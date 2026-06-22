# Native Artifacts

## Source Of Truth

React Native reference package:

- Repository: `UTEXO-Protocol/rgb-sdk-rn`
- Branch: `dev`
- Commit: `3d0cc8c8e170e493e1090a88216759043a37e03c`
- Package version: `1.0.0-beta.19`

Native RLN release:

- Repository: `UTEXO-Protocol/rgb-lightning-node`
- Release: `v0.6.0-beta.2`
- Release page:
  `https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/tag/v0.6.0-beta.2`

This Flutter package mirrors the checked-in RN build inputs for the baseline
above.

## iOS

RN downloads:

```text
https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/download/v0.6.0-beta.2/rgb-lightning-node-swift-0.6.0-beta.2.zip
```

Recorded upstream zip checksum:

```text
6ce1c107650b1078f3b94c30dc5fd68740147f73c2d22bd831abd751b72fa827  rgb-lightning-node-swift-0.6.0-beta.2.zip
```

The zip contains:

- `RGBLightningNode.xcframework`
- `RGBLightningNode.swift`
- `RGBLightningNodeFFI.h`
- `RGBLightningNodeFFI.modulemap`

Flutter package plan:

- Vendor or download the same Swift zip.
- Add `RGBLightningNode.xcframework` to the plugin podspec.
- Compile `RGBLightningNode.swift` with the plugin.
- Include `RGBLightningNodeFFI.h` and module map.

Initial preference:

- Keep artifact download as a script during development.
- Verify vendored files with `tool/verify_native_artifacts.sh`.
- Mirror artifacts privately before production app release.

## Android

RN Gradle dependency:

```gradle
implementation("com.utexo:rgb-lightning-node-android:0.6.0-beta.2")
implementation("net.java.dev.jna:jna:5.17.0@aar")
```

Recorded Android Maven AAR checksum observed locally:

```text
94c343928bc3bdf7dcbd584d446ec9559e198909971bb40d91901b588400d8df  rgb-lightning-node-android-0.6.0-beta.2.aar
```

Other requirements:

- `minSdkVersion 24`
- Kotlin
- Coroutines

Flutter package plan:

- Add the same dependencies to plugin `android/build.gradle`.
- Keep package namespace separate from RN:
  `com.utexo.rgb_sdk_flutter`.
- Use Kotlin bridge code that imports `org.utexo.rgblightningnode.*`.

## How Upstream Builds These Artifacts

The upstream Rust crate is configured as:

```toml
crate-type = ["lib", "staticlib", "cdylib"]
```

Release workflow:

- Builds Rust with features `uniffi,vls`.
- Generates Kotlin Android bindings from `bindings/rgb_lightning_node.udl`.
- Builds Android JNI libraries with `cargo-ndk`.
- Publishes Android artifact to Maven.
- Builds iOS static libraries for device and simulator targets.
- Packages them into `RGBLightningNode.xcframework`.
- Generates Swift bindings through UniFFI.

## Version Policy

All artifact versions must be pinned in:

- `doc/NATIVE_ARTIFACTS.md`
- `doc/SUPPLY_CHAIN.md`
- Dart package constants
- iOS podspec/script
- Android Gradle dependency

Do not upgrade iOS and Android independently unless documenting a platform
emergency.

Run this before release:

```sh
./tool/verify_native_artifacts.sh
```

Run this for a strict release-candidate supply-chain check:

```sh
REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh
```

## Known Artifact Gaps

- `rlnBackup` is exposed but unsupported by the current artifact bridge.
- `rlnSendRgb` keeps the RN-facing `skipSync` argument, but the pinned
  `0.6.0-beta.2` native `SendRgbRequest` type does not expose a `skipSync`
  field in the iOS Swift binding or Android AAR. The flag is therefore
  preserved for source parity and `skipSync=true` is rejected before native
  execution until upstream artifacts expose it.
- Mainnet maturity is not proven.
- Some UniFFI APIs are available upstream but not wrapped in RN.
- RN bridge has some cleanup issues that should not be copied blindly.
