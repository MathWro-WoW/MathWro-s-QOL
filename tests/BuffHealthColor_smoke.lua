-- Developer-only smoke test for the 12.1 AuraContainer migration.
-- This file is outside MathWroQOL.toc and is never loaded by the addon.

local containers = {}
local auraContainerLoaded = false

C_AddOns = {
    IsAddOnLoaded = function(name)
        return name == "Blizzard_AuraContainer" and auraContainerLoaded
    end,
    LoadAddOn = function(name)
        assert(name == "Blizzard_AuraContainer")
        auraContainerLoaded = true
    end,
}

local fillTexture = {}
local healthBar = { PostUpdateColor = function() end }
local unitFrame = { unit = "party1", groupName = "party", Health = healthBar }

function unitFrame:GetName()
    return "ElvUF_PartyGroup1UnitButton1"
end

function healthBar:GetParent()
    return unitFrame
end

function healthBar:GetFrameLevel()
    return 3
end

function healthBar:GetStatusBarTexture()
    return fillTexture
end

function healthBar:ForceUpdate()
    self:PostUpdateColor("party1")
end

local function newTexture()
    local texture = {}

    function texture:SetAllPoints(target)
        self.target = target
    end

    function texture:SetColorTexture(r, g, b, a)
        self.color = { r, g, b, a }
    end

    return texture
end

local function newAuraButton()
    local button = {}

    function button:SetSize(width, height)
        self.size = { width, height }
    end

    function button:SetPoint(...)
        self.point = { ... }
    end

    function button:SetFrameLevel(level)
        self.level = level
    end

    function button:SetMouseMotionEnabled(enabled)
        self.mouseMotion = enabled
    end

    function button:CreateTexture(_, layer, _, subLevel)
        self.texture = newTexture()
        self.texture.layer = layer
        self.texture.subLevel = subLevel
        return self.texture
    end

    return button
end

local function newAuraContainer(parent)
    local container = {
        parent = parent,
        enabled = true,
        slots = {},
        candidates = {},
        updates = 0,
    }

    function container:SetSize(width, height)
        self.size = { width, height }
    end

    function container:SetPoint(...)
        self.point = { ... }
    end

    function container:AddAuraSlot(key, filter, options)
        local button = newAuraButton()
        self.slots[#self.slots + 1] = { key = key, filter = filter, button = button }
        self.candidates[key] = options.candidateFilters
        options.initializeFrame(button)
        return button
    end

    function container:SetAuraSlotCandidateFilters(key, candidates)
        self.candidates[key] = candidates
    end

    function container:SetUnit(unit)
        self.unit = unit
    end

    function container:SetEnabled(enabled)
        self.enabled = enabled
    end

    function container:UpdateAllAuras()
        self.updates = self.updates + 1
    end

    containers[#containers + 1] = container
    return container
end

function CreateFrame(kind, _, parent, template)
    if kind == "AuraContainer" then
        assert(template == "CustomAuraContainerTemplate")
        return newAuraContainer(parent)
    end

    local frame = {}

    function frame:SetScript(script, callback)
        self[script] = callback
    end

    function frame:RegisterEvent(event)
        self.event = event
    end

    function frame:UnregisterEvent(event)
        if self.event == event then
            self.event = nil
        end
    end

    return frame
end

function EnumerateFrames(previous)
    if previous == nil then
        return unitFrame
    end
    return nil
end

function UnitExists(unit)
    return unit == "party1"
end

function GetSpecialization()
    return 1
end

function GetSpecializationInfo()
    return 256
end

function hooksecurefunc() end

function strtrim(value)
    return value:match("^%s*(.-)%s*$")
end

local unitFrames = { GetModule = function(_, name)
    assert(name == "UnitFrames")
    return { Configure_HealthBar = function() end }
end }
ElvUI = { [1] = unitFrames }

local addon = {
    db = { buffHealthColor = { enabled = true, buffs = {}, customOrder = {} } },
}

function addon:RegisterFeature(feature)
    self.feature = feature
end

assert(loadfile("Features/BuffHealthColor.lua"))("MathWroQOL", addon)
assert(addon.feature, "BuffHealthColor did not register")
addon.feature:Initialize()

assert(#containers == 1, "expected one AuraContainer")
local container = containers[1]
assert(container.unit == "party1", "unit assignment missing")
assert(container.enabled == true, "container should be enabled")
assert(#container.slots == 1, "default Atonement profile should create one slot")
assert(container.slots[1].filter == "HELPFUL|PLAYER", "player-cast filter missing")
assert(container.candidates.buff1.includeSpellIDs[194384] == true, "spell-ID filter missing")

local texture = container.slots[1].button.texture
assert(texture.target == fillTexture, "tint must follow the health-bar fill texture")
assert(texture.color[1] == 0.95 and texture.color[2] == 0.72 and texture.color[3] == 0.22, "default color mismatch")

addon.db.buffHealthColor.buffs.atonement.color = { r = 0.1, g = 0.2, b = 0.3 }
addon.feature:Apply()
assert(#containers == 1, "settings update should reuse the container")
assert(texture.color[1] == 0.1 and texture.color[2] == 0.2 and texture.color[3] == 0.3, "color update missing")

addon.db.buffHealthColor.buffs.custom = {
    enabled = true,
    label = "Custom",
    spellID = 12345,
    color = { r = 0.4, g = 0.5, b = 0.6 },
    frames = { party = true },
    allSpecs = true,
    specs = {},
}
addon.db.buffHealthColor.customOrder = { "custom" }
addon.feature:Apply()
assert(#container.slots == 2, "added profile should create a second AuraSlot")
assert(container.candidates.buff2.includeSpellIDs[12345] == true, "custom spell-ID filter missing")

addon.db.buffHealthColor.buffs.custom.enabled = false
addon.feature:Apply()
assert(next(container.candidates.buff2.includeSpellIDs) == nil, "retired AuraSlot must clear its spell filter")
assert(container.slots[2].button.texture.color[4] == 0, "retired AuraSlot tint must be transparent")

addon.db.buffHealthColor.enabled = false
addon.feature:Apply()
assert(container.enabled == false, "disabled feature must disable its container")

addon.db.buffHealthColor.enabled = true
addon.feature:Apply()
assert(#containers == 1 and container.enabled == true, "re-enable should reuse the container")

print("BuffHealthColor AuraContainer smoke test: PASS")
