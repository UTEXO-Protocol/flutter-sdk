#!/usr/bin/env bash
set -euo pipefail

RLN_VERSION="${RLN_VERSION:-0.6.0-beta.2}"
IOS_ZIP_SHA256="6ce1c107650b1078f3b94c30dc5fd68740147f73c2d22bd831abd751b72fa827"
ANDROID_AAR_SHA256="94c343928bc3bdf7dcbd584d446ec9559e198909971bb40d91901b588400d8df"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHECKSUM_FILE="${ROOT_DIR}/tool/native_artifacts.sha256"

IOS_ONLY=false
for arg in "$@"; do
  case "${arg}" in
    --ios-only)
      IOS_ONLY=true
      ;;
    *)
      echo "[supply-chain] Unknown argument: ${arg}" >&2
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

check_sha() {
  local expected="$1"
  local file="$2"
  local actual

  if [[ ! -f "${file}" ]]; then
    echo "[supply-chain] Missing file: ${file}" >&2
    exit 1
  fi

  actual="$(sha256_file "${file}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "[supply-chain] Checksum mismatch for ${file}" >&2
    echo "[supply-chain] Expected: ${expected}" >&2
    echo "[supply-chain] Actual:   ${actual}" >&2
    exit 1
  fi
}

require_tool shasum
require_tool awk

echo "[supply-chain] Verifying iOS vendored RLN files"
while read -r expected relative_path; do
  [[ -z "${expected}" ]] && continue
  [[ "${expected}" == \#* ]] && continue
  check_sha "${expected}" "${ROOT_DIR}/${relative_path}"
done <"${CHECKSUM_FILE}"

if [[ "${IOS_ONLY}" == true ]]; then
  echo "[supply-chain] iOS artifact checks passed."
  exit 0
fi

AAR_BASE="${HOME}/.gradle/caches/modules-2/files-2.1/com.utexo/rgb-lightning-node-android/${RLN_VERSION}"
AAR_PATH=""
if [[ -d "${AAR_BASE}" ]]; then
  AAR_PATH="$(find "${AAR_BASE}" -type f -name "rgb-lightning-node-android-${RLN_VERSION}.aar" | sort | head -n 1 || true)"
fi

if [[ -n "${AAR_PATH}" ]]; then
  echo "[supply-chain] Verifying Android Maven RLN AAR"
  check_sha "${ANDROID_AAR_SHA256}" "${AAR_PATH}"
elif [[ "${REQUIRE_ANDROID_AAR:-0}" == "1" ]]; then
  echo "[supply-chain] Android AAR is required but was not found in Gradle cache." >&2
  echo "[supply-chain] Run an Android Gradle build or dependency resolution first." >&2
  exit 1
else
  echo "[supply-chain] Android AAR not found in Gradle cache; skipping optional check."
fi

if [[ "${VERIFY_REMOTE:-0}" == "1" ]]; then
  require_tool curl
  URL="https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/download/v${RLN_VERSION}/rgb-lightning-node-swift-${RLN_VERSION}.zip"
  TMP_FILE="$(mktemp)"
  cleanup() {
    rm -f "${TMP_FILE}"
  }
  trap cleanup EXIT

  echo "[supply-chain] Downloading and verifying upstream iOS zip"
  curl --fail --location --silent --show-error "${URL}" --output "${TMP_FILE}"
  check_sha "${IOS_ZIP_SHA256}" "${TMP_FILE}"
fi

echo "[supply-chain] Native artifact checks passed."
