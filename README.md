# "Fibaro Home Center 3" to "Home Assistant" integration (Fork)

> **This is a fork of [alexander-vitishchenko/hc3-to-mqtt](https://github.com/alexander-vitishchenko/hc3-to-mqtt) v1.0.235**
> The original project bridges Fibaro HC3/HCL/Yubii Home devices to Home Assistant via MQTT.
> This fork adds a heartbeat/alive feature and improved sensor device_class mapping.

## Contents

- [Fork changes](#-fork-changes-v10235-fork-6)
  - [Heartbeat / Alive message](#heartbeat--alive-message)
  - [Automatic reconnect after errors](#automatic-reconnect-after-errors)
  - [Improved sensor device_class mapping](#improved-sensor-device_class-mapping)
  - [S1/S2 switch inputs and remote buttons as triggers](#s1s2-switch-inputs-and-remote-buttons-as-triggers)
- [How to use](#how-to-use)
- [Supported device types](#already-supported-device-types)
- [Building the .fqa from source](#building-the-fqa-from-source)
- [Checks and releases](#checks-and-releases)
- [Security considerations](#security-considerations)
- [Credits](#credits)

## 🔀 Fork changes (v1.0.235-fork-6)

### Heartbeat / Alive message
Publishes a periodic status message to MQTT so Home Assistant can monitor whether the HC3 bridge is alive and responsive.

- **Topic:** `homeassistant/hc3-heartbeat`
- **Interval:** configurable via QuickApp variable `hbInterval` (default: 60 seconds)
- **Payload example:**
```json
{
    "status": "online",
    "timestamp": "2025-01-15T14:30:00Z",
    "uptime": 3600,
    "version": "1.0.235-fork-6",
    "devices": 42,
    "entities": 58,
    "ip": "192.168.1.100"
}
```

#### Configuring the heartbeat interval

The heartbeat interval can be configured via the QuickApp variable `hbInterval` in your Fibaro HC3:

1. Open the QuickApp in your Fibaro HC3 web interface
2. Go to the **Variables** section
3. Add a new variable: name = `hbInterval`, value = number of seconds (e.g. `30`, `60`, `120`)
4. Save and restart the QuickApp

If the variable is not set, the default interval of **60 seconds** is used. Lower values give faster detection of connection issues, but generate more MQTT traffic. A value of `30` is a good balance for most setups.

#### Privacy: opt out of metadata in heartbeat

By default the heartbeat payload contains the HC3's local IP, the QuickApp version, and the device/entity counts. If you don't want these published (e.g. on a shared MQTT broker), add a QuickApp variable:

| Name | Value | Effect |
|------|-------|--------|
| `hbIncludeMeta` | `false` | Strips `version`, `devices`, `entities`, `ip` from the heartbeat payload (only `status`, `timestamp`, `uptime` remain) |

#### Heartbeat vs availability topic

This fork publishes **two** related topics:

- `homeassistant/hc3-status` — last-will availability topic, plain string `online` / `offline`. Used as the primary availability source for all bridged entities.
- `homeassistant/hc3-heartbeat` — periodic JSON heartbeat. Useful for detecting a hung QuickApp where the MQTT connection is still up but events have stopped flowing.

#### Home Assistant MQTT sensor configuration

```yaml
mqtt:
  sensor:
    - name: "HC3 Bridge Status"
      unique_id: hc3_bridge_status
      state_topic: "homeassistant/hc3-heartbeat"
      value_template: "{{ value_json.status }}"
      json_attributes_topic: "homeassistant/hc3-heartbeat"
      json_attributes_template: "{{ value_json | tojson }}"
      icon: "mdi:bridge"

    - name: "HC3 Bridge Uptime"
      unique_id: hc3_bridge_uptime
      state_topic: "homeassistant/hc3-heartbeat"
      value_template: "{{ value_json.uptime }}"
      unit_of_measurement: "s"
      device_class: "duration"
      icon: "mdi:timer-outline"

  binary_sensor:
    - name: "HC3 Bridge Online"
      unique_id: hc3_bridge_online
      state_topic: "homeassistant/hc3-status"
      payload_on: "online"
      payload_off: "offline"
      device_class: "connectivity"
      icon: "mdi:server-network"
```

### S1/S2 switch inputs and remote buttons as triggers
Presses on the S1/S2 inputs of Fibaro dimmers and relays (e.g. FGD-212, FGS-213, FGS-223) and on remote controller buttons are sent by the HC3 as *central scene* events. For every device that supports central scenes, the bridge creates a Home Assistant **device trigger** per combination of button and press type, attached to the same Home Assistant device as the dimmer/switch.

In Home Assistant: **Automations → Add trigger → Device →** select the dimmer/switch → e.g. *"First button" pressed*.

| Fibaro input | Trigger subtype | Press types |
|--------------|-----------------|-------------|
| S1 / button 1 | `button_1` ("First button") | `button_short_press`, `button_double_press`, `button_triple_press`, `button_long_press` (held), `button_long_release` |
| S2 / button 2 | `button_2` ("Second button") | same, as far as the device supports them |

Modules report presses in one of two ways, both supported:
- **Central Scene** (newer firmware, remotes such as the Fibaro Button): one trigger per button and press type the module advertises.
- **Scene Activation** (e.g. FGD-212 firmware 3.5): the HC3 shows a separate "Switch" device with `availableScenes`. Fibaro's scene ids are mapped to the same triggers: tens digit = input (1 = S1, 2 = S2), units digit = action (6 click, 4 double click, 5 triple click, 2 hold, 3 release, 0/1 toggle switch on/off). Example: 16 = S1 click, 24 = S2 double click. The HC3 lists only some ids in `availableScenes`; hold and release triggers are added for every input that appears there.

> **Enable scene activation on the module.** Many Fibaro modules don't send central scenes by default, e.g. FGD-212 parameter 28 and FGS-213/FGS-223 parameters 40/41. Check the manual of your module.

Every press is also published (non-retained) on `homeassistant/event/<fibaro-device-id>`, for use in MQTT triggers:

```json
{ "event_type": "central_scene", "device_id": 226, "button": 1, "action": "pressed2", "trigger": "1-pressed2" }
```

### Automatic reconnect after errors
The bridge recovers by itself instead of staying off until someone turns it on again:

- A failed poll of the HC3 events feed (e.g. `Host not found` while the HC3 is busy) is retried up to 5 times. After that the MQTT and HC3 connections are closed and opened again.
- An error while processing HC3 events no longer stops the polling.
- An MQTT connection that closes without an error (e.g. a broker restart) is reconnected.
- The reconnect delay starts at 10 seconds and doubles up to 5 minutes while the problem persists. It resets after the first successful poll.
- A manual **turn off** in the HC3 (or via `/api/devices/<id>/action/turnOff`) stays off; a pending reconnect is cancelled. **Turn on** on a live connection replaces it rather than opening a second one, so an external watchdog can safely do off/on.

> **Keep the QuickApp id when updating.** Uploading the `.fqa` as a new device gives the bridge a new id, which breaks anything that calls it by id (e.g. a Home Assistant `rest_command` for a watchdog). To keep the id, open the existing QuickApp in the HC3 editor and replace the contents of each file with the matching `src/*.lua`.

### Improved sensor device_class mapping
Based on [Eroi69's fix](https://github.com/Eroi69/hc3-to-mqtt/commit/7bc34385f753d25f70728cb290ad9747cb31fe83). The original code determined `device_class` only from the Fibaro subtype, which missed common units. This fork maps the unit of measurement to the correct Home Assistant device_class:

| Unit | device_class | state_class |
|------|-------------|-------------|
| A | current | measurement |
| V | voltage | measurement |
| W / kW | power | measurement |
| kWh / Wh | energy | total_increasing |
| °C / °F | temperature | measurement |
| lx | illuminance | measurement |
| Hz | frequency | measurement |

For ambiguous units (e.g. `%` is used by humidity, battery, position) the mapping **falls back to the device subtype** to avoid mis-classifying battery sensors as humidity. Other units not in this table also fall back to the original subtype-based logic.

---

## How to use

<ol>
    <li>
        Make sure you have MQTT broker installed, e.g. <a href="https://github.com/home-assistant/addons/blob/master/mosquitto/DOCS.md">Mosquitto within your Home Assistance instance</a>. 
        <br><br>
    </li>
    <li>
        Make sure you have "MQTT" integration added and configured your Home Assistant instance, as <a href="https://www.home-assistant.io/integrations/mqtt">described here</a>. 
        <br><br>
    </li>
    <li>
        Upload the Fibaro QuickApp (.fqa file) to your Fibaro Home Center 3 instance:
        <ul>
            <li>Open the Configuration Interface</li>
            <li>Go to Settings > Devices</li>
            <li>Click  +</li>
            <li>Choose Other Device</li>
            <li>Choose Upload File</li>
            <li>Choose file from your computer with .fqa</li>
        </ul>
        <br>
    </li>
    <li>
        Configure your Fibaro QuickApp:<br>
        <ul>
            <li> "<b>mqttUrl</b>" - URL for connecting to MQTT broker, e.g. <code>mqtt://192.168.1.10:1883</code> or <code>mqtts://192.168.1.10:8883</code> for TLS. <b>Use <code>mqtts://</code> whenever possible</b> — plain <code>mqtt://</code> sends username/password unencrypted over the network.</li>
            <li> "<b>mqttUsername</b>" and "<b>mqttPassword</b>" (optional) - user credentials for MQTT authentication</li>
            <li> "<b>hbInterval</b>" (optional) - interval in seconds for the heartbeat message (default: 60)</li>
            <li> "<b>hbIncludeMeta</b>" (optional) - set to <code>false</code> to omit IP/version/device counts from heartbeat (privacy)</li>
            <li> "<b>deviceFilter</b>" (optional) - apply your filters for Fibaro HC3 device autodiscovery in case you need to limit the number of devices to be bridged with Home Assistant. <br>
            <details>
               <summary>Click here to see example</summary>
               <code>{"filter":"baseType", "value":["com.fibaro.actor"]}, {"filter":"deviceID", "value":[41,42]}, { MORE FILTERS MAY GO HERE }</code>.<br> Fibaro Filter API description and more examples could be found at https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"
               <br><br>Use "deviceFilter", "deviceFilter2", "deviceFilter3" ... "deviceFilterX" to overcome Fibaro QuickApp variable length limitation. Use "," (commas) after each filter criterion as it is not added added automatically
            </details>
            </li>
    </li>
</ol>

## Already supported device types
   * Z-Wave hardware, and experimental Zigbee & Nice devices support
   * Sensors - Fibaro Motion Sensor, Fibaro Universal Sensor, Fibaro Flood Sensor, Fibaro Smoke/Fire Sensor, most of the generic sensors to measure temperature, humidity, brightness and so on
   * Energy and power meters
   * Charge level sensors for battery-powered devices
   * Lights - binary, dimmers and RGBW (no RGB for now)
   * Switches - binary and sound
   * Remote Controllers and the S1/S2 inputs of dimmers/relays, where each key and press type is bound to an automation trigger visible in Home Assistant GUI
   * Thermostats (limited support for a few known vendors) 

## Building the .fqa from source

The `.fqa` is a JSON file that bundles the Lua sources together with QuickApp metadata. To rebuild it from `src/`:

```bash
python3 scripts/build_fqa.py
```

This produces `hc3_to_mqtt_bridge-1.0.235-fork-6.fqa` in the repository root, with the contents of every `src/*.lua` injected into the corresponding QuickApp file slot. The script preserves the existing QuickApp variable defaults and view layout from the previous `.fqa`. Use `--check` to verify that the committed `.fqa` is in sync with `src/` without writing.

```bash
python3 scripts/build_fqa.py --check
```

## Checks and releases

The GitHub Actions workflow `.github/workflows/ci.yml` runs on every pull request and every push to `master`:

- Lua syntax check and `luacheck`
- `tests/run_tests.lua`: runs the sources against a mocked HC3 (button triggers, MQTT convention selection)
- the `.fqa` is in sync with `src/` (`scripts/build_fqa.py --check`)
- the version is consistent: `QUICKAPP_VERSION` in `src/main.lua`, the `.fqa` file name, `scripts/build_fqa.py` and a `## [<version>]` section in `CHANGELOG.md`

After a push to `master` passes these checks, the workflow creates the GitHub release `v<version>` with the `.fqa` attached and the CHANGELOG section as release notes. If that release already exists nothing is published, so a merge without a version bump doesn't release.

To release a new version: bump `QUICKAPP_VERSION`, rename the `.fqa` and `DEFAULT_FQA` in `scripts/build_fqa.py`, add a CHANGELOG section, run `python3 scripts/build_fqa.py`, and merge to `master`.

Run the tests locally with `lua5.3 tests/run_tests.lua src` (needs the `dkjson` rock).

## Security considerations

- **Use TLS.** Configure `mqttUrl` with the `mqtts://` scheme and a TLS-enabled broker. Plain `mqtt://` sends credentials and device state in clear text.
- **MQTT broker authorization.** The bridge publishes device state under `homeassistant/+/+/`. Treat read access to your broker as device-state access; restrict ACLs accordingly.
- **Heartbeat metadata.** The default heartbeat reveals the HC3's local IP, QuickApp version and device counts. Set the QuickApp variable `hbIncludeMeta=false` if these are sensitive in your environment.
- **Credentials in `mqttUrl`.** Avoid embedding `user:pass@` directly in `mqttUrl`. Use the dedicated `mqttUsername` / `mqttPassword` QuickApp variables — those are anonymized in logs.
- **QuickApp variables are not encrypted at rest.** Anyone with admin access to the HC3 can read them. Use a dedicated MQTT account with the minimum required ACL.

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Credits

- **Original project:** [alexander-vitishchenko/hc3-to-mqtt](https://github.com/alexander-vitishchenko/hc3-to-mqtt) — MIT License
- **Sensor device_class fix:** [Eroi69](https://github.com/Eroi69/hc3-to-mqtt)
