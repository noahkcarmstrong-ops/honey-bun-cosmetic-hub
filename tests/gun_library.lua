-- Covers portable gun capture, bounded persistence, deduplication and selection.
local function typed(kind,t)t._kind=kind;return t end
typeof=function(v)return type(v)=="table"and v._kind or type(v)end
Vector3={new=function(x,y,z)return typed("Vector3",{X=x,Y=y,Z=z})end}
Color3={new=function(r,g,b)return typed("Color3",{R=r,G=g,B=b})end}
Enum={Material=setmetatable({},{__index=function(_,name)return setmetatable(typed("EnumItem",{label="Enum.Material."..name}),{__tostring=function(v)return v.label end})end})}
local material=Enum.Material.Metal
local function copy(v)
    if type(v)~="table"then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local docs,nextDoc={},0
local http={
    JSONEncode=function(_,value)nextDoc=nextDoc+1;local token="json"..nextDoc;docs[token]=copy(value);return token end,
    JSONDecode=function(_,token)return copy(assert(docs[token]))end,
}
local game={GetService=function(_,name)assert(name=="HttpService");return http end}
local function gui(raw)
    local attrs={HoneyBunCosmeticGuns=raw}
    return {GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end,attrs=attrs}
end
local function object(class,props,child)
    props=props or {};props.ClassName=class
    function props:IsA(name)return name=="BasePart"and(class=="Part"or class=="MeshPart")or name==class end
    function props:FindFirstChildWhichIsA(name)if child and child.ClassName==name then return child end end
    function props:FindFirstChild(name)if child and child.Name==name then return child end end
    return props
end
local create=dofile("gun_library.lua")
local screen=gui();local library=create(game,screen)
local size=Vector3.new(2,4,6)
local staleSpecial=object("SpecialMesh",{MeshId="stale",TextureId="stale",Scale=Vector3.new(99,99,99),
    Offset=Vector3.new(0,0,0),VertexColor=Vector3.new(1,1,1)})
local source=object("MeshPart",{Name="EquippedGun",MeshId="rbxassetid://123",TextureID="rbxassetid://456",
    Size=size,MeshSize=Vector3.new(1,2,3),Color=Color3.new(0.2,0.3,0.4),Material=material},staleSpecial)
local entry=library.capture(source,"BIearyEyed")
assert(entry.kind=="Gun"and entry.name=="Gun from BIearyEyed","capture labels the source player")
assert(entry.definition.PortableGun and entry.definition.MeshId=="rbxassetid://123"and entry.definition.TextureId=="rbxassetid://456","MeshPart mesh properties are captured")
assert(entry.definition.Scale.X==2 and entry.definition.Scale.Y==2 and entry.definition.Scale.Z==2,"MeshPart size is normalized by mesh size")
assert(entry.definition.Size==size and source.Parent==nil,"capture preserves original part size and does not mutate source")
assert(library.capture(source,"BIearyEyed")==entry and #library.list()==1,"identical gun meshes are deduplicated")
library.select(entry.id)
assert(library.getSelected()==entry.id,"selection is stored in the library")
local saved=screen:GetAttribute("HoneyBunCosmeticGuns");assert(saved,"capture writes the persistence attribute")

-- A SpecialMesh takes precedence over the containing part's mesh-like fields.
local special=object("SpecialMesh",{MeshId="rbxassetid://789",TextureId="rbxassetid://987",Scale=Vector3.new(1,2,3),
    Offset=Vector3.new(0,0.5,0),VertexColor=Vector3.new(1,0.5,0.25)})
local part=object("Part",{Name="GunHandle",Size=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Material=material},special)
local specialEntry=library.capture(part,"BIearyEyed")
assert(specialEntry.definition.MeshId=="rbxassetid://789"and specialEntry.definition.Scale.Y==2 and specialEntry.definition.Offset.Y==0.5,"SpecialMesh properties are captured")

local restoredGui=gui(saved)
local restored=create(game,restoredGui)
local restoredEntries=restored.list()
assert(#restoredEntries==1 and restoredEntries[1].id==entry.id,"portable gun restores after rejoin without the source")
local definition=restoredEntries[1].definition
assert(typeof(definition.Scale)=="Vector3"and definition.Scale.X==2 and typeof(definition.Color)=="Color3","vectors and colors reconstruct as Roblox values")
assert(tostring(definition.Material)=="Enum.Material.Metal"and definition.Size.Y==4,"material and source size reconstruct")
assert(restored.getSelected()==entry.id,"selected gun restores after rejoin")
restored.select(nil)
local afterClear=create(game,gui(restoredGui:GetAttribute("HoneyBunCosmeticGuns")))
assert(afterClear.getSelected()==nil,"cleared selection persists")

-- Exercise the real MM2 capture, overlay, restore, and rejoin auto-equip path.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end;self.listeners[#self.listeners+1]=c;return c end
    function s:Fire(...)for _,c in ipairs(self.listeners)do if c.Connected then c.fn(...)end end end
    return s
end
local methods={}
local meta={__index=function(t,k)return methods[k]or t.props[k]end,__newindex=function(t,k,v)
    if k=="Parent"then
        local old=t.props.Parent;if old==v then return end
        if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i);break end end end
        t.props.Parent=v
        if v then v.children[#v.children+1]=t;v.ChildAdded:Fire(t);local a=v;while a do a.DescendantAdded:Fire(t);a=a.Parent end end
        t.AncestryChanged:Fire(t,v)
    else local old=t.props[k];t.props[k]=v;if old~=v and t.props.propertySignals and t.props.propertySignals[k]then t.props.propertySignals[k]:Fire()end end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),DescendantAdded=signal(),CharacterAdded=signal(),Destroying=signal(),AncestryChanged=signal()},children={}},meta)
    n.Parent=parent;return n
end
function methods:IsA(class)return class==self.ClassName or (class=="BasePart"and(self.ClassName=="Part"or self.ClassName=="MeshPart"))end
function methods:GetChildren()local out={};for _,v in ipairs(self.children)do out[#out+1]=v end;return out end
function methods:GetDescendants()local out={};local function walk(p)for _,v in ipairs(p.children)do out[#out+1]=v;walk(v)end end;walk(self);return out end
function methods:FindFirstChild(name)for _,v in ipairs(self.children)do if v.Name==name then return v end end end
function methods:FindFirstChildWhichIsA(class)for _,v in ipairs(self.children)do if v:IsA(class)then return v end end end
function methods:FindFirstChildOfClass(class)for _,v in ipairs(self.children)do if v.ClassName==class then return v end end end
function methods:GetPropertyChangedSignal(key)self.propertySignals=self.propertySignals or {};self.propertySignals[key]=self.propertySignals[key]or signal();return self.propertySignals[key]end
function methods:Destroy()self.Destroying:Fire();for _,v in ipairs(self:GetChildren())do v:Destroy()end;self.Parent=nil;self.destroyed=true end
local localPlayer=node("Player","LocalPlayer");localPlayer.Character=node("Model","LocalCharacter");localPlayer.Backpack=node("Backpack","Backpack")
local native=node("MeshPart","NativeGun");native.Size=Vector3.new(1,2,3);native.CFrame={native=true};native.Color=Color3.new(1,1,1);native.Material=material;native.LocalTransparencyModifier=0.25
local localRef=node("ObjectValue","DisplayRefGun",localPlayer.Character);localRef.Value=native
local sourcePlayer=node("Player","BIearyEyed");sourcePlayer.Character=node("Model","SourceCharacter")
local sourceMesh=node("MeshPart","Gun",sourcePlayer.Character);sourceMesh.MeshId="rbxassetid://321";sourceMesh.TextureID="rbxassetid://654"
sourceMesh.Size=Vector3.new(2,4,6);sourceMesh.MeshSize=Vector3.new(1,2,3);sourceMesh.Color=Color3.new(0.1,0.2,0.3);sourceMesh.Material=material
local sourceRef=node("ObjectValue","DisplayRefGun",sourcePlayer.Character);sourceRef.Value=sourceMesh
local players={LocalPlayer=localPlayer,GetPlayers=function()return{localPlayer,sourcePlayer}end}
local workspace=node("Folder","Workspace")
local mm2Game={GetService=function(_,name)return({HttpService=http,Players=players,Workspace=workspace,ReplicatedStorage=node("Folder","ReplicatedStorage")})[name]end}
Instance={new=function(class)return node(class)end}
Enum.MeshType={FileMesh=typed("EnumItem",{label="Enum.MeshType.FileMesh"})}
local renderGui=gui();local renderLibrary=create(mm2Game,renderGui)
local mm2=dofile("mm2.lua")(mm2Game,function()return{}end,renderLibrary)
assert(mm2.collectPlayerGun("BIearyEyed"):find("Saved to your gun library",1,true),"MM2 captures and equips the loaded player gun")
local selectedId=renderLibrary.getSelected();assert(selectedId and native.LocalTransparencyModifier==1,"equipping saved gun selects it and hides the native mesh")
local overlay
for _,child in ipairs(workspace:GetChildren())do if child.Name=="HoneyBunSavedGun"then overlay=child end end
assert(overlay and overlay.Size.X==2,"MM2 creates a separate overlay with saved part size")
local overlayMesh=overlay:FindFirstChildWhichIsA("SpecialMesh")
assert(overlayMesh and overlayMesh.MeshId=="rbxassetid://321"and overlayMesh.Scale.X==2 and overlayMesh.Scale.Y==2 and overlayMesh.Scale.Z==2,"MM2 renders the saved MeshPart mesh at normalized scale")
assert(native.Size.X==1 and native.MeshId==nil,"the native weapon geometry and size remain untouched")
mm2.restore();assert(native.LocalTransparencyModifier==0.25 and overlay.destroyed and renderLibrary.getSelected("Gun")==nil,"restore reveals the native gun, removes its overlay, and clears its saved selection")
mm2.equip(selectedId,"Gun")
mm2.destroy()

-- A fresh library and MM2 instance use only persisted data after the source leaves.
players.GetPlayers=function()return{localPlayer}end
local rejoinGui=gui(renderGui:GetAttribute("HoneyBunCosmeticGuns"))
local rejoinedLibrary=create(mm2Game,rejoinGui)
assert(rejoinedLibrary.getSelected()==selectedId,"selected entry survives the rejoin")
local rejoinedMm2=dofile("mm2.lua")(mm2Game,function()return{}end,rejoinedLibrary)
local rejoinedOverlay
for _,child in ipairs(workspace:GetChildren())do if child.Name=="HoneyBunSavedGun"then rejoinedOverlay=child end end
assert(rejoinedOverlay and native.LocalTransparencyModifier==1,"saved selection auto-equips after rejoin without the source player")
local rejoinedMesh=rejoinedOverlay:FindFirstChildWhichIsA("SpecialMesh")
assert(rejoinedMesh and rejoinedMesh.MeshId=="rbxassetid://321"and rejoinedMesh.Scale.X==2,"rejoined overlay restores the saved mesh and normalized scale")
rejoinedMm2.restore();assert(native.LocalTransparencyModifier==0.25 and rejoinedOverlay.destroyed,"rejoined MM2 restore cleans up the overlay")
rejoinedMm2.destroy()

-- The captured body-relative mount must replace the old gun's unrelated pivot.
local function frame(x,y,z)
    local f={X=x or 0,Y=y or 0,Z=z or 0,_kind='CFrame'}
    function f:ToObjectSpace(other)return frame(other.X-self.X,other.Y-self.Y,other.Z-self.Z)end
    function f:GetComponents()return self.X,self.Y,self.Z,1,0,0,0,1,0,0,0,1 end
    return setmetatable(f,{__mul=function(a,b)return frame(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end})
end
CFrame={new=frame}
local sourceTorso=node('MeshPart','UpperTorso',sourcePlayer.Character);sourceTorso.CFrame=frame(10,0,0)
local localTorso=node('MeshPart','UpperTorso',localPlayer.Character);localTorso.CFrame=frame(100,0,0)
sourceMesh.CFrame=frame(13,2,0);native.CFrame=frame(100,0,0)
local originalChild=node('MeshPart','OriginalGunDetail',native);originalChild.LocalTransparencyModifier=0
players.GetPlayers=function()return{localPlayer,sourcePlayer}end
local mountLibrary=create(mm2Game,gui())
local mountApi=dofile('mm2.lua')(mm2Game,function()return{}end,mountLibrary)
mountApi.collectPlayerGun('BIearyEyed')
local positioned
for _,o in ipairs(workspace:GetChildren())do if o.Name=='HoneyBunSavedGun'then positioned=o end end
assert(positioned.CFrame.X==103 and positioned.CFrame.Y==2,'The copied gun keeps the source torso mount offset instead of the old gun pivot')
assert(originalChild.LocalTransparencyModifier==1,'Every native gun detail is hidden under the replacement')
native.LocalTransparencyModifier=0
assert(native.LocalTransparencyModifier==1,'A camera visibility reset must not reveal the native gun beneath the skin')
local realGun=node('Tool','Gun',localPlayer.Backpack)
local realHandle=node('Part','Handle',realGun);realHandle.CFrame=frame(110,0,0);realHandle.LocalTransparencyModifier=0
realGun.Parent=localPlayer.Character
assert(realHandle.LocalTransparencyModifier==1,'Drawing the real gun hides its original appearance')
local heldOverlay
for _,o in ipairs(workspace:GetChildren())do if o.Name=='HoneyBunSavedGun' and o~=positioned then heldOverlay=o end end
assert(heldOverlay and heldOverlay.CFrame.X==110,'Drawing the real gun attaches the copied appearance to its handle')
realGun.Parent=localPlayer.Backpack
assert(heldOverlay.destroyed and realHandle.LocalTransparencyModifier==0,'Putting the gun away removes its held overlay and restores its handle')
mountApi.restore()
assert(originalChild.LocalTransparencyModifier==0 and native.LocalTransparencyModifier==0.25,'Removing the skin restores native root and detail visibility')
mountApi.destroy()

local bad=gui(http:JSONEncode({version=1,entries={{id="bad",name="bad",definition={PortableGun=true}}}}))
assert(#create(game,bad).list()==0,"malformed saved definitions are rejected")
print("Gun mesh capture, SpecialMesh precedence, normalized MeshPart scale, deduplication, source preservation, selection, and rejoin persistence passed.")
