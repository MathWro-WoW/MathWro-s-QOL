local _, addon = ...
if not ElvUI then return end  -- skip all feature code if ElvUI is not loaded

local VehicleBar = { name = "vehicleBar" }
addon:RegisterFeature(VehicleBar)

-- Remove vehicle-related hide tokens from a visibility condition string.
-- ElvUI default: "[vehicleui][petbattle][overridebar] hide; show"
-- In most vehicle encounters both [vehicleui] and [overridebar] are active,
-- so we strip all three vehicle tokens to keep the bar visible.
local function stripVehicleHide(condition)
    local result = condition
    result = result:gsub("%[vehicleui%]", "")   -- vehicle UI active
    result = result:gsub("%[overridebar%]", "") -- override action bar (common in vehicle encounters)
    result = result:gsub("%[possessbar%]", "")  -- possess/mind-control bar
    result = result:gsub("[ \t]+;", ";")        -- clean extra spaces before semicolons
    result = result:gsub(";%s*;", ";")          -- collapse double semicolons
    result = result:gsub("^%s*;%s*", "")        -- trim any leading semicolon
    result = result:gsub("%s+", " ")            -- normalise whitespace
    return result
end

-- Guard flag to prevent our own RegisterStateDriver calls from re-triggering the hook.
local applying = false
local suppressVehicleShow = false

local function getActiveVehicleBarIndex()
    if HasOverrideActionBar() then
        return GetOverrideBarIndex()
    end

    if HasVehicleActionBar() or IsPossessBarVisible() or UnitExists("vehicle") then
        return GetVehicleBarIndex()
    end

    return nil
end

-- Returns true when an override or vehicle bar is active AND it has at least
-- one populated action slot (filters out taxis, RP vehicles, etc.).
local function isVehicleLikeWithAbilities()
    local barIndex = getActiveVehicleBarIndex()
    if not barIndex then return false end
    local baseSlot = (barIndex - 1) * NUM_ACTIONBAR_BUTTONS
    for i = 1, NUM_ACTIONBAR_BUTTONS do
        if HasAction(baseSlot + i) then
            return true
        end
    end
    return false
end

local function onStateDriverRegistered(frame, attribute, condition)
    if applying or attribute ~= "visibility" then return end
    local db = addon.db
    if not db or not db.vehicleBar.enabled then return end

    for i, enabled in pairs(db.vehicleBar.bars) do
        if enabled and frame == _G["ElvUI_Bar"..i] then
            local newCondition = stripVehicleHide(condition)
            if newCondition ~= condition then
                applying = true
                RegisterStateDriver(frame, attribute, newCondition)
                applying = false
            end
            break
        end
    end
end

-- Force all enabled mouseover bars fully visible. Called on vehicle-like entry.
local function forceShowEnabledBars()
    local E = ElvUI[1]
    if not E then return end
    local db = addon.db.vehicleBar
    if not db or not db.enabled then return end
    for i, enabled in pairs(db.bars) do
        if enabled then
            local bar = _G["ElvUI_Bar"..i]
            if bar and bar.mouseover then
                E:UIFrameFadeIn(bar, 0.2, bar:GetAlpha(), (bar.db and bar.db.alpha) or 1)
            end
        end
    end
end

-- Fade out enabled mouseover bars back to hidden. Called on vehicle-like exit.
local function forceHideEnabledBars()
    local E = ElvUI[1]
    if not E then return end
    local db = addon.db.vehicleBar
    if not db or not db.enabled then return end
    for i, enabled in pairs(db.bars) do
        if enabled then
            local bar = _G["ElvUI_Bar"..i]
            if bar and bar.mouseover then
                E:UIFrameFadeOut(bar, 0.2, bar:GetAlpha(), 0)
            end
        end
    end
end

local function updateEnabledBarsForVehicleState()
    if not suppressVehicleShow and isVehicleLikeWithAbilities() then
        forceShowEnabledBars()
    else
        forceHideEnabledBars()
    end
end

local function onVehicleStateEvent(event)
    if event == "UNIT_EXITING_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        suppressVehicleShow = true
        forceHideEnabledBars()
        return
    end

    if event == "UNIT_ENTERING_VEHICLE"
        or event == "UNIT_ENTERED_VEHICLE"
        or HasOverrideActionBar()
        or not (HasVehicleActionBar() or IsPossessBarVisible() or UnitExists("vehicle"))
    then
        suppressVehicleShow = false
    end

    updateEnabledBarsForVehicleState()
end

local debugEvents

local function debugPrint(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MQOL Vehicle:|r " .. text)
    else
        print("MQOL Vehicle: " .. text)
    end
end

local function boolText(value)
    return value and "true" or "false"
end

local function valueText(value)
    if value == nil then return "nil" end
    return tostring(value)
end

local function frameName(frame)
    if not frame then return "nil" end
    return frame.GetName and frame:GetName() or tostring(frame)
end

local function printStateLine(prefix)
    debugPrint(prefix
        .. " override=" .. boolText(HasOverrideActionBar())
        .. " vehicleBar=" .. boolText(HasVehicleActionBar())
        .. " possess=" .. boolText(IsPossessBarVisible())
        .. " unitVehicle=" .. boolText(UnitExists("vehicle"))
        .. " overrideIndex=" .. valueText(GetOverrideBarIndex())
        .. " vehicleIndex=" .. valueText(GetVehicleBarIndex()))
end

local function printSlotSummary(label, barIndex)
    if not barIndex then
        debugPrint(label .. " slots: no bar index")
        return
    end

    local baseSlot = (barIndex - 1) * NUM_ACTIONBAR_BUTTONS
    local found = false
    for i = 1, NUM_ACTIONBAR_BUTTONS do
        local slot = baseSlot + i
        if HasAction(slot) then
            local actionType, id, subType = GetActionInfo(slot)
            debugPrint(label .. " slot " .. i .. "/" .. slot
                .. " type=" .. valueText(actionType)
                .. " id=" .. valueText(id)
                .. " subType=" .. valueText(subType))
            found = true
        end
    end

    if not found then
        debugPrint(label .. " slots: no populated actions")
    end
end

local function printBarSummary(index)
    local bar = _G["ElvUI_Bar" .. index]
    if not bar then
        debugPrint("bar" .. index .. ": frame missing")
        return
    end

    local db = bar.db
    debugPrint("bar" .. index
        .. " shown=" .. boolText(bar:IsShown())
        .. " visible=" .. boolText(bar:IsVisible())
        .. " alpha=" .. valueText(bar:GetAlpha())
        .. " mouseover=" .. boolText(bar.mouseover)
        .. " parent=" .. frameName(bar:GetParent())
        .. " pageAttr=" .. valueText(bar:GetAttribute("page"))
        .. " dbEnabled=" .. boolText(db and db.enabled)
        .. " dbAlpha=" .. valueText(db and db.alpha)
        .. " inheritGlobalFade=" .. boolText(db and db.inheritGlobalFade))

    if db and db.visibility then
        debugPrint("bar" .. index .. " visibility=" .. db.visibility)
    end
end

local function printVehicleDiagnostics(reason)
    local E = ElvUI and ElvUI[1]
    local AB = E and E:GetModule("ActionBars", true)
    local db = addon.db and addon.db.vehicleBar

    debugPrint("diagnostic reason=" .. valueText(reason))
    debugPrint("feature enabled=" .. boolText(db and db.enabled))
    printStateLine("state")
    debugPrint("suppress vehicle show=" .. boolText(suppressVehicleShow))
    debugPrint("active vehicle bar index=" .. valueText(getActiveVehicleBarIndex()))
    debugPrint("detector vehicleLikeWithAbilities=" .. boolText(isVehicleLikeWithAbilities()))

    if AB and AB.fadeParent then
        debugPrint("fadeParent alpha=" .. valueText(AB.fadeParent:GetAlpha())
            .. " mouseLock=" .. boolText(AB.fadeParent.mouseLock))
    else
        debugPrint("fadeParent unavailable")
    end

    if db and db.bars then
        for i, enabled in pairs(db.bars) do
            if enabled then
                printBarSummary(i)
            end
        end
    end

    printSlotSummary("override", GetOverrideBarIndex())
    printSlotSummary("vehicle", GetVehicleBarIndex())
end

local function toggleVehicleDebugWatcher()
    if debugEvents then
        debugEvents:UnregisterAllEvents()
        debugEvents = nil
        debugPrint("event watch disabled")
        return
    end

    debugEvents = CreateFrame("Frame")
    debugEvents:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    debugEvents:RegisterEvent("UPDATE_POSSESS_BAR")
    debugEvents:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    debugEvents:RegisterEvent("VEHICLE_UPDATE")
    debugEvents:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    debugEvents:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    debugEvents:RegisterUnitEvent("UNIT_ENTERING_VEHICLE", "player")
    debugEvents:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    debugEvents:RegisterUnitEvent("UNIT_EXITING_VEHICLE", "player")
    debugEvents:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    debugEvents:SetScript("OnEvent", function(self, event)
        printStateLine("event " .. event)
    end)
    debugPrint("event watch enabled")
end

addon.DebugVehicleBar = function(message)
    if message and message:match("^%s*watch%s*$") then
        toggleVehicleDebugWatcher()
    else
        printVehicleDiagnostics(message)
    end
end

function VehicleBar:Initialize()
    SLASH_MQOLVEHICLEDEBUG1 = "/mqolvehicledebug"
    SlashCmdList["MQOLVEHICLEDEBUG"] = function(message)
        addon.DebugVehicleBar(message)
    end

    -- Hook RegisterStateDriver to strip vehicle hide conditions from visibility drivers.
    hooksecurefunc("RegisterStateDriver", onStateDriverRegistered)

    local E = ElvUI[1]

    -- Bars using ElvUI's individual mouseover fade are NOT covered by ElvUI's own
    -- vehicle mouseLock (which only protects the global fade parent). Hook
    -- UIFrameFadeOut to cancel any fade-out targeting a selected bar while in a vehicle.
    if E and E.UIFrameFadeOut then
        hooksecurefunc(E, "UIFrameFadeOut", function(self, frame, fadeTime, startAlpha, endAlpha)
            if not isVehicleLikeWithAbilities() then return end
            local db = addon.db.vehicleBar
            if not db or not db.enabled then return end
            for i, enabled in pairs(db.bars) do
                if enabled and frame == _G["ElvUI_Bar"..i] and frame.mouseover then
                    -- Overwrite the fade-out with a fade-in before the FadeManager
                    -- processes its first OnUpdate tick — effectively a no-op fade.
                    E:UIFrameFadeIn(frame, 0.1, frame:GetAlpha(), (frame.db and frame.db.alpha) or 1)
                    break
                end
            end
        end)
    end

    -- Force bars visible on vehicle-like entry; fade them back out on exit.
    -- UNIT_EXITING/EXITED are authoritative exit signals; some vehicle APIs can
    -- still report the old action bar briefly, so suppress re-show until a new
    -- enter/override state or a fully cleared vehicle state is observed.
    local vehicleEvents = CreateFrame("Frame")
    vehicleEvents:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    vehicleEvents:RegisterEvent("UPDATE_POSSESS_BAR")
    vehicleEvents:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    vehicleEvents:RegisterEvent("VEHICLE_UPDATE")
    vehicleEvents:RegisterUnitEvent("UNIT_ENTERING_VEHICLE", "player")
    vehicleEvents:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    vehicleEvents:RegisterUnitEvent("UNIT_EXITING_VEHICLE", "player")
    vehicleEvents:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    vehicleEvents:SetScript("OnEvent", function(self, event)
        onVehicleStateEvent(event)
    end)

    -- Handle reload-while-already-in-vehicle-like-state.
    suppressVehicleShow = false
    updateEnabledBarsForVehicleState()

    self:Apply()
end

-- Called when settings change. Triggers ElvUI to re-run PositionAndSizeBar on all
-- bars, which re-registers state drivers, causing our hook to fire again.
function VehicleBar:Apply()
    if not ElvUI then return end
    local E = unpack(ElvUI)
    local AB = E and E:GetModule("ActionBars", true)
    if AB and AB.UpdateButtonSettings then
        AB:UpdateButtonSettings()
    end
end
