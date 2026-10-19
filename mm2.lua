-- MM2 local discovery and cosmetic previews. It never calls remotes or unlocks items.
return function(game, injectedRequire, gunLibrary)
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
    local function findEntry(id,kind)
        if gunLibrary then for _,e in ipairs(gunLibrary.list(kind)) do if e.id==tostring(id) then return e end end end
        for _,e in ipairs(catalog(kind)) do if e.id==tostring(id) then return e end end
    end
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
    local enrichSaved
    local function inventoryEntry(e)
        if enrichSaved and field(e.definition,"PortableGun") then enrichSaved(e) end
        local def=e.catalog or e.definition
        local categoryName,year,event,rarity,sortOrder=metadata(def)
        categoryName=field(def,"Category") or categoryName
        local rarityColor,rarityOrder=rarityStyle(def)
        local chroma=field(def,"Chroma")
        return {id=e.id,name=e.customName and e.name or (e.catalog and e.catalog.Name or e.name),kind=e.kind,rarity=rarity,
            image=field(def,"Image") or field(def,"ImageId") or field(def,"ImageID"),
            visual=field(e.definition,"PortableGun") and e.definition or nil,previewOffset=e.previewOffset or 0,
            holdingRotation=e.holdingRotation or {X=0,Y=0,Z=0},adjustments=e.adjustments,
            category=categoryName,year=year,event=event,rarityColor=rarityColor,rarityOrder=rarityOrder,
            season=field(def,"Season"),sortOrder=sortOrder,chroma=chroma==true or (type(chroma)=="string" and lower(chroma)~="" and lower(chroma)~="false")}
    end
    function api.list(category,search)
        local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower() or nil; if kind~="Knife" and kind~="Gun" and kind~="Emote" then kind=nil end
        local source={}; if kind then for _,e in ipairs(catalog(kind)) do source[#source+1]=e end else for _,k in ipairs({"Knife","Gun","Emote"}) do for _,e in ipairs(catalog(k)) do source[#source+1]=e end end end
        local query,out=lower(search),{}
        for _,e in ipairs(source) do
            local item=inventoryEntry(e)
            if query=="" or lower(item.name):find(query,1,true) or lower(item.id):find(query,1,true) then out[#out+1]=item end
        end
        return out
    end
    function api.savedInventory(kind,search)
        local out={};local query=lower(search)
        for _,entry in ipairs(gunLibrary and gunLibrary.list(kind) or {}) do
            local item=inventoryEntry(entry)
            if query=="" or lower(item.name):find(query,1,true) then out[#out+1]=item end
        end
        return out
    end
    local snapshots,track = {},nil
    -- Saved knives use the local avatar's back by default.  The loader may
    -- switch this to the side layout through api.setKnifeSide.
    local knifeSide=false
    local toolPresentations={}
    local appearanceGeneration=0
    local equipped,pending,connections = {},{},{}
    local allowPending=false
    local watchersActive=false
    local observed,watchedCharacters={},{}
    local equipError,lastEquipResult
    local function disconnectAll()
        for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        connections={};watchersActive=false;observed={};watchedCharacters={}
    end
    local function connect(signal, fn)
        local method=signal and read(signal,"Connect")
        if type(method)=="function" then local ok,c=pcall(method,signal,fn); if ok and c then connections[#connections+1]=c; return c end end
    end
    local function set(o,k,v) if not o then return false end; local ok=pcall(function() o[k]=v end); return ok and (v==nil or read(o,k)~=nil) end
    local function toolKind(t)
        local text=lower(read(t,"Name")); return text:find("gun",1,true) and "Gun" or (text:find("knife",1,true) or text:find("weapon",1,true)) and "Knife"
    end
    local function referenceKind(object)
        if not isA(object,"ObjectValue") then return nil end
        local name=lower(read(object,"Name")); return name=="displayrefgun" and "Gun" or name=="displayrefknife" and "Knife"
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
    local function displayReference(expected)
        local ps=service("Players");local p=ps and read(ps,"LocalPlayer");local character=p and read(p,"Character")
        for _,reference in ipairs(children(character)) do
            if referenceKind(reference)==expected then
                local target=read(reference,"Value");local handle=weaponHandle(target)
                return reference,target,handle
            end
        end
    end
    local function targetTool(expected)
        local reference,target,referenceHandle=displayReference(expected)
        if referenceHandle then return target,referenceHandle,reference end
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
    local assetCache,assetRoots,assetFailures,resourceCache,assetLoaders,loadedVisualCache={},{},{},{},{},{}
    local loadedLookupLog={}
    local lastAttempt
    local function itemAsset(assetId)
        local id=tonumber(assetId)
        assert(id and id>0 and id%1==0,"The item has an invalid ItemID asset.")
        local key=tostring(id)
        if assetCache[key] then return assetCache[key] end
        if assetFailures[key] then error(assetFailures[key]) end
        local generation=appearanceGeneration
        local ok,objects=pcall(function() return game:GetObjects("rbxassetid://"..string.format("%.0f",id)) end)
        if not alive or generation~=appearanceGeneration then
            if ok and type(objects)=="table" then for _,root in ipairs(objects) do pcall(function() root:Destroy() end) end end
            error("MM2 cosmetic loading cancelled.")
        end
        if not ok or type(objects)~="table" or #objects==0 then
            local reason=ok and type(objects)=="table" and "GetObjects returned no objects" or tostring(objects)
            local message="ItemID "..key..": "..reason..". Avatar model unavailable on this client."
            assetFailures[key]=message;assetLoaders[key]=message;error(message)
        end
        assetLoaders[key]="GetObjects"
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
    local identityKeys={itemkey=true,itemid=true,itemname=true,weaponid=true}
    local function identityValue(object)
        local values={}
        local attributes=read(object,"GetAttributes")
        if type(attributes)=="function" then local ok,result=pcall(attributes,object);if ok and type(result)=="table" then for key,value in pairs(result) do if identityKeys[lower(key)] then values[#values+1]=value end end end end
        for _,childObject in ipairs(children(object)) do if identityKeys[lower(read(childObject,"Name"))] then values[#values+1]=read(childObject,"Value") end end
        return values
    end
    local function identitySummary(object)
        local values=identityValue(object);local out={}
        for _,value in ipairs(values) do out[#out+1]=tostring(value) end
        return #out>0 and table.concat(out,"|") or "none"
    end
    local function exactLoadedIdentity(object,entry)
        if tostring(read(object,"Name"))==tostring(entry.id) then return true,"Name="..tostring(entry.id) end
        local itemId=field(entry.definition,"ItemID")
        local itemIdMatches=0
        if itemId then for _,candidate in ipairs(catalog(entry.kind)) do if tostring(field(candidate.definition,"ItemID"))==tostring(itemId) then itemIdMatches=itemIdMatches+1 end end end
        for _,value in ipairs(identityValue(object)) do
            if tostring(value)==tostring(entry.id) then return true,"identity="..tostring(value) end
            if itemId and itemIdMatches==1 and tostring(value)==tostring(itemId) then return true,"ItemID="..tostring(value) end
        end
    end
    local function loadedVisual(entry)
        local cacheKey=entry.kind..":"..entry.id
        if loadedVisualCache[cacheKey] then return loadedVisualCache[cacheKey] end
        local candidates,seen={},{}
        local function add(object,reference)
            if object and not seen[object] then seen[object]=true;candidates[#candidates+1]={object=object,reference=reference} end
        end
        local displays=child(service("Workspace"),"WeaponDisplays")
        add(displays)
        for _,object in ipairs(descendants(displays)) do add(object) end
        local players=service("Players");local getPlayers=read(players,"GetPlayers")
        if type(getPlayers)=="function" then
            local ok,list=pcall(getPlayers,players)
            if ok and type(list)=="table" then for _,player in ipairs(list) do
                local character=read(player,"Character")
                for _,reference in ipairs(children(character)) do if referenceKind(reference)==entry.kind then add(read(reference,"Value"),reference) end end
            end end
        end
        for _,candidate in ipairs(candidates) do
            local object,reference=candidate.object,candidate.reference
            if #loadedLookupLog<24 then loadedLookupLog[#loadedLookupLog+1]="inspect "..tostring(read(object,"Name")).." identities="..identitySummary(reference).."/"..identitySummary(object) end
            local matched,reason=exactLoadedIdentity(reference,entry)
            if not matched then matched,reason=exactLoadedIdentity(object,entry) end
            local handle=weaponHandle(object)
            if matched and handle and not snapshots[handle] then
                local cloneFn=read(handle,"Clone");local ok,clone=false,nil
                if type(cloneFn)=="function" then ok,clone=pcall(cloneFn,handle) end
                if ok and clone and weaponHandle(clone) then clone=weaponHandle(clone) end
                if ok and clone and isA(clone,"BasePart") then
                    for _,desc in ipairs(descendants(clone)) do if isA(desc,"LuaSourceContainer") then pcall(function() desc:Destroy() end) end end
                    assetRoots[#assetRoots+1]=clone;loadedVisualCache[cacheKey]=clone
                    loadedLookupLog[#loadedLookupLog+1]=entry.kind.." "..entry.id.." <- "..tostring(read(object,"Name")).." ("..tostring(reason)..")"
                    return clone
                end
            end
        end
        if #loadedLookupLog<24 then loadedLookupLog[#loadedLookupLog+1]=entry.kind.." "..entry.id.." <- no exact loaded source" end
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
        if not h and entry then h=loadedVisual(entry) or resourceVisual(entry) end
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
        if old.chromaConnection then old.chromaConnection:Disconnect();old.chromaConnection=nil end
        if old.overlay then pcall(function() old.overlay:Destroy() end);old.overlay=nil end
        if old.marker then pcall(function() old.marker:Destroy() end);old.marker=nil end
        old.restoring=true
        for part,value in pairs(old.hidden or {}) do set(part,"LocalTransparencyModifier",value) end
        old.hidden=nil
        if old.localTransparency~=nil then set(old.handle,"LocalTransparencyModifier",old.localTransparency) end
        if old.sourceClone then
            pcall(function() old.handle:ApplyMesh(old.sourceClone) end)
            pcall(function() old.sourceClone:Destroy() end)
            old.sourceClone=nil
        end
        set(old.mesh,"MeshId",old.meshId);set(old.mesh,"TextureId",old.textureId)
        set(old.mesh,"Scale",old.scale);set(old.mesh,"MeshType",old.meshType)
        set(old.handle,"Color",old.color);set(old.handle,"Material",old.material)
        set(old.handle,"Size",old.size)
    end
    local function restoreToolPresentation(tool,old)
        old.restoring=true
        if old.icon~=nil then set(tool,"TextureId",old.icon) end
        for sound,values in pairs(old.sounds) do for key,value in pairs(values) do set(sound,key,value) end end
    end
    local function applyToolPresentation(tool,e)
        if not isA(tool,"Tool") then return end
        local old=toolPresentations[tool]
        if old and (old.id~=e.id or old.revision~=(e.revision or 0)) then restoreToolPresentation(tool,old);toolPresentations[tool]=nil;old=nil end
        local presentation=e.definition.Presentation
        if not presentation then return end
        if not old then
            old={id=e.id,revision=e.revision or 0,icon=read(tool,"TextureId"),sounds={}}
            toolPresentations[tool]=old
            local changed=read(tool,"GetPropertyChangedSignal")
            if presentation.ToolIcon and type(changed)=="function" then
                connect(changed(tool,"TextureId"),function()
                    if not old.restoring and toolPresentations[tool]==old and read(tool,"TextureId")~=presentation.ToolIcon then
                        old.icon=read(tool,"TextureId");set(tool,"TextureId",presentation.ToolIcon)
                    end
                end)
            end
        end
        if presentation.ToolIcon then set(tool,"TextureId",presentation.ToolIcon) end
        for _,record in ipairs(presentation.Sounds or {}) do
            local sound=tool
            for _,name in ipairs(record.Path) do sound=child(sound,name);if not sound then break end end
            if not isA(sound,"Sound") then
                sound=nil
                for _,candidate in ipairs(descendants(tool)) do
                    if isA(candidate,"Sound") and read(candidate,"Name")==record.Name then
                        if sound then sound=nil;break end
                        sound=candidate
                    end
                end
            end
            if sound and not old.sounds[sound] then
                local values={};old.sounds[sound]=values
                for key,value in pairs(record.Properties or {}) do
                    values[key]=read(sound,key)
                    set(sound,key,value)
                    local changed=read(sound,"GetPropertyChangedSignal")
                    if type(changed)=="function" then connect(changed(sound,key),function()
                        if not old.restoring and toolPresentations[tool]==old and read(sound,key)~=value then
                            values[key]=read(sound,key);set(sound,key,value)
                        end
                    end) end
                end
            end
        end
    end
    local function weaponAdjustment(entry,held)
        local source=entry.adjustments and entry.adjustments[held and "Held" or "Holster"]
        local function axis(vector,name,fallback)
            local value=vector and vector[name]
            return type(value)=="number" and value or fallback
        end
        return {
            Position=Vector3.new(axis(source and source.Position,"X",0),axis(source and source.Position,"Y",0),axis(source and source.Position,"Z",0)),
            Rotation=Vector3.new(axis(source and source.Rotation,"X",0),axis(source and source.Rotation,"Y",0),axis(source and source.Rotation,"Z",0)),
            Scale=Vector3.new(axis(source and source.Scale,"X",1),axis(source and source.Scale,"Y",1),axis(source and source.Scale,"Z",1))
        }
    end
    local function scaledVector(value,scale)
        return Vector3.new(value.X*scale.X,value.Y*scale.Y,value.Z*scale.Z)
    end
    local function resolveSavedPlacement(handle,e,held,tool,character)
        local kind=e.kind or "Gun"
        local def=e.definition
        local mount=def.Mounts and def.Mounts[held and "Held" or "Holster"]
        if kind=="Knife" and not held and knifeSide then
            local lowerTorso=child(character,"LowerTorso") or child(character,"Torso")
            local belt=child(lowerTorso,"KnifeBelt")
            if lowerTorso and isA(belt,"Attachment") then
                mount={Part=read(lowerTorso,"Name"),Offset=read(belt,"CFrame")}
            elseif lowerTorso and mount and mount.Part==read(lowerTorso,"Name") and mount.Offset and mount.Offset.X<0 and mount.Offset.Y<0 and math.abs(mount.Offset.X)>math.abs(mount.Offset.Z) then
                -- Retain an actual belt mount already captured with this saved knife.
            elseif lowerTorso then
                -- Native MM2 KnifeBelt transform measured from live R15 joints (V13 report).
                -- This is the game's belt orientation, not an estimated Euler angle.
                mount={Part=read(lowerTorso,"Name"),Offset=CFrame.new(-0.735001147,-0.540000021,0.212500006,
                    -0.998995066,0.0298198294,0.033461079,
                    0.0136284996,-0.509110212,0.860593498,
                    0.0426981226,0.860184669,0.508192182)}
            end
        end
        if kind=="Knife" and not held and not knifeSide then
            -- A donor's display rotation can point the blade out of our torso.
            -- Put the thin axis against the body and the long axis upright.
            local torso=child(character,"UpperTorso") or child(character,"Torso") or child(character,"LowerTorso")
            if torso then
                local bodySize=read(torso,"Size") or Vector3.new(2,2,1)
                local size=def.Size or Vector3.new(0.2,2,0.2)
                local dimensions={size.X,size.Y,size.Z}
                local thin,long=1,1
                for i=2,3 do
                    if dimensions[i]<dimensions[thin] then thin=i end
                    if dimensions[i]>dimensions[long] then long=i end
                end
                if long==thin then long=thin==2 and 3 or 2 end
                local remaining=6-thin-long
                local columns={}
                columns[thin]={0,0,1}
                local angle=math.rad(30)
                columns[long]={math.sin(angle),math.cos(angle),0}
                local a,b=columns[remaining%3+1],columns[(remaining+1)%3+1]
                columns[remaining]={a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}
                local rotation=CFrame.new(0,0,0,
                    columns[1][1],columns[2][1],columns[3][1],
                    columns[1][2],columns[2][2],columns[3][2],
                    columns[1][3],columns[2][3],columns[3][3])
                local half=dimensions[thin]/2
                local x=0
                local y=0
                local z=bodySize.Z/2+half+0.03
                local offset=CFrame.new(x,y,z)*rotation
                -- SpecialMesh.Offset translates its visible center away from its Part.
                local meshOffset=def.Offset
                if meshOffset then offset=offset*CFrame.new(-meshOffset.X,-meshOffset.Y,-meshOffset.Z) end
                mount={Part=read(torso,"Name"),Offset=offset}
            end
        end
        local anchor=mount and child(character,mount.Part)
        local offset=anchor and mount.Offset
        anchor=anchor or handle
        local grip=held and def.Presentation and def.Presentation.Grip
        if not offset and grip and read(tool,"Grip") then
            local ok,relative=pcall(function()return tool.Grip*grip:Inverse()end)
            if ok then anchor=handle;offset=relative end
        end
        if kind=="Gun" and not held then
            local torso=child(character,"LowerTorso") or child(character,"Torso") or child(character,"UpperTorso")
            if torso then
                -- Use our native holster location, not the donor's body dimensions.
                local native=torso.CFrame:ToObjectSpace(handle.CFrame)
                local captured=torso.CFrame:ToObjectSpace(offset and anchor.CFrame*offset or handle.CFrame)
                local components={captured:GetComponents()}
                local placement=CFrame.new(native.X,native.Y,native.Z,table.unpack(components,4,12))
                local minX,maxX=math.huge,-math.huge
                local function bounds(visual,relative)
                    if (visual.Transparency or 0)>=1 then return end
                    local size=visual.Size
                    if not size then return end
                    local frame=placement*relative
                    local center=frame
                    local shift=visual.Offset
                    if shift then center=frame*CFrame.new(shift.X,shift.Y,shift.Z) end
                    local r={frame:GetComponents()}
                    local half=(math.abs(r[4])*size.X+math.abs(r[5])*size.Y+math.abs(r[6])*size.Z)/2
                    minX=math.min(minX,center.X-half);maxX=math.max(maxX,center.X+half)
                end
                bounds(def,CFrame.new())
                for _,part in ipairs(def.Parts or {}) do bounds(part,part.RelativeCFrame) end
                local correction=0
                local bodySize=read(torso,"Size")
                if bodySize and minX~=math.huge then
                    local edge=bodySize.X/2+0.03
                    correction=native.X>=0 and math.max(0,edge-minX) or math.min(0,-edge-maxX)
                end
                mount={Part=read(torso,"Name"),Offset=CFrame.new(correction,0,0)*placement}
                anchor=torso;offset=mount.Offset
            end
        end
        return anchor,offset,mount
    end
    local function applySavedGun(handle,e,held,tool,previewCharacter)
        local kind=e.kind or "Gun"
        assert(handle,"Your "..kind:lower().." display has not loaded yet.")
        local old=not previewCharacter and snapshots[handle]
        if old and old.overlay and old.overlayId==e.id and old.overlayRevision==(e.revision or 0) and read(old.overlay,"Parent") then return end
        if old then restoreHandle(old);snapshots[handle]=nil end
        local p=read(service("Players"),"LocalPlayer")
        local character=previewCharacter or read(p,"Character")
        local def=e.definition
        local anchor,offset,mount=resolveSavedPlacement(handle,e,held,tool,character)
        local overlay=Instance.new("Part")
        local ok,message=pcall(function()
            overlay.Name=kind=="Gun" and "HoneyBunSavedGun" or "HoneyBunSavedKnife"
            local adjustment=weaponAdjustment(e,held)
            overlay.Size=scaledVector(def.Size or Vector3.new(1,1,1),adjustment.Scale)
            local baseCFrame=offset and anchor.CFrame*offset or handle.CFrame
            -- Position is expressed in the anchor's local axes, followed by local rotation.
            if adjustment.Position.X~=0 or adjustment.Position.Y~=0 or adjustment.Position.Z~=0 then baseCFrame=anchor.CFrame*CFrame.new(adjustment.Position.X,adjustment.Position.Y,adjustment.Position.Z)*anchor.CFrame:ToObjectSpace(baseCFrame) end
            if adjustment.Rotation.X~=0 or adjustment.Rotation.Y~=0 or adjustment.Rotation.Z~=0 then baseCFrame=baseCFrame*CFrame.Angles(math.rad(adjustment.Rotation.X),math.rad(adjustment.Rotation.Y),math.rad(adjustment.Rotation.Z)) end
            overlay.CFrame=baseCFrame
            overlay.Anchored=false;overlay.Massless=true
            overlay.CanCollide=false;overlay.CanTouch=false;overlay.CanQuery=false
            overlay.Color=def.Color or handle.Color
            overlay.Material=def.Material or handle.Material
            overlay.Transparency=def.Transparency or (not previewCharacter and read(handle,"Transparency")) or 0
            overlay.LocalTransparencyModifier=read(handle,"LocalTransparencyModifier") or 0
            local mesh=Instance.new("SpecialMesh")
            mesh.MeshType=Enum.MeshType.FileMesh
            -- Portable Part meshes use the original surface color map as their diffuse texture.
            mesh.MeshId=def.MeshId;mesh.TextureId=(def.SurfaceAppearance and def.SurfaceAppearance.ColorMap) or def.TextureId or ""
            mesh.Scale=scaledVector(def.Scale or Vector3.new(1,1,1),adjustment.Scale)
            mesh.Offset=scaledVector(def.Offset or Vector3.new(0,0,0),adjustment.Scale)
            if def.VertexColor then mesh.VertexColor=def.VertexColor end
            mesh.Parent=overlay
            local weld=Instance.new("WeldConstraint")
            weld.Part0=anchor;weld.Part1=overlay;weld.Parent=overlay
            old={handle=handle,kind=kind,mount=mount,held=held,tool=tool,color=read(handle,"Color"),material=read(handle,"Material"),size=read(handle,"Size"),localTransparency=read(handle,"LocalTransparencyModifier") or 0,overlay=overlay,overlayId=e.id,overlayRevision=e.revision or 0,hidden={}}
            if not previewCharacter then snapshots[handle]=old end
            local chromaParts={}
            if def.Chroma then chromaParts[#chromaParts+1]=overlay end
            for index,visual in ipairs(def.Parts or {}) do
                local part=Instance.new("Part")
                -- Parent immediately so failure/restore destroys the entire assembly.
                part.Name="SavedWeaponDetail_"..index;part.Parent=overlay
                part.Size=scaledVector(visual.Size,adjustment.Scale);part.Color=visual.Color;part.Material=visual.Material or overlay.Material
                part.Transparency=visual.Transparency or 0
                part.LocalTransparencyModifier=overlay.LocalTransparencyModifier
                local relative=visual.RelativeCFrame or CFrame.new()
                local relativePosition=relative.Position or Vector3.new(0,0,0)
                local sameScale=adjustment.Scale.X==1 and adjustment.Scale.Y==1 and adjustment.Scale.Z==1
                if sameScale then
                    part.CFrame=overlay.CFrame*relative
                else
                    local components={relative:GetComponents()}
                    local pos=scaledVector(relativePosition,adjustment.Scale)
                    part.CFrame=overlay.CFrame*CFrame.new(pos.X,pos.Y,pos.Z,table.unpack(components,4,12))
                end
                part.Anchored=false;part.Massless=true
                part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
                local detail=Instance.new("SpecialMesh",part)
                detail.MeshType=Enum.MeshType.FileMesh;detail.MeshId=visual.MeshId
                detail.TextureId=(visual.SurfaceAppearance and visual.SurfaceAppearance.ColorMap) or visual.TextureId or ""
                detail.Scale=scaledVector(visual.Scale or Vector3.new(1,1,1),adjustment.Scale);detail.Offset=scaledVector(visual.Offset or Vector3.new(0,0,0),adjustment.Scale);detail.VertexColor=visual.VertexColor
                local joint=Instance.new("WeldConstraint",part)
                joint.Part0=overlay;joint.Part1=part
                if visual.Chroma then chromaParts[#chromaParts+1]=part end
            end
            if previewCharacter then
                overlay.Parent=previewCharacter;overlay.Anchored=true;overlay.LocalTransparencyModifier=0
                if type(read(Color3,"fromHSV"))=="function" then for _,part in ipairs(chromaParts) do part.Color=Color3.fromHSV(0,1,1) end end
                for _,object in ipairs(descendants(overlay)) do
                    if isA(object,"WeldConstraint") then object:Destroy()
                    elseif isA(object,"BasePart") then object.Anchored=true;object.LocalTransparencyModifier=0 end
                end
                return overlay
            end
            if #chromaParts>0 then
                local phase,elapsed=0,0
                local function tint()
                    local color=Color3.fromHSV(phase,1,1)
                    for _,part in ipairs(chromaParts) do part.Color=color end
                end
                tint()
                local heartbeat=read(service("RunService"),"Heartbeat")
                if heartbeat and type(read(heartbeat,"Connect"))=="function" then
                    old.chromaConnection=heartbeat:Connect(function(dt)
                        if old.restoring or snapshots[handle]~=old then return end
                        phase=(phase+dt/6)%1;elapsed=elapsed+dt
                        if elapsed>=1/30 then elapsed=0;tint() end
                    end)
                end
            end
            -- A separate static visual preserves its dimensions without changing game joints or tools.
            overlay.Parent=service("Workspace")
            local marker=Instance.new("ObjectValue")
            marker.Name="HoneyBunCosmeticVisual";marker.Value=overlay;marker.Parent=handle;old.marker=marker
            local function hide(part)
                if old.restoring or snapshots[handle]~=old then return end
                if not isA(part,"BasePart") or old.hidden[part]~=nil then return end
                old.hidden[part]=read(part,"LocalTransparencyModifier") or 0
                local changing=false
                local changed=read(part,"GetPropertyChangedSignal")
                if type(changed)=="function" then connect(changed(part,"LocalTransparencyModifier"),function()
                    if changing or old.restoring or snapshots[handle]~=old then return end
                    -- Camera/game visibility refreshes must not expose the original gun.
                    if part==handle and old.overlay then
                        old.overlay.LocalTransparencyModifier=part.LocalTransparencyModifier
                        for _,detail in ipairs(children(old.overlay)) do if isA(detail,"BasePart") then detail.LocalTransparencyModifier=part.LocalTransparencyModifier end end
                    end
                    changing=true;part.LocalTransparencyModifier=1;changing=false
                end) end
                changing=true;part.LocalTransparencyModifier=1;changing=false
            end
            hide(handle);for _,part in ipairs(descendants(handle)) do hide(part) end
            connect(read(handle,"DescendantAdded"),hide)
            local changed=read(handle,"GetPropertyChangedSignal")
            if type(changed)=="function" then connect(changed(handle,"Transparency"),function()
                if snapshots[handle]==old and old.overlay then old.overlay.Transparency=handle.Transparency end
            end) end
            connect(read(handle,"Destroying"),function()
                if snapshots[handle]==old then restoreHandle(old);snapshots[handle]=nil end
            end)
        end)
        if not ok then
            if old and snapshots[handle]==old then restoreHandle(old);snapshots[handle]=nil else overlay:Destroy() end
            error("Could not show saved "..kind:lower()..": "..tostring(message))
        end
        return overlay
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
        local handle
        if selectedTool then
            local referenceKindValue=referenceKind(selectedTool)
            if referenceKindValue then assert(referenceKindValue==kind,"Matching native weapon is required.");handle=weaponHandle(read(selectedTool,"Value"))
            else assert(weaponTarget(selectedTool) and toolKind(selectedTool)==kind,"Matching native weapon is required.");handle=weaponHandle(selectedTool) end
        else local _,targetHandle=targetTool(kind);handle=targetHandle end
        if not handle and allowPending then
            pending[kind]=e.id;equipped[kind]=e.id
            return "Queued "..kind:lower().." locally: "..e.name.." (waiting for your matching weapon)"
        end
        if field(e.definition,"PortableGun") then
            local tool=selectedTool
            if not tool then local target=targetTool(kind);tool=target end
            local held=isA(tool,"Tool")
            applyToolPresentation(tool,e)
            if held and read(tool,"Parent")~=read(read(service("Players"),"LocalPlayer"),"Character") then
                if snapshots[handle] then restoreHandle(snapshots[handle]);snapshots[handle]=nil end
                return "Saved "..kind:lower().." selected; draw your real "..kind:lower().." to use this appearance."
            end
            applySavedGun(handle,e,held,tool)
            equipped[kind]=e.id;pending[kind]=nil
            local message="Previewing saved "..kind:lower().." locally: "..e.name
            if held and not (e.definition.Mounts and e.definition.Mounts.Held) and not (e.definition.Presentation and e.definition.Presentation.Grip) then
                message=message..". Held grip was not saved; copy again while the owner holds it."
            end
            return message
        end
        if snapshots[handle] and snapshots[handle].overlay then restoreHandle(snapshots[handle]);snapshots[handle]=nil end
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
            old={handle=handle,mesh=mesh,meshId=read(mesh,"MeshId"),textureId=read(mesh,"TextureId"),scale=read(mesh,"Scale"),meshType=read(mesh,"MeshType"),color=read(handle,"Color"),material=read(handle,"Material"),size=read(handle,"Size"),sourceClone=nil}
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
            if read(source,"Size") then set(handle,"Size",read(source,"Size")) end
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
            local generation=appearanceGeneration
            local ok,message=pcall(api.preview,id,kind,tool)
            if not alive or generation~=appearanceGeneration or equipped[kind]~=id then return end
            if not ok then pending[kind]=id;equipError=tostring(message) else equipError=nil end
        end
    end
    local function applyToReference(reference)
        if not alive then return end
        local kind=referenceKind(reference);local id=kind and equipped[kind]
        if id and weaponHandle(read(reference,"Value")) then
            local generation=appearanceGeneration
            local ok,message=pcall(api.preview,id,kind,reference)
            if not alive or generation~=appearanceGeneration or equipped[kind]~=id then return end
            if not ok then pending[kind]=id;equipError=tostring(message) else equipError=nil end
        end
    end
    local function watchReference(reference)
        if not referenceKind(reference) then return end
        if not observed[reference] then
            observed[reference]=true
            local changed=read(reference,"GetPropertyChangedSignal")
            if type(changed)=="function" then connect(changed(reference,"Value"),function() applyToReference(reference) end) end
        end
        applyToReference(reference)
    end
    local function watchReferences(character)
        for _,reference in ipairs(children(character)) do watchReference(reference) end
    end
    local function watchTool(tool)
        if not weaponTarget(tool) or not toolKind(tool) then return end
        if not observed[tool] then
            observed[tool]=true
            connect(read(tool,"DescendantAdded"),function() applyToTool(tool) end)
            connect(read(tool,"ChildAdded"),function() applyToTool(tool) end)
            connect(read(tool,"AncestryChanged"),function() applyToTool(tool) end)
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
    local function watchCharacter(character)
        if not character then return end
        watchContainer(character);watchReferences(character)
        if not watchedCharacters[character] then
            watchedCharacters[character]=true
            connect(read(character,"ChildAdded"),watchReference)
        end
    end
    local function ensureWatchers()
        local ps=service("Players");local p=read(ps,"LocalPlayer")
        if not watchersActive then
            watchersActive=true
            connect(read(p,"CharacterAdded"),watchCharacter)
            connect(read(p,"ChildAdded"),function(o) if isA(o,"Backpack") then watchContainer(o) end end)
        end
        watchCharacter(read(p,"Character"));watchContainer(read(p,"Backpack"))
    end
    function api.equip(id,category)
        assert(alive,"The MM2 cosmetic preview is closed.")
        local kind=category and tostring(category):sub(1,1):upper()..tostring(category):sub(2):lower(); assert(kind=="Gun" or kind=="Knife","Equip category must be Knife or Gun.")
        local e=findEntry(id,kind); assert(e,"Unsupported "..kind:lower().." cosmetic: "..tostring(id))
        for tool,old in pairs(toolPresentations) do
            if toolKind(tool)==kind and old.id~=e.id then restoreToolPresentation(tool,old);toolPresentations[tool]=nil end
        end
        if gunLibrary then gunLibrary.select(field(e.definition,"PortableGun") and e.id or nil,kind) end
        lastAttempt={id=e.id,kind=kind,definition=e.definition}
        local generation=appearanceGeneration
        equipped[kind]=e.id;pending[kind]=e.id
        allowPending=true; local ok,result=pcall(api.preview,e.id,kind); allowPending=false
        if not alive or generation~=appearanceGeneration then return "MM2 cosmetic selection cancelled." end
        if not ok then
            equipError=tostring(result);ensureWatchers();equipError=tostring(result)
            lastEquipResult="Selected "..e.name.."; avatar preview unavailable: "..equipError
            return lastEquipResult
        end
        equipError=nil;lastEquipResult=result
        ensureWatchers()
        return result
    end
    function api.getEquipped()
        return {Knife=equipped.Knife,Gun=equipped.Gun}
    end
    function api.getKnifeSide()
        return knifeSide
    end
    function api.setKnifeSide(value)
        knifeSide=value==true
        -- Rebuild only the saved knife overlay.  Held tools and saved guns
        -- retain their existing presentation and grip.
        local knifeId=equipped.Knife
        for handle,old in pairs(snapshots) do
            if old.kind=="Knife" then restoreHandle(old);snapshots[handle]=nil end
        end
        if knifeId then
            pending.Knife=knifeId
            local ok,result=pcall(api.preview,knifeId,"Knife")
            if not ok then equipError=tostring(result);return false,equipError end
            pending.Knife=nil
            equipError=nil
            lastEquipResult=result
        end
        return knifeSide
    end
    function api.savedWeapons(kind) return gunLibrary and gunLibrary.list(kind) or {} end
    function api.savedGuns() return api.savedWeapons("Gun") end
    function api.getWeaponEditorScene(id,mode)
        assert(alive and gunLibrary,"The saved weapon library is unavailable.")
        assert(mode=="Holster" or mode=="Held","Weapon editor mode must be Holster or Held.")
        local entry
        for _,saved in ipairs(gunLibrary.list()) do if saved.id==id then entry=saved;break end end
        assert(entry,"Saved weapon was not found.")
        local player=read(service("Players"),"LocalPlayer");local live=read(player,"Character")
        assert(live,"Your character is not available for preview.")
        local archivable=live.Archivable;live.Archivable=true
        local cloned,character=pcall(function()return live:Clone()end);live.Archivable=archivable
        assert(cloned and character,"Your character could not be cloned for preview.")
        local ok,result=pcall(function()
            for _,object in ipairs(descendants(character)) do
                local name=lower(read(object,"Name"))
                if name:find("displayref",1,true) then
                    local target=read(object,"Value")
                    if target and type(read(target,"IsDescendantOf"))=="function" and target:IsDescendantOf(character) then target:Destroy() end
                    object:Destroy()
                elseif isA(object,"LuaSourceContainer") or isA(object,"Tool") or name=="honeybunsavedgun" or name=="honeybunsavedknife" then object:Destroy()
                elseif isA(object,"BasePart") then object.Anchored=true;object.LocalTransparencyModifier=0 end
            end
            local torso=child(character,"UpperTorso") or child(character,"Torso") or child(character,"LowerTorso")
            assert(torso,"Your avatar has no usable torso.")
            local held=mode=="Held"
            local hand=child(character,"RightHand") or child(character,"Right Arm")
            if held then
                -- Bake the stock ToolNone arm pose into the preview clone. The
                -- avatar stays anchored, so an Animator cannot pull it out of pose.
                local shoulder
                for _,joint in ipairs(descendants(character)) do
                    if isA(joint,"Motor6D") and (joint.Name=="RightShoulder" or joint.Name=="Right Shoulder") then shoulder=joint;break end
                end
                if shoulder and shoulder.Part0 and shoulder.Part1 then
                    -- Rotate forward around the torso's right axis, not the
                    -- shoulder joint's local axis (which varies between rigs).
                    local pivot=torso.CFrame:ToObjectSpace(shoulder.Part0.CFrame*shoulder.C0)
                    local _,_,_,r00,r01,r02,r10,r11,r12,r20,r21,r22=pivot:GetComponents()
                    local basis=CFrame.new(0,0,0,r00,r01,r02,r10,r11,r12,r20,r21,r22)
                    local inverseBasis=CFrame.new(0,0,0,r00,r10,r20,r01,r11,r21,r02,r12,r22)
                    local pose=inverseBasis*CFrame.Angles(math.pi/2,0,0)*basis
                    local joints=descendants(character)
                    local visited={}
                    local function poseBranch(joint,transform)
                        local part=joint.Part1
                        if not part or visited[part] then return end
                        visited[part]=true
                        part.CFrame=joint.Part0.CFrame*joint.C0*transform*joint.C1:Inverse()
                        if isA(joint,"Motor6D") then joint.Transform=transform end
                        for _,nextJoint in ipairs(joints) do
                            if (isA(nextJoint,"Motor6D") or isA(nextJoint,"Weld")) and read(nextJoint,"Part0")==part then poseBranch(nextJoint,CFrame.new()) end
                        end
                    end
                    poseBranch(shoulder,pose)
                end
            end
            -- WorldModel evaluates avatar joints even without animation scripts.
            -- Keep the baked preview pose instead of solving back to the idle rig.
            for _,joint in ipairs(descendants(character)) do
                if isA(joint,"Motor6D") or isA(joint,"Weld") then joint.Enabled=false end
            end
            local function matchingTool(parent)
                for _,candidate in ipairs(children(parent)) do if isA(candidate,"Tool") and toolKind(candidate)==entry.kind then return candidate end end
            end
            local drawnTool=matchingTool(live)
            local tool=drawnTool or matchingTool(read(player,"Backpack"))
            local native=held and tool and child(tool,"Handle")
            if not native then local ref=child(live,"DisplayRef"..entry.kind);native=ref and read(ref,"Value") end
            local handle=Instance.new("Part");handle.Name="HoneyBunEditorAnchor";handle.Transparency=1;handle.Anchored=true;handle.CanCollide=false
            handle.Size=native and native.Size or Vector3.new(1,1,1)
            handle.CFrame=native and native.CFrame or torso.CFrame
            if held and hand then
                local liveHand=child(live,"RightHand") or child(live,"Right Arm")
                if drawnTool and native and liveHand then
                    handle.CFrame=hand.CFrame*liveHand.CFrame:ToObjectSpace(native.CFrame)
                else
                    local attachment=child(hand,"RightGripAttachment")
                    local grip=tool and read(tool,"Grip")
                    handle.CFrame=hand.CFrame*(attachment and attachment.CFrame or CFrame.new())*(grip and grip:Inverse() or CFrame.new())
                end
            end
            handle.Parent=character
            local weapon=applySavedGun(handle,entry,held,tool,character)
            local focus=read(torso.CFrame,"Position") or Vector3.new(torso.CFrame.X,torso.CFrame.Y,torso.CFrame.Z)
            local axisAnchor=resolveSavedPlacement(handle,entry,held,tool,character)
            return {character=character,weapon=weapon,focus=focus,axisFrame=axisAnchor.CFrame,update=function()
                if weapon then weapon:Destroy() end
                weapon=applySavedGun(handle,entry,held,tool,character)
                return weapon
            end}
        end)
        if not ok then character:Destroy();error(result) end
        return result
    end
    function api.setSavedPreviewOffset(id,value)
        assert(alive and gunLibrary,"The saved weapon library is unavailable.")
        gunLibrary.setPreviewOffset(id,value)
        return "Saved weapon preview position."
    end
    function api.setSavedHoldingRotation(id,value)
        assert(alive and gunLibrary,"The saved weapon library is unavailable.")
        gunLibrary.setHoldingRotation(id,value)
        for _,entry in ipairs(gunLibrary.list()) do
            if entry.id==id and equipped[entry.kind]==id then
                pcall(api.preview,id,entry.kind)
                break
            end
        end
        return "Saved held rotation."
    end
    function api.setSavedWeaponAdjustment(id,mode,transform,persist)
        assert(alive and gunLibrary,"The saved weapon library is unavailable.")
        gunLibrary.setWeaponAdjustment(id,mode,transform,persist)
        local entry
        for _,saved in ipairs(gunLibrary.list()) do if saved.id==id then entry=saved;break end end
        local targets={}
        for handle,old in pairs(snapshots) do if old.overlayId==id then targets[#targets+1]={handle=handle,held=old.held,tool=old.tool} end end
        for _,target in ipairs(targets) do pcall(applySavedGun,target.handle,entry,target.held,target.tool) end
        return "Saved "..tostring(mode):lower().." weapon adjustment."
    end
    function api.renameSavedWeapon(id,name)
        assert(alive and gunLibrary,"The saved weapon library is unavailable.")
        local entry=gunLibrary.rename(id,name)
        return "Renamed saved "..entry.kind:lower().." to: "..entry.name
    end
    function api.removeSavedWeapon(id)
        assert(alive and gunLibrary,"The saved weapon library is unavailable.")
        local entry=gunLibrary.remove(id)
        local kind=entry.kind
        if equipped[kind]==id or pending[kind]==id then
            appearanceGeneration=appearanceGeneration+1
            equipped[kind]=nil;pending[kind]=nil
        end
        for handle,old in pairs(snapshots) do
            if old.overlayId==id then restoreHandle(old);snapshots[handle]=nil end
        end
        for tool,old in pairs(toolPresentations) do
            if old.id==id then restoreToolPresentation(tool,old);toolPresentations[tool]=nil end
        end
        return "Deleted saved "..kind:lower()..": "..(entry.customName and entry.name or (entry.catalog and entry.catalog.Name or entry.name))
    end
    local function captureGunMount(source,character,held)
        if not source then return nil end
        local anchor
        local function bodyPart(object)
            while object and object~=character do
                if isA(object,"BasePart") and child(character,read(object,"Name"))==object then return object end
                object=read(object,"Parent")
            end
        end
        for _,constraint in ipairs(descendants(source)) do
            for _,key in ipairs({"Attachment0","Attachment1","Part0","Part1"}) do
                local candidate=bodyPart(read(constraint,key))
                if candidate and candidate~=source then anchor=candidate;break end
            end
            if anchor then break end
        end
        if not anchor then
            for _,name in ipairs(held and {"RightHand","Right Arm"} or {"LowerTorso","UpperTorso","Torso"}) do
                anchor=child(character,name);if anchor then break end
            end
        end
        if not anchor then return nil end
        local ok,offset=pcall(function() return anchor.CFrame:ToObjectSpace(source.CFrame) end)
        if ok then return {Part=anchor.Name,Offset=offset} end
    end
    local function capturePresentation(tool,source)
        local result={Sounds={}}
        if tool then
            result.Grip=read(tool,"Grip")
            local icon=read(tool,"TextureId")
            if type(icon)=="string" and icon~="" then result.ToolIcon=icon end
        end
        local root=tool or source
        for _,sound in ipairs(descendants(root)) do
            if isA(sound,"Sound") and #result.Sounds<32 then
                local path,object={},sound
                while object and object~=root do table.insert(path,1,read(object,"Name"));object=read(object,"Parent") end
                if not tool then table.insert(path,1,"Handle") end
                local properties={}
                for _,key in ipairs({"SoundId","Volume","PlaybackSpeed","RollOffMinDistance","RollOffMaxDistance","EmitterSize","Looped"}) do properties[key]=read(sound,key) end
                if type(properties.SoundId)=="string" and properties.SoundId~="" and #path<=8 then
                    result.Sounds[#result.Sounds+1]={Name=read(sound,"Name"),Path=path,Properties=properties}
                end
            end
        end
        return result
    end
    local function assetKey(value)
        if type(value)=="number" then return tostring(value) end
        if type(value)~="string" or value=="" then return nil end
        return value:match("[?&]assetId=(%d+)") or value:match("[?&]id=(%d+)") or value:match("rbxassetid://(%d+)") or value:match("^(%d+)$")
    end
    enrichSaved=function(entry,objects)
        if entry.catalog or not gunLibrary or not gunLibrary.setCatalog then return end
        local candidates=catalog(entry.kind)
        local identities,itemIds={},{ }
        for _,object in pairs(objects or {}) do
            local name=read(object,"Name");if name then identities[tostring(name)]=true end
            for _,value in ipairs(identityValue(object)) do identities[tostring(value)]=true end
        end
        for _,candidate in ipairs(candidates) do local id=field(candidate.definition,"ItemID");if id then local key=tostring(id);itemIds[key]=(itemIds[key] or 0)+1 end end
        local presentation=entry.definition.Presentation
        local image=presentation and assetKey(presentation.ToolIcon)
        local mesh=assetKey(entry.definition.MeshId)
        local texture=assetKey(entry.definition.TextureId)
        local function unique(predicate)
            local match
            for _,candidate in ipairs(candidates) do if predicate(candidate) then if match then return nil end;match=candidate end end
            return match
        end
        local match=unique(function(candidate)
            local id=field(candidate.definition,"ItemID")
            return identities[candidate.id] or (id and itemIds[tostring(id)]==1 and identities[tostring(id)])
        end)
        if not match then match=unique(function(candidate)
            for value in pairs(identities) do if lower(value)==lower(candidate.name) then return true end end
            return false
        end) end
        if not match and image then match=unique(function(candidate)
            local def=candidate.definition
            if lower(candidate.name):match("^default") then return false end
            return assetKey(field(def,"Image") or field(def,"ImageId") or field(def,"ImageID"))==image
        end) end
        if not match and mesh then match=unique(function(candidate)
            local def=candidate.definition
            local otherTexture=assetKey(field(def,"TextureId") or field(def,"TextureID"))
            return assetKey(field(def,"MeshId") or field(def,"MeshID"))==mesh and (not otherTexture or texture==otherTexture)
        end) end
        if not match then return end
        local def=match.definition
        local category=metadata(def)
        gunLibrary.setCatalog(entry.id,{Id=match.id,Name=match.name,Image=field(def,"Image") or field(def,"ImageId") or field(def,"ImageID") or (presentation and presentation.ToolIcon),
            Rarity=field(def,"Rarity"),Category=category,Season=field(def,"Season"),Year=field(def,"Year"),Event=field(def,"Event"),Chroma=field(def,"Chroma"),SortOrder=field(def,"SortOrder")})
    end
    function api.identifySavedWeapon(name,kind)
        assert(kind=="Gun" or kind=="Knife","Choose knife or gun.")
        local id=equipped[kind]
        local entry=id and findEntry(id,kind)
        assert(entry and field(entry.definition,"PortableGun"),"Equip the saved "..kind:lower().." you want to identify first.")
        local query=lower(tostring(name or ""):match("^%s*(.-)%s*$"));assert(query~="","Enter the original MM2 weapon name.")
        local match
        for _,candidate in ipairs(catalog(kind)) do if lower(candidate.id)==query then match=candidate;break end end
        if not match then
        for _,candidate in ipairs(catalog(kind)) do
            if lower(candidate.name)==query then
                assert(not match,"Several items share that name. Enter the exact item ID instead.")
                match=candidate
            end
        end
        end
        assert(match,"That name was not found in MM2's "..kind:lower().." catalog.")
        local def=match.definition
        gunLibrary.setCatalog(id,{Id=match.id,Name=match.name,Image=field(def,"Image") or field(def,"ImageId") or field(def,"ImageID"),Rarity=field(def,"Rarity"),Category=metadata(def),Season=field(def,"Season"),Year=field(def,"Year"),Event=field(def,"Event"),Chroma=field(def,"Chroma"),SortOrder=field(def,"SortOrder")})
        return "Matched saved "..kind:lower().." to "..match.name..". Its original name, icon, and rarity are saved."
    end
    function api.collectPlayerWeapon(username,kind)
        kind=kind=="Knife" and "Knife" or "Gun"
        local kindLower=kind:lower()
        assert(alive,"The MM2 cosmetic preview is closed.")
        assert(gunLibrary,"Refresh the hub to load the saved weapon library.")
        username=tostring(username or ""):match("^%s*(.-)%s*$")
        assert(username~="","Enter a Roblox username first.")
        local players=service("Players")
        local target
        for _,player in ipairs(players:GetPlayers()) do
            if lower(read(player,"Name"))==lower(username) then target=player;break end
        end
        assert(target,"Player not found in this server: "..username)
        assert(target~=read(players,"LocalPlayer"),"Choose another player's loaded "..kindLower..".")
        local character=read(target,"Character")
        local source,heldSource,holsteredSource,heldTool
        -- Prefer the held weapon: its display can be hidden while it is equipped.
        for _,object in ipairs(children(character)) do
            if isA(object,"Tool") and toolKind(object)==kind then heldTool=object;heldSource=weaponHandle(object);break end
        end
        local reference=child(character,"DisplayRef"..kind)
        if referenceKind(reference)==kind then holsteredSource=weaponHandle(read(reference,"Value")) end
        source=heldSource or holsteredSource
        assert(source and isA(source,"BasePart"),"Their "..kindLower.." model is not loaded. Ask them to equip it nearby, then collect again.")
        assert(isA(source,"MeshPart") or childClass(source,"SpecialMesh"),"Their loaded "..kindLower.." has no supported mesh to copy.")
        local mounts={Holster=captureGunMount(holsteredSource,character,false),Held=captureGunMount(heldSource,character,true)}
        local presentation=capturePresentation(heldTool,source)
        local alternate=source==heldSource and holsteredSource or heldSource
        local entry=gunLibrary.capture(source,tostring(read(target,"Name")),mounts,kind,presentation,alternate)
        enrichSaved(entry,{heldTool,source,reference})
        loadedLookupLog[#loadedLookupLog+1]="Saved "..kindLower.." from "..tostring(read(target,"Name")).."; mesh="..tostring(entry.definition.MeshId)
        local message=api.equip(entry.id,kind)..". Saved to your "..kindLower.." library."
        message=message.." Grip: "..(presentation.Grip and "captured" or "not loaded").."; icon: "..(presentation.ToolIcon and "captured" or "not loaded").."; sounds: "..#presentation.Sounds.."."
        local surface=entry.definition.SurfaceAppearance
        if (surface and surface.ColorMap and surface.ColorMap~="") or (entry.definition.TextureId and entry.definition.TextureId~="") then
            message=message.." Texture reference saved (live rendering not verified)."
        else
            message=message.." No texture map was exposed by either matching display; this copy uses the source colors."
        end
        if not heldTool then message=message.." Save again while they hold it to capture its held grip, toolbar icon, and loaded sounds." end
        return message
    end
    function api.collectPlayerGun(username)return api.collectPlayerWeapon(username,"Gun")end
    function api.collectPlayerKnife(username)return api.collectPlayerWeapon(username,"Knife")end
    function api.restore()
        appearanceGeneration=appearanceGeneration+1
        if alive and gunLibrary then
            if equipped.Gun and gunLibrary.getSelected("Gun")==equipped.Gun then gunLibrary.select(nil,"Gun") end
            if equipped.Knife and gunLibrary.getSelected("Knife")==equipped.Knife then gunLibrary.select(nil,"Knife") end
        end
        if track then pcall(function() track:Stop(0);track:Destroy() end); track=nil end
        for tool,old in pairs(toolPresentations) do restoreToolPresentation(tool,old) end
        toolPresentations={}
        for _,old in pairs(snapshots) do restoreHandle(old) end
        snapshots={}; pending={}; equipped={};equipError=nil;lastEquipResult=nil; disconnectAll(); return "Restored local MM2 preview."
    end
    function api.destroy()
        if alive then
            alive=false;api.restore()
            for _,object in ipairs(assetRoots) do pcall(function() object:Destroy() end) end
            assetRoots={};assetCache={};assetFailures={};resourceCache={};assetLoaders={};loadedVisualCache={};loadedLookupLog={}
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
        lines[#lines+1]="Build: native knife mount diagnostics V13"
        if gunLibrary then
            local names={};for _,entry in ipairs(gunLibrary.list()) do names[#names+1]=entry.name end
            lines[#lines+1]="Saved guns="..#names.."; "..table.concat(names,", ")
        end
        lines[#lines+1]="Selected Knife="..tostring(equipped.Knife).." Gun="..tostring(equipped.Gun).." Last equip error="..tostring(equipError or "none")
        lines[#lines+1]="Pending Knife="..tostring(pending.Knife).." Gun="..tostring(pending.Gun).." Last result="..tostring(lastEquipResult or "none")
        if lastAttempt then
            lines[#lines+1]="Last attempted item="..lastAttempt.id.." kind="..lastAttempt.kind.." ItemID="..tostring(field(lastAttempt.definition,"ItemID")).." Model="..tostring(field(lastAttempt.definition,"Model"))
            local def=lastAttempt.definition
            local surface=field(def,"SurfaceAppearance")
            lines[#lines+1]="Captured texture="..tostring(field(def,"TextureId") or "none").."; surface color map="..tostring(surface and surface.ColorMap or "none")
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
        for _,old in pairs(snapshots) do
            if old.kind=="Knife" and old.mount then
                local torso=child(character,old.mount.Part)
                lines[#lines+1]="Knife layout="..(knifeSide and "left side" or "back").." torso="..old.mount.Part.." torsoSize="..tostring(read(torso,"Size")).." localOffset="..tostring(old.mount.Offset)
            end
        end
        for _,kind in ipairs({"Knife","Gun"}) do
            local reference,target,handle=displayReference(kind)
            lines[#lines+1]="DisplayRef"..kind.."="..(reference and fullName(reference) or "missing").." Value="..(target and fullName(target) or "missing").." class="..(target and tostring(read(target,"ClassName")) or "missing").." Handle="..(handle and fullName(handle) or "missing")
            local entry=equipped[kind] and findEntry(equipped[kind],kind)
            local presentation=entry and entry.definition.Presentation
            if presentation then
                local matched=0
                for tool,old in pairs(toolPresentations) do if toolKind(tool)==kind then for _ in pairs(old.sounds) do matched=matched+1 end end end
                lines[#lines+1]=kind.." saved presentation: grip="..tostring(presentation.Grip~=nil).." icon="..tostring(presentation.ToolIcon~=nil).." sounds="..#(presentation.Sounds or {}).." matched="..matched
            end
        end
        local function exactFrame(value)
            local ok,values=pcall(function()return {value:GetComponents()}end)
            if not ok then return "unavailable" end
            for i,n in ipairs(values) do values[i]=string.format("%.9g",n) end
            return table.concat(values,",")
        end
        local sampled=0
        local actors={}
        if p then actors[1]=p end
        local getPlayers=read(ps,"GetPlayers")
        if type(getPlayers)=="function" then
            for _,actor in ipairs(getPlayers(ps)) do if actor~=p then actors[#actors+1]=actor end end
        end
        for _,actor in ipairs(actors) do
            if sampled>=12 then break end
            local rig=read(actor,"Character")
            local ref=child(rig,"DisplayRefKnife")
            local native=weaponHandle(read(ref,"Value"))
            if native then
                sampled=sampled+1
                local owner=tostring(read(actor,"Name"))
                local torso=child(rig,"LowerTorso") or child(rig,"Torso") or child(rig,"UpperTorso")
                local ok,relative=pcall(function()return torso.CFrame:ToObjectSpace(native.CFrame)end)
                local mesh=childClass(native,"SpecialMesh")
                lines[#lines+1]="Native knife mount owner="..owner.." part="..fullName(native).." torso="..tostring(read(torso,"Name")).." relative="..(ok and exactFrame(relative) or "unavailable").." size="..tostring(read(native,"Size")).." mesh="..tostring(read(mesh or native,"MeshId"))
                local inspected=0
                for _,object in ipairs(descendants(native)) do
                    if inspected>=16 then break end
                    if isA(object,"Attachment") then
                        inspected=inspected+1
                        lines[#lines+1]="Native knife attachment owner="..owner.." path="..fullName(object).." local="..exactFrame(read(object,"CFrame"))
                    elseif isA(object,"RigidConstraint") or isA(object,"Weld") or isA(object,"Motor6D") then
                        inspected=inspected+1
                        for _,key in ipairs({"Attachment0","Attachment1","Part0","Part1"}) do
                            local endpoint=read(object,key)
                            if endpoint then lines[#lines+1]="Native knife joint owner="..owner.." joint="..fullName(object).." "..key.."="..fullName(endpoint).." parent="..fullName(read(endpoint,"Parent")).." local="..exactFrame(read(endpoint,"CFrame")) end
                        end
                        if read(object,"C0") then lines[#lines+1]="Native knife C0="..exactFrame(read(object,"C0")).." C1="..exactFrame(read(object,"C1")) end
                    end
                end
            end
        end
        for _,entry in ipairs(loadedLookupLog) do lines[#lines+1]="Loaded source: "..entry end
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
            local id=tonumber(field(lastAttempt.definition,"ItemID"))
            lines[#lines+1]="Visual loader="..tostring(id and assetLoaders[tostring(id)] or "not attempted")
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
    if gunLibrary then
        local savedId=gunLibrary.getSelected("Gun")
        if savedId and findEntry(savedId,"Gun") then api.equip(savedId,"Gun") end
        local savedKnifeId=gunLibrary.getSelected("Knife")
        if savedKnifeId and findEntry(savedKnifeId,"Knife") then api.equip(savedKnifeId,"Knife") end
    end
    return api
end
