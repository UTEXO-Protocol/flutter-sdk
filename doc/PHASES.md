# Implementation Phases

## Phase 0: Docs And Planning

Exit criteria:

- Private GitHub repo exists.
- Technical plan exists.
- Parity matrix exists.
- Issue tracker exists.
- Milestones and implementation issues exist in GitHub.

## Phase 1: Package Skeleton And Native Artifacts

Exit criteria:

- Flutter plugin package scaffolded.
- iOS podspec resolves `RGBLightningNode.xcframework`.
- Android Gradle resolves `com.utexo:rgb-lightning-node-android`.
- Example app builds empty plugin on iOS simulator and Android emulator.
- Artifact versions pinned and documented.

## Phase 2: Low-Level RLN Client Parity

Exit criteria:

- All 55 RN `rln*` methods exist in Dart.
- Pigeon contracts generate Swift/Kotlin/Dart code.
- Native bridge compiles on iOS and Android.
- Node create/init/unlock/shutdown/destroy smoke tests pass.
- Error wrapping is stable.

## Phase 3: High-Level Wallet Parity

Exit criteria:

- `UtexoWallet` mirrors RN `UTEXOWallet`.
- Password signer and native external signer flows exist.
- Unsupported RN methods return typed unsupported errors.
- Lifecycle restart/reinit behavior matches RN.
- Amount and status mapping tests pass.

## Phase 4: Bitcoin And RGB Workflows

Exit criteria:

- BTC address, balance, send, transactions.
- RGB list assets, balance, invoice, send, transfers.
- Create UTXOs.
- Issue NIA/CFA/IFA/UDA where native support works.
- Regtest workflow documented and automated.

## Phase 5: Lightning And Channel Workflows

Exit criteria:

- LN invoice, decode, payment, payment polling.
- RGB LN invoice and payment.
- Peer connect/disconnect.
- Channel open/close/list/get id.
- Channel recovery/restart smoke tests.

## Phase 6: Hardening And Release Candidate

Exit criteria:

- iOS simulator and device test matrix defined.
- Android emulator and device test matrix defined.
- Backup limitation resolved or explicitly release-blocked.
- Security review for signer flows.
- Package-level RN core export parity implemented or explicitly scoped out.
- API docs complete.
- Changelog and versioning policy complete.

## Phase 7: Proof, Matrix, Docs, Release Gate

Exit criteria:

- RN `dev` source comparison gates exist for low-level methods, wallet methods,
  and package runtime exports.
- Matrix validators track synchronous and asynchronous public wallet methods.
- Release-candidate automation runs the RN-source parity gate.
- Docs describe the final RN/RLN baseline and the backup/recovery boundary.

## Future: Optional Dart FFI Investigation

Exit criteria:

- Decide whether to keep Swift/Kotlin bridge long-term or build a
  Dart-friendly Rust C ABI.
- Prototype direct FFI only if it beats the plugin bridge on maintenance,
  safety, and reliability.
