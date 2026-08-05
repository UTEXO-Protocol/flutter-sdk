import '../client/rln_client.dart';
import '../errors/native_bridge_error_mapper.dart';
import '../errors/rgb_sdk_exception.dart';
import '../lsp/lsp_types.dart';
import '../lsp/utexo_lsp.dart';
import '../lsp/utexo_lsp_client.dart';
import '../models/rln_models.dart';
import '../models/utexo_core_models.dart';
import 'network_defaults.dart';
import 'rln_signers.dart';

/// Configuration used to create an RLN node.
class UtexoWalletConfig {
  const UtexoWalletConfig({
    required this.storageDirPath,
    this.network = 'regtest',
    this.daemonListeningPort = 9735,
    this.ldkPeerListeningPort = 9736,
    this.maxMediaUploadSizeMb = 20,
    this.enableVirtualChannelsV0,
    this.virtualPeerPubkeys,
    this.vssUrl,
    this.vssAllowHttp = false,
    this.vssAllowEmptyRestore = false,
    this.lspBaseUrl,
    this.lspBearerToken,
    this.reuseAddresses = false,
    this.xpubVan,
    this.xpubCol,
    this.masterFingerprint,
  });

  final String storageDirPath;
  final String network;
  final int daemonListeningPort;
  final int ldkPeerListeningPort;
  final int maxMediaUploadSizeMb;
  final bool? enableVirtualChannelsV0;
  final List<String>? virtualPeerPubkeys;
  final String? vssUrl;
  final bool vssAllowHttp;
  final bool vssAllowEmptyRestore;
  final String? lspBaseUrl;
  final String? lspBearerToken;
  final bool reuseAddresses;
  final String? xpubVan;
  final String? xpubCol;
  final String? masterFingerprint;
}

/// Network service configuration used to unlock an initialized wallet.
class UtexoUnlockConfig {
  const UtexoUnlockConfig({
    this.bitcoindRpcUsername,
    this.bitcoindRpcPassword,
    this.bitcoindRpcHost,
    this.bitcoindRpcPort,
    this.indexerUrl,
    this.proxyEndpoint,
    this.announceAddresses = const <String>[],
    this.announceAlias,
    this.gossipRgsServerUrl,
  });

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

/// Capability flags for optional wallet feature groups.
///
/// These flags are derived from the public carriers. The current Flutter/RLN
/// platform has no rgb-lib PSBT engine and no externally signed begin/end
/// wallet flows, matching the current React Native contract.
class WalletCapabilities {
  const WalletCapabilities({
    required this.psbtSigning,
    required this.beginEndFlows,
    this.rgbUtxoCreation = true,
    this.rgbAssetIssuance = true,
  });

  final bool psbtSigning;
  final bool beginEndFlows;
  final bool rgbUtxoCreation;
  final bool rgbAssetIssuance;
}

/// Optional PSBT feature group. It is absent while the pinned native/RN
/// baseline has no production PSBT engine.
abstract interface class PsbtWalletCarrier {}

/// Optional begin/end wallet-flow feature group. It is absent while the pinned
/// native/RN baseline has no externally signed begin/end flow.
abstract interface class BeginEndWalletCarrier {}

/// Request for a blinded or witness RGB invoice.
class RgbInvoiceRequest {
  const RgbInvoiceRequest({
    this.assetId,
    this.amount,
    this.durationSeconds,
    this.minConfirmations = 0,
  });

  final String? assetId;
  final int? amount;
  final int? durationSeconds;
  final int minConfirmations;
}

/// Request for an RGB transfer.
///
/// [assetId] and [amount] can be omitted when the invoice encodes them. For
/// asset-less donation invoices, pass them explicitly and set [donation].
class RgbSendRequest {
  const RgbSendRequest({
    required this.invoice,
    this.assetId,
    this.amount,
    this.donation = false,
    this.feeRate = 1,
    this.minConfirmations = 1,
    this.skipSync = false,
    this.witnessAmountSat,
    this.witnessBlinding,
  });

  final String invoice;
  final String? assetId;
  final int? amount;
  final bool donation;
  final double feeRate;
  final int minConfirmations;
  final bool skipSync;
  final int? witnessAmountSat;
  final int? witnessBlinding;
}

/// Request for atomic inflation of an IFA RGB asset.
class InflateAssetIfaRequest {
  const InflateAssetIfaRequest({
    required this.assetId,
    required this.inflationAmounts,
    this.feeRate = 1,
    this.minConfirmations = 1,
  });

  final String assetId;
  final List<int> inflationAmounts;
  final double feeRate;
  final int minConfirmations;
}

/// RN-core transfer status returned by UTEXO status helpers.
///
/// This intentionally remains a string alias for React Native parity. Prefer
/// comparing against [CoreTransferStatuses] constants instead of hard-coding
/// status literals in app code.
typedef CoreTransferStatus = String;
typedef RlnInvoiceStatusValue = String;
typedef RlnPaymentStatusValue = String;

enum _WalletLifecycleState {
  uninitialized,
  initializing,
  initialized,
  unlocking,
  unlocked,
  shutDown,
  destroying,
  disposed,
}

/// Known RN-core transfer-status values.
abstract final class CoreTransferStatuses {
  static const CoreTransferStatus waitingCounterparty = 'WaitingCounterparty';
  static const CoreTransferStatus waitingConfirmations = 'WaitingConfirmations';
  static const CoreTransferStatus settled = 'Settled';
  static const CoreTransferStatus failed = 'Failed';
}

/// Canonical RLN invoice statuses from `@utexo/rgb-sdk-core`.
abstract final class RlnInvoiceStatuses {
  static const RlnInvoiceStatusValue pending = 'Pending';
  static const RlnInvoiceStatusValue claimable = 'Claimable';
  static const RlnInvoiceStatusValue claiming = 'Claiming';
  static const RlnInvoiceStatusValue succeeded = 'Succeeded';
  static const RlnInvoiceStatusValue cancelled = 'Cancelled';
  static const RlnInvoiceStatusValue failed = 'Failed';
  static const RlnInvoiceStatusValue expired = 'Expired';
}

/// Canonical RLN payment statuses from `@utexo/rgb-sdk-core`.
abstract final class RlnPaymentStatuses {
  static const RlnPaymentStatusValue pending = 'Pending';
  static const RlnPaymentStatusValue claimable = 'Claimable';
  static const RlnPaymentStatusValue claiming = 'Claiming';
  static const RlnPaymentStatusValue succeeded = 'Succeeded';
  static const RlnPaymentStatusValue cancelled = 'Cancelled';
  static const RlnPaymentStatusValue failed = 'Failed';
}

const List<RlnInvoiceStatusValue> _invoiceStatusValues = <String>[
  RlnInvoiceStatuses.pending,
  RlnInvoiceStatuses.claimable,
  RlnInvoiceStatuses.claiming,
  RlnInvoiceStatuses.succeeded,
  RlnInvoiceStatuses.cancelled,
  RlnInvoiceStatuses.failed,
  RlnInvoiceStatuses.expired,
];

const List<RlnPaymentStatusValue> _paymentStatusValues = <String>[
  RlnPaymentStatuses.pending,
  RlnPaymentStatuses.claimable,
  RlnPaymentStatuses.claiming,
  RlnPaymentStatuses.succeeded,
  RlnPaymentStatuses.cancelled,
  RlnPaymentStatuses.failed,
];

const Map<String, String> _statusAliases = <String, String>{
  'paid': 'Succeeded',
  'settled': 'Succeeded',
  'success': 'Succeeded',
  'canceled': 'Cancelled',
};

RlnInvoiceStatusValue normalizeInvoiceStatus(Object? raw) {
  return _normalizeStatus(raw, _invoiceStatusValues, 'invoiceStatus');
}

RlnPaymentStatusValue normalizePaymentStatus(Object? raw) {
  return _normalizeStatus(raw, _paymentStatusValues, 'paymentStatus');
}

RlnInvoiceStatusValue? tryNormalizeInvoiceStatus(Object? raw) {
  try {
    return normalizeInvoiceStatus(raw);
  } catch (_) {
    return null;
  }
}

RlnPaymentStatusValue? tryNormalizePaymentStatus(Object? raw) {
  try {
    return normalizePaymentStatus(raw);
  } catch (_) {
    return null;
  }
}

bool isTerminalPaymentStatus(String status) {
  return status == RlnPaymentStatuses.succeeded ||
      status == RlnPaymentStatuses.cancelled ||
      status == RlnPaymentStatuses.failed ||
      status == RlnInvoiceStatuses.expired;
}

bool isClaimablePaymentStatus(String status) {
  return status == RlnPaymentStatuses.claimable ||
      status == RlnPaymentStatuses.claiming;
}

String _normalizeStatus(Object? raw, List<String> allowed, String label) {
  if (raw is! String || raw.trim().isEmpty) {
    throw ValidationError(
      '$label: expected a non-empty string, received $raw',
      label,
    );
  }
  final trimmed = raw.trim();
  final aliased =
      _statusAliases[trimmed.toLowerCase()] ?? _toPascalCase(trimmed);
  for (final value in allowed) {
    if (value == aliased) return value;
  }
  throw ValidationError(
    '$label: unknown value "$raw" (expected one of ${allowed.join(', ')})',
    label,
  );
}

String _toPascalCase(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

/// RN-style Lightning payment list item.
class LightningPaymentSummary {
  const LightningPaymentSummary({required this.txid, required this.status});

  final String txid;
  final String status;
}

/// RN-style wrapper returned by `listLightningPayments`.
class ListLightningPaymentsResponse {
  const ListLightningPaymentsResponse({required this.payments});

  final List<LightningPaymentSummary> payments;
}

/// RN-style response returned by `createBackup`.
class WalletBackupResponse {
  const WalletBackupResponse({required this.message, required this.backupPath});

  final String message;
  final String backupPath;
}

/// LSP configuration captured by the wallet node creation params.
class UtexoLspConfig {
  const UtexoLspConfig({this.baseUrl, this.bearerToken});

  final String? baseUrl;
  final String? bearerToken;
}

/// Optional RGB asset payload for Lightning invoice creation.
class LightningAsset {
  const LightningAsset({required this.assetId, required this.amount});

  final String assetId;
  final int amount;
}

/// RN-style Lightning receive request.
class LightningReceiveRequest {
  const LightningReceiveRequest({required this.lnInvoice});

  final String lnInvoice;

  /// Compatibility alias for earlier Flutter facade callers.
  String get invoice => lnInvoice;
}

/// RN-style Lightning send request/status response.
class LightningSendRequest {
  const LightningSendRequest({required this.txid, required this.status});

  final String txid;
  final String status;
}

/// RN-style on-chain receive response.
class OnchainReceiveResponse {
  const OnchainReceiveResponse({
    required this.invoice,
    this.recipientId,
    this.expirationTimestamp,
    required this.batchTransferIdx,
  });

  factory OnchainReceiveResponse.fromRln(RlnInvoice invoice) {
    return OnchainReceiveResponse(
      invoice: invoice.invoice,
      recipientId: invoice.recipientId,
      expirationTimestamp: invoice.expirationTimestamp,
      batchTransferIdx: invoice.batchTransferIdx,
    );
  }

  final String invoice;
  final String? recipientId;
  final int? expirationTimestamp;
  final int batchTransferIdx;
}

/// RN-style on-chain send response.
class OnchainSendResponse {
  const OnchainSendResponse({
    required this.txid,
    required this.batchTransferIdx,
  });

  factory OnchainSendResponse.fromRln(RlnSendResult result) {
    return OnchainSendResponse(
      txid: result.txid,
      batchTransferIdx: result.batchTransferIdx,
    );
  }

  final String txid;
  final int batchTransferIdx;
}

/// Typed, app-facing wallet facade for Bitcoin, RGB, and RGB Lightning flows.
///
/// The facade owns node lifecycle state and maps supported native responses into
/// Dart models. React Native wallet methods that are absent upstream, depend on
/// RN-only service flows, or are intentionally skipped throw
/// [UnsupportedWalletFeatureException].
class UtexoWallet {
  UtexoWallet({
    required UtexoWalletConfig config,
    RlnClient? client,
    RlnSigner? signer,
  }) : _config = config,
       _client = client ?? RlnClient(),
       _signer = signer;

  final UtexoWalletConfig _config;
  final RlnClient _client;
  RlnSigner? _signer;

  int? _nodeId;
  bool _nodeCreated = false;
  _WalletLifecycleState _lifecycleState = _WalletLifecycleState.uninitialized;
  Future<void>? _initInFlight;
  Future<void>? _unlockInFlight;
  Future<void> _lifecycleQueue = Future<void>.value();
  bool? _resolvedEnableVirtualChannelsV0;
  List<String>? _resolvedVirtualPeerPubkeys;
  String? _resolvedLspBaseUrl;
  PsbtWalletCarrier? get psbt => null;
  BeginEndWalletCarrier? get beginEnd => null;

  int get nodeId => _requireNode();

  bool get isInitialized =>
      _lifecycleState == _WalletLifecycleState.initialized ||
      _lifecycleState == _WalletLifecycleState.unlocking ||
      _lifecycleState == _WalletLifecycleState.unlocked;
  bool get isUnlocked => _lifecycleState == _WalletLifecycleState.unlocked;
  bool get isShutdown => _lifecycleState == _WalletLifecycleState.shutDown;
  bool isDisposed() => _lifecycleState == _WalletLifecycleState.disposed;
  WalletCapabilities get capabilities {
    final supportsExternalSignerRgbAssetFlows =
        _signer is! NativeExternalRlnSigner;
    return WalletCapabilities(
      psbtSigning: psbt != null,
      beginEndFlows: beginEnd != null,
      rgbUtxoCreation: supportsExternalSignerRgbAssetFlows,
      rgbAssetIssuance: supportsExternalSignerRgbAssetFlows,
    );
  }

  String getNetwork() {
    _ensureActive();
    return _config.network;
  }

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
          _nodeId ??= await _createNode();
          _nodeCreated = true;
          final signer = _ensureSigner(password: password, mnemonic: mnemonic);
          try {
            await signer.initNode(
              client: _client,
              nodeId: _nodeId!,
              storageDirPath: _config.storageDirPath,
            );
          } catch (error) {
            if (!hadNode &&
                _nodeId != null &&
                _signer is! NativeExternalRlnSigner) {
              try {
                await _client.destroyNode(_nodeId!);
                _nodeId = null;
                _nodeCreated = false;
              } catch (_) {
                // Preserve the original initialization failure.
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
            await signer.unlockNode(
              client: _client,
              nodeId: _nodeId!,
              config: resolvedConfig,
              storageDirPath: _config.storageDirPath,
            );
          } catch (_) {
            _lifecycleState = _WalletLifecycleState.initialized;
            rethrow;
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
      final existingNodeId = _nodeId;
      if (existingNodeId != null &&
          _lifecycleState != _WalletLifecycleState.shutDown) {
        await _client.shutdown(existingNodeId);
      }
      _lifecycleState = _WalletLifecycleState.initializing;
      final restartedNodeId = await _createNode();
      _nodeId = restartedNodeId;
      _nodeCreated = true;
      _lifecycleState = _WalletLifecycleState.initialized;
      if (unlockConfig != null) {
        final signer = _ensureSigner(password: password, mnemonic: mnemonic);
        final resolvedConfig = _resolveUnlockConfig(unlockConfig);
        _lifecycleState = _WalletLifecycleState.unlocking;
        try {
          await signer.unlockNode(
            client: _client,
            nodeId: _nodeId!,
            config: resolvedConfig,
            storageDirPath: _config.storageDirPath,
          );
        } catch (_) {
          _lifecycleState = _WalletLifecycleState.initialized;
          rethrow;
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
        await _client.shutdown(id);
      } catch (_) {
        _lifecycleState = _WalletLifecycleState.initialized;
        rethrow;
      }
    });
  }

  Future<void> destroy() {
    return _withLifecycle(() async {
      final id = _nodeId;
      final wasShutdown = _lifecycleState == _WalletLifecycleState.shutDown;
      if (_lifecycleState == _WalletLifecycleState.disposed) return;
      _lifecycleState = _WalletLifecycleState.destroying;
      if (id == null) {
        _lifecycleState = _WalletLifecycleState.disposed;
        return;
      }
      final errors = <Object>[];
      if (!wasShutdown) {
        try {
          await _client.shutdown(id);
        } catch (error) {
          errors.add(error);
        }
      }
      try {
        await _signer?.dispose(client: _client, nodeId: id);
      } catch (error) {
        errors.add(error);
      }
      try {
        await _client.destroyNode(id);
      } catch (error) {
        errors.add(error);
      }
      if (errors.isNotEmpty) {
        _lifecycleState = _WalletLifecycleState.initialized;
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

  Future<RlnNodeInfo> nodeInfo() async {
    return RlnNodeInfo.fromMap(await _client.nodeInfo(_requireNode()));
  }

  Future<RlnNodeInfo> getNodeInfo() {
    return nodeInfo();
  }

  Future<RlnNetworkInfo> networkInfo() async {
    return RlnNetworkInfo.fromMap(
      await _client.networkInfo(_requireUnlockedNode()),
    );
  }

  Future<RlnNetworkInfo> getNetworkInfo() {
    return networkInfo();
  }

  Future<RlnXpubs> getXpub() async {
    if (_config.xpubVan != null || _config.xpubCol != null) {
      return RlnXpubs(vanilla: _config.xpubVan, colored: _config.xpubCol);
    }
    final info = await nodeInfo();
    return RlnXpubs(
      vanilla: info.accountXpubVanilla,
      colored: info.accountXpubColored,
    );
  }

  Future<RlnBtcBalance> getBtcBalance({bool skipSync = false}) async {
    return RlnBtcBalance.fromMap(
      await _client.btcBalance(
        nodeId: _requireUnlockedNode(),
        skipSync: skipSync,
      ),
    );
  }

  Future<CoreBtcBalance> getBtcBalanceCore({bool skipSync = false}) async {
    return (await getBtcBalance(skipSync: skipSync)).toCore();
  }

  Future<String> getAddress() async {
    final response = await _client.address(_requireUnlockedNode());
    return response['address']! as String;
  }

  Future<List<RlnUnspent>> listUnspents({bool skipSync = false}) async {
    final unspents = await _client.listUnspents(
      nodeId: _requireUnlockedNode(),
      skipSync: skipSync,
    );
    return unspents.map(RlnUnspent.fromMap).toList(growable: false);
  }

  Future<List<CoreUnspent>> listUnspentsCore({bool skipSync = false}) async {
    return (await listUnspents(
      skipSync: skipSync,
    )).map((unspent) => unspent.toCore()).toList(growable: false);
  }

  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requireUInt8Optional(num, 'num');
    _requireUInt32Optional(size, 'size');
    _requireFeeRate(feeRate, 'feeRate');
    _ensureRgbUtxoCreationSupported();
    await _client.createUtxos(
      nodeId: _requireUnlockedNode(),
      upTo: upTo,
      num: num,
      size: size,
      feeRate: feeRate,
      skipSync: skipSync,
    );
    return num ?? 0;
  }

  Future<RlnAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async {
    return RlnAssets.fromMap(
      await _client.listAssets(
        nodeId: _requireUnlockedNode(),
        filterAssetSchemas: filterAssetSchemas,
      ),
    );
  }

  Future<CoreListAssets> listAssetsCore({
    List<String> filterAssetSchemas = const [],
  }) async {
    return (await listAssets(filterAssetSchemas: filterAssetSchemas)).toCore();
  }

  Future<RlnAssetBalance> getAssetBalance(String assetId) async {
    _requireNonEmpty(assetId, 'assetId');
    return RlnAssetBalance.fromMap(
      await _client.assetBalance(
        nodeId: _requireUnlockedNode(),
        assetId: assetId,
      ),
    );
  }

  Future<CoreAssetBalance> getAssetBalanceCore(String assetId) async {
    return (await getAssetBalance(assetId)).toCore();
  }

  Future<String> rotateVanillaAddress() async {
    final response = await _client.rotateAddress(_requireUnlockedNode());
    return RlnAddress.fromMap(response).address;
  }

  Future<RlnAssetNia> issueAssetNia({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    _requireUInt8(precision, 'precision');
    _requireNonNegativeList(amounts, 'amounts');
    _ensureRgbAssetIssuanceSupported('issueAssetNia');
    return RlnAssetNia.fromMap(
      _asRlnMap(
        await _client.issueAssetNia(
          nodeId: _requireUnlockedNode(),
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
        ),
      ),
    );
  }

  Future<RlnAssetIfa> issueAssetIfa({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    _requireUInt8(precision, 'precision');
    _requireNonNegativeList(amounts, 'amounts');
    _requireNonNegativeList(inflationAmounts, 'inflationAmounts');
    _ensureRgbAssetIssuanceSupported('issueAssetIfa');
    return RlnAssetIfa.fromMap(
      _asRlnMap(
        await _client.issueAssetIfa(
          nodeId: _requireUnlockedNode(),
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
          inflationAmounts: inflationAmounts,
          rejectListUrl: rejectListUrl,
        ),
      ),
    );
  }

  Future<RlnInvoice> blindReceive(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: false);
  }

  Future<CoreInvoiceReceiveData> blindReceiveCore(
    RgbInvoiceRequest request,
  ) async {
    return (await blindReceive(request)).toCore();
  }

  Future<RlnInvoice> witnessReceive(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: true);
  }

  Future<CoreInvoiceReceiveData> witnessReceiveCore(
    RgbInvoiceRequest request,
  ) async {
    return (await witnessReceive(request)).toCore();
  }

  Future<RlnDecodedRgbInvoice> decodeRgbInvoice(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    return RlnDecodedRgbInvoice.fromMap(
      await _client.decodeRgbInvoice(
        nodeId: _requireUnlockedNode(),
        invoice: invoice,
      ),
    );
  }

  Future<RlnDecodedRgbInvoice> decodeRGBInvoice(String invoice) {
    return decodeRgbInvoice(invoice);
  }

  Future<CoreInvoiceData> decodeRGBInvoiceCore(String invoice) async {
    return (await decodeRgbInvoice(invoice)).toCore(invoice);
  }

  Future<RlnSendResult> send(RgbSendRequest request) async {
    _requireNonEmpty(request.invoice, 'invoice');
    final decoded = await decodeRgbInvoice(request.invoice);
    final assetId = request.assetId ?? decoded.assetId;
    final recipientId = decoded.recipientId;
    final amount = request.amount ?? decoded.assignmentAmount;
    final transportEndpoints = decoded.transportEndpoints;

    if (assetId == null || assetId.isEmpty) {
      throw const WalletValidationException(
        'Asset ID is required for RGB send.',
        field: 'assetId',
      );
    }
    if (recipientId.isEmpty) {
      throw const WalletValidationException(
        'Recipient ID is required for RGB send.',
        field: 'recipientId',
      );
    }
    if (amount == null) {
      throw const WalletValidationException(
        'Amount is required for RGB send.',
        field: 'amount',
      );
    }
    _requireNonNegative(amount, 'amount');
    _requireFeeRate(request.feeRate, 'feeRate');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    _requireNonNegativeOptional(request.witnessAmountSat, 'witnessAmountSat');
    _requireNonNegativeOptional(request.witnessBlinding, 'witnessBlinding');
    _requireSupportedRgbSendSkipSync(request.skipSync);

    return RlnSendResult.fromMap(
      await _client.sendRgb(
        nodeId: _requireUnlockedNode(),
        donation: request.donation,
        feeRate: request.feeRate,
        minConfirmations: request.minConfirmations,
        skipSync: request.skipSync,
        assetId: assetId,
        recipientId: recipientId,
        amount: amount,
        transportEndpoints: transportEndpoints,
        witnessAmountSat: request.witnessAmountSat,
        witnessBlinding: request.witnessBlinding,
      ),
    );
  }

  Future<RlnInflateResult> inflate(InflateAssetIfaRequest request) async {
    _requireNonEmpty(request.assetId, 'assetId');
    if (request.inflationAmounts.isEmpty) {
      throw const WalletValidationException(
        'inflationAmounts must not be empty.',
        field: 'inflationAmounts',
      );
    }
    for (var index = 0; index < request.inflationAmounts.length; index++) {
      _requireNonNegative(
        request.inflationAmounts[index],
        'inflationAmounts[$index]',
      );
    }
    _requireFeeRate(request.feeRate, 'feeRate');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    _ensureRgbAssetIssuanceSupported('inflate');
    return RlnInflateResult.fromMap(
      await _client.inflate(
        nodeId: _requireUnlockedNode(),
        assetId: request.assetId,
        inflationAmounts: request.inflationAmounts,
        feeRate: request.feeRate,
        minConfirmations: request.minConfirmations,
      ),
    );
  }

  Future<String> sendBtc({
    required int amount,
    required String address,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requirePositive(amount, 'amount');
    _requireNonEmpty(address, 'address');
    _requireFeeRate(feeRate, 'feeRate');
    final response = await _client.sendBtc(
      nodeId: _requireUnlockedNode(),
      amount: amount,
      address: address,
      feeRate: feeRate,
      skipSync: skipSync,
    );
    return response['txid']! as String;
  }

  Future<List<RlnTransaction>> listTransactions({bool skipSync = false}) async {
    final transactions = await _client.listTransactions(
      nodeId: _requireUnlockedNode(),
      skipSync: skipSync,
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<CoreTransaction>> listTransactionsCore({
    bool skipSync = false,
  }) async {
    return (await listTransactions(
      skipSync: skipSync,
    )).map((transaction) => transaction.toCore()).toList(growable: false);
  }

  Future<List<RlnTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async {
    _requireNonEmpty(txid, 'txid');
    final transactions = await _client.listTransactionsByTxid(
      nodeId: _requireUnlockedNode(),
      txid: txid,
      skipSync: skipSync,
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<RlnTransfer>> listTransfers({String? assetId}) async {
    if (assetId != null) {
      final transfers = await _client.listTransfers(
        nodeId: _requireUnlockedNode(),
        assetId: assetId,
      );
      return transfers.map(RlnTransfer.fromMap).toList(growable: false);
    }

    try {
      final transfers = await _client.listTransfers(
        nodeId: _requireUnlockedNode(),
        assetId: '',
      );
      return transfers.map(RlnTransfer.fromMap).toList(growable: false);
    } on RgbSdkException catch (error) {
      if (!_isInvalidListTransfersRequest(error)) rethrow;
      return _listTransfersForKnownAssets();
    }
  }

  Future<List<CoreTransfer>> listTransfersCore({String? assetId}) async {
    return (await listTransfers(
      assetId: assetId,
    )).map((transfer) => transfer.toCore()).toList(growable: false);
  }

  Future<List<RlnTransfer>> listTransfersByTxid(String txid) async {
    _requireNonEmpty(txid, 'txid');
    final transfers = await _client.listTransfersByTxid(
      nodeId: _requireUnlockedNode(),
      txid: txid,
    );
    return transfers.map(RlnTransfer.fromMap).toList(growable: false);
  }

  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) async {
    _requireNonNegativeOptional(batchTransferIdx, 'batchTransferIdx');
    final response = await _client.failTransfers(
      nodeId: _requireUnlockedNode(),
      batchTransferIdx: batchTransferIdx,
      noAssetOnly: noAssetOnly,
      skipSync: skipSync,
    );
    return response['transfersChanged'] == true;
  }

  Future<void> refreshWallet({bool skipSync = false}) {
    return _client.refreshTransfers(
      nodeId: _requireUnlockedNode(),
      skipSync: skipSync,
    );
  }

  Future<void> syncWallet() => _client.sync(_requireUnlockedNode());

  Future<RlnFeeRate> estimateFeeRate(int blocks) async {
    _requireUInt16(blocks, 'blocks');
    return RlnFeeRate.fromMap(
      await _client.estimateFee(nodeId: _requireUnlockedNode(), blocks: blocks),
    );
  }

  Future<double> estimateFeeRateValue(int blocks) async {
    return (await estimateFeeRate(blocks)).feeRate;
  }

  Future<RlnFeeRate> rlnEstimateFeeRate(int blocks) => estimateFeeRate(blocks);

  Future<RlnIndexerCheck> checkIndexerUrl(String url) async {
    _requireNonEmpty(url, 'url');
    return RlnIndexerCheck.fromMap(
      await _client.checkIndexerUrl(
        nodeId: _requireUnlockedNode(),
        indexerUrl: url,
      ),
    );
  }

  Future<void> checkProxyEndpoint(String endpoint) {
    _requireNonEmpty(endpoint, 'endpoint');
    return _client.checkProxyEndpoint(
      nodeId: _requireUnlockedNode(),
      proxyEndpoint: endpoint,
    );
  }

  Future<WalletBackupResponse> createBackup({
    required String backupPath,
    required String password,
  }) {
    _requireNonEmpty(backupPath, 'backupPath');
    _requireNonEmpty(password, 'password');
    throw const UnsupportedWalletFeatureException(
      'createBackup is native-blocked by the current RLN/RN contract and is '
      'not a recovery-ready API.',
      feature: 'createBackup',
    );
  }

  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? amtMsat,
    int? expirySec,
    String? assetId,
    int? assetAmount,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  }) async {
    _requireNonNegativeOptional(amountSats, 'amountSats');
    final resolvedAmtMsat = amountSats == null ? amtMsat : amountSats * 1000;
    final resolvedExpirySec = expirySec ?? expirySeconds;
    final resolvedAssetId = asset?.assetId ?? assetId;
    final resolvedAssetAmount = resolvedAssetId == null
        ? null
        : (asset?.amount ?? assetAmount);
    final invoice = await createRlnLightningInvoice(
      amtMsat: resolvedAmtMsat,
      expirySec: resolvedExpirySec,
      assetId: resolvedAssetId,
      assetAmount: resolvedAssetAmount,
      paymentHash: null,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
    );
    return LightningReceiveRequest(lnInvoice: invoice.invoice);
  }

  Future<RlnLnInvoice> createRlnLightningInvoice({
    int? amtMsat,
    int expirySec = 3600,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  }) async {
    _requireNonNegativeOptional(amtMsat, 'amtMsat');
    _requireUInt32(expirySec, 'expirySec');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireUInt16Optional(minFinalCltvExpiryDelta, 'minFinalCltvExpiryDelta');
    return RlnLnInvoice.fromMap(
      await _client.lnInvoice(
        nodeId: _requireUnlockedNode(),
        amtMsat: amtMsat,
        expirySec: expirySec,
        assetId: assetId,
        assetAmount: assetAmount,
        paymentHash: paymentHash,
        minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
        descriptionHash: descriptionHash,
      ),
    );
  }

  Future<HodlInvoice> createHodlInvoice(CreateHodlInvoiceParams params) async {
    _requireNonEmpty(params.paymentHash, 'paymentHash');
    _requireNonNegativeOptional(params.amtMsat, 'amtMsat');
    _requireUInt32(params.expirySec, 'expirySec');
    _requireNonNegativeOptional(params.assetAmount, 'assetAmount');
    _requireUInt16Optional(
      params.minFinalCltvExpiryDelta,
      'minFinalCltvExpiryDelta',
    );
    final invoice = await createRlnLightningInvoice(
      amtMsat: params.amtMsat,
      expirySec: params.expirySec,
      assetId: params.assetId,
      assetAmount: params.assetAmount,
      paymentHash: params.paymentHash,
      minFinalCltvExpiryDelta: params.minFinalCltvExpiryDelta,
      descriptionHash: params.descriptionHash,
    );
    return HodlInvoice(
      bolt11: invoice.invoice,
      paymentHash: params.paymentHash,
      amtMsat: params.amtMsat,
      expirySec: params.expirySec,
      assetId: params.assetId,
      assetAmount: params.assetAmount,
      minFinalCltvExpiryDelta: params.minFinalCltvExpiryDelta,
      descriptionHash: params.descriptionHash,
    );
  }

  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  ) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireNonEmpty(preimage, 'preimage');
    final response = await _client.claimHodlInvoice(
      nodeId: _requireUnlockedNode(),
      paymentHash: paymentHash,
      paymentPreimage: preimage,
    );
    return HodlInvoiceResult(changed: response['changed'] == true);
  }

  Future<HodlInvoiceResult> cancelHodlInvoice(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    await _client.cancelHodlInvoice(
      nodeId: _requireUnlockedNode(),
      paymentHash: paymentHash,
    );
    return const HodlInvoiceResult(changed: true);
  }

  Future<List<RlnPayment>> listPaymentsRaw() {
    return listPayments();
  }

  Future<ApayNewResponse> apayNew(String hostNodeId) async {
    _requireNonEmpty(hostNodeId, 'hostNodeId');
    return ApayNewResponse.fromMap(
      await _client.apayNew(
        nodeId: _requireUnlockedNode(),
        hostNodeId: hostNodeId,
      ),
    );
  }

  Future<ApayNewResponse> apayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) async {
    _requireNonEmpty(hostNodeId, 'hostNodeId');
    _requireNonEmpty(username, 'username');
    _requireNonEmpty(domain, 'domain');
    return ApayNewResponse.fromMap(
      await _client.apayNewWithAddress(
        nodeId: _requireUnlockedNode(),
        hostNodeId: hostNodeId,
        username: username,
        domain: domain,
      ),
    );
  }

  Future<UtexoLsp> createLsp([LspPeer? peer, int peerPort = 9735]) async {
    _ensureNotDisposed();
    if (peer != null) return UtexoLsp(wallet: this, peer: peer);
    _ensureVirtualChannelsMutable();
    final baseUrl = resolveLspBaseUrl(_config.network, _config.lspBaseUrl);
    final client = UtexoLspClient(
      baseUrl: baseUrl,
      bearerToken: _config.lspBearerToken,
    );
    try {
      final info = await client.getInfo();
      _enableVirtualChannelsForPeer(info.pubkey);
      final peerHost = Uri.parse(baseUrl).host;
      return UtexoLsp(
        wallet: this,
        peer: LspPeer(
          baseUrl: baseUrl,
          peerPubkey: info.pubkey,
          peerHost: peerHost,
          peerPort: peerPort,
          bearerToken: _config.lspBearerToken,
        ),
        httpClient: client,
      );
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  UtexoLspConfig getLspConfig() {
    return UtexoLspConfig(
      baseUrl: _config.lspBaseUrl,
      bearerToken: _config.lspBearerToken,
    );
  }

  Future<RlnDecodedLnInvoice> decodeLnInvoice(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    return RlnDecodedLnInvoice.fromMap(
      await _client.decodeLnInvoice(
        nodeId: _requireUnlockedNode(),
        invoice: invoice,
      ),
    );
  }

  Future<LightningSendRequest> payLightningInvoice({
    String? lnInvoice,
    String? invoice,
    int? amount,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    final resolvedInvoice = lnInvoice ?? invoice;
    if (resolvedInvoice == null) {
      throw const WalletValidationException(
        'lnInvoice is required.',
        field: 'lnInvoice',
      );
    }
    _requireNonEmpty(resolvedInvoice, 'lnInvoice');
    _requireNonNegativeOptional(amount, 'amount');
    final resolvedAmtMsat = amount == null ? amtMsat : amount * 1000;
    final payment = await payRlnLightningInvoice(
      invoice: resolvedInvoice,
      amtMsat: resolvedAmtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    );
    return LightningSendRequest(
      txid: payment.paymentHash ?? payment.paymentId ?? '',
      status: payment.status,
    );
  }

  Future<RlnPaymentResult> payRlnLightningInvoice({
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireNonNegativeOptional(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    return RlnPaymentResult.fromMap(
      await _client.sendPayment(
        nodeId: _requireUnlockedNode(),
        invoice: invoice,
        amtMsat: amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      ),
    );
  }

  Future<RlnInvoiceStatusValue> getLightningReceiveStatus(String id) async {
    _requireNonEmpty(id, 'id');
    return normalizeInvoiceStatus((await invoiceStatus(id)).status);
  }

  Future<RlnPaymentStatusValue?> getLightningSendStatus(String id) async {
    _requireNonEmpty(id, 'id');
    final payment = await getPayment(id);
    return tryNormalizePaymentStatus(payment.status);
  }

  /// Deprecated compatibility helper that folds Lightning invoice states into
  /// the older RGB transfer-status vocabulary.
  Future<CoreTransferStatus?> getLightningReceiveRequest(String invoice) async {
    return _coreStatusFromNativeStatus(
      await getLightningReceiveStatus(invoice),
    );
  }

  /// Deprecated compatibility helper that folds Lightning payment states into
  /// the older RGB transfer-status vocabulary.
  Future<CoreTransferStatus?> getLightningSendRequest(
    String paymentHash,
  ) async {
    final status = await getLightningSendStatus(paymentHash);
    return status == null ? null : _coreStatusFromNativeStatus(status);
  }

  Future<RlnInvoiceStatus> invoiceStatus(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    return RlnInvoiceStatus.fromMap(
      await _client.invoiceStatus(
        nodeId: _requireUnlockedNode(),
        invoice: invoice,
      ),
    );
  }

  Future<List<RlnPayment>> listPayments() async {
    final payments = await _client.listPayments(_requireUnlockedNode());
    return payments.map(RlnPayment.fromMap).toList(growable: false);
  }

  Future<ListLightningPaymentsResponse> listLightningPayments() async {
    final payments = await listPayments();
    return ListLightningPaymentsResponse(
      payments: payments
          .map(
            (payment) => LightningPaymentSummary(
              txid: payment.paymentHash,
              status: payment.status ?? RlnPaymentStatuses.pending,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<OnchainReceiveResponse> onchainReceive(
    RgbInvoiceRequest request,
  ) async {
    final invoice = await _rgbInvoice(request, witness: true);
    return OnchainReceiveResponse.fromRln(invoice);
  }

  Future<OnchainSendResponse> onchainSend(RgbSendRequest request) async {
    return OnchainSendResponse.fromRln(await send(request));
  }

  Future<List<RlnTransfer>> listOnchainTransfers({String? assetId}) {
    return listTransfers(assetId: assetId);
  }

  Future<void> connectPeer(String peerPubkeyAndAddr) {
    _requireNonEmpty(peerPubkeyAndAddr, 'peerPubkeyAndAddr');
    return _client.connectPeer(
      nodeId: _requireUnlockedNode(),
      peerPubkeyAndAddr: peerPubkeyAndAddr,
    );
  }

  Future<void> disconnectPeer(String peerPubkey) {
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    return _client.disconnectPeer(
      nodeId: _requireUnlockedNode(),
      peerPubkey: peerPubkey,
    );
  }

  Future<List<RlnPeer>> listPeers() async {
    final peers = await _client.listPeers(_requireUnlockedNode());
    return peers.map(RlnPeer.fromMap).toList(growable: false);
  }

  Future<List<RlnChannel>> listChannels() async {
    final channels = await _client.listChannels(_requireUnlockedNode());
    return channels.map(RlnChannel.fromMap).toList(growable: false);
  }

  Future<List<LightningChannel>> listLightningChannels() async {
    return (await listChannels())
        .map((channel) => channel.toLightningChannel())
        .toList(growable: false);
  }

  Future<RlnOpenChannelResult> openChannel({
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    int pushMsat = 0,
    bool publicChannel = false,
    bool withAnchors = true,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) async {
    _requireNonEmpty(peerPubkeyAndOptAddr, 'peerPubkeyAndOptAddr');
    _requirePositive(capacitySat, 'capacitySat');
    _requireNonNegative(pushMsat, 'pushMsat');
    _requireUInt32Optional(feeBaseMsat, 'feeBaseMsat');
    _requireUInt32Optional(
      feeProportionalMillionths,
      'feeProportionalMillionths',
    );
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireNonNegativeOptional(pushAssetAmount, 'pushAssetAmount');
    return RlnOpenChannelResult.fromMap(
      await _client.openChannel(
        nodeId: _requireUnlockedNode(),
        peerPubkeyAndOptAddr: peerPubkeyAndOptAddr,
        capacitySat: capacitySat,
        pushMsat: pushMsat,
        publicChannel: publicChannel,
        withAnchors: withAnchors,
        feeBaseMsat: feeBaseMsat,
        feeProportionalMillionths: feeProportionalMillionths,
        temporaryChannelId: temporaryChannelId,
        assetId: assetId,
        assetAmount: assetAmount,
        pushAssetAmount: pushAssetAmount,
        virtualOpenMode: virtualOpenMode,
      ),
    );
  }

  Future<void> closeChannel({
    required String channelId,
    required String peerPubkey,
    bool force = false,
  }) {
    _requireNonEmpty(channelId, 'channelId');
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    return _client.closeChannel(
      nodeId: _requireUnlockedNode(),
      channelId: channelId,
      peerPubkey: peerPubkey,
      force: force,
    );
  }

  Future<String> getChannelId(String temporaryChannelId) {
    _requireNonEmpty(temporaryChannelId, 'temporaryChannelId');
    return _client.getChannelId(
      nodeId: _requireUnlockedNode(),
      temporaryChannelId: temporaryChannelId,
    );
  }

  Future<RlnPaymentResult> keysend({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(destPubkey, 'destPubkey');
    _requirePositive(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    return RlnPaymentResult.fromMap(
      await _client.keysend(
        nodeId: _requireUnlockedNode(),
        destPubkey: destPubkey,
        amtMsat: amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      ),
    );
  }

  Future<RlnPayment> getPayment(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    return RlnPayment.fromMap(
      await _client.getPayment(
        nodeId: _requireUnlockedNode(),
        paymentHash: paymentHash,
      ),
    );
  }

  Future<String> signMessage(String message) async {
    _requireNonEmpty(message, 'message');
    final response = await _client.signMessage(
      nodeId: _requireUnlockedNode(),
      message: message,
    );
    return RlnSignMessageResult.fromMap(response).signedMessage;
  }

  Future<bool> verifyMessage(String message, String signature) async {
    _requireNonEmpty(message, 'message');
    _requireNonEmpty(signature, 'signature');
    final response = await _client.verifyMessage(
      nodeId: _requireUnlockedNode(),
      message: message,
      signature: signature,
    );
    return RlnVerifyMessageResult.fromMap(response).valid;
  }

  Future<void> vssClearFence(String password) {
    _requireNonEmpty(password, 'password');
    return _client.vssClearFence(
      nodeId: _requireUnlockedNode(),
      password: password,
    );
  }

  Future<int> backupNow() {
    return _client.vssBackup(_requireUnlockedNode());
  }

  RlnSigner _ensureSigner({String? password, String? mnemonic}) {
    final signer = _signer;
    if (signer != null) {
      if (signer is PasswordRlnSigner &&
          password != null &&
          password.isNotEmpty) {
        signer.provideSecrets(password: password, mnemonic: mnemonic);
      }
      return signer;
    }
    if (password == null || password.isEmpty) {
      throw const WalletValidationException(
        'password is required when no RlnSigner is configured.',
        field: 'password',
      );
    }
    return _signer = PasswordRlnSigner(password: password, mnemonic: mnemonic);
  }

  Future<int> _createNode() {
    return _client.createNode(
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
    );
  }

  String? _resolvedNodeLspBaseUrl() {
    final resolved = _resolvedLspBaseUrl;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final explicit = _config.lspBaseUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return getDefaultLspBaseUrl(_config.network);
  }

  void _ensureVirtualChannelsMutable() {
    if (_nodeCreated || _nodeId != null) {
      throw const WalletException(
        'createLsp() must be called before init()/reinit(): virtual-channel '
        'params are baked into the node at init time and cannot be changed '
        'afterwards.',
      );
    }
  }

  void _enableVirtualChannelsForPeer(String peerPubkey) {
    _ensureVirtualChannelsMutable();
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _resolvedEnableVirtualChannelsV0 = true;
    _resolvedLspBaseUrl = resolveLspBaseUrl(
      _config.network,
      _config.lspBaseUrl,
    );
    final existing =
        _resolvedVirtualPeerPubkeys ?? _config.virtualPeerPubkeys ?? const [];
    if (existing.contains(peerPubkey)) {
      _resolvedVirtualPeerPubkeys = List<String>.unmodifiable(existing);
      return;
    }
    _resolvedVirtualPeerPubkeys = List<String>.unmodifiable(<String>[
      ...existing,
      peerPubkey,
    ]);
  }

  UtexoUnlockConfig _resolveUnlockConfig(UtexoUnlockConfig config) {
    return resolveUnlockConfig(_config.network, config);
  }

  Future<List<RlnTransfer>> _listTransfersForKnownAssets() async {
    final assets = await listAssets();
    final transfers = <RlnTransfer>[];
    final seen = <String>{};
    for (final id in assets.assetIds) {
      final assetTransfers = await _client.listTransfers(
        nodeId: _requireUnlockedNode(),
        assetId: id,
      );
      for (final rawTransfer in assetTransfers) {
        final transfer = RlnTransfer.fromMap(rawTransfer);
        if (seen.add(_transferDeduplicationKey(transfer))) {
          transfers.add(transfer);
        }
      }
    }
    return transfers;
  }

  String _transferDeduplicationKey(RlnTransfer transfer) {
    final batchTransferIdx = transfer.batchTransferIdx;
    if (batchTransferIdx != null) return 'batch:$batchTransferIdx';
    return [
      transfer.idx,
      transfer.txid ?? '',
      transfer.recipientId ?? '',
      transfer.kind,
      transfer.status,
    ].join('|');
  }

  bool _isInvalidListTransfersRequest(RgbSdkException error) {
    final cause = error.cause;
    if (cause is! NativeBridgeFailure) return false;
    final message = cause.message;
    return cause.operation == 'rlnListTransfers' &&
        (cause.nativeCode == 'InvalidRequest' ||
            (cause.nativeCode == 'RlnError' &&
                message.contains('InvalidRequest')));
  }

  CoreTransferStatus? _coreStatusFromNativeStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return CoreTransferStatuses.waitingCounterparty;
      case 'CLAIMABLE':
      case 'CLAIMING':
        return CoreTransferStatuses.waitingConfirmations;
      case 'SUCCEEDED':
        return CoreTransferStatuses.settled;
      case 'CANCELLED':
      case 'FAILED':
      case 'EXPIRED':
        return CoreTransferStatuses.failed;
      default:
        return null;
    }
  }

  Future<RlnInvoice> _rgbInvoice(
    RgbInvoiceRequest request, {
    required bool witness,
  }) async {
    _requireNonNegativeOptional(request.amount, 'amount');
    _requireUInt32Optional(request.durationSeconds, 'durationSeconds');
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    return RlnInvoice.fromMap(
      await _client.rgbInvoice(
        nodeId: _requireUnlockedNode(),
        assetId: request.assetId,
        assignmentAmount: request.amount,
        durationSeconds: request.durationSeconds,
        minConfirmations: request.minConfirmations,
        witness: witness,
        assignmentKind: request.amount == null
            ? null
            : RlnAssignmentKind.fungible.wireValue,
      ),
    );
  }

  RlnMap _asRlnMap(Object? value) {
    if (value is RlnMap) return value;
    if (value is Map) return Map<Object?, Object?>.from(value);
    throw const WalletException('Native response was not a map.');
  }

  int _requireNode() {
    _ensureActive();
    final id = _nodeId;
    if (id == null) {
      throw const WalletException('Wallet is not initialized.');
    }
    return id;
  }

  int _requireUnlockedNode() {
    final id = _requireNode();
    if (!isUnlocked) {
      throw const WalletException(
        'Wallet is not unlocked. Call unlock() before wallet operations.',
      );
    }
    return id;
  }

  void _ensureInitialized() {
    _ensureActive();
    if (!isInitialized || _nodeId == null) {
      throw const WalletException(
        'Wallet is not initialized. Call init() first.',
      );
    }
  }

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

  void _ensureNotDisposed() {
    if (_lifecycleState == _WalletLifecycleState.disposed) {
      throw const WalletException('Wallet is disposed.');
    }
  }

  Future<T> _withLifecycle<T>(Future<T> Function() operation) {
    final next = _lifecycleQueue.then((_) => operation());
    _lifecycleQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  void _requireNonEmpty(String value, String field) {
    if (value.isEmpty) {
      throw WalletValidationException(
        '$field must not be empty.',
        field: field,
      );
    }
  }

  void _validateConfig() {
    _requireNonEmpty(_config.storageDirPath, 'storageDirPath');
    _requireUInt16(_config.daemonListeningPort, 'daemonListeningPort');
    _requireUInt16(_config.ldkPeerListeningPort, 'ldkPeerListeningPort');
    _requireUInt16(_config.maxMediaUploadSizeMb, 'maxMediaUploadSizeMb');
  }

  void _requirePositive(int value, String field) {
    if (value <= 0) {
      throw WalletValidationException('$field must be positive.', field: field);
    }
  }

  void _requireNonNegative(int value, String field) {
    if (value < 0) {
      throw WalletValidationException(
        '$field must be non-negative.',
        field: field,
      );
    }
  }

  void _requireNonNegativeOptional(int? value, String field) {
    if (value == null) return;
    _requireNonNegative(value, field);
  }

  void _requireNonNegativeList(List<int> values, String field) {
    for (var index = 0; index < values.length; index += 1) {
      _requireNonNegative(values[index], '$field[$index]');
    }
  }

  void _requireUInt8(int value, String field) {
    if (value < 0 || value > 255) {
      throw WalletValidationException(
        '$field must fit in UInt8.',
        field: field,
      );
    }
  }

  void _requireUInt8Optional(int? value, String field) {
    if (value == null) return;
    _requireUInt8(value, field);
  }

  void _requireUInt16(int value, String field) {
    if (value < 0 || value > 65535) {
      throw WalletValidationException(
        '$field must fit in UInt16.',
        field: field,
      );
    }
  }

  void _requireUInt16Optional(int? value, String field) {
    if (value == null) return;
    _requireUInt16(value, field);
  }

  void _requireUInt32(int value, String field) {
    if (value < 0 || value > 4294967295) {
      throw WalletValidationException(
        '$field must fit in UInt32.',
        field: field,
      );
    }
  }

  void _requireUInt32Optional(int? value, String field) {
    if (value == null) return;
    _requireUInt32(value, field);
  }

  void _requireFeeRate(double value, String field) {
    if (value.isNaN ||
        value.isInfinite ||
        value < 0 ||
        value.truncateToDouble() != value) {
      throw WalletValidationException(
        '$field must be a finite non-negative integer fee rate.',
        field: field,
      );
    }
  }

  void _ensureRgbUtxoCreationSupported() {
    if (capabilities.rgbUtxoCreation) return;
    throw const UnsupportedWalletFeatureException(
      'createUtxos is not supported with NativeExternalRlnSigner by the pinned '
      'RLN native artifact.',
      feature: 'nativeExternalSigner.rgbUtxoCreation',
    );
  }

  void _ensureRgbAssetIssuanceSupported(String operation) {
    if (capabilities.rgbAssetIssuance) return;
    throw UnsupportedWalletFeatureException(
      '$operation is not supported with NativeExternalRlnSigner by the pinned '
      'RLN native artifact.',
      feature: 'nativeExternalSigner.rgbAssetIssuance',
    );
  }

  void _requireSupportedRgbSendSkipSync(bool skipSync) {
    if (!skipSync) return;
    throw const UnsupportedWalletFeatureException(
      'rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.',
      feature: 'rlnSendRgb.skipSync',
    );
  }
}

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
