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
