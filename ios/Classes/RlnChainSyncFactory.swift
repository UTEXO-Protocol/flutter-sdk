import Foundation

enum RlnChainSyncConfigurationError: Error {
  case invalid(field: String, message: String)
}

enum RlnChainSyncFactory {
  static func make(
    bitcoindRpcUsername: String?,
    bitcoindRpcPassword: String?,
    bitcoindRpcHost: String?,
    bitcoindRpcPort: Int64?,
    indexerUrl: String?
  ) throws -> SdkLdkChainSync {
    let rpcValues: [Any?] = [
      bitcoindRpcUsername,
      bitcoindRpcPassword,
      bitcoindRpcHost,
      bitcoindRpcPort,
    ]
    let rpcValueCount = rpcValues.compactMap { $0 }.count
    if (1...3).contains(rpcValueCount) {
      throw RlnChainSyncConfigurationError.invalid(
        field: "bitcoindRpc",
        message: "Provide all bitcoind RPC parameters or none of them."
      )
    }
    if rpcValueCount == 4 {
      guard let username = bitcoindRpcUsername,
            let password = bitcoindRpcPassword,
            let host = bitcoindRpcHost,
            let port = bitcoindRpcPort,
            (1...Int64(UInt16.max)).contains(port)
      else {
        throw RlnChainSyncConfigurationError.invalid(
          field: "bitcoindRpcPort",
          message: "bitcoindRpcPort must be between 1 and 65535."
        )
      }
      return .blockSync(
        bitcoindRpcUsername: username,
        bitcoindRpcPassword: password,
        bitcoindRpcHost: host,
        bitcoindRpcPort: UInt16(port)
      )
    }

    guard let transactionSyncUrl = indexerUrl, !transactionSyncUrl.isEmpty else {
      throw RlnChainSyncConfigurationError.invalid(
        field: "indexerUrl",
        message: "Provide indexerUrl or complete bitcoind RPC parameters."
      )
    }
    return .transactionSync(indexerUrl: transactionSyncUrl)
  }
}
