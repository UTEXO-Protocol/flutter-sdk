# RGB SDK Flutter

Private Flutter plugin for Bitcoin, RGB assets, and RGB Lightning, backed by
RGB Lightning Node native artifacts.

## Release Status

**Not production ready. Do not use this revision with mainnet funds.**

The current source/static parity pass compares this repository with:

- `UTEXO-Protocol/rgb-sdk-rn` `dev` at
  `63cbf9a01030a8a10eb1b04b2734cd8c5d23aec1`
- `@utexo/rgb-sdk-rn` `1.0.0-beta.27`
- `@utexo/rgb-sdk-core` `1.0.0-beta.7`
- RGB Lightning Node `0.10.0-beta.3`

The source baseline now targets those exact versions, and the pinned native
artifact remains unchanged from the RN package. The SDK still has confirmed
packaging, code-quality, supply-chain, and exact runtime evidence gaps, so
baseline alignment must not be mistaken for release readiness.

The authoritative verdict and issue ledger are in the
[Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md). Do not infer
production readiness from passing unit tests, static parity matrices, local
artifact checks, or the presence of an advanced/raw bridge method.

## Intended Architecture

The package exposes two Dart entrypoints:

- `package:rgb_sdk_flutter/rgb_sdk_flutter.dart`: stable app-facing wallet,
  domain DTOs, signer strategies, errors, validation, and crypto helpers.
- `package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart`: explicit
  RN/native-parity surface for `RlnClient`, `RLNBinding`, `RLNManager`, raw
  `Rln*` models, native bridge diagnostics, logger access, and migration tests.

App code should start with the stable root import. Advanced imports are for
release evidence, diagnostics, and deliberate native/RN escape hatches only.
Standalone account-key Schnorr signing is disabled by default and requires an
explicit `SchnorrSigningMode.experimentalDart` opt-in for parity tests/internal
tooling; production message signing should use the native RLN-backed wallet
node-key methods.

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
  config: UtexoWalletConfig(
    storageDirPath: '/app/documents/rgb-node',
    network: 'regtest',
    daemonListeningPort: 9735,
    ldkPeerListeningPort: 9736,
  ),
);

await wallet.init(password: password);
await wallet.unlock(
  password: password,
  config: UtexoUnlockConfig(
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

Use the pinned toolchain in `.fvmrc`. Release evidence must record the exact
toolchain and must fail when required local gates are skipped.

```sh
flutter --version
dart --version
flutter pub get
dart format --output=none --set-exit-if-changed lib test pigeons tool
dart run tool/validate_release_governance.dart
dart run tool/validate_codebase_hardening.dart
dart run tool/validate_public_api_docs.dart
dart run tool/validate_release_language.dart
dart run tool/validate_api_snapshot.dart
dart run tool/validate_bridge_vectors.dart
flutter analyze
flutter test --coverage
dart run tool/validate_coverage_policy.dart
dart run tool/validate_test_matrix.dart
RGB_SDK_RN_PATH=<current-rn-dev-checkout> \
  dart run tool/validate_rn_parity.dart
```

The current RN parity command is expected to pass for static method/export
inventory only when the local checkout and live upstream `origin/dev` both
match `tool/release_baseline.json`. It is not behavioral runtime evidence.

Native builds, iOS XCTest, and funded/unfunded regtest smokes are intentionally
local-only release gates. A release report must fail when any required local
gate is skipped.

## Recovery Boundary

Native local backup/recovery remains blocked. The package must not claim
recovery readiness until upstream provides a working, tested implementation.
Durable credential storage is owned by the consuming app; the SDK still owns
in-memory secret minimization and safe diagnostics.

LSP/LNURL HTTP uses HTTPS by default. Plain HTTP is accepted only for explicit
local loopback development hosts.

## Project Documents

- [Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md)
- [Integration, Security, and Release Policy](doc/INTEGRATION_SECURITY_AND_RELEASE.md)
- [API Compatibility and Divergence Policy](doc/API_COMPATIBILITY_AND_DIVERGENCE.md)
- [Bridge Behavior Contract](doc/BRIDGE_BEHAVIOR_CONTRACT.md)
- [Release Evidence Schema](doc/RELEASE_EVIDENCE_SCHEMA.md)
- [Public API Reference](doc/PUBLIC_API_REFERENCE.md)
- [Dart Coverage Policy](doc/COVERAGE_POLICY.md)
- [Security Policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Machine-Readable Test Matrix](tool/test_matrix/README.md)
