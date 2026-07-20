#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

"${ROOT}/script/prepare_web_roots.bash"
python3 script/validate.py

docker rm -f airradar-mr-sensor1-web airradar-mr-sensor2-web airradar-mr-sensor3-web >/dev/null 2>&1 || true

if docker compose version >/dev/null 2>&1; then
  docker compose --profile airradar --profile localization --profile adsb up -d
else
  docker-compose --profile airradar --profile localization --profile adsb up -d
fi

echo
echo "AirRadar Multi-radio started."
echo "Sensor 1 web:      http://localhost:${SENSOR1_WEB_PORT:-49161}/"
echo "Sensor 2 web:      http://localhost:${SENSOR2_WEB_PORT:-49162}/"
echo "Sensor 3 web:      http://localhost:${SENSOR3_WEB_PORT:-49163}/"
echo "Localization web:  http://localhost:${LOCALIZATION_PORT:-49256}/"
echo "tar1090:           http://localhost:${TAR1090_PORT:-8080}/"
