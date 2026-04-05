local _, addon = ...
local CT = addon.combatTracker

-- ── Known consumable item IDs ─────────────────────────────────────────────────
-- Midnight (12.x) item IDs.  Verify in-game:
--   /script local n=GetItemInfo(ITEMID); print(n)
-- Use the options panel "Custom Items" field to add new IDs without code changes.
local CONSUMABLE_IDS = {
    combatPotions = {
        -- Fleeting versions first — prioritised when both are in bags
        245902,  -- Fleeting Potion of Recklessness (Rank 1)
        245903,  -- Fleeting Potion of Recklessness (Rank 2)
        245897,  -- Fleeting Light's Potential (Rank 1)
        245898,  -- Fleeting Light's Potential (Rank 2)
        241288,  -- Potion of Recklessness (Rank 1)
        241289,  -- Potion of Recklessness (Rank 2)
        241308,  -- Light's Potential (Rank 1)
        241309,  -- Light's Potential (Rank 2)
    },
    healingPotions = {
        241304,  -- Silvermoon Health Potion (Rank 1)
        241305,  -- Silvermoon Health Potion (Rank 2)
    },
    manaPotions = {
        -- Fleeting versions first — prioritised when both are in bags
        245916,  -- Fleeting Lightfused Mana Potion (Rank 1)
        245917,  -- Fleeting Lightfused Mana Potion (Rank 2)
        241300,  -- Lightfused Mana Potion (Rank 1)
        241301,  -- Lightfused Mana Potion (Rank 2)
    },
    healthstone = {
        5512,    -- Healthstone (conjured item; shared CD tracked via spell below)
    },
}

-- Maps a regular potion item ID to its fleeting equivalent.
-- When both are in bags, only the fleeting version is shown.
local FLEETING_OF = {
    [241288] = 245902,  -- Potion of Recklessness R1
    [241289] = 245903,  -- Potion of Recklessness R2
    [241308] = 245897,  -- Light's Potential R1
    [241309] = 245898,  -- Light's Potential R2
    [241300] = 245916,  -- Lightfused Mana Potion R1
    [241301] = 245917,  -- Lightfused Mana Potion R2
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

    -- hideIfMissing defaults to true (hide) when nil; only false explicitly shows missing
    local showMissing = (frameDb.hideIfMissing == false)

    local function addFromList(idList)
        for _, id in ipairs(idList) do
            if tracked[id] then
                -- Fleeting priority: skip a regular potion when its fleeting
                -- equivalent is already in bags
                local fleetingID = FLEETING_OF[id]
                if fleetingID and found[fleetingID] then
                    -- Fleeting version present — suppress the regular one
                elseif found[id] or showMissing then
                    local f = found[id]
                    if not f then
                        local _, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(id)
                        f = { icon = itemIcon or FALLBACK_ICON, count = 0 }
                    end
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
        if found[id] or showMissing then
            local f = found[id]
            if not f then
                local _, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(id)
                f = { icon = itemIcon or FALLBACK_ICON, count = 0 }
            end
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
            if btn.countText then
                local count   = entry.count or 0
                local enabled = addon.db.combatTracker.frames.consumables.stackCountEnabled ~= false
                if enabled and count > 1 then
                    btn.countText:SetText(tostring(count))
                    btn.countText:Show()
                else
                    btn.countText:Hide()
                end
            end
            btn:Show()
        else
            btn._itemID   = nil
            btn._category = nil
            if btn.countText then btn.countText:Hide() end
            btn:Hide()
        end
    end

    CT:ApplySectionFont("consumables")
    CT:ApplyCooldownFont("consumables")
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
                -- C_Item.GetItemCooldown may return a table {startTime, duration} or
                -- raw scalars (startTime, duration) depending on the patch version.
                local a, b = C_Item.GetItemCooldown(btn._itemID)
                if type(a) == "table" then
                    start    = a.startTime or 0
                    duration = a.duration  or 0
                else
                    start    = a or 0
                    duration = b or 0
                end
            end
            CT.UpdateButtonCooldown(btn, start, duration)
        end
    end
end

function consumables:Initialize()
    local self = self
    -- Ensure hideIfMissing is a boolean; nil (missing from old saves) defaults to true
    local frameDb = addon.db.combatTracker.frames.consumables
    if frameDb.hideIfMissing == nil then
        frameDb.hideIfMissing = true
    end
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
