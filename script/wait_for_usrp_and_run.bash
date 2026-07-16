#!/usr/bin/env bash
set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "AirRadar USRP wait: no command supplied" >&2
  exit 64
fi

config_path=""
args=("$@")
for ((idx = 0; idx < ${#args[@]}; idx++)); do
  if [[ "${args[$idx]}" == "-c" && $((idx + 1)) -lt ${#args[@]} ]]; then
    config_path="${args[$((idx + 1))]}"
    break
  fi
done

if [[ -z "${config_path}" ]]; then
  echo "AirRadar USRP wait: no -c config path found; starting immediately"
  exec "$@"
fi

if [[ ! -f "${config_path}" ]]; then
  echo "AirRadar USRP wait: config ${config_path} not found; starting immediately"
  exec "$@"
fi

address="$(
  grep -E '^[[:space:]]*address:[[:space:]]*' "${config_path}" \
    | head -1 \
    | sed -E 's/^[[:space:]]*address:[[:space:]]*//; s/^["'\'']//; s/["'\'']$//'
)"

if [[ -z "${address}" ]]; then
  echo "AirRadar USRP wait: no device.address in ${config_path}; starting immediately"
  exec "$@"
fi

serial="$(
  printf '%s\n' "${address}" \
    | sed -nE 's/(^|.*,)[[:space:]]*serial=([^,[:space:]]+).*/\2/p'
)"

if ! command -v uhd_find_devices >/dev/null 2>&1; then
  echo "AirRadar USRP wait: uhd_find_devices is unavailable; starting immediately"
  exec "$@"
fi

interval="${AIRRADAR_USRP_WAIT_INTERVAL_SEC:-15}"
attempt=1
echo "AirRadar USRP wait: waiting for device.address=${address} config=${config_path}"

while true; do
  output="$(timeout 25s uhd_find_devices --args "${address}" 2>&1)"
  status=$?
  if [[ ${status} -eq 0 ]] && printf '%s\n' "${output}" | grep -q "Device Address"; then
    if [[ -z "${serial}" ]] || printf '%s\n' "${output}" | grep -q "serial:[[:space:]]*${serial}"; then
      echo "AirRadar USRP wait: found ${address}; starting AirRadar runtime"
      exec "$@"
    fi
  fi

  summary="$(
    printf '%s\n' "${output}" \
      | grep -E 'No UHD Devices Found|ERROR|Error|error|serial:|Device discovery|Could not|LookupError' \
      | tail -3 \
      | tr '\n' '; '
  )"
  if [[ -z "${summary}" ]]; then
    summary="uhd_find_devices exit=${status}"
  fi
  echo "AirRadar USRP wait: attempt=${attempt} not ready for ${address}: ${summary}"
  attempt=$((attempt + 1))
  sleep "${interval}"
done
