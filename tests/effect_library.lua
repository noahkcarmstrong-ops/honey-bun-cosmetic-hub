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
        if old then old.ChildRemoved:Fire(t) end
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
    local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),ChildRemoved=signal(),DescendantAdded=signal(),CharacterAdded=signal()},children={},propertySignals={}},meta)
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
local rs=node('Folder','ReplicatedStorage');local sync=node('Folder','Sync',node('Folder','Database',rs));local db=node('ModuleScript','Effects',sync);db.Data={Bats={Name='Bats'},Known={Name='Known Effect',Image=123,Rarity='Godly'},AmbiguousA={Name='Shared'},AmbiguousB={Name='Shared'},Fire={Name='Fire',Image=456}}
require=function(m)return m.Data end
local localPlayer=node('Player','LocalTestPlayer');localPlayer.Character=node('Model','LocalCharacter')
local EffectPlayer=node('Player','EffectPlayer');EffectPlayer.Character=node('Model','EffectPlayer')
local other=node('Player','Other');other.Character=node('Model','Other')
local display=node('Part','KnifeDisplay');local ref=node('ObjectValue','DisplayRefKnife',EffectPlayer.Character);ref.Value=display
local a=node('Attachment','Origin',display);a.CFrame=CFrame.new(0,1,0,1,0,0,0,1,0,0,0,1)
local b=node('Attachment','End',display)
local emitter=node('ParticleEmitter','OriginalParticles',a);emitter.Texture='rbxassetid://123';emitter.Rate=0;emitter.Enabled=false
emitter.Lifetime=NumberRange.new(1,2)
emitter.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0,0)),ColorSequenceKeypoint.new(1,Color3.new(0,1,0))})
emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0.1),NumberSequenceKeypoint.new(1,0)})
local trail=node('Trail','OriginalTrail',display);trail.Attachment0=a;trail.Attachment1=b;trail.Lifetime=0.3
node('Script','NeverSave',display);node('Tool','NeverSaveGear',display)
local players={LocalPlayer=localPlayer,GetPlayers=function()return{other,localPlayer,EffectPlayer}end}
local game={GetService=function(_,name)return({HttpService=http,Players=players,ReplicatedStorage=rs})[name]end}
local screen=gui();local create=dofile('effect_library.lua');local library=create(game,screen)
assert(library.capturePlayer('EffectPlayer'):find('1 new',1,true),'EffectPlayer loaded effect can be captured')
assert(#library.list()==1 and library.list()[1].name=='Effect from EffectPlayer','Unidentified effect uses an honest player label')
assert(library.capturePlayer('EffectPlayer'):find('1 already saved',1,true),'Identical captures are deduplicated')
assert(emitter.Rate==0 and emitter.Parent==a and trail.Attachment0==a,'The source player visuals are unchanged')
assert(library.capturePlayer('Missing'):find('not in this server',1,true),'Missing player is reported')
local saved=screen:GetAttribute('HoneyBunCosmeticEffects');assert(saved,'Capture stores portable data for hub persistence')
local effectId=library.list()[1].id
library.select(effectId)
saved=screen:GetAttribute('HoneyBunCosmeticEffects')
local oldSource=library.list()[1].definition.Effect
assert(count(oldSource,'Script')==0 and count(oldSource,'Tool')==0,'Scripts and gear are never copied')
library.destroy();display:Destroy();ref.Value=nil
local restored=create(game,gui(saved));local source=restored.list()[1].definition.Effect
assert(restored.getSelected()==effectId,'Selected effect survives leaving and rejoining')
assert(count(source,'ParticleEmitter')==1 and count(source,'Trail')==1,'Original visuals restore without source player or server objects')
local restoredParticle=first(source,'ParticleEmitter');assert(restoredParticle.Texture=='rbxassetid://123'and restoredParticle.Rate==0,'Original texture and emission settings round trip')
assert(restoredParticle.Lifetime.Min==1 and restoredParticle.Color.Keypoints[2].Value.G==1 and restoredParticle.Size.Keypoints[1].Envelope==0.1,'Particle ranges, colors and envelopes round trip')
local restoredTrail=first(source,'Trail');assert(restoredTrail.Attachment0.Parent==source and restoredTrail.Attachment1.Parent==source,'Trail links reconnect to saved attachments')
assert(restored.captureServer('EffectPlayer'):sub(1,#'EffectPlayer:')=='EffectPlayer:','Server collection starts with EffectPlayer')
-- The real playback module can equip the portable captured source.
local back=node('Part','BackKnife');local backRef=node('ObjectValue','DisplayRefKnife',localPlayer.Character);backRef.Value=back
local api=dofile('mm2_effects.lua')(game,nil,restored)
assert(api.getEquipped().Effect==effectId and count(back,'ParticleEmitter')==1,'Saved effect automatically reapplies without opening native inventory')
assert(#api.list('Effect')==2,'Bats and saved original both appear in the effects inventory')
assert(api.equip(restored.list()[1].id,'Effect'):find('original visuals',1,true),'Saved effect uses original playback')
assert(count(back,'ParticleEmitter')==1 and count(back,'Trail')==1,'Restored particles and trail reach the back knife')
local replacement=node('Part','SavedKnifeAppearance',node('Folder','Workspace'));local marker=node('ObjectValue','HoneyBunCosmeticVisual');marker.Value=replacement;marker.Parent=back
assert(count(replacement,'ParticleEmitter')==1 and count(back,'ParticleEmitter')==0,'Saved effect attaches to the replacement knife mesh')
marker:Destroy()
assert(count(replacement,'ParticleEmitter')==0 and count(back,'ParticleEmitter')==1,'Removing replacement moves effect back onto the real knife')
api.destroy();assert(restored.getSelected()==effectId,'Closing hub preserves selected effect')
assert(count(replacement,'ParticleEmitter')==0,'Replacement knife effect cleans up')
restored.destroy();assert(#back:GetChildren()==0,'Saved effect playback cleans up')
-- Catalog metadata is canonicalized by ID, while ambiguous and generic names stay unidentified.
local knownRaw=http:JSONEncode({version=1,entries={{id='KnownSaved',name='Old label',catalog={id='Known',image='spoof',rarity='spoof'},records={{class='ParticleEmitter',name='Known Effect',values={}}}}}})
local known=create(game,gui(knownRaw));local knownEntry=known.list()[1]
assert(knownEntry.name=='Known Effect' and knownEntry.image==123 and knownEntry.rarity=='Godly','Known effect metadata comes from the exact catalog ID')
known.destroy()
local ambiguousRaw=http:JSONEncode({version=1,entries={{id='AmbiguousSaved',name='Shared',records={{class='ParticleEmitter',name='Shared',values={}}}}}})
local ambiguous=create(game,gui(ambiguousRaw));assert(ambiguous.list()[1].name=='Shared' and ambiguous.list()[1].image==nil,'Ambiguous catalog names do not invent metadata');ambiguous.destroy()
local genericRaw=http:JSONEncode({version=1,entries={{id='GenericSaved',name='Fire',records={{class='Fire',name='Fire',values={}}}}}})
local generic=create(game,gui(genericRaw));assert(generic.list()[1].name=='Fire' and generic.list()[1].image==nil,'Generic visual names do not become catalog identities');generic.destroy()
-- Legacy files may contain the same visuals under different labels/IDs. Keep the
-- first saved record, remap selection to it, and expose an honest particle preview.
local duplicateRaw=http:JSONEncode({version=1,selected='Second',entries={
    {id='First',name='First label',records={{class='ParticleEmitter',name='A',values={Texture='rbxassetid://preview'}}}},
    {id='Second',name='Second label',records={{class='ParticleEmitter',name='B',values={Texture='rbxassetid://preview'}}}}
}})
local duplicateGui=gui(duplicateRaw)
local duplicate=create(game,duplicateGui);local duplicateEntry=duplicate.list()[1]
assert(#duplicate.list()==1 and duplicateEntry.id=='First','Portable duplicate visuals collapse by exact visual data')
assert(duplicate.getSelected()=='First','Selection follows the retained duplicate record')
assert(duplicateEntry.image==nil and duplicateEntry.previewImage=='rbxassetid://preview' and duplicateEntry.preview.label=='Saved particle texture preview','Unknown effect exposes a labeled particle preview instead of an official icon')
assert(not pcall(duplicate.rename,'First','   '),'Blank effect names are rejected')
duplicate.rename('First','  My sparks  ')
local renamedRaw=duplicateGui:GetAttribute('HoneyBunCosmeticEffects')
duplicate.destroy()
local renamed=create(game,gui(renamedRaw));assert(renamed.list()[1].name=='My sparks' and renamed.list()[1].editable,'Effect custom names persist after reload');renamed.destroy()
-- Saved files cannot introduce executable classes.
local bad=http:JSONEncode({version=1,entries={{id='Bad',name='Bad',records={{class='Script',name='DoNotRun',values={}}}}}})
local invalid=create(game,gui(bad));assert(#invalid.list()==0,'Invalid executable records are rejected');invalid.destroy()
local removableRaw=http:JSONEncode({version=1,selected='Removable',entries={{id='Removable',name='Removable',records={{class='ParticleEmitter',name='Saved',values={}}}}}})
local removable=create(game,gui(removableRaw));local removableSource=removable.list()[1].definition.Effect
assert(removable.getSelected()=='Removable','Selected effect fixture loads')
local removed=removable.remove('Removable')
assert(removed.id=='Removable' and removable.getSelected()==nil and removableSource.destroyed,'Removing selected effect clears selection and destroys its template')
assert(#removable.list()==0,'Removed effect disappears from the saved library')
removable.destroy()
print('Player effect capture, deduplication, original preservation, script exclusion, portable properties, trail references, rejoin and back-knife playback passed.')
