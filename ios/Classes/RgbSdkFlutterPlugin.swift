import Flutter
import UIKit

public class RgbSdkFlutterPlugin: NSObject, FlutterPlugin, RlnHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RgbSdkFlutterPlugin()
    RlnHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    RlnHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    RlnNodeStore.shared.clearAll()
  }

  func getNativeArtifactInfo() throws -> RlnNativeArtifactInfo {
    RlnNativeArtifactInfo(
      platform: "ios",
      rlnVersion: ReleaseBaseline.rlnVersion,
      reactNativeParityVersion: ReleaseBaseline.reactNativeVersion,
      bridge: "pigeon-bootstrap",
      nativeArtifact: "rgb-lightning-node-swift-\(ReleaseBaseline.rlnVersion).zip"
    )
  }

  private func unsupported<T>(_ operation: String) throws -> T {
    throw PigeonError(
      code: "unsupported",
      message: "\(operation) is not implemented yet.",
      details: ["operation": operation, "phase": "rln-parity"]
    )
  }

  private func unsupportedVoid(_ operation: String) throws {
    throw PigeonError(
      code: "unsupported",
      message: "\(operation) is not implemented yet.",
      details: ["operation": operation, "phase": "rln-parity"]
    )
  }

  private func runRln<T>(_ operation: String, _ block: () throws -> T) throws -> T {
    do {
      return try block()
    } catch let error as PigeonError {
      throw error
    } catch {
      throw bridgeError(error, operation: operation)
    }
  }

  private func runRlnWire<T>(
    _ operation: String,
    _ block: () throws -> T
  ) throws -> RlnWireResponse {
    try wireResponse(runRln(operation, block))
  }

  private func runRlnWireList<T>(
    _ operation: String,
    _ block: () throws -> [T]
  ) throws -> [RlnWireResponse] {
    try runRln(operation, block).map(wireResponse)
  }

  private func wireResponse(_ value: Any?) throws -> RlnWireResponse {
    let jsonValue = try jsonCompatibleValue(value)
    let data = try JSONSerialization.data(withJSONObject: jsonValue, options: [.sortedKeys])
    guard let json = String(data: data, encoding: .utf8) else {
      throw PigeonError(
        code: "nativeProtocol",
        message: "Native response JSON was not valid UTF-8.",
        details: nil
      )
    }
    return RlnWireResponse(json: json)
  }

  private func jsonCompatibleValue(_ value: Any?) throws -> Any {
    guard let value else {
      return NSNull()
    }
    switch value {
    case let value as [AnyHashable?: Any?]:
      var object = [String: Any]()
      for (key, entryValue) in value {
        let keyString = key.map { String(describing: $0) } ?? "null"
        object[keyString] = try jsonCompatibleValue(entryValue ?? nil)
      }
      return object
    case let value as [String: Any?]:
      var object = [String: Any]()
      for (key, entryValue) in value {
        object[key] = try jsonCompatibleValue(entryValue ?? nil)
      }
      return object
    case let value as [Any?]:
      return try value.map { try jsonCompatibleValue($0) }
    case let value as Bool:
      return value
    case let value as String:
      return value
    case let value as UInt64:
      return value <= UInt64(Int64.max) ? NSNumber(value: value) : String(value)
    case let value as UInt32:
      return NSNumber(value: value)
    case let value as UInt16:
      return NSNumber(value: value)
    case let value as UInt8:
      return NSNumber(value: value)
    case let value as Int64:
      return NSNumber(value: value)
    case let value as Int32:
      return NSNumber(value: value)
    case let value as Int:
      return NSNumber(value: value)
    case let value as Double:
      return NSNumber(value: value)
    case let value as Float:
      return NSNumber(value: value)
    case let value as NSNumber:
      return value
    default:
      return String(describing: value)
    }
  }

  private func bridgeError(_ error: Error, operation: String) -> PigeonError {
    if let pigeonError = error as? PigeonError {
      return pigeonError
    }
    return PigeonError(
      code: errorClassName(error),
      message: errorMessage(error),
      details: ["operation": operation]
    )
  }

  private func invalidArgument(_ operation: String, field: String, message: String) -> PigeonError {
    return PigeonError(
      code: "invalidArgument",
      message: message,
      details: ["operation": operation, "field": field]
    )
  }

  private func prepareStorageDirectory(_ path: String, operation: String) throws {
    do {
      try RlnStorageDirectoryPolicy.prepare(path)
    } catch let error as RlnStorageDirectoryPolicyError {
      throw invalidArgument(
        operation,
        field: "storageDirPath",
        message: error.localizedDescription
      )
    }
  }

  private func requireUInt64(_ value: Int64, field: String, operation: String) throws -> UInt64 {
    guard value >= 0 else {
      throw invalidArgument(operation, field: field, message: "\(field) must be non-negative.")
    }
    return UInt64(value)
  }

  private func optionalUInt64(_ value: Int64?, field: String, operation: String) throws -> UInt64? {
    guard let value else {
      return nil
    }
    return try requireUInt64(value, field: field, operation: operation)
  }

  private func requireUInt32(_ value: Int64, field: String, operation: String) throws -> UInt32 {
    guard value >= 0, value <= Int64(UInt32.max) else {
      throw invalidArgument(operation, field: field, message: "\(field) must fit in UInt32.")
    }
    return UInt32(value)
  }

  private func optionalUInt32(_ value: Int64?, field: String, operation: String) throws -> UInt32? {
    guard let value else {
      return nil
    }
    return try requireUInt32(value, field: field, operation: operation)
  }

  private func requireUInt16(_ value: Int64, field: String, operation: String) throws -> UInt16 {
    guard value >= 0, value <= Int64(UInt16.max) else {
      throw invalidArgument(operation, field: field, message: "\(field) must fit in UInt16.")
    }
    return UInt16(value)
  }

  private func optionalUInt16(_ value: Int64?, field: String, operation: String) throws -> UInt16? {
    guard let value else {
      return nil
    }
    return try requireUInt16(value, field: field, operation: operation)
  }

  private func requireUInt8(_ value: Int64, field: String, operation: String) throws -> UInt8 {
    guard value >= 0, value <= Int64(UInt8.max) else {
      throw invalidArgument(operation, field: field, message: "\(field) must fit in UInt8.")
    }
    return UInt8(value)
  }

  private func optionalUInt8(_ value: Int64?, field: String, operation: String) throws -> UInt8? {
    guard let value else {
      return nil
    }
    return try requireUInt8(value, field: field, operation: operation)
  }

  private func requireInt32(_ value: Int64, field: String, operation: String) throws -> Int32 {
    guard value >= Int64(Int32.min), value <= Int64(Int32.max) else {
      throw invalidArgument(operation, field: field, message: "\(field) must fit in Int32.")
    }
    return Int32(value)
  }

  private func optionalInt32(_ value: Int64?, field: String, operation: String) throws -> Int32? {
    guard let value else {
      return nil
    }
    return try requireInt32(value, field: field, operation: operation)
  }

  private func requireFeeRate(_ value: Double, field: String, operation: String) throws -> UInt64 {
    guard value.isFinite, value >= 0, value <= Double(UInt64.max), value.rounded(.towardZero) == value else {
      throw invalidArgument(operation, field: field, message: "\(field) must be a finite non-negative integer fee rate.")
    }
    return UInt64(value.rounded(.towardZero))
  }

  private func requireUInt64List(_ values: [Int64], field: String, operation: String) throws -> [UInt64] {
    try values.enumerated().map { index, value in
      try requireUInt64(value, field: "\(field)[\(index)]", operation: operation)
    }
  }

  private func pigeonInteger(_ value: UInt64) -> Any {
    if value <= UInt64(Int64.max) {
      return Int64(value)
    }
    return String(value)
  }

  private func pigeonInteger(_ value: UInt32) -> Int64 {
    Int64(value)
  }

  private func pigeonInteger(_ value: UInt16) -> Int64 {
    Int64(value)
  }

  private func pigeonInteger(_ value: UInt8) -> Int64 {
    Int64(value)
  }

  private func pigeonInteger(_ value: UInt) -> Any {
    if value <= UInt(Int64.max) {
      return Int64(value)
    }
    return String(value)
  }

  private func errorClassName(_ error: Error) -> String {
    let errorType = String(describing: type(of: error))
    if let dotIndex = errorType.lastIndex(of: ".") {
      return String(errorType[errorType.index(after: dotIndex)...])
    }
    return errorType
  }

  private func errorMessage(_ error: Error) -> String {
    if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
      return localized
    }

    let errorString = String(describing: error)
    if let detailsRange = errorString.range(of: "details: \"") {
      let afterDetails = String(errorString[detailsRange.upperBound...])
      if let endQuote = afterDetails.firstIndex(of: "\"") {
        return String(afterDetails[..<endQuote])
      }
    }

    return error.localizedDescription
  }

  private func isNodeReady(_ node: SdkNode) -> Bool {
    do {
      return try !node.nodeInfo().pubkey.isEmpty
    } catch {
      return false
    }
  }

  private func btcBalanceMap(_ balance: BtcBalance) -> [String: Any] {
    [
      "settled": pigeonInteger(balance.settled),
      "future": pigeonInteger(balance.future),
      "spendable": pigeonInteger(balance.spendable),
    ]
  }

  private func assetBalanceMap(_ balance: AssetBalanceInfo) -> [String: Any] {
    [
      "settled": pigeonInteger(balance.settled),
      "future": pigeonInteger(balance.future),
      "spendable": pigeonInteger(balance.spendable),
      "offchainOutbound": pigeonInteger(balance.offchainOutbound),
      "offchainInbound": pigeonInteger(balance.offchainInbound),
    ]
  }

  private func mediaMap(_ media: Media?) -> [String: Any]? {
    guard let media else {
      return nil
    }
    return [
      "filePath": media.filePath,
      "digest": media.digest,
      "mime": media.mime,
    ]
  }

  private func mediaAttachmentMap(_ attachment: MediaAttachment) -> [String: Any?] {
    [
      "key": Int64(attachment.key),
      "media": mediaMap(attachment.media),
    ]
  }

  private func tokenLightMap(_ token: TokenLight?) -> [String: Any?]? {
    guard let token else {
      return nil
    }
    return [
      "index": Int64(token.index),
      "ticker": token.ticker,
      "name": token.name,
      "details": token.details,
      "embeddedMedia": token.embeddedMedia,
      "media": mediaMap(token.media),
      "attachments": token.attachments.map(mediaAttachmentMap),
      "reserves": token.reserves,
    ]
  }

  private func assetNiaMap(_ asset: AssetNia) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "ticker": asset.ticker,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "issuedSupply": String(asset.issuedSupply),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "media": mediaMap(asset.media),
    ]
  }

  private func assetCfaMap(_ asset: AssetCfa) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "issuedSupply": String(asset.issuedSupply),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "media": mediaMap(asset.media),
    ]
  }

  private func assetIfaMap(_ asset: AssetIfa) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "ticker": asset.ticker,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "initialSupply": String(asset.initialSupply),
      "maxSupply": String(asset.maxSupply),
      "knownCirculatingSupply": String(asset.knownCirculatingSupply),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "media": mediaMap(asset.media),
      "rejectListUrl": asset.rejectListUrl,
    ]
  }

  private func assetUdaMap(_ asset: AssetUda) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "ticker": asset.ticker,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "token": tokenLightMap(asset.token),
    ]
  }

  private func listAssetsMap(_ assets: ListAssetsResponse) -> [String: Any] {
    [
      "nia": (assets.nia ?? []).map(assetNiaMap),
      "uda": (assets.uda ?? []).map(assetUdaMap),
      "cfa": (assets.cfa ?? []).map(assetCfaMap),
      "ifa": (assets.ifa ?? []).map(assetIfaMap),
    ]
  }

  private func channelMap(_ channel: Channel) -> [String: Any?] {
    [
      "channelId": channel.channelId,
      "peerPubkey": channel.peerPubkey,
      "status": String(describing: channel.status),
      "ready": channel.ready,
      "capacitySat": pigeonInteger(channel.capacitySat),
      "localBalanceSat": pigeonInteger(channel.localBalanceSat),
      "outboundBalanceMsat": pigeonInteger(channel.outboundBalanceMsat),
      "inboundBalanceMsat": pigeonInteger(channel.inboundBalanceMsat),
      "nextOutboundHtlcLimitMsat": pigeonInteger(channel.nextOutboundHtlcLimitMsat),
      "nextOutboundHtlcMinimumMsat": pigeonInteger(channel.nextOutboundHtlcMinimumMsat),
      "isUsable": channel.isUsable,
      "public": channel.public,
      "fundingTxid": channel.fundingTxid,
      "peerAlias": channel.peerAlias,
      "shortChannelId": channel.shortChannelId.map(String.init),
      "assetId": channel.assetId,
      "assetLocalAmount": channel.assetLocalAmount.map(String.init),
      "assetRemoteAmount": channel.assetRemoteAmount.map(String.init),
      "virtualOpenMode": channel.virtualOpenMode,
    ]
  }

  private func paymentMap(_ payment: Payment) -> [String: Any?] {
    [
      "amtMsat": payment.amtMsat.map(String.init),
      "assetAmount": payment.assetAmount.map(String.init),
      "assetId": payment.assetId,
      "paymentHash": payment.paymentHash,
      "paymentType": String(describing: payment.paymentType),
      "status": String(describing: payment.status),
      "createdAt": pigeonInteger(payment.createdAt),
      "updatedAt": pigeonInteger(payment.updatedAt),
      "payeePubkey": payment.payeePubkey,
      "preimage": payment.preimage,
    ]
  }

  private func rgbAllocationMap(_ allocation: RgbAllocation) -> [String: Any?] {
    [
      "assetId": allocation.assetId,
      "assignment": allocation.assignment,
      "settled": allocation.settled,
    ]
  }

  private func blockTimeMap(_ blockTime: BlockTime?) -> [String: Any]? {
    guard let blockTime else {
      return nil
    }
    return [
      "height": Int64(blockTime.height),
      "timestamp": pigeonInteger(blockTime.timestamp),
    ]
  }

  private func transactionMap(_ transaction: Transaction) -> [String: Any?] {
    [
      "transactionType": String(describing: transaction.transactionType),
      "txid": transaction.txid,
      "received": pigeonInteger(transaction.received),
      "sent": pigeonInteger(transaction.sent),
      "fee": pigeonInteger(transaction.fee),
      "confirmationTime": blockTimeMap(transaction.confirmationTime),
    ]
  }

  private func unspentMap(_ unspent: Unspent) -> [String: Any?] {
    [
      "utxo": [
        "outpoint": unspent.utxo.outpoint,
        "btcAmount": pigeonInteger(unspent.utxo.btcAmount),
        "colorable": unspent.utxo.colorable,
      ],
      "rgbAllocations": unspent.rgbAllocations.map(rgbAllocationMap),
    ]
  }

  private func decodeRgbInvoiceMap(_ invoice: DecodeRgbInvoiceResponse) -> [String: Any?] {
    [
      "recipientId": invoice.recipientId,
      "recipientType": invoice.recipientType,
      "assetSchema": invoice.assetSchema,
      "assetId": invoice.assetId,
      "assignment": invoice.assignment,
      "network": invoice.network,
      "expirationTimestamp": invoice.expirationTimestamp,
      "transportEndpoints": invoice.transportEndpoints,
    ]
  }

  private func transferTransportEndpointMap(_ endpoint: TransferTransportEndpoint) -> [String: Any] {
    [
      "endpoint": endpoint.endpoint,
      "transportType": endpoint.transportType,
      "used": endpoint.used,
    ]
  }

  private func transferMap(_ transfer: Transfer) -> [String: Any?] {
    [
      "idx": Int64(transfer.idx),
      "createdAt": transfer.createdAt,
      "updatedAt": transfer.updatedAt,
      "status": transfer.status,
      "requestedAssignment": transfer.requestedAssignment,
      "assignments": transfer.assignments,
      "kind": transfer.kind,
      "txid": transfer.txid,
      "recipientId": transfer.recipientId,
      "receiveUtxo": transfer.receiveUtxo,
      "changeUtxo": transfer.changeUtxo,
      "expiration": transfer.expiration,
      "transportEndpoints": transfer.transportEndpoints.map(transferTransportEndpointMap),
    ]
  }

  private func rgbInvoiceMap(_ invoice: SdkRgbInvoiceResponse) -> [String: Any?] {
    [
      "recipientId": invoice.recipientId,
      "invoice": invoice.invoice,
      "expirationTimestamp": invoice.expirationTimestamp,
      "batchTransferIdx": Int64(invoice.batchTransferIdx),
    ]
  }

  private func decodeLnInvoiceMap(_ invoice: DecodeLnInvoiceResponse) -> [String: Any?] {
    [
      "amtMsat": invoice.amtMsat.map(String.init),
      "expirySec": String(invoice.expirySec),
      "timestamp": String(invoice.timestamp),
      "assetId": invoice.assetId,
      "assetAmount": invoice.assetAmount.map(String.init),
      "paymentHash": invoice.paymentHash,
      "paymentSecret": invoice.paymentSecret,
      "payeePubkey": invoice.payeePubkey,
      "network": invoice.network,
    ]
  }

  private func keysendMap(_ response: SdkKeysendResponse) -> [String: Any?] {
    [
      "paymentHash": response.paymentHash,
      "paymentPreimage": response.paymentPreimage,
      "status": String(describing: response.status),
    ]
  }

  private func sendPaymentMap(_ response: SdkSendPaymentResponse) -> [String: Any?] {
    [
      "paymentId": response.paymentId,
      "paymentHash": response.paymentHash,
      "paymentSecret": response.paymentSecret,
      "status": String(describing: response.status),
    ]
  }

  func rlnCreateNode(
    storageDirPath: String,
    daemonListeningPort: Int64,
    ldkPeerListeningPort: Int64,
    network: String,
    maxMediaUploadSizeMb: Int64,
    enableVirtualChannelsV0: Bool?,
    virtualPeerPubkeys: [String]?,
    vssUrl: String?,
    vssAllowHttp: Bool,
    vssAllowEmptyRestore: Bool,
    lspBaseUrl: String?,
    lspBearerToken: String?,
    reuseAddresses: Bool
  ) throws -> Int64 {
    try runRln("rlnCreateNode") {
      let initRequest = SdkInitRequest(
        storageDirPath: storageDirPath,
        daemonListeningPort: try requireUInt16(daemonListeningPort, field: "daemonListeningPort", operation: "rlnCreateNode"),
        ldkPeerListeningPort: try requireUInt16(ldkPeerListeningPort, field: "ldkPeerListeningPort", operation: "rlnCreateNode"),
        network: network,
        maxMediaUploadSizeMb: try requireUInt16(maxMediaUploadSizeMb, field: "maxMediaUploadSizeMb", operation: "rlnCreateNode"),
        enableVirtualChannelsV0: enableVirtualChannelsV0,
        virtualPeerPubkeys: virtualPeerPubkeys?.filter { !$0.isEmpty },
        lspBaseUrl: lspBaseUrl,
        lspBearerToken: lspBearerToken,
        vssUrl: vssUrl,
        vssAllowHttp: vssAllowHttp,
        vssAllowEmptyRestore: vssAllowEmptyRestore,
        reuseAddresses: reuseAddresses
      )
      try prepareStorageDirectory(storageDirPath, operation: "rlnCreateNode")
      let node = try SdkNode.create(request: initRequest)
      return try RlnNodeStore.shared.create(node: node, storageDirPath: storageDirPath)
    }
  }

  func rlnInitNode(nodeId: Int64, password: String, mnemonic: String?) throws -> String {
    do {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      let state = try RlnNodeStore.shared.getState(id: nodeId)
      if state != .created {
        throw RlnStoreError.invalidState("RLN init is not allowed while node is in state: \(state)")
      }
      let pubkey = try node.`init`(password: password, mnemonic: mnemonic)
      try RlnNodeStore.shared.markInitialized(id: nodeId)
      return pubkey
    } catch {
      throw bridgeError(error, operation: "rlnInitNode")
    }
  }

  func rlnCreateNativeExternalSigner(
    seedHex: String,
    network: String,
    permissivePolicy: Bool,
    storageDirPath: String?
  ) throws -> Int64 {
    try runRln("rlnCreateNativeExternalSigner") {
      let signer: NativeExternalSigner
      if let storageDirPath {
        try prepareStorageDirectory(
          storageDirPath,
          operation: "rlnCreateNativeExternalSigner"
        )
        signer = try NativeExternalSigner.newWithStorage(
          seedHex: seedHex,
          network: network,
          permissivePolicy: permissivePolicy,
          storageDirPath: storageDirPath
        )
      } else {
        signer = try NativeExternalSigner(
          seedHex: seedHex,
          network: network,
          permissivePolicy: permissivePolicy
        )
      }
      return RlnNodeStore.shared.createSigner(signer)
    }
  }

  func rlnInitNodeWithNativeExternalSigner(nodeId: Int64, signerId: Int64) throws {
    try runRln("rlnInitNodeWithNativeExternalSigner") {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      let state = try RlnNodeStore.shared.getState(id: nodeId)
      if state != .created {
        throw RlnStoreError.invalidState("RLN init is not allowed while node is in state: \(state)")
      }
      let signer = try RlnNodeStore.shared.getSigner(id: signerId)
      try node.initWithNativeExternalSigner(signer: signer)
      node.detachExternalSigner()
      try RlnNodeStore.shared.markInitialized(id: nodeId)
    }
  }

  func rlnAttachNativeExternalSigner(nodeId: Int64, signerId: Int64) throws {
    try runRln("rlnAttachNativeExternalSigner") {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      let signer = try RlnNodeStore.shared.getSigner(id: signerId)
      try node.attachNativeExternalSigner(signer: signer)
    }
  }

  func rlnUnlockNodeWithNativeExternalSigner(
    nodeId: Int64,
    signerId: Int64,
    bitcoindRpcUsername: String?,
    bitcoindRpcPassword: String?,
    bitcoindRpcHost: String?,
    bitcoindRpcPort: Int64?,
    indexerUrl: String?,
    proxyEndpoint: String?,
    announceAddresses: [String],
    announceAlias: String?,
    gossipRgsServerUrl: String?
  ) throws {
    do {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      let signer = try RlnNodeStore.shared.getSigner(id: signerId)
      switch try RlnNodeStore.shared.beginUnlock(id: nodeId) {
      case .unlocked:
        if isNodeReady(node) {
          return
        }
        throw RlnStoreError.invalidState("RLN node is marked unlocked but nodeInfo is not available")
      case .unlocking:
        break
      default:
        throw RlnStoreError.invalidState("Unexpected RLN node state before unlock")
      }

      try node.unlockWithNativeExternalSigner(
        signer: signer,
        bitcoindRpcUsername: bitcoindRpcUsername,
        bitcoindRpcPassword: bitcoindRpcPassword,
        bitcoindRpcHost: bitcoindRpcHost,
        bitcoindRpcPort: try optionalUInt16(bitcoindRpcPort, field: "bitcoindRpcPort", operation: "rlnUnlockNodeWithNativeExternalSigner"),
        indexerUrl: indexerUrl,
        proxyEndpoint: proxyEndpoint,
        announceAddresses: announceAddresses,
        announceAlias: announceAlias
      )
      RlnNodeStore.shared.markUnlocked(id: nodeId)
    } catch {
      RlnNodeStore.shared.rollbackUnlock(id: nodeId)
      throw bridgeError(error, operation: "rlnUnlockNodeWithNativeExternalSigner")
    }
  }

  func rlnDestroyNativeExternalSigner(signerId: Int64) throws {
    RlnNodeStore.shared.removeSigner(id: signerId)
  }

  func rlnInitNodeWithExternalSigner(nodeId: Int64, nodePublicKeyHex: String, accountXpubVanilla: String, accountXpubColored: String, masterFingerprint: String, protocolVersion: String, apiLevel: Int64) throws {
    try runRln("rlnInitNodeWithExternalSigner") {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      let state = try RlnNodeStore.shared.getState(id: nodeId)
      if state != .created {
        throw RlnStoreError.invalidState("RLN init is not allowed while node is in state: \(state)")
      }
      try node.initWithExternalSigner(bootstrap: SdkExternalSignerBootstrap(
        nodeId: nodePublicKeyHex,
        accountXpubVanilla: accountXpubVanilla,
        accountXpubColored: accountXpubColored,
        masterFingerprint: masterFingerprint,
        protocolVersion: protocolVersion,
        apiLevel: try requireUInt32(apiLevel, field: "apiLevel", operation: "rlnInitNodeWithExternalSigner")
      ))
      try RlnNodeStore.shared.markInitialized(id: nodeId)
    }
  }

  func rlnUnlockNode(
    nodeId: Int64,
    password: String,
    bitcoindRpcUsername: String?,
    bitcoindRpcPassword: String?,
    bitcoindRpcHost: String?,
    bitcoindRpcPort: Int64?,
    indexerUrl: String?,
    proxyEndpoint: String?,
    announceAddresses: [String],
    announceAlias: String?,
    gossipRgsServerUrl: String?
  ) throws {
    do {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      switch try RlnNodeStore.shared.beginUnlock(id: nodeId) {
      case .unlocked:
        if isNodeReady(node) {
          return
        }
        throw RlnStoreError.invalidState("RLN node is marked unlocked but nodeInfo is not available")
      case .unlocking:
        break
      default:
        throw RlnStoreError.invalidState("Unexpected RLN node state before unlock")
      }

      try node.unlock(request: SdkUnlockRequest(
        password: password,
        bitcoindRpcUsername: bitcoindRpcUsername,
        bitcoindRpcPassword: bitcoindRpcPassword,
        bitcoindRpcHost: bitcoindRpcHost,
        bitcoindRpcPort: try optionalUInt16(bitcoindRpcPort, field: "bitcoindRpcPort", operation: "rlnUnlockNode"),
        indexerUrl: indexerUrl,
        proxyEndpoint: proxyEndpoint,
        announceAddresses: announceAddresses,
        announceAlias: announceAlias,
        gossipRgsServerUrl: gossipRgsServerUrl
      ))
      RlnNodeStore.shared.markUnlocked(id: nodeId)
    } catch {
      RlnNodeStore.shared.rollbackUnlock(id: nodeId)
      throw bridgeError(error, operation: "rlnUnlockNode")
    }
  }

  func rlnDestroyNode(nodeId: Int64) throws {
    RlnNodeStore.shared.remove(id: nodeId)
  }

  func rlnNodeInfo(nodeId: Int64) throws -> RlnWireResponse {
    try runRlnWire("rlnNodeInfo") {
      let info = try RlnNodeStore.shared.get(id: nodeId).nodeInfo()
      return [
        "pubkey": info.pubkey,
        "numChannels": pigeonInteger(info.numChannels),
        "numUsableChannels": pigeonInteger(info.numUsableChannels),
        "localBalanceSat": pigeonInteger(info.localBalanceSat),
        "eventualCloseFeesSat": pigeonInteger(info.eventualCloseFeesSat),
        "pendingOutboundPaymentsSat": pigeonInteger(info.pendingOutboundPaymentsSat),
        "numPeers": pigeonInteger(info.numPeers),
        "accountXpubVanilla": info.accountXpubVanilla,
        "accountXpubColored": info.accountXpubColored,
        "maxMediaUploadSizeMb": Int64(info.maxMediaUploadSizeMb),
        "rgbHtlcMinMsat": pigeonInteger(info.rgbHtlcMinMsat),
        "rgbChannelCapacityMinSat": pigeonInteger(info.rgbChannelCapacityMinSat),
        "channelCapacityMinSat": pigeonInteger(info.channelCapacityMinSat),
        "channelCapacityMaxSat": pigeonInteger(info.channelCapacityMaxSat),
        "channelAssetMinAmount": pigeonInteger(info.channelAssetMinAmount),
        "channelAssetMaxAmount": String(info.channelAssetMaxAmount),
        "networkNodes": pigeonInteger(info.networkNodes),
        "networkChannels": pigeonInteger(info.networkChannels),
        "latestRgsSnapshotTimestamp": info.latestRgsSnapshotTimestamp.map(pigeonInteger),
      ]
    }
  }

  func rlnNetworkInfo(nodeId: Int64) throws -> RlnWireResponse {
    try runRlnWire("rlnNetworkInfo") {
      let info = try RlnNodeStore.shared.get(id: nodeId).networkInfo()
      return [
        "network": info.network,
        "height": info.height,
      ]
    }
  }

  func rlnListPeers(nodeId: Int64) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListPeers") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listPeers()
        .map { ["pubkey": $0.pubkey] }
    }
  }

  func rlnConnectPeer(nodeId: Int64, peerPubkeyAndAddr: String) throws {
    try runRln("rlnConnectPeer") {
      try RlnNodeStore.shared.get(id: nodeId).connectpeer(peerPubkeyAndAddr: peerPubkeyAndAddr)
    }
  }

  func rlnDisconnectPeer(nodeId: Int64, peerPubkey: String) throws {
    try runRln("rlnDisconnectPeer") {
      try RlnNodeStore.shared.get(id: nodeId).disconnectpeer(request: SdkDisconnectPeerRequest(peerPubkey: peerPubkey))
    }
  }

  func rlnListChannels(nodeId: Int64) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListChannels") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listChannels()
        .map(channelMap)
    }
  }

  func rlnOpenChannel(nodeId: Int64, peerPubkeyAndOptAddr: String, capacitySat: Int64, pushMsat: Int64, publicChannel: Bool, withAnchors: Bool, feeBaseMsat: Int64?, feeProportionalMillionths: Int64?, temporaryChannelId: String?, assetId: String?, assetAmount: Int64?, pushAssetAmount: Int64?, virtualOpenMode: String?) throws -> RlnWireResponse {
    try runRlnWire("rlnOpenChannel") {
      let request = try SdkOpenChannelRequest(
        peerPubkeyAndOptAddr: peerPubkeyAndOptAddr,
        capacitySat: try requireUInt64(capacitySat, field: "capacitySat", operation: "rlnOpenChannel"),
        pushMsat: try requireUInt64(pushMsat, field: "pushMsat", operation: "rlnOpenChannel"),
        public: publicChannel,
        withAnchors: withAnchors,
        feeBaseMsat: try optionalUInt32(feeBaseMsat, field: "feeBaseMsat", operation: "rlnOpenChannel"),
        feeProportionalMillionths: try optionalUInt32(feeProportionalMillionths, field: "feeProportionalMillionths", operation: "rlnOpenChannel"),
        temporaryChannelId: temporaryChannelId,
        assetId: assetId,
        assetAmount: try optionalUInt64(assetAmount, field: "assetAmount", operation: "rlnOpenChannel"),
        pushAssetAmount: try optionalUInt64(pushAssetAmount, field: "pushAssetAmount", operation: "rlnOpenChannel"),
        virtualOpenMode: virtualOpenMode
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).openchannel(request: request)
      return ["temporaryChannelId": response.temporaryChannelId]
    }
  }

  func rlnCloseChannel(nodeId: Int64, channelId: String, peerPubkey: String, force: Bool) throws {
    try runRln("rlnCloseChannel") {
      try RlnNodeStore.shared.get(id: nodeId).closechannel(request: SdkCloseChannelRequest(
        channelId: channelId,
        peerPubkey: peerPubkey,
        force: force
      ))
    }
  }

  func rlnListPayments(nodeId: Int64) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListPayments") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listPayments()
        .map(paymentMap)
    }
  }

  func rlnAddress(nodeId: Int64) throws -> RlnWireResponse {
    try runRlnWire("rlnAddress") {
      ["address": try RlnNodeStore.shared.get(id: nodeId).address().address]
    }
  }

  func rlnRotateAddress(nodeId: Int64) throws -> RlnWireResponse {
    try runRlnWire("rlnRotateAddress") {
      ["address": try RlnNodeStore.shared.get(id: nodeId).rotateAddress().address]
    }
  }

  func rlnSignMessage(nodeId: Int64, message: String) throws -> RlnWireResponse {
    try runRlnWire("rlnSignMessage") {
      ["signedMessage": try RlnNodeStore.shared.get(id: nodeId).signMessage(message: message).signedMessage]
    }
  }

  func rlnVerifyMessage(nodeId: Int64, message: String, signature: String) throws -> RlnWireResponse {
    try runRlnWire("rlnVerifyMessage") {
      [
        "valid": try RlnNodeStore.shared.get(id: nodeId)
          .verifyMessage(message: message, signature: signature)
          .valid,
      ]
    }
  }

  func rlnAssetBalance(nodeId: Int64, assetId: String) throws -> RlnWireResponse {
    try runRlnWire("rlnAssetBalance") {
      assetBalanceMap(try RlnNodeStore.shared.get(id: nodeId).assetBalance(assetId: assetId))
    }
  }

  func rlnBackup(nodeId: Int64, backupPath: String, password: String) throws {
    throw PigeonError(
      code: "RlnError",
      message: "rlnBackup is not supported in this version of the RLN node",
      details: ["operation": "rlnBackup", "phase": "rln-parity"]
    )
  }

  func rlnBtcBalance(nodeId: Int64, skipSync: Bool) throws -> RlnWireResponse {
    try runRlnWire("rlnBtcBalance") {
      let balance = try RlnNodeStore.shared.get(id: nodeId).btcBalance(skipSync: skipSync)
      return [
        "vanilla": btcBalanceMap(balance.vanilla),
        "colored": btcBalanceMap(balance.colored),
      ]
    }
  }

  func rlnCheckIndexerUrl(nodeId: Int64, indexerUrl: String) throws -> RlnWireResponse {
    try runRlnWire("rlnCheckIndexerUrl") {
      let response = try RlnNodeStore.shared.get(id: nodeId).checkIndexerUrl(indexerUrl: indexerUrl)
      return ["indexerProtocol": response.indexerProtocol]
    }
  }

  func rlnCheckProxyEndpoint(nodeId: Int64, proxyEndpoint: String) throws {
    try runRln("rlnCheckProxyEndpoint") {
      try RlnNodeStore.shared.get(id: nodeId).checkProxyEndpoint(proxyEndpoint: proxyEndpoint)
    }
  }

  func rlnCreateUtxos(nodeId: Int64, upTo: Bool, num: Int64?, size: Int64?, feeRate: Double, skipSync: Bool) throws {
    try runRln("rlnCreateUtxos") {
      let request = SdkCreateUtxosRequest(
        upTo: upTo,
        num: try optionalUInt8(num, field: "num", operation: "rlnCreateUtxos"),
        size: try optionalUInt32(size, field: "size", operation: "rlnCreateUtxos"),
        feeRate: try requireFeeRate(feeRate, field: "feeRate", operation: "rlnCreateUtxos"),
        skipSync: skipSync
      )
      try RlnNodeStore.shared.get(id: nodeId).createutxos(request: request)
    }
  }

  func rlnDecodeLnInvoice(nodeId: Int64, invoice: String) throws -> RlnWireResponse {
    try runRlnWire("rlnDecodeLnInvoice") {
      decodeLnInvoiceMap(try RlnNodeStore.shared.get(id: nodeId).decodeLnInvoice(invoice: invoice))
    }
  }

  func rlnDecodeRgbInvoice(nodeId: Int64, invoice: String) throws -> RlnWireResponse {
    try runRlnWire("rlnDecodeRgbInvoice") {
      decodeRgbInvoiceMap(try RlnNodeStore.shared.get(id: nodeId).decodeRgbInvoice(invoice: invoice))
    }
  }

  func rlnEstimateFee(nodeId: Int64, blocks: Int64) throws -> RlnWireResponse {
    try runRlnWire("rlnEstimateFee") {
      let response = try RlnNodeStore.shared.get(id: nodeId)
        .estimateFee(blocks: try requireUInt16(blocks, field: "blocks", operation: "rlnEstimateFee"))
      return ["feeRate": response.feeRate]
    }
  }

  func rlnFailTransfers(nodeId: Int64, batchTransferIdx: Int64?, noAssetOnly: Bool, skipSync: Bool) throws -> RlnWireResponse {
    try runRlnWire("rlnFailTransfers") {
      let response = try RlnNodeStore.shared.get(id: nodeId).failtransfers(request: SdkFailTransfersRequest(
        batchTransferIdx: try optionalInt32(batchTransferIdx, field: "batchTransferIdx", operation: "rlnFailTransfers"),
        noAssetOnly: noAssetOnly,
        skipSync: skipSync
      ))
      return ["transfersChanged": response.transfersChanged]
    }
  }

  func rlnGetChannelId(nodeId: Int64, temporaryChannelId: String) throws -> String {
    try runRln("rlnGetChannelId") {
      try RlnNodeStore.shared.get(id: nodeId).getChannelId(temporaryChannelId: temporaryChannelId)
    }
  }

  func rlnGetPayment(nodeId: Int64, paymentHash: String) throws -> RlnWireResponse {
    try runRlnWire("rlnGetPayment") {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      var lastError: Error?
      for paymentType in [PaymentType.outbound, .inboundAutoClaim, .inboundHodl] {
        do {
          return paymentMap(try node.getPayment(paymentHash: paymentHash, paymentType: paymentType))
        } catch {
          lastError = error
        }
      }
      throw lastError ?? RlnStoreError.nodeNotFound(id: nodeId)
    }
  }

  func rlnInvoiceStatus(nodeId: Int64, invoice: String) throws -> RlnWireResponse {
    try runRlnWire("rlnInvoiceStatus") {
      ["status": String(describing: try RlnNodeStore.shared.get(id: nodeId).invoiceStatus(invoice: invoice))]
    }
  }

  func rlnKeysend(nodeId: Int64, destPubkey: String, amtMsat: Int64, assetId: String?, assetAmount: Int64?) throws -> RlnWireResponse {
    try runRlnWire("rlnKeysend") {
      let request = try SdkKeysendRequest(
        destPubkey: destPubkey,
        amtMsat: try requireUInt64(amtMsat, field: "amtMsat", operation: "rlnKeysend"),
        assetId: assetId,
        assetAmount: try optionalUInt64(assetAmount, field: "assetAmount", operation: "rlnKeysend")
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).keysend(request: request)
      return keysendMap(response)
    }
  }

  func rlnListAssets(nodeId: Int64, filterAssetSchemas: [String]) throws -> RlnWireResponse {
    try runRlnWire("rlnListAssets") {
      listAssetsMap(try RlnNodeStore.shared.get(id: nodeId).listAssets(filterAssetSchemas: filterAssetSchemas))
    }
  }

  func rlnListTransactions(nodeId: Int64, skipSync: Bool) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListTransactions") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listTransactions(skipSync: skipSync)
        .map(transactionMap)
    }
  }

  func rlnListTransactionsByTxid(nodeId: Int64, txid: String, skipSync: Bool) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListTransactionsByTxid") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listTransactionsByTxid(txid: txid, skipSync: skipSync)
        .map(transactionMap)
    }
  }

  func rlnListTransfers(nodeId: Int64, assetId: String) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListTransfers") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listTransfers(assetId: assetId)
        .map(transferMap)
    }
  }

  func rlnListTransfersByTxid(nodeId: Int64, txid: String) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListTransfersByTxid") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listTransfersByTxid(txid: txid)
        .map(transferMap)
    }
  }

  func rlnListUnspents(nodeId: Int64, skipSync: Bool) throws -> [RlnWireResponse] {
    try runRlnWireList("rlnListUnspents") {
      try RlnNodeStore.shared.get(id: nodeId)
        .listUnspents(skipSync: skipSync)
        .map(unspentMap)
    }
  }

  func rlnLnInvoice(
    nodeId: Int64,
    amtMsat: Int64?,
    expirySec: Int64,
    assetId: String?,
    assetAmount: Int64?,
    paymentHash: String?,
    minFinalCltvExpiryDelta: Int64?,
    descriptionHash: String?
  ) throws -> RlnWireResponse {
    try runRlnWire("rlnLnInvoice") {
      let request = try LnInvoiceRequest(
        amtMsat: try optionalUInt64(amtMsat, field: "amtMsat", operation: "rlnLnInvoice"),
        expirySec: try requireUInt32(expirySec, field: "expirySec", operation: "rlnLnInvoice"),
        assetId: assetId,
        assetAmount: try optionalUInt64(assetAmount, field: "assetAmount", operation: "rlnLnInvoice"),
        paymentHash: paymentHash,
        descriptionHash: descriptionHash,
        minFinalCltvExpiryDelta: try optionalUInt16(minFinalCltvExpiryDelta, field: "minFinalCltvExpiryDelta", operation: "rlnLnInvoice")
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).lnInvoice(request: request)
      return ["invoice": response.invoice]
    }
  }

  func rlnClaimHodlInvoice(nodeId: Int64, paymentHash: String, paymentPreimage: String) throws -> RlnWireResponse {
    try runRlnWire("rlnClaimHodlInvoice") {
      let response = try RlnNodeStore.shared.get(id: nodeId).claimhodlinvoice(request: ClaimHodlInvoiceRequest(
        paymentHash: paymentHash,
        paymentPreimage: paymentPreimage
      ))
      return ["changed": response.changed]
    }
  }

  func rlnCancelHodlInvoice(nodeId: Int64, paymentHash: String) throws {
    try runRln("rlnCancelHodlInvoice") {
      try RlnNodeStore.shared.get(id: nodeId).cancelhodlinvoice(request: CancelHodlInvoiceRequest(paymentHash: paymentHash))
    }
  }

  func rlnApayNew(nodeId: Int64, hostNodeId: String) throws -> RlnWireResponse {
    try runRlnWire("rlnApayNew") {
      let response = try RlnNodeStore.shared.get(id: nodeId).apayNew(hostNodeId: hostNodeId)
      let hashes = response.hashes.map { hash in
        [
          "hashIndex": pigeonInteger(hash.hashIndex),
          "paymentHash": hash.paymentHash,
        ] as [String: Any]
      }
      return [
        "requestId": response.requestId,
        "hostNodeId": response.hostNodeId,
        "protocolVersion": pigeonInteger(response.protocolVersion),
        "orderId": response.orderId,
        "status": response.status,
        "acceptedThroughIndex": pigeonInteger(response.acceptedThroughIndex),
        "nextIndexExpected": pigeonInteger(response.nextIndexExpected),
        "unusedHashes": pigeonInteger(response.unusedHashes),
        "refillBatchSize": pigeonInteger(response.refillBatchSize),
        "firstHashIndex": pigeonInteger(response.firstHashIndex),
        "lastHashIndex": pigeonInteger(response.lastHashIndex),
        "hashes": hashes,
      ]
    }
  }

  func rlnApayNewWithAddress(nodeId: Int64, hostNodeId: String, username: String, domain: String) throws -> RlnWireResponse {
    try runRlnWire("rlnApayNewWithAddress") {
      let response = try RlnNodeStore.shared.get(id: nodeId).apayNewWithAddress(
        hostNodeId: hostNodeId,
        username: username,
        domain: domain
      )
      let hashes = response.hashes.map { hash in
        [
          "hashIndex": pigeonInteger(hash.hashIndex),
          "paymentHash": hash.paymentHash,
        ] as [String: Any]
      }
      return [
        "requestId": response.requestId,
        "hostNodeId": response.hostNodeId,
        "protocolVersion": pigeonInteger(response.protocolVersion),
        "orderId": response.orderId,
        "status": response.status,
        "acceptedThroughIndex": pigeonInteger(response.acceptedThroughIndex),
        "nextIndexExpected": pigeonInteger(response.nextIndexExpected),
        "unusedHashes": pigeonInteger(response.unusedHashes),
        "refillBatchSize": pigeonInteger(response.refillBatchSize),
        "firstHashIndex": pigeonInteger(response.firstHashIndex),
        "lastHashIndex": pigeonInteger(response.lastHashIndex),
        "hashes": hashes,
      ]
    }
  }

  func rlnRefreshTransfers(nodeId: Int64, skipSync: Bool) throws {
    try runRln("rlnRefreshTransfers") {
      try RlnNodeStore.shared.get(id: nodeId).refreshtransfers(request: SdkRefreshTransfersRequest(skipSync: skipSync))
    }
  }

  private func parseAssignmentKind(_ rawValue: String?) throws -> AssignmentKind? {
    guard let rawValue else {
      return nil
    }
    switch rawValue {
    case "Fungible":
      return .fungible
    case "NonFungible":
      return .nonFungible
    case "InflationRight":
      return .inflationRight
    case "ReplaceRight":
      return .replaceRight
    case "Any":
      return .any
    default:
      throw invalidArgument(
        "rlnRgbInvoice",
        field: "assignmentKind",
        message: "Unknown assignmentKind: \(rawValue)"
      )
    }
  }

  func rlnRgbInvoice(
    nodeId: Int64,
    assetId: String?,
    assignmentAmount: Int64?,
    durationSeconds: Int64?,
    minConfirmations: Int64,
    witness: Bool,
    assignmentKind: String?
  ) throws -> RlnWireResponse {
    try runRlnWire("rlnRgbInvoice") {
      let request = SdkRgbInvoiceRequest(
        assetId: assetId,
        assignmentKind: try parseAssignmentKind(assignmentKind),
        assignmentAmount: try optionalUInt64(assignmentAmount, field: "assignmentAmount", operation: "rlnRgbInvoice"),
        durationSeconds: try optionalUInt32(durationSeconds, field: "durationSeconds", operation: "rlnRgbInvoice"),
        minConfirmations: try requireUInt8(minConfirmations, field: "minConfirmations", operation: "rlnRgbInvoice"),
        witness: witness
      )
      return rgbInvoiceMap(try RlnNodeStore.shared.get(id: nodeId).rgbinvoice(request: request))
    }
  }

  func rlnSendBtc(nodeId: Int64, amount: Int64, address: String, feeRate: Double, skipSync: Bool) throws -> RlnWireResponse {
    try runRlnWire("rlnSendBtc") {
      let request = SdkSendBtcRequest(
        amount: try requireUInt64(amount, field: "amount", operation: "rlnSendBtc"),
        address: address,
        feeRate: try requireFeeRate(feeRate, field: "feeRate", operation: "rlnSendBtc"),
        skipSync: skipSync
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).sendbtc(request: request)
      return ["txid": response.txid]
    }
  }

  func rlnSendPayment(nodeId: Int64, invoice: String, amtMsat: Int64?, assetId: String?, assetAmount: Int64?) throws -> RlnWireResponse {
    try runRlnWire("rlnSendPayment") {
      let request = try SdkSendPaymentRequest(
        invoice: invoice,
        amtMsat: try optionalUInt64(amtMsat, field: "amtMsat", operation: "rlnSendPayment"),
        assetId: assetId,
        assetAmount: try optionalUInt64(assetAmount, field: "assetAmount", operation: "rlnSendPayment")
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).sendpayment(request: request)
      return sendPaymentMap(response)
    }
  }

  func rlnSendRgb(nodeId: Int64, donation: Bool, feeRate: Double, minConfirmations: Int64, skipSync: Bool, assetId: String, recipientId: String, amount: Int64, transportEndpoints: [String], witnessAmountSat: Int64?, witnessBlinding: Int64?) throws -> RlnWireResponse {
    try runRlnWire("rlnSendRgb") {
      if skipSync {
        throw PigeonError(
          code: "UnsupportedOperationException",
          message: "rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.",
          details: ["operation": "rlnSendRgb", "field": "skipSync"]
        )
      }
      let witnessData: WitnessData?
      if let witnessAmountSat {
        witnessData = WitnessData(
          amountSat: try requireUInt64(witnessAmountSat, field: "witnessAmountSat", operation: "rlnSendRgb"),
          blinding: try optionalUInt64(witnessBlinding, field: "witnessBlinding", operation: "rlnSendRgb")
        )
      } else {
        witnessData = nil
      }
      let recipient = RgbRecipient(
        recipientId: recipientId,
        witnessData: witnessData,
        assignmentKind: .fungible,
        assignmentAmount: try requireUInt64(amount, field: "amount", operation: "rlnSendRgb"),
        transportEndpoints: transportEndpoints
      )
      let request = SendRgbRequest(
        donation: donation,
        feeRate: try requireFeeRate(feeRate, field: "feeRate", operation: "rlnSendRgb"),
        minConfirmations: try requireUInt8(minConfirmations, field: "minConfirmations", operation: "rlnSendRgb"),
        recipientGroups: [
          AssetRecipients(
            assetId: assetId,
            recipients: [recipient]
          ),
        ]
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).sendRgb(request: request)
      return [
        "txid": response.txid,
        "batchTransferIdx": Int64(response.batchTransferIdx),
      ]
    }
  }

  func rlnShutdown(nodeId: Int64) throws {
    try runRln("rlnShutdown") {
      let node = try RlnNodeStore.shared.get(id: nodeId)
      node.shutdown()
      RlnNodeStore.shared.markShutdown(id: nodeId)
    }
  }

  func rlnSync(nodeId: Int64) throws {
    try runRln("rlnSync") {
      try RlnNodeStore.shared.get(id: nodeId).sync()
    }
  }

  func rlnIssueAssetNia(nodeId: Int64, ticker: String, name: String, precision: Int64, amounts: [Int64]) throws -> RlnWireResponse {
    try runRlnWire("rlnIssueAssetNia") {
      let asset = try RlnNodeStore.shared.get(id: nodeId).issueassetnia(request: SdkIssueAssetNiaRequest(
        amounts: try requireUInt64List(amounts, field: "amounts", operation: "rlnIssueAssetNia"),
        ticker: ticker,
        name: name,
        precision: try requireUInt8(precision, field: "precision", operation: "rlnIssueAssetNia")
      ))
      return assetNiaMap(asset)
    }
  }

  func rlnIssueAssetCfa(nodeId: Int64, name: String, details: String?, precision: Int64, amounts: [Int64], fileDigest: String?) throws -> RlnWireResponse {
    try runRlnWire("rlnIssueAssetCfa") {
      let asset = try RlnNodeStore.shared.get(id: nodeId).issueassetcfa(request: SdkIssueAssetCfaRequest(
        amounts: try requireUInt64List(amounts, field: "amounts", operation: "rlnIssueAssetCfa"),
        name: name,
        details: details,
        precision: try requireUInt8(precision, field: "precision", operation: "rlnIssueAssetCfa"),
        fileDigest: fileDigest
      ))
      return assetCfaMap(asset)
    }
  }

  func rlnIssueAssetIfa(nodeId: Int64, ticker: String, name: String, precision: Int64, amounts: [Int64], inflationAmounts: [Int64], rejectListUrl: String?) throws -> RlnWireResponse {
    try runRlnWire("rlnIssueAssetIfa") {
      let asset = try RlnNodeStore.shared.get(id: nodeId).issueassetifa(request: SdkIssueAssetIfaRequest(
        amounts: try requireUInt64List(amounts, field: "amounts", operation: "rlnIssueAssetIfa"),
        inflationAmounts: try requireUInt64List(inflationAmounts, field: "inflationAmounts", operation: "rlnIssueAssetIfa"),
        ticker: ticker,
        name: name,
        precision: try requireUInt8(precision, field: "precision", operation: "rlnIssueAssetIfa"),
        rejectListUrl: rejectListUrl
      ))
      return assetIfaMap(asset)
    }
  }

  func rlnInflate(
    nodeId: Int64,
    assetId: String,
    inflationAmounts: [Int64],
    feeRate: Double,
    minConfirmations: Int64
  ) throws -> RlnWireResponse {
    try runRlnWire("rlnInflate") {
      let request = InflateRequest(
        assetId: assetId,
        inflationAmounts: try requireUInt64List(
          inflationAmounts,
          field: "inflationAmounts",
          operation: "rlnInflate"
        ),
        feeRate: try requireFeeRate(feeRate, field: "feeRate", operation: "rlnInflate"),
        minConfirmations: try requireUInt8(
          minConfirmations,
          field: "minConfirmations",
          operation: "rlnInflate"
        )
      )
      let response = try RlnNodeStore.shared.get(id: nodeId).inflate(request: request)
      return ["txid": response.txid]
    }
  }

  func rlnIssueAssetUda(nodeId: Int64, ticker: String, name: String, details: String?, precision: Int64, mediaFileDigest: String?, attachmentsFileDigests: [String]) throws -> RlnWireResponse {
    try runRlnWire("rlnIssueAssetUda") {
      let asset = try RlnNodeStore.shared.get(id: nodeId).issueassetuda(request: SdkIssueAssetUdaRequest(
        ticker: ticker,
        name: name,
        details: details,
        precision: try requireUInt8(precision, field: "precision", operation: "rlnIssueAssetUda"),
        mediaFileDigest: mediaFileDigest,
        attachmentsFileDigests: attachmentsFileDigests
      ))
      return assetUdaMap(asset)
    }
  }

  func rlnVssBackup(nodeId: Int64) throws -> Int64 {
    try runRln("rlnVssBackup") {
      let version = try RlnNodeStore.shared.get(id: nodeId).vssBackup()
      guard let value = Int64(exactly: version) else {
        throw PigeonError(
          code: "integerOverflow",
          message: "VSS backup version exceeds the Dart Int64 bridge range.",
          details: ["operation": "rlnVssBackup"]
        )
      }
      return value
    }
  }

  func rlnVssClearFence(nodeId: Int64, password: String) throws {
    try runRln("rlnVssClearFence") {
      try RlnNodeStore.shared.get(id: nodeId).vssClearFence(
        request: SdkVssClearFenceRequest(password: password)
      )
    }
  }
}
