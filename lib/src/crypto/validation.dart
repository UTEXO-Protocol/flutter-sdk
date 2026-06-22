import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;

import '../errors/rgb_sdk_exception.dart';
import 'constants.dart';

const List<Network> _validNetworks = <Network>[
  'mainnet',
  'testnet',
  'testnet4',
  'signet',
  'signet_custom',
  'utexo',
  'regtest',
];

void validateNetwork(Object network) {
  final normalized = NETWORK_MAP[network.toString().toLowerCase()];
  if (normalized == null || !_validNetworks.contains(normalized)) {
    throw ValidationError(
      'Invalid network: $network. Must be one of: ${_validNetworks.join(', ')}',
      'network',
    );
  }
}

Network normalizeNetwork(Object network) {
  validateNetwork(network);
  return NETWORK_MAP[network.toString().toLowerCase()]!;
}

bool isNetwork(Object? value) {
  if (value is! String) return false;
  final normalized = NETWORK_MAP[value.toLowerCase()];
  return normalized != null && _validNetworks.contains(normalized);
}

void validateMnemonic(Object? mnemonic, [String field = 'mnemonic']) {
  if (mnemonic is! String || mnemonic.trim().isEmpty) {
    throw ValidationError('$field must be a non-empty string', field);
  }

  final words = mnemonic.trim().split(RegExp(r'\s+'));
  if (words.length != 12 && words.length != 24) {
    throw ValidationError(
      '$field must be 12 or 24 words, got ${words.length} words',
      field,
    );
  }
}

void validateBip39Mnemonic(String mnemonic, [String field = 'mnemonic']) {
  validateMnemonic(mnemonic, field);
  if (!bip39.validateMnemonic(mnemonic.trim())) {
    throw ValidationError(
      'Invalid mnemonic format - failed BIP39 validation',
      field,
    );
  }
}

void validateBase64(Object? base64, [String field = 'data']) {
  if (base64 is! String || base64.trim().isEmpty) {
    throw ValidationError('$field must be a non-empty string', field);
  }
  final normalized = base64.trim();
  if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(normalized)) {
    throw ValidationError('Invalid base64 format for $field', field);
  }
  try {
    base64Decode(normalized);
  } catch (_) {
    throw ValidationError('Invalid base64 encoding for $field', field);
  }
}

void validatePsbt(Object? psbt, [String field = 'psbt']) {
  validateBase64(psbt, field);
  if (psbt.toString().trim().length < 50) {
    throw ValidationError(
      '$field appears to be too short to be a valid PSBT',
      field,
    );
  }
}

void validateHex(Object? hex, [String field = 'data']) {
  if (hex is! String || hex.trim().isEmpty) {
    throw ValidationError('$field must be a non-empty string', field);
  }
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex.trim())) {
    throw ValidationError('Invalid hex format for $field', field);
  }
}

void validateRequired<T>(T? value, String field) {
  if (value == null) {
    throw ValidationError('$field is required', field);
  }
}

void validateString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw ValidationError('$field must be a non-empty string', field);
  }
}

int toUnitsNumber(String value, int precision) {
  final normalized = value.trim();
  final negative = normalized.startsWith('-');
  final body = negative ? normalized.substring(1) : normalized;
  final parts = body.split('.');
  final integerPart = parts.isEmpty || parts.first.isEmpty ? '0' : parts.first;
  final fractionalPart = parts.length > 1 ? parts[1] : '';
  final paddedFraction = (fractionalPart + '0' * precision).substring(
    0,
    precision,
  );
  final units = int.parse(integerPart + paddedFraction);
  return negative ? -units : units;
}

double fromUnitsNumber(int units, int precision) {
  final base = BigInt.from(10).pow(precision).toDouble();
  return units / base;
}
