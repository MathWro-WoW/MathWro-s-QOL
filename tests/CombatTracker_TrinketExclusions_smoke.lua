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

local timers = {}
C_Timer = {
    After = function(_, callback)
        table.insert(timers, callback)
    end,
}

local function flushTimers()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do
        callback()
    end
end

local lastEventFrame
function CreateFrame()
    local frame = {
        events = {},
    }

    function frame:RegisterEvent(event)
        self.events[event] = true
    end

    function frame:SetScript(script, handler)
        assert(script == "OnEvent")
        self.handler = handler
    end

    lastEventFrame = frame
    return frame
end

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

flushTimers()
section:Initialize()
assert(lastEventFrame and lastEventFrame.events.PLAYER_EQUIPMENT_CHANGED,
    "trinkets must listen for equipped item changes")

section.buttons = {}
equipped[13] = nil
equipped[14] = nil
addon.db.combatTracker.frames.trinkets.excludedItems = {}

lastEventFrame.handler(lastEventFrame, "PLAYER_EQUIPMENT_CHANGED", 13, true)
equipped[13] = 222222
flushTimers()

assert(#section.buttons == 1 and section.buttons[1]._slotID == 13,
    "equipping an on-use trinket must refresh tracker icons without a reload")

section.buttons = {}
equipped[13] = 333333
equipped[14] = nil
section:RebuildIcons()
flushTimers()
assert(section.buttons[1] and section.buttons[1]:IsShown() and section.buttons[1]._slotID == 13,
    "setup must start with a visible equipped trinket")

equipped[13] = nil
lastEventFrame.handler(lastEventFrame, "PLAYER_ENTERING_WORLD")
equipped[13] = 333333
flushTimers()

assert(section.buttons[1] and section.buttons[1]:IsShown() and section.buttons[1]._slotID == 13,
    "loading screens must not drop equipped trinket icons until reload")

print("CombatTracker trinket exclusion smoke test: PASS")
