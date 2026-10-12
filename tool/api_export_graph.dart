import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Names visible through one or more export paths, not implementation imports.
final class DartExportVisibility {
  const DartExportVisibility.all() : show = null, hide = const {};

  DartExportVisibility._({Set<String>? show, Set<String> hide = const {}})
    : show = show == null ? null : Set.unmodifiable(show),
      hide = Set.unmodifiable(hide);

  final Set<String>? show;
  final Set<String> hide;

  bool allows(String name) =>
      !name.startsWith('_') &&
      (show == null || show!.contains(name)) &&
      !hide.contains(name);

  DartExportVisibility restrict(Iterable<Combinator> combinators) {
    var result = this;
    for (final combinator in combinators) {
      switch (combinator) {
        case ShowCombinator(:final shownNames):
          result = DartExportVisibility._(
            show: shownNames
                .map((name) => name.name)
                .where(result.allows)
                .toSet(),
          );
        case HideCombinator(:final hiddenNames):
          result = DartExportVisibility._(
            show: result.show,
            hide: {...result.hide, ...hiddenNames.map((name) => name.name)},
          );
      }
    }
    return result;
  }

  /// Export paths form a union; a later narrow barrel cannot hide an earlier API.
  DartExportVisibility union(DartExportVisibility other) {
    if (show != null && other.show != null) {
      return DartExportVisibility._(
        show: {
          ...show!,
          ...other.show!,
        }.where((name) => allows(name) || other.allows(name)).toSet(),
      );
    }
    if (show == null && other.show == null) {
      return DartExportVisibility._(hide: hide.intersection(other.hide));
    }
    final unrestricted = show == null ? this : other;
    final restricted = show == null ? other : this;
    return DartExportVisibility._(
      hide: unrestricted.hide.difference(
        restricted.show!.where(restricted.allows).toSet(),
      ),
    );
  }

  String get fingerprint {
    final names = show?.where(allows).toList()?..sort();
    final exclusions = hide.toList()..sort();
    return names == null ? '*!${exclusions.join(',')}' : names.join(',');
  }
}

/// Resolves multiline/transitive exports and parts, retaining show/hide policy.
///
/// A fixed point handles cycles and repeated exports without order-dependent
/// omission. External/conditional exports fail closed until explicitly modeled.
Map<String, DartExportVisibility> collectDartExportGraph({
  required Iterable<String> entrypoints,
  required String Function(String path) readSource,
}) {
  final result = <String, DartExportVisibility>{};
  final pending = <(String, DartExportVisibility)>[
    for (final path in entrypoints) (path, const DartExportVisibility.all()),
  ];
  while (pending.isNotEmpty) {
    final (path, requested) = pending.removeLast();
    final previous = result[path];
    final visibility = previous?.union(requested) ?? requested;
    if (previous?.fingerprint == visibility.fingerprint) continue;
    result[path] = visibility;
    final parsed = parseString(content: readSource(path), path: path);
    if (parsed.errors.isNotEmpty) {
      throw StateError('Cannot snapshot invalid Dart library: $path');
    }
    for (final directive in parsed.unit.directives) {
      switch (directive) {
        case ExportDirective(
          :final uri,
          :final combinators,
          :final configurations,
        ):
          if (configurations.isNotEmpty) {
            throw StateError('Conditional export needs explicit policy: $path');
          }
          pending.add((
            _resolve(path, uri.stringValue),
            visibility.restrict(combinators),
          ));
        case PartDirective(:final uri):
          pending.add((_resolve(path, uri.stringValue), visibility));
        case LibraryDirective():
        case ImportDirective():
        case PartOfDirective():
          break;
      }
    }
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

String _resolve(String owner, String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.startsWith('/')) {
    throw StateError(
      'External or invalid export needs explicit policy: $owner',
    );
  }
  return Uri(path: owner).resolveUri(uri).path;
}
