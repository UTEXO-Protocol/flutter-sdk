# Technical Plan

## Goal

Build a production-grade Flutter plugin package that provides scoped functional
parity with `@utexo/rgb-sdk-rn` while fitting naturally into Flutter/Dart.

Parity means:

- Every React Native low-level native bridge method has a Dart equivalent.
- Every React Native high-level `UTEXOWallet` behavior has a Dart equivalent.
- Lifecycle, signer behavior, error behavior, unsupported-method behavior, and
  return models are documented and testable.
- iOS and Android both use the same RLN artifact version unless deliberately
  pinned otherwise.

Full package-level parity also includes RN's top-level re-exports from
`@utexo/rgb-sdk-core` (`generateKeys`, key derivation, message signing,
validation helpers, and core base classes). Those are not native RLN bridge
methods and remain a separate Phase 6/7 workstream.

## Recommended Bridge Strategy

Use a Flutter plugin with a typed Dart facade over native Swift/Kotlin.

```text
Dart public API
  -> Dart RLN client
  -> Pigeon platform API
  -> Swift/Kotlin plugin implementation
  -> RLN UniFFI Swift/Kotlin bindings
  -> Rust RGB Lightning Node
```

This mirrors the React Native package's architecture but removes the React
Native/TurboModule layer.

## Why Not Direct Dart FFI First?

The current RLN release does expose C symbols through UniFFI-generated headers,
but the ergonomic API is generated for Swift and Kotlin. Binding the raw
UniFFI C layer directly from Dart would require reimplementing UniFFI
serialization, object handles, RustBuffer management, callback tables, error
lifting, and external signer glue.

That is possible, but it is not the shortest reliable path to parity.

Direct Dart FFI can become Phase 6 if we decide to own a Dart-friendly C ABI or
if upstream provides Dart UniFFI generation.

## Package Shape

```text
rgb_sdk_flutter/
  lib/
    rgb_sdk_flutter.dart
    src/
      client/
      models/
      platform/
      wallet/
      errors/
  pigeons/
    rln_api.dart
  ios/
    rgb_sdk_flutter.podspec
    Classes/
      RgbSdkFlutterPlugin.swift
      RlnNodeStore.swift
      RlnBridge.swift
  android/
    build.gradle.kts
    src/main/kotlin/com/utexo/rgb_sdk_flutter/
      RgbSdkFlutterPlugin.kt
      RlnNodeStore.kt
      RlnBridge.kt
  example/
```

## Public Dart Layers

### Low-Level API

`RlnClient` should expose the low-level RLN bridge surface with names close to
the RN implementation:

- `createNode`
- `initNode`
- `unlockNode`
- `shutdown`
- `destroyNode`
- `nodeInfo`
- `listAssets`
- `rgbInvoice`
- `sendRgb`
- `lnInvoice`
- `sendPayment`

The low-level layer is for parity and diagnostics.

### High-Level Wallet API

`UtexoWallet` should mirror `UTEXOWallet`:

- `init`
- `unlock`
- `reinit`
- `shutdown`
- `destroy`
- `getBtcBalance`
- `getAddress`
- `listAssets`
- `send`
- `blindReceive`
- `witnessReceive`
- `createLightningInvoice`
- `payLightningInvoice`
- `openChannel`
- `closeChannel`

This layer owns lifecycle sequencing, signer orchestration, and parity
behavior.

## Native Artifact Strategy

Start by consuming the same release artifacts as the RN package:

- iOS: `RGBLightningNode.xcframework` from
  `rgb-lightning-node-swift-0.6.0-beta.2.zip`.
- Android: Maven artifact
  `com.utexo:rgb-lightning-node-android:0.6.0-beta.2`.

The package must pin artifact versions in one documented place.
Checksums and mirror policy live in `doc/SUPPLY_CHAIN.md`; local verification
lives in `tool/verify_native_artifacts.sh`.

## Platform API Strategy

Use Pigeon for generated platform contracts.

Reasons:

- Type-safe Dart, Swift, and Kotlin glue.
- Better for a 54-method parity surface than hand-written string dispatch.
- Clear generated diffs when API changes.

Allowed exception:

- Keep one raw diagnostics method during early development if needed:
  `invokeRaw(method, args)`.

## Threading And Lifecycle

All native RLN calls must execute off the main/UI thread.

iOS:

- Use a serial queue or task queue for lifecycle operations.
- Use background queue for expensive calls.
- Main thread only for returning Pigeon responses.

Android:

- Use `Dispatchers.IO`.
- Protect node and signer maps with a mutex.
- Preserve RN's lifecycle states:
  `CREATED`, `INITIALIZED`, `UNLOCKING`, `UNLOCKED`, `SHUTDOWN`.

## Error Model

Dart should expose `RlnException`:

- `code`
- `message`
- `details`
- `platform`
- `operation`

Map native errors into stable categories:

- `notInitialized`
- `invalidRequest`
- `notFound`
- `conflict`
- `internal`
- `unsupported`
- `nodeStateCorrupted`
- `platformUnavailable`

Unsupported RN methods should be intentionally represented, not silently
omitted.

## Security Model

Seed material and signer material are high risk.

Phase 1 may match RN's `NativeExternalRLNSigner` flow for parity, but production
must move toward:

- iOS Keychain/Secure Enclave compatible seed handling.
- Android Keystore compatible seed handling.
- No plaintext seed persistence in app documents.
- Explicit memory lifetime boundaries for seed hex/mnemonic.

The concrete app-level secure storage policy is documented in
`doc/SECURITY_MODEL.md`.

## Backup And Recovery

RN exposes `rlnBackup`, but the current native artifact reports it unsupported
on iOS and Android. This must be treated as a parity-known limitation and
product blocker.

Package behavior:

- Expose the method for API parity.
- Delegate to native `rlnBackup` and preserve the native unsupported error while
  the pinned RN-matching bridge lacks backup support.
- Track upstream backup support as a release blocker before recovery-ready
  mainnet wallet usage.

## Release Criteria

The package release gate is:

- All 55 low-level RN `rln*` methods exist in Dart.
- All high-level RN wallet methods exist or have documented parity-compatible
  unsupported behavior.
- Dart, iOS, and Android guard unsigned numeric conversions instead of allowing
  silent wraparound.
- iOS simulator smoke test passes.
- Android emulator smoke test passes when an emulator is available.
- Regtest node lifecycle test passes.
- Funded RGB asset issue/receive/send test passes locally on iOS and Android.
- Funded RGB Lightning invoice/payment test passes locally on iOS and Android.
- Backup/restore must pass before any recovery-sensitive mainnet release.
- API docs and parity matrix are updated.
- Package-level `@utexo/rgb-sdk-core` export parity is either implemented in
  Dart or explicitly declared out of scope for the consuming app.
