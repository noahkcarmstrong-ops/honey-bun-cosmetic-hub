math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
local calls,infoCalls,destroyed=0,0,0
local description={HeightScale=1.05,WidthScale=.8,DepthScale=.9,HeadScale=1,BodyTypeScale=.2,ProportionScale=.4,Head=201,Shirt=202}
for _,part in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do description[part.."Color"]={R=1,G=.5,B=0}end
function description:GetAccessories()return {{AssetId=203,IsLayered=true,Order=4,Puffiness=.6}}end
function description:Destroy()destroyed=destroyed+1 end
local bad=false
local players={
 GetHumanoidDescriptionFromUserIdAsync=function(_,id)assert(id==99);calls=calls+1;return description end,
 GetCharacterAppearanceInfoAsync=function(_,id)
  assert(id==99);infoCalls=infoCalls+1
  if bad then error("Lookup unavailable")end
  return {playerAvatarType="R6",assets={{id=201,name="Head",assetType={id=79}},{id=202,name="Shirt",assetType={id=11}},{id=203,name="Coat",assetType={id=67}}}}
 end,
}
local lookup=dofile('avatar_lookup.lua')(players)
local first=lookup(99,7)
assert(first.userId=="7" and first.definition.playerAvatarType.playerAvatarType=="R6")
assert(first.definition.bodyColors.headColor=="ff8000" and first.definition.scales.width==.8)
assert(first.definition.assets[3].meta.order==4 and first.definition.assets[3].meta.puffiness==.6)
assert(first.items[1].assetType==79 and #first.items==3 and destroyed==1)
assert(lookup(99,8).userId=="8" and calls==1 and infoCalls==1,"cache reuses lookup but binds result to requesting account")
assert(not pcall(lookup,-1,7))
local failing=dofile('avatar_lookup.lua')(players);bad=true
assert(not pcall(failing,99,7) and destroyed==2,"failed metadata lookup releases the description")
bad=false;assert(pcall(failing,99,7),"a failure must not leave the lookup locked")
description:GetAccessories() -- fixture remains independent of any in-server character
description.GetAccessories=function()return {{AssetId=999}}end
assert(not pcall(dofile('avatar_lookup.lua')(players),99,7),"mixed account snapshots must not silently drop missing items")
print('PASS: account ID lookup, R6, colors, scales, layered metadata, cache, failure cleanup, and changed-outfit rejection.')
