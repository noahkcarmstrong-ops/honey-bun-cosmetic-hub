-- Run in a Roblox client: loadstring(testSource)(avatarSource).
-- A local synthetic model factory verifies batching without HTTP or live edits.
return function(source)
    local parts={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand",
        "RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot",
        "RightUpperLeg","RightLowerLeg","RightFoot"}
    local function rig(size)
        local model=Instance.new("Model")
        local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R15;h.Parent=model
        for _,name in ipairs(parts)do
            local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Size=Vector3.new(size,size,size);p.Parent=model
        end
        local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Parent=model
        return model
    end
    local character=rig(1)
    local event=Instance.new("BindableEvent")
    local p={Character=character,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
    local generated=0
    local players={CreateHumanoidModelFromDescriptionAsync=function(_,description)
        generated=generated+1
        assert(description.Head==1 and description.Torso==2 and description.LeftArm==3 and description.RightArm==4
            and description.LeftLeg==5 and description.RightLeg==6,"all six regions must share one request")
        return rig(2)
    end}
    local environment=setmetatable({game={GetService=function(_,name)
        if name=="Players"then return players end
        if name=="HttpService"then return game:GetService(name)end
        error("batch body must not issue extra metadata/preload requests: "..name)
    end}},{__index=getfenv()})
    local chunk=assert(loadstring(source));setfenv(chunk,environment)
    local api=chunk()(p,nil,nil,true)
    local body={Head=1,Torso=2,LeftArm=3,RightArm=4,LeftLeg=5,RightLeg=6}
    local head=character.Head
    api.applyBodyParts(body,{height=1})
    assert(generated==1 and character.Head==head and head.Size==Vector3.new(2,2,2),"one generation applies without replacing live parts")
    api.applyBodyParts(body,{height=1})
    assert(generated==1,"identical body reuses its cached template")
    api.applyBodyParts(body,{height=1.1})
    assert(generated==2,"changed scales invalidate the body cache")
    api.destroy()
    assert(head.Size==Vector3.new(1,1,1),"destroy restores original appearance")
    character:Destroy();event:Destroy()
    return "PASS: one generation for six regions, cache reuse, scale invalidation, part identity and restoration"
end
