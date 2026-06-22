#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REGTEST="${SCRIPT_DIR}/regtest.sh"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DEVICE="${DEVICE:-}"

TEST_ARGS=(
  "test"
  "integration_test/plugin_integration_test.dart"
  "--dart-define=RGB_SDK_FLUTTER_REGTEST=true"
  "--dart-define=RGB_SDK_FLUTTER_FUNDED_REGTEST=true"
  "--dart-define=RGB_SDK_FLUTTER_BITCOIND_RPC_PORT=${BITCOIND_RPC_PORT:-18444}"
  "--dart-define=RGB_SDK_FLUTTER_ELECTRS_PORT=${ELECTRS_PORT:-50002}"
  "--dart-define=RGB_SDK_FLUTTER_RGB_PROXY_PORT=${RGB_PROXY_PORT:-3003}"
)

if [[ -n "${DEVICE}" ]]; then
  TEST_ARGS+=("-d" "${DEVICE}")
fi

"${REGTEST}" start

STATUS_FILE="$(mktemp)"
cleanup() {
  rm -f "${STATUS_FILE}"
}
trap cleanup EXIT

set +e
(
  cd "${REPO_DIR}/example"
  "${FLUTTER_BIN}" "${TEST_ARGS[@]}"
  echo "$?" > "${STATUS_FILE}"
) 2>&1 | while IFS= read -r line; do
  echo "${line}"

  if [[ "${line}" =~ RGB_SDK_FLUTTER_HOST[[:space:]]+FUND[[:space:]]+address=([^[:space:]]+)[[:space:]]+amount=([^[:space:]]+) ]]; then
    (
      "${REGTEST}" sendtoaddress "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" >/dev/null
      "${REGTEST}" mine 6 >/dev/null
    ) &
  elif [[ "${line}" =~ RGB_SDK_FLUTTER_HOST[[:space:]]+MINE[[:space:]]+blocks=([0-9]+) ]]; then
    "${REGTEST}" mine "${BASH_REMATCH[1]}" >/dev/null &
  fi
done
PIPE_STATUS=$?
set -e

if [[ -s "${STATUS_FILE}" ]]; then
  exit "$(cat "${STATUS_FILE}")"
fi

exit "${PIPE_STATUS}"
