MqttConventionPrototype = {
    type = "'type' needs to be overriden", 
    mqtt = "MQTT connection must be established first"
}
 
function MqttConventionPrototype:getLastWillMessage() 
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onConnected()
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onDeviceNodeCreated(deviceNode)
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onDeviceNodeRemoved(deviceNode)
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onPropertyUpdated(deviceNode, event)
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onCommand(event)
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onDisconnected()
    error("function is mandatory for implementation")
end

-----------------------------------
-- HOME ASSISTANT 
-----------------------------------
MqttConventionHomeAssistant = inheritFrom(MqttConventionPrototype) 
MqttConventionHomeAssistant.type = "Home Assistant"
MqttConventionHomeAssistant.rootTopic = "homeassistant/"

-- TOPICS 
function MqttConventionHomeAssistant:getDeviceTopic(haEntity)
    -- *** rework to use own TOPICS and remove type usage
    return self.rootTopic .. tostring(haEntity.type) .. "/" .. haEntity.id .. "/"
end
function MqttConventionHomeAssistant:getGenericEventTopic(haEntity, eventType, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(haEntity) .. "events/" .. eventType .. "/" .. propertyName 
    else
        return self:getDeviceTopic(haEntity) .. "events/" .. eventType
    end
end
function MqttConventionHomeAssistant:getterTopic(haEntity, propertyName)
    -- *** REWORK TO USE ALL LINKED DEVICE PROPERTIES?
    if (haEntity.linkedEntity and propertyName == "value") then
        local result = self:getGenericEventTopic(haEntity.linkedEntity, "DevicePropertyUpdatedEvent", haEntity.linkedProperty)
        return result
    elseif (haEntity.linkedEntity and propertyName == "dead") then
        local result = self:getGenericEventTopic(haEntity.linkedEntity, "DevicePropertyUpdatedEvent", "dead")
        return result
    else
        return self:getGenericEventTopic(haEntity, "DevicePropertyUpdatedEvent", propertyName)
    end
end
function MqttConventionHomeAssistant:getGenericCommandTopic(haEntity, command, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(haEntity) .. command ..  "/" .. propertyName
    else
        return self:getDeviceTopic(haEntity) .. command
    end
end

function MqttConventionHomeAssistant:setterTopic(haEntity, propertyName)
    return self:getGenericCommandTopic(haEntity, "set", propertyName)
end

function MqttConventionHomeAssistant:getLastWillAvailabilityTopic()
    return self.rootTopic .. "hc3-dead"
end

function MqttConventionHomeAssistant:getLastWillMessage()
    return {
        topic = self:getLastWillAvailabilityTopic(),
        payload = "true",
        {
            retain = true
        }
    }    
end

function MqttConventionHomeAssistant:onConnected()
    self.mqtt:publish(self.rootTopic .. "hc3-dead", "false", {retain = true})
    self.mqtt:subscribe(self.rootTopic .. "+/+/set/+")
end

function MqttConventionHomeAssistant:onDisconnected()
    self.mqtt:publish(self.rootTopic .. "hc3-dead", "true", {retain = true})
end

function MqttConventionHomeAssistant:onDeviceNodeCreated(deviceNode)
    local haEntity = deviceNode.identifiedHaEntity
    --print("PUBLISH DEVICE: " .. deviceNode.fibaroDevice.id .. " " .. deviceNode.fibaroDevice.name)
    if (haEntity.type == RemoteControllerKey.type) then
        -- Home Assistant pretty unique spec for "device_automation/trigger" devices
        -- so better use another factory type for MQTT Discovery Message
        MqttConventionHomeAssistant:onRemoteControllerKeyCreated(deviceNode, self.mqtt)
        return
    end

    ------------------------------------------
    --- AVAILABILITY
    ------------------------------------------
    local msg = {
        unique_id = tostring(haEntity.id),
        object_id = tostring(haEntity.id),
        name = haEntity.name .. " (" .. haEntity.roomName .. ")",

        availability_mode = "all",
        availability = {
            {
                topic = self:getLastWillAvailabilityTopic(),
                payload_available = "false",
                payload_not_available = "true"
            }
            ,
            {
                topic = self:getterTopic(haEntity, "dead"),
                payload_available = "false",
                payload_not_available = "true" 
            }
        },

        json_attributes_topic = self:getDeviceTopic(haEntity) .. "config_json_attributes" 
    }

    ------------------------------------------
    --- PARENT DEVICE INFO
    ------------------------------------------
    msg.device = deviceNode.identifiedHaDevice

    ------------------------------------------
    --- USE "TRUE"/"FALSE" VALUE PAYLOAD, instead of "ON"/"OFF"
    ------------------------------------------
    if (haEntity.supportsRead) then
        if (haEntity.supportsBinary and haEntity.type ~= "cover") then 
            msg.payload_on = "true"
            msg.payload_off = "false"
        end
    end
    
    ------------------------------------------
    ---- READ
    ------------------------------------------
    -- Does device have binary state to share?
    if (haEntity.supportsRead and haEntity.supportsBinary) then
        msg.state_topic = self:getterTopic(haEntity, "state")
        
        if (haEntity.type == "light") then
            msg.state_value_template = "{{ value_json.value }}"
        else
            -- wish Home Assistant spec was consistent for all device types and "state_value_template" was used for all the devices with "state" property
            msg.value_template = "{{ value_json.value }}"
        end
    end
    -- Does device have multilevel state to share?
    if (haEntity.supportsRead and haEntity.supportsMultilevel) then
        if (haEntity.type == "light") then
            msg.brightness_state_topic = self:getterTopic(haEntity, "value")
            msg.brightness_value_template = "{{ value_json.value }}"
        elseif (haEntity.type == "cover") then
            -- Home Assistant to interpret state from "position_topic"
            msg.state_topic = nil

            msg.position_topic = self:getterTopic(haEntity, "value")
        elseif (haEntity.type == "sensor") then
            msg.state_topic = self:getterTopic(haEntity, "value")
            msg.value_template = "{{ value_json.value }}"
        else
            msg.value_template = "{{ value_json.value }}"
        end
    end

    ------------------------------------------
    ---- WRITE
    ------------------------------------------
    -- Does haEntity support binary write operations?
    if (haEntity.supportsWrite and haEntity.supportsBinary) then
        msg.command_topic = self:setterTopic(haEntity, "state")
    end
    -- Does haEntity support multilevel write operations?
    if (haEntity.supportsWrite) and (haEntity.supportsMultilevel) then
        if (haEntity.type == "light") then
            msg.brightness_command_topic = self:setterTopic(haEntity, "value")
            msg.brightness_scale = 99
            msg.on_command_type = "first"
        elseif (haEntity.type == "cover") then
            msg.set_position_topic = self:setterTopic(haEntity, "value")
            msg.position_template = "{{ value_json.value }}"
            -- value_template is deprecated since Home Assistant Core 2021.6.
            msg.value_template = nil
            msg.position_open = 100
            msg.position_closed = 0

            msg.payload_open = "open"
            msg.payload_close = "close"
            msg.payload_stop = "stop"

            --[[
            msg.state_closed = "closed"
            msg.state_closing = "closing"
            msg.state_open = "open"
            msg.state_opening = "opening"
            ]]--

            msg.state_topic = self:setterTopic(haEntity, "state")
        end
    end

    ------------------------------------------
    ---- SENSOR SPECIFIC
    ------------------------------------------
    if (haEntity.type == "binary_sensor" or haEntity.type == "sensor") then
        -- *** refactor, but keep device_class 'None' when default sensor is used by the QuickApp
        if (PrototypeEntity.subtype ~= haEntity.subtype) then
            msg.device_class = haEntity.subtype
        end
        -- *** refactor?
        if (PrototypeEntity.bridgeUnitOfMeasurement ~= haEntity.bridgeUnitOfMeasurement) then
            msg.unit_of_measurement = haEntity.bridgeUnitOfMeasurement
        end

        -- Energy meter requires extra properties
        if (haEntity.subtype == "energy") then
            msg.state_class = "total_increasing"
        end

        if (haEntity.subtype == RemoteController.subtype) then
            -- Remote controller sensor is not natively supported by Home Assistant, thus need to replace "remoteController" subtype with "None" haEntity class
            msg.device_class = nil
            -- Add "remote" icon
            msg.icon = "mdi:remote"
        end

        if (haEntity.type == RemoteController.type) and (haEntity.subtype == RemoteController.subtype) then
            msg.expire_after = 10
        end
    end

    ------------------------------------------ 
    ---- THERMOSTAT SPECIFIC (HEATING)
    ------------------------------------------
    -- *** ADD SUPPORT FOR COOLING MODE IN THE FUTURE
    if (haEntity.type == "climate") then
        -- **** refactor
        msg.modes = deviceNode.identifiedHaEntity.properties.supportedThermostatModes
        --msg.modes = deviceNode.fibaroDevice.properties.supportedThermostatModes
 
        msg.temperature_unit = deviceNode.fibaroDevice.properties.unit
        msg.temp_step = deviceNode.fibaroDevice.properties.heatingThermostatSetpointStep[msg.temperature_unit]

        -- MODE 
        msg.mode_state_topic = self:getterTopic(haEntity, "thermostatMode")
        msg.mode_command_topic = self:setterTopic(haEntity, "thermostatMode")

        -- *** 
        -- MIX/MAX TEMPERATURE
        msg.min_temp = deviceNode.fibaroDevice.properties.heatingThermostatSetpointCapabilitiesMin
        msg.max_temp = deviceNode.fibaroDevice.properties.heatingThermostatSetpointCapabilitiesMax

        -- TARGET TEMPERATURE
        msg.temperature_state_topic = self:getterTopic(haEntity, "heatingThermostatSetpoint")
        msg.temperature_command_topic = self:setterTopic(haEntity, "heatingThermostatSetpoint")
        
        -- CURRENT TEMPERATURE
        local temperatureSensorEntity = haEntity:getTemperatureSensor()
        if temperatureSensorEntity then 
            msg.current_temperature_topic = self:getterTopic(temperatureSensorEntity, "value")
        end
    end

    ------------------------------------------
    ---- RGBW
    ------------------------------------------
    if (haEntity.type == "light" and haEntity.subtype == "rgbw") then
        msg.rgbw_state_topic = self:getterTopic(haEntity, "color")
        msg.rgbw_value_template = "{{ value_json.value.split(',')[:4] | join(',') }}"
        msg.rgbw_command_topic = self:setterTopic(haEntity, "color")
    end

    self.mqtt:publish(self:getDeviceTopic(haEntity) .. "config", json.encode(msg), {retain = true})

    self.mqtt:publish(self:getDeviceTopic(haEntity) .. "config_json_attributes", json.encode(deviceNode.fibaroDevice), {retain = true})
end

function MqttConventionHomeAssistant:onRemoteControllerKeyCreated(deviceNode, mqtt)
    local haEntity = deviceNode.identifiedHaEntity
    
    local keyId = deviceNode.fibaroDevice.keyId
    local keyType = self:convertKeyAttributeToType(deviceNode.fibaroDevice.keyAttribute)
    
    local msg = {
        automation_type = "trigger",

        topic = self:getterTopic(haEntity, "value"),
        value_template = "{{ value_json.value }}", 

        type = keyType, 
        subtype = "button_" .. keyId,
        payload = keyId .. "-" .. keyType
    }

    ------------------------------------------
    --- PARENT DEVICE INFO
    ------------------------------------------
    msg.device = deviceNode.identifiedHaDevice

    mqtt:publish(self:getDeviceTopic(haEntity) .. "config", json.encode(msg), {retain = true})
end

local keyAttributeToTypeMap = {
    ["pressed"] = "button_short_press",
    ["pressed2"] = "button_double_press",
    ["pressed3"] = "button_triple_press",
    ["helddown"] = "button_long_press",
    ["released"] = "button_long_release"
}
function MqttConventionHomeAssistant:convertKeyAttributeToType(keyAttribute)
    local type = keyAttributeToTypeMap[keyAttribute]
    if not type then
        print("Unknown key attribute \"" .. tostring(keyAttribute) .. "\"")
        type = "unknown-" .. keyAttribute
    end

    return type
end

function MqttConventionHomeAssistant:onDeviceNodeRemoved(deviceNode)
    self.mqtt:publish(
        self:getDeviceTopic(deviceNode.identifiedHaEntity) .. "config", 
        "",
        {retain = true} 
    )
end

function MqttConventionHomeAssistant:onPropertyUpdated(deviceNode, event)
    local propertyName = event.data.property

    local value = event.data.newValue

    local haEntity = deviceNode.identifiedHaEntity

    -------------------------------------------
    -- COVER SPECIFIC
    -------------------------------------------
    if haEntity.type == "cover" then 
        if propertyName == "value" then
            -- Fibaro doesn't use "state" attribute for covers, so we'll trigger it on behalf of Fibaro based on "value" attribute
            --[[
            local state
            if value < 20 then
                state = "closed"
            elseif value > 80 then
                state = "open"
            else
                state = "unknown"
            end

            if state then
                local payload = {
                    id = haEntity.id,
                    deviceName = haEntity.name,
                    created = event.created,
                    timestamp = os.date(),
                    roomName = haEntity.roomName,
                    value = state
                }
                formattedState = json.encode(payload)
                self.mqtt:publish(self:getterTopic(haEntity, "state"), formattedState, {retain = true})
            end
            ]]--
        elseif propertyName == "state" then
            if (value == "unknown") then
                -- drop event as Fibaro has "Uknnown" value assigned to the "state" attribute 
                return
            end
        end
    end

    -------------------------------------------
    -- REMOTE CONTROLLER (SENSOR) SPECIFIC
    -------------------------------------------
    if haEntity.type == RemoteController.type and haEntity.subtype == RemoteController.subtype and propertyName == "value" then
        local keyValues = splitString(value, ",")

        local keyId = keyValues[1]
        local keyAttribute = keyValues[2]
        local keyType = self:convertKeyAttributeToType(keyAttribute)
        
        value = keyId .. "-" .. keyType
    end
    
    value = string.lower(value)

    local formattedPayload 
    if propertyName == "dead" then
    -- *** CHECK/REFACTOR
    --if ((propertyName == "dead") or (device.type == RemoteController.type and device.subtype == RemoteController.subtype)) then
        formattedPayload = tostring(value)
    else
        local payload = {
            id = haEntity.id,
            deviceName = haEntity.name,
            created = event.created,
            timestamp = os.date(),
            roomName = haEntity.roomName,
            value = value
        }
        formattedPayload = json.encode(payload)
    end

    -- *** DUPLICATE?
    self.mqtt:publish(self:getterTopic(haEntity, propertyName), formattedPayload, {retain = true})
end

function MqttConventionHomeAssistant:onCommand(event)
    if (string.find(event.topic, self.rootTopic) == 1) then
        -- Home Assistant command detected
        local topicElements = splitString(event.topic, "/")
        local deviceId = tonumber(topicElements[3])
        local propertyName = topicElements[5]

        local device = deviceNodeById[deviceId].identifiedHaEntity

        local value = event.payload

        if (device.type == "climate") then
            -- Fibaro HC3 uses first letter in upper case, and HA relies on lower case
            -- *** rename to firstCharacter
            local firstPart = string.upper(string.sub(value, 1, 1))
            local secondPart = string.sub(value, 2, string.len(value))
            value = firstPart .. secondPart
        end

        device:setProperty(propertyName, value)
    end
end

-----------------------------------
-- HOMIE
-----------------------------------
MqttConventionHomie = inheritFrom(MqttConventionPrototype) 
MqttConventionHomie.type = "Homie"
MqttConventionHomie.rootTopic = "homie/"

-- TOPICS 
function MqttConventionHomie:getDeviceTopic(device)
    return self.rootTopic .. device.id .. "/"
end
function MqttConventionHomie:getGenericEventTopic(device, eventType, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(device) .. "events/" .. eventType .. "/" .. propertyName 
    else
        return self:getDeviceTopic(device) .. "events/" .. eventType
    end
end
function MqttConventionHomie:getterTopic(device, propertyName)
    return self:getGenericEventTopic(device, "DevicePropertyUpdatedEvent", propertyName)     
end
function MqttConventionHomie:getGenericCommandTopic(device, command, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(device) .. command ..  "/" .. propertyName
    else
        return self:getDeviceTopic(device) .. command
    end
end

function MqttConventionHomie:getSetterTopic(device, propertyName)
    return self:getGenericCommandTopic(device, "set", propertyName)
end

function MqttConventionHomie:getLastWillMessage() 
    return {
        topic = self.rootTopic .. "hc3-dead",
        payload = "true",
        lastWill = true
    }    
end

function MqttConventionHomie:onConnected()
    self.mqtt:subscribe(self.rootTopic .. "+/+/+/set")
end

function MqttConventionHomie:onDisconnected()
end

function MqttConventionHomie:onDeviceNodeCreated(deviceNode)
    local device = deviceNode.identifiedHaEntity

    self.mqtt:publish(self:getDeviceTopic(device) .. "$homie", "2.1.0", {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "$name", device.name .. " (" .. deviceNode.fibaroDevice.roomName .. ")", {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "$implementation", "Fibaro HC3 to MQTT bridge", {retain = true})

    self.mqtt:publish(self:getDeviceTopic(device) .. "$nodes", "node", {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "node/$name", device.name, {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "node/$type", "", {retain = true})

    self.mqtt:publish(self:getDeviceTopic(device) .. "$extensions", "", {retain = true})

    local properties = { }

    if (device.supportsRead) then
        local propertyName = device.type
        -- *** get rid of this check
        --if (PrototypeEntity.subtype ~= device.subtype) then
            propertyName = propertyName .. " - " .. tostring(device.subtype)
        --end

        if (device.supportsBinary) then
            properties["state"] = {
                name = device.type,
                datatype = "boolean",
                settable = device.supportsWrite, 
                retained = true,
            }
        end

        if (device.supportsMultilevel) then
            properties["value"] = {
                name = device.type,
                datatype = "integer",
                settable = device.supportsWrite,
                retained = true,
                unit = device.bridgeUnitOfMeasurement
            }
        end
    end

    local propertiesStr = ""
    local firstParameter = true
    for i, j in pairs(properties) do
        if (not firstParameter) then
            propertiesStr = propertiesStr .. ","
        end
        propertiesStr = propertiesStr .. i
        firstParameter = false
    end

    self.mqtt:publish(self:getDeviceTopic(device) .. "node/$properties", propertiesStr, {retain = true})

    for i, j in pairs(properties) do
        local propertyTopic = self:getDeviceTopic(device) .. "node/" .. i .. "/$"
        for m, n in pairs(j) do
            self.mqtt:publish(propertyTopic .. m, tostring(n), {retain = true})
        end
    end

    local homieState
    if (deviceNode.fibaroDevice.dead) then
        homieState = "lost"
    else
        homieState = "ready"
    end
    self.mqtt:publish(self:getDeviceTopic(device) .. "$state", homieState, {retain = true})
end

function MqttConventionHomie:onDeviceNodeRemoved(deviceNode)
end

function MqttConventionHomie:onPropertyUpdated(deviceNode, event)
    local propertyName = event.data.property

    local value = event.data.newValue

    -- *** rename device to haEntity
    local device = deviceNode.identifiedHaEntity

    value = string.lower(value)

    self.mqtt:publish(self:getDeviceTopic(device) .. "node/" .. propertyName, value, {retain = true})
end

function MqttConventionHomie:onCommand(event)
    if (string.find(event.topic, self.rootTopic) == 1) then
        local topicElements = splitString(event.topic, "/")
        local deviceId = tonumber(topicElements[2])
        local device = deviceNodeById[deviceId].identifiedHaEntity

        local propertyName = topicElements[4]
        local value = event.payload

        device:setProperty(propertyName, value)
    end
end

-----------------------------------
-- FOR EXTENDED DEBUG PURPOSES
-----------------------------------

MqttConventionDebug = inheritFrom(MqttConventionPrototype) 
MqttConventionDebug.type = "Debug"
function MqttConventionDebug:getLastWillMessage() 
end
function MqttConventionDebug:onDeviceNodeCreated(deviceNode)
end
function MqttConventionDebug:onDeviceNodeRemoved(deviceNode)
end
function MqttConventionDebug:onPropertyUpdated(deviceNode, event)
end
function MqttConventionDebug:onConnected()
end
function MqttConventionDebug:onCommand(event)
end
function MqttConventionDebug:onDisconnected()
end

-----------------------------------
-- MQTT CONVENTION MAPPINGS
-----------------------------------

mqttConventionMappings = {
    ["home-assistant"] = MqttConventionHomeAssistant,
    ["homie"] = MqttConventionHomie,
    ["debug"] = MqttConventionDebug
} 


localIpAddress = identifyLocalIpAddressForHc3()
