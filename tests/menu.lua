-- Exercises the real menu's tab actions, validation, Refresh, and cleanup.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={Connected=true,fn=fn}
        function c:Disconnect() self.Connected=false end
        self.listeners[#self.listeners+1]=c;return c
    end
    function s:Fire(...) for _,c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
    return s
end
local objects,methods={},{}
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)t.props[k]=v end}
Instance={new=function(class,parent)
    local o=setmetatable({props={ClassName=class,Name=class,Parent=parent,Visible=true,Activated=signal(),FocusLost=signal(),Destroying=signal()}},meta)
    objects[#objects+1]=o;return o
end}
function methods:GetChildren()local list={};for _,o in ipairs(objects)do if o.Parent==self then list[#list+1]=o end end;return list end
function methods:FindFirstChild(name)for _,o in ipairs(self:GetChildren())do if o.Name==name then return o end end end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name))end
function methods:GetAttribute(key)return self.attributes and self.attributes[key]end
function methods:SetAttribute(key,value)self.attributes=self.attributes or {};self.attributes[key]=value end
function methods:Destroy()
    if self.destroyed then return end
    self.destroyed=true;self.Destroying:Fire()
    for _,o in ipairs(self:GetChildren())do o:Destroy()end
    self.Parent=nil
end
function methods:Clone()
    local clone=Instance.new(self.ClassName)
    for k,v in pairs(self.props)do if k~='Parent' and k~='Destroying' and k~='Activated' and k~='FocusLost' then clone[k]=v end end
    return clone
end
Vector2={new=function(x,y)return{X=x,Y=y}end}
UDim={new=function(s,o)return{Scale=s,Offset=o}end}
UDim2={new=function(...)return{...}end,fromOffset=function(...)return{...}end}
Color3={fromRGB=function(r,g,b)return{R=r,G=g,B=b}end}
local function enum()return setmetatable({},{__index=function(t,k)local v=enum();rawset(t,k,v);return v end})end
Enum=enum();DateTime={now=function()return{UnixTimestampMillis=123}end};task={spawn=function(fn)fn()end}
local guiRoot=Instance.new('PlayerGui');local player=Instance.new('Player');guiRoot.Parent=player;player.CharacterAdded=signal()
local input={InputBegan=signal(),GetFocusedTextBox=function()return nil end}
local calls={equip=0,skin=0,body=0,destroy=0,restore=0,current=0}
local slots={}
local function createMotion()
    return {
        getSlots=function()return slots end,
        setEmote=function(slot,value)slots[slot]={id=value,name='Emote '..value};calls.emoteSlot=slot;return'Assigned'end,
        clearEmote=function(slot)slots[slot]=nil;return'Reset'end,
        playEmote=function(slot)calls.preview=slot;return'Playing'end,
        openWheel=function()calls.wheel=true;return'Opened'end,
        reapplySaved=function()return'Restored'end,
        restore=function()calls.motionRestore=true;return'Restored'end,
        destroy=function()calls.motionDestroy=true end,
    }
end
local function createAnimations()
    return {
        equipBundle=function(value)calls.animationBundle=value;return'Equipped'end,
        restore=function()calls.animationRestore=true;return'Restored'end,
        reapplySaved=function()return'Restored'end,
        destroy=function()calls.animationDestroy=true end,
    }
end
local function createClothes()
    return {
        equipShirt=function(value)calls.shirt=value;return'Equipped'end,
        equipPants=function(value)calls.pants=value;return'Equipped'end,
        restoreShirt=function()calls.shirtRestore=true;return'Restored'end,
        restorePants=function()calls.pantsRestore=true;return'Restored'end,
        restore=function()calls.clothesRestore=true;return'Restored'end,
        reapplySaved=function()calls.clothesReplay=(calls.clothesReplay or 0)+1;return'Restored'end,
        destroy=function()calls.clothesDestroy=true end,
    }
end
local function createEditor()
    local equipped,nextKey={},0
    return {
        equipAccessory=function(value)
            if value=='bad' then error('Unavailable fixture') end
            calls.equip=calls.equip+1;calls.item=value;nextKey=nextKey+1
            equipped[#equipped+1]={key=nextKey,name='Hat '..value}
            return'Equipped fixture'
        end,
        listAccessories=function()return equipped end,
        removeAccessory=function(key)for i,item in ipairs(equipped)do if item.key==key then table.remove(equipped,i);return'Removed'end end end,
        clearAccessories=function()return'Cleared'end,
        removeCurrentAccessories=function()calls.current=calls.current+1;return'Removed current accessories'end,
        setSkin=function(color,region)calls.skin=calls.skin+1;calls.color=color;calls.region=region;return'Color applied'end,
        restoreSkin=function()calls.skinRestore=true;return'Original skin restored'end,
        applyBody=function(value)calls.body=calls.body+1;calls.package=value;return'Body applied'end,
        restore=function()calls.restore=calls.restore+1;return'Restored'end,
        reapplySaved=function()if calls.failReplay then error('Fixture avatar unavailable')end;return'Saved cosmetics restored.'end,
        getSettings=function()return{accessories={},colors={}}end,
        destroy=function()calls.destroy=calls.destroy+1 end,
    }
end
game={GetService=function(_,name)return({Players={LocalPlayer=player},UserInputService=input,HttpService={JSONDecode=function()return{sha=string.rep('a',40)}end}})[name]end}
function game:HttpGet(url)
    assert(url:find('/honey-bun-cosmetic-hub/',1,true),'Only the separate cosmetic repo is contacted')
    if url:find('/commits/main',1,true)then return'revision'end
    assert(url:find('/'..string.rep('a',40)..'/',1,true),'Modules and Refresh use immutable commits')
    if url:find('/avatar.lua',1,true)then return'editor-module'end
    if url:find('/motion.lua',1,true)then return'motion-module'end
    if url:find('/animations.lua',1,true)then return'animations-module'end
    if url:find('/storage.lua',1,true)then return'storage-module'end
    if url:find('/clothes.lua',1,true)then return'clothes-module'end
    if url:find('/loader.lua',1,true)then return'loader'end
    error('Unexpected request '..url)
end
loadstring=function(source)
    if source=='editor-module'then return function()return createEditor end end
    if source=='motion-module'then return function()return createMotion end end
    if source=='animations-module'then return function()return createAnimations end end
    if source=='clothes-module'then return function()return createClothes end end
    if source=='storage-module'then return function()return function()
        calls.storageLoaded=true
        return{status=function()return'Auto-save: on'end,destroy=function()calls.storageDestroyed=true end}
    end end end
    if source=='loader'then return function()dofile('loader.lua')end end
    error('Unexpected source')
end
local function gui()return assert(guiRoot:FindFirstChild('HoneyBunCosmeticHub'))end
local function find(root,class,text)
    for _,child in ipairs(root:GetChildren())do
        if child.ClassName==class and child.Text==text then return child end
        local nested=find(child,class,text);if nested then return nested end
    end
end
local function click(text)assert(find(gui(),'TextButton',text),'Missing button '..text).Activated:Fire()end
local function field(placeholder)
    for _,o in ipairs(objects)do if not o.destroyed and o.ClassName=='TextBox' and o.PlaceholderText==placeholder then return o end end
    error('Missing field '..placeholder)
end
dofile('loader.lua')
assert(not guiRoot:FindFirstChild('HoneyBunHub'),'Cosmetic menu never creates the original hub')
field('Paste accessory links or IDs here').Text='123, 456\nbad'
click('Add accessories');assert(calls.equip==2 and calls.item=='456','Batch adds both hats')
assert(field('Paste accessory links or IDs here').Text=='bad','Only failed entries remain for retry')
assert(find(gui(),'TextLabel','YOUR ADDED ACCESSORIES (2 / 20)'),'Both hats remain listed')
field('Paste accessory links or IDs here').Text='789'
click('Add accessories');assert(calls.equip==3,'Another add keeps previous hats')
assert(field('Paste accessory links or IDs here').Text=='','Successful input clears')
click('2. Hat 456  |  Remove')
assert(find(gui(),'TextButton','1. Hat 123  |  Remove') and find(gui(),'TextButton','2. Hat 789  |  Remove'),'Individual removal preserves other hats')
click('Add accessories');assert(calls.equip==3,'Empty input does not equip')
click('Remove current Roblox accessories');assert(calls.current==1,'Original accessory button reaches backend')
click('CLOTHES')
field('Classic shirt catalog link or ID').Text='https://www.roblox.com/catalog/123/Classic-Shirt';click('Equip shirt')
field('Classic pants catalog link or ID').Text='456';click('Equip pants')
assert(calls.shirt:find('/123/',1,true) and calls.pants=='456','Separate classic shirt and pants equip actions')
click('Restore original shirt');click('Restore original pants')
assert(calls.shirtRestore and calls.pantsRestore and calls.restore==0,'Clothing restores do not reset other cosmetics')
local replayCount=calls.clothesReplay;calls.failReplay=true;click('Reapply saved cosmetics');calls.failReplay=false
assert(calls.clothesReplay==replayCount+1,'A failed saved avatar does not block clothes replay')
click('SKIN');click('Roblox colors  >')
click('Restore original skin');assert(calls.skinRestore and calls.restore==0,'Skin-only restore does not restore all cosmetics')
local swatches={}
for _,o in ipairs(objects)do if not o.destroyed and o.Name:match('^Color_') then swatches[#swatches+1]=o end end
assert(#swatches==30,'Reference palette contains all 30 colors')
assert(swatches[1].Name=='Color_5A4C42' and swatches[30].Name=='Color_F8F8F8','Reference palette keeps the image order')
assert(swatches[5].BackgroundColor3.R==234 and swatches[5].BackgroundColor3.G==184 and swatches[5].BackgroundColor3.B==146,'Selected screenshot swatch uses exact RGB')
swatches[19].Activated:Fire();assert(calls.skin==1 and calls.color.B==255 and calls.region=='All','Skin palette action')
field('Red 0–255').Text='999';click('Apply RGB color');assert(calls.skin==1,'Invalid RGB never reaches avatar')
click('BODY');click('Girl');assert(calls.body==1 and calls.package=='Girl','Body preset action')
field('roblox.com/bundles/123/... or bundle ID').Text='https://www.roblox.com/bundles/311/Robloxian-2-0'
click('Apply body package');assert(calls.body==2 and calls.package:find('/311/',1,true),'Custom body bundle action')
click('EMOTES');click('Slot 3: Original / unassigned')
field('Roblox emote catalog link or ID').Text='12345';click('Assign to slot 3')
assert(calls.emoteSlot==3 and slots[3].id=='12345','Emote assigned to selected wheel slot')
click('Preview slot 3');assert(calls.preview==3,'Selected emote preview')
click('Open Roblox emote wheel');assert(calls.wheel,'Native wheel action')
click('Reset slot 3');assert(not slots[3],'Slot reset')
click('ANIMATIONS');field('roblox.com/bundles/123/... (animation bundle)').Text='https://www.roblox.com/bundles/82/Robot'
click('Equip animation bundle')
assert(calls.animationBundle=='https://www.roblox.com/bundles/82/Robot','Animation bundle Equip action')
assert(not find(gui(),'TextButton','Play animation') and not find(gui(),'TextButton','Loop: ON'),'Standalone playback UI removed')
click('Restore original animations');assert(calls.animationRestore,'Animation restore action')
click('Restore original appearance');assert(calls.restore==1 and calls.motionRestore and calls.clothesRestore,'Restore all editors')
local old=gui();click('Refresh');assert(old.destroyed and calls.destroy==1 and gui()~=old,'Refresh cleans the old avatar editor')
assert(calls.motionDestroy,'Refresh cleans motion editor')
assert(calls.animationDestroy,'Refresh cleans animation bundle editor')
assert(calls.storageLoaded and calls.storageDestroyed,'Persistent settings load and flush on Refresh')
assert(calls.clothesDestroy,'Refresh cleans clothing editor')
gui():Destroy()
for _,c in ipairs(input.InputBegan.listeners)do assert(not c.Connected,'Input listeners disconnected')end
print('Cosmetic tabs, accessory/body actions, color validation, separate repo, Refresh and cleanup passed.')
