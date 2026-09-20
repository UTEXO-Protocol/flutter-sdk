part of 'utexo_lsp.dart';

const _bridgeClockSkewSeconds = 300;
const _bridgeExpiryToleranceSeconds = 5;

final class _VerifiedReceiveBridge {
  const _VerifiedReceiveBridge({
    required this.onchainAssetId,
    required this.converted,
  });

  final String onchainAssetId;
  final bool converted;
}

final class _VerifiedRgbBridgeInvoice {
  const _VerifiedRgbBridgeInvoice({
    required this.assetId,
    required this.amount,
    required this.expiresAt,
  });

  final String assetId;
  final int amount;
  final int expiresAt;
}

/// Funds-safety checks shared by the two RGB/Lightning bridge directions.
///
/// The LSP response is untrusted until every signed invoice and echoed field is
/// tied to the caller's request. None of these checks may happen after payment.
abstract final class _LspBridgeQuoteVerifier {
  static int verifyCreatedReceiveInvoice({
    required ReceiveAssetOptions requested,
    required DecodedLightningInvoice decodedLightning,
    required String walletNetwork,
    required int nowEpochSeconds,
  }) {
    _verifyNetwork(decodedLightning.network, walletNetwork, 'Lightning');
    final lightningExpiry = _lightningExpiry(decodedLightning, nowEpochSeconds);
    final expectedMsat = requested.amountSats * 1000;
    if (expectedMsat <= 0 || decodedLightning.amtMsat != expectedMsat) {
      _fail('the created Lightning invoice amount differs from the request');
    }
    if (_requiredValue(decodedLightning.assetId, 'Lightning asset') !=
        requested.assetId.trim()) {
      _fail('the created Lightning invoice asset differs from the request');
    }
    if (decodedLightning.assetAmount != requested.amountRgb) {
      _fail(
        'the created Lightning invoice asset amount differs from the request',
      );
    }
    final requestedExpiry = requested.expirySeconds ?? 3600;
    if (decodedLightning.expirySec != requestedExpiry) {
      _fail('the created Lightning invoice expiry differs from the request');
    }
    return lightningExpiry;
  }

  static _VerifiedReceiveBridge verifyReceive({
    required ReceiveAssetOptions requested,
    required String createdLightningInvoice,
    required LspLightningReceiveResponse response,
    required DecodedLightningInvoice decodedLightning,
    required CoreInvoiceData decodedRgb,
    required String walletNetwork,
    required int nowEpochSeconds,
  }) {
    if (response.lnInvoice.trim() != createdLightningInvoice.trim()) {
      _fail('the response references a different Lightning invoice');
    }
    final lightningExpiry = verifyCreatedReceiveInvoice(
      requested: requested,
      decodedLightning: decodedLightning,
      walletNetwork: walletNetwork,
      nowEpochSeconds: nowEpochSeconds,
    );

    final rgb = _verifyRgbInvoice(
      decodedRgb,
      walletNetwork: walletNetwork,
      nowEpochSeconds: nowEpochSeconds,
    );
    if (rgb.amount != requested.amountRgb) {
      _fail('the returned RGB invoice amount differs from the request');
    }
    if ((rgb.expiresAt - lightningExpiry).abs() >
        _bridgeExpiryToleranceSeconds) {
      _fail('the RGB and Lightning invoice expiries do not match');
    }
    if (requested.onchainAsset == ReceiveOnchainAsset.payout &&
        rgb.assetId != requested.assetId.trim()) {
      _fail('payout mode returned an RGB invoice for another asset');
    }
    final reportedAsset = response.rgbAssetId?.trim();
    if (reportedAsset != null &&
        reportedAsset.isNotEmpty &&
        reportedAsset != rgb.assetId) {
      _fail('the reported on-chain asset differs from the RGB invoice');
    }
    final converted = rgb.assetId != requested.assetId.trim();
    if (response.converted != null && response.converted != converted) {
      _fail('the conversion flag disagrees with the signed invoices');
    }
    return _VerifiedReceiveBridge(
      onchainAssetId: rgb.assetId,
      converted: converted,
    );
  }

  static void verifySendRequest({
    required SendAssetOptions requested,
    required CoreInvoiceData decodedRgb,
    required String walletNetwork,
    required int nowEpochSeconds,
  }) {
    final rgb = _verifyRgbInvoice(
      decodedRgb,
      walletNetwork: walletNetwork,
      nowEpochSeconds: nowEpochSeconds,
    );
    final ln = requested.ln;
    if (ln == null) return;

    _requirePositiveOptional(ln.amtMsat, 'ln.amtMsat');
    _requirePositiveOptional(ln.expirySec, 'ln.expirySec');
    _requirePositiveOptional(ln.assetAmount, 'ln.assetAmount');
    _requirePositiveOptional(
      ln.minFinalCltvExpiryDelta,
      'ln.minFinalCltvExpiryDelta',
    );
    _requireUInt16Optional(
      ln.minFinalCltvExpiryDelta,
      'ln.minFinalCltvExpiryDelta',
    );
    _requireNonBlankOptional(ln.assetId, 'ln.assetId');
    _requireNonBlankOptional(ln.descriptionHash, 'ln.descriptionHash');
    _requireNonBlankOptional(ln.paymentHash, 'ln.paymentHash');
    _requireHex32Optional(ln.descriptionHash, 'ln.descriptionHash');
    _requireHex32Optional(ln.paymentHash, 'ln.paymentHash');

    if (ln.assetId != null && ln.assetId!.trim() != rgb.assetId) {
      throw const ValidationError(
        'ln.assetId must match the RGB invoice asset.',
        'ln.assetId',
      );
    }
    if (ln.assetAmount != null && ln.assetAmount != rgb.amount) {
      throw const ValidationError(
        'ln.assetAmount must match the RGB invoice amount.',
        'ln.assetAmount',
      );
    }
    final expiry = ln.expirySec;
    if (expiry != null &&
        (nowEpochSeconds + expiry - rgb.expiresAt).abs() >
            _bridgeExpiryToleranceSeconds) {
      throw const ValidationError(
        'ln.expirySec must match the RGB invoice remaining lifetime.',
        'ln.expirySec',
      );
    }
  }

  static void verifySendResponse({
    required SendAssetOptions requested,
    required LspOnchainSendResponse issued,
    required CoreInvoiceData decodedRgb,
    required DecodedLightningInvoice decodedLightning,
    required String walletNetwork,
    required String expectedLspPubkey,
    required int nowEpochSeconds,
  }) {
    if (issued.rgbInvoice.trim() != requested.rgbInvoice.trim()) {
      _fail('the response echoes a different RGB invoice');
    }
    final rgb = _verifyRgbInvoice(
      decodedRgb,
      walletNetwork: walletNetwork,
      nowEpochSeconds: nowEpochSeconds,
    );
    _verifyNetwork(decodedLightning.network, walletNetwork, 'Lightning');
    final lightningExpiry = _lightningExpiry(decodedLightning, nowEpochSeconds);
    if ((lightningExpiry - rgb.expiresAt).abs() >
        _bridgeExpiryToleranceSeconds) {
      _fail('the RGB and Lightning invoice expiries do not match');
    }
    if (_requiredValue(decodedLightning.assetId, 'Lightning asset') !=
        rgb.assetId) {
      _fail('the Lightning invoice asset differs from the RGB invoice');
    }
    if (decodedLightning.assetAmount != rgb.amount) {
      _fail('the Lightning invoice asset amount differs from the RGB invoice');
    }
    final amountMsat = decodedLightning.amtMsat;
    if (amountMsat == null || amountMsat <= 0) {
      _fail('the Lightning invoice has no positive fixed amount');
    }
    final payee = _requiredValue(
      decodedLightning.payeePubkey,
      'Lightning payee',
    );
    if (payee.toLowerCase() != expectedLspPubkey.trim().toLowerCase()) {
      _fail('the Lightning invoice is not payable to the configured LSP');
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(decodedLightning.paymentHash)) {
      _fail('the Lightning invoice payment hash is malformed');
    }

    final expected = requested.ln;
    if (expected == null) return;
    _requireEqualIfPresent('amount', expected.amtMsat, amountMsat);
    _requireEqualIfPresent('asset', expected.assetId?.trim(), rgb.assetId);
    _requireEqualIfPresent('asset amount', expected.assetAmount, rgb.amount);
    _requireEqualIfPresent(
      'expiry duration',
      expected.expirySec,
      decodedLightning.expirySec,
    );
    _requireEqualIfPresent(
      'description hash',
      expected.descriptionHash?.toLowerCase(),
      decodedLightning.descriptionHash?.toLowerCase(),
    );
    _requireEqualIfPresent(
      'payment hash',
      expected.paymentHash?.toLowerCase(),
      decodedLightning.paymentHash.toLowerCase(),
    );
  }

  static _VerifiedRgbBridgeInvoice _verifyRgbInvoice(
    CoreInvoiceData invoice, {
    required String walletNetwork,
    required int nowEpochSeconds,
  }) {
    _verifyNetwork(invoice.network, walletNetwork, 'RGB');
    final assetId = _requiredValue(invoice.assetId, 'RGB asset');
    if (invoice.assignment.type.trim().toLowerCase() != 'fungible') {
      _fail('the RGB invoice does not contain a fungible assignment');
    }
    final amount = invoice.assignment.amount;
    if (amount == null || amount <= 0) {
      _fail('the RGB invoice has no positive fungible amount');
    }
    final expiresAt = invoice.expirationTimestamp;
    if (expiresAt == null || expiresAt <= nowEpochSeconds) {
      _fail('the RGB invoice is missing an unexpired expiration timestamp');
    }
    return _VerifiedRgbBridgeInvoice(
      assetId: assetId,
      amount: amount,
      expiresAt: expiresAt,
    );
  }

  static int _lightningExpiry(
    DecodedLightningInvoice invoice,
    int nowEpochSeconds,
  ) {
    if (invoice.timestamp <= 0 || invoice.expirySec <= 0) {
      _fail('the Lightning invoice has an invalid timestamp or expiry');
    }
    if (invoice.timestamp > nowEpochSeconds + _bridgeClockSkewSeconds) {
      _fail('the Lightning invoice is unreasonably future-dated');
    }
    final expiresAt = invoice.timestamp + invoice.expirySec;
    if (expiresAt <= nowEpochSeconds) {
      _fail('the Lightning invoice is expired');
    }
    return expiresAt;
  }

  static void _verifyNetwork(
    String actual,
    String expected,
    String invoiceKind,
  ) {
    if (LspNetworkPolicy.canonical(actual) !=
        LspNetworkPolicy.canonical(expected)) {
      _fail('the $invoiceKind invoice is for another network');
    }
  }

  static String _requiredValue(String? value, String label) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      _fail('the $label is missing');
    }
    return normalized;
  }

  static void _requirePositiveOptional(int? value, String field) {
    if (value != null && value <= 0) {
      throw ValidationError('$field must be a positive integer.', field);
    }
  }

  static void _requireNonBlankOptional(String? value, String field) {
    if (value != null && value.trim().isEmpty) {
      throw ValidationError('$field must be non-empty when present.', field);
    }
  }

  static void _requireHex32Optional(String? value, String field) {
    if (value != null && !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim())) {
      throw ValidationError(
        '$field must be a 32-byte hexadecimal value.',
        field,
      );
    }
  }

  static void _requireUInt16Optional(int? value, String field) {
    if (value != null && (value < 1 || value > 0xffff)) {
      throw ValidationError('$field must be in the range 1..65535.', field);
    }
  }

  static void _requireEqualIfPresent(
    String label,
    Object? expected,
    Object? actual,
  ) {
    if (expected != null && expected != actual) {
      _fail('the Lightning invoice $label differs from the request');
    }
  }

  static Never _fail(String reason) {
    throw LspBridgeQuoteVerificationException(reason: reason);
  }
}
