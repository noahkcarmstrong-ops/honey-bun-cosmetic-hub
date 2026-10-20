-- Opt-in, local rendering of Larpblox appearances shared by clients in the same Roblox server.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local RELAY="https://larp.3xjn.dev"
local POLL_SECONDS=3
local PUBLISH_SECONDS=10
local ACCESSORY_TYPES={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
local BODY_TYPES={[17]="Head",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[79]="Head"}
local CLOTHES_TYPES={[2]="ShirtGraphic",[11]="Shirt",[12]="Pants"}
local ANIMATION_TYPES={[48]=true,[50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,[56]=true}
local COLOR_REGIONS={{"Head","headColor"},{"Torso","torsoColor"},{"LeftArm","leftArmColor"},{"RightArm","rightArmColor"},{"LeftLeg","leftLegColor"},{"RightLeg","rightLegColor"}}

local function safeId(value)
    local n=tonumber(value)
    return n and n>0 and n%1==0 and n<9007199254740992 and n or nil
end

return function(localPlayer,getSnapshot,getNameSettings,createAvatar,createClothes,createAnimations,createNames,isAlive,onStatus)
    local sharing=false
    local generation=0
    local peers={}
    local lastSent,lastPublished="",0
    local nextStatus=0
    local function status(message)
        if onStatus and os.clock()>=nextStatus then nextStatus=os.clock()+4;onStatus(message)end
    end
    local function roomPath()
        local placeId=tonumber(game.PlaceId)
        local jobId=tostring(game.JobId or "")
        assert(placeId and placeId>0 and placeId%1==0,"Join a live Roblox server before enabling shared Larp mode.")
        assert(jobId~="" and jobId~="00000000-0000-0000-0000-000000000000","Shared Larp mode is available in live game servers, not Studio.")
        assert(jobId:match("^[A-Za-z0-9%-]+$"),"This game server has an unsupported instance ID.")
        return "/v1/rooms/"..string.format("%.0f",placeId).."/"..jobId
    end
    local function callRelay(method,path,body)
        local fn=request or http_request or (syn and syn.request)
        assert(type(fn)=="function","This executor does not provide an HTTPS request function.")
        local response=fn({Url=RELAY..path,Method=method,Headers={ ["Content-Type"]="application/json" },Body=body and HttpService:JSONEncode(body) or nil,Timeout=6})
        local code=tonumber(response and (response.StatusCode or response.Status))
        assert(code and code>=200 and code<300,"Shared Larp relay returned HTTP "..tostring(code or "unknown"))
        return response.Body and HttpService:JSONDecode(response.Body) or {}
    end
    local function cleanupPeer(userId)
        local entry=peers[userId]
        if not entry then return end
        peers[userId]=nil
        for _,api in ipairs({entry.names,entry.animations,entry.clothes,entry.avatar})do
            if api and api.destroy then pcall(api.destroy)end
        end
    end
    local function cleanupAll()
        for userId in pairs(peers)do cleanupPeer(userId)end
    end
    local function peerApis(player)
        local playerGui
        pcall(function()playerGui=player:FindFirstChildOfClass("PlayerGui")end)
        local function callback(message)status("Shared appearance for "..player.Name..": "..tostring(message))end
        return {
            avatar=createAvatar(player,callback),
            clothes=createClothes(player,callback),
            animations=createAnimations(player,callback),
            names=createNames(player,playerGui),
            player=player,
        }
    end
    local function validRecord(record)
        if type(record)~="table" or record.version~=1 or type(record.userId)~="string" then return false end
        local snapshot=record.snapshot
        if type(snapshot)~="table" or snapshot.version~=1 or tostring(snapshot.userId)~=record.userId then return false end
        if not safeId(record.userId) or type(snapshot.definition)~="table" or type(snapshot.definition.assets)~="table" or #snapshot.definition.assets>100 or type(snapshot.items)~="table" or #snapshot.items>100 then return false end
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
        local fingerprint=HttpService:JSONEncode({snapshot=snapshot,name=record.name})
        local entry=peers[record.userId]
        if entry and entry.player==target and entry.fingerprint==fingerprint then return end
        if entry then cleanupPeer(record.userId)end
        entry=peerApis(target);peers[record.userId]=entry
        local ok,err=pcall(function()
            -- Start from the locally captured original so each newer record replaces the previous overlay cleanly.
            entry.avatar.restore();entry.clothes.restore();entry.animations.restore();entry.names.restore()
            local wanted={}
            local wantedClothes={}
            local animationAssets={}
            for _,item in ipairs(snapshot.items)do
                if type(item)=="table" and safeId(item.id) and tonumber(item.assetType) then
                    local assetType=tonumber(item.assetType)
                    if ACCESSORY_TYPES[assetType] then wanted[#wanted+1]=item
                    elseif BODY_TYPES[assetType] then pcall(entry.avatar.applyBodyPart,BODY_TYPES[assetType],item.id)
                    elseif assetType==18 then pcall(entry.avatar.applyFace,item.id)
                    elseif CLOTHES_TYPES[assetType]=="ShirtGraphic" then wantedClothes.ShirtGraphic=true;pcall(entry.clothes.equipTShirt,item.id)
                    elseif CLOTHES_TYPES[assetType]=="Shirt" then wantedClothes.Shirt=true;pcall(entry.clothes.equipShirt,item.id)
                    elseif CLOTHES_TYPES[assetType]=="Pants" then wantedClothes.Pants=true;pcall(entry.clothes.equipPants,item.id)
                    elseif assetType==19 then pcall(entry.avatar.equipGear,item.id)
                    elseif ANIMATION_TYPES[assetType] then animationAssets[#animationAssets+1]={id=item.id,assetType=assetType}
                    end
                end
            end
            entry.avatar.removeCurrentAccessories()
            for _,item in ipairs(wanted)do pcall(entry.avatar.equipAccessory,item.id)end
            if not wantedClothes.ShirtGraphic then pcall(entry.clothes.removeTShirt)end
            if not wantedClothes.Shirt then pcall(entry.clothes.removeShirt)end
            if not wantedClothes.Pants then pcall(entry.clothes.removePants)end
            local colors=snapshot.definition.bodyColors or {}
            for _,pair in ipairs(COLOR_REGIONS)do
                local value=colors[pair[2]]
                if type(value)=="string" and value:match("^#?%x%x%x%x%x%x$")then
                    value=value:gsub("^#","")
                    entry.avatar.setSkin(Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)),pair[1])
                end
            end
            if #animationAssets>0 then pcall(entry.animations.equipAssets,animationAssets)end
            local name=record.name
            if type(name)=="table" and name.enabled then pcall(entry.names.set,name.username,name.displayName)end
        end)
        if ok then entry.fingerprint=fingerprint else
            cleanupPeer(record.userId)
            status("Could not apply a shared appearance: "..tostring(err))
        end
    end
    local function publish()
        local snapshot=getSnapshot()
        local name=getNameSettings and getNameSettings() or {enabled=false,username="",displayName=""}
        local record={version=1,userId=tostring(localPlayer.UserId),snapshot=snapshot,name=name}
        local encoded=HttpService:JSONEncode(record)
        if encoded==lastSent and os.clock()-lastPublished<PUBLISH_SECONDS then return end
        callRelay("PUT",roomPath().."/players/"..tostring(localPlayer.UserId),record)
        lastSent=encoded;lastPublished=os.clock()
    end
    local function loop(mine)
        while sharing and generation==mine and isAlive() do
            local ok,err=pcall(function()
                publish()
                local result=callRelay("GET",roomPath().."/players?excludeUserId="..tostring(localPlayer.UserId))
                assert(type(result.players)=="table","Shared Larp relay returned an invalid player list.")
                local seen={}
                for _,record in ipairs(result.players)do if validRecord(record)then seen[record.userId]=true;applyRecord(record)end end
                for userId in pairs(peers)do if not seen[userId]or not Players:GetPlayerByUserId(tonumber(userId))then cleanupPeer(userId)end end
            end)
            if not ok then status("Shared Larp relay: "..tostring(err):gsub("^.-:%d+:%s*",""))end
            task.wait(POLL_SECONDS)
        end
    end
    local api={}
    function api.setEnabled(value)
        value=value==true
        if sharing==value then return api.status()end
        sharing=value;generation=generation+1;lastSent="";lastPublished=0
        local mine=generation
        if sharing then
            status("Sharing your Larp appearance with users in this Roblox server.")
            task.spawn(function()loop(mine)end)
        else
            pcall(function()callRelay("DELETE",roomPath().."/players/"..tostring(localPlayer.UserId))end)
            cleanupAll();status("Shared Larp mode is off.")
        end
        return api.status()
    end
    function api.isEnabled()return sharing end
    function api.status()return sharing and "Shared Larp mode: ON" or "Shared Larp mode: OFF"end
    function api.destroy()
        if sharing then pcall(function()callRelay("DELETE",roomPath().."/players/"..tostring(localPlayer.UserId))end)end
        sharing=false;generation=generation+1;cleanupAll()
    end
    return api
end
