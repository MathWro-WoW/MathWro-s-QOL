local _, addon = ...

-- Section registry — populated by CombatTracker_*.lua files at load time
local sections    = {}   -- ordered list: { racials, trinkets, consumables }
local sectionMap  = {}   -- keyed by name

local CT = {
    name     = "combatTracker",
    sections = sectionMap,
    frames   = {},   -- { [name] = Frame }
}
-- Expose as addon.combatTracker so section files can reference it at load time
addon.combatTracker = CT

-- ── Section registry ──────────────────────────────────────────────────────────

function CT:RegisterSection(def)
    table.insert(sections, def)
    sectionMap[def.name] = def
end

-- ── Shared button factory ─────────────────────────────────────────────────────

-- Creates a single icon button parented to UIParent.
-- Sections call this to grow their pool as needed.
function CT.CreateButton()
    local btn = CreateFrame("Button", nil, UIParent)
    btn:SetSize(36, 36)
    btn:SetFrameLevel(5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- trim default icon borders
    btn.icon = icon

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints(btn)
    cd:SetDrawBling(false)
    cd:SetDrawEdge(true)
    btn.cooldown = cd

    btn._cdStart     = nil
    btn._cdDuration  = nil
    btn._sectionName = nil  -- set by section when added to pool

    return btn
end

-- ── Shared cooldown updater ───────────────────────────────────────────────────

-- Guards against redundant SetCooldown calls (which reset the swipe animation).
-- Sections call this; never call CooldownFrame_Set directly in section code.
function CT.UpdateButtonCooldown(button, start, duration)
    start    = start    or 0
    duration = duration or 0
    if button._cdStart == start and button._cdDuration == duration then return end
    button._cdStart    = start
    button._cdDuration = duration
    if start > 0 and duration > 1.5 then
        CooldownFrame_Set(button.cooldown, start, duration, true)
        button.icon:SetDesaturated(true)
    else
        button.cooldown:Clear()
        button.icon:SetDesaturated(false)
    end
end

-- ── Merge helper ──────────────────────────────────────────────────────────────

-- Returns the key of the frame that should host this section's icons.
-- If the section merges into another valid section, returns that section's key.
-- Otherwise returns the section's own key.
function CT:GetHostKey(key)
    local db     = addon.db.combatTracker
    local target = db.frames[key].mergeInto
    if target and target ~= key and self.frames[target] then
        return target
    end
    return key
end

-- ── Layout engine ─────────────────────────────────────────────────────────────

-- Positions all icons that belong to the host frame `key`.
-- Includes icons from sections that have mergeInto == key.
-- Called by section:RebuildIcons() and CT:Apply().
function CT:LayoutSection(key)
    local db      = addon.db.combatTracker
    local frameDb = db.frames[key]
    local frame   = self.frames[key]
    if not frame then return end

    local MSQ      = LibStub and LibStub("Masque", true)
    local masqueOn = MSQ and db.masque.enabled and masqueGroups ~= nil

    -- Collect icons: host section first, then merged-in sections in registration order
    local icons = {}
    local hostSec = sectionMap[key]
    if hostSec then
        for _, btn in ipairs(hostSec:GetIcons()) do
            table.insert(icons, btn)
        end
    end
    for _, sec in ipairs(sections) do
        if sec.name ~= key and db.frames[sec.name].mergeInto == key then
            for _, btn in ipairs(sec:GetIcons()) do
                table.insert(icons, btn)
            end
        end
    end

    -- Position icons
    local w       = frameDb.iconWidth
    local h       = frameDb.iconHeight
    local layout  = frameDb.layout
    local cols    = frameDb.gridCols
    local padding = 2

    for i, btn in ipairs(icons) do
        btn:SetSize(w, h)
        btn:ClearAllPoints()
        local col, row
        if layout == "horizontal" then
            col, row = i - 1, 0
        elseif layout == "vertical" then
            col, row = 0, i - 1
        else  -- "grid"
            col = (i - 1) % cols
            row = math.floor((i - 1) / cols)
        end
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", col * (w + padding), -(row * (h + padding)))

        -- Let Masque recalculate skin offsets at the new size
        if masqueOn and btn._sectionName and masqueGroups[btn._sectionName] then
            masqueGroups[btn._sectionName]:ReSkin(btn)
        end
    end

    -- Resize anchor frame to fit its icons
    if #icons > 0 then
        local totalCols, totalRows
        if layout == "horizontal" then
            totalCols, totalRows = #icons, 1
        elseif layout == "vertical" then
            totalCols, totalRows = 1, #icons
        else
            totalCols = math.min(#icons, cols)
            totalRows = math.ceil(#icons / cols)
        end
        frame:SetSize(
            totalCols * w + (totalCols - 1) * padding,
            totalRows * h + (totalRows - 1) * padding
        )
    else
        frame:SetSize(36, 36)  -- keep draggable when empty
    end
end

-- ── Draggable section frames ──────────────────────────────────────────────────

-- Creates a draggable, invisible anchor frame for a section.
-- Saves position to DB on drag stop.
function CT:CreateSectionFrame(key)
    local db      = addon.db.combatTracker
    local frameDb = db.frames[key]

    local frame = CreateFrame("Frame", "MathWroQOL_CT_" .. key, UIParent)
    frame:SetSize(36, 36)
    frame:SetPoint(
        frameDb.point or "CENTER",
        UIParent,
        frameDb.point or "CENTER",
        frameDb.x or 0,
        frameDb.y or 0
    )
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.frames[key].point = point
        db.frames[key].x     = math.floor(x + 0.5)
        db.frames[key].y     = math.floor(y + 0.5)
    end)

    return frame
end

-- ── Feature contract ──────────────────────────────────────────────────────────

function CT:Initialize()
    local db = addon.db.combatTracker

    -- Create one anchor frame per section
    for _, sec in ipairs(sections) do
        self.frames[sec.name] = self:CreateSectionFrame(sec.name)
    end

    -- Let each section set up its event frame and do initial icon scan
    for _, sec in ipairs(sections) do
        if sec.Initialize then sec:Initialize() end
        sec:RebuildIcons()
    end

    self:Apply()
end

function CT:Apply()
    local db = addon.db.combatTracker

    -- Show or hide each section's anchor frame
    for _, sec in ipairs(sections) do
        local frameDb = db.frames[sec.name]
        local frame   = self.frames[sec.name]
        if frame then
            local isMerged = frameDb.mergeInto
                and frameDb.mergeInto ~= sec.name
                and self.frames[frameDb.mergeInto] ~= nil

            if not db.enabled or not frameDb.enabled or isMerged then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end

    -- Full data scan for all sections (handles enabled/disabled toggles, filter changes)
    for _, sec in ipairs(sections) do
        sec:RebuildIcons()
    end

    self:ApplyMasque()
end

-- ── Masque skinning ───────────────────────────────────────────────────────────

local masqueGroups = nil  -- nil until first enable; reset to nil on disable

local function CreateMasqueGroups()
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return nil end

    local groups = {
        racials     = MSQ:Group("MathWroQOL", "CT Racials",     "MathWroQOL_CT_Racials"),
        trinkets    = MSQ:Group("MathWroQOL", "CT Trinkets",    "MathWroQOL_CT_Trinkets"),
        consumables = MSQ:Group("MathWroQOL", "CT Consumables", "MathWroQOL_CT_Consumables"),
    }

    -- Re-apply layout when the user changes skin in the Masque UI.
    -- Masque modifies button regions *after* the callback fires, so defer with C_Timer.
    for _, group in pairs(groups) do
        group:RegisterCallback(function()
            C_Timer.After(0, function()
                addon:NotifyFeature("combatTracker")
            end)
        end)
    end

    return groups
end

local function RegisterButtonWithMasque(group, button)
    -- Hide the default normal texture so Masque's skin is the only visual layer
    button:SetNormalTexture("")
    -- Register with Legacy type and strictMode=true: only skin Icon and Cooldown
    group:AddButton(button, {
        Icon     = button.icon,
        Cooldown = button.cooldown,
    }, "Legacy", true)
end

local function UnregisterButtonFromMasque(group, button)
    group:RemoveButton(button)
    -- Restore default appearance after Masque removes the skin
    button.icon:SetAllPoints(button)
    button.icon:SetDesaturated(button._cdDuration and button._cdDuration > 1.5 or false)
end

function CT:ApplyMasque()
    local db  = addon.db.combatTracker
    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return end

    if db.masque.enabled then
        -- Lazy-create groups on first enable
        if not masqueGroups then
            masqueGroups = CreateMasqueGroups()
        end
        if not masqueGroups then return end

        -- Register all current buttons with their section's group
        for _, sec in ipairs(sections) do
            local group = masqueGroups[sec.name]
            if group then
                for _, btn in ipairs(sec.buttons) do
                    RegisterButtonWithMasque(group, btn)
                    btn:SetSize(
                        db.frames[sec.name].iconWidth,
                        db.frames[sec.name].iconHeight
                    )
                    group:ReSkin(btn)
                end
            end
        end
    else
        -- Disable: deregister all buttons and clear groups
        if masqueGroups then
            for _, sec in ipairs(sections) do
                local group = masqueGroups[sec.name]
                if group then
                    for _, btn in ipairs(sec.buttons) do
                        UnregisterButtonFromMasque(group, btn)
                    end
                end
            end
            masqueGroups = nil
        end

        -- Restore icon fill (Masque may have changed icon anchors)
        for _, sec in ipairs(sections) do
            for _, btn in ipairs(sec.buttons) do
                btn.icon:ClearAllPoints()
                btn.icon:SetAllPoints(btn)
            end
        end
    end
end

-- Exposed for section files to register newly-created buttons at RebuildIcons time
CT._masqueGroups         = function() return masqueGroups end
CT._registerButtonMasque = RegisterButtonWithMasque

addon:RegisterFeature(CT)
