# AirRadar Multi-radio

AirRadar Multi-radio is a single-PC deployment wrapper for running three local
AirRadar passive-radar receivers from one powerful Ubuntu 22.04 Mini PC.

The intended hardware is:

- One Ubuntu 22.04 Mini PC.
- Three Ettus USRP B210 two-channel SDRs connected over reliable USB 3.0 paths.
- Six antennas total:
  - Three reference antennas.
  - Three surveillance antennas.
- One ADS-B receiver stack, usually RTL-SDR plus readsb/tar1090 and adsb2dd.
- One AirRadar Localization instance fusing all three local AirRadar APIs.

This repo is intentionally separate from existing `/opt/airradar` and
`/opt/airradar-localization` deployments. It uses different container names,
different API ports, and different save/config folders.

## What Runs

| Component | Purpose | Default local port |
| --- | --- | --- |
| `sensor1` AirRadar runtime/API/web | USRP B210 #1 passive-radar sensor | API `3100`, web `49161` |
| `sensor2` AirRadar runtime/API/web | USRP B210 #2 passive-radar sensor | API `3200`, web `49162` |
| `sensor3` AirRadar runtime/API/web | USRP B210 #3 passive-radar sensor | API `3300`, web `49163` |
| AirRadar Localization | Multi-sensor map and fused localization | `49256` |
| tar1090 | ADS-B truth display and aircraft JSON source | `8080` |
| adsb2dd | ADS-B geographic to delay-Doppler conversion | `49155` |

The three AirRadar sensor configs live under:

```text
config/sensors/sensor1/config.yml
config/sensors/sensor2/config.yml
config/sensors/sensor3/config.yml
```

The localization config lives under:

```text
config/localization/config.yml
```

## RF Geometry Note

This deployment can run three B210s from one Mini PC, but localization quality
still depends on the physical antenna geometry. If all three surveillance
antennas are colocated and pointed the same way, the system has less geometric
diversity than three separated AirRadar nodes. For best localization, separate
the antenna phase centers as much as practical, point surveillance antennas at
useful complementary sectors, and document each RX/TX location in the configs.

## Quick Start

```bash
sudo git clone https://github.com/tiaminetworks/AirRadar-MultiRadio.git /opt/airradar-multiradio
sudo chown -R "$USER":"$USER" /opt/airradar-multiradio
cd /opt/airradar-multiradio

cp .env.example .env
script/bootstrap_sources.bash
```

Connect the three B210s and verify that UHD sees them:

```bash
uhd_find_devices
```

The three AirRadar runtime containers wait for their pinned B210 serial before
starting the C++ processor. If a B210 is missing, unstable, or unable to load
firmware, the container stays up and logs `AirRadar USRP wait: ...` instead of
crash-restarting. After USB/power/cable issues are fixed, the runtime starts
automatically on the next wait cycle.

Then pin the detected serials into the three AirRadar configs:

```bash
script/configure_b210s.py --serials SERIAL1,SERIAL2,SERIAL3
```

Set the real RX/TX geometry at the same time:

```bash
script/configure_b210s.py \
  --serials SERIAL1,SERIAL2,SERIAL3 \
  --rx-lat 38.580002 --rx-lon -121.496060 --rx-alt 50 \
  --site-name "Multi-radio Test Site" \
  --tx-name "KTXL RF22 ATSC 1.0" \
  --tx-lat 38.271667 --tx-lon -121.506111 --tx-alt 602 --tx-ant 601 \
  --center-hz 521000000 --rate-hz 5000000 --bandwidth-hz 5000000
```

On Ubuntu Docker bridge deployments, the localization browser and containers
must be able to reach the same AirRadar API and tar1090 addresses. The default
`configure_b210s.py` value is `172.17.0.1`, which works for the host Firefox
browser and for the localization container. Override it only if your Docker
bridge gateway is different:

```bash
script/configure_b210s.py --serials SERIAL1,SERIAL2,SERIAL3 --host-gateway 172.17.0.1
```

Build and start:

```bash
script/build.bash
script/up.bash
script/status.bash
```

Open:

- Sensor 1: <http://localhost:49161/>
- Sensor 2: <http://localhost:49162/>
- Sensor 3: <http://localhost:49163/>
- Localization: <http://localhost:49256/>
- tar1090: <http://localhost:8080/>

## ADS-B Truth Sources

AirRadar Multi-radio keeps local tar1090 as the default ADS-B truth source and
adds three online options for situations where a local ADS-B receiver is not
available or is temporarily unhealthy:

- `local tar1090`: local RTL-SDR/readsb/tar1090 stack on port `8080`.
- `Airplanes.live online`: public point-radius aircraft feed proxied by
  AirRadar Localization.
- `ADSB.lol online`: public point-radius aircraft feed proxied by AirRadar
  Localization.
- `ADS-B Exchange online`: API-key provider proxied by AirRadar Localization.
  Set `ADSB_EXCHANGE_API_KEY` in `.env` before selecting it.

All online choices are exposed as tar1090-compatible URLs under the localization
API, so existing ADS-B truth display and adsb2dd delay-Doppler conversion keep
working. The online search center defaults to the configured RX site and the
radius defaults to `80` nautical miles.

Verify the configured source list:

```bash
curl -s http://127.0.0.1:49256/api/adsb/sources | python3 -m json.tool
```

Smoke-test the first online source:

```bash
curl -s http://127.0.0.1:49256/api/adsb/airplanes-live/data/aircraft.json \
  | python3 -m json.tool | head
```

If internet access is unavailable, leave the ADS-B truth source on
`local tar1090`.

If the localization page opens but `/map/index.html` shows only the AirRadar
controls on a blank white page, verify the Cesium asset proxy:

```bash
curl -I http://127.0.0.1:49256/cesium/Build/Cesium/Cesium.js
```

It should return `HTTP/1.1 200`. AirRadar Multi-radio provides the required
`cesium-apache` network alias for the Cesium container; after updating an older
checkout, rebuild and recreate the localization services.

## Save And Replay Layout

Each sensor writes to its own save directory:

```text
save/sensor1/
save/sensor2/
save/sensor3/
```

Replay files are separated the same way:

```text
replay/sensor1/
replay/sensor2/
replay/sensor3/
```

Localization archive inputs can be placed under:

```text
archive/sensor1/
archive/sensor2/
archive/sensor3/
```

## Deployment Safety

This project does not reuse the existing AirRadar service names:

- It does not create `airradar`.
- It does not create `airradar-api`.
- It does not create `airradar-web`.
- It does not create `airradar-localization-api`.

Instead it creates names beginning with `airradar-mr-`.

The default ports are also separate from the current xband-3 deployment. This
allows local build and config testing without stopping existing AirRadar or
AirRadar Localization services.

## Development

Run static validation:

```bash
script/test.bash
```

Prepare patched web roots after updating the AirRadar source:

```bash
script/prepare_web_roots.bash
```

This also writes each sensor web container's Apache proxy file so the original
AirRadar `/api/*`, `/stash/*`, and `/maxhold/*` browser routes reach the
matching sensor API port from the same web origin. Sensor pages should use
`http://localhost:49161`, `http://localhost:49162`, or
`http://localhost:49163` without depending on direct browser access to API ports
`3100`, `3200`, or `3300`.

If one sensor display page gets stuck on a spinner, regenerate that sensor's web
root and restart only that sensor:

```bash
script/restart_sensor.bash sensor2 all
```

Use `sensor1`, `sensor2`, or `sensor3`. The optional second argument can be
`web`, `api`, `runtime`, or `all`.

Stop the stack:

```bash
script/down.bash
```

## Source Dependencies

The orchestration repo keeps source checkouts out of git under `src/`:

- `src/airradar`
- `src/airradar-localization`
- `src/adsb2dd`

Use `script/bootstrap_sources.bash` to clone or update them.
