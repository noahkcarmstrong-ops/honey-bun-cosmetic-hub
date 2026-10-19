-- Client-only, reversible realistic lighting presets.
return function(game)
    local lighting
    local workspace
    local ok = pcall(function() lighting = game:GetService("Lighting") end)
    if not ok then lighting = nil end
    pcall(function() workspace = game:GetService("Workspace") end)

    local api = {}
    local destroyed = false
    local preset, strength
    local savedLighting = {}
    local savedEffects = {}
    local own = {}
    local connection
    local elapsed = 0

    local lightingProperties = {
        "GlobalShadows", "Brightness", "ShadowSoftness", "Ambient", "OutdoorAmbient",
        "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation"
    }
    local competing = {BloomEffect=true, ColorCorrectionEffect=true, SunRaysEffect=true}

    local function set(object, property, value)
        if object then pcall(function() object[property] = value end) end
    end
    local function get(object, property)
        local okValue, value = pcall(function() return object[property] end)
        if okValue then return true, value end
        return false
    end
    local function children(parent)
        if not parent or not parent.GetChildren then return {} end
        local okChildren, result = pcall(function() return parent:GetChildren() end)
        return okChildren and result or {}
    end
    local function isCompeting(object)
        local okClass, class = pcall(function() return object.ClassName end)
        if okClass and competing[class] then return true end
        return object.IsA and (object:IsA("BloomEffect") or object:IsA("ColorCorrectionEffect") or object:IsA("SunRaysEffect"))
    end
    local function saveEffect(object)
        if not object or own[object] or savedEffects[object] ~= nil then return end
        local okEnabled, enabled = get(object, "Enabled")
        if okEnabled then savedEffects[object] = enabled end
    end
    local function disableCompeting(parent)
        for _, object in ipairs(children(parent)) do
            if isCompeting(object) and not own[object] then
                saveEffect(object)
                set(object, "Enabled", false)
            end
        end
    end
    local function syncCompeting()
        disableCompeting(lighting)
        local camera
        if workspace then pcall(function() camera = workspace.CurrentCamera end) end
        disableCompeting(camera)
    end
    local function color(r, g, b)
        return Color3.fromRGB(r, g, b)
    end
    local function blend(original, target, amount)
        if type(original) == "number" then return original + (target - original) * amount end
        if type(original) == "boolean" then return amount >= .5 and target or original end
        if original and original.R and target and target.R then
            local r = original.R + (target.R-original.R)*amount
            local g = original.G + (target.G-original.G)*amount
            local b = original.B + (target.B-original.B)*amount
            if Color3 and Color3.new then return Color3.new(r,g,b) end
        end
        return target
    end
    local targets = {
        Low = {GlobalShadows=true, Brightness=2, ShadowSoftness=.25, Ambient=color(105,105,105), OutdoorAmbient=color(145,145,145), EnvironmentDiffuseScale=.8, EnvironmentSpecularScale=.65, ExposureCompensation=.05},
        High = {GlobalShadows=true, Brightness=2.15, ShadowSoftness=.18, Ambient=color(92,92,102), OutdoorAmbient=color(160,165,180), EnvironmentDiffuseScale=1, EnvironmentSpecularScale=.9, ExposureCompensation=.12}
    }
    local function make(class, name)
        local object
        local okCreate = pcall(function() object = Instance.new(class) end)
        if not okCreate or not object then return end
        object.Name = name
        set(object, "Enabled", true)
        set(object, "Parent", lighting)
        own[object] = true
        return object
    end
    local function clearOwn()
        for object in pairs(own) do
            pcall(function() object:Destroy() end)
            own[object] = nil
        end
    end
    local function effectsFor(level, amount)
        clearOwn()
        local correction = make("ColorCorrectionEffect", "LarpbloxRealisticColor")
        if correction then
            set(correction, "Enabled", amount > 0)
            set(correction, "Brightness", (level == "High" and .025 or .01) * amount)
            set(correction, "Contrast", (level == "High" and .08 or .035) * amount)
            set(correction, "Saturation", (level == "High" and .04 or .015) * amount)
            set(correction, "TintColor", blend(color(255,255,255), level == "High" and color(255,248,238) or color(255,252,246), amount))
        end
        if level == "High" then
            local bloom = make("BloomEffect", "LarpbloxRealisticBloom")
            if bloom then set(bloom, "Enabled", amount > 0);set(bloom, "Intensity", .12 * amount);set(bloom, "Size", 24);set(bloom, "Threshold", .82) end
            local rays = make("SunRaysEffect", "LarpbloxRealisticSunRays")
            if rays then set(rays, "Enabled", amount > 0);set(rays, "Intensity", .025 * amount);set(rays, "Spread", .8) end
        end
    end
    local function enforce()
        if not preset or not lighting then return end
        local target = targets[preset]
        for _, property in ipairs(lightingProperties) do
            local original = savedLighting[property]
            if original ~= nil then set(lighting, property, blend(original, target[property], strength)) end
        end
        if strength == 0 then
            for object, value in pairs(savedEffects) do set(object, "Enabled", value) end
        else
            syncCompeting()
        end
    end
    function api.apply(level, amount)
        if destroyed then return false, "Realistic lighting has been destroyed." end
        if not lighting then return false, "Lighting service is unavailable." end
        if (level ~= "Low" and level ~= "High") or type(amount) ~= "number" or amount ~= amount or amount < 0 or amount > 1 then
            return false, "Preset must be Low or High and strength must be between 0 and 1."
        end
        if not preset then
            for _, property in ipairs(lightingProperties) do
                local exists, value = get(lighting, property)
                if exists then savedLighting[property] = value end
            end
            syncCompeting()
        end
        preset, strength = level, amount
        effectsFor(level, amount)
        enforce()
        if not connection then
            local run
            pcall(function() run = game:GetService("RunService") end)
            if run and run.Heartbeat and run.Heartbeat.Connect then
                connection = run.Heartbeat:Connect(function(dt)
                    elapsed = elapsed + (dt or 0)
                    if elapsed >= .5 then elapsed = 0; enforce() end
                end)
            end
        end
        return true
    end
    function api.restore()
        if connection then pcall(function() connection:Disconnect() end);connection=nil end
        clearOwn()
        for property, value in pairs(savedLighting) do set(lighting, property, value) end
        for object, value in pairs(savedEffects) do set(object, "Enabled", value) end
        savedLighting = {}
        savedEffects = {}
        preset, strength = nil, nil
        return true
    end
    function api.destroy()
        if destroyed then return end
        api.restore()
        destroyed = true
    end
    function api.state() return preset, strength end
    return api
end
