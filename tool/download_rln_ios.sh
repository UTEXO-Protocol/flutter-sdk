#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=tool/release_baseline.sh
source "${SCRIPT_DIR}/release_baseline.sh"

IOS_DIR="${ROOT_DIR}/ios"
RLN_VERSION="$(release_baseline_value rln.version)"
ARCHIVE_URL="$(release_baseline_value rln.ios.archiveUrl)"
ARCHIVE_SHA256="$(release_baseline_value rln.ios.archiveSha256)"
ARCHIVE_SIZE="$(release_baseline_value rln.ios.archiveSizeBytes)"
CACHE_DIR="${RLN_CACHE_DIR:-${HOME}/.cache/rgb-sdk-flutter/rln-ios/${RLN_VERSION}}"
CACHE_ARCHIVE="${CACHE_DIR}/rgb-lightning-node-swift-${RLN_VERSION}.zip"

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[rln] $1 is required." >&2
    exit 1
  }
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

verify_file() {
  local expected_sha="$1"
  local file="$2"
  [[ -f "${file}" ]] || {
    echo "[rln] Missing artifact file: ${file}" >&2
    return 1
  }
  local actual_sha
  actual_sha="$(sha256_file "${file}")"
  [[ "${actual_sha}" == "${expected_sha}" ]] || {
    echo "[rln] Checksum mismatch for ${file}" >&2
    echo "[rln] Expected: ${expected_sha}" >&2
    echo "[rln] Actual:   ${actual_sha}" >&2
    return 1
  }
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[rln] Skipping iOS artifact installation: host is not macOS."
  exit 0
fi

require_tool awk
require_tool curl
require_tool shasum
require_tool unzip

if [[ "${FORCE_RLN_DOWNLOAD:-0}" != "1" ]] &&
  "${SCRIPT_DIR}/verify_native_artifacts.sh" --ios-only >/dev/null 2>&1; then
  echo "[rln] Verified iOS RLN artifact ${RLN_VERSION} already installed."
  exit 0
fi

mkdir -p "${IOS_DIR}"
LOCK_DIR="${IOS_DIR}/.rln-install.lock"
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  echo "[rln] Another artifact installation is active: ${LOCK_DIR}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${IOS_DIR}/.rln-install.XXXXXX")"
ARCHIVE_PATH="${TMP_DIR}/rln-ios.zip"
cleanup() {
  rm -rf "${TMP_DIR}"
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

if [[ -n "${RLN_ARCHIVE_PATH:-}" ]]; then
  [[ -f "${RLN_ARCHIVE_PATH}" ]] || {
    echo "[rln] RLN_ARCHIVE_PATH does not exist: ${RLN_ARCHIVE_PATH}" >&2
    exit 1
  }
  cp "${RLN_ARCHIVE_PATH}" "${ARCHIVE_PATH}"
elif [[ -f "${CACHE_ARCHIVE}" ]]; then
  echo "[rln] Using cached iOS RLN archive ${CACHE_ARCHIVE}"
  cp "${CACHE_ARCHIVE}" "${ARCHIVE_PATH}"
elif [[ "${RLN_OFFLINE:-0}" == "1" ]]; then
  echo "[rln] iOS RLN archive is not installed and offline mode is enabled." >&2
  echo "[rln] Set RLN_ARCHIVE_PATH or pre-populate ${CACHE_ARCHIVE}." >&2
  exit 1
else
  echo "[rln] Downloading ${ARCHIVE_URL}"
  curl \
    --fail \
    --location \
    --show-error \
    --retry 3 \
    --connect-timeout 15 \
    --max-time 600 \
    "${ARCHIVE_URL}" \
    --output "${ARCHIVE_PATH}"
fi

ACTUAL_SIZE="$(wc -c <"${ARCHIVE_PATH}" | tr -d '[:space:]')"
if [[ "${ACTUAL_SIZE}" != "${ARCHIVE_SIZE}" ]]; then
  echo "[rln] Archive size mismatch." >&2
  echo "[rln] Expected: ${ARCHIVE_SIZE}" >&2
  echo "[rln] Actual:   ${ACTUAL_SIZE}" >&2
  exit 1
fi
verify_file "${ARCHIVE_SHA256}" "${ARCHIVE_PATH}"

if [[ -z "${RLN_ARCHIVE_PATH:-}" && "${CACHE_ARCHIVE}" != "${ARCHIVE_PATH}" ]]; then
  mkdir -p "${CACHE_DIR}"
  CACHE_TMP="${CACHE_ARCHIVE}.tmp.$$"
  cp "${ARCHIVE_PATH}" "${CACHE_TMP}"
  mv "${CACHE_TMP}" "${CACHE_ARCHIVE}"
fi

EXTRACT_DIR="${TMP_DIR}/extracted"
mkdir -p "${EXTRACT_DIR}"
unzip -q "${ARCHIVE_PATH}" -d "${EXTRACT_DIR}"
SWIFT_DIR="${EXTRACT_DIR}/swift"
[[ -d "${SWIFT_DIR}" ]] || {
  echo "[rln] Archive does not contain swift/." >&2
  exit 1
}

while IFS=$'\t' read -r expected_sha installed_path; do
  relative_path="${installed_path#ios/}"
  verify_file "${expected_sha}" "${SWIFT_DIR}/${relative_path}"
done < <(release_baseline_ios_files)

for entry in \
  RGBLightningNode.xcframework \
  RGBLightningNode.swift \
  RGBLightningNodeFFI.h \
  RGBLightningNodeFFI.modulemap; do
  rm -rf "${IOS_DIR:?}/${entry}"
  cp -R "${SWIFT_DIR}/${entry}" "${IOS_DIR}/${entry}"
done

"${SCRIPT_DIR}/verify_native_artifacts.sh" --ios-only
echo "[rln] Installed and verified iOS RLN artifact ${RLN_VERSION}."
