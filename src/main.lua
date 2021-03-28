function QuickApp:onInit()
    self:debug("-------------------------")
    self:debug("HC3 <-> MQTT BRIDGE")
    self:debug("-------------------------")

    self:turnOn() 
end

function QuickApp:publish(topic, payload)
    self.mqtt:publish(topic, tostring(payload), {retain = true})
end

function QuickApp:turnOn()
    self:establishMqttConnection()
end

function QuickApp:turnOff()
    self:disconnectFromMqttAndHc3()
    self:debug("Disconnected from MQTT and HC3")
    self:updateProperty("value", false)
    self:debug("Turned off HC3-to-MQTT bridge at Fibaro GUI")
end

function QuickApp:establishMqttConnection() 
    self.devices = {}

    -- IDENTIFY WHICH MQTT CONVENTIONS TO BE USED (e.g. Home Assistant, Homio, etc)
    self.mqttConventions = { }
    local mqttConventionStr = self:getVariable("mqttConvention")
    if (isEmptyString(mqttConventionStr)) then
        self.mqttConventions[0] = MqttConventionHomeAssistant
    else
        local arr = splitString(mqttConventionStr, ",")
        for i, j in ipairs(arr) do
            local convention = mqttConventionMappings[j]
            if (convention) then
                self.mqttConventions[i] = clone(convention)
            end
        end
    end

    local mqttConnectionParameters = self:getMqttConnectionParameters()
    self:trace("MQTT Connection Parameters: " .. json.encode(mqttConnectionParameters))

    local mqttClient = mqtt.Client.connect(
                                    self:getVariable("mqttUrl"),
                                    mqttConnectionParameters) 

    mqttClient:addEventListener('connected', function(event) self:onConnected(event) end)
    mqttClient:addEventListener('closed', function(event) self:onClosed(event) end)
    mqttClient:addEventListener('message', function(event) self:onMessage(event) end)
    mqttClient:addEventListener('error', function(event) self:onError(event) end)    
    
    -- skip event handlers to aid higher performance
    --mqttClient:addEventListener('subscribed', function(event) self:onSubscribed(event) end)
    --mqttClient:addEventListener('published', function(event) self:onPublished(event) end)

    self.mqtt = mqttClient
end

function QuickApp:getMqttConnectionParameters()
    local mqttConnectionParameters = {
        -- pickup last will from primary MQTT Convention provider
        lastWill = self.mqttConventions[1]:getLastWillMessage()
    }

    -- MQTT CLIENT ID
    local mqttClientId = self:getVariable("mqttClientId")
    if (isEmptyString(mqttClientId)) then
        mqttConnectionParameters.clientId = "HC3-" .. plugin.mainDeviceId
    else
        mqttConnectionParameters.clientId = mqttClientId
    end

    -- MQTT KEEP ALIVE PERIOD
    local mqttKeepAlivePeriod = self:getVariable("mqttKeepAlive")
    if (mqttKeepAlivePeriod) then
        mqttConnectionParameters.keepAlivePeriod = tonumber(mqttKeepAlivePeriod)
    else
        mqttConnectionParameters.keepAlivePeriod = 30
    end

    -- MQTT AUTH (USERNAME/PASSWORD)
    local mqttAuth = self:getVariable("mqttAuth") 
    local mqttUsername
    local mqttPassword
    if (isEmptyString(mqttAuth)) then
        mqttUsername = self:getVariable("mqttUsername")
        mqttPassword = self:getVariable("mqttPassword")
    else 
        local mqttAuth = self:getVariable("mqttAuth")
        if (mqttAuth) then
            mqttUsername, mqttPassword = decodeBase64Auth(mqttAuth)
        end
    end

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
    self:closeMqttConnection()
end

function QuickApp:closeMqttConnection()
    for i, j in ipairs(self.mqttConventions) do
        if (j.mqtt ~= MqttConventionPrototype.mqtt) then
            j:onDisconnected()
        end
    end

    self.mqtt:disconnect()
end

function QuickApp:onClosed(event)
    self:updateProperty("value", false)
end

function QuickApp:onError(event)
    self:error("MQTT ERROR: " .. json.encode(event))
    self:turnOff()
    self:scheduleReconnectToMqtt();
end

function QuickApp:scheduleReconnectToMqtt()
    fibaro.setTimeout(10000, function() 
        self:debug("Attempt to reconnect to MQTT...")
        self:establishMqttConnection()
    end)
end

function QuickApp:onMessage(event)
    for i, j in ipairs(self.mqttConventions) do
        j:onCommand(event)
    end
end

function QuickApp:onConnected(event)
    self:debug("MQTT connection established")

    for _, mqttConvention in ipairs(self.mqttConventions) do
        mqttConvention.mqtt = self.mqtt
        mqttConvention.devices = self.devices
        mqttConvention:onConnected()
    end

    self:discoverDevicesAndPublishToMqtt()

    self.hc3ConnectionEnabled = true
    self:scheduleHc3EventsFetcher()

    self:updateProperty("value", true)
end

function QuickApp:identifyAndPublishDeviceToMqtt(fibaroDevice)
    local bridgedDevice = identifyDevice(fibaroDevice) 
    self:publishDeviceToMqtt(bridgedDevice)
end

function QuickApp:discoverDevicesAndPublishToMqtt()
    local startTime = os.time()

    local fibaroDevices = self:discoverDevices()
    self:identifyDevices(fibaroDevices)

    for _, device in pairs(self.devices) do
        self:publishDeviceToMqtt(device)
    end

    local diff = os.time() - startTime   

    local bridgedDevices = 0
    for _, _ in pairs(self.devices) do
        bridgedDevices = bridgedDevices + 1
    end
    
    self:updateView("availableDevices", "text", "Available devices: " .. #fibaroDevices)
    self:updateView("bridgedDevices", "text", "Bridged devices: " .. bridgedDevices) 
    self:updateView("bootTime" , "text", "Boot time: " .. diff .. "s")

    self:debug("----------------------------------")
    self:debug("Device discovery has been complete")
    self:debug("----------------------------------")

    return haDevices
end

function QuickApp:discoverDevices()
    local fibaroDevices

    local developmentModeStr = self:getVariable("developmentMode")
    if ((not developmentModeStr) or (developmentModeStr ~= "true")) then
        self:debug("Bridge mode: PRODUCTION")

        fibaroDevices = getFibaroDevicesByFilter({
            enabled = true,
            visible = true
        })
    else
        -- useful to reduce amount information for debug with smaller number of devices
        self:debug("Bridge mode: DEVELOPMENT")

        fibaroDevices = {
            getFibaroDeviceById(41), -- switch Onyx light,
            getFibaroDeviceById(42), -- switch Fan,
            getFibaroDeviceById(260), -- iPad screen
            getFibaroDeviceById(287), -- door sensor
            getFibaroDeviceById(54), -- motion sensor
            getFibaroDeviceById(92), -- roller shutter
            getFibaroDeviceById(78), -- dimmer
            getFibaroDeviceById(66), -- temperature sensor
            getFibaroDeviceById(56), -- light sensor (lux)
            getFibaroDeviceById(245), -- volts
            getFibaroDeviceById(105), -- on/off thermostat from CH
            getFibaroDeviceById(106), -- temperature sensor
            getFibaroDeviceById(120), -- IR thermostat from CH
            getFibaroDeviceById(122), -- temperature sensor
            getFibaroDeviceById(335), -- on/off thermostat from Qubino
            getFibaroDeviceById(336) -- temperature sensor 
        }
    end

    return fibaroDevices 
end

function QuickApp:identifyDevices(fibaroDevices)
    for _, fibaroDevice in ipairs(fibaroDevices) do
        local device = identifyDevice(fibaroDevice)
        if (device) then
            self:debug("Device " .. self:getDeviceDescription(device) .. " identified as " .. device.bridgeType)
            self.devices[device.id] = device
        else
            self:debug("Couldn't recognize device #" .. fibaroDevice.id .. " - " .. fibaroDevice.name)
        end
    end
end

function QuickApp:publishDeviceToMqtt(device)
    ------------------------------------------------------------------
    ------- ANNOUNCE DEVICE EXISTANCE
    ------------------------------------------------------------------
    for i, j in ipairs(self.mqttConventions) do
        j:onDeviceCreated(device)
    end

    ------------------------------------------------------------------
    ------- ANNOUNCE DEVICE CURRENT STATE => BY SIMULATING HC3 EVENTS
    ------------------------------------------------------------------
    self:simulatePropertyUpdate(device, "dead", device.properties.dead)
    self:simulatePropertyUpdate(device, "state", device.properties.state)
    self:simulatePropertyUpdate(device, "value", device.properties.value)
    self:simulatePropertyUpdate(device, "heatingThermostatSetpoint", device.properties.heatingThermostatSetpoint)
    self:simulatePropertyUpdate(device, "thermostatMode", device.properties.thermostatMode)
end

function QuickApp:onPublished(event)
    -- do nothing, for now
end

-- FETCH HC3 EVENTS
local lastRefresh = 0
local http = net.HTTPClient()

function QuickApp:scheduleHc3EventsFetcher()
    local hc3Auth = self:getVariable("hc3Auth")
    if (isEmptyString(hc3Auth)) then
        local hc3Username = self:getVariable("hc3Username")
        local hc3Password = self:getVariable("hc3Password")
        if (isEmptyString(hc3Username) or isEmptyString(hc3Password)) then
            self:error("You need to provide username/password for your Fibaro HC3")
            error("You need to provide username/password for your Fibaro HC3")
        end
        hc3Auth = base64Encode(hc3Username .. ":" .. hc3Password)
    end

    self.hc3Auth = hc3Auth

    self:readHc3EventAndScheduleFetcher()
    self:debug("---------------------------------------------------")
    self:debug("Started monitoring events from Fibaro Home Center 3")
    self:debug("---------------------------------------------------")
end

function QuickApp:readHc3EventAndScheduleFetcher()
    local requestUrl = "http://localhost:11111/api/refreshStates?last=" .. lastRefresh;
    --self:debug("Try fetch events from " .. requestUrl .. " | " .. tostring(self.hc3ConnectionEnabled))

    -- use non-block HTTP calls, avoid api.get(uri) that has a risk of blocking calls
    local stat,res = http:request(
        requestUrl,
        {
        options = {
            headers = {
                ["Authorization"] = "Basic " .. self.hc3Auth,
            }
        },
        success=function(res)
            local states = res.status == 200 and json.decode(res.data)

            if (res.status ~= 200) then
                self:error("Unexpected response status " .. res.status)
            end
            if (not res.data) then
                self:error("Empty response")
            end
            if (not self.hc3ConnectionEnabled) then
                self:debug("Got flagged to stop reading HC3 events")
            end

            if states and self.hc3ConnectionEnabled then
                lastRefresh = states.last
                if states.events and #states.events>0 then 
                    for i, v in ipairs(states.events) do
                        self:dispatchFibaroEventToMqtt(v)
                        --local status, err = pcall(function () self:dispatchFibaroEventToMqtt(v) end)
                        --self:debug("RESP: " .. json.encode(status) .. " - " .. json.encode(err))
                    end
                end
            end

            if (self.hc3ConnectionEnabled) then
                fibaro.setTimeout(25, function()
                    self:readHc3EventAndScheduleFetcher()
                end)
            end
        end,
        error=function(res) 
            self:error("Error while reading HC3 events " .. json.encode(res))
            self:turnOff()
        end
    })
end

function QuickApp:simulatePropertyUpdate(device, propertyName, value)
    if value ~= nil then
        local event = createFibaroEventPayload(device, propertyName, value)
        event.simulation = true
        self:dispatchFibaroEventToMqtt(event)
    end
end

function QuickApp:dispatchFibaroEventToMqtt(event)
    --self:debug("Event: " .. json.encode(event))
    if (not event) then
        self:error("No event found")
        return
    end

    if (not event.data) then
        self:error("No event data found")
        return
    end

    local deviceId = event.data.id or event.data.deviceId

    if not deviceId then
        -- deviceId is must have for processing logic
        self:warning("No device id for " .. json.encode(event))
        return
    end 
    
    local propertyName = event.data.property
    if not propertyName then
        propertyName = "unknown"
    end

    if (not event.type) then
        event.type = "unknown"
    end

    local device = self.devices[deviceId]

    if (device) then

        if (event.type == "DevicePropertyUpdatedEvent") then

            -- *** OVERRIDE FIBARO PROPERTY NAMES, FOR BEING MORE CONSISTENT AND THUS EASIER TO HANDLE 
            if (device.bridgeType == "binary_sensor") and (propertyName == "value") then
                -- Fibaro uses state/value fields inconsistently for binary sensor. Replace value --> state field
                event.data.property = "state"
            end

            for i, j in ipairs(self.mqttConventions) do
                j:onPropertyUpdated(device, event)
            end
        elseif (event.type == "DeviceModifiedEvent") then
            self:dispatchDeviceModifiedEvent(device)
        elseif (event.type == "DeviceCreatedEvent") then
            self:dispatchDeviceCreatedEvent(device)
        elseif (event.type == "DeviceRemovedEvent") then 
            self:dispatchDeviceRemovedEvent(device)
        elseif (event.type == "DeviceActionRanEvent") then
            if (event.data.actionName == "turnOn" or event.data.actionName == "turnOff") then
                --self:rememberLastHc3CommandTime(deviceId, event.sourceType)
            end
        else
            self:warning("TBD: Need to introduce new event type for " .. tostring(event.type))
        end

    end
end

function QuickApp:rememberLastMqttCommandTime(deviceId)
    self.lastMqttCommandTime[deviceId] = os.time()
end

function QuickApp:dispatchPropertyUpdateEvent(device, event, payload, propertyName)
    -- PUBLISH DEVICE STATUS FOR HA AND NODE-RED
    local topic = createPropertyTopicName(device, propertyName)

    local value = (type(event.data.newValue) == "number" and event.data.newValue or tostring(event.data.newValue))
    if not value then
        value = (type(event.value) == "number" and event.value or tostring(event.value))    
    end

    payload.value = string.lower(value)

    local haPayload
    if (propertyName == "dead") then
        haPayload = tostring(payload.value)
    else
        haPayload = json.encode(payload)
    end

    --self:debug("SEND MESSAGE: " .. topic .. " = " .. json.encode(haPayload))
    self:publish(
        topic,
        haPayload
    )
end

function QuickApp:dispatchDeviceCreatedEvent(device)
    local fibaroDevice = api.get("/devices/" .. device.id)

    if (fibaroDevice.visible and fibaroDevice.enabled) then
        self:debug("Device created " .. json.encode(fibaroDevice))
        self:identifyAndPublishDeviceToMqtt(fibaroDevice)
    end
end

function QuickApp:dispatchDeviceModifiedEvent(device)
    self:debug("Device modified " .. device.id)

    self:dispatchDeviceRemovedEvent(device)

    self:dispatchDeviceCreatedEvent(device)
end

function QuickApp:dispatchDeviceRemovedEvent(device)
    self:debug("Device removed " .. device.id)
    for i, j in ipairs(self.mqttConventions) do
        j:onDeviceRemoved(device)
    end
    --self:removeDeviceFromMqtt(device)
end

function QuickApp:dispatchCentralSceneEvent(device, event, payload)
    -- PUBLISH DEVICE STATUS FOR HA AND NODE-RED
    local topic = createGenericEventTopicName(device, "CentralSceneEvent", "key" .. event.data.keyAttribute)

    createGenericEventTopicName(device, event.type)

    self:publish(
        topic,
        event.data.keyId
    )
end

function QuickApp:getDeviceDescription(device)
    if device and device.name and device.id and device.roomName then
        return device.name .. " #" .. device.id .. " (" .. tostring(device.roomName) .. ")"
    else
        return device.id
    end
end
