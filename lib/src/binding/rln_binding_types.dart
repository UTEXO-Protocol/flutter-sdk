part of 'rln_binding.dart';

class IRLNNodeCreateParams {
  IRLNNodeCreateParams({
    required this.storageDirPath,
    required this.daemonListeningPort,
    required this.ldkPeerListeningPort,
    required this.network,
    required this.maxMediaUploadSizeMb,
    this.enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    this.vssUrl,
    this.vssAllowHttp = false,
    this.vssAllowEmptyRestore = false,
    this.lspBaseUrl,
    this.lspBearerToken,
    this.reuseAddresses = false,
  }) : virtualPeerPubkeys = virtualPeerPubkeys == null
           ? null
           : List<String>.unmodifiable(virtualPeerPubkeys);

  final String storageDirPath;
  final int daemonListeningPort;
  final int ldkPeerListeningPort;
  final String network;
  final int maxMediaUploadSizeMb;
  final bool? enableVirtualChannelsV0;
  final List<String>? virtualPeerPubkeys;
  final String? vssUrl;
  final bool vssAllowHttp;
  final bool vssAllowEmptyRestore;
  final String? lspBaseUrl;
  final String? lspBearerToken;
  final bool reuseAddresses;
}

class IRLNUnlockParams {
  IRLNUnlockParams({
    this.bitcoindRpcUsername,
    this.bitcoindRpcPassword,
    this.bitcoindRpcHost,
    this.bitcoindRpcPort,
    this.indexerUrl,
    this.proxyEndpoint,
    List<String> announceAddresses = const <String>[],
    this.announceAlias,
    this.gossipRgsServerUrl,
  }) : announceAddresses = List<String>.unmodifiable(announceAddresses);

  final String? bitcoindRpcUsername;
  final String? bitcoindRpcPassword;
  final String? bitcoindRpcHost;
  final int? bitcoindRpcPort;
  final String? indexerUrl;
  final String? proxyEndpoint;
  final List<String> announceAddresses;
  final String? announceAlias;
  final String? gossipRgsServerUrl;
}

class IRLNExternalSignerBootstrap {
  const IRLNExternalSignerBootstrap({
    required this.nodePublicKeyHex,
    required this.accountXpubVanilla,
    required this.accountXpubColored,
    required this.masterFingerprint,
    required this.protocolVersion,
    required this.apiLevel,
  });

  final String nodePublicKeyHex;
  final String accountXpubVanilla;
  final String accountXpubColored;
  final String masterFingerprint;
  final String protocolVersion;
  final int apiLevel;
}

class RlnOpenChannelRequest {
  const RlnOpenChannelRequest({
    required this.peerPubkeyAndOptAddr,
    required this.capacitySat,
    required this.pushMsat,
    required this.public,
    required this.withAnchors,
    this.feeBaseMsat,
    this.feeProportionalMillionths,
    this.temporaryChannelId,
    this.assetId,
    this.assetAmount,
    this.pushAssetAmount,
    this.virtualOpenMode,
  });

  final String peerPubkeyAndOptAddr;
  final int capacitySat;
  final int pushMsat;
  final bool public;
  final bool withAnchors;
  final int? feeBaseMsat;
  final int? feeProportionalMillionths;
  final String? temporaryChannelId;
  final String? assetId;
  final int? assetAmount;
  final int? pushAssetAmount;
  final String? virtualOpenMode;
}

class RlnWitnessData {
  const RlnWitnessData({required this.amountSat, this.blinding});

  final int amountSat;
  final int? blinding;
}

class RlnOperationTimeoutPolicy {
  const RlnOperationTimeoutPolicy({
    this.defaultTimeout = _defaultApiTimeout,
    this.lifecycleTimeout = _defaultApiTimeout,
    this.unlockTimeout = _defaultApiTimeout,
    this.networkTimeout = _defaultApiTimeout,
    this.channelTimeout = _defaultApiTimeout,
    this.sendTimeout = _defaultApiTimeout,
    this.syncTimeout = _defaultApiTimeout,
  });

  static const Duration _defaultApiTimeout = Duration(
    milliseconds: DEFAULT_API_TIMEOUT,
  );

  /// Disables Dart-side deadlines. Native calls still run on the serialized
  /// Pigeon task queue and are not cancellable.
  static const RlnOperationTimeoutPolicy disabled = RlnOperationTimeoutPolicy(
    defaultTimeout: null,
    lifecycleTimeout: null,
    unlockTimeout: null,
    networkTimeout: null,
    channelTimeout: null,
    sendTimeout: null,
    syncTimeout: null,
  );

  final Duration? defaultTimeout;
  final Duration? lifecycleTimeout;
  final Duration? unlockTimeout;
  final Duration? networkTimeout;
  final Duration? channelTimeout;
  final Duration? sendTimeout;
  final Duration? syncTimeout;

  Duration? timeoutFor(String operation) {
    final lower = operation.toLowerCase();
    if (lower.contains('destroy')) return null;
    if (lower.contains('unlock')) return unlockTimeout;
    if (lower.contains('send') ||
        lower.contains('issue') ||
        lower.contains('inflate') ||
        lower.contains('utxo')) {
      return sendTimeout;
    }
    if (lower.contains('create') ||
        lower.contains('init') ||
        lower.contains('shutdown')) {
      return lifecycleTimeout;
    }
    if (lower.contains('sync') || lower.contains('refresh')) {
      return syncTimeout;
    }
    if (lower.contains('network') ||
        lower.contains('indexer') ||
        lower.contains('proxy') ||
        lower.contains('peer')) {
      return networkTimeout;
    }
    if (lower.contains('channel') || lower.contains('payment')) {
      return channelTimeout;
    }
    return defaultTimeout;
  }
}
