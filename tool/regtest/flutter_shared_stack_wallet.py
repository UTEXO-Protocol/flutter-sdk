#!/usr/bin/env python3
"""Run mobile wallet qualification against existing, preserved infrastructure.

This runner only reads the shared configuration and launches Flutter. Funding,
mint and payout requests are single-attempt events to the separately operated
host controller on localhost:29671; it owns the shared-stack mutation lock.
There are no Docker, chain setup, reset, wallet deletion or automatic retry paths.
On Android, the caller must establish adb reverse tcp:29671 tcp:29671 first.
"""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request


ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_digest():
    paths = subprocess.check_output(['git', 'ls-files', '-c', '-o',
        '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
    inventory = {path: digest(ROOT / path) for path in sorted(set(paths))
                 if path and (ROOT / path).is_file()}
    return hashlib.sha256(json.dumps(inventory, sort_keys=True).encode()).hexdigest()


def private_control_event(event, args):
    records = ROOT.parent / 'aster-dev/.buildlog/full-wallet-20261015/events.jsonl'
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if records.exists():
            for line in reversed(records.read_text().splitlines()):
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if (value.get('run_id') == args.run_id
                        and value.get('event') == event.get('event')
                        and value.get('id') == event.get('id')):
                    return value
        time.sleep(0.1)
    raise RuntimeError('Private fixture control record not received')


def preserve_fixture(fixture, args, output, native_closed):
    if args.device.startswith('emulator-'):
        if not re.fullmatch(r'/data/[A-Za-z0-9_./-]+/rgb-shared-' + re.escape(args.run_id) + r'-[A-Za-z0-9]+', fixture):
            raise RuntimeError('Unexpected Android fixture directory; refusing to copy')
        archive = output / 'private-device-state.tar'
        adb = os.environ.get('ADB_BIN', str(Path.home() / 'Library/Android/sdk/platform-tools/adb'))
        with archive.open('wb') as stream:
            copied = subprocess.run([adb, '-s', args.device, 'exec-out', 'run-as',
                'com.utexo.rgb_sdk_flutter_example', 'tar', '-C', fixture, '-cf', '-', '.'],
                stdout=stream, stderr=subprocess.PIPE)
        archive.chmod(0o600)
        if copied.returncode:
            raise RuntimeError('Private Android fixture copy failed')
        return {'status': 'saved', 'nativeClosed': native_closed,
                'archiveSha256': digest(archive), 'bytes': archive.stat().st_size}
    source = Path(fixture)
    allowed = Path.home() / 'Library/Developer/CoreSimulator/Devices' / args.device / 'data/Containers/Data/Application'
    if not source.resolve().is_relative_to(allowed) or not source.name.startswith('rgb-shared-' + args.run_id + '-'):
        raise RuntimeError('Unexpected iOS fixture directory; refusing to copy')
    destination = output / 'private-device-state'
    shutil.copytree(source, destination, symlinks=True)
    destination.chmod(0o700)
    return {'status': 'saved', 'nativeClosed': native_closed,
            'policy': 'private owner-only source copy; no secret output'}


def restore_android_wallets(source, fixture, args):
    # Only this SDK's verified owner-only archive is admitted. Reject traversal
    # and links before passing the two exact wallet directory trees to tar.
    with tarfile.open(source, 'r:') as archive:
        roots = set()
        for member in archive.getmembers():
            name = member.name.removeprefix('./')
            if name in ('', '.'):
                continue
            parts = Path(name).parts
            if Path(name).is_absolute() or '..' in parts or member.issym() or member.islnk():
                raise RuntimeError('Unsafe private fixture archive refused')
            if not (member.isfile() or member.isdir()):
                raise RuntimeError('Unsupported private fixture archive entry refused')
            if parts[0] in ('wallet-a', 'wallet-b'):
                roots.add(parts[0])
        if roots != {'wallet-a', 'wallet-b'}:
            raise RuntimeError('Both owned wallet trees are required')
    adb = os.environ.get('ADB_BIN', str(Path.home() / 'Library/Android/sdk/platform-tools/adb'))
    for name in ('wallet-a', 'wallet-b'):
        absent = subprocess.run([adb, '-s', args.device, 'exec-out', 'run-as',
            'com.utexo.rgb_sdk_flutter_example', 'test', '!', '-e', fixture + '/' + name],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if absent.returncode:
            raise RuntimeError('Existing or unverifiable Android wallet target refused')
    with source.open('rb') as stream:
        copied = subprocess.run([adb, '-s', args.device, 'exec-in', 'run-as',
            'com.utexo.rgb_sdk_flutter_example', 'tar', '-C', fixture,
            '-xf', '-', './wallet-a', './wallet-b'], stdin=stream,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if copied.returncode:
        raise RuntimeError('Private Android wallet restore failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--stack-dir', type=Path,
                        default=Path(os.environ.get('RGB_SHARED_STACK_DIR',
                            str(ROOT.parent.parent / 'utexo-local-stack'))),
                        help='existing shared stack directory; this runner never starts it')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--lifecycle-only', action='store_true')
    mode.add_argument('--resume-after-blind', type=Path,
                        help='private closed iOS fixture from a resolved earlier run; never mints/funds again')
    mode.add_argument('--verify-closed-fixture', type=Path,
                      help='read-only verification of an owned post-burn Android private archive; no financial requests')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{6,80}', args.run_id):
        parser.error('run-id must contain 6 through 80 ASCII letters, digits, dash or underscore')
    output = ROOT / 'build/full-wallet-20261015' / args.run_id
    # Existing runs carry financial requests. Never overwrite/replay a run.
    output.mkdir(parents=True, exist_ok=False)
    output.chmod(0o700)
    config_path = args.stack_dir.resolve() / 'artifacts/consumer-config.json'
    config = json.loads(config_path.read_text())
    if (config.get('environment') != 'LOCAL TEST ONLY'
            or config.get('network') != 'regtest'
            or config.get('evm_chain_id') != 42161
            or config.get('esplora_url') != 'http://127.0.0.1:18094'
            or config.get('proxy_endpoint') != 'rpc://127.0.0.1:28090/json-rpc'):
        raise RuntimeError('Shared configuration identity or endpoint changed; review before running')
    asset = config['asset']
    if (asset['schema'], asset['native_name'], asset['ticker'], asset['precision']) != ('Bfa', 'Usdt', 'USDT', 6):
        raise RuntimeError('Unexpected canonical BFA public identity')
    contract_path = Path(asset['public_contract'])
    if digest(contract_path) != asset['sha256']:
        raise RuntimeError('Canonical public contract hash mismatch')
    with urllib.request.urlopen(config['esplora_url'] + '/blocks/tip/height', timeout=15) as response:
        height = int(response.read())
    if height < 103:
        raise RuntimeError('Existing stack is not ready; runner will not start or initialize it')
    definitions = {
        'RGB_SHARED_RUN_ID': args.run_id,
        'RGB_SHARED_CONTRACT_BASE64': base64.b64encode(contract_path.read_bytes()).decode('ascii'),
        'RGB_SHARED_ASSET_ID': asset['id'],
        'RGB_SHARED_CONTRACT_SHA256': asset['sha256'],
        'RGB_SHARED_LIFECYCLE_ONLY': args.lifecycle_only,
        'RGB_SHARED_RESUME_AFTER_BLIND': args.resume_after_blind is not None,
        'RGB_SHARED_VERIFY_CLOSED_FIXTURE': args.verify_closed_fixture is not None,
    }
    resume_report = None
    resume_pubkey = None
    verify_report = None
    if args.verify_closed_fixture:
        source = args.verify_closed_fixture.resolve()
        if not args.device.startswith('emulator-') or source.name != 'private-device-state.tar' or not source.is_relative_to(ROOT / 'build/full-wallet-20261015'):
            raise RuntimeError('Verification requires this SDK private Android fixture archive')
        verify_report = json.loads((source.parent / 'result.json').read_text())
        backup = verify_report['privateFixtureBackup']
        if (verify_report['device'] != args.device or backup.get('status') != 'saved'
                or backup.get('nativeClosed') is not True
                or backup.get('archiveSha256') != digest(source)
                or verify_report['consumerConfigSha256'] != digest(config_path)):
            raise RuntimeError('Verification source identity, quiescence, archive or configuration differs')
        events = [json.loads(line.split('RGB_SDK_SHARED ', 1)[1]) for line in (source.parent / 'flutter.log').read_text().splitlines() if line.startswith('RGB_SDK_SHARED ')]
        if sum(e['event'] == 'bfa_burn_native_result' for e in events) != 1 or not any(e['event'] == 'bfa_witness_transfer_passed' for e in events):
            raise RuntimeError('Verification requires one retained post-witness native burn result')
        resume_pubkey = next(e['pubkey'] for e in events if e['event'] == 'lifecycle_destroy_reopen_passed')
    if args.resume_after_blind:
        source = args.resume_after_blind.resolve()
        if args.device.startswith('emulator-') or source.name != 'private-device-state' or not source.is_relative_to(ROOT / 'build/full-wallet-20261015'):
            raise RuntimeError('Resume requires this SDK private iOS fixture backup')
        resume_report = json.loads((source.parent / 'result.json').read_text())
        if (resume_report['device'] != args.device
                or resume_report['privateFixtureBackup'] != {'status': 'saved', 'nativeClosed': True,
                    'policy': 'private owner-only source copy; no secret output'}
                or resume_report['consumerConfigSha256'] != digest(config_path)):
            raise RuntimeError('Resume source identity, quiescence or consumer configuration differs')
        events = [json.loads(line.split('RGB_SDK_SHARED ', 1)[1]) for line in (source.parent / 'flutter.log').read_text().splitlines() if line.startswith('RGB_SDK_SHARED ')]
        if not any(e['event'] == 'bfa_blind_transfer_passed' for e in events) or any(e['event'] in ('bfa_burn_prepared', 'bfa_burn_native_result') for e in events):
            raise RuntimeError('Resume source is not the verified pre-burn blind-transfer checkpoint')
        resume_pubkey = next(e['pubkey'] for e in events if e['event'] == 'lifecycle_destroy_reopen_passed')
    definitions_path = output / 'public-defines.json'
    definitions_path.write_text(json.dumps(definitions, indent=2) + '\n')
    command = [
        os.environ.get('FLUTTER_BIN', 'flutter'), 'test',
        'integration_test/shared_stack_wallet_test.dart',
        '-d', args.device,
        '--dart-define-from-file=' + str(definitions_path),
        '--reporter=expanded',
    ]
    start = time.time()
    start_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    start_diff = subprocess.check_output(['git', 'diff', '--binary'], cwd=ROOT)
    start_source = source_digest()
    start_test_sha = digest(ROOT / 'example/integration_test/shared_stack_wallet_test.dart')
    process = subprocess.Popen(command, cwd=ROOT / 'example', stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)
    fixture = None
    backup = {'status': 'unavailable', 'reason': 'no closed-fixture backup event'}
    with (output / 'flutter.log').open('w') as log:
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            log.write(line)
            log.flush()
            if 'RGB_SDK_SHARED ' in line:
                event = json.loads(line.split('RGB_SDK_SHARED ', 1)[1])
                if event.get('event') in ('fixture_created', 'fixture_backup_requested', 'fixture_restore_requested'):
                    event = private_control_event(event, args)
                if event.get('event') == 'fixture_created':
                    fixture = event['storage']
                if event.get('event') == 'fixture_backup_requested':
                    if event.get('storage') != fixture:
                        raise RuntimeError('Backup request differs from this run fixture')
                    backup = preserve_fixture(fixture, args, output, event['native_closed'])
                    commands = ROOT.parent / 'aster-dev/.buildlog/full-wallet-20261015/commands'
                    ack = commands / (event['id'] + '.json')
                    # Only this run's unique acknowledgement is created. No
                    # stack mutation or financial request is handled here.
                    with ack.open('x') as stream:
                        json.dump({'ok': True, 'private_fixture_preserved': True}, stream)
                        stream.flush()
                        os.fsync(stream.fileno())
                if event.get('event') == 'fixture_restore_requested':
                    if not (args.resume_after_blind or args.verify_closed_fixture) or event.get('storage') != fixture:
                        raise RuntimeError('Unowned restore request refused')
                    destination = Path(fixture)
                    if args.verify_closed_fixture:
                        if not re.fullmatch(r'/data/[A-Za-z0-9_./-]+/rgb-shared-' + re.escape(args.run_id) + r'-[A-Za-z0-9]+', fixture):
                            raise RuntimeError('Unexpected Android restore target refused')
                        restore_android_wallets(args.verify_closed_fixture, fixture, args)
                    else:
                        allowed = Path.home() / 'Library/Developer/CoreSimulator/Devices' / args.device / 'data/Containers/Data/Application'
                        if not destination.resolve().is_relative_to(allowed):
                            raise RuntimeError('Unexpected restore target refused')
                        for name in ('wallet-a', 'wallet-b'):
                            if (destination / name).exists():
                                raise RuntimeError('Existing wallet target refused; never overwrite state')
                            shutil.copytree(args.resume_after_blind / name, destination / name, symlinks=True)
                    ack = ROOT.parent / 'aster-dev/.buildlog/full-wallet-20261015/commands' / (event['id'] + '.json')
                    with ack.open('x') as stream:
                        json.dump({'ok': True, 'wallet_a_pubkey': resume_pubkey,
                            'restored_from_run': (resume_report or verify_report)['runId']}, stream)
                        stream.flush()
                        os.fsync(stream.fileno())
    code = process.wait()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    diff = subprocess.check_output(['git', 'diff', '--binary'], cwd=ROOT)
    end_source = source_digest()
    report = {
        'schemaVersion': 1, 'suite': 'shared-stack-wallet',
        'status': 'passed' if code == 0 else 'failed', 'exitCode': code,
        'runId': args.run_id, 'device': args.device, 'lifecycleOnly': args.lifecycle_only,
        'repositoryCommit': start_commit, 'repositoryCommitAtEnd': commit,
        'trackedDiffSha256': hashlib.sha256(start_diff).hexdigest(),
        'trackedDiffSha256AtEnd': hashlib.sha256(diff).hexdigest(),
        'sourceSha256': start_source, 'sourceSha256AtEnd': end_source,
        'sourceChangedDuringRun': start_source != end_source or start_commit != commit,
        'testSourceSha256': start_test_sha,
        'consumerConfigSha256': digest(config_path), 'publicContractSha256': asset['sha256'],
        'chainHeightBefore': height, 'elapsedSeconds': round(time.time() - start, 3),
        'logSha256': digest(output / 'flutter.log'),
        'infrastructureStarted': False, 'containersCreated': False, 'stateReset': False,
        'fixtureStoragePolicy': 'unique mobile directories retained; see fixture_created events',
        'privateFixtureBackup': backup,
        'resumedClosedFixtureRun': resume_report['runId'] if resume_report else None,
        'verificationClosedFixtureRun': verify_report['runId'] if verify_report else None,
        'productionReady': False,
    }
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Qualification report: ' + str(output / 'result.json'))
    return code


if __name__ == '__main__':
    sys.exit(main())
