# RGB SDK Flutter

Flutter plugin for Bitcoin, RGB assets, and RGB Lightning wallets backed by
RGB Lightning Node native artifacts.

This package is the Flutter counterpart to
[`@utexo/rgb-sdk-rn`](https://github.com/UTEXO-Protocol/rgb-sdk-rn). It exposes
a stable Dart wallet facade for app code and an explicit advanced entrypoint
for RN/native parity diagnostics.

## Status

**Not production ready. Do not use this revision with mainnet funds.**

Current package version: `0.1.0`.

The current baseline is:

- `UTEXO-Protocol/rgb-sdk-rn` `dev` at
  `821ae4fd10ca3933445ab926cb0af0230b108913`
- `@utexo/rgb-sdk-rn` `1.0.0-beta.32`
- `@utexo/rgb-sdk-core` `1.0.0-beta.9`
- RGB Lightning Node `0.13.0-beta.3`

Static parity and implementation work target that exact baseline. Current
release eligibility still depends on the clean-candidate native, consumer, and
funded/unfunded evidence recorded in the tracker. The accepted production
constraint is `PKG-006`: upstream native artifacts are pinned and checksum
verified, but full production provenance is not available yet.

That means internal-beta development may proceed, while public/funds-bearing
production use still requires upstream signatures, trusted-key verification,
and reproducible-build/source attestations for every native artifact. The
authoritative ledger is
[doc/RELEASE_READINESS_TRACKER.md](doc/RELEASE_READINESS_TRACKER.md).

## Features

- On-device RGB Lightning Node integration for iOS and Android.
- Stable `UtexoWallet` facade for Bitcoin, RGB, Lightning, peer, channel,
  LSP, APay, signer, and lifecycle workflows.
- RGB asset issuance and transfer support for the native/RN-supported surface.
- On-chain BTC balance, address, UTXO, transaction, and send workflows.
- Lightning invoice, payment, peer, channel, keysend, decode, and status
  workflows.
- LSP integration for Lightning Address discovery and quotes, linked/canonical
  asset selection, async payment hash pools, APay receive, RGB/Lightning
  bridge flows, cryptographically verified APay external invoices, and locally
  verified bridge and external-payment relay quotes.
- Password signer and native external signer strategies.
- Strict Dart domain DTOs on the stable API boundary.
- Advanced RN/native entrypoint for `RlnClient`, `RLNBinding`, `RLNManager`,
  raw `Rln*` models, bridge diagnostics, and parity tooling.
- Local release gates for Dart tests, native iOS XCTest, Android bridge tests,
  clean consumer archives, funded/unfunded regtest smokes, and external signer
  restart proofs.

## Platform Requirements

| Platform | Requirement |
| --- | --- |
| Flutter | `>=3.41.0` |
| Dart | `>=3.11.0 <4.0.0` |
| iOS | `18.5+`, required by the pinned RLN iOS artifact object metadata |
| Android | min SDK `24`, compile SDK from `tool/release_baseline.json` |
| Native services | Electrum and/or bitcoind RPC plus RGB proxy at unlock time |

The tested local toolchain is pinned in `.fvmrc`.

## Installation

This release line is Git/path only and is not published to pub.dev. Use an
immutable commit in consuming apps.

```yaml
dependencies:
  rgb_sdk_flutter:
    git:
      url: https://github.com/UTEXO-Protocol/flutter-sdk.git
      ref: <immutable-commit>
```

Then run:

```sh
flutter pub get
```

### iOS

The pod `prepare_command` downloads the pinned
`RGBLightningNode.xcframework`, verifies it, and installs it into the plugin's
iOS directory.

```sh
cd ios
pod install
```

For deterministic local release runs, prefer a pre-resolved archive or cache:

```sh
RLN_ARCHIVE_PATH=/path/to/rgb-lightning-node-swift-0.13.0-beta.3.zip pod install
RLN_CACHE_DIR=/path/to/rln-cache pod install
RLN_OFFLINE=1 pod install
```

### Android

Android resolves `com.utexo:rgb-lightning-node-android:0.13.0-beta.3` through
Gradle/Maven. The release gate verifies the resolved AAR checksum, size, and
ABI set against `tool/release_baseline.json`.

## Quick Start

Import the stable package entrypoint for app code:

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
```

Create a wallet with app-owned storage and a signer:

```dart
final keys = await generateKeys('regtest');

final wallet = UtexoWallet(
  config: UtexoWalletConfig(
    storageDirPath: appRgbNodeStoragePath,
    daemonListeningPort: 9735,
    ldkPeerListeningPort: 9736,
    network: 'regtest',
  ),
  signer: PasswordRlnSigner(
    password: passwordFromUser,
    mnemonic: keys.mnemonic,
  ),
);

await wallet.init();
await wallet.unlock(
  UtexoUnlockConfig(
    bitcoindRpcUsername: 'user',
    bitcoindRpcPassword: 'password',
    bitcoindRpcHost: '127.0.0.1',
    bitcoindRpcPort: 18444,
    indexerUrl: '127.0.0.1:50002',
    proxyEndpoint: 'rpc://127.0.0.1:3013/json-rpc',
  ),
);

final address = await wallet.getAddress();
final balance = await wallet.getBtcBalance();

await wallet.syncWallet();
await wallet.createUtxos(
  upTo: false,
  num: 4,
  feeRate: 1,
);

final receive = await wallet.onchainReceive(
  RgbInvoiceRequest(
    witness: false,
    minConfirmations: 1,
  ),
);

print(address);
print(balance.vanilla.spendable);
print(receive.invoice);
```

Restart the same wallet instance after shutdown:

```dart
await wallet.shutdown();
await wallet.reinit(unlockConfig);
```

Release all SDK-owned native resources when the app is done with the wallet:

```dart
await wallet.destroy();
```

## Signers

`PasswordRlnSigner` is the password-based signer. The mnemonic is required for
first initialization and may be omitted for later unlock-only sessions when the
node storage already exists.

```dart
final firstRunSigner = PasswordRlnSigner(
  password: passwordFromUser,
  mnemonic: keys.mnemonic,
);

final unlockOnlySigner = PasswordRlnSigner(password: passwordFromUser);
```

`NativeExternalRlnSigner` uses the native external-signer path and accepts
mnemonic, seed bytes, or seed hex key material.

```dart
final signer = NativeExternalRlnSigner(
  keys: RlnKeyMaterial.mnemonic(keys.mnemonic),
  network: 'regtest',
);
```

Durable credential storage is app-owned. The SDK does not silently persist
passwords, mnemonics, seed hex, or app auth tokens.

## API Entry Points

Use the stable root library for normal app code:

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
```

Use the advanced library only for parity tests, diagnostics, migration tooling,
or low-level integrations that intentionally need the RN/native shape:

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
```

The stable facade returns Dart domain DTOs. Raw native/RN models remain behind
the advanced entrypoint.

## Common Workflows

| Area | Stable API examples |
| --- | --- |
| Wallet lifecycle | `init`, `unlock`, `shutdown`, `reinit`, `destroy` |
| BTC | `getBtcBalance`, `getAddress`, `rotateVanillaAddress`, `sendBtc` |
| UTXOs | `createUtxos`, `listUnspents` |
| RGB assets | `listAssets`, `getAssetBalance`, `issueAssetNia`, `issueAssetIfa` |
| RGB receive/send | `onchainReceive`, `blindReceive`, `witnessReceive`, `onchainSend`, `decodeRgbInvoice` |
| Transactions/transfers | `listTransactions`, `listTransfers`, `failTransfers`, `refreshTransfers`, `refreshWallet`, `syncWallet` |
| Lightning | `createBolt11Invoice`, `sendPayment`, `keysend`, `listPayments`, `decodeLightningInvoice` |
| Channels/peers | `connectPeer`, `disconnectPeer`, `listPeers`, `openChannel`, `closeChannel`, `listChannels` |
| LSP/APay | `createLsp`, `discoverAddress`, `quoteAddress`, `selectPaymentAsset`, `receiveAsset`, `sendAsset`, `requestExternalInvoice`, `quoteExternalPayment`, `payExternalInvoice`, `enableLightningAddress`, `refillHashPool` |
| Signing | wallet node-message signing plus explicit experimental account-key Schnorr opt-in |

## Accepted Constraints

The current internal-beta line intentionally keeps these constraints explicit:

- Native backup/recovery is blocked until upstream provides and proves a real
  implementation.
- `sendRgb(skipSync: true)` fails fast because the pinned native artifact has
  no real skip-sync field.
- Standalone pure-Dart account-key Schnorr signing fails closed by default and
  requires `SchnorrSigningMode.experimentalDart`.
- Durable credential storage is app-owned.
- Native builds and funded regtest smokes are local release gates, not CI
  gates.
- `publish_to: none` remains until publishing/version distribution policy is
  decided.
- Production native artifact provenance is accepted as an internal-beta
  constraint under `PKG-006`; production supply-chain mode must still fail
  until upstream signatures and reproducible-build/source attestations exist.

## Local Validation

Use the pinned Flutter toolchain from `.fvmrc`.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/integration_test tool pigeons
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test --coverage
dart run tool/validate_coverage_policy.dart
dart run tool/validate_release_governance.dart
dart run tool/validate_codebase_hardening.dart
dart run tool/validate_public_api_docs.dart
dart run tool/validate_release_language.dart
dart run tool/validate_api_snapshot.dart
dart run tool/validate_bridge_vectors.dart
RGB_SDK_RN_PATH=/path/to/rgb-sdk-rn dart run tool/validate_rn_parity.dart
```

The full local candidate gate is:

```sh
RUN_CONSUMER_ARCHIVES=1 RUN_PLATFORM=1 ./tool/test_release_candidate.sh
```

The full gate runs Dart checks, package governance, clean consumer installs and
archives, Android bridge tests, iOS XCTest, funded/unfunded iOS and Android
regtest smokes, and external-signer process restart proofs. Required local
gates must not be skipped for release evidence.

## Security and Recovery

Read [doc/SECURITY.md](doc/SECURITY.md) before integrating the package.

Do not put mnemonics, seeds, passwords, private keys, bearer tokens, invoices,
preimages, wallet paths, or native error bodies in logs, screenshots, reports,
or issue trackers. SDK diagnostics are redacted as defense in depth, not as a
license to log secrets.

Native local backup/recovery remains blocked. This release line must not claim
recovery readiness.

## Documentation

- [Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md)
- [Integration, Security, and Release Policy](doc/INTEGRATION_SECURITY_AND_RELEASE.md)
- [API Compatibility and Divergence Policy](doc/API_COMPATIBILITY_AND_DIVERGENCE.md)
- [Bridge Behavior Contract](doc/BRIDGE_BEHAVIOR_CONTRACT.md)
- [Release Evidence Schema](doc/RELEASE_EVIDENCE_SCHEMA.md)
- [Public API Reference](doc/PUBLIC_API_REFERENCE.md)
- [Dart Coverage Policy](doc/COVERAGE_POLICY.md)
- [Security Policy](doc/SECURITY.md)
- [Machine-Readable Test Matrix](tool/test_matrix/README.md)
- [Example App](example/README.md)
