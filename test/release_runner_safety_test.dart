import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final runner in [
    'test_clean_consumer_matrix.sh',
    'test_release_candidate.sh',
  ]) {
    test('$runner preserves a nested function failure', () async {
      final temp = Directory.systemTemp.createTempSync('rgb-runner-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final script = File('tool/$runner').absolute.path;
      final result = await Process.run(
        'bash',
        [
          '-c',
          '''
source "\$1"
failure() { false; printf 'MASKED_FAILURE'; }
run_step injected-failure failure
[[ "\$FAILED" == 1 && "\${STEP_CODES[0]}" == 1 ]]
''',
          'runner-test',
          script,
        ],
        environment: {
          'REPORT_DIR': temp.path,
          'CONSUMER_WORK_DIR': '${temp.path}/consumer',
        },
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, isNot(contains('MASKED_FAILURE')));
    });
  }

  test(
    'required skips can never be overridden into a passing release',
    () async {
      final temp = Directory.systemTemp.createTempSync('rgb-skip-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final result = await Process.run(
        'bash',
        [
          '-c',
          '''
source "\$1"
mark_required_skip native-test missing-device
[[ "\$FAILED" == 1 && "\${STEP_CODES[0]}" == 125 ]]
''',
          'runner-test',
          File('tool/test_release_candidate.sh').absolute.path,
        ],
        environment: {'REPORT_DIR': temp.path, 'ALLOW_SKIPPED': '1'},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test('release finalizer hashes the finished log even on failure', () async {
    final temp = Directory.systemTemp.createTempSync('rgb-log-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final result = await Process.run(
      'bash',
      [
        '-c',
        '''
source "\$1"
start_logging
trap finalize EXIT
printf 'final-log-line\\n'
exit 42
''',
        'runner-test',
        File('tool/test_release_candidate.sh').absolute.path,
      ],
      environment: {'REPORT_DIR': temp.path},
    );
    expect(result.exitCode, 42, reason: '${result.stdout}\n${result.stderr}');
    final reportFile = temp.listSync().whereType<File>().singleWhere(
      (f) => f.path.endsWith('.json'),
    );
    final report =
        jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
    final log = temp.listSync().whereType<File>().singleWhere(
      (f) => f.path.endsWith('.log'),
    );
    expect(log.readAsStringSync(), contains('final-log-line'));
    expect(
      report['logSha256'],
      sha256.convert(log.readAsBytesSync()).toString(),
    );
    expect(report['releaseEligible'], false);
    expect(report['status'], 'failed');
  });
}
