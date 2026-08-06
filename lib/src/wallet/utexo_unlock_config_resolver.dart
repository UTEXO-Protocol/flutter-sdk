part of 'utexo_wallet.dart';

UtexoUnlockConfig resolveUnlockConfig(
  String network,
  UtexoUnlockConfig config,
) {
  if (config.gossipRgsServerUrl != null &&
      config.gossipRgsServerUrl!.trim().isNotEmpty) {
    throw const UnsupportedWalletFeatureException(
      'gossipRgsServerUrl is not supported by the pinned RLN native signer '
      'unlock APIs and would be ignored by native platforms.',
      feature: 'unlock.gossipRgsServerUrl',
    );
  }
  final defaults = getNetworkDefaults(network);
  final indexerUrl = _blankToNull(config.indexerUrl) ?? defaults?.indexerUrl;
  final proxyEndpoint =
      _blankToNull(config.proxyEndpoint) ?? defaults?.proxyEndpoint;
  final bitcoindRpcHost = _blankToNull(config.bitcoindRpcHost);
  final bitcoindRpcUsername = _blankToNull(config.bitcoindRpcUsername);
  final resolved = UtexoUnlockConfig(
    bitcoindRpcUsername: bitcoindRpcUsername,
    bitcoindRpcPassword: config.bitcoindRpcPassword,
    bitcoindRpcHost: bitcoindRpcHost,
    bitcoindRpcPort: config.bitcoindRpcPort,
    indexerUrl: indexerUrl,
    proxyEndpoint: proxyEndpoint,
    announceAddresses: config.announceAddresses,
    announceAlias: config.announceAlias,
    gossipRgsServerUrl: null,
  );

  final hasIndexer = resolved.indexerUrl != null;
  final hasBitcoind =
      resolved.bitcoindRpcHost != null && resolved.bitcoindRpcUsername != null;
  if (!hasIndexer && !hasBitcoind) {
    throw WalletValidationException(
      'No chain backend configured for network "$network". '
      'Provide indexerUrl or bitcoindRpcHost + bitcoindRpcUsername in unlock config.',
      field: 'indexerUrl',
    );
  }
  return resolved;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

UtexoUnlockConfig resolveUnlockParams(
  String network,
  UtexoUnlockConfig params,
) {
  return resolveUnlockConfig(network, params);
}
