-- Roblox-shaped ownership and lifecycle checks for native player thumbnails.
local function node(class, name)
    local x = {ClassName=class, Name=name, children={}, attrs={}}
    function x:IsA(k) return k == self.ClassName end
    function x:GetDescendants()
        local out={}; local function walk(v) for _, child in ipairs(v.children) do out[#out+1]=child;walk(child) end end;walk(self);return out
    end
    x.signals={}
    function x:GetPropertyChangedSignal(k)
        self.signals[k]=self.signals[k] or {callbacks={}}
        local signal=self.signals[k]
        function signal:Connect(f) self.callbacks[#self.callbacks+1]=f;return {Disconnect=function()end} end
        return signal
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
local thumb=add(row,"ImageLabel","AvatarImage");thumb.ZIndex=2;thumb.ImageTransparency=0.25;thumb.Image="rbxthumb://type=AvatarHeadShot&id=123&w=48&h=48"
local nativeCorner=add(thumb,"UICorner","UICorner");nativeCorner.CornerRadius={Scale=0.5,Offset=0}
local rowIcon=add(row,"ImageLabel","Icon");rowIcon.Image="rbxassetid://inspect"
local other=add(core,"Frame","PlayerEntry_456")
local otherThumb=add(other,"ImageLabel","AvatarImage");otherThumb.Image="rbxthumb://type=AvatarHeadShot&id=456&w=48&h=48"
local people=add(core,"Frame","People");local list=add(people,"Frame","ScrollingFrame");local ownPeopleRow=add(list,"Frame","OwnPeopleRow")
local label=add(ownPeopleRow,"TextLabel","Name");label.Text="@LocalAlias"
local peopleThumb=add(ownPeopleRow,"ImageButton","AvatarThumbnail");peopleThumb.Image="rbxassetid://static"
local otherPeopleRow=add(list,"Frame","OtherPeopleRow");local otherPeopleLabel=add(otherPeopleRow,"TextLabel","Name");otherPeopleLabel.Text="@OtherUser"
local otherPeopleThumb=add(otherPeopleRow,"ImageButton","AvatarThumbnail");otherPeopleThumb.Image="rbxassetid://static"
local static=add(core,"ImageLabel","Icon");static.Image="rbxassetid://icon"
local UDimOld=UDim
UDim={new=function(scale,offset)return {Scale=scale,Offset=offset}end}
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
local profile=add(core,"Frame","Profile");local container=add(profile,"Frame","Container")
local characterIcon=add(container,"ImageLabel","CharacterIcon");characterIcon.Image="https://tr.rbxcdn.com/bust-thumbnail/image?userId=7446730&width=150"
local profileName=add(profile,"TextLabel","Name");profileName.Text="Original (You)"
local otherProfile=add(core,"Frame","Profile");local otherIcon=add(otherProfile,"ImageLabel","CharacterIcon");otherIcon.Image="https://tr.rbxcdn.com/bust-thumbnail/image?userId=999&width=150"
local otherName=add(otherProfile,"TextLabel","Name");otherName.Text="Nikilis1848960"
assert(module.isAvatarImage(characterIcon,{Name="Original",DisplayName="Original",UserId=7446730},{name="LocalAlias"}),"own Roblox CDN profile thumbnail is recognized")
assert(not module.isAvatarImage(otherIcon,{Name="Original",DisplayName="Original",UserId=7446730},{name="LocalAlias"}),"same CDN thumbnail in another profile is excluded")
local avatarAshx=add(core,"ImageLabel","Avatar");avatarAshx.Image="http://www.roblox.com/Thumbs/Avatar.ashx?userId=7446730&x=1"
local wrongAshx=add(core,"ImageLabel","Avatar");wrongAshx.Image="http://evil.example.com/Thumbs/Avatar.ashx?userId=7446730&x=1"
assert(module.isAvatarImage(avatarAshx,{Name="Original",UserId=7446730},{}),"legacy Roblox avatar thumbnail is recognized")
assert(not module.isAvatarImage(wrongAshx,{Name="Original",UserId=7446730},{}),"untrusted thumbnail host is excluded")
characterIcon.Image="";otherIcon.Image="";avatarAshx.Image="";wrongAshx.Image=""
local captures, shows, shownData=0,0,nil
local api=module.create(player,function() return {capture=function()captures=captures+1;return {live=true,serial=captures}end,show=function(frame,data)for _,child in ipairs(frame.children)do child:Destroy()end;frame.children={};shows=shows+1;shownData=data;frame.CurrentCamera={};return true end} end)
api.update({enabled=true,name="LocalAlias",snapshot=nil})
assert(captures==0 and shows==0 and thumb.ImageTransparency==1,"nil effective snapshot stays blank without capturing the live avatar")
local effective={definition={shirt="effective"},items={1,2}}
api.update({enabled=true,name="LocalAlias",snapshot=effective})
assert(shows==2 and captures==1 and shownData ~= effective,"effective outfit signature drives one cached live capture")
assert(thumb.ImageTransparency==1,"original image is hidden only after a successful render")
local portraitOverlay
for _,child in ipairs(thumb.children)do if child.Name=="LarpbloxOwnAvatarPreview" then portraitOverlay=child end end
assert(portraitOverlay and portraitOverlay.ZIndex==thumb.ZIndex,"portrait must preserve the native image layer below level badges")
local copiedCorner=portraitOverlay.children[1]
assert(copiedCorner and copiedCorner.ClassName=="UICorner" and copiedCorner.CornerRadius==nativeCorner.CornerRadius,"replacement portrait copies the exact native rounding")
local peopleOverlay=peopleThumb.children[1]
assert(peopleOverlay.children[1].CornerRadius.Scale==0.5,"People portraits remain circular even when the source uses a baked image mask")


api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
assert(shows==4 and captures==2,"a changed effective snapshot refreshes overlays once")
local scansBefore=api.report():match("Scans: (%d+)")
api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
assert(api.report():match("Scans: (%d+)")==scansBefore,"unchanged sync updates do not rescan the entire game UI")
assert(shows==4 and captures==2,"periodic scans reuse unchanged overlays and captures")
local coreReads=0;local originalDescendants=core.GetDescendants
core.GetDescendants=function(self)coreReads=coreReads+1;return originalDescendants(self)end
for _,callback in ipairs(otherPeopleLabel.signals.Text.callbacks)do callback()end
assert(coreReads==0,"other player text updates must not rescan all CoreGui")
core.GetDescendants=originalDescendants
local report=api.report();assert(report:find("active",1,true) and report:find("rendered: 4",1,true),"report states active rendering accurately")
api.update({enabled=false,name="LocalAlias",snapshot={version=1}})
local overlayGone=true;for _,child in ipairs(row:GetDescendants())do if child.Name=="LarpbloxOwnAvatarPreview" and child.Parent then overlayGone=false end end
assert(overlayGone,"destroying overlays restores the original image children")
assert(thumb.ImageTransparency==0.25,"disabling restores original image transparency")
api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
assert(captures==3 and thumb.ImageTransparency==1,"reenabling captures again and hides the original")
api.update({enabled=true,name="LocalAlias",image="rbxassetid://custom-avatar"})
local imageOverlay
for _,child in ipairs(row:GetDescendants())do if child.Name=="LarpbloxOwnAvatarPreview" and child.Parent then imageOverlay=child end end
assert(imageOverlay and imageOverlay.ClassName=="ImageLabel" and imageOverlay.Image=="rbxassetid://custom-avatar" and thumb.ImageTransparency==1,"custom avatar images use a full-size image overlay")
api.update({enabled=true,name="LocalAlias",snapshot={version=1}})
local viewportOverlay
for _,child in ipairs(row:GetDescendants())do if child.Name=="LarpbloxOwnAvatarPreview" and child.Parent then viewportOverlay=child end end
assert(viewportOverlay and viewportOverlay.ClassName=="ViewportFrame" and captures==4,"switching back restores the viewport renderer")
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

UDim=UDimOld
