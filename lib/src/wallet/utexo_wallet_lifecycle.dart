part of 'utexo_wallet.dart';

mixin _UtexoWalletLifecycle on _UtexoWalletInternals {
  Future<void> init({String? password, String? mnemonic}) {
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;
    final future =
        _withLifecycle(() async {
          _ensureNotDisposed();
          if (isInitialized) return;
          if (_lifecycleState == _WalletLifecycleState.shutDown) {
            throw const WalletException(
              'Wallet is shut down. Call reinit() before regular use.',
            );
          }
          _validateConfig();
          final hadNode = _nodeId != null;
          _lifecycleState = _WalletLifecycleState.initializing;
          try {
            _nodeId ??= await _createNode();
            _nodeCreated = true;
          } catch (error, stackTrace) {
            if (!hadNode) {
              _nodeId = null;
              _nodeCreated = false;
            }
            _lifecycleState = hadNode
                ? _WalletLifecycleState.initialized
                : _WalletLifecycleState.uninitialized;
            Error.throwWithStackTrace(error, stackTrace);
          }
          final signer = _ensureSigner(password: password, mnemonic: mnemonic);
          try {
            await initializeRlnSigner(
              signer: signer,
              client: _client,
              nodeId: _nodeId!,
              storageDirPath: _config.storageDirPath,
            );
          } catch (error, stackTrace) {
            if (!hadNode &&
                _nodeId != null &&
                _signer is! NativeExternalRlnSigner) {
              try {
                await _binding.rlnDestroyNode();
                _nodeId = null;
                _nodeCreated = false;
              } catch (cleanupError) {
                _lifecycleState = _WalletLifecycleState.uninitialized;
                Error.throwWithStackTrace(
                  WalletException(
                    'Wallet initialization and temporary node cleanup both '
                    'failed. Call destroy() before retrying.',
                    cause: <Object>[error, cleanupError],
                  ),
                  stackTrace,
                );
              }
            }
            _lifecycleState = _WalletLifecycleState.uninitialized;
            rethrow;
          }
          _lifecycleState = _WalletLifecycleState.initialized;
        }).whenComplete(() {
          _initInFlight = null;
        });
    _initInFlight = future;
    return future;
  }

  Future<void> initialize({String? password, String? mnemonic}) {
    return init(password: password, mnemonic: mnemonic);
  }

  Future<void> unlock({String? password, required UtexoUnlockConfig config}) {
    final inFlight = _unlockInFlight;
    if (inFlight != null) return inFlight;
    final future =
        _withLifecycle(() async {
          _ensureInitialized();
          if (isUnlocked) return;
          final signer = _ensureSigner(password: password);
          final resolvedConfig = _resolveUnlockConfig(config);
          _lifecycleState = _WalletLifecycleState.unlocking;
          try {
            await unlockRlnSigner(
              signer: signer,
              client: _client,
              nodeId: _nodeId!,
              config: resolvedConfig,
              storageDirPath: _config.storageDirPath,
            );
          } catch (error, stackTrace) {
            _lifecycleState = _WalletLifecycleState.initialized;
            Error.throwWithStackTrace(error, stackTrace);
          } finally {
            _markPasswordSignerConsumed(signer);
          }
          _lifecycleState = _WalletLifecycleState.unlocked;
        }).whenComplete(() {
          _unlockInFlight = null;
        });
    _unlockInFlight = future;
    return future;
  }

  Future<void> reinit({
    String? password,
    String? mnemonic,
    UtexoUnlockConfig? unlockConfig,
  }) {
    return _withLifecycle(() async {
      _ensureNotDisposed();
      _validateConfig();
      if (unlockConfig != null) {
        _validateSignerCanUnlock(password: password);
      }
      final previousNodeId = _nodeId;
      final hadPreviousNode = previousNodeId != null;
      final wasShutdown = _lifecycleState == _WalletLifecycleState.shutDown;
      if (hadPreviousNode && !wasShutdown) {
        await _binding.rlnShutdown();
        _lifecycleState = _WalletLifecycleState.shutDown;
      }
      _lifecycleState = _WalletLifecycleState.initializing;
      late final int restartedNodeId;
      try {
        restartedNodeId = await _createNode();
      } catch (error, stackTrace) {
        _nodeId = previousNodeId;
        _nodeCreated = hadPreviousNode;
        _lifecycleState = hadPreviousNode
            ? _WalletLifecycleState.shutDown
            : _WalletLifecycleState.uninitialized;
        Error.throwWithStackTrace(error, stackTrace);
      }
      _nodeId = restartedNodeId;
      _nodeCreated = true;
      _lifecycleState = _WalletLifecycleState.initialized;
      if (unlockConfig != null) {
        final signer = _ensureSigner(password: password, mnemonic: mnemonic);
        final resolvedConfig = _resolveUnlockConfig(unlockConfig);
        _lifecycleState = _WalletLifecycleState.unlocking;
        try {
          await unlockRlnSigner(
            signer: signer,
            client: _client,
            nodeId: _nodeId!,
            config: resolvedConfig,
            storageDirPath: _config.storageDirPath,
          );
        } catch (error, stackTrace) {
          try {
            await _binding.rlnDestroyNode();
          } catch (cleanupError) {
            _nodeId = null;
            _nodeCreated = false;
            _lifecycleState = _WalletLifecycleState.uninitialized;
            Error.throwWithStackTrace(
              WalletException(
                'Wallet reinit unlock and replacement node cleanup both '
                'failed. Call destroy() before retrying.',
                cause: <Object>[error, cleanupError],
              ),
              stackTrace,
            );
          }
          _nodeId = null;
          _nodeCreated = false;
          _lifecycleState = _WalletLifecycleState.uninitialized;
          Error.throwWithStackTrace(error, stackTrace);
        } finally {
          _markPasswordSignerConsumed(signer);
        }
        _lifecycleState = _WalletLifecycleState.unlocked;
      }
    });
  }

  Future<void> shutdown() {
    return _withLifecycle(() async {
      final id = _nodeId;
      if (id == null ||
          _lifecycleState == _WalletLifecycleState.disposed ||
          _lifecycleState == _WalletLifecycleState.shutDown) {
        return;
      }
      _lifecycleState = _WalletLifecycleState.shutDown;
      try {
        await _binding.rlnShutdown();
      } catch (error, stackTrace) {
        _lifecycleState = _WalletLifecycleState.initialized;
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> destroy() {
    return _withLifecycle(() async {
      final id = _nodeId;
      final wasShutdown = _lifecycleState == _WalletLifecycleState.shutDown;
      if (_lifecycleState == _WalletLifecycleState.disposed) return;
      _lifecycleState = _WalletLifecycleState.destroying;
      final errors = <Object>[];
      if (id != null && !wasShutdown) {
        try {
          await _binding.rlnShutdown();
        } catch (error) {
          errors.add(error);
        }
      }
      var signerDisposed = true;
      if (id != null) {
        try {
          final signer = _signer;
          if (signer != null) {
            await disposeRlnSigner(signer: signer, client: _client, nodeId: id);
          }
        } catch (error) {
          signerDisposed = false;
          errors.add(error);
        }
      }
      var nodeDestroyed = false;
      try {
        await _binding.rlnDestroyNode();
        nodeDestroyed = true;
      } catch (error) {
        errors.add(error);
      }
      if (nodeDestroyed && signerDisposed) {
        _nodeId = null;
        _nodeCreated = false;
        _lifecycleState = _WalletLifecycleState.disposed;
      }
      if (errors.isNotEmpty) {
        if (!nodeDestroyed || !signerDisposed) {
          _lifecycleState = _WalletLifecycleState.initialized;
        }
        throw WalletException(
          'Wallet destroy did not complete cleanly.',
          cause: List<Object>.unmodifiable(errors),
        );
      }
      _nodeId = null;
      _nodeCreated = false;
      _lifecycleState = _WalletLifecycleState.disposed;
    });
  }

  Future<void> dispose() => destroy();

  @override
  RlnSigner _ensureSigner({String? password, String? mnemonic}) {
    final signer = _signer;
    if (signer != null) {
      if (signer is PasswordRlnSigner &&
          password != null &&
          password.isNotEmpty) {
        signer.provideSecrets(password: password, mnemonic: mnemonic);
        _passwordSignerPasswordConsumed = false;
      }
      return signer;
    }
    if (password == null || password.isEmpty) {
      throw const WalletValidationException(
        'password is required when no RlnSigner is configured.',
        field: 'password',
      );
    }
    _passwordSignerPasswordConsumed = false;
    return _signer = PasswordRlnSigner(password: password, mnemonic: mnemonic);
  }

  @override
  void _validateSignerCanUnlock({String? password}) {
    if (_signer == null) {
      if (password == null || password.isEmpty) {
        throw const WalletValidationException(
          'password is required when no RlnSigner is configured.',
          field: 'password',
        );
      }
      return;
    }
    if (_signer is PasswordRlnSigner &&
        (password == null || password.isEmpty) &&
        _passwordSignerPasswordConsumed) {
      throw const WalletValidationException(
        'password is required because the previous password was consumed.',
        field: 'password',
      );
    }
  }

  @override
  void _markPasswordSignerConsumed(RlnSigner signer) {
    if (signer is PasswordRlnSigner) {
      _passwordSignerPasswordConsumed = true;
    }
  }

  @override
  Future<int> _createNode() {
    return _binding.rlnCreateNode(
      IRLNNodeCreateParams(
        storageDirPath: _config.storageDirPath,
        daemonListeningPort: _config.daemonListeningPort,
        ldkPeerListeningPort: _config.ldkPeerListeningPort,
        network: normalizeNativeRlnNetwork(_config.network),
        maxMediaUploadSizeMb: _config.maxMediaUploadSizeMb,
        enableVirtualChannelsV0:
            _resolvedEnableVirtualChannelsV0 ?? _config.enableVirtualChannelsV0,
        virtualPeerPubkeys:
            _resolvedVirtualPeerPubkeys ?? _config.virtualPeerPubkeys,
        vssUrl: _config.vssUrl,
        vssAllowHttp: _config.vssAllowHttp,
        vssAllowEmptyRestore: _config.vssAllowEmptyRestore,
        lspBaseUrl: _resolvedNodeLspBaseUrl(),
        lspBearerToken: _config.lspBearerToken,
        reuseAddresses: _config.reuseAddresses,
      ),
    );
  }

  @override
  String? _resolvedNodeLspBaseUrl() {
    final resolved = _resolvedLspBaseUrl;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final explicit = _config.lspBaseUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return getDefaultLspBaseUrl(_config.network);
  }
}
