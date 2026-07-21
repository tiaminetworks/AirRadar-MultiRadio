#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT}/src"

AIRRADAR_REPO="${AIRRADAR_REPO:-https://github.com/tiaminetworks/AirRadar.git}"
LOCALIZATION_REPO="${LOCALIZATION_REPO:-https://github.com/tiaminetworks/AirRadar-Localization.git}"
ADSB2DD_REPO="${ADSB2DD_REPO:-https://github.com/30hours/adsb2dd.git}"

clone_or_update() {
  local repo="$1"
  local path="$2"
  if [[ -d "${path}/.git" ]]; then
    echo "Updating ${path}"
    git -C "${path}" pull --ff-only
  else
    echo "Cloning ${repo} -> ${path}"
    git clone "${repo}" "${path}"
  fi
}

mkdir -p "${SRC_DIR}"
clone_or_update "${AIRRADAR_REPO}" "${SRC_DIR}/airradar"
clone_or_update "${LOCALIZATION_REPO}" "${SRC_DIR}/airradar-localization"
clone_or_update "${ADSB2DD_REPO}" "${SRC_DIR}/adsb2dd"

"${ROOT}/script/apply_airradar_overlays.bash"
"${ROOT}/script/prepare_web_roots.bash"

echo
echo "Source checkout complete."
echo "AirRadar source: ${SRC_DIR}/airradar"
echo "Localization source: ${SRC_DIR}/airradar-localization"
echo "ADS-B delay-Doppler source: ${SRC_DIR}/adsb2dd"
