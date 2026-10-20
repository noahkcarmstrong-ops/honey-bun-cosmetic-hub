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
        add(desc.Face,"Face",18,true)
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
        for _,key in ipairs(colorKeys)do assert(type(colors[key])=="string" and colors[key]:match("^%x%x%x%x%x%x$"),"Browser body colors are invalid.")end
        local scales=value.definition.scales;assert(type(scales)=="table","Browser scales are invalid.")
        for _,v in pairs(scales)do assert(type(v)=="number" and v==v and v<math.huge and v>=0 and v<=5,"Browser scales are invalid.")end
        local rig=value.definition.playerAvatarType;assert(type(rig)=="table" and (rig.playerAvatarType=="R6" or rig.playerAvatarType=="R15"),"Browser avatar type is invalid.")
        for _,item in ipairs(value.items)do assert(type(item)=="table" and safeId(item.id) and type(item.name)=="string" and #item.name<=128 and item.itemType=="Asset" and safeId(item.assetType),"Browser item is invalid.")end
        return value
    end
    local function applyCommand(value)
        validSnapshot(value);local revision=tonumber(value.revision);assert(revision and revision%1==0 and revision>0 and revision<9007199254740992,"Browser revision is invalid.");if revision<=lastRevision then return end
        local avatar,clothes=getAvatar(),getClothes();local failed={};local loadErrors={};local desired={};local current={}
        for _,item in ipairs(value.items)do
            assetTypes[item.id]=item.assetType
            if accessoryTypes[item.assetType] then desired[item.id]=true end
        end
        local ok,msg=pcall(function()
            for _,item in ipairs(snapshot().items)do if accessoryTypes[item.assetType] then current[item.id]=true end end
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
            local currentClothes=clothes.getSettings();local clothingTypes={[2]={"ShirtGraphic","equipTShirt","removeTShirt"},[11]={"Shirt","equipShirt","removeShirt"},[12]={"Pants","equipPants","removePants"}}
            local visibleClothes={};for _,item in ipairs(snapshot().items)do if clothingTypes[item.assetType] then visibleClothes[item.assetType]=item.id end end
            local wantedClothes={};local wantedAnimations={}
            for _,item in ipairs(value.items)do
                local slot=clothingTypes[item.assetType]
                if slot then
                    wantedClothes[item.assetType]=true
                    if visibleClothes[item.assetType]~=item.id then clothes[slot[2]](item.id)end
                elseif animationTypes[item.assetType] then wantedAnimations[#wantedAnimations+1]={id=item.id,assetType=item.assetType}
                elseif not accessoryTypes[item.assetType] and item.assetType~=17 and item.assetType~=18 and item.assetType~=27 and item.assetType~=28 and item.assetType~=29 and item.assetType~=30 and item.assetType~=31 then failed[#failed+1]=item.name end
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
        if ok then lastRevision=revision end
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
        if getViews then getViews().update({enabled=larpEnabled,name=larpName})end
        lastNameState=state
    end
    local function loop()
        local mine=generation
        while connected and generation==mine and isAlive() do
            local ok,err=pcall(function()
                local relay=call("GET","/v1/status",token)
                if relay and relay.instanceId and relay.instanceId~=api.instanceId then
                    lastRevision=0;lastJson=nil;lastNameState=nil;api.instanceId=relay.instanceId
                end
                applyNameState(call("GET","/v1/names/"..player.UserId,token))
                local command=call("GET","/v1/browser/"..player.UserId,token);if generation==mine and connected and command and command.revision then applyCommand(command)end
                local made,value=pcall(snapshot)
                if made then
                    lastSnapshot=value
                    local encoded=HttpService:JSONEncode(value)
                    if encoded~=lastJson then call("POST","/v1/game/"..player.UserId,token,value);lastJson=encoded end
                end
                if getViews then getViews().update({enabled=larpEnabled,name=larpName,snapshot=lastSnapshot}) end
            end)
            if not ok then status("Browser relay: "..tostring(err):gsub("^.-:%d+:%s*",""))end
            task.wait(0.75)
        end
    end
    function api.connect(code)
        code=(code and code~="" and code) or readSaved();assert(validToken(code),"Enter the 32-character browser pairing code.")
        local relay=call("GET","/v1/status",code);if relay and relay.instanceId and relay.instanceId~=api.instanceId then lastRevision=0;lastNameState=nil;api.instanceId=relay.instanceId end
        generation=generation+1;token=code;connected=true;lastJson=nil;save(code);status("Browser connected.")
        task.spawn(loop);return true
    end
    function api.disconnect()generation=generation+1;connected=false;token=nil;lastJson=nil;lastNameState=nil;applyNameState(nil);if getViews then getViews().update({enabled=false})end;status("Browser disconnected.")end
    function api.isConnected()return connected end
    function api.status()return connected and "Browser connected." or "Browser disconnected."end
    function api.publish()assert(connected,"Connect the browser first.");local value=snapshot();local encoded=HttpService:JSONEncode(value);if encoded~=lastJson then call("POST","/v1/game/"..player.UserId,token,value);lastJson=encoded end;return value end
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
