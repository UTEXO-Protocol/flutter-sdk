part of 'utexo_wallet.dart';

mixin _UtexoWalletOnchain on _UtexoWalletInternals {
  Future<RlnNodeInfo> nodeInfoRaw() async {
    _requireNode();
    return _binding.rlnNodeInfo();
  }

  Future<WalletNodeInfo> nodeInfo() async {
    return (await nodeInfoRaw()).toWalletNodeInfo();
  }

  Future<WalletNodeInfo> getNodeInfo() {
    return nodeInfo();
  }

  Future<RlnNodeInfo> getNodeInfoRaw() {
    return nodeInfoRaw();
  }

  Future<RlnNetworkInfo> networkInfoRaw() async {
    _requireUnlockedNode();
    return _binding.rlnNetworkInfo();
  }

  Future<WalletNetworkInfo> networkInfo() async {
    return (await networkInfoRaw()).toWalletNetworkInfo();
  }

  Future<WalletNetworkInfo> getNetworkInfo() {
    return networkInfo();
  }

  Future<RlnNetworkInfo> getNetworkInfoRaw() {
    return networkInfoRaw();
  }

  Future<RlnBtcBalance> getBtcBalanceRaw({bool skipSync = false}) async {
    _requireUnlockedNode();
    return _binding.rlnBtcBalance(skipSync);
  }

  Future<CoreBtcBalance> getBtcBalance({bool skipSync = false}) async {
    return (await getBtcBalanceRaw(skipSync: skipSync)).toCore();
  }

  Future<CoreBtcBalance> getBtcBalanceCore({bool skipSync = false}) {
    return getBtcBalance(skipSync: skipSync);
  }

  Future<String> getAddress() async {
    _requireUnlockedNode();
    return (await _binding.rlnAddress()).address;
  }

  Future<List<RlnUnspent>> listUnspentsRaw({bool skipSync = false}) async {
    _requireUnlockedNode();
    return _binding.rlnListUnspents(skipSync);
  }

  Future<List<CoreUnspent>> listUnspents({bool skipSync = false}) async {
    return (await listUnspentsRaw(
      skipSync: skipSync,
    )).map((unspent) => unspent.toCore()).toList(growable: false);
  }

  Future<List<CoreUnspent>> listUnspentsCore({bool skipSync = false}) {
    return listUnspents(skipSync: skipSync);
  }

  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requireUInt8Optional(num, 'num');
    _requireUInt32Optional(size, 'size');
    _requireFeeRate(feeRate, 'feeRate');
    _ensureRgbUtxoCreationSupported();
    _requireUnlockedNode();
    await _binding.rlnCreateUtxos(upTo, num, size, feeRate, skipSync);
    return num ?? 0;
  }

  Future<RlnAssets> listAssetsRaw({
    List<String> filterAssetSchemas = const [],
  }) async {
    _requireUnlockedNode();
    return _binding.rlnListAssets(filterAssetSchemas);
  }

  Future<CoreListAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async {
    return (await listAssetsRaw(
      filterAssetSchemas: filterAssetSchemas,
    )).toCore();
  }

  Future<CoreListAssets> listAssetsCore({
    List<String> filterAssetSchemas = const [],
  }) {
    return listAssets(filterAssetSchemas: filterAssetSchemas);
  }

  Future<RlnAssetBalance> getAssetBalanceRaw(String assetId) async {
    _requireNonEmpty(assetId, 'assetId');
    _requireUnlockedNode();
    return _binding.rlnAssetBalance(assetId);
  }

  Future<CoreAssetBalance> getAssetBalance(String assetId) async {
    return (await getAssetBalanceRaw(assetId)).toCore();
  }

  Future<CoreAssetBalance> getAssetBalanceCore(String assetId) {
    return getAssetBalance(assetId);
  }

  Future<String> rotateVanillaAddress() async {
    _requireUnlockedNode();
    return (await _binding.rlnRotateAddress()).address;
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
    _ensureRgbAssetIssuanceSupported('issueAssetNia');
    _requireUnlockedNode();
    return RlnAssetNia.fromMap(
      _asRlnMap(
        await _binding.rlnIssueAssetNia(ticker, name, precision, amounts),
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
    _ensureRgbAssetIssuanceSupported('issueAssetIfa');
    _requireUnlockedNode();
    return RlnAssetIfa.fromMap(
      _asRlnMap(
        await _binding.rlnIssueAssetIfa(
          ticker,
          name,
          precision,
          amounts,
          inflationAmounts,
          rejectListUrl,
        ),
      ),
    );
  }

  Future<RlnInvoice> blindReceiveRaw(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: false);
  }

  Future<CoreInvoiceReceiveData> blindReceive(RgbInvoiceRequest request) async {
    return (await blindReceiveRaw(request)).toCore();
  }

  Future<CoreInvoiceReceiveData> blindReceiveCore(RgbInvoiceRequest request) {
    return blindReceive(request);
  }

  Future<RlnInvoice> witnessReceiveRaw(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: true);
  }

  Future<CoreInvoiceReceiveData> witnessReceive(
    RgbInvoiceRequest request,
  ) async {
    return (await witnessReceiveRaw(request)).toCore();
  }

  Future<CoreInvoiceReceiveData> witnessReceiveCore(RgbInvoiceRequest request) {
    return witnessReceive(request);
  }

  Future<RlnDecodedRgbInvoice> decodeRgbInvoiceRaw(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireUnlockedNode();
    return _binding.rlnDecodeRgbInvoice(invoice);
  }

  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) async {
    return (await decodeRgbInvoiceRaw(invoice)).toCore(invoice);
  }

  @override
  Future<RlnSendResult> _sendRgb(RgbSendRequest request) async {
    _requireNonEmpty(request.invoice, 'invoice');
    final decoded = await decodeRgbInvoiceRaw(request.invoice);
    final assetId = request.assetId ?? decoded.assetId;
    final recipientId = decoded.recipientId;
    final amount = request.amount;
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

    _requireUnlockedNode();
    return _binding.rlnSendRgb(
      request.donation,
      request.feeRate,
      request.minConfirmations,
      request.skipSync,
      assetId,
      recipientId,
      amount,
      transportEndpoints,
      request.witnessAmountSat == null
          ? null
          : RlnWitnessData(
              amountSat: request.witnessAmountSat!,
              blinding: request.witnessBlinding,
            ),
    );
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
    _ensureRgbAssetIssuanceSupported('inflate');
    _requireUnlockedNode();
    return _binding.rlnInflate(
      request.assetId,
      request.inflationAmounts,
      request.feeRate,
      request.minConfirmations,
    );
  }

  Future<String> sendBtc({
    required int amount,
    required String address,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requirePositive(amount, 'amount');
    _requireNonEmpty(address, 'address');
    _requireFeeRate(feeRate, 'feeRate');
    _requireUnlockedNode();
    final response = await _binding.rlnSendBtc(
      amount,
      address,
      feeRate,
      skipSync,
    );
    return response['txid']! as String;
  }

  Future<List<RlnTransaction>> listTransactionsRaw({
    bool skipSync = false,
  }) async {
    _requireUnlockedNode();
    return _binding.rlnListTransactions(skipSync);
  }

  Future<List<CoreTransaction>> listTransactions({
    bool skipSync = false,
  }) async {
    return (await listTransactionsRaw(
      skipSync: skipSync,
    )).map((transaction) => transaction.toCore()).toList(growable: false);
  }

  Future<List<CoreTransaction>> listTransactionsCore({bool skipSync = false}) {
    return listTransactions(skipSync: skipSync);
  }

  Future<List<RlnTransaction>> listTransactionsByTxidRaw(
    String txid, {
    bool skipSync = false,
  }) async {
    _requireNonEmpty(txid, 'txid');
    _requireUnlockedNode();
    return _binding.rlnListTransactionsByTxid(txid, skipSync);
  }

  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async {
    return (await listTransactionsByTxidRaw(
      txid,
      skipSync: skipSync,
    )).map((transaction) => transaction.toCore()).toList(growable: false);
  }

  Future<List<RlnTransfer>> listTransfersRaw({String? assetId}) async {
    if (assetId != null) {
      _requireUnlockedNode();
      return _binding.rlnListTransfers(assetId);
    }

    try {
      _requireUnlockedNode();
      return await _binding.rlnListTransfers('');
    } on RgbSdkException catch (error) {
      if (!_isInvalidListTransfersRequest(error)) rethrow;
      throw UnsupportedWalletFeatureException(
        'Complete unfiltered transfer listing is not available with the '
        'current native artifact. Pass assetId to list asset transfers without '
        'silently omitting no-asset transfers.',
        feature: 'listTransfers',
        cause: error,
      );
    }
  }

  Future<List<CoreTransfer>> listTransfers({String? assetId}) async {
    return (await listTransfersRaw(
      assetId: assetId,
    )).map((transfer) => transfer.toCore()).toList(growable: false);
  }

  Future<List<CoreTransfer>> listTransfersCore({String? assetId}) {
    return listTransfers(assetId: assetId);
  }

  Future<List<RlnTransfer>> listTransfersByTxidRaw(String txid) async {
    _requireNonEmpty(txid, 'txid');
    _requireUnlockedNode();
    return _binding.rlnListTransfersByTxid(txid);
  }

  Future<List<CoreTransfer>> listTransfersByTxid(String txid) async {
    return (await listTransfersByTxidRaw(
      txid,
    )).map((transfer) => transfer.toCore()).toList(growable: false);
  }

  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) async {
    _requireNonNegativeOptional(batchTransferIdx, 'batchTransferIdx');
    _requireUnlockedNode();
    final response = await _binding.rlnFailTransfers(
      batchTransferIdx,
      noAssetOnly,
      skipSync,
    );
    return response['transfersChanged'] == true;
  }

  Future<void> refreshWallet({bool skipSync = false}) {
    _requireUnlockedNode();
    return _binding.rlnRefreshTransfers(skipSync);
  }

  Future<void> syncWallet() {
    _requireUnlockedNode();
    return _binding.rlnSync();
  }

  Future<RlnFeeRate> estimateFeeRate(int blocks) async {
    _requireUInt16(blocks, 'blocks');
    _requireUnlockedNode();
    return _binding.rlnEstimateFee(blocks);
  }

  Future<double> estimateFeeRateValue(int blocks) async {
    return (await estimateFeeRate(blocks)).feeRate;
  }

  Future<RlnFeeRate> rlnEstimateFeeRate(int blocks) => estimateFeeRate(blocks);

  Future<RlnIndexerCheck> checkIndexerUrl(String url) async {
    _requireNonEmpty(url, 'url');
    _requireUnlockedNode();
    return _binding.rlnCheckIndexerUrl(url);
  }

  Future<void> checkProxyEndpoint(String endpoint) {
    _requireNonEmpty(endpoint, 'endpoint');
    _requireUnlockedNode();
    return _binding.rlnCheckProxyEndpoint(endpoint);
  }

  Future<WalletBackupResponse> createBackup({
    required String backupPath,
    required String password,
  }) {
    _requireNonEmpty(backupPath, 'backupPath');
    _requireNonEmpty(password, 'password');
    throw const UnsupportedWalletFeatureException(
      'createBackup is native-blocked by the current RLN/RN contract and is '
      'not a recovery-ready API.',
      feature: 'createBackup',
    );
  }

  Future<OnchainReceiveResponse> onchainReceive(
    RgbInvoiceRequest request,
  ) async {
    final invoice = await _rgbInvoice(request, witness: true);
    return OnchainReceiveResponse.fromRln(invoice);
  }

  Future<OnchainSendResponse> onchainSend(RgbSendRequest request) async {
    return OnchainSendResponse.fromRln(await _sendRgb(request));
  }

  Future<List<CoreTransfer>> listOnchainTransfers({String? assetId}) {
    return listTransfers(assetId: assetId);
  }

  @override
  bool _isInvalidListTransfersRequest(RgbSdkException error) {
    final cause = error.cause;
    if (cause is! NativeBridgeFailure) return false;
    return cause.operation == 'rlnListTransfers' && error is BadRequestError;
  }

  @override
  Future<RlnInvoice> _rgbInvoice(
    RgbInvoiceRequest request, {
    required bool witness,
  }) async {
    _requireNonNegativeOptional(request.amount, 'amount');
    _requireUInt32Optional(request.durationSeconds, 'durationSeconds');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    _requireUnlockedNode();
    return _binding.rlnRgbInvoice(
      request.assetId,
      request.amount,
      request.durationSeconds,
      request.minConfirmations,
      witness,
      assignmentKind: request.amount == null
          ? null
          : RlnAssignmentKind.fungible,
    );
  }

  @override
  RlnMap _asRlnMap(Object? value) {
    if (value is RlnMap) return value;
    if (value is Map) return Map<Object?, Object?>.from(value);
    throw const WalletException('Native response was not a map.');
  }
}
