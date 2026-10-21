local fs=require('@lune/fs')
local luau=require('@lune/luau')
local source=fs.readFile('game_browser_sync.lua')
local first=assert(source:find('    local function applyNameState(value)',1,true))
local last=assert(source:find('    local function closeSocket()',first,true))
local flags,views={},{}
local names={set=function()end,restore=function()end,setEnabled=function()end,setVerified=function(value)table.insert(flags,value)end}
local fn=luau.load([[return function(names,views)
local player={UserId=7}
local lastModeValue,lastNameState,lastSharingPreference
local browserModeKnown,larpEnabled=false,false
local larpName,larpVerified='',false
local function readyForAppearance()return false end
local function getNames()return names end
local function getViews()return {update=function(v)table.insert(views,v)end}end
local function currentImage()end
local function notifySnapshot()end
]]..source:sub(first,last-1)..[[
return applyNameState
end]])()(names,views)
fn({version=1,userId='7',enabled=true,name='Alias',verified=true})
assert(flags[1]==true,'own name handler must receive enabled verification')
assert(views[1].verified==true,'own leaderboard renderer must receive verification')
fn({version=1,userId='7',enabled=true,name='',verified=true})
assert(flags[2]==true,'verification must work without a custom username')
fn({version=1,userId='7',enabled=false,name='',verified=true})
assert(flags[3]==false,'turning Larp mode off removes verification')
print('PASS: own name and leaderboard receive verification, including alias-free mode and disable.')
