#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"
REPORT_DIR="${REPORT_DIR:-${REPO_DIR}/build/test-reports/consumer-matrix}"
mkdir -p "${REPORT_DIR}"
REPORT_DIR="$(cd "${REPORT_DIR}" && pwd)"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)}"
WORK_DIR="${CONSUMER_WORK_DIR:-${REPO_DIR}/build/clean-consumer-matrix/${RUN_ID}}"
PACKAGE_DIR="${WORK_DIR}/package"
RUN_ARCHIVES="${RUN_CONSUMER_ARCHIVES:-1}"

mkdir -p "${REPORT_DIR}" "${PACKAGE_DIR}"

STEP_NAMES=()
STEP_CODES=()
STEP_DURATIONS=()
STEP_NOTES=()
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
  STEP_NOTES+=("")

  if [[ "${code}" -ne 0 ]]; then
    FAILED=1
    echo "!! ${name} failed with exit code ${code}"
  fi
}

write_report() {
  local status="passed"
  if [[ "${FAILED}" -ne 0 ]]; then
    status="failed"
  fi
  mkdir -p "${REPORT_DIR}"
  local report_file="${REPORT_DIR}/clean-consumer-matrix-${RUN_ID}.json"
  {
    echo "{"
    echo "  \"suite\": \"clean-consumer-matrix\","
    echo "  \"status\": \"${status}\","
    echo "  \"runId\": \"$(json_escape "${RUN_ID}")\","
    echo "  \"workDir\": \"$(json_escape "${WORK_DIR}")\","
    echo "  \"packageDir\": \"$(json_escape "${PACKAGE_DIR}")\","
    echo "  \"archivesEnabled\": \"$(json_escape "${RUN_ARCHIVES}")\","
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
  } >"${report_file}"
  echo
  echo "clean consumer matrix report: ${report_file}"
}

copy_candidate_snapshot() {
  cd "${REPO_DIR}"
  git ls-files -z --cached --modified --others --exclude-standard |
    while IFS= read -r -d '' path; do
      if [[ -f "${path}" ]]; then
        mkdir -p "${PACKAGE_DIR}/$(dirname "${path}")"
        cp -p "${path}" "${PACKAGE_DIR}/${path}"
      fi
    done
}

prepare_package_git_ref() {
  cd "${PACKAGE_DIR}"
  git init -q
  git config user.name "Clean Consumer Matrix"
  git config user.email "release-matrix@example.invalid"
  git add .
  git commit -q -m "candidate snapshot"
  git branch -M consumer-candidate
}

create_consumer() {
  local consumer_dir="$1"
  local dependency_yaml="$2"

  mkdir -p "${consumer_dir}"
  cd "${consumer_dir}"
  "${FLUTTER_BIN}" create --platforms android,ios --org com.utexo.consumer --project-name rgb_sdk_consumer .
  python3 - "${consumer_dir}/pubspec.yaml" "${dependency_yaml}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
dependency = sys.argv[2].replace("\\n", "\n")
text = path.read_text()
marker = "dependencies:\n"
replacement = f"dependencies:\n  rgb_sdk_flutter:\n{dependency}\n"
if marker not in text:
    raise SystemExit("dependencies section not found")
path.write_text(text.replace(marker, replacement, 1))
PY
cat >lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
  final version = RgbSdkFlutter.rlnVersion;
  final network = getNetworkDefaults('regtest')?.proxyEndpoint ?? 'missing';
    return MaterialApp(home: Text('$version $network'));
  }
}
DART
}

build_consumer() {
  local consumer_dir="$1"
  cd "${consumer_dir}"
  "${FLUTTER_BIN}" pub get
  "${FLUTTER_BIN}" analyze --no-fatal-warnings --no-fatal-infos
  if [[ "${RUN_ARCHIVES}" == "1" ]]; then
    "${FLUTTER_BIN}" build apk --release --target-platform android-arm64
    if [[ "$(uname -s)" == "Darwin" ]]; then
      "${FLUTTER_BIN}" build ios --release --no-codesign
      test -d "ios/.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNode.xcframework" ||
        {
          echo "iOS consumer did not prepare the RLN xcframework." >&2
          exit 1
        }
      test -f "ios/.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNodeFFI.h" ||
        {
          echo "iOS consumer did not prepare the RLN FFI header." >&2
          exit 1
        }
      (
        cd ios
        pod install --deployment --no-repo-update
      )
    fi
  fi
}

main() {
  trap write_report EXIT

  run_step "snapshot package from candidate files" copy_candidate_snapshot
  run_step "prepare local git dependency ref" prepare_package_git_ref
  run_step "package tarball content dry-run" bash -lc "cd '${PACKAGE_DIR}' && '${DART_BIN}' pub publish --dry-run"

  local path_consumer="${WORK_DIR}/consumer-path"
  local git_consumer="${WORK_DIR}/consumer-git"
  run_step "create path consumer" create_consumer "${path_consumer}" "    path: ${PACKAGE_DIR}"
  run_step "build path consumer archives" build_consumer "${path_consumer}"
  run_step "create git consumer" create_consumer "${git_consumer}" "    git:\n      url: file://${PACKAGE_DIR}\n      ref: consumer-candidate"
  run_step "build git consumer archives" build_consumer "${git_consumer}"

  if [[ "${FAILED}" -ne 0 ]]; then
    exit 1
  fi
}

main "$@"
