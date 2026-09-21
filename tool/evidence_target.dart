import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Resolves a catalog ID to a named test or test group, never a shell label.
/// Registration is not execution proof; platform reports remain mandatory.
String? evidenceTargetError(String testId) {
  final separator = testId.indexOf('::');
  if (separator <= 0 || separator == testId.length - 2) {
    return 'Malformed test ID: $testId';
  }
  final path = testId.substring(0, separator);
  final identifier = testId.substring(separator + 2);
  final file = File(path);
  if (!file.existsSync()) return 'Missing test source: $path';
  return registeredTestNames(path, file.readAsStringSync()).contains(identifier)
      ? null
      : 'No registered test/group "$identifier" in $path';
}

Set<String> registeredTestNames(String path, String source) {
  if (path.endsWith('.dart')) {
    final parsed = parseString(content: source);
    if (parsed.errors.isNotEmpty) return <String>{};
    final visitor = _TestNames();
    parsed.unit.accept(visitor);
    return visitor.names;
  }
  final pattern = path.endsWith('.kt')
      ? RegExp(r'@Test\s+fun\s+(\w+)\s*\(')
      : path.endsWith('.swift')
      ? RegExp(r'\bfunc\s+(test\w+)\s*\(')
      : null;
  return pattern?.allMatches(source).map((match) => match.group(1)!).toSet() ??
      <String>{};
}

class _TestNames extends RecursiveAstVisitor<void> {
  final names = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (const {'test', 'testWidgets', 'group'}.contains(node.methodName.name)) {
      final first = node.argumentList.arguments.firstOrNull;
      if (first is StringLiteral && first.stringValue != null) {
        names.add(first.stringValue!);
      }
    }
    super.visitMethodInvocation(node);
  }
}
