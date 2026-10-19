-- Local cards in the existing MM2 Weapons inventory; no ownership or remote changes.
return function(playerGui,catalog,onStatus)
    local api={}
    local enabled,dead=false,false
    local grid,template,root,ownedRoot,nativePane,nativeHost
    local panePath,gridPath
    local mounting,queued=false,false
    local cards,originals,connections,cardConnections={},{},{},{}
    local query,season="","season1"
    local lastReport="Native inventory has not been detected yet."
    local tabBindings,categoryCounts={},{season1=0,classic=0,holiday=0}
    local function read(o,k) local ok,v=pcall(function() return o[k] end);if ok then return v end end
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
    local function detect()
        for _,label in ipairs(descendants(playerGui)) do
            if (is(label,"TextLabel") or is(label,"TextButton")) and (label.Text=="Default Knife" or label.Text=="Default Gun") then
                local inventory=inventoryAncestor(label)
                if inventory then
                    local card=label
                    while card.Parent and card.Parent~=inventory.Parent do
                        local container=card.Parent
                        if is(card,"GuiObject") then
                            if container:FindFirstChildOfClass("UIGridLayout") then return inventory,container,card end
                            local knife,gun
                            for _,sibling in ipairs(children(container)) do
                                if is(sibling,"GuiObject") then
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
        if v=="season1" or v=="1" then return "season1" end
        if v=="classic" or v=="0" then return "classic" end
        if v=="holiday" or v:find("halloween",1,true) or v:find("christmas",1,true) then return "holiday" end
    end
    local function entryCategory(entry)
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
    local function clearCards()
        disconnect(cardConnections);cardConnections={}
        for _,card in ipairs(cards) do destroy(card) end
        cards={}
    end
    local render
    render=function()
        assert(grid and alive(grid),"MM2 inventory is being rebuilt.")
        clearCards()
        local items={}
        for _,kind in ipairs({"Knife","Gun"}) do
            local list=catalog.list(kind)
            assert(type(list)=="table","MM2 catalog did not return an item list.")
            for _,entry in ipairs(list) do items[#items+1]=entry end
        end
        categoryCounts={season1=0,classic=0,holiday=0}
        for _,entry in ipairs(items) do local key=entryCategory(entry);categoryCounts[key]=categoryCounts[key]+1 end
        table.sort(items,compare)
        local equipped=catalog.getEquipped and catalog.getEquipped() or {}
        local ok,message=pcall(function()
            for _,entry in ipairs(items) do
                if entryCategory(entry)==season and (query=="" or lower(entry.name):find(query,1,true) or lower(entry.id):find(query,1,true)) then
                    local card=template:Clone()
                    cards[#cards+1]=card
                    card.Name="HoneyBunLocal_"..entry.kind.."_"..tostring(entry.id)
                    card.Visible=true;card.LayoutOrder=#cards
                    for _,v in ipairs(texts(card)) do
                        if (is(v,"TextLabel") or is(v,"TextButton")) and (v.Text=="Default Knife" or v.Text=="Default Gun") then
                            v.Text=entry.name
                            if entry.rarityColor then v.TextColor3=entry.rarityColor end
                        end
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
                            local shown=lastReport
                            local refreshed,err=pcall(render)
                            if not refreshed then status(err) else status(shown) end
                        end
                    end)
                    card.Parent=grid
                end
            end
        end)
        if not ok then clearCards();error(message) end
        return #cards,#items
    end
    local refresh
    local function schedule()
        if not enabled or mounting or queued or dead then return end
        queued=true
        task.defer(function()
            queued=false
            if enabled and not dead then
                local ok,message=pcall(refresh)
                if not ok then status("Waiting for MM2 inventory: "..tostring(message)) end
            end
        end)
    end
    local function releaseMount()
        disconnect(connections);connections={};clearCards()
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
                elseif is(o,"GuiButton") then
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
            assert(nativeGrid,"Open MM2's Weapons inventory so its item panel can be detected.")
            root=detectedRoot
            nativeHost,nativePane=paneFor(nativeGrid,root)
            source=nativePane;originalGrid=nativeGrid;detectedTemplate=card
            panePath=pathFrom(playerGui,source);gridPath=pathFrom(source,originalGrid)
        else
            nativePane=source;nativeHost=source.Parent
            root=inventoryAncestor(originalGrid) or root
        end
        assert(source and nativeHost,"Native inventory content panel was not found.")
        if not template then
            assert(detectedTemplate,"Native item card template is unavailable.")
            template=detectedTemplate:Clone()
        end
        ownedRoot=source:Clone();ownedRoot.Name="HoneyBunLocal_Collection"
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
        connections[#connections+1]=ownedRoot:GetPropertyChangedSignal("Visible"):Connect(schedule)
        bindControls()
    end
    refresh=function()
        if not ownedRoot or not alive(ownedRoot) then
            mounting=true
            releaseMount()
            local ok,message=pcall(mount)
            mounting=false
            if not ok then releaseMount();error(message) end
        end
        ownedRoot.Visible=true
        for pane in pairs(originals) do pcall(function() pane.Visible=false end) end
        local n,total=render()
        assert(total>0,"MM2's item database returned no knife/gun cosmetics. Copy MM2 report for details.")
        status("MM2 "..season.." inventory: "..n.." local cosmetic cards.")
        return lastReport
    end
    local watchers={}
    function api.disable()
        enabled=false;queued=false
        disconnect(watchers);watchers={};releaseMount()
        if template then destroy(template);template=nil end
        panePath,gridPath=nil,nil
        return "Original MM2 inventory display restored."
    end
    function api.enable()
        assert(not dead,"MM2 inventory preview was closed.")
        if enabled then local ok,message=pcall(refresh);return ok,message end
        enabled=true;query="";season="season1"
        local ok,message=pcall(refresh)
        if not ok then api.disable();status("MM2 inventory could not load: "..tostring(message).."\n"..inventoryTree());return false,lastReport end
        local function changed(o)
            if not mounting and not localObject(o) and (inventoryAncestor(o) or lower(o.Name):find("inventory",1,true)) then schedule() end
        end
        watchers[#watchers+1]=playerGui.DescendantAdded:Connect(changed)
        watchers[#watchers+1]=playerGui.DescendantRemoving:Connect(changed)
        return true,message
    end
    function api.report()
        return "Native inventory build: labelled category buttons V4\n"..lastReport.."\nCategory="..season.."\nGrid="..(grid and grid:GetFullName() or "none").."\nGenerated="..#cards.."\nFiltered counts: Season1="..categoryCounts.season1.." Classic="..categoryCounts.classic.." Holiday="..categoryCounts.holiday.."\nBound tabs: "..table.concat(tabBindings,"; ")
    end
    function api.destroy() if not dead then api.disable();dead=true end end
    return api
end
