-- Local visual previews from MM2 Effects data; no ownership changes or game remotes.
return function(game,onStatus,library)
    local alive=true;local generation=0
    local selected=nil
    local catalogCache
    local catalogIds={}
    local collectedIds={}
    local capturePending,captureQueued,watchEpoch={},false,0
    local connections,observed,applied={}, {}, {}
    local sourceCache,sourceRoots,sourceNotes={},{},{}
    local sourceErrors,lastApplyError={},""
    local madeVisuals=setmetatable({},{__mode="k"})
    local startedDormant=false
    local function read(o,k) if not o then return nil end;local ok,v=pcall(function()return o[k]end);return ok and v or nil end
    local function isA(o,c) local f=read(o,"IsA");if type(f)=="function"then local ok,v=pcall(f,o,c);return ok and v==true end;return read(o,"ClassName")==c end
    local function children(o) local f=read(o,"GetChildren");if type(f)=="function"then local ok,v=pcall(f,o);if ok and type(v)=="table"then return v end end;return{} end
    local function descendants(o)local f=read(o,"GetDescendants");if type(f)=="function"then local ok,v=pcall(f,o);if ok and type(v)=="table"then return v end end;local out={};local function walk(p)for _,x in ipairs(children(p))do out[#out+1]=x;walk(x)end end;walk(o);return out end
    local function service(n)local f=read(game,"GetService");if type(f)~="function"then return nil end;local ok,v=pcall(f,game,n);return ok and v or nil end
    local function lower(v)return tostring(v or ""):lower()end
    local function field(v,k)return type(v)=="table" and v[k] or read(v,k) end
    local function connect(signal,fn) local f=read(signal,"Connect");if type(f)=="function"then local ok,c=pcall(f,signal,fn);if ok and c then connections[#connections+1]=c end end end
    local function disconnectAll()for _,c in ipairs(connections)do pcall(function()c:Disconnect()end)end;connections={};observed={};watchEpoch=watchEpoch+1;capturePending={};captureQueued=false end
    local function destroy(o)pcall(function()o:Destroy()end)end
    local function moduleData()
        local rs=service("ReplicatedStorage");local db=rs and rs:FindFirstChild("Database");local sync=db and db:FindFirstChild("Sync");local mod=sync and sync:FindFirstChild("Effects")
        if not mod then return nil,"ReplicatedStorage.Database.Sync.Effects was not found" end
        local ok,data=pcall(require,mod);return ok and data or nil,ok and nil or tostring(data)
    end
    local function catalog()
        if catalogCache then return catalogCache end
        local data,err=moduleData();assert(type(data)=="table",err or "Effects database is unavailable")
        local out={};for id,def in pairs(data)do if tostring(id)=="Bats" and type(def)=="table"then out[#out+1]={id=tostring(id),name=tostring(field(def,"ItemName")or field(def,"Name")or id),kind="Effect",rarity=field(def,"Rarity"),image=field(def,"Image")or field(def,"ImageId")or field(def,"ImageID"),category="effects",definition=def}end end
        if library then for _,entry in ipairs(library.list())do out[#out+1]=entry end end
        table.sort(out,function(a,b)return lower(a.name)<lower(b.name)end);catalogCache=out;for _,e in ipairs(out)do catalogIds[e.id]=e end;return out
    end
    local function find(id)for _,e in ipairs(catalog())do if e.id==tostring(id)then return e end end end
    local visualClasses={ParticleEmitter=true,Trail=true,Beam=true,Fire=true,Smoke=true,Sparkles=true,PointLight=true,SpotLight=true,SurfaceLight=true}
    local function visual(o)return o and (visualClasses[read(o,"ClassName")] or isA(o,"Light")) end
    local function generated(o)
        while o do if madeVisuals[o] then return true end;o=read(o,"Parent") end
        return false
    end
    local function supported(source)
        if visual(source) and not generated(source) then return true end
        for _,v in ipairs(descendants(source))do if visual(v) and not generated(v) then return true end end
        return false
    end
    local function indexSources()
        local index={};local token=generation;local visited=0
        for _,root in pairs({service("ReplicatedStorage"),service("Workspace")})do
            for _,candidate in ipairs(descendants(root))do
                if not generated(candidate)then
                    local keys={}
                    local function add(value)
                        if type(value)=="string" and not keys[value]then
                            keys[value]=true;index[value]=index[value]or{};table.insert(index[value],candidate)
                        end
                    end
                    add(read(candidate,"Name"))
                    local get=read(candidate,"GetAttribute")
                    if type(get)=="function"then
                        for _,key in ipairs({"Effect","EffectId","EffectID","KnifeEffect"})do
                            local ok,value=pcall(get,candidate,key);if ok then add(value)end
                        end
                    end
                end
                visited=visited+1
                if visited%200==0 and task and task.wait then task.wait()end
                if not alive or token~=generation then return nil end
            end
        end
        return index
    end
    local function loadedSource(e,value,index)
        index=index or indexSources()
        if not index then return nil end
        local matches,seen={},{}
        for _,key in ipairs({e.id,type(value)=="string" and value or e.id})do
            for _,candidate in ipairs(index[key]or{})do
                if not seen[candidate] and not generated(candidate) and supported(candidate)then
                    seen[candidate]=true;matches[#matches+1]=candidate
                end
            end
        end
        -- Multiple unrelated originals with the same name cannot be identified reliably.
        if #matches==1 then return matches[1] end
        return nil,#matches>1 and "multiple original templates match this effect" or nil
    end
    local function sourceFor(e,index)
        if sourceCache[e.id] then return sourceCache[e.id] end
        if sourceErrors[e.id] then return nil end
        local def=e.definition;local value=field(def,"Effect")or field(def,"Model")or field(def,"Template")or field(def,"Instance")or field(def,"Source")
        local source,reason;local lookupToken=generation
        if value and read(value,"ClassName") and supported(value)then source=value end
        if not source then source,reason=loadedSource(e,value,index)end
        if not alive or lookupToken~=generation then return nil end
        if source then
            sourceNotes[e.id]="original loaded template"
            -- Keep a private template if the other player leaves or their effect unloads.
            local ok,copy=pcall(function()return source:Clone()end)
            if ok and copy then source=copy;sourceRoots[#sourceRoots+1]=copy end
        end
        local assets,seen={},{}
        local function addAsset(value)
            local id=type(value)=="number" and tostring(value) or type(value)=="string" and (value:match("^%d+$") or value:match("[?&]id=(%d+)") or value:match("^rbxassetid://(%d+)$"))
            if id and not seen[id] then seen[id]=true;assets[#assets+1]=id end
        end
        for _,key in ipairs({"EffectID","EffectId","EffectAssetId","ModelId","ModelID","KnifeModule"})do addAsset(field(def,key))end
        if type(value)=="number" then addAsset(value)end
        for _,asset in ipairs(assets)do
            if source then break end
            local token=generation;local get=read(game,"GetObjects")
            if type(get)=="function"then
                local ok,roots=pcall(get,game,"rbxassetid://"..asset)
                if not alive or token~=generation then
                    if ok and type(roots)=="table"then for _,r in ipairs(roots)do destroy(r)end end
                    return nil
                end
                if ok and type(roots)=="table"then
                    for _,r in ipairs(roots)do
                        if not source and supported(r)then source=r;sourceRoots[#sourceRoots+1]=r
                        else destroy(r)end
                    end
                end
                if source then sourceNotes[e.id]="original asset "..asset
                else reason="asset "..asset..(ok and " returned no supported visual objects" or (" failed: "..tostring(roots):sub(1,160)))end
            else reason="GetObjects is unavailable on this client"end
        end
        if not source then sourceErrors[e.id]=reason or "no original template or explicit effect asset is available";return nil end
        local found=visual(source);for _,o in ipairs(descendants(source))do if visual(o)then found=true;break end end
        if not found then sourceErrors[e.id]="source contains no supported visual instances";return nil end
        sourceCache[e.id]=source;return source
    end
    local function weaponHandle(o)if isA(o,"BasePart")then return o end;return o and o:FindFirstChild("Handle")end
    local function targets()
        local out,seen={},{}
        local function add(o)if o and not seen[o]then local h=weaponHandle(o);if h and not seen[h]then seen[o]=true;seen[h]=true;out[#out+1]=h end end end
        local ps=service("Players");local p=ps and ps.LocalPlayer;local c=p and p.Character
        for _,x in ipairs(children(c))do if read(x,"Name")=="DisplayRefKnife" and isA(x,"ObjectValue")then add(read(x,"Value"))end end
        for _,x in ipairs(descendants(c))do local n=lower(read(x,"Name"));if isA(x,"Tool") and (n:find("knife",1,true)or n:find("weapon",1,true))then add(x)end end
        local bp=p and p.Backpack;for _,x in ipairs(descendants(bp))do local n=lower(read(x,"Name"));if isA(x,"Tool")and(n:find("knife",1,true)or n:find("weapon",1,true))then add(x)end end
        return out
    end
    local function cloneVisuals(source,target)
        local all=descendants(source);table.insert(all,1,source)
        local made,attachmentMap={},{}
        local function fail()for _,o in ipairs(made)do destroy(o)end;return nil end
        local function cleanClone(o)
            local ok,c=pcall(function()return o:Clone()end)
            if not ok or not c then return nil end
            made[#made+1]=c;madeVisuals[c]=true
            -- Copy visual properties only; no nested scripts, parts, or duplicate emitters.
            for _,child in ipairs(children(c)) do destroy(child) end
            return c
        end
        for _,o in ipairs(all) do
            if isA(o,"Attachment") then
                local c=cleanClone(o);if not c then return fail() end
                attachmentMap[o]=c
            end
        end
        for original,copy in pairs(attachmentMap) do copy.Parent=attachmentMap[read(original,"Parent")] or target end
        local count=0
        for _,o in ipairs(all) do
            if visual(o) then
                local c=cleanClone(o);if not c then return fail() end
                if isA(o,"ParticleEmitter") and type(read(o,"Rate"))=="number" and read(o,"Rate")<=0 then
                    -- Preserve the original texture and particle settings; start a gentle
                    -- local preview when the game normally triggers this emitter in code.
                    local ok=pcall(function()c.Rate=2 end)
                    if not ok then return fail()end
                    startedDormant=true
                end
                if isA(o,"Trail") or isA(o,"Beam") then
                    local a,b=attachmentMap[read(o,"Attachment0")],attachmentMap[read(o,"Attachment1")]
                    if not a or not b then return fail() end
                    local ok=pcall(function()c.Attachment0=a;c.Attachment1=b end)
                    if not ok then return fail() end
                end
                local ok=pcall(function()c.Enabled=true;c.Parent=attachmentMap[read(o,"Parent")] or target end)
                if not ok then return fail() end
                count=count+1
            end
        end
        if count==0 then return fail() end
        applied[target]=applied[target]or{}
        for _,o in ipairs(made)do applied[target][#applied[target]+1]=o end
        return true
    end
    local function clearApplied()startedDormant=false;for target,list in pairs(applied)do for _,o in ipairs(list)do destroy(o)end;applied[target]=nil end end
    local function apply()
        if not alive or not selected then return false,"No effect selected." end
        local token=generation
        local e=find(selected);local source=e and sourceFor(e)
        if not alive or token~=generation then return false,"Effect application was cancelled." end
        if not source then return false,"Effect has no supported local visual source." end
        local count=0;for _,target in ipairs(targets())do
            if not alive or token~=generation then return false,"Effect application was cancelled." end
            if cloneVisuals(source,target)then count=count+1 end
        end
        if count==0 then return false,"No original visuals could attach to the knife. See visual details in Copy MM2 report." end
        return true,"Equipped effect locally: "..e.name.." (original visuals)"
    end
    local function refreshEffect()
        if not alive or not selected then return end
        clearApplied()
        local ok,message=apply();lastApplyError=ok and "" or message
    end
    local function watchRef(x)
        if not x or not isA(x,"ObjectValue")or read(x,"Name")~="DisplayRefKnife"or observed[x]then return end
        observed[x]=true
        local sig=read(x,"GetPropertyChangedSignal")
        if type(sig)=="function"then connect(sig(x,"Value"),refreshEffect)end
    end
    local function watchTool(tool)
        if not isA(tool,"Tool") or not lower(read(tool,"Name")):find("knife",1,true) or observed[tool] then return end
        observed[tool]=true
        connect(read(tool,"ChildAdded"),function(x)if read(x,"Name")=="Handle" then refreshEffect() end end)
    end
    local function watchContainer(container,character)
        if not container or observed[container] then return end
        observed[container]=true
        connect(read(container,"ChildAdded"),function(x)
            watchTool(x)
            if character then watchRef(x) end
            if isA(x,"Tool") or (character and read(x,"Name")=="DisplayRefKnife") then refreshEffect() end
        end)
        for _,x in ipairs(children(container)) do watchTool(x);if character then watchRef(x) end end
    end
    local function captureArrivingOriginal(object)
        if not alive or generated(object) then return end
        catalog()
        local candidate=object
        for _=1,10 do
            if not candidate then break end
            local e=catalogIds[tostring(read(candidate,"Name"))]
            local get=read(candidate,"GetAttribute")
            if not e and type(get)=="function"then
                for _,key in ipairs({"Effect","EffectId","EffectID","KnifeEffect"})do
                    local ok,id=pcall(get,candidate,key)
                    if ok and type(id)=="string" and catalogIds[id]then e=catalogIds[id];break end
                end
            end
            if e then capturePending[candidate]=e;break end
            candidate=read(candidate,"Parent")
        end
        if captureQueued or next(capturePending)==nil then return end
        captureQueued=true;local epoch=watchEpoch
        local function collect()
            if not alive or epoch~=watchEpoch then return end
            captureQueued=false
            local pending=capturePending;capturePending={};local reapply=false
            for source,e in pairs(pending)do
                local originalCached=sourceCache[e.id]
                if not originalCached and read(source,"Parent") and not generated(source) and supported(source)then
                    local ok,copy=pcall(function()return source:Clone()end)
                    if ok and copy then
                        sourceRoots[#sourceRoots+1]=copy;sourceCache[e.id]=copy
                        sourceNotes[e.id]="original loaded template (automatically collected)"
                        sourceErrors[e.id]=nil;collectedIds[e.id]=true
                        if selected==e.id then reapply=true end
                    end
                end
            end
            if reapply then
                refreshEffect()
                if onStatus then pcall(onStatus,lastApplyError~="" and lastApplyError or ("Original effect loaded: "..tostring(selected)))end
            end
        end
        if task and task.defer then task.defer(collect)else collect()end
    end
    local function watchOriginals()
        for _,root in pairs({service("ReplicatedStorage"),service("Workspace")})do
            if not observed[root]then
                observed[root]=true
                connect(read(root,"DescendantAdded"),captureArrivingOriginal)
            end
        end
    end
    local function ensureWatchers()
        watchOriginals()
        local ps=service("Players");local p=ps and ps.LocalPlayer;if not p then return end
        if not observed[p] then
            observed[p]=true
            connect(read(p,"CharacterAdded"),function(c)
                generation=generation+1
                watchContainer(c,true);refreshEffect()
            end)
            connect(read(p,"ChildAdded"),function(o)
                if isA(o,"Backpack") or o==read(p,"Backpack") then watchContainer(o,false);refreshEffect() end
            end)
        end
        watchContainer(read(p,"Character"),true);watchContainer(read(p,"Backpack"),false)
    end
    local api={}
    function api.list(_,search)local out={};local q=lower(search);for _,e in ipairs(catalog())do if q==""or lower(e.name):find(q,1,true)or lower(e.id):find(q,1,true)then out[#out+1]={id=e.id,name=e.name,kind=e.kind,rarity=e.rarity,image=e.image,category=e.category}end end;return out end
    function api.equip(id,kind)assert(alive,"The effects preview is closed.");assert(kind=="Effect","Equip category must be Effect.");local e=find(id);assert(e,"Unsupported effect: "..tostring(id));generation=generation+1;local token=generation;selected=e.id;sourceErrors[e.id]=nil;ensureWatchers();clearApplied();local ok,msg=apply();if not alive or token~=generation then ok=false;msg="Effect application was cancelled." end;lastApplyError=ok and "" or msg;if onStatus then pcall(onStatus,msg)end;return ok and msg or "Selected "..e.name.."; unavailable locally: "..msg end
    function api.reloadLibrary()catalogCache=nil;catalogIds={};catalog()end
    function api.collectOriginals()assert(alive,"The effects preview is closed.");ensureWatchers()end
    function api.getEquipped()return{Effect=selected}end
    function api.restore()generation=generation+1;selected=nil;clearApplied();disconnectAll();lastApplyError="";return"Restored local MM2 effects."end
    function api.destroy()if alive then alive=false;api.restore();for _,r in ipairs(sourceRoots)do destroy(r)end;sourceRoots={};sourceCache={}end end
    local function selectedDetails()
        local e=selected and find(selected)
        if not e then return "none" end
        local keys={};for k in pairs(e.definition)do keys[#keys+1]=tostring(k)end;table.sort(keys)
        local fields={};for i=1,math.min(#keys,30)do local k=keys[i];fields[#fields+1]=k.."="..tostring(e.definition[k]):sub(1,180)end
        local roots={};for _,o in ipairs(descendants(service("ReplicatedStorage")))do
            local n=lower(read(o,"Name"))
            if n:find("effect",1,true) and (isA(o,"Folder")or isA(o,"ModuleScript")or isA(o,"Model")) then
                local path=read(o,"GetFullName");local ok,name=false,nil;if type(path)=="function"then ok,name=pcall(path,o)end
                roots[#roots+1]=(ok and name or tostring(read(o,"Name"))).."["..tostring(read(o,"ClassName")).."] children="..#children(o)
                if #roots>=25 then break end
            end
        end
        return e.id.."{"..table.concat(fields,";").."} loaded effect containers="..table.concat(roots,"|")
    end
    local function visualDetails()
        local lines={}
        local function describe(o)
            local fields={tostring(read(o,"Name")).."["..tostring(read(o,"ClassName")).."]"}
            for _,key in ipairs({"Enabled","Rate","Texture","Lifetime","Transparency","Size","Position","Orientation","Attachment0","Attachment1"})do
                local value=read(o,key);if value~=nil then fields[#fields+1]=key.."="..tostring(value):sub(1,130)end
            end
            local parent=read(o,"Parent");fields[#fields+1]="parent="..tostring(read(parent,"Name"))
            return table.concat(fields,";")
        end
        local source=selected and sourceCache[selected]
        if source then
            local all=descendants(source);table.insert(all,1,source)
            for _,o in ipairs(all)do
                if visual(o)or isA(o,"Attachment")or isA(o,"ModuleScript")or isA(o,"LocalScript")or isA(o,"Script")then
                    lines[#lines+1]="source "..describe(o);if #lines>=24 then break end
                end
            end
        end
        for _,target in ipairs(targets())do
            local path=read(target,"GetFullName");local ok,name=false,nil;if type(path)=="function"then ok,name=pcall(path,target)end
            lines[#lines+1]="target "..(ok and name or tostring(read(target,"Name"))).." transparency="..tostring(read(target,"Transparency")).." localTransparency="..tostring(read(target,"LocalTransparencyModifier"))
            local count=0;for _,o in ipairs(applied[target]or{})do if visual(o)then
                lines[#lines+1]="copy "..describe(o);count=count+1;if count>=8 then break end
            end end
            if #lines>=50 then break end
        end
        if startedDormant then lines[#lines+1]="Playback: started dormant original particles at 2 particles/second."end
        return table.concat(lines,"\n")
    end
    local function collectionReport()
        local ids={};for id in pairs(collectedIds)do ids[#ids+1]=id end;table.sort(ids)
        return "Automatically collected originals: "..(#ids>0 and table.concat(ids,",")or"none yet")
    end
    function api.report()local list=catalog();local names,defs={},{};for i=1,math.min(#list,20)do local e=list[i];names[#names+1]=e.id.."="..e.name;local fields={};for k,v in pairs(e.definition)do if #fields<6 then fields[#fields+1]=tostring(k)..":"..type(v).."="..tostring(v):sub(1,180)end end;defs[#defs+1]=e.id.."{"..table.concat(fields,";").."}" end;local targetCount=#targets();local appliedCount=0;for _,items in pairs(applied)do appliedCount=appliedCount+#items end;local sourceInfo="none";if selected then sourceInfo=sourceErrors[selected]or sourceNotes[selected]or"resolved" end;return"MM2 Effects build: Bats and saved player originals V10\nMM2 Effects catalog="..#list.." selected="..tostring(selected).." samples="..table.concat(names,",").." defs="..table.concat(defs,"|").." source="..sourceInfo.." targets="..targetCount.." applied="..appliedCount.." error="..tostring(lastApplyError).."\nselected definition="..selectedDetails().."\n"..visualDetails().."\n"..collectionReport() end
    return api
end
