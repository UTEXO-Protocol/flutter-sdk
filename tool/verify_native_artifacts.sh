#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tool/release_baseline.sh
source "${SCRIPT_DIR}/release_baseline.sh"

IOS_ONLY=false
REQUIRE_ANDROID=false
IOS_ARCHIVE_PATH=""
ANDROID_AAR_PATH=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --ios-only)
      IOS_ONLY=true
      shift
      ;;
    --require-android)
      REQUIRE_ANDROID=true
      shift
      ;;
    --ios-archive)
      IOS_ARCHIVE_PATH="${2:-}"
      [[ -n "${IOS_ARCHIVE_PATH}" ]] || {
        echo "[supply-chain] --ios-archive requires a path." >&2
        exit 2
      }
      shift 2
      ;;
    --android-aar)
      ANDROID_AAR_PATH="${2:-}"
      [[ -n "${ANDROID_AAR_PATH}" ]] || {
        echo "[supply-chain] --android-aar requires a path." >&2
        exit 2
      }
      shift 2
      ;;
    *)
      echo "[supply-chain] Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[supply-chain] $1 is required." >&2
    exit 1
  }
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

check_file() {
  local expected_sha="$1"
  local file="$2"
  local expected_size="${3:-}"
  [[ -f "${file}" ]] || {
    echo "[supply-chain] Missing file: ${file}" >&2
    exit 1
  }
  if [[ -n "${expected_size}" ]]; then
    local actual_size
    actual_size="$(wc -c <"${file}" | tr -d '[:space:]')"
    if [[ "${actual_size}" != "${expected_size}" ]]; then
      echo "[supply-chain] Size mismatch for ${file}" >&2
      echo "[supply-chain] Expected: ${expected_size}" >&2
      echo "[supply-chain] Actual:   ${actual_size}" >&2
      exit 1
    fi
  fi
  local actual_sha
  actual_sha="$(sha256_file "${file}")"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    echo "[supply-chain] Checksum mismatch for ${file}" >&2
    echo "[supply-chain] Expected: ${expected_sha}" >&2
    echo "[supply-chain] Actual:   ${actual_sha}" >&2
    exit 1
  fi
}

require_tool awk
require_tool shasum

echo "[supply-chain] Verifying installed iOS RLN files"
while IFS=$'\t' read -r expected_sha relative_path; do
  check_file "${expected_sha}" "${ROOT_DIR}/${relative_path}"
done < <(release_baseline_ios_files)

if [[ "$(uname -s)" == "Darwin" ]]; then
  require_tool plutil
  IOS_INFO_PLIST="${ROOT_DIR}/ios/RGBLightningNode.xcframework/Info.plist"
  IOS_INFO_JSON="$(plutil -convert json -o - "${IOS_INFO_PLIST}")"
  IOS_DEVICE_ARCHS="$(
    ruby -rjson -e '
      JSON.parse(STDIN.read).fetch("AvailableLibraries")
        .select { |entry| entry["SupportedPlatformVariant"].nil? }
        .flat_map { |entry| entry.fetch("SupportedArchitectures") }
        .uniq.sort.each { |arch| puts(arch) }
    ' <<<"${IOS_INFO_JSON}"
  )"
  IOS_SIMULATOR_ARCHS="$(
    ruby -rjson -e '
      JSON.parse(STDIN.read).fetch("AvailableLibraries")
        .select { |entry| entry["SupportedPlatformVariant"] == "simulator" }
        .flat_map { |entry| entry.fetch("SupportedArchitectures") }
        .uniq.sort.each { |arch| puts(arch) }
    ' <<<"${IOS_INFO_JSON}"
  )"
  EXPECTED_IOS_DEVICE_ARCHS="$(
    release_baseline_array rln.ios.deviceArchitectures | sort
  )"
  EXPECTED_IOS_SIMULATOR_ARCHS="$(
    release_baseline_array rln.ios.simulatorArchitectures | sort
  )"
  [[ "${IOS_DEVICE_ARCHS}" == "${EXPECTED_IOS_DEVICE_ARCHS}" ]] || {
    echo "[supply-chain] iOS device architecture mismatch." >&2
    exit 1
  }
  [[ "${IOS_SIMULATOR_ARCHS}" == "${EXPECTED_IOS_SIMULATOR_ARCHS}" ]] || {
    echo "[supply-chain] iOS simulator architecture mismatch." >&2
    exit 1
  }
fi

if [[ -n "${IOS_ARCHIVE_PATH}" ]]; then
  echo "[supply-chain] Verifying iOS release archive"
  check_file \
    "$(release_baseline_value rln.ios.archiveSha256)" \
    "${IOS_ARCHIVE_PATH}" \
    "$(release_baseline_value rln.ios.archiveSizeBytes)"
fi

if [[ "${IOS_ONLY}" == true ]]; then
  echo "[supply-chain] iOS artifact checks passed."
  exit 0
fi

RLN_VERSION="$(release_baseline_value rln.version)"
ANDROID_SHA256="$(release_baseline_value rln.android.archiveSha256)"
ANDROID_SIZE="$(release_baseline_value rln.android.archiveSizeBytes)"

if [[ -n "${ANDROID_AAR_PATH}" ]]; then
  AAR_PATHS=("${ANDROID_AAR_PATH}")
else
  AAR_BASE="${HOME}/.gradle/caches/modules-2/files-2.1/com.utexo/rgb-lightning-node-android/${RLN_VERSION}"
  AAR_PATHS=()
  if [[ -d "${AAR_BASE}" ]]; then
    while IFS= read -r path; do
      AAR_PATHS+=("${path}")
    done < <(
      find "${AAR_BASE}" -type f -name "rgb-lightning-node-android-${RLN_VERSION}.aar" | sort
    )
  fi
fi

if [[ "${#AAR_PATHS[@]}" -eq 0 ]]; then
  if [[ "${REQUIRE_ANDROID}" == true ]]; then
    echo "[supply-chain] Required Android AAR was not found." >&2
    exit 1
  fi
  echo "[supply-chain] Android AAR not resolved; optional verification skipped."
else
  require_tool unzip
  for aar_path in "${AAR_PATHS[@]}"; do
    echo "[supply-chain] Verifying Android AAR: ${aar_path}"
    check_file "${ANDROID_SHA256}" "${aar_path}" "${ANDROID_SIZE}"
    ACTUAL_ANDROID_ABIS="$(
      unzip -Z1 "${aar_path}" |
        sed -n 's#^jni/\([^/]*\)/librgb_lightning_node\.so$#\1#p' |
        sort -u
    )"
    EXPECTED_ANDROID_ABIS="$(
      release_baseline_array rln.android.abis | sort
    )"
    [[ "${ACTUAL_ANDROID_ABIS}" == "${EXPECTED_ANDROID_ABIS}" ]] || {
      echo "[supply-chain] Android ABI mismatch for ${aar_path}." >&2
      exit 1
    }
  done
fi

echo "[supply-chain] Native artifact checks passed."
