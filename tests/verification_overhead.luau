local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("local_names.lua")
local first=assert(source:find("    local humanoids={}",1,true))
local last=assert(source:find("    local function refresh()",first,true))
local setFirst=assert(source:find("    function api.setVerified",last,true))
local setLast=assert(source:find("    function api.set(username",setFirst,true))
local make=luau.load([[return function(player,players,controller,originalDisplay)
]]..source:sub(first,last-1)..[[
local api={}
]]..source:sub(setFirst,setLast)..[[
api.apply=applyHumanoid
api.watch=watchCharacter
function api.restore()for h,name in pairs(humanoids)do h.DisplayName=name end end
return api
end]])()
local function signal()
 local listeners={}
 return {
  Connect=function(_,fn)table.insert(listeners,fn);return {Disconnect=function()for i,v in ipairs(listeners)do if v==fn then table.remove(listeners,i);break end end end}end,
  Fire=function(_,value)for _,fn in ipairs(listeners)do fn(value)end end,
  Count=function()return #listeners end,
 }
end
local function character(name,late)
 local changed=signal()
 local h
 if not late then h={DisplayName=name,IsA=function(_,kind)return kind=="Humanoid"end,GetPropertyChangedSignal=function()return changed end} end
 local c={ChildAdded=signal(),CharacterAdded=signal()}
 c.FindFirstChildOfClass=function()return h end
 return c,h,c.ChildAdded,changed
end
local own,ownH=character("Own Real")
local viewer={Character=own,CharacterAdded=signal()}
local settings={settings={enabled=true,displayName="Alias"}}
local self=make(viewer,{LocalPlayer=viewer},settings,"Own Real")
self.setVerified(true)
assert(ownH.DisplayName=="Alias","viewer must not receive an overhead badge")
local model,h=character("Peer Real")
local peer={Character=model,CharacterAdded=signal()}
local api=make(peer,{LocalPlayer=viewer},settings,"Peer Real")
local glyph=utf8.char(0xE000)
api.setVerified(true)
assert(h.DisplayName=="Alias"..glyph,"peer badge must be part of the native name")
api.setVerified(true)
assert(h.DisplayName=="Alias"..glyph,"updates must not duplicate the glyph")
api.setVerified(false)
assert(h.DisplayName=="Alias","turning verification off removes only the badge")
settings.settings.enabled=false;api.setVerified(true)
assert(h.DisplayName=="Peer Real"..glyph,"verification works without a custom alias")
local fresh,freshH=character("Respawn Real");peer.Character=fresh
api.watch(fresh)
assert(freshH.DisplayName=="Respawn Real"..glyph,"respawn uses its current native name")
api.restore()
assert(h.DisplayName=="Peer Real" and freshH.DisplayName=="Respawn Real","cleanup restores original overhead names")
api.setVerified(true)
assert(freshH.DisplayName=="Respawn Real"..glyph,"verification rebinds after restore")
api.setVerified(false)
local late,lateH,added,changed=character("Late Real",true);peer.Character=late
api.watch(late);api.setVerified(true)
assert(lateH==nil,"late character starts without a Humanoid")
lateH={DisplayName="Late Real",IsA=function(_,kind)return kind=="Humanoid"end,GetPropertyChangedSignal=function()return changed end}
late.FindFirstChildOfClass=function()return lateH end
added:Fire(lateH)
assert(lateH.DisplayName=="Late Real"..glyph,"Humanoid added after CharacterAdded receives the badge")
lateH.DisplayName="Game Overwrite";changed:Fire()
assert(lateH.DisplayName=="Late Real"..glyph,"game DisplayName overwrite is corrected")
local replacement=character("Replacement")
api.watch(replacement);lateH.DisplayName="Stale";changed:Fire()
assert(lateH.DisplayName=="Stale","old character listener is disconnected")
local views=fs.readFile("native_avatar_views.lua")
assert(not views:find('Instance.new("BillboardGui")',1,true),"portrait renderer must not create a floating overhead badge")
print("PASS: no self overhead badge; peers use native name glyph; toggle, alias-free mode, respawn and cleanup preserve names.")
