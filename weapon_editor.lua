-- Standalone weapon adjustment editor. The catalog owns cloning and persistence.
return function(playerGui, catalog, onStatus)
    local UserInputService = game:GetService("UserInputService")
    local connections, scene = {}, {}
    local gui,entry,original,workingByMode,working,dragging
    local mode,refreshPending,openToken="Holster",false,0
    local accepted=false
    local controls, statusLabel, viewport, worldModel, camera
    local persist,sceneMode, cameraTarget, cameraYaw, cameraDistance, cameraPitch
    local orbitDragging,previousMouseBehavior
    local guides,axisLabels={},{}
    local projectAxes

    local function connect(signal, fn)
        if not signal or not signal.Connect then return end
        local c = signal:Connect(fn); table.insert(connections, c); return c
    end
    local function status(message)
        if statusLabel then statusLabel.Text = tostring(message or "") end
        if type(onStatus) == "function" then pcall(onStatus, message) end
    end
    local function copy(value)
        if type(value) ~= "table" then return value end
        local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
    end
    local function defaults()
        return {Position={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0},Scale={X=1,Y=1,Z=1}}
    end
    local function adjustment(value)
        local out = defaults()
        for group, values in pairs(out) do
            for axis, fallback in pairs(values) do
                local n = value and value[group] and tonumber(value[group][axis])
                out[group][axis] = n or fallback
            end
        end
        return out
    end
    local function make(class, parent, props)
        local item = Instance.new(class)
        for key, value in pairs(props or {}) do item[key] = value end
        item.Parent = parent
        return item
    end
    local function label(parent, textValue, size, color, textSize)
        return make("TextLabel", parent, {BackgroundTransparency=1, Size=size, Text=textValue,
            Font=Enum.Font.Gotham, TextColor3=color or Color3.fromRGB(215,215,215), TextSize=textSize or 12,
            TextXAlignment=Enum.TextXAlignment.Left})
    end
    local function button(parent, textValue, size)
        local b = make("TextButton", parent, {Size=size or UDim2.fromOffset(100,30), Text=textValue,
            Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=Color3.fromRGB(225,225,225),
            BackgroundColor3=Color3.fromRGB(52,65,82), BorderSizePixel=0, AutoButtonColor=true})
        make("UICorner", b, {CornerRadius=UDim.new(0,4)})
        return b
    end
    local function stopOrbit()
        if orbitDragging then
            orbitDragging=false
            if previousMouseBehavior then UserInputService.MouseBehavior=previousMouseBehavior end
            previousMouseBehavior=nil
        end
    end
    local function stopConnections()
        stopOrbit()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}; dragging = nil
    end
    local function clearScene()
        for _,guide in ipairs(guides) do guide:Destroy() end;guides={}
        for _, key in ipairs({"character", "weapon"}) do local object=scene[key]; if object and object.Destroy then pcall(function() object:Destroy() end) end end
        scene = {};sceneMode=nil
    end
    projectAxes=function()
        if not camera or not viewport then return end
        for _,guide in ipairs(guides) do
            local label=axisLabels[guide.Name]
            if label then
                local point=camera.CFrame:PointToObjectSpace(guide:GetAttribute("AxisEnd"))
                local size=viewport.AbsoluteSize
                local focal=size.Y/(2*math.tan(math.rad(camera.FieldOfView)/2))
                label.Visible=point.Z<-.1
                if label.Visible then label.Position=UDim2.fromOffset(size.X/2+point.X*focal/-point.Z,size.Y/2-point.Y*focal/-point.Z) end
            end
        end
    end
    local function updateAxes()
        for _,guide in ipairs(guides)do guide:Destroy()end;guides={}
        if not scene.weapon then return end
        local center=scene.weapon.CFrame.Position
        local basis=scene.axisFrame or scene.weapon.CFrame
        local frame=CFrame.new(center)*basis.Rotation
        local colors={X=Color3.fromRGB(255,100,100),Y=Color3.fromRGB(100,235,135),Z=Color3.fromRGB(100,160,255)}
        for _,axis in ipairs({"X","Y","Z"})do
            local delta=axis=="X" and Vector3.new(1.5,0,0) or axis=="Y" and Vector3.new(0,1.5,0) or Vector3.new(0,0,1.5)
            local endpoint=frame:PointToWorldSpace(delta)
            local rod=make("Part",worldModel,{Name=axis,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,Material=Enum.Material.Neon,Color=colors[axis],Size=Vector3.new(.045,.045,1.5),CFrame=CFrame.lookAt(center,endpoint)*CFrame.new(0,0,-.75)})
            rod:SetAttribute("AxisEnd",endpoint);guides[#guides+1]=rod
            if not axisLabels[axis] then
                local tag=label(viewport,axis,UDim2.fromOffset(24,24),colors[axis],18);tag.Name="AxisLabel"..axis;tag.AnchorPoint=Vector2.new(.5,.5);tag.ZIndex=7
                axisLabels[axis]=tag
            end
        end
        projectAxes()
    end
    local function updateCamera()
        if not camera then return end
        local target = cameraTarget or Vector3.new(0,2,0)
        pcall(function() camera.CFrame=CFrame.lookAt(target+Vector3.new(math.sin(cameraYaw or 0)*math.cos(cameraPitch or 0)*(cameraDistance or 8),math.sin(cameraPitch or 0)*(cameraDistance or 8),math.cos(cameraYaw or 0)*math.cos(cameraPitch or 0)*(cameraDistance or 8)),target) end)
        pcall(projectAxes)
    end
    persist=function(value, shouldPersist, targetMode)
        local ok, result = pcall(catalog.setWeaponAdjustment, entry.id, targetMode or mode, copy(value), shouldPersist)
        if not ok or result == false then status("Could not apply adjustment: "..tostring(result)); return false end
        return true
    end
    local function refreshScene()
        refreshPending=false
        if not persist(working,false) then return end
        if sceneMode==mode and scene.update then
            local ok,weapon=pcall(scene.update)
            if ok then scene.weapon=weapon;pcall(updateAxes);return end
        end
        clearScene()
        local ok,result=pcall(catalog.getEditorScene,entry.id,mode)
        if not ok or type(result)~="table" then status("Unable to load preview: "..tostring(result));return end
        scene=result;sceneMode=mode
        scene.character.Parent=worldModel
        if scene.weapon and not scene.weapon:IsDescendantOf(scene.character) then scene.weapon.Parent=worldModel end
        cameraTarget=scene.focus
        if not cameraTarget then pcall(function()cameraTarget=select(1,scene.character:GetBoundingBox()).Position end)end
        updateCamera();pcall(updateAxes)
    end
    local function queueRefresh()
        if refreshPending then return end
        refreshPending = true
        local token = openToken
        task.delay(0.05, function() if token == openToken and gui and gui.Parent then refreshScene() elseif token == openToken then refreshPending=false end end)
    end
    local function setValue(group, axis, value, released)
        working[group][axis] = value
        queueRefresh()
    end
    local function slider(parent, group, axis, minimum, maximum, step)
        local row = make("Frame", parent, {Name=group..axis,Size=UDim2.new(1,-14,0,38), BackgroundTransparency=1})
        label(row, axis, UDim2.fromOffset(28,30), ({X=Color3.fromRGB(255,145,145),Y=Color3.fromRGB(145,225,170),Z=Color3.fromRGB(145,185,255)})[axis], 13)
        local hit=make("TextButton",row,{Name="Slider",Position=UDim2.fromOffset(38,0),Size=UDim2.new(1,-100,0,34),Text="",BackgroundTransparency=1,AutoButtonColor=false})
        local track = make("Frame", hit, {Position=UDim2.fromOffset(0,14), Size=UDim2.new(1,0,0,6), BackgroundColor3=Color3.fromRGB(74,78,86), BorderSizePixel=0})
        local fill = make("Frame", track, {Size=UDim2.fromScale(0,1), BackgroundColor3=Color3.fromRGB(80,145,225), BorderSizePixel=0})
        local knob = make("TextButton", track, {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(0,.5), Size=UDim2.fromOffset(16,16), Text="", BackgroundColor3=Color3.fromRGB(225,230,235), BorderSizePixel=0})
        make("UICorner", knob, {CornerRadius=UDim.new(1,0)})
        local valueLabel = make("TextBox", row, {Name="Value",Size=UDim2.new(0,58,1,0),Position=UDim2.new(1,-58,0,0),BackgroundTransparency=1,ClearTextOnFocus=false,TextColor3=Color3.fromRGB(230,230,235),TextSize=11,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Right})
        local function paint(value)
            local ratio = math.clamp((value-minimum)/(maximum-minimum),0,1); fill.Size=UDim2.fromScale(ratio,1); knob.Position=UDim2.fromScale(ratio,.5); valueLabel.Text=string.format(step < 1 and "%.2f" or "%.0f",value)
        end
        local function update(input, released)
            if track.AbsoluteSize.X<=0 then return end
            local x = input.Position.X; local ratio = math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local value = math.floor((minimum+ratio*(maximum-minimum))/step+0.5)*step; value=math.clamp(value,minimum,maximum); paint(value); setValue(group,axis,value,released)
        end
        local function begin(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging={update=update,input=input}; update(input,false) end end
        connect(knob.InputBegan,begin); connect(hit.InputBegan,begin)
        connect(valueLabel.FocusLost,function() local value=tonumber(valueLabel.Text); if value and value==value and math.abs(value)<math.huge then value=math.clamp(math.floor(value/step+0.5)*step,minimum,maximum); paint(value); setValue(group,axis,value,true) else paint(working[group][axis]) end end)
        controls[group..axis]={paint=paint, minimum=minimum, maximum=maximum, step=step}
        return row
    end
    local function buildControls(parent)
        controls={}
        local order=1
        for _, spec in ipairs({{"Position","X",-3,3,.05},{"Position","Y",-3,3,.05},{"Position","Z",-3,3,.05},{"Rotation","X",-180,180,1},{"Rotation","Y",-180,180,1},{"Rotation","Z",-180,180,1},{"Scale","X",.25,2,.01},{"Scale","Y",.25,2,.01},{"Scale","Z",.25,2,.01}}) do
            if spec[2] == "X" then local titles={Position="Position  ·  studs",Rotation="Rotation  ·  degrees",Scale="Size  ·  scale"};local h=label(parent,titles[spec[1]],UDim2.new(1,0,0,24),Color3.fromRGB(120,175,235),13); h.LayoutOrder=order; order=order+1 end
            local row=slider(parent,spec[1],spec[2],spec[3],spec[4],spec[5]); row.LayoutOrder=order; order=order+1
        end
    end
    local function paintControls()
        for key, control in pairs(controls or {}) do local group, axis = key:match("^(%a+)(%a)$"); control.paint(working[group][axis]) end
    end
    local api = {}
    function api.open(newEntry, requestedMode)
        api.destroy();accepted=false; openToken=openToken+1; entry=newEntry; mode=requestedMode=="Held" and "Held" or "Holster"; original={Holster=adjustment(entry.adjustments and entry.adjustments.Holster),Held=adjustment(entry.adjustments and entry.adjustments.Held)}; workingByMode={Holster=copy(original.Holster),Held=copy(original.Held)}; working=workingByMode[mode]
        gui=make("ScreenGui",playerGui,{Name="HoneyBunWeaponEditor",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=100})
        local shade=make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.35,Active=true})
        local panel=make("Frame",shade,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.92,0,.9,0),BackgroundColor3=Color3.fromRGB(35,38,44),BorderSizePixel=0})
        make("UISizeConstraint",panel,{MinSize=Vector2.new(320,300),MaxSize=Vector2.new(900,640)})
        make("UICorner",panel,{CornerRadius=UDim.new(0,8)})
        make("Frame",panel,{Name="TitleBar",Size=UDim2.new(1,0,0,54),BackgroundColor3=Color3.fromRGB(0,100,170),BorderSizePixel=0})
        local title=label(panel,(entry.name or entry.Name or "Weapon").."  •  POSITION EDITOR",UDim2.new(1,-36,0,42),Color3.fromRGB(240,240,240),18);title.Position=UDim2.fromOffset(18,6);title.TextScaled=true
        make("UITextSizeConstraint",title,{MinTextSize=12,MaxTextSize=18})
        viewport=make("ViewportFrame",panel,{Ambient=Color3.fromRGB(180,180,190),LightColor=Color3.fromRGB(255,245,235),LightDirection=Vector3.new(-1,-1,-1),Position=UDim2.fromOffset(18,62),Size=UDim2.new(.46,-24,1,-116),BackgroundColor3=Color3.fromRGB(22,25,30),BorderSizePixel=0,Active=true}); worldModel=make("WorldModel",viewport,{}); camera=make("Camera",viewport,{}); viewport.CurrentCamera=camera
        pcall(function() camera.CFrame=CFrame.lookAt(Vector3.new(0,2,8),Vector3.new(0,2,0)) end)
        local right=make("ScrollingFrame",panel,{Position=UDim2.new(.46,8,0,62),Size=UDim2.new(.54,-26,1,-116),CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6})
        local layout=make("UIListLayout",right,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder}); make("UIPadding",right,{PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,8)})
        local tabs=make("Frame",right,{Size=UDim2.new(1,0,0,34),BackgroundTransparency=1,LayoutOrder=0}); local holster=button(tabs,"Hip / Back",UDim2.new(.49,0,1,0)); local held=button(tabs,"Holding",UDim2.new(.49,0,1,0)); held.Position=UDim2.new(.51,0,0,0)
        buildControls(right); statusLabel=label(viewport,"Right-click + drag to rotate. X: red · Y: green · Z: blue",UDim2.new(1,-20,0,42),Color3.fromRGB(215,225,240),12); statusLabel.Position=UDim2.fromOffset(10,8);statusLabel.TextWrapped=true;statusLabel.ZIndex=5
        local orbitLeft=button(viewport,"◀",UDim2.fromOffset(30,28)); orbitLeft.Position=UDim2.new(0,8,1,-36)
        local orbitRight=button(viewport,"▶",UDim2.fromOffset(30,28)); orbitRight.Position=UDim2.new(0,42,1,-36)
        local zoomOut=button(viewport,"−",UDim2.fromOffset(30,28)); zoomOut.Position=UDim2.new(0,76,1,-36)
        local zoomIn=button(viewport,"+",UDim2.fromOffset(30,28)); zoomIn.Position=UDim2.new(0,110,1,-36)
        cameraYaw,cameraDistance,cameraPitch=math.pi,8,0
        local function orbit(delta) cameraYaw=cameraYaw+delta; updateCamera() end
        connect(orbitLeft.Activated,function() orbit(-math.rad(15)) end); connect(orbitRight.Activated,function() orbit(math.rad(15)) end)
        connect(zoomOut.Activated,function() cameraDistance=math.min(14,cameraDistance+1); orbit(0) end); connect(zoomIn.Activated,function() cameraDistance=math.max(4,cameraDistance-1); orbit(0) end)
        local reset=button(panel,"Reset",UDim2.fromOffset(82,30)); reset.Position=UDim2.new(1,-307,1,-42); local cancel=button(panel,"Cancel",UDim2.fromOffset(82,30)); cancel.Position=UDim2.new(1,-215,1,-42); local done=button(panel,"Save / Done",UDim2.fromOffset(105,30)); done.Position=UDim2.new(1,-123,1,-42);done.Modal=true
        connect(viewport.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton2 and not dragging and not orbitDragging then
                previousMouseBehavior=UserInputService.MouseBehavior
                orbitDragging=true
                UserInputService.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
            end
        end)
        connect(UserInputService.WindowFocusReleased,stopOrbit)
        connect(UserInputService.InputChanged,function(input)
            if orbitDragging and input.UserInputType==Enum.UserInputType.MouseMovement then
                cameraYaw=cameraYaw-input.Delta.X*0.008
                cameraPitch=math.clamp(cameraPitch+input.Delta.Y*0.008,-math.rad(75),math.rad(75))
                updateCamera()
            end
            if dragging and (input==dragging.input or input.UserInputType==Enum.UserInputType.MouseMovement and dragging.input.UserInputType==Enum.UserInputType.MouseButton1) then dragging.update(input,false) end
        end)
        connect(UserInputService.InputEnded,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton2 then stopOrbit() end
            if dragging and (input==dragging.input or input.UserInputType==Enum.UserInputType.MouseButton1 and dragging.input.UserInputType==Enum.UserInputType.MouseButton1) then dragging=nil end
        end)
        local function paintModeButtons() holster.BackgroundColor3=mode=="Holster" and Color3.fromRGB(70,125,205) or Color3.fromRGB(52,65,82); held.BackgroundColor3=mode=="Held" and Color3.fromRGB(70,125,205) or Color3.fromRGB(52,65,82) end
        local function choose(nextMode) stopOrbit();dragging=nil;persist(working,false);workingByMode[mode]=working; mode=nextMode; working=workingByMode[mode]; paintModeButtons(); paintControls(); refreshScene(); end
        connect(holster.Activated,function() choose("Holster") end); connect(held.Activated,function() choose("Held") end)
        connect(reset.Activated,function() working=defaults(); paintControls(); persist(working,false); refreshScene(); status("Reset current mode") end)
        connect(cancel.Activated,function()local ok=true;for name,value in pairs(original)do if not persist(value,true,name)then ok=false end end;if ok then api.destroy()end end)
        connect(done.Activated,function() workingByMode[mode]=working; local ok=true; for name,value in pairs(workingByMode) do if not persist(value,true,name) then ok=false end end; if ok then accepted=true;api.destroy() end end)
        paintModeButtons(); refreshScene(); paintControls(); return api
    end
    function api.destroy()
        if entry and original and not accepted then for name,value in pairs(original) do persist(value,false,name) end end
        openToken=openToken+1;refreshPending=false; stopConnections(); clearScene(); if gui then pcall(function() gui:Destroy() end) end; gui=nil;axisLabels={}; viewport=nil; worldModel=nil; statusLabel=nil; entry=nil
    end
    return api
end
