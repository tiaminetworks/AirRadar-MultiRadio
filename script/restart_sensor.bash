#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

sensor="${1:-}"
target="${2:-all}"

case "${sensor}" in
  sensor1|sensor2|sensor3) ;;
  *)
    echo "Usage: $0 sensor1|sensor2|sensor3 [runtime|api|web|all]" >&2
    exit 2
    ;;
esac

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --profile airradar "$@"
  else
    docker-compose --profile airradar "$@"
  fi
}

restart_web() {
  "${ROOT}/script/prepare_web_roots.bash"
  compose up -d --force-recreate --no-deps "${sensor}_web"
}

case "${target}" in
  runtime)
    compose restart "${sensor}"
    ;;
  api)
    compose restart "${sensor}_api"
    ;;
  web)
    restart_web
    ;;
  all)
    compose restart "${sensor}_api"
    restart_web
    compose restart "${sensor}"
    ;;
  *)
    echo "Unknown target '${target}'. Use runtime, api, web, or all." >&2
    exit 2
    ;;
esac

echo "Restarted ${sensor} ${target}."
