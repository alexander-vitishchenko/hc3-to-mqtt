----------------------------------- 
-- PROTOTYPE OBJECT 
-----------------------------------
PrototypeEntity = {
    -- mandatory
    type = "'type' needs to be initialized",
    supportsBinary = "'supportsBinary' needs to be initialized",
    binaryProperty = "value",
    supportsMultilevel = "'supportsMultilevel' needs to be initialized",
    supportsRead = "'supportsRead' needs to be initialized",
    supportsWrite = "'supportsWrite' needs to be initialized",

    -- optional
    subtype = "default",
    modes = "'modes' needs to be initialized to an array of modes, e.g. 'heat', 'cool'",
    icon = "&#128230;",
    properties = { },
    customPropertySetters = nil -- could be optionally set by a child class
} 

function PrototypeEntity.isSupported(fibaroDevice)
    print("'isSupported' function is mandatory for implementation")
end

-- *** MERGE "INIT" WITH "NEW"
function PrototypeEntity:new(deviceNode)
    local status, haEntity = pcall(clone, self)

    local fibaroDevice = deviceNode.fibaroDevice
    haEntity.sourceDeviceNode = deviceNode

    haEntity.id = fibaroDevice.id
    haEntity.name = fibaroDevice.name
    haEntity.roomName = fibaroDevice.roomName

    local linkedFibaroDevice = fibaroDevice.linkedDevice
    if linkedFibaroDevice then
        haEntity.linkedEntity = deviceNodeById[linkedFibaroDevice.id].identifiedHaEntity
        haEntity.linkedProperty = fibaroDevice.linkedProperty
    end

    haEntity:init(fibaroDevice)

    return haEntity
end

function PrototypeEntity:init(fibaroDevice)
    -- "init" function could be optionally overriden by subclasses implementation
end 

function PrototypeEntity:setProperty(propertyName, value)
    if isEmptyString(value) then
        return
    end

    local customPropertySetter
    if (self.customPropertySetters ~= nil) then
        customPropertySetter = self.customPropertySetters[propertyName]
    end

    if (customPropertySetter == nil) then
        -- DEFAULT PROPERTY SETTER
        if (propertyName == "state") then
            if (value == "true") then
                --print("Turn ON for device #" .. self.id)
                fibaro.call(self.id, "turnOn")
            elseif (value == "false") then
                --print("Turn OFF for device #" .. self.id)
                fibaro.call(self.id, "turnOff")
            else
                print("Unexpected value: " .. json.encode(event))
            end
        else
            -- *** rename to firstCharacter
            local firstPart = string.upper(string.sub(propertyName, 1, 1))
            local secondPart = string.sub(propertyName, 2, string.len(propertyName))

            local functionName = "set" .. firstPart .. secondPart
            print("FUNCTION CALL: \"" .. functionName .. "\", with VALUE \"" .. value .. "\" for device #" .. self.id)

            if (propertyName == "color") then
                local newRgbw = splitStringToNumbers(value, ",")
                fibaro.call(self.id, functionName, newRgbw[1], newRgbw[2], newRgbw[3], newRgbw[4])
            else
                fibaro.call(self.id, functionName, value)
            end
        end
    else
        -- CUSTOM PROPERTY SETTER
        print("[CUSTOM PROPERTY] SET \"" .. propertyName .. "\" to \"" .. value .. "\" for device #" .. self.id)
        customPropertySetter(propertyName, value)
    end
end

function PrototypeEntity:fibaroDeviceHasType(type)
    return fibaroDeviceHasType(self.sourceDeviceNode.fibaroDevice, type)
end

function PrototypeEntity:fibaroDeviceHasNoType(type)
    return not fibaroDeviceHasType(self.sourceDeviceNode.fibaroDevice, type)
end

function PrototypeEntity:fibaroDeviceHasInterface(interface)
    return table_contains_value(self.sourceDeviceNode.fibaroDevice, interface)
end

function PrototypeEntity:fibaroDeviceHasNoInterface(interface)
    return not fibaroDeviceHasInterface(self.sourceDeviceNode.fibaroDevice, interface)
end

-----------------------------------
-- BINARY SWITCH
-----------------------------------
Switch = inheritFrom(PrototypeEntity)
Switch.type = "switch"
Switch.subtype = "binary"
Switch.supportsBinary = true
Switch.supportsMultilevel = false
Switch.supportsRead = true
Switch.supportsWrite = true
Switch.icon = "&#128268;" -- 🔌

function Switch.isSupported(fibaroDevice)
    if fibaroDeviceHasType(fibaroDevice, "com.fibaro.binarySwitch") and fibaroDeviceHasNoInterface(fibaroDevice, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- BINARY LIGHT
-----------------------------------
Light = inheritFrom(PrototypeEntity)
Light.type = "light"
Light.subtype = "binary"
Light.supportsBinary = true
Light.supportsMultilevel = false
Light.supportsRead = true
Light.supportsWrite = true
Light.icon = "&#128161;" -- 💡

function Light.isSupported(fibaroDevice)
    if fibaroDeviceHasType(fibaroDevice, "com.fibaro.binarySwitch") and fibaroDeviceHasInterface(fibaroDevice, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- MULTILEVEL LIGHT (DIMMERS)
-----------------------------------
Dimmer = inheritFrom(PrototypeEntity)
Dimmer.type = "light"
Dimmer.subtype = "dimmer"
Dimmer.supportsBinary = true
Dimmer.supportsMultilevel = true
Dimmer.supportsRead = true
Dimmer.supportsWrite = true
Dimmer.icon = "&#128161;"

function Dimmer.isSupported(fibaroDevice)
    if fibaroDeviceHasType(fibaroDevice, "com.fibaro.multilevelSwitch") and fibaroDeviceHasInterface(fibaroDevice, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- MULTILEVEL LIGHT (RGBW)
-----------------------------------
Rgbw = inheritFrom(PrototypeEntity)
Rgbw.type = "light"
Rgbw.subtype = "rgbw" 
Rgbw.supportsBinary = true
Rgbw.supportsMultilevel = true
Rgbw.supportsRead = true
Rgbw.supportsWrite = true
Rgbw.icon = "&#127752;" -- 🌈

function Rgbw.isSupported(fibaroDevice)
    if fibaroDeviceHasType(fibaroDevice, "com.fibaro.colorController") and fibaroDeviceHasInterface(fibaroDevice, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- BINARY SENSOR (DOOR, MOTION, WATER LEAK, FIRE, SMORE SENSORSMULTILEVEL FOR TEMPERATURE, ETC)
-----------------------------------
BinarySensor = inheritFrom(PrototypeEntity)
BinarySensor.type = "binary_sensor"
BinarySensor.supportsBinary = true
BinarySensor.supportsMultilevel = false
BinarySensor.supportsRead = true 
BinarySensor.supportsWrite = false
BinarySensor.icon = "&#128065;&#65039;" -- 👁️

function BinarySensor.isSupported(fibaroDevice)
    if (string.find(fibaroDevice.baseType, "Sensor") or string.find(fibaroDevice.baseType, "sensor") or string.find(fibaroDevice.baseType, "Detector") or string.find(fibaroDevice.baseType, "detector")) then
        --if (fibaroDevice.baseType ~= "com.fibaro.multilevelSensor") and (fibaroDevice.type ~= "com.fibaro.multilevelSensor") then
        if fibaroDeviceHasNoType(fibaroDevice, "com.fibaro.multilevelSensor") then
            return true 
        end
    end

    return false
end

function BinarySensor:init(fibaroDevice)
    -- ToDo: refactor with mappings
    if self:fibaroDeviceHasType("com.fibaro.motionSensor") then
        self.subtype = "motion"
    elseif self:fibaroDeviceHasType("com.fibaro.floodSensor") then
        self.subtype = "moisture" 
        self.icon = "&#128166;" -- 💦
    elseif self:fibaroDeviceHasType("com.fibaro.doorWindowSensor") then
        if self:fibaroDeviceHasType("com.fibaro.doorSensor") then
            self.subtype = "door"
            self.icon = "&#128682;" -- 🚪
        elseif self:fibaroDeviceHasType("com.fibaro.windowSensor") then
            self.subtype = "window"
            self.icon = "&#129003;" -- 🟫
        else
            print("[BinarySensor.init] Uknown doow/window sensor " .. self.id .. " " .. self.name)
        end
    elseif self:fibaroDeviceHasType("com.fibaro.fireDetector") or self:fibaroDeviceHasType("com.fibaro.fireSensor") then
        self.subtype = "heat"
        self.icon = "&#128293;" -- 🔥
    elseif self:fibaroDeviceHasType("com.fibaro.coDetector") then
        self.subtype = "carbon_monoxide"
        self.icon = "&#128168;" -- 💨
    elseif self:fibaroDeviceHasType("com.fibaro.smokeSensor") then
        self.subtype = "smoke"
        self.icon = "&#128684;" -- 🚬
    elseif self:fibaroDeviceHasType("com.fibaro.gasDetector") then
        self.subtype = "gas" 
        self.icon = "&#128168;" -- 💨
    elseif self:fibaroDeviceHasType("com.fibaro.lifeDangerSensor") then
        self.subtype = "safety"
    else
        self.subtype = nil
        --print("[BinarySensor.init] No sensor specialization for #" .. tostring(self.id) .. " \"" .. tostring(self.name) .. "\" that has type " .. fibaroDevice.baseType .. "-" .. fibaroDevice.type .. ", thus using default sensor class")
    end
end

-----------------------------------
-- MULTILEVEL SENSOR (TEMPERATURE, HUMIDITY, VOLTAGE, ETC) 
-----------------------------------
MultilevelSensor = inheritFrom(PrototypeEntity)
MultilevelSensor.type = "sensor"
MultilevelSensor.supportsBinary = false
MultilevelSensor.supportsMultilevel = true
MultilevelSensor.bridgeUnitOfMeasurement = "'unit of measurement' needs to be initialized"
MultilevelSensor.supportsRead = true
MultilevelSensor.supportsWrite = false
MultilevelSensor.icon = "&#128065;&#65039;" -- 👁️

function MultilevelSensor.isSupported(fibaroDevice)
    if fibaroDevice.baseType == "com.fibaro.electricMeter" then
        return true
    end

    if (string.find(fibaroDevice.baseType, "Sensor") or string.find(fibaroDevice.baseType, "sensor") or string.find(fibaroDevice.baseType, "Detector") or string.find(fibaroDevice.baseType, "detector")) then
        if fibaroDeviceHasType(fibaroDevice, "com.fibaro.multilevelSensor") then
            return true 
        end
    end

    return false
end

function MultilevelSensor:init(fibaroDevice)
    -- initialize unit of measurement
    self.bridgeUnitOfMeasurement = fibaroDevice.properties.unit

    -- initialize subtype 
    -- ToDo *** refactor with mappings?
    if self:fibaroDeviceHasType("com.fibaro.temperatureSensor") then
        self.subtype = "temperature"
        self.bridgeUnitOfMeasurement = "°" .. fibaroDevice.properties.unit
        self.icon = "&#127777;&#65039;" -- 🌡️
    elseif self:fibaroDeviceHasType("com.fibaro.lightSensor") then
        self.subtype = "illuminance"
        self.icon = "&#9728;&#65039;" -- ☀️
    elseif self:fibaroDeviceHasType("com.fibaro.humiditySensor") then 
        self.subtype = "humidity"
        self.icon = "&#128167;" -- 💧
    elseif self:fibaroDeviceHasType("com.fibaro.batteryLevelSensor") then 
        self.subtype = "battery"
        self.icon = "&#128267;" -- 🔋
    elseif self:fibaroDeviceHasType("com.fibaro.energySensor")then 
        self.subtype = "energy"
        self.icon = "&#9889;" -- ⚡
    elseif self:fibaroDeviceHasType("com.fibaro.powerMeter") then 
        self.subtype = "power"
        self.icon = "&#9889;" -- ⚡
    elseif (fibaroDevice.properties.unit == "V") then
        self.subtype = "voltage"
        self.icon = "&#9889;" -- ⚡
    elseif (fibaroDevice.properties.unit == "A") then
        self.subtype = "current"
        self.icon = "&#9889;" -- ⚡
    elseif (fibaroDevice.properties.unit == "W" or fibaroDevice.properties.unit == "kW" or fibaroDevice.properties.unit == "kVA") then
        self.subtype = "power"
        self.icon = "&#9889;" -- ⚡
    elseif (fibaroDevice.properties.unit == "Hz") then
        self.subtype = "frequency"
        self.icon = "&#8767;" -- ∿
    else
        --print("[MultilevelSensor.init] No sensor specialization for #" .. tostring(self.id) .. " \"" .. tostring(self.name) .. "\" that has type " .. fibaroDevice.baseType .. "-" .. fibaroDevice.type .. " and measured in '" .. tostring(fibaroDevice.properties.unit) .. "' unit, thus using default sensor class")
    end
end

-----------------------------------
-- MULTILEVEL SWITCH (COVER)
-----------------------------------
Cover = inheritFrom(PrototypeEntity)
Cover.type = "cover"
Cover.supportsBinary = true
Cover.supportsMultilevel = true
Cover.supportsRead = true
Cover.supportsWrite = true

function Cover.isSupported(fibaroDevice)
    if (fibaroDevice.baseType == "com.fibaro.baseShutter") then
        return true
    else 
        return false
    end
end

function Cover:init(fibaroDevice) 
    self.customPropertySetters = { }
    self.customPropertySetters["state"] = function (propertyName, value) 
        if (value == "open") then
            fibaro.call(self.id, "setValue", 100)
        elseif (value == "close") then
            fibaro.call(self.id, "setValue", 0)
        elseif (value == "stop") then
            fibaro.call(self.id, "stop")
        else
            print("Unsupported command")
        end
    end
end

-----------------------------------
-- THERMOSTAT (MULTILEVEL SWITCH)
-----------------------------------
Thermostat = inheritFrom(PrototypeEntity)
Thermostat.type = "climate"
Thermostat.supportsBinary = false
Thermostat.supportsMultilevel = true
Thermostat.supportsRead = true
Thermostat.supportsWrite = true 
Thermostat.icon = "&#127965;&#65039;" -- 🏝️

function Thermostat.isSupported(fibaroDevice)
    if fibaroDevice.baseType == "com.fibaro.hvacSystem" or fibaroDevice.type == "com.fibaro.hvacSystem" then 
        return true 
    else 
        return false
    end
end

function Thermostat:init(fibaroDevice) 
    local fibaroDeviceProperties = self.sourceDeviceNode.fibaroDevice.properties
    
    self.properties.supportedThermostatModes = { }
    for i, mode in ipairs(fibaroDeviceProperties.supportedThermostatModes) do
        self.properties.supportedThermostatModes[i] = string.lower(mode)
    end
end

function Thermostat:setMode(mode)
    fibaro.call(self.id, "setThermostatMode", mode)
end

function Thermostat:setHeatingThermostatSetpoint(targetTemperature)
    fibaro.call(self.id, "setHeatingThermostatSetpoint", targetTemperature)
end

function Thermostat:getTemperatureSensor()
    local sourceDeviceNode = self.sourceDeviceNode
    local parentNode = sourceDeviceNode.parentNode

    local relatedNodeList = {}
    if (parentNode) then
        shallowInsertTo(parentNode.childNodeList, relatedNodeList)    
    end
    shallowInsertTo(sourceDeviceNode.childNodeList, relatedNodeList)

    for _, siblingNode in ipairs(relatedNodeList) do
        if (siblingNode.included and siblingNode.identifiedHaEntity and siblingNode.identifiedHaEntity.type == "sensor" and siblingNode.identifiedHaEntity.subtype == "temperature") then
            return siblingNode.identifiedHaEntity
        end
    end

    return nil
end

-----------------------------------
-- REMOTE CONTROLLER
-----------------------------------
RemoteController = inheritFrom(MultilevelSensor)
RemoteController.subtype = "remoteController"

function RemoteController.isSupported(fibaroDevice)
    if ((fibaroDevice.baseType == "com.fibaro.remoteController") or ( fibaroDevice.baseType == "com.fibaro.remoteSceneController") or ( fibaroDevice.type == "com.fibaro.remoteController") or (fibaroDevice.type == "com.fibaro.remoteSceneController"))      then
        return true
    else 
        return false
    end
end

------------------------------------
-- REMOTE CONTROLLER - BUTTON ACTION
------------------------------------
RemoteControllerKey = inheritFrom(PrototypeEntity)
RemoteControllerKey.type = "device_automation"
RemoteControllerKey.subtype = "trigger"
RemoteControllerKey.supportsBinary = true
RemoteControllerKey.supportsMultilevel = false
RemoteControllerKey.supportsRead = true
RemoteControllerKey.supportsWrite = false
RemoteControllerKey.icon = "&#9654;&#65039;" -- ▶️

function RemoteControllerKey.isSupported(fibaroDevice)
    if (fibaroDevice.baseType == "com.alexander_vitishchenko.remoteKey") then
        return true
    else 
        return false
    end
end

function RemoteControllerKey.init(fibaroDevice)
    -- not needed for now
end

----------------------------------- 
-- SUPPORTED DEVICE MAPPINGS
-----------------------------------
haEntityTypeMappings = {
    Switch, -- binary switch
    Cover, -- multilevel switch
    Light, -- binary light
    Dimmer, -- multilevel light 
    Rgbw, -- multichannel and multilevel light
    BinarySensor,
    MultilevelSensor,
    Thermostat,
    RemoteController,
    RemoteControllerKey
}  