import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'android_elf.dart' show androidElfAbis;
import 'native_artifact_paths.dart';

final _digestPattern = RegExp(r'^[0-9a-f]{64}$');
const _recipePath = 'tool/build_rln_android_16k.sh';

// These checks bind local declarations to the pinned artifact and recipe bytes.
// They do not authenticate the builder or independently reproduce the artifact;
// the separate production provenance/signature gate (PKG-006) remains required.
class AndroidSourceBuildRecord {
  AndroidSourceBuildRecord._(
    this.path,
    this.digest,
    this.libraries,
    this.sourceCommit,
    this.recipeDigest,
    this.officialBaseAarDigest,
  );

  final String path;
  final String digest;
  final Map<String, Map<String, Object?>> libraries;
  final String sourceCommit;
  final String recipeDigest;
  final String officialBaseAarDigest;

  Map<String, Object?> get report => <String, Object?>{
    'scope': 'source-build-record-consistency',
    'status': 'checked',
    'manifest': path,
    'manifestSha256': digest,
    'trustedProvenance': false,
    'independentlyReproduced': false,
    'productionGate': 'PKG-006 remains required',
  };

  bool checkLibrary({
    required String abi,
    required int sizeBytes,
    required String digest,
    required List<String> failures,
  }) {
    final before = failures.length;
    final library = libraries[abi];
    if (library == null) {
      failures.add('Android source-build record has no JNI entry for $abi.');
    } else {
      _same(digest, library['sha256'], '$abi JNI SHA-256', failures);
      _same(sizeBytes, library['sizeBytes'], '$abi JNI size', failures);
    }
    return failures.length == before;
  }

  bool checkProvenanceDeclaration(Object? declaration, List<String> failures) {
    final before = failures.length;
    if (declaration is! Map<String, Object?>) {
      failures.add(
        'Android source-build provenance declaration must be an object.',
      );
      return false;
    }
    _same(declaration['manifest'], path, 'provenance manifest path', failures);
    _same(
      declaration['manifestSha256'],
      digest,
      'provenance manifest SHA-256',
      failures,
    );
    _same(
      declaration['sourceCommit'],
      sourceCommit,
      'provenance RLN commit',
      failures,
    );
    _same(
      declaration['recipeSha256'],
      recipeDigest,
      'provenance recipe SHA-256',
      failures,
    );
    _same(
      declaration['independentReproducibility'],
      'not-verified',
      'provenance independent reproduction (PKG-006)',
      failures,
    );
    final base = declaration['officialBaseAar'];
    if (base is! Map<String, Object?>) {
      failures.add(
        'Android source-build provenance input AAR must be an object.',
      );
    } else {
      _same(
        base['archiveSha256'],
        officialBaseAarDigest,
        'provenance input AAR SHA-256',
        failures,
      );
    }
    return failures.length == before;
  }
}

AndroidSourceBuildRecord? validateAndroidSourceBuildRecord({
  required Map<String, Object?> rln,
  required Map<String, Object?> android,
  required List<String> failures,
  Directory? repositoryRoot,
}) {
  final before = failures.length;
  final root = repositoryRoot ?? Directory.current;
  try {
    final path = android['sourceBuildManifest'];
    final digest = android['sourceBuildManifestSha256'];
    if (digest is! String || !_digestPattern.hasMatch(digest)) {
      throw const FormatException(
        'manifest SHA-256 must be a lowercase digest',
      );
    }
    final manifestFile = _localFile(root, path);
    if (manifestFile.lengthSync() > 1024 * 1024) {
      throw const FormatException('manifest exceeds 1 MiB');
    }
    final bytes = manifestFile.readAsBytesSync();
    if (sha256.convert(bytes).toString() != digest) {
      throw const FormatException('manifest SHA-256 differs from the baseline');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('manifest must be a JSON object');
    }
    _same(decoded['schemaVersion'], 1, 'schema version', failures);
    _same(decoded['scope'], 'derived-android-native-build', 'scope', failures);
    _same(decoded['upstreamRelease'], rln['version'], 'RLN version', failures);
    _same(decoded['sourceCommit'], rln['commit'], 'RLN commit', failures);
    _same(decoded['sourceTag'], rln['tag'], 'RLN tag', failures);
    _same(
      decoded['sourceRepository'],
      rln['repository'],
      'RLN repository',
      failures,
    );
    if (!decoded.containsKey('sourceOverlay') ||
        decoded['sourceOverlay'] != null) {
      failures.add(
        'Android source-build record must explicitly declare no source overlay.',
      );
    }
    final coordinate = MavenArtifactCoordinate.parse(
      android['mavenCoordinate'] as String,
    );
    _same(
      decoded['derivedArtifactVersion'],
      coordinate.version,
      'derived version',
      failures,
    );
    final recipeDigest = decoded['buildRecipeSha256'];
    if (recipeDigest is! String ||
        !_digestPattern.hasMatch(recipeDigest) ||
        sha256
                .convert(_localFile(root, _recipePath).readAsBytesSync())
                .toString() !=
            recipeDigest) {
      failures.add(
        'Android source-build record recipe SHA-256 differs from the actual recipe.',
      );
    }
    final aar = decoded['aar'];
    if (aar is! Map<String, Object?>) {
      throw const FormatException('aar must be an object');
    }
    _same(
      aar['file'],
      coordinate.fileName,
      'AAR coordinate filename',
      failures,
    );
    final archiveUri = Uri.parse(android['archiveUrl'] as String);
    _same(
      aar['file'],
      archiveUri.pathSegments.last,
      'AAR URL filename',
      failures,
    );
    _same(aar['sha256'], android['archiveSha256'], 'AAR SHA-256', failures);
    _same(aar['sizeBytes'], android['archiveSizeBytes'], 'AAR size', failures);
    for (final claim in <String>[
      'generatedKotlinByteParity',
      'generatedKotlinByteParityAfterStrip',
      'stockFfiExportParity',
      'stockDtNeededParity',
      'unchangedNonJniAarEntries',
    ]) {
      _same(decoded[claim], true, claim, failures);
    }
    _same(
      decoded['independentReproducibility'],
      'not-verified',
      'independent reproducibility (PKG-006)',
      failures,
    );
    _same(
      decoded['officialSignatureAppliesToDerivedArtifact'],
      false,
      'upstream signature scope (PKG-006)',
      failures,
    );
    final abis = android['abis'];
    if (abis is! List<Object?> ||
        abis.isEmpty ||
        abis.any((abi) => abi is! String || !androidElfAbis.containsKey(abi)) ||
        abis.toSet().length != abis.length) {
      throw const FormatException(
        'baseline ABIs must be unique known Android ABIs',
      );
    }
    final libraryObjects = decoded['libraries'];
    if (libraryObjects is! Map<String, Object?> ||
        libraryObjects.length != abis.length ||
        !libraryObjects.keys.toSet().containsAll(abis)) {
      throw const FormatException('library ABI set differs from the baseline');
    }
    final libraries = <String, Map<String, Object?>>{};
    for (final entry in libraryObjects.entries) {
      final library = entry.value;
      if (library is! Map<String, Object?> ||
          library['sha256'] is! String ||
          !_digestPattern.hasMatch(library['sha256']! as String) ||
          library['sizeBytes'] is! int ||
          (library['sizeBytes']! as int) <= 0 ||
          library['ffiExportNamesSha256'] is! String ||
          !_digestPattern.hasMatch(
            library['ffiExportNamesSha256']! as String,
          ) ||
          library['ffiExportCount'] is! int ||
          (library['ffiExportCount']! as int) <= 0) {
        throw FormatException(
          'invalid library digest/size/FFI inventory: ${entry.key}',
        );
      }
      final needed = library['dtNeeded'];
      if (needed is! List<Object?> ||
          needed.length != 3 ||
          needed.toSet().length != 3 ||
          !needed.toSet().containsAll(<String>{
            'libc.so',
            'libdl.so',
            'libm.so',
          })) {
        throw FormatException(
          'unexpected runtime library dependencies: ${entry.key}',
        );
      }
      libraries[entry.key] = library;
    }
    final baseDigest = decoded['officialBaseAarSha256'];
    if (baseDigest is! String || !_digestPattern.hasMatch(baseDigest)) {
      throw const FormatException('invalid official input AAR digest');
    }
    if (failures.length != before) return null;
    return AndroidSourceBuildRecord._(
      path! as String,
      digest,
      libraries,
      decoded['sourceCommit']! as String,
      recipeDigest! as String,
      baseDigest,
    );
  } on Object catch (error) {
    failures.add('Android source-build record consistency failed: $error');
    return null;
  }
}

File _localFile(Directory root, Object? value) {
  if (value is! String ||
      !value.startsWith('tool/') ||
      value
          .split('/')
          .any(
            (part) =>
                part == '.' ||
                part == '..' ||
                !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(part),
          )) {
    throw const FormatException(
      'manifest/recipe path must be a local relative tool path',
    );
  }
  final file = File('${root.path}/$value');
  final rootPath = root.resolveSymbolicLinksSync();
  if (!file.resolveSymbolicLinksSync().startsWith(
    '$rootPath${Platform.pathSeparator}',
  )) {
    throw const FormatException('manifest/recipe path escapes the repository');
  }
  return file;
}

void _same(
  Object? actual,
  Object? expected,
  String label,
  List<String> failures,
) {
  if (expected == null || actual != expected) {
    failures.add('Android source-build record $label mismatch.');
  }
}
