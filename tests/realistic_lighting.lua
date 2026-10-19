local objects, callbacks = {}, {}
local methods = {}
local meta = {__index=function(o,k)return methods[k] or o.props[k] end,__newindex=function(o,k,v)o.props[k]=v end}
Instance={new=function(class,parent)local o=setmetatable({props={ClassName=class,Name=class,Parent=parent},destroyed=false},meta);objects[#objects+1]=o;return o end}
function methods:IsA(c)return self.ClassName==c end
function methods:GetChildren()local out={};for _,o in ipairs(objects)do if not o.destroyed and o.Parent==self then out[#out+1]=o end end;return out end
function methods:Destroy()self.destroyed=true;self.Parent=nil end
Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end,new=function(r,g,b)return {R=r,G=g,B=b}end}
local lighting=Instance.new("Lighting");lighting.GlobalShadows=false;lighting.Brightness=1;lighting.ShadowSoftness=.5;lighting.Ambient=Color3.fromRGB(50,50,50);lighting.OutdoorAmbient=Color3.fromRGB(60,60,60);lighting.EnvironmentDiffuseScale=.4;lighting.EnvironmentSpecularScale=.3;lighting.ExposureCompensation=-.2
local old=Instance.new("BloomEffect",lighting);old.Enabled=false
local camera=Instance.new("Camera");local cameraEffect=Instance.new("ColorCorrectionEffect",camera);cameraEffect.Enabled=true
local workspace=Instance.new("Workspace");workspace.CurrentCamera=camera
local run={Heartbeat={Connect=function(_,fn)local c={active=true};function c:Disconnect()self.active=false end;callbacks[#callbacks+1]={c,fn};return c end}}
local game={GetService=function(_,n)if n=="Lighting"then return lighting elseif n=="Workspace"then return workspace elseif n=="RunService"then return run end end}
local module=dofile("realistic_lighting.lua");local api=module(game)
assert(not api.apply("Medium",.5));assert(not api.apply("Low",1.1));assert(api.apply("Low",.5));assert(old.Enabled==false and cameraEffect.Enabled==false)
local p,s=api.state();assert(p=="Low" and s==.5)
assert(not api.apply("Low",0/0));assert(api.apply("High",.2));local count=0;local bloom
for _,o in ipairs(lighting:GetChildren())do if o.Name:find("Larpblox")then count=count+1 end;if o.ClassName=="BloomEffect" and o.Name:find("Larpblox")then bloom=o end end
assert(count==3 and bloom.Enabled and bloom.Intensity==.024)
assert(api.apply("High",.8));local bloomHigh;for _,o in ipairs(lighting:GetChildren())do if o.ClassName=="BloomEffect" and o.Name:find("Larpblox")then bloomHigh=o end end;assert(bloomHigh.Enabled and bloomHigh.Intensity==.096)
local added=Instance.new("SunRaysEffect",lighting);added.Enabled=true;workspace.CurrentCamera=Instance.new("Camera");local newer=Instance.new("BloomEffect",workspace.CurrentCamera);newer.Enabled=true
for _,entry in ipairs(callbacks)do if entry[1].active then entry[2](.5)end end;assert(added.Enabled==false and newer.Enabled==false)
assert(api.apply("High",0));assert(old.Enabled==false and cameraEffect.Enabled==true and added.Enabled==true and newer.Enabled==true)
api.restore();assert(old.Enabled==false and cameraEffect.Enabled==true and added.Enabled==true and newer.Enabled==true);assert(lighting.GlobalShadows==false and lighting.ExposureCompensation==-.2)
lighting.Brightness=3;assert(api.apply("Low",.5));api.restore();assert(lighting.Brightness==3)
api.destroy();api.destroy();assert(api.apply("Low",.2)==false);lighting.ClockTime=3;assert(lighting.ClockTime==3)
print("Realistic lighting validation passed.")
