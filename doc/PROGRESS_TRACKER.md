# Progress Tracker

## Current State

Status: Current RN `dev` re-audited; low-level bridge, high-level
`UTEXOWallet`, signer, advanced manager/binding exports, and relevant
package-level core export parity are represented. Phase 6 public API surface
work is complete. Backup remains the only method-level native-artifact blocker;
`rlnSendRgb.skipSync=true` is a documented parameter-level artifact gap and
fails fast.

Repository: https://github.com/zeusbuilds/rgb-sdk-flutter

## Checklist

- [x] Research RN package architecture.
- [x] Identify native artifact sources.
- [x] Extract RN low-level method surface.
- [x] Extract RN high-level wallet surface.
- [x] Create docs-first repository plan.
- [x] Create private GitHub repo.
- [x] Push initial docs.
- [x] Create GitHub milestones.
- [x] Create GitHub issues.
- [x] Scaffold Flutter plugin.
- [x] Wire iOS artifact metadata and download script.
- [x] Wire Android artifact dependency metadata.
- [x] Add Pigeon bootstrap platform API.
- [x] Expand Pigeon platform API to all 55 low-level methods.
- [x] Expose all 55 low-level methods through `RlnClient`.
- [x] Implement lifecycle bridge slice.
- [x] Implement supported low-level RLN bridge methods.
- [x] Implement low-level bridge parity, with native-blocked backup exposed.
- [x] Implement high-level `UTEXOWallet` parity, with native-blocked backup and
      explicit RN-unsupported PSBT/VSS/bridge flows represented.
- [x] Add initial `UtexoWallet` facade over `RlnClient`.
- [x] Add local regtest Docker stack.
- [x] Add Flutter regtest smoke tests.
- [x] Verify empty example iOS simulator build.
- [x] Verify empty example Android debug build.
- [x] Implement Dart BIP86 key generation/derivation parity with RN core.
- [x] Implement Dart Schnorr message sign/verify parity with RN core.
- [x] Implement RN core validation, network preset, bridge helper, logger, and
      error-name exports relevant to the Flutter package.
- [x] Formally gate native backup as unsupported in the pinned RLN artifact.
- [x] Document app-level secure storage policy.
- [x] Add native artifact checksum verification.
- [x] Define local release policy and stop-ship conditions.
- [x] Define complete testing architecture and implementation phases.
- [x] Add machine-readable method test matrix.
- [x] Add exhaustive Dart contract coverage report for every public API.
- [x] Add native iOS and Android bridge tests.
- [x] Add function-by-function iOS/Android platform report from fresh release
      device runs.
- [x] Add release-candidate test report automation.
- [x] Add RN-style `RLNBinding`, `RLNManager`, `createRLNManager`, and
      `RNSigner` public exports.
- [x] Add RN-source parity release gate against pinned RN `dev`.

## Parity Counts

- Low-level RN `rln*` methods exposed in Dart: `55 / 55`
- Low-level RN `rln*` native usable implementations: `54 / 55`
- Low-level RN `rln*` Pigeon contracts: `55 / 55`
- Machine-readable test matrix rows: `196 / 196`
- Public Dart API contract coverage in matrix: `196 / 196`
- RN-source parity gate: validates `NativeRgb.ts`, `UTEXOWallet`, and
  `src/index.ts` runtime exports against Flutter source/matrices.
- Low-level RN `rln*` native-blocked methods: `1 / 55` (`rlnBackup`)
- Low-level RN `rln*` parameter-level native gaps:
  `rlnSendRgb.skipSync=true` is rejected before native execution because the
  pinned `0.6.0-beta.2` RLN artifact has no `SendRgbRequest.skipSync` field.
- High-level wallet methods/behaviors represented: typed supported facade +
  explicit unsupported stubs for RN-only PSBT/VSS/bridge methods.
- RN signer architecture represented: `RlnSigner`, `PasswordRlnSigner`, and
  `NativeExternalRlnSigner`; native external signer permissive policy defaults
  to RN-compatible `true`.
- RN core-style model mapping represented: additive `*Core` methods and
  `toCore()` extensions for balances, assets, invoices, UTXOs, transactions,
  and transfers.
- Unsupported RN/high-level methods represented: explicit stubs for
  PSBT/VSS/bridge-only flows.
- Package-level RN `src/index.ts` export parity: implemented for
  Flutter-relevant runtime exports, including RN-style `RLNBinding`,
  `RLNManager`, `createRLNManager`, and `RNSigner`. TypeScript-oriented core
  base classes/interfaces are represented by Dart facades and typed DTOs rather
  than duplicated as runtime classes.
- Native artifact platforms wired: `2 / 2 metadata`, `2 / 2 empty plugin builds`
- Most recent local verification in this branch: Dart formatting, analysis,
  unit tests, example tests, Pigeon drift check, Swift parse, Android Kotlin
  compile, native Android JVM bridge tests, native iOS XCTest bridge tests,
  iOS simulator build, Android debug build, and iOS/Android unfunded and funded
  regtest smokes all passed locally.
- Native artifact checksums are recorded in `tool/native_artifacts.sha256` and
  verified by `tool/verify_native_artifacts.sh`.
- Complete testing target state and implementation phases are documented in
  `doc/TESTING_STRATEGY.md`.
- Bootstrap bridge tests passing: `3 / 3`
- Native bridge test runners: Android JVM report via
  `tool/test_native_android.sh`; iOS XCTest report via
  `tool/test_native_ios.sh`.
- Numeric guardrails: Dart facade and native iOS/Android bridges validate
  bounded integer and fee-rate inputs before unsigned RLN conversion.

## Latest Decisions

- Use Flutter plugin with Pigeon and Swift/Kotlin native bridges.
- Consume same RLN artifacts as RN for initial parity.
- Do not implement direct Dart FFI first.
- Treat backup as exposed/native-blocked until upstream artifact supports it;
  do not claim mainnet wallet recovery readiness before that changes.
- Treat `rlnSendRgb.skipSync=true` as explicitly unsupported until upstream
  native artifacts expose the field; default RGB sends with `skipSync=false`
  remain supported.
- Backup and restore are intentionally skipped in the current hardening pass;
  release policy forbids recovery-ready claims while that remains true.
- Repository renamed to `rgb-sdk-flutter`; Dart package name is
  `rgb_sdk_flutter`.
- Public high-level wallet should use idiomatic Dart `UtexoWallet` to mirror
  RN `UTEXOWallet`.
- Public app code should use `UtexoWallet` for lifecycle state. `RlnClient`
  remains a stateless low-level bridge; `RLNBinding` and `RLNManager` exist for
  RN-style advanced/testing flows. The lifecycle/concurrency contract and
  intentional RN divergences are documented in `doc/BEHAVIORAL_CONTRACT.md`.
- Phase 1 bootstrap bridge exposes `nativeArtifactInfo()` with pinned RN and
  RLN versions.
- All 55 RN `NativeRgb` methods now exist in the generated Pigeon host API.
- Phase 2 lifecycle slice is implemented on iOS and Android:
  node create/init/unlock/shutdown/destroy, native signer lifecycle, external
  signer init/attach/unlock, `nodeInfo`, and `networkInfo`.
- Phase 2 read/health slice is implemented on iOS and Android:
  `address`, `btcBalance`, `checkIndexerUrl`, `checkProxyEndpoint`,
  `listPeers`, `listChannels`, `listPayments`, and `sync`.
- Phase 2 BTC foundation slice is implemented on iOS and Android:
  `createUtxos`, `estimateFee`, `listTransactions`, `listUnspents`, and
  `sendBtc`.
- Phase 2 RGB asset foundation slice is implemented on iOS and Android:
  `assetBalance`, `decodeRgbInvoice`, `failTransfers`, `listAssets`,
  `listTransfers`, `refreshTransfers`, `rgbInvoice`, `sendRgb`, and all four
  asset issuance methods (`NIA`, `CFA`, `IFA`, `UDA`).
- Phase 2 peer/channel/Lightning foundation slice is implemented on iOS and
  Android: peer connect/disconnect, channel open/close/id lookup, BOLT11 decode,
  invoice status, payment lookup, keysend, LN invoice creation, and LN payment
  send.
- An isolated local regtest stack now lives under `tool/regtest`, using
  non-conflicting defaults: bitcoind RPC `18444`, electrs `50002`, RGB proxy
  `3003`.
- The gated iOS and Android simulator regtest smokes pass against the local
  stack for lifecycle, unlock, sync, address, BTC balance, empty
  peers/channels/payments, endpoint checks, empty asset listing, transfer
  refresh, and no-asset transfer failure recovery.
- Funded RGB and RGB-Lightning behavior is covered by the host-coordinated
  simulator smoke harness on both iOS and Android simulators.
- `rlnBackup` remains exposed and native-blocked because the pinned RN-matching
  native bridge reports unsupported backup behavior on iOS and Android.
- The public Dart `UtexoWallet` facade owns node lifecycle (`init`, `unlock`,
  `shutdown`, `destroy`, `reinit`) and delegates supported Bitcoin, RGB,
  Lightning, peer, and channel operations to `RlnClient`.
- RN high-level methods that depend on upstream RN-only PSBT construction,
  signing, VSS backup, or service-backed flows now exist as explicit
  unsupported methods instead of missing Dart API surface.
- The gated iOS and Android simulator smokes now include a `UtexoWallet` facade
  workflow in addition to the low-level `RlnClient` workflow.
- `UtexoWallet` supported methods now return typed Dart models or deliberate
  RN-shaped parity wrappers instead of raw `Map<Object?, Object?>` responses for
  balances, assets, invoices, transfers, transactions, fee rates, peers,
  channels, node info, network info, and payments.
- Current RN `dev` changed `estimateFeeRate()` back to a fee-rate number and
  uses RN-shaped Lightning/on-chain wrapper responses; the Dart facade now
  matches those shapes while preserving raw RLN helper methods.
- Current RN `dev` top-level `createWallet` and core crypto/key exports are now
  represented in Dart with vector-tested BIP32/BIP86 key derivation and
  BIP340 Schnorr message signing/verification.
- RN `dev` beta.19 is now the parity target. Phase 1 updated the native
  artifact baseline to RLN `0.6.0-beta.2`; Phase 2 added low-level
  `rlnApayNewWithAddress`; Phase 3 added the high-level wallet/LSP attested
  APay registration and refill flow; Phase 4 added LSP proof wire mapping,
  default `utexo` LSP URL resolution, and pre-init virtual-channel setup; Phase
  5 matched older RN defaults, normalized native enum/status casing, and
  documented lifecycle/divergence behavior; Phase 6 added RN-style public
  manager, binding, and signer exports.
- UTEXO network preset, destination asset, bridge invoice/status helper, bridge
  API client, logger, validation helper, unit conversion, and RN-compatible
  error-name exports now exist for package-level parity.
- A host-coordinated funded regtest smoke harness now exists at
  `tool/regtest/flutter_funded_smoke.sh`. It services funding/mining requests
  emitted by the simulator test and covers two-wallet RGB issuance/send/receive
  behavior, peer connection, RGB channel open, RGB Lightning invoice creation,
  RGB Lightning payment send, and receiver invoice final-state assertion.
- On 2026-06-23, the full local native/platform proof passed on both iOS and
  Android: native bridge tests, unfunded regtest smokes, and funded
  RGB/RGB-Lightning smokes. The local regtest bitcoind RPC config was fixed so
  host-published RPC is verified before simulator/emulator tests start.
