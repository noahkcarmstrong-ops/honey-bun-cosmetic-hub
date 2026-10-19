-- Local-only character previews. The returned data is plain tables and can be JSON encoded.
return function(player)
    -- Keep the serialized snapshot comfortably below characters.lua's 90 KB preview limit.
    local MAX_RECORDS, MAX_STRING, MAX_TOTAL_STRING = 96, 2048, 40000
    local visualClasses = {
        Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
        CornerWedgePart = true, TrussPart = true, SpecialMesh = true,
        Decal = true, Texture = true, SurfaceAppearance = true,
        Shirt = true, Pants = true, ShirtGraphic = true,
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
    local function set(instance, property, value)
        if value ~= nil then pcall(function() instance[property] = value end) end
    end
    local function hasToolAncestor(instance, character)
        local parent = read(instance, "Parent")
        while parent and parent ~= character do
            if read(parent, "ClassName") == "Tool" then return true end
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
        if topClass == "Accessory" or topClass == "Hat" then return true end
        if partClasses[topClass] then return read(top, "Name") ~= "HumanoidRootPart" end
        if top ~= instance then return false end
        return topClass == "Shirt" or topClass == "Pants" or topClass == "ShirtGraphic"
    end
    local function addCommon(record, instance)
        record.name = stringValue(read(instance, "Name"), 128) or "PreviewPart"
        local class = read(instance, "ClassName")
        if class then record.class = class end
        local transparency = read(instance, "Transparency")
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
    local function createRecord(record, parent)
        local meshFallback = record.class == "MeshPart" and record.meshId ~= nil
        local object = Instance.new(meshFallback and "Part" or record.class)
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
        elseif record.class == "ShirtGraphic" then set(object, "Graphic", record.template) end
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
    function api.capture()
        local character = player and read(player, "Character")
        assert(character, "Wait for your avatar to finish spawning")
        local root = (character.FindFirstChild and character:FindFirstChild("HumanoidRootPart")) or read(character, "PrimaryPart")
        assert(root, "Wait for your avatar to finish spawning")
        local records, indices = {}, {}
        local hasPart = false
        local descendants = character.GetDescendants and character:GetDescendants() or {}
        for _, instance in ipairs(descendants) do
            local class = read(instance, "ClassName")
            if visualClasses[class] and appearanceInstance(instance, character) and not hasToolAncestor(instance, character) and #records < MAX_RECORDS then
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
    function api.show(viewportFrame, data)
        local records = safeRecords(data)
        if not viewportFrame or not records then return false end
        for _, child in ipairs(viewportFrame:GetChildren()) do child:Destroy() end
        local world = Instance.new("WorldModel"); world.Name = "CharacterPreview"; world.Parent = viewportFrame
        local model = Instance.new("Model"); model.Name = "Avatar"; model.Parent = world
        local humanoid = Instance.new("Humanoid"); humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType and Enum.HumanoidDisplayDistanceType.None or nil; humanoid.AutoRotate = false
        humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false
        if (data.rigType=="R15" or data.rigType=="R6") and Enum.HumanoidRigType then humanoid.RigType=Enum.HumanoidRigType[data.rigType] end
        humanoid.Parent = model
        viewportFrame.Ambient=Color3.new(0.7,0.7,0.7);viewportFrame.LightColor=Color3.new(1,1,1)
        local made = {}
        for index, record in ipairs(records) do made[index] = createRecord(record, made[record.parent] or model) end
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
    return api
end
