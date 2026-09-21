# Dart Coverage Policy

Coverage receipts include authored Dart tooling and all test fixtures in their
input digest, not only production Dart sources. Editing the verifier or a native
codec fixture invalidates an older receipt. Interface-only exclusions are parsed
structurally: adding an implementation, initializer, or constructor removes the
exclusion. These gates do not equate line coverage with platform behavior proof.

This policy covers Dart unit and contract tests only. It does not prove native
serialization, persistence, threading, regtest funds behavior, iOS/Android
archiveability, or release eligibility.

## Scope

Included:

- `lib/rgb_sdk_flutter.dart`
- hand-written Dart source under `lib/src/**`

Excluded:

- generated Pigeon code under `lib/src/pigeon/**`
- generated release baseline constants
- test files, tools, examples, native Swift/Kotlin, and build outputs

## Thresholds

The release gate requires:

- package line coverage at or above `65.0%`;
- `lib/src/wallet/**` at or above `80.0%`;
- `lib/src/lsp/**` at or above `65.0%`;
- `lib/src/crypto/**` at or above `70.0%`;
- `lib/src/models/**` at or above `70.0%`.

These are floor thresholds for the current release-hardening phase, not a
target quality ceiling. When a feature group adds high-risk logic, it must add
targeted tests even if the aggregate threshold already passes.

## Command

```sh
dart run tool/test_dart_coverage.dart
dart run tool/validate_coverage_policy.dart
```

`tool/validate_coverage_policy.dart` fails if `coverage/lcov.info` is missing,
contains no included source, omits current executable files, contains duplicate
records or inconsistent line summaries, or falls below any threshold above.
An AST check allows declaration-only interfaces and export-only libraries to
have no LCOV record; adding a method body removes that exemption automatically.

The runner deletes earlier output first and writes `coverage/evidence.json`
only after a successful test process. Its receipt binds LCOV to the exact Git
commit, source/test/dependency content hashes and complete source inventory.
Changed inputs or stale receipts fail validation. A dirty-tree receipt is useful
for development but does not qualify an immutable release candidate.
