#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/evidence_shell.sh"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
POD_BIN="${POD_BIN:-pod}"
DEVICE="${DEVICE:-${IOS_DEVICE:-}}"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/native}"

die() {
  echo "error: $*" >&2
  exit 1
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

[[ -n "${DEVICE}" ]] || die "set DEVICE or IOS_DEVICE to an iOS simulator name or UUID"

if [[ "${DEVICE}" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
  DESTINATION="platform=iOS Simulator,id=${DEVICE}"
else
  DESTINATION="platform=iOS Simulator,name=${DEVICE}"
fi

mkdir -p "${REPORT_DIR}"
REPORT_DIR="$(cd "${REPORT_DIR}" && pwd)"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FULL_COMMIT="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
SHORT_COMMIT="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
RUN_ID="${RELEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
DEVICE_LABEL="${DEVICE//[^A-Za-z0-9_.-]/_}"
if [[ -n "$(git -C "${REPO_DIR}" status --short 2>/dev/null)" ]]; then
  WORKTREE_DIRTY="true"
else
  WORKTREE_DIRTY="false"
fi
REPORT_FILE="${REPORT_DIR}/native-ios-${DEVICE_LABEL}-${RUN_ID}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/native-ios-${DEVICE_LABEL}-${RUN_ID}-${SHORT_COMMIT}.log"
start_evidence "${REPORT_FILE}"

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

repo_label_path() {
  local path="$1"
  case "${path}" in
    "${REPO_DIR}"/*) printf '<repo>/%s' "${path#"${REPO_DIR}/"}" ;;
    *) printf '%s' "${path}" ;;
  esac
}

set +e
(
  set -euo pipefail
  cd "${REPO_DIR}/example"
  # Flutter's config-only build can itself invoke CocoaPods. Constrain that
  # subprocess as well as the explicit install below, before any build work.
  [[ -f ios/Podfile.lock ]] || die "a committed example iOS Podfile.lock is required"
  REAL_POD_BIN="$(command -v "${POD_BIN}")" || die "CocoaPods executable is unavailable"
  REAL_POD_BIN="$(cd "$(dirname "${REAL_POD_BIN}")" && pwd)/$(basename "${REAL_POD_BIN}")"
  POD_GUARD_DIR="$(mktemp -d "${REPORT_DIR}/.locked-pods.XXXXXX")"
  trap 'rm -rf "${POD_GUARD_DIR}"' EXIT
  cp ios/Podfile.lock "${POD_GUARD_DIR}/Podfile.lock"
  export RGB_SDK_LOCKED_POD_BIN="${REAL_POD_BIN}"
  cat >"${POD_GUARD_DIR}/pod" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == install ]]; then
  shift
  for argument in "$@"; do
    case "${argument}" in
      --repo-update|--repo-update=*|--no-deployment|--deployment=*)
        echo "Mutable CocoaPods dependency resolution is forbidden during qualification." >&2
        exit 1
        ;;
    esac
  done
  exec "${RGB_SDK_LOCKED_POD_BIN}" install --deployment --no-repo-update "$@"
fi
exec "${RGB_SDK_LOCKED_POD_BIN}" "$@"
SH
  chmod 700 "${POD_GUARD_DIR}/pod"
  export PATH="${POD_GUARD_DIR}:${PATH}"
  "${FLUTTER_BIN}" build ios --simulator --config-only
  cmp -s ios/Podfile.lock "${POD_GUARD_DIR}/Podfile.lock" || die "Flutter configuration changed the locked iOS dependencies"

  cd ios
  "${REAL_POD_BIN}" install --deployment --no-repo-update
  cmp -s Podfile.lock "${POD_GUARD_DIR}/Podfile.lock" || die "CocoaPods changed the locked iOS dependencies"
  xcodebuild test \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -destination "${DESTINATION}"
) 2>&1 | tee "${LOG_FILE}"
EXIT_CODE="${PIPESTATUS[0]}"
set -e

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  STATUS="passed"
else
  STATUS="failed"
fi
# Finalization alone can authorize a clean, complete report.
RELEASE_ELIGIBLE="false"

cat >"${REPORT_FILE}" <<JSON
{
  "schemaVersion": 1,
  "suite": "native-ios-xctest",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "releaseEligible": ${RELEASE_ELIGIBLE},
  "evidenceId": "$(json_escape "rgb-sdk-flutter/native-ios-xctest/${RUN_ID}/${FULL_COMMIT}/${DEVICE_LABEL}")",
  "repository": {"commit": "$(json_escape "${FULL_COMMIT}")", "shortCommit": "$(json_escape "${SHORT_COMMIT}")"},
  "workingTree": {"dirty": ${WORKTREE_DIRTY}},
  "device": "$(json_escape "${DEVICE}")",
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "command": "$(json_escape "cd example && flutter build ios --simulator --config-only && cd ios && pod install && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination ${DESTINATION}")",
  "logPath": "$(json_escape "$(repo_label_path "${LOG_FILE}")")",
  "logSha256": "$(json_escape "$(sha256_file "${LOG_FILE}")")",
  "sanitization": {"pathPolicy": "repo-relative-labels"}
}
JSON

echo "native iOS report: ${REPORT_FILE}"
finish_evidence "${REPORT_FILE}"
exit "${EXIT_CODE}"
