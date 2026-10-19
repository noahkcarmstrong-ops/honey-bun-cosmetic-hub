-- MM2 sheriff/hero crosshair. The module only changes the local mouse icon.
return function(game)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local renderName = "HoneyBunMM2Crosshair"

    local image = ""
    local live = false
    local savedIcon
    local lastApplied
    local connection
    local destroyed = false

    local function disconnect()
        if connection then connection:Disconnect(); connection = nil end
        if RunService.UnbindFromRenderStep then
            pcall(function() RunService:UnbindFromRenderStep(renderName) end)
        end
    end

    local function isGun(child)
        if not child or child.Name ~= "Gun" then return false end
        if child.IsA then
            local ok, result = pcall(function() return child:IsA("Tool") end)
            if ok then return result end
        end
        return child.ClassName == nil or child.ClassName == "Tool"
    end

    local function equippedGun(character)
        if not character or not character.GetChildren then return false end
        for _, child in ipairs(character:GetChildren()) do
            if isGun(child) then return true end
        end
        return false
    end

    local function hasLiveCharacter()
        local character = player.Character
        if not character then return false end
        local humanoid
        if character.FindFirstChildOfClass then humanoid = character:FindFirstChildOfClass("Humanoid") end
        if not humanoid and character.FindFirstChild then humanoid = character:FindFirstChild("Humanoid") end
        return not humanoid or (tonumber(humanoid.Health) or 0) > 0
    end

    local function restore()
        if live then
            if mouse.Icon ~= lastApplied then savedIcon = mouse.Icon end
            mouse.Icon = savedIcon
            live = false
            lastApplied = nil
        end
    end

    local function update()
        if destroyed then return end
        local character = player.Character
        local shouldLive = image ~= "" and hasLiveCharacter() and equippedGun(character)
        if shouldLive then
            if not live then
                savedIcon = mouse.Icon
                live = true
            elseif mouse.Icon ~= lastApplied then
                savedIcon = mouse.Icon
            end
            mouse.Icon = image
            lastApplied = image
        else
            restore()
        end
    end

    local function bind()
        if RunService.BindToRenderStep and RunService.UnbindFromRenderStep then
            local priority = 2001
            if Enum and Enum.RenderPriority and Enum.RenderPriority.Last then
                priority = (Enum.RenderPriority.Last.Value or 2000) + 1
            end
            local ok = pcall(function() RunService:BindToRenderStep(renderName, priority, update) end)
            if ok then return end
        end
        local event = RunService.RenderStepped or RunService.Heartbeat
        if event and event.Connect then connection = event:Connect(update) end
    end

    bind()

    return {
        set = function(value)
            assert(not destroyed, "crosshair is destroyed")
            assert(type(value) == "string", "crosshair image must be a string")
            assert(value == "" or value:match("^rbxassetid://%d+$"), "crosshair image must be empty or rbxassetid://digits")
            image = value
            update()
        end,
        destroy = function()
            if destroyed then return end
            destroyed = true
            restore()
            disconnect()
        end,
    }
end
