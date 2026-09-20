part of 'utexo_lsp.dart';

mixin _UtexoLspAddress on _UtexoLspInternals {
  /// Resolves and pays a Lightning Address quote.
  Future<PayAddressResult> payAddress(PayAddressOptions options) async {
    final quote = await quoteAddress(options);
    final sendResult = await wallet.payLightningInvoice(
      lnInvoice: quote.invoice,
    );
    return PayAddressResult(
      invoice: quote.invoice,
      sendResult: sendResult,
      assetSelection: quote.assetSelection,
    );
  }

  /// Resolves a Lightning Address without paying the returned invoice.
  Future<AddressQuote> quoteAddress(PayAddressOptions options) async {
    return _quoteAddress(options);
  }

  Future<AddressQuote> _quoteAddress(
    PayAddressOptions options, {
    bool requireApayProof = false,
  }) async {
    _requirePositiveMsat(options.amtMsat, 'amtMsat');
    final parsed = parseLightningAddress(options.address);
    final asset = options.asset;
    final assetAmount = _resolvedAssetAmount(asset);
    if (asset != null && assetAmount == null) {
      throw const ValidationError(
        'asset.assetAmount or asset.amount is required when asset is set.',
        'asset.assetAmount',
      );
    }
    if (assetAmount != null && assetAmount <= 0) {
      throw const ValidationError(
        'asset amount must be a positive integer in smallest asset units.',
        'asset.assetAmount',
      );
    }

    var assetId = asset?.assetId?.trim();
    if (assetId != null && assetId.isEmpty) assetId = null;
    AssetSelection? selection;
    if (asset != null && assetId == null) {
      selection = await selectPaymentAsset(
        SelectPaymentAssetOptions(
          address: options.address,
          assetAmount: assetAmount!,
        ),
      );
      assetId = selection.assetId;
    }

    final sameLspHost = isSameLspHost(parsed.domain, peer.baseUrl);
    final resolution = await _resolveAddressQuote(
      username: parsed.username,
      domain: parsed.domain,
      amtMsat: options.amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    );
    final callback = resolution.callback;
    if (callback.pr.isEmpty) {
      throw const LspError(
        endpoint: 'lightning-address',
        status: 200,
        body: 'No invoice returned for Lightning Address',
      );
    }
    final decoded = await wallet.decodeLnInvoice(callback.pr);
    LspAddressQuoteVerifier.verify(
      resolution: resolution,
      invoice: decoded,
      username: parsed.username,
      domain: parsed.domain,
      expectedAmtMsat: options.amtMsat,
      expectedAssetId: assetId,
      expectedAssetAmount: assetAmount,
      walletNetwork: wallet.network,
      nowEpochSeconds: nowEpochSeconds,
      expectedLspPubkey: sameLspHost ? peer.peerPubkey : null,
      requireApayProof: requireApayProof,
    );
    return AddressQuote(
      invoice: callback.pr,
      amtMsat: options.amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
      assetSelection: selection,
      proof: callback.proof,
    );
  }

  /// Fetches LNURL discovery from the address's own host.
  Future<LspLnurlpDiscovery> discoverAddress(String address) async {
    final parsed = parseLightningAddress(address);
    if (isSameLspHost(parsed.domain, peer.baseUrl)) {
      return http.discoverAddress(parsed.username);
    }
    return http.discoverExternalAddress(parsed.domain, parsed.username);
  }

  /// Lists the payout and convertible assets advertised by an address.
  Future<PayableAssets> listPayableAssets([String? address]) async {
    final target = address?.trim().isNotEmpty == true
        ? address!.trim()
        : await _ownAddressString('listPayableAssets');
    return LspAssetSelectionPolicy.payableAssets(await discoverAddress(target));
  }

  /// Selects a payable asset using largest single-channel local liquidity.
  Future<AssetSelection> selectPaymentAsset(
    SelectPaymentAssetOptions options,
  ) async {
    final discovery =
        options.discovery ?? await discoverAddress(options.address);
    return LspAssetSelectionPolicy.selectForPayment(
      address: options.address,
      requiredAmount: options.assetAmount,
      discovery: discovery,
      localAmounts: await _localAssetAmounts(wallet),
    );
  }

  /// Creates a hosted invoice for a payer that does not implement APay.
  Future<ExternalInvoice> requestExternalInvoice(
    RequestExternalInvoiceOptions options,
  ) async {
    _requirePositiveMsat(options.amtMsat, 'amtMsat');
    if (options.assetAmount <= 0) {
      throw const ValidationError(
        'assetAmount must be a positive integer in smallest asset units.',
        'assetAmount',
      );
    }
    final target = options.address?.trim().isNotEmpty == true
        ? options.address!.trim()
        : await _ownAddressString('requestExternalInvoice');
    final parsed = parseLightningAddress(target);
    final payable = await listPayableAssets(parsed.address);
    final choice = LspAssetSelectionPolicy.pickForExternalInvoice(
      address: parsed.address,
      payable: payable,
      requested: options.asset,
      preference: options.prefer,
    );
    final quote = await _quoteAddress(
      PayAddressOptions(
        address: parsed.address,
        amtMsat: options.amtMsat,
        asset: PayAddressAssetParam(
          assetId: choice.asset.assetId,
          assetAmount: options.assetAmount,
        ),
      ),
      requireApayProof: true,
    );
    return ExternalInvoice(
      invoice: quote.invoice,
      amtMsat: quote.amtMsat,
      assetId: quote.assetId,
      assetAmount: quote.assetAmount,
      assetSelection: quote.assetSelection,
      proof: quote.proof,
      address: parsed.address,
      username: parsed.username,
      domain: parsed.domain,
      asset: choice.asset,
      converted: choice.converted,
      paymentHash: quote.proof?.paymentHash,
    );
  }

  Future<LspAddressResolution> _resolveAddressQuote({
    required String username,
    required String domain,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    if (!isSameLspHost(domain, peer.baseUrl)) {
      return http.resolveExternalAddressWithDiscovery(
        domain,
        username,
        amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      );
    }

    // A successful callback consumes one APay hash. If the response is lost,
    // retrying can consume another hash and create a second payable invoice.
    // The current protocol has no idempotency key or lookup handle, so an
    // ambiguous result must be surfaced to the caller instead of retried.
    return http.resolveAddressWithDiscovery(
      username,
      amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    );
  }

  Future<String> _ownAddressString(String operation) async {
    final address = await _ownLightningAddress(this, operation);
    return '${address.username}@${address.domain}';
  }

  int? _resolvedAssetAmount(PayAddressAssetParam? asset) {
    if (asset == null) return null;
    final amount = asset.amount;
    final assetAmount = asset.assetAmount;
    if (amount != null && assetAmount != null && amount != assetAmount) {
      throw const ValidationError(
        'asset.amount and asset.assetAmount must match when both are set.',
        'asset.assetAmount',
      );
    }
    return assetAmount ?? amount;
  }
}
