import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

const _runRegtest = bool.fromEnvironment('RGB_SDK_FLUTTER_REGTEST');
const _runFundedRegtest = bool.fromEnvironment(
  'RGB_SDK_FLUTTER_FUNDED_REGTEST',
);
const _bitcoindRpcPort = int.fromEnvironment(
  'RGB_SDK_FLUTTER_BITCOIND_RPC_PORT',
  defaultValue: 18444,
);
const _electrsPort = int.fromEnvironment(
  'RGB_SDK_FLUTTER_ELECTRS_PORT',
  defaultValue: 50002,
);
const _rgbProxyPort = int.fromEnvironment(
  'RGB_SDK_FLUTTER_RGB_PROXY_PORT',
  defaultValue: 3003,
);
const _password = 'password';

String get _host => Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nativeArtifactInfo test', (WidgetTester tester) async {
    const plugin = RgbSdkFlutter();
    final info = await plugin.nativeArtifactInfo();

    expect(info.rlnVersion, RgbSdkFlutter.rlnVersion);
    expect(
      info.reactNativeParityVersion,
      RgbSdkFlutter.reactNativeParityVersion,
    );
    expect(info.nativeArtifact.isNotEmpty, true);
  });

  testWidgets('regtest lifecycle and bitcoin read smoke', (
    WidgetTester tester,
  ) async {
    if (!_runRegtest) {
      markTestSkipped('Set --dart-define=RGB_SDK_FLUTTER_REGTEST=true to run.');
      return;
    }

    final client = const RgbSdkFlutter().rlnClient();
    final storageDir = await Directory.systemTemp.createTemp(
      'rgb-sdk-flutter-regtest-',
    );
    final nodeId = await client.createNode(
      storageDirPath: storageDir.path,
      daemonListeningPort: 34011,
      ldkPeerListeningPort: 34012,
      network: 'regtest',
      maxMediaUploadSizeMb: 5,
    );

    try {
      final pubkey = await client.initNode(nodeId: nodeId, password: _password);
      expect(pubkey, isNotEmpty);

      await client.unlockNode(
        nodeId: nodeId,
        password: _password,
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: _host,
        bitcoindRpcPort: _bitcoindRpcPort,
        indexerUrl: '$_host:$_electrsPort',
        proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
      );

      await client.sync(nodeId);

      final network = await client.networkInfo(nodeId);
      expect(network['network'].toString().toLowerCase(), contains('regtest'));
      expect(network['height'], greaterThanOrEqualTo(103));

      final nodeInfo = await client.nodeInfo(nodeId);
      expect(nodeInfo['pubkey'], isNotEmpty);
      expect(nodeInfo['accountXpubVanilla'], isNotEmpty);
      expect(nodeInfo['accountXpubColored'], isNotEmpty);

      final address = await client.address(nodeId);
      expect(address['address'], startsWith('bcrt'));

      final balance = await client.btcBalance(nodeId: nodeId, skipSync: true);
      expect(balance['vanilla'], isA<Map<Object?, Object?>>());
      expect(balance['colored'], isA<Map<Object?, Object?>>());

      final peers = await client.listPeers(nodeId);
      final channels = await client.listChannels(nodeId);
      final payments = await client.listPayments(nodeId);
      expect(peers, isEmpty);
      expect(channels, isEmpty);
      expect(payments, isEmpty);

      final indexer = await client.checkIndexerUrl(
        nodeId: nodeId,
        indexerUrl: '$_host:$_electrsPort',
      );
      expect(indexer['indexerProtocol'], isNotEmpty);

      await client.checkProxyEndpoint(
        nodeId: nodeId,
        proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
      );

      final assets = await client.listAssets(nodeId: nodeId);
      expect(assets['nia'], isA<List<Object?>>());
      expect(assets['uda'], isA<List<Object?>>());
      expect(assets['cfa'], isA<List<Object?>>());
      expect(assets['ifa'], isA<List<Object?>>());

      await client.refreshTransfers(nodeId: nodeId, skipSync: true);

      final failed = await client.failTransfers(
        nodeId: nodeId,
        batchTransferIdx: null,
        noAssetOnly: true,
        skipSync: true,
      );
      expect(failed['transfersChanged'], isA<bool>());
    } finally {
      await client.shutdown(nodeId).catchError((_) {});
      await client.destroyNode(nodeId).catchError((_) {});
      try {
        await storageDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('regtest UtexoWallet facade smoke', (WidgetTester tester) async {
    if (!_runRegtest) {
      markTestSkipped('Set --dart-define=RGB_SDK_FLUTTER_REGTEST=true to run.');
      return;
    }

    final storageDir = await Directory.systemTemp.createTemp(
      'rgb-sdk-flutter-wallet-regtest-',
    );
    final wallet = UtexoWallet(
      config: UtexoWalletConfig(
        storageDirPath: storageDir.path,
        daemonListeningPort: 34021,
        ldkPeerListeningPort: 34022,
        network: 'regtest',
        maxMediaUploadSizeMb: 5,
      ),
    );

    try {
      await wallet.init(password: _password);
      expect(wallet.isInitialized, true);

      await wallet.unlock(
        password: _password,
        config: UtexoUnlockConfig(
          bitcoindRpcUsername: 'user',
          bitcoindRpcPassword: 'password',
          bitcoindRpcHost: _host,
          bitcoindRpcPort: _bitcoindRpcPort,
          indexerUrl: '$_host:$_electrsPort',
          proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
        ),
      );
      expect(wallet.isUnlocked, true);

      await wallet.syncWallet();
      expect(await wallet.getAddress(), startsWith('bcrt'));

      final balance = await wallet.getBtcBalance(skipSync: true);
      expect(balance.vanilla.settled, greaterThanOrEqualTo(0));
      expect(balance.colored.settled, greaterThanOrEqualTo(0));

      final assets = await wallet.listAssets();
      expect(assets.nia, isEmpty);
      expect(assets.uda, isEmpty);
      expect(assets.cfa, isEmpty);
      expect(assets.ifa, isEmpty);

      await wallet.refreshWallet(skipSync: true);
      expect(
        await wallet.failTransfers(noAssetOnly: true, skipSync: true),
        isA<bool>(),
      );

      await wallet.shutdown();
      expect(wallet.isUnlocked, false);

      await wallet.reinit(
        unlockConfig: UtexoUnlockConfig(
          bitcoindRpcUsername: 'user',
          bitcoindRpcPassword: 'password',
          bitcoindRpcHost: _host,
          bitcoindRpcPort: _bitcoindRpcPort,
          indexerUrl: '$_host:$_electrsPort',
          proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
        ),
      );
      expect(wallet.isInitialized, true);
      expect(wallet.isUnlocked, true);
      await wallet.syncWallet();
      expect(await wallet.getAddress(), startsWith('bcrt'));
    } finally {
      await wallet.destroy().catchError((_) {});
      try {
        await storageDir.delete(recursive: true);
      } catch (_) {}
    }
  });
  testWidgets('funded regtest RGB send smoke', (WidgetTester tester) async {
    if (!_runFundedRegtest) {
      markTestSkipped(
        'Run tool/regtest/flutter_funded_smoke.sh to enable host funding.',
      );
      return;
    }

    final walletA = await _makeRegtestWallet('a', 34031, 34032);
    final walletB = await _makeRegtestWallet('b', 34033, 34034);

    try {
      await _startWallet(walletA);
      await _startWallet(walletB);

      _requestFunding(await walletA.getAddress(), '0.03');
      _requestFunding(await walletB.getAddress(), '0.02');
      await _waitForSpendable(walletA, 1, label: 'wallet A');
      await _waitForSpendable(walletB, 1, label: 'wallet B');

      await walletA.createUtxos(num: 10, size: 100000, feeRate: 1);
      await walletB.createUtxos(num: 10, size: 100000, feeRate: 1);
      await _mineAndWait(walletA, blocks: 1);
      await walletB.syncWallet();

      final issued = await walletA.issueAssetNia(
        ticker: 'TST',
        name: 'Test Asset',
        precision: 0,
        amounts: const <int>[1000],
      );
      expect(issued.assetId, isNotEmpty);

      final invoice = await walletB.blindReceive(const RgbInvoiceRequest());
      final send = await walletA.send(
        RgbSendRequest(
          invoice: invoice.invoice,
          assetId: issued.assetId,
          amount: 100,
          donation: true,
          skipSync: false,
        ),
      );
      expect(send.txid, isNotEmpty);

      await _mineAndWait(walletA, blocks: 1);
      await _waitForAssetSpendable(
        walletB,
        issued.assetId,
        100,
        label: 'wallet B',
      );
      final walletBTransfers = await walletB.listTransfers();
      expect(walletBTransfers, isNotEmpty);
      expect(
        walletBTransfers.any(
          (transfer) => transfer.assignments.any(
            (assignment) => assignment.contains('100'),
          ),
        ),
        true,
      );
      await _waitForAssetSpendable(
        walletA,
        issued.assetId,
        900,
        label: 'wallet A',
      );

      final walletABalance = await walletA.getAssetBalance(issued.assetId);
      expect(walletABalance.spendable, lessThanOrEqualTo(900));

      final walletAInfo = await walletA.nodeInfo();
      final walletBInfo = await walletB.nodeInfo();
      final walletAPeer = '${walletAInfo.pubkey}@127.0.0.1:34033';
      final walletBPeer = '${walletBInfo.pubkey}@127.0.0.1:34034';
      await walletA.connectPeer(walletBPeer);
      await _waitForPeer(walletA, walletBInfo.pubkey);
      await walletB.connectPeer(walletAPeer);
      await _waitForPeer(walletB, walletAInfo.pubkey);

      final opened = await walletA.openChannel(
        peerPubkeyAndOptAddr: walletBPeer,
        capacitySat: 500000,
        pushMsat: 0,
        publicChannel: false,
        withAnchors: true,
        assetId: issued.assetId,
        assetAmount: 200,
      );
      expect(opened.temporaryChannelId, isNotEmpty);

      await _mineAndWait(walletA, blocks: 6);
      await _waitForUsableChannelPair(walletA, walletB, issued.assetId);

      final lnInvoice = await walletB.createLightningInvoice(
        amtMsat: 3000000,
        assetId: issued.assetId,
        assetAmount: 50,
      );
      expect(lnInvoice.invoice, isNotEmpty);

      final payment = await walletA.payLightningInvoice(
        invoice: lnInvoice.invoice,
      );
      expect(payment.status, isNotEmpty);

      await _waitForInvoiceFinal(walletB, lnInvoice.invoice);
    } finally {
      await walletA.destroy().catchError((_) {});
      await walletB.destroy().catchError((_) {});
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}

Future<UtexoWallet> _makeRegtestWallet(
  String label,
  int daemonPort,
  int peerPort,
) async {
  final storageDir = await Directory.systemTemp.createTemp(
    'rgb-sdk-flutter-funded-$label-',
  );
  return UtexoWallet(
    config: UtexoWalletConfig(
      storageDirPath: storageDir.path,
      daemonListeningPort: daemonPort,
      ldkPeerListeningPort: peerPort,
      network: 'regtest',
      maxMediaUploadSizeMb: 5,
    ),
  );
}

Future<void> _startWallet(UtexoWallet wallet) async {
  await wallet.init(password: _password);
  await wallet.unlock(
    password: _password,
    config: UtexoUnlockConfig(
      bitcoindRpcUsername: 'user',
      bitcoindRpcPassword: 'password',
      bitcoindRpcHost: _host,
      bitcoindRpcPort: _bitcoindRpcPort,
      indexerUrl: '$_host:$_electrsPort',
      proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
    ),
  );
  await wallet.syncWallet();
}

void _requestFunding(String address, String amountBtc) {
  debugPrintSynchronously(
    'RGB_SDK_FLUTTER_HOST FUND address=$address amount=$amountBtc',
  );
}

void _requestMine(int blocks) {
  debugPrintSynchronously('RGB_SDK_FLUTTER_HOST MINE blocks=$blocks');
}

Future<void> _mineAndWait(UtexoWallet wallet, {required int blocks}) async {
  final startHeight = (await wallet.networkInfo()).height;
  _requestMine(blocks);
  await _waitForHeight(wallet, startHeight + blocks);
}

Future<void> _waitForHeight(UtexoWallet wallet, int targetHeight) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await wallet.syncWallet();
    final height = (await wallet.networkInfo()).height;
    if (height >= targetHeight) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Regtest height did not reach $targetHeight.');
}

Future<void> _waitForSpendable(
  UtexoWallet wallet,
  int minSat, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await wallet.syncWallet();
    final balance = await wallet.getBtcBalance();
    if (balance.vanilla.spendable >= minSat) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label did not reach $minSat spendable sats.');
}

Future<void> _waitForAssetSpendable(
  UtexoWallet wallet,
  String assetId,
  int minAmount, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 90; attempt++) {
    await wallet.refreshWallet();
    final balance = await wallet.getAssetBalance(assetId);
    if (balance.spendable >= minAmount) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label did not reach $minAmount spendable units for $assetId.');
}

Future<void> _waitForPeer(UtexoWallet wallet, String pubkey) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    final peers = await wallet.listPeers();
    if (peers.any((peer) => peer.pubkey == pubkey)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Peer $pubkey did not connect.');
}

Future<void> _waitForUsableChannelPair(
  UtexoWallet walletA,
  UtexoWallet walletB,
  String assetId,
) async {
  var lastA = const <RlnChannel>[];
  var lastB = const <RlnChannel>[];
  for (var attempt = 0; attempt < 90; attempt++) {
    await walletA.syncWallet();
    await walletB.syncWallet();
    lastA = await walletA.listChannels();
    lastB = await walletB.listChannels();
    if (_hasUsableRgbChannel(lastA, assetId) &&
        _hasUsableRgbChannel(lastB, assetId)) {
      return;
    }
    if (attempt % 5 == 4) {
      await _mineAndWait(walletA, blocks: 1);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail(
    'Wallets did not reach a usable RGB channel for $assetId. '
    'walletA=${_channelSummary(lastA)} walletB=${_channelSummary(lastB)}',
  );
}

bool _hasUsableRgbChannel(List<RlnChannel> channels, String assetId) {
  return channels.any(
    (channel) =>
        channel.assetId == assetId && (channel.ready || channel.isUsable),
  );
}

String _channelSummary(List<RlnChannel> channels) {
  return channels
      .map(
        (channel) =>
            '{id=${channel.channelId}, status=${channel.status}, '
            'ready=${channel.ready}, usable=${channel.isUsable}, '
            'asset=${channel.assetId}, funding=${channel.fundingTxid}}',
      )
      .join(', ');
}

Future<void> _waitForInvoiceFinal(UtexoWallet wallet, String invoice) async {
  for (var attempt = 0; attempt < 90; attempt++) {
    final status = (await wallet.invoiceStatus(invoice)).status.toLowerCase();
    if (status == 'succeeded') return;
    if (status == 'failed' || status == 'expired' || status == 'cancelled') {
      fail('Invoice reached terminal failure state: $status.');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail('Invoice did not reach succeeded state.');
}
