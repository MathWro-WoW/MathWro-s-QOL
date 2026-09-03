local _, addon = ...
local CT = addon.combatTracker

-- ── Racial spell data ─────────────────────────────────────────────────────────
-- Key: select(2, UnitRace("player")) — non-localised English race string
-- Each entry: { spellID, name } where name is used for the per-name toggle.
-- Multiple entries per race handle class variants (e.g. Blood Fury has 3 spell IDs).
-- Only the first matching IsSpellKnown() entry per name is used.
local RACIAL_DATA = {
    ["Human"]              = { { spellID=59752,  name="Every Man for Himself" } },
    ["Dwarf"]              = { { spellID=20594,  name="Stoneform" } },
    ["NightElf"]           = { { spellID=58984,  name="Shadowmeld" } },
    ["Gnome"]              = { { spellID=20589,  name="Escape Artist" } },
    ["Draenei"]            = { { spellID=28880,  name="Gift of the Naaru" } },
    ["Worgen"]             = { { spellID=68992,  name="Darkflight" } },
    ["LightforgedDraenei"] = { { spellID=255647, name="Light's Judgment" } },
    ["DarkIronDwarf"]      = { { spellID=265221, name="Fireblood" } },
    ["KulTiran"]           = { { spellID=287712, name="Haymaker" } },
    ["Mechagnome"]         = { { spellID=297830, name="Emergency Failsafe" } },
    ["Orc"]    = {
        { spellID=20572,  name="Blood Fury" },
        { spellID=33697,  name="Blood Fury" },
        { spellID=33702,  name="Blood Fury" },
    },
    ["Scourge"]            = { { spellID=20577,  name="Cannibalize" } },
    ["Tauren"]             = { { spellID=20549,  name="War Stomp" } },
    ["Troll"]              = { { spellID=26297,  name="Berserking" } },
    ["BloodElf"] = {
        { spellID=25046,  name="Arcane Torrent" },
        { spellID=28730,  name="Arcane Torrent" },
        { spellID=50613,  name="Arcane Torrent" },
        { spellID=80483,  name="Arcane Torrent" },
        { spellID=129597, name="Arcane Torrent" },
        { spellID=155145, name="Arcane Torrent" },
    },
    ["Goblin"]  = {
        { spellID=69070,  name="Rocket Jump" },
        { spellID=69041,  name="Rocket Barrage" },
    },
    ["Nightborne"]         = { { spellID=260364, name="Arcane Pulse" } },
    ["HighmountainTauren"] = { { spellID=255654, name="Bull Rush" } },
    ["MagharOrc"]          = { { spellID=274738, name="Ancestral Call" } },
    ["ZandalariTroll"]     = { { spellID=291944, name="Regeneratin'" } },
    ["Vulpera"] = {
        { spellID=312411, name="Bag of Tricks" },
        { spellID=256948, name="Make Camp" },
    },
    ["Pandaren"]           = { { spellID=107079, name="Quaking Palm" } },
    ["Dracthyr"] = {
        { spellID=358267, name="Soar" },
        { spellID=375901, name="Tempered Scales" },
    },
    ["Earthen"]            = { { spellID=461597, name="Stone Form" } },
}

-- ── Section definition ────────────────────────────────────────────────────────

local racials = {
    name       = "racials",
    buttons    = {},
    eventFrame = nil,
    _racialEntries = {},  -- populated by RebuildIcons(); read by Config panel
}

function racials:GetIcons()
    local visible = {}
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then
            table.insert(visible, btn)
        end
    end
    return visible
end

-- Builds the list of active racial spells for this character, filters hidden ones,
-- then updates the button pool accordingly.
function racials:RebuildIcons()
    local db      = addon.db.combatTracker
    local frameDb = db.frames.racials

    -- When disabled: hide all pool buttons and update layout
    if not db.enabled or not frameDb.enabled then
        for _, btn in ipairs(self.buttons) do btn:Hide() end
        CT:LayoutSection(CT:GetHostKey("racials"))
        return
    end

    local _, raceKey = UnitRace("player")
    local spellList  = RACIAL_DATA[raceKey] or {}

    -- Deduplicate by name: first seen (known) spell per name is canonical
    local seen     = {}
    local active   = {}  -- not hidden
    local allKnown = {}  -- known (used for Config panel toggle list)
    for _, entry in ipairs(spellList) do
        if not seen[entry.name] and IsSpellKnown(entry.spellID) then
            seen[entry.name] = true
            table.insert(allKnown, entry)
            if not db.racials.hiddenSpells[entry.name] then
                table.insert(active, entry)
            end
        end
    end
    self._racialEntries = allKnown  -- exposed for Config panel

    -- Register any newly-created pool buttons with Masque (if active)
    local mg = CT._masqueGroups()
    if mg and addon.db.combatTracker.masque.enabled and mg[self.name] then
        for _, btn in ipairs(self.buttons) do
            if not btn._masqueRegistered then
                CT._registerButtonMasque(mg[self.name], btn)
                btn._masqueRegistered = true
            end
        end
    end

    -- Grow pool if needed (pool never shrinks)
    local hostKey = CT:GetHostKey(self.name)
    local frameW  = addon.db.combatTracker.frames[hostKey].iconWidth
    local frameH  = addon.db.combatTracker.frames[hostKey].iconHeight
    while #self.buttons < #active do
        local btn = CT.CreateButton()
        btn._sectionName = self.name
        btn:SetSize(frameW, frameH)  -- pre-size before Masque registers the button
        -- Register with Masque if active
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
            local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry.spellID)
                or GetSpellTexture(entry.spellID)
            btn.icon:SetTexture(icon)
            btn._spellID = entry.spellID
            btn:Show()
        else
            btn._spellID = nil
            btn:Hide()
        end
    end

    CT:ApplySectionFont("racials")
    CT:ApplyCooldownFont("racials")
    C_Timer.After(0, function() self:UpdateCooldowns() end)
    CT:LayoutSection(CT:GetHostKey("racials"))
end

-- Refreshes cooldown state through the engine-owned duration object.
function racials:UpdateCooldowns()
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() and btn._spellID then
            CT.UpdateButtonCooldownFromSpell(btn, btn._spellID)
        end
    end
end

-- Registers events on a private frame
function racials:Initialize()
    local self = self  -- upvalue for closures

    -- Populate _allRacialNames from static data (no IsSpellKnown check needed).
    -- This is used by the Config panel so toggles appear immediately on panel open,
    -- even before RebuildIcons() has run (where IsSpellKnown may return false at login).
    local _, raceKey = UnitRace("player")
    local spellList  = RACIAL_DATA[raceKey] or {}
    local seenNames  = {}
    self._allRacialNames = {}
    for _, entry in ipairs(spellList) do
        if not seenNames[entry.name] then
            seenNames[entry.name] = true
            table.insert(self._allRacialNames, { name = entry.name })
        end
    end

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self.eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    self.eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")

    self.eventFrame:SetScript("OnEvent", function(_, event, unit)
        local db = addon.db.combatTracker
        local frameDb = db and db.frames and db.frames.racials

        if event == "SPELL_UPDATE_COOLDOWN" then
            if not db.enabled or not frameDb.enabled then return end
            if not self._cdPending then
                self._cdPending = true
                C_Timer.After(0, function()
                    self._cdPending = false
                    self:UpdateCooldowns()
                end)
            end
        elseif event == "UNIT_ENTERED_VEHICLE" and unit == "player" then
            -- Suppress racial frame while in vehicle
            if CT.frames["racials"] then CT.frames["racials"]:Hide() end
        elseif event == "UNIT_EXITED_VEHICLE" and unit == "player" then
            local db = addon.db.combatTracker
            if db.enabled and db.frames.racials.enabled then
                local frameDb = db.frames.racials
                local isMerged = frameDb.mergeInto
                    and frameDb.mergeInto ~= "racials"
                    and CT.frames[frameDb.mergeInto] ~= nil
                if not isMerged and CT.frames["racials"] then
                    CT.frames["racials"]:Show()
                end
            end
        end
    end)
end

CT:RegisterSection(racials)
