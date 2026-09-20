import 'package:meta/meta.dart' show internal;

/// Canonical protocol rules shared by the LSP orchestration boundaries.
///
/// This is package-internal. Keeping these rules in one place prevents signed
/// quote verification and native-response decoding from drifting apart.
@internal
abstract final class LspNetworkPolicy {
  /// Returns the native network identity used by signed RGB/BOLT11 payloads.
  static String canonical(String value) {
    return switch (value.trim().toLowerCase()) {
      '0' || 'bitcoin' || 'mainnet' => 'mainnet',
      '1' || '2' || 'testnet3' || 'testnet' => 'testnet',
      '3' || 'regtest' => 'regtest',
      'utexo' || 'signet' => 'signet',
      final normalized => normalized,
    };
  }
}

/// Bounds defined by the RLN APay v1 protocol.
@internal
abstract final class ApayProtocolPolicy {
  static const int protocolVersion = 1;
  static const String activeStatus = 'active';
  static const int firstHashIndex = 1;
  static const int maxHashIndex = 0x7fffffff;
  static const int maxBatchSize = 200;

  static bool isPaymentHash(String value) {
    return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim());
  }
}
