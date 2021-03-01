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
}

function PrototypeDevice:new(fibaroDevice)
    -- clone self, and copy fibaroDevice
    local status, device = pcall(clone, self)
    shallowCopyTo(fibaroDevice, device)

    device.fibaroDevice = fibaroDevice
    
    device.roomName = fibaro.getRoomNameByDeviceID(device.id)

    self:init(device)

    return device
end

function PrototypeDevice:init(device)
    -- to be overriden by subclasses when need to set up "bridgeSubtype" property
end

function PrototypeDevice:setState(state)
    if self.bridgeBinary and self.bridgeWrite then
        --fibaro.call(self.id, "setState", state)
        
        if (state == "true") then
            print("Turn ON for " .. self.id)
            fibaro.call(self.id, "turnOn")
        elseif (state == "false") then
            print("Turn OFF for " .. self.id)
            fibaro.call(self.id, "turnOff")
        else
            print("Unexpected value: " .. json.encode(event))
        end
        
    else
        print("WARNING: trying to turn ON undesignated devices")
    end
end

function PrototypeDevice:setValue(value)
    if self.bridgeMultilevel and self.bridgeWrite then
        fibaro.call(self.id, "setValue", value)
    else
        print("WARNING: trying to turn ON undesignated devices")
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
    if (fibaroDevice.type == "com.fibaro.binarySwitch") and not table_contains_value(fibaroDevice.interfaces, "light") then
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
    if (fibaroDevice.type == "com.fibaro.binarySwitch") and table_contains_value(fibaroDevice.interfaces, "light")      then
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
        device.bridgeSubtype = nil
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
    if (device.type == "com.fibaro.temperatureSensor") then
        device.bridgeSubtype = "temperature"
        device.bridgeUnitOfMeasurement = "°" .. device.properties.unit
    elseif (device.type == "com.fibaro.lightSensor") then
        device.bridgeSubtype = "illuminance"
    elseif (device.properties.unit == "V") then
        device.bridgeSubtype = "voltage"
    elseif (device.properties.unit == "A") then
        device.bridgeSubtype = "current"
    elseif (device.properties.unit == "W" or device.properties.unit == "kW" or device.properties.unit == "kVA") then
        device.bridgeSubtype = "power"
    else
        print("[MultilevelSensor.init] Unknown multilevel sensor " .. tostring(device.id) .. " " .. tostring(device.name))
        device.bridgeSubtype = nil
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

function Cover:setState(state)
    print("[Cover:setState] setState " .. state)
    if (state == "open") then
        self:setValue(99)
    elseif (state == "close") then
        self:setValue(0)
    elseif (state == "stop") then
        fibaro.call(self.id, "stop")
    else
        print("Unsupported state")
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
    MultilevelSensor
}  

function identifyDevice(fibaroDevice)
    for i, j in ipairs(deviceTypeMappings) do
        if (j.isSupported(fibaroDevice)) then
            return j:new(fibaroDevice)
        end
    end

    return nil
end

-----------------------------------
-- HELPER FUNCTIONS - FIX "WRONG" DEVICE TYPES FROM FIBARO DEVICE API
-----------------------------------

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

function getFibaroDeviceById(id)
    local fibaroDevice = api.get("/devices/" .. id)

    local overrideType = fibaroTypeOverride[fibaroDevice.type]
    if overrideType then 
        fibaroDevice.type = overrideType
    end

    local overrideBaseType = fibaroBaseTypeOverride[fibaroDevice.baseType]
    if overrideBaseType then 
        fibaroDevice.baseType = overrideBaseType
    end

    return fibaroDevice
end

-- TODO: com.fibaro.seismometer
-- TODO: com.fibaro.accelerometer

-- motion eye => seismometer
--  "type": "com.fibaro.seismometer",
--  "baseType": "com.fibaro.multilevelSensor",

-- motion eye => accelerometer
--  "type": "com.fibaro.accelerometer",
--  "baseType": "com.fibaro.sensor",

-- tamper for flood sensor and other Fibaro sensors
-- "type": "com.fibaro.motionSensor",
-- "baseType": "com.fibaro.securitySensor",