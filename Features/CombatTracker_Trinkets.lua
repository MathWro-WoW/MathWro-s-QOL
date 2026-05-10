local _, addon = ...
local CT = addon.combatTracker

local TRINKET_SLOTS = { 13, 14 }  -- inventory slot IDs for top/bottom trinket

local trinkets = {
    name       = "trinkets",
    buttons    = {},
    eventFrame = nil,
    pendingItems = {},
}

function trinkets:GetIcons()
    local visible = {}
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then table.insert(visible, btn) end
    end
    return visible
end

local function getItemSpell(itemID)
    if C_Item and C_Item.GetItemSpell then
        return C_Item.GetItemSpell(itemID)
    end
    return GetItemSpell(itemID)
end

local function isItemDataCached(itemID)
    if C_Item and C_Item.IsItemDataCachedByID then
        return C_Item.IsItemDataCachedByID(itemID)
    end
    return GetItemInfo(itemID) ~= nil
end

local function requestItemData(itemID)
    if not itemID then return end
    trinkets.pendingItems[itemID] = true
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

-- Scans both trinket slots, builds an active list, updates button pool.
function trinkets:RebuildIcons()
    local db      = addon.db.combatTracker
    local frameDb = db.frames.trinkets

    if not db.enabled or not frameDb.enabled then
        for _, btn in ipairs(self.buttons) do btn:Hide() end
        CT:LayoutSection(CT:GetHostKey("trinkets"))
        return
    end

    local active = {}  -- { slotID, isOnUse, icon }
    for _, slotID in ipairs(TRINKET_SLOTS) do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local spellName = getItemSpell(itemID)
            local isOnUse   = spellName ~= nil
            local icon      = GetInventoryItemTexture("player", slotID)
            local isCached  = isItemDataCached(itemID)

            if not icon or not isCached then
                requestItemData(itemID)
            end

            if icon and (not frameDb.onUseOnly or isOnUse) then
                table.insert(active, { slotID = slotID, isOnUse = isOnUse, icon = icon })
            end
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
    local hostKey = CT:GetHostKey(self.name)
    local frameW  = addon.db.combatTracker.frames[hostKey].iconWidth
    local frameH  = addon.db.combatTracker.frames[hostKey].iconHeight
    while #self.buttons < #active do
        local btn = CT.CreateButton()
        btn._sectionName = self.name
        btn:SetSize(frameW, frameH)  -- pre-size before Masque registers the button
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
            btn._slotID  = entry.slotID
            btn._isOnUse = entry.isOnUse
            btn:Show()
        else
            btn._slotID  = nil
            btn._isOnUse = nil
            btn:Hide()
        end
    end

    CT:ApplySectionFont("trinkets")
    CT:ApplyCooldownFont("trinkets")
    C_Timer.After(0, function() self:UpdateCooldowns() end)
    CT:LayoutSection(CT:GetHostKey("trinkets"))
end

-- For on-use trinkets: query inventory slot cooldown.
-- For passive trinkets: always clear the cooldown display.
function trinkets:UpdateCooldowns()
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() and btn._slotID then
            if btn._isOnUse then
                -- GetInventoryItemCooldown returns start, duration, enable
                local start, duration, enable = GetInventoryItemCooldown("player", btn._slotID)
                if enable then
                    CT.UpdateButtonCooldown(btn, start, duration)
                else
                    CT.UpdateButtonCooldown(btn, 0, 0)
                end
            else
                CT.UpdateButtonCooldown(btn, 0, 0)
            end
        end
    end
end

function trinkets:Initialize()
    local self = self
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    self.eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
        local db = addon.db.combatTracker
        local frameDb = db and db.frames and db.frames.trinkets

        if event == "ITEM_DATA_LOAD_RESULT" then
            local itemID = arg1
            local success = arg2
            if not db.enabled or not frameDb.enabled then return end
            if itemID and self.pendingItems[itemID] then
                self.pendingItems[itemID] = nil
                if success ~= false then
                    self:RebuildIcons()
                end
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- At PLAYER_LOGIN inventory/item data may not be ready. This scan
            -- requests missing item data; ITEM_DATA_LOAD_RESULT drives the retry.
            if not db.enabled or not frameDb.enabled then return end
            self:RebuildIcons()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            if not db.enabled or not frameDb.enabled then return end
            -- Only react to trinket slot changes
            local slotID = arg1
            if slotID == 13 or slotID == 14 then
                self:RebuildIcons()
            end
        elseif event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            if not db.enabled or not frameDb.enabled then return end
            if not self._cdPending then
                self._cdPending = true
                C_Timer.After(0, function()
                    self._cdPending = false
                    self:UpdateCooldowns()
                end)
            end
        end
    end)
end

CT:RegisterSection(trinkets)
