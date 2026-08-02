import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon/rln_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.utexo.rgb_sdk_flutter'),
    swiftOut: 'ios/Classes/RlnApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'rgb_sdk_flutter',
  ),
)
class RlnNativeArtifactInfo {
  RlnNativeArtifactInfo({
    required this.platform,
    required this.rlnVersion,
    required this.reactNativeParityVersion,
    required this.bridge,
    required this.nativeArtifact,
  });

  String platform;
  String rlnVersion;
  String reactNativeParityVersion;
  String bridge;
  String nativeArtifact;
}

@HostApi()
abstract class RlnHostApi {
  RlnNativeArtifactInfo getNativeArtifactInfo();

  int rlnCreateNode(
    String storageDirPath,
    int daemonListeningPort,
    int ldkPeerListeningPort,
    String network,
    int maxMediaUploadSizeMb,
    bool? enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    String? vssUrl,
    bool vssAllowHttp,
    bool vssAllowEmptyRestore,
    String? lspBaseUrl,
    String? lspBearerToken,
    bool reuseAddresses,
  );

  String rlnInitNode(int nodeId, String password, String? mnemonic);

  int rlnCreateNativeExternalSigner(
    String seedHex,
    String network,
    bool permissivePolicy,
    String? storageDirPath,
  );

  void rlnInitNodeWithNativeExternalSigner(int nodeId, int signerId);

  void rlnAttachNativeExternalSigner(int nodeId, int signerId);

  void rlnUnlockNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
  );

  void rlnDestroyNativeExternalSigner(int signerId);

  void rlnInitNodeWithExternalSigner(
    int nodeId,
    String nodePublicKeyHex,
    String accountXpubVanilla,
    String accountXpubColored,
    String masterFingerprint,
    String protocolVersion,
    int apiLevel,
  );

  void rlnUnlockNode(
    int nodeId,
    String password,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
  );

  void rlnDestroyNode(int nodeId);

  Map<Object?, Object?> rlnNodeInfo(int nodeId);

  Map<Object?, Object?> rlnNetworkInfo(int nodeId);

  List<Map<Object?, Object?>> rlnListPeers(int nodeId);

  void rlnConnectPeer(int nodeId, String peerPubkeyAndAddr);

  void rlnDisconnectPeer(int nodeId, String peerPubkey);

  List<Map<Object?, Object?>> rlnListChannels(int nodeId);

  Map<Object?, Object?> rlnOpenChannel(
    int nodeId,
    String peerPubkeyAndOptAddr,
    int capacitySat,
    int pushMsat,
    bool publicChannel,
    bool withAnchors,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  );

  void rlnCloseChannel(
    int nodeId,
    String channelId,
    String peerPubkey,
    bool force,
  );

  List<Map<Object?, Object?>> rlnListPayments(int nodeId);

  Map<Object?, Object?> rlnAddress(int nodeId);

  Map<Object?, Object?> rlnRotateAddress(int nodeId);

  Map<Object?, Object?> rlnSignMessage(int nodeId, String message);

  Map<Object?, Object?> rlnVerifyMessage(
    int nodeId,
    String message,
    String signature,
  );

  Map<Object?, Object?> rlnAssetBalance(int nodeId, String assetId);

  void rlnBackup(int nodeId, String backupPath, String password);

  Map<Object?, Object?> rlnBtcBalance(int nodeId, bool skipSync);

  Map<Object?, Object?> rlnCheckIndexerUrl(int nodeId, String indexerUrl);

  void rlnCheckProxyEndpoint(int nodeId, String proxyEndpoint);

  void rlnCreateUtxos(
    int nodeId,
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  );

  Map<Object?, Object?> rlnDecodeLnInvoice(int nodeId, String invoice);

  Map<Object?, Object?> rlnDecodeRgbInvoice(int nodeId, String invoice);

  Map<Object?, Object?> rlnEstimateFee(int nodeId, int blocks);

  Map<Object?, Object?> rlnFailTransfers(
    int nodeId,
    int? batchTransferIdx,
    bool noAssetOnly,
    bool skipSync,
  );

  String rlnGetChannelId(int nodeId, String temporaryChannelId);

  Map<Object?, Object?> rlnGetPayment(int nodeId, String paymentHash);

  Map<Object?, Object?> rlnInvoiceStatus(int nodeId, String invoice);

  Map<Object?, Object?> rlnKeysend(
    int nodeId,
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  );

  Map<Object?, Object?> rlnListAssets(
    int nodeId,
    List<String> filterAssetSchemas,
  );

  List<Map<Object?, Object?>> rlnListTransactions(int nodeId, bool skipSync);

  List<Map<Object?, Object?>> rlnListTransactionsByTxid(
    int nodeId,
    String txid,
    bool skipSync,
  );

  List<Map<Object?, Object?>> rlnListTransfers(int nodeId, String assetId);

  List<Map<Object?, Object?>> rlnListTransfersByTxid(int nodeId, String txid);

  List<Map<Object?, Object?>> rlnListUnspents(int nodeId, bool skipSync);

  Map<Object?, Object?> rlnLnInvoice(
    int nodeId,
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  );

  Map<Object?, Object?> rlnClaimHodlInvoice(
    int nodeId,
    String paymentHash,
    String paymentPreimage,
  );

  void rlnCancelHodlInvoice(int nodeId, String paymentHash);

  Map<Object?, Object?> rlnApayNew(int nodeId, String hostNodeId);

  Map<Object?, Object?> rlnApayNewWithAddress(
    int nodeId,
    String hostNodeId,
    String username,
    String domain,
  );

  void rlnRefreshTransfers(int nodeId, bool skipSync);

  Map<Object?, Object?> rlnRgbInvoice(
    int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness,
    String? assignmentKind,
  );

  Map<Object?, Object?> rlnSendBtc(
    int nodeId,
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  );

  Map<Object?, Object?> rlnSendPayment(
    int nodeId,
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  );

  Map<Object?, Object?> rlnSendRgb(
    int nodeId,
    bool donation,
    double feeRate,
    int minConfirmations,
    bool skipSync,
    String assetId,
    String recipientId,
    int amount,
    List<String> transportEndpoints,
    int? witnessAmountSat,
    int? witnessBlinding,
  );

  void rlnShutdown(int nodeId);

  void rlnSync(int nodeId);

  Object? rlnIssueAssetNia(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  );

  Object? rlnIssueAssetCfa(
    int nodeId,
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  );

  Object? rlnIssueAssetIfa(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
    List<int> inflationAmounts,
    String? rejectListUrl,
  );

  Map<Object?, Object?> rlnInflate(
    int nodeId,
    String assetId,
    List<int> inflationAmounts,
    double feeRate,
    int minConfirmations,
  );

  Object? rlnIssueAssetUda(
    int nodeId,
    String ticker,
    String name,
    String? details,
    int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests,
  );

  int rlnVssBackup(int nodeId);

  void rlnVssClearFence(int nodeId, String password);
}
