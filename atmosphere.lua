-- Client-only skybox customizer. The caller supplies the local game object.
return function(game,schema)
    local lighting = game:GetService("Lighting")
    local originals = {}
    local custom
    local generation = 0
    local destroyed = false
    local blueprint,skyAdded
    local overrideConnections={}
    local appliedId,lastFailure
    local repairs=0
    local daylight=true
    local originalClock
    local environmentSettings
    local originalLighting
    local atmosphereEntries={}
    local tint
    local skyProperties={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}
    local function service(name)local ok,value=pcall(game.GetService,game,name);if ok then return value end end

    local function finite(value)return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge end
    local function color(kind)
        local values={Natural={255,255,255},Warm={255,220,190},Cool={200,225,255},Pink={255,200,220}}
        local rgb=values[kind]
        if Color3 and Color3.fromRGB then return Color3.fromRGB(rgb[1],rgb[2],rgb[3]) end
        return {R=rgb[1]/255,G=rgb[2]/255,B=rgb[3]/255}
    end
    local function sameColor(a,b)
        if a==b then return true end
        return a and b and a.R==b.R and a.G==b.G and a.B==b.B
    end
    local function snapshotClock()
        if originalClock~=nil then return end
        originalClock=lighting.ClockTime
    end
    local function snapshotEnvironment()
        snapshotClock()
        if originalLighting~=nil then return end
        originalLighting={FogStart=lighting.FogStart,FogEnd=lighting.FogEnd,FogColor=lighting.FogColor}
    end
    local function rememberAtmosphere(object)
        for _,entry in ipairs(atmosphereEntries) do if entry.object==object then return end end
        atmosphereEntries[#atmosphereEntries+1]={object=object,parent=object.Parent}
    end

    local function id(value)
        if type(value)=="number" then
            if value>0 and value%1==0 and value<math.huge then return string.format("%.0f",value) end
            return
        end
        if type(value)~="string" then return end
        value=value:match("^%s*(.-)%s*$")
        local number=value:match("^%d+$") or value:match("^rbxassetid://(%d+)$")
        if not number then
            local url=value:gsub("^https?://","")
            local host,path=url:match("^([^/]+)(/.*)$")
            if host=="roblox.com" or host=="www.roblox.com" then
                number=path:match("^/library/(%d+)$") or path:match("^/library/(%d+)/")
                    or path:match("^/catalog/(%d+)$") or path:match("^/catalog/(%d+)/")
                    or path:match("^/asset/%?id=(%d+)$")
            elseif host=="create.roblox.com" then
                number=path:match("^/store/asset/(%d+)$") or path:match("^/store/asset/(%d+)/")
            end
        end
        if number and number:find("[1-9]") then return number end
    end

    local function cleanup(roots)
        if type(roots) ~= "table" then return end
        for _, root in ipairs(roots) do
            if root and root.Destroy then pcall(function() root:Destroy() end) end
        end
    end

    local function findSkies(value, found)
        if value:IsA("Sky") then table.insert(found, value); return end
        for _, child in ipairs(value:GetChildren()) do findSkies(child, found) end
    end

    local api = {}
    local advancedEnforce,advancedRestore

    local function stopOverride()
        for _,connection in ipairs(overrideConnections)do connection:Disconnect()end;overrideConnections={}
        if skyAdded then skyAdded:Disconnect();skyAdded=nil end
    end
    local function removeCompeting(child)
        if destroyed then return end
        if environmentSettings and child:IsA("Atmosphere") then
            rememberAtmosphere(child);child.Parent=nil;repairs=repairs+1;return
        end
        if not custom or child==custom or not child:IsA("Sky") then return end
        local known=false
        for _,entry in ipairs(originals) do if entry.object==child then known=true;break end end
        if not known then originals[#originals+1]={object=child,parent=lighting} end
        child.Parent=nil;repairs=repairs+1
    end
    local function ensureTint()
        if not environmentSettings then return end
        local usable=false
        if tint then
            local ok=pcall(function()return tint.Parent end)
            if ok then usable=pcall(function()tint.Parent=lighting end) end
        end
        if not usable then tint=nil end
        if not tint then
            tint=Instance.new("ColorCorrectionEffect")
            tint.Name="LarpbloxEnvironmentTint"
            tint.Parent=lighting
        elseif tint.Parent~=lighting then tint.Parent=lighting end
        if not tint.Enabled then tint.Enabled=true end
        local wanted=color(environmentSettings.color)
        if not sameColor(tint.TintColor,wanted) then tint.TintColor=wanted end
    end
    local function enforceEnvironment()
        if not environmentSettings then return end
        local fog=({Off={100000,100000},Light={100,1800},Thick={0,300}})[environmentSettings.fog]
        if lighting.ClockTime~=environmentSettings.time then lighting.ClockTime=environmentSettings.time end
        if lighting.FogStart~=fog[1] then lighting.FogStart=fog[1] end
        if lighting.FogEnd~=fog[2] then lighting.FogEnd=fog[2] end
        local fogColor=color(environmentSettings.color)
        if not sameColor(lighting.FogColor,fogColor) then lighting.FogColor=fogColor end
        ensureTint()
    end
    local function enforceSky()
        if destroyed then return end
        if advancedEnforce then advancedEnforce()end
        if environmentSettings then enforceEnvironment() end
        if custom then
            if not environmentSettings and daylight and lighting.ClockTime~=14 then lighting.ClockTime=14 end
            for _,child in ipairs(lighting:GetChildren()) do removeCompeting(child) end
            local ok=pcall(function()
                custom.Parent=lighting
                for _,property in ipairs(skyProperties) do
                    if custom[property]~=blueprint[property] then custom[property]=blueprint[property] end
                end
            end)
            if not ok then custom=blueprint:Clone();custom.Parent=lighting end
        else
            for _,child in ipairs(lighting:GetChildren()) do removeCompeting(child) end
        end
    end
    local function startOverride()
        if skyAdded then return end
        if lighting.ChildAdded then skyAdded=lighting.ChildAdded:Connect(removeCompeting) end
        local enforcing=false
        local function changed()
            if enforcing or destroyed then return end
            enforcing=true
            local ok,err=pcall(enforceSky)
            enforcing=false
            if not ok then lastFailure=tostring(err)end
        end
        local watched=setmetatable({}, {__mode="k"})
        local function watch(object)
            if watched[object]then return end
            watched[object]=true
            overrideConnections[#overrideConnections+1]=object.Changed:Connect(changed)
        end
        watch(lighting)
        for _,object in ipairs(lighting:GetChildren())do watch(object)end
        overrideConnections[#overrideConnections+1]=lighting.ChildAdded:Connect(function(object)watch(object);changed()end)
        overrideConnections[#overrideConnections+1]=lighting.ChildRemoved:Connect(changed)
        enforceSky()
    end

    function api.apply(value)
        if destroyed then return false, "Atmosphere customizer has been destroyed." end
        local assetId = id(value)
        if not assetId then return false, "Enter a positive Roblox model asset ID or a supported Roblox asset URL." end
        generation = generation + 1
        local token = generation
        local roots
        local ok, result = pcall(function() return game:GetObjects("rbxassetid://" .. assetId) end)
        if not ok then lastFailure=tostring(result);return false, "Could not load that Roblox model asset: " .. tostring(result) end
        roots = result
        local found = {}
        if type(roots) == "table" then
            for _, root in ipairs(roots) do findSkies(root, found) end
        end
        if token ~= generation then
            cleanup(roots)
            return false, "Skybox replacement was cancelled."
        end
        if #found == 0 then
            cleanup(roots)
            return false, "That model has no Sky object. A skybox needs six skybox faces; an image ID alone is not enough."
        end
        if #found ~= 1 then
            cleanup(roots)
            return false, "That model contains more than one Sky object, so the skybox is ambiguous."
        end
        local cloned,replacement = pcall(function()
            local sky=found[1]:Clone()
            assert(sky,"The Sky object could not be copied.")
            for _,child in ipairs(sky:GetChildren()) do child:Destroy() end
            return sky
        end)
        cleanup(roots)
        if cloned then
            for _,property in ipairs(skyProperties) do
                if type(replacement[property])~="string" or replacement[property]=="" then
                    replacement:Destroy()
                    return false,"This Sky is missing one or more of its six images. Try a complete skybox model."
                end
            end
            local provider=service("ContentProvider")
            if provider then
                local failures={}
                local loaded,message=pcall(function()
                    provider:PreloadAsync({replacement},function(asset,status)
                        if status~=Enum.AssetFetchStatus.Success then failures[#failures+1]=tostring(asset) end
                    end)
                end)
                if not loaded or #failures>0 then
                    replacement:Destroy()
                    return false,"Roblox could not load this skybox's images. Try another model. "..tostring(message or failures[1])
                end
            end
        end
        if not cloned then return false,"Could not copy this skybox: "..tostring(replacement) end
        if token ~= generation or destroyed then
            replacement:Destroy()
            return false, "Skybox replacement was cancelled."
        end

        if not custom then
            snapshotClock()
            originals={}
            for _,child in ipairs(lighting:GetChildren()) do
                if child:IsA("Sky") then originals[#originals+1]={object=child,parent=child.Parent} end
            end
        end
        stopOverride()
        for _, entry in ipairs(originals) do entry.object.Parent = nil end
        if custom then custom.Parent = nil; custom:Destroy() end
        custom = replacement
        replacement.Parent = lighting
        if daylight and not environmentSettings then lighting.ClockTime=14 end
        appliedId=assetId;lastFailure=nil;repairs=0
        if blueprint then blueprint:Destroy() end
        blueprint=replacement:Clone()
        startOverride()
        return true
    end

    function api.applyEnvironment(settings)
        if destroyed then return false,"Atmosphere customizer has been destroyed." end
        if type(settings)~="table" then return false,"Environment settings are required." end
        local time,fog,kind=settings.time,settings.fog,settings.color
        if not finite(time) or time<0 or time>24 then return false,"Environment time must be a finite number from 0 to 24." end
        if fog~="Off" and fog~="Light" and fog~="Thick" then return false,"Environment fog must be Off, Light, or Thick." end
        if kind~="Natural" and kind~="Warm" and kind~="Cool" and kind~="Pink" then return false,"Environment color must be Natural, Warm, Cool, or Pink." end
        snapshotEnvironment()
        environmentSettings={time=time,fog=fog,color=kind}
        for _,child in ipairs(lighting:GetChildren()) do removeCompeting(child) end
        startOverride()
        enforceSky()
        return true
    end

    function api.environment()
        if not environmentSettings then return nil end
        return {time=environmentSettings.time,fog=environmentSettings.fog,color=environmentSettings.color}
    end

    function api.restoreEnvironment()
        if not environmentSettings then return true end
        environmentSettings=nil
        if tint then pcall(function()tint.Parent=nil;tint:Destroy()end);tint=nil end
        for _,entry in ipairs(atmosphereEntries) do pcall(function()entry.object.Parent=entry.parent end) end
        atmosphereEntries={}
        if custom then
            if daylight then lighting.ClockTime=14 elseif originalClock~=nil then lighting.ClockTime=originalClock end
        elseif originalClock~=nil then lighting.ClockTime=originalClock end
        if originalLighting then
            lighting.FogStart=originalLighting.FogStart;lighting.FogEnd=originalLighting.FogEnd;lighting.FogColor=originalLighting.FogColor
            originalLighting=nil
        end
        if not custom then stopOverride() end
        if not custom and originalClock~=nil then originalClock=nil;originalLighting=nil end
        return true
    end

    function api.restore()
        generation = generation + 1
        local hadEnvironment=environmentSettings~=nil
        if not hadEnvironment then stopOverride() end
        if blueprint then blueprint:Destroy();blueprint=nil end
        if custom then custom.Parent = nil; custom:Destroy(); custom = nil end
        for _, entry in ipairs(originals) do pcall(function()entry.object.Parent = entry.parent end) end
        originals={}
        if not hadEnvironment and originalClock~=nil then lighting.ClockTime=originalClock;originalClock=nil;originalLighting=nil end
        if hadEnvironment then enforceEnvironment() end
        return true
    end

    function api.currentAsset()return custom and appliedId end
    function api.previewImage()
        if custom then return custom.SkyboxFt end
        local sky=lighting:FindFirstChildOfClass("Sky")
        return sky and sky.SkyboxFt
    end

    function api.daylightEnabled()return daylight end
    function api.setDaylight(value)
        daylight=value==true
        if custom and not environmentSettings then lighting.ClockTime=daylight and 14 or originalClock end
        return daylight and "Daylight enabled for the custom sky." or "Game time restored; the sky may look dark at night."
    end

    function api.report()
        local lines={"Atmosphere build: immediate sky override V4","Requested asset="..tostring(appliedId or "none"),"Daylight="..tostring(daylight).." original clock="..tostring(originalClock),
            "Environment="..(environmentSettings and ("time="..tostring(environmentSettings.time).." fog="..environmentSettings.fog.." color="..environmentSettings.color) or "none"),
            "Custom sky parent="..tostring(custom and custom.Parent and custom.Parent.Name or "none"),
            "Override active="..tostring(keeper~=nil or boundRun~=nil).." competing sky removals="..repairs,
            "Last load failure="..tostring(lastFailure or "none")}
        for _,key in ipairs({"ClockTime","TimeOfDay","Brightness","ExposureCompensation","FogStart","FogEnd"}) do
            lines[#lines+1]="Lighting."..key.."="..tostring(lighting[key])
        end
        for _,object in ipairs(lighting:GetChildren()) do
            lines[#lines+1]="Lighting child="..object.Name.." ["..object.ClassName.."]"
            if object:IsA("Sky") then
                for _,key in ipairs(skyProperties) do lines[#lines+1]=key.."="..tostring(object[key]) end
            elseif object:IsA("Atmosphere") then
                lines[#lines+1]="Atmosphere density="..tostring(object.Density).." haze="..tostring(object.Haze).." glare="..tostring(object.Glare)
            end
        end
        local world=service("Workspace")
        if world then
            local count=0
            for _,object in ipairs(world:GetDescendants()) do
                local name=object.Name:lower()
                if object:IsA("BasePart") and (name:find("sky",1,true) or name:find("dome",1,true)) then
                    lines[#lines+1]="Sky geometry="..object:GetFullName().." size="..tostring(object.Size).." transparency="..tostring(object.Transparency).." localTransparency="..tostring(object.LocalTransparencyModifier)
                    count=count+1;if count>=20 then break end
                end
            end
        end
        return table.concat(lines,"\n")
    end

    -- Only properties edited by this editor are overridden. Game values are captured lazily.
    local edits,lightingOriginals,effectOriginals,effects={},{},{},{}
    local byId={}
    for _,group in ipairs(schema or {})do byId[group.id]=group end
    local function encode(value)return typeof(value)=="Color3" and ("#"..value:ToHex()) or value end
    local function decode(value,field)
        if field.type=="color"then
            local hex=type(value)=="string" and value:match("^#?(%x%x%x%x%x%x)$")
            assert(hex,"Enter a six-digit hex color.")
            return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
        elseif field.type=="number"then
            value=tonumber(value);assert(finite(value)and value>=field.min and value<=field.max,"Enter a value between "..field.min.." and "..field.max..".")
            return value
        elseif field.type=="boolean"then assert(type(value)=="boolean","Choose On or Off.");return value
        else
            assert(type(value)=="string"and #value<512,"Enter an image asset ID.")
            if value==""then return value end
            local asset=value:match("^%d+$")or value:match("^rbxassetid://(%d+)$")or value:match("[?&]id=(%d+)")or value:match("/catalog/(%d+)")
            assert(asset,"Enter a Roblox image ID.");return "rbxassetid://"..asset
        end
    end
    local function effect(group)
        if effects[group.id]then return effects[group.id]end
        local originalsForGroup={}
        for _,child in ipairs(lighting:GetChildren())do if child:IsA(group.target)then originalsForGroup[#originalsForGroup+1]=child end end
        local object=originalsForGroup[1]and originalsForGroup[1]:Clone()or Instance.new(group.target)
        object.Name="LarpbloxLighting_"..group.id
        for _,child in ipairs(object:GetChildren())do child:Destroy()end
        for _,child in ipairs(originalsForGroup)do child.Parent=nil end
        effectOriginals[group.id]=originalsForGroup;effects[group.id]=object;object.Parent=lighting
        return object
    end
    local function editableSky()
        if custom then return custom end
        local current=lighting:FindFirstChildOfClass("Sky")
        snapshotClock();originals={}
        for _,child in ipairs(lighting:GetChildren())do if child:IsA("Sky")then originals[#originals+1]={object=child,parent=lighting}end end
        custom=current and current:Clone()or Instance.new("Sky")
        for _,child in ipairs(custom:GetChildren())do child:Destroy()end
        for _,entry in ipairs(originals)do entry.object.Parent=nil end
        if blueprint then blueprint:Destroy()end
        blueprint=custom:Clone();custom.Parent=lighting;appliedId="";daylight=false
        return custom
    end
    local defaults={}
    function api.values()
        local result={}
        for _,group in ipairs(schema or {})do
            local object=group.target=="Lighting"and lighting or group.target=="Sky"and(custom or lighting:FindFirstChildOfClass("Sky"))or effects[group.id]or lighting:FindFirstChildOfClass(group.target)
            if not object and defaults[group.id]then result[group.id]=table.clone(defaults[group.id]);continue end
            local temporary
            if not object then temporary=Instance.new(group.target);object=temporary end
            local values={}
            for _,field in ipairs(group.fields)do
                if group.target=="Atmosphere"and field.key=="Enabled"then values.Enabled=object.Parent==lighting
                else local ok,value=pcall(function()return object[field.key]end);if ok then values[field.key]=encode(value)end end
            end
            if temporary then if values.Enabled~=nil then values.Enabled=false end;defaults[group.id]=table.clone(values);temporary:Destroy()end
            result[group.id]=values
        end
        return result
    end
    function api.update(groupId,key,value)
        assert(not destroyed,"Lighting editor was closed.")
        local group=byId[groupId];assert(group,"Unknown lighting section.")
        local field;for _,candidate in ipairs(group.fields)do if candidate.key==key then field=candidate;break end end
        assert(field,"Unknown lighting property.");local decoded=decode(value,field)
        -- Migrate old preset overrides before accepting direct property controls.
        if environmentSettings then
            local inherited={ClockTime=lighting.ClockTime,FogStart=lighting.FogStart,FogEnd=lighting.FogEnd,FogColor=lighting.FogColor}
            local inheritedTint=tint and tint.TintColor
            api.restoreEnvironment()
            api.update("light","ClockTime",inherited.ClockTime)
            for _,property in ipairs({"FogStart","FogEnd","FogColor"})do api.update("fog",property,encode(inherited[property]))end
            if inheritedTint then api.update("correction","TintColor",encode(inheritedTint));api.update("correction","Enabled",true)end
        end
        daylight=false
        local object=group.target=="Lighting"and lighting or group.target=="Sky"and editableSky()or effect(group)
        if group.target=="Lighting"and lightingOriginals[key]==nil then lightingOriginals[key]=object[key]end
        if group.target=="Atmosphere"and key=="Enabled"then object.Parent=decoded and lighting or nil
        else object[key]=decoded end
        edits[groupId]=edits[groupId]or {};edits[groupId][key]=encode(decoded)
        if group.target=="Sky"then if blueprint then blueprint:Destroy()end;blueprint=custom:Clone()end
        startOverride()
        return api.values()
    end
    advancedEnforce=function()
        for groupId,values in pairs(edits)do
            local group=byId[groupId]
            local object=group.target=="Lighting"and lighting or group.target=="Sky"and custom or effects[groupId]
            if object then
                if group.target~="Lighting"and group.target~="Sky"then
                    local enabled=group.target~="Atmosphere"or values.Enabled~=false
                    object.Parent=enabled and lighting or nil
                    for _,child in ipairs(lighting:GetChildren())do
                        if child~=object and child:IsA(group.target)then
                            local found=false;for _,old in ipairs(effectOriginals[groupId]or {})do if old==child then found=true end end
                            if not found then table.insert(effectOriginals[groupId],child)end
                            child.Parent=nil
                        end
                    end
                end
                for _,field in ipairs(group.fields)do
                    local value=values[field.key]
                    if value~=nil and not(group.target=="Atmosphere"and field.key=="Enabled")then
                        local wanted=decode(value,field);if object[field.key]~=wanted then object[field.key]=wanted end
                    end
                end
            end
        end
    end
    advancedRestore=function()
        edits={}
        for key,value in pairs(lightingOriginals)do pcall(function()lighting[key]=value end)end
        lightingOriginals={}
        for _,object in pairs(effects)do object:Destroy()end
        effects={}
        for _,entries in pairs(effectOriginals)do for _,object in ipairs(entries)do pcall(function()object.Parent=lighting end)end end
        effectOriginals={}
    end
    function api.configuration()return {version=2,asset=api.currentAsset()or "",daylight=false,properties=game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):JSONEncode(edits))}end
    function api.gameSkyImage()
        local sky
        if custom then sky=originals[1]and originals[1].object else sky=lighting:FindFirstChildOfClass("Sky")end
        if sky then return sky.SkyboxFt end
        local default=Instance.new("Sky");local image=default.SkyboxFt;default:Destroy()
        return image
    end
    function api.setSky(value)
        local previous=edits.sky
        edits.sky=nil
        daylight=false
        if value==""then
            api.restore()
        else
            local ok,message=api.apply(value)
            if not ok then edits.sky=previous;error(message,0)end
        end
        if next(edits)then startOverride()end
        return api.values()
    end
    function api.loadConfiguration(value)
        assert(type(value)=="table"and value.version==2 and type(value.properties)=="table","Invalid lighting preset.")
        assert(type(value.asset)=="string"and #value.asset<=512 and(value.asset==""or id(value.asset)),"Invalid skybox asset.")
        -- Validate the whole preset before changing anything.
        for groupId,values in pairs(value.properties)do
            local group=byId[groupId];assert(group and type(values)=="table","Invalid lighting section.")
            for key,item in pairs(values)do local known;for _,field in ipairs(group.fields)do if field.key==key then decode(item,field);known=true;break end end;assert(known,"Invalid lighting property.")end
        end
        api.resetLighting()
        api.setDaylight(false)
        if value.asset and value.asset~=""then local ok,message=api.apply(value.asset);assert(ok,message)end
        for groupId,values in pairs(value.properties)do for key,item in pairs(values)do api.update(groupId,key,item)end end
        return api.values()
    end
    function api.resetLighting()
        api.restoreEnvironment();api.restore();advancedRestore();stopOverride()
        return api.values()
    end

    function api.destroy()
        if destroyed then return end
        api.restore()
        if environmentSettings then api.restoreEnvironment() end
        if advancedRestore then advancedRestore()end
        destroyed = true
    end

    return api
end
