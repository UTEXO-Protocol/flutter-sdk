import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/android_source_build_record.dart';

void main() {
  late _Fixture fixture;
  setUp(() => fixture = _Fixture.create());
  tearDown(() => fixture.root.deleteSync(recursive: true));

  test('matching records bind declarations without elevating provenance', () {
    final failures = <String>[];
    final record = fixture.validate(failures);
    expect(failures, isEmpty);
    expect(record, isNotNull);
    expect(record!.report['scope'], 'source-build-record-consistency');
    expect(record.report['trustedProvenance'], false);
    expect(record.report['independentlyReproduced'], false);
    expect(record.report['productionGate'], contains('PKG-006'));
    final bytes = utf8.encode('arm64-v8a JNI bytes');
    expect(
      record.checkLibrary(
        abi: 'arm64-v8a',
        sizeBytes: bytes.length,
        digest: sha256.convert(bytes).toString(),
        failures: failures,
      ),
      true,
    );
    expect(failures, isEmpty);
  });

  test('the committed record matches the current baseline and recipe', () {
    final baseline =
        jsonDecode(File('tool/release_baseline.json').readAsStringSync())
            as Map<String, Object?>;
    final rln = baseline['rln']! as Map<String, Object?>;
    final failures = <String>[];
    final record = validateAndroidSourceBuildRecord(
      rln: rln,
      android: rln['android']! as Map<String, Object?>,
      failures: failures,
    );
    expect(failures, isEmpty);
    expect(record, isNotNull);
  });

  test(
    'unrepinned record edits and missing digests fail before interpretation',
    () {
      fixture.file.writeAsStringSync('${fixture.file.readAsStringSync()} ');
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures.single, contains('manifest SHA-256 differs'));
      fixture.android.remove('sourceBuildManifestSha256');
      failures.clear();
      expect(fixture.validate(failures), isNull);
      expect(failures.single, contains('manifest SHA-256 must'));
    },
  );

  test('a repinned malformed or non-object record fails closed', () {
    for (final contents in <String>['{', '[]']) {
      fixture.file.writeAsStringSync(contents);
      fixture.pin();
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures, isNotEmpty);
    }
  });

  for (final path in <String>[
    '/tmp/record.json',
    'tool/../record.json',
    'tool/./record.json',
    'tool//record.json',
    r'tool\record.json',
    'tool/%2e%2e/record.json',
    'file:///tmp/record.json',
  ]) {
    test('rejects non-local manifest path $path', () {
      fixture.android['sourceBuildManifest'] = path;
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures.single, contains('local relative tool path'));
    });
  }

  test('a manifest symlink cannot escape the repository', () {
    final outside = Directory.systemTemp.createTempSync('rgb-record-outside-');
    addTearDown(() => outside.deleteSync(recursive: true));
    final target = File('${outside.path}/record.json')
      ..writeAsBytesSync(fixture.file.readAsBytesSync());
    Link('${fixture.root.path}/tool/link.json').createSync(target.path);
    fixture.android['sourceBuildManifest'] = 'tool/link.json';
    final failures = <String>[];
    expect(fixture.validate(failures), isNull);
    expect(failures.single, contains('escapes the repository'));
  });

  test(
    'changed recipe bytes fail even when the record digest remains pinned',
    () {
      fixture.recipe.writeAsStringSync('a changed compiler recipe');
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures, contains(contains('recipe SHA-256 differs')));
    },
  );

  for (final field in <String>[
    'sourceCommit',
    'upstreamRelease',
    'sourceTag',
    'sourceRepository',
    'derivedArtifactVersion',
    'scope',
  ]) {
    test('repinning cannot hide mismatched $field', () {
      fixture.manifest[field] = 'different';
      fixture.write();
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures, isNotEmpty);
    });
  }

  test('an overlay must be explicitly absent, including after repinning', () {
    for (final present in <bool>[true, false]) {
      if (present) {
        fixture.manifest['sourceOverlay'] = 'unreviewed';
      } else {
        fixture.manifest.remove('sourceOverlay');
      }
      fixture.write();
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures, contains(contains('no source overlay')));
    }
  });

  for (final field in <String>['file', 'sha256', 'sizeBytes']) {
    test('AAR $field stays bound to the baseline after record repinning', () {
      (fixture.manifest['aar']! as Map<String, Object?>)[field] =
          field == 'sizeBytes' ? 99 : 'different';
      fixture.write();
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(failures, isNotEmpty);
    });
  }

  for (final field in <String>[
    'generatedKotlinByteParity',
    'generatedKotlinByteParityAfterStrip',
    'stockFfiExportParity',
    'stockDtNeededParity',
    'unchangedNonJniAarEntries',
  ]) {
    test('both missing and false $field fail after repinning', () {
      for (final present in <bool>[true, false]) {
        if (present) {
          fixture.manifest[field] = false;
        } else {
          fixture.manifest.remove(field);
        }
        fixture.write();
        final failures = <String>[];
        expect(fixture.validate(failures), isNull);
        expect(failures, contains(contains(field)));
      }
    });
  }

  test(
    'record claims cannot promote reproduction or upstream signature scope',
    () {
      fixture.manifest['independentReproducibility'] = 'verified';
      fixture.manifest['officialSignatureAppliesToDerivedArtifact'] = true;
      fixture.write();
      final failures = <String>[];
      expect(fixture.validate(failures), isNull);
      expect(
        failures.where((failure) => failure.contains('PKG-006')),
        hasLength(2),
      );
    },
  );

  test('missing, extra and duplicate ABI declarations fail closed', () {
    final libraries = fixture.manifest['libraries']! as Map<String, Object?>;
    final removed = libraries.remove('x86_64');
    fixture.write();
    expect(fixture.validate(<String>[]), isNull);
    libraries['x86_64'] = removed;
    libraries['x86'] = removed;
    fixture.write();
    expect(fixture.validate(<String>[]), isNull);
    libraries.remove('x86');
    fixture.write();
    fixture.android['abis'] = <String>[
      'arm64-v8a',
      'armeabi-v7a',
      'x86_64',
      'x86_64',
    ];
    expect(fixture.validate(<String>[]), isNull);
  });

  test('malformed library digests and new unbundled dependencies fail', () {
    final library =
        (fixture.manifest['libraries']! as Map<String, Object?>)['arm64-v8a']!
            as Map<String, Object?>;
    final original = library['sha256'];
    library['sha256'] = 'bad';
    fixture.write();
    expect(fixture.validate(<String>[]), isNull);
    library['sha256'] = original;
    library['dtNeeded'] = <String>['libc.so', 'libdl.so', 'libc++_shared.so'];
    fixture.write();
    expect(fixture.validate(<String>[]), isNull);
  });

  test('actual JNI bytes and length must match the per-ABI record', () {
    final record = fixture.validate(<String>[])!;
    final failures = <String>[];
    expect(
      record.checkLibrary(
        abi: 'arm64-v8a',
        sizeBytes: 1,
        digest: sha256.convert(utf8.encode('changed bytes')).toString(),
        failures: failures,
      ),
      false,
    );
    expect(failures, contains(contains('JNI SHA-256 mismatch')));
    expect(failures, contains(contains('JNI size mismatch')));
    expect(
      record.checkLibrary(
        abi: 'unrecorded',
        sizeBytes: 1,
        digest: '',
        failures: failures,
      ),
      false,
    );
  });

  for (final field in <String>[
    'manifest',
    'manifestSha256',
    'sourceCommit',
    'recipeSha256',
  ]) {
    test(
      'provenance sourceBuild $field must agree with the validated record',
      () {
        final record = fixture.validate(<String>[])!;
        final declaration = <String, Object?>{
          'manifest': fixture.android['sourceBuildManifest'],
          'manifestSha256': fixture.android['sourceBuildManifestSha256'],
          'sourceCommit': fixture.rln['commit'],
          'recipeSha256': fixture.manifest['buildRecipeSha256'],
          'independentReproducibility': 'not-verified',
          'officialBaseAar': <String, Object?>{
            'archiveSha256': fixture.manifest['officialBaseAarSha256'],
          },
        };
        expect(
          record.checkProvenanceDeclaration(declaration, <String>[]),
          true,
        );
        declaration[field] = 'different';
        final failures = <String>[];
        expect(record.checkProvenanceDeclaration(declaration, failures), false);
        expect(failures, isNotEmpty);
      },
    );
  }

  test(
    'provenance cannot omit sourceBuild or substitute its official input AAR',
    () {
      final record = fixture.validate(<String>[])!;
      expect(record.checkProvenanceDeclaration(null, <String>[]), false);
      final failures = <String>[];
      record.checkProvenanceDeclaration(<String, Object?>{
        'manifest': fixture.android['sourceBuildManifest'],
        'manifestSha256': fixture.android['sourceBuildManifestSha256'],
        'sourceCommit': fixture.rln['commit'],
        'recipeSha256': fixture.manifest['buildRecipeSha256'],
        'independentReproducibility': 'not-verified',
        'officialBaseAar': <String, Object?>{'archiveSha256': 'different'},
      }, failures);
      expect(failures.single, contains('input AAR SHA-256 mismatch'));
    },
  );
}

class _Fixture {
  _Fixture(
    this.root,
    this.recipe,
    this.file,
    this.rln,
    this.android,
    this.manifest,
  );
  final Directory root;
  final File recipe;
  final File file;
  final Map<String, Object?> rln;
  final Map<String, Object?> android;
  final Map<String, Object?> manifest;

  static _Fixture create() {
    final root = Directory.systemTemp.createTempSync(
      'rgb-source-build-record-',
    );
    Directory('${root.path}/tool').createSync();
    final recipe = File('${root.path}/tool/build_rln_android_16k.sh')
      ..writeAsStringSync('the exact build recipe');
    final file = File('${root.path}/tool/record.json');
    final rln = <String, Object?>{
      'version': '0.17.0-beta.3',
      'tag': 'v0.17.0-beta.3',
      'commit': 'ecc69f20308231400561f6f060fea88acfa40cc4',
      'repository': 'https://github.com/UTEXO-Protocol/rgb-lightning-node.git',
    };
    const name = 'rgb-lightning-node-android-0.17.0-beta.3-16k.1.aar';
    final aarHash = sha256
        .convert(utf8.encode('the complete AAR bytes'))
        .toString();
    final android = <String, Object?>{
      'mavenCoordinate':
          'com.utexo.flutter:rgb-lightning-node-android:0.17.0-beta.3-16k.1',
      'archiveUrl': 'https://example.org/$name',
      'archiveSha256': aarHash,
      'archiveSizeBytes': 123,
      'abis': <String>['arm64-v8a', 'armeabi-v7a', 'x86_64'],
      'sourceBuildManifest': 'tool/record.json',
    };
    final manifest = <String, Object?>{
      'schemaVersion': 1,
      'scope': 'derived-android-native-build',
      'upstreamRelease': rln['version'],
      'sourceCommit': rln['commit'],
      'sourceTag': rln['tag'],
      'sourceRepository': rln['repository'],
      'derivedArtifactVersion': '0.17.0-beta.3-16k.1',
      'sourceOverlay': null,
      'buildRecipeSha256': sha256.convert(recipe.readAsBytesSync()).toString(),
      'officialBaseAarSha256': aarHash,
      'aar': <String, Object?>{
        'file': name,
        'sha256': aarHash,
        'sizeBytes': 123,
      },
      'generatedKotlinByteParity': true,
      'generatedKotlinByteParityAfterStrip': true,
      'stockFfiExportParity': true,
      'stockDtNeededParity': true,
      'unchangedNonJniAarEntries': true,
      'independentReproducibility': 'not-verified',
      'officialSignatureAppliesToDerivedArtifact': false,
      'libraries': <String, Object?>{
        for (final abi in android['abis']! as List<String>)
          abi: <String, Object?>{
            'sha256': sha256.convert(utf8.encode('$abi JNI bytes')).toString(),
            'sizeBytes': utf8.encode('$abi JNI bytes').length,
            'ffiExportCount': 242,
            'ffiExportNamesSha256': sha256
                .convert(utf8.encode('the same FFI inventory'))
                .toString(),
            'dtNeeded': <String>['libc.so', 'libdl.so', 'libm.so'],
          },
      },
    };
    return _Fixture(root, recipe, file, rln, android, manifest)..write();
  }

  void write() {
    file.writeAsStringSync(jsonEncode(manifest));
    pin();
  }

  void pin() {
    android['sourceBuildManifestSha256'] = sha256
        .convert(file.readAsBytesSync())
        .toString();
  }

  AndroidSourceBuildRecord? validate(List<String> failures) =>
      validateAndroidSourceBuildRecord(
        rln: rln,
        android: android,
        failures: failures,
        repositoryRoot: root,
      );
}
