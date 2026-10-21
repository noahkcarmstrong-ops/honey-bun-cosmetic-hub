local fs=require("@lune/fs")
local luau=require("@lune/luau")
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local self={UserId=1,Name="Self"}
local humanoid={Health=100,RigType="R6"}
local character={ChildAdded=signal(),FindFirstChildOfClass=function()return humanoid end,FindFirstChild=function()return {}end}
local peer={UserId=2,Name="Peer",Character=character,CharacterAdded=signal(),CharacterAppearanceLoaded=signal()}
local players={GetPlayers=function()return {self,peer}end,GetPlayerByUserId=function()return peer end}
local jobs,errors={},{}
local make=luau.load(fs.readFile("shared_larp.lua"),{environment={
 game={PlaceId=123,JobId="abc-123",GetService=function(_,name)return name=="Players" and players or {}end},
 task={spawn=function(f)table.insert(jobs,f)end,defer=function(f)table.insert(jobs,f)end},
 Enum={HumanoidRigType={R15="R15"}},
}})()
local function drain()while #jobs>0 do table.remove(jobs,1)()end end
local flags={}
local function dummy()return setmetatable({listAccessories=function()return {}end},{__index=function()return function()end end})end
local receive
local transport={setSharing=function()end,onShared=function(fn)receive=fn;return function()end end}
local snapshot={version=1,userId="2",items={},definition={assets={},bodyColors={},scales={}}}
local api=make(self,function()return nil end,function()return {}end,dummy,dummy,dummy,
 function()return {setVerified=function(v)table.insert(flags,v)end,restore=function()end,destroy=function()end}end,
 function()return true end,function(s)table.insert(errors,s)end,{transport=transport})
api.setEnabled(true);drain()
local function push(value)
 receive({type="upsert",record={version=1,userId="2",snapshot=snapshot,verified=value}});drain()
end
push(true);assert(flags[1]==true,"shared verification must reach the peer's overhead names")
push(true);assert(#flags==1,"identical record must not repeat work")
push(false);assert(flags[2]==false,"verification-only change must remove the peer badge")
api.destroy()
print("PASS: shared peer verification applies, deduplicates and disables without an outfit change.")
