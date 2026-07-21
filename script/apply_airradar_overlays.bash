#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIRRADAR_SOURCE="${AIRRADAR_SOURCE:-${ROOT}/src/airradar}"
PERFORMANCE_PATCH="${ROOT}/patches/airradar-lightweight-performance-categories.patch"
MAP_DISPLAY_PATCH="${ROOT}/patches/airradar-range-doppler-immediate-load.patch"
DISPLAY_PAGES_PATCH="${ROOT}/patches/airradar-display-pages-immediate-load.patch"

if [[ ! -d "${AIRRADAR_SOURCE}" ]]; then
  echo "Missing AirRadar source: ${AIRRADAR_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${AIRRADAR_SOURCE}/api/performance_evaluator.js" ]]; then
  echo "Missing AirRadar performance evaluator under ${AIRRADAR_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${AIRRADAR_SOURCE}/html/js/plot_map.js" ]]; then
  echo "Missing AirRadar range-Doppler plot script under ${AIRRADAR_SOURCE}" >&2
  exit 1
fi

apply_overlay() {
  local marker="$1"
  local target="$2"
  local patch="$3"
  local description="$4"

  if grep -q "${marker}" "${target}"; then
    echo "AirRadar overlay already present: ${description}"
    return
  fi

  if [[ ! -f "${patch}" ]]; then
    echo "Missing overlay patch: ${patch}" >&2
    exit 1
  fi

  if git -C "${AIRRADAR_SOURCE}" apply --check "${patch}"; then
    git -C "${AIRRADAR_SOURCE}" apply "${patch}"
    echo "Applied AirRadar overlay: ${description}"
  else
    echo "AirRadar overlay patch cannot apply cleanly to ${AIRRADAR_SOURCE}" >&2
    echo "Update ${patch} or update the AirRadar source manually before building." >&2
    exit 1
  fi
}

apply_overlay \
  "collectCategoryValuesLightweight" \
  "${AIRRADAR_SOURCE}/api/performance_evaluator.js" \
  "${PERFORMANCE_PATCH}" \
  "lightweight performance categories"

apply_overlay \
  "MAP_POLL_MS" \
  "${AIRRADAR_SOURCE}/html/js/plot_map.js" \
  "${MAP_DISPLAY_PATCH}" \
  "range-Doppler immediate load"

apply_overlay \
  "DISPLAY_TIMESTAMP_FALLBACK_MS" \
  "${AIRRADAR_SOURCE}/html/js/plot_detection.js" \
  "${DISPLAY_PAGES_PATCH}" \
  "display pages immediate load"
