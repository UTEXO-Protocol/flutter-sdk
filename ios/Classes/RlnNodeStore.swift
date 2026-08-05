import Foundation

final class RlnNodeStore {
  static let shared = RlnNodeStore()

  enum NodeLifecycleState {
    case created
    case initialized
    case unlocking
    case unlocked
    case shutdown
  }

  private var nodes: [Int64: SdkNode] = [:]
  private var states: [Int64: NodeLifecycleState] = [:]
  private var preUnlockStates: [Int64: NodeLifecycleState] = [:]
  private var storageDirByNodeId: [Int64: String] = [:]
  private var nextId: Int64 = 1
  private var signers: [Int64: NativeExternalSigner] = [:]
  private var nextSignerId: Int64 = 1
  private let queue = DispatchQueue(label: "com.utexo.rgb_sdk_flutter.rln-node-store")

  private init() {}

  func create(node: SdkNode, storageDirPath: String) throws -> Int64 {
    try queue.sync {
      let normalizedPath = storageDirPath.trimmingCharacters(in: .whitespacesAndNewlines)
      if !normalizedPath.isEmpty,
         let existingId = storageDirByNodeId.first(where: { $0.value == normalizedPath })?.key {
        if states[existingId] == .shutdown {
          nodes[existingId]?.shutdown()
          nodes[existingId] = node
          states[existingId] = .created
          return existingId
        }

        throw RlnStoreError.nodeAlreadyExists(storageDirPath: normalizedPath)
      }

      let id = nextId
      nextId += 1
      nodes[id] = node
      states[id] = .created
      storageDirByNodeId[id] = normalizedPath
      return id
    }
  }

  func get(id: Int64) throws -> SdkNode {
    try queue.sync {
      guard let node = nodes[id] else {
        throw RlnStoreError.nodeNotFound(id: id)
      }
      return node
    }
  }

  func getState(id: Int64) throws -> NodeLifecycleState {
    try queue.sync {
      guard let state = states[id] else {
        throw RlnStoreError.nodeNotFound(id: id)
      }
      return state
    }
  }

  func markInitialized(id: Int64) throws {
    try queue.sync {
      guard let state = states[id] else {
        throw RlnStoreError.nodeNotFound(id: id)
      }

      switch state {
      case .created:
        states[id] = .initialized
      case .initialized, .unlocked, .shutdown:
        break
      case .unlocking:
        throw RlnStoreError.invalidState("Cannot initialize RLN node while unlock is in progress")
      }
    }
  }

  func beginUnlock(id: Int64) throws -> NodeLifecycleState {
    try queue.sync {
      guard let state = states[id] else {
        throw RlnStoreError.nodeNotFound(id: id)
      }

      switch state {
      case .created, .initialized, .shutdown:
        preUnlockStates[id] = state
        states[id] = .unlocking
        return .unlocking
      case .unlocked:
        return .unlocked
      case .unlocking:
        throw RlnStoreError.invalidState("RLN unlock is already in progress")
      }
    }
  }

  func markUnlocked(id: Int64) {
    queue.sync {
      if states[id] != nil {
        states[id] = .unlocked
        preUnlockStates.removeValue(forKey: id)
      }
    }
  }

  func markShutdown(id: Int64) {
    queue.sync {
      if states[id] != nil {
        states[id] = .shutdown
      }
    }
  }

  func rollbackUnlock(id: Int64) {
    queue.sync {
      if states[id] == .unlocking {
        states[id] = preUnlockStates.removeValue(forKey: id) ?? .initialized
      }
    }
  }

  func remove(id: Int64) {
    queue.sync {
      if let node = nodes.removeValue(forKey: id), states[id] != .shutdown {
        node.shutdown()
      }
      states.removeValue(forKey: id)
      preUnlockStates.removeValue(forKey: id)
      storageDirByNodeId.removeValue(forKey: id)
    }
  }

  func createSigner(_ signer: NativeExternalSigner) -> Int64 {
    queue.sync {
      let id = nextSignerId
      nextSignerId += 1
      signers[id] = signer
      return id
    }
  }

  func getSigner(id: Int64) throws -> NativeExternalSigner {
    try queue.sync {
      guard let signer = signers[id] else {
        throw RlnStoreError.signerNotFound(id: id)
      }
      return signer
    }
  }

  func removeSigner(id: Int64) {
    queue.sync {
      signers.removeValue(forKey: id)
    }
  }

  func clearAll() {
    queue.sync {
      nodes.values.forEach { $0.shutdown() }
      nodes.removeAll()
      states.removeAll()
      preUnlockStates.removeAll()
      storageDirByNodeId.removeAll()
      signers.removeAll()
    }
  }
}

enum RlnStoreError: Error, LocalizedError {
  case nodeAlreadyExists(storageDirPath: String)
  case nodeNotFound(id: Int64)
  case signerNotFound(id: Int64)
  case invalidState(String)

  var errorDescription: String? {
    switch self {
    case .nodeAlreadyExists(let storageDirPath):
      return "RLN node already exists for storageDirPath: \(storageDirPath)"
    case .nodeNotFound(let id):
      return "RLN node with id \(id) not found"
    case .signerNotFound(let id):
      return "Native signer with id \(id) not found"
    case .invalidState(let message):
      return message
    }
  }
}
