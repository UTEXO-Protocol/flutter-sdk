part of 'utexo_lsp.dart';

mixin _UtexoLspAssetBridge on _UtexoLspInternals {
  /// Creates the linked Lightning and RGB invoices for an LSP receive bridge.
  Future<ReceiveAssetResult> receiveAsset(ReceiveAssetOptions options) async {
    if (options.assetId.trim().isEmpty) {
      throw const ValidationError('assetId is required.', 'assetId');
    }
    if (options.amountSats <= 0) {
      throw const ValidationError(
        'amountSats must be a positive integer.',
        'amountSats',
      );
    }
    if (options.amountRgb <= 0) {
      throw const ValidationError(
        'amountRgb must be a positive integer in smallest asset units.',
        'amountRgb',
      );
    }
    final expirySeconds = options.expirySeconds ?? 3600;
    if (expirySeconds <= 0) {
      throw const ValidationError(
        'expirySeconds must be positive.',
        'expirySeconds',
      );
    }
    final invoiceAge = Stopwatch()..start();
    final receive = await wallet.createLightningInvoice(
      amountSats: options.amountSats,
      expirySeconds: expirySeconds,
      asset: LightningAsset(
        assetId: options.assetId,
        amount: options.amountRgb,
      ),
    );
    final decodedLightning = await wallet.decodeLnInvoice(receive.lnInvoice);
    _LspBridgeQuoteVerifier.verifyCreatedReceiveInvoice(
      requested: options,
      decodedLightning: decodedLightning,
      walletNetwork: wallet.network,
      nowEpochSeconds: nowEpochSeconds,
    );

    final elapsedSeconds = invoiceAge.elapsed.inSeconds;
    if (elapsedSeconds >= expirySeconds) {
      throw const NetworkError(
        'Lightning invoice expired before the LSP mapping request.',
      );
    }
    final durationSeconds = expirySeconds - elapsedSeconds;
    final response = await http.lightningReceive(
      LspLightningReceiveRequest(
        lnInvoice: receive.lnInvoice,
        rgb: LspRgbParams(
          assetId: options.onchainAsset == ReceiveOnchainAsset.payout
              ? options.assetId
              : null,
          durationSeconds: durationSeconds,
        ),
      ),
    );
    final decodedRgb = await wallet.decodeRgbInvoice(response.rgbInvoice);
    final verified = _LspBridgeQuoteVerifier.verifyReceive(
      requested: options,
      createdLightningInvoice: receive.lnInvoice,
      response: response,
      decodedLightning: decodedLightning,
      decodedRgb: decodedRgb,
      walletNetwork: wallet.network,
      nowEpochSeconds: nowEpochSeconds,
    );
    return ReceiveAssetResult(
      lnInvoice: receive.lnInvoice,
      rgbInvoice: response.rgbInvoice,
      mappingId: response.mappingId,
      onchainAssetId: verified.onchainAssetId,
      converted: verified.converted,
    );
  }

  /// Pays an on-chain RGB invoice through the LSP's Lightning bridge.
  Future<SendAssetResult> sendAsset(SendAssetOptions options) async {
    if (options.rgbInvoice.trim().isEmpty) {
      throw const ValidationError('rgbInvoice is required.', 'rgbInvoice');
    }
    final decodedRgb = await wallet.decodeRgbInvoice(options.rgbInvoice);
    _LspBridgeQuoteVerifier.verifySendRequest(
      requested: options,
      decodedRgb: decodedRgb,
      walletNetwork: wallet.network,
      nowEpochSeconds: nowEpochSeconds,
    );
    final issued = await http.onchainSend(
      LspOnchainSendRequest(rgbInvoice: options.rgbInvoice, ln: options.ln),
    );
    final decodedLightning = await wallet.decodeLnInvoice(issued.lnInvoice);
    _LspBridgeQuoteVerifier.verifySendResponse(
      requested: options,
      issued: issued,
      decodedRgb: decodedRgb,
      decodedLightning: decodedLightning,
      walletNetwork: wallet.network,
      expectedLspPubkey: peer.peerPubkey,
      nowEpochSeconds: nowEpochSeconds,
    );
    final sendResult = await wallet.payLightningInvoice(
      lnInvoice: issued.lnInvoice,
    );
    return SendAssetResult(
      rgbInvoice: issued.rgbInvoice,
      lnInvoice: issued.lnInvoice,
      mappingId: issued.mappingId,
      sendResult: sendResult,
    );
  }
}
