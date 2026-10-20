-- Movement bundles for Roblox's standard R15 Animate script.
local Http=game:GetService("HttpService")
local assetStates={[48]="climb",[50]="fall",[51]="idle",[52]="jump",[53]="run",[54]="swim",[55]="walk",[56]="pose"}
local states={idle=true,walk=true,run=true,jump=true,fall=true,climb=true,swim=true,swimidle=true,pose=true}
local function bundleId(value)
    local digits=tostring(value or ""):match("^%s*(%d+)%s*$")
    local path=tostring(value or ""):match("^%s*https?://www%.roblox%.com/bundles/(%d+)")
        or tostring(value or ""):match("^%s*https?://roblox%.com/bundles/(%d+)")
    local id=tonumber(digits or path)
    assert(id and id>0 and id%1==0 and id<9007199254740992,"Paste a Roblox animation bundle link or bundle ID.")
    return id
end
return function(player,onStatus)
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticAnimationBundle"
    local savedId=gui and gui:GetAttribute(attribute)
    local savedAssets,savedComponents
    if type(savedId)=="string" then
        local ok,value=pcall(function() return Http:JSONDecode(savedId) end)
        if ok and type(value)=="table" then savedAssets=value.assets;savedId=value.bundleId end
    end
    if type(savedId)~="number" or savedId<=0 or savedId%1~=0 or savedId>=9007199254740992 then savedId=nil end
    local function validAssetType(value) return assetStates[tonumber(value)] end
    local function normalizeAssets(items)
        assert(type(items)=="table","Animation components must be an array.")
        local result={}
        for index,item in ipairs(items) do
            assert(type(item)=="table","Animation component #"..index.." is invalid.")
            local id=tonumber(item.id);local assetType=tonumber(item.assetType)
            assert(id and id>0 and id%1==0 and id<9007199254740992 and validAssetType(assetType),
                "Animation components need a valid catalog asset ID and supported assetType (48, 50-56).")
            result[#result+1]={id=id,assetType=assetType}
        end
        return result
    end
    if type(savedAssets)=="table" then
        local ok,normalized=pcall(normalizeAssets,savedAssets)
        savedAssets=ok and normalized or nil
    end
    local alive,generation=true,0
    local snapshot,cache=nil,{}
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local animate=character and character:FindFirstChild("Animate")
        assert(humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,"Roblox movement animation bundles need an R15 avatar.")
        assert(animate and animate:IsA("LocalScript") and not animate.Disabled and animate:FindFirstChild("idle")
            and animate:FindFirstChild("walk") and animate:FindFirstChild("run"),"This character does not have Roblox's standard movement animation controls ready.")
        return {character=character,humanoid=humanoid,animate=animate,generation=generation}
    end
    local function check(ctx)
        assert(alive and generation==ctx.generation and player.Character==ctx.character and ctx.humanoid.Health>0,
            "Your avatar changed while loading. Try again on the new character.")
    end
    local function restart(ctx)
        -- Reusing the existing Animator preserves normal multiplayer replication.
        local animator=ctx.humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Priority==Enum.AnimationPriority.Core or track.Priority==Enum.AnimationPriority.Idle or track.Priority==Enum.AnimationPriority.Movement then
                    track:Stop(0.1)
                end
            end
        end
        ctx.animate.Disabled=false
    end
    local function restoreCurrent()
        if not snapshot then return end
        local previous=snapshot;snapshot=nil
        if previous.character==player.Character and previous.animate.Parent then
            previous.animate.Disabled=true
            for _,folder in pairs(previous.added) do folder:Destroy() end
            for _,folder in pairs(previous.originals) do folder.Parent=previous.animate end
            restart(previous)
        else
            for _,folder in pairs(previous.originals) do folder:Destroy() end
        end
    end
    local function extractAsset(id,default,ctx)
        local loaded,roots=pcall(function() return game:GetObjects("rbxassetid://"..string.format("%.0f",id)) end)
        local extracted={}
        if loaded and type(roots)=="table" then
            for _,root in ipairs(roots) do
                local items=root:GetDescendants();table.insert(items,1,root)
                for _,node in ipairs(items) do
                    if node:IsA("Animation") and node.AnimationId~="" then
                        local parentName=node.Parent and string.lower(node.Parent.Name) or ""
                        local state=states[parentName] and parentName or default
                        if string.lower(node.Name):find("swimidle",1,true) then state="swimidle" end
                        local weight=node:FindFirstChild("Weight")
                        extracted[state]=extracted[state] or {}
                        table.insert(extracted[state],{name=node.Name,id=node.AnimationId,weight=weight and weight:IsA("NumberValue") and weight.Value or 1})
                    end
                end
            end
            for _,root in ipairs(roots) do root:Destroy() end
        end
        check(ctx);assert(next(extracted),"Roblox could not load the "..default.." animation component. Your current animations were kept.")
        return extracted
    end
    local function groupsForAssets(items,ctx)
        local groups={}
        for _,item in ipairs(items) do
            local default=assetStates[item.assetType]
            for state,entries in pairs(extractAsset(item.id,default,ctx)) do groups[state]=entries end
        end
        assert(next(groups),"These animation components contain no playable animations.")
        return groups
    end
    local function loadBundle(id,ctx)
        if cache[id] then return cache[id] end
        local ok,bundle=pcall(function()
            return Http:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",id).."/details",false))
        end)
        check(ctx)
        assert(ok and type(bundle)=="table" and type(bundle.items)=="table","Roblox could not read that animation bundle.")
        assert(bundle.bundleType=="AvatarAnimations","That is not an animation bundle. Copy a movement animation bundle link from Roblox.")
        local groups,assets={},{ }
        for _,item in ipairs(bundle.items) do
            local default=assetStates[tonumber(item.assetType)]
            if item.type=="Asset" and default then
                assets[#assets+1]={id=tonumber(item.id),assetType=tonumber(item.assetType)}
                for state,entries in pairs(extractAsset(item.id,default,ctx)) do groups[state]=entries end
            end
        end
        assert(next(groups),"This bundle has no supported movement animations.")
        local result={name=bundle.name or "Animation bundle",groups=groups,assets=assets}
        cache[id]=result;return result
    end
    local function applyGroups(groups)
        local ctx=context()
        local prepared={}
        for state,entries in pairs(groups) do
            local folder=Instance.new("Folder");folder.Name=state
            for _,entry in ipairs(entries) do
                local animation=Instance.new("Animation");animation.Name=entry.name;animation.AnimationId=entry.id;animation.Parent=folder
                local weight=Instance.new("NumberValue");weight.Name="Weight";weight.Value=entry.weight;weight.Parent=animation
            end
            prepared[state]=folder
        end
        restoreCurrent()
        snapshot={character=ctx.character,humanoid=ctx.humanoid,animate=ctx.animate,originals={},added=prepared}
        ctx.animate.Disabled=true
        local ok,message=pcall(function()
            for state,folder in pairs(prepared) do
                local old=ctx.animate:FindFirstChild(state)
                if old then snapshot.originals[state]=old;old.Parent=nil end
                folder.Parent=ctx.animate
            end
            restart(ctx)
        end)
        if not ok then pcall(restoreCurrent);error("Could not equip this movement bundle: "..tostring(message)) end
        return true
    end
    local function apply(id)
        local ctx=context();local bundle=loadBundle(id,ctx);check(ctx)
        applyGroups(bundle.groups)
        return bundle.name
    end
    local function applyAssets(items)
        local ctx=context();local groups=groupsForAssets(items,ctx);check(ctx)
        applyGroups(groups)
        return #items
    end
    local api={}
    function api.equipBundle(value)
        local id=bundleId(value)
        local name=apply(id)
        savedId=id;savedAssets=nil;savedComponents=cache[id] and cache[id].assets;if gui then gui:SetAttribute(attribute,id) end
        return "Equipped "..name..". Walk or run to try it."
    end
    function api.equipAssets(items)
        local normalized=normalizeAssets(items)
        local count=applyAssets(normalized)
        savedId=nil;savedAssets=normalized;savedComponents=normalized
        if gui then gui:SetAttribute(attribute,Http:JSONEncode({assets=normalized})) end
        return "Equipped "..count.." animation component"..(count==1 and "" or "s")..". Walk or run to try it."
    end
    function api.restore()
        restoreCurrent();savedId=nil;savedAssets=nil;savedComponents=nil;if gui then gui:SetAttribute(attribute,nil) end
        return "Original movement animations restored."
    end
    function api.reapplySaved()
        if savedAssets then return "Restored "..applyAssets(savedAssets).." animation components." end
        if savedId then return "Restored "..apply(savedId).."." end
        return "No movement animation bundle selected."
    end
    function api.getSettings()
        local source=savedAssets or savedComponents
        local assets
        if source then assets={};for i,item in ipairs(source) do assets[i]={id=item.id,assetType=item.assetType} end end
        return {bundleId=savedId,assets=assets}
    end
    local changed=player.CharacterAdded:Connect(function(character)
        generation=generation+1;local ticket=generation
        restoreCurrent()
        if not savedId and not savedAssets then return end
        task.spawn(function()
            for attempt=1,100 do
                if not alive or generation~=ticket or player.Character~=character or (not savedId and not savedAssets) then return end
                local ready=pcall(context)
                local ok,appearance=pcall(function() return player:HasAppearanceLoaded() end)
                if ready and ((ok and appearance) or attempt>=50) then
                    local applied,message=pcall(api.reapplySaved)
                    if not applied and onStatus then onStatus("Could not restore animation bundle: "..tostring(message)) end
                    return
                end
                task.wait(0.1)
            end
            if alive and generation==ticket and onStatus then onStatus("Movement controls not ready. Use Reapply saved cosmetics after spawning.") end
        end)
    end)
    function api.destroy()
        if not alive then return end
        alive=false;generation=generation+1;changed:Disconnect();pcall(restoreCurrent)
    end
    return api
end
