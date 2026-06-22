#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/native}"
GRADLE_ARGS=(":rgb_sdk_flutter:testDebugUnitTest" "--no-daemon")

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

mkdir -p "${REPORT_DIR}"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
COMMIT="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
REPORT_FILE="${REPORT_DIR}/native-android-${COMMIT}.json"
LOG_FILE="${REPORT_DIR}/native-android-${COMMIT}.log"

set +e
(
  cd "${REPO_DIR}/example/android"
  ./gradlew "${GRADLE_ARGS[@]}"
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
  "suite": "native-android-jvm",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "commit": "$(json_escape "${COMMIT}")",
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "command": "$(json_escape "cd example/android && ./gradlew ${GRADLE_ARGS[*]}")",
  "logPath": "$(json_escape "${LOG_FILE}")"
}
JSON

echo "native Android report: ${REPORT_FILE}"
exit "${EXIT_CODE}"
