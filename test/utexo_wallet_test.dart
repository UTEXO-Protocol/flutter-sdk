import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

class FakeRlnHostApi extends RlnHostApi {
  int? createdNodeId;
  int createNodeCount = 0;
  int? createdSignerId;
  int createSignerCount = 0;
  final List<int> createdSignerIds = <int>[];
  final List<int> destroyedNativeSignerIds = <int>[];
  String? createdNodeNetwork;
  String? createdSignerNetwork;
  bool? createdSignerPermissivePolicy;
  String? createdSignerStorageDirPath;
  bool? createdReuseAddresses;
  bool? createdEnableVirtualChannelsV0;
  List<String>? createdVirtualPeerPubkeys;
  String? createdLspBaseUrl;
  String? createdLspBearerToken;
  String? initializedPassword;
  int initNodeCount = 0;
  int unlockNodeCount = 0;
  int? initializedNativeSignerId;
  int? attachedNativeSignerId;
  int? unlockedNativeSignerId;
  int? destroyedNativeSignerId;
  bool throwOnNativeSignerInit = false;
  bool throwOnNativeSignerAttach = false;
  bool throwOnNativeSignerDestroy = false;
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
  int rgbInvoiceCalls = 0;
  int addressCalls = 0;
  int networkInfoCalls = 0;
  int listAssetsCalls = 0;
  int? lastRgbInvoiceMinConfirmations;
  String? lastRgbInvoiceAssignmentKind;
  Map<Object?, Object?>? lastSendRgb;
  Map<Object?, Object?>? lastSendBtc;
  Map<Object?, Object?>? lastLnInvoice;
  Map<Object?, Object?>? lastClaimHodlInvoice;
  String? lastCancelHodlPaymentHash;
  Object? connectPeerError;
  Object? claimHodlInvoiceError;
  Object? apayNewError;
  Object? apayNewWithAddressError;
  Object? vssClearFenceError;
  Object? vssBackupError;
  String? lastApayHostNodeId;
  String? lastApayAddressUsername;
  String? lastApayAddressDomain;
  int apayNewCalls = 0;
  int apayNewWithAddressCalls = 0;
  String? lastVssClearFencePassword;
  int vssBackupVersion = 42;
  String? lastTransactionTxid;
  String? lastTransferTxid;
  Map<Object?, Object?>? lastInflate;
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
  List<Map<Object?, Object?>>? paymentRows;

  RlnWireResponse _wireMap(Map<Object?, Object?> map) {
    return RlnWireResponse(json: jsonEncode(map));
  }

  List<RlnWireResponse> _wireList(List<Map<Object?, Object?>> rows) {
    return rows.map(_wireMap).toList(growable: false);
  }

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
    bool reuseAddresses,
  ) async {
    createNodeCount += 1;
    createdNodeId = 6 + createNodeCount;
    createdNodeNetwork = network;
    createdEnableVirtualChannelsV0 = enableVirtualChannelsV0;
    createdVirtualPeerPubkeys = virtualPeerPubkeys;
    createdLspBaseUrl = lspBaseUrl;
    createdLspBearerToken = lspBearerToken;
    createdReuseAddresses = reuseAddresses;
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
    String? storageDirPath,
  ) async {
    expect(seedHex.length, 64);
    createSignerCount += 1;
    createdSignerNetwork = network;
    createdSignerPermissivePolicy = permissivePolicy;
    createdSignerStorageDirPath = storageDirPath;
    createdSignerId = 98 + createSignerCount;
    createdSignerIds.add(createdSignerId!);
    return createdSignerId!;
  }

  @override
  Future<void> rlnInitNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
  ) async {
    initializedNativeSignerId = signerId;
    if (throwOnNativeSignerInit) {
      throw StateError('native signer init failed');
    }
  }

  @override
  Future<void> rlnAttachNativeExternalSigner(int nodeId, int signerId) async {
    attachedNativeSignerId = signerId;
    if (throwOnNativeSignerAttach) {
      throw StateError('native signer attach failed');
    }
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
    destroyedNativeSignerIds.add(signerId);
    if (throwOnNativeSignerDestroy) {
      throw StateError('native signer destroy failed');
    }
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
    unlockNodeCount += 1;
    unlockedHost = bitcoindRpcHost;
    unlockedIndexerUrl = indexerUrl;
    unlockedProxyEndpoint = proxyEndpoint;
  }

  @override
  Future<RlnWireResponse> rlnAddress(int nodeId) async {
    addressCalls += 1;
    return _wireMap(<Object?, Object?>{'address': 'bcrt1address'});
  }

  @override
  Future<RlnWireResponse> rlnRotateAddress(int nodeId) async {
    return _wireMap(<Object?, Object?>{'address': 'bcrt1rotated'});
  }

  @override
  Future<RlnWireResponse> rlnSignMessage(int nodeId, String message) async {
    return _wireMap(<Object?, Object?>{'signedMessage': 'signed:$message'});
  }

  @override
  Future<RlnWireResponse> rlnVerifyMessage(
    int nodeId,
    String message,
    String signature,
  ) async {
    return _wireMap(<Object?, Object?>{
      'valid': signature == 'signed:$message',
    });
  }

  @override
  Future<RlnWireResponse> rlnBtcBalance(int nodeId, bool skipSync) async {
    return _wireMap(<Object?, Object?>{
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
    });
  }

  @override
  Future<RlnWireResponse> rlnNodeInfo(int nodeId) async {
    return _wireMap(<Object?, Object?>{
      'pubkey': 'node',
      'numChannels': 0,
      'numUsableChannels': 0,
      'localBalanceSat': 0,
      'numPeers': 0,
      'accountXpubVanilla': 'xpub-van',
      'accountXpubColored': 'xpub-col',
    });
  }

  @override
  Future<RlnWireResponse> rlnNetworkInfo(int nodeId) async {
    networkInfoCalls += 1;
    return _wireMap(<Object?, Object?>{'network': 'regtest', 'height': 101});
  }

  @override
  Future<RlnWireResponse> rlnCheckIndexerUrl(
    int nodeId,
    String indexerUrl,
  ) async {
    return _wireMap(<Object?, Object?>{'indexerProtocol': 'electrum'});
  }

  @override
  Future<void> rlnCheckProxyEndpoint(int nodeId, String proxyEndpoint) async {}

  @override
  Future<RlnWireResponse> rlnRgbInvoice(
    int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness,
    String? assignmentKind,
  ) async {
    rgbInvoiceCalls += 1;
    lastRgbInvoiceWitness = witness;
    lastRgbInvoiceMinConfirmations = minConfirmations;
    lastRgbInvoiceAssignmentKind = assignmentKind;
    return _wireMap(<Object?, Object?>{
      'invoice': 'rgb:invoice',
      'recipientId': 'recipient',
      'expirationTimestamp': 123456,
      'batchTransferIdx': 1,
    });
  }

  @override
  Future<RlnWireResponse> rlnDecodeRgbInvoice(
    int nodeId,
    String invoice,
  ) async {
    return _wireMap(<Object?, Object?>{
      'recipientId': 'recipient',
      'recipientType': 'Blind',
      'assetId': 'asset',
      'assignment': '100',
      'network': 'regtest',
      'transportEndpoints': <String>['rpc://proxy/json-rpc'],
    });
  }

  @override
  Future<RlnWireResponse> rlnListAssets(
    int nodeId,
    List<String> filterAssetSchemas,
  ) async {
    listAssetsCalls += 1;
    return _wireMap(<Object?, Object?>{
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
    });
  }

  @override
  Future<RlnWireResponse> rlnAssetBalance(int nodeId, String assetId) async {
    lastAssetBalanceId = assetId;
    return _wireMap(_assetBalance());
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetNia(
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
    return _wireMap(_niaAsset(ticker: ticker, name: name));
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetCfa(
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
    return _wireMap(_cfaAsset());
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetIfa(
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
    return _wireMap(_ifaAsset());
  }

  @override
  Future<RlnWireResponse> rlnInflate(
    int nodeId,
    String assetId,
    List<int> inflationAmounts,
    double feeRate,
    int minConfirmations,
  ) async {
    lastInflate = <Object?, Object?>{
      'assetId': assetId,
      'inflationAmounts': inflationAmounts,
      'feeRate': feeRate,
      'minConfirmations': minConfirmations,
    };
    return _wireMap(<Object?, Object?>{'txid': 'inflate-txid'});
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetUda(
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
    return _wireMap(_udaAsset());
  }

  @override
  Future<RlnWireResponse> rlnSendRgb(
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
    return _wireMap(<Object?, Object?>{'txid': 'txid', 'batchTransferIdx': 2});
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
  Future<RlnWireResponse> rlnSendBtc(
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
    return _wireMap(<Object?, Object?>{'txid': 'btc-txid'});
  }

  @override
  Future<List<RlnWireResponse>> rlnListUnspents(
    int nodeId,
    bool skipSync,
  ) async {
    lastListUnspentsSkipSync = skipSync;
    return _wireList(<Map<Object?, Object?>>[
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
    ]);
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransactions(
    int nodeId,
    bool skipSync,
  ) async {
    lastListTransactionsSkipSync = skipSync;
    return _wireList(<Map<Object?, Object?>>[
      <Object?, Object?>{
        'transactionType': 'SEND_BTC',
        'txid': 'btc-txid',
        'received': 1000,
        'sent': 100,
        'fee': 10,
        'confirmationTime': <Object?, Object?>{'height': 101, 'timestamp': 2},
      },
    ]);
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransactionsByTxid(
    int nodeId,
    String txid,
    bool skipSync,
  ) async {
    lastTransactionTxid = txid;
    return rlnListTransactions(nodeId, skipSync);
  }

  @override
  Future<RlnWireResponse> rlnEstimateFee(int nodeId, int blocks) async {
    lastEstimateFeeBlocks = blocks;
    return _wireMap(<Object?, Object?>{'feeRate': 2.25});
  }

  @override
  Future<void> rlnBackup(int nodeId, String backupPath, String password) async {
    lastBackup = <Object?, Object?>{
      'backupPath': backupPath,
      'password': password,
    };
  }

  @override
  Future<RlnWireResponse> rlnLnInvoice(
    int nodeId,
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  ) async {
    lastLnInvoice = <Object?, Object?>{
      'amtMsat': amtMsat,
      'expirySec': expirySec,
      'assetId': assetId,
      'assetAmount': assetAmount,
      'paymentHash': paymentHash,
      'minFinalCltvExpiryDelta': minFinalCltvExpiryDelta,
      'descriptionHash': descriptionHash,
    };
    return _wireMap(<Object?, Object?>{'invoice': 'lnbc-invoice'});
  }

  @override
  Future<RlnWireResponse> rlnClaimHodlInvoice(
    int nodeId,
    String paymentHash,
    String paymentPreimage,
  ) async {
    lastClaimHodlInvoice = <Object?, Object?>{
      'paymentHash': paymentHash,
      'paymentPreimage': paymentPreimage,
    };
    final error = claimHodlInvoiceError;
    if (error != null) throw error;
    return _wireMap(<Object?, Object?>{'changed': true});
  }

  @override
  Future<void> rlnCancelHodlInvoice(int nodeId, String paymentHash) async {
    lastCancelHodlPaymentHash = paymentHash;
  }

  @override
  Future<RlnWireResponse> rlnApayNew(int nodeId, String hostNodeId) async {
    final error = apayNewError;
    if (error != null) throw error;
    apayNewCalls += 1;
    lastApayHostNodeId = hostNodeId;
    return _wireMap(<Object?, Object?>{
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
    });
  }

  @override
  Future<RlnWireResponse> rlnApayNewWithAddress(
    int nodeId,
    String hostNodeId,
    String username,
    String domain,
  ) async {
    final error = apayNewWithAddressError;
    if (error != null) throw error;
    apayNewWithAddressCalls += 1;
    lastApayHostNodeId = hostNodeId;
    lastApayAddressUsername = username;
    lastApayAddressDomain = domain;
    return _wireMap(<Object?, Object?>{
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
    });
  }

  @override
  Future<RlnWireResponse> rlnDecodeLnInvoice(int nodeId, String invoice) async {
    lastDecodeLnInvoice = invoice;
    return _wireMap(<Object?, Object?>{
      'amtMsat': 2000,
      'expirySec': 3600,
      'timestamp': 1,
      'assetId': 'asset',
      'assetAmount': 5,
      'paymentHash': 'payment-hash',
      'paymentSecret': 'payment-secret',
      'payeePubkey': 'payee',
      'network': 'regtest',
    });
  }

  @override
  Future<RlnWireResponse> rlnSendPayment(
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
    return _wireMap(<Object?, Object?>{
      'paymentHash': 'payment-hash',
      'paymentId': 'payment-id',
      'status': 'SUCCEEDED',
    });
  }

  @override
  Future<RlnWireResponse> rlnInvoiceStatus(int nodeId, String invoice) async {
    return _wireMap(<Object?, Object?>{'status': invoiceStatus});
  }

  @override
  Future<RlnWireResponse> rlnGetPayment(int nodeId, String paymentHash) async {
    return _wireMap(<Object?, Object?>{
      'paymentHash': paymentHash,
      'paymentType': 'OUTBOUND',
      'status': paymentStatus,
      'createdAt': 1,
      'updatedAt': 2,
    });
  }

  @override
  Future<List<RlnWireResponse>> rlnListPayments(int nodeId) async {
    final rows = paymentRows;
    if (rows != null) return _wireList(rows);
    return _wireList(<Map<Object?, Object?>>[
      <Object?, Object?>{
        'paymentHash': 'hash-1',
        'paymentType': 'OUTBOUND',
        'status': 'SUCCEEDED',
        'paymentPreimage': 'claim-preimage',
        'createdAt': 1,
        'updatedAt': 2,
      },
    ]);
  }

  @override
  Future<List<RlnWireResponse>> rlnListPeers(int nodeId) async {
    return _wireList(<Map<Object?, Object?>>[
      <Object?, Object?>{'pubkey': 'peer'},
    ]);
  }

  @override
  Future<void> rlnConnectPeer(int nodeId, String peerPubkeyAndAddr) async {
    final error = connectPeerError;
    if (error != null) throw error;
    lastConnectedPeer = peerPubkeyAndAddr;
  }

  @override
  Future<void> rlnDisconnectPeer(int nodeId, String peerPubkey) async {
    lastDisconnectedPeerPubkey = peerPubkey;
  }

  @override
  Future<List<RlnWireResponse>> rlnListChannels(int nodeId) async {
    return _wireList(
      channelRows ??
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
          ],
    );
  }

  @override
  Future<RlnWireResponse> rlnOpenChannel(
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
    return _wireMap(<Object?, Object?>{
      'temporaryChannelId': 'temporary-channel-id',
    });
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
  Future<RlnWireResponse> rlnKeysend(
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
    return _wireMap(<Object?, Object?>{
      'paymentHash': 'keysend-hash',
      'paymentId': 'keysend-id',
      'status': 'SUCCEEDED',
    });
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransfers(
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
    return _wireList(<Map<Object?, Object?>>[
      <Object?, Object?>{
        'idx': 1,
        'createdAt': 2,
        'updatedAt': 3,
        'status': 'Settled',
        'kind': 'Send',
        'assignments': <String>['Fungible(10)'],
      },
    ]);
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransfersByTxid(
    int nodeId,
    String txid,
  ) async {
    lastTransferTxid = txid;
    return rlnListTransfers(nodeId, 'asset');
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
    final error = vssClearFenceError;
    if (error != null) throw error;
    lastVssClearFencePassword = password;
  }

  @override
  Future<int> rlnVssBackup(int nodeId) async {
    final error = vssBackupError;
    if (error != null) throw error;
    return vssBackupVersion;
  }
}

class FakeLspClient extends IUtexoLspClient {
  bool closed = false;
  int getInfoCalls = 0;
  int resolveAddressCalls = 0;
  int resolveExternalAddressCalls = 0;
  int lightningAddressLookups = 0;
  String? lastLightningAddressPubkey;
  Object? resolveAddressError;
  Object? getInfoError;
  Object? onchainSendError;
  Object? lightningReceiveError;

  @override
  void close() {
    closed = true;
  }

  @override
  Future<LspGetInfoResponse> getInfo() async {
    getInfoCalls += 1;
    final error = getInfoError;
    if (error != null) throw error;
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
    resolveAddressCalls += 1;
    final error = resolveAddressError;
    if (error != null) throw error;
    return LspLnurlpCallbackResponse(pr: 'lnbc1invoice', routes: []);
  }

  @override
  Future<LspLnurlpCallbackResponse> lnurlCallback(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return LspLnurlpCallbackResponse(pr: 'lnbc1invoice', routes: []);
  }

  @override
  Future<LspLnurlpCallbackResponse> resolveExternalAddress(
    String domain,
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    resolveExternalAddressCalls += 1;
    return LspLnurlpCallbackResponse(pr: 'lnbc1external', routes: []);
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
    final error = onchainSendError;
    if (error != null) throw error;
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
    final error = lightningReceiveError;
    if (error != null) throw error;
    return const LspLightningReceiveResponse(
      lnInvoice: 'lnbc1invoice',
      rgbInvoice: 'rgb:invoice',
      mappingId: 'mapping',
    );
  }
}

class _StaticHttpClient extends http.BaseClient {
  _StaticHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

void main() {
  UtexoWallet walletWith(FakeRlnHostApi hostApi) {
    return UtexoWallet(
      config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
      client: RlnClient(hostApi: hostApi),
    );
  }

  Future<void> unlockWallet(UtexoWallet wallet) async {
    await wallet.init(password: 'password');
    await wallet.unlock(
      password: 'password',
      config: UtexoUnlockConfig(
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcUsername: 'user',
      ),
    );
  }

  test('requires initialization before wallet operations', () async {
    final wallet = walletWith(FakeRlnHostApi());

    expect(wallet.getAddress, throwsA(isA<WalletException>()));
  });

  test(
    'requires unlock before chain, RGB, Lightning, and channel operations',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');

      expect(await wallet.nodeInfo(), isA<RlnNodeInfo>());
      await expectLater(wallet.networkInfo(), throwsA(isA<WalletException>()));
      await expectLater(wallet.getAddress(), throwsA(isA<WalletException>()));
      await expectLater(wallet.listAssets(), throwsA(isA<WalletException>()));
      await expectLater(
        wallet.blindReceive(const RgbInvoiceRequest()),
        throwsA(isA<WalletException>()),
      );
      await expectLater(
        wallet.payRlnLightningInvoice(invoice: 'lnbc1invoice'),
        throwsA(isA<WalletException>()),
      );
      await expectLater(wallet.listPeers(), throwsA(isA<WalletException>()));
      expect(() => wallet.backupNow(), throwsA(isA<WalletException>()));

      expect(hostApi.networkInfoCalls, 0);
      expect(hostApi.addressCalls, 0);
      expect(hostApi.listAssetsCalls, 0);
      expect(hostApi.rgbInvoiceCalls, 0);
      expect(hostApi.lastSendPayment, isNull);
    },
  );

  test('initializes, unlocks, and delegates address lookup', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.init(password: 'password');
    await wallet.unlock(
      password: 'password',
      config: UtexoUnlockConfig(
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
      config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
      client: RlnClient(hostApi: hostApi),
      signer: PasswordRlnSigner(
        password: 'password',
        mnemonic:
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      ),
    );

    await wallet.init();
    await wallet.unlock(
      config: UtexoUnlockConfig(
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
      config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
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
      config: UtexoUnlockConfig(
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
    expect(hostApi.createdSignerStorageDirPath, '/tmp/rgb-wallet-test');
  });

  test(
    'allows strict native external signer policy when explicitly requested',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
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
      config: UtexoWalletConfig(
        storageDirPath: '/tmp/rgb-wallet-test',
        network: 'utexo',
      ),
      client: RlnClient(hostApi: passwordHostApi),
    );

    await passwordWallet.init(password: 'password');
    await passwordWallet.unlock(
      password: 'password',
      config: UtexoUnlockConfig(),
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
      config: UtexoWalletConfig(
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
    final resolved = resolveUnlockParams('utexo', UtexoUnlockConfig());

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
      () => resolveUnlockConfig('unknown-network', UtexoUnlockConfig()),
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

  test('rejects unsupported networks before native node creation', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = UtexoWallet(
      config: UtexoWalletConfig(
        storageDirPath: '/tmp/rgb-wallet-test',
        network: 'unknown-network',
      ),
      client: RlnClient(hostApi: hostApi),
    );

    await expectLater(
      wallet.init(password: 'password'),
      throwsA(isA<WalletValidationException>()),
    );
    expect(hostApi.createNodeCount, 0);
  });

  test('rejects no-op gossip RGS unlock configuration', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    await expectLater(
      wallet.unlock(
        password: 'password',
        config: UtexoUnlockConfig(
          bitcoindRpcHost: '127.0.0.1',
          bitcoindRpcUsername: 'user',
          gossipRgsServerUrl: 'https://rgs.example',
        ),
      ),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
  });

  test('coalesces concurrent init and unlock lifecycle calls', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await Future.wait(<Future<void>>[
      wallet.init(password: 'password'),
      wallet.init(password: 'password'),
    ]);
    expect(hostApi.createNodeCount, 1);
    expect(hostApi.initNodeCount, 1);

    await Future.wait(<Future<void>>[
      wallet.unlock(
        password: 'password',
        config: UtexoUnlockConfig(
          bitcoindRpcHost: '127.0.0.1',
          bitcoindRpcUsername: 'user',
        ),
      ),
      wallet.unlock(
        password: 'password',
        config: UtexoUnlockConfig(
          bitcoindRpcHost: '127.0.0.1',
          bitcoindRpcUsername: 'user',
        ),
      ),
    ]);
    expect(hostApi.unlockNodeCount, 1);
    expect(wallet.isUnlocked, true);
  });

  test('password signer consumes password after unlock', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.init(password: 'password');
    await wallet.unlock(
      config: UtexoUnlockConfig(
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcUsername: 'user',
      ),
    );
    await wallet.shutdown();

    await expectLater(
      wallet.reinit(
        unlockConfig: UtexoUnlockConfig(
          bitcoindRpcHost: '127.0.0.1',
          bitcoindRpcUsername: 'user',
        ),
      ),
      throwsA(isA<WalletValidationException>()),
    );
    expect(hostApi.createNodeCount, 1);
    expect(hostApi.unlockNodeCount, 1);

    await wallet.reinit(
      password: 'password',
      unlockConfig: UtexoUnlockConfig(
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcUsername: 'user',
      ),
    );

    expect(wallet.isUnlocked, true);
  });

  test('rejects regular operations after shutdown until reinit', () async {
    final wallet = walletWith(FakeRlnHostApi());

    await wallet.init(password: 'password');
    await wallet.shutdown();

    expect(wallet.isInitialized, false);
    expect(wallet.isShutdown, true);
    expect(() => wallet.nodeId, throwsA(isA<WalletException>()));
    await expectLater(wallet.getAddress(), throwsA(isA<WalletException>()));

    await wallet.reinit(
      unlockConfig: UtexoUnlockConfig(
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcUsername: 'user',
      ),
    );
    expect(await wallet.getAddress(), 'bcrt1address');
  });

  test('reinit recreates node without re-running signer init', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.init(password: 'password');
    await wallet.shutdown();
    await wallet.reinit(
      unlockConfig: UtexoUnlockConfig(
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcPort: 18444,
      ),
    );

    expect(hostApi.createNodeCount, 2);
    expect(hostApi.initNodeCount, 1);
    expect(hostApi.destroyNodeCount, 0);
    expect(hostApi.shutdownCount, 1);
    expect(wallet.isInitialized, true);
    expect(wallet.isUnlocked, true);
  });

  test('reinit supports a cold-process persisted wallet session', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);

    await wallet.reinit(
      password: 'password',
      unlockConfig: UtexoUnlockConfig(
        bitcoindRpcHost: '127.0.0.1',
        bitcoindRpcPort: 18444,
      ),
    );

    expect(hostApi.createNodeCount, 1);
    expect(hostApi.initNodeCount, 0);
    expect(wallet.isInitialized, true);
    expect(wallet.isUnlocked, true);
  });

  test(
    'cold-process external signer reinit attaches before unlocking',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.seedHex(
            '0101010101010101010101010101010101010101010101010101010101010101',
          ),
          network: 'regtest',
        ),
      );

      await wallet.reinit(unlockConfig: UtexoUnlockConfig());

      expect(hostApi.createNodeCount, 1);
      expect(hostApi.createdSignerIds, <int>[99]);
      expect(hostApi.attachedNativeSignerId, 99);
      expect(hostApi.unlockedNativeSignerId, 99);
      expect(wallet.isUnlocked, true);
    },
  );

  test(
    'failed native signer init destroys the temporary handle and consumes seed',
    () async {
      final hostApi = FakeRlnHostApi()..throwOnNativeSignerInit = true;
      final signer = NativeExternalRlnSigner(
        keys: RlnKeyMaterial.seedHex(
          '0101010101010101010101010101010101010101010101010101010101010101',
        ),
        network: 'regtest',
      );
      final wallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: signer,
      );

      await expectLater(wallet.init(), throwsStateError);
      expect(signer.signerId, isNull);
      expect(hostApi.createdSignerIds, <int>[99]);
      expect(hostApi.destroyedNativeSignerIds, <int>[99]);

      hostApi.throwOnNativeSignerInit = false;
      await expectLater(wallet.init(), throwsA(isA<WalletException>()));
      expect(hostApi.createdSignerIds, <int>[99]);

      final retryWallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.seedHex(
            '0101010101010101010101010101010101010101010101010101010101010101',
          ),
          network: 'regtest',
        ),
      );
      await retryWallet.init();

      expect(retryWallet.isInitialized, true);
      expect(hostApi.createdSignerIds, <int>[99, 100]);
    },
  );

  test(
    'failed cold attach destroys the temporary handle and consumes seed',
    () async {
      final hostApi = FakeRlnHostApi()..throwOnNativeSignerAttach = true;
      final signer = NativeExternalRlnSigner(
        keys: RlnKeyMaterial.seedHex(
          '0101010101010101010101010101010101010101010101010101010101010101',
        ),
        network: 'regtest',
      );
      final wallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: signer,
      );

      await expectLater(
        wallet.reinit(unlockConfig: UtexoUnlockConfig()),
        throwsStateError,
      );
      expect(signer.signerId, isNull);
      expect(hostApi.createdSignerIds, <int>[99]);
      expect(hostApi.destroyedNativeSignerIds, <int>[99]);

      hostApi.throwOnNativeSignerAttach = false;
      await expectLater(
        wallet.unlock(config: UtexoUnlockConfig()),
        throwsA(isA<WalletException>()),
      );
      expect(hostApi.createdSignerIds, <int>[99]);

      final retryWallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.seedHex(
            '0101010101010101010101010101010101010101010101010101010101010101',
          ),
          network: 'regtest',
        ),
      );
      await retryWallet.reinit(unlockConfig: UtexoUnlockConfig());

      expect(hostApi.attachedNativeSignerId, 100);
      expect(hostApi.unlockedNativeSignerId, 100);
    },
  );

  test(
    'failed signer cleanup blocks reuse until explicit disposal succeeds',
    () async {
      final hostApi = FakeRlnHostApi()
        ..throwOnNativeSignerInit = true
        ..throwOnNativeSignerDestroy = true;
      final client = RlnClient(hostApi: hostApi);
      final signer = NativeExternalRlnSigner(
        keys: RlnKeyMaterial.seedHex(
          '0101010101010101010101010101010101010101010101010101010101010101',
        ),
        network: 'regtest',
      );
      final wallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: client,
        signer: signer,
      );

      await expectLater(
        wallet.init(),
        throwsA(
          isA<WalletException>().having(
            (error) => error.cause,
            'operation and cleanup causes',
            isA<List<Object>>().having((causes) => causes.length, 'length', 2),
          ),
        ),
      );
      expect(hostApi.createdSignerIds, <int>[99]);
      expect(hostApi.destroyedNativeSignerIds, <int>[99]);

      await expectLater(wallet.init(), throwsA(isA<WalletException>()));
      expect(hostApi.createdSignerIds, <int>[99]);

      hostApi.throwOnNativeSignerDestroy = false;
      await signer.dispose(client: client, nodeId: wallet.nodeId);
      hostApi.throwOnNativeSignerInit = false;
      await expectLater(wallet.init(), throwsA(isA<WalletException>()));
      expect(hostApi.createdSignerIds, <int>[99]);

      final retryWallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: client,
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.seedHex(
            '0101010101010101010101010101010101010101010101010101010101010101',
          ),
          network: 'regtest',
        ),
      );
      await retryWallet.init();

      expect(retryWallet.isInitialized, true);
      expect(hostApi.createdSignerIds, <int>[99, 100]);
    },
  );

  test('durable native signer requires one stable storage path', () async {
    final hostApi = FakeRlnHostApi();
    final client = RlnClient(hostApi: hostApi);
    final signer = NativeExternalRlnSigner(
      keys: RlnKeyMaterial.seedHex(
        '0101010101010101010101010101010101010101010101010101010101010101',
      ),
      network: 'regtest',
    );

    await expectLater(
      signer.initNode(client: client, nodeId: 7, storageDirPath: ''),
      throwsA(
        isA<WalletValidationException>().having(
          (error) => error.field,
          'field',
          'storageDirPath',
        ),
      ),
    );

    await signer.initNode(
      client: client,
      nodeId: 7,
      storageDirPath: '/tmp/rgb-wallet-one',
    );
    await expectLater(
      signer.unlockNode(
        client: client,
        nodeId: 7,
        config: UtexoUnlockConfig(),
        storageDirPath: '/tmp/rgb-wallet-two',
      ),
      throwsA(isA<WalletException>()),
    );

    expect(hostApi.createdSignerIds, <int>[99]);
    expect(hostApi.unlockedNativeSignerId, isNull);
  });

  test('exposes RN-compatible high-level diagnostics', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
        config: UtexoWalletConfig(
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
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

    final response = await wallet.send(
      const RgbSendRequest(invoice: 'rgb:invoice'),
    );

    expect(response.txid, 'txid');
    expect(hostApi.lastSendRgb?['assetId'], 'asset');
    expect(hostApi.lastSendRgb?['recipientId'], 'recipient');
    expect(hostApi.lastSendRgb?['amount'], 100);
    expect(hostApi.lastSendRgb?['feeRate'], 1);
    expect(hostApi.lastSendRgb?['minConfirmations'], 1);
  });

  test('fails fast instead of ignoring RGB send skipSync', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
      await unlockWallet(wallet);

      final created = await wallet.createUtxos(num: 3);
      final feeRate = await wallet.estimateFeeRate(6);
      final feeRateValue = await wallet.estimateFeeRateValue(6);
      final btcTxid = await wallet.sendBtc(amount: 10, address: 'bcrt1dest');

      expect(created, 3);
      expect(DEFAULT_API_TIMEOUT, 120000);
      expect(DEFAULT_LOG_LEVEL, 3);
      expect(hostApi.lastCreateUtxosUpTo, true);
      expect(hostApi.lastCreateUtxosNum, 3);
      expect(hostApi.lastCreateUtxosFeeRate, 1);
      expect(feeRate.feeRate, 2.25);
      expect(feeRateValue, 2.25);
      expect(hostApi.lastEstimateFeeBlocks, 6);
      expect(btcTxid, 'btc-txid');
      expect(hostApi.lastSendBtc?['feeRate'], 1);
    },
  );

  test('validates app-facing bounded numeric inputs', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await unlockWallet(wallet);

    expect(
      () => wallet.createUtxos(num: 256),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.sendBtc(amount: 0, address: 'bcrt1dest'),
      throwsA(isA<WalletValidationException>()),
    );
    expect(
      () => wallet.sendBtc(amount: 1, address: 'bcrt1dest', feeRate: 1.5),
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
    expect(paymentResult.status, 'Pending');
    expect(payment.paymentType, 'InboundHodl');
    expect(payment.status, 'Claimable');
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

  test('parses and bounds native integer strings at model boundaries', () {
    expect(rlnPigeonMaxSignedInt64, 9223372036854775807);
    expect(rlnMaxUnsigned64Decimal, '18446744073709551615');

    final transaction = RlnTransaction.fromMap(<Object?, Object?>{
      'transactionType': 'rgbSend',
      'txid': 'txid',
      'received': '9223372036854775807',
      'fee': '0',
    });
    expect(transaction.received, rlnPigeonMaxSignedInt64);

    final transfer = RlnTransfer.fromMap(<Object?, Object?>{
      'idx': '9223372036854775807',
      'createdAt': '9223372036854775806',
      'updatedAt': '9223372036854775805',
      'status': 'WaitingCounterparty',
      'assignments': <String>['Fungible(1)'],
      'batchTransferIdx': '9223372036854775804',
    });
    expect(transfer.idx, rlnPigeonMaxSignedInt64);
    expect(transfer.createdAt, 9223372036854775806);
    expect(transfer.updatedAt, 9223372036854775805);
    expect(transfer.batchTransferIdx, 9223372036854775804);

    final nodeInfo = RlnNodeInfo.fromMap(<Object?, Object?>{
      'pubkey': 'node',
      'numChannels': 0,
      'numUsableChannels': 0,
      'localBalanceSat': 0,
      'numPeers': 0,
      'channelAssetMaxAmount': rlnMaxUnsigned64Decimal,
    });
    expect(
      nodeInfo.channelAssetMaxAmount,
      BigInt.parse(rlnMaxUnsigned64Decimal),
    );

    expect(
      () => RlnTransaction.fromMap(<Object?, Object?>{
        'transactionType': 'rgbSend',
        'txid': 'txid',
        'received': '9223372036854775808',
        'fee': '0',
      }),
      throwsA(isA<NativeProtocolException>()),
    );
    expect(
      () => RlnTransfer.fromMap(<Object?, Object?>{
        'idx': rlnMaxUnsigned64Decimal,
        'status': 'WaitingCounterparty',
        'assignments': <String>['Fungible(1)'],
      }),
      throwsA(isA<NativeProtocolException>()),
    );
    expect(
      () => RlnNodeInfo.fromMap(<Object?, Object?>{
        'pubkey': 'node',
        'numChannels': 0,
        'numUsableChannels': 0,
        'localBalanceSat': 0,
        'numPeers': 0,
        'channelAssetMaxAmount': '18446744073709551616',
      }),
      throwsA(isA<NativeProtocolException>()),
    );
  });

  test(
    'strict model decoding preserves optional state and rejects fabrication',
    () {
      expect(
        () => RlnAddress.fromMap(<Object?, Object?>{}),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => RlnBalance.fromMap(<Object?, Object?>{'settled': 1, 'future': 0}),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => parseCoreOutpoint('txid-without-vout'),
        throwsA(isA<NativeProtocolException>()),
      );

      final unspent = RlnUnspent.fromMap(<Object?, Object?>{
        'utxo': <Object?, Object?>{
          'outpoint': 'txid:3',
          'btcAmount': 1000,
          'colorable': true,
        },
        'pendingBlinded': 2,
      });
      expect(unspent.toCore().pendingBlinded, 2);

      final transfer = RlnTransfer.fromMap(<Object?, Object?>{
        'idx': 7,
        'status': 'WaitingSafeHeight',
        'kind': 'Burn',
        'assignments': <String>['Fungible(5)'],
      }).toCore();
      expect(transfer.batchTransferIdx, isNull);
      expect(transfer.createdAt, isNull);
      expect(transfer.status, 'WaitingSafeHeight');
      expect(transfer.kind, 'Burn');

      expect(
        () => RlnTransfer.fromMap(<Object?, Object?>{
          'idx': 7,
          'status': 'Mystery',
          'kind': 'Burn',
        }).toCore(),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );

  test('maps Lightning helpers to canonical RN status shapes', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

    expect(
      await wallet.getLightningReceiveStatus('invoice'),
      RlnInvoiceStatuses.succeeded,
    );
    expect(
      await wallet.getLightningSendStatus('payment-hash'),
      RlnPaymentStatuses.claiming,
    );
    expect(
      await wallet.getLightningReceiveRequest('invoice'),
      CoreTransferStatuses.settled,
    );

    final payments = await wallet.listLightningPayments();
    expect(payments.payments.single.txid, 'hash-1');
    expect(payments.payments.single.status, 'SUCCEEDED');
  });

  test('unknown Lightning send status maps to null', () async {
    final hostApi = FakeRlnHostApi()
      ..invoiceStatus = 'UNKNOWN_INVOICE'
      ..paymentStatus = 'UNKNOWN_PAYMENT';
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

    await expectLater(
      wallet.getLightningReceiveStatus('invoice'),
      throwsA(isA<ValidationError>()),
    );
    expect(await wallet.getLightningSendStatus('payment-hash'), isNull);
  });

  test('listTransfers delegates empty asset id when omitted like RN', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
      await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
      await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

      final transfers = await wallet.listTransfers();

      expect(hostApi.lastTransferAssetId, 'asset');
      expect(transfers.single.idx, 1);
    },
  );

  test('maps supported responses into core-style DTOs', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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

  test('marks PSBT capability carrier absent', () async {
    final wallet = walletWith(FakeRlnHostApi());
    await wallet.init(password: 'password');

    expect(wallet.psbt, isNull);
    expect(wallet.beginEnd, isNull);
    expect(wallet.capabilities.psbtSigning, false);
    expect(wallet.capabilities.beginEndFlows, false);
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
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

    final lnReceive = await wallet.createLightningInvoice(
      amountSats: 2,
      asset: const LightningAsset(assetId: 'asset', amount: 5),
      expirySeconds: 30,
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
    expect(hostApi.lastLnInvoice?['paymentHash'], isNull);
    expect(hostApi.lastLnInvoice?['minFinalCltvExpiryDelta'], 144);
    expect(lnSend.txid, 'payment-hash');
    expect(lnSend.status, 'SUCCEEDED');
    expect(hostApi.lastSendPayment?['amtMsat'], 3000);
    expect(onchainReceive.invoice, 'rgb:invoice');
    expect(onchainReceive.recipientId, 'recipient');
    expect(onchainReceive.expirationTimestamp, 123456);
    expect(onchainReceive.batchTransferIdx, 1);
    expect(onchainSend.txid, 'txid');
    expect(onchainSend.batchTransferIdx, 2);
  });

  test('maps HODL invoices, APay, LSP config, and VSS clear fence', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
    expect(hodl.amtMsat, 5000);
    expect(hodl.expirySec, 60);
    expect(hodl.assetId, 'asset');
    expect(hodl.assetAmount, 7);
    expect(hodl.minFinalCltvExpiryDelta, 144);
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
      await wallet.unlock(password: 'password', config: UtexoUnlockConfig());
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
        config: UtexoWalletConfig(
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
      await unlockWallet(wallet);

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
          options: const WaitOptions(timeoutMs: 1, pollIntervalMs: 50),
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
        options: const WaitOptions(timeoutMs: 50, pollIntervalMs: 50),
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
    await unlockWallet(wallet);

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
          pollIntervalMs: 50,
          onEachPoll: () {
            pollCount += 1;
          },
        ),
      ),
      throwsA(isA<LspLiquidityTimeoutException>()),
    );
    expect(pollCount, greaterThan(0));
  });

  test(
    'LSP payAddress routes by host and does not fallback for same-host errors',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = walletWith(hostApi);
      await wallet.init(password: 'password');
      await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

      final lspClient = FakeLspClient();
      final lsp = UtexoLsp(
        wallet: wallet,
        peer: const LspPeer(
          baseUrl: 'https://lsp.example/proxy',
          peerPubkey: 'lsp-peer',
          peerHost: 'lsp.example',
          peerPort: 9735,
        ),
        httpClient: lspClient,
      );

      final foreign = await lsp.payAddress(
        const PayAddressOptions(address: 'alice@wallet.example', amtMsat: 3000),
      );

      expect(foreign.invoice, 'lnbc1external');
      expect(lspClient.resolveAddressCalls, 0);
      expect(lspClient.resolveExternalAddressCalls, 1);

      lspClient.resolveAddressError = const LspError(
        endpoint: '/.well-known/lnurlp/alice',
        status: 401,
        body: 'unauthorized',
      );
      await expectLater(
        lsp.payAddress(
          const PayAddressOptions(address: 'alice@lsp.example', amtMsat: 3000),
        ),
        throwsA(isA<LspError>()),
      );
      expect(lspClient.resolveExternalAddressCalls, 1);
    },
  );

  test('LSP connect idempotence only swallows typed conflicts', () async {
    final hostApi = FakeRlnHostApi()
      ..connectPeerError = const ConflictError('peer already connected');
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());
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

    await lsp.connect();

    hostApi.connectPeerError = StateError('already connected');
    await expectLater(lsp.connect(), throwsA(isA<StateError>()));
  });

  test('LSP service operations preserve negative-path failures', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());
    final lspClient = FakeLspClient()
      ..lightningReceiveError = const LspError(
        endpoint: '/lightning_receive',
        status: 503,
        body: 'service unavailable',
      )
      ..onchainSendError = const LspError(
        endpoint: '/onchain_send',
        status: 400,
        body: 'bad rgb invoice',
      );
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
      lsp.receiveAsset(
        const ReceiveAssetOptions(
          assetId: 'asset',
          amountSats: 1000,
          amountRgb: 7,
        ),
      ),
      throwsA(isA<LspError>()),
    );
    await expectLater(
      lsp.sendAsset(const SendAssetOptions(rgbInvoice: 'rgb:invoice')),
      throwsA(isA<LspError>()),
    );
    expect(hostApi.lastSendPayment, isNull);
  });

  test('LSP settlement and APay failures use explicit error paths', () async {
    final hostApi = FakeRlnHostApi()
      ..invoiceStatus = 'FAILED'
      ..apayNewWithAddressError = const WalletError('apay registration failed');
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());
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

    await expectLater(
      lsp.awaitReceiveSettlement(
        'lnbc-invoice',
        options: const WaitOptions(timeoutMs: 50, pollIntervalMs: 50),
      ),
      throwsA(isA<LspSettlementException>()),
    );
    await expectLater(
      lsp.enableLightningAddress(),
      throwsA(isA<WalletError>()),
    );
    expect(hostApi.apayNewWithAddressCalls, 0);
  });

  test('LSP claimPendingPayments never claims without a preimage', () async {
    final hostApi = FakeRlnHostApi()
      ..paymentRows = <Map<Object?, Object?>>[
        <Object?, Object?>{
          'paymentHash': 'hash-missing-preimage',
          'paymentType': 'INBOUND',
          'status': 'CLAIMABLE',
          'createdAt': 1,
          'updatedAt': 2,
        },
      ];
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());
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

    final results = await lsp.claimPendingPayments();

    expect(results.single.paymentHash, 'hash-missing-preimage');
    expect(results.single.claimed, false);
    expect(results.single.error, contains('Missing preimage'));
    expect(hostApi.lastClaimHodlInvoice, isNull);
  });

  test('HODL and VSS negative paths do not rewrite native failures', () async {
    final hostApi = FakeRlnHostApi()
      ..paymentRows = <Map<Object?, Object?>>[
        <Object?, Object?>{
          'paymentHash': 'hash-with-preimage',
          'paymentType': 'INBOUND',
          'status': 'CLAIMABLE',
          'paymentPreimage': 'preimage',
          'createdAt': 1,
          'updatedAt': 2,
        },
      ]
      ..claimHodlInvoiceError = const WalletError('claim rejected')
      ..vssClearFenceError = const WalletError('vss clear failed')
      ..vssBackupError = const WalletError('vss backup failed');
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());
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

    final results = await lsp.claimPendingPayments();

    expect(results.single.paymentHash, 'hash-with-preimage');
    expect(results.single.claimed, false);
    expect(results.single.error, contains('claim rejected'));
    expect(hostApi.lastClaimHodlInvoice?['paymentPreimage'], 'preimage');
    await expectLater(
      wallet.vssClearFence('password'),
      throwsA(isA<WalletError>()),
    );
    await expectLater(wallet.backupNow(), throwsA(isA<WalletError>()));
  });

  test(
    'LSP HTTP policy preserves callback paths and redacts diagnostics',
    () async {
      final client = UtexoLspClient(
        baseUrl: 'https://proxy.example/lsp',
        bearerToken: 'secret-token',
        httpClient: _StaticHttpClient((request) async {
          if (request.url.path == '/lsp/.well-known/lnurlp/alice') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'callback':
                    'https://lsp.example/pay/callback/alice?existing=true',
                'minSendable': 1000,
                'maxSendable': 5000,
              }),
              200,
            );
          }
          if (request.url.path == '/lsp/pay/callback/alice' &&
              request.url.queryParameters['existing'] == 'true' &&
              request.url.queryParameters['amount'] == '3000') {
            return http.Response(
              jsonEncode(<String, Object?>{'pr': 'lnbc'}),
              200,
            );
          }
          return http.Response(
            '{"token":"secret-token","preimage":"${'a' * 64}"}',
            500,
          );
        }),
      );

      final resolved = await client.resolveAddress('alice', 3000);

      expect(resolved.pr, 'lnbc');
      expect(
        () => UtexoLspClient(baseUrl: 'http://lsp.example'),
        throwsA(isA<LspTransportPolicyException>()),
      );
      expect(
        LspError(
          endpoint: '/pay?token=secret-token',
          status: 500,
          body: '{"preimage":"${'a' * 64}"}',
        ).toString(),
        isNot(contains('secret-token')),
      );
    },
  );

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
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

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
    expect(coreTransactions.single.transactionType, 'SendBtc');
  });

  test('maps RGB asset balance and issuance methods', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await unlockWallet(wallet);

    final balance = await wallet.getAssetBalance('asset');
    final coreBalance = await wallet.getAssetBalanceCore('asset');
    final nia = await wallet.issueAssetNia(
      ticker: 'RGB',
      name: 'RGB Asset',
      precision: 0,
      amounts: const <int>[1000],
    );
    final ifa = await wallet.issueAssetIfa(
      ticker: 'IFA',
      name: 'Inflatable',
      precision: 0,
      amounts: const <int>[1000],
      inflationAmounts: const <int>[1000],
      rejectListUrl: 'https://example.com/reject-list',
    );
    expect(hostApi.lastAssetBalanceId, 'asset');
    expect(balance.offchainInbound, 3);
    expect(coreBalance.offchainOutbound, 2);
    expect(nia.ticker, 'RGB');
    expect(hostApi.lastIssueAssetNia?['amounts'], const <int>[1000]);
    expect(hostApi.lastIssueAssetCfa, isNull);
    expect(ifa.maxSupply, 2000);
    expect(hostApi.lastIssueAssetIfa?['rejectListUrl'], contains('reject'));
    expect(hostApi.lastIssueAssetUda, isNull);
  });

  test('maps Lightning, peer, and channel methods', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await unlockWallet(wallet);

    final decoded = await wallet.decodeLnInvoice('lnbc-invoice');
    final peers = await wallet.listPeers();
    final channels = await wallet.listChannels();
    final lightningChannels = await wallet.listLightningChannels();
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
    expect(lightningChannels.single.isPublic, false);
    expect(lightningChannels.single.status, 'Opened');
    expect(lightningChannels.single.localBalanceMsat, 90000000);
    expect(hostApi.lastConnectedPeer, 'peer@127.0.0.1:9735');
    expect(hostApi.lastDisconnectedPeerPubkey, 'peer');
    expect(opened.temporaryChannelId, 'temporary-channel-id');
    expect(hostApi.lastOpenChannel?['assetAmount'], 100);
    expect(hostApi.lastOpenChannel?['withAnchors'], true);
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
    await wallet.unlock(password: 'password', config: UtexoUnlockConfig());

    final transfers = await wallet.listOnchainTransfers(assetId: 'asset');

    expect(hostApi.lastTransferAssetId, 'asset');
    expect(transfers.single.idx, 1);
  });

  test(
    'exposes current RLN address, inflation, lookup, signing, and VSS APIs',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = walletWith(hostApi);
      await unlockWallet(wallet);

      expect(await wallet.rotateVanillaAddress(), 'bcrt1rotated');
      final inflation = await wallet.inflate(
        InflateAssetIfaRequest(assetId: 'ifa', inflationAmounts: <int>[25, 75]),
      );
      expect(inflation.txid, 'inflate-txid');
      expect(hostApi.lastInflate?['assetId'], 'ifa');
      expect(
        (await wallet.listTransactionsByTxid('btc-txid')).single.txid,
        'btc-txid',
      );
      expect(hostApi.lastTransactionTxid, 'btc-txid');
      expect((await wallet.listTransfersByTxid('btc-txid')).single.idx, 1);
      expect(hostApi.lastTransferTxid, 'btc-txid');
      final signature = await wallet.signMessage('message');
      expect(signature, 'signed:message');
      expect(await wallet.verifyMessage('message', signature), true);
      expect(await wallet.backupNow(), 42);
    },
  );

  test(
    'external signer capabilities reject unsupported RGB asset flows',
    () async {
      final hostApi = FakeRlnHostApi();
      final wallet = UtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/rgb-wallet-test'),
        client: RlnClient(hostApi: hostApi),
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.seedHex(
            '0101010101010101010101010101010101010101010101010101010101010101',
          ),
          network: 'regtest',
        ),
      );
      await unlockWallet(wallet);

      expect(wallet.capabilities.rgbUtxoCreation, false);
      expect(wallet.capabilities.rgbAssetIssuance, false);
      await expectLater(
        wallet.createUtxos(num: 1),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      await expectLater(
        wallet.issueAssetNia(
          ticker: 'RGB',
          name: 'RGB Asset',
          precision: 0,
          amounts: const <int>[1],
        ),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      expect(hostApi.lastCreateUtxosNum, isNull);
      expect(hostApi.lastIssueAssetNia, isNull);
    },
  );

  test('validates native external signer seed material length', () {
    final seedBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => index),
    );
    final material =
        RlnKeyMaterial.seedBytes(seedBytes) as RlnSeedBytesKeyMaterial;
    final originalSeedHex = material.toSeedHex32();
    seedBytes.fillRange(0, seedBytes.length, 255);

    expect(material.toSeedHex32(), originalSeedHex);
    expect(material.seedBytes, isNot(same(seedBytes)));
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
    expect(normalizeNetwork('testnet4'), 'testnet4');
    expect(normalizeNetwork('utexo'), 'utexo');
    expect(() => normalizeNetwork('MAINNET'), throwsA(isA<ValidationError>()));
    expect(
      () => normalizeNetwork('signet_custom'),
      throwsA(isA<ValidationError>()),
    );
    expect(getNetworkDefaults('regtest')?.indexerUrl, 'http://127.0.0.1:3002');
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
    expect(encodeTransferStatus('Finished'), 3);
    expect(() => encodeTransferStatus('unknown'), throwsArgumentError);
    expect(getNetworkDefaults('signet')?.proxyEndpoint, contains('utexo.com'));
    expect(UMA_PREFIX, r'$');
    expect(UMA_MAX_USERNAME_LENGTH, 64);
    expect(isUmaAddress(r'$alice@example.com'), true);
    expect(
      normalizeLightningAddress(r'$Alice@Example.com'),
      'alice@example.com',
    );
    expect(parseLightningAddress(r'$alice@example.com').isUma, true);
    expect(parseLightningAddress('Bob@example.com').address, 'Bob@example.com');
    expect(normalizeInvoiceStatus('paid'), RlnInvoiceStatuses.succeeded);
    expect(tryNormalizePaymentStatus('UNKNOWN'), isNull);
  });

  test('keeps local backup explicitly native-blocked', () async {
    final hostApi = FakeRlnHostApi();
    final wallet = walletWith(hostApi);
    await wallet.init(password: 'password');

    expect(
      () =>
          wallet.createBackup(backupPath: '/tmp/backup', password: 'password'),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );

    expect(hostApi.lastBackup, isNull);
  });
}
