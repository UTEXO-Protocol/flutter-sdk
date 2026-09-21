import 'package:flutter/services.dart';

import 'rgb_sdk_exception.dart';

const _nativeErrorCodes = <String>{
  'RlnError',
  'NotInitialized',
  'InvalidRequest',
  'NotFound',
  'Conflict',
  'FailedBitcoindConnection',
  'FailedBdkSync',
  'FailedBroadcast',
  'FailedPeerConnection',
  'InsufficientCapacity',
  'InsufficientFunds',
  'NoAvailableUtxos',
  'NoRoute',
  'ExternalSignerRequired',
  'ExternalSignerMismatch',
  'ExternalSignerUnavailable',
  'ExternalSignerProtocolError',
  'UnsupportedInExternalSignerMode',
  'FailedVssInit',
  'Internal',
};

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
  final details = _NativeBridgeErrorDetails.parse(error.details);
  final category = details.category ?? _categoryFromExactNativeCode(code);
  // Native exception text/details are not a support-safe contract: RLN may
  // include request material, credentials, paths or invoices in either field.
  final message = 'Native wallet operation failed (${category.name}).';
  final retryable = details.retryable ?? _retryableFromCategory(category);
  final cause = NativeBridgeFailure(
    operation: operation,
    nativeCode:
        !_nativeErrorCodes.contains(code) &&
            _categoryFromExactNativeCode(code) ==
                NativeBridgeFailureCategory.native
        ? 'NativeError'
        : code,
    category: category,
    message: message,
    details: <String, Object?>{
      'operation': operation,
      'category': category.name,
      'retryable': retryable,
    },
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
        feature:
            const <String>{
              'sendRgb.skipSync',
              'rlnSendRgb.skipSync',
              'rlnBackup',
              'backup',
              'unlock.gossipRgsServerUrl',
            }.contains(details.feature)
            ? details.feature!
            : operation,
        cause: cause,
      );
    case NativeBridgeFailureCategory.native:
      return RgbNodeError(message, cause: cause);
  }
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
    case 'FailedPeerConnection':
    case 'FailedBitcoindConnection':
    case 'FailedBdkSync':
    case 'FailedBroadcast':
    case 'NoRoute':
      return NativeBridgeFailureCategory.network;
    case 'Configuration':
    case 'StorageDirectoryPolicy':
    case 'RlnStorageDirectoryPolicyError':
    case 'RlnStorageDirectoryPolicyException':
    case 'NotInitialized':
    case 'ExternalSignerRequired':
    case 'ExternalSignerMismatch':
    case 'ExternalSignerUnavailable':
      return NativeBridgeFailureCategory.configuration;
    case 'unsupported':
    case 'Unsupported':
    case 'UnsupportedOperation':
    case 'UnsupportedInExternalSignerMode':
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
