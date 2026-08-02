# RGB SDK Flutter

Private Flutter plugin for Bitcoin, RGB assets, and RGB Lightning, backed by
RGB Lightning Node native artifacts.

## Release Status

**Not production ready. Do not use this revision with mainnet funds.**

The 2026-07-27 release-candidate audit compared this repository with:

- `UTEXO-Protocol/rgb-sdk-rn` `dev` at
  `cb4fe938b171ac3771093e46b494f5eca190e804`
- `@utexo/rgb-sdk-rn` `1.0.0-beta.25`
- `@utexo/rgb-sdk-core` `1.0.0-beta.5`
- RGB Lightning Node `0.9.0-beta.3`

The bridge and native artifact baseline now target those exact versions. The
SDK still has confirmed API, model, threading, lifecycle, packaging, security,
and test-evidence gaps, so baseline alignment must not be mistaken for release
readiness.

The authoritative verdict and issue ledger are in the
[Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md). Do not infer
production readiness from passing unit tests, the old parity matrices, or the
presence of a method with a runtime unsupported implementation.

## Intended Architecture

The package currently exposes:

- `UtexoWallet`: app-facing wallet facade.
- `RlnClient`: low-level Pigeon bridge.
- `RLNBinding` and `RLNManager`: RN-style advanced lifecycle wrappers.
- `PasswordRlnSigner` and `NativeExternalRlnSigner`: signer strategies.

This public surface is under review. Raw bridge types, compatibility exports,
and unsupported methods are not yet a stable API.

## Development Install

Use an immutable Git commit for internal development. Tracking `main` is not a
release-safe dependency policy.

```yaml
dependencies:
  rgb_sdk_flutter:
    git:
      url: git@github.com:zeusbuilds/rgb-sdk-flutter.git
      ref: <immutable-commit>
```

## Development Example

The following is provided only for local development while the release
blockers are open:

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
```

## Local Checks

Use the pinned toolchain once one is added. The repository currently has no
`.fvmrc`, so verify the active versions explicitly before trusting results.

```sh
flutter --version
dart --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test pigeons tool
flutter analyze
flutter test
dart run tool/validate_test_matrix.dart
RGB_SDK_RN_PATH=<current-rn-checkout> \
  dart run tool/validate_rn_parity.dart
```

The current RN parity command is expected to fail until the open parity work is
implemented.

Native builds, iOS XCTest, and funded/unfunded regtest smokes are intentionally
local-only release gates. A release report must fail when any required local
gate is skipped.

## Recovery Boundary

Native local backup/recovery remains blocked. The package must not claim
recovery readiness until upstream provides a working, tested implementation.
Durable credential storage is owned by the consuming app; the SDK still owns
in-memory secret minimization and safe diagnostics.

## Project Documents

- [Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md)
- [Security Policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Machine-Readable Test Matrix](tool/test_matrix/README.md)
