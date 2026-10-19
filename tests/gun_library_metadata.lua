-- Mount transforms persist as bounded numeric data, without retaining source parts.
local function typed(kind,values)values._kind=kind;return values end
typeof=function(value)return type(value)=="table"and value._kind or type(value)end
Vector3={new=function(x,y,z)return typed("Vector3",{X=x,Y=y,Z=z})end}
Color3={new=function(r,g,b)return typed("Color3",{R=r,G=g,B=b})end}
CFrame={new=function(...)
    local values={...};local result=typed("CFrame",{})
    function result:GetComponents()return table.unpack(values)end
    return result
end}
Enum={Material=setmetatable({},{__index=function(_,name)return setmetatable(typed("EnumItem",{label="Enum.Material."..name}),{__tostring=function(v)return v.label end})end})}
local function copy(value)
    if type(value)~="table"then return value end
    local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
end
local documents,nextDocument={},0
local http={
    JSONEncode=function(_,value)nextDocument=nextDocument+1;local token="json"..nextDocument;documents[token]=copy(value);return token end,
    JSONDecode=function(_,token)return copy(assert(documents[token]))end,
}
local game={GetService=function(_,name)assert(name=="HttpService");return http end}
local function gui(raw)
    local attributes={HoneyBunCosmeticGuns=raw}
    return {GetAttribute=function(_,key)return attributes[key]end,SetAttribute=function(_,key,value)attributes[key]=value end}
end
local function source()
    return {ClassName="MeshPart",MeshId="rbxassetid://77",TextureID="rbxassetid://88",Size=Vector3.new(2,4,6),
        MeshSize=Vector3.new(1,2,3),Color=Color3.new(0.2,0.3,0.4),IsA=function(self,class)return class=="BasePart"or class==self.ClassName end,
        FindFirstChildWhichIsA=function()return nil end}
end
local function offset(x,y,z)
    return CFrame.new(x,y,z,1,0,0,0,1,0,0,0,1)
end
local create=dofile("gun_library.lua")
local screen=gui();local library=create(game,screen)
local positions={Holster={Part="UpperTorso",Offset=offset(0.25,-0.5,1)},Held={Part="RightHand",Offset=offset(1,2,3)}}
local entry=library.capture(source(),"BIearyEyed",positions)
assert(entry.definition.Mounts.Holster.Part=="UpperTorso"and entry.definition.Mounts.Held.Part=="RightHand","named mount parts are captured")
assert(typeof(entry.definition.Mounts.Holster.Offset)=="CFrame","definition exposes a reconstructed Roblox CFrame")
local components={entry.definition.Mounts.Holster.Offset:GetComponents()}
assert(#components==12 and components[1]==0.25 and components[2]==-0.5 and components[4]==1 and components[12]==1,"all twelve transform components are retained")
assert(library.capture(source(),"BIearyEyed",positions).id==entry.id and #library.list()==1,"identical mount data deduplicates")

local changed=copy(positions);changed.Held.Offset=offset(1.000001,2,3)
local corrected=library.capture(source(),"BIearyEyed",changed)
assert(corrected.id~=entry.id and #library.list()==2,"mount changes produce a distinct saved gun")
local persisted=screen:GetAttribute("HoneyBunCosmeticGuns")
local stored=documents[persisted].entries[1].definition.Mounts
assert(stored.Holster.Part=="UpperTorso"and stored.Holster.Offset.t=="CFrame"and #stored.Holster.Offset.v==12,"persistence stores only part names and twelve finite numbers")

-- Mount metadata is plain data and restores after the source instance is gone.
local sourcePart=source();sourcePart=nil
local restored=create(game,gui(persisted))
local restoredEntry=restored.list()[1]
local restoredOffset=restoredEntry.definition.Mounts.Held.Offset
local restoredComponents={restoredOffset:GetComponents()}
assert(restoredEntry.id==entry.id and restoredEntry.definition.Mounts.Held.Part=="RightHand","mount labels restore after rejoin")
assert(typeof(restoredOffset)=="CFrame"and restoredComponents[1]==1 and restoredComponents[3]==3 and restoredComponents[12]==1,"mount offsets reconstruct as CFrames")

-- Bad optional metadata is skipped as a whole and does not break mesh capture.
local base=library.capture(source(),"BIearyEyed")
local badUnknown=library.capture(source(),"BIearyEyed",{Held={Part="RightHand",Offset=offset(0,0,0),Script="never copy"}})
assert(badUnknown.id==base.id and badUnknown.definition.Mounts==nil,"unknown mount fields discard optional metadata")
local badFrame=offset(0/0,0,0)
local badNumbers=library.capture(source(),"BIearyEyed",{Holster={Part="UpperTorso",Offset=badFrame}})
assert(badNumbers.id==base.id and badNumbers.definition.Mounts==nil,"non-finite transform components are rejected safely")
local badPart=library.capture(source(),"BIearyEyed",{Held={Part=string.rep("x",65),Offset=offset(0,0,0)}})
assert(badPart.id==base.id and badPart.definition.Mounts==nil,"oversized body-part names are rejected safely")

-- A legacy record without Mounts keeps its original id and remains readable.
local legacyScreen=gui();local legacyLibrary=create(game,legacyScreen)
local legacy=legacyLibrary.capture(source(),"BIearyEyed")
local legacyRaw=legacyScreen:GetAttribute("HoneyBunCosmeticGuns")
assert(documents[legacyRaw].entries[1].definition.Mounts==nil,"legacy-format entry contains no optional mount field")
local legacyRejoin=create(game,gui(legacyRaw))
assert(#legacyRejoin.list()==1 and legacyRejoin.list()[1].id==legacy.id and legacyRejoin.list()[1].definition.Mounts==nil,"pre-mount saved guns still restore with stable ids")
print("Gun mount metadata, CFrame validation and roundtrip, deduplication, optional-data rejection, source independence, and legacy restores passed.")
