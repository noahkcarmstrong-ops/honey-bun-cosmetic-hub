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
local bodyRegions={Head=true,Torso=true,LeftArm=true,RightArm=true,LeftLeg=true,RightLeg=true}
local function regionNames(region)
    if region=="Head" then return {"Head"} end
    local names=groups[region];local out={}
    for i=2,#names do out[#out+1]=names[i] end
    return out
end
local function idFrom(value,kind)
    if type(value)=="number" then
        assert(value>0 and value%1==0 and value<9007199254740992,"Enter a positive numeric ID.")
        return value
    end
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
return function(player,onStatus)
    local alive,generation=true,0
    local snapshot,added,skin,hidden=nil,{},{},{}
    local accountAccessoryNames
    local nextKey=0
    local playerGui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticSettings"
    local settings={accessories={},colors={},bodyParts={},hideOriginals=false}
    local reapplying,replayGeneration,replayToken=false,nil,0
    local function copySettings()
        local copy={accessories={},colors={},bodyParts={},hideOriginals=settings.hideOriginals,body=settings.body}
        for i,id in ipairs(settings.accessories) do copy.accessories[i]=id end
        for region,color in pairs(settings.colors) do copy.colors[region]={color[1],color[2],color[3]} end
        for region,value in pairs(settings.bodyParts) do copy.bodyParts[region]=value end
        return copy
    end
    if playerGui then
        local ok,saved=pcall(function()
            local value=playerGui:GetAttribute(attribute)
            return value and Http:JSONDecode(value)
        end)
        if ok and type(saved)=="table" then
            settings.hideOriginals=saved.hideOriginals==true
            if type(saved.body)=="string" then settings.body=saved.body end
            if type(saved.bodyParts)=="table" then
                for region,value in pairs(saved.bodyParts) do
                    if bodyRegions[region] and ((type(value)=="number" and value>0 and value%1==0 and value<9007199254740992)
                        or (type(value)=="string" and #value<=8192)) then settings.bodyParts[region]=value end
                end
            end
            if type(saved.accessories)=="table" then
                for _,id in ipairs(saved.accessories) do
                    if type(id)=="number" and id>0 and id%1==0 and id<9007199254740992 and #settings.accessories<20 then
                        table.insert(settings.accessories,id)
                    end
                end
            end
            if type(saved.colors)=="table" then
                for region,color in pairs(saved.colors) do
                    if (region=="All" or groups[region]) and type(color)=="table" then
                        local validColor=true
                        for i=1,3 do if type(color[i])~="number" or color[i]~=color[i] or color[i]<0 or color[i]>1 then validColor=false end end
                        if validColor then settings.colors[region]={color[1],color[2],color[3]} end
                    end
                end
            end
        end
    end
    local function save()
        if reapplying or not playerGui then return end
        playerGui:SetAttribute(attribute,Http:JSONEncode(settings))
    end
    local function notify(message,working)
        if alive and onStatus then onStatus(message,working) end
    end
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
    local function showOriginalAccessories()
        for _,entry in ipairs(hidden) do
            for part,properties in pairs(entry.parts) do
                for property,value in pairs(properties) do pcall(function() part[property]=value end) end
            end
        end
        hidden={}
    end
    local function forget()
        showOriginalAccessories()
        if snapshot then
            dispose(snapshot.meshes)
            for _,part in pairs(snapshot.parts) do part:Destroy() end
        end
        snapshot=nil;added={};skin={};hidden={}
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
            snapshot.joints={}
            local bodyParts={[ctx.character:FindFirstChild("HumanoidRootPart") or ctx.character]=true}
            for _,name in ipairs(r15) do bodyParts[ctx.character:FindFirstChild(name)]=true end
            for _,joint in ipairs(ctx.character:GetDescendants()) do
                if joint:IsA("Motor6D") and bodyParts[joint.Part0] and bodyParts[joint.Part1] then
                    snapshot.joints[joint]={C0=joint.C0,C1=joint.C1}
                end
            end
            snapshot.hipHeight=ctx.humanoid.HipHeight
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
    local function applyPartAppearance(target,source)
        if target:IsA("MeshPart") and source:IsA("MeshPart") then
            target:ApplyMesh(source)
            if source.Size then target.Size=source.Size end
        elseif target:IsA("Part") and (source:IsA("Part") or source:IsA("MeshPart")) then
            local prepared={}
            if source:IsA("MeshPart") then
                local bounds=source.MeshSize
                assert(bounds and bounds.X>0 and bounds.Y>0 and bounds.Z>0,"This head has no usable mesh dimensions.")
                local mesh=Instance.new("SpecialMesh")
                mesh.MeshType=Enum.MeshType.FileMesh;mesh.MeshId=source.MeshId;mesh.TextureId=source.TextureID
                local size=source.Size or target.Size
                mesh.Scale=Vector3.new(size.X/bounds.X,size.Y/bounds.Y,size.Z/bounds.Z)
                prepared[1]=mesh
            else
                for _,item in ipairs(source:GetChildren()) do if item:IsA("SpecialMesh") then prepared[#prepared+1]=item:Clone() end end
            end
            for _,item in ipairs(target:GetChildren()) do if item:IsA("SpecialMesh") then item:Destroy() end end
            for _,item in ipairs(prepared) do item.Parent=target end
            if source.Size then target.Size=source.Size end
            if source:IsA("Part") then target.Shape=source.Shape end
        else
            error("This body part cannot be changed safely on this avatar. Your gear was left alone.")
        end
        for _,attachment in ipairs(source:GetChildren()) do
            if attachment:IsA("Attachment") and attachment.Name:match("RigAttachment$") then
                local existing=target:FindFirstChild(attachment.Name)
                if existing and existing:IsA("Attachment") then existing.CFrame=attachment.CFrame end
            end
        end
    end
    local function fitBodyJoints(ctx,names)
        local bodyParts,affected={},{}
        for _,name in ipairs(names) do affected[ctx.character:FindFirstChild(name)]=true end
        for _,name in ipairs(r15) do bodyParts[ctx.character:FindFirstChild(name) or ctx.character]=true end
        bodyParts[ctx.character:FindFirstChild("HumanoidRootPart") or ctx.character]=true
        for _,joint in ipairs(ctx.character:GetDescendants()) do
            if joint:IsA("Motor6D") and bodyParts[joint.Part0] and bodyParts[joint.Part1] and (affected[joint.Part0] or affected[joint.Part1]) then
                local attachmentName=(joint.Name=="RootJoint" and "Root" or joint.Name).."RigAttachment"
                for _,attachment in ipairs(joint.Part0:GetChildren()) do
                    if attachment:IsA("Attachment") and attachment.Name==attachmentName then
                        local other=joint.Part1:FindFirstChild(attachment.Name)
                        if other and other:IsA("Attachment") then
                            joint.C0,joint.C1=attachment.CFrame,other.CFrame
                            break
                        end
                    end
                end
            end
        end
    end
    local function replaceParts(ctx,parts,names)
        names=names or r15
        for _,name in ipairs(names) do
            local target=ctx.character:FindFirstChild(name)
            assert(parts[name] and parts[name]:IsA("BasePart") and target and target:IsA("BasePart"),"This package does not contain the selected R15 body part.")
        end
        local backups,changed,joints={},{},{}
        for _,joint in ipairs(ctx.character:GetDescendants()) do
            if joint:IsA("Motor6D") then joints[joint]={C0=joint.C0,C1=joint.C1} end
        end
        for _,name in ipairs(names) do backups[name]=bodyClone(ctx.character:FindFirstChild(name)) end
        local ok,err=pcall(function()
            for _,name in ipairs(names) do
                local target=ctx.character:FindFirstChild(name)
                -- Keep the actual limb, attachments, RightGrip, and game controllers.
                -- ApplyMesh changes appearance without destroying the gear-holding part.
                table.insert(changed,name)
                local success,message=pcall(applyPartAppearance,target,parts[name])
                if not success then error("Roblox blocked changing "..name.." safely: "..tostring(message)) end
            end
            fitBodyJoints(ctx,names)
        end)
        if not ok then
            for i=#changed,1,-1 do
                local name=changed[i]
                local target=ctx.character:FindFirstChild(name)
                pcall(applyPartAppearance,target,backups[name])
            end
            for joint,offset in pairs(joints) do joint.C0,joint.C1=offset.C0,offset.C1 end
        end
        for _,part in pairs(backups) do part:Destroy() end
        assert(ok,err)
    end
    local function restoreBodyParts(ctx)
        replaceParts(ctx,snapshot.parts)
        for joint,offset in pairs(snapshot.joints or {}) do
            if joint.Parent then joint.C0,joint.C1=offset.C0,offset.C1 end
        end
        if snapshot.hipHeight~=nil then ctx.humanoid.HipHeight=snapshot.hipHeight end
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
        if not reapplying then table.insert(settings.accessories,id);save() end
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
            if entry.key==key then
                entry.object:Destroy();table.remove(added,i)
                if not reapplying then
                    for index,id in ipairs(settings.accessories) do if id==entry.id then table.remove(settings.accessories,index);break end end
                    save()
                end
                return "Removed "..entry.name.."."
            end
        end
        error("That added accessory is no longer equipped.")
    end
    local function clearAdded()
        for _,entry in ipairs(added) do entry.object:Destroy() end
        added={}
    end
    function api.clearAccessories()
        clearAdded()
        if not reapplying then settings.accessories={};save() end
        return "Removed accessories added by this hub."
    end
    local function attachedToAvatar(item,c)
        local handle=item:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then return false end
        local attachmentParts={
            HatAttachment={"Head"},HairAttachment={"Head"},FaceFrontAttachment={"Head"},FaceCenterAttachment={"Head"},
            NeckAttachment={"UpperTorso","Torso"},BodyBackAttachment={"UpperTorso","Torso"},BodyFrontAttachment={"UpperTorso","Torso"},
            LeftCollarAttachment={"UpperTorso","Torso"},RightCollarAttachment={"UpperTorso","Torso"},
            LeftShoulderAttachment={"LeftUpperArm","Left Arm"},RightShoulderAttachment={"RightUpperArm","Right Arm"},
            WaistFrontAttachment={"LowerTorso","Torso"},WaistCenterAttachment={"LowerTorso","Torso"},WaistBackAttachment={"LowerTorso","Torso"},
        }
        for _,child in ipairs(handle:GetChildren()) do
            if child:IsA("Attachment") then
                for _,name in ipairs(attachmentParts[child.Name] or {}) do
                    local part=c:FindFirstChild(name)
                    local matching=part and part:IsA("BasePart") and part:FindFirstChild(child.Name)
                    if matching and matching:IsA("Attachment") then return true end
                end
            elseif child:IsA("JointInstance") and child.Name=="AccessoryWeld" then
                local head=c:FindFirstChild("Head")
                if head and ((child.Part0==handle and child.Part1==head) or (child.Part1==handle and child.Part0==head)) then return true end
            end
        end
        return false
    end
    function api.removeCurrentAccessories()
        local ctx=context()
        capture(ctx)
        local hubAdded={}
        for _,entry in ipairs(added) do hubAdded[entry.object]=true end
        local avatarIds,avatarInstances={},{}
        local liveDescription=ctx.humanoid:FindFirstChildOfClass("HumanoidDescription")
        if liveDescription then
            for _,entry in ipairs(liveDescription:GetChildren()) do
                if entry:IsA("AccessoryDescription") then
                    local found,instance=pcall(function() return entry:GetAppliedInstance() end)
                    if found and instance and instance.Parent==ctx.character then avatarInstances[instance]=true end
                end
            end
        end
        local ok,description=pcall(function() return ctx.humanoid:GetAppliedDescription() end)
        if ok and description then
            local read,entries=pcall(function() return description:GetAccessories(true) end)
            if read then for _,entry in ipairs(entries) do avatarIds[entry.AssetId]=true end end
            description:Destroy()
        end
        -- Some games omit applied accessory instances, and SourceAssetId is restricted.
        -- Use trusted account accessory names as a fallback, never arbitrary game gear.
        if not accountAccessoryNames and type(player.UserId)=="number" then
            local loaded,appearance=pcall(function() return Players:GetCharacterAppearanceInfoAsync(player.UserId) end)
            check(ctx)
            if loaded and type(appearance)=="table" and type(appearance.assets)=="table" then
                accountAccessoryNames={}
                local types={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[76]=true,[77]=true}
                for _,asset in ipairs(appearance.assets) do
                    if type(asset)=="table" and type(asset.assetType)=="table" and types[asset.assetType.id] and type(asset.name)=="string" then
                        accountAccessoryNames[asset.name]=true
                    end
                end
            end
        end
        local alreadyHidden={}
        for _,entry in ipairs(hidden) do alreadyHidden[entry.object]=true end
        for _,item in ipairs(ctx.character:GetChildren()) do
            local identified,id=pcall(function() return item.SourceAssetId end)
            if (item:IsA("Accessory") or item:IsA("Hat")) and not hubAdded[item] and not alreadyHidden[item] and (avatarInstances[item] or (identified and avatarIds[id]) or (accountAccessoryNames and accountAccessoryNames[item.Name]) or attachedToAvatar(item,ctx.character)) then
                local entry={object=item,parts={}}
                for _,part in ipairs(item:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                        entry.parts[part]={Transparency=part.Transparency or 0};part.Transparency=1
                    elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") or part:IsA("Light") or part:IsA("Fire") or part:IsA("Smoke") or part:IsA("Sparkles") then
                        entry.parts[part]={Enabled=part.Enabled==true};part.Enabled=false
                    end
                end
                table.insert(hidden,entry)
            end
        end
        -- Repeated clicks also re-hide originals if the game changed their visibility.
        for _,entry in ipairs(hidden) do
            for part,properties in pairs(entry.parts) do
                pcall(function()
                    if properties.Transparency~=nil then part.Transparency=1 end
                    if properties.Enabled~=nil then part.Enabled=false end
                end)
            end
        end
        if not reapplying then settings.hideOriginals=true;save() end
        return #hidden==0 and "No identified Roblox avatar accessories to hide. Game equipment was left alone." or "Hidden "..#hidden.." Roblox accessories. Restore original appearance brings them back."
    end
    function api.accessoryReport()
        local ctx=context()
        local lines={"Honey Bun Cosmetic Hub accessory report","Build: avatar attachment detection V3","Hide originals saved: "..tostring(settings.hideOriginals),"Tracked hidden accessories: "..#hidden}
        local owned={};for _,entry in ipairs(added) do owned[entry.object]=true end
        for _,item in ipairs(ctx.character:GetChildren()) do
            if item:IsA("Accessory") or item:IsA("Hat") then
                local details={item.Name.." ["..item.ClassName.."]", "hub="..tostring(owned[item]==true),"avatar match="..tostring(attachedToAvatar(item,ctx.character))}
                local handle=item:FindFirstChild("Handle")
                if handle then
                    details[#details+1]="transparency="..tostring(handle.Transparency)
                    for _,child in ipairs(handle:GetChildren()) do
                        if child:IsA("Attachment") then details[#details+1]="attachment="..child.Name end
                    end
                else details[#details+1]="Handle missing" end
                lines[#lines+1]=table.concat(details,"; ")
            end
        end
        return table.concat(lines,"\n")
    end
    function api.setSkin(color,region)
        local ctx=context();region=region or "All"
        assert(region=="All" or groups[region],"Choose a body region.")
        capture(ctx)
        if region=="All" then skin={} end
        skin[region]=color
        paint(ctx.character,color,region)
        if not reapplying then
            if region=="All" then settings.colors={} end
            settings.colors[region]={color.R,color.G,color.B};save()
        end
        return "Skin color applied (visible to you)."
    end
    function api.applyBody(value)
        local ctx=context()
        local isR6=ctx.humanoid.RigType==Enum.HumanoidRigType.R6
        if value=="Blocky" and isR6 then
            capture(ctx)
            for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
            snapshot.bodyChanged=true
            if not reapplying then settings.body=value;save() end
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
                local generatedHumanoid=template:FindFirstChildOfClass("Humanoid")
                if generatedHumanoid and generatedHumanoid.HipHeight~=nil then ctx.humanoid.HipHeight=generatedHumanoid.HipHeight end
            end
            snapshot.bodyChanged=true
            if skin.All then paint(ctx.character,skin.All,"All") end
            for region,color in pairs(skin) do if region~="All" then paint(ctx.character,color,region) end end
        end)
        template:Destroy()
        assert(applied,message)
        if not reapplying then settings.body=value;settings.bodyParts={};save() end
        return "Body package applied (visible to you)."
    end
    function api.applyBodyPart(region,value)
        local ctx=context()
        assert(ctx.humanoid.RigType==Enum.HumanoidRigType.R15,"Individual body parts are only supported on R15 avatars.")
        assert(bodyRegions[region],"Choose a body region.")
        local field=region;local names=regionNames(region)
        local text=tostring(value or ""):match("^%s*(.-)%s*$")
        local isBundle=text:match("^https?://[^/]+/bundles/%d+") ~= nil
        local id
        if not isBundle then id=idFrom(value,"catalog") end
        if isBundle then
            local bundleId=idFrom(text,"bundles")
            local ok,bundle=pcall(function()
                return Http:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",bundleId).."/details",false))
            end)
            check(ctx)
            assert(ok and type(bundle)=="table" and type(bundle.items)=="table","Roblox could not read that body bundle.")
            assert(bundle.bundleType=="BodyParts" or bundle.bundleType=="DynamicHead","Choose a body or head bundle, rather than an animation bundle.")
            local outfit
            for _,item in ipairs(bundle.items) do
                if item.type=="UserOutfit" and tonumber(item.id) then outfit=tonumber(item.id);break end
            end
            assert(outfit,"That bundle does not contain a usable body outfit.")
            local loaded,source=pcall(function() return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfit) end)
            if not valid(ctx) then if loaded and source then source:Destroy() end;check(ctx) end
            assert(loaded and source,"Roblox could not load that body bundle.")
            local selected=source[field]
            source:Destroy()
            assert(type(selected)=="number" and selected>0,"That bundle has no selected "..region..".")
            id=selected
        else
            local service=game:GetService("MarketplaceService")
            local ok,info=pcall(function() return service:GetProductInfoAsync(id,Enum.InfoType.Asset) end)
            check(ctx)
            assert(ok and type(info)=="table" and info.AssetTypeId, "Roblox could not validate that catalog asset.")
            local expected={Head={[17]=true,[79]=true},Torso={[27]=true},RightArm={[28]=true},LeftArm={[29]=true},LeftLeg={[30]=true},RightLeg={[31]=true}}
            assert(expected[region][info.AssetTypeId],"That catalog item is not a "..region.." body part.")
        end
        local description=Instance.new("HumanoidDescription")
        description[field]=id
        local ok,template=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description,ctx.humanoid.RigType) end)
        description:Destroy()
        if not valid(ctx) then if ok and template then template:Destroy() end;check(ctx) end
        assert(ok and template,"Roblox blocked generating that body part.")
        strip(template)
        local parts={}
        for _,name in ipairs(names) do local part=template:FindFirstChild(name);if part and part:IsA("BasePart") then parts[name]=part end end
        local applied,message=pcall(function() capture(ctx,true);replaceParts(ctx,parts,names) end)
        template:Destroy()
        assert(applied,message)
        snapshot.bodyChanged=true
        if not reapplying then settings.bodyParts[region]=value;save() end
        return region.." body part applied (visible to you)."
    end
    local function restoreSkinAppearance(ctx)
        if not snapshot or snapshot.character~=ctx.character then skin={};return false end
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
        return true
    end
    local function restoreAppearance(keepOriginalsHidden)
        local ctx=context()
        clearAdded()
        if not snapshot or snapshot.character~=ctx.character then return "Nothing to restore on this character." end
        if not keepOriginalsHidden then showOriginalAccessories() end
        if snapshot.bodyChanged then
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then restoreBodyParts(ctx)
            else
                for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
                for _,mesh in ipairs(snapshot.meshes) do mesh:Clone().Parent=ctx.character end
            end
            snapshot.bodyChanged=false
        end
        restoreSkinAppearance(ctx)
        return "Original appearance restored."
    end
    function api.restoreSkin()
        local ctx=context()
        restoreSkinAppearance(ctx)
        settings.colors={};save()
        return "Original skin restored."
    end
    function api.restoreBody()
        local ctx=context()
        if snapshot and snapshot.character==ctx.character and snapshot.bodyChanged then
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then restoreBodyParts(ctx)
            else
                for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
                for _,mesh in ipairs(snapshot.meshes) do mesh:Clone().Parent=ctx.character end
            end
            snapshot.bodyChanged=false
        end
        settings.body=nil;settings.bodyParts={};save()
        return "Original body restored."
    end
    function api.restore()
        local message=restoreAppearance()
        settings={accessories={},colors={},bodyParts={},hideOriginals=false};save()
        return message
    end
    function api.getSettings() return copySettings() end
    local operations={}
    for _,name in ipairs({"equipAccessory","removeAccessory","clearAccessories","removeCurrentAccessories","setSkin","applyBody","applyBodyPart","restoreSkin","restoreBody","restore"}) do
        local operation=api[name]
        operations[name]=operation
        api[name]=function(...)
            assert(not reapplying,"Wait for saved cosmetics to finish restoring.")
            return operation(...)
        end
    end
    function api.reapplySaved()
        local ctx=context()
        if reapplying and replayGeneration==generation then return "Saved cosmetics are already restoring." end
        replayToken=replayToken+1
        local token=replayToken
        reapplying,replayGeneration=true,generation
        notify("Restoring saved cosmetics...",true)
        local desired=copySettings()
        local failures={}
        local ok,message=pcall(function()
            restoreAppearance(desired.hideOriginals)
            local function apply(operation,...)
                check(ctx)
                local success,err=pcall(operation,...)
                check(ctx)
                if not success then table.insert(failures,(tostring(err):gsub("^.-:%d+:%s*",""))) end
            end
            if desired.body then apply(operations.applyBody,desired.body) end
            for region,value in pairs(desired.bodyParts) do apply(operations.applyBodyPart,region,value) end
            if desired.hideOriginals then apply(operations.removeCurrentAccessories) end
            for _,id in ipairs(desired.accessories) do apply(operations.equipAccessory,id) end
            if desired.colors.All then apply(operations.setSkin,Color3.new(desired.colors.All[1],desired.colors.All[2],desired.colors.All[3]),"All") end
            for region,color in pairs(desired.colors) do if region~="All" then apply(operations.setSkin,Color3.new(color[1],color[2],color[3]),region) end end
        end)
        if token==replayToken then reapplying=false end
        check(ctx)
        assert(ok,message)
        local result=#failures==0 and "Saved cosmetics restored." or ("Saved selections kept; some could not load: "..failures[1])
        if token==replayToken then notify(result,false) end
        return result
    end
    local function schedule(c)
        local ticket=generation
        task.spawn(function()
            for attempt=1,100 do
                if not alive or generation~=ticket or player.Character~=c then return end
                local humanoid=c:FindFirstChildOfClass("Humanoid")
                local appearance=true
                if player.HasAppearanceLoaded then
                    local ok,loaded=pcall(function() return player:HasAppearanceLoaded() end)
                    appearance=ok and loaded
                end
                if humanoid and humanoid.Health>0 and c:FindFirstChild("Head") and (appearance or attempt>=50) then
                    task.wait(0.25)
                    if not alive or generation~=ticket or player.Character~=c then return end
                    local ok,err=pcall(api.reapplySaved)
                    if not ok and alive and generation==ticket then notify("Could not restore saved cosmetics: "..tostring(err),false) end
                    return
                end
                task.wait(0.1)
            end
            if alive and generation==ticket then notify("Avatar is not ready. Use Reapply saved cosmetics when it finishes loading.",false) end
        end)
    end
    local changed=player.CharacterAdded:Connect(function(c)
        generation=generation+1;forget();schedule(c)
    end)
    function api.destroy()
        if not alive then return end
        generation=generation+1
        changed:Disconnect()
        if snapshot and snapshot.character==player.Character then pcall(restoreAppearance) end
        forget();alive=false
    end
    return api
end
