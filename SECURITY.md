# Security Policy

This repository is private. Report suspected vulnerabilities through the
private project-owner channel, not through public issues, discussions, or
support logs.

## Current Security Status

This revision is **not approved for production or mainnet funds**. Confirmed
release blockers include native lifecycle/threading evidence, complete secret
lifetime minimization, cryptographic assurance, native artifact provenance,
platform smoke evidence, and recovery limitations.

The authoritative findings and exit criteria are in the
[Release Readiness Tracker](doc/RELEASE_READINESS_TRACKER.md), especially the
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
