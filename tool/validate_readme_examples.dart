import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Compiles the actual fenced Dart examples, with only app-owned inputs supplied
/// by the harness. Nothing is executed and no native wallet is created.
Future<void> main() async {
  final text = File('README.md').readAsStringSync();
  final examples = RegExp(
    r'```dart\n([\s\S]*?)\n```',
  ).allMatches(text).toList();
  if (examples.isEmpty) throw StateError('README has no Dart examples.');
  final directory = Directory('build/readme-validation')
    ..createSync(recursive: true);
  final file = File('${directory.path}/examples.dart');
  final imports = <String>{
    "import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';",
    for (final example in examples)
      if (example.group(1)!.trim().startsWith('import ') &&
          !example.group(1)!.contains('\n'))
        example.group(1)!.trim(),
  };
  final source = StringBuffer('''
${imports.map((directive) => '// ignore: unused_import\n$directive').join('\n')}
late String appRgbNodeStoragePath;
late String passwordFromUser;
late String passwordFromApprovedSecureStorage;
late GeneratedKeys keys;
late UtexoWallet wallet;
late UtexoUnlockConfig unlockConfig;
''');
  for (var i = 0; i < examples.length; i++) {
    final snippet = examples[i].group(1)!;
    if (snippet.trim().startsWith('import ') && !snippet.contains('\n')) {
      // Import-only snippets still need resolution, but intentionally have no
      // expression consuming the import in their minimal example.
      continue;
    }
    final wrapped = 'Future<void> readmeExample$i() async {\n$snippet\n}';
    final parsed = parseString(content: wrapped);
    final function = parsed.unit.declarations.single as FunctionDeclaration;
    final body = function.functionExpression.body as BlockFunctionBody;
    final outputs = body.block.statements
        .whereType<VariableDeclarationStatement>()
        .expand((statement) => statement.variables.variables)
        .map((variable) => variable.name.lexeme)
        .join(', ');
    source.writeln(
      'Future<void> readmeExample$i() async {\n$snippet\n'
      'Object.hashAll([$outputs]);\n}',
    );
  }
  file.writeAsStringSync(source.toString());
  try {
    final process = await Process.start(Platform.resolvedExecutable, [
      'analyze',
      '--fatal-infos',
      file.path,
    ], mode: ProcessStartMode.inheritStdio);
    exitCode = await process.exitCode;
  } finally {
    file.deleteSync();
  }
}
