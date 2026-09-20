import '../errors/rgb_sdk_exception.dart';
import '../models/utexo_core_models.dart';
import '../wallet/utexo_wallet_types.dart';
import 'lsp_errors.dart';
import 'lsp_protocol_policy.dart';

part 'lsp_quote_verifier.dart';

/// Request body for `POST /lightning_send`.
class LspLightningSendRequest {
  const LspLightningSendRequest({required this.invoice, this.payWithAssetId});

  /// Third-party BOLT11 invoice that the LSP must deliver.
  final String invoice;

  /// Asset this wallet asks to fund the relay with.
  final String? payWithAssetId;
}

/// One funding or delivery leg in an LSP Lightning relay quote.
class LspLightningSendLeg {
  const LspLightningSendLeg({
    this.assetId,
    this.assetAmount,
    required this.amtMsat,
    this.payeePubkey,
  });

  final String? assetId;

  /// RGB amount in smallest asset units.
  final int? assetAmount;

  /// Lightning amount in millisatoshis.
  final int amtMsat;

  final String? payeePubkey;
}

/// Quote returned by `POST /lightning_send`.
class LspLightningSendResponse {
  const LspLightningSendResponse({
    required this.lnInvoice,
    required this.paymentHash,
    required this.inbound,
    required this.outbound,
    required this.converted,
    required this.feeMsat,
    required this.expiresAt,
  });

  /// HODL BOLT11 that the payer must verify and pay.
  final String lnInvoice;
  final String paymentHash;
  final LspLightningSendLeg inbound;
  final LspLightningSendLeg outbound;
  final bool converted;

  /// Relay fee in millisatoshis.
  final int feeMsat;

  /// Quote expiry as a Unix timestamp in seconds.
  final int expiresAt;

  factory LspLightningSendResponse.fromWire(Map<String, Object?> map) {
    return LspLightningSendResponse(
      lnInvoice: _requiredString(map, 'ln_invoice', 'LspLightningSendResponse'),
      paymentHash: _requiredString(
        map,
        'payment_hash',
        'LspLightningSendResponse',
      ),
      inbound: _requiredLeg(map, 'inbound'),
      outbound: _requiredLeg(map, 'outbound'),
      converted: _requiredBool(map, 'converted', 'LspLightningSendResponse'),
      feeMsat: _requiredNonNegativeInt(
        map,
        'fee_msat',
        'LspLightningSendResponse',
      ),
      expiresAt: _requiredPositiveInt(
        map,
        'expires_at',
        'LspLightningSendResponse',
      ),
    );
  }
}

/// Canonical LSP relay-status string.
typedef LspLightningSendStatus = String;

/// Values accepted from `GET /lightning_send/{paymentHash}`.
abstract final class LspLightningSendStatuses {
  static const quoted = 'quoted';
  static const claimable = 'claimable';
  static const outboundPending = 'outbound_pending';
  static const outboundPaid = 'outbound_paid';
  static const outboundClaimed = 'outbound_claimed';
  static const settled = 'settled';
  static const cancelled = 'cancelled';
  static const failed = 'failed';

  static const values = <String>{
    quoted,
    claimable,
    outboundPending,
    outboundPaid,
    outboundClaimed,
    settled,
    cancelled,
    failed,
  };
}

/// Current lifecycle state of one LSP Lightning relay.
class LspLightningSendStatusResponse {
  const LspLightningSendStatusResponse({
    required this.paymentHash,
    required this.status,
    this.reason,
  });

  final String paymentHash;
  final LspLightningSendStatus status;
  final String? reason;

  factory LspLightningSendStatusResponse.fromWire(Map<String, Object?> map) {
    final status = _requiredString(
      map,
      'status',
      'LspLightningSendStatusResponse',
    );
    if (!LspLightningSendStatuses.values.contains(status)) {
      throw NativeProtocolException(
        'LspLightningSendStatusResponse.status has unknown value "$status".',
        field: 'lsp.status',
      );
    }
    return LspLightningSendStatusResponse(
      paymentHash: _requiredString(
        map,
        'payment_hash',
        'LspLightningSendStatusResponse',
      ),
      status: status,
      reason: _optionalString(map, 'reason', 'LspLightningSendStatusResponse'),
    );
  }
}

/// Inputs for quoting or paying a third-party invoice through the LSP relay.
class PayExternalInvoiceOptions {
  const PayExternalInvoiceOptions({
    required this.invoice,
    this.payWith,
    this.maxFeeMsat = 0,
  });

  /// Third-party BOLT11 invoice.
  final String invoice;

  /// Funding asset ticker or contract ID.
  final String? payWith;

  /// Maximum accepted relay fee in millisatoshis.
  final int maxFeeMsat;
}

/// Locally verified relay quote safe to submit to the wallet.
class ExternalPaymentQuote {
  const ExternalPaymentQuote._verified({
    required this.invoice,
    required this.paymentHash,
    required this.inbound,
    required this.outbound,
    required this.converted,
    required this.feeMsat,
    required this.expiresAt,
  });

  final String invoice;
  final String paymentHash;
  final LspLightningSendLeg inbound;
  final LspLightningSendLeg outbound;
  final bool converted;

  /// Relay fee in millisatoshis.
  final int feeMsat;

  /// Quote expiry as a Unix timestamp in seconds.
  final int expiresAt;

  /// True by construction: instances are returned only after local checks.
  bool get verified => true;
}

/// Result of submitting a verified external-payment quote.
class ExternalPaymentResult {
  const ExternalPaymentResult({required this.quote, required this.sendResult});

  final ExternalPaymentQuote quote;
  final LightningSendRequest sendResult;
}

LspLightningSendLeg _requiredLeg(Map<String, Object?> map, String key) {
  final raw = map[key];
  if (raw is! Map) {
    throw NativeProtocolException(
      'LspLightningSendResponse.$key must be an object.',
      field: 'lsp.$key',
    );
  }
  final leg = Map<String, Object?>.from(raw);
  return LspLightningSendLeg(
    assetId: _optionalString(leg, 'asset_id', 'LspLightningSendLeg'),
    assetAmount: _optionalNonNegativeInt(
      leg,
      'asset_amount',
      'LspLightningSendLeg',
    ),
    amtMsat: _requiredNonNegativeInt(leg, 'amt_msat', 'LspLightningSendLeg'),
    payeePubkey: _optionalString(leg, 'payee_pubkey', 'LspLightningSendLeg'),
  );
}

String _requiredString(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a non-empty string.',
    field: 'lsp.$key',
  );
}

String? _optionalString(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  if (value == null) return null;
  if (value is String) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a string when present.',
    field: 'lsp.$key',
  );
}

bool _requiredBool(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  if (value is bool) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a boolean.',
    field: 'lsp.$key',
  );
}

int _requiredNonNegativeInt(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = _integerValue(map[key]);
  if (value != null && value >= 0) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a non-negative integer.',
    field: 'lsp.$key',
  );
}

int _requiredPositiveInt(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = _integerValue(map[key]);
  if (value != null && value > 0) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a positive integer.',
    field: 'lsp.$key',
  );
}

int? _optionalNonNegativeInt(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  if (map[key] == null) return null;
  return _requiredNonNegativeInt(map, key, typeName);
}

int? _integerValue(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }
  if (value is String) return int.tryParse(value);
  return null;
}
