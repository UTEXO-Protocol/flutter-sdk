import 'dart:io';

const _barrelPath = 'lib/rgb_sdk_flutter.dart';
const _docPath = 'doc/PUBLIC_API_REFERENCE.md';

void main() {
  final errors = <String>[];
  final docFile = File(_docPath);
  if (!docFile.existsSync()) {
    errors.add('Missing $_docPath.');
  }
  final doc = docFile.existsSync() ? docFile.readAsStringSync() : '';

  for (final section in <String>[
    '## Stability Tiers',
    '## Lifecycle Prerequisites',
    '## Units',
    '## Error Taxonomy',
    '## Side Effects',
    '## Secret Handling',
    '## Platform Support',
    '## Unsupported or Native-Blocked Behavior',
    '## Symbol Coverage Checklist',
  ]) {
    if (!doc.contains(section)) {
      errors.add('$_docPath is missing required section $section.');
    }
  }

  for (final symbol in _exportedPublicSymbols()) {
    if (!RegExp('`${RegExp.escape(symbol)}`').hasMatch(doc)) {
      errors.add('$_docPath does not document exported symbol `$symbol`.');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Public API documentation validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exit(1);
  }

  stdout.writeln(
    'Public API documentation valid: ${_exportedPublicSymbols().length} symbols.',
  );
}

Set<String> _exportedPublicSymbols() {
  final barrel = File(_barrelPath).readAsStringSync();
  final exportPattern = RegExp(r"export '([^']+)';");
  final symbols = <String>{'RgbSdkFlutter'};

  for (final match in exportPattern.allMatches(barrel)) {
    final file = File('lib/${match.group(1)!}');
    if (!file.existsSync()) {
      throw StateError('Exported file does not exist: ${file.path}');
    }
    symbols.addAll(_publicSymbolsIn(file.readAsStringSync()));
  }
  return symbols;
}

Set<String> _publicSymbolsIn(String source) {
  final declarations = <String>{};
  final declarationPattern = RegExp(
    r'^(?:abstract\s+final\s+class|abstract\s+interface\s+class|'
    r'abstract\s+class|sealed\s+class|class|enum|extension|typedef)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)',
    multiLine: true,
  );
  for (final match in declarationPattern.allMatches(source)) {
    final name = match.group(1)!;
    if (!name.startsWith('_')) declarations.add(name);
  }

  final functionPattern = RegExp(
    r'^(?:[A-Za-z][A-Za-z0-9_<>,?]*\s+)+([a-z][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  for (final match in functionPattern.allMatches(source)) {
    final name = match.group(1)!;
    if (!name.startsWith('_')) declarations.add(name);
  }
  return declarations;
}
