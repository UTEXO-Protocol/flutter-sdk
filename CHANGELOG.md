## Unreleased

* Updated the RN parity target to `@utexo/rgb-sdk-rn` `1.0.0-beta.19` and
  pinned RLN native artifacts to `0.6.0-beta.2`.
* Added low-level `rlnApayNewWithAddress` bridge parity through Pigeon, Dart,
  Android, iOS, and contract tests.
* Added high-level APay address registration via
  `UtexoWallet.apayNewWithAddress`, updated `UtexoLsp.enableLightningAddress`
  to register one attested batch, and added `UtexoLsp.refillHashPool`.
* Preserved LSP APay proof/address-attestation wire data and added default
  `utexo` LSP URL plus pre-init virtual-channel wiring for no-arg `createLsp`.
* Matched RN defaults for native external signer permissive policy and
  `createUtxos(upTo)`, normalized native enum/status casing at the Dart model
  boundary, and documented the Flutter lifecycle/divergence contract.
* Added RN-style advanced public exports: `RLNBinding`, `RLNManager`,
  `createRLNManager`, and `RNSigner`, with contract coverage.
* Updated low-level bridge parity to `55 / 55`; backup remains the only
  native-blocked low-level method.

## 0.1.0 - 2026-05-22

* Implemented the app-facing `UtexoWallet` facade for Bitcoin, RGB, RGB
  Lightning, peer, channel, signer, and core DTO workflows.
* Exposed all 54 React Native low-level `rln*` methods through Dart/Pigeon,
  with the native-artifact-blocked `rlnBackup` preserved as a native-delegated
  unsupported path.
* Caught up to RN `dev` beta.17 for HODL invoice helpers, APay order creation,
  VSS clear fence, LSP helpers, expanded node creation/unlock fields, and
  Lightning invoice preimage/CLTV fields.
* Added RN-shaped high-level parity helpers for fee estimation, Lightning
  invoice creation/payment, request status polling, on-chain wrappers, and
  Lightning payment listing.
* Added Dart implementations for RN core key generation/derivation,
  BIP340 message signing/verification, validation helpers, UTEXO network
  presets, bridge helpers, logger, and compatible error names.
* Added `CoreTransferStatuses` constants for RN-compatible transfer status
  strings.
* Added Dart, Swift, and Kotlin guardrails for bounded integer fields,
  non-negative amounts, and fee-rate conversion before unsigned RLN calls.
* Added iOS and Android native bridge implementations, native artifact
  metadata, generated-code drift checks, unit tests, example tests, and local
  regtest smoke harnesses.
* Documented native-blocked backup, PSBT, VSS, and RN-only service flows as
  explicit limitations instead of missing API surface.

## 0.0.1 - 2026-05-22

* Initial private package scaffold.
* Added pinned RLN artifact metadata for React Native parity.
* Added Pigeon bootstrap host API for native artifact diagnostics.
