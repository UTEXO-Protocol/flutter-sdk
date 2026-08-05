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
  final methodRegex = RegExp(
    r'^\s*(?:[A-Za-z_][A-Za-z0-9_<>, ?]*[>?]*\s+)+([A-Za-z_][A-Za-z0-9_]*)(?:<[^>]+>)?\s*\(',
  );
  var inClass = false;
  var braceDepth = 0;

  for (final line in file.readAsLinesSync()) {
    if (!inClass) {
      if (line.contains(RegExp('class\\s+$className\\b'))) {
        inClass = true;
        braceDepth += _braceDelta(line);
      }
      continue;
    }

    braceDepth += _braceDelta(line);
    if (braceDepth <= 0) break;

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
    if (methodName.startsWith('_') || methodName == className) continue;
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
