#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIRRADAR_SOURCE="${AIRRADAR_SOURCE:-${ROOT}/src/airradar}"
PATCH="${ROOT}/patches/airradar-lightweight-performance-categories.patch"

if [[ ! -d "${AIRRADAR_SOURCE}" ]]; then
  echo "Missing AirRadar source: ${AIRRADAR_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${AIRRADAR_SOURCE}/api/performance_evaluator.js" ]]; then
  echo "Missing AirRadar performance evaluator under ${AIRRADAR_SOURCE}" >&2
  exit 1
fi

if grep -q "collectCategoryValuesLightweight" "${AIRRADAR_SOURCE}/api/performance_evaluator.js"; then
  echo "AirRadar overlay already present: lightweight performance categories"
  exit 0
fi

if [[ ! -f "${PATCH}" ]]; then
  echo "Missing overlay patch: ${PATCH}" >&2
  exit 1
fi

if git -C "${AIRRADAR_SOURCE}" apply --check "${PATCH}"; then
  git -C "${AIRRADAR_SOURCE}" apply "${PATCH}"
  echo "Applied AirRadar overlay: lightweight performance categories"
else
  echo "AirRadar overlay patch cannot apply cleanly to ${AIRRADAR_SOURCE}" >&2
  echo "Update ${PATCH} or update the AirRadar source manually before building." >&2
  exit 1
fi
