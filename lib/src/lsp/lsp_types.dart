import '../models/rln_models.dart';

class LspClientConfig {
  const LspClientConfig({
    required this.baseUrl,
    this.bearerToken,
    this.timeoutMs,
  });

  final String baseUrl;
  final String? bearerToken;
  final int? timeoutMs;
}

class LspGetInfoResponse {
  const LspGetInfoResponse({
    required this.pubkey,
    this.alias,
    required this.numChannels,
    required this.numUsableChannels,
  });

  factory LspGetInfoResponse.fromWire(Map<String, Object?> map) {
    return LspGetInfoResponse(
      pubkey: map['pubkey']?.toString() ?? '',
      alias: map['alias']?.toString(),
      numChannels: _intValue(map['num_channels']),
      numUsableChannels: _intValue(map['num_usable_channels']),
    );
  }

  final String pubkey;
  final String? alias;
  final int numChannels;
  final int numUsableChannels;
}

class LspLnParams {
  const LspLnParams({
    this.amtMsat,
    this.expirySec,
    this.assetId,
    this.assetAmount,
    this.descriptionHash,
    this.paymentHash,
    this.minFinalCltvExpiryDelta,
  });

  final int? amtMsat;
  final int? expirySec;
  final String? assetId;
  final int? assetAmount;
  final String? descriptionHash;
  final String? paymentHash;
  final int? minFinalCltvExpiryDelta;

  Map<String, Object?> toWire() {
    return <String, Object?>{
      if (amtMsat != null) 'amt_msat': amtMsat,
      if (expirySec != null) 'expiry_sec': expirySec,
      if (assetId != null) 'asset_id': assetId,
      if (assetAmount != null) 'asset_amount': assetAmount,
      if (descriptionHash != null) 'description_hash': descriptionHash,
      if (paymentHash != null) 'payment_hash': paymentHash,
      if (minFinalCltvExpiryDelta != null)
        'min_final_cltv_expiry_delta': minFinalCltvExpiryDelta,
    };
  }
}

class LspOnchainSendRequest {
  const LspOnchainSendRequest({required this.rgbInvoice, this.ln});

  final String rgbInvoice;
  final LspLnParams? ln;
}

class LspOnchainSendResponse {
  const LspOnchainSendResponse({
    required this.rgbInvoice,
    required this.lnInvoice,
    required this.mappingId,
  });

  factory LspOnchainSendResponse.fromWire(Map<String, Object?> map) {
    return LspOnchainSendResponse(
      rgbInvoice: map['rgb_invoice']?.toString() ?? '',
      lnInvoice: map['ln_invoice']?.toString() ?? '',
      mappingId: map['mapping_id']?.toString() ?? '',
    );
  }

  final String rgbInvoice;
  final String lnInvoice;
  final String mappingId;
}

class LspRgbParams {
  const LspRgbParams({
    required this.assetId,
    this.assignment,
    this.durationSeconds,
    this.minConfirmations,
    this.witness,
  });

  final String assetId;
  final String? assignment;
  final int? durationSeconds;
  final int? minConfirmations;
  final String? witness;

  Map<String, Object?> toWire() {
    return <String, Object?>{
      'asset_id': assetId,
      'min_confirmations': minConfirmations ?? 1,
      'witness': witness != null && witness!.isNotEmpty,
      if (assignment != null) 'assignment': assignment,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
  }
}

class LspLightningReceiveRequest {
  const LspLightningReceiveRequest({
    required this.lnInvoice,
    required this.rgb,
  });

  final String lnInvoice;
  final LspRgbParams rgb;
}

class LspLightningReceiveResponse {
  const LspLightningReceiveResponse({
    required this.lnInvoice,
    required this.rgbInvoice,
    required this.mappingId,
  });

  factory LspLightningReceiveResponse.fromWire(Map<String, Object?> map) {
    return LspLightningReceiveResponse(
      lnInvoice: map['ln_invoice']?.toString() ?? '',
      rgbInvoice: map['rgb_invoice']?.toString() ?? '',
      mappingId: map['mapping_id']?.toString() ?? '',
    );
  }

  final String lnInvoice;
  final String rgbInvoice;
  final String mappingId;
}

class LspLnurlpCallbackResponse {
  const LspLnurlpCallbackResponse({
    required this.pr,
    required this.routes,
    this.status,
    this.reason,
    this.proof,
  });

  factory LspLnurlpCallbackResponse.fromWire(Map<String, Object?> map) {
    final proof = map['proof'];
    return LspLnurlpCallbackResponse(
      pr: map['pr']?.toString() ?? '',
      routes: map['routes'] is List
          ? map['routes']! as List<Object?>
          : const [],
      status: map['status']?.toString(),
      reason: map['reason']?.toString(),
      proof: proof is Map
          ? ApayInvoiceProof.fromWire(Map<String, Object?>.from(proof))
          : null,
    );
  }

  final String pr;
  final List<Object?> routes;
  final String? status;
  final String? reason;
  final ApayInvoiceProof? proof;
}

class LspApayInvoiceProofWire {
  const LspApayInvoiceProofWire(this.map);

  factory LspApayInvoiceProofWire.fromMap(Map<String, Object?> map) {
    return LspApayInvoiceProofWire(map);
  }

  final Map<String, Object?> map;

  ApayInvoiceProof toProof() {
    return ApayInvoiceProof.fromWire(map);
  }
}

class LspLnurlpCallbackWire {
  const LspLnurlpCallbackWire(this.map);

  factory LspLnurlpCallbackWire.fromMap(Map<String, Object?> map) {
    return LspLnurlpCallbackWire(map);
  }

  final Map<String, Object?> map;

  LspLnurlpCallbackResponse toResponse() {
    return LspLnurlpCallbackResponse.fromWire(map);
  }
}

class ApayMerkleProofElement {
  const ApayMerkleProofElement({required this.sibling, required this.side});

  factory ApayMerkleProofElement.fromWire(Map<String, Object?> map) {
    return ApayMerkleProofElement(
      sibling: map['sibling']?.toString() ?? '',
      side: map['side']?.toString() ?? '',
    );
  }

  final String sibling;
  final String side;
}

class ApayInvoiceProof {
  const ApayInvoiceProof({
    required this.version,
    required this.recipientPubkey,
    required this.hostPubkey,
    required this.batchId,
    required this.hashIndex,
    required this.paymentHash,
    required this.batchRoot,
    required this.batchSize,
    required this.merkleProof,
    required this.batchSig,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ApayInvoiceProof.fromWire(Map<String, Object?> map) {
    final merkleProof = map['merkle_proof'];
    return ApayInvoiceProof(
      version: _intValue(map['version']),
      recipientPubkey: map['recipient_pubkey']?.toString() ?? '',
      hostPubkey: map['host_pubkey']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      hashIndex: _intValue(map['hash_index']),
      paymentHash: map['payment_hash']?.toString() ?? '',
      batchRoot: map['batch_root']?.toString() ?? '',
      batchSize: _intValue(map['batch_size']),
      merkleProof: merkleProof is List
          ? merkleProof
                .whereType<Map>()
                .map(
                  (value) => ApayMerkleProofElement.fromWire(
                    Map<String, Object?>.from(value),
                  ),
                )
                .toList(growable: false)
          : const <ApayMerkleProofElement>[],
      batchSig: map['batch_sig']?.toString() ?? '',
      createdAt: _intValue(map['created_at']),
      expiresAt: _intValue(map['expires_at']),
    );
  }

  final int version;
  final String recipientPubkey;
  final String hostPubkey;
  final String batchId;
  final int hashIndex;
  final String paymentHash;
  final String batchRoot;
  final int batchSize;
  final List<ApayMerkleProofElement> merkleProof;
  final String batchSig;
  final int createdAt;
  final int expiresAt;
}

class LspLightningAddressByPubkeyResponse {
  const LspLightningAddressByPubkeyResponse({
    required this.username,
    required this.domain,
    this.recipientPubkey,
    this.addressSig,
  });

  factory LspLightningAddressByPubkeyResponse.fromWire(
    Map<String, Object?> map,
  ) {
    return LspLightningAddressByPubkeyResponse(
      username: map['username']?.toString() ?? '',
      domain: map['domain']?.toString() ?? '',
      recipientPubkey: map['recipient_pubkey']?.toString(),
      addressSig: map['address_sig']?.toString(),
    );
  }

  final String username;
  final String domain;
  final String? recipientPubkey;
  final String? addressSig;
}

class LspPeer {
  const LspPeer({
    required this.baseUrl,
    required this.peerPubkey,
    required this.peerHost,
    required this.peerPort,
    this.bearerToken,
    this.timeoutMs,
  });

  final String baseUrl;
  final String peerPubkey;
  final String peerHost;
  final int peerPort;
  final String? bearerToken;
  final int? timeoutMs;
}

String peerUri(LspPeer peer) {
  return '${peer.peerPubkey}@${peer.peerHost}:${peer.peerPort}';
}

typedef ReceiveStatus = String;
typedef ReceiveSettlementOutcome = String;

abstract final class ReceiveStatuses {
  static const pending = 'Pending';
  static const succeeded = 'Succeeded';
  static const failed = 'Failed';
  static const expired = 'Expired';
}

abstract final class ReceiveSettlementOutcomes {
  static const settled = 'settled';
  static const timedOut = 'timed_out';
}

ReceiveStatus normalizeReceiveStatus(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'SUCCEEDED':
    case 'SETTLED':
      return ReceiveStatuses.succeeded;
    case 'FAILED':
      return ReceiveStatuses.failed;
    case 'EXPIRED':
      return ReceiveStatuses.expired;
    default:
      return ReceiveStatuses.pending;
  }
}

class ChannelReadyInfo {
  const ChannelReadyInfo({
    required this.channelId,
    required this.peerPubkey,
    required this.capacitySat,
    required this.outboundBalanceMsat,
    required this.inboundBalanceMsat,
  });

  final String channelId;
  final String peerPubkey;
  final int capacitySat;
  final int outboundBalanceMsat;
  final int inboundBalanceMsat;
}

class CreateHodlInvoiceParams {
  const CreateHodlInvoiceParams({
    required this.paymentHash,
    this.amtMsat,
    required this.expirySec,
    this.assetId,
    this.assetAmount,
    this.minFinalCltvExpiryDelta,
    this.descriptionHash,
  });

  final String paymentHash;
  final int? amtMsat;
  final int expirySec;
  final String? assetId;
  final int? assetAmount;
  final int? minFinalCltvExpiryDelta;
  final String? descriptionHash;
}

class HodlInvoice {
  const HodlInvoice({
    required this.bolt11,
    required this.paymentHash,
    this.amtMsat,
    required this.expirySec,
    this.assetId,
    this.assetAmount,
    this.minFinalCltvExpiryDelta,
    this.descriptionHash,
  });

  final String bolt11;
  final String paymentHash;
  final int? amtMsat;
  final int expirySec;
  final String? assetId;
  final int? assetAmount;
  final int? minFinalCltvExpiryDelta;
  final String? descriptionHash;
}

class HodlInvoiceResult {
  const HodlInvoiceResult({required this.changed});

  final bool changed;
}

class ApayHashEntry {
  const ApayHashEntry({required this.hashIndex, required this.paymentHash});

  factory ApayHashEntry.fromMap(RlnMap map) {
    return ApayHashEntry(
      hashIndex: _intValue(map['hashIndex']),
      paymentHash: map['paymentHash']?.toString() ?? '',
    );
  }

  final int hashIndex;
  final String paymentHash;
}

class ApayNewResponse {
  const ApayNewResponse({
    required this.requestId,
    required this.hostNodeId,
    required this.protocolVersion,
    required this.orderId,
    required this.status,
    required this.acceptedThroughIndex,
    required this.nextIndexExpected,
    required this.unusedHashes,
    required this.refillBatchSize,
    required this.firstHashIndex,
    required this.lastHashIndex,
    required this.hashes,
  });

  factory ApayNewResponse.fromMap(RlnMap map) {
    final hashes = map['hashes'];
    return ApayNewResponse(
      requestId: map['requestId']?.toString() ?? '',
      hostNodeId: map['hostNodeId']?.toString() ?? '',
      protocolVersion: _intValue(map['protocolVersion']),
      orderId: map['orderId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      acceptedThroughIndex: _intValue(map['acceptedThroughIndex']),
      nextIndexExpected: _intValue(map['nextIndexExpected']),
      unusedHashes: _intValue(map['unusedHashes']),
      refillBatchSize: _intValue(map['refillBatchSize']),
      firstHashIndex: _intValue(map['firstHashIndex']),
      lastHashIndex: _intValue(map['lastHashIndex']),
      hashes: hashes is List
          ? hashes
                .whereType<Map>()
                .map(
                  (value) =>
                      ApayHashEntry.fromMap(Map<Object?, Object?>.from(value)),
                )
                .toList(growable: false)
          : const <ApayHashEntry>[],
    );
  }

  final String requestId;
  final String hostNodeId;
  final int protocolVersion;
  final String orderId;
  final String status;
  final int acceptedThroughIndex;
  final int nextIndexExpected;
  final int unusedHashes;
  final int refillBatchSize;
  final int firstHashIndex;
  final int lastHashIndex;
  final List<ApayHashEntry> hashes;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
