# API Usage Guide

## Layers

`UtexoWallet` is the app-facing API. It owns lifecycle state, validates common
inputs, maps native responses into typed Dart models, and represents unsupported
React Native wallet methods with explicit `UnsupportedWalletFeatureException`s.

`RlnSigner` mirrors the React Native signer strategy layer. Use
`PasswordRlnSigner` for password/mnemonic wallets and `NativeExternalRlnSigner`
for the native external signer flow.

`RlnClient` is the low-level parity layer. It intentionally mirrors the native
`rln*` bridge methods and returns raw platform maps for many calls. Keep app code
off this layer unless you are debugging parity or adding a new wallet facade
method.

Top-level PSBT helpers (`signPsbt`, `signPsbtFromSeed`, `estimatePsbt`) are
RN-parity throwing stubs because RN removed `bdk-rn`. Do not build signing flows
on them.

Top-level key helpers mirror the RN core package:

```dart
final keys = await createWallet('regtest');
final sameKeys = await deriveKeysFromMnemonic('regtest', keys.mnemonic);
final account = await accountXpubsFromMnemonic('regtest', keys.mnemonic);
```

Message signing uses the RN core derivation path and BIP340 Schnorr signatures:

```dart
final signature = await signMessage(
  SignMessageParams(message: 'hello', seed: seedHex, network: 'regtest'),
);

final ok = await verifyMessage(
  VerifyMessageParams(
    message: 'hello',
    signature: signature,
    accountXpub: account.accountXpubVanilla,
    network: 'regtest',
  ),
);
```

## Lifecycle

Create one wallet per node storage directory:

```dart
final wallet = UtexoWallet(config: config);
await wallet.init(password: password);
await wallet.unlock(password: password, config: unlockConfig);
```

Or construct the wallet with a signer, matching the React Native architecture:

```dart
final wallet = UtexoWallet(
  config: config,
  signer: PasswordRlnSigner(password: password, mnemonic: mnemonic),
);

await wallet.init();
await wallet.unlock(config: unlockConfig);
```

Call `shutdown()` when preserving node state and `destroy()` when releasing the
native node handle and marking the Dart object disposed.

Serialize lifecycle-changing calls per wallet instance: `init`, `unlock`,
`reinit`, `shutdown`, `destroy`, and `dispose`. `RlnClient` is intentionally
stateless; use it for bridge parity work and diagnostics, not as a lifecycle
manager. See `doc/BEHAVIORAL_CONTRACT.md` for the complete contract.

For RN-style advanced/testing code, use `RLNBinding` or `RLNManager`:

```dart
final manager = createRLNManager();
await manager.rlnCreateNode(params);
await manager.rlnInitNode(password);
```

Known networks get RN-style unlock defaults. Use `getNetworkDefaults()` or
`resolveUnlockParams()` when product code wants to preview the exact indexer and
proxy values before calling `unlock()`:

```dart
final defaults = getNetworkDefaults('utexo');
final unlock = resolveUnlockParams('utexo', const UtexoUnlockConfig());
```

The `utexo` app network is normalized to native `signet` for node and native
external signer creation, while preserving `wallet.getNetwork() == 'utexo'`.

## Supported Typed Models

The high-level wallet returns typed models for the supported surface:

- `RlnNodeInfo`, `RlnNetworkInfo`, `RlnXpubs`
- `RlnBtcBalance`, `RlnBalance`, `RlnAssetBalance`
- `RlnAssetNia`, `RlnAssetCfa`, `RlnAssetIfa`, `RlnAssetUda`, `RlnAssets`
- `RlnInvoice`, `RlnDecodedRgbInvoice`, `RlnSendResult`
- `RlnTransaction`, `RlnTransfer`, `RlnUnspent`
- `RlnPeer`, `RlnChannel`, `RlnOpenChannelResult`
- `RlnLnInvoice`, `RlnDecodedLnInvoice`, `RlnInvoiceStatus`
- `RlnPayment`, `RlnPaymentResult`
- `LightningReceiveRequest`, `LightningSendRequest`
- `OnchainReceiveResponse`, `OnchainSendResponse`, `WalletBackupResponse`
- `ListLightningPaymentsResponse`, `LightningPaymentSummary`

For RN `rgb-sdk-core`-style data, use the additive `*Core` methods such as
`getBtcBalanceCore()`, `listAssetsCore()`, `blindReceiveCore()`,
`decodeRGBInvoiceCore()`, `listTransactionsCore()`, and `listTransfersCore()`.
The underlying models also expose `toCore()` extensions.

Some high-level methods intentionally keep RN-shaped return values for parity.
For example, `estimateFeeRate()` returns a fee-rate number,
`createLightningInvoice()` returns `LightningReceiveRequest.lnInvoice`,
`payLightningInvoice()` returns `LightningSendRequest`, and
`listLightningPayments()` returns a payment wrapper. Use
`CoreTransferStatuses` constants when checking transfer status values.
Unknown native Lightning status strings map to `null`; use `invoiceStatus()` or
`getPayment()` when raw diagnostic status is needed.

If a high-level method returns `RlnMap`, that method is intentionally unsupported
or parity-only and should not be used in product code.

The facade validates non-negative amounts, bounded UInt-style fields, and finite
fee rates before native calls. Native iOS and Android bridges repeat those
checks before converting to RLN unsigned numeric types.

## RGB Send `skipSync`

`UtexoWallet.send()`, `UtexoWallet.onchainSend()`, and `RlnClient.sendRgb()`
support default RGB sends with `skipSync: false`. Passing `skipSync: true`
throws `UnsupportedWalletFeatureException` before native execution because the
pinned RN-matching RLN artifact has no native `SendRgbRequest.skipSync` field.

Other intentional Flutter divergences from RN are documented in
`doc/BEHAVIORAL_CONTRACT.md`.

## Backup

`UtexoWallet.createBackup()` is exposed for parity and delegates to native
`rlnBackup`. The current RN-matching native bridge reports backup as unsupported
on iOS and Android, so production recovery flows must not depend on it yet.

Do not build app recovery flows on this package until backup is resolved or a
separate recovery architecture has been approved.
