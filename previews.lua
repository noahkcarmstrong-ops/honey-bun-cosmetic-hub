-- Local-only character previews. The returned data is plain tables and can be JSON encoded.
return function(player)
    -- Keep the serialized snapshot comfortably below characters.lua's 90 KB preview limit.
    local MAX_RECORDS, MAX_STRING, MAX_TOTAL_STRING = 96, 2048, 40000
    local visualClasses = {
        Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
        CornerWedgePart = true, TrussPart = true, SpecialMesh = true,
        Decal = true, Texture = true, SurfaceAppearance = true,
        Shirt = true, Pants = true, ShirtGraphic = true, CharacterMesh = true,
    }
    local partClasses = {Part=true, MeshPart=true, UnionOperation=true, WedgePart=true,
        CornerWedgePart=true, TrussPart=true}
    local meshClasses = {SpecialMesh=true}
    local function finite(n)
        return type(n) == "number" and n == n and math.abs(n) < 1e9
    end
    local function stringValue(value, limit)
        if type(value) ~= "string" then return nil end
        if #value > (limit or MAX_STRING) then return nil end
        return value
    end
    local function vec(value)
        if not value then return nil end
        local ok, x, y, z = pcall(function() return value.X, value.Y, value.Z end)
        if ok and finite(x) and finite(y) and finite(z) then return {x, y, z} end
    end
    local function color(value)
        if not value then return nil end
        local ok, r, g, b = pcall(function() return value.R, value.G, value.B end)
        if ok and finite(r) and finite(g) and finite(b) then return {r, g, b} end
    end
    local function enumName(value, fallback)
        local text = value and tostring(value)
        return text and text:match("([%w_]+)$") or fallback
    end
    local function cframe(value)
        if not value then return nil end
        local ok, values = pcall(function()
            local out = {value:GetComponents()}
            return out
        end)
        if not ok or #values ~= 12 then return nil end
        for i = 1, 12 do if not finite(values[i]) then return nil end end
        return values
    end
    local function read(instance, property)
        local ok, value = pcall(function() return instance[property] end)
        return ok and value or nil
    end
    local function hubGear(instance)
        local ok,value=pcall(function() return instance:GetAttribute("LarpbloxHubGear") end)
        return ok and value==true
    end
    local function set(instance, property, value)
        if value ~= nil then pcall(function() instance[property] = value end) end
    end
    local function hasForeignToolAncestor(instance, character)
        local parent = read(instance, "Parent")
        while parent and parent ~= character do
            if read(parent, "ClassName") == "Tool" then return not hubGear(parent) end
            parent = read(parent, "Parent")
        end
        return false
    end
    local function appearanceInstance(instance, character)
        local parent = read(instance, "Parent")
        local top = instance
        while parent and parent ~= character do
            top, parent = parent, read(parent, "Parent")
        end
        local topClass = read(top, "ClassName")
        if topClass == "Tool" then return hubGear(top) end
        if topClass == "Accessory" or topClass == "Hat" then return true end
        if partClasses[topClass] then return read(top, "Name") ~= "HumanoidRootPart" end
        if top ~= instance then return false end
        return topClass == "Shirt" or topClass == "Pants" or topClass == "ShirtGraphic" or topClass == "CharacterMesh"
    end
    local function addCommon(record, instance)
        record.name = stringValue(read(instance, "Name"), 128) or "PreviewPart"
        local class = read(instance, "ClassName")
        if class then record.class = class end
        local transparency = read(instance, "Transparency")
        local localTransparency = read(instance, "LocalTransparencyModifier")
        if finite(localTransparency) then
            local base=math.min(1,math.max(0,transparency or 0))
            local modifier=math.min(1,math.max(0,localTransparency))
            transparency=1-(1-base)*(1-modifier)
        end
        if finite(transparency) then record.transparency = transparency end
        local tint = color(read(instance, "Color3"))
        if tint then record.color = tint end
    end
    local function capturePart(record, instance, root)
        addCommon(record, instance)
        record.color = color(read(instance, "Color")) or record.color
        record.size = vec(read(instance, "Size"))
        local partCFrame = read(instance, "CFrame")
        local rootCFrame = read(root, "CFrame")
        if partCFrame and rootCFrame then
            local ok, relative = pcall(function() return rootCFrame:ToObjectSpace(partCFrame) end)
            record.cframe = cframe(ok and relative or partCFrame)
        else
            record.cframe = cframe(partCFrame)
        end
        local material = read(instance, "Material")
        if material then record.material = enumName(material) end
        local reflectance = read(instance, "Reflectance")
        if finite(reflectance) then record.reflectance = reflectance end
        local shape = read(instance, "Shape")
        if shape then record.shape = enumName(shape) end
        record.textureId = stringValue(read(instance, "TextureID"))
        record.meshId = stringValue(read(instance, "MeshId"))
        record.meshSize = vec(read(instance, "MeshSize"))
    end
    local function capture(instance, root, parent)
        local class = read(instance, "ClassName")
        local record = {class = class, parent = parent}
        if partClasses[class] then
            capturePart(record, instance, root)
        elseif meshClasses[class] then
            addCommon(record, instance)
            record.meshId = stringValue(read(instance, "MeshId"))
            record.textureId = stringValue(read(instance, "TextureId"))
            record.scale, record.offset, record.vertexColor = vec(read(instance, "Scale")), vec(read(instance, "Offset")), vec(read(instance, "VertexColor"))
            record.meshType = enumName(read(instance, "MeshType"), "FileMesh")
        elseif class == "Decal" or class == "Texture" then
            addCommon(record, instance)
            record.texture = stringValue(read(instance, "Texture"))
            record.face = enumName(read(instance, "Face"), "Front")
            if class == "Texture" then
                local studsU, studsV = read(instance, "StudsPerTileU"), read(instance, "StudsPerTileV")
                if finite(studsU) then record.studsU = studsU end
                if finite(studsV) then record.studsV = studsV end
            end
        elseif class == "SurfaceAppearance" then
            addCommon(record, instance)
            record.colorMap = stringValue(read(instance, "ColorMap"))
            record.metalnessMap = stringValue(read(instance, "MetalnessMap"))
            record.normalMap = stringValue(read(instance, "NormalMap"))
            record.roughnessMap = stringValue(read(instance, "RoughnessMap"))
            record.alphaMode = tostring(read(instance, "AlphaMode") or "Overlay")
        elseif class == "CharacterMesh" then
            addCommon(record, instance)
            record.bodyPart = enumName(read(instance, "BodyPart"))
            record.meshId = tostring(read(instance, "MeshId") or 0)
            record.baseTextureId = tostring(read(instance, "BaseTextureId") or 0)
            record.overlayTextureId = tostring(read(instance, "OverlayTextureId") or 0)
        else
            addCommon(record, instance)
            record.template = stringValue(read(instance, "ShirtTemplate") or read(instance, "PantsTemplate") or read(instance, "Graphic"))
        end
        return record
    end
    local function safeRecords(data)
        if type(data) ~= "table" or data.version~=1 or type(data.records) ~= "table" or #data.records==0 or #data.records > MAX_RECORDS then return nil end
        local totalString = 0
        for index, record in ipairs(data.records) do
            if type(record) ~= "table" or type(record.class) ~= "string" or not visualClasses[record.class] then return nil end
            if record.parent ~= nil and (not finite(record.parent) or record.parent ~= math.floor(record.parent) or record.parent < 0 or record.parent >= index) then return nil end
            if partClasses[record.class] and (type(record.size) ~= "table" or #record.size ~= 3 or type(record.cframe) ~= "table" or #record.cframe ~= 12) then return nil end
            if partClasses[record.class] then
                for i = 1, 3 do if not finite(record.size[i]) or record.size[i] <= 0 or record.size[i] > 1000 then return nil end end
                for i = 1, 3 do if not finite(record.cframe[i]) or math.abs(record.cframe[i]) > 10000 then return nil end end
                if record.meshSize then
                    for i=1,3 do if not finite(record.meshSize[i]) or record.meshSize[i]<=0 then return nil end end
                end
            end
            for key, value in pairs(record) do
                if type(value) == "string" then
                    if #value > MAX_STRING then return nil end
                    totalString = totalString + #value
                end
                if type(value) == "number" and not finite(value) then return nil end
                if key == "cframe" or key == "size" or key == "scale" or key == "offset" or key == "color" or key == "vertexColor" or key == "meshSize" then
                    if type(value) == "table" then
                        local expected = key == "cframe" and 12 or 3
                        if #value ~= expected then return nil end
                        for _, number in ipairs(value) do if not finite(number) then return nil end end
                    end
                end
            end
        end
        if totalString > MAX_TOTAL_STRING then return nil end
        return data.records
    end
    local alive=true
    local meshSources,meshFailures,meshPending,meshOrder={},{},{},{}
    local shows=setmetatable({}, {__mode="k"})
    local function cleanMesh(source)
        local ok,copy=pcall(function()return source:Clone()end)
        if not ok or not copy then return nil end
        for _,child in ipairs(copy:GetChildren())do child:Destroy()end
        return copy
    end
    local function rememberMesh(id,source)
        if not meshSources[id] then meshOrder[#meshOrder+1]=id end
        if meshSources[id] and meshSources[id]~=source then meshSources[id]:Destroy() end
        meshSources[id]=source
        if #meshOrder>MAX_RECORDS then
            local oldest=table.remove(meshOrder,1)
            if meshSources[oldest] then meshSources[oldest]:Destroy();meshSources[oldest]=nil end
        end
    end
    local function nativeMesh(record)
        local id=record.meshId
        if not id or not alive then return nil end
        if meshSources[id] then return cleanMesh(meshSources[id]) end
        local character=player and read(player,"Character")
        for _,part in ipairs(character and character:GetDescendants() or {})do
            if read(part,"ClassName")=="MeshPart" and read(part,"MeshId")==id then
                local copy=cleanMesh(part)
                if copy then rememberMesh(id,copy);return cleanMesh(copy) end
            end
        end
        if meshFailures[id] then return nil end
        if meshPending[id] then
            if not task or not task.wait then return nil end
            while alive and meshPending[id]do task.wait()end
            return alive and meshSources[id] and cleanMesh(meshSources[id]) or nil
        end
        meshPending[id]=true
        local ok,source=pcall(function()
            local content=Content and Content.fromUri and Content.fromUri(id) or id
            return game:GetService("AssetService"):CreateMeshPartAsync(content,{})
        end)
        meshPending[id]=nil
        if not alive then if ok and source then source:Destroy()end;return nil end
        if ok and source and read(source,"ClassName")=="MeshPart" then
            for _,child in ipairs(source:GetChildren())do child:Destroy()end
            rememberMesh(id,source);return cleanMesh(source)
        end
        meshFailures[id]=true
    end
    local function createRecord(record, parent, current)
        local native=record.class=="MeshPart" and nativeMesh(record)
        local meshFallback = record.class == "MeshPart" and record.meshId ~= nil and not native
        local object = native or Instance.new(meshFallback and "Part" or record.class)
        if current and not current() then object:Destroy();return nil end
        set(object, "Name", stringValue(record.name, 128) or record.class)
        if partClasses[record.class] then
            set(object, "Size", record.size and Vector3.new(record.size[1], record.size[2], record.size[3]))
            if record.cframe and #record.cframe == 12 then
                local unpacker = table.unpack or unpack
                set(object, "CFrame", CFrame.new(unpacker(record.cframe)))
            end
            if record.color then set(object, "Color", Color3.new(record.color[1], record.color[2], record.color[3])) end
            set(object, "Transparency", record.transparency)
            set(object, "Reflectance", record.reflectance)
            set(object, "TextureID", record.textureId)
            if record.material and Enum.Material then set(object, "Material", Enum.Material[record.material]) end
            if record.shape and Enum.PartType then set(object, "Shape", Enum.PartType[record.shape]) end
        elseif record.class == "SpecialMesh" then
            set(object, "MeshId", record.meshId); set(object, "TextureId", record.textureId)
            if record.meshType and Enum.MeshType then set(object, "MeshType", Enum.MeshType[record.meshType]) end
            if record.scale then set(object, "Scale", Vector3.new(record.scale[1], record.scale[2], record.scale[3])) end
            if record.offset then set(object, "Offset", Vector3.new(record.offset[1], record.offset[2], record.offset[3])) end
            if record.vertexColor then set(object, "VertexColor", Vector3.new(record.vertexColor[1], record.vertexColor[2], record.vertexColor[3])) end
        elseif record.class == "Decal" or record.class == "Texture" then
            set(object, "Texture", record.texture); set(object, "Face", Enum.NormalId[record.face] or Enum.NormalId.Front)
            set(object, "Transparency", record.transparency)
            if record.class == "Texture" then set(object, "StudsPerTileU", record.studsU); set(object, "StudsPerTileV", record.studsV) end
        elseif record.class == "SurfaceAppearance" then
            set(object, "ColorMap", record.colorMap); set(object, "MetalnessMap", record.metalnessMap)
            set(object, "NormalMap", record.normalMap); set(object, "RoughnessMap", record.roughnessMap)
        elseif record.class == "Shirt" then set(object, "ShirtTemplate", record.template)
        elseif record.class == "Pants" then set(object, "PantsTemplate", record.template)
        elseif record.class == "ShirtGraphic" then set(object, "Graphic", record.template)
        elseif record.class == "CharacterMesh" then
            if record.bodyPart and Enum.BodyPart then set(object, "BodyPart", Enum.BodyPart[record.bodyPart]) end
            set(object, "MeshId", tonumber(record.meshId))
            set(object, "BaseTextureId", tonumber(record.baseTextureId))
            set(object, "OverlayTextureId", tonumber(record.overlayTextureId))
        end
        object.Parent = parent
        if partClasses[record.class] then object.Anchored = true; object.CanCollide = false end
        if meshFallback then
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType and Enum.MeshType.FileMesh or nil
            mesh.MeshId = record.meshId
            mesh.TextureId = record.textureId
            if record.meshSize then mesh.Scale = Vector3.new(record.size[1]/record.meshSize[1], record.size[2]/record.meshSize[2], record.size[3]/record.meshSize[3]) end
            mesh.Parent = object
        end
        return object
    end
    local api = {}
    local function captureCharacter(character)
        assert(character, "Wait for your avatar to finish spawning")
        local root = (character.FindFirstChild and character:FindFirstChild("HumanoidRootPart")) or read(character, "PrimaryPart")
        assert(root, "Wait for your avatar to finish spawning")
        local records, indices = {}, {}
        local hasPart = false
        local descendants = character.GetDescendants and character:GetDescendants() or {}
        -- Reserve room for saved clothes even on avatars with many accessory parts.
        local ordered={}
        for _,instance in ipairs(descendants)do
            local class=read(instance,"ClassName")
            if class=="Shirt" or class=="Pants" or class=="ShirtGraphic" then ordered[#ordered+1]=instance end
        end
        for _,instance in ipairs(descendants)do
            local class=read(instance,"ClassName")
            if class~="Shirt" and class~="Pants" and class~="ShirtGraphic" then ordered[#ordered+1]=instance end
        end
        for _, instance in ipairs(ordered) do
            local class = read(instance, "ClassName")
            if visualClasses[class] and appearanceInstance(instance, character) and not hasForeignToolAncestor(instance, character) and #records < MAX_RECORDS then
                local parent = indices[read(instance, "Parent")] or 0
                local record = capture(instance, root, parent)
                if record.class == "Part" or record.class == "MeshPart" or record.class == "UnionOperation" or record.class == "WedgePart" or record.class == "CornerWedgePart" or record.class == "TrussPart" then
                    if record.cframe and record.size then table.insert(records, record); indices[instance] = #records; hasPart = true end
                else
                    table.insert(records, record); indices[instance] = #records
                end
            end
        end
        assert(hasPart, "Wait for your avatar to finish spawning")
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        return {version = 1, records = records,rigType=humanoid and enumName(humanoid.RigType) or nil}
    end
    function api.capture()
        return captureCharacter(player and read(player,"Character"))
    end
    function api.captureDescription(description,rigType)
        assert(alive,"Preview renderer was closed.")
        local model=game:GetService("Players"):CreateHumanoidModelFromDescriptionAsync(description,rigType)
        local ok,result=pcall(function()
            assert(alive,"Preview renderer was closed.")
            for _,part in ipairs(model:GetDescendants()) do
                if part:IsA("MeshPart") and part.MeshId~="" then
                    local copy=cleanMesh(part)
                    if copy then rememberMesh(part.MeshId,copy) end
                end
            end
            return captureCharacter(model)
        end)
        model:Destroy()
        if not ok then error(result) end
        return result
    end
    function api.show(viewportFrame, data)
        local records = safeRecords(data)
        if not alive or not viewportFrame or not records then return false end
        local ticket={};shows[viewportFrame]=ticket
        local viewportParent=viewportFrame.Parent
        for _, child in ipairs(viewportFrame:GetChildren()) do child:Destroy() end
        local world = Instance.new("WorldModel"); world.Name = "CharacterPreview"; world.Parent = viewportFrame
        local model = Instance.new("Model"); model.Name = "Avatar"; model.Parent = world
        local humanoid = Instance.new("Humanoid"); humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType and Enum.HumanoidDisplayDistanceType.None or nil; humanoid.AutoRotate = false
        humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false
        if (data.rigType=="R15" or data.rigType=="R6") and Enum.HumanoidRigType then humanoid.RigType=Enum.HumanoidRigType[data.rigType] end
        viewportFrame.Ambient=Color3.new(0.7,0.7,0.7);viewportFrame.LightColor=Color3.new(1,1,1)
        local made = {}
        local function current()
            return alive and shows[viewportFrame]==ticket and viewportFrame.Parent==viewportParent and world.Parent==viewportFrame
        end
        for index, record in ipairs(records) do
            local object=createRecord(record,made[record.parent] or model,current)
            if not object or not current() then
                if object then object:Destroy()end
                humanoid:Destroy();world:Destroy();return false
            end
            made[index]=object
        end
        local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1)
        root.CFrame=CFrame.new(0,0,0);root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.Parent=model
        model.PrimaryPart=root
        if not data.rigType then
            local rig=model:FindFirstChild("UpperTorso") and "R15" or "R6"
            if Enum.HumanoidRigType then humanoid.RigType=Enum.HumanoidRigType[rig] end
        end
        -- Let the Humanoid discover a complete body and its saved clothing together.
        humanoid.Parent=model
        local camera = Instance.new("Camera"); camera.Name = "PreviewCamera"; camera.Parent = viewportFrame; viewportFrame.CurrentCamera = camera
        local minX, minY, minZ, maxX, maxY, maxZ = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
        for index, record in ipairs(records) do
            if partClasses[record.class] then
                local object = made[index]
                local position = read(object, "Position") or (read(object, "CFrame") and read(object, "CFrame").Position)
                local size = read(object, "Size")
                if position and size then
                    minX, minY, minZ = math.min(minX, position.X-size.X/2), math.min(minY, position.Y-size.Y/2), math.min(minZ, position.Z-size.Z/2)
                    maxX, maxY, maxZ = math.max(maxX, position.X+size.X/2), math.max(maxY, position.Y+size.Y/2), math.max(maxZ, position.Z+size.Z/2)
                end
            end
        end
        if minX == math.huge then minX, minY, minZ, maxX, maxY, maxZ = -1, 0, -1, 1, 6, 1 end
        local center = Vector3.new((minX+maxX)/2, (minY+maxY)/2, (minZ+maxZ)/2)
        local extent = math.max(maxX-minX, maxY-minY, maxZ-minZ, 1)
        local fov = 35; camera.FieldOfView = fov
        local aspect = 1
        local viewportSize = read(viewportFrame, "AbsoluteSize")
        if viewportSize and finite(viewportSize.X) and finite(viewportSize.Y) and viewportSize.Y > 0 then aspect = math.max(viewportSize.X / viewportSize.Y, 0.1) end
        local halfAngle = math.tan(math.rad(fov/2)); local fit = math.max((maxY-minY)/2, (maxX-minX)/(2*aspect), extent/10)
        local distance = fit / math.max(halfAngle, 0.01) * 1.25
        local position = Vector3.new(center.X, center.Y, center.Z-distance)
        camera.CFrame = CFrame.lookAt and CFrame.lookAt(position, center) or CFrame.new(position, center)
        return true
    end
    -- Static presentation shared by native People cards and avatar inspection.
    function api.poseThumbnail(frame)
        local model=frame:FindFirstChild("Avatar",true)
        if not model then return end
        local function transform(names,pivot,rotation)
            local delta=CFrame.new(pivot)*rotation*CFrame.new(-pivot)
            for _,name in ipairs(names) do
                local part=model:FindFirstChild(name)
                if part then part.CFrame=delta*part.CFrame end
            end
        end
        for _,side in ipairs({"Left","Right"}) do
            local upper=model:FindFirstChild(side.."UpperArm")
            local lower=model:FindFirstChild(side.."LowerArm")
            if upper then
                local pivot=upper.CFrame:PointToWorldSpace(Vector3.new(0,upper.Size.Y/2,0))
                transform({side.."UpperArm",side.."LowerArm",side.."Hand"},pivot,
                    CFrame.Angles(0,0,math.rad(side=="Left" and -9 or 9)))
            end
            if lower then
                local pivot=lower.CFrame:PointToWorldSpace(Vector3.new(0,lower.Size.Y/2,0))
                transform({side.."LowerArm",side.."Hand"},pivot,CFrame.Angles(math.rad(12),0,0))
            end
        end
        frame.Ambient=Color3.new(0.55,0.55,0.55)
        frame.LightColor=Color3.new(0.85,0.85,0.85)
        frame.LightDirection=Vector3.new(-1,-1,-2)
    end
    function api.frameThumbnail(frame,options)
        local model=frame:FindFirstChild("Avatar",true)
        local camera=frame.CurrentCamera
        if not (model and camera) then return end
        options=options or {}
        local min,max
        local points={}
        local bodyParts={Head=true,Torso=true,UpperTorso=true,LowerTorso=true,
            ["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,
            LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
            LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}
        for _,part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and (bodyParts[part.Name] or
                (options.includeAccessories and part.Name~="HumanoidRootPart" and part.Transparency<1)) then
                for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                    local point=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X*x/2,part.Size.Y*y/2,part.Size.Z*z/2))
                    points[#points+1]=point
                    min=min and Vector3.new(math.min(min.X,point.X),math.min(min.Y,point.Y),math.min(min.Z,point.Z)) or point
                    max=max and Vector3.new(math.max(max.X,point.X),math.max(max.Y,point.Y),math.max(max.Z,point.Z)) or point
                end end end
            end
        end
        if not min then return end
        local center=(min+max)/2
        local absolute=frame.AbsoluteSize
        local aspect=absolute.Y>0 and math.max(absolute.X/absolute.Y,0.1) or 1
        camera.FieldOfView=35
        local tangent=math.tan(math.rad(camera.FieldOfView/2))
        local direction=Vector3.new(math.sin(math.rad(18)),0.06,-math.cos(math.rad(18))).Unit
        local basis=CFrame.lookAt(center,center-direction)
        local distance=1
        for _,point in ipairs(points) do
            local relative=basis:PointToObjectSpace(point)
            distance=math.max(distance,relative.Z+math.max(math.abs(relative.X)/(tangent*aspect),math.abs(relative.Y)/tangent)*(options.padding or 1.15))
        end
        camera.CFrame=CFrame.lookAt(center+direction*distance,center)
    end
    function api.destroy()
        alive=false
        for _,source in pairs(meshSources)do source:Destroy()end
        meshSources={};meshFailures={};meshOrder={}
    end
    return api
end
