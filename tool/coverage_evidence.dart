import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart';

/// The reviewed coverage scope excludes only generated Dart sources.
List<String> coverageSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path.replaceAll('\\', '/'))
        .where((path) => path.endsWith('.dart') && !path.endsWith('.g.dart'))
        .toList()
      ..sort();

/// Interfaces and export-only libraries have no executable line coverage.
/// Parse this structurally so adding a method body removes the exemption.
bool isDeclarationOnlySource(String path) {
  final parsed = parseString(content: File(path).readAsStringSync());
  return parsed.errors.isEmpty &&
      parsed.unit.declarations.every((declaration) {
        if (declaration is TypeAlias) return true;
        if (declaration is! ClassDeclaration) return false;
        final body = declaration.body;
        return body is EmptyClassBody ||
            body is BlockClassBody &&
                body.members.every(
                  (member) =>
                      member is MethodDeclaration &&
                      member.body is EmptyFunctionBody,
                );
      });
}

/// Binds coverage to source, tests and dependency resolution, including dirt.
String coverageInputHash() {
  final paths = <String>[
    ...coverageSources(),
    ...Directory(
      'test',
    ).listSync(recursive: true).whereType<File>().map((file) => file.path),
    ...Directory('tool')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.dart')),
    'pubspec.yaml',
    'pubspec.lock',
    'tool/release_baseline.json',
  ]..sort();
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            for (final path in paths)
              path: sha256.convert(File(path).readAsBytesSync()).toString(),
          }),
        ),
      )
      .toString();
}

String coverageCommit() {
  final result = Process.runSync('git', ['rev-parse', 'HEAD']);
  if (result.exitCode != 0) {
    throw StateError('Cannot attribute coverage to git HEAD.');
  }
  return (result.stdout as String).trim();
}
