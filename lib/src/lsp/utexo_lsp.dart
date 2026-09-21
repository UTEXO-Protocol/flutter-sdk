import 'dart:async';

import '../crypto/validation.dart';
import '../errors/rgb_sdk_exception.dart';
import '../models/utexo_core_models.dart';
import '../wallet/utexo_wallet_types.dart';
import 'lsp_address_quote_verifier.dart';
import 'lsp_address_types.dart';
import 'lsp_asset_selection.dart';
import 'lsp_errors.dart';
import 'lsp_flow_types.dart';
import 'lsp_protocol_policy.dart';
import 'lsp_relay_types.dart';
import 'lsp_types.dart';
import 'lsp_wallet.dart';
import 'utexo_lsp_client.dart';

part 'utexo_lsp_address.dart';
part 'utexo_lsp_apay.dart';
part 'utexo_lsp_asset_bridge.dart';
part 'utexo_lsp_bridge_quote_verifier.dart';
part 'utexo_lsp_connection.dart';
part 'utexo_lsp_relay.dart';

const _defaultChannelTimeoutMs = 120000;
const _defaultSettlementTimeoutMs = 60000;
const _defaultPollIntervalMs = 2000;
const _minPollIntervalMs = 50;

abstract class _UtexoLspInternals {
  ILspWallet get wallet;
  LspPeer get peer;
  IUtexoLspClient get http;
  int get nowEpochSeconds;
}

/// Composes LSP channel, bridge, Lightning Address, APay, and relay flows.
class UtexoLsp extends _UtexoLspInternals
    with
        _UtexoLspConnection,
        _UtexoLspAssetBridge,
        _UtexoLspAddress,
        _UtexoLspApay,
        _UtexoLspRelay {
  UtexoLsp({
    required this.wallet,
    required this.peer,
    IUtexoLspClient? httpClient,
    DateTime Function()? clock,
  }) : http =
           httpClient ??
           UtexoLspClient(
             baseUrl: peer.baseUrl,
             bearerToken: peer.bearerToken,
             timeoutMs: peer.timeoutMs,
           ),
       _clock = clock ?? DateTime.now;

  @override
  final ILspWallet wallet;

  @override
  final LspPeer peer;

  /// Direct access to the configured LSP HTTP client.
  @override
  final IUtexoLspClient http;

  final DateTime Function() _clock;

  @override
  int get nowEpochSeconds => _clock().toUtc().millisecondsSinceEpoch ~/ 1000;

  /// Releases resources owned by the HTTP client implementation.
  void close() {
    http.close();
  }

  /// Alias for [close].
  void dispose() {
    close();
  }
}

void _checkCancelled(WaitOptions options) {
  if (options.isCancelled?.call() == true) {
    throw const OperationCancelledError('UtexoLsp operation cancelled.');
  }
}

int _validatedTimeoutMs(WaitOptions options, int fallback) {
  final value = options.timeoutMs ?? fallback;
  if (value <= 0) {
    throw const ValidationError(
      'timeoutMs must be a positive integer.',
      'timeoutMs',
    );
  }
  return value;
}

int _validatedPollIntervalMs(WaitOptions options) {
  final value = options.pollIntervalMs ?? _defaultPollIntervalMs;
  if (value < _minPollIntervalMs) {
    throw ValidationError(
      'pollIntervalMs must be at least $_minPollIntervalMs.',
      'pollIntervalMs',
    );
  }
  return value;
}

bool _isUsableChannel(LightningChannel channel) {
  return channel.isUsable ?? channel.ready;
}

void _requirePositiveMsat(int value, String field) {
  if (value <= 0) {
    throw ValidationError(
      '$field must be a positive integer in millisatoshis.',
      field,
    );
  }
}

Future<Map<String, BigInt>> _localAssetAmounts(ILspWallet wallet) async {
  await wallet.syncWallet();
  final amounts = <String, BigInt>{};
  for (final channel in await wallet.listChannels()) {
    final assetId = channel.assetId;
    if (assetId == null || assetId.isEmpty || !_isUsableChannel(channel)) {
      continue;
    }
    final amount = channel.assetLocalAmount ?? BigInt.zero;
    final current = amounts[assetId] ?? BigInt.zero;
    if (amount > current) amounts[assetId] = amount;
  }
  return Map<String, BigInt>.unmodifiable(amounts);
}

Future<LspLightningAddressByPubkeyResponse> _ownLightningAddress(
  _UtexoLspInternals lsp,
  String operation,
) async {
  final nodeInfo = await lsp.wallet.getNodeInfo();
  if (nodeInfo.pubkey.isEmpty) {
    throw WalletException('$operation requires an unlocked wallet.');
  }
  return _resolveLightningAddress(lsp, nodeInfo.pubkey, operation: operation);
}

Future<LspLightningAddressByPubkeyResponse> _resolveLightningAddress(
  _UtexoLspInternals lsp,
  String pubkey, {
  required String operation,
  int attempts = 8,
  Duration delay = const Duration(seconds: 2),
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    try {
      final address = await lsp.http.getLightningAddressByPubkey(pubkey);
      if (address.username.isNotEmpty && address.domain.isNotEmpty) {
        return address;
      }
    } catch (error) {
      lastError = error;
      if (!_isRetryableAddressProvisioningError(error)) rethrow;
    }
    if (attempt < attempts - 1) await Future<void>.delayed(delay);
  }
  throw NetworkError(
    '$operation: the LSP did not provision a Lightning Address.',
    cause: lastError,
  );
}

bool _isRetryableAddressProvisioningError(Object error) {
  if (error is LspError) {
    return error.status == 0 ||
        error.status == 404 ||
        error.status == 408 ||
        error.status == 425 ||
        error.status == 429 ||
        error.status >= 500;
  }
  return error is NetworkError;
}
