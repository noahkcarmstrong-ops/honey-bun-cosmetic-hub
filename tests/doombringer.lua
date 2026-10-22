-- Offline contract test for Doombringer's local-only API.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={live=true};self.listeners[#self.listeners+1]={c,fn};function c:Disconnect()c.live=false end;return c end
    function s:Fire(...)for _,v in ipairs(self.listeners)do if v[1].live then v[2](...)end end end
    return s
end
local methods={};local meta={__index=function(t,k)return methods[k]or t.props[k]end,__newindex=function(t,k,v)
    if k=="Parent"then local old=t.props.Parent;if old then for i,x in ipairs(old.children)do if x==t then table.remove(old.children,i)break end end;old.ChildRemoved:Fire(t)end;t.props.Parent=v;if v then v.children[#v.children+1]=t;v.ChildAdded:Fire(t);local a=v;while a do a.DescendantAdded:Fire(t);a=a.Parent end end else t.props[k]=v end end}
local function node(class,name,parent)local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),ChildRemoved=signal(),DescendantAdded=signal(),DescendantRemoving=signal()},children={}},meta);n.Parent=parent;return n end
function methods:IsA(c)return c==self.ClassName or c=="BasePart"and(self.ClassName=="Part"or self.ClassName=="MeshPart")end
function methods:GetChildren()return self.children end
function methods:FindFirstChild(n)for _,x in ipairs(self.children)do if x.Name==n then return x end end end
function methods:FindFirstChildOfClass(c)for _,x in ipairs(self.children)do if x:IsA(c)then return x end end end
function methods:Destroy()self.destroyed=true;self.Parent=nil end
local function player(name,display)local p=node("Player",name);p.DisplayName=display or name;p.CharacterAdded=signal();p.Chatted=signal();p.Backpack=node("Backpack",name.." Backpack");p.mouse={Hit={Position={X=4,Y=0,Z=7}}};return p end
function methods:GetMouse()return self.mouse end
Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end};Color3={new=function(r,g,b)return{r=r,g=g,b=b}end};CFrame={new=function(p)return{Position=p}end,Angles=function()return{}end};Enum={Material={Neon=1}};local timers={};local clock=0;task={delay=function(seconds,fn)timers[#timers+1]={at=clock+seconds,fn=fn}end,defer=function(fn)fn()end};os.clock=function()return clock end
local function advance(seconds)local endAt=clock+seconds;while true do local pick;for i,t in ipairs(timers)do if t.at<=endAt and (not pick or t.at<pick.at)then pick={i=i,at=t.at,fn=t.fn}end end;if not pick then break end;table.remove(timers,pick.i);clock=pick.at;pick.fn()end;clock=endAt end
local createdParts={};Instance={new=function(c)local n=node(c,c);if c=="Tool"then n.Activated=signal()elseif c=="Part"then createdParts[#createdParts+1]=n end;return n end}
local me=player("Tester");local target=player("Target","Target Display");me.Character=node("Model","Character");local humanoid=node("Humanoid","Humanoid",me.Character);humanoid.Health=100;humanoid.Died=signal();local hat=node("Accessory","Doombringer",me.Character);local handle=node("Part","Handle",hat);local meRoot=node("Part","HumanoidRootPart",me.Character);meRoot.Position=Vector3.new(10,0,10);target.Character=node("Model","Other");local targetRoot=node("Part","HumanoidRootPart",target.Character);targetRoot.Position=Vector3.new(20,0,20)
local players={LocalPlayer=me,GetPlayers=function()return{me,target}end};local textService={SendingMessage=signal()};game={GetService=function(_,n)return n=="Players"and players or n=="TextChatService"and textService end}
local statuses={};local api=dofile("doombringer.lua")(me,function(s)statuses[#statuses+1]=s end)
assert(api.refresh() and api.diagnostics().satellite,"matching name creates the local satellite")
assert(api.command("smite Target"),"smite resolves a local target");assert(api.diagnostics().effects>0,"smite creates visual effects")
assert(not api.command("smite Target"),"duplicate legacy/TextChat delivery is suppressed")
advance(0.6);me.Chatted:Fire("target 1 2 3");textService.SendingMessage:Fire({Text="target 1 2 3"});assert(api.diagnostics().effects>0,"Chatted and SendingMessage share duplicate suppression")
advance(0.6)
assert(api.command("target 1 2 3"),"coordinate target command fires a beam")
advance(0.6);assert(api.command("movesat 8 9 10") and not api.command("movesat 8 9 10 11") and api.command("location"),"movesat and location commands work")
assert(not api.command("giveweapon Target") and api.diagnostics().tools==0,"remote targeting tool grants are rejected locally")
assert(api.command("giveweapon me") and api.diagnostics().tools==1,"targeting tool stays local")
local tool;for t in pairs({})do tool=t end;for _,x in ipairs(me.Backpack.children)do if x:IsA("Tool")then tool=x end end;assert(tool and tool.RequiresHandle==false and tool.CanBeDropped==false,"tool has no required handle and cannot drop")
advance(0.6);tool.Activated:Fire();assert(api.diagnostics().effects>0,"tool activation makes a local beam")
handle.Transparency=1;assert(not api.refresh(),"hidden handle disables the cosmetic");handle.Transparency=0;assert(api.refresh(),"visible handle restores the cosmetic")
advance(0.6)
assert(api.command("kill Target"),"kill command is visual only");advance(0.6);assert(api.command("kill all"),"kill-all command is visual only")
advance(0.6);local before=#createdParts;assert(api.command("armageddon"),"armageddon starts");advance(3.1);assert(#createdParts-before>=25,"armageddon performs 25 sequential local strikes")
local after=#createdParts;api.command("stop");advance(10);assert(#createdParts==after and api.diagnostics().effects==0,"stop cancels remaining strikes")
api.setEnabled(false);assert(not api.command("smite Target") and not api.diagnostics().active,"disabled hat blocks commands")
api.setEnabled(true);hat.Parent=nil;assert(not api.refresh() and api.diagnostics().tools==0,"hat removal cleans tools and effects")
humanoid.Died:Fire();local newCharacter=node("Model","Respawned");local newHumanoid=node("Humanoid","Humanoid",newCharacter);newHumanoid.Health=100;newHumanoid.Died=signal();local newHat=node("Accessory","Doombringer",newCharacter);node("Part","Handle",newHat);local newRoot=node("Part","HumanoidRootPart",newCharacter);newRoot.Position=Vector3.new(11,0,11);me.Character=newCharacter;me.CharacterAdded:Fire(newCharacter);assert(api.refresh(),"respawn with a matching hat restores the cosmetic")
api.destroy();assert(not api.diagnostics().active,"destroy cleans the cosmetic")
print("Doombringer commands, local targeting tool, cancellation, gating, and safety contract passed.")
