/// Raw platform map returned by the low-level RLN bridge.
typedef RlnMap = Map<Object?, Object?>;

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int _intValue(Object? value, [int fallback = 0]) =>
    _intOrNull(value) ?? fallback;

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

String? _stringOrNull(Object? value) => value?.toString();

String _canonicalEnum(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) return '';
  if (RegExp(r'^[A-Z0-9_]+$').hasMatch(raw)) return raw;
  return raw
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toUpperCase();
}

String _uppercaseStatus(Object? value) {
  return (_stringOrNull(value) ?? '').toUpperCase();
}

RlnMap _map(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  return const <Object?, Object?>{};
}

List<RlnMap> _mapList(Object? value) {
  if (value is! List) return const <RlnMap>[];
  return value.map(_map).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map(_stringOrNull).whereType<String>().toList(growable: false);
}

/// Vanilla and colored xpubs for the wallet accounts.
class RlnXpubs {
  const RlnXpubs({this.vanilla, this.colored});

  final String? vanilla;
  final String? colored;
}

/// Node metadata returned by RLN.
class RlnNodeInfo {
  const RlnNodeInfo({
    required this.pubkey,
    required this.numChannels,
    required this.numUsableChannels,
    required this.localBalanceSat,
    required this.eventualCloseFeesSat,
    required this.pendingOutboundPaymentsSat,
    required this.numPeers,
    this.accountXpubVanilla,
    this.accountXpubColored,
    required this.maxMediaUploadSizeMb,
    required this.rgbHtlcMinMsat,
    required this.rgbChannelCapacityMinSat,
    required this.channelCapacityMinSat,
    required this.channelCapacityMaxSat,
    required this.channelAssetMinAmount,
    required this.channelAssetMaxAmount,
    required this.networkNodes,
    required this.networkChannels,
    this.latestRgsSnapshotTimestamp,
  });

  factory RlnNodeInfo.fromMap(RlnMap map) {
    return RlnNodeInfo(
      pubkey: _stringOrNull(map['pubkey']) ?? '',
      numChannels: _intValue(map['numChannels']),
      numUsableChannels: _intValue(map['numUsableChannels']),
      localBalanceSat: _intValue(map['localBalanceSat']),
      eventualCloseFeesSat: _intValue(map['eventualCloseFeesSat']),
      pendingOutboundPaymentsSat: _intValue(map['pendingOutboundPaymentsSat']),
      numPeers: _intValue(map['numPeers']),
      accountXpubVanilla: _stringOrNull(map['accountXpubVanilla']),
      accountXpubColored: _stringOrNull(map['accountXpubColored']),
      maxMediaUploadSizeMb: _intValue(map['maxMediaUploadSizeMb']),
      rgbHtlcMinMsat: _intValue(map['rgbHtlcMinMsat']),
      rgbChannelCapacityMinSat: _intValue(map['rgbChannelCapacityMinSat']),
      channelCapacityMinSat: _intValue(map['channelCapacityMinSat']),
      channelCapacityMaxSat: _intValue(map['channelCapacityMaxSat']),
      channelAssetMinAmount: _intValue(map['channelAssetMinAmount']),
      channelAssetMaxAmount: _intValue(map['channelAssetMaxAmount']),
      networkNodes: _intValue(map['networkNodes']),
      networkChannels: _intValue(map['networkChannels']),
      latestRgsSnapshotTimestamp: _intOrNull(map['latestRgsSnapshotTimestamp']),
    );
  }

  final String pubkey;
  final int numChannels;
  final int numUsableChannels;
  final int localBalanceSat;
  final int eventualCloseFeesSat;
  final int pendingOutboundPaymentsSat;
  final int numPeers;
  final String? accountXpubVanilla;
  final String? accountXpubColored;
  final int maxMediaUploadSizeMb;
  final int rgbHtlcMinMsat;
  final int rgbChannelCapacityMinSat;
  final int channelCapacityMinSat;
  final int channelCapacityMaxSat;
  final int channelAssetMinAmount;
  final int channelAssetMaxAmount;
  final int networkNodes;
  final int networkChannels;
  final int? latestRgsSnapshotTimestamp;
}

/// Current chain/network state seen by the node.
class RlnNetworkInfo {
  const RlnNetworkInfo({required this.network, required this.height});

  factory RlnNetworkInfo.fromMap(RlnMap map) {
    return RlnNetworkInfo(
      network: _stringOrNull(map['network']) ?? '',
      height: _intValue(map['height']),
    );
  }

  final String network;
  final int height;
}

/// Common settled/future/spendable balance tuple.
class RlnBalance {
  const RlnBalance({
    required this.settled,
    required this.future,
    required this.spendable,
  });

  factory RlnBalance.fromMap(RlnMap map) {
    return RlnBalance(
      settled: _intValue(map['settled']),
      future: _intValue(map['future']),
      spendable: _intValue(map['spendable']),
    );
  }

  final int settled;
  final int future;
  final int spendable;
}

/// Bitcoin balance split by vanilla and colored wallet domains.
class RlnBtcBalance {
  const RlnBtcBalance({required this.vanilla, required this.colored});

  factory RlnBtcBalance.fromMap(RlnMap map) {
    return RlnBtcBalance(
      vanilla: RlnBalance.fromMap(_map(map['vanilla'])),
      colored: RlnBalance.fromMap(_map(map['colored'])),
    );
  }

  final RlnBalance vanilla;
  final RlnBalance colored;
}

/// RGB asset balance, including off-chain channel amounts.
class RlnAssetBalance extends RlnBalance {
  const RlnAssetBalance({
    required super.settled,
    required super.future,
    required super.spendable,
    required this.offchainOutbound,
    required this.offchainInbound,
  });

  factory RlnAssetBalance.fromMap(RlnMap map) {
    return RlnAssetBalance(
      settled: _intValue(map['settled']),
      future: _intValue(map['future']),
      spendable: _intValue(map['spendable']),
      offchainOutbound: _intValue(map['offchainOutbound']),
      offchainInbound: _intValue(map['offchainInbound']),
    );
  }

  final int offchainOutbound;
  final int offchainInbound;
}

/// Media metadata attached to RGB assets or tokens.
class RlnMedia {
  const RlnMedia({this.filePath, this.digest, this.mime});

  factory RlnMedia.fromMap(RlnMap map) {
    return RlnMedia(
      filePath: _stringOrNull(map['filePath']),
      digest: _stringOrNull(map['digest']),
      mime: _stringOrNull(map['mime']),
    );
  }

  final String? filePath;
  final String? digest;
  final String? mime;
}

class RlnTokenLight {
  const RlnTokenLight({
    required this.index,
    this.ticker,
    this.name,
    this.details,
    required this.embeddedMedia,
    this.media,
    required this.attachments,
    required this.reserves,
  });

  factory RlnTokenLight.fromMap(RlnMap map) {
    return RlnTokenLight(
      index: _intValue(map['index']),
      ticker: _stringOrNull(map['ticker']),
      name: _stringOrNull(map['name']),
      details: _stringOrNull(map['details']),
      embeddedMedia: _boolValue(map['embeddedMedia']),
      media: map['media'] == null ? null : RlnMedia.fromMap(_map(map['media'])),
      attachments: _mapList(
        map['attachments'],
      ).map(RlnMediaAttachment.fromMap).toList(growable: false),
      reserves: _boolValue(map['reserves']),
    );
  }

  final int index;
  final String? ticker;
  final String? name;
  final String? details;
  final bool embeddedMedia;
  final RlnMedia? media;
  final List<RlnMediaAttachment> attachments;
  final bool reserves;
}

class RlnMediaAttachment {
  const RlnMediaAttachment({required this.key, this.media});

  factory RlnMediaAttachment.fromMap(RlnMap map) {
    return RlnMediaAttachment(
      key: _intValue(map['key']),
      media: map['media'] == null ? null : RlnMedia.fromMap(_map(map['media'])),
    );
  }

  final int key;
  final RlnMedia? media;
}

/// Base type for typed RGB assets.
sealed class RlnAsset {
  const RlnAsset({
    required this.assetId,
    required this.name,
    this.details,
    required this.precision,
    required this.timestamp,
    required this.addedAt,
    required this.balance,
  });

  final String assetId;
  final String name;
  final String? details;
  final int precision;
  final int timestamp;
  final int addedAt;
  final RlnAssetBalance balance;
}

/// Fungible NIA RGB asset.
class RlnAssetNia extends RlnAsset {
  const RlnAssetNia({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required this.issuedSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
  });

  factory RlnAssetNia.fromMap(RlnMap map) {
    return RlnAssetNia(
      assetId: _stringOrNull(map['assetId']) ?? '',
      ticker: _stringOrNull(map['ticker']) ?? '',
      name: _stringOrNull(map['name']) ?? '',
      details: _stringOrNull(map['details']),
      precision: _intValue(map['precision']),
      issuedSupply: _intValue(map['issuedSupply']),
      timestamp: _intValue(map['timestamp']),
      addedAt: _intValue(map['addedAt']),
      balance: RlnAssetBalance.fromMap(_map(map['balance'])),
      media: map['media'] == null ? null : RlnMedia.fromMap(_map(map['media'])),
    );
  }

  final String ticker;
  final int issuedSupply;
  final RlnMedia? media;
}

/// Collectible CFA RGB asset.
class RlnAssetCfa extends RlnAsset {
  const RlnAssetCfa({
    required super.assetId,
    required super.name,
    super.details,
    required super.precision,
    required this.issuedSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
  });

  factory RlnAssetCfa.fromMap(RlnMap map) {
    return RlnAssetCfa(
      assetId: _stringOrNull(map['assetId']) ?? '',
      name: _stringOrNull(map['name']) ?? '',
      details: _stringOrNull(map['details']),
      precision: _intValue(map['precision']),
      issuedSupply: _intValue(map['issuedSupply']),
      timestamp: _intValue(map['timestamp']),
      addedAt: _intValue(map['addedAt']),
      balance: RlnAssetBalance.fromMap(_map(map['balance'])),
      media: map['media'] == null ? null : RlnMedia.fromMap(_map(map['media'])),
    );
  }

  final int issuedSupply;
  final RlnMedia? media;
}

/// Inflation-capable IFA RGB asset.
class RlnAssetIfa extends RlnAsset {
  const RlnAssetIfa({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required this.initialSupply,
    required this.maxSupply,
    required this.knownCirculatingSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
    this.rejectListUrl,
  });

  factory RlnAssetIfa.fromMap(RlnMap map) {
    return RlnAssetIfa(
      assetId: _stringOrNull(map['assetId']) ?? '',
      ticker: _stringOrNull(map['ticker']) ?? '',
      name: _stringOrNull(map['name']) ?? '',
      details: _stringOrNull(map['details']),
      precision: _intValue(map['precision']),
      initialSupply: _intValue(map['initialSupply']),
      maxSupply: _intValue(map['maxSupply']),
      knownCirculatingSupply: _intValue(map['knownCirculatingSupply']),
      timestamp: _intValue(map['timestamp']),
      addedAt: _intValue(map['addedAt']),
      balance: RlnAssetBalance.fromMap(_map(map['balance'])),
      media: map['media'] == null ? null : RlnMedia.fromMap(_map(map['media'])),
      rejectListUrl: _stringOrNull(map['rejectListUrl']),
    );
  }

  final String ticker;
  final int initialSupply;
  final int maxSupply;
  final int knownCirculatingSupply;
  final RlnMedia? media;
  final String? rejectListUrl;
}

/// Unique digital asset.
class RlnAssetUda extends RlnAsset {
  const RlnAssetUda({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.token,
  });

  factory RlnAssetUda.fromMap(RlnMap map) {
    return RlnAssetUda(
      assetId: _stringOrNull(map['assetId']) ?? '',
      ticker: _stringOrNull(map['ticker']) ?? '',
      name: _stringOrNull(map['name']) ?? '',
      details: _stringOrNull(map['details']),
      precision: _intValue(map['precision']),
      timestamp: _intValue(map['timestamp']),
      addedAt: _intValue(map['addedAt']),
      balance: RlnAssetBalance.fromMap(_map(map['balance'])),
      token: map['token'] == null
          ? null
          : RlnTokenLight.fromMap(_map(map['token'])),
    );
  }

  final String ticker;
  final RlnTokenLight? token;
}

/// Asset groups returned by `listAssets`.
class RlnAssets {
  const RlnAssets({
    required this.nia,
    required this.uda,
    required this.cfa,
    required this.ifa,
  });

  factory RlnAssets.fromMap(RlnMap map) {
    return RlnAssets(
      nia: _mapList(
        map['nia'],
      ).map(RlnAssetNia.fromMap).toList(growable: false),
      uda: _mapList(
        map['uda'],
      ).map(RlnAssetUda.fromMap).toList(growable: false),
      cfa: _mapList(
        map['cfa'],
      ).map(RlnAssetCfa.fromMap).toList(growable: false),
      ifa: _mapList(
        map['ifa'],
      ).map(RlnAssetIfa.fromMap).toList(growable: false),
    );
  }

  final List<RlnAssetNia> nia;
  final List<RlnAssetUda> uda;
  final List<RlnAssetCfa> cfa;
  final List<RlnAssetIfa> ifa;

  Iterable<String> get assetIds sync* {
    yield* nia.map((asset) => asset.assetId);
    yield* uda.map((asset) => asset.assetId);
    yield* cfa.map((asset) => asset.assetId);
    yield* ifa.map((asset) => asset.assetId);
  }
}

/// RGB invoice created by the wallet.
class RlnInvoice {
  const RlnInvoice({
    required this.invoice,
    required this.recipientId,
    this.expirationTimestamp,
    required this.batchTransferIdx,
  });

  factory RlnInvoice.fromMap(RlnMap map) {
    return RlnInvoice(
      invoice: _stringOrNull(map['invoice']) ?? '',
      recipientId: _stringOrNull(map['recipientId']) ?? '',
      expirationTimestamp: _intOrNull(map['expirationTimestamp']),
      batchTransferIdx: _intValue(map['batchTransferIdx']),
    );
  }

  final String invoice;
  final String recipientId;
  final int? expirationTimestamp;
  final int batchTransferIdx;
}

/// Decoded RGB invoice data.
class RlnDecodedRgbInvoice {
  const RlnDecodedRgbInvoice({
    required this.recipientId,
    required this.recipientType,
    this.assetSchema,
    this.assetId,
    required this.assignment,
    required this.network,
    this.expirationTimestamp,
    required this.transportEndpoints,
  });

  factory RlnDecodedRgbInvoice.fromMap(RlnMap map) {
    return RlnDecodedRgbInvoice(
      recipientId: _stringOrNull(map['recipientId']) ?? '',
      recipientType: _stringOrNull(map['recipientType']) ?? '',
      assetSchema: _stringOrNull(map['assetSchema']),
      assetId: _stringOrNull(map['assetId']),
      assignment: _stringOrNull(map['assignment']) ?? '',
      network: _stringOrNull(map['network']) ?? '',
      expirationTimestamp: _intOrNull(map['expirationTimestamp']),
      transportEndpoints: _stringList(map['transportEndpoints']),
    );
  }

  int? get assignmentAmount {
    final match = RegExp(r'\d+').firstMatch(assignment);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  final String recipientId;
  final String recipientType;
  final String? assetSchema;
  final String? assetId;
  final String assignment;
  final String network;
  final int? expirationTimestamp;
  final List<String> transportEndpoints;
}

/// Result of an RGB send.
class RlnSendResult {
  const RlnSendResult({required this.txid, required this.batchTransferIdx});

  factory RlnSendResult.fromMap(RlnMap map) {
    return RlnSendResult(
      txid: _stringOrNull(map['txid']) ?? '',
      batchTransferIdx: _intValue(map['batchTransferIdx']),
    );
  }

  final String txid;
  final int batchTransferIdx;
}

class RlnBlockTime {
  const RlnBlockTime({required this.height, required this.timestamp});

  factory RlnBlockTime.fromMap(RlnMap map) {
    return RlnBlockTime(
      height: _intValue(map['height']),
      timestamp: _intValue(map['timestamp']),
    );
  }

  final int height;
  final int timestamp;
}

/// On-chain Bitcoin transaction.
class RlnTransaction {
  const RlnTransaction({
    required this.transactionType,
    required this.txid,
    required this.received,
    required this.sent,
    required this.fee,
    this.confirmationTime,
  });

  factory RlnTransaction.fromMap(RlnMap map) {
    return RlnTransaction(
      transactionType: _canonicalEnum(map['transactionType']),
      txid: _stringOrNull(map['txid']) ?? '',
      received: _intValue(map['received']),
      sent: _intValue(map['sent']),
      fee: _intValue(map['fee']),
      confirmationTime: map['confirmationTime'] == null
          ? null
          : RlnBlockTime.fromMap(_map(map['confirmationTime'])),
    );
  }

  final String transactionType;
  final String txid;
  final int received;
  final int sent;
  final int fee;
  final RlnBlockTime? confirmationTime;
}

class RlnTransferTransportEndpoint {
  const RlnTransferTransportEndpoint({
    required this.endpoint,
    required this.transportType,
    required this.used,
  });

  factory RlnTransferTransportEndpoint.fromMap(RlnMap map) {
    return RlnTransferTransportEndpoint(
      endpoint: _stringOrNull(map['endpoint']) ?? '',
      transportType: _stringOrNull(map['transportType']) ?? '',
      used: _boolValue(map['used']),
    );
  }

  final String endpoint;
  final String transportType;
  final bool used;
}

/// RGB transfer state.
class RlnTransfer {
  const RlnTransfer({
    required this.idx,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.requestedAssignment,
    required this.assignments,
    required this.kind,
    this.txid,
    this.recipientId,
    this.receiveUtxo,
    this.changeUtxo,
    this.expiration,
    required this.transportEndpoints,
  });

  factory RlnTransfer.fromMap(RlnMap map) {
    return RlnTransfer(
      idx: _intValue(map['idx']),
      createdAt: _intValue(map['createdAt']),
      updatedAt: _intValue(map['updatedAt']),
      status: _stringOrNull(map['status']) ?? '',
      requestedAssignment: _stringOrNull(map['requestedAssignment']),
      assignments: _stringList(map['assignments']),
      kind: _stringOrNull(map['kind']) ?? '',
      txid: _stringOrNull(map['txid']),
      recipientId: _stringOrNull(map['recipientId']),
      receiveUtxo: _stringOrNull(map['receiveUtxo']),
      changeUtxo: _stringOrNull(map['changeUtxo']),
      expiration: _intOrNull(map['expiration']),
      transportEndpoints: _mapList(
        map['transportEndpoints'],
      ).map(RlnTransferTransportEndpoint.fromMap).toList(growable: false),
    );
  }

  final int idx;
  final int createdAt;
  final int updatedAt;
  final String status;
  final String? requestedAssignment;
  final List<String> assignments;
  final String kind;
  final String? txid;
  final String? recipientId;
  final String? receiveUtxo;
  final String? changeUtxo;
  final int? expiration;
  final List<RlnTransferTransportEndpoint> transportEndpoints;
}

class RlnRgbAllocation {
  const RlnRgbAllocation({
    this.assetId,
    required this.assignment,
    required this.settled,
  });

  factory RlnRgbAllocation.fromMap(RlnMap map) {
    return RlnRgbAllocation(
      assetId: _stringOrNull(map['assetId']),
      assignment: _stringOrNull(map['assignment']) ?? '',
      settled: _boolValue(map['settled']),
    );
  }

  final String? assetId;
  final String assignment;
  final bool settled;
}

class RlnUtxo {
  const RlnUtxo({
    required this.outpoint,
    required this.btcAmount,
    required this.colorable,
  });

  factory RlnUtxo.fromMap(RlnMap map) {
    return RlnUtxo(
      outpoint: _stringOrNull(map['outpoint']) ?? '',
      btcAmount: _intValue(map['btcAmount']),
      colorable: _boolValue(map['colorable']),
    );
  }

  final String outpoint;
  final int btcAmount;
  final bool colorable;
}

/// Wallet UTXO and RGB allocations.
class RlnUnspent {
  const RlnUnspent({required this.utxo, required this.rgbAllocations});

  factory RlnUnspent.fromMap(RlnMap map) {
    return RlnUnspent(
      utxo: RlnUtxo.fromMap(_map(map['utxo'])),
      rgbAllocations: _mapList(
        map['rgbAllocations'],
      ).map(RlnRgbAllocation.fromMap).toList(growable: false),
    );
  }

  final RlnUtxo utxo;
  final List<RlnRgbAllocation> rgbAllocations;
}

/// Decoded BOLT11 invoice.
class RlnDecodedLnInvoice {
  const RlnDecodedLnInvoice({
    this.amtMsat,
    required this.expirySec,
    required this.timestamp,
    this.assetId,
    this.assetAmount,
    required this.paymentHash,
    required this.paymentSecret,
    this.payeePubkey,
    required this.network,
  });

  factory RlnDecodedLnInvoice.fromMap(RlnMap map) {
    return RlnDecodedLnInvoice(
      amtMsat: _intOrNull(map['amtMsat']),
      expirySec: _intValue(map['expirySec']),
      timestamp: _intValue(map['timestamp']),
      assetId: _stringOrNull(map['assetId']),
      assetAmount: _intOrNull(map['assetAmount']),
      paymentHash: _stringOrNull(map['paymentHash']) ?? '',
      paymentSecret: _stringOrNull(map['paymentSecret']) ?? '',
      payeePubkey: _stringOrNull(map['payeePubkey']),
      network: _stringOrNull(map['network']) ?? '',
    );
  }

  final int? amtMsat;
  final int expirySec;
  final int timestamp;
  final String? assetId;
  final int? assetAmount;
  final String paymentHash;
  final String paymentSecret;
  final String? payeePubkey;
  final String network;
}

/// BOLT11 invoice created by RLN.
class RlnLnInvoice {
  const RlnLnInvoice({required this.invoice});

  factory RlnLnInvoice.fromMap(RlnMap map) {
    return RlnLnInvoice(invoice: _stringOrNull(map['invoice']) ?? '');
  }

  final String invoice;
}

/// Result returned by payment-send operations.
class RlnPaymentResult {
  const RlnPaymentResult({
    this.paymentId,
    this.paymentHash,
    this.paymentSecret,
    this.paymentPreimage,
    required this.status,
  });

  factory RlnPaymentResult.fromMap(RlnMap map) {
    return RlnPaymentResult(
      paymentId: _stringOrNull(map['paymentId']),
      paymentHash: _stringOrNull(map['paymentHash']),
      paymentSecret: _stringOrNull(map['paymentSecret']),
      paymentPreimage: _stringOrNull(map['paymentPreimage']),
      status: _uppercaseStatus(map['status']),
    );
  }

  final String? paymentId;
  final String? paymentHash;
  final String? paymentSecret;
  final String? paymentPreimage;
  final String status;
}

/// Stored Lightning payment.
class RlnPayment {
  const RlnPayment({
    this.amtMsat,
    this.assetAmount,
    this.assetId,
    required this.paymentHash,
    required this.paymentType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.payeePubkey,
    this.preimage,
  });

  factory RlnPayment.fromMap(RlnMap map) {
    return RlnPayment(
      amtMsat: _intOrNull(map['amtMsat']),
      assetAmount: _intOrNull(map['assetAmount']),
      assetId: _stringOrNull(map['assetId']),
      paymentHash: _stringOrNull(map['paymentHash']) ?? '',
      paymentType: _canonicalEnum(map['paymentType']),
      status: _uppercaseStatus(map['status']),
      createdAt: _intValue(map['createdAt']),
      updatedAt: _intValue(map['updatedAt']),
      payeePubkey: _stringOrNull(map['payeePubkey']),
      preimage:
          _stringOrNull(map['preimage']) ??
          _stringOrNull(map['paymentPreimage']) ??
          _stringOrNull(map['payment_preimage']),
    );
  }

  final int? amtMsat;
  final int? assetAmount;
  final String? assetId;
  final String paymentHash;
  final String paymentType;
  final String status;
  final int createdAt;
  final int updatedAt;
  final String? payeePubkey;
  final String? preimage;
}

/// Lightning channel, optionally backed by an RGB asset.
class RlnChannel {
  const RlnChannel({
    required this.channelId,
    required this.peerPubkey,
    required this.status,
    required this.ready,
    required this.capacitySat,
    required this.localBalanceSat,
    required this.outboundBalanceMsat,
    required this.inboundBalanceMsat,
    this.nextOutboundHtlcLimitMsat,
    this.nextOutboundHtlcMinimumMsat,
    required this.isUsable,
    required this.public,
    this.fundingTxid,
    this.peerAlias,
    this.shortChannelId,
    this.assetId,
    this.assetLocalAmount,
    this.assetRemoteAmount,
    this.virtualOpenMode,
  });

  factory RlnChannel.fromMap(RlnMap map) {
    return RlnChannel(
      channelId: _stringOrNull(map['channelId']) ?? '',
      peerPubkey: _stringOrNull(map['peerPubkey']) ?? '',
      status: _canonicalEnum(map['status']),
      ready: _boolValue(map['ready']),
      capacitySat: _intValue(map['capacitySat']),
      localBalanceSat: _intValue(map['localBalanceSat']),
      outboundBalanceMsat: _intValue(map['outboundBalanceMsat']),
      inboundBalanceMsat: _intValue(map['inboundBalanceMsat']),
      nextOutboundHtlcLimitMsat: _intOrNull(map['nextOutboundHtlcLimitMsat']),
      nextOutboundHtlcMinimumMsat: _intOrNull(
        map['nextOutboundHtlcMinimumMsat'],
      ),
      isUsable: _boolValue(map['isUsable']),
      public: _boolValue(map['public']),
      fundingTxid: _stringOrNull(map['fundingTxid']),
      peerAlias: _stringOrNull(map['peerAlias']),
      shortChannelId: _intOrNull(map['shortChannelId']),
      assetId: _stringOrNull(map['assetId']),
      assetLocalAmount: _intOrNull(map['assetLocalAmount']),
      assetRemoteAmount: _intOrNull(map['assetRemoteAmount']),
      virtualOpenMode: _stringOrNull(map['virtualOpenMode']),
    );
  }

  final String channelId;
  final String peerPubkey;
  final String status;
  final bool ready;
  final int capacitySat;
  final int localBalanceSat;
  final int outboundBalanceMsat;
  final int inboundBalanceMsat;
  final int? nextOutboundHtlcLimitMsat;
  final int? nextOutboundHtlcMinimumMsat;
  final bool isUsable;
  final bool public;
  final String? fundingTxid;
  final String? peerAlias;
  final int? shortChannelId;
  final String? assetId;
  final int? assetLocalAmount;
  final int? assetRemoteAmount;
  final String? virtualOpenMode;
}

/// Connected peer public key.
class RlnPeer {
  const RlnPeer({required this.pubkey});

  factory RlnPeer.fromMap(RlnMap map) {
    return RlnPeer(pubkey: _stringOrNull(map['pubkey']) ?? '');
  }

  final String pubkey;
}

/// Fee rate estimate returned by RLN.
class RlnFeeRate {
  const RlnFeeRate({required this.feeRate});

  factory RlnFeeRate.fromMap(RlnMap map) {
    return RlnFeeRate(feeRate: _doubleOrNull(map['feeRate']) ?? 0);
  }

  final double feeRate;
}

/// Indexer endpoint capability information returned by RLN.
class RlnIndexerCheck {
  const RlnIndexerCheck({required this.indexerProtocol});

  factory RlnIndexerCheck.fromMap(RlnMap map) {
    return RlnIndexerCheck(
      indexerProtocol: _stringOrNull(map['indexerProtocol']) ?? '',
    );
  }

  final String indexerProtocol;
}

/// Invoice lifecycle status.
class RlnInvoiceStatus {
  const RlnInvoiceStatus({required this.status});

  factory RlnInvoiceStatus.fromMap(RlnMap map) {
    return RlnInvoiceStatus(status: _uppercaseStatus(map['status']));
  }

  final String status;
}

/// Result returned when opening a channel.
class RlnOpenChannelResult {
  const RlnOpenChannelResult({required this.temporaryChannelId});

  factory RlnOpenChannelResult.fromMap(RlnMap map) {
    return RlnOpenChannelResult(
      temporaryChannelId: _stringOrNull(map['temporaryChannelId']) ?? '',
    );
  }

  final String temporaryChannelId;
}
