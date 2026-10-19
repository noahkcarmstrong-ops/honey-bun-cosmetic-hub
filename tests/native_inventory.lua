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
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)
    if k=='Parent' then
        local old=t.props.Parent
        if old then for i,c in ipairs(old.children) do if c==t then table.remove(old.children,i);break end end end
        t.props.Parent=v
        if v then v.children[#v.children+1]=t;v.ChildAdded:Fire(t) end
    else t.props[k]=v end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,Visible=true,Active=true,Text='',PlaceholderText='',ZIndex=1,Size='card-size',AbsoluteSize={X=100,Y=100},Activated=signal(),ChildAdded=signal(),changed=signal()},children={}},meta)
    n.Parent=parent;return n
end
function methods:IsA(class)
    return self.ClassName==class or (class=='GuiObject' and guiClasses[self.ClassName]) or (class=='GuiButton' and (self.ClassName=='TextButton' or self.ClassName=='ImageButton')) or (class=='LuaSourceContainer' and (self.ClassName=='LocalScript' or self.ClassName=='Script' or self.ClassName=='ModuleScript')) or false
end
function methods:GetChildren()local out={};for _,c in ipairs(self.children)do out[#out+1]=c end;return out end
function methods:GetDescendants()local out={};local function walk(p)for _,c in ipairs(p.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end
function methods:FindFirstChildOfClass(class)for _,c in ipairs(self.children)do if c:IsA(class)then return c end end end
function methods:GetFullName()return (self.Parent and self.Parent:GetFullName()..'.' or '')..self.Name end
function methods:GetPropertyChangedSignal()return self.changed end
function methods:Destroy()for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil;self.destroyed=true end
function methods:Clone()
    local n=node(self.ClassName,self.Name)
    for k,v in pairs(self.props)do if k~='Parent' and k~='Activated' and k~='ChildAdded' and k~='changed'then n[k]=v end end
    for _,c in ipairs(self.children)do c:Clone().Parent=n end
    return n
end
Instance={new=function(class)return node(class)end}
UDim2={fromScale=function(x,y)return{x=x,y=y}end,fromOffset=function(x,y)return{x=x,y=y}end}
Enum={SortOrder={LayoutOrder='LayoutOrder'},AutomaticSize={Y='AutoY'}}
local playerGui=node('PlayerGui','PlayerGui')
local inventory=node('Frame','Inventory',playerGui)
local scroll=node('ScrollingFrame','Weapons',inventory);scroll.CanvasSize='original-canvas';scroll.AutomaticCanvasSize='None'
local grid=node('Frame','Cards',scroll);grid.AutomaticSize='None'
local layout=node('UIGridLayout','Layout',grid)
local function card(name,label)
    local c=node('Frame',name,grid)
    local text=node('TextLabel','ItemName',c);text.Text=label
    local image=node('ImageLabel','Icon',c);image.Image='original-icon'
    node('TextButton','NativeEquip',c)
    node('LocalScript','NativeScript',c)
    return c
end
local knife=card('Knife','Default Knife')
local gun=card('Gun','Default Gun');gun.Visible=false
local search=node('TextBox','Search',inventory)
local season=node('TextButton','Season',inventory);season.Text='Season 1'
local holiday=node('TextButton','Holiday',inventory);holiday.Text='Holiday'
local lastPreview
local catalog={list=function(kind,q)
    local entry=kind=='Knife' and {id='rare',kind='Knife',name='Rare Knife',image=123,season=1} or {id='chroma',kind='Gun',name='Chroma Gun',image='rbxassetid://456',season='Holiday'}
    if q and q~='' and not entry.name:lower():find(q,1,true) then return {} end
    return {entry}
end,preview=function(id,kind)lastPreview=id..':'..kind;return'Applied' end}
local function generated()
    local out={};for _,c in ipairs(grid:GetChildren())do if c.Name:find('HoneyBunLocal_',1,true) then out[#out+1]=c end end;return out
end
local api=create(playerGui,catalog)
local ok,msg=api.enable();assert(ok,msg)
assert(#generated()==2,'Creates both native cosmetic cards')
assert(not knife.Visible and not gun.Visible,'Hides native originals while enabled')
assert(scroll.AutomaticCanvasSize=='AutoY','Enables scrolling for all catalog cards')
local localCard=generated()[1]
assert(localCard.Visible and localCard.LayoutOrder==1,'Clones are visible and ordered')
assert(localCard:FindFirstChildOfClass('ImageLabel').Image=='rbxassetid://123','Uses normalized catalog images')
local button
for _,v in ipairs(localCard:GetDescendants())do
    assert(not v:IsA('LuaSourceContainer'),'Cloned scripts are stripped')
    if v.Name=='HoneyBunPreviewClick'then button=v end
    if v.Name=='NativeEquip'then assert(not v.Active,'Native equip button is disabled')end
end
assert(button and button.ZIndex>localCard.ZIndex,'Local overlay captures card clicks')
button.Activated:Fire();assert(lastPreview=='rare:Knife','Click previews exactly the selected item')
season.Activated:Fire();assert(#generated()==1,'Season 1 matches numeric season metadata')
holiday.Activated:Fire();assert(#generated()==1 and generated()[1].Name:find('chroma',1,true),'Holiday tab filters local cards')
search.Text='missing';search.changed:Fire();assert(#generated()==0,'Native search filters owned cards')
search.Text='';search.changed:Fire()
api.disable()
assert(#generated()==0 and knife.Visible and not gun.Visible,'Disable restores exact original visibility')
assert(scroll.CanvasSize=='original-canvas' and scroll.AutomaticCanvasSize=='None' and grid.AutomaticSize=='None','Restores scrolling and grid settings')
assert(not knife.destroyed and not gun.destroyed,'Original cards survive cleanup')
layout:Destroy()
local enabled,message=api.enable();assert(enabled,message)
assert(grid:FindFirstChildOfClass('UIGridLayout'),'Manual native layouts receive an owned grid layout')
api.disable();assert(not grid:FindFirstChildOfClass('UIGridLayout'),'Owned layout is removed on disable')
local empty=create(playerGui,{list=function()return{}end})
assert(not empty.enable(),'Empty catalog does not claim success')
assert(knife.Visible and not gun.Visible and #generated()==0,'Failed enable rolls back native UI')
local missing=create(node('PlayerGui','Empty'),catalog)
assert(not missing.enable() and missing.report():find('not detected',1,true),'Missing native template fails clearly')
api.destroy()
assert(not pcall(api.enable),'Destroyed browser cannot be re-enabled')
print('Native inventory cloning, local clicks, filters, fallback layout, failure rollback and restoration passed.')
