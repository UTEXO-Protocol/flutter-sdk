#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FUNDED_SMOKE="${SCRIPT_DIR}/regtest/flutter_funded_smoke.sh"
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
REPORT_FILE="${REPORT_DIR}/platform-funded-${DEVICE_LABEL}-${RUN_ID}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/platform-funded-${DEVICE_LABEL}-${RUN_ID}-${SHORT_COMMIT}.log"

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
DEVICE="${DEVICE}" "${FUNDED_SMOKE}" 2>&1 | tee "${LOG_FILE}"
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
  "schemaVersion": 1,
  "suite": "platform-funded-regtest",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "releaseEligible": false,
  "evidenceId": "$(json_escape "rgb-sdk-flutter/platform-funded-regtest/${RUN_ID}/${FULL_COMMIT}/${DEVICE_LABEL}")",
  "repository": {"commit": "$(json_escape "${FULL_COMMIT}")", "shortCommit": "$(json_escape "${SHORT_COMMIT}")"},
  "workingTree": {"dirty": ${WORKTREE_DIRTY}},
  "device": "$(json_escape "${DEVICE}")",
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "regtest": {
    "bitcoindRpcPort": ${BITCOIND_RPC_PORT:-18444},
    "electrsPort": ${ELECTRS_PORT:-50002},
    "rgbProxyPort": ${RGB_PROXY_PORT:-3003}
  },
  "logPath": "$(json_escape "$(repo_label_path "${LOG_FILE}")")",
  "logSha256": "$(json_escape "$(sha256_file "${LOG_FILE}")")",
  "sanitization": {"pathPolicy": "repo-relative-labels"}
}
JSON

echo "platform funded report: ${REPORT_FILE}"
exit "${EXIT_CODE}"
