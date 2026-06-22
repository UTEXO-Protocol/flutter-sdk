# Release Policy

This package is private infrastructure for a wallet app. Releases should be
small, reproducible, and tied to explicit native RLN artifact versions.

## Release Channels

| Channel | Network posture | Allowed claims |
|---|---|---|
| Development | Regtest only | API development and local smoke testing. |
| Internal beta | Regtest and testnet | Feature validation with known recovery limits. |
| Production candidate | Testnet plus reviewed mainnet dry-run | No recovery-ready claims while backup is native-blocked. |
| Production | Mainnet | Requires product sign-off on recovery posture. |

Backup and restore are skipped in this pass by decision. Until a reviewed
backup/recovery path exists, production messaging must not imply that this
package alone makes an RGB wallet recoverable.

## Versioning

- Pin the native RLN artifact in Dart constants, iOS artifact documentation,
  iOS scripts, and Android Gradle dependencies.
- Do not upgrade iOS and Android RLN artifacts independently unless there is a
  documented platform emergency.
- Treat native artifact upgrades as release-candidate work, not routine patch
  work.
- Update `CHANGELOG.md`, `doc/NATIVE_ARTIFACTS.md`, `doc/PARITY_MATRIX.md`, and
  `doc/PROGRESS_TRACKER.md` with every meaningful parity or artifact change.

## Required Local Gates

Run these before cutting a package release:

```sh
flutter pub get
cd example && flutter pub get && cd ..
dart format --set-exit-if-changed .
dart run tool/validate_test_matrix.dart
dart run tool/validate_rn_parity.dart
./tool/generate_pigeon.sh
dart format lib/src/pigeon/rln_api.g.dart
git diff --exit-code -- \
  lib/src/pigeon/rln_api.g.dart \
  android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt \
  ios/Classes/RlnApi.g.swift
flutter analyze
flutter test
cd example && flutter test test && cd ..
./tool/verify_native_artifacts.sh
./tool/test_release_candidate.sh
```

The complete target-state matrix, platform gates, and release report
requirements are defined in `doc/TESTING_STRATEGY.md`.

Native build gates remain local, not CI, by current project decision:

```sh
cd example && flutter build ios --simulator --no-codesign
cd example && flutter build apk --debug
```

Regtest gates remain local, not CI:

```sh
DEVICE=<ios-simulator-id> ./tool/test_platform_unfunded.sh
DEVICE=<ios-simulator-id> ./tool/test_platform_funded.sh
DEVICE=<android-emulator-id> ./tool/test_platform_unfunded.sh
DEVICE=<android-emulator-id> ./tool/test_platform_funded.sh
```

## Release Notes Checklist

Every release note should include:

- Dart package version and git commit.
- RN reference repo commit and branch.
- RLN artifact version.
- iOS upstream zip checksum.
- iOS vendored file checksum verification result.
- Android Maven artifact checksum verification result when available locally.
- Tests, builds, and smokes that passed.
- Explicit backup/recovery status.

## Stop-Ship Conditions

Do not release if any of these are true:

- Native artifacts are unpinned or checksum verification fails.
- Dart facade and native bridge disagree on numeric bounds.
- Pigeon generated files drift from the checked-in source contract.
- iOS and Android platform behavior differs in an undocumented way.
- Seed, password, mnemonic, proxy credential, or backup path values can appear
  in logs, analytics, or crash reports.
- Product copy claims wallet recovery readiness while `rlnBackup` remains
  native-blocked.
