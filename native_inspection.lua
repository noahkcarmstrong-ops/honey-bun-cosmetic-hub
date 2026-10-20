-- Reopens the selected player's native avatar inspector with local cosmetic data.
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
    local currentSnapshot,currentImage,previewData,previewKey,previewCharacter
    local warmedItems,refreshQueued=nil,false
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
            if current:IsA("GuiObject") and not current.Visible and not (panels[current] and not panels[current].ready) then return false end
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
            if object.Parent and object:IsA("TextLabel") and visible(object.Parent) then
                local text=object.Text
                local scoped=false
                local scopeRoot
                local ancestor=object.Parent
                while ancestor do
                    if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu" then scoped=true;scopeRoot=ancestor end
                    ancestor=ancestor.Parent
                end
                if scoped then knownLabels[object]=true end
                if scoped and (text==player.Name.."'s Avatar" or text==alias.."'s Avatar" or (active and (object==lastLabel or adopting) and (text==alias.."'s Avatar" or (lastName and text==lastName.."'s Avatar"))))then
                    return object,text,scopeRoot
                end
            end
        end
    end
    local function nativeAvatarVisual(object)
        if object.Name==overlayName then return false end
        if object:IsA("ViewportFrame") then return true end
        if not (object:IsA("ImageLabel") or object:IsA("ImageButton")) then return false end
        local ancestor=object.Parent
        while ancestor do
            if ancestor.Name==overlayName then return false end
            if ancestor.Name=="ViewportContainer" or (ancestor.Name=="Thumbnail" and ancestor.Parent and ancestor.Parent.Name=="InnerView") then return true end
            if ancestor.Name:find("InspectAndBuy",1,true) then break end
            ancestor=ancestor.Parent
        end
        return false
    end
    local function panelVisibility(root,show)
        local targets={}
        local itemNames,itemIds={},{}
        local function normalized(value)return tostring(value or ""):match("^%s*(.-)%s*$"):lower()end
        for _,item in ipairs(currentSnapshot and currentSnapshot.items or {})do
            if type(item.name)=="string" then itemNames[normalized(item.name)]=true end
            itemIds[tostring(item.id)]=true
        end
        local function larpItems(object)
            local labels={object}
            for _,child in ipairs(object:GetDescendants())do labels[#labels+1]=child end
            local found=false
            for _,label in ipairs(labels)do
                if label:IsA("TextLabel") and string.lower(label.Name or "")=="itemname" then
                    found=true
                    if not itemNames[normalized(label.Text)] then
                        local matched=false
                        local card=label.Parent
                        for depth=1,4 do
                            if not card then break end
                            local images,labels={},0
                            for _,child in ipairs(card:GetDescendants())do
                                if child:IsA("TextLabel") and child.Name:lower()=="itemname" then labels=labels+1 end
                                if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                                    local image=tostring(child.Image or "")
                                    local id=image:match("^rbxthumb://type=Asset&id=(%d+)[&]")
                                    if id then images[#images+1]=id end
                                end
                            end
                            if labels>1 then break end
                            if #images>0 then
                                matched=true;for _,id in ipairs(images)do if not itemIds[id] then matched=false end end
                                break
                            end
                            if card==object then break end
                            card=card.Parent
                        end
                        if not matched then return false end
                    end
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
                if nativeAvatarVisual(object) or (object:IsA("TextLabel") and object.Text:match("'s Avatar$")) or itemContent then
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
                    if modeEnabled and not mutatingPanel then
                        if object.Visible then entry.original=true end
                        if not entry.ready then mutatingPanel=true;object.Visible=false;mutatingPanel=false end
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
                local identified,own=false,false
                for _,object in ipairs(root:GetDescendants())do
                    if object:IsA("TextLabel") and object.Text:match("'s Avatar$")then
                        identified=true
                        if object.Text==player.Name.."'s Avatar" or object.Text==currentName.."'s Avatar" then own=true end
                    end
                end
                local ready=active and fallbackGui and fallbackGui.Enabled and fallbackEntry and fallbackEntry.overlay and fallbackEntry.overlay.Visible
                -- Mask own content while its shell is still hidden, before opening animation starts.
                if not identified or (own and not ready) then panelVisibility(root,false)end
            end
        end
    end
    local function restoreMasks()
        restorePanels()
        if fallbackEntry and fallbackEntry.overlay then fallbackEntry.overlay:Destroy()end
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
                        if not currentImage and (key~=previewKey or not previewData or previewCharacter~=player.Character) then
                            previewData=previews.capture();previewKey=key;previewCharacter=player.Character
                        end
                        local overlayClass=currentImage and "ImageLabel" or "ViewportFrame"
                        if entry.overlay and not entry.overlay.Parent then entry.overlay=nil;entry.key=nil end
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
                        entry.overlay.Parent=parent
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
            if fallbackGui then fallbackGui.Enabled=false;if fallbackEntry and fallbackEntry.overlay then fallbackEntry.overlay.Visible=false end end
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
        local nativeViewport,nativeThumbnail
        for _,viewport in ipairs(objects)do
            if nativeAvatarVisual(viewport) then
                if viewport:IsA("ViewportFrame") then nativeViewport=nativeViewport or viewport
                elseif viewport.Parent and viewport.Parent.Name=="Thumbnail" then nativeThumbnail=viewport.Parent end
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
            -- The native layout hides/repositions the 3D container while loading.
            -- Render outside its UIListLayout, aligned with the visible thumbnail slot.
            renderPreview(fallbackEntry,fallbackGui)
            local overlay=fallbackEntry.overlay
            if overlay then
                local bounds=nativeThumbnail or nativeViewport
                if bounds then
                    overlay.AnchorPoint=Vector2.new(0,0)
                    local origin=fallbackGui.AbsolutePosition or Vector2.new(0,0)
                    overlay.Position=UDim2.fromOffset(bounds.AbsolutePosition.X-origin.X,bounds.AbsolutePosition.Y-origin.Y)
                    overlay.Size=UDim2.fromOffset(bounds.AbsoluteSize.X,bounds.AbsoluteSize.Y)
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
    local function schedulePreview()
        if refreshQueued or not modeEnabled or not currentSnapshot then return end
        refreshQueued=true
        local function refresh()
            refreshQueued=false
            if modeEnabled and currentSnapshot then maskPreview(true)end
        end
        if task and task.defer then task.defer(refresh)else refreshQueued=false end
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
                    if modeEnabled and object.Visible and not guardingVisibility and not mutatingPanel then
                        if panels[object] then panels[object].original=true end
                        guardingVisibility=true
                        local ok,message=pcall(function()quarantineUnknownPanels();maskPreview(false,true)end)
                        guardingVisibility=false
                        if not ok then status="Inspection visibility guard: "..tostring(message) end
                        schedulePreview()
                    end
                end);connections[#connections+1]=rootVisibility[object] end)
            end
        end
        if scoped and object:IsA("TextLabel")then
            knownLabels[object]=true
            local wasTitle=object.Text:match("'s Avatar$")~=nil
            pcall(function()connections[#connections+1]=object:GetPropertyChangedSignal("Text"):Connect(function()
                local isTitle=object.Text:match("'s Avatar$")~=nil
                if wasTitle or isTitle then maskPreview(false);schedulePreview()end
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
                if scoped and (nativeAvatarVisual(object) or (object:IsA("TextLabel") and object.Text:match("'s Avatar$")))then maskPreview(false)end
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
                if fallbackEntry and fallbackEntry.overlay then fallbackEntry.overlay.Visible=false end
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
    local recoveryScheduled,recoverySince,recoverySignature=false,nil,nil
    local recoveryAttempts=0
    local function scheduleRecovery()
        if recoveryScheduled or not modeEnabled or not task or not task.delay then return end
        recoveryScheduled=true
        task.delay(1,function()
            recoveryScheduled=false
            if not modeEnabled then return end
            local label,_,root=ownTitle(currentName,true)
            if not label or not active or not currentSnapshot then
                recoverySince=nil;recoveryAttempts=0
            else
                if recoverySignature~=lastSignature then
                    recoverySignature=lastSignature;recoverySince=nil;recoveryAttempts=0
                end
                local loading,cards=false,0
                for _,object in ipairs(root:GetDescendants())do
                    if object.Name:match("^Skeleton%d+$") and visible(object) then loading=true end
                    if object.Name=="ItemCardFooterTitle" and visible(object) then cards=cards+1 end
                end
                if not loading or cards>0 then
                    recoverySince=nil;recoveryAttempts=0
                elseif recoveryAttempts<3 then
                    local now=os.clock()
                    recoverySince=recoverySince or now
                    if now-recoverySince>=6*2^recoveryAttempts then
                        recoveryAttempts=recoveryAttempts+1;recoverySince=now
                        -- A successful API call can still leave Roblox's cards stuck.
                        -- Recreate only the own description, never the account inspector.
                        lastSignature=nil
                        local attempts=recoveryAttempts
                        local ok,err=pcall(api.update,{enabled=true,name=currentName,snapshot=currentSnapshot,image=currentImage})
                        recoverySignature=lastSignature;recoveryAttempts=attempts
                        status=ok and ("Retrying stalled Roblox item cards ("..attempts.."/3).") or ("Item card retry failed: "..tostring(err))
                    end
                end
            end
            scheduleRecovery()
        end)
    end
    function api.update(options)
        local enabled=options.enabled==true
        modeEnabled=enabled
        if enabled then scheduleRecovery()else recoverySince=nil;recoverySignature=nil;recoveryAttempts=0 end
        currentSnapshot=options.snapshot
        if enabled and currentSnapshot and task and task.spawn then
            local thumbs={};for _,item in ipairs(currentSnapshot.items or {})do thumbs[#thumbs+1]="rbxthumb://type=Asset&id="..tostring(item.id).."&w=150&h=150"end
            local key=table.concat(thumbs,"|")
            if warmedItems~=key then
                warmedItems=key
                task.spawn(function()pcall(function()game:GetService("ContentProvider"):PreloadAsync(thumbs)end)end)
            end
        end
        currentImage=type(options.image)=="string" and options.image~="" and options.image or nil
        if not currentSnapshot then previewData=nil;previewKey=nil end
        local alias=tostring(options.name or "")
        local name=alias~="" and alias or player.Name
        currentName=name
        local label,title=ownTitle(name)
        if not enabled then
            if active and label and not options.preserveNative then pcall(function()gui:InspectPlayerFromUserId(player.UserId)end)end
            restoreMasks()
            releaseDescription()
            active=false;lastLabel=nil;lastSignature=nil;adopting=false;lastName=nil
            return
        end
        if not label then maskPreview(false);return end
        maskPreview(false)
        if not options.snapshot then status="Waiting for the local outfit.";return end
        local signature=game:GetService("HttpService"):JSONEncode(options.snapshot)..name
        if active and lastSignature==signature then
            if title==name.."'s Avatar" then lastLabel=label;adopting=false;maskPreview(true);return end
            if adopting then maskPreview(false);return end
        end
        local desc=description(options.snapshot)
        local ok,err=pcall(function()gui:InspectPlayerFromHumanoidDescription(desc,name)end)
        -- Roblox loads preview models and AccessoryDescription children asynchronously.
        -- Keep the source alive until Larp mode stops or a newer inspection replaces it.
        if ok then releaseDescription();activeDescription=desc;active=true;lastLabel=label;lastSignature=signature;adopting=true;lastName=name;status="Native local outfit inspection requested."
        else desc:Destroy();status="Roblox blocked the local avatar inspector: "..tostring(err)end
    end
    function api.report()return status end
    function api.destroy(preserveNative)
        if unbindGuard then unbindGuard();unbindGuard=nil end
        previewData=nil;previewKey=nil;currentImage=nil
        api.update({enabled=false,name="",preserveNative=preserveNative==true})
        for _,connection in ipairs(connections)do connection:Disconnect()end
        connections={}
    end
    return api
end
return M
