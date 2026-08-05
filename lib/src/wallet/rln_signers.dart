import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

import '../client/rln_client.dart';
import '../errors/rgb_sdk_exception.dart';
import 'network_defaults.dart';
import 'utexo_wallet_types.dart';

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
  RlnSeedBytesKeyMaterial(Uint8List seedBytes)
    : _seedBytes = Uint8List.fromList(seedBytes);

  final Uint8List _seedBytes;

  Uint8List get seedBytes => Uint8List.fromList(_seedBytes);

  @override
  String toSeedHex32() {
    if (_seedBytes.length < 32) {
      throw const WalletValidationException(
        'seedBytes must contain at least 32 bytes.',
        field: 'seedBytes',
      );
    }
    final bytes = _seedBytes.take(32);
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

  Future<void> initNode({
    required RlnClient client,
    required int nodeId,
    required String storageDirPath,
  });

  Future<void> unlockNode({
    required RlnClient client,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
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

  String? _password;
  String? _mnemonic;

  bool get hasPendingPassword => _password != null && _password!.isNotEmpty;

  void provideSecrets({required String password, String? mnemonic}) {
    _password = password;
    if (mnemonic != null) {
      _mnemonic = mnemonic;
    }
  }

  @override
  Future<void> initNode({
    required RlnClient client,
    required int nodeId,
    required String storageDirPath,
  }) async {
    final password = _requirePassword();
    await client.initNode(
      nodeId: nodeId,
      password: password,
      mnemonic: _mnemonic,
    );
    _mnemonic = null;
  }

  @override
  Future<void> unlockNode({
    required RlnClient client,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
  }) async {
    final password = _requirePassword();
    try {
      await client.unlockNode(
        nodeId: nodeId,
        password: password,
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
    } finally {
      _password = null;
      _mnemonic = null;
    }
  }

  String _requirePassword() {
    final password = _password;
    if (password == null || password.isEmpty) {
      throw const WalletValidationException(
        'password is required because the previous password was consumed.',
        field: 'password',
      );
    }
    return password;
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

  String? _seedHex;
  final String network;
  final bool permissivePolicy;
  int? _signerId;
  int? _orphanedSignerId;
  String? _storageDirPath;

  int? get signerId => _signerId;

  @override
  Future<void> initNode({
    required RlnClient client,
    required int nodeId,
    required String storageDirPath,
  }) async {
    _ensureNoOrphanedSigner();
    if (_signerId != null) {
      throw const WalletException(
        'Native external signer is already initialized.',
      );
    }
    final signerId = await _createSigner(client, storageDirPath);
    try {
      await client.initNodeWithNativeExternalSigner(
        nodeId: nodeId,
        signerId: signerId,
      );
    } catch (error, stackTrace) {
      await _cleanupFailedSigner(
        client: client,
        signerId: signerId,
        operationError: error,
        operationStackTrace: stackTrace,
      );
    }
    _signerId = signerId;
  }

  @override
  Future<void> unlockNode({
    required RlnClient client,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
  }) async {
    _ensureNoOrphanedSigner();
    _bindStorageDirPath(storageDirPath);
    if (_signerId == null) {
      final signerId = await _createSigner(client, storageDirPath);
      try {
        await client.attachNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
        );
      } catch (error, stackTrace) {
        await _cleanupFailedSigner(
          client: client,
          signerId: signerId,
          operationError: error,
          operationStackTrace: stackTrace,
        );
      }
      _signerId = signerId;
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
    final signerId = _signerId ?? _orphanedSignerId;
    if (signerId == null) {
      _storageDirPath = null;
      return;
    }
    await client.destroyNativeExternalSigner(signerId);
    if (_signerId == signerId) {
      _signerId = null;
    }
    if (_orphanedSignerId == signerId) {
      _orphanedSignerId = null;
    }
    _storageDirPath = null;
  }

  Future<int> _createSigner(RlnClient client, String storageDirPath) async {
    _ensureNoOrphanedSigner();
    _bindStorageDirPath(storageDirPath);
    final seedHex = _seedHex;
    if (seedHex == null) {
      throw const WalletException(
        'Native external signer seed material has already been consumed. '
        'Create a new NativeExternalRlnSigner to retry.',
      );
    }
    try {
      return await client.createNativeExternalSigner(
        seedHex: seedHex,
        network: network,
        permissivePolicy: permissivePolicy,
        storageDirPath: storageDirPath,
      );
    } finally {
      _seedHex = null;
    }
  }

  void _bindStorageDirPath(String storageDirPath) {
    if (storageDirPath.trim().isEmpty) {
      throw const WalletValidationException(
        'storageDirPath is required for a durable native external signer.',
        field: 'storageDirPath',
      );
    }
    final boundPath = _storageDirPath;
    if (boundPath != null && boundPath != storageDirPath) {
      throw const WalletException(
        'Native external signer cannot change storageDirPath.',
      );
    }
    _storageDirPath = storageDirPath;
  }

  void _ensureNoOrphanedSigner() {
    if (_orphanedSignerId != null) {
      throw const WalletException(
        'Native external signer cleanup previously failed. '
        'Call dispose() before retrying.',
      );
    }
  }

  Future<Never> _cleanupFailedSigner({
    required RlnClient client,
    required int signerId,
    required Object operationError,
    required StackTrace operationStackTrace,
  }) async {
    try {
      await client.destroyNativeExternalSigner(signerId);
    } catch (cleanupError) {
      _orphanedSignerId = signerId;
      Error.throwWithStackTrace(
        WalletException(
          'Native external signer operation and cleanup both failed. '
          'Call dispose() before retrying.',
          cause: <Object>[operationError, cleanupError],
        ),
        operationStackTrace,
      );
    }
    Error.throwWithStackTrace(operationError, operationStackTrace);
  }
}
