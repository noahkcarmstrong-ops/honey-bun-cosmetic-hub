local objects = {}
local methods = {}
local function signal()
    local listeners = {}
    return {
        Connect = function(_, fn)
            local connection = {active = true}
            function connection:Disconnect() self.active = false end
            listeners[#listeners + 1] = {connection, fn}
            return connection
        end,
        Fire = function(_, ...)
            for _, pair in ipairs(listeners) do
                if pair[1].active then pair[2](...) end
            end
        end,
    }
end
local meta = {__index = function(o, k) return methods[k] or o.props[k] end,
    __newindex = function(o, k, v)
        if o.destroyed and k == "Parent" then error("destroyed instance") end
        local old = o.props[k]
        o.props[k] = v
        if k == "Parent" and v and v ~= old and v.props and v.props.ChildAdded then
            v.props.ChildAdded:Fire(o)
        end
    end}

Instance = {new = function(class, parent)
    local o = setmetatable({props = {ClassName = class, Name = class, ChildAdded = signal()}, destroyed = false}, meta)
    o.Parent = parent
    table.insert(objects, o)
    return o
end}
function methods:IsA(class) return self.ClassName == class end
function methods:GetChildren()
    local out = {}
    for _, o in ipairs(objects) do if not o.destroyed and o.Parent == self then table.insert(out, o) end end
    return out
end
function methods:FindFirstChild(name)
    for _, child in ipairs(self:GetChildren()) do if child.Name == name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self:GetChildren()) do if child.ClassName == class then return child end end
end
function methods:Destroy()
    if self.destroyed then return end
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent = nil
    self.destroyed = true
end
function methods:Clone()
    local copy = Instance.new(self.ClassName)
    for k, v in pairs(self.props) do if k ~= "Parent" then copy[k] = v end end
    for _, child in ipairs(self:GetChildren()) do child:Clone().Parent = copy end
    return copy
end

local lighting = Instance.new("Lighting");lighting.ClockTime=0
local original = Instance.new("Sky", lighting); original.Name = "Original"; original.SkyboxBk = "old"
local game = {Lighting = lighting, assets = {}, fail = false, cancel = false}
local api
local callbacks={}
local renderCallbacks={}; local bindCalls={}; local unbindCalls={}
local heartbeat={Connect=function(_,fn)local c={active=true};function c:Disconnect()self.active=false end;callbacks[#callbacks+1]={c,fn};return c end}
local renderService={
    Heartbeat=heartbeat,
    BindToRenderStep=function(_,name,priority,fn) bindCalls[#bindCalls+1]={name,priority};renderCallbacks[name]={fn=fn,active=true} end,
    UnbindFromRenderStep=function(_,name) unbindCalls[#unbindCalls+1]=name;if renderCallbacks[name] then renderCallbacks[name].active=false end end,
}
local function tick(dt)
    dt=dt or .3
    for _,entry in pairs(renderCallbacks)do if entry.active then entry.fn(dt)end end
    for _,pair in ipairs(callbacks)do if pair[1].active then pair[2](dt)end end
end
function game:GetService(name)if name=="Lighting" then return self.Lighting elseif name=="RunService" then return renderService elseif name=="ContentProvider" then return self.provider end end
function game:GetObjects(uri)
    assert(uri == "rbxassetid://123")
    if self.fail then error("network") end
    if self.cancel then self.cancel = false; api.restore() end
    return self.assets
end

local module = dofile("atmosphere.lua")
api = module(game)
local function model(name, skies)
    local root = Instance.new("Model"); root.Name = name
    for _, sky in ipairs(skies or {}) do sky.Parent = root end
    return root
end
local function sky(name)
    local s = Instance.new("Sky"); s.Name = name;for _,face in ipairs({"Bk","Dn","Ft","Lf","Rt","Up"})do s["Skybox"..face]=name end;return s
end

assert(not api.apply("0"), "zero is invalid")
assert(not api.apply("123abc"), "loose IDs are invalid")
assert(not api.apply("https://roblox.com/library/0"), "zero URL is invalid")
assert(original.Parent == lighting and original.SkyboxBk == "old")

local noSky = model("NoSky")
game.assets = {noSky}; assert(not api.apply(123), "models without Sky are rejected")
assert(noSky.destroyed and original.Parent == lighting, "failed load leaves Lighting alone and cleans wrappers")

local ambiguous=model("Ambiguous",{sky("A"),sky("B")});game.assets={ambiguous}
assert(not api.apply("123") and ambiguous.destroyed and original.Parent==lighting,"Ambiguous models are rejected and cleaned without changing the sky")
local incomplete=sky("Incomplete");incomplete.SkyboxUp="";game.assets={model("Incomplete",{incomplete})}
assert(not api.apply("123") and original.Parent==lighting,"Incomplete six-face skies never replace the game sky")
Enum={AssetFetchStatus={Success="Success",Failure="Failure"},RenderPriority={Last={Value=200}}}
game.provider={PreloadAsync=function(_,assets,callback)callback("blocked-image","Failure")end}
game.assets={model("Blocked",{sky("Blocked")})}
assert(not api.apply("123") and original.Parent==lighting,"Unavailable sky images are reported without overwriting the working sky")
game.provider={PreloadAsync=function(_,assets,callback)callback("valid-image","Success")end}
local source = sky("Source"); local script = Instance.new("Script", source)
local wrapper = model("Wrapper", {source}); game.assets = {wrapper}
assert(api.apply("https://create.roblox.com/store/asset/123/Custom-Sky"))
assert(original.Parent == nil and wrapper.destroyed and script.destroyed, "success sanitizes and cleans source assets")
assert(lighting.ClockTime==14,"Applying a sky uses daylight instead of preserving the game midnight")
assert(api.currentAsset()=="123" and api.previewImage()=="Source","Saved cards can capture the active sky ID and its original front face")
local custom = lighting:FindFirstChildOfClass("Sky"); assert(custom and custom ~= original and custom.Name == "Source")
assert(#custom:GetChildren() == 0, "cloned Sky has no untrusted descendants")

local gameReset=sky("Game reset");gameReset.Parent=lighting
assert(gameReset.Parent==nil,"ChildAdded quarantines a competing sky immediately")
custom.Parent=nil;tick(1/240)
assert(custom.Parent==lighting and gameReset.Parent==nil,"Override removes newly inserted game skies and reparents custom sky")
lighting.ClockTime=0;tick(1/240);assert(lighting.ClockTime==14,"Game midnight resets cannot darken the custom sky")
api.setDaylight(false);assert(lighting.ClockTime==0,"Daylight off restores the game time")
tick();assert(lighting.ClockTime==0,"Daylight off stops time enforcement")
api.setDaylight(true);assert(lighting.ClockTime==14,"Daylight can be enabled again")
custom.SkyboxBk="game changed it";tick(1/240);assert(custom.SkyboxBk=="Source","Game sky texture changes are repaired on the next render")
local report=api.report()
assert(report:find("Requested asset=123",1,true) and report:find("SkyboxBk=Source",1,true),"Report includes requested model and actual active sky face IDs")
game.fail = true; assert(not api.apply("rbxassetid://123"), "failed replacement is reported")
assert(custom.Parent == lighting and not custom.destroyed, "failed replacement keeps current sky")
game.fail = false
local second = sky("Second"); local secondWrapper = model("SecondWrapper", {second}); game.assets = {secondWrapper}
assert(api.apply("https://roblox.com/asset/?id=123")); assert(custom.destroyed and secondWrapper.destroyed)
assert(api.restore());assert(lighting.ClockTime==0,"Restore returns the exact original time of day");assert(gameReset.Parent==lighting,"Restore returns skies added by the game during override")
assert(original.Parent == lighting and second.Parent == nil, "restore returns exact original object")
local restoredSky=sky("After restore immediate");restoredSky.Parent=lighting
assert(restoredSky.Parent==lighting,"Restore disconnects immediate quarantine hooks")
tick(1/240);assert(restoredSky.Parent==lighting,"Restore unbinds render repair")
local late = sky("Late"); local lateWrapper = model("LateWrapper", {late}); game.assets = {lateWrapper}; game.cancel = true
assert(not api.apply(123), "a replacement cancelled during loading is rejected")
assert(lateWrapper.destroyed, "cancelled replacement cleans wrappers")
assert(original.Parent == lighting, "cancelled replacement preserves originals")

local beforeEnvironment = api.environment()
assert(not beforeEnvironment, "No environment is active before applying one")
assert(not api.applyEnvironment({time=25,fog="Light",color="Natural"}), "Environment rejects out-of-range time")
assert(not api.environment(), "Invalid environment settings do not mutate state")
local nativeAtmosphere=Instance.new("Atmosphere",lighting)
assert(api.applyEnvironment({time=7.5,fog="Light",color="Warm"}), "Environment applies without a custom sky")
assert(api.environment().time==7.5 and api.environment().fog=="Light" and api.environment().color=="Warm", "Environment returns a copy of active settings")
assert(nativeAtmosphere.Parent==nil and lighting.FogStart==100 and lighting.FogEnd==1800 and lighting.ClockTime==7.5, "Environment detaches native atmosphere and enforces lighting")
local ownTint=lighting:FindFirstChild("LarpbloxEnvironmentTint")
assert(ownTint and #lighting:GetChildren()>=2, "Environment creates one owned color correction effect")
assert(api.applyEnvironment({time=8,fog="Thick",color="Cool"}) and lighting.ClockTime==8 and lighting.FogStart==0 and lighting.FogEnd==300, "Replacing an active environment applies immediately")
ownTint:Destroy();lighting.ClockTime=1;lighting.FogEnd=2;tick(1/240)
assert(lighting:FindFirstChild("LarpbloxEnvironmentTint") and lighting.ClockTime==8 and lighting.FogEnd==300, "Environment repairs deleted tint and game property changes")
assert(api.restoreEnvironment() and nativeAtmosphere.Parent==lighting, "Environment restore returns native atmosphere")
assert(not api.environment() and lighting.FogStart==nil and lighting.FogEnd==nil, "Environment restore returns baseline fog")
lighting.FogStart=33;lighting.FogEnd=44;api.restoreEnvironment()
assert(lighting.FogStart==33 and lighting.FogEnd==44, "Restoring without an active environment is a no-op")
api.destroy();local afterRestore=sky("After destroy");afterRestore.Parent=lighting;tick(1/240)
assert(afterRestore.Parent==lighting,"Restore and destroy disconnect the active override")
assert(original.Parent == lighting and api.apply(123) == false, "destroy restores and disables API")
assert(#bindCalls >= 2 and bindCalls[1][2] == Enum.RenderPriority.Last.Value + 1,"Render repair runs after the last render priority")
assert(#unbindCalls >= 2,"Restore and destroy unbind render repair")

local fallbackLighting=Instance.new("Lighting");fallbackLighting.ClockTime=3
local fallbackOriginal=sky("Fallback original");fallbackOriginal.Parent=fallbackLighting
local fallbackGame={Lighting=fallbackLighting,assets={},provider={PreloadAsync=function(_,assets,callback)callback("valid-image","Success")end}}
function fallbackGame:GetService(name)if name=="Lighting" then return self.Lighting elseif name=="RunService" then return {Heartbeat=heartbeat}elseif name=="ContentProvider" then return self.provider end end
function fallbackGame:GetObjects(uri)assert(uri=="rbxassetid://123");return self.assets end
local fallbackApi=module(fallbackGame)
local fallbackSource=sky("Fallback source");fallbackGame.assets={model("Fallback wrapper",{fallbackSource})}
assert(fallbackApi.apply(123),"Heartbeat fallback applies a replacement")
local fallbackCustom=fallbackLighting:FindFirstChildOfClass("Sky")
fallbackCustom.SkyboxBk="fallback changed";tick(1/240)
assert(fallbackCustom.SkyboxBk=="Fallback source","Heartbeat fallback repairs on every frame")
assert(fallbackApi.restore() and fallbackOriginal.Parent==fallbackLighting,"Heartbeat fallback restores originals")
local fallbackLate=sky("Fallback late");fallbackLate.Parent=fallbackLighting;tick(1/240)
assert(fallbackLate.Parent==fallbackLighting,"Heartbeat fallback disconnects on restore")

local function freshGame(clock)
    local world=Instance.new("Lighting");world.ClockTime=clock;world.FogStart=11;world.FogEnd=22;world.FogColor="baseline"
    local originalSky=sky("Fresh original");originalSky.Parent=world
    local fresh={Lighting=world,assets={},provider={PreloadAsync=function(_,assets,callback)callback("valid-image","Success")end}}
    function fresh:GetService(name)if name=="Lighting" then return self.Lighting elseif name=="RunService" then return renderService elseif name=="ContentProvider" then return self.provider end end
    function fresh:GetObjects(uri)assert(uri=="rbxassetid://123");return self.assets end
    local source=sky("Fresh custom");fresh.assets={model("Fresh wrapper",{source})}
    return fresh,world,originalSky
end

local skyFirst,skyFirstLighting,skyFirstOriginal=freshGame(0)
local skyFirstApi=module(skyFirst)
assert(skyFirstApi.apply(123) and skyFirstLighting.ClockTime==14,"Sky-first lifecycle applies daylight")
assert(skyFirstApi.applyEnvironment({time=8,fog="Light",color="Natural"}) and skyFirstLighting.ClockTime==8,"Sky-first environment takes time ownership")
local copy=skyFirstApi.environment();copy.time=2;assert(skyFirstApi.environment().time==8,"Environment returns an isolated copy")
assert(skyFirstApi.restoreEnvironment() and skyFirstLighting.ClockTime==14,"Restoring environment returns sky daylight")
assert(skyFirstApi.restore() and skyFirstLighting.ClockTime==0 and skyFirstOriginal.Parent==skyFirstLighting,"Restoring sky returns original game clock")

local envFirst,envFirstLighting,envFirstOriginal=freshGame(3)
local envFirstApi=module(envFirst)
local envNative=Instance.new("Atmosphere",envFirstLighting)
assert(envFirstApi.applyEnvironment({time=8,fog="Thick",color="Cool"}) and envNative.Parent==nil,"Environment detaches native atmosphere immediately")
assert(envFirstApi.apply(123) and envFirstLighting.ClockTime==8,"Sky preserves active environment time")
assert(envFirstApi.restore() and envFirstLighting.ClockTime==8,"Sky restore preserves active environment")
assert(envFirstApi.restoreEnvironment() and envFirstLighting.ClockTime==3 and envNative.Parent==envFirstLighting,"Environment restore returns game state")

local destroyGame,destroyLighting,destroyOriginal=freshGame(4)
local destroyNative=Instance.new("Atmosphere",destroyLighting)
destroyLighting.FogStart=5;destroyLighting.FogEnd=6
local destroyApi=module(destroyGame)
assert(destroyApi.applyEnvironment({time=9,fog="Off",color="Pink"}) and destroyApi.apply(123),"Destroy lifecycle activates sky and environment")
local unbindBefore=#unbindCalls
destroyApi.destroy()
assert(destroyLighting.ClockTime==4 and destroyLighting.FogStart==5 and destroyLighting.FogEnd==6,"Destroy restores lighting properties")
assert(destroyOriginal.Parent==destroyLighting and destroyNative.Parent==destroyLighting,"Destroy restores sky and native atmosphere")
assert(not destroyLighting:FindFirstChild("LarpbloxEnvironmentTint") and #unbindCalls>unbindBefore,"Destroy removes tint and render hook")

print("Atmosphere validation, replacement, sanitization, failure, restore, and destroy passed.")
