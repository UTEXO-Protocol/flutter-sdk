# Public API Reference

This document is the release-line public API contract for the current
`rgb-sdk-flutter` package surface. It does not declare production readiness.
The release verdict remains controlled by
`doc/RELEASE_READINESS_TRACKER.md`.

## Stability Tiers

| Tier | Symbols | Contract |
| --- | --- | --- |
| Stable wallet facade | `package:rgb_sdk_flutter/rgb_sdk_flutter.dart`: `RgbSdkFlutter`, `UtexoWallet`, wallet config/request/response types, signer strategies, domain DTOs, public wallet errors | Intended for app code, subject to documented breaking-change policy. |
| Advanced/native bridge | `package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart`: `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` native models, native bridge error mapper, logger, and RN compatibility extensions | Available for RN/native parity, diagnostics, migration tools, and explicit escape hatches; shape follows the pinned RN/native baseline. |
| Core/domain adapters | Stable domain `Core*`/`Lightning*` DTOs are root-exported; raw mapper extensions remain advanced-only | Flutter domain adaptation of current RN/core concepts. |
| Compatibility stubs | PSBT and backup/recovery-related symbols | Present for compatibility only when the tracker marks the feature unsupported or native-blocked. |

Canonical `UtexoWallet` methods return stable wallet/domain DTOs, not raw
native wire DTOs. Advanced callers that need the pinned native shape for parity
debugging must use the matching explicit `Raw` method, for example
`listChannelsRaw()`, `getBtcBalanceRaw()`, `decodeLnInvoiceRaw()`, or
`listTransfersRaw()`. Import `rgb_sdk_flutter_advanced.dart` for raw bridge
classes, RN-uppercase compatibility spellings such as `decodeRGBInvoice`, or
RN-style managers. The root import intentionally does not export those names.

## Lifecycle Prerequisites

`UtexoWallet` owns the app-facing lifecycle. Call `init()` once, then
`unlock()` with a network service configuration before wallet operations that
need a running native node. After `shutdown()`, regular operations fail until
`reinit()` succeeds. After `destroy()`, the wallet is disposed and cannot be
reused.

Internally, the wallet facade routes native node operations through its binding
owner so app-facing calls share one serialized lifecycle/operation queue. Signer
strategies may still use the same underlying native client for their private
native signer handles.

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

`UtexoWallet.listTransfers()` calls the native unfiltered listing path. If the
pinned native artifact rejects that call, the SDK throws
`UnsupportedWalletFeatureException` instead of falling back to known asset IDs,
because such a fallback can omit no-asset transfers. Pass `assetId` when an
asset-specific transfer list is acceptable.

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
`LspError` and the specialized LSP exceptions where the service layer can
classify the failure; those LSP types also inherit from the SDK taxonomy so
callers can catch `RgbSdkException` at the stable boundary.

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
- `CoreAssetNia`, `CoreAssetUda`, `CoreBalance`, `CoreBtcBalance`
- `CoreInvoiceData`, `CoreInvoiceReceiveData`, `CoreListAssets`, `CoreRgbAllocation`
- `CoreTransaction`, `CoreTransfer`, `CoreTransferStatus`, `CoreTransferStatuses`
- `CoreUnspent`, `CoreUtxo`, `CreateHodlInvoiceParams`, `CryptoError`
- `DecodedLightningInvoice`, `GeneratedKeys`, `HodlInvoice`, `HodlInvoiceResult`
- `ExperimentalCryptoException`
- `InflateAssetIfaRequest`, `LightningAddressInfo`, `LightningAsset`, `LightningChannel`
- `LightningChannelOpenResult`, `LightningInvoiceStatus`, `LightningPayment`, `LightningPaymentResult`
- `LightningPaymentSummary`, `LightningPeer`, `LightningReceiveRequest`, `LightningSendRequest`
- `ListLightningPaymentsResponse`, `LspAmountOutOfRangeException`, `LspApayInvoiceProofWire`, `LspChannelTimeoutException`
- `LspClientConfig`, `LspError`, `LspGetInfoResponse`, `LspLightningAddressByPubkeyResponse`
- `LspLightningReceiveRequest`, `LspLightningReceiveResponse`, `LspLiquidityTimeoutException`, `LspLnParams`
- `LspLnurlpCallbackResponse`, `LspLnurlpCallbackWire`, `LspOnchainSendRequest`, `LspOnchainSendResponse`
- `LspPeer`, `LspRgbParams`, `LspSettlementException`, `LspSupportedAsset`, `LspTransportPolicyException`
- `NativeArtifactInfo`, `NativeExternalRlnSigner`, `NativeProtocolException`, `Network`
- `NetworkError`, `NetworkVersions`, `NotFoundError`, `OnchainReceiveResponse`
- `OnchainSendResponse`, `OperationCancelledError`, `Outpoint`, `ParsedLightningAddress`, `PasswordRlnSigner`
- `PayAddressAsset`, `PayAddressOptions`, `PayAddressResult`, `PsbtType`
- `PsbtWalletCarrier`, `ReceiveAssetOptions`, `ReceiveAssetResult`, `ReceiveSettlementOutcome`
- `ReceiveSettlementOutcomes`, `ReceiveStatus`, `ReceiveStatuses`, `RgbInvoiceRequest`
- `RgbNodeError`, `RgbSdkException`, `RgbSdkFlutter`, `RgbSendRequest`
- `RlnInvoiceStatusValue`, `RlnInvoiceStatuses`, `RlnKeyMaterial`, `RlnMnemonicKeyMaterial`
- `RlnOperationTimeoutException`, `RlnOperationTimeoutPolicy`, `RlnPaymentStatusValue`, `RlnPaymentStatuses`
- `RlnSeedBytesKeyMaterial`, `RlnSeedHexKeyMaterial`, `RlnSigner`, `SDKError`
- `SchnorrSigningMode`, `SendAssetOptions`, `SendAssetResult`, `SignMessageParams`
- `UnsupportedWalletFeatureException`
- `UtexoLsp`, `UtexoLspConfig`, `UtexoUnlockConfig`, `UtexoWallet`
- `UtexoWalletConfig`, `ValidationError`, `VerifyMessageParams`, `WaitOptions`
- `WalletBackupResponse`, `WalletCapabilities`, `WalletError`, `WalletException`
- `WalletInitParams`, `WalletNetworkInfo`, `WalletNodeInfo`, `WalletValidationException`
- `accountDerivationPath`, `accountXpubsFromMnemonic`, `createWallet`, `deriveKeysFromMnemonic`
- `deriveKeysFromMnemonicOrSeed`, `deriveKeysFromSeed`, `deriveKeysFromXpriv`, `fromUnitsNumber`
- `generateKeys`, `getNetworkVersions`, `getXprivFromMnemonic`, `getXpubFromXpriv`
- `hostnameOf`, `isClaimablePaymentStatus`, `isLoopbackHost`, `isNetwork`
- `isSameLspHost`, `isTerminalPaymentStatus`, `isUmaAddress`, `lnurlDiscoveryUri`
- `normalizeInvoiceStatus`, `normalizeLightningAddress`, `normalizeNetwork`, `normalizePaymentStatus`
- `normalizeReceiveStatus`, `normalizeSeedInput`, `parseCoreAssignment`, `parseCoreOutpoint`
- `parseLightningAddress`, `peerUri`, `redactSupportText`, `resolveUnlockConfig`
- `resolveUnlockParams`, `restoreKeys`, `seedFromMnemonic`, `signMessage`
- `signSchnorr`, `toUnitsNumber`, `tryNormalizeInvoiceStatus`, `tryNormalizePaymentStatus`
- `validateBase64`, `validateBip39Mnemonic`, `validateHex`, `validateMnemonic`
- `validateNetwork`, `validatePsbt`, `validateString`, `verifyMessage`
- `verifySchnorr`, `wipeSecretBytes`, `xOnlyPointFromPoint`
