-- Call the chat presentation callbacks locally; never send a public message.
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local player={UserId=123,Name='OriginalUser',DisplayName='Original Display',CharacterAdded=signal()}
local players={GetPlayers=function()return {player}end,PlayerAdded=signal(),PlayerRemoving=signal()}
local originalProperties
local calls=0
local function previous()
 calls=calls+1
 return originalProperties
end
local config={DeriveNewMessageProperties=function()return {}end}
local service={OnIncomingMessage=previous,OnChatWindowAdded=previous,FindFirstChildOfClass=function()return config end}
game={GetService=function(_,name)
 if name=='Players'then return players end
 if name=='TextChatService'then return service end
end}
Instance={new=function()return {}end}
local create=dofile('local_names.lua')
local api=create(player)
api.set('Alias_User','Alias < Display')
for _,member in ipairs({'OnIncomingMessage','OnChatWindowAdded'})do
 local message={TextSource={UserId=123},PrefixText='<font color="#fff">Original Display</font>:',Text='message stays untouched'}
 originalProperties={Text='formatted message',Metadata='preserve game formatting'}
 local before=calls
 local result=service[member](message)
 assert(result==originalProperties and calls==before+1,'preserve the existing callback and its returned object')
 assert(result.PrefixText=='<font color="#fff">Alias &lt; Display</font>:','sender prefix without a UI Name must format correctly')
 assert(message.Text=='message stays untouched' and message.PrefixText:find('Original Display',1,true),'never mutate chat content or the original message')
 originalProperties=nil
 result=service[member](message)
 assert(result.PrefixText=='<font color="#fff">Alias &lt; Display</font>:','derive properties when no previous callback result exists')
 originalProperties={Text='OriginalUser joined'}
 result=service[member]({Text='OriginalUser joined'})
 assert(result.Text=='Alias_User joined','local system notifications still format')
 originalProperties=setmetatable({}, {__index=function()error('unavailable formatting property')end})
 local ok,value=pcall(service[member],message)
 assert(ok and value==originalProperties,'a Larp formatting failure must return native properties without breaking chat')
 assert(service[member](nil)==originalProperties,'missing presentation messages must pass through')
end
api.setEnabled(false)
originalProperties={PrefixText='Original Display:'}
assert(service.OnChatWindowAdded({TextSource={UserId=123},PrefixText='Original Display:'})==originalProperties,'disabled names retain native chat')
api.destroy()
assert(service.OnIncomingMessage==previous and service.OnChatWindowAdded==previous,'destroy restores callback ownership')
print('PASS: sender prefixes, both chat callbacks, native formatting, system messages, failure isolation and cleanup')
