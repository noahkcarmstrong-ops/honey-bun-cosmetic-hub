-- Small Roblox-shaped fixture for the local name override.
local function signal()
    local s = {listeners = {}}
    function s:Connect(fn) local c={fn=fn,Connected=true};self.listeners[#self.listeners+1]=c;return {Disconnect=function() c.Connected=false end} end
    function s:Fire(...) for _,c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
    return s
end
local function node(class,name)
    local x={ClassName=class,Name=name,children={},signals={},attrs={},DescendantAdded=signal()}
    setmetatable(x,{__index=function(t,k) if k=="Parent" then return rawget(t,"parent") end end,__newindex=function(t,k,v)
        if k=="Parent" then local old=rawget(t,"parent");if old then for i,c in ipairs(old.children) do if c==t then table.remove(old.children,i)break end end end;rawset(t,"parent",v);if v then v.children[#v.children+1]=t end else rawset(t,k,v) end
    end})
    function x:IsA(k) return k==self.ClassName or (k=="GuiObject" and (self.ClassName=="TextLabel" or self.ClassName=="TextButton")) end
    function x:GetChildren() return self.children end
    function x:FindFirstChildOfClass(k) for _,c in ipairs(self.children) do if c:IsA(k) then return c end end end
    function x:GetDescendants() local out={};local function walk(v) for _,c in ipairs(v.children) do out[#out+1]=c;walk(c) end end;walk(self);return out end
    function x:FindFirstChild(n,recurse) for _,c in ipairs(self.children) do if c.Name==n then return c end;if recurse then local f=c:FindFirstChild(n,true);if f then return f end end end end
    function x:GetPropertyChangedSignal(k) self.signals[k]=self.signals[k] or signal();return self.signals[k] end
    function x:GetAttribute(k) return self.attrs[k] end;function x:SetAttribute(k,v) self.attrs[k]=v end
    function x:Destroy() self.Parent=nil end
    return x
end
local http={JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end}
local core=node("CoreGui","CoreGui");local gui=node("PlayerGui","PlayerGui");local character=node("Model","Character");local humanoid=node("Humanoid","Humanoid");humanoid.DisplayName="Original Display";humanoid.Parent=character
local added=signal();local player={Name="OriginalUser",DisplayName="Original Display",UserId=123,Character=character,CharacterAdded=added}
function player:FindFirstChildOfClass(k) return k=="PlayerGui" and gui end
local chatPlayers={player}
local playersService={GetPlayers=function()return chatPlayers end}
game={Workspace=node("Workspace","Workspace"),GetService=function(_,name)if name=="Players"then return playersService end;if name=="HttpService"then return http end;if name=="CoreGui"then return core end end}
local make=dofile("local_names.lua")
local row=node("Frame","PlayerEntry_123");row.Parent=core;local label=node("TextLabel","Name");label.Text="OriginalUser";label.RichText=true;label.Parent=row
local other=node("Frame","999");other.Parent=core;local otherLabel=node("TextLabel","Name");otherLabel.Text="OriginalUser";otherLabel.Parent=other
local native=node("TextLabel","PlayerName");native.Text="Combined Service Name";native.Parent=row
local shared=node("TextLabel","PlayerName");shared.Text="Original Display";shared.Parent=other
local list=node("Frame","PlayerList");list.Parent=core
local title=node("Frame","TitlePlayer");title.Parent=list
local titleName=node("TextLabel","PlayerName");titleName.Text="Mobile Combined Name";titleName.Parent=title
local people=node("Frame","People");people.Parent=core
local menuRow=node("Frame","UnidentifiedReactRow");menuRow.Parent=people
local menuDisplay=node("TextLabel","Text");menuDisplay.Text="Original Display";menuDisplay.Parent=menuRow
local menuUser=node("TextLabel","Text");menuUser.Text="@OriginalUser";menuUser.Parent=menuRow
local otherRow=node("Frame","OtherReactRow");otherRow.Parent=people
local otherDisplay=node("TextLabel","Text");otherDisplay.Text="Original Display";otherDisplay.Parent=otherRow
local otherUser=node("TextLabel","Text");otherUser.Text="@OtherUser";otherUser.Parent=otherRow
local chat=node("Frame","TextChatService");chat.Parent=core
local ownMessage=node("TextLabel","Message");ownMessage.RichText=true;ownMessage.Text="Original Display: oo la la";ownMessage.Parent=chat
local richMessage=node("TextLabel","RichMessage");richMessage.RichText=true;richMessage.Text='<font color="#fff">Original Display:</font> body mentions Original Display';richMessage.Parent=chat
local otherMessage=node("TextLabel","OtherMessage");otherMessage.Text="Other Display: Original Display in the body";otherMessage.Parent=chat
local systemMessage=node("TextLabel","SystemMessage");systemMessage.Text="System: Original Display";systemMessage.Parent=chat
local api=make(player,gui)
api.set("Local_User","Local Display")
assert(label.Text=="Local_User" and otherLabel.Text=="OriginalUser","only the local player's native row changes")
assert(menuDisplay.Text=="Local Display" and menuUser.Text=="@Local_User","People menu own display and username update without row ID")
assert(otherDisplay.Text=="Original Display" and otherUser.Text=="@OtherUser","People menu shared display name stays untouched")
assert(humanoid.DisplayName=="Local Display","humanoid display name changes locally")
assert(titleName.Text=="Local Display","native local mobile title row changes")
assert(native.Text=="Local Display" and shared.Text=="Original Display","native combined name changes only in own user-ID row")
assert(ownMessage.Text=="Local Display: oo la la","chat rewrites only the local sender prefix")
assert(richMessage.Text=='<font color="#fff">Local Display:</font> body mentions Original Display',"chat rich text preserves tags and body")
assert(otherMessage.Text=="Other Display: Original Display in the body" and systemMessage.Text=="System: Original Display","chat leaves other and system messages untouched")
local function message(parent,text,name,id)
 local object=node("TextLabel",name or "TextMessage");object.Text=text;object.RichText=true
 if id then object:SetAttribute("UserId",id) end
 object.Parent=parent;core.DescendantAdded:Fire(object);return object
end
local experience=node("Frame","ExperienceChat");experience.Parent=core
local split=message(experience,'<font color="#fff">Original Display</font>: unchanged Original Display')
assert(split.Text=='<font color="#fff">Local Display</font>: unchanged Original Display',"split rich sender preserves body and colors")
local foreign=message(experience,"Original Display: foreign",nil,999)
assert(foreign.Text=="Original Display: foreign","foreign sender ID vetoes a matching display name")
local aliasCollision=message(experience,"Local Display: another player's name")
assert(aliasCollision.Text=="Local Display: another player's name","the alias is never used to identify a new sender")
local bubble=node("Frame","BubbleChat");bubble.Parent=experience
local bubbleText=message(bubble,"Original Display: quoted message")
assert(bubbleText.Text=="Original Display: quoted message","bubble message bodies are never rewritten")
local system=message(experience,"Original Display: system text","SystemMessage")
assert(system.Text=="Original Display: system text","system text is not a sender")
local sender=message(experience,"Original Display","PrefixText")
assert(sender.Text=="Local Display","standalone sender prefixes update without message text")
local numbered=node("Frame","1");numbered.Parent=experience
assert(message(numbered,"Original Display: numbered row").Text=="Local Display: numbered row","numeric message indices are not user IDs")
chatPlayers={player,{Name="OtherUser",DisplayName="Original Display",UserId=999}}
local ambiguous=message(experience,"Original Display: ambiguous")
assert(ambiguous.Text=="Original Display: ambiguous","shared display names are not guessed")
local identified=message(experience,"Original Display: identified",nil,123)
assert(identified.Text=="Local Display: identified","explicit own sender ID resolves shared display names")
chatPlayers={player}
local recycled=message(experience,"Original Display: first")
recycled.Text="Other Display: next";recycled:GetPropertyChangedSignal("Text"):Fire()
assert(recycled.Text=="Other Display: next","recycled chat labels stop rewriting other senders")
local whitespace=message(experience,'<font face="Original Display"> Original Display </font>: body')
native.Text="Refreshed Service Name";native:GetPropertyChangedSignal("Text"):Fire()
assert(native.Text=="Local Display","native redraw reapplies")
local late=node("TextLabel","PlayerName");late.Text="";late.Parent=row;core.DescendantAdded:Fire(late)
late.Text="Original Display";late:GetPropertyChangedSignal("Text"):Fire()
assert(late.Text=="Local Display","text assigned after creation is replaced")
api.set("Other_User","A < B & 50%")
assert(native.Text=="A < B & 50%","plain names preserve literal characters")
assert(ownMessage.Text=="A &lt; B &amp; 50%: oo la la","chat prefix escapes rich-text characters")
assert(whitespace.Text=='<font face="Original Display"> A &lt; B &amp; 50% </font>: body',"percent aliases and whitespace preserve font attributes")
assert(aliasCollision.Text=="Local Display: another player's name","changing aliases never changes another sender")
label.Text='<font face="OriginalUser">Original Display</font>';label:GetPropertyChangedSignal("Text"):Fire()
assert(label.Text=='<font face="OriginalUser">A &lt; B &amp; 50%</font>',"RichText replacement preserves tag attributes and escapes the alias")
api.set("Local_User","Local Display")
label.Text="<font color=\"#fff\">OriginalUser</font>";label:GetPropertyChangedSignal("Text"):Fire()
assert(label.Text=="<font color=\"#fff\">Local_User</font>","RichText tags remain intact")
api.setEnabled(false)
assert(menuDisplay.Text=="Original Display" and menuUser.Text=="@OriginalUser","People menu restores original name")
assert(native.Text=="Refreshed Service Name","disable restores latest native service name")
assert(ownMessage.Text=="Original Display: oo la la" and richMessage.Text=='<font color="#fff">Original Display:</font> body mentions Original Display',"disable restores chat messages")
assert(label.Text=="<font color=\"#fff\">OriginalUser</font>" and humanoid.DisplayName=="Original Display","disable restores originals")
api.setEnabled(true);assert(label.Text=="<font color=\"#fff\">Local_User</font>","enable reapplies after an update")
local fresh=node("Model","Fresh");local freshHumanoid=node("Humanoid","Humanoid");freshHumanoid.DisplayName="Original Display";freshHumanoid.Parent=fresh;player.Character=fresh;added:Fire(fresh)
assert(freshHumanoid.DisplayName=="Local Display","respawn reapplies display name")
api.restore();assert(api.getSettings().username=="" and label.Text=="<font color=\"#fff\">OriginalUser</font>","restore clears settings and text")
api.set("Final_User","Final Display")
api.set("Again_User","Again Display")
api.destroy()
assert(freshHumanoid.DisplayName=="Original Display","repeated settings preserve original humanoid name")
local blockedGame=game
local savedService=game.GetService
game.GetService=function(_,name)if name=="CoreGui"then error("blocked")end;return savedService(game,name)end
local blocked=make(player,gui)
assert(blocked.report():find("unavailable",1,true),"unavailable CoreGui is reported")
blocked.destroy();game.GetService=savedService
print("Local name override fixture passed.")
