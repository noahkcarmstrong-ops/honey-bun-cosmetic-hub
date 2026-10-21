-- Deterministic slow-load regression: no network or wall-clock sleeps.
local function signal()
 return {Connect=function()return {Disconnect=function()end}end}
end
local self={UserId=1,Name='Self'}
local function player(id)
 local h={Health=100,RigType='R15',FindFirstChild=function()end}
 local c={ChildAdded=signal(),FindFirstChildOfClass=function()return h end,FindFirstChild=function()return {}end}
 return {UserId=id,Name='Player'..id,Character=c,CharacterAdded=signal(),CharacterAppearanceLoaded=signal()}
end
local peers={[2]=player(2),[3]=player(3)}
local players={GetPlayers=function()return {self,peers[2],peers[3]}end,GetPlayerByUserId=function(_,id)return peers[id]end,
 PlayerAdded=signal(),PlayerRemoving=signal()}
game={PlaceId=1,JobId='test-job',GetService=function(_,name)return name=='Players' and players or {}end}
Enum={HumanoidRigType={R15='R15',R6='R6'}}
local jobs,blocked={},{}
task={spawn=function(fn)jobs[#jobs+1]=coroutine.create(fn)end,defer=function(fn)jobs[#jobs+1]=coroutine.create(fn)end}
local function drain()
 while #jobs>0 do
  local thread=table.remove(jobs,1)
  local ok,reason=coroutine.resume(thread);assert(ok,reason)
  if coroutine.status(thread)~='dead' then blocked[#blocked+1]=thread end
 end
end
local names,views,bodies,accessories,destroyed={},{},{},{},{}
local receive
local block=true
local function avatar(p)
 local equipped={}
 local api={destroy=function()destroyed[p.UserId]=true end,removeCurrentAccessories=function()end,
  listAccessories=function()local result={}for id in pairs(equipped)do result[#result+1]={id=id,key=id}end;return result end,
  equipAccessory=function(id)equipped[id]=true;accessories[p.UserId]=id end,
  removeAccessory=function(id)equipped[id]=nil end,
  applyBodyPart=function()error('complete shared bodies must not generate six separate rigs')end,
  applyBodyParts=function(body)
   assert(names[p.UserId] and views[p.UserId],'name and portrait must be presented before body loading')
   bodies[p.UserId]=(bodies[p.UserId] or 0)+1
   if p.UserId==2 and block then coroutine.yield('asset load')end
  end}
 return api
end
local function clothes()return {destroy=function()end,removeShirt=function()end,removePants=function()end,removeTShirt=function()end}end
local function animations()return {destroy=function()end}end
local function nameApi(p)return {destroy=function()end,set=function(name)names[p.UserId]=name end,restore=function()names[p.UserId]=nil end}end
local function record(id,asset,name)
 return {version=1,userId=tostring(id),snapshot={version=1,userId=tostring(id),definition={assets={{id=asset}},scales={}},items={{id=asset,assetType=8}}},
  name={enabled=true,username=name,displayName=name}}
end
local transport={setSharing=function()end,onShared=function(fn)receive=fn;return function()end end}
local sync=dofile('shared_larp.lua')(self,function()return record(1,1,'Self').snapshot end,function()return {}end,
 avatar,clothes,animations,nameApi,function()return true end,function()end,{transport=transport,
 createViews=function(p)return {update=function(options)assert(options.snapshot,'portrait needs the received snapshot');views[p.UserId]=options.name end,destroy=function()end}end})
drain();sync.setEnabled(true)
local first=record(2,20,'FirstAlias');local other=record(3,30,'OtherAlias')
receive({type='snapshot',players={first,other}})
assert(names[2]=='FirstAlias' and names[3]=='OtherAlias','names apply in the receive event before any asset jobs run')
drain()
assert(#blocked==1 and bodies[2]==1 and bodies[3]==1 and accessories[3]==30,'one slow body must not block a different player')
receive({type='upsert',record=record(2,21,'Intermediate')})
receive({type='upsert',record=record(2,22,'LatestAlias')})
assert(names[2]=='LatestAlias' and views[2]=='LatestAlias','new names bypass an older pending body load')
block=false
jobs[#jobs+1]=table.remove(blocked,1);drain()
assert(accessories[2]==22 and bodies[2]==2,'superseded record must stop before equipping old accessories; latest update is coalesced')
local count=bodies[2];receive({type='upsert',record=record(2,22,'LatestAlias')});drain()
assert(bodies[2]==count,'identical records perform no extra body work')
sync.setEnabled(false);sync.setEnabled(true);block=true
receive({type='upsert',record=record(2,23,'Pending')});drain()
assert(#blocked==1,'cancellation test must reach a pending body load')
sync.setEnabled(false);block=false;jobs[#jobs+1]=table.remove(blocked,1);drain()
assert(accessories[2]==22 and destroyed[2],'disabling sharing cancels pending accessory application')
sync.destroy()
local profiles={[2]=record(2,50,'SavedAlias')}
local fetches=0
sync=dofile('shared_larp.lua')(self,function()return record(1,1,'Self').snapshot end,function()return {}end,
 avatar,clothes,animations,nameApi,function()return true end,function()end,{transport=transport,
 fetchProfiles=function(ids)
  fetches=fetches+1;local out={};for _,id in ipairs(ids)do if profiles[tonumber(id)]then out[#out+1]=profiles[tonumber(id)]end end;return out
 end,
 createViews=function(p)return {update=function(options)views[p.UserId]=options.name end,destroy=function()end}end})
drain();sync.setEnabled(true);drain()
assert(names[2]=='SavedAlias' and accessories[2]==50,'a saved extension profile applies without a peer game connection')
receive({type='snapshot',players={}});drain()
assert(names[2]=='SavedAlias','an empty live room must not remove a saved profile')
receive({type='upsert',record=record(2,51,'LiveAlias')});drain()
assert(names[2]=='LiveAlias' and accessories[2]==51,'live game updates override the saved profile')
receive({type='remove',userId='2'});drain()
assert(names[2]=='SavedAlias' and accessories[2]==50,'disconnecting the peer game returns to its saved profile')
profiles[2]=nil;destroyed[2]=nil
receive({type='remove',userId='2'});drain()
assert(destroyed[2],'removing a public profile restores the original appearance')
assert(fetches==3 and #jobs==0,'profile lookups follow lifecycle events without polling')
sync.destroy()
print('PASS: immediate names and portraits, independent peer loads, one body call, coalescing, deduplication and cancellation')
