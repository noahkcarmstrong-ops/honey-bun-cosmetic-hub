-- Mirrors cosmetic attributes to a per-account executor file across Roblox sessions.
local Http=game:GetService("HttpService")
local function allowed(key,value)
    if type(key)~="string" or #key>80 then return false end
    local kind=type(value)
    if key=="HoneyBunCosmeticSettings" or key=="HoneyBunCosmeticEmotes" or key=="HoneyBunCosmeticClothes" then
        return kind=="string" and #value<=131072
    end
    if key=="HoneyBunCosmeticEffects" then return kind=="string" and #value<=1400000 end
    if key=="HoneyBunCosmeticGuns" then return kind=="string" and #value<=1400000 end
    if key=="HoneyBunCosmeticCharacters" then
        return kind=="string" and #value<=1400000
    end
    if key=="HoneyBunCosmeticAnimationBundle" then
        return kind=="number" and value>0 and value%1==0 and value<9007199254740992
    end
    if key:sub(1,19)~="HoneyBunCosmeticUI_" then return false end
    return (kind=="string" and #value<=8192) or kind=="boolean" or (kind=="number" and value==value and math.abs(value)<9007199254740992)
end
return function(gui,userId,onStatus)
    local api={}
    local notice="Auto-save: session only. Your executor does not support saving files."
    function api.status() return notice end
    function api.destroy() end
    if type(readfile)~="function" or type(writefile)~="function" then return api end
    assert(type(userId)=="number" and userId>0 and userId%1==0,"A valid Roblox account is needed to save settings.")
    local path="HoneyBunCosmeticHub_"..string.format("%.0f",userId)..".json"
    local function report(value)
        notice=value
        if onStatus then onStatus(value) end
    end
    local function read(pathToRead)
        local ok,raw=pcall(readfile,pathToRead)
        if not ok or type(raw)~="string" or #raw>8388608 then return nil end
        local decoded,saved=pcall(function() return Http:JSONDecode(raw) end)
        if decoded and type(saved)=="table" and saved.version==1 and type(saved.values)=="table" then return saved,raw end
    end
    local saved,lastValid=read(path)
    if not saved then saved,lastValid=read(path..".bak") end
    if saved then
        for key,value in pairs(saved.values) do
            if allowed(key,value) and gui:GetAttribute(key)==nil then gui:SetAttribute(key,value) end
        end
    end
    report("Auto-save: on. Saved choices load when you run the hub after rejoining.")
    local alive,dirty,scheduled=true,false,false
    local function flush()
        if not dirty then return end
        local values={}
        for key,value in pairs(gui:GetAttributes()) do if allowed(key,value) then values[key]=value end end
        local ok,message=pcall(function()
            local raw=Http:JSONEncode({version=1,values=values})
            assert(#raw<=8388608,"Saved settings exceed the file size limit.")
            writefile(path..".bak",lastValid or raw)
            writefile(path,raw)
            lastValid=raw
        end)
        if ok then
            dirty=false
            report("Auto-save: on. Saved choices load when you run the hub after rejoining.")
        else
            report("Auto-save failed. Session settings are kept; file access may be blocked by your executor.")
        end
    end
    local changed=gui.AttributeChanged:Connect(function(key)
        local value=gui:GetAttribute(key)
        if not allowed(key,value) and not (value==nil and (key=="HoneyBunCosmeticSettings" or key=="HoneyBunCosmeticEmotes" or key=="HoneyBunCosmeticClothes" or key=="HoneyBunCosmeticAnimationBundle" or key=="HoneyBunCosmeticCharacters" or key=="HoneyBunCosmeticEffects" or key=="HoneyBunCosmeticGuns" or key:sub(1,19)=="HoneyBunCosmeticUI_")) then return end
        dirty=true
        if key=="HoneyBunCosmeticSettings" or key=="HoneyBunCosmeticEmotes" or key=="HoneyBunCosmeticClothes" or key=="HoneyBunCosmeticAnimationBundle" or key=="HoneyBunCosmeticCharacters" or key=="HoneyBunCosmeticEffects" or key=="HoneyBunCosmeticGuns" then
            flush()
        elseif not scheduled then
            scheduled=true
            task.defer(function()
                scheduled=false
                if alive then flush() end
            end)
        end
    end)
    function api.destroy()
        if not alive then return end
        alive=false;changed:Disconnect();flush()
    end
    -- Migrate already-selected session settings when this version is refreshed in.
    dirty=true;flush()
    return api
end
