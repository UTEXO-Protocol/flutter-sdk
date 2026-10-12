import 'package:meta/meta.dart' show internal;

import '../errors/rgb_sdk_exception.dart';

/// Shared facade policy; the pinned native artifact also enforces this rule.
@internal
abstract final class LightningPolicy {
  static void requireEnabled(String network) {
    if (const {
      'mainnet',
      'bitcoin',
      '0',
    }.contains(network.trim().toLowerCase())) {
      throw const WalletError(
        'Lightning is disabled on mainnet. Only on-chain operations are supported.',
        code: 'LIGHTNING_DISABLED_ON_MAINNET',
      );
    }
  }
}
