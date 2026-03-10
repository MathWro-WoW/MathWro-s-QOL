local _, addon = ...

local AuctionFilter = { name = "auctionFilter" }
addon:RegisterFeature(AuctionFilter)

-- Write the two managed filter entries into AUCTION_HOUSE_DEFAULT_FILTERS.
-- Only touches CurrentExpansionOnly and UsableOnly — all other entries untouched.
local function applyFilters()
    if not AUCTION_HOUSE_DEFAULT_FILTERS then return end
    local db = addon.db and addon.db.auctionFilter
    if not db then return end
    AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = db.currentExpansionOnly == true
    AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.UsableOnly] = db.usableOnly == true
end

-- Register at top level (same pattern as AuctionHouseFilterDefaults reference addon)
-- so the handler is in place before Blizzard_AuctionHouseUI loads.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        self:UnregisterEvent("ADDON_LOADED")
        applyFilters()
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- Re-apply on every open so in-session manual changes are reset.
        applyFilters()
    end
end)

function AuctionFilter:Apply()
    applyFilters()
end

function AuctionFilter:Initialize()
    -- Event frame already registered at top level.
end
