import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mutation in [false, true]) {
    test(
      'native iOS runner locks Flutter CocoaPods install and ${mutation ? 'rejects lock drift before XCTest' : 'keeps explicit install in deployment mode'}',
      () async {
        final root = Directory.systemTemp.createTempSync('rgb-ios-pod-lock-');
        addTearDown(() => root.deleteSync(recursive: true));
        for (final path in ['tool', 'bin', 'example/ios', 'reports']) {
          Directory('${root.path}/$path').createSync(recursive: true);
        }
        File(
          'tool/test_native_ios.sh',
        ).copySync('${root.path}/tool/test_native_ios.sh');
        File(
          'tool/evidence_shell.sh',
        ).copySync('${root.path}/tool/evidence_shell.sh');
        File(
          '${root.path}/example/ios/Podfile.lock',
        ).writeAsStringSync('locked dependency fixture\n');
        Future<void> executable(String name, String content) async {
          final file = File('${root.path}/bin/$name')
            ..writeAsStringSync(content);
          final result = await Process.run('chmod', ['700', file.path]);
          expect(result.exitCode, 0);
        }

        await executable('pod', r'''#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE_ROOT/reports/pod-calls"
[ "$1" = install ] || exit 0
case " $* " in *' --deployment '*) ;; *) exit 74 ;; esac
case " $* " in *' --no-repo-update '*) ;; *) exit 75 ;; esac
''');
        await executable('flutter', '''#!/bin/sh
# Mimic Flutter's own CocoaPods subprocess before config-only returns.
pod install --verbose || exit \$?
${mutation ? 'printf \'changed dependency fixture\\n\' > ios/Podfile.lock' : ':'}
''');
        await executable('dart', '#!/bin/sh\nexit 0\n');
        await executable('xcodebuild', r'''#!/bin/sh
printf 'xctest invoked\n' > "$FIXTURE_ROOT/reports/xctest-invoked"
''');
        final result = await Process.run(
          'bash',
          ['tool/test_native_ios.sh'],
          workingDirectory: root.path,
          environment: {
            'FIXTURE_ROOT': root.path,
            'PATH': '${root.path}/bin:${Platform.environment['PATH'] ?? ''}',
            'DART_BIN': '${root.path}/bin/dart',
            'FLUTTER_BIN': '${root.path}/bin/flutter',
            'POD_BIN': '${root.path}/bin/pod',
            'DEVICE': '11111111-2222-3333-4444-555555555555',
            'REPORT_DIR': '${root.path}/reports',
            'REQUIRE_RELEASE_ELIGIBLE': '0',
          },
        );
        expect(
          result.exitCode,
          mutation ? 1 : 0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final calls = File('${root.path}/reports/pod-calls').readAsLinesSync();
        expect(calls, hasLength(mutation ? 1 : 2));
        for (final call in calls) {
          expect(call, contains('--deployment'));
          expect(call, contains('--no-repo-update'));
        }
        expect(
          File('${root.path}/reports/xctest-invoked').existsSync(),
          !mutation,
        );
        if (mutation) {
          expect(
            result.stdout,
            contains(
              'Flutter configuration changed the locked iOS dependencies',
            ),
          );
        }
      },
    );
  }
}
