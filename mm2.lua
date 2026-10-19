-- MM2 local discovery and cosmetic previews. It never calls remotes or unlocks items.
return function(game, injectedRequire)
    local api, alive = {}, true
    local function read(object, key) if not object then return nil end; local ok, value = pcall(function() return object[key] end); return ok and value or nil end
    local function service(name) if not game or type(game.GetService) ~= "function" then return nil end; local ok, v = pcall(game.GetService, game, name); return ok and v or nil end
    local function children(object) local fn=read(object,"GetChildren"); if type(fn)~="function" then return {} end; local ok,v=pcall(fn,object); return ok and type(v)=="table" and v or {} end
    local function descendants(object) local fn=read(object,"GetDescendants"); if type(fn)~="function" then return {} end; local ok,v=pcall(fn,object); return ok and type(v)=="table" and v or {} end
    local function isA(object, class) local fn=read(object,"IsA"); if type(fn)=="function" then local ok,v=pcall(fn,object,class); return ok and v==true end; return read(object,"ClassName")==class end
    local function child(parent,name)
        if not parent then return nil end
        local fn=read(parent,"FindFirstChild"); if type(fn)=="function" then local ok,v=pcall(fn,parent,name); if ok and v then return v end end
        for _,v in ipairs(children(parent)) do if read(v,"Name")==name then return v end end
    end
    local function childClass(parent,className)
        if not parent then return nil end
        local fn=read(parent,"FindFirstChildOfClass"); if type(fn)=="function" then local ok,v=pcall(fn,parent,className); if ok and v then return v end end
        for _,v in ipairs(children(parent)) do if isA(v,className) then return v end end
    end
    local function moduleAt(path)
        local current=service("ReplicatedStorage"); for _,name in ipairs(path) do current=child(current,name); if not current then return nil end end
        return isA(current,"ModuleScript") and current or nil
    end
    local function load(module)
        if not module then return nil,"Data ModuleScript was not found" end
        local fn=injectedRequire; if type(fn)~="function" then fn=require end
        local ok,v=pcall(fn,module); if not ok then return nil,tostring(v) end; return v
    end
    local function lower(v) return string.lower(tostring(v or "")) end
    local function field(v,k) return type(v)=="table" and v[k] or read(v,k) end
    local function idOf(v,fallback)
        if type(v)=="string" or type(v)=="number" then return tostring(v) end
        return tostring(field(v,"ItemName") or field(v,"Name") or field(v,"Id") or field(v,"ID") or fallback or "")
    end
    local function kindOf(v)
        local text=lower(field(v,"ItemType") or field(v,"Type")); if text:find("emote",1,true) then return "Emote" end
        if text:find("gun",1,true) then return "Gun" end; if text:find("knife",1,true) or text:find("weapon",1,true) then return "Knife" end
        local name=lower(idOf(v)); if name:find("gun",1,true) then return "Gun" end; if name:find("knife",1,true) then return "Knife" end
    end
    local function collect(value, wanted, out, seen, fallback)
        if type(value)~="table" or seen[value] then return end; seen[value]=true
        local kind=kindOf(value)
        if not kind and wanted=="Emote" and (field(value,"AnimationId") or field(value,"Animation") or field(value,"Name") or field(value,"ItemName")) then kind="Emote" end
        local id=tostring(field(value,"Id") or field(value,"ID") or fallback or field(value,"ItemName") or field(value,"Name") or "")
        if kind==wanted and id~="" then out[#out+1]={id=id,name=tostring(field(value,"ItemName") or field(value,"Name") or id),kind=kind,rarity=field(value,"Rarity"),definition=value} end
        for k,v in pairs(value) do if type(v)=="table" and k~="Model" then collect(v,wanted,out,seen,tostring(k)) end end
    end
    local cache,cacheStatus,rawData={},{},{}
    local function catalog(kind)
        if cache[kind] then return cache[kind] end
        local module=kind=="Emote" and moduleAt({"Database","Sync","Emotes"}) or moduleAt({"Database","Sync","Item"})
        local data,loadError=load(module); cacheStatus[kind]={module=module,error=loadError,dataType=type(data)};rawData[kind]=data; local out={}; collect(data,kind,out,{})
        local seen,final={},{ }; for _,e in ipairs(out) do if not seen[e.id] then seen[e.id]=true; final[#final+1]=e end end
        table.sort(final,function(a,b) return lower(a.name)==lower(b.name) and a.id<b.id or lower(a.name)<lower(b.name) end); cache[kind]=final; return final
    end
    local function findEntry(id,kind) for _,e in ipairs(catalog(kind)) do if e.id==tostring(id) then return e end end end
    function api.list(category,search)
        local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower() or nil; if kind~="Knife" and kind~="Gun" and kind~="Emote" then kind=nil end
        local source={}; if kind then for _,e in ipairs(catalog(kind)) do source[#source+1]=e end else for _,k in ipairs({"Knife","Gun","Emote"}) do for _,e in ipairs(catalog(k)) do source[#source+1]=e end end end
        local query,out=lower(search),{}; for _,e in ipairs(source) do if query=="" or lower(e.name):find(query,1,true) or lower(e.id):find(query,1,true) then out[#out+1]={id=e.id,name=e.name,kind=e.kind,rarity=e.rarity,image=field(e.definition,"Image") or field(e.definition,"ImageId"),season=field(e.definition,"Season") or field(e.definition,"Event")} end end; return out
    end
    local snapshots,track = {},nil
    local function set(o,k,v) if not o then return false end; local ok=pcall(function() o[k]=v end); return ok and (v==nil or read(o,k)~=nil) end
    local function targetTool(expected)
        local ps=service("Players"); local p=ps and read(ps,"LocalPlayer"); local c=p and read(p,"Character")
        for _,t in ipairs(children(c)) do if isA(t,"Tool") then local name=lower(read(t,"Name")); local actual=name:find("gun",1,true) and "Gun" or (name:find("knife",1,true) or name:find("weapon",1,true)) and "Knife"; local h=child(t,"Handle"); if h and actual==expected then return t,h end end end
    end
    local function modelHandle(model)
        if type(model)=="string" then
            local resources=child(service("ReplicatedStorage"),"Resources")
            for _,candidate in ipairs(descendants(resources)) do
                if read(candidate,"Name")==model and (isA(candidate,"Model") or isA(candidate,"Tool") or isA(candidate,"BasePart")) then
                    model=candidate;break
                end
            end
        end
        if isA(model,"Model") or isA(model,"Tool") then return child(model,"Handle") end
        if isA(model,"BasePart") then return model end
    end
    local function handleVisual(def)
        local mesh,texture=field(def,"MeshId"),field(def,"TextureId"); local color=field(def,"Color") or field(def,"Color3"); local material=field(def,"Material")
        local scale,meshType=field(def,"Scale"),field(def,"MeshType")
        local h=modelHandle(field(def,"Model"))
        if h then
            local m=childClass(h,"SpecialMesh")
            if m then
                mesh=mesh or read(m,"MeshId");texture=texture or read(m,"TextureId")
                scale=scale or read(m,"Scale");meshType=meshType or read(m,"MeshType")
            end
            assert(not isA(h,"MeshPart"),"This cosmetic uses a MeshPart model; this preview format is not supported yet.")
            color=color or read(h,"Color");material=material or read(h,"Material")
        end
        return mesh,texture,color,material,scale,meshType
    end
    function api.preview(id,category)
        assert(alive,"The MM2 cosmetic preview is closed."); local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower(); if kind~="Emote" then kind=kind=="Gun" and "Gun" or "Knife" end
        local e=findEntry(id,kind); assert(e,"Cosmetic is not in the local "..kind.." catalog: "..tostring(id))
        if kind=="Emote" then
            local ps=service("Players")
            local p=read(ps,"LocalPlayer")
            local h=childClass(read(p,"Character"),"Humanoid")
            local animator=childClass(h,"Animator")
            local aid=field(e.definition,"AnimationId") or field(e.definition,"Animation")
            if type(aid)=="number" then aid=tostring(aid) end
            assert(type(aid)=="string" and aid~="","Emote has no explicit AnimationId.")
            if aid:match("^%s*%d+%s*$") then aid="rbxassetid://"..aid:match("%d+") end
            assert(animator and type(read(animator,"LoadAnimation"))=="function","Character Animator is unavailable for local emote preview.")
            local anim=Instance.new("Animation")
            local nextTrack
            local ok,message=pcall(function()
                anim.AnimationId=aid
                nextTrack=animator:LoadAnimation(anim)
                assert(nextTrack,"Animator did not return an animation track.")
                nextTrack:Play()
            end)
            anim:Destroy()
            if not ok then
                if nextTrack then pcall(function() nextTrack:Stop(0);nextTrack:Destroy() end) end
                error("Could not play this emote: "..tostring(message))
            end
            if track then pcall(function() track:Stop(0);track:Destroy() end) end
            track=nextTrack
            return "Previewing emote: "..e.name
        end
        local _,handle=targetTool(kind); assert(handle,"Equip a matching "..kind:lower().." Tool with a Handle before previewing this cosmetic."); local meshId,textureId,color,material,scale,meshType=handleVisual(e.definition); assert(meshId or textureId or color or material or scale or meshType,"Cosmetic has no supported local visual fields (explicit MeshId/TextureId, Handle mesh, Color, or Material).")
        local mesh=childClass(handle,"SpecialMesh"); assert(mesh or not(meshId or textureId or scale or meshType),"Equipped Handle has no SpecialMesh for this mesh preview.")
        local old=snapshots[handle]; if not old then old={handle=handle,mesh=mesh,meshId=read(mesh,"MeshId"),textureId=read(mesh,"TextureId"),scale=read(mesh,"Scale"),meshType=read(mesh,"MeshType"),color=read(handle,"Color"),material=read(handle,"Material")}; snapshots[handle]=old end
        local changes={{mesh,"MeshId",meshId},{mesh,"TextureId",textureId},{mesh,"Scale",scale},{mesh,"MeshType",meshType},{handle,"Color",color},{handle,"Material",material}}
        for _,change in ipairs(changes) do if change[3]~=nil and not set(change[1],change[2],change[3]) then set(old.mesh,"MeshId",old.meshId); set(old.mesh,"TextureId",old.textureId); set(old.mesh,"Scale",old.scale); set(old.mesh,"MeshType",old.meshType); set(old.handle,"Color",old.color); set(old.handle,"Material",old.material); snapshots[handle]=nil; error("Cosmetic preview could not set supported field "..change[2]) end end
        return "Previewing "..kind:lower().." locally: "..e.name
    end
    function api.restore() if track then pcall(function() track:Stop(0);track:Destroy() end); track=nil end; for _,old in pairs(snapshots) do set(old.mesh,"MeshId",old.meshId); set(old.mesh,"TextureId",old.textureId); set(old.mesh,"Scale",old.scale); set(old.mesh,"MeshType",old.meshType); set(old.handle,"Color",old.color); set(old.handle,"Material",old.material) end; snapshots={}; return "Restored local MM2 preview." end
    function api.destroy() if alive then alive=false; return api.restore() end end
    local function fullName(o) local fn=read(o,"GetFullName"); if type(fn)=="function" then local ok,v=pcall(fn,o); if ok and type(v)=="string" then return v end end; return tostring(read(o,"Name") or "") end
    local function samples(data)
        local entries={}
        if type(data)~="table" then return "unavailable" end
        for id,definition in pairs(data) do
            if type(definition)=="table" then
                local values={}
                for key,value in pairs(definition) do
                    if #values>=20 then break end
                    if type(value)=="string" or type(value)=="number" or type(value)=="boolean" then
                        values[#values+1]=tostring(key).."="..tostring(value):sub(1,180)
                    else values[#values+1]=tostring(key).."=["..type(value).."]" end
                end
                table.sort(values);entries[#entries+1]=tostring(id).."{"..table.concat(values,";").."}"
                if #entries>=3 then break end
            end
        end
        return table.concat(entries,", ")
    end
    function api.report()
        local rs=service("ReplicatedStorage"); local ps=service("Players"); local p=ps and read(ps,"LocalPlayer"); local lines={"MM2 discovery (read-only)","GameId="..tostring(read(game,"GameId") or "?"),"PlaceId="..tostring(read(game,"PlaceId") or "?"),"ReplicatedStorage="..(rs and "available" or "missing"),"LocalPlayer="..(p and tostring(read(p,"Name") or "available") or "missing")}
        lines[#lines+1]="Build: local catalog preview V1"
        for _,pair in ipairs({{"Item","Knife"},{"Emotes","Emote"}}) do
            local label,kind=pair[1],pair[2]
            catalog(kind)
            local status=cacheStatus[kind]
            lines[#lines+1]=label.." requireType="..status.dataType.." error="..tostring(status.error or "none").." samples="..samples(rawData[kind])
        end
        local gui=p and read(p,"PlayerGui"); local paths={}; for _,o in ipairs(descendants(rs)) do local path=fullName(o); local x=lower(path); if (x:find("database",1,true) or x:find("item",1,true) or x:find("emote",1,true) or x:find("inventory",1,true)) and (isA(o,"ModuleScript") or isA(o,"Folder") or isA(o,"Model") or isA(o,"LocalScript")) then paths[#paths+1]="RS match: "..path end end; for _,o in ipairs(descendants(gui)) do local path=fullName(o); local x=lower(path); if (x:find("inventory",1,true) or x:find("item",1,true) or x:find("emote",1,true)) and (isA(o,"ModuleScript") or isA(o,"LocalScript") or isA(o,"ScreenGui") or isA(o,"Frame")) then paths[#paths+1]="PlayerGui match: "..path end end; local c=p and read(p,"Character"); for _,o in ipairs(children(c)) do if isA(o,"Tool") or isA(o,"Accessory") then paths[#paths+1]="Equipped "..tostring(read(o,"ClassName") or "Instance")..": "..fullName(o) end end; for _,path in ipairs(paths) do if #lines<80 then lines[#lines+1]=path end end; return table.concat(lines,"\n")
    end
    return api
end
