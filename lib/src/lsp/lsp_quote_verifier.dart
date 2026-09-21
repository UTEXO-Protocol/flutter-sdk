part of 'lsp_relay_types.dart';

/// Verifies that an LSP relay quote is cryptographically and economically tied
/// to the target invoice before the wallet is allowed to pay it.
/// Internal verifier used by [UtexoLsp] to create proof-carrying quotes.
///
/// This declaration is public only because Dart privacy is library-scoped and
/// the orchestration implementation lives in a separate library. It is hidden
/// from the package's root export and is not part of the supported API.
abstract final class LspRelayQuoteVerifier {
  /// Throws [LspQuoteMismatchException] on any unbound or altered quote field.
  static ExternalPaymentQuote verify({
    required DecodedLightningInvoice target,
    required DecodedLightningInvoice hodl,
    required LspLightningSendResponse quoted,
    required int maxFeeMsat,
    required String walletNetwork,
    required String expectedLspPubkey,
    required String? expectedFundingAssetId,
    required int nowEpochSeconds,
  }) {
    if (maxFeeMsat < 0) {
      throw const ValidationError(
        'maxFeeMsat must be a non-negative integer.',
        'maxFeeMsat',
      );
    }
    final targetHash = target.paymentHash.trim();
    final hodlHash = hodl.paymentHash.trim();
    final quotedHash = quoted.paymentHash.trim();
    if (targetHash.isEmpty || hodlHash.isEmpty || quotedHash.isEmpty) {
      throw const LspQuoteMismatchException(
        reason: 'one or more payment hashes are empty',
      );
    }
    if (hodlHash.toLowerCase() != targetHash.toLowerCase()) {
      throw LspQuoteMismatchException(
        reason:
            'the HODL invoice hash does not match the target invoice hash; '
            'the payment legs are not atomic',
      );
    }
    if (quotedHash.toLowerCase() != hodlHash.toLowerCase()) {
      throw const LspQuoteMismatchException(
        reason:
            'the reported payment hash differs from the signed HODL invoice',
      );
    }
    _requireHex32(targetHash, 'target invoice payment hash');
    _requireHex32(hodlHash, 'HODL invoice payment hash');

    final walletNetworkName = LspNetworkPolicy.canonical(walletNetwork);
    if (LspNetworkPolicy.canonical(target.network) != walletNetworkName ||
        LspNetworkPolicy.canonical(hodl.network) != walletNetworkName) {
      throw const LspQuoteMismatchException(
        reason: 'one or both signed invoices are for another network',
      );
    }
    final targetExpiry = _invoiceExpiry(target, nowEpochSeconds, 'target');
    final hodlExpiry = _invoiceExpiry(hodl, nowEpochSeconds, 'HODL');
    if (hodlExpiry > targetExpiry) {
      throw const LspQuoteMismatchException(
        reason: 'the HODL invoice outlives the invoice it is meant to fund',
      );
    }
    if (quoted.expiresAt <= nowEpochSeconds ||
        quoted.expiresAt > targetExpiry ||
        (quoted.expiresAt - hodlExpiry).abs() > 5) {
      throw const LspQuoteMismatchException(
        reason: 'the reported quote expiry differs from the signed invoices',
      );
    }

    _requireSame(
      label: 'caller-selected funding asset',
      expected: expectedFundingAssetId,
      actual: hodl.assetId,
    );
    _requireSame(
      label: 'asset amount',
      expected: target.assetAmount,
      actual: hodl.assetAmount,
    );
    _requireSame(
      label: 'inbound asset',
      expected: hodl.assetId,
      actual: quoted.inbound.assetId,
    );
    _requireSame(
      label: 'outbound asset',
      expected: target.assetId,
      actual: quoted.outbound.assetId,
    );
    _requireSame(
      label: 'inbound asset amount',
      expected: hodl.assetAmount,
      actual: quoted.inbound.assetAmount == null
          ? null
          : BigInt.from(quoted.inbound.assetAmount!),
    );
    _requireSame(
      label: 'outbound asset amount',
      expected: target.assetAmount,
      actual: quoted.outbound.assetAmount == null
          ? null
          : BigInt.from(quoted.outbound.assetAmount!),
    );
    final targetPayee = target.payeePubkey?.trim();
    final outboundPayee = quoted.outbound.payeePubkey?.trim();
    final hodlPayee = hodl.payeePubkey?.trim();
    if (targetPayee == null ||
        targetPayee.isEmpty ||
        outboundPayee == null ||
        outboundPayee.isEmpty ||
        targetPayee.toLowerCase() != outboundPayee.toLowerCase()) {
      throw const LspQuoteMismatchException(
        reason: 'the quoted outbound payee differs from the target invoice',
      );
    }
    if (hodlPayee == null ||
        hodlPayee.isEmpty ||
        hodlPayee.toLowerCase() != expectedLspPubkey.trim().toLowerCase()) {
      throw const LspQuoteMismatchException(
        reason: 'the HODL invoice is not payable to the configured LSP peer',
      );
    }
    final inboundPayee = quoted.inbound.payeePubkey?.trim();
    if (inboundPayee != null &&
        inboundPayee.isNotEmpty &&
        hodlPayee.toLowerCase() != inboundPayee.toLowerCase()) {
      throw const LspQuoteMismatchException(
        reason: 'the quoted inbound payee differs from the HODL invoice',
      );
    }
    if (targetPayee.toLowerCase() == hodlPayee.toLowerCase()) {
      throw const LspQuoteMismatchException(
        reason: 'the relay target cannot be the configured LSP itself',
      );
    }

    final targetMsat = target.amtMsat;
    final hodlMsat = hodl.amtMsat;
    if (targetMsat == null || targetMsat <= 0) {
      throw const LspQuoteMismatchException(
        reason: 'the target invoice does not contain a positive fixed amount',
      );
    }
    if (hodlMsat == null || hodlMsat <= 0) {
      throw const LspQuoteMismatchException(
        reason: 'the HODL invoice does not contain a positive fixed amount',
      );
    }
    if (quoted.outbound.amtMsat != targetMsat) {
      throw const LspQuoteMismatchException(
        reason: 'the quoted outbound amount differs from the target invoice',
      );
    }
    if (quoted.inbound.amtMsat != hodlMsat) {
      throw const LspQuoteMismatchException(
        reason: 'the quoted inbound amount differs from the HODL invoice',
      );
    }
    if (quoted.feeMsat > maxFeeMsat) {
      throw LspQuoteMismatchException(
        reason:
            'the relay fee ${quoted.feeMsat} msat exceeds the allowed '
            '$maxFeeMsat msat',
      );
    }
    if (hodlMsat > targetMsat + maxFeeMsat) {
      throw const LspQuoteMismatchException(
        reason: 'the HODL invoice amount exceeds the target plus allowed fee',
      );
    }
    if (quoted.inbound.amtMsat != quoted.outbound.amtMsat + quoted.feeMsat) {
      throw const LspQuoteMismatchException(
        reason:
            'the quoted fee does not reconcile the inbound and outbound legs',
      );
    }

    final assetsDiffer = quoted.inbound.assetId != quoted.outbound.assetId;
    if (quoted.converted != assetsDiffer) {
      throw const LspQuoteMismatchException(
        reason: 'the conversion flag disagrees with the two quoted asset legs',
      );
    }
    return ExternalPaymentQuote._verified(
      invoice: quoted.lnInvoice,
      paymentHash: hodl.paymentHash,
      inbound: quoted.inbound,
      outbound: quoted.outbound,
      converted: quoted.converted,
      feeMsat: quoted.feeMsat,
      expiresAt: quoted.expiresAt,
    );
  }

  static void _requireSame({
    required String label,
    required Object? expected,
    required Object? actual,
  }) {
    if (expected != actual) {
      throw LspQuoteMismatchException(
        reason: 'the quoted $label does not match the signed invoices',
      );
    }
  }

  static int _invoiceExpiry(
    DecodedLightningInvoice invoice,
    int nowEpochSeconds,
    String label,
  ) {
    if (invoice.timestamp <= 0 || invoice.expirySec <= 0) {
      throw LspQuoteMismatchException(
        reason: 'the $label invoice has an invalid timestamp or expiry',
      );
    }
    if (invoice.timestamp > nowEpochSeconds + 300) {
      throw LspQuoteMismatchException(
        reason: 'the $label invoice is unreasonably future-dated',
      );
    }
    final expiry = invoice.timestamp + invoice.expirySec;
    if (expiry <= nowEpochSeconds) {
      throw LspQuoteMismatchException(reason: 'the $label invoice is expired');
    }
    return expiry;
  }

  static void _requireHex32(String value, String label) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
      throw LspQuoteMismatchException(
        reason: 'the $label is not a 32-byte hexadecimal value',
      );
    }
  }
}
