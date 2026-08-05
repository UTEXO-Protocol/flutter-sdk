# Dart Coverage Policy

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
flutter test --coverage
dart run tool/validate_coverage_policy.dart
```

`tool/validate_coverage_policy.dart` fails if `coverage/lcov.info` is missing,
contains no included source, or falls below any threshold above.
