#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESTART_SMOKE="${SCRIPT_DIR}/regtest/flutter_external_signer_restart.sh"
DEVICE="${DEVICE:-}"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/platform}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"

[[ -n "${DEVICE}" ]] || {
  echo "error: set DEVICE to a Flutter device id." >&2
  exit 2
}

mkdir -p "${REPORT_DIR}"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
COMMIT="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
SHORT_COMMIT="${COMMIT:0:12}"
DIRTY=false
if [[ -n "$(git -C "${REPO_DIR}" status --porcelain 2>/dev/null)" ]]; then
  DIRTY=true
fi
DEVICE_SLUG="${DEVICE//[^A-Za-z0-9_.-]/_}"
REPORT_FILE="${REPORT_DIR}/external-signer-restart-${DEVICE_SLUG}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/external-signer-restart-${DEVICE_SLUG}-${SHORT_COMMIT}.log"

set +e
env DEVICE="${DEVICE}" RUN_ID="${RUN_ID}" "${RESTART_SMOKE}" 2>&1 |
  tee "${LOG_FILE}"
EXIT_CODE="${PIPESTATUS[0]}"
set -e

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  STATUS="passed"
else
  STATUS="failed"
fi

ruby -rjson -e '
  report = {
    "schemaVersion" => 1,
    "suite" => "external-signer-process-restart",
    "status" => ARGV.fetch(0),
    "exitCode" => Integer(ARGV.fetch(1)),
    "commit" => ARGV.fetch(2),
    "workingTreeDirty" => ARGV.fetch(3) == "true",
    "device" => ARGV.fetch(4),
    "runId" => ARGV.fetch(5),
    "startedAt" => ARGV.fetch(6),
    "finishedAt" => ARGV.fetch(7),
    "regtest" => {
      "bitcoindRpcPort" => Integer(ARGV.fetch(8)),
      "electrsPort" => Integer(ARGV.fetch(9)),
      "rgbProxyPort" => Integer(ARGV.fetch(10))
    },
    "logPath" => ARGV.fetch(11)
  }
  File.write(ARGV.fetch(12), JSON.pretty_generate(report) + "\n")
' \
  "${STATUS}" \
  "${EXIT_CODE}" \
  "${COMMIT}" \
  "${DIRTY}" \
  "${DEVICE}" \
  "${RUN_ID}" \
  "${STARTED_AT}" \
  "${FINISHED_AT}" \
  "${BITCOIND_RPC_PORT:-18444}" \
  "${ELECTRS_PORT:-50002}" \
  "${RGB_PROXY_PORT:-3003}" \
  "${LOG_FILE}" \
  "${REPORT_FILE}"

echo "external signer restart report: ${REPORT_FILE}"
exit "${EXIT_CODE}"
