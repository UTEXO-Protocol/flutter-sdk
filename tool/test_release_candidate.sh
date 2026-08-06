#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/regtest/config.sh"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/release}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"

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
REPORT_FILE="${REPORT_DIR}/release-candidate-${RUN_ID}-${SHORT_COMMIT}.json"
LOG_FILE="${REPORT_DIR}/release-candidate-${RUN_ID}-${SHORT_COMMIT}.log"

STEP_NAMES=()
STEP_CODES=()
STEP_DURATIONS=()
STEP_NOTES=()
FAILED=0
RELEASE_MIN_FREE_KB="${RELEASE_MIN_FREE_KB:-10485760}"

baseline_value() {
  local dotted_path="$1"
  python3 - "${REPO_DIR}/tool/release_baseline.json" "${dotted_path}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)

for segment in sys.argv[2].split("."):
    value = value[segment]

print(value)
PY
}

BASELINE_RN_REPOSITORY="$(baseline_value reactNative.repository)"
BASELINE_RN_COMMIT="$(baseline_value reactNative.commit)"
BASELINE_RN_VERSION="$(baseline_value reactNative.version)"
BASELINE_CORE_VERSION="$(baseline_value core.version)"
BASELINE_RLN_VERSION="$(baseline_value rln.version)"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

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

run_step() {
  local name="$1"
  shift
  local start
  local finish
  local code

  echo
  echo "==> ${name}"
  start="$(date +%s)"
  set +e
  "$@"
  code="$?"
  set -e
  finish="$(date +%s)"

  STEP_NAMES+=("${name}")
  STEP_CODES+=("${code}")
  STEP_DURATIONS+=("$((finish - start))")
  STEP_NOTES+=("")

  if [[ "${code}" -ne 0 ]]; then
    FAILED=1
    echo "!! ${name} failed with exit code ${code}"
  fi
}

mark_required_skip() {
  local name="$1"
  local reason="$2"

  echo "!! ${name} skipped: ${reason}"
  STEP_NAMES+=("${name}")
  STEP_CODES+=(125)
  STEP_DURATIONS+=(0)
  STEP_NOTES+=("required gate skipped: ${reason}")
  if [[ "${ALLOW_SKIPPED_RELEASE_GATES:-0}" != "1" ]]; then
    FAILED=1
  fi
}

ensure_ios_simulator_visible() {
  local device="$1"

  xcrun simctl boot "${device}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${device}" -b >/dev/null 2>&1 || true
  open -a Simulator --args -CurrentDeviceUDID "${device}" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5 6; do
    if "${FLUTTER_BIN}" devices 2>/dev/null | grep -F "${device}" >/dev/null; then
      return 0
    fi
    sleep 2
  done

  "${FLUTTER_BIN}" devices
  return 1
}

ensure_android_device_visible() {
  local requested_device="$1"
  local android_home="${ANDROID_HOME:-${HOME}/Library/Android/sdk}"
  local adb_bin="${ADB_BIN:-${android_home}/platform-tools/adb}"
  local emulator_bin="${ANDROID_EMULATOR_BIN:-${android_home}/emulator/emulator}"
  local serial=""
  local booted=""
  local device_list=""

  if [[ -n "${requested_device}" ]] &&
    "${adb_bin}" devices 2>/dev/null |
      grep -E "^${requested_device}[[:space:]]+device" >/dev/null; then
    ANDROID_DEVICE="${requested_device}"
    return 0
  fi

  if [[ -z "${ANDROID_EMULATOR:-}" ]]; then
    "${FLUTTER_BIN}" devices || true
    "${adb_bin}" devices -l || true
    return 1
  fi

  "${adb_bin}" start-server >/dev/null
  nohup "${emulator_bin}" \
    -avd "${ANDROID_EMULATOR}" \
    -no-window \
    -no-snapshot-load \
    -gpu swiftshader_indirect \
    -no-audio \
    -no-boot-anim \
    -netdelay none \
    -netspeed full \
    >"${REPORT_DIR}/android-emulator-${RUN_ID}-${SHORT_COMMIT}.log" 2>&1 &

  for _ in $(seq 1 180); do
    device_list="$("${adb_bin}" devices -l 2>/dev/null || true)"
    if [[ -n "${requested_device}" ]] &&
      grep -E "^${requested_device}[[:space:]]+device" <<<"${device_list}" >/dev/null; then
      serial="${requested_device}"
    else
      serial="$(awk '/^emulator-[0-9]+[[:space:]]+device/{print $1; exit}' <<<"${device_list}")"
    fi
    if [[ -n "${serial}" ]]; then
      booted="$("${adb_bin}" -s "${serial}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      if [[ "${booted}" == "1" ]]; then
        ANDROID_DEVICE="${serial}"
        "${adb_bin}" -s "${serial}" shell true >/dev/null
        return 0
      fi
    fi
    sleep 2
  done

  "${FLUTTER_BIN}" devices || true
  "${adb_bin}" devices -l || true
  return 1
}

ensure_release_disk_space() {
  local path="${1:-${REPO_DIR}}"
  local available_kb

  available_kb="$(df -Pk "${path}" | awk 'NR == 2 {print $4}')"
  if [[ -z "${available_kb}" || "${available_kb}" -lt "${RELEASE_MIN_FREE_KB}" ]]; then
    echo "Release runner requires at least ${RELEASE_MIN_FREE_KB} KiB free on ${path}; available: ${available_kb:-unknown} KiB." >&2
    echo "Clean generated Flutter/Xcode/Pub caches before collecting release-candidate evidence." >&2
    return 1
  fi
}

write_report() {
  local finished_at
  local status
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "${FAILED}" -eq 0 ]]; then
    status="passed"
  else
    status="failed"
  fi
  if [[ "${FAILED}" -eq 0 && "${WORKTREE_DIRTY}" == "false" ]]; then
    release_eligible="true"
  else
    release_eligible="false"
  fi
  local log_sha
  if [[ -f "${LOG_FILE}" ]]; then
    log_sha="$(sha256_file "${LOG_FILE}")"
  else
    log_sha=""
  fi

  {
    echo "{"
    echo "  \"schemaVersion\": 1,"
    echo "  \"suite\": \"release-candidate\","
    echo "  \"status\": \"${status}\","
    echo "  \"releaseEligible\": ${release_eligible},"
    echo "  \"evidenceId\": \"$(json_escape "rgb-sdk-flutter/release-candidate/${RUN_ID}/${FULL_COMMIT}/local")\","
    echo "  \"repository\": {\"commit\": \"$(json_escape "${FULL_COMMIT}")\", \"shortCommit\": \"$(json_escape "${SHORT_COMMIT}")\"},"
    echo "  \"workingTree\": {\"dirty\": ${WORKTREE_DIRTY}},"
    echo "  \"baseline\": {"
    echo "    \"file\": \"tool/release_baseline.json\","
    echo "    \"reactNative\": {\"repository\": \"$(json_escape "${BASELINE_RN_REPOSITORY}")\", \"ref\": \"refs/heads/dev\", \"commit\": \"$(json_escape "${BASELINE_RN_COMMIT}")\", \"version\": \"$(json_escape "${BASELINE_RN_VERSION}")\"},"
    echo "    \"core\": {\"version\": \"$(json_escape "${BASELINE_CORE_VERSION}")\"},"
    echo "    \"rln\": {\"version\": \"$(json_escape "${BASELINE_RLN_VERSION}")\"}"
    echo "  },"
    echo "  \"startedAt\": \"${STARTED_AT}\","
    echo "  \"finishedAt\": \"${finished_at}\","
    echo "  \"logPath\": \"$(json_escape "$(repo_label_path "${LOG_FILE}")")\","
    echo "  \"logSha256\": \"$(json_escape "${log_sha}")\","
    echo "  \"sanitization\": {\"pathPolicy\": \"repo-relative-labels\", \"secretScan\": \"release-package-validator\"},"
    echo "  \"steps\": ["
    for index in "${!STEP_NAMES[@]}"; do
      local comma=","
      if [[ "${index}" -eq $((${#STEP_NAMES[@]} - 1)) ]]; then
        comma=""
      fi
      echo "    {\"name\": \"$(json_escape "${STEP_NAMES[${index}]}")\", \"exitCode\": ${STEP_CODES[${index}]}, \"durationSeconds\": ${STEP_DURATIONS[${index}]}, \"note\": \"$(json_escape "${STEP_NOTES[${index}]}")\"}${comma}"
    done
    echo "  ]"
    echo "}"
  } >"${REPORT_FILE}"

  echo
  echo "release candidate report: ${REPORT_FILE}"
}

main() {
  cd "${REPO_DIR}"

  run_step "package dependency resolution" "${FLUTTER_BIN}" pub get
  run_step "example dependency resolution" bash -lc "cd '${REPO_DIR}/example' && '${FLUTTER_BIN}' pub get"
  run_step "format check" "${DART_BIN}" format --set-exit-if-changed lib test example/integration_test tool pigeons
  run_step "test matrix validation" "${DART_BIN}" run tool/validate_test_matrix.dart
  run_step "bridge behavior vector validation" "${DART_BIN}" run tool/validate_bridge_vectors.dart
  run_step "codebase hardening validation" "${DART_BIN}" run tool/validate_codebase_hardening.dart
  run_step "public API documentation validation" "${DART_BIN}" run tool/validate_public_api_docs.dart
  run_step "release language validation" "${DART_BIN}" run tool/validate_release_language.dart
  run_step "release governance validation" "${DART_BIN}" run tool/validate_release_governance.dart
  run_step "API and bridge snapshot validation" "${DART_BIN}" run tool/validate_api_snapshot.dart
  run_step "RN dev source parity validation" "${DART_BIN}" run tool/validate_rn_parity.dart
  run_step "release package validation" "${DART_BIN}" run tool/validate_release_package.dart
  run_step "native artifact checksum verification" ./tool/verify_native_artifacts.sh --require-android
  run_step "supply-chain provenance, SBOM, license, and ABI gate" "${DART_BIN}" run tool/validate_supply_chain.dart
  run_step "release disk-space preflight" ensure_release_disk_space "${REPO_DIR}"
  if [[ "${RUN_CONSUMER_MATRIX:-1}" == "1" ]]; then
    run_step "clean consumer install and archive matrix" bash -lc "REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_clean_consumer_matrix.sh'"
  else
    mark_required_skip "clean consumer install and archive matrix" "RUN_CONSUMER_MATRIX is not 1"
  fi
  run_step "pigeon drift check" bash -lc "before=\$(mktemp) && after=\$(mktemp) && git -C '${REPO_DIR}' diff -- pigeons/rln_api.dart lib/src/pigeon/rln_api.g.dart android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt ios/Classes/RlnApi.g.swift > \"\${before}\" && '${REPO_DIR}/tool/generate_pigeon.sh' && '${DART_BIN}' format '${REPO_DIR}/lib/src/pigeon/rln_api.g.dart' && git -C '${REPO_DIR}' diff -- pigeons/rln_api.dart lib/src/pigeon/rln_api.g.dart android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt ios/Classes/RlnApi.g.swift > \"\${after}\" && cmp -s \"\${before}\" \"\${after}\""
  run_step "package analyze" "${FLUTTER_BIN}" analyze
  run_step "package tests with Dart coverage" "${FLUTTER_BIN}" test --coverage
  run_step "Dart coverage policy validation" "${DART_BIN}" run tool/validate_coverage_policy.dart
  run_step "example widget tests" bash -lc "cd '${REPO_DIR}/example' && '${FLUTTER_BIN}' test test"
  run_step "native Android JVM bridge tests" bash -lc "REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_native_android.sh'"

  if [[ -n "${IOS_DEVICE:-}" ]]; then
    run_step "native iOS XCTest bridge tests" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_native_ios.sh'"
  else
    mark_required_skip "native iOS XCTest bridge tests" "IOS_DEVICE is unset"
  fi

  if [[ "${RUN_PLATFORM:-0}" == "1" ]]; then
    if [[ -n "${IOS_DEVICE:-}" ]]; then
      run_step "prepare iOS simulator for Flutter platform smokes" ensure_ios_simulator_visible "${IOS_DEVICE}"
      run_step "iOS unfunded regtest smoke" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_unfunded.sh'"
      run_step "iOS funded regtest smoke" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_funded.sh'"
      run_step "iOS external-signer process restart" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_external_signer_restart.sh'"
    else
      mark_required_skip "iOS platform regtest smokes" "RUN_PLATFORM=1 but IOS_DEVICE is unset"
      mark_required_skip "iOS external-signer process restart" "RUN_PLATFORM=1 but IOS_DEVICE is unset"
    fi

    if [[ -n "${ANDROID_DEVICE:-}" || -n "${ANDROID_EMULATOR:-}" ]]; then
      run_step "prepare Android device for Flutter platform smokes" ensure_android_device_visible "${ANDROID_DEVICE:-}"
      if [[ -n "${ANDROID_DEVICE:-}" ]]; then
        run_step "Android unfunded regtest smoke" bash -lc "DEVICE='${ANDROID_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_unfunded.sh'"
        run_step "Android funded regtest smoke" bash -lc "DEVICE='${ANDROID_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_funded.sh'"
        run_step "Android external-signer process restart" bash -lc "DEVICE='${ANDROID_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_external_signer_restart.sh'"
      else
        mark_required_skip "Android platform regtest smokes" "Android device preparation failed"
        mark_required_skip "Android external-signer process restart" "Android device preparation failed"
      fi
    else
      mark_required_skip "Android platform regtest smokes" "RUN_PLATFORM=1 but ANDROID_DEVICE is unset"
      mark_required_skip "Android external-signer process restart" "RUN_PLATFORM=1 but ANDROID_DEVICE is unset"
    fi
  else
    mark_required_skip "iOS funded/unfunded regtest smokes" "RUN_PLATFORM is not 1"
    mark_required_skip "Android funded/unfunded regtest smokes" "RUN_PLATFORM is not 1"
    mark_required_skip "iOS/Android external-signer process restart" "RUN_PLATFORM is not 1"
  fi

  write_report
  if [[ "${FAILED}" -ne 0 ]]; then
    exit 1
  fi
}

main "$@" 2>&1 | tee "${LOG_FILE}"
