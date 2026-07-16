#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if docker compose version >/dev/null 2>&1; then
  docker compose --profile airradar --profile localization --profile adsb ps
else
  docker-compose --profile airradar --profile localization --profile adsb ps
fi

echo
for port in 3100 3200 3300; do
  printf 'AirRadar API %s: ' "${port}"
  curl -fsS "http://127.0.0.1:${port}/api/timestamp" >/dev/null 2>&1 && echo "ok" || echo "not ready"
done

printf 'Localization API: '
curl -fsS "http://127.0.0.1:${LOCALIZATION_PORT:-49256}/api/status" >/dev/null 2>&1 && echo "ok" || echo "not ready"

printf 'Localization map Cesium assets: '
curl -fsS "http://127.0.0.1:${LOCALIZATION_PORT:-49256}/cesium/Build/Cesium/Cesium.js" >/dev/null 2>&1 && echo "ok" || echo "not ready"
