import 'dart:convert';
import 'dart:io';

import 'evidence_report.dart';

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void _write(String path, Map<String, Object?> value) => File(
  path,
).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');

Object? _labelLocalPaths(Object? value) {
  if (value is String) {
    return value.replaceAll(Directory.current.path, '<repo>');
  }
  if (value is List<Object?>) return value.map(_labelLocalPaths).toList();
  if (value is Map<String, Object?>) {
    return value.map((key, item) => MapEntry(key, _labelLocalPaths(item)));
  }
  return value;
}

Future<String?> _probe(String command, List<String> args) async {
  try {
    final process = await Process.start(command, args);
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode.timeout(
      const Duration(seconds: 30),
      onTimeout: () async {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        return -1;
      },
    );
    final output = '${await stdout}\n${await stderr}'.trim();
    return code == 0 ? output : null;
  } on ProcessException {
    return null;
  }
}

Future<Map<String, Object?>?> _device(String id) async {
  final text = await _probe(Platform.environment['FLUTTER_BIN'] ?? 'flutter', [
    'devices',
    '--machine',
  ]);
  if (text == null) return null;
  final devices = jsonDecode(text) as List<Object?>;
  for (final device in devices.whereType<Map<String, Object?>>()) {
    if (device['id'] == id) {
      return {
        for (final key in ['id', 'name', 'targetPlatform', 'sdk', 'emulator'])
          key: device[key],
      };
    }
  }
  return null;
}

Future<List<Map<String, Object?>>> _stackImages() async {
  // Fixed SDK-owned project: never enumerate or inspect another app's stack.
  final ids = await _probe('docker', [
    'compose',
    '-p',
    'rgb-sdk-flutter-regtest',
    '-f',
    'tool/regtest/compose.yaml',
    'ps',
    '-q',
  ]);
  if (ids == null || ids.isEmpty) return [];
  final result = <Map<String, Object?>>[];
  for (final id in ids.split('\n').where((id) => id.isNotEmpty)) {
    final text = await _probe('docker', [
      'inspect',
      '--format',
      '{"containerId":{{json .Id}},"imageId":{{json .Image}},"service":{{json (index .Config.Labels "com.docker.compose.service")}}}',
      id,
    ]);
    if (text == null) continue;
    result.add(jsonDecode(text) as Map<String, Object?>);
  }
  return result;
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Expected start <snapshot> or finish <snapshot> <report>.',
    );
  }
  if (args[0] == 'start') {
    final flutter = await Process.run(
      Platform.environment['FLUTTER_BIN'] ?? 'flutter',
      ['--version', '--machine'],
    );
    if (flutter.exitCode != 0) throw StateError('Cannot identify Flutter.');
    final flutterVersion =
        jsonDecode(flutter.stdout as String) as Map<String, Object?>;
    _write(args[1], {
      'candidate': candidateIdentity(),
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'toolchain': {
        'dart': Platform.version,
        'flutter': {
          for (final key in [
            'frameworkVersion',
            'frameworkRevision',
            'engineRevision',
            'dartSdkVersion',
            'channel',
          ])
            key: flutterVersion[key],
        },
        'host':
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'architecture': await _probe('uname', ['-m']),
        'xcode': Platform.isMacOS
            ? await _probe('xcodebuild', ['-version'])
            : null,
        'cocoapods': Platform.isMacOS
            ? await _probe('pod', ['--version'])
            : null,
        'java': RegExp(
          r'(?:openjdk|java) version "[^"]+"',
        ).firstMatch(await _probe('java', ['-version']) ?? '')?.group(0),
      },
    });
    return;
  }
  if (args[0] != 'finish' || args.length != 3) {
    throw ArgumentError('Invalid command.');
  }
  final snapshot = _read(args[1]);
  final report = _read(args[2]);
  final before = snapshot['candidate'] as Map<String, Object?>;
  final after = candidateIdentity();
  final log = File(Platform.environment['EVIDENCE_LOG_PATH'] ?? '');
  if (!log.existsSync()) {
    throw StateError('Cannot finalize without the completed log.');
  }
  report.addAll({
    'schemaVersion': 2,
    'runId': Platform.environment['RELEASE_RUN_ID'] ?? report['runId'],
    'candidateStart': before,
    'candidateEnd': after,
    'toolchain': snapshot['toolchain'],
    'startedAt': snapshot['startedAt'],
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'logPath': log.absolute.path.startsWith('${Directory.current.path}/')
        ? '<repo>/${log.absolute.path.substring(Directory.current.path.length + 1)}'
        : log.absolute.path,
    'logSha256': fileDigest(log),
    'releaseEligible':
        report['status'] == 'passed' && sameCleanCandidate(before, after),
  });
  final device = report['device'];
  if (device is String) report['deviceIdentity'] = await _device(device);
  if (report['regtest'] is Map<String, Object?>) {
    report['stackIdentity'] = {
      'project': 'rgb-sdk-flutter-regtest',
      'composeSha256': fileDigest(File('tool/regtest/compose.yaml')),
      'services': await _stackImages(),
    };
  }
  if (report['suite'] == 'release-candidate') {
    final children = File(
      '${log.parent.path}/children-${report['runId']}.json',
    );
    if (!children.existsSync()) {
      report['releaseEligible'] = false;
      report['status'] = 'failed';
    } else {
      report['childrenManifest'] = {
        'path': children.path,
        'sha256': fileDigest(children),
      };
    }
  }
  if (!sameCleanCandidate(before, after)) {
    report['releaseEligible'] = false;
    report['candidateQualification'] = 'dirty-or-changed';
  }
  if (!log.absolute.path.startsWith('${Directory.current.path}/')) {
    report['releaseEligible'] = false;
    report['artifactPathScope'] = 'external-debug-only';
  }
  if (report['releaseEligible'] == true) {
    final errors = evidenceReportErrors(
      report,
      candidate: before,
      runId: '${report['runId']}',
      root: Directory.current,
    );
    if (errors.isNotEmpty) {
      report['releaseEligible'] = false;
      report['status'] = 'failed';
      report['evidenceErrors'] = errors;
    }
  }
  _write(args[2], _labelLocalPaths(report) as Map<String, Object?>);
  if (report['status'] == 'failed') exitCode = 1;
}
