local _, addon = ...
if not ElvUI then return end

local AtonementHealthColor = { name = "atonementHealthColor" }
addon:RegisterFeature(AtonementHealthColor)

local ATONEMENT_SPELL_ID = 194384

local E = ElvUI[1]
local UF = E and E:GetModule("UnitFrames", true)
local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
local GetUnitAuraBySpellID = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local isSecretValue = issecretvalue or function() return false end

local eventFrames = {}
local hookedHealthBars = setmetatable({}, { __mode = "k" })
local refreshPending = {}
local hooksRegistered = false

local function isPriest()
    local _, classFile = UnitClass("player")
    return classFile == "PRIEST"
end

local function getDb()
    return addon.db and addon.db.atonementHealthColor
end

local function getFrameGroup(frame, unit)
    local owner = frame
    while owner do
        if owner.groupName then
            return owner.groupName
        end
        if owner.originalParent and owner.originalParent.groupName then
            return owner.originalParent.groupName
        end
        owner = owner:GetParent()
    end

    if unit == "player" or unit == "target" then
        return unit
    elseif unit and unit:match("^party%d+$") then
        return "party"
    elseif unit and unit:match("^raid%d+$") then
        return "raid"
    end
end

local function isSelectedFrame(frame, unit)
    local db = getDb()
    local frames = db and db.frames
    if not frames then return false end

    local group = getFrameGroup(frame, unit)
    if group == "player" or group == "target" or group == "party" then
        return frames[group] == true
    elseif group == "raid1" or group == "raid2" or group == "raid3" then
        return frames[group] == true
    elseif group == "raid" then
        return frames.raid1 == true or frames.raid2 == true or frames.raid3 == true
    end

    return false
end

local function auraDataIsAtonement(auraData)
    local spellID = auraData and auraData.spellId
    return spellID and not isSecretValue(spellID) and spellID == ATONEMENT_SPELL_ID
end

local function unitHasAtonement(unit)
    if not unit or not UnitExists(unit) then return false end

    if unit == "player" and GetPlayerAuraBySpellID then
        local ok, auraData = pcall(GetPlayerAuraBySpellID, ATONEMENT_SPELL_ID)
        if ok and auraData then return true end
    elseif GetUnitAuraBySpellID then
        local ok, auraData = pcall(GetUnitAuraBySpellID, unit, ATONEMENT_SPELL_ID)
        if ok and auraData then return true end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        local found = false
        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraData)
            if auraDataIsAtonement(auraData) then
                found = true
                return true
            end
        end, true)
        if found then return true end
    end

    if GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, auraData = pcall(GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not auraData then break end

            if auraDataIsAtonement(auraData) then
                return true
            end
        end
    end

    return false
end

local function applyAtonementColor(healthBar, unit)
    local db = getDb()
    if not db or not db.enabled or not isPriest() then return end

    local frame = healthBar and healthBar:GetParent()
    if not frame or not isSelectedFrame(frame, unit) then return end
    if not unitHasAtonement(unit) then return end

    local color = db.color or {}
    if UF and UF.SetStatusBarColor then
        UF:SetStatusBarColor(healthBar, color.r or 0.95, color.g or 0.72, color.b or 0.22)
    else
        healthBar:SetStatusBarColor(color.r or 0.95, color.g or 0.72, color.b or 0.22)
    end
end

local function wrapHealthBar(healthBar)
    if not healthBar or hookedHealthBars[healthBar] then return end

    local originalPostUpdateColor = healthBar.PostUpdateColor
    healthBar.PostUpdateColor = function(bar, unit, ...)
        if originalPostUpdateColor then
            originalPostUpdateColor(bar, unit, ...)
        end
        applyAtonementColor(bar, unit)
    end

    hookedHealthBars[healthBar] = true
end

local function scanExistingHealthBars()
    local frame = EnumerateFrames()
    while frame do
        if frame.Health and frame.Health.PostUpdateColor and tostring(frame:GetName() or ""):match("^ElvUF_") then
            wrapHealthBar(frame.Health)
        end
        frame = EnumerateFrames(frame)
    end
end

local function refreshFrame(frame)
    if not frame or not frame.Health then return end
    if frame.UpdateAllElements then
        frame:UpdateAllElements("ElvUI_UpdateAllElements")
    elseif frame.Health.ForceUpdate then
        frame.Health:ForceUpdate()
    end
end

local function refreshUnit(unit)
    for healthBar in pairs(hookedHealthBars) do
        local frame = healthBar and healthBar:GetParent()
        if frame and frame.unit == unit and isSelectedFrame(frame, unit) then
            refreshFrame(frame)
        end
    end
end

local function scheduleUnitRefresh(unit)
    if refreshPending[unit] then return end
    refreshPending[unit] = true
    C_Timer.After(0, function()
        refreshPending[unit] = nil
        refreshUnit(unit)
    end)
end

local function refreshAll()
    for healthBar in pairs(hookedHealthBars) do
        local frame = healthBar and healthBar:GetParent()
        if frame then
            refreshFrame(frame)
        end
    end
end

local function addEventUnit(unit)
    if eventFrames[unit] then return end

    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_AURA", unit)
    frame:SetScript("OnEvent", function(_, _, eventUnit)
        scheduleUnitRefresh(eventUnit)
    end)
    eventFrames[unit] = frame
end

local function unregisterEvents()
    for unit, frame in pairs(eventFrames) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        eventFrames[unit] = nil
    end
end

local function registerEvents()
    unregisterEvents()

    local db = getDb()
    if not db or not db.enabled or not isPriest() then return end

    local frames = db.frames or {}
    if frames.player or frames.party or frames.raid1 or frames.raid2 or frames.raid3 then
        addEventUnit("player")
    end

    if frames.target then
        addEventUnit("target")
    end

    if frames.party then
        for i = 1, 4 do
            addEventUnit("party" .. i)
        end
    end

    if frames.raid1 or frames.raid2 or frames.raid3 then
        for i = 1, 40 do
            addEventUnit("raid" .. i)
        end
    end
end

local function registerHooks()
    if hooksRegistered or not UF then return end

    if UF.Configure_HealthBar then
        hooksecurefunc(UF, "Configure_HealthBar", function(_, frame)
            if frame and frame.Health then
                wrapHealthBar(frame.Health)
            end
        end)
    end

    hooksRegistered = true
end

function AtonementHealthColor:Initialize()
    if not isPriest() then return end

    registerHooks()
    scanExistingHealthBars()
    self:Apply()
end

function AtonementHealthColor:Apply()
    if not isPriest() then return end

    scanExistingHealthBars()
    registerEvents()
    refreshAll()
end
