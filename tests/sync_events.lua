local function signal()
    local listeners={}
    return {Connect=function(_,fn)
        local c={Connected=true};function c:Disconnect()self.Connected=false end
        listeners[#listeners+1]={c=c,fn=fn};return c
    end,Fire=function(_,...)for _,v in ipairs(listeners)do if v.c.Connected then v.fn(...)end end end}
end
table.clear=table.clear or function(t)for k in pairs(t)do t[k]=nil end end
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
local function instance(class)
    local signals={}
    return {IsA=function(_,name)return name==class end,GetPropertyChangedSignal=function(_,name)
        signals[name]=signals[name] or signal();return signals[name]
    end}
end
local snapshots=0
local body=instance("BodyColors")
for _,name in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do body[name.."Color3"]={R=1,G=1,B=1}end
local humanoid=instance("Humanoid");humanoid.ApplyDescriptionFinished=signal()
local description={GetAccessories=function()return {}end}
humanoid.GetAppliedDescription=function()snapshots=snapshots+1;return description end
local part=instance("BasePart")
local character={DescendantAdded=signal(),DescendantRemoving=signal()}
function character:FindFirstChildOfClass(name)return name=="Humanoid" and humanoid or name=="BodyColors" and body end
function character:GetDescendants()return {body,humanoid,part}end
function part:IsDescendantOf()return false end
local gui={AttributeChanged=signal()}
local player={UserId=7,Character=character,CharacterAdded=signal(),CharacterRemoving=signal(),FindFirstChildOfClass=function()return gui end}
local documents={};local nextDocument=0
local http={JSONEncode=function(_,value)nextDocument=nextDocument+1;local key=tostring(nextDocument);documents[key]=value;return key end,
    JSONDecode=function(_,key)return documents[key]end}
game={GetService=function(_,name)return name=="HttpService" and http or {}end}
Enum={HumanoidRigType={R6={}}}
local jobs,timers={},{}
task={spawn=function(fn)jobs[#jobs+1]=coroutine.create(fn)end,wait=function(seconds)return coroutine.yield(seconds)end,
    delay=function(_,fn)timers[#timers+1]=fn end}
local function resume(job)local ok,value=coroutine.resume(job);assert(ok,value);return value end
local function flush()local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end end
local httpRequests=0
request=function()httpRequests=httpRequests+1;return {StatusCode=200,Body=http:JSONEncode({instanceId="fixture",code=string.rep("a",32)})}end
local socket={OnMessage=signal(),OnClose=signal(),Close=function()end}
function socket:Send(data)
    if documents[data].type=="auth" then self.OnMessage:Fire(http:JSONEncode({type="ready",instanceId="fixture"}))end
end
WebSocket={connect=function()return socket end}
local avatar={getSettings=function()return {}end,listAccessories=function()return {}end}
local restoredNames=0
local names={restore=function()restoredNames=restoredNames+1 end,setEnabled=function()end,
    set=function(name)assert(name~="","empty name must not be applied")end}
local create=dofile("game_browser_sync.lua")
local sync=create(player,function()return avatar end,function()return {getSettings=function()return {}end}end,function()return true end,nil,nil,function()return names end)
resume(jobs[1]);assert(#jobs==2,"auto-connect starts the transport")
assert(resume(jobs[2])==5,"ready socket uses the slow maintenance interval")
flush();assert(snapshots==1,"connection publishes an initial snapshot")
socket.OnMessage:Fire(http:JSONEncode({type="state",channel="names",value={version=1,userId="7",enabled=true,name=""}}))
resume(jobs[#jobs]);assert(restoredNames==1,"Larp mode without a custom name restores original names")
for _=1,3 do resume(jobs[2])end
assert(snapshots==1,"idle WebSocket does not rebuild snapshots during recovery checks")
body:GetPropertyChangedSignal("HeadColor3"):Fire()
body:GetPropertyChangedSignal("HeadColor3"):Fire()
humanoid.ApplyDescriptionFinished:Fire()
assert(#timers==1,"appearance event bursts coalesce")
flush();assert(snapshots==2,"appearance event publishes")
gui.AttributeChanged:Fire("Unrelated");assert(#timers==0,"unrelated UI attributes do not publish")
gui.AttributeChanged:Fire("HoneyBunCosmeticUI");flush();assert(snapshots==3,"cosmetic setting events publish")
character.DescendantRemoving:Fire(part);flush();local count=snapshots
part:GetPropertyChangedSignal("Color"):Fire();assert(#timers==0,"removed descendants lose subscriptions")
body:GetPropertyChangedSignal("HeadColor3"):Fire();sync.disconnect();flush()
assert(snapshots==count,"disconnect cancels pending snapshots")
body:GetPropertyChangedSignal("HeadColor3"):Fire();assert(#timers==0,"disconnect removes appearance subscriptions")
print("Idle WebSocket, event coalescing, descendant cleanup and disconnect passed.")
