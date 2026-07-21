#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_HOST="${1:-}"
REMOTE_PATH="${2:-/opt/airradar-multiradio}"

cd "${ROOT}"

fail=0

warn() {
  echo "WARN: $*" >&2
}

check() {
  echo
  echo "== $* =="
}

mark_fail() {
  echo "ERROR: $*" >&2
  fail=1
}

short_commit() {
  git rev-parse --short "$1" 2>/dev/null || printf 'unavailable'
}

check "Git revision"
if git fetch origin main >/dev/null 2>&1; then
  :
else
  warn "Could not fetch origin/main; using local remote-tracking ref."
fi

head_commit="$(git rev-parse HEAD)"
origin_commit="$(git rev-parse origin/main 2>/dev/null || true)"
echo "local HEAD:  $(short_commit HEAD) ${head_commit}"
if [[ -n "${origin_commit}" ]]; then
  echo "origin/main: $(short_commit origin/main) ${origin_commit}"
  if [[ "${head_commit}" != "${origin_commit}" ]]; then
    mark_fail "local HEAD does not match origin/main"
  fi
else
  mark_fail "origin/main is not available"
fi

tracked_status="$(git status --short --untracked-files=no)"
if [[ -n "${tracked_status}" ]]; then
  echo "${tracked_status}"
  mark_fail "tracked working tree changes are present"
else
  echo "tracked working tree: clean"
fi

untracked_count="$(git status --short --untracked-files=all | awk '/^\\?\\?/ { count++ } END { print count + 0 }')"
echo "untracked files: ${untracked_count}"

check "Generated vendor assets"
if [[ ! -d src/airradar/html/lib ]]; then
  warn "src/airradar/html/lib is missing; run script/bootstrap_sources.bash first."
else
  for sensor in sensor1 sensor2 sensor3; do
    out="build/web/${sensor}"
    if [[ ! -d "${out}/lib" ]]; then
      mark_fail "${out}/lib is missing; run script/prepare_web_roots.bash"
      continue
    fi
    while IFS= read -r -d '' source_file; do
      rel="${source_file#src/airradar/html/}"
      generated_file="${out}/${rel}"
      if [[ ! -f "${generated_file}" ]]; then
        mark_fail "${sensor}: missing generated vendor asset ${rel}"
      elif ! cmp -s "${source_file}" "${generated_file}"; then
        mark_fail "${sensor}: generated vendor asset differs from source: ${rel}"
      fi
    done < <(find src/airradar/html/lib -type f -print0)
  done
  echo "vendor assets: checked source vs build/web/sensor{1,2,3}"
fi

check "Running web containers"
if command -v docker >/dev/null 2>&1; then
  if containers="$(docker ps --format '{{.Names}}' 2>/dev/null)"; then
    for sensor in sensor1 sensor2 sensor3; do
      container="airradar-mr-${sensor}-web"
      if grep -qx "${container}" <<<"${containers}"; then
        echo "${container}: running"
        if [[ -f src/airradar/html/lib/plotly-2.20.0.min.js ]]; then
          source_hash="$(sha256sum src/airradar/html/lib/plotly-2.20.0.min.js | awk '{print $1}')"
          container_hash="$(docker exec "${container}" sha256sum /usr/local/apache2/htdocs/lib/plotly-2.20.0.min.js 2>/dev/null | awk '{print $1}')"
          echo "${container}: plotly ${container_hash}"
          if [[ "${container_hash}" != "${source_hash}" ]]; then
            mark_fail "${container}: Plotly hash does not match source"
          fi
        fi
      else
        warn "${container}: not running"
      fi
    done
  else
    warn "docker is installed but not accessible; skipping container hash checks"
  fi
else
  warn "docker command is not available"
fi

check "Local HTTP smoke"
if command -v curl >/dev/null 2>&1; then
  for port in 49161 49162 49163; do
    if curl -fsS "http://127.0.0.1:${port}/display/maxhold/" >/dev/null 2>&1; then
      echo "web ${port}: display/maxhold ok"
    else
      warn "web ${port}: display/maxhold not reachable"
    fi
    if curl -fsS "http://127.0.0.1:${port}/stash/map" >/dev/null 2>&1; then
      echo "web ${port}: stash/map ok"
    else
      warn "web ${port}: stash/map not reachable"
    fi
  done
  if curl -fsS "http://127.0.0.1:${LOCALIZATION_PORT:-49256}/api/status" >/dev/null 2>&1; then
    echo "localization: api/status ok"
  else
    warn "localization: api/status not reachable"
  fi
fi

if [[ -n "${REMOTE_HOST}" ]]; then
  check "Remote deployment ${REMOTE_HOST}:${REMOTE_PATH}"
  ssh "${REMOTE_HOST}" "cd '${REMOTE_PATH}' && AIRRADAR_AUDIT_REMOTE_MODE=1 ./script/audit_consistency.bash"
fi

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "AirRadar Multi-radio consistency audit passed."
else
  echo "AirRadar Multi-radio consistency audit failed." >&2
fi
exit "${fail}"
