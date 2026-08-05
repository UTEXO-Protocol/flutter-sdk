import 'package:flutter/services.dart';

import 'rgb_sdk_exception.dart';

/// Structured cause attached to SDK exceptions created from native bridge
/// failures.
class NativeBridgeFailure {
  const NativeBridgeFailure({
    required this.operation,
    required this.nativeCode,
    required this.message,
    required this.details,
    required this.retryable,
  });

  final String operation;
  final String nativeCode;
  final String message;
  final Object? details;
  final bool retryable;

  @override
  String toString() {
    return 'NativeBridgeFailure($operation, $nativeCode, retryable: $retryable): $message';
  }
}

RgbSdkException mapNativeBridgeException(
  PlatformException error, {
  required String operation,
}) {
  final code = error.code.trim().isEmpty ? 'PlatformException' : error.code;
  final message = _nativeMessage(error, operation);
  final retryable = _isRetryable(code, message);
  final cause = NativeBridgeFailure(
    operation: operation,
    nativeCode: code,
    message: message,
    details: error.details,
    retryable: retryable,
  );
  final normalized = code.toLowerCase();
  final lowerMessage = message.toLowerCase();

  if (_containsAny(normalized, const ['invalid', 'badrequest']) ||
      _containsAny(lowerMessage, const [
        'invalidrequest',
        'invalid request',
        'badrequest',
        'bad request',
      ])) {
    return BadRequestError(message, cause: cause);
  }
  if (_containsAny(normalized, const ['notfound', 'not_found']) ||
      _containsAny(lowerMessage, const ['not found', 'missing'])) {
    return NotFoundError(message, cause: cause);
  }
  if (_containsAny(normalized, const ['conflict', 'alreadyexists']) ||
      _containsAny(lowerMessage, const ['conflict', 'already', 'in use'])) {
    return ConflictError(message, cause: cause);
  }
  if (_containsAny(normalized, const ['network', 'transport', 'timeout']) ||
      _containsAny(lowerMessage, const ['network', 'timeout', 'connection'])) {
    return NetworkError(message, cause: cause);
  }
  if (_containsAny(normalized, const ['config', 'configuration'])) {
    return ConfigurationError(message, cause: cause);
  }

  return RgbNodeError(message, cause: cause);
}

String _nativeMessage(PlatformException error, String operation) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) return message;
  return 'Native bridge operation $operation failed with ${error.code}.';
}

bool _containsAny(String value, List<String> needles) {
  return needles.any(value.contains);
}

bool _isRetryable(String code, String message) {
  final value = '${code.toLowerCase()} ${message.toLowerCase()}';
  return _containsAny(value, const [
    'timeout',
    'temporar',
    'busy',
    'network',
    'connection',
    'unavailable',
  ]);
}
