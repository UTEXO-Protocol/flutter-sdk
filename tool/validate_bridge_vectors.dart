import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  final errors = <String>[];

  final rlnMatrix = _readJsonObject(
    File('${root.path}/tool/test_matrix/rln_methods.json'),
    errors,
  );
  final vectorPolicy = _readJsonObject(
    File('${root.path}/tool/test_matrix/bridge_behavior_vectors.json'),
    errors,
  );

  _validateShape(vectorPolicy, errors);
  _validateFamilies(rlnMatrix, vectorPolicy, errors);
  _validateCriticalMethods(rlnMatrix, vectorPolicy, errors);
  _validateNumericPolicy(root, vectorPolicy, errors);

  if (errors.isNotEmpty) {
    stderr.writeln('Bridge vector validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exit(1);
  }

  final methodCount = _methodRows(rlnMatrix).length;
  final familyCount = _objectMap(vectorPolicy['families']).length;
  final criticalCount = _objectMap(vectorPolicy['criticalMethods']).length;
  stdout.writeln(
    'Bridge vectors valid: $methodCount methods, $familyCount families, '
    '$criticalCount critical method contracts.',
  );
}

Map<String, Object?> _readJsonObject(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing JSON file: ${file.path}');
    return <String, Object?>{};
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, Object?>) return decoded;
    errors.add('${file.path} must contain a JSON object.');
  } catch (error) {
    errors.add('${file.path} is not valid JSON: $error');
  }
  return <String, Object?>{};
}

void _validateShape(Map<String, Object?> policy, List<String> errors) {
  if (policy['schemaVersion'] != 1) {
    errors.add('bridge_behavior_vectors.json must have schemaVersion 1.');
  }
  if (_objectMap(policy['families']).isEmpty) {
    errors.add('bridge_behavior_vectors.json must define families.');
  }
  if (_objectMap(policy['criticalMethods']).isEmpty) {
    errors.add('bridge_behavior_vectors.json must define criticalMethods.');
  }
  final requiredFamilyVectors = policy['requiredFamilyVectors'];
  if (requiredFamilyVectors is! List<Object?> ||
      requiredFamilyVectors.whereType<String>().isEmpty) {
    errors.add(
      'bridge_behavior_vectors.json must define requiredFamilyVectors.',
    );
  }
}

void _validateFamilies(
  Map<String, Object?> rlnMatrix,
  Map<String, Object?> policy,
  List<String> errors,
) {
  final rows = _methodRows(rlnMatrix);
  final groups = rows.map((row) => row['group']).whereType<String>().toSet();
  final families = _objectMap(policy['families']);

  for (final group
      in groups.difference(families.keys.toSet()).toList()..sort()) {
    errors.add('RlnClient group "$group" has no bridge vector family.');
  }
  for (final stale
      in families.keys.toSet().difference(groups).toList()..sort()) {
    errors.add('Bridge vector family "$stale" has no RlnClient methods.');
  }

  for (final entry in families.entries) {
    final family = _objectMapValue(entry.value);
    final vectors = family['vectors'];
    final testIds = family['testIds'];
    if (vectors is! List<Object?> || vectors.whereType<String>().isEmpty) {
      errors.add('Bridge vector family ${entry.key} has no vectors.');
    }
    if (testIds is! List<Object?> || testIds.whereType<String>().isEmpty) {
      errors.add('Bridge vector family ${entry.key} has no testIds.');
    }
  }
}

void _validateCriticalMethods(
  Map<String, Object?> rlnMatrix,
  Map<String, Object?> policy,
  List<String> errors,
) {
  final methodIds = _methodRows(
    rlnMatrix,
  ).map((row) => row['id']).whereType<String>().toSet();
  final criticalMethods = _objectMap(policy['criticalMethods']);

  for (final method in criticalMethods.keys.toList()..sort()) {
    if (!methodIds.contains(method)) {
      errors.add('Critical bridge vector method "$method" is not in matrix.');
      continue;
    }
    final row = _objectMapValue(criticalMethods[method]);
    final tracker = row['tracker'];
    final requiredVectors = row['requiredVectors'];
    final testIds = row['testIds'];
    if (tracker is! String || tracker.isEmpty) {
      errors.add('Critical bridge vector method $method lacks tracker.');
    }
    if (requiredVectors is! List<Object?> ||
        requiredVectors.whereType<String>().isEmpty) {
      errors.add('Critical bridge vector method $method lacks vectors.');
    }
    if (testIds is! List<Object?> || testIds.whereType<String>().isEmpty) {
      errors.add('Critical bridge vector method $method lacks testIds.');
    }
  }
}

void _validateNumericPolicy(
  Directory root,
  Map<String, Object?> policy,
  List<String> errors,
) {
  final numericPolicy = _objectMapValue(policy['numericPolicy']);
  if (numericPolicy.isEmpty) {
    errors.add('bridge_behavior_vectors.json must define numericPolicy.');
    return;
  }

  for (final field in <String>['inputRange', 'largeOutputEncoding']) {
    final value = numericPolicy[field];
    if (value is! String || value.isEmpty) {
      errors.add('numericPolicy.$field must be a non-empty string.');
    }
  }

  final constants = numericPolicy['dartConstants'];
  if (constants is! List<Object?> || constants.whereType<String>().isEmpty) {
    errors.add('numericPolicy.dartConstants must name source constants.');
  } else {
    final modelSource = File(
      '${root.path}/lib/src/models/rln_models.dart',
    ).readAsStringSync();
    for (final symbol in constants.whereType<String>()) {
      final parts = symbol.split('::');
      if (parts.length != 2) {
        errors.add('numericPolicy.dartConstants entry is invalid: $symbol');
        continue;
      }
      if (!modelSource.contains(parts[1])) {
        errors.add('numericPolicy.dartConstants symbol is missing: $symbol');
      }
    }
  }

  final testIds = numericPolicy['testIds'];
  if (testIds is! List<Object?> || testIds.whereType<String>().isEmpty) {
    errors.add('numericPolicy.testIds must include executable evidence.');
  }
}

List<Map<String, Object?>> _methodRows(Map<String, Object?> matrix) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return const <Map<String, Object?>>[];
  return methods.whereType<Map<String, Object?>>().toList(growable: false);
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  return const <String, Object?>{};
}

Map<String, Object?> _objectMapValue(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}
