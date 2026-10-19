-- Exercises the real backend against live-description and Animator stand-ins.
local function copy(t)
    if type(t)~='table' then return t end
    local c={};for k,v in pairs(t)do c[k]=copy(v)end;return c
end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={fn=fn,Connected=true};function c:Disconnect()self.Connected=false end;self.listeners[#self.listeners+1]=c;return c end
    function s:Fire(...)for _,c in ipairs(self.listeners)do if c.Connected then c.fn(...)end end end
    return s
end
Enum={HumanoidRigType={R15='R15',R6='R6'},CoreGuiType={EmotesMenu='EmotesMenu'}}
local jobs={}
task={spawn=function(fn)jobs[#jobs+1]=fn end,wait=function()end}
local function flush()local pending=jobs;jobs={};for _,fn in ipairs(pending)do fn()end end
local encoded,attributes={},{}
local http={JSONEncode=function(_,v)encoded=copy(v);return'saved'end,JSONDecode=function(_,v)return v=='saved' and copy(encoded) or {}end}
local gui={GetAttribute=function(_,k)return attributes[k]end,SetAttribute=function(_,k,v)attributes[k]=v end}
local wheelEnabled=true
local starter={GetCoreGuiEnabled=function()return wheelEnabled end}
local guiService={SetEmotesMenuOpen=function(_,value)assert(value==true)end}
local function character(rig)
    local c={}
    local desc={Parent=true,emotes={Wave={111},Dance={222}},equipped={{Slot=1,Name='Wave'},{Slot=8,Name='Dance'}}}
    function desc:GetEmotes()return copy(self.emotes)end
    function desc:GetEquippedEmotes()return copy(self.equipped)end
    function desc:SetEmotes(v)for name,ids in pairs(v)do assert(type(name)=='string' and type(ids[1])=='number')end;self.emotes=copy(v)end
    function desc:SetEquippedEmotes(v)for _,entry in ipairs(v)do assert(self.emotes[entry.Name])end;self.equipped=copy(v)end
    local h={Health=100,RigType=rig or 'R15',Parent=c}
    function h:FindFirstChildOfClass(name)return ({HumanoidDescription=desc})[name]end
    function h:GetAppliedDescription()error('Must edit live description, not a copy')end
    function h:PlayEmoteAsync(name)assert(desc.emotes[name]);self.playedEmote=name;return true end
    function c:FindFirstChildOfClass(name)if name=='Humanoid'then return h end end
    return c,h,desc
end
local c,h,desc=character()
local player={Character=c,CharacterAdded=signal(),FindFirstChildOfClass=function()return gui end,HasAppearanceLoaded=function()return true end}
game={GetService=function(_,name)return({HttpService=http,StarterGui=starter,GuiService=guiService})[name]end,GetObjects=function()return{}end}
local make=dofile('motion.lua')
local messages={}
local api=make(player,function(m)messages[#messages+1]=m end)
api.setEmote(3,'https://www.roblox.com/catalog/333/Emote')
api.setEmote(6,666)
assert(desc.emotes['Honey Bun Slot 3'][1]==333 and #desc.equipped==4,'Adds multiple slots and preserves original slots')
api.setEmote(1,999);assert(desc.equipped[1].Name=='Honey Bun Slot 1','Assigned slot replaces original')
api.clearEmote(1);assert(desc.equipped[1].Name=='Wave','Reset restores original assignment in that slot')
api.clearEmote(3)
assert(desc.emotes['Honey Bun Slot 3']==nil and #desc.equipped==3,'Clearing one preserves other assignments')
api.playEmote(6);assert(h.playedEmote=='Honey Bun Slot 6','Preview plays instead of just opening wheel')
api.openWheel();wheelEnabled=false;assert(not pcall(api.openWheel),'Disabled wheel explained');wheelEnabled=true
for _,value in ipairs({'junk123','https://evil.example/catalog/123',0,-1,1.5})do assert(not pcall(api.setEmote,2,value),'Invalid asset rejected')end
assert(not pcall(api.setEmote,9,123),'Invalid slot rejected')
local c2,h2,d2=character();player.Character=c2;player.CharacterAdded:Fire(c2);flush()
assert(d2.emotes['Honey Bun Slot 6'][1]==666,'Respawn restores wheel')
api.destroy()
assert(d2.emotes['Honey Bun Slot 6']==nil and d2.emotes.Wave[1]==111,'Destroy restores original live wheel')
local refreshed=make(player);refreshed.reapplySaved()
assert(refreshed.getSlots()[6].id==666 and d2.emotes['Honey Bun Slot 6'],'Refresh retains saved slots')
refreshed.restore()
assert(not next(refreshed.getSlots()) and d2.emotes['Honey Bun Slot 6']==nil,'Restore clears saved assignments')
refreshed.destroy()
local c3=character('R6');player.Character=c3
local r6=make(player);assert(not pcall(r6.setEmote,1,123),'R6 wheel rejected with clear message');r6.destroy()
print('Emote live wheel, slot persistence, preview, validation, respawn and restore checks passed.')
