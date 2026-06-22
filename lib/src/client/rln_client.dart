import '../errors/rgb_sdk_exception.dart';
import '../pigeon/rln_api.g.dart';

/// Low-level bridge over the native RGB Lightning Node `rln*` API.
///
/// This class intentionally stays close to the React Native bridge surface.
/// Prefer `UtexoWallet` for product code because it returns typed models and
/// handles wallet lifecycle checks.
class RlnClient {
  RlnClient({RlnHostApi? hostApi}) : _hostApi = hostApi ?? RlnHostApi();

  final RlnHostApi _hostApi;

  Future<int> createNode({
    required String storageDirPath,
    required int daemonListeningPort,
    required int ldkPeerListeningPort,
    required String network,
    required int maxMediaUploadSizeMb,
    bool? enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    String? vssUrl,
    bool vssAllowHttp = false,
    bool vssAllowEmptyRestore = false,
    String? lspBaseUrl,
    String? lspBearerToken,
  }) {
    return _hostApi.rlnCreateNode(
      storageDirPath,
      daemonListeningPort,
      ldkPeerListeningPort,
      network,
      maxMediaUploadSizeMb,
      enableVirtualChannelsV0,
      virtualPeerPubkeys,
      vssUrl,
      vssAllowHttp,
      vssAllowEmptyRestore,
      lspBaseUrl,
      lspBearerToken,
    );
  }

  Future<String> initNode({
    required int nodeId,
    required String password,
    String? mnemonic,
  }) {
    return _hostApi.rlnInitNode(nodeId, password, mnemonic);
  }

  Future<int> createNativeExternalSigner({
    required String seedHex,
    required String network,
    required bool permissivePolicy,
  }) {
    return _hostApi.rlnCreateNativeExternalSigner(
      seedHex,
      network,
      permissivePolicy,
    );
  }

  Future<void> initNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) {
    return _hostApi.rlnInitNodeWithNativeExternalSigner(nodeId, signerId);
  }

  Future<void> attachNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) {
    return _hostApi.rlnAttachNativeExternalSigner(nodeId, signerId);
  }

  Future<void> unlockNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses = const <String>[],
    String? announceAlias,
    String? gossipRgsServerUrl,
  }) {
    return _hostApi.rlnUnlockNodeWithNativeExternalSigner(
      nodeId,
      signerId,
      bitcoindRpcUsername,
      bitcoindRpcPassword,
      bitcoindRpcHost,
      bitcoindRpcPort,
      indexerUrl,
      proxyEndpoint,
      announceAddresses,
      announceAlias,
      gossipRgsServerUrl,
    );
  }

  Future<void> destroyNativeExternalSigner(int signerId) {
    return _hostApi.rlnDestroyNativeExternalSigner(signerId);
  }

  Future<void> initNodeWithExternalSigner({
    required int nodeId,
    required String nodePublicKeyHex,
    required String accountXpubVanilla,
    required String accountXpubColored,
    required String masterFingerprint,
    required String protocolVersion,
    required int apiLevel,
  }) {
    return _hostApi.rlnInitNodeWithExternalSigner(
      nodeId,
      nodePublicKeyHex,
      accountXpubVanilla,
      accountXpubColored,
      masterFingerprint,
      protocolVersion,
      apiLevel,
    );
  }

  Future<void> unlockNode({
    required int nodeId,
    required String password,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses = const <String>[],
    String? announceAlias,
    String? gossipRgsServerUrl,
  }) {
    return _hostApi.rlnUnlockNode(
      nodeId,
      password,
      bitcoindRpcUsername,
      bitcoindRpcPassword,
      bitcoindRpcHost,
      bitcoindRpcPort,
      indexerUrl,
      proxyEndpoint,
      announceAddresses,
      announceAlias,
      gossipRgsServerUrl,
    );
  }

  Future<void> destroyNode(int nodeId) {
    return _hostApi.rlnDestroyNode(nodeId);
  }

  Future<Map<Object?, Object?>> nodeInfo(int nodeId) {
    return _hostApi.rlnNodeInfo(nodeId);
  }

  Future<Map<Object?, Object?>> networkInfo(int nodeId) {
    return _hostApi.rlnNetworkInfo(nodeId);
  }

  Future<List<Map<Object?, Object?>>> listPeers(int nodeId) {
    return _hostApi.rlnListPeers(nodeId);
  }

  Future<void> connectPeer({
    required int nodeId,
    required String peerPubkeyAndAddr,
  }) {
    return _hostApi.rlnConnectPeer(nodeId, peerPubkeyAndAddr);
  }

  Future<void> disconnectPeer({
    required int nodeId,
    required String peerPubkey,
  }) {
    return _hostApi.rlnDisconnectPeer(nodeId, peerPubkey);
  }

  Future<List<Map<Object?, Object?>>> listChannels(int nodeId) {
    return _hostApi.rlnListChannels(nodeId);
  }

  Future<Map<Object?, Object?>> openChannel({
    required int nodeId,
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    required int pushMsat,
    required bool publicChannel,
    required bool withAnchors,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) {
    return _hostApi.rlnOpenChannel(
      nodeId,
      peerPubkeyAndOptAddr,
      capacitySat,
      pushMsat,
      publicChannel,
      withAnchors,
      feeBaseMsat,
      feeProportionalMillionths,
      temporaryChannelId,
      assetId,
      assetAmount,
      pushAssetAmount,
      virtualOpenMode,
    );
  }

  Future<void> closeChannel({
    required int nodeId,
    required String channelId,
    required String peerPubkey,
    required bool force,
  }) {
    return _hostApi.rlnCloseChannel(nodeId, channelId, peerPubkey, force);
  }

  Future<List<Map<Object?, Object?>>> listPayments(int nodeId) {
    return _hostApi.rlnListPayments(nodeId);
  }

  Future<Map<Object?, Object?>> address(int nodeId) {
    return _hostApi.rlnAddress(nodeId);
  }

  Future<Map<Object?, Object?>> assetBalance({
    required int nodeId,
    required String assetId,
  }) {
    return _hostApi.rlnAssetBalance(nodeId, assetId);
  }

  Future<void> backup({
    required int nodeId,
    required String backupPath,
    required String password,
  }) {
    return _hostApi.rlnBackup(nodeId, backupPath, password);
  }

  Future<Map<Object?, Object?>> btcBalance({
    required int nodeId,
    required bool skipSync,
  }) {
    return _hostApi.rlnBtcBalance(nodeId, skipSync);
  }

  Future<Map<Object?, Object?>> checkIndexerUrl({
    required int nodeId,
    required String indexerUrl,
  }) {
    return _hostApi.rlnCheckIndexerUrl(nodeId, indexerUrl);
  }

  Future<void> checkProxyEndpoint({
    required int nodeId,
    required String proxyEndpoint,
  }) {
    return _hostApi.rlnCheckProxyEndpoint(nodeId, proxyEndpoint);
  }

  Future<void> createUtxos({
    required int nodeId,
    required bool upTo,
    int? num,
    int? size,
    required double feeRate,
    required bool skipSync,
  }) {
    return _hostApi.rlnCreateUtxos(nodeId, upTo, num, size, feeRate, skipSync);
  }

  Future<Map<Object?, Object?>> decodeLnInvoice({
    required int nodeId,
    required String invoice,
  }) {
    return _hostApi.rlnDecodeLnInvoice(nodeId, invoice);
  }

  Future<Map<Object?, Object?>> decodeRgbInvoice({
    required int nodeId,
    required String invoice,
  }) {
    return _hostApi.rlnDecodeRgbInvoice(nodeId, invoice);
  }

  Future<Map<Object?, Object?>> estimateFee({
    required int nodeId,
    required int blocks,
  }) {
    return _hostApi.rlnEstimateFee(nodeId, blocks);
  }

  Future<Map<Object?, Object?>> failTransfers({
    required int nodeId,
    int? batchTransferIdx,
    required bool noAssetOnly,
    required bool skipSync,
  }) {
    return _hostApi.rlnFailTransfers(
      nodeId,
      batchTransferIdx,
      noAssetOnly,
      skipSync,
    );
  }

  Future<String> getChannelId({
    required int nodeId,
    required String temporaryChannelId,
  }) {
    return _hostApi.rlnGetChannelId(nodeId, temporaryChannelId);
  }

  Future<Map<Object?, Object?>> getPayment({
    required int nodeId,
    required String paymentHash,
  }) {
    return _hostApi.rlnGetPayment(nodeId, paymentHash);
  }

  Future<Map<Object?, Object?>> invoiceStatus({
    required int nodeId,
    required String invoice,
  }) {
    return _hostApi.rlnInvoiceStatus(nodeId, invoice);
  }

  Future<Map<Object?, Object?>> keysend({
    required int nodeId,
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) {
    return _hostApi.rlnKeysend(
      nodeId,
      destPubkey,
      amtMsat,
      assetId,
      assetAmount,
    );
  }

  Future<Map<Object?, Object?>> listAssets({
    required int nodeId,
    List<String> filterAssetSchemas = const <String>[],
  }) {
    return _hostApi.rlnListAssets(nodeId, filterAssetSchemas);
  }

  Future<List<Map<Object?, Object?>>> listTransactions({
    required int nodeId,
    required bool skipSync,
  }) {
    return _hostApi.rlnListTransactions(nodeId, skipSync);
  }

  Future<List<Map<Object?, Object?>>> listTransfers({
    required int nodeId,
    required String assetId,
  }) {
    return _hostApi.rlnListTransfers(nodeId, assetId);
  }

  Future<List<Map<Object?, Object?>>> listUnspents({
    required int nodeId,
    required bool skipSync,
  }) {
    return _hostApi.rlnListUnspents(nodeId, skipSync);
  }

  Future<Map<Object?, Object?>> lnInvoice({
    required int nodeId,
    int? amtMsat,
    required int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
  }) {
    return _hostApi.rlnLnInvoice(
      nodeId,
      amtMsat,
      expirySec,
      assetId,
      assetAmount,
      paymentHash,
      minFinalCltvExpiryDelta,
    );
  }

  Future<Map<Object?, Object?>> claimHodlInvoice({
    required int nodeId,
    required String paymentHash,
    required String paymentPreimage,
  }) {
    return _hostApi.rlnClaimHodlInvoice(nodeId, paymentHash, paymentPreimage);
  }

  Future<void> cancelHodlInvoice({
    required int nodeId,
    required String paymentHash,
  }) {
    return _hostApi.rlnCancelHodlInvoice(nodeId, paymentHash);
  }

  Future<Map<Object?, Object?>> apayNew({
    required int nodeId,
    required String hostNodeId,
  }) {
    return _hostApi.rlnApayNew(nodeId, hostNodeId);
  }

  Future<Map<Object?, Object?>> apayNewWithAddress({
    required int nodeId,
    required String hostNodeId,
    required String username,
    required String domain,
  }) {
    return _hostApi.rlnApayNewWithAddress(nodeId, hostNodeId, username, domain);
  }

  Future<void> refreshTransfers({required int nodeId, required bool skipSync}) {
    return _hostApi.rlnRefreshTransfers(nodeId, skipSync);
  }

  Future<Map<Object?, Object?>> rgbInvoice({
    required int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    required int minConfirmations,
    required bool witness,
  }) {
    return _hostApi.rlnRgbInvoice(
      nodeId,
      assetId,
      assignmentAmount,
      durationSeconds,
      minConfirmations,
      witness,
    );
  }

  Future<Map<Object?, Object?>> sendBtc({
    required int nodeId,
    required int amount,
    required String address,
    required double feeRate,
    required bool skipSync,
  }) {
    return _hostApi.rlnSendBtc(nodeId, amount, address, feeRate, skipSync);
  }

  Future<Map<Object?, Object?>> sendPayment({
    required int nodeId,
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) {
    return _hostApi.rlnSendPayment(
      nodeId,
      invoice,
      amtMsat,
      assetId,
      assetAmount,
    );
  }

  Future<Map<Object?, Object?>> sendRgb({
    required int nodeId,
    required bool donation,
    required double feeRate,
    required int minConfirmations,
    required bool skipSync,
    required String assetId,
    required String recipientId,
    required int amount,
    required List<String> transportEndpoints,
    int? witnessAmountSat,
    int? witnessBlinding,
  }) {
    if (skipSync) {
      throw const UnsupportedWalletFeatureException(
        'rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.',
        feature: 'rlnSendRgb.skipSync',
      );
    }
    return _hostApi.rlnSendRgb(
      nodeId,
      donation,
      feeRate,
      minConfirmations,
      skipSync,
      assetId,
      recipientId,
      amount,
      transportEndpoints,
      witnessAmountSat,
      witnessBlinding,
    );
  }

  Future<void> shutdown(int nodeId) {
    return _hostApi.rlnShutdown(nodeId);
  }

  Future<void> sync(int nodeId) {
    return _hostApi.rlnSync(nodeId);
  }

  Future<Object?> issueAssetNia({
    required int nodeId,
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) {
    return _hostApi.rlnIssueAssetNia(nodeId, ticker, name, precision, amounts);
  }

  Future<Object?> issueAssetCfa({
    required int nodeId,
    required String name,
    String? details,
    required int precision,
    required List<int> amounts,
    String? fileDigest,
  }) {
    return _hostApi.rlnIssueAssetCfa(
      nodeId,
      name,
      details,
      precision,
      amounts,
      fileDigest,
    );
  }

  Future<Object?> issueAssetIfa({
    required int nodeId,
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) {
    return _hostApi.rlnIssueAssetIfa(
      nodeId,
      ticker,
      name,
      precision,
      amounts,
      inflationAmounts,
      rejectListUrl,
    );
  }

  Future<Object?> issueAssetUda({
    required int nodeId,
    required String ticker,
    required String name,
    String? details,
    required int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests = const <String>[],
  }) {
    return _hostApi.rlnIssueAssetUda(
      nodeId,
      ticker,
      name,
      details,
      precision,
      mediaFileDigest,
      attachmentsFileDigests,
    );
  }

  Future<void> vssClearFence({required int nodeId, required String password}) {
    return _hostApi.rlnVssClearFence(nodeId, password);
  }
}
