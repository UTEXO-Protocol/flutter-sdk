import '../errors/rgb_sdk_exception.dart';
import '../wallet/utexo_wallet_types.dart';
import 'rln_models.dart';
import 'utexo_domain_policy.dart';

/// RGB assignment shape used by the RN package's core model layer.
class Assignment {
  const Assignment({required this.type, this.amount});

  /// Assignment kind, for example `Fungible`.
  final String type;

  /// RGB asset amount in the asset's smallest unit.
  final int? amount;
}

class Outpoint {
  const Outpoint({required this.txid, required this.vout});

  final String txid;
  final int vout;
}

class CoreBlockTime {
  const CoreBlockTime({required this.height, required this.timestamp});

  final int height;

  /// Block Unix timestamp in seconds.
  final int timestamp;
}

class CoreTransferTransportEndpoint {
  const CoreTransferTransportEndpoint({
    required this.endpoint,
    required this.transportType,
    required this.used,
  });

  final String endpoint;
  final String transportType;
  final bool used;
}

class CoreMedia {
  const CoreMedia({this.filePath, this.mime});

  final String? filePath;
  final String? mime;
}

class CoreTokenAttachment {
  const CoreTokenAttachment({
    required this.key,
    required this.filePath,
    required this.mime,
    required this.digest,
  });

  final int key;
  final String filePath;
  final String mime;
  final String digest;
}

class CoreAssetToken {
  CoreAssetToken({
    required this.index,
    this.ticker,
    this.name,
    this.details,
    required this.embeddedMedia,
    this.media,
    required List<CoreTokenAttachment> attachments,
    required this.reserves,
  }) : attachments = List<CoreTokenAttachment>.unmodifiable(attachments);

  final int index;
  final String? ticker;
  final String? name;
  final String? details;
  final bool embeddedMedia;
  final CoreMedia? media;
  final List<CoreTokenAttachment> attachments;
  final bool reserves;
}

class CoreBalance {
  const CoreBalance({
    required this.settled,
    required this.future,
    required this.spendable,
  });

  /// Settled balance. Bitcoin balances are sats; RGB balances are asset
  /// smallest units according to precision.
  final int settled;

  /// Pending/future balance. Bitcoin balances are sats; RGB balances are asset
  /// smallest units according to precision.
  final int future;

  /// Spendable balance. Bitcoin balances are sats; RGB balances are asset
  /// smallest units according to precision.
  final int spendable;
}

class CoreBtcBalance {
  const CoreBtcBalance({required this.vanilla, required this.colored});

  final CoreBalance vanilla;
  final CoreBalance colored;
}

class CoreAssetBalance extends CoreBalance {
  const CoreAssetBalance({
    required super.settled,
    required super.future,
    required super.spendable,
    required this.offchainOutbound,
    required this.offchainInbound,
  });

  /// Off-chain outbound RGB amount in the asset's smallest unit.
  final int offchainOutbound;

  /// Off-chain inbound RGB amount in the asset's smallest unit.
  final int offchainInbound;
}

class CoreUtxo {
  const CoreUtxo({
    required this.outpoint,
    required this.btcAmount,
    required this.colorable,
    this.exists = true,
  });

  final Outpoint outpoint;

  /// Bitcoin UTXO value in sats.
  final int btcAmount;
  final bool colorable;
  final bool exists;
}

class CoreRgbAllocation {
  const CoreRgbAllocation({
    this.assetId,
    required this.assignment,
    required this.settled,
  });

  final String? assetId;
  final Assignment assignment;
  final bool settled;
}

class CoreUnspent {
  CoreUnspent({
    required this.utxo,
    required List<CoreRgbAllocation> rgbAllocations,
    this.pendingBlinded = 0,
  }) : rgbAllocations = List<CoreRgbAllocation>.unmodifiable(rgbAllocations);

  final CoreUtxo utxo;
  final List<CoreRgbAllocation> rgbAllocations;
  final int pendingBlinded;
}

class CoreTransaction {
  const CoreTransaction({
    required this.txid,
    required this.transactionType,
    required this.received,
    required this.sent,
    required this.fee,
    this.confirmationTime,
  });

  final String txid;
  final String transactionType;

  /// Received Bitcoin amount in sats.
  final int received;

  /// Sent Bitcoin amount in sats.
  final int sent;

  /// Transaction fee in sats.
  final int fee;

  /// Confirmation height plus Unix timestamp in seconds.
  final CoreBlockTime? confirmationTime;
}

class CoreTransfer {
  CoreTransfer({
    required this.idx,
    this.batchTransferIdx,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required List<Assignment> assignments,
    required this.kind,
    this.txid,
    this.recipientId,
    this.receiveUtxo,
    this.changeUtxo,
    this.expiration,
    required List<CoreTransferTransportEndpoint> transportEndpoints,
  }) : assignments = List<Assignment>.unmodifiable(assignments),
       transportEndpoints = List<CoreTransferTransportEndpoint>.unmodifiable(
         transportEndpoints,
       );

  final int idx;
  final int? batchTransferIdx;

  /// Transfer creation Unix timestamp in seconds, when native provides it.
  final int? createdAt;

  /// Transfer update Unix timestamp in seconds, when native provides it.
  final int? updatedAt;
  final String status;
  final List<Assignment> assignments;
  final String kind;
  final String? txid;
  final String? recipientId;
  final Outpoint? receiveUtxo;
  final Outpoint? changeUtxo;

  /// Transfer expiration Unix timestamp in seconds, when native provides it.
  final int? expiration;
  final List<CoreTransferTransportEndpoint> transportEndpoints;
}

class CoreInvoiceReceiveData {
  const CoreInvoiceReceiveData({
    required this.invoice,
    this.recipientId,
    this.expirationTimestamp,
    required this.batchTransferIdx,
  });

  final String invoice;
  final String? recipientId;

  /// Invoice expiration Unix timestamp in seconds.
  final int? expirationTimestamp;
  final int batchTransferIdx;
}

class CoreInvoiceData {
  CoreInvoiceData({
    required this.invoice,
    required this.recipientId,
    this.assetSchema,
    this.assetId,
    required this.network,
    required this.assignment,
    this.expirationTimestamp,
    required List<String> transportEndpoints,
  }) : transportEndpoints = List<String>.unmodifiable(transportEndpoints);

  final String invoice;
  final String recipientId;
  final String? assetSchema;
  final String? assetId;
  final String network;
  final Assignment assignment;
  final int? expirationTimestamp;
  final List<String> transportEndpoints;
}

class CoreAsset {
  const CoreAsset({
    required this.assetId,
    this.ticker,
    required this.name,
    this.details,
    required this.precision,
    required this.timestamp,
    required this.addedAt,
    required this.balance,
    this.media,
  });

  final String assetId;
  final String? ticker;
  final String name;
  final String? details;
  final int precision;

  /// Asset issuance Unix timestamp in seconds.
  final int timestamp;

  /// Asset wallet-addition Unix timestamp in seconds.
  final int addedAt;
  final CoreBalance balance;
  final CoreMedia? media;
}

class CoreAssetNia extends CoreAsset {
  const CoreAssetNia({
    required super.assetId,
    required super.ticker,
    required super.name,
    super.details,
    required super.precision,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    super.media,
    required this.issuedSupply,
  });

  final int issuedSupply;
}

class CoreAssetCfa extends CoreAsset {
  const CoreAssetCfa({
    required super.assetId,
    required super.name,
    super.details,
    required super.precision,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    super.media,
    required this.issuedSupply,
  });

  final int issuedSupply;
}

class CoreAssetIfa extends CoreAsset {
  const CoreAssetIfa({
    required super.assetId,
    required super.ticker,
    required super.name,
    super.details,
    required super.precision,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    super.media,
    required this.initialSupply,
    required this.maxSupply,
    required this.knownCirculatingSupply,
    this.rejectListUrl,
  });

  final int initialSupply;
  final int maxSupply;
  final int knownCirculatingSupply;
  final String? rejectListUrl;
}

class CoreAssetUda extends CoreAsset {
  const CoreAssetUda({
    required super.assetId,
    required super.ticker,
    required super.name,
    super.details,
    required super.precision,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.token,
  });

  final CoreAssetToken? token;
}

class CoreListAssets {
  CoreListAssets({
    required List<CoreAssetNia> nia,
    required List<CoreAssetCfa> cfa,
    required List<CoreAssetIfa> ifa,
    required List<CoreAssetUda> uda,
  }) : nia = List<CoreAssetNia>.unmodifiable(nia),
       cfa = List<CoreAssetCfa>.unmodifiable(cfa),
       ifa = List<CoreAssetIfa>.unmodifiable(ifa),
       uda = List<CoreAssetUda>.unmodifiable(uda);

  final List<CoreAssetNia> nia;
  final List<CoreAssetCfa> cfa;
  final List<CoreAssetIfa> ifa;
  final List<CoreAssetUda> uda;

  Iterable<String> get assetIds sync* {
    yield* nia.map((asset) => asset.assetId);
    yield* cfa.map((asset) => asset.assetId);
    yield* ifa.map((asset) => asset.assetId);
    yield* uda.map((asset) => asset.assetId);
  }
}

/// Stable wallet-facing node metadata.
class WalletNodeInfo {
  const WalletNodeInfo({
    required this.pubkey,
    required this.numChannels,
    required this.numUsableChannels,
    required this.localBalanceSat,
    this.eventualCloseFeesSat,
    this.pendingOutboundPaymentsSat,
    required this.numPeers,
    this.accountXpubVanilla,
    this.accountXpubColored,
    this.maxMediaUploadSizeMb,
    this.rgbHtlcMinMsat,
    this.rgbChannelCapacityMinSat,
    this.channelCapacityMinSat,
    this.channelCapacityMaxSat,
    this.channelAssetMinAmount,
    this.channelAssetMaxAmount,
    this.networkNodes,
    this.networkChannels,
    this.latestRgsSnapshotTimestamp,
  });

  final String pubkey;
  final int numChannels;
  final int numUsableChannels;

  /// Local on-chain/channel wallet balance in sats.
  final int localBalanceSat;
  final int? eventualCloseFeesSat;
  final int? pendingOutboundPaymentsSat;
  final int numPeers;
  final String? accountXpubVanilla;
  final String? accountXpubColored;
  final int? maxMediaUploadSizeMb;

  /// Minimum RGB HTLC value in millisats.
  final int? rgbHtlcMinMsat;

  /// Minimum RGB channel capacity in sats.
  final int? rgbChannelCapacityMinSat;

  /// Minimum channel capacity in sats.
  final int? channelCapacityMinSat;

  /// Maximum channel capacity in sats.
  final int? channelCapacityMaxSat;

  /// Minimum channel RGB asset amount in the asset's smallest unit.
  final int? channelAssetMinAmount;

  /// Maximum channel RGB asset amount in the asset's smallest unit.
  final BigInt? channelAssetMaxAmount;
  final int? networkNodes;
  final int? networkChannels;

  /// Latest RGS snapshot Unix timestamp in seconds.
  final int? latestRgsSnapshotTimestamp;
}

/// Stable wallet-facing chain/network metadata.
class WalletNetworkInfo {
  const WalletNetworkInfo({required this.network, required this.height});

  final String network;
  final int height;
}

/// Canonical Lightning channel shape used by the RN/core contract.
class LightningChannel {
  const LightningChannel({
    required this.channelId,
    required this.peerPubkey,
    required this.capacitySat,
    required this.ready,
    required this.isPublic,
    this.isUsable,
    this.status,
    this.localBalanceMsat,
    this.outboundBalanceMsat,
    this.inboundBalanceMsat,
    this.nextOutboundHtlcLimitMsat,
    this.nextOutboundHtlcMinimumMsat,
    this.fundingTxid,
    this.peerAlias,
    this.shortChannelId,
    this.assetId,
    this.assetLocalAmount,
    this.assetRemoteAmount,
    this.virtualOpenMode,
  });

  final String channelId;
  final String peerPubkey;

  /// Channel capacity in sats.
  final int capacitySat;
  final bool ready;
  final bool isPublic;
  final bool? isUsable;
  final String? status;

  /// Local Lightning balance in millisats.
  final int? localBalanceMsat;

  /// Outbound Lightning balance in millisats.
  final int? outboundBalanceMsat;

  /// Inbound Lightning balance in millisats.
  final int? inboundBalanceMsat;

  /// Next outbound HTLC maximum in millisats.
  final int? nextOutboundHtlcLimitMsat;

  /// Next outbound HTLC minimum in millisats.
  final int? nextOutboundHtlcMinimumMsat;
  final String? fundingTxid;
  final String? peerAlias;
  final int? shortChannelId;
  final String? assetId;

  /// Local RGB asset amount in the asset's smallest unit.
  final int? assetLocalAmount;

  /// Remote RGB asset amount in the asset's smallest unit.
  final int? assetRemoteAmount;
  final String? virtualOpenMode;
}

/// Stable wallet-facing connected peer metadata.
class LightningPeer {
  const LightningPeer({required this.pubkey});

  final String pubkey;
}

/// Stable wallet-facing channel-open response.
class LightningChannelOpenResult {
  const LightningChannelOpenResult({required this.temporaryChannelId});

  final String temporaryChannelId;
}

/// Stable wallet-facing decoded BOLT11 invoice.
class DecodedLightningInvoice {
  const DecodedLightningInvoice({
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

  /// Lightning invoice amount in millisats.
  final int? amtMsat;

  /// Lightning invoice expiry duration in seconds.
  final int expirySec;

  /// Lightning invoice creation Unix timestamp in seconds.
  final int timestamp;
  final String? assetId;

  /// RGB asset amount in the asset's smallest unit.
  final int? assetAmount;
  final String paymentHash;
  final String paymentSecret;
  final String? payeePubkey;
  final String network;
}

/// Stable wallet-facing stored Lightning payment.
class LightningPayment {
  const LightningPayment({
    this.amtMsat,
    this.assetAmount,
    this.assetId,
    required this.paymentHash,
    this.paymentType,
    required this.status,
    this.invoice,
    this.inbound,
    this.createdAt,
    this.updatedAt,
    this.payeePubkey,
    this.preimage,
  });

  /// Lightning payment amount in millisats.
  final int? amtMsat;

  /// RGB asset amount in the asset's smallest unit.
  final int? assetAmount;
  final String? assetId;
  final String paymentHash;
  final String? paymentType;
  final String status;
  final String? invoice;

  /// Whether this is an inbound payment, when its direction is known.
  final bool? inbound;

  /// Payment creation Unix timestamp in seconds.
  final int? createdAt;

  /// Payment update Unix timestamp in seconds.
  final int? updatedAt;
  final String? payeePubkey;
  final String? preimage;
}

/// Result returned by a direct Lightning keysend operation.
class SendPaymentResult extends LightningPayment {
  const SendPaymentResult({
    required super.paymentHash,
    required super.status,
    super.preimage,
  });
}

extension RlnWalletNodeInfoMapper on RlnNodeInfo {
  WalletNodeInfo toWalletNodeInfo() {
    return WalletNodeInfo(
      pubkey: pubkey,
      numChannels: numChannels,
      numUsableChannels: numUsableChannels,
      localBalanceSat: localBalanceSat,
      eventualCloseFeesSat: eventualCloseFeesSat,
      pendingOutboundPaymentsSat: pendingOutboundPaymentsSat,
      numPeers: numPeers,
      accountXpubVanilla: accountXpubVanilla,
      accountXpubColored: accountXpubColored,
      maxMediaUploadSizeMb: maxMediaUploadSizeMb,
      rgbHtlcMinMsat: rgbHtlcMinMsat,
      rgbChannelCapacityMinSat: rgbChannelCapacityMinSat,
      channelCapacityMinSat: channelCapacityMinSat,
      channelCapacityMaxSat: channelCapacityMaxSat,
      channelAssetMinAmount: channelAssetMinAmount,
      channelAssetMaxAmount: channelAssetMaxAmount,
      networkNodes: networkNodes,
      networkChannels: networkChannels,
      latestRgsSnapshotTimestamp: latestRgsSnapshotTimestamp,
    );
  }
}

extension RlnWalletNetworkInfoMapper on RlnNetworkInfo {
  WalletNetworkInfo toWalletNetworkInfo() {
    return WalletNetworkInfo(network: network, height: height);
  }
}

extension RlnLightningPeerMapper on RlnPeer {
  LightningPeer toLightningPeer() {
    return LightningPeer(pubkey: pubkey);
  }
}

extension RlnLightningChannelOpenResultMapper on RlnOpenChannelResult {
  LightningChannelOpenResult toLightningChannelOpenResult() {
    return LightningChannelOpenResult(temporaryChannelId: temporaryChannelId);
  }
}

extension RlnDecodedLightningInvoiceMapper on RlnDecodedLnInvoice {
  DecodedLightningInvoice toDecodedLightningInvoice() {
    return DecodedLightningInvoice(
      amtMsat: amtMsat,
      expirySec: expirySec,
      timestamp: timestamp,
      assetId: assetId,
      assetAmount: assetAmount,
      paymentHash: paymentHash,
      paymentSecret: paymentSecret,
      payeePubkey: payeePubkey,
      network: network,
    );
  }
}

extension RlnSendPaymentResultMapper on RlnPaymentResult {
  SendPaymentResult toSendPaymentResult() {
    final paymentHash = this.paymentHash;
    if (paymentHash == null || paymentHash.isEmpty) {
      throw const NativeProtocolException(
        'RlnKeysendResponse.paymentHash must be a non-empty string.',
        field: 'RlnKeysendResponse.paymentHash',
      );
    }
    return SendPaymentResult(
      paymentHash: paymentHash,
      status: tryNormalizePaymentStatus(status) ?? RlnPaymentStatuses.pending,
      preimage: paymentPreimage,
    );
  }
}

extension RlnLightningPaymentMapper on RlnPayment {
  LightningPayment toLightningPayment() {
    return LightningPayment(
      amtMsat: amtMsat,
      assetAmount: assetAmount,
      assetId: assetId,
      paymentHash: paymentHash,
      paymentType: paymentType,
      status: tryNormalizePaymentStatus(status) ?? RlnPaymentStatuses.pending,
      inbound: paymentType == null ? null : paymentType != 'Outbound',
      createdAt: createdAt,
      updatedAt: updatedAt,
      payeePubkey: payeePubkey,
      preimage: preimage,
    );
  }
}

Assignment parseCoreAssignment(String assignment) {
  final fungible = RegExp(r'Fungible\((\d+)\)').firstMatch(assignment);
  if (fungible != null) {
    return Assignment(type: 'Fungible', amount: int.parse(fungible.group(1)!));
  }
  for (final type in <String>[
    'NonFungible',
    'InflationRight',
    'ReplaceRight',
    'Any',
  ]) {
    if (assignment == type) return Assignment(type: type);
  }
  final amount = int.tryParse(assignment);
  if (amount != null) return Assignment(type: 'Fungible', amount: amount);
  throw NativeProtocolException(
    'Unsupported RGB assignment shape "$assignment".',
    field: 'assignment',
  );
}

Outpoint parseCoreOutpoint(String value) {
  final index = value.lastIndexOf(':');
  if (index <= 0 || index == value.length - 1) {
    throw NativeProtocolException(
      'Outpoint must use "<txid>:<vout>" format.',
      field: 'outpoint',
    );
  }
  final vout = int.tryParse(value.substring(index + 1));
  if (vout == null || vout < 0) {
    throw NativeProtocolException(
      'Outpoint vout must be a non-negative integer.',
      field: 'outpoint',
    );
  }
  return Outpoint(txid: value.substring(0, index), vout: vout);
}

extension RlnCoreBalanceMapper on RlnBalance {
  CoreBalance toCore() {
    return CoreBalance(settled: settled, future: future, spendable: spendable);
  }
}

extension RlnCoreAssetBalanceMapper on RlnAssetBalance {
  CoreAssetBalance toCore() {
    return CoreAssetBalance(
      settled: settled,
      future: future,
      spendable: spendable,
      offchainOutbound: offchainOutbound,
      offchainInbound: offchainInbound,
    );
  }
}

extension RlnCoreMediaMapper on RlnMedia {
  CoreMedia toCore() => CoreMedia(filePath: filePath, mime: mime);
}

extension RlnCoreBlockTimeMapper on RlnBlockTime {
  CoreBlockTime toCore() => CoreBlockTime(height: height, timestamp: timestamp);
}

extension RlnCoreTransferEndpointMapper on RlnTransferTransportEndpoint {
  CoreTransferTransportEndpoint toCore() {
    return CoreTransferTransportEndpoint(
      endpoint: endpoint,
      transportType: transportType,
      used: used,
    );
  }
}

extension RlnCoreAssetTokenMapper on RlnTokenLight {
  CoreAssetToken toCore() {
    return CoreAssetToken(
      index: index,
      ticker: ticker,
      name: name,
      details: details,
      embeddedMedia: embeddedMedia,
      media: media?.toCore(),
      attachments: attachments
          .map((attachment) {
            final attachmentMedia = attachment.media;
            if (attachmentMedia == null) {
              throw const NativeProtocolException(
                'Asset token attachment is missing required media.',
                field: 'token.attachments.media',
              );
            }
            return CoreTokenAttachment(
              key: attachment.key,
              filePath: attachmentMedia.filePath,
              mime: attachmentMedia.mime,
              digest: attachmentMedia.digest,
            );
          })
          .toList(growable: false),
      reserves: reserves,
    );
  }
}

extension RlnCoreAssetNiaMapper on RlnAssetNia {
  CoreAssetNia toCore() {
    return CoreAssetNia(
      assetId: assetId,
      ticker: ticker,
      name: name,
      details: details,
      precision: precision,
      timestamp: timestamp,
      addedAt: addedAt,
      balance: balance.toCore(),
      media: media?.toCore(),
      issuedSupply: issuedSupply,
    );
  }
}

extension RlnCoreAssetIfaMapper on RlnAssetIfa {
  CoreAssetIfa toCore() {
    return CoreAssetIfa(
      assetId: assetId,
      ticker: ticker,
      name: name,
      details: details,
      precision: precision,
      timestamp: timestamp,
      addedAt: addedAt,
      balance: balance.toCore(),
      media: media?.toCore(),
      initialSupply: initialSupply,
      maxSupply: maxSupply,
      knownCirculatingSupply: knownCirculatingSupply,
      rejectListUrl: rejectListUrl,
    );
  }
}

extension RlnCoreBtcBalanceMapper on RlnBtcBalance {
  CoreBtcBalance toCore() {
    return CoreBtcBalance(vanilla: vanilla.toCore(), colored: colored.toCore());
  }
}

extension RlnCoreUnspentMapper on RlnUnspent {
  CoreUnspent toCore() {
    return CoreUnspent(
      utxo: CoreUtxo(
        outpoint: parseCoreOutpoint(utxo.outpoint),
        btcAmount: utxo.btcAmount,
        colorable: utxo.colorable,
      ),
      rgbAllocations: rgbAllocations
          .map(
            (allocation) => CoreRgbAllocation(
              assetId: allocation.assetId,
              assignment: parseCoreAssignment(allocation.assignment),
              settled: allocation.settled,
            ),
          )
          .toList(growable: false),
      pendingBlinded: pendingBlinded,
    );
  }
}

extension RlnCoreTransactionMapper on RlnTransaction {
  CoreTransaction toCore() {
    return CoreTransaction(
      txid: txid,
      transactionType: UtexoDomainPolicy.mapTransactionType(transactionType),
      received: received,
      sent: sent,
      fee: fee,
      confirmationTime: confirmationTime?.toCore(),
    );
  }
}

extension RlnCoreTransferMapper on RlnTransfer {
  CoreTransfer toCore() {
    final kind = UtexoDomainPolicy.requireTransferKind(this.kind);
    return CoreTransfer(
      idx: idx,
      batchTransferIdx: batchTransferIdx,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: UtexoDomainPolicy.requireTransferStatus(status),
      assignments: assignments.map(parseCoreAssignment).toList(growable: false),
      kind: kind,
      txid: txid,
      recipientId: recipientId,
      receiveUtxo: receiveUtxo == null ? null : parseCoreOutpoint(receiveUtxo!),
      changeUtxo: changeUtxo == null ? null : parseCoreOutpoint(changeUtxo!),
      expiration: expiration,
      transportEndpoints: transportEndpoints
          .map((endpoint) => endpoint.toCore())
          .toList(growable: false),
    );
  }
}

extension RlnCoreInvoiceMapper on RlnInvoice {
  CoreInvoiceReceiveData toCore() {
    return CoreInvoiceReceiveData(
      invoice: invoice,
      recipientId: recipientId,
      expirationTimestamp: expirationTimestamp,
      batchTransferIdx: batchTransferIdx,
    );
  }
}

extension RlnCoreDecodedRgbInvoiceMapper on RlnDecodedRgbInvoice {
  CoreInvoiceData toCore(String invoice) {
    return CoreInvoiceData(
      invoice: invoice,
      recipientId: recipientId,
      assetSchema: assetSchema,
      assetId: assetId,
      network: network,
      assignment: parseCoreAssignment(assignment),
      expirationTimestamp: expirationTimestamp,
      transportEndpoints: transportEndpoints,
    );
  }
}

extension RlnCoreAssetsMapper on RlnAssets {
  CoreListAssets toCore() {
    return CoreListAssets(
      nia: nia.map((source) => source.toCore()).toList(growable: false),
      cfa: cfa
          .map(
            (source) => CoreAssetCfa(
              assetId: source.assetId,
              name: source.name,
              details: source.details,
              precision: source.precision,
              timestamp: source.timestamp,
              addedAt: source.addedAt,
              balance: source.balance.toCore(),
              media: source.media?.toCore(),
              issuedSupply: source.issuedSupply,
            ),
          )
          .toList(growable: false),
      ifa: ifa.map((source) => source.toCore()).toList(growable: false),
      uda: uda
          .map(
            (source) => CoreAssetUda(
              assetId: source.assetId,
              ticker: source.ticker,
              name: source.name,
              details: source.details,
              precision: source.precision,
              timestamp: source.timestamp,
              addedAt: source.addedAt,
              balance: source.balance.toCore(),
              token: source.token?.toCore(),
            ),
          )
          .toList(growable: false),
    );
  }
}

extension RlnLightningChannelMapper on RlnChannel {
  LightningChannel toLightningChannel() {
    return LightningChannel(
      channelId: channelId,
      peerPubkey: peerPubkey,
      capacitySat: capacitySat,
      ready: ready,
      isPublic: public,
      isUsable: isUsable,
      status: status == null ? null : _normalizeChannelStatus(status!),
      localBalanceMsat: localBalanceSat == null
          ? null
          : localBalanceSat! * 1000,
      outboundBalanceMsat: outboundBalanceMsat,
      inboundBalanceMsat: inboundBalanceMsat,
      nextOutboundHtlcLimitMsat: nextOutboundHtlcLimitMsat,
      nextOutboundHtlcMinimumMsat: nextOutboundHtlcMinimumMsat,
      fundingTxid: fundingTxid,
      peerAlias: peerAlias,
      shortChannelId: shortChannelId,
      assetId: assetId,
      assetLocalAmount: assetLocalAmount,
      assetRemoteAmount: assetRemoteAmount,
      virtualOpenMode: virtualOpenMode,
    );
  }
}

String _normalizeChannelStatus(String status) {
  return UtexoDomainPolicy.normalizeChannelStatus(status);
}
