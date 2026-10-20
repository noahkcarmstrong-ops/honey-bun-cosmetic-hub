-- Local-only game <-> browser pairing. The relay never receives game code or commands.
local HttpService=game:GetService("HttpService")
local MarketplaceService=game:GetService("MarketplaceService")
local PORT=38261
local accessoryTypes={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
local animationTypes={[48]="ClimbAnimation",[50]="FallAnimation",[51]="IdleAnimation",[52]="JumpAnimation",[53]="RunAnimation",[54]="SwimAnimation",[55]="WalkAnimation",[56]="PoseAnimation"}
local function safeId(v)return type(v)=="number" and v==v and v>0 and v%1==0 and v<9007199254740992 end
local function hex(c)
    local function n(v)return math.clamp(math.floor(v*255+0.5),0,255) end
    return string.format("%02x%02x%02x",n(c.R),n(c.G),n(c.B))
end
local function call(method,path,token,body)
    local url="http://127.0.0.1:"..PORT..path
    local headers={Authorization="Bearer "..token,["Content-Type"]="application/json"}
    local fn= request or http_request or (syn and syn.request)
    assert(type(fn)=="function","This executor does not provide a localhost HTTP request function.")
    local result=fn({Url=url,Method=method,Headers=headers,Body=body and HttpService:JSONEncode(body),Timeout=5})
    local code=result and (result.StatusCode or result.Status)
    if tonumber(code)==404 then return nil end
    assert(tonumber(code)==200,"Browser relay returned HTTP "..tostring(code or "unknown"))
    return result.Body and HttpService:JSONDecode(result.Body) or {}
end
return function(player,getAvatar,getClothes,isAlive,onStatus,getAnimations,getNames,getViews)
    local api,token,connected,lastJson,lastRevision={},nil,false,nil,0
    local generation=0
    local lastNameState=nil
    local larpEnabled,larpName,lastSnapshot=false,"",nil
    local socket,socketReady,socketMine,nextSocketTry=nil,false,0,0
    local incoming,pumping={},false
    local retryCommand,retryAt=nil,0
    local imageValue,imageAsset,imageUrl,imageSerial=nil,nil,nil,0
    local loadingImageUrl
    local lastDefinition
    local file="larpblox-browser-pair-"..tostring(player.UserId)..".txt"
    local cache,assetTypes,bodyCache={},{},{}
    local function status(message)if onStatus and isAlive() then onStatus(message)end end
    local function validToken(v)return type(v)=="string" and #v==32 and v:match("^%x+$") end
    local function readSaved()
        if type(readfile)=="function" and type(isfile)=="function" then
            local ok,v=pcall(function()if isfile(file)then return readfile(file)end end)
            if ok and validToken(v)then return v end
        end
    end
    local function save(v)
        if type(writefile)=="function" then pcall(writefile,file,v)end
    end
    local function product(id,fallback)
        if cache[id]then return cache[id]end
        -- Browser commands carry validated names and asset types.  Keep that
        -- metadata authoritative for this sync so a slow marketplace lookup
        -- cannot delay applying the outfit.
        if fallback and assetTypes[id] then cache[id]=fallback;return fallback end
        local name=fallback or tostring(id);local ok,info=pcall(function()return MarketplaceService:GetProductInfo(id,Enum.InfoType.Asset)end)
        if ok and type(info)=="table" then if type(info.Name)=="string" then name=info.Name end;assetTypes[id]=tonumber(info.AssetTypeId) end
        cache[id]=name;return name
    end
    local function bodyDescription(value)
        if bodyCache[value] then return bodyCache[value] end
        local presets={Girl=131929545,["Robloxian 2.0"]=131929576}
        local outfit=presets[value]
        if not outfit then
            local id=tonumber(value) or tonumber(tostring(value):match("/bundles/(%d+)"))
            assert(safeId(id),"Invalid body bundle.")
            local bundle=HttpService:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",id).."/details",false))
            for _,item in ipairs(bundle.items or {})do if item.type=="UserOutfit" then outfit=tonumber(item.id);break end end
        end
        assert(safeId(outfit),"Body bundle has no outfit.")
        local source=game:GetService("Players"):GetHumanoidDescriptionFromOutfitIdAsync(outfit)
        local result={}
        for _,key in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","BodyTypeScale","ProportionScale"})do result[key]=source[key] end
        source:Destroy();bodyCache[value]=result;return result
    end
    local bodyRegions={{"Head",17},{"Torso",27},{"RightArm",28},{"LeftArm",29},{"LeftLeg",30},{"RightLeg",31}}
    local bodyTypeRegions={[17]="Head",[79]="Head",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg"}
    local browserBody,originalBody={},{ }
    local browserFace=false
    local function definitionKey(definition)
        if type(definition)~="table" then return "" end
        local ids,values={},{}
        for _,asset in ipairs(definition.assets or {})do ids[#ids+1]=asset.id end
        table.sort(ids);for _,id in ipairs(ids)do values[#values+1]=tostring(id)end
        for _,key in ipairs({"headColor","torsoColor","leftArmColor","rightArmColor","leftLegColor","rightLegColor"})do
            values[#values+1]=tostring((definition.bodyColors or {})[key] or ""):gsub("^#",""):lower()
        end
        for _,key in ipairs({"height","width","depth","head","bodyType","proportion"})do values[#values+1]=tostring((definition.scales or {})[key] or "")end
        return table.concat(values,"|")
    end
    local function currentImage()
        return imageAsset and imageValue and definitionKey(imageValue.definition)==definitionKey(lastDefinition) and imageAsset or nil
    end
    local function updateViews()
        if getViews then getViews().update({enabled=larpEnabled,name=larpName,snapshot=lastSnapshot,image=currentImage()})end
    end
    local function applyImage(value)
        if type(value)~="table" or value.version~=1 or tostring(value.userId)~=tostring(player.UserId) then return end
        local url=value.imageUrl
        if type(url)~="string" or #url>2048 or not (url:match("^https://tr%.rbxcdn%.com/[%w%-%._~/]+$") or url:match("^https://t%d%.rbxcdn%.com/[%w%-%._~/]+$")) then return end
        if type(value.definition)~="table" then return end
        imageValue=value
        if imageUrl==url and imageAsset then updateViews();return end
        local custom=getcustomasset or getsynasset
        if type(custom)~="function" or type(writefile)~="function" then return end
        if loadingImageUrl==url then return end
        loadingImageUrl=url
        local mine=generation
        local ok,result=pcall(function()
            local bytes=game:HttpGet(url,false)
            assert(type(bytes)=="string" and #bytes<=4*1024*1024 and bytes:sub(1,8)=="\137PNG\r\n\26\n","The avatar image is not a valid PNG.")
            if mine~=generation or not imageValue or imageValue.imageUrl~=url then return end
            imageSerial=imageSerial+1
            local path="larpblox-avatar-"..player.UserId.."-"..imageSerial..".png"
            writefile(path,bytes)
            return custom(path)
        end)
        if loadingImageUrl==url then loadingImageUrl=nil end
        if ok and type(result)=="string" and mine==generation and imageValue and imageValue.imageUrl==url then imageAsset=result;imageUrl=url;updateViews()
        elseif not ok then status("Browser avatar image: "..tostring(result))end
    end
    local function snapshot()
        local character=player.Character;local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        assert(character and humanoid,"Wait for your avatar to finish spawning.")
        local desc=humanoid:GetAppliedDescription();local settings=getAvatar():getSettings();local clothes=getClothes():getSettings()
        local colors=character:FindFirstChildOfClass("BodyColors")
        local function color(region,name)
            local c=colors and colors[region.."Color3"]
            if not c then local part=character:FindFirstChild(name) or character:FindFirstChild(region=="Torso" and "Torso" or region:gsub("Arm","UpperArm"):gsub("Leg","UpperLeg"));c=part and part.Color end
            return c and hex(c) or "ffffff"
        end
        local definition={assets={},bodyColors={headColor=color("Head","Head"),torsoColor=color("Torso","UpperTorso"),leftArmColor=color("LeftArm","Left Arm"),rightArmColor=color("RightArm","Right Arm"),leftLegColor=color("LeftLeg","Left Leg"),rightLegColor=color("RightLeg","Right Leg")},scales={},playerAvatarType={playerAvatarType=humanoid.RigType==Enum.HumanoidRigType.R6 and "R6" or "R15"}}
        for _,pair in ipairs({{"HeightScale","height"},{"WidthScale","width"},{"DepthScale","depth"},{"HeadScale","head"},{"BodyTypeScale","bodyType"},{"ProportionScale","proportion"}})do local v=desc[pair[1]];if type(v)=="number" and v==v and v<math.huge then definition.scales[pair[2]]=v end end
        local items,seen={},{}
        local function add(id,name,assetType,include,meta)
            if include and safeId(id) and not seen[id] and #items<100 then
                local label=product(id,name);assetType=assetTypes[id] or assetType
                seen[id]=true;items[#items+1]={id=id,name=string.sub(label,1,128),itemType="Asset",assetType=assetType};definition.assets[#definition.assets+1]={id=id,meta=meta}
            end
        end
        local added={};for _,entry in ipairs(getAvatar():listAccessories())do added[entry.id]=true;local typeId=assetTypes[entry.id] or 8;add(entry.id,entry.name,typeId,true)end
        if getAvatar().listGear then for _,entry in ipairs(getAvatar():listGear())do add(entry.id,entry.name,19,true) end end
        local ok,entries=pcall(function()return desc:GetAccessories(true)end)
        if ok and type(entries)=="table" then for _,entry in ipairs(entries)do local id=entry.AssetId;local typeId=assetTypes[id] or 8;add(id,entry.Name,typeId,not settings.hideOriginals or added[id],entry.IsLayered and {order=entry.Order or 0,puffiness=entry.Puffiness or 0} or nil)end end
        local bodyTypes={Head=17,Torso=27,LeftArm=29,RightArm=28,LeftLeg=30,RightLeg=31}
        local source=desc
        if settings.body and settings.body~="Blocky" then source=bodyDescription(settings.body) end
        if source~=desc then definition.scales.bodyType=source.BodyTypeScale;definition.scales.proportion=source.ProportionScale end
        for region,typeId in pairs(bodyTypes)do
            local id=source[region]
            if settings.body=="Blocky" and (region~="Head" or humanoid.RigType~=Enum.HumanoidRigType.R6) then id=0 end
            local override=settings.bodyParts and settings.bodyParts[region]
            if override then
                local text=tostring(override)
                if text:find("/bundles/",1,true) then id=bodyDescription(override)[region]
                else id=tonumber(override) or tonumber(text:match("/catalog/(%d+)")) end
            end
            add(id,region,typeId,true)
        end
        add(settings.face or desc.Face,"Face",18,true)
        add(clothes.ShirtGraphic or desc.GraphicTShirt,"Graphic T-Shirt",2,true)
        add(clothes.Shirt or desc.Shirt,"Shirt",11,(clothes.Shirt or desc.Shirt)~=nil);add(clothes.Pants or desc.Pants,"Pants",12,(clothes.Pants or desc.Pants)~=nil)
        local animationSettings=getAnimations and getAnimations().getSettings() or {}
        local overridden={}
        for _,item in ipairs(animationSettings.assets or {})do overridden[item.assetType]=true;add(item.id,"Movement animation",item.assetType,true)end
        for assetType,property in pairs(animationTypes)do
            if not overridden[assetType] and property~="PoseAnimation" then
                local readable,id=pcall(function()return desc[property]end)
                if readable then add(id,property,assetType,true)end
            end
        end
        return {version=1,userId=tostring(player.UserId),definition=definition,items=items}
    end
    local function validSnapshot(value)
        assert(type(value)=="table" and value.version==1 and tostring(value.userId)==tostring(player.UserId),"Browser snapshot is for a different account.")
        assert(type(value.definition)=="table" and type(value.definition.assets)=="table" and #value.definition.assets<=100,"Browser snapshot assets are invalid.")
        assert(type(value.items)=="table" and #value.items<=100,"Browser snapshot items are invalid.")
        for _,asset in ipairs(value.definition.assets)do assert(type(asset)=="table" and safeId(asset.id),"Browser asset is invalid.")end
        local colors=value.definition.bodyColors;local colorKeys={"headColor","torsoColor","leftArmColor","rightArmColor","leftLegColor","rightLegColor"}
        assert(type(colors)=="table", "Browser body colors are invalid.")
        for _,key in ipairs(colorKeys)do
            assert(type(colors[key])=="string" and colors[key]:match("^#?%x%x%x%x%x%x$"),"Browser body colors are invalid.")
            colors[key]=colors[key]:gsub("^#",""):lower()
        end
        local scales=value.definition.scales;assert(type(scales)=="table","Browser scales are invalid.")
        for _,v in pairs(scales)do assert(type(v)=="number" and v==v and v<math.huge and v>=0 and v<=5,"Browser scales are invalid.")end
        local rig=value.definition.playerAvatarType;assert(type(rig)=="table" and (rig.playerAvatarType=="R6" or rig.playerAvatarType=="R15"),"Browser avatar type is invalid.")
        for _,item in ipairs(value.items)do assert(type(item)=="table" and safeId(item.id) and type(item.name)=="string" and #item.name<=128 and item.itemType=="Asset" and safeId(item.assetType),"Browser item is invalid.")end
        return value
    end
    local function applyCommand(value)
        validSnapshot(value);local revision=tonumber(value.revision);assert(revision and revision%1==0 and revision>0 and revision<9007199254740992,"Browser revision is invalid.");if revision<=lastRevision then return end
        local avatar,clothes=getAvatar(),getClothes();local failed={};local loadErrors={};local desired={};local current={};local desiredGear
        for _,item in ipairs(value.items)do
            assetTypes[item.id]=item.assetType
            cache[item.id]=item.name
            if accessoryTypes[item.assetType] then desired[item.id]=true end
            if item.assetType==19 then desiredGear=item end
        end
        local ok,msg=pcall(function()
            local before=snapshot()
            for _,item in ipairs(before.items)do if accessoryTypes[item.assetType] then current[item.id]=true end end
            for _,entry in ipairs({{"Head","headColor"},{"Torso","torsoColor"},{"LeftArm","leftArmColor"},{"RightArm","rightArmColor"},{"LeftLeg","leftLegColor"},{"RightLeg","rightLegColor"}})do
                local wanted=value.definition.bodyColors[entry[2]]:lower()
                if before.definition.bodyColors[entry[2]]~=wanted then
                    local loaded,reason=pcall(avatar.setSkin,Color3.fromRGB(tonumber(wanted:sub(1,2),16),tonumber(wanted:sub(3,4),16),tonumber(wanted:sub(5,6),16)),entry[1])
                    if not loaded then loadErrors[#loadErrors+1]=entry[1].." color: "..tostring(reason)end
                end
            end
            local currentBody,desiredBody={},{ }
            for _,item in ipairs(before.items)do local region=bodyTypeRegions[item.assetType];if region then currentBody[region]=item.id end end
            for _,item in ipairs(value.items)do local region=bodyTypeRegions[item.assetType];if region then desiredBody[region]=item.id end end
            for _,entry in ipairs(bodyRegions)do
                local region=entry[1];local wanted=desiredBody[region];local owned=browserBody[region]
                if owned and not wanted then
                    local original=originalBody[region]
                    if avatar.restoreBodyPart then
                        local loaded,reason=pcall(avatar.restoreBodyPart,region)
                        if not loaded then loadErrors[#loadErrors+1]=region..": "..tostring(reason)end
                    elseif original then
                        local loaded,reason=pcall(avatar.applyBodyPart,region,original)
                        if not loaded then loadErrors[#loadErrors+1]=region..": "..tostring(reason)end
                    end
                    browserBody[region]=nil;originalBody[region]=nil
                elseif wanted and currentBody[region]~=wanted then
                    if not originalBody[region] then originalBody[region]=currentBody[region] end
                    local loaded,reason=pcall(avatar.applyBodyPart,region,wanted)
                    if loaded then browserBody[region]=wanted else loadErrors[#loadErrors+1]=region..": "..tostring(reason)end
                end
            end
            local currentFace,desiredFace
            for _,item in ipairs(before.items)do if item.assetType==18 then currentFace=item.id end end
            for _,item in ipairs(value.items)do if item.assetType==18 then desiredFace=item.id end end
            if desiredFace and avatar.applyFace and currentFace~=desiredFace then
                local loaded,reason=pcall(avatar.applyFace,desiredFace)
                if loaded then browserFace=true else loadErrors[#loadErrors+1]="Face: "..tostring(reason)end
            elseif not desiredFace and browserFace and avatar.restoreFace then
                local loaded,reason=pcall(avatar.restoreFace)
                if not loaded then loadErrors[#loadErrors+1]="Face: "..tostring(reason)end
                browserFace=false
            end
            local changed=false;for id in pairs(desired)do if not current[id]then changed=true end end;for id in pairs(current)do if not desired[id]then changed=true end end
            if changed then
                -- Keep unchanged instances: some already-worn hats cannot be loaded again.
                local entries=avatar.listAccessories();local localIds={};local present={}
                for _,entry in ipairs(entries)do localIds[entry.id]=true end
                local hideOriginals=false
                for id in pairs(current)do
                    if not localIds[id] then
                        if desired[id] then present[id]=true else hideOriginals=true end
                    end
                end
                if hideOriginals then avatar.removeCurrentAccessories();present={} end
                for _,entry in ipairs(entries)do
                    if desired[entry.id] then present[entry.id]=true else avatar.removeAccessory(entry.key) end
                end
                for _,item in ipairs(value.items)do
                    if accessoryTypes[item.assetType] and not present[item.id] then
                        local loaded,reason=pcall(avatar.equipAccessory,item.id)
                        if loaded then present[item.id]=true else loadErrors[#loadErrors+1]=item.name..": "..tostring(reason) end
                    end
                end
            end
            local currentGear=avatar.listGear and avatar.listGear()[1]
            if (currentGear and not desiredGear) or (desiredGear and (not currentGear or currentGear.id~=desiredGear.id)) then
                if desiredGear then
                    local loaded,reason=pcall(avatar.equipGear,desiredGear.id)
                    if not loaded then loadErrors[#loadErrors+1]=desiredGear.name..": "..tostring(reason) end
                elseif currentGear then avatar.removeGear()
                end
            end
            local currentClothes=clothes.getSettings();local clothingTypes={[2]={"ShirtGraphic","equipTShirt","removeTShirt"},[11]={"Shirt","equipShirt","removeShirt"},[12]={"Pants","equipPants","removePants"}}
            local visibleClothes={};for _,item in ipairs(snapshot().items)do if clothingTypes[item.assetType] then visibleClothes[item.assetType]=item.id end end
            local wantedClothes={};local wantedAnimations={}
            for _,item in ipairs(value.items)do
                local slot=clothingTypes[item.assetType]
                if slot then
                    wantedClothes[item.assetType]=true
                    if visibleClothes[item.assetType]~=item.id then clothes[slot[2]](item.id)end
                elseif animationTypes[item.assetType] then wantedAnimations[#wantedAnimations+1]={id=item.id,assetType=item.assetType}
                elseif item.assetType~=19 and not accessoryTypes[item.assetType] and item.assetType~=17 and item.assetType~=18 and item.assetType~=27 and item.assetType~=28 and item.assetType~=29 and item.assetType~=30 and item.assetType~=31 and item.assetType~=79 then failed[#failed+1]=item.name end
            end
            for assetType,slot in pairs(clothingTypes)do if not wantedClothes[assetType] and currentClothes[slot[1]]~=0 and clothes[slot[3]] then clothes[slot[3]]()end end
            if getAnimations then
                local animationApi=getAnimations();local settings=animationApi.getSettings()
                local currentAnimations={};for _,item in ipairs(snapshot().items)do if animationTypes[item.assetType] then currentAnimations[item.assetType]=item.id end end
                local changedAnimations=false;local desiredAnimations={}
                for _,item in ipairs(wantedAnimations)do desiredAnimations[item.assetType]=item.id;if currentAnimations[item.assetType]~=item.id then changedAnimations=true end end
                for assetType in pairs(currentAnimations)do if not desiredAnimations[assetType] then changedAnimations=true end end
                if changedAnimations then
                    local loaded,reason=pcall(function()if #wantedAnimations>0 then animationApi.equipAssets(wantedAnimations) elseif settings.bundleId or settings.assets then animationApi.restore()end end)
                    if not loaded then loadErrors[#loadErrors+1]="Movement animations: "..tostring(reason)end
                end
            elseif #wantedAnimations>0 then loadErrors[#loadErrors+1]="Reload the connected script to enable movement animations." end
            if #loadErrors>0 then error(table.concat(loadErrors,"; "))end
        end)
        if ok then lastRevision=revision;lastDefinition=value.definition end
        if not ok then status("Browser outfit failed: "..tostring(msg)) elseif #failed>0 then status("Browser outfit applied; unsupported items: "..table.concat(failed,", ")) else status("Browser outfit applied locally.") end
    end
    local function applyNameState(value)
        local state="disabled"
        local name=""
        if value then
            -- Older relays may return an outfit-shaped payload for unknown paths.
            if value.enabled==nil and value.name==nil then return end
            assert(type(value)=="table" and value.version==1 and tostring(value.userId)==tostring(player.UserId) and type(value.enabled)=="boolean" and type(value.name)=="string","Browser name is invalid.")
            if value.enabled then
                assert(value.name=="" or (value.name:match("^[A-Za-z0-9_]+$") and #value.name>=3 and #value.name<=20),"Browser name is invalid.")
                state="enabled:"..value.name;name=value.name
            end
        end
        larpEnabled=state~="disabled";larpName=name
        if state==lastNameState then return end
        if getNames then
            local names=getNames()
            if state=="disabled" then names.setEnabled(false) else names.set(name,name) end
        end
        if getViews then getViews().update({enabled=larpEnabled,name=larpName,image=currentImage()})end
        lastNameState=state
    end
    local function closeSocket()
        socketMine=socketMine+1;socketReady=false
        local previous=socket;socket=nil
        if previous then pcall(function()previous:Close()end)end
    end
    local function send(channel,value)
        if socketReady and socket then
            local ok=pcall(function()socket:Send(HttpService:JSONEncode({type="publish",channel=channel,value=value}))end)
            if ok then return end
            closeSocket()
        end
        return call("POST","/v1/"..(channel=="game" and "game" or channel).."/"..player.UserId,token,value)
    end
    local function publishSnapshot()
        local made,value=pcall(snapshot)
        if made then
            lastSnapshot=value
            local encoded=HttpService:JSONEncode(value)
            if encoded~=lastJson then send("game",value);lastJson=encoded end
        end
        updateViews()
    end
    local function pump()
        if pumping then return end
        pumping=true;local mine=generation
        local ok,err=pcall(function()
            while connected and generation==mine and next(incoming)do
                local batch=incoming;incoming={}
                if batch.names then applyNameState(batch.names.value)end
                if batch.browser and batch.browser.value and batch.browser.value.revision then
                    local command=batch.browser.value
                    applyCommand(command)
                    if lastRevision~=command.revision then retryCommand=command;retryAt=os.clock()+2 else retryCommand=nil end
                end
                if batch.image then
                    local value=batch.image.value
                    task.spawn(function()if generation==mine and connected then applyImage(value)end end)
                end
                publishSnapshot()
            end
        end)
        pumping=false
        if not ok then status("Browser socket: "..tostring(err))end
    end
    local function openSocket()
        local ws=WebSocket or websocket or (syn and syn.websocket)
        local connect=ws and (ws.connect or ws.new)
        if type(connect)~="function" or socket or os.clock()<nextSocketTry then return end
        nextSocketTry=os.clock()+2
        local mine=generation;local serial=socketMine
        local ok,candidate=pcall(connect,"ws://127.0.0.1:"..PORT.."/v1/socket")
        if not ok or not candidate then return end
        if mine~=generation then pcall(function()candidate:Close()end);return end
        socket=candidate
        candidate.OnClose:Connect(function()
            if socket==candidate then socket=nil;socketReady=false;lastJson=nil end
        end)
        candidate.OnMessage:Connect(function(message)
            if socket~=candidate or generation~=mine or socketMine~=serial then return end
            local read,value=pcall(function()return HttpService:JSONDecode(message)end)
            if not read or type(value)~="table" then return end
            if value.type=="ready" then
                socketReady=true;lastJson=nil
                if value.instanceId~=api.instanceId then lastRevision=0;lastNameState=nil;api.instanceId=value.instanceId end
                status("Browser connected via WebSocket.")
            elseif value.type=="state" and (value.channel=="browser" or value.channel=="names" or value.channel=="image") then
                incoming[value.channel]={value=value.value};task.spawn(pump)
            elseif value.type=="error" then closeSocket()end
        end)
        local sent=pcall(function()candidate:Send(HttpService:JSONEncode({version=1,type="auth",token=token,userId=tostring(player.UserId),role="game"}))end)
        if not sent then closeSocket()end
    end
    local function loop()
        local mine=generation
        while connected and generation==mine and isAlive() do
            local ok,err=pcall(function()
                openSocket()
                if not socketReady then
                local relay=call("GET","/v1/status",token)
                if relay and relay.instanceId and relay.instanceId~=api.instanceId then
                    lastRevision=0;lastJson=nil;lastNameState=nil;api.instanceId=relay.instanceId
                end
                local command=call("GET","/v1/browser/"..player.UserId,token)
                local names=call("GET","/v1/names/"..player.UserId,token)
                local image=relay and relay.websocket and call("GET","/v1/image/"..player.UserId,token)
                if generation~=mine or not connected then return end
                if not socketReady then
                    if command and command.revision then incoming.browser={value=command}end
                    incoming.names={value=names}
                    if image then incoming.image={value=image}end
                end
                end
                if generation~=mine or not connected then return end
                if retryCommand and os.clock()>=retryAt and not incoming.browser then incoming.browser={value=retryCommand};retryCommand=nil end
                pump()
                if not pumping then publishSnapshot()end
            end)
            if not ok then status("Browser relay: "..tostring(err):gsub("^.-:%d+:%s*",""))end
            task.wait(0.25)
        end
    end
    function api.connect(code)
        code=(code and code~="" and code) or readSaved();assert(validToken(code),"Enter the 32-character browser pairing code.")
        local relay=call("GET","/v1/status",code);if relay and relay.instanceId and relay.instanceId~=api.instanceId then lastRevision=0;lastNameState=nil;api.instanceId=relay.instanceId end
        closeSocket();incoming={};retryCommand=nil;generation=generation+1;token=code;connected=true;lastJson=nil;save(code);status("Browser connected.")
        task.spawn(loop);return true
    end
    function api.disconnect()generation=generation+1;closeSocket();incoming={};retryCommand=nil;connected=false;token=nil;lastJson=nil;lastNameState=nil;applyNameState(nil);if getViews then getViews().update({enabled=false})end;status("Browser disconnected.")end
    function api.isConnected()return connected end
    function api.status()return connected and (socketReady and "Browser connected via WebSocket." or "Browser connected (HTTP fallback).") or "Browser disconnected."end
    function api.publish()assert(connected,"Connect the browser first.");local value=snapshot();local encoded=HttpService:JSONEncode(value);if encoded~=lastJson then send("game",value);lastJson=encoded end;return value end
    function api.destroy()api.disconnect()end
    local saved=readSaved()
    if saved then
        local mine=generation
        task.spawn(function()
            while generation==mine and isAlive() do
                if pcall(api.connect,saved) then return end
                status("Waiting for the saved browser connection...")
                task.wait(2)
            end
        end)
    end
    return api,saved
end
