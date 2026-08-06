import 'dart:convert';
import 'dart:io';

const _baselinePath = 'tool/release_baseline.json';

final _forbiddenPatterns = <RegExp>[
  RegExp(r'\bbeta\.19\b', caseSensitive: false),
  RegExp(r'\b55/55\b', caseSensitive: false),
  RegExp(r'\b100%\s+(?:rn\s+)?parity\b', caseSensitive: false),
  RegExp(r'\bfully\s+production\s+ready\b', caseSensitive: false),
  RegExp(r'\brelease[- ]ready\b', caseSensitive: false),
];

void main() {
  final failures = <String>[];
  final baselineText = File(_baselinePath).readAsStringSync();
  final baseline = _readBaseline(baselineText);

  for (final path in _trackedTextFiles()) {
    if (_isExcluded(path)) continue;
    final text = File(path).readAsStringSync();
    final lines = text.split('\n');
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final pattern in _forbiddenPatterns) {
        if (pattern.hasMatch(line) && !_isAllowedNegativeClaim(line)) {
          failures.add(
            '$path:${index + 1} contains forbidden release/parity wording: '
            '${line.trim()}',
          );
        }
      }
    }
  }

  final readme = File('README.md').readAsStringSync();
  for (final expected in <String>[
    baseline.reactNativeCommit,
    '@utexo/rgb-sdk-rn` `${baseline.reactNativeVersion}`',
    '@utexo/rgb-sdk-core` `${baseline.coreVersion}`',
    'RGB Lightning Node `${baseline.rlnVersion}`',
    'Not production ready',
  ]) {
    if (!readme.contains(expected)) {
      failures.add(
        'README.md must include baseline/internal-beta safety wording: '
        '$expected',
      );
    }
  }

  if (!baselineText.contains('"reactNative"') ||
      !baselineText.contains('"core"') ||
      !baselineText.contains('"rln"')) {
    failures.add('$_baselinePath must remain the machine baseline for claims.');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Release language validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Release language validation passed.');
}

_Baseline _readBaseline(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('release_baseline.json must be an object.');
  }
  final rn = _object(decoded, 'reactNative');
  final core = _object(decoded, 'core');
  final rln = _object(decoded, 'rln');
  return _Baseline(
    reactNativeCommit: _string(rn, 'commit'),
    reactNativeVersion: _string(rn, 'version'),
    coreVersion: _string(core, 'version'),
    rlnVersion: _string(rln, 'version'),
  );
}

Map<String, Object?> _object(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is Map<String, Object?>) return value;
  throw FormatException('$_baselinePath/$key must be an object.');
}

String _string(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$_baselinePath/$key must be a non-empty string.');
}

final class _Baseline {
  const _Baseline({
    required this.reactNativeCommit,
    required this.reactNativeVersion,
    required this.coreVersion,
    required this.rlnVersion,
  });

  final String reactNativeCommit;
  final String reactNativeVersion;
  final String coreVersion;
  final String rlnVersion;
}

bool _isAllowedNegativeClaim(String line) {
  final normalized = line.toLowerCase();
  return normalized.contains('not production ready') ||
      normalized.contains('not release-ready') ||
      normalized.contains('not release ready') ||
      normalized.contains('does not make') ||
      normalized.contains('must not be mistaken for release readiness');
}

bool _isExcluded(String path) {
  if (path.startsWith('build/')) return true;
  if (path.startsWith('coverage/')) return true;
  if (path.startsWith('doc/RELEASE_READINESS_TRACKER.md')) return true;
  if (path.startsWith('CHANGELOG.md')) return true;
  if (path.endsWith('.png') ||
      path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.jar') ||
      path.endsWith('.keystore')) {
    return true;
  }
  return false;
}

List<String> _trackedTextFiles() {
  final result = Process.runSync(
    'git',
    <String>['ls-files', '--cached', '--others', '--exclude-standard'],
    stdoutEncoding: systemEncoding,
    stderrEncoding: systemEncoding,
  );
  if (result.exitCode != 0) {
    throw StateError('git ls-files failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split('\n')
      .where((line) => line.isNotEmpty)
      .where((line) => File(line).existsSync())
      .where(_looksTextual)
      .toList(growable: false);
}

bool _looksTextual(String path) {
  const suffixes = <String>{
    '.dart',
    '.md',
    '.yaml',
    '.yml',
    '.json',
    '.sh',
    '.swift',
    '.kt',
    '.kts',
    '.xml',
    '.rb',
    '.podspec',
  };
  return suffixes.any(path.endsWith) ||
      path == 'README.md' ||
      path == 'LICENSE' ||
      path == 'doc/SECURITY.md';
}
