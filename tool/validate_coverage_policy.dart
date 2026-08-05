import 'dart:io';

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
      'Run `flutter test --coverage` first.',
    );
    exit(1);
  }

  final records = _parseLcov(
    file.readAsStringSync(),
  ).where((record) => _includedSource(record.path)).toList(growable: false);
  if (records.isEmpty) {
    stderr.writeln('Coverage policy validation failed: no included sources.');
    exit(1);
  }

  final failures = <String>[];
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
  Iterable<_LcovRecord> records,
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

double _coverage(Iterable<_LcovRecord> records) {
  var found = 0;
  var hit = 0;
  for (final record in records) {
    found += record.linesFound;
    hit += record.linesHit;
  }
  if (found == 0) return 0;
  return hit * 100 / found;
}

List<_LcovRecord> _parseLcov(String text) {
  final records = <_LcovRecord>[];
  String? path;
  int? linesFound;
  int? linesHit;

  void flush() {
    if (path != null && linesFound != null && linesHit != null) {
      records.add(
        _LcovRecord(
          path: _repoRelative(path!),
          linesFound: linesFound!,
          linesHit: linesHit!,
        ),
      );
    }
    path = null;
    linesFound = null;
    linesHit = null;
  }

  for (final line in text.split('\n')) {
    if (line.startsWith('SF:')) {
      flush();
      path = line.substring(3);
    } else if (line.startsWith('LF:')) {
      linesFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();
  return records;
}

String _repoRelative(String path) {
  final normalized = path.replaceAll('\\', '/');
  final libIndex = normalized.indexOf('/lib/');
  if (libIndex >= 0) return normalized.substring(libIndex + 1);
  if (normalized.startsWith('lib/')) return normalized;
  return normalized;
}

class _LcovRecord {
  const _LcovRecord({
    required this.path,
    required this.linesFound,
    required this.linesHit,
  });

  final String path;
  final int linesFound;
  final int linesHit;
}
