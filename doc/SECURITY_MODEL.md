# Security Model

This package is a bridge to native RGB Lightning Node artifacts. It can help
enforce safe API boundaries, but the consuming wallet app owns user consent,
device unlock policy, secure persistence, analytics policy, and recovery UX.

Backup and restore are intentionally excluded from this pass. The current
pinned RLN artifact reports `rlnBackup` as unsupported on iOS and Android, so a
mainnet wallet must not claim recovery readiness through this package yet.

## Sensitive Material

Treat these values as secret:

- BIP39 mnemonic phrases.
- Seed hex values.
- Wallet passwords.
- Native signer handles when they imply access to seed-backed signing.
- RLN storage directories and backup files.

The package must never log these values, include them in exception messages,
send them to analytics, or persist them in shared preferences, plain files, app
documents, screenshots, crash breadcrumbs, or support bundles.

## Package Boundary

The Dart layer provides these guardrails:

- `PasswordRlnSigner` accepts a mnemonic for RN parity and clears its retained
  mnemonic reference after native initialization.
- `NativeExternalRlnSigner` converts mnemonic or seed input into the native
  signer format and should be scoped to the shortest useful lifetime.
- Public wallet and client APIs validate empty strings, negative amounts,
  finite fee rates, and unsigned integer bounds before crossing the native
  bridge.
- Unsupported recovery and service-backed RN flows are explicit stubs, not
  silent no-ops.

These guardrails do not replace app-level secure storage.

## iOS Secure Storage Policy

For a production app, store seed material only as encrypted or wrapped data in
Keychain-backed storage.

Recommended defaults:

- Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for seed material when the
  product can require device unlock before wallet use.
- Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` only when background
  wallet work is required and explicitly reviewed.
- Use `SecAccessControl` with biometry or device passcode for high-risk actions
  if the UX requires local user presence.
- Do not use iCloud-synchronizing Keychain classes for wallet seed material
  unless a separate recovery and multi-device threat model is approved.
- Consider Secure Enclave only for wrapping/signing keys that fit its API; do
  not assume it can directly hold arbitrary BIP39 seed material.

Operational rules:

- Read seed material only at signer construction or unlock time.
- Keep plaintext seed strings out of view models and UI state.
- Clear Dart references and native handles as soon as the wallet lifecycle
  permits.
- Exclude wallet storage directories from iCloud backup unless a reviewed
  backup strategy requires otherwise.

## Android Secure Storage Policy

For a production app, store seed material only as encrypted blobs protected by
Android Keystore keys.

Recommended defaults:

- Generate a non-exportable AES-GCM wrapping key in Android Keystore.
- Prefer StrongBox-backed keys when available, while supporting a reviewed
  fallback path for devices without StrongBox.
- Use `setUserAuthenticationRequired(true)` for actions that require local user
  presence.
- Store only encrypted seed blobs in app-private storage or encrypted
  preferences.
- Disable Android Auto Backup for wallet storage unless a separate recovery
  design explicitly allows it.

Operational rules:

- Do not pass seed material through Intents, Bundles, logs, notifications, or
  crash reports.
- Keep signer handles tied to wallet lifecycle and release them during
  `destroy`.
- Treat rooted, debug, and emulator environments as lower-assurance contexts in
  product policy.

## Native Bridge Rules

- All native calls that can touch signer material or node state must run off the
  UI thread.
- Native error messages must be normalized before surfacing to Dart if they
  might include paths, seed material, passwords, or proxy credentials.
- Native storage paths must be app-private and should not be user-selectable
  without path normalization.
- Release builds must use pinned native artifact versions and verified
  checksums.

## Product Security Review Checklist

Before an app release that uses this package:

- Confirm mnemonic, seed, password, and backup path values are redacted from
  logs, analytics, crash reports, and support exports.
- Confirm iOS Keychain accessibility class and Android Keystore settings match
  the product threat model.
- Confirm wallet storage directories are excluded from OS cloud backup unless a
  reviewed recovery strategy says otherwise.
- Confirm simulator/regtest secrets cannot be compiled into production builds.
- Run funded regtest smokes on iOS and Android against the exact release
  artifact versions.
- Run `./tool/verify_native_artifacts.sh` and archive the output with release
  notes.
- Do not make recovery-ready mainnet claims until backup/restore has an
  approved implementation and platform proof.
