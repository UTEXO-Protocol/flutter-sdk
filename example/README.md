# RGB SDK Flutter Example

This app compiles and exercises the current plugin bindings for local
development. It is not evidence that the SDK is production ready.

Run widget tests from this directory:

```sh
flutter test test
```

The standalone offline native test creates, releases, and reopens a persistent
native signer in one fresh private directory through the real Flutter bridge.
It uses a public test-vector seed and requires no stack, endpoints, node, wallet,
or network access:

```sh
flutter test integration_test/offline_native_load_test.dart -d <owned-device-id>
```

This tests native loading and signer-handle release/reopen. It does not prove
public identity continuity, unlocked-node shutdown, signer revocation, funded
operations, process restart, or the WDK lifecycle overlay's acceptance criteria.
The other integration files contain separately gated regtest/funded scenarios
that require their explicit configuration and service dependencies.

See the
[Release Readiness Tracker](../doc/RELEASE_READINESS_TRACKER.md) for the
current verdict, missing test evidence, and exact release gates.
