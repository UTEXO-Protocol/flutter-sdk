import 'dart:async';

import '../crypto/validation.dart';
import '../errors/rgb_sdk_exception.dart';
import '../models/utexo_core_models.dart';
import '../wallet/utexo_wallet.dart';
import '../wallet/utexo_wallet_types.dart';
import 'lsp_errors.dart';
import 'lsp_types.dart';
import 'utexo_lsp_client.dart';

class WaitOptions {
  const WaitOptions({
    this.timeoutMs,
    this.pollIntervalMs,
    this.isCancelled,
    this.onProgress,
    this.onEachPoll,
  });

  final int? timeoutMs;
  final int? pollIntervalMs;
  final bool Function()? isCancelled;
  final void Function(String message)? onProgress;
  final FutureOr<void> Function()? onEachPoll;
}

class ReceiveAssetOptions {
  const ReceiveAssetOptions({
    required this.assetId,
    required this.amountSats,
    required this.amountRgb,
    this.expirySeconds,
  });

  final String assetId;
  final int amountSats;
  final int amountRgb;
  final int? expirySeconds;
}

class ReceiveAssetResult {
  const ReceiveAssetResult({
    required this.lnInvoice,
    required this.rgbInvoice,
    required this.mappingId,
  });

  final String lnInvoice;
  final String rgbInvoice;
  final String mappingId;
}

class SendAssetOptions {
  const SendAssetOptions({required this.rgbInvoice, this.ln});

  final String rgbInvoice;
  final LspLnParams? ln;
}

class SendAssetResult extends LspOnchainSendResponse {
  const SendAssetResult({
    required super.rgbInvoice,
    required super.lnInvoice,
    required super.mappingId,
    required this.sendResult,
  });

  final LightningSendRequest sendResult;
}

class PayAddressOptions {
  const PayAddressOptions({
    required this.address,
    required this.amtMsat,
    this.asset,
  });

  final String address;
  final int amtMsat;
  final PayAddressAsset? asset;
}

class PayAddressAsset {
  const PayAddressAsset({required this.assetId, required this.assetAmount});

  final String assetId;
  final int assetAmount;
}

class LightningAddressInfo {
  const LightningAddressInfo({
    required this.username,
    required this.domain,
    required this.address,
    required this.unusedHashes,
    required this.nextIndexExpected,
    required this.refillBatchSize,
  });

  final String username;
  final String domain;
  final String address;
  final int unusedHashes;
  final int nextIndexExpected;
  final int refillBatchSize;
}

class ClaimResult {
  const ClaimResult({
    required this.paymentHash,
    required this.claimed,
    this.error,
  });

  final String paymentHash;
  final bool claimed;
  final String? error;
}

class PayAddressResult {
  const PayAddressResult({required this.invoice, required this.sendResult});

  final String invoice;
  final LightningSendRequest sendResult;
}

class UtexoLsp {
  UtexoLsp({
    required this.wallet,
    required this.peer,
    IUtexoLspClient? httpClient,
  }) : http =
           httpClient ??
           UtexoLspClient(
             baseUrl: peer.baseUrl,
             bearerToken: peer.bearerToken,
             timeoutMs: peer.timeoutMs,
           );

  static const _defaultChannelTimeoutMs = 120000;
  static const _defaultSettlementTimeoutMs = 60000;
  static const _defaultPollIntervalMs = 2000;
  static const _minPollIntervalMs = 50;

  final UtexoWallet wallet;
  final LspPeer peer;
  final IUtexoLspClient http;

  void close() {
    http.close();
  }

  void dispose() {
    close();
  }

  Future<void> connect() async {
    try {
      await wallet.connectPeer(peerUri(peer));
    } catch (error) {
      if (!_isAlreadyConnectedError(error)) rethrow;
    }
  }

  Future<ChannelReadyInfo> waitForChannel(
    String assetId, {
    WaitOptions options = const WaitOptions(),
  }) async {
    if (assetId.isEmpty) {
      throw const ValidationError('assetId is required', 'assetId');
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
          .where((channel) => _isUsableRgbChannel(channel, assetId))
          .firstOrNull;

      options.onProgress?.call(
        'channels: ${channels.length} - RGB usable: ${match == null ? 'no' : 'yes'}',
      );

      if (match != null) return _toChannelReadyInfo(match);
      await _sleep(pollIntervalMs, options);
    }

    throw LspChannelTimeoutException(
      assetId: assetId,
      elapsedMs: timeoutMs,
      peerPubkey: peer.peerPubkey,
    );
  }

  Future<ReceiveAssetResult> receiveAsset(ReceiveAssetOptions options) async {
    final expirySeconds = options.expirySeconds ?? 3600;
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;
    final receive = await wallet.createLightningInvoice(
      amountSats: options.amountSats,
      expirySeconds: expirySeconds,
      asset: LightningAsset(
        assetId: options.assetId,
        amount: options.amountRgb,
      ),
    );

    final elapsedSeconds =
        ((DateTime.now().millisecondsSinceEpoch - createdAtMs) / 1000).round();
    final durationSeconds = (expirySeconds - elapsedSeconds)
        .clamp(1, expirySeconds)
        .toInt();

    final lspReceive = await http.lightningReceive(
      LspLightningReceiveRequest(
        lnInvoice: receive.lnInvoice,
        rgb: LspRgbParams(
          assetId: options.assetId,
          durationSeconds: durationSeconds,
        ),
      ),
    );

    return ReceiveAssetResult(
      lnInvoice: receive.lnInvoice,
      rgbInvoice: lspReceive.rgbInvoice,
      mappingId: lspReceive.mappingId,
    );
  }

  Future<ReceiveSettlementOutcome> awaitReceiveSettlement(
    String lnInvoice, {
    WaitOptions options = const WaitOptions(),
  }) async {
    final timeoutMs = _validatedTimeoutMs(options, _defaultSettlementTimeoutMs);
    final pollIntervalMs = _validatedPollIntervalMs(options);
    final timer = Stopwatch()..start();

    while (timer.elapsedMilliseconds < timeoutMs) {
      _checkCancelled(options);
      await options.onEachPoll?.call();

      await wallet.syncWallet();
      final status = normalizeReceiveStatus(
        await wallet.getLightningReceiveStatus(lnInvoice),
      );

      options.onProgress?.call(status);

      if (status == ReceiveStatuses.succeeded) {
        return ReceiveSettlementOutcomes.settled;
      }
      if (status == ReceiveStatuses.failed ||
          status == ReceiveStatuses.expired) {
        throw LspSettlementException(step: 'ln_invoice', status: status);
      }

      await _sleep(pollIntervalMs, options);
    }

    options.onProgress?.call('timeout');
    return ReceiveSettlementOutcomes.timedOut;
  }

  Future<void> waitForOutboundLiquidity(
    int minMsat, {
    WaitOptions options = const WaitOptions(),
  }) async {
    if (minMsat < 0) {
      throw const ValidationError('minMsat must be non-negative', 'minMsat');
    }
    final timeoutMs = _validatedTimeoutMs(options, _defaultChannelTimeoutMs);
    final pollIntervalMs = _validatedPollIntervalMs(options);
    final timer = Stopwatch()..start();

    while (timer.elapsedMilliseconds < timeoutMs) {
      _checkCancelled(options);
      await options.onEachPoll?.call();

      await wallet.syncWallet();
      final channels = await wallet.listChannels();
      final lspChannel = channels
          .where(
            (channel) =>
                channel.peerPubkey == peer.peerPubkey &&
                channel.isUsable == true,
          )
          .firstOrNull;
      final outbound = lspChannel?.outboundBalanceMsat ?? 0;

      options.onProgress?.call('outbound: $outbound msat (need $minMsat)');
      if (outbound >= minMsat) return;

      await _sleep(pollIntervalMs, options);
    }

    throw LspLiquidityTimeoutException(
      minMsat: minMsat,
      elapsedMs: timeoutMs,
      peerPubkey: peer.peerPubkey,
    );
  }

  Future<SendAssetResult> sendAsset(SendAssetOptions options) async {
    final issued = await http.onchainSend(
      LspOnchainSendRequest(rgbInvoice: options.rgbInvoice, ln: options.ln),
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

  Future<PayAddressResult> payAddress(PayAddressOptions options) async {
    final parsedAddress = parseLightningAddress(options.address);
    final username = parsedAddress.username;
    final domain = parsedAddress.domain;
    if (options.amtMsat <= 0) {
      throw const ValidationError(
        'amtMsat must be a finite positive integer (msat)',
        'amtMsat',
      );
    }
    final asset = options.asset;
    if (asset != null && asset.assetAmount < 0) {
      throw const ValidationError(
        'asset.assetAmount must be non-negative',
        'asset.assetAmount',
      );
    }
    String? invoice;

    if (isSameLspHost(domain, peer.baseUrl)) {
      final callback = await http.resolveAddress(
        username,
        options.amtMsat,
        assetId: asset?.assetId,
        assetAmount: asset?.assetAmount,
      );
      invoice = callback.pr;
    } else {
      final callback = await http.resolveExternalAddress(
        domain,
        username,
        options.amtMsat,
        assetId: asset?.assetId,
        assetAmount: asset?.assetAmount,
      );
      invoice = callback.pr;
    }

    if (invoice.isEmpty) {
      throw const LspError(
        endpoint: 'lightning-address',
        status: 200,
        body: 'No invoice returned for Lightning Address',
      );
    }
    final sendResult = await wallet.payLightningInvoice(lnInvoice: invoice);
    return PayAddressResult(invoice: invoice, sendResult: sendResult);
  }

  Future<LightningAddressInfo> enableLightningAddress() async {
    final nodeInfo = await wallet.getNodeInfo();
    if (nodeInfo.pubkey.isEmpty) {
      throw const WalletException(
        'enableLightningAddress: wallet not unlocked',
      );
    }

    final lspInfo = await http.getInfo();
    final address = await _resolveLightningAddress(nodeInfo.pubkey);
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

  Future<ApayNewResponse> refillHashPool() async {
    final nodeInfo = await wallet.getNodeInfo();
    if (nodeInfo.pubkey.isEmpty) {
      throw const WalletException('refillHashPool: wallet not unlocked');
    }

    final lspInfo = await http.getInfo();
    final address = await http.getLightningAddressByPubkey(nodeInfo.pubkey);
    return wallet.apayNewWithAddress(
      lspInfo.pubkey,
      address.username,
      address.domain,
    );
  }

  Future<LspLightningAddressByPubkeyResponse> _resolveLightningAddress(
    String pubkey, {
    int attempts = 8,
    int delayMs = 2000,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        final address = await http.getLightningAddressByPubkey(pubkey);
        if (address.username.isNotEmpty && address.domain.isNotEmpty) {
          return address;
        }
      } catch (error) {
        lastError = error;
      }
      if (attempt < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw NetworkError(
      'enableLightningAddress: LSP did not provision an address for $pubkey '
      '(ensure the wallet is connected to the LSP).',
      cause: lastError,
    );
  }

  Future<List<ClaimResult>> claimPendingPayments() async {
    final payments = await wallet.listPaymentsRaw();
    final claimable = payments.where((payment) {
      final status = tryNormalizePaymentStatus(payment.status);
      return status != null && isClaimablePaymentStatus(status);
    });

    final results = <ClaimResult>[];
    for (final payment in claimable) {
      final preimage = payment.preimage;
      if (preimage == null || preimage.isEmpty) {
        results.add(
          ClaimResult(
            paymentHash: payment.paymentHash,
            claimed: false,
            error: 'Missing preimage for claimable payment',
          ),
        );
        continue;
      }
      try {
        await wallet.claimHodlInvoice(payment.paymentHash, preimage);
        results.add(
          ClaimResult(paymentHash: payment.paymentHash, claimed: true),
        );
      } catch (error) {
        results.add(
          ClaimResult(
            paymentHash: payment.paymentHash,
            claimed: false,
            error: error.toString(),
          ),
        );
      }
    }
    return results;
  }

  bool _isUsableRgbChannel(LightningChannel channel, String assetId) {
    return channel.peerPubkey == peer.peerPubkey &&
        channel.assetId == assetId &&
        _isUsable(channel);
  }

  ChannelReadyInfo _toChannelReadyInfo(LightningChannel channel) {
    return ChannelReadyInfo(
      channelId: channel.channelId,
      peerPubkey: channel.peerPubkey,
      capacitySat: channel.capacitySat,
      outboundBalanceMsat: channel.outboundBalanceMsat ?? 0,
      inboundBalanceMsat: channel.inboundBalanceMsat ?? 0,
    );
  }

  void _checkCancelled(WaitOptions options) {
    if (options.isCancelled?.call() == true) {
      throw const OperationCancelledError('UtexoLsp: operation cancelled');
    }
  }

  Future<void> _sleep(int ms, WaitOptions options) async {
    final timer = Stopwatch()..start();
    while (timer.elapsedMilliseconds < ms) {
      _checkCancelled(options);
      final remaining = ms - timer.elapsedMilliseconds;
      await Future<void>.delayed(
        Duration(milliseconds: remaining.clamp(1, 250).toInt()),
      );
    }
  }

  bool _isUsable(LightningChannel channel) {
    return channel.isUsable ?? channel.ready;
  }

  int _validatedTimeoutMs(WaitOptions options, int fallback) {
    final value = options.timeoutMs ?? fallback;
    if (value <= 0) {
      throw const ValidationError(
        'timeoutMs must be a positive integer',
        'timeoutMs',
      );
    }
    return value;
  }

  int _validatedPollIntervalMs(WaitOptions options) {
    final value = options.pollIntervalMs ?? _defaultPollIntervalMs;
    if (value < _minPollIntervalMs) {
      throw ValidationError(
        'pollIntervalMs must be at least $_minPollIntervalMs',
        'pollIntervalMs',
      );
    }
    return value;
  }

  bool _isAlreadyConnectedError(Object error) {
    if (error is ConflictError) return true;
    if (error is RgbSdkException && error.code == 'CONFLICT') return true;
    return false;
  }
}
