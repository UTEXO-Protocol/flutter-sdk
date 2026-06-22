import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';
import 'dart:convert';
import 'dart:io';

class FakeRlnHostApi extends RlnHostApi {
  int? createdNodeId;
  int createNodeCount = 0;
  int? createdSignerId;
  String? createdNodeNetwork;
  String? createdSignerNetwork;
  bool? createdSignerPermissivePolicy;
  bool? createdEnableVirtualChannelsV0;
  List<String>? createdVirtualPeerPubkeys;
  String? createdLspBaseUrl;
  String? createdLspBearerToken;
  String? initializedPassword;
  int initNodeCount = 0;
  int? initializedNativeSignerId;
  int? attachedNativeSignerId;
  int? unlockedNativeSignerId;
  int? destroyedNativeSignerId;
  int shutdownCount = 0;
  int destroyNodeCount = 0;
  String? lastTransferAssetId;
  bool throwOnEmptyListTransfers = false;
  String emptyListTransfersErrorCode = 'RlnError';
  String emptyListTransfersErrorMessage =
      'rgb_sdk_flutter.RlnError.InvalidRequest(message: "invalid request")';
  String? unlockedHost;
  String? unlockedIndexerUrl;
  String? unlockedProxyEndpoint;
  bool? lastRgbInvoiceWitness;
  int? lastRgbInvoiceMinConfirmations;
  Map<Object?, Object?>? lastSendRgb;
  Map<Object?, Object?>? lastSendBtc;
  Map<Object?, Object?>? lastLnInvoice;
  Map<Object?, Object?>? lastClaimHodlInvoice;
  String? lastCancelHodlPaymentHash;
  String? lastApayHostNodeId;
  String? lastApayAddressUsername;
  String? lastApayAddressDomain;
  int apayNewCalls = 0;
  int apayNewWithAddressCalls = 0;
  String? lastVssClearFencePassword;
  Map<Object?, Object?>? lastSendPayment;
  Map<Object?, Object?>? lastBackup;
  Map<Object?, Object?>? lastIssueAssetNia;
  Map<Object?, Object?>? lastIssueAssetCfa;
  Map<Object?, Object?>? lastIssueAssetIfa;
  Map<Object?, Object?>? lastIssueAssetUda;
  Map<Object?, Object?>? lastOpenChannel;
  Map<Object?, Object?>? lastCloseChannel;
  Map<Object?, Object?>? lastKeysend;
  String? lastAssetBalanceId;
  String? lastDecodeLnInvoice;
  String? lastConnectedPeer;
  String? lastDisconnectedPeerPubkey;
  String? lastTemporaryChannelId;
  bool? lastListUnspentsSkipSync;
  bool? lastListTransactionsSkipSync;
  bool? lastCreateUtxosUpTo;
  int? lastCreateUtxosNum;
  double? lastCreateUtxosFeeRate;
  int? lastEstimateFeeBlocks;
  String invoiceStatus = 'SUCCEEDED';
  String paymentStatus = 'CLAIMING';
  List<Map<Object?, Object?>>? channelRows;

  Map<Object?, Object?> _assetBalance({
    int settled = 100,
    int future = 0,
    int spendable = 100,
  }) {
    return <Object?, Object?>{
      'settled': settled,
      'future': future,
      'spendable': spendable,
      'offchainOutbound': 2,
      'offchainInbound': 3,
    };
  }

  Map<Object?, Object?> _niaAsset({
    String assetId = 'asset',
    String ticker = 'TST',
    String name = 'Test Asset',
  }) {
    return <Object?, Object?>{
      'assetId': assetId,
      'ticker': ticker,
      'name': name,
      'precision': 0,
      'issuedSupply': 1000,
      'timestamp': 1,
      'addedAt': 1,
      'balance': _assetBalance(),
    };
  }

  Map<Object?, Object?> _cfaAsset() {
    return <Object?, Object?>{
      'assetId': 'cfa',
      'name': 'Collectible',
      'details': 'details',
      'precision': 0,
      'issuedSupply': 1,
      'timestamp': 1,
      'addedAt': 1,
      'balance': _assetBalance(settled: 1, spendable: 1),
    };
  }

  Map<Object?, Object?> _ifaAsset() {
    return <Object?, Object?>{
      'assetId': 'ifa',
      'ticker': 'IFA',
      'name': 'Inflatable',
      'details': 'details',
      'precision': 0,
      'initialSupply': 1000,
      'maxSupply': 2000,
      'knownCirculatingSupply': 1000,
      'timestamp': 1,
      'addedAt': 1,
      'balance': _assetBalance(settled: 1000, spendable: 1000),
      'rejectListUrl': 'https://example.com/reject-list',
    };
  }

  Map<Object?, Object?> _udaAsset() {
    return <Object?, Object?>{
      'assetId': 'uda',
      'ticker': 'UDA',
      'name': 'Unique',
      'details': 'details',
      'precision': 0,
      'timestamp': 1,
      'addedAt': 1,
      'balance': _assetBalance(settled: 1, spendable: 1),
      'token': <Object?, Object?>{
        'index': 0,
        'ticker': 'UDA',
        'name': 'Unique',
        'details': 'details',
        'embeddedMedia': false,
        'attachments': <Object?>[],
        'reserves': false,
      },
    };
  }

  @override
  Future<int> rlnCreateNode(
    String storageDirPath,
    int daemonListeningPort,
    int ldkPeerListeningPort,
    String network,
    int maxMediaUploadSizeMb,
    bool? enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    String? vssUrl,
    bool vssAllowHttp,
    bool vssAllowEmptyRestore,
    String? lspBaseUrl,
    String? lspBearerToken,
  ) async {
    createNodeCount += 1;
    createdNodeId = 6 + createNodeCount;
    createdNodeNetwork = network;
    createdEnableVirtualChannelsV0 = enableVirtualChannelsV0;
    createdVirtualPeerPubkeys = virtualPeerPubkeys;
    createdLspBaseUrl = lspBaseUrl;
    createdLspBearerToken = lspBearerToken;
    return createdNodeId!;
  }

  @override
  Future<String> rlnInitNode(
    int nodeId,
    String password,
    String? mnemonic,
  ) async {
    initNodeCount += 1;
    initializedPassword = password;
    return 'pubkey';
  }

  @override
  Future<int> rlnCreateNativeExternalSigner(
    String seedHex,
    String network,
    bool permissivePolicy,
  ) async {
    expect(seedHex.length, 64);
    createdSignerNetwork = network;
    createdSignerPermissivePolicy = permissivePolicy;
    createdSignerId = 99;
    return createdSignerId!;
  }

  @override
  Future<void> rlnInitNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
  ) async {
    initializedNativeSignerId = signerId;
  }

  @override
  Future<void> rlnAttachNativeExternalSigner(int nodeId, int signerId) async {
    attachedNativeSignerId = signerId;
  }

  @override
  Future<void> rlnUnlockNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
  ) async {
    unlockedNativeSignerId = signerId;
    unlockedHost = bitcoindRpcHost;
    unlockedIndexerUrl = indexerUrl;
    unlockedProxyEndpoint = proxyEndpoint;
  }

  @override
  Future<void> rlnDestroyNativeExternalSigner(int signerId) async {
    destroyedNativeSignerId = signerId;
  }

  @override
  Future<void> rlnUnlockNode(
    int nodeId,
    String password,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
  ) async {
    unlockedHost = bitcoindRpcHost;
    unlockedIndexerUrl = indexerUrl;
    unlockedProxyEndpoint = proxyEndpoint;
  }

  @override
  Future<Map<Object?, Object?>> rlnAddress(int nodeId) async {
    return <Object?, Object?>{'address': 'bcrt1address'};
  }

  @override
  Future<Map<Object?, Object?>> rlnBtcBalance(int nodeId, bool skipSync) async {
    return <Object?, Object?>{
      'vanilla': <Object?, Object?>{
        'settled': 1000,
        'future': 0,
        'spendable': 900,
      },
      'colored': <Object?, Object?>{
        'settled': 2000,
        'future': 0,
        'spendable': 1800,
      },
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnNodeInfo(int nodeId) async {
    return <Object?, Object?>{
      'pubkey': 'node',
      'numChannels': 0,
      'numUsableChannels': 0,
      'localBalanceSat': 0,
      'numPeers': 0,
      'accountXpubVanilla': 'xpub-van',
      'accountXpubColored': 'xpub-col',
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnNetworkInfo(int nodeId) async {
    return <Object?, Object?>{'network': 'regtest', 'height': 101};
  }

  @override
  Future<Map<Object?, Object?>> rlnCheckIndexerUrl(
    int nodeId,
    String indexerUrl,
  ) async {
    return <Object?, Object?>{'indexerProtocol': 'electrum'};
  }

  @override
  Future<void> rlnCheckProxyEndpoint(int nodeId, String proxyEndpoint) async {}

  @override
  Future<Map<Object?, Object?>> rlnRgbInvoice(
    int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness,
  ) async {
    lastRgbInvoiceWitness = witness;
    lastRgbInvoiceMinConfirmations = minConfirmations;
    return <Object?, Object?>{
      'invoice': 'rgb:invoice',
      'recipientId': 'recipient',
      'batchTransferIdx': 1,
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnDecodeRgbInvoice(
    int nodeId,
    String invoice,
  ) async {
    return <Object?, Object?>{
      'recipientId': 'recipient',
      'assetId': 'asset',
      'assignment': '100',
      'transportEndpoints': <String>['rpc://proxy/json-rpc'],
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnListAssets(
    int nodeId,
    List<String> filterAssetSchemas,
  ) async {
    return <Object?, Object?>{
      'nia': <Object?>[
        <Object?, Object?>{
          'assetId': 'asset',
          'ticker': 'TST',
          'name': 'Test Asset',
          'precision': 0,
          'issuedSupply': 1000,
          'timestamp': 1,
          'addedAt': 1,
          'balance': <Object?, Object?>{
            'settled': 100,
            'future': 0,
            'spendable': 100,
            'offchainOutbound': 0,
            'offchainInbound': 0,
          },
        },
      ],
      'cfa': <Object?>[],
      'ifa': <Object?>[],
      'uda': <Object?>[],
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnAssetBalance(
    int nodeId,
    String assetId,
  ) async {
    lastAssetBalanceId = assetId;
    return _assetBalance();
  }

  @override
  Future<Object?> rlnIssueAssetNia(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  ) async {
    lastIssueAssetNia = <Object?, Object?>{
      'ticker': ticker,
      'name': name,
      'precision': precision,
      'amounts': amounts,
    };
    return _niaAsset(ticker: ticker, name: name);
  }

  @override
  Future<Object?> rlnIssueAssetCfa(
    int nodeId,
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  ) async {
    lastIssueAssetCfa = <Object?, Object?>{
      'name': name,
      'details': details,
      'precision': precision,
      'amounts': amounts,
      'fileDigest': fileDigest,
    };
    return _cfaAsset();
  }

  @override
  Future<Object?> rlnIssueAssetIfa(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
    List<int> inflationAmounts,
    String? rejectListUrl,
  ) async {
    lastIssueAssetIfa = <Object?, Object?>{
      'ticker': ticker,
      'name': name,
      'precision': precision,
      'amounts': amounts,
      'inflationAmounts': inflationAmounts,
      'rejectListUrl': rejectListUrl,
    };
    return _ifaAsset();
  }

  @override
  Future<Object?> rlnIssueAssetUda(
    int nodeId,
    String ticker,
    String name,
    String? details,
    int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests,
  ) async {
    lastIssueAssetUda = <Object?, Object?>{
      'ticker': ticker,
      'name': name,
      'details': details,
      'precision': precision,
      'mediaFileDigest': mediaFileDigest,
      'attachmentsFileDigests': attachmentsFileDigests,
    };
    return _udaAsset();
  }

  @override
  Future<Map<Object?, Object?>> rlnSendRgb(
    int nodeId,
    bool donation,
    double feeRate,
    int minConfirmations,
    bool skipSync,
    String assetId,
    String recipientId,
    int amount,
    List<String> transportEndpoints,
    int? witnessAmountSat,
    int? witnessBlinding,
  ) async {
    lastSendRgb = <Object?, Object?>{
      'assetId': assetId,
      'recipientId': recipientId,
      'amount': amount,
      'feeRate': feeRate,
      'minConfirmations': minConfirmations,
      'transportEndpoints': transportEndpoints,
    };
    return <Object?, Object?>{'txid': 'txid', 'batchTransferIdx': 2};
  }

  @override
  Future<void> rlnCreateUtxos(
    int nodeId,
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) async {
    lastCreateUtxosUpTo = upTo;
    lastCreateUtxosNum = num;
    lastCreateUtxosFeeRate = feeRate;
  }

  @override
  Future<Map<Object?, Object?>> rlnSendBtc(
    int nodeId,
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  ) async {
    lastSendBtc = <Object?, Object?>{
      'amount': amount,
      'address': address,
      'feeRate': feeRate,
    };
    return <Object?, Object?>{'txid': 'btc-txid'};
  }

  @override
  Future<List<Map<Object?, Object?>>> rlnListUnspents(
    int nodeId,
    bool skipSync,
  ) async {
    lastListUnspentsSkipSync = skipSync;
    return <Map<Object?, Object?>>[
      <Object?, Object?>{
        'utxo': <Object?, Object?>{
          'outpoint': 'txid:0',
          'btcAmount': 1000,
          'colorable': true,
        },
        'rgbAllocations': <Object?>[
          <Object?, Object?>{
            'assetId': 'asset',
            'assignment': 'Fungible(100)',
            'settled': true,
          },
        ],
      },
    ];
  }

  @override
  Future<List<Map<Object?, Object?>>> rlnListTransactions(
    int nodeId,
    bool skipSync,
  ) async {
    lastListTransactionsSkipSync = skipSync;
    return <Map<Object?, Object?>>[
      <Object?, Object?>{
        'transactionType': 'User',
        'txid': 'btc-txid',
        'received': 1000,
        'sent': 100,
        'fee': 10,
        'confirmationTime': <Object?, Object?>{'height': 101, 'timestamp': 2},
      },
    ];
  }

  @override
  Future<Map<Object?, Object?>> rlnEstimateFee(int nodeId, int blocks) async {
    lastEstimateFeeBlocks = blocks;
    return <Object?, Object?>{'feeRate': 2.25};
  }

  @override
  Future<void> rlnBackup(int nodeId, String backupPath, String password) async {
    lastBackup = <Object?, Object?>{
      'backupPath': backupPath,
      'password': password,
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnLnInvoice(
    int nodeId,
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
  ) async {
    lastLnInvoice = <Object?, Object?>{
      'amtMsat': amtMsat,
      'expirySec': expirySec,
      'assetId': assetId,
      'assetAmount': assetAmount,
      'paymentHash': paymentHash,
      'minFinalCltvExpiryDelta': minFinalCltvExpiryDelta,
    };
    return <Object?, Object?>{'invoice': 'lnbc-invoice'};
  }

  @override
  Future<Map<Object?, Object?>> rlnClaimHodlInvoice(
    int nodeId,
    String paymentHash,
    String paymentPreimage,
  ) async {
    lastClaimHodlInvoice = <Object?, Object?>{
      'paymentHash': paymentHash,
      'paymentPreimage': paymentPreimage,
    };
    return <Object?, Object?>{'changed': true};
  }

  @override
  Future<void> rlnCancelHodlInvoice(int nodeId, String paymentHash) async {
    lastCancelHodlPaymentHash = paymentHash;
  }

  @override
  Future<Map<Object?, Object?>> rlnApayNew(
    int nodeId,
    String hostNodeId,
  ) async {
    apayNewCalls += 1;
    lastApayHostNodeId = hostNodeId;
    return <Object?, Object?>{
      'requestId': 'request',
      'hostNodeId': hostNodeId,
      'protocolVersion': 1,
      'orderId': 'order',
      'status': 'created',
      'acceptedThroughIndex': 0,
      'nextIndexExpected': 1,
      'unusedHashes': 2,
      'refillBatchSize': 10,
      'firstHashIndex': 0,
      'lastHashIndex': 1,
      'hashes': <Object?>[
        <Object?, Object?>{'hashIndex': 0, 'paymentHash': 'hash'},
      ],
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnApayNewWithAddress(
    int nodeId,
    String hostNodeId,
    String username,
    String domain,
  ) async {
    apayNewWithAddressCalls += 1;
    lastApayHostNodeId = hostNodeId;
    lastApayAddressUsername = username;
    lastApayAddressDomain = domain;
    return <Object?, Object?>{
      'requestId': 'request',
      'hostNodeId': hostNodeId,
      'protocolVersion': 1,
      'orderId': 'order',
      'status': 'created',
      'acceptedThroughIndex': 0,
      'nextIndexExpected': 1,
      'unusedHashes': 2,
      'refillBatchSize': 10,
      'firstHashIndex': 0,
      'lastHashIndex': 1,
      'hashes': <Object?>[
        <Object?, Object?>{'hashIndex': 0, 'paymentHash': 'hash'},
      ],
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnDecodeLnInvoice(
    int nodeId,
    String invoice,
  ) async {
    lastDecodeLnInvoice = invoice;
    return <Object?, Object?>{
      'amtMsat': 2000,
      'expirySec': 3600,
      'timestamp': 1,
      'assetId': 'asset',
      'assetAmount': 5,
      'paymentHash': 'payment-hash',
      'paymentSecret': 'payment-secret',
      'payeePubkey': 'payee',
      'network': 'regtest',
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnSendPayment(
    int nodeId,
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    lastSendPayment = <Object?, Object?>{
      'invoice': invoice,
      'amtMsat': amtMsat,
      'assetId': assetId,
      'assetAmount': assetAmount,
    };
    return <Object?, Object?>{
      'paymentHash': 'payment-hash',
      'paymentId': 'payment-id',
      'status': 'SUCCEEDED',
    };
  }

  @override
  Future<Map<Object?, Object?>> rlnInvoiceStatus(
    int nodeId,
    String invoice,
  ) async {
    return <Object?, Object?>{'status': invoiceStatus};
  }

  @override
  Future<Map<Object?, Object?>> rlnGetPayment(
    int nodeId,
    String paymentHash,
  ) async {
    return <Object?, Object?>{
      'paymentHash': paymentHash,
      'paymentType': 'OUTBOUND',
      'status': paymentStatus,
      'createdAt': 1,
      'updatedAt': 2,
    };
  }

  @override
  Future<List<Map<Object?, Object?>>> rlnListPayments(int nodeId) async {
    return <Map<Object?, Object?>>[
      <Object?, Object?>{
        'paymentHash': 'hash-1',
        'paymentType': 'OUTBOUND',
        'status': 'SUCCEEDED',
        'paymentPreimage': 'claim-preimage',
        'createdAt': 1,
        'updatedAt': 2,
      },
    ];
  }

  @override
  Future<List<Map<Object?, Object?>>> rlnListPeers(int nodeId) async {
    return <Map<Object?, Object?>>[
      <Object?, Object?>{'pubkey': 'peer'},
    ];
  }

  @override
  Future<void> rlnConnectPeer(int nodeId, String peerPubkeyAndAddr) async {
    lastConnectedPeer = peerPubkeyAndAddr;
  }

  @override
  Future<void> rlnDisconnectPeer(int nodeId, String peerPubkey) async {
    lastDisconnectedPeerPubkey = peerPubkey;
  }

  @override
  Future<List<Map<Object?, Object?>>> rlnListChannels(int nodeId) async {
    return channelRows ??
        <Map<Object?, Object?>>[
          <Object?, Object?>{
            'channelId': 'channel-id',
            'peerPubkey': 'peer',
            'status': 'Opened',
            'ready': true,
            'capacitySat': 100000,
            'localBalanceSat': 90000,
            'outboundBalanceMsat': 80000,
            'inboundBalanceMsat': 70000,
            'isUsable': true,
            'public': false,
            'assetId': 'asset',
            'assetLocalAmount': 100,
            'assetRemoteAmount': 0,
          },
        ];
  }

  @override
  Future<Map<Object?, Object?>> rlnOpenChannel(
    int nodeId,
    String peerPubkeyAndOptAddr,
    int capacitySat,
    int pushMsat,
    bool publicChannel,
    bool withAnchors,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  ) async {
    lastOpenChannel = <Object?, Object?>{
      'peerPubkeyAndOptAddr': peerPubkeyAndOptAddr,
      'capacitySat': capacitySat,
      'pushMsat': pushMsat,
      'publicChannel': publicChannel,
      'withAnchors': withAnchors,
      'assetId': assetId,
      'assetAmount': assetAmount,
    };
    return <Object?, Object?>{'temporaryChannelId': 'temporary-channel-id'};
  }

  @override
  Future<void> rlnCloseChannel(
    int nodeId,
    String channelId,
    String peerPubkey,
    bool force,
  ) async {
    lastCloseChannel = <Object?, Object?>{
      'channelId': channelId,
      'peerPubkey': peerPubkey,
      'force': force,
    };
  }

  @override
  Future<String> rlnGetChannelId(int nodeId, String temporaryChannelId) async {
    lastTemporaryChannelId = temporaryChannelId;
    return 'channel-id';
  }

  @override
  Future<Map<Object?, Object?>> rlnKeysend(
    int nodeId,
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    lastKeysend = <Object?, Object?>{
      'destPubkey': destPubkey,
      'amtMsat': amtMsat,
      'assetId': assetId,
      'assetAmount': assetAmount,
    };
    return <Object?, Object?>{
      'paymentHash': 'keysend-hash',
      'paymentId': 'keysend-id',
      'status': 'SUCCEEDED',
    };
  }

  @override
  Future<List<Map<Object?, Object?>>> rlnListTransfers(
    int nodeId,
    String assetId,
  ) async {
    lastTransferAssetId = assetId;
    if (assetId.isEmpty && throwOnEmptyListTransfers) {
      throw PlatformException(
        code: emptyListTransfersErrorCode,
        message: emptyListTransfersErrorMessage,
        details: <Object?, Object?>{'operation': 'rlnListTransfers'},
      );
    }
    return <Map<Object?, Object?>>[
      <Object?, Object?>{
        'idx': 1,
        'createdAt': 2,
        'updatedAt': 3,
        'status': 'Settled',
        'kind': 'Send',
        'assignments': <String>['Fungible(10)'],
      },
    ];
  }

  @override
  Future<void> rlnShutdown(int nodeId) async {
    shutdownCount += 1;
  }

  @override
  Future<void> rlnSync(int nodeId) async {}

  @override
  Future<void> rlnDestroyNode(int nodeId) async {
    destroyNodeCount += 1;
  }

  @override
  Future<void> rlnVssClearFence(int nodeId, String password) async {
    lastVssClearFencePassword = password;
  }
}

class FakeLspClient extends IUtexoLspClient {
  bool closed = false;
  int getInfoCalls = 0;
  int lightningAddressLookups = 0;
  String? lastLightningAddressPubkey;

  @override
  void close() {
    closed = true;
  }

  @override
  Future<LspGetInfoResponse> getInfo() async {
    getInfoCalls += 1;
    return const LspGetInfoResponse(
      pubkey: 'lsp-peer',
      numChannels: 1,
      numUsableChannels: 1,
    );
  }

  @override
  Future<LspLnurlpCallbackResponse> resolveAddress(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return const LspLnurlpCallbackResponse(pr: 'lnbc1invoice', routes: []);
  }

  @override
  Future<LspLnurlpCallbackResponse> lnurlCallback(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return const LspLnurlpCallbackResponse(pr: 'lnbc1invoice', routes: []);
  }

  @override
  Future<LspLightningAddressByPubkeyResponse> getLightningAddressByPubkey(
    String peerPubkey,
  ) async {
    lightningAddressLookups += 1;
    lastLightningAddressPubkey = peerPubkey;
    return const LspLightningAddressByPubkeyResponse(
      username: 'alice',
      domain: 'lsp.example',
    );
  }

  @override
  Future<LspOnchainSendResponse> onchainSend(
    LspOnchainSendRequest params,
  ) async {
    return const LspOnchainSendResponse(
      rgbInvoice: 'rgb:invoice',
      lnInvoice: 'lnbc1invoice',
      mappingId: 'mapping',
    );
  }

  @override
  Future<LspLightningReceiveResponse> lightningReceive(
    LspLightningReceiveRequest params,
  ) async {
    return const LspLightningReceiveResponse(
      lnInvoice: 'lnbc1invoice',
      rgbInvoice: 'rgb:invoice',
      mappingId: 'mapping',
    );
  }
}

void main() {
  UtexoWallet walletWith(FakeRlnHostApi hostApi) {
    return UtexoWallet(
      config: const UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
      client: RlnClient(hostApi: hostApi),
    );
  }

  test('requires initialization before wallet operations', () async {
    final wallet = walletWith(FakeRlnHostApi());

    expect(wallet.getAddress, throwsA(isA<WalletException>()));
  });

  test('initializes, unlocks, and delegates address lookup', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.init(password: 'password');
    await wallet.unlock(
      password: 'password',
      config: const UtexoUnlockConfig(
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcPort: 18444,
      ),
    );

    expect(wallet.nodeId, 7);
    expect(wallet.isInitialized, true);
    expect(wallet.isUnlocked, true);
    expect(hostApi.initializedPassword, 'password');
    expect(hostApi.unlockedHost, '127.0.0.1');
    expect(await wallet.getAddress(), 'bcrt1address');
  });

  test('supports RN-style password signer in constructor', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = UtexoWallet(
      config: const UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
      client: RlnClient(hostApi: hostApi),
      signer: PasswordRlnSigner(
        password: 'password',
        mnemonic:
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      ),
    );

    await wallet.init();
    await wallet.unlock(
      config: const UtexoUnlockConfig(
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcPort: 18444,
      ),
    );

    expect(hostApi.initializedPassword, 'password');
    expect(hostApi.unlockedHost, '127.0.0.1');
  });

  test('supports RN-style native external signer lifecycle', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = UtexoWallet(
      config: const UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
      client: RlnClient(hostApi: hostApi),
      signer: NativeExternalRlnSigner(
        keys: RlnKeyMaterial.mnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        ),
        network: 'regtest',
      ),
    );

    await wallet.init();
    await wallet.unlock(
      config: const UtexoUnlockConfig(
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcPort: 18444,
      ),
    );
    await wallet.destroy();

    expect(hostApi.initializedNativeSignerId, 99);
    expect(hostApi.attachedNativeSignerId, isNull);
    expect(hostApi.unlockedNativeSignerId, 99);
    expect(hostApi.destroyedNativeSignerId, 99);
    expect(hostApi.createdSignerPermissivePolicy, true);
  });

  test(
    'allows strict native external signer policy when explicitly requested',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = UtexoWallet(
        config: const UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.mnemonic(
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
          ),
          network: 'regtest',
          permissivePolicy: false,
        ),
      );

      await wallet.init();

      expect(hostApi.createdSignerPermissivePolicy, false);
    },
  );

  test('normalizes utexo network for native node and signer parity', () async {
    final passwordHostApi = FakeRlnHostApi();
    final passwordWallet = UtexoWallet(
      config: const UtexoWalletConfig(
        storageDirPath: '/tmp/rgb-wallet-test',
        network: 'utexo',
      ),
      client: RlnClient(hostApi: passwordHostApi),
    );

    await passwordWallet.init(password: 'password');
    await passwordWallet.unlock(
      password: 'password',
      config: const UtexoUnlockConfig(),
    );

    expect(passwordWallet.getNetwork(), 'utexo');
    expect(passwordHostApi.createdNodeNetwork, 'signet');
    expect(passwordHostApi.unlockedIndexerUrl, 'https://esplora-api.utexo.com');
    expect(
      passwordHostApi.unlockedProxyEndpoint,
      'rpcs://rgb-proxy.utexo.com/json-rpc',
    );

    final signerHostApi = FakeRlnHostApi();
    final signerWallet = UtexoWallet(
      config: const UtexoWalletConfig(
        storageDirPath: '/tmp/rgb-wallet-test',
        network: 'utexo',
      ),
      client: RlnClient(hostApi: signerHostApi),
      signer: NativeExternalRlnSigner(
        keys: RlnKeyMaterial.mnemonic(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        ),
        network: 'utexo',
      ),
    );

    await signerWallet.init();

    expect(signerHostApi.createdNodeNetwork, 'signet');
    expect(signerHostApi.createdSignerNetwork, 'signet');
  });

  test('exports RN-style network defaults and unlock resolution', () {
    final defaults = getNetworkDefaults('utexo');
    final resolved = resolveUnlockParams('utexo', const UtexoUnlockConfig());

    expect(normalizeNativeRlnNetwork('UTEXO'), 'signet');
    expect(defaults?.indexerUrl, 'https://esplora-api.utexo.com');
    expect(defaults?.proxyEndpoint, 'rpcs://rgb-proxy.utexo.com/json-rpc');
    expect(getDefaultLspBaseUrl('utexo'), 'https://lsp-signet.utexo.com');
    expect(resolveLspBaseUrl('utexo', null), 'https://lsp-signet.utexo.com');
    expect(
      resolveLspBaseUrl('regtest', 'http://127.0.0.1:3000'),
      'http://127.0.0.1:3000',
    );
    expect(resolved.indexerUrl, 'https://esplora-api.utexo.com');
    expect(resolved.proxyEndpoint, 'rpcs://rgb-proxy.utexo.com/json-rpc');

    expect(
      () => resolveUnlockConfig('unknown-network', const UtexoUnlockConfig()),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => resolveLspBaseUrl('regtest', null),
      throwsA(isA<WalletValidationException>()),
    );
  });

  test('maps LSP APay proof and address attestation wire fields', () {
    final proofWire = <String, Object?>{
      'version': 1,
      'recipient_pubkey': 'recipient',
      'host_pubkey': 'host',
      'batch_id': 'batch',
      'hash_index': 7,
      'payment_hash': 'payment-hash',
      'batch_root': 'batch-root',
      'batch_size': 10,
      'merkle_proof': <Object?>[
        <String, Object?>{'sibling': 'sibling', 'side': 'left'},
      ],
      'batch_sig': 'signature',
      'created_at': 11,
      'expires_at': 22,
    };
    final callback = LspLnurlpCallbackWire.fromMap(<String, Object?>{
      'pr': 'lnbc1invoice',
      'routes': <Object?>[],
      'proof': proofWire,
    }).toResponse();
    final directProof = LspApayInvoiceProofWire.fromMap(proofWire).toProof();
    final address =
        LspLightningAddressByPubkeyResponse.fromWire(<String, Object?>{
          'username': 'alice',
          'domain': 'lsp.example',
          'recipient_pubkey': 'recipient',
          'address_sig': 'address-signature',
        });

    expect(callback.proof?.recipientPubkey, 'recipient');
    expect(callback.proof?.hostPubkey, 'host');
    expect(callback.proof?.batchId, 'batch');
    expect(callback.proof?.hashIndex, 7);
    expect(callback.proof?.merkleProof.single.sibling, 'sibling');
    expect(callback.proof?.merkleProof.single.side, 'left');
    expect(directProof.batchSig, 'signature');
    expect(address.recipientPubkey, 'recipient');
    expect(address.addressSig, 'address-signature');
  });

  test('rejects unlock when no backend or defaults are available', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = UtexoWallet(
      config: const UtexoWalletConfig(
        storageDirPath: '/tmp/rgb-wallet-test',
        network: 'unknown-network',
      ),
      client: RlnClient(hostApi: hostApi),
    );

    await wallet.init(password: 'password');

    await expectLater(
      wallet.unlock(password: 'password', config: const UtexoUnlockConfig()),
      throwsA(isA<WalletValidationException>()),
    );
  });

  test('reinit recreates node without re-running signer init', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.init(password: 'password');
    await wallet.shutdown();
    await wallet.reinit(
      unlockConfig: const UtexoUnlockConfig(
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcPort: 18444,
      ),
    );

    expect(hostApi.createNodeCount, 2);
    expect(hostApi.initNodeCount, 1);
    expect(hostApi.destroyNodeCount, 0);
    expect(wallet.isInitialized, true);
    expect(wallet.isUnlocked, true);
  });

  test('reinit before init is rejected', () async {
    final wallet = walletWith(FakeRlnHostApi());

    expect(() => wallet.reinit(), throwsA(isA<WalletException>()));
  });

  test('exposes RN-compatible high-level diagnostics', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    expect((await wallet.getNodeInfo()).pubkey, 'node');
    expect((await wallet.getNetworkInfo()).height, 101);
    expect(
      (await wallet.checkIndexerUrl('127.0.0.1:50002')).indexerProtocol,
      'electrum',
    );
    await expectLater(
      wallet.checkProxyEndpoint('rpc://127.0.0.1:3003/json-rpc'),
      completes,
    );
  });

  test(
    'returns constructor xpubs when provided like RN wallet params',
    () async {
      final wallet = UtexoWallet(
        config: const UtexoWalletConfig(
          storageDirPath: '/tmp/rgb-wallet-test',
          xpubVan: 'constructor-van',
          xpubCol: 'constructor-col',
          masterFingerprint: 'f23f9fd2',
        ),
        client: RlnClient(hostApi: FakeRlnHostApi()),
      );
      await wallet.init(password: 'password');

      final xpubs = await wallet.getXpub();

      expect(xpubs.vanilla, 'constructor-van');
      expect(xpubs.colored, 'constructor-col');
    },
  );

  test('creates blind and witness RGB receive invoices', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    await wallet.blindReceive(const RgbInvoiceRequest(assetId: 'asset'));
    expect(hostApi.lastRgbInvoiceWitness, false);
    expect(hostApi.lastRgbInvoiceMinConfirmations, 0);

    await wallet.witnessReceive(const RgbInvoiceRequest(assetId: 'asset'));
    expect(hostApi.lastRgbInvoiceWitness, true);
  });

  test('decodes invoice and sends RGB asset', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final response = await wallet.send(
      const RgbSendRequest(invoice: 'rgb:invoice'),
    );

    expect(response.txid, 'txid');
    expect(hostApi.lastSendRgb?['assetId'], 'asset');
    expect(hostApi.lastSendRgb?['recipientId'], 'recipient');
    expect(hostApi.lastSendRgb?['amount'], 100);
    expect(hostApi.lastSendRgb?['feeRate'], 1.5);
    expect(hostApi.lastSendRgb?['minConfirmations'], 1);
  });

  test('fails fast instead of ignoring RGB send skipSync', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    await expectLater(
      wallet.send(const RgbSendRequest(invoice: 'rgb:invoice', skipSync: true)),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );

    expect(hostApi.lastSendRgb, isNull);
  });

  test(
    'matches RN-shaped defaults and return values for utility helpers',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');

      final created = await wallet.createUtxos(num: 3);
      final feeRate = await wallet.estimateFeeRate(6);
      final btcTxid = await wallet.sendBtc(amount: 10, address: 'bcrt1dest');

      expect(created, 3);
      expect(hostApi.lastCreateUtxosUpTo, true);
      expect(hostApi.lastCreateUtxosNum, 3);
      expect(hostApi.lastCreateUtxosFeeRate, 1.5);
      expect(feeRate, 2.25);
      expect(hostApi.lastEstimateFeeBlocks, 6);
      expect(btcTxid, 'btc-txid');
      expect(hostApi.lastSendBtc?['feeRate'], 1.5);
    },
  );

  test('validates app-facing bounded numeric inputs', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    expect(
      () => wallet.createUtxos(num: 256),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.sendBtc(amount: 0, address: 'bcrt1dest'),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.blindReceive(
        const RgbInvoiceRequest(assetId: 'asset', minConfirmations: 256),
      ),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.issueAssetNia(
        ticker: 'RGB',
        name: 'RGB Asset',
        precision: 256,
        amounts: const <int>[1],
      ),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.createLightningInvoice(expirySec: -1),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.openChannel(peerPubkeyAndOptAddr: '', capacitySat: 1),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.keysend(destPubkey: 'pubkey', amtMsat: -1),
      throwsA(isA<WalletValidationException>()),
    );
  });

  test('canonicalizes native enum and status casing at model boundary', () {
    final channel = RlnChannel.fromMap(<Object?, Object?>{
      'channelId': 'channel',
      'peerPubkey': 'peer',
      'status': 'openedReady',
      'ready': true,
      'capacitySat': 1,
      'localBalanceSat': 1,
      'outboundBalanceMsat': 1,
      'inboundBalanceMsat': 1,
      'isUsable': true,
      'public': false,
    });
    final paymentResult = RlnPaymentResult.fromMap(<Object?, Object?>{
      'status': 'pending',
    });
    final payment = RlnPayment.fromMap(<Object?, Object?>{
      'paymentHash': 'hash',
      'paymentType': 'inboundHodl',
      'status': 'claimable',
      'createdAt': 1,
      'updatedAt': 2,
    });
    final transaction = RlnTransaction.fromMap(<Object?, Object?>{
      'transactionType': 'rgbSend',
      'txid': 'txid',
      'received': 0,
      'sent': 0,
      'fee': 0,
    });
    final invoiceStatus = RlnInvoiceStatus.fromMap(<Object?, Object?>{
      'status': 'succeeded',
    });

    expect(channel.status, 'OPENED_READY');
    expect(paymentResult.status, 'PENDING');
    expect(payment.paymentType, 'INBOUND_HODL');
    expect(payment.status, 'CLAIMABLE');
    expect(transaction.transactionType, 'RGB_SEND');
    expect(invoiceStatus.status, 'SUCCEEDED');
    expect(
      RlnTransaction.fromMap(<Object?, Object?>{
        'transactionType': 'RGB_SEND',
        'txid': 'txid',
        'received': 0,
        'sent': 0,
        'fee': 0,
      }).transactionType,
      'RGB_SEND',
    );
  });

  test('maps Lightning helpers to RN core-style status shapes', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    expect(
      await wallet.getLightningReceiveRequest('invoice'),
      CoreTransferStatuses.settled,
    );
    expect(
      await wallet.getLightningSendRequest('payment-hash'),
      CoreTransferStatuses.waitingConfirmations,
    );

    final payments = await wallet.listLightningPayments();
    expect(payments.payments.single.txid, 'hash-1');
    expect(payments.payments.single.status, 'SUCCEEDED');
  });

  test('unknown Lightning helper statuses map to null', () async {
    final hostApi = FakeRlnHostApi()
      ..invoiceStatus = 'UNKNOWN_INVOICE'
      ..paymentStatus = 'UNKNOWN_PAYMENT';
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    expect(await wallet.getLightningReceiveRequest('invoice'), isNull);
    expect(await wallet.getLightningSendRequest('payment-hash'), isNull);
  });

  test('listTransfers delegates empty asset id when omitted like RN', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final transfers = await wallet.listTransfers();

    expect(hostApi.lastTransferAssetId, '');
    expect(transfers.single.idx, 1);
  });

  test(
    'listTransfers falls back when current native artifact rejects empty id',
    () async {
      final hostApi = FakeRlnHostApi()..throwOnEmptyListTransfers = true;
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');

      final transfers = await wallet.listTransfers();

      expect(hostApi.lastTransferAssetId, 'asset');
      expect(transfers.single.idx, 1);
    },
  );

  test(
    'listTransfers fallback accepts Android direct InvalidRequest code',
    () async {
      final hostApi = FakeRlnHostApi()
        ..throwOnEmptyListTransfers = true
        ..emptyListTransfersErrorCode = 'InvalidRequest'
        ..emptyListTransfersErrorMessage = 'invalid request';
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');

      final transfers = await wallet.listTransfers();

      expect(hostApi.lastTransferAssetId, 'asset');
      expect(transfers.single.idx, 1);
    },
  );

  test('maps supported responses into core-style DTOs', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final balance = await wallet.getBtcBalanceCore();
    final invoice = await wallet.blindReceiveCore(
      const RgbInvoiceRequest(assetId: 'asset', amount: 100),
    );
    final decoded = await wallet.decodeRGBInvoiceCore('rgb:invoice');

    expect(balance.vanilla.settled, 1000);
    expect(invoice.batchTransferIdx, 1);
    expect(decoded.assignment.type, 'Fungible');
    expect(decoded.assignment.amount, 100);
  });

  test('marks PSBT methods as explicitly unsupported', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    expect(
      () => wallet.signPsbt('psbt'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
    expect(
      () => signPsbt('mnemonic', 'psbt'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
    expect(
      () => signPsbtFromSeed('seed', 'psbt'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
    expect(
      () => estimatePsbt('psbt'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
  });

  test('uses RN-shaped Lightning and on-chain wrapper contracts', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final lnReceive = await wallet.createLightningInvoice(
      amountSats: 2,
      asset: const LightningAsset(assetId: 'asset', amount: 5),
      expirySeconds: 30,
      paymentHash: 'payment-hash',
      minFinalCltvExpiryDelta: 144,
    );
    final lnSend = await wallet.payLightningInvoice(
      lnInvoice: 'lnbc-invoice',
      amount: 3,
      assetId: 'asset',
    );
    final onchainReceive = await wallet.onchainReceive(
      const RgbInvoiceRequest(assetId: 'asset', amount: 10),
    );
    final onchainSend = await wallet.onchainSend(
      const RgbSendRequest(invoice: 'rgb:invoice'),
    );

    expect(lnReceive.lnInvoice, 'lnbc-invoice');
    expect(hostApi.lastLnInvoice?['amtMsat'], 2000);
    expect(hostApi.lastLnInvoice?['assetId'], 'asset');
    expect(hostApi.lastLnInvoice?['assetAmount'], 5);
    expect(hostApi.lastLnInvoice?['paymentHash'], 'payment-hash');
    expect(hostApi.lastLnInvoice?['minFinalCltvExpiryDelta'], 144);
    expect(lnSend.txid, 'payment-hash');
    expect(lnSend.status, 'SUCCEEDED');
    expect(hostApi.lastSendPayment?['amtMsat'], 3000);
    expect(onchainReceive.invoice, 'rgb:invoice');
    expect(onchainSend.txid, 'txid');
    expect(onchainSend.batchTransferIdx, 2);
  });

  test('maps HODL invoices, APay, LSP config, and VSS clear fence', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final hodl = await wallet.createHodlInvoice(
      const CreateHodlInvoiceParams(
        paymentHash: 'hodl-hash',
        amtMsat: 5000,
        expirySec: 60,
        assetId: 'asset',
        assetAmount: 7,
        minFinalCltvExpiryDelta: 144,
      ),
    );
    final claim = await wallet.claimHodlInvoice('hodl-hash', 'preimage');
    final cancel = await wallet.cancelHodlInvoice('hodl-hash');
    final rawPayments = await wallet.listPaymentsRaw();
    final apay = await wallet.apayNew('host-node-id');
    final attestedApay = await wallet.apayNewWithAddress(
      'host-node-id',
      'alice',
      'lsp.example',
    );
    final lsp = await wallet.createLsp(
      const LspPeer(
        baseUrl: 'http://127.0.0.1:3000',
        peerPubkey: 'peer',
        peerHost: '127.0.0.1',
        peerPort: 9735,
      ),
    );
    await wallet.vssClearFence('password');

    expect(hodl.bolt11, 'lnbc-invoice');
    expect(hodl.paymentHash, 'hodl-hash');
    expect(hostApi.lastLnInvoice?['paymentHash'], 'hodl-hash');
    expect(hostApi.lastLnInvoice?['minFinalCltvExpiryDelta'], 144);
    expect(claim.changed, true);
    expect(cancel.changed, true);
    expect(hostApi.lastClaimHodlInvoice?['paymentPreimage'], 'preimage');
    expect(hostApi.lastCancelHodlPaymentHash, 'hodl-hash');
    expect(rawPayments.single.paymentHash, 'hash-1');
    expect(rawPayments.single.preimage, 'claim-preimage');
    expect(apay.hostNodeId, 'host-node-id');
    expect(apay.hashes.single.paymentHash, 'hash');
    expect(attestedApay.hostNodeId, 'host-node-id');
    expect(attestedApay.hashes.single.paymentHash, 'hash');
    expect(hostApi.lastApayHostNodeId, 'host-node-id');
    expect(hostApi.lastApayAddressUsername, 'alice');
    expect(hostApi.lastApayAddressDomain, 'lsp.example');
    expect(lsp.peer.peerPubkey, 'peer');
    expect(wallet.getLspConfig().baseUrl, isNull);
    expect(hostApi.lastVssClearFencePassword, 'password');
  });

  test(
    'LSP APay address registration uses one attested batch and refills',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');
      final lspClient = FakeLspClient();
      final lsp = UtexoLsp(
        wallet: wallet,
        peer: const LspPeer(
          baseUrl: 'http://127.0.0.1:3000',
          peerPubkey: 'lsp-peer',
          peerHost: '127.0.0.1',
          peerPort: 9735,
        ),
        httpClient: lspClient,
      );

      final address = await lsp.enableLightningAddress();

      expect(address.username, 'alice');
      expect(address.domain, 'lsp.example');
      expect(address.address, 'alice@lsp.example');
      expect(address.unusedHashes, 2);
      expect(address.nextIndexExpected, 1);
      expect(address.refillBatchSize, 10);
      expect(hostApi.apayNewCalls, 0);
      expect(hostApi.apayNewWithAddressCalls, 1);
      expect(hostApi.lastApayHostNodeId, 'lsp-peer');
      expect(hostApi.lastApayAddressUsername, 'alice');
      expect(hostApi.lastApayAddressDomain, 'lsp.example');
      expect(lspClient.getInfoCalls, 1);
      expect(lspClient.lightningAddressLookups, 1);
      expect(lspClient.lastLightningAddressPubkey, 'node');

      final refill = await lsp.refillHashPool();

      expect(refill.hostNodeId, 'lsp-peer');
      expect(hostApi.apayNewCalls, 0);
      expect(hostApi.apayNewWithAddressCalls, 2);
      expect(lspClient.getInfoCalls, 2);
      expect(lspClient.lightningAddressLookups, 2);
    },
  );

  test(
    'createLsp before init wires virtual channels into node creation',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      server.listen((request) {
        requests.add(request.uri.path);
        if (request.uri.path == '/get_info') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, Object?>{
              'pubkey': 'lsp-peer',
              'num_channels': 1,
              'num_usable_channels': 1,
            }),
          );
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        request.response.close();
      });

      try {
        final baseUrl = 'http://${server.address.host}:${server.port}';
        final hostApi = FakeRlnHostApi();
        final wallet = UtexoWallet(
          config: UtexoWalletConfig(
            storageDirPath: '/tmp/rgb-wallet-test',
            lspBaseUrl: baseUrl,
            lspBearerToken: 'token',
          ),
          client: RlnClient(hostApi: hostApi),
        );

        final lsp = await wallet.createLsp();
        await wallet.init(password: 'password');

        expect(lsp.peer.baseUrl, baseUrl);
        expect(lsp.peer.peerPubkey, 'lsp-peer');
        expect(lsp.peer.peerHost, server.address.host);
        expect(requests, contains('/get_info'));
        expect(hostApi.createdEnableVirtualChannelsV0, true);
        expect(hostApi.createdVirtualPeerPubkeys, <String>['lsp-peer']);
        expect(hostApi.createdLspBaseUrl, baseUrl);
        expect(hostApi.createdLspBearerToken, 'token');
        expect(wallet.createLsp, throwsA(isA<WalletException>()));
      } finally {
        await server.close(force: true);
      }
    },
  );

  test(
    'utexo network default LSP URL is passed to native node creation',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = UtexoWallet(
        config: const UtexoWalletConfig(
          storageDirPath: '/tmp/rgb-wallet-test',
          network: 'utexo',
        ),
        client: RlnClient(hostApi: hostApi),
      );

      await wallet.init(password: 'password');

      expect(hostApi.createdLspBaseUrl, 'https://lsp-signet.utexo.com');
      expect(hostApi.createdEnableVirtualChannelsV0, isNull);
      expect(hostApi.createdVirtualPeerPubkeys, isNull);
    },
  );

  test('validates APay address registration inputs', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    expect(
      () => wallet.apayNewWithAddress('', 'alice', 'lsp.example'),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.apayNewWithAddress('host-node-id', '', 'lsp.example'),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.apayNewWithAddress('host-node-id', 'alice', ''),
      throwsA(isA<WalletValidationException>()),
    );
  });

  test(
    'LSP channel wait requires matching peer and exposes disposal',
    () async {
      final hostApi = FakeRlnHostApi()
        ..channelRows = <Map<Object?, Object?>>[
          <Object?, Object?>{
            'channelId': 'wrong-peer-channel',
            'peerPubkey': 'other-peer',
            'status': 'Opened',
            'ready': true,
            'capacitySat': 100000,
            'localBalanceSat': 90000,
            'outboundBalanceMsat': 80000,
            'inboundBalanceMsat': 70000,
            'isUsable': true,
            'public': false,
            'assetId': 'asset',
          },
        ];
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');

      final lspClient = FakeLspClient();
      final lsp = UtexoLsp(
        wallet: wallet,
        peer: const LspPeer(
          baseUrl: 'http://127.0.0.1:3000',
          peerPubkey: 'lsp-peer',
          peerHost: '127.0.0.1',
          peerPort: 9735,
        ),
        httpClient: lspClient,
      );

      await expectLater(
        lsp.waitForChannel(
          'asset',
          options: const WaitOptions(timeoutMs: 1, pollIntervalMs: 1),
        ),
        throwsA(isA<LspChannelTimeoutException>()),
      );

      hostApi.channelRows = <Map<Object?, Object?>>[
        ...hostApi.channelRows!,
        <Object?, Object?>{
          'channelId': 'lsp-channel',
          'peerPubkey': 'lsp-peer',
          'status': 'Opened',
          'ready': true,
          'capacitySat': 100000,
          'localBalanceSat': 90000,
          'outboundBalanceMsat': 80000,
          'inboundBalanceMsat': 70000,
          'isUsable': true,
          'public': false,
          'assetId': 'asset',
        },
      ];

      final ready = await lsp.waitForChannel(
        'asset',
        options: const WaitOptions(timeoutMs: 50, pollIntervalMs: 1),
      );
      expect(ready.channelId, 'lsp-channel');
      expect(ready.peerPubkey, 'lsp-peer');

      lsp.close();
      expect(lspClient.closed, true);
    },
  );

  test('LSP outbound liquidity wait throws on timeout', () async {
    final hostApi = FakeRlnHostApi()
      ..channelRows = <Map<Object?, Object?>>[
        <Object?, Object?>{
          'channelId': 'lsp-channel',
          'peerPubkey': 'lsp-peer',
          'status': 'Opened',
          'ready': true,
          'capacitySat': 100000,
          'localBalanceSat': 90000,
          'outboundBalanceMsat': 10,
          'inboundBalanceMsat': 70000,
          'isUsable': true,
          'public': false,
          'assetId': 'asset',
        },
      ];
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final lsp = UtexoLsp(
      wallet: wallet,
      peer: const LspPeer(
        baseUrl: 'http://127.0.0.1:3000',
        peerPubkey: 'lsp-peer',
        peerHost: '127.0.0.1',
        peerPort: 9735,
      ),
      httpClient: FakeLspClient(),
    );

    var pollCount = 0;
    await expectLater(
      lsp.waitForOutboundLiquidity(
        100,
        options: WaitOptions(
          timeoutMs: 20,
          pollIntervalMs: 1,
          onEachPoll: () {
            pollCount += 1;
          },
        ),
      ),
      throwsA(isA<LspLiquidityTimeoutException>()),
    );
    expect(pollCount, greaterThan(0));
  });

  test('covers wallet lifecycle aliases', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.initialize(password: 'password');
    expect(wallet.nodeId, 7);
    expect(hostApi.initNodeCount, 1);

    await wallet.dispose();
    expect(hostApi.destroyNodeCount, 1);
    expect(wallet.isInitialized, false);
  });

  test('maps Bitcoin list methods and core DTO aliases', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final unspents = await wallet.listUnspents(skipSync: true);
    final coreUnspents = await wallet.listUnspentsCore(skipSync: true);
    final transactions = await wallet.listTransactions(skipSync: true);
    final coreTransactions = await wallet.listTransactionsCore(skipSync: true);

    expect(hostApi.lastListUnspentsSkipSync, true);
    expect(unspents.single.utxo.outpoint, 'txid:0');
    expect(coreUnspents.single.utxo.outpoint.txid, 'txid');
    expect(coreUnspents.single.utxo.outpoint.vout, 0);
    expect(transactions.single.txid, 'btc-txid');
    expect(hostApi.lastListTransactionsSkipSync, true);
    expect(coreTransactions.single.transactionType, 'User');
  });

  test('maps RGB asset balance and issuance methods', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final balance = await wallet.getAssetBalance('asset');
    final coreBalance = await wallet.getAssetBalanceCore('asset');
    final nia = await wallet.issueAssetNia(
      ticker: 'RGB',
      name: 'RGB Asset',
      precision: 0,
      amounts: const <int>[1000],
    );
    final cfa = await wallet.issueAssetCfa(
      name: 'Collectible',
      details: 'details',
      precision: 0,
      amounts: const <int>[1],
      fileDigest: 'file-digest',
    );
    final ifa = await wallet.issueAssetIfa(
      ticker: 'IFA',
      name: 'Inflatable',
      precision: 0,
      amounts: const <int>[1000],
      inflationAmounts: const <int>[1000],
      rejectListUrl: 'https://example.com/reject-list',
    );
    final uda = await wallet.issueAssetUda(
      ticker: 'UDA',
      name: 'Unique',
      details: 'details',
      precision: 0,
      mediaFileDigest: 'media-digest',
      attachmentsFileDigests: const <String>['attachment-digest'],
    );

    expect(hostApi.lastAssetBalanceId, 'asset');
    expect(balance.offchainInbound, 3);
    expect(coreBalance.offchainOutbound, 2);
    expect(nia.ticker, 'RGB');
    expect(hostApi.lastIssueAssetNia?['amounts'], const <int>[1000]);
    expect(cfa.assetId, 'cfa');
    expect(hostApi.lastIssueAssetCfa?['fileDigest'], 'file-digest');
    expect(ifa.maxSupply, 2000);
    expect(hostApi.lastIssueAssetIfa?['rejectListUrl'], contains('reject'));
    expect(uda.token?.name, 'Unique');
    expect(hostApi.lastIssueAssetUda?['attachmentsFileDigests'], const <String>[
      'attachment-digest',
    ]);
  });

  test('maps Lightning, peer, and channel methods', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final decoded = await wallet.decodeLnInvoice('lnbc-invoice');
    final peers = await wallet.listPeers();
    final channels = await wallet.listChannels();
    await wallet.connectPeer('peer@127.0.0.1:9735');
    await wallet.disconnectPeer('peer');
    final opened = await wallet.openChannel(
      peerPubkeyAndOptAddr: 'peer@127.0.0.1:9735',
      capacitySat: 100000,
      assetId: 'asset',
      assetAmount: 100,
    );
    await wallet.closeChannel(
      channelId: 'channel-id',
      peerPubkey: 'peer',
      force: true,
    );
    final channelId = await wallet.getChannelId('temporary-channel-id');
    final keysend = await wallet.keysend(
      destPubkey: 'peer',
      amtMsat: 1000,
      assetId: 'asset',
      assetAmount: 10,
    );

    expect(hostApi.lastDecodeLnInvoice, 'lnbc-invoice');
    expect(decoded.paymentHash, 'payment-hash');
    expect(peers.single.pubkey, 'peer');
    expect(channels.single.channelId, 'channel-id');
    expect(hostApi.lastConnectedPeer, 'peer@127.0.0.1:9735');
    expect(hostApi.lastDisconnectedPeerPubkey, 'peer');
    expect(opened.temporaryChannelId, 'temporary-channel-id');
    expect(hostApi.lastOpenChannel?['assetAmount'], 100);
    expect(hostApi.lastCloseChannel?['force'], true);
    expect(hostApi.lastTemporaryChannelId, 'temporary-channel-id');
    expect(channelId, 'channel-id');
    expect(keysend.paymentHash, 'keysend-hash');
    expect(hostApi.lastKeysend?['assetAmount'], 10);
  });

  test('listOnchainTransfers delegates to RGB transfer listing', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final transfers = await wallet.listOnchainTransfers(assetId: 'asset');

    expect(hostApi.lastTransferAssetId, 'asset');
    expect(transfers.single.idx, 1);
  });

  test('marks RN service and bridge-only wallet methods unsupported', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    void expectUnsupported(Object? Function() action) {
      expect(action, throwsA(isA<UnsupportedWalletFeatureException>()));
    }

    expectUnsupported(wallet.rotateVanillaAddress);
    expectUnsupported(wallet.rotateColoredAddress);
    expectUnsupported(() => wallet.inflateBegin(<String, Object?>{}));
    expectUnsupported(() => wallet.inflateEnd(<String, Object?>{}));
    expectUnsupported(() => wallet.inflate(<String, Object?>{}));
    expectUnsupported(() => wallet.estimateFee('psbt'));
    expectUnsupported(
      () => wallet.payLightningInvoiceBegin(<String, Object?>{}),
    );
    expectUnsupported(() => wallet.payLightningInvoiceEnd(<String, Object?>{}));
    expectUnsupported(
      () => wallet.getLightningSendFeeEstimate(<String, Object?>{}),
    );
    expectUnsupported(() => wallet.onchainSendBegin(<String, Object?>{}));
    expectUnsupported(() => wallet.onchainSendEnd(<String, Object?>{}));
    expectUnsupported(() => wallet.getOnchainSendStatus('invoice'));
    expectUnsupported(() => wallet.goOnline('127.0.0.1:50002'));
    expectUnsupported(() => wallet.createUtxosBegin(<String, Object?>{}));
    expectUnsupported(() => wallet.createUtxosEnd(<String, Object?>{}));
    expectUnsupported(() => wallet.sendBegin(<String, Object?>{}));
    expectUnsupported(() => wallet.sendEnd(<String, Object?>{}));
    expectUnsupported(() => wallet.sendBtcBegin(<String, Object?>{}));
    expectUnsupported(() => wallet.sendBtcEnd(<String, Object?>{}));
    expectUnsupported(() => wallet.signMessage('message'));
    expectUnsupported(() => wallet.verifyMessage('message', 'signature'));
    expectUnsupported(() => wallet.configureVssBackup(<String, Object?>{}));
    expectUnsupported(wallet.disableVssAutoBackup);
    expectUnsupported(() => wallet.vssBackup(<String, Object?>{}));
    expectUnsupported(() => wallet.vssBackupInfo(<String, Object?>{}));
  });

  test('validates native external signer seed material length', () {
    expect(
      () => RlnKeyMaterial.seedBytes(
        Uint8List.fromList(<int>[1, 2, 3]),
      ).toSeedHex32(),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => RlnKeyMaterial.seedHex('abcd').toSeedHex32(),
      throwsA(isA<WalletValidationException>()),
    );
  });

  test('derives RN-core compatible BIP86 wallet keys', () async {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    final keys = await deriveKeysFromMnemonic('regtest', mnemonic);
    final account = await accountXpubsFromMnemonic('regtest', mnemonic);
    final xpriv = await getXprivFromMnemonic('regtest', mnemonic);
    final xpub = await getXpubFromXpriv(xpriv, 'regtest');
    final derivedFromXpriv = await deriveKeysFromXpriv('regtest', xpriv);

    expect(
      keys.xpub,
      'tpubD6NzVbkrYhZ4XYa9MoLt4BiMZ4gkt2faZ4BcmKu2a9te4LDpQmvEz2L2yDERivHxFPnxXXhqDRkUNnQCpZggCyEZLBktV7VaSmwayqMJy1s',
    );
    expect(
      keys.accountXpubVanilla,
      'tpubDDfvzhdVV4unsoKt5aE6dcsNsfeWbTgmLZPi8LQDYU2xixrYemMfWJ3BaVneH3u7DBQePdTwhpybaKRU95pi6PMUtLPBJLVQRpzEnjfjZzX',
    );
    expect(
      keys.accountXpubColored,
      'tpubDCtpoJs6YJcjLnr9gq6jYriYNMuWEu8mSDvEQU5st3ZkJbFqqzwpHUiPvxqD2366ciFAfpehk1k2d7Tyk7AJEr8uZva7KfnX4RpsiVSoEcZ',
    );
    expect(keys.masterFingerprint, '73c5da0a');
    expect(keys.xpriv, xpriv);
    expect(xpub, keys.xpub);
    expect(derivedFromXpriv.accountXpubColored, keys.accountXpubColored);
    expect(account.account_xpub_vanilla, keys.accountXpubVanilla);
    expect(account.account_xpub_colored, keys.accountXpubColored);
  });

  test('matches RN-core seed derivation and utility behavior', () async {
    const seedHex =
        '000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f';

    final keys = await deriveKeysFromSeed('testnet', seedHex);

    expect(keys.mnemonic, '');
    expect(
      keys.xpub,
      'tpubD6NzVbkrYhZ4XvAFWdRioWkez63m2w589L9wVoTb2EntxoaJzLimYXKhefzTu58GuDirYSw542zHmAFwrtkRUCurw4HqG3BUkJo5eYKuJ8m',
    );
    expect(
      keys.accountXpubVanilla,
      'tpubDDrJBxXn5KStr5AC7o3VnnaYS86K6XFEPhYcW2hLmmhx8yfEXhn35CjvPUeyUAQfAB3cLEebUxqauCk7JFweeFmRcPCk5F2d8x8xitQR9do',
    );
    expect(
      keys.accountXpubColored,
      'tpubDCL4izsXaTLEd1cH2njbTDvpt7vQtDSeUzic8FPRmT7Fmkifje9frT9jGoYmm1XNXS3dLeeBsZqoyLWLCTN5g2JgPoQUef2CjEthdX9Ewfz',
    );
    expect(keys.masterFingerprint, '91790c21');
    expect(normalizeNetwork(0), 'mainnet');
    expect(normalizeNetwork(1), 'testnet');
    expect(normalizeNetwork(3), 'regtest');
    expect(accountDerivationPath('regtest', false), "m/86'/1'/0'");
    expect(accountDerivationPath('regtest', true), "m/86'/827167'/0'");
    expect(toUnitsNumber('123.4567', 2), 12345);
    expect(fromUnitsNumber(123456000, 6), 123.456);
  });

  test('signs and verifies RN-core compatible Schnorr messages', () async {
    const seedHex =
        '000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f';
    const rnSignature =
        'VquHRnAyfYngMXhpTIvaZTjFDnhp0tQXo4FaMXPaFTUyZDNgNVlQIu4Uhy6XgG2pZEdrUyJG9BNLohmfUooT8g==';
    final keys = await deriveKeysFromSeed('regtest', seedHex);

    final signature = await signMessage(
      const SignMessageParams(message: 'hello', seed: seedHex),
    );

    expect(
      await verifyMessage(
        VerifyMessageParams(
          message: 'hello',
          signature: signature,
          accountXpub: keys.accountXpubVanilla,
        ),
      ),
      isTrue,
    );
    expect(
      await verifyMessage(
        VerifyMessageParams(
          message: 'hello',
          signature: rnSignature,
          accountXpub: keys.accountXpubVanilla,
        ),
      ),
      isTrue,
    );
  });

  test('exports RN-core UTEXO network and bridge helpers', () {
    final destination = getDestinationAsset(
      'mainnet',
      'mainnetLightning',
      testnetPreset.networkIdMap['mainnet']!.assets.first.assetId,
    );

    expect(utexoNetworkMap['mainnet'], 'testnet');
    expect(getUtxoNetworkConfig('mainnet').networkMap['mainnet'], 'mainnet');
    expect(destination?.tokenName, 'tUSD');
    expect(decodeBridgeInvoice('0x7267623a696e766f696365'), 'rgb:invoice');
    expect(encodeTransferStatus('Finished'), 'F'.codeUnitAt(0));
    expect(getNetworkDefaults('signet')?.proxyEndpoint, contains('utexo.com'));
  });

  test('delegates backup to the native parity bridge', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    final backup = await wallet.createBackup(
      backupPath: '/tmp/backup',
      password: 'password',
    );

    expect(backup.message, 'Backup created successfully');
    expect(backup.backupPath, '/tmp/backup');
    expect(hostApi.lastBackup?['backupPath'], '/tmp/backup');
    expect(hostApi.lastBackup?['password'], 'password');
  });
}
