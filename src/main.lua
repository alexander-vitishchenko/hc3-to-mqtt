--[[ RELEASE NOTES FOR 1.0.235-fork-6
Summary: The bridge reconnects by itself after errors

Description:
- A failed poll of the HC3 events feed (e.g. "Host not found") turned the bridge off
  for good; it is now retried, and after 5 failures in a row MQTT and HC3 are reconnected
- An error while processing HC3 events no longer stops the polling chain
- An MQTT connection that closes without an error event (e.g. broker restart) is reconnected
- Reconnect delay grows from 10 s to at most 5 min while the problem persists
- A manual turn off is not undone by a pending reconnect; turnOn on a live connection
  replaces it instead of opening a second one
- Events of a replaced MQTT client and replies to an earlier polling chain are ignored,
  so a reconnect never leaves duplicate connections or polling chains behind

Earlier fork changes (1.0.235-fork-5):
- A retained command was replayed on every (re)connect and switched devices on again;
  it is now ignored and removed from the broker

Earlier fork changes (1.0.235-fork-4):
- Remote controller sensors no longer get state_class "measurement" (HA rejected their text state)
- state_class only for numeric sensors, not binary sensors
- Hold/release triggers for every Fibaro Scene Activation input

Earlier fork changes (1.0.235-fork-3):
- Scene Activation ids (availableScenes, SceneActivationEvent, "sceneActivation"
  property) are mapped to the same S1/S2 device triggers as Central Scene

Earlier fork changes (1.0.235-fork-2):
- Device triggers per button and press type for every device with central scene
  support (dimmers/relays such as FGD-212, FGS-213, FGS-223, and remote controllers)
- Remote controller triggers and key-press sensor work again
- Fixed crash when "mqttConvention" is empty or unknown

Earlier fork changes (1.0.235-fork-1):
- Added periodic heartbeat/alive MQTT message on topic "homeassistant/hc3-heartbeat"
  Configurable interval via QuickApp variable "hbInterval" (default: 60 seconds)
  Payload includes: status, timestamp, uptime, version, device/entity count, IP address
  IP/version disclosure can be disabled via QuickApp variable "hbIncludeMeta=false"
- Fixed device_class mapping for sensors based on unit (A, V, W, kWh, Wh, °C, lx, %)
  (based on Eroi69's fork)
- Added state_class "measurement" for non-energy sensors
- Forked from alexander-vitishchenko/hc3-to-mqtt v1.0.235
]]--

local QUICKAPP_VERSION = "1.0.235-fork-6"
local DEFAULT_HEARTBEAT_INTERVAL = 60
local DEFAULT_RECONNECT_DELAY_MS = 10000
local MAX_RECONNECT_DELAY_MS = 300000
local MAX_HC3_FETCH_RETRIES = 5
local DEFAULT_KEEPALIVE = 60
local FAST_POLL_DELAY_MS = 50
local SLOW_POLL_DELAY_MS = 1000
local HC3_REFRESH_STATES_URL = "http://127.0.0.1:11111/api/refreshStates"

developmentMode = false

function QuickApp:onInit()
    self.startTime = os.time()

    self:debug("")
    self:debug("------- HC3 <-> MQTT BRIDGE")
    self:debug("Version: " .. QUICKAPP_VERSION)
    self:debug("Fork changes: heartbeat/alive MQTT message, S1/S2 and remote buttons as device triggers, automatic reconnect after errors")
    self:debug("(!) IMPORTANT NOTE FOR THOSE USERS WHO USED THE QUICKAPP PRIOR TO 1.0.191 VERSION: Your Home Assistant dashboards and automations need to be reconfigured with new entity ids. This is a one-time effort that introduces a relatively \"small\" inconvenience for the greater good (a) introduce long-term stability so Home Assistant entity duplicates will not happen in certain scenarios (b) entity id namespaces are now synchronized between Fibaro and Home Assistant ecosystems")

    -- Create optional variables with defaults if absent (avoids "Variable not found" warnings on every start)
    if self:getVariable("hbInterval") == "" then
        self:setVariable("hbInterval", tostring(DEFAULT_HEARTBEAT_INTERVAL))
    end
    if self:getVariable("hbIncludeMeta") == "" then
        self:setVariable("hbIncludeMeta", "true")
    end

    self:turnOn()
end

-- turnOn/turnOff are what the HC3 UI and the REST API
-- (/api/devices/<id>/action/turnOn|turnOff) call, e.g. from a Home Assistant watchdog.
-- Internal recovery uses reconnectLater() instead.
function QuickApp:turnOn()
    self:cancelScheduledReconnect()
    self.reconnectAttempts = 0
    if self.mqtt then
        -- a second connection next to a live one would duplicate every event
        self:disconnectFromMqttAndHc3()
    end
    self:establishMqttConnection()
end

function QuickApp:turnOff()
    -- a manual turn off must not be undone by a pending automatic reconnect
    self:cancelScheduledReconnect()
    self:disconnectFromMqttAndHc3()
end

function QuickApp:establishMqttConnection() 
    -- IDENTIFY WHICH MQTT CONVENTIONS TO BE USED (e.g. Home Assistant, Homio, etc)
    self.mqttConventions = { }
    local mqttConventionStr = self:getVariable("mqttConvention")
    if (isNotEmptyString(mqttConventionStr)) then
        for _, conventionName in ipairs(splitString(mqttConventionStr, ",")) do
            local convention = mqttConventionMappings[conventionName]
            if (convention) then
                table.insert(self.mqttConventions, clone(convention))
            else
                self:warning("Unknown mqttConvention '" .. conventionName .. "' ignored")
            end
        end
    end
    if (#self.mqttConventions == 0) then
        table.insert(self.mqttConventions, clone(MqttConventionHomeAssistant))
    end

    local mqttConnectionParameters = self:getMqttConnectionParameters()

    -- Anonymize MQTT username and password before being printed to log
    local status, anonymizedMqttConnectionParameters = pcall(clone, mqttConnectionParameters)
    if (not status) or (not anonymizedMqttConnectionParameters) then
        anonymizedMqttConnectionParameters = { note = "anonymization failed" }
    end
    if (anonymizedMqttConnectionParameters.username) then
        anonymizedMqttConnectionParameters.username = "anonymized-username"
    end
    if (anonymizedMqttConnectionParameters.password) then
        anonymizedMqttConnectionParameters.password = "anonymized-password"
    end
    self:trace("MQTT Connection Parameters: " .. json.encode(anonymizedMqttConnectionParameters))

    local mqttUrl = self:getVariable("mqttUrl")
    if isEmptyString(mqttUrl) then
        self:error("'mqttUrl' QuickApp variable is not set; cannot connect to MQTT broker")
        return
    end
    self:trace("MQTT URL: " .. sanitizeMqttUrl(mqttUrl))

    local mqttClient = mqtt.Client.connect(
                                    mqttUrl,
                                    mqttConnectionParameters)

    -- Events of a client that we closed or replaced are ignored; a late
    -- 'connected' would otherwise start a second polling chain.
    mqttClient:addEventListener('connected', function(event)
        if self.mqtt == mqttClient then
            self:onConnected(event)
        else
            pcall(function() mqttClient:disconnect() end)
        end
    end)
    mqttClient:addEventListener('closed', function(event)
        if self.mqtt == mqttClient then
            -- closed without us asking for it, e.g. a broker restart
            self:onClosed(event)
            self:reconnectLater("MQTT connection closed unexpectedly")
        elseif self.mqtt == nil then
            self:onClosed(event)
        end
    end)
    mqttClient:addEventListener('message', function(event)
        if self.mqtt == mqttClient then
            self:onMessage(event)
        end
    end)
    mqttClient:addEventListener('error', function(event)
        if self.mqtt == mqttClient then
            self:onError(event)
        end
    end)

    self.mqtt = mqttClient
end

function QuickApp:getMqttConnectionParameters()
    local mqttConnectionParameters = {
        -- pickup last will from primary MQTT Convention provider
        lastWill = self.mqttConventions[1]:getLastWillMessage()
    }

    -- MQTT CLIENT ID (OPTIONAL)
    local mqttClientId = self:getVariable("mqttClientId")
    if (isEmptyString(mqttClientId)) then
        local autogeneratedMqttClientId = "HC3-" .. plugin.mainDeviceId .. "-" .. tostring(os.time())
        self:debug("All is good - mqttClientId has been generated for you automatically \"" .. autogeneratedMqttClientId .. "\"")
        mqttConnectionParameters.clientId = autogeneratedMqttClientId
    else
        mqttConnectionParameters.clientId = mqttClientId
    end

    -- MQTT KEEP ALIVE PERIOD
    local mqttKeepAlivePeriod = self:getVariable("mqttKeepAlive")
    local parsedKeepAlive = tonumber(mqttKeepAlivePeriod)
    if parsedKeepAlive and parsedKeepAlive > 0 then
        mqttConnectionParameters.keepAlivePeriod = parsedKeepAlive
    else
        mqttConnectionParameters.keepAlivePeriod = DEFAULT_KEEPALIVE
    end

    -- MQTT AUTH (USERNAME/PASSWORD)
    local mqttUsername = self:getVariable("mqttUsername")
    local mqttPassword = self:getVariable("mqttPassword")

    if (mqttUsername) then
        mqttConnectionParameters.username = mqttUsername
    end
    if (mqttPassword) then
        mqttConnectionParameters.password = mqttPassword
    end

    return mqttConnectionParameters
end

function QuickApp:disconnectFromMqttAndHc3()
    self.hc3ConnectionEnabled = false

    local client = self.mqtt
    if not client then
        return
    end
    -- Forget the client before closing it, so its 'closed' event reads as an
    -- intentional disconnect and does not trigger a reconnect
    self.mqtt = nil
    self:closeMqttConnection(client)
end

function QuickApp:closeMqttConnection(client)
    for _, j in ipairs(self.mqttConventions or {}) do
        if (j.mqtt ~= MqttConventionPrototype.mqtt) then
            -- the connection may already be gone; publishing "offline" is best effort
            local ok, err = pcall(function() j:onDisconnected() end)
            if not ok then
                self:warning("Could not publish offline status: " .. tostring(err))
            end
        end
    end

    local ok, err = pcall(function() client:disconnect() end)
    if not ok then
        self:warning("Closing the MQTT connection failed: " .. tostring(err))
    end
end

function QuickApp:onClosed(event)
    self:updateProperty("value", false)
    self:debug("")
    self:debug("------- Disconnected from MQTT/Home Assistant")
end

function QuickApp:onError(event)
    self:error("MQTT ERROR: " .. json.encode(event))
    if event.code == 2 then
        self:warning("MQTT username and/or password is possibly indicated wrongly")
    end
    self:reconnectLater("MQTT error")
end

-- Internal recovery: drop the MQTT and HC3 connections and connect again later
function QuickApp:reconnectLater(reason)
    self:disconnectFromMqttAndHc3()
    self:scheduleReconnectToMqtt(reason)
end

function QuickApp:scheduleReconnectToMqtt(reason)
    self:cancelScheduledReconnect()

    -- 10 s, 20 s, 40 s, ... up to 5 min while the problem persists; reset after
    -- the first successful HC3 poll or a manual turnOn
    self.reconnectAttempts = (self.reconnectAttempts or 0) + 1
    local delay = math.min(DEFAULT_RECONNECT_DELAY_MS * (2 ^ (self.reconnectAttempts - 1)), MAX_RECONNECT_DELAY_MS)
    delay = math.floor(delay)
    self:warning((reason or "Connection lost") .. "; reconnecting in " .. math.floor(delay / 1000) .. "s (attempt " .. self.reconnectAttempts .. ")")

    self.reconnectTimer = fibaro.setTimeout(delay, function()
        self.reconnectTimer = nil
        if self.mqtt then
            -- someone already connected again in the meantime
            return
        end
        self:debug("Attempt to reconnect to MQTT...")
        self:establishMqttConnection()
    end)
end

function QuickApp:cancelScheduledReconnect()
    if self.reconnectTimer then
        fibaro.clearTimeout(self.reconnectTimer)
        self.reconnectTimer = nil
    end
end

function QuickApp:onMessage(event)
    -- A retained command is replayed by the broker on every (re)connect and would
    -- switch the device again each time; drop it and clear it from the broker
    if event.retain then
        self:warning("Ignoring retained MQTT command on '" .. tostring(event.topic) .. "' (payload '" .. tostring(event.payload) .. "') and removing it from the broker")
        self.mqtt:publish(event.topic, "", {retain = true})
        return
    end
    -- Empty payloads are what clearing a retained message looks like; not a command
    if isEmptyString(event.payload) then
        return
    end

    for i, j in ipairs(self.mqttConventions) do
        j:onHomeAssistantEvent(event)
    end
end

function QuickApp:onConnected(event) 
    self:debug("")
    self:debug("------- Connected to MQTT/Home Assistant")

    -- Discovery reads the HC3 API; if that fails the bridge must not stay
    -- connected to MQTT without delivering anything
    local ok, err = pcall(function()
        for _, mqttConvention in ipairs(self.mqttConventions) do
            mqttConvention.mqtt = self.mqtt
            mqttConvention:onConnected()
        end

        self:discoverDevicesAndPublishToMqtt()
    end)
    if not ok then
        self:error("Device discovery failed: " .. tostring(err))
        self:reconnectLater("Device discovery failed")
        return
    end

    self.hc3ConnectionEnabled = true
    self:scheduleHc3EventsFetcher()

    self:updateProperty("value", true)

    -- Start periodic heartbeat/alive message; bump generation so any
    -- previously-scheduled timer chain from a prior connection self-cancels.
    self.heartbeatGeneration = (self.heartbeatGeneration or 0) + 1
    self:scheduleHeartbeat(self.heartbeatGeneration)
end

--[[
    HEARTBEAT / ALIVE MESSAGE
    Publishes a periodic status message to MQTT so Home Assistant can monitor
    whether the HC3 bridge is alive and responsive.

    Topic: homeassistant/hc3-heartbeat
    Interval: configurable via "hbInterval" QuickApp variable (default: 60 seconds)

    Each heartbeat also re-publishes "online" on the retained availability
    topic (homeassistant/hc3-status), see refreshAvailability().

    Optional QuickApp variables:
    - hbIncludeMeta = "false" to omit IP/version/device counts (privacy)

    Payload example (with meta):
    {
        "status": "online",
        "timestamp": "2025-01-15T14:30:00Z",
        "uptime": 3600,
        "version": "1.0.235-fork-6",
        "devices": 42,
        "entities": 58,
        "ip": "192.168.1.100"
    }

    The `generation` parameter ensures that if the QuickApp reconnects (and
    starts a new heartbeat chain), older chains stop instead of running in
    parallel.
]]--
function QuickApp:scheduleHeartbeat(generation)
    if not self.hc3ConnectionEnabled then
        return
    end
    -- Cancel ourselves if a newer generation has been started (e.g. reconnect)
    if generation ~= self.heartbeatGeneration then
        return
    end

    -- Read configurable interval; reject non-positive values
    local rawInterval = self:getVariable("hbInterval")
    local heartbeatInterval = tonumber(rawInterval)
    if (not heartbeatInterval) or heartbeatInterval <= 0 then
        if isNotEmptyString(rawInterval) then
            self:warning("Invalid hbInterval '" .. tostring(rawInterval) .. "' - falling back to default " .. DEFAULT_HEARTBEAT_INTERVAL .. "s")
        end
        heartbeatInterval = DEFAULT_HEARTBEAT_INTERVAL
    end

    -- Build heartbeat payload. Meta (IP/version/counts) can be opted out.
    local includeMeta = self:getVariable("hbIncludeMeta")
    local payloadTable = {
        status = "online",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        uptime = os.time() - self.startTime,
    }
    if includeMeta ~= "false" then
        payloadTable.version = QUICKAPP_VERSION
        payloadTable.devices = allFibaroDevicesAmount or 0
        payloadTable.entities = identifiedHaEntitiesAmount or 0
        payloadTable.ip = localIpAddress or "unknown"
    end

    local published, err = pcall(function()
        self.mqtt:publish("homeassistant/hc3-heartbeat", json.encode(payloadTable), {retain = true})
    end)
    if not published then
        self:warning("Heartbeat publish failed: " .. tostring(err))
    else
        self:trace("Heartbeat published (next in " .. heartbeatInterval .. "s)")
    end

    -- Re-assert availability ("online" on homeassistant/hc3-status) so a stale
    -- retained "offline" from another bridge instance cannot keep entities
    -- unavailable. Separate pcall: a failure here must not stop the heartbeat.
    for _, mqttConvention in ipairs(self.mqttConventions) do
        local refreshed, refreshErr = pcall(function()
            mqttConvention:refreshAvailability()
        end)
        if not refreshed then
            self:warning("Availability refresh failed for " .. tostring(mqttConvention.type) .. ": " .. tostring(refreshErr))
        end
    end

    -- Schedule next heartbeat in same generation
    fibaro.setTimeout(heartbeatInterval * 1000, function()
        self:scheduleHeartbeat(generation)
    end)
end

function QuickApp:discoverDevicesAndPublishToMqtt()
    local startTime = os.time()
    local phaseStartTime = startTime
    
    local deviceHierarchyRootNode = self:discoverDeviceHierarchy()
    local phaseEndTime = os.time()
    
    self:debug("")
    self:debug("-------- Fibaro device discovery completed in " .. (phaseEndTime - phaseStartTime) .. " second(s)")
    self:debug("Total Fibaro devices                 : " .. allFibaroDevicesAmount)
    self:debug("Filtered Fibaro devices to           : " .. filteredFibaroDevicesAmount)
    self:debug("Number of Home Assistant entities    : " .. identifiedHaEntitiesAmount .. " => number of supported Fibaro devices + automatically generated entities for power, energy and battery sensors (when found appropriate interfaces for a Fibaro device) + automatically generated  remote controllers, where cartesian join is applied for each key and press types")
    self:debug("")
    printDeviceNodeHierarchy(deviceHierarchyRootNode, 0)

    phaseStartTime = os.time()
    self:publishDeviceNodeToMqtt(deviceHierarchyRootNode)
    phaseEndTime = os.time()    

    self:debug("")
    self:debug("------- Fibaro device configuration and states have been distributed to MQTT/Home Assistant in " .. (phaseEndTime - phaseStartTime) .. " second(s)")

    local diff = os.time() - startTime

    self:updateView("totalFibaroDevices", "text", "Total Fibaro devices: " .. allFibaroDevicesAmount)
    self:updateView("filteredFibaroDevices", "text", "Filtered Fibaro devices: " .. filteredFibaroDevicesAmount)
    self:updateView("haEntities", "text", "Home Assistant entities: " .. identifiedHaEntitiesAmount)
 
    self:updateView("bootTime" , "text", "Boot time: " .. diff .. "s")
end

function QuickApp:discoverDeviceHierarchy()
    local developmentModeStr = self:getVariable("developmentMode")
    if ((not developmentModeStr) or (developmentModeStr ~= "true")) then
        self:debug("Bridge mode: PRODUCTION")
    else
        self:debug("Bridge mode: DEVELOPMENT")
        developmentMode = true
    end

    local customDeviceFilterJsonStr = getCompositeQuickAppVariable(self, "deviceFilter")
    if (isEmptyString(customDeviceFilterJsonStr)) then
        self:debug("All is good - default filter applied, where only enabled and visible devices are used")
    end

    fibaroDevices = getDeviceHierarchyByFilter(customDeviceFilterJsonStr, self)

    return fibaroDevices
end

-- *** rename to "*AndItsChildren"
function QuickApp:publishDeviceNodeToMqtt(deviceNode)
    if (deviceNode.identifiedHaEntity) then
        self:__publishDeviceNodeToMqtt(deviceNode)
    end

    for _, fibaroDeviceChildNode in pairs(deviceNode.childNodeList) do
        self:publishDeviceNodeToMqtt(fibaroDeviceChildNode)
    end
end

function QuickApp:__publishDeviceNodeToMqtt(deviceNode)
    ------------------------------------------------------------------
    ------- ANNOUNCE DEVICE EXISTENCE
    ------------------------------------------------------------------
    for i, j in ipairs(self.mqttConventions) do
        j:onDeviceNodeCreated(deviceNode)
    end

    ------------------------------------------------------------------
    ------- ANNOUNCE DEVICE CURRENT STATE => BY SIMULATING HC3 EVENTS
    ------------------------------------------------------------------
    self:__publishDeviceProperties(deviceNode.fibaroDevice)
end

function QuickApp:__publishDeviceProperties(fibaroDevice)
    self:simulatePropertyUpdate(fibaroDevice, "dead", fibaroDevice.properties.dead)
    self:simulatePropertyUpdate(fibaroDevice, "state", fibaroDevice.properties.state)
    self:simulatePropertyUpdate(fibaroDevice, "value", fibaroDevice.properties.value)
    self:simulatePropertyUpdate(fibaroDevice, "value2", fibaroDevice.properties.value2)
    self:simulatePropertyUpdate(fibaroDevice, "heatingThermostatSetpoint", fibaroDevice.properties.heatingThermostatSetpoint)
    self:simulatePropertyUpdate(fibaroDevice, "thermostatMode", fibaroDevice.properties.thermostatMode)
    self:simulatePropertyUpdate(fibaroDevice, "energy", fibaroDevice.properties.energy)
    self:simulatePropertyUpdate(fibaroDevice, "power", fibaroDevice.properties.power)
    self:simulatePropertyUpdate(fibaroDevice, "batteryLevel", fibaroDevice.properties.batteryLevel)
    self:simulatePropertyUpdate(fibaroDevice, "color", fibaroDevice.properties.color)
end

function QuickApp:onPublished(event)
    -- do nothing, for now
end

-- FETCH HC3 EVENTS
local lastRefresh = 0
local hc3HttpClient = net.HTTPClient()

function QuickApp:scheduleHc3EventsFetcher()
    self.gotWarning = false
    self.hc3FetchFailures = 0

    -- Bump the generation so a polling chain of an earlier connection stops
    -- instead of running next to this one
    self.pollGeneration = (self.pollGeneration or 0) + 1
    self:scheduleAnotherPollingForHc3(self.pollGeneration)

    self:debug("")
    self:debug("------- Connected to Fibaro Home Center 3 events feed")
end

function QuickApp:scheduleAnotherPollingForHc3(generation)
    if generation ~= self.pollGeneration then
        return
    end

    if (self.hc3ConnectionEnabled) then
        local delay
        if self.gotWarning then
            -- avoid hitting errors with a "speed of light"
            delay = SLOW_POLL_DELAY_MS
        else
            -- provide fast events distribution to Home Assistant when no errors present
            delay = FAST_POLL_DELAY_MS
        end

        fibaro.setTimeout(delay, function()
            self:readHc3EventAndScheduleFetcher(generation)
        end)
    else
        self:debug("")
        self:debug("------- Disconnected from Fibaro HC3")
    end
end

function QuickApp:readHc3EventAndScheduleFetcher(generation)
    -- Reliable and high-performance method to get events from Fibaro HC3 using non-blocking HTTP calls
    if (generation ~= self.pollGeneration) or (not self.hc3ConnectionEnabled) then
        return
    end

    local requestUrl = HC3_REFRESH_STATES_URL .. "?last=" .. lastRefresh

    hc3HttpClient:request(
        requestUrl,
        {
        options = { },
        success=function(res)
            if generation ~= self.pollGeneration then
                return
            end
            if (res and not isEmptyString(res.data)) then
                local ok, err = pcall(function()
                    self:processFibaroHc3Events(json.decode(res.data))
                end)
                if ok then
                    self.hc3FetchFailures = 0
                    self.reconnectAttempts = 0
                    self:scheduleAnotherPollingForHc3(generation)
                else
                    self:onHc3FetchFailed(generation, "Error while processing Fibaro HC3 events: " .. tostring(err))
                end
            else
                local statusStr = (res and tostring(res.status)) or "<no response>"
                local bodyStr = res and json.encode(res) or "<nil>"
                self:onHc3FetchFailed(generation, "Error while fetching events from Fibaro HC3. Response status: " .. statusStr .. ". Body: " .. bodyStr)
            end
        end,
        error=function(res)
            if generation ~= self.pollGeneration then
                return
            end
            self:onHc3FetchFailed(generation, "Error while fetching Fibaro HC3 events " .. json.encode(res))
        end
    })
end

-- A single failed poll (e.g. "Host not found" while the HC3 is busy) used to
-- turn the bridge off for good. Retry a few times, then reconnect everything.
function QuickApp:onHc3FetchFailed(generation, message)
    self.hc3FetchFailures = (self.hc3FetchFailures or 0) + 1
    if self.hc3FetchFailures <= MAX_HC3_FETCH_RETRIES then
        self:warning(message .. " (failure " .. self.hc3FetchFailures .. " of " .. MAX_HC3_FETCH_RETRIES .. ", retrying)")
        self.gotWarning = true
        self:scheduleAnotherPollingForHc3(generation)
    else
        self:error(message)
        self:reconnectLater("Fetching HC3 events failed " .. self.hc3FetchFailures .. " times in a row")
    end
end

function QuickApp:processFibaroHc3Events(data)
    self.gotWarning = false

    -- Simulate repeatable broken status
    --data.status = "STARTING_SERVICES"

    if (data.status ~= 200 and data.status ~= "IDLE") then
        self.gotWarning = true
        if (not data.status) then
            data.status = "<unknown>"
        end

        logWithoutRepetableWarnings(data)
    end

    local events = data.events

    if (data.last) then
        lastRefresh = data.last
    end

    if events and #events > 0 then 
        for i, v in ipairs(events) do
            self:dispatchFibaroEventToMqtt(v)
        end
    end
end

function QuickApp:simulatePropertyUpdate(fibaroDevice, propertyName, value)
    if value ~= nil then
        local event = createFibaroEventPayload(fibaroDevice, propertyName, value)
        self:dispatchFibaroEventToMqtt(event)
    end
end

local deviceModifiedEventTimestamps = {}
local deviceCreatedEventTimestamps = {}
function QuickApp:dispatchFibaroEventToMqtt(event)
    if (not event) then
        self:error("No event found")
        return
    end

    if (not event.data) then
        self:error("No event data found")
        return
    end

    local fibaroDeviceId = event.data.id or event.data.deviceId

    -- *** add origin event source id

    if not fibaroDeviceId then
        -- This is a system level event, which is not bound to a particular device => ignore
        return
    end 

    local eventType = event.type
    if (not eventType) then
        eventType = "<unknown>"
    end

    local deviceNode = getDeviceNodeById(fibaroDeviceId)

    if (deviceNode) then
        -- process events for devices that are required to be known to the QuickApp 
        if deviceNode.included then
            -- process events for devices that are included by user filter criteria

            -- Button presses are forwarded even for devices without an own HA entity
            if (eventType == "CentralSceneEvent") then
                return self:dispatchCentralSceneEvent(deviceNode, event)
            elseif (eventType == "SceneActivationEvent") then
                return self:dispatchSceneActivation(deviceNode, event.data.sceneId)
            elseif (eventType == "DevicePropertyUpdatedEvent") and (event.data.property == "sceneActivation") then
                return self:dispatchSceneActivation(deviceNode, event.data.newValue)
            end

            local haEntity = deviceNode.identifiedHaEntity
            if haEntity then
                if (eventType == "DevicePropertyUpdatedEvent") then
                    return self:dispatchDevicePropertyUpdatedEvent(deviceNode, event)
                elseif (eventType == "DeviceModifiedEvent") then
                    -- Fibaro generates "DeviceModifiedEvent" event after "DeviceCreatedEvent" => filter out the redundant event
                    local deviceLastCreationTimestamp = deviceCreatedEventTimestamps[fibaroDeviceId]
                    local deviceLastModificationTimestamp = deviceModifiedEventTimestamps[fibaroDeviceId]
                    if ((deviceLastCreationTimestamp) and (deviceLastCreationTimestamp == event.created)) then
                        self:debug("Ignore duplicate event for 'DeviceModifiedEvent' as it's called right after 'DeviceCreatedEvent'")
                        return
                    elseif ((deviceLastModificationTimestamp) and (deviceLastModificationTimestamp == event.created)) then
                        self:debug("Ignore duplicate event for 'DeviceModifiedEvent' as it's called right after another 'DeviceModifiedEvent'")
                        return
                    else
                        return self:dispatchDeviceModifiedEvent(deviceNode)
                    end
                elseif (eventType == "DeviceRemovedEvent") then 
                    return self:dispatchDeviceRemovedEvent(deviceNode)
                elseif (eventType == "DeviceActionRanEvent") then 
                    -- reuse the existing DevicePropertyUpdatedEvent processing logic
                    event.data.property = "action"
                    event.data.newValue = event.data.actionName
                    event.data.doNotRetain = true
                    
                    return self:dispatchDevicePropertyUpdatedEvent(deviceNode, event) 
                else
                    -- unsupported event type => ignore
                    return
                end
            else
                -- event for unsupported device => ignore
                return
            end
        
        else
            -- event for a device excluded by user filter criteria => ignore
            return
        end

    else
        -- process events for devices that are NOT REQUIRED to be known to the QuickApp
        if (eventType == "DeviceCreatedEvent") then
            deviceCreatedEventTimestamps[fibaroDeviceId] = event.created
            return self:dispatchDeviceCreatedEvent(fibaroDeviceId)
        else
            -- ignore unknown devices
            return
        end
    end
end

function QuickApp:dispatchDevicePropertyUpdatedEvent(deviceNode, event)
    local haEntity = deviceNode.identifiedHaEntity
    local propertyName = event.data.property
    if not propertyName then
        propertyName = "unknown"
    end

    -- *** move logic to device
    if ((haEntity.type == "binary_sensor") or (haEntity.type == "switch"))
           and 
        (propertyName == "value") 
    then
        -- Fibaro uses state/value fields inconsistently for 
        -- 1. binary sensors. Replace "value" with "state" field
        -- 2. Sound switch (Aetec). Replace "value" with "state" field
        event.data.property = "state"
    end

    -- round numbers
    local value = event.data.newValue
    if (isNumber(value)) then
        value = round(value, 2)
    end

    event.data.newValue = (type(value) == "number" and value or tostring(value))
    
    local targetEvent = haEntity:overrideFibaroEventIfNeeded(event)

    if targetEvent then
        for _, j in ipairs(self.mqttConventions) do
            if (type(targetEvent) == 'table' and #targetEvent > 0) then
                for _, i in ipairs(targetEvent) do
                    j:onFibaroEvent(deviceNode, i)
                end
            else
                j:onFibaroEvent(deviceNode, targetEvent)
            end
        end
    end
    -- if `targetEvent` is nil the device parser deliberately swallowed the event
end

function QuickApp:rememberLastMqttCommandTime(deviceId)
    self.lastMqttCommandTime[deviceId] = os.time()
end

-- S1/S2 inputs of dimmers/relays and remote controller keys send one
-- CentralSceneEvent per press (pressed, pressed2, helddown, released, ...).
function QuickApp:dispatchCentralSceneEvent(deviceNode, event)
    local keyId = event.data.keyId
    local keyAttribute = event.data.keyAttribute
    if (keyId == nil) or (keyAttribute == nil) then
        self:debug("Ignoring CentralSceneEvent without keyId/keyAttribute: " .. json.encode(event))
        return
    end

    self:debug("Scene event: device #" .. tostring(deviceNode.id) .. " button " .. centralSceneTriggerId(keyId, keyAttribute))

    for _, mqttConvention in ipairs(self.mqttConventions) do
        mqttConvention:onCentralSceneEvent(deviceNode, keyId, keyAttribute)
    end

    -- A remote controller also shows its last key press as sensor value. Never do
    -- this for other devices: a dimmer's "value" is its brightness.
    local haEntity = deviceNode.identifiedHaEntity
    if haEntity and (haEntity.type == RemoteController.type) and (haEntity.subtype == RemoteController.subtype) then
        self:simulatePropertyUpdate(deviceNode.fibaroDevice, "value", normalizeSceneKeyId(keyId) .. "," .. string.lower(tostring(keyAttribute)))
    end
end

-- The device that owns the Scene Activation triggers: the one with
-- availableScenes, which on an FGD-212 is the "Switch" sibling of the dimmer.
local function findSceneActivationNode(deviceNode)
    if deviceNode.fibaroDevice.properties.availableScenes then
        return deviceNode
    end
    if deviceNode.parentNode then
        for _, sibling in ipairs(deviceNode.parentNode.childNodeList) do
            if sibling.included and sibling.fibaroDevice.properties and sibling.fibaroDevice.properties.availableScenes then
                return sibling
            end
        end
    end
    return deviceNode
end

-- Modules using Scene Activation (instead of Central Scene) report a press as a
-- SceneActivationEvent and/or a "sceneActivation" property update, possibly on
-- different devices. Both are mapped to the Central Scene keys; a press that
-- arrives through both within a second is forwarded once.
local lastSceneActivation = {}
function QuickApp:dispatchSceneActivation(deviceNode, sceneId)
    if sceneId == nil then
        return
    end

    local targetNode = findSceneActivationNode(deviceNode)
    local now = os.time()
    local last = lastSceneActivation[targetNode.id]
    if last and (last.sceneId == tostring(sceneId)) and (now - last.time <= 1) then
        return
    end
    lastSceneActivation[targetNode.id] = { sceneId = tostring(sceneId), time = now }

    local keyId, keyAttribute = sceneActivationToKey(sceneId)
    self:debug("Scene activation " .. tostring(sceneId) .. " from device #" .. tostring(deviceNode.id))
    return self:dispatchCentralSceneEvent(targetNode, { data = { keyId = keyId, keyAttribute = keyAttribute } })
end

function QuickApp:dispatchDeviceCreatedEvent(fibaroDeviceId)
    local newDeviceNode = createAndAddDeviceNodeToHierarchyById(fibaroDeviceId)

    if (newDeviceNode.included and newDeviceNode.identifiedHaEntity) then
        self:debug("Fibaro device " .. newDeviceNode.id .. " added")
        -- also publishes linked children (energy/power/battery sensors, button triggers)
        self:publishDeviceNodeToMqtt(newDeviceNode)

        printDeviceNodeHierarchy(newDeviceNode, 1)
    else
        self:debug("New device " .. newDeviceNode.id .. " will not be added")
    end
end

function QuickApp:dispatchDeviceModifiedEvent(deviceNode)
    -- Previous logic that is expected to work, but HA doesn't handle remove & crate entity events
    --self:debug("Fibaro device " .. deviceNode.id .. " got modified => its old configuration to be removed, and then the new one added by the QuickApp")
    --self:dispatchDeviceRemovedEvent(deviceNode)
    --self:dispatchDeviceCreatedEvent(deviceNode.id)

    self:debug("Fibaro device " .. deviceNode.id .. " got modified => its old configuration will be updated")    
    self:dispatchDeviceCreatedEvent(deviceNode.id)
end

function QuickApp:dispatchDeviceRemovedEvent(deviceNode)
    removeDeviceNodeFromHierarchyById(deviceNode.id)

    for _, mqttConvention in ipairs(self.mqttConventions) do
        mqttConvention:onDeviceNodeRemoved(deviceNode)

        for _, childNode in ipairs(deviceNode.childNodeList) do
            self:dispatchDeviceRemovedEvent(childNode)
        end

    end
    self:debug("Fibaro device removed " .. deviceNode.id)
end

function QuickApp:logDeviceNode(id)
    local deviceNode = getDeviceNodeById(id)
    print("------- DEVICE NODE INFO FOR #" .. id)
    print("Matched filter criteria: " ..tostring(deviceNode.included))
    print("Fibaro device: " ..json.encode(deviceNode.fibaroDevice))

    local haDeviceStr
    if deviceNode.identifiedHaDevice then
        haDeviceStr = json.encode(deviceNode.identifiedHaDevice)
    else 
        haDeviceStr = "not found => not supported by the Quick App"
    end
    print("Home Assistant physical device: " .. haDeviceStr)

    local haEntityStr
    if deviceNode.identifiedHaEntity then
        local haEntity = deviceNode.identifiedHaEntity
        local haEntityCopy = { 
            id = haEntity.id,
            name = haEntity.name,
            roomName = haEntity.roomName,
            type = haEntity.type,
            subtype = haEntity.subtype,
            icon = haEntity.icon
        } 
        if (haEntityCopy.linkedEntity) then
            haEntityCopy.linkedEntity = getDeviceDescriptionById(haEntityCopy.linkedEntity.id)
        end

        if (haEntityCopy.type == "climate") then
            local sensor =  haEntity:getTemperatureSensor()
            if sensor then
                haEntityCopy.temperatureSensor = getDeviceDescriptionById(haEntity:getTemperatureSensor().id)
            else
                haEntityCopy.temperatureSensor = "no temperature sensor attached"
            end
        end

        haEntityStr = json.encode(haEntityCopy)
    else 
        haEntityStr = "not found => not supported by the Quick App"
    end
    print("Home Assistant logical entity: " .. haEntityStr)

    print("Children count : " .. tostring(#deviceNode.childNodeList))
end
