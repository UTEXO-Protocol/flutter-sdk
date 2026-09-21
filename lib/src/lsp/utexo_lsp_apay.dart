part of 'utexo_lsp.dart';

mixin _UtexoLspApay on _UtexoLspInternals {
  /// Registers the first attested APay hash batch for this wallet.
  Future<LightningAddressInfo> enableLightningAddress() async {
    final lspInfo = await http.getInfo();
    _requireConfiguredLsp(lspInfo);
    final address = await _ownLightningAddress(this, 'enableLightningAddress');
    final pool = await wallet.apayNewWithAddress(
      lspInfo.pubkey,
      address.username,
      address.domain,
    );
    return LightningAddressInfo(
      username: address.username,
      domain: address.domain,
      address: '${address.username}@${address.domain}',
      unusedHashes: pool.unusedHashes,
      nextIndexExpected: pool.nextIndexExpected,
      refillBatchSize: pool.refillBatchSize,
    );
  }

  /// Registers a fresh attested APay hash batch for the assigned address.
  Future<ApayNewResponse> refillHashPool() async {
    final nodeInfo = await wallet.getNodeInfo();
    if (nodeInfo.pubkey.isEmpty) {
      throw const WalletException(
        'refillHashPool requires an unlocked wallet.',
      );
    }
    final lspInfo = await http.getInfo();
    _requireConfiguredLsp(lspInfo);
    final address = await http.getLightningAddressByPubkey(nodeInfo.pubkey);
    return wallet.apayNewWithAddress(
      lspInfo.pubkey,
      address.username,
      address.domain,
    );
  }

  void _requireConfiguredLsp(LspGetInfoResponse info) {
    if (info.pubkey.trim().toLowerCase() !=
            peer.peerPubkey.trim().toLowerCase() ||
        LspNetworkPolicy.canonical(info.network) !=
            LspNetworkPolicy.canonical(wallet.network)) {
      throw const LspQuoteMismatchException(
        reason: 'APay host identity or network differs from the configured LSP',
      );
    }
  }

  /// Claims every locally claimable payment that has a non-empty preimage.
  Future<List<ClaimResult>> claimPendingPayments() async {
    final claimable = (await wallet.listPayments()).where(
      (payment) => isClaimablePaymentStatus(payment.status),
    );
    final results = <ClaimResult>[];
    for (final payment in claimable) {
      final preimage = payment.preimage;
      if (preimage == null || preimage.isEmpty) {
        results.add(
          ClaimResult(
            paymentHash: payment.paymentHash,
            claimed: false,
            error: 'Missing preimage for claimable payment.',
          ),
        );
        continue;
      }
      try {
        await wallet.claimHodlInvoice(payment.paymentHash, preimage);
        results.add(
          ClaimResult(paymentHash: payment.paymentHash, claimed: true),
        );
      } catch (_) {
        results.add(
          ClaimResult(
            paymentHash: payment.paymentHash,
            claimed: false,
            error: 'Payment claim failed. Check its status before retrying.',
          ),
        );
      }
    }
    return List<ClaimResult>.unmodifiable(results);
  }
}
