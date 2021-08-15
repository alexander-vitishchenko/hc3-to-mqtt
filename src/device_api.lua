----------------------------------- 
-- PROTOTYPE OBJECT 
-----------------------------------

PrototypeDevice = {
    bridgeType = "'bridgeType' needs to be set",
    bridgeSubtype = "'bridgeSubtype' needs to be set",
    bridgeBinary = "'bridgeBinary' needs to be set",
    bridgeBinaryProperty = "value",
    bridgeMultilevel = "'bridgeMultilevel' needs to be set",
    bridgeRead = "'bridgeRead' needs to be set",
    bridgeWrite = "'bridgeWrite' needs to be set",
    bridgeModes = "'bridgeWrite' needs to be set to an array of modes, e.g. 'heat', 'cool'",
    customPropertySetters = nil -- could be optionally set by child class
}

function PrototypeDevice:new(fibaroDevice)
    -- clone self, and copy fibaroDevice
    local status, device = pcall(clone, self)
    shallowCopyTo(fibaroDevice, device)

    device.fibaroDevice = fibaroDevice
    
    device.roomName = tostring(fibaro.getRoomNameByDeviceID(device.id))

    self:init(device)

    return device
end

function PrototypeDevice:init(device)
    -- needs to be overriden by subclasses if need to initialize custom parameters
end 

function PrototypeDevice:setProperty(propertyName, value)
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
                print("Turn ON for device #" .. self.id)
                fibaro.call(self.id, "turnOn")
            elseif (value == "false") then
                print("Turn OFF for device #" .. self.id)
                fibaro.call(self.id, "turnOff")
            else
                print("Unexpected value: " .. json.encode(event))
            end

        else
            local firstPart = string.upper(string.sub(propertyName, 1, 1))
            local secondPart = string.sub(propertyName, 2, string.len(propertyName))

            local functionName = "set" .. firstPart .. secondPart
            print("CALL \"" .. functionName .. "\", with VALUE \"" .. value .. "\" for device #" .. self.id)
            fibaro.call(self.id, functionName, value)
        end
    else
        -- CUSTOM PROPERTY SETTER
        print("SET \"" .. propertyName .. "\" to \"" .. value .. "\" for device #" .. self.id)
        customPropertySetter(propertyName, value)
    end
end

function PrototypeDevice.isSupported(fibaroDevice)
    print("'isSupported' function is mandatory for implementation")
end

-----------------------------------
-- BINARY SWITCH
-----------------------------------

Switch = inheritFrom(PrototypeDevice)
Switch.bridgeType = "switch"
Switch.bridgeBinary = true
Switch.bridgeMultilevel = false
Switch.bridgeRead = true
Switch.bridgeWrite = true

function Switch.isSupported(fibaroDevice)
    if ((fibaroDevice.baseType == "com.fibaro.binarySwitch") or (fibaroDevice.type == "com.fibaro.binarySwitch")) and not table_contains_value(fibaroDevice.interfaces, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- BINARY LIGHT
-----------------------------------

Light = inheritFrom(PrototypeDevice)
Light.bridgeType = "light"
Light.bridgeBinary = true
Light.bridgeMultilevel = false
Light.bridgeRead = true
Light.bridgeWrite = true

function Light.isSupported(fibaroDevice)
    if ((fibaroDevice.baseType == "com.fibaro.binarySwitch") or (fibaroDevice.type == "com.fibaro.binarySwitch")) and table_contains_value(fibaroDevice.interfaces, "light") then
        return true
    else 
        return false
    end
end

-----------------------------------
-- MULTILEVEL LIGHT (DIMMERS)
-----------------------------------

Dimmer = inheritFrom(PrototypeDevice)
Dimmer.bridgeType = "light"
Dimmer.bridgeBinary = true
Dimmer.bridgeMultilevel = true
Dimmer.bridgeRead = true
Dimmer.bridgeWrite = true

function Dimmer.isSupported(fibaroDevice)
    if (fibaroDevice.baseType == "com.fibaro.multilevelSwitch") and table_contains_value(fibaroDevice.interfaces, "light")      then
        return true
    else 
        return false
    end
end

-----------------------------------
-- BINARY SENSOR (DOOR, MOTION, WATER LEAK, FIRE, SMORE SENSORSMULTILEVEL FOR TEMPERATURE, ETC)
-----------------------------------

BinarySensor = inheritFrom(PrototypeDevice)
BinarySensor.bridgeType = "binary_sensor"
BinarySensor.bridgeBinary = true
BinarySensor.bridgeMultilevel = false
BinarySensor.bridgeRead = true 
BinarySensor.bridgeWrite = false

function BinarySensor.isSupported(fibaroDevice)
    if (string.find(fibaroDevice.baseType, "Sensor")) or (string.find(fibaroDevice.baseType, "sensor")) then
        if (fibaroDevice.baseType ~= "com.fibaro.multilevelSensor") and (fibaroDevice.type ~= "com.fibaro.multilevelSensor") then
            return true 
        end
    end

    return false
end

function BinarySensor:init(device)
    -- set unit of measurement
    device.bridgeUnitOfMeasurement = device.properties.unit

    -- ToDo: refactor with mappings
    if (device.type == "com.fibaro.motionSensor") or (device.baseType == "com.fibaro.motionSensor") then
        device.bridgeSubtype = "motion"
    elseif (device.baseType == "com.fibaro.floodSensor") then
        device.bridgeSubtype = "moisture" 
    elseif (device.baseType == "com.fibaro.doorWindowSensor") then
        if (device.type == "com.fibaro.doorSensor") then
            device.bridgeSubtype = "door"
        else
            print("[BinarySensor.init] Uknown doow/window sensor " .. device.id .. " " .. device.name)
        end
    elseif (device.baseType == "com.fibaro.lifeDangerSensor") then
        device.bridgeSubtype = "safety"
    elseif (device.baseType == "com.fibaro.smokeSensor") or (device.type == "com.fibaro.smokeSensor") then
        device.bridgeSubtype = "smoke"
    else
        print("[BinarySensor.init] Unknown binary sensor")
    end
end

-----------------------------------
-- MULTILEVEL SENSOR (TEMPERATURE, HUMIDITY, VOLTAGE, ETC) 
-----------------------------------

MultilevelSensor = inheritFrom(PrototypeDevice)
MultilevelSensor.bridgeType = "sensor"
MultilevelSensor.bridgeBinary = false
MultilevelSensor.bridgeMultilevel = true
MultilevelSensor.bridgeUnitOfMeasurement = "'unit of measurement' needs to be initialized"
MultilevelSensor.bridgeRead = true
MultilevelSensor.bridgeWrite = false

function MultilevelSensor.isSupported(fibaroDevice)
    if (string.find(fibaroDevice.baseType, "Sensor")) or (string.find(fibaroDevice.baseType, "sensor")) then
        if (fibaroDevice.baseType == "com.fibaro.multilevelSensor") or (fibaroDevice.type == "com.fibaro.multilevelSensor") then
            return true 
        end
    end

    return false
end

function MultilevelSensor:init(device)
    -- initialize unit of measurement
    device.bridgeUnitOfMeasurement = device.properties.unit

    -- initialize subtype
    -- ToDo: refactor with mappings
    if (device.type == "com.fibaro.temperatureSensor") then
        device.bridgeSubtype = "temperature"
        device.bridgeUnitOfMeasurement = "°" .. device.properties.unit
    elseif (device.type == "com.fibaro.lightSensor") then
        device.bridgeSubtype = "illuminance"
    elseif (device.type == "com.fibaro.humiditySensor") then 
        device.bridgeSubtype = "humidity"
    elseif (device.properties.unit == "V") then
        device.bridgeSubtype = "voltage"
    elseif (device.properties.unit == "A") then
        device.bridgeSubtype = "current"
    elseif (device.properties.unit == "W" or device.properties.unit == "kW" or device.properties.unit == "kVA") then
        device.bridgeSubtype = "power"
    elseif (device.properties.unit == "min(s)") then
        device.bridgeSubtype = "battery"
    else
        print("[MultilevelSensor.init] Unknown multilevel sensor " .. tostring(device.id) .. " " .. tostring(device.name) .. " " .. device.properties.unit)
    end
end

-----------------------------------
-- MULTILEVEL SWITCH (COVER)
-----------------------------------

Cover = inheritFrom(PrototypeDevice)
Cover.bridgeType = "cover"
Cover.bridgeBinary = true
Cover.bridgeMultilevel = true
Cover.bridgeRead = true
Cover.bridgeWrite = true

function Cover.isSupported(fibaroDevice)
    if (fibaroDevice.baseType == "com.fibaro.baseShutter") then
        return true
    else 
        return false
    end
end

function Cover:init(device) 
    device.customPropertySetters = { }
    device.customPropertySetters["state"] = function (propertyName, value) 
        if (value == "open") then
            fibaro.call(device.id, "setValue", 99)
        elseif (value == "close") then
            fibaro.call(device.id, "setValue", 0)
        elseif (value == "stop") then
            fibaro.call(device.id, "stop")
        else
            print("Unsupported state")
        end
    end
end

-----------------------------------
-- THERMOSTAT (MULTILEVEL SWITCH)
-----------------------------------

Thermostat = inheritFrom(PrototypeDevice)
Thermostat.bridgeType = "climate"
Thermostat.bridgeBinary = false
Thermostat.bridgeMultilevel = true
Thermostat.bridgeRead = true
Thermostat.bridgeWrite = true 

function Thermostat.isSupported(fibaroDevice)
    if (fibaroDevice.type == "com.fibaro.hvacSystem") then 
        return true 
    else 
        return false
    end
end

function Thermostat:init(device) 
    for i, mode in ipairs(device.properties.supportedThermostatModes) do
        device.properties.supportedThermostatModes[i] = string.lower(mode)
    end
end

function Thermostat:setMode(mode)
    fibaro.call(self.id, "setThermostatMode", mode)
end

function Thermostat:setHeatingThermostatSetpoint(targetTemperature)
    fibaro.call(self.id, "setHeatingThermostatSetpoint", targetTemperature)
end

function Thermostat:getTemperatureSensor(allDevices)
    local device = allDevices[self.id + 1]
    if (not Thermostat.isTemperatureSensor(device)) then
        -- *** no laughs, to be refactored :)
        device = allDevices[self.id + 2]
    end

    if (Thermostat.isTemperatureSensor(device)) then
        return device
    else
        return nil
    end
end

function Thermostat.isTemperatureSensor(device)
    if ((device ~= nil) and (MultilevelSensor.isSupported(device)) and (device.bridgeSubtype == "temperature")) then
        return true
    else
        return false
    end
end

-----------------------------------
-- HELPER FUNCTIONS - OVERRIDE "WRONG" DEVICE TYPES FROM FIBARO DEVICE API
-----------------------------------

local fibaroBaseTypeOverride = {
    ["com.fibaro.FGR"] = "com.fibaro.baseShutter",
    ["com.fibaro.FGMS001"] = "com.fibaro.motionSensor",
    ["com.fibaro.FGWP"] = "com.fibaro.binarySwitch"
}

local fibaroTypeOverride = { 
    ["com.fibaro.FGKF601"] = "com.fibaro.keyFob",
    ["com.fibaro.FGD212"] = "com.fibaro.dimmer",
    ["com.fibaro.FGMS001v2"] = "com.fibaro.motionSensor",
    ["com.fibaro.FGFS101"] = "com.fibaro.floodSensor",
    ["com.fibaro.FGWP102"] = "com.fibaro.binarySwitch"
}

function getFibaroDevicesByFilter(filter)
    local filterStr = ""

    local firstParameter = true
    for i, j in pairs(filter) do
        if (not firstParameter) then
            filterStr = filterStr .. "&"
        end
        filterStr = filterStr .. i .. "=" .. tostring(j)
        firstParameter = false
    end

    print("Device filter URI '" .. "/devices?" .. filterStr .. "'")

    local allDevices = api.get("/devices?" .. filterStr)

    for i, j in ipairs(allDevices) do
        overrideFibaroDeviceType(j)
    end

    return allDevices
end

function getFibaroDeviceById(id)
    local fibaroDevice = api.get("/devices/" .. id)

    return getFibaroDeviceByInfo(fibaroDevice)
end

function getFibaroDeviceByInfo(info)
    local fibaroDevice = info

    overrideFibaroDeviceType(fibaroDevice) 

    return fibaroDevice
end

function overrideFibaroDeviceType(fibaroDevice)
    if (not fibaroDevice) or (not fibaroDevice.type) then
        return
    end
    local overrideType = fibaroTypeOverride[fibaroDevice.type]
    if overrideType then 
        fibaroDevice.type = overrideType
    end
    
    local overrideBaseType = fibaroBaseTypeOverride[fibaroDevice.baseType]
    if overrideBaseType then 
        fibaroDevice.baseType = overrideBaseType
    end
end

-----------------------------------
-- HELPER FUNCTIONS - IDENTIFY DEVICE BRIDGE TYPE BY LOOKING AT FIBARO DEVICE TYPE
-----------------------------------

deviceTypeMappings = {
    Switch, -- binary switch
    Cover, -- multilevel switch
    Light, -- binary light
    Dimmer, -- multilevel light 
    BinarySensor,
    MultilevelSensor,
    Thermostat
}  

function identifyDevice(fibaroDevice)
    for i, j in ipairs(deviceTypeMappings) do
        if (j.isSupported(fibaroDevice)) then
            local device = j:new(fibaroDevice)
            if (device.parentId and device.parentId ~= 0) then
                device.bridgeParent = getFibaroDeviceById(device.parentId)
            end

            return device
        end
    end

    return nil
end
