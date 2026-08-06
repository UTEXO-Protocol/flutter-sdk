import 'dart:convert';
import 'dart:io';

const _validSupport = <String>{
  'supported',
  'native-blocked',
  'unsupported-parity',
};

const _validContract = <String>{'covered', 'implemented'};

const _validPlatformStatus = <String>{
  'required',
  'expected_failure',
  'not_required',
};

void main() {
  final root = Directory.current;
  final errors = <String>[];

  final rlnMatrix = _readMatrix(
    root,
    'tool/test_matrix/rln_methods.json',
    errors,
  );
  final walletMatrix = _readMatrix(
    root,
    'tool/test_matrix/wallet_methods.json',
    errors,
  );
  final coreMatrix = _readMatrix(
    root,
    'tool/test_matrix/core_exports.json',
    errors,
  );
  final evidenceCatalog = _readEvidenceCatalog(
    root,
    'tool/test_matrix/evidence_catalog.json',
    errors,
  );

  _validateMatrixShape('rln_methods.json', rlnMatrix, evidenceCatalog, errors);
  _validateMatrixShape(
    'wallet_methods.json',
    walletMatrix,
    evidenceCatalog,
    errors,
  );
  _validateMatrixShape(
    'core_exports.json',
    coreMatrix,
    evidenceCatalog,
    errors,
  );

  _validateSourceCoverage(
    name: 'RlnClient',
    className: 'RlnClient',
    sourcePath: 'lib/src/client/rln_client.dart',
    matrix: rlnMatrix,
    errors: errors,
  );
  _validateCoreExportCoverage(coreMatrix, errors);
  _validateSourceCoverage(
    name: 'UtexoWallet',
    className: 'UtexoWallet',
    sourcePath: 'lib/src/wallet/utexo_wallet.dart',
    matrix: walletMatrix,
    errors: errors,
  );

  if (errors.isNotEmpty) {
    stderr.writeln('Test matrix validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exit(1);
  }

  final rlnCount = _methodIds(rlnMatrix).length;
  final walletCount = _methodIds(walletMatrix).length;
  final coreCount = _methodIds(coreMatrix).length;
  stdout.writeln(
    'Test matrix valid: '
    '$rlnCount RlnClient, $walletCount UtexoWallet, $coreCount core exports.',
  );
}

void _validateCoreExportCoverage(
  Map<String, Object?> matrix,
  List<String> errors,
) {
  final stable = _collectEntrypointSymbols('lib/rgb_sdk_flutter.dart', errors);
  final advanced = _collectEntrypointSymbols(
    'lib/rgb_sdk_flutter_advanced.dart',
    errors,
  );
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return;

  for (final row in methods.whereType<Map<String, Object?>>()) {
    final id = row['id'];
    final implementation = row['implementation'];
    if (id is! String || implementation is! String) continue;
    final separator = implementation.indexOf('::');
    if (separator < 0) continue;
    final entrypoint = implementation.substring(0, separator);
    final symbol = implementation.substring(separator + 2);
    final exported = switch (entrypoint) {
      'lib/rgb_sdk_flutter.dart' => stable,
      'lib/rgb_sdk_flutter_advanced.dart' => advanced,
      _ => null,
    };
    if (exported == null) {
      errors.add(
        'core_exports.json/$id must reference a package entrypoint, not '
        '$entrypoint.',
      );
    } else if (symbol != id || !exported.contains(symbol)) {
      errors.add(
        'core_exports.json/$id claims $implementation, but `$symbol` is not '
        'exported by that entrypoint.',
      );
    }
  }
}

Set<String> _collectEntrypointSymbols(
  String entrypointPath,
  List<String> errors,
) {
  final entrypoint = File(entrypointPath);
  if (!entrypoint.existsSync()) {
    errors.add('Missing package entrypoint: $entrypointPath');
    return <String>{};
  }
  final symbols = _publicTopLevelSymbols(entrypoint);
  final exportPattern = RegExp(r"export\s+'([^']+)'([^;]*);");
  for (final match in exportPattern.allMatches(entrypoint.readAsStringSync())) {
    final target = File('${entrypoint.parent.path}/${match.group(1)!}');
    if (!target.existsSync()) {
      errors.add('$entrypointPath exports missing file ${target.path}.');
      continue;
    }
    final available = <String>{};
    for (final libraryFile in _dartLibraryFiles(target)) {
      available.addAll(_publicTopLevelSymbols(libraryFile));
    }
    final combinators = match.group(2)!;
    final show = _combinatorSymbols(combinators, 'show');
    final hide = _combinatorSymbols(combinators, 'hide') ?? const <String>{};
    symbols.addAll(
      available.where(
        (name) => (show == null || show.contains(name)) && !hide.contains(name),
      ),
    );
  }
  return symbols;
}

Set<String> _publicTopLevelSymbols(File file) {
  final symbols = <String>{};
  final declaration = RegExp(
    r'^(?:abstract\s+final\s+class|abstract\s+interface\s+class|'
    r'abstract\s+class|sealed\s+class|class|enum|typedef|extension)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)',
  );
  final callable = RegExp(
    r'^(?:[A-Za-z][A-Za-z0-9_<>,? ]*\s+)'
    r'([a-zA-Z][A-Za-z0-9_]*)\s*\(',
  );
  final variable = RegExp(
    r'^(?:const|final)\s+[A-Za-z][A-Za-z0-9_<>,? ]*\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)\s*[=;]',
  );
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith(' ') || line.startsWith('\t')) continue;
    for (final pattern in <RegExp>[declaration, callable, variable]) {
      final match = pattern.firstMatch(line);
      if (match != null && !match.group(1)!.startsWith('_')) {
        symbols.add(match.group(1)!);
        break;
      }
    }
  }
  return symbols;
}

Set<String>? _combinatorSymbols(String source, String keyword) {
  final match = RegExp('(?:^|\\s)$keyword\\s+([^;]+)').firstMatch(source);
  if (match == null) return null;
  final raw = match.group(1)!;
  final stop = RegExp(r'\s(?:show|hide)\s').firstMatch(raw);
  return (stop == null ? raw : raw.substring(0, stop.start))
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}

Map<String, Object?> _readMatrix(
  Directory root,
  String relativePath,
  List<String> errors,
) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    errors.add('Missing matrix file: $relativePath');
    return <String, Object?>{};
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, Object?>) return decoded;
    errors.add('$relativePath must contain a JSON object.');
  } catch (error) {
    errors.add('$relativePath is not valid JSON: $error');
  }
  return <String, Object?>{};
}

Map<String, Object?> _readEvidenceCatalog(
  Directory root,
  String relativePath,
  List<String> errors,
) {
  final catalog = _readMatrix(root, relativePath, errors);
  if (catalog.isEmpty) return <String, Object?>{};
  if (catalog['schemaVersion'] != 1) {
    errors.add('$relativePath must have schemaVersion 1.');
  }
  final buckets = catalog['buckets'];
  if (buckets is Map<String, Object?>) return buckets;
  errors.add('$relativePath must contain a buckets object.');
  return <String, Object?>{};
}

void _validateMatrixShape(
  String name,
  Map<String, Object?> matrix,
  Map<String, Object?> evidenceCatalog,
  List<String> errors,
) {
  final methods = matrix['methods'];
  if (matrix['schemaVersion'] != 1) {
    errors.add('$name must have schemaVersion 1.');
  }
  if (methods is! List<Object?>) {
    errors.add('$name must have a methods array.');
    return;
  }

  final seen = <String>{};
  for (final raw in methods) {
    if (raw is! Map<String, Object?>) {
      errors.add('$name contains a non-object method row.');
      continue;
    }
    final id = raw['id'];
    if (id is! String || id.isEmpty) {
      errors.add('$name contains a method row without id.');
      continue;
    }
    if (!seen.add(id)) {
      errors.add('$name contains duplicate method id: $id');
    }
    for (final field in <String>[
      'group',
      'support',
      'fixture',
      'contract',
      'implementation',
      'evidenceBucket',
    ]) {
      if (raw[field] is! String || (raw[field] as String).isEmpty) {
        errors.add('$name/$id is missing required string field: $field');
      }
    }
    final implementation = raw['implementation'];
    if (implementation is String &&
        !implementation.contains('::') &&
        implementation != 'native-artifact') {
      errors.add(
        '$name/$id implementation must name a concrete symbol, for example '
        'path/to/file.dart::Class.method.',
      );
    }
    final evidenceBucket = raw['evidenceBucket'];
    final fixture = raw['fixture'];
    if (evidenceBucket is String &&
        fixture is String &&
        evidenceBucket != fixture) {
      errors.add(
        '$name/$id evidenceBucket must match fixture until executable test IDs '
        'replace fixture buckets.',
      );
    }
    if (evidenceBucket is String) {
      final evidence = evidenceCatalog[evidenceBucket];
      if (evidence is! Map<String, Object?>) {
        errors.add('$name/$id has uncataloged evidenceBucket: $evidenceBucket');
      } else {
        final testIds = evidence['testIds'];
        final assertions = evidence['assertions'];
        final claimLevel = evidence['claimLevel'];
        if (claimLevel is! String || claimLevel.isEmpty) {
          errors.add(
            '$name/$id evidenceBucket $evidenceBucket lacks claimLevel.',
          );
        }
        if (testIds is! List<Object?> || testIds.isEmpty) {
          errors.add('$name/$id evidenceBucket $evidenceBucket lacks testIds.');
        }
        if (assertions is! List<Object?> || assertions.isEmpty) {
          errors.add(
            '$name/$id evidenceBucket $evidenceBucket lacks assertions.',
          );
        }
      }
    }
    final support = raw['support'];
    if (support is String && !_validSupport.contains(support)) {
      errors.add('$name/$id has invalid support value: $support');
    }
    final contract = raw['contract'];
    if (contract is String && !_validContract.contains(contract)) {
      errors.add(
        '$name/$id has invalid contract value: $contract. '
        'Use covered or implemented; planned rows are not release-ready.',
      );
    }
    for (final field in <String>['ios', 'android']) {
      final status = raw[field];
      if (status == null) continue;
      if (status is! String || !_validPlatformStatus.contains(status)) {
        errors.add('$name/$id has invalid $field status: $status');
      }
    }
    if (support == 'supported' && contract is String) {
      final isContracted = contract == 'covered' || contract == 'implemented';
      if (!isContracted) {
        errors.add('$name/$id is supported but lacks contract coverage.');
      }
    }
  }
}

void _validateSourceCoverage({
  required String name,
  required String className,
  required String sourcePath,
  required Map<String, Object?> matrix,
  required List<String> errors,
}) {
  final sourceMethods = _extractPublicClassMethods(sourcePath, className);
  final matrixMethods = _methodIds(matrix);

  final missing = sourceMethods.difference(matrixMethods).toList()..sort();
  final stale = matrixMethods.difference(sourceMethods).toList()..sort();

  for (final method in missing) {
    errors.add('$name.$method is public but has no test matrix row.');
  }
  for (final method in stale) {
    errors.add('$name matrix row is stale or no longer public: $method');
  }
}

Set<String> _methodIds(Map<String, Object?> matrix) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return <String>{};
  return methods
      .whereType<Map<String, Object?>>()
      .map((row) => row['id'])
      .whereType<String>()
      .toSet();
}

Set<String> _extractPublicClassMethods(String relativePath, String className) {
  final file = File(relativePath);
  if (!file.existsSync()) return <String>{};

  final methods = <String>{};
  final files = _dartLibraryFiles(file);
  for (final libraryFile in files) {
    methods.addAll(
      _extractPublicMembersFromScope(libraryFile, 'class', className),
    );
  }
  if (className == 'UtexoWallet') {
    for (final libraryFile in files) {
      methods.addAll(
        _extractPublicMembersFromScope(libraryFile, 'mixin', '_UtexoWallet'),
      );
      methods.addAll(
        _extractPublicMembersFromScope(
          libraryFile,
          'extension',
          'UtexoWalletRawApi',
        ),
      );
    }
  }
  return methods;
}

List<File> _dartLibraryFiles(File file) {
  final source = file.readAsStringSync();
  final directory = file.parent.path;
  final partPattern = RegExp(r"part '([^']+)';");
  return <File>[
    file,
    for (final match in partPattern.allMatches(source))
      File('$directory/${match.group(1)!}'),
  ];
}

Set<String> _extractPublicMembersFromScope(
  File file,
  String keyword,
  String scopeName,
) {
  final methods = <String>{};
  final methodRegex = RegExp(
    r'^\s*(?:[A-Za-z_][A-Za-z0-9_<>, ?]*[>?]*\s+)+([A-Za-z_][A-Za-z0-9_]*)(?:<[^>]+>)?\s*\(',
  );
  var inScope = false;
  var seenBody = false;
  var braceDepth = 0;

  for (final line in file.readAsLinesSync()) {
    if (!inScope) {
      if (line.contains(RegExp('$keyword\\s+$scopeName'))) {
        inScope = true;
        braceDepth += _braceDelta(line);
      }
      continue;
    }

    braceDepth += _braceDelta(line);
    if (!seenBody) {
      if (braceDepth <= 0) continue;
      seenBody = true;
    } else if (braceDepth <= 0) {
      break;
    }

    final trimmed = line.trimLeft();
    if (trimmed.startsWith('_') ||
        trimmed.startsWith('if ') ||
        trimmed.startsWith('for ') ||
        trimmed.startsWith('while ') ||
        trimmed.startsWith('switch ') ||
        trimmed.startsWith('catch ') ||
        trimmed.startsWith('try ') ||
        trimmed.startsWith('throw ') ||
        trimmed.startsWith('return ') ||
        trimmed.startsWith('await ') ||
        trimmed.startsWith('final ') ||
        trimmed.startsWith('var ') ||
        trimmed.startsWith('factory ') ||
        trimmed.startsWith('static ') ||
        trimmed.startsWith('get ') ||
        trimmed.contains(' Function(')) {
      continue;
    }

    final match = methodRegex.firstMatch(line);
    if (match == null) continue;

    final methodName = match.group(1)!;
    if (methodName.startsWith('_') || methodName == scopeName) continue;
    methods.add(methodName);
  }
  return methods;
}

int _braceDelta(String line) {
  var delta = 0;
  for (final codeUnit in line.codeUnits) {
    if (codeUnit == 123) delta += 1;
    if (codeUnit == 125) delta -= 1;
  }
  return delta;
}
