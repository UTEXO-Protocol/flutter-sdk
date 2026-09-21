#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/evidence_shell.sh"
source "${SCRIPT_DIR}/regtest/config.sh"
REGTEST="${SCRIPT_DIR}/regtest/regtest.sh"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DEVICE="${DEVICE:-}"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/platform}"

die() {
  echo "error: $*" >&2
  exit 1
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

[[ -n "${DEVICE}" ]] || die "set DEVICE to a Flutter device id, for example DEVICE='iPhone 16 Pro' or DEVICE=emulator-5554"

mkdir -p "${REPORT_DIR}"

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
REPORT_FILE="${REPORT_DIR}/platform-unfunded-${DEVICE_LABEL}-${RUN_ID}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/platform-unfunded-${DEVICE_LABEL}-${RUN_ID}-${SHORT_COMMIT}.log"
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

TEST_ARGS=(
  test
  integration_test/plugin_integration_test.dart
  -d "${DEVICE}"
  --dart-define=RGB_SDK_FLUTTER_REGTEST=true
  "--dart-define=RGB_SDK_FLUTTER_BITCOIND_RPC_PORT=${BITCOIND_RPC_PORT}"
  "--dart-define=RGB_SDK_FLUTTER_ELECTRS_PORT=${ELECTRS_PORT}"
  "--dart-define=RGB_SDK_FLUTTER_RGB_PROXY_PORT=${RGB_PROXY_PORT}"
)

"${REGTEST}" start

set +e
(
  cd "${REPO_DIR}/example"
  "${FLUTTER_BIN}" "${TEST_ARGS[@]}"
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
  "suite": "platform-unfunded-regtest",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "releaseEligible": ${RELEASE_ELIGIBLE},
  "evidenceId": "$(json_escape "rgb-sdk-flutter/platform-unfunded-regtest/${RUN_ID}/${FULL_COMMIT}/${DEVICE_LABEL}")",
  "repository": {"commit": "$(json_escape "${FULL_COMMIT}")", "shortCommit": "$(json_escape "${SHORT_COMMIT}")"},
  "workingTree": {"dirty": ${WORKTREE_DIRTY}},
  "device": "$(json_escape "${DEVICE}")",
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "regtest": {
    "bitcoindRpcPort": ${BITCOIND_RPC_PORT},
    "electrsPort": ${ELECTRS_PORT},
    "rgbProxyPort": ${RGB_PROXY_PORT}
  },
  "logPath": "$(json_escape "$(repo_label_path "${LOG_FILE}")")",
  "logSha256": "$(json_escape "$(sha256_file "${LOG_FILE}")")",
  "sanitization": {"pathPolicy": "repo-relative-labels"}
}
JSON

echo "platform unfunded report: ${REPORT_FILE}"
finish_evidence "${REPORT_FILE}"
exit "${EXIT_CODE}"
