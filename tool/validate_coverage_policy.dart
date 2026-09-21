import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'coverage_evidence.dart';
import 'lcov.dart';

const _coveragePath = 'coverage/lcov.info';

const _thresholds = <String, double>{
  'package': 65.0,
  'lib/src/wallet/': 80.0,
  'lib/src/lsp/': 65.0,
  'lib/src/crypto/': 70.0,
  'lib/src/models/': 70.0,
};

void main() {
  final file = File(_coveragePath);
  if (!file.existsSync()) {
    stderr.writeln(
      'Coverage policy validation failed: missing $_coveragePath. '
      'Run `dart run tool/test_dart_coverage.dart` first.',
    );
    exit(1);
  }

  final records = parseLcov(
    file.readAsStringSync(),
  ).where((record) => _includedSource(record.path)).toList(growable: false);
  if (records.isEmpty) {
    stderr.writeln('Coverage policy validation failed: no included sources.');
    exit(1);
  }

  final failures = <String>[];
  final sources = coverageSources().toSet();
  final recordedSources = records.map((record) => record.path).toSet();
  for (final missing in sources.difference(recordedSources)) {
    if (!isDeclarationOnlySource(missing)) {
      failures.add('LCOV omits current executable source $missing.');
    }
  }
  if (recordedSources.length != records.length) {
    failures.add('LCOV contains duplicate source records.');
  }
  for (final stale in recordedSources.difference(sources)) {
    failures.add('LCOV contains stale source $stale.');
  }
  final receiptFile = File('coverage/evidence.json');
  if (!receiptFile.existsSync()) {
    failures.add('Missing coverage receipt; run tool/test_dart_coverage.dart.');
  } else {
    try {
      final receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, Object?>;
      if (receipt['schemaVersion'] != 1 ||
          receipt['exitCode'] != 0 ||
          receipt['commit'] != coverageCommit() ||
          receipt['inputSha256'] != coverageInputHash() ||
          receipt['lcovSha256'] !=
              sha256.convert(file.readAsBytesSync()).toString() ||
          jsonEncode(receipt['sourceFiles']) != jsonEncode(coverageSources())) {
        failures.add(
          'Coverage receipt does not match the current source, tests, commit, or LCOV.',
        );
      }
    } on Object {
      failures.add('Coverage receipt is malformed.');
    }
  }
  _checkBucket('package', records, failures);
  for (final prefix in _thresholds.keys.where((key) => key != 'package')) {
    _checkBucket(
      prefix,
      records.where((record) => record.path.startsWith(prefix)),
      failures,
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Coverage policy validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Coverage policy validation passed.');
  for (final entry in _thresholds.entries) {
    final bucketRecords = entry.key == 'package'
        ? records
        : records.where((record) => record.path.startsWith(entry.key));
    final coverage = _coverage(bucketRecords);
    stdout.writeln(
      '- ${entry.key}: ${coverage.toStringAsFixed(1)}% '
      '(minimum ${entry.value.toStringAsFixed(1)}%)',
    );
  }
}

bool _includedSource(String path) {
  if (!path.startsWith('lib/')) return false;
  if (path.startsWith('lib/src/pigeon/')) return false;
  if (path == 'lib/src/release_baseline.g.dart') return false;
  return true;
}

void _checkBucket(
  String label,
  Iterable<LcovRecord> records,
  List<String> failures,
) {
  final threshold = _thresholds[label]!;
  final coverage = _coverage(records);
  if (coverage < threshold) {
    failures.add(
      '$label coverage is ${coverage.toStringAsFixed(1)}%, below '
      '${threshold.toStringAsFixed(1)}%.',
    );
  }
}

double _coverage(Iterable<LcovRecord> records) {
  var found = 0;
  var hit = 0;
  for (final record in records) {
    found += record.linesFound;
    hit += record.linesHit;
  }
  if (found == 0) return 0;
  return hit * 100 / found;
}
