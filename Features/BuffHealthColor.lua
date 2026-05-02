local _, addon = ...
if not ElvUI then return end

local BuffHealthColor = { name = "buffHealthColor" }
addon:RegisterFeature(BuffHealthColor)

local BUILTIN_BUFF_ORDER = {
    "atonement",
    "lifebloom",
    "prayerOfMending",
    "riptide",
    "beaconOfTheSavior",
    "renewingMist",
}
local DEFAULT_BUFFS = {
    atonement = {
        label = "Atonement",
        spellID = 194384,
        color = { r = 0.95, g = 0.72, b = 0.22 },
    },
    lifebloom = {
        label = "Lifebloom",
        spellID = 33763,
        color = { r = 0.20, g = 0.85, b = 0.25 },
    },
    prayerOfMending = {
        label = "Prayer of Mending",
        spellID = 41635,
        color = { r = 0.95, g = 0.88, b = 0.42 },
    },
    riptide = {
        label = "Riptide",
        spellID = 61295,
        color = { r = 0.16, g = 0.62, b = 0.95 },
    },
    beaconOfTheSavior = {
        label = "Beacon of the Savior",
        spellID = 1244893,
        color = { r = 1.00, g = 0.78, b = 0.50 },
    },
    renewingMist = {
        label = "Renewing Mist",
        spellID = 448430,
        color = { r = 0.35, g = 0.92, b = 0.70 },
    },
}

local DEFAULT_FRAMES = {
    player = false,
    target = false,
    party  = true,
    raid1  = true,
    raid2  = true,
    raid3  = true,
}

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

local function copyColor(color, fallback)
    color = color or fallback or {}
    return {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
    }
end

local function copyFrames(frames)
    frames = frames or DEFAULT_FRAMES
    return {
        player = frames.player == true,
        target = frames.target == true,
        party  = frames.party == true,
        raid1  = frames.raid1 == true,
        raid2  = frames.raid2 == true,
        raid3  = frames.raid3 == true,
    }
end

local function getDb()
    return addon.db and addon.db.buffHealthColor
end

local function ensureProfileDefaults(profile, key)
    local default = DEFAULT_BUFFS[key]
    if default then
        if profile.enabled == nil then profile.enabled = key == "atonement" end
        if not profile.label then profile.label = default.label end
        if not profile.spellID then profile.spellID = default.spellID end
        if not profile.color then profile.color = copyColor(default.color) end
        if not profile.frames then profile.frames = copyFrames(DEFAULT_FRAMES) end
    else
        if profile.enabled == nil then profile.enabled = true end
        if not profile.label then profile.label = "Spell " .. tostring(profile.spellID or key) end
        if not profile.color then profile.color = copyColor(DEFAULT_BUFFS.atonement.color) end
        if not profile.frames then profile.frames = copyFrames(DEFAULT_FRAMES) end
    end
end

local function ensureDbShape()
    local db = getDb()
    if not db then return nil end

    if type(db.buffs) ~= "table" then db.buffs = {} end
    if type(db.customOrder) ~= "table" then db.customOrder = {} end

    for _, key in ipairs(BUILTIN_BUFF_ORDER) do
        if type(db.buffs[key]) ~= "table" then db.buffs[key] = {} end
        ensureProfileDefaults(db.buffs[key], key)
    end

    for _, key in ipairs(db.customOrder) do
        if type(db.buffs[key]) == "table" then
            ensureProfileDefaults(db.buffs[key], key)
        end
    end

    db.selectedBuff = db.selectedBuff or "atonement"
    return db
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

local function isSelectedFrame(profile, frame, unit)
    local frames = profile and profile.frames
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

local function auraDataMatchesSpellID(auraData, spellID)
    local auraSpellID = auraData and auraData.spellId
    local sourceUnit = auraData and auraData.sourceUnit
    return auraSpellID
        and not isSecretValue(auraSpellID)
        and auraSpellID == spellID
        and sourceUnit == "player"
end

local function unitHasBuff(unit, spellID)
    if not unit or not spellID or not UnitExists(unit) then return false end

    if unit == "player" and GetPlayerAuraBySpellID then
        local ok, auraData = pcall(GetPlayerAuraBySpellID, spellID)
        if ok and auraDataMatchesSpellID(auraData, spellID) then return true end
    elseif GetUnitAuraBySpellID then
        local ok, auraData = pcall(GetUnitAuraBySpellID, unit, spellID)
        if ok and auraDataMatchesSpellID(auraData, spellID) then return true end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        local found = false
        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraData)
            if auraDataMatchesSpellID(auraData, spellID) then
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

            if auraDataMatchesSpellID(auraData, spellID) then
                return true
            end
        end
    end

    return false
end

local function forEachProfile(db, callback)
    for _, key in ipairs(BUILTIN_BUFF_ORDER) do
        local profile = db.buffs and db.buffs[key]
        if profile and callback(key, profile) then return true end
    end

    for _, key in ipairs(db.customOrder or {}) do
        local profile = db.buffs and db.buffs[key]
        if profile and callback(key, profile) then return true end
    end
end

local function findMatchingProfile(db, healthBar, unit)
    local frame = healthBar and healthBar:GetParent()
    if not frame then return nil end

    local matchedProfile
    forEachProfile(db, function(_, profile)
        local spellID = tonumber(profile.spellID)
        if profile.enabled and spellID and isSelectedFrame(profile, frame, unit) and unitHasBuff(unit, spellID) then
            matchedProfile = profile
            return true
        end
    end)

    return matchedProfile
end

local function applyBuffColor(healthBar, unit)
    local db = ensureDbShape()
    if not db or not db.enabled then return end

    local profile = findMatchingProfile(db, healthBar, unit)
    if not profile then return end

    local color = profile.color or {}
    if UF and UF.SetStatusBarColor then
        UF:SetStatusBarColor(healthBar, color.r or 1, color.g or 1, color.b or 1)
    else
        healthBar:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1)
    end
end

local function wrapHealthBar(healthBar)
    if not healthBar or hookedHealthBars[healthBar] then return end

    local originalPostUpdateColor = healthBar.PostUpdateColor
    healthBar.PostUpdateColor = function(bar, unit, ...)
        if originalPostUpdateColor then
            originalPostUpdateColor(bar, unit, ...)
        end
        applyBuffColor(bar, unit)
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
        if frame and frame.unit == unit then
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

    local db = ensureDbShape()
    if not db or not db.enabled then return end

    local selected = {}
    forEachProfile(db, function(_, profile)
        if not profile.enabled then return end
        local frames = profile.frames or {}
        selected.player = selected.player or frames.player
        selected.target = selected.target or frames.target
        selected.party  = selected.party or frames.party
        selected.raid   = selected.raid or frames.raid1 or frames.raid2 or frames.raid3
    end)

    if selected.player or selected.party or selected.raid then
        addEventUnit("player")
    end

    if selected.target then
        addEventUnit("target")
    end

    if selected.party then
        for i = 1, 4 do
            addEventUnit("party" .. i)
        end
    end

    if selected.raid then
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

function BuffHealthColor:Initialize()
    ensureDbShape()
    registerHooks()
    scanExistingHealthBars()
    self:Apply()
end

function BuffHealthColor:Apply()
    ensureDbShape()
    scanExistingHealthBars()
    registerEvents()
    refreshAll()
end
