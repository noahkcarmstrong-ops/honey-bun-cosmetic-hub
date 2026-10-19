-- Backend fixture: strict Roblox-like instances, parenting, CFrames, and APIs.
local function cf(x,y,z)
    local c={x=x or 0,y=y or 0,z=z or 0}
    function c:Inverse() return cf(-self.x,-self.y,-self.z) end
    return setmetatable(c,{__mul=function(a,b)return cf(a.x+b.x,a.y+b.y,a.z+b.z)end})
end
local function node(class,name)
    local x={ClassName=class,Name=name,children={},destroyed=false}
    local mt={__index=function(t,k)if k=="Parent" then return rawget(t,"_parent") end end,__newindex=function(t,k,v)
        if k=="Parent" then
            local old=rawget(t,"_parent"); if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i)break end end end
            rawset(t,"_parent",v); if v then v.children[#v.children+1]=t end
        else rawset(t,k,v) end
    end}; setmetatable(x,mt)
    function x:IsA(k)return k==self.ClassName or k=="BasePart" and(self.ClassName=="Part"or self.ClassName=="MeshPart") or k=="LuaSourceContainer" and(self.ClassName=="Script"or self.ClassName=="LocalScript"or self.ClassName=="ModuleScript") or k=="JointInstance" and self.ClassName=="Weld"end
    function x:GetChildren()return self.children end
    function x:GetDescendants()local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end
    function x:FindFirstChild(n,r)for _,c in ipairs(self.children)do if c.Name==n then return c end;if r then local q=c:FindFirstChild(n,true);if q then return q end end end end
    function x:FindFirstChildOfClass(k)for _,c in ipairs(self.children)do if c:IsA(k)then return c end end end
    function x:FindFirstChildWhichIsA(k,r)for _,c in ipairs(r and self:GetDescendants()or self.children)do if c:IsA(k)then return c end end end
 function x:Destroy()self.destroyed=true;self.Parent=nil;for i=#self.children,1,-1 do self.children[i]:Destroy()end end
    function x:Clone()local n=node(self.ClassName,self.Name);for k,v in pairs(self)do if k~="children"and k~="Parent"and k~="_parent"and type(v)~="function"then n[k]=v end end;for _,c in ipairs(self.children)do c:Clone().Parent=n end;return n end
    return x
end
local function signal()local s={};function s:Connect(f)self.f=f;return{Disconnect=function()self.f=nil end}end;function s:Fire(...)if self.f then self.f(...)end end;return s end
local function hum()local h=node("Humanoid","Humanoid");h.Health=100;h.RigType="R15";h.replaced={};function h:AddAccessory(a)a.Parent=self.Parent end;function h:ReplaceBodyPartR15(n,p)if self.failName==n then return false end;local old=self.Parent:FindFirstChild(n);if old then old:Destroy()end;self.replaced[n]=p;p.Parent=self.Parent;return true end;return h end
Enum={HumanoidRigType={R6="R6",R15="R15"},BodyPartR15={}}
CFrame={new=function(x,y,z)return cf(x,y,z)end}
for _,n in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do Enum.BodyPartR15[n]=n end
Instance={new=function(c)return node(c,c)end}
local body=node("Model","Character");hum().Parent=body;local root=node("Part","HumanoidRootPart");root.CFrame=cf();root.Parent=body
for _,n in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do local p=node("Part",n);p.Color={r=1,g=1,b=1};p.CFrame=cf();p.Parent=body end
local bc=node("BodyColors","Body Colors");bc.HeadColor3={r=1,g=1,b=1};bc.TorsoColor3={r=1,g=1,b=1};bc.LeftArmColor3={r=1,g=1,b=1};bc.RightArmColor3={r=1,g=1,b=1};bc.LeftLegColor3={r=1,g=1,b=1};bc.RightLegColor3={r=1,g=1,b=1};bc.Parent=body
local head=body:FindFirstChild("Head");local ha=node("Attachment","HatAttachment");ha.CFrame=cf();ha.Parent=head
local player={Character=body,CharacterAdded=signal()};local accessory=node("Accessory","Blue Hat");local handle=node("Part","Handle");handle.CFrame=cf();handle.AttachmentPoint=cf();handle.Parent=accessory;local at=node("Attachment","HatAttachment");at.CFrame=cf();at.Parent=handle;local injected=node("Script","Injected");injected.Parent=accessory
local template=node("Model","Template");for _,n in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do local p=node("MeshPart",n);p.CFrame=cf();p.Parent=template end
local players={template=template};function players:GetHumanoidDescriptionFromOutfitIdAsync(id)local d=node("HumanoidDescription","Description");d.id=id;d.Head=901;d.Torso=902;d.LeftArm=903;d.RightArm=904;d.LeftLeg=905;d.RightLeg=906;return d end;function players:CreateHumanoidModelFromDescriptionAsync(description)self.lastDescription=description;self.generated=true;if self.onGenerate then self.onGenerate()end;return self.template:Clone() end
local savedSettings=nil;local http={bundleType="BodyParts"};function http:GetAsync()return'{"items":[{"type":"UserOutfit","id":131929576}]}'end;function http:JSONDecode(value)if value=="settings-token"then return savedSettings end;return{bundleType=self.bundleType,items={{type="UserOutfit",id=131929576}}}end;function http:JSONEncode(value)savedSettings=value;return"settings-token"end
local gui=node("PlayerGui","PlayerGui");function gui:SetAttribute(k,v)self[k]=v end;function gui:GetAttribute(k)return self[k]end
player.PlayerGui=gui;function player:FindFirstChild(n)return self[n]end;function player:FindFirstChildOfClass(n)if n=="PlayerGui"then return self.PlayerGui end end;function player:WaitForChild(n)return self[n]end;function player:HasAppearanceLoaded()return true end
Color3={fromRGB=function(r,g,b)return{R=r/255,G=g/255,B=b/255,r=r/255,g=g/255,b=b/255}end,new=function(r,g,b)return{R=r,G=g,B=b,r=r,g=g,b=b}end};task={queue={},wait=function()end,spawn=function(f)table.insert(task.queue,f)end}
local mode="normal";local function freshAccessory()local a=node("Accessory","Blue Hat");a.AttachmentPoint=cf();local h=node("Part","Handle");h.CFrame=cf();h.AttachmentPoint=cf();h.Parent=a;return a end
local marketplace={assetType=28};function marketplace:GetProductInfoAsync()return{AssetTypeId=self.assetType}end
game={GetService=function(_,n)return({Players=players,HttpService=http,MarketplaceService=marketplace})[n]end,GetObjects=function(_,id)assert(id=="rbxassetid://123");if mode=="respawn"then local fresh=node("Model","Fresh");player.Character=fresh;player.CharacterAdded:Fire(fresh)end;if mode=="blocked"then return{node("Part","NotWearable")}end;if accessory.destroyed then return{freshAccessory()}end;return{accessory}end,HttpGet=function()return http:GetAsync()end}
Enum.InfoType={Asset="Asset"}
local create=dofile("avatar.lua");assert(type(create)=="function","module returns create(player)");local api=create(player)
assert(api.equipAccessory(123):match("Equipped"));local candidate=body:FindFirstChild("Blue Hat");assert(injected.destroyed and candidate,"sanitizing removes inserted script and parents cloned accessory");assert(#api.listAccessories()==1)
api.setSkin(Color3.new(.5,.4,.3),"All");assert(head.Color.r==.5 and body:FindFirstChild("LeftUpperArm").Color.r==.5 and bc.HeadColor3.r==.5,"R15 grouped skin applies");api.restore();assert(head.Color.r==1 and bc.HeadColor3.r==1,"restore returns original colors")
assert(api.applyBody("https://www.roblox.com/bundles/555"):match("applied"));assert(players.generated and body:FindFirstChildOfClass("Humanoid").replaced.Head,"bundle outfit generates template and replaces body parts")
mode="respawn";local stale=create(player);local ok=pcall(function()stale.equipAccessory(123)end);assert(not ok,"respawn cancels stale asset operation");stale.destroy();player.Character=body;player.CharacterAdded:Fire(body)

-- Blocked body replacement rolls back every changed limb and preserves the root.
mode="normal"; local rootBefore=root; local r15=create(player); local h=body:FindFirstChildOfClass("Humanoid"); h.failName="LeftHand"; local beforeChildren=#body:GetChildren(); local rolled=pcall(function()r15.applyBody("https://www.roblox.com/bundles/555")end); assert(not rolled,"a rejected ReplaceBodyPartR15 fails"); assert(body:FindFirstChild("HumanoidRootPart")==rootBefore,"rollback preserves root identity"); assert(#body:GetChildren()<=beforeChildren+1,"rollback leaves no unowned body clones"); h.failName=nil; r15.destroy()

-- R6 Blocky is local CharacterMesh removal and restore; Girl uses generated R6 meshes.
local r6=node("Model","R6Character"); local r6h=hum(); r6h.RigType=Enum.HumanoidRigType.R6; r6h.Parent=r6; local r6root=node("Part","HumanoidRootPart");r6root.Parent=r6;local torso=node("Part","Torso");torso.Parent=r6;local originalMesh=node("CharacterMesh","BodyMesh");originalMesh.Parent=r6
local r6player={Character=r6,CharacterAdded=signal(),PlayerGui=gui};function r6player:FindFirstChildOfClass(n)if n=="PlayerGui"then return self.PlayerGui end end;local oldTemplate=players.template;local r6template=node("Model","R6Template");local girlMesh=node("CharacterMesh","GirlMesh");girlMesh.Parent=r6template;players.template=r6template;local r6api=create(r6player);players.generated=false;assert(r6api.applyBody("Blocky"):match("Blocky"));assert(originalMesh.destroyed and not players.generated and r6root.Parent==r6,"R6 Blocky removes meshes without generating or replacing model");assert(r6api.restore():match("restored") and r6:FindFirstChild("BodyMesh"),"R6 restore returns original CharacterMesh");assert(r6api.applyBody("Girl"):match("Body") and r6:FindFirstChild("GirlMesh"),"R6 Girl applies generated CharacterMesh only");r6api.destroy();players.template=oldTemplate

-- Destroying during template generation cancels the completed operation.
players.template=template; local cancel=create(player); players.onGenerate=function()cancel.destroy()end; local cancelled=pcall(function()cancel.applyBody("Robloxian 2.0")end); players.onGenerate=nil; assert(not cancelled,"destroy during generation cancels operation")

-- Failed assets have no side effects; repeated keys remain unique after removal.
local clean=create(player); local count=#body:GetChildren();mode="blocked";assert(not pcall(function()clean.equipAccessory(123)end) and #body:GetChildren()==count,"blocked asset has no side effects");mode="normal";local a=clean.equipAccessory(123);local first=clean.listAccessories()[1].key;clean.equipAccessory(123);local second=clean.listAccessories()[2].key;assert(first~=second,"repeated equips receive unique keys");clean.removeAccessory(first);assert(#clean.listAccessories()==1,"individual removal keeps other accessory");clean.destroy()
-- Original Roblox accessories can be hidden without deleting them or hub-added hats.
local originalHat=freshAccessory();originalHat.Name="Original Roblox Hat";originalHat.Parent=body
local wardrobe=create(player);wardrobe.equipAccessory(123)
local addedHat=wardrobe.listAccessories()[1]
wardrobe.removeCurrentAccessories()
assert(originalHat.Parent==nil and not originalHat.destroyed,"original accessory is detached, not destroyed")
assert(#wardrobe.listAccessories()==1 and wardrobe.listAccessories()[1].key==addedHat.key,"hub-added accessory stays equipped")
wardrobe.removeCurrentAccessories();wardrobe.restore()
assert(originalHat.Parent==body and not originalHat.destroyed,"restore returns original hat")
assert(#wardrobe.listAccessories()==0,"restore removes hub-added hats")
wardrobe.removeCurrentAccessories();wardrobe.destroy()
assert(originalHat.Parent==body,"closing or refreshing returns original hats")

-- Saved selections survive editor recreation and a fresh character, while restore clears them.
mode="normal"; local persist=create(player); persist.equipAccessory(123); persist.setSkin(Color3.fromRGB(128,96,64),"All"); persist.applyBody("https://www.roblox.com/bundles/555")
local saved=persist.getSettings(); assert(saved and saved.accessories and #saved.accessories==1 and saved.colors and saved.colors.All and saved.hideOriginals==true,"getSettings returns normalized saved selections")
persist.destroy(); local resumed=create(player); local fresh=body:Clone(); local freshHum=fresh:FindFirstChildOfClass("Humanoid"); freshHum.Health=100; freshHum.RigType=Enum.HumanoidRigType.R15; freshHum.replaced={}; freshHum.ReplaceBodyPartR15=function(self,n,p)self.replaced[n]=p;p.Parent=self.Parent;return true end; freshHum.AddAccessory=function(self,a)a.Parent=self.Parent end; local freshHat=freshAccessory();freshHat.Name="Original Roblox Hat";freshHat.Parent=fresh; player.Character=fresh; player.CharacterAdded:Fire(fresh)
while #task.queue>0 do local work=table.remove(task.queue,1);work() end
assert(resumed.getSettings().accessories and #resumed.getSettings().accessories==1,"new editor reads prior session settings"); assert(freshHat.Parent==nil and not freshHat.destroyed,"saved hideOriginals hides fresh original accessories"); local replay=resumed.reapplySaved(); assert(type(replay)=="string" and #replay>0,"saved accessories/body/color replay on fresh character"); local count=#resumed.listAccessories(); resumed.reapplySaved(); assert(#resumed.listAccessories()==count,"manual replay does not duplicate cosmetics")
mode="blocked"; local failed=pcall(function()resumed.reapplySaved()end); assert(failed,"blocked saved asset reports without throwing"); local failedMessage=resumed.reapplySaved(); assert(failedMessage:match("some could not load") and #resumed.getSettings().accessories==1,"failed saved accessory remains persisted")
mode="normal"; resumed.restore(); local cleared=resumed.getSettings(); assert((not cleared.accessories or #cleared.accessories==0) and freshHat.Parent==fresh,"restore clears saved selections and restores original hat"); resumed.destroy()

-- Skin-only restore keeps added hats, body changes, and hidden originals while clearing saved colors.
player.Character=body
local originalSkin=Color3.new(.8,.7,.6)
player.Character:FindFirstChild("Head").Color=originalSkin
local skinOnly=create(player); local hiddenHat=freshAccessory();hiddenHat.Name="Hidden Original Hat";hiddenHat.Parent=player.Character
skinOnly.equipAccessory(123); skinOnly.equipAccessory(123); skinOnly.removeCurrentAccessories(); skinOnly.applyBody("https://www.roblox.com/bundles/555"); skinOnly.setSkin(Color3.new(.2,.3,.4),"All")
local beforeSkinOnly=skinOnly.getSettings(); assert(beforeSkinOnly.hideOriginals and beforeSkinOnly.body and #skinOnly.listAccessories()==2,"skin-only setup keeps multiple cosmetics")
local changedBodyHead=player.Character:FindFirstChild("Head")
skinOnly.restoreSkin(); local afterSkinOnly=skinOnly.getSettings()
assert(#skinOnly.listAccessories()==2 and hiddenHat.Parent==nil and not hiddenHat.destroyed,"skin-only restore preserves added hats and hidden originals")
assert(afterSkinOnly.hideOriginals and afterSkinOnly.body and next(afterSkinOnly.colors)==nil,"skin-only restore clears saved colors only")
assert(player.Character:FindFirstChild("Head")==changedBodyHead and changedBodyHead.Color==originalSkin,"skin-only restore returns actual original color without replacing body")
skinOnly.destroy()

-- Mixed R15 regions replace only selected segments and restore keeps hats and colors.
player.Character=body; local mixed=create(player); local mixedRoot=body:FindFirstChild("HumanoidRootPart"); local mixedHead=body:FindFirstChild("Head"); mixedHead.Color=Color3.new(.7,.6,.5)
local mixedHat=freshAccessory();mixedHat.Name="Mixed Hat";mixedHat.Parent=body
body:FindFirstChild("LeftUpperArm").MeshId="original-arm"
template:FindFirstChild("LeftUpperArm").MeshId="custom-arm"
assert(mixed.applyBodyPart("LeftArm","https://www.roblox.com/bundles/555"):match("LeftArm")); marketplace.assetType=31
assert(body:FindFirstChild("LeftUpperArm").MeshId=="custom-arm","selected arm geometry actually changes")
assert(mixed.applyBodyPart("RightLeg",456):match("RightLeg")); local mixedSettings=mixed.getSettings()
assert(mixedSettings.bodyParts.LeftArm and mixedSettings.bodyParts.RightLeg,"mixed body selections are saved")
assert(body:FindFirstChild("HumanoidRootPart")==mixedRoot and body:FindFirstChild("Head")==mixedHead,"mixed replacement preserves unrelated parts")
marketplace.assetType=27; assert(not pcall(function()mixed.applyBodyPart("Head",456)end),"wrong catalog category is rejected")
assert(mixed.restoreBody():match("restored") and mixedHat.Parent==body and mixedHead.Color.r==.7,"restoreBody keeps hats and colors")
assert(body:FindFirstChild("LeftUpperArm").MeshId=="original-arm","body-only restore restores geometry after only region changes")
assert(next(mixed.getSettings().bodyParts)==nil and not mixed.getSettings().body,"restoreBody clears body selections")
marketplace.assetType=79
mixed.applyBodyPart("Head","https://www.roblox.com/catalog/789/Dynamic-Head")
assert(players.lastDescription.Head==789,"dynamic head catalog ID is passed to body generation")
mixed.applyBodyPart("Head","https://www.roblox.com/bundles/555/Head")
assert(players.lastDescription.Head==901,"head bundle uses outfit head asset")
http.bundleType="AvatarAnimations"
assert(not pcall(mixed.applyBodyPart,"Head","https://www.roblox.com/bundles/82/Robot"),"animation bundles cannot replace body parts")
http.bundleType="BodyParts"
local partialHead=body:FindFirstChild("Head")
mixed.reapplySaved()
assert(mixed.getSettings().bodyParts.Head and body:FindFirstChild("Head")~=partialHead,"custom heads survive saved replay")
mixed.applyBody("Girl")
assert(next(mixed.getSettings().bodyParts)==nil,"new full body package clears mixed overrides")
mixed.destroy()
print("Avatar backend fixture and lifecycle tests passed.")
