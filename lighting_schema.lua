-- Shared property contracts for the lighting backend and editor.
local function number(key,label,min,max,step)return {key=key,label=label,type="number",min=min,max=max,step=step or 0.01}end
local function color(key,label)return {key=key,label=label,type="color"}end
local function boolean(key,label)return {key=key,label=label,type="boolean"}end
local function image(key,label)return {key=key,label=label,type="image"}end
return {
 {id="light",title="Light",target="Lighting",open=true,fields={number("ClockTime","Time of day",0,24,0.05),number("Brightness","Brightness",0,10),number("ExposureCompensation","Exposure",-5,5),number("GeographicLatitude","Latitude",-90,90,1)}},
 {id="colors",title="Colors",target="Lighting",open=true,fields={color("Ambient","Ambient"),color("OutdoorAmbient","Outdoor ambient"),color("ColorShift_Top","Top tint"),color("ColorShift_Bottom","Bottom tint")}},
 {id="atmosphere",title="Fog & atmosphere",target="Atmosphere",open=true,fields={boolean("Enabled","Enabled"),number("Density","Density",0,1),number("Haze","Haze",0,10),number("Glare","Glare",0,10),number("Offset","Offset",-1,1),color("Color","Color"),color("Decay","Decay")}},
 {id="fog",title="Distance fog",target="Lighting",fields={number("FogStart","Start",0,100000,10),number("FogEnd","End",1,100000,10),color("FogColor","Color")}},
 {id="shadows",title="Shadows & reflections",target="Lighting",fields={boolean("GlobalShadows","Shadows"),number("ShadowSoftness","Softness",0,1),number("EnvironmentDiffuseScale","Diffuse",0,1),number("EnvironmentSpecularScale","Reflections",0,1)}},
 {id="bloom",title="Bloom",target="BloomEffect",fields={boolean("Enabled","Enabled"),number("Intensity","Intensity",0,10),number("Size","Size",0,56,1),number("Threshold","Threshold",0,4)}},
 {id="sunRays",title="Sun rays",target="SunRaysEffect",fields={boolean("Enabled","Enabled"),number("Intensity","Intensity",0,1),number("Spread","Spread",0,1)}},
 {id="correction",title="Color correction",target="ColorCorrectionEffect",fields={boolean("Enabled","Enabled"),number("Brightness","Brightness",-1,1),number("Contrast","Contrast",-1,1),number("Saturation","Saturation",-1,1),color("TintColor","Tint")}},
 {id="depth",title="Depth of field",target="DepthOfFieldEffect",fields={boolean("Enabled","Enabled"),number("FarIntensity","Far intensity",0,1),number("NearIntensity","Near intensity",0,1),number("FocusDistance","Focus distance",0,500,1),number("InFocusRadius","Focus radius",0,500,1)}},
 {id="blur",title="Blur",target="BlurEffect",fields={boolean("Enabled","Enabled"),number("Size","Size",0,56,1)}},
 {id="sky",title="Advanced sky",target="Sky",fields={boolean("CelestialBodiesShown","Sun & moon"),number("SunAngularSize","Sun size",0,60),number("MoonAngularSize","Moon size",0,60),number("StarCount","Stars",0,5000,1),image("SunTextureId","Sun image"),image("MoonTextureId","Moon image"),image("SkyboxBk","Back face"),image("SkyboxDn","Bottom face"),image("SkyboxFt","Front face"),image("SkyboxLf","Left face"),image("SkyboxRt","Right face"),image("SkyboxUp","Top face")}},
}
