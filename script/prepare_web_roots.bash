#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIRRADAR_SOURCE="${AIRRADAR_SOURCE:-${ROOT}/src/airradar}"

if [[ ! -d "${AIRRADAR_SOURCE}/html" ]]; then
  echo "Missing AirRadar html source: ${AIRRADAR_SOURCE}/html" >&2
  echo "Run script/bootstrap_sources.bash or set AIRRADAR_SOURCE." >&2
  exit 1
fi

prepare_one() {
  local sensor="$1"
  local api_port="$2"
  local out="${ROOT}/build/web/${sensor}"
  rm -rf "${out}"
  mkdir -p "${out}"
  cp -a "${AIRRADAR_SOURCE}/html/." "${out}/"
  find "${out}" -type f -name '*.bak' -delete

  # AirRadar's static UI assumes localhost:3000. Each multi-radio sensor has
  # its own API port, so patch the generated web roots without touching source.
  find "${out}" -type f \( -name '*.html' -o -name '*.js' -o -name '*.css' \) \
    -exec perl -0pi -e "s/:3000/:${api_port}/g" {} +
}

prepare_one sensor1 3100
prepare_one sensor2 3200
prepare_one sensor3 3300

echo "Prepared patched AirRadar web roots in ${ROOT}/build/web"
