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
        allSpecs = false,
        specs = { [256] = true },
        validSpecs = { [256] = true },
    },
    lifebloom = {
        label = "Lifebloom",
        spellID = 33763,
        color = { r = 0.20, g = 0.85, b = 0.25 },
        allSpecs = false,
        specs = { [105] = true },
        validSpecs = { [105] = true },
    },
    prayerOfMending = {
        label = "Prayer of Mending",
        spellID = 41635,
        color = { r = 0.95, g = 0.88, b = 0.42 },
        allSpecs = false,
        specs = { [257] = true },
        validSpecs = { [256] = true, [257] = true },
    },
    riptide = {
        label = "Riptide",
        spellID = 61295,
        color = { r = 0.16, g = 0.62, b = 0.95 },
        allSpecs = false,
        specs = { [264] = true },
        validSpecs = { [264] = true },
    },
    beaconOfTheSavior = {
        label = "Beacon of the Savior",
        spellID = 1244893,
        color = { r = 1.00, g = 0.78, b = 0.50 },
        allSpecs = false,
        specs = { [65] = true },
        validSpecs = { [65] = true },
    },
    renewingMist = {
        label = "Renewing Mist",
        spellID = 448430,
        color = { r = 0.35, g = 0.92, b = 0.70 },
        allSpecs = false,
        specs = { [270] = true },
        validSpecs = { [270] = true },
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
local specEventFrame
local hookedHealthBars = setmetatable({}, { __mode = "k" })
local auraState = {}
local activeProfiles = {}
local activeSpellIDs = {}
local activeProfilesReady = false
local hooksRegistered = false
local scanExistingHealthBars
local registerEvents

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

local function copySpecs(specs)
    local copy = {}
    for specID, enabled in pairs(specs or {}) do
        copy[tonumber(specID) or specID] = enabled == true
    end
    return copy
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
        if profile.allSpecs == nil then profile.allSpecs = default.allSpecs == true end
        if not profile.specs then profile.specs = copySpecs(default.specs) end
        profile.validSpecs = copySpecs(default.validSpecs)
    else
        if profile.enabled == nil then profile.enabled = true end
        if not profile.label then profile.label = "Spell " .. tostring(profile.spellID or key) end
        if not profile.color then profile.color = copyColor(DEFAULT_BUFFS.atonement.color) end
        if not profile.frames then profile.frames = copyFrames(DEFAULT_FRAMES) end
        if profile.allSpecs == nil then profile.allSpecs = true end
        if not profile.specs then profile.specs = {} end
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

local function getCurrentSpecID()
    if not GetSpecialization or not GetSpecializationInfo then return nil end

    local specIndex = GetSpecialization()
    if not specIndex then return nil end

    local specID = GetSpecializationInfo(specIndex)
    return tonumber(specID)
end

local function profileMatchesCurrentSpec(profile)
    if not profile then return false end
    local specID = getCurrentSpecID()
    if not specID then return true end

    if profile.validSpecs and not (profile.validSpecs[specID] == true or profile.validSpecs[tostring(specID)] == true) then
        return false
    end

    if not profile.validSpecs and profile.allSpecs == true then return true end

    local specs = profile.specs
    if type(specs) ~= "table" then return true end

    return specs[specID] == true or specs[tostring(specID)] == true
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

local function rebuildActiveProfiles(db)
    activeProfiles = {}
    activeSpellIDs = {}
    activeProfilesReady = true

    if not db or not db.enabled then return end

    forEachProfile(db, function(_, profile)
        local spellID = tonumber(profile.spellID)
        if profile.enabled and spellID and profileMatchesCurrentSpec(profile) then
            table.insert(activeProfiles, profile)
            activeSpellIDs[spellID] = true
        end
    end)
end

local function clearAuraState()
    for unit in pairs(auraState) do
        auraState[unit] = nil
    end
end

local function getUnitAuraState(unit)
    local state = auraState[unit]
    if not state then
        state = { spells = {}, instances = {} }
        auraState[unit] = state
    end
    return state
end

local function addTrackedAura(state, auraData)
    if not auraData or not auraData.auraInstanceID then return false end

    local spellID = auraData.spellId
    if isSecretValue(spellID) or not activeSpellIDs[spellID] or auraData.sourceUnit ~= "player" then return false end

    if state.instances[auraData.auraInstanceID] == spellID then return false end

    state.instances[auraData.auraInstanceID] = spellID
    state.spells[spellID] = (state.spells[spellID] or 0) + 1
    return true
end

local function removeTrackedAura(state, auraInstanceID)
    local spellID = state.instances[auraInstanceID]
    if not spellID then return false end

    state.instances[auraInstanceID] = nil
    local count = (state.spells[spellID] or 1) - 1
    state.spells[spellID] = count > 0 and count or nil
    return true
end

local function scanUnitAuras(unit)
    local state = getUnitAuraState(unit)
    state.spells = {}
    state.instances = {}

    if not unit or not UnitExists(unit) then return state end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraData)
            addTrackedAura(state, auraData)
        end, true)
    elseif GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, auraData = pcall(GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not auraData then break end
            addTrackedAura(state, auraData)
        end
    end

    return state
end

local function updateTrackedAuraByInstanceID(unit, state, auraInstanceID)
    local wasTracked = removeTrackedAura(state, auraInstanceID)
    local auraData
    if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
    end

    local isTracked = addTrackedAura(state, auraData)
    return wasTracked or isTracked
end

local function processUnitAuraUpdate(unit, updateInfo)
    if not unit then return false end

    if not activeProfilesReady then
        rebuildActiveProfiles(getDb())
    end
    if #activeProfiles == 0 then return false end

    if not updateInfo or updateInfo.isFullUpdate or not auraState[unit] then
        scanUnitAuras(unit)
        return true
    end

    local state = getUnitAuraState(unit)
    local changed = false

    if updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            changed = removeTrackedAura(state, auraInstanceID) or changed
        end
    end

    if updateInfo.addedAuras then
        for _, auraData in ipairs(updateInfo.addedAuras) do
            changed = addTrackedAura(state, auraData) or changed
        end
    end

    if updateInfo.updatedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            changed = updateTrackedAuraByInstanceID(unit, state, auraInstanceID) or changed
        end
    end

    return changed
end

local function unitHasTrackedBuff(unit, spellID)
    local state = auraState[unit]
    if not state then
        state = scanUnitAuras(unit)
    end

    return state.spells[spellID] ~= nil
end

local function findMatchingProfile(db, healthBar, unit)
    local frame = healthBar and healthBar:GetParent()
    if not frame then return nil end

    for _, profile in ipairs(activeProfiles) do
        local spellID = tonumber(profile.spellID)
        if spellID and isSelectedFrame(profile, frame, unit) and unitHasTrackedBuff(unit, spellID) then
            return profile
        end
    end
end

local function captureBackdropColor(healthBar)
    local backdrop = healthBar and healthBar.backdrop
    if not backdrop or healthBar._mqolBuffHealthBackdropColor or not backdrop.GetBackdropColor then return end

    local r, g, b, a = backdrop:GetBackdropColor()
    healthBar._mqolBuffHealthBackdropColor = { r = r, g = g, b = b, a = a }
end

local function restoreBackdropColor(healthBar)
    local backdrop = healthBar and healthBar.backdrop
    local color = healthBar and healthBar._mqolBuffHealthBackdropColor
    if not backdrop or not color or not backdrop.SetBackdropColor then return end

    backdrop:SetBackdropColor(color.r or 0, color.g or 0, color.b or 0, color.a or 1)
end

local function applyBuffColor(healthBar, unit)
    local db = getDb()
    if not db or not db.enabled then
        restoreBackdropColor(healthBar)
        return
    end

    if not activeProfilesReady then
        rebuildActiveProfiles(db)
    end

    local profile = findMatchingProfile(db, healthBar, unit)
    if not profile then
        restoreBackdropColor(healthBar)
        return
    end

    local color = profile.color or {}
    local r, g, b = color.r or 1, color.g or 1, color.b or 1
    if UF and UF.SetStatusBarColor then
        UF:SetStatusBarColor(healthBar, r, g, b)
    else
        healthBar:SetStatusBarColor(r, g, b)
    end

    if healthBar.bg and healthBar.bg.SetVertexColor then
        healthBar.bg:SetVertexColor(r, g, b)
    end

    if healthBar.backdrop and healthBar.backdrop.SetBackdropColor then
        captureBackdropColor(healthBar)
        healthBar.backdrop:SetBackdropColor(r, g, b, healthBar._mqolBuffHealthBackdropColor and healthBar._mqolBuffHealthBackdropColor.a or 1)
    end
end

local function debugPrint(message)
    local line = "|cff33ff99MQOL BuffHealth:|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    else
        print(line)
    end
end

local function boolText(value)
    return value and "yes" or "no"
end

local function getFrameName(frame)
    return frame and (frame:GetName() or "<unnamed>") or "<nil>"
end

local function getFrameUnit(frame)
    return frame and (frame.unit or frame.displayedUnit)
end

local function getAuraDebug(unit, spellID)
    local debug = { any = false, player = false, sources = {} }
    local seenSources = {}

    local function addAura(auraData)
        if not auraData or auraData.spellId ~= spellID then return end

        debug.any = true
        if auraData.sourceUnit == "player" then debug.player = true end

        local source = tostring(auraData.sourceUnit or "nil")
        if not seenSources[source] then
            table.insert(debug.sources, source)
            seenSources[source] = true
        end
    end

    if unit == "player" and GetPlayerAuraBySpellID then
        local ok, auraData = pcall(GetPlayerAuraBySpellID, spellID)
        if ok then addAura(auraData) end
    end

    if GetUnitAuraBySpellID then
        local ok, auraData = pcall(GetUnitAuraBySpellID, unit, spellID)
        if ok then addAura(auraData) end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(auraData)
            addAura(auraData)
        end, true)
    elseif GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, auraData = pcall(GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not auraData then break end
            addAura(auraData)
        end
    end

    return debug
end

local function getSelectedProfileLabel(frame, unit)
    local db = ensureDbShape()
    if not db or not db.buffs then return "none" end

    local labels = {}
    forEachProfile(db, function(_, profile)
        if profile.enabled and isSelectedFrame(profile, frame, unit) then
            table.insert(labels, profile.label or tostring(profile.spellID))
        end
    end)

    return #labels > 0 and table.concat(labels, ", ") or "none"
end

local function printDebugForUnit(unit)
    local db = ensureDbShape()
    if not db or not db.enabled then
        debugPrint("feature disabled")
        return
    end

    scanExistingHealthBars()
    debugPrint("unit=" .. tostring(unit) .. " exists=" .. boolText(UnitExists(unit)) .. " featureEnabled=true")

    if UF and UF.db and UF.db.colors then
        local colors = UF.db.colors
        debugPrint("ElvUI transparentHealth=" .. boolText(colors.transparentHealth) .. " customHealthBackdrop=" .. boolText(colors.customhealthbackdrop))
    end

    if not db then return end

    debugPrint("currentSpecID=" .. tostring(getCurrentSpecID() or "none"))

    forEachProfile(db, function(_, profile)
        if not profile.enabled then return end

        local spellID = tonumber(profile.spellID)
        if spellID then
            local aura = getAuraDebug(unit, spellID)
            local sources = #aura.sources > 0 and table.concat(aura.sources, ",") or "none"
            debugPrint((profile.label or tostring(spellID)) .. " spellID=" .. spellID .. " specMatch=" .. boolText(profileMatchesCurrentSpec(profile)) .. " auraAny=" .. boolText(aura.any) .. " playerCast=" .. boolText(aura.player) .. " sources=" .. sources)
        end
    end)

    local elvFrames, elvHealthBars, unwrappedHealthBars = 0, 0, 0
    local frame = EnumerateFrames()
    while frame do
        if tostring(frame:GetName() or ""):match("^ElvUF_") then
            elvFrames = elvFrames + 1
            if frame.Health then
                elvHealthBars = elvHealthBars + 1
                if not hookedHealthBars[frame.Health] then
                    unwrappedHealthBars = unwrappedHealthBars + 1
                end
            end
        end
        frame = EnumerateFrames(frame)
    end

    local total, sameUnit, printed = 0, 0, 0
    for healthBar in pairs(hookedHealthBars) do
        total = total + 1
        local frame = healthBar and healthBar:GetParent()
        local frameUnit = getFrameUnit(frame)
        if frameUnit == unit then sameUnit = sameUnit + 1 end
    end

    debugPrint("elvFrames=" .. elvFrames .. " elvHealthBars=" .. elvHealthBars .. " hookedHealthBars=" .. total .. " unwrappedHealthBars=" .. unwrappedHealthBars .. " matchingUnit=" .. sameUnit)

    for healthBar in pairs(hookedHealthBars) do
        local frame = healthBar and healthBar:GetParent()
        local frameUnit = getFrameUnit(frame)
        if frameUnit == unit or printed < 6 then
            printed = printed + 1
            debugPrint(
                "frame=" .. getFrameName(frame)
                .. " unit=" .. tostring(frame and frame.unit)
                .. " displayedUnit=" .. tostring(frame and frame.displayedUnit)
                .. " group=" .. tostring(getFrameGroup(frame, frameUnit))
                .. " selectedFor=" .. getSelectedProfileLabel(frame, frameUnit)
            )
        end
        if printed >= 12 then break end
    end
end

function addon.DebugBuffHealthColor(message)
    local unit = strtrim(message or "")
    if unit == "" then unit = "target" end
    if unit == "self" then unit = "player" end
    printDebugForUnit(unit)
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

scanExistingHealthBars = function()
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
    if frame.Health.ForceUpdate then
        frame.Health:ForceUpdate()
    elseif frame.UpdateAllElements then
        frame:UpdateAllElements("ElvUI_UpdateAllElements")
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
    frame:SetScript("OnEvent", function(_, _, eventUnit, updateInfo)
        if processUnitAuraUpdate(eventUnit, updateInfo) then
            refreshUnit(eventUnit)
        end
    end)
    eventFrames[unit] = frame
end

local function unregisterEvents()
    for unit, frame in pairs(eventFrames) do
        frame:UnregisterAllEvents()
        frame:SetScript("OnEvent", nil)
        eventFrames[unit] = nil
    end

    if specEventFrame then
        specEventFrame:UnregisterAllEvents()
        specEventFrame:SetScript("OnEvent", nil)
    end
end

local function registerSpecEvent()
    if not specEventFrame then
        specEventFrame = CreateFrame("Frame")
    end

    specEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    specEventFrame:SetScript("OnEvent", function()
        registerEvents()
        refreshAll()
    end)
end

registerEvents = function()
    unregisterEvents()
    clearAuraState()

    local db = ensureDbShape()
    rebuildActiveProfiles(db)
    if not db or not db.enabled then return end

    registerSpecEvent()

    local selected = {}
    for _, profile in ipairs(activeProfiles) do
        local frames = profile.frames or {}
        selected.player = selected.player or frames.player
        selected.target = selected.target or frames.target
        selected.party  = selected.party or frames.party
        selected.raid   = selected.raid or frames.raid1 or frames.raid2 or frames.raid3
    end

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
            local db = getDb()
            if not db or not db.enabled then return end
            if frame and frame.Health then
                wrapHealthBar(frame.Health)
            end
        end)
    end

    hooksRegistered = true
end

function BuffHealthColor:Initialize()
    local db = ensureDbShape()
    if not db or not db.enabled then return end
    registerHooks()
    scanExistingHealthBars()
    self:Apply()
end

function BuffHealthColor:Apply()
    local db = ensureDbShape()
    if not db or not db.enabled then
        unregisterEvents()
        clearAuraState()
        activeProfiles = {}
        activeProfilesReady = false
        return
    end

    registerHooks()
    scanExistingHealthBars()
    registerEvents()
    refreshAll()
end
