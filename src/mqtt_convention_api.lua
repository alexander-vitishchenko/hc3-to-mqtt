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

function MqttConventionPrototype:onPropertyUpdateEvent(device, event)
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
function MqttConventionHomeAssistant:getPropertyTopic(device, propertyName)
    return self:getGenericEventTopic(device, "DevicePropertyUpdatedEvent", propertyName)     
end
function MqttConventionHomeAssistant:getGenericCommandTopic(device, command, propertyName) 
    if (propertyName) then
        return self:getDeviceTopic(device) .. command ..  "/" .. propertyName
    else
        return self:getDeviceTopic(device) .. command
    end
end

function MqttConventionHomeAssistant:getSetterTopic(device, propertyName)
    return self:getGenericCommandTopic(device, "set", propertyName)
end

function MqttConventionHomeAssistant:getLastWillMessage()
    return {
        topic = self.rootTopic .. "hc3-dead",
        payload = "true"
    }    
end

function MqttConventionHomeAssistant:onConnected()
    self.mqtt:publish(self.rootTopic .. "hc3-dead", "false")
    self.mqtt:subscribe(self.rootTopic .. "+/+/set/+")
end

function MqttConventionHomeAssistant:onDisconnected()
    self.mqtt:publish(self.rootTopic .. "hc3-dead", "true")
end

function MqttConventionHomeAssistant:onDeviceCreated(device)
    local msg = {
        unique_id = device.fibaroDevice.id,
        name = device.fibaroDevice.name .. " (" .. device.roomName .. ")",

        availability_topic = self:getPropertyTopic(device, "dead"),
        payload_available = "false",
        payload_not_available = "true", 

        json_attributes_topic = self:getDeviceTopic(device) .. "config_json_attributes" 
    }

    -- Setup "true"/"false" values to be used for device state tracking + JSON parser
    if (device.bridgeRead) then
        if (device.bridgeBinary and device.bridgeType ~= "cover") then 
            msg.payload_on = "true"
            msg.payload_off = "false"
        end
        msg.value_template = "{{ value_json.value }}"
    end
    
    ------------------------------------------
    ---- READ
    ------------------------------------------
    -- Does device have binary state to share?
    if (device.bridgeRead and device.bridgeBinary) then
        msg.state_topic = self:getPropertyTopic(device, "state")
    end
    -- Does device have multilevel state to share?
    if (device.bridgeRead and device.bridgeMultilevel) then
        if (device.bridgeType == "light") then
            msg.brightness_state_topic = self:getPropertyTopic(device, "value")
            msg.brightness_value_template = "{{ value_json.value }}"
        elseif (device.bridgeType == "cover") then
            msg.position_topic = self:getPropertyTopic(device, "value")
        elseif (device.bridgeType == "sensor") then
            msg.state_topic = self:getPropertyTopic(device, "value")
        end
    end

    ------------------------------------------
    ---- WRITE
    ------------------------------------------
    -- Does device support binary write operations?
    if (device.bridgeWrite and device.bridgeBinary) then
        msg.command_topic = self:getSetterTopic(device, "state")
    end
    -- Does device support multilevel write operations?
    if (device.bridgeWrite) and (device.bridgeMultilevel) then
        if (device.bridgeType == "light") then
            msg.brightness_command_topic = self:getSetterTopic(device, "value")
            msg.brightness_scale = 99
            msg.on_command_type = "brightness"
        elseif (device.bridgeType == "cover") then
            msg.set_position_topic = self:getSetterTopic(device, "value")
            msg.position_open = 99 
            msg.position_closed = 0

            msg.payload_open = "open"
            msg.payload_close = "close"
            msg.payload_stop = "stop"
        end
    end

    ------------------------------------------
    ---- SENSOR SPECIFIC
    ------------------------------------------
    if (device.bridgeType == "binary_sensor" or device.bridgeType == "sensor") then
        if (PrototypeDevice.bridgeUnitOfMeasurement ~= device.bridgeSubtype) then
            msg.device_class = device.bridgeSubtype
        end
        if (PrototypeDevice.bridgeUnitOfMeasurement ~= device.bridgeUnitOfMeasurement) then
            msg.unit_of_measurement = device.bridgeUnitOfMeasurement
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

function MqttConventionHomeAssistant:onPropertyUpdateEvent(device, event)
    local propertyName = event.data.property
    local payload = {
        id = device.id,
        deviceName = device.name,
        created = event.created,
        timestamp = os.date(),
        roomName = device.roomName
    }

    local value = (type(event.data.newValue) == "number" and event.data.newValue or tostring(event.data.newValue))

    payload.value = string.lower(value)

    local formattedPayload
    if (propertyName == "dead") then
        formattedPayload = tostring(payload.value)
    else
        formattedPayload = json.encode(payload)
    end

    --local simulation = (event.simulation == true)

    self.mqtt:publish(self:getPropertyTopic(device, propertyName), formattedPayload, {retain = true})
end

function MqttConventionHomeAssistant:onCommand(event)
    if (string.find(event.topic, self.rootTopic) == 1) then
        local topicElements = splitString(event.topic, "/")
        local deviceId = tonumber(topicElements[3])
        local propertyName = topicElements[5]

        local device = self.devices[deviceId]

        if (propertyName == "state") then
            device:setState(event.payload)
        elseif (propertyName == "value") then
            device:setValue(event.payload)
        end

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
function MqttConventionHomie:getPropertyTopic(device, propertyName)
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
        payload = "true"
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
        if (device.bridgeSubtype ~= PrototypeDevice.bridgeSubtype) then
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
    print("TBD")
end

function MqttConventionHomie:onPropertyUpdateEvent(device, event)
    local propertyName = event.data.property

    local value = (type(event.data.newValue) == "number" and event.data.newValue or tostring(event.data.newValue))

    value = string.lower(value)

    self.mqtt:publish(self:getDeviceTopic(device) .. "node/" .. propertyName, value, {retain = true})
end

function MqttConventionHomie:onCommand(event)
    print("[MqttConventionHomie:onCommand]" )
    print(event.topic)
    print(event.payload)
    if (string.find(event.topic, self.rootTopic) == 1) then
        local topicElements = splitString(event.topic, "/")
        local deviceId = tonumber(topicElements[2])
        local propertyName = topicElements[4]

        local device = self.devices[deviceId]

        if (propertyName == "state") then
            device:setState(event.payload)
        elseif (propertyName == "value") then
            device:setValue(event.payload)
        end

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
function MqttConventionDebug:onPropertyUpdateEvent(device, event)
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
