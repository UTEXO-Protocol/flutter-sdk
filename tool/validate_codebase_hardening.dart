import 'dart:convert';
import 'dart:io';

const _maxHandWrittenDartLines = 1700;
const _maxNativePluginLines = 1500;

void main() {
  final failures = <String>[];
  _requireZeroAnalyzerDiagnostics(failures);

  final analysis = File('analysis_options.yaml').readAsStringSync();
  for (final required in <String>[
    'strict-casts: true',
    'strict-inference: true',
    'strict-raw-types: true',
    'lib/src/pigeon/**',
    'directives_ordering: true',
    'sort_pub_dependencies: true',
    'unawaited_futures: true',
    'type_annotate_public_apis: true',
  ]) {
    if (!analysis.contains(required)) {
      failures.add('analysis_options.yaml must contain `$required`.');
    }
  }

  for (final path in <String>[
    'lib/src/wallet/utexo_wallet_types.dart',
    'lib/src/wallet/utexo_wallet_guards.dart',
    'lib/src/wallet/utexo_wallet_lifecycle.dart',
    'lib/src/wallet/utexo_wallet_lsp_apay.dart',
    'lib/src/wallet/utexo_wallet_onchain.dart',
    'lib/src/wallet/utexo_wallet_lightning.dart',
    'lib/src/wallet/utexo_wallet_raw.dart',
    'lib/src/wallet/utexo_unlock_config_resolver.dart',
    'lib/src/wallet/wallet_policy.dart',
    'lib/src/binding/rln_binding_types.dart',
    'lib/src/binding/rln_binding_lifecycle.dart',
    'lib/src/binding/rln_binding_lightning.dart',
    'lib/src/binding/rln_binding_onchain.dart',
    'lib/src/models/utexo_domain_policy.dart',
    'lib/src/native_artifact_provider.dart',
    'ios/Classes/RlnBridgeErrorDetails.swift',
    'doc/PUBLIC_API_REFERENCE.md',
    'doc/COVERAGE_POLICY.md',
    'tool/validate_codebase_hardening.dart',
    'tool/validate_public_api_docs.dart',
    'tool/validate_release_language.dart',
    'tool/validate_coverage_policy.dart',
  ]) {
    if (!File(path).existsSync()) {
      failures.add('Missing hardening artifact: $path');
    }
  }

  for (final file
      in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.contains('/src/pigeon/'))
          .where((file) => !file.path.endsWith('/release_baseline.g.dart'))) {
    final lineCount = file.readAsLinesSync().length;
    if (lineCount > _maxHandWrittenDartLines) {
      failures.add(
        '${_relative(file.path)} has $lineCount lines; split hand-written Dart '
        'files before exceeding $_maxHandWrittenDartLines.',
      );
    }
  }

  for (final file
      in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.contains('/src/pigeon/'))) {
    final source = file.readAsStringSync();
    for (final forbidden in <String>[
      'throw ArgumentError',
      'throw StateError',
      'throw FormatException',
      'throw UnsupportedError',
      'throw Exception(',
    ]) {
      if (source.contains(forbidden)) {
        failures.add(
          '${_relative(file.path)} exposes an untyped Dart exception through '
          'hand-written package code: `$forbidden`.',
        );
      }
    }
  }

  for (final file in <File>[
    File('ios/Classes/RgbSdkFlutterPlugin.swift'),
    File(
      'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbSdkFlutterPlugin.kt',
    ),
  ]) {
    final lineCount = file.readAsLinesSync().length;
    if (lineCount > _maxNativePluginLines) {
      failures.add(
        '${file.path} has $lineCount lines; split native plugin code before '
        'exceeding $_maxNativePluginLines.',
      );
    }
  }

  final wallet = _readLibraryFiles('lib/src/wallet', <String>[
    'utexo_wallet.dart',
    'utexo_wallet_guards.dart',
    'utexo_wallet_lifecycle.dart',
    'utexo_wallet_lsp_apay.dart',
    'utexo_wallet_onchain.dart',
    'utexo_wallet_lightning.dart',
    'utexo_unlock_config_resolver.dart',
  ]);
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final root = File('lib/rgb_sdk_flutter.dart').readAsStringSync();
  final cryptoMessage = File('lib/src/crypto/message.dart').readAsStringSync();
  final binding = _readLibraryFiles('lib/src/binding', <String>[
    'rln_binding.dart',
    'rln_binding_types.dart',
    'rln_binding_lifecycle.dart',
    'rln_binding_lightning.dart',
    'rln_binding_onchain.dart',
  ]);
  final walletPolicy = File(
    'lib/src/wallet/wallet_policy.dart',
  ).readAsStringSync();
  final coreModels = File(
    'lib/src/models/utexo_core_models.dart',
  ).readAsStringSync();
  final domainPolicy = File(
    'lib/src/models/utexo_domain_policy.dart',
  ).readAsStringSync();
  final lsp = File('lib/src/lsp/utexo_lsp.dart').readAsStringSync();
  final lspErrors = File('lib/src/lsp/lsp_errors.dart').readAsStringSync();
  final lspClient = File(
    'lib/src/lsp/utexo_lsp_client.dart',
  ).readAsStringSync();

  for (final removed in <String>[
    'lib/rgb_sdk_flutter_platform_interface.dart',
    'lib/rgb_sdk_flutter_method_channel.dart',
  ]) {
    if (File(removed).existsSync()) {
      failures.add(
        '$removed must not exist; native operations are owned by Pigeon/RLNBinding.',
      );
    }
  }
  if (pubspec.contains('plugin_platform_interface')) {
    failures.add(
      'pubspec.yaml must not depend on plugin_platform_interface; the package is not a federated platform-interface bridge.',
    );
  }
  if (!root.contains('NativeArtifactInfoReader().getNativeArtifactInfo()')) {
    failures.add(
      'RgbSdkFlutter.nativeArtifactInfo() must use the internal Pigeon metadata reader.',
    );
  }
  if (!cryptoMessage.contains('enum SchnorrSigningMode') ||
      !cryptoMessage.contains('SchnorrSigningMode.disabled') ||
      !cryptoMessage.contains('ExperimentalCryptoException') ||
      !cryptoMessage.contains('_requireExperimentalDartSigning')) {
    failures.add(
      'Standalone Dart Schnorr signing must fail closed behind SchnorrSigningMode.experimentalDart.',
    );
  }
  if (binding.contains('error.toString().toLowerCase()') ||
      binding.contains("text.contains('already')")) {
    failures.add(
      'RLNBinding must not classify lifecycle conflicts by parsing error strings.',
    );
  }
  for (final type in <String>[
    'class UtexoWalletConfig',
    'class UtexoUnlockConfig',
    'class RgbSendRequest',
    'class InflateAssetIfaRequest',
    'class ListLightningPaymentsResponse',
  ]) {
    if (wallet.contains(type)) {
      failures.add('lib/src/wallet/utexo_wallet.dart still owns `$type`.');
    }
  }
  for (final required in <String>[
    'WalletInputPolicy.validateConfig(_config)',
    'WalletInputPolicy.requireNonEmpty(value, field)',
    'WalletInputPolicy.requireIntegerFeeRate(value, field)',
    'WalletInputPolicy.requireSupportedRgbSendSkipSync(skipSync)',
  ]) {
    if (!wallet.contains(required)) {
      failures.add(
        'lib/src/wallet/utexo_wallet.dart must delegate validation through `$required`.',
      );
    }
  }
  for (final required in <String>[
    "_requiredNativeString(response, 'txid', 'RlnSendBtcResponse')",
    "'RlnFailTransfersResponse'",
    "'RlnClaimHodlInvoiceResponse'",
    "'RlnSendPaymentResponse.paymentHash'",
  ]) {
    if (!wallet.contains(required)) {
      failures.add(
        'Stable wallet native success decoding must retain `$required`.',
      );
    }
  }
  for (final forbidden in <String>[
    "response['txid']! as String",
    "response['transfersChanged'] == true",
    "response['changed'] == true",
    "payment.paymentHash ?? payment.paymentId ?? ''",
  ]) {
    if (wallet.contains(forbidden)) {
      failures.add(
        'Stable wallet must not fabricate or loosely cast native success '
        'fields: `$forbidden`.',
      );
    }
  }
  for (final forbidden in <String>[
    'throw ArgumentError',
    'throw StateError',
    'const validStatuses',
    'const validKinds',
  ]) {
    if (wallet.contains(forbidden)) {
      failures.add(
        'lib/src/wallet/utexo_wallet.dart must not contain `$forbidden`.',
      );
    }
  }
  for (final required in <String>[
    'class WalletInputPolicy',
    'static void requireNonEmpty',
    'static void requireIntegerFeeRate',
    'static void validateConfig',
  ]) {
    if (!walletPolicy.contains(required)) {
      failures.add('Wallet input policy missing `$required`.');
    }
  }
  for (final required in <String>[
    'class UtexoDomainPolicy',
    'transactionTypes',
    'transferStatuses',
    'transferKinds',
    'channelStatuses',
  ]) {
    if (!domainPolicy.contains(required)) {
      failures.add('Domain model policy missing `$required`.');
    }
  }
  for (final required in <String>[
    'UtexoDomainPolicy.mapTransactionType',
    'UtexoDomainPolicy.requireTransferStatus',
    'UtexoDomainPolicy.requireTransferKind',
    'UtexoDomainPolicy.normalizeChannelStatus',
  ]) {
    if (!coreModels.contains(required)) {
      failures.add(
        'lib/src/models/utexo_core_models.dart must use `$required`.',
      );
    }
  }
  for (final forbidden in <String>[
    'const validStatuses',
    'const validKinds',
    'const typeMap',
  ]) {
    if (coreModels.contains(forbidden)) {
      failures.add(
        'lib/src/models/utexo_core_models.dart still owns `$forbidden`.',
      );
    }
  }
  for (final forbidden in <String>['implements Exception']) {
    if (lspErrors.contains(forbidden) || lspClient.contains(forbidden)) {
      failures.add(
        'Stable LSP errors must extend RgbSdkException subclasses, not `$forbidden`.',
      );
    }
  }
  for (final forbidden in <String>['throw ArgumentError', 'throw StateError']) {
    if (lsp.contains(forbidden) || lspClient.contains(forbidden)) {
      failures.add('Stable LSP code must not contain `$forbidden`.');
    }
  }

  final collectionFields = RegExp(
    r'final\s+(?:List|Map)<[^>]+>\s+(?!_)[^;]+;\s*$',
    multiLine: true,
  );
  for (final file in <String>[
    'lib/src/wallet/utexo_wallet_types.dart',
    'lib/src/models/rln_models.dart',
    'lib/src/models/utexo_core_models.dart',
    'lib/src/lsp/lsp_types.dart',
    'lib/src/binding/rln_binding.dart',
  ]) {
    final text = File(file).readAsStringSync();
    if (collectionFields.hasMatch(text) && !text.contains('.unmodifiable(')) {
      failures.add(
        '$file has public collection fields without defensive copies.',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Codebase hardening validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Codebase hardening validation passed.');
}

String _relative(String path) {
  final cwd = '${Directory.current.path}/';
  return path.startsWith(cwd) ? path.substring(cwd.length) : path;
}

String _readLibraryFiles(String directory, List<String> names) {
  return names
      .map((name) => File('$directory/$name').readAsStringSync())
      .join('\n');
}

void _requireZeroAnalyzerDiagnostics(List<String> failures) {
  final result = Process.runSync('dart', <String>['analyze', '--format=json']);
  final output = (result.stdout as String).trim();
  if (output.isEmpty) {
    if (result.exitCode != 0) {
      failures.add('dart analyze --format=json exited ${result.exitCode}.');
    }
    return;
  }

  try {
    final decoded = jsonDecode(output);
    if (decoded is! Map<String, Object?>) {
      failures.add('dart analyze --format=json returned an unexpected shape.');
      return;
    }
    final diagnostics = decoded['diagnostics'];
    if (diagnostics is! List || diagnostics.isEmpty) return;
    failures.add(
      'dart analyze must report zero diagnostics for release candidates; '
      'found ${diagnostics.length}.',
    );
    for (final diagnostic in diagnostics.take(10)) {
      if (diagnostic is! Map) continue;
      final code = diagnostic['code'];
      final location = diagnostic['location'];
      final message = diagnostic['problemMessage'];
      failures.add('- ${_formatLocation(location)} [$code] $message');
    }
  } on FormatException catch (error) {
    failures.add('Could not parse dart analyze JSON output: $error');
  }
}

String _formatLocation(Object? location) {
  if (location is! Map) return 'unknown location';
  final file = location['file'];
  final range = location['range'];
  if (range is! Map) return file?.toString() ?? 'unknown location';
  final start = range['start'];
  if (start is! Map) return file?.toString() ?? 'unknown location';
  final line = start['line'];
  final column = start['column'];
  return '$file:$line:$column';
}
