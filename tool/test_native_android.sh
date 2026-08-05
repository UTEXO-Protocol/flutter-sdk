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
FULL_COMMIT="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
SHORT_COMMIT="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
RUN_ID="${RELEASE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
if [[ -n "$(git -C "${REPO_DIR}" status --short 2>/dev/null)" ]]; then
  WORKTREE_DIRTY="true"
else
  WORKTREE_DIRTY="false"
fi
REPORT_FILE="${REPORT_DIR}/native-android-${RUN_ID}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/native-android-${RUN_ID}-${SHORT_COMMIT}.log"

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
if [[ "${EXIT_CODE}" -eq 0 && "${WORKTREE_DIRTY}" == "false" ]]; then
  RELEASE_ELIGIBLE="true"
else
  RELEASE_ELIGIBLE="false"
fi

cat >"${REPORT_FILE}" <<JSON
{
  "schemaVersion": 1,
  "suite": "native-android-jvm",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "releaseEligible": ${RELEASE_ELIGIBLE},
  "evidenceId": "$(json_escape "rgb-sdk-flutter/native-android-jvm/${RUN_ID}/${FULL_COMMIT}/android-host")",
  "repository": {"commit": "$(json_escape "${FULL_COMMIT}")", "shortCommit": "$(json_escape "${SHORT_COMMIT}")"},
  "workingTree": {"dirty": ${WORKTREE_DIRTY}},
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "command": "$(json_escape "cd example/android && ./gradlew ${GRADLE_ARGS[*]}")",
  "logPath": "$(json_escape "$(repo_label_path "${LOG_FILE}")")",
  "logSha256": "$(json_escape "$(sha256_file "${LOG_FILE}")")",
  "sanitization": {"pathPolicy": "repo-relative-labels"}
}
JSON

echo "native Android report: ${REPORT_FILE}"
exit "${EXIT_CODE}"
