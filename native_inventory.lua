-- Local cards in the existing MM2 Weapons/Effects inventory; no ownership or remote changes.
return function(playerGui,catalog,onStatus,mode)
    local effects=mode=="effects" or mode=="saved-effects"
    local savedOnly=mode=="saved" or mode=="saved-effects"
    local initialCategory=effects and "effects" or "season1"
    local api={}
    local enabled,dead=false,false
    local grid,template,root,ownedRoot,nativePane,nativeHost
    local savedTab,savedPane,savedGrid,savedTabParent,savedOpen=nil,nil,nil,nil,false
    local savedTabMode=false
    local savedNativeVisibility={}
    local savedHeader={}
    local panePath,gridPath
    local mounting,queued=false,false
    local rendering,rerenderRequested=false,false
    local renderGeneration,renderPasses=0,0
    local renderedSeason,renderedQuery,catalogItems
    local cards,cardEntries,originals,connections,cardConnections={},{},{},{},{}
    local sideSlots,sideSnapshots,sideCandidates={},{},{}
    local sideModelIcons={}
    local query,season="",initialCategory
    local lastReport="Native inventory has not been detected yet."
    local diagnosticDetails=""
    local tabBindings,categoryCounts={},{season1=0,classic=0,holiday=0}
    local function read(o,k) local ok,v=pcall(function() return o[k] end);if ok then return v end;return nil end
    local function is(o,c) local ok,v=pcall(function() return o:IsA(c) end);return ok and v end
    local function children(o) return o and o:GetChildren() or {} end
    local function descendants(o) return o and o:GetDescendants() or {} end
    local function lower(v) return tostring(v or ""):lower() end
    local function normalize(v) return lower(v):gsub("[%s_]","") end
    local function status(message)
        lastReport=tostring(message)
        if onStatus then pcall(onStatus,lastReport) end
    end
    local function disconnect(list) for _,c in ipairs(list) do c:Disconnect() end end
    local function destroy(o) pcall(function() o:Destroy() end) end
    local function texts(o)
        local list=descendants(o);table.insert(list,1,o)
        return list
    end
    local function defaultKind(o)
        for _,v in ipairs(texts(o)) do
            if is(v,"TextLabel") or is(v,"TextButton") then
                if v.Text=="Default Knife" then return "Knife" end
                if v.Text=="Default Gun" then return "Gun" end
            end
        end
    end
    local function inventoryAncestor(o)
        local current=o.Parent
        while current and current~=playerGui do
            if lower(current.Name):find("inventory",1,true) then return current end
            current=current.Parent
        end
    end
    local function detectWeapon()
        local function collectionLabel(label,inventory)
            local o=label
            while o and o~=inventory do
                local name=normalize(o.Name)
                if name:find("equipped",1,true) or name:find("loadout",1,true) or lower(o.Name):sub(1,14)=="honeybunlocal_" then return false end
                o=o.Parent
            end
            return true
        end
        local function singleCard(card)
            local count=0
            for _,o in ipairs(texts(card)) do
                if is(o,"TextLabel") or is(o,"TextButton") then
                    if o.Text=="Default Knife" or o.Text=="Default Gun" then count=count+1 end
                end
                local name=normalize(o.Name)
                if name:find("crafting",1,true) or name:find("redeem",1,true) then return false end
            end
            return count==1
        end
        for _,label in ipairs(descendants(playerGui)) do
            if (is(label,"TextLabel") or is(label,"TextButton")) and (label.Text=="Default Knife" or label.Text=="Default Gun") then
                local inventory=inventoryAncestor(label)
                if inventory and collectionLabel(label,inventory) then
                    local card=label
                    while card.Parent and card.Parent~=inventory.Parent do
                        local container=card.Parent
                        if is(card,"GuiObject") and singleCard(card) then
                            if container:FindFirstChildOfClass("UIGridLayout") then return inventory,container,card end
                            local knife,gun
                            for _,sibling in ipairs(children(container)) do
                                if is(sibling,"GuiObject") and singleCard(sibling) then
                                    local kind=defaultKind(sibling)
                                    if kind=="Knife" then knife=sibling elseif kind=="Gun" then gun=sibling end
                                end
                            end
                            if knife and gun and knife~=gun then return inventory,container,knife end
                        end
                        if container==inventory then break end
                        card=container
                    end
                end
            end
        end

    end
    local function detect()
        if not effects then return detectWeapon() end
        local _,_,weaponTemplate=detectWeapon()
        for _,branch in ipairs(descendants(playerGui)) do
            local effectBranch=normalize(branch.Name)=="effects"
            local ancestor,excludedBranch=branch,false
            while effectBranch and ancestor and ancestor~=playerGui do
                local name=normalize(ancestor.Name)
                if name:find("equipped",1,true) or name:find("loadout",1,true) or lower(ancestor.Name):sub(1,14)=="honeybunlocal_" then excludedBranch=true;break end
                ancestor=ancestor.Parent
            end
            if effectBranch and not excludedBranch and is(branch,"GuiObject") and not is(branch,"GuiButton") and inventoryAncestor(branch) then
                local fallback
                for _,candidate in ipairs(descendants(branch)) do
                    local container=is(candidate,"UIGridLayout") and candidate.Parent or candidate
                    local ancestor,excluded=container,false
                    while ancestor and ancestor~=branch do
                        local name=normalize(ancestor.Name)
                        if name:find("equipped",1,true) or lower(ancestor.Name):sub(1,14)=="honeybunlocal_" then excluded=true;break end
                        ancestor=ancestor.Parent
                    end
                    if not excluded and is(container,"GuiObject") and not is(container,"GuiButton") then
                        local structural=is(candidate,"UIGridLayout") or is(container,"ScrollingFrame") or normalize(container.Name)=="container"
                        if structural then
                            for _,card in ipairs(children(container)) do
                                if is(card,"GuiObject") and lower(card.Name):sub(1,14)~="honeybunlocal_" and card:FindFirstChild("ItemName",true) then
                                    -- A scrolling wrapper can contain the entire item grid.
                                    -- Never clone that grid as though it were one effect card.
                                    local wrapsCards=false
                                    for _,nested in ipairs(children(card)) do
                                        if is(nested,"GuiObject") and nested:FindFirstChild("ItemName",true) then wrapsCards=true;break end
                                    end
                                    if not wrapsCards then return branch,container,card end
                                end
                            end
                            -- Prefer the inner grid when Items wraps a scrolling Container.
                            if not fallback or is(candidate,"UIGridLayout") or container.Parent==fallback then fallback=container end
                        end
                    end
                end
                if fallback and weaponTemplate then return branch,fallback,weaponTemplate end
            end
        end
    end
    local function inventoryTree()
        local lines={}
        for _,o in ipairs(descendants(playerGui)) do
            if inventoryAncestor(o) and is(o,"GuiObject") then
                lines[#lines+1]=o:GetFullName().." ["..o.ClassName.."] text="..tostring(read(o,"Text") or ""):sub(1,60)
                if #lines>=80 then break end
            end
        end
        return table.concat(lines,"\n")
    end
    local function own(o) return lower(o.Name):sub(1,14)=="honeybunlocal_" end
    local function category(value)
        local v=normalize(value)
        if savedOnly and v=="current" then return "season1" end
        if v=="season1" or v=="1" then return "season1" end
        if v=="classic" or v=="0" then return "classic" end
        if v=="holiday" or v:find("halloween",1,true) or v:find("christmas",1,true) then return "holiday" end
    end
    local function entryCategory(entry)
        if effects then return "effects" end
        if savedOnly and savedTabMode then return "saved" end
        return category(entry.category) or category(entry.event) or category(entry.season) or "classic"
    end
    local function pathFrom(ancestor,object)
        local path={}
        while object and object~=ancestor do table.insert(path,1,object.Name);object=object.Parent end
        return object==ancestor and path or nil
    end
    local function atPath(ancestor,path)
        if not path then return nil end
        local o=ancestor
        for _,name in ipairs(path or {}) do o=o and o:FindFirstChild(name) end
        return o
    end
    local function alive(o)
        while o do if o==playerGui then return true end;o=o.Parent end
        return false
    end
    local function localObject(o)
        while o and o~=playerGui do if own(o) then return true end;o=o.Parent end
        return false
    end
    local function paneFor(nativeGrid,inventory)
        local branch=nativeGrid
        local fallback=nativeGrid
        while branch and branch~=inventory do
            if is(branch,"ScrollingFrame") then fallback=branch end
            local parent=branch.Parent
            local categories=0
            for _,sibling in ipairs(children(parent)) do
                if is(sibling,"GuiObject") and not is(sibling,"GuiButton") and category(sibling.Name) then categories=categories+1 end
            end
            if categories>=2 and category(branch.Name) then return parent,branch end
            branch=parent
        end
        return fallback.Parent,fallback
    end
    local rarityRanks={unique=8,ancient=7,godly=6,vintage=5,classic=5,legendary=4,rare=3,uncommon=2,common=1}
    local rarityColors={unique={255,100,0},ancient={138,43,226},godly={255,0,255},vintage={255,255,0},classic={255,255,0},legendary={255,0,0},rare={0,200,0},uncommon={0,100,255},common={179,179,179}}
    local function entryColor(entry)
        if savedOnly and not effects then return Color3.fromRGB(table.unpack(rarityColors.ancient)) end
        if entry.rarityColor then return entry.rarityColor end
        local rgb=rarityColors[lower(entry.rarity)]
        if rgb and Color3 and Color3.fromRGB then return Color3.fromRGB(table.unpack(rgb)) end
    end
    local function compare(a,b)
        local ao,bo=type(a.sortOrder)=="number",type(b.sortOrder)=="number"
        if ao~=bo then return ao end
        if ao and a.sortOrder~=b.sortOrder then return a.sortOrder<b.sortOrder end
        local ar=a.rarityOrder or rarityRanks[lower(a.rarity)] or 0
        local br=b.rarityOrder or rarityRanks[lower(b.rarity)] or 0
        if ar~=br then return ar>br end
        if (a.chroma==true)~=(b.chroma==true) then return a.chroma==true end
        if lower(a.name)~=lower(b.name) then return lower(a.name)<lower(b.name) end
        return tostring(a.id)<tostring(b.id)
    end
    local function icon(card)
        local best,area
        for _,v in ipairs(texts(card)) do
            if is(v,"ImageLabel") or is(v,"ImageButton") then
                if v.Name=="Icon" or v.Name=="ItemImage" then return v end
                local size=read(v,"AbsoluteSize")
                local n=size and size.X*size.Y or 0
                if not best or n>(area or 0) then best,area=v,n end
            end
        end
        return best
    end
    local function overlay(card)
        local z=card.ZIndex or 1
        for _,v in ipairs(texts(card)) do
            if is(v,"GuiObject") then z=math.max(z,v.ZIndex or 1) end
            if is(v,"GuiButton") and v~=card then v.Active=false;pcall(function() v.Interactable=false end) end
            if is(v,"LuaSourceContainer") then destroy(v) end
        end
        local button=Instance.new("TextButton")
        button.Name="HoneyBunPreviewClick";button.Text="";button.BackgroundTransparency=1
        button.Size=UDim2.fromScale(1,1);button.Position=UDim2.fromScale(0,0)
        button.ZIndex=z+1;button.Parent=card
        return button
    end
    local function savedModelIcon(card,target,entry)
        local def=entry.visual
        if not target or not def or (type(entry.image)=="string" and entry.image~="") or type(entry.image)=="number" then return end
        local viewport=Instance.new("ViewportFrame")
        local ok=pcall(function()
            viewport.Name="HoneyBunLocal_ModelIcon";viewport.BackgroundTransparency=1
            viewport.Size=target.Size;viewport.Position=target.Position;viewport.AnchorPoint=target.AnchorPoint
            viewport.ZIndex=target.ZIndex;viewport.Ambient=Color3.fromRGB(200,200,200);viewport.LightColor=Color3.fromRGB(255,255,255)
            local model=Instance.new("Part");model.Size=def.Size;model.Anchored=true;model.CanCollide=false
            model.Color=def.Color;model.Material=def.Material;model.CFrame=CFrame.new()
            local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh;mesh.MeshId=def.MeshId
            mesh.TextureId=(def.SurfaceAppearance and def.SurfaceAppearance.ColorMap) or def.TextureId or ""
            mesh.Scale=def.Scale;mesh.Offset=def.Offset or Vector3.new(0,0,0)
            if def.VertexColor then mesh.VertexColor=def.VertexColor end
            mesh.Parent=model;model.Parent=viewport
            local camera=Instance.new("Camera");camera.FieldOfView=35
            local extent=math.max(def.Size.X,def.Size.Y,def.Size.Z)
            camera.CFrame=CFrame.lookAt(Vector3.new(extent*0.6,extent*0.3,extent*2.3),Vector3.new(0,0,0))
            camera.Parent=viewport;viewport.CurrentCamera=camera
            viewport.Parent=target.Parent
        end)
        if not ok then destroy(viewport);return end
        return viewport
    end
    local function clearCards()
        renderGeneration=renderGeneration+1;renderedSeason=nil;renderedQuery=nil
        disconnect(cardConnections);cardConnections={}
        for _,card in ipairs(cards) do destroy(card) end
        cards={};cardEntries={}
    end
    local function restoreSideSlots()
        for _,preview in pairs(sideModelIcons) do destroy(preview.viewport) end
        sideModelIcons={}
        for object,values in pairs(sideSnapshots) do
            for key,value in pairs(values) do pcall(function() object[key]=value end) end
        end
        sideSnapshots={};sideSlots={};sideCandidates={}
    end
    local function snapshot(object,key)
        sideSnapshots[object]=sideSnapshots[object] or {}
        if sideSnapshots[object][key]==nil then sideSnapshots[object][key]=read(object,key) end
    end
    local function sideSlotFor(container,kind)
        local wanted=lower(kind)
        for _,object in ipairs(descendants(container)) do
            if is(object,"GuiObject") and not localObject(object) and normalize(object.Name)==wanted then return object end
        end
    end
    local function bindSideSlots()
        sideSlots={};sideCandidates={}
        for _,object in ipairs(descendants(root)) do
            local ancestor,originalPane=object,false
            while ancestor and ancestor~=root do
                if originals[ancestor]~=nil then originalPane=true;break end
                ancestor=ancestor.Parent
            end
            if is(object,"GuiObject") and not localObject(object) and not originalPane then
                local name=normalize(object.Name)
                if name:find("equipped",1,true) or name=="loadout" then
                    local names={};for _,childObject in ipairs(children(object)) do if is(childObject,"GuiObject") and #names<24 then names[#names+1]=tostring(childObject.Name) end end
                    if #sideCandidates<12 then sideCandidates[#sideCandidates+1]=object:GetFullName().." children="..table.concat(names,",") end
                    if effects then
                        sideSlots.Effect=sideSlotFor(object,"Effect") or sideSlotFor(object,"Item") or object
                    end
                    sideSlots.Knife=not effects and (sideSlotFor(object,"Knife") or sideSlots.Knife) or nil
                    sideSlots.Gun=not effects and (sideSlotFor(object,"Gun") or sideSlots.Gun) or nil
                    if sideSlots.Knife and sideSlots.Gun then break end
                end
            end
        end
    end
    local function sideText(slot,kind,rarity)
        local wanted=rarity and "rarity" or nil
        for _,object in ipairs(texts(slot)) do
            if is(object,"TextLabel") or is(object,"TextButton") then
                local name=normalize(object.Name)
                if (wanted and name==wanted) or (not wanted and (name=="itemname" or name=="title" or name=="displayname")) then return object end
                if not wanted and object.Text=="Default "..kind then return object end
            end
        end
    end
    local function updateSideSlots(equipped)
        for kind,slot in pairs(sideSlots) do
            local id=equipped[kind]
            if not id then
                for _,object in ipairs(texts(slot)) do
                    for key,value in pairs(sideSnapshots[object] or {}) do pcall(function()object[key]=value end) end
                end
            end
            local entry
            if id then
                for _,candidate in ipairs(catalog.list(kind) or {}) do if candidate.id==id then entry=candidate;break end end
            end
            local image=entry and (entry.image or entry.previewImage)
            if type(image)=="number" or (type(image)=="string" and image:match("^%d+$")) then image="rbxassetid://"..tostring(image) end
            local target=icon(slot)
            if target then snapshot(target,"Image");target.Image=type(image)=="string" and image or read(target,"Image") end
            local preview=sideModelIcons[slot]
            if preview and (not entry or preview.id~=entry.id or (type(image)=="string" and image~="")) then
                destroy(preview.viewport);sideModelIcons[slot]=nil;preview=nil
            end
            if entry and entry.visual and not preview and target and (not image or image=="") then
                snapshot(target,"Image");target.Image=""
                local viewport=savedModelIcon(slot,target,entry)
                if viewport then sideModelIcons[slot]={id=entry.id,viewport=viewport} end
            end
            local name=sideText(slot,kind,false)
            if name then
                snapshot(name,"Text");snapshot(name,"Visible")
                if entry and (kind=="Knife" or kind=="Gun") then name.Text="";name.Visible=false
                else name.Text=entry and entry.name or read(name,"Text") end
            end
            if name and entry and kind~="Knife" and kind~="Gun" then
                local color=entryColor(entry)
                if color then
                    for _,key in ipairs({"BackgroundColor3","BackgroundTransparency","TextColor3"}) do snapshot(name,key) end
                    name.BackgroundColor3=color;name.BackgroundTransparency=0;name.TextColor3=Color3.fromRGB(255,255,255)
                end
            end
            local rarity=sideText(slot,kind,true)
            if rarity and entry and entry.rarity then snapshot(rarity,"Text");rarity.Text=tostring(entry.rarity) end
        end
    end
    local function updateSelection(equipped)
        for _,card in ipairs(cards) do
            local entry=cardEntries[card]
            if entry then
                for _,v in ipairs(texts(card)) do
                    if is(v,"GuiObject") and (normalize(v.Name)=="equipped" or normalize(v.Name)=="selected") then
                        v.Visible=equipped[entry.kind]==entry.id
                    end
                end
            end
        end
    end
    local savedCards,savedEntries,savedConnections={}, {}, {}
    local savedMetadata={}
    local savedCardConnections,savedLayouts={},{ }
    local savedGrids={}
    local savedRoot
    local openOptions
    local function clearSaved()
        openOptions=nil
        disconnect(savedConnections);savedConnections={}
        for _,connectionsForCard in pairs(savedCardConnections) do disconnect(connectionsForCard) end
        savedCardConnections={}
        for _,card in pairs(savedCards) do destroy(card) end
        savedCards={};savedEntries={}
        savedMetadata={}
        for target,state in pairs(savedLayouts) do
            if state.created then destroy(state.layout) end
            for object,properties in pairs(state.properties) do for key,value in pairs(properties) do pcall(function() object[key]=value end) end end
            if state.sortOrder~=nil then pcall(function() state.layout.SortOrder=state.sortOrder end) end
        end
        savedLayouts={}
    end
    local function findSavedGrids(inventory)
        local found={}
        local function addCategory(branch,key)
            local gridTarget,scrollTarget,plainTarget
            for _,o in ipairs(texts(branch)) do
                local excluded=false;local ancestor=o
                while ancestor and ancestor~=inventory do
                    local n=normalize(ancestor.Name)
                    if n:find("equipped",1,true) or n:find("loadout",1,true) or n=="tabs" or own(ancestor) then excluded=true;break end
                    ancestor=ancestor.Parent
                end
                if not excluded and o~=branch and is(o,"GuiObject") and not is(o,"GuiButton") then
                    if o:FindFirstChildOfClass("UIGridLayout") then gridTarget=o end
                    if is(o,"ScrollingFrame") then scrollTarget=o end
                    -- MM2's live Weapons tree sometimes uses plain Frames all
                    -- the way down to Current.Container (no scrolling frame or
                    -- UIGridLayout). Keep cards in that innermost container.
                    if normalize(o.Name)=="container" then plainTarget=o end
                end
            end
            if not gridTarget and branch:FindFirstChildOfClass("UIGridLayout") then gridTarget=branch end
            if not scrollTarget and is(branch,"ScrollingFrame") then scrollTarget=branch end
            local target=gridTarget or scrollTarget or plainTarget
            if target then found[key]=target end
        end
        local area
        local weaponBranch=inventory
        for _,branch in ipairs(descendants(inventory)) do
            if normalize(branch.Name)=="weapons" and is(branch,"GuiObject") and not is(branch,"GuiButton") then weaponBranch=branch;break end
        end
        for _,o in ipairs(descendants(weaponBranch)) do
            if normalize(o.Name)=="items" then
                for _,nested in ipairs(descendants(o)) do if normalize(nested.Name)=="container" then area=nested;break end end
                if area then break end
            end
        end
        area=area or inventory
        for _,o in ipairs(descendants(area)) do
            if is(o,"GuiObject") and category(o.Name) then addCategory(o,category(o.Name)) end
        end
        return found
    end
    local function prepareSavedGrid(target)
        if savedLayouts[target] then return end
        local layout=target:FindFirstChildOfClass("UIGridLayout")
        local state={layout=layout,created=false,properties={},sortOrder=layout and read(layout,"SortOrder")}
        if not layout then
            layout=Instance.new("UIGridLayout");layout.Name="HoneyBunSavedGridLayout";layout.CellSize=template.Size;layout.CellPadding=UDim2.fromOffset(4,4);layout.Parent=target
            state.layout=layout;state.created=true
        end
        if not effects then
            local size=read(layout,"CellSize") or template.Size
            if size then
                state.properties[layout]={CellSize=layout.CellSize,CellPadding=layout.CellPadding,FillDirectionMaxCells=layout.FillDirectionMaxCells}
                layout.FillDirectionMaxCells=5
                layout.CellPadding=UDim2.fromOffset(4,4)
                local function resizeCells()
                    local bounds=read(target,"AbsoluteSize")
                    local width=bounds and bounds.X
                    local height=type(width)=="number" and width>0 and math.max(1,math.floor(width/5-6)) or nil
                    local cell=UDim2.new(0.2,-6,height and 0 or (size.Y and size.Y.Scale or size.y or 0)*0.8,height or (size.Y and size.Y.Offset or 80)*0.8)
                    if layout.CellSize~=cell then layout.CellSize=cell end
                end
                resizeCells()
                savedConnections[#savedConnections+1]=target:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCells)
            end
        end
        layout.SortOrder=Enum.SortOrder.LayoutOrder
        savedLayouts[target]=state
        local scrolling=target
        while scrolling and scrolling~=root and not is(scrolling,"ScrollingFrame") do scrolling=scrolling.Parent end
        if scrolling and scrolling~=root then
            state.properties[scrolling]={AutomaticCanvasSize=read(scrolling,"AutomaticCanvasSize")}
            scrolling.AutomaticCanvasSize=Enum.AutomaticSize.Y
            if scrolling~=target then
                state.properties[target]=state.properties[target] or {}
                state.properties[target].AutomaticSize=read(target,"AutomaticSize")
                target.AutomaticSize=Enum.AutomaticSize.Y
            end
        end
    end
    local function savedSelection(equipped)
        for card,entry in pairs(savedEntries) do
            if alive(card) then
                for _,v in ipairs(texts(card)) do
                    if is(v,"GuiObject") and (normalize(v.Name)=="equipped" or normalize(v.Name)=="selected") then v.Visible=equipped[entry.kind]==entry.id end
                end
            end
        end
    end
    local function savedMetadataFor(entry)
        return {id=entry.id,kind=entry.kind,category=entryCategory(entry),name=entry.name,image=entry.image,previewImage=entry.previewImage,editable=entry.editable,rarity=entry.rarity,
            previewOffset=entry.previewOffset,rarityColor=entry.rarityColor,sortOrder=entry.sortOrder,rarityOrder=entry.rarityOrder,chroma=entry.chroma}
    end
    local function sameSavedMetadata(a,b)
        if not a or not b then return false end
        for key,value in pairs(b) do if a[key]~=value then return false end end
        return true
    end
    local renderSaved
    local function tabForSaved(inventory,key,detectedGrid)
        local tabs
        -- Anchor to the actual cards; the sidebar also has a Frame named Weapons.
        local area=inventory
        local ancestor=detectedGrid
        while ancestor and ancestor~=inventory do
            if normalize(ancestor.Name)=="items" then area=ancestor;break end
            ancestor=ancestor.Parent
        end
        for _,o in ipairs(descendants(area)) do
            if normalize(o.Name)=="tabs" and is(o,"GuiObject") then tabs=o;break end
        end
        if not tabs then return end
        for _,o in ipairs(children(tabs)) do
            if category(o.Name)==key then return o,tabs end
            for _,v in ipairs(texts(o)) do if category(read(v,"Text"))==key then return o,tabs end end
        end
    end
    local function savedTabText(tab)
        local changed=false
        for _,o in ipairs(texts(tab)) do
            if is(o,"TextLabel") or is(o,"TextButton") then
                local value=lower(read(o,"Text"))
                if value:find("season",1,true) or value=="current" or category(value)=="season1" then o.Text="Saved Weapons";changed=true end
            end
        end
        if not changed and (is(tab,"TextLabel") or is(tab,"TextButton")) then tab.Text="Saved Weapons" end
    end
    local function showSavedTab(open,nativeKey)
        if open and not savedOpen then
            for pane in pairs(savedNativeVisibility) do if alive(pane) then savedNativeVisibility[pane]=pane.Visible end end
        end
        savedOpen=open
        if savedPane then savedPane.Visible=open end
        for pane,visible in pairs(savedNativeVisibility) do
            if alive(pane) then
                if open then pane.Visible=false
                elseif nativeKey then pane.Visible=category(pane.Name)==nativeKey
                else pane.Visible=visible end
            end
        end
        local function tabColors(tab,selected,remember)
            local shade=selected and 12 or 48
            local edge=selected and 0 or 48
            for _,o in ipairs(texts(tab)) do
                local name=normalize(o.Name)
                local border=name:find("border",1,true) or name:find("line",1,true) or name:find("separator",1,true)
                local properties
                if o==tab or is(o,"GuiButton") then properties={BackgroundColor3=Color3.fromRGB(shade,shade,shade),BorderColor3=Color3.fromRGB(edge,edge,edge)}
                elseif is(o,"UIStroke") then properties={Color=Color3.fromRGB(edge,edge,edge)}
                elseif border and is(o,"GuiObject") then
                    properties={BackgroundColor3=Color3.fromRGB(edge,edge,edge),BorderColor3=Color3.fromRGB(edge,edge,edge)}
                    if is(o,"ImageLabel") then properties.ImageColor3=Color3.fromRGB(edge,edge,edge) end
                end
                for key,value in pairs(properties or {}) do
                    if remember then savedHeader[o]=savedHeader[o] or {};if savedHeader[o][key]==nil then savedHeader[o][key]=read(o,key) end end
                    o[key]=value
                end
            end
        end
        if savedTab then
            tabColors(savedTab,open,false)
            local shade=open and 12 or 48
            savedTab.BackgroundColor3=Color3.fromRGB(shade,shade,shade)
            for _,o in ipairs(texts(savedTab)) do
                if is(o,"GuiButton") then o.BackgroundColor3=Color3.fromRGB(shade,shade,shade) end
                local n=normalize(o.Name)
                if is(o,"GuiObject") and (n=="selected" or n=="selectedborder" or n=="selection") then o.Visible=open end
            end
        end
        for _,tab in ipairs(children(savedTabParent)) do
            local key=category(tab.Name)
            if key then
                if open or nativeKey then tabColors(tab,not open and key==nativeKey,true) end
                for _,marker in ipairs(descendants(tab)) do
                local n=normalize(marker.Name)
                if is(marker,"GuiObject") and (n=="selected" or n=="selectedborder" or n=="selection") then
                    savedHeader[marker]=savedHeader[marker] or {Visible=marker.Visible}
                    if open then marker.Visible=false elseif nativeKey then marker.Visible=key==nativeKey end
                end
            end end
        end
    end
    local function mountSavedTab(inventory,detectedGrid,detectedTemplate)
        if savedTabMode and savedTab and alive(savedTab) and savedPane and alive(savedPane) and savedGrid and alive(savedGrid) then return true end
        if savedTabMode then
            disconnect(connections);connections={};clearSaved();restoreSideSlots()
            if savedTab then destroy(savedTab) end;if savedPane then destroy(savedPane) end
            for o,props in pairs(savedHeader) do for key,value in pairs(props) do pcall(function()o[key]=value end) end end
            savedHeader={};savedNativeVisibility={};savedOpen=false;savedTabMode=false
        end
        nativeHost,nativePane=paneFor(detectedGrid,inventory)
        local source=nativePane
        assert(source and nativeHost,"Native inventory content panel was not found.")
        if not template then template=detectedTemplate and detectedTemplate:Clone() end
        assert(template,"Native item card template is unavailable.")
        local sourceGrid=detectedGrid
        local sourcePath=pathFrom(source,sourceGrid)
        savedPane=source:Clone();savedPane.Name="HoneyBunLocal_SavedPane"
        for _,o in ipairs(texts(savedPane)) do if is(o,"LuaSourceContainer") then destroy(o) end end
        savedGrid=atPath(savedPane,sourcePath)
        assert(savedGrid,"The copied native saved pane grid could not be located.")
        for _,o in ipairs(children(savedGrid)) do if is(o,"GuiObject") then destroy(o) end end
        local tab,tabs=tabForSaved(inventory,"season1",detectedGrid)
        if not tab or not tabs then destroy(savedPane);savedPane=nil;savedGrid=nil;return false end
        savedTab=tab:Clone();savedTab.Name="HoneyBunLocal_SavedTab";savedTabText(savedTab)
        -- Keep the native selected gray as the saved tab's resting color too.
        savedTab.BackgroundColor3=Color3.fromRGB(48,48,48)
        for _,o in ipairs(descendants(savedTab)) do
            if is(o,"GuiButton") then o.BackgroundColor3=Color3.fromRGB(48,48,48) end
        end
        for _,o in ipairs(texts(savedTab)) do if is(o,"LuaSourceContainer") then destroy(o) end end
        -- Fit four native-styled tabs into the space previously used by three.
        local nativeTabs={}
        for _,o in ipairs(children(tabs)) do if is(o,"GuiObject") and category(o.Name) then nativeTabs[#nativeTabs+1]=o end end
        table.sort(nativeTabs,function(a,b)return (category(a.Name)=="season1" and 1 or category(a.Name)=="classic" and 2 or 3)<(category(b.Name)=="season1" and 1 or category(b.Name)=="classic" and 2 or 3)end)
        pcall(function()
            local first,last=nativeTabs[1],nativeTabs[#nativeTabs]
            local origin=first.Position.X
            local widthScale=(last.Position.X.Scale+last.Size.X.Scale-origin.Scale)/4
            local widthOffset=(last.Position.X.Offset+last.Size.X.Offset-origin.Offset)/4
            local all={};for _,o in ipairs(nativeTabs) do all[#all+1]=o end;all[#all+1]=savedTab
            for index,o in ipairs(all) do
                if o~=savedTab then savedHeader[o]={Size=o.Size,Position=o.Position} end
                o.Size=UDim2.new(widthScale,widthOffset,o.Size.Y.Scale,o.Size.Y.Offset)
                o.Position=UDim2.new(origin.Scale+(index-1)*widthScale,origin.Offset+(index-1)*widthOffset,o.Position.Y.Scale,o.Position.Y.Offset)
                for _,label in ipairs(texts(o)) do
                    if is(label,"TextLabel") or is(label,"TextButton") then
                        if o~=savedTab then savedHeader[label]=savedHeader[label] or {};savedHeader[label].TextScaled=label.TextScaled end
                        label.TextScaled=true
                    end
                end
            end
        end)
        -- Layout-driven headers ignore Position: put Saved before Search there too.
        for index,o in ipairs(nativeTabs) do
            savedHeader[o]=savedHeader[o] or {}
            savedHeader[o].LayoutOrder=read(o,"LayoutOrder") or 0
            o.LayoutOrder=index
        end
        local nextOrder=#nativeTabs+2
        for _,o in ipairs(children(tabs)) do
            if is(o,"UIListLayout") then
                savedHeader[o]={SortOrder=o.SortOrder};o.SortOrder=Enum.SortOrder.LayoutOrder
            elseif is(o,"GuiObject") and not category(o.Name) then
                savedHeader[o]=savedHeader[o] or {};savedHeader[o].LayoutOrder=read(o,"LayoutOrder") or 0
                o.LayoutOrder=nextOrder;nextOrder=nextOrder+1
            end
        end
        savedTab.LayoutOrder=#nativeTabs+1;savedTab.Parent=tabs;savedTabParent=tabs
        savedPane.Parent=nativeHost;savedPane.Visible=false
        for _,pane in ipairs(children(nativeHost)) do
            if pane~=savedPane and is(pane,"GuiObject") and category(pane.Name) then
                if savedNativeVisibility[pane]==nil then savedNativeVisibility[pane]=pane.Visible end
            end
        end
        local function bindTab(o)
            if is(o,"GuiButton") then
                connections[#connections+1]=o.Activated:Connect(function() showSavedTab(true) end)
                local click=read(o,"MouseButton1Click");if click then connections[#connections+1]=click:Connect(function() showSavedTab(true) end) end
            end
        end
        for _,o in ipairs(texts(savedTab)) do bindTab(o) end
        for _,o in ipairs(descendants(tabs)) do
            if not localObject(o) and is(o,"GuiButton") then
                -- Keep the native game tab behavior; this callback only closes our pane.
                local key=category(o.Name) or category(o.Parent and o.Parent.Name) or category(read(o,"Text"))
                if key then
                    local function selectNative() showSavedTab(false,key) end
                    connections[#connections+1]=o.Activated:Connect(selectNative)
                    local click=read(o,"MouseButton1Click");if click then connections[#connections+1]=click:Connect(selectNative) end
                end
            end
        end
        for _,o in ipairs(descendants(inventory)) do
            if is(o,"TextBox") and (lower(o.Name):find("search",1,true) or lower(o.PlaceholderText):find("search",1,true)) then
                query=lower(o.Text);connections[#connections+1]=o:GetPropertyChangedSignal("Text"):Connect(function() query=lower(o.Text);renderSaved() end);break
            end
        end
        connections[#connections+1]=savedPane:GetPropertyChangedSignal("Visible"):Connect(function() if enabled and savedPane.Visible~=savedOpen then savedPane.Visible=savedOpen end end)
        showSavedTab(false)
        savedTabMode=true
        return true
    end
    renderSaved=function()
        if not enabled or dead then return end
        local inventory,detectedGrid,detectedTemplate
        if effects then inventory,detectedGrid,detectedTemplate=detect() else inventory,detectedGrid,detectedTemplate=detectWeapon() end
        if not inventory then status("Waiting for MM2 Weapons inventory to load.");return end
        if savedRoot and savedRoot~=inventory then
            clearSaved()
        end
        if savedRoot~=inventory and savedOnly then
            -- Remove cards left by an older hub before mounting the dedicated tab.
            for _,object in ipairs(descendants(inventory)) do
                if tostring(object.Name):sub(1,#"HoneyBunLocal_Saved_")=="HoneyBunLocal_Saved_" then destroy(object) end
            end
        end
        savedRoot=inventory
        root=inventory
        if savedOnly and not effects and not mountSavedTab(inventory,detectedGrid,detectedTemplate) then
            clearSaved()
            status("Waiting for MM2's weapon tabs. Saved cards will appear only in Saved Weapons.")
            return
        end
        if not template then template=detectedTemplate and detectedTemplate:Clone() end
        if not template then status("Waiting for native weapon cards to load.");return end
        local grids=effects and {effects=detectedGrid} or (savedTabMode and {saved=savedGrid} or findSavedGrids(inventory));savedGrids=grids
        for _,target in pairs(grids) do prepareSavedGrid(target) end
        bindSideSlots()
        local wanted={}
        local pending={}
        for _,kind in ipairs(effects and {"Effect"} or {"Knife","Gun"}) do
            for _,entry in ipairs(catalog.list(kind) or {}) do
                local key=entryCategory(entry);local target=grids[key]
                if target and (query=="" or lower(entry.name):find(query,1,true) or lower(entry.id):find(query,1,true)) then
                    local id=kind..":"..tostring(entry.id)
                    wanted[id]=true
                    pending[#pending+1]={id=id,entry=entry,target=target}
                end
            end
        end
        table.sort(pending,function(a,b)return compare(a.entry,b.entry) end)
        local orders={}
        for _,item in ipairs(pending) do
            if not orders[item.target] then
                local maxOrder=0;for _,child in ipairs(children(item.target)) do if is(child,"GuiObject") and not own(child) and type(read(child,"LayoutOrder"))=="number" then maxOrder=math.max(maxOrder,child.LayoutOrder) end end
                orders[item.target]=maxOrder
            end
            orders[item.target]=orders[item.target]+1
            local id,entry,target=item.id,item.entry,item.target
                    local existing=savedCards[id]
                    local metadata=savedMetadataFor(entry)
                    if existing and (not alive(existing) or not sameSavedMetadata(savedMetadata[id],metadata)) then
                        destroy(existing);savedCards[id]=nil;savedEntries[existing]=nil
                        savedMetadata[id]=nil
                        if savedCardConnections[id] then disconnect(savedCardConnections[id]);savedCardConnections[id]=nil end
                    end
                    if not savedCards[id] or not alive(savedCards[id]) then
                        local card=template:Clone();savedCards[id]=card;savedEntries[card]=entry
                        local rarityColor=entryColor(entry)
                        if not effects then
                            card.BorderColor3=rarityColor
                            for _,edge in ipairs(descendants(card)) do
                                if is(edge,"UIStroke") then edge.Color=rarityColor end
                            end
                        end
                        card.Name="HoneyBunLocal_Saved_"..entry.kind.."_"..tostring(entry.id);card.Visible=true
                        for _,v in ipairs(texts(card)) do
                            if (is(v,"TextLabel") or is(v,"TextButton")) and (v.Text=="Default Knife" or v.Text=="Default Gun" or normalize(v.Name)=="itemname") then
                                v.Text=effects and entry.name or ""
                                if not effects then v.Visible=false end
                                if rarityColor then
                                    pcall(function()v.BackgroundColor3=rarityColor;v.BackgroundTransparency=0 end)
                                    if not effects then
                                        v.BorderSizePixel=0;v.BorderColor3=rarityColor
                                        local bar=read(v,"Parent")
                                        if bar~=card and is(bar,"GuiObject") then bar.BackgroundTransparency=1;bar.BorderColor3=rarityColor end
                                        for _,decoration in ipairs(descendants(v)) do if is(decoration,"UIGradient") then decoration.Enabled=false end end
                                    end
                                    pcall(function()v.TextColor3=Color3.fromRGB(255,255,255)end)
                                end
                            end
                            if (is(v,"TextLabel") or is(v,"TextButton")) and normalize(v.Name)=="rarity" then
                                if not effects then v.Text="";v.Visible=false
                                else v.Text=tostring(entry.rarity or "");if rarityColor then v.TextColor3=rarityColor end end
                            end
                            if is(v,"LuaSourceContainer") then destroy(v) end
                        end
                        local hasRarity=false
                        for _,v in ipairs(texts(card)) do if (is(v,"TextLabel") or is(v,"TextButton")) and normalize(v.Name)=="rarity" then hasRarity=true end end
                        if effects and not hasRarity and entry.rarity then
                            local rarity=Instance.new("TextLabel");rarity.Name="Rarity";rarity.BackgroundTransparency=1;rarity.Text=tostring(entry.rarity)
                            if rarityColor then rarity.TextColor3=rarityColor end
                            rarity.Size=UDim2.fromScale(0.42,0.16);rarity.Position=UDim2.fromScale(0.58,0.02);rarity.TextScaled=true;rarity.TextStrokeTransparency=0.5
                            if entry.rarityColor then pcall(function()rarity.BackgroundColor3=entry.rarityColor end) end
                            rarity.Parent=card
                        end
                        local image=entry.image or entry.previewImage;if type(image)=="number" or (type(image)=="string" and image:match("^%d+$")) then image="rbxassetid://"..tostring(image) end
                        local targetIcon=icon(card);if targetIcon then targetIcon.Image=type(image)=="string" and image or "" end
                        if not effects then
                            card.BackgroundTransparency=1;card.ClipsDescendants=true
                            -- The native card reserves its bottom fifth for the old name bar.
                            -- Expand the preview into our shorter cell and discard that footer.
                            for _,object in ipairs(descendants(card)) do
                                local name=normalize(object.Name)
                                if is(object,"GuiObject") and (name:find("name",1,true) or name:find("rarity",1,true) or name:find("footer",1,true)) then object.Visible=false end
                            end
                            local preview=targetIcon
                            while preview and preview~=card do
                                preview.Size=UDim2.fromScale(1,1);preview.Position=UDim2.fromScale(0,0);preview.AnchorPoint=Vector2.new(0,0)
                                preview=preview.Parent
                            end
                        end
                        savedModelIcon(card,targetIcon,entry)
                        if not entry.image and entry.previewImage then
                            local label=Instance.new("TextLabel");label.Name="HoneyBunParticlePreview";label.Text="Particle preview"
                            label.BackgroundTransparency=1;label.TextColor3=Color3.fromRGB(220,220,220);label.TextScaled=true
                            label.Size=UDim2.fromScale(1,0.14);label.Position=UDim2.fromScale(0,0.02);label.Parent=card
                        end
                        local click=overlay(card)
                        savedCardConnections[id]={click.Activated:Connect(function()
                            if openOptions then openOptions.Visible=false;openOptions=nil end
                            local good,result=pcall(catalog.equip or catalog.preview,entry.id,entry.kind)
                            status(good and (result or "Local item selected.") or ("Could not equip locally: "..tostring(result)))
                            if good then local selection=catalog.getEquipped and catalog.getEquipped() or {};savedSelection(selection);updateSideSlots(selection) end
                        end)}
                        if catalog.remove and (not effects or entry.editable) then
                            local menu=Instance.new("Frame");menu.Name="HoneyBunSavedOptionsMenu";menu.Visible=false;menu.Active=true
                            menu.Size=UDim2.fromScale(1,1);menu.BackgroundColor3=Color3.fromRGB(16,17,21);menu.BackgroundTransparency=0
                            menu.BorderSizePixel=0;menu.ZIndex=click.ZIndex+1;menu.Parent=card
                            local function bind(button,callback) savedCardConnections[id][#savedCardConnections[id]+1]=button.Activated:Connect(callback) end
                            local tweenService
                            pcall(function()tweenService=game:GetService("TweenService")end)
                            local function option(name,text,y)
                                local o=Instance.new("TextButton");o.Name=name;o.Text=text;o.TextScaled=false;o.TextSize=12
                                o.Size=UDim2.fromScale(0.9,0.15);o.Position=UDim2.fromScale(0.05,y);o.BackgroundTransparency=0
                                local base=Color3.fromRGB(43,48,58);local hover=Color3.fromRGB(62,80,105)
                                o.BackgroundColor3=base;o.BorderSizePixel=0;o.AutoButtonColor=false
                                pcall(function()o.Font=Enum.Font.SourceSansSemibold end)
                                o.TextColor3=Color3.fromRGB(245,245,250);o.ZIndex=click.ZIndex+2;o.Parent=menu
                                local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,4);corner.Parent=o
                                local scale=Instance.new("UIScale");scale.Scale=1;scale.Parent=o
                                local tweens={}
                                local function animate(object,properties,duration)
                                    if tweens[object] then tweens[object]:Cancel() end
                                    local good=pcall(function()
                                        assert(tweenService)
                                        local tween=tweenService:Create(object,TweenInfo.new(duration or 0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
                                        tweens[object]=tween;tween:Play()
                                    end)
                                    if not good then for key,value in pairs(properties) do object[key]=value end end
                                end
                                local function event(name,fn)
                                    local signal=read(o,name)
                                    if signal then savedCardConnections[id][#savedCardConnections[id]+1]=signal:Connect(fn) end
                                end
                                event("MouseEnter",function()animate(o,{BackgroundColor3=hover})end)
                                event("MouseLeave",function()animate(o,{BackgroundColor3=base});animate(scale,{Scale=1})end)
                                event("MouseButton1Down",function()animate(scale,{Scale=0.93},0.08)end)
                                event("MouseButton1Up",function()animate(scale,{Scale=1},0.16)end)
                                bind(o,function()scale.Scale=0.93;animate(scale,{Scale=1},0.18)end)
                                return o
                            end
                            local adjustmentButtons={}
                            if not effects and catalog.openEditor then
                                for _,action in ipairs({{"HoneyBunAdjustPreview","Adjust placement","Holster",0.25},{"HoneyBunAdjustHolding","Adjust holding","Held",0.43}}) do
                                    local button=option(action[1],action[2],action[4]);adjustmentButtons[#adjustmentButtons+1]=button
                                    local editMode=action[3]
                                    bind(button,function()
                                        menu.Visible=false;openOptions=nil
                                        local good,result=pcall(catalog.openEditor,entry,editMode)
                                        if not good then status("Could not open weapon editor: "..tostring(result)) end
                                    end)
                                end
                            end
                            local rename=option("HoneyBunRenameSaved","Rename",0.61)
                            local remove=option("HoneyBunDeleteSaved","Delete",0.79)
                            local field=Instance.new("TextBox");field.Name="HoneyBunSavedName";field.Text=entry.name;field.ClearTextOnFocus=false
                            field.Size=UDim2.fromScale(0.9,0.22);field.Position=UDim2.fromScale(0.05,0.28);field.TextScaled=true
                            field.TextColor3=Color3.fromRGB(245,245,250);field.BackgroundColor3=Color3.fromRGB(35,36,40)
                            field.ZIndex=click.ZIndex+2;field.Visible=false;field.Parent=menu
                            local save=option("HoneyBunSaveName","Save",0.55)
                            local cancel=option("HoneyBunCancelSaved","Cancel",0.77)
                            local function reset()
                                rename.Visible=catalog.rename~=nil;remove.Visible=true;remove.Text="Delete"
                                for _,button in ipairs(adjustmentButtons) do button.Visible=true end
                                field.Visible=false;save.Visible=false;cancel.Visible=false;field.Text=entry.name
                            end
                            bind(rename,function()
                                rename.Visible=false;remove.Visible=false;field.Visible=true;save.Visible=true;cancel.Visible=true
                                for _,button in ipairs(adjustmentButtons) do button.Visible=false end
                                pcall(function()field:CaptureFocus()end)
                            end)
                            bind(save,function()
                                local good,result=pcall(catalog.rename,entry.id,field.Text)
                                if good then menu.Visible=false;openOptions=nil;renderSaved() end
                                status(good and (result or "Saved name updated.") or ("Could not rename: "..tostring(result)))
                            end)
                            bind(cancel,function()reset();menu.Visible=false;openOptions=nil end)
                            bind(remove,function()
                                if remove.Text~="Confirm delete" then remove.Text="Confirm delete";rename.Visible=false;cancel.Visible=true;for _,button in ipairs(adjustmentButtons) do button.Visible=false end;return end
                                local good,result=pcall(catalog.remove,entry.id)
                                if good then openOptions=nil;renderSaved() else reset() end
                                status(good and (result or "Saved item deleted.") or ("Could not delete: "..tostring(result)))
                            end)
                            local cog=Instance.new("TextButton");cog.Name="HoneyBunSavedOptions";cog.Text="\226\154\153"
                            cog.Size=UDim2.fromOffset(30,30);cog.Position=UDim2.new(1,-31,0,1)
                            cog.BackgroundTransparency=1;cog.TextColor3=Color3.fromRGB(205,208,218);cog.TextSize=20
                            pcall(function()cog.Font=Enum.Font.Gotham end)
                            cog.ZIndex=click.ZIndex+3;cog.Parent=card
                            local cogScale=Instance.new("UIScale");cogScale.Scale=1;cogScale.Parent=cog
                            local cogTween,scaleTween
                            bind(cog,function()
                                local rotation=(read(cog,"Rotation") or 0)+90
                                if cogTween then cogTween:Cancel() end;if scaleTween then scaleTween:Cancel() end
                                cogScale.Scale=0.84
                                local animated=pcall(function()
                                    assert(tweenService)
                                    cogTween=tweenService:Create(cog,TweenInfo.new(0.26,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Rotation=rotation})
                                    scaleTween=tweenService:Create(cogScale,TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
                                    cogTween:Play();scaleTween:Play()
                                end)
                                if not animated then cog.Rotation=rotation;cogScale.Scale=1 end
                                local show=not menu.Visible;if openOptions then openOptions.Visible=false end
                                reset();menu.Visible=show;openOptions=show and menu or nil
                            end)
                            reset()
                        end
                        card.Parent=target
                    end
                    local card=savedCards[id]
                    if card.Parent~=target then card.Parent=target end
                    savedEntries[card]=entry;savedMetadata[id]=metadata;card.LayoutOrder=orders[target]
            end
        for id,card in pairs(savedCards) do
            if not wanted[id] or not alive(card) then
                destroy(card);savedCards[id]=nil;savedEntries[card]=nil;savedMetadata[id]=nil
                if savedCardConnections[id] then disconnect(savedCardConnections[id]);savedCardConnections[id]=nil end
            end
        end
        for card in pairs(savedEntries) do if not alive(card) then savedEntries[card]=nil end end
        local equipped=catalog.getEquipped and catalog.getEquipped() or {}
        savedSelection(equipped)
        updateSideSlots(equipped)
        local count=0;for _ in pairs(savedCards) do count=count+1 end
        status("MM2 native collection: "..count.." saved "..(effects and "effect" or "weapon").." cards.")
    end
    local render
    render=function()
        assert(grid and alive(grid),"MM2 inventory is being rebuilt.")
        clearCards()
        local generation=renderGeneration
        local renderSeason,renderQuery=season,query
        renderPasses=renderPasses+1
        if not catalogItems then
            catalogItems={}
            for _,kind in ipairs(effects and {"Effect"} or {"Knife","Gun"}) do
                local list=catalog.list(kind)
                assert(type(list)=="table","MM2 catalog did not return an item list.")
                for _,entry in ipairs(list) do catalogItems[#catalogItems+1]=entry end
            end
            categoryCounts={season1=0,classic=0,holiday=0,effects=0}
            for _,entry in ipairs(catalogItems) do local key=entryCategory(entry);categoryCounts[key]=categoryCounts[key]+1 end
            table.sort(catalogItems,compare)
        end
        local items=catalogItems
        local equipped=catalog.getEquipped and catalog.getEquipped() or {}
        local ok,message=pcall(function()
            for _,entry in ipairs(items) do
                if entryCategory(entry)==renderSeason and (renderQuery=="" or lower(entry.name):find(renderQuery,1,true) or lower(entry.id):find(renderQuery,1,true)) then
                    if #cards>0 and #cards%24==0 and type(task.wait)=="function" then task.wait() end
                    if generation~=renderGeneration or not enabled or dead then return end
                    local card=template:Clone()
                    cards[#cards+1]=card
                    cardEntries[card]=entry
                    card.Name="HoneyBunLocal_"..entry.kind.."_"..tostring(entry.id)
                    card.Visible=true;card.LayoutOrder=#cards
                    for _,v in ipairs(texts(card)) do
                        if (is(v,"TextLabel") or is(v,"TextButton")) and (v.Text=="Default Knife" or v.Text=="Default Gun" or (effects and normalize(v.Name)=="itemname")) then
                            v.Text=entry.name
                            if entry.rarityColor then v.TextColor3=entry.rarityColor end
                        end
                        if effects and (is(v,"TextLabel") or is(v,"TextButton")) and normalize(v.Name)=="rarity" then v.Text=tostring(entry.rarity or "") end
                        if is(v,"GuiObject") and (normalize(v.Name)=="equipped" or normalize(v.Name)=="selected") then v.Visible=equipped[entry.kind]==entry.id end
                    end
                    local image=entry.image
                    if type(image)=="number" or (type(image)=="string" and image:match("^%d+$")) then image="rbxassetid://"..tostring(image) end
                    local target=icon(card)
                    if target then target.Image=type(image)=="string" and image or "" end
                    local button=overlay(card)
                    cardConnections[#cardConnections+1]=button.Activated:Connect(function()
                        local good,result=pcall(catalog.equip or catalog.preview,entry.id,entry.kind)
                        status(good and (result or "Local item selected.") or ("Could not equip locally: "..tostring(result)))
                        if good then
                            local equipped=catalog.getEquipped and catalog.getEquipped() or {}
                            updateSelection(equipped);updateSideSlots(equipped)
                        end
                    end)
                    card.Parent=grid
                end
            end
        end)
        if not ok then clearCards();error(message) end
        if generation==renderGeneration and enabled then renderedSeason=renderSeason;renderedQuery=renderQuery end
        return #cards,#items
    end
    local refresh
    local function schedule()
        if not enabled or mounting or queued or dead then return end
        queued=true
        task.defer(function()
            queued=false
            if enabled and not dead then
                local ok,message
                if savedOnly then ok,message=pcall(renderSaved) else ok,message=pcall(refresh) end
                if not ok then status("Waiting for MM2 inventory: "..tostring(message)) end
            end
        end)
    end
    local function releaseMount()
        disconnect(connections);connections={};clearCards();restoreSideSlots()
        for o,props in pairs(savedHeader) do for key,value in pairs(props) do pcall(function()o[key]=value end) end end
        savedHeader={}
        if savedTab then destroy(savedTab);savedTab=nil end
        if savedPane then destroy(savedPane);savedPane=nil;savedGrid=nil end
        for pane,visible in pairs(savedNativeVisibility) do pcall(function() pane.Visible=visible end) end
        savedNativeVisibility={};savedOpen=false;savedTabParent=nil;savedTabMode=false
        if ownedRoot then destroy(ownedRoot);ownedRoot=nil end
        for o,visible in pairs(originals) do pcall(function() o.Visible=visible end) end
        originals={};grid=nil
    end
    local function hidePane(o)
        if originals[o]==nil then originals[o]=o.Visible end
        o.Visible=false
        connections[#connections+1]=o:GetPropertyChangedSignal("Visible"):Connect(function()
            if enabled and o.Visible then o.Visible=false end
        end)
    end
    local function buttonCategory(button)
        local ancestor=button
        while ancestor and ancestor~=root do
            if originals[ancestor]~=nil then return nil end
            ancestor=ancestor.Parent
        end
        local key=category(read(button,"Text")) or category(button.Name)
        if key then return key end
        for _,o in ipairs(descendants(button)) do
            key=category(read(o,"Text"))
            if key then return key end
        end
        ancestor=button.Parent
        for _=1,3 do
            if not ancestor or ancestor==root then break end
            key=category(ancestor.Name)
            if key then return key end
            for _,label in ipairs(children(ancestor)) do
                if is(label,"TextLabel") then
                    key=category(label.Text)
                    if key then return key end
                end
            end
            ancestor=ancestor.Parent
        end
    end
    local function bindControls()
        tabBindings={}
        for _,o in ipairs(descendants(root)) do
            if not localObject(o) then
                if is(o,"TextBox") and (lower(o.Name):find("search",1,true) or lower(o.PlaceholderText):find("search",1,true)) then
                    query=lower(o.Text)
                    connections[#connections+1]=o:GetPropertyChangedSignal("Text"):Connect(function() query=lower(o.Text);schedule() end)
                elseif is(o,"GuiButton") and not effects then
                    local key=buttonCategory(o)
                    if key then
                        tabBindings[#tabBindings+1]=key.."="..o:GetFullName()
                        connections[#connections+1]=o.Activated:Connect(function() season=key;schedule() end)
                    end
                end
            end
        end
        if is(root,"GuiObject") then connections[#connections+1]=root:GetPropertyChangedSignal("Visible"):Connect(schedule) end
    end
    local function mount()
        local source=atPath(playerGui,panePath)
        local originalGrid=atPath(source,gridPath)
        local detectedTemplate
        if not source or not originalGrid or not alive(originalGrid) then
            local detectedRoot,nativeGrid,card=detect()
            assert(nativeGrid,"Open MM2's "..(effects and "Effects" or "Weapons").." inventory so its item panel can be detected.")
            root=detectedRoot
            nativeHost,nativePane=paneFor(nativeGrid,root)
            source=nativePane;originalGrid=nativeGrid;detectedTemplate=card
            panePath=pathFrom(playerGui,source);gridPath=pathFrom(source,originalGrid)
        else
            nativePane=source;nativeHost=source.Parent
            if effects then
                local ancestor=originalGrid
                while ancestor do
                    if normalize(ancestor.Name)=="effects" then root=ancestor;break end
                    ancestor=ancestor.Parent
                end
            else root=inventoryAncestor(originalGrid) or root end
        end
        assert(source and nativeHost,"Native inventory content panel was not found.")
        if not template then
            assert(detectedTemplate,"Native item card template is unavailable.")
            template=detectedTemplate:Clone()
        end
        ownedRoot=source:Clone();ownedRoot.Name=effects and "HoneyBunLocal_Effects" or "HoneyBunLocal_Collection"
        for _,o in ipairs(texts(ownedRoot)) do if is(o,"LuaSourceContainer") then destroy(o) end end
        grid=atPath(ownedRoot,gridPath)
        assert(grid,"The copied native item grid could not be located.")
        for _,o in ipairs(children(grid)) do if is(o,"GuiObject") then destroy(o) end end
        local layout=grid:FindFirstChildOfClass("UIGridLayout")
        if not layout then
            layout=Instance.new("UIGridLayout");layout.CellSize=template.Size;layout.CellPadding=UDim2.fromOffset(4,4);layout.Parent=grid
        end
        layout.SortOrder=Enum.SortOrder.LayoutOrder
        local scrolling=grid
        while scrolling and scrolling~=ownedRoot.Parent and not is(scrolling,"ScrollingFrame") do scrolling=scrolling.Parent end
        if scrolling then
            scrolling.AutomaticCanvasSize=Enum.AutomaticSize.Y
            if scrolling~=grid then grid.AutomaticSize=Enum.AutomaticSize.Y end
        end
        ownedRoot.Visible=true
        for _,o in ipairs(children(nativeHost)) do
            if is(o,"GuiObject") and not own(o) and (o==source or (category(o.Name) and not is(o,"GuiButton"))) then hidePane(o) end
        end
        ownedRoot.Parent=nativeHost
        bindSideSlots()
        connections[#connections+1]=ownedRoot:GetPropertyChangedSignal("Visible"):Connect(schedule)
        bindControls()
    end
    refresh=function()
        if rendering then rerenderRequested=true;return lastReport end
        if not ownedRoot or not alive(ownedRoot) then
            mounting=true
            releaseMount()
            local ok,message=pcall(mount)
            mounting=false
            if not ok then releaseMount();error(message) end
        end
        ownedRoot.Visible=true
        for pane in pairs(originals) do pcall(function() pane.Visible=false end) end
        local n,total=#cards,catalogItems and #catalogItems or 0
        if renderedSeason~=season or renderedQuery~=query then
            rendering=true
            local ok,count,all=pcall(render)
            rendering=false
            if not ok then error(count) end
            if not enabled or dead then return lastReport end
            n,total=count,all
        end
        assert(total>0,"MM2's database returned no "..(effects and "effects" or "knife/gun cosmetics")..". Copy MM2 report for details.")
        local equipped=catalog.getEquipped and catalog.getEquipped() or {}
        updateSelection(equipped);updateSideSlots(equipped)
        if rerenderRequested then rerenderRequested=false;schedule() end
        status("MM2 "..season.." inventory: "..n.." local cosmetic cards.")
        return lastReport
    end
    local watchers={}
    local function watchSaved()
        local function changed(o)
            if not localObject(o) and (inventoryAncestor(o) or lower(o.Name):find("inventory",1,true)) then schedule() end
        end
        watchers[#watchers+1]=playerGui.DescendantAdded:Connect(changed)
        watchers[#watchers+1]=playerGui.DescendantRemoving:Connect(function(o)
            changed(o)
            if enabled and (o==savedTab or o==savedPane) then schedule() end
            if enabled then for _,card in pairs(savedCards) do if card==o then schedule();break end end end
        end)
    end
    function api.refreshSaved()
        assert(savedOnly,"refreshSaved is available only in saved mode")
        catalogItems=nil
        if enabled then renderSaved() end
        return #savedConnections
    end
    function api.disable()
        enabled=false;queued=false;rerenderRequested=false;catalogItems=nil
        disconnect(watchers);watchers={};releaseMount()
        clearSaved();restoreSideSlots()
        savedRoot=nil;savedGrids={}
        if template then destroy(template);template=nil end
        panePath,gridPath=nil,nil
        return "Original MM2 inventory display restored."
    end
    function api.enable()
        assert(not dead,"MM2 inventory preview was closed.")
        if savedOnly then
            if enabled then renderSaved();return true,lastReport end
            enabled=true;watchSaved();renderSaved()
            return true,lastReport
        end
        if enabled then local ok,message=pcall(refresh);return ok,message end
        enabled=true;query="";season=initialCategory
        local ok,message=pcall(refresh)
        if not ok then
            diagnosticDetails=tostring(message).."\n"..inventoryTree()
            api.disable()
            local reason=tostring(message)
            for _=1,3 do reason=reason:gsub("^.-:%d+:%s*","") end
            status(reason)
            return false,lastReport
        end
        diagnosticDetails=""
        if not enabled then return false,"Inventory loading cancelled." end
        local function changed(o)
            if not mounting and not localObject(o) and (inventoryAncestor(o) or lower(o.Name):find("inventory",1,true)) then schedule() end
        end
        watchers[#watchers+1]=playerGui.DescendantAdded:Connect(changed)
        watchers[#watchers+1]=playerGui.DescendantRemoving:Connect(changed)
        return true,message
    end
    function api.report()
        if savedOnly then
            local count=0;for _,card in pairs(savedCards) do if alive(card) then count=count+1 end end
            if savedTabMode then return "Native inventory build: saved weapons V3\n"..lastReport.."\nGenerated="..count.."\nSaved pane: "..(savedGrid and savedGrid:GetFullName() or "none") end
            local paths={};for _,key in ipairs(effects and {"effects"} or {"season1","classic","holiday"}) do paths[#paths+1]=key.."="..(savedGrids[key] and savedGrids[key]:GetFullName() or "none") end
            return "Native inventory build: "..(effects and "saved effects V4" or "saved weapons V3").."\n"..lastReport.."\nGenerated="..count.."\nCategory grids: "..table.concat(paths,"; ")
        end
        return "Native inventory build: weapons and effects V9\n"..lastReport.."\nCategory="..season.."\nGrid="..(grid and grid:GetFullName() or "none").."\nRender passes="..renderPasses.."\nGenerated="..#cards.."\nFiltered counts: Season1="..categoryCounts.season1.." Classic="..categoryCounts.classic.." Holiday="..categoryCounts.holiday.." Effects="..tostring(categoryCounts.effects or 0).."\nBound side slots: Knife="..(sideSlots.Knife and sideSlots.Knife:GetFullName() or "none").." Gun="..(sideSlots.Gun and sideSlots.Gun:GetFullName() or "none").." Effect="..(sideSlots.Effect and sideSlots.Effect:GetFullName() or "none").."\nSide candidates: "..table.concat(sideCandidates,"; ").."\nBound tabs: "..table.concat(tabBindings,"; ")..(diagnosticDetails~="" and ("\nInventory diagnostics:\n"..diagnosticDetails) or "")
    end
    function api.destroy() if not dead then api.disable();dead=true end end
    return api
end
