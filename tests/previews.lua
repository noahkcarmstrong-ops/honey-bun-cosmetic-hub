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
meshPart.LocalTransparencyModifier=1
local tool = Instance.new('Tool', character); local held = Instance.new('Part', tool); held.Size = Vector3.new(1, 1, 1); held.CFrame = cframe(0, 0, 0)
local gameplay = Instance.new('Model', character); local gameplayPart = Instance.new('Part', gameplay); gameplayPart.Size = Vector3.new(1, 1, 1); gameplayPart.CFrame = cframe(0, 0, 0)
Instance.new('Script', character)
local module = dofile('previews.lua'); local api = module(player); local data = api.capture()
assert(#data.records == 3, 'captures body and hat appearance, excludes tools and gameplay models')
assert(data.records[1].cframe and data.records[1].size, 'captures bounded part geometry')
local meshRecord
for _, record in ipairs(data.records) do if record.class == 'MeshPart' then meshRecord = record end end
assert(meshRecord and meshRecord.meshId == 'rbxassetid://mesh', 'preserves MeshPart mesh ID')
assert(meshRecord.transparency == 1, 'captures local transparency used to hide live avatar parts')
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

local shirt=Instance.new('Shirt',character);shirt.Name='HoneyBunShirt';shirt.ShirtTemplate='saved-shirt-template'
local pants=Instance.new('Pants',character);pants.Name='HoneyBunPants';pants.PantsTemplate='saved-pants-template'
local h=Instance.new('Humanoid',character);h.RigType='R15'
Enum.HumanoidRigType={R15='R15',R6='R6'}
function meshPart:Clone()
    local copy=Instance.new('MeshPart')
    for k,v in pairs(self.props)do if k~='Parent'then copy[k]=v end end
    Instance.new('Script',copy)
    return copy
end
local dressed=api.capture()
shirt.ShirtTemplate='different-current-shirt';pants.PantsTemplate='different-current-pants'
local dressedViewport=Instance.new('ViewportFrame')
assert(api.show(dressedViewport,dressed),'Saved dressed snapshot renders')
local dressedAvatar=dressedViewport:FindFirstChild('CharacterPreview'):FindFirstChild('Avatar')
assert(dressedAvatar:FindFirstChild('Head').ClassName=='MeshPart','R15 preview preserves native body MeshParts for classic clothing')
assert(dressedAvatar:FindFirstChildOfClass('Shirt').ShirtTemplate=='saved-shirt-template' and dressedAvatar:FindFirstChildOfClass('Pants').PantsTemplate=='saved-pants-template','Preview uses saved clothes rather than current clothes')
assert(dressedAvatar:FindFirstChildOfClass('Humanoid').RigType=='R15','Preview uses the saved avatar rig type')
for _,item in ipairs(dressedAvatar:GetDescendants())do assert(item.ClassName~='Script','Native body clones cannot bring scripts into the preview')end
assert(meshPart.Parent==character and shirt.ShirtTemplate=='different-current-shirt','Preview never changes the live avatar')
print('Saved clothes and native R15 body preview checks passed.')

-- Saved outfits still reconstruct native body meshes after rejoining with another avatar.
local meshLoads=0
local generatedSources={}
game={GetService=function(_,name)
    assert(name=='AssetService')
    return{CreateMeshPartAsync=function(_,content)
        meshLoads=meshLoads+1
        local part=Instance.new('MeshPart');part.MeshId=content
        generatedSources[#generatedSources+1]=part
        return part
    end}
end}
function methods:Clone()
    local copy=Instance.new(self.ClassName)
    for k,v in pairs(self.props)do if k~='Parent'then copy[k]=v end end
    for _,child in ipairs(self:GetChildren())do child:Clone().Parent=copy end
    return copy
end
local rejoined=module({Character=nil})
local rejoinViewport=Instance.new('ViewportFrame')
assert(rejoined.show(rejoinViewport,dressed),'Saved clothes preview loads without the original live character')
local rejoinAvatar=rejoinViewport:FindFirstChild('CharacterPreview'):FindFirstChild('Avatar')
assert(rejoinAvatar:FindFirstChild('Head').ClassName=='MeshPart' and rejoinAvatar:FindFirstChildOfClass('Shirt').ShirtTemplate=='saved-shirt-template','Old saved preview reconstructs a native clothed body')
assert(rejoined.show(Instance.new('ViewportFrame'),dressed) and meshLoads==1,'Repeated saved outfit cards share the loaded native mesh')
rejoined.destroy();assert(generatedSources[1].destroyed,'Preview cache releases loaded native meshes when the hub closes')
assert(not rejoined.show(rejoinViewport,dressed),'Closed preview module cannot repopulate cards')
local parent=Instance.new('Frame');local cancelledViewport=Instance.new('ViewportFrame',parent)
local cancelledAPI=module({Character=nil})
local lateSource
local created=game.GetService
game.GetService=function()return{CreateMeshPartAsync=function()
    cancelledViewport.Parent=nil
    lateSource=Instance.new('MeshPart')
    return lateSource
end}end
assert(not cancelledAPI.show(cancelledViewport,dressed),'Removed card cancels a yielding preview before parenting loaded parts')
cancelledAPI.destroy();assert(lateSource.destroyed,'Cancelled native mesh is cleaned with the preview cache')
game.GetService=created
-- R6 package mesh IDs are numeric properties, including modern IDs above 1e9.
Enum.BodyPart={Torso="Torso"}
local bodyMesh=Instance.new('CharacterMesh',character)
bodyMesh.BodyPart='Torso';bodyMesh.MeshId=12345678901
bodyMesh.BaseTextureId=23456789012;bodyMesh.OverlayTextureId=34567890123
hat.Transparency=0.2;hat.LocalTransparencyModifier=0.5
local faithful=api.capture();local capturedBody,capturedHandle
for _,record in ipairs(faithful.records)do
 if record.class=='CharacterMesh'then capturedBody=record end
 if record.name=='Handle'then capturedHandle=record end
end
assert(capturedBody and capturedBody.meshId=='12345678901','R6 body mesh is captured without losing numeric asset IDs')
assert(capturedHandle and math.abs(capturedHandle.transparency-0.6)<0.0001,'local and base transparency compose like Roblox rendering')
local faithfulView=Instance.new('ViewportFrame');assert(api.show(faithfulView,faithful))
local renderedBody
for _,object in ipairs(faithfulView:GetDescendants())do if object.ClassName=='CharacterMesh'then renderedBody=object end end
assert(renderedBody and renderedBody.MeshId==12345678901 and renderedBody.BaseTextureId==23456789012 and renderedBody.OverlayTextureId==34567890123,'R6 body mesh and both texture IDs survive rendering')
for i=1,110 do local extra=Instance.new('Part',character);extra.Name='Extra'..i;extra.Size=Vector3.new(1,1,1);extra.CFrame=cframe(0,0,0)end
local crowded=api.capture();local savedShirt,savedPants=false,false
for _,record in ipairs(crowded.records)do savedShirt=savedShirt or record.class=='Shirt';savedPants=savedPants or record.class=='Pants'end
assert(#crowded.records<=96 and savedShirt and savedPants,'Clothing records survive the preview size limit on crowded avatars')
api.destroy()
print('Rejoined native mesh loading, shared cache, card cancellation, cleanup and clothing priority checks passed.')
