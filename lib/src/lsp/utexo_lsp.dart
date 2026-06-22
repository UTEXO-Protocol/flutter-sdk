import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http_package;

import '../models/rln_models.dart';
import '../wallet/utexo_wallet.dart';
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
      if (!error.toString().toLowerCase().contains('already')) rethrow;
    }
  }

  Future<ChannelReadyInfo> waitForChannel(
    String assetId, {
    WaitOptions options = const WaitOptions(),
  }) async {
    if (assetId.isEmpty) {
      throw ArgumentError.value(assetId, 'assetId', 'assetId is required');
    }
    final timeoutMs = options.timeoutMs ?? _defaultChannelTimeoutMs;
    final pollIntervalMs = options.pollIntervalMs ?? _defaultPollIntervalMs;
    final deadline = DateTime.now().millisecondsSinceEpoch + timeoutMs;

    while (DateTime.now().millisecondsSinceEpoch < deadline) {
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
    final timeoutMs = options.timeoutMs ?? _defaultSettlementTimeoutMs;
    final pollIntervalMs = options.pollIntervalMs ?? _defaultPollIntervalMs;
    final deadline = DateTime.now().millisecondsSinceEpoch + timeoutMs;

    while (DateTime.now().millisecondsSinceEpoch < deadline) {
      _checkCancelled(options);
      await options.onEachPoll?.call();

      await wallet.syncWallet();
      final raw = await wallet.getLightningReceiveRequest(lnInvoice);
      final status = normalizeReceiveStatus(raw);

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
      throw ArgumentError.value(
        minMsat,
        'minMsat',
        'minMsat must be non-negative',
      );
    }
    final timeoutMs = options.timeoutMs ?? _defaultChannelTimeoutMs;
    final pollIntervalMs = options.pollIntervalMs ?? _defaultPollIntervalMs;
    final deadline = DateTime.now().millisecondsSinceEpoch + timeoutMs;

    while (DateTime.now().millisecondsSinceEpoch < deadline) {
      _checkCancelled(options);
      await options.onEachPoll?.call();

      await wallet.syncWallet();
      final channels = await wallet.listChannels();
      final lspChannel = channels
          .where(
            (channel) =>
                channel.peerPubkey == peer.peerPubkey && channel.isUsable,
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
    final parts = options.address.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      throw ArgumentError.value(
        options.address,
        'address',
        'Invalid Lightning Address',
      );
    }

    final username = parts.first;
    final domain = parts.last;
    String? invoice;

    try {
      final callback = await http.resolveAddress(
        username,
        options.amtMsat,
        assetId: options.asset?.assetId,
        assetAmount: options.asset?.assetAmount,
      );
      invoice = callback.pr;
    } catch (_) {
      final metaUri = Uri.https(domain, '/.well-known/lnurlp/$username');
      final metaResponse = await _httpGet(metaUri);
      final meta = jsonDecode(metaResponse.body) as Map<String, Object?>;
      final callback = meta['callback']?.toString();
      if (callback == null || callback.isEmpty) {
        throw StateError('Missing callback in LNURL response');
      }
      final callbackUri = _addQueryParams(callback, <String, String>{
        'amount': options.amtMsat.toString(),
        if (options.asset?.assetId != null) 'asset_id': options.asset!.assetId,
        if (options.asset?.assetAmount != null)
          'asset_amount': options.asset!.assetAmount.toString(),
      });
      final callbackResponse = await _httpGet(Uri.parse(callbackUri));
      final body = jsonDecode(callbackResponse.body) as Map<String, Object?>;
      invoice = body['pr']?.toString();
    }

    if (invoice == null || invoice.isEmpty) {
      throw StateError('No invoice returned for Lightning Address');
    }
    final sendResult = await wallet.payLightningInvoice(lnInvoice: invoice);
    return PayAddressResult(invoice: invoice, sendResult: sendResult);
  }

  Future<LightningAddressInfo> enableLightningAddress() async {
    final nodeInfo = await wallet.getNodeInfo();
    if (nodeInfo.pubkey.isEmpty) {
      throw StateError('enableLightningAddress: wallet not unlocked');
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
      throw StateError('refillHashPool: wallet not unlocked');
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
    throw StateError(
      'enableLightningAddress: LSP did not provision an address for $pubkey '
      '(ensure the wallet is connected to the LSP). Last error: $lastError',
    );
  }

  Future<List<ClaimResult>> claimPendingPayments() async {
    final payments = await wallet.listPaymentsRaw();
    final claimable = payments.where((payment) {
      final status = payment.status.toUpperCase();
      return status == 'CLAIMABLE' || status == 'CLAIMING';
    });

    final results = <ClaimResult>[];
    for (final payment in claimable) {
      final preimage = payment.preimage ?? '';
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

  Future<http_package.Response> _httpGet(Uri uri) {
    return http_package.get(uri);
  }

  bool _isUsableRgbChannel(RlnChannel channel, String assetId) {
    return channel.peerPubkey == peer.peerPubkey &&
        channel.assetId == assetId &&
        channel.isUsable;
  }

  ChannelReadyInfo _toChannelReadyInfo(RlnChannel channel) {
    return ChannelReadyInfo(
      channelId: channel.channelId,
      peerPubkey: channel.peerPubkey,
      capacitySat: channel.capacitySat,
      outboundBalanceMsat: channel.outboundBalanceMsat,
      inboundBalanceMsat: channel.inboundBalanceMsat,
    );
  }

  void _checkCancelled(WaitOptions options) {
    if (options.isCancelled?.call() == true) {
      throw StateError('UtexoLsp: operation cancelled');
    }
  }

  Future<void> _sleep(int ms, WaitOptions options) async {
    final end = DateTime.now().millisecondsSinceEpoch + ms;
    while (DateTime.now().millisecondsSinceEpoch < end) {
      _checkCancelled(options);
      final remaining = end - DateTime.now().millisecondsSinceEpoch;
      await Future<void>.delayed(
        Duration(milliseconds: remaining.clamp(1, 250).toInt()),
      );
    }
  }

  String _addQueryParams(String url, Map<String, String> params) {
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: <String, String>{...uri.queryParameters, ...params},
        )
        .toString();
  }
}
