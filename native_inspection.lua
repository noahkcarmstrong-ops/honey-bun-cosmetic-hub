-- Reopens only the local player's native avatar inspector with local cosmetic data.
local fields={[2]="GraphicTShirt",[11]="Shirt",[12]="Pants",[17]="Head",[79]="Head",[18]="Face",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[48]="ClimbAnimation",[50]="FallAnimation",[51]="IdleAnimation",[52]="JumpAnimation",[53]="RunAnimation",[54]="SwimAnimation",[55]="WalkAnimation"}
local accessoryTypes={[8]="Hat",[41]="Hair",[42]="Face",[43]="Neck",[44]="Shoulder",[45]="Front",[46]="Back",[47]="Waist",[64]="TShirt",[65]="Shirt",[66]="Pants",[67]="Jacket",[68]="Sweater",[69]="Shorts",[70]="LeftShoe",[71]="RightShoe",[72]="DressSkirt",[76]="Eyebrow",[77]="Eyelash"}
local scales={height="HeightScale",width="WidthScale",depth="DepthScale",head="HeadScale",proportion="ProportionScale",bodyType="BodyTypeScale"}
local colors={headColor="HeadColor",torsoColor="TorsoColor",leftArmColor="LeftArmColor",rightArmColor="RightArmColor",leftLegColor="LeftLegColor",rightLegColor="RightLegColor"}
local function description(snapshot)
    assert(type(snapshot)=="table" and type(snapshot.definition)=="table" and type(snapshot.items)=="table","Local outfit is not ready.")
    local desc=Instance.new("HumanoidDescription")
    local ok,err=pcall(function()
        local metadata={}
        for _,asset in ipairs(snapshot.definition.assets or {})do metadata[asset.id]=asset.meta end
        local accessories={}
        for _,item in ipairs(snapshot.items)do
            local field=fields[item.assetType]
            if field then desc[field]=item.id
            elseif accessoryTypes[item.assetType]then
                local kind=Enum.AccessoryType[accessoryTypes[item.assetType]]
                assert(kind,"Roblox does not support this accessory type.")
                local meta=metadata[item.id]
                local layered=item.assetType>=64 and item.assetType<=72
                local entry={AssetId=item.id,AccessoryType=kind,IsLayered=layered}
                if layered then entry.Order=meta and meta.order or #accessories;entry.Puffiness=meta and meta.puffiness or 0 end
                accessories[#accessories+1]=entry
            end
        end
        desc:SetAccessories(accessories,true)
        for name,field in pairs(scales)do local value=snapshot.definition.scales and snapshot.definition.scales[name];if value~=nil then desc[field]=value end end
        for name,field in pairs(colors)do
            local value=snapshot.definition.bodyColors and snapshot.definition.bodyColors[name]
            if value then
                value=value:gsub("^#","")
                assert(value:match("^%x%x%x%x%x%x$"),"Local skin color is invalid.")
                desc[field]=Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16))
            end
        end
    end)
    if not ok then desc:Destroy();error(err)end
    return desc
end
local M={description=description}
function M.create(player)
    local core,gui
    pcall(function() core=game:GetService("CoreGui");gui=game:GetService("GuiService")end)
    local active=false
    local activeDescription
    local function releaseDescription()
        if activeDescription then activeDescription:Destroy();activeDescription=nil end
    end
    local lastSignature,lastLabel,adopting,lastName,status=nil,nil,false,nil,"Inspector is waiting."
    local function visible(object)
        local current=object
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current=current.Parent
        end
        return true
    end
    local function ownTitle(alias)
        local objects={};pcall(function()objects=core:GetDescendants()end)
        for _,object in ipairs(objects)do
            if object:IsA("TextLabel") and visible(object) then
                local text=object.Text
                local scoped=false
                local ancestor=object.Parent
                while ancestor do
                    if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu" then scoped=true;break end
                    ancestor=ancestor.Parent
                end
                if scoped and (text==player.Name.."'s Avatar" or (active and (object==lastLabel or adopting) and (text==alias.."'s Avatar" or (lastName and text==lastName.."'s Avatar"))))then
                    return object,text
                end
            end
        end
    end
    local api={}
    function api.update(options)
        local enabled=options.enabled==true
        local alias=tostring(options.name or "")
        local name=alias~="" and alias or player.Name
        local label,title=ownTitle(name)
        if not enabled then
            if active and label then pcall(function()gui:InspectPlayerFromUserId(player.UserId)end)end
            releaseDescription()
            active=false;lastLabel=nil;lastSignature=nil;adopting=false;lastName=nil
            return
        end
        if not label then lastLabel=nil;lastSignature=nil;adopting=false;return end
        if not options.snapshot then status="Waiting for the local outfit.";return end
        local signature=game:GetService("HttpService"):JSONEncode(options.snapshot)..name
        if active and lastSignature==signature and adopting then lastLabel=label;adopting=false;return end
        if active and lastLabel==label and lastSignature==signature then return end
        local desc=description(options.snapshot)
        local ok,err=pcall(function()gui:InspectPlayerFromHumanoidDescription(desc,name)end)
        -- Roblox loads preview models and AccessoryDescription children asynchronously.
        -- Keep the source alive until Larp mode stops or a newer inspection replaces it.
        if ok then releaseDescription();activeDescription=desc;active=true;lastLabel=label;lastSignature=signature;adopting=true;lastName=name;status="Native local outfit inspection requested."
        else desc:Destroy();status="Roblox blocked the local avatar inspector: "..tostring(err)end
    end
    function api.report()return status end
    function api.destroy()api.update({enabled=false,name=""})end
    return api
end
return M
