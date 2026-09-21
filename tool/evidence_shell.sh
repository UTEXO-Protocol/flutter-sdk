#!/usr/bin/env bash

# Run only from SDK-owned qualification scripts. Candidate snapshots are ignored
# build output; no credentials or host environment dump enter the report.
start_evidence() {
  EVIDENCE_SNAPSHOT="${1%.json}.candidate.json"
  export RELEASE_RUN_ID="${RUN_ID}"
  (
    cd "${REPO_DIR}"
    "${DART_BIN:-dart}" run tool/finalize_evidence.dart start "${EVIDENCE_SNAPSHOT}"
  )
}

finish_evidence() {
  (
    cd "${REPO_DIR}"
    EVIDENCE_LOG_PATH="${LOG_FILE}" "${DART_BIN:-dart}" run tool/finalize_evidence.dart finish "${EVIDENCE_SNAPSHOT}" "$1"
  )
}

begin_evidence_log() {
  LOG_PIPE_DIR="$(mktemp -d "${REPORT_DIR}/.evidence-log.XXXXXX")"
  mkfifo "${LOG_PIPE_DIR}/pipe"
  exec 3>&1 4>&2
  tee "${LOG_FILE}" <"${LOG_PIPE_DIR}/pipe" &
  TEE_PID=$!
  exec >"${LOG_PIPE_DIR}/pipe" 2>&1
}

end_evidence_log() {
  local tee_result=0
  exec 1>&3 2>&4
  wait "${TEE_PID}" || tee_result=$?
  rm -f "${LOG_PIPE_DIR}/pipe"
  rmdir "${LOG_PIPE_DIR}"
  return "${tee_result}"
}
