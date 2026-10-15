# Native provenance verification

The production supply-chain gate verifies actual signatures and signed build
claims. `status: verified` requests verification; it does not authorize an
artifact. Current artifacts have no such evidence and remain internal-beta-only.
No production trust roots have been approved in `tool/native_provenance_trust.json`.

## Supported evidence

The offline verifier supports RSA keys of at least 3072 bits, SHA-256 and detached
signatures over exact file bytes (`format: rsa-sha256-detached`). It uses OpenSSL
without a shell and rejects nonzero results and deadlines. This deliberately
limited format is not a DSSE, GPG, Sigstore, or SLSA build-level verifier. Other
formats require their own reviewed verifier; never convert a verified-looking
status into a bypass. Protocol references: [OpenSSL dgst](https://docs.openssl.org/master/man1/openssl-dgst/)
and [SLSA artifact verification](https://slsa.dev/spec/v1.2/verifying-artifacts).

An independently reviewed trust policy provides each key's `keyId`, `role`
(`publisher`, `builder`, or `reproducer`), approved `identity`, `artifactIds`,
repository-relative `publicKeyPath`, and SHA-256 of the exact PEM bytes in
`publicKeySha256`. Builder keys additionally pin `buildType` and nonempty
`requiredInputs`: `{uri, digest: {algorithm: exactDigest}}` entries for the build
recipe, dependency lockfiles and toolchain inputs. Source repository and commit
are always required from the release baseline, independently of those inputs.
Reviewers must confirm the completeness and meaning of these pins. Do not take
keys, builder identities or trust policy from the artifact download itself.

For each artifact in `tool/native_artifact_provenance.json`, supply all three:

- `signature`: `status: verified`, `format`, publisher `keyId`, `signaturePath`.
  The signature must cover the exact baseline archive, including size and digest.
- `attestation`: the same fields with the builder key, plus `statementPath`.
  This is a detached signature over the original UTF-8 JSON bytes of an in-toto
  `https://in-toto.io/Statement/v1` with
  `predicateType: https://slsa.dev/provenance/v1`. The one subject must name the
  artifact ID and its SHA-256. `predicate.runDetails.builder.id`,
  `predicate.buildDefinition.buildType` and `resolvedDependencies` must match the
  approved builder and pinned source/build inputs.
- `reproducibleBuild`: the same fields with the independent reproducer key, plus
  `receiptPath`. The signed receipt must have `schemaVersion: 1`,
  `type: utexo-native-reproduction`, `artifactId`, `artifactSha256`,
  `artifactSizeBytes`, `sourceRepository`, `sourceCommit`, `provenanceSha256`
  (digest of the original statement bytes), approved reproducer `identity`,
  `result: byte-for-byte-match`, `cleanBuild: true` and a reviewable HTTPS
  `runUrl`. The reproducer's key and identity must differ from both publisher
  and builder. Key independence compares canonical DER SubjectPublicKeyInfo, so
PEM formatting or alternate key encoding cannot disguise the same RSA key.
The trusted reproducer is responsible for executing the clean
  rebuild and preserving reviewable run logs; this verifier checks its signed
  report and bindings, and does not itself reproduce native binaries.

All evidence/key paths are bounded repository-relative files and cannot escape
through traversal or symlinks. Private keys never belong in this repository.
Approve public trust roots separately from the artifact/evidence change. Tests
use disposable generated keys, not production identities.

## Run

Resolve the unchanged native artifacts, then run:

```sh
RGB_SDK_IOS_ARCHIVE_PATH=/absolute/path/to/original.zip \
RGB_SDK_ANDROID_AAR_PATH=/absolute/path/to/original.aar \
dart run tool/validate_supply_chain.dart --production
```

The gate independently compares installed iOS native files against their pinned
hashes and validates the Android AAR before admitting native provenance. Missing,
partial or invalid signatures/attestations/reproduction fail production. Current
absent evidence remains a production blocker; do not sign historical binaries
without rebuilding and reviewing their source and inputs.
