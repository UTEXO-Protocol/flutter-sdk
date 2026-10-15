import 'dart:convert';
import 'dart:io';

import 'evidence_report.dart';

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void _write(String path, Map<String, Object?> value) => File(
  path,
).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');

Object? _labelLocalPaths(Object? value) {
  if (value is String) {
    return value.replaceAll(Directory.current.path, '<repo>');
  }
  if (value is List<Object?>) return value.map(_labelLocalPaths).toList();
  if (value is Map<String, Object?>) {
    return value.map((key, item) => MapEntry(key, _labelLocalPaths(item)));
  }
  return value;
}

Future<String?> _probe(String command, List<String> args) async {
  try {
    final process = await Process.start(command, args);
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode.timeout(
      const Duration(seconds: 30),
      onTimeout: () async {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        return -1;
      },
    );
    final output = '${await stdout}\n${await stderr}'.trim();
    return code == 0 ? output : null;
  } on ProcessException {
    return null;
  }
}

/// Resolves one exact available simulator UUID from read-only simctl records.
/// Device names are deliberately not used for matching: XCTest may run managed
/// clones while the requested destination remains shut down.
Map<String, Object?>? simulatorDeviceIdentity(
  String id, {
  required Object? devices,
  required Object? runtimes,
  required Object? deviceTypes,
}) {
  if (!RegExp(
        r'^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
      ).hasMatch(id) ||
      devices is! Map<String, Object?> ||
      runtimes is! List<Object?> ||
      deviceTypes is! List<Object?>) {
    return null;
  }
  final matches = <Map<String, Object?>>[];
  for (final group in devices.entries) {
    if (group.value is! List<Object?>) continue;
    for (final device
        in (group.value! as List<Object?>).whereType<Map<String, Object?>>()) {
      if ('${device['udid']}'.toUpperCase() != id.toUpperCase() ||
          device['isAvailable'] != true) {
        continue;
      }
      final runtimeMatches = runtimes.whereType<Map<String, Object?>>().where(
        (runtime) =>
            runtime['identifier'] == group.key &&
            group.key.startsWith('com.apple.CoreSimulator.SimRuntime.iOS-') &&
            runtime['isAvailable'] == true &&
            runtime['version'] is String &&
            (runtime['version']! as String).isNotEmpty &&
            runtime['buildversion'] is String &&
            (runtime['buildversion']! as String).isNotEmpty,
      );
      final modelMatches = deviceTypes.whereType<Map<String, Object?>>().where(
        (model) =>
            model['identifier'] == device['deviceTypeIdentifier'] &&
            model['name'] is String &&
            (model['name']! as String).isNotEmpty,
      );
      if (runtimeMatches.length != 1 || modelMatches.length != 1) return null;
      final runtime = runtimeMatches.single;
      matches.add({
        'id': id,
        'name': device['name'],
        'targetPlatform': 'ios',
        'sdk': 'iOS ${runtime['version']} (${runtime['buildversion']})',
        'emulator': true,
        'identitySource': 'simctl-exact-available-uuid',
        'runtimeIdentifier': runtime['identifier'],
        'runtimeVersion': runtime['version'],
        'runtimeBuild': runtime['buildversion'],
        'modelIdentifier': device['deviceTypeIdentifier'],
        'model': modelMatches.single['name'],
        'state': device['state'],
      });
    }
  }
  return matches.length == 1 ? matches.single : null;
}

Object? _jsonOrNull(String? text) {
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

Future<Map<String, Object?>?> _device(String id) async {
  final text = await _probe(Platform.environment['FLUTTER_BIN'] ?? 'flutter', [
    'devices',
    '--machine',
  ]);
  final flutterDevices = _jsonOrNull(text);
  if (flutterDevices is List<Object?>) {
    for (final device in flutterDevices.whereType<Map<String, Object?>>()) {
      if (device['id'] == id) {
        return {
          for (final key in ['id', 'name', 'targetPlatform', 'sdk', 'emulator'])
            key: device[key],
        };
      }
    }
  }
  // Read-only discovery works for shutdown destinations and managed XCTest
  // clones too. Never boot, select a same-name device, or manufacture an OS.
  final inventories = await Future.wait([
    _probe('xcrun', ['simctl', 'list', 'devices', 'available', '--json']),
    _probe('xcrun', ['simctl', 'list', 'runtimes', '--json']),
    _probe('xcrun', ['simctl', 'list', 'devicetypes', '--json']),
  ]);
  final devices = _jsonOrNull(inventories[0]);
  final runtimes = _jsonOrNull(inventories[1]);
  final types = _jsonOrNull(inventories[2]);
  return simulatorDeviceIdentity(
    id,
    devices: devices is Map<String, Object?> ? devices['devices'] : null,
    runtimes: runtimes is Map<String, Object?> ? runtimes['runtimes'] : null,
    deviceTypes: types is Map<String, Object?> ? types['devicetypes'] : null,
  );
}

Future<List<Map<String, Object?>>> _stackImages() async {
  // Fixed SDK-owned project: never enumerate or inspect another app's stack.
  final ids = await _probe('docker', [
    'compose',
    '-p',
    'rgb-sdk-flutter-regtest',
    '-f',
    'tool/regtest/compose.yaml',
    'ps',
    '-q',
  ]);
  if (ids == null || ids.isEmpty) return [];
  final result = <Map<String, Object?>>[];
  for (final id in ids.split('\n').where((id) => id.isNotEmpty)) {
    final text = await _probe('docker', [
      'inspect',
      '--format',
      '{"containerId":{{json .Id}},"imageId":{{json .Image}},"service":{{json (index .Config.Labels "com.docker.compose.service")}}}',
      id,
    ]);
    if (text == null) continue;
    result.add(jsonDecode(text) as Map<String, Object?>);
  }
  return result;
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError(
      'Expected start <snapshot> or finish <snapshot> <report>.',
    );
  }
  if (args[0] == 'start') {
    final flutter = await Process.run(
      Platform.environment['FLUTTER_BIN'] ?? 'flutter',
      ['--version', '--machine'],
    );
    if (flutter.exitCode != 0) throw StateError('Cannot identify Flutter.');
    final flutterVersion =
        jsonDecode(flutter.stdout as String) as Map<String, Object?>;
    _write(args[1], {
      'candidate': candidateIdentity(),
      'startedAt': DateTime.now().toUtc().toIso8601String(),
      'toolchain': {
        'dart': Platform.version,
        'flutter': {
          for (final key in [
            'frameworkVersion',
            'frameworkRevision',
            'engineRevision',
            'dartSdkVersion',
            'channel',
          ])
            key: flutterVersion[key],
        },
        'host':
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'architecture': await _probe('uname', ['-m']),
        'xcode': Platform.isMacOS
            ? await _probe('xcodebuild', ['-version'])
            : null,
        'cocoapods': Platform.isMacOS
            ? await _probe('pod', ['--version'])
            : null,
        'java': RegExp(
          r'(?:openjdk|java) version "[^"]+"',
        ).firstMatch(await _probe('java', ['-version']) ?? '')?.group(0),
      },
    });
    return;
  }
  if (args[0] != 'finish' || args.length != 3) {
    throw ArgumentError('Invalid command.');
  }
  final snapshot = _read(args[1]);
  final report = _read(args[2]);
  final before = snapshot['candidate'] as Map<String, Object?>;
  final after = candidateIdentity();
  final log = File(Platform.environment['EVIDENCE_LOG_PATH'] ?? '');
  if (!log.existsSync()) {
    throw StateError('Cannot finalize without the completed log.');
  }
  report.addAll({
    'schemaVersion': 2,
    'runId': Platform.environment['RELEASE_RUN_ID'] ?? report['runId'],
    'candidateStart': before,
    'candidateEnd': after,
    'toolchain': snapshot['toolchain'],
    'startedAt': snapshot['startedAt'],
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'logPath': log.absolute.path.startsWith('${Directory.current.path}/')
        ? '<repo>/${log.absolute.path.substring(Directory.current.path.length + 1)}'
        : log.absolute.path,
    'logSha256': fileDigest(log),
    'releaseEligible':
        report['status'] == 'passed' && sameCleanCandidate(before, after),
  });
  final device = report['device'];
  if (device is String) report['deviceIdentity'] = await _device(device);
  if (report['suite'] != 'platform-onchain-regtest' &&
      report['regtest'] is Map<String, Object?>) {
    report['stackIdentity'] = {
      'project': 'rgb-sdk-flutter-regtest',
      'composeSha256': fileDigest(File('tool/regtest/compose.yaml')),
      'services': await _stackImages(),
    };
  }
  if (report['suite'] == 'release-candidate') {
    final children = File(
      '${log.parent.path}/children-${report['runId']}.json',
    );
    if (!children.existsSync()) {
      report['releaseEligible'] = false;
      report['status'] = 'failed';
    } else {
      report['childrenManifest'] = {
        'path': children.path,
        'sha256': fileDigest(children),
      };
    }
  }
  if (!sameCleanCandidate(before, after)) {
    report['releaseEligible'] = false;
    report['candidateQualification'] = 'dirty-or-changed';
  }
  if (!log.absolute.path.startsWith('${Directory.current.path}/')) {
    report['releaseEligible'] = false;
    report['artifactPathScope'] = 'external-debug-only';
  }
  if (report['releaseEligible'] == true) {
    final errors = evidenceReportErrors(
      report,
      candidate: before,
      runId: '${report['runId']}',
      root: Directory.current,
    );
    if (errors.isNotEmpty) {
      report['releaseEligible'] = false;
      report['status'] = 'failed';
      report['evidenceErrors'] = errors;
    }
  }
  _write(args[2], _labelLocalPaths(report) as Map<String, Object?>);
  if (report['status'] == 'failed' ||
      (Platform.environment['REQUIRE_RELEASE_ELIGIBLE'] == '1' &&
          report['releaseEligible'] != true)) {
    stderr.writeln('Evidence is not a passing release-eligible qualification.');
    exitCode = 1;
  }
}
