import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_webrgb.dart';
import 'package:rgb_sdk_flutter/src/errors/native_bridge_error_mapper.dart';

import 'burn_operations_test.dart' show MemoryBurnStore;

final _txid = 'ab' * 32;
const _assetId = 'rgb:asset';
const _payout = BurnPayout(
  chainId: 'eip155:42161',
  address: '0x1212121212121212121212121212121212121212',
);
const _args = WebRgbBurnAssetArgs(
  network: 'regtest',
  assetId: _assetId,
  amount: '18446744073709551615',
  burnRecipient: _payout,
);
CoreAssetBalance _balance(BigInt amount) => CoreAssetBalance(
  settled: amount,
  future: amount,
  spendable: amount,
  offchainInbound: BigInt.zero,
  offchainOutbound: BigInt.zero,
);

class _Wallet implements UtexoWallet {
  bool disposed = false;
  int burns = 0;
  String proof = base64Encode(utf8.encode('abc'));
  String transferKind = 'Burn';
  int? anchor = 100;
  bool hasBfa = true;
  bool supportsBurn = true;
  bool supportsProof = true;
  BigInt amount = BigInt.from(42);
  String assignmentType = 'Fungible';
  Future<String> Function()? address;
  Future<BurnResult> Function()? burning;
  Future<String> Function(String)? readingProof;
  Object? decodeFailure;
  RgbInvoiceRequest? received;
  @override
  bool isDisposed() => disposed;
  @override
  String getNetwork() => 'regtest';
  @override
  Future<String> getAddress() async =>
      address == null ? 'bc1address' : await address!();
  @override
  Future<BfaCapabilities> getBfaCapabilities() async => BfaCapabilities(
    burn: supportsBurn,
    consignment: supportsProof,
    bfa: true,
  );
  @override
  Future<CoreListAssets> listAssets() async => CoreListAssets(
    bfa: [
      if (hasBfa)
        CoreAssetBfa(
          assetId: _assetId,
          ticker: 'USDT',
          name: 'Tether',
          precision: 6,
          timestamp: 1,
          addedAt: 2,
          balance: _balance(amount),
          initialSupply: BigInt.parse('18446744073709551615'),
        ),
    ],
    nia: const [],
    cfa: const [],
    ifa: const [],
    uda: const [],
  );
  @override
  Future<CoreAssetBalance> getAssetBalance(String assetId) async =>
      _balance(amount);
  @override
  Future<BurnResult> burn(BurnParams params) async {
    burns++;
    expect(params.amount, _args.amount);
    expect(params.burnRecipient, '${'0' * 24}${'12' * 20}');
    return burning == null
        ? BurnResult(txid: _txid, batchTransferIdx: 42)
        : await burning!();
  }

  @override
  Future<List<CoreTransfer>> listTransfers({String? assetId}) async => [
    for (final id in [_txid, 'cd' * 32])
      CoreTransfer(
        idx: 9,
        kind: transferKind,
        status: 'Settled',
        txid: id,
        assignments: [Assignment(type: 'Fungible', amount: amount)],
        requestedAssignment: Assignment(type: 'Fungible', amount: amount),
        transportEndpoints: const [],
      ),
  ];
  @override
  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async => [
    CoreTransaction(
      txid: txid,
      transactionType: 'RgbSend',
      received: 0,
      sent: 1,
      fee: 1,
      confirmationTime: anchor == null
          ? null
          : CoreBlockTime(height: anchor!, timestamp: 1),
    ),
  ];
  @override
  Future<WalletNetworkInfo> getNetworkInfo() async =>
      const WalletNetworkInfo(network: 'regtest', height: 102);
  @override
  Future<void> refreshWallet() async {}
  @override
  Future<String> getConsignment(String assetId, String txid) async =>
      readingProof == null ? proof : await readingProof!(txid);
  @override
  Future<CoreInvoiceReceiveData> blindReceive(RgbInvoiceRequest request) async {
    received = request;
    return const CoreInvoiceReceiveData(
      invoice: 'rgb:invoice',
      recipientId: 'recipient',
      expirationTimestamp: 123,
      batchTransferIdx: 4,
    );
  }

  @override
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) async {
    if (decodeFailure case final failure?) throw failure;
    return CoreInvoiceData(
      invoice: invoice,
      assetId: _assetId,
      recipientId: 'recipient',
      network: 'regtest',
      assignment: Assignment(type: assignmentType, amount: amount),
      expirationTimestamp: 123,
      transportEndpoints: const ['rpc://proxy.example'],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Matcher _error(String code) =>
    throwsA(isA<WebRgbError>().having((e) => e.code, 'code', code));

void main() {
  late _Wallet wallet;
  late MemoryBurnStore store;
  late BurnOperations operations;
  late List<WebRgbApproval> prompts;
  var approve = true;
  WebRgbProvider provider({
    bool approved = true,
    bool burn = true,
    Future<bool> Function(WebRgbApproval)? confirm,
    String origin = 'https://mint.example',
  }) => WebRgbProvider(
    wallet,
    WebRgbOptions(
      origin: origin,
      sessionApproved: approved,
      confirm:
          confirm ??
          (request) async {
            prompts.add(request);
            return approve;
          },
      burn: burn
          ? WebRgbBurnOptions(
              operations: operations,
              allowedPayoutChainIds: ['eip155:42161'],
            )
          : null,
    ),
  );
  setUp(() {
    wallet = _Wallet();
    store = MemoryBurnStore();
    operations = BurnOperations(wallet, store);
    prompts = [];
    approve = true;
  });

  test(
    'optional entrypoint advertises only supported, configured methods',
    () async {
      expect(
        (await provider(burn: false).getInfo()).methods,
        webRgbReadMethods,
      );
      expect((await provider().getInfo()).methods, [
        ...webRgbReadMethods,
        'burnAsset',
        'getConsignment',
      ]);
      wallet.supportsBurn = false;
      expect((await provider().getInfo()).methods, [
        ...webRgbReadMethods,
        'getConsignment',
      ]);
      wallet.supportsProof = false;
      expect((await provider().getInfo()).methods, webRgbReadMethods);
      await expectLater(
        provider().burnAsset(_args),
        _error('METHOD_NOT_SUPPORTED'),
      );
      expect(wallet.burns, 0);
    },
  );

  test(
    'enable approval is coalesced and revocation invalidates pending consent',
    () async {
      final approval = Completer<bool>();
      var calls = 0;
      final session = provider(
        approved: false,
        confirm: (_) {
          calls++;
          return approval.future;
        },
      );
      await expectLater(session.getAddress(), _error('NOT_ENABLED'));
      final first = session.enable();
      final second = session.enable();
      expect(calls, 1);
      final firstError = expectLater(first, _error('NOT_ENABLED'));
      final secondError = expectLater(second, _error('NOT_ENABLED'));
      session.revoke();
      approval.complete(true);
      await Future.wait([firstError, secondError]);
      expect(session.enabled, false);
    },
  );

  test(
    'revoke then re-enable cannot authorize an old in-flight response',
    () async {
      final response = Completer<String>();
      wallet.address = () => response.future;
      final session = provider();
      final pending = session.getAddress();
      final assertion = expectLater(pending, _error('NOT_ENABLED'));
      session.revoke();
      await session.enable();
      response.complete('private wallet address');
      await assertion;
      expect(session.enabled, true);
    },
  );

  test('native errors are redacted rather than exposed to a dApp', () async {
    wallet.address = () async =>
        throw StateError('secret /wallet/path password=123');
    await expectLater(
      provider().getAddress(),
      throwsA(
        isA<WebRgbError>().having(
          (e) => e.toString(),
          'redacted',
          isNot(contains('password')),
        ),
      ),
    );
  });

  test(
    'blind receive approval shows effective confirmation floor and inputs',
    () async {
      final session = provider(burn: false);
      final received = await session.blindReceive(
        const WebRgbBlindReceiveArgs(
          assetId: _assetId,
          amount: 12,
          minConfirmations: 1,
        ),
      );
      expect(wallet.received!.minConfirmations, 3);
      expect(prompts.single.params['minConfirmations'], 3);
      expect(received.toJson()['invoice'], 'rgb:invoice');
      approve = false;
      await expectLater(session.blindReceive(), _error('USER_REJECTED'));
      await expectLater(
        session.blindReceive(const WebRgbBlindReceiveArgs(amount: 0)),
        _error('INVALID_PARAMS'),
      );
    },
  );

  test(
    'balances reject JS precision loss; history preserves exact decimal amounts',
    () async {
      final session = provider();
      expect((await session.listAssets()).single.schema, 'bfa');
      expect((await session.getAssetBalance(_assetId)).balance, 42);
      wallet.amount = BigInt.parse('9007199254740992');
      await expectLater(
        session.getAssetBalance(_assetId),
        _error('INTERNAL_ERROR'),
      );
      final transfers = await session.listTransfers(_assetId);
      expect(transfers.first.amount, isNull);
      expect(transfers.first.amountBaseUnits, '9007199254740992');
      expect(transfers.first.toJson(), isNot(contains('amount')));
      expect(transfers.first.toJson(), isNot(contains('blockHeight')));
    },
  );

  test(
    'read result JSON follows the reviewed WebRGB field contracts',
    () async {
      final session = provider(burn: false);
      expect((await session.getAddress()).toJson(), {'address': 'bc1address'});
      expect((await session.getInfo()).toJson(), {
        'ready': true,
        'network': 'regtest',
        'protocol': 'RGB_LN',
        'methods': webRgbReadMethods,
      });
      expect((await session.listAssets()).single.toJson(), {
        'id': _assetId,
        'schema': 'bfa',
        'ticker': 'USDT',
        'name': 'Tether',
        'precision': 6,
      });
      expect((await session.getAssetBalance(_assetId)).toJson(), {
        'assetId': _assetId,
        'balance': 42,
        'raw': {
          'settled': 42,
          'future': 42,
          'spendable': 42,
          'offchainOutbound': 0,
          'offchainInbound': 0,
        },
      });
      final known = await session.getTransferStatus(9, _assetId);
      expect(known.toJson(), {
        'found': true,
        'status': 'Settled',
        'transfer': {
          'assetId': _assetId,
          'transferId': 9,
          'status': 'Settled',
          'kind': 'Burn',
          'amount': 42,
          'amountBaseUnits': '42',
          'txid': _txid,
        },
      });
      expect((await session.getTransferStatus('unknown')).toJson(), {
        'found': false,
        'status': null,
        'transfer': null,
      });
      await expectLater(
        session.getTransferStatus(''),
        _error('INVALID_PARAMS'),
      );
      await expectLater(
        session.getTransferStatus([]),
        _error('INVALID_PARAMS'),
      );
    },
  );

  test(
    'invoice decoder preserves seconds, endpoints and unspecified amounts',
    () async {
      final session = provider();
      expect((await session.decodeRgbInvoice('rgb:invoice')).toJson(), {
        'assetId': _assetId,
        'amount': 42,
        'recipientId': 'recipient',
        'expirationTimestamp': 123,
        'network': 'regtest',
        'transportEndpoints': ['rpc://proxy.example'],
      });
      wallet.amount = BigInt.zero;
      expect((await session.decodeRgbInvoice('rgb:invoice')).amount, isNull);
      wallet.assignmentType = 'Any';
      wallet.amount = BigInt.one;
      expect((await session.decodeRgbInvoice('rgb:invoice')).amount, isNull);
      wallet.assignmentType = 'Fungible';
      wallet.amount = BigInt.from(-1);
      await expectLater(
        session.decodeRgbInvoice('rgb:invoice'),
        _error('INTERNAL_ERROR'),
      );
      wallet.amount = BigInt.parse('9007199254740992');
      await expectLater(
        session.decodeRgbInvoice('rgb:invoice'),
        _error('INTERNAL_ERROR'),
      );
      for (final invoice in ['', 'lnbc1', 'rgb:${'a' * 16384}']) {
        await expectLater(
          session.decodeRgbInvoice(invoice),
          _error('INVALID_PARAMS'),
        );
      }
    },
  );

  test(
    'host authorization expiry after consent prevents native work',
    () async {
      var active = true;
      final session = WebRgbProvider(
        wallet,
        WebRgbOptions(
          origin: 'https://mint.example',
          sessionApproved: true,
          assertAuthorized: () {
            if (!active) throw StateError('expired');
          },
          confirm: (_) async {
            active = false;
            return true;
          },
        ),
      );
      await expectLater(session.blindReceive(), _error('NOT_ENABLED'));
      expect(wallet.received, isNull);
      await expectLater(session.enable(), _error('NOT_ENABLED'));
      final disconnected = provider(approved: false);
      approve = false;
      await expectLater(disconnected.enable(), _error('USER_REJECTED'));
      approve = true;
      await disconnected.enable();
      wallet.disposed = true;
      expect(disconnected.enabled, false);
      await expectLater(disconnected.getInfo(), _error('NOT_ENABLED'));
    },
  );

  test('session origins and chain policies reject untrusted identities', () {
    for (final origin in [
      'file:///wallet',
      'https://user:pass@mint.example',
      'https://mint.example/path',
      'https://mint.example?token=secret',
      'https://mint.example#fragment',
    ]) {
      expect(() => provider(origin: origin), throwsA(isA<WebRgbError>()));
    }
    expect(
      () => WebRgbProvider(
        wallet,
        WebRgbOptions(
          origin: 'https://mint.example',
          confirm: (_) async => true,
          burn: WebRgbBurnOptions(
            operations: operations,
            allowedPayoutChainIds: ['eip155:0'],
          ),
        ),
      ),
      throwsA(isA<WebRgbError>()),
    );
  });

  test(
    'burn preserves u64, journal ID is private, approval covers proof export',
    () async {
      final session = provider();
      final burned = await session.burnAsset(_args);
      expect(burned.amount, _args.amount);
      expect(burned.toJson().keys, isNot(contains('requestId')));
      expect(prompts.single.params['getConsignment'], true);
      final record = (await operations.records()).single;
      expect(record.state, BurnOperationState.complete);
      expect(burned.toJson().toString(), isNot(contains(record.id)));
      final proof = await session.getConsignment(
        WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid),
      );
      expect(proof.data, wallet.proof);
      expect(proof.byteLength, 3);
      // Independent published Keccak-256("abc") vector, not SHA3-256.
      expect(
        proof.digest,
        '0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45',
      );
      expect(prompts, hasLength(1));
    },
  );

  test(
    'wrong chain, network, asset and zero EVM recipient never burn',
    () async {
      final session = provider();
      for (final args in [
        const WebRgbBurnAssetArgs(
          network: 'mainnet',
          assetId: _assetId,
          amount: '1',
          burnRecipient: _payout,
        ),
        WebRgbBurnAssetArgs(
          network: 'regtest',
          assetId: _assetId,
          amount: '1',
          burnRecipient: BurnPayout(
            chainId: 'eip155:1',
            address: _payout.address,
          ),
        ),
        WebRgbBurnAssetArgs(
          network: 'regtest',
          assetId: _assetId,
          amount: '1',
          burnRecipient: BurnPayout(
            chainId: _payout.chainId,
            address: '0x${'0' * 40}',
          ),
        ),
      ]) {
        await expectLater(session.burnAsset(args), _error('INVALID_PARAMS'));
      }
      wallet.hasBfa = false;
      await expectLater(session.burnAsset(_args), _error('ASSET_NOT_FOUND'));
      expect(wallet.burns, 0);
      expect(store.data, isEmpty);
      expect(prompts, isEmpty);
    },
  );

  test(
    'native InvalidRequest becomes a sanitized WebRGB parameter error',
    () async {
      wallet.decodeFailure = mapNativeBridgeException(
        PlatformException(
          code: 'InvalidRequest',
          message: 'private invoice payload',
        ),
        operation: 'rlnDecodeRgbInvoice',
      );
      await expectLater(
        provider().decodeRgbInvoice('rgb:invalid'),
        _error('INVALID_PARAMS'),
      );
    },
  );

  test('unknown named assets fail before receive approval or mutation', () async {
    final session = provider();
    await expectLater(
      session.blindReceive(
        const WebRgbBlindReceiveArgs(assetId: 'rgb:unknown'),
      ),
      _error('ASSET_NOT_FOUND'),
    );
    await expectLater(
      session.getAssetBalance('rgb:unknown'),
      _error('ASSET_NOT_FOUND'),
    );
    expect(prompts, isEmpty);
    expect(wallet.received, isNull);
    // The no-asset invoice remains the supported way to receive a new contract.
    await session.blindReceive();
    expect(wallet.received!.assetId, isNull);
  });

  test('another wallet cannot reuse a burn journal', () {
    final other = _Wallet();
    expect(
      () => WebRgbProvider(
        other,
        WebRgbOptions(
          origin: 'https://mint.example',
          confirm: (_) async => true,
          burn: WebRgbBurnOptions(
            operations: operations,
            allowedPayoutChainIds: [_payout.chainId],
          ),
        ),
      ),
      throwsA(isA<WebRgbError>()),
    );
  });

  for (final phase in [
    BurnOperationState.prepared,
    BurnOperationState.pending,
  ]) {
    test('revoke during $phase cancels durably before native burn', () async {
      final session = provider();
      store.afterWrite = (record) async {
        if (record.state == phase) session.revoke();
      };
      await expectLater(session.burnAsset(_args), _error('NOT_ENABLED'));
      expect(wallet.burns, 0);
      expect(
        (await operations.records()).single.state,
        BurnOperationState.cancelled,
      );
    });
  }

  test(
    'revoke during dispatched burn preserves result but withholds response',
    () async {
      final session = provider();
      wallet.burning = () async {
        session.revoke();
        return BurnResult(txid: _txid, batchTransferIdx: 42);
      };
      await expectLater(session.burnAsset(_args), _error('NOT_ENABLED'));
      expect(wallet.burns, 1);
      expect(
        (await operations.records()).single.state,
        BurnOperationState.complete,
      );
    },
  );

  test(
    'new sessions require proof consent, even after a same-origin burn',
    () async {
      await provider().burnAsset(_args);
      approve = false;
      await expectLater(
        provider().getConsignment(
          WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid),
        ),
        _error('USER_REJECTED'),
      );
      expect(prompts.last.method, 'getConsignment');
    },
  );

  test('proof export rejects non-burn, malformed and oversized data', () async {
    final session = provider();
    final args = WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid);
    wallet.transferKind = 'Send';
    await expectLater(session.getConsignment(args), _error('INVALID_PARAMS'));
    wallet.transferKind = 'Burn';
    for (final value in [
      '',
      '%AA',
      'YWJj\n',
      'A' * (((16 * 1024 * 1024 + 2) ~/ 3) * 4 + 1),
    ]) {
      wallet.proof = value;
      await expectLater(session.getConsignment(args), _error('INTERNAL_ERROR'));
    }
  });

  test('concurrent proof requests retain their own data and digests', () async {
    final session = provider();
    wallet.readingProof = (txid) async => txid == _txid ? 'YWJj' : 'BwgJ';
    final results = await Future.wait([
      session.getConsignment(
        WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid),
      ),
      session.getConsignment(
        WebRgbGetConsignmentArgs(assetId: _assetId, txid: 'cd' * 32),
      ),
    ]);
    expect(results.map((result) => result.data), ['YWJj', 'BwgJ']);
    expect(results.first.digest, isNot(results.last.digest));
  });

  test(
    'burn status uses anchor height and responds to reorg without burning',
    () async {
      final session = provider();
      await session.burnAsset(_args);
      final status = await session.getTransferStatus(_txid);
      expect(status.transfer!.confirmations, 3);
      expect(status.transfer!.amount, isNull);
      expect(status.transfer!.amountBaseUnits, _args.amount);
      wallet.anchor = null;
      expect(
        (await session.getTransferStatus(_txid)).transfer!.confirmations,
        0,
      );
      final other = await provider(
        origin: 'https://other.example',
      ).getTransferStatus(_txid);
      expect(other.transfer!.burnRecipient, isNull);
      expect(wallet.burns, 1);
    },
  );
}
