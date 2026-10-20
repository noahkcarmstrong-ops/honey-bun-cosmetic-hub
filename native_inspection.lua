-- Reopens only the local player's native avatar inspector with local cosmetic data.
local fields={[2]="GraphicTShirt",[11]="Shirt",[12]="Pants",[17]="Head",[79]="Head",[18]="Face",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[48]="ClimbAnimation",[50]="FallAnimation",[51]="IdleAnimation",[52]="JumpAnimation",[53]="RunAnimation",[54]="SwimAnimation",[55]="WalkAnimation"}
local accessoryTypes={[8]="Hat",[41]="Hair",[42]="Face",[43]="Neck",[44]="Shoulder",[45]="Front",[46]="Back",[47]="Waist",[64]="TShirt",[65]="Shirt",[66]="Pants",[67]="Jacket",[68]="Sweater",[69]="Shorts",[70]="LeftShoe",[71]="RightShoe",[72]="DressSkirt",[76]="Eyebrow",[77]="Eyelash"}
local scales={height="HeightScale",width="WidthScale",depth="DepthScale",head="HeadScale",proportion="ProportionScale",bodyType="BodyTypeScale"}
local colors={headColor="HeadColor",torsoColor="TorsoColor",leftArmColor="LeftArmColor",rightArmColor="RightArmColor",leftLegColor="LeftLegColor",rightLegColor="RightLegColor"}
local function description(snapshot)
    assert(type(snapshot)=="table" and type(snapshot.definition)=="table" and type(snapshot.items)=="table","Local outfit is not ready.")
    local desc=Instance.new("HumanoidDescription")
    local ok,err=pcall(function()
        local metadata={}
        for _,asset in ipairs(snapshot.definition.assets or {})do metadata[asset.id]=asset.meta end
        local accessories={}
        for _,item in ipairs(snapshot.items)do
            local field=fields[item.assetType]
            if field then desc[field]=item.id
            elseif accessoryTypes[item.assetType]then
                local kind=Enum.AccessoryType[accessoryTypes[item.assetType]]
                assert(kind,"Roblox does not support this accessory type.")
                local meta=metadata[item.id]
                local layered=item.assetType>=64 and item.assetType<=72
                local entry={AssetId=item.id,AccessoryType=kind,IsLayered=layered}
                if layered then entry.Order=meta and meta.order or #accessories;entry.Puffiness=meta and meta.puffiness or 0 end
                accessories[#accessories+1]=entry
            end
        end
        desc:SetAccessories(accessories,true)
        for name,field in pairs(scales)do local value=snapshot.definition.scales and snapshot.definition.scales[name];if value~=nil then desc[field]=value end end
        for name,field in pairs(colors)do
            local value=snapshot.definition.bodyColors and snapshot.definition.bodyColors[name]
            if value then
                value=value:gsub("^#","")
                assert(value:match("^%x%x%x%x%x%x$"),"Local skin color is invalid.")
                desc[field]=Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16))
            end
        end
    end)
    if not ok then desc:Destroy();error(err)end
    return desc
end
-- Compare the applied model, not just its presence: Roblox parents it before loading ends.
local function appearanceKey(desc)
    local out={}
    for _,field in pairs(fields)do out[#out+1]=field..":"..tostring(desc[field] or 0)end
    for _,field in pairs(scales)do out[#out+1]=field..":"..tostring(desc[field] or 0)end
    for _,field in pairs(colors)do
        local color=desc[field]
        if color then out[#out+1]=field..string.format(":%.4f:%.4f:%.4f",color.R,color.G,color.B)end
    end
    for _,entry in ipairs(desc:GetAccessories(true))do out[#out+1]="Accessory:"..tostring(entry.AssetId)end
    table.sort(out);return table.concat(out,";")
end
local M={description=description}
function M.create(player)
    local core,gui
    pcall(function() core=game:GetService("CoreGui");gui=game:GetService("GuiService")end)
    local active=false
    local modeEnabled,currentName=false,player.Name
    local masked,connections={},{}
    local changingMask=false
    local activeDescription
    local function releaseDescription()
        if activeDescription then activeDescription:Destroy();activeDescription=nil end
    end
    local lastSignature,lastLabel,adopting,lastName,status=nil,nil,false,nil,"Inspector is waiting."
    local function visible(object)
        local current=object
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current=current.Parent
        end
        return true
    end
    local function ownTitle(alias)
        local objects={};pcall(function()objects=core:GetDescendants()end)
        for _,object in ipairs(objects)do
            if object:IsA("TextLabel") and visible(object) then
                local text=object.Text
                local scoped=false
                local scopeRoot
                local ancestor=object.Parent
                while ancestor do
                    if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu" then scoped=true;scopeRoot=ancestor;break end
                    ancestor=ancestor.Parent
                end
                if scoped and (text==player.Name.."'s Avatar" or (active and (object==lastLabel or adopting) and (text==alias.."'s Avatar" or (lastName and text==lastName.."'s Avatar"))))then
                    return object,text,scopeRoot
                end
            end
        end
    end
    local function restoreMasks()
        for viewport,entry in pairs(masked)do
            if entry.connection then entry.connection:Disconnect()end
            pcall(function()viewport.ImageTransparency=entry.original end)
        end
        masked={}
    end
    local function maskPreview(allowReady)
        if not modeEnabled then return end
        local label,_,root=ownTitle(currentName)
        if not label or not root then
            -- Roblox can reuse the same viewport when inspecting a different player.
            for viewport,entry in pairs(masked)do
                local ancestor=viewport.Parent
                while ancestor and not ancestor.Name:find("InspectAndBuy",1,true) and ancestor.Name~="AvatarInspectMenu"do ancestor=ancestor.Parent end
                if ancestor then
                    for _,object in ipairs(ancestor:GetDescendants())do
                        if object:IsA("TextLabel") and object.Text:match("'s Avatar$") and object.Text~=player.Name.."'s Avatar" and object.Text~=currentName.."'s Avatar" and object.Text~=(lastName or "").."'s Avatar"then
                            if entry.connection then entry.connection:Disconnect()end
                            viewport.ImageTransparency=entry.original;masked[viewport]=nil;break
                        end
                    end
                end
            end
            return
        end
        local objects=root:GetDescendants()
        for _,viewport in ipairs(objects)do
            if viewport:IsA("ViewportFrame")then
                local entry=masked[viewport]
                if not entry then
                    entry={original=viewport.ImageTransparency or 0,ready=false};masked[viewport]=entry
                    pcall(function()entry.connection=viewport:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
                        if modeEnabled and not changingMask and not entry.ready then
                            changingMask=true;viewport.ImageTransparency=1;changingMask=false
                        end
                    end)end)
                end
                local ready=false
                if allowReady and activeDescription then
                    local ok,result=pcall(function()
                        local expected=appearanceKey(activeDescription)
                        for _,object in ipairs(viewport:GetDescendants())do
                            if object:IsA("Humanoid")then
                                local applied=object:GetAppliedDescription()
                                local matches=appearanceKey(applied)==expected
                                applied:Destroy()
                                if matches then return true end
                            end
                        end
                        return false
                    end)
                    ready=ok and result
                end
                entry.ready=ready
                changingMask=true;viewport.ImageTransparency=ready and entry.original or 1;changingMask=false
            end
        end
    end
    local function watchTitle(object)
        local ancestor=object.Parent
        local scoped=false
        while ancestor do
            if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu"then scoped=true;break end
            ancestor=ancestor.Parent
        end
        if scoped and object:IsA("TextLabel")then
            local wasTitle=object.Text:match("'s Avatar$")~=nil
            pcall(function()connections[#connections+1]=object:GetPropertyChangedSignal("Text"):Connect(function()
                local isTitle=object.Text:match("'s Avatar$")~=nil
                if wasTitle or isTitle then maskPreview(false)end
                wasTitle=isTitle
            end)end)
        end
        return scoped
    end
    if core then
        pcall(function()
            for _,object in ipairs(core:GetDescendants())do watchTitle(object)end
            connections[#connections+1]=core.DescendantAdded:Connect(function(object)
                local scoped=watchTitle(object)
                if scoped and (object:IsA("ViewportFrame") or (object:IsA("TextLabel") and object.Text:match("'s Avatar$")))then maskPreview(false)end
            end)
        end)
    end
    local api={}
    function api.update(options)
        local enabled=options.enabled==true
        modeEnabled=enabled
        local alias=tostring(options.name or "")
        local name=alias~="" and alias or player.Name
        currentName=name
        local label,title=ownTitle(name)
        if not enabled then
            if active and label then pcall(function()gui:InspectPlayerFromUserId(player.UserId)end)end
            restoreMasks()
            releaseDescription()
            active=false;lastLabel=nil;lastSignature=nil;adopting=false;lastName=nil
            return
        end
        if not label then maskPreview(false);lastLabel=nil;lastSignature=nil;adopting=false;return end
        maskPreview(false)
        if not options.snapshot then status="Waiting for the local outfit.";return end
        local signature=game:GetService("HttpService"):JSONEncode(options.snapshot)..name
        if active and lastSignature==signature and adopting then lastLabel=label;adopting=false;maskPreview(true);return end
        if active and lastLabel==label and lastSignature==signature then maskPreview(true);return end
        local desc=description(options.snapshot)
        local ok,err=pcall(function()gui:InspectPlayerFromHumanoidDescription(desc,name)end)
        -- Roblox loads preview models and AccessoryDescription children asynchronously.
        -- Keep the source alive until Larp mode stops or a newer inspection replaces it.
        if ok then releaseDescription();activeDescription=desc;active=true;lastLabel=label;lastSignature=signature;adopting=true;lastName=name;status="Native local outfit inspection requested."
        else desc:Destroy();status="Roblox blocked the local avatar inspector: "..tostring(err)end
    end
    function api.report()return status end
    function api.destroy()
        api.update({enabled=false,name=""})
        for _,connection in ipairs(connections)do connection:Disconnect()end
        connections={}
    end
    return api
end
return M
