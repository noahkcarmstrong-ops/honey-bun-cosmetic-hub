-- Backend fixture: strict Roblox-like instances, parenting, CFrames, and APIs.
local function cf(x,y,z)
    local c={x=x or 0,y=y or 0,z=z or 0}
    function c:Inverse() return cf(-self.x,-self.y,-self.z) end
    return setmetatable(c,{__mul=function(a,b)return cf(a.x+b.x,a.y+b.y,a.z+b.z)end})
end
local function node(class,name)
    local x={ClassName=class,Name=name,children={},destroyed=false}
    local mt={__newindex=function(t,k,v)
        if k=="Parent" then
            local old=rawget(t,"Parent"); if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i)break end end end
            rawset(t,k,v); if v then v.children[#v.children+1]=t end
        else rawset(t,k,v) end
    end}; setmetatable(x,mt)
    function x:IsA(k)return k==self.ClassName or k=="BasePart" and(self.ClassName=="Part"or self.ClassName=="MeshPart") or k=="LuaSourceContainer" and(self.ClassName=="Script"or self.ClassName=="LocalScript"or self.ClassName=="ModuleScript") or k=="JointInstance" and self.ClassName=="Weld"end
    function x:GetChildren()return self.children end
    function x:GetDescendants()local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end
    function x:FindFirstChild(n,r)for _,c in ipairs(self.children)do if c.Name==n then return c end;if r then local q=c:FindFirstChild(n,true);if q then return q end end end end
    function x:FindFirstChildOfClass(k)for _,c in ipairs(self.children)do if c:IsA(k)then return c end end end
    function x:FindFirstChildWhichIsA(k,r)for _,c in ipairs(r and self:GetDescendants()or self.children)do if c:IsA(k)then return c end end end
 function x:Destroy()self.destroyed=true;local p=self.Parent;if p then for i=#p.children,1,-1 do if p.children[i]==self then table.remove(p.children,i)end end end;self.Parent=nil;for i=#self.children,1,-1 do self.children[i]:Destroy()end end
    function x:Clone()local n=node(self.ClassName,self.Name);for k,v in pairs(self)do if k~="children"and k~="Parent"and type(v)~="function"then n[k]=v end end;for _,c in ipairs(self.children)do c:Clone().Parent=n end;return n end
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
local players={template=template};function players:GetHumanoidDescriptionFromOutfitIdAsync(id)local d=node("HumanoidDescription","Description");d.id=id;return d end;function players:CreateHumanoidModelFromDescriptionAsync()self.generated=true;if self.onGenerate then self.onGenerate()end;return self.template:Clone() end
local http={};function http:GetAsync()return'{"items":[{"type":"UserOutfit","id":131929576}]}'end;function http:JSONDecode()return{items={{type="UserOutfit",id=131929576}}}end
local mode="normal";local function freshAccessory()local a=node("Accessory","Blue Hat");a.AttachmentPoint=cf();local h=node("Part","Handle");h.CFrame=cf();h.AttachmentPoint=cf();h.Parent=a;return a end
game={GetService=function(_,n)return({Players=players,HttpService=http})[n]end,GetObjects=function(_,id)assert(id=="rbxassetid://123");if mode=="respawn"then local fresh=node("Model","Fresh");player.Character=fresh;player.CharacterAdded:Fire(fresh)end;if mode=="blocked"then return{node("Part","NotWearable")}end;if accessory.destroyed then return{freshAccessory()}end;return{accessory}end,HttpGet=function()return http:GetAsync()end}
local create=dofile("avatar.lua");assert(type(create)=="function","module returns create(player)");local api=create(player)
assert(api.equipAccessory(123):match("Equipped"));local candidate=body:FindFirstChild("Blue Hat");assert(injected.destroyed and candidate,"sanitizing removes inserted script and parents cloned accessory");assert(#api.listAccessories()==1)
api.setSkin({r=.5,g=.4,b=.3},"All");assert(head.Color.r==.5 and body:FindFirstChild("LeftUpperArm").Color.r==.5 and bc.HeadColor3.r==.5,"R15 grouped skin applies");api.restore();assert(head.Color.r==1 and bc.HeadColor3.r==1,"restore returns original colors")
assert(api.applyBody("https://www.roblox.com/bundles/555"):match("applied"));assert(players.generated and body:FindFirstChildOfClass("Humanoid").replaced.Head,"bundle outfit generates template and replaces body parts")
mode="respawn";local stale=create(player);local ok=pcall(function()stale.equipAccessory(123)end);assert(not ok,"respawn cancels stale asset operation");stale.destroy();player.Character=body;player.CharacterAdded:Fire(body)

-- Blocked body replacement rolls back every changed limb and preserves the root.
mode="normal"; local rootBefore=root; local r15=create(player); local h=body:FindFirstChildOfClass("Humanoid"); h.failName="LeftHand"; local beforeChildren=#body:GetChildren(); local rolled=pcall(function()r15.applyBody("https://www.roblox.com/bundles/555")end); assert(not rolled,"a rejected ReplaceBodyPartR15 fails"); assert(body:FindFirstChild("HumanoidRootPart")==rootBefore,"rollback preserves root identity"); assert(#body:GetChildren()<=beforeChildren+1,"rollback leaves no unowned body clones"); r15.destroy()

-- R6 Blocky is local CharacterMesh removal and restore; Girl uses generated R6 meshes.
local r6=node("Model","R6Character"); local r6h=hum(); r6h.RigType=Enum.HumanoidRigType.R6; r6h.Parent=r6; local r6root=node("Part","HumanoidRootPart");r6root.Parent=r6;local torso=node("Part","Torso");torso.Parent=r6;local originalMesh=node("CharacterMesh","BodyMesh");originalMesh.Parent=r6
local r6player={Character=r6,CharacterAdded=signal()}; local oldTemplate=players.template; local r6template=node("Model","R6Template");local girlMesh=node("CharacterMesh","GirlMesh");girlMesh.Parent=r6template;players.template=r6template;local r6api=create(r6player);players.generated=false;assert(r6api.applyBody("Blocky"):match("Blocky"));assert(originalMesh.destroyed and not players.generated and r6root.Parent==r6,"R6 Blocky removes meshes without generating or replacing model");assert(r6api.restore():match("restored") and r6:FindFirstChild("BodyMesh"),"R6 restore returns original CharacterMesh");assert(r6api.applyBody("Girl"):match("Body") and r6:FindFirstChild("GirlMesh"),"R6 Girl applies generated CharacterMesh only");r6api.destroy();players.template=oldTemplate

-- Destroying during template generation cancels the completed operation.
players.template=template; local cancel=create(player); players.onGenerate=function()cancel.destroy()end; local cancelled=pcall(function()cancel.applyBody("Robloxian 2.0")end); players.onGenerate=nil; assert(not cancelled,"destroy during generation cancels operation")

-- Failed assets have no side effects; repeated keys remain unique after removal.
local clean=create(player); local count=#body:GetChildren();mode="blocked";assert(not pcall(function()clean.equipAccessory(123)end) and #body:GetChildren()==count,"blocked asset has no side effects");mode="normal";local a=clean.equipAccessory(123);local first=clean.listAccessories()[1].key;clean.equipAccessory(123);local second=clean.listAccessories()[2].key;assert(first~=second,"repeated equips receive unique keys");clean.removeAccessory(first);assert(#clean.listAccessories()==1,"individual removal keeps other accessory");clean.destroy()
print("Avatar backend fixture and lifecycle tests passed.")
