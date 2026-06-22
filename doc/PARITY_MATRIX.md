# API Parity Matrix

Status legend:

- `planned`: not implemented yet.
- `native-blocked`: Dart exposes/delegates the parity method, but the current
  RN-matching native bridge reports the operation unsupported.
- `blocked`: native artifact does not support it or upstream behavior is unclear.
- `unsupported-parity`: RN exposes the method but throws/not implemented; Dart
  should expose matching typed unsupported behavior.
- `done`: implemented and tested.

## Low-Level Native Bridge Parity

All 55 React Native `NativeRgb` methods must exist in Dart.

The Dart `RlnClient` wrapper now exposes all 55 methods. The status below
tracks native behavior parity, not just public Dart method availability.

| RN method | Flutter API target | Status | Notes |
|---|---|---:|---|
| `rlnCreateNode` | `RlnClient.createNode` | done | Node creation from storage path and ports. |
| `rlnInitNode` | `RlnClient.initNode` | done | Password/mnemonic init. |
| `rlnCreateNativeExternalSigner` | `RlnClient.createNativeExternalSigner` | done | Seed handling security review required. |
| `rlnInitNodeWithNativeExternalSigner` | `RlnClient.initNodeWithNativeExternalSigner` | done | Native signer init. |
| `rlnAttachNativeExternalSigner` | `RlnClient.attachNativeExternalSigner` | done | Required on cold start. |
| `rlnUnlockNodeWithNativeExternalSigner` | `RlnClient.unlockNodeWithNativeExternalSigner` | done | External signer unlock. |
| `rlnDestroyNativeExternalSigner` | `RlnClient.destroyNativeExternalSigner` | done | Release signer handle. |
| `rlnInitNodeWithExternalSigner` | `RlnClient.initNodeWithExternalSigner` | done | Bootstrap-based signer flow. |
| `rlnUnlockNode` | `RlnClient.unlockNode` | done | Password unlock. |
| `rlnDestroyNode` | `RlnClient.destroyNode` | done | Remove handle/release native resources. |
| `rlnNodeInfo` | `RlnClient.nodeInfo` | done | Preserve all native fields where possible. |
| `rlnNetworkInfo` | `RlnClient.networkInfo` | done | Network and height. |
| `rlnListPeers` | `RlnClient.listPeers` | done | Peer pubkeys. |
| `rlnConnectPeer` | `RlnClient.connectPeer` | done | `pubkey@host:port`. |
| `rlnDisconnectPeer` | `RlnClient.disconnectPeer` | done | Peer pubkey. |
| `rlnListChannels` | `RlnClient.listChannels` | done | Include RGB channel fields; status is normalized at the Dart model boundary. |
| `rlnOpenChannel` | `RlnClient.openChannel` | done | BTC and RGB channels. |
| `rlnCloseChannel` | `RlnClient.closeChannel` | done | Cooperative/force. |
| `rlnListPayments` | `RlnClient.listPayments` | done | Preserve payment data and normalize payment type/status casing at the Dart model boundary. |
| `rlnClaimHodlInvoice` | `RlnClient.claimHodlInvoice` | done | HODL invoice settlement. |
| `rlnCancelHodlInvoice` | `RlnClient.cancelHodlInvoice` | done | HODL invoice cancellation. |
| `rlnApayNew` | `RlnClient.apayNew` | done | APay async order creation; response is preserved as a raw native map until upstream formalizes a stable Dart DTO. |
| `rlnApayNewWithAddress` | `RlnClient.apayNewWithAddress` | done | APay async order creation with Lightning Address attestation parameters. |
| `rlnAddress` | `RlnClient.address` | done | On-chain BTC address. |
| `rlnAssetBalance` | `RlnClient.assetBalance` | done | Includes settled/future/spendable and offchain fields. |
| `rlnBackup` | `RlnClient.backup` | native-blocked | Current RN-matching native bridges return unsupported on iOS and Android. |
| `rlnBtcBalance` | `RlnClient.btcBalance` | done | Vanilla + colored balance. |
| `rlnCheckIndexerUrl` | `RlnClient.checkIndexerUrl` | done | Health/diagnostics. |
| `rlnCheckProxyEndpoint` | `RlnClient.checkProxyEndpoint` | done | Health/diagnostics. |
| `rlnCreateUtxos` | `RlnClient.createUtxos` | done | Colorable UTXO setup. The high-level wallet default matches RN `upTo=true`. |
| `rlnDecodeLnInvoice` | `RlnClient.decodeLnInvoice` | done | BOLT11 decode. |
| `rlnDecodeRgbInvoice` | `RlnClient.decodeRgbInvoice` | done | RGB invoice decode. |
| `rlnEstimateFee` | `RlnClient.estimateFee` | done | Fee rate by target blocks. |
| `rlnFailTransfers` | `RlnClient.failTransfers` | done | Recovery operation; covered by fresh-node no-asset smoke. |
| `rlnGetChannelId` | `RlnClient.getChannelId` | done | Temp to permanent id. |
| `rlnGetPayment` | `RlnClient.getPayment` | done | Payment hash lookup; tries outbound and inbound payment types because RN-compatible API only accepts hash. |
| `rlnInvoiceStatus` | `RlnClient.invoiceStatus` | done | Invoice polling; status is uppercased like RN. |
| `rlnKeysend` | `RlnClient.keysend` | done | Advanced payment. |
| `rlnListAssets` | `RlnClient.listAssets` | done | NIA/CFA/IFA/UDA mapped with media/token summaries. |
| `rlnListTransactions` | `RlnClient.listTransactions` | done | On-chain history; transaction type is canonicalized like RN. |
| `rlnListTransfers` | `RlnClient.listTransfers` | done | RGB transfer history by asset id. |
| `rlnListUnspents` | `RlnClient.listUnspents` | done | UTXO and RGB allocations. |
| `rlnLnInvoice` | `RlnClient.lnInvoice` | done | BTC or RGB LN invoice. |
| `rlnRefreshTransfers` | `RlnClient.refreshTransfers` | done | Covered by fresh-node smoke. |
| `rlnRgbInvoice` | `RlnClient.rgbInvoice` | done | Blind/witness invoice; funded RGB flow covered by host-coordinated smoke. |
| `rlnSendBtc` | `RlnClient.sendBtc` | done | BTC on-chain send. |
| `rlnSendPayment` | `RlnClient.sendPayment` | done | LN payment. |
| `rlnSendRgb` | `RlnClient.sendRgb` | done | Single-recipient on-chain RGB send bridge. `skipSync: true` is rejected before native execution because the pinned `0.6.0-beta.2` native `SendRgbRequest` has no `skipSync` field. |
| `rlnShutdown` | `RlnClient.shutdown` | done | Graceful stop. |
| `rlnSync` | `RlnClient.sync` | done | Blockchain sync. |
| `rlnVssClearFence` | `RlnClient.vssClearFence` | done | VSS fence reset helper added by RN beta.17. |
| `rlnIssueAssetNia` | `RlnClient.issueAssetNia` | done | Non-inflationary asset. |
| `rlnIssueAssetCfa` | `RlnClient.issueAssetCfa` | done | Collectible/fractional asset. |
| `rlnIssueAssetIfa` | `RlnClient.issueAssetIfa` | done | Inflatable asset. |
| `rlnIssueAssetUda` | `RlnClient.issueAssetUda` | done | Unique digital asset. |

## High-Level Wallet Parity

| RN `UTEXOWallet` method | Flutter API target | Status | Notes |
|---|---|---:|---|
| `init` | `UtexoWallet.init` | done | Create node and initialize signer. |
| `unlock` | `UtexoWallet.unlock` | done | Unlock node with network services through password or configured signer. |
| `reinit` | `UtexoWallet.reinit` | done | Recreate manager and optionally unlock after initial init. |
| `shutdown` | `UtexoWallet.shutdown` | done | Preserve node state. |
| `destroy` | `UtexoWallet.destroy` | done | Shutdown, destroy node, dispose signer. |
| `initialize` | `UtexoWallet.initialize` | done | Alias for `init`. |
| `goOnline` | `UtexoWallet.goOnline` | unsupported-parity | RN says use `unlock`. |
| `getXpub` | `UtexoWallet.getXpub` | done | Uses constructor xpubs when supplied, otherwise `nodeInfo`. |
| `getNetwork` | `UtexoWallet.getNetwork` | done | From wallet config. |
| `dispose` | `UtexoWallet.dispose` | done | Alias for destroy. |
| `isDisposed` | `UtexoWallet.isDisposed` | done | Local lifecycle flag. |
| `getBtcBalance` | `UtexoWallet.getBtcBalance` | done | Low-level `rlnBtcBalance`. |
| `getAddress` | `UtexoWallet.getAddress` | done | Low-level `rlnAddress`. |
| `rotateVanillaAddress` | `UtexoWallet.rotateVanillaAddress` | unsupported-parity | RN not implemented. |
| `rotateColoredAddress` | `UtexoWallet.rotateColoredAddress` | unsupported-parity | RN not implemented. |
| `listUnspents` | `UtexoWallet.listUnspents` | done | Low-level unspents. |
| `createUtxosBegin` | `UtexoWallet.createUtxosBegin` | unsupported-parity | RN not implemented. |
| `createUtxosEnd` | `UtexoWallet.createUtxosEnd` | unsupported-parity | RN not implemented. |
| `createUtxos` | `UtexoWallet.createUtxos` | done | All-in-one method; defaults `upTo=true` and returns `num ?? 0` like RN. |
| `listAssets` | `UtexoWallet.listAssets` | done | Asset groups. |
| `getAssetBalance` | `UtexoWallet.getAssetBalance` | done | Asset balance. |
| `issueAssetNia` | `UtexoWallet.issueAssetNia` | done | Returns typed NIA asset model. |
| `issueAssetIfa` | `UtexoWallet.issueAssetIfa` | done | Returns typed IFA asset model. |
| `inflateBegin` | `UtexoWallet.inflateBegin` | unsupported-parity | RN not implemented. |
| `inflateEnd` | `UtexoWallet.inflateEnd` | unsupported-parity | RN not implemented. |
| `inflate` | `UtexoWallet.inflate` | unsupported-parity | RN not implemented. |
| `sendBegin` | `UtexoWallet.sendBegin` | unsupported-parity | RN not implemented. |
| `sendEnd` | `UtexoWallet.sendEnd` | unsupported-parity | RN not implemented. |
| `send` | `UtexoWallet.send` | done | Decode RGB invoice then send. `skipSync: true` fails fast because the pinned native RGB send request cannot carry it. |
| `sendBtcBegin` | `UtexoWallet.sendBtcBegin` | unsupported-parity | RN not implemented. |
| `sendBtcEnd` | `UtexoWallet.sendBtcEnd` | unsupported-parity | RN not implemented. |
| `sendBtc` | `UtexoWallet.sendBtc` | done | Low-level `rlnSendBtc`. |
| `blindReceive` | `UtexoWallet.blindReceive` | done | RGB invoice witness false. |
| `witnessReceive` | `UtexoWallet.witnessReceive` | done | RGB invoice witness true. |
| `decodeRGBInvoice` | `UtexoWallet.decodeRgbInvoice` | done | Decode and map. |
| `listTransactions` | `UtexoWallet.listTransactions` | done | On-chain history. |
| `listTransfers` | `UtexoWallet.listTransfers` | done | RGB transfers. |
| `failTransfers` | `UtexoWallet.failTransfers` | done | Recovery operation. |
| `refreshWallet` | `UtexoWallet.refreshWallet` | done | Refresh RGB transfers. |
| `syncWallet` | `UtexoWallet.syncWallet` | done | Node sync. |
| `configureVssBackup` | `UtexoWallet.configureVssBackup` | unsupported-parity | RN not implemented. |
| `disableVssAutoBackup` | `UtexoWallet.disableVssAutoBackup` | unsupported-parity | RN not implemented. |
| `vssBackup` | `UtexoWallet.vssBackup` | unsupported-parity | RN not implemented. |
| `vssBackupInfo` | `UtexoWallet.vssBackupInfo` | unsupported-parity | RN not implemented. |
| `estimateFeeRate` | `UtexoWallet.estimateFeeRate` | done | Returns RN-shaped fee-rate number. |
| `estimateFee` | `UtexoWallet.estimateFee` | unsupported-parity | RN not implemented. |
| `createBackup` | `UtexoWallet.createBackup` | native-blocked | Delegates to native `rlnBackup` and returns `WalletBackupResponse` only if native succeeds. Current native bridge reports unsupported like RN. |
| `signPsbt` | `UtexoWallet.signPsbt` | unsupported-parity | RN not implemented. |
| `signMessage` | `UtexoWallet.signMessage` | unsupported-parity | RN not implemented. |
| `verifyMessage` | `UtexoWallet.verifyMessage` | unsupported-parity | RN not implemented. |
| `createLightningInvoice` | `UtexoWallet.createLightningInvoice` | done | Returns RN-style `LightningReceiveRequest.lnInvoice`; raw helper remains `createRlnLightningInvoice`. |
| `createHodlInvoice` | `UtexoWallet.createHodlInvoice` | done | HODL invoice helper added by current RN `dev`. |
| `claimHodlInvoice` | `UtexoWallet.claimHodlInvoice` | done | HODL invoice claim helper. |
| `cancelHodlInvoice` | `UtexoWallet.cancelHodlInvoice` | done | HODL invoice cancel helper. |
| `getLightningReceiveRequest` | `UtexoWallet.getLightningReceiveRequest` | done | Maps invoice status to RN core transfer status. |
| `getLightningSendRequest` | `UtexoWallet.getLightningSendRequest` | done | Looks up payment hash and maps to RN core transfer status. |
| `getLightningSendFeeEstimate` | `UtexoWallet.getLightningSendFeeEstimate` | unsupported-parity | RN not implemented. |
| `payLightningInvoiceBegin` | `UtexoWallet.payLightningInvoiceBegin` | unsupported-parity | RN not implemented. |
| `payLightningInvoiceEnd` | `UtexoWallet.payLightningInvoiceEnd` | unsupported-parity | RN not implemented. |
| `payLightningInvoice` | `UtexoWallet.payLightningInvoice` | done | Returns RN-style `LightningSendRequest`; raw helper remains `payRlnLightningInvoice`. |
| `listLightningPayments` | `UtexoWallet.listLightningPayments` | done | Returns RN-shaped payment wrapper. |
| `listPaymentsRaw` | `UtexoWallet.listPaymentsRaw` | done | Raw low-level payment list for current RN LSP flows. |
| `apayNew` | `UtexoWallet.apayNew` | done | APay async order helper. |
| `apayNewWithAddress` | `UtexoWallet.apayNewWithAddress` | done | APay async order helper with Lightning Address attestation parameters. |
| `createLsp` | `UtexoWallet.createLsp` | done | Creates the Dart `UtexoLsp` helper; no-arg form resolves the LSP URL, fetches LSP pubkey, and wires virtual-channel node-create params before init. |
| `getLspConfig` | `UtexoWallet.getLspConfig` | done | Returns configured LSP base URL, bearer token, and timeout. |
| `onchainReceive` | `UtexoWallet.onchainReceive` | done | Returns RN-style `OnchainReceiveResponse.invoice`, witness default true. |
| `onchainSendBegin` | `UtexoWallet.onchainSendBegin` | unsupported-parity | RN not implemented. |
| `onchainSendEnd` | `UtexoWallet.onchainSendEnd` | unsupported-parity | RN not implemented. |
| `onchainSend` | `UtexoWallet.onchainSend` | done | Decode RGB invoice then return RN-style `OnchainSendResponse`. Shares the RGB send `skipSync: true` fast-fail guard. |
| `getOnchainSendStatus` | `UtexoWallet.getOnchainSendStatus` | unsupported-parity | RN not implemented. |
| `listOnchainTransfers` | `UtexoWallet.listOnchainTransfers` | done | Transfer list alias. |
| `vssClearFence` | `UtexoWallet.vssClearFence` | done | Delegates to low-level `rlnVssClearFence`. |
| RLN extras | `UtexoWallet.*` | done | Typed node, peer, channel, keysend, decode, health helpers. |

## Signer Parity

| RN signer | Flutter API target | Status | Notes |
|---|---|---:|---|
| `IRLNSigner` | `RlnSigner` | done | Strategy interface accepted by `UtexoWallet`. |
| `PasswordRLNSigner` | `PasswordRlnSigner` | done | Password/mnemonic init and password unlock. |
| `NativeExternalRLNSigner` | `NativeExternalRlnSigner` | done | BIP39 mnemonic or seed material to 32-byte seed hex, native signer init/attach/unlock/dispose; `permissivePolicy` defaults to `true` like RN. |

## Core-Style Model Parity

Flutter cannot import TypeScript `@utexo/rgb-sdk-core` types directly, so the
package provides Dart DTOs and `toCore()` mappers with the same semantic shape
for app-facing flows.

| RN core mapping area | Flutter API target | Status | Notes |
|---|---|---:|---|
| balances | `getBtcBalanceCore`, `getAssetBalanceCore`, `toCore()` | done | Settled/future/spendable and offchain fields. |
| UTXOs | `listUnspentsCore`, `toCore()` | done | Parses outpoints and assignments. |
| RGB invoices | `blindReceiveCore`, `witnessReceiveCore`, `decodeRGBInvoiceCore` | done | Preserves invoice, recipient, assignment, transport endpoints, expiration. |
| transactions/transfers | `listTransactionsCore`, `listTransfersCore`, `toCore()` | done | Normalizes unknown statuses/kinds like RN. |
| asset lists | `listAssetsCore`, `toCore()` | done | NIA/CFA/IFA/UDA semantic groups. |

## Package-Level Export Parity

The current Flutter package matches the RN low-level `NativeRgb` bridge and the
RN `UTEXOWallet`/signer architecture. It also includes Dart equivalents for the
RN core exports that are relevant to this Bitcoin/RGB/RGB-Lightning package.

| RN package export area | Flutter status | Notes |
|---|---:|---|
| `createWallet` / `WalletInitParams` | done | Dart `createWallet`, `generateKeys`, and BIP86 key derivation match RN core vectors. |
| `getNetworkDefaults` / `resolveUnlockParams` | done | Dart exposes typed network defaults and unlock config resolution, including `utexo` to native `signet` normalization and RLN proxy overrides. |
| `RLNManager`, `RLNBinding`, `RNSigner` advanced/testing exports | done | Flutter exports Dart `RLNBinding`, `RLNManager`, `createRLNManager`, and `RNSigner`; `RLNBinding` owns one node id and serializes operations like RN. |
| `@utexo/rgb-sdk-core` crypto/key exports | done | Includes key generation/derivation, network validation, unit helpers, message signing/verification, UTEXO network presets, bridge helpers, logger, and RN-compatible error names. |
| `signPsbt`, `signPsbtFromSeed`, `estimatePsbt` | unsupported-parity | RN exports stubs that throw after `bdk-rn` removal; Flutter exports matching top-level stubs and wallet stubs. |

Not duplicated as runtime classes: TypeScript-oriented core base classes and
interfaces such as `BaseWalletManager`, `UTEXOWalletCore`, and protocol
interfaces. Their Dart equivalents are concrete typed facades and models in
this package; Phase 7's RN-source comparison gate keeps this public claim honest
against the actual upstream core package.
