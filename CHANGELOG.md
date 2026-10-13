# Changelog

## 0.1.0 - Unreleased

Initial internal-beta Flutter package release.

- Added the stable `rgb_sdk_flutter.dart` entrypoint with the `UtexoWallet`
  facade, typed wallet configuration, signer strategies, domain DTOs, errors,
  validation helpers, and crypto utilities.
- Added the advanced `rgb_sdk_flutter_advanced.dart` entrypoint for explicit
  RN/native parity access to `RlnClient`, `RLNBinding`, `RLNManager`, raw
  `Rln*` models, bridge diagnostics, and migration tooling.
- Targeted `@utexo/rgb-sdk-rn` `1.0.0-beta.37`,
  `@utexo/rgb-sdk-core` `1.0.0-beta.9`, and RGB Lightning Node
  `0.16.0-beta.3`, including onchain-only mainnet native startup.
- Added bridged fungible assets (BFA), signer-aware burn capabilities, exact-u64
  burn requests, saved consignment bytes/path, and password/external-signer
  unlock `ethRpcUrl` through RLN's request-based native API.
- Added durable `BurnOperations` with pending-outcome blocking and explicit
  independent-proof reconciliation; a storage failure never retries a burn.
- Added pre-broadcast funding-failure cancellation and an optional sanitized
  journal error field; unknown outcomes remain pending, never auto-retried.
- Added optional WebRGB receiving/read/burn integration with immutable typed
  requests, per-session revocation, sanitized errors, chain policy, and bounded
  Keccak-256 proof export. Hosts own transport, durable storage and user approval.
- Added WebRGB 0.1.2 witness receiving and exact approved Unicode message
  signing through the native wallet, plus an optional bounded WalletConnect
  session RPC router. Full WalletKit pairing and live relay qualification are
  not implemented or claimed by this router.
- Blocked canonical Lightning methods on mainnet with the upstream error code.
  Native `LightningUnsupportedOnMainnet` remains a typed unsupported failure.
- Implemented iOS and Android Pigeon bridges backed by the pinned native RGB
  Lightning Node artifacts.
- Added wallet workflows for Bitcoin, RGB assets, Lightning payments, peers,
  channels, LSP/APay, on-chain transfers, node lifecycle, and signer-backed
  message signing.
- Added typed detailed-transfer refresh results, merged RLN 0.13 history
  filters, `WaitingBroadcast`, UTXO existence, decoded-invoice descriptions,
  proxy recipient IDs, linked IFA metadata, and deterministic LDK chain-sync
  adaptation on both native platforms.
- Added core beta.9 linked/canonical receive, Lightning Address discovery and
  asset selection, external invoice, and cross-asset relay flows. Relay quotes
  and both RGB/Lightning bridge legs are decoded and checked locally before any
  payment call. APay external
  invoices verify the BOLT11, Lightning Address ownership signature, Merkle
  inclusion, and signed batch commitment. Foreign LNURL hosts never receive
  configured LSP bearer credentials, and the default transport pins approved
  DNS answers through TLS connection establishment.
- Added one canonical LSP network policy for configured aliases and signed
  invoice networks, plus fail-closed APay v1 host/version/status/index/batch
  decoding and mutation preflight for bridge amounts, hashes, and CLTV bounds.
- Added strict model decoding, stable error taxonomy, lifecycle serialization,
  native timeout policy, local storage permission checks, support-safe
  diagnostic redaction, and secret-lifetime minimization guardrails.
- Added local release gates for formatter/analyzer/test/doc/API validation,
  RN parity validation, native artifact checks, supply-chain inventory,
  clean-consumer install/archive checks, Android bridge tests, iOS XCTest,
  funded/unfunded platform smokes, and external-signer process restart proof.
- Documented accepted constraints for native backup/recovery, RGB skip-sync,
  experimental pure-Dart Schnorr signing, app-owned durable credential storage,
  local-only native/regtest gates, Git/path distribution, and upstream
  native artifact provenance.
