local function node(class,name)
    local x={ClassName=class,Name=name,children={},destroyed=false}
    setmetatable(x,{__index=function(t,k)if k=="Parent"then return rawget(t,"_parent")end end,__newindex=function(t,k,v)if k=="Parent"then local old=rawget(t,"_parent");if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i)break end end end;rawset(t,"_parent",v);if v then v.children[#v.children+1]=t end else rawset(t,k,v)end end})
    function x:IsA(k)return k==self.ClassName end;function x:GetChildren()return self.children end;function x:GetDescendants()local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end;function x:FindFirstChildOfClass(k)for _,c in ipairs(self.children)do if c:IsA(k)then return c end end end;function x:Destroy()self.destroyed=true;self.Parent=nil end;function x:Clone()local n=node(self.ClassName,self.Name);for k,v in pairs(self)do if k~="children"and k~="_parent"then n[k]=v end end;return n end;return x
end
local function signal()local s={};function s:Connect(f)self.f=f;return{Disconnect=function()self.f=nil end}end;function s:Fire(...)if self.f then self.f(...)end end;return s end
local function character()local c=node("Model","Character");local h=node("Humanoid","Humanoid");h.Health=100;h.Parent=c;return c end
local c=character();local shirt1=node("Shirt","Original Shirt");shirt1.ShirtTemplate="shirt-one";shirt1.Parent=c;local shirt2=node("Shirt","Second Shirt");shirt2.ShirtTemplate="shirt-two";shirt2.Parent=c;local pants=node("Pants","Original Pants");pants.PantsTemplate="pants-one";pants.Parent=c;local hat=node("Accessory","Hat");hat.Parent=c
local gui=node("PlayerGui","PlayerGui");function gui:SetAttribute(k,v)self[k]=v end;function gui:GetAttribute(k)return self[k]end
local player={Character=c,CharacterAdded=signal(),PlayerGui=gui};function player:FindFirstChildOfClass(k)if k=="PlayerGui"then return gui end end;function player:HasAppearanceLoaded()return true end
local saved=nil;local http={};function http:JSONEncode(v)saved=v;return v end;function http:JSONDecode(v)return type(v)=="table" and v or nil end
local assets={shirt=node("Shirt","Loaded Shirt"),pants=node("Pants","Loaded Pants")};assets.shirt.ShirtTemplate="shirt-new";assets.pants.PantsTemplate="pants-new";local mode="normal"
game={GetService=function(_,n)return n=="HttpService" and http end,GetObjects=function(_,id)if mode=="respawn"then local fresh=character();player.Character=fresh;player.CharacterAdded:Fire(fresh)end;if mode=="wrong"then return{node("Accessory","Layered Item")}end;if id:match("456")then return{assets.pants:Clone()}end;return{assets.shirt:Clone()}end};Instance={new=function(k)return node(k,k)end};task={queue={},spawn=function(f)table.insert(task.queue,f)end,wait=function()end}
local create=dofile("clothes.lua");local api=create(player)
for _,invalid in ipairs({"hello123","https://evil.example/catalog/123/Shirt","https://www.roblox.com/bundles/123/Shirt"}) do
    assert(not pcall(api.equipShirt,invalid),"invalid catalog input rejected")
end
assert(api.equipShirt("https://www.roblox.com/catalog/123/Classic_Shirt?x=1"):match("Equipped"),"catalog URL loads");assert(#c:GetChildren()==4 and c:FindFirstChildOfClass("Accessory")==hat,"shirt replacement keeps hats");api.equipShirt(123);assert(#c:GetChildren()==4,"re-equip does not duplicate");assert(api.equipPants("rbxassetid://456"):match("Equipped"),"pants loads")
api.restoreShirt();assert(shirt1.Parent==c,"shirt1 restore");assert(shirt2.Parent==c,"shirt2 restore");assert(c:FindFirstChildOfClass("Pants") and c:FindFirstChildOfClass("Pants")~=pants,"pants preserved");api.restorePants();assert(pants.Parent==c and hat.Parent==c,"pants restore keeps hat")
mode="wrong";local before=#c:GetChildren();assert(not pcall(function()api.equipShirt(999)end) and #c:GetChildren()==before,"wrong class has no side effects");mode="normal";api.equipShirt(123);api.equipPants(456);api.destroy();assert(shirt1.Parent==c and shirt2.Parent==c and pants.Parent==c,"destroy restores appearance")
local refresh=create(player)
assert(refresh.getSettings().Shirt==123 and refresh.getSettings().Pants==456,"saved settings survive refresh")
mode="respawn";local cancelled=pcall(function()refresh.equipShirt(123)end)
assert(not cancelled,"character change cancels load")
mode="normal"
while #task.queue>0 do table.remove(task.queue,1)() end
assert(player.Character:FindFirstChildOfClass("Shirt").ShirtTemplate=="shirt-new" and player.Character:FindFirstChildOfClass("Pants").PantsTemplate=="pants-new","both saved clothes automatically replay after respawn")
refresh.destroy()
local load=game.GetObjects
game.GetObjects=function(self,id)if id:match("123")then error("Shirt unavailable")end;return load(self,id)end
local partial=create(player)
assert(not pcall(partial.reapplySaved),"failed saved shirt is reported")
assert(player.Character:FindFirstChildOfClass("Pants").PantsTemplate=="pants-new" and partial.getSettings().Shirt==123,"pants still replay and failed shirt stays saved for retry")
partial.destroy()
print("Clothes backend fixture and lifecycle tests passed.")

-- Appearance can report loaded before the new Humanoid is inserted.
game.GetObjects=load
local resetApi=create(player)
resetApi.equipShirt(123);resetApi.equipPants(456)
local fresh=node("Model","DelayedCharacter")
player.Character=fresh;player.CharacterAdded:Fire(fresh)
local oldWait=task.wait
local waits=0
task.wait=function()
    waits=waits+1
    if waits==1 then local h=node("Humanoid","Humanoid");h.Health=100;h.Parent=fresh end
end
while #task.queue>0 do table.remove(task.queue,1)() end
task.wait=oldWait
assert(fresh:FindFirstChildOfClass("Shirt") and fresh:FindFirstChildOfClass("Shirt").ShirtTemplate=="shirt-new", "reset waits for a live Humanoid before restoring the saved shirt")
assert(fresh:FindFirstChildOfClass("Pants") and fresh:FindFirstChildOfClass("Pants").PantsTemplate=="pants-new", "reset restores saved pants after delayed character readiness")
resetApi.destroy()
print("Delayed character readiness preserves saved clothes.")

local stopped=create(player)
local closing=character();player.Character=closing;player.CharacterAdded:Fire(closing)
task.wait=function() stopped.destroy() end
while #task.queue>0 do table.remove(task.queue,1)() end
task.wait=oldWait
assert(not closing:FindFirstChildOfClass("Shirt") and not closing:FindFirstChildOfClass("Pants"), "closing the hub cancels a pending reset restore")
local rapid=create(player)
local outdated=character();player.Character=outdated;player.CharacterAdded:Fire(outdated)
local latest
local once=false
task.wait=function()
    if not once then once=true;latest=character();player.Character=latest;player.CharacterAdded:Fire(latest) end
end
while #task.queue>0 do table.remove(task.queue,1)() end
task.wait=oldWait
assert(not outdated:FindFirstChildOfClass("Shirt") and not outdated:FindFirstChildOfClass("Pants"), "a second reset cancels restoration on the outdated character")
assert(latest:FindFirstChildOfClass("Shirt").ShirtTemplate=="shirt-new" and latest:FindFirstChildOfClass("Pants").PantsTemplate=="pants-new", "rapid resets restore clothes only to the latest character")
rapid.destroy()
print("Reset cancellation and rapid reset clothes checks passed.")
local removingCharacter=character();player.Character=removingCharacter
local removableShirt=node("Shirt","Original shirt");removableShirt.ShirtTemplate="original";removableShirt.Parent=removingCharacter
local removablePants=node("Pants","Original pants");removablePants.PantsTemplate="original";removablePants.Parent=removingCharacter
local removing=create(player);removing.removeShirt();removing.removePants()
assert(not removingCharacter:FindFirstChildOfClass("Shirt") and not removingCharacter:FindFirstChildOfClass("Pants"),"browser Remove hides both classic clothing slots")
assert(removing.getSettings().Shirt==0 and removing.getSettings().Pants==0,"explicit removal is saved independently of restore-original")
removing.destroy()
assert(removableShirt.Parent==removingCharacter and removablePants.Parent==removingCharacter,"closing restores the real original clothes")
local removedReload=create(player);removedReload.reapplySaved()
assert(not removingCharacter:FindFirstChildOfClass("Shirt") and not removingCharacter:FindFirstChildOfClass("Pants"),"removed clothing stays removed on script rerun")
removedReload.restoreShirt();removedReload.restorePants();removedReload.destroy()
print("Browser clothing removal, persistence and original restoration checks passed.")

-- Classic graphic T-shirts use ShirtGraphic.Graphic, independently of shirts/pants.
local graphicCharacter=character();player.Character=graphicCharacter
local originalGraphic=node("ShirtGraphic","Original graphic");originalGraphic.Graphic="original-graphic";originalGraphic.Parent=graphicCharacter
local previousLoader=game.GetObjects
game.GetObjects=function(self,id)if id=="rbxassetid://789" then local graphic=node("ShirtGraphic","Loaded graphic");graphic.Graphic="new-graphic";return{graphic}end;return previousLoader(self,id)end
local graphics=create(player);graphics.equipTShirt(789)
assert(graphicCharacter:FindFirstChildOfClass("ShirtGraphic").Graphic=="new-graphic","classic T-shirt graphic equips")
assert(graphics.getSettings().ShirtGraphic==789,"classic T-shirt selection is saved")
graphics.removeTShirt();assert(not graphicCharacter:FindFirstChildOfClass("ShirtGraphic"),"classic T-shirt Remove works")
graphics.destroy();assert(originalGraphic.Parent==graphicCharacter,"cleanup restores original T-shirt")
local graphicsReload=create(player);graphicsReload.reapplySaved();assert(not graphicCharacter:FindFirstChildOfClass("ShirtGraphic"),"removed T-shirt survives rerun")
graphicsReload.restoreTShirt();graphicsReload.destroy()
print("Classic graphic T-shirt equip, remove, persistence and restore passed.")
