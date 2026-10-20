-- Mocked relay/Roblox check for game_browser_sync.lua. Run with lupa (see parent command).
local function color(r,g,b)return {R=r/255,G=g/255,B=b/255}end
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
local body={HeadColor3=color(255,0,0),TorsoColor3=color(0,255,0),LeftArmColor3=color(0,0,255),RightArmColor3=color(255,255,0),LeftLegColor3=color(255,0,255),RightLegColor3=color(0,255,255)}
local character={BodyColors=body,Head={Color=color(255,0,0)},UpperTorso={Color=color(0,255,0)}}
function character:FindFirstChildOfClass(k)return k=="BodyColors" and body or k=="Humanoid" and self.humanoid end
local desc={Shirt=101,Pants=202,Head=301,Face=302,Torso=303,LeftArm=304,RightArm=305,LeftLeg=306,RightLeg=307,GraphicTShirt=308,HeightScale=1,WidthScale=1,DepthScale=1,HeadScale=1,BodyTypeScale=0,ProportionScale=0}
function desc:GetAccessories()return {{AssetId=11,Name="Original Hat"}} end
for _,property in ipairs({"ClimbAnimation","FallAnimation","IdleAnimation","JumpAnimation","RunAnimation","SwimAnimation","WalkAnimation"})do desc[property]=0 end
setmetatable(desc,{__index=function(_,property)error(property.." is not a valid member of HumanoidDescription")end})
local humanoid={Health=100,RigType={Name="R15"}}
function humanoid:GetAppliedDescription()return desc end
humanoid.Parent=character;character.humanoid=humanoid
local player={UserId=7,Character=character}
local localHats={{key=1,id=12,name="Local Hat"}}
local gearEntry=nil
local settings={accessories={12},hideOriginals=false,colors={},bodyParts={},body="Blocky",face=302}
local avatar={}
local bodyCalls={}
local faceCalls={}
function avatar.getSettings()return settings end
function avatar.listAccessories()local entries={};for i,entry in ipairs(localHats)do entries[i]=entry end;return entries end
function avatar.listGear()return gearEntry and {gearEntry} or {} end
function avatar.equipGear(id)gearEntry={id=id,name="Gear"} end
function avatar.removeGear()gearEntry=nil end
function avatar.removeAccessory(key)for i,v in ipairs(localHats)do if v.key==key then table.remove(localHats,i)end end end
function avatar.equipAccessory(id)assert(id~=11,"an already worn original cannot be downloaded again");localHats[#localHats+1]={key=id,id=id,name="Added"}end
function avatar.clearAccessories()localHats={}end
function avatar.removeCurrentAccessories()settings.hideOriginals=true end
function avatar.applyBodyPart(region,id)bodyCalls[#bodyCalls+1]={region,id};settings.bodyParts[region]=id end
function avatar.restoreBodyPart(region)bodyCalls[#bodyCalls+1]={region,"restore"};settings.bodyParts[region]=nil end
function avatar.applyFace(id)faceCalls[#faceCalls+1]={"apply",id};settings.face=id end
function avatar.restoreFace()faceCalls[#faceCalls+1]={"restore"};settings.face=302 end
local clothes={Shirt=101,Pants=202};local clothing={}
function clothing.getSettings()return clothes end
function clothing.equipShirt(id)clothes.Shirt=id end
function clothing.equipPants(id)clothes.Pants=id end
function clothing.removeShirt()clothes.Shirt=0 end
function clothing.removePants()clothes.Pants=0 end
local http={}
function http:JSONEncode(v)return v end
function http:JSONDecode(v)return v end
local extraTypes={};local productCalls={}
game={GetService=function(_,name)if name=="HttpService"then return http end;if name=="MarketplaceService"then return {GetProductInfo=function(_,id)productCalls[id]=(productCalls[id] or 0)+1;return {Name="Asset"..id,AssetTypeId=extraTypes[id] or ({[101]=11,[202]=12,[301]=17,[302]=18,[303]=27,[304]=29,[305]=28,[306]=30,[307]=31,[308]=2})[id] or 8}end}end end}
Enum={InfoType={Asset={}},HumanoidRigType={R6={},R15={}}};Color3={fromRGB=function(r,g,b)return color(r,g,b)end};humanoid.RigType=Enum.HumanoidRigType.R15
local posted;local command={version=1,userId="7",revision=1,definition={assets={},bodyColors={headColor="ff0000",torsoColor="00ff00",leftArmColor="0000ff",rightArmColor="ffff00",leftLegColor="ff00ff",rightLegColor="00ffff"},scales={},playerAvatarType={playerAvatarType="R15"}},items={{id=11,name="Original Hat",itemType="Asset",assetType=8},{id=13,name="New Hat",itemType="Asset",assetType=8},{id=101,name="Shirt",itemType="Asset",assetType=11}}}
function request(o)if o.Method=="GET" and o.Url:find("status")then return {StatusCode=200,Body={version=1,connected=true}}end;if o.Method=="GET"then return {StatusCode=200,Body=command}end;posted=o.Body;return {StatusCode=200,Body={}}end
local jobs={};task={spawn=function(f)jobs[#jobs+1]=f end,wait=function()end}
local create=dofile("game_browser_sync.lua");local sync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end)
sync.connect(string.rep("a",32));local snapshot=sync.publish();local hasGraphic=false;for _,a in ipairs(snapshot.definition.assets)do if a.id==308 then hasGraphic=true end end;assert(snapshot.definition.assets[1].id==12,"local hat is published");assert(hasGraphic,"graphic shirt is published")
extraTypes[1900]=19;gearEntry={id=1900,name="Blaster"};snapshot=sync.publish();local hasGear=false;for _,item in ipairs(snapshot.items)do if item.id==1900 and item.assetType==19 then hasGear=true end end;assert(hasGear,"hub gear is published as asset type 19");gearEntry=nil
task.wait=function()sync.disconnect()end
jobs[1]();assert(#localHats==1 and localHats[1].id==13,"new hat equips without reloading an unchanged unavailable original")
assert((productCalls[13] or 0)==0,"browser hat metadata avoids a marketplace lookup while applying")
local keptOriginal=false;for _,item in ipairs(posted.items)do if item.id==11 then keptOriginal=true end end;assert(keptOriginal,"unchanged original remains visible")
for _,item in ipairs(posted.items)do assert(item.id~=12,"same sync cycle publishes the completed removal instead of the previous outfit")end
command.revision=2;command.items={{id=13,name="New Hat",itemType="Asset",assetType=8}};jobs[1]=nil;task.wait=function()sync.disconnect()end;sync.connect(string.rep("a",32));jobs[1]();assert(#localHats==1 and localHats[1].id==13,"command removes an original hat without duplication")
assert(clothes.Shirt==0 and clothes.Pants==0,"removed classic clothing stays removed")
settings.body=nil;settings.bodyParts={Head="https://www.roblox.com/catalog/999/Test"};clothes.Shirt=nil
local preserved=sync.connect(string.rep("a",32));local captured=sync.publish();local ids={};for _,asset in ipairs(captured.definition.assets)do ids[asset.id]=true end
assert(ids[999] and not ids[301] and ids[302] and ids[306] and ids[307],"body overrides, face and correct legs preserved")
command.revision=3;command.items={};jobs[1]=nil;sync.disconnect();sync.connect(string.rep("a",32));jobs[1]();assert(clothes.Shirt==0,"original shirt removed even without saved override")
-- One failing download must not block other new hats; retry only the missing hat.
local normalEquip=avatar.equipAccessory;local failOnce=true
avatar.equipAccessory=function(id)if id==20 and failOnce then failOnce=false;error("temporary asset error")end;normalEquip(id)end
command.revision=4;command.items={{id=20,name="Retry hat",itemType="Asset",assetType=8},{id=21,name="Working hat",itemType="Asset",assetType=8}}
jobs={};sync.connect(string.rep("a",32));jobs[1]()
assert(#localHats==1 and localHats[1].id==21,"one failed asset does not prevent another new hat equipping")
jobs={};sync.connect(string.rep("a",32));jobs[1]()
assert(#localHats==2,"retry adds the missing hat without duplicating the successful hat")
sync.destroy()
-- A saved code reconnects without clicking Connect, even if the helper starts late.
isfile=function()return true end;readfile=function()return string.rep("a",32)end;writefile=function()end
local attempts,instance=0,"first"
request=function(o)
    if o.Url:find("status") then
        attempts=attempts+1
        if attempts==1 then error("helper not started yet")end
        return {StatusCode=200,Body={version=1,connected=true,instanceId=instance}}
    end
    if o.Method=="GET"then return {StatusCode=200,Body=command}end
    return {StatusCode=200,Body={}}
end
jobs={};local restored=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end)
task.wait=function()end
assert(#jobs==1,"saved connection schedules automatic reconnect")
jobs[1]();assert(restored.isConnected() and attempts==2,"saved connection retries until the helper returns")
command.revision=1;command.items={{id=13,name="First",itemType="Asset",assetType=8}}
local cycles=0
task.wait=function()
    cycles=cycles+1
    if cycles==1 then instance="second";command.items={{id=14,name="After restart",itemType="Asset",assetType=8}}
    else restored.disconnect()end
end
jobs[2]();assert(#localHats==1 and localHats[1].id==14,"helper restart resets revisions and accepts the new outfit")
restored.destroy();print("Game browser sync saved reconnect, delayed helper and restart recovery passed.")

-- End-to-end relay command dispatch for every supported wearable category.
local relayRequest=request;request=function(o)if o.Method=="POST"then posted=o.Body end;return relayRequest(o)end
isfile=function()return false end
function clothing.equipTShirt(id)clothes.ShirtGraphic=id end
function clothing.removeTShirt()clothes.ShirtGraphic=0 end
local movementSettings={}
local movementApi={getSettings=function()return movementSettings end,equipAssets=function(items)movementSettings={assets=items}end,restore=function()movementSettings={}end}
local categories={2,11,12,19,8,41,42,43,44,45,46,47,64,65,66,67,68,69,70,71,72,76,77,48,50,51,52,53,54,55,56}
local allItems={}
for _,assetType in ipairs(categories)do local id=10000+assetType;extraTypes[id]=assetType;allItems[#allItems+1]={id=id,name="Category "..assetType,itemType="Asset",assetType=assetType}end
jobs={};local fullSync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end,function()return movementApi end)
command.revision=10;command.items=allItems
task.wait=function()fullSync.disconnect()end
fullSync.connect(string.rep("a",32));jobs[1]()
local publishedTypes={};for _,item in ipairs(posted.items)do publishedTypes[item.id]=item.assetType end
for _,assetType in ipairs(categories)do assert(publishedTypes[10000+assetType]==assetType,"equipped category is confirmed by game snapshot: "..assetType)end
command.revision=11;command.items={};jobs={};fullSync.connect(string.rep("a",32));jobs[1]()
assert(#localHats==0 and clothes.Shirt==0 and clothes.Pants==0 and clothes.ShirtGraphic==0 and not movementSettings.assets,"Remove clears accessories, all classic clothes and movement components")
fullSync.destroy()
print("Game relay all accessory regions, layered clothes, classic T-shirts, shirts/pants and animation component dispatch passed.")

-- Browser names sync independently of avatar snapshots, including retries and disconnect restore.
local nameState={version=1,userId="7",enabled=true,name="Alpha_7"}
local nameEvents={}
local oldRequest=request
request=function(o)
    if o.Url:find("/v1/names/") then return {StatusCode=200,Body=nameState} end
    if o.Url:find("status") then return {StatusCode=200,Body={version=1,connected=true,instanceId="names"}} end
    return {StatusCode=404,Body={}}
end
local nameApi={
    set=function(username,displayName)nameEvents[#nameEvents+1]={"set",username,displayName}end,
    setEnabled=function(enabled)nameEvents[#nameEvents+1]={"enabled",enabled}end,
}
local function makeNameSync()
    return create(player,function()return avatar end,function()return clothing end,function()return true end,function()end,nil,function()return nameApi end)
end
local savedCharacter=player.Character;player.Character=nil
local nameSync=makeNameSync();jobs={};task.wait=function()nameSync.disconnect()end
nameSync.connect(string.rep("a",32));jobs[1]();assert(#nameEvents==2 and nameEvents[1][1]=="set" and nameEvents[1][2]=="Alpha_7","browser name applies without avatar snapshot")
nameState={version=1,userId="7",enabled=true,name="Beta_7"};nameEvents={};nameSync=makeNameSync();jobs={};nameSync.connect(string.rep("a",32));jobs[1]();assert(#nameEvents==2 and nameEvents[1][2]=="Beta_7","browser name changes are applied")
nameState={version=1,userId="7",enabled=false,name=""};nameEvents={};nameSync=makeNameSync();jobs={};nameSync.connect(string.rep("a",32));jobs[1]();assert(nameEvents[#nameEvents][1]=="enabled" and nameEvents[#nameEvents][2]==false,"disabled browser name restores locally")
nameEvents={};nameSync.disconnect();assert(nameEvents[#nameEvents][1]=="enabled" and nameEvents[#nameEvents][2]==false,"disconnect restores local name")
request=oldRequest
player.Character=savedCharacter
print("Game browser name sync applies, changes, disables and restores without avatar snapshots.")

-- Native views follow mode even without a custom name, and restore on disconnect.
local viewEvents={}
nameState={version=1,userId="7",enabled=true,name=""}
request=function(o)
 if o.Url:find("/v1/names/")then return {StatusCode=200,Body=nameState}end
 if o.Url:find("status")then return {StatusCode=200,Body={version=1,connected=true}}end
 return {StatusCode=200,Body={}}
end
jobs={}
local viewsSync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end,nil,function()return nameApi end,function()return {update=function(value)viewEvents[#viewEvents+1]=value end}end)
task.wait=function()viewsSync.disconnect()end
viewsSync.connect(string.rep("a",32));jobs[1]()
assert(viewEvents[1].enabled==true and viewEvents[1].name=="" and not viewEvents[1].snapshot,"mode hides account previews before outfit loading")
assert(viewEvents[2].enabled==true and viewEvents[2].snapshot,"effective outfit is delivered after the loading gate")
assert(viewEvents[#viewEvents].enabled==false,"disconnect restores native views")
print("Native view mode, effective outfit and disconnect forwarding passed.")

-- Browser body selections apply only changed regions and restore browser-owned removals.
request=function(o)if o.Url:find("status")then return {StatusCode=200,Body={version=1,connected=true}}end;if o.Method=="GET"then return {StatusCode=200,Body=command}end;posted=o.Body;return {StatusCode=200,Body={}}end
local bodySync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end)
command.revision=20;command.items={{id=999,name="Head",itemType="Asset",assetType=17},{id=303,name="Torso",itemType="Asset",assetType=27},{id=305,name="RightArm",itemType="Asset",assetType=28},{id=304,name="LeftArm",itemType="Asset",assetType=29},{id=9999,name="LeftLeg",itemType="Asset",assetType=30},{id=307,name="RightLeg",itemType="Asset",assetType=31},{id=404,name="Face",itemType="Asset",assetType=18}}
bodyCalls={};faceCalls={};jobs={};task.wait=function()bodySync.disconnect()end;bodySync.connect(string.rep("a",32));jobs[1]();assert(#bodyCalls==1 and bodyCalls[1][1]=="LeftLeg","browser body selection applies only changed regions");assert(faceCalls[1][1]=="apply" and faceCalls[1][2]==404,"browser face applies through avatar API")
local publishedFace;for _,item in ipairs(posted.items or {})do if item.assetType==18 then publishedFace=item.id end end;assert(publishedFace==404,"snapshot publishes the selected face")
local beforeRemoval=#bodyCalls
command.revision=21;command.items={{id=999,name="Head",itemType="Asset",assetType=17},{id=303,name="Torso",itemType="Asset",assetType=27},{id=305,name="RightArm",itemType="Asset",assetType=28},{id=304,name="LeftArm",itemType="Asset",assetType=29},{id=307,name="RightLeg",itemType="Asset",assetType=31}}
jobs={};bodySync.connect(string.rep("a",32));jobs[1]();assert(#bodyCalls>beforeRemoval and bodyCalls[#bodyCalls][1]=="LeftLeg" and bodyCalls[#bodyCalls][2]=="restore","removed browser body part restores through avatar API");assert(faceCalls[#faceCalls][1]=="restore","removed browser face restores through avatar API")
bodySync.destroy();print("Game browser body selections apply and restore selectively.")

-- A saved character replaces its skin colors, clothing and accessories in one command,
-- including the # prefix emitted by the browser preview.
local skinCalls={}
function avatar.setSkin(value,region)
    skinCalls[#skinCalls+1]=region
    body[region.."Color3"]=value
end
localHats={{key=88,id=88,name="Old Hat"}};clothes.Shirt=111;clothes.Pants=222
extraTypes[23]=8;extraTypes[333]=11;extraTypes[444]=12
command.revision=22
command.definition.bodyColors={headColor="#123456",torsoColor="#654321",leftArmColor="#112233",rightArmColor="#aabbcc",leftLegColor="#ddee00",rightLegColor="#00ff11"}
command.items={{id=23,name="Saved Hat",itemType="Asset",assetType=8},{id=333,name="Saved Shirt",itemType="Asset",assetType=11},{id=444,name="Saved Pants",itemType="Asset",assetType=12}}
local colorSync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end)
jobs={};task.wait=function()colorSync.disconnect()end
colorSync.connect(string.rep("a",32));jobs[1]()
assert(#skinCalls==6,"saved outfit applies all changed body colors")
assert(#localHats==1 and localHats[1].id==23,"saved outfit replaces the previous accessory")
assert(clothes.Shirt==333 and clothes.Pants==444,"saved outfit replaces the previous clothes")
assert(posted.definition.bodyColors.headColor=="123456","game confirms the new outfit color instead of the old one")
colorSync.destroy()
print("Saved character body colors replace the previous outfit colors.")

-- WebSocket auth, pushed outfit/mode state, snapshot publishing and disconnect.
local sent,closed={},false
local messageHandler,closeHandler
local ws={OnMessage={Connect=function(_,fn)messageHandler=fn end},OnClose={Connect=function(_,fn)closeHandler=fn end}}
function ws:Close()closed=true;if closeHandler then closeHandler()end end
function ws:Send(value)
    sent[#sent+1]=value
    if value.type=="auth" then
        messageHandler({type="ready",instanceId="ws-test"})
        messageHandler({type="state",channel="names",value={version=1,userId="7",enabled=true,name="Socket_7"}})
        command.revision=40;command.items={{id=23,name="Pushed Hat",itemType="Asset",assetType=8}}
        messageHandler({type="state",channel="browser",value=command})
        messageHandler({type="state",channel="image",value={version=1,userId="7",definition=command.definition,imageUrl="https://tr.rbxcdn.com/Test-Png/420/420/Avatar/Png/noFilter"}})
    end
end
WebSocket={connect=function(url)assert(url=="ws://127.0.0.1:38261/v1/socket");return ws end}
request=function(o)
    assert(o.Url:find("/v1/status"),"WebSocket ready avoids HTTP polling")
    return {StatusCode=200,Body={version=1,instanceId="ws-test"}}
end
local pngWritten=false
getcustomasset=function(path)assert(path:match("larpblox%-avatar%-7%-%d+.png"));return "rbxasset://custom-avatar.png"end
game.HttpGet=function()return "\137PNG\r\n\26\nbytes"end
writefile=function(path,bytes)if path:match("%.png$")then pngWritten=bytes:sub(1,8)=="\137PNG\r\n\26\n"end end
viewEvents={}
jobs={};local socketSync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end,nil,function()return nameApi end,function()return {update=function(value)viewEvents[#viewEvents+1]=value end}end)
local socketStatus
task.wait=function()
    for i=2,#jobs do jobs[i]()end
    socketStatus=socketSync.status()
    local received=false;for _,value in ipairs(viewEvents)do if value.image=="rbxasset://custom-avatar.png"then received=true end end
    assert(pngWritten and received,"browser PNG loads as a custom asset and forwards to native views")
    socketSync.disconnect()
end
socketSync.connect(string.rep("a",32));jobs[1]()
assert(sent[1].type=="auth" and sent[1].role=="game" and sent[1].userId=="7","WebSocket authenticates account and role")
assert(socketStatus=="Browser connected via WebSocket.","WebSocket reports active transport")
assert(#localHats==1 and localHats[1].id==23,"pushed command applies outfit")
local published=false;for _,value in ipairs(sent)do if value.type=="publish" and value.channel=="game" then published=true end end
assert(published and closed,"game snapshot publishes over socket and disconnect closes it")
WebSocket=nil
print("WebSocket authentication, pushed outfit, snapshot and disconnect passed.")
