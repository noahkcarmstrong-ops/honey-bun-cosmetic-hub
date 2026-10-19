-- Saved knives have independent persistence and use the same local-only mount preview as guns.
local function typed(kind,values)values._kind=kind;return values end
typeof=function(value)return type(value)=="table"and value._kind or type(value)end
Vector3={new=function(x,y,z)return typed("Vector3",{X=x,Y=y,Z=z})end}
Color3={new=function(r,g,b)return typed("Color3",{R=r,G=g,B=b})end}
local function frame(x,y,z,...)
    local r={...};if #r==0 then r={1,0,0,0,1,0,0,0,1} end
    local f=typed("CFrame",{X=x or 0,Y=y or 0,Z=z or 0,r=r})
    function f:GetComponents()return self.X,self.Y,self.Z,table.unpack(self.r) end
    function f:ToObjectSpace(other)
        local r=self.r
        local inverse=frame(0,0,0,r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9])
        return inverse*frame(other.X-self.X,other.Y-self.Y,other.Z-self.Z,table.unpack(other.r))
    end
    return setmetatable(f,{__mul=function(a,b)
        local r,q=a.r,b.r;local product={}
        for i=0,2 do for j=1,3 do product[i*3+j]=r[i*3+1]*q[j]+r[i*3+2]*q[j+3]+r[i*3+3]*q[j+6] end end
        return frame(a.X+r[1]*b.X+r[2]*b.Y+r[3]*b.Z,a.Y+r[4]*b.X+r[5]*b.Y+r[6]*b.Z,a.Z+r[7]*b.X+r[8]*b.Y+r[9]*b.Z,table.unpack(product))
    end})
end
CFrame={new=frame}
Enum={Material=setmetatable({},{__index=function(_,name)return typed("EnumItem",{label="Enum.Material."..name})end})}
Enum.MeshType={FileMesh=typed("EnumItem",{label="Enum.MeshType.FileMesh"})}
local function copy(value)if type(value)~="table"then return value end;local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out end
local documents,nextDocument={},0
local http={JSONEncode=function(_,value)nextDocument=nextDocument+1;local key="json"..nextDocument;documents[key]=copy(value);return key end,JSONDecode=function(_,key)return copy(assert(documents[key]))end}
local function gui(raw)local attrs={HoneyBunCosmeticGuns=raw};return {GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end}end
local function signal()
    local listeners={}
    return {Connect=function(_,fn)local connection={active=true};function connection:Disconnect()self.active=false end;listeners[#listeners+1]={connection,fn};return connection end,
        Fire=function(_,...)for _,entry in ipairs(listeners)do if entry[1].active then entry[2](...)end end end}
end
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
local localTorso=node("Part","UpperTorso",localPlayer.Character);localTorso.CFrame=frame(100,0,0);localTorso.Size=Vector3.new(4,4,2)
local localKnife=node("MeshPart","Knife",localPlayer.Character);localKnife.CFrame=frame(100,0,0);localKnife.Color=Color3.new(1,1,1);localKnife.Material=Enum.Material.Metal;localKnife.LocalTransparencyModifier=0
local misleadingAttachment=node("Attachment","BodyBackAttachment",localTorso);misleadingAttachment.CFrame=frame(0,0,-10)
local localRef=node("ObjectValue","DisplayRefKnife",localPlayer.Character);localRef.Value=localKnife
local owner=node("Player","KnifeOwner");owner.Character=node("Model","OwnerCharacter")
local torso=node("Part","UpperTorso",owner.Character);torso.CFrame=frame(10,0,0)
local source=node("MeshPart","Knife",owner.Character);source.CFrame=frame(13,2,0);source.MeshId="rbxassetid://knife";source.TextureID="rbxassetid://texture"
source.Size=Vector3.new(0.2,4,2);source.MeshSize=Vector3.new(1,2,3);source.Color=Color3.new(0.2,0.3,0.4);source.Material=Enum.Material.Metal
local surface=node('SurfaceAppearance','SurfaceAppearance',source);surface.ColorMap='rbxassetid://original-color-map'
local ref=node("ObjectValue","DisplayRefKnife",owner.Character);ref.Value=source
local players={LocalPlayer=localPlayer,GetPlayers=function()return{localPlayer,owner}end}
local heartbeat=signal()
local replicated=node("Folder","ReplicatedStorage");local game={GetService=function(_,name)return({HttpService=http,Players=players,Workspace=workspace,ReplicatedStorage=replicated,RunService={Heartbeat=heartbeat}})[name]end}
Instance={new=function(class,parent)return node(class,nil,parent)end}
local screen=gui();local library=libraryFactory(game,screen)
local mm2=dofile("mm2.lua")(game,function()return{}end,library)
assert(mm2.collectPlayerKnife("KnifeOwner"):find("Saved to your knife library",1,true),"knife collection reports a saved knife")
local knives=mm2.savedWeapons("Knife");local guns=mm2.savedWeapons("Gun")
assert(#knives==1 and #guns==0 and knives[1].name=="Knife from KnifeOwner"and knives[1].kind=="Knife","knife entries stay separate from saved guns")
local knifeId=knives[1].id
assert(library.getSelected("Knife")==knifeId and library.getSelected()==nil,"knife selection is independent from the legacy gun selection")
local overlay
for _,item in ipairs(workspace:GetChildren())do if item.Name=="HoneyBunSavedKnife"then overlay=item end end
assert(overlay and overlay.CFrame.X==100 and overlay.CFrame.Y==0 and math.abs(overlay.CFrame.Z-1.13)<0.0001,"flat knife rests against the back using its thickness, not its blade width")
local backRotation=overlay.CFrame.r
assert(math.abs(backRotation[7])>0.99 and math.abs(backRotation[8])<0.0001 and math.abs(backRotation[9])<0.0001,"only the thin mesh axis projects out of the back")
assert(backRotation[5]>0.85,"long blade axis lies upright along the back instead of pointing outward")
assert(overlay:FindFirstChildOfClass('SpecialMesh').TextureId=='rbxassetid://original-color-map','Copied weapon displays the source surface color map instead of an empty or stale texture')
local weld=overlay:FindFirstChildOfClass("WeldConstraint")
assert(weld and weld.Part0==localTorso and weld.Part1==overlay,"knife overlay welds to the matching local body part")
local visualMarker=localKnife:FindFirstChild("HoneyBunCosmeticVisual")
assert(visualMarker and visualMarker.Value==overlay,"the original knife points effect previews at the copied knife visual")
assert(localKnife.LocalTransparencyModifier==1,"knife preview hides only the local original knife")
-- Captured from MM2's native LowerTorso.KnifeBelt joint report.
local localLowerTorso=node("Part","LowerTorso",localPlayer.Character)
localLowerTorso.CFrame=frame(100,-2,0);localLowerTorso.Size=Vector3.new(2,1,1)
local knifeBelt=node("Attachment","KnifeBelt",localLowerTorso)
knifeBelt.CFrame=frame(-0.73373872,-0.576318264,0.212840006,
    -0.998995066,0.0298198294,0.033461079,
    0.0136284996,-0.509110212,0.860593498,
    0.0426981226,0.860184669,0.508192182)
local sideResult=mm2.setKnifeSide(true)
assert(sideResult==true and mm2.getKnifeSide()==true,"knife side layout can be enabled")
local sideOverlay
for _,item in ipairs(workspace:GetChildren())do if item.Name=="HoneyBunSavedKnife"then sideOverlay=item end end
local expectedSide=localLowerTorso.CFrame*knifeBelt.CFrame
for i,value in ipairs({sideOverlay.CFrame:GetComponents()}) do
    assert(math.abs(value-({expectedSide:GetComponents()})[i])<0.000001,"side knife follows every component of the native belt attachment")
end
assert(sideOverlay:FindFirstChildOfClass("WeldConstraint").Part0==localLowerTorso,"side knife welds to the native lower torso")
assert(overlay.destroyed,"changing layout removes the previous knife overlay")
mm2.setKnifeSide(false)
assert(mm2.getKnifeSide()==false,"knife layout can return to the default back position")
local persisted=screen:GetAttribute("HoneyBunCosmeticGuns")
local restoredLibrary=libraryFactory(game,gui(persisted))
assert(#restoredLibrary.list("Knife")==1 and restoredLibrary.list("Knife")[1].id==knifeId and restoredLibrary.getSelected("Knife")==knifeId,"knife definition and selection survive reload")
mm2.restore()
assert(localKnife.LocalTransparencyModifier==0 and overlay.destroyed and visualMarker.destroyed and library.getSelected("Knife")==nil,"explicit restore clears knife selection and removes its overlay marker")
mm2.equip(knifeId,"Knife")
assert(mm2.removeSavedWeapon(knifeId):find('Deleted saved knife',1,true),'Saved entry can be deleted through the backend')
assert(#library.list('Knife')==0 and library.getSelected('Knife')==nil and mm2.getEquipped().Knife==nil,'Deletion clears the library and active selection')
assert(localKnife.LocalTransparencyModifier==0 and not localKnife:FindFirstChild('HoneyBunCosmeticVisual'),'Deleting equipped copy restores the original knife')
assert(#libraryFactory(game,gui(screen:GetAttribute('HoneyBunCosmeticGuns'))).list('Knife')==0,'Deletion survives reload')
mm2.collectPlayerKnife('KnifeOwner')
knifeId=mm2.savedWeapons('Knife')[1].id
mm2.destroy()
assert(library.getSelected("Knife")==knifeId,"destroying the preview preserves the selected knife for the next load")
local afterDestroy=libraryFactory(game,gui(screen:GetAttribute("HoneyBunCosmeticGuns")))
assert(afterDestroy.getSelected("Knife")==knifeId and #afterDestroy.list("Knife")==1,"destroyed preview selection remains persisted")
print("Saved knife capture, separate persistence, body-relative overlay, local hiding, and restore passed.")

-- A Chroma detail is a separate visible mesh, not a script to execute.
Color3.fromHSV=function(h,s,v)return typed("Color3",{R=h,G=s,B=v})end
local chroma=node("MeshPart","Chroma",source)
chroma.CFrame=source.CFrame*frame(0,0.25,0)
chroma.Size=Vector3.new(0.25,3,1);chroma.MeshSize=Vector3.new(1,1,1)
chroma.MeshId="rbxassetid://chroma-detail";chroma.TextureID="rbxassetid://chroma-mask"
chroma.Color=Color3.new(0.2,0.8,0.4);chroma.Material=Enum.Material.Metal;chroma.Transparency=0.2
local chromaScript=node("Script","ChromaScript",chroma)
local chromaMM2=dofile("mm2.lua")(game,function()return{}end,library)
chromaMM2.collectPlayerKnife("KnifeOwner")
local chromaOverlay
for _,item in ipairs(workspace:GetChildren())do if item.Name=="HoneyBunSavedKnife"then chromaOverlay=item end end
local copiedDetail=chromaOverlay and chromaOverlay:FindFirstChild("SavedWeaponDetail_1")
assert(copiedDetail and copiedDetail:FindFirstChildOfClass("SpecialMesh").MeshId==chroma.MeshId,"Chroma copies include their separate visible mesh layer")
assert(copiedDetail:FindFirstChildOfClass("SpecialMesh").TextureId==chroma.TextureID and copiedDetail.Transparency==0.2,"Chroma detail mask and transparency survive copying")
assert(copiedDetail:FindFirstChildOfClass("WeldConstraint").Part0==chromaOverlay,"Chroma layer stays attached to the saved weapon")
assert(not copiedDetail:FindFirstChild("ChromaScript"),"source scripts are never copied or executed")
local originalBaseColor=chromaOverlay.Color
local firstTint=copiedDetail.Color
heartbeat:Fire(0.5)
assert(copiedDetail.Color~=firstTint and chromaOverlay.Color==originalBaseColor,"only Chroma layers cycle colors while the base stays unchanged")
local lastTint=copiedDetail.Color
chromaMM2.restore();heartbeat:Fire(0.5)
assert(copiedDetail.Color==lastTint and chromaOverlay.destroyed,"restoring a Chroma disconnects its animation")
assert(chroma.Parent==source and chromaScript.Parent==chroma,"copying preserves the donor's original Chroma instances")
print("Chroma layer meshes, textures, local animation, attachment, and cleanup passed.")

-- Guns use the same persisted multipart renderer and root Chroma animation.
local donorGunRef=node("ObjectValue","DisplayRefGun",owner.Character);donorGunRef.Value=source
local localGun=node("MeshPart","Gun",localPlayer.Character)
localGun.CFrame=frame(100,0,0);localGun.Color=Color3.new(1,1,1);localGun.Material=Enum.Material.Metal;localGun.LocalTransparencyModifier=0
local localGunRef=node("ObjectValue","DisplayRefGun",localPlayer.Character);localGunRef.Value=localGun
node("Script","ChromaScript",source)
chromaMM2.collectPlayerGun("KnifeOwner")
local gunOverlay
for _,item in ipairs(workspace:GetChildren())do if item.Name=="HoneyBunSavedGun"then gunOverlay=item end end
assert(gunOverlay and gunOverlay:FindFirstChild("SavedWeaponDetail_1"),"Chroma guns copy their complete mesh assembly")
assert(gunOverlay.CFrame.X-source.Size.X/2>=localLowerTorso.CFrame.X+localLowerTorso.Size.X/2+0.029,"wide copied gun clears the local hip instead of embedding in it")
assert(gunOverlay.CFrame.Y==localGun.CFrame.Y and gunOverlay.CFrame.Z==localGun.CFrame.Z,"hip clearance preserves native holster height and depth")

local gunTint=gunOverlay.Color;heartbeat:Fire(0.5)
assert(gunOverlay.Color~=gunTint,"a root Chroma gun cycles its tint")
local persistedChroma=libraryFactory(game,gui(screen:GetAttribute("HoneyBunCosmeticGuns")))
local savedChroma=persistedChroma.list("Gun")[1]
assert(savedChroma and savedChroma.definition.Chroma and #savedChroma.definition.Parts==1,"root and layer Chroma flags survive reloading the saved gun")
local savedGunId=library.getSelected("Gun")
source.Color=Color3.new(0.9,0.1,0.5);chroma.Color=Color3.new(0.1,0.3,0.9)
chromaMM2.collectPlayerGun("KnifeOwner")
assert(library.getSelected("Gun")==savedGunId and #library.list("Gun")==1,"different Chroma color phases do not create duplicate gun saves")
chromaMM2.restore()
localGun.CFrame=frame(99.5,0,0)
chromaMM2.collectPlayerGun("KnifeOwner")
local leftGun
for _,item in ipairs(workspace:GetChildren())do if item.Name=="HoneyBunSavedGun"then leftGun=item end end
assert(leftGun.CFrame.X+source.Size.X/2<=localLowerTorso.CFrame.X-localLowerTorso.Size.X/2-0.029,"hip clearance also pushes left-side holsters outward instead of through the body")
chromaMM2.destroy()
print("Chroma gun root animation and multipart persistence passed.")

local nativeAttachment=node("Attachment","NativeKnifeAttachment",localKnife)
nativeAttachment.CFrame=frame(0.25,-0.5,1)
local bodyAttachment=node("Attachment","NativeHipAttachment",localTorso)
bodyAttachment.CFrame=frame(-1,-0.5,0)
local nativeJoint=node("RigidConstraint","NativeKnifeJoint",localKnife)
nativeJoint.Attachment0=nativeAttachment;nativeJoint.Attachment1=bodyAttachment
local mountReport=chromaMM2.report()
assert(mountReport:find("Build: native knife mount diagnostics V13",1,true),"mount diagnostic report identifies its current build")
assert(mountReport:find("Native knife attachment owner=LocalPlayer",1,true) and mountReport:find("local=0.25,-0.5,1",1,true),"report records native attachment transforms without guessing")
assert(mountReport:find("Attachment1=NativeHipAttachment",1,true),"report identifies the native body attachment used by the knife joint")
print("Native knife attachment and joint diagnostics passed.")
