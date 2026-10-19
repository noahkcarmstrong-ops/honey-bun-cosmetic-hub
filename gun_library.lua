-- Stores static, portable gun meshes without copying their source instances.
return function(game,gui)
    local Http=game:GetService("HttpService")
    local KEY="HoneyBunCosmeticGuns"
    local MAX_BYTES,MAX_ENTRIES,MAX_STRING=1400000,128,2048
    local function finite(n)return type(n)=="number"and n==n and math.abs(n)<1e9 end
    local function read(o,key)local ok,v=pcall(function()return o[key]end);return ok and v or nil end
    local function vector(kind,v)
        if typeof(v)~=kind then return nil end
        local out={}
        for _,key in ipairs(kind=="Vector3" and {"X","Y","Z"} or {"R","G","B"})do
            local n=read(v,key);if not finite(n)then return nil end;out[#out+1]=n
        end
        return out
    end
    local function encode(v,kind)
        local t=typeof(v)
        if t=="string"then if #v>MAX_STRING then return nil end;return v end
        if t=="number"then return finite(v)and v or nil end
        if t=="Vector3"or t=="Color3"then local values=vector(t,v);return values and {t=t,v=values}or nil end
        if t=="EnumItem"then
            local group,item=tostring(v):match("^Enum%.([%w_]+)%.([%w_]+)$")
            if group and (kind=="Material"and group=="Material")then return {t="EnumItem",v={group,item}}end
        end
    end
    local function decode(v,kind)
        if type(v)=="string"then return #v<=MAX_STRING and v or nil end
        if type(v)=="number"then return finite(v)and v or nil end
        if type(v)~="table"or type(v.v)~="table"then return nil end
        local a=v.v
        if v.t=="Vector3"and #a==3 and finite(a[1])and finite(a[2])and finite(a[3])then return Vector3.new(a[1],a[2],a[3])end
        if v.t=="Color3"and #a==3 and finite(a[1])and finite(a[2])and finite(a[3])then return Color3.new(a[1],a[2],a[3])end
        if v.t=="EnumItem"and kind=="Material"and a[1]=="Material"and type(a[2])=="string"then
            local ok,value=pcall(function()return Enum.Material[a[2]]end);if ok then return value end
        end
    end
    local function validDefinition(d)
        return type(d)=="table"and d.PortableGun==true and type(d.MeshId)=="string"and #d.MeshId>0 and #d.MeshId<=MAX_STRING
            and type(d.TextureId)=="string"and #d.TextureId<=MAX_STRING
            and typeof(d.Scale)=="Vector3"and typeof(d.Offset)=="Vector3"and typeof(d.VertexColor)=="Vector3"
            and typeof(d.Color)=="Color3"and (d.Material==nil or typeof(d.Material)=="EnumItem")and typeof(d.Size)=="Vector3"
            and vector("Vector3",d.Scale)~=nil and vector("Vector3",d.Offset)~=nil and vector("Vector3",d.VertexColor)~=nil
            and vector("Color3",d.Color)~=nil and vector("Vector3",d.Size)~=nil
            and d.Size.X>0 and d.Size.Y>0 and d.Size.Z>0
    end
    local function pack(d)
        return {PortableGun=true,MeshId=d.MeshId,TextureId=d.TextureId,Scale=encode(d.Scale),Offset=encode(d.Offset),
            VertexColor=encode(d.VertexColor),Color=encode(d.Color),Material=encode(d.Material,"Material"),Size=encode(d.Size)}
    end
    local function unpackDefinition(d)
        if type(d)~="table"or d.PortableGun~=true then return nil end
        local result={PortableGun=true,MeshId=decode(d.MeshId),TextureId=decode(d.TextureId),Scale=decode(d.Scale),Offset=decode(d.Offset),
            VertexColor=decode(d.VertexColor),Color=decode(d.Color),Material=decode(d.Material,"Material"),Size=decode(d.Size)}
        return validDefinition(result)and result or nil
    end
    local function canonical(v)
        if type(v)=="number"then return "number:"..string.format("%.5f",v)end
        if type(v)~="table"then return type(v)..":"..tostring(v)end
        local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
        local out={};for _,k in ipairs(keys)do out[#out+1]=k.."="..canonical(v[k])end;return "{"..table.concat(out,"|").."}"
    end
    local function identity(d)
        local s=canonical(pack(d));local a,b=1,7
        for i=1,#s do a=(a*31+s:byte(i))%2147483647;b=(b*37+s:byte(i))%2147483629 end
        return "SavedGun_"..string.format("%.0f_%.0f",a,b)
    end
    local entries,selected={},nil
    local raw=gui:GetAttribute(KEY)
    if type(raw)=="string"and #raw<=MAX_BYTES then
        local ok,saved=pcall(function()return Http:JSONDecode(raw)end)
        if ok and type(saved)=="table"and saved.version==1 and type(saved.entries)=="table"and #saved.entries<=MAX_ENTRIES then
            for _,record in ipairs(saved.entries)do
                if type(record)=="table"and type(record.id)=="string"and #record.id<=100 and type(record.name)=="string"and #record.name<=150 then
                    local definition=unpackDefinition(record.definition)
                    if definition and record.id==identity(definition)then
                        entries[#entries+1]={id=record.id,name=record.name,kind="Gun",definition=definition}
                    end
                end
            end
            if type(saved.selected)=="string"then selected=saved.selected end
        end
    end
    if selected then
        local found=false;for _,entry in ipairs(entries)do if entry.id==selected then found=true;break end end
        if not found then selected=nil end
    end
    local function save()
        local records={};for _,entry in ipairs(entries)do records[#records+1]={id=entry.id,name=entry.name,definition=pack(entry.definition)}end
        local encoded=Http:JSONEncode({version=1,entries=records,selected=selected})
        assert(#encoded<=MAX_BYTES,"Saved gun library is full.");gui:SetAttribute(KEY,encoded)
    end
    local api={}
    function api.capture(sourceBasePart,playerName)
        assert(sourceBasePart and read(sourceBasePart,"IsA") and sourceBasePart:IsA("BasePart"),"Choose a gun mesh part.")
        assert(type(playerName)=="string"and #playerName>0 and #playerName<=150,"Enter a player name.")
        local class=read(sourceBasePart,"ClassName")
        local mesh;if class~="MeshPart"then mesh=sourceBasePart:FindFirstChildWhichIsA("SpecialMesh")end
        local size=read(sourceBasePart,"Size");assert(typeof(size)=="Vector3","Gun source has no valid part size.")
        local meshId,textureId,scale,offset,vertexColor
        if mesh then
            meshId=read(mesh,"MeshId");textureId=read(mesh,"TextureId");scale=read(mesh,"Scale");offset=read(mesh,"Offset");vertexColor=read(mesh,"VertexColor")
        elseif class=="MeshPart"then
            meshId=read(sourceBasePart,"MeshId");textureId=read(sourceBasePart,"TextureID")
            local meshSize=read(sourceBasePart,"MeshSize")
            assert(typeof(meshSize)=="Vector3"and meshSize.X~=0 and meshSize.Y~=0 and meshSize.Z~=0,"Gun mesh has no valid mesh size.")
            scale=Vector3.new(size.X/meshSize.X,size.Y/meshSize.Y,size.Z/meshSize.Z);offset=Vector3.new(0,0,0);vertexColor=Vector3.new(1,1,1)
        else error("Gun source needs a SpecialMesh or MeshPart mesh.")end
        local definition={PortableGun=true,MeshId=meshId,TextureId=textureId,Scale=scale,Offset=offset,VertexColor=vertexColor,
            Color=read(sourceBasePart,"Color"),Material=read(sourceBasePart,"Material"),Size=size}
        assert(validDefinition(definition),"Gun mesh has unsupported or oversized visual properties.")
        local id=identity(definition)
        for _,entry in ipairs(entries)do if entry.id==id then return entry end end
        assert(#entries<MAX_ENTRIES,"Saved gun library is full.")
        local entry={id=id,name="Gun from "..playerName,kind="Gun",definition=definition}
        entries[#entries+1]=entry
        local ok,err=pcall(save);if not ok then table.remove(entries);error(err)end
        return entry
    end
    function api.list()local out={};for i,e in ipairs(entries)do out[i]=e end;return out end
    function api.getSelected()return selected end
    function api.select(id)
        if id~=nil then local found=false;for _,entry in ipairs(entries)do if entry.id==id then found=true;break end end;assert(found,"Choose a saved gun.")end
        local previous=selected;selected=id
        local ok,err=pcall(save);if not ok then selected=previous;error(err)end
        return selected
    end
    return api
end
