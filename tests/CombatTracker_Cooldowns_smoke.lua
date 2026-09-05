-- Developer-only smoke test for 12.1 restricted cooldown duration objects.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local durationBySpell = {}
local cooldownInfoBySpell = {}
local registeredFeature

C_Spell = {
    GetSpellCooldown = function(spellID)
        return cooldownInfoBySpell[spellID]
    end,
    GetSpellCooldownDuration = function(spellID, ignoreGCD)
        assert(ignoreGCD == true, "tracked cooldowns must ignore the global cooldown")
        return durationBySpell[spellID]
    end,
}

C_Item = {
    GetItemCooldown = function()
        error("bag item cooldowns must not drive equipped trinket frames")
    end,
}

function GetInventoryItemCooldown(unit, slotID)
    assert(unit == "player", "trinket cooldowns must query equipped inventory slots")
    assert(slotID == 13, "only the shown on-use trinket should query cooldown state")
    return 10, 90, 1, 1
end

local addon = {
    db = {
        combatTracker = {
            frames = {
                racials = { desaturateOnCD = true },
                consumables = { desaturateOnCD = true },
                trinkets = { desaturateOnCD = true },
            },
        },
    },
}

function addon:RegisterFeature(feature)
    registeredFeature = feature
end

assert(loadfile("Features/CombatTracker.lua"))("MathWroQOL", addon)
assert(registeredFeature == addon.combatTracker, "CombatTracker did not register")
assert(loadfile("Features/CombatTracker_Racials.lua"))("MathWroQOL", addon)
assert(loadfile("Features/CombatTracker_Consumables.lua"))("MathWroQOL", addon)
assert(loadfile("Features/CombatTracker_Trinkets.lua"))("MathWroQOL", addon)

local function newButton(sectionName, spellID, fields)
    local button = fields or {}
    button._sectionName = sectionName
    button._spellID = spellID
    button.icon = {
        SetDesaturated = function(_, value)
            button.desaturated = value
        end,
    }
    button.cooldown = {
        Clear = function()
            button.cleared = true
        end,
        SetCooldown = function(_, start, duration, modRate)
            button.appliedStart = start
            button.appliedDuration = duration
            button.appliedModRate = modRate
        end,
        SetCooldownFromDurationObject = function(_, duration, clearIfZero)
            button.appliedDurationObject = duration
            button.clearIfZero = clearIfZero
        end,
    }

    function button:IsShown()
        return true
    end

    return button
end

local function restrictedDuration()
    return {
        IsZero = function()
            error("addon code must not inspect duration-object state")
        end,
    }
end

local racialDuration = restrictedDuration()
local healthstoneDuration = restrictedDuration()
local potionDuration = restrictedDuration()
local trinketSpellDuration = restrictedDuration()
local function setCooldownState(spellID, duration, isActive, isOnGCD)
    durationBySpell[spellID] = duration
    cooldownInfoBySpell[spellID] = {
        isActive = isActive,
        isOnGCD = isOnGCD,
    }
end

setCooldownState(1001, racialDuration, true, false)
setCooldownState(6262, healthstoneDuration, true, false)
setCooldownState(1002, potionDuration, true, false)
setCooldownState(1003, trinketSpellDuration, true, false)

local racialButton = newButton("racials", 1001)
addon.combatTracker.sections.racials.buttons = { racialButton }
local racialOK, racialError = pcall(function()
    addon.combatTracker.sections.racials:UpdateCooldowns()
end)
assert(racialOK, "racial refresh evaluated secret duration state: " .. tostring(racialError))
assert(racialButton.appliedDurationObject == racialDuration,
    "racials must apply the engine-owned cooldown duration object")

local healthstoneButton = newButton("consumables", 6262, {
    _itemID = 5512,
    _category = "healthstone",
})
local potionButton = newButton("consumables", 1002, {
    _itemID = 241288,
    _category = "combatPotions",
})
addon.combatTracker.sections.consumables.buttons = { healthstoneButton, potionButton }
local consumablesOK, consumablesError = pcall(function()
    addon.combatTracker.sections.consumables:UpdateCooldowns()
end)
assert(consumablesOK,
    "consumable refresh evaluated secret duration state: " .. tostring(consumablesError))
assert(healthstoneButton.appliedDurationObject == healthstoneDuration,
    "Healthstone must apply the engine-owned cooldown duration object")
assert(potionButton.appliedDurationObject == potionDuration,
    "potions must apply the engine-owned cooldown duration object")

local trinketButton = newButton("trinkets", 1003, {
    _slotID = 13,
    _isOnUse = true,
})
local passiveTrinketButton = newButton("trinkets", nil, {
    _slotID = 14,
    _isOnUse = false,
})
addon.combatTracker.sections.trinkets.buttons = { trinketButton, passiveTrinketButton }
local trinketOK, trinketError = pcall(function()
    addon.combatTracker.sections.trinkets:UpdateCooldowns()
end)
assert(trinketOK, "trinket refresh evaluated secret duration state: " .. tostring(trinketError))
assert(not trinketButton.appliedDurationObject,
    "on-use trinkets must not use the item spell's shorter cooldown duration object")
assert(trinketButton.appliedStart == 10 and trinketButton.appliedDuration == 90
    and trinketButton.appliedModRate == 1,
    "on-use trinkets must apply the equipped inventory item's real cooldown")
assert(passiveTrinketButton.cleared and not passiveTrinketButton.appliedDuration,
    "passive trinkets must clear stale cooldown state")

assert(racialButton.clearIfZero and healthstoneButton.clearIfZero
    and potionButton.clearIfZero,
    "duration-object cooldowns must clear themselves when the engine reports zero")
assert(racialButton.desaturated and healthstoneButton.desaturated
    and potionButton.desaturated and trinketButton.desaturated,
    "active duration objects must preserve configured icon desaturation")

local gcdDuration = restrictedDuration()
setCooldownState(2001, gcdDuration, true, true)
local gcdButton = newButton("racials", 2001)
addon.combatTracker.UpdateButtonCooldownFromSpell(gcdButton, 2001)
assert(gcdButton.appliedDurationObject == gcdDuration and not gcdButton.desaturated,
    "global-cooldown state must not desaturate a tracked icon")

local inactiveDuration = restrictedDuration()
setCooldownState(2002, inactiveDuration, false, false)
local inactiveButton = newButton("racials", 2002)
addon.combatTracker.UpdateButtonCooldownFromSpell(inactiveButton, 2002)
assert(inactiveButton.appliedDurationObject == inactiveDuration and not inactiveButton.desaturated,
    "inactive cooldown state must keep the icon saturated")

local missingDurationButton = newButton("racials", 2003)
addon.combatTracker.UpdateButtonCooldownFromSpell(missingDurationButton, 2003)
assert(missingDurationButton.cleared and not missingDurationButton.desaturated,
    "missing duration data must clear stale cooldown and desaturation state")

local disabledDesaturationDuration = restrictedDuration()
setCooldownState(2004, disabledDesaturationDuration, true, false)
addon.db.combatTracker.frames.racials.desaturateOnCD = false
local disabledDesaturationButton = newButton("racials", 2004)
addon.combatTracker.UpdateButtonCooldownFromSpell(disabledDesaturationButton, 2004)
addon.db.combatTracker.frames.racials.desaturateOnCD = true
assert(disabledDesaturationButton.appliedDurationObject == disabledDesaturationDuration
    and not disabledDesaturationButton.desaturated,
    "disabled desaturation must not affect cooldown rendering")

print("CombatTracker restricted cooldown duration smoke test: PASS")
