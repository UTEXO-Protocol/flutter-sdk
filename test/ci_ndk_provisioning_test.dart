import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('.github/workflows/quality.yml').readAsStringSync();
  const step = '      - name: Provision pinned Android NDK\n';
  final start = workflow.indexOf(step);
  final end = workflow.indexOf('      - name:', start + step.length);
  final block = workflow.substring(start, end);
  final script = block
      .substring(block.indexOf('        run: |\n') + '        run: |\n'.length)
      .split('\n')
      .map((line) => line.startsWith('          ') ? line.substring(10) : line)
      .join('\n');

  for (final (scenario, expectedCode, calls) in [
    ('cached', 0, 0),
    ('transient', 0, 2),
    ('wrong-version', 1, 3),
    ('broken-compiler', 1, 3),
  ]) {
    test(
      'pinned NDK provisioning handles $scenario without test retries',
      () async {
        final root = Directory.systemTemp.createTempSync('rgb-ci-ndk-');
        addTearDown(() => root.deleteSync(recursive: true));
        final sdk = '${root.path}/sdk';
        Directory('$sdk/cmdline-tools/latest/bin').createSync(recursive: true);
        Directory('${root.path}/bin').createSync();
        final ndk = '$sdk/ndk/28.2.13676358';
        Future<void> executable(String path, String content) async {
          File(path).writeAsStringSync(content);
          expect((await Process.run('chmod', ['700', path])).exitCode, 0);
        }

        await executable('${root.path}/bin/sleep', '#!/bin/sh\nexit 0\n');
        await executable(
          '$sdk/cmdline-tools/latest/bin/sdkmanager',
          r'''#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE_ROOT/calls"
count=$(wc -l < "$FIXTURE_ROOT/calls" | tr -d ' ')
if [ "$SCENARIO" = transient ] && [ "$count" = 1 ]; then exit 1; fi
ndk="$ANDROID_SDK_ROOT/ndk/28.2.13676358"
mkdir -p "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
version=28.2.13676358
if [ "$SCENARIO" = wrong-version ]; then version=99.0.0; fi
printf 'Pkg.Revision = %s\n' "$version" > "$ndk/source.properties"
status=0
if [ "$SCENARIO" = broken-compiler ]; then status=1; fi
printf '#!/bin/sh\nexit %s\n' "$status" > "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
chmod 700 "$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
''',
        );
        if (scenario == 'cached') {
          Directory(
            '$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin',
          ).createSync(recursive: true);
          File(
            '$ndk/source.properties',
          ).writeAsStringSync('Pkg.Revision = 28.2.13676358\n');
          await executable(
            '$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang',
            '#!/bin/sh\nexit 0\n',
          );
        }
        final result = await Process.run(
          'bash',
          ['-c', script],
          environment: {
            'FIXTURE_ROOT': root.path,
            'SCENARIO': scenario,
            'ANDROID_SDK_ROOT': sdk,
            'PATH': '${root.path}/bin:${Platform.environment['PATH'] ?? ''}',
          },
        );
        expect(
          result.exitCode,
          expectedCode,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final log = File('${root.path}/calls');
        final requests = log.existsSync() ? log.readAsLinesSync() : <String>[];
        expect(requests, hasLength(calls));
        expect(
          requests.every(
            (line) => line == '--install ndk;28.2.13676358 --channel=0',
          ),
          isTrue,
        );
      },
    );
  }
}
