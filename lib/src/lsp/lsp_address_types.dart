import '../wallet/utexo_wallet_types.dart';
import 'lsp_types.dart';

/// Optional asset leg for a Lightning Address quote.
///
/// Omit [assetId] to let `UtexoLsp.selectPaymentAsset` choose from discovery
/// metadata and this wallet's per-channel liquidity. [amount] is retained as
/// the core-compatible alias of [assetAmount].
class PayAddressAssetParam {
  const PayAddressAssetParam({this.assetId, this.amount, this.assetAmount});

  final String? assetId;

  /// Asset amount in smallest units; an alias of [assetAmount].
  final int? amount;

  /// Asset amount in smallest units.
  final int? assetAmount;
}

/// Options for quoting or paying a Lightning Address.
class PayAddressOptions {
  const PayAddressOptions({
    required this.address,
    required this.amtMsat,
    this.asset,
  });

  /// Lightning Address, including UMA's optional leading `$` form.
  final String address;

  /// Lightning amount in millisatoshis.
  final int amtMsat;

  /// Optional RGB asset leg.
  final PayAddressAssetParam? asset;
}

/// A Lightning Address invoice that has been quoted but not paid.
class AddressQuote {
  const AddressQuote({
    required this.invoice,
    required this.amtMsat,
    this.assetId,
    this.assetAmount,
    this.assetSelection,
    this.proof,
  });

  final String invoice;

  /// Lightning amount in millisatoshis.
  final int amtMsat;

  final String? assetId;

  /// RGB amount in smallest asset units.
  final int? assetAmount;

  /// Present only when the SDK selected the quoted asset.
  final AssetSelection? assetSelection;

  /// APay inclusion proof returned by the LSP, when available.
  final ApayInvoiceProof? proof;
}

/// Result of paying a Lightning Address quote.
class PayAddressResult {
  const PayAddressResult({
    required this.invoice,
    required this.sendResult,
    this.assetSelection,
  });

  final String invoice;
  final LightningSendRequest sendResult;

  /// Present only when the SDK selected the quoted asset.
  final AssetSelection? assetSelection;
}

/// Assets advertised as payable by one Lightning Address.
class PayableAssets {
  PayableAssets({
    this.payoutAsset,
    required List<LspSupportedAsset> accepted,
    required List<LspSupportedAsset> convertible,
  }) : accepted = List<LspSupportedAsset>.unmodifiable(accepted),
       convertible = List<LspSupportedAsset>.unmodifiable(convertible);

  final LspSupportedAsset? payoutAsset;
  final List<LspSupportedAsset> accepted;
  final List<LspSupportedAsset> convertible;
}

/// Local liquidity observed for an LSP asset candidate.
class LspAssetLiquidityCandidate {
  const LspAssetLiquidityCandidate({
    required this.assetId,
    required this.localAmount,
  });

  final String assetId;

  /// Largest spendable amount on one usable channel, in smallest asset units.
  final int localAmount;
}

/// Asset selected for a Lightning Address payment.
class AssetSelection {
  const AssetSelection({
    required this.assetId,
    this.asset,
    required this.converted,
    required this.localAssetAmount,
    this.payoutAsset,
  });

  final String assetId;
  final LspSupportedAsset? asset;
  final bool converted;

  /// Largest spendable amount on one matching channel, in smallest units.
  final int localAssetAmount;

  final LspSupportedAsset? payoutAsset;
}

/// Inputs used to select a locally payable asset.
class SelectPaymentAssetOptions {
  const SelectPaymentAssetOptions({
    required this.address,
    required this.assetAmount,
    this.discovery,
  });

  final String address;

  /// Payment size in smallest asset units.
  final int assetAmount;

  /// Previously fetched discovery metadata, if available.
  final LspLnurlpDiscovery? discovery;
}

/// Preference used when no explicit external-invoice asset is supplied.
enum ExternalInvoiceAssetPreference { convertible, payout }

/// Options for creating an invoice payable by an APay-unaware external node.
class RequestExternalInvoiceOptions {
  const RequestExternalInvoiceOptions({
    required this.amtMsat,
    required this.assetAmount,
    this.asset,
    this.prefer = ExternalInvoiceAssetPreference.convertible,
    this.address,
  });

  /// Lightning amount in millisatoshis.
  final int amtMsat;

  /// RGB amount in smallest asset units.
  final int assetAmount;

  /// Ticker or contract ID. Omit to apply [prefer].
  final String? asset;

  final ExternalInvoiceAssetPreference prefer;

  /// Address to quote. Defaults to this wallet's assigned LSP address.
  final String? address;
}

/// Hosted quote that can be paid by an external Lightning node.
class ExternalInvoice extends AddressQuote {
  const ExternalInvoice({
    required super.invoice,
    required super.amtMsat,
    super.assetId,
    super.assetAmount,
    super.assetSelection,
    super.proof,
    required this.address,
    required this.username,
    required this.domain,
    this.asset,
    required this.converted,
    this.paymentHash,
  });

  final String address;
  final String username;
  final String domain;
  final LspSupportedAsset? asset;
  final bool converted;

  /// Payment hash from the APay proof, when the LSP provides one.
  final String? paymentHash;
}
