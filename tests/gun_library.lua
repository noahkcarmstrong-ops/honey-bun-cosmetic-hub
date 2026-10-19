-- Covers portable gun capture, bounded persistence, deduplication and selection.
local function typed(kind,t)t._kind=kind;return t end
typeof=function(v)return type(v)=="table"and v._kind or type(v)end
Vector3={new=function(x,y,z)return typed("Vector3",{X=x,Y=y,Z=z})end}
Color3={new=function(r,g,b)return typed("Color3",{R=r,G=g,B=b})end}
Enum={Material=setmetatable({},{__index=function(_,name)return setmetatable(typed("EnumItem",{label="Enum.Material."..name}),{__tostring=function(v)return v.label end})end})}
local material=Enum.Material.Metal
local function content(uri)return typed("Content",{Uri=uri})end
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
local knifeEntry=library.capture(part,"BIearyEyed",nil,"Knife")

-- SurfaceAppearance maps must survive capture and portable persistence.
local surface=object("SurfaceAppearance",{ColorMap="rbxassetid://color",MetalnessMap="rbxassetid://metal",
    NormalMap="rbxassetid://normal",RoughnessMap="rbxassetid://rough"})
local surfacePart=object("MeshPart",{Name="SurfaceGun",MeshId="rbxassetid://surface-mesh",TextureID="",
    Size=Vector3.new(2,2,2),MeshSize=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Material=material},surface)
local surfaceEntry=library.capture(surfacePart,"BIearyEyed")
assert(surfaceEntry.definition.SurfaceAppearance.ColorMap=="rbxassetid://color","SurfaceAppearance maps are captured")
local latestSaved=screen:GetAttribute("HoneyBunCosmeticGuns")

-- Modern Content properties are normalized to their URI, with legacy values
-- retained when the modern property is present but empty.
local modernSurface=object("SurfaceAppearance",{ColorMapContent=content("rbxassetid://modern-color"),ColorMap="rbxassetid://legacy-color",
    MetalnessMapContent=content(""),MetalnessMap="rbxassetid://legacy-metal"})
local modernPart=object("MeshPart",{Name="ModernGun",MeshId="rbxassetid://modern-mesh",TextureContent=content("rbxassetid://modern-texture"),TextureID="rbxassetid://legacy-texture",
    Size=Vector3.new(2,2,2),MeshSize=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Material=material},modernSurface)
local modernEntry=library.capture(modernPart,"BIearyEyed")
assert(modernEntry.definition.TextureId=="rbxassetid://modern-texture","MeshPart TextureContent is captured as its URI")
assert(modernEntry.definition.SurfaceAppearance.ColorMap=="rbxassetid://modern-color","SurfaceAppearance ColorMapContent is captured as its URI")
assert(modernEntry.definition.SurfaceAppearance.MetalnessMap=="rbxassetid://legacy-metal","empty modern content falls back to the legacy map")

-- A matching display can fill only missing texture maps, and the borrowed
-- values must survive persistence. Explicit item identity prevents cross-skin borrowing.
local fallbackPrimary=object("MeshPart",{Name="FallbackPrimary",MeshId="rbxassetid://fallback-mesh",TextureID="",
    Size=Vector3.new(2,2,2),MeshSize=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Material=material},object("SurfaceAppearance",{ColorMap="",NormalMap="rbxassetid://primary-normal"}))
local fallbackAlternate=object("MeshPart",{Name="FallbackAlternate",MeshId="rbxassetid://fallback-mesh",TextureID="rbxassetid://borrowed-texture",
    Size=Vector3.new(2,2,2),MeshSize=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Material=material},object("SurfaceAppearance",{ColorMap="rbxassetid://borrowed-color",NormalMap="rbxassetid://alternate-normal",RoughnessMap="rbxassetid://borrowed-rough"}))
fallbackPrimary.GetAttribute=function(_,name)return name=="ItemID" and "same-item" or nil end
fallbackAlternate.GetAttribute=function(_,name)return name=="ItemID" and "same-item" or nil end
local fallbackEntry=library.capture(fallbackPrimary,"BIearyEyed",nil,"Gun",nil,fallbackAlternate)
assert(fallbackEntry.definition.TextureId=="rbxassetid://borrowed-texture" and fallbackEntry.definition.SurfaceAppearance.ColorMap=="rbxassetid://borrowed-color",
    "matching mesh fallback fills missing texture and color maps")
assert(fallbackEntry.definition.SurfaceAppearance.NormalMap=="rbxassetid://primary-normal" and fallbackEntry.definition.SurfaceAppearance.RoughnessMap=="rbxassetid://borrowed-rough",
    "primary surface maps win while missing maps are borrowed")
local mismatched=object("MeshPart",{Name="MismatchedFallback",MeshId="rbxassetid://different-mesh",TextureID="rbxassetid://primary-texture",
    Size=Vector3.new(2,2,2),MeshSize=Vector3.new(1,1,1),Color=Color3.new(1,1,1),Material=material},object("SurfaceAppearance",{ColorMap="rbxassetid://primary-color"}))
local mismatchEntry=library.capture(mismatched,"BIearyEyed",nil,"Gun",nil,fallbackAlternate)
assert(mismatchEntry.definition.TextureId=="rbxassetid://primary-texture" and mismatchEntry.definition.SurfaceAppearance.ColorMap=="rbxassetid://primary-color",
    "different mesh fallback leaves primary textures unchanged")
local fallbackReload=create(game,gui(screen:GetAttribute("HoneyBunCosmeticGuns")))
local fallbackDefinition
for _,savedEntry in ipairs(fallbackReload.list("Gun")) do if savedEntry.id==fallbackEntry.id then fallbackDefinition=savedEntry.definition end end
assert(fallbackDefinition and fallbackDefinition.TextureId=="rbxassetid://borrowed-texture" and fallbackDefinition.SurfaceAppearance.RoughnessMap=="rbxassetid://borrowed-rough",
    "borrowed texture maps persist after reload")

local restoredGui=gui(saved)
local restored=create(game,restoredGui)
local restoredEntries=restored.list()
assert(#restoredEntries==1 and restoredEntries[1].id==entry.id,"portable gun restores after rejoin without the source")
local definition=restoredEntries[1].definition
assert(typeof(definition.Scale)=="Vector3"and definition.Scale.X==2 and typeof(definition.Color)=="Color3","vectors and colors reconstruct as Roblox values")
assert(tostring(definition.Material)=="Enum.Material.Metal"and definition.Size.Y==4,"material and source size reconstruct")
assert(restored.getSelected()==entry.id,"selected gun restores after rejoin")
restored.select(nil)
local afterClearGui=gui(latestSaved)
local afterClear=create(game,afterClearGui)
afterClear.select(nil)
assert(afterClear.getSelected()==nil,"cleared selection persists")
local removed=afterClear.remove(entry.id)
assert(removed and removed.id==entry.id,"remove returns and deletes the saved gun")
assert(afterClear.getSelected()==nil,"remove clears selected gun")
afterClear.select(knifeEntry.id,"Knife")
local removedKnife=afterClear.remove(knifeEntry.id)
assert(removedKnife and removedKnife.id==knifeEntry.id and afterClear.getSelected("Knife")==nil,"remove clears selected knife")
local afterRemove=create(game,gui(afterClearGui:GetAttribute("HoneyBunCosmeticGuns")))
local removedStillPresent=false
for _,savedEntry in ipairs(afterRemove.list("Gun")) do if savedEntry.id==entry.id then removedStillPresent=true end end
assert(#afterRemove.list("Knife")==0 and not removedStillPresent,"removed weapons stay deleted after reload")
local missingOk=pcall(function() afterRemove.remove("missing-saved-id") end)
assert(not missingOk,"remove rejects an unknown saved weapon")
local surfaceReload=create(game,gui(screen:GetAttribute("HoneyBunCosmeticGuns")))
local surfaceDefinition
for _,savedEntry in ipairs(surfaceReload.list("Gun")) do if savedEntry.id==surfaceEntry.id then surfaceDefinition=savedEntry.definition end end
assert(surfaceDefinition and surfaceDefinition.SurfaceAppearance.NormalMap=="rbxassetid://normal","SurfaceAppearance maps persist after reload")

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
local replicated=node("Folder","ReplicatedStorage")
local mm2Game={GetService=function(_,name)return({HttpService=http,Players=players,Workspace=workspace,ReplicatedStorage=replicated})[name]end}
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
    function f:Inverse()return frame(-self.X,-self.Y,-self.Z)end
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

-- A rifle's own Tool grip, icon and sounds differ from the native pistol.
local sourceTool=node('Tool','Gun',sourcePlayer.Character)
sourceTool.Grip=frame(4,0,0);sourceTool.TextureId='rbxassetid://scope-icon'
sourceMesh.Name='Handle';sourceMesh.Parent=sourceTool
local sourceShot=node('Sound','Shoot',sourceMesh);sourceShot.SoundId='rbxassetid://scope-shot';sourceShot.Volume=0.7;sourceShot.PlaybackSpeed=1.2
realGun.Grip=frame(1,0,0);realGun.TextureId='rbxassetid://pistol-icon'
local realShot=node('Sound','Shoot',realHandle);realShot.SoundId='rbxassetid://pistol-shot';realShot.Volume=0.4;realShot.PlaybackSpeed=1
local presentationLibrary=create(mm2Game,gui())
local presentationApi=dofile('mm2.lua')(mm2Game,function()return{}end,presentationLibrary)
presentationApi.collectPlayerGun('BIearyEyed')
assert(realGun.TextureId=='rbxassetid://scope-icon','Toolbar icon follows captured Tool even while in Backpack')
assert(realShot.SoundId=='rbxassetid://scope-shot' and realShot.Volume==0.7,'Real weapon triggers use captured original shot sound')
realGun.Parent=localPlayer.Character
local gripOverlay=realHandle:FindFirstChild('HoneyBunCosmeticVisual').Value
assert(gripOverlay.CFrame.X==107,'Rifle grip corrects the native pistol handle without changing real Tool grip')
assert(realGun.Grip.X==1 and sourceTool.Grip.X==4,'Source and gameplay Tool grips remain unchanged')
local sourceHand=node('MeshPart','RightHand',sourcePlayer.Character);sourceHand.CFrame=frame(20,0,0)
local localHand=node('MeshPart','RightHand',localPlayer.Character);localHand.CFrame=frame(200,0,0)
presentationApi.collectPlayerGun('BIearyEyed')
gripOverlay=realHandle:FindFirstChild('HoneyBunCosmeticVisual').Value
assert(gripOverlay.CFrame.X==193,'Exact captured hand position takes priority over generic Tool grip correction')
presentationApi.restore()
assert(realGun.TextureId=='rbxassetid://pistol-icon' and realShot.SoundId=='rbxassetid://pistol-shot' and realShot.Volume==0.4,'Restore returns toolbar icon and original weapon audio')
assert(sourceShot.SoundId=='rbxassetid://scope-shot','Source player sound is untouched')
presentationApi.destroy()

-- Saved models use real catalog labels without changing their equip IDs.
local itemModule=node('ModuleScript','Item',node('Folder','Sync',node('Folder','Database',replicated)))
itemModule.Data={Gingerscope={ItemName='Gingerscope',ItemType='Gun',Image='rbxassetid://999',Rarity='Ancient',Event='Christmas',Year=2023,MeshId='rbxassetid://321',TextureId='rbxassetid://654'},
    UnownedGun={ItemName='Not Captured',ItemType='Gun',Image='rbxassetid://777',Rarity='Common',Season=1}}
local beforeId=presentationLibrary.list('Gun')[1].id
local catalogApi=dofile('mm2.lua')(mm2Game,function(module)return module.Data or {}end,presentationLibrary)
local savedCards=catalogApi.savedInventory('Gun')
assert(#savedCards==#presentationLibrary.list('Gun') and savedCards[1].id==beforeId,'Saved inventory contains only captured models with stable equip IDs')
assert(savedCards[1].name=='Gingerscope' and savedCards[1].image=='rbxassetid://999' and savedCards[1].rarity=='Ancient' and savedCards[1].category=='holiday','Saved card uses the real Gingerscope name, icon, rarity and Holiday tab')
local metadataGui=gui();local metadataLibrary=create(mm2Game,metadataGui)
local metadataEntry=metadataLibrary.capture(sourceMesh,'Test')
metadataLibrary.setCatalog(metadataEntry.id,presentationLibrary.list('Gun')[1].catalog)
local persistedMetadata=create(mm2Game,gui(metadataGui:GetAttribute('HoneyBunCosmeticGuns')))
assert(persistedMetadata.list()[1].catalog.Name=='Gingerscope','Saved catalog labels persist without the original player')
catalogApi.equip(beforeId,'Gun')
local identified=catalogApi.identifySavedWeapon('Not Captured','Gun')
assert(identified:find('Not Captured',1,true),'Identifying a saved weapon reports the matched catalog name')
local identifiedEntry=presentationLibrary.list('Gun')[1]
assert(identifiedEntry.id==beforeId and identifiedEntry.catalog.Name=='Not Captured' and identifiedEntry.catalog.Image=='rbxassetid://777'
    and identifiedEntry.catalog.Rarity=='Common' and identifiedEntry.catalog.Category=='season1','Identification updates metadata without changing the saved ID')
local invalidIdentify=pcall(function()catalogApi.identifySavedWeapon('missing-name','Gun')end)
assert(not invalidIdentify and presentationLibrary.list('Gun')[1].catalog.Name=='Not Captured','Invalid identification preserves saved metadata')
catalogApi.destroy()

local bad=gui(http:JSONEncode({version=1,entries={{id="bad",name="bad",definition={PortableGun=true}}}}))
assert(#create(game,bad).list()==0,"malformed saved definitions are rejected")
print("Gun mesh capture, SpecialMesh precedence, normalized MeshPart scale, deduplication, source preservation, selection, and rejoin persistence passed.")
