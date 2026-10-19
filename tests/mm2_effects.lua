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
        if v then v.children[#v.children+1]=t;v.ChildAdded:Fire(t)end
    else
        local old=t.props[k];t.props[k]=v
        if old~=v and t.propertySignals[k] then t.propertySignals[k]:Fire()end
    end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),CharacterAdded=signal()},children={},propertySignals={}},meta)
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
    for k,v in pairs(self.props)do if k~='Parent'and k~='ChildAdded'and k~='CharacterAdded'then copy[k]=v end end
    for _,v in ipairs(self.children)do v:Clone().Parent=copy end
    return copy
end
local function count(root,class)local n=0;for _,v in ipairs(root:GetDescendants())do if v:IsA(class)then n=n+1 end end;return n end
local function first(root,class)for _,v in ipairs(root:GetDescendants())do if v:IsA(class)then return v end end end
local rs=node('Folder','ReplicatedStorage')
local sync=node('Folder','Sync',node('Folder','Database',rs))
local module=node('ModuleScript','Effects',sync)
local resources=node('Folder','Resources',rs)
local attachment=node('Attachment','GlowOrigin')
local emitter=node('ParticleEmitter','Glow',attachment);emitter.Rate=5;emitter.Enabled=false
node('LocalScript','DoNotRun',emitter)
local trailSource=node('Folder','TrailFx',resources)
local a=node('Attachment','A',trailSource);local b=node('Attachment','B',trailSource)
local trail=node('Trail','Trail',trailSource);trail.Attachment0=a;trail.Attachment1=b;trail.Enabled=false
local burst=node('ParticleEmitter','Burst');burst.Rate=0
local broken=node('Trail','Broken')
node('ParticleEmitter','Ambiguous',resources);node('ParticleEmitter','Ambiguous',resources)
module.Data={Spark={ItemName='Spark',Rarity='Rare',Effect=attachment,ImageID=999},TrailFx={Name='Trail'},
    ServerOnly={Name='Kill only'},Burst={Effect=burst},Broken={Effect=broken},Ambiguous={},AssetOnly={EffectID=12345}}
local char=node('Model','Character');local handle=node('Part','Handle',node('Tool','Knife',char))
local display=node('Part','KnifeDisplay');local ref=node('ObjectValue','DisplayRefKnife',char);ref.Value=display
local player=node('Player','Player');player.Character=char;player.Backpack=node('Backpack','Backpack')
local game={GetService=function(_,name)return name=='ReplicatedStorage'and rs or name=='Players'and{LocalPlayer=player}end}
require=function(m)return m.Data end
local api=dofile('mm2_effects.lua')(game)
local list=api.list('Effect');assert(#list==7,'Every catalog effect remains listed, including unsupported effects')
local sparkle=api.list('Effect','Spark')[1];assert(sparkle.image==999 and sparkle.kind=='Effect' and sparkle.rarity=='Rare','Effect names, images and metadata come from the catalog')
assert(api.equip('Spark','Effect'):find('Equipped effect'),'Supported source equips')
assert(count(handle,'ParticleEmitter')==1 and count(display,'ParticleEmitter')==1,'The effect reaches both the actual knife and avatar display')
assert(first(display,'ParticleEmitter').Parent:IsA('Attachment'),'Root Attachment is preserved as emitter parent')
assert(first(display,'ParticleEmitter').Enabled and not emitter.Enabled,'Only copied visuals are enabled')
assert(count(display,'LocalScript')==0 and count(attachment,'LocalScript')==1,'Nested scripts are stripped while source stays intact')
local oldGlow=first(display,'ParticleEmitter')
assert(api.equip('TrailFx','Effect'):find('Equipped effect'),'Exact catalog-key template resolves from replicated resources')
local copiedTrail=first(display,'Trail')
assert(oldGlow.destroyed and copiedTrail and copiedTrail.Attachment0~=a and copiedTrail.Attachment1~=b,'Switching removes previous visuals and remaps trail attachments')
assert(copiedTrail.Attachment0.Parent==display and copiedTrail.Attachment1.Parent==display,'Trail endpoints attach to the actual display')
for _,id in ipairs({'ServerOnly','Burst','Broken','Ambiguous'})do
    assert(api.equip(id,'Effect'):find('unavailable locally'),'Unavailable, burst-only and ambiguous effects cannot claim visible equip')
    assert(#display:GetChildren()==0 and #handle:GetChildren()==0,'Failed effect leaves no partial clones')
end
api.equip('Spark','Effect')
local previous=first(display,'ParticleEmitter')
local fresh=node('Model','Respawn');player.Character=fresh;player.CharacterAdded:Fire(fresh)
assert(previous.destroyed,'Reset removes old preview')
local lateRef=node('ObjectValue','DisplayRefKnife',fresh)
local replacement=node('Part','NewDisplay');lateRef.Value=replacement
assert(count(replacement,'ParticleEmitter')==1,'Late reference and Value arrival reapply the selected effect')
player.Backpack=node('Backpack','NewBackpack');player.ChildAdded:Fire(player.Backpack)
local lateTool=node('Tool','Knife',player.Backpack);local lateHandle=node('Part','Handle',lateTool)
assert(count(lateHandle,'ParticleEmitter')==1,'Replacement Backpack and late Handle both receive the selected effect')
local cleanRoot=node('Folder','LateAsset');node('ParticleEmitter','AssetVisual',cleanRoot)
game.GetObjects=function()api.restore();return{cleanRoot}end
assert(api.equip('AssetOnly','Effect'):find('cancelled')and cleanRoot.destroyed,'Restore cancels a yielding asset request and destroys late results')
assert(#replacement:GetChildren()==0 and #lateHandle:GetChildren()==0 and not api.getEquipped().Effect,'Restore clears selection and all added visuals')
local switchedRoot=node('Folder','SupersededAsset');node('ParticleEmitter','OldEffect',switchedRoot)
game.GetObjects=function()api.equip('Spark','Effect');return{switchedRoot}end
assert(api.equip('AssetOnly','Effect'):find('cancelled')and switchedRoot.destroyed,'A new selection supersedes an older yielding request')
assert(api.getEquipped().Effect=='Spark'and count(replacement,'ParticleEmitter')==1,'Late old results do not overwrite the new selection')
-- Real MM2 definitions reference visual assets through KnifeModule.
module.Data.LegacyFire={Name='Legacy Fire',KnifeModule=473588389}
local legacyApi=dofile('mm2_effects.lua')(game)
local downloaded=node('ModuleScript','KnifeEffect')
local downloadedVisual=node('Fire','Flame',downloaded)
node('Script','NeverExecute',downloaded)
local requested
local requireBefore=require
require=function(m)assert(m==module,'Downloaded effect code must never execute');return requireBefore(m)end
game.GetObjects=function(_,asset)requested=asset;return{downloaded}end
assert(legacyApi.equip('LegacyFire','Effect'):find('Equipped effect'),'KnifeModule assets supply visual children')
assert(requested=='rbxassetid://473588389' and count(replacement,'Fire')==1,'Actual knife display receives KnifeModule visual')
assert(count(replacement,'Script')==0,'Downloaded scripts are never attached')
assert(legacyApi.report():find('selected definition=LegacyFire',1,true),'Report includes selected effect definition even beyond sample limit')
legacyApi.destroy()
require=requireBefore
-- Blue Fire remains visible when its original asset is unavailable.
module.Data.BlueFire={Name='Blue Flaming Knife',KnifeModule=473588389}
Instance={new=function(class)return node(class)end}
Color3={fromRGB=function(r,g,b)return{R=r,G=g,B=b}end}
game.GetObjects=function()return{}end
local fireApi=dofile('mm2_effects.lua')(game)
assert(fireApi.equip('BlueFire','Effect'):find('local recreation',1,true),'Unavailable BlueFire asset uses an explicitly labeled native flame recreation')
local fire=first(replacement,'Fire')
assert(fire and fire.Enabled and fire.Color.B==255,'Blue flame is attached and enabled on the real display')
assert(count(lateHandle,'Fire')==1,'Blue flame also reaches the held knife')
assert(fireApi.report():find('built-in blue flame recreation',1,true),'Report identifies recreated effect source')
fireApi.restore();assert(fire.destroyed and count(lateHandle,'Fire')==0,'Restoring removes recreated flames')
fireApi.destroy()
local report=api.report();assert(report:find('defs=')and report:find('targets=')and report:find('source='),'Report includes definition and target diagnostics')
api.destroy();assert(#replacement:GetChildren()==0 and #lateHandle:GetChildren()==0,'Closing the hub cleans all previews')
assert(not pcall(api.equip,'Spark','Effect'),'Closed effect service cannot equip')
local after=node('Part','AfterClose');lateRef.Value=after;assert(#after:GetChildren()==0,'Closed service disconnects lifecycle listeners')
local closingApi=dofile('mm2_effects.lua')(game)
local closingRoot=node('Folder','ClosingRoot');node('ParticleEmitter','Visual',closingRoot)
game.GetObjects=function()closingApi.destroy();return{closingRoot}end
assert(closingApi.equip('AssetOnly','Effect'):find('cancelled')and closingRoot.destroyed,'Closing the hub during asset loading destroys late results')
print('MM2 effects catalog, particle and trail cloning, script stripping, source matching, reset, late targets, cancellation and cleanup passed.')
