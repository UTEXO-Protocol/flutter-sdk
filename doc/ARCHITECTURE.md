# Architecture

## System Overview

```text
Flutter app or package consumer
  |
  | Dart API
  v
rgb_sdk_flutter package
  |
  | Pigeon generated host API
  v
iOS Swift plugin / Android Kotlin plugin
  |
  | UniFFI generated language bindings
  v
RGB Lightning Node Rust library
  |
  | Bitcoin RPC, indexer, RGB proxy, Lightning peers
  v
Bitcoin + RGB + Lightning network services
```

## Modules

### `lib/src/client`

Low-level RLN client. One method per native bridge operation.

Responsibilities:

- Parameter validation light enough to catch Dart misuse.
- Type conversion to platform request models.
- Stable error wrapping.
- No wallet policy.

### `lib/src/wallet`

High-level wallet wrapper matching RN `UTEXOWallet`.

Responsibilities:

- Lifecycle sequencing.
- Signer orchestration.
- Parity aliases such as `initialize`.
- Derived operations such as RGB send from decoded invoice.
- Mapping low-level native types into higher-level wallet types.

### `lib/src/models`

Immutable Dart models for all native DTOs.

Rules:

- Model names should be Dart idiomatic but traceable to RLN/RN names.
- Preserve raw IDs and raw status strings where app-level enum mapping could
  lose information.
- Avoid `double` for amounts in Dart public models. Use `int` or `BigInt` for
  sats, msats, asset amounts, timestamps, and block heights.

### `ios/Classes`

Swift bridge. It should be a cleaned-up port of RN's `RgbSwiftHelper` and
`RlnNodeStore`, not a direct copy with React Native dependencies.

### `android/src/main/kotlin`

Kotlin bridge. It should be a cleaned-up port of RN's `RgbModule` and
`RlnNodeStore`, not a direct copy with React Native dependencies.

## Node Identity

The native node store should identify nodes by integer handles, matching RN.

Storage path behavior must match RN:

- Creating a second active node with the same storage path is an error.
- Recreating a shutdown node with the same storage path reuses the node id
  where platform behavior permits.
- Destroy removes the handle and releases native resources.

## Signer Strategy

Supported parity modes:

- Password signer.
- Native external signer.
- External signer bootstrap attach/unlock path.

Future production modes:

- Secure Enclave-backed host signer.
- Android Keystore-backed host signer.
- Hardware wallet signer.

## Amount Types

React Native uses JavaScript `number`, which is unsafe for large integers.
Dart must do better:

- Sats: `int`
- Msats: `int`
- Asset amounts: `int` or `BigInt` if upstream range requires it
- Timestamps: `int`
- Fee rate: `double` only if native returns fractional fee rate

Native bridge conversions must validate overflow before converting to
`UInt64`, `ULong`, or platform numeric types.

## Unsupported Methods

Do not hide unsupported RN methods. Keep them visible and return typed
unsupported errors.

Known examples from RN `UTEXOWallet`:

- Address rotation.
- Begin/end PSBT flows.
- VSS backup.
- Message signing/verification.
- Lightning fee estimate.
- On-chain send status.

## Eventing

Phase 1 can use polling for parity because RN primarily exposes polling calls.

Phase 2 should add optional event streams:

- node lifecycle
- sync progress
- payment status
- transfer status
- channel updates

Events must not replace parity methods.
