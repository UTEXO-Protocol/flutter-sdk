import 'package:flutter/services.dart';

import 'rgb_sdk_exception.dart';

/// Structured cause attached to SDK exceptions created from native bridge
/// failures.
class NativeBridgeFailure {
  const NativeBridgeFailure({
    required this.operation,
    required this.nativeCode,
    required this.category,
    required this.message,
    required this.details,
    required this.retryable,
    required this.structured,
  });

  final String operation;
  final String nativeCode;
  final NativeBridgeFailureCategory category;
  final String message;
  final Object? details;
  final bool retryable;
  final bool structured;

  @override
  String toString() {
    return 'NativeBridgeFailure('
        '$operation, $nativeCode, $category, retryable: $retryable'
        '): $message';
  }
}

enum NativeBridgeFailureCategory {
  invalidRequest,
  notFound,
  conflict,
  network,
  configuration,
  unsupported,
  native,
}

RgbSdkException mapNativeBridgeException(
  PlatformException error, {
  required String operation,
}) {
  final code = error.code.trim().isEmpty ? 'PlatformException' : error.code;
  final message = _nativeMessage(error, operation);
  final details = _NativeBridgeErrorDetails.parse(error.details);
  final category = details.category ?? _categoryFromExactNativeCode(code);
  final retryable = details.retryable ?? _retryableFromCategory(category);
  final cause = NativeBridgeFailure(
    operation: operation,
    nativeCode: code,
    category: category,
    message: message,
    details: error.details,
    retryable: retryable,
    structured: details.category != null,
  );

  switch (category) {
    case NativeBridgeFailureCategory.invalidRequest:
      return BadRequestError(message, cause: cause);
    case NativeBridgeFailureCategory.notFound:
      return NotFoundError(message, cause: cause);
    case NativeBridgeFailureCategory.conflict:
      return ConflictError(message, cause: cause);
    case NativeBridgeFailureCategory.network:
      return NetworkError(message, cause: cause);
    case NativeBridgeFailureCategory.configuration:
      return ConfigurationError(message, cause: cause);
    case NativeBridgeFailureCategory.unsupported:
      return UnsupportedWalletFeatureException(
        message,
        feature: details.feature ?? operation,
        cause: cause,
      );
    case NativeBridgeFailureCategory.native:
      return RgbNodeError(message, cause: cause);
  }
}

String _nativeMessage(PlatformException error, String operation) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) return message;
  return 'Native bridge operation $operation failed with ${error.code}.';
}

NativeBridgeFailureCategory _categoryFromExactNativeCode(String code) {
  switch (code) {
    case 'invalidArgument':
    case 'InvalidArgument':
    case 'InvalidRequest':
    case 'BadRequest':
      return NativeBridgeFailureCategory.invalidRequest;
    case 'NodeNotFound':
    case 'SignerNotFound':
    case 'NotFound':
    case 'RlnStoreError.nodeNotFound':
    case 'RlnStoreError.signerNotFound':
      return NativeBridgeFailureCategory.notFound;
    case 'Conflict':
    case 'AlreadyExists':
    case 'ResourceBusy':
      return NativeBridgeFailureCategory.conflict;
    case 'Network':
    case 'Transport':
    case 'Timeout':
      return NativeBridgeFailureCategory.network;
    case 'Configuration':
    case 'StorageDirectoryPolicy':
    case 'RlnStorageDirectoryPolicyError':
    case 'RlnStorageDirectoryPolicyException':
      return NativeBridgeFailureCategory.configuration;
    case 'unsupported':
    case 'Unsupported':
    case 'UnsupportedOperation':
      return NativeBridgeFailureCategory.unsupported;
    default:
      return NativeBridgeFailureCategory.native;
  }
}

bool _retryableFromCategory(NativeBridgeFailureCategory category) {
  return category == NativeBridgeFailureCategory.network ||
      category == NativeBridgeFailureCategory.conflict;
}

class _NativeBridgeErrorDetails {
  const _NativeBridgeErrorDetails({
    required this.category,
    required this.retryable,
    required this.feature,
  });

  final NativeBridgeFailureCategory? category;
  final bool? retryable;
  final String? feature;

  static _NativeBridgeErrorDetails parse(Object? details) {
    if (details is! Map) {
      return const _NativeBridgeErrorDetails(
        category: null,
        retryable: null,
        feature: null,
      );
    }
    return _NativeBridgeErrorDetails(
      category: _parseCategory(details['category']),
      retryable: details['retryable'] is bool
          ? details['retryable'] as bool
          : null,
      feature: details['feature'] is String
          ? details['feature'] as String
          : null,
    );
  }

  static NativeBridgeFailureCategory? _parseCategory(Object? value) {
    if (value is! String) return null;
    switch (value) {
      case 'invalidRequest':
        return NativeBridgeFailureCategory.invalidRequest;
      case 'notFound':
        return NativeBridgeFailureCategory.notFound;
      case 'conflict':
        return NativeBridgeFailureCategory.conflict;
      case 'network':
        return NativeBridgeFailureCategory.network;
      case 'configuration':
        return NativeBridgeFailureCategory.configuration;
      case 'unsupported':
        return NativeBridgeFailureCategory.unsupported;
      case 'native':
        return NativeBridgeFailureCategory.native;
      default:
        return null;
    }
  }
}
