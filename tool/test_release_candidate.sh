#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/release}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"

mkdir -p "${REPORT_DIR}"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
COMMIT="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
REPORT_FILE="${REPORT_DIR}/release-candidate-${COMMIT}.json"
LOG_FILE="${REPORT_DIR}/release-candidate-${COMMIT}.log"

STEP_NAMES=()
STEP_CODES=()
STEP_DURATIONS=()
FAILED=0

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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

  if [[ "${code}" -ne 0 ]]; then
    FAILED=1
    echo "!! ${name} failed with exit code ${code}"
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

  {
    echo "{"
    echo "  \"suite\": \"release-candidate\","
    echo "  \"status\": \"${status}\","
    echo "  \"commit\": \"$(json_escape "${COMMIT}")\","
    echo "  \"startedAt\": \"${STARTED_AT}\","
    echo "  \"finishedAt\": \"${finished_at}\","
    echo "  \"logPath\": \"$(json_escape "${LOG_FILE}")\","
    echo "  \"steps\": ["
    for index in "${!STEP_NAMES[@]}"; do
      local comma=","
      if [[ "${index}" -eq $((${#STEP_NAMES[@]} - 1)) ]]; then
        comma=""
      fi
      echo "    {\"name\": \"$(json_escape "${STEP_NAMES[${index}]}")\", \"exitCode\": ${STEP_CODES[${index}]}, \"durationSeconds\": ${STEP_DURATIONS[${index}]}}${comma}"
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
  run_step "format check" "${DART_BIN}" format --set-exit-if-changed .
  run_step "test matrix validation" "${DART_BIN}" run tool/validate_test_matrix.dart
  run_step "RN dev source parity validation" "${DART_BIN}" run tool/validate_rn_parity.dart
  run_step "native artifact checksum verification" ./tool/verify_native_artifacts.sh --ios-only
  run_step "pigeon drift check" bash -lc "'${REPO_DIR}/tool/generate_pigeon.sh' && '${DART_BIN}' format '${REPO_DIR}/lib/src/pigeon/rln_api.g.dart' && git -C '${REPO_DIR}' diff --exit-code -- lib/src/pigeon/rln_api.g.dart android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt ios/Classes/RlnApi.g.swift"
  run_step "package analyze" "${FLUTTER_BIN}" analyze
  run_step "package tests" "${FLUTTER_BIN}" test
  run_step "example widget tests" bash -lc "cd '${REPO_DIR}/example' && '${FLUTTER_BIN}' test test"
  run_step "native Android JVM bridge tests" bash -lc "REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_native_android.sh'"

  if [[ -n "${IOS_DEVICE:-}" ]]; then
    run_step "native iOS XCTest bridge tests" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_native_ios.sh'"
  else
    echo "Skipping native iOS XCTest bridge tests because IOS_DEVICE is unset."
  fi

  if [[ "${RUN_PLATFORM:-0}" == "1" ]]; then
    if [[ -n "${IOS_DEVICE:-}" ]]; then
      run_step "iOS unfunded regtest smoke" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_unfunded.sh'"
      run_step "iOS funded regtest smoke" bash -lc "DEVICE='${IOS_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_funded.sh'"
    else
      echo "Skipping iOS platform tests because IOS_DEVICE is unset."
    fi

    if [[ -n "${ANDROID_DEVICE:-}" ]]; then
      run_step "Android unfunded regtest smoke" bash -lc "DEVICE='${ANDROID_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_unfunded.sh'"
      run_step "Android funded regtest smoke" bash -lc "DEVICE='${ANDROID_DEVICE}' REPORT_DIR='${REPORT_DIR}' '${REPO_DIR}/tool/test_platform_funded.sh'"
    else
      echo "Skipping Android platform tests because ANDROID_DEVICE is unset."
    fi
  else
    echo
    echo "Platform tests are local release gates. Run with RUN_PLATFORM=1 IOS_DEVICE=<id> ANDROID_DEVICE=<id> when devices are available."
  fi

  write_report
  if [[ "${FAILED}" -ne 0 ]]; then
    exit 1
  fi
}

main "$@" 2>&1 | tee "${LOG_FILE}"
