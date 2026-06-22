# Complete Testing Strategy

This package must be tested like wallet infrastructure, not like a normal UI
plugin. The bar is not "the package builds". The bar is:

- every supported public API has deterministic unit or contract coverage,
- every supported native bridge method is executed on iOS and Android,
- every stateful wallet workflow is proven on regtest,
- every unsupported or native-blocked method fails honestly and consistently,
- every release produces an auditable test report tied to exact native artifact
  checksums.

`rlnBackup` remains skipped as product functionality by current decision, but
it must still be tested as a native-blocked parity surface: the API must exist,
delegate, and return a stable unsupported/native-blocked failure instead of
pretending success.

## Reference Model

The UTEXO org does not have one wrapper repository that already gives us the
complete testing standard we need.

Useful patterns to copy:

- `rgb-lightning-node`: strongest baseline. It has Rust unit/regtest coverage,
  lib SDK tests, VSS tests, Python/Kotlin/Android/Swift UniFFI E2E, and artifact
  builds.
- `rgb-lib`: strong Rust wallet tests across issue/send/receive/backup/VSS and
  feature combinations.
- `rgb-sdk`: strong JS package-level tests plus many regtest/signet scenarios.
- `rgb-lib-wasm`: strong browser/WASM plus regtest integration testing.
- `utexo-lsp`: useful Python E2E structure over an RLN submodule.

Patterns not strong enough to copy as the final standard:

- `rgb-sdk-rn`: build/release CI plus one Android instrumentation smoke. It is
  useful as API parity input, not as a testing benchmark.
- thin binding wrappers such as `rgb-lib-nodejs`, `rgb-lib-kotlin`,
  `rgb-lib-swift`, `rgb-lib-bare`, and `rgb-lightning-node-nodejs`: mostly
  build/release validation, little or no behavioral testing.

Flutter should use the stronger core-repo model while also proving mobile
bridge parity that the RN package does not fully prove.

## Coverage Definitions

A method is not "tested" unless the relevant proof level is explicit.

| Level | Meaning |
|---|---|
| Declared | Public Dart API exists and is documented. |
| Unit-tested | Pure Dart validation/model/error behavior has deterministic tests. |
| Contract-tested | Dart method calls the expected Pigeon host API with correct arguments and maps success/error responses. |
| Native-compiled | iOS Swift and Android Kotlin compile against the pinned RLN artifact. |
| Platform-smoked | Method executes on at least one platform simulator/emulator. |
| Platform-verified | Method executes on both iOS simulator and Android emulator with expected result or expected failure. |
| Workflow-verified | Method is part of a full regtest wallet workflow with real node state. |
| Release-verified | Result is recorded in the release test report with artifact version, platform, device, commit, and pass/fail. |

Production-supported APIs must reach `Release-verified` on both iOS and
Android. Unsupported parity APIs must reach `Release-verified` as intentional
failures.

## Required Test Layers

### Layer 0: Static And Supply Chain Gates

Purpose: catch broken source state before runtime tests.

Required commands:

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
./tool/verify_native_artifacts.sh
```

Coverage:

- Dart formatting and analyzer.
- Pigeon generated-code drift.
- Native artifact checksums.
- Public exports compile.
- RN `dev` source still matches the Flutter low-level bridge, wallet matrix,
  and package runtime exports.
- No accidental generated/native artifact mismatch.

Current CI policy:

- GitHub CI runs formatting, Pigeon drift, analyzer, unit tests, example widget
  tests, and iOS vendored artifact checksum verification.
- Native builds and regtest smokes are intentionally not in CI by current
  project decision. They are local or release-run gates.

Future option:

- If we later add trusted self-hosted macOS runners and Android emulator
  capacity, promote the full platform suite to scheduled or pre-release CI.

### Layer 1: Pure Dart Unit Tests

Purpose: prove deterministic logic without native dependencies.

Location:

```text
test/
  utexo_wallet_test.dart
  rgb_sdk_flutter_test.dart
  rgb_sdk_flutter_method_channel_test.dart
```

Required coverage:

- All request validation:
  - empty strings,
  - negative amounts,
  - `u16`, `u32`, `u64` bounds,
  - finite fee rates,
  - optional/null/default fields.
- All model mappers:
  - balances,
  - assets,
  - invoices,
  - payments,
  - peers,
  - channels,
  - transfers,
  - transactions,
  - UTXOs,
  - node info,
  - network info.
- Error mapping:
  - platform exceptions,
  - `RgbSdkException`,
  - unsupported stubs,
  - native-blocked backup,
  - parameter-level native artifact gaps such as `rlnSendRgb.skipSync=true`.
- High-level wallet lifecycle sequencing:
  - requires init before wallet operations,
  - unlock requires init,
  - reinit recreates node correctly,
  - destroy releases node and signer state,
  - shutdown errors still clean up handles when appropriate.
- RN core-style crypto and helper exports:
  - BIP39 mnemonic generation,
  - BIP32/BIP86 derivation,
  - xpriv/xpub helpers,
  - seed/mnemonic restore,
  - Schnorr sign/verify,
  - unit conversion,
  - network presets,
  - validation helpers,
  - bridge helper DTOs.

Implementation rule:

- Pure Dart tests must not require Docker, Simulator, Android Emulator, network
  access, or native artifacts.

### Layer 2: Dart Contract Tests Over Fake Host APIs

Purpose: prove every Dart facade method calls the expected platform contract
without relying on native RLN state.

Required implementation:

- Keep a fake `RlnHostApi` that records every call.
- Add one contract test per low-level method.
- Add one contract test per high-level `UtexoWallet` method or behavior group.
- Assert exact argument mapping and response mapping.
- Assert expected exception category and operation name for failure paths.

Current implementation:

- `test/rln_client_contract_test.dart` records and asserts all 55 low-level
  `RlnClient` to Pigeon host calls, including exact argument order.
- `test/utexo_wallet_test.dart` covers supported wallet facade groups, aliases,
  DTO/core mappers, unsupported RN parity stubs, native-blocked backup, and RGB
  send `skipSync` fast-fail behavior.
- `tool/test_matrix/*.json` records the public API catalog. The validator fails
  if a public `RlnClient` or `UtexoWallet` method is missing, stale, malformed,
  or still marked as `planned`.
- `tool/validate_rn_parity.dart` reads RN `NativeRgb.ts`,
  `src/wallet/utexo-wallet.ts`, and `src/index.ts` from the pinned RN `dev`
  checkout. It fails on missing low-level methods, missing high-level wallet
  rows, unmapped runtime exports, stale aliases, or undocumented TypeScript-only
  type-star boundaries.

Coverage matrix:

| API group | Contract checks |
|---|---|
| Lifecycle | create/init/unlock/shutdown/destroy/reinit call order and cleanup behavior. |
| Native signer | signer creation, signer init, attach, unlock, destroy, seed validation. |
| Read/health | address, node info, network info, balance, list calls, endpoint checks. |
| BTC | create UTXOs, estimate fee, list transactions, list unspents, send BTC. |
| RGB assets | list assets, asset balance, issue NIA/CFA/IFA/UDA, invoice decode, invoice create, send, fail, refresh. |
| Peers/channels | connect, disconnect, list peers, open, close, channel ID, list channels. |
| Lightning | decode invoice, create invoice, send payment, keysend, invoice/payment lookup, list payments. |
| Unsupported parity | PSBT, VSS, RN service-only helpers throw stable unsupported errors. |
| Native-blocked | backup delegates to native bridge and preserves unsupported/native-blocked failure. |

No supported method can be release-ready without a contract test.

### Layer 3: Native Compile And Native Unit Tests

Purpose: catch bridge bugs that Dart tests cannot see.

Current minimum:

- Swift parse/compile checks for iOS bridge files.
- Kotlin compile checks for Android bridge files.
- Example iOS simulator build.
- Example Android debug build.
- Android JVM bridge tests through `tool/test_native_android.sh`.
- iOS XCTest bridge tests through `tool/test_native_ios.sh`.

Current native test files:

```text
android/src/test/kotlin/com/utexo/rgb_sdk_flutter/
  RgbSdkFlutterPluginTest.kt

example/ios/RunnerTests/
  RunnerTests.swift
```

Current native coverage:

- Android artifact metadata pinning.
- Android native-blocked `rlnBackup` error shape and secret redaction.
- Android unsigned numeric guardrails before native RLN creation.
- Android `RlnNodeStore` duplicate path rejection, shutdown-path reuse,
  lifecycle transitions, and close-on-remove behavior.
- iOS artifact metadata pinning.
- iOS native-blocked `rlnBackup` error shape and secret redaction.
- iOS unsigned numeric guardrails before native RLN creation.

Future native hardening additions:

```text
ios/Tests or example/ios/RunnerTests/
  RlnNodeStoreTests.swift
  RlnThreadingTests.swift

android/src/test/kotlin/com/utexo/rgb_sdk_flutter/
  RlnCoroutineTest.kt

android/src/androidTest/
  RlnBridgeInstrumentationTest.kt
```

iOS unit coverage:

- Node handle creation/removal.
- Signer handle creation/removal.
- Numeric conversion guardrails before unsigned RLN calls.
- Error normalization and secret redaction.
- Lifecycle serialization.
- Double destroy and shutdown-after-error behavior.

Android unit coverage:

- Node store mutex behavior.
- Coroutine dispatcher behavior.
- Unsigned conversion guardrails.
- Error normalization and secret redaction.
- Double destroy and shutdown-after-error behavior.

Native tests should use no-pointer or fake handles where possible and
instrumented RLN only where the real artifact is required.

### Layer 4: Unfunded Platform Smoke

Purpose: prove the plugin loads native artifacts and can create/unlock a real
RLN node on both platforms against the local regtest stack.

Existing test:

```text
example/integration_test/plugin_integration_test.dart
```

Command:

```sh
DEVICE=<device-id> ./tool/test_platform_unfunded.sh
```

Required platforms:

- iOS simulator arm64.
- Android emulator x86_64.

Coverage:

- native artifact metadata,
- create node,
- init node,
- unlock node,
- sync,
- node info,
- network info,
- address,
- BTC balance,
- list peers,
- list channels,
- list payments,
- endpoint checks,
- empty asset listing,
- transfer refresh,
- no-asset transfer failure recovery,
- shutdown,
- destroy.

Exit criteria:

- Same test file must pass on iOS and Android.
- Any platform-specific exception message must still map to the same Dart error
  category.

### Layer 5: Funded Regtest Workflow Tests

Purpose: prove wallet state transitions with real funding, mining, RGB assets,
channels, and RGB Lightning payments.

Existing harness:

```sh
DEVICE=<device-id> ./tool/test_platform_funded.sh
```

Architecture:

- Docker regtest stack runs on host.
- Simulator/emulator runs the Flutter integration test.
- Test emits `RGB_SDK_FLUTTER_HOST` funding/mining commands.
- Host script services those commands through `tool/regtest/regtest.sh`.
- Node wallets never control the miner wallet directly.

Current funded coverage:

- two independent `UtexoWallet` nodes,
- host BTC funding and block mining,
- wallet sync and spendable balance polling,
- deterministic colorable UTXO creation,
- NIA issuance,
- witness RGB invoice creation,
- RGB send from wallet A to wallet B,
- transfer refresh and recipient asset balance assertion,
- peer connection,
- RGB channel open,
- funding confirmation mining,
- usable channel polling with additional block production,
- RGB BOLT11 invoice creation,
- RGB Lightning payment send,
- receiver invoice final-state assertion.

Required funded additions:

- blind invoice receive path,
- CFA/IFA/UDA issuance flows,
- asset balance per issued asset type,
- `sendBtc` success path,
- fee estimate behavior with realistic fee rates,
- list transactions after BTC and RGB operations,
- list unspents before and after create/send flows,
- close channel cooperative path,
- close channel force path where supported,
- reconnect/restart and verify channel/payment state,
- keysend path where native artifact supports it,
- failed transfer recovery after proxy/indexer disruption.

### Layer 6: Function-By-Function Platform Matrix

Purpose: remove ambiguity. Every public method gets a row with iOS and Android
evidence.

The matrix should be generated or maintained as a machine-readable file:

```text
tool/test_matrix/rln_methods.json
tool/test_matrix/wallet_methods.json
tool/test_matrix/core_exports.json
```

Validate it with:

```sh
dart run tool/validate_test_matrix.dart
```

The schema is intentionally compact:

- `id`: public Dart method/export name.
- `hostApi`: low-level native host method where applicable.
- `group`: lifecycle, bitcoin, rgb, lightning, channel, peer, signer, etc.
- `support`: `supported`, `native-blocked`, or `unsupported-parity`.
- `fixture`: the intended proof fixture.
- `contract`: `covered` or `implemented`; `planned` is invalid.
- `ios`/`android`: platform proof requirement for low-level native methods.

Result output:

```text
build/test-reports/
  release/
    release-candidate-<git-sha>.json
    release-candidate-<git-sha>.log
  platform/
    platform-unfunded-<device>-<git-sha>.json
    platform-unfunded-<device>-<git-sha>.log
    platform-funded-<device>-<git-sha>.json
    platform-funded-<device>-<git-sha>.log
```

Release report fields:

- git commit,
- package version,
- RN reference commit,
- RLN artifact version,
- artifact checksums,
- Flutter version,
- Xcode version,
- Android SDK/NDK versions,
- iOS simulator model/runtime,
- Android emulator API/ABI,
- method pass/fail/skip/native-blocked status,
- failure logs,
- manual sign-off.

No release should claim "all functions tested" without this matrix report.

### Layer 7: Restart, Persistence, And Resilience

Purpose: wallet bugs often appear after restart, interrupted sync, partial
failure, or repeated calls.

Required scenarios:

- init, unlock, shutdown, recreate node using same storage dir, unlock again.
- destroy while shutdown fails.
- unlock twice while node is already unlocked.
- concurrent read calls while unlocked.
- concurrent lifecycle calls are serialized or rejected predictably.
- wrong password.
- wrong network with existing storage.
- missing storage directory.
- corrupted or deleted storage subdirectory.
- proxy down during send.
- proxy recovers and transfer refresh succeeds.
- indexer unavailable during unlock or sync.
- bitcoind temporarily unavailable.
- payment/channel state after app process restart.
- channel and transfer listing after restart.

Each scenario must assert:

- no native handle leak,
- no unhandled platform exception,
- stable Dart error code,
- no secret values in error messages,
- eventual cleanup succeeds.

### Layer 8: Security Tests

Purpose: prove sensitive material is not casually exposed.

Required automated checks:

- Seed, mnemonic, password, RPC password, proxy endpoint credentials, backup
  path, and storage path are redacted from thrown Dart errors.
- Native error mapping does not include seed/mnemonic/password strings.
- Logs from tests do not contain known sentinel secrets.
- Unsupported methods do not serialize secret arguments into exception details.
- `PasswordRlnSigner` clears retained mnemonic after native init.
- `NativeExternalRlnSigner` rejects invalid seed material before native bridge.
- Artifact checksums match expected values.

Required manual/app integration checks:

- iOS Keychain policy follows `doc/SECURITY_MODEL.md`.
- Android Keystore policy follows `doc/SECURITY_MODEL.md`.
- Wallet storage directories are app-private and cloud-backup policy is
  explicitly reviewed.

### Layer 9: Performance And Stability Budgets

Purpose: catch regressions that still return correct values but make the wallet
feel broken.

Baseline metrics to record in release reports:

- node create time,
- init time,
- unlock time,
- sync time after empty wallet,
- sync time after funded wallet,
- address time,
- list assets time,
- issue asset time,
- RGB send time,
- transfer settle time,
- channel open time,
- Lightning invoice creation time,
- Lightning payment completion time.

Initial budgets should be generous and data-driven. Once baselines stabilize,
turn them into warning thresholds, then release-blocking thresholds.

Stability requirements:

- funded smoke can run three times in a row on the same machine after
  `regtest.sh reset`,
- no simulator/emulator process crash,
- no native plugin crash,
- no unbounded log growth,
- no leaked test storage after cleanup.

## Device And Runtime Matrix

Minimum release-candidate matrix:

| Platform | Required target | Purpose |
|---|---|---|
| iOS simulator | Latest stable iOS runtime on Apple Silicon | Fast release gate for Swift/Pigeon/RLN integration. |
| Android emulator | x86_64 API level used by product min/support policy | Fast release gate for Kotlin/Pigeon/RLN integration. |
| iOS physical device | One arm64 device before app beta/mainnet | Proves native artifact on real device runtime. |
| Android physical device | One arm64 device before app beta/mainnet | Proves JNI/native artifact on real device runtime. |

For package-only releases, simulator/emulator may be enough if release notes
state that physical-device validation is pending. For wallet app beta/mainnet,
physical devices are required.

## Regtest Environment

This repo includes an isolated Docker Compose regtest stack under:

```text
tool/regtest
```

Start it:

```sh
./tool/regtest/regtest.sh start
```

Default local endpoints:

- bitcoind RPC: `127.0.0.1:18444`, username `user`, password `password`
- electrs: `127.0.0.1:50002`
- RGB proxy: `rpc://127.0.0.1:3003/json-rpc`
- network: `regtest`

Useful commands:

```sh
./tool/regtest/regtest.sh info
./tool/regtest/regtest.sh mine 1
./tool/regtest/regtest.sh sendtoaddress <address> <btc>
./tool/regtest/regtest.sh stop
./tool/regtest/regtest.sh reset
```

Rules:

- `start` preserves existing stack data.
- `reset` is required before reproducibility-sensitive release runs.
- Every funded release run must capture stack info before tests.
- Every failure must dump regtest stack logs and simulator/emulator logs.

## Command Plan

### Quick Developer Check

Use before pushing ordinary Dart/plugin changes:

```sh
dart format --set-exit-if-changed .
./tool/verify_native_artifacts.sh --ios-only
flutter analyze
flutter test
./tool/test_native_android.sh
cd example && flutter test test && cd ..
```

### Full Local Package Check

Use before asking for review:

```sh
flutter pub get
cd example && flutter pub get && cd ..
dart format --set-exit-if-changed .
./tool/generate_pigeon.sh
dart format lib/src/pigeon/rln_api.g.dart
git diff --exit-code -- \
  lib/src/pigeon/rln_api.g.dart \
  android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt \
  ios/Classes/RlnApi.g.swift
REQUIRE_ANDROID_AAR=1 ./tool/verify_native_artifacts.sh
flutter analyze
flutter test
./tool/test_native_android.sh
cd example && flutter test test && cd ..
```

### Native Build Check

Use before package release:

```sh
./tool/test_native_android.sh
DEVICE=<ios-simulator-id> ./tool/test_native_ios.sh
cd example && flutter build ios --simulator --no-codesign && cd ..
cd example && flutter build apk --debug && cd ..
```

### Platform Smoke Check

Use before package release:

```sh
./tool/regtest/regtest.sh reset
DEVICE=<ios-simulator-id> ./tool/test_platform_unfunded.sh

./tool/regtest/regtest.sh reset
DEVICE=<android-emulator-id> ./tool/test_platform_unfunded.sh
```

### Funded Workflow Check

Use before package release:

```sh
./tool/regtest/regtest.sh reset
DEVICE=<ios-simulator-id> ./tool/test_platform_funded.sh

./tool/regtest/regtest.sh reset
DEVICE=<android-emulator-id> ./tool/test_platform_funded.sh
```

### Strict Release Candidate Check

Use before a release candidate:

```sh
VERIFY_REMOTE=1 REQUIRE_ANDROID_AAR=1 ./tool/verify_native_artifacts.sh
IOS_DEVICE=<ios-simulator-id> \
RUN_PLATFORM=1 ANDROID_DEVICE=<android-emulator-id> \
  ./tool/test_release_candidate.sh
```

Then run:

- full local package check,
- native build check,
- platform smoke check,
- funded workflow check,
- function-by-function matrix once implemented,
- manual review of the generated release report.

## Implementation Phases

### Phase T0: Test Catalog

Deliverables:

- Add machine-readable method matrix files under `tool/test_matrix`.
- Link each row to the relevant public Dart API and fixture.
- Add test status fields:
  - `contract`,
  - `ios`,
  - `android`,
  - `fixture`,
  - `support`.
- Add a script that fails if a `done` parity row has no test matrix row.

Exit criteria:

- Every low-level `RlnClient` method has a matrix row.
- Every supported `UtexoWallet` method has a matrix row.
- Every core export has a matrix row.
- Every unsupported/native-blocked method has an expected failure row.

### Phase T1: Complete Dart Contract Coverage

Deliverables:

- One fake-host test for every `RlnClient` method.
- One fake-host or pure-Dart test for every `UtexoWallet` method.
- Error-path tests for invalid state, invalid input, platform exceptions, and
  unsupported/native-blocked behavior.

Exit criteria:

- Contract coverage is 100 percent for public Dart APIs.
- No method is only indirectly tested through a larger workflow.

### Phase T2: Native Bridge Unit Tests

Deliverables:

- Android JVM tests for store/error/numeric logic.
- iOS XCTest local test target for artifact/error/numeric logic.
- Android instrumentation test for real RLN create/init/unlock/nodeInfo.
- Swift parse/compile check remains part of local gate.

Exit criteria:

- Native helper logic fails fast without needing a full Flutter integration
  test.
- Android and iOS bridge behavior is symmetric where APIs are symmetric.
- Deeper Android instrumentation remains useful, but is not required in CI by
  current project policy.

### Phase T3: Exhaustive Unfunded Platform Matrix

Deliverables:

- Extend `example/integration_test/plugin_integration_test.dart` or split into:
  - `unfunded_lifecycle_test.dart`,
  - `unfunded_read_methods_test.dart`,
  - `unfunded_negative_methods_test.dart`.
- Add runner script:
  - `tool/test_platform_unfunded.sh`.
- Emit JSON platform report.

Exit criteria:

- Every method that can run before funding is verified on iOS and Android.
- Expected precondition failures are asserted, not ignored.

### Phase T4: Exhaustive Funded Platform Matrix

Deliverables:

- Split funded tests by scenario:
  - `funded_btc_test.dart`,
  - `funded_rgb_issue_receive_send_test.dart`,
  - `funded_rgb_asset_types_test.dart`,
  - `funded_channels_test.dart`,
  - `funded_rgb_lightning_test.dart`,
  - `funded_restart_persistence_test.dart`.
- Add runner script:
  - `tool/test_platform_funded.sh`.
- Emit JSON platform and workflow report.

Exit criteria:

- Every funded Bitcoin, RGB, channel, and RGB Lightning method is verified on
  iOS and Android.
- Test report proves which method each workflow covered.

### Phase T5: Resilience, Security, And Performance

Deliverables:

- Add restart/persistence tests.
- Add endpoint disruption tests.
- Add secret redaction tests.
- Add repeated-run stability mode.
- Add performance measurement output.

Exit criteria:

- Release report includes stability and performance baselines.
- Known secret sentinels do not appear in logs or exception strings.

### Phase T6: Release Report Automation

Deliverables:

- Add `tool/test_release_candidate.sh`.
- Add report writer for:
  - command output,
  - method matrix,
  - platform metadata,
  - artifact checksums,
  - logs.
- Add `doc/TEST_REPORT_TEMPLATE.md` if reports need manual sign-off.

Exit criteria:

- A release candidate can produce one archive proving what was tested.
- The archive is enough for an engineer to answer "was every supported function
  tested on both iOS and Android?" without rerunning tests.

## Release Blocking Rules

Block release if any of these are true:

- A supported method lacks a matrix row.
- A supported method lacks Dart contract coverage.
- A supported native method is not platform-verified on both iOS and Android.
- A funded workflow passes on one platform but not the other.
- A method returns different shape/nullability semantics between iOS and
  Android without documentation and explicit product sign-off.
- A native error leaks seed, mnemonic, password, RPC password, proxy credential,
  or storage path.
- Artifact checksum verification fails.
- Pigeon generated files drift.
- The release report cannot identify git commit, Flutter version, native
  artifact version, or device/runtime metadata.

Allowed non-blocking statuses:

- `rlnBackup` native-blocked, while backup remains intentionally skipped.
- `rlnSendRgb.skipSync=true` fast-fails until the pinned native artifact exposes
  a matching request field.
- RN unsupported-parity methods that throw stable unsupported errors.
- Physical-device validation pending for a package-only internal release, if
  release notes explicitly say so.

## Current Gaps

As of this doc:

- Dart unit and contract coverage now has a machine-readable matrix and
  validator for all public `RlnClient`, `UtexoWallet`, and core export rows.
- Native Android JVM and iOS XCTest bridge reports are produced by
  `tool/test_native_android.sh` and `tool/test_native_ios.sh`.
- Fresh iOS and Android platform JSON reports are produced by
  `tool/test_platform_unfunded.sh` and `tool/test_platform_funded.sh`; rerun
  them for every release candidate and retain the generated reports.
- Android native instrumentation still exists only in the RN repo, not this
  Flutter repo. The Flutter repo currently relies on Android JVM bridge tests
  plus Flutter platform smokes for real native-artifact execution.
- Physical-device validation is not documented as completed.
- Performance baselines are not recorded.
- Secret-redaction log scanning is not automated.

These gaps do not mean the implementation is fake. They mean the current proof
is not yet complete enough to claim exhaustive cross-platform function
coverage.
