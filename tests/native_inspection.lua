-- Roblox-shaped fixture for the supported local Avatar Inspect Menu bridge.
local function node(class,name,parent)
    local x={ClassName=class,Name=name or class,Visible=true,Enabled=true,Text="",children={},destroyed=false}
    function x:IsA(k)return k==self.ClassName or k=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel")end
    function x:GetDescendants()
        local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out
    end
    function x:Destroy()self.destroyed=true;self.Parent=nil end
    return setmetatable(x,{__index=function(t,k)if k=="Parent"then return rawget(t,"parent")end;return rawget(t,k)end,__newindex=function(t,k,v)
        if k=="Parent"then rawset(t,"parent",v);if v then v.children[#v.children+1]=t end else rawset(t,k,v)end
    end})
end
local function child(parent,class,name)local x=node(class,name);x.Parent=parent;return x end

local old={Instance=Instance,Enum=Enum,Color3=Color3,game=game}
local descriptions,inspectCalls,restoreCalls= {},{},{}
Instance={new=function(class)
    local x=node(class,class)
    function x:SetAccessories(v,includeRigid)self.accessories=v;self.includeRigid=includeRigid end
    function x:Destroy()self.destroyed=true end
    return x
end}
Enum={AccessoryType={Hat="Hat",Hair="Hair",Back="Back",Jacket="Jacket"}}
Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local http={JSONEncode=function(_,v)return v.version..":"..(v.items[1] and v.items[1].id or "")end}
local gui={InspectPlayerFromHumanoidDescription=function(_,desc,name)
    inspectCalls[#inspectCalls+1]={description=desc,name=name}
end,InspectPlayerFromUserId=function(_,id)restoreCalls[#restoreCalls+1]=id end}
local core=node("CoreGui","CoreGui")
local inspect=child(core,"Frame","InspectAndBuy")
local title=child(inspect,"TextLabel","Title");title.Text="Original's Avatar"
local other=child(core,"Frame","OtherInspectAndBuy");local otherTitle=child(other,"TextLabel","Title");otherTitle.Text="Other's Avatar"
local hidden=child(core,"Frame","HiddenInspectAndBuy");hidden.Visible=false;local hiddenTitle=child(hidden,"TextLabel","Title");hiddenTitle.Text="Original's Avatar"
game={GetService=function(_,name)
    if name=="CoreGui"then return core elseif name=="GuiService"then return gui elseif name=="HttpService"then return http end
end}
local module=dofile("native_inspection.lua")
local player={Name="Original",UserId=123}
local api=module.create(player)
local snapshot={version=1,definition={assets={{id=100,meta=nil},{id=200,meta={order=3,puffiness=0.35}}},scales={height=1.1,width=0.9,depth=1.05,head=1.2,proportion=0.4,bodyType=0.7},bodyColors={headColor="#112233",torsoColor="445566"}},items={{id=100,assetType=11},{id=200,assetType=67}}}
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(#inspectCalls==1 and inspectCalls[1].name=="LarpAlias","local native inspection is requested with the alias")
local d=inspectCalls[1].description
assert(d.Shirt==100 and d.accessories[1].AssetId==200 and d.accessories[1].IsLayered and d.accessories[1].Order==3 and d.accessories[1].Puffiness==0.35,"clothing and layered accessory metadata are preserved")
assert(d.HeightScale==1.1 and d.WidthScale==0.9 and d.DepthScale==1.05 and d.HeadScale==1.2 and d.ProportionScale==0.4 and d.BodyTypeScale==0.7,"body scales are preserved")
assert(d.HeadColor.R==17/255 and d.HeadColor.G==34/255 and d.HeadColor.B==51/255,"body colors are converted")
title.Text="LarpAlias's Avatar";api.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(#inspectCalls==1,"adopting the redirected title does not reopen in a loop")
local changed={version=2,definition=snapshot.definition,items={{id=100,assetType=11},{id=201,assetType=67}}};api.update({enabled=true,name="LarpAlias",snapshot=changed});assert(#inspectCalls==2,"an outfit change requests a fresh native inspection")
assert(otherTitle.Text=="Other's Avatar" and hiddenTitle.Text=="Original's Avatar","other and hidden inspect screens are untouched")
api.update({enabled=false,name="LarpAlias"});assert(#restoreCalls==1 and restoreCalls[1]==123,"turning Larp mode off restores the platform avatar even while the redirected alias title is visible")
local blockedGui={InspectPlayerFromHumanoidDescription=function()error("blocked")end,InspectPlayerFromUserId=function()end}
game.GetService=function(_,name)if name=="CoreGui"then return core elseif name=="GuiService"then return blockedGui elseif name=="HttpService"then return http end end
local blocked=module.create(player);title.Text="Original's Avatar";blocked.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(blocked.report():find("blocked",1,true),"blocked native API access is reported")
Instance,Enum,Color3,game=old.Instance,old.Enum,old.Color3,old.game
print("Native inspection description, redirect adoption, lifecycle and blocked API checks passed.")
