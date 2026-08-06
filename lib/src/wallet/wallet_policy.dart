import '../errors/rgb_sdk_exception.dart';
import 'utexo_wallet_types.dart';

/// Internal policy owner for stable wallet-facade argument checks.
///
/// Public DTOs own their shape, native/raw DTOs own wire decoding, and this
/// module owns app-facing validation decisions before a wallet call crosses the
/// native boundary.
abstract final class WalletInputPolicy {
  static void requireCompatibleNativeOwner({
    required Object binding,
    required Object client,
  }) {
    if (identical(binding, client)) return;
    throw const ConfigurationError(
      'binding and client must wrap the same RlnClient instance.',
    );
  }

  static void requireNonEmpty(String value, String field) {
    if (value.isEmpty) {
      throw WalletValidationException(
        '$field must not be empty.',
        field: field,
      );
    }
  }

  static void requirePositive(int value, String field) {
    if (value <= 0) {
      throw WalletValidationException('$field must be positive.', field: field);
    }
  }

  static void requireNonNegative(int value, String field) {
    if (value < 0) {
      throw WalletValidationException(
        '$field must be non-negative.',
        field: field,
      );
    }
  }

  static void requireNonNegativeOptional(int? value, String field) {
    if (value == null) return;
    requireNonNegative(value, field);
  }

  static void requireNonNegativeList(List<int> values, String field) {
    for (var index = 0; index < values.length; index += 1) {
      requireNonNegative(values[index], '$field[$index]');
    }
  }

  static void requireUInt8(int value, String field) {
    if (value < 0 || value > 255) {
      throw WalletValidationException(
        '$field must fit in UInt8.',
        field: field,
      );
    }
  }

  static void requireUInt8Optional(int? value, String field) {
    if (value == null) return;
    requireUInt8(value, field);
  }

  static void requireUInt16(int value, String field) {
    if (value < 0 || value > 65535) {
      throw WalletValidationException(
        '$field must fit in UInt16.',
        field: field,
      );
    }
  }

  static void requireUInt16Optional(int? value, String field) {
    if (value == null) return;
    requireUInt16(value, field);
  }

  static void requireUInt32(int value, String field) {
    if (value < 0 || value > 4294967295) {
      throw WalletValidationException(
        '$field must fit in UInt32.',
        field: field,
      );
    }
  }

  static void requireUInt32Optional(int? value, String field) {
    if (value == null) return;
    requireUInt32(value, field);
  }

  static void requireIntegerFeeRate(double value, String field) {
    if (value.isNaN ||
        value.isInfinite ||
        value < 0 ||
        value.truncateToDouble() != value) {
      throw WalletValidationException(
        '$field must be a finite non-negative integer fee rate.',
        field: field,
      );
    }
  }

  static void validateConfig(UtexoWalletConfig config) {
    requireNonEmpty(config.storageDirPath, 'storageDirPath');
    requireUInt16(config.daemonListeningPort, 'daemonListeningPort');
    requireUInt16(config.ldkPeerListeningPort, 'ldkPeerListeningPort');
    requireUInt16(config.maxMediaUploadSizeMb, 'maxMediaUploadSizeMb');
  }

  static void requireSupportedRgbSendSkipSync(bool skipSync) {
    if (!skipSync) return;
    throw const UnsupportedWalletFeatureException(
      'rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.',
      feature: 'rlnSendRgb.skipSync',
    );
  }
}
