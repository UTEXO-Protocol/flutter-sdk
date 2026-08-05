# Public API Reference

This document is the release-line public API contract for the current
`rgb-sdk-flutter` package surface. It does not declare production readiness.
The release verdict remains controlled by
`doc/RELEASE_READINESS_TRACKER.md`.

## Stability Tiers

| Tier | Symbols | Contract |
| --- | --- | --- |
| Stable wallet facade | `RgbSdkFlutter`, `UtexoWallet`, wallet config/request/response types, signer strategies, public wallet errors | Intended for app code, subject to documented breaking-change policy. |
| Advanced/native bridge | `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, `Rln*` native models | Available for RN/native parity, diagnostics, and escape hatches; shape follows the pinned RN/native baseline. |
| Core/domain adapters | `Core*`, `LightningChannel`, mapper extensions, UTEXO bridge/LSP types | Flutter domain adaptation of current RN/core concepts. |
| Compatibility stubs | PSBT and backup/recovery-related symbols | Present for compatibility only when the tracker marks the feature unsupported or native-blocked. |

## Lifecycle Prerequisites

`UtexoWallet` owns the app-facing lifecycle. Call `init()` once, then
`unlock()` with a network service configuration before wallet operations that
need a running native node. After `shutdown()`, regular operations fail until
`reinit()` succeeds. After `destroy()`, the wallet is disposed and cannot be
reused.

`RlnClient` is lower-level and does not protect callers from every lifecycle
mistake; it maps platform failures into SDK errors but still expects a valid
native node ID. `RLNBinding` and `RLNManager` are advanced wrappers around the
same native state and should not be mixed with `UtexoWallet` for the same node
unless a test explicitly owns that interaction.

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

Numeric inputs must fit the current signed 64-bit Pigeon bridge boundary unless
the field is documented as a decimal-string native output.

## Error Taxonomy

Public APIs throw `RgbSdkException` subclasses for SDK-owned error domains:
`ValidationError`, `WalletError`, `WalletException`,
`WalletValidationException`, `ConfigurationError`, `BadRequestError`,
`ConflictError`, `NetworkError`, `NotFoundError`, `RgbNodeError`,
`NativeProtocolException`, `CryptoError`, `SDKError`, and
`UnsupportedWalletFeatureException`.

Native `PlatformException`s must be mapped through `mapNativeBridgeException`
and preserve a `NativeBridgeFailure` cause when bridge metadata exists.
HTTP/LSP failures use `LspError` and the specialized LSP exceptions where the
service layer can classify the failure.

## Side Effects

`init()`, `unlock()`, `reinit()`, `shutdown()`, `destroy()`, sync, send,
receive, channel, issuance, signer, and bridge APIs may create or mutate native
node state. LSP APIs perform network I/O through `IUtexoLspClient`. Pure crypto,
validation, network-default, and model-mapping helpers are deterministic except
for documented secret-buffer wiping.

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
baseline supports them.

## Symbol Coverage Checklist

The documentation validator requires every exported public symbol to appear in
this checklist.

- `AccountXpubs`, `ApayHashEntry`, `ApayInvoiceProof`, `ApayMerkleProofElement`,
  `ApayNewResponse`, `Assignment`, `BadRequestError`, `BeginEndWalletCarrier`,
  `BridgeApiException`, `ChannelReadyInfo`, `ClaimResult`, `ConfigurationError`,
  `ConflictError`, `CoreAsset`, `CoreAssetBalance`, `CoreAssetCfa`,
  `CoreAssetIfa`, `CoreAssetNia`, `CoreAssetUda`, `CoreBalance`,
  `CoreBtcBalance`, `CoreInvoiceData`, `CoreInvoiceReceiveData`,
  `CoreListAssets`, `CoreRgbAllocation`, `CoreTransaction`, `CoreTransfer`,
  `CoreTransferStatus`, `CoreTransferStatuses`, `CoreUnspent`, `CoreUtxo`,
  `CreateHodlInvoiceParams`, `CryptoError`, `FetchClient`, `GeneratedKeys`,
  `HodlInvoice`, `HodlInvoiceResult`, `IRLNExternalSignerBootstrap`,
  `IRLNNodeCreateParams`, `IRLNUnlockParams`, `IUtexoLspClient`,
  `InflateAssetIfaRequest`, `LightningAddressInfo`, `LightningAsset`,
  `LightningChannel`, `LightningPaymentSummary`, `LightningReceiveRequest`,
  `LightningSendRequest`, `ListLightningPaymentsResponse`, `LogLevel`,
  `Logger`, `LspAmountOutOfRangeException`, `LspApayInvoiceProofWire`,
  `LspChannelTimeoutException`, `LspClientConfig`, `LspError`,
  `LspGetInfoResponse`, `LspLightningAddressByPubkeyResponse`,
  `LspLightningReceiveRequest`, `LspLightningReceiveResponse`,
  `LspLiquidityTimeoutException`, `LspLnParams`, `LspLnurlpCallbackResponse`,
  `LspLnurlpCallbackWire`, `LspOnchainSendRequest`, `LspOnchainSendResponse`,
  `LspPeer`, `LspRgbParams`, `LspSettlementException`,
  `LspTransportPolicyException`, `NativeArtifactInfo`, `NativeBridgeFailure`,
  `NativeExternalRlnSigner`, `NativeProtocolException`, `Network`,
  `NetworkAddress`, `NetworkAsset`, `NetworkEndpoints`, `NetworkError`,
  `NetworkVersions`, `NotFoundError`, `OnchainReceiveResponse`,
  `OnchainSendResponse`, `Outpoint`, `ParsedLightningAddress`,
  `PasswordRlnSigner`, `PayAddressAsset`, `PayAddressOptions`,
  `PayAddressResult`, `PsbtType`, `PsbtWalletCarrier`, `ReceiveAssetOptions`,
  `ReceiveAssetResult`, `ReceiveSettlementOutcome`,
  `ReceiveSettlementOutcomes`, `ReceiveStatus`, `ReceiveStatuses`,
  `RgbInvoiceRequest`, `RgbNodeError`, `RgbSdkException`, `RgbSdkFlutter`,
  `RgbSendRequest`, `RLNBinding`, `RLNManager`, `RlnAddress`, `RlnAsset`,
  `RlnAssetBalance`, `RlnAssetCfa`, `RlnAssetIfa`, `RlnAssetNia`,
  `RlnAssetUda`, `RlnAssets`, `RlnAssignmentKind`, `RlnBalance`,
  `RlnBlockTime`, `RlnBtcBalance`, `RlnChannel`, `RlnClient`,
  `RlnCoreAssetBalanceMapper`, `RlnCoreAssetsMapper`, `RlnCoreBalanceMapper`,
  `RlnCoreBtcBalanceMapper`, `RlnCoreDecodedRgbInvoiceMapper`,
  `RlnCoreInvoiceMapper`, `RlnCoreTransactionMapper`,
  `RlnCoreTransferMapper`, `RlnCoreUnspentMapper`, `RlnDecodedLnInvoice`,
  `RlnDecodedRgbInvoice`, `RlnFeeRate`, `RlnIndexerCheck`, `RlnInflateResult`,
  `RlnInvoice`, `RlnInvoiceStatus`, `RlnInvoiceStatuses`,
  `RlnInvoiceStatusValue`, `RlnKeyMaterial`, `RlnLightningChannelMapper`,
  `RlnLnInvoice`, `RlnMap`, `RlnMedia`, `RlnMediaAttachment`,
  `RlnMnemonicKeyMaterial`, `RlnNetworkInfo`, `RlnNodeInfo`,
  `RlnOpenChannelRequest`, `RlnOpenChannelResult`, `RlnPayment`,
  `RlnPaymentResult`, `RlnPaymentStatuses`, `RlnPaymentStatusValue`,
  `RlnPeer`, `RlnRgbAllocation`, `RlnSeedBytesKeyMaterial`,
  `RlnSeedHexKeyMaterial`, `RlnSendResult`, `RlnSignMessageResult`,
  `RlnSigner`, `RlnTokenLight`, `RlnTransaction`, `RlnTransfer`,
  `RlnTransferTransportEndpoint`, `RlnUnspent`, `RlnUtxo`,
  `RlnVerifyMessageResult`, `RlnWitnessData`, `RlnXpubs`, `RNSigner`,
  `SDKError`, `SendAssetOptions`, `SendAssetResult`, `SignMessageParams`,
  `SignPsbtOptions`, `UnsupportedWalletFeatureException`, `UtexoBridgeApiClient`,
  `UtexoLsp`, `UtexoLspClient`, `UtexoLspConfig`, `UtxoNetworkConfig`,
  `UtxoNetworkId`, `UtxoNetworkPreset`, `UtxoNetworkPresetConfig`,
  `UtexoUnlockConfig`, `UtexoWallet`, `UtexoWalletConfig`, `ValidationError`,
  `VerifyMessageParams`, `WaitOptions`, `WalletBackupResponse`,
  `WalletCapabilities`, `WalletError`, `WalletException`,
  `WalletInitParams`, `WalletValidationException`, `accountDerivationPath`,
  `accountXpubsFromMnemonic`, `configureLogging`, `createRLNManager`,
  `createWallet`, `decodeBridgeInvoice`, `deriveKeysFromMnemonic`,
  `deriveKeysFromMnemonicOrSeed`, `deriveKeysFromSeed`, `deriveKeysFromXpriv`,
  `encodeTransferStatus`, `estimatePsbt`, `fromUnitsNumber`, `generateKeys`,
  `getBridgeAPI`, `getDefaultLspBaseUrl`, `getDestinationAsset`,
  `getNetworkDefaults`, `getNetworkVersions`, `getUtxoNetworkConfig`,
  `getXprivFromMnemonic`, `getXpubFromXpriv`, `hostnameOf`,
  `isClaimablePaymentStatus`, `isLoopbackHost`, `isNetwork`,
  `isSameLspHost`, `isTerminalPaymentStatus`, `isUmaAddress`,
  `lnurlDiscoveryUri`, `mapNativeBridgeException`, `normalizeInvoiceStatus`,
  `normalizeLightningAddress`, `normalizeNativeRlnNetwork`, `normalizeNetwork`,
  `normalizePaymentStatus`, `normalizeReceiveStatus`, `normalizeSeedInput`,
  `parseCoreAssignment`, `parseCoreOutpoint`, `parseLightningAddress`, `peerUri`,
  `redactSupportText`, `resolveLspBaseUrl`, `resolveUnlockConfig`,
  `resolveUnlockParams`, `restoreKeys`, `rootNodeFromBase58`,
  `rootNodeFromSeed`, `seedFromMnemonic`, `signMessage`, `signPsbt`,
  `signPsbtFromSeed`, `signSchnorr`, `toNetworkName`, `toUnitsNumber`,
  `tryNormalizeInvoiceStatus`, `tryNormalizePaymentStatus`, `validateBase64`,
  `validateBip39Mnemonic`, `validateHex`, `validateMnemonic`,
  `validateNetwork`, `validatePsbt`, `validateString`, `verifyMessage`,
  `verifySchnorr`, `wipeSecretBytes`, `xOnlyPointFromPoint`.
