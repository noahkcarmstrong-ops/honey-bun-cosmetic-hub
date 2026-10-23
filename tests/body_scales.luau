-- Pass the avatar factory and native inspection module. Uses disposable rigs only.
local create,inspect=...
local Players=game:GetService('Players')
local fields={height='HeightScale',width='WidthScale',depth='DepthScale',head='HeadScale',bodyType='BodyTypeScale',proportion='ProportionScale'}
local initial=Instance.new('HumanoidDescription')
local model=Players:CreateHumanoidModelFromDescriptionAsync(initial,Enum.HumanoidRigType.R15)
initial:Destroy()
local event=Instance.new('BindableEvent')
local player={Character=model,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
local originals={}
for _,part in ipairs(model:GetChildren())do if part:IsA('BasePart')then originals[part.Name]={part=part,size=part.Size}end end
local api=create(player,nil,nil,true)
local count=0
local ok,err=pcall(function()
 for _,scales in ipairs({{height=1.05,width=0.75,depth=0.8,head=0.95,bodyType=0.5,proportion=0.3},{height=0.9,width=1,depth=1,head=1,bodyType=0,proportion=0}})do
  local description=inspect.description({items={},definition={assets={},scales=scales}})
  for name,field in pairs(fields)do assert(math.abs(description[field]-scales[name])<0.0001,'Inspect lost '..name)end
  local reference=Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
  description:Destroy()
  api.setScales(scales);api.applyBodyParts({},scales)
  for name,original in pairs(originals)do
   local part=model:FindFirstChild(name)
   assert(part==original.part,'Scale update replaced '..name)
   assert((part.Size-reference[name].Size).Magnitude<0.001,'Scale geometry differs from Roblox: '..name)
  end
  reference:Destroy();count=count+1
 end
 api.restoreBody()
 for name,original in pairs(originals)do assert((model[name].Size-original.size).Magnitude<0.001,'Restore failed: '..name)end
end)
api.destroy();event:Destroy();model:Destroy()
assert(ok,err)
return {passed=count,message='Repeated scale changes match native Roblox geometry; all six inspect values and live part identities preserved.'}
