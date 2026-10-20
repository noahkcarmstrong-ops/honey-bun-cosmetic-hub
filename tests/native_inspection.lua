-- Roblox-shaped fixture for the supported local Avatar Inspect Menu bridge.
local function signal()
 local listeners={}
 return {Connect=function(_,fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;listeners[#listeners+1]={c,fn};return c end,
 Fire=function(_,...)for _,entry in ipairs(listeners)do if entry[1].Connected then entry[2](...)end end end}
end
local function node(class,name,parent)
    local x={ClassName=class,Name=name or class,Visible=true,Enabled=true,Text="",children={},destroyed=false,DescendantAdded=signal(),signals={}}
    function x:IsA(k)return k==self.ClassName or k=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel")end
    function x:GetDescendants()
        local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out
    end
    function x:GetPropertyChangedSignal(key)self.signals[key]=self.signals[key] or signal();return self.signals[key]end
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
    function x:GetAccessories()return self.accessories or {}end
    function x:Destroy()self.destroyed=true end
    return x
end}
Enum={AccessoryType={Hat="Hat",Hair="Hair",Back="Back",Jacket="Jacket",Face="Face"}}
Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local http={JSONEncode=function(_,v)return v.version..":"..(v.items[1] and v.items[1].id or "")end}
local gui={InspectPlayerFromHumanoidDescription=function(_,desc,name)
    inspectCalls[#inspectCalls+1]={description=desc,name=name}
end,InspectPlayerFromUserId=function(_,id)restoreCalls[#restoreCalls+1]=id end}
local core=node("CoreGui","CoreGui")
local inspect=child(core,"Frame","InspectAndBuy")
local title=child(inspect,"TextLabel","Title");title.Text="Original's Avatar"
local viewport=child(inspect,"ViewportFrame","AvatarViewport");viewport.ImageTransparency=0.2
local world=child(viewport,"WorldModel","WorldModel")
local model=child(world,"Model","Avatar")
local renderedHumanoid=child(model,"Humanoid","Humanoid")
local modelDescription
function renderedHumanoid:GetAppliedDescription()return modelDescription end
local other=child(core,"Frame","OtherInspectAndBuy");local otherTitle=child(other,"TextLabel","Title");otherTitle.Text="Other's Avatar"
local hidden=child(core,"Frame","HiddenInspectAndBuy");hidden.Visible=false;local hiddenTitle=child(hidden,"TextLabel","Title");hiddenTitle.Text="Original's Avatar"
game={GetService=function(_,name)
    if name=="CoreGui"then return core elseif name=="GuiService"then return gui elseif name=="HttpService"then return http end
end}
local module=dofile("native_inspection.lua")
local player={Name="Original",UserId=123}
local api=module.create(player)
local snapshot={version=1,definition={assets={{id=100,meta=nil},{id=200,meta={order=3,puffiness=0.35}}},scales={height=1.1,width=0.9,depth=1.05,head=1.2,proportion=0.4,bodyType=0.7},bodyColors={headColor="#112233",torsoColor="445566"}},items={{id=100,assetType=11},{id=200,assetType=67},{id=301,assetType=8},{id=302,assetType=41},{id=303,assetType=42},{id=304,assetType=79},{id=305,assetType=12},{id=306,assetType=8}}}
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(#inspectCalls==1 and inspectCalls[1].name=="LarpAlias","local native inspection is requested with the alias")
assert(viewport.ImageTransparency==1,"the account preview is hidden before native loading starts")
local d=inspectCalls[1].description
assert(not d.destroyed,"native inspector must retain the description while asynchronous avatar and item loading use it")
assert(d.Head==304 and d.Pants==305 and #d.accessories==5,"head, pants and every equipped accessory reach the native description")
local nativeIds={};for _,item in ipairs(d.accessories)do nativeIds[item.AssetId]=true end
assert(nativeIds[200] and nativeIds[301] and nativeIds[302] and nativeIds[303] and nativeIds[306],"the full Larp accessory set survives native conversion")
assert(d.Shirt==100 and d.accessories[1].AssetId==200 and d.accessories[1].IsLayered and d.accessories[1].Order==3 and d.accessories[1].Puffiness==0.35,"clothing and layered accessory metadata are preserved")
assert(d.HeightScale==1.1 and d.WidthScale==0.9 and d.DepthScale==1.05 and d.HeadScale==1.2 and d.ProportionScale==0.4 and d.BodyTypeScale==0.7,"body scales are preserved")
assert(d.HeadColor.R==17/255 and d.HeadColor.G==34/255 and d.HeadColor.B==51/255,"body colors are converted")
title.Text="LarpAlias's Avatar";api.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(#inspectCalls==1,"adopting the redirected title does not reopen in a loop")
-- A model being parented is insufficient: wait for its applied outfit to match.
modelDescription={GetAccessories=function()return {}end,Destroy=function()end}
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(viewport.ImageTransparency==1,"a stale account model remains blank")
viewport.ImageTransparency=0;viewport:GetPropertyChangedSignal("ImageTransparency"):Fire()
assert(viewport.ImageTransparency==1,"native opacity updates cannot reveal a stale model while loading")
modelDescription=setmetatable({Destroy=function()end},{__index=d})
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(viewport.ImageTransparency==0.2,"matching applied Larp appearance reveals the native preview")
local late=child(inspect,"ViewportFrame","LateViewport");late.ImageTransparency=0
core.DescendantAdded:Fire(late)
assert(late.ImageTransparency==1,"new native previews are hidden immediately without waiting for relay polling")
title.Text="OtherPerson's Avatar";title:GetPropertyChangedSignal("Text"):Fire()
assert(viewport.ImageTransparency==0.2 and late.ImageTransparency==0,"a reused inspector restores visibility for another player")
title.Text="LarpAlias's Avatar";title:GetPropertyChangedSignal("Text"):Fire()
local changed={version=2,definition=snapshot.definition,items={{id=100,assetType=11},{id=201,assetType=67}}};api.update({enabled=true,name="LarpAlias",snapshot=changed});assert(#inspectCalls==2,"an outfit change requests a fresh native inspection")
assert(viewport.ImageTransparency==1,"an outfit change blanks the previous preview while loading")
assert(d.destroyed and not inspectCalls[2].description.destroyed,"new inspection releases the old source and keeps the replacement alive")
assert(otherTitle.Text=="Other's Avatar" and hiddenTitle.Text=="Original's Avatar","other and hidden inspect screens are untouched")
api.update({enabled=false,name="LarpAlias"});assert(#restoreCalls==1 and restoreCalls[1]==123,"turning Larp mode off restores the platform avatar even while the redirected alias title is visible")
assert(viewport.ImageTransparency==0.2 and late.ImageTransparency==0,"mode off restores original native visibility")
assert(inspectCalls[2].description.destroyed,"mode off releases the retained source")
local blockedGui={InspectPlayerFromHumanoidDescription=function()error("blocked")end,InspectPlayerFromUserId=function()end}
game.GetService=function(_,name)if name=="CoreGui"then return core elseif name=="GuiService"then return blockedGui elseif name=="HttpService"then return http end end
local blocked=module.create(player);title.Text="Original's Avatar";blocked.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(blocked.report():find("blocked",1,true),"blocked native API access is reported")
Instance,Enum,Color3,game=old.Instance,old.Enum,old.Color3,old.game
print("Native inspection description, redirect adoption, lifecycle and blocked API checks passed.")
