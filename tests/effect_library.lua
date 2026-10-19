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

local function typed(kind,values)values._kind=kind;return values end
typeof=function(v)return type(v)=='table'and v._kind or type(v)end
Color3={new=function(r,g,b)return typed('Color3',{R=r,G=g,B=b})end}
NumberRange={new=function(a,b)return typed('NumberRange',{Min=a,Max=b})end}
NumberSequenceKeypoint={new=function(t,v,e)return{Time=t,Value=v,Envelope=e or 0}end}
NumberSequence={new=function(keys)return typed('NumberSequence',{Keypoints=keys})end}
ColorSequenceKeypoint={new=function(t,c)return{Time=t,Value=c}end}
ColorSequence={new=function(keys)return typed('ColorSequence',{Keypoints=keys})end}
CFrame={new=function(...)local a={...};return typed('CFrame',{GetComponents=function()return table.unpack(a)end})end}
local function deep(v)if type(v)~='table'then assert(type(v)~='function','No executable values may be saved');return v end;local out={};for k,x in pairs(v)do out[k]=deep(x)end;return out end
local documents={};local nextDoc=0
local http={JSONEncode=function(_,value)nextDoc=nextDoc+1;local key='json'..nextDoc;documents[key]=deep(value);return key end,JSONDecode=function(_,key)return deep(assert(documents[key]))end}
local function gui(raw)local attrs={HoneyBunCosmeticEffects=raw};return{GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end}end
Instance={new=function(class)return node(class)end}
local rs=node('Folder','ReplicatedStorage');local sync=node('Folder','Sync',node('Folder','Database',rs));local db=node('ModuleScript','Effects',sync);db.Data={Bats={Name='Bats'}}
require=function(m)return m.Data end
local localPlayer=node('Player','Duncan5783');localPlayer.Character=node('Model','LocalCharacter')
local qosra=node('Player','qosra');qosra.Character=node('Model','qosra')
local other=node('Player','Other');other.Character=node('Model','Other')
local display=node('Part','KnifeDisplay');local ref=node('ObjectValue','DisplayRefKnife',qosra.Character);ref.Value=display
local a=node('Attachment','Origin',display);a.CFrame=CFrame.new(0,1,0,1,0,0,0,1,0,0,0,1)
local b=node('Attachment','End',display)
local emitter=node('ParticleEmitter','OriginalParticles',a);emitter.Texture='rbxassetid://123';emitter.Rate=0;emitter.Enabled=false
emitter.Lifetime=NumberRange.new(1,2)
emitter.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0,0)),ColorSequenceKeypoint.new(1,Color3.new(0,1,0))})
emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0.1),NumberSequenceKeypoint.new(1,0)})
local trail=node('Trail','OriginalTrail',display);trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=0.3
node('Script','NeverSave',display);node('Tool','NeverSaveGear',display)
local players={LocalPlayer=localPlayer,GetPlayers=function()return{other,localPlayer,qosra}end}
local game={GetService=function(_,name)return({HttpService=http,Players=players,ReplicatedStorage=rs})[name]end}
local screen=gui();local create=dofile('effect_library.lua');local library=create(game,screen)
assert(library.capturePlayer('qosra'):find('1 new',1,true),'qosra loaded effect can be captured')
assert(#library.list()==1 and library.list()[1].name=='Effect from qosra','Unidentified effect uses an honest player label')
assert(library.capturePlayer('qosra'):find('1 already saved',1,true),'Identical captures are deduplicated')
assert(emitter.Rate==0 and emitter.Parent==a and trail.Attachment0==a,'The source player visuals are unchanged')
assert(library.capturePlayer('Missing'):find('not in this server',1,true),'Missing player is reported')
local saved=screen:GetAttribute('HoneyBunCosmeticEffects');assert(saved,'Capture stores portable data for hub persistence')
local oldSource=library.list()[1].definition.Effect
assert(count(oldSource,'Script')==0 and count(oldSource,'Tool')==0,'Scripts and gear are never copied')
library.destroy();display:Destroy();ref.Value=nil
local restored=create(game,gui(saved));local source=restored.list()[1].definition.Effect
assert(count(source,'ParticleEmitter')==1 and count(source,'Trail')==1,'Original visuals restore without source player or server objects')
local restoredParticle=first(source,'ParticleEmitter');assert(restoredParticle.Texture=='rbxassetid://123'and restoredParticle.Rate==0,'Original texture and emission settings round trip')
assert(restoredParticle.Lifetime.Min==1 and restoredParticle.Color.Keypoints[2].Value.G==1 and restoredParticle.Size.Keypoints[1].Envelope==0.1,'Particle ranges, colors and envelopes round trip')
local restoredTrail=first(source,'Trail');assert(restoredTrail.Attachment0.Parent==source and restoredTrail.Attachment1.Parent==source,'Trail links reconnect to saved attachments')
assert(restored.captureServer('qosra'):sub(1,6)=='qosra:','Server collection starts with qosra')
-- The real playback module can equip the portable captured source.
local back=node('Part','BackKnife');local backRef=node('ObjectValue','DisplayRefKnife',localPlayer.Character);backRef.Value=back
local api=dofile('mm2_effects.lua')(game,nil,restored)
assert(#api.list('Effect')==2,'Bats and saved original both appear in the effects inventory')
assert(api.equip(restored.list()[1].id,'Effect'):find('original visuals',1,true),'Saved effect uses original playback')
assert(count(back,'ParticleEmitter')==1 and count(back,'Trail')==1,'Restored particles and trail reach the back knife')
api.destroy();restored.destroy();assert(#back:GetChildren()==0,'Saved effect playback cleans up')
-- Saved files cannot introduce executable classes.
local bad=http:JSONEncode({version=1,entries={{id='Bad',name='Bad',records={{class='Script',name='DoNotRun',values={}}}}}})
local invalid=create(game,gui(bad));assert(#invalid.list()==0,'Invalid executable records are rejected');invalid.destroy()
print('Player effect capture, deduplication, original preservation, script exclusion, portable properties, trail references, rejoin and back-knife playback passed.')
