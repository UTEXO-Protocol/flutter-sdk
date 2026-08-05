import 'dart:io';

const _maxHandWrittenDartLines = 1700;
const _maxNativePluginLines = 1500;

void main() {
  final failures = <String>[];

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

  final wallet = File('lib/src/wallet/utexo_wallet.dart').readAsStringSync();
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

  final collectionFields = RegExp(
    r'final\s+(?:List|Map)<[^;]+;\s*$',
    multiLine: true,
  );
  for (final file in <String>[
    'lib/src/wallet/utexo_wallet_types.dart',
    'lib/src/models/rln_models.dart',
    'lib/src/models/utexo_core_models.dart',
    'lib/src/lsp/lsp_types.dart',
    'lib/src/utexo/network.dart',
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
