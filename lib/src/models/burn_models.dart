import '../errors/rgb_sdk_exception.dart';

/// Build capabilities after the wallet has applied its signer restrictions.
class BfaCapabilities {
  const BfaCapabilities({
    required this.burn,
    required this.consignment,
    required this.bfa,
  });

  factory BfaCapabilities.fromMap(Map<Object?, Object?> value) {
    bool flag(String key) {
      final result = value[key];
      if (result is bool) return result;
      throw NativeProtocolException(
        'BFA capability must be a boolean.',
        field: key,
      );
    }

    return BfaCapabilities(
      burn: flag('burn'),
      consignment: flag('consignment'),
      bfa: flag('bfa'),
    );
  }

  final bool burn;
  final bool consignment;
  final bool bfa;
}

/// An irreversible RGB burn, expressed in exact unsigned 64-bit base units.
///
/// The native recipient is 32 bytes (64 hex characters, without 0x). BFA
/// requires it. Payout chain selection is a host policy, not native metadata.
/// This request is immutable; submitting it twice can burn funds twice.
class BurnParams {
  const BurnParams({
    required this.assetId,
    required this.amount,
    this.burnRecipient,
    required this.feeRate,
    required this.minConfirmations,
  });

  final String assetId;
  final String amount;
  final String? burnRecipient;

  /// Positive integer sat/vB, bounded to RN's exact integer range.
  final int feeRate;

  /// Required confirmations, from 1 through 255.
  final int minConfirmations;

  /// Rejects malformed inputs before enqueueing any native side effect.
  void validate() {
    validateBurnAssetId(assetId);
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(amount) ||
        BigInt.parse(amount) > BigInt.parse('18446744073709551615')) {
      throw const WalletValidationException(
        'Burn amount must be a positive u64 decimal string.',
        field: 'amount',
      );
    }
    if (burnRecipient != null && !burnHex32.hasMatch(burnRecipient!)) {
      throw const WalletValidationException(
        'Burn recipient must be 32-byte hex without 0x.',
        field: 'burnRecipient',
      );
    }
    if (feeRate < 1 || feeRate > 9007199254740991) {
      throw const WalletValidationException(
        'Burn fee rate must be a positive safe integer in sat/vB.',
        field: 'feeRate',
      );
    }
    if (minConfirmations < 1 || minConfirmations > 255) {
      throw const WalletValidationException(
        'Burn confirmations must be between 1 and 255.',
        field: 'minConfirmations',
      );
    }
  }
}

/// Native burn identity, not evidence of confirmation or external payout.
class BurnResult {
  const BurnResult({required this.txid, required this.batchTransferIdx});

  factory BurnResult.fromMap(Map<Object?, Object?> value) {
    final txid = value['txid'];
    final index = value['batchTransferIdx'];
    if (txid is! String ||
        !burnHex32.hasMatch(txid) ||
        index is! int ||
        index < 0 ||
        index > 9007199254740991) {
      throw const NativeProtocolException('Invalid native burn result.');
    }
    return BurnResult(txid: txid, batchTransferIdx: index);
  }

  final String txid;
  final int batchTransferIdx;

  /// Validate even a directly constructed result before journaling it.
  void validate() =>
      BurnResult.fromMap({'txid': txid, 'batchTransferIdx': batchTransferIdx});
}

final RegExp burnHex32 = RegExp(r'^[a-fA-F0-9]{64}$');

void validateBurnAssetId(String assetId) {
  if (!assetId.startsWith('rgb:') || assetId.length > 256) {
    throw const WalletValidationException(
      'Invalid asset ID.',
      field: 'assetId',
    );
  }
}

void validateConsignmentLookup(String assetId, String txid) {
  validateBurnAssetId(assetId);
  if (!burnHex32.hasMatch(txid)) {
    throw const WalletValidationException(
      'Invalid transaction ID.',
      field: 'txid',
    );
  }
}
