--[[ RELEASE NOTES FOR 1.0.211
Summary: Updated source files structure for better maintainability

Description:
- device_api and device_helper are seggretated
- minor logging improvements
]]--

function QuickApp:onInit()
    self:debug("")
    self:debug("------- HC3 <-> MQTT BRIDGE")
    self:debug("Version: 1.0.211")
    self:debug("(!) IMPORTANT NOTE FOR THOSE USERS WHO USED THE QUICKAPP PRIOR TO 1.0.191 VERSION: Your Home Assistant dashboards and automations need to be reconfigured with new enity ids. This is a one-time effort that introduces a relatively \"small\" inconvenience for the greater good (a) introduce long-term stability so Home Assistant entity duplicates will not happen in certain scenarios (b) entity id namespaces are now syncronized between Fibaro and Home Assistant ecosystems")

    self:turnOn()
end

function QuickApp:publish(topic, payload)
    self.mqtt:publish(topic, tostring(payload), {retain = true})
end

function QuickApp:turnOn() 
    self:establishMqttConnection()
end

function QuickApp:turnOff()
    self:disconnectFromMqttAndHc3()
end

function QuickApp:establishMqttConnection() 
    -- IDENTIFY WHICH MQTT CONVENTIONS TO BE USED (e.g. Home Assistant, Homio, etc)
    self.mqttConventions = { }
    local mqttConventionStr = self:getVariable("mqttConvention")
    if (isEmptyString(mqttConventionStr)) then
        self.mqttConventions[0] = MqttConventionHomeAssistant
    else
        local arr = splitString(mqttConventionStr, ",")
        for i, j in ipairs(arr) do
            local convention = mqttConventionMappings[j]
            if (convention) then
                self.mqttConventions[i] = clone(convention)
            end
        end
    end

    local mqttConnectionParameters = self:getMqttConnectionParameters()

    -- Anonymize MQTT username and password before being printed to log
    local status, anonymizedMqttConnectionParameters = pcall(clone, mqttConnectionParameters)
    if (anonymizedMqttConnectionParameters.username) then
        anonymizedMqttConnectionParameters.username = "anonymized-username"
    end
    if (anonymizedMqttConnectionParameters.password) then
        anonymizedMqttConnectionParameters.password = "anonymized-password"
    end
    self:trace("MQTT Connection Parameters: " .. json.encode(anonymizedMqttConnectionParameters))

    local mqttClient = mqtt.Client.connect(
                                    self:getVariable("mqttUrl"),
                                    mqttConnectionParameters) 

    mqttClient:addEventListener('connected', function(event) self:onConnected(event) end)
    mqttClient:addEventListener('closed', function(event) self:onClosed(event) end)
    mqttClient:addEventListener('message', function(event) self:onMessage(event) end)
    mqttClient:addEventListener('error', function(event) self:onError(event) end)    
    
    self.mqtt = mqttClient
end

function QuickApp:getMqttConnectionParameters()
    local mqttConnectionParameters = {
        -- pickup last will from primary MQTT Convention provider
        lastWill = self.mqttConventions[1]:getLastWillMessage()
    }

    -- MQTT CLIENT ID (OPTIONAL)
    local mqttClientId = self:getVariable("mqttClientId")
    if (isEmptyString(mqttClientId)) then
        local autogeneratedMqttClientId = "HC3-" .. plugin.mainDeviceId .. "-" .. tostring(os.time())
        self:debug("All is good - mqttClientId has been generated for you automatically \"" .. autogeneratedMqttClientId .. "\"")
        mqttConnectionParameters.clientId = autogeneratedMqttClientId
    else
        mqttConnectionParameters.clientId = mqttClientId
    end

    -- MQTT KEEP ALIVE PERIOD
    local mqttKeepAlivePeriod = self:getVariable("mqttKeepAlive")
    if (mqttKeepAlivePeriod) then
        mqttConnectionParameters.keepAlivePeriod = tonumber(mqttKeepAlivePeriod)
    else
        mqttConnectionParameters.keepAlivePeriod = 60
    end

    -- MQTT AUTH (USERNAME/PASSWORD)
    local mqttUsername = self:getVariable("mqttUsername")
    local mqttPassword = self:getVariable("mqttPassword")

    if (mqttUsername) then
        mqttConnectionParameters.username = mqttUsername
    end
    if (mqttPassword) then
        mqttConnectionParameters.password = mqttPassword
    end

    return mqttConnectionParameters
end

function QuickApp:disconnectFromMqttAndHc3()
    self.hc3ConnectionEnabled = false
    self:closeMqttConnection()
end

function QuickApp:closeMqttConnection()
    for i, j in ipairs(self.mqttConventions) do
        if (j.mqtt ~= MqttConventionPrototype.mqtt) then
            j:onDisconnected()
        end
    end

    self.mqtt:disconnect()
end

function QuickApp:disconnectFromMqttAndHc3()
    self.hc3ConnectionEnabled = false
    self:closeMqttConnection()
end


function QuickApp:onClosed(event)
    self:updateProperty("value", false)
    self:debug("")
    self:debug("------- Disconnected from MQTT/Home Assistant")
end

function QuickApp:onError(event)
    self:error("MQTT ERROR: " .. json.encode(event))
    if event.code == 2 then
        self:warning("MQTT username and/or password is possibly indicated wrongly")
    end
    self:turnOff()
    self:scheduleReconnectToMqtt();
end

function QuickApp:scheduleReconnectToMqtt()
    fibaro.setTimeout(10000, function() 
        self:debug("Attempt to reconnect to MQTT...")
        self:establishMqttConnection()
    end)
end

function QuickApp:onMessage(event)
    for i, j in ipairs(self.mqttConventions) do
        j:onCommand(event)
    end
end

function QuickApp:onConnected(event) 
    self:debug("")
    self:debug("------- Connected to MQTT/Home Assistant")

    for _, mqttConvention in ipairs(self.mqttConventions) do
        mqttConvention.mqtt = self.mqtt
        mqttConvention:onConnected()
    end

    self:discoverDevicesAndPublishToMqtt()

    self.hc3ConnectionEnabled = true
    self:scheduleHc3EventsFetcher()

    self:updateProperty("value", true)
end

function QuickApp:discoverDevicesAndPublishToMqtt()
    local startTime = os.time()
    local phaseStartTime = startTime
    
    local deviceHierarchyRootNode = self:discoverDeviceHierarchy()
    local phaseEndTime = os.time()
    
    self:debug("")
    self:debug("-------- Fibaro device discovery has been complete in " .. (phaseEndTime - phaseStartTime) .. " second(s)")
    self:debug("Total Fibaro devices                 : " .. allFibaroDevicesAmount)
    self:debug("Filtered Fibaro devices to           : " .. filteredFibaroDevicesAmount)
    self:debug("Number of Home Assistant entities    : " .. identifiedHaEntitiesAmount .. " => number of supported Fibaro devices + automatically generated entities for power, energy and battery sensors (when found appropriate interfaces for a Fibaro device) + automatically generated  remote controllers, where cartesian join is applied for each key and press types")
    self:debug("")
    self:printDeviceNode(deviceHierarchyRootNode, 0)

    phaseStartTime = os.time()
    self:publishDeviceNodeToMqtt(deviceHierarchyRootNode)
    phaseEndTime = os.time()    

    self:debug("")
    self:debug("------- Fibaro device configuration and states have been distributed to MQTT/Home Assistant in " .. (phaseEndTime - phaseStartTime) .. " second(s)")

    local diff = os.time() - startTime

    self:updateView("totalFibaroDevices", "text", "Total Fibaro devices: " .. allFibaroDevicesAmount)
    self:updateView("filteredFibaroDevices", "text", "Filtered Fibaro devices: " .. filteredFibaroDevicesAmount)
    self:updateView("haEntities", "text", "Home Assistant entities: " .. identifiedHaEntitiesAmount)
 
    self:updateView("bootTime" , "text", "Boot time: " .. diff .. "s")
end

function QuickApp:discoverDeviceHierarchy()
    local developmentModeStr = self:getVariable("developmentMode")
    if ((not developmentModeStr) or (developmentModeStr ~= "true")) then
        self:debug("Bridge mode: PRODUCTION")

        local customDeviceFilterJsonStr = self:getVariable("deviceFilter")
        if (isEmptyString(mqttClientId)) then
            self:debug("All is good - default filter applied, where only enabled and visible devices are used")
        end

        fibaroDevices = getDeviceHierarchyByFilter(customDeviceFilterJsonStr)
    else
        -- smaller number of devices for development and testing purposes
        self:debug("Bridge mode: DEVELOPMENT (temporary unsupported)")
        --[[
        fibaroDevices = {
            enrichFibaroDeviceWithMetaInfo(
                json.decode(
                    "{  }"
                )
            ) 
        }
        ]]--
    end

    return fibaroDevices
end

-- *** rename and move to helper class
function QuickApp:printDeviceNode(deviceNode, level)
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
        self:debug(deviceDescription)
    end

    for _, deviceChildNode in pairs(deviceNode.childNodeList) do
        self:printDeviceNode(deviceChildNode, level + 1)
    end

end

-- *** rename to "*AndItsChildren"
function QuickApp:publishDeviceNodeToMqtt(deviceNode)
    if (deviceNode.identifiedHaEntity) then
        self:__publishDeviceNodeToMqtt(deviceNode)
    end

    for _, fibaroDeviceChildNode in pairs(deviceNode.childNodeList) do
        self:publishDeviceNodeToMqtt(fibaroDeviceChildNode)
    end
end


function QuickApp:discoverDevicesByFilter()
    local fibaroDevices

    local developmentModeStr = self:getVariable("developmentMode")
    if ((not developmentModeStr) or (developmentModeStr ~= "true")) then
        self:debug("Bridge mode: PRODUCTION")

        local customDeviceFilterJsonStr = self:getVariable("deviceFilter")
        if (isEmptyString(mqttClientId)) then
            self:debug("All is good - default filter applied, where only enabled and visible devices are used")
        end

        fibaroDevices = getFibaroDevicesByFilter(customDeviceFilterJsonStr)
    else
        --smaller number of devices for development and testing purposes
        self:debug("Bridge mode: DEVELOPMENT")

        fibaroDevices = {
            enrichFibaroDeviceWithMetaInfo(
                json.decode(
                    "{  }"
                )
            ) 
        }
    end

    return fibaroDevices
end

function QuickApp:__publishDeviceNodeToMqtt(deviceNode)
    ------------------------------------------------------------------
    ------- ANNOUNCE DEVICE EXISTANCE
    ------------------------------------------------------------------
    for i, j in ipairs(self.mqttConventions) do
        j:onDeviceNodeCreated(deviceNode)
    end

    ------------------------------------------------------------------
    ------- ANNOUNCE DEVICE CURRENT STATE => BY SIMULATING HC3 EVENTS
    ------------------------------------------------------------------
    self:__publishDeviceProperties(deviceNode.fibaroDevice)
end

function QuickApp:__publishDeviceProperties(fibaroDevice)
    self:simulatePropertyUpdate(fibaroDevice, "dead", fibaroDevice.properties.dead)
    self:simulatePropertyUpdate(fibaroDevice, "state", fibaroDevice.properties.state)
    self:simulatePropertyUpdate(fibaroDevice, "value", fibaroDevice.properties.value)
    self:simulatePropertyUpdate(fibaroDevice, "heatingThermostatSetpoint", fibaroDevice.properties.heatingThermostatSetpoint)
    self:simulatePropertyUpdate(fibaroDevice, "thermostatMode", fibaroDevice.properties.thermostatMode)
    self:simulatePropertyUpdate(fibaroDevice, "energy", fibaroDevice.properties.energy)
    self:simulatePropertyUpdate(fibaroDevice, "power", fibaroDevice.properties.power)
    self:simulatePropertyUpdate(fibaroDevice, "batteryLevel", fibaroDevice.properties.batteryLevel)
    self:simulatePropertyUpdate(fibaroDevice, "color", fibaroDevice.properties.color)
end

function QuickApp:onPublished(event)
    -- do nothing, for now
end

-- FETCH HC3 EVENTS
local lastRefresh = 0
local http = net.HTTPClient()

function QuickApp:scheduleHc3EventsFetcher()
    self.errorCacheMap = { }
    self.errorCacheTimeout = 60
    self.gotWarning = false
    
    self.eventProcessorIsActive = false

    self:scheduleAnotherPollingForHc3()

    self:debug("")
    self:debug("------- Connected to Fibaro Home Center 3 events feed")
end

function QuickApp:scheduleAnotherPollingForHc3()
    if (self.hc3ConnectionEnabled) then
        local delay
        if self.gotWarning then
            -- avoid hitting errors with a "speed of light"
            delay = 1000
        else
            -- provide fast events distribution to Home Assistant when no errors present
            delay = 50
        end

        fibaro.setTimeout(delay, function()
            self:readHc3EventAndScheduleFetcher()
        end)
    else
        self:debug("")
        self:debug("------- Disconnected from Fibaro HC3")
    end
end

function QuickApp:readHc3EventAndScheduleFetcher()
    -- This a reliable and high-performance method to get events from Fibaro HC3, by using non-blocking HTTP calls

    -- no 2+ jobs to be executed twice
    self.eventProcessorIsActive = true

    local requestUrl = "http://127.0.0.1:11111/api/refreshStates?last=" .. lastRefresh

    local stat, res = http:request(
        requestUrl,
        {
        options = { },
        success=function(res)
            local data
            if (res and not isEmptyString(res.data)) then
                self:processFibaroHc3Events(json.decode(res.data))
                self:scheduleAnotherPollingForHc3()
            else
                self:error("Error while fetching events from Fibaro HC3. Response status code is " .. res.status .. ". HTTP response body is '" .. json.encode(res) .. "'")
                self:turnOff()
            end
        end,
        error=function(res) 
            self:error("Error while fetching Fibaro HC3 events " .. json.encode(res))
            self:turnOff()
        end
    })
end

function QuickApp:processFibaroHc3Events(data)
    self.gotWarning = false

    --if not self.hc3ConnectionEnabled then
    --    return
    --end

    -- Simulate repeatable broken status
    --data.status = "STARTING_SERVICES"

    if (data.status ~= 200 and data.status ~= "IDLE") then
        self.gotWarning = true
        if (not data.status) then
            data.status = "<unknown>"
        end

        -- filter out repeatable errors
        local lastErrorReceivedTimestamp = self.errorCacheMap[data.status]
        local currentTimestamp = os.time()
        if ((not lastErrorReceivedTimestamp) or (lastErrorReceivedTimestamp < (currentTimestamp - self.errorCacheTimeout))) then
            self:warning("Unexpected response status \"" .. tostring(data.status) .. "\", muting any repeated warnings for " .. self.errorCacheTimeout .. " seconds")
            self:trace("Full response body: " .. json.encode(data))

            -- mute repeatable warnings temporary (avoid spamming to logs)
            self.errorCacheMap[data.status] = currentTimestamp
        end
    end

    local events = data.events

    if (data.last) then
        lastRefresh = data.last
    end

    if events and #events>0 then 
        for i, v in ipairs(events) do
            -- *** rename dispatch to "PROCESS" / ename onDeviceCreated and so on => "dispatchToMqtt"
            self:dispatchFibaroEventToMqtt(v)
        end
    end
end

function QuickApp:simulatePropertyUpdate(fibaroDevice, propertyName, value)
    if value ~= nil then
        local event = createFibaroEventPayload(fibaroDevice, propertyName, value)
        event.simulation = true
        self:dispatchFibaroEventToMqtt(event)
    end
end

deviceModifiedEventTimestamps = {}
deviceCreatedEventTimestamps = {}
function QuickApp:dispatchFibaroEventToMqtt(event)
    if (not event) then
        self:error("No event found")
        return
    end

    if (not event.data) then
        self:error("No event data found")
        return
    end

    local fibaroDeviceId = event.data.id or event.data.deviceId

    -- *** add origin event source id

    if not fibaroDeviceId then
        -- This is a system level event, which is not bound to a particular device => ignore
        return
    end 

    local eventType = event.type
    if (not eventType) then
        eventType = "<unknown>"
    end

    local deviceNode = getDeviceNodeById(fibaroDeviceId)

    if (deviceNode) then
        -- process events for devices that are required to be known to the QuickApp
        if deviceNode.included then
            -- process events for devices that are included by user filter criteria
            local haEntity = deviceNode.identifiedHaEntity
            if haEntity then
                if (eventType == "DevicePropertyUpdatedEvent") then
                    return self:dispatchDevicePropertyUpdatedEvent(deviceNode, event) 
                elseif (eventType == "CentralSceneEvent") then
                    -- convert to DevicePropertyUpdatedEvent event, so we reuse the existing value dispatch mechanism rather than reinventing a wheel
                    local keyValueMapAsString = event.data.keyId .. "," .. string.lower(event.data.keyAttribute)
                    self:trace("Action => " .. event.data.keyId .. "-" .. string.lower(event.data.keyAttribute))
                    return self:simulatePropertyUpdate(deviceNode, "value", keyValueMapAsString)
                elseif (eventType == "DeviceModifiedEvent") then
                    -- Fibaro generates "DeviceModifiedEvent" event after "DeviceCreatedEvent" => filter out the reduntant event 
                    
                    local deviceLastCreationTimestamp = deviceCreatedEventTimestamps[fibaroDeviceId]
                    local deviceLastModificationTimestamp = deviceModifiedEventTimestamps[fibaroDeviceId]
                    if ((deviceLastCreationTimestamp) and (deviceLastCreationTimestamp == event.created)) then
                        self:debug("Ignore duplicate event for 'DeviceModifiedEvent' as it's called right after 'DeviceCreatedEvent'")
                        return
                    elseif ((deviceLastModificationTimestamp) and (deviceLastModificationTimestamp == event.created)) then
                        self:debug("Ignore duplicate event for 'DeviceModifiedEvent' as it's called right after another 'DeviceModifiedEvent'")
                        return
                    else
                        return self:dispatchDeviceModifiedEvent(deviceNode)
                    end
                elseif (eventType == "DeviceRemovedEvent") then 
                    return self:dispatchDeviceRemovedEvent(deviceNode)
                else
                    -- unsupported event type => ignore
                    return
                end
            else
                -- event for unsupported device => ignore
                return
            end
        
        else
            -- event for a device excluded by user filter criteria => ignore
            return
        end

    else 
        -- process events for devices that are NOT REQUIRED to be known to the QuickApp 
        if (eventType == "DeviceCreatedEvent") then
            deviceCreatedEventTimestamps[fibaroDeviceId] = event.created
            return self:dispatchDeviceCreatedEvent(fibaroDeviceId)
        else
            -- ignore unknown devices
            return
        end
    end

    -- Ignore and show no redundant warnings for unsupported event types
    if (unsupportedFibaroEventTypes[eventType]) then
        -- Ignore and show no redundant warnings
        return
    end

    self:debug("Couldn't process event \"" .. eventType .. "\" for " .. getDeviceDescriptionById(fibaroDeviceId))
    self:debug(json.encode(event))
end

function QuickApp:dispatchDevicePropertyUpdatedEvent(deviceNode, event)
    -- *** OVERRIDE FIBARO PROPERTY NAMES, FOR BEING MORE CONSISTENT AND THUS EASIER TO HANDLE 
    local haEntity = deviceNode.identifiedHaEntity
    local propertyName = event.data.property
    if not propertyName then
        propertyName = "unknown"
    end

    if (haEntity.type == "binary_sensor") and (propertyName == "value") then
        -- Fibaro uses state/value fields inconsistently for binary sensor. Replace value --> state field
        event.data.property = "state"
    end

    local value = event.data.newValue
    if (isNumber(value)) then
        value = round(value, 2)
    end

    event.data.newValue = (type(value) == "number" and value or tostring(value))
    
    for i, j in ipairs(self.mqttConventions) do
        j:onPropertyUpdated(deviceNode, event)
    end
end

function QuickApp:rememberLastMqttCommandTime(deviceId)
    self.lastMqttCommandTime[deviceId] = os.time()
end

function QuickApp:dispatchDeviceCreatedEvent(fibaroDeviceId)
    local newDeviceNode = createAndAddDeviceNodeToHierarchyById(fibaroDeviceId)

    if (newDeviceNode.included and newDeviceNode.identifiedHaEntity) then
        self:debug("Fibaro device " .. newDeviceNode.id .. " added")
        for i, j in ipairs(self.mqttConventions) do
            j:onDeviceNodeCreated(newDeviceNode)
        end
        
        self:__publishDeviceProperties(newDeviceNode.fibaroDevice)

        self:printDeviceNode(newDeviceNode, 1)
    else
        self:debug("New device " .. newDeviceNode.id .. " will not be added")
    end
end

function QuickApp:dispatchDeviceModifiedEvent(deviceNode)
    self:debug("Fibaro device " .. deviceNode.id .. " got modified => its old configuration to be removed, and then the new one added by the QuickApp")

    self:dispatchDeviceRemovedEvent(deviceNode)

    self:dispatchDeviceCreatedEvent(deviceNode.id)
end

function QuickApp:dispatchDeviceRemovedEvent(deviceNode)
    removeDeviceNodeFromHierarchyById(deviceNode.id)

    for _, mqttConvention in ipairs(self.mqttConventions) do
        mqttConvention:onDeviceNodeRemoved(deviceNode)

        for _, childNode in ipairs(deviceNode.childNodeList) do
            self:dispatchDeviceRemovedEvent(childNode)
        end

    end
    self:debug("Fibaro device removed " .. deviceNode.id)
end

function QuickApp:logDeviceNode(id)
    local deviceNode = getDeviceNodeById(id)
    print("------- DEVICE NODE INFO FOR #" .. id)
    print("Matched filter criteria: " ..tostring(deviceNode.included))
    print("Fibaro device: " ..json.encode(deviceNode.fibaroDevice))

    local haDeviceStr
    if deviceNode.identifiedHaDevice then
        haDeviceStr = json.encode(deviceNode.identifiedHaDevice)
    else 
        haDeviceStr = "not found => not supported by the Quick App"
    end
    print("Home Assistant physical device: " .. haDeviceStr)

    local haEntityStr
    if deviceNode.identifiedHaEntity then
        local haEntity = deviceNode.identifiedHaEntity
        local haEntityCopy = { 
            id = haEntity.id,
            name = haEntity.name,
            roomName = haEntity.roomName,
            type = haEntity.type,
            subtype = haEntity.subtype,
            icon = haEntity.icon
        } 
        if (haEntityCopy.linkedEntity) then
            haEntityCopy.linkedEntity = getDeviceDescriptionById(haEntityCopy.linkedEntity.id)
        end

        if (haEntityCopy.type == "climate") then
            local sensor =  haEntity:getTemperatureSensor()
            if sensor then
                haEntityCopy.temperatureSensor = getDeviceDescriptionById(haEntity:getTemperatureSensor().id)
            else
                haEntityCopy.temperatureSensor = "no temperature sensor attached"
            end
        end

        haEntityStr = json.encode(haEntityCopy)
    else 
        haEntityStr = "not found => not supported by the Quick App"
    end
    print("Home Assistant logical entity: " .. haEntityStr)

    print("Children count : " .. tostring(#deviceNode.childNodeList))
end

unsupportedFibaroEventTypes = {
    DeviceActionRanEvent = true,
    DeviceChangedRoomEvent = true,
    QuickAppFilesChangedEvent = true, 
    PluginChangedViewEvent = true
}

-- *** FORMATTED LOG %d
