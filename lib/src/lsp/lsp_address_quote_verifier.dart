import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:meta/meta.dart' show internal, visibleForTesting;
import 'package:pointycastle/api.dart' show PublicKeyParameter;
import 'package:pointycastle/ecc/api.dart' show ECPublicKey, ECSignature;
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

import '../models/utexo_core_models.dart';
import 'lsp_errors.dart';
import 'lsp_protocol_policy.dart';
import 'lsp_types.dart';

const _apayLeafTag = 'UTEXO_APAY_HASH_V1';
const _apayBatchTag = 'UTEXO_APAY_HASH_BATCH_V1';
const _apayAddressTag = 'UTEXO_APAY_LNADDR_V1';
const _lightningSignedMessagePrefix = 'Lightning Signed Message:';
const _allowedFutureSkewSeconds = 300;
const _zbase32Alphabet = 'ybndrfg8ejkmcpqxot1uwisza345h769';
final _secp256k1 = ECCurve_secp256k1();
final _secp256k1FieldPrime = BigInt.parse(
  'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
  radix: 16,
);

/// Verifies every signed or protocol-bound field in a Lightning Address quote.
///
/// This is package-internal despite Dart requiring a public declaration across
/// library boundaries. Applications should use `UtexoLsp.quoteAddress`, which
/// invokes the verifier before returning a quote.
@internal
abstract final class LspAddressQuoteVerifier {
  /// Exercises the exact LDK recoverable-signature verifier with external
  /// reference vectors. Not a supported package API.
  @visibleForTesting
  static bool verifyLightningSignatureForTesting({
    required List<int> message,
    required String signature,
    required String pubkey,
  }) {
    return _verifyLightningSignature(
      Uint8List.fromList(message),
      signature,
      _decodeCompressedPubkey(pubkey, 'test public key'),
    );
  }

  static void verify({
    required LspAddressResolution resolution,
    required DecodedLightningInvoice invoice,
    required String username,
    required String domain,
    required int expectedAmtMsat,
    required String? expectedAssetId,
    required int? expectedAssetAmount,
    required String walletNetwork,
    required int nowEpochSeconds,
    String? expectedLspPubkey,
    bool requireApayProof = false,
    String? expectedRecipientPubkey,
  }) {
    final discovery = resolution.discovery;
    final callback = resolution.callback;
    _verifyDiscovery(discovery);
    _verifyInvoice(
      discovery: discovery,
      invoice: invoice,
      expectedAmtMsat: expectedAmtMsat,
      expectedAssetId: expectedAssetId,
      expectedAssetAmount: expectedAssetAmount,
      walletNetwork: walletNetwork,
      nowEpochSeconds: nowEpochSeconds,
      expectedLspPubkey: expectedLspPubkey,
    );

    final proof = callback.proof;
    if (expectedRecipientPubkey != null) {
      _decodeCompressedPubkey(expectedRecipientPubkey, 'wallet public key');
      if (discovery.recipientPubkey?.toLowerCase() !=
              expectedRecipientPubkey.toLowerCase() ||
          proof?.recipientPubkey.toLowerCase() !=
              expectedRecipientPubkey.toLowerCase()) {
        _fail('the receive invoice recipient differs from the local wallet');
      }
    }
    if (proof == null) {
      if (requireApayProof) {
        _fail('the APay flow returned no signed inclusion proof');
      }
      return;
    }

    _verifyApayProof(
      proof: proof,
      discovery: discovery,
      invoice: invoice,
      username: username,
      domain: domain,
      nowEpochSeconds: nowEpochSeconds,
      expectedLspPubkey: expectedLspPubkey,
    );
  }

  static void _verifyDiscovery(LspLnurlpDiscovery discovery) {
    if (discovery.tag != 'payRequest') {
      _fail('LNURL discovery did not identify a payRequest');
    }
    final metadata = discovery.metadata;
    if (metadata == null || metadata.isEmpty) {
      _fail('LNURL discovery omitted the invoice-binding metadata');
    }
  }

  static void _verifyInvoice({
    required LspLnurlpDiscovery discovery,
    required DecodedLightningInvoice invoice,
    required int expectedAmtMsat,
    required String? expectedAssetId,
    required int? expectedAssetAmount,
    required String walletNetwork,
    required int nowEpochSeconds,
    required String? expectedLspPubkey,
  }) {
    if (invoice.amtMsat != expectedAmtMsat) {
      _fail('the BOLT11 amount differs from the requested LNURL amount');
    }
    if (invoice.assetId != expectedAssetId) {
      _fail('the BOLT11 asset differs from the requested LNURL asset');
    }
    if (invoice.assetAmount !=
        (expectedAssetAmount == null
            ? null
            : BigInt.from(expectedAssetAmount))) {
      _fail('the BOLT11 asset amount differs from the requested amount');
    }
    if (LspNetworkPolicy.canonical(invoice.network) !=
        LspNetworkPolicy.canonical(walletNetwork)) {
      _fail('the BOLT11 network differs from the wallet network');
    }
    if (invoice.timestamp <= 0 || invoice.expirySec <= 0) {
      _fail('the BOLT11 has an invalid creation time or expiry duration');
    }
    if (invoice.timestamp > nowEpochSeconds + _allowedFutureSkewSeconds) {
      _fail('the BOLT11 creation time is unreasonably far in the future');
    }
    if (invoice.timestamp + invoice.expirySec <= nowEpochSeconds) {
      _fail('the BOLT11 is expired');
    }

    final metadataHash = sha256
        .convert(utf8.encode(discovery.metadata!))
        .toString();
    if (invoice.descriptionHash?.toLowerCase() != metadataHash) {
      _fail('the BOLT11 description hash does not bind LNURL metadata');
    }
    _decodeHexFixed(invoice.paymentHash, 32, 'invoice payment hash');
    final payee = invoice.payeePubkey;
    if (payee == null) {
      _fail('the BOLT11 omitted its recovered payee public key');
    }
    _decodeCompressedPubkey(payee, 'invoice payee public key');
    if (expectedLspPubkey != null) {
      _decodeCompressedPubkey(
        expectedLspPubkey,
        'configured LSP peer public key',
      );
      if (payee.toLowerCase() != expectedLspPubkey.toLowerCase()) {
        _fail('the BOLT11 payee differs from the configured LSP peer');
      }
    }
  }

  static void _verifyApayProof({
    required ApayInvoiceProof proof,
    required LspLnurlpDiscovery discovery,
    required DecodedLightningInvoice invoice,
    required String username,
    required String domain,
    required int nowEpochSeconds,
    required String? expectedLspPubkey,
  }) {
    if (proof.version != 1) {
      _fail('the APay proof version is unsupported');
    }
    if (proof.batchSize < 1 ||
        proof.batchSize > ApayProtocolPolicy.maxBatchSize) {
      _fail('the APay batch size is outside the supported protocol range');
    }
    if (proof.hashIndex < ApayProtocolPolicy.firstHashIndex ||
        proof.hashIndex > ApayProtocolPolicy.maxHashIndex) {
      _fail('the APay hash index is outside the BIP32 derivation range');
    }
    if (proof.createdAt <= 0 || proof.expiresAt <= proof.createdAt) {
      _fail('the APay batch has invalid validity timestamps');
    }
    if (proof.createdAt > nowEpochSeconds + _allowedFutureSkewSeconds) {
      _fail('the APay batch creation time is unreasonably far in the future');
    }
    if (proof.expiresAt <= nowEpochSeconds) {
      _fail('the APay batch commitment is expired');
    }

    final recipient = _decodeCompressedPubkey(
      proof.recipientPubkey,
      'APay recipient public key',
    );
    final host = _decodeCompressedPubkey(
      proof.hostPubkey,
      'APay host public key',
    );
    final batchId = _decodeHexFixed(proof.batchId, 16, 'APay batch ID');
    final paymentHash = _decodeHexFixed(
      proof.paymentHash,
      32,
      'APay payment hash',
    );
    final batchRoot = _decodeHexFixed(proof.batchRoot, 32, 'APay batch root');

    if (proof.paymentHash.toLowerCase() != invoice.paymentHash.toLowerCase()) {
      _fail('the APay proof payment hash differs from the signed BOLT11');
    }
    if (proof.hostPubkey.toLowerCase() != invoice.payeePubkey!.toLowerCase()) {
      _fail('the APay host differs from the signed BOLT11 payee');
    }
    if (expectedLspPubkey != null &&
        proof.hostPubkey.toLowerCase() != expectedLspPubkey.toLowerCase()) {
      _fail('the APay host differs from the configured LSP peer');
    }

    final discoveredRecipient = discovery.recipientPubkey;
    final addressSignature = discovery.addressSig;
    if (discoveredRecipient == null || addressSignature == null) {
      _fail('the APay proof has no matching address ownership attestation');
    }
    _decodeCompressedPubkey(discoveredRecipient, 'LNURL recipient public key');
    if (discoveredRecipient.toLowerCase() !=
        proof.recipientPubkey.toLowerCase()) {
      _fail('the APay proof recipient differs from LNURL discovery');
    }

    final canonicalDomain = domain.toLowerCase();
    final exactDomainValid = _verifyAddressSignature(
      recipient: recipient,
      domain: domain,
      username: username,
      signature: addressSignature,
    );
    final canonicalDomainValid =
        canonicalDomain != domain &&
        _verifyAddressSignature(
          recipient: recipient,
          domain: canonicalDomain,
          username: username,
          signature: addressSignature,
        );
    if (!exactDomainValid && !canonicalDomainValid) {
      _fail('the Lightning Address ownership signature is invalid');
    }

    final expectedDepth = _merkleDepth(proof.batchSize);
    if (proof.merkleProof.length != expectedDepth) {
      _fail('the APay Merkle proof depth does not match its batch size');
    }
    var current = _sha256(<int>[
      0,
      ...utf8.encode(_apayLeafTag),
      ...recipient,
      ...batchId,
      ..._uint64Bytes(proof.hashIndex, 'APay hash index'),
      ...paymentHash,
    ]);
    for (final element in proof.merkleProof) {
      final sibling = _decodeHexFixed(
        element.sibling,
        32,
        'APay Merkle sibling',
      );
      current = element.side == 'left'
          ? _sha256(<int>[1, ...sibling, ...current])
          : _sha256(<int>[1, ...current, ...sibling]);
    }
    if (!_bytesEqual(current, batchRoot)) {
      _fail('the APay payment hash is not included in the signed batch root');
    }

    final batchCommitment = BytesBuilder(copy: false)
      ..add(utf8.encode(_apayBatchTag))
      ..add(recipient)
      ..add(host)
      ..add(batchId)
      ..add(batchRoot)
      ..add(_uint64Bytes(proof.batchSize, 'APay batch size'))
      ..add(_uint64Bytes(proof.createdAt, 'APay created time'))
      ..add(_uint64Bytes(proof.expiresAt, 'APay expiry time'));
    if (!_verifyLightningSignature(
      batchCommitment.takeBytes(),
      proof.batchSig,
      recipient,
    )) {
      _fail('the APay batch commitment signature is invalid');
    }
  }

  static bool _verifyLightningSignature(
    Uint8List message,
    String signature,
    Uint8List expectedPubkey,
  ) {
    try {
      final encoded = _decodeZbase32(signature);
      if (encoded.length != 65) return false;
      final recoveryId = encoded.first - 31;
      if (recoveryId < 0 || recoveryId > 3) return false;

      final r = _bytesToBigInt(encoded.sublist(1, 33));
      final s = _bytesToBigInt(encoded.sublist(33, 65));
      final n = _secp256k1.n;
      if (r <= BigInt.zero || r >= n || s <= BigInt.zero || s >= n) {
        return false;
      }

      final x = r + BigInt.from(recoveryId >> 1) * n;
      if (x >= _secp256k1FieldPrime) return false;
      final rPoint = _secp256k1.curve.decompressPoint(recoveryId & 1, x);
      if (!(rPoint * n)!.isInfinity) return false;

      final digest = _sha256d(<int>[
        ...utf8.encode(_lightningSignedMessagePrefix),
        ...message,
      ]);
      final z = _bytesToBigInt(digest);
      final negativeZ = (n - (z % n)) % n;
      final signedR = rPoint * s;
      final negativeZG = _secp256k1.G * negativeZ;
      if (signedR == null || negativeZG == null) return false;
      final sum = signedR + negativeZG;
      if (sum == null) return false;
      final recovered = sum * r.modInverse(n);
      if (recovered == null || recovered.isInfinity) return false;
      if (!_bytesEqual(recovered.getEncoded(true), expectedPubkey)) {
        return false;
      }

      final expectedPoint = _secp256k1.curve.decodePoint(expectedPubkey);
      if (expectedPoint == null || expectedPoint.isInfinity) return false;
      final verifier = ECDSASigner()
        ..init(
          false,
          PublicKeyParameter<ECPublicKey>(
            ECPublicKey(expectedPoint, _secp256k1),
          ),
        );
      return verifier.verifySignature(digest, ECSignature(r, s));
    } on Object {
      return false;
    }
  }

  static bool _verifyAddressSignature({
    required Uint8List recipient,
    required String domain,
    required String username,
    required String signature,
  }) {
    final commitment = BytesBuilder(copy: false)
      ..add(utf8.encode(_apayAddressTag))
      ..add(recipient)
      ..add(utf8.encode(domain))
      ..add(utf8.encode(username))
      ..add(_uint64Bytes(0, 'APay address expiry'));
    return _verifyLightningSignature(
      commitment.takeBytes(),
      signature,
      recipient,
    );
  }

  static Uint8List _decodeZbase32(String value) {
    if (value.length != 104) {
      throw const FormatException('invalid Lightning signature length');
    }
    var buffer = 0;
    var pendingBits = 0;
    final out = BytesBuilder(copy: false);
    for (final codeUnit in value.codeUnits) {
      final index = _zbase32Alphabet.indexOf(String.fromCharCode(codeUnit));
      if (index < 0) throw const FormatException('invalid zbase32 character');
      buffer = (buffer << 5) | index;
      pendingBits += 5;
      while (pendingBits >= 8) {
        pendingBits -= 8;
        out.addByte((buffer >> pendingBits) & 0xff);
      }
      buffer &= (1 << pendingBits) - 1;
    }
    if (pendingBits != 0 && buffer != 0) {
      throw const FormatException('non-canonical zbase32 padding');
    }
    return out.takeBytes();
  }

  static Uint8List _decodeCompressedPubkey(String value, String field) {
    final bytes = _decodeHexFixed(value, 33, field);
    if (bytes.first != 2 && bytes.first != 3) {
      _fail('$field is not a compressed secp256k1 public key');
    }
    final point = _secp256k1.curve.decodePoint(bytes);
    if (point == null || point.isInfinity) {
      _fail('$field is not a valid secp256k1 point');
    }
    return bytes;
  }

  static Uint8List _decodeHexFixed(String value, int length, String field) {
    final normalized = value.trim();
    if (normalized.length != length * 2 ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) {
      _fail('$field must be exactly $length bytes of hexadecimal');
    }
    final output = Uint8List(length);
    for (var index = 0; index < length; index += 1) {
      output[index] = int.parse(
        normalized.substring(index * 2, index * 2 + 2),
        radix: 16,
      );
    }
    return output;
  }

  static Uint8List _uint64Bytes(int value, String field) {
    final integer = BigInt.from(value);
    final max = (BigInt.one << 64) - BigInt.one;
    if (integer < BigInt.zero || integer > max) {
      _fail('$field is outside the unsigned 64-bit range');
    }
    final output = Uint8List(8);
    var current = integer;
    for (var index = output.length - 1; index >= 0; index -= 1) {
      output[index] = (current & BigInt.from(0xff)).toInt();
      current >>= 8;
    }
    return output;
  }

  static int _merkleDepth(int leaves) {
    var depth = 0;
    var width = leaves;
    while (width > 1) {
      width = (width + 1) ~/ 2;
      depth += 1;
    }
    return depth;
  }

  static Uint8List _sha256(List<int> bytes) =>
      Uint8List.fromList(sha256.convert(bytes).bytes);

  static Uint8List _sha256d(List<int> bytes) => _sha256(_sha256(bytes));

  static BigInt _bytesToBigInt(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index += 1) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static Never _fail(String reason) {
    throw LspAddressQuoteVerificationException(reason: reason);
  }
}
