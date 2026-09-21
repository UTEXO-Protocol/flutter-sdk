import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';
import 'package:rgb_sdk_flutter/src/wallet/wallet_policy.dart';

// A closed test boundary: an unexpected method never falls through to Pigeon.
class _Host implements RlnHostApi {
  final calls = <Symbol>[];
  final signers = <int>{};
  Completer<void>? unlockGate;
  bool failUnlock = false;
  bool failInit = false;
  bool failSignerDestroy = false;

  @override
  dynamic noSuchMethod(Invocation call) {
    final method = call.memberName;
    calls.add(method);
    switch (method) {
      case #rlnCreateNode:
        return Future<int>.value(1);
      case #rlnInitNode:
        if (failInit) return Future<String>.error(StateError('init failure'));
        return Future<String>.value('test-node');
      case #rlnCreateNativeExternalSigner:
        signers.add(99);
        return Future<int>.value(99);
      case #rlnUnlockNode:
      case #rlnUnlockNodeWithNativeExternalSigner:
        if (failUnlock) return Future<void>.error(StateError('test failure'));
        return unlockGate?.future ?? Future<void>.value();
      case #rlnDestroyNativeExternalSigner:
        if (failSignerDestroy) {
          return Future<void>.error(StateError('test cleanup failure'));
        }
        signers.remove(call.positionalArguments.single as int);
        return Future<void>.value();
      case #rlnInitNodeWithNativeExternalSigner:
      case #rlnAttachNativeExternalSigner:
      case #rlnCreateUtxos:
      case #rlnShutdown:
      case #rlnDestroyNode:
        return Future<void>.value();
      default:
        throw StateError('Unexpected test host call: $method');
    }
  }
}

NativeExternalRlnSigner _signer() => NativeExternalRlnSigner(
  keys: RlnKeyMaterial.seedHex('01' * 32),
  network: 'regtest',
);

UtexoWallet _wallet(_Host host, {RlnSigner? signer}) =>
    createAdvancedUtexoWallet(
      config: UtexoWalletConfig(storageDirPath: '/test-only/not-created'),
      client: RlnClient(hostApi: host),
      signer: signer,
      operationTimeouts: const RlnOperationTimeoutPolicy(
        unlockTimeout: Duration(milliseconds: 5),
      ),
    );

void main() {
  test('init validates credentials before creating native resources', () async {
    final host = _Host();
    final wallet = _wallet(host);
    await expectLater(wallet.init(), throwsA(isA<WalletValidationException>()));
    expect(host.calls, isEmpty);
    expect(wallet.isInitialized, isFalse);
    await wallet.destroy();
  });

  test('invalid reinit config leaves the active node untouched', () async {
    final host = _Host();
    final wallet = _wallet(host);
    await wallet.init(password: 'test-only');
    await wallet.unlock(config: UtexoUnlockConfig());
    final before = List<Symbol>.of(host.calls);
    await expectLater(
      wallet.reinit(
        password: 'test-only',
        unlockConfig: UtexoUnlockConfig(bitcoindRpcHost: 'localhost'),
      ),
      throwsA(isA<WalletValidationException>()),
    );
    expect(host.calls, before);
    expect(wallet.isUnlocked, isTrue);
    await wallet.destroy();
  });

  test(
    'failed init requires fresh credentials before retry allocation',
    () async {
      final host = _Host()..failInit = true;
      final wallet = _wallet(host);
      await expectLater(wallet.init(password: 'test-only'), throwsStateError);
      final before = List<Symbol>.of(host.calls);
      host.failInit = false;
      await expectLater(
        wallet.init(),
        throwsA(isA<WalletValidationException>()),
      );
      expect(host.calls, before);
      await wallet.init(password: 'fresh-test-only');
      expect(wallet.isInitialized, isTrue);
      await wallet.destroy();
    },
  );

  test(
    'partial destroy retries only the signer that still needs cleanup',
    () async {
      final host = _Host();
      final wallet = _wallet(host, signer: _signer());
      await wallet.init();
      host.failSignerDestroy = true;
      await expectLater(wallet.destroy(), throwsA(isA<WalletException>()));
      expect(wallet.isDisposed(), isFalse);
      final before = host.calls.length;
      host.failSignerDestroy = false;
      await wallet.destroy();
      expect(host.calls.skip(before), <Symbol>[
        #rlnDestroyNativeExternalSigner,
      ]);
      expect(wallet.isDisposed(), isTrue);
      expect(host.signers, isEmpty);
    },
  );

  test('invalid deadlines never dispatch or poison the native queue', () async {
    for (final timeout in <Duration>[
      Duration.zero,
      const Duration(seconds: -1),
    ]) {
      final host = _Host();
      final binding = RLNBinding(
        client: RlnClient(hostApi: host),
        operationTimeouts: RlnOperationTimeoutPolicy(sendTimeout: timeout),
      );
      await binding.rlnCreateNode(
        IRLNNodeCreateParams(
          storageDirPath: '/test-only',
          daemonListeningPort: 1,
          ldkPeerListeningPort: 2,
          network: 'regtest',
          maxMediaUploadSizeMb: 1,
        ),
      );
      expect(
        () => binding.rlnCreateUtxos(false, 1, 1000, 1, false),
        throwsA(isA<ValidationError>()),
      );
      await Future<void>.value();
      expect(host.calls, isNot(contains(#rlnCreateUtxos)));
      await binding.rlnDestroyNode();
      expect(host.calls.last, #rlnDestroyNode);
    }
  });

  test(
    'destroy releases signer after a failed reinit removed its node',
    () async {
      final host = _Host()..failUnlock = true;
      final signer = _signer();
      final wallet = _wallet(host, signer: signer);
      await expectLater(
        wallet.reinit(unlockConfig: UtexoUnlockConfig()),
        throwsA(isA<StateError>()),
      );
      expect(host.signers, <int>{99});
      await wallet.destroy();
      expect(wallet.isDisposed(), isTrue);
      expect(signer.signerId, isNull);
      expect(host.signers, isEmpty);
    },
  );

  for (final external in <bool>[false, true]) {
    test(
      '${external ? 'external' : 'password'} signer deadline preserves cleanup ordering',
      () {
        fakeAsync((clock) {
          final host = _Host()..unlockGate = Completer<void>();
          final wallet = _wallet(host, signer: external ? _signer() : null);
          final errors = <Object>[];
          wallet.init(password: external ? null : 'test-only').catchError((
            Object error,
          ) {
            errors.add(error);
          });
          clock.flushMicrotasks();
          expect(wallet.isInitialized, isTrue);
          wallet.unlock(config: UtexoUnlockConfig()).catchError((Object error) {
            errors.add(error);
          });
          clock.flushMicrotasks();
          clock.elapse(const Duration(milliseconds: 6));
          expect(errors.single, isA<RlnOperationTimeoutException>());
          expect(wallet.isUnlocked, isFalse);
          var destroyed = false;
          wallet.destroy().then((_) {
            destroyed = true;
          });
          clock.flushMicrotasks();
          expect(destroyed, isFalse);
          expect(host.calls, isNot(contains(#rlnDestroyNode)));
          host.unlockGate!.complete();
          clock.flushMicrotasks();
          expect(destroyed, isTrue);
          expect(wallet.isDisposed(), isTrue);
          expect(host.signers, isEmpty);
        });
      },
    );
  }

  test('native diagnostics omit arbitrary native messages and payloads', () {
    final error = mapNativeBridgeException(
      PlatformException(
        code: 'InvalidRequest',
        message: 'secret-credential',
        details: <String, Object?>{'password': 'secret-credential'},
      ),
      operation: 'rlnUnlockNode',
    );
    expect(jsonEncode(error.toJson()), isNot(contains('secret-credential')));
    expect(error.toString(), isNot(contains('secret-credential')));
    expect(error.cause.toString(), isNot(contains('secret-credential')));
    final cause = error.cause! as NativeBridgeFailure;
    expect(jsonEncode(cause.details), isNot(contains('secret-credential')));
  });

  test(
    'HTTP errors never serialize malformed JSON cause or split a secret',
    () async {
      for (final malformed in <bool>[false, true]) {
        final secret = 'test-secret-' * 90;
        final client = UtexoLspClient(
          baseUrl: 'https://lsp.example',
          httpClient: MockClient(
            (_) async => http.Response(
              '${jsonEncode(<String, String>{'unrecognizedDetail': secret})}${malformed ? 'invalid' : ''}',
              malformed ? 200 : 503,
            ),
          ),
        );
        try {
          await client.getInfo();
          fail('Expected HTTP/JSON failure');
        } on LspError catch (error) {
          final diagnostic =
              '${jsonEncode(error.toJson())} $error ${error.cause}';
          expect(diagnostic, isNot(contains('test-secret-')));
        } finally {
          client.close();
        }
      }
    },
  );

  test('core error subclasses preserve SDKError catches and HTTP defaults', () {
    const errors = <RgbSdkException>[
      CryptoError('test'),
      NetworkError('test'),
      ConfigurationError('test'),
      BadRequestError('test'),
      NotFoundError('test'),
      ConflictError('test'),
      RgbNodeError('test'),
    ];
    expect(errors, everyElement(isA<SDKError>()));
    expect(errors.sublist(3, 6).map((e) => e.statusCode), <int>[400, 404, 409]);
  });

  test('out-of-range numeric representations fail without saturation', () {
    expect(
      () => RlnBalance.fromMap(<Object?, Object?>{
        'settled': 1e30,
        'future': 0,
        'spendable': 0,
      }),
      throwsA(isA<NativeProtocolException>()),
    );
    expect(
      () => WalletInputPolicy.requireIntegerFeeRate(
        9223372036854775808.0,
        'feeRate',
      ),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => WalletInputPolicy.satsToMsats(18446744073709552, 'amount'),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      WalletInputPolicy.satsToMsats(9223372036854775, 'amount'),
      9223372036854775000,
    );
  });

  test('seed lists reject wrapping bytes', () {
    for (final invalid in <int>[-1, 256, 9223372036854775807]) {
      expect(
        () => normalizeSeedInput(<int>[invalid, ...List<int>.filled(31, 1)]),
        throwsA(isA<ValidationError>()),
      );
    }
  });

  test('LNURL business failure is not parsed as malformed success', () {
    expect(
      () => LspLnurlpCallbackResponse.fromWire(<String, Object?>{
        'status': 'ERROR',
        'reason': 'hash_pool_empty',
      }),
      throwsA(
        isA<LnurlCallbackException>().having(
          (error) => error.reason,
          'reason',
          'hash_pool_empty',
        ),
      ),
    );
  });
}
