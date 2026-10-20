-- Source selection must keep the loader and all modules on one revision.
local sha=string.rep("a",40)
local urls,loaded={}
game={GetService=function()return {
    UrlEncode=function(_,value)return value:gsub("/","%%2F")end,
    JSONDecode=function()return {sha=sha}end,
}end,HttpGet=function(_,url)urls[#urls+1]=url;return "fixture"end}
DateTime={now=function()return {UnixTimestampMillis=1}end}
loadstring=function()return function(options)loaded=options end end
assert(loadfile("launcher.lua"))("fix/events")
assert(urls[1]:find("commits/fix%2Fevents",1,true),"selected branch is resolved")
assert(urls[2]:find("/"..sha.."/loader.lua",1,true),"loader uses the resolved commit")
assert(loaded.branch=="fix/events" and loaded.revision==sha,"modules receive the same branch and commit")

assert(loadfile("autoexec.lua"))()
assert(loaded=="main","autoexec forwards the selected remote branch")

-- Exercise actual loader startup until UI construction, after storage was loaded.
local readFiles={}
local playerGui={FindFirstChild=function()end}
local player={UserId=7,WaitForChild=function(_,name)assert(name=="PlayerGui");return playerGui end}
local httpCalls=0
game={GetService=function(_,name)
    if name=="Players"then return {LocalPlayer=player}end
    if name=="RunService"then return {IsClient=function()return true end}end
end,HttpGet=function()httpCalls=httpCalls+1;error("local branch attempted HTTP")end}
Color3={fromRGB=function()return {}end}
loadstring=function(source)assert(source=="local-storage");return function()return function()return {}end end end
Instance={new=function()error("STOP_AFTER_STORAGE",0)end}
local ok,err=pcall(assert(loadfile("loader.lua")),{branch="fix/events",readSource=function(file)
    readFiles[#readFiles+1]=file;return "local-storage"
end})
assert(not ok and tostring(err):find("STOP_AFTER_STORAGE",1,true),tostring(err))
assert(readFiles[1]=="storage.lua" and httpCalls==0,"local modules use the selected snapshot")
print("Branch resolution and local loader source selection passed.")
