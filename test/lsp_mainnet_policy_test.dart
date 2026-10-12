import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

class _Wallet extends Fake implements ILspWallet {
  @override
  String network = 'regtest';
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unexpected wallet operation: ${invocation.memberName}');
  }
}

class _Http extends Fake implements IUtexoLspClient {
  int calls = 0;
  int closes = 0;
  Future<LspGetInfoResponse> Function()? onInfo;

  @override
  Future<LspGetInfoResponse> getInfo() async {
    calls++;
    if (onInfo case final read?) return read();
    throw StateError('Unexpected HTTP getInfo');
  }

  @override
  void close() => closes++;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unexpected HTTP operation: ${invocation.memberName}');
  }
}

class _UnusedInfo extends Fake implements LspGetInfoResponse {}

final _denied = throwsA(
  isA<WalletError>().having(
    (error) => error.code,
    'code',
    'LIGHTNING_DISABLED_ON_MAINNET',
  ),
);
const _peer = LspPeer(
  baseUrl: 'https://lsp.example',
  peerPubkey: 'peer',
  peerHost: 'lsp.example',
  peerPort: 9735,
);

Map<String, Future<Object?> Function()> _operations(UtexoLsp lsp) => {
  'connect': lsp.connect,
  'waitForChannel': () => lsp.waitForChannel('rgb:asset'),
  'awaitReceiveSettlement': () => lsp.awaitReceiveSettlement('invoice'),
  'waitForOutboundLiquidity': () => lsp.waitForOutboundLiquidity(1),
  'receiveAsset': () => lsp.receiveAsset(
    const ReceiveAssetOptions(
      assetId: 'rgb:asset',
      amountSats: 1,
      amountRgb: 1,
    ),
  ),
  'sendAsset': () =>
      lsp.sendAsset(const SendAssetOptions(rgbInvoice: 'invoice')),
  'payAddress': () => lsp.payAddress(
    const PayAddressOptions(address: 'a@example.com', amtMsat: 1),
  ),
  'quoteAddress': () => lsp.quoteAddress(
    const PayAddressOptions(address: 'a@example.com', amtMsat: 1),
  ),
  'discoverAddress': () => lsp.discoverAddress('a@example.com'),
  'listPayableAssets': lsp.listPayableAssets,
  'selectPaymentAsset': () => lsp.selectPaymentAsset(
    const SelectPaymentAssetOptions(address: 'a@example.com', assetAmount: 1),
  ),
  'enableLightningAddress': lsp.enableLightningAddress,
  'requestExternalInvoice': () => lsp.requestExternalInvoice(
    const RequestExternalInvoiceOptions(amtMsat: 1, assetAmount: 1),
  ),
  'quoteExternalPayment': () => lsp.quoteExternalPayment(
    const PayExternalInvoiceOptions(invoice: 'invoice'),
  ),
  'payExternalInvoice': () => lsp.payExternalInvoice(
    const PayExternalInvoiceOptions(invoice: 'invoice'),
  ),
  'externalPaymentStatus': () => lsp.externalPaymentStatus('hash'),
  'refillHashPool': lsp.refillHashPool,
  'claimPendingPayments': lsp.claimPendingPayments,
};

void main() {
  test(
    'mainnet change during discovery stops before APay registration',
    () async {
      final wallet = _Wallet();
      final http = _Http()
        ..onInfo = () async {
          wallet.network = 'mainnet';
          return _UnusedInfo();
        };
      final lsp = UtexoLsp(wallet: wallet, peer: _peer, httpClient: http);
      await expectLater(lsp.enableLightningAddress(), _denied);
      expect(http.calls, 1);
      expect(wallet.calls, 0);
      lsp.dispose();
    },
  );
  test(
    'constructor denies mainnet before transport allocation or validation',
    () {
      for (final network in ['mainnet', ' MAINNET ', 'bitcoin', '0']) {
        final wallet = _Wallet()..network = network;
        final http = _Http();
        expect(
          () => UtexoLsp(wallet: wallet, peer: _peer, httpClient: http),
          _denied,
        );
        expect(
          () => UtexoLsp(
            wallet: wallet,
            peer: const LspPeer(
              baseUrl: 'invalid',
              peerPubkey: 'peer',
              peerHost: 'invalid',
              peerPort: 9735,
            ),
          ),
          _denied,
        );
        expect(wallet.calls, 0);
        expect(http.calls, 0);
        expect(http.closes, 0);
      }
    },
  );

  test(
    'every orchestration method rechecks mainnet before any side effect',
    () async {
      final wallet = _Wallet();
      final http = _Http();
      final lsp = UtexoLsp(wallet: wallet, peer: _peer, httpClient: http);
      final operations = _operations(lsp);
      final matrix =
          jsonDecode(
                File('tool/test_matrix/lsp_methods.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final methods = (matrix['methods']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        operations.keys.toSet(),
        methods
            .map((row) => row['id'])
            .where((id) => id != 'close' && id != 'dispose')
            .toSet(),
      );
      wallet.network = 'mainnet';
      for (final operation in operations.entries) {
        await expectLater(operation.value(), _denied, reason: operation.key);
      }
      expect(wallet.calls, 0);
      expect(http.calls, 0);
      lsp.close();
      expect(http.closes, 1);
    },
  );

  test(
    'network change during a polling hook stops before wallet sync',
    () async {
      for (final method in ['channel', 'settlement', 'liquidity']) {
        final wallet = _Wallet();
        final http = _Http();
        final lsp = UtexoLsp(wallet: wallet, peer: _peer, httpClient: http);
        final options = WaitOptions(
          onEachPoll: () async {
            wallet.network = 'mainnet';
          },
        );
        final future = switch (method) {
          'channel' => lsp.waitForChannel('rgb:asset', options: options),
          'settlement' => lsp.awaitReceiveSettlement(
            'invoice',
            options: options,
          ),
          _ => lsp.waitForOutboundLiquidity(1, options: options),
        };
        await expectLater(future, _denied);
        expect(wallet.calls, 0);
        expect(http.calls, 0);
        lsp.dispose();
      }
    },
  );

  test('non-mainnet constructors remain usable', () {
    for (final network in ['regtest', 'signet', 'utexo', 'testnet']) {
      final wallet = _Wallet()..network = network;
      final http = _Http();
      UtexoLsp(wallet: wallet, peer: _peer, httpClient: http).dispose();
      expect(http.closes, 1);
      expect(http.calls, 0);
      expect(wallet.calls, 0);
    }
  });
}
