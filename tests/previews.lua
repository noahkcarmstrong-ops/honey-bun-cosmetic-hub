-- Focused contract checks for the bounded local preview serializer.
local objects = {}
local function children(parent)
    local result = {}
    for _, object in ipairs(objects) do if object.Parent == parent and not object.destroyed then table.insert(result, object) end end
    return result
end
local methods = {}
local meta = {__index = function(object, key) return methods[key] or object.props[key] end,
    __newindex = function(object, key, value) object.props[key] = value end}
Instance = {new = function(class, parent)
    local object = setmetatable({props = {ClassName = class, Name = class, Parent = parent}}, meta)
    table.insert(objects, object); return object
end}
function methods:IsA(class) return self.ClassName == class end
function methods:GetChildren() return children(self) end
function methods:FindFirstChild(name) for _, object in ipairs(children(self)) do if object.Name == name then return object end end end
function methods:FindFirstChildOfClass(class) for _,object in ipairs(children(self)) do if object.ClassName==class then return object end end end
function methods:GetDescendants()
    local result = {}
    local function walk(parent) for _, child in ipairs(children(parent)) do table.insert(result, child); walk(child) end end
    walk(self); return result
end
function methods:Destroy() self.destroyed = true; self.Parent = nil end
Vector3 = {new = function(x, y, z) return {X=x, Y=y, Z=z} end}
Color3 = {new = function(r, g, b) return {R=r, G=g, B=b} end}
local function cframe(x, y, z)
    local position = type(x) == 'table' and x or {X=x, Y=y, Z=z}
    return {Position = position, GetComponents = function() return position.X, position.Y, position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1 end,
        ToObjectSpace = function(_, value) return value end}
end
CFrame = {new = cframe, lookAt = function(from, target) return {Position=from, Target=target} end}
Enum = {Material = {}, PartType = {}, MeshType = {FileMesh='FileMesh'}, HumanoidDisplayDistanceType = {None='None'}, NormalId = {Front = 'Front'}}
local player = {Character = Instance.new('Model')}
local character = player.Character
local root = Instance.new('Part', character); root.Name = 'HumanoidRootPart'; root.Size = Vector3.new(2, 2, 1); root.CFrame = cframe(0, 0, 0); root.Color = Color3.new(1, 1, 1)
local hat = Instance.new('Part', character); hat.Name = 'Handle'; hat.Size = Vector3.new(1, 1, 1); hat.CFrame = cframe(0, 2, 0); hat.Color = Color3.new(1, 0, 0)
local mesh = Instance.new('SpecialMesh', hat); mesh.MeshId = 'rbxassetid://1'; mesh.TextureId = 'rbxassetid://2'
local meshPart = Instance.new('MeshPart', character); meshPart.Name = 'Head'; meshPart.Size = Vector3.new(2, 2, 2); meshPart.CFrame = cframe(0, 4, 0); meshPart.MeshId = 'rbxassetid://mesh'; meshPart.TextureID = 'rbxassetid://texture'
meshPart.MeshSize=Vector3.new(4,4,4)
local tool = Instance.new('Tool', character); local held = Instance.new('Part', tool); held.Size = Vector3.new(1, 1, 1); held.CFrame = cframe(0, 0, 0)
local gameplay = Instance.new('Model', character); local gameplayPart = Instance.new('Part', gameplay); gameplayPart.Size = Vector3.new(1, 1, 1); gameplayPart.CFrame = cframe(0, 0, 0)
Instance.new('Script', character)
local module = dofile('previews.lua'); local api = module(player); local data = api.capture()
assert(#data.records == 3, 'captures body and hat appearance, excludes tools and gameplay models')
assert(data.records[1].cframe and data.records[1].size, 'captures bounded part geometry')
local meshRecord
for _, record in ipairs(data.records) do if record.class == 'MeshPart' then meshRecord = record end end
assert(meshRecord and meshRecord.meshId == 'rbxassetid://mesh', 'preserves MeshPart mesh ID')
local viewport = Instance.new('ViewportFrame')
assert(api.show(viewport, data), 'renders valid data')
assert(viewport.CurrentCamera and viewport:FindFirstChild('CharacterPreview'), 'creates static world and camera')
assert(viewport.CurrentCamera.CFrame.Target and viewport.CurrentCamera.CFrame.Target.Y > 1, 'camera targets avatar bounds center')
local avatar = viewport:FindFirstChild('CharacterPreview'):FindFirstChild('Avatar')
local foundMesh = false
for _, object in ipairs(avatar:GetDescendants()) do if object.ClassName == 'SpecialMesh' and object.MeshId == 'rbxassetid://mesh' then foundMesh = true;assert(object.Scale.X==0.5,'Mesh scale uses part size divided by original mesh bounds') end end
assert(foundMesh, 'renders MeshPart through FileMesh fallback')
assert(not api.show(viewport, {records = {{class = 'Script'}}}), 'rejects untrusted classes')
assert(not api.show(viewport, {version=1,records = {{class = 'Part', size = {-1, 2, 2}, cframe = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}}}}), 'rejects negative geometry')
local missingCharacter = module({Character = nil})
local ok, message = pcall(missingCharacter.capture)
assert(not ok and message:find('Wait for your avatar to finish spawning', 1, true), 'requires a usable spawned avatar')
print('Character preview capture, tool filtering, rendering, and validation passed.')
