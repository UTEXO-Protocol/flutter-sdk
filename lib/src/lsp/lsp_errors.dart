import 'lsp_types.dart';

class LspChannelTimeoutException implements Exception {
  const LspChannelTimeoutException({
    required this.assetId,
    required this.elapsedMs,
    this.peerPubkey,
  });

  final String assetId;
  final int elapsedMs;
  final String? peerPubkey;

  @override
  String toString() {
    final seconds = (elapsedMs / 1000).round();
    final peer = peerPubkey == null ? '' : ' with peer $peerPubkey';
    return 'No usable RGB channel for $assetId$peer after ${seconds}s';
  }
}

class LspLiquidityTimeoutException implements Exception {
  const LspLiquidityTimeoutException({
    required this.minMsat,
    required this.elapsedMs,
    this.peerPubkey,
  });

  final int minMsat;
  final int elapsedMs;
  final String? peerPubkey;

  @override
  String toString() {
    final seconds = (elapsedMs / 1000).round();
    final peer = peerPubkey == null ? '' : ' with peer $peerPubkey';
    return 'No outbound liquidity of $minMsat msat$peer after ${seconds}s';
  }
}

class LspSettlementException implements Exception {
  const LspSettlementException({required this.step, required this.status});

  final String step;
  final ReceiveStatus status;

  @override
  String toString() {
    return 'Settlement ended with status "$status" at step $step';
  }
}

class LspAmountOutOfRangeException implements Exception {
  const LspAmountOutOfRangeException({
    required this.amtMsat,
    required this.minSendable,
    required this.maxSendable,
  });

  final int amtMsat;
  final int minSendable;
  final int maxSendable;

  @override
  String toString() {
    return 'amount $amtMsat msat is outside LNURL sendable range '
        '[$minSendable, $maxSendable]';
  }
}

class LspTransportPolicyException implements Exception {
  const LspTransportPolicyException(this.message, {required this.uri});

  final String message;
  final Uri uri;

  @override
  String toString() => 'LspTransportPolicyException($uri): $message';
}
