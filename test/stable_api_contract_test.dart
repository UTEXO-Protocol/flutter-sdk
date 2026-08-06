import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  test(
    'custom signer contract is implementable from the stable package',
    () async {
      final signer = _CustomSigner();
      final host = _RecordingSignerHost();

      await signer.initNode(
        host: host,
        nodeId: 7,
        storageDirPath: '/tmp/stable-signer',
      );
      await signer.unlockNode(
        host: host,
        nodeId: 7,
        config: UtexoUnlockConfig(indexerUrl: 'ssl://indexer.example:50002'),
        storageDirPath: '/tmp/stable-signer',
      );
      await signer.dispose(host: host, nodeId: 7);

      expect(host.passwordNodeIds, <int>[7]);
      expect(signer.disposedNodeIds, <int>[7]);
    },
  );
}

final class _CustomSigner extends RlnSigner {
  final List<int> disposedNodeIds = <int>[];

  @override
  Future<void> initNode({
    required RlnSignerHost host,
    required int nodeId,
    required String storageDirPath,
  }) {
    return host.initPasswordNode(nodeId: nodeId, password: 'test-password');
  }

  @override
  Future<void> unlockNode({
    required RlnSignerHost host,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
  }) {
    return host.unlockPasswordNode(
      nodeId: nodeId,
      password: 'test-password',
      config: config,
    );
  }

  @override
  Future<void> dispose({
    required RlnSignerHost host,
    required int nodeId,
  }) async {
    disposedNodeIds.add(nodeId);
  }
}

final class _RecordingSignerHost implements RlnSignerHost {
  final List<int> passwordNodeIds = <int>[];

  @override
  Future<void> initPasswordNode({
    required int nodeId,
    required String password,
    String? mnemonic,
  }) async {
    passwordNodeIds.add(nodeId);
  }

  @override
  Future<void> unlockPasswordNode({
    required int nodeId,
    required String password,
    required UtexoUnlockConfig config,
  }) async {}

  @override
  Future<int> createNativeExternalSigner({
    required String seedHex,
    required String network,
    required bool permissivePolicy,
    required String storageDirPath,
  }) async => 1;

  @override
  Future<void> initNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) async {}

  @override
  Future<void> attachNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) async {}

  @override
  Future<void> unlockNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
    required UtexoUnlockConfig config,
  }) async {}

  @override
  Future<void> destroyNativeExternalSigner(int signerId) async {}
}
