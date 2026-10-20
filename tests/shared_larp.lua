local calls={}
local localPlayer={UserId=1,Name="Self",DisplayName="Self"}
local peer={UserId=2,Name="Other",DisplayName="Other"}
local Players={GetPlayerByUserId=function(_,id)return id==2 and peer or nil end}
local peerRecord={version=1,userId="2",name={enabled=true,username="LarpTwo",displayName="Larp Two"},snapshot={
    version=1,userId="2",definition={assets={},bodyColors={headColor="ff0000",torsoColor="00ff00",leftArmColor="0000ff",rightArmColor="ffffff",leftLegColor="000000",rightLegColor="888888"},scales={},playerAvatarType={playerAvatarType="R15"}},
    items={{id=200,name="Hat",assetType=8},{id=300,name="Shirt",assetType=11},{id=400,name="Head",assetType=17}},
}}
local http={JSONEncode=function(_,value)return value end,JSONDecode=function(_,value)return value end}
Color3={fromRGB=function(r,g,b)return {r=r,g=g,b=b}end}
game={PlaceId=123,JobId="abc-123",GetService=function(_,name)if name=="Players"then return Players end;if name=="HttpService"then return http end end}
request=function(value)
    calls[#calls+1]=value
    if value.Method=="GET"then return {StatusCode=200,Body={players={peerRecord}}}end
    return {StatusCode=200,Body={ok=true}}
end
local jobs={}
task={spawn=function(fn)jobs[#jobs+1]=fn end,wait=function()end}
local destroyed=0
local function api()
    return {
        restore=function()calls[#calls+1]={Method="RESTORE"}end,
        destroy=function()destroyed=destroyed+1 end,
        removeCurrentAccessories=function()calls[#calls+1]={Method="HIDE_ACCESSORIES"}end,
        equipAccessory=function(id)calls[#calls+1]={Method="ACCESSORY",Id=id}end,
        applyBodyPart=function(region,id)calls[#calls+1]={Method="BODY",Region=region,Id=id}end,
        applyFace=function(id)calls[#calls+1]={Method="FACE",Id=id}end,
        setSkin=function(_,region)calls[#calls+1]={Method="SKIN",Region=region}end,
        equipGear=function(id)calls[#calls+1]={Method="GEAR",Id=id}end,
    }
end
local function clothes()
    return {restore=function()end,destroy=function()destroyed=destroyed+1 end,equipTShirt=function()end,equipShirt=function()calls[#calls+1]={Method="SHIRT"}end,equipPants=function()end,removeTShirt=function()end,removeShirt=function()end,removePants=function()end}
end
local function animations()
    return {restore=function()end,destroy=function()destroyed=destroyed+1 end,equipAssets=function()calls[#calls+1]={Method="ANIMATIONS"}end}
end
local names={restore=function()end,destroy=function()destroyed=destroyed+1 end,set=function(username,displayName)calls[#calls+1]={Method="NAME",Username=username,DisplayName=displayName}end}
local module=dofile("shared_larp.lua")
local apiInstance
local nameSettings={enabled=false,username="",displayName=""}
apiInstance=module(localPlayer,function()return {version=1,userId="1",definition={assets={},bodyColors={}},items={}}end,function()return nameSettings end,
    function()return api()end,function()return clothes()end,function()return animations()end,function()return names end,function()return true end,function()end)
task.wait=function()apiInstance.setEnabled(false)end
apiInstance.setEnabled(true)
assert(#jobs==1,"enabling sharing starts a relay poll loop")
jobs[1]()
local function called(method)for _,entry in ipairs(calls)do if entry.Method==method then return true end end;return false end
assert(called("PUT"),"the local Larp record is published")
assert(called("GET"),"the current Roblox server roster is polled")
assert(called("ACCESSORY") and called("BODY") and called("SHIRT"),"peer appearance items are applied locally")
assert(called("SKIN") and called("NAME"),"peer colors and Larp name are applied locally")
assert(called("DELETE"),"disabling sharing removes the local relay record")
assert(destroyed==4,"disabling sharing restores and destroys the peer overlay APIs")
print("Shared Larp opt-in publish, peer rendering, cleanup and relay removal passed.")

for _,fixture in ipairs({
    {value={enabled=true,username="",displayName=""},enabled=false},
    {value={enabled=true,username="Valid_Name",displayName=""},enabled=false},
    {value={enabled=true,username="Invalid Name",displayName="Display"},enabled=false},
    {value={enabled=true,username="Valid_Name",displayName="Display"},enabled=true},
})do
    nameSettings=fixture.value;calls={};jobs={}
    apiInstance.setEnabled(true);jobs[1]()
    local published
    for _,entry in ipairs(calls)do if entry.Method=="PUT"then published=entry.Body end end
    assert(published and published.snapshot,"avatar still publishes without a custom name")
    assert(published.name.enabled==fixture.enabled,"only valid custom names are shared")
    if not fixture.enabled then
        assert(published.name.username=="" and published.name.displayName=="","disabled name has empty fields")
    else
        assert(published.name.username==fixture.value.username,"valid custom name is preserved")
    end
end
print("Empty or invalid custom names do not block avatar sharing.")
