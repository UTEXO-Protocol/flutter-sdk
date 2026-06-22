# Behavioral Contract

This package targets behavioral parity with `@utexo/rgb-sdk-rn` for Bitcoin,
RGB, RGB-Lightning, APay, and LSP wallet flows while keeping the public Dart API
idiomatic for Flutter applications.

The low-level `RlnClient` is a thin Pigeon facade over the native `rln*`
methods. It is intentionally stateless: callers pass the native node id to each
method, and the client does not own a node queue, wallet lifecycle state, or
operation mutex.

The app-facing stateful layer is `UtexoWallet`. It owns node creation,
initialization, unlock, shutdown, destroy, signer attachment, and supported
Bitcoin/RGB/Lightning workflows. Product code should use `UtexoWallet` unless
it is adding or testing bridge-level parity.

## Lifecycle And Concurrency

React Native exposes `RLNBinding` and `RLNManager` helpers that serialize node
operations with a per-node queue. Flutter exposes Dart compatibility wrappers
with the same ownership model for advanced and test callers. Product code should
still prefer `UtexoWallet`:

- `UtexoWallet.init()` creates the native node and initializes the configured
  signer.
- `UtexoWallet.unlock()` moves an initialized node online.
- `UtexoWallet.shutdown()` stops a node but keeps the wallet reusable for
  `reinit()`.
- `UtexoWallet.destroy()` releases native node and signer handles and marks the
  wallet disposed.
- `UtexoWallet.reinit()` is only valid after an initial `init()`.

`RLNBinding` and `RLNManager` own one native node id, serialize native calls, and
expose `consumeRlnUnlockConflictNormalized()` for RN-style unlock conflict
handling. `RlnClient` remains stateless and still requires an explicit node id.

Callers should serialize lifecycle-changing calls for a wallet instance:
`init`, `unlock`, `reinit`, `shutdown`, `destroy`, and `dispose`. Concurrent
read and payment operations should be coordinated by the app whenever they
depend on a lifecycle transition.

## RN-Matched Defaults

The following defaults intentionally match RN `dev`:

- `NativeExternalRlnSigner.permissivePolicy` defaults to `true`.
- `UtexoWallet.createUtxos()` defaults `upTo` to `true`.
- Channel statuses, payment statuses, payment types, invoice statuses, and
  transaction types are normalized at the Dart model boundary so Android and iOS
  bridge casing differences do not leak into app code.

## Intentional Flutter Divergences

Some differences are deliberate because they make the Flutter package safer or
more useful without hiding native limitations:

- `RlnClient.sendRgb(skipSync: true)` and wallet RGB send wrappers fail fast
  before native execution. The pinned RLN `0.6.0-beta.2` native request type has
  no `skipSync` field, so silently accepting the flag would be misleading.
- `UtexoWallet.getXpub()` returns constructor-provided xpubs or node-info xpubs
  when available. RN currently throws for this helper, but Flutter apps can use
  the available data safely.
- `RlnClient.getPayment()` searches the payment by hash through the native
  bridge surface exposed by the platform. This may be broader than a single RN
  Android lookup path, but it preserves the RN-facing API shape.
- LSP wait helpers throw explicit timeout exceptions such as
  `LspChannelTimeoutException` and `LspLiquidityTimeoutException` instead of
  returning ambiguous null/partial states.

These divergences are covered by tests and documented here so they are product
decisions, not accidental drift.
