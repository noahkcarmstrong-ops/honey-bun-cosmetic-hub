-- Local presentation only. Identity comes from real players, never UI paths.
local function trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
local function pattern(value) return value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") end
local function escape(value) return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;") end
local function plain(value, rich)
    if not rich then return value end
    return value:gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")
end
local controllers, identities, usernames, displays = {}, {}, {}, {}
local chatAliases={}
local entries = setmetatable({}, {__mode="k"})
local buckets, rootConnections, rosterConnections = {}, {}, {}
local coreGui, players
local chatService
local chatBindings={}
local chatStatus="Chat names are unavailable."
pcall(function() coreGui=game:GetService("CoreGui") end)
pcall(function() players=game:GetService("Players") end)

local function addName(index, name, id)
    if index[name] == nil then index[name]=id elseif index[name] ~= id then index[name]=false end
end
local function rememberChatName(id,name,field)
    if not name or name=="" then return end
    chatAliases[id]=chatAliases[id] or {}
    chatAliases[id][name]=field
end
local function rebuildIdentities(leavingId)
    usernames, displays = {}, {}
    local roster = {}
    if players then pcall(function() roster=players:GetPlayers() end) end
    for _, player in ipairs(roster) do
        if player.UserId~=leavingId and not identities[player.UserId] then
            identities[player.UserId]={username=player.Name, display=player.DisplayName}
        end
    end
    local present={}
    for _, player in ipairs(roster) do if player.UserId~=leavingId then present[player.UserId]=true end end
    for id, identity in pairs(identities) do
        if present[id] or controllers[id] then
            addName(usernames, identity.username, id)
            addName(displays, identity.display, id)
            rememberChatName(id,identity.display,"displayName")
            rememberChatName(id,identity.username,"username")
        else identities[id]=nil end
    end
end
local function chatSpan(entry)
    if not entry.source:find(":",1,true) then return end
    -- Roblox keys native message records by sender ID and message GUID. Use
    -- that identity without depending on any chat window path or game layout.
    local ancestor=entry.object
    local senderId,inCore
    while ancestor do
        if ancestor==coreGui then inCore=true end
        local id=tostring(ancestor.Name):match("^(%d+)%-%{%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%}$")
        if id then senderId=tonumber(id) end
        ancestor=ancestor.Parent
    end
    if not inCore or not senderId or not identities[senderId] then return end
    local rich=entry.object.RichText==true
    local text=plain(entry.source,rich)
    local offset=1
    -- Role/channel tags precede the sender; they are not part of the name.
    while true do
        local finish=text:sub(offset):match("^%s*%b[]%s*()")
        if not finish then break end
        offset=offset+finish-1
    end
    local leading=text:sub(1,offset-1)
    for name,field in pairs(chatAliases[senderId] or {}) do
        if text:sub(offset,offset+#name)==name..":" then
            local encoded=rich and escape(name) or name
            local cursor=1
            while true do
                local first,last=entry.source:find(encoded..":",cursor,true)
                if not first then break end
                if plain(entry.source:sub(1,first-1),rich)==leading then
                    return senderId,{first=first,last=last-1,field=field}
                end
                cursor=last+1
            end
        end
    end
end
local function resolve(entry)
    local sender,span=chatSpan(entry)
    entry.chatSpan=span
    if sender then return sender end
    local text=plain(entry.source,entry.object.RichText==true):gsub(" %(You%)$", "")
    local name=text:match("^@(.+)$") or text:match("^(.-)'s%s") or text
    local id=usernames[name]
    if id==nil then id=displays[name] end
    if id==nil then return nil end
    -- Explicit conflicting identity wins over coincidentally matching text.
    local ancestor=entry.object
    local explicitId
    while ancestor do
        local ok, ignored=pcall(function() return ancestor:GetAttribute("LarpbloxIgnoreNameOverride") end)
        if ok and ignored then return nil end
        for _, key in ipairs({"UserId","UserID","PlayerId","playerId"}) do
            local success,value=pcall(function() return ancestor:GetAttribute(key) end)
            local found=success and tonumber(value)
            if found then
                if explicitId and explicitId~=found then return nil end
                explicitId=found
            end
        end
        ancestor=ancestor.Parent
    end
    if explicitId then
        local identity=identities[explicitId]
        if identity and (name==identity.username or name==identity.display) then return explicitId end
        return nil
    end
    return id or nil
end
local function replacement(entry, controller)
    if entry.chatSpan then
        local span=entry.chatSpan
        local identity=identities[entry.id]
        if not identity then return entry.source end
        local value=span.field=="username" and identity.username or identity.display
        if controller and controller.settings.enabled then
            local configured=controller.settings[span.field]
            if configured and configured~="" then value=configured end
        end
        if entry.object.RichText then value=escape(value) end
        return entry.source:sub(1,span.first-1)..value..entry.source:sub(span.last+1)
    end
    if not controller or not controller.settings.enabled then return entry.source end
    local identity=identities[controller.id]
    local settings=controller.settings
    local username=settings.username~="" and settings.username or identity.username
    local display=settings.displayName~="" and settings.displayName or identity.display
    if entry.object.RichText then username,display=escape(username),escape(display) end
    -- Rewrite text segments only, preserving markup and its attributes.
    local function segment(text)
        -- One substitution pass prevents aliases from being substituted again.
        local matches={}
        for _,pair in ipairs({{identity.username,username},{identity.display,display}}) do
            local cursor=1
            while true do
                local first,last=text:find("%f[%w_]"..pattern(pair[1]).."%f[^%w_]",cursor)
                if not first then break end
                matches[#matches+1]={first,last,pair[2]};cursor=last+1
            end
        end
        table.sort(matches,function(a,b) return a[1]<b[1] or (a[1]==b[1] and a[2]>b[2]) end)
        local out,cursor={},1
        for _,match in ipairs(matches) do
            if match[1]>=cursor then out[#out+1]=text:sub(cursor,match[1]-1);out[#out+1]=match[3];cursor=match[2]+1 end
        end
        out[#out+1]=text:sub(cursor);return table.concat(out)
    end
    if not entry.object.RichText then return segment(entry.source) end
    local out,cursor={},1
    while true do
        local first,last=entry.source:find("<[^>]*>",cursor)
        if not first then out[#out+1]=segment(entry.source:sub(cursor));break end
        out[#out+1]=segment(entry.source:sub(cursor,first-1));out[#out+1]=entry.source:sub(first,last);cursor=last+1
    end
    return table.concat(out)
end
local function readCallback(service,member)
    if type(getcallbackvalue)=="function" then
        return pcall(getcallbackvalue,service,member)
    end
    return pcall(function() return service[member] end)
end
local function bindChat()
    if next(chatBindings) then return end
    local ok, service=pcall(function() return game:GetService("TextChatService") end)
    if not ok or not service then return end
    local config=service:FindFirstChildOfClass("ChatWindowConfiguration")
    for _,member in ipairs({"OnIncomingMessage","OnChatWindowAdded"}) do
        local member=member
        local readable,previous=readCallback(service,member)
        -- Preserve the game's callback and its filtering/status/formatting.
        if readable and (previous==nil or type(previous)=="function") and (member~="OnChatWindowAdded" or config) then
            local hook=function(message)
                local properties=previous and previous(message) or nil
                local source=message.TextSource
                local controller=source and controllers[source.UserId]
                if not controller or not controller.settings.enabled then return properties end
                local prefix=properties and properties.PrefixText
                if not prefix or prefix=="" then prefix=message.PrefixText end
                if type(prefix)~="string" or prefix=="" then return properties end
                local value=replacement({source=prefix,object={RichText=true}},controller)
                if value==prefix then return properties end
                if not properties then
                    properties=member=="OnIncomingMessage" and Instance.new("TextChatMessageProperties") or config:DeriveNewMessageProperties()
                end
                properties.PrefixText=value
                return properties
            end
            if pcall(function() service[member]=hook end) then
                chatBindings[member]={previous=previous,hook=hook}
            end
        end
    end
    chatService=service
    if next(chatBindings) then chatStatus="Chat sender names use Larp names." end
end
local function unbindChat()
    for member,binding in pairs(chatBindings) do
        local readable,current=readCallback(chatService,member)
        if readable and current==binding.hook then
            pcall(function() chatService[member]=binding.previous end)
        end
    end
    chatService=nil;chatBindings={}
    chatStatus="Chat names are unavailable."
end
local function render(entry)
    local value=replacement(entry,controllers[entry.id])
    if entry.object.Text==value then return end
    entry.written=value
    pcall(function() entry.object.Text=value end)
end
local function bind(entry)
    if entry.id and buckets[entry.id] then buckets[entry.id][entry]=nil end
    entry.id=resolve(entry)
    if entry.id then
        buckets[entry.id]=buckets[entry.id] or setmetatable({}, {__mode="k"})
        buckets[entry.id][entry]=true
    end
    render(entry)
end
local function unwatch(object)
    local entry=entries[object]
    if not entry then return end
    if entry.id and buckets[entry.id] then buckets[entry.id][entry]=nil end
    for _,connection in ipairs(entry.connections) do connection:Disconnect() end
    entries[object]=nil
end
local function watch(object)
    if entries[object] or not (object:IsA("TextLabel") or object:IsA("TextButton")) then return end
    local entry={object=object,source=object.Text,connections={}}
    entries[object]=entry
    entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal("Text"):Connect(function()
        if object.Text==entry.written then return end
        entry.written=nil;entry.source=object.Text;bind(entry)
    end)
    entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal("RichText"):Connect(function() bind(entry) end)
    bind(entry)
end
local function watchRoot(root)
    if not root or rootConnections[root] then return end
    local ok, descendants=pcall(function() return root:GetDescendants() end)
    if not ok then return end
    local connections={}
    rootConnections[root]=connections
    connections[#connections+1]=root.DescendantAdded:Connect(watch)
    connections[#connections+1]=root.DescendantRemoving:Connect(unwatch)
    for _,object in ipairs(descendants) do watch(object) end
end
local function refreshRoster(leavingId)
    rebuildIdentities(leavingId)
    for _,entry in pairs(entries) do bind(entry) end
end

return function(player, playerGui, gameObject)
    local id=player.UserId
    assert(not controllers[id],"Name presentation already exists for this player")
    local knownIdentity=identities[id]~=nil
    local controller={id=id,settings={enabled=false,username="",displayName=""}}
    controllers[id]=controller
    identities[id]=identities[id] or {username=player.Name,display=player.DisplayName or player.Name}
    local originalDisplay=identities[id].display
    rebuildIdentities()
    bindChat()
    if not knownIdentity then
        -- Only a new identity can change existing labels' resolution.
        for _,entry in pairs(entries) do bind(entry) end
    end
    if #rosterConnections==0 and players then
        rosterConnections[#rosterConnections+1]=players.PlayerAdded:Connect(function() refreshRoster() end)
        rosterConnections[#rosterConnections+1]=players.PlayerRemoving:Connect(function(leaving)
            identities[leaving.UserId]=nil
            -- PlayerRemoving fires before GetPlayers drops the player.
            local identity=controllers[leaving.UserId]
            if identity then identity.settings.enabled=false end
            refreshRoster(leaving.UserId)
        end)
    end
    watchRoot(coreGui);watchRoot(playerGui);watchRoot(gameObject);watchRoot(game.Workspace)
    local humanoids={}
    local function applyHumanoid(character)
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        if humanoids[humanoid]==nil then humanoids[humanoid]=humanoid.DisplayName end
        local settings=controller.settings
        pcall(function()
            humanoid.DisplayName=settings.enabled and (settings.displayName~="" and settings.displayName or originalDisplay) or humanoids[humanoid]
        end)
    end
    local characterConnection=player.CharacterAdded:Connect(applyHumanoid)
    local function refresh()
        local settings=controller.settings
        -- Prefer the player's local presentation property for future UI reads.
        -- Keep immutable real names in the identity index and never change Name.
        local display=settings.enabled and settings.displayName~="" and settings.displayName or originalDisplay
        pcall(function() if player.DisplayName~=display then player.DisplayName=display end end)
        for entry in pairs(buckets[id] or {}) do render(entry) end
        applyHumanoid(player.Character)
    end
    local api={}
    function api.set(username,displayName)
        username,displayName=trim(username),trim(displayName)
        assert(username=="" or (#username>=3 and #username<=20 and username:match("^[A-Za-z0-9_]+$")),"Username must be 3-20 ASCII letters, numbers, or underscores.")
        assert(#displayName<=50 and not displayName:find("[%c]"),"Display name must be 1-50 characters without control characters.")
        rememberChatName(id,username,"username");rememberChatName(id,displayName,"displayName")
        controller.settings={enabled=true,username=username,displayName=displayName};refresh();return api.report()
    end
    function api.setEnabled(value) controller.settings.enabled=value==true;refresh();return api.report() end
    function api.getSettings() local s=controller.settings;return {enabled=s.enabled,username=s.username,displayName=s.displayName} end
    function api.restore() controller.settings={enabled=false,username="",displayName=""};refresh();return "Original names restored locally." end
    function api.report() return "Names are local only. "..(controller.settings.enabled and "Override enabled locally. "..chatStatus or "Override disabled.") end
    function api.destroy()
        if controllers[id]~=controller then return end
        api.restore();characterConnection:Disconnect();controllers[id]=nil
        for humanoid,original in pairs(humanoids) do pcall(function() humanoid.DisplayName=original end) end
        if next(controllers)==nil then
            unbindChat()
            for object in pairs(entries) do unwatch(object) end
            for _,connections in pairs(rootConnections) do for _,connection in ipairs(connections) do connection:Disconnect() end end
            for _,connection in ipairs(rosterConnections) do connection:Disconnect() end
            rootConnections,rosterConnections,buckets,identities,chatAliases={},{},{},{},{}
        end
    end
    return api
end
