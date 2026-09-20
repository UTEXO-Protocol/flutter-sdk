part of 'utexo_lsp.dart';

mixin _UtexoLspRelay on _UtexoLspInternals {
  /// Quotes and locally verifies a cross-asset external Lightning payment.
  Future<ExternalPaymentQuote> quoteExternalPayment(
    PayExternalInvoiceOptions options,
  ) async {
    final invoice = options.invoice.trim();
    if (invoice.isEmpty) {
      throw const ValidationError('invoice is required.', 'invoice');
    }
    if (options.maxFeeMsat < 0) {
      throw const ValidationError(
        'maxFeeMsat must be non-negative.',
        'maxFeeMsat',
      );
    }

    // Decode before the LSP sees the invoice. The subsequent comparison is
    // anchored in data signed by the third party, not in LSP JSON.
    final target = await wallet.decodeLnInvoice(invoice);
    if (target.paymentHash.isEmpty) {
      throw const ValidationError(
        'the target invoice carries no payment hash.',
        'invoice',
      );
    }
    final payWithAssetId = await _resolvePayWithAsset(target, options.payWith);
    final quoted = await http.lightningSend(
      LspLightningSendRequest(invoice: invoice, payWithAssetId: payWithAssetId),
    );
    final hodl = await wallet.decodeLnInvoice(quoted.lnInvoice);
    return LspRelayQuoteVerifier.verify(
      target: target,
      hodl: hodl,
      quoted: quoted,
      maxFeeMsat: options.maxFeeMsat,
      walletNetwork: wallet.network,
      expectedLspPubkey: peer.peerPubkey,
      nowEpochSeconds: nowEpochSeconds,
    );
  }

  /// Pays a relay only after [quoteExternalPayment] verifies every invariant.
  Future<ExternalPaymentResult> payExternalInvoice(
    PayExternalInvoiceOptions options,
  ) async {
    final quote = await quoteExternalPayment(options);
    final sendResult = await wallet.payLightningInvoice(
      lnInvoice: quote.invoice,
    );
    return ExternalPaymentResult(quote: quote, sendResult: sendResult);
  }

  /// Fetches the LSP-side status for a quoted external payment.
  Future<LspLightningSendStatusResponse> externalPaymentStatus(
    String paymentHash,
  ) async {
    if (paymentHash.trim().isEmpty) {
      throw const ValidationError('paymentHash is required.', 'paymentHash');
    }
    return http.lightningSendStatus(paymentHash.trim());
  }

  Future<String?> _resolvePayWithAsset(
    DecodedLightningInvoice target,
    String? requested,
  ) async {
    final value = requested?.trim();
    if (value != null && value.isNotEmpty) {
      final needle = value.toLowerCase();
      if (needle.startsWith('rgb:')) return value;
      final assets = (await http.getInfo()).supportedAssets;
      final hit = assets
          .where((asset) => (asset.ticker ?? '').toLowerCase() == needle)
          .firstOrNull;
      if (hit == null) {
        throw LspUnknownPayableAssetException(
          requested: value,
          accepted: assets,
        );
      }
      return hit.assetId;
    }

    final requiredAmount = target.assetAmount;
    if (requiredAmount == null || requiredAmount <= 0) return null;
    final local = await _localAssetAmounts(wallet);
    final targetAssetId = target.assetId;
    if (targetAssetId != null &&
        (local[targetAssetId] ?? 0) >= requiredAmount) {
      return targetAssetId;
    }
    final alternatives = local.entries.where(
      (entry) => entry.key != targetAssetId && entry.value >= requiredAmount,
    );
    return alternatives.firstOrNull?.key;
  }
}
