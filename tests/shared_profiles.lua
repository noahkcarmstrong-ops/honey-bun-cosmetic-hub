local calls=0
local source={players={{version=1,userId='2',snapshot={version=1,userId='2',items={},definition={assets={{id=20},{id=21}}}},name={enabled=true,username='Alias',displayName='Alias'}},
 {version=1,userId='999',snapshot={version=1,items={},definition={assets={{id=99}}}}}}}
game={GetService=function(_,name)
 if name=='HttpService'then return {JSONDecode=function()return source end}end
 if name=='AvatarEditorService'then return {GetBatchItemDetailsAsync=function(_,ids)calls=calls+1;local result={};for _,id in ipairs(ids)do result[#result+1]={Id=id,Name='Asset '..id,AssetType='Hat'}end;return result end}end
end,HttpGet=function(_,url)assert(url=='https://larp.3xjn.dev/v1/profiles?userIds=2');return 'profiles'end}
Instance={new=function()return {Fire=function()end,Destroy=function()end}end}
Enum={AvatarItemType={Asset='Asset'},AvatarAssetType={Hat={Value=8}}};task={spawn=function(fn)fn()end}
local fetch=dofile('shared_profiles.lua')
local records=fetch({'2'})
assert(#records==1 and #records[1].snapshot.items==2 and calls==1,'legacy profiles gain metadata in one batch without including unrequested users')
records=fetch({'2'})
assert(calls==1,'complete profiles need no metadata lookup')
source.players[1].snapshot.items={};records=fetch({'2'})
assert(calls==1 and #records[1].snapshot.items==2,'legacy metadata is cached for subsequent lifecycle lookups')
print('PASS: saved profiles, request scoping, complete item metadata and cached legacy migration')
