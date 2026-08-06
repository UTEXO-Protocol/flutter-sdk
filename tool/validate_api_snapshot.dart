import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

const _snapshotPath = 'tool/api_snapshot.json';

void main(List<String> args) {
  final current = _buildSnapshot();
  if (args.contains('--print-current')) {
    const encoder = JsonEncoder.withIndent('  ');
    stdout.writeln(encoder.convert(current));
    return;
  }

  final errors = <String>[];
  final snapshotFile = File(_snapshotPath);
  if (!snapshotFile.existsSync()) {
    errors.add('Missing $_snapshotPath. Run with --print-current to inspect.');
  } else {
    try {
      final expected =
          jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
      _compareSection('dartExportedSurface', expected, current, errors);
      _compareSection('pigeonSchema', expected, current, errors);
      _compareSection('generatedPigeonSurface', expected, current, errors);
      _compareSection('nativeBridgeSurface', expected, current, errors);
    } catch (error) {
      errors.add('$_snapshotPath is not valid snapshot JSON: $error');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('API snapshot validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    stderr.writeln(
      'Intentional API/ABI changes must update $_snapshotPath and cite the '
      'tracker row plus migration note in the same change.',
    );
    exit(1);
  }

  stdout.writeln('API snapshot validation passed.');
}

void _compareSection(
  String key,
  Map<String, Object?> expected,
  Map<String, Object?> current,
  List<String> errors,
) {
  final expectedSection = expected[key];
  final currentSection = current[key];
  if (expectedSection is! Map<String, Object?> ||
      currentSection is! Map<String, Object?>) {
    errors.add('$key must be a JSON object.');
    return;
  }

  for (final field in <String>['hash', 'count']) {
    if (expectedSection[field] != currentSection[field]) {
      errors.add(
        '$key $field changed: expected ${expectedSection[field]}, '
        'current ${currentSection[field]}.',
      );
    }
  }
}

Map<String, Object?> _buildSnapshot() {
  final exportedFiles = _exportedDartDirectives();
  final nativeFiles = <String>[
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbSdkFlutterPlugin.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnNodeStore.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnStorageDirectoryPolicy.kt',
    'ios/Classes/RgbSdkFlutterPlugin.swift',
    'ios/Classes/RlnBridgeErrorDetails.swift',
    'ios/Classes/RlnNodeStore.swift',
    'ios/Classes/RlnStorageDirectoryPolicy.swift',
  ];
  final generatedPigeonFiles = <String>[
    'lib/src/pigeon/rln_api.g.dart',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt',
    'ios/Classes/RlnApi.g.swift',
  ];

  return <String, Object?>{
    'schemaVersion': 1,
    'description':
        'Normalized public API and bridge snapshot. Update only with a tracker row and migration note.',
    'dartExportedSurface': _surface(
      exportedFiles.keys.toList(growable: false),
      dartExports: exportedFiles,
    ),
    'pigeonSchema': _surface(<String>['pigeons/rln_api.dart']),
    'generatedPigeonSurface': _surface(generatedPigeonFiles),
    'nativeBridgeSurface': _surface(nativeFiles),
  };
}

Map<String, Object?> _surface(
  List<String> files, {
  Map<String, _ExportDirective> dartExports =
      const <String, _ExportDirective>{},
}) {
  final entries = <String>[];
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Snapshot source does not exist: $path');
    }
    entries.add('### $path');
    entries.addAll(
      _normalizedPublicLines(
        path,
        file.readAsLinesSync(),
        dartExport: dartExports[path],
      ),
    );
  }
  final normalized = entries.join('\n');
  return <String, Object?>{
    'count': entries.length,
    'hash': crypto.sha256.convert(utf8.encode(normalized)).toString(),
    'files': files,
  };
}

Map<String, _ExportDirective> _exportedDartDirectives() {
  const entrypoints = <String>[
    'lib/rgb_sdk_flutter.dart',
    'lib/rgb_sdk_flutter_advanced.dart',
  ];
  final files = <String, _ExportDirective>{};
  final exportPattern = RegExp(r"export '([^']+)'([^;]*);");
  for (final entrypointPath in entrypoints) {
    final entrypoint = File(entrypointPath);
    for (final path in _dartLibraryFiles(entrypointPath)) {
      files[path] = const _ExportDirective();
    }
    for (final line in entrypoint.readAsLinesSync()) {
      final match = exportPattern.firstMatch(line);
      if (match == null) continue;
      final directive = _ExportDirective(
        show: _symbolsFromCombinator(match.group(2)!, 'show'),
        hide: _symbolsFromCombinator(match.group(2)!, 'hide'),
      );
      for (final path in _dartLibraryFiles('lib/${match.group(1)!}')) {
        files[path] = directive;
      }
    }
  }
  return Map<String, _ExportDirective>.fromEntries(
    files.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

List<String> _dartLibraryFiles(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>[path];
  final directory = file.parent.path == '.' ? '' : '${file.parent.path}/';
  final partPattern = RegExp(r"part '([^']+)';");
  final parts = partPattern
      .allMatches(file.readAsStringSync())
      .map((match) => '$directory${match.group(1)!}')
      .toList(growable: false);
  return <String>[path, ...parts];
}

List<String> _normalizedPublicLines(
  String path,
  List<String> lines, {
  _ExportDirective? dartExport,
}) {
  final output = <String>[];
  var inBlockComment = false;
  for (final original in lines) {
    var line = original.trim();
    if (line.isEmpty) continue;

    if (inBlockComment) {
      if (line.contains('*/')) inBlockComment = false;
      continue;
    }
    if (line.startsWith('/*')) {
      if (!line.contains('*/')) inBlockComment = true;
      continue;
    }
    if (line.startsWith('//') || line.startsWith('*')) continue;
    if (line.startsWith('import ')) continue;
    if (line.startsWith('@') && !line.startsWith('@HostApi')) continue;

    if (path.endsWith('.dart')) {
      if (_isDartPublicSurfaceLine(line) &&
          _isDartSymbolExported(line, dartExport)) {
        output.add(line);
      }
      continue;
    }
    if (path.endsWith('.kt')) {
      if (_isKotlinPublicSurfaceLine(line)) output.add(line);
      continue;
    }
    if (path.endsWith('.swift')) {
      if (_isSwiftPublicSurfaceLine(line)) output.add(line);
      continue;
    }
    output.add(line);
  }
  return output;
}

bool _isDartSymbolExported(String line, _ExportDirective? directive) {
  if (directive == null) return true;
  final symbol = _dartSymbolName(line);
  if (symbol == null) return true;
  final show = directive.show;
  final hide = directive.hide ?? const <String>{};
  return (show == null || show.contains(symbol)) && !hide.contains(symbol);
}

String? _dartSymbolName(String line) {
  if (line.startsWith('export ')) return null;
  final declaration = RegExp(
    r'^(?:abstract\s+final\s+class|abstract\s+interface\s+class|'
    r'abstract\s+class|sealed\s+class|class|enum|extension|typedef|mixin)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)',
  ).firstMatch(line);
  if (declaration != null) return declaration.group(1);

  final variable = RegExp(
    r'^(?:const|final|static const|static final)\s+'
    r'(?:[A-Za-z_][A-Za-z0-9_<>, ?]*\s+)?'
    r'([A-Za-z_][A-Za-z0-9_]*)\s*[=({]',
  ).firstMatch(line);
  if (variable != null) return variable.group(1);

  final member = RegExp(
    r'^(?:Future<[^>]+>|Future|Stream<[^>]+>|'
    r'[A-Z][A-Za-z0-9_<>, ?]*|bool|int|double|String|void)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)[({=]',
  ).firstMatch(line);
  return member?.group(1);
}

bool _isDartPublicSurfaceLine(String line) {
  if (line.startsWith('_')) return false;
  if (line.startsWith('export ')) return true;
  if (line.startsWith('class ') ||
      line.startsWith('abstract class ') ||
      line.startsWith('enum ') ||
      line.startsWith('extension ') ||
      line.startsWith('typedef ') ||
      line.startsWith('mixin ')) {
    return true;
  }
  if (line.startsWith('const ') ||
      line.startsWith('final ') ||
      line.startsWith('static const ') ||
      line.startsWith('static final ')) {
    return true;
  }
  return RegExp(
    r'^(?:Future<[^>]+>|Future|Stream<[^>]+>|[A-Z][A-Za-z0-9_<>, ?]*|bool|int|double|String|void)\s+[A-Za-z][A-Za-z0-9_]*[({]',
  ).hasMatch(line);
}

bool _isKotlinPublicSurfaceLine(String line) {
  return line.startsWith('class ') ||
      line.startsWith('interface ') ||
      line.startsWith('data class ') ||
      line.startsWith('enum class ') ||
      line.startsWith('fun ') ||
      line.startsWith('override fun ') ||
      line.startsWith('val ') ||
      line.startsWith('var ');
}

bool _isSwiftPublicSurfaceLine(String line) {
  return line.startsWith('class ') ||
      line.startsWith('struct ') ||
      line.startsWith('protocol ') ||
      line.startsWith('enum ') ||
      line.startsWith('func ') ||
      line.startsWith('static func ') ||
      line.startsWith('let ') ||
      line.startsWith('var ');
}

Set<String>? _symbolsFromCombinator(String source, String keyword) {
  final match = RegExp('(?:^|\\s)$keyword\\s+([^;]+)').firstMatch(source);
  if (match == null) return null;
  final raw = match.group(1)!;
  final stop = RegExp(r'\s(?:show|hide)\s').firstMatch(raw);
  final values = stop == null ? raw : raw.substring(0, stop.start);
  return values
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}

class _ExportDirective {
  const _ExportDirective({this.show, this.hide});

  final Set<String>? show;
  final Set<String>? hide;
}
