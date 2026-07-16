#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if docker compose version >/dev/null 2>&1; then
  docker compose --profile airradar --profile localization --profile adsb down
else
  docker-compose --profile airradar --profile localization --profile adsb down
fi
