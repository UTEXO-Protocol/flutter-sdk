import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  final errors = <String>[];

  final manifest = _readJsonObject(
    File('${root.path}/tool/rn_parity_manifest.json'),
    errors,
  );
  final baseline = _readJsonObject(
    File('${root.path}/tool/release_baseline.json'),
    errors,
  );
  final rnPath = _resolveRnPath();
  final rnRoot = Directory(rnPath);
  if (!rnRoot.existsSync()) {
    errors.add(
      'RN reference repo not found at $rnPath. Set RGB_SDK_RN_PATH to the '
      'rgb-sdk-rn dev checkout.',
    );
    _finish(errors);
  }

  _validateRnBaseline(rnRoot, baseline, errors);
  _validateLowLevelNativeMethods(root, rnRoot, errors);
  _validateTypedPigeonWire(root, errors);
  _validateWalletMethods(root, rnRoot, errors);
  _validateRuntimeExports(root, rnRoot, manifest, errors);
  _validateScopedTypeStars(rnRoot, manifest, errors);

  _finish(errors);

  stdout.writeln(
    'RN parity valid against ${_shortCommit(_nestedString(baseline, <String>['reactNative', 'commit']))}: '
    'NativeRgb methods, UTEXOWallet methods, and runtime package exports.',
  );
}

String _resolveRnPath() {
  final envPath = Platform.environment['RGB_SDK_RN_PATH'];
  if (envPath != null && envPath.trim().isNotEmpty) return envPath.trim();
  return '../rgb-sdk-rn';
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

void _validateRnBaseline(
  Directory rnRoot,
  Map<String, Object?> baseline,
  List<String> errors,
) {
  final expectedCommit = _nestedString(baseline, <String>[
    'reactNative',
    'commit',
  ]);
  final expectedPackage = _nestedString(baseline, <String>[
    'reactNative',
    'package',
  ]);
  final expectedVersion = _nestedString(baseline, <String>[
    'reactNative',
    'version',
  ]);
  final expectedCoreVersion = _nestedString(baseline, <String>[
    'core',
    'version',
  ]);
  final expectedRlnVersion = _nestedString(baseline, <String>[
    'rln',
    'version',
  ]);
  if (<String?>[
    expectedCommit,
    expectedPackage,
    expectedVersion,
    expectedCoreVersion,
    expectedRlnVersion,
  ].any((value) => value == null || value.isEmpty)) {
    errors.add(
      'release_baseline.json must define the RN commit/package/version, '
      'core version, and RLN version.',
    );
    return;
  }

  final result = Process.runSync('git', <String>[
    '-C',
    rnRoot.path,
    'rev-parse',
    'HEAD',
  ]);
  if (result.exitCode != 0) {
    errors.add('Unable to read RN reference git commit: ${result.stderr}');
    return;
  }

  final actual = result.stdout.toString().trim();
  if (actual != expectedCommit) {
    errors.add(
      'RN reference commit mismatch. Expected $expectedCommit, found $actual at '
      '${rnRoot.path}. Update the RN checkout or deliberately update the '
      'release baseline after a new parity audit.',
    );
  }

  final packageJson = _readJsonObject(
    File('${rnRoot.path}/package.json'),
    errors,
  );
  if (packageJson['name'] != expectedPackage) {
    errors.add(
      'RN package mismatch. Expected $expectedPackage, found '
      '${packageJson['name']}.',
    );
  }
  if (packageJson['version'] != expectedVersion) {
    errors.add(
      'RN version mismatch. Expected $expectedVersion, found '
      '${packageJson['version']}.',
    );
  }
  final dependencies = packageJson['dependencies'];
  final actualCoreVersion = dependencies is Map<String, Object?>
      ? dependencies['@utexo/rgb-sdk-core']
      : null;
  if (actualCoreVersion != expectedCoreVersion) {
    errors.add(
      'RN core dependency mismatch. Expected $expectedCoreVersion, found '
      '$actualCoreVersion.',
    );
  }

  final androidBuild = File('${rnRoot.path}/android/build.gradle');
  final androidSource = androidBuild.existsSync()
      ? androidBuild.readAsStringSync()
      : '';
  final expectedCoordinate =
      'com.utexo:rgb-lightning-node-android:$expectedRlnVersion';
  if (!androidSource.contains(expectedCoordinate)) {
    errors.add(
      'RN Android bridge does not pin baseline artifact $expectedCoordinate.',
    );
  }

  final downloadScript = File(
    '${rnRoot.path}/scripts/download-rln-bindings.js',
  );
  final downloadSource = downloadScript.existsSync()
      ? downloadScript.readAsStringSync()
      : '';
  if (!downloadSource.contains("const VERSION = '$expectedRlnVersion';")) {
    errors.add(
      'RN iOS artifact downloader does not pin RLN $expectedRlnVersion.',
    );
  }
}

String? _nestedString(Map<String, Object?> source, List<String> path) {
  Object? value = source;
  for (final segment in path) {
    if (value is! Map<String, Object?>) return null;
    value = value[segment];
  }
  return value is String ? value : null;
}

void _validateLowLevelNativeMethods(
  Directory root,
  Directory rnRoot,
  List<String> errors,
) {
  final rnSignatures = _extractRnNativeRgbSignatures(
    File('${rnRoot.path}/src/binding/NativeRgb.ts'),
    errors,
  );
  final pigeonSignatures = _extractPigeonHostApiSignatures(
    File('${root.path}/pigeons/rln_api.dart'),
    errors,
  );
  final rnMethods = rnSignatures.keys.toSet();
  final pigeonMethods = pigeonSignatures.keys.toSet();
  final matrix = _readJsonObject(
    File('${root.path}/tool/test_matrix/rln_methods.json'),
    errors,
  );
  final flutterHostApis = _matrixStringField(matrix, 'hostApi');

  final missing = rnMethods.difference(flutterHostApis).toList()..sort();
  final stale = flutterHostApis.difference(rnMethods).toList()..sort();
  final missingFromPigeon = rnMethods.difference(pigeonMethods).toList()
    ..sort();
  final stalePigeon =
      pigeonMethods
          .where((method) => method.startsWith('rln'))
          .toSet()
          .difference(rnMethods)
          .toList()
        ..sort();

  for (final method in missing) {
    errors.add('RN NativeRgb.$method is missing from rln_methods.json.');
  }
  for (final method in stale) {
    errors.add('rln_methods.json hostApi $method is not in RN NativeRgb.ts.');
  }
  for (final method in missingFromPigeon) {
    errors.add('RN NativeRgb.$method is missing from Pigeon RlnHostApi.');
  }
  for (final method in stalePigeon) {
    errors.add('Pigeon RlnHostApi.$method is not in RN NativeRgb.ts.');
  }

  for (final method in rnMethods.intersection(pigeonMethods)) {
    final rn = rnSignatures[method]!;
    final pigeon = pigeonSignatures[method]!;
    if (rn.returnType != pigeon.returnType) {
      errors.add(
        'NativeRgb.$method return mismatch. RN ${rn.returnType.label}, '
        'Pigeon ${pigeon.returnType.label}.',
      );
    }
    if (rn.parameters.length != pigeon.parameters.length) {
      errors.add(
        'NativeRgb.$method parameter count mismatch. RN '
        '${rn.parameters.length}, Pigeon ${pigeon.parameters.length}.',
      );
      continue;
    }
    for (var index = 0; index < rn.parameters.length; index++) {
      final rnParam = rn.parameters[index];
      final pigeonParam = pigeon.parameters[index];
      if (rnParam.name != pigeonParam.name) {
        errors.add(
          'NativeRgb.$method parameter ${index + 1} name mismatch. RN '
          '${rnParam.name}, Pigeon ${pigeonParam.name}.',
        );
      }
      if (rnParam.type != pigeonParam.type) {
        errors.add(
          'NativeRgb.$method parameter ${rnParam.name} type mismatch. RN '
          '${rnParam.type.label}, Pigeon ${pigeonParam.type.label}.',
        );
      }
    }
  }
}

Map<String, _MethodSignature> _extractRnNativeRgbSignatures(
  File file,
  List<String> errors,
) {
  if (!file.existsSync()) {
    errors.add('Missing RN NativeRgb source: ${file.path}');
    return <String, _MethodSignature>{};
  }
  final source = file.readAsStringSync();
  final methods = <String, _MethodSignature>{};
  final methodRegex = RegExp(
    r'^\s*(rln[A-Za-z0-9_]+)\s*\(([\s\S]*?)\)\s*:\s*Promise<([^>]+)>;',
    multiLine: true,
  );
  for (final match in methodRegex.allMatches(source)) {
    final name = match.group(1)!;
    methods[name] = _MethodSignature(
      name: name,
      returnType: _TypeShape.fromRn(match.group(3)!.trim()),
      parameters: _parseRnParameters(match.group(2)!),
    );
  }
  return methods;
}

Map<String, _MethodSignature> _extractPigeonHostApiSignatures(
  File file,
  List<String> errors,
) {
  if (!file.existsSync()) {
    errors.add('Missing Pigeon source: ${file.path}');
    return <String, _MethodSignature>{};
  }
  final source = file.readAsStringSync();
  final methods = <String, _MethodSignature>{};
  final methodRegex = RegExp(
    r'^\s*([A-Za-z0-9_<>, ?]+)\s+(rln[A-Za-z0-9_]+)\s*\(([\s\S]*?)\);',
    multiLine: true,
  );
  for (final match in methodRegex.allMatches(source)) {
    final name = match.group(2)!;
    methods[name] = _MethodSignature(
      name: name,
      returnType: _TypeShape.fromDart(match.group(1)!.trim()),
      parameters: _parseDartParameters(match.group(3)!),
    );
  }
  return methods;
}

List<_ParameterShape> _parseRnParameters(String source) {
  return _splitParameters(source)
      .map((raw) {
        final match = RegExp(
          r'^\s*([A-Za-z_][A-Za-z0-9_]*)(\?)?\s*:\s*(.+?)\s*,?\s*$',
        ).firstMatch(raw);
        if (match == null) return null;
        final optional = match.group(2) != null;
        final typeSource = match.group(3)!.trim();
        return _ParameterShape(
          name: match.group(1)!,
          type: _TypeShape.fromRn(optional ? '$typeSource | null' : typeSource),
        );
      })
      .whereType<_ParameterShape>()
      .toList(growable: false);
}

List<_ParameterShape> _parseDartParameters(String source) {
  return _splitParameters(source)
      .map((raw) {
        final match = RegExp(
          r'^\s*([A-Za-z0-9_<>, ?]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*,?\s*$',
        ).firstMatch(raw);
        if (match == null) return null;
        return _ParameterShape(
          name: match.group(2)!,
          type: _TypeShape.fromDart(match.group(1)!.trim()),
        );
      })
      .whereType<_ParameterShape>()
      .toList(growable: false);
}

List<String> _splitParameters(String source) {
  return source
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

void _validateTypedPigeonWire(Directory root, List<String> errors) {
  final pigeon = File('${root.path}/pigeons/rln_api.dart');
  if (!pigeon.existsSync()) {
    errors.add('Missing Pigeon source: ${pigeon.path}');
    return;
  }

  final source = pigeon.readAsStringSync();
  if (!source.contains('class RlnWireResponse')) {
    errors.add('Pigeon source must define typed RlnWireResponse wire DTO.');
  }
  for (final forbidden in <String>[
    'Map<Object?, Object?>',
    'List<Map<Object?, Object?>>',
  ]) {
    if (source.contains(forbidden)) {
      errors.add(
        'Pigeon source still exposes broad $forbidden; use RlnWireResponse '
        'and strict Dart decoding at the client boundary.',
      );
    }
  }
}

final class _MethodSignature {
  const _MethodSignature({
    required this.name,
    required this.returnType,
    required this.parameters,
  });

  final String name;
  final _TypeShape returnType;
  final List<_ParameterShape> parameters;
}

final class _ParameterShape {
  const _ParameterShape({required this.name, required this.type});

  final String name;
  final _TypeShape type;
}

final class _TypeShape {
  const _TypeShape(this.kind, {this.nullable = false});

  factory _TypeShape.fromRn(String source) {
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    final nullable =
        normalized.contains('null') || normalized.contains('undefined');
    final nonNull = normalized
        .replaceAll(RegExp(r'\s*\|\s*null'), '')
        .replaceAll(RegExp(r'\s*\|\s*undefined'), '')
        .replaceAll('?', '')
        .trim();
    return _TypeShape(_rnKind(nonNull), nullable: nullable);
  }

  factory _TypeShape.fromDart(String source) {
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == 'Object?') {
      return const _TypeShape('map');
    }
    final nullable = normalized.endsWith('?');
    final nonNull = nullable
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    return _TypeShape(_dartKind(nonNull), nullable: nullable);
  }

  final String kind;
  final bool nullable;

  String get label => nullable ? '$kind?' : kind;

  @override
  bool operator ==(Object other) {
    return other is _TypeShape &&
        other.kind == kind &&
        other.nullable == nullable;
  }

  @override
  int get hashCode => Object.hash(kind, nullable);

  static String _rnKind(String source) {
    return switch (source) {
      'string' => 'string',
      'number' => 'number',
      'boolean' => 'bool',
      'void' => 'void',
      'object' => 'map',
      'object[]' => 'list-map',
      'string[]' => 'list-string',
      'number[]' => 'list-number',
      'any' => 'map',
      _ => source,
    };
  }

  static String _dartKind(String source) {
    return switch (source) {
      'String' => 'string',
      'int' || 'double' => 'number',
      'bool' => 'bool',
      'void' => 'void',
      'Map<Object?, Object?>' => 'map',
      'Object' => 'map',
      'RlnWireResponse' => 'map',
      'List<Map<Object?, Object?>>' => 'list-map',
      'List<RlnWireResponse>' => 'list-map',
      'List<String>' => 'list-string',
      'List<int>' => 'list-number',
      _ => source,
    };
  }
}

void _validateWalletMethods(
  Directory root,
  Directory rnRoot,
  List<String> errors,
) {
  final rnMethods = _extractRnWalletMethods(
    File('${rnRoot.path}/src/wallet/utexo-wallet.ts'),
    errors,
  );
  final matrix = _readJsonObject(
    File('${root.path}/tool/test_matrix/wallet_methods.json'),
    errors,
  );
  final walletMatrixIds = _matrixIds(matrix);

  final missing = rnMethods.difference(walletMatrixIds).toList()..sort();
  for (final method in missing) {
    errors.add('RN UTEXOWallet.$method is missing from wallet_methods.json.');
  }
}

Set<String> _extractRnWalletMethods(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN wallet source: ${file.path}');
    return <String>{};
  }

  final lines = file.readAsLinesSync();
  final methods = <String>{};
  var inClass = false;
  var braceDepth = 0;
  final methodRegex = RegExp(
    r'^\s*(?:async\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?::|{)',
  );

  for (final line in lines) {
    if (!inClass) {
      if (line.contains(RegExp(r'export\s+class\s+UTEXOWallet\b'))) {
        inClass = true;
        braceDepth += _braceDelta(line);
      }
      continue;
    }

    braceDepth += _braceDelta(line);
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('private ') ||
        trimmed.startsWith('protected ') ||
        trimmed.startsWith('constructor(') ||
        trimmed.startsWith('if ') ||
        trimmed.startsWith('for ') ||
        trimmed.startsWith('while ') ||
        trimmed.startsWith('switch ')) {
      if (braceDepth <= 0) break;
      continue;
    }

    final match = methodRegex.firstMatch(line);
    if (match != null) {
      final method = match.group(1)!;
      if (!method.startsWith('_') && method != 'constructor') {
        methods.add(method);
      }
    }

    if (braceDepth <= 0) break;
  }

  return methods;
}

int _braceDelta(String line) {
  var delta = 0;
  for (final codeUnit in line.codeUnits) {
    if (codeUnit == 123) delta += 1; // {
    if (codeUnit == 125) delta -= 1; // }
  }
  return delta;
}

void _validateRuntimeExports(
  Directory root,
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final rnExports = _extractRnRuntimeExports(
    File('${rnRoot.path}/src/index.ts'),
    errors,
  );
  final aliases = _stringMap(manifest, 'runtimeExportAliases', errors);
  final scopedOut = _stringMap(manifest, 'scopedOutRuntimeExports', errors);
  final dartSymbols = _collectDartBarrelSymbols(root, errors);

  for (final exportName in rnExports) {
    if (aliases.containsKey(exportName)) {
      final dartSymbol = aliases[exportName]!;
      if (!dartSymbols.contains(dartSymbol)) {
        errors.add(
          'RN runtime export $exportName maps to Dart symbol $dartSymbol, '
          'but $dartSymbol is not exported by lib/rgb_sdk_flutter.dart.',
        );
      }
      continue;
    }
    if (scopedOut.containsKey(exportName)) {
      if (scopedOut[exportName]!.trim().isEmpty) {
        errors.add('Scoped-out runtime export $exportName needs a reason.');
      }
      continue;
    }
    errors.add(
      'RN runtime export $exportName is not mapped or explicitly scoped out.',
    );
  }

  for (final alias in aliases.entries) {
    if (!rnExports.contains(alias.key)) {
      errors.add('runtimeExportAliases contains stale RN export ${alias.key}.');
    }
  }
  for (final exportName in scopedOut.keys) {
    if (!rnExports.contains(exportName)) {
      errors.add(
        'scopedOutRuntimeExports contains stale RN export $exportName.',
      );
    }
  }
}

Set<String> _extractRnRuntimeExports(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN package barrel: ${file.path}');
    return <String>{};
  }

  final source = file.readAsStringSync();
  final exportRegex = RegExp(
    r'export\s+(?!type\b)\{([\s\S]*?)\}\s+from\s+[^\n;]+;',
    multiLine: true,
  );
  final exports = <String>{};
  for (final match in exportRegex.allMatches(source)) {
    final block = match.group(1)!;
    final withoutComments = block
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');
    for (final rawName in withoutComments.split(',')) {
      var name = rawName.trim();
      if (name.isEmpty) continue;
      final aliasMatch = RegExp(
        r'^[A-Za-z_][A-Za-z0-9_]*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)$',
      ).firstMatch(name);
      if (aliasMatch != null) {
        name = aliasMatch.group(1)!;
      }
      exports.add(name);
    }
  }
  return exports;
}

Set<String> _collectDartBarrelSymbols(Directory root, List<String> errors) {
  final barrel = File('${root.path}/lib/rgb_sdk_flutter.dart');
  if (!barrel.existsSync()) {
    errors.add('Missing Dart barrel: ${barrel.path}');
    return <String>{};
  }

  final symbols = <String>{};
  final exportRegex = RegExp(r"export\s+'([^']+)';");
  for (final match in exportRegex.allMatches(barrel.readAsStringSync())) {
    final relative = match.group(1)!;
    final file = File('${root.path}/lib/$relative');
    if (!file.existsSync()) {
      errors.add('Dart barrel exports missing file: $relative');
      continue;
    }
    symbols.addAll(_extractDartSymbols(file));
  }
  symbols.addAll(_extractDartSymbols(barrel));
  return symbols;
}

Set<String> _extractDartSymbols(File file) {
  final symbols = <String>{};
  final typeRegex = RegExp(
    r'^(?:sealed\s+class|abstract\s+final\s+class|abstract\s+class|class|enum|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final functionRegex = RegExp(
    r'^(?:Future<[^>]+>|[A-Za-z_][A-Za-z0-9_<>, ?]*?)\s+([A-Za-z_][A-Za-z0-9_]*)(?:<[^>]+>)?\s*\(',
  );
  final variableRegex = RegExp(
    r'^(?:const|final)\s+[A-Za-z_][A-Za-z0-9_<>, ?]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*[=;]',
  );

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith(' ') || line.startsWith('\t')) continue;
    for (final regex in <RegExp>[typeRegex, functionRegex, variableRegex]) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        if (!name.startsWith('_')) symbols.add(name);
        break;
      }
    }
  }
  return symbols;
}

void _validateScopedTypeStars(
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final index = File('${rnRoot.path}/src/index.ts');
  if (!index.existsSync()) return;

  final scopedOut = _stringMap(manifest, 'scopedOutTypeStars', errors);
  final starRegex = RegExp(r"export\s+type\s+\*\s+from\s+'([^']+)';");
  final typeStars = starRegex
      .allMatches(index.readAsStringSync())
      .map((match) => match.group(1)!)
      .toSet();

  for (final target in typeStars) {
    if (!scopedOut.containsKey(target)) {
      errors.add(
        'RN type-star export $target is not explicitly documented in '
        'scopedOutTypeStars.',
      );
    } else if (scopedOut[target]!.trim().isEmpty) {
      errors.add('Type-star export $target needs a scoped-out reason.');
    }
  }
  for (final target in scopedOut.keys) {
    if (!typeStars.contains(target)) {
      errors.add('scopedOutTypeStars contains stale target $target.');
    }
  }
}

Map<String, String> _stringMap(
  Map<String, Object?> source,
  String key,
  List<String> errors,
) {
  final value = source[key];
  if (value is! Map<String, Object?>) {
    errors.add('rn_parity_manifest.json must define object $key.');
    return <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.value is! String) {
      errors.add('$key/${entry.key} must be a string.');
      continue;
    }
    result[entry.key] = entry.value! as String;
  }
  return result;
}

Set<String> _matrixIds(Map<String, Object?> matrix) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return <String>{};
  return methods
      .whereType<Map<String, Object?>>()
      .map((row) => row['id'])
      .whereType<String>()
      .toSet();
}

Set<String> _matrixStringField(Map<String, Object?> matrix, String field) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return <String>{};
  return methods
      .whereType<Map<String, Object?>>()
      .map((row) => row[field])
      .whereType<String>()
      .toSet();
}

String _shortCommit(Object? commit) {
  if (commit is! String || commit.length < 12) return 'configured RN commit';
  return commit.substring(0, 12);
}

void _finish(List<String> errors) {
  if (errors.isEmpty) return;
  stderr.writeln('RN parity validation failed:');
  for (final error in errors) {
    stderr.writeln('- $error');
  }
  exit(1);
}
