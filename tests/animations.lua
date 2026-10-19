local all,methods={},{}
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)t.props[k]=v end}
Instance={new=function(class)
    local o=setmetatable({props={ClassName=class,Name=class}},meta);all[#all+1]=o;return o
end}
function methods:IsA(class)return self.ClassName==class end
function methods:GetChildren()local result={};for _,o in ipairs(all)do if o.Parent==self then result[#result+1]=o end end;return result end
function methods:GetDescendants()local result={};for _,o in ipairs(self:GetChildren())do result[#result+1]=o;for _,d in ipairs(o:GetDescendants())do result[#result+1]=d end end;return result end
function methods:FindFirstChild(name)for _,o in ipairs(self:GetChildren())do if o.Name==name then return o end end end
function methods:FindFirstChildOfClass(class)for _,o in ipairs(self:GetChildren())do if o.ClassName==class then return o end end end
function methods:Destroy()for _,o in ipairs(self:GetChildren())do o:Destroy()end;self.Parent=nil;self.destroyed=true end
local function new(class,name,parent)local o=Instance.new(class);o.Name=name;o.Parent=parent;return o end
local attrs={}
local gui={GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end}
Enum={HumanoidRigType={R15='R15'},AnimationPriority={Core='Core',Idle='Idle',Movement='Movement',Action='Action'}}
local jobs={};task={spawn=function(fn)jobs[#jobs+1]=fn end,wait=function()end}
local function flush()local pending=jobs;jobs={};for _,fn in ipairs(pending)do fn()end end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={fn=fn,Connected=true};function c:Disconnect()self.Connected=false end;s.listeners[#s.listeners+1]=c;return c end
    function s:Fire(...)for _,c in ipairs(s.listeners)do if c.Connected then c.fn(...)end end end
    return s
end
local function character()
    local c=new('Model','Character')
    local h=new('Humanoid','Humanoid',c);h.Health=100;h.RigType='R15'
    local animate=new('LocalScript','Animate',c);animate.Disabled=false
    for _,state in ipairs({'idle','walk','run','jump','fall','climb','swim','swimidle'})do
        local folder=new('StringValue',state,animate)
        local a=new('Animation','Original',folder);a.AnimationId='original-'..state
    end
    local animator=new('Animator','Animator',h)
    local movement={Priority='Core',Stop=function(self)self.stopped=true end}
    local action={Priority='Action',Stop=function(self)self.stopped=true end}
    animator.GetPlayingAnimationTracks=function()return{movement,action}end
    return c,animate,h,movement,action
end
local bundle={bundleType='AvatarAnimations',name='Fixture Movement',items={}}
local names={[48]='climb',[50]='fall',[51]='idle',[52]='jump',[53]='run',[54]='swim',[55]='walk'}
for id in pairs(names)do bundle.items[#bundle.items+1]={type='Asset',assetType=id,id=id}end
local failBundle,failAsset=false,false
local roots={}
local http={JSONDecode=function()return failBundle and {bundleType='BodyParts',items={}} or bundle end}
game={GetService=function(_,name)assert(name=='HttpService');return http end,HttpGet=function(_,url)assert(url:find('/bundles/',1,true));return'fixture'end}
function game:GetObjects(url)
    if failAsset then error('Unavailable')end
    local id=tonumber(url:match('(%d+)$'));local state=assert(names[id])
    local root=new('Folder','R15Anim');roots[#roots+1]=root
    local function group(s,count)
        local folder=new('StringValue',s,root)
        for i=1,count do
            local a=new('Animation',s..i,folder);a.AnimationId='rbxassetid://'..id..i
            local weight=new('NumberValue','Weight',a);weight.Value=i*3
        end
    end
    group(state,state=='idle' and 2 or 1)
    if state=='swim' then group('swimidle',1)end
    return{root}
end
local c,animate,h,movement,action=character()
local player={Character=c,CharacterAdded=signal(),FindFirstChildOfClass=function()return gui end,HasAppearanceLoaded=function()return true end}
local make=dofile('animations.lua');local api=make(player)
api.equipBundle('https://www.roblox.com/bundles/82/Robot')
assert(animate:FindFirstChild('walk'):GetChildren()[1].AnimationId=='rbxassetid://551','Walk resolves wrapper content rather than catalog ID')
assert(#animate:FindFirstChild('idle'):GetChildren()==2,'Both idle variants preserved')
assert(animate:FindFirstChild('idle'):GetChildren()[2]:FindFirstChild('Weight').Value==6,'Idle weighting preserved')
assert(animate:FindFirstChild('swimidle'):GetChildren()[1].AnimationId=='rbxassetid://541','Swim idle state equipped')
assert(movement.stopped and not action.stopped and not animate.Disabled,'Restarts locomotion while preserving action tracks')
assert(attrs.HoneyBunCosmeticAnimationBundle==82,'Equipped bundle saved')
for _,root in ipairs(roots)do assert(root.destroyed,'Loaded wrappers disposed')end
failBundle=true;assert(not pcall(api.equipBundle,'999'),'Body bundle rejected');failBundle=false
failAsset=true;assert(not pcall(api.equipBundle,'998'),'Unloadable package rejected');failAsset=false
assert(attrs.HoneyBunCosmeticAnimationBundle==82 and animate:FindFirstChild('walk'):GetChildren()[1].AnimationId=='rbxassetid://551','Failed equip keeps current package')
for _,invalid in ipairs({'https://evil.example/bundles/82','https://www.roblox.com/catalog/82/Animation','bad',0,-1})do assert(not pcall(api.equipBundle,invalid),'Invalid bundle input rejected')end
local c2,a2=character();player.Character=c2;player.CharacterAdded:Fire(c2);flush()
assert(a2:FindFirstChild('run'):GetChildren()[1].AnimationId=='rbxassetid://531','Bundle reapplies after reset')
api.destroy();assert(a2:FindFirstChild('run'):GetChildren()[1].AnimationId=='original-run','Refresh restores original controls before reload')
local refreshed=make(player);refreshed.reapplySaved()
assert(a2:FindFirstChild('walk'):GetChildren()[1].AnimationId=='rbxassetid://551','Refresh restores saved bundle')
refreshed.restore();assert(a2:FindFirstChild('walk'):GetChildren()[1].AnimationId=='original-walk' and attrs.HoneyBunCosmeticAnimationBundle==nil,'Restore original animations clears selection')
refreshed.destroy()
print('Movement bundle wrappers, idle variants, locomotion, persistence, reset, restore and failed-equip checks passed.')
