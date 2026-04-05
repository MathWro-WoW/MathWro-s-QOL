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

    -- Stack count label (bottom-right; used by sections that track item quantities)
    local countText = btn:CreateFontString(nil, "OVERLAY")
    countText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, 2)
    countText:SetJustifyH("RIGHT")
    countText:SetTextColor(1, 1, 1, 1)
    countText:Hide()
    btn.countText = countText

    -- Cooldown countdown label (centered; replaces built-in CooldownFrame numbers)
    local cdCountText = btn:CreateFontString(nil, "OVERLAY")
    cdCountText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    cdCountText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    cdCountText:SetJustifyH("CENTER")
    cdCountText:SetTextColor(1, 1, 1, 1)
    cdCountText:Hide()
    btn.cdCountText = cdCountText

    btn._cdStart     = nil
    btn._cdDuration  = nil
    btn._sectionName = nil  -- set by section when added to pool

    return btn
end

-- ── Shared font applicators ───────────────────────────────────────────────────

-- Applies the section's configured font/size to every button's stack countText.
function CT:ApplySectionFont(sectionName)
    local frameDb  = addon.db.combatTracker.frames[sectionName]
    local font     = frameDb.stackCountFont     or "Fonts\\FRIZQT__.TTF"
    local fontSize = frameDb.stackCountFontSize or 12
    local sec      = sectionMap[sectionName]
    if sec then
        for _, btn in ipairs(sec.buttons) do
            if btn.countText then
                btn.countText:SetFont(font, fontSize, "OUTLINE")
            end
        end
    end
end

-- Applies the section's cooldown text font/size and toggles the built-in
-- WoW countdown numbers (hidden when our custom text is enabled).
function CT:ApplyCooldownFont(sectionName)
    local frameDb  = addon.db.combatTracker.frames[sectionName]
    local enabled  = frameDb.cdCountEnabled ~= false
    local font     = frameDb.cdCountFont     or "Fonts\\FRIZQT__.TTF"
    local fontSize = frameDb.cdCountFontSize or 14
    local sec      = sectionMap[sectionName]
    if sec then
        for _, btn in ipairs(sec.buttons) do
            if btn.cdCountText then
                btn.cdCountText:SetFont(font, fontSize, "OUTLINE")
            end
            -- Hide built-in countdown when our text is active; restore it otherwise
            if btn.cooldown and btn.cooldown.SetHideCountdownNumbers then
                btn.cooldown:SetHideCountdownNumbers(enabled)
            end
        end
    end
end

-- Formats a remaining-seconds value into a compact countdown string.
local function FormatCooldownTime(remaining)
    if remaining >= 3600 then
        return string.format("%dh", math.floor(remaining / 3600))
    elseif remaining >= 60 then
        return string.format("%dm", math.floor(remaining / 60))
    elseif remaining >= 10 then
        return string.format("%d",  math.floor(remaining))
    else
        return string.format("%.1f", remaining)
    end
end

-- Ticked every 0.1 s; updates the custom cooldown countdown text on all buttons.
function CT:UpdateAllCooldownTexts()
    local now = GetTime()
    for _, sec in ipairs(sections) do
        local frameDb = addon.db.combatTracker.frames[sec.name]
        local enabled = frameDb.cdCountEnabled ~= false
        for _, btn in ipairs(sec.buttons) do
            if btn.cdCountText and btn:IsShown() then
                if enabled
                    and btn._cdStart    and btn._cdStart    > 0
                    and btn._cdDuration and btn._cdDuration > 1.5
                then
                    local remaining = btn._cdStart + btn._cdDuration - now
                    if remaining > 0 then
                        btn.cdCountText:SetText(FormatCooldownTime(remaining))
                        btn.cdCountText:Show()
                    else
                        btn.cdCountText:Hide()
                    end
                else
                    btn.cdCountText:Hide()
                end
            end
        end
    end
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

    local w        = frameDb.iconWidth
    local h        = frameDb.iconHeight
    local layout   = frameDb.layout
    local cols     = frameDb.gridCols
    local growDir  = frameDb.growDirection or "growRight"
    local padding  = 2

    -- Snapshot the stable anchor edge BEFORE any resize so it stays fixed
    -- when icons are added or removed.
    local scW, scH = UIParent:GetWidth(), UIParent:GetHeight()
    local stableAnchor, stableX, stableY
    if growDir == "growLeft" then
        stableAnchor = "TOPRIGHT"
        stableX = (frame:GetRight() or (scW/2 + (frameDb.x or 0) + 18)) - scW
        stableY = (frame:GetTop()   or (scH/2 + (frameDb.y or 0) + 18)) - scH
    elseif growDir == "growUp" then
        stableAnchor = "BOTTOMLEFT"
        stableX = frame:GetLeft()   or (scW/2 + (frameDb.x or 0) - 18)
        stableY = frame:GetBottom() or (scH/2 + (frameDb.y or 0) - 18)
    elseif growDir == "centerH" or growDir == "centerV" then
        stableAnchor = "CENTER"
        local cx, cy = frame:GetCenter()
        if cx and cy then
            stableX = cx - scW/2
            stableY = cy - scH/2
        else
            stableX = frameDb.x or 0
            stableY = frameDb.y or 0
        end
    else  -- growRight, growDown (anchor top-left edge)
        stableAnchor = "TOPLEFT"
        stableX = frame:GetLeft() or (scW/2 + (frameDb.x or 0) - 18)
        stableY = (frame:GetTop() or (scH/2 + (frameDb.y or 0) + 18)) - scH
    end

    -- Position icons relative to the appropriate frame corner
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

        if growDir == "growLeft" then
            -- Anchor icons from the right edge; col=0 is rightmost
            btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(col * (w + padding)), -(row * (h + padding)))
        elseif growDir == "growUp" then
            -- Anchor icons from the bottom edge; row=0 is bottommost
            btn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", col * (w + padding), row * (h + padding))
        else
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", col * (w + padding), -(row * (h + padding)))
        end

        if masqueOn and btn._sectionName and masqueGroups[btn._sectionName] then
            masqueGroups[btn._sectionName]:ReSkin(btn)
        end
    end

    -- Compute new frame size
    local newW, newH
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
        newW = totalCols * w + (totalCols - 1) * padding
        newH = totalRows * h + (totalRows - 1) * padding
    else
        newW, newH = 36, 36
    end

    -- Resize and re-anchor at the stable edge so icons don't drift when count changes
    frame:SetSize(newW, newH)
    frame:ClearAllPoints()
    frame:SetPoint(stableAnchor, UIParent, stableAnchor, stableX, stableY)
    frame:SetClampedToScreen(true)
    frameDb.point = stableAnchor
    frameDb.x     = math.floor(stableX + 0.5)
    frameDb.y     = math.floor(stableY + 0.5)
end

-- ── Section anchor frames ─────────────────────────────────────────────────────

-- Creates an invisible anchor frame for a section and registers it with
-- LibEditMode so it gets the native gold-glow highlight and drag in Edit Mode.
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
    frame:SetClampedToScreen(true)

    local LibEditMode = LibStub and LibStub("LibEditMode", true)
    if LibEditMode then
        local displayName = "MathWroQOL - CT " .. key:sub(1,1):upper() .. key:sub(2)
        LibEditMode:AddFrame(frame, function(_, _, point, x, y)
            db.frames[key].point = point
            db.frames[key].x     = math.floor(x + 0.5)
            db.frames[key].y     = math.floor(y + 0.5)
            CT:LayoutSection(CT:GetHostKey(key))
        end, {
            point = frameDb.point or "CENTER",
            x     = frameDb.x or 0,
            y     = frameDb.y or 0,
        }, displayName)

        -- Hook the LibEditMode selection overlay so clicking it also attaches
        -- the EditModeNudge overlay (native WoW frames do this via AttachToSystemFrame).
        if LibEditMode.frameSelections then
            local sel = LibEditMode.frameSelections[frame]
            if sel then
                sel:HookScript("OnMouseDown", function()
                    if addon.editModeNudge and addon.editModeNudge.AttachToFrame then
                        addon.editModeNudge:AttachToFrame(frame)
                    end
                end)
            end
        end
    end

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

    -- Ticker: updates custom cooldown countdown text at 10 Hz
    C_Timer.NewTicker(0.1, function() CT:UpdateAllCooldownTexts() end)

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
