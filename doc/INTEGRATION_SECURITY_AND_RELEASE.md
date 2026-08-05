# Integration, Security, and Release Policy

This package is still an internal beta. Do not use this revision with mainnet
funds and do not treat static parity as production readiness.

## Supported Toolchain

The current development baseline is:

- Flutter `>=3.41.0`
- Dart `>=3.11.0 <4.0.0`
- iOS minimum from `tool/release_baseline.json`
- Swift version from `tool/release_baseline.json`
- Android min/compile SDK, Java, and Kotlin versions from
  `tool/release_baseline.json`

Release evidence must record the exact Flutter, Dart, Xcode, CocoaPods, Gradle,
Kotlin, Android SDK, simulator/device, and regtest stack used for a candidate.

## Native Artifacts

Native RGB Lightning Node artifacts are pinned in `tool/release_baseline.json`.
The current `releaseTier` is `internal-beta`. That means:

- artifacts are acceptable for development and internal beta only;
- checksums, sizes, iOS slices, and Android ABIs must verify before release
  testing;
- `dart run tool/validate_supply_chain.dart` must pass and attach an SBOM-style
  dependency inventory, license-file inventory, ABI-symbol checks, and artifact
  provenance status to local release evidence;
- `dart run tool/validate_supply_chain.dart --production` must fail until
  upstream artifact signatures and reproducible-build attestations are present.

iOS artifacts are downloaded by the pod `prepare_command` and verified before
reuse. Android artifacts resolve through Gradle/Maven and must be checked
against the pinned hash before candidate evidence is accepted.

## Clean Consumer Matrix

`tool/test_clean_consumer_matrix.sh` creates a candidate snapshot from tracked
and unignored source files, commits it to a temporary local Git repository,
then verifies:

- package tarball contents through `dart pub publish --dry-run`;
- fresh path dependency installation;
- fresh Git dependency installation;
- Android release APK builds for both consumers;
- iOS release `--no-codesign` builds for both consumers on macOS.

This matrix proves install/archive behavior for a clean consumer. It does not
replace funded native smokes or upstream provenance evidence.

## Transport Policy

LSP and LNURL HTTP uses HTTPS by default. Plain HTTP is allowed only for local
loopback hosts such as `127.0.0.1`, `localhost`, `::1`, and Android emulator
host `10.0.2.2`.

Injected HTTP clients are not closed by the SDK. HTTP clients created by the
SDK are closed by the SDK.

## Secure Storage Boundary

Durable credential storage is owned by the consuming app, not this SDK. The SDK
does not silently persist passwords, mnemonics, seed hex, or app auth tokens.

The SDK still owns:

- copying mutable seed byte input before use;
- wiping SDK-owned seed/private-key byte buffers after derivation/signing where
  Dart allows it;
- consuming native external signer seed hex after handoff to native so retries
  require a fresh signer instance instead of retaining replayable seed material;
- redacting support-safe diagnostics;
- rejecting unsupported native fields before a no-op can appear successful.

Strings, BIP32 internals, VM copies, and app-owned storage cannot be reliably
zeroized by this package. Do not pass production secrets through logs, crash
reports, screenshots, or long-lived app state.

Native local backup/recovery remains blocked until upstream supplies a real,
tested implementation.

## Required Local Release Gates

CI intentionally runs only source/static/package checks. Native builds,
XCTest/JVM bridge tests, funded/unfunded regtest smokes, and external-signer
restart proofs are local release gates. `tool/test_release_candidate.sh` must
fail when required local gates are skipped. The script also runs supply-chain
and clean-consumer gates by default; use `RUN_CONSUMER_MATRIX=0` only for local
debugging, never for release evidence.

## API and Evidence Governance

Release policy is split across two dedicated documents:

- `doc/API_COMPATIBILITY_AND_DIVERGENCE.md` defines RN/core/native precedence,
  approved divergences, API stability tiers, Dart adaptation rules, migration
  policy, and the Pigeon-vs-FFI decision record.
- `doc/BRIDGE_BEHAVIOR_CONTRACT.md` defines low-level Pigeon bridge behavior,
  numeric transport limits, malformed wire-response handling, and the native
  vector claim boundary.
- `doc/RELEASE_EVIDENCE_SCHEMA.md` defines evidence IDs, required report
  fields, sanitization rules, matrix evidence catalog rules, API/ABI snapshot
  policy, and documentation completeness criteria.

The local release gate runs:

```sh
dart run tool/validate_release_governance.dart
dart run tool/validate_api_snapshot.dart
dart run tool/validate_bridge_vectors.dart
```

Intentional public API, Pigeon, or native bridge surface changes must update
`tool/api_snapshot.json` in the same change as the tracker row and migration
note. Evidence-bucket changes must update
`tool/test_matrix/evidence_catalog.json`; bridge-vector changes must update
`tool/test_matrix/bridge_behavior_vectors.json`. Both must pass
`dart run tool/validate_test_matrix.dart` and
`dart run tool/validate_bridge_vectors.dart`.
