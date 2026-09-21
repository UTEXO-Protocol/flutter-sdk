// ignore_for_file: constant_identifier_names

import 'package:bip32/bip32.dart';

import '../errors/rgb_sdk_exception.dart';

/// Bitcoin network type alias used by the RN core package.
typedef Network = String;

/// PSBT type alias exported by RN core.
typedef PsbtType = String;

/// BIP86 derivation purpose.
const int DERIVATION_PURPOSE = 86;

/// Account index used by the RN core package.
const int DERIVATION_ACCOUNT = 0;

/// RGB keychain index exported by RN core.
const int KEYCHAIN_RGB = 0;

/// Bitcoin keychain index exported by RN core.
const int KEYCHAIN_BTC = 0;

const int COIN_RGB_MAINNET = 827166;
const int COIN_RGB_TESTNET = 827167;
const int COIN_BITCOIN_MAINNET = 0;
const int COIN_BITCOIN_TESTNET = 1;

const String DEFAULT_NETWORK = 'regtest';
const int DEFAULT_API_TIMEOUT = 120000;
const int DEFAULT_MAX_RETRIES = 3;
const int DEFAULT_LOG_LEVEL = 3;
const String DEFAULT_VSS_SERVER_URL = 'https://vss-server.utexo.com/vss';

/// Network aliases mirrored from `@utexo/rgb-sdk-core`.
const Map<String, Network> NETWORK_MAP = <String, Network>{
  '0': 'mainnet',
  '1': 'testnet',
  '2': 'testnet',
  '3': 'regtest',
  'mainnet': 'mainnet',
  'testnet': 'testnet',
  'testnet4': 'testnet4',
  'signet': 'signet',
  'utexo': 'utexo',
  'regtest': 'regtest',
};

const Map<Network, Map<String, int>> BIP32_VERSIONS =
    <Network, Map<String, int>>{
      'mainnet': <String, int>{'public': 0x0488b21e, 'private': 0x0488ade4},
      'testnet': <String, int>{'public': 0x043587cf, 'private': 0x04358394},
      'testnet4': <String, int>{'public': 0x043587cf, 'private': 0x04358394},
      'signet': <String, int>{'public': 0x043587cf, 'private': 0x04358394},
      'utexo': <String, int>{'public': 0x043587cf, 'private': 0x04358394},
      'regtest': <String, int>{'public': 0x043587cf, 'private': 0x04358394},
    };

const Map<Network, String> DEFAULT_TRANSPORT_ENDPOINTS = <Network, String>{
  'mainnet': 'rpcs://rgb-proxy-mainnet.utexo.com/json-rpc',
  'testnet': 'rpcs://rgb-proxy-testnet3.utexo.com/json-rpc',
  'testnet4': 'rpcs://proxy.iriswallet.com/0.2/json-rpc',
  'signet': 'rpcs://proxy.iriswallet.com/0.2/json-rpc',
  'utexo': 'rpcs://rgb-proxy-utexo.utexo.com/json-rpc',
  'regtest': 'rpcs://proxy.iriswallet.com/0.2/json-rpc',
};

const Map<Network, String> DEFAULT_INDEXER_URLS = <Network, String>{
  'mainnet': 'https://esplora-mainnet.utexo.com',
  'testnet': 'https://esplora-testnet3.utexo.com',
  'testnet4': 'https://esplora-testnet4.utexo.com',
  'signet': 'ssl://electrum.iriswallet.com:50033',
  'utexo': 'https://esplora-api.utexo.com',
  'regtest': 'http://127.0.0.1:3002',
};

class NetworkVersions {
  const NetworkVersions({
    required this.public,
    required this.private,
    required this.wif,
  });

  final int public;
  final int private;
  final int wif;

  NetworkType toBip32Network() {
    return NetworkType(
      wif: wif,
      bip32: Bip32Type(public: public, private: private),
    );
  }
}

NetworkVersions getNetworkVersions(Object bitcoinNetwork) {
  final network = toNetworkName(bitcoinNetwork);
  final versions = BIP32_VERSIONS[network]!;
  return NetworkVersions(
    public: versions['public']!,
    private: versions['private']!,
    wif: network == 'mainnet' ? 0x80 : 0xef,
  );
}

Network toNetworkName(Object bitcoinNetwork) {
  final exact = NETWORK_MAP[bitcoinNetwork.toString()];
  if (exact != null) return exact;
  throw ValidationError(
    'bitcoinNetwork must be one of: ${NETWORK_MAP.keys.join(', ')}; '
        'received $bitcoinNetwork.',
    'bitcoinNetwork',
  );
}

String accountDerivationPath(Object bitcoinNetwork, bool rgb) {
  final network = toNetworkName(bitcoinNetwork);
  final coinType = rgb
      ? (network == 'mainnet' ? COIN_RGB_MAINNET : COIN_RGB_TESTNET)
      : (network == 'mainnet' ? COIN_BITCOIN_MAINNET : COIN_BITCOIN_TESTNET);
  return "m/$DERIVATION_PURPOSE'/$coinType'/$DERIVATION_ACCOUNT'";
}
