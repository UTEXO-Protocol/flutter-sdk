#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXAMPLE_DIR="${REPO_DIR}/example"
REGTEST="${SCRIPT_DIR}/regtest.sh"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
ADB_BIN="${ADB_BIN:-}"
DEVICE="${DEVICE:-}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
DEVICE_SEED_HEX="${DEVICE_SEED_HEX:-$(
  ruby -rdigest -e 'print Digest::SHA256.hexdigest(ARGV.fetch(0))' "${RUN_ID}"
)}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.utexo.rgbSdkFlutterExample}"
ANDROID_PACKAGE="${ANDROID_PACKAGE:-com.utexo.rgb_sdk_flutter_example}"
ANDROID_ACTIVITY="${ANDROID_ACTIVITY:-${ANDROID_PACKAGE}.MainActivity}"
RESULT_TIMEOUT_SEC="${RESULT_TIMEOUT_SEC:-900}"
RESULT_FILE_NAME="rgb-sdk-flutter-restart-result-${RUN_ID}.json"
COMMAND_FILE_NAME="rgb-sdk-flutter-host-command-${RUN_ID}.json"
TEST_TARGET="integration_test/external_signer_restart_test.dart"

if [[ -z "${ADB_BIN}" ]]; then
  if command -v adb >/dev/null 2>&1; then
    ADB_BIN="$(command -v adb)"
  elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/platform-tools/adb" ]]; then
    ADB_BIN="${ANDROID_HOME}/platform-tools/adb"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" &&
    -x "${ANDROID_SDK_ROOT}/platform-tools/adb" ]]; then
    ADB_BIN="${ANDROID_SDK_ROOT}/platform-tools/adb"
  elif [[ -x "${HOME}/Library/Android/sdk/platform-tools/adb" ]]; then
    ADB_BIN="${HOME}/Library/Android/sdk/platform-tools/adb"
  fi
fi

[[ -n "${DEVICE}" ]] || {
  echo "error: set DEVICE to a Flutter device id." >&2
  exit 2
}
[[ "${RUN_ID}" =~ ^[A-Za-z0-9_.-]+$ ]] || {
  echo "error: RUN_ID must contain only letters, digits, dot, dash, or underscore." >&2
  exit 2
}
[[ "${RESULT_TIMEOUT_SEC}" =~ ^[1-9][0-9]*$ ]] || {
  echo "error: RESULT_TIMEOUT_SEC must be a positive integer." >&2
  exit 2
}
[[ "${DEVICE_SEED_HEX}" =~ ^[0-9a-f]{64}$ ]] || {
  echo "error: DEVICE_SEED_HEX must be exactly 32 lowercase hexadecimal bytes." >&2
  exit 2
}

flutter_build_args() {
  printf '%s\n' \
    "--target=${TEST_TARGET}" \
    "--dart-define=RGB_SDK_FLUTTER_RESTART_PHASE=auto" \
    "--dart-define=RGB_SDK_FLUTTER_RESTART_RUN_ID=${RUN_ID}" \
    "--dart-define=RGB_SDK_FLUTTER_RESTART_DEVICE_SEED_HEX=${DEVICE_SEED_HEX}" \
    "--dart-define=RGB_SDK_FLUTTER_BITCOIND_RPC_PORT=${BITCOIND_RPC_PORT:-18444}" \
    "--dart-define=RGB_SDK_FLUTTER_ELECTRS_PORT=${ELECTRS_PORT:-50002}" \
    "--dart-define=RGB_SDK_FLUTTER_RGB_PROXY_PORT=${RGB_PROXY_PORT:-3003}"
}

detect_platform() {
  if command -v xcrun >/dev/null 2>&1 &&
    xcrun simctl list devices 2>/dev/null | grep -Fq "${DEVICE}"; then
    echo "ios"
    return
  fi
  if [[ -n "${ADB_BIN}" ]] &&
    [[ "$("${ADB_BIN}" -s "${DEVICE}" get-state 2>/dev/null)" == "device" ]]; then
    echo "android"
    return
  fi
  echo "error: DEVICE=${DEVICE} is not a booted iOS simulator or connected Android device." >&2
  return 2
}

parse_result() {
  ruby -rjson -e '
    result = JSON.parse(ARGV.fetch(0))
    abort("unexpected result schemaVersion") unless result["schemaVersion"] == 2
    abort("unexpected result runId") unless result["runId"] == ARGV.fetch(1)
    puts "#{result.fetch("phase")}|#{result.fetch("status")}"
  ' "$1" "${RUN_ID}"
}

parse_host_command() {
  ruby -rjson -e '
    command = JSON.parse(ARGV.fetch(0))
    abort("unexpected command schemaVersion") unless command["schemaVersion"] == 1
    abort("unexpected command runId") unless command["runId"] == ARGV.fetch(1)
    abort("unsupported host command") unless command["command"] == "fund"
    puts "#{command.fetch("address")}|#{command.fetch("amountBtc")}"
  ' "$1" "${RUN_ID}"
}

execute_host_command() {
  local command_json="$1"
  local parsed
  local address
  local amount
  parsed="$(parse_host_command "${command_json}")"
  IFS='|' read -r address amount <<<"${parsed}"
  echo "[restart] funding ${address} with ${amount} BTC"
  "${REGTEST}" sendtoaddress "${address}" "${amount}" >/dev/null
  "${REGTEST}" mine 6 >/dev/null
}

build_and_install_ios() {
  local build_args=()
  local app_path="${EXAMPLE_DIR}/build/ios/iphonesimulator/Runner.app"
  while IFS= read -r argument; do
    build_args+=("${argument}")
  done < <(flutter_build_args)

  if ! xcrun simctl list devices 2>/dev/null |
    grep -F "${DEVICE}" |
    grep -q "(Booted)"; then
    xcrun simctl boot "${DEVICE}"
  fi
  xcrun simctl bootstatus "${DEVICE}" -b

  (
    cd "${EXAMPLE_DIR}"
    "${FLUTTER_BIN}" build ios --simulator --debug "${build_args[@]}"
  )
  [[ -d "${app_path}" ]] || {
    echo "error: iOS restart-test app was not produced at ${app_path}." >&2
    return 1
  }
  if ! xcrun simctl uninstall "${DEVICE}" "${IOS_BUNDLE_ID}" >/dev/null 2>&1; then
    echo "[restart] no stale iOS restart-test app was installed"
  fi
  xcrun simctl install "${DEVICE}" "${app_path}"
  IOS_DATA_CONTAINER="$(
    xcrun simctl get_app_container "${DEVICE}" "${IOS_BUNDLE_ID}" data
  )"
}

launch_ios() {
  local launch_output
  launch_output="$(
    xcrun simctl launch \
      --terminate-running-process \
      "${DEVICE}" \
      "${IOS_BUNDLE_ID}"
  )"
  echo "[restart] launched iOS process: ${launch_output}"
}

process_ios_host_command() {
  local command_path="$1"
  if [[ ! -s "${command_path}" ]]; then
    return
  fi
  execute_host_command "$(cat "${command_path}")"
  rm -f "${command_path}"
}

wait_for_ios_phase() {
  local expected_phase="$1"
  local expected_status="$2"
  local result_path="${IOS_DATA_CONTAINER}/tmp/${RESULT_FILE_NAME}"
  local command_path="${IOS_DATA_CONTAINER}/tmp/${COMMAND_FILE_NAME}"
  local attempt
  local result_json
  local parsed
  local actual_phase
  local actual_status

  for ((attempt = 0; attempt < RESULT_TIMEOUT_SEC; attempt += 1)); do
    process_ios_host_command "${command_path}"
    if [[ -s "${result_path}" ]]; then
      result_json="$(cat "${result_path}")"
      parsed="$(parse_result "${result_json}")"
      IFS='|' read -r actual_phase actual_status <<<"${parsed}"
      if [[ "${actual_status}" == "failed" ]]; then
        echo "error: iOS ${actual_phase} process reported failure:" >&2
        echo "${result_json}" >&2
        return 1
      fi
      if [[ "${actual_phase}" == "${expected_phase}" &&
        "${actual_status}" == "${expected_status}" ]]; then
        echo "[restart] iOS ${expected_phase} result: ${result_json}"
        return
      fi
    fi
    sleep 1
  done

  echo "error: iOS ${expected_phase} process did not report ${expected_status} within ${RESULT_TIMEOUT_SEC}s." >&2
  xcrun simctl spawn "${DEVICE}" log show --last 5m \
    --style compact \
    --predicate "process == 'Runner'" >&2 || true
  return 1
}

run_ios_restart() {
  local original_container
  local relaunched_container
  build_and_install_ios
  original_container="${IOS_DATA_CONTAINER}"

  echo "[restart] phase=prepare runId=${RUN_ID} device=${DEVICE} platform=ios"
  launch_ios
  wait_for_ios_phase prepare prepared

  xcrun simctl terminate "${DEVICE}" "${IOS_BUNDLE_ID}"
  sleep 1
  echo "[restart] phase=verify runId=${RUN_ID} device=${DEVICE} platform=ios"
  launch_ios
  relaunched_container="$(
    xcrun simctl get_app_container "${DEVICE}" "${IOS_BUNDLE_ID}" data
  )"
  [[ "${relaunched_container}" == "${original_container}" ]] || {
    echo "error: iOS data container changed across process relaunch." >&2
    return 1
  }
  wait_for_ios_phase verify passed
}

build_and_install_android() {
  local build_args=()
  local apk_path="${EXAMPLE_DIR}/build/app/outputs/flutter-apk/app-debug.apk"
  while IFS= read -r argument; do
    build_args+=("${argument}")
  done < <(flutter_build_args)

  (
    cd "${EXAMPLE_DIR}"
    "${FLUTTER_BIN}" build apk --debug "${build_args[@]}"
  )
  [[ -f "${apk_path}" ]] || {
    echo "error: Android restart-test APK was not produced at ${apk_path}." >&2
    return 1
  }
  if ! "${ADB_BIN}" -s "${DEVICE}" uninstall "${ANDROID_PACKAGE}" >/dev/null 2>&1; then
    echo "[restart] no stale Android restart-test app was installed"
  fi
  "${ADB_BIN}" -s "${DEVICE}" install "${apk_path}" >/dev/null
  ANDROID_DATA_DIR="$(
    "${ADB_BIN}" -s "${DEVICE}" shell run-as "${ANDROID_PACKAGE}" pwd | tr -d '\r'
  )"
}

launch_android() {
  "${ADB_BIN}" -s "${DEVICE}" shell am start -W \
    -n "${ANDROID_PACKAGE}/${ANDROID_ACTIVITY}"
}

find_android_file() {
  local file_name="$1"
  "${ADB_BIN}" -s "${DEVICE}" shell run-as "${ANDROID_PACKAGE}" \
    find . -maxdepth 2 -type f -name "${file_name}" -print -quit \
    2>/dev/null | tr -d '\r'
}

read_android_file() {
  local file_name="$1"
  local relative_path
  relative_path="$(find_android_file "${file_name}")"
  if [[ -z "${relative_path}" ]]; then
    return 1
  fi
  "${ADB_BIN}" -s "${DEVICE}" shell run-as "${ANDROID_PACKAGE}" \
    cat "${relative_path}" 2>/dev/null | tr -d '\r'
}

remove_android_file() {
  local file_name="$1"
  local relative_path
  relative_path="$(find_android_file "${file_name}")"
  if [[ -n "${relative_path}" ]]; then
    "${ADB_BIN}" -s "${DEVICE}" shell run-as "${ANDROID_PACKAGE}" \
      rm -f "${relative_path}"
  fi
}

process_android_host_command() {
  local command_json
  command_json="$(read_android_file "${COMMAND_FILE_NAME}" || true)"
  if [[ -z "${command_json}" ]]; then
    return
  fi
  execute_host_command "${command_json}"
  remove_android_file "${COMMAND_FILE_NAME}"
}

wait_for_android_phase() {
  local expected_phase="$1"
  local expected_status="$2"
  local attempt
  local result_json
  local parsed
  local actual_phase
  local actual_status

  for ((attempt = 0; attempt < RESULT_TIMEOUT_SEC; attempt += 1)); do
    process_android_host_command
    result_json="$(read_android_file "${RESULT_FILE_NAME}" || true)"
    if [[ -n "${result_json}" ]]; then
      parsed="$(parse_result "${result_json}")"
      IFS='|' read -r actual_phase actual_status <<<"${parsed}"
      if [[ "${actual_status}" == "failed" ]]; then
        echo "error: Android ${actual_phase} process reported failure:" >&2
        echo "${result_json}" >&2
        return 1
      fi
      if [[ "${actual_phase}" == "${expected_phase}" &&
        "${actual_status}" == "${expected_status}" ]]; then
        echo "[restart] Android ${expected_phase} result: ${result_json}"
        return
      fi
    fi
    sleep 1
  done

  echo "error: Android ${expected_phase} process did not report ${expected_status} within ${RESULT_TIMEOUT_SEC}s." >&2
  "${ADB_BIN}" -s "${DEVICE}" logcat -d -t 1000 >&2 || true
  return 1
}

run_android_restart() {
  local original_data_dir
  local relaunched_data_dir
  build_and_install_android
  original_data_dir="${ANDROID_DATA_DIR}"

  echo "[restart] phase=prepare runId=${RUN_ID} device=${DEVICE} platform=android"
  launch_android
  wait_for_android_phase prepare prepared

  "${ADB_BIN}" -s "${DEVICE}" shell am force-stop "${ANDROID_PACKAGE}"
  sleep 1
  echo "[restart] phase=verify runId=${RUN_ID} device=${DEVICE} platform=android"
  launch_android
  relaunched_data_dir="$(
    "${ADB_BIN}" -s "${DEVICE}" shell run-as "${ANDROID_PACKAGE}" pwd | tr -d '\r'
  )"
  [[ "${relaunched_data_dir}" == "${original_data_dir}" ]] || {
    echo "error: Android data directory changed across process relaunch." >&2
    return 1
  }
  wait_for_android_phase verify passed
}

"${REGTEST}" start
PLATFORM="$(detect_platform)"
case "${PLATFORM}" in
  ios)
    run_ios_restart
    ;;
  android)
    run_android_restart
    ;;
  *)
    echo "error: unsupported platform ${PLATFORM}." >&2
    exit 2
    ;;
esac
