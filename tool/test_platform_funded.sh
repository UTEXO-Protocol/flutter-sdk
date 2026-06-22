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
COMMIT="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
REPORT_FILE="${REPORT_DIR}/platform-funded-${DEVICE//[^A-Za-z0-9_.-]/_}-${COMMIT}.json"
LOG_FILE="${REPORT_DIR}/platform-funded-${DEVICE//[^A-Za-z0-9_.-]/_}-${COMMIT}.log"

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
  "suite": "platform-funded-regtest",
  "status": "${STATUS}",
  "exitCode": ${EXIT_CODE},
  "commit": "$(json_escape "${COMMIT}")",
  "device": "$(json_escape "${DEVICE}")",
  "startedAt": "${STARTED_AT}",
  "finishedAt": "${FINISHED_AT}",
  "regtest": {
    "bitcoindRpcPort": ${BITCOIND_RPC_PORT:-18444},
    "electrsPort": ${ELECTRS_PORT:-50002},
    "rgbProxyPort": ${RGB_PROXY_PORT:-3003}
  },
  "logPath": "$(json_escape "${LOG_FILE}")"
}
JSON

echo "platform funded report: ${REPORT_FILE}"
exit "${EXIT_CODE}"
