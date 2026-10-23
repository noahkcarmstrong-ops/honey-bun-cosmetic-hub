-- Local recreation of the contest prize's historical Minifigure tool.
return function(player,onStatus)
    local alive,enabled=true,false
    local character,hat,humanoid,watchedHandle,tool,mouse,oldCursor,sparkles,sound
    local activeBurst=false
    local generation=0
    local connections,characterConnections,appearanceConnections,toolConnections={},{},{},{}
    local gilded={}
    local gold=Color3.fromRGB(255,215,0)
    local idleCursor="rbxasset://textures/GunCursor.png"
    local waitCursor="rbxasset://textures/GunWaitCursor.png"
    local function connect(signal,callback,list)list[#list+1]=signal:Connect(callback)end
    local function disconnect(list)for _,c in ipairs(list)do c:Disconnect()end;table.clear(list)end
    local function status(message)if onStatus then pcall(onStatus,message)end end
    local function matches(item)
        return (item:IsA("Accessory")or item:IsA("Hat"))and(item.Name=="SparklingHat"or item.SourceAssetId==92719239)
    end
    local function active()
        local handle=hat and hat:FindFirstChild("Handle")
        return alive and enabled and character==player.Character and hat and hat.Parent==character and handle
            and handle.Transparency<1 and(not humanoid or humanoid.Health>0)
    end
    local function cursor(value)if mouse then pcall(function()mouse.Icon=value end)end end
    local function restoreCursor()
        if mouse then pcall(function()if mouse.Icon==idleCursor or mouse.Icon==waitCursor then mouse.Icon=oldCursor or ""end end)end
        mouse=nil;oldCursor=nil
    end
    local function finish()
        generation=generation+1;activeBurst=false
        if sparkles then sparkles:Destroy();sparkles=nil end
        if sound then sound:Stop()end
        for part,original in pairs(gilded)do
            pcall(function()
                if part.Color==gold then part.Color=original.color end
                if part.Material==Enum.Material.Ice then part.Material=original.material end
            end)
        end
        table.clear(gilded)
        if tool then tool.Enabled=true end
        cursor(idleCursor)
    end
    local function clearTool()
        finish();restoreCursor();disconnect(toolConnections)
        local previous=tool;tool=nil;sound=nil
        if previous then previous:Destroy()end
    end
    local function gild(part)
        if not activeBurst or not active()or not tool or tool.Parent~=character or not part:IsA("BasePart")or part:IsDescendantOf(character)then return end
        if part.Size.X>5 or part.Size.Y>5 or part.Size.Z>5 then return end
        local ancestor=part.Parent
        while ancestor and ancestor~=workspace do
            if ancestor:IsA("Model")and ancestor:FindFirstChildOfClass("Humanoid")then return end
            ancestor=ancestor.Parent
        end
        if gilded[part]then return end
        local count=0;for _ in pairs(gilded)do count=count+1 end;if count>=32 then return end
        gilded[part]={color=part.Color,material=part.Material}
        part.Color=gold;part.Material=Enum.Material.Ice
    end
    local function createTool()
        if tool and tool.Parent then return end
        clearTool()
        local original=hat:FindFirstChild("Handle")
        local handle=original:Clone()
        -- Keep only geometry and textures; never copy scripts, welds, or constraints.
        for _,child in ipairs(handle:GetChildren())do
            if child:IsA("SpecialMesh")or child:IsA("Decal")or child:IsA("Texture")or child:IsA("SurfaceAppearance")then
                for _,descendant in ipairs(child:GetDescendants())do descendant:Destroy()end
            else child:Destroy()end
        end
        handle.Name="Handle";handle.Anchored=false;handle.CanCollide=false;handle.CanTouch=true;handle.Massless=true;handle.Transparency=0
        tool=Instance.new("Tool");tool.Name="Contest Winner Award";tool.ToolTip="Click for applause, gold sparkles, and five seconds of golden touch."
        tool.CanBeDropped=false;tool.RequiresHandle=true;handle.Parent=tool
        sound=Instance.new("Sound");sound.Name="ClapSound";sound.SoundId="rbxassetid://57908388";sound.Volume=1;sound.Parent=handle
        connect(tool.Equipped,function(equippedMouse)
            restoreCursor();mouse=equippedMouse or player:GetMouse();oldCursor=mouse and mouse.Icon
            cursor(activeBurst and waitCursor or idleCursor)
        end,toolConnections)
        connect(tool.Unequipped,function()finish();restoreCursor()end,toolConnections)
        connect(tool.Activated,function()
            if not active()or activeBurst or tool.Parent~=character then return end
            activeBurst=true;tool.Enabled=false;generation=generation+1;local token=generation
            cursor(waitCursor)
            sparkles=Instance.new("Sparkles");sparkles.Name="ContestAwardSparkles";sparkles.SparkleColor=gold;sparkles.Parent=handle
            local gui=player:FindFirstChildOfClass("PlayerGui")
            if not gui or gui:GetAttribute("HoneyBunCosmeticUI_HatSounds")~=false then sound:Play()end
            status("Contest award: golden touch active for five seconds.")
            task.delay(5,function()if alive and token==generation then finish()end end)
        end,toolConnections)
        connect(handle.Touched,gild,toolConnections)
        tool.Parent=player:FindFirstChildOfClass("Backpack")or character
    end
    local refresh
    refresh=function()
        if not alive then return end
        local nextHat,nextHumanoid
        if character and character==player.Character then
            nextHumanoid=character:FindFirstChildOfClass("Humanoid")
            for _,item in ipairs(character:GetChildren())do if matches(item)then nextHat=item;break end end
        end
        local nextHandle=nextHat and nextHat:FindFirstChild("Handle")
        if nextHat~=hat or nextHumanoid~=humanoid or nextHandle~=watchedHandle then
            clearTool();disconnect(appearanceConnections);hat=nextHat;humanoid=nextHumanoid;watchedHandle=nextHandle
            local handle=watchedHandle
            if handle then connect(handle:GetPropertyChangedSignal("Transparency"),refresh,appearanceConnections)end
            if humanoid then connect(humanoid.Died,clearTool,appearanceConnections)end
        end
        if active()then createTool()else clearTool()end
    end
    local function bind(nextCharacter)
        clearTool();disconnect(characterConnections);disconnect(appearanceConnections)
        character=nextCharacter;hat=nil;humanoid=nil;watchedHandle=nil
        if character then
            connect(character.DescendantAdded,function(item)if matches(item)or item:IsA("Humanoid")or(item.Name=="Handle"and item.Parent==hat)then refresh()end end,characterConnections)
            connect(character.DescendantRemoving,function(item)if item==hat or item==humanoid then task.defer(refresh)end end,characterConnections)
        end
        refresh()
    end
    connect(player.CharacterAdded,bind,connections);bind(player.Character)
    return {
        refresh=refresh,
        setEnabled=function(value)enabled=value==true;refresh()end,
        destroy=function()alive=false;clearTool();disconnect(connections);disconnect(characterConnections);disconnect(appearanceConnections);character=nil;hat=nil end,
    }
end
