-- Weapon presentation data persists as bounded plain data, without source instances.
local function typed(kind,values)values._kind=kind;return values end
typeof=function(value)return type(value)=="table"and value._kind or type(value)end
Vector3={new=function(x,y,z)return typed("Vector3",{X=x,Y=y,Z=z})end}
Color3={new=function(r,g,b)return typed("Color3",{R=r,G=g,B=b})end}
CFrame={new=function(...)
    local values={...};local result=typed("CFrame",{})
    function result:GetComponents()return table.unpack(values)end
    return result
end}
local function copy(value)
    if type(value)~="table"then return value end
    local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
end
local documents,nextDocument={},0
local http={JSONEncode=function(_,value)nextDocument=nextDocument+1;local token="json"..nextDocument;documents[token]=copy(value);return token end,
    JSONDecode=function(_,token)return copy(assert(documents[token]))end}
local game={GetService=function(_,name)assert(name=="HttpService");return http end}
local attributes={}
local screen={GetAttribute=function(_,key)return attributes[key]end,SetAttribute=function(_,key,value)attributes[key]=value end}
local function source()
    return {ClassName="MeshPart",MeshId="rbxassetid://77",TextureID="rbxassetid://88",Size=Vector3.new(2,4,6),MeshSize=Vector3.new(1,2,3),
        Color=Color3.new(.2,.3,.4),IsA=function(self,class)return class=="BasePart"or class==self.ClassName end,FindFirstChildWhichIsA=function()return nil end}
end
local function frame(x,y,z)return CFrame.new(x,y,z,1,0,0,0,1,0,0,0,1)end
local create=dofile("gun_library.lua")
local library=create(game,screen)
local metadata={Grip=frame(1,2,3),ToolIcon="rbxassetid://901",Sounds={{Name="Fire",Path={"Handle","Fire"},Properties={SoundId="rbxassetid://902",Volume=.7,PlaybackSpeed=1.2,RollOffMinDistance=2,RollOffMaxDistance=80,EmitterSize=4,Looped=false}}}}
local entry=library.capture(source(),"Player",nil,nil,metadata)
assert(entry.definition.Presentation and entry.definition.Presentation.ToolIcon==metadata.ToolIcon,"presentation exposes icon")
assert(entry.definition.Presentation.Sounds[1].Properties.Volume==.7,"sound properties are retained")
assert(typeof(entry.definition.Presentation.Grip)=="CFrame","grip is reconstructed as CFrame")
local saved=documents[screen:GetAttribute("HoneyBunCosmeticGuns")].entries[1].definition.Presentation
assert(saved.Grip.t=="CFrame"and #saved.Grip.v==12 and saved.Sounds[1].Path[2]=="Fire","only portable presentation values are saved")
metadata.Sounds[1].Properties.Volume=9
local restored=create(game,screen).list()[1]
assert(restored.id==entry.id and restored.definition.Presentation.Sounds[1].Properties.Volume==.7,"presentation restores independently of source tables")
local changed=copy(restored.definition.Presentation);changed.ToolIcon="different"
assert(library.capture(source(),"Player",nil,nil,changed).id~=entry.id,"presentation participates in identity")

local legacyAttributes={}
local legacyScreen={GetAttribute=function(_,key)return legacyAttributes[key]end,SetAttribute=function(_,key,value)legacyAttributes[key]=value end}
local legacyLibrary=create(game,legacyScreen);local legacy=legacyLibrary.capture(source(),"Player")
local raw=legacyScreen:GetAttribute("HoneyBunCosmeticGuns")
assert(documents[raw].entries[1].definition.Presentation==nil,"legacy entry keeps its original shape")
local old=create(game,{GetAttribute=function()return raw end}).list()[1]
assert(old.id==legacy.id and old.definition.Presentation==nil,"legacy entry restores with stable identity")

local plain=library.capture(source(),"Player")
local bad={ToolIcon="x",Sounds={{Name="Fire",Path={"Handle"},Properties={Volume=11}}}}
assert(library.capture(source(),"Player",nil,nil,bad).id==plain.id,"invalid metadata is omitted without breaking capture")
local badPath={Sounds={{Name="Fire",Path={string.rep("x",101)}}}}
assert(library.capture(source(),"Player",nil,nil,badPath).id==plain.id,"oversized path is rejected safely")
local badGrip={Grip="not a CFrame"}
assert(library.capture(source(),"Player",nil,nil,badGrip).id==plain.id,"invalid grip is rejected safely")
assert(library.capture(source(),"Player",nil,nil,{ToolIcon="",Sounds={}}).id==plain.id,"empty optional presentation keeps legacy identity")
print("Weapon presentation roundtrip, bounds, identity, source independence, malformed metadata, and legacy restore passed.")
