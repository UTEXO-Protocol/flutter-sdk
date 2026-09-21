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
    final deadline = _PollDeadline(timer, timeoutMs, options);

    while (timer.elapsedMilliseconds < timeoutMs) {
      try {
        _checkCancelled(options);
        await deadline.run(() async => options.onEachPoll?.call());
        await deadline.run(wallet.syncWallet);
        final channels = await deadline.run(wallet.listChannels);
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
        deadline.check();
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
        await deadline.pause(pollIntervalMs);
      } on _PollDeadlineExpired {
        break;
      }
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
    final deadline = _PollDeadline(timer, timeoutMs, options);

    while (timer.elapsedMilliseconds < timeoutMs) {
      try {
        _checkCancelled(options);
        await deadline.run(() async => options.onEachPoll?.call());
        await deadline.run(wallet.syncWallet);
        final status = await deadline.run(
          () => wallet.getLightningReceiveStatus(lnInvoice),
        );
        options.onProgress?.call(status);
        deadline.check();

        if (status == RlnInvoiceStatuses.succeeded) {
          return ReceiveSettlementOutcomes.settled;
        }
        if (status == RlnInvoiceStatuses.failed ||
            status == RlnInvoiceStatuses.expired ||
            status == RlnInvoiceStatuses.cancelled) {
          throw LspSettlementException(step: 'ln_invoice', status: status);
        }
        await deadline.pause(pollIntervalMs);
      } on _PollDeadlineExpired {
        break;
      }
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
    final deadline = _PollDeadline(timer, timeoutMs, options);
    var lastOutboundMsat = 0;

    while (timer.elapsedMilliseconds < timeoutMs) {
      try {
        _checkCancelled(options);
        await deadline.run(() async => options.onEachPoll?.call());
        await deadline.run(wallet.syncWallet);
        final channels = await deadline.run(wallet.listChannels);
        final balances = channels
            .where(
              (channel) =>
                  channel.peerPubkey == peer.peerPubkey &&
                  _isUsableChannel(channel),
            )
            .map(
              (channel) =>
                  channel.outboundBalanceMsat ?? channel.localBalanceMsat ?? 0,
            );
        // One sufficiently funded channel is required; no MPP contract is assumed.
        lastOutboundMsat = balances.fold<int>(
          0,
          (largest, value) => value > largest ? value : largest,
        );
        options.onProgress?.call(
          'outbound: $lastOutboundMsat msat (need $minMsat)',
        );
        deadline.check();
        if (lastOutboundMsat >= minMsat) return;
        await deadline.pause(pollIntervalMs);
      } on _PollDeadlineExpired {
        break;
      }
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

final class _PollDeadlineExpired implements Exception {
  const _PollDeadlineExpired();
}

/// Bounds polling without implying cancellation of an already dispatched call.
/// Each continuation checks the budget before it may start another operation.
final class _PollDeadline {
  _PollDeadline(this.timer, this.timeoutMs, this.options);

  final Stopwatch timer;
  final int timeoutMs;
  final WaitOptions options;

  void check() {
    _checkCancelled(options);
    if (timer.elapsedMilliseconds >= timeoutMs) {
      throw const _PollDeadlineExpired();
    }
  }

  Future<void> pause(int milliseconds) async {
    Timer? delay;
    try {
      await run(() {
        final completed = Completer<void>();
        delay = Timer(Duration(milliseconds: milliseconds), completed.complete);
        return completed.future;
      });
    } finally {
      delay?.cancel();
    }
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    check();
    final result = Completer<T>();
    final deadlineTimer = Timer(
      Duration(milliseconds: timeoutMs - timer.elapsedMilliseconds),
      () => result.completeError(const _PollDeadlineExpired()),
    );
    final cancellationTimer = options.isCancelled == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 25), (_) {
            if (result.isCompleted) return;
            try {
              _checkCancelled(options);
            } catch (error, stack) {
              result.completeError(error, stack);
            }
          });
    try {
      unawaited(
        Future<T>.sync(operation).then(
          (value) {
            if (!result.isCompleted) result.complete(value);
          },
          onError: (Object error, StackTrace stack) {
            if (!result.isCompleted) result.completeError(error, stack);
          },
        ),
      );
      final value = await result.future;
      check();
      return value;
    } finally {
      deadlineTimer.cancel();
      cancellationTimer?.cancel();
    }
  }
}
