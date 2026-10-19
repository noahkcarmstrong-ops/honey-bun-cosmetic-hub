-- Exercises account-scoped cosmetic storage without Roblox or executor APIs.
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function signal()
    local result = {listeners = {}}
    function result:Connect(fn)
        local connection = {Connected = true}
        function connection:Disconnect() self.Connected = false end
        connection.fn = fn
        self.listeners[#self.listeners + 1] = connection
        return connection
    end
    function result:Fire(...)
        for _, connection in ipairs(self.listeners) do
            if connection.Connected then connection.fn(...) end
        end
    end
    return result
end

local jobs = {}
task = {
    defer = function(fn) jobs[#jobs + 1] = fn end,
}
local function flush()
    local pending = jobs
    jobs = {}
    for _, fn in ipairs(pending) do fn() end
end

-- JSON is represented by opaque tokens. The fake still deep-copies values so
-- tests catch accidental mutation of the in-memory document.
local jsonDocuments, nextToken = {}, 0
local http = {
    JSONEncode = function(_, value)
        nextToken = nextToken + 1
        local token = 'json-token-' .. nextToken
        jsonDocuments[token] = copy(value)
        return token
    end,
    JSONDecode = function(_, token)
        assert(jsonDocuments[token], 'attempted to decode an invalid JSON token')
        return copy(jsonDocuments[token])
    end,
}
game = {GetService = function(_, name) return name == 'HttpService' and http end}

local files = {}
function isfile(path) return files[path] ~= nil end
function readfile(path) return assert(files[path], 'missing file ' .. path) end
function writefile(path, contents) files[path] = contents end

local function playerGui(initial)
    local attributes = copy(initial or {})
    local changed = signal()
    local gui = {AttributeChanged = changed}
    function gui:GetAttribute(name) return attributes[name] end
    function gui:SetAttribute(name, value)
        attributes[name] = value
        changed:Fire(name)
    end
    function gui:GetAttributes() return copy(attributes) end
    return gui
end

local makeStorage = dofile('storage.lua')
local function value(gui, name) return gui:GetAttribute(name) end
local function rejoin(userId, initial)
    local gui = playerGui(initial)
    local storage = makeStorage(gui, userId)
    return gui, storage
end

-- A first session writes every supported category and survives a fresh GUI.
local firstGui, first = rejoin(101)
firstGui:SetAttribute('HoneyBunCosmeticSettings', '{"accessories":[]}')
firstGui:SetAttribute('HoneyBunCosmeticEmotes', '{"1":12345,"3":123}')
firstGui:SetAttribute('HoneyBunCosmeticAnimationBundle', 82)
firstGui:SetAttribute('HoneyBunCosmeticEffects', '{"version":1,"entries":[]}')
firstGui:SetAttribute('HoneyBunCosmeticGuns', '{"version":1,"guns":[]}')
firstGui:SetAttribute('HoneyBunCosmeticClothes', '{"Shirt":123,"Pants":456}')
firstGui:SetAttribute('HoneyBunCosmeticUI_Theme', 'dark')
firstGui:SetAttribute('HoneyBunCosmeticUI_Scale', 1.25)
flush()
assert(first.status(), 'storage reports a usable status')
first:destroy()

-- destroy() flushes a pending deferred write before disconnecting listeners.
local destroyFlushGui, destroyFlush = rejoin(404)
destroyFlushGui:SetAttribute('HoneyBunCosmeticUI_Theme', 'flushed-on-destroy')
destroyFlush:destroy()
local destroyFlushRejoinGui, destroyFlushRejoin = rejoin(404)
assert(value(destroyFlushRejoinGui, 'HoneyBunCosmeticUI_Theme') == 'flushed-on-destroy', 'destroy flushes pending writes')
destroyFlushRejoin:destroy()
destroyFlushGui:SetAttribute('HoneyBunCosmeticUI_Theme', 'must-not-save-after-destroy')
flush()
local disconnectedGui, disconnected = rejoin(404)
assert(value(disconnectedGui, 'HoneyBunCosmeticUI_Theme') == 'flushed-on-destroy', 'destroy disconnects attribute listener')
disconnected:destroy()

local restoredGui, restored = rejoin(101)
assert(value(restoredGui, 'HoneyBunCosmeticSettings') == '{"accessories":[]}', 'settings restore after rejoin')
assert(value(restoredGui, 'HoneyBunCosmeticEmotes') == '{"1":12345,"3":123}', 'emotes including slot 1 restore after rejoin')
assert(value(restoredGui, 'HoneyBunCosmeticAnimationBundle') == 82, 'animation bundle restore after rejoin')
assert(value(restoredGui, 'HoneyBunCosmeticEffects') == '{"version":1,"entries":[]}', 'Saved player effects restore after rejoin')
assert(value(restoredGui, 'HoneyBunCosmeticGuns') == '{"version":1,"guns":[]}', 'saved gun choices restore after rejoin')
assert(value(restoredGui, 'HoneyBunCosmeticClothes') == '{"Shirt":123,"Pants":456}', 'classic shirt and pants restore after rejoin')
assert(value(restoredGui, 'HoneyBunCosmeticUI_Theme') == 'dark' and value(restoredGui, 'HoneyBunCosmeticUI_Scale') == 1.25, 'UI values restore after rejoin')
restored:destroy()

-- An account's save cannot be reused just by renaming its file for another ID.
local ownerDocument=http:JSONDecode(files['HoneyBunCosmeticHub_101.json'])
assert(ownerDocument.userId==101,'Saved documents identify the account that owns them')
files['HoneyBunCosmeticHub_909.json']=files['HoneyBunCosmeticHub_101.json']
local misplacedGui,misplaced=rejoin(909)
assert(value(misplacedGui,'HoneyBunCosmeticSettings')==nil,'Mismatched account saves are not loaded')
misplaced:destroy()

-- Attributes already present for this session win over disk values.
local precedenceGui, precedence = rejoin(101, {
    HoneyBunCosmeticSettings = 'session-settings',
    HoneyBunCosmeticUI_Theme = 'session-theme',
})
assert(value(precedenceGui, 'HoneyBunCosmeticSettings') == 'session-settings', 'session settings take precedence')
assert(value(precedenceGui, 'HoneyBunCosmeticUI_Theme') == 'session-theme', 'session UI values take precedence')
assert(value(precedenceGui, 'HoneyBunCosmeticEmotes') == '{"1":12345,"3":123}', 'missing session values still restore')
precedence:destroy()

-- Account files are isolated.
local otherGui, other = rejoin(202)
assert(value(otherGui, 'HoneyBunCosmeticSettings') == nil, 'another account starts empty')
otherGui:SetAttribute('HoneyBunCosmeticSettings', 'other-account')
flush();other:destroy()
local originalGui, original = rejoin(101)
assert(value(originalGui, 'HoneyBunCosmeticSettings') == 'session-settings', 'account data does not cross accounts')
original:destroy()

local mixedBody='{"body":"Girl","bodyParts":{"Head":"https://www.roblox.com/catalog/123/Head","LeftArm":"https://www.roblox.com/bundles/311/Body"}}'
local partsGui,parts=rejoin(505)
partsGui:SetAttribute('HoneyBunCosmeticSettings',mixedBody);flush();parts:destroy()
local restoredPartsGui,restoredParts=rejoin(505)
assert(value(restoredPartsGui,'HoneyBunCosmeticSettings')==mixedBody,'mixed body region selections persist after rejoin')
restoredParts:destroy()

-- Setting an attribute to nil removes it from the next saved document.
local removalGui, removal = rejoin(101)
removalGui:SetAttribute('HoneyBunCosmeticEmotes', nil)
flush();removal:destroy()
local afterRemovalGui, afterRemoval = rejoin(101)
assert(value(afterRemovalGui, 'HoneyBunCosmeticEmotes') == nil, 'removed attributes stay removed after rejoin')
afterRemoval:destroy()

-- A corrupt primary file falls back to the last valid backup document.
local path = 'HoneyBunCosmeticHub_101.json'
local backupPath = path .. '.bak'
files[path] = 'corrupt-json'
files[backupPath] = files[backupPath] or files[path]
-- Replace the backup with a valid token made through the same JSON encoder.
files[backupPath] = http:JSONEncode({version = 1, values = {
    HoneyBunCosmeticSettings = 'backup-settings',
    HoneyBunCosmeticUI_Theme = 'backup-theme',
}})
local fallbackGui, fallback = rejoin(101)
assert(value(fallbackGui, 'HoneyBunCosmeticSettings') == 'backup-settings' and value(fallbackGui, 'HoneyBunCosmeticUI_Theme') == 'backup-theme', 'valid backup restores when main file is corrupt')
fallback:destroy()

-- Executor file APIs are optional: the module remains usable as session-only storage.
local savedRead, savedWrite, savedIsfile = readfile, writefile, isfile
readfile, writefile, isfile = nil, nil, nil
local sessionGui, session = rejoin(303, {HoneyBunCosmeticSettings = 'session-only'})
assert(value(sessionGui, 'HoneyBunCosmeticSettings') == 'session-only', 'session-only mode keeps current attributes')
assert(session.status():find('session only', 1, true), 'session-only status is clear')
assert(pcall(function() sessionGui:SetAttribute('HoneyBunCosmeticUI_Theme', 'memory-only'); flush(); session:destroy() end), 'missing file APIs do not crash')
readfile, writefile, isfile = savedRead, savedWrite, savedIsfile

-- A failed disk write reports the failure, preserves in-memory values, and retries.
local failedGui, failed = rejoin(505)
local workingWrite = writefile
writefile = function() error('disk full') end
failedGui:SetAttribute('HoneyBunCosmeticSettings', 'kept-in-memory')
assert(failed.status():find('failed', 1, true), 'write failure is reported')
assert(value(failedGui, 'HoneyBunCosmeticSettings') == 'kept-in-memory', 'write failure preserves session value')
writefile = workingWrite
failedGui:SetAttribute('HoneyBunCosmeticUI_Theme', 'retry-succeeded')
flush();failed:destroy()
local retriedGui, retried = rejoin(505)
assert(value(retriedGui, 'HoneyBunCosmeticSettings') == 'kept-in-memory' and value(retriedGui, 'HoneyBunCosmeticUI_Theme') == 'retry-succeeded', 'next change retries failed write')
retried:destroy()

-- Character documents are allowlisted, flushed immediately, and removed on nil.
local characterGui, characterStorage = rejoin(808)
characterGui:SetAttribute('HoneyBunCosmeticCharacters', '{"version":1,"nextId":1,"profiles":[]}')
local characterRejoinGui, characterRejoinStorage = rejoin(808)
assert(value(characterRejoinGui, 'HoneyBunCosmeticCharacters') == '{"version":1,"nextId":1,"profiles":[]}', 'character library restores after rejoin')
characterRejoinGui:SetAttribute('HoneyBunCosmeticCharacters', nil)
local characterDeletedGui, characterDeletedStorage = rejoin(808)
assert(value(characterDeletedGui, 'HoneyBunCosmeticCharacters') == nil, 'character library deletion persists')
characterStorage:destroy(); characterRejoinStorage:destroy(); characterDeletedStorage:destroy()

-- Gun choices restore in a fresh GUI and nil removal persists immediately.
local gunGui, gunStorage = rejoin(909)
gunGui:SetAttribute('HoneyBunCosmeticGuns', '{"version":1,"guns":[{"id":123}]}')
local gunRejoinGui, gunRejoinStorage = rejoin(909)
assert(value(gunRejoinGui, 'HoneyBunCosmeticGuns') == '{"version":1,"guns":[{"id":123}]}', 'gun choices restore after rejoin')
gunRejoinGui:SetAttribute('HoneyBunCosmeticGuns', nil)
local gunDeletedGui, gunDeletedStorage = rejoin(909)
assert(value(gunDeletedGui, 'HoneyBunCosmeticGuns') == nil, 'gun choice deletion persists')
gunStorage:destroy(); gunRejoinStorage:destroy(); gunDeletedStorage:destroy()

_G.characterRejoin = rejoin
_G.characterFlush = flush

print('Storage restore, precedence, account isolation, removals, backup fallback, and session-only checks passed.')
