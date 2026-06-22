# Test Matrix

This directory is the machine-readable testing contract for the package.

- `rln_methods.json`: every public `RlnClient` method and the expected platform
  proof level.
- `wallet_methods.json`: every public `UtexoWallet` method, including
  supported methods, aliases, unsupported parity stubs, and native-blocked
  backup.
- `core_exports.json`: package-level RN core-style exports.
- `../rn_parity_manifest.json`: the exact RN `dev` runtime export aliases and
  explicitly scoped-out TypeScript-only runtime/type-star boundaries.
- Rows may include `limitations` for parameter-level native artifact gaps that
  do not block the whole method.

Validate the matrix with:

```sh
dart run tool/validate_test_matrix.dart
dart run tool/validate_rn_parity.dart
```

The validator fails when a public low-level or wallet method exists without a
matrix row, when matrix rows are stale, when required fields are missing, or
when a row still uses a non-release-ready contract status such as `planned`.

`validate_rn_parity.dart` reads the RN `dev` checkout directly and fails when
RN `NativeRgb.ts`, `UTEXOWallet`, or `src/index.ts` runtime exports drift from
the Flutter method matrices and public Dart package barrel. Set
`RGB_SDK_RN_PATH` if the RN checkout is not at the manifest default path.
