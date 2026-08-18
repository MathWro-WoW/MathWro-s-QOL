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
local trackedHealthBars = setmetatable({}, { __mode = "k" })
local activeProfiles = {}
local activeProfilesReady = false
local profilesVersion = 0
local hooksRegistered = false
local specEventFrame
local scanExistingHealthBars

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
    activeProfilesReady = true
    profilesVersion = profilesVersion + 1

    if not db or not db.enabled then return end

    forEachProfile(db, function(_, profile)
        local spellID = tonumber(profile.spellID)
        if profile.enabled and spellID and profileMatchesCurrentSpec(profile) then
            table.insert(activeProfiles, profile)
        end
    end)
end

-- 12.1 hides restricted aura state from addon Lua. AuraSlots keep detection and
-- visibility engine-side; the slot's solid texture is the health-bar tint.

local function loadAuraContainer()
    if not C_AddOns or not C_AddOns.LoadAddOn or not C_AddOns.IsAddOnLoaded then return false end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer")
end

local function disableContainer(data)
    if not data or not data.container or not data.enabled then return end
    data.container:SetEnabled(false)
    data.enabled = false
end

local function createContainer(healthBar, data)
    if data.container then return data.container end
    if not loadAuraContainer() then return nil end

    local container = CreateFrame("AuraContainer", nil, healthBar, "CustomAuraContainerTemplate")
    container:SetSize(1, 1)
    container:SetPoint("CENTER", healthBar, "CENTER")

    data.container = container
    data.enabled = true
    return container
end

local function addAuraSlot(healthBar, data, index)
    local container = data.container
    local key = "buff" .. index
    local texture
    local subLevel = math.max(-8, 7 - (index - 1))

    container:AddAuraSlot(key, "HELPFUL|PLAYER", {
        candidateFilters = { includeSpellIDs = {} },
        initializeFrame = function(auraButton)
            auraButton:SetSize(1, 1)
            auraButton:SetPoint("CENTER", healthBar, "CENTER")
            auraButton:SetFrameLevel(healthBar:GetFrameLevel())
            if auraButton.SetMouseMotionEnabled then
                auraButton:SetMouseMotionEnabled(false)
            end

            texture = auraButton:CreateTexture(nil, "ARTWORK", nil, subLevel)
            local fillTexture = healthBar:GetStatusBarTexture()
            if fillTexture then
                texture:SetAllPoints(fillTexture)
            else
                texture:SetAllPoints(healthBar)
            end
            texture:SetColorTexture(0, 0, 0, 0)
        end,
    })

    local slot = {
        key = key,
        texture = texture,
    }
    data.slots[index] = slot
    return slot
end

local function collectProfilesForFrame(frame, unit)
    local profiles = {}
    for _, profile in ipairs(activeProfiles) do
        if isSelectedFrame(profile, frame, unit) then
            table.insert(profiles, profile)
        end
    end
    return profiles
end

local function syncHealthBar(healthBar, unit)
    local data = trackedHealthBars[healthBar]
    if not data then return end

    local frame = healthBar:GetParent()
    unit = unit or (frame and (frame.unit or frame.displayedUnit))
    local group = getFrameGroup(frame, unit)
    local exists = unit and UnitExists(unit) == true
    local db = getDb()

    if not db or not db.enabled then
        disableContainer(data)
        data.version = profilesVersion
        data.group = group
        data.unit = unit
        data.exists = exists
        data.synced = true
        return
    end

    if not activeProfilesReady then
        rebuildActiveProfiles(db)
    end

    if data.synced and data.version == profilesVersion and data.group == group
        and data.unit == unit and data.exists == exists
    then
        return
    end

    data.version = profilesVersion
    data.group = group
    data.unit = unit
    data.exists = exists
    data.synced = false

    local profiles = collectProfilesForFrame(frame, unit)
    if not exists or #profiles == 0 then
        disableContainer(data)
        data.synced = true
        return
    end

    local container = createContainer(healthBar, data)
    if not container then return end

    for index = #data.slots + 1, #profiles do
        addAuraSlot(healthBar, data, index)
    end

    for index, slot in ipairs(data.slots) do
        local profile = profiles[index]
        local spellID = profile and tonumber(profile.spellID)
        if slot.spellID ~= spellID then
            slot.spellID = spellID
            container:SetAuraSlotCandidateFilters(slot.key, {
                includeSpellIDs = spellID and { [spellID] = true } or {},
            })
        end

        if profile and slot.texture then
            local color = profile.color or {}
            local r, g, b = color.r or 1, color.g or 1, color.b or 1
            if slot.r ~= r or slot.g ~= g or slot.b ~= b then
                slot.texture:SetColorTexture(r, g, b, 1)
                slot.r, slot.g, slot.b = r, g, b
            end
        elseif slot.texture then
            slot.texture:SetColorTexture(0, 0, 0, 0)
        end

    end

    if data.containerUnit ~= unit then
        container:SetUnit(unit)
        data.containerUnit = unit
    end
    if not data.enabled then
        container:SetEnabled(true)
        data.enabled = true
    end
    container:UpdateAllAuras()
    data.synced = true
end

local function debugPrint(message)
    local line = "|cff33ff99MQOL BuffHealth:|r " .. tostring(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    else
        print(line)
    end
end

local function getFrameName(frame)
    return frame and (frame:GetName() or "<unnamed>") or "<nil>"
end

local function getFrameUnit(frame)
    return frame and (frame.unit or frame.displayedUnit)
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

local function refreshFrame(frame)
    if not frame or not frame.Health then return end
    if frame.Health.ForceUpdate then
        frame.Health:ForceUpdate()
    elseif frame.UpdateAllElements then
        frame:UpdateAllElements("ElvUI_UpdateAllElements")
    end
end

local function refreshAll()
    for healthBar in pairs(trackedHealthBars) do
        local frame = healthBar:GetParent()
        syncHealthBar(healthBar, getFrameUnit(frame))
        refreshFrame(frame)
    end
end

local function wrapHealthBar(healthBar)
    if not healthBar or trackedHealthBars[healthBar] then return end

    trackedHealthBars[healthBar] = { slots = {} }
    local originalPostUpdateColor = healthBar.PostUpdateColor
    healthBar.PostUpdateColor = function(bar, unit, ...)
        if originalPostUpdateColor then
            originalPostUpdateColor(bar, unit, ...)
        end
        syncHealthBar(bar, unit)
    end

    syncHealthBar(healthBar, getFrameUnit(healthBar:GetParent()))
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

local function setSpecEventEnabled(enabled)
    if enabled then
        if not specEventFrame then
            specEventFrame = CreateFrame("Frame")
            specEventFrame:SetScript("OnEvent", function()
                rebuildActiveProfiles(ensureDbShape())
                refreshAll()
            end)
        end
        specEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    elseif specEventFrame then
        specEventFrame:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
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

local function printDebugForUnit(unit)
    local db = ensureDbShape()
    if not db or not db.enabled then
        debugPrint("feature disabled")
        return
    end

    scanExistingHealthBars()
    rebuildActiveProfiles(db)
    refreshAll()

    debugPrint("unit=" .. tostring(unit)
        .. " exists=" .. tostring(UnitExists(unit) == true)
        .. " auraContainer=" .. tostring(loadAuraContainer()))
    debugPrint("currentSpecID=" .. tostring(getCurrentSpecID() or "none")
        .. " activeProfiles=" .. #activeProfiles)

    local matched = 0
    for healthBar, data in pairs(trackedHealthBars) do
        local frame = healthBar:GetParent()
        local frameUnit = getFrameUnit(frame)
        if frameUnit == unit then
            matched = matched + 1
            debugPrint("frame=" .. getFrameName(frame)
                .. " group=" .. tostring(getFrameGroup(frame, frameUnit))
                .. " selectedFor=" .. getSelectedProfileLabel(frame, frameUnit)
                .. " container=" .. tostring(data.container ~= nil)
                .. " slots=" .. #data.slots)
        end
    end
    debugPrint("matchingUnitFrames=" .. matched
        .. " auraPresence=engine-managed")
end

function addon.DebugBuffHealthColor(message)
    local unit = strtrim(message or "")
    if unit == "" then unit = "target" end
    if unit == "self" then unit = "player" end
    printDebugForUnit(unit)
end

function BuffHealthColor:Initialize()
    local db = ensureDbShape()
    if not db or not db.enabled then return end

    rebuildActiveProfiles(db)
    registerHooks()
    setSpecEventEnabled(true)
    scanExistingHealthBars()
    refreshAll()
end

function BuffHealthColor:Apply()
    local db = ensureDbShape()
    rebuildActiveProfiles(db)

    if not db or not db.enabled then
        setSpecEventEnabled(false)
        refreshAll()
        return
    end

    registerHooks()
    setSpecEventEnabled(true)
    scanExistingHealthBars()
    refreshAll()
end
