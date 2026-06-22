#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DEVICE="${DEVICE:-${IOS_DEVICE:-}}"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/native}"

die() {
  echo "error: $*" >&2
  exit 1
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

[[ -n "${DEVICE}" ]] || die "set DEVICE or IOS_DEVICE to an iOS simulator name, for example DEVICE='iPhone 17 Pro'"

mkdir -p "${REPORT_DIR}"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
COMMIT="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
REPORT_FILE="${REPORT_DIR}/native-ios-${DEVICE//[^A-Za-z0-9_.-]/_}-${COMMIT}.json"
LOG_FILE="${REPORT_DIR}/native-ios-${DEVICE//[^A-Za-z0-9_.-]/_}-${COMMIT}.log"

set +e
(
  cd "${REPO_DIR}/example"
  "${FLUTTER_BIN}" build ios --simulator --config-only

  cd ios
  xcodebuild test \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -destination "platform=iOS Simulator,name=${DEVICE}"
) 2>&1 | tee "${LOG_FILE}"
EXIT_CODE="${PIPESTATUS[0]}"
set -e

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  STATUS="passed"
else
  STATUS="failed"
fi

cat >"${REPORT_FILE}" <<JSON
{
  "suite": "native-ios-xctest",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "commit": "$(json_escape "${COMMIT}")",
  "device": "$(json_escape "${DEVICE}")",
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "command": "$(json_escape "cd example && flutter build ios --simulator --config-only && cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination platform=iOS Simulator,name=${DEVICE}")",
  "logPath": "$(json_escape "${LOG_FILE}")"
}
JSON

echo "native iOS report: ${REPORT_FILE}"
exit "${EXIT_CODE}"
