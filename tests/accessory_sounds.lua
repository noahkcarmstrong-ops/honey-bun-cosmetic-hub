-- Exercises local accessory sound playback and cleanup without Roblox audio APIs.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end
        self.listeners[#self.listeners+1]=c;return c
    end
    function s:Fire(...)
        for _,c in ipairs(self.listeners)do if c.Connected then c.fn(...)end end
    end
    return s
end

local methods={}
local meta={__index=function(t,k)return methods[k]or t.props[k]end,__newindex=function(t,k,v)
    if k=="Parent"then
        local old=t.props.Parent;if old==v then return end
        local a=old
        while a do a.DescendantRemoving:Fire(t);a=a.Parent end
        if old then
            for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i);break end end
            old.ChildRemoved:Fire(t)
        end
        t.props.Parent=v
        if v then
            v.children[#v.children+1]=t;v.ChildAdded:Fire(t)
            local a=v;while a do a.DescendantAdded:Fire(t);a=a.Parent end
        end
    else
        local old=t.props[k];t.props[k]=v
        if old~=v and t.propertySignals[k]then t.propertySignals[k]:Fire()end
    end
end}
local function node(class,name,parent)
    local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),ChildRemoved=signal(),DescendantAdded=signal(),DescendantRemoving=signal(),Destroying=signal()},
        children={},propertySignals={}},meta)
    n.Parent=parent;return n
end
function methods:IsA(class)return class==self.ClassName or (class=="BasePart"and(self.ClassName=="Part"or self.ClassName=="MeshPart"))end
function methods:GetChildren()local out={};for _,v in ipairs(self.children)do out[#out+1]=v end;return out end
function methods:FindFirstChild(name)for _,v in ipairs(self.children)do if v.Name==name then return v end end end
function methods:GetDescendants()local out={};local function walk(p)for _,v in ipairs(p.children)do out[#out+1]=v;walk(v)end end;walk(self);return out end
function methods:GetPropertyChangedSignal(key)self.propertySignals[key]=self.propertySignals[key]or signal();return self.propertySignals[key]end
function methods:Play()self.PlayCount=(self.PlayCount or 0)+1;self.IsPlaying=true end
function methods:Stop()self.StopCount=(self.StopCount or 0)+1;self.IsPlaying=false end
function methods:Destroy()
    self.Destroying:Fire();for _,child in ipairs(self:GetChildren())do child:Destroy()end;self.Parent=nil;self.destroyed=true
end

local timers={}
task={delay=function(seconds,fn)timers[#timers+1]={seconds=seconds,fn=fn}end}
local function nextTimer()
    local timer=table.remove(timers,1);assert(timer,"expected a pending sound timer")
    assert(timer.seconds>=5 and timer.seconds<=15,"hat laugh delay stays in the original 5–15 second range")
    timer.fn()
end
local function gui(initial)
    local attributes={HoneyBunCosmeticUI_HatSounds=initial}
    return {GetAttribute=function(_,key)return attributes[key]end,SetAttribute=function(_,key,value)attributes[key]=value end,attributes=attributes}
end
local function sound(parent,id,looped,playing)
    local item=node("Sound","Sound");item.SoundId="rbxassetid://"..id;item.Looped=looped;item.IsPlaying=playing or false;item.PlayCount=0;item.StopCount=0;item.Parent=parent;return item
end
local player={CharacterAdded=signal()}
player.Character=node("Model","Character")
local function accessory(name,parent)
    local item=node("Accessory",name,parent);item.Handle=node("Part","Handle",item);item.Handle.Transparency=0;return item
end

local create=dofile("accessory_sounds.lua")
local storage=gui(nil)
local sounds=create(player,storage)
assert(sounds.isEnabled(),"accessory sounds default to on")

-- Generic looped sounds start once; already-playing originals are left alone.
local generic=accessory("QuietHat",player.Character)
local loop=sound(generic.Handle,"12345",true)
local preplaying=sound(generic.Handle,"12346",true,true)
assert(loop.PlayCount==1 and loop.IsPlaying,"embedded looped sounds play locally when equipped")
assert(preplaying.PlayCount==0,"an already-playing source sound is not restarted")

-- The original Witches Brew hat uses one random laugh every 5–15 seconds.
local witches=accessory("WitchesBrewHat",player.Character)
local laugh1=sound(witches.Handle,"62777535",false)
local laugh2=sound(witches.Handle,"88108663",false)
local laugh3=sound(witches.Handle,"88108686",false)
assert(laugh1.PlayCount+laugh2.PlayCount+laugh3.PlayCount==0,"the three original laughs wait for their delayed trigger")
nextTimer()
assert(laugh1.PlayCount+ laugh2.PlayCount+laugh3.PlayCount==1,"one original laugh plays per timer")
nextTimer()
local playingLaughs=(laugh1.IsPlaying and 1 or 0)+(laugh2.IsPlaying and 1 or 0)+(laugh3.IsPlaying and 1 or 0)
assert(playingLaughs<=1,"Witches Brew laughs do not overlap")
assert(laugh1.PlayCount+laugh2.PlayCount+laugh3.PlayCount==1,"a laugh that is still playing is neither overlapped nor restarted")
witches.Parent=nil;nextTimer()
assert(laugh1.PlayCount+laugh2.PlayCount+laugh3.PlayCount==1,"removing the witch hat cancels its pending laugh")

-- Manual one-shot playback chooses at most one sound per accessory.
local oneShotHat=accessory("BellHat",player.Character)
local bell1=sound(oneShotHat.Handle,"20001",false)
local bell2=sound(oneShotHat.Handle,"20002",false)
local before=bell1.PlayCount+bell2.PlayCount
assert(type(sounds.playNow())=="string","manual playback returns a user-facing result")
assert(bell1.PlayCount+bell2.PlayCount==before+1,"manual playback starts only one original sound per accessory")

-- Hidden originals, removal, disabling, and hub shutdown stop only sounds started here.
local original=accessory("OriginalHat",player.Character)
local originalLoop=sound(original.Handle,"30001",true)
assert(originalLoop.IsPlaying,"original equipped accessories receive local playback")
original.Handle.Transparency=1
original.Handle:GetPropertyChangedSignal("Transparency"):Fire()
assert(not originalLoop.IsPlaying and originalLoop.StopCount>0,"hidden original hats stop hub-started playback")
original.Handle.Transparency=0;original.Handle:GetPropertyChangedSignal("Transparency"):Fire()
assert(originalLoop.IsPlaying,"visible originals can resume their local loop")
generic.Parent=nil
assert(not loop.IsPlaying and loop.StopCount>0,"removing an accessory stops sounds started by the hub")

sounds.setEnabled(false)
assert(not sounds.isEnabled()and storage:GetAttribute("HoneyBunCosmeticUI_HatSounds")==false,"the off toggle is saved")
assert(not originalLoop.IsPlaying and preplaying.IsPlaying,"disabling stops hub playback but leaves source playback alone")
local muted=accessory("MutedHat",player.Character);local mutedLoop=sound(muted.Handle,"40001",true)
assert(not mutedLoop.IsPlaying,"disabled sound playback stays off")
sounds.setEnabled(true)
assert(storage:GetAttribute("HoneyBunCosmeticUI_HatSounds")==true,"the on toggle is saved")
assert(mutedLoop.IsPlaying,"enabling starts looped sounds on equipped accessories")

-- Respawn attaches the new character; destroying the hub cleans its playback.
local oldCharacter=player.Character
local newCharacter=node("Model","NewCharacter");player.Character=newCharacter;player.CharacterAdded:Fire(newCharacter)
local respawnHat=accessory("RespawnHat",newCharacter)
local respawnLoop=sound(respawnHat.Handle,"50001",true)
assert(respawnLoop.IsPlaying,"looped accessory sounds reapply after respawn")
sounds.destroy()
assert(not respawnLoop.IsPlaying and not mutedLoop.IsPlaying and not originalLoop.IsPlaying,"hub shutdown stops its sounds")
assert(preplaying.IsPlaying and oldCharacter~=newCharacter,"source sounds not started by the hub remain untouched")

-- A saved opt-out remains respected on the next hub run.
local mutedHub=create(player,gui(false))
assert(not mutedHub.isEnabled(),"sound toggle preference survives hub recreation")
mutedHub.destroy()
print("Accessory sound auto-play, delayed Witches Brew laughs, toggle persistence, hidden/removal cleanup, source playback preservation, and respawn passed.")
