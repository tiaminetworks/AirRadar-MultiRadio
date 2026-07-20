# AirRadar Multi-radio Deployment Guide

This guide deploys one Ubuntu 22.04 Mini PC with three local USRP B210
two-channel SDRs, one ADS-B receiver stack, three AirRadar sensor instances,
and one AirRadar Localization instance.

## 1. Install Ubuntu Packages

```bash
sudo apt update
sudo apt install -y \
  git curl ca-certificates gnupg lsb-release \
  python3 python3-pip python3-yaml \
  uhd-host libuhd-dev
```

Install Docker Engine and the Docker Compose plugin if they are not already
installed:

```bash
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker "$USER"
newgrp docker
```

Download UHD images:

```bash
sudo uhd_images_downloader
```

Reload USB rules:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## 2. Clone AirRadar Multi-radio

```bash
sudo git clone https://github.com/tiaminetworks/AirRadar-MultiRadio.git /opt/airradar-multiradio
sudo chown -R "$USER":"$USER" /opt/airradar-multiradio
cd /opt/airradar-multiradio
cp .env.example .env
```

## 3. Pull Component Sources

```bash
cd /opt/airradar-multiradio
script/bootstrap_sources.bash
```

This creates ignored source folders:

```text
src/airradar
src/airradar-localization
src/adsb2dd
```

## 4. Connect And Verify Hardware

Connect:

- Three USRP B210 SDRs.
- One RTL-SDR ADS-B receiver.
- Three reference antennas.
- Three surveillance antennas.

Check USB topology:

```bash
lsusb
lsusb -t
```

Check B210 serials:

```bash
uhd_find_devices
```

Expected result: three B210 devices, each with a unique serial.

If UHD cannot find the images, run:

```bash
sudo uhd_images_downloader
```

The sensor runtime containers include a hardware wait wrapper. If a configured
B210 serial is not visible or UHD cannot initialize it, the container logs
`AirRadar USRP wait: ...` and keeps waiting instead of crash-restarting. This
makes USB/power/cable problems visible in the logs and lets the runtime start
automatically after the hardware becomes healthy.

## 5. Pin B210 Serial Numbers

Replace the serials below with the three serials from `uhd_find_devices`:

```bash
cd /opt/airradar-multiradio
script/configure_b210s.py --serials SERIAL1,SERIAL2,SERIAL3
```

Set real site and transmitter geometry:

```bash
script/configure_b210s.py \
  --serials SERIAL1,SERIAL2,SERIAL3 \
  --rx-lat YOUR_RX_LAT --rx-lon YOUR_RX_LONG --rx-alt YOUR_RX_ALT_M \
  --site-name "Your Multi-radio Site" \
  --tx-name "Your TV Illuminator" \
  --tx-lat YOUR_TX_LAT --tx-lon YOUR_TX_LONG --tx-alt YOUR_TX_ALT_M --tx-ant YOUR_TX_ANT_M \
  --center-hz 521000000 --rate-hz 5000000 --bandwidth-hz 5000000
```

The localization map URLs must be reachable from both Docker containers and the
host browser. On a normal Ubuntu Docker bridge, keep the default host gateway
`172.17.0.1`. If your bridge gateway is different, pass it explicitly:

```bash
script/configure_b210s.py \
  --serials SERIAL1,SERIAL2,SERIAL3 \
  --host-gateway 172.17.0.1
```

This updates:

- `config/sensors/sensor1/config.yml`
- `config/sensors/sensor2/config.yml`
- `config/sensors/sensor3/config.yml`
- `config/localization/config.yml`

## 6. Validate Before Build

```bash
cd /opt/airradar-multiradio
script/test.bash
```

The test checks:

- Python script syntax.
- YAML config consistency.
- Unique AirRadar ports.
- Docker Compose render validity.

## 7. Build

```bash
cd /opt/airradar-multiradio
script/build.bash
```

The first build can take a while because AirRadar builds C++ dependencies and
downloads UHD images inside the image.

## 8. Start The Full Stack

```bash
cd /opt/airradar-multiradio
script/up.bash
script/status.bash
```

Open:

```text
Sensor 1 Web:     http://localhost:49161/
Sensor 2 Web:     http://localhost:49162/
Sensor 3 Web:     http://localhost:49163/
Localization:     http://localhost:49256/
tar1090:          http://localhost:8080/
```

## 9. Operational Checks

Check containers:

```bash
cd /opt/airradar-multiradio
docker compose --profile airradar --profile localization --profile adsb ps
```

Check AirRadar APIs:

```bash
curl -s http://127.0.0.1:3100/api/config | python3 -m json.tool | head
curl -s http://127.0.0.1:3200/api/config | python3 -m json.tool | head
curl -s http://127.0.0.1:3300/api/config | python3 -m json.tool | head
```

Check the browser-facing AirRadar display data routes:

```bash
for port in 49161 49162 49163; do
  echo "Sensor web port ${port}"
  curl -s "http://127.0.0.1:${port}/stash/map" | head -c 80; echo
  curl -s "http://127.0.0.1:${port}/stash/iqdata" | head -c 80; echo
  curl -s "http://127.0.0.1:${port}/stash/timing" | head -c 80; echo
  curl -s "http://127.0.0.1:${port}/stash/detection" | head -c 80; echo
done
```

The AirRadar max-hold, spectrum, timing, and detection-history pages use the
original `/stash/*` URLs. In Multi-radio, each sensor web container proxies
those URLs to its matching API port. The browser should stay on the sensor web
origin, for example `http://localhost:49162/stash/map` for sensor 2, instead of
calling `http://localhost:3200/stash/map` directly.

If a display page is stuck on a spinner, first verify the data path:

```bash
curl -I http://127.0.0.1:49162/display/maxhold/
curl -s http://127.0.0.1:49162/stash/map | head -c 120; echo
curl -s http://127.0.0.1:3200/stash/map | head -c 120; echo
```

If the `/stash/map` responses are present, hard-refresh the browser. If the
browser is still stuck or the generated pages contain stale API-port URLs,
regenerate the web roots and restart the affected sensor:

```bash
cd /opt/airradar-multiradio
script/restart_sensor.bash sensor2 all
```

Use `sensor1`, `sensor2`, or `sensor3`. The optional second argument can be
`web`, `api`, `runtime`, or `all`. The `web` and `all` modes force-recreate the
web container so Docker rebinds the freshly generated web root.

If the API ports work but the web ports return `404`, recreate the web
containers:

```bash
cd /opt/airradar-multiradio
script/prepare_web_roots.bash
docker compose --profile airradar up -d --no-deps sensor1_web sensor2_web sensor3_web
```

Check ADS-B:

```bash
curl -s http://127.0.0.1:8080/data/aircraft.json | python3 -m json.tool | head
curl -s http://127.0.0.1:49155/api/dd | head
```

Check the ADS-B truth sources exposed by AirRadar Localization:

```bash
curl -s http://127.0.0.1:49256/api/adsb/sources | python3 -m json.tool
curl -s http://127.0.0.1:49256/api/adsb/airplanes-live/data/aircraft.json \
  | python3 -m json.tool | head
```

The normal local source is `local tar1090`. The online choices are
`Airplanes.live online`, `ADSB.lol online`, and `ADS-B Exchange online`. The
first two are public point-radius feeds. `ADS-B Exchange online` requires an API
key:

```bash
cd /opt/airradar-multiradio
perl -0pi -e 's/^ADSB_EXCHANGE_API_KEY=.*/ADSB_EXCHANGE_API_KEY=YOUR_KEY/' .env
docker compose --profile localization up -d --build localization_api localization_event
```

If the Mini PC has no internet access, keep the localization ADS-B truth source
set to `local tar1090`; the online providers will return an API error instead
of affecting the local tar1090 path.

Check localization:

```bash
curl -s http://127.0.0.1:49256/api/status | python3 -m json.tool
```

Check the localization map Cesium assets:

```bash
curl -I http://127.0.0.1:49256/cesium/Build/Cesium/Cesium.js
```

Expected result: `HTTP/1.1 200`. If `/api/status` works but the map page is
blank white with only AirRadar layer controls visible, the Cesium asset proxy is
not reachable. Pull the current AirRadar Multi-radio code, rebuild, and recreate
the localization services:

```bash
cd /opt/airradar-multiradio
git pull --ff-only origin main
script/build.bash
script/up.bash
script/status.bash
```

## 10. Updating Existing Multi-radio Deployments

```bash
cd /opt/airradar-multiradio
git pull --ff-only origin main
script/bootstrap_sources.bash
script/test.bash
script/build.bash
script/up.bash
```

If local configs have been modified, back them up first:

```bash
cp -a config "config.backup-$(date +%Y%m%d-%H%M%S)"
```

## 11. Stopping

```bash
cd /opt/airradar-multiradio
script/down.bash
```

## Notes On Performance

Three B210s at 5 MS/s with two channels each is a heavy USB and CPU workload.
If overrun messages appear, reduce one or more of:

- Sample rate / bandwidth.
- CPI duration.
- Delay range.
- Doppler range.
- Optional IQ recording.

Use separate USB root controllers where possible. A weak hub can make the system
look like a software problem when it is really USB bandwidth or power.
