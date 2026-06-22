#!/usr/bin/env bash
set -euo pipefail

RLN_VERSION="${RLN_VERSION:-0.6.0-beta.2}"
BASE_URL="https://github.com/UTEXO-Protocol/rgb-lightning-node/releases/download/v${RLN_VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IOS_DIR="${ROOT_DIR}/ios"
ZIP_PATH="${IOS_DIR}/rgb-lightning-node-swift.zip"
TMP_DIR="${IOS_DIR}/.tmp-rln-swift"
FRAMEWORK_DIR="${IOS_DIR}/RGBLightningNode.xcframework"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[rln] Skipping iOS framework download: host is not macOS."
  exit 0
fi

if [[ "${FORCE_RLN_DOWNLOAD:-0}" != "1" && -d "${FRAMEWORK_DIR}" && -f "${IOS_DIR}/RGBLightningNode.swift" ]]; then
  echo "[rln] iOS RLN artifact ${RLN_VERSION} already exists."
  exit 0
fi

command -v curl >/dev/null 2>&1 || {
  echo "[rln] curl is required to download the iOS RLN artifact." >&2
  exit 1
}

command -v unzip >/dev/null 2>&1 || {
  echo "[rln] unzip is required to extract the iOS RLN artifact." >&2
  exit 1
}

mkdir -p "${IOS_DIR}"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

URL="${BASE_URL}/rgb-lightning-node-swift-${RLN_VERSION}.zip"
echo "[rln] Downloading ${URL}"
curl --fail --location --progress-bar "${URL}" --output "${ZIP_PATH}"

echo "[rln] Extracting iOS RLN artifact"
unzip -q -o "${ZIP_PATH}" -d "${TMP_DIR}"
rm -f "${ZIP_PATH}"

SWIFT_DIR="${TMP_DIR}/swift"
if [[ ! -d "${SWIFT_DIR}/RGBLightningNode.xcframework" ]]; then
  echo "[rln] RGBLightningNode.xcframework was not found inside the release zip." >&2
  rm -rf "${TMP_DIR}"
  exit 1
fi

rm -rf "${FRAMEWORK_DIR}"
cp -R "${SWIFT_DIR}/RGBLightningNode.xcframework" "${FRAMEWORK_DIR}"

for file in RGBLightningNode.swift RGBLightningNodeFFI.h RGBLightningNodeFFI.modulemap; do
  if [[ -f "${SWIFT_DIR}/${file}" ]]; then
    cp "${SWIFT_DIR}/${file}" "${IOS_DIR}/${file}"
  else
    echo "[rln] ${file} was not found inside the release zip." >&2
    rm -rf "${TMP_DIR}"
    exit 1
  fi
done

rm -rf "${TMP_DIR}"
echo "[rln] iOS RLN artifact ${RLN_VERSION} is ready."

if [[ "${SKIP_RLN_VERIFY:-0}" != "1" && -x "${ROOT_DIR}/tool/verify_native_artifacts.sh" ]]; then
  "${ROOT_DIR}/tool/verify_native_artifacts.sh" --ios-only
fi
