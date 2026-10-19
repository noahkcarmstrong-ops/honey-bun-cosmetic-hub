-- MM2 sheriff/hero crosshair, sized independently of the source image.
return function(game)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Input = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()
    local renderName = "HoneyBunMM2Crosshair"

    local image = ""
    local live = false
    local savedIcon
    local lastApplied
    local connection
    local destroyed = false
    local savedMouseEnabled
    local size = 24
    local gui = Instance.new("ScreenGui")
    gui.Name="HoneyBunCrosshair";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=1000
    gui.Parent=player:WaitForChild("PlayerGui")
    local cursor=Instance.new("ImageLabel",gui)
    cursor.Name="Crosshair";cursor.BackgroundTransparency=1;cursor.AnchorPoint=Vector2.new(.5,.5)
    cursor.Size=UDim2.fromOffset(size,size);cursor.Visible=false

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
            Input.MouseIconEnabled=savedMouseEnabled
            cursor.Visible=false
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
                savedMouseEnabled=Input.MouseIconEnabled
                live = true
            elseif mouse.Icon ~= lastApplied then
                savedIcon = mouse.Icon
            end
            mouse.Icon = image
            lastApplied = image
            local position=Input:GetMouseLocation()
            cursor.Image=image;cursor.Position=UDim2.fromOffset(position.X,position.Y)
            cursor.Visible=true;Input.MouseIconEnabled=false
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
        setSize = function(value)
            assert(not destroyed,"crosshair is destroyed")
            assert(type(value)=="number" and value==value and value>=8 and value<=128,"Crosshair size must be between 8 and 128 pixels.")
            size=math.floor(value+.5)
            cursor.Size=UDim2.fromOffset(size,size)
        end,
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
            gui:Destroy()
        end,
    }
end
