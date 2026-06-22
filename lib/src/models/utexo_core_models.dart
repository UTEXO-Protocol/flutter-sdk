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
  const CoreUnspent({
    required this.utxo,
    required this.rgbAllocations,
    this.pendingBlinded = 0,
  });

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
  const CoreTransfer({
    required this.idx,
    required this.batchTransferIdx,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.assignments,
    required this.kind,
    this.txid,
    this.recipientId,
    this.receiveUtxo,
    this.changeUtxo,
    this.expiration,
    required this.transportEndpoints,
  });

  final int idx;
  final int batchTransferIdx;
  final int createdAt;
  final int updatedAt;
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
    required this.recipientId,
    this.expirationTimestamp,
    required this.batchTransferIdx,
  });

  final String invoice;
  final String recipientId;
  final int? expirationTimestamp;
  final int batchTransferIdx;
}

class CoreInvoiceData {
  const CoreInvoiceData({
    required this.invoice,
    required this.recipientId,
    this.assetSchema,
    this.assetId,
    required this.network,
    required this.assignment,
    this.expirationTimestamp,
    required this.transportEndpoints,
  });

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
  const CoreListAssets({
    required this.nia,
    required this.cfa,
    required this.ifa,
    required this.uda,
  });

  final List<CoreAssetNia> nia;
  final List<CoreAssetCfa> cfa;
  final List<CoreAssetIfa> ifa;
  final List<CoreAssetUda> uda;
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
    if (assignment.contains(type)) return Assignment(type: type);
  }
  final amount = int.tryParse(assignment);
  return amount == null
      ? const Assignment(type: 'Any')
      : Assignment(type: 'Fungible', amount: amount);
}

Outpoint parseCoreOutpoint(String value) {
  final index = value.lastIndexOf(':');
  if (index < 0) return Outpoint(txid: value, vout: 0);
  return Outpoint(
    txid: value.substring(0, index),
    vout: int.tryParse(value.substring(index + 1)) ?? 0,
  );
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
    );
  }
}

extension RlnCoreTransactionMapper on RlnTransaction {
  CoreTransaction toCore() {
    const validTypes = <String>{'RgbSend', 'Drain', 'CreateUtxos', 'User'};
    return CoreTransaction(
      txid: txid,
      transactionType: validTypes.contains(transactionType)
          ? transactionType
          : 'User',
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
      'WaitingConfirmations',
      'Settled',
      'Failed',
    };
    const validKinds = <String>{
      'Issuance',
      'ReceiveBlind',
      'ReceiveWitness',
      'Send',
      'Inflation',
    };
    return CoreTransfer(
      idx: idx,
      batchTransferIdx: 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: validStatuses.contains(status) ? status : 'WaitingCounterparty',
      assignments: assignments.map(parseCoreAssignment).toList(growable: false),
      kind: validKinds.contains(kind) ? kind : 'Send',
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
