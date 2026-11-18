-- Runs the QuickApp sources against a mocked HC3 runtime.
-- Usage: lua tests/run_tests.lua [src-dir]   (needs the dkjson rock)
local dk = require("dkjson")
local SRC = arg[1] or "src"

local fails = 0
local function check(cond, msg)
    if cond then print("ok:   " .. msg) else fails = fails + 1; print("FAIL: " .. msg) end
end

-- Mocked HC3 runtime -------------------------------------------------------
local devices = {
    { id = 1, name = "Root", parentId = 0, baseType = "com.fibaro.device", type = "com.fibaro.zwaveDevice",
      enabled = true, visible = false, interfaces = {"zwave"}, properties = {}, actions = {} },
    { id = 226, name = "Dimmer", parentId = 1, baseType = "com.fibaro.multilevelSwitch", type = "com.fibaro.FGD212",
      enabled = true, visible = true, interfaces = {"light", "zwave", "zwaveCentralScene"},
      properties = { value = 40, dead = false,
          centralSceneSupport = {
              { keyId = 1, keyAttributes = {"Pressed", "Released", "HeldDown", "Pressed2", "Pressed3"} },
              { keyId = 2.0, keyAttributes = {"Pressed", "Pressed2"} } } },
      actions = { turnOn = 0, turnOff = 0, setValue = 1 } },
    -- FGD-212 with Scene Activation (as reported by a real HC3): hidden Z-Wave
    -- node, a "Switch" child with availableScenes, and the dimmer itself
    { id = 170, name = "1.03 Spots Device", parentId = 1, baseType = "com.fibaro.device", type = "com.fibaro.zwaveDevice",
      enabled = true, visible = false, interfaces = {"zwave"}, properties = {}, actions = {} },
    { id = 172, name = "1.03 Spots Switch", parentId = 170, baseType = "com.fibaro.actor", type = "com.fibaro.remoteController",
      enabled = true, visible = true, interfaces = {"zwave", "zwaveSceneActivationEvent"},
      properties = { dead = false, zwaveCompany = "Fibargroup",
          availableScenes = { { name = "", sceneId = 26 }, { name = "", sceneId = 16 }, { name = "", sceneId = 24 }, { name = "", sceneId = 14 } } },
      actions = { reconfigure = 0 } },
    { id = 173, name = "1.03 Spots", parentId = 170, baseType = "com.fibaro.multilevelSwitch", type = "com.fibaro.FGD212",
      enabled = true, visible = true, interfaces = {"light", "zwave", "zwaveSceneActivation"},
      properties = { value = 40, dead = false, state = true, sceneActivation = 26 },
      actions = { turnOn = 0, turnOff = 0, setValue = 1 } },
    { id = 300, name = "KeyFob", parentId = 0, baseType = "com.fibaro.remoteController", type = "com.fibaro.FGKF601",
      enabled = true, visible = true, interfaces = {"zwave", "battery"},
      properties = { dead = false, batteryLevel = 90,
          centralSceneSupport = { { keyId = 1, keyAttributes = {"Pressed"} } } },
      actions = {} },
}

fibaroCalls = {}
json = { encode = function(t) return dk.encode(t) end, decode = function(s) return dk.decode(s) end }
unpack = table.unpack
plugin = { mainDeviceId = 999 }
api = {
    get = function(path)
        if path == "/devices" then return devices end
        if path:find("network") then return { networkConfig = { eth0 = { enabled = true, ipConfig = { ip = "10.0.0.2" } } } } end
        local id = tonumber(path:match("/devices/(%d+)"))
        for _, d in ipairs(devices) do if d.id == id then return d end end
    end,
    post = function()
        local out = {}
        for _, d in ipairs(devices) do if d.visible then out[#out + 1] = { id = d.id } end end
        return out
    end,
}
-- Timers are recorded and only run when a test calls runTimers()
timers = {}
local nextTimerId = 0
fibaro = {
    getRoomNameByDeviceID = function() return "Living room" end,
    getGlobalVariable = function() return nil end,
    setTimeout = function(ms, fn)
        nextTimerId = nextTimerId + 1
        timers[nextTimerId] = { ms = ms, fn = fn }
        return nextTimerId
    end,
    clearTimeout = function(id) timers[id] = nil end,
    call = function(id, action, ...) fibaroCalls[#fibaroCalls + 1] = { id = id, action = action, args = {...} } end,
}
-- HTTP requests to the HC3 events feed are recorded; a test answers them
httpRequests = {}
net = { HTTPClient = function() return { request = function(_, url, opts)
    httpRequests[#httpRequests + 1] = { url = url, opts = opts }
end } end }
-- Every MQTT client is recorded with its event listeners
mqttClients = {}
mqtt = { Client = { connect = function()
    local c = { listeners = {}, disconnected = false, published = {} }
    function c:addEventListener(name, fn) self.listeners[name] = fn end
    function c:disconnect() self.disconnected = true end
    function c:publish(topic, payload, opts) self.published[#self.published + 1] = { topic = topic, payload = payload, opts = opts } end
    function c:subscribe() end
    mqttClients[#mqttClients + 1] = c
    return c
end } }
QuickApp = {}

for _, f in ipairs({"tools", "device_api", "device_helper", "mqtt_convention_api", "main"}) do
    dofile(SRC .. "/" .. f .. ".lua")
end

local function newQuickApp(variables, warnings)
    local qa = setmetatable({ properties = { quickAppVariables = {} } }, { __index = QuickApp })
    local noop = function() end
    qa.debug, qa.trace, qa.error = noop, noop, noop
    qa.warning = function(_, msg) if warnings then warnings[#warnings + 1] = msg end end
    qa.updateView, qa.updateProperty = noop, noop
    qa.getVariable = function(_, name) return variables[name] or "" end
    return qa
end

-- Central scene: S1/S2 and remote buttons as HA device triggers -----------
local published = {}
local qa = newQuickApp({ mqttConvention = "home-assistant" })
qa.mqtt = { publish = function(_, topic, payload, opts)
    published[#published + 1] = { topic = topic, payload = payload, retain = opts and opts.retain }
end }
qa.mqttConventions = { clone(MqttConventionHomeAssistant) }
qa.mqttConventions[1].mqtt = qa.mqtt
qa:publishDeviceNodeToMqtt(qa:discoverDeviceHierarchy())

local triggers = {}
for _, m in ipairs(published) do
    if m.topic:match("^homeassistant/device_automation/.+/config$") then
        triggers[#triggers + 1] = dk.decode(m.payload)
    end
end
check(#triggers == 16, "16 device triggers discovered (7 central scene dimmer, 4 scene activation + hold/release for S1 and S2, 1 remote), got " .. #triggers)

-- HA rejects text states on sensors with a state_class
for _, m in ipairs(published) do
    local id = m.topic:match("^homeassistant/sensor/(%d+)/config$")
    if id == "172" or id == "300" then
        check(dk.decode(m.payload).state_class == nil, "remote sensor #" .. id .. " has no state_class")
    end
end
for _, t in ipairs(triggers) do
    if not (t.device and t.device.identifiers) then check(false, "trigger " .. tostring(t.payload) .. " has device info") end
end

-- Simulates HA: a trigger fires when {{ value_json.trigger }} equals its payload
local function dispatch(event)
    local before = #published
    qa:dispatchFibaroEventToMqtt(event)
    local fired, msgs = {}, {}
    for i = before + 1, #published do
        local m = published[i]
        msgs[#msgs + 1] = m
        for _, t in ipairs(triggers) do
            local v = (t.topic == m.topic) and dk.decode(m.payload)
            if v and v.trigger == t.payload then fired[#fired + 1] = t.subtype .. "/" .. t.type end
        end
    end
    return fired, msgs
end

local function press(id, keyId, attr)
    return dispatch({ type = "CentralSceneEvent", data = { id = id, keyId = keyId, keyAttribute = attr } })
end

local fired, msgs = press(226, 1, "Pressed")
check(#fired == 1 and fired[1] == "button_1/button_short_press", "S1 short press fires button_1/button_short_press")
local touched = false
for _, m in ipairs(msgs) do if m.topic:match("light/226/.*/value$") then touched = true end end
check(not touched, "S1 press does not overwrite the dimmer brightness")
check(msgs[1] ~= nil and msgs[1].retain == false, "scene event is published non-retained")

fired = press(226, 2, "Pressed2")
check(#fired == 1 and fired[1] == "button_2/button_double_press", "S2 double press fires button_2/button_double_press (keyId 2.0 in metadata)")

fired = press(226, 1, "HeldDown")
check(#fired == 1 and fired[1] == "button_1/button_long_press", "S1 hold fires button_1/button_long_press")

fired, msgs = press(300, 1, "Pressed")
check(#fired == 1, "remote button press fires its trigger")
local sensorUpdated = false
for _, m in ipairs(msgs) do
    if m.topic:match("sensor/300/.*/value$") and m.payload:find("1%-button_short_press") then sensorUpdated = true end
end
check(sensorUpdated, "remote sensor shows the last key press")

fired = press(1, 1, "Pressed")
check(#fired == 0, "events from excluded (hidden) devices are ignored")

-- Scene Activation (FGD-212 with parameter 28 = 1) --------------------------
fired, msgs = dispatch({ type = "SceneActivationEvent", data = { id = 172, sceneId = 26 } })
check(#fired == 1 and fired[1] == "button_2/button_short_press", "SceneActivationEvent 26 fires button_2/button_short_press")
sensorUpdated = false
for _, m in ipairs(msgs) do
    if m.topic:match("sensor/172/.*/value$") and m.payload:find("2%-button_short_press") then sensorUpdated = true end
end
check(sensorUpdated, "switch sensor #172 shows the last scene")

fired, msgs = dispatch({ type = "DevicePropertyUpdatedEvent", data = { id = 173, property = "sceneActivation", newValue = 16 } })
check(#fired == 1 and fired[1] == "button_1/button_short_press", "sceneActivation property 16 on the dimmer fires the switch's button_1/button_short_press")
touched = false
for _, m in ipairs(msgs) do if m.topic:match("light/173/") then touched = true end end
check(not touched, "scene activation does not touch the dimmer's own topics")

local total = 0
fired = dispatch({ type = "SceneActivationEvent", data = { id = 172, sceneId = 14 } }); total = total + #fired
fired = dispatch({ type = "DevicePropertyUpdatedEvent", data = { id = 173, property = "sceneActivation", newValue = 14 } }); total = total + #fired
check(total == 1, "the same press reported as event and as property update fires once (" .. total .. ")")

fired = dispatch({ type = "SceneActivationEvent", data = { id = 172, sceneId = 12 } })
check(#fired == 1 and fired[1] == "button_1/button_long_press", "scene 12 (not in availableScenes) fires button_1/button_long_press")
fired = dispatch({ type = "SceneActivationEvent", data = { id = 172, sceneId = 23 } })
check(#fired == 1 and fired[1] == "button_2/button_long_release", "scene 23 fires button_2/button_long_release")

-- Commands from Home Assistant ----------------------------------------------
local commandTopic = "homeassistant/light/226/events/home assistant => fibaro/state"
local function command(payload, retain)
    fibaroCalls = {}
    local before = #published
    qa:onMessage({ topic = commandTopic, payload = payload, retain = retain })
    local republished = {}
    for i = before + 1, #published do republished[#republished + 1] = published[i] end
    return fibaroCalls, republished
end

local calls, republished = command("true", false)
check(#calls == 1 and calls[1].id == 226 and calls[1].action == "turnOn", "live 'true' command turns device #226 on")

calls, republished = command("true", true)
check(#calls == 0, "retained command (replayed on reconnect) is not executed")
check(#republished == 1 and republished[1].topic == commandTopic and republished[1].payload == "" and republished[1].retain == true,
    "retained command is cleared from the broker")

calls = command("", false)
check(#calls == 0, "empty payload (the clearing message) is not executed")

-- MQTT convention selection -------------------------------------------------
for _, case in ipairs({
    { value = "", expected = "Home Assistant" },
    { value = "home-assistant", expected = "Home Assistant" },
    { value = "typo", expected = "Home Assistant", warns = true },
    { value = "homie,home-assistant", expected = "Homie,Home Assistant" },
}) do
    local warnings = {}
    local q = newQuickApp({ mqttConvention = case.value, mqttUrl = "mqtt://broker" }, warnings)
    local ok, err = pcall(q.establishMqttConnection, q)
    local names = {}
    for _, c in ipairs(q.mqttConventions or {}) do names[#names + 1] = c.type end
    check(ok and table.concat(names, ",") == case.expected,
        string.format("mqttConvention=%q connects with %s%s", case.value, case.expected, ok and "" or (" (" .. tostring(err) .. ")")))
    if case.warns then check(#warnings > 0, "unknown mqttConvention is logged") end
end

-- Reconnect after errors ------------------------------------------------------
-- Runs the timers that are pending now (not the ones they schedule)
local function runTimers()
    local ids = {}
    for id in pairs(timers) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local t = timers[id]
        if t then timers[id] = nil; t.fn() end
    end
end
local function pendingTimer(ms)
    for _, t in pairs(timers) do if t.ms == ms then return true end end
    return false
end
local function lastPoll() return httpRequests[#httpRequests].opts end

timers, httpRequests, mqttClients = {}, {}, {}
local rq = newQuickApp({ mqttUrl = "mqtt://broker", hbInterval = "60" })
rq.startTime = os.time()
rq:turnOn()
check(#mqttClients == 1, "turnOn opens one MQTT connection")
mqttClients[1].listeners.connected({})
runTimers()
check(#httpRequests == 1, "after connecting the bridge polls the HC3 events feed")

for _ = 1, 5 do
    lastPoll().error("Host not found (authoritative)")
    runTimers()
end
check(#httpRequests == 6, "a failed poll is retried 5 times (" .. #httpRequests .. " polls)")
check(not mqttClients[1].disconnected, "MQTT stays connected while polls are retried")

lastPoll().error("Host not found (authoritative)")
check(mqttClients[1].disconnected, "the 6th failure in a row disconnects MQTT")
check(pendingTimer(10000), "a reconnect is scheduled after 10 s")
runTimers()
check(#mqttClients == 2, "the bridge reconnects by itself")

mqttClients[1].listeners.connected({})
check(not rq.hc3ConnectionEnabled, "a late 'connected' of the old client is ignored")
local polls = #httpRequests
mqttClients[2].listeners.connected({})
runTimers()
check(#httpRequests == polls + 1, "only the new connection polls the HC3, no duplicate chain")
lastPoll().success({ status = 200, data = '{"status":"IDLE","last":5,"events":[]}' })
check(rq.reconnectAttempts == 0 and rq.hc3FetchFailures == 0, "a successful poll resets the failure and reconnect counters")

runTimers()
polls = #httpRequests
lastPoll().success({ status = 200, data = "{not json" })
runTimers()
check(#httpRequests == polls + 1 and not mqttClients[2].disconnected, "an error while processing events does not stop polling")

-- reconnect delay grows while the problem persists
mqttClients[2].listeners.error({ code = 1 })
check(pendingTimer(10000), "an MQTT error schedules a reconnect after 10 s")
runTimers()
check(#mqttClients == 3, "reconnected after the MQTT error")
mqttClients[3].listeners.error({ code = 1 })
check(pendingTimer(20000), "a second failure in a row waits 20 s")

rq:turnOff()
runTimers()
check(#mqttClients == 3, "a manual turn off cancels the pending reconnect")

rq:turnOn()
check(#mqttClients == 4, "turnOn after a manual turn off connects again")
mqttClients[4].listeners.connected({})
runTimers()
mqttClients[4].listeners.closed({})
check(mqttClients[4].disconnected and pendingTimer(10000), "an unexpected close schedules a reconnect")
runTimers()
check(#mqttClients == 5, "reconnected after the unexpected close")

local closedClient = mqttClients[5]
mqttClients[5].listeners.connected({})
rq:turnOn()
check(closedClient.disconnected and #mqttClients == 6, "turnOn on a live connection replaces it instead of adding a second one")
check(not pendingTimer(10000), "closing the replaced connection does not schedule a reconnect")

print(fails == 0 and "ALL TESTS PASSED" or (fails .. " TEST(S) FAILED"))
os.exit(fails == 0 and 0 or 1)
