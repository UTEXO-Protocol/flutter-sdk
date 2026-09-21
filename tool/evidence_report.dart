import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

String fileDigest(File file) =>
    sha256.convert(file.readAsBytesSync()).toString();

const evidenceSuites = <String>{
  'release-candidate',
  'clean-consumer-matrix',
  'native-android-jvm',
  'native-ios-xctest',
  'platform-unfunded-regtest',
  'platform-funded-regtest',
  'external-signer-process-restart',
};

bool _nonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty;

File? _ownedFile(Object? path, Directory root) {
  if (path is! String || path.isEmpty) return null;
  final file = File(
    path.startsWith('<repo>/') ? '${root.path}/${path.substring(7)}' : path,
  );
  if (!file.existsSync()) return null;
  return file.resolveSymbolicLinksSync().startsWith(
        '${root.resolveSymbolicLinksSync()}/',
      )
      ? file
      : null;
}

String _git(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) throw StateError('Cannot identify candidate.');
  return result.stdout as String;
}

/// Hash tracked contents, not merely HEAD, so edits during a run invalidate it.
Map<String, Object?> candidateIdentity() {
  final files = _git(['ls-files', '-z']).split('\x00')
    ..removeWhere((p) => p.isEmpty);
  files.sort();
  final manifest = <String, Object?>{
    for (final path in files)
      path: File(path).existsSync() ? fileDigest(File(path)) : null,
  };
  return {
    'commit': _git(['rev-parse', 'HEAD']).trim(),
    'dirty': _git(['status', '--porcelain']).trim().isNotEmpty,
    'sourceSha256': sha256
        .convert(utf8.encode(jsonEncode(manifest)))
        .toString(),
    'baselineSha256': fileDigest(File('tool/release_baseline.json')),
    'provenanceSha256': fileDigest(
      File('tool/native_artifact_provenance.json'),
    ),
    'dependencyLockSha256': fileDigest(File('pubspec.lock')),
  };
}

bool sameCleanCandidate(
  Map<String, Object?> before,
  Map<String, Object?> after,
) =>
    before['dirty'] == false &&
    after['dirty'] == false &&
    const [
      'commit',
      'sourceSha256',
      'baselineSha256',
      'provenanceSha256',
      'dependencyLockSha256',
    ].every((key) => before[key] != null && before[key] == after[key]);

/// Validates a child report against the exact parent candidate and completed log.
/// A report is local run evidence, not a cryptographic provenance attestation.
List<String> evidenceReportErrors(
  Map<String, Object?> report, {
  required Map<String, Object?> candidate,
  required String runId,
  required Directory root,
}) {
  final errors = <String>[];
  if (report['schemaVersion'] != 2) errors.add('Unsupported report schema.');
  if (report['runId'] != runId) {
    errors.add('Report belongs to a different run.');
  }
  if (report['status'] != 'passed' || report['releaseEligible'] != true) {
    errors.add('Child report is not a passing clean qualification.');
  }
  final before = report['candidateStart'];
  final after = report['candidateEnd'];
  if (before is! Map<String, Object?> ||
      after is! Map<String, Object?> ||
      !sameCleanCandidate(before, after) ||
      !sameCleanCandidate(candidate, after)) {
    errors.add('Child candidate changed or differs from the parent.');
  }
  final toolchain = report['toolchain'];
  if (toolchain is! Map<String, Object?> ||
      !_nonEmptyString(toolchain['dart']) ||
      !_nonEmptyString(toolchain['architecture']) ||
      !_nonEmptyString(toolchain['host'])) {
    errors.add('Missing toolchain or host identity.');
  }
  final flutter = toolchain is Map<String, Object?>
      ? toolchain['flutter']
      : null;
  if (flutter is! Map<String, Object?> ||
      !const [
        'frameworkVersion',
        'frameworkRevision',
        'engineRevision',
        'dartSdkVersion',
        'channel',
      ].every((key) => _nonEmptyString(flutter[key]))) {
    errors.add('Missing Flutter version or revision identity.');
  }
  final suite = '${report['suite']}';
  if (!evidenceSuites.contains(suite)) errors.add('Unknown evidence suite.');
  if (suite == 'clean-consumer-matrix' && report['archivesEnabled'] != '1') {
    errors.add('Both consumer archives must be enabled.');
  }
  final device = report['device'];
  if ((suite == 'native-ios-xctest' ||
          suite.contains('regtest') ||
          suite == 'external-signer-process-restart') &&
      !_nonEmptyString(device)) {
    errors.add('Missing required device.');
  }
  if (toolchain is Map<String, Object?>) {
    final needsXcode =
        suite == 'clean-consumer-matrix' || suite == 'native-ios-xctest';
    final needsJava =
        suite == 'clean-consumer-matrix' || suite == 'native-android-jvm';
    if (needsXcode &&
        (toolchain['xcode'] is! String || toolchain['cocoapods'] is! String)) {
      errors.add('Missing Apple build-tool identity.');
    }
    if (needsJava && toolchain['java'] is! String) {
      errors.add('Missing JVM identity.');
    }
  }
  if (device is String) {
    final identity = report['deviceIdentity'];
    if (identity is! Map<String, Object?> ||
        identity['id'] != device ||
        identity['sdk'] is! String ||
        identity['targetPlatform'] is! String) {
      errors.add('Missing exact platform-device identity.');
    }
  }
  if (suite.contains('regtest') || suite == 'external-signer-process-restart') {
    final stack = report['stackIdentity'];
    final services = stack is Map<String, Object?> ? stack['services'] : null;
    if (stack is! Map<String, Object?> ||
        stack['project'] != 'rgb-sdk-flutter-regtest' ||
        services is! List<Object?> ||
        !{'bitcoind', 'electrs', 'proxy'}.every(
          (service) => services.whereType<Map<String, Object?>>().any(
            (entry) =>
                entry['service'] == service &&
                '${entry['imageId']}'.startsWith('sha256:'),
          ),
        )) {
      errors.add(
        'Missing owned-stack container and immutable image identities.',
      );
    }
  }
  final started = DateTime.tryParse('${report['startedAt']}');
  final finished = DateTime.tryParse('${report['finishedAt']}');
  if (started == null || finished == null || finished.isBefore(started)) {
    errors.add('Invalid report timestamps.');
  }
  final steps = report['steps'];
  if (steps is List<Object?>) {
    if (steps.isEmpty ||
        steps.any(
          (step) => step is! Map<String, Object?> || step['exitCode'] != 0,
        )) {
      errors.add('Missing or failed child steps.');
    }
  } else if (report['exitCode'] != 0) {
    errors.add('Missing successful exit status.');
  }
  final log = _ownedFile(report['logPath'], root);
  if (log == null || fileDigest(log) != report['logSha256']) {
    errors.add('Completed log is absent or its checksum differs.');
  }
  if (suite == 'release-candidate') {
    errors.addAll(_childManifestErrors(report, candidate, runId, root));
  }
  return errors;
}

List<String> _childManifestErrors(
  Map<String, Object?> report,
  Map<String, Object?> candidate,
  String runId,
  Directory root,
) {
  final errors = <String>[];
  final attachment = report['childrenManifest'];
  final file = attachment is Map<String, Object?>
      ? _ownedFile(attachment['path'], root)
      : null;
  if (file == null ||
      attachment is! Map<String, Object?> ||
      fileDigest(file) != attachment['sha256']) {
    return ['Missing or altered child-report manifest.'];
  }
  try {
    final manifest = jsonDecode(file.readAsStringSync());
    if (manifest is! Map<String, Object?> ||
        manifest['runId'] != runId ||
        manifest['children'] is! List<Object?>) {
      return ['Invalid child-report manifest.'];
    }
    final children = manifest['children']! as List<Object?>;
    final keys = <String>{};
    final devices = <String, Set<String>>{};
    final fundedPlatforms = <String>{};
    for (final child in children) {
      final source = child is Map<String, Object?>
          ? _ownedFile(child['path'], root)
          : null;
      if (source == null ||
          child is! Map<String, Object?> ||
          fileDigest(source) != child['sha256']) {
        errors.add('Missing or altered child report.');
        continue;
      }
      final data = jsonDecode(source.readAsStringSync());
      if (data is! Map<String, Object?> ||
          data['suite'] == 'release-candidate') {
        errors.add('Invalid or nested release child report.');
        continue;
      }
      errors.addAll(
        evidenceReportErrors(
          data,
          candidate: candidate,
          runId: runId,
          root: root,
        ),
      );
      final suite = '${data['suite']}';
      final device = '${data['device'] ?? ''}';
      final identity = data['deviceIdentity'];
      if (suite == 'platform-funded-regtest' &&
          identity is Map<String, Object?>) {
        fundedPlatforms.add('${identity['targetPlatform']}');
      }
      if (!keys.add('$suite/$device')) errors.add('Duplicate child report.');
      devices.putIfAbsent(suite, () => <String>{}).add(device);
    }
    for (final suite in [
      'clean-consumer-matrix',
      'native-android-jvm',
      'native-ios-xctest',
    ]) {
      if (devices[suite]?.length != 1) {
        errors.add('Missing $suite child report.');
      }
    }
    final platformDevices = devices['platform-funded-regtest'] ?? <String>{};
    if (children.length != 9 ||
        platformDevices.length != 2 ||
        platformDevices.contains('') ||
        !fundedPlatforms.contains('ios') ||
        !fundedPlatforms.any((platform) => platform.startsWith('android')) ||
        !platformDevices.containsAll(devices['native-ios-xctest'] ?? {''})) {
      errors.add(
        'Both platform candidates and all nine children are required.',
      );
    }
    for (final suite in [
      'platform-unfunded-regtest',
      'external-signer-process-restart',
    ]) {
      final other = devices[suite] ?? <String>{};
      if (other.length != 2 || !other.containsAll(platformDevices)) {
        errors.add('Missing matching devices for $suite.');
      }
    }
  } on FormatException {
    errors.add('Malformed child-report JSON.');
  }
  return errors;
}
