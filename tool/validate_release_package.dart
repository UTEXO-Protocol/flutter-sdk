import 'dart:convert';
import 'dart:io';

const _expectedVersion = '0.1.0';
const _expectedFlutterVersion = '3.41.9';
const _publicTestMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

final _secretPatterns = <RegExp>[
  RegExp(r'\bghp_[A-Za-z0-9_]{20,}\b'),
  RegExp(r'\bgithub_pat_[A-Za-z0-9_]{20,}\b'),
  RegExp(r'\bglpat-[A-Za-z0-9_\-\.]{20,}\b'),
  RegExp(
    r'\b(api[_-]?key|access[_-]?token|secret[_-]?key)\s*[:=]\s*[A-Za-z0-9_\-\.]{16,}',
    caseSensitive: false,
  ),
  RegExp(
    r'\b(?:abandon|ability|able|about|above|absent|absorb|abstract|absurd|abuse|access|accident|account|accuse|achieve|acid|acoustic|acquire|across|act|action|actor|actress|actual|adapt|add|addict|address|adjust|admit|adult|advance|advice|aerobic|affair|afford|afraid|again|age|agent|agree|ahead|aim|air|airport|aisle|alarm|album|alcohol|alert|alien|all|alley|allow|almost|alone|alpha|already|also|alter|always|amateur|amazing|among|amount|amused|analyst|anchor|ancient|anger|angle|angry|animal|ankle|announce|annual|another|answer|antenna|antique|anxiety|any|apart|apology|appear|apple|approve|april|arch|arctic|area|arena|argue|arm|armed|armor|army|around|arrange|arrest|arrive|arrow|art|artefact|artist|artwork|ask|aspect|assault|asset|assist|assume|asthma|athlete|atom|attack|attend|attitude|attract|auction|audit|august|aunt|author|auto|autumn|average|avocado|avoid|awake|aware|away|awesome|awful|awkward|axis)\b(?:\s+\b[a-z]{3,8}\b){11,23}',
  ),
];

void main() {
  final failures = <String>[];

  void check(bool condition, String message) {
    if (!condition) failures.add(message);
  }

  final pubspec = _read('pubspec.yaml');
  check(
    pubspec.contains('version: $_expectedVersion'),
    'pubspec version must be $_expectedVersion.',
  );
  check(
    pubspec.contains("sdk: '>=3.11.0 <4.0.0'") &&
        pubspec.contains("flutter: '>=3.41.0'"),
    'pubspec SDK constraints must match the tested Flutter/Dart baseline.',
  );

  final fvmrc = jsonDecode(_read('.fvmrc')) as Map<String, Object?>;
  check(
    fvmrc['flutter'] == _expectedFlutterVersion,
    '.fvmrc must pin Flutter $_expectedFlutterVersion.',
  );

  final qualityWorkflow = _read('.github/workflows/quality.yml');
  check(
    qualityWorkflow.contains('flutter-version-file: .fvmrc') &&
        !qualityWorkflow.contains('channel: stable'),
    'CI must install Flutter from .fvmrc, not a floating stable channel.',
  );

  final podspec = _read('ios/rgb_sdk_flutter.podspec');
  check(
    podspec.contains("s.version          = '$_expectedVersion'"),
    'podspec version must match pubspec.',
  );
  check(
    podspec.contains(":type => 'MIT'") &&
        podspec.contains(":file => '../LICENSE'"),
    'podspec must declare the package license type and LICENSE file.',
  );
  check(
    podspec.contains("s.source           = { :path => '.' }"),
    'podspec source must remain path-based for Flutter plugin integration.',
  );
  check(
    podspec.contains('IPHONEOS_DEPLOYMENT_TARGET') &&
        podspec.contains("ios_requirements.fetch('minimumOsVersion')"),
    'podspec must apply the baseline iOS minimum deployment target.',
  );
  check(
    podspec.contains('s.resource_bundles') &&
        podspec.contains('Resources/PrivacyInfo.xcprivacy'),
    'podspec must bundle the iOS privacy manifest.',
  );
  check(
    File('ios/Resources/PrivacyInfo.xcprivacy').existsSync(),
    'iOS privacy manifest file must exist.',
  );

  final androidBuild = _read('android/build.gradle.kts');
  check(
    androidBuild.contains('version = "$_expectedVersion"'),
    'Android Gradle version must match pubspec.',
  );
  check(
    !File('android/settings.gradle').existsSync() &&
        File('android/settings.gradle.kts').existsSync(),
    'Android plugin must keep only settings.gradle.kts.',
  );
  check(
    _read(
      'android/src/main/AndroidManifest.xml',
    ).contains('android.permission.INTERNET'),
    'Android plugin release manifest must declare INTERNET.',
  );
  check(
    _read(
      'example/android/app/src/main/AndroidManifest.xml',
    ).contains('android.permission.INTERNET'),
    'Android example release manifest must declare INTERNET.',
  );

  final pubignore = _read('.pubignore');
  for (final requiredPattern in <String>[
    'build/',
    'coverage/',
    '.github/',
    'ios/RGBLightningNode.xcframework/',
    'android/.gradle/',
  ]) {
    check(
      pubignore.contains(requiredPattern),
      '.pubignore must contain $requiredPattern.',
    );
  }

  final baseline =
      jsonDecode(_read('tool/release_baseline.json')) as Map<String, Object?>;
  check(
    baseline['releaseTier'] == 'internal-beta',
    'release baseline must keep releaseTier=internal-beta until provenance gates pass.',
  );
  final iosRequirements =
      ((baseline['buildRequirements']! as Map<String, Object?>)['ios']!
          as Map<String, Object?>);
  check(
    iosRequirements['minimumOsVersion'] == '18.5',
    'iOS minimum must match the current RLN iOS artifact object minos 18.5.',
  );
  check(
    _read(
      'example/ios/Podfile',
    ).contains("platform :ios, '${iosRequirements['minimumOsVersion']}'"),
    'example iOS Podfile must declare the baseline iOS minimum.',
  );
  check(
    !_read(
      'example/ios/Runner.xcodeproj/project.pbxproj',
    ).contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;'),
    'example Xcode project must not keep stale iOS 13.0 deployment targets.',
  );

  final downloader = _read('tool/download_rln_ios.sh');
  check(
    downloader.contains('RLN_CACHE_DIR') &&
        downloader.contains('RLN_OFFLINE') &&
        downloader.contains('RLN_ARCHIVE_PATH'),
    'iOS artifact downloader must support explicit path, cache, and offline mode.',
  );

  check(File('LICENSE').existsSync(), 'LICENSE must exist.');
  check(File('SECURITY.md').existsSync(), 'SECURITY.md must exist.');
  check(
    File('doc/RELEASE_READINESS_TRACKER.md').existsSync(),
    'release tracker must exist.',
  );
  check(
    File('doc/API_COMPATIBILITY_AND_DIVERGENCE.md').existsSync(),
    'API compatibility and divergence policy must exist.',
  );
  check(
    File('doc/BRIDGE_BEHAVIOR_CONTRACT.md').existsSync(),
    'bridge behavior contract must exist.',
  );
  check(
    File('doc/RELEASE_EVIDENCE_SCHEMA.md').existsSync(),
    'release evidence schema must exist.',
  );
  check(
    File('doc/PUBLIC_API_REFERENCE.md').existsSync(),
    'public API reference must exist.',
  );
  check(
    File('doc/COVERAGE_POLICY.md').existsSync(),
    'coverage policy must exist.',
  );
  check(
    File('tool/api_snapshot.json').existsSync(),
    'API/ABI snapshot must exist.',
  );
  check(
    File('tool/test_matrix/evidence_catalog.json').existsSync(),
    'test-matrix evidence catalog must exist.',
  );
  check(
    File('tool/test_matrix/bridge_behavior_vectors.json').existsSync(),
    'bridge behavior vector policy must exist.',
  );
  check(
    File('tool/validate_api_snapshot.dart').existsSync(),
    'API snapshot validation gate must exist.',
  );
  check(
    File('tool/validate_bridge_vectors.dart').existsSync(),
    'bridge behavior vector validation gate must exist.',
  );
  check(
    File('tool/validate_codebase_hardening.dart').existsSync(),
    'codebase hardening validation gate must exist.',
  );
  check(
    File('tool/validate_coverage_policy.dart').existsSync(),
    'coverage policy validation gate must exist.',
  );
  check(
    File('tool/validate_public_api_docs.dart').existsSync(),
    'public API documentation validation gate must exist.',
  );
  check(
    File('tool/validate_release_language.dart').existsSync(),
    'release language validation gate must exist.',
  );
  check(
    File('tool/validate_release_governance.dart').existsSync(),
    'release governance validation gate must exist.',
  );
  check(
    File('tool/validate_supply_chain.dart').existsSync(),
    'supply-chain validation gate must exist.',
  );
  check(
    File('tool/test_clean_consumer_matrix.sh').existsSync(),
    'clean consumer matrix gate must exist.',
  );
  check(
    _read(
          'tool/test_release_candidate.sh',
        ).contains('validate_supply_chain.dart') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('validate_codebase_hardening.dart') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('validate_public_api_docs.dart') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('validate_release_language.dart') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('validate_coverage_policy.dart') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('test_clean_consumer_matrix.sh') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('test_external_signer_restart.sh') &&
        _read(
          'tool/test_release_candidate.sh',
        ).contains('validate_bridge_vectors.dart'),
    'release candidate script must include bridge-vector, supply-chain, clean-consumer, and external-signer restart gates.',
  );
  check(
    File('test/fixtures/bip340_test_vectors.csv').existsSync(),
    'official BIP340 vector fixture must exist.',
  );

  for (final path in _trackedTextFiles()) {
    final text = _read(path);
    final scanText = text.replaceAll(_publicTestMnemonic, '');
    for (final pattern in _secretPatterns) {
      final match = pattern.firstMatch(scanText);
      if (match != null) {
        failures.add('possible secret material in $path: ${match.group(0)}');
        break;
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Release package validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Release package validation passed.');
}

String _read(String path) => File(path).readAsStringSync();

List<String> _trackedTextFiles() {
  final result = Process.runSync('git', <String>[
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
  ], stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    throw StateError('git ls-files failed: ${result.stderr}');
  }
  final binarySuffixes = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.jar',
    '.keystore',
    '.zip',
    '.aar',
    '.a',
    '.xcframework',
    '.plist',
    '.lock',
  };
  return (result.stdout as String)
      .split('\n')
      .where((path) => path.isNotEmpty)
      .where((path) => File(path).existsSync())
      .where((path) => !path.startsWith('build/'))
      .where((path) => !binarySuffixes.any(path.endsWith))
      .toList(growable: false);
}
