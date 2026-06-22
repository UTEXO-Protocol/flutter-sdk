# Release Test Report Template

Use this template when signing off a release candidate from the JSON files under
`build/test-reports`.

## Candidate

- Git commit:
- Package version:
- RLN artifact version:
- React Native parity version:
- Flutter version:
- Xcode version:
- Android SDK/NDK version:
- Report files:

## Required Gates

- Static/package gate: pass/fail
- Matrix validation: pass/fail
- RN dev source parity validation: pass/fail
- Pigeon drift check: pass/fail
- Native artifact checksum verification: pass/fail
- Package unit/contract tests: pass/fail
- Example widget tests: pass/fail
- iOS unfunded platform smoke: pass/fail/not run
- iOS funded platform smoke: pass/fail/not run
- Android unfunded platform smoke: pass/fail/not run
- Android funded platform smoke: pass/fail/not run

## Exceptions

- `rlnBackup`: native-blocked by the pinned RN-matching artifact until upstream
  support exists or a separate reviewed recovery design replaces it.
- `rlnSendRgb.skipSync=true`: parameter-level native artifact gap; must fail
  fast before native execution until upstream exposes the field.
- Physical-device validation: required for wallet app beta/mainnet; may be
  pending only for an internal package-only release with explicit release-note
  disclosure.

## Sign-Off

- Reviewer:
- Date:
- Decision:
- Notes:
