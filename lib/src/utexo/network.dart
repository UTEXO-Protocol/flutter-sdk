import '../crypto/constants.dart';

typedef UtxoNetworkPreset = String;
typedef UtxoNetworkId = String;

class NetworkAsset {
  const NetworkAsset({
    required this.assetId,
    required this.tokenName,
    required this.longName,
    required this.precision,
    required this.tokenId,
  });

  final String assetId;
  final String tokenName;
  final String longName;
  final int precision;
  final int tokenId;
}

class UtxoNetworkConfig {
  const UtxoNetworkConfig({
    required this.networkName,
    required this.networkId,
    required this.assets,
  });

  final String networkName;
  final int networkId;
  final List<NetworkAsset> assets;

  NetworkAsset? getAssetById(int tokenId) {
    for (final asset in assets) {
      if (asset.tokenId == tokenId) return asset;
    }
    return null;
  }
}

class UtxoNetworkPresetConfig {
  const UtxoNetworkPresetConfig({
    required this.networkMap,
    required this.networkIdMap,
  });

  final Map<String, Network> networkMap;
  final Map<UtxoNetworkId, UtxoNetworkConfig> networkIdMap;
}

const UtxoNetworkPresetConfig testnetPreset = UtxoNetworkPresetConfig(
  networkMap: <String, Network>{'mainnet': 'testnet', 'utexo': 'utexo'},
  networkIdMap: <UtxoNetworkId, UtxoNetworkConfig>{
    'mainnet': UtxoNetworkConfig(
      networkName: 'RGB',
      networkId: 36,
      assets: <NetworkAsset>[
        NetworkAsset(
          assetId: 'rgb:WPRv95Nj-icdrgPp-zpQhIp_-2TyJ~Ge-k~FvuMZ-~vVnkA0',
          tokenName: 'tUSD',
          longName: 'USDT',
          precision: 6,
          tokenId: 4,
        ),
      ],
    ),
    'mainnetLightning': UtxoNetworkConfig(
      networkName: 'RGB Lightning',
      networkId: 94,
      assets: <NetworkAsset>[
        NetworkAsset(
          assetId: 'rgb:WPRv95Nj-icdrgPp-zpQhIp_-2TyJ~Ge-k~FvuMZ-~vVnkA0',
          tokenName: 'tUSD',
          longName: 'USDT',
          precision: 6,
          tokenId: 4,
        ),
      ],
    ),
    'utexo': UtxoNetworkConfig(
      networkName: 'UTEXO',
      networkId: 96,
      assets: <NetworkAsset>[
        NetworkAsset(
          assetId: 'rgb:yJW4k8si-~8JdNfl-nM91qFu-r5rH_HS-1hM7jpi-L~lBf90',
          tokenName: 'tUSD',
          longName: 'USDT',
          precision: 6,
          tokenId: 4,
        ),
      ],
    ),
  },
);

const UtxoNetworkPresetConfig mainnetPreset = UtxoNetworkPresetConfig(
  networkMap: <String, Network>{'mainnet': 'mainnet', 'utexo': 'utexo'},
  networkIdMap: <UtxoNetworkId, UtxoNetworkConfig>{
    'mainnet': UtxoNetworkConfig(
      networkName: 'RGB',
      networkId: 36,
      assets: <NetworkAsset>[
        NetworkAsset(
          assetId: 'rgb:nkHbmy97-R4cjRCe-j~VvT~E-0UQ0OW8-jOCCW6O-EqeCq9M',
          tokenName: 'tUSD',
          longName: 'USDT',
          precision: 6,
          tokenId: 3,
        ),
      ],
    ),
    'mainnetLightning': UtxoNetworkConfig(
      networkName: 'RGB Lightning',
      networkId: 94,
      assets: <NetworkAsset>[
        NetworkAsset(
          assetId: 'rgb:nkHbmy97-R4cjRCe-j~VvT~E-0UQ0OW8-jOCCW6O-EqeCq9M',
          tokenName: 'tUSD',
          longName: 'USDT',
          precision: 6,
          tokenId: 3,
        ),
      ],
    ),
    'utexo': UtxoNetworkConfig(
      networkName: 'UTEXO',
      networkId: 96,
      assets: <NetworkAsset>[
        NetworkAsset(
          assetId: 'rgb:0yyfySrb-TArdWKB-6Y0yhUX-dbqMpN3-NnjsV2F-2fMhOI4',
          tokenName: 'tUSD',
          longName: 'USDT',
          precision: 6,
          tokenId: 3,
        ),
      ],
    ),
  },
);

const Map<UtxoNetworkPreset, UtxoNetworkPresetConfig> _networkPresets =
    <UtxoNetworkPreset, UtxoNetworkPresetConfig>{
      'mainnet': mainnetPreset,
      'testnet': testnetPreset,
    };

UtxoNetworkPresetConfig getUtxoNetworkConfig(UtxoNetworkPreset preset) {
  return _networkPresets[preset] ?? testnetPreset;
}

final Map<String, Network> utexoNetworkMap = testnetPreset.networkMap;

final Map<UtxoNetworkId, UtxoNetworkConfig> utexoNetworkIdMap =
    testnetPreset.networkIdMap;

NetworkAsset? getDestinationAsset(
  UtxoNetworkId senderNetwork,
  UtxoNetworkId destinationNetwork,
  String? assetIdSender, [
  Map<UtxoNetworkId, UtxoNetworkConfig>? networkIdMap,
]) {
  final config = networkIdMap ?? utexoNetworkIdMap;
  final destinationConfig = config[destinationNetwork];
  if (destinationConfig == null) return null;
  if (assetIdSender == null) return destinationConfig.assets.firstOrNull;

  final senderConfig = config[senderNetwork];
  if (senderConfig == null) return null;
  NetworkAsset? senderAsset;
  for (final asset in senderConfig.assets) {
    if (asset.assetId == assetIdSender) {
      senderAsset = asset;
      break;
    }
  }
  if (senderAsset == null) return null;
  return destinationConfig.getAssetById(senderAsset.tokenId);
}
