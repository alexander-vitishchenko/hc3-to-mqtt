# Changelog

All notable changes to this fork are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project loosely follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **Heartbeat interval QuickApp variable**: code and README now agree on the
  variable name. The variable is `hbInterval` (and `hbIncludeMeta` for the
  metadata opt-out). Short names are used deliberately because Fibaro limits
  QuickApp variable-name length — `heartbeatInterval` / `heartbeatIncludeMeta`
  were too long to add in the HC3 UI. The previously-shipped code read the
  mismatched `hbinterval`, so the interval was never actually configurable.
- **Recurring "Variable X not found" log warnings**: optional QuickApp
  variables (`hbInterval`, `hbIncludeMeta`, `mqttClientId`, `deviceFilter*`)
  are now read through a new `QuickApp:getOptionalVariable` helper that does
  not trigger Fibaro's warning when the variable is absent. Previously the
  heartbeat logged two warnings on every interval (e.g. every 60 seconds).
- **`return nul` typo** in `device_helper.lua` (`__identifyHaEntity`) replaced
  with `return nil`.
- **Undefined `deviceHierarchy` reference** in
  `removeDeviceNodeFromHierarchyById` replaced with
  `deviceHierarchyRootNode.childNodeList`. Also added a guard for unknown ids.
- **Undefined `event` reference** in `PrototypeEntity:setProperty` warning
  branch — the warning now logs the actual unexpected value.
- **Duplicate `disconnectFromMqttAndHc3` definition** in `main.lua` removed.
- **Dead `discoverDevicesByFilter`** in `main.lua` removed — referenced an
  undefined `mqttClientId` and was never called.
- **Hardcoded debug spam for device #226** removed from
  `dispatchFibaroEventToMqtt`.
- **Dutch debug comments / log strings** translated to English for
  consistency.
- **`shallowInsertTo`/`shallowCopyTo`** no longer write to a stray global
  `copy` for non-table inputs.
- **Inverted Zigbee version logic** in `__identifyAndAppendHaDevice` (was
  printing "Zigbee" without a version when the version was present).
- **`zwaveInfoComponents`** is now declared `local` (was leaking to globals).
- **Last-will message format** for the Home Assistant convention now uses a
  proper `retain = true` key instead of an unnamed nested table.
- **Missing nil-check** for unknown device ids in `onHomeAssistantEvent`
  (both Home Assistant and Homie conventions) — previously a command for an
  unknown device crashed the handler.
- **Unreachable code** after the if/elseif return chain in
  `dispatchFibaroEventToMqtt` removed.
- **Literal `\t` escape sequences** in `tools.lua` (`table.indexOf`) replaced
  with real indentation; the previous source would not parse as Lua.
- **Spelling fixes**: "entity", "synchronized", "redundant", "existence",
  "battery", "door", "heuristics", "Unknown", "Assistant".
- **`%` unit no longer maps to `humidity`**: ambiguous percent units (battery,
  position, humidity) now fall back to the device subtype, fixing battery
  sensors being mis-classified as humidity.

### Added
- **`hbIncludeMeta` QuickApp variable**. Set to `false` to omit IP /
  version / device counts from the heartbeat payload (privacy / shared-broker
  scenarios).
- **`QuickApp:getOptionalVariable` helper** reads QuickApp variables straight
  from `self.properties.quickAppVariables`, so optional/unset variables are
  read silently instead of producing a Fibaro "Variable not found" warning.
- **`sanitizeMqttUrl` helper** in `tools.lua` strips `user:pass@` from URLs
  before logging.
- **Heartbeat lifecycle generation counter**. Reconnects no longer leave a
  stale heartbeat chain running in parallel.
- **`scripts/build_fqa.py`** rebuilds `hc3_to_mqtt_bridge-1.0.235-fork-1.fqa`
  from the Lua sources, with a `--check` mode to verify that the committed
  `.fqa` matches `src/`.
- **`SECURITY.md`** with vulnerability-reporting guidance and operational
  notes.
- **README**: navigation TOC, TLS / `mqtts://` recommendation, heartbeat
  privacy section, build instructions, security considerations.
- **Input validation** for `mqttKeepAlive` and `hbInterval`
  (non-positive / non-numeric values fall back to defaults with a warning).
- **`pcall` around `identifyLocalIpAddressForHc3`** at module load time so a
  transient HC3 API issue doesn't prevent the QuickApp from starting.

### Changed
- Magic numbers (poll delays, reconnect delay, default keepalive, default
  heartbeat interval, refresh-states URL) lifted to named constants at the
  top of `main.lua`.
- The `.fqa` is now generated deterministically from `src/` via
  `scripts/build_fqa.py`. The previously-committed `.fqa` was out of sync
  with `src/`; that has been corrected.

## [1.0.235-fork-1]

### Added
- Periodic heartbeat/alive MQTT message on `homeassistant/hc3-heartbeat`.
- Sensor `device_class` mapping based on unit of measurement (A, V, W, kWh,
  Wh, °C/°F, lx, %), based on Eroi69's fix.
- `state_class = measurement` for non-energy sensors.

### Forked from
- alexander-vitishchenko/hc3-to-mqtt v1.0.235.
