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

function MqttConventionPrototype:onDeviceCreated(device)
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onDeviceRemoved(device)
    error("function is mandatory for implementation")
end

function MqttConventionPrototype:onPropertyUpdated(device, event)
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
function MqttConventionHomeAssistant:getDeviceTopic(device)
    return self.rootTopic .. device.bridgeType .. "/" .. device.id .. "/"
end
function MqttConventionHomeAssistant:getGenericEventTopic(device, eventType, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(device) .. "events/" .. eventType .. "/" .. propertyName 
    else
        return self:getDeviceTopic(device) .. "events/" .. eventType
    end
end
function MqttConventionHomeAssistant:getterTopic(device, propertyName)
    if (device.linkedDevice and propertyName == "value") then
        local result = self:getGenericEventTopic(device.linkedDevice, "DevicePropertyUpdatedEvent", device.linkedProperty)

        return result
    else
        return self:getGenericEventTopic(device, "DevicePropertyUpdatedEvent", propertyName)
    end
end
function MqttConventionHomeAssistant:getGenericCommandTopic(device, command, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(device) .. command ..  "/" .. propertyName
    else
        return self:getDeviceTopic(device) .. command
    end
end

function MqttConventionHomeAssistant:setterTopic(device, propertyName)
    return self:getGenericCommandTopic(device, "set", propertyName)
end

function MqttConventionHomeAssistant:getLastWillAvailabilityTopic()
    return self.rootTopic .. "hc3-dead"
end

function MqttConventionHomeAssistant:getLastWillMessage()
    return {
        topic = self:getLastWillAvailabilityTopic(),
        payload = "true"
    }    
end

function MqttConventionHomeAssistant:onConnected()
    self.mqtt:publish(self.rootTopic .. "hc3-dead", "false", {retain = true})
    self.mqtt:subscribe(self.rootTopic .. "+/+/set/+")
end

function MqttConventionHomeAssistant:onDisconnected()
    self.mqtt:publish(self.rootTopic .. "hc3-dead", "true", {retain = true})
end

function MqttConventionHomeAssistant:onDeviceCreated(device)
    ------------------------------------------
    --- AVAILABILITY
    ------------------------------------------
    local msg = {
        unique_id = tostring(device.id),
        name = device.name .. " (" .. device.roomName .. ")",

        availability_mode = "all",
        availability = {
            {
                topic = self:getLastWillAvailabilityTopic(),
                payload_available = "false",
                payload_not_available = "true"
            }
            ,
            {
                topic = self:getterTopic(device, "dead"),
                payload_available = "false",
                payload_not_available = "true" 
            }
        },

        json_attributes_topic = self:getDeviceTopic(device) .. "config_json_attributes" 
    }

    ------------------------------------------
    --- PARENT DEVICE INFO
    ------------------------------------------
    local parentDevice = device.bridgeParent
    if parentDevice then
        msg.device = {
            identifiers = "hc3-" .. parentDevice.id,
            name = parentDevice.name,
            manufacturer = parentDevice.properties.zwaveCompany,
            model = parentDevice.properties.model, 
            -- zwave version is used instead of device software version
            sw_version = parentDevice.properties.zwaveVersion
        }
    end

    ------------------------------------------
    --- USE "TRUE"/"FALSE" VALUE PAYLOAD, instead of "ON"/"OFF"
    ------------------------------------------
    if (device.bridgeRead) then
        if (device.bridgeBinary and device.bridgeType ~= "cover") then 
            msg.payload_on = "true"
            msg.payload_off = "false"
        end
    end
    
    ------------------------------------------
    ---- READ
    ------------------------------------------
    -- Does device have binary state to share?
    if (device.bridgeRead and device.bridgeBinary) then
        msg.state_topic = self:getterTopic(device, "state")
        
        if (device.bridgeType == "light") then
            msg.state_value_template = "{{ value_json.value }}"
        else
            -- wish Home Assistant spec was consistent for all device types and "state_value_template" was used for all the devices with "state" property
            msg.value_template = "{{ value_json.value }}"
        end
    end
    -- Does device have multilevel state to share?
    if (device.bridgeRead and device.bridgeMultilevel) then
        if (device.bridgeType == "light") then
            msg.brightness_state_topic = self:getterTopic(device, "value")
            msg.brightness_value_template = "{{ value_json.value }}"
        elseif (device.bridgeType == "cover") then
            msg.position_topic = self:getterTopic(device, "value")
        elseif (device.bridgeType == "sensor") then
            msg.state_topic = self:getterTopic(device, "value")
            msg.value_template = "{{ value_json.value }}"
        else
            msg.value_template = "{{ value_json.value }}"
        end
    end

    ------------------------------------------
    ---- WRITE
    ------------------------------------------
    -- Does device support binary write operations?
    if (device.bridgeWrite and device.bridgeBinary) then
        msg.command_topic = self:setterTopic(device, "state")
    end
    -- Does device support multilevel write operations?
    if (device.bridgeWrite) and (device.bridgeMultilevel) then
        if (device.bridgeType == "light") then
            msg.brightness_command_topic = self:setterTopic(device, "value")
            msg.brightness_scale = 99
            msg.on_command_type = "brightness"
        elseif (device.bridgeType == "cover") then
            msg.set_position_topic = self:setterTopic(device, "value")
            msg.position_template = "{{ value_json.value }}"
            -- value_template is deprecated since Home Assistant Core 2021.6.
            msg.value_template = nil
            msg.position_open = 99
            msg.position_closed = 0

            msg.payload_open = "open"
            msg.payload_close = "close"
            msg.payload_stop = "stop"

            msg.state_open = "open"
            msg.state_closed = "closed"
            msg.state_opening = "opening"
            msg.state_closing = "closing"
            msg.state_topic = self:setterTopic(device, "state")
        end
    end

    ------------------------------------------
    ---- SENSOR SPECIFIC
    ------------------------------------------
    if (device.bridgeType == "binary_sensor" or device.bridgeType == "sensor") then
        if (PrototypeDevice.bridgeSubtype ~= device.bridgeSubtype) then
            msg.device_class = device.bridgeSubtype
        end
        if (PrototypeDevice.bridgeUnitOfMeasurement ~= device.bridgeUnitOfMeasurement) then
            msg.unit_of_measurement = device.bridgeUnitOfMeasurement
        end

        -- Energy meter requires extra properties
        if (device.bridgeSubtype == "energy") then
            msg.state_class = "measurement"
            msg.last_reset_topic = self:getterTopic(device, "lastReset")
            msg.last_reset_value_template = "{{ value_json.value }}"
        end
    end

    ------------------------------------------
    ---- THERMOSTAT SPECIFIC
    ------------------------------------------
    if (device.bridgeType == "climate") then
        msg.modes = device.properties.supportedThermostatModes
 
        msg.temperature_unit = device.properties.unit
        msg.temp_step = device.properties.heatingThermostatSetpointStep[msg.temperature_unit]

        -- MODE 
        msg.mode_state_topic = self:getterTopic(device, "thermostatMode")
        msg.mode_command_topic = self:setterTopic(device, "thermostatMode")

        -- MIX/MAX TEMPERATURE
        msg.min_temp = device.properties.heatingThermostatSetpointCapabilitiesMin
        msg.max_temp = device.properties.heatingThermostatSetpointCapabilitiesMax

        -- TARGET TEMPERATURE
        msg.temperature_state_topic = self:getterTopic(device, "heatingThermostatSetpoint")
        msg.temperature_command_topic = self:setterTopic(device, "heatingThermostatSetpoint")
        
        -- CURRENT TEMPERATURE
        local temperatureSensorDevice = device:getTemperatureSensor(self.devices)
        if temperatureSensorDevice then 
            msg.current_temperature_topic = self:getterTopic(temperatureSensorDevice, "value")
        end
    end

    self.mqtt:publish(self:getDeviceTopic(device) .. "config", json.encode(msg), {retain = true})
    
    self.mqtt:publish(self:getDeviceTopic(device) .. "config_json_attributes", json.encode(device.fibaroDevice), {retain = true})
end

function MqttConventionHomeAssistant:onDeviceRemoved(device)
    self.mqtt:publish(
        self:getDeviceTopic(device) .. "config", 
        "" 
    )
end

function MqttConventionHomeAssistant:onPropertyUpdated(device, event)
    local propertyName = event.data.property

    local value = event.data.newValue

    if device.bridgeType == "cover" then 
        if propertyName == "value" then
            -- Fibaro doesn't use "state" attribute for covers, so we'll trigger it on behalf of Fibaro based on "value" attribute
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
                    id = device.id,
                    deviceName = device.name,
                    created = event.created,
                    timestamp = os.date(),
                    roomName = device.roomName,
                    value = state
                }
                formattedState = json.encode(payload)
                --formattedState = state
                self.mqtt:publish(self:getterTopic(device, "state"), formattedState, {retain = true})
            end
        elseif propertyName == "state" then
            if (value == "unknown") then
                -- drop event as Fibaro has "Uknnown" value constantly assigned to the "state" attribute 
                return
            end
        end
    end

    value = string.lower(value)

    local formattedPayload
    if (propertyName == "dead") then
        formattedPayload = tostring(value)
    else
        local payload = {
            id = device.id,
            deviceName = device.name,
            created = event.created,
            timestamp = os.date(),
            roomName = device.roomName,
            value = value
        }
        formattedPayload = json.encode(payload)
    end

    self.mqtt:publish(self:getterTopic(device, propertyName), formattedPayload, {retain = true})
end

function MqttConventionHomeAssistant:onCommand(event)
    if (string.find(event.topic, self.rootTopic) == 1) then
        -- Home Assistant command detected
        local topicElements = splitString(event.topic, "/")
        local deviceId = tonumber(topicElements[3])
        local propertyName = topicElements[5]

        local device = self.devices[deviceId]

        local value = event.payload

        if (device.bridgeType == "climate") then
            -- Fibaro HC3 uses first letter in upper case, and HA relies on lower case
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

function MqttConventionHomie:onDeviceCreated(device)
    self.mqtt:publish(self:getDeviceTopic(device) .. "$homie", "2.1.0", {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "$name", device.name .. " (" .. device.roomName .. ")", {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "$implementation", "Fibaro HC3 to MQTT bridge", {retain = true})

    self.mqtt:publish(self:getDeviceTopic(device) .. "$nodes", "node", {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "node/$name", device.name, {retain = true})
    self.mqtt:publish(self:getDeviceTopic(device) .. "node/$type", "", {retain = true})

    self.mqtt:publish(self:getDeviceTopic(device) .. "$extensions", "", {retain = true})

    local properties = { }

    if (device.bridgeRead) then
        local propertyName = device.bridgeType
        if (PrototypeDevice.bridgeSubtype ~= device.bridgeSubtype) then
            propertyName = propertyName .. " - " .. device.bridgeSubtype
        end

        if (device.bridgeBinary) then
            properties["state"] = {
                name = device.bridgeType,
                datatype = "boolean",
                settable = device.bridgeWrite, 
                retained = true,
            }
        end

        if (device.bridgeMultilevel) then
            properties["value"] = {
                name = device.bridgeType,
                datatype = "integer",
                settable = device.bridgeWrite,
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
    if (device.dead) then
        homieState = "lost"
    else
        homieState = "ready"
    end
    self.mqtt:publish(self:getDeviceTopic(device) .. "$state", homieState, {retain = true})
end

function MqttConventionHomie:onDeviceRemoved(device)
end

function MqttConventionHomie:onPropertyUpdated(device, event)
    local propertyName = event.data.property

    local value = event.data.newValue

    value = string.lower(value)

    self.mqtt:publish(self:getDeviceTopic(device) .. "node/" .. propertyName, value, {retain = true})
end

function MqttConventionHomie:onCommand(event)
    if (string.find(event.topic, self.rootTopic) == 1) then
        local topicElements = splitString(event.topic, "/")
        local deviceId = tonumber(topicElements[2])
        local device = self.devices[deviceId]

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
function MqttConventionDebug:onDeviceCreated(device)
end
function MqttConventionDebug:onDeviceRemoved(device)
end
function MqttConventionDebug:onPropertyUpdated(device, event)
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
