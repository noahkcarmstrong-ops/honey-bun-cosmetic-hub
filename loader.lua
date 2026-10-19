-- Honey Bun Cosmetic Hub: standalone cosmetic menu.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, name in ipairs({"HoneyBunCosmeticHub"}) do
    local old = playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

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
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.Position = UDim2.fromOffset(28, 112)
tabs.Size = UDim2.new(1, -170, 0, 32)
tabs.BackgroundTransparency = 1
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
local avatarAPI
local refresh = Instance.new("TextButton")
refresh.Position = UDim2.new(1, -126, 0, 112)
refresh.Size = UDim2.fromOffset(98, 32)
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

local alive, busy, activePage = true, false, "Accessories"
local statusText = "Local preview. Changes reset when you respawn or refresh."
local statusLabel, render
local accessoryInput, bundleInput = "", ""
local rgb = {"255", "204", "153"}
local hexInput = "#FFCC99"
local regions = {"All", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
local regionNames = {"Whole body", "Head", "Torso", "Left arm", "Right arm", "Left leg", "Right leg"}
local regionIndex = 1
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
    item.FocusLost:Connect(function() changed(item.Text) end)
    return item
end
local function api()
    if avatarAPI then return avatarAPI end
    local stamp=tostring(DateTime.now().UnixTimestampMillis)
    local revision=game:GetService("HttpService"):JSONDecode(game:HttpGet(
        "https://api.github.com/repos/noahkcarmstrong-ops/honey-bun-cosmetic-hub/commits/main?refresh="..stamp,false))
    local sha=revision and revision.sha
    assert(type(sha)=="string" and #sha==40 and sha:match("^%x+$"),"Could not find the latest cosmetic update.")
    local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-cosmetic-hub/"..sha.."/avatar.lua",false)
    local chunk,message=loadstring(source);assert(chunk,message)
    local create=chunk();assert(type(create)=="function","Avatar editor failed to load.")
    assert(alive,"Menu was closed.")
    avatarAPI=create(Players.LocalPlayer)
    return avatarAPI
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
local function groupButtons(choices)
    local frame=row("Frame",34)
    for index,choice in ipairs(choices) do
        local item=Instance.new("TextButton")
        item.Size=UDim2.new(1/#choices,-6,1,0)
        item.Position=UDim2.new((index-1)/#choices,0,0,0)
        item.Parent=frame
        styleButton(item,choice[1])
        item.Activated:Connect(choice[2])
    end
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
    if activePage=="Accessories" then
        caption("ACCESSORIES",24)
        caption("Paste a Roblox catalog link or item ID. Add hats, masks, hair, and other rigid accessories.",44)
        local field=input("roblox.com/catalog/123456/... or item ID",accessoryInput,function(value) accessoryInput=value end)
        button("Equip accessory",function()
            accessoryInput=field.Text
            action(function(editor) return editor.equipAccessory(accessoryInput) end)
        end)
        button("Remove added accessories",function() action(function(editor) return editor.clearAccessories() end) end)
        if avatarAPI and avatarAPI.listAccessories then
            for _,entry in ipairs(avatarAPI.listAccessories()) do
                local key=entry.key
                button("Remove: "..entry.name,function() action(function(editor) return editor.removeAccessory(key) end) end)
            end
        end
        caption("Your existing avatar accessories stay equipped. Asset access and avatar compatibility vary by game.",44)
    elseif activePage=="Skin" then
        caption("SKIN COLOR",24)
        button("Apply to: "..regionNames[regionIndex].."  >",function()
            if busy then return end
            regionIndex=regionIndex%#regions+1;render()
        end)
        local palette={{"Light",255,224,189},{"Tan",210,161,115},{"Brown",120,78,49},{"Dark",72,48,34},{"Pink",255,170,210},{"Blue",110,190,255}}
        local choices={}
        for _,shade in ipairs(palette) do
            local r,g,b=shade[2],shade[3],shade[4]
            table.insert(choices,{shade[1],function()
                rgb={tostring(r),tostring(g),tostring(b)}
                action(function(editor) return editor.setSkin(Color3.fromRGB(r,g,b),regions[regionIndex]) end)
            end})
        end
        groupButtons(choices)
        caption("Custom RGB color (each number from 0 to 255)",30)
        local fields={}
        for index,name in ipairs({"Red", "Green", "Blue"}) do
            local i=index
            caption(name,20)
            fields[i]=input(name.." 0–255",rgb[i],function(value) rgb[i]=value end)
        end
        button("Apply RGB color",function()
            for i,field in ipairs(fields) do rgb[i]=field.Text end
            action(function(editor)
                local channels={}
                for i,value in ipairs(rgb) do
                    local n=tonumber(value)
                    assert(n and n==n and n>=0 and n<=255 and n%1==0,"Enter whole RGB numbers from 0 to 255.")
                    channels[i]=n
                end
                return editor.setSkin(Color3.fromRGB(channels[1],channels[2],channels[3]),regions[regionIndex])
            end)
        end)
        local hex=input("Hex color, for example #FFCC99",hexInput,function(value) hexInput=value end)
        button("Apply hex color",function()
            hexInput=hex.Text
            action(function(editor)
                local value=hexInput:match("^%s*#?(%x%x%x%x%x%x)%s*$")
                assert(value,"Enter six hex characters, for example #FFCC99.")
                return editor.setSkin(Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)),regions[regionIndex])
            end)
        end)
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
            action(function(editor) return editor.applyBody(bundleInput) end)
        end)
        caption("R6 and R15 use different body parts. Unsupported packages show a message instead of changing your avatar rig.",48)
    end
    button("Restore original appearance",function() action(function(editor) return editor.restore() end) end)
end
for index,name in ipairs({"Accessories", "Skin", "Body"}) do
    local page=name
    local item=Instance.new("TextButton")
    item.Name=page
    item.Size=UDim2.fromOffset(index==1 and 96 or 60,32)
    item.LayoutOrder=index
    item.Parent=tabs
    styleButton(item,string.upper(page))
    item.Activated:Connect(function()
        if busy then return end
        activePage=page;render()
    end)
    tabButtons[page]=item
end
local respawn=Players.LocalPlayer.CharacterAdded:Connect(function()
    if not alive then return end
    statusText="New character loaded. Choose cosmetics to apply again."
    render()
end)
gui.Destroying:Connect(function()
    alive=false
    connection:Disconnect()
    respawn:Disconnect()
    if avatarAPI then avatarAPI.destroy() end
end)
render()
