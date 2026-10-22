-- Read a Roblox account outfit through native client APIs, never a live character.
return function(players)
    local cache,busy={},false
    local function validId(value)return type(value)=="number" and value>0 and value%1==0 and value<9007199254740992 end
    local function hex(color)
        local function component(v)return math.clamp(math.floor(v*255+0.5),0,255)end
        return string.format("%02x%02x%02x",component(color.R),component(color.G),component(color.B))
    end
    return function(target,account)
        assert(validId(target) and validId(tonumber(account)),"Invalid Roblox account.")
        local previous=cache[target]
        if previous and previous.expires>os.clock() then
            return {version=1,userId=tostring(account),definition=previous.definition,items=previous.items}
        end
        assert(not busy,"Another avatar lookup is in progress. Try again shortly.")
        busy=true
        local description
        local ok,value=pcall(function()
            description=players:GetHumanoidDescriptionFromUserIdAsync(target)
            -- The appearance dictionary supplies item names/types and the account's
            -- R6/R15 choice, which HumanoidDescription does not expose.
            local info=players:GetCharacterAppearanceInfoAsync(target)
            assert(type(info)=="table" and type(info.assets)=="table" and #info.assets<=100,"The account outfit could not be read.")
            assert(info.playerAvatarType=="R6" or info.playerAvatarType=="R15","The account body type could not be read.")
            local definition={assets={},bodyColors={},scales={},playerAvatarType={playerAvatarType=info.playerAvatarType}}
            local items,known={},{}
            for _,asset in ipairs(info.assets)do
                local kind=asset.assetType and asset.assetType.id
                assert(validId(asset.id) and validId(kind) and kind<=1000 and not known[asset.id],"Invalid account outfit item.")
                local name=tostring(asset.name or ("Item "..asset.id)):gsub("%c","")
                local finish=utf8.offset(name,129);if finish then name=name:sub(1,finish-1)end
                local entry={id=asset.id}
                if type(asset.meta)=="table" then entry.meta=asset.meta end
                known[asset.id]=entry;definition.assets[#definition.assets+1]=entry
                items[#items+1]={id=asset.id,name=name,itemType="Asset",assetType=kind}
            end
            local function requireAsset(id)
                assert(not validId(id) or known[id],"The account outfit changed during lookup. Try again.")
            end
            for _,accessory in ipairs(description:GetAccessories(true))do
                requireAsset(accessory.AssetId)
                if accessory.IsLayered then known[accessory.AssetId].meta={order=accessory.Order or 0,puffiness=accessory.Puffiness or 0}end
            end
            for _,property in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","Face","Shirt","Pants","GraphicTShirt"})do requireAsset(description[property])end
            for _,part in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do
                local name=part:sub(1,1):lower()..part:sub(2).."Color"
                definition.bodyColors[name]=hex(description[part.."Color"])
            end
            for _,pair in ipairs({{"HeightScale","height"},{"WidthScale","width"},{"DepthScale","depth"},{"HeadScale","head"},{"BodyTypeScale","bodyType"},{"ProportionScale","proportion"}})do
                definition.scales[pair[2]]=description[pair[1]]
            end
            return {definition=definition,items=items,expires=os.clock()+300}
        end)
        if description then pcall(function()description:Destroy()end)end
        busy=false
        if not ok then error(tostring(value),0)end
        local count,oldest,oldTime=0,nil,math.huge
        for id,entry in pairs(cache)do count=count+1;if entry.expires<oldTime then oldest,oldTime=id,entry.expires end end
        if count>=32 then cache[oldest]=nil end
        cache[target]=value
        return {version=1,userId=tostring(account),definition=value.definition,items=value.items}
    end
end
