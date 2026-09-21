import XCTest

@testable import rgb_sdk_flutter

final class RunnerTests: XCTestCase {
  private let plugin = RgbSdkFlutterPlugin()

  func testWireCodecPreservesUnsignedAmountsAndNestedNulls() throws {
    let response = try RlnWireCodec.encode([
      "maximum": UInt64.max, "zero": Int64(0), "one": Int64(1),
      "nested": ["value": NSNull()], "enabled": true
    ] as [String: Any])
    let decoded = try XCTUnwrap(JSONSerialization.jsonObject(
      with: Data(response.json.utf8)) as? [String: Any])
    XCTAssertEqual(decoded["maximum"] as? String, "18446744073709551615")
    XCTAssertEqual(decoded["zero"] as? Int, 0)
    XCTAssertEqual(decoded["one"] as? Int, 1)
    XCTAssertEqual(decoded["enabled"] as? Bool, true)
    XCTAssertTrue((decoded["nested"] as? [String: Any])?["value"] is NSNull)
  }

  func testNativeArtifactInfoMatchesPinnedIOSArtifact() throws {
    let info = try plugin.getNativeArtifactInfo()

    XCTAssertEqual(info.platform, "ios")
    XCTAssertEqual(info.rlnVersion, ReleaseBaseline.rlnVersion)
    XCTAssertEqual(info.reactNativeParityVersion, ReleaseBaseline.reactNativeVersion)
    XCTAssertEqual(info.bridge, "pigeon-bootstrap")
    XCTAssertEqual(
      info.nativeArtifact,
      "rgb-lightning-node-swift-\(ReleaseBaseline.rlnVersion).zip"
    )
  }

  func testChainSyncFactorySelectsTransactionAndBlockBackends() throws {
    let transactionSync = try RlnChainSyncFactory.make(
      bitcoindRpcUsername: nil,
      bitcoindRpcPassword: nil,
      bitcoindRpcHost: nil,
      bitcoindRpcPort: nil,
      indexerUrl: "electrum.example:50001"
    )
    guard case let .transactionSync(indexerUrl) = transactionSync else {
      return XCTFail("Expected transaction sync")
    }
    XCTAssertEqual(indexerUrl, "electrum.example:50001")

    let blockSync = try RlnChainSyncFactory.make(
      bitcoindRpcUsername: "rpc-user",
      bitcoindRpcPassword: "rpc-password",
      bitcoindRpcHost: "127.0.0.1",
      bitcoindRpcPort: 18_443,
      indexerUrl: "ignored.example:50001"
    )
    guard case let .blockSync(username, password, host, port) = blockSync else {
      return XCTFail("Expected block sync")
    }
    XCTAssertEqual(username, "rpc-user")
    XCTAssertEqual(password, "rpc-password")
    XCTAssertEqual(host, "127.0.0.1")
    XCTAssertEqual(port, 18_443)
  }

  func testChainSyncFactoryRejectsPartialOrInvalidConfiguration() {
    assertChainSyncError(field: "bitcoindRpc") {
      _ = try RlnChainSyncFactory.make(
        bitcoindRpcUsername: "rpc-user",
        bitcoindRpcPassword: nil,
        bitcoindRpcHost: nil,
        bitcoindRpcPort: nil,
        indexerUrl: "electrum.example:50001"
      )
    }
    assertChainSyncError(field: "indexerUrl") {
      _ = try RlnChainSyncFactory.make(
        bitcoindRpcUsername: nil,
        bitcoindRpcPassword: nil,
        bitcoindRpcHost: nil,
        bitcoindRpcPort: nil,
        indexerUrl: nil
      )
    }
    for port in [Int64(0), Int64(65_536)] {
      assertChainSyncError(field: "bitcoindRpcPort") {
        _ = try RlnChainSyncFactory.make(
          bitcoindRpcUsername: "rpc-user",
          bitcoindRpcPassword: "rpc-password",
          bitcoindRpcHost: "127.0.0.1",
          bitcoindRpcPort: port,
          indexerUrl: nil
        )
      }
    }
    assertChainSyncError(field: "indexerUrl") {
      _ = try RlnChainSyncFactory.make(
        bitcoindRpcUsername: nil,
        bitcoindRpcPassword: nil,
        bitcoindRpcHost: nil,
        bitcoindRpcPort: nil,
        indexerUrl: " \n "
      )
    }
    assertChainSyncError(field: "bitcoindRpcUsername") {
      _ = try RlnChainSyncFactory.make(
        bitcoindRpcUsername: " ",
        bitcoindRpcPassword: "",
        bitcoindRpcHost: "127.0.0.1",
        bitcoindRpcPort: 18_443,
        indexerUrl: nil
      )
    }
    assertChainSyncError(field: "bitcoindRpcHost") {
      _ = try RlnChainSyncFactory.make(
        bitcoindRpcUsername: "rpc-user",
        bitcoindRpcPassword: "",
        bitcoindRpcHost: "\t",
        bitcoindRpcPort: 18_443,
        indexerUrl: nil
      )
    }
  }

  func testBackupFailsAsNativeBlockedWithoutLeakingArguments() {
    XCTAssertThrowsError(
      try plugin.rlnBackup(
        nodeId: 1,
        backupPath: "/tmp/secret-backup-path",
        password: "super-secret-password"
      )
    ) { error in
      let pigeon = expectPigeonError(error)
      XCTAssertEqual(pigeon.code, "RlnError")
      XCTAssertEqual(pigeon.message, "rlnBackup is not supported in this version of the RLN node")
      XCTAssertFalse((pigeon.message ?? "").contains("secret"))

      let details = expectDetails(pigeon)
      XCTAssertEqual(details["operation"] as? String, "rlnBackup")
      XCTAssertEqual(details["phase"] as? String, "rln-parity")
    }
  }

  func testExternalSignerRgsFailsBeforeNativeLookup() {
    XCTAssertThrowsError(try plugin.rlnUnlockNodeWithNativeExternalSigner(
      nodeId: 9999, signerId: 9999, bitcoindRpcUsername: nil,
      bitcoindRpcPassword: nil, bitcoindRpcHost: nil, bitcoindRpcPort: nil,
      indexerUrl: nil, proxyEndpoint: nil, announceAddresses: [],
      announceAlias: nil, gossipRgsServerUrl: "https://rgs.example")) { error in
      let pigeon = expectPigeonError(error)
      XCTAssertEqual(pigeon.code, "UnsupportedOperationException")
      XCTAssertEqual(expectDetails(pigeon)["category"] as? String, "unsupported")
    }
  }

  func testSendRgbRejectsSkipSyncBeforeNativeNodeLookup() {
    XCTAssertThrowsError(
      try plugin.rlnSendRgb(
        nodeId: 1,
        donation: false,
        feeRate: 1.5,
        minConfirmations: 1,
        skipSync: true,
        assetId: "asset",
        recipientId: "recipient",
        amount: 100,
        transportEndpoints: ["rpc://127.0.0.1:3003/json-rpc"],
        witnessAmountSat: nil,
        witnessBlinding: nil
      )
    ) { error in
      let pigeon = expectPigeonError(error)
      XCTAssertEqual(pigeon.code, "UnsupportedOperationException")
      XCTAssertEqual(
        pigeon.message,
        "rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact."
      )

      let details = expectDetails(pigeon)
      XCTAssertEqual(details["operation"] as? String, "rlnSendRgb")
      XCTAssertEqual(details["field"] as? String, "skipSync")
    }
  }

  func testCreateNodeRejectsInvalidUnsignedInputsBeforeNativeCreate() {
    XCTAssertThrowsError(
      try plugin.rlnCreateNode(
        storageDirPath: uniquePath("negative-port"),
        daemonListeningPort: -1,
        ldkPeerListeningPort: 9735,
        network: "regtest",
        maxMediaUploadSizeMb: 5,
        enableVirtualChannelsV0: nil,
        virtualPeerPubkeys: nil,
        vssUrl: nil,
        vssAllowHttp: false,
        vssAllowEmptyRestore: false,
        lspBaseUrl: nil,
        lspBearerToken: nil,
        reuseAddresses: false
      )
    ) { error in
      assertInvalidArgument(error, field: "daemonListeningPort")
    }

    XCTAssertThrowsError(
      try plugin.rlnCreateNode(
        storageDirPath: uniquePath("oversized-media"),
        daemonListeningPort: 3000,
        ldkPeerListeningPort: 9735,
        network: "regtest",
        maxMediaUploadSizeMb: 65_536,
        enableVirtualChannelsV0: nil,
        virtualPeerPubkeys: nil,
        vssUrl: nil,
        vssAllowHttp: false,
        vssAllowEmptyRestore: false,
        lspBaseUrl: nil,
        lspBearerToken: nil,
        reuseAddresses: false
      )
    ) { error in
      assertInvalidArgument(error, field: "maxMediaUploadSizeMb")
    }
  }

  func testBridgeRejectsFractionalFeeRateBeforeNativeNodeLookup() {
    XCTAssertThrowsError(
      try plugin.rlnSendBtc(
        nodeId: 9_999,
        amount: 1,
        address: "bcrt1destination",
        feeRate: 1.5,
        skipSync: false
      )
    ) { error in
      let pigeon = expectPigeonError(error)
      assertInvalidArgument(error, operation: "rlnSendBtc", field: "feeRate")
      XCTAssertTrue((pigeon.message ?? "").contains("integer fee rate"))
    }
  }

  func testBridgeRejectsGroupTwoNumericBoundaryFieldsBeforeNativeNodeLookup() {
    XCTAssertThrowsError(
      try plugin.rlnOpenChannel(
        nodeId: 9_999,
        peerPubkeyAndOptAddr: "peer@127.0.0.1:9735",
        capacitySat: -1,
        pushMsat: 0,
        publicChannel: false,
        withAnchors: true,
        feeBaseMsat: nil,
        feeProportionalMillionths: nil,
        temporaryChannelId: nil,
        assetId: nil,
        assetAmount: nil,
        pushAssetAmount: nil,
        virtualOpenMode: nil
      )
    ) { error in
      assertInvalidArgument(error, operation: "rlnOpenChannel", field: "capacitySat")
    }

    XCTAssertThrowsError(
      try plugin.rlnLnInvoice(
        nodeId: 9_999,
        amtMsat: nil,
        expirySec: -1,
        assetId: nil,
        assetAmount: nil,
        paymentHash: nil,
        minFinalCltvExpiryDelta: nil,
        descriptionHash: "description-hash"
      )
    ) { error in
      assertInvalidArgument(error, operation: "rlnLnInvoice", field: "expirySec")
    }

    XCTAssertThrowsError(
      try plugin.rlnSendPayment(
        nodeId: 9_999,
        invoice: "lnbc1invoice",
        amtMsat: -1,
        assetId: nil,
        assetAmount: nil
      )
    ) { error in
      assertInvalidArgument(error, operation: "rlnSendPayment", field: "amtMsat")
    }

    XCTAssertThrowsError(
      try plugin.rlnInflate(
        nodeId: 9_999,
        assetId: "asset",
        inflationAmounts: [-1],
        feeRate: 1.0,
        minConfirmations: 1
      )
    ) { error in
      assertInvalidArgument(error, operation: "rlnInflate", field: "inflationAmounts[0]")
    }
  }

  func testRgbInvoiceRejectsUnknownAssignmentKindBeforeNativeNodeLookup() {
    XCTAssertThrowsError(
      try plugin.rlnRgbInvoice(
        nodeId: 9_999,
        assetId: "asset",
        assignmentAmount: 1,
        durationSeconds: nil,
        minConfirmations: 1,
        witness: false,
        assignmentKind: "Mystery"
      )
    ) { error in
      let pigeon = expectPigeonError(error)
      assertInvalidArgument(error, operation: "rlnRgbInvoice", field: "assignmentKind")
      XCTAssertTrue((pigeon.message ?? "").contains("Unknown assignmentKind"))
    }
  }

  func testBridgeReportsUnknownNodeForGroupTwoMethodFamilies() {
    let cases: [(String, () throws -> Void)] = [
      ("rlnInitNodeWithNativeExternalSigner", { try self.plugin.rlnInitNodeWithNativeExternalSigner(nodeId: 9_999, signerId: 8_888) }),
      ("rlnAttachNativeExternalSigner", { try self.plugin.rlnAttachNativeExternalSigner(nodeId: 9_999, signerId: 8_888) }),
      ("rlnNodeInfo", { _ = try self.plugin.rlnNodeInfo(nodeId: 9_999) }),
      ("rlnCheckIndexerUrl", { _ = try self.plugin.rlnCheckIndexerUrl(nodeId: 9_999, indexerUrl: "electrum://127.0.0.1:50001") }),
      ("rlnListPeers", { _ = try self.plugin.rlnListPeers(nodeId: 9_999) }),
      ("rlnListChannels", { _ = try self.plugin.rlnListChannels(nodeId: 9_999) }),
      ("rlnListPayments", { _ = try self.plugin.rlnListPayments(nodeId: 9_999) }),
      ("rlnVssBackup", { _ = try self.plugin.rlnVssBackup(nodeId: 9_999) }),
      ("rlnVssClearFence", { _ = try self.plugin.rlnVssClearFence(nodeId: 9_999, password: "never-log-this-password") }),
      ("rlnRotateAddress", { _ = try self.plugin.rlnRotateAddress(nodeId: 9_999) }),
      ("rlnSignMessage", { _ = try self.plugin.rlnSignMessage(nodeId: 9_999, message: "message") }),
      ("rlnVerifyMessage", { _ = try self.plugin.rlnVerifyMessage(nodeId: 9_999, message: "message", signature: "signature") }),
      ("rlnListTransactionsByTxid", { _ = try self.plugin.rlnListTransactionsByTxid(nodeId: 9_999, txid: "txid", skipSync: false) }),
      ("rlnListTransfersByTxid", { _ = try self.plugin.rlnListTransfersByTxid(nodeId: 9_999, txid: "txid") }),
    ]

    for (operation, call) in cases {
      XCTAssertThrowsError(try call()) { error in
        let pigeon = expectPigeonError(error)
        let details = expectDetails(pigeon)
        XCTAssertEqual(details["operation"] as? String, operation)
        XCTAssertEqual(pigeon.code, "NodeNotFound")
        XCTAssertEqual(details["category"] as? String, "notFound")
      }
    }
  }

  func testCreatesDiskBackedNativeExternalSigner() throws {
    let storageDirPath = uniquePath("native-signer")
    defer {
      try? FileManager.default.removeItem(atPath: storageDirPath)
    }

    let signerId: Int64
    do {
      signerId = try plugin.rlnCreateNativeExternalSigner(
        seedHex: String(repeating: "01", count: 32),
        network: "regtest",
        permissivePolicy: true,
        storageDirPath: storageDirPath
      )
    } catch {
      if let pigeon = error as? PigeonError {
        XCTFail(
          "Failed to create disk-backed native signer: "
            + "code=\(pigeon.code), message=\(pigeon.message ?? "<nil>"), "
            + "details=\(String(describing: pigeon.details))"
        )
      } else {
        XCTFail(
          "Failed to create disk-backed native signer: "
            + "\(type(of: error)): \(error)"
        )
      }
      return
    }
    defer {
      try? plugin.rlnDestroyNativeExternalSigner(signerId: signerId)
    }

    XCTAssertGreaterThan(signerId, 0)
    let attributes = try FileManager.default.attributesOfItem(atPath: storageDirPath)
    let permissions = try XCTUnwrap(
      attributes[.posixPermissions] as? NSNumber
    ).intValue
    XCTAssertEqual(permissions & 0o777, 0o700)
  }

  func testStoragePolicyCreatesOwnerOnlyDirectory() throws {
    let rootPath = uniquePath("storage-policy-create")
    let storageDirPath = "\(rootPath)/nested/node"
    defer {
      try? FileManager.default.removeItem(atPath: rootPath)
    }

    try RlnStorageDirectoryPolicy.prepare(storageDirPath)

    let attributes = try FileManager.default.attributesOfItem(atPath: storageDirPath)
    XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeDirectory)
    let permissions = try XCTUnwrap(
      attributes[.posixPermissions] as? NSNumber
    ).intValue
    XCTAssertEqual(permissions & 0o777, 0o700)
  }

  func testStoragePolicyRejectsBroadExistingDirectoryWithoutChangingIt() throws {
    let storageDirPath = uniquePath("storage-policy-broad")
    try FileManager.default.createDirectory(
      atPath: storageDirPath,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: NSNumber(value: 0o755)]
    )
    defer {
      try? FileManager.default.removeItem(atPath: storageDirPath)
    }

    XCTAssertThrowsError(try RlnStorageDirectoryPolicy.prepare(storageDirPath)) { error in
      guard let policyError = error as? RlnStorageDirectoryPolicyError else {
        XCTFail("Expected RlnStorageDirectoryPolicyError, got \(type(of: error)): \(error)")
        return
      }
      XCTAssertTrue(policyError.message.contains("mode 0700"))
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: storageDirPath)
    let permissions = try XCTUnwrap(
      attributes[.posixPermissions] as? NSNumber
    ).intValue
    XCTAssertEqual(permissions & 0o777, 0o755)
  }

  func testStoragePolicyRejectsOwnerOnlyButUnusableDirectory() throws {
    let storageDirPath = uniquePath("storage-policy-unusable")
    try FileManager.default.createDirectory(
      atPath: storageDirPath,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: NSNumber(value: 0o600)]
    )
    defer {
      try? FileManager.default.removeItem(atPath: storageDirPath)
    }

    XCTAssertThrowsError(try RlnStorageDirectoryPolicy.prepare(storageDirPath)) { error in
      guard let policyError = error as? RlnStorageDirectoryPolicyError else {
        XCTFail("Expected RlnStorageDirectoryPolicyError, got \(type(of: error)): \(error)")
        return
      }
      XCTAssertTrue(policyError.message.contains("mode 0700"))
    }
  }

  func testCreateNodeMapsUnsafeStorageToStableInvalidArgument() throws {
    let storageDirPath = uniquePath("storage-policy-plugin")
    try FileManager.default.createDirectory(
      atPath: storageDirPath,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: NSNumber(value: 0o755)]
    )
    defer {
      try? FileManager.default.removeItem(atPath: storageDirPath)
    }

    XCTAssertThrowsError(
      try plugin.rlnCreateNode(
        storageDirPath: storageDirPath,
        daemonListeningPort: 3000,
        ldkPeerListeningPort: 9735,
        network: "regtest",
        maxMediaUploadSizeMb: 5,
        enableVirtualChannelsV0: nil,
        virtualPeerPubkeys: nil,
        vssUrl: nil,
        vssAllowHttp: false,
        vssAllowEmptyRestore: false,
        lspBaseUrl: nil,
        lspBearerToken: nil,
        reuseAddresses: false
      )
    ) { error in
      let pigeon = expectPigeonError(error)
      XCTAssertEqual(pigeon.code, "invalidArgument")
      XCTAssertTrue((pigeon.message ?? "").contains("mode 0700"))

      let details = expectDetails(pigeon)
      XCTAssertEqual(details["operation"] as? String, "rlnCreateNode")
      XCTAssertEqual(details["field"] as? String, "storageDirPath")
    }
  }

  func testNodeStoreRejectsDuplicateActiveStorageAndReusesShutdownPath() throws {
    let path = uniquePath("native-store-reuse")
    let firstNode = CloseTrackingSdkNode()
    let duplicateNode = CloseTrackingSdkNode()
    let replacementNode = CloseTrackingSdkNode()
    var nodeId: Int64?
    defer {
      if let nodeId {
        plugin.nodeStore.remove(id: nodeId)
      }
    }

    let firstId = try plugin.nodeStore.create(node: firstNode, storageDirPath: path)
    nodeId = firstId
    XCTAssertIdentical(firstNode, try plugin.nodeStore.get(id: firstId))
    XCTAssertEqual(try plugin.nodeStore.getState(id: firstId), .created)

    XCTAssertThrowsError(
      try plugin.nodeStore.create(node: duplicateNode, storageDirPath: path)
    ) { error in
      guard case RlnStoreError.nodeAlreadyExists = error else {
        XCTFail("Expected nodeAlreadyExists, got \(type(of: error)): \(error)")
        return
      }
    }
    XCTAssertEqual(duplicateNode.shutdownCount, 0)

    plugin.nodeStore.markShutdown(id: firstId)
    let reusedId = try plugin.nodeStore.create(node: replacementNode, storageDirPath: path)
    XCTAssertNotEqual(reusedId, firstId)
    nodeId = reusedId
    plugin.nodeStore.remove(id: firstId)
    XCTAssertIdentical(replacementNode, try plugin.nodeStore.get(id: reusedId))
    XCTAssertEqual(try plugin.nodeStore.getState(id: reusedId), .created)
    XCTAssertEqual(firstNode.shutdownCount, 1)

    let snapshot = plugin.nodeStore.snapshot()
    XCTAssertEqual(snapshot.nodeCount, 1)
    XCTAssertEqual(snapshot.storageDirByNodeId[reusedId], path)
  }

  func testNodeStoreLifecycleAndFinalCleanupState() throws {
    let node = CloseTrackingSdkNode()
    let nodeId = try plugin.nodeStore.create(
      node: node,
      storageDirPath: uniquePath("native-store-lifecycle")
    )

    XCTAssertEqual(try plugin.nodeStore.beginUnlock(id: nodeId), .unlocking)
    plugin.nodeStore.rollbackUnlock(id: nodeId)
    XCTAssertEqual(try plugin.nodeStore.getState(id: nodeId), .created)

    try plugin.nodeStore.markInitialized(id: nodeId)
    XCTAssertEqual(try plugin.nodeStore.getState(id: nodeId), .initialized)

    XCTAssertEqual(try plugin.nodeStore.beginUnlock(id: nodeId), .unlocking)
    plugin.nodeStore.markUnlocked(id: nodeId)
    XCTAssertEqual(try plugin.nodeStore.getState(id: nodeId), .unlocked)
    XCTAssertThrowsError(try plugin.nodeStore.markInitialized(id: nodeId))

    plugin.nodeStore.markShutdown(id: nodeId)
    XCTAssertEqual(try plugin.nodeStore.getState(id: nodeId), .shutdown)
    XCTAssertThrowsError(try plugin.nodeStore.markInitialized(id: nodeId))

    plugin.nodeStore.remove(id: nodeId)
    XCTAssertThrowsError(try plugin.nodeStore.get(id: nodeId))
    XCTAssertEqual(plugin.nodeStore.snapshot().nodeCount, 0)
    XCTAssertEqual(node.shutdownCount, 0)
  }

  func testNodeStoreClearAllRemovesNodesAndSigners() throws {
    let node = CloseTrackingSdkNode()
    let signer = NativeExternalSigner(noPointer: NativeExternalSigner.NoPointer())
    let nodeId = try plugin.nodeStore.create(
      node: node,
      storageDirPath: uniquePath("native-store-clear")
    )
    let signerId = plugin.nodeStore.createSigner(signer)

    plugin.nodeStore.clearAll()

    let snapshot = plugin.nodeStore.snapshot()
    XCTAssertEqual(snapshot.nodeCount, 0)
    XCTAssertEqual(snapshot.signerCount, 0)
    XCTAssertEqual(node.shutdownCount, 1)
    XCTAssertThrowsError(try plugin.nodeStore.get(id: nodeId))
    XCTAssertThrowsError(try plugin.nodeStore.getSigner(id: signerId))
  }

  func testEngineCleanupDoesNotTouchAnotherEngine() throws {
    let other = RgbSdkFlutterPlugin()
    let mine = try plugin.nodeStore.create(node: CloseTrackingSdkNode(), storageDirPath: uniquePath("engine-a"))
    let theirs = try other.nodeStore.create(node: CloseTrackingSdkNode(), storageDirPath: uniquePath("engine-b"))
    defer { other.nodeStore.remove(id: theirs) }
    let closed = expectation(description: "engine resources released")
    plugin.closeEngine { closed.fulfill() }
    wait(for: [closed], timeout: 5)
    XCTAssertThrowsError(try plugin.nodeStore.get(id: mine))
    XCTAssertNoThrow(try other.nodeStore.get(id: theirs))
    XCTAssertThrowsError(try plugin.rlnShutdown(nodeId: mine))
  }

  func testEngineCleanupWaitsForInFlightUnlock() throws {
    let node = BlockingUnlockSdkNode()
    let owner = plugin
    let id = try owner.nodeStore.create(node: node, storageDirPath: uniquePath("unlock-drain"))
    let unlocked = expectation(description: "in-flight unlock finishes")
    let closed = expectation(description: "engine drains then clears")
    defer { node.release.signal() }
    DispatchQueue.global().async {
      do {
        try owner.rlnUnlockNode(
          nodeId: id, password: "test-only", bitcoindRpcUsername: nil,
          bitcoindRpcPassword: nil, bitcoindRpcHost: nil, bitcoindRpcPort: nil,
          indexerUrl: "electrum://127.0.0.1:50001", proxyEndpoint: nil,
          announceAddresses: [], announceAlias: nil, gossipRgsServerUrl: nil
        )
      } catch {
        XCTFail("Unexpected unlock failure: \(error)")
      }
      unlocked.fulfill()
    }
    XCTAssertEqual(node.entered.wait(timeout: .now() + 5), .success)
    owner.closeEngine { closed.fulfill() }
    XCTAssertEqual(node.cleanup.wait(timeout: .now() + 0.05), .timedOut)
    node.release.signal()
    wait(for: [unlocked, closed], timeout: 5)
    XCTAssertEqual(node.cleanup.wait(timeout: .now() + 5), .success)
    XCTAssertEqual(owner.nodeStore.snapshot().nodeCount, 0)
    XCTAssertThrowsError(try owner.rlnInitNode(nodeId: id, password: "test", mnemonic: nil))
    XCTAssertThrowsError(try owner.rlnDestroyNode(nodeId: id))
    XCTAssertThrowsError(try owner.rlnDestroyNativeExternalSigner(signerId: 1))
  }

  func testNativeEnumIdentityAndCategoryArePreserved() {
    XCTAssertEqual(rlnErrorCode(.Conflict(message: "private")), "Conflict")
    XCTAssertEqual(rlnErrorCode(.NotFound(message: "private")), "NotFound")
    XCTAssertEqual(nativeErrorCategory(rlnErrorCode(.FailedPeerConnection(message: "private"))), "network")
    XCTAssertEqual(nativeErrorCategory(rlnErrorCode(.UnsupportedInExternalSignerMode(message: "private"))), "unsupported")
  }

  private func assertChainSyncError(
    field expectedField: String,
    operation: () throws -> Void
  ) {
    XCTAssertThrowsError(try operation()) { error in
      guard case let RlnChainSyncConfigurationError.invalid(field, _) = error else {
        XCTFail("Expected RlnChainSyncConfigurationError, got \(type(of: error)): \(error)")
        return
      }
      XCTAssertEqual(field, expectedField)
    }
  }

  private func assertInvalidArgument(
    _ error: Error,
    operation: String = "rlnCreateNode",
    field: String
  ) {
    let pigeon = expectPigeonError(error)
    XCTAssertEqual(pigeon.code, "invalidArgument")

    let details = expectDetails(pigeon)
    XCTAssertEqual(details["operation"] as? String, operation)
    XCTAssertEqual(details["field"] as? String, field)
  }

  private func expectPigeonError(_ error: Error) -> PigeonError {
    guard let pigeon = error as? PigeonError else {
      XCTFail("Expected PigeonError, got \(type(of: error)): \(error)")
      return PigeonError(code: "unexpected", message: nil, details: nil)
    }
    return pigeon
  }

  private func expectDetails(_ error: PigeonError) -> [String: Any] {
    guard let details = error.details as? [String: Any] else {
      XCTFail("Expected string-keyed details, got \(String(describing: error.details))")
      return [:]
    }
    return details
  }

  private func uniquePath(_ label: String) -> String {
    "/tmp/rgb-sdk-flutter-native-test-\(label)-\(UUID().uuidString)"
  }
}

private final class CloseTrackingSdkNode: SdkNode {
  private(set) var shutdownCount = 0

  init() {
    super.init(noPointer: SdkNode.NoPointer())
  }

  required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
    super.init(unsafeFromRawPointer: pointer)
  }

  override func shutdown() {
    shutdownCount += 1
  }
}

private final class BlockingUnlockSdkNode: SdkNode {
  let entered = DispatchSemaphore(value: 0)
  let release = DispatchSemaphore(value: 0)
  let cleanup = DispatchSemaphore(value: 0)

  init() { super.init(noPointer: SdkNode.NoPointer()) }
  required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
    super.init(unsafeFromRawPointer: pointer)
  }

  override func unlock(request: SdkUnlockRequest) throws {
    entered.signal()
    XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
  }

  override func shutdown() { cleanup.signal() }
}
