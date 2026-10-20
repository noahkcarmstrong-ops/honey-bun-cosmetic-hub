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
local M={description=description}
function M.create(player,getPreviews)
    local core,gui
    pcall(function() core=game:GetService("CoreGui");gui=game:GetService("GuiService")end)
    local active=false
    local modeEnabled,currentName=false,player.Name
    local masked,connections,knownLabels={},{},{}
    local unbindGuard
    local changingMask=false
    local currentSnapshot,previewData,previewKey
    local overlayName="LarpbloxInspectPreview"
    local fallbackGui,fallbackEntry,previewLabel
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
    local function ownTitle(alias,knownOnly)
        local objects={}
        if knownOnly then
            for object in pairs(knownLabels)do objects[#objects+1]=object end
        else pcall(function()objects=core:GetDescendants()end)end
        for _,object in ipairs(objects)do
            if object.Parent and object:IsA("TextLabel") and visible(object) then
                local text=object.Text
                local scoped=false
                local scopeRoot
                local ancestor=object.Parent
                while ancestor do
                    if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu" then scoped=true;scopeRoot=ancestor;break end
                    ancestor=ancestor.Parent
                end
                if scoped then knownLabels[object]=true end
                if scoped and (text==player.Name.."'s Avatar" or (active and (object==lastLabel or adopting) and (text==alias.."'s Avatar" or (lastName and text==lastName.."'s Avatar"))))then
                    return object,text,scopeRoot
                end
            end
        end
    end
    local function restoreMasks()
        if fallbackGui then fallbackGui:Destroy();fallbackGui=nil;fallbackEntry=nil end
        for viewport,entry in pairs(masked)do
            if entry.connection then entry.connection:Disconnect()end
            if entry.overlay then entry.overlay:Destroy()end
            pcall(function()viewport.ImageTransparency=entry.original end)
        end
        masked={}
    end
    local function renderPreview(entry,parent)
        if entry.overlay then entry.overlay.Visible=false end
        if currentSnapshot and getPreviews then
                    local key=game:GetService("HttpService"):JSONEncode(currentSnapshot)..tostring(player.Character)
                    local ok,err=pcall(function()
                        local previews=getPreviews()
                        if key~=previewKey or not previewData then
                            previewData=previews.capture();previewKey=key
                        end
                        if not entry.overlay then
                            local overlay=Instance.new("ViewportFrame")
                            overlay.Name=overlayName;overlay.BackgroundTransparency=1;overlay.BorderSizePixel=0
                            overlay.Size=UDim2.fromScale(1,1);overlay.Position=UDim2.fromScale(0,0)
                            overlay.Visible=false;overlay.ZIndex=10
                            entry.overlay=overlay;overlay.Parent=parent
                        end
                        if entry.key~=key then
                            assert(previews.show(entry.overlay,previewData)~=false,"Local avatar preview could not render.")
                            entry.key=key
                        end
                        if modeEnabled and (entry==fallbackEntry or masked[parent]==entry) then entry.overlay.Visible=true end
                    end)
                    if not ok then status="Local inspection preview is loading: "..tostring(err)end
                end
    end
    local function maskPreview(allowReady,preserveLive)
        if fallbackGui and not preserveLive then fallbackGui.Enabled=false end
        if not modeEnabled then return end
        local label,_,root=ownTitle(currentName,preserveLive)
        previewLabel=label
        if not label or not root then
            if fallbackGui then fallbackGui.Enabled=false end
            -- Roblox can reuse the same viewport when inspecting a different player.
            for viewport,entry in pairs(masked)do
                local ancestor=viewport.Parent
                while ancestor and not ancestor.Name:find("InspectAndBuy",1,true) and ancestor.Name~="AvatarInspectMenu"do ancestor=ancestor.Parent end
                if ancestor then
                    for _,object in ipairs(ancestor:GetDescendants())do
                        if object:IsA("TextLabel") and object.Text:match("'s Avatar$") and object.Text~=player.Name.."'s Avatar" and object.Text~=currentName.."'s Avatar" and object.Text~=(lastName or "").."'s Avatar"then
                            if entry.connection then entry.connection:Disconnect()end
                            if entry.overlay then entry.overlay:Destroy()end
                            viewport.ImageTransparency=entry.original;masked[viewport]=nil;break
                        end
                    end
                end
            end
            return
        end
        local objects=root:GetDescendants()
        for _,viewport in ipairs(objects)do
            if viewport:IsA("ViewportFrame") and viewport.Name~=overlayName then
                local entry=masked[viewport]
                if not entry then
                    entry={original=viewport.ImageTransparency or 0};masked[viewport]=entry
                    pcall(function()entry.connection=viewport:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
                        if modeEnabled and not changingMask then
                            changingMask=true;viewport.ImageTransparency=1;changingMask=false
                        end
                    end)end)
                end
                -- The native model can normalize body IDs/scales or fail to generate.
                -- Show the actual local character through the existing preview renderer.
                changingMask=true;viewport.ImageTransparency=1;changingMask=false
                if entry.overlay then entry.overlay.Visible=false end
            end
        end
        if allowReady and currentSnapshot then
            if not fallbackGui then
                fallbackGui=Instance.new("ScreenGui")
                fallbackGui.Name="LarpbloxOwnPreview";fallbackGui.ResetOnSpawn=false
                fallbackGui.IgnoreGuiInset=true;fallbackGui.DisplayOrder=1000
                fallbackGui.Enabled=false;fallbackGui.Parent=core
                fallbackEntry={}
            end
            renderPreview(fallbackEntry,fallbackGui)
            local overlay=fallbackEntry.overlay
            if overlay then
                -- The native item title marks the bottom of the avatar area.
                local titleY=label.AbsolutePosition and label.AbsolutePosition.Y or 340
                local height=math.min(300,math.max(0,titleY-84))
                overlay.AnchorPoint=Vector2.new(0.5,0)
                overlay.Position=UDim2.new(0.5,0,0,math.max(64,titleY-height-12))
                overlay.Size=UDim2.fromOffset(math.min(320,height),height)
                fallbackGui.Enabled=height>0 and overlay.Visible==true
            end
        end
    end
    local function watchTitle(object)
        if object.Name==overlayName then return false end
        local ancestor=object.Parent
        local scoped=false
        while ancestor do
            if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu"then scoped=true;break end
            ancestor=ancestor.Parent
        end
        if scoped and object:IsA("TextLabel")then
            knownLabels[object]=true
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
    -- Native try-on models can be inserted after the item/name callbacks.
    -- Mask them at the last render priority, before any frame can display them.
    pcall(function()
        local run=game:GetService("RunService")
        local function guard()
            if modeEnabled then maskPreview(false,true)end
            if fallbackGui and fallbackGui.Enabled and (not modeEnabled or not previewLabel or not previewLabel.Parent or not visible(previewLabel))then
                fallbackGui.Enabled=false
            end
        end
        if run.BindToRenderStep then
            local binding="LarpbloxInspectGuard_"..tostring(player.UserId)
            local priority=Enum.RenderPriority and Enum.RenderPriority.Last.Value or 2000
            run:BindToRenderStep(binding,priority,guard)
            unbindGuard=function()run:UnbindFromRenderStep(binding)end
        else connections[#connections+1]=run.RenderStepped:Connect(guard)end
    end)
    local api={}
    function api.update(options)
        local enabled=options.enabled==true
        modeEnabled=enabled
        currentSnapshot=options.snapshot
        if not currentSnapshot then previewData=nil;previewKey=nil end
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
        if unbindGuard then unbindGuard();unbindGuard=nil end
        previewData=nil;previewKey=nil
        api.update({enabled=false,name=""})
        for _,connection in ipairs(connections)do connection:Disconnect()end
        connections={}
    end
    return api
end
return M
