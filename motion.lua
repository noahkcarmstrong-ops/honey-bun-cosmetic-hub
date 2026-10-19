-- Local emote wheel assignments and single-animation playback.
local Http=game:GetService("HttpService")
local function assetId(value)
    if type(value)=="number" then
        assert(value>0 and value%1==0 and value<9007199254740992,"Enter a positive whole asset ID.")
        return value
    end
    value=tostring(value or ""):match("^%s*(.-)%s*$")
    local digits=value:match("^(%d+)$") or value:match("^rbxassetid://(%d+)$")
    local path=value:match("^https?://www%.roblox%.com/(.+)$") or value:match("^https?://roblox%.com/(.+)$")
        or value:match("^https?://create%.roblox%.com/(.+)$")
    if path then
        digits=path:match("^catalog/(%d+)") or path:match("^library/(%d+)")
            or path:match("^store/asset/(%d+)") or path:match("^asset/%?id=(%d+)")
    end
    local id=tonumber(digits)
    assert(id and id>0 and id<9007199254740992,"Paste a Roblox asset link or a positive numeric ID.")
    return id
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={};for key,item in pairs(value) do result[key]=copy(item) end;return result
end
return function(player,onStatus)
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticEmotes"
    local slots,original={},nil
    local alive,generation=true,0
    local track,animation,playback=nil,nil,0
    if gui then
        local ok,saved=pcall(function() return Http:JSONDecode(gui:GetAttribute(attribute) or "{}") end)
        if ok and type(saved)=="table" then
            for i=1,8 do
                local id=saved[tostring(i)]
                if type(id)=="number" and id>0 and id%1==0 and id<9007199254740992 then
                    slots[i]={id=id,name="Emote "..string.format("%.0f",id)}
                end
            end
        end
    end
    local function save()
        if not gui then return end
        local saved={}
        for slot,item in pairs(slots) do saved[tostring(slot)]=item.id end
        gui:SetAttribute(attribute,Http:JSONEncode(saved))
    end
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        assert(humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        return character,humanoid,generation
    end
    local function check(character,ticket)
        assert(alive and player.Character==character and generation==ticket,"Your avatar changed while loading. Try again.")
    end
    local function description()
        local character,humanoid=context()
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,"Roblox's emote wheel needs an R15 avatar.")
        -- CoreScripts observe this live child, not the copy from GetAppliedDescription().
        local desc=humanoid:FindFirstChildOfClass("HumanoidDescription")
        assert(desc,"This avatar has no live emote description. Wait for it to load, then retry.")
        if not original or original.description~=desc then
            original={description=desc,character=character,emotes=desc:GetEmotes(),equipped=desc:GetEquippedEmotes()}
        end
        return desc,humanoid
    end
    local function restoreWheel()
        if original and original.character==player.Character and original.description.Parent then
            original.description:SetEmotes(copy(original.emotes))
            original.description:SetEquippedEmotes(copy(original.equipped))
        end
    end
    local function applyWheel()
        local desc=description()
        local emotes,equipped=copy(original.emotes),{}
        for _,entry in ipairs(original.equipped) do
            if not slots[entry.Slot] then equipped[#equipped+1]=copy(entry) end
        end
        for slot,item in pairs(slots) do
            local name="Honey Bun Slot "..slot
            emotes[name]={item.id}
            equipped[#equipped+1]={Slot=slot,Name=name}
        end
        table.sort(equipped,function(a,b) return a.Slot<b.Slot end)
        local ok,message=pcall(function() desc:SetEmotes(emotes);desc:SetEquippedEmotes(equipped) end)
        if not ok then pcall(restoreWheel);error("Roblox could not update this emote wheel: "..tostring(message)) end
    end
    local function stop()
        playback=playback+1
        if track then pcall(function() track:Stop(0.1);track:Destroy() end) end
        if animation then animation:Destroy() end
        track,animation=nil,nil
    end
    local function slotNumber(value)
        assert(type(value)=="number" and value>=1 and value<=8 and value%1==0,"Choose a slot from 1 to 8.")
        return value
    end
    local api={}
    function api.getSlots() return copy(slots) end
    function api.setEmote(slot,value)
        slot=slotNumber(slot)
        local id=assetId(value)
        description()
        local previous=slots[slot]
        slots[slot]={id=id,name="Emote "..string.format("%.0f",id)}
        local ok,message=pcall(applyWheel)
        if not ok then slots[slot]=previous;error(message) end
        save()
        return "Assigned emote to wheel slot "..slot..". Open the Roblox wheel to use it."
    end
    function api.clearEmote(slot)
        slot=slotNumber(slot)
        local previous=slots[slot];slots[slot]=nil
        local ok,message=pcall(applyWheel)
        if not ok then slots[slot]=previous;error(message) end
        save();return "Slot "..slot.." reset to its original assignment."
    end
    function api.openWheel()
        local _,humanoid=context()
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,"Roblox's emote wheel needs an R15 avatar.")
        local starter=game:GetService("StarterGui")
        assert(starter:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu),"This game has disabled Roblox's emote wheel.")
        local ok=pcall(function() game:GetService("GuiService"):SetEmotesMenuOpen(true) end)
        assert(ok,"Roblox's emote wheel is not available yet. Try its usual menu button.")
        return "Opened the Roblox emote wheel."
    end
    function api.playEmote(slot)
        slot=slotNumber(slot);assert(slots[slot],"Assign an emote to that slot first.")
        applyWheel();stop()
        local character,humanoid,ticket=context()
        local ok,played=pcall(function() return humanoid:PlayEmoteAsync("Honey Bun Slot "..slot) end)
        check(character,ticket)
        assert(ok and played,"Roblox could not play this emote. Check its permissions and your avatar rig.")
        return "Playing emote from slot "..slot.."."
    end
    local function animationId(value)
        local id=assetId(value)
        -- Catalog emotes wrap an Animation; raw animation IDs load directly.
        local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..string.format("%.0f",id)) end)
        local resolved
        if ok and type(objects)=="table" then
            for _,root in ipairs(objects) do
                local item=root:IsA("Animation") and root or root:FindFirstChildWhichIsA("Animation",true)
                if item and item.AnimationId~="" then resolved=item.AnimationId end
            end
            for _,root in ipairs(objects) do root:Destroy() end
        end
        return resolved or ("rbxassetid://"..string.format("%.0f",id))
    end
    function api.playAnimation(value,looped,speed)
        assert(type(speed)=="number" and speed==speed and speed>=0.1 and speed<=3,"Enter a speed from 0.1 to 3.")
        assetId(value)
        local character,humanoid,ticket=context()
        local animator=humanoid:FindFirstChildOfClass("Animator")
        assert(animator,"This avatar has no animation player yet. Wait for it to load.")
        stop();local request=playback
        local id=animationId(value)
        check(character,ticket)
        assert(request==playback,"Animation request was cancelled.")
        local candidate=Instance.new("Animation");candidate.AnimationId=id
        local loaded
        local ok=pcall(function()
            loaded=animator:LoadAnimation(candidate)
            loaded.Priority=Enum.AnimationPriority.Action
            loaded.Looped=looped==true
            loaded:Play(0.1,1,speed)
        end)
        if not ok then
            if loaded then pcall(function() loaded:Destroy() end) end
            candidate:Destroy();error("Roblox could not load this animation. Check its permissions and R6/R15 rig.")
        end
        track,animation=loaded,candidate
        task.spawn(function()
            for _=1,80 do
                if not alive or request~=playback or player.Character~=character then return end
                if loaded.Length>0 then return end
                task.wait(0.1)
            end
            if alive and request==playback then
                stop()
                if onStatus then onStatus("Animation did not load. It may be restricted, unavailable, or incompatible with this game.") end
            end
        end)
        return "Animation requested. If it does not load, a message will appear here."
    end
    function api.stopAnimation() stop();return "Animation stopped." end
    function api.reapplySaved()
        if next(slots) then applyWheel() end
        return "Saved emote wheel assignments restored."
    end
    function api.restore()
        stop();restoreWheel();slots={};save();original=nil
        return "Original emote wheel restored."
    end
    local changed=player.CharacterAdded:Connect(function(character)
        generation=generation+1;local ticket=generation
        stop();original=nil
        if not next(slots) then return end
        task.spawn(function()
            for attempt=1,100 do
                if not alive or generation~=ticket or player.Character~=character then return end
                local humanoid=character:FindFirstChildOfClass("Humanoid")
                local ok,ready=pcall(function() return player:HasAppearanceLoaded() end)
                if humanoid and humanoid.Health>0 and humanoid:FindFirstChildOfClass("HumanoidDescription") and ((ok and ready) or attempt>=50) then
                    local applied,message=pcall(api.reapplySaved)
                    if not applied and onStatus then onStatus("Could not restore saved emotes: "..tostring(message)) end
                    return
                end
                task.wait(0.1)
            end
            if alive and generation==ticket and onStatus then onStatus("Emote wheel not ready. Use Reapply saved cosmetics after spawning.") end
        end)
    end)
    function api.destroy()
        if not alive then return end
        alive=false;generation=generation+1;changed:Disconnect();stop();pcall(restoreWheel);original=nil
    end
    return api
end
