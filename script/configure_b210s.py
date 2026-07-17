#!/usr/bin/env python3
"""Configure three local USRP B210 serial numbers for AirRadar Multi-radio."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
SENSOR_KEYS = ["sensor1", "sensor2", "sensor3"]
DEFAULT_HOST_GATEWAY = "172.17.0.1"
ONLINE_ADSB_SERVERS = [
    {
        "name": "Airplanes.live online",
        "url": "http://localization_api:5000/api/adsb/airplanes-live",
    },
    {
        "name": "ADSB.lol online",
        "url": "http://localization_api:5000/api/adsb/adsb-lol",
    },
    {
        "name": "ADS-B Exchange online",
        "url": "http://localization_api:5000/api/adsb/adsb-exchange",
    },
]


def detect_serials() -> list[str]:
    try:
        proc = subprocess.run(
            ["uhd_find_devices"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
    except FileNotFoundError:
        return []

    serials: list[str] = []
    for line in proc.stdout.splitlines():
        match = re.search(r"serial:\s*([A-Za-z0-9_-]+)", line)
        if match:
            serial = match.group(1)
            if serial not in serials:
                serials.append(serial)
    return serials


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def save_yaml(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(data, handle, sort_keys=False, width=1000)


def update_sensor_config(sensor: str, serial: str, args: argparse.Namespace) -> None:
    path = ROOT / "config" / "sensors" / sensor / "config.yml"
    data = load_yaml(path)
    data["capture"]["device"]["address"] = f"serial={serial}"
    data["capture"]["fs"] = int(args.rate_hz)
    data["capture"]["device"]["bandwidth"] = int(args.bandwidth_hz)
    data["capture"]["fc"] = int(args.center_hz)

    rx = data.setdefault("location", {}).setdefault("rx", {})
    rx["latitude"] = args.rx_lat
    rx["longitude"] = args.rx_lon
    rx["altitude"] = args.rx_alt
    rx["name"] = f"{args.site_name} {sensor} RX"

    tx = data["location"].setdefault("tx", {})
    tx["latitude"] = args.tx_lat
    tx["longitude"] = args.tx_lon
    tx["altitude"] = args.tx_alt
    tx["antennaHeight"] = args.tx_ant
    tx["name"] = args.tx_name

    save_yaml(path, data)


def update_localization_config(serials: list[str], args: argparse.Namespace) -> None:
    path = ROOT / "config" / "localization" / "config.yml"
    data = load_yaml(path)
    data["radar"] = []
    base_ports = [3100, 3200, 3300]
    for sensor, api_port in zip(SENSOR_KEYS, base_ports):
        data["radar"].append(
            {
                "name": sensor,
                "url": f"{args.host_gateway}:{api_port}",
                "localizationDefault": True,
                "fusionWeight": 1.0,
                "location": {
                    "rx": {
                        "latitude": args.rx_lat,
                        "longitude": args.rx_lon,
                        "altitude": args.rx_alt,
                        "name": f"{args.site_name} {sensor} RX",
                    },
                    "tx": {
                        "latitude": args.tx_lat,
                        "longitude": args.tx_lon,
                        "altitude": args.tx_alt,
                        "antennaHeight": args.tx_ant,
                        "name": args.tx_name,
                    },
                },
            }
        )
    data.setdefault("localisation", {}).setdefault("joint", {})["sensorWeights"] = {
        sensor: 1.0 for sensor in SENSOR_KEYS
    }
    data.setdefault("map", {}).setdefault("location", {})["latitude"] = args.rx_lat
    data["map"]["location"]["longitude"] = args.rx_lon
    data["map"]["tar1090"] = f"{args.host_gateway}:8080"
    data["map"]["tar1090_servers"] = [
        {"name": "local tar1090", "url": f"{args.host_gateway}:8080"},
        *ONLINE_ADSB_SERVERS,
    ]
    online = data["map"].setdefault("adsb_online", {})
    online.setdefault("defaultRadiusNm", 80)
    online.setdefault("timeoutSec", 4)
    center = online.setdefault("center", {})
    center["latitude"] = args.rx_lat
    center["longitude"] = args.rx_lon
    save_yaml(path, data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serials", help="Comma-separated B210 serials for sensor1,sensor2,sensor3")
    parser.add_argument("--center-hz", type=float, default=521_000_000)
    parser.add_argument("--rate-hz", type=float, default=5_000_000)
    parser.add_argument("--bandwidth-hz", type=float, default=5_000_000)
    parser.add_argument("--rx-lat", type=float, default=38.58000207566816)
    parser.add_argument("--rx-lon", type=float, default=-121.49606043119596)
    parser.add_argument("--rx-alt", type=float, default=50)
    parser.add_argument("--site-name", default="Multi-radio")
    parser.add_argument("--tx-name", default="KTXL RF22 ATSC 1.0")
    parser.add_argument("--tx-lat", type=float, default=38.271667)
    parser.add_argument("--tx-lon", type=float, default=-121.506111)
    parser.add_argument("--tx-alt", type=float, default=602)
    parser.add_argument("--tx-ant", type=float, default=601)
    parser.add_argument(
        "--host-gateway",
        default=DEFAULT_HOST_GATEWAY,
        help=(
            "Host address reachable from both Docker containers and the host browser. "
            "Ubuntu Docker bridge default is 172.17.0.1."
        ),
    )
    args = parser.parse_args()

    serials = [s.strip() for s in args.serials.split(",")] if args.serials else detect_serials()
    serials = [s for s in serials if s]
    if len(serials) < 3:
        print("Need three B210 serials. Detected: " + (", ".join(serials) or "none"), file=sys.stderr)
        print("Use --serials SERIAL1,SERIAL2,SERIAL3 after checking uhd_find_devices.", file=sys.stderr)
        return 2

    serials = serials[:3]
    for sensor, serial in zip(SENSOR_KEYS, serials):
        update_sensor_config(sensor, serial, args)
        print(f"{sensor}: serial={serial}")
    update_localization_config(serials, args)
    print("Updated AirRadar sensor configs and localization config.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
