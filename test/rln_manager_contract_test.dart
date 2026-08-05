import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

class _Call {
  const _Call(this.method, this.args);

  final String method;
  final List<Object?> args;
}

class _BindingHostApi extends RlnHostApi {
  final calls = <_Call>[];
  bool throwConflictOnUnlock = false;
  int nodeInfoFailuresRemaining = 0;

  void _record(String method, List<Object?> args) {
    calls.add(_Call(method, args));
  }

  RlnWireResponse _wireMap(Map<Object?, Object?> map) {
    return RlnWireResponse(json: jsonEncode(map));
  }

  @override
  Future<int> rlnCreateNode(
    String storageDirPath,
    int daemonListeningPort,
    int ldkPeerListeningPort,
    String network,
    int maxMediaUploadSizeMb,
    bool? enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    String? vssUrl,
    bool vssAllowHttp,
    bool vssAllowEmptyRestore,
    String? lspBaseUrl,
    String? lspBearerToken,
    bool reuseAddresses,
  ) async {
    _record('rlnCreateNode', <Object?>[
      storageDirPath,
      daemonListeningPort,
      ldkPeerListeningPort,
      network,
      maxMediaUploadSizeMb,
      enableVirtualChannelsV0,
      virtualPeerPubkeys,
      vssUrl,
      vssAllowHttp,
      vssAllowEmptyRestore,
      lspBaseUrl,
      lspBearerToken,
      reuseAddresses,
    ]);
    return 42;
  }

  @override
  Future<String> rlnInitNode(
    int nodeId,
    String password,
    String? mnemonic,
  ) async {
    _record('rlnInitNode', <Object?>[nodeId, password, mnemonic]);
    return 'node-pubkey';
  }

  @override
  Future<void> rlnUnlockNode(
    int nodeId,
    String password,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
  ) async {
    _record('rlnUnlockNode', <Object?>[
      nodeId,
      password,
      bitcoindRpcUsername,
      bitcoindRpcPassword,
      bitcoindRpcHost,
      bitcoindRpcPort,
      indexerUrl,
      proxyEndpoint,
      announceAddresses,
      announceAlias,
      gossipRgsServerUrl,
    ]);
    if (throwConflictOnUnlock) {
      throw Exception('already in use');
    }
  }

  @override
  Future<RlnWireResponse> rlnNodeInfo(int nodeId) async {
    _record('rlnNodeInfo', <Object?>[nodeId]);
    if (nodeInfoFailuresRemaining > 0) {
      nodeInfoFailuresRemaining -= 1;
      throw Exception('node not ready');
    }
    return _wireMap(<Object?, Object?>{
      'pubkey': 'node-pubkey',
      'numChannels': 0,
      'numUsableChannels': 0,
      'localBalanceSat': 0,
      'eventualCloseFeesSat': 0,
      'pendingOutboundPaymentsSat': 0,
      'numPeers': 0,
      'maxMediaUploadSizeMb': 20,
      'rgbHtlcMinMsat': 0,
      'rgbChannelCapacityMinSat': 0,
      'channelCapacityMinSat': 0,
      'channelCapacityMaxSat': 0,
      'channelAssetMinAmount': 0,
      'channelAssetMaxAmount': 0,
      'networkNodes': 0,
      'networkChannels': 0,
    });
  }

  @override
  Future<int> rlnCreateNativeExternalSigner(
    String seedHex,
    String network,
    bool permissivePolicy,
    String? storageDirPath,
  ) async {
    _record('rlnCreateNativeExternalSigner', <Object?>[
      seedHex,
      network,
      permissivePolicy,
      storageDirPath,
    ]);
    return 7;
  }

  @override
  Future<void> rlnCreateUtxos(
    int nodeId,
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) async {
    _record('rlnCreateUtxos', <Object?>[
      nodeId,
      upTo,
      num,
      size,
      feeRate,
      skipSync,
    ]);
  }

  @override
  Future<void> rlnShutdown(int nodeId) async {
    _record('rlnShutdown', <Object?>[nodeId]);
  }

  @override
  Future<void> rlnDestroyNode(int nodeId) async {
    _record('rlnDestroyNode', <Object?>[nodeId]);
  }
}

void main() {
  test('RLNBinding owns node id and delegates RN-style methods', () async {
    final hostApi = _BindingHostApi();
    final binding = RLNBinding(client: RlnClient(hostApi: hostApi));

    final nodeId = await binding.rlnCreateNode(
      const IRLNNodeCreateParams(
        storageDirPath: '/tmp/rgb-node',
        daemonListeningPort: 9735,
        ldkPeerListeningPort: 9736,
        network: 'regtest',
        maxMediaUploadSizeMb: 20,
      ),
    );
    final pubkey = await binding.rlnInitNode('password', 'mnemonic');
    await binding.rlnCreateUtxos(true, 2, null, 1.5, false);

    expect(nodeId, 42);
    expect(pubkey, 'node-pubkey');
    expect(hostApi.calls.map((call) => call.method), <String>[
      'rlnCreateNode',
      'rlnInitNode',
      'rlnCreateUtxos',
    ]);
    expect(hostApi.calls[1].args, <Object?>[42, 'password', 'mnemonic']);
    expect(hostApi.calls[2].args, <Object?>[42, true, 2, null, 1.5, false]);
    expect(
      () => binding.rlnCreateNode(
        const IRLNNodeCreateParams(
          storageDirPath: '/tmp/another',
          daemonListeningPort: 9735,
          ldkPeerListeningPort: 9736,
          network: 'regtest',
          maxMediaUploadSizeMb: 20,
        ),
      ),
      throwsA(isA<WalletError>()),
    );
  });

  test('RLNManager exports RN-style defaults and lifecycle helpers', () async {
    final hostApi = _BindingHostApi();
    final manager = RLNManager(
      binding: RLNBinding(client: RlnClient(hostApi: hostApi)),
    );

    await manager.rlnCreateNode(
      const IRLNNodeCreateParams(
        storageDirPath: '/tmp/rgb-node',
        daemonListeningPort: 9735,
        ldkPeerListeningPort: 9736,
        network: 'regtest',
        maxMediaUploadSizeMb: 20,
      ),
    );
    final signerId = await manager.rlnCreateNativeExternalSigner(
      '00' * 32,
      'regtest',
      storageDirPath: '/tmp/rgb-node',
    );
    await manager.rlnShutdown();
    await manager.rlnDestroyNode();
    await manager.rlnDestroyNode();

    expect(signerId, 7);
    expect(
      hostApi.calls
          .where((call) => call.method == 'rlnCreateNativeExternalSigner')
          .single
          .args,
      <Object?>['00' * 32, 'regtest', true, '/tmp/rgb-node'],
    );
    expect(hostApi.calls.map((call) => call.method), contains('rlnShutdown'));
    expect(
      hostApi.calls.where((call) => call.method == 'rlnDestroyNode').length,
      1,
    );
  });

  test(
    'consumeRlnUnlockConflictNormalized mirrors RN one-shot behavior',
    () async {
      final hostApi = _BindingHostApi()
        ..throwConflictOnUnlock = true
        ..nodeInfoFailuresRemaining = 1;
      final binding = RLNBinding(client: RlnClient(hostApi: hostApi));
      await binding.rlnCreateNode(
        const IRLNNodeCreateParams(
          storageDirPath: '/tmp/rgb-node',
          daemonListeningPort: 9735,
          ldkPeerListeningPort: 9736,
          network: 'regtest',
          maxMediaUploadSizeMb: 20,
        ),
      );

      await binding.rlnUnlockNode(
        password: 'password',
        params: const IRLNUnlockParams(indexerUrl: '127.0.0.1:50002'),
      );

      expect(binding.consumeRlnUnlockConflictNormalized(), true);
      expect(binding.consumeRlnUnlockConflictNormalized(), false);
    },
  );

  test('createRLNManager and RNSigner are exported compatibility APIs', () async {
    const seedHex =
        '000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f';
    final keys = await deriveKeysFromSeed('regtest', seedHex);
    final signer = RNSigner();

    final signature = await signer.signMessage(
      message: 'hello',
      seed: seedHex,
      network: 'regtest',
    );
    final verified = await signer.verifyMessage(
      message: 'hello',
      signature: signature,
      accountXpub: keys.accountXpubVanilla,
      network: 'regtest',
    );

    expect(createRLNManager(), isA<RLNManager>());
    expect(verified, true);
    expect(
      () => signer.signPsbtWithMnemonic('mnemonic', 'psbt'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
    expect(
      () => signer.estimateFee('psbt'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
  });
}
