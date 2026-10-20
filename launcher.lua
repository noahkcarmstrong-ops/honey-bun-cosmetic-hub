-- Stable launcher: resolve GitHub main before loading an immutable script URL.
local Http=game:GetService("HttpService")
local stamp=tostring(DateTime.now().UnixTimestampMillis)
local revision=Http:JSONDecode(game:HttpGet("https://api.github.com/repos/noahkcarmstrong-ops/larpblox/commits/main?refresh="..stamp,false))
local sha=revision and revision.sha
assert(type(sha)=="string" and #sha==40 and sha:match("^%x+$"),"GitHub could not find the latest Larpblox update. Try again.")
local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/"..sha.."/loader.lua",false)
local run,message=loadstring(source)
assert(run,message)
run()
