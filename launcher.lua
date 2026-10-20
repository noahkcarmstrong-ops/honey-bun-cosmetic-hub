-- Select a branch once, then pin the loader and its modules to the same commit.
local branch = ... or "main"
local Http=game:GetService("HttpService")
local stamp=tostring(DateTime.now().UnixTimestampMillis)
local revision=Http:JSONDecode(game:HttpGet("https://api.github.com/repos/noahkcarmstrong-ops/larpblox/commits/"..Http:UrlEncode(branch).."?refresh="..stamp,false))
local sha=revision and revision.sha
assert(type(sha)=="string" and #sha==40 and sha:match("^%x+$"),"GitHub could not find the latest Larpblox update. Try again.")
local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/"..sha.."/loader.lua",false)
local run,message=loadstring(source)
assert(run,message)
run({branch=branch,revision=sha})
