import XCTest

@testable import rgb_sdk_flutter

final class RunnerTests: XCTestCase {
  private let plugin = RgbSdkFlutterPlugin()

  func testNativeArtifactInfoMatchesPinnedIOSArtifact() throws {
    let info = try plugin.getNativeArtifactInfo()

    XCTAssertEqual(info.platform, "ios")
    XCTAssertEqual(info.rlnVersion, "0.6.0-beta.2")
    XCTAssertEqual(info.reactNativeParityVersion, "1.0.0-beta.19")
    XCTAssertEqual(info.bridge, "pigeon-bootstrap")
    XCTAssertEqual(info.nativeArtifact, "rgb-lightning-node-swift-0.6.0-beta.2.zip")
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
        lspBearerToken: nil
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
        lspBearerToken: nil
      )
    ) { error in
      assertInvalidArgument(error, field: "maxMediaUploadSizeMb")
    }
  }

  private func assertInvalidArgument(_ error: Error, field: String) {
    let pigeon = expectPigeonError(error)
    XCTAssertEqual(pigeon.code, "invalidArgument")

    let details = expectDetails(pigeon)
    XCTAssertEqual(details["operation"] as? String, "rlnCreateNode")
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
