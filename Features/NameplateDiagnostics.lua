local _, addon = ...

local NameplateDiagnostics = { name = "nameplateDiagnostics" }
addon:RegisterFeature(NameplateDiagnostics)

local CVARS = {
    nameplateShowAll = {
        label = "All nameplates",
        binding = "ALLNAMEPLATES",
    },
    nameplateShowEnemies = {
        label = "Enemy nameplates",
        binding = "NAMEPLATES",
    },
    nameplateShowFriends = {
        label = "Friendly nameplates",
        binding = "FRIENDNAMEPLATES",
    },
}

local eventFrame
local lastValues = {}
local lastSetCVar = {}

local function debugPrint(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MQOL Nameplates:|r " .. text)
    else
        print("MQOL Nameplates: " .. text)
    end
end

local function isEnabled()
    return addon.db
        and addon.db.nameplateDiagnostics
        and addon.db.nameplateDiagnostics.enabled == true
end

local function isWatchedCVar(name)
    return name and CVARS[tostring(name)] ~= nil
end

local function valueText(value)
    if value == nil then return "nil" end
    return tostring(value)
end

local function getCVarValue(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    return GetCVar(name)
end

local function getBindingText(command)
    if not command then return "none" end

    local bindings = {}
    local key1, key2 = GetBindingKey(command)
    if key1 then table.insert(bindings, key1) end
    if key2 then table.insert(bindings, key2) end

    if #bindings == 0 then return "none" end
    return table.concat(bindings, ", ")
end

local function detectCaller(stack)
    if not stack then
        return "unknown"
    end

    local firstBlizzard
    for line in stack:gmatch("[^\n]+") do
        local addonName = line:match("[Ii]nterface[\\/]+[Aa]dd[Oo]ns[\\/]+([^\\/]+)")
        if addonName and addonName ~= "MathWroQOL" then
            return addonName
        end

        if not firstBlizzard and line:find("[Ii]nterface[\\/]+[Ff]rameXML[\\/]") then
            firstBlizzard = "Blizzard FrameXML"
        end
        if not firstBlizzard and line:find("[Ii]nterface[\\/]+[Aa]dd[Oo]ns[\\/]+Blizzard_") then
            firstBlizzard = "Blizzard addon"
        end
    end

    return firstBlizzard or "Blizzard/internal, keybind, macro, or console"
end

local function printChange(source, name, oldValue, newValue, caller)
    local info = CVARS[name]
    if not info then return end

    debugPrint(info.label
        .. " changed " .. valueText(oldValue)
        .. " -> " .. valueText(newValue)
        .. " via " .. source
        .. "; caller=" .. valueText(caller)
        .. "; binding=" .. getBindingText(info.binding))
end

local function recordSetCVar(source, name, value, stack)
    if not isEnabled() or not isWatchedCVar(name) then return end

    name = tostring(name)
    local oldValue = lastValues[name]
    if oldValue ~= nil and tostring(oldValue) == tostring(value) then
        return
    end

    local caller = detectCaller(stack)
    lastSetCVar[name] = {
        source = source,
        value = value,
        caller = caller,
        time = GetTime and GetTime() or 0,
    }
    lastValues[name] = value

    printChange(source, name, oldValue, value, caller)
end

local function handleCVarUpdate(name)
    if not isEnabled() or not isWatchedCVar(name) then return end

    name = tostring(name)
    local oldValue = lastValues[name]
    local newValue = getCVarValue(name)
    lastValues[name] = newValue

    if oldValue == nil or tostring(oldValue) == tostring(newValue) then
        return
    end

    local recent = lastSetCVar[name]
    if recent and GetTime and (GetTime() - recent.time) < 0.25 then
        return
    end

    printChange("CVAR_UPDATE", name, oldValue, newValue, "no hookable Lua SetCVar caller")
end

local function snapshotValues()
    for name in pairs(CVARS) do
        lastValues[name] = getCVarValue(name)
    end
end

local function ensureEventFrame()
    if eventFrame then return eventFrame end

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, name)
        if event == "CVAR_UPDATE" then
            handleCVarUpdate(name)
        elseif event == "UPDATE_BINDINGS" and isEnabled() then
            debugPrint("bindings updated; enemy=" .. getBindingText("NAMEPLATES")
                .. ", friendly=" .. getBindingText("FRIENDNAMEPLATES")
                .. ", all=" .. getBindingText("ALLNAMEPLATES"))
        end
    end)
    return eventFrame
end

local function registerEvents()
    local frame = ensureEventFrame()
    frame:RegisterEvent("CVAR_UPDATE")
    frame:RegisterEvent("UPDATE_BINDINGS")
end

local function unregisterEvents()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

local function printStatus(reason)
    debugPrint("status reason=" .. valueText(reason))
    for name, info in pairs(CVARS) do
        debugPrint(info.label
            .. " " .. name
            .. "=" .. valueText(getCVarValue(name))
            .. "; binding=" .. getBindingText(info.binding))
    end
end

function NameplateDiagnostics:Initialize()
    hooksecurefunc("SetCVar", function(name, value)
        recordSetCVar("SetCVar", name, value, debugstack and debugstack(2, 12, 0))
    end)

    if C_CVar and C_CVar.SetCVar then
        hooksecurefunc(C_CVar, "SetCVar", function(name, value)
            recordSetCVar("C_CVar.SetCVar", name, value, debugstack and debugstack(2, 12, 0))
        end)
    end

    SLASH_MQOLNAMEPLATES1 = "/mqolnameplates"
    SlashCmdList["MQOLNAMEPLATES"] = function(message)
        addon.DebugNameplateDiagnostics(message)
    end

    self:Apply()
end

function NameplateDiagnostics:Apply()
    if isEnabled() then
        snapshotValues()
        registerEvents()
        debugPrint("watch enabled")
    else
        unregisterEvents()
    end
end

addon.DebugNameplateDiagnostics = function(message)
    local command = message and message:match("^%s*(.-)%s*$") or ""
    command = command:lower()

    addon.db.nameplateDiagnostics = addon.db.nameplateDiagnostics or { enabled = false }

    if command == "on" or command == "enable" then
        addon.db.nameplateDiagnostics.enabled = true
        addon:NotifyFeature("nameplateDiagnostics")
        printStatus("enabled")
        return
    end

    if command == "off" or command == "disable" then
        addon.db.nameplateDiagnostics.enabled = false
        addon:NotifyFeature("nameplateDiagnostics")
        debugPrint("watch disabled")
        return
    end

    if command == "toggle" then
        addon.db.nameplateDiagnostics.enabled = not addon.db.nameplateDiagnostics.enabled
        addon:NotifyFeature("nameplateDiagnostics")
        printStatus(addon.db.nameplateDiagnostics.enabled and "enabled" or "disabled")
        return
    end

    printStatus(command ~= "" and command or "manual")
end
