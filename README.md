# RGB SDK Flutter

Private Flutter plugin for Bitcoin, RGB assets, and RGB Lightning, backed by
the same RGB Lightning Node artifacts used by `@utexo/rgb-sdk-rn`.

The package exposes two Dart layers:

- `UtexoWallet`: the app-facing, typed wallet facade for product code.
- `RlnClient`: the low-level RN-parity bridge over the native `rln*` methods.
- `RlnSigner`: RN-style signer strategies for password and native external
  signer flows.

Use `UtexoWallet` by default. Reach for `RlnClient` only when validating parity,
debugging the native bridge, or adding new wallet features.

## Current Status

- RN dev baseline: `@utexo/rgb-sdk-rn` `1.0.0-beta.19`, RLN
  `0.6.0-beta.2`.
- Low-level RN bridge surface: `55 / 55` Dart methods.
- Native low-level implementations: `54 / 55`.
- Native-blocked low-level item: backup. The Dart facade delegates to native
  `rlnBackup`, but the pinned RN-matching native bridge reports backup as
  unsupported on iOS and Android.
- Parameter-level native gap: `rlnSendRgb(skipSync: true)` is rejected before
  native execution because the pinned RLN artifact has no `skipSync` field for
  RGB sends. Default `skipSync: false` RGB sends are supported and covered.
- High-level wallet facade: typed Dart API for supported Bitcoin, RGB, peer,
  channel, Lightning, HODL invoice, attested APay, VSS fence, and LSP
  workflows, including APay proof wire data, the default `utexo` LSP URL, and
  pre-init virtual-channel setup for no-arg `createLsp()`.
- Guardrails: Dart facade and native bridges validate bounded integer fields,
  non-negative amounts, and finite fee rates before converting to RLN unsigned
  numeric types.
- RN-style signer facade: `PasswordRlnSigner` and `NativeExternalRlnSigner`.
- Behavioral contract: `UtexoWallet` owns Flutter lifecycle state; `RlnClient`
  remains a stateless low-level bridge; `RLNBinding` and `RLNManager` are
  available for RN-style advanced/testing flows. See
  `doc/BEHAVIORAL_CONTRACT.md` for lifecycle, concurrency, RN default, and
  intentional-divergence details.
- RN-style core helpers: `createWallet`, `generateKeys`,
  `deriveKeysFromMnemonic`, `deriveKeysFromSeed`, `signMessage`,
  `verifyMessage`, validation utilities, UTEXO network presets, bridge helpers,
  and logger exports.
- Core-style DTO mappers: additive `*Core` wallet methods and `toCore()`
  extensions for callers that want RN `rgb-sdk-core`-shaped data.
- Local regtest smoke harnesses cover unfunded and funded RGB/RGB-Lightning
  flows, including RGB send and RGB Lightning payment over an RGB channel.
- Release parity gate: `tool/validate_rn_parity.dart` compares the pinned RN
  `dev` source against Flutter's low-level matrix, wallet matrix, and public
  runtime exports.

## Install

This is currently a private package. Use a Git dependency or path dependency
from the consuming app until it is published internally.

```yaml
dependencies:
  rgb_sdk_flutter:
    git:
      url: git@github.com:zeusbuilds/rgb-sdk-flutter.git
      ref: main
```

## Basic Usage

```dart
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

final wallet = UtexoWallet(
  config: const UtexoWalletConfig(
    storageDirPath: '/app/documents/rgb-node',
    network: 'regtest',
    daemonListeningPort: 9735,
    ldkPeerListeningPort: 9736,
  ),
);

await wallet.init(password: password);
await wallet.unlock(
  password: password,
  config: const UtexoUnlockConfig(
    bitcoindRpcUsername: 'user',
    bitcoindRpcPassword: 'password',
    bitcoindRpcHost: '127.0.0.1',
    bitcoindRpcPort: 18444,
    indexerUrl: '127.0.0.1:50002',
    proxyEndpoint: 'rpc://127.0.0.1:3003/json-rpc',
  ),
);

final address = await wallet.getAddress();
final balance = await wallet.getBtcBalance();
final assets = await wallet.listAssets();
```

## Core Key Helpers

```dart
final keys = await createWallet('regtest');
final restored = await deriveKeysFromMnemonic('regtest', keys.mnemonic);
final signature = await signMessage(
  SignMessageParams(message: 'hello', seed: seedHex, network: 'regtest'),
);
final valid = await verifyMessage(
  VerifyMessageParams(
    message: 'hello',
    signature: signature,
    accountXpub: restored.accountXpubVanilla,
    network: 'regtest',
  ),
);
```

RN-style signer construction is also supported:

```dart
final wallet = UtexoWallet(
  config: config,
  signer: PasswordRlnSigner(password: password, mnemonic: mnemonic),
);

await wallet.init();
await wallet.unlock(config: unlockConfig);
```

## RGB Send Sketch

```dart
final invoice = await receiver.blindReceive(const RgbInvoiceRequest());

final result = await sender.send(
  RgbSendRequest(
    invoice: invoice.invoice,
    assetId: assetId,
    amount: 100,
    donation: true,
  ),
);

print(result.txid);
```

## Local Quality Checks

```sh
flutter pub get
./tool/verify_native_artifacts.sh
dart run tool/validate_test_matrix.dart
dart run tool/validate_rn_parity.dart
flutter analyze
flutter test
./tool/test_native_android.sh

cd example
flutter pub get
flutter test test
```

Run iOS native XCTest bridge tests when an iOS simulator is available:

```sh
DEVICE='iPhone 17 Pro' ./tool/test_native_ios.sh
```

CI intentionally runs formatting, generated-code drift, analysis, and unit
tests. It does not run native builds, iOS XCTest, or regtest smoke tests.

## Production Readiness Boundary

The package is release-candidate hardened for the implemented non-backup
Bitcoin, RGB, RGB Lightning, signer, and key-derivation surfaces that pass local
analysis, unit tests, builds, parity gates, and regtest smokes. It is not
recovery-ready for a mainnet wallet until the pinned RLN artifact exposes a
working backup/restore path or a separate reviewed recovery design is adopted.

## Regtest Smoke

Start the isolated local stack:

```sh
./tool/regtest/regtest.sh start
```

Run the quick simulator smoke from `example/`:

```sh
DEVICE=<device-id> ./tool/test_platform_unfunded.sh
```

Run the funded RGB/RGB-Lightning smoke from the repository root:

```sh
DEVICE=<device-id> ./tool/test_platform_funded.sh
```

The funded script coordinates host-side mining/funding while the simulator runs
the plugin through real wallet, RGB, channel, and RGB Lightning flows.

Run the local release-candidate gate and write a JSON report:

```sh
./tool/test_release_candidate.sh
```

Platform smokes stay local by design. To include them in a release-candidate
run, provide devices explicitly:

```sh
RUN_PLATFORM=1 IOS_DEVICE=<ios-device-id> ANDROID_DEVICE=<android-device-id> \
  ./tool/test_release_candidate.sh
```

## Key Docs

- [Technical Plan](doc/TECHNICAL_PLAN.md)
- [API Usage Guide](doc/API_USAGE.md)
- [Architecture](doc/ARCHITECTURE.md)
- [Native Artifacts](doc/NATIVE_ARTIFACTS.md)
- [Security Model](doc/SECURITY_MODEL.md)
- [Release Policy](doc/RELEASE_POLICY.md)
- [Supply Chain](doc/SUPPLY_CHAIN.md)
- [API Parity Matrix](doc/PARITY_MATRIX.md)
- [Implementation Phases](doc/PHASES.md)
- [Progress Tracker](doc/PROGRESS_TRACKER.md)
- [Issue Tracker](doc/ISSUE_TRACKER.md)
- [Complete Testing Strategy](doc/TESTING_STRATEGY.md)
- [Risk Register](doc/RISK_REGISTER.md)
