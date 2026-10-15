class MavenArtifactCoordinate {
  MavenArtifactCoordinate._(this.group, this.module, this.version);

  factory MavenArtifactCoordinate.parse(String coordinate) {
    final match = RegExp(
      r'^([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*):'
      r'([A-Za-z0-9_][A-Za-z0-9_.-]*):'
      r'([A-Za-z0-9_][A-Za-z0-9_.+-]*)$',
    ).firstMatch(coordinate);
    if (match == null) {
      throw const FormatException('Invalid three-part Maven coordinate.');
    }
    return MavenArtifactCoordinate._(match[1]!, match[2]!, match[3]!);
  }

  final String group;
  final String module;
  final String version;

  String get fileName => '$module-$version.aar';
  String cacheDirectory(String home) =>
      '$home/.gradle/caches/modules-2/files-2.1/$group/$module/$version';
}
