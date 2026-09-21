/// One validated LCOV source record. Counts are derived from line hits, not
/// trusted summary fields, so corrupt LF/LH totals cannot inflate coverage.
final class LcovRecord {
  const LcovRecord({
    required this.path,
    required this.linesFound,
    required this.linesHit,
  });

  final String path;
  final int linesFound;
  final int linesHit;
}

List<LcovRecord> parseLcov(String text) {
  final records = <LcovRecord>[];
  String? path;
  int? declaredFound;
  int? declaredHit;
  final lines = <int, int>{};
  final paths = <String>{};

  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('SF:')) {
      if (path != null) {
        throw const FormatException('Unterminated LCOV record.');
      }
      path = line.substring(3).replaceAll('\\', '/');
      final lib = path.indexOf('/lib/');
      if (lib >= 0) path = path.substring(lib + 1);
      if (path.isEmpty || !paths.add(path)) {
        throw const FormatException('Empty or duplicate LCOV source.');
      }
    } else if (line.startsWith('DA:')) {
      if (path == null) {
        throw const FormatException('LCOV line outside a source record.');
      }
      final fields = line.substring(3).split(',');
      if (fields.length < 2 || fields.length > 3) {
        throw const FormatException('Invalid LCOV line hits.');
      }
      final number = int.parse(fields[0]);
      final hits = int.parse(fields[1]);
      if (number <= 0 || hits < 0 || lines.containsKey(number)) {
        throw const FormatException('Invalid or duplicate LCOV line.');
      }
      lines[number] = hits;
    } else if (line.startsWith('LF:')) {
      if (path == null || declaredFound != null) {
        throw const FormatException('Invalid LCOV LF.');
      }
      declaredFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      if (path == null || declaredHit != null) {
        throw const FormatException('Invalid LCOV LH.');
      }
      declaredHit = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      final found = lines.length;
      final hit = lines.values.where((count) => count > 0).length;
      if (path == null || declaredFound != found || declaredHit != hit) {
        throw const FormatException('LCOV summary does not match line hits.');
      }
      records.add(LcovRecord(path: path, linesFound: found, linesHit: hit));
      path = null;
      declaredFound = null;
      declaredHit = null;
      lines.clear();
    }
  }
  if (path != null) throw const FormatException('Unterminated LCOV record.');
  return records;
}
