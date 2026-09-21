import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/coverage_evidence.dart';
import '../tool/lcov.dart';

void main() {
  test('coverage exemption ends when an interface gains executable code', () {
    final root = Directory.systemTemp.createTempSync('rgb-declaration-');
    addTearDown(() => root.deleteSync(recursive: true));
    final source = File('${root.path}/interface.dart');
    for (final entry in <String, bool>{
      "export 'public.dart';": true,
      'abstract class Contract { void run(); }': true,
      'class Contract { void run() {} }': false,
      'class Contract { final value = DateTime.now(); }': false,
      'class Contract { Contract(); }': false,
      'int get value => 1;': false,
    }.entries) {
      source.writeAsStringSync(entry.key);
      expect(
        isDeclarationOnlySource(source.path),
        entry.value,
        reason: entry.key,
      );
    }
  });
  const valid =
      'SF:lib/example.dart\nDA:1,0\nDA:2,2\nLF:2\nLH:1\nend_of_record\n';
  test('coverage totals are computed from actual line records', () {
    final result = parseLcov(valid).single;
    expect(result.path, 'lib/example.dart');
    expect(result.linesFound, 2);
    expect(result.linesHit, 1);
  });
  test('corrupt coverage cannot inflate or omit evidence', () {
    for (final invalid in <String>[
      valid.replaceFirst('LH:1', 'LH:2'),
      valid.replaceFirst('LF:2', 'LF:1'),
      valid.replaceFirst('DA:1,0', 'DA:1,-1'),
      valid.replaceFirst('DA:2,2', 'DA:1,2'),
      valid.replaceFirst('end_of_record', ''),
      valid.replaceFirst('LF:2', 'LF:2\nLF:2'),
      '$valid$valid',
    ]) {
      expect(() => parseLcov(invalid), throwsFormatException);
    }
  });
}
