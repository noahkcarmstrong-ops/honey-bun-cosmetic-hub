-- Local classic 2D shirt and pants replacement. Never invokes Roblox's avatar system.
local Http=game:GetService("HttpService")

local function parse(value)
    if type(value)=="number" then
        assert(value>0 and value%1==0 and value<9007199254740992,"Enter a positive numeric ID.")
        return value
    end
    local text=tostring(value or ""):match("^%s*(.-)%s*$")
    local id=text:match("^(%d+)$") or text:match("^rbxassetid://(%d+)$")
    if not id then
        local path=text:match("^https?://www%.roblox%.com/(.+)$") or text:match("^https?://roblox%.com/(.+)$")
        if path then
            local catalog,suffix=path:match("^catalog/(%d+)(.*)$")
            if catalog and (suffix=="" or suffix:match("^[/#?]")) then id=catalog end
        end
    end
    local number=tonumber(id)
    assert(number and number>0 and number<9007199254740992,"Paste a Roblox catalog link, rbxassetid, or positive numeric ID.")
    return number
end

local function dispose(roots)
    for _,root in ipairs(roots or {}) do if root then root:Destroy() end end
end

return function(player,onStatus,managedRespawn)
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticClothes"
    local settings={Shirt=nil,Pants=nil,ShirtGraphic=nil}
    local alive,generation=true,0
    local state={Shirt=nil,Pants=nil,ShirtGraphic=nil}
    local templates,requests={},{}
    local function nextRequest(kind)
        requests[kind]=(requests[kind] or 0)+1
        return requests[kind]
    end
    local function read()
        if not gui then return end
        local ok,saved=pcall(function() return Http:JSONDecode(gui:GetAttribute(attribute) or "") end)
        if ok and type(saved)=="table" then
            for _,kind in ipairs({"Shirt","Pants","ShirtGraphic"}) do
                local value=saved[kind]
                if type(value)=="number" and value>=0 and value%1==0 and value<9007199254740992 then settings[kind]=value end
            end
        end
    end
    read()
    local reapplying=false
    local function save()
        if gui and not reapplying then gui:SetAttribute(attribute,Http:JSONEncode({Shirt=settings.Shirt,Pants=settings.Pants,ShirtGraphic=settings.ShirtGraphic})) end
    end
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        assert(character and humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        return {character=character,generation=generation}
    end
    local function valid(ctx)
        return alive and generation==ctx.generation and player.Character==ctx.character
    end
    local function check(ctx)
        assert(valid(ctx),"Your avatar changed while loading. Try again on the new character.")
    end
    local function capture(ctx,kind)
        local s=state[kind]
        if s then return s end
        s={character=ctx.character,originals={},applied=nil};state[kind]=s
        local children={}
        for _,item in ipairs(ctx.character:GetChildren()) do children[#children+1]=item end
        for _,item in ipairs(children) do
            if item:IsA(kind) then item.Parent=nil;table.insert(s.originals,item) end
        end
        return s
    end
    local function clearApplied(s)
        if s and s.applied then s.applied:Destroy();s.applied=nil end
    end
    local function restoreKind(kind,clearSaved)
        nextRequest(kind);local ctx=context();local s=state[kind]
        if s then
            clearApplied(s)
            if s.character==ctx.character then for _,item in ipairs(s.originals) do item.Parent=ctx.character end end
            state[kind]=nil
        end
        if clearSaved then settings[kind]=nil;save() end
        return "Original "..string.lower(kind).." restored."
    end
    local function resolveTemplate(ctx,kind,value)
        local property=({Shirt="ShirtTemplate",Pants="PantsTemplate",ShirtGraphic="Graphic"})[kind]
        local id=parse(value);local assetId=string.format("%.0f",id);local key=kind..":"..assetId;local template=templates[key]
        if not template then
            local ok,roots=pcall(function() return game:GetObjects("rbxassetid://"..assetId) end)
            assert(ok and type(roots)=="table" and #roots>0,"Roblox could not load that catalog item. It may be private or unavailable.")
            if not valid(ctx) then dispose(roots);check(ctx) end
            local source
            for _,root in ipairs(roots) do
                if root:IsA(kind) then source=root end
                if not source then for _,item in ipairs(root:GetDescendants()) do if item:IsA(kind) then source=item;break end end end
                if source then break end
            end
            if not source then dispose(roots);error("That catalog item is not a classic "..string.lower(kind)..".") end
            template=source[property]
            if type(template)~="string" or template=="" then dispose(roots);error("That classic "..string.lower(kind).." has no usable template.") end
            game:GetService("ContentProvider"):PreloadAsync({template})
            check(ctx)
            templates[key]=template
            dispose(roots)
        end
        return template,id
    end
    local function equip(kind,value)
        local ctx=context();local ticket=nextRequest(kind)
        local property=({Shirt="ShirtTemplate",Pants="PantsTemplate",ShirtGraphic="Graphic"})[kind]
        local template,id=resolveTemplate(ctx,kind,value)
        assert(requests[kind]==ticket,"Clothing choice changed while loading.")
        local applied=Instance.new(kind);applied.Name="HoneyBun"..kind;applied[property]=template
        if not valid(ctx) then applied:Destroy();check(ctx) end
        local s=capture(ctx,kind);clearApplied(s)
        applied.Parent=ctx.character;s.applied=applied;settings[kind]=id;save()
        return "Equipped classic "..string.lower(kind).." (visible to you)."
    end
    local api={}
    local function remove(kind)
        nextRequest(kind);local ctx=context();local s=capture(ctx,kind);clearApplied(s)
        settings[kind]=0;save()
        return "Removed classic "..string.lower(kind).." locally."
    end
    function api.equipTShirt(value)return equip("ShirtGraphic",value) end
    function api.removeTShirt()return remove("ShirtGraphic") end
    function api.restoreTShirt()return restoreKind("ShirtGraphic",true) end
    function api.equipShirt(value)return equip("Shirt",value) end
    function api.equipPants(value)return equip("Pants",value) end
    function api.removeShirt()return remove("Shirt") end
    function api.removePants()return remove("Pants") end
    function api.restoreShirt()return restoreKind("Shirt",true) end
    function api.restorePants()return restoreKind("Pants",true) end
    function api.restore() local a=restoreKind("Shirt",false);local b=restoreKind("Pants",false);local c=restoreKind("ShirtGraphic",false);settings.Shirt=nil;settings.Pants=nil;settings.ShirtGraphic=nil;save();return a.." "..b.." "..c end
    function api.getSettings()return {Shirt=settings.Shirt,Pants=settings.Pants,ShirtGraphic=settings.ShirtGraphic} end
    function api.prepareSaved()
        local ctx=context()
        for _,kind in ipairs({"Shirt","Pants","ShirtGraphic"})do
            if settings[kind] and settings[kind]~=0 then resolveTemplate(ctx,kind,settings[kind])end
        end
        check(ctx)
    end
    function api.reapplySaved()
        local old=reapplying;reapplying=true;local messages,errors={},{}
        for _,kind in ipairs({"Shirt","Pants","ShirtGraphic"}) do
            if settings[kind] then
                if onStatus then onStatus("Restoring "..string.lower(kind).." ("..tostring(settings[kind])..")...") end
                local ok,message=pcall(function() if settings[kind]==0 then return remove(kind) end;return equip(kind,settings[kind]) end)
                if ok then table.insert(messages,string.lower(kind)) else table.insert(errors,string.lower(kind)..": "..tostring(message)) end
            end
        end
        reapplying=old
        if #errors>0 then error("Could not reapply saved clothes ("..table.concat(errors,"; ")..")") end
        return #messages==0 and "No saved classic clothes selected." or "Reapplied saved classic clothes."
    end
    local readyConnections={}
    local function cancelReady()
        for _,connection in ipairs(readyConnections)do connection:Disconnect()end
        readyConnections={}
    end
    local function whenReady(character,ready,callback)
        cancelReady()
        local pending,finished=false,false
        local function changed()
            if pending or finished then return end
            pending=true
            task.defer(function()
                pending=false
                if finished or not alive or player.Character~=character then return end
                if not ready()then return end
                finished=true;cancelReady();callback()
            end)
        end
        local function watch(object)
            if object:IsA("Humanoid")then
                readyConnections[#readyConnections+1]=object.HealthChanged:Connect(changed)
            elseif object:IsA("LocalScript") and object.Name=="Animate"then
                readyConnections[#readyConnections+1]=object:GetPropertyChangedSignal("Disabled"):Connect(changed)
            end
        end
        readyConnections[#readyConnections+1]=character.DescendantAdded:Connect(function(object)watch(object);changed()end)
        readyConnections[#readyConnections+1]=player.CharacterAppearanceLoaded:Connect(changed)
        for _,object in ipairs(character:GetDescendants())do watch(object)end
        changed()
    end
    local changed=player.CharacterAdded:Connect(function(character)
        generation=generation+1;for _,kind in ipairs({"Shirt","Pants","ShirtGraphic"}) do local s=state[kind];if s then clearApplied(s);for _,item in ipairs(s.originals) do item:Destroy() end;state[kind]=nil end end
        if managedRespawn then return end
        whenReady(character,function()
            local h=character:FindFirstChildOfClass("Humanoid")
            return h and h.Health>0 and player:HasAppearanceLoaded()
        end,function()
            local ok,message=pcall(api.reapplySaved)
            if not ok and onStatus then onStatus("Could not restore saved clothes: "..tostring(message))end
        end)
    end)
    function api.destroy()
        cancelReady()
        if not alive then return end
        alive=false;generation=generation+1;changed:Disconnect()
        for _,kind in ipairs({"Shirt","Pants","ShirtGraphic"}) do
            local s=state[kind]
            if s then
                clearApplied(s)
                if s.character==player.Character then for _,item in ipairs(s.originals) do item.Parent=s.character end
                else for _,item in ipairs(s.originals) do item:Destroy() end end
                state[kind]=nil
            end
        end
    end
    return api
end
