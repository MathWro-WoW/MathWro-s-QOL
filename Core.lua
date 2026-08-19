local addonName, addon = ...
MathWroQOL = addon  -- global reference for other files

addon.features = {}

local defaults = {
    vehicleBar = {
        enabled = false,
        bars = { [1] = true },
    },
    gameMenu = {
        scale = 1.0,
        moveable = false,
    },
    buffHealthColor = {
        enabled = false,
        selectedBuff = "atonement",
        buffs = {
            atonement = {
                enabled = true,
                label = "Atonement",
                spellID = 194384,
                color = { r = 0.95, g = 0.72, b = 0.22 },
                allSpecs = false,
                specs = { [256] = true },
                validSpecs = { [256] = true },
                frames = {
                    player = false,
                    target = false,
                    party  = true,
                    raid1  = true,
                    raid2  = true,
                    raid3  = true,
                },
            },
            lifebloom = {
                enabled = false,
                label = "Lifebloom",
                spellID = 33763,
                color = { r = 0.20, g = 0.85, b = 0.25 },
                allSpecs = false,
                specs = { [105] = true },
                validSpecs = { [105] = true },
                frames = {
                    player = false,
                    target = false,
                    party  = true,
                    raid1  = true,
                    raid2  = true,
                    raid3  = true,
                },
            },
            prayerOfMending = {
                enabled = false,
                label = "Prayer of Mending",
                spellID = 41635,
                color = { r = 0.95, g = 0.88, b = 0.42 },
                allSpecs = false,
                specs = { [257] = true },
                validSpecs = { [256] = true, [257] = true },
                frames = {
                    player = false,
                    target = false,
                    party  = true,
                    raid1  = true,
                    raid2  = true,
                    raid3  = true,
                },
            },
            riptide = {
                enabled = false,
                label = "Riptide",
                spellID = 61295,
                color = { r = 0.16, g = 0.62, b = 0.95 },
                allSpecs = false,
                specs = { [264] = true },
                validSpecs = { [264] = true },
                frames = {
                    player = false,
                    target = false,
                    party  = true,
                    raid1  = true,
                    raid2  = true,
                    raid3  = true,
                },
            },
            beaconOfTheSavior = {
                enabled = false,
                label = "Beacon of the Savior",
                spellID = 1244893,
                color = { r = 1.00, g = 0.78, b = 0.50 },
                allSpecs = false,
                specs = { [65] = true },
                validSpecs = { [65] = true },
                frames = {
                    player = false,
                    target = false,
                    party  = true,
                    raid1  = true,
                    raid2  = true,
                    raid3  = true,
                },
            },
            renewingMist = {
                enabled = false,
                label = "Renewing Mist",
                spellID = 448430,
                color = { r = 0.35, g = 0.92, b = 0.70 },
                allSpecs = false,
                specs = { [270] = true },
                validSpecs = { [270] = true },
                frames = {
                    player = false,
                    target = false,
                    party  = true,
                    raid1  = true,
                    raid2  = true,
                    raid3  = true,
                },
            },
        },
        customOrder = {},
    },
    cdmButton = {
        enabled = false,
        slashWA = false,
        slashCM = false,
    },
    cmcMasque = {
        enabled = false,
        viewers = {
            essential = true,
            utility = true,
            buffIcons = true,
        },
    },
    auctionFilter = {
        currentExpansionOnly = false,
        usableOnly = false,
    },
    combatLog = {
        dungeon      = false,
        mythicPlus   = false,
        raid         = false,
        scenario     = false,
        pvp          = false,
        arena        = false,
        maxLevelOnly = false,
    },
    editModeNudge = {
        enabled = false,
        ellesmereEnabled = false,
    },
    combatTracker = {
        enabled = false,
        frames = {
            racials = {
                point = "CENTER", x = -220, y = 200,
                layout = "horizontal",
                growDirection = "growRight",
                gridCols = 2,
                iconWidth = 36,
                iconHeight = 36,
                mergeInto = nil,
                enabled = true,
                desaturateOnCD = false,
                stackCountEnabled  = true,
                stackCountFontSize = 12,
                stackCountFont     = "Fonts\\FRIZQT__.TTF",
                cdCountEnabled     = true,
                cdCountFontSize    = 14,
                cdCountFont        = "Fonts\\FRIZQT__.TTF",
            },
            trinkets = {
                point = "CENTER", x = 0, y = 200,
                layout = "horizontal",
                growDirection = "growRight",
                gridCols = 2,
                iconWidth = 36,
                iconHeight = 36,
                mergeInto = nil,
                enabled = true,
                onUseOnly = true,
                desaturateOnCD = false,
                stackCountEnabled  = true,
                stackCountFontSize = 12,
                stackCountFont     = "Fonts\\FRIZQT__.TTF",
                cdCountEnabled     = true,
                cdCountFontSize    = 14,
                cdCountFont        = "Fonts\\FRIZQT__.TTF",
            },
            consumables = {
                point = "CENTER", x = 220, y = 200,
                layout = "horizontal",
                growDirection = "growRight",
                gridCols = 2,
                iconWidth = 36,
                iconHeight = 36,
                mergeInto = nil,
                enabled = true,
                hideIfMissing = true,
                showCombatPotions = true,
                showHealingPotions = true,
                showManaPotions = true,
                showHealthstone = true,
                customItems = {},
                itemOrder = {},
                desaturateOnCD = false,
                stackCountEnabled  = true,
                stackCountFontSize = 12,
                stackCountFont     = "Fonts\\FRIZQT__.TTF",
                cdCountEnabled     = true,
                cdCountFontSize    = 14,
                cdCountFont        = "Fonts\\FRIZQT__.TTF",
            },
        },
        racials = {
            hiddenSpells = {},
        },
        masque = {
            enabled = false,
        },
    },
}

local function applyDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            applyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        MathWroQOLDB = MathWroQOLDB or {}
        applyDefaults(MathWroQOLDB, defaults)
        addon.db = MathWroQOLDB
    elseif event == "PLAYER_LOGIN" then
        for _, feature in ipairs(addon.features) do
            if feature.Initialize then feature:Initialize() end
        end
    end
end)

-- Register a feature table. Feature must have a .name string.
-- Optionally: .Initialize() called on PLAYER_LOGIN, .Apply() called when settings change.
function addon:RegisterFeature(feature)
    table.insert(self.features, feature)
end

-- Tell a feature (by name) to re-apply its logic after a settings change.
function addon:NotifyFeature(name)
    for _, feature in ipairs(self.features) do
        if feature.name == name and feature.Apply then
            feature:Apply()
        end
    end
end

SLASH_MQOLBUFFDEBUG1 = "/mqolbuffdebug"
SlashCmdList["MQOLBUFFDEBUG"] = function(message)
    if addon.DebugBuffHealthColor then
        addon.DebugBuffHealthColor(message)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MQOL BuffHealth:|r diagnostic unavailable; BuffHealthColor did not finish loading")
    else
        print("MQOL BuffHealth: diagnostic unavailable; BuffHealthColor did not finish loading")
    end
end
