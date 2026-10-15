import 'package:crypto/crypto.dart' show sha256;

import '../errors/rgb_sdk_exception.dart';

const _tronChains = {'tron:728126428', 'tron:2494104990', 'tron:3448148188'};
const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

/// Supported address namespaces; host authorization is checked separately.
bool isSupportedBurnPayoutChain(String chainId) =>
    RegExp(r'^eip155:[1-9][0-9]*$').hasMatch(chainId) ||
    _tronChains.contains(chainId);

/// Validates the chain/address pair without changing Base58Check casing.
String normalizeBurnRecipientAddress(String chainId, String address) {
  encodeBurnRecipient(chainId, address);
  return chainId.startsWith('eip155:') ? address.toLowerCase() : address;
}

/// Native BFA commitments contain the account bytes, not the payout chain ID.
String encodeBurnRecipient(String chainId, String address) {
  if (RegExp(r'^eip155:[1-9][0-9]*$').hasMatch(chainId)) {
    return encodeEvmBurnRecipient(address);
  }
  if (_tronChains.contains(chainId)) return encodeTronBurnRecipient(address);
  throw const WalletValidationException(
    'Unsupported burn payout chain.',
    field: 'payout',
  );
}

/// Encodes a nonzero EVM address as 12 zero bytes and 20 address bytes.
String encodeEvmBurnRecipient(String address) {
  if (address.length != 42 ||
      !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address) ||
      RegExp(r'^0x0{40}$', caseSensitive: false).hasMatch(address)) {
    throw const WalletValidationException(
      'A nonzero 20-byte EVM address is required.',
      field: 'payout',
    );
  }
  return address.substring(2).toLowerCase().padLeft(64, '0');
}

/// Validates a Tron Base58Check address and commits its 20 account bytes.
///
/// The 0x41 network prefix and four-byte double-SHA256 checksum are transport
/// metadata, so neither belongs in the zero-padded 32-byte burn recipient.
String encodeTronBurnRecipient(String address) {
  const invalid = WalletValidationException(
    'A nonzero Tron Base58Check address is required.',
    field: 'payout',
  );
  if (address.length != 34 ||
      !RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(address)) {
    throw invalid;
  }
  // The fixed 34-character bound limits the decoder to a public 25-byte value.
  var number = BigInt.zero;
  final radix = BigInt.from(58);
  for (final codeUnit in address.codeUnits) {
    final digit = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    number = number * radix + BigInt.from(digit);
  }
  final decoded = List<int>.filled(25, 0);
  for (var index = decoded.length - 1; index >= 0; index -= 1) {
    decoded[index] = (number & BigInt.from(255)).toInt();
    number >>= 8;
  }
  if (number != BigInt.zero || decoded[0] != 0x41) throw invalid;
  final payload = decoded.sublist(0, 21);
  final checksum = sha256.convert(sha256.convert(payload).bytes).bytes;
  for (var index = 0; index < 4; index += 1) {
    if (decoded[21 + index] != checksum[index]) throw invalid;
  }
  final account = payload.sublist(1);
  if (account.every((byte) => byte == 0)) throw invalid;
  return account
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join()
      .padLeft(64, '0');
}
