# API Compatibility and Divergence Policy

This document defines how `rgb-sdk-flutter` decides API parity with
`rgb-sdk-rn`, when a Dart-shaped API is allowed to differ, and how breaking
changes are staged. It is a release gate, not background guidance.

## Source Precedence

When RN source, core declarations, and native RLN artifacts disagree, use this
order:

1. Native RLN runtime behavior and artifact capabilities.
2. `@utexo/rgb-sdk-core` declarations and mapper semantics.
3. `rgb-sdk-rn` public TypeScript API shape.
4. Existing Flutter compatibility surface.

The native runtime wins because a wrapper cannot honestly support behavior the
pinned artifact does not implement. Core wins over RN naming when core defines
the domain contract and RN is only adapting that contract to React Native.
Flutter compatibility is last and may only remain through an explicit
compatibility or advanced API boundary.

## Approved Divergence Register

Every intentional divergence needs an owner, a tracker row, a test/evidence
reference, and a reversal trigger. New divergences must be recorded before they
ship.

| Divergence | Owner | Tracker | Current decision | Evidence | Reversal trigger |
| --- | --- | --- | --- | --- | --- |
| `createBackup` / `rlnBackup` | Native artifact owner plus Flutter maintainer | `API-019`, `G-11` | Keep native-blocked and fail before claiming recovery support. | `test/utexo_wallet_test.dart::keeps local backup explicitly native-blocked`; Android/iOS native backup-blocked bridge cases. | Pinned native RLN exposes a working backup/recovery implementation and cross-platform funded recovery tests pass. |
| `sendRgb(skipSync: true)` | Flutter maintainer | `API-006` | Fail fast instead of accepting and silently discarding the value. | `test/rln_client_contract_test.dart::sendRgb rejects skipSync true before native call`; Android/iOS native skip-sync rejection cases. | Pinned native RLN exposes a real skip-sync request field and RN/core define semantics. |
| `gossipRgsServerUrl` unlock field | Flutter maintainer | `API-030` | Reject non-empty values because native signer unlock currently ignores the field. | `test/utexo_wallet_test.dart::rejects no-op gossip RGS unlock configuration`. | Pinned native RLN signer unlock consumes the field end to end. |
| High-level CFA/UDA issuance | Flutter maintainer | `API-017` | Expose only through low-level RN-parity `RlnClient`/`RLNBinding`, not the stable wallet facade. | Wallet matrix excludes `issueAssetCfa`/`issueAssetUda`; low-level matrix keeps the RN methods. | RN adds wallet-level CFA/UDA methods or product approves a Flutter-only extension library. |
| Standalone account-key Schnorr signing default | Flutter maintainer plus release security owner | `SEC-007` | Fail closed by default and require `SchnorrSigningMode.experimentalDart` for the pure-Dart signer, even though RN's top-level core `signMessage` is callable by default. Wallet/node-key signing remains native RLN-backed and RN-aligned. | `test/crypto_bip340_vectors_test.dart::standalone Schnorr signing fails closed without explicit opt in`; `test/utexo_wallet_test.dart::signs and verifies RN-core compatible Schnorr messages`; `tool/validate_codebase_hardening.dart`. | Replace the pure-Dart implementation with a vetted/native signing primitive or complete a formal crypto review proving production suitability, then update public docs and parity tests before changing the default. |
| Durable credential storage | Consuming app owner plus Flutter maintainer | `SEC-009` | App-owned storage boundary; SDK owns only in-memory minimization and diagnostics. | `doc/INTEGRATION_SECURITY_AND_RELEASE.md`; release package validation requires `SECURITY.md`. | SDK product scope expands to include a native secure-storage subsystem. |
| Native builds/regtest in CI | Release owner | `TEST-017`, `G-12` | Keep native builds and funded regtest smokes local-only, but mandatory for release evidence. | `tool/test_release_candidate.sh` fails skipped required gates unless explicitly debug-overridden. | CI is provisioned with reliable simulators/emulators and a funded regtest stack. |

## API Stability Tiers

The public package is split into root-stable and explicit advanced/parity
entrypoints. Every root-exported symbol must be classified as app-facing,
domain, public error, validation/crypto helper, or documented compatibility
carrier. Raw RN/native parity symbols must live behind
`package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart`.

| Tier | Meaning | Examples today | Compatibility rule |
| --- | --- | --- | --- |
| Stable facade | App-facing APIs intended to survive release. | `RgbSdkFlutter`, `UtexoWallet`, signer config, domain wallet DTOs. | Breaking changes require a tracker row, migration note, API snapshot update, and semver plan. |
| Advanced parity | RN/native-shaped APIs for parity testing, diagnostics, migration tooling, and explicit escape hatches. | `RlnClient`, `RLNBinding`, `RLNManager`, `IRLN*`, raw `Rln*` models, native bridge mapper. | Can change when RN/native changes, but changes must cite the RN baseline and update parity tests. |
| Compatibility shim | Legacy or transitional exports kept to avoid abrupt local breakage. | Old aliases, core-shaped helpers, raw status helpers. | Must be deprecated or quarantined before production release. |
| Unsupported/native-blocked | Public names that exist only to fail honestly. | `createBackup` while native backup is blocked. | Must fail before native side effects and must be documented as not release-ready. |
| Internal | Implementation details. | Native stores, bridge error mapper internals, LSP implementation helpers. | Must not be exported from the stable facade once `CODE-001` is closed. |

## Model and Policy Ownership

The SDK keeps model layers intentionally one-directional:

| Layer | Owner | Allowed dependencies | Must not do |
| --- | --- | --- | --- |
| Raw native wire | `Rln*` models and generated Pigeon carriers | Pigeon JSON/maps, strict required-field decoding, `NativeProtocolException` | Return from stable canonical wallet methods. |
| Stable domain | `Core*`, `Lightning*`, wallet response DTOs | Raw models plus `UtexoDomainPolicy` mapper decisions | Decode platform maps directly or call native clients. |
| Wallet facade | `UtexoWallet` | Stable request/response DTOs, `WalletInputPolicy`, binding owner | Own raw validation constants, duplicate status tables, or expose native handles from stable methods. |
| Compatibility / advanced | `rgb_sdk_flutter_advanced.dart` | Stable root plus raw bridge/client/binding/manager APIs | Leak into `rgb_sdk_flutter.dart` without a tracker row and migration note. |
| Network/LSP | `UtexoLsp` and `UtexoLspClient` | Stable wallet DTOs, LSP wire DTOs, SDK error taxonomy | Throw Dart core exceptions or duplicate wallet/Lightning status normalization. |

`WalletInputPolicy` owns stable facade numeric/string/range validation.
`UtexoDomainPolicy` owns public transaction, transfer, and channel vocabulary
mapping. Network defaults remain in `network_defaults.dart` because they are a
separate environment-resolution policy shared by wallet creation and LSP
bootstrap. Public failures must cross the stable boundary as
`RgbSdkException` subclasses.

## Dart Adaptation Map

Dart may adapt TypeScript-shaped inputs only when it keeps the same domain
semantics and the adaptation is tested.

| Area | RN/core shape | Flutter shape | Accepted adaptation | Required evidence |
| --- | --- | --- | --- | --- |
| Lifecycle credentials | RN methods accept password/mnemonic/native signer params near node lifecycle calls. | `UtexoWallet.init`, `unlock`, `reinit`, and `RlnSigner` strategies. | Flutter may use typed signer strategies, but must not persist credentials implicitly and must fail if required secrets are missing. | `test/utexo_wallet_test.dart::supports RN-style password signer in constructor`; `test/utexo_wallet_test.dart::supports RN-style native external signer lifecycle`; lifecycle group platform stress remains open. |
| Network/default resolution | Core defaults plus native-only `utexo` mapping. | `UtexoWalletConfig`, `UtexoUnlockConfig`, `NetworkDefaults`. | Flutter validates SDK-facing network names and maps native-only values only at the boundary. | `test/utexo_wallet_test.dart::exports RN-style network defaults and unlock resolution`; `API-022`, `API-023`. |
| Public network-name helpers | Core beta.7 still has an internal `toNetworkName` heuristic, while RN beta.27 only root-exports exact `normalizeNetwork` plus callers such as `getNetworkVersions`. | `normalizeNetwork`, `getNetworkVersions`, and derivation-path helpers. | Flutter's stable public network-name path uses exact allowed values only. This is a deliberate safety tightening so malformed strings cannot silently select a real network. Core-only `toNetworkName` is not exported from the stable Flutter root because RN beta.27 does not export it. | `API-035`, `test/utexo_wallet_test.dart::matches RN-core seed derivation and utility behavior`. |
| Amount unit helpers | RN beta.27 root-exports `toUnitsNumber` and `fromUnitsNumber`; the published core beta.7 package also contains non-root BigInt helpers. | Dart root exports the RN beta.27 package surface only. | `toUnitsNumber` fails above JavaScript `Number.MAX_SAFE_INTEGER`, matching RN's safe-number boundary. Core-only BigInt helpers are kept out of the stable root until RN exports them or product approves a Flutter extension surface. | `API-034`, `test/utexo_wallet_test.dart::matches RN-core seed derivation and utility behavior`. |
| LSP discovery document | RN beta.27/core beta.7 `GET /get_info` returns pubkey, network, optional host/port, supported assets, and u64 policy limits as decimal strings. | `LspGetInfoResponse` and `LspSupportedAsset` use Dart `BigInt` for u64 policy fields and strict required-field decoding. | Flutter maps the beta.7 shape directly and removes the stale beta.6 alias/channel-count fields. Malformed LSP/APay DTO fields fail closed instead of fabricating empty strings or zeroes. | `API-033`, `MODEL-018`, `MODEL-019`, `test/utexo_wallet_test.dart::createLsp discovers peer host and port from beta.7 get_info`, `test/utexo_wallet_test.dart::LSP get_info parser matches beta.7 shape and preserves u64`, `test/utexo_wallet_test.dart::LSP DTO parsers fail closed for malformed required fields`. |
| RGB send skip-sync | RN accepts a parameter the pinned native artifact ignores. | `RlnClient.sendRgb` exposes `skipSync`; `UtexoWallet.onchainSend` validates it fail-fast. | Flutter rejects `true` until upstream implements it. | `API-006`; bridge and wallet tests named in the divergence register. |
| Wallet send spelling | Current RN deleted the old generic `send` wallet method and keeps `onchainSend`. | Flutter exposes only `UtexoWallet.onchainSend` at the stable facade. | No decoded-amount fallback; callers must pass `amount`, matching RN's current explicit validation. | `API-014`, `API-016`, `test/utexo_wallet_test.dart::requires explicit onchainSend amount instead of decoded fallback`. |
| Transfer listing | RN calls native `listTransfers('')` for unfiltered transfer listing. | Flutter calls the same native path when available. | If the pinned artifact rejects unfiltered listing, Flutter fails closed instead of falling back to known asset IDs and silently omitting no-asset transfers. Asset-filtered calls remain supported. | `API-028`, `test/utexo_wallet_test.dart::listTransfers fails closed when unfiltered native listing is rejected`. |
| Lightning aliases | RN keeps canonical Lightning status names and removed old RGB-folding request helpers. | Flutter exposes `getLightningReceiveStatus` and `getLightningSendStatus`; old request aliases are removed. | Statuses stay in the Lightning vocabulary instead of being folded into RGB transfer status. | `API-016`, `LSP-006`, and wallet status tests. |
| Message signing identity and crypto posture | RN exports account-key core signing helpers and wallet node-key signing with the same JS method names in different scopes. RN core signing is backed by the JS core package dependency stack and top-level `signMessage` is callable by default. | Flutter keeps top-level account-key helpers and adds explicit wallet `signNodeMessage`/`verifyNodeMessage` aliases. | Wallet `signMessage`/`verifyMessage` remain RN node-key aliases; new Dart app code should use the explicit node-key names when both scopes are imported. Standalone account-key signing fails closed unless callers explicitly opt into `SchnorrSigningMode.experimentalDart`, because the pure-Dart signer is not audited/proven constant-time. This default is an accepted `SEC-007` divergence, not exact RN top-level behavior. Verification remains enabled. | `API-018`, `SEC-007`, `test/utexo_wallet_test.dart::exposes current RLN address, inflation, lookup, signing, and VSS APIs`, `test/utexo_wallet_test.dart::signs and verifies RN-core compatible Schnorr messages`, `test/crypto_bip340_vectors_test.dart::standalone Schnorr signing fails closed without explicit opt in`. |
| Removed root exports | RN no longer exports old `RNSigner`, flat PSBT stubs, or UTEXO bridge/network helper maps from the package root. | Flutter root barrel no longer exports those implementation files. | Direct `src/` imports are unsupported; stable PSBT/begin-end capability is expressed through absent optional carriers. | `API-024`, public API snapshot, public API docs validator. |
| Error aliases | Core error classes carry stable `code`, optional `statusCode`, and serializable fields. | Flutter SDK errors expose the same fields through Dart exceptions plus `toJson()`. | Constructors remain Dart-native but preserve core semantic fields. | `API-026`, `test/utexo_wallet_test.dart::serializes core-compatible SDK errors`. |
| On-chain receive/send requests | Core uses domain request/response models; RN often passes object literals. | Flutter uses typed request classes. | Typed request classes are allowed if units, optionality, defaults, and native field names are documented. | `MODEL-016`, `API-014`, and `test/utexo_wallet_test.dart::documents and preserves timestamp and amount units at model boundaries`. |
| Raw request DTOs | RN/native bridge sends loose JS objects and maps. | Low-level `RlnClient` still exposes raw maps through `rgb_sdk_flutter_advanced.dart`. | Raw map APIs stay advanced-only; stable facade must return domain models. | `CODE-001`, `CODE-005`, and API snapshot gate. |
| Wallet facade return shapes | RN/native names may surface bridge DTOs. | Canonical `UtexoWallet` methods return stable domain DTOs; native `Rln*` models are reachable through explicit `Raw` methods. | Flutter app code should not consume bridge wire shapes by default. Raw access remains available for parity debugging and advanced native integration. | `API-007`, `API-010`, `test/utexo_wallet_test.dart::maps Bitcoin list methods to domain DTOs and raw escape hatches`, `test/utexo_wallet_test.dart::maps Lightning, peer, and channel methods to stable DTOs`. |

## Deprecation and Breaking-Change Plan

1. Classify every exported symbol as stable, advanced, compatibility,
   unsupported, or internal.
2. Add Dart `@Deprecated` annotations and README/API docs for compatibility
   shims before removing them.
3. Keep one migration table that maps old symbols to stable replacements.
4. Remove or quarantine stale exports before the first production release.
5. Update `tool/api_snapshot.json` only in the same change as the migration
   note and tracker row.

No breaking public change is considered complete unless `dart run
tool/validate_api_snapshot.dart`, `dart run tool/validate_rn_parity.dart`, and
`dart run tool/validate_release_governance.dart` pass.

## Architecture Decisions

### Bridge Technology

Use Pigeon-generated Swift/Kotlin bridges for this release line.

Alternatives evaluated: Dart FFI, `uniffi-bindgen-dart`, `uniffi-dart`, and a
bespoke C ABI. Pigeon is retained because the current native deliverable is
already platform-specific Swift/Kotlin packaging around RLN artifacts, and the
Dart public API can stay stable while the bridge is swapped later.

Reversal criteria: switch only if a UniFFI/FFI spike proves full compatibility
with the exact RLN UDL/artifacts, async APIs, callbacks/external signer flows,
error mapping, object lifecycle, iOS/Android packaging, and the parity test
matrix.

### Artifact Ownership

This package does not build upstream RLN artifacts. It consumes pinned
internal-beta artifacts, verifies checksums/ABIs/slices, and fails production
supply-chain mode until upstream signatures or reproducible-build attestations
exist.

### Stable Layering

The intended production layering is:

1. Stable app facade and domain DTOs through `rgb_sdk_flutter.dart`.
2. Advanced RN/native parity library through `rgb_sdk_flutter_advanced.dart`.
3. Generated Pigeon/native bridge.
4. Native RLN artifacts.

Stable app code must not depend on raw Pigeon maps or native-only lifecycle
handles. Advanced imports are allowed only when the caller intentionally accepts
the RN/native parity contract.

Flutter's old template `PlatformInterface`/method-channel shim was removed.
Native work has a single bridge owner: generated Pigeon `RlnHostApi` wrapped by
`RlnClient` and serialized by `RLNBinding`. The only stable package-level native
diagnostic is `RgbSdkFlutter.nativeArtifactInfo()`, which reads metadata through
the same generated Pigeon host API rather than a second substitutable platform
abstraction.
