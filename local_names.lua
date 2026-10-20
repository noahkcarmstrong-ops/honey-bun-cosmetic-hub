-- Local-only username/display-name cosmetic. It never changes Roblox identity.
local function trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
local function validUsername(value)
    return value == "" or (#value >= 3 and #value <= 20 and value:match("^[A-Za-z0-9_]+$"))
end
local function validDisplay(value)
    return value == "" or (#value >= 1 and #value <= 50 and not value:find("[%c]"))
end
local function pattern(value) return tostring(value):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") end
local function isTextObject(object)
    return object and object.IsA and (object:IsA("TextLabel") or object:IsA("TextButton"))
end
local function ancestors(object)
    local result = {}; local current = object
    while current do result[#result + 1] = current; current = current.Parent end
    return result
end
local function hasOwnId(object, player)
    local id = tostring(player.UserId or "")
    if id == "" then return false end
    for _, item in ipairs(ancestors(object)) do
        local name = tostring(item.Name or "")
        if name == id or name == "PlayerEntry_" .. id or name == "p_" .. id or name=="PlayerLabel"..player.Name then return true end
        for _, key in ipairs({"UserId", "UserID", "PlayerId", "playerId"}) do
            local ok, value = pcall(function() return item:GetAttribute(key) end)
            if ok and tostring(value or "") == id then return true end
        end
    end
    return false
end
local function isHubOwned(object)
    for _, item in ipairs(ancestors(object)) do if tostring(item.Name or "") == "HoneyBunCosmeticHub" then return true end end
    return false
end
local function walk(root, fn)
    if not root then return end
    pcall(function() fn(root) end)
    local descendants
    pcall(function() descendants = root:GetDescendants() end)
    for _, item in ipairs(descendants or {}) do pcall(fn, item) end
end

return function(player, playerGui, gameObject)
    local settings = {enabled = false, username = "", displayName = ""}
    local originals, watchedObjects, connections, roots = {}, {}, {}, {}
    local alive, applying, builtInAvailable = true, false, false
    local coreGuiRoot, coreGuiChanges = nil, 0
    local originalUsername = tostring(player.Name or "")
    local originalDisplay = tostring(player.DisplayName or originalUsername)
    local characterChanged, watchedRoots = nil, {}
    local status = "Names are local only."

    -- Browser relay is the only source of name settings. Ignore older menu saves.
    local function targetUsername() return settings.username ~= "" and settings.username or originalUsername end
    local function targetDisplay() return settings.displayName ~= "" and settings.displayName or originalDisplay end
    local function visibleText(text) return tostring(text or ""):gsub("<[^>]->", "") end
    local function escapeRich(value) return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;") end
    local function replaceText(text, rich)
        if type(text) ~= "string" then return text end
        local username, display = targetUsername(), targetDisplay()
        if rich then username, display = escapeRich(username), escapeRich(display) end
        if text == "@"..originalUsername then return "@"..username end
        if text == originalUsername then return username end
        if text == originalDisplay then return display end
        local plain=visibleText(text):gsub(" %(You%)$", "")
        if plain ~= originalUsername and plain ~= originalDisplay then return text end
        -- Replace only text between tags; this preserves RichText attributes and tags.
        local out, cursor = {}, 1
        while true do
            local start, finish, tag = text:find("<[^>]*>", cursor)
            if not start then
                local chunk = text:sub(cursor):gsub("%f[%w_]" .. pattern(originalUsername) .. "%f[^%w_]", function() return username end)
                out[#out + 1] = chunk:gsub("%f[%w_]" .. pattern(originalDisplay) .. "%f[^%w_]", function() return display end); break
            end
            local chunk = text:sub(cursor, start - 1):gsub("%f[%w_]" .. pattern(originalUsername) .. "%f[^%w_]", function() return username end)
            out[#out + 1] = chunk:gsub("%f[%w_]" .. pattern(originalDisplay) .. "%f[^%w_]", function() return display end)
            out[#out + 1] = text:sub(start, finish); cursor = finish + 1
        end
        return table.concat(out)
    end
    local function inCore(object)
        for _, ancestor in ipairs(ancestors(object)) do if ancestor == coreGuiRoot then return true end end
        return false
    end
    -- Roblox Client Tracker: TeamListView keys rows as PlayerEntry_<userId>.
    -- PlayerNameTag renders PlayerName from the user-profile name service;
    -- PlayerListDisplayView uses TitlePlayer for the local mobile entry.
    local function nativeName(object)
        if object.Name ~= "PlayerName" or not inCore(object) then return false end
        if hasOwnId(object,player) then return true end
        local title,list=false,false
        for _,ancestor in ipairs(ancestors(object)) do
            if ancestor.Name=="TitlePlayer" then title=true end
            if ancestor.Name=="PlayerList" then list=true end
        end
        return title and list
    end
    local function ownMenuRow(object)
        if not inCore(object) then return false end
        local current=object.Parent
        for depth=1,5 do
            if not current then break end
            local ok,children=pcall(function()return current:GetDescendants()end)
            if not ok or #children>120 then break end
            local own,other,texts=false,false,0
            for _,child in ipairs(children)do
                if isTextObject(child)then
                    texts=texts+1
                    local text=originals[child] or child.Text
                    if text=="@"..originalUsername then own=true
                    elseif type(text)=="string" and text:match("^@[%w_]+$")then other=true end
                end
            end
            if own and not other and texts<=8 then return true end
            current=current.Parent
        end
        return false
    end
    local function owned(object)
        if hasOwnId(object,player) or nativeName(object) or ownMenuRow(object) then return true end
        for _,item in ipairs(ancestors(object)) do
            if item==player.Character or item.Name==originalUsername then return true end
        end
        return false
    end
    local function candidate(object)
        if not isTextObject(object) or isHubOwned(object) or not owned(object) then return false end
        if nativeName(object) then return true end
        local plain=visibleText(object.Text):gsub(" %(You%)$", "")
        return plain==originalUsername or plain=="@"..originalUsername or plain==originalDisplay
    end
    local function applyText(object)
        local original=originals[object]
        if not original or not owned(object) then return end
        local replacement
        if nativeName(object) and (settings.displayName~="" or settings.username~="") then
            replacement=settings.displayName~="" and settings.displayName or settings.username
            if object.RichText then replacement=escapeRich(replacement) end
        else replacement=replaceText(original,object.RichText==true) end
        if replacement==object.Text then return end
        applying=true
        local ok=pcall(function() object.Text=replacement end)
        applying=false
        if ok and inCore(object) then coreGuiChanges=coreGuiChanges+1 end
    end
    local function watch(object)
        if not isTextObject(object) or isHubOwned(object) then return end
        if watchedObjects[object] then
            if not originals[object] and candidate(object) then originals[object]=object.Text end
            if settings.enabled then applyText(object) end
            return
        end
        watchedObjects[object]=true
        if candidate(object) then originals[object]=object.Text end
        local changed
        pcall(function() changed=object:GetPropertyChangedSignal("Text"):Connect(function()
            if not alive or applying then return end
            if not candidate(object) then originals[object]=nil;return end
            originals[object]=object.Text
            if settings.enabled then
                applyText(object)
                local row=object.Parent and object.Parent.Parent
                if row then walk(row,function(item)
                    if isTextObject(item) and not originals[item] and candidate(item)then originals[item]=item.Text;applyText(item)end
                end)end
            end
        end) end)
        if changed then connections[#connections+1]=changed end
        if settings.enabled then applyText(object) end
    end
    local function restoreText()
        applying = true
        for object, original in pairs(originals) do if owned(object) then pcall(function() object.Text = original end) end end
        applying = false
    end
    local function humanoid(character)
        local h; pcall(function() h = character and character:FindFirstChildOfClass("Humanoid") end)
        if not h then return end
        local original = h.DisplayName
        if settings.enabled then pcall(function() h.DisplayName = targetDisplay() end) end
        if not roots[h] then roots[h] = original end
    end
    local function restoreHumanoids()
        for h, original in pairs(roots) do pcall(function() h.DisplayName = original end) end
        roots = {}
    end
    local function scan(root)
        walk(root, watch)
        if root and not watchedRoots[root] then
            watchedRoots[root] = true
            pcall(function() connections[#connections + 1] = root.DescendantAdded:Connect(watch) end)
        end
    end
    local ok = pcall(function() coreGuiRoot = game:GetService("CoreGui") end)
    if ok and coreGuiRoot then
        builtInAvailable=pcall(function() coreGuiRoot:GetDescendants() end)
        if builtInAvailable then scan(coreGuiRoot) end
    end
    if not builtInAvailable then status="Names are local only. Built-in player list is unavailable." end
    scan(playerGui); scan(gameObject)
    local workspaceRoot; pcall(function() workspaceRoot = game.Workspace end); scan(workspaceRoot)
    pcall(function() characterChanged = player.CharacterAdded:Connect(function(character) restoreHumanoids(); humanoid(character); scan(character) end) end)
    humanoid(player.Character)
    local function refresh()
        if not settings.enabled then restoreText(); restoreHumanoids(); return end
        scan(coreGuiRoot); scan(playerGui); scan(gameObject); scan(workspaceRoot); humanoid(player.Character)
        for object in pairs(originals) do applyText(object) end
    end
    local api = {}
    function api.set(username, displayName)
        username, displayName = trim(username), trim(displayName)
        assert(validUsername(username), "Username must be 3-20 ASCII letters, numbers, or underscores.")
        assert(validDisplay(displayName), "Display name must be 1-50 characters without control characters.")
        settings.username, settings.displayName = username, displayName; settings.enabled = true; refresh()
        return api.report()
    end
    function api.setEnabled(value) settings.enabled = value == true; refresh(); return api.report() end
    function api.getSettings() return {enabled=settings.enabled, username=settings.username, displayName=settings.displayName} end
    function api.restore() settings.username, settings.displayName = "", ""; settings.enabled = false; refresh(); return "Original names restored locally." end
    function api.report() return status .. (settings.enabled and " Override enabled locally; Roblox interface text changes: " .. tostring(coreGuiChanges) .. "." or " Override disabled.") end
    function api.destroy()
        if not alive then return end
        alive = false; if characterChanged then characterChanged:Disconnect() end
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        restoreText(); restoreHumanoids()
    end
    return api
end
