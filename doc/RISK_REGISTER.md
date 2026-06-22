# Risk Register

## R1: Backup Unsupported In Current Artifacts

Severity: critical.

RN exposes backup, but the current native bridge reports unsupported behavior.
RGB client-side validation makes backup/recovery a core safety concern.

Mitigation:

- Expose the high-level API and delegate to native `rlnBackup` for parity.
- Preserve the native unsupported error while the pinned RN-matching bridge lacks
  backup support.
- Track as release blocker.
- Validate upstream artifact support before recovery-ready mainnet use.

## R2: Seed And Signer Handling

Severity: critical.

Native external signer parity may require passing seed hex or mnemonic through
the bridge during early implementation.

Mitigation:

- Key derivation and message signing now have RN-core vector tests in Dart.
- App-level secure storage policy is documented in `doc/SECURITY_MODEL.md`.
- Prefer host-backed signer strategies for production.

## R3: Direct UniFFI C Binding Complexity

Severity: high.

Direct Dart FFI against UniFFI-generated C symbols would require manual
UniFFI lifting/lowering.

Mitigation:

- Use Swift/Kotlin bridge first.
- Revisit only with a dedicated C ABI or upstream Dart binding.

## R4: RLN Maturity

Severity: high.

Upstream RLN/RGB Lightning is still beta/early and may be testnet/regtest
oriented.

Mitigation:

- Keep artifact versions pinned.
- Build regtest and testnet verification before any mainnet claim.
- Gate mainnet at the product layer.

## R5: Amount Overflow

Severity: high.

React Native uses JS `number`, but RLN uses `u64` in many places.

Mitigation:

- Dart public APIs use `int` and validate signed/bounded inputs before bridge
  calls.
- Native iOS and Android bridges validate unsigned conversions and preserve
  oversize returned unsigned values as strings instead of silently wrapping.
- Avoid `double` for amounts.

## R6: Platform Divergence

Severity: medium.

iOS and Android generated bindings may not expose identical behavior.

Mitigation:

- Maintain platform parity tests.
- Document platform-specific limitations in the parity matrix.

## R7: Artifact Download And Supply Chain

Severity: medium.

Large binary artifacts are downloaded from GitHub/Maven.

Mitigation:

- Pin exact versions.
- Record upstream and vendored artifact checksums in `doc/SUPPLY_CHAIN.md` and
  `tool/native_artifacts.sha256`.
- Verify local artifacts with `tool/verify_native_artifacts.sh`.
- Mirror artifacts privately before production app release.
