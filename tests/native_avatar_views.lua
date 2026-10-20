-- Roblox-shaped ownership and lifecycle checks for native player thumbnails.
local function node(class, name)
    local x = {ClassName=class, Name=name, children={}, attrs={}}
    function x:IsA(k) return k == self.ClassName end
    function x:GetDescendants()
        local out={}; local function walk(v) for _, child in ipairs(v.children) do out[#out+1]=child;walk(child) end end;walk(self);return out
    end
    function x:GetAttribute(k) return self.attrs[k] end
    function x:Destroy() self.destroyed=true;self.Parent=nil end
    return setmetatable(x,{__index=function(t,k) if k=="Parent" then return rawget(t,"parent") end;return rawget(t,k) end,__newindex=function(t,k,v)
        if k=="Parent" then rawset(t,"parent",v);if v then v.children[#v.children+1]=t end else rawset(t,k,v) end
    end})
end
local function add(parent, class, name)
    local x=node(class,name);x.Parent=parent;return x
end
local core=node("CoreGui","CoreGui")
local row=add(core,"Frame","PlayerEntry_123")
local thumb=add(row,"ImageLabel","AvatarImage");thumb.ImageTransparency=0.25;thumb.Image="rbxthumb://type=AvatarHeadShot&id=123&w=48&h=48"
local rowIcon=add(row,"ImageLabel","Icon");rowIcon.Image="rbxassetid://inspect"
local other=add(core,"Frame","PlayerEntry_456")
local otherThumb=add(other,"ImageLabel","AvatarImage");otherThumb.Image="rbxthumb://type=AvatarHeadShot&id=456&w=48&h=48"
local people=add(core,"Frame","People");local list=add(people,"Frame","ScrollingFrame");local ownPeopleRow=add(list,"Frame","OwnPeopleRow")
local label=add(ownPeopleRow,"TextLabel","Name");label.Text="@LocalAlias"
local peopleThumb=add(ownPeopleRow,"ImageButton","AvatarThumbnail");peopleThumb.Image="rbxassetid://static"
local otherPeopleRow=add(list,"Frame","OtherPeopleRow");local otherPeopleLabel=add(otherPeopleRow,"TextLabel","Name");otherPeopleLabel.Text="@OtherUser"
local otherPeopleThumb=add(otherPeopleRow,"ImageButton","AvatarThumbnail");otherPeopleThumb.Image="rbxassetid://static"
local static=add(core,"ImageLabel","Icon");static.Image="rbxassetid://icon"
local InstanceOld, gameOld, taskOld, UDim2Old = Instance, game, task, UDim2
Instance={new=function(class) return node(class,class) end}
UDim2={fromScale=function(x,y)return{x=x,y=y}end}
game={GetService=function(_,name)assert(name=="CoreGui");return core end}
task=nil
local module=dofile("native_avatar_views.lua")
local player={Name="Original",UserId=123,Character={}}
assert(module.isAvatarImage(thumb,player,{name="LocalAlias"}),"exact local AvatarHeadShot is owned")
assert(not module.isAvatarImage(rowIcon,player,{name="LocalAlias"}),"unrelated icon in an owned row is excluded")
assert(not module.isAvatarImage(otherThumb,player,{name="LocalAlias"}),"another player's thumbnail is excluded")
assert(module.isAvatarImage(peopleThumb,player,{name="LocalAlias"}),"unique People alias row is owned")
label.Text="@Original";assert(module.isAvatarImage(peopleThumb,player,{name=""}),"blank alias falls back to the real username");label.Text="@LocalAlias"
label.Text="@Original";assert(module.isAvatarImage(peopleThumb,player,{name="LocalAlias"}),"real username remains owned while alias rewrite is pending");label.Text="@LocalAlias"
assert(not module.isAvatarImage(otherPeopleThumb,player,{name="LocalAlias"}),"another People row is excluded")
assert(not module.isAvatarImage(static,player,{name="LocalAlias"}),"static icons are excluded")
local captures, shows, shownData=0,0,nil
local api=module.create(player,function() return {capture=function()captures=captures+1;return {live=true,serial=captures}end,show=function(frame,data)shows=shows+1;shownData=data;frame.CurrentCamera={};return true end} end)
api.update({enabled=true,name="LocalAlias",snapshot=nil})
assert(captures==0 and shows==0 and thumb.ImageTransparency==1,"nil effective snapshot stays blank without capturing the live avatar")
local effective={definition={shirt="effective"},items={1,2}}
api.update({enabled=true,name="LocalAlias",snapshot=effective})
assert(shows==2 and captures==1 and shownData ~= effective,"effective outfit signature drives one cached live capture")
assert(thumb.ImageTransparency==1,"original image is hidden only after a successful render")
api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
assert(shows==4 and captures==2,"a changed effective snapshot refreshes overlays once")
api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
assert(shows==4 and captures==2,"periodic scans reuse unchanged overlays and captures")
local report=api.report();assert(report:find("active",1,true) and report:find("rendered: 4",1,true),"report states active rendering accurately")
api.update({enabled=false,name="LocalAlias",snapshot={version=1}})
local overlayGone=true;for _,child in ipairs(row:GetDescendants())do if child.Name=="LarpbloxOwnAvatarPreview" and child.Parent then overlayGone=false end end
assert(overlayGone,"destroying overlays restores the original image children")
assert(thumb.ImageTransparency==0.25,"disabling restores original image transparency")
api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
assert(captures==3 and thumb.ImageTransparency==1,"reenabling captures again and hides the original")
api.destroy()
assert(thumb.ImageTransparency==0.25,"destroy restores the native image")
local retryCaptures, retryShows=0,0
local retry=module.create(player,function() return {capture=function()
    retryCaptures=retryCaptures+1;if retryCaptures==1 then error("character not ready") end;return {live=true}
end,show=function(frame) retryShows=retryShows+1;frame.CurrentCamera={};return true end} end)
retry.update({enabled=true,name="LocalAlias",snapshot=effective})
assert(retryCaptures==1 and retryShows==0,"capture failure leaves thumbnails untouched")
retry.update({enabled=true,name="LocalAlias",snapshot=effective})
assert(retryCaptures==2 and retryShows==2,"capture retries when the cached preview is missing")
retry.update({enabled=false,name="LocalAlias",snapshot=effective});retry.destroy()
local failed=module.create(player,function() return {capture=function()return {live=true}end,show=function()return false end} end)
failed.update({enabled=true,name="LocalAlias",snapshot=effective})
assert(thumb.ImageTransparency==1,"render failure keeps the original avatar blank")
failed.update({enabled=false,name="LocalAlias",snapshot=effective});failed.destroy()
Instance,game,task,UDim2=InstanceOld,gameOld,taskOld,UDim2Old
print("Native avatar ownership and overlay lifecycle passed.")
