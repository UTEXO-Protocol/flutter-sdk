import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/native_provenance_verifier.dart';

void main() {
  late Directory root;
  late File artifact;
  late Map<String, Object?> policy;
  late Map<String, Object?> declaration;
  late Map<String, Object?> statement;
  late Map<String, Object?> receipt;
  const id = 'rln-ios-swift';
  const repository = 'https://example.test/native.git';
  final commit = 'a' * 40;

  void openssl(List<String> args) {
    final result = Process.runSync(
      'openssl',
      args,
      workingDirectory: root.path,
    );
    if (result.exitCode != 0) throw StateError('Fixture crypto failed.');
  }

  String digest(File file) => sha256.convert(file.readAsBytesSync()).toString();

  void sign(String name, String role) => openssl([
    'dgst',
    '-sha256',
    '-sign',
    '$role.private.pem',
    '-out',
    '$name.sig',
    name,
  ]);

  Future<Map<String, Object?>> verify(List<String> failures) =>
      NativeProvenanceVerifier(root: root, policy: policy).verify(
        artifactId: id,
        artifact: artifact,
        expectedDigest: sha256
            .convert(utf8.encode('native fixture'))
            .toString(),
        expectedSize: utf8.encode('native fixture').length,
        sourceRepository: repository,
        sourceCommit: commit,
        declaration: declaration,
        failures: failures,
      );

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('native-provenance-test-');
    for (final role in ['publisher', 'builder', 'reproducer']) {
      openssl([
        'genpkey',
        '-algorithm',
        'RSA',
        '-pkeyopt',
        'rsa_keygen_bits:3072',
        '-out',
        '$role.private.pem',
      ]);
      openssl([
        'pkey',
        '-in',
        '$role.private.pem',
        '-pubout',
        '-out',
        '$role.public.pem',
      ]);
    }
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  setUp(() {
    artifact = File('${root.path}/archive')
      ..writeAsStringSync('native fixture');
    sign('archive', 'publisher');
    policy = {
      'schemaVersion': 1,
      'keys': [
        for (final role in ['publisher', 'builder', 'reproducer'])
          {
            'keyId': role,
            'role': role,
            'identity': 'https://example.test/$role',
            'artifactIds': [id],
            'publicKeyPath': '$role.public.pem',
            'publicKeySha256': digest(File('${root.path}/$role.public.pem')),
            if (role == 'builder') ...{
              'buildType': 'https://example.test/build/v1',
              'requiredInputs': [
                {
                  'uri': 'https://example.test/recipe',
                  'digest': {'sha256': 'b' * 64},
                },
              ],
            },
          },
      ],
    };
    declaration = {
      'signature': {
        'format': 'rsa-sha256-detached',
        'keyId': 'publisher',
        'signaturePath': 'archive.sig',
      },
      'attestation': {
        'format': 'rsa-sha256-detached',
        'keyId': 'builder',
        'statementPath': 'statement.json',
        'signaturePath': 'statement.json.sig',
      },
      'reproducibleBuild': {
        'format': 'rsa-sha256-detached',
        'keyId': 'reproducer',
        'receiptPath': 'receipt.json',
        'signaturePath': 'receipt.json.sig',
      },
    };
    statement = {
      '_type': 'https://in-toto.io/Statement/v1',
      'predicateType': 'https://slsa.dev/provenance/v1',
      'subject': [
        {
          'name': id,
          'digest': {'sha256': digest(artifact)},
        },
      ],
      'predicate': {
        'buildDefinition': {
          'buildType': 'https://example.test/build/v1',
          'resolvedDependencies': [
            {
              'uri': repository,
              'digest': {'gitCommit': commit},
            },
            {
              'uri': 'https://example.test/recipe',
              'digest': {'sha256': 'b' * 64},
            },
          ],
        },
        'runDetails': {
          'builder': {'id': 'https://example.test/builder'},
        },
      },
    };
    File(
      '${root.path}/statement.json',
    ).writeAsStringSync(jsonEncode(statement));
    sign('statement.json', 'builder');
    receipt = {
      'schemaVersion': 1,
      'type': 'utexo-native-reproduction',
      'artifactId': id,
      'artifactSha256': digest(artifact),
      'artifactSizeBytes': artifact.lengthSync(),
      'sourceRepository': repository,
      'sourceCommit': commit,
      'provenanceSha256': digest(File('${root.path}/statement.json')),
      'identity': 'https://example.test/reproducer',
      'result': 'byte-for-byte-match',
      'cleanBuild': true,
      'runUrl': 'https://example.test/runs/1',
    };
    File('${root.path}/receipt.json').writeAsStringSync(jsonEncode(receipt));
    sign('receipt.json', 'reproducer');
  });

  test(
    'verifies real archive, signed source inputs and independent receipt',
    () async {
      final errors = <String>[];
      final result = await verify(errors);
      expect(errors, isEmpty);
      expect(result['signatureVerified'], true);
      expect(result['attestationVerified'], true);
      expect(result['reproductionVerified'], true);
    },
  );

  test('empty trust policy never accepts claimed signatures', () async {
    policy['keys'] = <Object?>[];
    final errors = <String>[];
    expect((await verify(errors))['signatureVerified'], false);
    expect(errors, hasLength(1));
  });

  for (final field in [
    'artifactSha256',
    'sourceCommit',
    'provenanceSha256',
    'cleanBuild',
    'result',
    'identity',
    'runUrl',
  ]) {
    test('rejects signed reproduction with wrong $field', () async {
      receipt[field] = field == 'cleanBuild' ? false : 'wrong';
      File('${root.path}/receipt.json').writeAsStringSync(jsonEncode(receipt));
      sign('receipt.json', 'reproducer');
      final errors = <String>[];
      final result = await verify(errors);
      expect(result['attestationVerified'], true);
      expect(result['reproductionVerified'], false);
      expect(errors, isNotEmpty);
    });
  }

  test(
    'a valid signature cannot authorize a different source commit',
    () async {
      final predicate = statement['predicate']! as Map<String, Object?>;
      final definition = predicate['buildDefinition']! as Map<String, Object?>;
      definition['resolvedDependencies'] = [
        {
          'uri': repository,
          'digest': {'gitCommit': 'c' * 40},
        },
      ];
      File(
        '${root.path}/statement.json',
      ).writeAsStringSync(jsonEncode(statement));
      sign('statement.json', 'builder');
      final errors = <String>[];
      final result = await verify(errors);
      expect(result['signatureVerified'], true);
      expect(result['attestationVerified'], false);
      expect(errors, isNotEmpty);
    },
  );

  test('unapproved recipe inputs fail despite a valid signature', () async {
    final keys = policy['keys']! as List<Map<String, Object?>>;
    keys[1]['requiredInputs'] = [
      {
        'uri': 'different recipe',
        'digest': {'sha256': 'c' * 64},
      },
    ];
    final errors = <String>[];
    expect((await verify(errors))['attestationVerified'], false);
    expect(errors, isNotEmpty);
  });

  test(
    'same builder and reproducer identity cannot claim independence',
    () async {
      final keys = policy['keys']! as List<Map<String, Object?>>;
      keys[2]['identity'] = keys[1]['identity'];
      final errors = <String>[];
      expect((await verify(errors))['reproductionVerified'], false);
      expect(errors, isNotEmpty);
    },
  );

  test('same RSA key with different PEM bytes is not independent', () async {
    final alias = File('${root.path}/builder-alias.public.pem')
      ..writeAsStringSync(
        '${File('${root.path}/builder.public.pem').readAsStringSync()}\n',
      );
    final keys = policy['keys']! as List<Map<String, Object?>>;
    keys[2]['publicKeyPath'] = 'builder-alias.public.pem';
    keys[2]['publicKeySha256'] = digest(alias);
    sign('receipt.json', 'builder');
    final errors = <String>[];
    final result = await verify(errors);
    expect(result['attestationVerified'], true);
    expect(result['reproductionVerified'], false);
    expect(errors, isNotEmpty);
  });

  test('modified archive is rejected before signature promotion', () async {
    artifact.writeAsStringSync('tampered bytes');
    final errors = <String>[];
    expect((await verify(errors))['signatureVerified'], false);
    expect(errors, isNotEmpty);
  });

  test('tampered receipt signature is rejected', () async {
    File('${root.path}/receipt.json.sig').writeAsBytesSync([1, 2, 3]);
    final errors = <String>[];
    expect((await verify(errors))['reproductionVerified'], false);
    expect(errors, isNotEmpty);
  });

  test('wrong key role cannot sign a publisher archive', () async {
    (declaration['signature']! as Map<String, Object?>)['keyId'] = 'builder';
    final errors = <String>[];
    expect((await verify(errors))['signatureVerified'], false);
    expect(errors, isNotEmpty);
  });

  test('fingerprint mismatch and escaped paths fail closed', () async {
    final keys = policy['keys']! as List<Map<String, Object?>>;
    keys[0]['publicKeySha256'] = '0' * 64;
    var errors = <String>[];
    expect((await verify(errors))['signatureVerified'], false);
    expect(errors, isNotEmpty);
    keys[0]['publicKeyPath'] = '../unreviewed.pem';
    errors = <String>[];
    expect((await verify(errors))['signatureVerified'], false);
    expect(errors, isNotEmpty);
  });
}
