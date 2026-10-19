-- Client-only skybox customizer. The caller supplies the local game object.
return function(game)
    local lighting = game:GetService("Lighting")
    local originals = {}
    local custom
    local generation = 0
    local destroyed = false
    local keeper,blueprint
    local skyProperties={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}
    local function service(name)local ok,value=pcall(game.GetService,game,name);if ok then return value end end

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

    function api.apply(value)
        if destroyed then return false, "Atmosphere customizer has been destroyed." end
        local assetId = id(value)
        if not assetId then return false, "Enter a positive Roblox model asset ID or a supported Roblox asset URL." end
        generation = generation + 1
        local token = generation
        local roots
        local ok, result = pcall(function() return game:GetObjects("rbxassetid://" .. assetId) end)
        if not ok then return false, "Could not load that Roblox model asset: " .. tostring(result) end
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
            originals={}
            for _,child in ipairs(lighting:GetChildren()) do
                if child:IsA("Sky") then originals[#originals+1]={object=child,parent=child.Parent} end
            end
        end
        for _, entry in ipairs(originals) do entry.object.Parent = nil end
        if custom then custom.Parent = nil; custom:Destroy() end
        replacement.Parent = lighting
        custom = replacement
        if blueprint then blueprint:Destroy() end
        blueprint=replacement:Clone()
        if keeper then keeper:Disconnect() end
        local run=service("RunService")
        if run then
            local elapsed=0
            keeper=run.Heartbeat:Connect(function(dt)
                elapsed=elapsed+dt;if elapsed<0.25 then return end;elapsed=0
                if not custom or destroyed then return end
                for _,child in ipairs(lighting:GetChildren()) do
                    if child:IsA("Sky") and child~=custom then
                        local known=false;for _,entry in ipairs(originals) do if entry.object==child then known=true;break end end
                        if not known then originals[#originals+1]={object=child,parent=lighting} end
                        child.Parent=nil
                    end
                end
                local ok=pcall(function()
                    custom.Parent=lighting
                    for _,property in ipairs(skyProperties) do custom[property]=blueprint[property] end
                end)
                if not ok then custom=blueprint:Clone();custom.Parent=lighting end
            end)
        end
        return true
    end

    function api.restore()
        generation = generation + 1
        if keeper then keeper:Disconnect();keeper=nil end
        if blueprint then blueprint:Destroy();blueprint=nil end
        if custom then custom.Parent = nil; custom:Destroy(); custom = nil end
        for _, entry in ipairs(originals) do entry.object.Parent = entry.parent end
        originals={}
        return true
    end

    function api.destroy()
        if destroyed then return end
        api.restore()
        destroyed = true
    end

    return api
end
