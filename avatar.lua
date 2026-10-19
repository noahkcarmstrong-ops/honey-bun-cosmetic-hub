-- Local appearance only. No character replacement, remotes, or game detection.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local groups={
    Head={"Head"},Torso={"Torso","UpperTorso","LowerTorso"},
    LeftArm={"Left Arm","LeftUpperArm","LeftLowerArm","LeftHand"},
    RightArm={"Right Arm","RightUpperArm","RightLowerArm","RightHand"},
    LeftLeg={"Left Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot"},
    RightLeg={"Right Leg","RightUpperLeg","RightLowerLeg","RightFoot"},
}
local r15={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand",
    "RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot",
    "RightUpperLeg","RightLowerLeg","RightFoot"}
local outfits={Girl=131929545,["Robloxian 2.0"]=131929576}
local function idFrom(value,kind)
    value=tostring(value or ""):match("^%s*(.-)%s*$")
    local id=value:match("^(%d+)$")
    if not id then
        local path=value:match("^https?://www%.roblox%.com/(.+)$") or value:match("^https?://roblox%.com/(.+)$")
        if path then id=path:match("^"..kind.."/(%d+)") end
    end
    if kind=="catalog" and not id then id=value:match("^rbxassetid://(%d+)$") end
    local number=tonumber(id)
    assert(number and number>0 and number<9007199254740992,"Paste a Roblox "..kind.." link or a positive numeric ID.")
    return number
end
local function strip(root)
    for _,item in ipairs(root:GetDescendants()) do if item:IsA("LuaSourceContainer") then item:Destroy() end end
end
local function dispose(list)
    for _,item in ipairs(list) do item:Destroy() end
end
local function bodyClone(part)
    local clone=part:Clone()
    assert(clone,"This avatar's body cannot be copied.")
    strip(clone)
    for _,item in ipairs(clone:GetDescendants()) do if item:IsA("JointInstance") then item:Destroy() end end
    return clone
end
return function(player)
    local alive,generation=true,0
    local snapshot,added,skin=nil,{},{}
    local nextKey=0
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local c=player.Character
        local humanoid=c and c:FindFirstChildOfClass("Humanoid")
        assert(c and humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        return {character=c,humanoid=humanoid,generation=generation}
    end
    local function valid(ctx)
        return alive and generation==ctx.generation and player.Character==ctx.character
            and ctx.humanoid.Parent==ctx.character and ctx.humanoid.Health>0
    end
    local function check(ctx)
        assert(valid(ctx),"Your avatar changed while loading. Try again on the new character.")
    end
    local function forget()
        if snapshot then
            dispose(snapshot.meshes)
            for _,part in pairs(snapshot.parts) do part:Destroy() end
        end
        snapshot=nil;added={};skin={}
    end
    local function capture(ctx,body)
        if not snapshot then
            local saved={character=ctx.character,colors={},bodyColors={},meshes={},parts={},bodyChanged=false}
            for _,item in ipairs(ctx.character:GetChildren()) do
                if item:IsA("BasePart") and item.Name~="HumanoidRootPart" then
                    saved.colors[item.Name]=item.Color
                elseif item:IsA("CharacterMesh") then table.insert(saved.meshes,item:Clone())
                elseif item:IsA("BodyColors") then
                    saved.hadBodyColors=true
                    for region in pairs(groups) do saved.bodyColors[region]=item[region.."Color3"] end
                end
            end
            snapshot=saved
        end
        if body and ctx.humanoid.RigType==Enum.HumanoidRigType.R15 and not next(snapshot.parts) then
            local copies={}
            local ok,message=pcall(function()
                for _,name in ipairs(r15) do
                    local part=ctx.character:FindFirstChild(name)
                    assert(part and part:IsA("BasePart"),"This character does not use a standard R15 body.")
                    copies[name]=bodyClone(part)
                end
            end)
            if not ok then for _,part in pairs(copies) do part:Destroy() end;error(message) end
            snapshot.parts=copies
        end
    end
    local function paint(c,color,region)
        local colors=c:FindFirstChildOfClass("BodyColors")
        if not colors then
            colors=Instance.new("BodyColors")
            for group,names in pairs(groups) do
                for _,name in ipairs(names) do
                    local part=c:FindFirstChild(name)
                    if part and part:IsA("BasePart") then colors[group.."Color3"]=part.Color;break end
                end
            end
            colors.Parent=c
        end
        for group,names in pairs(groups) do
            if region=="All" or region==group then
                colors[group.."Color3"]=color
                for _,name in ipairs(names) do
                    local part=c:FindFirstChild(name)
                    if part and part:IsA("BasePart") then part.Color=color end
                end
            end
        end
    end
    local function attach(accessory,c)
        local handle=accessory:FindFirstChild("Handle")
        assert(handle and handle:IsA("BasePart"),"This accessory has no wearable Handle.")
        assert(not accessory:FindFirstChildWhichIsA("WrapLayer",true),"Layered clothing needs Roblox's avatar system. Try a rigid hat, mask, or hair accessory.")
        local target,bodyAttachment,handleAttachment
        for _,a in ipairs(handle:GetChildren()) do
            if a:IsA("Attachment") then
                for _,part in ipairs(c:GetChildren()) do
                    if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
                        local b=part:FindFirstChild(a.Name)
                        if b and b:IsA("Attachment") then target,bodyAttachment,handleAttachment=part,b,a;break end
                    end
                end
            end
            if target then break end
        end
        local c0,c1
        if target then c0,c1=handleAttachment.CFrame,bodyAttachment.CFrame
        else
            assert(not handle:FindFirstChildWhichIsA("Attachment"),"This accessory has no matching attachment on your avatar.")
            target=c:FindFirstChild("Head")
            assert(target,"This avatar has no Head for a legacy hat.")
            c0,c1=accessory.AttachmentPoint,CFrame.new(0,0.5,0)
        end
        for _,item in ipairs(handle:GetChildren()) do
            if item:IsA("JointInstance") or item:IsA("WeldConstraint") then item:Destroy() end
        end
        handle.CFrame=target.CFrame*c1*c0:Inverse()
        local weld=Instance.new("Weld")
        weld.Name,weld.Part0,weld.Part1="AccessoryWeld",handle,target
        weld.C0,weld.C1=c0,c1
        weld.Parent=handle
    end
    local function reattach(c)
        for _,item in ipairs(c:GetChildren()) do
            if item:IsA("Accessory") or item:IsA("Hat") then pcall(attach,item,c) end
        end
    end
    local function replaceParts(ctx,parts)
        for _,name in ipairs(r15) do
            assert(parts[name] and ctx.character:FindFirstChild(name),"This package does not contain a complete R15 body.")
        end
        local backups,changed={},{}
        for _,name in ipairs(r15) do backups[name]=bodyClone(ctx.character:FindFirstChild(name)) end
        local ok,err=pcall(function()
            for _,name in ipairs(r15) do
                local target=ctx.character:FindFirstChild(name)
                local clone=bodyClone(parts[name])
                clone.CFrame,clone.Color=target.CFrame,target.Color
                clone.Anchored,clone.CanCollide,clone.Massless=target.Anchored,target.CanCollide,target.Massless
                clone.Transparency=target.Transparency
                local success,result=pcall(function() return ctx.humanoid:ReplaceBodyPartR15(Enum.BodyPartR15[name],clone) end)
                if not success or not result then clone:Destroy();error("Roblox blocked replacing "..name.." on this avatar.") end
                table.insert(changed,name)
            end
        end)
        if not ok then
            for i=#changed,1,-1 do
                local name=changed[i]
                local backup=backups[name]:Clone()
                local restored,result=pcall(function() return ctx.humanoid:ReplaceBodyPartR15(Enum.BodyPartR15[name],backup) end)
                if not restored or not result then backup:Destroy() end
            end
        end
        for _,part in pairs(backups) do part:Destroy() end
        reattach(ctx.character)
        assert(ok,err)
    end
    local api={}
    function api.equipAccessory(value)
        local ctx=context()
        local id=idFrom(value,"catalog")
        assert(#added<20,"Remove an added accessory before adding more (20 maximum).")
        local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..string.format("%.0f",id)) end)
        assert(ok and type(objects)=="table" and #objects>0,"Roblox could not load that accessory. It may be private or unavailable.")
        if not valid(ctx) then dispose(objects);check(ctx) end
        local accessory
        for _,root in ipairs(objects) do
            strip(root)
            if root:IsA("Accessory") or root:IsA("Hat") then accessory=root;break end
            for _,item in ipairs(root:GetDescendants()) do
                if item:IsA("Accessory") or item:IsA("Hat") then accessory=item;break end
            end
            if accessory then break end
        end
        if not accessory then dispose(objects);error("That item is not a wearable accessory. Use a hat, mask, or hair catalog link.") end
        local candidate=accessory:Clone()
        dispose(objects)
        strip(candidate)
        for _,item in ipairs(candidate:GetDescendants()) do
            if item:IsA("BasePart") then item.Anchored=false;item.CanCollide=false;item.CanTouch=false;item.Massless=true end
        end
        local fitted,message=pcall(attach,candidate,ctx.character)
        if not fitted then candidate:Destroy();error(message) end
        capture(ctx)
        candidate.Parent=ctx.character
        nextKey=nextKey+1
        table.insert(added,{key=nextKey,id=id,name=candidate.Name,object=candidate})
        return "Equipped "..candidate.Name.." (visible to you)."
    end
    function api.listAccessories()
        local list={}
        for _,entry in ipairs(added) do
            if entry.object.Parent==player.Character then table.insert(list,{key=entry.key,id=entry.id,name=entry.name}) end
        end
        return list
    end
    function api.removeAccessory(key)
        for i,entry in ipairs(added) do
            if entry.key==key then entry.object:Destroy();table.remove(added,i);return "Removed "..entry.name.."." end
        end
        error("That added accessory is no longer equipped.")
    end
    function api.clearAccessories()
        for _,entry in ipairs(added) do entry.object:Destroy() end
        added={}
        return "Removed accessories added by this hub."
    end
    function api.setSkin(color,region)
        local ctx=context();region=region or "All"
        assert(region=="All" or groups[region],"Choose a body region.")
        capture(ctx)
        if region=="All" then skin={} end
        skin[region]=color
        paint(ctx.character,color,region)
        return "Skin color applied (visible to you)."
    end
    function api.applyBody(value)
        local ctx=context()
        local isR6=ctx.humanoid.RigType==Enum.HumanoidRigType.R6
        if value=="Blocky" and isR6 then
            capture(ctx)
            for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
            snapshot.bodyChanged=true
            return "Blocky body applied (visible to you)."
        end
        local outfit=outfits[value]
        if value~="Blocky" and not outfit then
            local id=idFrom(value,"bundles")
            local ok,bundle=pcall(function()
                return Http:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",id).."/details",false))
            end)
            check(ctx)
            assert(ok and type(bundle)=="table" and type(bundle.items)=="table","Roblox could not read that body bundle.")
            for _,item in ipairs(bundle.items) do if item.type=="UserOutfit" then outfit=tonumber(item.id);break end end
            assert(outfit,"That bundle has no avatar body outfit. Choose a character body bundle.")
        end
        local description=Instance.new("HumanoidDescription")
        if outfit then
            local ok,source=pcall(function() return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfit) end)
            if not valid(ctx) then description:Destroy();if ok and source then source:Destroy() end;check(ctx) end
            if not ok or not source then description:Destroy();error("Roblox could not load this package's body description.") end
            for _,name in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","BodyTypeScale","ProportionScale"}) do description[name]=source[name] end
            source:Destroy()
        end
        local ok,template=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description,ctx.humanoid.RigType) end)
        description:Destroy()
        if not valid(ctx) then if ok and template then template:Destroy() end;check(ctx) end
        assert(ok and template,"Roblox blocked generating this body package in this client.")
        strip(template)
        local applied,message=pcall(function()
            if isR6 then
                local meshes={}
                for _,item in ipairs(template:GetChildren()) do if item:IsA("CharacterMesh") then table.insert(meshes,item) end end
                assert(#meshes>0,"This package has no compatible R6 body meshes. Try an R15 game.")
                capture(ctx)
                for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
                for _,mesh in ipairs(meshes) do mesh:Clone().Parent=ctx.character end
            else
                local parts={}
                for _,name in ipairs(r15) do
                    local part=template:FindFirstChild(name)
                    if part and part:IsA("BasePart") then parts[name]=part end
                end
                capture(ctx,true)
                replaceParts(ctx,parts)
            end
            snapshot.bodyChanged=true
            if skin.All then paint(ctx.character,skin.All,"All") end
            for region,color in pairs(skin) do if region~="All" then paint(ctx.character,color,region) end end
        end)
        template:Destroy()
        assert(applied,message)
        return "Body package applied (visible to you)."
    end
    function api.restore()
        local ctx=context()
        api.clearAccessories()
        if not snapshot or snapshot.character~=ctx.character then return "Nothing to restore on this character." end
        if snapshot.bodyChanged then
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then replaceParts(ctx,snapshot.parts)
            else
                for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
                for _,mesh in ipairs(snapshot.meshes) do mesh:Clone().Parent=ctx.character end
            end
            snapshot.bodyChanged=false
        end
        local colors=ctx.character:FindFirstChildOfClass("BodyColors")
        if colors then
            if snapshot.hadBodyColors then
                for region,color in pairs(snapshot.bodyColors) do colors[region.."Color3"]=color end
            else colors:Destroy() end
        end
        for name,color in pairs(snapshot.colors) do
            local part=ctx.character:FindFirstChild(name)
            if part and part:IsA("BasePart") then part.Color=color end
        end
        skin={}
        return "Original appearance restored."
    end
    local changed=player.CharacterAdded:Connect(function() generation=generation+1;forget() end)
    function api.destroy()
        if not alive then return end
        generation=generation+1
        changed:Disconnect()
        if snapshot and snapshot.character==player.Character then pcall(api.restore) end
        forget();alive=false
    end
    return api
end
