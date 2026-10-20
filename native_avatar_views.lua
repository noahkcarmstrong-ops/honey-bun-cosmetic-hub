-- Adds the local player's live appearance to Roblox's own player-list thumbnails.
-- Restores native images when its local preview is disabled.
local function read(object, key)
    local ok, value = pcall(function() return object and object[key] end)
    return ok and value or nil
end

local function ancestors(object)
    local result, current = {}, object
    while current do result[#result + 1] = current; current = read(current, "Parent") end
    return result
end

local function attr(object, key)
    local ok, value = pcall(function() return object:GetAttribute(key) end)
    return ok and value or nil
end

local function hasOwnId(object, player)
    local id = tostring(read(player, "UserId") or "")
    if id == "" then return false end
    for _, item in ipairs(ancestors(object)) do
        local name = tostring(read(item, "Name") or "")
        if name == id or name == "PlayerEntry_" .. id or name == "p_" .. id
            or name == "PlayerLabel" .. tostring(read(player, "Name") or "") then return true end
        for _, key in ipairs({"UserId", "UserID", "PlayerId", "playerId"}) do
            if tostring(attr(item, key) or "") == id then return true end
        end
    end
    return false
end

local function plainText(value)
    return tostring(value or ""):gsub("<[^>]->", "")
end

local function uniquePeopleRow(object, player, options)
    local username = tostring(options and options.name or "")
    local realUsername = tostring(read(player, "Name") or "")
    local accepted = {}
    if username ~= "" then accepted["@" .. username] = true end
    if realUsername ~= "" then accepted["@" .. realUsername] = true end
    if next(accepted) == nil then return false end
    local path = ancestors(object)
    local inPeople=false
    for _,ancestor in ipairs(path)do
        if tostring(read(ancestor,"Name") or ""):lower():find("people",1,true)then inPeople=true;break end
    end
    if not inPeople then return false end
    for depth=2,math.min(#path,6)do
        local row=path[depth]
        local descendants=read(row,"GetDescendants") and row:GetDescendants() or {}
        if #descendants>120 then break end
        local found,other,texts=false,false,0
        for _,child in ipairs(descendants)do
            local class=read(child,"ClassName")
            if class=="TextLabel" or class=="TextButton" then
                texts=texts+1
                local text=plainText(read(child,"Text"))
                if accepted[text] then found=true
                elseif text:match("^@[%w_]+$")then other=true end
            end
        end
        if found and not other and texts<=8 then return true end
    end
    return false
end

local function imageIsAvatar(object, player)
    local image = tostring(read(object, "Image") or "")
    local id = tostring(read(player, "UserId") or "")
    -- AvatarHeadShot thumbnails are unambiguous, even when Roblox changes row names.
    if image:match("^rbxthumb://") and image:lower():find("type=avatarheadshot", 1, true)
        and (image:match("[?&]id=" .. id .. "[&]") or image:match("[?&]id=" .. id .. "$")) then return true end
    return false
end

local function isAvatarImage(object, player, options)
    local class = read(object, "ClassName")
    if class ~= "ImageLabel" and class ~= "ImageButton" then return false end
    local name = tostring(read(object, "Name") or ""):lower()
    local namedThumbnail = name == "avatar" or name == "avatarimage" or name == "headshot"
        or name == "avatarthumbnail" or name == "thumbnail"
    if imageIsAvatar(object, player) then return true end
    if namedThumbnail and hasOwnId(object, player) then return true end
    return namedThumbnail and uniquePeopleRow(object, player, options)
end

local function signature(value, seen)
    if type(value) ~= "table" then return tostring(value) end
    seen = seen or {}; if seen[value] then return "<cycle>" end; seen[value] = true
    local keys = {}; for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}; for _, key in ipairs(keys) do out[#out + 1] = tostring(key) .. "=" .. signature(value[key], seen) end
    return "{" .. table.concat(out, ";") .. "}"
end

local M = {isAvatarImage = isAvatarImage, hasOwnId = hasOwnId}

function M.create(player, getPreviews)
    assert(player, "player is required"); assert(type(getPreviews) == "function", "getPreviews is required")
    local alive, enabled, currentName, currentImage, previewSnapshot, effectiveKey = true, false, "", nil, nil, nil
    local overlays, overlayKeys, originalTransparency, hiddenImages, connections, scanCount, renderedCount = {}, {}, {}, {}, {}, 0, 0
    local transparencyConnections,textConnections={},{}
    local coreGui, available
    local status = "Native avatar thumbnails are disabled."

    local function restoreImage(image)
        if hiddenImages[image] then
            pcall(function() image.ImageTransparency = originalTransparency[image] end)
            originalTransparency[image] = nil; hiddenImages[image] = nil
        end
    end
    local function hideImage(image)
        if not hiddenImages[image] then originalTransparency[image] = read(image, "ImageTransparency"); hiddenImages[image] = true end
        pcall(function() image.ImageTransparency = 1 end)
    end
    local function restoreAllImages()
        for image in pairs(hiddenImages) do restoreImage(image) end
    end
    local function destroyOverlay(image, restore)
        local overlay = overlays[image]
        if overlay then pcall(function() overlay:Destroy() end); overlays[image] = nil; overlayKeys[image] = nil end
        if restore ~= false then restoreImage(image) end
    end
    local function frameCamera(frame)
        local world = read(frame, "FindFirstChild") and frame:FindFirstChild("CharacterPreview")
        local model = world and world:FindFirstChild("Avatar")
        local head = model and model:FindFirstChild("Head", true)
        local camera = frame and frame.CurrentCamera
        if not (head and camera) then return end
        local position, size = head.Position, head.Size
        if not (position and size and CFrame and CFrame.lookAt) then return end
        local distance = math.max(size.X, size.Y, size.Z, 1) * 2.5
        pcall(function() camera.CFrame = CFrame.lookAt(position + Vector3.new(0, 0, -distance), position) end)
    end
    local function makeOverlay(image, imageSource)
        local overlay = overlays[image]
        local class = imageSource and "ImageLabel" or "ViewportFrame"
        if overlay and (read(overlay, "Parent") ~= image or read(overlay, "ClassName") ~= class) then
            pcall(function() overlay:Destroy() end); overlays[image] = nil; overlayKeys[image] = nil; overlay = nil
        end
        if overlay then return overlay end
        overlay = Instance.new(class)
        overlay.Name = "LarpbloxOwnAvatarPreview"
        overlay.Position = UDim2.fromScale(0, 0); overlay.Size = UDim2.fromScale(1, 1)
        overlay.BackgroundTransparency = 1; overlay.BorderSizePixel = 0
        overlay.Visible = false
        overlay.ZIndex = (read(image, "ZIndex") or 1) + 1; overlay.Parent = image
        if imageSource then overlay.Image = imageSource end
        overlays[image] = overlay
        return overlay
    end
    local function render(image)
        hideImage(image)
        if not previewSnapshot and not currentImage then return end
        if overlays[image] and overlayKeys[image] == effectiveKey then return end
        if currentImage then
            local overlay = makeOverlay(image, currentImage)
            overlay.Image = currentImage; overlayKeys[image] = effectiveKey; renderedCount = renderedCount + 1
            pcall(function() overlay.Visible = true end)
            return
        end
        local ok, previews = pcall(getPreviews)
        if not ok or not previews or type(previews.show) ~= "function" then status = "Preview renderer unavailable."; return end
        local overlay = makeOverlay(image)
        local shown, result = pcall(function() return previews.show(overlay, previewSnapshot) end)
        if shown and result ~= false then
            overlayKeys[image] = effectiveKey; frameCamera(overlay); renderedCount = renderedCount + 1
            pcall(function() overlay.Visible = true end)
        else destroyOverlay(image, false) end
    end
    local watch
    local function scan()
        if not alive or not enabled or not available then return end
        scanCount = scanCount + 1
        local descendants = {}; pcall(function() descendants = coreGui:GetDescendants() end)
        local seen = {}
        for _, object in ipairs(descendants) do
            if isAvatarImage(object, player, {name = currentName}) then seen[object] = true;if watch then watch(object)end;render(object) end
        end
        for image in pairs(hiddenImages) do if not seen[image] then destroyOverlay(image) end end
    end
    watch=function(object)
        if not enabled or not isAvatarImage(object, player, {name = currentName}) then return end
        hideImage(object)
        if not connections[object] then
            local ok, signal = pcall(function() return object:GetPropertyChangedSignal("Image") end)
            if ok and signal then
                local connection
                local connected = pcall(function() connection = signal:Connect(function()
                    if alive and enabled and isAvatarImage(object, player, {name = currentName}) then hideImage(object) end
                end) end)
                if connected and connection then connections[object] = connection end
            end
            local okTransparency, transparencySignal = pcall(function() return object:GetPropertyChangedSignal("ImageTransparency") end)
            if okTransparency and transparencySignal then
                local transparencyConnection
                pcall(function() transparencyConnection = transparencySignal:Connect(function()
                    if alive and enabled and isAvatarImage(object, player, {name = currentName}) then hideImage(object) end
                end) end)
                if transparencyConnection then transparencyConnections[object] = transparencyConnection end
            end
        end
    end
    local function watchPeopleText(object)
        local class = read(object, "ClassName")
        if class ~= "TextLabel" and class ~= "TextButton" then return end
        local people = false
        for _, item in ipairs(ancestors(object)) do
            local name = tostring(read(item, "Name") or ""):lower()
            if name:find("people",1,true) then people = true; break end
        end
        if not people or textConnections[object] then return end
        local ok, signal = pcall(function() return object:GetPropertyChangedSignal("Text") end)
        if not ok or not signal then return end
        local connection
        pcall(function() connection = signal:Connect(function()
            if alive and enabled then scan() end
        end) end)
        if connection then textConnections[object] = connection end
        if enabled then scan()end
    end
    local ok = pcall(function() coreGui = game:GetService("CoreGui"); coreGui:GetDescendants() end)
    available = ok and coreGui ~= nil
    if not available then status = "Roblox CoreGui is unavailable; native avatar thumbnails could not be inspected." end
    if available then
        pcall(function() connections.core = coreGui.DescendantAdded:Connect(function(object)
            watch(object); watchPeopleText(object)
        end) end)
    end

    local api = {}
    function api.update(options)
        options = options or {}; enabled = options.enabled == true; currentName = tostring(options.name or ""); currentImage = tostring(options.image or ""); if currentImage == "" then currentImage = nil end
        local character = read(player, "Character")
        local effectiveSnapshot = options.snapshot
        local nextKey = signature(effectiveSnapshot) .. "|" .. tostring(character) .. "|" .. tostring(currentImage or "")
        if enabled and (nextKey~=effectiveKey or effectiveSnapshot==nil)then
            previewSnapshot=nil
            for image,overlay in pairs(overlays)do overlay.Visible=false;hideImage(image)end
        end
        if enabled then
            local preflight = {}; pcall(function() preflight = coreGui:GetDescendants() end)
            for _, object in ipairs(preflight) do watch(object); watchPeopleText(object) end
        end
        if enabled and effectiveSnapshot ~= nil and not currentImage and (nextKey ~= effectiveKey or previewSnapshot == nil) then
            previewSnapshot = nil
            for image, overlay in pairs(overlays) do
                pcall(function() overlay.Visible = false end)
                hideImage(image)
            end
            local okPreview, previews = pcall(getPreviews)
            if okPreview and previews and type(previews.capture) == "function" then
                local capturedOk, captured = pcall(previews.capture)
                if capturedOk then previewSnapshot = captured end
            end
        end
        if enabled and effectiveSnapshot == nil and not currentImage then
            previewSnapshot = nil
            for image, overlay in pairs(overlays) do
                pcall(function() overlay.Visible = false end)
                hideImage(image)
            end
        end
        effectiveKey = nextKey
        if not enabled then
            previewSnapshot = nil
            for image in pairs(overlays) do destroyOverlay(image) end
            restoreAllImages()
            status = "Native avatar thumbnails are disabled."; return api.report()
        end
        scan(); status = available and "Native avatar thumbnails active." or status; return api.report()
    end
    function api.report() return status .. " Scans: " .. tostring(scanCount) .. "; rendered: " .. tostring(renderedCount) .. "." end
    function api.destroy()
        if not alive then return end
        alive = false
        for _, connection in pairs(connections) do pcall(function() connection:Disconnect() end) end
        for _,group in ipairs({transparencyConnections,textConnections})do
            for _,connection in pairs(group)do pcall(function()connection:Disconnect()end)end
        end
        connections = {};transparencyConnections={};textConnections={}
        for image in pairs(overlays) do destroyOverlay(image) end
        restoreAllImages()
    end
    return api
end

return M
