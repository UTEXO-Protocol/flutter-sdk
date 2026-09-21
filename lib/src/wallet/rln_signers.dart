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

/// Narrow node-operation boundary available to custom [RlnSigner] strategies.
///
/// The wallet supplies this host. Implementations must not retain it beyond an
/// operation because its native node ownership follows the wallet lifecycle.
abstract interface class RlnSignerHost {
  Future<void> initPasswordNode({
    required int nodeId,
    required String password,
    String? mnemonic,
  });

  Future<void> unlockPasswordNode({
    required int nodeId,
    required String password,
    required UtexoUnlockConfig config,
  });

  Future<int> createNativeExternalSigner({
    required String seedHex,
    required String network,
    required bool permissivePolicy,
    required String storageDirPath,
  });

  Future<void> initNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
  });

  Future<void> attachNativeExternalSigner({
    required int nodeId,
    required int signerId,
  });

  Future<void> unlockNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
    required UtexoUnlockConfig config,
  });

  Future<void> destroyNativeExternalSigner(int signerId);
}

/// RN-compatible signer strategy used by [UtexoWallet].
abstract class RlnSigner {
  const RlnSigner();

  Future<void> initNode({
    required RlnSignerHost host,
    required int nodeId,
    required String storageDirPath,
  });

  Future<void> unlockNode({
    required RlnSignerHost host,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
  });

  Future<void> dispose({
    required RlnSignerHost host,
    required int? nodeId,
  }) async {}
}

/// Password-based signer equivalent to RN `PasswordRLNSigner`.
class PasswordRlnSigner extends RlnSigner {
  PasswordRlnSigner({required String password, String? mnemonic})
    : _password = password,
      _mnemonic = mnemonic;

  String? _password;
  String? _mnemonic;

  void provideSecrets({required String password, String? mnemonic}) {
    _password = password;
    if (mnemonic != null) {
      _mnemonic = mnemonic;
    }
  }

  @override
  Future<void> initNode({
    required RlnSignerHost host,
    required int nodeId,
    required String storageDirPath,
  }) async {
    final password = _requirePassword();
    try {
      await host.initPasswordNode(
        nodeId: nodeId,
        password: password,
        mnemonic: _mnemonic,
      );
    } catch (_) {
      _password = null;
      rethrow;
    } finally {
      _mnemonic = null;
    }
  }

  @override
  Future<void> unlockNode({
    required RlnSignerHost host,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
  }) async {
    final password = _requirePassword();
    try {
      await host.unlockPasswordNode(
        nodeId: nodeId,
        password: password,
        config: config,
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

  @override
  Future<void> dispose({
    required RlnSignerHost host,
    required int? nodeId,
  }) async {
    _password = null;
    _mnemonic = null;
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
    required RlnSignerHost host,
    required int nodeId,
    required String storageDirPath,
  }) async {
    _ensureNoOrphanedSigner();
    if (_signerId != null) {
      throw const WalletException(
        'Native external signer is already initialized.',
      );
    }
    final signerId = await _createSigner(host, storageDirPath);
    try {
      await host.initNodeWithNativeExternalSigner(
        nodeId: nodeId,
        signerId: signerId,
      );
    } catch (error, stackTrace) {
      await _cleanupFailedSigner(
        host: host,
        signerId: signerId,
        operationError: error,
        operationStackTrace: stackTrace,
      );
    }
    _signerId = signerId;
  }

  @override
  Future<void> unlockNode({
    required RlnSignerHost host,
    required int nodeId,
    required UtexoUnlockConfig config,
    required String storageDirPath,
  }) async {
    _ensureNoOrphanedSigner();
    _bindStorageDirPath(storageDirPath);
    if (_signerId == null) {
      final signerId = await _createSigner(host, storageDirPath);
      try {
        await host.attachNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
        );
      } catch (error, stackTrace) {
        await _cleanupFailedSigner(
          host: host,
          signerId: signerId,
          operationError: error,
          operationStackTrace: stackTrace,
        );
      }
      _signerId = signerId;
    }
    await host.unlockNodeWithNativeExternalSigner(
      nodeId: nodeId,
      signerId: _signerId!,
      config: config,
    );
  }

  @override
  Future<void> dispose({
    required RlnSignerHost host,
    required int? nodeId,
  }) async {
    _seedHex = null;
    final signerId = _signerId ?? _orphanedSignerId;
    if (signerId == null) {
      _storageDirPath = null;
      return;
    }
    await host.destroyNativeExternalSigner(signerId);
    if (_signerId == signerId) {
      _signerId = null;
    }
    if (_orphanedSignerId == signerId) {
      _orphanedSignerId = null;
    }
    _storageDirPath = null;
  }

  Future<int> _createSigner(RlnSignerHost host, String storageDirPath) async {
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
      return await host.createNativeExternalSigner(
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
    required RlnSignerHost host,
    required int signerId,
    required Object operationError,
    required StackTrace operationStackTrace,
  }) async {
    try {
      await host.destroyNativeExternalSigner(signerId);
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

Future<void> initializeRlnSigner({
  required RlnSigner signer,
  required RlnClient client,
  required int nodeId,
  required String storageDirPath,
}) {
  return signer.initNode(
    host: _RlnClientSignerHost(client),
    nodeId: nodeId,
    storageDirPath: storageDirPath,
  );
}

Future<void> unlockRlnSigner({
  required RlnSigner signer,
  required RlnClient client,
  required int nodeId,
  required UtexoUnlockConfig config,
  required String storageDirPath,
}) {
  return signer.unlockNode(
    host: _RlnClientSignerHost(client),
    nodeId: nodeId,
    config: config,
    storageDirPath: storageDirPath,
  );
}

Future<void> disposeRlnSigner({
  required RlnSigner signer,
  required RlnClient client,
  required int? nodeId,
}) {
  return signer.dispose(host: _RlnClientSignerHost(client), nodeId: nodeId);
}

final class _RlnClientSignerHost implements RlnSignerHost {
  const _RlnClientSignerHost(this._client);

  final RlnClient _client;

  @override
  Future<void> initPasswordNode({
    required int nodeId,
    required String password,
    String? mnemonic,
  }) {
    return _client
        .initNode(nodeId: nodeId, password: password, mnemonic: mnemonic)
        .then((_) {});
  }

  @override
  Future<void> unlockPasswordNode({
    required int nodeId,
    required String password,
    required UtexoUnlockConfig config,
  }) {
    return _client.unlockNode(
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
  }

  @override
  Future<int> createNativeExternalSigner({
    required String seedHex,
    required String network,
    required bool permissivePolicy,
    required String storageDirPath,
  }) {
    return _client.createNativeExternalSigner(
      seedHex: seedHex,
      network: network,
      permissivePolicy: permissivePolicy,
      storageDirPath: storageDirPath,
    );
  }

  @override
  Future<void> initNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) {
    return _client.initNodeWithNativeExternalSigner(
      nodeId: nodeId,
      signerId: signerId,
    );
  }

  @override
  Future<void> attachNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) {
    return _client.attachNativeExternalSigner(
      nodeId: nodeId,
      signerId: signerId,
    );
  }

  @override
  Future<void> unlockNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
    required UtexoUnlockConfig config,
  }) {
    return _client.unlockNodeWithNativeExternalSigner(
      nodeId: nodeId,
      signerId: signerId,
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
  Future<void> destroyNativeExternalSigner(int signerId) {
    return _client.destroyNativeExternalSigner(signerId);
  }
}
