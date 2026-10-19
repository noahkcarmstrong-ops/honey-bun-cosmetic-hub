-- MM2 local discovery and cosmetic previews. It never calls remotes or unlocks items.
return function(game, injectedRequire)
    local api, alive = {}, true
    local function read(object, key) if not object then return nil end; local ok, value = pcall(function() return object[key] end); return ok and value or nil end
    local function service(name) if not game or type(game.GetService) ~= "function" then return nil end; local ok, v = pcall(game.GetService, game, name); return ok and v or nil end
    local function children(object) local fn=read(object,"GetChildren"); if type(fn)~="function" then return {} end; local ok,v=pcall(fn,object); return ok and type(v)=="table" and v or {} end
    local function descendants(object)
        local fn=read(object,"GetDescendants")
        if type(fn)=="function" then local ok,v=pcall(fn,object);if ok and type(v)=="table" then return v end end
        local out={}
        local function walk(parent) for _,o in ipairs(children(parent)) do out[#out+1]=o;walk(o) end end
        walk(object);return out
    end
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
        if not kind and wanted=="Emote" and (field(value,"AnimationID") or field(value,"AnimationId") or field(value,"Animation") or field(value,"Name") or field(value,"ItemName")) then kind="Emote" end
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
    local function metadata(def)
        local season=field(def,"Season"); local event=field(def,"Event"); local holiday=field(def,"Holiday")
        local function text(v) return type(v)=="string" and lower(v) or "" end
        local holidayFlag=holiday==true or (type(holiday)=="string" and text(holiday)~="" and text(holiday)~="false")
        if type(event)=="table" then holidayFlag=true elseif event~=nil and text(event)~="" and text(event)~="false" then holidayFlag=true end
        local christmas,halloween=field(def,"Christmas"),field(def,"Halloween")
        if christmas==true or halloween==true or (type(christmas)=="string" and text(christmas)~="false" and text(christmas)~="") or (type(halloween)=="string" and text(halloween)~="false" and text(halloween)~="") then holidayFlag=true end
        local seasonName=tostring(season or ""):lower():gsub("[%s_]","")
        if seasonName:find("halloween",1,true) or seasonName:find("christmas",1,true) or seasonName=="holiday" then holidayFlag=true end
        local category=holidayFlag and "holiday" or ((season==1 or seasonName=="season1" or seasonName=="1") and "season1" or "classic")
        return category,field(def,"Year") or season,event,field(def,"Rarity"),field(def,"SortOrder") or field(def,"LayoutOrder")
    end
    local rarityTables
    local function rarityStyle(def)
        if not rarityTables then
            rarityTables={}
            for _,name in ipairs({"Rarity","Rarities"}) do
                local data=load(moduleAt({"Database","Sync",name}))
                if type(data)=="table" then rarityTables[#rarityTables+1]=data end
            end
        end
        local color=field(def,"RarityColor")
        local order=field(def,"RarityOrder")
        local key=field(def,"Rarity")
        for _,data in ipairs(rarityTables) do
            local style=key and data[key]
            if type(typeof)=="function" and typeof(style)=="Color3" then color=color or style end
            if type(style)=="table" then
                color=color or style.Color or style.Color3
                order=order or style.SortOrder or style.Rank
            end
        end
        return color,type(order)=="number" and order or nil
    end
    function api.list(category,search)
        local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower() or nil; if kind~="Knife" and kind~="Gun" and kind~="Emote" then kind=nil end
        local source={}; if kind then for _,e in ipairs(catalog(kind)) do source[#source+1]=e end else for _,k in ipairs({"Knife","Gun","Emote"}) do for _,e in ipairs(catalog(k)) do source[#source+1]=e end end end
        local query,out=lower(search),{}; for _,e in ipairs(source) do if query=="" or lower(e.name):find(query,1,true) or lower(e.id):find(query,1,true) then
            local categoryName,year,event,rarity,sortOrder=metadata(e.definition)
            local rarityColor,rarityOrder=rarityStyle(e.definition)
            local chroma=field(e.definition,"Chroma"); out[#out+1]={id=e.id,name=e.name,kind=e.kind,rarity=rarity,image=field(e.definition,"Image") or field(e.definition,"ImageId") or field(e.definition,"ImageID"),category=categoryName,year=year,event=event,rarityColor=rarityColor,rarityOrder=rarityOrder,season=field(e.definition,"Season"),sortOrder=sortOrder,chroma=chroma==true or (type(chroma)=="string" and lower(chroma)~="" and lower(chroma)~="false")}
        end end; return out
    end
    local snapshots,track = {},nil
    local equipped,pending,connections = {},{},{}
    local allowPending=false
    local watchersActive=false
    local observed={}
    local equipError,lastEquipResult
    local function disconnectAll()
        for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        connections={};watchersActive=false;observed={}
    end
    local function connect(signal, fn)
        local method=signal and read(signal,"Connect")
        if type(method)=="function" then local ok,c=pcall(method,signal,fn); if ok and c then connections[#connections+1]=c; return c end end
    end
    local function set(o,k,v) if not o then return false end; local ok=pcall(function() o[k]=v end); return ok and (v==nil or read(o,k)~=nil) end
    local function toolKind(t)
        local text=lower(read(t,"Name")); return text:find("gun",1,true) and "Gun" or (text:find("knife",1,true) or text:find("weapon",1,true)) and "Knife"
    end
    local function weaponTarget(object)
        if isA(object,"Tool") then return true end
        local name=lower(read(object,"Name"))
        return (isA(object,"Accessory") or isA(object,"Model") or isA(object,"BasePart")) and
            (name=="knife" or name=="gun" or name=="knifedisplay" or name=="gundisplay" or name=="holsteredknife" or name=="holsteredgun")
    end
    local function weaponHandle(object)
        return isA(object,"BasePart") and object or child(object,"Handle")
    end
    local function targetTool(expected)
        local ps=service("Players"); local p=ps and read(ps,"LocalPlayer"); local c=p and read(p,"Character")
        local bp=p and read(p,"Backpack")
        local containers={character=c,backpack=bp}
        for _,key in ipairs({"character","backpack"}) do
            for _,t in ipairs(descendants(containers[key])) do
                if weaponTarget(t) then local h=weaponHandle(t);if h and toolKind(t)==expected then return t,h end end
            end
        end
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
    local assetCache,assetRoots,assetFailures,resourceCache={},{},{},{}
    local lastAttempt
    local function itemAsset(assetId)
        local id=tonumber(assetId)
        assert(id and id>0 and id%1==0,"The item has an invalid ItemID asset.")
        local key=tostring(id)
        if assetCache[key] then return assetCache[key] end
        if assetFailures[key] then error(assetFailures[key]) end
        local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..string.format("%.0f",id)) end)
        if not ok or type(objects)~="table" or #objects==0 then
            local message="Could not load ItemID "..key..": "..tostring(objects)
            if ok and type(objects)=="table" then message="ItemID "..key.." returned no objects; its asset is unavailable to this client." end
            assetFailures[key]=message;error(message)
        end
        local all={}
        for _,object in ipairs(objects) do
            assetRoots[#assetRoots+1]=object
            all[#all+1]=object
            for _,desc in ipairs(descendants(object)) do all[#all+1]=desc end
        end
        for _,object in ipairs(all) do
            if isA(object,"LuaSourceContainer") then pcall(function() object:Destroy() end) end
        end
        local visual
        for _,object in ipairs(all) do
            if read(object,"Name")=="Handle" and isA(object,"BasePart") then visual=object;break end
        end
        if not visual then
            local parts,meshes,layout={},{},{}
            for _,object in ipairs(all) do
                if isA(object,"BasePart") then parts[#parts+1]=object end
                if isA(object,"SpecialMesh") then meshes[#meshes+1]=object end
                if #layout<16 then layout[#layout+1]=tostring(read(object,"Name")).."["..tostring(read(object,"ClassName")).."]" end
            end
            if #parts==1 then visual=parts[1] elseif #parts==0 and #meshes==1 then visual=meshes[1] end
            if not visual then
                local message="ItemID "..key.." has an unsupported visual layout: "..table.concat(layout,", ")
                assetFailures[key]=message;error(message)
            end
        end
        assetCache[key]=visual
        return visual
    end
    local function resourceVisual(entry)
        if resourceCache[entry.id] then return resourceCache[entry.id] end
        local storage=service("ReplicatedStorage")
        local candidates={entry.id,field(entry.definition,"ItemName"),field(entry.definition,"Name"),field(entry.definition,"ItemID")}
        local objects=descendants(storage)
        for i=1,4 do
            local name=candidates[i]
            if name then
                for _,object in ipairs(objects) do
                    if tostring(read(object,"Name"))==tostring(name) then
                        local source=modelHandle(object)
                        if not source and isA(object,"SpecialMesh") then source=object end
                        if not source and (isA(object,"Model") or isA(object,"Tool") or isA(object,"Folder")) then
                            local parts={}
                            for _,desc in ipairs(descendants(object)) do
                                if isA(desc,"BasePart") then
                                    parts[#parts+1]=desc
                                    if read(desc,"Name")=="Handle" then source=desc;break end
                                end
                            end
                            if not source and #parts==1 then source=parts[1] end
                        end
                        if source then resourceCache[entry.id]=source;return source end
                    end
                end
            end
        end
    end
    local function handleVisual(def,entry)
        local mesh,texture=field(def,"MeshId") or field(def,"MeshID"),field(def,"TextureId") or field(def,"TextureID"); local color=field(def,"Color") or field(def,"Color3"); local material=field(def,"Material")
        local scale,meshType=field(def,"Scale"),field(def,"MeshType")
        local h=modelHandle(field(def,"Model"))
        if not h and entry then h=resourceVisual(entry) end
        if not h and field(def,"ItemID") then h=itemAsset(field(def,"ItemID")) end
        if h then
            local m=isA(h,"SpecialMesh") and h or childClass(h,"SpecialMesh")
            if m then
                mesh=mesh or read(m,"MeshId");texture=texture or read(m,"TextureId")
                scale=scale or read(m,"Scale");meshType=meshType or read(m,"MeshType")
            end
            color=color or read(h,"Color");material=material or read(h,"Material")
            if isA(h,"MeshPart") then texture=texture or read(h,"TextureID") end
        end
        return mesh,texture,color,material,scale,meshType,h
    end
    local function restoreHandle(old)
        if old.sourceClone then
            pcall(function() old.handle:ApplyMesh(old.sourceClone) end)
            pcall(function() old.sourceClone:Destroy() end)
            old.sourceClone=nil
        end
        set(old.mesh,"MeshId",old.meshId);set(old.mesh,"TextureId",old.textureId)
        set(old.mesh,"Scale",old.scale);set(old.mesh,"MeshType",old.meshType)
        set(old.handle,"Color",old.color);set(old.handle,"Material",old.material)
    end
    function api.preview(id,category,selectedTool)
        assert(alive,"The MM2 cosmetic preview is closed."); local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower(); if kind~="Emote" then kind=kind=="Gun" and "Gun" or "Knife" end
        local e=findEntry(id,kind); assert(e,"Cosmetic is not in the local "..kind.." catalog: "..tostring(id))
        if kind=="Emote" then
            local ps=service("Players")
            local p=read(ps,"LocalPlayer")
            local h=childClass(read(p,"Character"),"Humanoid")
            local animator=childClass(h,"Animator")
            local aid=field(e.definition,"AnimationId") or field(e.definition,"AnimationID") or field(e.definition,"Animation")
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
        local _,handle=targetTool(kind)
        if selectedTool then assert(weaponTarget(selectedTool) and toolKind(selectedTool)==kind,"Matching native weapon is required.");handle=weaponHandle(selectedTool) end
        if not handle and allowPending then
            pending[kind]=e.id;equipped[kind]=e.id
            return "Queued "..kind:lower().." locally: "..e.name.." (waiting for your matching weapon)"
        end
        local meshId,textureId,color,material,scale,meshType,source=handleVisual(e.definition,e)
        if field(e.definition,"Model")~=nil then assert(source,"Cosmetic model reference could not be resolved from ReplicatedStorage.Resources.") end
        assert(meshId or textureId or color or material or scale or meshType or source,"Cosmetic has no supported local visual fields (explicit MeshId/TextureId, model, Handle mesh, Color, or Material).")
        if not handle then
            error("Equip a matching "..kind:lower().." Tool with a Handle before previewing this cosmetic.")
        end
        local mesh=childClass(handle,"SpecialMesh")
        local applyMesh=source and isA(source,"MeshPart") and isA(handle,"MeshPart") and type(read(handle,"ApplyMesh"))=="function"
        if source and isA(source,"MeshPart") and not applyMesh then
            assert(mesh,"The native weapon needs a SpecialMesh or MeshPart for this skin.")
            local size,meshSize=read(source,"Size"),read(source,"MeshSize")
            assert(size and meshSize and meshSize.X>0 and meshSize.Y>0 and meshSize.Z>0,"This asset did not expose mesh dimensions for the native Part weapon.")
            meshId=read(source,"MeshId");textureId=read(source,"TextureID")
            assert(type(meshId)=="string" and meshId~="","This weapon asset has no readable mesh.")
            scale=Vector3.new(size.X/meshSize.X,size.Y/meshSize.Y,size.Z/meshSize.Z)
            meshType=Enum.MeshType.FileMesh
        end
        assert(applyMesh or mesh or not(meshId or textureId or scale or meshType),"Equipped Handle has no SpecialMesh for this mesh preview.")
        local old=snapshots[handle]; if not old then
            old={handle=handle,mesh=mesh,meshId=read(mesh,"MeshId"),textureId=read(mesh,"TextureId"),scale=read(mesh,"Scale"),meshType=read(mesh,"MeshType"),color=read(handle,"Color"),material=read(handle,"Material"),sourceClone=nil}
            if applyMesh and type(read(handle,"Clone"))=="function" then local ok,clone=pcall(read(handle,"Clone"),handle); if ok then old.sourceClone=clone end;assert(old.sourceClone,"Could not snapshot the original weapon mesh safely.") end
            snapshots[handle]=old
        end
        if applyMesh and not old.sourceClone then
            local ok,clone=pcall(function() return handle:Clone() end)
            assert(ok and clone,"Could not preserve the original weapon mesh safely.")
            old.sourceClone=clone
        end
        if applyMesh then
            local ok,message=pcall(read(handle,"ApplyMesh"),handle,source)
            if not ok then restoreHandle(old);snapshots[handle]=nil;error("Could not apply the cosmetic mesh: "..tostring(message)) end
        end
        if applyMesh and meshId~=nil and tostring(meshId)~=tostring(read(source,"MeshId")) then restoreHandle(old);snapshots[handle]=nil;error("This cosmetic has a separate MeshId that cannot be applied to this MeshPart safely.") end
        local changes={{mesh,"MeshId",not applyMesh and meshId or nil},{applyMesh and handle or mesh,applyMesh and "TextureID" or "TextureId",textureId},{mesh,"Scale",scale},{mesh,"MeshType",meshType},{handle,"Color",color},{handle,"Material",material}}
        for _,change in ipairs(changes) do
            if change[3]~=nil and not set(change[1],change[2],change[3]) then
                restoreHandle(old);snapshots[handle]=nil
                error("Cosmetic preview could not set supported field "..change[2])
            end
        end
        equipped[kind]=e.id; pending[kind]=nil
        return "Previewing "..kind:lower().." locally: "..e.name
    end
    local function applyToTool(tool)
        if not alive or not weaponTarget(tool) then return end
        local kind=toolKind(tool)
        local id=kind and equipped[kind]
        if id and weaponHandle(tool) then
            local ok,message=pcall(api.preview,id,kind,tool)
            if not ok then pending[kind]=id;equipError=tostring(message) else equipError=nil end
        end
    end
    local function watchTool(tool)
        if not weaponTarget(tool) then return end
        if not observed[tool] then
            observed[tool]=true
            connect(read(tool,"DescendantAdded"),function() applyToTool(tool) end)
            connect(read(tool,"ChildAdded"),function() applyToTool(tool) end)
        end
        applyToTool(tool)
    end
    local function watchContainer(container)
        if not container then return end
        if not observed[container] then
            observed[container]=true;connect(read(container,"ChildAdded"),watchTool);connect(read(container,"DescendantAdded"),watchTool)
        end
        for _,tool in ipairs(descendants(container)) do watchTool(tool) end
    end
    local function ensureWatchers()
        local ps=service("Players");local p=read(ps,"LocalPlayer")
        if not watchersActive then
            watchersActive=true
            connect(read(p,"CharacterAdded"),watchContainer)
            connect(read(p,"ChildAdded"),function(o) if isA(o,"Backpack") then watchContainer(o) end end)
        end
        watchContainer(read(p,"Character"));watchContainer(read(p,"Backpack"))
    end
    function api.equip(id,category)
        assert(alive,"The MM2 cosmetic preview is closed.")
        local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower(); assert(kind=="Gun" or kind=="Knife","Equip category must be Knife or Gun.")
        local e=findEntry(id,kind); assert(e,"Unsupported "..kind:lower().." cosmetic: "..tostring(id))
        lastAttempt={id=e.id,kind=kind,definition=e.definition}
        allowPending=true; local ok,result=pcall(api.preview,e.id,kind); allowPending=false
        if not ok then equipError=tostring(result);error(result) end
        equipError=nil;lastEquipResult=result
        ensureWatchers()
        return result
    end
    function api.getEquipped()
        return {Knife=equipped.Knife,Gun=equipped.Gun}
    end
    function api.restore()
        if track then pcall(function() track:Stop(0);track:Destroy() end); track=nil end
        for _,old in pairs(snapshots) do restoreHandle(old) end
        snapshots={}; pending={}; equipped={};equipError=nil;lastEquipResult=nil; disconnectAll(); return "Restored local MM2 preview."
    end
    function api.destroy()
        if alive then
            alive=false;api.restore()
            for _,object in ipairs(assetRoots) do pcall(function() object:Destroy() end) end
            assetRoots={};assetCache={};assetFailures={};resourceCache={}
        end
    end
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
        lines[#lines+1]="Build: replicated visuals and avatar diagnostics V6"
        lines[#lines+1]="Selected Knife="..tostring(equipped.Knife).." Gun="..tostring(equipped.Gun).." Last equip error="..tostring(equipError or "none")
        lines[#lines+1]="Pending Knife="..tostring(pending.Knife).." Gun="..tostring(pending.Gun).." Last result="..tostring(lastEquipResult or "none")
        if lastAttempt then
            lines[#lines+1]="Last attempted item="..lastAttempt.id.." kind="..lastAttempt.kind.." ItemID="..tostring(field(lastAttempt.definition,"ItemID")).." Model="..tostring(field(lastAttempt.definition,"Model"))
        end
        local roots={}
        for _,object in ipairs(children(rs)) do
            if #roots>=40 then break end
            roots[#roots+1]=tostring(read(object,"Name")).."["..tostring(read(object,"ClassName")).."]"
        end
        lines[#lines+1]="RS roots="..table.concat(roots,", ")
        local character=read(p,"Character")
        local top={}
        for _,object in ipairs(children(character)) do
            if #top>=40 then break end
            top[#top+1]=tostring(read(object,"Name")).."["..tostring(read(object,"ClassName")).."]"
        end
        lines[#lines+1]="Avatar children="..table.concat(top,", ")
        local visualCount=0
        for _,object in ipairs(descendants(character)) do
            if visualCount>=32 then break end
            if isA(object,"Model") or isA(object,"Accessory") or isA(object,"MeshPart") or isA(object,"SpecialMesh") or isA(object,"Motor6D") or isA(object,"Weld") then
                visualCount=visualCount+1
                local mesh=read(object,"MeshId")
                lines[#lines+1]="Avatar object="..fullName(object).." ["..tostring(read(object,"ClassName")).."]"..(mesh and " MeshId="..tostring(mesh) or "")
            end
        end
        local resources=child(rs,"Resources")
        local resourceInfo={}
        for _,object in ipairs(children(resources)) do
            if #resourceInfo>=16 then break end
            resourceInfo[#resourceInfo+1]=tostring(read(object,"Name")).."["..tostring(read(object,"ClassName")).."]"
        end
        lines[#lines+1]="Loaded resources="..(resources and table.concat(resourceInfo,", ") or "missing")
        if lastAttempt then
            local source=resourceCache[lastAttempt.id]
            lines[#lines+1]="Resolved local resource="..(source and fullName(source) or "none")
        end
        local ps=service("Players");local current=read(ps,"LocalPlayer")
        for _,area in ipairs({"Character","Backpack"}) do
            for _,object in ipairs(descendants(read(current,area))) do
                if weaponTarget(object) then
                    local handle=weaponHandle(object)
                    lines[#lines+1]="Weapon target="..fullName(object).." class="..tostring(read(object,"ClassName")).." Handle="..tostring(handle and read(handle,"ClassName") or "missing")
                end
            end
        end
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
