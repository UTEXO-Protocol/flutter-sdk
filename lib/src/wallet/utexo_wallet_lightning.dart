part of 'utexo_wallet.dart';

mixin _UtexoWalletLightning on _UtexoWalletInternals {
  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? amtMsat,
    int? expirySec,
    String? assetId,
    int? assetAmount,
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
      paymentHash: null,
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
    _requireUnlockedNode();
    return _binding.rlnLnInvoice(
      amtMsat,
      expirySec,
      assetId,
      assetAmount,
      paymentHash: paymentHash,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
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
      amtMsat: params.amtMsat,
      expirySec: params.expirySec,
      assetId: params.assetId,
      assetAmount: params.assetAmount,
      minFinalCltvExpiryDelta: params.minFinalCltvExpiryDelta,
      descriptionHash: params.descriptionHash,
    );
  }

  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  ) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireNonEmpty(preimage, 'preimage');
    _requireUnlockedNode();
    final response = await _binding.rlnClaimHodlInvoice(paymentHash, preimage);
    return HodlInvoiceResult(changed: response['changed'] == true);
  }

  Future<HodlInvoiceResult> cancelHodlInvoice(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireUnlockedNode();
    await _binding.rlnCancelHodlInvoice(paymentHash);
    return const HodlInvoiceResult(changed: true);
  }

  Future<RlnDecodedLnInvoice> decodeLnInvoiceRaw(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireUnlockedNode();
    return _binding.rlnDecodeLnInvoice(invoice);
  }

  Future<DecodedLightningInvoice> decodeLnInvoice(String invoice) async {
    return (await decodeLnInvoiceRaw(invoice)).toDecodedLightningInvoice();
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
    _requireUnlockedNode();
    return _binding.rlnSendPayment(invoice, amtMsat, assetId, assetAmount);
  }

  Future<RlnInvoiceStatusValue> getLightningReceiveStatus(String id) async {
    _requireNonEmpty(id, 'id');
    return normalizeInvoiceStatus((await invoiceStatusRaw(id)).status);
  }

  Future<RlnPaymentStatusValue?> getLightningSendStatus(String id) async {
    _requireNonEmpty(id, 'id');
    final payment = await getPaymentRaw(id);
    return tryNormalizePaymentStatus(payment.status);
  }

  Future<RlnInvoiceStatus> invoiceStatusRaw(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireUnlockedNode();
    return _binding.rlnInvoiceStatus(invoice);
  }

  Future<LightningInvoiceStatus> invoiceStatus(String invoice) async {
    return (await invoiceStatusRaw(invoice)).toLightningInvoiceStatus();
  }

  Future<List<RlnPayment>> listPaymentsRaw() async {
    _requireUnlockedNode();
    return _binding.rlnListPayments();
  }

  Future<List<LightningPayment>> listPayments() async {
    return (await listPaymentsRaw())
        .map((payment) => payment.toLightningPayment())
        .toList(growable: false);
  }

  Future<ListLightningPaymentsResponse> listLightningPayments() async {
    final payments = await listPayments();
    return ListLightningPaymentsResponse(
      payments: payments
          .map(
            (payment) => LightningPaymentSummary(
              txid: payment.paymentHash,
              status: payment.status ?? RlnPaymentStatuses.pending,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> connectPeer(String peerPubkeyAndAddr) {
    _requireNonEmpty(peerPubkeyAndAddr, 'peerPubkeyAndAddr');
    _requireUnlockedNode();
    return _binding.rlnConnectPeer(peerPubkeyAndAddr);
  }

  Future<void> disconnectPeer(String peerPubkey) {
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _requireUnlockedNode();
    return _binding.rlnDisconnectPeer(peerPubkey);
  }

  Future<List<RlnPeer>> listPeersRaw() async {
    _requireUnlockedNode();
    return _binding.rlnListPeers();
  }

  Future<List<LightningPeer>> listPeers() async {
    return (await listPeersRaw())
        .map((peer) => peer.toLightningPeer())
        .toList(growable: false);
  }

  Future<List<RlnChannel>> listChannelsRaw() async {
    _requireUnlockedNode();
    return _binding.rlnListChannels();
  }

  Future<List<LightningChannel>> listChannels() async {
    return (await listChannelsRaw())
        .map((channel) => channel.toLightningChannel())
        .toList(growable: false);
  }

  Future<List<LightningChannel>> listLightningChannels() {
    return listChannels();
  }

  Future<RlnOpenChannelResult> openChannelRaw({
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    int pushMsat = 0,
    bool publicChannel = false,
    bool withAnchors = true,
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
    _requireUnlockedNode();
    return _binding.rlnOpenChannel(
      RlnOpenChannelRequest(
        peerPubkeyAndOptAddr: peerPubkeyAndOptAddr,
        capacitySat: capacitySat,
        pushMsat: pushMsat,
        public: publicChannel,
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

  Future<LightningChannelOpenResult> openChannel({
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    int pushMsat = 0,
    bool publicChannel = false,
    bool withAnchors = true,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) async {
    return (await openChannelRaw(
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
    )).toLightningChannelOpenResult();
  }

  Future<void> closeChannel({
    required String channelId,
    required String peerPubkey,
    bool force = false,
  }) {
    _requireNonEmpty(channelId, 'channelId');
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _requireUnlockedNode();
    return _binding.rlnCloseChannel(channelId, peerPubkey, force);
  }

  Future<String> getChannelId(String temporaryChannelId) {
    _requireNonEmpty(temporaryChannelId, 'temporaryChannelId');
    _requireUnlockedNode();
    return _binding.rlnGetChannelId(temporaryChannelId);
  }

  Future<RlnPaymentResult> keysendRaw({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(destPubkey, 'destPubkey');
    _requirePositive(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireUnlockedNode();
    return _binding.rlnKeysend(destPubkey, amtMsat, assetId, assetAmount);
  }

  Future<LightningPaymentResult> keysend({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    return (await keysendRaw(
      destPubkey: destPubkey,
      amtMsat: amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    )).toLightningPaymentResult();
  }

  Future<RlnPayment> getPaymentRaw(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireUnlockedNode();
    return _binding.rlnGetPayment(paymentHash);
  }

  Future<LightningPayment> getPayment(String paymentHash) async {
    return (await getPaymentRaw(paymentHash)).toLightningPayment();
  }

  Future<String> signNodeMessage(String message) async {
    _requireNonEmpty(message, 'message');
    _requireUnlockedNode();
    return (await _binding.rlnSignMessage(message)).signedMessage;
  }

  Future<bool> verifyNodeMessage(String message, String signature) async {
    _requireNonEmpty(message, 'message');
    _requireNonEmpty(signature, 'signature');
    _requireUnlockedNode();
    return (await _binding.rlnVerifyMessage(message, signature)).valid;
  }

  Future<String> signMessage(String message) => signNodeMessage(message);

  Future<bool> verifyMessage(String message, String signature) =>
      verifyNodeMessage(message, signature);

  Future<void> vssClearFence(String password) {
    _requireNonEmpty(password, 'password');
    _requireUnlockedNode();
    return _binding.rlnVssClearFence(password);
  }

  Future<int> backupNow() {
    _requireUnlockedNode();
    return _binding.rlnVssBackup();
  }
}
