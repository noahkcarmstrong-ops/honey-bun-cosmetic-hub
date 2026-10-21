-- Run in a Roblox client: loadstring(testSource)(previewsSource, nativeViewsSource).
-- Uses real CFrames/Instances with an isolated model factory; no avatar HTTP calls.
return function(previewsSource,nativeViewsSource)
    local function closeFrame(actual,expected)
        local a,b={actual:GetComponents()},{expected:GetComponents()}
        for i=1,12 do assert(math.abs(a[i]-b[i])<0.0001,"joint transform mismatch at component "..i)end
    end
    local first=assert(nativeViewsSource:find("    local bodyParts=",1,true))
    local last=assert(nativeViewsSource:find("    local function updateGeometry(",first,true))
    local cameraFunctions=assert(loadstring("return function(read,getPreviews)\nlocal nativeImageSources={}\n"
        ..nativeViewsSource:sub(first,last-1).."\nreturn frameCamera,matchPortraitMask\nend"))()
    local frameCamera,matchMask=cameraFunctions(function(o,k)return o[k]end,function()return {}end)
    for _,kind in ipairs({"Motor6D","AnimationConstraint"})do
        local model=Instance.new("Model")
        local function part(name,parent,position)
            local p=Instance.new("Part");p.Name=name;p.Size=Vector3.new(1,1,1)
            p.CFrame=CFrame.new(position);p.Anchored=true;p.Parent=parent;return p
        end
        local root=part("HumanoidRootPart",model,Vector3.new(100,50,-30))
        local head=part("Head",model,Vector3.new(-500,90,300))
        local accessory=Instance.new("Accessory");accessory.Parent=model
        local hat=part("Handle",accessory,Vector3.new(900,-20,200))
        local c0=CFrame.new(0,2,0)*CFrame.Angles(0.1,0.2,0)
        local c1=CFrame.new(0,-0.5,0)*CFrame.Angles(0,0,0.1)
        local transform=CFrame.Angles(0.05,-0.1,0)
        local joint=Instance.new(kind)
        if kind=="Motor6D" then
            joint.Part0=root;joint.Part1=head;joint.C0=c0;joint.C1=c1
        else
            local a=Instance.new("Attachment");a.CFrame=c0;a.Parent=root
            local b=Instance.new("Attachment");b.CFrame=c1;b.Parent=head
            joint.Attachment0=a;joint.Attachment1=b
        end
        joint.Transform=transform;joint.Parent=head
        local weld=Instance.new("Weld");weld.Part0=hat;weld.Part1=head
        weld.C0=CFrame.new(0,-0.2,0);weld.C1=CFrame.new(0,0.7,0);weld.Parent=hat
        local expectedHead=c0*transform*c1:Inverse()
        local expectedHat=expectedHead*weld.C1*weld.C0:Inverse()
        local environment=setmetatable({game={GetService=function(_,service)
            assert(service=="Players")
            return {CreateHumanoidModelFromDescriptionAsync=function()return model end}
        end}},{__index=getfenv()})
        local chunk=assert(loadstring(previewsSource));setfenv(chunk,environment)
        local api=chunk()({})
        local data=api.captureDescription({},Enum.HumanoidRigType.R15)
        assert(model.Parent==nil and #model:GetChildren()==0,"temporary rig must be destroyed")
        local headRecord,hatRecord
        for _,record in ipairs(data.records)do
            if record.name=="Head" then headRecord=record end
            if record.name=="Handle" then hatRecord=record end
        end
        assert(headRecord and hatRecord and hatRecord.headAccessory,"preserve head-attached accessory classification")
        closeFrame(CFrame.new(unpack(headRecord.cframe)),expectedHead)
        closeFrame(CFrame.new(unpack(hatRecord.cframe)),expectedHat)
        local image=Instance.new("ImageLabel")
        local people=Instance.new("Frame");people.Name="PeopleList";image.Parent=people
        image.Image="rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150"
        local overlay=Instance.new("CanvasGroup");overlay.Parent=image
        local view=Instance.new("ViewportFrame");view.Parent=overlay
        assert(api.show(view,data))
        local rendered=view:FindFirstChild("Avatar",true)
        assert(rendered.Handle:GetAttribute("LarpbloxPreviewHeadAccessory"),"headwear survives serialization")
        matchMask(image,overlay)
        assert(overlay:FindFirstChildOfClass("UICorner").CornerRadius==UDim.new(0.5,0),"People headshots need a circular mask")
        frameCamera(view,image)
        local camera=view.CurrentCamera
        for _,p in ipairs({rendered.Head,rendered.Handle})do
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                local v=camera.CFrame:PointToObjectSpace(p.CFrame*Vector3.new(p.Size.X*x/2,p.Size.Y*y/2,p.Size.Z*z/2))
                assert(v.Z<0 and math.sqrt(v.X^2+v.Y^2)/(-v.Z*math.tan(math.rad(camera.FieldOfView/2)))<0.95,
                    "head and hat must fit inside the circular crop")
            end end end
        end
        local native=Instance.new("UICorner");native.CornerRadius=UDim.new(0,7);native.Parent=image
        matchMask(image,overlay)
        assert(overlay:FindFirstChildOfClass("UICorner").CornerRadius==native.CornerRadius,"preserve explicit native corner")
        native:Destroy();image.Parent=nil;matchMask(image,overlay)
        assert(not overlay:FindFirstChildOfClass("UICorner"),"do not force circles outside People")
        api.destroy();image:Destroy();people:Destroy()
    end
    return "PASS: legacy and animation joints, head/hat offsets, accessory metadata, circular framing and native masks"
end
