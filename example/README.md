# RGB SDK Flutter Example

This app compiles and exercises the current plugin bindings for local
development. It is not evidence that the SDK is production ready.

Run widget tests from this directory:

```sh
flutter test test
```

The integration tests in `integration_test/` require the repository's local
regtest stack and explicit `--dart-define` configuration. Existing integration
coverage includes the current low-level beta.25 contract but does not yet prove
external-signer process restart, recovery, or the complete failure matrix.

Android release networking also requires the host application's `INTERNET`
permission until the packaging issue is resolved.

See the
[Release Readiness Tracker](../doc/RELEASE_READINESS_TRACKER.md) for the
current verdict, missing test evidence, and exact release gates.
