local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={live=true};self.listeners[#self.listeners+1]={c,fn}
        function c:Disconnect()self.live=false end
        return c
    end
    function s:Fire(...)for _,v in ipairs(self.listeners)do if v[1].live then v[2](...)end end end
    return s
end
local methods={}
local meta={__index=function(t,k)return methods[k] or t.props[k]end,__newindex=function(t,k,v)
    if k=='Parent' then
        local old=t.props.Parent;if old==v then return end
        if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i);break end end end
        t.props.Parent=v
        if v then
            v.children[#v.children+1]=t;v.ChildAdded:Fire(t)
            local ancestor=v
            while ancestor do ancestor.DescendantAdded:Fire(t);ancestor=ancestor.Parent end
        end
    else
        local old=t.props[k];t.props[k]=v
        if old~=v and t.propertySignals[k] then t.propertySignals[k]:Fire()end
    end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),DescendantAdded=signal(),CharacterAdded=signal()},children={},propertySignals={}},meta)
    n.Parent=parent;return n
end
function methods:IsA(c)return c==self.ClassName or (c=='BasePart' and (self.ClassName=='Part' or self.ClassName=='MeshPart')) or (c=='Light' and self.ClassName=='PointLight')end
function methods:GetChildren()local out={};for _,v in ipairs(self.children)do out[#out+1]=v end;return out end
function methods:GetDescendants()local out={};local function walk(p)for _,v in ipairs(p.children)do out[#out+1]=v;walk(v)end end;walk(self);return out end
function methods:FindFirstChild(name)for _,v in ipairs(self.children)do if v.Name==name then return v end end end
function methods:GetPropertyChangedSignal(k)self.propertySignals[k]=self.propertySignals[k]or signal();return self.propertySignals[k]end
function methods:Destroy()for _,v in ipairs(self:GetChildren())do v:Destroy()end;self.Parent=nil;self.destroyed=true end
function methods:Clone()
    local copy=node(self.ClassName,self.Name)
    for k,v in pairs(self.props)do if k~='Parent'and k~='ChildAdded'and k~='DescendantAdded'and k~='CharacterAdded'then copy[k]=v end end
    for _,v in ipairs(self.children)do v:Clone().Parent=copy end
    -- Roblox Clone remaps references between descendants of the cloned root.
    local mapping={}
    local function map(a,b)mapping[a]=b;for i,child in ipairs(a.children)do map(child,b.children[i])end end
    map(self,copy)
    for original,cloned in pairs(mapping)do
        if original.Attachment0 then cloned.Attachment0=mapping[original.Attachment0]or original.Attachment0 end
        if original.Attachment1 then cloned.Attachment1=mapping[original.Attachment1]or original.Attachment1 end
    end
    return copy
end
local function count(root,class)local n=0;for _,v in ipairs(root:GetDescendants())do if v:IsA(class)then n=n+1 end end;return n end
local function first(root,class)for _,v in ipairs(root:GetDescendants())do if v:IsA(class)then return v end end end
local rs=node('Folder','ReplicatedStorage')
local sync=node('Folder','Sync',node('Folder','Database',rs))
local database=node('ModuleScript','Effects',sync)
database.Data={Bats={Name='Bats',KnifeModule=1133166797},BlueFire={Name='Blue Flaming Knife'},Flowerwood={Name='Flowerwood'}}
local world=node('Folder','Workspace')
local source=node('Folder','Bats',world)
local original=node('ParticleEmitter','ParticleEmitter',source);original.Rate=0;original.Texture='rbxassetid://5858070133'
local character=node('Model','Character')
local display=node('Part','KnifeDisplay',world)
local reference=node('ObjectValue','DisplayRefKnife',character);reference.Value=display
local backpack=node('Backpack','Backpack')
local held=node('Part','Handle',node('Tool','Knife',backpack))
local player=node('Player','Player');player.Character=character;player.Backpack=backpack
local game={GetService=function(_,name)return({ReplicatedStorage=rs,Workspace=world,Players={LocalPlayer=player}})[name]end}
require=function(m)assert(m==database);return m.Data end
local api=dofile('mm2_effects.lua')(game)
local catalog=api.list('Effect')
assert(#catalog==1 and catalog[1].id=='Bats','Only original Bats is offered')
assert(not pcall(api.equip,'BlueFire','Effect') and not pcall(api.equip,'Flowerwood','Effect'),'Other effects cannot be equipped')
assert(api.equip('Bats','Effect'):find('original visuals',1,true),'Bats keeps original visuals')
assert(count(display,'ParticleEmitter')==1 and count(held,'ParticleEmitter')==1,'Original Bats reaches back knife and held knife')
assert(first(display,'ParticleEmitter').Texture==original.Texture and first(display,'ParticleEmitter').Rate==2 and original.Rate==0,'Original texture is preserved and playback starts locally')
source:Destroy()
local nextDisplay=node('Part','NewKnifeDisplay',world);reference.Value=nextDisplay
assert(count(nextDisplay,'ParticleEmitter')==1 and #display:GetChildren()==0,'Cached original follows display replacement')
api.restore();assert(#nextDisplay:GetChildren()==0 and #held:GetChildren()==0,'Turning off Bats removes its visuals')
api.destroy()
print('Original Bats-only catalog, back and held knife playback, display replacement and cleanup passed.')
