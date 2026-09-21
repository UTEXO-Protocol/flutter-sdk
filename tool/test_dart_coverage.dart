import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'coverage_evidence.dart';

/// Runs coverage and records a content-bound receipt only after all tests pass.
Future<void> main() async {
  final receipt = File('coverage/evidence.json');
  if (receipt.existsSync()) receipt.deleteSync();
  final lcov = File('coverage/lcov.info');
  if (lcov.existsSync()) lcov.deleteSync();
  final before = coverageInputHash();
  final commit = coverageCommit();
  final started = DateTime.now().toUtc();
  final process = await Process.start(
    Platform.environment['FLUTTER_BIN'] ?? 'flutter',
    ['test', '--coverage', '--coverage-package=rgb_sdk_flutter'],
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    exitCode = result;
    return;
  }
  if (coverageInputHash() != before || coverageCommit() != commit) {
    stderr.writeln('Coverage inputs changed during the test run.');
    exitCode = 1;
    return;
  }
  if (!lcov.existsSync()) throw StateError('Tests produced no LCOV.');
  receipt.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'schemaVersion': 1, 'commit': commit, 'inputSha256': before, 'sourceFiles': coverageSources(), 'lcovSha256': sha256.convert(lcov.readAsBytesSync()).toString(), 'startedAt': started.toIso8601String(), 'finishedAt': DateTime.now().toUtc().toIso8601String(), 'exitCode': result})}\n',
  );
}
