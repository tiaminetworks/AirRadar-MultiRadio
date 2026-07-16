#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

python3 -m py_compile script/configure_b210s.py script/validate.py
python3 script/validate.py --allow-placeholders

if docker compose version >/dev/null 2>&1; then
  docker compose --profile airradar --profile localization --profile adsb config >/tmp/airradar-multiradio-compose.yml
elif command -v docker-compose >/dev/null 2>&1; then
  docker-compose --profile airradar --profile localization --profile adsb config >/tmp/airradar-multiradio-compose.yml
else
  echo "Docker Compose is not installed; skipping compose config validation." >&2
fi

echo "AirRadar Multi-radio tests passed."
