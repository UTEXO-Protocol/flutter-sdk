# Security Policy

The public source mirror is `UTEXO-Protocol/flutter-sdk`. Report suspected
vulnerabilities through a project-owner security channel, not through public
issues, discussions, or support logs.

## Current Security Status

This revision is **not approved for production or mainnet funds**. The current
SDK source, API, model, lifecycle, packaging, local native, and platform-smoke
evidence is current for the internal-beta line, but production approval is
still bounded by accepted constraints.

The most important constraint is `PKG-006`: pinned native artifacts are
checksum/ABI/slice verified and inventoried, but the upstream release does not
yet provide the full signature, trusted-key verification, and
reproducible-build/source attestation evidence required for production
supply-chain mode.

The authoritative findings and exit criteria are in the
[Release Readiness Tracker](RELEASE_READINESS_TRACKER.md), especially the
`SEC`, `LSP`, `LIFE`, `PKG`, and `TEST` issue groups.

## Secret Handling

Never include any of the following in issues, logs, screenshots, traces, crash
reports, test reports, fixtures, or support bundles:

- Mnemonics, seed bytes, seed hex, xprivs, or private keys.
- Wallet, backup, VSS, or bitcoind RPC passwords.
- Bearer tokens, authentication headers, or proxy credentials.
- Production wallet paths, backup files, channel-state files, or database
  contents.
- Full invoices, payment preimages, or native error bodies when they may
  contain private wallet or service data.

Durable credential storage is the consuming application's responsibility. The
SDK must not persist credentials implicitly and remains responsible for
minimizing in-memory copies, bounding secret lifetime, and producing redacted
diagnostics.

Current LSP diagnostics redact common credential fields, bearer tokens, long
hex secrets, and oversized response bodies before they are exposed through
support-safe exceptions. Treat this as defense in depth, not permission to log
secrets.

## Transport

LSP and LNURL HTTP must use HTTPS except for explicit local loopback development
hosts. Non-loopback plain HTTP is rejected before the request is sent.

## Recovery Warning

Native local backup/recovery is blocked in the current artifacts. Do not treat
VSS configuration, a declared backup method, or a successful unit test as
proof of recoverability. Recovery requires an independently tested upstream
implementation before this package can be approved for funds-bearing use.

## Initial mainnet signer boundary

The mainnet onchain release supports only the SDK's built-in
`PasswordRlnSigner`. `UtexoWallet.init` and `reinit` reject external/custom
signers (including overriding password-signer subclasses) before native node or
signer allocation, irrespective of VSS configuration. The Swift/Kotlin plugin also records each created node's network and rejects
external bootstrap/init/attach/unlock plus external signer creation on mainnet
and unknown network aliases, before native signer or wallet operations. This
protects the advanced raw Dart bridge too. Advanced/node-host interfaces remain
research/integration primitives outside the supported production wallet facade.

External mode's orphan BTC reservations, persistent native teardown and
public-bootstrap-material-derived VSS keys remain upstream qualification and
security blockers. Regtest support is retained solely so they can be fixed and
verified. Password mode uses the native mnemonic-derived backup identity; this
scope boundary is not proof of fresh-device recovery. Missing portable/local
backup and VSS restore evidence remain release blockers.
