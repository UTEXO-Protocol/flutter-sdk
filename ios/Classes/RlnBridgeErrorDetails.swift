import Foundation

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
  case "Network", "Transport", "Timeout":
    return "network"
  case "Configuration", "RlnStorageDirectoryPolicyError":
    return "configuration"
  case "InvalidArgument", "InvalidRequest", "BadRequest":
    return "invalidRequest"
  case "Unsupported", "UnsupportedOperation":
    return "unsupported"
  default:
    return "native"
  }
}

func nativeErrorRetryable(_ category: String) -> Bool {
  category == "network" || category == "conflict"
}
