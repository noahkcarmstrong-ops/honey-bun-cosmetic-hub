-- Local visual previews from MM2 Effects data; no ownership changes or game remotes.
return function(game,onStatus)
    local alive=true;local generation=0
    local selected=nil
    local catalogCache
    local connections,observed,applied={}, {}, {}
    local sourceCache,sourceRoots,sourceNotes={},{},{}
    local sourceErrors,lastApplyError={},""
    local function read(o,k) if not o then return nil end;local ok,v=pcall(function()return o[k]end);return ok and v or nil end
    local function isA(o,c) local f=read(o,"IsA");if type(f)=="function"then local ok,v=pcall(f,o,c);return ok and v==true end;return read(o,"ClassName")==c end
    local function children(o) local f=read(o,"GetChildren");if type(f)=="function"then local ok,v=pcall(f,o);if ok and type(v)=="table"then return v end end;return{} end
    local function descendants(o)local f=read(o,"GetDescendants");if type(f)=="function"then local ok,v=pcall(f,o);if ok and type(v)=="table"then return v end end;local out={};local function walk(p)for _,x in ipairs(children(p))do out[#out+1]=x;walk(x)end end;walk(o);return out end
    local function service(n)local f=read(game,"GetService");if type(f)~="function"then return nil end;local ok,v=pcall(f,game,n);return ok and v or nil end
    local function lower(v)return tostring(v or ""):lower()end
    local function field(v,k)return type(v)=="table" and v[k] or read(v,k) end
    local function connect(signal,fn) local f=read(signal,"Connect");if type(f)=="function"then local ok,c=pcall(f,signal,fn);if ok and c then connections[#connections+1]=c end end end
    local function disconnectAll()for _,c in ipairs(connections)do pcall(function()c:Disconnect()end)end;connections={};observed={} end
    local function destroy(o)pcall(function()o:Destroy()end)end
    local function moduleData()
        local rs=service("ReplicatedStorage");local db=rs and rs:FindFirstChild("Database");local sync=db and db:FindFirstChild("Sync");local mod=sync and sync:FindFirstChild("Effects")
        if not mod then return nil,"ReplicatedStorage.Database.Sync.Effects was not found" end
        local ok,data=pcall(require,mod);return ok and data or nil,ok and nil or tostring(data)
    end
    local function catalog()
        if catalogCache then return catalogCache end
        local data,err=moduleData();assert(type(data)=="table",err or "Effects database is unavailable")
        local out={};for id,def in pairs(data)do if type(def)=="table"then out[#out+1]={id=tostring(id),name=tostring(field(def,"ItemName")or field(def,"Name")or id),kind="Effect",rarity=field(def,"Rarity"),image=field(def,"Image")or field(def,"ImageId")or field(def,"ImageID"),category="effects",definition=def}end end
        table.sort(out,function(a,b)return lower(a.name)<lower(b.name)end);catalogCache=out;return out
    end
    local function find(id)for _,e in ipairs(catalog())do if e.id==tostring(id)then return e end end end
    local function findNamed(root,name)
        if not root then return nil end
        local found=nil;for _,o in ipairs(descendants(root))do if tostring(read(o,"Name"))==name then if found then return nil end;found=o end end;return found
    end
    local visualClasses={ParticleEmitter=true,Trail=true,Beam=true,Fire=true,Smoke=true,Sparkles=true,PointLight=true,SpotLight=true,SurfaceLight=true}
    local function visual(o)return o and (visualClasses[read(o,"ClassName")] or isA(o,"Light")) end
    local function sourceFor(e)
        if sourceCache[e.id] then return sourceCache[e.id] end
        if sourceErrors[e.id] then return nil end
        local def=e.definition;local value=field(def,"Effect")or field(def,"Model")or field(def,"Template")or field(def,"Instance")or field(def,"Source")
        local source
        if type(value)=="string"then source=findNamed(service("ReplicatedStorage"),value)elseif value and read(value,"ClassName")then source=value end
        if not source then
            local matches={}
            for _,candidate in ipairs(descendants(service("ReplicatedStorage"))) do
                if read(candidate,"Name")==e.id then
                    local supported=visual(candidate)
                    for _,v in ipairs(descendants(candidate)) do if visual(v) then supported=true;break end end
                    if supported then matches[#matches+1]=candidate end
                end
            end
            if #matches==1 then source=matches[1] end
        end
        local asset=field(def,"EffectID")or field(def,"EffectId")or field(def,"EffectAssetId")or field(def,"ModelId")or field(def,"KnifeModule")
        if not source and asset then
            local token=generation;local get=read(game,"GetObjects");if type(get)=="function"then local ok,roots=pcall(get,game,"rbxassetid://"..tostring(asset));if not alive or token~=generation then if ok and type(roots)=="table"then for _,r in ipairs(roots)do destroy(r)end end;return nil end;if ok and type(roots)=="table"then source=roots[1];for _,r in ipairs(roots)do sourceRoots[#sourceRoots+1]=r end end end
        end
        -- A named local recreation avoids depending on an inaccessible legacy asset.
        if not source and e.id=="BlueFire" then
            local ok,flame=pcall(function()
                local fire=Instance.new("Fire")
                fire.Name="HoneyBunBlueFlame";fire.Color=Color3.fromRGB(0,85,255)
                fire.SecondaryColor=Color3.fromRGB(80,200,255);fire.Size=2;fire.Heat=2
                return fire
            end)
            if ok and flame then
                source=flame;sourceRoots[#sourceRoots+1]=flame
                sourceNotes[e.id]="built-in blue flame recreation"
            end
        end
        if not source then sourceErrors[e.id]=asset and ("asset "..tostring(asset).." returned no accessible visual source") or "no explicit local source or supported asset";return nil end
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
            made[#made+1]=c
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
            if visual(o) and not (isA(o,"ParticleEmitter") and type(read(o,"Rate"))=="number" and read(o,"Rate")<=0) then
                local c=cleanClone(o);if not c then return fail() end
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
    local function clearApplied()for target,list in pairs(applied)do for _,o in ipairs(list)do destroy(o)end;applied[target]=nil end end
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
        if count==0 then return false,"No compatible knife target or continuous visual is available. Burst-only effects need game behavior." end
        return true,"Equipped effect locally: "..e.name..(sourceNotes[e.id] and " (local recreation)" or "")
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
    local function ensureWatchers()
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
    function api.report()local list=catalog();local names,defs={},{};for i=1,math.min(#list,20)do local e=list[i];names[#names+1]=e.id.."="..e.name;local fields={};for k,v in pairs(e.definition)do if #fields<6 then fields[#fields+1]=tostring(k)..":"..type(v).."="..tostring(v):sub(1,180)end end;defs[#defs+1]=e.id.."{"..table.concat(fields,";").."}" end;local targetCount=#targets();local appliedCount=0;for _,items in pairs(applied)do appliedCount=appliedCount+#items end;local sourceInfo="none";if selected then sourceInfo=sourceErrors[selected]or sourceNotes[selected]or"resolved" end;return"MM2 Effects build: local knife visuals V3\nMM2 Effects catalog="..#list.." selected="..tostring(selected).." samples="..table.concat(names,",").." defs="..table.concat(defs,"|").." source="..sourceInfo.." targets="..targetCount.." applied="..appliedCount.." error="..tostring(lastApplyError).."\nselected definition="..selectedDetails() end
    return api
end
