-- Saved knives have independent persistence and use the same local-only mount preview as guns.
local function typed(kind,values)values._kind=kind;return values end
typeof=function(value)return type(value)=="table"and value._kind or type(value)end
Vector3={new=function(x,y,z)return typed("Vector3",{X=x,Y=y,Z=z})end}
Color3={new=function(r,g,b)return typed("Color3",{R=r,G=g,B=b})end}
local function frame(x,y,z)
    local f=typed("CFrame",{X=x or 0,Y=y or 0,Z=z or 0})
    function f:GetComponents()return self.X,self.Y,self.Z,1,0,0,0,1,0,0,0,1 end
    function f:ToObjectSpace(other)return frame(other.X-self.X,other.Y-self.Y,other.Z-self.Z)end
    return setmetatable(f,{__mul=function(a,b)return frame(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end})
end
CFrame={new=function(...)local v={...};return frame(v[1],v[2],v[3])end}
Enum={Material=setmetatable({},{__index=function(_,name)return typed("EnumItem",{label="Enum.Material."..name})end})}
Enum.MeshType={FileMesh=typed("EnumItem",{label="Enum.MeshType.FileMesh"})}
local function copy(value)if type(value)~="table"then return value end;local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out end
local documents,nextDocument={},0
local http={JSONEncode=function(_,value)nextDocument=nextDocument+1;local key="json"..nextDocument;documents[key]=copy(value);return key end,JSONDecode=function(_,key)return copy(assert(documents[key]))end}
local function gui(raw)local attrs={HoneyBunCosmeticGuns=raw};return {GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end}end
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local methods={}
local meta={__index=function(t,k)return methods[k]or t.props[k]end,__newindex=function(t,k,v)
    if k=="Parent"then local old=t.props.Parent;if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i);break end end end;t.props.Parent=v;if v then v.children[#v.children+1]=t end
    else t.props[k]=v end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),DescendantAdded=signal(),AncestryChanged=signal()},children={}},meta);n.Parent=parent;return n
end
function methods:IsA(class)return class==self.ClassName or class=="BasePart"and(self.ClassName=="Part"or self.ClassName=="MeshPart")end
function methods:GetChildren()local out={};for _,v in ipairs(self.children)do out[#out+1]=v end;return out end
function methods:GetDescendants()local out={};local function walk(p)for _,v in ipairs(p.children)do out[#out+1]=v;walk(v)end end;walk(self);return out end
function methods:FindFirstChild(name)for _,v in ipairs(self.children)do if v.Name==name then return v end end end
function methods:FindFirstChildWhichIsA(class)for _,v in ipairs(self.children)do if v:IsA(class)then return v end end end
function methods:FindFirstChildOfClass(class)return self:FindFirstChildWhichIsA(class)end
function methods:Destroy()self.destroyed=true;self.Parent=nil end
local libraryFactory=dofile("gun_library.lua")
local workspace=node("Folder","Workspace")
local localPlayer=node("Player","LocalPlayer");localPlayer.Character=node("Model","LocalCharacter");localPlayer.Backpack=node("Backpack","Backpack")
local localTorso=node("Part","UpperTorso",localPlayer.Character);localTorso.CFrame=frame(100,0,0)
local localKnife=node("MeshPart","Knife",localPlayer.Character);localKnife.CFrame=frame(100,0,0);localKnife.Color=Color3.new(1,1,1);localKnife.Material=Enum.Material.Metal;localKnife.LocalTransparencyModifier=0
local localRef=node("ObjectValue","DisplayRefKnife",localPlayer.Character);localRef.Value=localKnife
local owner=node("Player","KnifeOwner");owner.Character=node("Model","OwnerCharacter")
local torso=node("Part","UpperTorso",owner.Character);torso.CFrame=frame(10,0,0)
local source=node("MeshPart","Knife",owner.Character);source.CFrame=frame(13,2,0);source.MeshId="rbxassetid://knife";source.TextureID="rbxassetid://texture"
source.Size=Vector3.new(2,4,6);source.MeshSize=Vector3.new(1,2,3);source.Color=Color3.new(0.2,0.3,0.4);source.Material=Enum.Material.Metal
local ref=node("ObjectValue","DisplayRefKnife",owner.Character);ref.Value=source
local players={LocalPlayer=localPlayer,GetPlayers=function()return{localPlayer,owner}end}
local replicated=node("Folder","ReplicatedStorage");local game={GetService=function(_,name)return({HttpService=http,Players=players,Workspace=workspace,ReplicatedStorage=replicated})[name]end}
Instance={new=function(class)return node(class)end}
local screen=gui();local library=libraryFactory(game,screen)
local mm2=dofile("mm2.lua")(game,function()return{}end,library)
assert(mm2.collectPlayerKnife("KnifeOwner"):find("Saved to your knife library",1,true),"knife collection reports a saved knife")
local knives=mm2.savedWeapons("Knife");local guns=mm2.savedWeapons("Gun")
assert(#knives==1 and #guns==0 and knives[1].name=="Knife from KnifeOwner"and knives[1].kind=="Knife","knife entries stay separate from saved guns")
local knifeId=knives[1].id
assert(library.getSelected("Knife")==knifeId and library.getSelected()==nil,"knife selection is independent from the legacy gun selection")
local overlay
for _,item in ipairs(workspace:GetChildren())do if item.Name=="HoneyBunSavedKnife"then overlay=item end end
assert(overlay and overlay.CFrame.X==103 and overlay.CFrame.Y==2,"knife preview uses captured body-relative mount, weld anchor, and overlay")
local weld=overlay:FindFirstChildOfClass("WeldConstraint")
assert(weld and weld.Part0==localTorso and weld.Part1==overlay,"knife overlay welds to the matching local body part")
local visualMarker=localKnife:FindFirstChild("HoneyBunCosmeticVisual")
assert(visualMarker and visualMarker.Value==overlay,"the original knife points effect previews at the copied knife visual")
assert(localKnife.LocalTransparencyModifier==1,"knife preview hides only the local original knife")
local persisted=screen:GetAttribute("HoneyBunCosmeticGuns")
local restoredLibrary=libraryFactory(game,gui(persisted))
assert(#restoredLibrary.list("Knife")==1 and restoredLibrary.list("Knife")[1].id==knifeId and restoredLibrary.getSelected("Knife")==knifeId,"knife definition and selection survive reload")
mm2.restore()
assert(localKnife.LocalTransparencyModifier==0 and overlay.destroyed and visualMarker.destroyed and library.getSelected("Knife")==nil,"explicit restore clears knife selection and removes its overlay marker")
mm2.equip(knifeId,"Knife")
mm2.destroy()
assert(library.getSelected("Knife")==knifeId,"destroying the preview preserves the selected knife for the next load")
local afterDestroy=libraryFactory(game,gui(screen:GetAttribute("HoneyBunCosmeticGuns")))
assert(afterDestroy.getSelected("Knife")==knifeId and #afterDestroy.list("Knife")==1,"destroyed preview selection remains persisted")
print("Saved knife capture, separate persistence, body-relative overlay, local hiding, and restore passed.")
