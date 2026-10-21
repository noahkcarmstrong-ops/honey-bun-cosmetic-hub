local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("local_names.lua")
local first=assert(source:find("    local humanoids={}",1,true))
local last=assert(source:find("    local characterConnection=",first,true))
local setFirst=assert(source:find("    function api.setVerified",last,true))
local setLast=assert(source:find("\n",setFirst,true))
local make=luau.load([[return function(player,players,controller,originalDisplay)
]]..source:sub(first,last-1)..[[
local api={}
]]..source:sub(setFirst,setLast)..[[
api.apply=applyHumanoid
function api.restore()for h,name in pairs(humanoids)do h.DisplayName=name end end
return api
end]])()
local function character(name)
 local h={DisplayName=name}
 return {FindFirstChildOfClass=function()return h end},h
end
local own,ownH=character("Own Real")
local viewer={Character=own}
local settings={settings={enabled=true,displayName="Alias"}}
local self=make(viewer,{LocalPlayer=viewer},settings,"Own Real")
self.setVerified(true)
assert(ownH.DisplayName=="Alias","viewer must not receive an overhead badge")
local model,h=character("Peer Real")
local peer={Character=model}
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
api.apply(fresh)
assert(freshH.DisplayName=="Respawn Real"..glyph,"respawn uses its current native name")
api.restore()
assert(h.DisplayName=="Peer Real" and freshH.DisplayName=="Respawn Real","cleanup restores original overhead names")
local views=fs.readFile("native_avatar_views.lua")
assert(not views:find('Instance.new("BillboardGui")',1,true),"portrait renderer must not create a floating overhead badge")
print("PASS: no self overhead badge; peers use native name glyph; toggle, alias-free mode, respawn and cleanup preserve names.")
