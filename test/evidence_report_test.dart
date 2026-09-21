import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/evidence_report.dart';

void main() {
  test(
    'child evidence rejects stale trees, missing gates and altered logs',
    () {
      final root = Directory.systemTemp.createTempSync('rgb-evidence-');
      addTearDown(() => root.deleteSync(recursive: true));
      final log = File('${root.path}/run.log')
        ..writeAsStringSync('completed\n');
      final identity = <String, Object?>{
        'commit': 'candidate',
        'dirty': false,
        'sourceSha256': 'source',
        'baselineSha256': 'baseline',
        'provenanceSha256': 'artifacts',
        'dependencyLockSha256': 'lock',
      };
      final report = <String, Object?>{
        'schemaVersion': 2,
        'suite': 'native-android-jvm',
        'runId': 'run',
        'status': 'passed',
        'releaseEligible': true,
        'candidateStart': identity,
        'candidateEnd': identity,
        'toolchain': {
          'dart': 'version',
          'flutter': <String, Object?>{
            'frameworkVersion': '3.41.9',
            'frameworkRevision': 'test-framework',
            'engineRevision': 'test-engine',
            'dartSdkVersion': '3.11.5',
            'channel': 'stable',
          },
          'host': 'host',
          'architecture': 'arm64',
          'java': 'openjdk version "17"',
        },
        'startedAt': '2026-09-20T00:00:00Z',
        'finishedAt': '2026-09-20T00:00:01Z',
        'exitCode': 0,
        'logPath': '<repo>/run.log',
        'logSha256': fileDigest(log),
      };
      List<String> check(Map<String, Object?> value) => evidenceReportErrors(
        value,
        candidate: identity,
        runId: 'run',
        root: root,
      );
      expect(check(report), isEmpty);
      for (final change in <Map<String, Object?>>[
        {'schemaVersion': 1},
        {'runId': 'old'},
        {'releaseEligible': false},
        {
          'candidateEnd': {...identity, 'commit': 'other'},
        },
        {
          'candidateEnd': {...identity, 'sourceSha256': 'edited'},
        },
        {
          'candidateEnd': {...identity, 'dirty': true},
        },
        {'steps': <Object?>[]},
        {
          'steps': [
            {'exitCode': 125},
          ],
        },
        {'logSha256': 'incorrect'},
        {'toolchain': null},
        {'suite': 'invented-suite'},
        {'suite': 'native-ios-xctest'},
        {'suite': 'release-candidate'},
        {
          'toolchain': {
            ...report['toolchain']! as Map<String, Object?>,
            'flutter': <String, Object?>{},
          },
        },
        {'finishedAt': '2026-09-19T00:00:00Z'},
      ]) {
        expect(check({...report, ...change}), isNotEmpty, reason: '$change');
      }

      final childReports = <File>[];
      for (final entry in <(String, String?)>[
        ('clean-consumer-matrix', null),
        ('native-android-jvm', null),
        ('native-ios-xctest', 'ios-device'),
        for (final device in ['ios-device', 'android-device']) ...[
          ('platform-unfunded-regtest', device),
          ('platform-funded-regtest', device),
          ('external-signer-process-restart', device),
        ],
      ]) {
        final (suite, device) = entry;
        final child = {
          ...report,
          'suite': suite,
          'toolchain': {
            ...report['toolchain']! as Map<String, Object?>,
            'xcode': 'Xcode 27',
            'cocoapods': '1.16.2',
          },
          if (suite == 'clean-consumer-matrix') 'archivesEnabled': '1',
          if (device != null) ...{
            'device': device,
            'deviceIdentity': {
              'id': device,
              'sdk': 'test-sdk',
              'targetPlatform': device == 'ios-device'
                  ? 'ios'
                  : 'android-arm64',
            },
          },
          if (suite.contains('regtest') ||
              suite == 'external-signer-process-restart')
            'stackIdentity': {
              'project': 'rgb-sdk-flutter-regtest',
              'services': [
                for (final service in ['bitcoind', 'electrs', 'proxy'])
                  {'service': service, 'imageId': 'sha256:${'0' * 64}'},
              ],
            },
        };
        final file = File('${root.path}/$suite-${device ?? 'host'}.json')
          ..writeAsStringSync(jsonEncode(child));
        childReports.add(file);
      }
      final manifest = File('${root.path}/children.json');
      Map<String, Object?> parent() {
        manifest.writeAsStringSync(
          jsonEncode({
            'runId': 'run',
            'children': [
              for (final file in childReports)
                {'path': file.path, 'sha256': fileDigest(file)},
            ],
          }),
        );
        return {
          ...report,
          'suite': 'release-candidate',
          'childrenManifest': {
            'path': manifest.path,
            'sha256': fileDigest(manifest),
          },
        };
      }

      final passingParent = parent();
      expect(check(passingParent), isEmpty);
      final child = childReports.first;
      final original = child.readAsStringSync();
      child.writeAsStringSync('$original ');
      expect(
        check(passingParent),
        contains('Missing or altered child report.'),
      );
      child.writeAsStringSync(original);
      final removed = childReports.removeLast();
      expect(check(parent()), isNotEmpty);
      childReports.add(removed);
      final noChild = {...report, 'suite': 'release-candidate'};
      expect(
        check(noChild),
        contains('Missing or altered child-report manifest.'),
      );
      log.writeAsStringSync('changed after report\n');
      expect(
        check(report),
        contains('Completed log is absent or its checksum differs.'),
      );
    },
  );
}
