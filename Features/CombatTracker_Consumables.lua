local _, addon = ...
local CT = addon.combatTracker

-- ── Known consumable item IDs ─────────────────────────────────────────────────
-- These are The War Within (11.x) item IDs. Verify in-game for Midnight (12.x):
--   /script local n=GetItemInfo(ITEMID); print(n)
-- Use the options panel "Custom Items" field to add new IDs without code changes.
local CONSUMABLE_IDS = {
    combatPotions = {
        212265,  -- Tempered Potion
        212264,  -- Potion of Unwavering Focus
        212283,  -- Frontline Potion
        212270,  -- Potion of Shocking Disclosure
    },
    healingPotions = {
        212603,  -- Algari Healing Potion
        212604,  -- Cavedweller's Delight
    },
    manaPotions = {
        212607,  -- Algari Mana Potion
    },
    healthstone = {
        5512,    -- Healthstone (conjured item; shared CD tracked via spell below)
    },
}
-- Spell ID whose cooldown represents the Healthstone shared cooldown
local HEALTHSTONE_CD_SPELL = 6262

-- Fallback icon shown when hideIfMissing=false and item is not in bags
local FALLBACK_ICON = 134400  -- classic potion flask icon

local consumables = {
    name           = "consumables",
    buttons        = {},
    eventFrame     = nil,
    bagScanPending = false,
    -- Cached scan results: { [itemID] = { icon, count } }
    cachedItems    = {},
}

function consumables:GetIcons()
    local visible = {}
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then table.insert(visible, btn) end
    end
    return visible
end

-- Full bag scan. Builds active item list and updates button pool.
function consumables:ScanBags()
    local db      = addon.db.combatTracker
    local frameDb = db.frames.consumables

    if not db.enabled or not frameDb.enabled then
        for _, btn in ipairs(self.buttons) do btn:Hide() end
        CT:LayoutSection(CT:GetHostKey("consumables"))
        return
    end

    -- Build lookup set of all tracked item IDs → category
    local tracked = {}
    if frameDb.showCombatPotions then
        for _, id in ipairs(CONSUMABLE_IDS.combatPotions) do
            tracked[id] = "combatPotions"
        end
    end
    if frameDb.showHealingPotions then
        for _, id in ipairs(CONSUMABLE_IDS.healingPotions) do
            tracked[id] = "healingPotions"
        end
    end
    if frameDb.showManaPotions then
        for _, id in ipairs(CONSUMABLE_IDS.manaPotions) do
            tracked[id] = "manaPotions"
        end
    end
    if frameDb.showHealthstone then
        for _, id in ipairs(CONSUMABLE_IDS.healthstone) do
            tracked[id] = "healthstone"
        end
    end
    for id in pairs(frameDb.customItems or {}) do
        tracked[id] = "custom"
    end

    -- Scan all bags (0–4)
    local found = {}  -- { [itemID] = { icon, count } }
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and tracked[info.itemID] then
                local existing = found[info.itemID]
                if existing then
                    existing.count = existing.count + (info.stackCount or 1)
                else
                    found[info.itemID] = {
                        icon  = info.iconFileID,
                        count = info.stackCount or 1,
                    }
                end
            end
        end
    end
    self.cachedItems = found

    -- Build ordered active list
    -- Order: combat potions → healing potions → mana potions → healthstone → custom
    local active = {}

    local function addFromList(idList)
        for _, id in ipairs(idList) do
            if tracked[id] then
                if found[id] or not frameDb.hideIfMissing then
                    local f = found[id] or { icon = FALLBACK_ICON, count = 0 }
                    table.insert(active, {
                        itemID   = id,
                        icon     = f.icon,
                        count    = f.count,
                        category = tracked[id],
                    })
                end
            end
        end
    end

    if frameDb.showCombatPotions  then addFromList(CONSUMABLE_IDS.combatPotions)  end
    if frameDb.showHealingPotions then addFromList(CONSUMABLE_IDS.healingPotions) end
    if frameDb.showManaPotions    then addFromList(CONSUMABLE_IDS.manaPotions)    end
    if frameDb.showHealthstone    then addFromList(CONSUMABLE_IDS.healthstone)    end

    -- Custom items in sorted order
    local customIDs = {}
    for id in pairs(frameDb.customItems or {}) do table.insert(customIDs, id) end
    table.sort(customIDs)
    for _, id in ipairs(customIDs) do
        if found[id] or not frameDb.hideIfMissing then
            local f = found[id] or { icon = FALLBACK_ICON, count = 0 }
            table.insert(active, {
                itemID   = id,
                icon     = f.icon,
                count    = f.count,
                category = "custom",
            })
        end
    end

    -- Register any pre-existing pool buttons with Masque (if active)
    local mg = CT._masqueGroups()
    if mg and addon.db.combatTracker.masque.enabled and mg[self.name] then
        for _, btn in ipairs(self.buttons) do
            if not btn._masqueRegistered then
                CT._registerButtonMasque(mg[self.name], btn)
                btn._masqueRegistered = true
            end
        end
    end

    -- Grow pool if needed
    while #self.buttons < #active do
        local btn = CT.CreateButton()
        btn._sectionName = self.name
        if mg and addon.db.combatTracker.masque.enabled and mg[self.name] then
            CT._registerButtonMasque(mg[self.name], btn)
            btn._masqueRegistered = true
        end
        table.insert(self.buttons, btn)
    end

    -- Update pool entries
    for i, btn in ipairs(self.buttons) do
        local entry = active[i]
        if entry then
            btn.icon:SetTexture(entry.icon)
            btn._itemID   = entry.itemID
            btn._category = entry.category
            btn:Show()
        else
            btn._itemID   = nil
            btn._category = nil
            btn:Hide()
        end
    end

    self:UpdateCooldowns()
    CT:LayoutSection(CT:GetHostKey("consumables"))
end

function consumables:RebuildIcons()
    self:ScanBags()
end

-- Refreshes cooldown overlays without re-scanning bags.
-- Healthstone uses the shared conjure cooldown spell; others use GetItemCooldown.
function consumables:UpdateCooldowns()
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() and btn._itemID then
            local start, duration
            if btn._category == "healthstone" then
                local info = C_Spell.GetSpellCooldown(HEALTHSTONE_CD_SPELL)
                start    = info and info.startTime or 0
                duration = info and info.duration  or 0
            else
                local info = C_Item.GetItemCooldown(btn._itemID)
                start    = info and info.startTime or 0
                duration = info and info.duration  or 0
            end
            CT.UpdateButtonCooldown(btn, start, duration)
        end
    end
end

function consumables:Initialize()
    local self = self
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE" then
            -- Debounce: BAG_UPDATE fires 50-100x per loot event; coalesce into one scan
            if self.bagScanPending then return end
            self.bagScanPending = true
            C_Timer.After(0, function()
                self.bagScanPending = false
                self:ScanBags()
            end)
        elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            self:UpdateCooldowns()
        end
    end)
end

CT:RegisterSection(consumables)
