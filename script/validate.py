#!/usr/bin/env python3
"""Validate AirRadar Multi-radio static configuration."""

from __future__ import annotations

import argparse
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
SENSOR_KEYS = ["sensor1", "sensor2", "sensor3"]


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-placeholders", action="store_true")
    args = parser.parse_args()

    errors: list[str] = []
    api_ports: set[int] = set()
    all_ports: set[int] = set()
    serials: set[str] = set()

    for sensor in SENSOR_KEYS:
        path = ROOT / "config" / "sensors" / sensor / "config.yml"
        data = load_yaml(path)
        address = str(data["capture"]["device"]["address"])
        if "CHANGE_ME" in address and not args.allow_placeholders:
            errors.append(f"{sensor}: B210 serial is still a placeholder")
        if address in serials:
            errors.append(f"{sensor}: duplicate USRP address {address}")
        serials.add(address)

        ports = data["network"]["ports"]
        for name, value in ports.items():
            port = int(value)
            if port in all_ports:
                errors.append(f"{sensor}: duplicate port {port} at network.ports.{name}")
            all_ports.add(port)
        api_ports.add(int(ports["api"]))

        if data["truth"]["adsb"]["adsb2dd"] != "127.0.0.1:49155":
            errors.append(f"{sensor}: expected local adsb2dd endpoint 127.0.0.1:49155")

    loc = load_yaml(ROOT / "config" / "localization" / "config.yml")
    loc_radars = {entry["name"]: entry["url"] for entry in loc.get("radar", [])}
    for sensor, port in zip(SENSOR_KEYS, [3100, 3200, 3300]):
        expected = f"host.docker.internal:{port}"
        if loc_radars.get(sensor) != expected:
            errors.append(f"localization: {sensor} url should be {expected}")

    weights = loc.get("localisation", {}).get("joint", {}).get("sensorWeights", {})
    for sensor in SENSOR_KEYS:
        if sensor not in weights:
            errors.append(f"localization: missing sensor weight for {sensor}")

    if errors:
        for error in errors:
            print("ERROR:", error)
        return 1

    print("AirRadar Multi-radio config validation passed.")
    print("Sensor API ports:", ", ".join(str(port) for port in sorted(api_ports)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
