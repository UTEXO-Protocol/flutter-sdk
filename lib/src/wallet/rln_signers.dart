import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

import '../client/rln_client.dart';
import '../errors/rgb_sdk_exception.dart';
import 'network_defaults.dart';
import 'utexo_wallet.dart';

/// Key material accepted by native external RLN signers.
///
/// This mirrors the React Native package: mnemonic strings are converted to a
/// BIP39 seed and raw seed bytes are truncated to the first 32 bytes.
sealed class RlnKeyMaterial {
  const RlnKeyMaterial();

  factory RlnKeyMaterial.mnemonic(String mnemonic) = RlnMnemonicKeyMaterial;
  factory RlnKeyMaterial.seedBytes(Uint8List seedBytes) =
      RlnSeedBytesKeyMaterial;
  factory RlnKeyMaterial.seedHex(String seedHex) = RlnSeedHexKeyMaterial;

  String toSeedHex32();
}

class RlnMnemonicKeyMaterial extends RlnKeyMaterial {
  const RlnMnemonicKeyMaterial(this.mnemonic);

  final String mnemonic;

  @override
  String toSeedHex32() => bip39.mnemonicToSeedHex(mnemonic).substring(0, 64);
}

class RlnSeedBytesKeyMaterial extends RlnKeyMaterial {
  const RlnSeedBytesKeyMaterial(this.seedBytes);

  final Uint8List seedBytes;

  @override
  String toSeedHex32() {
    if (seedBytes.length < 32) {
      throw const WalletValidationException(
        'seedBytes must contain at least 32 bytes.',
        field: 'seedBytes',
      );
    }
    final bytes = seedBytes.take(32);
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class RlnSeedHexKeyMaterial extends RlnKeyMaterial {
  const RlnSeedHexKeyMaterial(this.seedHex);

  final String seedHex;

  @override
  String toSeedHex32() {
    final normalized = seedHex.startsWith('0x')
        ? seedHex.substring(2)
        : seedHex;
    if (normalized.length < 64) {
      throw const WalletValidationException(
        'seedHex must contain at least 32 bytes.',
        field: 'seedHex',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
      throw const WalletValidationException(
        'seedHex must be hexadecimal.',
        field: 'seedHex',
      );
    }
    return normalized.substring(0, 64);
  }
}

/// RN-compatible signer strategy used by [UtexoWallet].
abstract class RlnSigner {
  const RlnSigner();

  Future<void> initNode({required RlnClient client, required int nodeId});

  Future<void> unlockNode({
    required RlnClient client,
    required int nodeId,
    required UtexoUnlockConfig config,
  });

  Future<void> dispose({
    required RlnClient client,
    required int nodeId,
  }) async {}
}

/// Password-based signer equivalent to RN `PasswordRLNSigner`.
class PasswordRlnSigner extends RlnSigner {
  PasswordRlnSigner({required String password, String? mnemonic})
    : _password = password,
      _mnemonic = mnemonic;

  final String _password;
  String? _mnemonic;

  @override
  Future<void> initNode({
    required RlnClient client,
    required int nodeId,
  }) async {
    await client.initNode(
      nodeId: nodeId,
      password: _password,
      mnemonic: _mnemonic,
    );
    _mnemonic = null;
  }

  @override
  Future<void> unlockNode({
    required RlnClient client,
    required int nodeId,
    required UtexoUnlockConfig config,
  }) {
    return client.unlockNode(
      nodeId: nodeId,
      password: _password,
      bitcoindRpcUsername: config.bitcoindRpcUsername,
      bitcoindRpcPassword: config.bitcoindRpcPassword,
      bitcoindRpcHost: config.bitcoindRpcHost,
      bitcoindRpcPort: config.bitcoindRpcPort,
      indexerUrl: config.indexerUrl,
      proxyEndpoint: config.proxyEndpoint,
      announceAddresses: config.announceAddresses,
      announceAlias: config.announceAlias,
      gossipRgsServerUrl: config.gossipRgsServerUrl,
    );
  }
}

/// Native external signer equivalent to RN `NativeExternalRLNSigner`.
class NativeExternalRlnSigner extends RlnSigner {
  NativeExternalRlnSigner({
    required RlnKeyMaterial keys,
    required String network,
    this.permissivePolicy = true,
  }) : _seedHex = keys.toSeedHex32(),
       network = normalizeNativeRlnNetwork(network);

  final String _seedHex;
  final String network;
  final bool permissivePolicy;
  int? _signerId;

  int? get signerId => _signerId;

  @override
  Future<void> initNode({
    required RlnClient client,
    required int nodeId,
  }) async {
    _signerId = await client.createNativeExternalSigner(
      seedHex: _seedHex,
      network: network,
      permissivePolicy: permissivePolicy,
    );
    await client.initNodeWithNativeExternalSigner(
      nodeId: nodeId,
      signerId: _signerId!,
    );
  }

  @override
  Future<void> unlockNode({
    required RlnClient client,
    required int nodeId,
    required UtexoUnlockConfig config,
  }) async {
    if (_signerId == null) {
      _signerId = await client.createNativeExternalSigner(
        seedHex: _seedHex,
        network: network,
        permissivePolicy: permissivePolicy,
      );
      await client.attachNativeExternalSigner(
        nodeId: nodeId,
        signerId: _signerId!,
      );
    }
    await client.unlockNodeWithNativeExternalSigner(
      nodeId: nodeId,
      signerId: _signerId!,
      bitcoindRpcUsername: config.bitcoindRpcUsername,
      bitcoindRpcPassword: config.bitcoindRpcPassword,
      bitcoindRpcHost: config.bitcoindRpcHost,
      bitcoindRpcPort: config.bitcoindRpcPort,
      indexerUrl: config.indexerUrl,
      proxyEndpoint: config.proxyEndpoint,
      announceAddresses: config.announceAddresses,
      announceAlias: config.announceAlias,
      gossipRgsServerUrl: config.gossipRgsServerUrl,
    );
  }

  @override
  Future<void> dispose({required RlnClient client, required int nodeId}) async {
    final signerId = _signerId;
    if (signerId == null) return;
    await client.destroyNativeExternalSigner(signerId);
    _signerId = null;
  }
}
