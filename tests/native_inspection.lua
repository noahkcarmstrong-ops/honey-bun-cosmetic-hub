-- Roblox-shaped fixture for the supported local Avatar Inspect Menu bridge.
local function signal()
 local listeners={}
 return {Connect=function(_,fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;listeners[#listeners+1]={c,fn};return c end,
 Fire=function(_,...)for _,entry in ipairs(listeners)do if entry[1].Connected then entry[2](...)end end end}
end
local function node(class,name,parent)
    local x={ClassName=class,Name=name or class,Visible=true,Enabled=true,Text="",children={},destroyed=false,DescendantAdded=signal(),signals={}}
    function x:IsA(k)return k==self.ClassName or k=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="ImageButton" or self.ClassName=="ImageLabel" or self.ClassName=="ViewportFrame" or self.ClassName=="TextLabel")end
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

local old={Instance=Instance,Enum=Enum,Color3=Color3,game=game,UDim2=UDim2,Vector2=Vector2}
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
local renderStepped=signal()
local boundGuard,unbound=false,false
local run={RenderStepped=renderStepped,
 BindToRenderStep=function(_,name,priority,callback)assert(priority>=2000);boundGuard=callback end,
 UnbindFromRenderStep=function()unbound=true;boundGuard=false end}
local core=node("CoreGui","CoreGui")
-- Current Roblox mounts a Folder and places the entire panel beneath it.
local mount=child(core,"Folder","InspectAndBuy")
local inspect=child(mount,"Frame","ItemDetails")
local closeButton=child(inspect,"ImageButton","CloseButton")
local title=child(inspect,"TextLabel","Title");title.Text="Original's Avatar";title.Visible=false
local viewport=child(inspect,"ViewportFrame","AvatarViewport");viewport.ImageTransparency=0.2;viewport.AbsolutePosition={X=111,Y=222};viewport.AbsoluteSize={X=200,Y=250}
local itemContent=child(inspect,"Frame","ItemDetails");local itemLabel=child(itemContent,"TextLabel","ItemName");itemLabel.Text="Original item"
local loadingContainer=child(inspect,"Frame","ViewportContainer")
local loadingImage=child(loadingContainer,"ImageLabel","AvatarLoadingImage");loadingImage.ImageTransparency=0.3
local world=child(viewport,"WorldModel","WorldModel")
local model=child(world,"Model","Avatar")
local renderedHumanoid=child(model,"Humanoid","Humanoid")
local modelDescription
function renderedHumanoid:GetAppliedDescription()return modelDescription end
local other=child(core,"Frame","OtherInspectAndBuy");local otherTitle=child(other,"TextLabel","Title");otherTitle.Text="Other's Avatar"
local hidden=child(core,"Frame","HiddenInspectAndBuy");hidden.Visible=false;local hiddenTitle=child(hidden,"TextLabel","Title");hiddenTitle.Text="Original's Avatar"
game={GetService=function(_,name)
    if name=="RunService"then return run elseif name=="CoreGui"then return core elseif name=="GuiService"then return gui elseif name=="HttpService"then return http end
end}
local module=dofile("native_inspection.lua")
local player={Name="Original",UserId=123}
UDim2={fromScale=function(x,y)return {x,y}end,fromOffset=function(x,y)return {x,y}end,new=function(...)return {...}end}
Vector2={new=function(x,y)return {x,y}end}
local captures,shows=0,0
local failRender=false
local livePreview={version=1,records={{class="MeshPart",name="LiveLarpHat"}}}
local api=module.create(player,function()return {
 capture=function()captures=captures+1;return livePreview end,
 show=function(frame,data)
  assert(viewport.ImageTransparency==1,"the real avatar stays hidden while local rendering runs")
  assert(frame.Visible==false and data==livePreview,"only the captured live character is rendered while hidden")
  shows=shows+1;return not failRender
 end,
}end)
local function previewGui()
 for _,object in ipairs(core.children)do if object.Name=="LarpbloxOwnPreview" and not object.destroyed then return object end end
end
local function liveOverlay()
 local parent=previewGui();if not parent then return end
 for _,object in ipairs(core:GetDescendants())do if object.Name=="LarpbloxInspectPreview" and not object.destroyed then return object end end
end
local snapshot={version=1,definition={assets={{id=100,meta=nil},{id=200,meta={order=3,puffiness=0.35}}},scales={height=1.1,width=0.9,depth=1.05,head=1.2,proportion=0.4,bodyType=0.7},bodyColors={headColor="#112233",torsoColor="445566"}},items={{id=100,assetType=11,name="Larp Shirt"},{id=200,assetType=67},{id=301,assetType=8},{id=302,assetType=41},{id=303,assetType=42},{id=304,assetType=79},{id=305,assetType=12},{id=306,assetType=8}}}
title.Text="LarpAlias's Avatar"
api.update({enabled=true,name="LarpAlias"})
assert(inspect.Visible and closeButton.Visible and not title.Visible and not itemContent.Visible,"missing outfit data leaves the page open while account content stays hidden")
-- local_names can rewrite the own title before the native redirect starts.
title.Visible=true;title:GetPropertyChangedSignal("Visible"):Fire()
title.Text="LarpAlias's Avatar";title:GetPropertyChangedSignal("Text"):Fire()
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(#inspectCalls==1 and inspectCalls[1].name=="LarpAlias","local native inspection is requested with the alias")
assert(viewport.ImageTransparency==1 and loadingImage.ImageTransparency==1,"both native loading thumbnail and 3D account preview are hidden before loading")
assert(closeButton.Visible,"close control stays usable while Larp content loads")
assert(inspect.Visible==true and not title.Visible and not itemContent.Visible and title.Text=="LarpAlias's Avatar","the native shell stays visible while old avatar and item content are quarantined")
inspect.Visible=true;inspect:GetPropertyChangedSignal("Visible"):Fire()
assert(inspect.Visible==true and not title.Visible and not itemContent.Visible,"native visibility updates cannot reveal quarantined content during loading")
local d=inspectCalls[1].description
assert(not d.destroyed,"native inspector must retain the description while asynchronous avatar and item loading use it")
assert(d.Head==304 and d.Pants==305 and #d.accessories==5,"head, pants and every equipped accessory reach the native description")
local nativeIds={};for _,item in ipairs(d.accessories)do nativeIds[item.AssetId]=true end
assert(nativeIds[200] and nativeIds[301] and nativeIds[302] and nativeIds[303] and nativeIds[306],"the full Larp accessory set survives native conversion")
assert(d.Shirt==100 and d.accessories[1].AssetId==200 and d.accessories[1].IsLayered and d.accessories[1].Order==3 and d.accessories[1].Puffiness==0.35,"clothing and layered accessory metadata are preserved")
assert(d.HeightScale==1.1 and d.WidthScale==0.9 and d.DepthScale==1.05 and d.HeadScale==1.2 and d.ProportionScale==0.4 and d.BodyTypeScale==0.7,"body scales are preserved")
assert(d.HeadColor.R==17/255 and d.HeadColor.G==34/255 and d.HeadColor.B==51/255,"body colors are converted")
title.Text="LarpAlias's Avatar";itemLabel.Text="Larp Shirt";api.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(#inspectCalls==1,"adopting the redirected title does not reopen in a loop")
assert(inspect.Visible==true,"the panel reveals only after its Larp title and local preview are ready")
assert(title.Visible and itemContent.Visible,"the redirected title and refreshed item content appear only after adoption")
inspect.Visible=false
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
inspect.Visible=true
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(#inspectCalls==1,"temporary hiding during native remount must not restart inspection")
-- React can replace the heading instance without changing the inspected player.
local oldTitle=title;oldTitle.Parent=nil;oldTitle.Visible=false
for i,v in ipairs(inspect.children)do if v==oldTitle then table.remove(inspect.children,i);break end end
title=child(inspect,"TextLabel","HeaderText");title.Text="LarpAlias's Avatar";core.DescendantAdded:Fire(title)
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(liveOverlay() and liveOverlay().Visible and previewGui().Enabled,"a remounted alias heading must keep the own avatar rendering")

assert(liveOverlay().Parent==viewport and liveOverlay().Position[1]==0 and liveOverlay().Position[2]==0 and liveOverlay().Size[1]==1 and liveOverlay().Size[2]==1,"live preview lives inside the native viewport and follows its layout")
itemLabel.Text="Original item";boundGuard()
assert(not itemContent.Visible,"a stale original item cannot be revealed by the new Larp title")
itemLabel.Text="Larp Shirt";boundGuard()
assert(itemContent.Visible,"matching Larp items reveal after their content arrives")
local assetThumb=child(itemContent,"ImageLabel","Thumbnail");assetThumb.Image="rbxthumb://type=Asset&id=100&w=150&h=150"
itemLabel.Text="Catalog name differs from local accessory name";boundGuard()
assert(itemContent.Visible,"owned asset IDs reveal cards even when their catalog names differ")
assetThumb.Image="rbxthumb://type=Asset&id=999&w=150&h=150";boundGuard()
assert(not itemContent.Visible,"a different account item ID stays hidden")
assetThumb.Image="";itemLabel.Text="Larp Shirt";boundGuard()

-- Reopening an already-mounted native inspector must mask its viewport in the
-- Visible signal itself, before the render-step guard gets a chance to run.
inspect.Visible=false;inspect:GetPropertyChangedSignal("Visible"):Fire()
viewport.ImageTransparency=0;inspect.Visible=true;inspect:GetPropertyChangedSignal("Visible"):Fire()
assert(viewport.ImageTransparency==1,"opening an existing inspector masks the native avatar synchronously")
-- Native normalized descriptions must not keep the live Larp preview blank.
assert(liveOverlay() and liveOverlay().Visible and captures==1 and shows==1,"live local avatar renders even if the native applied model differs")
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(viewport.ImageTransparency==1 and liveOverlay().Visible and shows==1,"the live preview is cached and the account model remains hidden")
api.update({enabled=true,name="LarpAlias",snapshot=snapshot,image="rbxassetid://custom-avatar"})
assert(liveOverlay().ClassName=="ImageLabel" and liveOverlay().Image=="rbxassetid://custom-avatar" and liveOverlay().Visible,"custom inspection images replace the viewport overlay")
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(liveOverlay().ClassName=="ViewportFrame" and liveOverlay().Visible and shows==2,"inspection switches back to the viewport renderer")
viewport.ImageTransparency=0;viewport:GetPropertyChangedSignal("ImageTransparency"):Fire()
assert(viewport.ImageTransparency==1,"native opacity updates cannot reveal the account model")
local late=child(inspect,"ViewportFrame","LateViewport");late.ImageTransparency=0
core.DescendantAdded:Fire(late)
assert(late.ImageTransparency==1,"new native previews are hidden immediately without waiting for relay polling")
title.Text="OtherPerson's Avatar";title:GetPropertyChangedSignal("Text"):Fire()
assert(viewport.ImageTransparency==0.2 and late.ImageTransparency==0,"a reused inspector restores visibility for another player")
title.Text="LarpAlias's Avatar";title:GetPropertyChangedSignal("Text"):Fire()
local changed={version=2,definition=snapshot.definition,items={{id=100,assetType=11,name="Larp Shirt"},{id=201,assetType=67}}};api.update({enabled=true,name="LarpAlias",snapshot=changed});assert(#inspectCalls==2,"an outfit change requests a fresh native inspection")
assert(viewport.ImageTransparency==1 and (not liveOverlay() or not previewGui().Enabled),"an outfit change blanks the previous preview while loading")
failRender=true
api.update({enabled=true,name="LarpAlias",snapshot=changed})
assert(inspect.Visible,"a failed avatar render must not hide the page")
assert(viewport.ImageTransparency==1 and not previewGui().Enabled,"failed local renders stay blank without revealing the account avatar")
failRender=false
api.update({enabled=true,name="LarpAlias",snapshot=changed})
assert(liveOverlay().Visible and previewGui().Enabled,"a successful retry reveals the live Larp avatar")
viewport.ClassName="Frame";late.ClassName="Frame"
api.update({enabled=true,name="LarpAlias",snapshot=changed})
assert(previewGui().Enabled and liveOverlay().Visible,"inspection without a native ViewportFrame still shows the actual Larp avatar")
-- Late native viewport/model insertion with no DescendantAdded callback is
-- still masked before it can reach a frame, without hiding our ready preview.
viewport.ClassName="ViewportFrame";viewport.ImageTransparency=0
boundGuard()
assert(viewport.ImageTransparency==1 and previewGui().Enabled,"last-priority guard blocks the native model flash without blanking the ready Larp preview")
inspect.Visible=false;boundGuard()
assert(not previewGui().Enabled,"closing the native menu hides the added preview before the next frame")
inspect.Visible=true;api.update({enabled=true,name="LarpAlias",snapshot=changed})
assert(d.destroyed and not inspectCalls[2].description.destroyed,"new inspection releases the old source and keeps the replacement alive")
assert(otherTitle.Text=="Other's Avatar" and hiddenTitle.Text=="Original's Avatar","other and hidden inspect screens are untouched")
api.update({enabled=false,name="LarpAlias"});assert(#restoreCalls==1 and restoreCalls[1]==123,"turning Larp mode off restores the platform avatar even while the redirected alias title is visible")
assert(viewport.ImageTransparency==0.2 and late.ImageTransparency==0 and itemContent.Visible,"mode off restores original native visibility")
assert(inspectCalls[2].description.destroyed,"mode off releases the retained source")
api.update({enabled=true,name="LarpAlias",snapshot=changed})
-- Native avatar content may be inserted before its identifying title exists.
local unknownMount=child(core,"Folder","InspectAndBuyNew")
local unknownPanel=child(unknownMount,"Frame","Container")
core.DescendantAdded:Fire(unknownPanel)
assert(unknownPanel.Visible==true,"a new inspection panel keeps its shell visible while loading")
local unknownAvatar=child(unknownPanel,"ViewportFrame","Avatar")
core.DescendantAdded:Fire(unknownAvatar)
assert(unknownPanel.Visible==true and not unknownAvatar.Visible,"avatar-first loading keeps the shell visible while native content stays blank")
local legacyPanel=child(core,"ImageButton","InspectAndBuy")
core.DescendantAdded:Fire(legacyPanel)
assert(legacyPanel.Visible==true,"legacy root controls remain available before children arrive")
api.destroy();assert(unbound,"closing the hub removes the last-priority render guard")
local blockedGui={InspectPlayerFromHumanoidDescription=function()error("blocked")end,InspectPlayerFromUserId=function()end}
game.GetService=function(_,name)if name=="CoreGui"then return core elseif name=="GuiService"then return blockedGui elseif name=="HttpService"then return http end end
local blocked=module.create(player);title.Text="Original's Avatar";blocked.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(blocked.report():find("blocked",1,true),"blocked native API access is reported")
blocked.destroy()
Instance,Enum,Color3,game,UDim2,Vector2=old.Instance,old.Enum,old.Color3,old.game,old.UDim2,old.Vector2
print("Native inspection description, redirect adoption, lifecycle and blocked API checks passed.")
