# Release Evidence Schema

Release evidence must be attributable, sanitized, and tied to the exact source
candidate. A passing script name is never enough.

## Current Enforcement

The September corrective implementation emits schema version 2 only after
finalization. Draft reports are always `releaseEligible: false`. Finalization
compares the starting and ending commit, tracked source content, baseline,
artifact-provenance manifest, dependency lock, and clean-worktree status. It
hashes logs after their writers have exited, records Flutter/Dart/host and
available native build-tool identities, and labels repository paths.

The default mainnet-onchain production runner requires five current-run child
reports: consumer matrix, Android JVM, iOS XCTest and onchain qualification for
both explicit devices. The explicit historical internal-beta profile requires
nine: consumer matrix, Android JVM, iOS XCTest, and funded, unfunded and
external-signer restart reports for both explicit devices. Each child must match the parent candidate and its
completed log checksum. Platform reports additionally require the exact device
OS identity and their profile-specific stack/container image IDs. A checked children
manifest is attached to the final combined report.

This is not a claim that qualification has run. TEST-040/TEST-041 stay open until
an exact clean combined run exercises these contracts end to end. The expanded
native/compiler inventory, attachment provenance and sanitization requirements
below must also be verified before those rows close; hashes are not signatures.

## Evidence Identifier

Every release evidence file must have a stable identifier:

```text
rgb-sdk-flutter/<gate>/<utc-run-id>/<full-git-commit>/<platform-or-host>
```

Rules:

- `utc-run-id` uses `YYYYMMDDTHHMMSSZ`.
- `full-git-commit` is the 40-character commit hash.
- dirty worktree evidence may be used only for development triage and must be
  labelled `releaseEligible: false`.
- release-eligible reports must be unique per run and must not overwrite prior
  reports.

## Required Report Fields

Every release report JSON must include:

| Field | Requirement |
| --- | --- |
| `schemaVersion` | Integer schema version. |
| `evidenceId` | Identifier using the format above. |
| `releaseEligible` | `true` only for a clean candidate with no skipped required gates. |
| `repository` | Repository URL and full commit hash. |
| `workingTree` | Clean/dirty state plus sanitized changed-file summary. |
| `baseline` | RN commit/version, core version, RLN version, artifact checksums, ABIs/slices. |
| `toolchain` | Flutter, Dart, Xcode, CocoaPods, Gradle, Kotlin, Android SDK, Java. |
| `host` | OS, architecture, and sanitized host label. |
| `devices` | Simulator/emulator/device IDs, names, OS versions, and architecture. |
| `regtestStack` | Docker image IDs/tags, container names, service ports, and chain height when applicable. |
| `steps` | Ordered gate names, exact commands or script IDs, start/end timestamps, durations, and exit codes. |
| `artifacts` | Checksummed native artifacts and generated report attachments. |
| `sanitization` | Redaction policy version and proof that absolute local paths/secrets are not present. |

## Sanitization Rules

Reports must not contain:

- personal home-directory paths;
- access tokens, API keys, passwords, mnemonics, private keys, seed hex, or
  bearer credentials;
- full app data directories unless replaced with a run-local label;
- real mainnet addresses or identifiers from production users.

Allowed path format:

```text
<repo>/build/test-reports/<run-id>/...
<tmp>/<run-id>/...
```

Local-only debugging reports may contain richer paths, but they must be
labelled `releaseEligible: false` and must not be cited as release evidence.

## Matrix Evidence Catalog

`tool/test_matrix/evidence_catalog.json` is the catalog that maps each matrix
`evidenceBucket` to executable test IDs, script IDs, platform report families,
and the assertion level it proves. The matrix validator fails when a bucket is
missing from the catalog.

Claim levels:

| Level | Meaning |
| --- | --- |
| `unit_contract` | Dart-only contract, validation, mapping, or utility evidence. |
| `native_bridge` | iOS XCTest or Android JVM bridge evidence without funded flows. |
| `platform_smoke` | Flutter integration evidence on simulator/emulator. |
| `funded_regtest` | Controlled regtest evidence involving funds or channels. |
| `release_blocked` | Expected failure or native-blocked behavior. |

Evidence buckets do not automatically imply production readiness. The tracker
row decides whether the linked evidence is sufficient for a release claim.

## API and ABI Snapshots

`tool/api_snapshot.json` stores the current normalized snapshot of:

- exported Dart package surface;
- Pigeon schema;
- generated Dart Pigeon surface;
- generated Swift and Kotlin Pigeon surfaces;
- native bridge/store source markers.

`dart run tool/validate_api_snapshot.dart` fails when the current normalized
surface differs from the snapshot. Intentional changes must update the snapshot
and cite the tracker row and migration note in the same change.

## Documentation Completeness Criteria

`dart doc` passing only proves syntax and link health. Public docs are complete
only when stable or advanced public symbols document:

- lifecycle prerequisites;
- network/platform support;
- units for timestamps, sats, msats, fee rates, and asset amounts;
- sync behavior and side effects;
- thrown SDK error categories;
- native-blocked or unsupported behavior;
- secret-handling responsibilities;
- an executable or manually verified snippet when a symbol is part of the
  stable app facade.

Documentation review is release evidence only when the reviewer records the
API snapshot hash, tracker IDs reviewed, and exact docs command output.

## Mainnet onchain production profile

`RELEASE_PROFILE=mainnet-onchain` is the default. It invokes the supply-chain
validator with `--production` and consumes `platform-onchain-regtest` evidence;
it does not execute the legacy SDK-owned stack or Lightning financial runners.
`RUN_PLATFORM` cannot opt this profile into those scripts. `internal-beta` is
explicitly separate, with no production-readiness claim.

The production aggregate requires exactly five validated reports for the same
clean candidate/run ID and completed log hashes: `clean-consumer-matrix`,
`native-android-jvm`, `native-ios-xctest/<ios-device>` and
`platform-onchain-regtest/<ios-device|android-device>`. The two platform reports
must identify iOS and Android, match the explicit device IDs and include:

| Field | Required value |
| --- | --- |
| `releaseProfile` | `mainnet-onchain` |
| `releaseNetwork` / `testNetwork` | `mainnet` / `regtest` |
| `walletSigner` | `password` |
| `stackIdentity.project` / `.host` | `wdk-rln-017-qualification` / `localhost` |
| `stackIdentity.ports` | `rlnApi:29301`, `esplora:29302`, `rgbProxy:29300` |
| `stackIdentity.containerLifecycle` | `preserved` |
| `stackIdentity.services` | Existing `rln`, `esplora`, `rgb-proxy` role entries, 64-character container IDs and immutable `sha256:` image IDs |
| `bfaChainIdentity` | Existing project `wdk-rln-017-bfa-anvil-20261014`, RPC `http://localhost:29545`, chain `31337`, existing `containerId`/`imageId`, `containerLifecycle:preserved`, `contractsPreserved:true` |
| `cases` | Each required ID below exactly once, `status:passed` and non-empty `assertions` describing actual observed outcomes |

A separately operated qualification controller must collect these cases with
independent wallet storage on the **already running** isolated stack. Reorgs,
interruption and adversarial BFA cases belong there; never reset containers or
chain data. Reuse of a development-stack happy-path report or a changed
candidate is rejected. The SDK aggregate does not generate case claims on
behalf of that controller.

Required case IDs (enforced by `tool/release_profiles.dart`):

- `wallet-create-unlock`
- `btc-send-receive`
- `bfa-mint-backing`
- `bfa-burn-payout`
- `rgb-blind-send-receive`
- `rgb-witness-bound-send-receive`
- `rgb-witness-unbound-send-receive`
- `onchain-history-accounting`
- `password-interrupted-send-reconciliation`
- `rgb-reorg-reconfirm`
- `bfa-wrong-lock-valid-lock`
- `fresh-device-vss-restore`
- `mainnet-lightning-rejected`
- `mainnet-external-signer-rejected`

The mainnet rejection cases must observe zero native side effects. Financial
cases run only on regtest. Fresh-device VSS restore means a new app storage and
credential boundary that does not retain the original wallet files or
Keychain/Keystore values, followed by exact BTC/RGB reconciliation. Assertions
must cover allocation state and spendable/future/settled balances through
confirmation/restart, never merely a passing test name. Local reports remain
checksummed test evidence, not cryptographic artifact attestations.
