# Test Matrix

This directory contains the machine-readable implementation inventory:

- `rln_methods.json`: declared `RlnClient` method coverage.
- `wallet_methods.json`: declared `UtexoWallet` method coverage.
- `core_exports.json`: declared package-level core-style exports.
- `../rn_parity_manifest.json`: deliberate runtime export aliases and scoped
  exclusions.
- `../release_baseline.json`: the single immutable RN/core/RLN source and
  artifact baseline.

## Important Limitation

These files are an inventory, not proof of release readiness. The current
validator checks names and row fields but does not prove signatures, defaults,
request/response fields, native implementations, errors, lifecycle behavior,
platform agreement, or real test execution. A row can declare a fixture and
contract without being linked to an executable behavioral test.

The inventory is aligned to the beta.25 low-level method set. The current
parity validator still compares names rather than full typed signatures and
does not inspect type exports comprehensively.

```sh
dart run tool/validate_test_matrix.dart
RGB_SDK_RN_PATH=<current-rn-checkout> \
  dart run tool/validate_rn_parity.dart
```

`validate_test_matrix.dart` currently passes. The parity command remains a
required truth-telling check and fails while current RN wallet methods are
missing from Flutter.

See the
[Release Readiness Tracker](../../doc/RELEASE_READINESS_TRACKER.md) for the
authoritative gaps and replacement requirements. The matrices must eventually
be generated from typed contracts and link each row to executable test IDs and
native implementations.
