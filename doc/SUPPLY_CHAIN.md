# Supply Chain

The package consumes native binary artifacts from the upstream RLN project. The
current policy is to pin versions, record checksums, verify local vendored
files, and keep a private mirroring path available before any production app
release.

## Upstream Inputs

RN reference:

- Repository: `UTEXO-Protocol/rgb-sdk-rn`
- Branch: `dev`
- Commit: `3d0cc8c8e170e493e1090a88216759043a37e03c`
- Package version: `1.0.0-beta.19`

RLN artifacts:

- Version: `0.6.0-beta.2`
- iOS release zip:
  `https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/download/v0.6.0-beta.2/rgb-lightning-node-swift-0.6.0-beta.2.zip`
- Android Maven coordinate:
  `com.utexo:rgb-lightning-node-android:0.6.0-beta.2`

Treat the checked-in RN Swift download script and Android Gradle dependency as
the reproducible source of truth.

## Recorded Checksums

Upstream iOS release zip:

```text
6ce1c107650b1078f3b94c30dc5fd68740147f73c2d22bd831abd751b72fa827  rgb-lightning-node-swift-0.6.0-beta.2.zip
```

Android Maven AAR observed in the local Gradle cache:

```text
94c343928bc3bdf7dcbd584d446ec9559e198909971bb40d91901b588400d8df  rgb-lightning-node-android-0.6.0-beta.2.aar
```

iOS vendored file checksums live in `tool/native_artifacts.sha256`.

## Verification

Run local verification before release:

```sh
./tool/verify_native_artifacts.sh
```

The script always verifies checked-in iOS vendored files. It verifies the
Android Maven AAR when the artifact is present in the local Gradle cache. It can
also verify the upstream iOS zip on demand:

```sh
VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh
```

For a release candidate, run with strict Android verification after Gradle has
resolved dependencies:

```sh
REQUIRE_ANDROID_AAR=1 VERIFY_REMOTE=1 ./tool/verify_native_artifacts.sh
```

## Private Mirror Policy

Before a production app consumes this package, mirror native artifacts into a
controlled private location.

Required mirror metadata:

- Original upstream URL or Maven coordinate.
- Upstream release version.
- Original checksum.
- Mirror checksum.
- Date mirrored.
- Operator or automation identity.
- Reason for upgrade.

Mirror usage rules:

- Keep the package source pinned to exact versions.
- Never consume `latest`, moving tags, or unversioned binary URLs.
- Keep public upstream checksums and private mirror checksums in release notes.
- If a mirror artifact differs from the upstream checksum, treat it as a new
  artifact requiring review.

## Upgrade Procedure

1. Update the native RLN version in docs, constants, iOS scripts, and Android
   Gradle files.
2. Download and verify the iOS zip from the upstream release.
3. Resolve the Android Maven AAR and record its checksum.
4. Re-run Pigeon generation if native signatures changed.
5. Run Dart unit tests, example tests, iOS simulator build, Android debug build,
   and funded regtest smokes on both platforms.
6. Update the parity matrix with newly supported, changed, or blocked methods.
7. Update the release notes with every checksum and verification command.
