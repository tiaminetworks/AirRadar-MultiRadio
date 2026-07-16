# Architecture

AirRadar Multi-radio is an orchestration layer. It does not fork AirRadar or
AirRadar Localization source code. Instead it pins three independent AirRadar
configs to three local USRP B210 serial numbers and exposes them to one local
AirRadar Localization instance.

## Data Flow

```text
Reference antenna 1      Surveillance antenna 1
        |                         |
        +------ USRP B210 #1 -----+--> AirRadar sensor1 API :3100

Reference antenna 2      Surveillance antenna 2
        |                         |
        +------ USRP B210 #2 -----+--> AirRadar sensor2 API :3200

Reference antenna 3      Surveillance antenna 3
        |                         |
        +------ USRP B210 #3 -----+--> AirRadar sensor3 API :3300

RTL-SDR 1090 MHz receiver --> readsb --> tar1090 :8080 --> adsb2dd :49155

sensor1/sensor2/sensor3 APIs + ADS-B truth --> AirRadar Localization :49256
AirRadar Localization :49256 -- /cesium/* proxy --> Cesium Apache container
```

The localization API serves `/map/index.html` and proxies `/cesium/*` requests
to the Cesium container using the network alias `cesium-apache`. If that alias
is missing, the browser can load AirRadar overlay controls but cannot initialize
the Cesium map.

## Port Map

| Sensor | API | Map socket | Detection socket | Track socket | Control |
| --- | ---: | ---: | ---: | ---: | ---: |
| sensor1 | 3100 | 3101 | 3102 | 3103 | 4104 |
| sensor2 | 3200 | 3201 | 3202 | 3203 | 4204 |
| sensor3 | 3300 | 3301 | 3302 | 3303 | 4304 |

## Why Three Config Folders

Each B210 must be pinned by serial. Each sensor also has independent:

- RF center frequency.
- Sampling rate and RF bandwidth.
- Reference/surveillance gain.
- Transmitter preset.
- Receiver/transmitter geometry.
- Save and replay directory.
- API/control ports.

Keeping separate config folders avoids accidental cross-sensor edits.
