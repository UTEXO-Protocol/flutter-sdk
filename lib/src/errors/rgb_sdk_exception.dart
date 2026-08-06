/// Base exception type thrown by the Dart wallet facade.
class RgbSdkException implements Exception {
  const RgbSdkException(
    this.message, {
    required this.code,
    this.statusCode,
    this.cause,
  });

  final String message;
  final String code;
  final int? statusCode;
  final Object? cause;

  Map<String, Object?> toJson() {
    final cause = this.cause;
    return <String, Object?>{
      'name': runtimeType.toString(),
      'message': message,
      'code': code,
      'statusCode': statusCode,
      if (cause != null) 'cause': cause.toString(),
    };
  }

  @override
  String toString() {
    final statusCode = this.statusCode;
    final status = statusCode == null ? '' : ', statusCode: $statusCode';
    return '${runtimeType.toString()}($code$status): $message';
  }
}

/// RN-core compatible base error name.
class SDKError extends RgbSdkException {
  const SDKError(
    super.message, {
    super.code = 'SDK_ERROR',
    super.statusCode,
    super.cause,
  });
}

/// General wallet lifecycle or native-response error.
class WalletException extends SDKError {
  const WalletException(super.message, {super.statusCode, super.cause})
    : super(code: 'WALLET_ERROR');
}

/// Native response violated the SDK's wire contract.
class NativeProtocolException extends SDKError {
  const NativeProtocolException(
    super.message, {
    this.field,
    super.statusCode,
    super.cause,
  }) : super(code: 'NATIVE_PROTOCOL_ERROR');

  final String? field;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    if (field != null) 'field': field,
  };

  @override
  String toString() {
    final field = this.field;
    if (field == null) return 'NativeProtocolException: $message';
    return 'NativeProtocolException($field): $message';
  }
}

/// RN-core compatible wallet error name.
class WalletError extends WalletException {
  const WalletError(super.message, {super.statusCode, super.cause});
}

/// A Dart-side deadline elapsed before a native RLN operation returned.
///
/// Pigeon and the pinned native RLN artifacts do not expose true cancellation
/// once a call has entered native code. The binding therefore quarantines the
/// node after this error and keeps its internal queue blocked until native
/// completion, so follow-up cleanup can run in order.
class RlnOperationTimeoutException extends WalletException {
  const RlnOperationTimeoutException({
    required this.operation,
    required this.timeout,
  }) : super('Native RLN operation timed out.', cause: operation);

  final String operation;
  final Duration timeout;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'operation': operation,
    'timeoutMs': timeout.inMilliseconds,
  };

  @override
  String toString() =>
      'RlnOperationTimeoutException($operation, ${timeout.inMilliseconds}ms)';
}

/// Input validation failure before a native call is made.
class WalletValidationException extends SDKError {
  const WalletValidationException(super.message, {required this.field})
    : super(code: 'VALIDATION_ERROR');

  final String field;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'field': field,
  };

  @override
  String toString() => 'WalletValidationException($field): $message';
}

/// RN-core compatible validation error name.
class ValidationError extends WalletValidationException {
  const ValidationError(super.message, String field) : super(field: field);
}

/// RN-core compatible crypto error name.
class CryptoError extends RgbSdkException {
  const CryptoError(super.message, {super.statusCode, super.cause})
    : super(code: 'CRYPTO_ERROR');
}

/// Private-key signing path that is intentionally not production enabled.
class ExperimentalCryptoException extends CryptoError {
  const ExperimentalCryptoException(super.message, {required this.primitive})
    : super(cause: primitive);

  final String primitive;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'primitive': primitive,
  };
}

/// RN-core compatible network error name.
class NetworkError extends RgbSdkException {
  const NetworkError(super.message, {super.statusCode, super.cause})
    : super(code: 'NETWORK_ERROR');
}

/// Caller-requested cancellation before an SDK operation completed.
class OperationCancelledError extends RgbSdkException {
  const OperationCancelledError(super.message, {super.cause})
    : super(code: 'CANCELLED');
}

/// RN-core compatible configuration error name.
class ConfigurationError extends RgbSdkException {
  const ConfigurationError(super.message, {super.statusCode, super.cause})
    : super(code: 'CONFIGURATION_ERROR');
}

/// RN-core compatible bad request error name.
class BadRequestError extends RgbSdkException {
  const BadRequestError(super.message, {super.statusCode, super.cause})
    : super(code: 'BAD_REQUEST');
}

/// RN-core compatible not found error name.
class NotFoundError extends RgbSdkException {
  const NotFoundError(super.message, {super.statusCode, super.cause})
    : super(code: 'NOT_FOUND');
}

/// RN-core compatible conflict error name.
class ConflictError extends RgbSdkException {
  const ConflictError(super.message, {super.statusCode, super.cause})
    : super(code: 'CONFLICT');
}

/// RN-core compatible RGB node error name.
class RgbNodeError extends RgbSdkException {
  const RgbNodeError(super.message, {super.statusCode, super.cause})
    : super(code: 'RGB_NODE_ERROR');
}

/// Feature that exists for parity but is intentionally unavailable.
class UnsupportedWalletFeatureException extends SDKError {
  const UnsupportedWalletFeatureException(
    super.message, {
    required this.feature,
    super.cause,
  }) : super(code: 'UNSUPPORTED');

  final String feature;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'feature': feature,
  };

  @override
  String toString() => 'UnsupportedWalletFeatureException($feature): $message';
}
