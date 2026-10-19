local create=dofile('mm2.lua')
local function node(name,class,items)
    return {Name=name,ClassName=class,GetFullName=function()return name end,GetChildren=function()return items or {} end,GetDescendants=function()return items or {} end,IsA=function(self,c)return self.ClassName==c end}
end
local db=node('ReplicatedStorage.Database.Items','ModuleScript')
local ui=node('PlayerGui.Inventory.Equip','LocalScript')
local tool=node('Character.Knife','Tool')
local player={Name='Fixture',PlayerGui=node('PlayerGui','PlayerGui',{ui}),Character=node('Character','Model',{tool})}
local services={ReplicatedStorage=node('ReplicatedStorage','ReplicatedStorage',{db}),Players={LocalPlayer=player}}
local game={GameId=66654135,PlaceId=142823291,PlaceVersion=123,GetService=function(_,name)return services[name]end}
local report=create(game).report()
assert(report:find('ReplicatedStorage.Database.Items',1,true),'Reports item data module')
assert(report:find('PlayerGui.Inventory.Equip',1,true),'Reports inventory UI scripts without executing them')
assert(report:find('Character.Knife',1,true),'Reports equipped weapon')
assert(create({}).report():find('missing',1,true),'Handles unavailable game services')
print('MM2 read-only discovery checks passed.')

-- Catalog and reversible local preview checks use an injected ordinary require.
local itemModule=node('Item','ModuleScript')
itemModule.Data={KnifeAlpha={ItemName='Nebula Knife',ItemType='Knife',MeshId='mesh-new',TextureId='texture-new',Rarity='Godly',Image='rbxassetid://123',Season=1},KnifeBeta={ItemName='Second Knife',ItemType='Knife',MeshId='mesh-second'},GunAlpha={Name='Dart Gun',Type='Gun',Color='blue'}}
local emoteModule=node('Emotes','ModuleScript')
emoteModule.Data={Wave={Name='Wave',Type='Emote',AnimationId=12345},Dance={Name='Dance',AnimationID='67890'}}
local sync=node('Sync','Folder',{itemModule,emoteModule})
local database=node('Database','Folder',{sync})
local rs=node('ReplicatedStorage','ReplicatedStorage',{database})
local specialMesh=node('SpecialMesh','SpecialMesh'); specialMesh.MeshId='mesh-old'; specialMesh.TextureId='texture-old'
local handle=node('Handle','Part',{specialMesh}); handle.Color='red'; handle.Material='plastic'
local liveTool=node('Knife','Tool',{handle})
local liveCharacter=node('Character','Model',{liveTool})
local livePlayer={Name='Previewer',Character=liveCharacter,PlayerGui=node('PlayerGui','PlayerGui')}
local previewServices={ReplicatedStorage=rs,Players={LocalPlayer=livePlayer}}
local previewGame={GetService=function(_,name)return previewServices[name]end}
local injected=function(module)return module.Data end
local mm2=create(previewGame,injected)
local knives=mm2.list('Knife','nebula'); assert(#knives==1 and knives[1].kind=='Knife' and knives[1].rarity=='Godly','Lists and searches knife catalog')
assert(knives[1].image=='rbxassetid://123' and knives[1].season==1,'Native cards receive the real catalog image and season')
local guns=mm2.list('Gun'); assert(#guns==1 and guns[1].kind=='Gun','Classifies guns from Type: '..tostring(#guns))
local emotes=mm2.list('Emote'); assert(#emotes==2 and emotes[1].id~='' ,'Lists emotes including records without Type')
assert(mm2.preview('KnifeAlpha','Knife'):find('locally',1,true),'Previews an equipped knife locally')
assert(specialMesh.MeshId=='mesh-new' and specialMesh.TextureId=='texture-new','Applies explicit mesh fields')
mm2.restore(); assert(specialMesh.MeshId=='mesh-old' and specialMesh.TextureId=='texture-old' and handle.Color=='red','Restores mesh and handle appearance')
local secondMesh=node('SpecialMesh','SpecialMesh'); secondMesh.MeshId='mesh-second-old'
local secondHandle=node('Handle','Part',{secondMesh}); local secondTool=node('SecondKnife','Tool',{secondHandle}); local secondCharacter=node('Character','Model',{secondTool})
mm2.preview('KnifeAlpha','Knife')
livePlayer.Character=secondCharacter; assert(mm2.preview('KnifeBeta','Knife'):find('locally',1,true),'Previews a second equipped handle'); mm2.restore(); assert(secondMesh.MeshId=='mesh-second-old' and specialMesh.MeshId=='mesh-old','Restores both changed handles in one operation')
livePlayer.Character=liveCharacter; local mismatchOk,mismatch=pcall(function() mm2.preview('GunAlpha','Gun') end); assert(not mismatchOk and tostring(mismatch):find('matching gun',1,true),'Rejects category mismatch with equipped knife')
local badData=node('Item','ModuleScript'); badData.Data={Unknown={ItemName='Plain Knife',ItemType='Knife'}}
local badSync=node('Sync','Folder',{badData}); local badRs=node('ReplicatedStorage','ReplicatedStorage',{node('Database','Folder',{badSync})})
local badGame={GetService=function(_,name) if name=='ReplicatedStorage' then return badRs end if name=='Players' then return {LocalPlayer=livePlayer} end end}
local bad=create(badGame,function(module)return module.Data end); local ok,msg=pcall(function() bad.preview('Unknown','Knife') end); assert(not ok and tostring(msg):find('supported local visual',1,true),'Rejects unsupported visuals honestly')
print('MM2 catalog, local preview, restore, and unsupported-visual checks passed.')

local animator=node('Animator','Animator')
local played,stopped,removed=false,false,false
function animator:LoadAnimation(anim)
    assert(anim.AnimationId=='rbxassetid://67890','Normalizes numeric animation strings')
    return {Play=function()played=true end,Stop=function()stopped=true end,Destroy=function()removed=true end}
end
local humanoid=node('Humanoid','Humanoid',{animator})
livePlayer.Character=node('Character','Model',{humanoid})
local animationDestroyed=false
Instance={new=function(class)return {Destroy=function()animationDestroyed=true end}end}
mm2.preview('Dance','Emote');assert(played and animationDestroyed,'Plays emote and cleans up the temporary animation')
mm2.restore();assert(stopped and removed,'Restore stops and destroys the emote track')
local errorReport=create(badGame,function()error('Fixture cannot load module')end).report()
assert(errorReport:find('Fixture cannot load module',1,true),'Reports database errors for live diagnosis')
print('MM2 multi-weapon restoration and emote lifecycle checks passed.')

-- Metadata keeps explicit holiday flags ahead of Season and equip waits for the native Tool lifecycle.
local signal=function() local listeners={}; return {Connect=function(_,fn) listeners[#listeners+1]=fn; return {Disconnect=function() end} end,Fire=function(_,value) for _,fn in ipairs(listeners) do fn(value) end end} end
local mixed=node('Item','ModuleScript'); mixed.Data={Mixed={ItemName='Mixed Holiday',ItemType='Knife',Season=1,Event='Halloween',Year=2024,Rarity='Godly',SortOrder=7,Chroma='true',Model='HolidayMesh'},Classic={ItemName='Classic',ItemType='Knife',Season=0},Plain={ItemName='Plain',ItemType='Knife'}}
local mixedSync=node('Sync','Folder',{mixed}); local mixedDb=node('Database','Folder',{mixedSync}); local source=node('HolidayMesh','MeshPart'); source.IsA=function(self,c)return c=='MeshPart' or c=='BasePart' or c==self.ClassName end; local resources=node('Resources','Folder',{source}); local mixedRs=node('ReplicatedStorage','ReplicatedStorage',{mixedDb,resources})
local backpack={GetChildren=function()return {} end,ChildAdded=signal()}; local character={GetChildren=function()return {} end,ChildAdded=signal()}; local mixedPlayer={Character=character,Backpack=backpack,CharacterAdded=signal()}
local mixedApi=create({GetService=function(_,name) return name=='ReplicatedStorage' and mixedRs or name=='Players' and {LocalPlayer=mixedPlayer} end},function(module)return module.Data end)
local cards=mixedApi.list('Knife'); local byId={}; for _,card in ipairs(cards) do byId[card.id]=card end
assert(byId.Mixed.category=='holiday' and byId.Mixed.year==2024 and byId.Mixed.event=='Halloween' and byId.Mixed.sortOrder==7 and byId.Mixed.chroma,'Combines explicit holiday metadata without losing season/year fields')
assert(byId.Classic.category=='classic' and byId.Plain.category=='classic','Season zero and missing season remain classic')
assert(mixedApi.equip('Mixed','Knife'):find('waiting',1,true),'Equip accepts a supported cosmetic before a Tool exists')
local liveHandle=node('Handle','MeshPart'); liveHandle.ApplyMesh=function(self,source) self.applied=source end; liveHandle.Clone=function(self)return {original=self,Destroy=function()self.destroyed=true end}end
local arriving=node('Knife','Tool',{liveHandle}); character.GetChildren=function()return {arriving}end; character.ChildAdded:Fire(arriving)
assert(liveHandle.applied==source,'Pending selection applies the resolved model to the arriving Tool Handle')
-- A successful initial equip must survive a fresh character, not just a still-pending selection.
local respawnHandle=node('Handle','MeshPart')
respawnHandle.ApplyMesh=liveHandle.ApplyMesh;respawnHandle.Clone=liveHandle.Clone
local respawnTool=node('Knife','Tool',{respawnHandle})
local respawnCharacter={GetChildren=function()return{respawnTool}end,ChildAdded=signal()}
mixedPlayer.Character=respawnCharacter;mixedPlayer.CharacterAdded:Fire(respawnCharacter)
assert(respawnHandle.applied==source,'Selected cosmetic reapplies after respawn even after pending state was cleared')
assert(mixedApi.getEquipped().Knife=='Mixed','Selection remains equipped across character replacement')
local displayHandle=node('Handle','MeshPart')
displayHandle.ApplyMesh=liveHandle.ApplyMesh;displayHandle.Clone=liveHandle.Clone
local display=node('KnifeDisplay','Model',{displayHandle})
respawnCharacter.ChildAdded:Fire(display)
assert(displayHandle.applied==source,'Existing native holstered weapon displays use the same local skin without replacing joints')
mixedApi.restore(); assert(liveHandle.applied and liveHandle.applied.original==liveHandle,'Restore reapplies the cloned original MeshPart source')
assert(respawnHandle.applied and respawnHandle.applied.original==respawnHandle and displayHandle.applied.original==displayHandle,'Restore returns respawned and holstered weapon meshes')
assert(not mixedApi.getEquipped().Knife,'Restore clears pending and selected cosmetics')
print('MM2 metadata, pending equip, respawn persistence and mesh restoration passed.')

-- Replays the real MM2 ItemID-only fields supplied in the live report.
local realData=node('Item','ModuleScript')
realData.Data={Fragile_G_2023={ItemID=12965349193,ItemName='Fragile',ItemType='Gun',Rarity='Common',Season=1},Gingerscythe={ItemID=15683138101,ItemName='Gingerscythe',ItemType='Knife',Rarity='Rare',Event='Christmas',Year=2023},ClassicItem={ItemID=999,ItemName='Classic',ItemType='Knife',Rarity='Common'}}
local assetScript={ClassName='LocalScript',IsA=function(_,c)return c=='LuaSourceContainer' end,Destroy=function(self)self.destroyed=true end}
local assetSource=node('Mesh','MeshPart',{assetScript});assetSource.MeshId='asset-mesh';assetSource.TextureID='asset-texture'
assetSource.IsA=function(_,c)return c=='BasePart'or c=='MeshPart'end
assetSource.Destroy=function(self)self.destroyed=true end
local weaponHandle=node('Handle','MeshPart');weaponHandle.MeshId='original-mesh';weaponHandle.TextureID='original-texture'
weaponHandle.ApplyMesh=function(self,v)self.MeshId=v.MeshId;self.TextureID=v.TextureID end
weaponHandle.Clone=function(self)return{MeshId=self.MeshId,TextureID=self.TextureID,Destroy=function(self)self.destroyed=true end}end
local weapon=node('Gun','Tool',{weaponHandle})
local assetPlayer={Character=node('Character','Model',{weapon})}
local assetServices={Players={LocalPlayer=assetPlayer},ReplicatedStorage=node('ReplicatedStorage','ReplicatedStorage',{node('Database','Folder',{node('Sync','Folder',{realData})})})}
local assetLoads=0
local assetGame={GetService=function(_,name)return assetServices[name]end,GetObjects=function(_,uri)assert(uri=='rbxassetid://12965349193');assetLoads=assetLoads+1;return{assetSource}end}
local assetApi=create(assetGame,function(module)return module.Data end)
local categoryById={};for _,entry in ipairs(assetApi.list())do categoryById[entry.id]=entry.category end
assert(categoryById.Fragile_G_2023=='season1' and categoryById.Gingerscythe=='holiday' and categoryById.ClassicItem=='classic','Live database fields classify separately without excluding items')
local equippedResult=assetApi.equip('Fragile_G_2023','Gun')
assert(weaponHandle.MeshId=='asset-mesh'and weaponHandle.TextureID=='asset-texture','ItemID asset visibly changes the actual native weapon mesh and texture')
assert(assetScript.destroyed,'Asset scripts are removed before use')
assert(assetApi.getEquipped().Gun=='Fragile_G_2023','Database key remains the item identity; ItemID is its asset source')
assetApi.equip('Fragile_G_2023','Gun');assert(assetLoads==1,'Selected asset is cached rather than downloaded on every reapply')
assetApi.restore();assert(weaponHandle.MeshId=='original-mesh'and weaponHandle.TextureID=='original-texture','ItemID skin restores actual original weapon appearance')
-- MM2 may use a Part/SpecialMesh holster even when the downloaded item is a MeshPart.
assetSource.Size={X=2,Y=4,Z=2};assetSource.MeshSize={X=4,Y=4,Z=4}
Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end};Enum={MeshType={FileMesh='FileMesh'}}
local oldScale={X=1,Y=1,Z=1}
local displayMesh=node('Mesh','SpecialMesh');displayMesh.MeshId='old-display';displayMesh.TextureId='old-display-texture';displayMesh.Scale=oldScale;displayMesh.MeshType='old-type'
local directDisplay=node('GunDisplay','Part',{displayMesh})
directDisplay.IsA=function(_,c)return c=='BasePart'or c=='Part'end
assetPlayer.Character=node('Character','Model',{directDisplay})
assetApi.equip('Fragile_G_2023','Gun')
assert(displayMesh.MeshId=='asset-mesh'and displayMesh.TextureId=='asset-texture'and displayMesh.Scale.X==0.5 and displayMesh.Scale.Y==1,'ItemID MeshPart skins fit the existing native SpecialMesh display')
assetApi.restore();assert(displayMesh.MeshId=='old-display'and displayMesh.Scale==oldScale and displayMesh.MeshType=='old-type','Part display restores exact original geometry and scale')
assetApi.destroy();assert(assetSource.destroyed,'Detached loaded assets are destroyed when the hub closes')
print('Live MM2 ItemID loading, visible equip, script stripping, categories and restoration passed.')
