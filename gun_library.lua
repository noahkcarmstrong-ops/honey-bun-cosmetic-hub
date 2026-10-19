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
        if t=="CFrame"then
            local ok,values=pcall(function()return {v:GetComponents()}end)
            if ok and #values==12 then for _,n in ipairs(values)do if not finite(n)then return nil end end;return {t=t,v=values}end
        end
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
        if v.t=="CFrame"and #a==12 then
            for _,n in ipairs(a)do if not finite(n)then return nil end end
            return CFrame.new(table.unpack(a))
        end
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
    local function packMounts(mounts)
        if mounts==nil then return nil end
        if type(mounts)~="table"then return nil end
        local packed={}
        for name,mount in pairs(mounts)do
            if (name~="Holster"and name~="Held")or type(mount)~="table"then return nil end
            for key in pairs(mount)do if key~="Part"and key~="Offset"then return nil end end
            if type(mount.Part)~="string"or #mount.Part==0 or #mount.Part>64 then return nil end
            local offset=encode(mount.Offset)
            if not offset or offset.t~="CFrame"then return nil end
            packed[name]={Part=mount.Part,Offset=offset}
        end
        return next(packed)and packed or nil
    end
    local function unpackMounts(mounts)
        if mounts==nil then return nil,true end
        if type(mounts)~="table"then return nil,false end
        local decoded={}
        for name,mount in pairs(mounts)do
            if (name~="Holster"and name~="Held")or type(mount)~="table"then return nil,false end
            for key in pairs(mount)do if key~="Part"and key~="Offset"then return nil,false end end
            if type(mount.Part)~="string"or #mount.Part==0 or #mount.Part>64 then return nil,false end
            local offset=decode(mount.Offset)
            if typeof(offset)~="CFrame"then return nil,false end
            decoded[name]={Part=mount.Part,Offset=offset}
        end
        if not next(decoded)then return nil,false end
        return decoded,true
    end
    local SOUND_PROPERTIES={SoundId="string",Volume="volume",PlaybackSpeed="speed",RollOffMinDistance="distance",RollOffMaxDistance="distance",EmitterSize="distance",Looped="boolean"}
    local function packPresentation(presentation)
        if presentation==nil then return nil end
        if type(presentation)~="table"then return nil end
        for key in pairs(presentation)do if key~="Grip"and key~="ToolIcon"and key~="Sounds"then return nil end end
        local packed={}
        if presentation.Grip~=nil then
            local grip=encode(presentation.Grip);if not grip or grip.t~="CFrame"then return nil end
            packed.Grip=grip
        end
        if presentation.ToolIcon~=nil then
            if type(presentation.ToolIcon)~="string"or #presentation.ToolIcon>MAX_STRING then return nil end
            if #presentation.ToolIcon>0 then packed.ToolIcon=presentation.ToolIcon end
        end
        if presentation.Sounds~=nil then
            if type(presentation.Sounds)~="table"then return nil end
            local count=0;for key in pairs(presentation.Sounds)do if type(key)~="number"or key<1 or key>32 or key%1~=0 then return nil end;count=count+1 end
            if count>32 then return nil end
            for i=1,count do if presentation.Sounds[i]==nil then return nil end end
            if count>0 then packed.Sounds={} end
            for i,sound in ipairs(presentation.Sounds)do
                if type(sound)~="table"then return nil end
                for key in pairs(sound)do if key~="Name"and key~="Path"and key~="Properties"then return nil end end
                if type(sound.Name)~="string"or #sound.Name==0 or #sound.Name>100 or type(sound.Path)~="table"then return nil end
                local pathCount=0;for key in pairs(sound.Path)do if type(key)~="number"or key<1 or key>8 or key%1~=0 then return nil end;pathCount=pathCount+1 end
                if pathCount==0 or pathCount>8 then return nil end
                for n=1,pathCount do if sound.Path[n]==nil then return nil end end
                local item={Name=sound.Name,Path={}}
                for n,part in ipairs(sound.Path)do if type(part)~="string"or #part==0 or #part>100 then return nil end;item.Path[n]=part end
                if type(sound.Properties)~="table"then return nil end
                item.Properties={}
                for key,value in pairs(sound.Properties)do
                    local rule=SOUND_PROPERTIES[key];if not rule then return nil end
                    if rule=="string"then if type(value)~="string"or #value>MAX_STRING then return nil end
                    elseif rule=="boolean"then if type(value)~="boolean"then return nil end
                    elseif not finite(value)then return nil
                    elseif rule=="volume"then if value<0 or value>10 then return nil end
                    elseif rule=="speed"then if value<=0 or value>10 then return nil end
                    elseif value<0 then return nil end
                    item.Properties[key]=value
                end
                packed.Sounds[i]=item
            end
        end
        return next(packed)and packed or nil
    end
    local function unpackPresentation(presentation)
        if presentation==nil then return nil,true end
        if type(presentation)~="table"then return nil,false end
        for key in pairs(presentation)do if key~="Grip"and key~="ToolIcon"and key~="Sounds"then return nil,false end end
        local result={}
        if presentation.Grip~=nil then local grip=decode(presentation.Grip);if typeof(grip)~="CFrame"then return nil,false end;result.Grip=grip end
        if presentation.ToolIcon~=nil then if type(presentation.ToolIcon)~="string"or #presentation.ToolIcon>MAX_STRING then return nil,false end;if #presentation.ToolIcon>0 then result.ToolIcon=presentation.ToolIcon end end
        if presentation.Sounds~=nil then
            local packed=packPresentation({Sounds=presentation.Sounds});if packed then
                result.Sounds={}
                for i,sound in ipairs(packed.Sounds)do result.Sounds[i]={Name=sound.Name,Path=sound.Path,Properties=sound.Properties}end
            elseif type(presentation.Sounds)~="table"or next(presentation.Sounds)~=nil then return nil,false end
        end
        return next(result)and result or nil,true
    end
    local function pack(d)
        local out={PortableGun=true,MeshId=d.MeshId,TextureId=d.TextureId,Scale=encode(d.Scale),Offset=encode(d.Offset),
            VertexColor=encode(d.VertexColor),Color=encode(d.Color),Material=encode(d.Material,"Material"),Size=encode(d.Size)}
        if d.Mounts then out.Mounts=packMounts(d.Mounts)end
        if d.Presentation then out.Presentation=packPresentation(d.Presentation)end
        return out
    end
    local function unpackDefinition(d)
        if type(d)~="table"or d.PortableGun~=true then return nil end
        local mounts,mountsValid=unpackMounts(d.Mounts);if not mountsValid then return nil end
        local presentation,presentationValid=unpackPresentation(d.Presentation);if not presentationValid then return nil end
        local result={PortableGun=true,MeshId=decode(d.MeshId),TextureId=decode(d.TextureId),Scale=decode(d.Scale),Offset=decode(d.Offset),
            VertexColor=decode(d.VertexColor),Color=decode(d.Color),Material=decode(d.Material,"Material"),Size=decode(d.Size),Mounts=mounts,Presentation=presentation}
        return validDefinition(result)and result or nil
    end
    local function canonical(v,precise)
        if type(v)=="number"then return "number:"..string.format(precise and "%.9f"or"%.5f",v)end
        if type(v)~="table"then return type(v)..":"..tostring(v)end
        local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
        local out={};for _,k in ipairs(keys)do out[#out+1]=k.."="..canonical(v[k],precise or k=="Mounts")end;return "{"..table.concat(out,"|").."}"
    end
    local function identity(d,kind)
        local s=canonical(pack(d));local a,b=1,7
        for i=1,#s do a=(a*31+s:byte(i))%2147483647;b=(b*37+s:byte(i))%2147483629 end
        return (kind=="Knife" and "SavedKnife_" or "SavedGun_")..string.format("%.0f_%.0f",a,b)
    end
    local entries,selected,selectedKnife={},nil,nil
    local raw=gui:GetAttribute(KEY)
    if type(raw)=="string"and #raw<=MAX_BYTES then
        local ok,saved=pcall(function()return Http:JSONDecode(raw)end)
        if ok and type(saved)=="table"and saved.version==1 and type(saved.entries)=="table"and #saved.entries<=MAX_ENTRIES then
            for _,record in ipairs(saved.entries)do
                if type(record)=="table"and type(record.id)=="string"and #record.id<=100 and type(record.name)=="string"and #record.name<=150 then
                    local kind=record.kind=="Knife" and "Knife" or "Gun"
                    local definition=unpackDefinition(record.definition)
                    if definition and record.id==identity(definition,kind)then
                        entries[#entries+1]={id=record.id,name=record.name,kind=kind,definition=definition}
                    end
                end
            end
            if type(saved.selected)=="string"then selected=saved.selected end
            if type(saved.selectedKnife)=="string"then selectedKnife=saved.selectedKnife end
        end
    end
    if selected then
        local found=false;for _,entry in ipairs(entries)do if entry.id==selected and entry.kind=="Gun" then found=true;break end end
        if not found then selected=nil end
    end
    if selectedKnife then local found=false;for _,entry in ipairs(entries)do if entry.id==selectedKnife and entry.kind=="Knife"then found=true;break end end;if not found then selectedKnife=nil end end
    local function save()
        local records={};for _,entry in ipairs(entries)do local record={id=entry.id,name=entry.name,definition=pack(entry.definition)};if entry.kind=="Knife"then record.kind="Knife"end;records[#records+1]=record end
        local encoded=Http:JSONEncode({version=1,entries=records,selected=selected,selectedKnife=selectedKnife})
        assert(#encoded<=MAX_BYTES,"Saved gun library is full.");gui:SetAttribute(KEY,encoded)
    end
    local api={}
    function api.capture(sourceBasePart,playerName,mounts,kind,presentation)
        kind=kind=="Knife" and "Knife" or "Gun"
        local noun=kind:lower()
        assert(sourceBasePart and read(sourceBasePart,"IsA") and sourceBasePart:IsA("BasePart"),"Choose a "..noun.." mesh part.")
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
        local encodedMounts=packMounts(mounts)
        definition.Mounts=unpackMounts(encodedMounts)
        local encodedPresentation=packPresentation(presentation)
        if encodedPresentation then definition.Presentation=unpackPresentation(encodedPresentation)end
        assert(validDefinition(definition),"Gun mesh has unsupported or oversized visual properties.")
        local id=identity(definition,kind)
        for _,entry in ipairs(entries)do if entry.id==id and entry.kind==kind then return entry end end
        assert(#entries<MAX_ENTRIES,"Saved gun library is full.")
        local entry={id=id,name=kind.." from "..playerName,kind=kind,definition=definition}
        entries[#entries+1]=entry
        local ok,err=pcall(save);if not ok then table.remove(entries);error(err)end
        return entry
    end
    function api.list(kind)local out={};for _,e in ipairs(entries)do if kind==nil or e.kind==kind then out[#out+1]=e end end;return out end
    function api.getSelected(kind)if kind=="Knife"then return selectedKnife end;return selected end
    function api.select(id,kind)
        kind=kind=="Knife" and "Knife" or "Gun"
        if id~=nil then local found=false;for _,entry in ipairs(entries)do if entry.id==id and entry.kind==kind then found=true;break end end;assert(found,"Choose a saved "..kind:lower()..".")end
        local previous=kind=="Knife" and selectedKnife or selected
        if kind=="Knife"then selectedKnife=id else selected=id end
        local ok,err=pcall(save);if not ok then if kind=="Knife"then selectedKnife=previous else selected=previous end;error(err)end
        if kind=="Knife"then return selectedKnife end;return selected
    end
    return api
end
