import 'dart:async';

import '../wallet/utexo_wallet_types.dart';
import 'lsp_types.dart';

/// Hooks and deadlines used by polling LSP operations.
class WaitOptions {
  const WaitOptions({
    this.timeoutMs,
    this.pollIntervalMs,
    this.isCancelled,
    this.onProgress,
    this.onEachPoll,
  });

  /// Overall deadline in milliseconds.
  final int? timeoutMs;

  /// Delay between observations in milliseconds.
  final int? pollIntervalMs;

  /// Returns true when the caller no longer wants the operation to continue.
  final bool Function()? isCancelled;

  /// Receives non-sensitive, human-readable progress descriptions.
  final void Function(String message)? onProgress;

  /// Runs before each observation, for example to mine regtest blocks.
  final FutureOr<void> Function()? onEachPoll;
}

/// Selects the on-chain asset requested from the LSP receive bridge.
enum ReceiveOnchainAsset {
  /// Let the LSP select the linked canonical asset for the on-chain leg.
  convertible,

  /// Require the on-chain leg to use the Lightning payout asset itself.
  payout,
}

/// Parameters for receiving an RGB asset over Lightning through an LSP.
class ReceiveAssetOptions {
  const ReceiveAssetOptions({
    required this.assetId,
    required this.amountSats,
    required this.amountRgb,
    this.expirySeconds,
    this.onchainAsset = ReceiveOnchainAsset.convertible,
  });

  /// Asset delivered to this wallet over Lightning.
  final String assetId;

  /// Bitcoin amount encoded in the Lightning invoice, in satoshis.
  final int amountSats;

  /// RGB amount encoded in the Lightning invoice, in smallest asset units.
  final int amountRgb;

  /// Invoice lifetime in seconds. Defaults to 3600.
  final int? expirySeconds;

  /// Policy for the asset accepted on the on-chain side of the bridge.
  final ReceiveOnchainAsset onchainAsset;
}

/// Invoices and mapping metadata returned by an LSP receive bridge.
class ReceiveAssetResult {
  const ReceiveAssetResult({
    required this.lnInvoice,
    required this.rgbInvoice,
    required this.mappingId,
    this.onchainAssetId,
    required this.converted,
  });

  /// BOLT11 invoice created by this wallet.
  final String lnInvoice;

  /// RGB invoice that must be paid by the on-chain sender.
  final String rgbInvoice;

  /// LSP mapping identifier joining the two payment legs.
  final String mappingId;

  /// Asset decoded from the verified on-chain RGB invoice.
  final String? onchainAssetId;

  /// Whether the verified on-chain and Lightning asset IDs differ.
  final bool converted;
}

/// Parameters for paying an on-chain RGB invoice through an LSP.
class SendAssetOptions {
  const SendAssetOptions({required this.rgbInvoice, this.ln});

  /// Recipient's RGB invoice.
  final String rgbInvoice;

  /// Optional Lightning invoice overrides accepted by the LSP.
  final LspLnParams? ln;
}

/// LSP bridge metadata plus the wallet's resulting Lightning send record.
class SendAssetResult extends LspOnchainSendResponse {
  const SendAssetResult({
    required super.rgbInvoice,
    required super.lnInvoice,
    required super.mappingId,
    required this.sendResult,
  });

  /// Wallet result from paying the LSP's BOLT11 invoice.
  final LightningSendRequest sendResult;
}

/// Lightning Address provisioned for this wallet's node public key.
class LightningAddressInfo {
  const LightningAddressInfo({
    required this.username,
    required this.domain,
    required this.address,
    this.unusedHashes,
    this.nextIndexExpected,
    this.refillBatchSize,
  });

  final String username;
  final String domain;
  final String address;

  /// APay hashes still available after registration, when reported.
  final int? unusedHashes;

  /// Index at which the next APay batch begins, when reported.
  final int? nextIndexExpected;

  /// LSP-recommended APay refill size, when reported.
  final int? refillBatchSize;
}

/// Result of attempting to claim one pending HODL payment.
class ClaimResult {
  const ClaimResult({
    required this.paymentHash,
    required this.claimed,
    this.error,
  });

  final String paymentHash;
  final bool claimed;

  /// Redacted diagnostic when the claim was not completed.
  final String? error;
}
