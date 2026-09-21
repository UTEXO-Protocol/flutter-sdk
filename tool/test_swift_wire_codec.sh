#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rgb-wire-codec.XXXXXX")"
trap 'rm -rf "${WORK_DIR}"' EXIT
swiftc -warnings-as-errors \
  "${REPO_DIR}/ios/Classes/RlnWireCodec.swift" \
  "${REPO_DIR}/test/native/wire_codec_main.swift" \
  -o "${WORK_DIR}/wire-codec-test"
"${WORK_DIR}/wire-codec-test"
