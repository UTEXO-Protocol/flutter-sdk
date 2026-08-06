import 'dart:io';

const _barrelPath = 'lib/rgb_sdk_flutter.dart';
const _docPath = 'doc/PUBLIC_API_REFERENCE.md';
const _forbiddenStableRootSymbols = <String>{
  'IRLNExternalSignerBootstrap',
  'IRLNNodeCreateParams',
  'IRLNUnlockParams',
  'IUtexoLspClient',
  'Logger',
  'NativeBridgeFailure',
  'RLNBinding',
  'RLNManager',
  'RlnAddress',
  'RlnAsset',
  'RlnAssetBalance',
  'RlnAssetCfa',
  'RlnAssetIfa',
  'RlnAssetNia',
  'RlnAssetUda',
  'RlnAssets',
  'RlnBtcBalance',
  'RlnChannel',
  'RlnClient',
  'RlnDecodedLnInvoice',
  'RlnDecodedRgbInvoice',
  'RlnFeeRate',
  'RlnInvoice',
  'RlnLnInvoice',
  'RlnMap',
  'RlnNetworkInfo',
  'RlnNodeInfo',
  'RlnOpenChannelRequest',
  'RlnOpenChannelResult',
  'RlnPayment',
  'RlnPaymentResult',
  'RlnPeer',
  'RlnSendResult',
  'RlnSignMessageResult',
  'RlnTransaction',
  'RlnTransfer',
  'RlnUnspent',
  'RlnUtxo',
  'RlnVerifyMessageResult',
  'UtexoLspClient',
  'configureLogging',
  'createRLNManager',
  'logger',
  'mapNativeBridgeException',
};

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

  final exportedSymbols = _exportedPublicSymbols();
  final forbidden = exportedSymbols.intersection(_forbiddenStableRootSymbols);
  if (forbidden.isNotEmpty) {
    errors.add(
      'Stable root barrel exports advanced/internal symbols: '
      '${(forbidden.toList()..sort()).join(', ')}.',
    );
  }

  for (final symbol in exportedSymbols) {
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
    'Public API documentation valid: ${exportedSymbols.length} symbols.',
  );
}

Set<String> _exportedPublicSymbols() {
  final barrel = File(_barrelPath).readAsStringSync();
  final symbols = <String>{'RgbSdkFlutter'};

  for (final match in _exportDirectives(barrel)) {
    final file = File('lib/${match.path}');
    if (!file.existsSync()) {
      throw StateError('Exported file does not exist: ${file.path}');
    }
    final librarySymbols = <String>{};
    for (final libraryFile in _dartLibraryFiles(file)) {
      librarySymbols.addAll(_publicSymbolsIn(libraryFile.readAsStringSync()));
    }
    symbols.addAll(_filterSymbols(librarySymbols, match));
  }
  return symbols;
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

List<_ExportDirective> _exportDirectives(String barrel) {
  final exportPattern = RegExp(r"export '([^']+)'([^;]*);");
  return exportPattern
      .allMatches(barrel)
      .map(
        (match) => _ExportDirective(
          match.group(1)!,
          show: _symbolsFromCombinator(match.group(2)!, 'show'),
          hide: _symbolsFromCombinator(match.group(2)!, 'hide'),
        ),
      )
      .toList(growable: false);
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

Set<String> _filterSymbols(Set<String> symbols, _ExportDirective directive) {
  final show = directive.show;
  final hide = directive.hide ?? const <String>{};
  return symbols
      .where((symbol) => show == null || show.contains(symbol))
      .where((symbol) => !hide.contains(symbol))
      .toSet();
}

class _ExportDirective {
  const _ExportDirective(this.path, {this.show, this.hide});

  final String path;
  final Set<String>? show;
  final Set<String>? hide;
}
