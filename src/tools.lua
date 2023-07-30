local alphabet = {
    ["А"] = "A",
    ["Б"] = "B",
    ["В"] = "V",
    ["Г"] = "G",
    ["Д"] = "D",
    ["Е"] = "E",
    ["Ж"] = "Zh",
    ["З"] = "Z",
    ["И"] = "I",
    ["І"] = "I",
    ["Ї"] = "I",
    ["Й"] = "I",
    ["К"] = "K",
    ["Л"] = "L",
    ["М"] = "M",
    ["Н"] = "N",
    ["О"] = "O",
    ["П"] = "P",
    ["Р"] = "R",
    ["С"] = "S",
    ["Т"] = "T",
    ["У"] = "U",
    ["Ф"] = "F",
    ["Х"] = "H",
    ["Ч"] = "Ch",
    ["Ц"] = "C",
    ["Ш"] = "Sh",
    ["Щ"] = "Shch",
    ["И"] = "I",
    ["Є"] = "E",
    ["Э"] = "E",
    ["Ю"] = "Ju",
    ["Я"] = "Ja",
    ["а"] = "a",
    ["б"] = "b",
    ["в"] = "v",
    ["г"] = "g",
    ["д"] = "d",
    ["е"] = "e",
    ["~"] = "e",
    ["ж"] = "zh",
    ["з"] = "z",
    ["и"] = "i",
    ["і"] = "i",
    ["ї"] = "i",
    ["й"] = "i",
    ["к"] = "k",
    ["л"] = "l",
    ["м"] = "m",
    ["н"] = "n",
    ["о"] = "o",
    ["п"] = "p",
    ["р"] = "r",
    ["с"] = "s",
    ["т"] = "t",
    ["у"] = "u",
    ["ф"] = "f",
    ["х"] = "h",
    ["ч"] = "ch",
    ["ц"] = "c",
    ["ш"] = "sh",
    ["щ"] = "shch",
    ["ы"] = "i",
    ["ь"] = "'",
    ["є"] = "e",
    ["э"] = "e",
    ["ю"] = "ju",
    ["я"] = "ja"
}

function transliterate(input)
    if (not input) then
        return "unknown_input_for_transliteration"
    end

    local output = {}
    local i = 1

    for p, c in utf8.codes(input) do  
        local char = utf8.char(c)
        local outputCharacter = alphabet[char]

        if not outputCharacter then
        if (string.find(char, "%a") or string.find(char, "%d")) then
            outputCharacter = char
        else
            outputCharacter = "-"
        end

        end
        output[i] = outputCharacter
        i = i + 1
    end

    --print("RESULT " .. table.concat(output) ) 

    return table.concat(output) 
end

function extractMetaInfoFromDeviceName(deviceName)
    local metaInfo = {
        pureName = deviceName,
        autoPower = true,
        turnOffTimeout = 10 * 60,
        segmentId = -1,
    }
    
    local s, e = string.find(deviceName, "%[.+%]")
    if s and e then
        local pureName = string.gsub(string.sub(deviceName, 1, s-1), "%s+$", "")
        local metaStr = string.sub(deviceName, s+1, e-1)

        metaInfo.pureName = pureName
 
        local attrs = splitStringToNumbers(metaStr, "%.")
        if attrs[1] == "1" then
            metaInfo.autoPower = true
        else
            metaInfo.autoPower = false
        end

        if attrs[2] and attrs[2] ~= "-" then 
            metaInfo.turnOffTimeout = math.ceil(attrs[2] * 60)
        end

        if attrs[3] and attrs[3] ~= "-" then 
            metaInfo.segmentId = tonumber(attrs[3])
            metaInfo.rooms = {}

            local segmentIdsStr = fibaro.getGlobalVariable("segment_" .. metaInfo.segmentId)
            if segmentIdsStr then
                local roomIds = splitStringToNumbers(segmentIdsStr, ",")
                for i,roomIdStr in ipairs(roomIds) do
                    metaInfo.rooms[i] = roomIdStr
                end
            end
        end
    else
        metaInfo.name = deviceName
    end

    return metaInfo
end

function splitString(str, sep)
  local fields = {}
  str:gsub("([^" .. sep .."]+)",function(c) fields[#fields+1]=c:gsub("^%s*(.-)%s*$", "%1") end)
  return fields
end


function splitStringToNumbers(str, sep)
  local fields = {}
  str:gsub("([^" .. sep .."]+)",function(c) fields[#fields+1]=c end)
  return fields
end

function table_contains_value(tab, val)
    if not tab then
        return false
    end
    
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function isEmptyString(s)
  return s == nil or s == ""
end

function isNotEmptyString(s)
    return not isEmptyString(s)
end

function base64Encode(data)
    local b ='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function base64Decode(data)
    local b ='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function decodeBase64Auth(encoded)
    local decoded = base64Decode(encoded)
    
    local i = string.find(decoded, ":")

    if i then
        return string.sub(decoded, 0, i-1), string.sub(decoded, i+1, string.len(decoded))
    else
        return nil
    end
end

function shallowInsertTo(from, to)
    local orig_type = type(from)
    if orig_type == 'table' then
        for orig_key, orig_value in pairs(from) do
            table.insert(to, orig_value)
        end
    else -- number, string, boolean, etc
        copy = from
    end
end

function shallowCopyTo(from, to)
    local orig_type = type(from)
    if orig_type == 'table' then
        for orig_key, orig_value in pairs(from) do
            to[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = from
    end
end


function clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[clone(orig_key)] = clone(orig_value)
        end
        --setmetatable(copy, clone(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function inheritFrom(orig)
    return clone(orig)
end

function isNumber(value)
    if type(value) == "number" then return true end

    if value == tostring(tonumber(value)) then
        return true
    else
        return false
    end
end

function round(number, dec)
    local k = 10^dec

    local result = math.floor(number * k + 0.5) / k

    local resultWithoutTrailingZero = math.floor(result)
    if (resultWithoutTrailingZero ~= result) then
        return result
    else
        return resultWithoutTrailingZero
    end

    return result
end

function identifyLocalIpAddressForHc3()
    local networkInterfaces = api.get("/proxy?url=http://127.0.0.1:11112/api/settings/network")
    for i, j in pairs(networkInterfaces.networkConfig) do
        if (j.enabled) then
            return j.ipConfig.ip
        end
    end

    print("[WARNING] Cannot identify HC3 local ip address")
    
    return "unknown"
end

table.indexOf = function( t, object )
\tlocal result

    for i=1,#t do
        if object == t[i] then
            result = i
            break
        end
    end

\treturn result
end

function getCompositeQuickAppVariable(quickApp, variableName)
    local compositeValue
    compositeValue = quickApp:getVariable(variableName)

    if isNotEmptyString(compositeValue) then
        for i=2, 10 do
            local value = quickApp:getVariable(variableName .. i)
            if isNotEmptyString(value) then
                compositeValue = compositeValue .. value
            else
                break
            end
        end
    end

    return compositeValue
end

errorCacheMap = { }
errorCacheTimeout = 60
function logWithoutRepetableWarnings(data)
    -- filter out repeatable errors
    local lastErrorReceivedTimestamp = errorCacheMap[data.status]
    local currentTimestamp = os.time()
    if ((not lastErrorReceivedTimestamp) or (lastErrorReceivedTimestamp < (currentTimestamp - errorCacheTimeout))) then
        print("Unexpected response status \"" .. tostring(data.status) .. "\", muting any repeated warnings for " .. errorCacheTimeout .. " seconds")
        print("Full response body: " .. json.encode(data))

        -- mute repeatable warnings temporary (avoid spamming to logs)
        errorCacheMap[data.status] = currentTimestamp
    end
end
