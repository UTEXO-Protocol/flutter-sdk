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
  final exportedFiles = _exportedDartFiles();
  final nativeFiles = <String>[
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbSdkFlutterPlugin.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnNodeStore.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnStorageDirectoryPolicy.kt',
    'ios/Classes/RgbSdkFlutterPlugin.swift',
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
    'dartExportedSurface': _surface(exportedFiles),
    'pigeonSchema': _surface(<String>['pigeons/rln_api.dart']),
    'generatedPigeonSurface': _surface(generatedPigeonFiles),
    'nativeBridgeSurface': _surface(nativeFiles),
  };
}

Map<String, Object?> _surface(List<String> files) {
  final entries = <String>[];
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Snapshot source does not exist: $path');
    }
    entries.add('### $path');
    entries.addAll(_normalizedPublicLines(path, file.readAsLinesSync()));
  }
  final normalized = entries.join('\n');
  return <String, Object?>{
    'count': entries.length,
    'hash': crypto.sha256.convert(utf8.encode(normalized)).toString(),
    'files': files,
  };
}

List<String> _exportedDartFiles() {
  final entrypoint = File('lib/rgb_sdk_flutter.dart');
  final files = <String>['lib/rgb_sdk_flutter.dart'];
  final exportPattern = RegExp(r"export '([^']+)';");
  for (final line in entrypoint.readAsLinesSync()) {
    final match = exportPattern.firstMatch(line);
    if (match == null) continue;
    files.add('lib/${match.group(1)!}');
  }
  files.sort();
  return files;
}

List<String> _normalizedPublicLines(String path, List<String> lines) {
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
      if (_isDartPublicSurfaceLine(line)) output.add(line);
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
