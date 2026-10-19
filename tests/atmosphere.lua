local objects = {}
local methods = {}
local meta = {__index = function(o, k) return methods[k] or o.props[k] end,
    __newindex = function(o, k, v) o.props[k] = v end}

Instance = {new = function(class, parent)
    local o = setmetatable({props = {ClassName = class, Name = class, Parent = parent}, destroyed = false}, meta)
    table.insert(objects, o)
    return o
end}
function methods:IsA(class) return self.ClassName == class end
function methods:GetChildren()
    local out = {}
    for _, o in ipairs(objects) do if not o.destroyed and o.Parent == self then table.insert(out, o) end end
    return out
end
function methods:FindFirstChild(name)
    for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self:GetChildren()) do if child.ClassName == class then return child end end
end
function methods:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent = nil
end
function methods:Clone()
    local copy = Instance.new(self.ClassName)
    for k, v in pairs(self.props) do if k ~= "Parent" then copy[k] = v end end
    for _, child in ipairs(self:GetChildren()) do child:Clone().Parent = copy end
    return copy
end

local lighting = Instance.new("Lighting")
local original = Instance.new("Sky", lighting); original.Name = "Original"; original.SkyboxBk = "old"
local game = {Lighting = lighting, assets = {}, fail = false, cancel = false}
local api
function game:GetService(name) assert(name == "Lighting"); return self.Lighting end
function game:GetObjects(uri)
    assert(uri == "rbxassetid://123")
    if self.fail then error("network") end
    if self.cancel then self.cancel = false; api.restore() end
    return self.assets
end

local module = dofile("atmosphere.lua")
api = module(game)
local function model(name, skies)
    local root = Instance.new("Model"); root.Name = name
    for _, sky in ipairs(skies or {}) do sky.Parent = root end
    return root
end
local function sky(name)
    local s = Instance.new("Sky"); s.Name = name; s.SkyboxBk = name; return s
end

assert(not api.apply("0"), "zero is invalid")
assert(not api.apply("123abc"), "loose IDs are invalid")
assert(not api.apply("https://roblox.com/library/0"), "zero URL is invalid")
assert(original.Parent == lighting and original.SkyboxBk == "old")

local noSky = model("NoSky")
game.assets = {noSky}; assert(not api.apply(123), "models without Sky are rejected")
assert(noSky.destroyed and original.Parent == lighting, "failed load leaves Lighting alone and cleans wrappers")

local ambiguous=model("Ambiguous",{sky("A"),sky("B")});game.assets={ambiguous}
assert(not api.apply("123") and ambiguous.destroyed and original.Parent==lighting,"Ambiguous models are rejected and cleaned without changing the sky")
local source = sky("Source"); local script = Instance.new("Script", source)
local wrapper = model("Wrapper", {source}); game.assets = {wrapper}
assert(api.apply("https://create.roblox.com/store/asset/123/Custom-Sky"))
assert(original.Parent == nil and wrapper.destroyed and script.destroyed, "success sanitizes and cleans source assets")
local custom = lighting:FindFirstChildOfClass("Sky"); assert(custom and custom ~= original and custom.Name == "Source")
assert(#custom:GetChildren() == 0, "cloned Sky has no untrusted descendants")

game.fail = true; assert(not api.apply("rbxassetid://123"), "failed replacement is reported")
assert(custom.Parent == lighting and not custom.destroyed, "failed replacement keeps current sky")
game.fail = false
local second = sky("Second"); local secondWrapper = model("SecondWrapper", {second}); game.assets = {secondWrapper}
assert(api.apply("https://roblox.com/asset/?id=123")); assert(custom.destroyed and secondWrapper.destroyed)
assert(api.restore()); assert(original.Parent == lighting and second.Parent == nil, "restore returns exact original object")
local late = sky("Late"); local lateWrapper = model("LateWrapper", {late}); game.assets = {lateWrapper}; game.cancel = true
assert(not api.apply(123), "a replacement cancelled during loading is rejected")
assert(lateWrapper.destroyed, "cancelled replacement cleans wrappers")
assert(original.Parent == lighting, "cancelled replacement preserves originals")
api.destroy(); assert(original.Parent == lighting and api.apply(123) == false, "destroy restores and disables API")

print("Atmosphere validation, replacement, sanitization, failure, restore, and destroy passed.")
