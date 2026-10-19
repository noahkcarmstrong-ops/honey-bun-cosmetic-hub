local function signal()
    local s = {listeners = {}}
    function s:Connect(fn)
        local c = {Connected = true, fn = fn}
        function c:Disconnect() self.Connected = false end
        table.insert(self.listeners, c)
        return c
    end
    function s:Fire(...) for _, c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
    return s
end

local function object(class, name, parent)
    local o = {ClassName = class, Name = name or class, Parent = parent}
    function o:IsA(kind) return self.ClassName == kind end
    function o:GetChildren()
        local result = {}
        for _, child in ipairs(self.children or {}) do if child.Parent == self then table.insert(result, child) end end
        return result
    end
    function o:Add(child) self.children = self.children or {}; child.Parent = self; table.insert(self.children, child); return child end
    function o:FindFirstChild(name)
        for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
    end
    function o:FindFirstChildOfClass(kind)
        for _, child in ipairs(self:GetChildren()) do if child.ClassName == kind then return child end end
    end
    return o
end

local player = object("Player", "LocalPlayer")
local mouse = {Icon = "native://default"}
function player:GetMouse() return mouse end
local players = {LocalPlayer = player}
local run = {RenderStepped = signal(), Heartbeat = signal()}
local fakeGame = {GetService = function(_, name) return name == "Players" and players or run end}

local module = dofile("crosshair.lua")
local api = module(fakeGame)
local character = object("Model", "Character")
local humanoid = character:Add(object("Humanoid")); humanoid.Health = 100
local gun = character:Add(object("Tool", "Gun"))
player.Character = character

api.set("rbxassetid://123")
run.RenderStepped:Fire()
assert(mouse.Icon == "rbxassetid://123", "equipped Gun overrides the icon")
gun.Parent = nil
local knife = character:Add(object("Tool", "Knife"))
run.RenderStepped:Fire()
assert(mouse.Icon == "native://default", "knife does not override the icon")
knife.Parent = nil; gun.Parent = character
run.RenderStepped:Fire()
mouse.Icon = "native://changed-before-disable"
api.set("")
assert(mouse.Icon == "native://changed-before-disable", "immediate native changes survive disable")
api.set("rbxassetid://123"); run.RenderStepped:Fire()
mouse.Icon = "native://changed"
run.RenderStepped:Fire()
assert(mouse.Icon == "rbxassetid://123", "native icon changes are replaced while active")
api.set("")
assert(mouse.Icon == "native://changed", "latest native icon is restored when disabled")

api.set("rbxassetid://456"); run.RenderStepped:Fire()
humanoid.Health = 0; run.RenderStepped:Fire()
assert(mouse.Icon == "native://changed", "death restores the native icon")
humanoid.Health = 100; gun.Parent = character; run.RenderStepped:Fire()
assert(mouse.Icon == "rbxassetid://456", "respawn/live state can activate again")
api.destroy()
assert(mouse.Icon == "native://changed", "destroy restores the native icon")
assert(not run.RenderStepped.listeners[1].Connected, "destroy disconnects fallback rendering")
assert(not pcall(function() api.set("rbxassetid://789") end), "set after destroy is rejected")
api.destroy()
print("MM2 crosshair equip, native icon preservation, death, disable, and cleanup passed.")
