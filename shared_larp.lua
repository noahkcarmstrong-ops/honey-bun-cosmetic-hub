-- Opt-in, local rendering of Larpblox appearances shared by clients in the same Roblox server.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local ACCESSORY_TYPES={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
local BODY_TYPES={[17]="Head",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[79]="Head"}
local BODY_REGIONS={"Head","Torso","RightArm","LeftArm","LeftLeg","RightLeg"}
local SCALE_VALUES={height="BodyHeightScale",width="BodyWidthScale",depth="BodyDepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="BodyProportionScale"}
local CLOTHES_TYPES={[2]="ShirtGraphic",[11]="Shirt",[12]="Pants"}
local ANIMATION_TYPES={[48]=true,[50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,[56]=true}
local COLOR_REGIONS={{"Head","headColor"},{"Torso","torsoColor"},{"LeftArm","leftArmColor"},{"RightArm","rightArmColor"},{"LeftLeg","leftLegColor"},{"RightLeg","rightLegColor"}}

local function safeId(value)
    local n=tonumber(value)
    return n and n>0 and n%1==0 and n<9007199254740992 and n or nil
end
local function safeImageUrl(value)
    return type(value)=="string" and #value<=2048 and
        (value:match("^https://tr%.rbxcdn%.com/[%w%-%._~/]+$") or value:match("^https://t%d%.rbxcdn%.com/[%w%-%._~/]+$"))~=nil
end

local function sameValue(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a)do if not sameValue(value,b[key])then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end

return function(localPlayer,getSnapshot,getNameSettings,createAvatar,createClothes,createAnimations,createNames,isAlive,onStatus,presentation)
    presentation=presentation or {}
    local sharing=false
    local generation=0
    local peers={}
    local imageSerial=0
    local lastSent
    local transport=presentation.transport
    local latestRecords,pending,connections={},{},{}
    local processing=false
    local nextStatus=0
    local function status(message)
        if onStatus and os.clock()>=nextStatus then nextStatus=os.clock()+4;onStatus(message)end
    end
    local function roomContext()
        local placeId=tonumber(game.PlaceId)
        local jobId=tostring(game.JobId or "")
        assert(placeId and placeId>0 and placeId%1==0,"Join a live Roblox server before enabling shared Larp mode.")
        assert(jobId~="" and jobId~="00000000-0000-0000-0000-000000000000","Shared Larp mode is available in live game servers, not Studio.")
        assert(jobId:match("^[A-Za-z0-9%-]+$"),"This game server has an unsupported instance ID.")
        return string.format("%.0f",placeId),jobId
    end
    local function cleanupPeer(userId)
        local entry=peers[userId]
        if not entry then return end
        peers[userId]=nil
        for value,original in pairs(entry.originalScales or {})do
            pcall(function()if value.Parent then value.Value=original end end)
        end
        for _,api in ipairs({entry.names,entry.animations,entry.clothes,entry.avatar,entry.views})do
            if api and api.destroy then pcall(api.destroy)end
        end
        if entry.imagePath and type(delfile)=="function" then pcall(delfile,entry.imagePath)end
    end
    local function cleanupAll()
        for userId in pairs(peers)do cleanupPeer(userId)end
    end
    local function peerApis(player)
        local playerGui
        -- Other players' names are displayed in this client's GUI.
        pcall(function()playerGui=localPlayer:FindFirstChildOfClass("PlayerGui")end)
        local function callback(message)status("Shared appearance for "..player.Name..": "..tostring(message))end
        return {
            avatar=createAvatar(player,callback),
            clothes=createClothes(player,callback),
            animations=createAnimations(player,callback),
            names=createNames(player,playerGui),
            player=player,
            character=player.Character,
        }
    end
    local function validRecord(record)
        if type(record)~="table" or record.version~=1 or type(record.userId)~="string" then return false end
        local snapshot=record.snapshot
        if type(snapshot)~="table" or snapshot.version~=1 or tostring(snapshot.userId)~=record.userId then return false end
        if not safeId(record.userId) or type(snapshot.definition)~="table" or type(snapshot.definition.assets)~="table" or #snapshot.definition.assets>100 or type(snapshot.items)~="table" or #snapshot.items>100 then return false end
        if record.imageUrl~=nil and not safeImageUrl(record.imageUrl) then return false end
        if record.name~=nil then
            local name=record.name
            if type(name)~="table" or type(name.enabled)~="boolean" or type(name.username)~="string" or #name.username>20 or not name.username:match("^[A-Za-z0-9_]*$") or type(name.displayName)~="string" or #name.displayName>50 or name.displayName:find("[%c]") then return false end
            if name.enabled and (#name.username<3 or #name.displayName<1) then return false end
        end
        return true
    end
    local function applyRecord(record)
        if not validRecord(record) or record.userId==tostring(localPlayer.UserId) then return end
        local target=Players:GetPlayerByUserId(tonumber(record.userId))
        if not target or target==localPlayer then return end
        local snapshot=record.snapshot
        local entry=peers[record.userId]
        if entry and entry.player==target and entry.character==target.Character
            and sameValue(entry.snapshot,snapshot) and sameValue(entry.name,record.name)
            and entry.imageUrl==record.imageUrl then return end
        if entry and (entry.player~=target or entry.character~=target.Character)then
            cleanupPeer(record.userId);entry=nil
        end
        local fresh=not entry
        if fresh then entry=peerApis(target);peers[record.userId]=entry end
        local ok,err=pcall(function()
            -- Keep the live overlay and its caches when only part of the outfit changes.
            local previous=entry.snapshot or {}
            local oldItems,oldSlots,slots={},{},{}
            for _,item in ipairs(previous.items or {})do oldItems[tostring(item.assetType)..":"..tostring(item.id)]=true;oldSlots[tonumber(item.assetType) or 0]=true end
            for _,item in ipairs(snapshot.items)do slots[tonumber(item.assetType) or 0]=true end
            for _,item in ipairs(previous.items or {})do
                local kind=tonumber(item.assetType)
                if not slots[kind]then
                    if kind==18 then pcall(entry.avatar.restoreFace)
                    elseif kind==19 then pcall(entry.avatar.removeGear)end
                end
            end
            local wanted={}
            local wantedClothes={}
            local animationAssets={}
            local body,oldBody={},{}
            for _,item in ipairs(previous.items or {})do
                local region=BODY_TYPES[tonumber(item.assetType)]
                if region then oldBody[region]=item.id end
            end
            for _,item in ipairs(snapshot.items)do
                local region=BODY_TYPES[tonumber(item.assetType)]
                if region then body[region]=item.id end
            end
            -- These are complete outfits. Zero/default body parts are deliberately
            -- omitted from the asset list; absence means blocky, not the peer's
            -- original Roblox package. Apply on first render and after respawn too.
            local humanoid=target.Character and target.Character:FindFirstChildOfClass("Humanoid")
            local blocky,bodyChanged=true,fresh
            for _,region in ipairs(BODY_REGIONS)do
                if region~="Head" and (body[region] or 0)~=0 then blocky=false end
                if (body[region] or 0)~=(oldBody[region] or 0)then bodyChanged=true end
            end
            local bulk=blocky and bodyChanged and type(entry.avatar.applyBody)=="function"
            if bulk then entry.avatar.applyBody("Blocky")end
            for _,region in ipairs(BODY_REGIONS)do
                local desired=body[region] or 0
                local changed=fresh or desired~=(oldBody[region] or 0)
                if bulk then
                    changed=region=="Head" and (desired~=0 or (humanoid and humanoid.RigType==Enum.HumanoidRigType.R6 and changed))
                end
                if changed then
                    entry.avatar.applyBodyPart(region,desired)
                end
            end
            if humanoid and humanoid.RigType==Enum.HumanoidRigType.R15 then
                entry.originalScales=entry.originalScales or {}
                for key,property in pairs(SCALE_VALUES)do
                    local scale=humanoid:FindFirstChild(property)
                    local desired=(snapshot.definition.scales or {})[key]
                    if scale and scale:IsA("NumberValue")then
                        if desired~=nil then
                            assert(type(desired)=="number" and desired==desired and desired>=0 and desired<=5,"Invalid shared body scale")
                            if entry.originalScales[scale]==nil then entry.originalScales[scale]=scale.Value end
                            if scale.Value~=desired then scale.Value=desired end
                        elseif entry.originalScales[scale]~=nil then
                            scale.Value=entry.originalScales[scale];entry.originalScales[scale]=nil
                        end
                    end
                end
            end
            for _,item in ipairs(snapshot.items)do
                if type(item)=="table" and safeId(item.id) and tonumber(item.assetType) then
                    local assetType=tonumber(item.assetType)
                    local changed=not oldItems[tostring(item.assetType)..":"..tostring(item.id)]
                    if ACCESSORY_TYPES[assetType] then wanted[item.id]=item
                    elseif BODY_TYPES[assetType] then -- Applied by region above, including absent/default parts.
                    elseif assetType==18 then if changed then pcall(entry.avatar.applyFace,item.id)end
                    elseif CLOTHES_TYPES[assetType]=="ShirtGraphic" then wantedClothes.ShirtGraphic=true;if changed then pcall(entry.clothes.equipTShirt,item.id)end
                    elseif CLOTHES_TYPES[assetType]=="Shirt" then wantedClothes.Shirt=true;if changed then pcall(entry.clothes.equipShirt,item.id)end
                    elseif CLOTHES_TYPES[assetType]=="Pants" then wantedClothes.Pants=true;if changed then pcall(entry.clothes.equipPants,item.id)end
                    elseif assetType==19 then if changed then pcall(entry.avatar.equipGear,item.id)end
                    elseif ANIMATION_TYPES[assetType] then animationAssets[#animationAssets+1]={id=item.id,assetType=assetType}
                    end
                end
            end
            if fresh then entry.avatar.removeCurrentAccessories()end
            local equipped={}
            for _,item in ipairs(entry.avatar.listAccessories())do equipped[item.id]=true end
            -- Load additions first so existing accessories remain visible while assets load.
            for id in pairs(wanted)do if not equipped[id]then pcall(entry.avatar.equipAccessory,id)end end
            for _,item in ipairs(entry.avatar.listAccessories())do if not wanted[item.id]then pcall(entry.avatar.removeAccessory,item.key)end end
            if not wantedClothes.ShirtGraphic and (fresh or oldSlots[2])then pcall(entry.clothes.removeTShirt)end
            if not wantedClothes.Shirt and (fresh or oldSlots[11])then pcall(entry.clothes.removeShirt)end
            if not wantedClothes.Pants and (fresh or oldSlots[12])then pcall(entry.clothes.removePants)end
            local colors=snapshot.definition.bodyColors or {}
            for _,pair in ipairs(COLOR_REGIONS)do
                local value=colors[pair[2]]
                local oldColors=previous.definition and previous.definition.bodyColors or {}
                if value~=oldColors[pair[2]] and type(value)=="string" and value:match("^#?%x%x%x%x%x%x$")then
                    value=value:gsub("^#","")
                    entry.avatar.setSkin(Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)),pair[1])
                end
            end
            table.sort(animationAssets,function(a,b)return a.assetType==b.assetType and a.id<b.id or a.assetType<b.assetType end)
            if not sameValue(entry.animationAssets,animationAssets)then
                if #animationAssets>0 then pcall(entry.animations.equipAssets,animationAssets)
                elseif entry.animationAssets and #entry.animationAssets>0 then pcall(entry.animations.restore)end
                entry.animationAssets=animationAssets
            end
            local name=record.name
            if not sameValue(entry.name,name)then
                if type(name)=="table" and name.enabled then pcall(entry.names.set,name.username,name.displayName)
                else pcall(entry.names.restore)end
            end
            if presentation.createViews and peers[record.userId]==entry and sharing and isAlive() then
                if not entry.views then entry.views=presentation.createViews(target)end
                local options={enabled=true,name=name and name.enabled and name.username or "",snapshot=snapshot,image=entry.image}
                entry.viewOptions=options
                entry.views.update(options)
                local custom=getcustomasset or getsynasset
                if record.imageUrl~=entry.imageUrl then
                    entry.imageGeneration=(entry.imageGeneration or 0)+1
                    entry.image=nil;options.image=nil;entry.views.update(options)
                end
                if record.imageUrl and record.imageUrl~=entry.imageUrl and type(custom)=="function" and type(writefile)=="function" then
                    local imageGeneration=entry.imageGeneration
                    task.spawn(function()
                        local loaded,reason=pcall(function()
                            local bytes=game:HttpGet(record.imageUrl,false)
                            assert(type(bytes)=="string" and #bytes<=4*1024*1024 and bytes:sub(1,8)=="\137PNG\r\n\26\n","Invalid shared avatar image.")
                            if peers[record.userId]~=entry or entry.imageGeneration~=imageGeneration or not sharing or not isAlive() then return end
                            imageSerial=imageSerial+1
                            local path="larpblox-shared-avatar-"..record.userId.."-"..imageSerial..".png"
                            local previousPath=entry.imagePath
                            entry.imagePath=path
                            writefile(path,bytes)
                            local image=custom(path)
                            if peers[record.userId]~=entry or entry.imageGeneration~=imageGeneration or not sharing or not isAlive() then return end
                            entry.image=image;entry.viewOptions.image=image;entry.views.update(entry.viewOptions)
                            if previousPath and type(delfile)=="function"then pcall(delfile,previousPath)end
                        end)
                        if not loaded and peers[record.userId]==entry then status("Shared avatar image: "..tostring(reason))end
                    end)
                end
            end
        end)
        if ok then entry.snapshot=snapshot;entry.name=record.name;entry.imageUrl=record.imageUrl else
            cleanupPeer(record.userId)
            status("Could not apply a shared appearance: "..tostring(err))
        end
    end
    local function publish(snapshot)
        snapshot=snapshot or getSnapshot()
        local settings=getNameSettings and getNameSettings() or {}
        local name={enabled=false,username="",displayName=""}
        local username,displayName=settings.username,settings.displayName
        if settings.enabled==true and type(username)=="string" and #username>=3 and #username<=20
            and username:match("^[A-Za-z0-9_]+$") and type(displayName)=="string"
            and #displayName>=1 and #displayName<=50 and not displayName:find("[%c]") then
            name={enabled=true,username=username,displayName=displayName}
        end
        local record={version=1,userId=tostring(localPlayer.UserId),snapshot=snapshot,name=name}
        if presentation.getImageUrl then
            local url=presentation.getImageUrl()
            if safeImageUrl(url) then record.imageUrl=url end
        end
        if sameValue(record,lastSent)then return end
        assert(transport and transport.setSharing,"Update Larpblox Desktop and the game script to share appearances.")
        local placeId,jobId=roomContext()
        transport.setSharing({enabled=true,placeId=placeId,jobId=jobId,record=record})
        lastSent=record
    end
    local processPending
    processPending=function()
        if processing or not sharing or not isAlive()then return end
        processing=true
        local mine=generation
        task.spawn(function()
            while sharing and generation==mine and isAlive()and next(pending)do
                local userId,record=next(pending);pending[userId]=nil
                if record==false then cleanupPeer(userId)
                else
                    local ok,reason=pcall(applyRecord,record)
                    if not ok then status("Shared appearance: "..tostring(reason))end
                end
            end
            processing=false
            if sharing and next(pending)then processPending()end
        end)
    end
    local function receive(event)
        if not sharing or not isAlive()or type(event)~="table"then return end
        if event.type=="status"then status(tostring(event.message));return end
        if event.type=="snapshot"and type(event.players)=="table"then
            local seen={}
            for _,record in ipairs(event.players)do
                if validRecord(record)and record.userId~=tostring(localPlayer.UserId)then
                    seen[record.userId]=true;latestRecords[record.userId]=record;pending[record.userId]=record
                end
            end
            for userId in pairs(latestRecords)do if not seen[userId]then latestRecords[userId]=nil;pending[userId]=false end end
        elseif event.type=="upsert"and validRecord(event.record)then
            local record=event.record
            if record.userId~=tostring(localPlayer.UserId)then latestRecords[record.userId]=record;pending[record.userId]=record end
        elseif event.type=="remove"and type(event.userId)=="string"then
            latestRecords[event.userId]=nil;pending[event.userId]=false
        end
        processPending()
    end
    if transport and transport.onShared then connections[#connections+1]=transport.onShared(receive)end
    if transport and transport.onSnapshot then
        connections[#connections+1]=transport.onSnapshot(function(snapshot)
            if sharing and isAlive()then
                local ok,reason=pcall(publish,snapshot)
                if not ok then status("Shared appearance: "..tostring(reason))end
            end
        end)
    end
    local function watchPlayer(player)
        if player==localPlayer then return end
        local ok,connection=pcall(function()return player.CharacterAdded:Connect(function()
            local key=tostring(player.UserId)
            if latestRecords[key]then pending[key]=latestRecords[key];processPending()end
        end)end)
        if ok then connections[#connections+1]=function()connection:Disconnect()end end
    end
    for _,player in ipairs(Players:GetPlayers())do watchPlayer(player)end
    pcall(function()
        local added=Players.PlayerAdded:Connect(watchPlayer)
        local removed=Players.PlayerRemoving:Connect(function(player)
            local key=tostring(player.UserId);pending[key]=false;processPending()
        end)
        connections[#connections+1]=function()added:Disconnect();removed:Disconnect()end
    end)
    local api={}
    function api.setEnabled(value)
        value=value==true
        if sharing==value then return api.status()end
        generation=generation+1;lastSent=nil
        if sharing then
            sharing=false
            if transport then pcall(transport.setSharing,{enabled=false})end
            pending={};latestRecords={};cleanupAll();status("Shared Larp mode is off.")
        elseif value then
            sharing=true
            local ok,reason=pcall(publish)
            if not ok then sharing=false;error(reason,0)end
            status("Sharing your Larp appearance through desktop.")
        end
        return api.status()
    end
    function api.isEnabled()return sharing end
    function api.status()return sharing and "Shared Larp mode: ON" or "Shared Larp mode: OFF"end
    function api.destroy()
        if sharing and transport then pcall(transport.setSharing,{enabled=false})end
        sharing=false;generation=generation+1;cleanupAll()
        for _,disconnect in ipairs(connections)do pcall(disconnect)end
        connections={};pending={};latestRecords={}
    end
    return api
end
