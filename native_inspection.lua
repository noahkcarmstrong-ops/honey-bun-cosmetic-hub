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
    local panels,inspectRoots={},{}
    local rootVisibility={}
    local guardingVisibility=false
    local mutatingPanel=false
    local unbindGuard
    local changingMask=false
    local currentSnapshot,currentImage,previewData,previewKey
    local quarantineUnknownPanels,maskPreview
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
            if current:IsA("GuiObject") and not current.Visible and not (panels[current] and not panels[current].ready and panels[current].original) then return false end
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
                    if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu" then scoped=true;scopeRoot=ancestor end
                    ancestor=ancestor.Parent
                end
                if scoped then knownLabels[object]=true end
                if scoped and (text==player.Name.."'s Avatar" or (not active and text==alias.."'s Avatar") or (active and (object==lastLabel or adopting) and (text==alias.."'s Avatar" or (lastName and text==lastName.."'s Avatar"))))then
                    return object,text,scopeRoot
                end
            end
        end
    end
    local function panelVisibility(root,show)
        local targets={}
        local itemNames={}
        for _,item in ipairs(currentSnapshot and currentSnapshot.items or {})do
            if type(item.name)=="string" then itemNames[item.name]=true end
        end
        local function larpItems(object)
            local labels={object}
            for _,child in ipairs(object:GetDescendants())do labels[#labels+1]=child end
            local found=false
            for _,label in ipairs(labels)do
                if label:IsA("TextLabel") and string.lower(label.Name or "")=="itemname" then
                    found=true
                    if not itemNames[label.Text] then return false end
                end
            end
            return found
        end
        -- Keep the native panel shell (including close/back navigation) alive.
        -- Only quarantine avatar/item content until the redirected inspector is ready.
        for _,object in ipairs(root:GetDescendants())do
            if object:IsA("GuiObject")then
                local name=string.lower(object.Name or "")
                local itemContent=name=="itemdetails" or name=="itemcontent" or name=="itemname"
                if itemContent and not object:IsA("TextLabel") then
                    -- A layout may reuse an item-related name for the whole page.
                    -- Never hide a container that also owns the avatar or navigation.
                    local hasItem=false
                    for _,child in ipairs(object:GetDescendants())do
                        local childName=string.lower(child.Name or "")
                        if childName=="itemname" then hasItem=true end
                        if child:IsA("ViewportFrame") or (child:IsA("TextLabel") and child.Text:match("'s Avatar$")) or childName=="close" or childName=="closebutton" or childName=="back" or childName=="backbutton" then itemContent=false;break end
                    end
                    itemContent=itemContent and hasItem
                    if not itemContent and panels[object] then
                        local entry=panels[object]
                        if entry.connection then entry.connection:Disconnect()end
                        mutatingPanel=true;object.Visible=entry.original;mutatingPanel=false
                        panels[object]=nil
                    end
                end
                if object:IsA("ViewportFrame") or (object:IsA("TextLabel") and object.Text:match("'s Avatar$")) or itemContent then
                    targets[#targets+1]={object=object,itemContent=itemContent}
                end
            end
        end
        for _,target in ipairs(targets)do
            local object=target.object
            local reveal=show and (not target.itemContent or larpItems(object))
            local entry=panels[object]
            if not entry then
                entry={original=object.Visible,root=root,ready=false};panels[object]=entry
                pcall(function()entry.connection=object:GetPropertyChangedSignal("Visible"):Connect(function()
                    if modeEnabled and not entry.ready and not mutatingPanel then
                        mutatingPanel=true;object.Visible=false;mutatingPanel=false
                    end
                end)end)
            end
            entry.ready=reveal
            mutatingPanel=true;object.Visible=reveal and entry.original or false;mutatingPanel=false
        end
    end
    local function restorePanels(root)
        for object,entry in pairs(panels)do
            if not root or entry.root==root then
                if entry.connection then entry.connection:Disconnect()end
                pcall(function()object.Visible=entry.original end)
                panels[object]=nil
            end
        end
    end
    function quarantineUnknownPanels()
        if not modeEnabled then return end
        for root in pairs(inspectRoots)do
            if not root.Parent then inspectRoots[root]=nil
            else
                local identified=false
                for _,object in ipairs(root:GetDescendants())do
                    if object:IsA("TextLabel") and object.Text:match("'s Avatar$")then identified=true;break end
                end
                -- A thumbnail can arrive before the name; keep unknown panels blank.
                if not identified then panelVisibility(root,false)end
            end
        end
    end
    local function restoreMasks()
        restorePanels()
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
        if (currentSnapshot or currentImage) then
                    local key=(currentSnapshot and game:GetService("HttpService"):JSONEncode(currentSnapshot) or "")..tostring(player.Character).."|"..tostring(currentImage or "")
                    local ok,err=pcall(function()
                        local previews=getPreviews and getPreviews() or nil
                        if not currentImage and (key~=previewKey or not previewData) then
                            previewData=previews.capture();previewKey=key
                        end
                        local overlayClass=currentImage and "ImageLabel" or "ViewportFrame"
                        if entry.overlay and entry.overlay.ClassName~=overlayClass then
                            entry.overlay:Destroy();entry.overlay=nil;entry.key=nil
                        end
                        if not entry.overlay then
                            local overlay=Instance.new(overlayClass)
                            overlay.Name=overlayName;overlay.BackgroundTransparency=1;overlay.BorderSizePixel=0
                            overlay.Size=UDim2.fromScale(1,1);overlay.Position=UDim2.fromScale(0,0)
                            overlay.Visible=false;overlay.ZIndex=10
                            entry.overlay=overlay;overlay.Parent=parent
                        end
                        if entry.key~=key then
                            if currentImage then entry.overlay.Image=currentImage
                            else assert(previews and previews.show(entry.overlay,previewData)~=false,"Local avatar preview could not render.") end
                            entry.key=key
                        end
                        if modeEnabled and (entry==fallbackEntry or masked[parent]==entry) then entry.overlay.Visible=true end
                    end)
                    if not ok then status="Local inspection preview is loading: "..tostring(err)end
                end
    end
    function maskPreview(allowReady,preserveLive)
        if fallbackGui and not preserveLive then fallbackGui.Enabled=false end
        if not modeEnabled then return end
        quarantineUnknownPanels()
        local label,title,root=ownTitle(currentName,preserveLive)
        previewLabel=label
        if not label or not root then
            if fallbackGui then fallbackGui.Enabled=false end
            -- Return shared native containers to normal when another player is inspected.
            for object,entry in pairs(panels)do
                local other=false
                for _,candidate in ipairs(entry.root:GetDescendants())do
                    if candidate:IsA("TextLabel") and candidate.Text:match("'s Avatar$") and candidate.Text~=player.Name.."'s Avatar" and candidate.Text~=currentName.."'s Avatar" and candidate.Text~=(lastName or "").."'s Avatar"then other=true;break end
                end
                if other then restorePanels(entry.root)end
            end
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
        local larpTitle=title==currentName.."'s Avatar"
        local ready=active and larpTitle and fallbackGui and fallbackGui.Enabled and fallbackEntry and fallbackEntry.overlay and fallbackEntry.overlay.Visible
        panelVisibility(root,preserveLive and ready==true)
        if not ready and fallbackGui then fallbackGui.Enabled=false end
        local objects=root:GetDescendants()
        local nativeViewport
        for _,viewport in ipairs(objects)do
            if viewport:IsA("ViewportFrame") and viewport.Name~=overlayName then
                nativeViewport=nativeViewport or viewport
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
                local position=nativeViewport and nativeViewport.AbsolutePosition
                local size=nativeViewport and nativeViewport.AbsoluteSize
                local hasBounds=position and size and position.X and position.Y and size.X and size.Y and size.X>0 and size.Y>0
                if hasBounds then
                    overlay.AnchorPoint=Vector2.new(0,0)
                    overlay.Position=UDim2.fromOffset(position.X,position.Y)
                    overlay.Size=UDim2.fromOffset(size.X,size.Y)
                    fallbackGui.Enabled=overlay.Visible==true and larpTitle
                else
                    -- Older layouts expose no usable viewport bounds; use the title as a fallback.
                    local titleY=label.AbsolutePosition and label.AbsolutePosition.Y or 340
                    if titleY<120 then titleY=340 end
                    local height=math.min(300,math.max(0,titleY-84))
                    overlay.AnchorPoint=Vector2.new(0.5,0)
                    overlay.Position=UDim2.new(0.5,0,0,math.max(64,titleY-height-12))
                    overlay.Size=UDim2.fromOffset(math.min(320,height),height)
                    fallbackGui.Enabled=height>0 and overlay.Visible==true and larpTitle
                end
                panelVisibility(root,fallbackGui.Enabled)
            end
        end
    end
    local function watchTitle(object)
        if object.Name==overlayName then return false end
        local ancestor=object
        local scoped,root=false,nil
        while ancestor do
            if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu"then scoped=true;root=ancestor end
            ancestor=ancestor.Parent
        end
        if root then
            inspectRoots[root]=true
            -- InspectAndBuy can be a Folder; observe the actual GUI objects,
            -- including the reused shell whose Visible changes when reopened.
            if object:IsA("GuiObject") and not rootVisibility[object] then
                pcall(function() rootVisibility[object]=object:GetPropertyChangedSignal("Visible"):Connect(function()
                    if modeEnabled and object.Visible and not guardingVisibility then
                        guardingVisibility=true
                        local ok,message=pcall(function()quarantineUnknownPanels();maskPreview(false,true)end)
                        guardingVisibility=false
                        if not ok then status="Inspection visibility guard: "..tostring(message) end
                    end
                end);connections[#connections+1]=rootVisibility[object] end)
            end
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
                if scoped and modeEnabled then quarantineUnknownPanels()end
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
        currentImage=type(options.image)=="string" and options.image~="" and options.image or nil
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
        previewData=nil;previewKey=nil;currentImage=nil
        api.update({enabled=false,name=""})
        for _,connection in ipairs(connections)do connection:Disconnect()end
        connections={}
    end
    return api
end
return M
