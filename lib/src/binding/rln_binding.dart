import '../client/rln_client.dart';
import '../errors/rgb_sdk_exception.dart';
import '../models/rln_models.dart';

class IRLNNodeCreateParams {
  const IRLNNodeCreateParams({
    required this.storageDirPath,
    required this.daemonListeningPort,
    required this.ldkPeerListeningPort,
    required this.network,
    required this.maxMediaUploadSizeMb,
    this.enableVirtualChannelsV0,
    this.virtualPeerPubkeys,
    this.vssUrl,
    this.vssAllowHttp = false,
    this.vssAllowEmptyRestore = false,
    this.lspBaseUrl,
    this.lspBearerToken,
  });

  final String storageDirPath;
  final int daemonListeningPort;
  final int ldkPeerListeningPort;
  final String network;
  final int maxMediaUploadSizeMb;
  final bool? enableVirtualChannelsV0;
  final List<String>? virtualPeerPubkeys;
  final String? vssUrl;
  final bool vssAllowHttp;
  final bool vssAllowEmptyRestore;
  final String? lspBaseUrl;
  final String? lspBearerToken;
}

class IRLNUnlockParams {
  const IRLNUnlockParams({
    this.bitcoindRpcUsername,
    this.bitcoindRpcPassword,
    this.bitcoindRpcHost,
    this.bitcoindRpcPort,
    this.indexerUrl,
    this.proxyEndpoint,
    this.announceAddresses = const <String>[],
    this.announceAlias,
    this.gossipRgsServerUrl,
  });

  final String? bitcoindRpcUsername;
  final String? bitcoindRpcPassword;
  final String? bitcoindRpcHost;
  final int? bitcoindRpcPort;
  final String? indexerUrl;
  final String? proxyEndpoint;
  final List<String> announceAddresses;
  final String? announceAlias;
  final String? gossipRgsServerUrl;
}

class IRLNExternalSignerBootstrap {
  const IRLNExternalSignerBootstrap({
    required this.nodePublicKeyHex,
    required this.accountXpubVanilla,
    required this.accountXpubColored,
    required this.masterFingerprint,
    required this.protocolVersion,
    required this.apiLevel,
  });

  final String nodePublicKeyHex;
  final String accountXpubVanilla;
  final String accountXpubColored;
  final String masterFingerprint;
  final String protocolVersion;
  final int apiLevel;
}

class RlnOpenChannelRequest {
  const RlnOpenChannelRequest({
    required this.peerPubkeyAndOptAddr,
    required this.capacitySat,
    required this.pushMsat,
    required this.public,
    required this.withAnchors,
    this.feeBaseMsat,
    this.feeProportionalMillionths,
    this.temporaryChannelId,
    this.assetId,
    this.assetAmount,
    this.pushAssetAmount,
    this.virtualOpenMode,
  });

  final String peerPubkeyAndOptAddr;
  final int capacitySat;
  final int pushMsat;
  final bool public;
  final bool withAnchors;
  final int? feeBaseMsat;
  final int? feeProportionalMillionths;
  final String? temporaryChannelId;
  final String? assetId;
  final int? assetAmount;
  final int? pushAssetAmount;
  final String? virtualOpenMode;
}

class RlnWitnessData {
  const RlnWitnessData({required this.amountSat, this.blinding});

  final int amountSat;
  final int? blinding;
}

enum _RlnLifecycleState { idle, active, shuttingDown, destroying }

class RLNBinding {
  RLNBinding({RlnClient? client}) : _client = client ?? RlnClient();

  final RlnClient _client;
  Future<void> _nodeOperationQueue = Future<void>.value();
  int? _rlnNodeId;
  bool _unlockConflictNormalized = false;
  _RlnLifecycleState _lifecycleState = _RlnLifecycleState.idle;

  int? get rlnNodeId => _rlnNodeId;

  Future<T> _withNodeQueue<T>(Future<T> Function() operation) {
    final previous = _nodeOperationQueue;
    final next = previous.then((_) => operation());
    _nodeOperationQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<T> _withNodeOperation<T>(Future<T> Function(int nodeId) operation) {
    return _withNodeQueue(() {
      final nodeId = _requireNodeId();
      _assertRegularOpsAllowed();
      return operation(nodeId);
    });
  }

  int _requireNodeId() {
    final nodeId = _rlnNodeId;
    if (nodeId == null) {
      throw const WalletError('RLN node is not created');
    }
    return nodeId;
  }

  void _assertRegularOpsAllowed() {
    if (_lifecycleState == _RlnLifecycleState.shuttingDown ||
        _lifecycleState == _RlnLifecycleState.destroying) {
      throw const WalletError('RLN node is shutting down or destroying');
    }
  }

  bool _isConflictError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('already') ||
        text.contains('conflict') ||
        text.contains('in use') ||
        text.contains('busy');
  }

  Future<bool> _probeNodeReady(int nodeId) async {
    try {
      await _client.nodeInfo(nodeId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> rlnCreateNode(IRLNNodeCreateParams params) {
    return _withNodeQueue(() async {
      if (_rlnNodeId != null) {
        throw const WalletError('RLN node is already created');
      }
      final nodeId = await _client.createNode(
        storageDirPath: params.storageDirPath,
        daemonListeningPort: params.daemonListeningPort,
        ldkPeerListeningPort: params.ldkPeerListeningPort,
        network: params.network,
        maxMediaUploadSizeMb: params.maxMediaUploadSizeMb,
        enableVirtualChannelsV0: params.enableVirtualChannelsV0,
        virtualPeerPubkeys: params.virtualPeerPubkeys,
        vssUrl: params.vssUrl,
        vssAllowHttp: params.vssAllowHttp,
        vssAllowEmptyRestore: params.vssAllowEmptyRestore,
        lspBaseUrl: params.lspBaseUrl,
        lspBearerToken: params.lspBearerToken,
      );
      _rlnNodeId = nodeId;
      _lifecycleState = _RlnLifecycleState.active;
      return nodeId;
    });
  }

  Future<String> rlnInitNode(String password, [String? mnemonic]) {
    return _withNodeOperation(
      (nodeId) => _client.initNode(
        nodeId: nodeId,
        password: password,
        mnemonic: mnemonic,
      ),
    );
  }

  Future<void> rlnUnlockNode({
    required String password,
    IRLNUnlockParams params = const IRLNUnlockParams(),
  }) {
    return _withNodeQueue(() async {
      final nodeId = _requireNodeId();
      _assertRegularOpsAllowed();
      _unlockConflictNormalized = false;
      if (await _probeNodeReady(nodeId)) return;
      try {
        await _client.unlockNode(
          nodeId: nodeId,
          password: password,
          bitcoindRpcUsername: params.bitcoindRpcUsername,
          bitcoindRpcPassword: params.bitcoindRpcPassword,
          bitcoindRpcHost: params.bitcoindRpcHost,
          bitcoindRpcPort: params.bitcoindRpcPort,
          indexerUrl: params.indexerUrl,
          proxyEndpoint: params.proxyEndpoint,
          announceAddresses: params.announceAddresses,
          announceAlias: params.announceAlias,
          gossipRgsServerUrl: params.gossipRgsServerUrl,
        );
      } catch (error) {
        if (!_isConflictError(error) || !await _probeNodeReady(nodeId)) {
          rethrow;
        }
        _unlockConflictNormalized = true;
      }
    });
  }

  Future<void> rlnShutdown() {
    return _withNodeQueue(() async {
      final nodeId = _requireNodeId();
      _lifecycleState = _RlnLifecycleState.shuttingDown;
      try {
        await _client.shutdown(nodeId);
      } catch (_) {
        _lifecycleState = _RlnLifecycleState.active;
        rethrow;
      }
    });
  }

  Future<void> rlnDestroyNode() {
    return _withNodeQueue(() async {
      final nodeId = _rlnNodeId;
      if (nodeId == null) return;
      _lifecycleState = _RlnLifecycleState.destroying;
      try {
        await _client.destroyNode(nodeId);
        _rlnNodeId = null;
        _lifecycleState = _RlnLifecycleState.idle;
      } catch (_) {
        _lifecycleState = _RlnLifecycleState.active;
        rethrow;
      }
    });
  }

  bool consumeRlnUnlockConflictNormalized() {
    final normalized = _unlockConflictNormalized;
    _unlockConflictNormalized = false;
    return normalized;
  }

  Future<int> rlnCreateNativeExternalSigner(
    String seedHex,
    String network, {
    bool permissivePolicy = true,
  }) {
    return _withNodeQueue(
      () => _client.createNativeExternalSigner(
        seedHex: seedHex,
        network: network,
        permissivePolicy: permissivePolicy,
      ),
    );
  }

  Future<void> rlnInitNodeWithNativeExternalSigner(int signerId) {
    return _withNodeOperation(
      (nodeId) => _client.initNodeWithNativeExternalSigner(
        nodeId: nodeId,
        signerId: signerId,
      ),
    );
  }

  Future<void> rlnAttachNativeExternalSigner(int signerId) {
    return _withNodeOperation(
      (nodeId) => _client.attachNativeExternalSigner(
        nodeId: nodeId,
        signerId: signerId,
      ),
    );
  }

  Future<void> rlnUnlockNodeWithNativeExternalSigner(
    int signerId, [
    IRLNUnlockParams params = const IRLNUnlockParams(),
  ]) {
    return _withNodeQueue(() async {
      final nodeId = _requireNodeId();
      _assertRegularOpsAllowed();
      _unlockConflictNormalized = false;
      if (await _probeNodeReady(nodeId)) return;
      try {
        await _client.unlockNodeWithNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
          bitcoindRpcUsername: params.bitcoindRpcUsername,
          bitcoindRpcPassword: params.bitcoindRpcPassword,
          bitcoindRpcHost: params.bitcoindRpcHost,
          bitcoindRpcPort: params.bitcoindRpcPort,
          indexerUrl: params.indexerUrl,
          proxyEndpoint: params.proxyEndpoint,
          announceAddresses: params.announceAddresses,
          announceAlias: params.announceAlias,
          gossipRgsServerUrl: params.gossipRgsServerUrl,
        );
      } catch (error) {
        if (!_isConflictError(error) || !await _probeNodeReady(nodeId)) {
          rethrow;
        }
        _unlockConflictNormalized = true;
      }
    });
  }

  Future<void> rlnDestroyNativeExternalSigner(int signerId) {
    return _withNodeQueue(() => _client.destroyNativeExternalSigner(signerId));
  }

  Future<void> rlnInitNodeWithExternalSigner(
    IRLNExternalSignerBootstrap bootstrap,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.initNodeWithExternalSigner(
        nodeId: nodeId,
        nodePublicKeyHex: bootstrap.nodePublicKeyHex,
        accountXpubVanilla: bootstrap.accountXpubVanilla,
        accountXpubColored: bootstrap.accountXpubColored,
        masterFingerprint: bootstrap.masterFingerprint,
        protocolVersion: bootstrap.protocolVersion,
        apiLevel: bootstrap.apiLevel,
      ),
    );
  }

  Future<RlnNodeInfo> rlnNodeInfo() async {
    return RlnNodeInfo.fromMap(await _withNodeOperation(_client.nodeInfo));
  }

  Future<RlnNetworkInfo> rlnNetworkInfo() async {
    return RlnNetworkInfo.fromMap(
      await _withNodeOperation(_client.networkInfo),
    );
  }

  Future<void> rlnConnectPeer(String peerPubkeyAndAddr) {
    return _withNodeOperation(
      (nodeId) => _client.connectPeer(
        nodeId: nodeId,
        peerPubkeyAndAddr: peerPubkeyAndAddr,
      ),
    );
  }

  Future<List<RlnPeer>> rlnListPeers() async {
    final peers = await _withNodeOperation(_client.listPeers);
    return peers.map(RlnPeer.fromMap).toList(growable: false);
  }

  Future<void> rlnDisconnectPeer(String peerPubkey) {
    return _withNodeOperation(
      (nodeId) =>
          _client.disconnectPeer(nodeId: nodeId, peerPubkey: peerPubkey),
    );
  }

  Future<List<RlnChannel>> rlnListChannels() async {
    final channels = await _withNodeOperation(_client.listChannels);
    return channels.map(RlnChannel.fromMap).toList(growable: false);
  }

  Future<RlnOpenChannelResult> rlnOpenChannel(RlnOpenChannelRequest request) {
    return _withNodeOperation(
      (nodeId) async => RlnOpenChannelResult.fromMap(
        await _client.openChannel(
          nodeId: nodeId,
          peerPubkeyAndOptAddr: request.peerPubkeyAndOptAddr,
          capacitySat: request.capacitySat,
          pushMsat: request.pushMsat,
          publicChannel: request.public,
          withAnchors: request.withAnchors,
          feeBaseMsat: request.feeBaseMsat,
          feeProportionalMillionths: request.feeProportionalMillionths,
          temporaryChannelId: request.temporaryChannelId,
          assetId: request.assetId,
          assetAmount: request.assetAmount,
          pushAssetAmount: request.pushAssetAmount,
          virtualOpenMode: request.virtualOpenMode,
        ),
      ),
    );
  }

  Future<void> rlnCloseChannel(
    String channelId,
    String peerPubkey,
    bool force,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.closeChannel(
        nodeId: nodeId,
        channelId: channelId,
        peerPubkey: peerPubkey,
        force: force,
      ),
    );
  }

  Future<String> rlnGetChannelId(String temporaryChannelId) {
    return _withNodeOperation(
      (nodeId) => _client.getChannelId(
        nodeId: nodeId,
        temporaryChannelId: temporaryChannelId,
      ),
    );
  }

  Future<List<RlnPayment>> rlnListPayments() async {
    final payments = await _withNodeOperation(_client.listPayments);
    return payments.map(RlnPayment.fromMap).toList(growable: false);
  }

  Future<RlnPayment> rlnGetPayment(String paymentHash) async {
    return RlnPayment.fromMap(
      await _withNodeOperation(
        (nodeId) =>
            _client.getPayment(nodeId: nodeId, paymentHash: paymentHash),
      ),
    );
  }

  Future<RlnInvoiceStatus> rlnInvoiceStatus(String invoice) async {
    return RlnInvoiceStatus.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.invoiceStatus(nodeId: nodeId, invoice: invoice),
      ),
    );
  }

  Future<RlnLnInvoice> rlnLnInvoice(
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount, {
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
  }) async {
    return RlnLnInvoice.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.lnInvoice(
          nodeId: nodeId,
          amtMsat: amtMsat,
          expirySec: expirySec,
          assetId: assetId,
          assetAmount: assetAmount,
          paymentHash: paymentHash,
          minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
        ),
      ),
    );
  }

  Future<RlnMap> rlnClaimHodlInvoice(
    String paymentHash,
    String paymentPreimage,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.claimHodlInvoice(
        nodeId: nodeId,
        paymentHash: paymentHash,
        paymentPreimage: paymentPreimage,
      ),
    );
  }

  Future<void> rlnCancelHodlInvoice(String paymentHash) {
    return _withNodeOperation(
      (nodeId) =>
          _client.cancelHodlInvoice(nodeId: nodeId, paymentHash: paymentHash),
    );
  }

  Future<RlnMap> rlnApayNew(String hostNodeId) {
    return _withNodeOperation(
      (nodeId) => _client.apayNew(nodeId: nodeId, hostNodeId: hostNodeId),
    );
  }

  Future<RlnMap> rlnApayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.apayNewWithAddress(
        nodeId: nodeId,
        hostNodeId: hostNodeId,
        username: username,
        domain: domain,
      ),
    );
  }

  Future<RlnDecodedLnInvoice> rlnDecodeLnInvoice(String invoice) async {
    return RlnDecodedLnInvoice.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.decodeLnInvoice(nodeId: nodeId, invoice: invoice),
      ),
    );
  }

  Future<RlnDecodedRgbInvoice> rlnDecodeRgbInvoice(String invoice) async {
    return RlnDecodedRgbInvoice.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.decodeRgbInvoice(nodeId: nodeId, invoice: invoice),
      ),
    );
  }

  Future<RlnPaymentResult> rlnSendPayment(
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    return RlnPaymentResult.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.sendPayment(
          nodeId: nodeId,
          invoice: invoice,
          amtMsat: amtMsat,
          assetId: assetId,
          assetAmount: assetAmount,
        ),
      ),
    );
  }

  Future<RlnPaymentResult> rlnKeysend(
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    return RlnPaymentResult.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.keysend(
          nodeId: nodeId,
          destPubkey: destPubkey,
          amtMsat: amtMsat,
          assetId: assetId,
          assetAmount: assetAmount,
        ),
      ),
    );
  }

  Future<RlnMap> rlnAddress() {
    return _withNodeOperation(_client.address);
  }

  Future<RlnBtcBalance> rlnBtcBalance([bool skipSync = false]) async {
    return RlnBtcBalance.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.btcBalance(nodeId: nodeId, skipSync: skipSync),
      ),
    );
  }

  Future<RlnMap> rlnSendBtc(
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.sendBtc(
        nodeId: nodeId,
        amount: amount,
        address: address,
        feeRate: feeRate,
        skipSync: skipSync,
      ),
    );
  }

  Future<Object?> rlnIssueAssetNia(
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.issueAssetNia(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        precision: precision,
        amounts: amounts,
      ),
    );
  }

  Future<Object?> rlnIssueAssetCfa(
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.issueAssetCfa(
        nodeId: nodeId,
        name: name,
        details: details,
        precision: precision,
        amounts: amounts,
        fileDigest: fileDigest,
      ),
    );
  }

  Future<Object?> rlnIssueAssetIfa(
    String ticker,
    String name,
    int precision,
    List<int> amounts,
    List<int> inflationAmounts,
    String? rejectListUrl,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.issueAssetIfa(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        precision: precision,
        amounts: amounts,
        inflationAmounts: inflationAmounts,
        rejectListUrl: rejectListUrl,
      ),
    );
  }

  Future<Object?> rlnIssueAssetUda(
    String ticker,
    String name,
    String? details,
    int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.issueAssetUda(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        details: details,
        precision: precision,
        mediaFileDigest: mediaFileDigest,
        attachmentsFileDigests: attachmentsFileDigests,
      ),
    );
  }

  Future<RlnAssets> rlnListAssets(List<String> filterAssetSchemas) async {
    return RlnAssets.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.listAssets(
          nodeId: nodeId,
          filterAssetSchemas: filterAssetSchemas,
        ),
      ),
    );
  }

  Future<RlnAssetBalance> rlnAssetBalance(String assetId) async {
    return RlnAssetBalance.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.assetBalance(nodeId: nodeId, assetId: assetId),
      ),
    );
  }

  Future<RlnInvoice> rlnRgbInvoice(
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness,
  ) async {
    return RlnInvoice.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.rgbInvoice(
          nodeId: nodeId,
          assetId: assetId,
          assignmentAmount: assignmentAmount,
          durationSeconds: durationSeconds,
          minConfirmations: minConfirmations,
          witness: witness,
        ),
      ),
    );
  }

  Future<RlnSendResult> rlnSendRgb(
    bool donation,
    double feeRate,
    int minConfirmations,
    bool skipSync,
    String assetId,
    String recipientId,
    int amount,
    List<String> transportEndpoints, [
    RlnWitnessData? witnessData,
  ]) async {
    return RlnSendResult.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.sendRgb(
          nodeId: nodeId,
          donation: donation,
          feeRate: feeRate,
          minConfirmations: minConfirmations,
          skipSync: skipSync,
          assetId: assetId,
          recipientId: recipientId,
          amount: amount,
          transportEndpoints: transportEndpoints,
          witnessAmountSat: witnessData?.amountSat,
          witnessBlinding: witnessData?.blinding,
        ),
      ),
    );
  }

  Future<List<RlnTransaction>> rlnListTransactions(bool skipSync) async {
    final transactions = await _withNodeOperation(
      (nodeId) => _client.listTransactions(nodeId: nodeId, skipSync: skipSync),
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<RlnTransfer>> rlnListTransfers(String assetId) async {
    final transfers = await _withNodeOperation(
      (nodeId) => _client.listTransfers(nodeId: nodeId, assetId: assetId),
    );
    return transfers.map(RlnTransfer.fromMap).toList(growable: false);
  }

  Future<List<RlnUnspent>> rlnListUnspents(bool skipSync) async {
    final unspents = await _withNodeOperation(
      (nodeId) => _client.listUnspents(nodeId: nodeId, skipSync: skipSync),
    );
    return unspents.map(RlnUnspent.fromMap).toList(growable: false);
  }

  Future<void> rlnRefreshTransfers(bool skipSync) {
    return _withNodeOperation(
      (nodeId) => _client.refreshTransfers(nodeId: nodeId, skipSync: skipSync),
    );
  }

  Future<RlnMap> rlnFailTransfers(
    int? batchTransferIdx,
    bool noAssetOnly,
    bool skipSync,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.failTransfers(
        nodeId: nodeId,
        batchTransferIdx: batchTransferIdx,
        noAssetOnly: noAssetOnly,
        skipSync: skipSync,
      ),
    );
  }

  Future<RlnFeeRate> rlnEstimateFee(int blocks) async {
    return RlnFeeRate.fromMap(
      await _withNodeOperation(
        (nodeId) => _client.estimateFee(nodeId: nodeId, blocks: blocks),
      ),
    );
  }

  Future<RlnIndexerCheck> rlnCheckIndexerUrl(String indexerUrl) async {
    return RlnIndexerCheck.fromMap(
      await _withNodeOperation(
        (nodeId) =>
            _client.checkIndexerUrl(nodeId: nodeId, indexerUrl: indexerUrl),
      ),
    );
  }

  Future<void> rlnCheckProxyEndpoint(String proxyEndpoint) {
    return _withNodeOperation(
      (nodeId) => _client.checkProxyEndpoint(
        nodeId: nodeId,
        proxyEndpoint: proxyEndpoint,
      ),
    );
  }

  Future<void> rlnSync() {
    return _withNodeOperation(_client.sync);
  }

  Future<void> rlnCreateUtxos(
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) {
    return _withNodeOperation(
      (nodeId) => _client.createUtxos(
        nodeId: nodeId,
        upTo: upTo,
        num: num,
        size: size,
        feeRate: feeRate,
        skipSync: skipSync,
      ),
    );
  }

  Future<void> rlnBackup(String backupPath, String password) {
    return _withNodeOperation(
      (nodeId) => _client.backup(
        nodeId: nodeId,
        backupPath: backupPath,
        password: password,
      ),
    );
  }

  Future<void> rlnVssClearFence(String password) {
    return _withNodeOperation(
      (nodeId) => _client.vssClearFence(nodeId: nodeId, password: password),
    );
  }
}
