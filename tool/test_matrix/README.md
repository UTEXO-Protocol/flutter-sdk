# Test Matrix

This directory contains the machine-readable implementation inventory:

- `rln_methods.json`: declared `RlnClient` method coverage.
- `wallet_methods.json`: declared `UtexoWallet` method coverage.
- `core_exports.json`: declared package-level core-style exports.
- `evidence_catalog.json`: executable evidence IDs, report families, claim
  levels, and assertions for every evidence bucket.
- `bridge_behavior_vectors.json`: low-level bridge family vectors, critical
  method vectors, and numeric transport policy.
- `../rn_parity_manifest.json`: deliberate runtime export aliases and scoped
  exclusions.
- `../release_baseline.json`: the single immutable RN/core/RLN source and
  artifact baseline.

## Important Limitation

These files are an inventory, not proof of release readiness. The validator
checks row shape, implementation-symbol metadata, evidence buckets, and local
source coverage. Every evidence bucket must resolve through
`evidence_catalog.json` to executable test IDs, report families, claim levels,
and assertions. The RN parity validator also checks the exact RN baseline,
NativeRgb method names, low-level parameter names/types/nullability, return
categories, wallet method inventory, and runtime exports.

The inventory is aligned to RN `1.0.0-beta.27`, core `1.0.0-beta.7`, and RLN
`0.10.0-beta.3`. It still does not prove defaults, request/response fields,
native implementations, native error categories, lifecycle behavior, platform
agreement, or real funds behavior. A row can be linked to executable evidence
that proves only a unit contract, expected failure, or current smoke path; the
release tracker decides whether that evidence is sufficient for a release
claim.

```sh
dart run tool/validate_test_matrix.dart
dart run tool/validate_bridge_vectors.dart
RGB_SDK_RN_PATH=<current-rn-checkout> \
  dart run tool/validate_rn_parity.dart
```

Both commands are required truth-telling checks. Passing them proves static
inventory parity only; release readiness additionally requires native/platform
evidence from the tracker.

See the
[Release Readiness Tracker](../../doc/RELEASE_READINESS_TRACKER.md) for the
authoritative gaps and replacement requirements. The matrices must eventually
move from bucket-level evidence links to row-specific immutable reports and
native implementation evidence where the tracker requires it.
