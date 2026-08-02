#!/usr/bin/env bash

if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "[baseline] ROOT_DIR must be set before sourcing release_baseline.sh" >&2
  return 1
fi

RELEASE_BASELINE_FILE="${ROOT_DIR}/tool/release_baseline.json"

release_baseline_require() {
  command -v ruby >/dev/null 2>&1 || {
    echo "[baseline] ruby is required to read ${RELEASE_BASELINE_FILE}." >&2
    return 1
  }
  [[ -f "${RELEASE_BASELINE_FILE}" ]] || {
    echo "[baseline] Missing ${RELEASE_BASELINE_FILE}." >&2
    return 1
  }
}

release_baseline_value() {
  local path="$1"
  ruby -rjson -e '
    value = JSON.parse(File.read(ARGV.fetch(0)))
    ARGV.fetch(1).split(".").each { |key| value = value.fetch(key) }
    abort("baseline value must be scalar: #{ARGV.fetch(1)}") if value.is_a?(Hash) || value.is_a?(Array)
    print(value)
  ' "${RELEASE_BASELINE_FILE}" "${path}"
}

release_baseline_ios_files() {
  ruby -rjson -e '
    files = JSON.parse(File.read(ARGV.fetch(0))).fetch("rln").fetch("ios").fetch("installedFiles")
    files.sort.each { |path, sha| puts("#{sha}\t#{path}") }
  ' "${RELEASE_BASELINE_FILE}"
}

release_baseline_array() {
  local path="$1"
  ruby -rjson -e '
    value = JSON.parse(File.read(ARGV.fetch(0)))
    ARGV.fetch(1).split(".").each { |key| value = value.fetch(key) }
    abort("baseline value must be an array: #{ARGV.fetch(1)}") unless value.is_a?(Array)
    value.each { |item| abort("baseline array item must be scalar") if item.is_a?(Hash) || item.is_a?(Array) }
    puts(value)
  ' "${RELEASE_BASELINE_FILE}" "${path}"
}

release_baseline_require
