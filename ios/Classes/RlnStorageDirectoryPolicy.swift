import Darwin
import Foundation

struct RlnStorageDirectoryPolicyError: LocalizedError {
  let message: String

  var errorDescription: String? {
    message
  }
}

enum RlnStorageDirectoryPolicy {
  private static let ownerOnlyPermissions = 0o700

  static func prepare(_ path: String) throws {
    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw policyError("storageDirPath must not be empty.")
    }
    guard (path as NSString).isAbsolutePath else {
      throw policyError("storageDirPath must be an absolute path.")
    }
    guard !(path as NSString).pathComponents.contains(where: { $0 == "." || $0 == ".." }) else {
      throw policyError("storageDirPath must not contain '.' or '..' components.")
    }

    do {
      try FileManager.default.createDirectory(
        atPath: path,
        withIntermediateDirectories: true,
        attributes: [
          .posixPermissions: NSNumber(value: ownerOnlyPermissions)
        ]
      )
    } catch {
      throw policyError("storageDirPath could not be created: \(error.localizedDescription)")
    }

    try verify(path)
  }

  private static func verify(_ path: String) throws {
    var metadata = stat()
    guard lstat(path, &metadata) == 0 else {
      throw policyError(
        "storageDirPath could not be inspected: \(String(cString: strerror(errno)))."
      )
    }

    guard (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else {
      throw policyError("storageDirPath must identify a directory, not a file or symbolic link.")
    }

    let effectiveUserId = geteuid()
    guard metadata.st_uid == effectiveUserId else {
      throw policyError(
        "storageDirPath must be owned by the current process user; "
          + "found uid \(metadata.st_uid), expected \(effectiveUserId)."
      )
    }

    let permissions = metadata.st_mode & mode_t(0o777)
    guard permissions == mode_t(ownerOnlyPermissions) else {
      throw policyError(
        "storageDirPath must have mode 0700; "
          + "found mode \(String(permissions, radix: 8))."
      )
    }
  }

  private static func policyError(_ message: String) -> RlnStorageDirectoryPolicyError {
    RlnStorageDirectoryPolicyError(message: message)
  }
}
