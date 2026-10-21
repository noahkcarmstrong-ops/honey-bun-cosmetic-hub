local function signal()
 local listeners={}
 return {Connect=function(_,fn)listeners[#listeners+1]=fn;return {Disconnect=function()end}end,
 Fire=function(_,...)for _,fn in ipairs(listeners)do fn(...)end end}
end
table.clear=table.clear or function(t)for k in pairs(t)do t[k]=nil end end
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
local jobs={}
task={defer=function(fn)jobs[#jobs+1]=fn end,spawn=function(fn)jobs[#jobs+1]=fn end,delay=function()end}
local function drain()while #jobs>0 do table.remove(jobs,1)()end end
local ready,reads=false,0
local colors={}
for _,region in ipairs({'Head','Torso','LeftArm','RightArm','LeftLeg','RightLeg'})do colors[region..'Color3']={R=1,G=1,B=1}end
local desc=setmetatable({GetAccessories=function()return {}end},{__index=function()return 0 end})
Enum={HumanoidRigType={R15='R15',R6='R6'}}
local h={RigType='R15',FindFirstChild=function()end,GetAppliedDescription=function()reads=reads+1;return desc end}
local character={FindFirstChildOfClass=function(_,class)return class=='Humanoid' and h or colors end,GetDescendants=function()return {}end}
local player={UserId=1,Character=character,FindFirstChildOfClass=function()end}
local http={JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end}
game={GetService=function(_,name)return name=='HttpService' and http or {}end}
request=function()return {StatusCode=200,Body={instanceId='startup',code=string.rep('a',32)}}end
local socket={OnMessage=signal(),OnClose=signal(),Close=function()end}
local responses,clientResponses,auth={},{},nil
function socket:Send(value)
 if value.type=='auth'then auth=value;self.OnMessage:Fire({type='ready',instanceId='startup',sharing=true})end
 if value.type=='avatar-lookup-result'then responses[#responses+1]=value end
 if value.type=='client-result'then clientResponses[#clientResponses+1]=value end
end
WebSocket={connect=function()return socket end}
local settings={bodyParts={}}
local avatar={getSettings=function()return settings end,listAccessories=function()return {}end,removeCurrentAccessories=function()end}
local clothes={getSettings=function()return {}end}
local names={set=function()end,restore=function()end,setEnabled=function()end}
local shared,sync
local enabled=0
local backgroundId,backgrounds=0,{}
local backgroundChanges=0
sync=dofile('game_browser_sync.lua')(player,function()return avatar end,function()return clothes end,function()return true end,
 nil,nil,function()return names end,nil,{isReady=function()return ready end,
 lookupAvatar=function(target)assert(target==99);return {version=1,userId='1',items={}}end,
 clientRequest=function(method,params)assert(method=='test.echo','Unsupported client request.');return params end,
 getBackgroundState=function()return backgroundId,backgrounds end,
 setBackgroundState=function(id,choices)backgroundId=id; backgroundChanges=backgroundChanges+1;if choices then backgrounds=choices end end,
 setEnabled=function(value)
 if value then enabled=enabled+1;shared=sync.snapshotForSharing()end
end})
drain()
assert(auth.avatarLookup==true,'client advertises its native lookup support')
assert(auth.clientRequests==true,'client advertises the stable data request bridge')
socket.OnMessage:Fire({type='client-request',id='12345678-1234-1234-1234-123456789022',method='test.echo',params={value=42}});drain()
assert(clientResponses[1].result.value==42,'new named feature data goes through the same bridge')
socket.OnMessage:Fire({type='client-request',id='12345678-1234-1234-1234-123456789023',method='not.registered',params={}});drain()
assert(clientResponses[2].ok==false,'unregistered methods cannot execute')
socket.OnMessage:Fire({type='avatar-lookup',id='12345678-1234-1234-1234-123456789012',targetUserId='99'});drain()
assert(#responses==1 and responses[1].ok and responses[1].snapshot.userId=='1','one-shot account lookup returns through the same socket')
assert(reads==0,'lookup never reads the player character')
socket.OnMessage:Fire({type='avatar-lookup',id='bad',targetUserId='99'});drain()
assert(#responses==1,'malformed lookup requests are ignored')
local command={version=1,userId='1',revision=1,items={},definition={assets={},scales={},playerAvatarType={playerAvatarType='R15'},bodyColors={}}}
for _,key in ipairs({'head','torso','leftArm','rightArm','leftLeg','rightLeg'})do command.definition.bodyColors[key..'Color']='ffffff'end
socket.OnMessage:Fire({type='state',channel='browser',value=command})
socket.OnMessage:Fire({type='state',channel='names',value={version=1,userId='1',enabled=true,name='Alias',sharing=true}})
drain()
assert(sync.isConnected() and enabled==1 and shared.definition==command.definition,'sharing connects using the saved browser outfit before local restoration')
assert(reads==0,'startup must not inspect or mutate a half-restored local avatar')
ready=true;sync.resumeAppearance();drain()
assert(reads>0,'finishing restoration resumes the queued browser outfit and snapshot')
command.revision=2;command.backgroundId=42;command.backgrounds={{id=42,name='Backdrop'}}
socket.OnMessage:Fire({type='state',channel='browser',value=command});drain()
assert(backgroundId==42 and backgrounds[1].id==42,'a background-only command applies immediately through the socket')
assert(sync.publish().backgroundId==42,'the game confirms the applied background')
socket.OnMessage:Fire({type='state',channel='browser',value=command});drain()
assert(backgroundChanges==2,'a duplicate revision does not reapply the background')
command.revision=3;command.backgroundId=0
socket.OnMessage:Fire({type='state',channel='browser',value=command});drain()
assert(backgroundId==0 and sync.publish().backgroundId==0,'explicit removal clears and confirms the background')
socket.OnMessage:Fire({type='avatar-lookup',id='12345678-1234-1234-1234-123456789013',targetUserId='99'})
sync.destroy();drain()
assert(#responses==1,'disconnect cancels pending lookup work')
print('PASS: early connection and sharing, no partial-avatar publication, deferred appearance replay')
