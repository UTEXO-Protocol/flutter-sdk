#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/evidence_shell.sh"
source "${SCRIPT_DIR}/regtest/config.sh"
RESTART_SMOKE="${SCRIPT_DIR}/regtest/flutter_external_signer_restart.sh"
DEVICE="${DEVICE:-}"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/platform}"
RUN_ID="${RELEASE_RUN_ID:-${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}}"

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
REPORT_FILE="${REPORT_DIR}/external-signer-restart-${DEVICE_SLUG}-${RUN_ID}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/external-signer-restart-${DEVICE_SLUG}-${RUN_ID}-${SHORT_COMMIT}.log"
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
# Finalization alone can authorize a clean, complete report.
RELEASE_ELIGIBLE="false"

ruby -rjson -e '
  report = {
    "schemaVersion" => 1,
    "suite" => "external-signer-process-restart",
    "status" => ARGV.fetch(0),
    "exitCode" => Integer(ARGV.fetch(1)),
    "releaseEligible" => ARGV.fetch(14) == "true",
    "evidenceId" => "rgb-sdk-flutter/external-signer-process-restart/#{ARGV.fetch(5)}/#{ARGV.fetch(2)}/#{ARGV.fetch(4).gsub(/[^A-Za-z0-9_.-]/, "_")}",
    "repository" => {
      "commit" => ARGV.fetch(2),
      "shortCommit" => ARGV.fetch(2)[0, 12]
    },
    "workingTree" => {"dirty" => ARGV.fetch(3) == "true"},
    "device" => ARGV.fetch(4),
    "runId" => ARGV.fetch(5),
    "startedAt" => ARGV.fetch(6),
    "finishedAt" => ARGV.fetch(7),
    "regtest" => {
      "bitcoindRpcPort" => Integer(ARGV.fetch(8)),
      "electrsPort" => Integer(ARGV.fetch(9)),
      "rgbProxyPort" => Integer(ARGV.fetch(10))
    },
    "logPath" => ARGV.fetch(11),
    "logSha256" => ARGV.fetch(12),
    "sanitization" => {"pathPolicy" => "repo-relative-labels"}
  }
  File.write(ARGV.fetch(13), JSON.pretty_generate(report) + "\n")
' \
  "${STATUS}" \
  "${EXIT_CODE}" \
  "${COMMIT}" \
  "${DIRTY}" \
  "${DEVICE}" \
  "${RUN_ID}" \
  "${STARTED_AT}" \
  "${FINISHED_AT}" \
  "${BITCOIND_RPC_PORT}" \
  "${ELECTRS_PORT}" \
  "${RGB_PROXY_PORT}" \
  "$(repo_label_path "${LOG_FILE}")" \
  "$(sha256_file "${LOG_FILE}")" \
  "${REPORT_FILE}" \
  "${RELEASE_ELIGIBLE}"

echo "external signer restart report: ${REPORT_FILE}"
finish_evidence "${REPORT_FILE}"
exit "${EXIT_CODE}"
