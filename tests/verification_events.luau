-- Exercise the production event scheduler without connecting to a Roblox session.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("native_avatar_views.lua")
local first=assert(source:find("    local verificationQueued=false",1,true))
local last=assert(source:find("    local function bindVerificationCharacter",first,true))
local chunk=source:sub(first,last-1)
local jobs,scans={},0
local fn=luau.load([[return function(task,renderVerification)
local alive,enabled,verified=true,true,true
local function read(o,k)return o[k]end
local function verificationText(o)return o.Text=="Alias" end
]]..chunk..[[
return queueVerification,function()alive=false end
end]])()
local queue,stop=fn({defer=function(f)table.insert(jobs,f)end},function()scans+=1 end)
for i=1,1000 do queue({ClassName="ImageLabel"});queue({ClassName="TextLabel",Text="Other"})end
assert(#jobs==0,"unrelated UI changes must not scan the interface")
for i=1,1000 do queue({ClassName="TextLabel",Text="Alias"})end
assert(#jobs==1,"one UI burst must schedule only one scan")
table.remove(jobs,1)()
assert(scans==1)
queue({ClassName="TextLabel",Text="Alias"});stop();table.remove(jobs,1)()
assert(scans==1,"destroy must cancel pending work")
print("PASS: unrelated UI changes do not scan; matching events coalesce; destroy cancels queued work.")
