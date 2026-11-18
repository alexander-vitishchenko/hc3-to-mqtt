# Changelog

All notable changes to this fork are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project loosely follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.235-fork-6] - 2026-11-18

### Fixed
- **Bridge stayed off after a single failed HC3 poll**: an error from the HC3
  events feed (seen as `Host not found (authoritative)` on
  `127.0.0.1:11111/api/refreshStates`) called `turnOff()` and nothing turned
  the bridge on again. A failed poll is now retried up to 5 times; after that
  MQTT and HC3 are disconnected and reconnected automatically.
- **Polling stopped after an error while processing events** (e.g. a response
  that is not valid JSON): processing now runs in `pcall` and counts as a
  failed poll.
- **No reconnect after an MQTT connection closed without an error event**
  (e.g. a broker restart): the bridge now reconnects.
- **Device discovery errors after connecting** left MQTT connected without
  delivering events; the bridge now disconnects and tries again later.

### Changed
- Reconnect delay grows from 10 s to at most 5 min while the problem persists
  and resets after the first successful poll or a manual turn on.
- A manual turn off cancels a pending automatic reconnect. Turn on on a live
  connection replaces it instead of opening a second connection.
- Events of a replaced MQTT client and replies to an earlier polling chain are
  ignored, so a reconnect cannot leave duplicate connections or polling chains.

### Added
- Tests for retries, reconnects, manual turn off, unexpected close and
  replaced connections (`tests/run_tests.lua`), with recorded timers, HTTP
  requests and MQTT clients in the mocked runtime.

## [1.0.235-fork-5] - 2026-10-19

### Fixed
- **Devices switched on at every bridge (re)start**: a retained command on a
  `…/events/home assistant => fibaro/…` topic was replayed by the broker on
  every connect and executed again (seen with `-1.05 Lamp` and `1.06 Lamp`).
  Retained commands are now ignored, logged as a warning and cleared from the
  broker; empty payloads (the clearing message) are not executed.

## [1.0.235-fork-4] - 2026-10-19

### Added
- **Hold and release triggers for Scene Activation inputs**: the HC3 lists
  only some scene ids in `availableScenes` (e.g. 16/14/26/24 on an FGD-212),
  while the module also sends hold (12/22) and release (13/23). These triggers
  are now created for every input that appears.

### Fixed
- **Remote controller sensors rejected every key press**: their discovery
  carried `state_class: measurement`, so Home Assistant refused the text state
  (e.g. `1-button_short_press`) and the sensor stayed `unavailable`. The
  `state_class` is now only sent for numeric sensors, which also removes it
  from binary sensors.

## [1.0.235-fork-3] - 2026-10-19

### Added
- **S1/S2 triggers for modules that use Scene Activation** (e.g. FGD-212
  firmware 3.5): the "Switch" device's `availableScenes` become the same
  Home Assistant device triggers as Central Scene buttons. Presses arrive as
  `SceneActivationEvent` or as a `sceneActivation` property update on the
  dimmer; both are handled, and a press reported both ways fires once.
- **CI and automatic releases** (`.github/workflows/ci.yml`): every pull
  request and push to `master` runs a Lua syntax check, luacheck, tests against
  a mocked HC3 (`tests/run_tests.lua`), an `.fqa` sync check and a version
  consistency check. A push to `master` with a new `QUICKAPP_VERSION` creates
  the GitHub release with the `.fqa` attached.

### Removed
- **`scripts/create_release.ps1`**: replaced by the release job in
  `.github/workflows/ci.yml`.

## [1.0.235-fork-2] - 2026-10-19

### Added
- **S1/S2 switch inputs as Home Assistant device triggers**: every included
  device with central scene support (dimmers and relays such as FGD-212,
  FGS-213, FGS-223, not only remote controllers) gets a device trigger per
  button and press type. Scene events on `homeassistant/event/<id>` now carry a
  `trigger` field (e.g. `"1-pressed2"`) that these triggers match on.

### Fixed
- **Crash when `mqttConvention` is empty or unknown**: the default convention
  was stored at index 0, which the code never reads. It now falls back to Home
  Assistant and warns about unknown names.
- **Remote controller triggers never fired**: they listened on a topic nothing
  published to. All button triggers now listen on `homeassistant/event/<id>`.
- **Remote controller sensor stopped showing key presses** since scene events
  were only published to `homeassistant/event/<id>`. Remote controllers update
  their sensor again; dimmers still don't, so a press can't overwrite their
  brightness.
- **Central scene events of included devices without an own entity** were
  dropped; they are now forwarded too.
- **Linked entities of newly added or modified devices** (energy, power and
  battery sensors, button triggers) were only announced to Home Assistant after
  a QuickApp restart; they are now published right away.
- **Entities stuck on "unavailable" after another bridge went offline**: the
  availability topic `homeassistant/hc3-status` is retained and shared. When a
  second bridge instance was removed, its `offline` overwrote ours and every
  entity stayed unavailable until this QuickApp reconnected. Each heartbeat now
  re-publishes `online` on that topic, so the bridge recovers by itself within
  one `hbInterval`.
## [1.0.235-fork-1]

### Fixed
- **Heartbeat interval QuickApp variable**: code and README now agree on the
  variable name `hbInterval` (and `hbIncludeMeta`); previously the code read
  `hbinterval` while the README documented `heartbeatInterval`. Both variables
  are created with defaults on first start.
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
- **`heartbeatIncludeMeta` QuickApp variable**. Set to `false` to omit IP /
  version / device counts from the heartbeat payload (privacy / shared-broker
  scenarios).
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
- **Input validation** for `mqttKeepAlive` and `heartbeatInterval`
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

### Added (initial fork)
- Periodic heartbeat/alive MQTT message on `homeassistant/hc3-heartbeat`.
- Sensor `device_class` mapping based on unit of measurement (A, V, W, kWh,
  Wh, °C/°F, lx, %), based on Eroi69's fix.
- `state_class = measurement` for non-energy sensors.

### Forked from (initial fork)
- alexander-vitishchenko/hc3-to-mqtt v1.0.235.
