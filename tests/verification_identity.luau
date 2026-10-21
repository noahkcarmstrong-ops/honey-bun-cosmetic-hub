-- Verify own labels remain matchable when Roblox appends its '(You)' marker.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("native_avatar_views.lua")
local first=assert(source:find("    local function verificationText(object)",1,true))
local last=assert(source:find("    local function verifiedRosterRow",first,true))
local matcher=luau.load([[return function(player,currentName,currentDisplayName)
local function read(o,k)return o[k]end
local function plainText(value)return tostring(value or ""):gsub("<[^>]->","")end
]]..source:sub(first,last-1)..[[
return verificationText
end]])()
local match=matcher({Name="Original",DisplayName="Original Display"},"Alias","Alias")
assert(match({Text="Alias (You)"}),"custom alias with Roblox own marker must match")
assert(match({Text="Original (You)"}),"username with Roblox own marker must match")
assert(match({Text="Original Display (You)"}),"display name with Roblox own marker must match")
assert(not match({Text="@Alias (You)"}),"handles must remain excluded from normal label matching")
print("PASS: own verification labels match through Roblox '(You)' suffix.")
