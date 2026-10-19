-- Local cards in the existing MM2 Weapons inventory; no ownership or remote changes.
return function(playerGui,catalog,onStatus)
    local api={}
    local enabled,dead=false,false
    local grid,template,root,ownedLayout,scroll,scrollState,gridState
    local cards,originals,connections,cardConnections={},{},{},{}
    local query,season="",nil
    local lastReport="Native inventory has not been detected yet."
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
    local function hideOriginal(o)
        if is(o,"GuiObject") and not own(o) then
            if originals[o]==nil then originals[o]=o.Visible end
            o.Visible=false
        end
    end
    local function seasonMatches(value)
        if not season or value==nil then return true end
        local v=normalize(value)
        if season=="season1" then return v=="1" or v=="season1" end
        if season=="classic" then return v=="classic" or v=="0" end
        return v=="holiday" or v:find("halloween",1,true) or v:find("christmas",1,true)
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
            if is(v,"GuiButton") then v.Active=false;pcall(function() v.Interactable=false end) end
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
    local function render()
        assert(template and template.Parent==grid,"MM2 rebuilt the inventory. Turn Show all cosmetics off and on again.")
        for o in pairs(originals) do pcall(function() o.Visible=false end) end
        clearCards()
        local items={}
        for _,kind in ipairs({"Knife","Gun"}) do
            local list=catalog.list(kind,query)
            assert(type(list)=="table","MM2 catalog did not return an item list.")
            for _,entry in ipairs(list) do items[#items+1]=entry end
        end
        local ok,message=pcall(function()
            for _,entry in ipairs(items) do
                if seasonMatches(entry.season) then
                    local card=template:Clone()
                    cards[#cards+1]=card
                    card.Name="HoneyBunLocal_"..entry.kind.."_"..tostring(entry.id)
                    card.Visible=true;card.LayoutOrder=#cards
                    for _,v in ipairs(texts(card)) do
                        if (is(v,"TextLabel") or is(v,"TextButton")) and (v.Text=="Default Knife" or v.Text=="Default Gun") then v.Text=entry.name end
                    end
                    local image=entry.image
                    if type(image)=="number" or (type(image)=="string" and image:match("^%d+$")) then image="rbxassetid://"..tostring(image) end
                    local target=icon(card)
                    if target then target.Image=type(image)=="string" and image or "" end
                    local button=overlay(card)
                    cardConnections[#cardConnections+1]=button.Activated:Connect(function()
                        local good,result=pcall(catalog.preview,entry.id,entry.kind)
                        status(good and (result or "Preview applied.") or ("Preview unavailable: "..tostring(result)))
                    end)
                    card.Parent=grid
                end
            end
        end)
        if not ok then clearCards();error(message) end
        return #cards,#items
    end
    local function update()
        local ok,n=pcall(render)
        status(ok and ("MM2 inventory: "..n.." local cosmetic cards.") or ("MM2 inventory update failed: "..tostring(n)))
    end
    local function bindControls()
        for _,o in ipairs(descendants(root)) do
            if is(o,"TextBox") and (lower(o.Name):find("search",1,true) or lower(o.PlaceholderText):find("search",1,true)) then
                query=lower(o.Text)
                connections[#connections+1]=o:GetPropertyChangedSignal("Text"):Connect(function() query=lower(o.Text);update() end)
            elseif is(o,"TextButton") and (normalize(o.Text)=="season1" or normalize(o.Text)=="classic" or normalize(o.Text)=="holiday") then
                connections[#connections+1]=o.Activated:Connect(function() season=normalize(o.Text);update() end)
            end
        end
    end
    function api.disable()
        disconnect(connections);connections={};clearCards()
        for o,visible in pairs(originals) do pcall(function() o.Visible=visible end) end
        originals={}
        if ownedLayout then destroy(ownedLayout);ownedLayout=nil end
        if scroll and scrollState then pcall(function() scroll.CanvasSize=scrollState.canvas;scroll.AutomaticCanvasSize=scrollState.auto end) end
        if grid and gridState then pcall(function() grid.Size=gridState.size;grid.AutomaticSize=gridState.auto end) end
        scroll,scrollState,gridState=nil,nil,nil
        enabled=false
        return "Original MM2 inventory display restored."
    end
    function api.enable()
        assert(not dead,"MM2 inventory preview was closed.")
        if enabled then return true,lastReport end
        root,grid,template=detect()
        if not grid then
            status("Native inventory not detected. Open MM2 Weapons inventory showing Default Knife and Default Gun, then try again.\n"..inventoryTree())
            return false,lastReport
        end
        local ok,message=pcall(function()
            if not grid:FindFirstChildOfClass("UIGridLayout") then
                ownedLayout=Instance.new("UIGridLayout")
                ownedLayout.Name="HoneyBunLocalLayout";ownedLayout.CellSize=template.Size
                ownedLayout.CellPadding=UDim2.fromOffset(4,4);ownedLayout.SortOrder=Enum.SortOrder.LayoutOrder
                ownedLayout.Parent=grid
            end
            scroll=grid
            while scroll and not is(scroll,"ScrollingFrame") do scroll=scroll.Parent end
            if scroll then
                scrollState={canvas=scroll.CanvasSize,auto=scroll.AutomaticCanvasSize}
                scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
                if grid~=scroll then
                    gridState={size=grid.Size,auto=grid.AutomaticSize}
                    grid.AutomaticSize=Enum.AutomaticSize.Y
                end
            end
            for _,o in ipairs(children(grid)) do hideOriginal(o) end
            connections[#connections+1]=grid.ChildAdded:Connect(hideOriginal)
            query="";season=nil;bindControls()
            local n,total=render()
            assert(total>0,"MM2's item database returned no knife/gun cosmetics. Copy MM2 report for the database details.")
            return "MM2 inventory: "..n.." local cosmetic cards added."
        end)
        if not ok then api.disable();status("MM2 inventory could not load: "..tostring(message));return false,lastReport end
        enabled=true;status(message)
        return true,message
    end
    function api.report()
        return "Native inventory build: local cards V2\n"..lastReport.."\nGrid="..(grid and grid:GetFullName() or "none").."\nGenerated="..#cards
    end
    function api.destroy() if not dead then api.disable();dead=true end end
    return api
end
