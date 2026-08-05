import '../errors/rgb_sdk_exception.dart';
import 'rln_models.dart';

/// RGB assignment shape used by the RN package's core model layer.
class Assignment {
  const Assignment({required this.type, this.amount});

  final String type;
  final int? amount;
}

class Outpoint {
  const Outpoint({required this.txid, required this.vout});

  final String txid;
  final int vout;
}

class CoreBalance {
  const CoreBalance({
    required this.settled,
    required this.future,
    required this.spendable,
  });

  final int settled;
  final int future;
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

  final int offchainOutbound;
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
  final int received;
  final int sent;
  final int fee;
  final RlnBlockTime? confirmationTime;
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
    required List<RlnTransferTransportEndpoint> transportEndpoints,
  }) : assignments = List<Assignment>.unmodifiable(assignments),
       transportEndpoints = List<RlnTransferTransportEndpoint>.unmodifiable(
         transportEndpoints,
       );

  final int idx;
  final int? batchTransferIdx;
  final int? createdAt;
  final int? updatedAt;
  final String status;
  final List<Assignment> assignments;
  final String kind;
  final String? txid;
  final String? recipientId;
  final Outpoint? receiveUtxo;
  final Outpoint? changeUtxo;
  final int? expiration;
  final List<RlnTransferTransportEndpoint> transportEndpoints;
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
  final int timestamp;
  final int addedAt;
  final CoreBalance balance;
  final RlnMedia? media;
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

  final RlnTokenLight? token;
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
  final int capacitySat;
  final bool ready;
  final bool isPublic;
  final bool? isUsable;
  final String? status;
  final int? localBalanceMsat;
  final int? outboundBalanceMsat;
  final int? inboundBalanceMsat;
  final int? nextOutboundHtlcLimitMsat;
  final int? nextOutboundHtlcMinimumMsat;
  final String? fundingTxid;
  final String? peerAlias;
  final int? shortChannelId;
  final String? assetId;
  final int? assetLocalAmount;
  final int? assetRemoteAmount;
  final String? virtualOpenMode;
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
    const typeMap = <String, String>{
      'RGB_SEND': 'RgbSend',
      'DRAIN': 'Drain',
      'CREATE_UTXOS': 'CreateUtxos',
      'SEND_BTC': 'SendBtc',
      'INCOMING': 'Incoming',
    };
    final mappedType = typeMap[transactionType];
    if (mappedType == null) {
      throw NativeProtocolException(
        'Unsupported transaction type "$transactionType".',
        field: 'transactionType',
      );
    }
    return CoreTransaction(
      txid: txid,
      transactionType: mappedType,
      received: received,
      sent: sent,
      fee: fee,
      confirmationTime: confirmationTime,
    );
  }
}

extension RlnCoreTransferMapper on RlnTransfer {
  CoreTransfer toCore() {
    const validStatuses = <String>{
      'WaitingCounterparty',
      'WaitingSafeHeight',
      'WaitingConfirmations',
      'Settled',
      'Failed',
      'Initiated',
    };
    const validKinds = <String>{
      'Issuance',
      'ReceiveBlind',
      'ReceiveWitness',
      'Send',
      'Inflation',
      'Burn',
    };
    final kind = this.kind;
    if (!validStatuses.contains(status)) {
      throw NativeProtocolException(
        'Unsupported transfer status "$status".',
        field: 'status',
      );
    }
    if (kind == null || !validKinds.contains(kind)) {
      throw NativeProtocolException(
        'Unsupported transfer kind "$kind".',
        field: 'kind',
      );
    }
    return CoreTransfer(
      idx: idx,
      batchTransferIdx: batchTransferIdx,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status,
      assignments: assignments.map(parseCoreAssignment).toList(growable: false),
      kind: kind,
      txid: txid,
      recipientId: recipientId,
      receiveUtxo: receiveUtxo == null ? null : parseCoreOutpoint(receiveUtxo!),
      changeUtxo: changeUtxo == null ? null : parseCoreOutpoint(changeUtxo!),
      expiration: expiration,
      transportEndpoints: transportEndpoints,
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
      nia: nia
          .map(
            (source) => CoreAssetNia(
              assetId: source.assetId,
              ticker: source.ticker,
              name: source.name,
              details: source.details,
              precision: source.precision,
              timestamp: source.timestamp,
              addedAt: source.addedAt,
              balance: source.balance.toCore(),
              media: source.media,
              issuedSupply: source.issuedSupply,
            ),
          )
          .toList(growable: false),
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
              media: source.media,
              issuedSupply: source.issuedSupply,
            ),
          )
          .toList(growable: false),
      ifa: ifa
          .map(
            (source) => CoreAssetIfa(
              assetId: source.assetId,
              ticker: source.ticker,
              name: source.name,
              details: source.details,
              precision: source.precision,
              timestamp: source.timestamp,
              addedAt: source.addedAt,
              balance: source.balance.toCore(),
              media: source.media,
              initialSupply: source.initialSupply,
              maxSupply: source.maxSupply,
              knownCirculatingSupply: source.knownCirculatingSupply,
              rejectListUrl: source.rejectListUrl,
            ),
          )
          .toList(growable: false),
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
              token: source.token,
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
  const statuses = <String, String>{
    'opening': 'Opening',
    'opened': 'Opened',
    'closing': 'Closing',
  };
  final normalized = statuses[status.toLowerCase()];
  if (normalized == null) {
    throw NativeProtocolException(
      'Unsupported channel status "$status".',
      field: 'status',
    );
  }
  return normalized;
}
