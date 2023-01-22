----------------------------------- 
-- CACHE FOR QUICKAPP PERFORMANCE BOOST 
-----------------------------------
deviceHierarchyRootNode = nil
deviceNodeById = { }
deviceFilter = { }

allFibaroDevicesAmount = 0
filteredFibaroDevicesAmount = 0
identifiedHaEntitiesAmount = 0

-----------------------------------
--  FIBARO DEVICE TYPE CUSTOM MAPPINGS 
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
    deviceHierarchyRootNode = nil
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
        print("--> Supported JSON format: " .. "{\"filter\":\"baseType\", \"value\":[\"com.fibaro.actor\"]},   {\"filter\":\"deviceID\", \"value\":[41,42]},   { MORE FILTERS MAY GO HERE }")
        print("--> See the list of Fibaro API filter types at https://manuals.fibaro.com/content/other/FIBARO_System_Lua_API.pdf => \"fibaro:getDevicesId(filters)\"")
        print("")

        local customDeviceFilterJson = json.decode("{ filters: [ " .. customDeviceFilterJsonStr .. "] }") 

        shallowInsertTo(customDeviceFilterJson.filters, deviceFilter.filters)
    else
        print("Default device filter is used: " .. json.encode(deviceFilter))
    end


    local allFibaroDevices = api.get("/devices")
    allFibaroDevicesAmount = #allFibaroDevices

    local filteredFibaroDeviceIds = api.post( 
        "/devices/filter", 
        deviceFilter
    )
    filteredFibaroDevicesAmount = #filteredFibaroDeviceIds

    ----------- SIMULATED ZIGBEE RGBW DEVICE
    --addSimulatedDevice(allFibaroDevices, filteredFibaroDeviceIds, "{\
  \"id\": 237,\
  \"name\": \"237\",\
  \"roomID\": 219,\
  \"view\": [],\
  \"type\": \"com.fibaro.zigbeeDevice\",\
  \"baseType\": \"com.fibaro.device\",\
  \"enabled\": true,\
  \"visible\": false,\
  \"isPlugin\": false,\
  \"parentId\": 8,\
  \"viewXml\": false,\
  \"hasUIView\": false,\
  \"configXml\": false,\
  \"interfaces\": [\
    \"zigbee\"\
  ],\
  \"properties\": {\
    \"categories\": [\
      \"other\"\
    ],\
    \"configured\": true,\
    \"dead\": true,\
    \"deadReason\": \"\",\
    \"deviceControlType\": 1,\
    \"deviceIcon\": 28,\
    \"deviceRole\": \"Other\",\
    \"deviceState\": \"Configured\",\
    \"icon\": {},\
    \"ieeeAddress\": \"0x84FD27EEEEEEE05E\",\
    \"log\": \"\",\
    \"logTemp\": \"\",\
    \"manufacturer\": \"Ajax Online\",\
    \"model\": \"AJ_ZB_GU10\",\
    \"networkAddress\": 12761,\
    \"saveLogs\": true,\
    \"supportedDeviceRoles\": [\
      \"Other\"\
    ],\
    \"userDescription\": \"\",\
    \"zigbeeDeviceIds\": \"13,97\"\
  },\
  \"actions\": {},\
  \"created\": 1656669191,\
  \"modified\": 1673281514,\
  \"sortOrder\": 110\
}")
    --addSimulatedDevice(allFibaroDevices, filteredFibaroDeviceIds, "{\
  \"id\": 238,\
  \"name\": \"Nightlight RGB\",\
  \"roomID\": 230,\
  \"view\": [\
    {\
      \"assetsPath\": \"\",\
      \"name\": \"com.fibaro.colorController\",\
      \"translatesPath\": \"/assets/i18n/com.fibaro.colorController\",\
      \"type\": \"ts\"\
    }\
  ],\
  \"type\": \"com.fibaro.FGRGBW442CC\",\
  \"baseType\": \"com.fibaro.colorController\",\
  \"enabled\": true,\
  \"visible\": true,\
  \"isPlugin\": false,\
  \"parentId\": 237,\
  \"viewXml\": false,\
  \"hasUIView\": false,\
  \"configXml\": false,\
  \"interfaces\": [\
    \"light\",\
    \"zigbee\"\
  ],\
  \"properties\": {\
    \"categories\": [\
      \"lights\"\
    ],\
    \"color\": \"208.0336600431721,0,254.99999999999997,0\",\
    \"colorComponents\": {},\
    \"configured\": true,\
    \"currentProgram\": 0,\
    \"currentProgramID\": 0,\
    \"dead\": false,\
    \"deadReason\": \"\",\
    \"deviceControlType\": 51,\
    \"deviceIcon\": 15,\
    \"deviceRole\": \"Rgb\",\
    \"icon\": {},\
    \"ieeeAddress\": \"0x84FD27EEEEEEE05E\",\
    \"isLight\": true,\
    \"log\": \"\",\
    \"logTemp\": \"\",\
    \"manufacturer\": \"\",\
    \"model\": \"\",\
    \"networkAddress\": 12761,\
    \"programsSortOrder\": \"1,2,3,4,5\",\
    \"saveLogs\": true,\
    \"state\": false,\
    \"supportedDeviceRoles\": [\
      \"Rgb\"\
    ],\
    \"userDescription\": \"\",\
    \"value\": 0\
  },\
  \"actions\": {\
    \"setColor\": 1,\
    \"setColorComponents\": 1,\
    \"setValue\": 1,\
    \"startColorEnhancement\": 1,\
    \"startColorFade\": 1,\
    \"startProgram\": 1,\
    \"stopColorChange\": 1,\
    \"toggle\": 0,\
    \"turnOff\": 0,\
    \"turnOn\": 0\
  },\
  \"created\": 1656669192,\
  \"modified\": 1674037508,\
  \"sortOrder\": 111\
}")
    --addSimulatedDevice(allFibaroDevices, filteredFibaroDeviceIds, "{\
  \"id\": 46,\
  \"name\": \"VR baie vitrée\",\
  \"roomID\": 221,\
  \"view\": [],\
  \"type\": \"com.fibaro.device\",\
  \"baseType\": \"\",\
  \"enabled\": true,\
  \"visible\": false,\
  \"isPlugin\": false,\
  \"parentId\": 7,\
  \"viewXml\": false,\
  \"hasUIView\": false,\
  \"configXml\": false,\
  \"interfaces\": [\
    \"nice\",\
    \"niceMono\"\
  ],\
  \"properties\": {\
    \"buttonHold\": 5000,\
    \"categories\": [\
      \"other\"\
    ],\
    \"configuration\": true,\
    \"dead\": false,\
    \"deadReason\": \"\",\
    \"deviceControlType\": 1,\
    \"deviceIcon\": 28,\
    \"deviceRole\": \"Other\",\
    \"deviceState\": \"Configured\",\
    \"icon\": {},\
    \"inputToChannelMap\": {},\
    \"log\": \"\",\
    \"logTemp\": \"\",\
    \"manufacturer\": \"NICE\",\
    \"model\": \"\",\
    \"niceId\": 13,\
    \"niceProtocol\": \"Opera0\",\
    \"numberOfSupportedButtons\": 8,\
    \"saveLogs\": true,\
    \"supportedDeviceRoles\": [\
      \"Other\"\
    ],\
    \"userDescription\": \"\"\
  },\
  \"actions\": {},\
  \"created\": 0,\
  \"modified\": 1671310430,\
  \"sortOrder\": 23\
}")
    --addSimulatedDevice(allFibaroDevices, filteredFibaroDeviceIds, "{\
  \"id\": 34,\
  \"name\": \"VR baie vitrée\",\
  \"roomID\": 221,\
  \"view\": [\
    {\
      \"assetsPath\": \"dynamic-plugins/com.fibaro.remoteBaseShutter\",\
      \"name\": \"com.fibaro.remoteBaseShutter\",\
      \"translatesPath\": \"/assets/i18n/com.fibaro.remoteBaseShutter\",\
      \"type\": \"ts\"\
    },\
    {\
      \"assetsPath\": \"dynamic-plugins/favorite-positions\",\
      \"name\": \"favorite-positions\",\
      \"translatesPath\": \"/assets/i18n/favorite-positions\",\
      \"type\": \"ts\"\
    }\
  ],\
  \"type\": \"com.fibaro.remoteBaseShutter\",\
  \"baseType\": \"com.fibaro.remoteController\",\
  \"enabled\": true,\
  \"visible\": true,\
  \"isPlugin\": false,\
  \"parentId\": 46,\
  \"viewXml\": false,\
  \"hasUIView\": true,\
  \"configXml\": false,\
  \"interfaces\": [\
    \"favoritePosition\",\
    \"nice\",\
    \"niceMono\"\
  ],\
  \"properties\": {\
    \"buttonHold\": 5000,\
    \"categories\": [\
      \"remotes\"\
    ],\
    \"configuration\": true,\
    \"dead\": false,\
    \"deadReason\": \"\",\
    \"deviceControlType\": 53,\
    \"deviceIcon\": 218,\
    \"deviceRole\": \"BlindsWithoutPositioning\",\
    \"deviceState\": \"Configured\",\
    \"favoritePositions\": [\
      {\
        \"label\": \"Favorite position 1\",\
        \"name\": \"FavoritePosition1\",\
        \"value\": 50\
      }\
    ],\
    \"favoritePositionsNativeSupport\": true,\
    \"icon\": {\
      \"path\": \"/assets/icon/fibaro/com.fibaro.remoteBaseShutter_garage/com.fibaro.remoteBaseShutter_garage.png\",\
      \"source\": \"HC\"\
    },\
    \"inputToChannelMap\": {\
      \"close\": [\
        3\
      ],\
      \"open\": [\
        1\
      ],\
      \"partialOpen1\": [],\
      \"step\": [],\
      \"stop\": [\
        2\
      ],\
      \"toggleCh1\": [],\
      \"toggleCh2\": [],\
      \"turnOffCh1\": [],\
      \"turnOffCh2\": [],\
      \"turnOnCh1\": [],\
      \"turnOnCh2\": [],\
      \"unsupported\": []\
    },\
    \"log\": \"\",\
    \"logTemp\": \"\",\
    \"manufacturer\": \"NICE\",\
    \"model\": \"\",\
    \"niceId\": 13,\
    \"niceProtocol\": \"Opera0\",\
    \"numberOfSupportedButtons\": 8,\
    \"saveLogs\": true,\
    \"supportedDeviceRoles\": [\
      \"BlindsWithoutPositioning\",\
      \"VenetianBlinds\",\
      \"Awning\"\
    ],\
    \"userDescription\": \"\"\
  },\
  \"actions\": {\
    \"close\": 0,\
    \"open\": 0,\
    \"setFavoritePosition\": 1,\
    \"stop\": 0\
  },\
  \"created\": 1649487581,\
  \"modified\": 1671310429,\
  \"sortOrder\": 15\
}")

    ----------- PREPARE VIRTUAL ROOT NODE
    deviceHierarchyRootNode = createUnidentifiedDeviceNode(
        {
            id = 0,
            name = "Root device node",
            parentId = nil,
            roomId = nil,
        }, 
        false
    )

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
        -- *** refactor "check" naming
        __checkAndAppendLinkedDevices(fibaroDevice)
    end

    __identifyDeviceNode(deviceHierarchyRootNode)

    return deviceHierarchyRootNode
end

function addSimulatedDevice(allFibaroDevices, filteredFibaroDeviceIds, fibaroDeviceJsonStr)
    local fibaroDevice = json.decode(fibaroDeviceJsonStr)
    fibaroDevice.id = fibaroDevice.id + 20000
    if fibaroDevice.parentId > 10 then
        fibaroDevice.parentId = fibaroDevice.parentId + 20000
    end
    
    table.insert(allFibaroDevices, fibaroDevice)
    table.insert(filteredFibaroDeviceIds, { id = fibaroDevice.id })

    allFibaroDevicesAmount = #allFibaroDevices
    filteredFibaroDevicesAmount = #filteredFibaroDeviceIds
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

    local node = createUnidentifiedDeviceNode(fibaroDevice, included)

    deviceNodeById[fibaroDeviceId] = node

    -- enrich with room name, base/type fixes, etc
    if (not fibaroDevice.linkedDevice) then
        enrichFibaroDeviceWithMetaInfo(node.fibaroDevice)
    end

    local parentNode = node.parentNode
    if parentNode then
        table.insert(parentNode.childNodeList, node)
    else
        table.insert(deviceHierarchyRootNode.childNodeList, node)
    end

    return node
end

-- *** rename "included" to "includedToFilterCriteria"
function createUnidentifiedDeviceNode(fibaroDevice, included)
    -- lookup parent node from cache
    local parentNode
    if fibaroDevice.parentId then
        parentNode = deviceNodeById[fibaroDevice.parentId]
    else
        parentNode = nil
    end

    local node = {
        id = fibaroDevice.id,

        fibaroDevice = fibaroDevice,
        identifiedHaEntity = nil,
        identifiedHaDevice = nil,

        parentNode = parentNode,

        childNodeList = { },

        included = included,

        -- *** simplify node structure/naming
        isHaDevice = false
    }

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

-- *** rename to __identifyDeviceNodeAndItsChildren
function __identifyDeviceNode(deviceNode)
    -- identify Home Assistant entity
    if (deviceNode.included) then
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
        haDevice = __identifyAndAppendHaDevice(deviceNode)
    elseif deviceNode.identifiedHaEntity ~= nil then
        haDevice = __identifyAndAppendHaDevice(deviceNode)
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

function __identifyAndAppendHaDevice(deviceNode)
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
            haDevice.hw_version = "Zigbee " .. tostring(fibaroDevice.properties.zigbeeVersion)
        end
    elseif fibaroDeviceHasInterface(fibaroDevice, "nice") then
        -- experimental, need hardware for testing
        if fibaroDevice.properties.niceProtocol then
            haDevice.hw_version = "Nice " .. tostring(fibaroDevice.properties.niceProtocol)
        else
            haDevice.hw_version = "Nice"
        end
    end

    deviceNode.isHaDevice = true

    return haDevice
end

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

function printDeviceNode(deviceNode, level)
    local deviceDescription = ""

    local lastSiblingNode
    local lastSiblingNodeOfParent
    local lastSiblingNodeOfParentOfParent
    if (deviceNode.parentNode) then
        local siblingNodes = deviceNode.parentNode.childNodeList
        lastSiblingNode = siblingNodes[#siblingNodes]

        if (deviceNode.parentNode.parentNode) then
            local siblingNodesOfParent = deviceNode.parentNode.parentNode.childNodeList
            lastSiblingNodeOfParent = siblingNodesOfParent[#siblingNodesOfParent]

            if (deviceNode.parentNode.parentNode.parentNode) then
                local siblingNodesOfParentOfParent = deviceNode.parentNode.parentNode.parentNode.childNodeList
                lastSiblingNodeOfParentOfParent = siblingNodesOfParentOfParent[#siblingNodesOfParentOfParent]
            end
        end
    end

    if level > 1 then
        local levelCap = level-1
        for i=1, levelCap do
            deviceDescription = deviceDescription .. "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
            
            if (i > 1) then
                deviceDescription = deviceDescription .. "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
            end
            
            -- *** refactor with dynamic parent level number 
            if (i < levelCap) then
                if ((i == (levelCap - 2)) and (deviceNode.parentNode ~= lastSiblingNodeOfParentOfParent)) then
                    deviceDescription = deviceDescription .. "&#x2503;"
                elseif ((i == (levelCap - 1)) and (deviceNode.parentNode ~= lastSiblingNodeOfParent)) then
                    deviceDescription = deviceDescription .. "&#x2503;"
                else
                    deviceDescription = deviceDescription .. "&nbsp;"
                end
            end
        end

        if (deviceNode == lastSiblingNode) then
            -- ┗
            deviceDescription = deviceDescription .. "&#x2517;"
        else
            -- ┣
            deviceDescription = deviceDescription .. "&#9507;"
        end

        -- ━━▶
        deviceDescription = deviceDescription .. "&#9473;&#9473;&#9654; "
    end

    local bracketStart
    local bracketEnd
    if (deviceNode.isHaDevice) then
        -- 〚  〛
        --bracketStart = "&#12310;"
        --bracketEnd = "&#12311;"
        -- < >
        bracketStart = "<"
        bracketEnd = ">"
    else
        bracketStart = "["
        bracketEnd = "]"
    end

    local deviceType
    if (deviceNode.included) then
        local identifiedHaEntity = deviceNode.identifiedHaEntity

        if (identifiedHaEntity) then
            -- 💡, 🌈, 🔌, etc
            deviceDescription = deviceDescription .. bracketStart .. identifiedHaEntity.icon .. bracketEnd.. " "
            deviceType = identifiedHaEntity.type .. "-" .. tostring(identifiedHaEntity.subtype)
        else
            -- 🚧
            deviceDescription = deviceDescription .. bracketStart .. "&#128679;" .. bracketEnd .. " "
        end
    else
        -- 🛇
        deviceDescription = deviceDescription .. bracketStart .. "&#128711;" .. bracketEnd .. " "
    end

    local fibaroDevice = deviceNode.fibaroDevice
    
    deviceDescription = deviceDescription .. "#" .. fibaroDevice.id .. " named as \""  .. tostring(fibaroDevice.name) .. "\""

    if (fibaroDevice.roomName) then
        deviceDescription = deviceDescription .. " in \"" .. fibaroDevice.roomName .. "\" room"
    end

    if (deviceNode.included) then
        if (deviceType) then
            deviceDescription = deviceDescription .. " identified as " .. deviceType .. " type"
        else
            deviceDescription = deviceDescription .. " (unsupported device: " .. fibaroDevice.baseType .. "-" .. fibaroDevice.type .. ")"
        end
    else
        deviceDescription = deviceDescription .. " (excluded by QuickApp filters)"
    end

    if (level > 0) then
        print(deviceDescription)
    end

    for _, deviceChildNode in pairs(deviceNode.childNodeList) do
        printDeviceNode(deviceChildNode, level + 1)
    end

end
