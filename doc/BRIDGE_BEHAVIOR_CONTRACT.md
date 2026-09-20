# Bridge Behavior Contract

This file defines the release-candidate contract for the low-level Flutter
bridge over the pinned React Native `NativeRgb` / RGB Lightning Node surface.
It is intentionally narrower than the product-facing wallet contract: it
answers whether the generated Pigeon bridge, Swift/Kotlin adapters, and Dart
decoder preserve the native behavior they claim.

The executable policy lives in
`tool/test_matrix/bridge_behavior_vectors.json` and is validated by:

```sh
dart run tool/validate_bridge_vectors.dart
```

## Source Order

1. Native RLN artifacts define runtime behavior.
2. React Native `dev` defines method names, parameter order, optionality, and
   current platform adapter intent.
3. Pigeon defines Flutter transport types.
4. Dart `RlnClient` decodes the transport into low-level maps.
5. `UtexoWallet` and model mappers turn those maps into stable domain shapes.

If these disagree, do not silently adapt at the call site. Either fix the
lower layer or record an approved divergence in
`doc/API_COMPATIBILITY_AND_DIVERGENCE.md`.

## Numeric Contract

Native RLN request structs use unsigned integer fields in many places. The
current Pigeon bridge transports Dart integers to Swift/Kotlin as signed 64-bit
values, so Flutter request inputs support:

- `UInt64`-semantic fields: `0..9223372036854775807`.
- `UInt32`, `UInt16`, `UInt8`, and signed `Int32` fields: the narrower native
  range, rejected by Swift/Kotlin before native mutation.
- Fee-rate fields that native accepts as unsigned integer sats/vbyte: finite,
  non-negative, integral `double` values.

Native outputs may contain unsigned 64-bit values. Swift and Kotlin bridge
adapters serialize values above signed `Int64.max` as decimal strings. Public
Dart models use signed `int` only for fields whose release fixtures and domain
contracts fit signed 64-bit values. Native unsigned capability fields that may
legitimately exceed signed 64-bit use an exact domain type instead; for example
`RlnNodeInfo.channelAssetMaxAmount` is `BigInt?` and accepts the full UInt64
range. Model mappers must never turn out-of-range native values into `0`,
`null`, a clamped value, or a default model.

The source constants are:

- `lib/src/models/rln_models.dart::rlnPigeonMaxSignedInt64`
- `lib/src/models/rln_models.dart::rlnMaxUnsigned64Decimal`

## Required Vectors

Every low-level bridge family must declare evidence for:

- Dart request delegation.
- Dart platform-error mapping.
- Malformed native wire response rejection where the method returns wire data.
- Native invalid-argument rejection before node lookup or mutation where the
  method has bounded request fields.
- Native unknown-node/signer error shape where the method requires a handle.
- Platform smoke or regtest success evidence for actual native execution.

Critical methods changed during the beta.26, beta.27, and beta.32/RLN 0.13
catch-ups also have method-specific vectors in
`bridge_behavior_vectors.json`, including `rotateAddress`, `signMessage`,
`verifyMessage`, txid-filtered history methods, detailed transfer refresh,
`lnInvoice`, `rgbInvoice`, and `inflate`.

## Malformed Wire Behavior

Swift/Kotlin return `RlnWireResponse(json: String)` for map-like responses.
Dart must reject:

- invalid JSON;
- valid JSON whose root is not an object for single-map calls;
- list responses containing any non-object element.

Malformed native output throws `NativeProtocolException`; it must not be
fabricated into an empty/default model.

## Release Claim Boundary

Passing the bridge-vector validator proves that the release candidate has a
complete declared bridge behavior policy and that the policy points to
executable evidence. It does not by itself prove funded runtime behavior.
Runtime eligibility still requires the local platform/regtest reports tracked
in `doc/RELEASE_READINESS_TRACKER.md`.
