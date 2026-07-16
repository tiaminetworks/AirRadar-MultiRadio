#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ ! -d "${AIRRADAR_SOURCE:-${ROOT}/src/airradar}" ]] ||
   [[ ! -d "${LOCALIZATION_SOURCE:-${ROOT}/src/airradar-localization}" ]] ||
   [[ ! -d "${ADSB2DD_SOURCE:-${ROOT}/src/adsb2dd}" ]]; then
  echo "Missing source checkouts; running bootstrap first."
  "${ROOT}/script/bootstrap_sources.bash"
else
  "${ROOT}/script/prepare_web_roots.bash"
fi

python3 script/validate.py

if docker compose version >/dev/null 2>&1; then
  docker compose --profile airradar --profile localization --profile adsb build
else
  docker-compose --profile airradar --profile localization --profile adsb build
fi
