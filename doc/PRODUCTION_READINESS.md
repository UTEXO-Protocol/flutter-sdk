# Production Readiness

## Verdict

The implemented non-backup package surface is release-candidate hardened for
local package quality and React Native parity. Wallet backup/recovery remains
blocked by the pinned native RLN artifact.

This pass intentionally skips backup and restore. The non-backup production
work now has explicit policy docs for secure storage, release gates, and native
artifact supply-chain verification.

This is not a cosmetic limitation: RGB wallet recovery is a product-critical
requirement. A mainnet app should not ship custody or recoverability claims on
this package until one of these is true:

- upstream RLN exposes and verifies backup/restore in the pinned iOS and
  Android artifacts, or
- a separate reviewed recovery architecture is implemented and tested.

## Done

- Low-level RN `NativeRgb` surface exists in Dart/Pigeon: `55 / 55` for the
  current RN dev baseline.
- Native low-level implementations are usable where the artifact supports them:
  `54 / 55`; the missing usable operation is the intentionally native-blocked
  `rlnBackup`.
- `rlnBackup` is deliberately exposed but native-blocked; it does not fake
  success.
- `rlnSendRgb.skipSync=true` is deliberately rejected before native execution;
  the pinned `0.6.0-beta.2` artifact has no native field for that flag. Default
  RGB sends with `skipSync=false` remain supported.
- High-level `UtexoWallet` exists for supported Bitcoin, RGB, RGB Lightning,
  peer, channel, lifecycle, and signer workflows.
- RN core key helpers are implemented in Dart with vector tests:
  `createWallet`, `generateKeys`, `deriveKeysFromMnemonic`,
  `deriveKeysFromSeed`, `deriveKeysFromMnemonicOrSeed`, `restoreKeys`,
  `accountXpubsFromMnemonic`, `getXprivFromMnemonic`, `getXpubFromXpriv`,
  and `deriveKeysFromXpriv`.
- RN core message helpers are implemented in Dart:
  `signMessage`, `verifyMessage`, `signSchnorr`, and `verifySchnorr`.
- RN core validation/network/unit helpers and UTEXO network/bridge helpers are
  implemented for Flutter-relevant runtime use.
- RN-style advanced exports exist for `RLNBinding`, `RLNManager`,
  `createRLNManager`, and `RNSigner`.
- RN `dev` source parity is now a release gate through
  `tool/validate_rn_parity.dart`, covering `NativeRgb.ts`, `UTEXOWallet`, and
  `src/index.ts` runtime exports against the Flutter matrices and package
  barrel.
- RN PSBT helpers remain explicit unsupported stubs, matching RN after
  `bdk-rn` removal.
- App-level secure storage requirements are documented in
  `doc/SECURITY_MODEL.md`.
- Secure storage decision is explicit: the SDK does not persist secrets; the
  consuming app must provide reviewed iOS Keychain / Android Keystore-backed
  storage before beta or mainnet custody release.
- Local release gates and stop-ship conditions are documented in
  `doc/RELEASE_POLICY.md`.
- Native artifact checksums and mirror policy are documented in
  `doc/SUPPLY_CHAIN.md`, with local verification in
  `tool/verify_native_artifacts.sh`.

## Release Gate

Before a recovery-sensitive mainnet release:

- prove backup/restore on iOS and Android against the same artifact versions,
- run funded RGB and RGB-Lightning smokes on both platforms,
- run `tool/validate_rn_parity.dart` against the pinned RN checkout,
- complete app-level secure storage integration for seed/signer material,
- run a human security review of seed, signer, backup, and native bridge flows.

Current non-backup release hygiene docs:

- `doc/SECURITY_MODEL.md`
- `doc/RELEASE_POLICY.md`
- `doc/SUPPLY_CHAIN.md`
