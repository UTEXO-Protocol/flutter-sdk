import 'dart:convert';
import 'dart:io';

const _osvQueryBatchUrl = 'https://api.osv.dev/v1/querybatch';
const _osvTimeout = Duration(seconds: 20);
const _allowNetworkSkipEnv = 'ALLOW_SUPPLY_CHAIN_NETWORK_SKIP';
const _allowedLicenseClassifications = <String>{
  'Apache-2.0',
  'BSD-2-Clause-like',
  'BSD-3-Clause-like',
  'Flutter-SDK-bundled',
  'MIT',
  'MPL-2.0',
};
const _restrictedLicensePatterns = <String>[
  'gnu general public license',
  'gnu affero general public license',
  'server side public license',
  'business source license',
  'elastic license',
  'commons clause',
  'non-commercial',
  'noncommercial',
];

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _commitPattern = RegExp(r'^[0-9a-f]{40}$');
final _requiredSymbolMarkers = <String>[
  'UNIFFI_META_NAMESPACE_RGB_LIGHTNING_NODE',
  'UNIFFI_META_UDL_RGB_LIGHTNING_NODE',
  'UNIFFI_META_RGB_LIGHTNING_NODE_METHOD_SDKNODE_INIT_WITH_NATIVE_EXTERNAL_SIGNER',
  'UNIFFI_META_RGB_LIGHTNING_NODE_METHOD_SDKNODE_UNLOCK_WITH_NATIVE_EXTERNAL_SIGNER',
  'UNIFFI_META_RGB_LIGHTNING_NODE_METHOD_SDKNODE_ATTACH_NATIVE_EXTERNAL_SIGNER',
  'UNIFFI_META_RGB_LIGHTNING_NODE_INTERFACE_NATIVEEXTERNALSIGNER',
  'uniffi_rgb_lightning_node_fn_func_uniffi_healthcheck',
];

Future<void> main(List<String> args) async {
  final production = args.contains('--production');
  final failures = <String>[];
  final warnings = <String>[];
  final report = <String, Object?>{
    'suite': 'supply-chain',
    'mode': production ? 'production' : 'internal-beta',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'repositoryDirty': _gitDirty(),
  };

  final baseline =
      jsonDecode(File('tool/release_baseline.json').readAsStringSync())
          as Map<String, Object?>;
  final rln = baseline['rln']! as Map<String, Object?>;
  final ios = rln['ios']! as Map<String, Object?>;
  final android = rln['android']! as Map<String, Object?>;

  _validateBaseline(
    baseline: baseline,
    rln: rln,
    ios: ios,
    android: android,
    failures: failures,
  );
  report['baseline'] = <String, Object?>{
    'reactNativeCommit': _at<Map<String, Object?>>(
      baseline,
      'reactNative',
    )?['commit'],
    'rlnCommit': rln['commit'],
    'rlnVersion': rln['version'],
    'releaseTier': baseline['releaseTier'],
  };

  final dependencies = _dependencyInventory(failures, warnings);
  report['dartDependencies'] = dependencies;
  report['licensePolicy'] = _licensePolicyReport(dependencies, failures);
  report['vulnerabilityAudit'] = await _vulnerabilityAudit(
    dependencies,
    failures,
    warnings,
  );

  final nativeReport = <String, Object?>{};
  nativeReport['ios'] = _validateIosSymbols(ios, failures, warnings);
  nativeReport['android'] = _validateAndroidArtifact(
    android,
    failures,
    warnings,
  );
  report['nativeArtifacts'] = nativeReport;

  final provenance = <String, Object?>{
    'sourcePins': 'present',
    'checksums': 'present',
    'upstreamSignatures': 'absent',
    'reproducibleBuildAttestation': 'absent',
    'productionReady': false,
  };
  report['provenance'] = provenance;
  if (production) {
    failures.add(
      'production provenance is not satisfied: upstream artifact signatures '
      'and reproducible build attestations are absent.',
    );
  } else {
    warnings.add(
      'upstream artifact signatures and reproducible build attestations are '
      'absent; this can only pass as an internal-beta gate.',
    );
  }

  report['warnings'] = warnings;
  report['failures'] = failures;
  _writeReport(report);

  if (failures.isNotEmpty) {
    stderr.writeln('Supply-chain validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Supply-chain validation passed.');
  if (warnings.isNotEmpty) {
    stdout.writeln('Warnings:');
    for (final warning in warnings) {
      stdout.writeln('- $warning');
    }
  }
}

void _validateBaseline({
  required Map<String, Object?> baseline,
  required Map<String, Object?> rln,
  required Map<String, Object?> ios,
  required Map<String, Object?> android,
  required List<String> failures,
}) {
  final rn = baseline['reactNative']! as Map<String, Object?>;
  final core = baseline['core']! as Map<String, Object?>;
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('reactNative.repository', rn['repository']),
    MapEntry('core.repository', core['repository']),
    MapEntry('rln.repository', rln['repository']),
    MapEntry('rln.ios.archiveUrl', ios['archiveUrl']),
    MapEntry('rln.android.archiveUrl', android['archiveUrl']),
  ]) {
    final value = entry.value?.toString() ?? '';
    if (!value.startsWith('https://')) {
      failures.add('${entry.key} must be an https URL.');
    }
  }
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('reactNative.commit', rn['commit']),
    MapEntry('rln.commit', rln['commit']),
  ]) {
    final value = entry.value?.toString() ?? '';
    if (!_commitPattern.hasMatch(value)) {
      failures.add('${entry.key} must be a full 40-character commit hash.');
    }
  }
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('rln.ios.archiveSha256', ios['archiveSha256']),
    MapEntry('rln.android.archiveSha256', android['archiveSha256']),
  ]) {
    final value = entry.value?.toString() ?? '';
    if (!_sha256Pattern.hasMatch(value)) {
      failures.add('${entry.key} must be a lowercase SHA-256 digest.');
    }
  }
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('rln.ios.archiveSizeBytes', ios['archiveSizeBytes']),
    MapEntry('rln.android.archiveSizeBytes', android['archiveSizeBytes']),
  ]) {
    final value = entry.value;
    if (value is! int || value <= 0) {
      failures.add('${entry.key} must be a positive integer.');
    }
  }
}

List<Map<String, Object?>> _dependencyInventory(
  List<String> failures,
  List<String> warnings,
) {
  final lockText = File('pubspec.lock').readAsStringSync();
  final lockPackages = _parsePubspecLock(lockText);
  final packageConfigFile = File('.dart_tool/package_config.json');
  if (!packageConfigFile.existsSync()) {
    failures.add(
      '.dart_tool/package_config.json is missing; run flutter pub get first.',
    );
    return const <Map<String, Object?>>[];
  }
  final packageConfig =
      jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, Object?>;
  final packages = (packageConfig['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final roots = <String, Uri>{};
  for (final package in packages) {
    final name = package['name']?.toString();
    final rootUri = package['rootUri']?.toString();
    if (name == null || rootUri == null) continue;
    roots[name] = Uri.parse(rootUri);
  }

  final inventory = <Map<String, Object?>>[];
  for (final package in lockPackages) {
    final name = package['name']!.toString();
    final root = roots[name];
    final licenseFiles = root == null
        ? const <String>[]
        : _licenseFilesIncludingSdkRoot(Directory.fromUri(root));
    final source = package['source']?.toString();
    final license = source == 'sdk'
        ? const _LicenseClassification.accepted('Flutter-SDK-bundled')
        : root == null
        ? _LicenseClassification.unknown('missing package root')
        : _classifyLicense(Directory.fromUri(root), licenseFiles);
    if (licenseFiles.isEmpty) {
      failures.add(
        'dependency $name has no local LICENSE/COPYING/NOTICE file.',
      );
    }
    inventory.add(<String, Object?>{
      'name': name,
      'version': package['version'],
      'source': source,
      'dependency': package['dependency'],
      'sha256': package['sha256'],
      'licenseFiles': licenseFiles,
      'license': license.name,
      'licensePolicy': license.policy,
      'licenseReason': license.reason,
    });
  }
  if (inventory.isEmpty) {
    failures.add('pubspec.lock dependency inventory is empty.');
  }
  return inventory;
}

Map<String, Object?> _licensePolicyReport(
  List<Map<String, Object?>> dependencies,
  List<String> failures,
) {
  final accepted = <Map<String, Object?>>[];
  final unknown = <Map<String, Object?>>[];
  final rejected = <Map<String, Object?>>[];

  for (final dependency in dependencies) {
    final policy = dependency['licensePolicy']?.toString() ?? 'unknown';
    final row = <String, Object?>{
      'name': dependency['name'],
      'version': dependency['version'],
      'license': dependency['license'],
      'policy': policy,
      'reason': dependency['licenseReason'],
    };
    if (policy == 'accepted') {
      accepted.add(row);
    } else if (policy == 'rejected') {
      rejected.add(row);
    } else {
      unknown.add(row);
    }
  }

  for (final dependency in rejected) {
    failures.add(
      'dependency ${dependency['name']} has rejected license evidence: '
      '${dependency['reason']}',
    );
  }
  for (final dependency in unknown) {
    failures.add(
      'dependency ${dependency['name']} has unclassified license evidence: '
      '${dependency['reason']}',
    );
  }

  return <String, Object?>{
    'allowed': _allowedLicenseClassifications.toList()..sort(),
    'acceptedCount': accepted.length,
    'unknownCount': unknown.length,
    'rejectedCount': rejected.length,
    'accepted': accepted,
    'unknown': unknown,
    'rejected': rejected,
  };
}

List<Map<String, Object?>> _parsePubspecLock(String text) {
  final packages = <Map<String, Object?>>[];
  String? current;
  String? dependency;
  String? source;
  String? version;
  String? sha256;
  for (final line in text.split('\n')) {
    final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(line);
    if (packageMatch != null) {
      if (current != null) {
        packages.add(<String, Object?>{
          'name': current,
          'dependency': dependency,
          'source': source,
          'version': version,
          'sha256': sha256,
        });
      }
      current = packageMatch.group(1);
      dependency = null;
      source = null;
      version = null;
      sha256 = null;
      continue;
    }
    if (current == null) continue;
    String? scalar(String key) {
      final match = RegExp('^    $key: (.*)\$').firstMatch(line);
      return match?.group(1)?.replaceAll('"', '');
    }

    dependency ??= scalar('dependency');
    source ??= scalar('source');
    version ??= scalar('version');
    sha256 ??= scalar('      sha256');
    final shaMatch = RegExp(r'^      sha256: "?([^"]+)"?$').firstMatch(line);
    if (shaMatch != null) sha256 = shaMatch.group(1);
  }
  if (current != null) {
    packages.add(<String, Object?>{
      'name': current,
      'dependency': dependency,
      'source': source,
      'version': version,
      'sha256': sha256,
    });
  }
  return packages
      .where((package) => package['name'] != 'rgb_sdk_flutter')
      .toList(growable: false);
}

List<String> _licenseFiles(Directory root) {
  if (!root.existsSync()) return const <String>[];
  final files = <String>[];
  for (final entity in root.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last.toLowerCase();
    if (name == 'license' ||
        name == 'license.md' ||
        name == 'copying' ||
        name == 'notice' ||
        name == 'notice.md') {
      files.add(entity.path);
    }
  }
  files.sort();
  return files;
}

List<String> _licenseFilesIncludingSdkRoot(Directory root) {
  final direct = _licenseFiles(root);
  if (direct.isNotEmpty) return direct;
  var current = root;
  for (var depth = 0; depth < 4; depth += 1) {
    current = current.parent;
    final parentLicenses = _licenseFiles(current);
    if (parentLicenses.isNotEmpty) return parentLicenses;
  }
  return const <String>[];
}

_LicenseClassification _classifyLicense(Directory root, List<String> files) {
  if (files.isEmpty) return _LicenseClassification.unknown('no license file');
  final text = files
      .map((path) => File(path).readAsStringSync())
      .join('\n\n')
      .toLowerCase();
  for (final pattern in _restrictedLicensePatterns) {
    if (text.contains(pattern)) {
      return _LicenseClassification.rejected(
        'restricted/copyleft-commercial pattern "$pattern" found',
      );
    }
  }
  if (text.contains('apache license') && text.contains('version 2.0')) {
    return const _LicenseClassification.accepted('Apache-2.0');
  }
  if (text.contains('mozilla public license') && text.contains('version 2.0')) {
    return const _LicenseClassification.accepted('MPL-2.0');
  }
  if (text.contains('mit license') ||
      text.contains('permission is hereby granted, free of charge')) {
    return const _LicenseClassification.accepted('MIT');
  }
  if (text.contains('redistribution and use in source and binary forms')) {
    final hasAdvertisingClause = text.contains(
      'all advertising materials mentioning features or use of this software',
    );
    final license = hasAdvertisingClause
        ? 'BSD-4-Clause-like'
        : 'BSD-3-Clause-like';
    if (_allowedLicenseClassifications.contains(license)) {
      return _LicenseClassification.accepted(license);
    }
    return _LicenseClassification.rejected('$license is not allowlisted');
  }
  return _LicenseClassification.unknown(
    'no accepted SPDX-compatible pattern found in ${root.path}',
  );
}

Future<Map<String, Object?>> _vulnerabilityAudit(
  List<Map<String, Object?>> dependencies,
  List<String> failures,
  List<String> warnings,
) async {
  final hosted = dependencies
      .where((dependency) => dependency['source'] == 'hosted')
      .where((dependency) => dependency['version'] != null)
      .toList(growable: false);
  if (hosted.isEmpty) {
    failures.add('no hosted dependencies available for OSV audit.');
    return <String, Object?>{'status': 'failed', 'reason': 'empty inventory'};
  }

  final queries = hosted
      .map(
        (dependency) => <String, Object?>{
          'package': <String, Object?>{
            'name': dependency['name'],
            'ecosystem': 'Pub',
          },
          'version': dependency['version'],
        },
      )
      .toList(growable: false);

  late final Map<String, Object?> decoded;
  try {
    decoded = await _postJson(Uri.parse(_osvQueryBatchUrl), <String, Object?>{
      'queries': queries,
    });
  } catch (error) {
    final message = 'OSV vulnerability audit failed: $error';
    if (Platform.environment[_allowNetworkSkipEnv] == '1') {
      warnings.add('$message. Allowed by $_allowNetworkSkipEnv=1.');
      return <String, Object?>{
        'status': 'skipped',
        'reason': message,
        'queryCount': queries.length,
      };
    }
    failures.add(message);
    return <String, Object?>{
      'status': 'failed',
      'reason': message,
      'queryCount': queries.length,
    };
  }

  final results = decoded['results'];
  if (results is! List || results.length != hosted.length) {
    failures.add('OSV querybatch returned malformed result shape.');
    return <String, Object?>{
      'status': 'failed',
      'reason': 'malformed result shape',
      'queryCount': queries.length,
    };
  }

  final vulnerable = <Map<String, Object?>>[];
  for (var i = 0; i < hosted.length; i += 1) {
    final result = results[i];
    final vulns = result is Map ? result['vulns'] : null;
    if (vulns is! List || vulns.isEmpty) continue;
    final dependency = hosted[i];
    vulnerable.add(<String, Object?>{
      'name': dependency['name'],
      'version': dependency['version'],
      'vulnerabilities': vulns
          .whereType<Map<Object?, Object?>>()
          .map(
            (vuln) => <String, Object?>{
              'id': vuln['id'],
              'aliases': vuln['aliases'],
              'summary': vuln['summary'],
              'modified': vuln['modified'],
            },
          )
          .toList(growable: false),
    });
  }

  if (vulnerable.isNotEmpty) {
    failures.add(
      'OSV vulnerability audit found affected hosted dependencies: '
      '${vulnerable.map((row) => row['name']).join(', ')}',
    );
  }

  return <String, Object?>{
    'status': vulnerable.isEmpty ? 'passed' : 'failed',
    'source': _osvQueryBatchUrl,
    'ecosystem': 'Pub',
    'queryCount': queries.length,
    'vulnerableCount': vulnerable.length,
    'vulnerable': vulnerable,
  };
}

Future<Map<String, Object?>> _postJson(
  Uri uri,
  Map<String, Object?> body,
) async {
  final client = HttpClient()..connectionTimeout = _osvTimeout;
  try {
    final request = await client.postUrl(uri).timeout(_osvTimeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(_osvTimeout);
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode}: $text');
    }
    final decoded = jsonDecode(text);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    throw const FormatException('expected JSON object response');
  } finally {
    client.close(force: true);
  }
}

Map<String, Object?> _validateIosSymbols(
  Map<String, Object?> ios,
  List<String> failures,
  List<String> warnings,
) {
  final installedFiles =
      (ios['installedFiles']! as Map<String, Object?>).keys.toList()..sort();
  final libraries = installedFiles
      .where((path) => path.endsWith('/librgb_lightning_node.a'))
      .toList(growable: false);
  final slices = <Map<String, Object?>>[];
  if (!Platform.isMacOS) {
    warnings.add('iOS symbol validation requires macOS; skipped on this host.');
    return <String, Object?>{'status': 'skipped', 'reason': 'not macOS'};
  }
  for (final relativePath in libraries) {
    final file = File(relativePath);
    if (!file.existsSync()) {
      failures.add('missing iOS native library: $relativePath');
      continue;
    }
    final symbols = _runSymbols('nm', <String>['-gU', relativePath]);
    final missing = _missingMarkers(symbols, _requiredSymbolMarkers);
    if (missing.isNotEmpty) {
      failures.add(
        'iOS native library $relativePath is missing ABI markers: '
        '${missing.join(', ')}',
      );
    }
    slices.add(<String, Object?>{
      'path': relativePath,
      'sizeBytes': file.lengthSync(),
      'markersChecked': _requiredSymbolMarkers.length,
      'missingMarkers': missing,
    });
  }
  if (slices.isEmpty) {
    failures.add('no iOS native libraries found in release baseline.');
  }
  return <String, Object?>{'status': 'checked', 'libraries': slices};
}

Map<String, Object?> _validateAndroidArtifact(
  Map<String, Object?> android,
  List<String> failures,
  List<String> warnings,
) {
  final version = android['archiveUrl']
      .toString()
      .split('/')
      .reversed
      .skip(1)
      .first;
  final aarPaths = _findAndroidAars(version);
  if (aarPaths.isEmpty) {
    failures.add('Android AAR is not resolved in the local Gradle cache.');
    return <String, Object?>{'status': 'missing'};
  }
  final expectedAbis = (android['abis']! as List<Object?>)
      .map((abi) => abi.toString())
      .toSet();
  final archives = <Map<String, Object?>>[];
  for (final aar in aarPaths) {
    final entries = _run('unzip', <String>['-Z1', aar.path]).stdoutLines;
    final abis = entries
        .map(
          (entry) => RegExp(
            r'^jni/([^/]+)/librgb_lightning_node\.so$',
          ).firstMatch(entry),
        )
        .whereType<RegExpMatch>()
        .map((match) => match.group(1)!)
        .toSet();
    if (abis.length != expectedAbis.length || !abis.containsAll(expectedAbis)) {
      failures.add(
        'Android AAR ${aar.path} ABI set ${abis.toList()..sort()} does not '
        'match expected ${expectedAbis.toList()..sort()}.',
      );
    }
    final abiReports = <Map<String, Object?>>[];
    for (final abi in abis.toList()..sort()) {
      final markerReport = _androidSymbolMarkers(aar, abi, failures, warnings);
      abiReports.add(markerReport);
    }
    archives.add(<String, Object?>{
      'path': aar.path,
      'sizeBytes': aar.lengthSync(),
      'abis': abis.toList()..sort(),
      'symbols': abiReports,
    });
  }
  return <String, Object?>{'status': 'checked', 'archives': archives};
}

Map<String, Object?> _androidSymbolMarkers(
  File aar,
  String abi,
  List<String> failures,
  List<String> warnings,
) {
  final temp = Directory.systemTemp.createTempSync('rgb-sdk-abi-');
  final entry = 'jni/$abi/librgb_lightning_node.so';
  final unzip = _run('unzip', <String>['-q', aar.path, entry, '-d', temp.path]);
  if (unzip.exitCode != 0) {
    failures.add('failed to extract $entry from ${aar.path}: ${unzip.stderr}');
    return <String, Object?>{'abi': abi, 'status': 'extract-failed'};
  }
  final library = File('${temp.path}/$entry');
  final symbols = _runSymbols('nm', <String>['-gD', library.path]);
  final missing = _missingMarkers(symbols, _requiredSymbolMarkers);
  try {
    temp.deleteSync(recursive: true);
  } catch (_) {
    warnings.add('temporary ABI directory could not be removed: ${temp.path}');
  }
  if (missing.isNotEmpty) {
    failures.add(
      'Android $abi native library is missing ABI markers: ${missing.join(', ')}',
    );
  }
  return <String, Object?>{
    'abi': abi,
    'markersChecked': _requiredSymbolMarkers.length,
    'missingMarkers': missing,
  };
}

List<File> _findAndroidAars(String version) {
  final home = Platform.environment['HOME'];
  if (home == null) return const <File>[];
  final base = Directory(
    '$home/.gradle/caches/modules-2/files-2.1/com.utexo/'
    'rgb-lightning-node-android/$version',
  );
  if (!base.existsSync()) return const <File>[];
  return base
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where(
        (file) =>
            file.uri.pathSegments.last ==
            'rgb-lightning-node-android-$version.aar',
      )
      .toList(growable: false);
}

String _runSymbols(String executable, List<String> args) {
  final result = _run(executable, args);
  if (result.exitCode == 0) return result.stdoutText;
  return _run('strings', <String>[args.last]).stdoutText;
}

List<String> _missingMarkers(String symbols, List<String> markers) {
  return markers.where((marker) => !symbols.contains(marker)).toList();
}

_CommandResult _run(String executable, List<String> args) {
  final result = Process.runSync(executable, args, stdoutEncoding: utf8);
  return _CommandResult(
    exitCode: result.exitCode,
    stdoutText: result.stdout.toString(),
    stderr: result.stderr.toString(),
  );
}

void _writeReport(Map<String, Object?> report) {
  final reportDir = Platform.environment['REPORT_DIR'];
  if (reportDir == null || reportDir.isEmpty) return;
  final dir = Directory(reportDir)..createSync(recursive: true);
  final commit = _run('git', <String>[
    'rev-parse',
    '--short',
    'HEAD',
  ]).stdoutText.trim();
  final path =
      '${dir.path}/supply-chain-${commit.isEmpty ? 'unknown' : commit}.json';
  File(
    path,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('supply-chain report: $path');
}

bool _gitDirty() {
  final result = _run('git', <String>['status', '--porcelain']);
  return result.stdoutText.trim().isNotEmpty;
}

T? _at<T>(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is T ? value : null;
}

class _CommandResult {
  const _CommandResult({
    required this.exitCode,
    required this.stdoutText,
    required this.stderr,
  });

  final int exitCode;
  final String stdoutText;
  final String stderr;

  List<String> get stdoutLines => stdoutText
      .split('\n')
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

class _LicenseClassification {
  const _LicenseClassification._(this.name, this.policy, this.reason);

  const _LicenseClassification.accepted(String name)
    : this._(name, 'accepted', 'allowlisted license classification');

  _LicenseClassification.rejected(String reason)
    : this._('REJECTED', 'rejected', reason);

  _LicenseClassification.unknown(String reason)
    : this._('UNKNOWN', 'unknown', reason);

  final String name;
  final String policy;
  final String reason;
}
