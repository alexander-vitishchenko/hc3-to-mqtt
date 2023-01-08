----------------------------------- 
-- CACHE FOR QUICKAPP PERFORMANCE BOOST 
-----------------------------------
-- **** ADD VIRTUAL ROOT NODE AT LEVEL 0
deviceHierarchy = { }
deviceNodeById = { }
deviceFilter = { }

allFibaroDevicesAmount = 0
filteredFibaroDevicesAmount = 0
identifiedHaEntitiesAmount = 0

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
        self.icon = "&#128167;" -- 💧
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
    elseif self:fibaroDeviceHasType("com.fibaro.humiditySensor") then 
        self.subtype = "humidity"
    elseif self:fibaroDeviceHasType("com.fibaro.energySensor")then 
        self.subtype = "energy"
        self.icon = "&#9889;" -- ⚡
    elseif self:fibaroDeviceHasType("com.fibaro.powerMeter") then 
        self.subtype = "power"
        self.icon = "&#9889;" -- ⚡
    elseif self:fibaroDeviceHasType("com.fibaro.batteryLevelSensor") then 
        self.subtype = "battery"
        self.icon = "&#128267;" -- 🔋
    elseif (self.subtype == RemoteController.subtype) then 
        -- *** REFACTOR
        -- do nothing / the purpose for this logical condition is to make sure RemoteController doesn't fall into "Unknown multilevel sensor" category
    elseif (fibaroDevice.properties.unit == "V") then
        self.subtype = "voltage"
        self.icon = "&#9889;" -- ⚡
    elseif (fibaroDevice.properties.unit == "A") then
        self.subtype = "current"
        self.icon = "&#9889;" -- ⚡
    elseif (fibaroDevice.properties.unit == "Hz") then
        self.subtype = "frequency"
    elseif (fibaroDevice.properties.unit == "W" or fibaroDevice.properties.unit == "kW" or fibaroDevice.properties.unit == "kVA") then
        self.subtype = "power"
        self.icon = "&#9889;" -- ⚡
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

function cleanDeviceCache()
    deviceHierarchy = { }
    deviceNodeById = { }

    allFibaroDevicesAmount = 0
    filteredFibaroDevicesAmount = 0
    identifiedHaEntitiesAmount = 0
end

function getDeviceHierarchyByFilter(customDeviceFilterJsonStr)
    cleanDeviceCache()

    deviceFilter = 
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
                    "id"
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

        shallowInsertTo(customDeviceFilterJson.filters, deviceFilter.filters)
    end

    print("Filter: " .. json.encode(deviceFilter))

    local allFibaroDevices = api.get("/devices")
    allFibaroDevicesAmount = #allFibaroDevices

    local filteredFibaroDeviceIds = api.post( 
        "/devices/filter", 
        deviceFilter
    )
    filteredFibaroDevicesAmount = #filteredFibaroDeviceIds

    ----------- BUILD FIBARO DEVICE HIERARCHY
    for i=1, #allFibaroDevices do
        appendNodeByFibaroDevice(allFibaroDevices[i], false)
    end

    -- DO PERFORMANCE HEAVY OPERATIONS ONLY FOR DEVICES THAT ARE IN FILTER SCOPE
    for i=1, #filteredFibaroDeviceIds do
        local fibaroDeviceId = filteredFibaroDeviceIds[i].id
        local deviceNode = deviceNodeById[fibaroDeviceId]
        local fibaroDevice = deviceNode.fibaroDevice
        
        ----------- INCLUDE NODE WITH DEVICE MATCHING FILTER CRITERIA
        deviceNode.included = true

        ----------- CREATE POWER, ENERGY & BATTERLY LEVEL SENSORS INSTEAD OF RELYING ON ATTRIBUTES WITHIN A SINGLE DEVICE
        __checkAndAppendLinkedDevices(fibaroDevice)
    end

    __identifyDeviceHierarchy(deviceHierarchy)

    return deviceHierarchy
end

----------- CREATE POWER, ENERGY & BATTERLY LEVEL SENSORS INSTEAD OF RELYING ON ATTRIBUTES WITHIN A SINGLE DEVICE
function __checkAndAppendLinkedDevices(fibaroDevice)

    -- Does device support energy monitoring? Create a dedicated sensor for Home Assistant
    if (table_contains_value(fibaroDevice.interfaces, "energy")) then 
        local sensor = createLinkedMultilevelSensorDevice(fibaroDevice, "energy")

        appendNodeByFibaroDevice(sensor, true)
    end

    -- Does device support power monitoring? Create a dedicated sensor for Home Assistant
    if (table_contains_value(fibaroDevice.interfaces, "power")) then 
        local sensor = createLinkedMultilevelSensorDevice(fibaroDevice, "power")

        appendNodeByFibaroDevice(sensor, true)
    end


    -- Battery powered device? Create a dedicated battery sensor for Home Assistant
    if (table_contains_value(fibaroDevice.interfaces, "battery")) then
        local sensor = createLinkedMultilevelSensorDevice(fibaroDevice, "batteryLevel")
        appendNodeByFibaroDevice(sensor, true)
    end

    -- Is it a "Remote Control" device? Created dedicated devices for each combination of Button and Press Type
    --if (device.type == RemoteController.type and device.subtype == RemoteController.subtype) then
    if (RemoteController.isSupported(fibaroDevice)) then
        if fibaroDevice.properties.centralSceneSupport then
            for _, i in ipairs(fibaroDevice.properties.centralSceneSupport) do
                for _, j in ipairs(i.keyAttributes) do
                    local sensor = createLinkedKey(fibaroDevice, i.keyId, j)

                    appendNodeByFibaroDevice(sensor, true)
                end
            end
        end
    end
end

function appendNodeByFibaroDevice(fibaroDevice, included)
    local fibaroDeviceId = fibaroDevice.id
    local parentNode = deviceNodeById[fibaroDevice.parentId]

    local node = {
        id = fibaroDevice.id,

        fibaroDevice = fibaroDevice,
        identifiedHaEntity = nil,
        identifiedHaDevice = nil,

        parentNode = parentNode,

        childNodeList = { },

        included = included,

        isHaDevice = false
    }
    deviceNodeById[fibaroDeviceId] = node

    -- enrich with room name, base/type fixes, etc
    if (not fibaroDevice.linkedDevice) then
        enrichFibaroDeviceWithMetaInfo(node.fibaroDevice)
    end

    if parentNode then
        table.insert(parentNode.childNodeList, node)
    else
        table.insert(deviceHierarchy, node)
    end

    return node
end

function getDeviceNodeById(fibaroDeviceId)
    return deviceNodeById[fibaroDeviceId]
end


function removeDeviceNodeFromHierarchyById(id)
    local deviceNode = deviceNodeById[id]
    
    local parentNode = deviceNode.parentNode
    local sourceListForDeviceNode
    
    if parentNode then
        sourceListForDeviceNode = parentNode.childNodeList
    else
        sourceListForDeviceNode = deviceHierarchy
    end

    local ind = table.indexOf(sourceListForDeviceNode, deviceNode)

    if (ind) then
        table.remove(sourceListForDeviceNode, ind)
    else
        print("WARNING: Device node " .. id .. " was not removed from cache")
    end

    deviceNodeById[id] = nil
end

function createAndAddDeviceNodeToHierarchyById(id)
    local fibaroDevice = api.get("/devices/" .. id)

    local status, deviceFilterById = pcall(clone, deviceFilter)
    local filterOperands = deviceFilterById.filters
    filterOperands[#filterOperands + 1] = {
            filter = "deviceID",
            value = { id }
    }
    
    local filteredFibaroDeviceIds = api.post( 
        "/devices/filter", 
        deviceFilterById
    )

    local newFibaroDevice = api.get("/devices/" .. id)
    local newDeviceNode = appendNodeByFibaroDevice(newFibaroDevice)

    if #filteredFibaroDeviceIds == 0 then
        print("Device " .. id .. " doesn't match to filter criteria and thus skipped") 
    else
        newDeviceNode.included = true

        __checkAndAppendLinkedDevices(newDeviceNode.fibaroDevice)

        __identifyDeviceNode(newDeviceNode)
    end

    return newDeviceNode
end

function enrichFibaroDeviceWithMetaInfo(fibaroDevice)
    -- OVERRIDE BASE TYPE IF NECESSARY
    local overrideBaseType = fibaroBaseTypeOverride[fibaroDevice.baseType]
    if overrideBaseType then 
        fibaroDevice.baseType = overrideBaseType
    end

    -- OVERRIDE TYPE IF NECESSARY
    local overrideType = fibaroTypeOverride[fibaroDevice.type]
    if overrideType then 
        fibaroDevice.type = overrideType
    end

    fibaroDevice.roomName = tostring(fibaro.getRoomNameByDeviceID(fibaroDevice.id))

    return fibaroDevice
end

function PrototypeEntity.isSupported(fibaroDevice)
    print("'isSupported' function is mandatory for implementation")
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

-- *** REMOVE AND MERGE WITH DEVICE HIERARCHY DISCOVERY
function __identifyDeviceHierarchy(deviceHierarchy)
    for _, j in pairs(deviceHierarchy) do
        __identifyDeviceNode(j)
    end
end

function __identifyDeviceNode(deviceNode)
    -- identify Home Assistant entity
    if (deviceNode.included) then
        -- *** REFACTOR TO REUSE IN A SIGNLE NODE DISCOVERY
        local identifiedHaEntity = __identifyHaEntity(deviceNode)

        if (identifiedHaEntity) then
            deviceNode.identifiedHaEntity = identifiedHaEntity
            identifiedHaEntitiesAmount = identifiedHaEntitiesAmount + 1
        end
    end

    -- identify Home Assistant device
    local haDevice
    if (deviceNode.parentNode and deviceNode.parentNode.identifiedHaDevice ~= nil) then
        haDevice = deviceNode.parentNode.identifiedHaDevice
    elseif deviceNode.fibaroDevice.baseType == "com.fibaro.device" then
        haDevice = identifyAndAppendHaDevice(deviceNode)
    elseif deviceNode.identifiedHaEntity ~= nil then
        haDevice = identifyAndAppendHaDevice(deviceNode)
    else
        -- no Home Assistant device association available
    end
    deviceNode.identifiedHaDevice = haDevice

    -- identify child devices
    for _, deviceChildNode in pairs(deviceNode.childNodeList) do
        __identifyDeviceNode(deviceChildNode)
    end
end

function __identifyHaEntity(deviceNode)
    for i, j in ipairs(haEntityTypeMappings) do
        if (j.isSupported(deviceNode.fibaroDevice)) then
            return j:new(deviceNode)
        end
    end

    return nul
end

function identifyAndAppendHaDevice(deviceNode)
    local fibaroDevice = deviceNode.fibaroDevice

    local haDevice = {
        identifiers = "hc3-" .. fibaroDevice.id,
        name = fibaroDevice.name,
        suggested_area = fibaroDevice.roomName,
        manufacturer = nil,
        hw_version = nil,
        sw_version = nil,
        model = fibaroDevice.properties.model, 
        configuration_url = "http://" .. localIpAddress .. "/app/settings/devices/list#device-" .. fibaroDevice.id
    }

    if fibaroDeviceHasInterface(fibaroDevice, "quickApp") then
        haDevice.hw_version = "QuickApp (virtual device)"
        haDevice.sw_version = tostring(fibaroDevice.baseType) .. "-" .. tostring(fibaroDevice.type)
    elseif fibaroDeviceHasInterface(fibaroDevice, "zwave") then
        -- IDENTIFY HARDWARE VERSION
        local zwaveHwVersion = fibaroDevice.properties.zwaveInfo
        if zwaveHwVersion then
            zwaveInfoComponents = splitStringToNumbers(zwaveHwVersion, ",")
            if (#zwaveInfoComponents == 3) then
                zwaveHwVersion = "Z-Wave type " .. zwaveInfoComponents[1] .. "; Z-Wave version " .. zwaveInfoComponents[2] .. "." .. zwaveInfoComponents[3]
            end
        end
        if zwaveHwVersion then
            haDevice.hw_version = zwaveHwVersion
        else   
            haDevice.hw_version = "Z-Wave"
        end
        
        -- IDENTIFY SOFTWARE VERSION
        if fibaroDevice.properties.zwaveCompany then
            haDevice.manufacturer = fibaroDevice.properties.zwaveCompany
            haDevice.sw_version = haDevice.manufacturer .. " " .. tostring(fibaroDevice.properties.zwaveVersion)
        else
            haDevice.sw_version = tostring(fibaroDevice.properties.zwaveVersion)
        end
    elseif fibaroDeviceHasInterface(fibaroDevice, "zigbee") then
        -- experimental, need hardware for testing
        if fibaroDevice.properties.zigbeeVersion then
            haDevice.hw_version = "Zigbee"
        else
            haDevice.hw_version = "Zigbee " .. fibaroDevice.properties.zigbeeVersion
        end
    elseif fibaroDeviceHasInterface(fibaroDevice, "nice") then
        -- experimental, need hardware for testing
        if fibaroDevice.properties.niceProtocol then
            haDevice.hw_version = "Nice " .. fibaroDevice.properties.niceProtocol
        else
            haDevice.hw_version = "Nice"
        end
    end

    deviceNode.isHaDevice = true

    return haDevice
end

-- ****** FIX DEFECT => TOPIC FOR LINKED DEVICE
function createLinkedMultilevelSensorDevice(fromDevice, linkedProperty)
    local linkedUnit
    local sensorTypeSuffix = "Sensor"
    if (linkedProperty == "energy") then
        linkedUnit = "kWh"
        sensorTypeSuffix = "Meter"
    elseif (linkedProperty == "power") then
        linkedUnit = "W"
        sensorTypeSuffix = "Meter"
    elseif (linkedProperty == "batteryLevel") then
        linkedUnit = "%"
    end

    local newLinkedFibaroSensor = createLinkedFibaroDevice(fromDevice, linkedProperty, linkedUnit)

    newLinkedFibaroSensor.baseType = "com.fibaro.multilevelSensor"
    newLinkedFibaroSensor.type = "com.fibaro." .. linkedProperty .. sensorTypeSuffix

    return newLinkedFibaroSensor
end

function createLinkedKey(fromDevice, keyId, keyAttribute)
    local keyAttribute = string.lower(keyAttribute)

    local action = keyId .. "-" .. keyAttribute

    --local newFibaroKey = createLinkedFibaroDevice(fromDevice, "value", nil)
    local newFibaroKey = createLinkedFibaroDevice(fromDevice, action, nil)
    newFibaroKey.baseType = "com.alexander_vitishchenko.remoteKey"
    newFibaroKey.keyId = keyId
    newFibaroKey.keyAttribute = keyAttribute

    return newFibaroKey
end

function createLinkedFibaroDevice(fromDevice, linkedProperty, linkedUnit)
    local newFibaroLinkedDevice = {
        id = fromDevice.id .. "_" .. linkedProperty,
        name = fromDevice.name,  
        roomID = fromDevice.roomID,
        roomName = fromDevice.roomName,
        parentId = fromDevice.id,
        linkedDevice = fromDevice,
        linkedProperty = linkedProperty,
        properties = {
            unit = linkedUnit
        },
        comment = "This entity has been autogenerated by HC3 <-> Home Assistant bridge to adjust the data model difference between Fibaro HC3 and Home Assistant. Fibaro treats '" .. linkedProperty .. "' entity to be an attribute of #" .. fromDevice.id .. ". And Home Asisstant requires these to be two separate entities"
    }

    return newFibaroLinkedDevice
end

function getDeviceDescriptionById(fibaroDeviceId)
    local description = "#" .. tostring(fibaroDeviceId)

    local deviceNode = getDeviceNodeById(fibaroDeviceId)

    if deviceNode then
        local fibaroDevice = deviceNode.fibaroDevice
        if fibaroDevice then
            description = description .. " named as " .. tostring(fibaroDevice.name) .. " at \"" .. tostring(fibaroDevice.roomName) .. "\""
        end
    end

    return description
end
