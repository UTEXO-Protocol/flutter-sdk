# RGB SDK Flutter Release Readiness Tracker

This is the sole authoritative release-readiness tracker for
`rgb-sdk-flutter`.
Historical phase plans, parity claims, risk registers, and readiness documents
were removed because they overlapped and had drifted from the implementation.

## Document Control

| Field | Value |
| --- | --- |
| Audit date | 2026-07-28 |
| P0 remediation started | 2026-07-28 |
| Release verdict | **NO-GO** |
| Flutter baseline commit | `b310f15e0b902f715dcac23393efb6b7661ae2d0` |
| Candidate state | Baseline commit plus uncommitted P0 remediation; current evidence is not release-commit evidence |
| React Native reference | `UTEXO-Protocol/rgb-sdk-rn` `dev` at `cb4fe938b171ac3771093e46b494f5eca190e804` |
| React Native package | `@utexo/rgb-sdk-rn` `1.0.0-beta.25` |
| Canonical core contract | `@utexo/rgb-sdk-core` `1.0.0-beta.5` |
| Flutter code currently targets | RN `1.0.0-beta.25`; core `1.0.0-beta.5`; RLN `0.9.0-beta.3` |
| Current RN native artifacts | RLN `0.9.0-beta.3` |
| Audit confidence | P0 source, generated-code, native-artifact, native-test, and process-restart claims are locally verified; remaining gates retain their explicit status |

## Verdict

All four P0 findings are implemented and locally verified in the current
worktree. The package now targets the exact RN beta.25/core beta.5/RLN beta.3
baseline, uses a generated artifact manifest, persists external-signer VLS
state in a validated owner-only directory, and passes a funded one-install,
two-process channel recovery/payment proof on iOS and Android.

The package is still not a release candidate and must not be used for
production or mainnet funds. There are 127 open P1/P2 findings, the current
worktree is uncommitted, the live RN validator still identifies two missing
high-level Lightning status APIs, and the complete API/model/lifecycle,
threading, packaging, security, and exact-commit release matrices have not
passed. P0 completion removes the known catastrophic blockers; it does not
convert the broader release verdict to GO.

Passing analysis, unit tests, native bridge tests, and the targeted restart
proof support only the claims they exercise. Name-based matrix validation is
not behavioral parity evidence, and June platform reports are not evidence for
the current worktree.

## Tracker Rules

### Priority

| Priority | Meaning |
| --- | --- |
| P0 | Funds, durable wallet state, secret exposure, or catastrophic release risk |
| P1 | Release-blocking correctness, API, native, platform, or packaging defect |
| P2 | Required production hardening or material maintainability problem |
| P3 | Quality improvement that can follow the first production release |

### Status

| Status | Meaning |
| --- | --- |
| Open | Confirmed and not fixed |
| In progress | An owner is actively implementing it |
| Blocked upstream | Cannot be completed without a native/upstream change |
| Accepted constraint | Deliberate boundary approved for this release line |
| Needs decision | Product or architecture decision is required |
| Verified | Fixed and independently rechecked against its exit criteria |

An issue moves to `Verified` only after its implementation, tests, platform
evidence, and documentation are complete. A passing name-based parity script is
not sufficient evidence.

## Audit Evidence

| Check | Result | Interpretation |
| --- | --- | --- |
| Direct toolchain | Flutter `3.41.9`, Dart `3.11.5` | Commands below used the asserted direct executables, not the broken local FVM wrapper |
| `flutter analyze --no-fatal-warnings --no-fatal-infos` | Pass | Current analyzer configuration reports no issues |
| `flutter test` | Pass, 123 tests | Dart unit/contract tests pass; most still do not execute native RLN behavior |
| `flutter test` in `example/` | Pass, 1 test | Example widget smoke passes |
| `flutter test --coverage` | Not rerun after P0; last pre-P0 result was 57.4% (`1816/3164`) | No threshold; native code is outside this metric |
| `dart format --output=none --set-exit-if-changed .` | Pass, 41 files, 0 changed | Current Dart files are formatter-canonical |
| `dart doc` | Pass, 0 warnings and 0 errors | Syntax/link health only; public documentation remains incomplete |
| `dart run tool/generate_release_baseline.dart --check` | Pass | Generated Dart/Swift/Kotlin constants are current; Gradle, podspec, and shell tooling read the same manifest directly |
| Pigeon regenerate/checksum comparison | Pass | Regenerating the Dart/Swift/Kotlin bridge changes no generated file |
| `dart run tool/validate_test_matrix.dart` | Pass: 62 `RlnClient`, 109 `UtexoWallet`, 35 core exports | Validator proves local declaration coverage, not behavior |
| `RGB_SDK_RN_PATH=<exact-dev> dart run tool/validate_rn_parity.dart` | Fail only for `getLightningReceiveStatus` and `getLightningSendStatus` | Exact RN commit/package/native method checks pass; public-wallet parity remains incomplete under API-005 |
| `dart pub publish --dry-run` | Exit 65, two warnings | Current dirty state and tracked-but-worktree-deleted, gitignored historical docs prevent clean package validation; no `.pubignore` defines intentional contents |
| `./tool/verify_native_artifacts.sh` | Pass | Installed iOS files and exact Android AAR checksum/ABI set match the generated baseline |
| CocoaPods lint | Not rerun after P0; last run passed with material warnings | Metadata warnings and iOS deployment-target mismatch remain open |
| iOS XCTest bridge suite | Pass, 9 cases | Current source graph, exact storage policy, and UUID destination path passed on simulator `8B3E2FF7-3A8C-4834-94E9-CC6AD707F2E5` |
| Android JVM bridge suite | Pass, 12 cases | Current plugin/storage-policy cases passed |
| iOS external-signer process restart | Pass | Run `20260727T204201Z-81121`; one installed binary, PIDs `81897` then `81978`, stable node/channel, bidirectional pre/post-restart payments |
| Android external-signer process restart | Pass | Run `20260727T204304Z-82076`; one installed APK on ARM64 Android 17/API 37, same data directory, stable node/channel, bidirectional pre/post-restart payments |
| Current general funded/unfunded platform smokes | Not rerun after P0 | Existing four reports are from 2026-06-23 and do not prove the current worktree |
| Combined release-candidate script | Not rerun as release evidence | The current worktree is uncommitted; its known public parity gate fails API-005, and the prior `b310f15` report predates P0 remediation |

The repository has no `.fvmrc`. In this environment, `fvm flutter ...` and
`fvm dart ...` returned success without running Flutter or Dart. Historical
evidence based only on those commands is invalid until a pinned FVM toolchain
is added and the executable path is asserted.

## Audit Scope and Method

This review used three independent contracts rather than trusting the existing
parity manifest: current RN `NativeRgb.ts` and both native implementations,
current RN `UTEXOWallet`, and the exact core package declaration/runtime
published with RN. Those were compared against every Flutter public library,
Pigeon source and generated bridge, Swift/Kotlin implementation, wire/domain
model, lifecycle and LSP path, test/tool, package manifest, artifact script,
workflow, example, and public document.

Static comparison proves the source-level findings in this tracker. Current
native storage behavior and the external-signer recovery invariant also have
targeted iOS/Android execution evidence. This does not prove complete native
runtime correctness: the general funded/unfunded workflows, full bridge
families, failure/concurrency matrix, clean consumer archives, supported
toolchain matrix, and exact immutable release commit remain failed gates.

## Issue Rollup

| Measure | Count |
| --- | ---: |
| Total tracked findings | 149 |
| P0 | 4 |
| P1 | 97 |
| P2 | 48 |
| Open | 127 |
| In progress | 0 |
| Needs decision | 2 |
| Accepted constraint | 3 |
| Verified | 17 |

This rollup is a snapshot of the master ledger below. Update it in the same
change whenever an issue is added or its priority/status changes.

## P0 Execution Log

| Date | Scope | State | Evidence |
| --- | --- | --- | --- |
| 2026-07-28 | Baseline refresh | Verified | Refetched RN `origin/dev`; it remains `cb4fe938b171ac3771093e46b494f5eca190e804`, package `1.0.0-beta.25`, core `1.0.0-beta.5`, RLN `0.9.0-beta.3`. One manifest now feeds generated constants and direct build/script readers; exact commit/source, checksums, installed iOS files/slices, and Android AAR/ABIs verify. |
| 2026-07-28 | Durable external signer | Verified | Both plugins use RLN `newWithStorage(storageDirPath)` before attachment, Dart owns signer handles transactionally, native storage is owner-only, and funded process-restart/channel-payment proofs pass on iOS and Android. |
| 2026-07-28 | Restart proof | Verified | One run-scoped binary/APK is installed once per platform, settles both directions, orderly-shuts down RLN, crosses an OS-enforced process boundary, relaunches without reinstalling, proves unchanged storage plus stable node/channel identities, and settles both directions again. This is not an abrupt-crash/power-loss proof; TEST-007 retains that work. |
| 2026-07-28 | Native storage policy | Verified | New roots are created with exact mode `0700`; symlink, non-directory, foreign-owner, broad, and owner-only-but-unusable paths fail closed without permission mutation. Current native suites pass 9 iOS and 12 Android cases, and both funded process-restart smokes pass. |
| 2026-07-28 | iOS native test source graph | Verified | `test_native_ios.sh` now runs `pod install` before `xcodebuild`; the subsequent run compiled `RlnStorageDirectoryPolicy.swift` from the current source graph and all nine XCTest cases passed. |
| 2026-07-28 | Regtest readiness | Verified | Startup mines a current tip when Bitcoin Core reports IBD, waits for IBD to clear, and requires a valid Electrum `server.version` JSON response. The gate passed before both final platform restart runs. |
| 2026-07-28 | Restart fixture contract | Verified | Funded execution proved RLN beta.3 rejects RGB UTXO creation as well as asset issuance in external-signer mode. The executable proof now matches upstream's supported safety regression: a funded external-signer device opens a `trusted_no_broadcast` BTC channel to an allowlisted password-backed host, both directions settle before a process boundary, then identities, the exact channel, and both payment directions recover in a new Flutter process. |
| 2026-07-28 | Restart oracle refinement | Verified | The oracle requires `trusted_no_broadcast` on the external-signer opener and binds the acceptor by peer identity, channel ID, capacity, and funding transaction, matching RLN beta.3's opener-only mode annotation. Both platform runs satisfied it. |
| 2026-07-28 | iOS funded process restart | Verified | Run `20260727T204201Z-81121` built and installed one dedicated iOS simulator binary with a run-unique seed, serviced its fresh funding request, prepared a trusted virtual channel, settled both payment directions, force-terminated PID `81897`, relaunched the same installed binary and unchanged data container as PID `81978`, recovered the same identities/channel ID, and settled both directions again. Evidence: `build/test-reports/platform/external-signer-restart-8B3E2FF7-3A8C-4834-94E9-CC6AD707F2E5-b310f15e0b90.json` (`workingTreeDirty: true`). |
| 2026-07-28 | Android funded process restart | Verified | Run `20260727T204304Z-82076` built and installed one APK with a run-unique seed on ARM64 Android 17/API 37, serviced its fresh funding request, prepared a trusted virtual channel, settled both payment directions, force-stopped the package, relaunched it with the same app data directory, recovered the same identities/channel ID, and settled both directions again. Evidence: `build/test-reports/platform/external-signer-restart-emulator-5554-b310f15e0b90.json` (`workingTreeDirty: true`). |

## Release Gates

| Gate | Status | Exit condition |
| --- | --- | --- |
| G-01 Baseline and artifact pin | Passed locally | One authoritative manifest pins RN/core/RLN versions, immutable sources, checksums, ABI/slices, installed files, and platform requirements |
| G-02 Low-level bridge parity | Passed structurally | Every current RN `NativeRgb` method and parameter exists on Dart, iOS, and Android; Pigeon regeneration is idempotent |
| G-03 Public wallet contract | Failed | Canonical methods, capabilities, defaults, errors, and return models match the approved core/RN contract |
| G-04 Durable lifecycle | Failed | Init/unlock/restart/shutdown/dispose are idempotent, retryable, race-safe, and restart-tested |
| G-05 Threading and responsiveness | Failed | Blocking RLN work never runs on a platform/UI message thread |
| G-06 Model integrity | Failed | Typed wire DTOs reject malformed required fields and preserve optionality, units, enums, and all fields |
| G-07 Security | Failed | Signer persistence, secret lifetime, transport policy, crypto boundary, and error redaction are reviewed |
| G-08 Packaging and supply chain | Failed | Clean consumer installs are deterministic and verified on supported platform/toolchain matrices |
| G-09 Test evidence | Failed | Contract, native, restart, failure, funded/unfunded, and cross-platform tests pass on the exact release commit |
| G-10 Documentation | Failed | Public APIs, lifecycle, security boundary, support matrix, migration, and limitations are accurate |
| G-11 Recovery | Accepted constraint | Local backup remains explicitly native-blocked; no recovery-ready/mainnet claim is allowed |
| G-12 CI scope | Accepted constraint | Native builds and regtest smokes remain local-only, with mandatory signed/local release evidence |

## Exact Native API Delta

### Low-Level Bridge Remediation

The seven beta.25 methods (`rlnRotateAddress`, `rlnSignMessage`,
`rlnVerifyMessage`, `rlnInflate`, `rlnListTransactionsByTxid`,
`rlnListTransfersByTxid`, and `rlnVssBackup`) now exist through Pigeon, Dart,
Swift, and Kotlin. The four changed signatures now carry `reuseAddresses`,
durable signer `storageDirPath`, Lightning `descriptionHash`, and RGB
`assignmentKind`. Generated bridge regeneration is byte-stable.

This closes structural low-level parity, not behavioral release evidence.
TEST-005 and TEST-008 retain the missing cross-platform method-family and
malformed-response coverage.

### Missing or Wrong High-Level Behavior

| Canonical API | Current behavior in RN | Flutter behavior |
| --- | --- | --- |
| `getLightningReceiveStatus(id)` | Returns canonical Lightning invoice status | Missing; old helper converts it into RGB transfer status |
| `getLightningSendStatus(id)` | Returns canonical payment status or `null` | Missing; old helper converts it into RGB transfer status |
| RGB send with `skipSync: true` | RN beta.25 accepts it but both native plugins discard it; RLN beta.3 has no request field | Rejected before native execution, which is the honest behavior |
| `createLightningInvoice` | No arbitrary `paymentHash`; supports `descriptionHash` | Retains stale `paymentHash`; lacks `descriptionHash` |
| `createHodlInvoice` | Supports `descriptionHash`; returns full `LightningInvoice` | Lacks field and returns reduced custom DTO |
| `openChannel` | `withAnchors` defaults to `true` | Defaults to `false` |
| `onchainSend` amount | Current RN requires caller-provided amount | Flutter silently falls back to decoded invoice assignment |

### Wrong Canonical Return Shapes

Flutter often returns `Rln*` wire objects from the canonical method name and
adds a separate `*Core` method. Current RN does the opposite: canonical names
return core domain models; raw wire methods live below the wallet facade.

| Canonical method | Required shape | Flutter shape/problem |
| --- | --- | --- |
| `getBtcBalance` | `BtcBalance` | Raw `RlnBtcBalance` |
| `listUnspents` | `Unspent[]`, including `pendingBlinded` | Raw list; field absent |
| `listAssets` / `getAssetBalance` | Core asset models | Raw models; additive `*Core` variants are incomplete |
| `blindReceive` / `witnessReceive` | Full `InvoiceReceiveData` | Raw invoice DTO; recipient optionality is lost |
| `listTransactions` / `listTransfers` | Canonical transaction/transfer models | Raw models and lossy `toCore()` mappings |
| `estimateFeeRate` | `{ feeRate }` | Bare `double` |
| `listPayments` | `LightningPayment[]` | Raw `RlnPayment[]` |
| `invoiceStatus` | Canonical status value | Wrapper object containing uppercased raw string |
| `getNodeInfo` | `LightningNodeInfo` | Raw, stale `RlnNodeInfo` |
| `getNetworkInfo` | `LightningNetworkInfo` with `blockHeight` | Raw model with `height` |
| `listPeers` / `listChannels` | Canonical domain models and units | Raw models, wrong optionality, `public` naming, sat/msat mismatch |
| `keysend` / `decodeLnInvoice` | Canonical payment/invoice models | Raw wire-oriented models |
| `onchainReceive` | Invoice, recipient ID, expiry, batch index | Invoice only |

### Public Methods That Must Not Be Runtime Stubs

Current core exposes unsupported platform groups through optional capability
carriers. Flutter publicly declares methods and throws at runtime instead.

`rotateColoredAddress`, `inflateBegin`, `inflateEnd`, `estimateFee(psbt)`,
`payLightningInvoiceBegin`, `payLightningInvoiceEnd`,
`getLightningSendFeeEstimate`, `onchainSendBegin`, `onchainSendEnd`,
`getOnchainSendStatus`, `goOnline`, `createUtxosBegin`, `createUtxosEnd`,
`sendBegin`, `sendEnd`, `sendBtcBegin`, `sendBtcEnd`, `signPsbt`,
`configureVssBackup`, `disableVssAutoBackup`, `vssBackup`, and `vssBackupInfo`
must be removed from the always-present facade or moved behind typed optional
capabilities. `Object` parameters are not an acceptable placeholder contract.

`createBackup` is different: the current RN facade still exposes it while both
native paths throw, contradicting the current core contract. The approved
project decision is to keep recovery explicitly native-blocked and make no
recovery-ready claim until upstream supplies a real implementation.

## Master Issue Ledger

### Baseline and Parity

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| BASE-001 | P0 | Verified | Flutter now pins RN `1.0.0-beta.25`, core `1.0.0-beta.5`, and RLN `0.9.0-beta.3` from `tool/release_baseline.json`; generated Dart/Swift/Kotlin/shell/build consumers are current and exact native artifacts verify. | Keep baseline generation/drift checks and exact artifact verification mandatory whenever upstream changes. |
| BASE-002 | P1 | Open | `pubspec`, podspec, and Android module versions are `0.1.0`, `0.0.1`, and `1.0-SNAPSHOT`. | Adopt one package version policy and verify all platform metadata from it. |
| BASE-003 | P1 | Open | No `.fvmrc`; CI follows floating Flutter `stable`; local FVM commands can no-op. | Pin Flutter/Dart, assert versions at every gate, and test the oldest supported toolchain. |
| BASE-004 | P1 | Verified | Baseline metadata moved out of the alias-only parity manifest into `tool/release_baseline.json`, which pins exact RN/core/RLN source and artifact identities without a personal checkout path. | Keep the exact-commit validator and generated baseline as the only current-version authority. |
| BASE-005 | P1 | Open | Current parity gate is absent from CI and fails against current RN dev. | Run a deterministic current-baseline contract gate wherever credentials permit; require it locally otherwise. |
| BASE-006 | P2 | Open | RN, core, and native artifacts can contradict each other; current `createBackup` is one confirmed example. | Define precedence and record every approved divergence with an owner and test. |
| BASE-007 | P1 | Verified | The baseline generator emitted Dart that `dart format` changed, so CI's format step made the subsequent generated-drift check fail even when both started from generated output. | Generated Dart is now formatter-canonical; generate, `dart format --set-exit-if-changed`, and `--check` pass consecutively in CI order. |

### Public and Native API

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| API-001 | P1 | Open | All seven beta.25 low-level methods now exist through Dart/Pigeon/Swift/Kotlin, but not every method has independent iOS and Android behavioral coverage. | Add platform-equivalent success, failure, and malformed-response tests for the seven methods before treating implementation presence as behavior parity. |
| API-002 | P1 | Open | `reuseAddresses`, signer storage, `descriptionHash`, and `assignmentKind` now traverse the generated bridge, but native request-field behavior is not fully covered on both platforms. | Add cross-platform request assertions and integration vectors for every changed field/default. |
| API-003 | P1 | Open | Rotate, inflate, node-key sign, and node-key verify are implemented, but canonical return/error behavior lacks complete native and facade vectors. | Prove current native behavior and approved domain results on both platforms. |
| API-004 | P1 | Open | Txid-filtered transaction and transfer APIs now exist at low and high levels; only local delegation/shape coverage exists. | Add native cross-platform semantics, empty-result, malformed-result, and `skipSync` vectors. |
| API-005 | P1 | Open | `backupNow` now delegates to native VSS backup; the live RN validator still finds `getLightningReceiveStatus` and `getLightningSendStatus` missing from the public wallet contract. | Add canonical Lightning status APIs without retaining semantically wrong RGB-status aliases as the primary API. |
| API-006 | P1 | Accepted constraint | RLN `0.9.0-beta.3` still has no RGB `skipSync` request field; RN beta.25 accepts and silently discards the value. | Keep Flutter fail-fast and its tests until upstream adds real support; never claim parity by ignoring the option. |
| API-007 | P1 | Open | Canonical wallet names return raw models while incomplete `*Core` aliases carry intended domain shapes. | Make canonical APIs return canonical domain types; isolate raw bridge APIs. |
| API-008 | P1 | Open | `onchainReceive` discards recipient ID, expiry, and batch transfer index. | Preserve the full native response. |
| API-009 | P1 | Open | `estimateFeeRate` returns a scalar instead of the shared response object. | Match the approved domain contract. |
| API-010 | P1 | Open | Lightning payment, node, network, channel, peer, keysend, and decode methods return wire shapes. | Add explicit wire-to-domain mappers equivalent to current RN mappings. |
| API-011 | P1 | Open | Current Lightning receive/send helpers return RGB transfer statuses. | Expose Lightning status vocabularies without cross-domain conversion. |
| API-012 | P1 | Open | `createLightningInvoice` retains removed `paymentHash` and lacks `descriptionHash`; HODL output is incomplete. | Match current narrowed invoice/HODL contracts and add LNURL metadata tests. |
| API-013 | P1 | Open | `openChannel` defaults `withAnchors` to false; current RN defaults true. | Align the default and add a native request assertion. |
| API-014 | P2 | Open | `onchainSend` amount fallback differs from current RN and is undocumented. | Choose one contract, validate explicitly, and add cross-SDK vectors. |
| API-015 | P1 | Open | Unsupported methods are always-present runtime throws with `Object` inputs. | Remove them or expose typed optional capability carriers. |
| API-016 | P2 | Open | `getXpub`, generic `send`, old status aliases, and several bridge helpers are stale RN-era surface. | Remove/deprecate after a migration inventory; do not advertise as parity. |
| API-017 | P2 | Needs decision | High-level CFA/UDA issuance is a Flutter extension absent from current RN wallet. | Classify as supported Flutter extension, move to advanced API, or remove. |
| API-018 | P2 | Open | Package-level sign/verify uses derived BIP86 account keys while wallet sign/verify uses the node key upstream; names invite substitution. | Separate names/contracts and document key identity unambiguously. |
| API-019 | P1 | Open | `createBackup` is exposed as working although both current RN native implementations are blocked. | Keep the call explicitly unavailable and forbid recovery/mainnet readiness claims. |
| API-020 | P2 | Open | There is no stable/experimental/advanced API boundary or deprecation policy. | Publish a versioned API policy and snapshot the intended public surface. |
| API-021 | P1 | Open | Exported defaults drift from core: API timeout is 30 seconds instead of 120; log level is string `info` instead of `LogLevel.ERROR` and cannot be passed to `configureLogging`. | Generate typed constants from the approved core contract and add compile/runtime parity vectors. |
| API-022 | P1 | Open | Mainnet/testnet/testnet4/regtest indexer defaults are stale and can connect callers to different infrastructure; current regtest default is local Esplora on port 3002. | Align endpoints deliberately and test resolved unlock requests per network. |
| API-023 | P1 | Open | Network handling adds unsupported `signet_custom`, lowercases values that core treats exactly, and maps numeric `0`/`3` incorrectly in `toNetworkName`. | Implement one strict network parser with exhaustive string/numeric vectors; do not copy the upstream numeric heuristic bug. |
| API-024 | P1 | Open | Removed RN exports remain public: `RNSigner`, PSBT helpers, UTEXO bridge/network maps, `getBridgeAPI`, `TransferStatuses`, and `encodeTransferStatus`; the latter returns only the first UTF-8 byte. | Remove or quarantine obsolete exports; never represent a status with the first byte of its label. |
| API-025 | P1 | Open | Legacy `FetchClient`/bridge helpers have no timeout or close contract, stringify missing required fields as `"null"`, and swallow every transfer lookup error as not-found. | Remove with the obsolete bridge surface or rebuild with typed results, ownership, timeout, and error semantics. |
| API-026 | P2 | Open | Core-compatible error aliases do not match core shape (`statusCode`, stable code constructors, and serialization are missing). | Define a Dart-native but semantically equivalent error contract and compatibility tests. |
| API-027 | P2 | Open | Current runtime export `LspLiquidityTimeoutError` is unmapped while the manifest still lists multiple exports removed from RN. | Regenerate and review the runtime export inventory from current source. |
| API-028 | P1 | Open | Old-artifact `listTransfers()` fallback lists known assets one by one, so it can omit no-asset transfers and return duplicates. | Remove after artifact upgrade or make aggregation complete and deduplicated with fixtures. |
| API-029 | P2 | Open | High-level input shapes have no approved Dart adaptation map: lifecycle credentials, skip-sync exposure, flexible Lightning aliases, on-chain requests, and raw request DTOs differ from RN/core. | Specify each intentional Dart-shaped signature and test semantic equivalence field by field. |
| API-030 | P1 | Open | External-signer unlock accepts `gossipRgsServerUrl` through Dart and Pigeon, but both native plugins discard it because the underlying signer unlock has no such parameter. | Remove or explicitly reject the option for this signer mode, or obtain upstream support; never silently accept a no-op configuration. |
| API-031 | P1 | Open | `UtexoWallet` has no current `capabilities`, `psbt`, or `beginEnd` carrier contract, so unsupported features remain callable runtime throws instead of compile-time absence. | Implement typed optional carriers and derive capability flags from carrier presence so declarations cannot drift from behavior. |
| API-032 | P1 | Open | RLN beta.3 rejects RGB UTXO creation and asset issuance in external-signer mode, but the public wallet exposes both without a signer-mode capability or compile-time boundary. Funded restart execution discovered the restriction only at runtime. | Model signer-mode capabilities explicitly, document the native restriction, and make unsupported RGB UTXO/issuance operations unavailable before a native call; use the upstream trusted virtual BTC-channel regression to prove external-signer persistence. |

### Models, Serialization, and Numeric Correctness

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| MODEL-001 | P1 | Open | Pigeon uses `Map<Object?, Object?>` and `Object?` for most responses and issuance. | Define typed Pigeon DTOs or a generated strict wire schema for every response. |
| MODEL-002 | P1 | Open | Required fields silently become `''`, `0`, `false`, empty maps, or empty lists in `rln_models.dart`. | Reject malformed required data with typed protocol errors. |
| MODEL-003 | P1 | Open | Missing models include assignment kind, rotate/sign/verify/inflate responses, and `pendingBlinded`. | Add exact current wire types and generated shape tests. |
| MODEL-004 | P1 | Open | `RlnNodeInfo` retains removed fields/xpubs and turns current optional metrics into required zeroes. | Match current wire optionality and map separately to the domain model. |
| MODEL-005 | P1 | Open | Media fields are nullable in Flutter but required in current wire; asset off-chain balances have the inverse error. | Preserve exact nullability at the wire boundary. |
| MODEL-006 | P1 | Open | Transaction fields/types are stale; current `SEND_BTC` and `INCOMING` can collapse to `User`. | Model every current enum case and reject unknown values at the appropriate boundary. |
| MODEL-007 | P1 | Open | Transfer optionality is lost; statuses omit `WaitingSafeHeight`/`Initiated`; kind omits `Burn`. | Update transfer DTOs and canonical enum mapping without silent fallback. |
| MODEL-008 | P1 | Open | `RlnUnspent.toCore()` drops `pendingBlinded`; current field is absent entirely. | Preserve the field end to end. |
| MODEL-009 | P1 | Open | Payment type/status values are uppercased to a vocabulary that differs from current RN/core PascalCase. | Centralize generated enum normalization and add iOS/Android fixtures. |
| MODEL-010 | P1 | Open | Channel wire optionals become required defaults; canonical mapper and sat-to-msat conversion are absent. | Preserve wire optionality and return canonical `LightningChannel`. |
| MODEL-011 | P1 | Open | Invoice `recipientId` is optional upstream but becomes an empty required string. | Preserve nullability and validate only where a workflow requires it. |
| MODEL-012 | P1 | Open | Core transfer mapper hard-codes `batchTransferIdx: 0` and silently substitutes status/kind defaults. | Preserve real values or fail; never invent transaction state. |
| MODEL-013 | P1 | Open | Outpoint/assignment parsing uses permissive regex/string fallbacks and fabricates `vout: 0`. | Use structured native fields or strict parsers with typed failure. |
| MODEL-014 | P1 | Open | Fee rates are `double` with default `1.5`, then truncated to native `UInt64` (`1`) on both platforms. | Use an integral type or reject fractions; add exact conversion vectors. |
| MODEL-015 | P2 | Open | Pigeon signed `Int64` cannot represent the full native `UInt64` range; Android sometimes serializes large outputs as strings. | Define supported numeric ranges and one cross-platform large-integer representation. |
| MODEL-016 | P2 | Open | Timestamp and amount units are not consistently documented on public Dart models. | Document and test seconds/msat/sat semantics at every boundary. |

### Lifecycle, Threading, and Architecture

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| LIFE-001 | P1 | Open | Pigeon HostApi handlers are synchronous; generated Swift/Kotlin handlers call RLN directly on message/platform threads. | Move every blocking native call to an owned background task queue and return asynchronously. |
| LIFE-002 | P1 | Open | Native readiness probes call `Thread.sleep`/`usleep` in those synchronous handlers. | Replace blocking polling with cancellable asynchronous coordination. |
| LIFE-003 | P1 | Open | `UtexoWallet.init()` is not idempotent/retry-safe; concurrent calls can repeat signer initialization or leave partial state. | Implement and test an explicit lifecycle state machine with in-flight operation coalescing. |
| LIFE-004 | P1 | Open | `UtexoWallet` bypasses `RLNBinding`'s queue and calls `RlnClient` directly. | Establish one lifecycle/concurrency owner and route all facade calls through it. |
| LIFE-005 | P1 | Open | `_requireNode()` checks handle/disposed only, so many operations run before init/unlock or after shutdown. | Encode required state per operation and fail deterministically before native calls. |
| LIFE-006 | P1 | Open | Successful `shutdown()` leaves node ID and initialized state active while direct operations remain callable. | Represent shutdown explicitly and permit only documented restart/destroy operations. |
| LIFE-007 | P1 | Open | `reinit()` suppresses shutdown failure and recreates against the same storage path/handle, risking conflicts and partial state. | Make restart transactional and prove recovery after every failure point. |
| LIFE-008 | P1 | Open | `destroy()` suppresses shutdown/signer failures and can lose diagnostics or leave partial native resources. | Aggregate cleanup errors, make disposal idempotent, and verify final native store state. |
| LIFE-009 | P1 | Open | Android detach unregisters Pigeon only; iOS has no detach cleanup; global stores retain nodes/signers. | Close all engine-owned nodes/signers on detach and hot restart. |
| LIFE-010 | P1 | Open | iOS replaces a shutdown node without closing it; both stores mark the replacement initialized before its init phase. | Correct ownership/state transitions and add same-path restart tests. |
| LIFE-011 | P2 | Open | Native operations have no uniform timeout/cancellation semantics. | Define cancellation and timeout policy for sync, unlock, network, channel, and send operations. |
| LIFE-012 | P2 | Open | `UtexoWallet` (1595 lines), native plugins (1200+), binding (865), and models (994) combine unrelated domains. | Split by lifecycle, Bitcoin, RGB, Lightning, LSP, mapping, and bridge responsibilities. |
| LIFE-013 | P2 | Open | Platform-interface/method-channel classes cover only artifact metadata while all real work bypasses them via Pigeon. | Simplify to one plugin abstraction or make platform substitution complete. |
| LIFE-014 | P1 | Open | Native init/unlock treats any error text containing `"conflict"` as prior success; init can then return an empty pubkey and mark the node initialized. | Use typed native error categories and prove actual state before transition; never turn an unknown conflict into empty-success. |
| LIFE-015 | P1 | Open | External-signer creation assigns the handle before init/attach completes. A failure can leak the old handle, overwrite it on retry, or skip a required attach on the next unlock. | Make signer creation/attach transactional, destroy failed handles, and test every retry/failure boundary. |

### LSP and Network Behavior

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| LSP-001 | P1 | Open | Flutter keeps a duplicated pre-beta.25 LSP implementation; current RN re-exports the canonical core implementation. | Port the current core contract/behavior and remove duplicate drift. |
| LSP-002 | P1 | Open | Callback rewrite replaces scheme/host/port but drops a configured base URL path prefix. | Rebase callback paths exactly like current core and add proxy-prefix tests. |
| LSP-003 | P1 | Open | `payAddress` catches every configured-client error and falls back, masking auth, TLS, server, and parse failures. | Fall back only for an explicit unsupported/not-found case. |
| LSP-004 | P1 | Open | Fallback HTTP bypasses the injected client, has no timeout/status checks, and follows untrusted callback schemes. | Use one owned client, enforce timeout/status/HTTPS policy, and validate callback hosts. |
| LSP-005 | P1 | Open | `claimPendingPayments` substitutes an empty preimage and attempts a claim. | Skip/report missing preimages without making the native call. |
| LSP-006 | P1 | Open | Old status helpers collapse Lightning states into RGB transfer states, breaking settlement semantics. | Use canonical Lightning status methods and types. |
| LSP-007 | P2 | Open | Polling uses wall-clock time and accepts invalid timeout/poll values. | Use a monotonic clock, validate options, and inject time/sleep for deterministic tests. |
| LSP-008 | P2 | Open | Peer-connect idempotence is detected by substring matching `"already"`. | Map a typed native conflict/already-connected error. |
| LSP-009 | P2 | Open | Injected HTTP client ownership is undocumented and the client is always closed by the SDK. | Make ownership explicit or track whether the SDK created the client. |

### Security and Cryptography

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| SEC-001 | P0 | Verified | The former ephemeral VLS signer path was replaced with `newWithStorage(storageDirPath)` and transactional handle ownership. | Disk-backed signer creation and funded restart/channel-payment tests pass on both platforms. |
| SEC-002 | P1 | Open | Password, mnemonic, seed bytes, and seed hex are retained in immutable Dart objects; external signer keeps `_seedHex` for its lifetime. | Minimize lifetime/copies, use zeroizable buffers where possible, and document unavoidable runtime limits. |
| SEC-003 | P1 | Open | Native failures surface as raw `PlatformException`; exported typed SDK errors are not used for bridge failures. | Centralize stable domain error mapping with category, operation, retryability, and cause. |
| SEC-004 | P1 | Open | Error text/details have no redaction policy; generated fallback errors include stack traces and native messages. | Redact secrets/paths/tokens and test support-safe serialization. |
| SEC-005 | P1 | Open | `LspError` stores and prints unbounded response bodies. | Bound and redact response previews; preserve full bodies only in opt-in secure diagnostics. |
| SEC-006 | P1 | Open | LSP/VSS HTTP can be enabled without a production transport policy. | Require TLS outside explicit regtest/development configuration. |
| SEC-007 | P1 | Open | BIP340/Schnorr is hand-rolled over PointyCastle without an audited constant-time signing boundary or differential suite. | Use a vetted implementation/native primitive and run official/differential known-answer tests. |
| SEC-008 | P2 | Open | No dependency vulnerability, license, binary provenance, or secret-log scan is a release gate. | Add reproducible audits and store results with the release evidence. |
| SEC-009 | P2 | Accepted constraint | Durable credential storage is app-owned, not SDK-owned. | Document the boundary; SDK still owns in-memory minimization and must never persist credentials implicitly. |
| SEC-010 | P1 | Open | `RlnSeedBytesKeyMaterial` retains the caller's mutable `Uint8List` by reference, allowing key material to change after construction and leaving ownership/zeroization ambiguous. | Copy into an owned zeroizable representation and define destruction semantics. |
| SEC-011 | P0 | Verified | Native node creation could leave a newly created storage root with group/other permissions, after which RLN correctly rejected `newWithStorage` and durable external-signer initialization could not start. | Both plugins now enforce owner-only storage roots and fail closed for unsafe existing paths; native policy tests and funded cross-process restart/payment smokes pass on iOS and Android. |
| SEC-012 | P1 | Verified | The native storage policies rejected group/other access but accepted owner-only directory modes missing required owner read/write/execute bits, such as `0600`; RLN would then fail later through a less stable error path despite the policy claiming `0700`. | Both platforms now require exact mode `0700`; the new negative cases pass in the 9-case iOS and 12-case Android native suites. |

### Packaging, Platforms, and Supply Chain

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| PKG-001 | P1 | Open | CI checksum verification fails in a clean checkout because all iOS artifacts are ignored and no download step runs. | Make clean CI artifact acquisition and verification deterministic. |
| PKG-002 | P1 | Open | CocoaPods `prepare_command` downloads binaries during consumer install. | Prefer pre-resolved internal artifacts or a deterministic cacheable fetch with offline behavior. |
| PKG-003 | P1 | Open | iOS downloader skips any existing framework/source without verifying version or checksum. | Verify before reuse and replace stale artifacts atomically. |
| PKG-004 | P1 | Open | Version/checksum/source metadata is duplicated across Dart, Swift, Kotlin, Gradle, shell, tests, and docs. | Generate all consumers from one reviewed artifact manifest. |
| PKG-005 | P1 | Open | Android AAR verification is optional and checks the first matching Gradle cache file. | Use Gradle dependency verification or resolve and hash the exact artifact. |
| PKG-006 | P1 | Open | No artifact signature/provenance, SBOM, license inventory, ABI symbol check, or architecture validation exists. | Add and gate all five for a production release. |
| PKG-007 | P1 | Open | `ios/Resources/PrivacyInfo.xcprivacy` exists but is not bundled by the podspec. | Bundle and validate the privacy manifest in a consumer app archive. |
| PKG-008 | P1 | Open | Pod lint reports vendored simulator objects built for iOS 18.5 while the pod declares iOS 13. | Rebuild compatible artifacts or raise/document the real minimum and test it. |
| PKG-009 | P1 | Open | Plugin and example release manifests omit Android `INTERNET`; only debug/profile declare it. | Declare or clearly enforce the permission and verify a release build can network. |
| PKG-010 | P2 | Open | Android plugin contains both `settings.gradle` and `settings.gradle.kts`. | Keep one supported build configuration. |
| PKG-011 | P2 | Open | AGP 8.11.1, Kotlin 2.2.20, compileSdk 36, Java 17, minSdk 24, Swift 5, and iOS 13 have no consumer compatibility matrix. | Define and test supported Flutter/Gradle/Kotlin/Xcode/OS ranges. |
| PKG-012 | P1 | Open | Dart `^3.11.5` is incompatible with the declared Flutter minimum `>=3.3.0`. | Set coherent SDK constraints based on tested Flutter releases. |
| PKG-013 | P2 | Needs decision | `publish_to: none` and private Git install are used without an immutable distribution/version policy. | Decide private registry vs tagged Git distribution and document integrity/rollback. |
| PKG-014 | P2 | Open | `dart pub publish --dry-run` exits 65 in the current dirty worktree: tracked historical docs are deleted locally but remain gitignored/indexed until commit, and no `.pubignore` defines intentional package contents. | Re-run from the clean candidate, add an intentional `.pubignore` where needed, and make dry-run warning-free. |
| PKG-015 | P2 | Open | Podspec lacks complete license/source metadata and lint emits warnings. | Make pod lint warning-free except documented unavoidable vendor warnings. |
| PKG-016 | P1 | Open | No clean consumer tests cover Git/tarball install, cold/stale/offline CocoaPods cache, Gradle resolution, or release archives. | Add a local release matrix using clean temporary consumer projects. |
| PKG-017 | P2 | Open | Upstream artifacts are accepted only for development/internal beta, but the package does not enforce that boundary. | Mark artifacts/builds as non-production until production provenance gates pass. |

### Testing and Release Evidence

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| TEST-001 | P1 | Open | Dart tests now assert supported rotate/inflate/sign/verify delegation and the intentional `skipSync` fail-fast divergence, but these remain mostly mock/contract checks rather than native behavior proofs. | Add current real-native success/failure vectors while retaining the approved `skipSync` divergence test. |
| TEST-002 | P1 | Open | Most Dart tests are mock/delegation contracts; they cannot prove native serialization, persistence, threading, or funds behavior. | Add layered contract, native, and end-to-end tests with independent oracles. |
| TEST-003 | P2 | Open | Dart line coverage is 57.4%; no threshold or changed-line rule exists. | Define meaningful domain thresholds while excluding generated code appropriately. |
| TEST-004 | P0 | Verified | No external-signer process-restart/channel-state/payment test existed. | The one-install/two-process funded restart proof passes on iOS and Android with pre/post-restart bidirectional settlement. |
| TEST-005 | P1 | Open | Dart contract tests cover the new beta.25 surface, but rotate/sign/verify/inflate, txid histories, `backupNow`, assignment kinds, and description hash do not have complete iOS/Android execution coverage. | Cover every new beta.25 API on both platforms and at the public facade with independent assertions. |
| TEST-006 | P1 | Open | HODL/APay/LSP/VSS tests are mainly mocked and do not cover production failure/retry/settlement paths. | Add controlled service/native integration suites and negative cases. |
| TEST-007 | P1 | Open | No lifecycle concurrency, retry, crash/restart, hot-restart, cancellation, stress, or fault-injection suite exists. | Build deterministic state-machine and platform stress tests. |
| TEST-008 | P1 | Open | Native bridge tests are small and asymmetric; Flutter has no Android instrumentation equivalent and limited iOS XCTest. | Create platform-equivalent native suites for every bridge family and malformed response. |
| TEST-009 | P2 | Open | No fuzz/property/differential tests cover parsers, numeric boundaries, enums, keys, or Schnorr. | Add official vectors plus property and cross-implementation differential tests. |
| TEST-010 | P1 | Open | Parity validator compares names, not signatures/defaults/fields/returns/native implementations/behavior; its regex misses multiline methods. | Replace with AST/schema-based API and generated native conformance checks. |
| TEST-011 | P1 | Open | Test-matrix `fixture` and `contract` fields are unlinked declarations; labels such as `restart_persistence` and `funded_rgb_asset_types` do not prove those flows ran, while the validator skips getters/static APIs and can pass fake stubs. | Link every row to executable test IDs, implementation symbols, platform evidence, and independent assertions. |
| TEST-012 | P1 | Open | Release script reports `passed` when iOS XCTest/platform smokes are skipped. | Represent required, passed, failed, and skipped gates explicitly; skipped required gates fail release. |
| TEST-013 | P1 | Open | Current iOS/Android builds and funded/unfunded smokes were not run on the audited commit/artifacts. | Run the complete local matrix on the exact candidate and attach evidence. |
| TEST-014 | P2 | Open | Reports are ignored, unauthenticated, and contain local absolute paths. Native/release reports use only the short HEAD, omit dirty-worktree state, and overwrite earlier runs at the same commit; restart reports record dirty state but are still mutable local files. | Produce sanitized checksummed reports tied to the exact clean commit, tools, devices, artifacts, stack image, and unique run ID. |
| TEST-015 | P2 | Open | Integration tests create wallet temp directories without guaranteed cleanup. | Use teardown/finally cleanup and verify no native handles/files remain. |
| TEST-016 | P2 | Open | No public API/ABI snapshot or semantic versioning compatibility test exists. | Snapshot Dart API, Pigeon schema, Android ABI, iOS symbols, and model JSON/wire fixtures. |
| TEST-017 | P2 | Accepted constraint | Native builds and regtest smokes will not run in CI. | Make the local release gate mandatory, reproducible, attributable, and impossible to report green when skipped. |
| TEST-018 | P1 | Verified | The native iOS test script reused a stale CocoaPods source graph and omitted newly added plugin files. It now runs `pod install` before `xcodebuild`, records that step, and the follow-up XCTest run compiled the new policy file and passed all nine cases. | Keep the explicit pod refresh in every local native iOS release run. |
| TEST-019 | P1 | Verified | Regtest startup considered electrs ready when its TCP port opened, even while a persisted stale Bitcoin tip kept bitcoind in IBD and electrs returned no protocol response; RLN unlock then failed after its startup timeout. | Startup now establishes a current non-IBD tip and validates an Electrum `server.version` JSON response; both final platform restart runs passed the gate. |
| TEST-020 | P1 | Verified | Two independent `flutter test` invocations reinstall the platform test app; on iOS the second install receives a new sandbox and deletes the first process's persisted node/signer state, so the apparent restart test cannot exercise recovery. | The controller now builds and installs one auto-phased binary, coordinates through atomic run-scoped files, force-terminates and relaunches without reinstalling, verifies unchanged storage, and requires second-process result markers on iOS and Android. |
| TEST-021 | P1 | Verified | `test_native_ios.sh` always placed `DEVICE` in Xcode's `name=` destination field, so a valid simulator UUID failed selection even while Xcode listed that UUID. | The script now emits `id=` for canonical UUIDs and `name=` otherwise, records the resolved destination, and the UUID path passed all nine XCTest cases. |
| TEST-022 | P1 | Verified | The restart fixture reused one constant signer seed, so a persisted regtest chain could contain spendable UTXOs from an earlier run and let the current prepare phase advance before its own funding request was serviced. | The controller now derives and validates a unique 32-byte seed per run; fresh-address funding and the full restart proof passed on both platforms. |
| TEST-023 | P1 | Verified | The iOS restart controller treated a listed simulator as runnable even when XCTest had left it shut down, so app installation failed before the test with CoreSimulator state error 405. | The controller now boots the selected simulator when needed, blocks on `simctl bootstatus`, and the subsequent full iOS restart proof passed. |

### Code Quality, Modularity, and Documentation

| ID | Pri | Status | Finding and evidence | Required outcome |
| --- | --- | --- | --- | --- |
| CODE-001 | P2 | Open | Public barrel exports raw bridge internals, wire models, obsolete helpers, LSP internals, and compatibility shims. | Export a small stable facade; move advanced/internal APIs to explicit libraries. |
| CODE-002 | P2 | Open | Dart naming violates idioms (`RLNManager`, `RLNBinding`, `IRLN*`, `RNSigner`, `decodeRGBInvoice`, field `public`). | Use Dart-style names on stable APIs; isolate literal RN names to parity tooling. |
| CODE-003 | P2 | Open | `analysis_options.yaml` only imports `flutter_lints`; strict casts/inference/raw-types and package-specific rules are absent. | Enable strict analysis and an approved production lint set. |
| CODE-004 | P2 | Open | Broad `catch (_)`, substring error classification, and swallowed cleanup errors are common. | Catch typed errors, preserve causes, and make intentional suppression observable. |
| CODE-005 | P2 | Open | Raw, core, compatibility, and facade models duplicate concepts without a clear ownership boundary. | Define wire/domain/public layers and one mapper direction between each. |
| CODE-006 | P2 | Open | LSP, wallet, binding, client, and native plugins duplicate validation/default/status logic. | Centralize generated contracts and domain policies. |
| CODE-007 | P2 | Open | Public API docs are sparse and rarely state lifecycle prerequisites, units, errors, side effects, secret handling, or platform support. | Document every public symbol and verify examples in CI/local gates. |
| CODE-008 | P2 | Open | Current code/docs no longer contain beta.19 claims outside historical tracker/changelog context, but broad “RN-style/parity” names remain and no automated stale-baseline language check exists. | Tie parity claims to the generated baseline and executable contract scope so future comments/tests cannot imply more than they prove. |
| CODE-009 | P2 | Open | There is no architecture decision record for Pigeon vs FFI/UniFFI-Dart, artifact ownership, or stable API layering. | Record decisions, alternatives, reversal criteria, and ownership. |
| CODE-010 | P2 | Open | No formal compatibility/migration plan exists for removing the large stale public surface. | Add deprecations, migration notes, and a versioned breaking-change plan. |
| CODE-011 | P2 | Open | Public DTOs/configs are only shallowly immutable and retain mutable lists/maps; most have no value equality or copy semantics. | Adopt immutable value types and defensive copies at public boundaries. |
| CODE-012 | P2 | Open | Public failures mix `PlatformException`, SDK exceptions, `ArgumentError`, `StateError`, and raw HTTP errors. | Define one documented error taxonomy and map every boundary into it. |
| DOC-001 | P1 | Verified | Root README claimed release-candidate hardening and 55/55 beta.19 parity after upstream changed. | README now states the exact audited baselines, no-go verdict, and limits of existing test/parity evidence. |
| DOC-002 | P2 | Verified | Sixteen overlapping historical docs were removed in favor of this tracker. | Keep this file authoritative; do not recreate parallel status documents. |
| DOC-003 | P2 | Verified | Example and test-matrix READMEs previously treated mocked/matrix checks as production evidence. | Both now state their exact scope, stale baseline, missing evidence, and authoritative release-gate link. |
| DOC-004 | P2 | Open | No current support matrix, upgrade guide, artifact migration, recovery boundary, or app integration security guide exists. | Publish them after the API/artifact baseline is fixed. |
| DOC-005 | P2 | Open | `dart doc` has zero warnings but this does not measure completeness or semantic accuracy. | Add documentation coverage/review criteria and executable snippets. |
| DOC-006 | P2 | Verified | GitHub issue templates referenced the deleted parity matrix, omitted exact baselines, and allowed tests to be deferred without release-gate semantics. | Templates now require tracker IDs, immutable baselines, typed cross-platform scope, executable evidence, and tracker updates. |

## Accepted Decisions and Constraints

1. **Local backup/recovery:** keep `createBackup`/`rlnBackup` explicitly
   native-blocked. This is honest parity with actual native behavior, but it
   forbids recovery-ready and mainnet-production claims.
2. **Native CI:** do not run native builds or regtest smokes in CI. They remain
   mandatory local release gates with auditable evidence.
3. **Bridge technology:** keep Pigeon for this release line. UniFFI-Dart may be
   evaluated separately; a bridge rewrite does not replace API/model/lifecycle
   correctness work.
4. **Artifacts:** upstream artifacts are acceptable for development and
   internal beta only. Production requires provenance, compatibility, and
   reproducibility gates.
5. **Secure storage:** durable credential storage is app-level. The SDK remains
   responsible for minimizing in-memory secrets and documenting ownership.
6. **RGB `skipSync`:** keep fail-fast until the native artifact adds real
   support. RN beta.25 silently discards the option on both platforms, which is
   not behavior Flutter should copy.

## Upstream Defects We Must Not Copy

The RN `dev` branch is the parity reference, not an automatic quality oracle.

| Upstream issue | Flutter policy |
| --- | --- |
| RN/core says lifecycle init/dispose is idempotent/retryable, but RN implementation does not fully enforce it | Implement the stronger core invariant and test failures/concurrency |
| Core declares `createBackup` implemented; current RN native bridge throws | Preserve explicit native-blocked status |
| RN artifact downloader skips existing iOS frameworks and lacks checksum verification | Verify before reuse |
| RN release workflow publishes after build without the full native/regtest/security matrix | Use the stronger Flutter local release gate |
| RN also truncates fractional fee rates | Fix the contract instead of reproducing the bug |
| Core/RN error and LSP-body handling is not sufficient for wallet secrets | Apply Flutter-specific redaction and diagnostics policy |
| Core LSP also uses broad fallback, empty-preimage claims, substring error matching, and wall-clock polling | Keep parity at the public contract while fixing unsafe orchestration behavior |
| Core `toNetworkName` also misclassifies numeric network identifiers through substring heuristics | Use an exhaustive network mapping with vectors for every accepted identifier |
| RN also accepts `gossipRgsServerUrl` for native external-signer unlock and silently drops it in both native plugins | Reject unsupported configuration or add real upstream support; do not claim the option was applied |
| RN also uses conflict-string heuristics around lifecycle operations | Require typed errors and verified state transitions |
| RN beta.25 accepts RGB `skipSync` but omits it from both native `SendRgbRequest` constructions because RLN beta.3 has no such field | Preserve Flutter's explicit fail-fast behavior until the artifact supports it |

## Remediation Order

1. **Safety baseline:** upgrade RLN artifacts, implement disk-backed signer
   persistence, establish one version manifest, and prove restart safety.
2. **Generated contract:** model the complete current native API with typed
   requests/responses and regenerate Dart/Swift/Kotlin.
3. **Domain API:** rebuild the stable wallet facade around canonical models,
   optional capability carriers, explicit errors, and correct defaults.
4. **Lifecycle/threading:** move native work off platform threads and implement
   a tested transactional lifecycle state machine.
5. **LSP/security:** port current core behavior, harden transport/error/secret
   handling, and replace or independently audit cryptographic primitives.
6. **Packaging:** make artifact acquisition, verification, privacy metadata,
   permissions, and clean consumer installs deterministic.
7. **Verification:** execute the full contract/native/restart/failure/funded
   matrix on both platforms and attach sanitized release evidence.
8. **Public release:** finalize docs, migration, semver/API snapshots, and only
   then reconsider the no-go verdict.

## Definition of Production Ready

Production ready means every P0 and P1 issue is `Verified`; every P2 issue is
either `Verified` or explicitly accepted with an owner and expiry; all release
gates pass on one immutable commit and one immutable artifact set; no required
gate is skipped; a clean app can install and archive on every supported
toolchain; external-signer restart and funded RGB Lightning flows pass on both
platforms; public docs match executable behavior; and the release makes no
recovery guarantee while native backup remains blocked.
