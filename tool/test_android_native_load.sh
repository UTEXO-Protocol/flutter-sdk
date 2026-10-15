#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_SDK_DIR="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${HOME}/Library/Android/sdk}}"
NDK_DIR="${ANDROID_NDK_HOME:-${ANDROID_SDK_DIR}/ndk/28.2.13676358}"
ADB_BIN="${ADB_BIN:-${ANDROID_SDK_DIR}/platform-tools/adb}"
DART_BIN="${DART_BIN:-dart}"
SERIAL=""
EXPECTED_AVD=""
LIBRARY=""
COMPILE_ONLY=false
REPORT_DIR="${REPORT_DIR:-${ROOT_DIR}/build/test-reports/native-load}"

die() { echo "[native-load] $*" >&2; exit 1; }
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --serial|--avd|--library|--ndk|--report-dir)
      [[ "$#" -ge 2 && -n "$2" ]] || die "$1 requires a value"
      case "$1" in
        --serial) SERIAL="$2" ;;
        --avd) EXPECTED_AVD="$2" ;;
        --library) LIBRARY="$2" ;;
        --ndk) NDK_DIR="$2" ;;
        --report-dir) REPORT_DIR="$2" ;;
      esac
      shift 2 ;;
    --compile-only) COMPILE_ONLY=true; shift ;;
    *) die "Unknown option: $1" ;;
  esac
done
[[ "$(uname -s)" == Darwin ]] || die "This runner currently requires the macOS NDK host toolchain."
CLANG="${NDK_DIR}/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android24-clang"
[[ -x "${CLANG}" ]] || die "NDK 28.2 arm64 compiler is missing: ${CLANG}"
mkdir -p "${REPORT_DIR}"
REPORT_DIR="$(cd "${REPORT_DIR}" && pwd)"
PROBE="${REPORT_DIR}/android_load_probe"
"${CLANG}" -std=c11 -Wall -Wextra -Werror -Wno-nullability-completeness \
  -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 \
  -I "${ROOT_DIR}/ios" "${ROOT_DIR}/test/native/android_load_probe.c" \
  -ldl -o "${PROBE}"
if [[ "${COMPILE_ONLY}" == true ]]; then
  echo "[native-load] Compiled ${PROBE}; no device was accessed."
  exit 0
fi
[[ "${SERIAL}" =~ ^emulator-[0-9]+$ ]] || die "Set --serial to the fresh owned emulator."
[[ "${EXPECTED_AVD}" =~ ^Aster_[A-Za-z0-9_]+$ ]] || die "Set --avd to a fresh Aster-owned AVD."
[[ -f "${LIBRARY}" && ! -L "${LIBRARY}" ]] || die "Set --library to the actual rebuilt arm64 library."
[[ -x "${ADB_BIN}" ]] || die "adb is missing."
ACTUAL_AVD="$("${ADB_BIN}" -s "${SERIAL}" emu avd name | tr -d '\r' | head -n 1)"
[[ "${ACTUAL_AVD}" == "${EXPECTED_AVD}" ]] || die "Emulator AVD identity does not match --avd."
PAGE_SIZE="$("${ADB_BIN}" -s "${SERIAL}" shell getconf PAGE_SIZE | tr -d '\r')"
[[ "${PAGE_SIZE}" == 16384 ]] || die "Owned guest is not running a 16 KiB kernel."
GUEST_ABI="$("${ADB_BIN}" -s "${SERIAL}" shell getprop ro.product.cpu.abi | tr -d '\r')"
[[ "${GUEST_ABI}" == arm64-v8a ]] || die "Owned guest is not arm64-v8a."
GUEST_API="$("${ADB_BIN}" -s "${SERIAL}" shell getprop ro.build.version.sdk | tr -d '\r')"
[[ "${GUEST_API}" =~ ^[0-9]+$ ]] || die "Owned guest API level is unavailable."
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
REPORT="${REPORT_DIR}/android-load-${RUN_ID}.json"
LOG="${REPORT_DIR}/android-load-${RUN_ID}.log"
ELF_REPORT="${REPORT_DIR}/android-load-${RUN_ID}-elf.json"
"${DART_BIN}" run "${ROOT_DIR}/tool/verify_android_elf.dart" \
  --elf "${LIBRARY}" --abi arm64-v8a --report "${ELF_REPORT}" > /dev/null

# These changes are restricted to the caller-named, identity-checked guest.
# A successful load must not be credited to Android's 4 KiB compatibility mode.
LINKER_MODE=false
if ((GUEST_API >= 37)); then
  LINKER_MODE=fatal
fi
"${ADB_BIN}" -s "${SERIAL}" shell setprop bionic.linker.16kb.app_compat.enabled "${LINKER_MODE}"
"${ADB_BIN}" -s "${SERIAL}" shell setprop pm.16kb.app_compat.disabled true
LINKER_COMPAT="$("${ADB_BIN}" -s "${SERIAL}" shell getprop bionic.linker.16kb.app_compat.enabled | tr -d '\r')"
PACKAGE_COMPAT="$("${ADB_BIN}" -s "${SERIAL}" shell getprop pm.16kb.app_compat.disabled | tr -d '\r')"
[[ "${LINKER_COMPAT}" == "${LINKER_MODE}" && "${PACKAGE_COMPAT}" == true ]] || die "Could not disable guest compatibility fallback."
REMOTE="/data/local/tmp/rgb-sdk-flutter-load-${RUN_ID}"
LIBRARY_SHA="$(shasum -a 256 "${LIBRARY}" | awk '{print $1}')"
PROBE_SHA="$(shasum -a 256 "${PROBE}" | awk '{print $1}')"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cleanup() {
  local result=$?
  trap - EXIT
  if ! "${ADB_BIN}" -s "${SERIAL}" shell rm -rf "${REMOTE}" >/dev/null 2>&1; then
    [[ "${result}" -ne 0 ]] || result=1
  fi
  ruby -rjson -e '
    status, started, serial, avd, lib_sha, probe_sha, log, elf, api, linker_mode = ARGV
    puts JSON.pretty_generate({schemaVersion: 1,
      suite: "android-native-load-16k", scope: "native-load-only-no-wallet-or-services",
      status: status == "0" ? "passed" : "failed", exitCode: status.to_i,
      releaseEligible: false, startedAt: started,
      finishedAt: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      device: {serial: serial, avd: avd, abi: "arm64-v8a", apiLevel: api.to_i, pageSize: 16384},
      compatibility: {linkerEnabled: false, linkerMode: linker_mode, packageDisabled: true},
      librarySha256: lib_sha, probeSha256: probe_sha,
      expectedContractVersion: 26, expectedHealthcheckChecksum: 28125,
      expectedHealthcheck: "rgb_lightning_node_uniffi_ready",
      apkZipAlignment: "not-checked-load-probe-is-not-an-APK",
      logPath: log, elfReportPath: elf})
  ' "${result}" "${STARTED_AT}" "${SERIAL}" "${EXPECTED_AVD}" \
    "${LIBRARY_SHA}" "${PROBE_SHA}" "${LOG}" "${ELF_REPORT}" "${GUEST_API}" "${LINKER_MODE}" > "${REPORT}" || result=1
  echo "[native-load] Report: ${REPORT}"
  exit "${result}"
}
trap cleanup EXIT
"${ADB_BIN}" -s "${SERIAL}" shell mkdir -m 700 "${REMOTE}"
"${ADB_BIN}" -s "${SERIAL}" push "${PROBE}" "${REMOTE}/probe" > /dev/null
"${ADB_BIN}" -s "${SERIAL}" push "${LIBRARY}" "${REMOTE}/librgb_lightning_node.so" > /dev/null
REMOTE_LIBRARY_SHA="$("${ADB_BIN}" -s "${SERIAL}" shell sha256sum "${REMOTE}/librgb_lightning_node.so" | awk '{print $1}')"
REMOTE_PROBE_SHA="$("${ADB_BIN}" -s "${SERIAL}" shell sha256sum "${REMOTE}/probe" | awk '{print $1}')"
[[ "${REMOTE_LIBRARY_SHA}" == "${LIBRARY_SHA}" && "${REMOTE_PROBE_SHA}" == "${PROBE_SHA}" ]] || die "Pushed native bytes do not match the recorded host digests."
"${ADB_BIN}" -s "${SERIAL}" shell chmod 700 "${REMOTE}/probe"
"${ADB_BIN}" -s "${SERIAL}" shell \
  "LD_LIBRARY_PATH=${REMOTE} ${REMOTE}/probe ${REMOTE}/librgb_lightning_node.so" 2>&1 | tee "${LOG}"
