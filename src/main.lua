local fibaroBaseTypeOverride = {
    ["com.fibaro.FGR"] = "com.fibaro.baseShutter",
    ["com.fibaro.FGMS001"] = "com.fibaro.motionSensor"
}

local fibaroTypeOverride = {
    ["com.fibaro.FGKF601"] = "com.fibaro.keyFob",
    ["com.fibaro.FGD212"] = "com.fibaro.dimmer",
    ["com.fibaro.FGMS001v2"] = "com.fibaro.motionSensor",
    ["com.fibaro.FGFS101"] = "com.fibaro.floodSensor"
} 

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
    self:simulatePropertyUpdate(self:getDevice(1), "dead", "true")
    self:disconnectFromMqttAndHc3()
    self:updateProperty("value", false)
end

function QuickApp:establishMqttConnection()
    self.deviceById = {}
    self.haDeviceTypeById = {}
    self.fibaroDeviceBaseTypeById = {}
    self.fibaroDeviceTypeById = {}
    self.dimmerBrightnessUpdateTime = {}
    self.lastMqttCommandTime = {}
    self.lastHc3CommandTime = {}
    self.lastHc3CommandSourceType = {}

    self.haDeviceTypeById[1] = "binary_sensor"
    self.hc3Device = self:getDevice(1)
    self.hc3DeviceDetails = api.get("/devices/1")

    if self.mqtt then
        --[[ 
        if pcall(self:closeMqttConnection()) then
            self:debug("Old connection closed")
        else
            self:warning("Unable to close old connection")
        end
        ]]--
    end

    self:debug("Connecting to " .. self:getVariable("mqttUrl") ..  " ...")

    local mqttConnectionParameters = self:getMqttConnectionParameters()

    self:trace("MQTT Connection Parameters: " .. json.encode(mqttConnectionParameters))

    local mqttClient = mqtt.Client.connect(
                                    self:getVariable("mqttUrl"), 
                                    mqttConnectionParameters) 

    mqttClient:addEventListener('connected', function(event) self:onConnected(event) end)
    mqttClient:addEventListener('closed', function(event) self:onClosed(event) end)
    mqttClient:addEventListener('message', function(event) self:onMessage(event) end)
    mqttClient:addEventListener('error', function(event) self:onError(event) end)    
    mqttClient:addEventListener('subscribed', function(event) self:onSubscribed(event) end)
    mqttClient:addEventListener('published', function(event) self:onPublished(event) end) 

    self.mqtt = mqttClient
end

function QuickApp:getMqttConnectionParameters()
    local mqttConnectionParameters = {
        lastWill = {
            topic = createPropertyTopicName(self.hc3Device, "dead"),
            payload = "true"
        }
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
        self:debug("plain")
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
    local options = {}
    self.mqtt:disconnect(options)
end

function QuickApp:onConnected(event)
    self:debug("MQTT connection established")
    self.mqtt:subscribe("homeassistant/+/+/commands/+")
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
    self:debug("Schedule attempt to reconnect to MQTT...")
    fibaro.setTimeout(10000, function() 
        self:establishMqttConnection()
    end)
end

function QuickApp:onMessage(event)
    self:debug("COMMAND " .. json.encode(event))

    local deviceId = getDeviceIdFromTopic(event.topic)
    if not deviceId then
        self:error("No device id could be extracted from topic " .. event.topic)
    end

    self:rememberLastMqttCommandTime(deviceId)

    if string.find(event.topic, "setValue$") then
        self:onSetValue(deviceId, event)
    elseif string.find(event.topic, "setBrightness$") then
        self:onSetBrightness(deviceId, event)
    elseif string.find(event.topic, "setPosition$") then
        self:onSetPosition(deviceId, event)
    elseif string.find(event.topic, "setThermostatMode$") then
        self:onSetThermostatMode(deviceId, event)
    elseif string.find(event.topic, "setHeatingThermostatSetpoint$") then
        self:onSetHeatingThermostatSetpoint(deviceId, event)
    else
        self:warning("Unknown event " .. json.encode(event))
    end
end 

function QuickApp:discoverDevicesAndBroadcastToHa()
    local startTime = os.time()

    self.devices = {}
    local allDevices = api.get("/devices?enabled=true&visible=true")
    self:publishDeviceToMqtt(self.hc3DeviceDetails)


    local bridgedDevices = 0
    for i, j in pairs(allDevices) do
        if (self:publishDeviceToMqtt(j)) then
            bridgedDevices = bridgedDevices + 1
        end
    end

    local endTime = os.time()
    local diff = endTime - startTime 

    self:updateView("availableDevices", "text", "Available devices: " .. #allDevices)
    self:updateView("bridgedDevices", "text", "Bridged devices: " .. bridgedDevices)
    self:updateView("bootTime" , "text", "Boot time: " .. diff .. "s")

    self:debug("Load complete!")

    return haDevices
end

function QuickApp:publishDeviceToMqtt(j)
    local deviceId = j.id
    local fibaroType = j.type
    local fibaroBaseType = j.baseType

    if (not fibaroType) then
        self:error("No fibaro type indicated for " .. deviceName .. " - " .. deviceId)
        return
    end

    if (not fibaroBaseType) then
        self:error("No fibaro base type indicated for " .. deviceName .. " - " .. deviceId)
        return
    end

    -- override base type if necessary
    local overrideBaseType = fibaroBaseTypeOverride[fibaroBaseType]
    if overrideBaseType then
        fibaroBaseType = overrideBaseType
    end
    self.fibaroDeviceBaseTypeById[deviceId] = fibaroBaseType

    local overrideType = fibaroTypeOverride[fibaroType]
    if overrideType then
        fibaroType = overrideType
    end
    self.fibaroDeviceTypeById[deviceId] = fibaroType

    local interfaces = j.interfaces
    local categories = j.properties.categories

    --self:debug("DEVICE: " .. j.name .. "(" .. deviceId .. ") " .. j.baseType .. " | " .. j.type .. " | " .. json.encode(interfaces) .. " | " .. json.encode(categories))

    local haConfig = {
    }

    local haDeviceType = nil
    local hasValue = true
    local hasState = false
    local hasBrightness = false
    local hasPosition = false
    local hasBinaryValue = true
    local hasMode = false
    local isEditable = false
    local isThermostat = false
    local hasTopicToTriggerEvents = false
    local supportTextNotifications = false
    local supportVoiceNotifications = false
    local decoyDevice = false

    ------------------------------------------------------------------
    ------- IDENTIFY DEVICE TYPE FOR HOME ASSISTANT
    ------------------------------------------------------------------
    if (fibaroBaseType == "com.fibaro.actor") then
        if (fibaroType == "com.fibaro.binarySwitch") then
            isEditable = true
            if (table_contains_value(interfaces, "light")) then
                haDeviceType = "light"
            else
                -- climate (fan) is not supported
                if (table_contains_value(categories, "climate_does_not_exist")) then
                    haDeviceType = "fan"
                    hasValue = false
                else
                    haDeviceType = "switch"
                end
            end
        end

    elseif (fibaroBaseType == "com.fibaro.baseShutter") then 
        haDeviceType = "cover"
        hasPosition = true
        isEditable = true

    elseif (fibaroBaseType == "com.fibaro.multilevelSwitch") then
        haDeviceType = "light"
        isEditable = true
        hasBrightness = true

    elseif (fibaroBaseType == "com.fibaro.sensor") then 
        if (fibaroType == "com.fibaro.multilevelSensor") then
            haDeviceType = "sensor"
            hasBinaryValue = false
            haConfig.unit_of_measurement = j.properties.unit
        else
            haDeviceType = "binary_sensor"
        end

    elseif (fibaroBaseType == "com.fibaro.motionSensor" or fibaroType == "com.fibaro.motionSensor") then
        haDeviceType = "binary_sensor"
        haConfig.device_class = "motion"

    elseif (fibaroBaseType == "com.fibaro.floodSensor") then
        haDeviceType = "binary_sensor"
        haConfig.device_class = "moisture" 


    elseif (fibaroBaseType == "com.fibaro.doorWindowSensor") then
        if (fibaroType == "com.fibaro.doorSensor") then
            haDeviceType = "binary_sensor"
            haConfig.device_class = "door"
            --haConfig.off_delay = "2"
        else
            self:warning("UNKNOWN DOOR WINDOW SENSOR " .. self:getDeviceDescription(deviceId))
        end

    elseif (fibaroBaseType == "com.fibaro.smokeSensor") then
            haDeviceType = "binary_sensor"
            haConfig.device_class = "smoke"

    elseif (fibaroBaseType == "com.fibaro.lifeDangerSensor") then
            haDeviceType = "binary_sensor"
            -- reuse "smoke" icon, looks prete decent in home assistant
            haConfig.device_class = "smoke"

    elseif (fibaroBaseType == "com.fibaro.multilevelSensor") then
        haDeviceType = "sensor"
        hasBinaryValue = false
        if (fibaroType == "com.fibaro.temperatureSensor") then
            haConfig.device_class = "temperature" 
            haConfig.unit_of_measurement = "°" .. j.properties.unit
        elseif (fibaroType == "com.fibaro.lightSensor") then
            haConfig.unit_of_measurement = j.properties.unit
            haConfig.device_class = "illuminance"
        else
            self:warning("UNKNOWN DEVICE TYPE FOR MULTILEVEL SENSOR " .. self:getDeviceDescription(deviceId))
        end

    elseif (fibaroType == "com.fibaro.hvacSystem") then
        hasMode = true
        haDeviceType = "climate"
        hasBinaryValue = false
        hasValue = false
        isThermostat = true

    elseif (fibaroBaseType == "com.fibaro.remoteSceneController") then
        if (fibaroType == "com.fibaro.keyFob") then
            -- ToDo: implement keyFob support later
            --     * 6 buttons
            --     * click types: "keyPressed", "keyHeldDown", "keyReleased"
            haDeviceType = "device_automation"
            haConfig.automation_type = "trigger"
            haConfig.type = "button_short_press"
            haConfig.subtype = "button_1"
            hasTopicToTriggerEvents = true
            hasValue = false
        end

    elseif (fibaroType == "com.fibaro.zwavePrimaryController") then
        haDeviceType = "binary_sensor"
        haConfig.name = "Fibaro HC3"
        haConfig.device_class = "plug"
        decoyDevice = true

    elseif (fibaroType == "HC_user") then
        --self:debug("Ignore HC_user for now")

        --[[
        "properties": {
            "Email": "<tbd>@gmail.com",
            "actions": {
            "sendDefinedEmailNotification": 1,
            "sendDefinedSMSNotification": 2,
            "sendEmail": 2,
            "sendGlobalEmailNotifications": 1,
            "sendGlobalPushNotifications": 1,
            "sendGlobalSMSNotifications": 1,
            "sendPush": 1,
            "setSipDisplayName": 1,
            "setSipUserID": 1,
            "setSipUserPassword": 1
        }
        ]]--

    elseif (fibaroType == "com.fibaro.player") then
        -- TODO add proper support for media player / TTL
        haDeviceType = "media_player"
        haConfig.commands = {
            turn_on = {
                service = "SERVICE",
                data = "SERVICE_DATA"
            },
            turn_off = {
                service = "SERVICE",
                data = "SERVICE_DATA"
            }
        }

    else
        self:warning("UNKNOWN DEVICE TYPE " .. self:getDeviceDescription(deviceId))
    end

    self.haDeviceTypeById[deviceId] = haDeviceType
 

------------------------------------------------------------------
------- ANNOUNCE DEVICE CONFIGURATION TO HOME ASSISTANT
------------------------------------------------------------------
    --self:debug("START PUBLISHING CONFIG TO HA - " .. tostring(haDeviceType))
    if haDeviceType then
        -- refresh with haDeviceType property
        device = self:getDeviceAndRefreshCache(deviceId)

        haConfig.unique_id = tostring(device.id) 
        
        if (not haConfig.name) then
            haConfig.name = device.name
        end
        haConfig.name = haConfig.name .. " (" .. device.roomName .. ")"
        --haConfig.name = haConfig.name .. " #" .. device.id .. " (" .. device.roomName .. ")"

        --self:debug("REGISTER DEVICE " .. haConfig.name .. " | " .. haDeviceType)

        if (device.id ~= self.hc3Device.id) then
            haConfig.availability = {
                {topic = createPropertyTopicName(device, "dead"), payload_available = "false", payload_not_available = "true"},
                {topic = createPropertyTopicName(self.hc3Device, "dead"), payload_available = "false", payload_not_available = "true"}
            }
            --haConfig.availability_topic = createPropertyTopicName(device, "dead")
        else
            haConfig.availability_topic = createPropertyTopicName(device, "dead")
            haConfig.payload_available = "false"
            haConfig.payload_not_available = "true"
        end

        haConfig.device = {
            manufacturer = "Fibaro",
            name = "Home Center 3",
            model = self.hc3DeviceDetails.type,
            sw_version = self.hc3DeviceDetails.properties.zwaveVersion,
            identifiers = {tostring(self.hc3DeviceDetails.id)}
        }

        haConfig.json_attributes_topic = createHaJsonAttributesTopicName(device)

        if hasValue then
            haConfig.state_topic = createPropertyTopicName(device, "value")
            haConfig.value_template = "{{ value_json.value }}"
        end
        if hasState then
            haConfig.state_value_template = "{{ value_json.value }}"
        end
        
        if hasBinaryValue then
            haConfig.payload_on = "true"
            haConfig.payload_off = "false"
        end
        
        if isEditable then
            haConfig.command_topic = createCommandTopicName(device, "value")
        end

        if hasBrightness then
            haConfig.brightness_scale = 99
            haConfig.brightness_state_topic = createPropertyTopicName(device, "brightness")
            haConfig.brightness_value_template = "{{ value_json.value }}"
            if isEditable then
                haConfig.brightness_command_topic = createCommandTopicName(device, "brightness")
            end
        end

        if hasPosition then
            haConfig.payload_on = nil
            haConfig.payload_off = nil
            haConfig.state_topic = nil
            haConfig.command_topic = nil

            haConfig.position_open = 100
            haConfig.position_closed = 0
            haConfig.payload_open = "100"
            haConfig.payload_close = "0"
            haConfig.payload_stop = "stop"
            haConfig.state_open = "open"
            haConfig.state_closed = "closed"
            haConfig.state_opening = "opening"
            haConfig.state_closing = "closing"
            haConfig.position_topic = createPropertyTopicName(device, "position")
            if isEditable then
                haConfig.set_position_topic = createCommandTopicName(device, "position")
            end
        end

        if isThermostat then
            haConfig.mode_state_topic = createPropertyTopicName(device, "thermostatMode")
            haConfig.mode_state_template = "{{ value_json.value }}"
            haConfig.mode_command_topic = createCommandTopicName(device, "thermostatMode")

            haConfig.temperature_state_topic = createPropertyTopicName(device, "heatingThermostatSetpoint")
            haConfig.temperature_state_template = "{{ value_json.value }}"
            haConfig.temperature_command_topic = createCommandTopicName(device, "heatingThermostatSetpoint")

            -- refactor
            local currentTemperatureDevice = {
                id = deviceId + 1,
                name = "doesn't matter", 
                fibaroBaseType = "doesn't matter",
                fibaroType = "doesn't matter",
                haType = "sensor",
                roomName = "doesn't matter"
            }

            haConfig.current_temperature_topic = createPropertyTopicName(currentTemperatureDevice, "value")
            haConfig.current_temperature_template = "{{ value_json.value }}"

            local fibaroModes = j.properties.supportedThermostatModes
            haConfig.modes = {}
            for i, mode in pairs(fibaroModes) do
                haConfig.modes[i] = string.lower(mode)
            end

            haConfig.temp_step = tonumber(j.properties.heatingThermostatSetpointStep[j.properties.unit])
            haConfig.min_temp = j.properties.heatingThermostatSetpointCapabilitiesMin
            haConfig.max_temp = j.properties.heatingThermostatSetpointCapabilitiesMax

            haConfig.temperature_unit = j.properties.unit
        end

        if hasTopicToTriggerEvents then
            haConfig.topic = createPropertyTopicName(device, "triggerEvent")
        end

        if haDeviceType == "fan" then
            haConfig.optimistic = false

            --haConfig.speed_state_topic = createPropertyTopicName(device, "speed")
            --haConfig.speed_value_template = "{{ value_json.value }}"
            --haConfig.payload_low_speed = "low"
            --haConfig.payload_medium_speed = "medium"
            --haConfig.payload_high_speed = "high"
            --haConfig.speeds = { "off", "low", "medium", "high"}
            --haConfig.state_value_template = "{{ value_json.value }}"

            if isEditable then
                --haConfig.oscillation_command_topic = createCommandTopicName(device, "oscillation")
                --haConfig.speed_command_topic = createCommandTopicName(device, "speed")
            end
        end

        j.metaInfo = device.metaInfo

        -- self:debug("PUBLISH DEVICE CONFIG: " .. json.encode(haConfig)) 

        -- Basic configuration for Home Assistant
        self:publish(
            createHaConfigTopicName(device), 
            json.encode(haConfig)
        ) 

        -- Publish extra device attributes
        self:publish(
            createHaJsonAttributesTopicName(device), 
            json.encode(j)
        )

        -----------------------------------------------------------------
        ----------- BROADCAST DEVICE CURRENT STATE TO HOME ASSISSTANT
        -----------------------------------------------------------------

        self:simulatePropertyUpdate(device, "dead", j.properties.dead)
        if (j.propertiesDead) then
            self:simulatePropertyUpdate(device, "deadReason", j.properties.deadReason)
        end

        if hasBrightness then
            self:simulatePropertyUpdate(device, "value", j.properties.value)
            self:simulatePropertyUpdate(device, "state", j.properties.state)
        elseif hasPosition then
            self:simulatePropertyUpdate(device, "value", j.properties.value)
            self:simulatePropertyUpdate(device, "state", j.properties.state)
        elseif haDeviceType == "climate" then
            self:simulatePropertyUpdate(device, "thermostatMode", string.lower(j.properties.thermostatMode))
            self:simulatePropertyUpdate(device, "heatingThermostatSetpoint", j.properties.heatingThermostatSetpoint)
        elseif haDeviceType == "fan" then
            -- do nothing, for now
        elseif hasValue then
            if decoyDevice then
                self:simulatePropertyUpdate(device, "value", "true")
            else
                self:simulatePropertyUpdate(device, "value", j.properties.value)
            end
        else
            self:trace("No value detected for " .. self:getDeviceDescription(deviceId))
        end

        return haConfig
    end
end

function QuickApp:removeDeviceFromMqtt(device)
    self:publish(
        createHaConfigTopicName(device), 
        ""
    )
end

function QuickApp:onSubscribed()
    self:debug("MQTT subscription established")

    self:discoverDevicesAndBroadcastToHa()

    self.hc3ConnectionEnabled = true
    self:readHc3Events()

    self:debug("Started fetching HC3 events")

    self:updateProperty("value", true)
end

function QuickApp:onPublished(event)
    -- do nothing, for now
end

function QuickApp:onSetValue(deviceId, event)
    local payload = event.payload

    local osTime = os.time()

    local data = {properties = {value = tostring(event.payload)} }

    local fibaroBaseType = self:getFibaroDeviceBaseTypeById(deviceId)

    if (fibaroBaseType == "com.fibaro.multilevelSwitch") then
        local state = plugin.getProperty(deviceId, "state")
        local brightness = plugin.getProperty(deviceId, "value")
        if brightness > 0 then
            state = true
        end
        if (event.payload == "true" and state == false) then

            local dimmerBrightnessUpdateTime = self.dimmerBrightnessUpdateTime[deviceId]
            if not dimmerBrightnessUpdateTime then
                dimmerBrightnessUpdateTime = -1
            end
            local diff = os.time() - dimmerBrightnessUpdateTime
            
            if (diff > 1) then
                fibaro.call(deviceId, "turnOn")
            else
                -- ignore
            end
        elseif (event.payload == "false" and state == true) then
            fibaro.call(deviceId, "turnOff")
        else
            self:warning("Unknown value: " .. json.encode(event))
        end
    else
        if (event.payload == "true") then
            fibaro.call(deviceId, "turnOn")
        elseif (event.payload == "false") then
            fibaro.call(deviceId, "turnOff")
        else
            self:warning("Unknown value: " .. json.encode(event))
        end
    end
end

function QuickApp:onSetBrightness(deviceId, event)
    local payload = event.payload

    local osTime = os.time()

    local data = {properties = {value = tostring(event.payload)} }
    
    self.dimmerBrightnessUpdateTime[deviceId] = os.time()
    fibaro.call(deviceId, "setValue", event.payload)
end

function QuickApp:onSetPosition(deviceId, event)
    local payload = event.payload

    local data = {properties = {value = tostring(event.payload)} }
    
    fibaro.call(deviceId, "setValue", event.payload)
end

function QuickApp:onSetThermostatMode(deviceId, event)
    local payload = event.payload

    local deviceId = getDeviceIdFromTopic(event.topic)

    local data = {properties = {value = tostring(event.payload)} }
    
    local mode = event.payload:gsub("^%l", string.upper)

    fibaro.call(deviceId, "setThermostatMode", mode)
end

function QuickApp:onSetHeatingThermostatSetpoint(deviceId, event)
    local payload = json.decode(event.payload)

    local data = {properties = {value = tostring(event.payload)} }
    
    fibaro.call(deviceId, "setHeatingThermostatSetpoint", event.payload)
end

-- FETCH HC3 EVENTS
local lastRefresh = 0
local http = net.HTTPClient()
function QuickApp:readHc3Events()
    local requestUrl = "http://localhost:11111/api/refreshStates?last=" .. lastRefresh;
    --self:debug("Try fetch events from " .. requestUrl .. " | " .. tostring(self.hc3ConnectionEnabled))

    -- use non-block HTTP calls, avoid api.get(uri) that has a risk of blocking calls
    local stat,res = http:request(
        requestUrl,
        {
        options = {
            headers = {
                ["Authorization"] = "Basic " .. self:getVariable("hc3Auth"),
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
                        self:dispatchFibaroEventToMqtt(v)self:dispatchFibaroEventToMqtt(v)
                        --local status, err = pcall(function () self:dispatchFibaroEventToMqtt(v) end)
                        --self:debug("RESP: " .. json.encode(status) .. " - " .. json.encode(err))
                    end
                end
            end

            if (self.hc3ConnectionEnabled) then
                fibaro.setTimeout(50, function()
                --fibaro.setTimeout(1000, function()  
                    self:readHc3Events()
                end)
            end
        end,
        error=function(res) 
            self:error("Error while reading HC3 events " .. json.encode(res))
            self:turnOff()
        end
    })
end

function QuickApp:simulatePropertyUpdate(device, propertyName, payload)
    local event = createFibaroEventPayload(device, propertyName, payload)
    event.simulation = true
    --self:debug("SIMULATE PROPERTY UPDATE EVENT: " .. json.encode(event))
    self:dispatchFibaroEventToMqtt(event)
end

function QuickApp:dispatchFibaroEventToMqtt(event)
    -- self:debug("Event 1: " .. json.encode(event))
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

    local device = self:getDevice(deviceId)

    --self:trace("Dispatch event " .. json.encode(event) .. " | "  .. device.fibaroBaseType .. " | " .. device.fibaroType .. " | " .. event.type .. " | " .. tostring(event.simulation))

    if (device.haType == "unknown") then
        --self:warning("Unknown HA device type for " .. " | " .. deviceId .. " | " .. json.encode(device) .. " | " .. tostring(self.haDeviceTypeById[device.id]) .. " | " .. json.encode(event))
    end

    local genericPayload = {
        id = device.id,
        --deviceId = device.id,
        deviceName = device.name,
        haType = device.haType,
        fibaroType = device.fibaroType,
        fibaroBaseType = device.fibaroBaseType,
        created = event.created,
        timestamp = os.date(),
        roomId = fibaro.getRoomID(deviceId),
        roomName = device.roomName
    }

    -- fibaro doesn't have a consistant use of "value" and "state" properties for "dimmer" device :(, so here goes a workaround
    if (event.type == "DeviceActionRanEvent") then
        if (device.haType == "unknown") then
            --self:trace(json.encode(self.haDeviceTypeById))
        end

        if (event.data.actionName == "turnOn" or event.data.actionName == "turnOff") then
            self:rememberLastHc3CommandTime(deviceId, event.sourceType)
        end
        
    elseif (event.type == "DevicePropertyUpdatedEvent") then
        local now = os.time()

        local lastMqttCommandTime = self.lastMqttCommandTime[device.id]
        if not lastMqttCommandTime then
            lastMqttCommandTime = -1
        end

        local lastHc3CommandTime = self.lastHc3CommandTime[device.id]
        if not lastHc3CommandTime then
            lastHc3CommandTime = -1
        end

        local lastHc3CommandSourceType = self.lastHc3CommandSourceType[device.id]

        local diffHc3 = now - lastHc3CommandTime
        local diffMqtt = now - lastMqttCommandTime

        --[[
            Event: {"sourceType":"system","data":{"property":"value","oldValue":false,"id":42,"newValue":true},"objects":[{"objectId":42,"objectType":"device"}],"type":"DevicePropertyUpdatedEvent","created":1601229076}
            Event: {"sourceType":"system","data":{"property":"state","oldValue":false,"id":42,"newValue":true},"objects":[{"objectId":42,"objectType":"device"}],"type":"DevicePropertyUpdatedEvent","created":1601229076}
            Event: {"sourceType":"device","sourceId":42,"created":1601229076,"type":"SceneStartedEvent","data":{"id":36,"subid":1,"trigger":null,"type":""},"objects":[{"objectId":36,"objectType":"scene"}]}
        ]]--

        local simulation = (event.simulation == true)

        local source = "zwave-device"
        if (simulation) then
            source = "mqtt-bridge-simulation"
        elseif (diffMqtt <= 2) then
            source = "mqtt"
        elseif (diffHc3 <= 2) then
            if (lastHc3CommandSourceType == "user") then
                source = "zwave-hc3-user"
            elseif (lastHc3CommandSourceType == "system") then
                source = "zwave-hc3-system"
            else
                self:warning("Unknown source type " .. lastHc3CommandSourceType)
            end
        end

        --genericPayload.debugDiffHc3 = diffHc3
        --genericPayload.debugDiffMqtt = diffMqtt
        genericPayload.source = source

        if (device.fibaroBaseType == "com.fibaro.multilevelSwitch") then
            if propertyName == "state" then
                --self:debug("state --> value")
                propertyName = "value" 
            elseif propertyName == "value" then
                --self:debug("value --> brightness")
                propertyName = "brightness" 
            else
                -- no workaround required for other properties
            end
        elseif (device.fibaroBaseType == "com.fibaro.baseShutter") then
            if propertyName == "state" then
                --self:debug("state --> value")
                --propertyName = "value" 
            elseif propertyName == "value" then
                --self:debug("value --> position")
                propertyName = "position" 
            else
                -- no workaround required for other properties
            end
        --elseif (device.haType == "climate") then
        end

        self:dispatchPropertyUpdateEvent(
            device, 
            event,
            genericPayload,
            propertyName
            )

    elseif (event.type == "DeviceModifiedEvent") then
        self:dispatchDeviceModifiedEvent(device)

    elseif (event.type == "CentralSceneEvent") then
        if (device.fibaroType == "com.fibaro.keyFob") then
            self:dispatchCentralSceneEvent(
                device, 
                event,
                genericPayload
                )
        end
    
    elseif (event.type == "DeviceCreatedEvent") then
        self:dispatchDeviceCreatedEvent(device)

    elseif (event.type == "DeviceRemovedEvent") then
        self:dispatchDeviceRemovedEvent(device)

    else
        self:warning("TBD: Need to introduce new event type for " .. tostring(event.type))
        -- unknown event type

    end

    -- PUBLISH RAW EVENT FOR DEBUG PURPOSES

    --self:debug("!" .. event.type .. " - " .. json.encode(device))

    self:publish(
        createGenericEventTopicName(device, event.type) .. "/raw_event",
        json.encode(event)
    )
end

function QuickApp:rememberLastHc3CommandTime(deviceId, sourceType)
    self.lastHc3CommandTime[deviceId] = os.time()
    self.lastHc3CommandSourceType[deviceId] = sourceType
end

function QuickApp:rememberLastMqttCommandTime(deviceId)
    self.lastMqttCommandTime[deviceId] = os.time()
end

function QuickApp:dispatchPropertyUpdateEvent(device, event, payload, propertyName)
    -- PUBLISH DEVICE STATUS FOR HA AND NODE-RED
    local topic = createPropertyTopicName(device, propertyName)

    local value = (type(event.data.newValue) == "number" and event.data.newValue or tostring(event.data.newValue))
    if not value then
        --self:warning("No property value found. Ignoring event")
        --return
    elseif value == "nil" then
        --self:warning("Nil property value found. Ignoring event")
        --return
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
    local fibaroDeviceInfo = api.get("/devices/" .. device.id)

    if (fibaroDeviceInfo.visible and fibaroDeviceInfo.enabled) then
        self:debug("Device created " .. json.encode(fibaroDeviceInfo))
        self:publishDeviceToMqtt(fibaroDeviceInfo)
    end
end

function QuickApp:dispatchDeviceModifiedEvent(device)
    self:debug("Device modified " .. device.id)

    self:dispatchDeviceRemovedEvent(device)

    self:dispatchDeviceCreatedEvent(device)
end

function QuickApp:dispatchDeviceRemovedEvent(device)
    self:debug("Device removed " .. device.id)
    self:removeDeviceFromMqtt(device)
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


function QuickApp:getDevice(deviceId)
    local device = self:getDeviceFromCache(deviceId)

    if not device then
        device = self:getDeviceUncached(deviceId)

        self.deviceById[deviceId] = device
    end
    
    return device
end

function QuickApp:getDeviceFromCache(deviceId)
    return self.deviceById[deviceId]
end

function QuickApp:getDeviceAndRefreshCache(deviceId)
    self.deviceById[deviceId] = self:getDeviceUncached(deviceId)

    return self:getDevice(deviceId)
end

function QuickApp:getDeviceUncached(deviceId)
    local deviceName = fibaro.getName(deviceId)
    if (not deviceName) then
        self:warning("No device name for " .. deviceId)
        deviceName = "unknown"
    end

    local roomName = fibaro.getRoomNameByDeviceID(deviceId)
    
    local fibaroDeviceBaseType = self:getFibaroDeviceBaseTypeById(deviceId)
    local fibaryDeviceType = self:getFibaroDeviceTypeById(deviceId)
    local haDeviceType = self:getHaDeviceTypeById(deviceId)


    -- extract meta information from device name if available, and purify device name
    local metaInfo = extractMetaInfoFromDeviceName(deviceName)
    if (metaInfo and metaInfo.pureName) then
        deviceName = metaInfo.pureName
    end
    metaInfo.haType = haDeviceType or "unknown"

    local device = {
        id = deviceId,
        name = deviceName, 
        fibaroBaseType = fibaroDeviceBaseType or "unknown",
        fibaroType = fibaryDeviceType or "unknown",
        haType = metaInfo.haType,
        --haType = "unknown",
        roomName = roomName,
        metaInfo = metaInfo
    }

    return device
end

function QuickApp:getFibaroDeviceBaseTypeById(deviceId)
    local fibaroBaseType = self.fibaroDeviceBaseTypeById[deviceId]
    if not fibaroBaseType then
        fibaroBaseType = "unknown"
    end

    return fibaroBaseType
end

function QuickApp:getFibaroDeviceTypeById(deviceId)
    local fibaroType = self.fibaroDeviceTypeById[deviceId]
    if not fibaroType then
        fibaroType = "unknown"
    end

    return fibaroType
end

function QuickApp:getHaDeviceTypeById(deviceId)
    local haType = self.haDeviceTypeById[deviceId]
    if not haType then
        haType = "unknown"
    end

    return haType
end

function QuickApp:getDeviceDescription(deviceId)
    if (deviceId) then
        local device = self:getDevice(deviceId) 

        if device and device.name and device.id and device.roomName then
            return device.name .. " #" .. device.id .. " (" .. tostring(device.roomName) .. ")"
        else
            return device.id
        end
    else
        return "no device id"
    end
end

-- TODO: com.fibaro.seismometer
-- TODO: com.fibaro.accelerometer

-- eye seismometer
--  "type": "com.fibaro.seismometer",
--  "baseType": "com.fibaro.multilevelSensor",

-- eye accelerometer
--  "type": "com.fibaro.accelerometer",
--  "baseType": "com.fibaro.sensor",

-- tamper for flood sensor
-- "type": "com.fibaro.motionSensor",
-- "baseType": "com.fibaro.securitySensor",