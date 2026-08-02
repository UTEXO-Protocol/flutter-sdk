import 'package:flutter/services.dart';

import '../client/rln_client.dart';
import '../errors/rgb_sdk_exception.dart';
import '../lsp/lsp_types.dart';
import '../lsp/utexo_lsp.dart';
import '../lsp/utexo_lsp_client.dart';
import '../models/rln_models.dart';
import '../models/utexo_core_models.dart';
import 'network_defaults.dart';
import 'rln_signers.dart';

/// Configuration used to create an RLN node.
class UtexoWalletConfig {
  const UtexoWalletConfig({
    required this.storageDirPath,
    this.network = 'regtest',
    this.daemonListeningPort = 9735,
    this.ldkPeerListeningPort = 9736,
    this.maxMediaUploadSizeMb = 20,
    this.enableVirtualChannelsV0,
    this.virtualPeerPubkeys,
    this.vssUrl,
    this.vssAllowHttp = false,
    this.vssAllowEmptyRestore = false,
    this.lspBaseUrl,
    this.lspBearerToken,
    this.reuseAddresses = false,
    this.xpubVan,
    this.xpubCol,
    this.masterFingerprint,
  });

  final String storageDirPath;
  final String network;
  final int daemonListeningPort;
  final int ldkPeerListeningPort;
  final int maxMediaUploadSizeMb;
  final bool? enableVirtualChannelsV0;
  final List<String>? virtualPeerPubkeys;
  final String? vssUrl;
  final bool vssAllowHttp;
  final bool vssAllowEmptyRestore;
  final String? lspBaseUrl;
  final String? lspBearerToken;
  final bool reuseAddresses;
  final String? xpubVan;
  final String? xpubCol;
  final String? masterFingerprint;
}

/// Network service configuration used to unlock an initialized wallet.
class UtexoUnlockConfig {
  const UtexoUnlockConfig({
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

/// Request for a blinded or witness RGB invoice.
class RgbInvoiceRequest {
  const RgbInvoiceRequest({
    this.assetId,
    this.amount,
    this.durationSeconds,
    this.minConfirmations = 0,
  });

  final String? assetId;
  final int? amount;
  final int? durationSeconds;
  final int minConfirmations;
}

/// Request for an RGB transfer.
///
/// [assetId] and [amount] can be omitted when the invoice encodes them. For
/// asset-less donation invoices, pass them explicitly and set [donation].
class RgbSendRequest {
  const RgbSendRequest({
    required this.invoice,
    this.assetId,
    this.amount,
    this.donation = false,
    this.feeRate = 1.5,
    this.minConfirmations = 1,
    this.skipSync = false,
    this.witnessAmountSat,
    this.witnessBlinding,
  });

  final String invoice;
  final String? assetId;
  final int? amount;
  final bool donation;
  final double feeRate;
  final int minConfirmations;
  final bool skipSync;
  final int? witnessAmountSat;
  final int? witnessBlinding;
}

/// Request for atomic inflation of an IFA RGB asset.
class InflateAssetIfaRequest {
  const InflateAssetIfaRequest({
    required this.assetId,
    required this.inflationAmounts,
    this.feeRate = 1.5,
    this.minConfirmations = 1,
  });

  final String assetId;
  final List<int> inflationAmounts;
  final double feeRate;
  final int minConfirmations;
}

/// RN-core transfer status returned by UTEXO status helpers.
///
/// This intentionally remains a string alias for React Native parity. Prefer
/// comparing against [CoreTransferStatuses] constants instead of hard-coding
/// status literals in app code.
typedef CoreTransferStatus = String;

/// Known RN-core transfer-status values.
abstract final class CoreTransferStatuses {
  static const CoreTransferStatus waitingCounterparty = 'WaitingCounterparty';
  static const CoreTransferStatus waitingConfirmations = 'WaitingConfirmations';
  static const CoreTransferStatus settled = 'Settled';
  static const CoreTransferStatus failed = 'Failed';
}

/// RN-style Lightning payment list item.
class LightningPaymentSummary {
  const LightningPaymentSummary({required this.txid, required this.status});

  final String txid;
  final String status;
}

/// RN-style wrapper returned by `listLightningPayments`.
class ListLightningPaymentsResponse {
  const ListLightningPaymentsResponse({required this.payments});

  final List<LightningPaymentSummary> payments;
}

/// RN-style response returned by `createBackup`.
class WalletBackupResponse {
  const WalletBackupResponse({required this.message, required this.backupPath});

  final String message;
  final String backupPath;
}

/// LSP configuration captured by the wallet node creation params.
class UtexoLspConfig {
  const UtexoLspConfig({this.baseUrl, this.bearerToken});

  final String? baseUrl;
  final String? bearerToken;
}

/// Optional RGB asset payload for Lightning invoice creation.
class LightningAsset {
  const LightningAsset({required this.assetId, required this.amount});

  final String assetId;
  final int amount;
}

/// RN-style Lightning receive request.
class LightningReceiveRequest {
  const LightningReceiveRequest({required this.lnInvoice});

  final String lnInvoice;

  /// Compatibility alias for earlier Flutter facade callers.
  String get invoice => lnInvoice;
}

/// RN-style Lightning send request/status response.
class LightningSendRequest {
  const LightningSendRequest({required this.txid, required this.status});

  final String txid;
  final String status;
}

/// RN-style on-chain receive response.
class OnchainReceiveResponse {
  const OnchainReceiveResponse({required this.invoice});

  final String invoice;
}

/// RN-style on-chain send response.
class OnchainSendResponse {
  const OnchainSendResponse({
    required this.txid,
    required this.batchTransferIdx,
  });

  factory OnchainSendResponse.fromRln(RlnSendResult result) {
    return OnchainSendResponse(
      txid: result.txid,
      batchTransferIdx: result.batchTransferIdx,
    );
  }

  final String txid;
  final int batchTransferIdx;
}

/// Typed, app-facing wallet facade for Bitcoin, RGB, and RGB Lightning flows.
///
/// The facade owns node lifecycle state and maps supported native responses into
/// Dart models. React Native wallet methods that are absent upstream, depend on
/// RN-only service flows, or are intentionally skipped throw
/// [UnsupportedWalletFeatureException].
class UtexoWallet {
  UtexoWallet({
    required UtexoWalletConfig config,
    RlnClient? client,
    RlnSigner? signer,
  }) : _config = config,
       _client = client ?? RlnClient(),
       _signer = signer;

  final UtexoWalletConfig _config;
  final RlnClient _client;
  RlnSigner? _signer;

  int? _nodeId;
  bool _nodeCreated = false;
  bool _initialized = false;
  bool _unlocked = false;
  bool _shutdown = false;
  bool _disposed = false;
  bool? _resolvedEnableVirtualChannelsV0;
  List<String>? _resolvedVirtualPeerPubkeys;
  String? _resolvedLspBaseUrl;

  int get nodeId => _requireNode();

  bool get isInitialized => _initialized;
  bool get isUnlocked => _unlocked;
  bool isDisposed() => _disposed;

  String getNetwork() {
    _ensureActive();
    return _config.network;
  }

  Future<void> init({String? password, String? mnemonic}) async {
    _ensureNotDisposed();
    _validateConfig();
    _nodeId ??= await _createNode();
    _nodeCreated = true;
    _shutdown = false;
    final signer = _ensureSigner(password: password, mnemonic: mnemonic);
    await signer.initNode(
      client: _client,
      nodeId: _nodeId!,
      storageDirPath: _config.storageDirPath,
    );
    _initialized = true;
  }

  Future<void> initialize({String? password, String? mnemonic}) {
    return init(password: password, mnemonic: mnemonic);
  }

  Future<void> unlock({
    String? password,
    required UtexoUnlockConfig config,
  }) async {
    _ensureInitialized();
    final signer = _ensureSigner(password: password);
    final resolvedConfig = _resolveUnlockConfig(config);
    await signer.unlockNode(
      client: _client,
      nodeId: _nodeId!,
      config: resolvedConfig,
      storageDirPath: _config.storageDirPath,
    );
    _unlocked = true;
  }

  Future<void> reinit({
    String? password,
    String? mnemonic,
    UtexoUnlockConfig? unlockConfig,
  }) async {
    _ensureNotDisposed();
    _validateConfig();
    final existingNodeId = _nodeId;
    if (existingNodeId != null && !_shutdown) {
      await _client.shutdown(existingNodeId);
      _shutdown = true;
      _unlocked = false;
    }
    final restartedNodeId = await _createNode();
    _nodeId = restartedNodeId;
    _nodeCreated = true;
    _initialized = true;
    _unlocked = false;
    _shutdown = false;
    _disposed = false;
    if (unlockConfig != null) {
      final signer = _ensureSigner(password: password, mnemonic: mnemonic);
      final resolvedConfig = _resolveUnlockConfig(unlockConfig);
      await signer.unlockNode(
        client: _client,
        nodeId: _nodeId!,
        config: resolvedConfig,
        storageDirPath: _config.storageDirPath,
      );
      _unlocked = true;
    }
  }

  Future<void> shutdown() async {
    final id = _nodeId;
    if (id == null || _disposed || _shutdown) return;
    await _client.shutdown(id);
    _unlocked = false;
    _shutdown = true;
  }

  Future<void> destroy() async {
    final id = _nodeId;
    if (id == null) {
      _disposed = true;
      return;
    }
    try {
      await _client.shutdown(id);
    } catch (_) {
      // Destroy should still release the native handle after a failed shutdown.
    }
    try {
      await _signer?.dispose(client: _client, nodeId: id);
    } catch (_) {
      // Destroy should still release the native handle after signer cleanup.
    }
    await _client.destroyNode(id);
    _nodeId = null;
    _initialized = false;
    _unlocked = false;
    _shutdown = false;
    _disposed = true;
  }

  Future<void> dispose() => destroy();

  Future<RlnNodeInfo> nodeInfo() async {
    return RlnNodeInfo.fromMap(await _client.nodeInfo(_requireNode()));
  }

  Future<RlnNodeInfo> getNodeInfo() {
    return nodeInfo();
  }

  Future<RlnNetworkInfo> networkInfo() async {
    return RlnNetworkInfo.fromMap(await _client.networkInfo(_requireNode()));
  }

  Future<RlnNetworkInfo> getNetworkInfo() {
    return networkInfo();
  }

  Future<RlnXpubs> getXpub() async {
    if (_config.xpubVan != null || _config.xpubCol != null) {
      return RlnXpubs(vanilla: _config.xpubVan, colored: _config.xpubCol);
    }
    final info = await nodeInfo();
    return RlnXpubs(
      vanilla: info.accountXpubVanilla,
      colored: info.accountXpubColored,
    );
  }

  Future<RlnBtcBalance> getBtcBalance({bool skipSync = false}) async {
    return RlnBtcBalance.fromMap(
      await _client.btcBalance(nodeId: _requireNode(), skipSync: skipSync),
    );
  }

  Future<CoreBtcBalance> getBtcBalanceCore({bool skipSync = false}) async {
    return (await getBtcBalance(skipSync: skipSync)).toCore();
  }

  Future<String> getAddress() async {
    final response = await _client.address(_requireNode());
    return response['address']! as String;
  }

  Future<List<RlnUnspent>> listUnspents({bool skipSync = false}) async {
    final unspents = await _client.listUnspents(
      nodeId: _requireNode(),
      skipSync: skipSync,
    );
    return unspents.map(RlnUnspent.fromMap).toList(growable: false);
  }

  Future<List<CoreUnspent>> listUnspentsCore({bool skipSync = false}) async {
    return (await listUnspents(
      skipSync: skipSync,
    )).map((unspent) => unspent.toCore()).toList(growable: false);
  }

  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    double feeRate = 1.5,
    bool skipSync = false,
  }) async {
    _requireUInt8Optional(num, 'num');
    _requireUInt32Optional(size, 'size');
    _requireFeeRate(feeRate, 'feeRate');
    await _client.createUtxos(
      nodeId: _requireNode(),
      upTo: upTo,
      num: num,
      size: size,
      feeRate: feeRate,
      skipSync: skipSync,
    );
    return num ?? 0;
  }

  Future<RlnAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async {
    return RlnAssets.fromMap(
      await _client.listAssets(
        nodeId: _requireNode(),
        filterAssetSchemas: filterAssetSchemas,
      ),
    );
  }

  Future<CoreListAssets> listAssetsCore({
    List<String> filterAssetSchemas = const [],
  }) async {
    return (await listAssets(filterAssetSchemas: filterAssetSchemas)).toCore();
  }

  Future<RlnAssetBalance> getAssetBalance(String assetId) async {
    _requireNonEmpty(assetId, 'assetId');
    return RlnAssetBalance.fromMap(
      await _client.assetBalance(nodeId: _requireNode(), assetId: assetId),
    );
  }

  Future<CoreAssetBalance> getAssetBalanceCore(String assetId) async {
    return (await getAssetBalance(assetId)).toCore();
  }

  Future<String> rotateVanillaAddress() async {
    final response = await _client.rotateAddress(_requireNode());
    return RlnAddress.fromMap(response).address;
  }

  Future<String> rotateColoredAddress() {
    _unsupported('rotateColoredAddress');
  }

  Future<RlnAssetNia> issueAssetNia({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    _requireUInt8(precision, 'precision');
    _requireNonNegativeList(amounts, 'amounts');
    return RlnAssetNia.fromMap(
      _asRlnMap(
        await _client.issueAssetNia(
          nodeId: _requireNode(),
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
        ),
      ),
    );
  }

  Future<RlnAssetCfa> issueAssetCfa({
    required String name,
    String? details,
    required int precision,
    required List<int> amounts,
    String? fileDigest,
  }) async {
    _requireNonEmpty(name, 'name');
    _requireUInt8(precision, 'precision');
    _requireNonNegativeList(amounts, 'amounts');
    return RlnAssetCfa.fromMap(
      _asRlnMap(
        await _client.issueAssetCfa(
          nodeId: _requireNode(),
          name: name,
          details: details,
          precision: precision,
          amounts: amounts,
          fileDigest: fileDigest,
        ),
      ),
    );
  }

  Future<RlnAssetIfa> issueAssetIfa({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    _requireUInt8(precision, 'precision');
    _requireNonNegativeList(amounts, 'amounts');
    _requireNonNegativeList(inflationAmounts, 'inflationAmounts');
    return RlnAssetIfa.fromMap(
      _asRlnMap(
        await _client.issueAssetIfa(
          nodeId: _requireNode(),
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
          inflationAmounts: inflationAmounts,
          rejectListUrl: rejectListUrl,
        ),
      ),
    );
  }

  Future<RlnAssetUda> issueAssetUda({
    required String ticker,
    required String name,
    String? details,
    required int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests = const <String>[],
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    _requireUInt8(precision, 'precision');
    return RlnAssetUda.fromMap(
      _asRlnMap(
        await _client.issueAssetUda(
          nodeId: _requireNode(),
          ticker: ticker,
          name: name,
          details: details,
          precision: precision,
          mediaFileDigest: mediaFileDigest,
          attachmentsFileDigests: attachmentsFileDigests,
        ),
      ),
    );
  }

  Future<RlnInvoice> blindReceive(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: false);
  }

  Future<CoreInvoiceReceiveData> blindReceiveCore(
    RgbInvoiceRequest request,
  ) async {
    return (await blindReceive(request)).toCore();
  }

  Future<RlnInvoice> witnessReceive(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: true);
  }

  Future<CoreInvoiceReceiveData> witnessReceiveCore(
    RgbInvoiceRequest request,
  ) async {
    return (await witnessReceive(request)).toCore();
  }

  Future<RlnDecodedRgbInvoice> decodeRgbInvoice(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    return RlnDecodedRgbInvoice.fromMap(
      await _client.decodeRgbInvoice(nodeId: _requireNode(), invoice: invoice),
    );
  }

  Future<RlnDecodedRgbInvoice> decodeRGBInvoice(String invoice) {
    return decodeRgbInvoice(invoice);
  }

  Future<CoreInvoiceData> decodeRGBInvoiceCore(String invoice) async {
    return (await decodeRgbInvoice(invoice)).toCore(invoice);
  }

  Future<RlnSendResult> send(RgbSendRequest request) async {
    _requireNonEmpty(request.invoice, 'invoice');
    final decoded = await decodeRgbInvoice(request.invoice);
    final assetId = request.assetId ?? decoded.assetId;
    final recipientId = decoded.recipientId;
    final amount = request.amount ?? decoded.assignmentAmount;
    final transportEndpoints = decoded.transportEndpoints;

    if (assetId == null || assetId.isEmpty) {
      throw const WalletValidationException(
        'Asset ID is required for RGB send.',
        field: 'assetId',
      );
    }
    if (recipientId.isEmpty) {
      throw const WalletValidationException(
        'Recipient ID is required for RGB send.',
        field: 'recipientId',
      );
    }
    if (amount == null) {
      throw const WalletValidationException(
        'Amount is required for RGB send.',
        field: 'amount',
      );
    }
    _requireNonNegative(amount, 'amount');
    _requireFeeRate(request.feeRate, 'feeRate');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    _requireNonNegativeOptional(request.witnessAmountSat, 'witnessAmountSat');
    _requireNonNegativeOptional(request.witnessBlinding, 'witnessBlinding');
    _requireSupportedRgbSendSkipSync(request.skipSync);

    return RlnSendResult.fromMap(
      await _client.sendRgb(
        nodeId: _requireNode(),
        donation: request.donation,
        feeRate: request.feeRate,
        minConfirmations: request.minConfirmations,
        skipSync: request.skipSync,
        assetId: assetId,
        recipientId: recipientId,
        amount: amount,
        transportEndpoints: transportEndpoints,
        witnessAmountSat: request.witnessAmountSat,
        witnessBlinding: request.witnessBlinding,
      ),
    );
  }

  Future<String> inflateBegin(Object params) {
    _unsupported('inflateBegin');
  }

  Future<RlnMap> inflateEnd(Object params) {
    _unsupported('inflateEnd');
  }

  Future<RlnInflateResult> inflate(InflateAssetIfaRequest request) async {
    _requireNonEmpty(request.assetId, 'assetId');
    if (request.inflationAmounts.isEmpty) {
      throw const WalletValidationException(
        'inflationAmounts must not be empty.',
        field: 'inflationAmounts',
      );
    }
    for (var index = 0; index < request.inflationAmounts.length; index++) {
      _requireNonNegative(
        request.inflationAmounts[index],
        'inflationAmounts[$index]',
      );
    }
    _requireFeeRate(request.feeRate, 'feeRate');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    return RlnInflateResult.fromMap(
      await _client.inflate(
        nodeId: _requireNode(),
        assetId: request.assetId,
        inflationAmounts: request.inflationAmounts,
        feeRate: request.feeRate,
        minConfirmations: request.minConfirmations,
      ),
    );
  }

  Future<String> sendBtc({
    required int amount,
    required String address,
    double feeRate = 1.5,
    bool skipSync = false,
  }) async {
    _requirePositive(amount, 'amount');
    _requireNonEmpty(address, 'address');
    _requireFeeRate(feeRate, 'feeRate');
    final response = await _client.sendBtc(
      nodeId: _requireNode(),
      amount: amount,
      address: address,
      feeRate: feeRate,
      skipSync: skipSync,
    );
    return response['txid']! as String;
  }

  Future<List<RlnTransaction>> listTransactions({bool skipSync = false}) async {
    final transactions = await _client.listTransactions(
      nodeId: _requireNode(),
      skipSync: skipSync,
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<CoreTransaction>> listTransactionsCore({
    bool skipSync = false,
  }) async {
    return (await listTransactions(
      skipSync: skipSync,
    )).map((transaction) => transaction.toCore()).toList(growable: false);
  }

  Future<List<RlnTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async {
    _requireNonEmpty(txid, 'txid');
    final transactions = await _client.listTransactionsByTxid(
      nodeId: _requireNode(),
      txid: txid,
      skipSync: skipSync,
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<RlnTransfer>> listTransfers({String? assetId}) async {
    if (assetId != null) {
      final transfers = await _client.listTransfers(
        nodeId: _requireNode(),
        assetId: assetId,
      );
      return transfers.map(RlnTransfer.fromMap).toList(growable: false);
    }

    try {
      final transfers = await _client.listTransfers(
        nodeId: _requireNode(),
        assetId: '',
      );
      return transfers.map(RlnTransfer.fromMap).toList(growable: false);
    } on PlatformException catch (error) {
      if (!_isInvalidListTransfersRequest(error)) rethrow;
      return _listTransfersForKnownAssets();
    }
  }

  Future<List<CoreTransfer>> listTransfersCore({String? assetId}) async {
    return (await listTransfers(
      assetId: assetId,
    )).map((transfer) => transfer.toCore()).toList(growable: false);
  }

  Future<List<RlnTransfer>> listTransfersByTxid(String txid) async {
    _requireNonEmpty(txid, 'txid');
    final transfers = await _client.listTransfersByTxid(
      nodeId: _requireNode(),
      txid: txid,
    );
    return transfers.map(RlnTransfer.fromMap).toList(growable: false);
  }

  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) async {
    _requireNonNegativeOptional(batchTransferIdx, 'batchTransferIdx');
    final response = await _client.failTransfers(
      nodeId: _requireNode(),
      batchTransferIdx: batchTransferIdx,
      noAssetOnly: noAssetOnly,
      skipSync: skipSync,
    );
    return response['transfersChanged'] == true;
  }

  Future<void> refreshWallet({bool skipSync = false}) {
    return _client.refreshTransfers(nodeId: _requireNode(), skipSync: skipSync);
  }

  Future<void> syncWallet() => _client.sync(_requireNode());

  Future<double> estimateFeeRate(int blocks) async {
    _requireUInt16(blocks, 'blocks');
    final response = RlnFeeRate.fromMap(
      await _client.estimateFee(nodeId: _requireNode(), blocks: blocks),
    );
    return response.feeRate;
  }

  Future<RlnFeeRate> rlnEstimateFeeRate(int blocks) async {
    _requireUInt16(blocks, 'blocks');
    return RlnFeeRate.fromMap(
      await _client.estimateFee(nodeId: _requireNode(), blocks: blocks),
    );
  }

  Future<RlnIndexerCheck> checkIndexerUrl(String url) async {
    _requireNonEmpty(url, 'url');
    return RlnIndexerCheck.fromMap(
      await _client.checkIndexerUrl(nodeId: _requireNode(), indexerUrl: url),
    );
  }

  Future<void> checkProxyEndpoint(String endpoint) {
    _requireNonEmpty(endpoint, 'endpoint');
    return _client.checkProxyEndpoint(
      nodeId: _requireNode(),
      proxyEndpoint: endpoint,
    );
  }

  Future<RlnMap> estimateFee(String psbtBase64) {
    _unsupported('estimateFee');
  }

  Future<WalletBackupResponse> createBackup({
    required String backupPath,
    required String password,
  }) async {
    _requireNonEmpty(backupPath, 'backupPath');
    _requireNonEmpty(password, 'password');
    await _client.backup(
      nodeId: _requireNode(),
      backupPath: backupPath,
      password: password,
    );
    return WalletBackupResponse(
      message: 'Backup created successfully',
      backupPath: backupPath,
    );
  }

  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? amtMsat,
    int? expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  }) async {
    _requireNonNegativeOptional(amountSats, 'amountSats');
    final resolvedAmtMsat = amountSats == null ? amtMsat : amountSats * 1000;
    final resolvedExpirySec = expirySec ?? expirySeconds;
    final resolvedAssetId = asset?.assetId ?? assetId;
    final resolvedAssetAmount = resolvedAssetId == null
        ? null
        : (asset?.amount ?? assetAmount);
    final invoice = await createRlnLightningInvoice(
      amtMsat: resolvedAmtMsat,
      expirySec: resolvedExpirySec,
      assetId: resolvedAssetId,
      assetAmount: resolvedAssetAmount,
      paymentHash: paymentHash,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
    );
    return LightningReceiveRequest(lnInvoice: invoice.invoice);
  }

  Future<RlnLnInvoice> createRlnLightningInvoice({
    int? amtMsat,
    int expirySec = 3600,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  }) async {
    _requireNonNegativeOptional(amtMsat, 'amtMsat');
    _requireUInt32(expirySec, 'expirySec');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireUInt16Optional(minFinalCltvExpiryDelta, 'minFinalCltvExpiryDelta');
    return RlnLnInvoice.fromMap(
      await _client.lnInvoice(
        nodeId: _requireNode(),
        amtMsat: amtMsat,
        expirySec: expirySec,
        assetId: assetId,
        assetAmount: assetAmount,
        paymentHash: paymentHash,
        minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
        descriptionHash: descriptionHash,
      ),
    );
  }

  Future<HodlInvoice> createHodlInvoice(CreateHodlInvoiceParams params) async {
    _requireNonEmpty(params.paymentHash, 'paymentHash');
    _requireNonNegativeOptional(params.amtMsat, 'amtMsat');
    _requireUInt32(params.expirySec, 'expirySec');
    _requireNonNegativeOptional(params.assetAmount, 'assetAmount');
    _requireUInt16Optional(
      params.minFinalCltvExpiryDelta,
      'minFinalCltvExpiryDelta',
    );
    final invoice = await createRlnLightningInvoice(
      amtMsat: params.amtMsat,
      expirySec: params.expirySec,
      assetId: params.assetId,
      assetAmount: params.assetAmount,
      paymentHash: params.paymentHash,
      minFinalCltvExpiryDelta: params.minFinalCltvExpiryDelta,
      descriptionHash: params.descriptionHash,
    );
    return HodlInvoice(
      bolt11: invoice.invoice,
      paymentHash: params.paymentHash,
    );
  }

  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  ) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireNonEmpty(preimage, 'preimage');
    final response = await _client.claimHodlInvoice(
      nodeId: _requireNode(),
      paymentHash: paymentHash,
      paymentPreimage: preimage,
    );
    return HodlInvoiceResult(changed: response['changed'] == true);
  }

  Future<HodlInvoiceResult> cancelHodlInvoice(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    await _client.cancelHodlInvoice(
      nodeId: _requireNode(),
      paymentHash: paymentHash,
    );
    return const HodlInvoiceResult(changed: true);
  }

  Future<List<RlnPayment>> listPaymentsRaw() {
    return listPayments();
  }

  Future<ApayNewResponse> apayNew(String hostNodeId) async {
    _requireNonEmpty(hostNodeId, 'hostNodeId');
    return ApayNewResponse.fromMap(
      await _client.apayNew(nodeId: _requireNode(), hostNodeId: hostNodeId),
    );
  }

  Future<ApayNewResponse> apayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) async {
    _requireNonEmpty(hostNodeId, 'hostNodeId');
    _requireNonEmpty(username, 'username');
    _requireNonEmpty(domain, 'domain');
    return ApayNewResponse.fromMap(
      await _client.apayNewWithAddress(
        nodeId: _requireNode(),
        hostNodeId: hostNodeId,
        username: username,
        domain: domain,
      ),
    );
  }

  Future<UtexoLsp> createLsp([LspPeer? peer, int peerPort = 9735]) async {
    _ensureNotDisposed();
    if (peer != null) return UtexoLsp(wallet: this, peer: peer);
    _ensureVirtualChannelsMutable();
    final baseUrl = resolveLspBaseUrl(_config.network, _config.lspBaseUrl);
    final client = UtexoLspClient(
      baseUrl: baseUrl,
      bearerToken: _config.lspBearerToken,
    );
    try {
      final info = await client.getInfo();
      _enableVirtualChannelsForPeer(info.pubkey);
      final peerHost = Uri.parse(baseUrl).host;
      return UtexoLsp(
        wallet: this,
        peer: LspPeer(
          baseUrl: baseUrl,
          peerPubkey: info.pubkey,
          peerHost: peerHost,
          peerPort: peerPort,
          bearerToken: _config.lspBearerToken,
        ),
        httpClient: client,
      );
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  UtexoLspConfig getLspConfig() {
    return UtexoLspConfig(
      baseUrl: _config.lspBaseUrl,
      bearerToken: _config.lspBearerToken,
    );
  }

  Future<RlnDecodedLnInvoice> decodeLnInvoice(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    return RlnDecodedLnInvoice.fromMap(
      await _client.decodeLnInvoice(nodeId: _requireNode(), invoice: invoice),
    );
  }

  Future<LightningSendRequest> payLightningInvoice({
    String? lnInvoice,
    String? invoice,
    int? amount,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    final resolvedInvoice = lnInvoice ?? invoice;
    if (resolvedInvoice == null) {
      throw const WalletValidationException(
        'lnInvoice is required.',
        field: 'lnInvoice',
      );
    }
    _requireNonEmpty(resolvedInvoice, 'lnInvoice');
    _requireNonNegativeOptional(amount, 'amount');
    final resolvedAmtMsat = amount == null ? amtMsat : amount * 1000;
    final payment = await payRlnLightningInvoice(
      invoice: resolvedInvoice,
      amtMsat: resolvedAmtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    );
    return LightningSendRequest(
      txid: payment.paymentHash ?? payment.paymentId ?? '',
      status: payment.status,
    );
  }

  Future<RlnPaymentResult> payRlnLightningInvoice({
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireNonNegativeOptional(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    return RlnPaymentResult.fromMap(
      await _client.sendPayment(
        nodeId: _requireNode(),
        invoice: invoice,
        amtMsat: amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      ),
    );
  }

  Future<String> payLightningInvoiceBegin(Object params) {
    _unsupported('payLightningInvoiceBegin');
  }

  Future<RlnMap> payLightningInvoiceEnd(Object params) {
    _unsupported('payLightningInvoiceEnd');
  }

  Future<int> getLightningSendFeeEstimate(Object params) {
    _unsupported('getLightningSendFeeEstimate');
  }

  Future<CoreTransferStatus?> getLightningReceiveRequest(String invoice) async {
    return _coreStatusFromInvoiceStatus(await invoiceStatus(invoice));
  }

  /// Returns a core transfer status for a Lightning payment hash.
  ///
  /// Unknown native status strings return `null`, matching the nullable RN
  /// helper shape while preserving access to raw status through [getPayment].
  Future<CoreTransferStatus?> getLightningSendRequest(
    String paymentHash,
  ) async {
    final payment = await getPayment(paymentHash);
    return _coreStatusFromPaymentStatus(payment.status);
  }

  Future<RlnInvoiceStatus> invoiceStatus(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    return RlnInvoiceStatus.fromMap(
      await _client.invoiceStatus(nodeId: _requireNode(), invoice: invoice),
    );
  }

  Future<List<RlnPayment>> listPayments() async {
    final payments = await _client.listPayments(_requireNode());
    return payments.map(RlnPayment.fromMap).toList(growable: false);
  }

  Future<ListLightningPaymentsResponse> listLightningPayments() async {
    final payments = await listPayments();
    return ListLightningPaymentsResponse(
      payments: payments
          .map(
            (payment) => LightningPaymentSummary(
              txid: payment.paymentHash,
              status: payment.status,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<OnchainReceiveResponse> onchainReceive(
    RgbInvoiceRequest request,
  ) async {
    final invoice = await _rgbInvoice(request, witness: true);
    return OnchainReceiveResponse(invoice: invoice.invoice);
  }

  Future<OnchainSendResponse> onchainSend(RgbSendRequest request) async {
    return OnchainSendResponse.fromRln(await send(request));
  }

  Future<String> onchainSendBegin(Object params) {
    _unsupported('onchainSendBegin');
  }

  Future<RlnMap> onchainSendEnd(Object params) {
    _unsupported('onchainSendEnd');
  }

  Future<RlnMap> getOnchainSendStatus(String invoice) {
    _unsupported('getOnchainSendStatus');
  }

  Future<List<RlnTransfer>> listOnchainTransfers({String? assetId}) {
    return listTransfers(assetId: assetId);
  }

  Future<void> connectPeer(String peerPubkeyAndAddr) {
    _requireNonEmpty(peerPubkeyAndAddr, 'peerPubkeyAndAddr');
    return _client.connectPeer(
      nodeId: _requireNode(),
      peerPubkeyAndAddr: peerPubkeyAndAddr,
    );
  }

  Future<void> disconnectPeer(String peerPubkey) {
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    return _client.disconnectPeer(
      nodeId: _requireNode(),
      peerPubkey: peerPubkey,
    );
  }

  Future<List<RlnPeer>> listPeers() async {
    final peers = await _client.listPeers(_requireNode());
    return peers.map(RlnPeer.fromMap).toList(growable: false);
  }

  Future<List<RlnChannel>> listChannels() async {
    final channels = await _client.listChannels(_requireNode());
    return channels.map(RlnChannel.fromMap).toList(growable: false);
  }

  Future<RlnOpenChannelResult> openChannel({
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    int pushMsat = 0,
    bool publicChannel = false,
    bool withAnchors = false,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) async {
    _requireNonEmpty(peerPubkeyAndOptAddr, 'peerPubkeyAndOptAddr');
    _requirePositive(capacitySat, 'capacitySat');
    _requireNonNegative(pushMsat, 'pushMsat');
    _requireUInt32Optional(feeBaseMsat, 'feeBaseMsat');
    _requireUInt32Optional(
      feeProportionalMillionths,
      'feeProportionalMillionths',
    );
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireNonNegativeOptional(pushAssetAmount, 'pushAssetAmount');
    return RlnOpenChannelResult.fromMap(
      await _client.openChannel(
        nodeId: _requireNode(),
        peerPubkeyAndOptAddr: peerPubkeyAndOptAddr,
        capacitySat: capacitySat,
        pushMsat: pushMsat,
        publicChannel: publicChannel,
        withAnchors: withAnchors,
        feeBaseMsat: feeBaseMsat,
        feeProportionalMillionths: feeProportionalMillionths,
        temporaryChannelId: temporaryChannelId,
        assetId: assetId,
        assetAmount: assetAmount,
        pushAssetAmount: pushAssetAmount,
        virtualOpenMode: virtualOpenMode,
      ),
    );
  }

  Future<void> closeChannel({
    required String channelId,
    required String peerPubkey,
    bool force = false,
  }) {
    _requireNonEmpty(channelId, 'channelId');
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    return _client.closeChannel(
      nodeId: _requireNode(),
      channelId: channelId,
      peerPubkey: peerPubkey,
      force: force,
    );
  }

  Future<String> getChannelId(String temporaryChannelId) {
    _requireNonEmpty(temporaryChannelId, 'temporaryChannelId');
    return _client.getChannelId(
      nodeId: _requireNode(),
      temporaryChannelId: temporaryChannelId,
    );
  }

  Future<RlnPaymentResult> keysend({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(destPubkey, 'destPubkey');
    _requirePositive(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    return RlnPaymentResult.fromMap(
      await _client.keysend(
        nodeId: _requireNode(),
        destPubkey: destPubkey,
        amtMsat: amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      ),
    );
  }

  Future<RlnPayment> getPayment(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    return RlnPayment.fromMap(
      await _client.getPayment(
        nodeId: _requireNode(),
        paymentHash: paymentHash,
      ),
    );
  }

  Future<void> goOnline(String indexerUrl, {bool? skipConsistencyCheck}) {
    _unsupported('goOnline; use unlock() with indexerUrl instead.');
  }

  Future<String> createUtxosBegin(Object params) {
    _unsupported('createUtxosBegin');
  }

  Future<int> createUtxosEnd(Object params) {
    _unsupported('createUtxosEnd');
  }

  Future<String> sendBegin(Object params) {
    _unsupported('sendBegin');
  }

  Future<RlnMap> sendEnd(Object params) {
    _unsupported('sendEnd');
  }

  Future<String> sendBtcBegin(Object params) {
    _unsupported('sendBtcBegin');
  }

  Future<String> sendBtcEnd(Object params) {
    _unsupported('sendBtcEnd');
  }

  Future<String> signPsbt(String psbt, {String? mnemonic}) {
    _unsupported('signPsbt');
  }

  Future<String> signMessage(String message) async {
    _requireNonEmpty(message, 'message');
    final response = await _client.signMessage(
      nodeId: _requireNode(),
      message: message,
    );
    return RlnSignMessageResult.fromMap(response).signedMessage;
  }

  Future<bool> verifyMessage(String message, String signature) async {
    _requireNonEmpty(message, 'message');
    _requireNonEmpty(signature, 'signature');
    final response = await _client.verifyMessage(
      nodeId: _requireNode(),
      message: message,
      signature: signature,
    );
    return RlnVerifyMessageResult.fromMap(response).valid;
  }

  Future<void> configureVssBackup(Object config) {
    _unsupported('configureVssBackup');
  }

  Future<void> disableVssAutoBackup() {
    _unsupported('disableVssAutoBackup');
  }

  Future<int> vssBackup(Object config) {
    _unsupported('vssBackup');
  }

  Future<int> backupNow() {
    return _client.vssBackup(_requireNode());
  }

  Future<RlnMap> vssBackupInfo(Object config) {
    _unsupported('vssBackupInfo');
  }

  Future<void> vssClearFence(String password) {
    _requireNonEmpty(password, 'password');
    return _client.vssClearFence(nodeId: _requireNode(), password: password);
  }

  Never _unsupported(String feature) {
    throw UnsupportedWalletFeatureException(
      '$feature is not available in rgb_sdk_flutter.',
      feature: feature,
    );
  }

  RlnSigner _ensureSigner({String? password, String? mnemonic}) {
    final signer = _signer;
    if (signer != null) return signer;
    if (password == null || password.isEmpty) {
      throw const WalletValidationException(
        'password is required when no RlnSigner is configured.',
        field: 'password',
      );
    }
    return _signer = PasswordRlnSigner(password: password, mnemonic: mnemonic);
  }

  Future<int> _createNode() {
    return _client.createNode(
      storageDirPath: _config.storageDirPath,
      daemonListeningPort: _config.daemonListeningPort,
      ldkPeerListeningPort: _config.ldkPeerListeningPort,
      network: normalizeNativeRlnNetwork(_config.network),
      maxMediaUploadSizeMb: _config.maxMediaUploadSizeMb,
      enableVirtualChannelsV0:
          _resolvedEnableVirtualChannelsV0 ?? _config.enableVirtualChannelsV0,
      virtualPeerPubkeys:
          _resolvedVirtualPeerPubkeys ?? _config.virtualPeerPubkeys,
      vssUrl: _config.vssUrl,
      vssAllowHttp: _config.vssAllowHttp,
      vssAllowEmptyRestore: _config.vssAllowEmptyRestore,
      lspBaseUrl: _resolvedNodeLspBaseUrl(),
      lspBearerToken: _config.lspBearerToken,
      reuseAddresses: _config.reuseAddresses,
    );
  }

  String? _resolvedNodeLspBaseUrl() {
    final resolved = _resolvedLspBaseUrl;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final explicit = _config.lspBaseUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return getDefaultLspBaseUrl(_config.network);
  }

  void _ensureVirtualChannelsMutable() {
    if (_nodeCreated || _nodeId != null) {
      throw const WalletException(
        'createLsp() must be called before init()/reinit(): virtual-channel '
        'params are baked into the node at init time and cannot be changed '
        'afterwards.',
      );
    }
  }

  void _enableVirtualChannelsForPeer(String peerPubkey) {
    _ensureVirtualChannelsMutable();
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _resolvedEnableVirtualChannelsV0 = true;
    _resolvedLspBaseUrl = resolveLspBaseUrl(
      _config.network,
      _config.lspBaseUrl,
    );
    final existing =
        _resolvedVirtualPeerPubkeys ?? _config.virtualPeerPubkeys ?? const [];
    if (existing.contains(peerPubkey)) {
      _resolvedVirtualPeerPubkeys = List<String>.unmodifiable(existing);
      return;
    }
    _resolvedVirtualPeerPubkeys = List<String>.unmodifiable(<String>[
      ...existing,
      peerPubkey,
    ]);
  }

  UtexoUnlockConfig _resolveUnlockConfig(UtexoUnlockConfig config) {
    return resolveUnlockConfig(_config.network, config);
  }

  Future<List<RlnTransfer>> _listTransfersForKnownAssets() async {
    final assets = await listAssets();
    final transfers = <RlnTransfer>[];
    for (final id in assets.assetIds) {
      final assetTransfers = await _client.listTransfers(
        nodeId: _requireNode(),
        assetId: id,
      );
      transfers.addAll(assetTransfers.map(RlnTransfer.fromMap));
    }
    return transfers;
  }

  bool _isInvalidListTransfersRequest(PlatformException error) {
    final details = error.details;
    final operation = details is Map ? details['operation'] : null;
    final message = error.message ?? '';
    return operation == 'rlnListTransfers' &&
        (error.code == 'InvalidRequest' ||
            (error.code == 'RlnError' && message.contains('InvalidRequest')));
  }

  CoreTransferStatus? _coreStatusFromInvoiceStatus(RlnInvoiceStatus status) {
    return _coreStatusFromNativeStatus(status.status);
  }

  CoreTransferStatus? _coreStatusFromPaymentStatus(String status) {
    return _coreStatusFromNativeStatus(status);
  }

  CoreTransferStatus? _coreStatusFromNativeStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return CoreTransferStatuses.waitingCounterparty;
      case 'CLAIMABLE':
      case 'CLAIMING':
        return CoreTransferStatuses.waitingConfirmations;
      case 'SUCCEEDED':
        return CoreTransferStatuses.settled;
      case 'CANCELLED':
      case 'FAILED':
      case 'EXPIRED':
        return CoreTransferStatuses.failed;
      default:
        return null;
    }
  }

  Future<RlnInvoice> _rgbInvoice(
    RgbInvoiceRequest request, {
    required bool witness,
  }) async {
    _requireNonNegativeOptional(request.amount, 'amount');
    _requireUInt32Optional(request.durationSeconds, 'durationSeconds');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    return RlnInvoice.fromMap(
      await _client.rgbInvoice(
        nodeId: _requireNode(),
        assetId: request.assetId,
        assignmentAmount: request.amount,
        durationSeconds: request.durationSeconds,
        minConfirmations: request.minConfirmations,
        witness: witness,
        assignmentKind: request.amount == null
            ? null
            : RlnAssignmentKind.fungible.wireValue,
      ),
    );
  }

  RlnMap _asRlnMap(Object? value) {
    if (value is RlnMap) return value;
    if (value is Map) return Map<Object?, Object?>.from(value);
    throw const WalletException('Native response was not a map.');
  }

  int _requireNode() {
    _ensureActive();
    final id = _nodeId;
    if (id == null) {
      throw const WalletException('Wallet is not initialized.');
    }
    return id;
  }

  void _ensureInitialized() {
    _ensureActive();
    if (!_initialized || _nodeId == null) {
      throw const WalletException(
        'Wallet is not initialized. Call init() first.',
      );
    }
  }

  void _ensureActive() {
    _ensureNotDisposed();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const WalletException('Wallet is disposed.');
    }
  }

  void _requireNonEmpty(String value, String field) {
    if (value.isEmpty) {
      throw WalletValidationException(
        '$field must not be empty.',
        field: field,
      );
    }
  }

  void _validateConfig() {
    _requireNonEmpty(_config.storageDirPath, 'storageDirPath');
    _requireUInt16(_config.daemonListeningPort, 'daemonListeningPort');
    _requireUInt16(_config.ldkPeerListeningPort, 'ldkPeerListeningPort');
    _requireUInt16(_config.maxMediaUploadSizeMb, 'maxMediaUploadSizeMb');
  }

  void _requirePositive(int value, String field) {
    if (value <= 0) {
      throw WalletValidationException('$field must be positive.', field: field);
    }
  }

  void _requireNonNegative(int value, String field) {
    if (value < 0) {
      throw WalletValidationException(
        '$field must be non-negative.',
        field: field,
      );
    }
  }

  void _requireNonNegativeOptional(int? value, String field) {
    if (value == null) return;
    _requireNonNegative(value, field);
  }

  void _requireNonNegativeList(List<int> values, String field) {
    for (var index = 0; index < values.length; index += 1) {
      _requireNonNegative(values[index], '$field[$index]');
    }
  }

  void _requireUInt8(int value, String field) {
    if (value < 0 || value > 255) {
      throw WalletValidationException(
        '$field must fit in UInt8.',
        field: field,
      );
    }
  }

  void _requireUInt8Optional(int? value, String field) {
    if (value == null) return;
    _requireUInt8(value, field);
  }

  void _requireUInt16(int value, String field) {
    if (value < 0 || value > 65535) {
      throw WalletValidationException(
        '$field must fit in UInt16.',
        field: field,
      );
    }
  }

  void _requireUInt16Optional(int? value, String field) {
    if (value == null) return;
    _requireUInt16(value, field);
  }

  void _requireUInt32(int value, String field) {
    if (value < 0 || value > 4294967295) {
      throw WalletValidationException(
        '$field must fit in UInt32.',
        field: field,
      );
    }
  }

  void _requireUInt32Optional(int? value, String field) {
    if (value == null) return;
    _requireUInt32(value, field);
  }

  void _requireFeeRate(double value, String field) {
    if (value.isNaN || value.isInfinite || value < 0) {
      throw WalletValidationException(
        '$field must be a finite non-negative fee rate.',
        field: field,
      );
    }
  }

  void _requireSupportedRgbSendSkipSync(bool skipSync) {
    if (!skipSync) return;
    throw const UnsupportedWalletFeatureException(
      'rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.',
      feature: 'rlnSendRgb.skipSync',
    );
  }
}

UtexoUnlockConfig resolveUnlockConfig(
  String network,
  UtexoUnlockConfig config,
) {
  final defaults = getNetworkDefaults(network);
  final resolved = UtexoUnlockConfig(
    bitcoindRpcUsername: config.bitcoindRpcUsername,
    bitcoindRpcPassword: config.bitcoindRpcPassword,
    bitcoindRpcHost: config.bitcoindRpcHost,
    bitcoindRpcPort: config.bitcoindRpcPort,
    indexerUrl: config.indexerUrl ?? defaults?.indexerUrl,
    proxyEndpoint: config.proxyEndpoint ?? defaults?.proxyEndpoint,
    announceAddresses: config.announceAddresses,
    announceAlias: config.announceAlias,
    gossipRgsServerUrl: config.gossipRgsServerUrl,
  );

  final hasIndexer = resolved.indexerUrl != null;
  final hasBitcoind =
      resolved.bitcoindRpcHost != null && resolved.bitcoindRpcUsername != null;
  if (!hasIndexer && !hasBitcoind) {
    throw WalletValidationException(
      'No chain backend configured for network "$network". '
      'Provide indexerUrl or bitcoindRpcHost + bitcoindRpcUsername in unlock config.',
      field: 'indexerUrl',
    );
  }
  return resolved;
}

UtexoUnlockConfig resolveUnlockParams(
  String network,
  UtexoUnlockConfig params,
) {
  return resolveUnlockConfig(network, params);
}
