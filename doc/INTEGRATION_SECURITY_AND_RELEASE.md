# Integration, Security, and Release Policy

This package is still an internal beta. Do not use this revision with mainnet
funds and do not treat static parity as production readiness.

## Supported Toolchain

The current development baseline is:

- Flutter `>=3.41.0`
- Dart `>=3.11.0 <4.0.0`
- iOS `18.5` or newer. This is not a product preference: the pinned RLN
  `0.10.0-beta.3` iOS static objects are built with `LC_BUILD_VERSION`
  `minos 18.5`, so lower deployment targets are not supported by this artifact
  set.
- Swift version from `tool/release_baseline.json`
- Android min/compile SDK, Java, and Kotlin versions from
  `tool/release_baseline.json`

Release evidence must record the exact Flutter, Dart, Xcode, CocoaPods, Gradle,
Kotlin, Android SDK, simulator/device, and regtest stack used for a candidate.

## Support Matrix

| Area | Current support | Release note |
| --- | --- | --- |
| Package distribution | Private Git/path only | `publish_to: none`; public publishing policy is deferred |
| Flutter | `3.41.x` family | CI and local gates read `.fvmrc` |
| Dart | `>=3.11.0 <4.0.0` | Tested with Dart `3.11.5` from Flutter `3.41.9` |
| iOS | `18.5+` | Required by the pinned RLN iOS archive object metadata |
| CocoaPods | Local Flutter consumer integration | Plain `pod lib lint` resolves the stale public Flutter pod and is not authoritative |
| Android | min SDK `24`, compile SDK `36` | Native AAR must verify checksum, size, and ABI set |
| Native/regtest CI | Not supported | Native builds and regtest smokes are mandatory local release gates |

## Native Artifacts

Native RGB Lightning Node artifacts are pinned in `tool/release_baseline.json`.
The current `releaseTier` is `internal-beta`. That means:

- artifacts are acceptable for development and internal beta only;
- checksums, sizes, iOS slices, and Android ABIs must verify before release
  testing;
- `dart run tool/validate_supply_chain.dart` must pass and attach an SBOM-style
  dependency inventory, license-file inventory, ABI-symbol checks, and artifact
  provenance status from `tool/native_artifact_provenance.json` to local
  release evidence;
- `dart run tool/validate_supply_chain.dart --production` must fail until
  every native artifact has a verified upstream signature and a
  reproducible-build/source attestation.

iOS artifacts are downloaded by the pod `prepare_command` and verified before
reuse. The downloader supports three deterministic acquisition modes:

- `RLN_ARCHIVE_PATH=/path/to/rgb-lightning-node-swift.zip` for an explicit
  pre-resolved archive;
- `RLN_CACHE_DIR=/path/to/cache` for a checksum-verified local archive cache;
- `RLN_OFFLINE=1` to fail closed unless an installed artifact, explicit
  archive, or cache entry is available.

Android artifacts resolve through Gradle/Maven and must be checked against the
pinned hash before candidate evidence is accepted.

The current provenance manifest records the live upstream status for the pinned
RLN `0.10.0-beta.3` artifact set:

| Artifact | Signature status | Attestation status | Production effect |
| --- | --- | --- | --- |
| iOS Swift archive | No detached signature asset is published with the GitHub release | No SLSA/provenance/SBOM attestation is published with the release asset | Blocks production |
| Android Maven AAR | Maven Central publishes `.asc` for the AAR, but this SDK has no pinned trusted signing key verification result | No reproducible-build attestation tying the AAR to source, builder identity, and build inputs is published | Blocks production |

Production supply-chain mode is intentionally fail-closed today. Checksums,
source pins, dependency SBOM, license classification, OSV checks, ABI markers,
and slice metadata are present, but upstream provenance is incomplete for the
pinned RLN release. Do not change `releaseTier` out of `internal-beta` until
the manifest records verified signatures and reproducible-build/source
attestations for every native artifact and `dart run
tool/validate_supply_chain.dart --production` passes.

## Artifact Upgrade Procedure

When RN/core/RLN changes, update artifacts in this order:

1. Update `tool/release_baseline.json` with the exact RN commit, core version,
   RLN tag/commit/version, archive URLs, archive sizes, SHA-256 digests,
   iOS installed-file digests, iOS object minimum, slices, Android ABI set, and
   toolchain requirements.
2. Update `tool/native_artifact_provenance.json` with signature URLs,
   signature digests, trusted signing-key verification results,
   attestation URLs/digests, and reproducible-build evidence for the same
   artifact bytes. Do not mark a signature or attestation `verified` unless it
   was checked against pinned trusted identity and source metadata.
3. Run `dart run tool/generate_release_baseline.dart`, then `dart format` on
   generated Dart files.
4. Run `tool/download_rln_ios.sh` and `tool/verify_native_artifacts.sh
   --require-android` from a clean or explicitly prepared cache.
5. Run `pod ipc spec ios/rgb_sdk_flutter.podspec` and confirm the platform,
   license, privacy bundle, source files, and deployment-target xconfigs match
   the baseline.
6. Run the clean consumer matrix with archives enabled on macOS.
7. Update this tracker with the exact evidence paths and keep any new
   upstream mismatch open until it has executable proof.

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

## CocoaPods Validation Policy

Use `pod ipc spec ios/rgb_sdk_flutter.podspec` for podspec metadata validation
and `tool/test_clean_consumer_matrix.sh` for real Flutter/CocoaPods consumer
integration. Do not use a plain `pod lib lint` result as release evidence for
this package: CocoaPods resolves the public `Flutter` pod at `3.13.0`, while
the generated Pigeon Swift bridge requires the `FlutterBinaryMessenger`
task-queue API available in the pinned Flutter `3.41.9` toolchain.

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
- `doc/PUBLIC_API_REFERENCE.md` documents the current exported symbols,
  stability tiers, lifecycle prerequisites, units, error taxonomy, side effects,
  secret-handling responsibilities, platform support, and unsupported behavior.
- `doc/COVERAGE_POLICY.md` defines the Dart-only coverage scope and thresholds.

The local release gate runs:

```sh
dart run tool/validate_release_governance.dart
dart run tool/validate_codebase_hardening.dart
dart run tool/validate_public_api_docs.dart
dart run tool/validate_release_language.dart
dart run tool/validate_api_snapshot.dart
dart run tool/validate_bridge_vectors.dart
flutter test --coverage
dart run tool/validate_coverage_policy.dart
```

Intentional public API, Pigeon, or native bridge surface changes must update
`tool/api_snapshot.json` in the same change as the tracker row and migration
note. Evidence-bucket changes must update
`tool/test_matrix/evidence_catalog.json`; bridge-vector changes must update
`tool/test_matrix/bridge_behavior_vectors.json`. Both must pass
`dart run tool/validate_test_matrix.dart` and
`dart run tool/validate_bridge_vectors.dart`. Documentation or public-surface
language changes must pass `dart run tool/validate_public_api_docs.dart` and
`dart run tool/validate_release_language.dart`.

## API Policy Summary

Stable app-facing APIs live behind `UtexoWallet` and return domain models.
`RlnClient` and generated Pigeon surfaces are advanced/native-parity layers and
may expose wire-shaped DTOs. Unsupported native feature groups must be absent
or represented by nullable typed capability carriers, not always-present
runtime stubs. Any deliberate RN/core divergence must cite a tracker row in
`doc/API_COMPATIBILITY_AND_DIVERGENCE.md` before release claims are updated.
