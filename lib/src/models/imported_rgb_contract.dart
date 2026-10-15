import 'dart:convert';

import '../errors/rgb_sdk_exception.dart';
import 'burn_models.dart' show validateBurnAssetId;

/// Verified identity and public fungible metadata from a contract import.
///
/// Supplies are exact base units. Importing this definition does not create
/// allocations or a balance. Token attachments and asset state remain available
/// through the wallet's asset list after import.
class ImportedRgbContract {
  const ImportedRgbContract({
    required this.assetId,
    required this.alreadyImported,
    required this.assetSchema,
    required this.name,
    required this.precision,
    required this.initialSupply,
    required this.maxSupply,
    required this.knownCirculatingSupply,
    this.ticker,
    this.details,
  });

  factory ImportedRgbContract.fromMap(
    Map<Object?, Object?> value, {
    required String expectedAssetId,
  }) {
    Never invalid(String field) => throw NativeProtocolException(
      'Malformed imported RGB contract metadata.',
      field: field,
    );
    final metadata = value['metadata'];
    if (metadata is! Map<Object?, Object?>) invalid('metadata');
    String text(String key) {
      final result = metadata[key];
      if (result is! String || result.isEmpty) invalid('metadata.$key');
      return result;
    }

    String? optionalText(String key) {
      final result = metadata[key];
      if (result == null) return null;
      if (result is! String) invalid('metadata.$key');
      return result;
    }

    BigInt supply(String key) {
      final result = metadata[key];
      final units = switch (result) {
        int() when result >= 0 => BigInt.from(result),
        String() when RegExp(r'^[0-9]+$').hasMatch(result) => BigInt.tryParse(
          result,
        ),
        _ => null,
      };
      if (units == null || units > BigInt.parse('18446744073709551615')) {
        invalid('metadata.$key');
      }
      return units;
    }

    if (value['assetId'] != expectedAssetId) invalid('assetId');
    final imported = value['alreadyImported'];
    if (imported is! bool) invalid('alreadyImported');
    final precision = metadata['precision'];
    if (precision is! int || precision < 0 || precision > 255) {
      invalid('metadata.precision');
    }
    return ImportedRgbContract(
      assetId: expectedAssetId,
      alreadyImported: imported,
      assetSchema: text('assetSchema'),
      name: text('name'),
      precision: precision,
      initialSupply: supply('initialSupply'),
      maxSupply: supply('maxSupply'),
      knownCirculatingSupply: supply('knownCirculatingSupply'),
      ticker: optionalText('ticker'),
      details: optionalText('details'),
    );
  }

  final String assetId;
  final bool alreadyImported;
  final String assetSchema;
  final String name;
  final int precision;
  final BigInt initialSupply;
  final BigInt maxSupply;
  final BigInt knownCirculatingSupply;
  final String? ticker;
  final String? details;
}

/// Rejects malformed encodings before native import mutates wallet metadata.
void validateRgbContractImport(String contractBase64, String expectedAssetId) {
  validateBurnAssetId(expectedAssetId);
  if (contractBase64.isEmpty ||
      contractBase64.length > 16 * 1024 * 1024 ||
      contractBase64.length % 4 != 0 ||
      !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(contractBase64)) {
    throw const WalletValidationException(
      'Expected non-empty standard Base64 public contract bytes.',
      field: 'contractBase64',
    );
  }
  try {
    final bytes = base64Decode(contractBase64);
    if (bytes.isEmpty || base64Encode(bytes) != contractBase64) {
      throw const FormatException('Noncanonical Base64');
    }
  } on FormatException {
    throw const WalletValidationException(
      'Expected canonical standard Base64 public contract bytes.',
      field: 'contractBase64',
    );
  }
}
