part of 'utexo_wallet.dart';

mixin _UtexoWalletGuards on _UtexoWalletInternals {
  @override
  UtexoUnlockConfig _resolveUnlockConfig(UtexoUnlockConfig config) {
    if (_signer is NativeExternalRlnSigner &&
        _blankToNull(config.gossipRgsServerUrl) != null) {
      throw const UnsupportedWalletFeatureException(
        'Native external signer unlock does not support rapid gossip sync.',
        feature: 'unlock.gossipRgsServerUrl',
      );
    }
    return resolveUnlockConfig(_config.network, config);
  }

  @override
  int _requireNode() {
    _ensureActive();
    final id = _nodeId;
    if (id == null) {
      throw const WalletException('Wallet is not initialized.');
    }
    return id;
  }

  @override
  int _requireUnlockedNode() {
    final id = _requireNode();
    if (!isUnlocked) {
      throw const WalletException(
        'Wallet is not unlocked. Call unlock() before wallet operations.',
      );
    }
    return id;
  }

  @override
  void _ensureInitialized() {
    _ensureActive();
    if (!isInitialized || _nodeId == null) {
      throw const WalletException(
        'Wallet is not initialized. Call init() first.',
      );
    }
  }

  @override
  void _ensureActive() {
    _ensureNotDisposed();
    if (_lifecycleState == _WalletLifecycleState.shutDown) {
      throw const WalletException(
        'Wallet is shut down. Call reinit() before regular use.',
      );
    }
    if (_lifecycleState == _WalletLifecycleState.destroying) {
      throw const WalletException('Wallet is being destroyed.');
    }
  }

  @override
  void _ensureNotDisposed() {
    if (_lifecycleState == _WalletLifecycleState.disposed) {
      throw const WalletException('Wallet is disposed.');
    }
  }

  @override
  Future<T> _withLifecycle<T>(Future<T> Function() operation) {
    final next = _lifecycleQueue.then((_) => operation());
    _lifecycleQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  @override
  void _requireNonEmpty(String value, String field) {
    WalletInputPolicy.requireNonEmpty(value, field);
  }

  @override
  void _validateConfig() {
    WalletInputPolicy.validateConfig(_config);
  }

  @override
  void _requirePositive(int value, String field) {
    WalletInputPolicy.requirePositive(value, field);
  }

  @override
  void _requireNonNegative(int value, String field) {
    WalletInputPolicy.requireNonNegative(value, field);
  }

  @override
  void _requireNonNegativeOptional(int? value, String field) {
    WalletInputPolicy.requireNonNegativeOptional(value, field);
  }

  @override
  void _requireNonNegativeList(List<int> values, String field) {
    WalletInputPolicy.requireNonNegativeList(values, field);
  }

  @override
  void _requireUInt8(int value, String field) {
    WalletInputPolicy.requireUInt8(value, field);
  }

  @override
  void _requireUInt8Optional(int? value, String field) {
    WalletInputPolicy.requireUInt8Optional(value, field);
  }

  @override
  void _requireUInt16(int value, String field) {
    WalletInputPolicy.requireUInt16(value, field);
  }

  @override
  void _requireUInt16Optional(int? value, String field) {
    WalletInputPolicy.requireUInt16Optional(value, field);
  }

  @override
  void _requireUInt32(int value, String field) {
    WalletInputPolicy.requireUInt32(value, field);
  }

  @override
  void _requireUInt32Optional(int? value, String field) {
    WalletInputPolicy.requireUInt32Optional(value, field);
  }

  @override
  void _requireFeeRate(double value, String field) {
    WalletInputPolicy.requireIntegerFeeRate(value, field);
  }

  @override
  void _ensureRgbUtxoCreationSupported() {
    if (capabilities.rgbUtxoCreation) return;
    throw const UnsupportedWalletFeatureException(
      'createUtxos is not supported with NativeExternalRlnSigner by the pinned '
      'RLN native artifact.',
      feature: 'nativeExternalSigner.rgbUtxoCreation',
    );
  }

  @override
  void _ensureRgbAssetIssuanceSupported(String operation) {
    if (capabilities.rgbAssetIssuance) return;
    throw UnsupportedWalletFeatureException(
      '$operation is not supported with NativeExternalRlnSigner by the pinned '
      'RLN native artifact.',
      feature: 'nativeExternalSigner.rgbAssetIssuance',
    );
  }

  @override
  void _requireSupportedRgbSendSkipSync(bool skipSync) {
    WalletInputPolicy.requireSupportedRgbSendSkipSync(skipSync);
  }
}
