----------------------------------- 
-- PROTOTYPE OBJECT 
-----------------------------------
PrototypeDevice = {
    bridgeType = "'bridgeType' needs to be set",
    bridgeSubtype = "default",
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
    
    if (not device.roomName) then
        device.roomName = tostring(fibaro.getRoomNameByDeviceID(device.id))
    end

    self:init(device)

    return device
end

function PrototypeDevice:init(device)
    -- "init" function could be optionally overriden by subclasses implementation
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
                --print("Turn ON for device #" .. self.id)
                fibaro.call(self.id, "turnOn")
            elseif (value == "false") then
                --print("Turn OFF for device #" .. self.id)
                fibaro.call(self.id, "turnOff")
            else
                print("Unexpected value: " .. json.encode(event))
            end
        else
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

function PrototypeDevice.isSupported(fibaroDevice)
    print("'isSupported' function is mandatory for implementation")
end

-----------------------------------
-- BINARY SWITCH
-----------------------------------
Switch = inheritFrom(PrototypeDevice)
Switch.bridgeType = "switch"
Switch.bridgeSubtype = "binary"
Switch.bridgeBinary = true
Switch.bridgeMultilevel = false
Switch.bridgeRead = true
Switch.bridgeWrite = true 

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
Light = inheritFrom(PrototypeDevice)
Light.bridgeType = "light"
Light.bridgeSubtype = "binary"
Light.bridgeBinary = true
Light.bridgeMultilevel = false
Light.bridgeRead = true
Light.bridgeWrite = true

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
Dimmer = inheritFrom(PrototypeDevice)
Dimmer.bridgeType = "light"
Dimmer.bridgeSubtype = "dimmer"
Dimmer.bridgeBinary = true
Dimmer.bridgeMultilevel = true
Dimmer.bridgeRead = true
Dimmer.bridgeWrite = true

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
Rgbw = inheritFrom(PrototypeDevice)
Rgbw.bridgeType = "light"
Rgbw.bridgeSubtype = "rgbw" 
Rgbw.bridgeBinary = true
Rgbw.bridgeMultilevel = true
Rgbw.bridgeRead = true
Rgbw.bridgeWrite = true

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
BinarySensor = inheritFrom(PrototypeDevice)
BinarySensor.bridgeType = "binary_sensor"
BinarySensor.bridgeBinary = true
BinarySensor.bridgeMultilevel = false
BinarySensor.bridgeRead = true 
BinarySensor.bridgeWrite = false

function BinarySensor.isSupported(fibaroDevice)
    if (string.find(fibaroDevice.baseType, "Sensor")) or (string.find(fibaroDevice.baseType, "sensor")) then
        --if (fibaroDevice.baseType ~= "com.fibaro.multilevelSensor") and (fibaroDevice.type ~= "com.fibaro.multilevelSensor") then
        if fibaroDeviceHasNoType(fibaroDevice, "com.fibaro.multilevelSensor") then
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
    -- ToDo *** refactor with mappings
    if (device.type == "com.fibaro.temperatureSensor") then
        device.bridgeSubtype = "temperature"
        device.bridgeUnitOfMeasurement = "°" .. device.properties.unit
    elseif (device.type == "com.fibaro.lightSensor") then
        device.bridgeSubtype = "illuminance"
    elseif (device.type == "com.fibaro.humiditySensor") then 
        device.bridgeSubtype = "humidity"
    elseif (device.type == "com.fibaro.energySensor") then 
        device.bridgeSubtype = "energy"
    elseif (device.type == "com.fibaro.powerSensor") then 
        device.bridgeSubtype = "power"
    elseif (device.type == "com.fibaro.batteryLevelSensor") then 
        device.bridgeSubtype = "battery"
    elseif (device.bridgeSubtype == RemoteController.bridgeSubtype) then 
        -- do nothing / the purpose for this logical condition is to make sure RemoteController doesn't fall into "Unknown multilevel sensor" category
    elseif (device.properties.unit == "V") then
        device.bridgeSubtype = "voltage"
    elseif (device.properties.unit == "A") then
        device.bridgeSubtype = "current"
    elseif (device.properties.unit == "W" or device.properties.unit == "kW" or device.properties.unit == "kVA") then
        device.bridgeSubtype = "power"
    else
        print("[MultilevelSensor.init] Using default sensor type, as couldn't identify specialisation for " .. tostring(device.id) .. " " .. tostring(device.name) .. " " .. tostring(device.properties.unit))
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
        -- *** no laughs, to be refactored with linked devices later :)
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
-- REMOTE CONTROLLER
-----------------------------------
RemoteController = inheritFrom(MultilevelSensor)
RemoteController.bridgeSubtype = "remoteController"

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
RemoteControllerKey = inheritFrom(PrototypeDevice)
RemoteControllerKey.bridgeType = "device_automation"
RemoteControllerKey.bridgeSubtype = "trigger"
RemoteControllerKey.bridgeBinary = true
RemoteControllerKey.bridgeMultilevel = false
RemoteControllerKey.bridgeRead = true
RemoteControllerKey.bridgeWrite = false

function RemoteControllerKey.isSupported(fibaroDevice)
    if (fibaroDevice.baseType == "com.alexander_vitishchenko.remoteKey") then
        return true
    else 
        return false
    end
end

function RemoteControllerKey.init(device)
    -- not needed for now
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

function getFibaroDevicesByFilter(customDeviceFilterJsonStr)
    -- EXAMPLE FILTERS FROM  https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => "fibaro:getDevicesId(filters)"
    --[[
            {
                "filter": "hasProperty",
                "value": ["configured", "dead", "model"]
            },

            {
                "filter": "interface",
                "value": ["zwave", "levelChange"]
            },

            {
                "filter": "parentId",
                "value": [664]
            },

            {
                "filter": "type",
                "value": ["com.fibaro.multilevelSwitch"]
            },

            {
                "filter": "roomID",
                "value": [2, 3]
            },

            {
                "filter": "baseType",
                "value": ["com.fibaro.binarySwitch"]
            },

            {
                "filter": "isTypeOf",
                "value": ["com.fibaro.binarySwitch"]
            },

            {
                "filter": "isPlugin",
                "value": [true]
            },

            {
                "filter": "propertyEquals",
                "value":
                    [
                        {
                            "propertyName": "configured",
                            "propertyValue": [true]
                        },
                        {
                            "propertyName": "dead",
                            "propertyValue": [false]
                        },
                        {
                            "propertyName": "deviceIcon",
                            "propertyValue": [15]
                        },
                        {
                            "propertyName": "deviceControlType",
                            "propertyValue": [15,20,25]
                        }
                    ]
            },

            {
                "filter": "deviceID",
                "value": [55,120,902]
            }
    ]]--
    
    local deviceFilterJson = 
        {
            filters = {
                {
                    filter = "enabled",
                    value = { true }
                },
                {
                    filter = "visible",
                    value = { true }
                }
            }, 
            attributes = {
                -- define the list of Fibaro device attributes we are interested in
                main = {
                    "id", "name", "roomID", "view", "type", "baseType", "enabled", "visible", "isPlugin", "parentId", "viewXml", "hasUIView", "configXml", "interfaces", "properties", "actions", "created", "modified", "sortOrder"
                }
            }
        }

    if (not isEmptyString(customDeviceFilterJsonStr)) then
        print("")
        print("(!) Apply custom device filter: " .. tostring(customDeviceFilterJsonStr))
        print("--> It will only work if the provided filter is JSON like: " .. "{\"filter\":\"baseType\", \"value\":[\"com.fibaro.actor\"]},   {\"filter\":\"deviceID\", \"value\":[41,42]},   { MORE FILTERS MAY GO HERE }")
        print("--> See the list of Fibaro API filter types at https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => \"fibaro:getDevicesId(filters)\"")
        print("")

        local customDeviceFilterJson = json.decode("{ filters: [ " .. customDeviceFilterJsonStr .. "] }") 

        shallowInsertTo(customDeviceFilterJson.filters, deviceFilterJson.filters)
    end

    local allDevices = api.post( 
        "/devices/filter", 
        deviceFilterJson
    )

    print("Filter: " .. json.encode(deviceFilterJson))

    print("Found devices " .. #allDevices)
    print("")

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

function fibaroDeviceHasType(fibaroDevice, type)
    return (fibaroDevice.baseType == type) or (fibaroDevice.type == type)
end

function fibaroDeviceHasNoType(fibaroDevice, type)
    return not fibaroDeviceHasType(fibaroDevice, type)
end

function fibaroDeviceHasInterface(fibaroDevice, interface)
    return table_contains_value(fibaroDevice.interfaces, interface)
end

function fibaroDeviceHasNoInterface(fibaroDevice, interface)
    return not fibaroDeviceHasInterface(fibaroDevice, interface)
end

-----------------------------------
-- HELPER FUNCTIONS - IDENTIFY DEVICE BRIDGE TYPE BY LOOKING AT FIBARO DEVICE TYPE
-----------------------------------

deviceTypeMappings = {
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
