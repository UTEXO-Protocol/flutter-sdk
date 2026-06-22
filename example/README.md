# RGB SDK Flutter Example

Small example app used to compile and exercise the plugin host bindings.

## Local Smoke Tests

From this directory:

```sh
flutter test test
```

The real RLN bridge smoke tests live in `integration_test/` and are gated by
`--dart-define` flags because they require the local regtest stack. See
`../doc/TESTING_STRATEGY.md` for the exact commands.
