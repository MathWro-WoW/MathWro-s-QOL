local _, addon = ...
local CT = addon.combatTracker

local TRINKET_SLOTS = { 13, 14 }  -- inventory slot IDs for top/bottom trinket

local trinkets = {
    name       = "trinkets",
    buttons    = {},
    eventFrame = nil,
}

function trinkets:GetIcons()
    local visible = {}
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then table.insert(visible, btn) end
    end
    return visible
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
            local spellName = GetItemSpell(itemID)
            local isOnUse   = spellName ~= nil
            if not frameDb.onUseOnly or isOnUse then
                local icon = GetInventoryItemTexture("player", slotID)
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
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

    self.eventFrame:SetScript("OnEvent", function(_, event, slotID)
        local db = addon.db.combatTracker
        local frameDb = db and db.frames and db.frames.trinkets

        if event == "PLAYER_ENTERING_WORLD" then
            -- At PLAYER_LOGIN the inventory API isn't ready yet; this event fires
            -- after all equipment data is available, giving us a reliable first scan.
            if not db.enabled or not frameDb.enabled then return end
            self:RebuildIcons()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            if not db.enabled or not frameDb.enabled then return end
            -- Only react to trinket slot changes
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
