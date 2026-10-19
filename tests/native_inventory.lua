local create=dofile('native_inventory.lua')
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={fn=fn,live=true};function c:Disconnect() self.live=false end
        self.listeners[#self.listeners+1]=c;return c
    end
    function s:Fire(...) for _,c in ipairs(self.listeners) do if c.live then c.fn(...) end end end
    return s
end
local methods={}
local guiClasses={Frame=true,ScrollingFrame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,TextBox=true}
local function ancestors(o,signalName,value)
    while o do o[signalName]:Fire(value);o=o.Parent end
end
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)
    if k=='Parent' then
        local old=t.props.Parent
        if old==v then return end
        if old then
            ancestors(old,'DescendantRemoving',t)
            for _,desc in ipairs(t:GetDescendants())do ancestors(old,'DescendantRemoving',desc)end
            for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i);break end end
        end
        t.props.Parent=v
        if v then
            v.children[#v.children+1]=t;v.ChildAdded:Fire(t)
            ancestors(v,'DescendantAdded',t)
            for _,desc in ipairs(t:GetDescendants())do ancestors(v,'DescendantAdded',desc)end
        end
    else
        local old=t.props[k];t.props[k]=v
        if old~=v and t.props.propertySignals and t.props.propertySignals[k]then t.props.propertySignals[k]:Fire()end
    end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,Visible=true,Active=true,Text='',PlaceholderText='',ZIndex=1,Size='card-size',AbsoluteSize={X=100,Y=100},Activated=signal(),ChildAdded=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),changed=signal()},children={}},meta)
    n.Parent=parent;return n
end
function methods:IsA(class)
    return self.ClassName==class or (class=='GuiObject' and guiClasses[self.ClassName]) or (class=='GuiButton' and (self.ClassName=='TextButton' or self.ClassName=='ImageButton')) or (class=='LuaSourceContainer' and (self.ClassName=='LocalScript' or self.ClassName=='Script' or self.ClassName=='ModuleScript')) or false
end
function methods:GetChildren()local out={};for _,c in ipairs(self.children)do out[#out+1]=c end;return out end
function methods:GetDescendants()local out={};local function walk(p)for _,c in ipairs(p.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end
function methods:FindFirstChildOfClass(class)for _,c in ipairs(self.children)do if c:IsA(class)then return c end end end
function methods:GetFullName()return (self.Parent and self.Parent:GetFullName()..'.' or '')..self.Name end
function methods:GetPropertyChangedSignal(key)
    self.propertySignals=self.propertySignals or {};self.propertySignals[key]=self.propertySignals[key]or signal();return self.propertySignals[key]
end
function methods:FindFirstChild(name)for _,c in ipairs(self.children)do if c.Name==name then return c end end end
function methods:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil;self.destroyed=true end
function methods:Clone()
    local n=node(self.ClassName,self.Name)
    for k,v in pairs(self.props)do if k~='Parent' and k~='Activated' and k~='ChildAdded' and k~='changed' and k~='DescendantAdded' and k~='DescendantRemoving' and k~='propertySignals'then n[k]=v end end
    for _,c in ipairs(self.children)do c:Clone().Parent=n end
    return n
end
Instance={new=function(class)return node(class)end}
UDim2={fromScale=function(x,y)return{x=x,y=y}end,fromOffset=function(x,y)return{x=x,y=y}end}
Enum={SortOrder={LayoutOrder='LayoutOrder'},AutomaticSize={Y='AutoY'}}
task={queue={},defer=function(fn)table.insert(task.queue,fn)end}
local function flush()
    local turns=0
    while #task.queue>0 do
        turns=turns+1;assert(turns<30,'Lifecycle watchers must not schedule endless self-renders')
        local queue=task.queue;task.queue={};for _,fn in ipairs(queue)do fn()end
    end
end
local playerGui=node('PlayerGui','PlayerGui')
local function nativeInventory()
    local inventory=node('Frame','Inventory',playerGui)
    local host=node('Frame','WeaponPages',inventory)
    local seasonPane=node('ScrollingFrame','Season1',host)
    local classicPane=node('ScrollingFrame','Classic',host);classicPane.Visible=false
    local holidayPane=node('ScrollingFrame','Holiday',host);holidayPane.Visible=false
    seasonPane.CanvasSize='original-canvas';seasonPane.AutomaticCanvasSize='None'
    local layout=node('UIGridLayout','Layout',seasonPane)
    local function card(name,label)
        local c=node('Frame',name,seasonPane)
        local text=node('TextLabel','ItemName',c);text.Text=label
        local image=node('ImageLabel','Icon',c);image.Image='original-icon'
        node('TextButton','NativeEquip',c)
        local selected=node('TextLabel','Equipped',c);selected.Visible=false
        node('LocalScript','NativeScript',c)
        return c
    end
    local knife=card('Knife','Default Knife')
    local gun=card('Gun','Default Gun');gun.Visible=false
    local equipped=node('Frame','Equipped',inventory)
    local knifeSlot=node('Frame','Knife',equipped);local knifeIcon=node('ImageLabel','Icon',knifeSlot);knifeIcon.Image='side-knife';local knifeName=node('TextLabel','ItemName',knifeSlot);knifeName.Text='Default Knife';local knifeRarity=node('TextLabel','Rarity',knifeSlot);knifeRarity.Text='Native Knife'
    local gunSlot=node('Frame','Gun',equipped);local gunIcon=node('ImageLabel','Icon',gunSlot);gunIcon.Image='side-gun';local gunName=node('TextLabel','ItemName',gunSlot);gunName.Text='Default Gun';local gunRarity=node('TextLabel','Rarity',gunSlot);gunRarity.Text='Native Gun'
    local search=node('TextBox','Search',inventory)
    local buttons={}
    for _,name in ipairs({'Season 1','Classic','Holiday'})do
        local holder=node('Frame',name,inventory)
        local button=node('ImageButton','Button',holder)
        local title=node('TextLabel','Title',holder);title.Text=name
        buttons[name]=button
        button.Activated:Connect(function()
            seasonPane.Visible=name=='Season 1';classicPane.Visible=name=='Classic';holidayPane.Visible=name=='Holiday'
        end)
    end
    return inventory,host,seasonPane,classicPane,holidayPane,knife,gun,search,buttons,layout,equipped
end
-- Equipped defaults can appear before the actual collection in the live GUI.
local decoy=node('Frame','InventoryLoadout',playerGui)
local decoySlots=node('Frame','Equipped',decoy)
for _,kind in ipairs({'Knife','Gun'})do
    local column=node('Frame',kind,decoySlots)
    node('TextLabel','ItemName',column).Text='Default '..kind
    node('ImageLabel','Icon',column)
    node('Frame','CraftingStation',column)
end
local inventory,host,seasonPane,classicPane,holidayPane,knife,gun,search,buttons,layout,equipped=nativeInventory()
local chosen={}
local lastEquip
local definitions={
    {id='rare',kind='Knife',name='Rare Knife',image=123,category='season1',rarity='Rare'},
    {id='godly',kind='Gun',name='Godly Gun',image=234,category='season1',rarity='Godly'},
    {id='classic',kind='Knife',name='Classic Knife',image=345,category='classic',rarity='Common'},
    {id='holiday',kind='Gun',name='Holiday Gun',image=456,category='holiday',rarity='Godly'},
}
local catalog={list=function(kind,q)
    local result={};for _,entry in ipairs(definitions)do
        if entry.kind==kind and (not q or q=='' or entry.name:lower():find(q,1,true))then result[#result+1]=entry end
    end;return result
end,equip=function(id,kind)chosen[kind]=id;lastEquip=id..':'..kind;return'Equipped locally'end,getEquipped=function()return chosen end}
local function collection()
    for _,o in ipairs(host:GetChildren())do if o.Name=='HoneyBunLocal_Collection'then return o end end
end
local function generated()
    local out={};local root=collection();if not root then return out end
    for _,o in ipairs(root:GetDescendants())do if o.Name:find('HoneyBunLocal_',1,true)and o.Name~='HoneyBunLocal_Collection'then out[#out+1]=o end end
    table.sort(out,function(a,b)return a.LayoutOrder<b.LayoutOrder end);return out
end
local function overlay(card)
    for _,o in ipairs(card:GetDescendants())do if o.Name=='HoneyBunPreviewClick'then return o end end
end
local api=create(playerGui,catalog)
local ok,msg=api.enable();assert(ok,msg);flush()
assert(#generated()==2,'Season 1 contains only its catalog items')
assert(generated()[1].Name:find('godly',1,true),'Rarity sorting puts Godly before Rare across weapon types')
assert(not seasonPane.Visible and not classicPane.Visible and not holidayPane.Visible,'Native panels are hidden behind the reusable collection')
assert(knife.Visible and not gun.Visible,'Original native card visibility is never modified')
assert(collection().AutomaticCanvasSize=='AutoY','Owned collection scrolls')
local card=generated()[1]
assert(card:FindFirstChildOfClass('ImageLabel').Image=='rbxassetid://234','Native cards use catalog images')
for _,v in ipairs(card:GetDescendants())do
    assert(not v:IsA('LuaSourceContainer'),'Cloned scripts are stripped')
    if v.Name=='NativeEquip'then assert(not v.Active,'Native remote-driven button is disabled')end
end
local cardsBefore=generated();local firstGenerated,secondGenerated=cardsBefore[1],cardsBefore[2]
overlay(card).Activated:Fire();assert(lastEquip=='godly:Gun','Click equips the selected cosmetic rather than requiring an immediate preview')
assert(generated()[1]==firstGenerated and generated()[2]==secondGenerated,'Click updates existing cards without rebuilding the grid')
assert(generated()[1]:FindFirstChild('Equipped').Visible,'Native equipped marker reflects local selection')
overlay(secondGenerated).Activated:Fire();assert(lastEquip=='rare:Knife','Second click equips the other cosmetic')
assert(generated()[1]==firstGenerated and generated()[2]==secondGenerated,'Second click keeps the existing cards')
assert(generated()[1]:FindFirstChild('Equipped').Visible and generated()[2]:FindFirstChild('Equipped').Visible,'Each weapon category keeps its selection marker without rebuilding')
assert(equipped:FindFirstChild('Knife'):FindFirstChild('ItemName').Text=='Rare Knife','Native Knife side slot shows selected name')
assert(equipped:FindFirstChild('Knife'):FindFirstChild('Icon').Image=='rbxassetid://123','Native Knife side slot shows selected image')
assert(equipped:FindFirstChild('Knife'):FindFirstChild('Rarity').Text=='Rare','Native Knife side slot shows selected rarity')
assert(equipped:FindFirstChild('Gun'):FindFirstChild('ItemName').Text=='Godly Gun','Native Gun side slot keeps its selected name')
buttons.Classic.Activated:Fire();flush()
assert(#generated()==1 and generated()[1].Name:find('classic',1,true),'Classic tab works even when native game changes panels')
assert(collection().Visible and not classicPane.Visible,'Local collection remains visible after native category switch')
buttons.Holiday.Activated:Fire();flush()
assert(#generated()==1 and generated()[1].Name:find('holiday',1,true),'Holiday tab uses its own item category')
search.Text='missing';flush();assert(#generated()==0,'Native search filters the selected category')
search.Text='';flush()
local beforeReopen=generated()[1]
inventory.Visible=false;collection().Visible=false;inventory.Visible=true;flush()
assert(generated()[1]==beforeReopen,'Reopening unchanged inventory must not rebuild hundreds of cards')
assert(#generated()==1 and collection().Visible,'Closing and reopening preserves local cards and selected category')
-- MM2 replaces its entire inventory GUI, not just its visibility.
inventory:Destroy()
inventory,host,seasonPane,classicPane,holidayPane,knife,gun,search,buttons,layout,equipped=nativeInventory()
flush()
assert(collection() and #generated()==1,'A rebuilt native inventory is rebound automatically')
buttons.Classic.Activated:Fire();flush();assert(#generated()==1,'Recreated tab controls are rebound')
api.disable();flush()
assert(not collection() and seasonPane.Visible and not classicPane.Visible and not holidayPane.Visible,'Disable restores exact native panel visibility')
assert(knife.Visible and not gun.Visible and not knife.destroyed,'Native cards remain intact')
assert(seasonPane.CanvasSize=='original-canvas' and seasonPane.AutomaticCanvasSize=='None','Original scrolling settings are untouched')
assert(equipped:FindFirstChild('Knife'):FindFirstChild('ItemName').Text=='Default Knife' and equipped:FindFirstChild('Knife'):FindFirstChild('Icon').Image=='side-knife','Native side slot restores on disable')
layout:Destroy();assert(api.enable(),'Manual card positions are supported');flush()
assert(collection():FindFirstChildOfClass('UIGridLayout'),'Only owned collection receives fallback layout')
api.disable();assert(not seasonPane:FindFirstChildOfClass('UIGridLayout'),'Original manual native layout remains unchanged')
local empty=create(playerGui,{list=function()return{}end})
assert(not empty.enable(),'Empty catalog cannot claim success')
assert(not collection() and seasonPane.Visible,'Failed enable restores native panels')
local missing=create(node('PlayerGui','Empty'),catalog)
assert(not missing.enable(),'Missing native inventory fails clearly')
api.destroy();assert(not pcall(api.enable),'Destroyed browser cannot re-enable')
print('Native inventory categories, rarity order, local equip, close/reopen, full GUI rebuild and cleanup passed.')

-- Large categories yield between batches and reopening reuses the existing cards.
local largeEntries={}
for i=1,100 do largeEntries[i]={id='batch'..i,kind='Knife',name='Batch '..i,image=1000+i,category='season1',rarity='Common'} end
local largeCatalog={list=function(kind)return kind=='Knife' and largeEntries or {} end,getEquipped=function()return{}end}
local pauses=0
task.wait=function()pauses=pauses+1 end
local largeApi=create(playerGui,largeCatalog)
assert(largeApi.enable());flush()
assert(#generated()==100 and pauses==4,'Large catalogs yield every 24 cards rather than cloning everything in one frame')
local existingCard=generated()[1]
inventory.Visible=false;inventory.Visible=true;flush()
assert(generated()[1]==existingCard and pauses==4,'Unchanged reopen neither clones cards nor performs another batch load')
largeApi.disable();flush()
-- Turning off the hub during a yielded render cannot leave cards or watchers behind.
local cancelledApi=create(playerGui,largeCatalog)
task.wait=function()cancelledApi.disable()end
assert(not cancelledApi.enable(),'A render cancelled while yielding does not report successful enable')
flush();assert(not collection() and seasonPane.Visible,'Cancelled batches clean up the local collection and restore native panels')
task.wait=nil
print('Unchanged inventory reuse, large catalog batching and cancellation passed.')

-- Effects share native styling but have their own pane, cards, and selection.
local effectsPane=node('Frame','Effects',inventory)
local effectsItems=node('ScrollingFrame','Items',effectsPane)
node('UIGridLayout','Grid',effectsItems)
local none=node('Frame','None',effectsItems)
node('TextLabel','ItemName',none).Text='None'
node('ImageLabel','Icon',none).Image='native-none'
node('TextLabel','Equipped',none).Visible=false
local effectSlot=node('Frame','Equipped',effectsPane)
node('ImageLabel','Icon',effectSlot).Image='native-effect'
node('TextLabel','ItemName',effectSlot).Text='None'
local effectsSearch=node('TextBox','Search',effectsPane)
local effectChoice
local effectCatalog={list=function(kind)
    assert(kind=='Effect','Effects mode requests only effects')
    return{{id='Flames',name='Flames',kind='Effect',image=456,rarity='Godly'},{id='Sparkles',name='Sparkles',kind='Effect',image=789,rarity='Common'}}
end,getEquipped=function()return{Effect=effectChoice}end,equip=function(id,kind)assert(kind=='Effect');effectChoice=id;return'Applied local effect'end}
local weaponOverlay=create(playerGui,catalog)
assert(weaponOverlay.enable());flush()
local effectsOverlay=create(playerGui,effectCatalog,nil,'effects')
assert(effectsOverlay.enable());flush()
local effectCollection=effectsPane:FindFirstChild('HoneyBunLocal_Effects')
assert(effectCollection and collection(),'Weapon and effect collections coexist')
local effectCards={}
for _,v in ipairs(effectCollection:GetChildren())do if v.Name:find('HoneyBunLocal_Effect_',1,true)then effectCards[#effectCards+1]=v end end
assert(#effectCards==2 and not effectsItems.Visible and none.Parent==effectsItems,'Every catalog effect is shown without changing native cards')
assert(effectCards[1]:FindFirstChild('ItemName').Text=='Flames','Effect card uses the selected effect name')
overlay(effectCards[1]).Activated:Fire()
assert(effectChoice=='Flames' and effectCards[1]:FindFirstChild('Equipped').Visible,'Click equips an effect and marks its native card')
assert(effectSlot:FindFirstChild('ItemName').Text=='Flames' and effectSlot:FindFirstChild('Icon').Image=='rbxassetid://456','Native effect side slot shows local selection')
effectsSearch.Text='missing';flush()
local visibleCards=0
for _,v in ipairs(effectCollection:GetChildren())do if v.Name:find('HoneyBunLocal_Effect_',1,true)then visibleCards=visibleCards+1 end end
assert(visibleCards==0,'Effect search filters independently')
effectCollection:Destroy();effectsPane.Visible=false;effectsPane.Visible=true;flush()
assert(effectsPane:FindFirstChild('HoneyBunLocal_Effects'),'Effects collection reconnects after its pane is replaced')
assert(equipped:FindFirstChild('Knife'):FindFirstChild('ItemName').Text~='Flames','Reconnecting effects cannot overwrite a weapon side slot')
effectsOverlay.disable();flush()
assert(effectsItems.Visible and effectSlot:FindFirstChild('ItemName').Text=='None' and collection(),'Disabling effects restores its pane and keeps weapons enabled')
weaponOverlay.destroy();effectsOverlay.destroy()
print('Independent native effects inventory, equip, search, side slot and restoration passed.')

-- An unopened, empty Effects pane must not require an existing effect card or grid.
none:Destroy()
effectsItems:FindFirstChildOfClass('UIGridLayout'):Destroy()
effectsPane.Visible=false
effectsSearch.Text=''
local emptyEffects=create(playerGui,effectCatalog,nil,'effects')
assert(emptyEffects.enable(),'Empty unopened Effects pane borrows the native weapon card template');flush()
local emptyCollection=effectsPane:FindFirstChild('HoneyBunLocal_Effects')
assert(emptyCollection and emptyCollection:FindFirstChildOfClass('UIGridLayout'),'Empty Effects pane receives its own local card grid')
local emptyCount=0
for _,v in ipairs(emptyCollection:GetChildren())do if v.Name:find('HoneyBunLocal_Effect_',1,true)then emptyCount=emptyCount+1 end end
assert(emptyCount==2 and knife.Parent==seasonPane,'All effects render without moving native weapon cards')
emptyEffects.destroy();flush()
assert(effectsItems.Visible and not effectsPane.Visible,'Empty Effects cleanup preserves original visibility')
print('Empty unopened Effects pane fallback passed.')

local notOpened=create(node('PlayerGui','NotOpened'),effectCatalog,nil,'effects')
local opened,message=notOpened.enable()
assert(not opened and message:find("Open MM2's Effects inventory",1,true),'Unopened effects panel gives a clear next step')
assert(not message:find('\n',1,true) and not message:match(':%d+:'),'Panel error keeps debug trees and source line numbers out of the hub status')
assert(notOpened.report():find('Inventory diagnostics:',1,true),'Full panel diagnostics remain available in Copy MM2 report')
notOpened.destroy()
print('Unopened inventory guidance and separate diagnostic report passed.')
