-- Developer-only smoke test for user-configured excluded on-use trinkets.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local section
local equipped = {
    [13] = 248583,
    [14] = 111111,
}

function GetInventoryItemID(unit, slotID)
    assert(unit == "player")
    return equipped[slotID]
end

function GetInventoryItemTexture(unit, slotID)
    assert(unit == "player")
    return 100000 + slotID
end
function GetInventoryItemCooldown(unit, slotID)
    assert(unit == "player")
    return slotID, 90, 1, 1
end


C_Item = {
    GetItemSpell = function(itemID)
        return "Use", itemID + 1
    end,
    IsItemDataCachedByID = function()
        return true
    end,
}

C_Timer = {
    After = function(_, callback)
        callback()
    end,
}

local CT = {
    frames = {},
}

function CT:RegisterSection(def)
    section = def
end

function CT:GetHostKey(key)
    return key
end

function CT:CreateButton()
    local button = {
        icon = {
            SetTexture = function() end,
            SetDesaturated = function() end,
        },
        cooldown = {
            SetCooldown = function() end,
        },
    }

    function button:SetSize() end
    function button:Show() self.shown = true end
    function button:Hide() self.shown = false end
    function button:IsShown() return self.shown == true end

    return button
end

function CT:ApplySectionFont() end
function CT:ApplyCooldownFont() end
function CT:LayoutSection() end
function CT.UpdateButtonCooldownFromSpell() end
function CT._masqueGroups() return nil end

local addon = {
    combatTracker = CT,
    db = {
        combatTracker = {
            enabled = true,
            masque = { enabled = false },
            frames = {
                trinkets = {
                    enabled = true,
                    onUseOnly = true,
                    iconWidth = 36,
                    iconHeight = 36,
                    excludedItems = { [248583] = true },
                },
            },
        },
    },
}

assert(loadfile("Features/CombatTracker_Trinkets.lua"))("MathWroQOL", addon)
assert(section, "trinkets section did not register")
section:RebuildIcons()

assert(#section.buttons == 1,
    "a user-excluded trinket must not consume a tracker icon")
assert(section.buttons[1]._slotID == 14,
    "the non-excluded trinket must remain visible")

addon.db.combatTracker.frames.trinkets.excludedItems[248583] = nil
section:RebuildIcons()
assert(#section.buttons == 2,
    "removing a user-configured exclusion must restore the trinket icon")

print("CombatTracker trinket exclusion smoke test: PASS")
