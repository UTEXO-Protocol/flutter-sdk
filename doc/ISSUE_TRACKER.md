# Issue Tracker

This file mirrors the GitHub issues so the repo remains useful offline.

## Milestones

1. Phase 0: Docs And Planning
2. Phase 1: Package Skeleton And Native Artifacts
3. Phase 2: Low-Level RLN Client Parity
4. Phase 3: High-Level Wallet Parity
5. Phase 4: Bitcoin And RGB Workflows
6. Phase 5: Lightning And Channel Workflows
7. Phase 6: Hardening And Release Candidate
8. Phase 7: Proof, Matrix, Docs, Release Gate

## Initial Issues

| Title | Milestone | Labels | Status |
|---|---|---|---|
| Create Flutter plugin package skeleton | Phase 1 | package, flutter | done |
| Wire iOS RLN XCFramework artifact | Phase 1 | ios, native-artifacts | done |
| Wire Android RLN Maven artifact | Phase 1 | android, native-artifacts | done |
| Define Pigeon platform API contracts | Phase 2 | pigeon, api | done |
| Implement native node lifecycle bridge | Phase 2 | lifecycle, ios, android | done |
| Implement signer bridge parity | Phase 2 | signer, security | done |
| Implement all supported low-level RN rln methods | Phase 2 | parity, api | done |
| Implement UtexoWallet high-level wrapper | Phase 3 | wallet, parity | done |
| Represent unsupported RN methods intentionally | Phase 3 | parity, errors | done |
| Implement BTC wallet workflows | Phase 4 | bitcoin | done |
| Implement RGB asset workflows | Phase 4 | rgb | done |
| Implement Lightning workflows | Phase 5 | lightning | done for local RGB LN smoke; device hardening remains Phase 6 |
| Implement peer and channel workflows | Phase 5 | channels | done for local RGB channel smoke; device hardening remains Phase 6 |
| Build regtest verification harness | Phase 5 | testing, regtest | done for BTC/RGB/RGB-LN smoke |
| Security review signer and seed flow | Phase 6 | security | done for package crypto vectors and documented app secure-storage policy |
| Add native artifact checksum verification | Phase 6 | supply-chain, release | done |
| Define local release policy | Phase 6 | release | done |
| Define complete testing architecture | Phase 6 | testing, release | done |
| Add machine-readable method test matrix | Phase 6 | testing, parity | done |
| Add exhaustive Dart contract coverage for public APIs | Phase 6 | testing, parity | done for Dart low-level, wallet facade, core helpers, unsupported parity, native-blocked backup, and RGB send `skipSync` fast-fail |
| Add iOS and Android native bridge unit/instrumentation tests | Phase 6 | testing, ios, android | done for Android JVM bridge tests and iOS XCTest bridge tests; deeper Android instrumentation remains future hardening |
| Add iOS/Android function-by-function platform report | Phase 6 | testing, release | done for local simulator/emulator reports; rerun per release candidate |
| Add release-candidate test report automation | Phase 6 | testing, release | done for local static/unit/report gate; platform reports are opt-in with devices |
| Resolve or formally gate backup support | Phase 6 | backup, release-blocker | gated; upstream artifact support still required for recovery-ready mainnet use |
| Decide/implement package-level core export parity | Phase 6 | parity, core-api | done for Flutter-relevant runtime exports |

GitHub issue tracker: https://github.com/zeusbuilds/rgb-sdk-flutter/issues

## Release Readiness Audit - RN dev 2026-06-22

Status: release-candidate gated for the implemented non-backup surface; not
recovery-ready while backup remains native-blocked.

This audit compares the Flutter SDK against React Native SDK `dev` at
`3d0cc8c8e170e493e1090a88216759043a37e03c`.

Baseline found:

- RN package: `@utexo/rgb-sdk-rn` `1.0.0-beta.19`.
- RN native RLN artifact inputs: `com.utexo:rgb-lightning-node-android:0.6.0-beta.2`
  and `rgb-lightning-node-swift-0.6.0-beta.2.zip`.
- Flutter SDK package now reports RN parity `1.0.0-beta.19`.
- Flutter SDK native artifacts now pin RLN `0.6.0-beta.2`.
- RN low-level native method surface now has 55 `rln*` methods.
- Flutter Pigeon/RlnClient method surface now has 55 methods.
- Phase 2 closed the low-level `rlnApayNewWithAddress` bridge gap.

The earlier "done" rows in this tracker and in `doc/PARITY_MATRIX.md` are stale
for this baseline. They must not be used as release evidence until the blockers
below are resolved.

### Release Blockers

| ID | Priority | Area | Gap / Risk | Evidence | Acceptance Criteria |
|---|---:|---|---|---|---|
| REL-001 | P0 | Native artifacts / versioning | Resolved by Phase 1: Flutter now targets RN `1.0.0-beta.19` / RLN `0.6.0-beta.2`. Keep this row as the audit trail for the baseline upgrade. | RN: `package.json`, `android/build.gradle`, `scripts/download-rln-bindings.js`. Flutter: `lib/rgb_sdk_flutter.dart`, `android/build.gradle.kts`, `tool/download_rln_ios.sh`, `tool/verify_native_artifacts.sh`, `ios/Classes/RgbSdkFlutterPlugin.swift`, `android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbSdkFlutterPlugin.kt`. | Done: all Dart/native constants, Android dependency, iOS download script, artifact verification, checksum file, docs, example tests, and native artifact info tests point to RN `1.0.0-beta.19` / RLN `0.6.0-beta.2`; iOS and Android example builds pass against the new artifacts. |
| REL-002 | P0 | Low-level bridge | Resolved by Phase 2: `rlnApayNewWithAddress(nodeId, hostNodeId, username, domain)` now exists in Pigeon, `RlnClient`, Android, and iOS. Keep this row as the audit trail for the beta.19 low-level bridge catch-up. | RN: `src/binding/NativeRgb.ts`, `src/binding/IRLN.ts`, `src/binding/RLNBinding.ts`, `src/wallet/rln-manager.ts`, `android/src/main/java/com/rgbsdkrn/RgbModule.kt`, `ios/RgbSwiftHelper.swift`. Flutter: `pigeons/rln_api.dart`, `lib/src/client/rln_client.dart`, generated Pigeon files, and native plugin implementations. | Done: method matrix is 55/55, Dart contract coverage asserts argument order, generated bindings include the method, and iOS/Android example builds compile against the native `0.6.0-beta.2` artifacts. |
| REL-003 | P0 | Wallet API | Resolved by Phase 3: `UtexoWallet.apayNewWithAddress(hostNodeId, username, domain)` now registers APay batches with Lightning Address attestation parameters. | RN: `src/wallet/utexo-wallet.ts`. Flutter: `lib/src/wallet/utexo_wallet.dart`. | Done: validates non-empty host node id, username, and domain; maps native output into `ApayNewResponse`; covered by fake-host wallet tests and platform builds. |
| REL-004 | P0 | LSP / APay security | Resolved by Phase 3: `UtexoLsp.enableLightningAddress()` now resolves the LSP-provisioned address first and registers exactly one attested batch with `apayNewWithAddress`. | RN: `src/lsp/UtexoLsp.ts`. Flutter: `lib/src/lsp/utexo_lsp.dart`. | Done: fetches node pubkey and LSP info, polls `getLightningAddressByPubkey`, calls `wallet.apayNewWithAddress(lspPubkey, username, domain)`, returns `username`, `domain`, `address`, `unusedHashes`, `nextIndexExpected`, and `refillBatchSize`; tests prove the bootstrap `apayNew` call is not used. |
| REL-005 | P0 | LSP / APay lifecycle | Resolved by Phase 3: `UtexoLsp.refillHashPool()` now exists and registers fresh attested APay batches. | RN: `src/lsp/UtexoLsp.ts`, `CHANGELOG.md`, `docs/async-payments.md`. Flutter: `lib/src/lsp/utexo_lsp.dart`. | Done: resolves wallet pubkey and LSP address, calls `wallet.apayNewWithAddress`, returns `ApayNewResponse`, and is covered by fake-host refill tests. |
| REL-006 | P0 | LSP wire models | Resolved by Phase 4: Flutter now preserves LNURL callback APay `proof` and `getLightningAddressByPubkey` `recipient_pubkey` / `address_sig` data. | RN: `src/lsp/lsp-types.ts`, `src/lsp/UtexoLSPClient.ts`. Flutter: `lib/src/lsp/lsp_types.dart`, `lib/src/lsp/utexo_lsp_client.dart`. | Done: added `LspApayInvoiceProofWire`, `LspLnurlpCallbackWire`, `ApayInvoiceProof`, and `ApayMerkleProofElement`; maps proof from snake_case to Dart camelCase through `fromWire`; adds `recipientPubkey` and `addressSig`; wire mapping is covered by tests. |
| REL-007 | P0 | LSP defaults | Resolved by Phase 4: `network: utexo` now resolves the default LSP URL `https://lsp-signet.utexo.com` for no-arg `createLsp()` and native node creation. | RN: `src/wallet/network-defaults.ts`, `src/wallet/utexo-wallet.ts`. Flutter: `lib/src/wallet/network_defaults.dart`, `UtexoWallet.createLsp`. | Done: added `getDefaultLspBaseUrl(network)` and `resolveLspBaseUrl(network, lspBaseUrl)`; exported by the existing package barrel; used in `createLsp()` and `_createNode()`; throws loudly when no explicit or default URL exists. |
| REL-008 | P0 | Virtual channels / LSP startup order | Resolved by Phase 4: no-arg `createLsp()` now fetches the LSP pubkey, enables `enableVirtualChannelsV0`, appends the LSP pubkey to `virtualPeerPubkeys`, and fails after node creation because those params are baked into native node creation. | RN: `src/wallet/utexo-wallet.ts` (`nodeCreated`, `enableVirtualChannelsForPeer`). Flutter: `lib/src/wallet/utexo_wallet.dart`. | Done: tracks node-created state separately; keeps internal mutable node-create overrides while public config remains immutable; tests prove `_createNode()` receives virtual-channel settings and no-arg `createLsp()` fails after init. |
| REL-009 | P1 | Signer parity | Resolved by Phase 5: `NativeExternalRlnSigner.permissivePolicy` now defaults to `true`, matching RN `RLNBinding.rlnCreateNativeExternalSigner`, while explicit `false` remains supported. | RN: `src/wallet/rln-signers.ts`, `src/binding/RLNBinding.ts`. Flutter: `lib/src/wallet/rln_signers.dart`, `test/utexo_wallet_test.dart`. | Done: tests prove omitted policy reaches native as `true` and explicit strict policy reaches native as `false`. |
| REL-010 | P1 | Wallet default parity | Resolved by Phase 5: `UtexoWallet.createUtxos()` now defaults `upTo` to `true`, matching RN. | RN: `src/wallet/utexo-wallet.ts`. Flutter: `lib/src/wallet/utexo_wallet.dart`, `test/utexo_wallet_test.dart`. | Done: wallet utility defaults test calls `createUtxos()` without `upTo` and asserts the host receives `true`. |
| REL-011 | P1 | Enum/status normalization | Resolved by Phase 5: Dart model constructors canonicalize channel status, invoice status, send/keysend payment status, payment type, and transaction type so iOS/Android casing differences do not leak into app code. | RN: `src/binding/RLNBinding.ts` (`canonicalEnum`, `toUpperCase`). Flutter: `lib/src/models/rln_models.dart`, `test/utexo_wallet_test.dart`. | Done: model-boundary fixtures cover camel-case and already-canonical values for `RlnChannel.status`, `RlnInvoiceStatus.status`, `RlnPaymentResult.status`, `RlnPayment.status`, `RlnPayment.paymentType`, and `RlnTransaction.transactionType`. |
| REL-012 | P1 | Package-level API parity | Resolved by Phase 6: Flutter now exports Dart equivalents for RN `RLNManager`, `createRLNManager`, `RLNBinding`, and `RNSigner`, while core TypeScript base/interface exports are explicitly scoped to Dart facades/DTOs. | RN: `src/index.ts`, `src/wallet/rln-manager.ts`, `src/binding/RLNBinding.ts`, `src/signer/RNSigner.ts`. Flutter: `lib/rgb_sdk_flutter.dart`, `lib/src/binding/rln_binding.dart`, `lib/src/wallet/rln_manager.dart`, `lib/src/signer/rn_signer.dart`, `test/rln_manager_contract_test.dart`. | Done: advanced exports compile from the package barrel, `RLNBinding` owns and serializes one native node id, `RLNManager` delegates the full RN-style low-level method surface, `RNSigner` delegates message signing and PSBT stubs, and docs no longer claim undifferentiated 100% TS export parity. |
| REL-013 | P1 | Stateful binding lifecycle | Resolved by Phase 6: Dart `RLNBinding` and `RLNManager` now provide the RN-style stateful binding surface with serialized operations and one-shot unlock conflict normalization. | RN: `src/binding/RLNBinding.ts`, `src/wallet/rln-manager.ts`. Flutter: `lib/src/binding/rln_binding.dart`, `lib/src/wallet/rln_manager.dart`, `doc/BEHAVIORAL_CONTRACT.md`, `test/rln_manager_contract_test.dart`, `test/utexo_wallet_test.dart`. | Done: lifecycle guards, aliases, `reinit` rules, `destroy`, LSP ordering, binding node-id ownership, duplicate node-create rejection, idempotent destroy, and unlock conflict consumption are tested. |
| REL-014 | P1 | Test matrix / fake confidence | Resolved by Phase 7: the release gate now compares Flutter matrices/package exports directly against RN `dev` source. | Flutter: `tool/test_matrix/rln_methods.json`, `tool/test_matrix/wallet_methods.json`, `tool/test_matrix/core_exports.json`, `tool/rn_parity_manifest.json`, `tool/validate_test_matrix.dart`, `tool/validate_rn_parity.dart`. | Done: `validate_rn_parity.dart` extracts RN `NativeRgb.ts`, `UTEXOWallet`, `src/index.ts` runtime exports, and TypeScript-only type-star boundaries; it fails on missing/stale mappings and is part of `tool/test_release_candidate.sh`. |
| REL-015 | P1 | Docs / release claims | Resolved by Phase 7: README, readiness, release policy, testing strategy, test report template, matrix README, and progress tracker now describe the RN beta.19/RLN beta.2 baseline and the non-backup release boundary. | Flutter: `README.md`, `doc/PARITY_MATRIX.md`, `doc/PRODUCTION_READINESS.md`, `doc/PROGRESS_TRACKER.md`, `doc/RELEASE_POLICY.md`, `doc/TESTING_STRATEGY.md`, `doc/TEST_REPORT_TEMPLATE.md`. | Done: docs describe release-candidate hardening for implemented non-backup surfaces, keep backup/recovery as a mainnet product gate, and include the RN-source parity validator. |
| REL-016 | P2 | Backup / recovery product gate | `rlnBackup` remains native-blocked upstream and Flutter gates it. This is not fake parity because RN is also blocked, but a production wallet still needs a formal recovery story before mainnet release. | RN and Flutter native backup paths throw/are unavailable; Flutter tracker marks backup gated. | Keep backup out of parity scope only if product release notes explicitly say recovery is provided by another approved mechanism. Otherwise create a separate mainnet release blocker for VSS/backup/restore. |
| REL-017 | P2 | Intentional behavior divergences | Resolved by Phase 5 as documented safer Flutter behavior: RGB send `skipSync=true` fails fast, `getXpub()` returns available data, `getPayment()` keeps the RN-facing lookup shape over the native bridge, and LSP waits throw explicit timeout exceptions. | Flutter: `RlnClient.sendRgb`, `UtexoWallet.getXpub`, `RlnClient.getPayment`, `UtexoLsp.waitForOutboundLiquidity`, `doc/BEHAVIORAL_CONTRACT.md`, `test/utexo_wallet_test.dart`, `test/rln_client_contract_test.dart`. | Done: each divergence is documented and covered by existing or added tests, so it is no longer hidden drift. |
| REL-018 | P2 | Native platform proof | Resolved as a repeatable local release gate: native Android JVM bridge tests, iOS XCTest bridge tests when `IOS_DEVICE` is set, optional iOS/Android regtest smokes, and native artifact verification are all captured by the release-candidate script/report. | Flutter: `tool/test_release_candidate.sh`, `tool/test_native_android.sh`, `tool/test_native_ios.sh`, `tool/test_platform_unfunded.sh`, `tool/test_platform_funded.sh`, `test/`, `android/src/test`, `example/ios/RunnerTests`. RN: `android/src/androidTest`. | Done: the package now has an auditable release report flow. Full simulator/emulator smokes remain local opt-in by current project decision and were run locally on 2026-06-23 for iOS and Android, funded and unfunded. |

### Important Non-Blocker Findings

- `sendRgb(skipSync: true)` remains unsupported by the RN `0.6.0-beta.2`
  native `SendRgbRequest` shape. Flutter's fail-fast behavior is documented as
  an intentional safer divergence.
- Existing `rlnBackup` gating is honest, not a fake implementation. The problem
  is product recovery readiness, not hidden code pretending backup works.

## RN Dev Beta.19 Fix Plan

This plan tracks the implementation order for closing the release-readiness
audit above. Each phase must end with its own verification pass before moving to
the next phase.

| Phase | Status | Scope | Release Gaps Covered | Completion Gate |
|---|---|---|---|---|
| Phase 1: Baseline And Native Artifact Catch-Up | complete | Update the Flutter package to RN `1.0.0-beta.19` and RLN `0.6.0-beta.2`; refresh version constants, Android/iOS artifact pins, checksum data, and native artifact docs. | REL-001 | Package reports the new RN/RLN versions; artifact download/verification scripts point at the new release; checksum metadata is refreshed; docs no longer describe the previous RN/RLN baseline as current. |
| Phase 2: Low-Level Bridge Parity | complete | Add `rlnApayNewWithAddress` through Pigeon, Dart, Android, and iOS; update method matrix and bridge tests. | REL-002 | Flutter low-level bridge matches RN's 55-method `rln*` surface and the new method has Dart + native coverage. |
| Phase 3: Wallet And APay API | complete | Add `UtexoWallet.apayNewWithAddress`, rework `enableLightningAddress`, add `refillHashPool`, and return pool metadata. | REL-003, REL-004, REL-005 | Attested APay registration and refill behavior match RN, without the old double-registration flow. |
| Phase 4: LSP UX, Defaults, And Virtual Channels | complete | Add APay proof/address wire models, default `utexo` LSP URL resolution, and no-arg `createLsp` virtual-channel auto-wiring before node creation. | REL-006, REL-007, REL-008 | LSP/APay wire data is preserved, `network: utexo` works without explicit `lspBaseUrl`, and virtual-channel setup cannot be silently applied after node creation. |
| Phase 5: Older Parity Corrections | complete | Fixed signer policy default, `createUtxos(upTo)` default, enum/status normalization, stateful lifecycle/concurrency contract, and documented behavior divergences. | REL-009, REL-010, REL-011, REL-013, REL-017 | No known silent RN behavior drift remains from these older corrections; intentional Flutter divergences are documented and tested. |
| Phase 6: Public API Surface Decision | complete | Added Dart equivalents for `RLNManager`, `createRLNManager`, `RLNBinding`, and `RNSigner`; clarified broad core export scope as Dart facades/DTOs for TypeScript-oriented base/interface exports. | REL-012 | Public API claims match the implemented contract; advanced RN-style exports exist and TypeScript-only export gaps are not hidden as runtime parity. |
| Phase 7: Proof, Matrix, Docs, Release Gate | complete | Added RN-source comparison gates, updated matrices, tightened validators, wired the new gate into release-candidate automation, and rewrote release docs from the final truth. | REL-014, REL-015, REL-016, REL-018 | Release-candidate automation now proves RN source parity, wallet/LSP/APay behavior through existing tests, expected backup gating, native artifact integrity, and local platform compatibility gates. |

### Phase Verification Log

#### Phase 1: Baseline And Native Artifact Catch-Up

Date: 2026-06-22

Result: passed.

Commands/checks:

- `RLN_VERSION=0.6.0-beta.2 FORCE_RLN_DOWNLOAD=1 SKIP_RLN_VERIFY=1 ./tool/download_rln_ios.sh`
- Direct upstream checksum capture:
  - iOS zip: `6ce1c107650b1078f3b94c30dc5fd68740147f73c2d22bd831abd751b72fa827`
  - Android AAR: `94c343928bc3bdf7dcbd584d446ec9559e198909971bb40d91901b588400d8df`
- `VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh`
- `REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh`
- `fvm dart format lib/rgb_sdk_flutter.dart`
- `git diff --check`
- `fvm dart run tool/validate_test_matrix.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test`
- `fvm flutter build ios --simulator --no-codesign` from `example/`
- `fvm flutter build apk --debug` from `example/`

Notes:

- Phase 1 did not close method parity. Phase 2 closed the
  `rlnApayNewWithAddress` low-level bridge gap.
- `rlnBackup` remains honestly native-blocked.
- `sendRgb(skipSync: true)` remains intentionally fail-fast because RN
  `0.6.0-beta.2` `SendRgbRequest` still has no `skipSync` field.

#### Phase 2: Low-Level Bridge Parity

Date: 2026-06-22

Result: passed.

Done:

- Added `rlnApayNewWithAddress(nodeId, hostNodeId, username, domain)` to the
  Pigeon host API.
- Regenerated Dart, Kotlin, and Swift Pigeon bindings.
- Exposed `RlnClient.apayNewWithAddress`.
- Implemented Android and iOS native handlers against the RLN
  `apayNewWithAddress` native method.
- Added Dart contract coverage that asserts exact host method name and argument
  order.
- Updated low-level method matrix and docs from `54 / 55` to `55 / 55`.

Commands/checks:

- `./tool/generate_pigeon.sh`
- `fvm dart format pigeons/rln_api.dart lib/src/client/rln_client.dart lib/src/pigeon/rln_api.g.dart test/rln_client_contract_test.dart test/utexo_wallet_test.dart`
- `git diff --check`
- `fvm dart run tool/validate_test_matrix.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test`
- `fvm flutter build ios --simulator --no-codesign` from `example/`
- `fvm flutter build apk --debug` from `example/`
- `REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh`

New issues found during Phase 2:

- None. The remaining APay work is already tracked by `REL-003`, `REL-004`,
  and `REL-005` because this phase intentionally stops at the low-level bridge.

#### Phase 3: Wallet And APay API

Date: 2026-06-22

Result: passed.

Done:

- Added `UtexoWallet.apayNewWithAddress(hostNodeId, username, domain)`.
- Added non-empty validation for host node id, username, and domain.
- Reworked `UtexoLsp.enableLightningAddress()` to resolve the LSP-provisioned
  address first, then register exactly one attested APay batch.
- Extended `LightningAddressInfo` with `unusedHashes`, `nextIndexExpected`, and
  `refillBatchSize`.
- Added `UtexoLsp.refillHashPool()` for fresh attested APay batches.
- Updated the wallet method matrix and high-level parity docs.
- Added wallet/LSP tests proving the plain `apayNew` bootstrap call is not used
  by the Lightning Address flow.

Commands/checks:

- `fvm dart format lib/src/wallet/utexo_wallet.dart lib/src/lsp/utexo_lsp.dart test/utexo_wallet_test.dart`
- `git diff --check`
- `fvm dart run tool/validate_test_matrix.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test`
- `fvm flutter build ios --simulator --no-codesign` from `example/`
- `fvm flutter build apk --debug` from `example/`

New issues found during Phase 3:

- None. APay proof/address wire-model gaps were tracked by `REL-006` and
  closed in Phase 4.

#### Phase 4: LSP UX, Defaults, And Virtual Channels

Date: 2026-06-22

Result: passed.

Done:

- Added APay proof wire and public response models for LNURL callback proof
  data.
- Preserved `recipient_pubkey` and `address_sig` in
  `LspLightningAddressByPubkeyResponse`.
- Added `getDefaultLspBaseUrl` and `resolveLspBaseUrl`, including the `utexo`
  default `https://lsp-signet.utexo.com`.
- Updated native node creation to use the default `utexo` LSP URL.
- Updated no-arg `createLsp()` to fetch the LSP pubkey, enable virtual channels,
  append the LSP pubkey to native node-create params, and reject calls after
  node creation.
- Added tests for wire mapping, default LSP URL resolution, pre-init virtual
  channel wiring, and post-init ordering failure.

Commands/checks:

- `fvm dart format lib/src/lsp/lsp_types.dart lib/src/wallet/network_defaults.dart lib/src/wallet/utexo_wallet.dart test/utexo_wallet_test.dart`
- `git diff --check`
- `fvm dart run tool/validate_test_matrix.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test`
- `fvm flutter build ios --simulator --no-codesign` from `example/`
- `fvm flutter build apk --debug` from `example/`

New issues found during Phase 4:

- None. Remaining gaps are the already-filed Phase 5 signer/default/enum
  corrections and later release-proof work.

#### Phase 5: Older Parity Corrections

Date: 2026-06-22

Result: passed.

Done:

- Matched RN signer default semantics by changing
  `NativeExternalRlnSigner.permissivePolicy` to default to `true`.
- Preserved explicit strict native signer policy with
  `permissivePolicy: false`.
- Matched RN wallet funding default by changing `UtexoWallet.createUtxos()` to
  default `upTo=true`.
- Added Dart model-boundary normalization for channel status, invoice status,
  payment result status, stored payment status, stored payment type, and
  transaction type.
- Documented the Flutter lifecycle/concurrency contract:
  `UtexoWallet` owns state, `RlnClient` remains a stateless bridge, and callers
  should serialize lifecycle-changing wallet calls.
- Documented intentional safer Flutter divergences: RGB send `skipSync=true`
  fail-fast behavior, useful `getXpub()` data return, broader native
  `getPayment()` lookup shape, and explicit LSP timeout exceptions.

Commands/checks:

- `fvm dart format lib/src/wallet/rln_signers.dart lib/src/wallet/utexo_wallet.dart lib/src/models/rln_models.dart test/utexo_wallet_test.dart`
- `git diff --check`
- `fvm dart run tool/validate_test_matrix.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test`
- Stale wording scan for old Phase 5 gap claims.
- `REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh`
- `fvm flutter build ios --simulator --no-codesign` from `example/`
- `fvm flutter build apk --debug` from `example/`

New issues found during Phase 5:

- None during Phase 5. RN-source comparison gates and release-candidate
  platform proof were later closed in Phase 7.

#### Phase 6: Public API Surface Decision

Date: 2026-06-22

Result: passed.

Done:

- Added public Dart `RLNBinding` with RN-style node-id ownership, serialized
  operation queue, lifecycle state checks, and one-shot
  `consumeRlnUnlockConflictNormalized()`.
- Added public Dart `RLNManager` and `createRLNManager()` that delegate the
  complete RN-style low-level method surface to `RLNBinding`.
- Added public Dart `RNSigner` for message signing, verification, and RN-parity
  PSBT unsupported stubs.
- Exported the new advanced APIs from `package:rgb_sdk_flutter`.
- Updated the core export matrix with advanced export rows.
- Clarified docs so TypeScript-oriented core base classes/interfaces are not
  silently claimed as runtime Dart export parity.

Commands/checks:

- `fvm dart format lib/rgb_sdk_flutter.dart lib/src/binding/rln_binding.dart lib/src/wallet/rln_manager.dart lib/src/signer/rn_signer.dart test/rln_manager_contract_test.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test test/rln_manager_contract_test.dart`
- `fvm flutter test`
- `fvm dart run tool/validate_test_matrix.dart`
- `REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh`
- `fvm flutter build ios --simulator --no-codesign` from `example/`
- `fvm flutter build apk --debug` from `example/`

New issues found during Phase 6:

- None during Phase 6. RN-source comparison gates and release-candidate
  platform proof were later closed in Phase 7.

#### Phase 7: Proof, Matrix, Docs, Release Gate

Date: 2026-06-22

Result: passed for source/matrix/docs gate, release-candidate automation,
native artifact verification, Android JVM bridge tests, and example iOS/Android
builds. iOS XCTest and platform smokes were not run in this pass because no
`IOS_DEVICE`, `ANDROID_DEVICE`, or `RUN_PLATFORM=1` release-run device
configuration was provided.

Done:

- Added `tool/rn_parity_manifest.json` with the pinned RN `dev` commit,
  runtime export aliases, explicit TypeScript-oriented scoped-out runtime
  exports, and documented type-star boundaries.
- Added `tool/validate_rn_parity.dart` to compare RN source directly against
  Flutter:
  - RN `src/binding/NativeRgb.ts` methods against `rln_methods.json`
    `hostApi` rows.
  - RN `src/wallet/utexo-wallet.ts` public methods against
    `wallet_methods.json`.
  - RN `src/index.ts` runtime exports against `lib/rgb_sdk_flutter.dart`.
- Wired RN-source parity validation into `tool/test_release_candidate.sh`.
- Tightened `tool/validate_test_matrix.dart` so synchronous public wallet
  methods are also tracked.
- Added missing matrix rows for `UtexoWallet.isDisposed`,
  `UtexoWallet.getNetwork`, and `UtexoWallet.getLspConfig`.
- Updated README, readiness, release-policy, testing-strategy, report-template,
  progress, and matrix docs to describe the RN beta.19/RLN beta.2 truth and the
  non-backup release boundary.

Commands/checks:

- `fvm dart format tool/validate_rn_parity.dart tool/validate_test_matrix.dart`
- `fvm dart run tool/validate_rn_parity.dart`
- `fvm dart run tool/validate_test_matrix.dart`
- `fvm flutter analyze --no-fatal-warnings --no-fatal-infos`
- `fvm flutter test`
- `REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh`
- `./tool/test_release_candidate.sh`
  - Report:
    `build/test-reports/release/release-candidate-0080480.json`
  - Native Android report:
    `build/test-reports/release/native-android-0080480.json`
- `flutter build ios --simulator --no-codesign` from `example/`
- `flutter build apk --debug` from `example/`

New issues found during Phase 7:

- The old matrix validator only scanned `Future` methods. It missed synchronous
  public RN-facing wallet methods, so the validator now parses public class
  method declarations instead.
- `wallet_methods.json` was missing `isDisposed`, `getNetwork`, and
  `getLspConfig`. Those rows are now tracked.

#### Local Platform Proof Rerun

Date: 2026-06-23

Result: passed after fixing the local regtest bitcoind RPC exposure.

Decisions confirmed:

- Backup/recovery remains native-blocked and product-release gated.
- `sendRgb(skipSync: true)` remains fail-fast until upstream native artifacts
  expose a matching field.
- Native builds and regtest smokes remain local-only, not CI jobs.
- Pigeon Swift/Kotlin bridges remain the implementation path for now; no Dart
  FFI migration in this release slice.
- Upstream native artifacts remain acceptable for development/internal beta,
  with checksum verification.
- Secure storage remains app-owned: the SDK does not persist mnemonic, seed,
  password, signer material, or backup artifacts.

Fixes made:

- The regtest stack's host-published bitcoind RPC returned HTTP 403 even though
  in-container `bitcoin-cli` worked. The local compose config now widens
  bitcoind `rpcallowip` for this isolated regtest stack.
- `regtest.sh start` now proves host RPC readiness with authenticated `curl`
  before launching simulator/emulator smokes, preventing false native
  `FailedBitcoindConnection` failures.
- The funded smoke now prints explicit `RGB_SDK_FLUTTER_STEP` breadcrumbs at
  every expensive RGB/RGB-Lightning boundary.

Commands/checks:

- `DEVICE='iPhone Air' ./tool/test_native_ios.sh`
- `./tool/test_native_android.sh`
- `DEVICE='46B8C95D-F0CD-4E50-9C98-61A8F84176AB' ./tool/test_platform_unfunded.sh`
- `DEVICE='emulator-5554' ./tool/test_platform_unfunded.sh`
- `DEVICE='46B8C95D-F0CD-4E50-9C98-61A8F84176AB' ./tool/test_platform_funded.sh`
- `DEVICE='emulator-5554' ./tool/test_platform_funded.sh`

Reports are generated under:

- `build/test-reports/native/`
- `build/test-reports/platform/`

## Issue Writing Standard

Each implementation issue should include:

- Scope.
- RN reference files and methods.
- Flutter API target.
- iOS implementation notes.
- Android implementation notes.
- Acceptance criteria.
- Test plan.
