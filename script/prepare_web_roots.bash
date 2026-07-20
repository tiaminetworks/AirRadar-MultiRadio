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
  mkdir -p "${out}"
  find "${out}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "${AIRRADAR_SOURCE}/html/." "${out}/"
  find "${out}" -type f -name '*.bak' -delete

  # AirRadar's static UI assumes localhost:3000. Each multi-radio sensor has
  # its own API port, so patch the generated web roots without touching source.
  find "${out}" -type f \( -name '*.html' -o -name '*.js' -o -name '*.css' \) \
    -exec perl -0pi -e "s/:3000/:${api_port}/g" {} +

  # In the single-node AirRadar UI, local browser sessions call the API port
  # directly. In MultiRadio, each sensor web container proxies /api/* and
  # /stash/* to the matching sensor API. Keep browser traffic on the same web
  # origin so long-running pages survive browser refreshes, SSH forwards,
  # Cloudflare tunnels, and API-port exposure differences.
  find "${out}" -type f \( -name '*.html' -o -name '*.js' \) \
    -exec perl -0pi -e "s/window\\.location\\.hostname/window.location.host/g; s/global\\.location\\.hostname/global.location.host/g; s/var isLocalHost = is_localhost\\(host\\);/var isLocalHost = false;/g; s@return '//' \\+ host \\+ \\(isLocalHost \\? ':${api_port}' : ''\\) \\+ path;@return path;@g; s@return '//' \\+ host \\+ \\(isLocalHost\\(host\\) \\? ':${api_port}' : ''\\) \\+ path;@return path;@g; s@return 'http://' \\+ global\\.location\\.host \\+ ':${api_port}' \\+ path;@return path;@g; s@return 'http://' \\+ window\\.location\\.host \\+ ':${api_port}' \\+ path;@return path;@g; s@return 'http://' \\+ replayHost \\+ ':${api_port}' \\+ path;@return path;@g; s@return 'http://' \\+ trajectoryHost \\+ ':${api_port}' \\+ path;@return path;@g; s/:${api_port}//g" {} +

  # Some AirRadar pages define small API helper functions with slightly
  # different local variable names. Force those helpers to use same-origin
  # relative URLs in the generated web roots so Logs/Settings/Performance/
  # Sessions cannot accidentally contact another sensor API or a blocked port.
  find "${out}" -type f \( -name '*.html' -o -name '*.js' \) ! -path '*/lib/*' \
    -exec perl -0pi -e "s@function (airradarApiUrl|logsApiUrl|replayApiUrl|trajectoryApiUrl|apiUrl)\\(path\\)\\s*\\{\\s*return [^;]+;\\s*\\}@function \$1(path) { return path; }@gs" {} +

  cat > "${out}/httpd-airradar-proxy.conf" <<EOF
ProxyPreserveHost On
ProxyTimeout 30
ProxyPass /api/ http://host.docker.internal:${api_port}/api/
ProxyPassReverse /api/ http://host.docker.internal:${api_port}/api/
ProxyPass /stash/ http://host.docker.internal:${api_port}/stash/
ProxyPassReverse /stash/ http://host.docker.internal:${api_port}/stash/
ProxyPass /maxhold/ http://host.docker.internal:${api_port}/maxhold/
ProxyPassReverse /maxhold/ http://host.docker.internal:${api_port}/maxhold/
EOF
}

prepare_one sensor1 3100
prepare_one sensor2 3200
prepare_one sensor3 3300

echo "Prepared patched AirRadar web roots in ${ROOT}/build/web"
