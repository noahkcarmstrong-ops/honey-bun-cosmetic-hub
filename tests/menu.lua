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
    local o=setmetatable({props={ClassName=class,Name=class,Parent=parent,Visible=true,Activated=signal(),FocusLost=signal(),Focused=signal(),MouseEnter=signal(),MouseLeave=signal(),MouseButton1Down=signal(),MouseButton1Up=signal(),Destroying=signal()}},meta)
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
ColorSequence={new=function(...)return{...}end}
TweenInfo={new=function(...)return{...}end}
local function enum()return setmetatable({},{__index=function(t,k)local v=enum();rawset(t,k,v);return v end})end
Enum=enum();DateTime={now=function()return{UnixTimestampMillis=123}end};task={spawn=function(fn)fn()end,delay=function(_,fn)fn()end}
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
local tweenService={Create=function(_,object,_,goal)
    local tween={Completed=signal(),Cancel=function(self)self.cancelled=true end,Play=function(self)
        if self.cancelled then return end
        for key,value in pairs(goal)do object[key]=value end
        self.Completed:Fire(Enum.PlaybackState.Completed)
    end}
    return tween
end}
game={GetService=function(_,name)return({Players={LocalPlayer=player},UserInputService=input,HttpService=http,TweenService=tweenService})[name]end}
function game:HttpGet(url)
    assert(url:find('/honey-bun-cosmetic-hub/',1,true),'Only the separate cosmetic repo is contacted')
    if url:find('/commits/main',1,true)then return'revision'end
    assert(url:find('/'..string.rep('a',40)..'/',1,true),'Modules and Refresh use immutable commits')
    if url:find('/native_inventory.lua',1,true)then return'native-mm2-module'end
    if url:find('/accessory_sounds.lua',1,true)then return'accessory-sounds-module'end
    if url:find('/gun_library.lua',1,true)then return'gun-library-module'end
    if url:find('/effect_library.lua',1,true)then return'effect-library-module'end
    if url:find('/mm2_effects.lua',1,true)then return'mm2-effects-module'end
    if url:find('/mm2.lua',1,true)then return'mm2-module'end
    if url:find('/avatar.lua',1,true)then return'editor-module'end
    if url:find('/motion.lua',1,true)then return'motion-module'end
    if url:find('/animations.lua',1,true)then return'animations-module'end
    if url:find('/storage.lua',1,true)then return'storage-module'end
    if url:find('/clothes.lua',1,true)then return'clothes-module'end
    if url:find('/characters.lua',1,true)then return'characters-module'end
    if url:find('/atmosphere.lua',1,true)then return'atmosphere-module'end
    if url:find('/previews.lua',1,true)then return'previews-module'end
    if url:find('/loader.lua',1,true)then return'loader'end
    error('Unexpected request '..url)
end
loadstring=function(source)
    if source=='native-mm2-module'then return function()return function(_gui,_catalog,_status,mode)local key=(mode=='effects' or mode=='saved-effects') and 'nativeEffectsEnabled' or mode=='saved' and 'savedNativeEnabled' or 'nativeEnabled';return{refreshSaved=function()calls.savedInventoryRefreshed=true end,enable=function()if calls.nativeFail and mode~='saved' and mode~='saved-effects' then return false,'Open MM2 inventory first' end;calls[key]=true;return'Enabled'end,disable=function()calls[key]=false end,destroy=function()calls[key]=false;calls.nativeDestroyed=true end,report=function()return'Native fixture report'end}end end end
    if source=='accessory-sounds-module'then return function()return function(_player,_gui)local enabled=_gui:GetAttribute('HoneyBunCosmeticUI_HatSounds')~=false;return{isEnabled=function()return enabled end,setEnabled=function(v)enabled=v;_gui:SetAttribute('HoneyBunCosmeticUI_HatSounds',v);calls.hatSounds=v;return'Sound toggle'end,playNow=function()calls.playHatSounds=true;return'Played'end,destroy=function()calls.hatSoundsDestroyed=true end}end end end
    if source=='gun-library-module'then return function()return function(_game,store)assert(store==guiRoot,'Weapon library uses persistent PlayerGui');return{}end end end
    if source=='effect-library-module'then return function()return function(_game,store)assert(store==guiRoot,'Effect library uses persistent PlayerGui');return{list=function()return{{id='Effect1',name='Effect from PlayerOne'}}end,capturePlayer=function(name)calls.capturePlayer=name;return'Captured player',{'Effect1'}end,captureServer=function(name)calls.capturePriority=name;return'Captured server'end,report=function()return'Library fixture'end,destroy=function()calls.libraryDestroyed=true end}end end end
    if source=='mm2-effects-module'then return function()return function(_game,_status)calls.effectLoads=(calls.effectLoads or 0)+1;return{equip=function(id)calls.savedEffect=id;return'Equipped effect'end,getEquipped=function()return{}end,reloadLibrary=function()calls.libraryReloaded=true end,collectOriginals=function()calls.effectsCollecting=true end,restore=function()calls.effectsRestored=true end,destroy=function()calls.effectsDestroyed=true end,report=function()return'Effects fixture report'end}end end end
    if source=='mm2-module'then return function()return function()calls.weaponLoads=(calls.weaponLoads or 0)+1;return{setKnifeSide=function(value)calls.knifeSide=value;return value end,savedInventory=function(kind)return{{id=kind..'1',name=kind..' from PlayerOne',kind=kind}}end,savedWeapons=function(kind)return{{id=kind..'1',name=kind..' from PlayerOne',kind=kind}}end,equip=function(id,kind)calls.savedWeapon=id;calls.savedKind=kind;return'Equipped'end,collectPlayerWeapon=function(name,kind)calls.captureOwner=name;calls.captureKind=kind;if calls.failGun and kind=='Gun' then error('Gun not loaded')end;return'Copied '..kind end,report=function()return'MM2 fixture report'end,list=function(category,search)calls.mm2Category=category;calls.mm2Search=search;return{{id='ChromaFixture',name='Chroma fixture',kind=category}}end,preview=function(id,category)calls.mm2Preview=id;return'Previewed'end,restore=function()calls.mm2Restored=true;return'Restored'end,destroy=function()calls.mm2Destroyed=true end}end end end
    if source=='atmosphere-module'then return function()return function()return{daylightEnabled=function()return calls.daylight~=false end,setDaylight=function(v)calls.daylight=v;return'Time updated'end,apply=function(id)calls.skybox=id;return true end,restore=function()calls.skyRestored=true;return'Sky restored'end,destroy=function()calls.skyDestroyed=true end}end end end
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
local function findName(root,name)
    if root.Name==name then return root end
    for _,child in ipairs(root:GetChildren())do local found=findName(child,name);if found then return found end end
end
local header=assert(findName(gui(),'ClassicTitleBar'),'Classic title bar is present')
assert(header.BackgroundColor3.R==0 and header.BackgroundColor3.G==112 and header.BackgroundColor3.B==192,'Classic title bar uses Roblox blue')
local panel=header.Parent
local hideButton=assert(find(gui(),'TextButton','−'),'Hide button is present')
hideButton.Activated:Fire();assert(panel.Visible==false and panel.GroupTransparency==1,'Hide animation fades the whole menu before hiding it')
input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift});assert(panel.Visible==true and panel.GroupTransparency==0,'Right Shift restores the whole menu after fading out')
assert(panel:FindFirstChild('UIScale').Scale==1,'Opening restores the menu scale')
local addButton=assert(find(gui(),'TextButton','Add accessories'),'Animated action button is present')
local baseColor=addButton.BackgroundColor3
addButton.MouseEnter:Fire()
assert(addButton.BackgroundColor3.R==207 and addButton.BackgroundColor3.G==224 and addButton.BackgroundColor3.B==240,'Button hover uses the pale classic highlight')
addButton.MouseLeave:Fire()
assert(addButton.BackgroundColor3==baseColor,'Button leave restores its base color')
local addScale=assert(addButton:FindFirstChild('UIScale'),'Animated button has a press scale')
addButton.MouseButton1Down:Fire();assert(addScale.Scale==0.98,'Button press scales down')
addButton.MouseButton1Up:Fire();assert(addScale.Scale==1,'Button release restores scale')
local accessoriesTab=assert(findName(gui(),'Accessories'),'Accessories tab exists')
accessoriesTab.MouseEnter:Fire();assert(accessoriesTab.BackgroundColor3.R==0 and accessoriesTab.BackgroundColor3.G==133,'Selected tab hover stays blue')
accessoriesTab.MouseLeave:Fire();assert(accessoriesTab.BackgroundColor3.R==0 and accessoriesTab.BackgroundColor3.G==112,'Selected tab leave stays blue')
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
local clothesTab=assert(findName(gui(),'Clothes'),'Clothes tab exists')
assert(clothesTab.BackgroundColor3.R==0 and clothesTab.BackgroundColor3.G==112,'Selected tab turns blue after page switch')
clothesTab.MouseEnter:Fire();assert(clothesTab.BackgroundColor3.R==0 and clothesTab.BackgroundColor3.G==133,'Selected tab hover remains blue after page switch')
clothesTab.MouseLeave:Fire();assert(clothesTab.BackgroundColor3.R==0 and clothesTab.BackgroundColor3.G==112,'Selected tab leave remains blue after page switch')
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
local owner=field("Player's Roblox username")
owner.Text='  PlayerOne  '
click("Save and equip player's gun")
assert(calls.captureOwner=='PlayerOne' and calls.captureKind=='Gun' and not calls.nativeEnabled,'Gun is copied without Show all weapons')
assert(guiRoot:GetAttribute('HoneyBunCosmeticUI_copyPlayer')=='PlayerOne','Username is saved')
assert(calls.knifeSide==false,'Saved knife layout defaults to the back')
click('Boombox layout: OFF')
assert(calls.knifeSide==true and guiRoot:GetAttribute('HoneyBunCosmeticUI_mm2KnifeSide')==true,'Boombox toggle moves knives to the side and saves the setting')
click('Boombox layout: ON');assert(calls.knifeSide==false,'Boombox toggle returns knives to the back')
click("Save and equip player's knife")
assert(calls.captureKind=='Knife','Knife uses the same entered username')
click("Save and equip player's effect")
assert(calls.capturePlayer=='PlayerOne' and calls.libraryReloaded and calls.savedEffect=='Effect1' and calls.nativeEffectsEnabled,'Saving effects automatically adds native inventory cards')
click('Refresh saved weapons in MM2 inventory')
assert(calls.savedNativeEnabled and calls.savedInventoryRefreshed and not calls.nativeEnabled,'Saved models appear in native inventory without all-weapons overlay')
assert(not find(gui(),'TextButton','Equip Gun from PlayerOne') and not find(gui(),'TextButton','Equip Knife from PlayerOne'),'Saved weapon equip buttons are removed from hub')
assert(not find(gui(),'TextButton','Equip Effect from PlayerOne') and not find(gui(),'TextButton','Remove knife effect'),'Duplicate saved effect controls are removed from the hub')
calls.failGun=true;calls.capturePlayer=nil
click('Save all three');calls.failGun=false
assert(calls.captureKind=='Knife' and calls.capturePlayer=='PlayerOne','Missing gun does not prevent saving knife and effect')
calls.nativeFail=true;click('Show all weapons: OFF');calls.nativeFail=false
assert(find(gui(),'TextButton','Show all weapons: OFF'),'Detection failure leaves toggle off')
click('Show all weapons: OFF')
assert(calls.nativeEnabled and find(gui(),'TextButton','Show all weapons: ON'),'Optional inventory overlay toggles on')
assert(calls.savedNativeEnabled,'Saved Weapons remains available with the full catalog enabled')
click('Show all weapons: ON');assert(not calls.nativeEnabled and not calls.mm2Restored,'Hiding optional inventory does not clear saved weapon appearance')
assert(calls.savedNativeEnabled,'Disabling full overlay restores saved native cards')
click('Refresh saved effects in MM2 inventory');assert(calls.nativeEffectsEnabled and calls.effectsCollecting,'Saved effects inventory refreshes without a toggle')
click('Collect server effects');assert(calls.capturePriority=='PlayerOne','Server capture prioritizes entered username')
assert(not calls.effectsRestored and calls.nativeEffectsEnabled,'Saved effects stay visible and equipped')
click('Remove saved weapon appearances');assert(calls.mm2Restored,'Explicit remove clears only equipped weapon appearances')
click('Back');assert(find(gui(),'TextButton','Open MM2 menu'),'Back returns to the MM2 entry')
click('ATMOSPHERE')
assert(findName(gui(),'Atmosphere').LayoutOrder==findName(gui(),'Characters').LayoutOrder+1,'Atmosphere tab follows Characters in all games')
field('Roblox skybox model link or ID').Text='12345';click('Apply skybox')
assert(calls.skybox=='12345','Skybox field routes the requested ID to its own module')
click('Daylight: ON');assert(calls.daylight==false,'Daylight can restore game time')
click('Daylight: OFF');assert(calls.daylight==true,'Daylight can be enabled again')
click('Restore original sky');assert(calls.skyRestored,'Atmosphere restores the original sky')
field('Skybox name').Text='Classic sky';click('Save skybox')
assert(find(gui(),'TextButton','Load Classic sky'),'Saved skybox gets a load button')
field('Skybox name').Text='Classic renamed';click('Save skybox')
assert(not find(gui(),'TextButton','Load Classic sky'),'Saving the same asset updates instead of duplicating')
click('Daylight: ON');click('Load Classic renamed')
assert(calls.skybox=='12345' and calls.daylight==true,'Load reapplies the saved asset and daylight preference')
click('Refresh');click('ATMOSPHERE')
assert(find(gui(),'TextButton','Load Classic renamed'),'Skybox library survives Refresh')
click('Delete Classic renamed')
assert(not find(gui(),'TextButton','Load Classic renamed'),'Delete removes the saved skybox')

click('ACCESSORIES');assert(find(gui(),'TextButton','Add accessories'),'Cosmetic tabs remain usable')
click('Hat sounds: ON');assert(calls.hatSounds==false,'Hat sound toggle updates persisted preference')
click('Hat sounds: OFF');click('Play hat sounds now');assert(calls.hatSounds==true and calls.playHatSounds,'Hat sound controls enable and play local audio')
gui():SetAttribute('HoneyBunCosmeticGuns','legacy-weapons')
gui():SetAttribute('HoneyBunCosmeticEffects','legacy-effects')
guiRoot:SetAttribute('HoneyBunCosmeticUI_mm2KnifeSide',true)
local weaponLoads,effectLoads=calls.weaponLoads,calls.effectLoads
game.GameId=0;game.PlaceId=142823291
dofile('loader.lua');
assert(guiRoot:GetAttribute('HoneyBunCosmeticGuns')=='legacy-weapons' and guiRoot:GetAttribute('HoneyBunCosmeticEffects')=='legacy-effects','Refresh migrates old temporary collections to persistent PlayerGui')
assert(calls.weaponLoads==weaponLoads+1 and calls.effectLoads==effectLoads+1,'Saved collections load automatically when script runs in MM2')
assert(calls.knifeSide==true,'Saved boombox layout reapplies when the hub reloads')
assert(find(gui(),'TextButton','MM2'),'MM2 main place is recognized')
assert(calls.effectsDestroyed and calls.nativeEffectsEnabled and calls.savedNativeEnabled,'Refresh cleans up old displays and automatically restores saved collections')
assert(calls.hatSoundsDestroyed,'Refreshing the hub also cleans up accessory sound playback')
game.PlaceId=0
dofile('loader.lua');assert(not find(gui(),'TextButton','MM2'),'MM2 entry is absent outside MM2')
gui():Destroy()
for _,c in ipairs(input.InputBegan.listeners)do assert(not c.Connected,'Input listeners disconnected')end
assert(calls.skyDestroyed,'Skybox module restores its changes on menu cleanup')
print('Cosmetic tabs, accessory/body actions, color validation, separate repo, Refresh and cleanup passed.')
