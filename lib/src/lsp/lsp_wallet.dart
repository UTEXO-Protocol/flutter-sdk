import '../models/utexo_core_models.dart';
import '../wallet/utexo_wallet_types.dart';
import 'lsp_types.dart';

/// Narrow wallet contract required by `UtexoLsp`.
///
/// Keeping orchestration on this interface prevents the platform wallet,
/// generated bridge, and HTTP client from becoming one dependency cycle.
abstract interface class ILspWallet {
  /// Canonical wallet network used to reject cross-network LSP invoices.
  String get network;

  Future<void> connectPeer(String peerPubkeyAndAddr);

  Future<List<LightningChannel>> listChannels();

  Future<WalletNodeInfo> getNodeInfo();

  Future<List<LightningPayment>> listPayments();

  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  });

  Future<LightningSendRequest> payLightningInvoice({
    required String lnInvoice,
    int? amount,
    String? assetId,
    int? assetAmount,
  });

  Future<DecodedLightningInvoice> decodeLnInvoice(String invoice);

  /// Decodes an RGB invoice so bridge responses can be verified before funds
  /// move. Implementations must use the same wallet network as [network].
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice);

  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  );

  Future<ApayNewResponse> apayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  );

  Future<void> syncWallet();

  Future<RlnInvoiceStatusValue> getLightningReceiveStatus(String id);
}
