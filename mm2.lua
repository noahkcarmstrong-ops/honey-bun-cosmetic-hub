-- MM2 client discovery only. This module never requires modules, runs scripts,
-- changes instances, or calls remotes; it reports what this client can see.
return function(game)
    local api = {}

    local keywords = {
        "inventory", "item", "weapon", "knife", "gun", "emote",
        "database", "asset", "localplayer",
    }

    local function safeGetService(name)
        if not game or type(game.GetService) ~= "function" then return nil end
        local ok, service = pcall(game.GetService, game, name)
        return ok and service or nil
    end

    local function read(instance, key)
        if not instance then return nil end
        local ok, value = pcall(function() return instance[key] end)
        return ok and value or nil
    end

    local function isA(instance, className)
        local method = read(instance, "IsA")
        if type(method) ~= "function" then return read(instance, "ClassName") == className end
        local ok, result = pcall(method, instance, className)
        return ok and result == true
    end

    local function children(instance)
        local method = read(instance, "GetChildren")
        if type(method) ~= "function" then return {} end
        local ok, result = pcall(method, instance)
        return ok and type(result) == "table" and result or {}
    end

    local function descendants(instance)
        local method = read(instance, "GetDescendants")
        if type(method) ~= "function" then return {} end
        local ok, result = pcall(method, instance)
        return ok and type(result) == "table" and result or {}
    end

    local function fullName(instance)
        local value = read(instance, "GetFullName")
        if type(value) == "function" then
            local ok, name = pcall(value, instance)
            if ok and type(name) == "string" and name ~= "" then return name end
        end
        local parts, current, guard = {}, instance, 0
        while current and guard < 64 do
            local name = read(current, "Name")
            if type(name) ~= "string" or name == "" then break end
            table.insert(parts, 1, name)
            current, guard = read(current, "Parent"), guard + 1
        end
        return table.concat(parts, ".")
    end

    local function relevant(path)
        local lower = string.lower(path or "")
        for _, word in ipairs(keywords) do
            if string.find(lower, word, 1, true) then return true end
        end
        return false
    end

    function api.report()
        local lines, seen, count = {}, {}, 0
        local function add(label)
            if count >= 80 or type(label) ~= "string" or label == "" or seen[label] then return end
            seen[label], count = true, count + 1
            lines[#lines + 1] = label
        end

        local replicatedStorage = safeGetService("ReplicatedStorage")
        local players = safeGetService("Players")
        local localPlayer = read(players, "LocalPlayer")
        local playerGui = localPlayer and read(localPlayer, "PlayerGui")
        local character = localPlayer and read(localPlayer, "Character")

        local gameId, placeId, placeVersionId
        if game then
            gameId, placeId = read(game, "GameId"), read(game, "PlaceId")
            placeVersionId = read(game, "PlaceVersion")
        end
        lines[#lines + 1] = "MM2 discovery (read-only)"
        lines[#lines + 1] = "GameId=" .. tostring(gameId or "?")
        lines[#lines + 1] = "PlaceId=" .. tostring(placeId or "?")
        lines[#lines + 1] = "PlaceVersion=" .. tostring(placeVersionId or "?")
        lines[#lines + 1] = "ReplicatedStorage=" .. (replicatedStorage and "available" or "missing")
        lines[#lines + 1] = "LocalPlayer=" .. (localPlayer and tostring(read(localPlayer, "Name") or "available") or "missing")

        if replicatedStorage then
            for _, child in ipairs(children(replicatedStorage)) do
                add("RS child: " .. fullName(child))
            end
            for _, item in ipairs(descendants(replicatedStorage)) do
                local path = fullName(item)
                if relevant(path) and (isA(item, "ModuleScript") or isA(item, "Folder") or isA(item, "Model")) then
                    add("RS match: " .. path)
                end
            end
        end

        if playerGui then
            for _, item in ipairs(descendants(playerGui)) do
                local path = fullName(item)
                if relevant(path) and (isA(item, "ModuleScript") or isA(item, "LocalScript") or isA(item, "ScreenGui") or isA(item, "Frame")) then
                    add("PlayerGui match: " .. path)
                end
            end
        end

        if character then
            for _, item in ipairs(children(character)) do
                if isA(item, "Tool") or isA(item, "Accessory") then
                    add("Equipped " .. tostring(read(item, "ClassName") or "Instance") .. ": " .. fullName(item))
                end
            end
        end

        if count >= 80 then lines[#lines + 1] = "[output capped at 80 entries]" end
        return table.concat(lines, "\n")
    end

    return api
end
