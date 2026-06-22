/// Base exception type thrown by the Dart wallet facade.
class RgbSdkException implements Exception {
  const RgbSdkException(this.message, {required this.code, this.cause});

  final String message;
  final String code;
  final Object? cause;

  @override
  String toString() => 'RgbSdkException($code): $message';
}

/// RN-core compatible base error name.
class SDKError extends RgbSdkException {
  const SDKError(super.message, {super.cause}) : super(code: 'SDK_ERROR');
}

/// General wallet lifecycle or native-response error.
class WalletException extends RgbSdkException {
  const WalletException(super.message, {super.cause})
    : super(code: 'WALLET_ERROR');
}

/// RN-core compatible wallet error name.
class WalletError extends WalletException {
  const WalletError(super.message, {super.cause});
}

/// Input validation failure before a native call is made.
class WalletValidationException extends RgbSdkException {
  const WalletValidationException(super.message, {required this.field})
    : super(code: 'VALIDATION_ERROR');

  final String field;

  @override
  String toString() => 'WalletValidationException($field): $message';
}

/// RN-core compatible validation error name.
class ValidationError extends WalletValidationException {
  const ValidationError(super.message, String field) : super(field: field);
}

/// RN-core compatible crypto error name.
class CryptoError extends RgbSdkException {
  const CryptoError(super.message, {super.cause}) : super(code: 'CRYPTO_ERROR');
}

/// RN-core compatible network error name.
class NetworkError extends RgbSdkException {
  const NetworkError(super.message, {super.cause})
    : super(code: 'NETWORK_ERROR');
}

/// RN-core compatible configuration error name.
class ConfigurationError extends RgbSdkException {
  const ConfigurationError(super.message, {super.cause})
    : super(code: 'CONFIGURATION_ERROR');
}

/// RN-core compatible bad request error name.
class BadRequestError extends RgbSdkException {
  const BadRequestError(super.message, {super.cause})
    : super(code: 'BAD_REQUEST');
}

/// RN-core compatible not found error name.
class NotFoundError extends RgbSdkException {
  const NotFoundError(super.message, {super.cause}) : super(code: 'NOT_FOUND');
}

/// RN-core compatible conflict error name.
class ConflictError extends RgbSdkException {
  const ConflictError(super.message, {super.cause}) : super(code: 'CONFLICT');
}

/// RN-core compatible RGB node error name.
class RgbNodeError extends RgbSdkException {
  const RgbNodeError(super.message, {super.cause})
    : super(code: 'RGB_NODE_ERROR');
}

/// Feature that exists for parity but is intentionally unavailable.
class UnsupportedWalletFeatureException extends RgbSdkException {
  const UnsupportedWalletFeatureException(
    super.message, {
    required this.feature,
  }) : super(code: 'UNSUPPORTED');

  final String feature;

  @override
  String toString() => 'UnsupportedWalletFeatureException($feature): $message';
}
