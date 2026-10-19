-- Honey Bun Cosmetic Hub: standalone cosmetic menu.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, name in ipairs({"HoneyBunCosmeticHub"}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

local moduleRevision,persistence,persistenceLabel
local persistenceNotice="Auto-save: session only. Saved-settings support could not load."
pcall(function()
    local stamp=tostring(DateTime.now().UnixTimestampMillis)
    local revision=game:GetService("HttpService"):JSONDecode(game:HttpGet(
        "https://api.github.com/repos/noahkcarmstrong-ops/honey-bun-cosmetic-hub/commits/main?refresh="..stamp,false))
    local sha=revision and revision.sha
    assert(type(sha)=="string" and #sha==40 and sha:match("^%x+$"),"Could not find the latest cosmetic update.")
    moduleRevision=sha
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..sha.."/storage.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    persistence=chunk()(playerGui,Players.LocalPlayer.UserId,function(message)
        if persistenceLabel and persistenceLabel.Parent then persistenceLabel.Text=message end
    end)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "HoneyBunCosmeticHub"
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.new(1, -48, 0.78, 0)
panel.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
panel.BorderSizePixel = 0
panel.Parent = gui
local limits = Instance.new("UISizeConstraint", panel)
limits.MaxSize = Vector2.new(520, 760)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local border = Instance.new("UIStroke", panel)
border.Color = Color3.fromRGB(48, 48, 48)

local function text(parent, value, position, size, fontSize, shade)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.Gotham
    label.Text = value
    label.TextSize = fontSize
    label.TextColor3 = Color3.fromRGB(shade, shade, shade)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

text(panel, "HONEY BUN COSMETIC HUB", UDim2.fromOffset(28, 26), UDim2.new(1, -100, 0, 24), 16, 240).Font = Enum.Font.GothamMedium
text(panel, "LOCAL AVATAR EDITOR", UDim2.fromOffset(28, 55), UDim2.new(1, -56, 0, 20), 10, 110)

local hide = Instance.new("TextButton")
hide.Position = UDim2.new(1, -60, 0, 23)
hide.Size = UDim2.fromOffset(32, 32)
hide.BackgroundTransparency = 1
hide.Text = "−"
hide.TextSize = 24
hide.TextColor3 = Color3.fromRGB(160, 160, 160)
hide.Font = Enum.Font.Gotham
hide.Parent = panel

local line = Instance.new("Frame", panel)
line.Position = UDim2.fromOffset(28, 96)
line.Size = UDim2.new(1, -56, 0, 1)
line.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
line.BorderSizePixel = 0
local tabs = Instance.new("ScrollingFrame")
tabs.Name = "Tabs"
tabs.Position = UDim2.fromOffset(28, 112)
tabs.Size = UDim2.new(1, -56, 0, 36)
tabs.BackgroundTransparency = 1
tabs.BorderSizePixel=0;tabs.ScrollBarThickness=2
tabs.CanvasSize=UDim2.fromOffset(0,0);tabs.AutomaticCanvasSize=Enum.AutomaticSize.X
tabs.ScrollingDirection=Enum.ScrollingDirection.X
tabs.Parent = panel
local tabLayout = Instance.new("UIListLayout", tabs)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
local content = Instance.new("ScrollingFrame")
content.Name = "CosmeticsPage"
content.Position = UDim2.fromOffset(28, 160)
content.Size = UDim2.new(1, -56, 1, -238)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 2
content.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel
local layout = Instance.new("UIListLayout", content)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
local avatarAPI,motionAPI,animationAPI
local refresh = Instance.new("TextButton")
refresh.Position = UDim2.new(1, -126, 0, 62)
refresh.Size = UDim2.fromOffset(98, 26)
refresh.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
refresh.BorderSizePixel = 0
refresh.Text = "Refresh"
refresh.TextColor3 = Color3.fromRGB(220, 220, 220)
refresh.TextSize = 12
refresh.Font = Enum.Font.GothamMedium
refresh.Parent = panel
Instance.new("UICorner", refresh).CornerRadius = UDim.new(0, 6)

local refreshing = false
refresh.Activated:Connect(function()
    if refreshing then return end
    refreshing = true
    refresh.Text = "Refreshing..."
    local ok, message = pcall(function()
        local stamp = tostring(DateTime.now().UnixTimestampMillis)
        local revisionUrl = "https://api.github.com/repos/noahkcarmstrong-ops/honey-bun-cosmetic-hub/commits/main?refresh=" .. stamp
        local revision = game:GetService("HttpService"):JSONDecode(game:HttpGet(revisionUrl, false))
        local sha = revision and revision.sha
        assert(type(sha) == "string" and #sha == 40 and sha:match("^%x+$"), "GitHub did not return a valid update revision")
        local url = "https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/" .. sha .. "/loader.lua"
        local source = game:HttpGet(url, false)
        local chunk, compileError = loadstring(source)
        assert(chunk, compileError)
        chunk()
    end)
    if not ok then
        warn("Honey Bun Cosmetic Hub: refresh failed", message)
        if refresh.Parent then
            refresh.Text = "Retry refresh"
        end
    end
    refreshing = false
end)

local footerLine = line:Clone()
footerLine.Position = UDim2.new(0, 28, 1, -64)
footerLine.Parent = panel
text(panel, "RIGHT SHIFT", UDim2.new(0, 28, 1, -48), UDim2.fromOffset(110, 24), 10, 190)
local hint = text(panel, "Show / hide", UDim2.new(0, 140, 1, -48), UDim2.new(1, -168, 0, 24), 11, 105)
hint.TextXAlignment = Enum.TextXAlignment.Right

hide.Activated:Connect(function() panel.Visible = false end)
local connection = Input.InputBegan:Connect(function(key)
    if Input:GetFocusedTextBox() then return end
    if key.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
    end
end)

local function uiSetting(key,default)
    local value=playerGui:GetAttribute("HoneyBunCosmeticUI_"..key)
    return type(value)==type(default) and value or default
end
local alive, busy, activePage = true, false, uiSetting("page","Accessories")
if activePage~="Accessories" and activePage~="Skin" and activePage~="Body" and activePage~="Emotes" and activePage~="Animations" then activePage="Accessories" end
local statusText = "Local avatar editor. Saved selections reapply automatically."
local statusLabel, render
local accessoryInput, bundleInput = uiSetting("accessory",""), uiSetting("bundle","")
local emoteInput,animationInput=uiSetting("emote",""),uiSetting("animationBundle","")
local emoteSlot=uiSetting("emoteSlot",1)
if emoteSlot<1 or emoteSlot>8 or emoteSlot%1~=0 then emoteSlot=1 end
local rgb = {uiSetting("red","255"),uiSetting("green","204"),uiSetting("blue","153")}
local hexInput = uiSetting("hex","#FFCC99")
local regions = {"All", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
local regionNames = {"Whole body", "Head", "Torso", "Left arm", "Right arm", "Left leg", "Right leg"}
local regionIndex = uiSetting("region",1)
if regionIndex<1 or regionIndex>#regions or regionIndex%1~=0 then regionIndex=1 end
local paletteOpen=uiSetting("palette",false)
local function saveUI()
    local values={page=activePage,accessory=accessoryInput,bundle=bundleInput,red=rgb[1],green=rgb[2],blue=rgb[3],hex=hexInput,region=regionIndex,palette=paletteOpen,emote=emoteInput,animationBundle=animationInput,emoteSlot=emoteSlot}
    for key,value in pairs(values) do playerGui:SetAttribute("HoneyBunCosmeticUI_"..key,value) end
end
-- Exact RGB samples from the user's 5-column, 6-row Roblox palette reference.
local robloxColors={
    {90,76,66},{124,92,70},{175,148,131},{204,142,105},{234,184,146},
    {86,66,54},{105,64,40},{188,155,93},{199,172,120},{215,197,154},
    {149,121,119},{163,75,75},{218,134,122},{255,201,201},{255,152,220},
    {116,134,157},{82,124,174},{128,187,220},{177,167,255},{167,94,155},
    {0,143,156},{91,154,76},{124,156,107},{161,196,140},{226,155,64},
    {245,205,48},{248,217,109},{99,95,98},{205,205,205},{248,248,248},
}
local tabButtons = {}
local order = 0
local function row(class, height)
    order=order+1
    local item=Instance.new(class)
    item.Size=UDim2.new(1,-8,0,height)
    item.LayoutOrder=order
    item.BackgroundTransparency=1
    item.Parent=content
    return item
end
local function caption(value, height)
    local item=row("TextLabel",height or 36)
    item.Font,item.TextSize,item.Text=Enum.Font.Gotham,12,value
    item.TextColor3=Color3.fromRGB(170,170,170)
    item.TextWrapped=true
    item.TextXAlignment=Enum.TextXAlignment.Left
    return item
end
local function styleButton(item, value)
    item.BackgroundTransparency=0
    item.BackgroundColor3=Color3.fromRGB(34,34,34)
    item.BorderSizePixel=0
    item.Font,item.TextSize,item.Text=Enum.Font.GothamMedium,12,value
    item.TextColor3=Color3.fromRGB(225,225,225)
    Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
end
local function button(value, callback)
    local item=row("TextButton",34)
    styleButton(item,value)
    item.Activated:Connect(callback)
    return item
end
local function input(placeholder, value, changed)
    local item=row("TextBox",38)
    item.BackgroundTransparency=0
    item.BackgroundColor3=Color3.fromRGB(28,28,28)
    item.BorderSizePixel=0
    item.Font,item.TextSize=Enum.Font.Gotham,12
    item.TextColor3=Color3.fromRGB(235,235,235)
    item.PlaceholderColor3=Color3.fromRGB(130,130,130)
    item.PlaceholderText,item.Text=placeholder,value
    item.ClearTextOnFocus=false
    Instance.new("UICorner",item).CornerRadius=UDim.new(0,6)
    item.FocusLost:Connect(function() changed(item.Text);saveUI() end)
    return item
end
local function api()
    if avatarAPI then return avatarAPI end
    local sha=moduleRevision
    if not sha then
        local stamp=tostring(DateTime.now().UnixTimestampMillis)
        local revision=game:GetService("HttpService"):JSONDecode(game:HttpGet(
            "https://api.github.com/repos/noahkcarmstrong-ops/honey-bun-cosmetic-hub/commits/main?refresh="..stamp,false))
        sha=revision and revision.sha
    end
    assert(type(sha)=="string" and #sha==40 and sha:match("^%x+$"),"Could not find the latest cosmetic update.")
    moduleRevision=sha
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..sha.."/avatar.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    local create=chunk();assert(type(create)=="function","Avatar editor failed to load.")
    assert(alive,"Menu was closed.")
    avatarAPI=create(Players.LocalPlayer,function(message,working)
        if not alive then return end
        busy=working;statusText=message
        if render then render() end
    end)
    return avatarAPI
end
local function motion()
    if motionAPI then return motionAPI end
    api()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/motion.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    motionAPI=chunk()(Players.LocalPlayer,function(message)
        if not alive then return end
        statusText=message
        if statusLabel then statusLabel.Text=message end
    end)
    return motionAPI
end
local function animations()
    if animationAPI then return animationAPI end
    api()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/animations.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    animationAPI=chunk()(Players.LocalPlayer,function(message)
        if not alive then return end
        statusText=message
        if statusLabel then statusLabel.Text=message end
    end)
    return animationAPI
end
local function action(callback)
    if busy or not alive then return end
    busy=true
    statusText="Working..."
    if statusLabel then statusLabel.Text=statusText end
    task.spawn(function()
        local ok,message=pcall(function() return callback(api()) end)
        busy=false
        if not alive then return end
        statusText=ok and (message or "Done.") or ("Could not apply: "..tostring(message):gsub("^.-:%d+:%s*",""))
        render()
    end)
end
render=function()
    if not alive then return end
    for _,item in ipairs(content:GetChildren()) do if item~=layout then item:Destroy() end end
    content.CanvasPosition=Vector2.new(0,0)
    order=0
    for name,item in pairs(tabButtons) do
        item.BackgroundColor3=Color3.fromRGB(name==activePage and 235 or 30,name==activePage and 235 or 30,name==activePage and 235 or 30)
        item.TextColor3=name==activePage and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
    end
    statusLabel=caption(statusText,56)
    statusLabel.AutomaticSize=Enum.AutomaticSize.Y
    persistenceLabel=caption(persistence and persistence.status() or persistenceNotice,44)
    if activePage=="Accessories" then
        caption("ACCESSORIES",24)
        caption("Wear several hats, masks, or hair items together. Paste links or IDs separated by spaces, commas, or new lines (20 items maximum).",60)
        local field=input("Paste accessory links or IDs here",accessoryInput,function(value) accessoryInput=value end)
        field.MultiLine=true;field.TextWrapped=true;field.Size=UDim2.new(1,-8,0,72)
        button("Add accessories",function()
            if busy then return end
            accessoryInput=field.Text
            saveUI()
            local submitted=accessoryInput
            action(function(editor)
                local addedCount,failed,firstError=0,{},nil
                for value in submitted:gmatch("[^%s,;]+") do
                    local ok,message=pcall(editor.equipAccessory,value)
                    if ok then addedCount=addedCount+1
                    else
                        failed[#failed+1]=value
                        firstError=firstError or tostring(message):gsub("^.-:%d+:%s*","")
                    end
                end
                accessoryInput=table.concat(failed,"\n");saveUI()
                if #failed>0 then
                    return string.format("Added %d. %d could not load; left in the box to retry. %s",addedCount,#failed,firstError)
                end
                if addedCount==0 then return "Paste at least one accessory link or ID first." end
                return string.format("Added %d. Your other accessories stay on. Paste more to add another.",addedCount)
            end)
        end)
        local accessories=avatarAPI and avatarAPI.listAccessories and avatarAPI.listAccessories() or {}
        caption(string.format("YOUR ADDED ACCESSORIES (%d / 20)",#accessories),24)
        if #accessories==0 then caption("Nothing added yet. Add an item above to start.",32) end
        if avatarAPI and avatarAPI.listAccessories then
            for index,entry in ipairs(accessories) do
                local key=entry.key
                button(index..". "..entry.name.."  |  Remove",function() action(function(editor) return editor.removeAccessory(key) end) end)
            end
        end
        button("Remove added accessories",function() action(function(editor) return editor.clearAccessories() end) end)
        button("Remove current Roblox accessories",function() action(function(editor) return editor.removeCurrentAccessories() end) end)
        caption("Remove current Roblox accessories hides your original hats and accessories. Restore original appearance brings them back.",48)
    elseif activePage=="Skin" then
        caption("SKIN COLOR",24)
        button("Restore original skin",function() action(function(editor) return editor.restoreSkin() end) end)
        button("Apply to: "..regionNames[regionIndex].."  >",function()
            if busy then return end
            regionIndex=regionIndex%#regions+1;saveUI();render()
        end)
        button(paletteOpen and "Roblox colors  v" or "Roblox colors  >",function()
            if busy then return end
            paletteOpen=not paletteOpen;saveUI();render()
        end)
        if paletteOpen then
            for rowIndex=1,6 do
                local frame=row("Frame",46)
                for column=1,5 do
                    local shade=robloxColors[(rowIndex-1)*5+column]
                    local r,g,b=shade[1],shade[2],shade[3]
                    local swatch=Instance.new("TextButton")
                    swatch.Name=string.format("Color_%02X%02X%02X",r,g,b)
                    swatch.AnchorPoint=Vector2.new(0.5,0.5)
                    swatch.Position=UDim2.new((column-0.5)/5,0,0.5,0)
                    swatch.Size=UDim2.fromOffset(36,36)
                    swatch.BackgroundColor3=Color3.fromRGB(r,g,b)
                    swatch.BorderSizePixel=0;swatch.Text="";swatch.AutoButtonColor=false
                    swatch.Parent=frame
                    Instance.new("UICorner",swatch).CornerRadius=UDim.new(1,0)
                    if tonumber(rgb[1])==r and tonumber(rgb[2])==g and tonumber(rgb[3])==b then
                        local stroke=Instance.new("UIStroke",swatch)
                        stroke.Color=Color3.fromRGB(68,130,255);stroke.Thickness=2
                    end
                    swatch.Activated:Connect(function()
                        if busy then return end
                        rgb={tostring(r),tostring(g),tostring(b)}
                        hexInput=string.format("#%02X%02X%02X",r,g,b)
                        saveUI()
                        action(function(editor) return editor.setSkin(Color3.fromRGB(r,g,b),regions[regionIndex]) end)
                    end)
                end
            end
        end
        caption("Custom RGB color (each number from 0 to 255)",30)
        local fields={}
        for index,name in ipairs({"Red", "Green", "Blue"}) do
            local i=index
            caption(name,20)
            fields[i]=input(name.." 0–255",rgb[i],function(value) rgb[i]=value end)
        end
        button("Apply RGB color",function()
            for i,field in ipairs(fields) do rgb[i]=field.Text end
            saveUI()
            action(function(editor)
                local channels={}
                for i,value in ipairs(rgb) do
                    local n=tonumber(value)
                    assert(n and n==n and n>=0 and n<=255 and n%1==0,"Enter whole RGB numbers from 0 to 255.")
                    channels[i]=n
                end
                local message=editor.setSkin(Color3.fromRGB(channels[1],channels[2],channels[3]),regions[regionIndex])
                hexInput=string.format("#%02X%02X%02X",channels[1],channels[2],channels[3]);saveUI()
                return message
            end)
        end)
        local hex=input("Hex color, for example #FFCC99",hexInput,function(value) hexInput=value end)
        button("Apply hex color",function()
            hexInput=hex.Text
            saveUI()
            action(function(editor)
                local value=hexInput:match("^%s*#?(%x%x%x%x%x%x)%s*$")
                assert(value,"Enter six hex characters, for example #FFCC99.")
                local r,g,b=tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)
                local message=editor.setSkin(Color3.fromRGB(r,g,b),regions[regionIndex])
                rgb={tostring(r),tostring(g),tostring(b)};saveUI()
                return message
            end)
        end)
    elseif activePage=="Emotes" then
        caption("EMOTE WHEEL",24)
        caption("Choose one of the 8 Roblox wheel slots, then paste an emote catalog link or ID. Assignments save through resets and Refresh.",56)
        local slots=motionAPI and motionAPI.getSlots() or {}
        local slotRow
        for index=1,8 do
            local slot=index
            if slot%2==1 then slotRow=row("Frame",34) end
            local entry=slots[slot]
            local label=entry and (entry.name or tostring(entry.id)) or "Original / unassigned"
            local item=Instance.new("TextButton")
            item.Size=UDim2.new(0.5,-3,1,0)
            item.Position=UDim2.new(slot%2==1 and 0 or 0.5,slot%2==1 and 0 or 3,0,0)
            styleButton(item,(slot==emoteSlot and "> " or "").."Slot "..slot..": "..label)
            item.TextTruncate=Enum.TextTruncate.AtEnd
            item.Parent=slotRow
            item.Activated:Connect(function()
                if busy then return end
                emoteSlot=slot;saveUI();render()
            end)
        end
        local field=input("Roblox emote catalog link or ID",emoteInput,function(value) emoteInput=value end)
        button("Assign to slot "..emoteSlot,function()
            emoteInput=field.Text;saveUI()
            action(function() return motion().setEmote(emoteSlot,emoteInput) end)
        end)
        button("Preview slot "..emoteSlot,function() action(function() return motion().playEmote(emoteSlot) end) end)
        button("Reset slot "..emoteSlot,function() action(function() return motion().clearEmote(emoteSlot) end) end)
        button("Open Roblox emote wheel",function() action(function() return motion().openWheel() end) end)
        caption("Playback can be visible to other players through Roblox's normal animation system. Wheel assignments are saved locally.",52)
        caption("The standard wheel needs an R15 avatar and Roblox's emote menu enabled by the game. Some emotes may be restricted.",52)
    elseif activePage=="Animations" then
        caption("ANIMATION BUNDLES",24)
        caption("Paste a Roblox animation bundle link to change your walk, run, idle, and the other movement animations included in that bundle.",56)
        local field=input("roblox.com/bundles/123/... (animation bundle)",animationInput,function(value) animationInput=value end)
        button("Equip animation bundle",function()
            animationInput=field.Text;saveUI()
            action(function() return animations().equipBundle(animationInput) end)
        end)
        button("Restore original animations",function() action(function() return animations().restore() end) end)
        caption("Your equipped bundle saves through resets and Refresh. Walk or run after equipping to see the change.",48)
        caption("Uses your character's existing animation player, which normally shares playback with other players.",44)
        caption("Requires an R15 avatar with Roblox's standard movement controls. Games with custom animation systems may not support bundles.",52)
    else
        caption("BODY PACKAGES",24)
        caption("Choose a classic body or paste a Roblox bundle link. Packages keep your current avatar rig.",44)
        for _,name in ipairs({"Blocky", "Girl", "Robloxian 2.0"}) do
            local preset=name
            button(preset,function() action(function(editor) return editor.applyBody(preset) end) end)
        end
        local field=input("roblox.com/bundles/123/... or bundle ID",bundleInput,function(value) bundleInput=value end)
        button("Apply body package",function()
            bundleInput=field.Text
            saveUI()
            action(function(editor) return editor.applyBody(bundleInput) end)
        end)
        caption("R6 and R15 use different body parts. Unsupported packages show a message instead of changing your avatar rig.",48)
    end
    button("Reapply saved cosmetics",function() action(function(editor)
        local message=editor.reapplySaved()
        if motionAPI then motionAPI.reapplySaved() end
        if animationAPI then animationAPI.reapplySaved() end
        return message
    end) end)
    button("Restore original appearance",function() action(function(editor)
        if motionAPI then motionAPI.restore() end
        if animationAPI then animationAPI.restore() end
        return editor.restore()
    end) end)
end
for index,name in ipairs({"Accessories", "Skin", "Body", "Emotes", "Animations"}) do
    local page=name
    local item=Instance.new("TextButton")
    item.Name=page
    item.Size=UDim2.fromOffset((index==1 or index==5) and 96 or 64,32)
    item.LayoutOrder=index
    item.Parent=tabs
    styleButton(item,string.upper(page))
    item.Activated:Connect(function()
        if busy then return end
        activePage=page;saveUI();render()
    end)
    tabButtons[page]=item
end
local respawn=Players.LocalPlayer.CharacterAdded:Connect(function()
    if not alive then return end
    statusText="New character loading. Saved cosmetics will reapply automatically."
    render()
end)
gui.Destroying:Connect(function()
    alive=false
    connection:Disconnect()
    respawn:Disconnect()
    if avatarAPI then avatarAPI.destroy() end
    if motionAPI then motionAPI.destroy() end
    if animationAPI then animationAPI.destroy() end
    if persistence then persistence.destroy() end
end)
render()
action(function(editor)
    local message=editor.reapplySaved()
    motion().reapplySaved()
    animations().reapplySaved()
    return message
end)
