-- Developer-only smoke test for EllesmereUI unlock-mover scan scheduling.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local frames = {}
local scheduled = {}
local enumerationCalls = 0
local scanCallbacks = 0
local registerUnlockElementsHook
local unlockListener

local function newFrame(isMover)
    local frame = {}

    function frame:IsObjectType(kind)
        return isMover and kind == "Button"
    end

    function frame:HookScript(script, callback)
        self[script] = callback
    end

    if isMover then
        frame._barKey = "test"
        frame._bg = {}
        frame._brd = {}
    end

    return frame
end

for index = 1, 250 do
    frames[index] = newFrame(index == 100 or index == 250)
end

for index = 1, 249 do
    frames[index]._next = frames[index + 1]
end

function EnumerateFrames(previous)
    if previous then
        enumerationCalls = enumerationCalls + 1
        return previous._next
    end
    return frames[1]
end

C_Timer = {
    After = function(_, callback)
        scheduled[#scheduled + 1] = callback
    end,
}

EllesmereUI = {
    RegisterUnlockModeListener = function(_, _, listener)
        unlockListener = listener
    end,
    RegisterUnlockElements = function() end,
    IsUnlockModeActive = function()
        return true
    end,
}

function hooksecurefunc(target, method, callback)
    assert(target == EllesmereUI and method == "RegisterUnlockElements")
    registerUnlockElementsHook = callback
end

local addon = {
    db = { editModeNudge = { enabled = false, ellesmereEnabled = true } },
}

function addon:RegisterFeature(feature)
    self.feature = feature
end

assert(loadfile("Features/EditModeNudge.lua"))("MathWroQOL", addon)
assert(addon.feature, "EditModeNudge did not register")
addon.feature:Initialize()
assert(unlockListener, "unlock-mode listener was not registered")
assert(registerUnlockElementsHook, "unlock-element hook was not registered")

unlockListener(true)
registerUnlockElementsHook()

while #scheduled > 0 do
    local callback = table.remove(scheduled, 1)
    enumerationCalls = 0
    scanCallbacks = scanCallbacks + 1
    callback()
    assert(enumerationCalls <= 100, "unlock-mover scan exceeded its per-callback frame budget")
end

assert(scanCallbacks == 6, "registration during a scan must schedule one complete rescan")
for _, index in ipairs({ 100, 250 }) do
    assert(frames[index].OnClick, "mover was not hooked")
    assert(frames[index].OnHide, "mover hide handler was not hooked")
end

unlockListener(true)
unlockListener(false)
assert(#scheduled == 1, "unlock close should leave only the invalidated callback")
enumerationCalls = 0
table.remove(scheduled, 1)()
assert(enumerationCalls == 0, "invalidated scan callback must not enumerate frames")

print("EditModeNudge unlock-mover scan smoke test: PASS")
