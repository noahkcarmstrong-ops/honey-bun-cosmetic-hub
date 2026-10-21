-- Executor adapter for the unmodified, pinned Prism package.
local VERSION = "2383bbd"

return function(readSource)
    local globals = type(getgenv) == "function" and getgenv() or _G
    local cached = globals.LarpbloxPrism
    if cached and cached.version == VERSION then return cached end

    local customAsset = getcustomasset or getsynasset
    assert(type(customAsset) == "function" and type(writefile) == "function",
        "Prism needs local asset support (getcustomasset and writefile).")
    local filename = "Larpblox-Prism-" .. VERSION .. ".rbxm"
    local bytes = readSource("vendor/Prism.rbxm")
    assert(type(bytes) == "string" and bytes:sub(1, 7) == "<roblox", "Prism package could not download.")
    writefile(filename, bytes)
    local objects = game:GetObjects(customAsset(filename))
    assert(#objects == 1 and objects[1]:IsA("ModuleScript"), "Prism package is invalid.")
    local package = objects[1]
    package.Name = "LarpbloxPrism"

    -- Locally inserted models have source but no executable Roblox bytecode.
    -- Scope require/script/_G to this package; never replace the client's globals.
    local environment = getfenv()
    local moduleGlobals, modules, loading = {}, {}, {}
    local function import(module)
        if typeof(module) ~= "Instance" or (module ~= package and not module:IsDescendantOf(package)) then
            return require(module)
        end
        if modules[module] ~= nil then return modules[module] end
        assert(not loading[module], "Circular Prism import: " .. module:GetFullName())
        local chunk, message = loadstring(module.Source, "=" .. module:GetFullName())
        assert(chunk, message)
        setfenv(chunk, setmetatable({script = module, require = import, _G = moduleGlobals}, {__index = environment}))
        loading[module] = true
        local ok, result = xpcall(chunk, debug.traceback)
        loading[module] = nil
        if not ok then error(result, 0) end
        modules[module] = result
        return result
    end
    local ok, runtime = pcall(function()
        return {
            version = VERSION,
            Prism = import(package),
            React = import(package.React),
            ReactRoblox = import(package.ReactRoblox),
        }
    end)
    if type(delfile) == "function" then pcall(delfile, filename) end
    if not ok then package:Destroy(); error(runtime, 0) end
    globals.LarpbloxPrism = runtime
    return runtime
end
