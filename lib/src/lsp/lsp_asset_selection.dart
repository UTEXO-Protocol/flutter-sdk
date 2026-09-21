import '../errors/rgb_sdk_exception.dart';
import 'lsp_address_types.dart';
import 'lsp_errors.dart';
import 'lsp_types.dart';

/// Pure selection policy for discovery-backed LSP asset choices.
abstract final class LspAssetSelectionPolicy {
  /// Projects discovery into the payout, accepted, and convertible menus.
  ///
  /// The accepted list remains in server order. Selection applies its own
  /// payout-first deduplication without rewriting discovery data shown to a
  /// caller.
  static PayableAssets payableAssets(LspLnurlpDiscovery discovery) {
    final payout = discovery.payoutAsset;
    final accepted = List<LspSupportedAsset>.unmodifiable(
      discovery.acceptedAssets ??
          (payout == null
              ? const <LspSupportedAsset>[]
              : <LspSupportedAsset>[payout]),
    );
    final convertible = payout == null
        ? const <LspSupportedAsset>[]
        : accepted
              .where((asset) => asset.assetId != payout.assetId)
              .toList(growable: false);
    return PayableAssets(
      payoutAsset: payout,
      accepted: accepted,
      convertible: convertible,
    );
  }

  /// Selects the first payout-preferred asset with enough one-channel liquidity.
  static AssetSelection selectForPayment({
    required String address,
    required int requiredAmount,
    required LspLnurlpDiscovery discovery,
    required Map<String, BigInt> localAmounts,
  }) {
    if (requiredAmount <= 0) {
      throw const ValidationError(
        'assetAmount must be a positive integer in smallest asset units.',
        'assetAmount',
      );
    }
    final payable = payableAssets(discovery);
    final ordered = <LspSupportedAsset>[];
    final payout = payable.payoutAsset;
    if (payout != null) ordered.add(payout);
    for (final asset in payable.accepted) {
      if (!ordered.any((candidate) => candidate.assetId == asset.assetId)) {
        ordered.add(asset);
      }
    }
    if (ordered.isEmpty) {
      throw LspNoPayableAssetException(address: address);
    }

    final considered = <LspAssetLiquidityCandidate>[];
    for (final asset in ordered) {
      final localAmount = localAmounts[asset.assetId] ?? BigInt.zero;
      considered.add(
        LspAssetLiquidityCandidate(
          assetId: asset.assetId,
          localAmount: localAmount,
        ),
      );
      if (localAmount >= BigInt.from(requiredAmount)) {
        return AssetSelection(
          assetId: asset.assetId,
          asset: asset,
          converted:
              payable.payoutAsset != null &&
              asset.assetId != payable.payoutAsset!.assetId,
          localAssetAmount: localAmount,
          payoutAsset: payable.payoutAsset,
        );
      }
    }
    throw LspInsufficientAssetLiquidityException(
      requiredAmount: requiredAmount,
      candidates: considered,
    );
  }

  /// Resolves a ticker/contract ID or an unambiguous preference.
  static LspPayableAssetChoice pickForExternalInvoice({
    required String address,
    required PayableAssets payable,
    required String? requested,
    required ExternalInvoiceAssetPreference preference,
  }) {
    final accepted = payable.accepted;
    if (accepted.isEmpty) {
      throw LspNoPayableAssetException(address: address);
    }

    bool isConverted(LspSupportedAsset asset) {
      final payout = payable.payoutAsset;
      return payout != null && asset.assetId != payout.assetId;
    }

    final requestedValue = requested?.trim();
    if (requestedValue != null && requestedValue.isNotEmpty) {
      final needle = requestedValue.toLowerCase();
      final matches = accepted.where(
        (asset) =>
            asset.assetId.toLowerCase() == needle ||
            (asset.ticker ?? '').toLowerCase() == needle,
      );
      final hit = matches.firstOrNull;
      if (hit == null) {
        throw LspUnknownPayableAssetException(
          requested: requestedValue,
          accepted: accepted,
        );
      }
      return LspPayableAssetChoice(asset: hit, converted: isConverted(hit));
    }

    if (accepted.length == 1) {
      return LspPayableAssetChoice(
        asset: accepted.single,
        converted: isConverted(accepted.single),
      );
    }
    final payout = payable.payoutAsset;
    if (preference == ExternalInvoiceAssetPreference.payout && payout != null) {
      return LspPayableAssetChoice(asset: payout, converted: false);
    }
    if (preference == ExternalInvoiceAssetPreference.convertible) {
      if (payable.convertible.length == 1) {
        return LspPayableAssetChoice(
          asset: payable.convertible.single,
          converted: true,
        );
      }
      if (payable.convertible.isEmpty && payout != null) {
        return LspPayableAssetChoice(asset: payout, converted: false);
      }
    }
    throw LspAmbiguousPayableAssetException(
      candidates: preference == ExternalInvoiceAssetPreference.payout
          ? accepted
          : payable.convertible,
      preference: preference,
    );
  }
}

/// Internal policy result for an external invoice asset choice.
class LspPayableAssetChoice {
  const LspPayableAssetChoice({required this.asset, required this.converted});

  final LspSupportedAsset asset;
  final bool converted;
}
