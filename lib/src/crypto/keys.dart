import 'dart:typed_data';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;

import '../errors/rgb_sdk_exception.dart';
import 'constants.dart';
import 'validation.dart';

class GeneratedKeys {
  const GeneratedKeys({
    required this.mnemonic,
    required this.xpub,
    required this.accountXpubVanilla,
    required this.accountXpubColored,
    required this.masterFingerprint,
    required this.xpriv,
  });

  final String mnemonic;
  final String xpub;
  final String accountXpubVanilla;
  final String accountXpubColored;
  final String masterFingerprint;
  final String xpriv;
}

class AccountXpubs {
  const AccountXpubs({
    required this.accountXpubVanilla,
    required this.accountXpubColored,
  });

  final String accountXpubVanilla;
  final String accountXpubColored;

  // ignore: non_constant_identifier_names
  String get account_xpub_vanilla => accountXpubVanilla;
  // ignore: non_constant_identifier_names
  String get account_xpub_colored => accountXpubColored;
}

class WalletInitParams {
  const WalletInitParams({
    required this.xpubVan,
    required this.xpubCol,
    required this.masterFingerprint,
    this.mnemonic,
    this.seed,
    this.network,
    this.xpub,
    this.transportEndpoint,
    this.indexerUrl,
    this.dataDir,
    this.reuseAddresses,
    this.vanillaKeychain,
    this.maxAllocationsPerUtxo,
  });

  final String xpubVan;
  final String xpubCol;
  final String masterFingerprint;
  final String? mnemonic;
  final Uint8List? seed;
  final Object? network;
  final String? xpub;
  final String? transportEndpoint;
  final String? indexerUrl;
  final String? dataDir;
  final bool? reuseAddresses;
  final int? vanillaKeychain;
  final int? maxAllocationsPerUtxo;
}

String _hexByte(int value) => value.toRadixString(16).padLeft(2, '0');

String _bytesToHex(Iterable<int> bytes) => bytes.map(_hexByte).join();

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i += 1) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

/// Best-effort scrubbing for secret byte buffers owned by this package.
///
/// Dart cannot guarantee zeroization for immutable strings, BIP32 internals, or
/// VM copies. Use this only to shorten the lifetime of mutable byte buffers that
/// the SDK explicitly created or defensively copied.
void wipeSecretBytes(Uint8List bytes) {
  bytes.fillRange(0, bytes.length, 0);
}

Uint8List normalizeSeedInput(Object seed, [String field = 'seed']) {
  if (seed is String) {
    final trimmed = seed.trim();
    if (trimmed.isEmpty) {
      throw ValidationError('$field must be a non-empty hex string', field);
    }
    final hex = trimmed.startsWith('0x') ? trimmed.substring(2) : trimmed;
    if (hex.length.isOdd) {
      throw ValidationError('$field hex string must have even length', field);
    }
    if (hex.length != 128) {
      throw ValidationError(
        '$field must be 64 bytes (128 hex characters)',
        field,
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      throw ValidationError('$field must be a valid hex string', field);
    }
    return _hexToBytes(hex);
  }
  if (seed is Uint8List) {
    if (seed.isEmpty) {
      throw ValidationError('$field must not be empty', field);
    }
    return Uint8List.fromList(seed);
  }
  if (seed is List<int>) {
    if (seed.isEmpty) {
      throw ValidationError('$field must not be empty', field);
    }
    if (seed.any((byte) => byte < 0 || byte > 255)) {
      throw ValidationError('$field must contain bytes in 0..255', field);
    }
    return Uint8List.fromList(seed);
  }
  throw ValidationError(
    '$field must be a 64-byte hex string or Uint8List',
    field,
  );
}

BIP32 rootNodeFromSeed(Uint8List seed, Object network) {
  try {
    return BIP32.fromSeed(seed, getNetworkVersions(network).toBip32Network());
  } catch (error) {
    throw CryptoError(
      'Failed to create BIP32 root node from seed',
      cause: error,
    );
  }
}

BIP32 rootNodeFromBase58(String key, Object network) {
  try {
    return BIP32.fromBase58(key, getNetworkVersions(network).toBip32Network());
  } catch (error) {
    throw CryptoError('Failed to parse extended key', cause: error);
  }
}

GeneratedKeys _buildGeneratedKeysFromRoot(
  BIP32 root,
  Network network,
  String mnemonic,
) {
  final accountXpubs = _deriveAccountXpubsFromRoot(root, network);
  return GeneratedKeys(
    mnemonic: mnemonic,
    xpub: root.neutered().toBase58(),
    accountXpubVanilla: accountXpubs.accountXpubVanilla,
    accountXpubColored: accountXpubs.accountXpubColored,
    masterFingerprint: _bytesToHex(root.fingerprint),
    xpriv: root.toBase58(),
  );
}

AccountXpubs _deriveAccountXpubsFromRoot(BIP32 root, Network network) {
  return AccountXpubs(
    accountXpubVanilla: root
        .derivePath(accountDerivationPath(network, false))
        .neutered()
        .toBase58(),
    accountXpubColored: root
        .derivePath(accountDerivationPath(network, true))
        .neutered()
        .toBase58(),
  );
}

Future<GeneratedKeys> createWallet([Object network = DEFAULT_NETWORK]) {
  return generateKeys(network);
}

Future<GeneratedKeys> generateKeys([
  Object bitcoinNetwork = DEFAULT_NETWORK,
]) async {
  try {
    final mnemonic = bip39.generateMnemonic(strength: 128);
    return deriveKeysFromMnemonic(bitcoinNetwork, mnemonic);
  } catch (error) {
    if (error is RgbSdkException) rethrow;
    throw CryptoError('Failed to generate mnemonic: $error', cause: error);
  }
}

Future<GeneratedKeys> deriveKeysFromMnemonic(
  Object bitcoinNetwork,
  String mnemonic,
) async {
  validateBip39Mnemonic(mnemonic);
  final network = normalizeNetwork(bitcoinNetwork);
  final seed = bip39.mnemonicToSeed(mnemonic.trim());
  try {
    final root = rootNodeFromSeed(seed, network);
    return _buildGeneratedKeysFromRoot(root, network, mnemonic.trim());
  } catch (error) {
    if (error is RgbSdkException) rethrow;
    throw CryptoError('Failed to derive keys from mnemonic', cause: error);
  } finally {
    wipeSecretBytes(seed);
  }
}

Future<GeneratedKeys> deriveKeysFromSeed(
  Object bitcoinNetwork,
  Object seed,
) async {
  final network = normalizeNetwork(bitcoinNetwork);
  final normalizedSeed = normalizeSeedInput(seed);
  try {
    final root = rootNodeFromSeed(normalizedSeed, network);
    return _buildGeneratedKeysFromRoot(root, network, '');
  } catch (error) {
    if (error is RgbSdkException) rethrow;
    throw CryptoError('Failed to derive keys from seed', cause: error);
  } finally {
    wipeSecretBytes(normalizedSeed);
  }
}

Future<GeneratedKeys> deriveKeysFromMnemonicOrSeed(
  Object bitcoinNetwork,
  Object mnemonicOrSeed,
) async {
  if (mnemonicOrSeed is String) {
    final trimmed = mnemonicOrSeed.trim();
    final words = trimmed.split(RegExp(r'\s+'));
    final isLikelyMnemonic =
        trimmed.contains(' ') && words.length >= 12 && words.length <= 24;
    if (isLikelyMnemonic) {
      try {
        return deriveKeysFromMnemonic(bitcoinNetwork, trimmed);
      } on ValidationError {
        return deriveKeysFromSeed(bitcoinNetwork, trimmed);
      }
    }
    return deriveKeysFromSeed(bitcoinNetwork, trimmed);
  }
  return deriveKeysFromSeed(bitcoinNetwork, mnemonicOrSeed);
}

Future<GeneratedKeys> restoreKeys(Object bitcoinNetwork, String mnemonic) {
  return deriveKeysFromMnemonic(bitcoinNetwork, mnemonic);
}

Future<String> getXprivFromMnemonic(
  Object bitcoinNetwork,
  String mnemonic,
) async {
  validateBip39Mnemonic(mnemonic);
  final network = normalizeNetwork(bitcoinNetwork);
  final seed = bip39.mnemonicToSeed(mnemonic.trim());
  try {
    return rootNodeFromSeed(seed, network).toBase58();
  } catch (error) {
    if (error is RgbSdkException) rethrow;
    throw CryptoError('Failed to derive xpriv from mnemonic', cause: error);
  } finally {
    wipeSecretBytes(seed);
  }
}

Future<String> getXpubFromXpriv(String xpriv, [Object? bitcoinNetwork]) async {
  if (xpriv.trim().isEmpty) {
    throw const ValidationError('xpriv must be a non-empty string', 'xpriv');
  }
  try {
    final network =
        bitcoinNetwork ?? (xpriv.startsWith('xprv') ? 'mainnet' : 'testnet');
    return rootNodeFromBase58(xpriv, network).neutered().toBase58();
  } catch (error) {
    if (error is RgbSdkException) rethrow;
    throw CryptoError('Failed to derive xpub from xpriv', cause: error);
  }
}

Future<GeneratedKeys> deriveKeysFromXpriv(
  Object networkOrXpriv, [
  String? xpriv,
]) async {
  final actualXpriv = xpriv ?? networkOrXpriv.toString();
  if (actualXpriv.trim().isEmpty) {
    throw const ValidationError('xpriv must be a non-empty string', 'xpriv');
  }
  try {
    final detectedNetwork =
        actualXpriv.startsWith('tprv') || actualXpriv.startsWith('tpub')
        ? 'testnet'
        : 'mainnet';
    final network = normalizeNetwork(detectedNetwork);
    final root = rootNodeFromBase58(actualXpriv, network);
    return _buildGeneratedKeysFromRoot(root, network, '');
  } catch (error) {
    if (error is RgbSdkException) rethrow;
    throw CryptoError('Failed to derive keys from xpriv', cause: error);
  }
}

Future<AccountXpubs> accountXpubsFromMnemonic(
  Object bitcoinNetwork,
  String mnemonic,
) async {
  final keys = await deriveKeysFromMnemonic(bitcoinNetwork, mnemonic);
  return AccountXpubs(
    accountXpubVanilla: keys.accountXpubVanilla,
    accountXpubColored: keys.accountXpubColored,
  );
}

Uint8List seedFromMnemonic(String mnemonic) {
  validateBip39Mnemonic(mnemonic);
  return bip39.mnemonicToSeed(mnemonic.trim());
}
