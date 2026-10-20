-- Select a branch once, then pin the loader and its modules to the same commit.
local branch = ... or "main"
local function trace(stage)
    if type(writefile)=="function" then pcall(writefile,"larpblox-startup.log",stage)end
end
trace("Resolving branch: "..branch)
-- Autoexec may run before the character/appearance exists, even after Loaded.
-- Start cosmetic and native-UI work only after the initial avatar is ready.
trace("Waiting for game and avatar readiness")
if not game:IsLoaded() then game.Loaded:Wait() end
local Players=game:GetService("Players")
while not Players.LocalPlayer do Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
local player=Players.LocalPlayer
local readySignal=Instance.new("BindableEvent")
local connections={}
local characterConnection
local finished,timedOut=false,false
local function checkReady()
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health>0 and character:FindFirstChild("HumanoidRootPart") and player:HasAppearanceLoaded()then
        finished=true;readySignal:Fire()
    end
end
local function watchCharacter(character)
    if characterConnection then characterConnection:Disconnect()end
    characterConnection=character and character.ChildAdded:Connect(checkReady)or nil
    checkReady()
end
connections[#connections+1]=player.CharacterAdded:Connect(watchCharacter)
connections[#connections+1]=player.CharacterAppearanceLoaded:Connect(checkReady)
watchCharacter(player.Character)
task.delay(30,function()if not finished then timedOut=true;finished=true;readySignal:Fire()end end)
if not finished then readySignal.Event:Wait()end
for _,connection in ipairs(connections)do connection:Disconnect()end
if characterConnection then characterConnection:Disconnect()end
readySignal:Destroy()
if timedOut then trace("Avatar readiness timed out; run Larpblox after spawning.");warn("Larpblox: avatar is not ready yet. Run the script again after spawning.");return end
trace("Avatar ready; resolving branch: "..branch)
local Http=game:GetService("HttpService")
local stamp=tostring(DateTime.now().UnixTimestampMillis)
local revision=Http:JSONDecode(game:HttpGet("https://api.github.com/repos/noahkcarmstrong-ops/larpblox/commits/"..Http:UrlEncode(branch).."?refresh="..stamp,false))
local sha=revision and revision.sha
assert(type(sha)=="string" and #sha==40 and sha:match("^%x+$"),"GitHub could not find the latest Larpblox update. Try again.")
trace("Downloading loader: "..sha)
local source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/"..sha.."/loader.lua",false)
trace("Compiling loader: "..sha)
local run,message=loadstring(source)
assert(run,message)
trace("Starting loader: "..sha)
local ok,err=pcall(run,{branch=branch,revision=sha,trace=trace})
if not ok then trace("Startup error: "..tostring(err));error(err,0)end
