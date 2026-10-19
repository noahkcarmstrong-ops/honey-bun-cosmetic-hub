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
text(panel, "COSMETICS", UDim2.fromOffset(28, 55), UDim2.new(1, -56, 0, 20), 10, 110)

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
do
    local cosmeticTab = Instance.new("TextButton")
    cosmeticTab.Name = "Cosmetics"
    cosmeticTab.Size = UDim2.fromOffset(110, 32)
    cosmeticTab.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
    cosmeticTab.BorderSizePixel = 0
    cosmeticTab.Text = "COSMETICS"
    cosmeticTab.TextColor3 = Color3.fromRGB(20, 20, 20)
    cosmeticTab.TextSize = 12
    cosmeticTab.Font = Enum.Font.GothamMedium
    cosmeticTab.AutoButtonColor = false
    cosmeticTab.Parent = tabs
    Instance.new("UICorner", cosmeticTab).CornerRadius = UDim.new(0, 6)
end
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
gui.Destroying:Connect(function()
    connection:Disconnect()
end)

text(content, "Hats and effects coming soon.", UDim2.fromOffset(0, 0),
    UDim2.new(1, -8, 0, 48), 12, 170).TextWrapped = true
