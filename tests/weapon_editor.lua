-- Exercise the complete editor with a small Roblox UI host.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={active=true,fn=fn};function c:Disconnect()self.active=false end;self.listeners[#self.listeners+1]=c;return c end
    function s:Fire(...)for _,c in ipairs(self.listeners)do if c.active then c.fn(...)end end end
    return s
end
local objects,methods={},{}
Instance={new=function(class)
    local o=setmetatable({ClassName=class,Name=class,InputBegan=signal(),InputChanged=signal(),MouseEnter=signal(),MouseLeave=signal(),Activated=signal(),FocusLost=signal(),AbsoluteSize={X=200,Y=40},AbsolutePosition={X=0,Y=0}}, {__index=methods})
    objects[#objects+1]=o;return o
end}
function methods:Destroy()self.destroyed=true;self.Parent=nil end
function methods:IsDescendantOf(parent)local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
local function named(name)for i=#objects,1,-1 do local o=objects[i];if o.Name==name and not o.destroyed then return o end end end
local function button(text)for i=#objects,1,-1 do local o=objects[i];if o.ClassName=='TextButton' and o.Text==text and not o.destroyed then return o end end;error('Missing button '..text)end
local function field(row)for i=#objects,1,-1 do local o=objects[i];if o.Parent==named(row) and o.Name=='Value' then return o end end;error('Missing field '..row)end
local vectorMeta={__add=function(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},vectorMeta)end}
Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectorMeta)end}
Vector2={new=function(x,y)return {X=x,Y=y}end}
UDim={new=function(s,o)return {Scale=s,Offset=o}end}
UDim2={new=function(x,xo,y,yo)return {X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}}end,fromScale=function(x,y)return {X={Scale=x,Offset=0},Y={Scale=y,Offset=0}}end,fromOffset=function(x,y)return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}end}
Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end}
CFrame={lookAt=function(position,target)return {Position=position,Target=target}end}
Enum={Font={Gotham='Gotham',GothamMedium='GothamMedium'},TextXAlignment={Left='Left',Right='Right'},AutomaticSize={Y='Y'},SortOrder={LayoutOrder='LayoutOrder'},UserInputType={MouseButton1='MouseButton1',MouseButton2='MouseButton2',MouseMovement='MouseMovement',MouseWheel='MouseWheel',Touch='Touch'},UserInputState={Change='Change'},ContextActionResult={Sink='Sink',Pass='Pass'}}
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
local pending={};task={delay=function(_,fn)pending[#pending+1]=fn end}
local function flush()local q=pending;pending={};for _,fn in ipairs(q)do fn()end end
Enum.MouseBehavior={Default='Default',LockCurrentPosition='LockCurrentPosition'}
local input={InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),MouseBehavior='Default'}
Enum.CameraType={Scriptable='Scriptable',Custom='Custom'}
local contextActions={}
local contextActionService={
    BindActionAtPriority=function(_,name,callback,...)
        contextActions[name]={callback=callback,args={...}}
    end,
    UnbindAction=function(_,name)contextActions[name]=nil end,
}
local function boundAction()
    for name,action in pairs(contextActions)do return name,action end
end
local originalFrame,originalFocus={},{}
local actualCamera={CameraType='Custom',CFrame=originalFrame,Focus=originalFocus}
game={GetService=function(_,name)if name=='Workspace'then return {CurrentCamera=actualCamera}end;if name=='ContextActionService'then return contextActionService end;assert(name=='UserInputService');return input end}
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function default()return {Position={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0},Scale={X=1,Y=1,Z=1}}end
local values={Holster=default(),Held=default()};local writes,previews,clones=0,0,0
local catalog={setWeaponAdjustment=function(id,mode,value,persist)assert(id=='saved');values[mode]=copy(value);if persist then writes=writes+1 else previews=previews+1 end;return 'Applied'end}
function catalog.getEditorScene(id,mode)
    clones=clones+1
    local avatar=Instance.new('Model');local gun=Instance.new('Part');gun.Parent=avatar
    return {character=avatar,weapon=gun,focus=Vector3.new(100,20,30),update=function()previews=previews+1;return gun end}
end
local api=dofile('weapon_editor.lua')({},catalog)
local entry={id='saved',name='Gingerscope',adjustments=copy(values)}
api.open(entry,'Holster')
assert(named('HoneyBunWeaponEditor'),'Full editor opens')
local camera;for _,o in ipairs(objects)do if o.ClassName=='Camera'then camera=o end end
assert(camera.CFrame.Target.X==100,'Camera targets avatar location instead of world origin')
local view;for _,o in ipairs(objects)do if o.ClassName=='ViewportFrame'then view=o end end
local actionName,action=boundAction();assert(action and action.callback,'Preview binds a context action for mouse-wheel zoom')
view.MouseEnter:Fire()
assert(actualCamera.CameraType=='Scriptable' and actualCamera.CFrame==originalFrame,'Hovering preview freezes the real camera')
local wheelFrame=actualCamera.CFrame
local function cameraDistance()
    local position,target=camera.CFrame.Position,camera.CFrame.Target
    local dx,dy,dz=position.X-target.X,position.Y-target.Y,position.Z-target.Z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local initialDistance=cameraDistance()
assert(action.callback(actionName,Enum.UserInputState.Change,{UserInputType='MouseWheel',Position={Z=1}})==Enum.ContextActionResult.Sink,'Mouse wheel over preview is consumed')
assert(cameraDistance()<initialDistance and actualCamera.CFrame==wheelFrame,'Wheel up zooms preview without moving the real camera')
local nearDistance=cameraDistance()
assert(action.callback(actionName,Enum.UserInputState.Change,{UserInputType='MouseWheel',Position={Z=-1}})==Enum.ContextActionResult.Sink)
assert(cameraDistance()>nearDistance,'Wheel down zooms preview out')
view.MouseLeave:Fire()
local outsideDistance=cameraDistance()
assert(action.callback(actionName,Enum.UserInputState.Change,{UserInputType='MouseWheel',Position={Z=1}})==Enum.ContextActionResult.Pass,'Mouse wheel outside preview passes through')
assert(cameraDistance()==outsideDistance,'Mouse wheel outside preview does not zoom')
view.MouseEnter:Fire()
for _=1,30 do action.callback(actionName,Enum.UserInputState.Change,{UserInputType='MouseWheel',Position={Z=1}})end
assert(cameraDistance()>=4,'Preview zoom has a minimum distance')
for _=1,60 do action.callback(actionName,Enum.UserInputState.Change,{UserInputType='MouseWheel',Position={Z=-1}})end
assert(cameraDistance()<=14,'Preview zoom has a maximum distance')
input.WindowFocusReleased:Fire()
assert(actualCamera.CameraType=='Custom' and actualCamera.CFrame==originalFrame,'Losing window focus restores the real camera while hovered')
local startX=camera.CFrame.Position.X
view.InputBegan:Fire({UserInputType='MouseButton1'})
input.InputChanged:Fire({UserInputType='MouseMovement',Delta={X=40,Y=25}})
assert(camera.CFrame.Position.X~=startX and camera.CFrame.Position.Y~=20,'Left drag orbits horizontally and vertically')
assert(input.MouseBehavior=='LockCurrentPosition','Orbit locks the cursor for continuous dragging')
assert(actualCamera.CameraType=='Scriptable' and actualCamera.CFrame==originalFrame,'Preview drag freezes the real camera without moving it')
input.InputEnded:Fire({UserInputType='MouseButton1'})
local endedX=camera.CFrame.Position.X
input.InputChanged:Fire({UserInputType='MouseMovement',Delta={X=40,Y=25}})
assert(camera.CFrame.Position.X==endedX and input.MouseBehavior=='Default','Releasing left click ends rotation and restores cursor')
assert(actualCamera.CameraType=='Custom' and actualCamera.CFrame==originalFrame and actualCamera.Focus==originalFocus,'Releasing preview restores the real camera state')
view.InputBegan:Fire({UserInputType='MouseButton1'});input.WindowFocusReleased:Fire()
assert(input.MouseBehavior=='Default','Losing window focus releases cursor')

local x=field('PositionX');x.Text='1.25';x.FocusLost:Fire();flush()
assert(values.Holster.Position.X==1.25 and writes==0,'Numeric placement updates live without disk writes')
assert(clones==1,'Slider updates reuse the avatar clone')
local ySlider;for _,o in ipairs(objects)do if o.Parent==named('PositionY') and o.Name=='Slider'then ySlider=o end end
local down={UserInputType='MouseButton1',Position={X=100}}
ySlider.InputBegan:Fire(down)
input.InputChanged:Fire({UserInputType='MouseMovement',Position={X=150}})
input.InputEnded:Fire({UserInputType='MouseButton1',Position={X=0}});flush()
assert(values.Holster.Position.Y==1.5 and writes==0,'Dragging updates once and release does not jump to the release event position')

button('Holding').Activated:Fire()
local tilt=field('RotationX');tilt.Text='45';tilt.FocusLost:Fire();flush()
button('Hip / Back').Activated:Fire()
assert(field('PositionX').Text=='1.25','Switching modes preserves placement edits')
button('Save / Done').Activated:Fire()
assert(writes==2 and values.Held.Rotation.X==45,'Save persists both modes')
assert(not named('HoneyBunWeaponEditor'),'Save closes editor')
entry.adjustments=copy(values);api.open(entry,'Held')
field('RotationX').Text='90';field('RotationX').FocusLost:Fire();flush()
local cancelView;for _,o in ipairs(objects)do if o.ClassName=='ViewportFrame' and not o.destroyed then cancelView=o end end
cancelView.MouseEnter:Fire()
assert(actualCamera.CameraType=='Scriptable','Cancel test starts with a frozen camera while hovered')
button('Cancel').Activated:Fire()
assert(values.Held.Rotation.X==45 and values.Holster.Position.X==1.25,'Cancel restores both initial modes')
assert(actualCamera.CameraType=='Custom' and not boundAction(),'Cancel restores the camera and unbinds the wheel action')
api.open(entry,'Holster');button('Reset').Activated:Fire()
assert(field('PositionX').Text=='0.00','Reset restores current mode controls')
local closingView;for _,o in ipairs(objects)do if o.ClassName=='ViewportFrame' and not o.destroyed then closingView=o end end
closingView.MouseEnter:Fire()
closingView.InputBegan:Fire({UserInputType='MouseButton1'})
api.destroy();flush()
assert(input.MouseBehavior=='Default' and actualCamera.CameraType=='Custom' and not boundAction(),'Closing editor restores cursor, actual camera and wheel binding during orbit')
for _,s in ipairs({input.InputChanged,input.InputEnded})do for _,c in ipairs(s.listeners)do assert(not c.active,'Global input handlers disconnect')end end
print('Avatar editor opening, camera, nine sliders, live reuse, mode isolation, Save, Cancel, Reset and cleanup passed.')
