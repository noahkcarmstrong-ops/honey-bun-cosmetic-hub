local function signal()
 local s={listeners={}};function s:Connect(fn)local c={active=true};function c:Disconnect()self.active=false end;self.listeners[#self.listeners+1]={c,fn};return c end
 function s:Fire(...)for _,v in ipairs(self.listeners)do if v[1].active then v[2](...)end end end;return s
end
local methods={};local objects={}
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)t.props[k]=v end}
Instance={new=function(class)
 local o=setmetatable({props={ClassName=class,Name=class,Visible=true,TextTransparency=0,Activated=signal(),Size={},Position={},AnchorPoint={}}},meta);objects[#objects+1]=o;return o
end}
function methods:GetChildren()local list={};for _,o in ipairs(objects)do if o.Parent==self then list[#list+1]=o end end;return list end
function methods:GetDescendants()local list={};local function walk(p)for _,o in ipairs(p:GetChildren())do list[#list+1]=o;walk(o)end end;walk(self);return list end
function methods:FindFirstChild(n)for _,o in ipairs(self:GetChildren())do if o.Name==n then return o end end end
function methods:IsA(c)
 return c==self.ClassName or c=='GuiObject' and (self.ClassName=='Frame' or self.ClassName=='TextLabel' or self.ClassName=='TextButton' or self.ClassName=='ImageLabel') or c=='GuiButton' and self.ClassName=='TextButton' or c=='LuaSourceContainer' and self.ClassName=='LocalScript'
end
function methods:FindFirstChildOfClass(c)for _,o in ipairs(self:GetChildren())do if o.ClassName==c then return o end end end
function methods:IsDescendantOf(p)local o=self.Parent;while o do if o==p then return true end;o=o.Parent end;return false end
function methods:Clone()local o=Instance.new(self.ClassName);for k,v in pairs(self.props)do if k~='Parent' and k~='Activated'then o.props[k]=v end end;for _,v in ipairs(self:GetChildren())do local c=v:Clone();c.Parent=o end;return o end
function methods:Destroy()for _,v in ipairs(self:GetChildren())do v:Destroy()end;self.Parent=nil end
local function node(class,name,parent)local o=Instance.new(class);o.Name=name;o.Parent=parent;return o end
local function find(root,n)for _,o in ipairs(root:GetDescendants())do if o.Name==n then return o end end end
Enum={KeyCode={},UserInputState={Begin='Begin',End='End'},ContextActionResult={Pass='Pass',Sink='Sink'}}
for _,k in ipairs({'Q','E','One','Two','Three','Four','Five','Six','Seven','Eight'})do Enum.KeyCode[k]={Name=k}end
local cas={};function cas:BindActionAtPriority(_,fn)self.callback=fn end;function cas:UnbindAction()self.callback=nil end
local heartbeat=signal();local input={GetFocusedTextBox=function()return nil end}
local game={GetService=function(_,name)return ({ContextActionService=cas,RunService={Heartbeat=heartbeat},UserInputService=input})[name]end}
local gui=node('PlayerGui','PlayerGui');local cp=node('ScreenGui','CrossPlatform',gui);local bar=node('Frame','Emotes',cp);local body=node('Frame','_',bar)
local pages=node('Frame','EmotePages',body)
local header=node('TextLabel','Title',body);header.Text='Game Emotes (1/1)'
local q=node('TextButton','Previous',body);q.Text='Q';local e=node('TextButton','Next',body);e.Text='E'
local page=node('Frame','Game Emotes (1/1)',pages);local box=node('Frame','Container',page)
node('UIListLayout','List',box)
local toy=node('Frame','Toy',box);local inside=node('Frame','Container',toy)
node('TextLabel','EmoteName',inside).Text='Witches Brew';node('ImageLabel','Icon',inside).Image='toy'
node('TextLabel','Hotkey',inside).Text='1';node('TextButton','Button',inside)
node('LocalScript','MustNotCopy',toy)
local your=node('Frame','Your Emotes (1/8)',pages);your.Visible=false
local entries={};for i=1,10 do entries[i]={id='e'..i,name='Emote '..i,image=100+i}end
local played
local api=dofile('emote_bar.lua')(gui,{list=function(k)assert(k=='Emote');return entries end,preview=function(id)played=id;return'Playing'end},nil,game)
assert(api.enable());assert(page.Visible,'Native toy page remains first')
local catalogPage=find(pages,'HoneyBunLocal_EmotePage_1');assert(catalogPage and not catalogPage.Visible,'Catalog has separate added pages')
assert(find(catalogPage,'List'),'Preserves native list layout')
assert(not find(catalogPage,'MustNotCopy'),'Cloned scripts stripped')
assert(cas.callback(nil,'Begin',{KeyCode=Enum.KeyCode.One})=='Pass','Native page keeps native tool number keys')
assert(cas.callback(nil,'Begin',{KeyCode=Enum.KeyCode.E})=='Sink','Custom paging consumes E')
assert(not page.Visible and catalogPage.Visible,'E opens first catalog page')
local first=find(catalogPage,'HoneyBunLocal_EmoteCard_e1')
assert(find(first,'EmoteName').Text=='Emote 1' and find(first,'Icon').Image=='rbxassetid://101','Native nested labels and icons replaced')
assert(find(first,'Hotkey').Text=='1','Catalog hotkeys start at one on each page')
find(first,'Button').Activated:Fire();assert(played=='e1','Click uses selected emote')
cas.callback(nil,'Begin',{KeyCode=Enum.KeyCode.Two});assert(played=='e2','Roblox Two key maps to second emote')
find(body,'HoneyBunLocal_EmoteE').Activated:Fire()
assert(find(pages,'HoneyBunLocal_EmotePage_2').Visible,'Onscreen next button changes page')
assert(find(body,'HoneyBunLocal_EmotePageTitle').Text=='Game Emotes (3/3)','Caption counts native and added pages')
header.Text='Your Emotes (1/8)';your.Visible=true;heartbeat:Fire(.2)
assert(not catalogPage.Visible and your.Visible,'Native other sections remain untouched')
assert(cas.callback(nil,'Begin',{KeyCode=Enum.KeyCode.One})=='Pass','Other sections retain native keys')
header.Text='Game Emotes (1/1)';your.Visible=false;heartbeat:Fire(.2)
assert(find(pages,'HoneyBunLocal_EmotePage_2').Visible,'Returning to Game resumes catalog page')
bar.Visible=false;heartbeat:Fire(.2)
assert(cas.callback(nil,'Begin',{KeyCode=Enum.KeyCode.E})=='Pass','Closed bar cannot intercept gameplay keys')
api.disable();assert(page.Visible and not catalogPage.Parent and header.TextTransparency==0 and not cas.callback,'Off restores original native page, header, controls and input')
bar.Visible=true;api.enable();assert(page.Visible,'Reenable does not duplicate or lose native page')
api.destroy();assert(page.Visible and not cas.callback,'Destroy cleans up')
print('Native emote bar pages, nested cards, keys, section switching, toy preservation and cleanup passed.')
