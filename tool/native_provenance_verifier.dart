import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Offline verification. Trust comes only from a separately reviewed policy;
/// artifact metadata and receipt authors cannot select their own trusted keys.
/// Supports RSA (at least 3072 bits), SHA-256 and detached signatures over exact
/// bytes. This is not a DSSE, Sigstore, GPG or SLSA level certification verifier.
final class NativeProvenanceVerifier {
  NativeProvenanceVerifier({required this.root, required this.policy});

  final Directory root;
  final Map<String, Object?> policy;

  Future<Map<String, Object?>> verify({
    required String artifactId,
    required File artifact,
    required String expectedDigest,
    required int expectedSize,
    required String sourceRepository,
    required String sourceCommit,
    required Map<String, Object?> declaration,
    required List<String> failures,
  }) async {
    final report = <String, Object?>{
      'signatureVerified': false,
      'attestationVerified': false,
      'reproductionVerified': false,
    };
    try {
      _require(
        policy['schemaVersion'] == 1,
        'Unsupported trust-policy schema.',
      );
      _require(
        artifact.existsSync() && artifact.lengthSync() == expectedSize,
        'Native archive is missing or its size differs from the baseline.',
      );
      _require(
        (await sha256.bind(artifact.openRead()).first).toString() ==
            expectedDigest,
        'Native archive digest differs from the baseline.',
      );
      final signature = _object(declaration['signature']);
      final signer = await _verifySignature(
        artifactId: artifactId,
        role: 'publisher',
        declaration: signature,
        content: artifact,
      );
      report['signatureVerified'] = true;
      report['publisherKeyId'] = signer['keyId'];

      final attestation = _object(declaration['attestation']);
      final statementFile = _file(attestation['statementPath'], 256 * 1024);
      final builder = await _verifySignature(
        artifactId: artifactId,
        role: 'builder',
        declaration: attestation,
        content: statementFile,
      );
      final statement = _object(jsonDecode(statementFile.readAsStringSync()));
      _require(
        statement['_type'] == 'https://in-toto.io/Statement/v1' &&
            statement['predicateType'] == 'https://slsa.dev/provenance/v1',
        'Unsupported signed provenance statement type.',
      );
      final subjects = statement['subject'];
      _require(
        subjects is List && subjects.length == 1,
        'Provenance must have exactly one artifact subject.',
      );
      final subject = _object((subjects as List).single);
      _require(
        subject['name'] == artifactId &&
            _object(subject['digest'])['sha256'] == expectedDigest,
        'Provenance does not bind the expected artifact and digest.',
      );
      final predicate = _object(statement['predicate']);
      final definition = _object(predicate['buildDefinition']);
      final details = _object(predicate['runDetails']);
      final builderId = _object(details['builder'])['id'];
      _require(
        builderId == builder['identity'] &&
            definition['buildType'] == builder['buildType'],
        'Builder identity or build type is not approved by the trust policy.',
      );
      final dependencies = definition['resolvedDependencies'];
      final approvedInputs = builder['requiredInputs'];
      _require(
        approvedInputs is List && approvedInputs.isNotEmpty,
        'Trust policy must pin the recipe, lockfiles and toolchain inputs.',
      );
      final requiredInputs = <Map<String, Object?>>[
        {
          'uri': sourceRepository,
          'digest': {'gitCommit': sourceCommit},
        },
        ...(approvedInputs as List).map(_object),
      ];
      _require(dependencies is List, 'Provenance build inputs are missing.');
      for (final input in requiredInputs) {
        final digest = _object(input['digest']);
        _require(
          digest.length == 1 &&
              digest.values.single is String &&
              (digest.values.single as String).isNotEmpty &&
              (dependencies as List).whereType<Map<String, Object?>>().any(
                (dependency) =>
                    dependency['uri'] == input['uri'] &&
                    dependency['digest'] is Map &&
                    (dependency['digest'] as Map).length == 1 &&
                    (dependency['digest'] as Map)[digest.keys.single] ==
                        digest.values.single,
              ),
          'Provenance is missing a pinned source or build input.',
        );
      }
      report['attestationVerified'] = true;
      report['builderIdentity'] = builderId;

      final reproduction = _object(declaration['reproducibleBuild']);
      final receiptFile = _file(reproduction['receiptPath'], 256 * 1024);
      final reproducer = await _verifySignature(
        artifactId: artifactId,
        role: 'reproducer',
        declaration: reproduction,
        content: receiptFile,
      );
      _require(
        reproducer['canonicalKeySha256'] != signer['canonicalKeySha256'] &&
            reproducer['canonicalKeySha256'] != builder['canonicalKeySha256'] &&
            reproducer['identity'] != builderId &&
            reproducer['identity'] != signer['identity'],
        'Independent reproduction must use a distinct approved identity and key.',
      );
      final receipt = _object(jsonDecode(receiptFile.readAsStringSync()));
      _require(
        receipt['schemaVersion'] == 1 &&
            receipt['type'] == 'utexo-native-reproduction' &&
            receipt['artifactId'] == artifactId &&
            receipt['artifactSha256'] == expectedDigest &&
            receipt['artifactSizeBytes'] == expectedSize &&
            receipt['sourceRepository'] == sourceRepository &&
            receipt['sourceCommit'] == sourceCommit &&
            receipt['provenanceSha256'] ==
                (await sha256.bind(statementFile.openRead()).first)
                    .toString() &&
            receipt['identity'] == reproducer['identity'] &&
            receipt['result'] == 'byte-for-byte-match' &&
            receipt['cleanBuild'] == true,
        'Reproduction receipt does not bind an independent clean matching build.',
      );
      final run = Uri.tryParse('${receipt['runUrl']}');
      _require(
        run != null &&
            run.scheme == 'https' &&
            run.host.isNotEmpty &&
            run.userInfo.isEmpty,
        'Reproduction receipt needs a reviewable HTTPS build-run URL.',
      );
      report['reproductionVerified'] = true;
      report['reproducerIdentity'] = reproducer['identity'];
    } on Object {
      // Deliberately omit untrusted receipt text, subprocess output and paths.
      failures.add(
        '$artifactId: native provenance verification failed. '
        'Supply reviewed trust roots, exact archives and valid signed evidence.',
      );
    }
    return report;
  }

  Future<Map<String, Object?>> _verifySignature({
    required String artifactId,
    required String role,
    required Map<String, Object?> declaration,
    required File content,
  }) async {
    _require(
      declaration['format'] == 'rsa-sha256-detached',
      'Unsupported signature format.',
    );
    final keyId = declaration['keyId'];
    final keys = policy['keys'];
    _require(keys is List, 'Trust policy keys are missing.');
    final matches = (keys as List)
        .map(_object)
        .where((key) => key['keyId'] == keyId)
        .toList();
    _require(matches.length == 1, 'Key identity is absent or ambiguous.');
    final key = matches.single;
    _require(
      key['role'] == role &&
          key['artifactIds'] is List &&
          (key['artifactIds'] as List).contains(artifactId) &&
          key['identity'] is String &&
          (key['identity'] as String).isNotEmpty,
      'Key is not authorized for this role and artifact.',
    );
    final publicKey = _file(key['publicKeyPath'], 64 * 1024);
    _require(
      sha256.convert(publicKey.readAsBytesSync()).toString() ==
          key['publicKeySha256'],
      'Trusted key fingerprint mismatch.',
    );
    final keyInspection = await _openssl([
      'rsa',
      '-pubin',
      '-in',
      publicKey.path,
      '-text',
      '-noout',
    ]);
    final match = RegExp(
      r'Public-Key:\s*\((\d+) bit\)',
    ).firstMatch('${keyInspection.stdout}');
    _require(
      match != null && int.parse(match.group(1)!) >= 3072,
      'RSA public key must contain at least 3072 bits.',
    );
    final signature = _file(declaration['signaturePath'], 16 * 1024);
    await _openssl([
      'dgst',
      '-sha256',
      '-verify',
      publicKey.path,
      '-signature',
      signature.path,
      content.absolute.path,
    ]);
    final canonical = await _openssl([
      'pkey',
      '-pubin',
      '-in',
      publicKey.path,
      '-pubout',
      '-outform',
      'DER',
    ], binary: true);
    return {
      ...key,
      'canonicalKeySha256': sha256
          .convert(canonical.stdout as List<int>)
          .toString(),
    };
  }

  Future<ProcessResult> _openssl(
    List<String> arguments, {
    bool binary = false,
  }) async {
    final process = await Process.start(
      'openssl',
      arguments,
      runInShell: false,
    );
    final stdoutFuture = _boundedOutput(process.stdout);
    final stderrFuture = process.stderr.drain<void>();
    try {
      final results = await Future.wait<Object?>([
        process.exitCode,
        stdoutFuture,
        stderrFuture,
      ], eagerError: true).timeout(const Duration(seconds: 30));
      final code = results[0]! as int;
      final output = results[1]! as List<int>;
      _require(code == 0, 'Cryptographic signature validation failed.');
      return ProcessResult(
        process.pid,
        code,
        binary ? output : utf8.decode(output),
        '',
      );
    } on Object {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      rethrow;
    }
  }

  Future<List<int>> _boundedOutput(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      _require(
        bytes.length + chunk.length <= 64 * 1024,
        'OpenSSL output limit.',
      );
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  File _file(Object? relativePath, int maximumBytes) {
    _require(
      relativePath is String &&
          relativePath.isNotEmpty &&
          !relativePath.startsWith('/') &&
          !relativePath.split('/').contains('..'),
      'Evidence must be a repository-relative path.',
    );
    final file = File('${root.path}/$relativePath');
    _require(
      file.existsSync() &&
          file.lengthSync() > 0 &&
          file.lengthSync() <= maximumBytes &&
          file.resolveSymbolicLinksSync().startsWith(
            '${root.resolveSymbolicLinksSync()}/',
          ),
      'Evidence is missing, oversized or outside the reviewed repository.',
    );
    return file;
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected evidence object.');
  }
  return value;
}

void _require(bool condition, String reason) {
  if (!condition) throw FormatException(reason);
}
