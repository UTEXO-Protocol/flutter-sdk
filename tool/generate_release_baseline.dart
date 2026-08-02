import 'dart:convert';
import 'dart:io';

final class _Baseline {
  const _Baseline({
    required this.rnCommit,
    required this.rnVersion,
    required this.coreVersion,
    required this.rlnVersion,
    required this.androidCoordinate,
    required this.iosArchiveUrl,
  });

  final String rnCommit;
  final String rnVersion;
  final String coreVersion;
  final String rlnVersion;
  final String androidCoordinate;
  final String iosArchiveUrl;
}

void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');
  if (arguments.any((argument) => argument != '--check')) {
    stderr.writeln(
      'Usage: dart run tool/generate_release_baseline.dart [--check]',
    );
    exitCode = 64;
    return;
  }

  final root = File.fromUri(Platform.script).parent.parent;
  final manifestFile = File('${root.path}/tool/release_baseline.json');
  final baseline = _readBaseline(manifestFile);
  final outputs = <File, String>{
    File('${root.path}/lib/src/release_baseline.g.dart'): _renderDart(baseline),
    File('${root.path}/ios/Classes/ReleaseBaseline.g.swift'): _renderSwift(
      baseline,
    ),
    File(
      '${root.path}/android/src/main/kotlin/com/utexo/'
      'rgb_sdk_flutter/ReleaseBaseline.g.kt',
    ): _renderKotlin(
      baseline,
    ),
  };

  var drifted = false;
  for (final entry in outputs.entries) {
    final file = entry.key;
    final expected = entry.value;
    if (checkOnly) {
      if (!file.existsSync() || file.readAsStringSync() != expected) {
        stderr.writeln('Generated baseline drift: ${file.path}');
        drifted = true;
      }
      continue;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(expected);
    stdout.writeln('Generated ${file.path}');
  }

  if (drifted) {
    stderr.writeln('Run: dart run tool/generate_release_baseline.dart');
    exitCode = 1;
  } else if (checkOnly) {
    stdout.writeln('Release baseline generated files are current.');
  }
}

_Baseline _readBaseline(File file) {
  if (!file.existsSync()) {
    throw FormatException('Missing release baseline: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('release_baseline.json must be an object.');
  }
  if (decoded['schemaVersion'] != 1) {
    throw const FormatException('Unsupported release baseline schemaVersion.');
  }

  final rn = _object(decoded, 'reactNative');
  final core = _object(decoded, 'core');
  final rln = _object(decoded, 'rln');
  final ios = _object(rln, 'ios');
  final android = _object(rln, 'android');
  final buildRequirements = _object(decoded, 'buildRequirements');
  final iosRequirements = _object(buildRequirements, 'ios');
  final androidRequirements = _object(buildRequirements, 'android');
  final installedFiles = _object(ios, 'installedFiles');

  final rnCommit = _string(rn, 'commit');
  final rlnCommit = _string(rln, 'commit');
  for (final entry in <String, String>{
    'reactNative.commit': rnCommit,
    'rln.commit': rlnCommit,
  }.entries) {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(entry.value)) {
      throw FormatException('${entry.key} must be a full SHA-1.');
    }
  }
  final rlnVersion = _string(rln, 'version');
  if (_string(rln, 'tag') != 'v$rlnVersion') {
    throw const FormatException('rln.tag must equal v<rln.version>.');
  }
  if (decoded['releaseTier'] != 'internal-beta') {
    throw const FormatException(
      'releaseTier must remain internal-beta until production gates pass.',
    );
  }
  for (final entry in <String, String>{
    'reactNative.repository': _string(rn, 'repository'),
    'core.repository': _string(core, 'repository'),
    'rln.repository': _string(rln, 'repository'),
    'rln.ios.archiveUrl': _string(ios, 'archiveUrl'),
    'rln.android.archiveUrl': _string(android, 'archiveUrl'),
  }.entries) {
    final uri = Uri.tryParse(entry.value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('${entry.key} must be an absolute HTTPS URL.');
    }
  }
  for (final entry in <String, int>{
    'rln.ios.archiveSizeBytes': _positiveInt(ios, 'archiveSizeBytes'),
    'rln.android.archiveSizeBytes': _positiveInt(android, 'archiveSizeBytes'),
    'buildRequirements.android.minSdk': _positiveInt(
      androidRequirements,
      'minSdk',
    ),
    'buildRequirements.android.compileSdk': _positiveInt(
      androidRequirements,
      'compileSdk',
    ),
    'buildRequirements.android.javaLanguageVersion': _positiveInt(
      androidRequirements,
      'javaLanguageVersion',
    ),
  }.entries) {
    if (entry.value <= 0) {
      throw FormatException('${entry.key} must be positive.');
    }
  }
  _string(iosRequirements, 'minimumOsVersion');
  _string(iosRequirements, 'swiftLanguageVersion');
  _string(androidRequirements, 'kotlinVersion');
  _nonEmptyStringList(ios, 'deviceArchitectures');
  _nonEmptyStringList(ios, 'simulatorArchitectures');
  _nonEmptyStringList(android, 'abis');
  if (installedFiles.isEmpty) {
    throw const FormatException('rln.ios.installedFiles must not be empty.');
  }
  for (final entry in installedFiles.entries) {
    if (entry.key.startsWith('/') || entry.key.contains('..')) {
      throw FormatException(
        'Installed artifact path must be repository-relative: ${entry.key}.',
      );
    }
    if (entry.value is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.value! as String)) {
      throw FormatException('Invalid SHA-256 for ${entry.key}.');
    }
  }
  for (final pair in <(Map<String, Object?>, String)>[
    (ios, 'archiveSha256'),
    (android, 'archiveSha256'),
  ]) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(_string(pair.$1, pair.$2))) {
      throw FormatException('${pair.$2} must be a SHA-256.');
    }
  }

  return _Baseline(
    rnCommit: rnCommit,
    rnVersion: _string(rn, 'version'),
    coreVersion: _string(core, 'version'),
    rlnVersion: rlnVersion,
    androidCoordinate: _string(android, 'mavenCoordinate'),
    iosArchiveUrl: _string(ios, 'archiveUrl'),
  );
}

Map<String, Object?> _object(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is Map<String, Object?>) return value;
  throw FormatException('$key must be an object.');
}

String _string(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string.');
}

int _positiveInt(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is int && value > 0) return value;
  throw FormatException('$key must be a positive integer.');
}

List<String> _nonEmptyStringList(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty string array.');
  }
  final strings = value.whereType<String>().toList(growable: false);
  if (strings.length != value.length ||
      strings.any((item) => item.isEmpty) ||
      strings.toSet().length != strings.length) {
    throw FormatException('$key must contain unique, non-empty strings.');
  }
  return strings;
}

String _renderDart(_Baseline value) =>
    '''
// Generated from tool/release_baseline.json. Do not edit.

abstract final class ReleaseBaseline {
  static const reactNativeCommit = '${value.rnCommit}';
  static const reactNativeVersion = '${value.rnVersion}';
  static const coreVersion = '${value.coreVersion}';
  static const rlnVersion = '${value.rlnVersion}';
  static const androidMavenCoordinate =
      '${value.androidCoordinate}';
  static const iosArchiveUrl =
      '${value.iosArchiveUrl}';
}
''';

String _renderSwift(_Baseline value) =>
    '''
// Generated from tool/release_baseline.json. Do not edit.

enum ReleaseBaseline {
  static let reactNativeCommit = "${value.rnCommit}"
  static let reactNativeVersion = "${value.rnVersion}"
  static let coreVersion = "${value.coreVersion}"
  static let rlnVersion = "${value.rlnVersion}"
  static let iosArchiveUrl = "${value.iosArchiveUrl}"
}
''';

String _renderKotlin(_Baseline value) =>
    '''
// Generated from tool/release_baseline.json. Do not edit.
package com.utexo.rgb_sdk_flutter

internal object ReleaseBaseline {
    const val REACT_NATIVE_COMMIT = "${value.rnCommit}"
    const val REACT_NATIVE_VERSION = "${value.rnVersion}"
    const val CORE_VERSION = "${value.coreVersion}"
    const val RLN_VERSION = "${value.rlnVersion}"
    const val ANDROID_MAVEN_COORDINATE = "${value.androidCoordinate}"
}
''';
