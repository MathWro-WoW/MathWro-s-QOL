local addonName, addon = ...
MathWroQOL = addon  -- global reference for other files

addon.features = {}

local defaults = {
    vehicleBar = {
        enabled = true,
        bars = { [1] = true },
    },
    cdmButton = {
        enabled = true,
        slashWA = true,
        slashCM = true,
    },
    auctionFilter = {
        currentExpansionOnly = false,
        usableOnly = false,
    },
    combatLog = {
        dungeon      = false,
        raid         = false,
        scenario     = false,
        pvp          = false,
        arena        = false,
        maxLevelOnly = false,
    },
    editModeNudge = {
        enabled = true,
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
