import '../errors/rgb_sdk_exception.dart';
import 'lsp_address_types.dart';
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
    required this.lastOutboundMsat,
    required this.elapsedMs,
    this.peerPubkey,
  }) : super('Timed out waiting for outbound LSP liquidity.');

  final int minMsat;
  final int lastOutboundMsat;
  final int elapsedMs;
  final String? peerPubkey;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'minMsat': minMsat,
    'lastOutboundMsat': lastOutboundMsat,
    'elapsedMs': elapsedMs,
    if (peerPubkey != null) 'peerPubkey': peerPubkey,
  };

  @override
  String toString() {
    final seconds = (elapsedMs / 1000).round();
    final peer = peerPubkey == null ? '' : ' with peer $peerPubkey';
    return 'Outbound liquidity did not reach $minMsat msat$peer after '
        '${seconds}s (last seen: $lastOutboundMsat msat)';
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
    'uri': _uriWithoutQuery(uri),
  };

  @override
  String toString() =>
      'LspTransportPolicyException(${_uriWithoutQuery(uri)}): $message';
}

String _uriWithoutQuery(Uri uri) => Uri(
  scheme: uri.scheme,
  host: uri.host,
  port: uri.hasPort ? uri.port : null,
  path: uri.path,
).toString();

/// No advertised asset has enough one-channel local liquidity.
class LspInsufficientAssetLiquidityException extends WalletException {
  LspInsufficientAssetLiquidityException({
    required this.requiredAmount,
    required List<LspAssetLiquidityCandidate> candidates,
  }) : candidates = List<LspAssetLiquidityCandidate>.unmodifiable(candidates),
       super('No accepted asset has enough spendable channel liquidity.');

  /// Required RGB amount in smallest asset units.
  final int requiredAmount;

  /// Largest local amount observed for every advertised candidate.
  final List<LspAssetLiquidityCandidate> candidates;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'required': requiredAmount,
    'candidates': candidates
        .map(
          (candidate) => <String, Object?>{
            'assetId': candidate.assetId,
            'localAmount': candidate.localAmount.toString(),
          },
        )
        .toList(growable: false),
  };
}

/// The receiver advertises neither a payout nor an accepted asset.
class LspNoPayableAssetException extends WalletException {
  const LspNoPayableAssetException({required this.address})
    : super('The Lightning Address advertises no payable RGB asset.');

  final String address;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'address': address,
  };
}

/// A requested ticker or contract ID is not accepted by the address.
class LspUnknownPayableAssetException extends ValidationError {
  LspUnknownPayableAssetException({
    required this.requested,
    required List<LspSupportedAsset> accepted,
  }) : accepted = List<LspSupportedAsset>.unmodifiable(accepted),
       super('The requested asset is not payable to this address.', 'asset');

  final String requested;
  final List<LspSupportedAsset> accepted;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'requested': requested,
    'accepted': accepted.map((asset) => asset.assetId).toList(growable: false),
  };
}

/// More than one asset matches an external-invoice preference.
class LspAmbiguousPayableAssetException extends ValidationError {
  LspAmbiguousPayableAssetException({
    required List<LspSupportedAsset> candidates,
    required this.preference,
  }) : candidates = List<LspSupportedAsset>.unmodifiable(candidates),
       super('More than one payable asset matches the preference.', 'asset');

  final List<LspSupportedAsset> candidates;
  final ExternalInvoiceAssetPreference preference;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'preference': preference.name,
    'candidates': candidates
        .map((asset) => asset.assetId)
        .toList(growable: false),
  };
}

/// An LSP relay quote does not match the invoices it claims to bind.
class LspQuoteMismatchException extends NetworkError {
  const LspQuoteMismatchException({required this.reason})
    : super('Refusing an LSP relay quote that failed local verification.');

  final String reason;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'reason': reason,
  };
}

/// A Lightning Address invoice or APay proof failed local verification.
class LspAddressQuoteVerificationException extends NetworkError {
  const LspAddressQuoteVerificationException({required this.reason})
    : super('Refusing a Lightning Address quote that failed verification.');

  /// Stable, non-secret diagnostic suitable for support telemetry.
  final String reason;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'reason': reason,
  };
}

/// An RGB/Lightning bridge response was not bound to the requested transfer.
///
/// The SDK throws this before paying a returned Lightning invoice or exposing
/// mismatched receive metadata. [reason] is stable and contains no invoice or
/// payment secret material.
class LspBridgeQuoteVerificationException extends NetworkError {
  const LspBridgeQuoteVerificationException({required this.reason})
    : super('Refusing an LSP bridge quote that failed local verification.');

  /// Stable, non-secret diagnostic suitable for support telemetry.
  final String reason;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'reason': reason,
  };
}
