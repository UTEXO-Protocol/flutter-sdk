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
| Durable credential storage | Consuming app owner plus Flutter maintainer | `SEC-009` | App-owned storage boundary; SDK owns only in-memory minimization and diagnostics. | `doc/INTEGRATION_SECURITY_AND_RELEASE.md`; release package validation requires `SECURITY.md`. | SDK product scope expands to include a native secure-storage subsystem. |
| Native builds/regtest in CI | Release owner | `TEST-017`, `G-12` | Keep native builds and funded regtest smokes local-only, but mandatory for release evidence. | `tool/test_release_candidate.sh` fails skipped required gates unless explicitly debug-overridden. | CI is provisioned with reliable simulators/emulators and a funded regtest stack. |

## API Stability Tiers

The public package is split into tiers. The root barrel still exports too much;
that cleanup is tracked separately, but every symbol must be classified by
intent before release.

| Tier | Meaning | Examples today | Compatibility rule |
| --- | --- | --- | --- |
| Stable facade | App-facing APIs intended to survive release. | `RgbSdkFlutter`, `UtexoWallet`, signer config, domain wallet DTOs. | Breaking changes require a tracker row, migration note, API snapshot update, and semver plan. |
| Advanced parity | RN/native-shaped APIs for parity testing, diagnostics, and escape hatches. | `RlnClient`, `RLNBinding`, `RLNManager`, raw bridge maps. | Can change when RN/native changes, but changes must cite the RN baseline and update parity tests. |
| Compatibility shim | Legacy or transitional exports kept to avoid abrupt local breakage. | Old aliases, core-shaped helpers, raw status helpers. | Must be deprecated or quarantined before production release. |
| Unsupported/native-blocked | Public names that exist only to fail honestly. | `createBackup` while native backup is blocked. | Must fail before native side effects and must be documented as not release-ready. |
| Internal | Implementation details. | Native stores, bridge error mapper internals, LSP implementation helpers. | Must not be exported from the stable facade once `CODE-001` is closed. |

## Dart Adaptation Map

Dart may adapt TypeScript-shaped inputs only when it keeps the same domain
semantics and the adaptation is tested.

| Area | RN/core shape | Flutter shape | Accepted adaptation | Required evidence |
| --- | --- | --- | --- | --- |
| Lifecycle credentials | RN methods accept password/mnemonic/native signer params near node lifecycle calls. | `UtexoWallet.init`, `unlock`, `reinit`, and `RlnSigner` strategies. | Flutter may use typed signer strategies, but must not persist credentials implicitly and must fail if required secrets are missing. | `test/utexo_wallet_test.dart::supports RN-style password signer in constructor`; `test/utexo_wallet_test.dart::supports RN-style native external signer lifecycle`; lifecycle group platform stress remains open. |
| Network/default resolution | Core defaults plus native-only `utexo` mapping. | `UtexoWalletConfig`, `UtexoUnlockConfig`, `NetworkDefaults`. | Flutter validates SDK-facing network names and maps native-only values only at the boundary. | `test/utexo_wallet_test.dart::exports RN-style network defaults and unlock resolution`; `API-022`, `API-023`. |
| RGB send skip-sync | RN accepts a parameter the pinned native artifact ignores. | `sendRgb` / `UtexoWallet.send` expose `skipSync` with fail-fast validation. | Flutter rejects `true` until upstream implements it. | `API-006`; bridge and wallet tests named in the divergence register. |
| Lightning aliases | RN has JS-friendly aliases and raw request objects. | Flutter exposes typed methods and a compatibility layer. | Typed methods are preferred; aliases must map field-for-field or be deprecated. | `API-010`, `API-016`, and Group 2 migration work. |
| On-chain receive/send requests | Core uses domain request/response models; RN often passes object literals. | Flutter uses typed request classes. | Typed request classes are allowed if units, optionality, defaults, and native field names are documented. | `MODEL-016`, `API-014`, and Group 2/3 vectors. |
| Raw request DTOs | RN/native bridge sends loose JS objects and maps. | Low-level `RlnClient` still exposes raw maps for advanced parity. | Raw map APIs stay advanced-only; stable facade must return domain models. | `CODE-001`, `CODE-005`, and API snapshot gate. |

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

1. Stable app facade and domain DTOs.
2. Advanced RN/native parity library.
3. Generated Pigeon/native bridge.
4. Native RLN artifacts.

Stable app code must not depend on raw Pigeon maps or native-only lifecycle
handles once Group 2 closes.
