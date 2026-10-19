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
emoteModule.Data={Wave={Name='Wave',Type='Emote',AnimationId=12345},Dance={Name='Dance',AnimationId='67890'}}
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
