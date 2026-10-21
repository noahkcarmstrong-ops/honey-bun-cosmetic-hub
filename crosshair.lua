-- MM2 sheriff/hero crosshair, sized independently of the source image.
return function(game)
    local Players = game:GetService("Players")
    local Input = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    local mouse = player:GetMouse()

    local image = ""
    local live = false
    local savedIcon
    local lastApplied
    local watchers,characterWatchers={},{}
    local destroyed = false
    local savedMouseEnabled
    local size = 40
    local gui = Instance.new("ScreenGui")
    gui.Name="HoneyBunCrosshair";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=1000
    gui.Parent=player:WaitForChild("PlayerGui")
    local cursor=Instance.new("ImageLabel",gui)
    cursor.Name="Crosshair";cursor.BackgroundTransparency=1;cursor.AnchorPoint=Vector2.new(.5,.5)
    cursor.Size=UDim2.fromOffset(size,size);cursor.Visible=false

    local function disconnect()
        for _,c in ipairs(watchers)do c:Disconnect()end;watchers={}
        for _,c in ipairs(characterWatchers)do c:Disconnect()end;characterWatchers={}
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

    local updating=false
    local function update()
        if destroyed or updating then return end
        updating=true
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
        updating=false
    end

    local function bind()
        local function watchCharacter(character)
            for _,c in ipairs(characterWatchers)do c:Disconnect()end;characterWatchers={}
            if character then
                local function watch(object)
                    if object:IsA("Humanoid")then characterWatchers[#characterWatchers+1]=object.HealthChanged:Connect(update)
                    elseif object:IsA("Tool")then characterWatchers[#characterWatchers+1]=object:GetPropertyChangedSignal("Name"):Connect(update)end
                end
                for _,object in ipairs(character:GetChildren())do watch(object)end
                characterWatchers[#characterWatchers+1]=character.ChildAdded:Connect(function(object)watch(object);update()end)
                characterWatchers[#characterWatchers+1]=character.ChildRemoved:Connect(update)
            end
            update()
        end
        watchers[#watchers+1]=player.CharacterAdded:Connect(watchCharacter)
        watchers[#watchers+1]=mouse.Move:Connect(update)
        watchers[#watchers+1]=mouse:GetPropertyChangedSignal("Icon"):Connect(update)
        watchers[#watchers+1]=Input:GetPropertyChangedSignal("MouseIconEnabled"):Connect(update)
        watchCharacter(player.Character)
    end

    bind()

    return {
        setSize = function(value)
            assert(not destroyed,"crosshair is destroyed")
            assert(type(value)=="number" and value==value and value>=8 and value<=200,"Crosshair size must be between 8 and 200 pixels.")
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
