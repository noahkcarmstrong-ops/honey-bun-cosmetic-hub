-- Saves only supported visual properties from loaded knife displays; never scripts or gear.
return function(game,gui)
    local Http=game:GetService("HttpService")
    local Players=game:GetService("Players")
    local KEY="HoneyBunCosmeticEffects"
    local MAX_BYTES,MAX_RECORDS,MAX_ENTRIES=1400000,96,256
    local common={"Enabled","Color","Brightness","LightEmission","LightInfluence"}
    local properties={
        ParticleEmitter={"Texture","Rate","Lifetime","Speed","SpreadAngle","Rotation","RotSpeed","Size","Transparency","Acceleration","Drag","VelocityInheritance","Orientation","EmissionDirection","ZOffset","TimeScale","LockedToPart","Shape","ShapeStyle","ShapeInOut","ShapePartial","Squash","WindAffectsDrag","FlipbookFramerate","FlipbookLayout","FlipbookMode","FlipbookStartRandom"},
        Trail={"Lifetime","MinLength","MaxLength","Texture","TextureLength","TextureMode","FaceCamera","WidthScale","Transparency"},
        Beam={"Width0","Width1","CurveSize0","CurveSize1","FaceCamera","Segments","Texture","TextureLength","TextureMode","TextureSpeed","ZOffset","Transparency"},
        Fire={"SecondaryColor","Size","Heat"},Smoke={"Opacity","RiseVelocity","Size"},Sparkles={"SparkleColor"},
        PointLight={"Range","Shadows"},SpotLight={"Range","Shadows","Angle","Face"},SurfaceLight={"Range","Shadows","Angle","Face"},Attachment={"CFrame"}
    }
    local function read(o,key)local ok,v=pcall(function()return o[key]end);if not ok then return nil end;return v end
    local function children(o)return o and o:GetChildren()or{}end
    local function descendants(o)return o and o:GetDescendants()or{}end
    local function finite(n)return type(n)=="number"and n==n and math.abs(n)<1e9 end
    local function encode(v)
        local kind=typeof(v)
        if kind=="boolean"or kind=="string"then if kind=="string"and #v>2048 then return nil end;return v end
        if kind=="number"then return finite(v)and v or nil end
        if kind=="Color3"then return{t=kind,v={v.R,v.G,v.B}}end
        if kind=="Vector3"then return{t=kind,v={v.X,v.Y,v.Z}}end
        if kind=="Vector2"then return{t=kind,v={v.X,v.Y}}end
        if kind=="NumberRange"then return{t=kind,v={v.Min,v.Max}}end
        if kind=="CFrame"then return{t=kind,v={v:GetComponents()}}end
        if kind=="EnumItem"then
            local group,item=tostring(v):match("^Enum%.([%w_]+)%.([%w_]+)$")
            if group then return{t=kind,v={group,item}}end
        end
        if kind=="NumberSequence"or kind=="ColorSequence"then
            local points={};if #v.Keypoints>32 then return nil end
            for _,p in ipairs(v.Keypoints)do points[#points+1]=kind=="NumberSequence"and{p.Time,p.Value,p.Envelope}or{p.Time,p.Value.R,p.Value.G,p.Value.B}end
            return{t=kind,v=points}
        end
    end
    local function decode(value)
        if type(value)~="table"then
            if type(value)=="number"and not finite(value)then return nil end
            if type(value)=="string"then return #value<=2048 and value or nil end
            if type(value)=="boolean"then return value end
            return type(value)=="number"and finite(value)and value or nil
        end
        local t,v=value.t,value.v;if type(v)~="table"or #v>32 then return nil end
        if t=="EnumItem"then return type(v[1])=="string"and type(v[2])=="string"and Enum[v[1]][v[2]]or nil end
        if t=="NumberSequence"or t=="ColorSequence"then
            local points={}
            for _,p in ipairs(v)do
                if type(p)~="table"then return nil end
                for _,n in ipairs(p)do if not finite(n)then return nil end end
                points[#points+1]=t=="NumberSequence"and NumberSequenceKeypoint.new(p[1],p[2],p[3])or ColorSequenceKeypoint.new(p[1],Color3.new(p[2],p[3],p[4]))
            end
            return t=="NumberSequence"and NumberSequence.new(points)or ColorSequence.new(points)
        end
        for _,n in ipairs(v)do if not finite(n)then return nil end end
        if t=="Color3"and #v==3 then return Color3.new(table.unpack(v))end
        if t=="Vector3"and #v==3 then return Vector3.new(table.unpack(v))end
        if t=="Vector2"and #v==2 then return Vector2.new(table.unpack(v))end
        if t=="NumberRange"and #v==2 then return NumberRange.new(table.unpack(v))end
        if t=="CFrame"and #v==12 then return CFrame.new(table.unpack(v))end
    end
    local function allowed(class)
        local keys={};for _,key in ipairs(common)do keys[key]=true end
        for _,key in ipairs(properties[class]or{})do keys[key]=true end
        return keys
    end
    local entries,templates={},{}
    local visualKeys,aliases={},{}
    local metadataMigrated=false
    local effectCatalog={}
    local catalogByName={}
    local function field(def,...)
        if type(def)~="table" then return nil end
        for i=1,select("#",...)do local value=def[select(i,...)]if value~=nil then return value end end
    end
    local function loadCatalog()
        local rs=game:GetService("ReplicatedStorage")
        local db=rs and rs:FindFirstChild("Database");local sync=db and db:FindFirstChild("Sync")
        local mod=sync and sync:FindFirstChild("Effects")
        if not mod then return end
        local ok,data=pcall(require,mod);if not ok or type(data)~="table"then return end
        for id,def in pairs(data)do
            if type(def)=="table"then
                local key=tostring(id);local name=field(def,"ItemName","Name")
                effectCatalog[key]={id=key,name=type(name)=="string"and name or key,rarity=field(def,"Rarity"),image=field(def,"Image","ImageId","ImageID")}
                local exact=type(name)=="string"and name or nil
                if exact then catalogByName[exact]=catalogByName[exact]or{};catalogByName[exact][#catalogByName[exact]+1]=key end
            end
        end
    end
    loadCatalog()
    local function catalogId(root,records)
        local function known(value)return type(value)=="string"and effectCatalog[value]and value or nil end
        local id=known(read(root,"Name"));if id then return id end
        for _,attribute in ipairs({"EffectId","EffectID","CatalogId","CatalogID","ItemId","ItemID","Id","ID"})do
            local ok,value=pcall(function()return root:GetAttribute(attribute)end)
            id=ok and known(value)or nil;if id then return id end
        end
        local found={}
        for _,record in ipairs(records or{})do
            if not ({Fire=true,Smoke=true,Sparkles=true,Attachment=true,Trail=true,Beam=true,ParticleEmitter=true,Light=true})[record.name] then
                local matches=catalogByName[record.name]
                if matches then for _,candidate in ipairs(matches)do found[candidate]=true end end
            end
        end
        local only;for candidate in pairs(found)do if only then return nil end;only=candidate end
        return only
    end
    local selected
    local notice="No player effects collected yet."
    local alive=true
    local function snapshot(root)
        local records,indices,visuals={},{},0
        local all=descendants(root);table.insert(all,1,root)
        for _,o in ipairs(all)do
            local class=read(o,"ClassName")
            if properties[class]then
                assert(#records<MAX_RECORDS,"This knife effect is too large to save safely.")
                local record={class=class,name=tostring(read(o,"Name")):sub(1,100),values={}}
                indices[o]=#records+1;records[#records+1]=record
                if class~="Attachment"then visuals=visuals+1 end
                local keys=allowed(class)
                for key in pairs(keys)do local value=encode(read(o,key));if value~=nil then record.values[key]=value end end
            end
        end
        if visuals==0 then return nil end
        for o,index in pairs(indices)do
            local record=records[index];record.parent=indices[read(o,"Parent")]
            if record.class=="Trail"or record.class=="Beam"then
                record.a=indices[read(o,"Attachment0")];record.b=indices[read(o,"Attachment1")]
                assert(record.a and record.b,"This effect uses attachments outside the loaded knife; it cannot be saved yet.")
            end
            -- Rebase attachments under secondary parts onto this knife's local frame.
            if record.class=="Attachment"and not record.parent and read(root,"CFrame")and read(o,"WorldCFrame")then
                local ok,relative=pcall(function()return root.CFrame:ToObjectSpace(o.WorldCFrame)end)
                if ok then record.values.CFrame=encode(relative)end
            end
        end
        return records
    end
    local function canonical(v)
        if type(v)=="number"then return "number:"..string.format("%.5f",v)end
        if type(v)~="table"then return type(v)..":"..tostring(v)end
        local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
        local out={};for _,k in ipairs(keys)do out[#out+1]=tostring(k).."="..canonical(v[k])end
        return"{"..table.concat(out,"|").."}"
    end
    -- Names and player ownership are labels only. Keep attachment topology and
    -- every saved visual property so unrelated effects cannot merge accidentally.
    local function visualIdentity(records)
        local visual={}
        for i,record in ipairs(records or{})do
            visual[i]={class=record.class,values=record.values,parent=record.parent,a=record.a,b=record.b}
        end
        return canonical(visual)
    end
    local function identity(records)
        local text=visualIdentity(records);local a,b=1,7
        for i=1,#text do a=(a*31+text:byte(i))%2147483647;b=(b*37+text:byte(i))%2147483629 end
        return"SavedEffect_"..string.format("%.0f_%.0f",a,b)
    end
    local function particlePreview(records)
        for _,record in ipairs(records or{})do
            if record.class=="ParticleEmitter" and type(record.values)=="table" then
                local texture=record.values.Texture
                if type(texture)=="string" and texture~="" then
                    return{kind="ParticleTexture",label="Saved particle texture preview",texture=texture}
                end
            end
        end
    end
    local function restore(entry)
        assert(type(entry.records)=="table"and #entry.records<=MAX_RECORDS,"Invalid saved effect size.")
        local root=Instance.new("Folder");root.Name=entry.id
        local made={}
        local ok,err=pcall(function()
            for i,r in ipairs(entry.records)do
                assert(type(r)=="table"and properties[r.class],"Unsupported saved effect class.")
                local o=Instance.new(r.class);made[i]=o;o.Name=tostring(r.name or r.class):sub(1,100)
                local keys=allowed(r.class)
                for key,value in pairs(type(r.values)=="table"and r.values or{})do
                    if keys[key]then local good,decoded=pcall(decode,value);if good and decoded~=nil then pcall(function()o[key]=decoded end)end end
                end
                o.Parent=root
            end
            for i,r in ipairs(entry.records)do
                if r.parent then assert(made[r.parent]and entry.records[r.parent].class=="Attachment","Invalid effect parent.");made[i].Parent=made[r.parent]end
                if r.class=="Trail"or r.class=="Beam"then
                    assert(made[r.a]and made[r.b]and entry.records[r.a].class=="Attachment"and entry.records[r.b].class=="Attachment","Invalid trail endpoints.")
                    made[i].Attachment0=made[r.a];made[i].Attachment1=made[r.b]
                end
            end
        end)
        if not ok then root:Destroy();error(err)end
        return root
    end
    local raw=gui:GetAttribute(KEY)
    if type(raw)=="string"and #raw<=MAX_BYTES then
        local ok,saved=pcall(function()return Http:JSONDecode(raw)end)
        if ok and type(saved)=="table"and saved.version==1 and type(saved.entries)=="table"and #saved.entries<=MAX_ENTRIES then
            if type(saved.selected)=="string" and #saved.selected<100 then selected=saved.selected end
            for _,entry in ipairs(saved.entries)do
                if type(entry)=="table"and type(entry.id)=="string"and #entry.id<100 and type(entry.name)=="string"and #entry.name<=150 then
                    local good,source=pcall(restore,entry)
                    if good then
                        local catalogValue=type(entry.catalog)=="table" and entry.catalog.id
                        if catalogValue and not effectCatalog[tostring(catalogValue)] then entry.catalog=nil end
                        if entry.catalog then entry.catalog=effectCatalog[tostring(catalogValue)] end
                        if not entry.catalog then
                            local savedCatalogId=catalogId(source,entry.records)
                            if savedCatalogId then entry.catalog=effectCatalog[savedCatalogId];metadataMigrated=true end
                        end
                        local key=visualIdentity(entry.records)
                        local previous=visualKeys[key]
                        if previous then
                            aliases[entry.id]=previous
                            if entry.catalog then
                                for _,retained in ipairs(entries) do
                                    if retained.id==previous and not retained.catalog then retained.catalog=entry.catalog;break end
                                end
                            end
                            source:Destroy()
                        else
                            visualKeys[key]=entry.id
                            entry.customName=entry.customName==true
                            entries[#entries+1]=entry;templates[entry.id]=source
                        end
                    end
                end
            end
            if selected and aliases[selected] then selected=aliases[selected];metadataMigrated=true end
            if #entries~=#saved.entries then metadataMigrated=true end
        end
    end
    local function save()
        local encoded=Http:JSONEncode({version=1,entries=entries,selected=selected})
        assert(#encoded<=MAX_BYTES,"Saved effect library is full.");gui:SetAttribute(KEY,encoded)
    end
    if metadataMigrated then pcall(save) end
    local function roots(player)
        local result,seen={},{}
        local function add(o)if o and not seen[o]then seen[o]=true;result[#result+1]=o end end
        local character=read(player,"Character")
        for _,o in ipairs(children(character))do
            if read(o,"Name")=="DisplayRefKnife"and read(o,"ClassName")=="ObjectValue"then add(read(o,"Value"))end
            if read(o,"ClassName")=="Tool"and tostring(read(o,"Name")):lower()=="knife"then add(o:FindFirstChild("Handle"))end
        end
        return result
    end
    local api={}
    function api.getSelected()return selected end
    function api.select(id)
        id=aliases[id] or id
        if id~=nil then
            local found=id=="Bats" or templates[id]~=nil
            assert(found,"Choose a saved effect.")
        end
        local previous=selected;selected=id
        local ok,err=pcall(save);if not ok then selected=previous;error(err) end
    end
    function api.capturePlayer(name)
        assert(alive,"The effect collector is closed.")
        assert(type(name)=="string"and name~="","Enter a Roblox username.")
        local player
        for _,p in ipairs(Players:GetPlayers())do if tostring(read(p,"Name")):lower()==name:lower()then player=p;break end end
        if not player then return"Player "..name.." is not in this server."end
        if player==Players.LocalPlayer then return"Choose another player's original knife effect."end
        local added,duplicates,failures,captured=0,0,{},{}
        for _,root in ipairs(roots(player))do
            local ok,records=pcall(snapshot,root)
            if not ok then failures[#failures+1]=tostring(records)
            elseif records then
                local key=visualIdentity(records)
                local id=visualKeys[key] or identity(records)
                if templates[id]then duplicates=duplicates+1 else
                    assert(#entries<MAX_ENTRIES,"Saved effect library is full.")
                    local fromCount=0;for _,saved in ipairs(entries)do if saved.from==tostring(player.Name)then fromCount=fromCount+1 end end
                    local label="Effect from "..tostring(player.Name)..(fromCount>0 and (" ("..(fromCount+1)..")")or"")
                    local entry={id=id,name=label,from=tostring(player.Name),records=records}
                    local catalogIdValue=catalogId(root,records)
                    if catalogIdValue then entry.catalog=effectCatalog[catalogIdValue] end
                    local good,source=pcall(restore,entry)
                    if good then
                        entries[#entries+1]=entry
                        local saved,err=pcall(save)
                        if not saved then table.remove(entries);source:Destroy();error(err)end
                        templates[id]=source;visualKeys[key]=id;added=added+1
                    else failures[#failures+1]=tostring(source)end
                end
                if templates[id] then captured[#captured+1]=id end
            end
        end
        notice=name..": "..added.." new supported knife visual(s), "..duplicates.." already saved."
        if added==0 and duplicates==0 then notice=notice.." No saveable knife visuals loaded; they must equip the effect nearby."end
        if #failures>0 then notice=notice.." Unsupported: "..table.concat(failures,"; "):sub(1,350)end
        return notice,captured
    end
    function api.captureServer(first)
        local list=Players:GetPlayers();table.sort(list,function(a,b)
            local aFirst=tostring(a.Name):lower()==tostring(first):lower();local bFirst=tostring(b.Name):lower()==tostring(first):lower()
            if aFirst then return not bFirst end;if bFirst then return false end;return a.Name<b.Name
        end)
        local results={};local before=#entries
        for _,p in ipairs(list)do if p~=Players.LocalPlayer then
            if not alive then return "Effect collection cancelled."end
            local ok,message=pcall(api.capturePlayer,p.Name)
            results[#results+1]=ok and message or (tostring(p.Name)..": "..tostring(message):sub(1,250))
            if task and task.wait then task.wait()end
        end end
        if not alive then return "Effect collection cancelled."end
        notice=table.concat(results,"\n")
        return (results[1]or"No other players in this server.").." Server check: "..#results.." player(s), "..(#entries-before).." new effect(s). Full details in Copy MM2 report."
    end
    function api.list()
        local out={};for _,entry in ipairs(entries)do
            local metadata=entry.catalog
            local image=metadata and metadata.image
            local hasImage=image~=nil and image~=""
            local preview;if not hasImage then preview=particlePreview(entry.records) end
            out[#out+1]={id=entry.id,name=entry.customName and entry.name or (metadata and metadata.name or entry.name),kind="Effect",rarity=metadata and metadata.rarity,image=image,previewImage=preview and preview.texture,preview=preview,category="effects",editable=true,definition={Effect=templates[entry.id]}}
        end;return out
    end
    local function cleanName(name)
        assert(type(name)=="string","Enter a saved effect name.")
        name=name:match("^%s*(.-)%s*$")
        assert(#name>0,"Enter a saved effect name.")
        assert(#name<=80,"Saved effect names must be 80 characters or fewer.")
        return name
    end
    function api.rename(id,name)
        assert(type(id)=="string" and id~="","Choose a saved effect.")
        id=aliases[id] or id;name=cleanName(name)
        for _,entry in ipairs(entries) do if entry.id==id then
            local oldName,oldCustom=entry.name,entry.customName
            entry.name,entry.customName=name,true
            local ok,err=pcall(save)
            if not ok then entry.name,entry.customName=oldName,oldCustom;error(err) end
            return entry
        end end
        error("Saved effect was not found.")
    end
    function api.remove(id)
        assert(type(id)=="string" and id~="","Choose a saved effect.")
        id=aliases[id] or id
        for index,entry in ipairs(entries) do if entry.id==id then
            table.remove(entries,index);local oldSelected=selected
            if selected==id then selected=nil end
            local ok,err=pcall(save)
            if not ok then table.insert(entries,index,entry);selected=oldSelected;error(err) end
            local source=templates[id];templates[id]=nil;visualKeys[visualIdentity(entry.records)]=nil
            if source then source:Destroy() end
            return entry
        end end
        error("Saved effect was not found.")
    end
    function api.report()return"Saved original effect library: "..#entries.."; "..notice end
    function api.destroy()alive=false;for _,source in pairs(templates)do source:Destroy()end;templates={}end
    return api
end
