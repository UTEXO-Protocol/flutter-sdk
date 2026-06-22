import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  final errors = <String>[];

  final manifest = _readJsonObject(
    File('${root.path}/tool/rn_parity_manifest.json'),
    errors,
  );
  final rnPath = _resolveRnPath(manifest);
  final rnRoot = Directory(rnPath);
  if (!rnRoot.existsSync()) {
    errors.add(
      'RN reference repo not found at $rnPath. Set RGB_SDK_RN_PATH to the '
      'rgb-sdk-rn dev checkout.',
    );
    _finish(errors);
  }

  _validateRnCommit(rnRoot, manifest, errors);
  _validateLowLevelNativeMethods(root, rnRoot, errors);
  _validateWalletMethods(root, rnRoot, errors);
  _validateRuntimeExports(root, rnRoot, manifest, errors);
  _validateScopedTypeStars(rnRoot, manifest, errors);

  _finish(errors);

  stdout.writeln(
    'RN parity valid against ${_shortCommit(manifest['rnReferenceCommit'])}: '
    'NativeRgb methods, UTEXOWallet methods, and runtime package exports.',
  );
}

String _resolveRnPath(Map<String, Object?> manifest) {
  final envPath = Platform.environment['RGB_SDK_RN_PATH'];
  if (envPath != null && envPath.trim().isNotEmpty) return envPath.trim();
  final manifestPath = manifest['rnDefaultPath'];
  if (manifestPath is String && manifestPath.trim().isNotEmpty) {
    return manifestPath.trim();
  }
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

void _validateRnCommit(
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final expected = manifest['rnReferenceCommit'];
  if (expected is! String || expected.isEmpty) {
    errors.add('rn_parity_manifest.json must define rnReferenceCommit.');
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
  if (actual != expected) {
    errors.add(
      'RN reference commit mismatch. Expected $expected, found $actual at '
      '${rnRoot.path}. Update the RN checkout or deliberately update the '
      'manifest after a new parity audit.',
    );
  }
}

void _validateLowLevelNativeMethods(
  Directory root,
  Directory rnRoot,
  List<String> errors,
) {
  final rnMethods = _extractRnNativeRgbMethods(
    File('${rnRoot.path}/src/binding/NativeRgb.ts'),
    errors,
  );
  final matrix = _readJsonObject(
    File('${root.path}/tool/test_matrix/rln_methods.json'),
    errors,
  );
  final flutterHostApis = _matrixStringField(matrix, 'hostApi');

  final missing = rnMethods.difference(flutterHostApis).toList()..sort();
  final stale = flutterHostApis.difference(rnMethods).toList()..sort();

  for (final method in missing) {
    errors.add('RN NativeRgb.$method is missing from rln_methods.json.');
  }
  for (final method in stale) {
    errors.add('rln_methods.json hostApi $method is not in RN NativeRgb.ts.');
  }
}

Set<String> _extractRnNativeRgbMethods(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN NativeRgb source: ${file.path}');
    return <String>{};
  }
  final methods = <String>{};
  final methodRegex = RegExp(r'^\s*(rln[A-Za-z0-9_]+)\s*\(');
  for (final line in file.readAsLinesSync()) {
    final match = methodRegex.firstMatch(line);
    if (match != null) methods.add(match.group(1)!);
  }
  return methods;
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
