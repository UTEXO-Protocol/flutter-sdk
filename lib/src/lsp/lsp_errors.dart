import '../errors/rgb_sdk_exception.dart';
import 'lsp_types.dart';

class LspChannelTimeoutException extends NetworkError {
  const LspChannelTimeoutException({
    required this.assetId,
    required this.elapsedMs,
    this.peerPubkey,
  }) : super('Timed out waiting for a usable RGB channel.', cause: assetId);

  final String assetId;
  final int elapsedMs;
  final String? peerPubkey;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'assetId': assetId,
    'elapsedMs': elapsedMs,
    if (peerPubkey != null) 'peerPubkey': peerPubkey,
  };

  @override
  String toString() {
    final seconds = (elapsedMs / 1000).round();
    final peer = peerPubkey == null ? '' : ' with peer $peerPubkey';
    return 'No usable RGB channel for $assetId$peer after ${seconds}s';
  }
}

class LspLiquidityTimeoutException extends NetworkError {
  const LspLiquidityTimeoutException({
    required this.minMsat,
    required this.elapsedMs,
    this.peerPubkey,
  }) : super('Timed out waiting for outbound LSP liquidity.');

  final int minMsat;
  final int elapsedMs;
  final String? peerPubkey;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'minMsat': minMsat,
    'elapsedMs': elapsedMs,
    if (peerPubkey != null) 'peerPubkey': peerPubkey,
  };

  @override
  String toString() {
    final seconds = (elapsedMs / 1000).round();
    final peer = peerPubkey == null ? '' : ' with peer $peerPubkey';
    return 'No outbound liquidity of $minMsat msat$peer after ${seconds}s';
  }
}

class LspSettlementException extends WalletException {
  const LspSettlementException({required this.step, required this.status})
    : super('LSP settlement reached a terminal non-success state.');

  final String step;
  final ReceiveStatus status;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'step': step,
    'status': status,
  };

  @override
  String toString() {
    return 'Settlement ended with status "$status" at step $step';
  }
}

class LspAmountOutOfRangeException extends ValidationError {
  const LspAmountOutOfRangeException({
    required this.amtMsat,
    required this.minSendable,
    required this.maxSendable,
  }) : super('amtMsat is outside the LNURL sendable range', 'amtMsat');

  final int amtMsat;
  final int minSendable;
  final int maxSendable;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'amtMsat': amtMsat,
    'minSendable': minSendable,
    'maxSendable': maxSendable,
  };

  @override
  String toString() {
    return 'amount $amtMsat msat is outside LNURL sendable range '
        '[$minSendable, $maxSendable]';
  }
}

class LspTransportPolicyException extends ConfigurationError {
  const LspTransportPolicyException(super.message, {required this.uri});

  final Uri uri;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'uri': uri.toString(),
  };

  @override
  String toString() => 'LspTransportPolicyException($uri): $message';
}
