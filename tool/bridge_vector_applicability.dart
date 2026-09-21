import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Derives only structural exclusions; never waives a supported runtime test.
Set<String> applicableFamilyVectors({
  required String pigeonSource,
  required Set<String> hostMethods,
  required Set<String> requiredVectors,
}) {
  final unit = parseString(content: pigeonSource).unit;
  final host = unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (node) => node.namePart.typeName.lexeme == 'RlnHostApi',
  );
  final declarations = (host.body as BlockClassBody).members
      .whereType<MethodDeclaration>()
      .where((method) => hostMethods.contains(method.name.lexeme))
      .toList();
  if (declarations.length != hostMethods.length || hostMethods.isEmpty) {
    throw StateError('Every bridge family method must resolve in Pigeon.');
  }
  final result = Set<String>.of(requiredVectors);
  if (hostMethods.length == 1 && hostMethods.single == 'rlnBackup') {
    // API-019: upstream deliberately rejects backup before argument/handle use.
    return {
      'dart-delegation',
      'dart-platform-error-mapping',
      'native-explicit-unsupported',
    };
  }
  if (!declarations.any(
    (method) => _containsType(method.returnType, 'RlnWireResponse'),
  )) {
    result.remove('dart-malformed-wire');
  }
  if (!declarations.any(
    (method) => method.parameters!.parameters.any((raw) {
      final parameter = raw is DefaultFormalParameter ? raw.parameter : raw;
      return parameter is SimpleFormalParameter &&
          !{'nodeId', 'signerId'}.contains(parameter.name?.lexeme) &&
          (_containsType(parameter.type, 'int') ||
              _containsType(parameter.type, 'double'));
    }),
  )) {
    result.remove('native-invalid-argument');
  }
  return result;
}

bool _containsType(TypeAnnotation? type, String name) =>
    type is NamedType &&
    (type.name.lexeme == name ||
        (type.typeArguments?.arguments.any(
              (argument) => _containsType(argument, name),
            ) ??
            false));
