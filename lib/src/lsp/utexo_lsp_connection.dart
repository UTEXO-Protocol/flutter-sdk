part of 'utexo_lsp.dart';

mixin _UtexoLspConnection on _UtexoLspInternals {
  /// Connects the wallet to the configured LSP peer.
  Future<void> connect() async {
    try {
      await wallet.connectPeer(peerUri(peer));
    } catch (error) {
      if (!_isAlreadyConnectedError(error)) rethrow;
    }
  }

  /// Waits for a usable RGB channel with the configured LSP peer.
  Future<ChannelReadyInfo> waitForChannel(
    String assetId, {
    WaitOptions options = const WaitOptions(),
  }) async {
    if (assetId.trim().isEmpty) {
      throw const ValidationError('assetId is required.', 'assetId');
    }
    final timeoutMs = _validatedTimeoutMs(options, _defaultChannelTimeoutMs);
    final pollIntervalMs = _validatedPollIntervalMs(options);
    final timer = Stopwatch()..start();

    while (timer.elapsedMilliseconds < timeoutMs) {
      _checkCancelled(options);
      await options.onEachPoll?.call();
      await wallet.syncWallet();
      final channels = await wallet.listChannels();
      final match = channels
          .where(
            (channel) =>
                channel.peerPubkey == peer.peerPubkey &&
                channel.assetId == assetId &&
                _isUsableChannel(channel),
          )
          .firstOrNull;
      options.onProgress?.call(
        'channels: ${channels.length}; RGB usable: ${match == null ? 'no' : 'yes'}',
      );
      if (match != null) {
        return ChannelReadyInfo(
          channelId: match.channelId,
          peerPubkey: match.peerPubkey,
          capacitySat: match.capacitySat,
          outboundBalanceMsat:
              match.outboundBalanceMsat ?? match.localBalanceMsat ?? 0,
          inboundBalanceMsat:
              match.inboundBalanceMsat ?? match.remoteBalanceMsat ?? 0,
        );
      }
      await _sleep(pollIntervalMs, options);
    }

    throw LspChannelTimeoutException(
      assetId: assetId,
      elapsedMs: timer.elapsedMilliseconds,
      peerPubkey: peer.peerPubkey,
    );
  }

  /// Waits for an inbound invoice to settle or reach a terminal error.
  Future<ReceiveSettlementOutcome> awaitReceiveSettlement(
    String lnInvoice, {
    WaitOptions options = const WaitOptions(),
  }) async {
    if (lnInvoice.trim().isEmpty) {
      throw const ValidationError('lnInvoice is required.', 'lnInvoice');
    }
    final timeoutMs = _validatedTimeoutMs(options, _defaultSettlementTimeoutMs);
    final pollIntervalMs = _validatedPollIntervalMs(options);
    final timer = Stopwatch()..start();

    while (timer.elapsedMilliseconds < timeoutMs) {
      _checkCancelled(options);
      await options.onEachPoll?.call();
      await wallet.syncWallet();
      final status = await wallet.getLightningReceiveStatus(lnInvoice);
      options.onProgress?.call(status);

      if (status == RlnInvoiceStatuses.succeeded) {
        return ReceiveSettlementOutcomes.settled;
      }
      if (status == RlnInvoiceStatuses.failed ||
          status == RlnInvoiceStatuses.expired ||
          status == RlnInvoiceStatuses.cancelled) {
        throw LspSettlementException(step: 'ln_invoice', status: status);
      }
      await _sleep(pollIntervalMs, options);
    }

    options.onProgress?.call('timeout');
    return ReceiveSettlementOutcomes.timedOut;
  }

  /// Waits until the LSP channel has at least [minMsat] outbound liquidity.
  Future<void> waitForOutboundLiquidity(
    int minMsat, {
    WaitOptions options = const WaitOptions(),
  }) async {
    if (minMsat < 0) {
      throw const ValidationError('minMsat must be non-negative.', 'minMsat');
    }
    final timeoutMs = _validatedTimeoutMs(options, _defaultChannelTimeoutMs);
    final pollIntervalMs = _validatedPollIntervalMs(options);
    final timer = Stopwatch()..start();
    var lastOutboundMsat = 0;

    while (timer.elapsedMilliseconds < timeoutMs) {
      _checkCancelled(options);
      await options.onEachPoll?.call();
      await wallet.syncWallet();
      final channels = await wallet.listChannels();
      final lspChannel = channels
          .where(
            (channel) =>
                channel.peerPubkey == peer.peerPubkey &&
                _isUsableChannel(channel),
          )
          .firstOrNull;
      lastOutboundMsat =
          lspChannel?.outboundBalanceMsat ?? lspChannel?.localBalanceMsat ?? 0;
      options.onProgress?.call(
        'outbound: $lastOutboundMsat msat (need $minMsat)',
      );
      if (lastOutboundMsat >= minMsat) return;
      await _sleep(pollIntervalMs, options);
    }

    throw LspLiquidityTimeoutException(
      minMsat: minMsat,
      lastOutboundMsat: lastOutboundMsat,
      elapsedMs: timer.elapsedMilliseconds,
      peerPubkey: peer.peerPubkey,
    );
  }

  bool _isAlreadyConnectedError(Object error) {
    if (error is ConflictError) return true;
    return error is RgbSdkException && error.code == 'CONFLICT';
  }
}
