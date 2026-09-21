import '../errors/rgb_sdk_exception.dart';

/// Internal policy owner for stable wallet/domain DTO mapping.
///
/// Raw `Rln*` models decode the native wire contract. Stable `Core*` and
/// `Lightning*` DTOs expose the wallet/domain contract. This policy is the
/// only place that translates native enum/status spelling into the public
/// domain vocabulary.
abstract final class UtexoDomainPolicy {
  /// Recognized native aliases become core names; unknown networks fail closed.
  static String normalizeNetwork(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[_\s-]+'), '');
    final canonical = const <String, String>{
      'bitcoin': 'mainnet',
      'mainnet': 'mainnet',
      'testnet': 'testnet',
      'testnet3': 'testnet',
      'testnet4': 'testnet4',
      'signet': 'signet',
      'signetcustom': 'utexo',
      'utexo': 'utexo',
      'regtest': 'regtest',
    }[key];
    if (canonical != null) return canonical;
    throw const NativeProtocolException(
      'Unsupported native network.',
      field: 'network',
    );
  }

  static const Map<String, String> transactionTypes = <String, String>{
    'RGB_SEND': 'RgbSend',
    'DRAIN': 'Drain',
    'CREATE_UTXOS': 'CreateUtxos',
    'SEND_BTC': 'SendBtc',
    'INCOMING': 'Incoming',
  };

  static const Map<String, String> transferStatuses = <String, String>{
    'initiated': 'Initiated',
    'waitingcounterparty': 'WaitingCounterparty',
    'waitingsafeheight': 'WaitingSafeHeight',
    'waitingbroadcast': 'WaitingBroadcast',
    'waitingconfirmations': 'WaitingConfirmations',
    'settled': 'Settled',
    'failed': 'Failed',
  };

  static const Set<String> transferKinds = <String>{
    'Issuance',
    'ReceiveBlind',
    'ReceiveWitness',
    'Send',
    'Inflation',
    'Burn',
  };

  static const Map<String, String> channelStatuses = <String, String>{
    'opening': 'Opening',
    'opened': 'Opened',
    'closing': 'Closing',
  };

  static String mapTransactionType(String raw) {
    final mapped = transactionTypes[raw];
    if (mapped != null) return mapped;
    throw NativeProtocolException(
      'Unsupported transaction type "$raw".',
      field: 'transactionType',
    );
  }

  static String requireTransferStatus(String raw) {
    final key = raw.trim().replaceAll(RegExp(r'[_\s-]'), '').toLowerCase();
    final status = transferStatuses[key];
    if (status != null) return status;
    throw NativeProtocolException(
      'Unsupported transfer status "$raw".',
      field: 'status',
    );
  }

  static String requireTransferKind(String? raw) {
    if (raw != null && transferKinds.contains(raw)) return raw;
    throw NativeProtocolException(
      'Unsupported transfer kind "$raw".',
      field: 'kind',
    );
  }

  static String normalizeChannelStatus(String raw) {
    final normalized = channelStatuses[raw.toLowerCase()];
    if (normalized != null) return normalized;
    throw NativeProtocolException(
      'Unsupported channel status "$raw".',
      field: 'status',
    );
  }
}
