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
    icon = "&#128230;", -- 📦
    properties = { },
    customPropertySetters = nil -- could be optionally set by a child class
} 

function PrototypeEntity.isSupported(fibaroDevice)
    print("'isSupported' function is mandatory for implementation")
end

-- *** MERGE "INIT" WITH "NEW"?
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

-- *** rename setProperty to process HA event
function PrototypeEntity:setProperty(propertyName, params)
    -- check if there is a custom property setter

    -- DEFAULT PROPERTY SETTER
    if propertyName == "state" then
        local value = params[1]

        if (value == "true") then
            print("Turn ON for device #" .. self.id)
            fibaro.call(self.id, "turnOn")
        elseif (value == "false") then
            print("Turn OFF for device #" .. self.id)
            fibaro.call(self.id, "turnOff")
        else
            print("Unexpected value: " .. json.encode(event))
        end
    elseif propertyName == "action" then
        print("FUNCTION CALL: \"" .. params[1] .. "\", with NO PARAMS for device #" .. self.id)
        fibaro.call(self.id, params[1])
    else
        local firstPart = string.upper(string.sub(propertyName, 1, 1))
        local secondPart = string.sub(propertyName, 2, string.len(propertyName))
        local functionName = "set" .. firstPart .. secondPart

        print("FUNCTION CALL: \"" .. functionName .. "\", with PARAMS \"" .. json.encode(params) .. "\" for device #" .. self.id)

        fibaro.call(self.id, functionName, unpack(params))
    end
end

function PrototypeEntity:fibaroDeviceTypeContains(type)
    return fibaroDeviceTypeContains(self.sourceDeviceNode.fibaroDevice, type)
end
function PrototypeEntity:fibaroDeviceTypeMatchesWith(type)
    return fibaroDeviceTypeMatchesWith(self.sourceDeviceNode.fibaroDevice, type)
end
function PrototypeEntity:fibaroDeviceHasInterface(interface)
    return fibaroDeviceHasInterface(self.sourceDeviceNode.fibaroDevice, interface)
end
function PrototypeEntity:fibaroDeviceHasAction(action)
    return fibaroDeviceHasAction(self.sourceDeviceNode.fibaroDevice, action)
end
function PrototypeEntity:fibaroDeviceHasProperty(property)
    return fibaroDeviceHasProperty(self.sourceDeviceNode.fibaroDevice, property)
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
    if (fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.binarySwitch") or fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.soundSwitch")) and (not fibaroDeviceHasInterface(fibaroDevice, "light")) then
        return true
    else 
        return false
    end
end

function Switch:init(fibaroDevice)
    if self:fibaroDeviceTypeMatchesWith("com.fibaro.soundSwitch") then
        self.icon = "&#128264;" -- 🔈
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
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.binarySwitch") and fibaroDeviceHasInterface(fibaroDevice, "light") then
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
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.multilevelSwitch") and fibaroDeviceHasInterface(fibaroDevice, "light") then
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
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.colorController") and fibaroDeviceHasInterface(fibaroDevice, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- GENERIC SENSOR
-----------------------------------
GenericSensor = inheritFrom(PrototypeEntity)
GenericSensor.supportsRead = true 
GenericSensor.supportsWrite = false
GenericSensor.icon = "&#128065;&#65039;" -- 👁️

function GenericSensor.isGenericSensor(fibaroDevice)
    if fibaroDeviceTypeContains(fibaroDevice, "Sensor") or fibaroDeviceTypeContains(fibaroDevice, "sensor") or fibaroDeviceTypeContains(fibaroDevice, "Detector") or fibaroDeviceTypeContains(fibaroDevice, "detector") or fibaroDeviceTypeContains(fibaroDevice, "Meter") or fibaroDeviceTypeContains(fibaroDevice, "meter") then
        return true
    else
        return false
    end
end


-----------------------------------
-- BINARY SENSOR (DOOR, MOTION, WATER LEAK, FIRE, SMORE SENSORSMULTILEVEL FOR TEMPERATURE, ETC)
-----------------------------------
BinarySensor = inheritFrom(GenericSensor)
BinarySensor.type = "binary_sensor"
BinarySensor.supportsBinary = true
BinarySensor.supportsMultilevel = false

function BinarySensor.isSupported(fibaroDevice)
    if GenericSensor.isGenericSensor(fibaroDevice) and (not fibaroDevice.properties.unit) then
        return true
    else
        return false
    end
end

function BinarySensor:init(fibaroDevice)
    -- ToDo *** refactor with mappings for a bit higher performance?
    if self:fibaroDeviceTypeMatchesWith("com.fibaro.motionSensor") then
        self.subtype = "motion"
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.floodSensor") then
        self.subtype = "moisture" 
        self.icon = "&#128166;" -- 💦
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.doorWindowSensor") then
        if self:fibaroDeviceTypeMatchesWith("com.fibaro.doorSensor") then
            self.subtype = "door"
            self.icon = "&#128682;" -- 🚪
        elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.windowSensor") then
            self.subtype = "window"
            self.icon = "&#129003;" -- 🟫
            --self.icon = "&#129695;" -- 🪟
        else
            print("[BinarySensor.init] Uknown doow/window sensor " .. self.id .. " " .. self.name)
        end
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.fireDetector") or self:fibaroDeviceTypeMatchesWith("com.fibaro.fireSensor") then
        self.subtype = "heat"
        self.icon = "&#128293;" -- 🔥
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.coDetector") then
        self.subtype = "carbon_monoxide"
        self.icon = "&#128168;" -- 💨
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.smokeSensor") then
        self.subtype = "smoke"
        self.icon = "&#128684;" -- 🚬
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.gasDetector") then
        self.subtype = "gas" 
        self.icon = "&#128168;" -- 💨
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.lifeDangerSensor") then
        self.subtype = "safety"
    else
        -- use generic sensor 

        -- DEBUG: print("[BinarySensor.init] No sensor specialization for #" .. tostring(self.id) .. " \"" .. tostring(self.name) .. "\" that has type " .. fibaroDevice.baseType .. "-" .. fibaroDevice.type .. ", thus using default sensor class")
    end
end

----------------------------------------------------------
-- MULTILEVEL SENSOR (TEMPERATURE, HUMIDITY, VOLTAGE, ETC) 
----------------------------------------------------------
MultilevelSensor = inheritFrom(GenericSensor)
MultilevelSensor.type = "sensor"
MultilevelSensor.supportsBinary = false
MultilevelSensor.supportsMultilevel = true
MultilevelSensor.bridgeUnitOfMeasurement = "'unit of measurement' needs to be initialized"

function MultilevelSensor.isSupported(fibaroDevice)
    if GenericSensor.isGenericSensor(fibaroDevice) and fibaroDevice.properties.unit then
        return true
    else
        return false
    end
end

function MultilevelSensor:init(fibaroDevice)
    self.bridgeUnitOfMeasurement = fibaroDevice.properties.unit

    -- identify subtype 
    -- ToDo *** refactor with mappings for a bit higher performance?
    if self:fibaroDeviceTypeMatchesWith("com.fibaro.temperatureSensor") then
        self.subtype = "temperature"
        self.bridgeUnitOfMeasurement = "°" .. fibaroDevice.properties.unit
        self.icon = "&#127777;&#65039;" -- 🌡️
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.lightSensor") then
        self.subtype = "illuminance"
        self.icon = "&#9728;&#65039;" -- ☀️
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.humiditySensor") then 
        self.subtype = "humidity"
        self.icon = "&#128167;" -- 💧
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.batteryLevelSensor") then 
        self.subtype = "battery"
        self.icon = "&#128267;" -- 🔋
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.energySensor") or self:fibaroDeviceTypeMatchesWith("com.fibaro.energyMeter") or self:fibaroDeviceTypeMatchesWith("com.fibaro.electricMeter") then 
        self.subtype = "energy"
        self.icon = "&#9889;" -- ⚡
    elseif self:fibaroDeviceTypeMatchesWith("com.fibaro.powerMeter") then 
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
        -- use generic sensor 

        -- DEBUG: print("[MultilevelSensor.init] No sensor specialization for #" .. tostring(self.id) .. " \"" .. tostring(self.name) .. "\" that has type " .. fibaroDevice.baseType .. "-" .. fibaroDevice.type .. " and measured in '" .. tostring(fibaroDevice.properties.unit) .. "' unit, thus using default sensor class")
    end
end

-----------------------------------
-- MULTILEVEL SWITCH (COVER)
-----------------------------------
Cover = inheritFrom(PrototypeEntity)
Cover.type = "cover"
Cover.supportsBinary = true
Cover.supportsMultilevel = false
Cover.supportsRead = true
Cover.supportsWrite = true

Cover.supportsTilt = false
Cover.supportsTiltMultilevel = false

function Cover.isSupported(fibaroDevice)
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.baseShutter") or fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.remoteBaseShutter") or fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.rollerShutter") then
        return true
    else 
        return false
    end
end

function Cover:init(fibaroDevice) 
    -- CHECK of 0..100 positioning is supported in addition to open/close/stop actions
    if self:fibaroDeviceHasAction("setValue") or self:fibaroDeviceHasProperty("value") then
        self.supportsMultilevel = true
    end

    -- CHECK FOR TILT SUPPORT
    if self:fibaroDeviceHasAction("setValue2") or self:fibaroDeviceHasProperty("value2") or fibaroDevice.id == 499 then
        self.supportsTilt = true
        self.supportsTiltMultilevel = true
    elseif self:fibaroDeviceHasAction("rotateSlatsUp") or self:fibaroDeviceHasAction("rotateSlatsDown") or self:fibaroDeviceHasAction("stopSlats") then
        self.supportsTilt = true
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
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.hvacSystem") then 
        return true 
    else 
        return false
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
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.remoteController") or fibaroDeviceTypeMatchesWith(fibaroDevice, "com.fibaro.remoteSceneController") then
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
--RemoteControllerKey.icon = "&#128377;&#65039;" -- 🕹️

function RemoteControllerKey.isSupported(fibaroDevice)
    if fibaroDeviceTypeMatchesWith(fibaroDevice, "com.alexander_vitishchenko.remoteKey") then
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
    -- Switches
    Switch, -- binary
    Cover, -- multilevel

    -- Lights
    Dimmer, -- multilevel light; Dimmer detection has a priority over binary light
    Light, -- binary
    Rgbw, -- multichannel

    -- Sensors
    BinarySensor,
    MultilevelSensor,
   
    Thermostat,

    RemoteController,
    RemoteControllerKey
}  