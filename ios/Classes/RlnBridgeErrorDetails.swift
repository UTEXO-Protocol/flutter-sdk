import Foundation

// Exhaustive against the pinned UniFFI enum. New native cases must be reviewed
// rather than silently losing their identity behind the enum's type name.
func rlnErrorCode(_ error: RlnError) -> String {
  switch error {
  case .NotInitialized: return "NotInitialized"
  case .InvalidRequest: return "InvalidRequest"
  case .NotFound: return "NotFound"
  case .Conflict: return "Conflict"
  case .FailedBitcoindConnection: return "FailedBitcoindConnection"
  case .FailedBdkSync: return "FailedBdkSync"
  case .FailedBroadcast: return "FailedBroadcast"
  case .FailedPeerConnection: return "FailedPeerConnection"
  case .InsufficientCapacity: return "InsufficientCapacity"
  case .InsufficientFunds: return "InsufficientFunds"
  case .NoAvailableUtxos: return "NoAvailableUtxos"
  case .NoRoute: return "NoRoute"
  case .ExternalSignerRequired: return "ExternalSignerRequired"
  case .ExternalSignerMismatch: return "ExternalSignerMismatch"
  case .ExternalSignerUnavailable: return "ExternalSignerUnavailable"
  case .ExternalSignerProtocolError: return "ExternalSignerProtocolError"
  case .UnsupportedInExternalSignerMode: return "UnsupportedInExternalSignerMode"
  case .FailedVssInit: return "FailedVssInit"
  case .Internal: return "Internal"
  }
}

func bridgeErrorDetails(
  _ operation: String,
  category: String,
  retryable: Bool,
  extra: [String: Any] = [:]
) -> [String: Any] {
  var details: [String: Any] = [
    "operation": operation,
    "category": category,
    "retryable": retryable,
  ]
  for (key, value) in extra {
    details[key] = value
  }
  return details
}

func nativeErrorCategory(_ code: String) -> String {
  switch code {
  case "NodeNotFound", "SignerNotFound", "NotFound",
    "RlnStoreError.nodeNotFound", "RlnStoreError.signerNotFound":
    return "notFound"
  case "Conflict", "AlreadyExists", "ResourceBusy":
    return "conflict"
  case "Network", "Transport", "Timeout", "FailedBitcoindConnection",
    "FailedBdkSync", "FailedBroadcast", "FailedPeerConnection", "NoRoute":
    return "network"
  case "Configuration", "RlnStorageDirectoryPolicyError", "NotInitialized",
    "ExternalSignerRequired", "ExternalSignerMismatch", "ExternalSignerUnavailable":
    return "configuration"
  case "InvalidArgument", "InvalidRequest", "BadRequest":
    return "invalidRequest"
  case "Unsupported", "UnsupportedOperation", "UnsupportedInExternalSignerMode":
    return "unsupported"
  default:
    return "native"
  }
}

func nativeErrorRetryable(_ category: String) -> Bool {
  category == "network" || category == "conflict"
}
