-- Saved cosmetic character snapshots stored on PlayerGui.
return function(playerGui)
    local Http=game:GetService("HttpService")
    local names={HoneyBunCosmeticSettings=true,HoneyBunCosmeticEmotes=true,HoneyBunCosmeticClothes=true,HoneyBunCosmeticAnimationBundle=true}
    local maxProfiles,maxPreview,maxDocument,maxSafe=12,90000,1400000,9007199254740992
    local function copy(value,seen)
        if type(value)~="table" then return value end
        seen=seen or {};assert(not seen[value],"Cyclic character data")
        seen[value]=true;local out={};for key,item in pairs(value) do out[copy(key,seen)]=copy(item,seen) end;seen[value]=nil;return out
    end
    local function encode(value,message)
        local ok,result=pcall(function() return Http:JSONEncode(value) end)
        assert(ok and type(result)=="string",message or "Invalid character data")
        return result
    end
    local function name(value)
        assert(type(value)=="string","Character name must be text")
        value=value:match("^%s*(.-)%s*$");assert(#value>0 and #value<=40,"Character name must be 1-40 characters");return value
    end
    local function values(source)
        assert(type(source)=="table","Character values are malformed")
        local out,total={ },0
        for key,value in pairs(source) do
            assert(names[key],"Character contains an unknown attribute")
            if key=="HoneyBunCosmeticAnimationBundle" then
                assert(type(value)=="number" and value==value and value>0 and value%1==0 and value<maxSafe,"Animation bundle is invalid")
            else
                assert(type(value)=="string" and #value<=131072,"Character attribute is invalid")
                total=total+#value
            end
            out[key]=value
        end
        assert(total<=1000000,"Character attributes are too large");return out
    end
    local function read()
        local encoded=playerGui:GetAttribute("HoneyBunCosmeticCharacters")
        if encoded==nil then return {version=1,nextId=1,profiles={}} end
        assert(type(encoded)=="string" and #encoded<=maxDocument,"Stored characters are too large")
        local ok,doc=pcall(function() return Http:JSONDecode(encoded) end)
        assert(ok and type(doc)=="table","Stored characters are invalid JSON")
        assert(doc.version==1 and type(doc.nextId)=="number" and doc.nextId==doc.nextId and doc.nextId>=1 and doc.nextId<maxSafe and doc.nextId%1==0 and type(doc.profiles)=="table","Stored characters are malformed")
        local seen,count={},0
        for key in pairs(doc.profiles) do assert(type(key)=="number" and key%1==0 and key>=1 and key<=#doc.profiles and key<=maxProfiles,"Stored characters are malformed") end
        for index=1,#doc.profiles do
            local profile=doc.profiles[index]
            count=count+1;assert(count<=maxProfiles and type(profile)=="table","Stored characters are malformed")
            assert(type(profile.id)=="number" and profile.id==profile.id and profile.id>=1 and profile.id<maxSafe and profile.id%1==0 and profile.id<doc.nextId and not seen[profile.id],"Stored character IDs are malformed")
            seen[profile.id]=true;profile.name=name(profile.name);profile.values=values(profile.values)
            assert(profile.preview==nil or type(profile.preview)=="table","Stored character preview is malformed")
            if profile.preview then assert(#encode(profile.preview)<=maxPreview,"Stored character preview is too large") end
        end
        assert(#encode(doc)<=maxDocument,"Stored characters are too large");return doc
    end
    local document=read()
    local function write(nextDocument)
        local encoded=encode(nextDocument,"Cannot encode characters");assert(#encoded<=maxDocument,"Saved characters are too large")
        playerGui:SetAttribute("HoneyBunCosmeticCharacters",encoded);document=nextDocument
    end
    local api={}
    function api.list() local out={};for i,profile in ipairs(document.profiles) do out[i]=copy(profile) end;return out end
    function api.get(id)
        assert(type(id)=="number" and id==id and id>=1 and id<maxSafe and id%1==0,"Character id is invalid")
        for _,profile in ipairs(document.profiles) do if profile.id==id then return copy(profile) end end
    end
    function api.save(label,preview)
        label=name(label);assert(preview==nil or type(preview)=="table","Character preview is malformed")
        if preview then assert(#encode(preview)<=maxPreview,"Character preview is too large") end
        assert(#document.profiles<maxProfiles,"Character library is full")
        local snapshot={};for key in pairs(names) do local value=playerGui:GetAttribute(key);if value~=nil then snapshot[key]=value end end;snapshot=values(snapshot)
        local profile={id=document.nextId,name=label,values=snapshot};if preview~=nil then profile.preview=copy(preview) end
        local nextDocument={version=1,nextId=document.nextId+1,profiles={}};for i,item in ipairs(document.profiles) do nextDocument.profiles[i]=copy(item) end;table.insert(nextDocument.profiles,profile);write(nextDocument);return copy(profile)
    end
    function api.rename(id,label)
        assert(type(id)=="number" and id==id and id>=1 and id<maxSafe and id%1==0,"Character id is invalid")
        label=name(label)
        local nextDocument={version=1,nextId=document.nextId,profiles={}};local found=false;local renamed
        for i,profile in ipairs(document.profiles) do
            local nextProfile=copy(profile)
            if profile.id==id then found=true;nextProfile.name=label;renamed=nextProfile end
            nextDocument.profiles[i]=nextProfile
        end
        assert(found,"Character not found")
        write(nextDocument);return copy(renamed)
    end
    function api.update(id,preview)
        assert(type(id)=="number" and id==id and id>=1 and id<maxSafe and id%1==0,"Character id is invalid")
        assert(preview==nil or type(preview)=="table","Character preview is malformed")
        if preview then assert(#encode(preview)<=maxPreview,"Character preview is too large") end
        local exists=false;for _,profile in ipairs(document.profiles) do if profile.id==id then exists=true;break end end
        assert(exists,"Character not found")
        local snapshot={};for key in pairs(names) do local value=playerGui:GetAttribute(key);if value~=nil then snapshot[key]=value end end;snapshot=values(snapshot)
        local nextDocument={version=1,nextId=document.nextId,profiles={}};local found=false;local updated
        for i,profile in ipairs(document.profiles) do
            local nextProfile=copy(profile)
            if profile.id==id then
                found=true;nextProfile.values=copy(snapshot);nextProfile.preview=preview and copy(preview) or nil;updated=nextProfile
            end
            nextDocument.profiles[i]=nextProfile
        end
        assert(found,"Character not found")
        write(nextDocument);return copy(updated)
    end
    function api.delete(id)
        local nextDocument={version=1,nextId=document.nextId,profiles={}};local found=false
        for _,profile in ipairs(document.profiles) do if profile.id==id then found=true else table.insert(nextDocument.profiles,copy(profile)) end end
        if found then write(nextDocument) end;return found
    end
    return api
end
