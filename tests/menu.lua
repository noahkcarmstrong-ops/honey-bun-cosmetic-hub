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
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)
    t.props[k]=v
    if t.props.propertySignals and t.props.propertySignals[k] then t.props.propertySignals[k]:Fire() end
end}
Instance={new=function(class,parent)
    local o=setmetatable({props={ClassName=class,Name=class,Parent=parent,Visible=true,Activated=signal(),FocusLost=signal(),Destroying=signal()}},meta)
    objects[#objects+1]=o;return o
end}
function methods:GetChildren()local list={};for _,o in ipairs(objects)do if o.Parent==self then list[#list+1]=o end end;return list end
function methods:FindFirstChild(name)for _,o in ipairs(self:GetChildren())do if o.Name==name then return o end end end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name))end
function methods:GetAttribute(key)return self.attributes and self.attributes[key]end
function methods:GetPropertyChangedSignal(key)
    self.propertySignals=self.propertySignals or {}
    self.propertySignals[key]=self.propertySignals[key] or signal()
    return self.propertySignals[key]
end
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
    calls.loadedCharacterSettings=guiRoot:GetAttribute('HoneyBunCosmeticSettings')
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
        accessoryReport=function()return'Fixture accessory report'end,
        setSkin=function(color,region)calls.skin=calls.skin+1;calls.color=color;calls.region=region;return'Color applied'end,
        restoreSkin=function()calls.skinRestore=true;return'Original skin restored'end,
        applyBody=function(value)calls.body=calls.body+1;calls.package=value;return'Body applied'end,
        applyBodyPart=function(region,value)calls.bodyParts=calls.bodyParts or {};calls.bodyParts[region]=value;return'Part equipped'end,
        restoreBody=function()calls.bodyRestore=true;return'Body restored'end,
        restore=function()calls.restore=calls.restore+1;return'Restored'end,
        reapplySaved=function()if calls.failReplay then error('Fixture avatar unavailable')end;return'Saved cosmetics restored.'end,
        getSettings=function()return{accessories={},colors={}}end,
        destroy=function()calls.destroy=calls.destroy+1 end,
    }
end
local documents,nextDocument={},0
local http={JSONEncode=function(_,value)
    nextDocument=nextDocument+1;local token='document-'..nextDocument;documents[token]=value;return token
end,JSONDecode=function(_,raw)
    if raw=='revision' then return{sha=string.rep('a',40)}end
    return assert(documents[raw],'Invalid fixture JSON')
end}
game={GetService=function(_,name)return({Players={LocalPlayer=player},UserInputService=input,HttpService=http})[name]end}
function game:HttpGet(url)
    assert(url:find('/honey-bun-cosmetic-hub/',1,true),'Only the separate cosmetic repo is contacted')
    if url:find('/commits/main',1,true)then return'revision'end
    assert(url:find('/'..string.rep('a',40)..'/',1,true),'Modules and Refresh use immutable commits')
    if url:find('/native_inventory.lua',1,true)then return'native-mm2-module'end
    if url:find('/mm2_effects.lua',1,true)then return'mm2-effects-module'end
    if url:find('/mm2.lua',1,true)then return'mm2-module'end
    if url:find('/avatar.lua',1,true)then return'editor-module'end
    if url:find('/motion.lua',1,true)then return'motion-module'end
    if url:find('/animations.lua',1,true)then return'animations-module'end
    if url:find('/storage.lua',1,true)then return'storage-module'end
    if url:find('/clothes.lua',1,true)then return'clothes-module'end
    if url:find('/characters.lua',1,true)then return'characters-module'end
    if url:find('/previews.lua',1,true)then return'previews-module'end
    if url:find('/loader.lua',1,true)then return'loader'end
    error('Unexpected request '..url)
end
loadstring=function(source)
    if source=='native-mm2-module'then return function()return function(_gui,_catalog,_status,mode)local key=mode=='effects' and 'nativeEffectsEnabled' or 'nativeEnabled';return{enable=function()if calls.nativeFail then return false,'Open MM2 inventory first' end;calls[key]=true;return'Enabled'end,disable=function()calls[key]=false end,destroy=function()calls[key]=false;calls.nativeDestroyed=true end,report=function()return'Native fixture report'end}end end end
    if source=='mm2-effects-module'then return function()return function()return{restore=function()calls.effectsRestored=true end,destroy=function()calls.effectsDestroyed=true end,report=function()return'Effects fixture report'end}end end end
    if source=='mm2-module'then return function()return function()return{report=function()return'MM2 fixture report'end,list=function(category,search)calls.mm2Category=category;calls.mm2Search=search;return{{id='ChromaFixture',name='Chroma fixture',kind=category}}end,preview=function(id,category)calls.mm2Preview=id;return'Previewed'end,restore=function()calls.mm2Restored=true;return'Restored'end,destroy=function()calls.mm2Destroyed=true end}end end end
    if source=='editor-module'then return function()return createEditor end end
    if source=='motion-module'then return function()return createMotion end end
    if source=='animations-module'then return function()return createAnimations end end
    if source=='clothes-module'then return function()return createClothes end end
    if source=='characters-module'then return function()return dofile('characters.lua')end end
    if source=='previews-module'then return function()return function()return{
        capture=function()return{version=1,parts={}}end,
        show=function(viewport,data)calls.characterPreview=data;assert(viewport.ClassName=='ViewportFrame')end,
    }end end end
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
setclipboard=function(value)calls.accessoryReport=value end
click('Copy accessory report');assert(calls.accessoryReport=='Fixture accessory report','Accessory report is copied for live troubleshooting')
setclipboard=nil
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
click('Custom body parts  >')
field('Head catalog or bundle link / asset ID').Text='https://www.roblox.com/catalog/123/Head';click('Equip head')
field('Left arm catalog or bundle link / asset ID').Text='https://www.roblox.com/bundles/311/Robloxian-2-0';click('Equip left arm')
assert(calls.bodyParts.Head:find('/123/',1,true) and calls.bodyParts.LeftArm:find('/311/',1,true),'Head and limb inputs reach independent body region actions')
click('Restore original body');assert(calls.bodyRestore and calls.restore==0,'Body-only restore preserves other cosmetics')
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
click('BODY')
assert(field('Head catalog or bundle link / asset ID').Text=='https://www.roblox.com/catalog/123/Head','Custom part editor links survive Refresh')
local function named(root,name)
    if root.Name==name then return root end
    for _,child in ipairs(root:GetChildren())do local found=named(child,name);if found then return found end end
end
local function clickNamed(name)assert(named(gui(),name),'Missing button '..name).Activated:Fire()end
local function cog()clickNamed('CharacterOptions_1')end
local function tile()clickNamed('EquipCharacter_1')end

guiRoot:SetAttribute('HoneyBunCosmeticSettings','saved-cat-look')
guiRoot:SetAttribute('HoneyBunCosmeticClothes','saved-shirt')
guiRoot:SetAttribute('HoneyBunCosmeticAnimationBundle',82)
click('CHARACTERS')
assert(named(gui(),'CharacterGrid'),'Characters uses a thumbnail grid')
assert(not find(gui(),'TextButton','Equip') and not find(gui(),'TextButton','Delete'),'No equip/delete buttons beneath previews')
click('Create New Character');click('Create')
assert(not named(gui(),'CharacterCard_1'),'Blank name cannot create a character')
field('Character name').Text='Cat outfit';click('Create')
assert(named(gui(),'CharacterCard_1') and calls.characterPreview,'Created character includes preview')
local grid=named(gui(),'CharacterGrid')
grid.AbsoluteSize={X=940,Y=300}
assert(grid:FindFirstChild('UIGridLayout').FillDirectionMaxCells==7,'Wide layout fits reference-sized square cards')
grid.AbsoluteSize={X=300,Y=300}
assert(grid:FindFirstChild('UIGridLayout').FillDirectionMaxCells==2,'Narrow layout keeps cards in two columns')
field('Search by name...').Text='missing'
assert(not named(gui(),'CharacterCard_1').Visible,'Search hides unmatched characters live')
field('Search by name...').Text='CAT'
assert(named(gui(),'CharacterCard_1').Visible,'Search matches names without case sensitivity')
field('Search by name...').Text=''
cog();assert(find(gui(),'TextButton','Update') and find(gui(),'TextButton','Rename') and find(gui(),'TextButton','Delete') and find(gui(),'TextButton','Cancel'),'Cog shows all four Roblox menu labels')
cog();assert(not named(gui(),'CharacterMenu_1'),'Cog closes an open menu')
guiRoot:SetAttribute('HoneyBunCosmeticSettings','different-look')
guiRoot:SetAttribute('HoneyBunCosmeticEmotes','different-wheel')
guiRoot:SetAttribute('HoneyBunCosmeticAnimationBundle',99)
tile()
assert(calls.loadedCharacterSettings=='saved-cat-look','Clicking thumbnail equips the saved look')
assert(guiRoot:GetAttribute('HoneyBunCosmeticClothes')=='saved-shirt' and guiRoot:GetAttribute('HoneyBunCosmeticAnimationBundle')==82,'Equip restores all saved categories')
assert(guiRoot:GetAttribute('HoneyBunCosmeticEmotes')==nil,'Equip clears categories absent from the saved character')
cog();click('Rename');field('Character name').Text='Pumpkin dude';click('Save Name')
assert(find(gui(),'TextLabel','Pumpkin dude'),'Renamed character label appears beneath the preview')
guiRoot:SetAttribute('HoneyBunCosmeticSettings','updated-cat-look')
cog();click('Update');guiRoot:SetAttribute('HoneyBunCosmeticSettings','other-look');tile()
assert(calls.loadedCharacterSettings=='updated-cat-look','Update stores current look without creating a duplicate')
guiRoot:SetAttribute('HoneyBunCosmeticSettings','previous-look')
calls.failReplay=true;tile();calls.failReplay=false
assert(guiRoot:GetAttribute('HoneyBunCosmeticSettings')=='previous-look','Failed equip restores previous selections')
tile()
cog();click('Delete');assert(find(gui(),'TextButton','Confirm delete'),'Delete asks for confirmation')
click('Cancel');assert(named(gui(),'CharacterCard_1'),'Cancelled deletion keeps character')
click('Refresh')
assert(find(gui(),'TextLabel','Pumpkin dude'),'Renamed and updated character survives Refresh')
cog();click('Delete');click('Confirm delete')
assert(not named(gui(),'CharacterCard_1'),'Confirmed deletion removes the card')
assert(guiRoot:GetAttribute('HoneyBunCosmeticSettings')=='updated-cat-look','Deleting character leaves equipped look on')
assert(not find(gui(),'TextButton','MM2'),'Other games do not show the MM2 entry')
game.GameId=66654135
dofile('loader.lua')
click('MM2');click('Open MM2 menu')
assert(find(gui(),'TextLabel','MM2 MENU'),'MM2 entry opens its own menu')
setclipboard=function(value)calls.clipboard=value end
click('Copy MM2 report');setclipboard=nil;assert(calls.clipboard=='MM2 fixture report\nNative fixture report','MM2 discovery report is copied')
assert(not find(gui(),'TextButton','Restore original appearance'),'MM2 menu contains no cosmetic actions')
calls.nativeFail=true;click('Show all weapons: OFF');calls.nativeFail=false
assert(find(gui(),'TextButton','Show all weapons: OFF'),'Detection failure leaves toggle off')
click('Show all weapons: OFF')
assert(calls.nativeEnabled and find(gui(),'TextButton','Show all weapons: ON'),'Native inventory overlay toggles on')
assert(not find(gui(),'TextBox','Search MM2 cosmetics'),'Separate catalog is removed from the hub')
click('Show all weapons: ON');assert(not calls.nativeEnabled and calls.mm2Restored,'Disable restores native inventory and previews')
click('Show all weapons: OFF')
click('Show all effects: OFF');assert(calls.nativeEffectsEnabled and calls.nativeEnabled and find(gui(),'TextButton','Show all effects: ON'),'Separate effects toggle enables alongside weapons')
click('Show all effects: ON');assert(calls.effectsRestored and not calls.nativeEffectsEnabled and calls.nativeEnabled and find(gui(),'TextButton','Show all effects: OFF'),'Effects disable restores only local effects and keeps weapons enabled')
click('Back');assert(find(gui(),'TextButton','Open MM2 menu'),'Back returns to the MM2 entry')
click('ACCESSORIES');assert(find(gui(),'TextButton','Add accessories'),'Cosmetic tabs remain usable')
game.GameId=0;game.PlaceId=142823291
dofile('loader.lua');assert(find(gui(),'TextButton','MM2'),'MM2 main place is recognized')
assert(calls.effectsDestroyed and not calls.nativeEffectsEnabled,'Refreshing the hub destroys effects and their inventory overlay')
game.PlaceId=0
dofile('loader.lua');assert(not find(gui(),'TextButton','MM2'),'MM2 entry is absent outside MM2')
gui():Destroy()
for _,c in ipairs(input.InputBegan.listeners)do assert(not c.Connected,'Input listeners disconnected')end
print('Cosmetic tabs, accessory/body actions, color validation, separate repo, Refresh and cleanup passed.')
