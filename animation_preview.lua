-- Isolated, animated copy of the current avatar. Never plays on the real character.
local framingByCharacter=setmetatable({},{__mode="k"})
return function(viewport,player,source,onError)
    local alive,model,track=true,nil,nil
    local generation,playGeneration=0,0
    local animator
    local resetBounds=true
    local idle=true
    local currentId
    local sampleAfter=0
    local function refresh()
        playGeneration=playGeneration+1
        local ticket=playGeneration
        task.spawn(function()
            local ok,message=pcall(function()
                local ids,isIdle={},true
                if source then ids,isIdle=source() end
                if not alive or ticket~=playGeneration or not animator then return end
                local id=ids[1] and tostring(ids[1])
                if id and id:match("^%d+$") then id="rbxassetid://"..id end
                if currentId==id and idle==(isIdle==true) then return end
                idle=isIdle==true;currentId=id
                resetBounds=true;sampleAfter=os.clock()+0.25
                if track then track:Stop(0.15);track:Destroy();track=nil end
                if id then
                    local animation=Instance.new("Animation");animation.AnimationId=id
                    local nextTrack=animator:LoadAnimation(animation);animation:Destroy()
                    if not alive or ticket~=playGeneration then nextTrack:Destroy();return end
                    resetBounds=true
                    nextTrack.KeyframeReached:Connect(function()if poseChanged then poseChanged()end end)
                    nextTrack.DidLoop:Connect(function()if poseChanged then poseChanged()end end)
                    track=nextTrack;track.Priority=Enum.AnimationPriority.Action;track.Looped=true;track:Play(0.15)
                end
            end)
            if not ok and alive and ticket==playGeneration and onError then onError(tostring(message)) end
        end)
    end
    local resized
    local poseChanged
    local function clear()
        if track then pcall(function()track:Stop(0);track:Destroy()end);track=nil end
        for _,child in ipairs(viewport:GetChildren()) do child:Destroy() end
        model=nil;animator=nil;currentId=nil;poseChanged=nil
        if resized then resized:Disconnect();resized=nil end
        playGeneration=playGeneration+1
    end
    local function rebuild()
        generation=generation+1;local ticket=generation
        clear()
        task.spawn(function()
            local ok,message=pcall(function()
                local character=player.Character
                assert(character and character:FindFirstChild("HumanoidRootPart"),"Wait for your avatar to spawn.")
                local archivable=character.Archivable;character.Archivable=true
                local cloned,copy=pcall(function()return character:Clone()end)
                character.Archivable=archivable
                assert(cloned and copy,"Your avatar could not be displayed.")
                if not alive or generation~=ticket then copy:Destroy();return end
                for _,child in ipairs(copy:GetDescendants()) do
                    if child:IsA("LuaSourceContainer") or child:IsA("Sound") or child:IsA("Tool") then child:Destroy()
                    elseif child:IsA("BasePart") then child.CanCollide=false;child.CanTouch=false;child.CanQuery=false;child.Anchored=false end
                end
                local root=copy:FindFirstChild("HumanoidRootPart")
                assert(root,"Your avatar has no root part.")
                root.Anchored=true;copy.PrimaryPart=root;copy:PivotTo(CFrame.new())
                local world=Instance.new("WorldModel");world.Name="AnimationWorld";world.Parent=viewport
                copy.Parent=world;model=copy
                local humanoid=copy:FindFirstChildOfClass("Humanoid")
                assert(humanoid,"Your avatar has no Humanoid.")
                humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
                animator=humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator",humanoid)
                local bodyParts={}
                for _,part in ipairs(copy:GetDescendants()) do
                    if part:IsA("BasePart") and (part.Parent==copy or part.Parent:IsA("Accessory") and part.Size.Magnitude<6) then
                        bodyParts[#bodyParts+1]=part
                    end
                end
                local function bounds()
                    local minimum=Vector3.new(math.huge,math.huge,math.huge)
                    local maximum=Vector3.new(-math.huge,-math.huge,-math.huge)
                    for _,part in ipairs(bodyParts) do
                        for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                            local point=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)/2)
                            minimum=minimum:Min(point);maximum=maximum:Max(point)
                        end end end
                    end
                    return minimum,maximum
                end
                local minimum,maximum=bounds()
                local framing=framingByCharacter[character]
                if not framing then
                    framing={idleMin=minimum,idleMax=maximum}
                    framingByCharacter[character]=framing
                end
                local camera=Instance.new("Camera");camera.FieldOfView=35
                local target
                local function updateTarget()
                    if idle then
                        minimum,maximum=framing.idleMin,framing.idleMax
                    elseif os.clock()>=sampleAfter then
                        local low,high=bounds()
                        if resetBounds then minimum,maximum=low,high;resetBounds=false
                        else minimum=minimum:Min(low);maximum=maximum:Max(high) end
                    end
                    local center=(minimum+maximum)/2
                    local size=maximum-minimum
                    local aspect=math.max(0.1,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
                    local tangent=math.tan(math.rad(camera.FieldOfView/2))
                    local distance=math.max(size.Y/(0.76*tangent),size.X/(0.76*aspect*tangent))/2+size.Z/2
                    target=CFrame.lookAt(center+Vector3.new(0,0,-distance),center)
                end
                updateTarget()
                camera.CFrame=framing.camera or target
                poseChanged=function()
                    if not alive or generation~=ticket then return end
                    updateTarget()
                    game:GetService("TweenService"):Create(camera,TweenInfo.new(0.8),{CFrame=target}):Play()
                    framing.camera=target
                end
                resized=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(poseChanged)
                camera.Parent=viewport;viewport.CurrentCamera=camera
                viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.new(1,1,1)
                viewport.LightDirection=Vector3.new(-1,-1,-1)
                refresh()
            end)
            if not ok and alive and generation==ticket and onError then onError(tostring(message):gsub("^.-:%d+:%s*","")) end
        end)
    end
    local changed=player.CharacterAdded:Connect(function(character)
        task.spawn(function()
            character:WaitForChild("HumanoidRootPart",10)
            if alive then rebuild() end
        end)
    end)
    rebuild()
    return function()alive=false;generation=generation+1;changed:Disconnect();clear()end,refresh
end
