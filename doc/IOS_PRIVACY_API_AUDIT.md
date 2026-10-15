# SDK required reason API audit

Audited 2026-10-16 against the pinned RLN v0.17.0-beta.3 iOS archive and SDK
source. This is a source/symbol review, not an App Store acceptance claim.

The SDK owns `ios/Resources/PrivacyInfo.xcprivacy`; the podspec includes it in
`rgb_sdk_flutter_privacy.bundle`. Apps cannot substitute their root manifest for
an SDK's declarations. `tool/validate_ios_privacy.py` checks the plist shape,
duplicate categories, exact source-justified reasons and no tracking claim;
`validate_release_package.dart` invokes it.

| Category | Declaration | Source justification |
| --- | --- | --- |
| FileTimestamp | `C617.1` | `RlnStorageDirectoryPolicy.swift` calls `lstat` to verify app-owned wallet directory owner, type and permissions. RLN `src/rgb_file_transfer.rs::cleanup_orphans_at` reads metadata/modified time inside its supplied app-container storage directory. SQLite/Rust persistence also imports `stat`, `fstat`, `lstat`. No filesystem metadata is used as device identity or telemetry. |

Integrators must keep `storageDirPath` inside their app container, as required by
`UtexoWalletConfig`. Do not reuse this justification for arbitrary external file
access or send filesystem metadata to a server.

## Native disk-space review remains open

`nm -u -A ios/RGBLightningNode.xcframework/ios-arm64/librgb_lightning_node.a`
finds `statfs`/`fstatfs` in the native SQLite object and `fstatfs`/`fstatvfs` in
Rustix. The inspected SQLite implementation uses filesystem type/flags to
select locking behavior; this is not evidence that it checks available storage.
Do not invent `E174.1` (free space for writing/deleting files) merely to satisfy a
scanner. The native publisher must identify the linked call paths, remove
unused calls or provide a truthful approved justification. Inspect the final
signed archive's required API report and aggregate privacy manifests before
closing the overall iOS privacy release gate. The package validator proves the
reviewed declaration is present; it does not close that native review.

No required SystemBootTime/UserDefaults/ActiveKeyboards imports were found in
the current native archive scan. Reaudit when any native artifact or dependency
changes. App/network data collection, VSS server data handling and store privacy
answers remain separate deployment review requirements.

Apple primary references (reviewed 2026-10-16):
- [Required reason API policy](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Category and approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [TN3183: manifest structure](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
