#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

python3 -m py_compile script/configure_b210s.py script/validate.py
python3 script/validate.py --allow-placeholders

compose_config="$(mktemp /tmp/airradar-multiradio-compose.XXXXXX.yml)"
trap 'rm -f "${compose_config}"' EXIT

if docker compose version >/dev/null 2>&1; then
  docker compose --profile airradar --profile localization --profile adsb config >"${compose_config}"
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose --profile airradar --profile localization --profile adsb config >"${compose_config}"
else
  echo "Docker Compose is not installed; skipping compose config validation." >&2
fi

echo "AirRadar Multi-radio tests passed."
