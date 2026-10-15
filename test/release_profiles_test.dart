import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/evidence_report.dart';
import '../tool/release_profiles.dart';

Map<String, Object?> qualificationFields() => {
  'releaseProfile': mainnetOnchainProfile,
  'releaseNetwork': 'mainnet',
  'testNetwork': 'regtest',
  'walletSigner': 'password',
  'stackIdentity': {
    'project': 'wdk-rln-017-qualification',
    'host': 'localhost',
    'containerLifecycle': 'preserved',
    'ports': {'rlnApi': 29301, 'esplora': 29302, 'rgbProxy': 29300},
    'services': [
      for (final role in ['rln', 'esplora', 'rgb-proxy'])
        {
          'role': role,
          'containerId': 'a' * 64,
          'imageId': 'sha256:${'b' * 64}',
        },
    ],
  },
  'bfaChainIdentity': {
    'project': 'wdk-rln-017-bfa-anvil-20261014',
    'rpcUrl': 'http://localhost:29545',
    'chainId': 31337,
    'containerId': 'c' * 64,
    'imageId': 'sha256:${'d' * 64}',
    'containerLifecycle': 'preserved',
    'contractsPreserved': true,
  },
  'cases': [
    for (final id in onchainQualificationCases)
      {
        'id': id,
        'status': 'passed',
        'assertions': ['Test fixture assertion for $id'],
      },
  ],
};

void main() {
  test(
    'mainnet profile requires five children without Lightning successes',
    () {
      final keys = expectedChildEvidence(
        profile: mainnetOnchainProfile,
        ios: 'ios',
        android: 'android',
      );
      expect(keys, {
        'clean-consumer-matrix/',
        'native-android-jvm/',
        'native-ios-xctest/ios',
        'platform-onchain-regtest/ios',
        'platform-onchain-regtest/android',
      });
      expect(
        expectedChildEvidence(
          profile: internalBetaProfile,
          ios: 'i',
          android: 'a',
        ),
        hasLength(9),
      );
      expect(
        () => expectedChildEvidence(profile: 'typo', ios: 'i', android: 'a'),
        throwsArgumentError,
      );
    },
  );

  test(
    'isolated onchain cases fail closed for missing or foreign evidence',
    () {
      final valid = qualificationFields();
      expect(onchainQualificationErrors(valid), isEmpty);
      for (final key in valid.keys) {
        expect(
          onchainQualificationErrors({...valid}..remove(key)),
          isNotEmpty,
          reason: 'Missing $key must fail.',
        );
      }
      for (final id in onchainQualificationCases) {
        final cases = List<Map<String, Object?>>.from(valid['cases']! as List);
        cases.removeWhere((entry) => entry['id'] == id);
        expect(
          onchainQualificationErrors({...valid, 'cases': cases}),
          isNotEmpty,
          reason: 'Missing $id must fail.',
        );
      }
      for (final change in <Map<String, Object?>>[
        {'walletSigner': 'external'},
        {'testNetwork': 'mainnet'},
        {'releaseProfile': internalBetaProfile},
        {
          'stackIdentity': {'project': 'utexo_local'},
        },
        {
          'bfaChainIdentity': {'chainId': 42161},
        },
        {
          'cases': [
            ...(valid['cases']! as List),
            {
              'id': 'lightning-pay',
              'status': 'passed',
              'assertions': ['paid'],
            },
          ],
        },
        {
          'cases': [
            ...(valid['cases']! as List),
            (valid['cases']! as List).first,
          ],
        },
      ]) {
        expect(onchainQualificationErrors({...valid, ...change}), isNotEmpty);
      }
    },
  );

  test('mainnet aggregate validates both exact onchain children and logs', () {
    final root = Directory.systemTemp.createTempSync('rgb-onchain-profile-');
    addTearDown(() => root.deleteSync(recursive: true));
    final log = File('${root.path}/run.log')..writeAsStringSync('completed\n');
    final candidate = <String, Object?>{
      'commit': 'candidate',
      'dirty': false,
      'sourceSha256': 'source',
      'baselineSha256': 'baseline',
      'provenanceSha256': 'artifacts',
      'dependencyLockSha256': 'lock',
    };
    final base = <String, Object?>{
      'schemaVersion': 2,
      'runId': 'run',
      'status': 'passed',
      'releaseEligible': true,
      'candidateStart': candidate,
      'candidateEnd': candidate,
      'toolchain': {
        'dart': 'version',
        'host': 'host',
        'architecture': 'arm64',
        'java': '17',
        'xcode': '27',
        'cocoapods': '1.16',
        'flutter': {
          'frameworkVersion': '3.47.7',
          'frameworkRevision': 'framework',
          'engineRevision': 'engine',
          'dartSdkVersion': '3.13',
          'channel': 'stable',
        },
      },
      'startedAt': '2026-10-16T00:00:00Z',
      'finishedAt': '2026-10-16T00:00:01Z',
      'exitCode': 0,
      'logPath': '<repo>/run.log',
      'logSha256': fileDigest(log),
    };
    final children = <File>[];
    for (final key in expectedChildEvidence(
      profile: mainnetOnchainProfile,
      ios: 'ios',
      android: 'android',
    )) {
      final split = key.split('/');
      final suite = split[0];
      final device = split[1];
      final data = {
        ...base,
        'suite': suite,
        if (suite == 'clean-consumer-matrix') 'archivesEnabled': '1',
        if (device.isNotEmpty) ...{
          'device': device,
          'deviceIdentity': {
            'id': device,
            'sdk': device == 'ios' ? 'iOS 27' : 'Android 17',
            'targetPlatform': device == 'ios' ? 'ios' : 'android-arm64',
          },
        },
        if (suite == 'platform-onchain-regtest') ...qualificationFields(),
      };
      final file = File('${root.path}/$suite-$device.json')
        ..writeAsStringSync(jsonEncode(data));
      children.add(file);
    }
    List<String> checkParent() {
      final manifest = File('${root.path}/children.json')
        ..writeAsStringSync(
          jsonEncode({
            'runId': 'run',
            'children': [
              for (final file in children)
                {'path': file.path, 'sha256': fileDigest(file)},
            ],
          }),
        );
      return evidenceReportErrors(
        {
          ...base,
          'suite': 'release-candidate',
          'releaseProfile': mainnetOnchainProfile,
          'childrenManifest': {
            'path': manifest.path,
            'sha256': fileDigest(manifest),
          },
        },
        candidate: candidate,
        runId: 'run',
        root: root,
      );
    }

    expect(checkParent(), isEmpty);
    final android = children.removeLast();
    expect(checkParent(), isNotEmpty);
    children.add(android);
    final report =
        jsonDecode(android.readAsStringSync()) as Map<String, Object?>;
    android.writeAsStringSync(
      jsonEncode({
        ...report,
        'candidateEnd': {...candidate, 'commit': 'stale'},
      }),
    );
    expect(checkParent(), isNotEmpty);
  });
}
