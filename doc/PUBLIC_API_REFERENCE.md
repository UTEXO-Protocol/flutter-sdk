# Public API Reference

This document is the release-line public API contract for the current
`rgb-sdk-flutter` package surface. It does not declare production readiness.
The release verdict remains controlled by
`doc/RELEASE_READINESS_TRACKER.md`.

## Stability Tiers

| Tier | Symbols | Contract |
| --- | --- | --- |
| Stable wallet facade | `package:rgb_sdk_flutter/rgb_sdk_flutter.dart`: `RgbSdkFlutter`, `UtexoWallet`, wallet config/request/response types, signer strategies, domain DTOs, public wallet errors | Intended for app code, subject to documented breaking-change policy. |
| Advanced/native bridge | `package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart`: `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` native models, `createAdvancedUtexoWallet`, native bridge error mapper, logger, and RN/raw compatibility extensions | Available for RN/native parity, diagnostics, migration tools, and explicit escape hatches; shape follows the pinned RN/native baseline. |
| Core/domain adapters | Stable domain `Core*`/`Lightning*` DTOs are root-exported; raw mapper extensions remain advanced-only | Flutter domain adaptation of current RN/core concepts. |
| Capability and blocked boundaries | Absent PSBT/begin-end carriers and native-blocked backup/recovery | Optional carriers are `null`; backup fails explicitly while the tracker marks it native-blocked. |

Canonical `UtexoWallet` methods return stable wallet/domain DTOs, not raw
native wire DTOs. Advanced callers that need the pinned native shape for parity
debugging must use the matching explicit `Raw` method, for example
`listChannelsRaw()`, `getBtcBalanceRaw()`, `decodeLnInvoiceRaw()`, or
`listTransfersRaw()`. Those methods are members of the advanced-only
`UtexoWalletRawApi` extension; importing the stable root alone cannot resolve
them. Import `rgb_sdk_flutter_advanced.dart` for raw bridge classes,
dependency-injected test wallets, RN-uppercase compatibility spellings such as
`decodeRGBInvoice`, or RN-style managers. The root import intentionally does
not export those names or expose `RlnClient`/`RLNBinding` in the stable wallet
constructor.

Custom signer strategies implement `RlnSigner` against the stable
`RlnSignerHost` protocol. The wallet supplies that host and retains native
client ownership; signer implementations must not retain it after an
operation. `IUtexoLspClient` is likewise a stable transport protocol because
RN exports that contract and `UtexoLsp` accepts injected implementations. The
stable root also exports `UtexoLspClient`, matching RN's concrete one-off LSP
client. An injected `http.Client` remains caller-owned unless
`closeHttpClient: true` is explicit; an internally created transport is owned
and closed by `UtexoLspClient`. The internally created transport resolves and
pins a public IP address for each connection while retaining the original host
for TLS/SNI validation. An injected client must provide equivalent proxy,
redirect, DNS-rebinding, and destination-policy enforcement; the SDK cannot
inspect or constrain a caller-owned transport. The raw native client remains
advanced-only.

Asset issuance returns `CoreAssetNia`/`CoreAssetIfa`, `inflate()` returns
`InflateAssetIfaResponse`, `estimateFeeRate()` returns
`FeeEstimationResponse`, and `checkIndexerUrl()` returns
`IndexerCheckResponse`. Their native `Rln*` equivalents are available only
through the advanced raw extension.

Canonical wallet inputs follow RN/core semantics with Dart named parameters or
typed requests. Ordinary read/list methods hide raw bridge sync/filter knobs;
`refreshTransfers(skipSync:)` intentionally exposes the beta.32 switch and
returns immutable per-batch `RefreshedTransfer` outcomes. `refreshWallet()`
retains the shared void compatibility contract. Lightning invoice creation accepts sats plus an optional
`LightningAsset`; payment accepts required `lnInvoice` plus optional sats and
asset fields. Channel opening uses `peerPubkey`, `isPublic`, and
`assetLocalAmount`. `RgbInvoiceRequest.witness` selects the `onchainReceive`
mode; the dedicated blind/witness methods enforce their named mode.

Lightning methods use the core beta.9 domain shapes. `listPayments()` returns
`LightningPayment` records with a required canonical PascalCase status and
optional Unix-second timestamps. `listLightningPayments()` wraps
`LightningSendRequest` records, whose status and RGB consignment endpoint are
optional. `keysend()` returns `SendPaymentResult`. Missing required native
identifiers and malformed boolean/string success fields throw
`NativeProtocolException`; the facade never substitutes an empty identifier or
silently treats malformed data as `false`.

## Lifecycle Prerequisites

`UtexoWallet` owns the app-facing lifecycle. Call `init()` once, then
`unlock()` with a network service configuration before wallet operations that
need a running native node. After `shutdown()`, regular operations fail until
`reinit()` succeeds. After `destroy()`, the wallet is disposed and cannot be
reused.

`vssClearFence(password)` is the deliberate exception to the general unlock
rule: call it after `init()` but before `unlock()` when recovering a stale VSS
single-writer fence. It fails before initialization and does not require an
unlocked node. `backupNow()` still requires an unlocked node.

Internally, the wallet facade routes native node operations through its binding
owner so app-facing calls share one serialized lifecycle/operation queue. Signer
strategies may still use the same underlying native client for their private
native signer handles, but each complete signer operation runs inside the
binding queue and its deadline. Disposal also owns signers whose node creation
or reinitialization failed; node IDs are not signer ownership markers.

The advanced `RlnClient` is lower-level and does not protect callers from every
lifecycle mistake; it maps platform failures into SDK errors but still expects a
valid native node ID. `RLNBinding` and `RLNManager` are advanced wrappers around
the same native state and should not be mixed with `UtexoWallet` for the same
node unless a test explicitly owns that interaction.

## Native Operation Deadlines

The wallet/binding layer applies `RlnOperationTimeoutPolicy` deadlines to
serialized native operations. The default deadline is `DEFAULT_API_TIMEOUT`
(`120000` ms), matching the current core default. Categories exist for
lifecycle, unlock, network, channel/payment, send/asset/UTXO, and sync/refresh
operations.

The pinned Pigeon/RLN bridge cannot cancel a Rust call after native execution
has started. When a deadline elapses, Dart throws
`RlnOperationTimeoutException`, marks the binding state unknown for regular
operations, keeps the internal queue waiting for native completion, and allows
`rlnDestroyNode()`/`UtexoWallet.destroy()` to run afterward as the ordered
cleanup gate. Cleanup itself is not timed out by the binding.

LSP HTTP calls use a separate 15-second default, matching core beta.9. Override
it with `LspPeer.timeoutMs` or `LspClientConfig.timeoutMs` when the deployment
requires a different positive deadline. A stalled quote or discovery request
must not inherit the two-minute native operation deadline.

## Units

| Field family | Unit |
| --- | --- |
| Bitcoin on-chain balances, channel capacity, witness amounts | sats |
| Lightning balances, invoice amounts, HTLC limits | msats |
| RGB asset amounts, issuance, inflation, transfers | asset smallest units according to precision |
| Fee rates | sats/vbyte and integer-equivalent for native bridge calls |
| Expiry/duration inputs | seconds |
| Native timestamps from transfer/invoice/block metadata | Unix seconds unless a field is explicitly named `Ms` |
| Ports, counts, indexes, confirmations | integer native units |

Numeric inputs must fit the current signed 64-bit Pigeon bridge boundary.
Native UInt64 outputs that may exceed that boundary use exact domain types; for
example `RlnNodeInfo.channelAssetMaxAmount` is `BigInt?`.

RGB balances, supplies, decoded Lightning asset amounts, payment/channel RGB
amounts, and fungible assignments are `BigInt` (nullable only where genuinely
optional). `CoreAssetBalance` is separate from Bitcoin's signed `CoreBalance`.
Requests remain signed-int bounded by Pigeon: check the request range before
converting a large read value; never call `toInt()` and assume it is lossless.
`CoreTransfer.requestedAssignment` is retained independently of assignments
actually received. `WalletNodeInfo.localBalanceMsat` is an exact `BigInt`
conversion of native local sats. `blockHeight`, `expirySeconds`, `payee`, and
`HodlInvoice.invoice` are core-compatible aliases of their existing fields.

`NetworkEndpoints` and `getNetworkDefaults()` are stable root helpers for
app-facing network defaults. They expose the selected indexer URL and RGB proxy
endpoint after SDK network normalization. Removed UTEXO bridge/network preset
maps are not retained as dead compatibility code.

`UtexoWallet.listTransfers()` calls RLN 0.13's real unfiltered listing path, so
no-asset transfers are retained. `listTransfers(assetId:)` remains available
for an asset-specific view. `refreshTransfers()` preserves signed Int32 batch
IDs, normalized status changes, and typed failures without inventing an update
for unchanged records.

## LSP and Linked Assets

`UtexoLsp` exposes the core beta.9 connection, receive/send bridge, Lightning
Address, APay, and external relay flows. `receiveAsset()` defaults to
`ReceiveOnchainAsset.convertible`, which omits `asset_id` and lets the LSP
resolve the canonical linked on-chain asset; use `.payout` only when both legs
must use the payout contract. The result reports `onchainAssetId` and
`converted` from the locally decoded RGB invoice rather than trusting optional
service metadata.

`ILspWallet.network` is the canonical native invoice network used for signed
payload comparison: configured `utexo` is exposed as `signet`, and numeric
aliases resolve to their native names. `UtexoWallet.getNetwork()` separately
retains the RN-compatible configured value for application display/config
logic.

Both bridge directions are verified before funds can move. `receiveAsset()`
requires the returned RGB invoice to match the wallet network, requested
amount, selected asset policy, created BOLT11, and expiry. `sendAsset()` decodes
the target RGB invoice before contacting the LSP, then requires the returned
BOLT11 to match its asset, amount, network, expiry, caller overrides, and the
configured LSP payee before calling `payLightningInvoice()`. A mismatch throws
`LspBridgeQuoteVerificationException`; payment is never attempted.
Bridge receive amounts must be positive, and caller-supplied BOLT11 hashes and
CLTV overrides are completely validated before the first LSP mutation.

Lightning Address discovery is routed by the address domain. Calls to the
configured LSP may carry its bearer token; foreign discovery and callbacks are
always unauthenticated. `resolveAddressWithDiscovery()` and
`resolveExternalAddressWithDiscovery()` return an immutable
`LspAddressResolution`, keeping the discovery document and its single callback
result together. The convenience resolution methods delegate to that coherent
exchange. A consuming callback is attempted once: the SDK does not silently
retry after a timeout because the server may already have consumed an APay
payment hash. Asset selection uses the largest balance on any one usable
channel and prefers the payout asset before a convertible asset. It does not
sum liquidity across channels because the current flow does not provide
cross-asset multipart payment.

`quoteExternalPayment()` decodes the target and HODL invoices locally and fails
before payment when their hashes, assets, base-unit amounts, millisatoshi
amounts, networks, timestamps, expiries, payees, fee reconciliation, fee
ceiling, or conversion flag disagree. The HODL invoice must be signed by the
configured LSP and cannot outlive the target invoice. `payExternalInvoice()`
pays only a quote that passed those checks.

`quoteAddress()` verifies the callback BOLT11 amount, RGB asset, asset amount,
network, lifetime, recovered payee, and LNURL metadata description hash before
returning an `AddressQuote`. When an `ApayInvoiceProof` is present, Flutter also
verifies its version and lifetime, payment-hash and host binding, Lightning
Address ownership signature, Merkle inclusion path, and signed batch
commitment. DNS domain case is treated canonically without changing the signed
username. Native `apayNew` responses are bound to the requested host and must
contain a coherent APay v1 hash batch within the BIP32 derivation bounds.
`requestExternalInvoice()` requires that complete proof chain;
proofless legacy LNURL is accepted only by the ordinary quote path. Any failed
check throws `LspAddressQuoteVerificationException` before a payment call.

## Error Taxonomy

Public APIs throw `RgbSdkException` subclasses for SDK-owned error domains:
`ValidationError`, `WalletError`, `WalletException`,
`WalletValidationException`, `ConfigurationError`, `BadRequestError`,
`ConflictError`, `NetworkError`, `NotFoundError`, `RgbNodeError`,
`NativeProtocolException`, `RlnOperationTimeoutException`,
`OperationCancelledError`, `CryptoError`, `ExperimentalCryptoException`,
`SDKError`, and `UnsupportedWalletFeatureException`.

Native `PlatformException`s are mapped by the native bridge boundary before they
reach stable wallet calls. The advanced library exports the mapper and
`NativeBridgeFailure` for bridge tests and diagnostics. HTTP/LSP failures use
`LspError` and specialized failures such as
`LspAmountOutOfRangeException`, `LspNoPayableAssetException`,
`LspUnknownPayableAssetException`, `LspAmbiguousPayableAssetException`,
`LspInsufficientAssetLiquidityException`, `LspQuoteMismatchException`, and
`LspBridgeQuoteVerificationException` where the service layer can classify the
failure. Those LSP types also inherit from the SDK taxonomy so callers can
catch `RgbSdkException` at the stable boundary.

## Side Effects

`init()`, `unlock()`, `reinit()`, `shutdown()`, `destroy()`, sync, send,
receive, channel, issuance, signer, and advanced bridge APIs may create or
mutate native node state. LSP APIs perform network I/O through their configured
client. Pure crypto, validation, network-default, and model helpers are
deterministic except for documented secret-buffer wiping.

## Secret Handling

The SDK does not own durable credential storage. Apps must store passwords,
mnemonics, bearer tokens, RPC credentials, and user secrets in their own secure
storage. SDK-owned byte buffers are defensively copied and wiped where Dart can
guarantee access to mutable bytes; Dart strings, VM copies, BIP32 internals, and
app-owned values cannot be reliably zeroized by this package.

## Platform Support

The current native artifacts target Flutter `3.41.x`, Dart `3.11.x`, Android
min SDK `24`, and iOS `18.5+`. The iOS floor is derived from the pinned RLN
artifact object metadata, not from an aspirational support target.

## Unsupported or Native-Blocked Behavior

`sendRgb(skipSync: true)` fails before native execution because the pinned
native artifacts expose no real request field for it. Local backup/recovery is
native-blocked and must not be marketed as ready. PSBT and begin/end flow
carriers are absent on the stable wallet facade until the upstream/native
baseline supports them. Removed RN package exports such as the old `RNSigner`
wrapper, flat PSBT helpers, and UTEXO bridge/network map helpers are not
exported from the root Dart package. Advanced callers should import
`rgb_sdk_flutter_advanced.dart`; importing implementation files under `src/` is
unsupported.

The pinned RLN 0.13 native artifacts expose additional methods that RN beta.32
does not call: `assetLink`, `assetMetadata`, `getAssetMedia`, `getSwap`,
`listSwaps`, `makerexecute`, `makerinit`, `postassetmedia`,
`sendonionmessage`, `taker`, `attachExternalSigner`, and
`unlockWithAttachedExternalSigner`. They are intentionally outside this
release-line parity surface. The same applies to the native-only
`SdkIssueAssetIfaRequest.issuanceType` field. Adding any of these requires a
reviewed public contract in RN/core first; the Flutter package does not expose
speculative wrappers.

## Key Identity

Top-level `signMessage(SignMessageParams)` and
`verifyMessage(VerifyMessageParams)` are account-key helpers compatible with
RN core and verify against an account xpub. `UtexoWallet.signNodeMessage` and
`UtexoWallet.verifyNodeMessage` use the running RLN node identity key. The
wallet keeps RN's `signMessage` and `verifyMessage` spellings as node-key
aliases. New Dart app code should prefer the explicit node-key names when both
helper families are imported.

Standalone account-key signing uses a pure-Dart BIP340 implementation only when
`SignMessageParams.signingMode` or `signSchnorr(..., signingMode: ...)` is set
to `SchnorrSigningMode.experimentalDart`. The default mode fails closed with
`ExperimentalCryptoException` because that implementation is not audited or
proven constant-time. Production wallet message signing should use the native
RLN-backed wallet node-key methods.

## Symbol Coverage Checklist

The documentation validator requires every root-exported stable symbol to appear in
this checklist. Advanced/parity symbols are intentionally excluded from this
root checklist and are snapshotted by `tool/api_snapshot.json`.

- `AccountXpubs`, `ApayHashEntry`, `ApayInvoiceProof`, `ApayMerkleProofElement`
- `ApayNewResponse`, `Assignment`, `BadRequestError`, `BeginEndWalletCarrier`
- `ChannelReadyInfo`, `ClaimResult`, `ConfigurationError`, `ConflictError`
- `CoreAsset`, `CoreAssetBalance`, `CoreAssetCfa`, `CoreAssetIfa`
- `CoreAssetNia`, `CoreAssetToken`, `CoreAssetUda`, `CoreBalance`, `CoreBlockTime`
- `CoreBtcBalance`, `CoreInvoiceData`, `CoreInvoiceReceiveData`, `CoreListAssets`, `CoreMedia`
- `CoreRgbAllocation`, `CoreTokenAttachment`, `CoreTransaction`, `CoreTransfer`
- `CoreTransferStatus`, `CoreTransferStatuses`, `CoreTransferTransportEndpoint`
- `CoreUnspent`, `CoreUtxo`, `CreateHodlInvoiceParams`, `CryptoError`
- `DecodedLightningInvoice`, `GeneratedKeys`, `HodlInvoice`, `HodlInvoiceResult`
- `ExperimentalCryptoException`
- `LnurlCallbackException`, `PsbtFeeEstimate`
- `FeeEstimationResponse`, `IndexerCheckResponse`, `InflateAssetIfaRequest`, `InflateAssetIfaResponse`
- `AddressQuote`, `AssetSelection`, `ExternalInvoice`, `ExternalInvoiceAssetPreference`
- `ExternalPaymentQuote`, `ExternalPaymentResult`, `IUtexoLspClient`, `ILspWallet`
- `LightningAddressInfo`, `LightningAsset`, `LightningChannel`
- `LightningChannelOpenResult`, `LightningPayment`, `LightningPeer`
- `LightningReceiveRequest`, `LightningSendRequest`, `SendPaymentResult`
- `ListLightningPaymentsResponse`, `LspAmbiguousPayableAssetException`, `LspAmountOutOfRangeException`
- `LspAssetLiquidityCandidate`, `LspChannelTimeoutException`
- `LspClientConfig`, `LspError`, `LspGetInfoResponse`, `LspLightningAddressByPubkeyResponse`
- `LspInsufficientAssetLiquidityException`, `LspLightningReceiveRequest`, `LspLightningReceiveResponse`
- `LspLightningSendLeg`, `LspLightningSendRequest`, `LspLightningSendResponse`, `LspLightningSendStatus`
- `LspLightningSendStatuses`, `LspLightningSendStatusResponse`, `LspLiquidityTimeoutException`, `LspLnParams`
- `LspLnurlpCallbackResponse`, `LspOnchainSendRequest`, `LspOnchainSendResponse`
- `LspLnurlpDiscovery`, `LspNoPayableAssetException`, `LspPeer`, `LspQuoteMismatchException`
- `LspAddressQuoteVerificationException`, `LspAddressResolution`, `LspBridgeQuoteVerificationException`
- `LspRgbParams`
- `LspSettlementException`, `LspSupportedAsset`, `LspTransportPolicyException`
- `LspUnknownPayableAssetException`
- `NativeArtifactInfo`, `NativeExternalRlnSigner`, `NativeProtocolException`, `Network`
- `NetworkEndpoints`, `NetworkError`, `NetworkVersions`, `NotFoundError`, `OnchainReceiveResponse`
- `OnchainSendResponse`, `OperationCancelledError`, `Outpoint`, `ParsedLightningAddress`, `PasswordRlnSigner`
- `PayableAssets`, `PayAddressAssetParam`, `PayAddressOptions`, `PayAddressResult`, `PayExternalInvoiceOptions`
- `PsbtType`, `PsbtWalletCarrier`, `ReceiveAssetOptions`, `ReceiveAssetResult`, `ReceiveOnchainAsset`
- `ReceiveSettlementOutcome`, `RefreshFailure`, `RefreshTransfersResult`, `RefreshedTransfer`
- `ReceiveSettlementOutcomes`, `ReceiveStatus`, `ReceiveStatuses`, `RgbInvoiceRequest`
- `RgbNodeError`, `RgbSdkException`, `RgbSdkFlutter`, `RgbSendRequest`
- `RlnInvoiceStatusValue`, `RlnInvoiceStatuses`, `RlnKeyMaterial`, `RlnMnemonicKeyMaterial`
- `RlnOperationTimeoutException`, `RlnOperationTimeoutPolicy`, `RlnPaymentStatusValue`, `RlnPaymentStatuses`
- `RlnSeedBytesKeyMaterial`, `RlnSeedHexKeyMaterial`, `RlnSigner`, `RlnSignerHost`, `SDKError`
- `RequestExternalInvoiceOptions`, `SchnorrSigningMode`, `SelectPaymentAssetOptions`
- `SendAssetOptions`, `SendAssetResult`, `SignMessageParams`
- `UnsupportedWalletFeatureException`
- `UtexoLsp`, `UtexoLspClient`, `UtexoLspConfig`, `UtexoUnlockConfig`, `UtexoWallet`
- `UtexoWalletConfig`, `ValidationError`, `VerifyMessageParams`, `WaitOptions`
- `WalletBackupResponse`, `WalletCapabilities`, `WalletError`, `WalletException`
- `WalletInitParams`, `WalletNetworkInfo`, `WalletNodeInfo`, `WalletValidationException`
- `accountDerivationPath`, `accountXpubsFromMnemonic`, `createWallet`, `deriveKeysFromMnemonic`
- `deriveKeysFromMnemonicOrSeed`, `deriveKeysFromSeed`, `deriveKeysFromXpriv`, `fromUnitsNumber`
- `generateKeys`, `getNetworkDefaults`, `getNetworkVersions`, `getXprivFromMnemonic`, `getXpubFromXpriv`
- `isClaimablePaymentStatus`, `isNetwork`, `isTerminalPaymentStatus`, `isUmaAddress`
- `normalizeInvoiceStatus`, `normalizeLightningAddress`, `normalizeNetwork`, `normalizePaymentStatus`
- `normalizeReceiveStatus`, `normalizeSeedInput`, `parseCoreAssignment`, `parseCoreOutpoint`
- `parseLightningAddress`, `peerUri`
- `resolveUnlockParams`, `restoreKeys`, `seedFromMnemonic`, `signMessage`
- `signSchnorr`, `toUnitsNumber`, `tryNormalizeInvoiceStatus`, `tryNormalizePaymentStatus`
- `validateBase64`, `validateBip39Mnemonic`, `validateHex`, `validateMnemonic`
- `validateNetwork`, `validatePsbt`, `validateString`, `verifyMessage`
- `verifySchnorr`, `wipeSecretBytes`, `xOnlyPointFromPoint`
