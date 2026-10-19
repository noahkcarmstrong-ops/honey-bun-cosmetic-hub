-- Larpblox: standalone cosmetic menu.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
-- Classic Roblox chrome: blue title bar, pale panels, bordered controls.
local theme={blue=Color3.fromRGB(0,112,192),blueHover=Color3.fromRGB(0,133,220),
    paper=Color3.fromRGB(240,242,245),ink=Color3.fromRGB(42,48,56),muted=Color3.fromRGB(91,100,110),
    button=Color3.fromRGB(224,229,235),hover=Color3.fromRGB(207,224,240),edge=Color3.fromRGB(166,178,190)}
local TweenService
pcall(function() TweenService=game:GetService("TweenService") end)
local tweens=setmetatable({},{__mode="k"})
local function smooth(object,properties,duration,done)
    local previous=tweens[object]
    if previous then previous:Cancel();tweens[object]=nil end
    if not TweenService then
        for key,value in pairs(properties) do object[key]=value end
        if done then done() end
        return
    end
    local tween=TweenService:Create(object,TweenInfo.new(duration or 0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
    tweens[object]=tween
    tween.Completed:Connect(function(state)
        if tweens[object]~=tween then return end
        tweens[object]=nil
        if done and state==Enum.PlaybackState.Completed then done() end
    end)
    tween:Play()
end
local buttonStates=setmetatable({},{__mode="k"})
local function animateButton(item,base,hover)
    local state={base=base or theme.button,hover=hover or theme.hover,over=false}
    buttonStates[item]=state
    item.AutoButtonColor=false
    local scale=Instance.new("UIScale",item);scale.Scale=1
    local function paint() smooth(item,{BackgroundColor3=state.over and state.hover or state.base}) end
    if item.MouseEnter then item.MouseEnter:Connect(function()state.over=true;paint()end) end
    if item.MouseLeave then item.MouseLeave:Connect(function()state.over=false;paint();smooth(scale,{Scale=1})end) end
    if item.MouseButton1Down then item.MouseButton1Down:Connect(function()smooth(scale,{Scale=0.98},0.08)end) end
    if item.MouseButton1Up then item.MouseButton1Up:Connect(function()smooth(scale,{Scale=1},0.12)end) end
    item.Activated:Connect(function()smooth(scale,{Scale=1},0.12)end)
    item.Destroying:Connect(function()
        for _,object in ipairs({item,scale}) do if tweens[object] then tweens[object]:Cancel();tweens[object]=nil end end
    end)
end
local isMM2 = game.GameId == 66654135 or game.PlaceId == 142823291
local mm2MenuOpen = false
local mm2API,mm2NativeAPI,mm2SavedNativeAPI,mm2EffectsAPI,mm2EffectsNativeAPI,mm2EffectsLibraryAPI
local mm2WeaponEditorAPI
local mm2GunLibraryAPI
local accessorySoundsAPI
local mm2Enabled=false
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, name in ipairs({"HoneyBunCosmeticHub"}) do
    local old = playerGui:FindFirstChild(name)
    if old then
        for _,key in ipairs({"HoneyBunCosmeticGuns","HoneyBunCosmeticEffects"}) do
            local value=old:GetAttribute(key)
            if value and not playerGui:GetAttribute(key) then playerGui:SetAttribute(key,value) end
        end
        old:Destroy()
    end
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

local panel = Instance.new("CanvasGroup")
panel.GroupTransparency=0
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.new(1, -48, 0.78, 0)
panel.BackgroundColor3 = theme.paper
panel.BorderSizePixel = 0
panel.Parent = gui
local limits = Instance.new("UISizeConstraint", panel)
limits.MaxSize = Vector2.new(520, 760)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 3)
-- Draw the edge inside the fading canvas, not on its clipped outer boundary.
local outline=Instance.new("Frame",panel)
outline.Name="MenuOutline";outline.BackgroundTransparency=1;outline.BorderSizePixel=0
outline.Position=UDim2.fromOffset(1,1);outline.Size=UDim2.new(1,-2,1,-2)
outline.ZIndex=10;outline.Active=false
Instance.new("UICorner",outline).CornerRadius=UDim.new(0,2)
local border = Instance.new("UIStroke", outline)
border.Thickness=1
border.Color = Color3.fromRGB(55,80,105)
local header=Instance.new("Frame",panel)
header.Name="ClassicTitleBar";header.Size=UDim2.new(1,0,0,96)
header.BackgroundColor3=theme.blue;header.BorderSizePixel=0
local headerGradient=Instance.new("UIGradient",header)
headerGradient.Color=ColorSequence.new(Color3.fromRGB(0,132,215),Color3.fromRGB(0,91,164))
headerGradient.Rotation=90
local panelScale=Instance.new("UIScale",panel);panelScale.Scale=1

local function text(parent, value, position, size, fontSize, shade)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.SourceSans
    label.Text = value
    label.TextSize = fontSize
    label.TextColor3 = theme.ink
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local brandFallback = text(panel, "LARPBLOX", UDim2.fromOffset(28, 26), UDim2.new(1, -100, 0, 48), 28, 240)
brandFallback.Font = Enum.Font.SourceSansBold
brandFallback.TextColor3=Color3.fromRGB(255,255,255)
local customAsset = getcustomasset or getsynasset
if type(customAsset)=="function" and type(writefile)=="function" and moduleRevision then
    task.spawn(function()
        pcall(function()
            local file = "Larpblox-logo.png"
            local bytes = game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/assets/larpblox-logo.png", false)
            assert(bytes:sub(1,8)=="\137PNG\13\10\26\10", "Invalid logo image")
            writefile(file, bytes)
            local logo = Instance.new("ImageLabel")
            logo.Name = "LarpbloxLogo"
            logo.BackgroundTransparency = 1
            logo.Position = UDim2.fromOffset(28, 22)
            logo.Size = UDim2.new(1, -110, 0, 58)
            logo.ScaleType = Enum.ScaleType.Fit
            logo.Image = customAsset(file)
            logo.Parent = panel
            brandFallback.Visible = false
        end)
    end)
end

local hide = Instance.new("TextButton")
hide.Position = UDim2.new(1, -60, 0, 23)
hide.Size = UDim2.fromOffset(32, 32)
hide.BackgroundTransparency = 1
hide.Text = "−"
hide.TextSize = 24
hide.TextColor3 = Color3.fromRGB(255,255,255)
hide.Font = Enum.Font.SourceSans
hide.Parent = panel

local line = Instance.new("Frame", panel)
line.Position = UDim2.fromOffset(28, 96)
line.Size = UDim2.new(1, -56, 0, 1)
line.BackgroundColor3 = theme.edge
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
local avatarAPI,motionAPI,animationAPI,clothesAPI,charactersAPI,previewsAPI
local refresh = Instance.new("TextButton")
refresh.Position = UDim2.new(1, -126, 0, 62)
refresh.Size = UDim2.fromOffset(98, 26)
refresh.BackgroundColor3 = Color3.fromRGB(0,88,160)
refresh.BorderSizePixel = 0
refresh.Text = "Refresh"
refresh.TextColor3 = Color3.fromRGB(255,255,255)
refresh.TextSize = 12
refresh.Font = Enum.Font.SourceSansSemibold
refresh.Parent = panel
Instance.new("UICorner", refresh).CornerRadius = UDim.new(0, 2)
animateButton(refresh,Color3.fromRGB(0,88,160),theme.blueHover)
animateButton(hide,theme.blue,theme.blueHover)

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
        warn("Larpblox: refresh failed", message)
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

local menuVisible=true
local function showMenu(visible)
    menuVisible=visible
    if visible then
        panel.Visible=true
        smooth(panelScale,{Scale=1},0.32)
        smooth(panel,{GroupTransparency=0,Position=UDim2.new(1,-24,0.5,0)},0.32)
    else
        smooth(panelScale,{Scale=0.975},0.24)
        smooth(panel,{GroupTransparency=1,Position=UDim2.new(1,-12,0.5,0)},0.24,function() if not menuVisible then panel.Visible=false end end)
    end
end
hide.Activated:Connect(function() showMenu(false) end)
local connection = Input.InputBegan:Connect(function(key)
    if Input:GetFocusedTextBox() then return end
    if key.KeyCode == Enum.KeyCode.RightShift then
        showMenu(not menuVisible)
    end
end)

local function uiSetting(key,default)
    local value=playerGui:GetAttribute("HoneyBunCosmeticUI_"..key)
    return type(value)==type(default) and value or default
end
local copyPlayerInput=uiSetting("copyPlayer","")
local knifeSide=uiSetting("mm2KnifeSide",false)
local alive, busy, activePage = true, false, uiSetting("page","Accessories")
local actionRunning=false
if activePage~="Accessories" and activePage~="Clothes" and activePage~="Skin" and activePage~="Body" and activePage~="Emotes" and activePage~="Animations" and activePage~="Characters" and not (isMM2 and activePage=="MM2") then activePage="Accessories" end
local statusText = "Local avatar editor. Saved selections reapply automatically."
local statusLabel, render,lastRenderedPage
local accessoryInput, bundleInput = uiSetting("accessory",""), uiSetting("bundle","")
local emoteInput,animationInput=uiSetting("emote",""),uiSetting("animationBundle","")
local shirtInput,pantsInput=uiSetting("shirt",""),uiSetting("pants","")
local characterName=uiSetting("characterName","")
local deleteCharacter,characterMenu,characterDialog
local characterSearch=""
local bodyPartRegions={"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"}
local bodyPartNames={"Head","Torso","Left arm","Right arm","Left leg","Right leg"}
local bodyPartInputs={}
for _,region in ipairs(bodyPartRegions) do bodyPartInputs[region]=uiSetting("part_"..region,"") end
local bodyPartsOpen=uiSetting("bodyPartsOpen",false)
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
    local values={page=activePage,accessory=accessoryInput,bundle=bundleInput,red=rgb[1],green=rgb[2],blue=rgb[3],hex=hexInput,region=regionIndex,palette=paletteOpen,emote=emoteInput,animationBundle=animationInput,emoteSlot=emoteSlot,shirt=shirtInput,pants=pantsInput}
    values.bodyPartsOpen=bodyPartsOpen
    values.characterName=characterName
    values.copyPlayer=copyPlayerInput
    values.mm2KnifeSide=knifeSide
    for _,region in ipairs(bodyPartRegions) do values["part_"..region]=bodyPartInputs[region] end
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
    item.Font,item.TextSize,item.Text=Enum.Font.SourceSans,14,value
    item.TextColor3=theme.muted
    item.TextWrapped=true
    item.TextXAlignment=Enum.TextXAlignment.Left
    return item
end
local function styleButton(item, value)
    item.BackgroundTransparency=0
    item.BackgroundColor3=theme.button
    item.BorderSizePixel=0
    item.Font,item.TextSize,item.Text=Enum.Font.SourceSansSemibold,15,value
    item.TextColor3=theme.ink
    item.BorderSizePixel=1;item.BorderColor3=theme.edge
    animateButton(item)
    Instance.new("UICorner",item).CornerRadius=UDim.new(0,2)
end
local function button(value, callback)
    local item=row("TextButton",36)
    styleButton(item,value)
    item.Activated:Connect(callback)
    return item
end
local function input(placeholder, value, changed)
    local item=row("TextBox",38)
    item.BackgroundTransparency=0
    item.BackgroundColor3=Color3.fromRGB(255,255,255)
    item.BorderSizePixel=0
    item.Font,item.TextSize=Enum.Font.SourceSans,15
    item.TextColor3=theme.ink
    item.PlaceholderColor3=theme.muted
    item.PlaceholderText,item.Text=placeholder,value
    item.ClearTextOnFocus=false
    Instance.new("UICorner",item).CornerRadius=UDim.new(0,2)
    item.BorderSizePixel=1;item.BorderColor3=theme.edge
    if item.Focused then item.Focused:Connect(function()smooth(item,{BorderColor3=theme.blue})end) end
    item.FocusLost:Connect(function() smooth(item,{BorderColor3=theme.edge});changed(item.Text);saveUI() end)
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
        busy=working or actionRunning;statusText=message
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
local function clothes()
    if clothesAPI then return clothesAPI end
    api()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/clothes.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    clothesAPI=chunk()(Players.LocalPlayer,function(message)
        if not alive then return end
        statusText=message
        if statusLabel then statusLabel.Text=message end
    end)
    return clothesAPI
end
local function characterModules()
    api()
    local function load(name)
        local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/"..name..".lua",false)
        local chunk,message=loadstring(source);assert(chunk,message)
        assert(alive,"Menu was closed.")
        return chunk()
    end
    if not charactersAPI then charactersAPI=load("characters")(playerGui) end
    if not previewsAPI then previewsAPI=load("previews")(Players.LocalPlayer) end
end
local function reapplyAll(editor)
    local failures={}
    for _,operation in ipairs({
        function() return editor.reapplySaved() end,
        function() return motion().reapplySaved() end,
        function() return animations().reapplySaved() end,
        function() return clothes().reapplySaved() end,
    }) do
        local ok,message=pcall(operation)
        if not ok then failures[#failures+1]=tostring(message):gsub("^.-:%d+:%s*","") end
        if ok and type(message)=="string" and message:find("some could not load",1,true) then failures[#failures+1]=message end
    end
    return #failures==0 and "Saved selections restored." or ("Some saved selections could not load: "..failures[1]),#failures==0
end
local characterKeys={"HoneyBunCosmeticSettings","HoneyBunCosmeticEmotes","HoneyBunCosmeticClothes","HoneyBunCosmeticAnimationBundle"}
local function currentCharacterValues()
    local values={}
    for _,key in ipairs(characterKeys) do values[key]=playerGui:GetAttribute(key) end
    return values
end
local function loadCharacterValues(values)
    -- Recreate editors so their cached settings and original appearance agree.
    for _,editor in pairs({clothesAPI,motionAPI,animationAPI}) do editor.destroy() end
    if avatarAPI then avatarAPI.destroy() end
    avatarAPI,motionAPI,animationAPI,clothesAPI=nil,nil,nil,nil
    for _,key in ipairs(characterKeys) do playerGui:SetAttribute(key,values[key]) end
    return reapplyAll(api())
end
local function equipCharacter(id)
    local saved=charactersAPI.get(id)
    assert(saved,"That saved character is no longer available.")
    local previous=currentCharacterValues()
    local ok,message,complete=pcall(loadCharacterValues,saved.values)
    if ok and complete then return "Equipped "..saved.name..". This is now your saved look for resets and rejoining." end
    local restored,_,all=pcall(loadCharacterValues,previous)
    error((ok and message or tostring(message))..((restored and all) and " Your previous look was restored." or " Use Reapply saved cosmetics after your avatar finishes loading."))
end
local function action(callback)
    if busy or not alive then return end
    actionRunning=true;busy=true
    statusText="Working..."
    if statusLabel then statusLabel.Text=statusText end
    task.spawn(function()
        local ok,message=pcall(function() return callback(api()) end)
        actionRunning=false;busy=false
        if not alive then return end
        statusText=ok and (message or "Done.") or ("Could not apply: "..tostring(message):gsub("^.-:%d+:%s*",""))
        render()
    end)
end
local function hatSounds()
    if accessorySoundsAPI then return accessorySoundsAPI end
    api()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/accessory_sounds.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    accessorySoundsAPI=chunk()(Players.LocalPlayer,playerGui)
    return accessorySoundsAPI
end
local function mm2()
    assert(isMM2,"This menu is only available in MM2.")
    if mm2API then return mm2API end
    api()
    local librarySource=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/gun_library.lua",false)
    local libraryChunk,libraryError=loadstring(librarySource);assert(libraryChunk,libraryError)
    mm2GunLibraryAPI=libraryChunk()(game,playerGui)
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/mm2.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    mm2API=chunk()(game,nil,mm2GunLibraryAPI)
    mm2API.setKnifeSide(knifeSide)
    return mm2API
end
local function nativeMM2()
    if mm2NativeAPI then return mm2NativeAPI end
    local catalog=mm2()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/native_inventory.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    mm2NativeAPI=chunk()(playerGui,catalog,function(message)
        if not alive then return end
        statusText=message
        if statusLabel then statusLabel.Text=message end
    end)
    return mm2NativeAPI
end
local function savedNativeMM2()
    if mm2SavedNativeAPI then return mm2SavedNativeAPI end
    local backend=mm2()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/native_inventory.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    local function openWeaponEditor(entry,mode)
        if not mm2WeaponEditorAPI then
            local editorSource=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/weapon_editor.lua",false)
            local editorChunk,editorError=loadstring(editorSource);assert(editorChunk,editorError)
            mm2WeaponEditorAPI=editorChunk()(playerGui,{
                getEditorScene=backend.getWeaponEditorScene,
                setWeaponAdjustment=backend.setSavedWeaponAdjustment
            },function(message)if alive and statusLabel then statusLabel.Text=message end end)
        end
        for _,saved in ipairs(backend.savedInventory(entry.kind)) do
            if saved.id==entry.id then entry=saved;break end
        end
        mm2WeaponEditorAPI.open(entry,mode)
    end
    local savedCatalog={list=backend.savedInventory,equip=backend.equip,getEquipped=backend.getEquipped,remove=backend.removeSavedWeapon,rename=backend.renameSavedWeapon,openEditor=openWeaponEditor}
    mm2SavedNativeAPI=chunk()(playerGui,savedCatalog,function(message)
        if alive and statusLabel then statusLabel.Text=message end
    end,"saved")
    return mm2SavedNativeAPI
end
local function effectsMM2()
    assert(isMM2,"This menu is only available in MM2.")
    if mm2EffectsAPI then return mm2EffectsAPI end
    api()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/mm2_effects.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    local librarySource=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/effect_library.lua",false)
    local libraryChunk,libraryError=loadstring(librarySource);assert(libraryChunk,libraryError)
    mm2EffectsLibraryAPI=libraryChunk()(game,playerGui)
    mm2EffectsAPI=chunk()(game,function(message)
        if alive then statusText=message;if statusLabel then statusLabel.Text=message end end
    end,mm2EffectsLibraryAPI)
    return mm2EffectsAPI
end
local function nativeEffectsMM2()
    if mm2EffectsNativeAPI then return mm2EffectsNativeAPI end
    local catalog=effectsMM2()
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..moduleRevision.."/native_inventory.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    mm2EffectsNativeAPI=chunk()(playerGui,catalog,function(message)
        if alive then statusText=message;if statusLabel then statusLabel.Text=message end end
    end,"saved-effects")
    return mm2EffectsNativeAPI
end
render=function()
    if not alive then return end
    local savedScroll=activePage=="Characters" and lastRenderedPage==activePage and content.CanvasPosition
    local pageChanged=lastRenderedPage~=activePage
    lastRenderedPage=activePage
    if pageChanged then
        content.Position=UDim2.fromOffset(28,166)
        smooth(content,{Position=UDim2.fromOffset(28,160)},0.18)
    end
    for _,item in ipairs(content:GetChildren()) do if item~=layout then item:Destroy() end end
    content.CanvasPosition=Vector2.new(0,0)
    order=0
    for name,item in pairs(tabButtons) do
        local selected=name==activePage
        local state=buttonStates[item]
        state.base=selected and theme.blue or theme.button
        state.hover=selected and theme.blueHover or theme.hover
        item.TextColor3=selected and Color3.fromRGB(255,255,255) or theme.ink
        smooth(item,{BackgroundColor3=state.over and state.hover or state.base})
    end
    if activePage~="Characters" then limits.MaxSize=Vector2.new(520,760) end
    statusLabel,persistenceLabel=nil,nil
    if activePage~="Characters" then
        statusLabel=caption(statusText,56)
        statusLabel.AutomaticSize=Enum.AutomaticSize.Y
        persistenceLabel=caption(persistence and persistence.status() or persistenceNotice,44)
    end
    if activePage=="MM2" and isMM2 then
        caption(mm2MenuOpen and "MM2 MENU" or "MURDER MYSTERY 2",24)
        if mm2MenuOpen then
            caption("KNIFE POSITION",24)
            caption("Off: knife on your back. On: knife at your side.",36)
            button(knifeSide and "Boombox layout: ON" or "Boombox layout: OFF",function() action(function()
                local nextValue=not knifeSide
                local _,message=mm2().setKnifeSide(nextValue)
                assert(message==nil,message)
                knifeSide=nextValue;saveUI()
                return knifeSide and "Saved knives are now at your side." or "Saved knives are now on your back."
            end) end)
            caption("SAVE A PLAYER'S LOOK",24)
            caption("Enter a username from this server. Save while they hold the weapon to capture its hand position, toolbar icon, and loaded sounds. Saved copies are for you only.",80)
            local owner=input("Player's Roblox username",copyPlayerInput,function(value)copyPlayerInput=value end)
            local function username()
                copyPlayerInput=owner.Text:gsub("^%s+",""):gsub("%s+$","")
                saveUI()
                assert(copyPlayerInput~="","Enter a Roblox username from this server.")
                return copyPlayerInput
            end
            local function updateWeapons()
                if mm2Enabled then
                    nativeMM2().disable()
                    local ok=nativeMM2().enable()
                    if ok==false then mm2Enabled=false end
                    savedNativeMM2().enable();savedNativeMM2().refreshSaved()
                else
                    savedNativeMM2().enable();savedNativeMM2().refreshSaved()
                end
            end
            local function copyWeapon(kind)
                local message=mm2().collectPlayerWeapon(username(),kind)
                updateWeapons()
                return message
            end
            local function copyEffect()
                effectsMM2()
                local message,ids=mm2EffectsLibraryAPI.capturePlayer(username())
                mm2EffectsAPI.reloadLibrary()
                if ids and ids[1] then message=message.." "..mm2EffectsAPI.equip(ids[1],"Effect") end
                nativeEffectsMM2().enable();nativeEffectsMM2().refreshSaved()
                return message
            end
            button("Save and equip player's gun",function() action(function() return copyWeapon("Gun") end) end)
            button("Save and equip player's knife",function() action(function() return copyWeapon("Knife") end) end)
            button("Save and equip player's effect",function() action(copyEffect) end)
            button("Save all three",function() action(function()
                username()
                local messages={}
                for _,operation in ipairs({function()return copyWeapon("Gun")end,function()return copyWeapon("Knife")end,copyEffect}) do
                    local ok,message=pcall(operation)
                    messages[#messages+1]=ok and message or tostring(message):gsub("^.-:%d+:%s*","")
                end
                return table.concat(messages,"\n")
            end) end)
            caption("YOUR SAVED WEAPONS",24)
            caption("Open MM2's Weapons inventory → Saved Weapons. All copied guns and knives stay together there. Click a card to equip. Use its cog menu to rename or delete your saved copy.",64)
            button("Refresh saved weapons in MM2 inventory",function() action(function()
                updateWeapons()
                return "Open MM2's Weapons inventory and select Saved Weapons. All your copied guns and knives are there."
            end) end)
            button("Remove saved weapon appearances",function() action(function()return mm2().restore()end) end)
            caption("FIX AN UNIDENTIFIED WEAPON",24)
            caption("Equip a saved copy, then enter its original MM2 name to match its name, icon, and rarity.",48)
            local weaponName=input("Original weapon name or item ID","",function()end)
            for _,kind in ipairs({"Knife","Gun"}) do
                button("Match equipped saved "..kind:lower(),function() action(function()
                    local message=mm2().identifySavedWeapon(weaponName.Text,kind)
                    updateWeapons();return message
                end) end)
            end
            caption("OPTIONAL MM2 INVENTORY DISPLAY",24)
            caption("Saved copies appear only in Saved Weapons. Show all weapons displays the separate game catalog.",48)
            button(mm2Enabled and "Show all weapons: ON" or "Show all weapons: OFF",function() action(function()
                if mm2Enabled then
                    nativeMM2().disable();mm2Enabled=false;savedNativeMM2().enable()
                    return "Original inventory display restored. Your saved weapon appearance stays equipped."
                end
                local ok,message=nativeMM2().enable()
                savedNativeMM2().enable();savedNativeMM2().refreshSaved()
                assert(ok~=false,message or "MM2 inventory could not be detected.")
                mm2Enabled=true;return type(ok)=="string" and ok or message
            end) end)
            button("Refresh saved effects in MM2 inventory",function() action(function()
                nativeEffectsMM2().enable();nativeEffectsMM2().refreshSaved()
                effectsMM2().collectOriginals()
                return "Saved effects appear automatically in MM2's Effects inventory."
            end) end)

            button("Collect server effects",function() action(function()
                effectsMM2()
                local message=mm2EffectsLibraryAPI.captureServer(copyPlayerInput)
                mm2EffectsAPI.reloadLibrary()
                nativeEffectsMM2().enable();nativeEffectsMM2().refreshSaved()
                return message
            end) end)

            button("Copy MM2 report",function() action(function()
                local report=mm2().report().."\n"..nativeMM2().report()
                if mm2SavedNativeAPI then report=report.."\n"..mm2SavedNativeAPI.report() end
                if mm2EffectsAPI then report=report.."\n"..mm2EffectsAPI.report() end
                if mm2EffectsLibraryAPI then report=report.."\n"..mm2EffectsLibraryAPI.report() end
                if mm2EffectsNativeAPI then report=report.."\n"..mm2EffectsNativeAPI.report() end
                if type(setclipboard)=="function" then
                    setclipboard(report)
                    return "MM2 report copied. Paste it into chat if a preview cannot load."
                end
                return report
            end) end)
            button("Back",function() mm2MenuOpen=false;render() end)
        else
            caption("Open your dedicated MM2 menu below.",40)
            button("Open MM2 menu",function() mm2MenuOpen=true;render() end)
        end
    elseif activePage=="Characters" then
        limits.MaxSize=Vector2.new(1050,850)
        local toolbar=row("Frame",34)
        local search=Instance.new("TextBox",toolbar)
        search.Name="CharacterSearch";search.Size=UDim2.new(1,-176,1,0)
        search.BackgroundColor3=Color3.fromRGB(255,255,255);search.BorderSizePixel=1;search.BorderColor3=theme.edge
        search.Font=Enum.Font.SourceSans;search.TextSize=13;search.TextColor3=theme.ink
        search.PlaceholderText="Search by name...";search.PlaceholderColor3=theme.muted
        search.Text=characterSearch;search.ClearTextOnFocus=false
        Instance.new("UICorner",search).CornerRadius=UDim.new(0,2)
        local create=Instance.new("TextButton",toolbar)
        create.Position=UDim2.new(1,-166,0,0);create.Size=UDim2.fromOffset(166,34)
        styleButton(create,"Create New Character")
        create.Activated:Connect(function()
            if busy then return end
            characterDialog={kind="create"};characterMenu=nil;characterName="";render()
        end)
        if characterDialog then
            local rename=characterDialog.kind=="rename"
            caption(rename and "Rename Character" or "Create New Character",24)
            local field=input("Character name",characterName,function(value) characterName=value end)
            button(rename and "Save Name" or "Create",function()
                if busy then return end
                characterName=field.Text;saveUI()
                local dialog=characterDialog
                action(function()
                    characterModules()
                    local saved
                    if dialog.kind=="rename" then saved=charactersAPI.rename(dialog.id,characterName)
                    else saved=charactersAPI.save(characterName,previewsAPI.capture()) end
                    characterName="";characterDialog=nil;characterSearch="";saveUI()
                    return "Saved "..saved.name.."."
                end)
            end)
            button("Cancel",function() if not busy then characterDialog=nil;render() end end)
        end
        if charactersAPI then
            local saved=charactersAPI.list()
            local grid=row("Frame",0);grid.Name="CharacterGrid"
            local arrangement=Instance.new("UIGridLayout",grid)
            arrangement.SortOrder=Enum.SortOrder.LayoutOrder;arrangement.CellPadding=UDim2.fromOffset(10,20)
            local cards={}
            local empty=caption(#saved==0 and "No characters yet. Choose Create New Character to save your current look." or "No characters found.",44)
            local function fitGrid()
                local width=grid.AbsoluteSize and grid.AbsoluteSize.X or 440
                if width<=0 then width=440 end
                local columns=math.max(1,math.floor((width+10)/134))
                local cell=(width-(columns-1)*10)/columns
                arrangement.FillDirectionMaxCells=columns
                arrangement.CellSize=UDim2.new(1/columns,-10*(columns-1)/columns,0,cell+38)
                local count=0
                for _,entry in ipairs(cards) do
                    entry.card.Visible=entry.name:lower():find(characterSearch:lower(),1,true)~=nil
                    if entry.card.Visible then count=count+1 end
                end
                local rows=math.ceil(count/columns)
                grid.Size=UDim2.new(1,-8,0,rows>0 and rows*(cell+58)-20 or 0)
                empty.Visible=count==0
            end
            for index,entry in ipairs(saved) do
                local id,name=entry.id,entry.name
                local card=Instance.new("Frame",grid)
                card.Name="CharacterCard_"..id;card.BackgroundTransparency=1;card.LayoutOrder=index
                cards[#cards+1]={card=card,name=name}
                local image=Instance.new("TextButton",card)
                image.Name="EquipCharacter_"..id;image.Text="";image.BorderSizePixel=0
                image.Size=UDim2.new(1,0,1,-38);image.BackgroundColor3=theme.button
                animateButton(image)
                Instance.new("UICorner",image).CornerRadius=UDim.new(0,2)
                image.Activated:Connect(function() action(function() return equipCharacter(id) end) end)
                local viewport=Instance.new("ViewportFrame",image)
                viewport.Name="CharacterPreview_"..id;viewport.Position=UDim2.new(0.06,0,0.04,0);viewport.Size=UDim2.new(0.88,0,0.92,0)
                viewport.BackgroundTransparency=1;viewport.Active=false
                local previewData,previewAPI=entry.preview,previewsAPI
                task.spawn(function()
                    local shown,result=false,false
                    if previewAPI then shown,result=pcall(previewAPI.show,viewport,previewData) end
                    if alive and image.Parent and (not shown or not result) then
                        local missing=text(image,"Preview unavailable",UDim2.new(0,4,0.4,0),UDim2.new(1,-8,0,30),10,190)
                        missing.TextWrapped=true
                    end
                end)
                local title=text(card,name,UDim2.new(0,0,1,-32),UDim2.new(1,-2,0,32),16,235)
                title.Font=Enum.Font.SourceSansBold;title.TextWrapped=true;title.TextTruncate=Enum.TextTruncate.AtEnd;title.TextYAlignment=Enum.TextYAlignment.Top
                local cog=Instance.new("TextButton",image)
                cog.Name="CharacterOptions_"..id;cog.Text="⚙";cog.Font=Enum.Font.SourceSans;cog.TextSize=20
                cog.Size=UDim2.fromOffset(30,30);cog.Position=UDim2.new(1,-31,0,1)
                cog.BackgroundTransparency=1;cog.TextColor3=theme.ink
                animateButton(cog);cog.ZIndex=5
                cog.Activated:Connect(function()
                    if busy then return end
                    if characterMenu==id then characterMenu=nil else characterMenu=id end
                    deleteCharacter=nil;render()
                end)
                if characterMenu==id then
                    local menu=Instance.new("Frame",image)
                    menu.Name="CharacterMenu_"..id;menu.Size=UDim2.new(1,0,1,0)
                    menu.Active=true;menu.BackgroundColor3=theme.paper;menu.BackgroundTransparency=0.04;menu.BorderSizePixel=0;menu.ZIndex=3
                    Instance.new("UICorner",menu).CornerRadius=UDim.new(0,2)
                    local function option(label,position,callback)
                        local item=Instance.new("TextButton",menu)
                        item.Text=label;item.Font=Enum.Font.SourceSansSemibold;item.TextSize=12
                        item.TextColor3=theme.ink;item.BackgroundTransparency=0
                        item.BackgroundColor3=theme.button;animateButton(item)
                        item.Position=UDim2.new(0,0,position,0);item.Size=UDim2.new(1,0,0.20,0);item.ZIndex=4
                        item.Activated:Connect(callback)
                    end
                    if deleteCharacter==id then
                        option("Confirm delete",0.34,function() action(function()
                            charactersAPI.delete(id);deleteCharacter=nil;characterMenu=nil
                            return "Deleted "..name..". Your equipped look stays on."
                        end) end)
                        option("Cancel",0.56,function() if not busy then deleteCharacter=nil;characterMenu=nil;render() end end)
                    else
                        option("Update",0.17,function() action(function()
                            local saved=charactersAPI.update(id,previewsAPI.capture());characterMenu=nil
                            return "Updated "..saved.name.." with your current look."
                        end) end)
                        option("Rename",0.37,function()
                            if busy then return end
                            characterDialog={kind="rename",id=id};characterName=name;characterMenu=nil;render()
                        end)
                        option("Delete",0.57,function() if not busy then deleteCharacter=id;render() end end)
                        option("Cancel",0.77,function() if not busy then characterMenu=nil;render() end end)
                    end
                end
            end
            search:GetPropertyChangedSignal("Text"):Connect(function() characterSearch=search.Text;fitGrid() end)
            grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGrid)
            fitGrid()
        else
            caption("Open this tab again to load your saved characters.",40)
        end
        caption(statusText,44)
        caption(persistence and persistence.status() or persistenceNotice,44)
    elseif activePage=="Accessories" then
        caption("ACCESSORIES",24)
        local soundsEnabled=playerGui:GetAttribute("HoneyBunCosmeticUI_HatSounds")~=false
        button(soundsEnabled and "Hat sounds: ON" or "Hat sounds: OFF",function() action(function()
            local sounds=hatSounds();return sounds.setEnabled(not sounds.isEnabled())
        end) end)
        button("Play hat sounds now",function() action(function()return hatSounds().playNow()end)end)
        caption("Original hat audio, heard by you. Witches Brew laughs randomly every 5–15 seconds. Some audio may be restricted by Roblox.",56)
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
        button("Copy accessory report",function() action(function(editor)
            local report=editor.accessoryReport()
            if type(setclipboard)=="function" then setclipboard(report);return "Accessory report copied. Paste it into chat if hats still stay on." end
            return report
        end) end)
        caption("Remove current Roblox accessories hides your original hats and accessories. Restore original appearance brings them back.",48)
    elseif activePage=="Clothes" then
        caption("CLASSIC CLOTHES",24)
        caption("Paste classic 2D shirt and pants catalog links. Equip each separately; your other cosmetics stay on. Layered 3D clothing is not supported.",64)
        caption("SHIRT",22)
        local shirt=input("Classic shirt catalog link or ID",shirtInput,function(value) shirtInput=value end)
        button("Equip shirt",function()
            shirtInput=shirt.Text;saveUI()
            action(function() return clothes().equipShirt(shirtInput) end)
        end)
        button("Restore original shirt",function() action(function() return clothes().restoreShirt() end) end)
        caption("PANTS",22)
        local pants=input("Classic pants catalog link or ID",pantsInput,function(value) pantsInput=value end)
        button("Equip pants",function()
            pantsInput=pants.Text;saveUI()
            action(function() return clothes().equipPants(pantsInput) end)
        end)
        button("Restore original pants",function() action(function() return clothes().restorePants() end) end)
        caption("Shirts and pants save through resets, Refresh, and rejoining when file auto-save is on.",48)
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
        button(bodyPartsOpen and "Custom body parts  v" or "Custom body parts  >",function()
            if busy then return end
            bodyPartsOpen=not bodyPartsOpen;saveUI();render()
        end)
        if bodyPartsOpen then
            caption("Mix different packages on an R15 avatar. Paste a body package link for a region, or use that individual body part's catalog link / asset ID.",64)
            for index,region in ipairs(bodyPartRegions) do
                local part,label=region,bodyPartNames[index]
                caption(string.upper(label),22)
                local partField=input(label.." catalog or bundle link / asset ID",bodyPartInputs[part],function(value) bodyPartInputs[part]=value end)
                button("Equip "..string.lower(label),function()
                    bodyPartInputs[part]=partField.Text;saveUI()
                    action(function(editor) return editor.applyBodyPart(part,bodyPartInputs[part]) end)
                end)
            end
            caption("Arms and legs include their matching hand or foot. A new full body package replaces your mixed part selections.",48)
        end
        button("Restore original body",function() action(function(editor) return editor.restoreBody() end) end)
        caption("R6 and R15 use different body parts. Unsupported packages show a message instead of changing your avatar rig.",48)
    end
    if activePage~="Characters" and activePage~="MM2" then
    button("Reapply saved cosmetics",function() action(reapplyAll) end)
    button("Restore original appearance",function() action(function(editor)
        if motionAPI then motionAPI.restore() end
        if animationAPI then animationAPI.restore() end
        if clothesAPI then clothesAPI.restore() end
        return editor.restore()
    end) end)
    end
    if savedScroll then content.CanvasPosition=savedScroll end
end
local pages={"Accessories", "Clothes", "Skin", "Body", "Emotes", "Animations", "Characters"}
if isMM2 then table.insert(pages,"MM2") end
for index,name in ipairs(pages) do
    local page=name
    local item=Instance.new("TextButton")
    item.Name=page
    item.Size=UDim2.fromOffset((page=="Accessories" or page=="Animations" or page=="Characters") and 96 or 64,32)
    item.LayoutOrder=index
    item.Parent=tabs
    styleButton(item,string.upper(page))
    item.Activated:Connect(function()
        if busy then return end
        activePage=page;deleteCharacter=nil;characterMenu=nil;characterDialog=nil;saveUI()
        if page=="Characters" and not charactersAPI then action(function() characterModules();return "Save a look or equip one from your wardrobe below." end)
        else render() end
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
    for object,tween in pairs(tweens) do tween:Cancel();tweens[object]=nil end
    respawn:Disconnect()
    if mm2EffectsNativeAPI then mm2EffectsNativeAPI.destroy() end
    if mm2EffectsAPI then mm2EffectsAPI.destroy() end
    if mm2EffectsLibraryAPI then mm2EffectsLibraryAPI.destroy() end
    if mm2WeaponEditorAPI then mm2WeaponEditorAPI.destroy() end
    if mm2SavedNativeAPI then mm2SavedNativeAPI.destroy() end
    if mm2NativeAPI then mm2NativeAPI.destroy() end
    if mm2API then mm2API.destroy() end
    if accessorySoundsAPI then accessorySoundsAPI.destroy() end
    if persistence then persistence.destroy() end
    if avatarAPI then avatarAPI.destroy() end
    if motionAPI then motionAPI.destroy() end
    if animationAPI then animationAPI.destroy() end
    if clothesAPI then clothesAPI.destroy() end
    if previewsAPI and previewsAPI.destroy then previewsAPI.destroy() end
end)
panelScale.Scale=0.975
panel.GroupTransparency=1
panel.Position=UDim2.new(1,-12,0.5,0)
showMenu(true)
render()
action(function(editor)
    local soundsLoaded=pcall(hatSounds)
    local message=reapplyAll(editor)
    if not soundsLoaded then message=message.." Hat sounds could not load; try their control in Accessories." end
    if activePage=="Characters" then characterModules() end
    if isMM2 and playerGui:GetAttribute("HoneyBunCosmeticGuns") then mm2();savedNativeMM2().enable() end
    if isMM2 and playerGui:GetAttribute("HoneyBunCosmeticEffects") then effectsMM2();nativeEffectsMM2().enable() end
    return message
end)
