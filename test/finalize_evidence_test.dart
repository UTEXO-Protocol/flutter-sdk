import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/finalize_evidence.dart' show simulatorDeviceIdentity;

const _destination = '11111111-2222-3333-4444-555555555555';
const _clone = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
const _runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0';
const _model = 'com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro';

Map<String, Object?> _devices() => {
  _runtime: [
    {
      'udid': _destination,
      'name': 'Qualification destination',
      'state': 'Shutdown',
      'isAvailable': true,
      'deviceTypeIdentifier': _model,
    },
    {
      'udid': _clone,
      'name': 'Clone 1 of Qualification destination',
      'state': 'Booted',
      'isAvailable': true,
      'deviceTypeIdentifier': _model,
    },
  ],
};
List<Object?> _runtimes() => [
  {
    'identifier': _runtime,
    'version': '27.0',
    'buildversion': '24A434',
    'isAvailable': true,
  },
];
List<Object?> _types() => [
  {'identifier': _model, 'name': 'iPhone 18 Pro'},
];

void main() {
  test('shutdown simulator identity uses exact UUID, runtime and model', () {
    Map<String, Object?>? resolve({
      String id = _destination,
      Object? devices,
      Object? runtimes,
      Object? types,
    }) => simulatorDeviceIdentity(
      id,
      devices: devices ?? _devices(),
      runtimes: runtimes ?? _runtimes(),
      deviceTypes: types ?? _types(),
    );
    final identity = resolve()!;
    expect(identity['id'], _destination);
    expect(identity['name'], 'Qualification destination');
    expect(identity['state'], 'Shutdown');
    expect(identity['sdk'], 'iOS 27.0 (24A434)');
    expect(identity['model'], 'iPhone 18 Pro');
    expect(identity['runtimeIdentifier'], _runtime);
    expect(resolve(id: 'Qualification destination'), isNull);
    expect(resolve(id: '99999999-2222-3333-4444-555555555555'), isNull);
    expect(resolve(runtimes: <Object?>[]), isNull);
    expect(resolve(types: <Object?>[]), isNull);
    expect(
      resolve(
        devices: {
          _runtime: [(_devices()[_runtime]! as List).last],
        },
      ),
      isNull,
    );
    expect(
      resolve(
        devices: {
          _runtime: [
            {
              ...((_devices()[_runtime]! as List).first as Map),
              'isAvailable': false,
            },
          ],
        },
      ),
      isNull,
    );
    expect(
      resolve(
        devices: {
          _runtime: [
            ...(_devices()[_runtime]! as List),
            (_devices()[_runtime]! as List).first,
          ],
        },
      ),
      isNull,
    );
    expect(
      resolve(
        runtimes: [
          {...(_runtimes().single! as Map), 'isAvailable': false},
        ],
      ),
      isNull,
    );
  });

  for (final strict in [false, true]) {
    test(
      'dirty candidate keeps raw passed status but ${strict ? 'fails qualification' : 'allows diagnostic exit'}',
      () async {
        final fixture = await _Fixture.create();
        addTearDown(fixture.dispose);
        await fixture.start();
        await File(
          '${fixture.root.path}/candidate.txt',
        ).writeAsString('changed');
        final result = await fixture.finish(strict: strict);
        expect(
          result.exitCode,
          strict ? 1 : 0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final report = fixture.report();
        expect(report['status'], 'passed');
        expect(report['releaseEligible'], false);
        expect(report['candidateQualification'], 'dirty-or-changed');
      },
    );
  }

  test(
    'headless finalizer discovers exact shutdown CI destination without booting',
    () async {
      final fixture = await _Fixture.create(device: _destination);
      addTearDown(fixture.dispose);
      await fixture.start();
      final result = await fixture.finish(strict: true);
      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}\n${fixture.report()}',
      );
      final report = fixture.report();
      expect(report['releaseEligible'], true);
      final identity = report['deviceIdentity']! as Map<String, Object?>;
      expect(identity['id'], _destination);
      expect(identity['state'], 'Shutdown');
      expect(identity['runtimeIdentifier'], _runtime);
      expect(identity['modelIdentifier'], _model);
      final calls = File(
        '${fixture.root.path}/build/simctl-calls',
      ).readAsLinesSync();
      expect(calls.toSet(), {
        'simctl list devices available --json',
        'simctl list runtimes --json',
        'simctl list devicetypes --json',
      });
    },
  );

  test(
    'same-name managed clone cannot qualify a missing destination',
    () async {
      final fixture = await _Fixture.create(
        device: '99999999-2222-3333-4444-555555555555',
      );
      addTearDown(fixture.dispose);
      await fixture.start();
      final result = await fixture.finish(strict: true);
      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(fixture.report()['releaseEligible'], false);
      expect(fixture.report()['deviceIdentity'], isNull);
    },
  );
}

final class _Fixture {
  _Fixture(this.root, this.script, this.device);
  final Directory root;
  final String script;
  final String? device;

  static Future<_Fixture> create({String? device}) async {
    final root = Directory(
      Directory.systemTemp
          .createTempSync('rgb-finalize-evidence-')
          .resolveSymbolicLinksSync(),
    );
    final fixture = _Fixture(
      root,
      File('tool/finalize_evidence.dart').absolute.path,
      device,
    );
    for (final path in ['tool', 'build', 'bin']) {
      Directory('${root.path}/$path').createSync();
    }
    File('${root.path}/.gitignore').writeAsStringSync('build/\nbin/\n');
    File('${root.path}/candidate.txt').writeAsStringSync('original');
    for (final path in [
      'tool/release_baseline.json',
      'tool/native_artifact_provenance.json',
    ]) {
      File('${root.path}/$path').writeAsStringSync('{}');
    }
    File('${root.path}/pubspec.lock').writeAsStringSync('fixture');
    for (final args in [
      ['init', '-q'],
      ['add', '.'],
      [
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.invalid',
        'commit',
        '-qm',
        'fixture',
      ],
    ]) {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: root.path,
      );
      if (result.exitCode != 0) throw StateError('${result.stderr}');
    }
    final flutterVersion = jsonEncode({
      'frameworkVersion': '3.47.7',
      'frameworkRevision': 'framework',
      'engineRevision': 'engine',
      'dartSdkVersion': '3.13',
      'channel': 'stable',
    });
    await fixture._executable('flutter', '''#!/bin/sh
if [ "\$1" = devices ]; then printf '%s\\n' '[]'; else printf '%s\\n' '$flutterVersion'; fi
''');
    await fixture._executable(
      'xcodebuild',
      '#!/bin/sh\nprintf "Xcode 27\\n"\n',
    );
    await fixture._executable('pod', '#!/bin/sh\nprintf "1.16.2\\n"\n');
    await fixture._executable(
      'java',
      '#!/bin/sh\nprintf \'openjdk version "17"\\n\'\n',
    );
    File(
      '${root.path}/build/devices.json',
    ).writeAsStringSync(jsonEncode({'devices': _devices()}));
    File(
      '${root.path}/build/runtimes.json',
    ).writeAsStringSync(jsonEncode({'runtimes': _runtimes()}));
    File(
      '${root.path}/build/devicetypes.json',
    ).writeAsStringSync(jsonEncode({'devicetypes': _types()}));
    await fixture._executable('xcrun', '''#!/bin/sh
printf '%s\\n' "\$*" >> build/simctl-calls
case "\$*" in
  'simctl list devices available --json') cat build/devices.json ;;
  'simctl list runtimes --json') cat build/runtimes.json ;;
  'simctl list devicetypes --json') cat build/devicetypes.json ;;
  *) exit 97 ;;
esac
''');
    File('${root.path}/build/run.log').writeAsStringSync('completed\n');
    File('${root.path}/build/report.json').writeAsStringSync(
      jsonEncode({
        'suite': device == null ? 'native-android-jvm' : 'native-ios-xctest',
        'status': 'passed',
        'runId': 'run',
        'exitCode': 0,
        'device': ?device,
      }),
    );
    return fixture;
  }

  Future<void> _executable(String name, String content) async {
    final file = File('${root.path}/bin/$name')..writeAsStringSync(content);
    final result = await Process.run('chmod', ['700', file.path]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  Future<ProcessResult> _run(List<String> args, {bool strict = false}) =>
      Process.run(
        Platform.environment['DART_BIN'] ?? 'dart',
        [script, ...args],
        workingDirectory: root.path,
        environment: {
          'PATH': '${root.path}/bin:${Platform.environment['PATH'] ?? ''}',
          'FLUTTER_BIN': '${root.path}/bin/flutter',
          'EVIDENCE_LOG_PATH': '${root.path}/build/run.log',
          'RELEASE_RUN_ID': 'run',
          'REQUIRE_RELEASE_ELIGIBLE': strict ? '1' : '0',
        },
      );

  Future<void> start() async {
    final result = await _run(['start', 'build/snapshot.json']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }

  Future<ProcessResult> finish({required bool strict}) => _run([
    'finish',
    'build/snapshot.json',
    'build/report.json',
  ], strict: strict);
  Map<String, Object?> report() =>
      jsonDecode(File('${root.path}/build/report.json').readAsStringSync())
          as Map<String, Object?>;
  Future<void> dispose() => root.delete(recursive: true);
}
