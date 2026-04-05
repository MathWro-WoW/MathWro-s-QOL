local _, addon = ...

local function ElvSkin()
    if not ElvUI then return nil end
    return ElvUI[1]:GetModule("Skins")
end

-- ── Widget helpers ────────────────────────────────────────────────────────────

local function MakeSeparator(parent, anchor, offsetY)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    line:SetHeight(1)
    line:SetWidth(550)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    return line
end

local function MakeCheckbox(parent, label, x, y, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(getValue())
    cb:SetScript("OnClick", function(self)
        setValue(self:GetChecked() == true)
    end)
    local S = ElvSkin()
    if S then S:HandleCheckBox(cb) end
    return cb
end

-- ── Slider + editable number input ────────────────────────────────────────────
-- Returns a container frame with .Refresh() to sync from DB.
-- minVal/maxVal are integers. setVal(n) is called on every change.
local _sliderCount = 0
local function MakeSliderWithInput(parent, label, minVal, maxVal, getVal, setVal)
    _sliderCount = _sliderCount + 1
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(300, 50)

    local lbl = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)

    local sliderName = "MathWroQOL_CTSlider" .. _sliderCount
    local slider = CreateFrame("Slider", sliderName, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 5, -8)
    slider:SetWidth(180)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    local S = ElvSkin()
    if S then S:HandleSliderFrame(slider) end
    _G[sliderName .. "Low"]:SetText(tostring(minVal))
    _G[sliderName .. "High"]:SetText(tostring(maxVal))
    _G[sliderName .. "Text"]:SetText("")

    -- Display: clickable FontString (always renders). Click → shows EditBox.
    local displayBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    displayBtn:SetSize(40, 20)
    displayBtn:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    displayBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 },
    })
    displayBtn:SetBackdropColor(0, 0, 0, 0.5)
    displayBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    if ElvUI then
        local E = ElvUI[1]
        displayBtn:SetBackdropColor(unpack(E.media.backdropcolor))
        displayBtn:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local valueLabel = displayBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueLabel:SetAllPoints()
    valueLabel:SetJustifyH("CENTER")

    -- Edit: EditBox shown only while user types; hidden otherwise.
    -- Focused EditBoxes always paint their text, avoiding the repaint bug.
    local input = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    input:SetFontObject(GameFontHighlightSmall)
    input:SetJustifyH("CENTER")
    input:SetSize(40, 20)
    input:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(3)
    input:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left=1, right=1, top=1, bottom=1 },
    })
    input:SetBackdropColor(0, 0, 0, 0.5)
    input:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    input:Hide()

    local syncing = false

    local function showInput()
        input:SetText(tostring(getVal()))
        displayBtn:Hide()
        input:Show()
        input:SetFocus()
        input:HighlightText()
    end

    local function commitInput()
        local val = tonumber(input:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, math.floor(val + 0.5)))
            syncing = true
            slider:SetValue(val)
            syncing = false
            setVal(val)
        end
        valueLabel:SetText(tostring(getVal()))
        input:Hide()
        displayBtn:Show()
    end

    displayBtn:SetScript("OnClick", showInput)
    input:SetScript("OnEnterPressed", function(self) commitInput(); self:ClearFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEditFocusLost", commitInput)

    slider:SetScript("OnValueChanged", function(self, value)
        if syncing then return end
        value = math.floor(value + 0.5)
        valueLabel:SetText(tostring(value))
        setVal(value)
    end)

    function container:Refresh()
        local v = getVal()
        syncing = true
        slider:SetValue(v)
        syncing = false
        valueLabel:SetText(tostring(v))
    end

    container:Refresh()
    return container
end

-- ── Dropdown ──────────────────────────────────────────────────────────────────
-- options: array of { label=string, value=any }
-- getValue() returns current value; setValue(v) stores it.
-- Returns a frame with .Refresh() to re-sync display from DB.
local _openDropdownPopups = {}
local _dropdownCount = 0
local function MakeDropdown(parent, options, getValue, setValue)
    _dropdownCount = _dropdownCount + 1

    -- Button showing the currently selected option
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(130, 22)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    if ElvUI then
        local E = ElvUI[1]
        btn:SetBackdropColor(unpack(E.media.backdropcolor))
        btn:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -18, 0)
    btnText:SetJustifyH("LEFT")

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown")

    -- Popup list (parented to UIParent so it floats above everything)
    local popup = CreateFrame("Frame", "MathWroQOL_DropPopup" .. _dropdownCount, UIParent, "BackdropTemplate")
    table.insert(_openDropdownPopups, popup)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetWidth(130)
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.97)
    popup:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    if ElvUI then
        local E = ElvUI[1]
        popup:SetBackdropColor(unpack(E.media.backdropcolor))
        popup:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end
    popup:Hide()

    local ROW_H = 20
    popup:SetHeight(#options * ROW_H + 4)

    local rows = {}
    for i, opt in ipairs(options) do
        local row = CreateFrame("Button", nil, popup)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  popup, "TOPLEFT",  2, -(i - 1) * ROW_H - 2)
        row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -(i - 1) * ROW_H - 2)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 0.82, 0, 0.15)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 6, 0)
        label:SetJustifyH("LEFT")
        label:SetText(opt.label)
        row.label = label

        row:SetScript("OnClick", function()
            setValue(opt.value)
            btnText:SetText(opt.label)
            addon:NotifyFeature("combatTracker")
            popup:Hide()
        end)

        rows[i] = { frame = row, opt = opt }
    end

    -- Highlight the active row in gold when popup opens
    local function updateRowColors()
        local cur = getValue()
        for _, r in ipairs(rows) do
            if r.opt.value == cur then
                r.frame.label:SetTextColor(1, 0.82, 0, 1)
            else
                r.frame.label:SetTextColor(1, 1, 1, 1)
            end
        end
    end

    -- Click-outside-to-close: a full-screen transparent catcher frame
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(2)
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function()
        popup:Hide()
    end)
    popup:HookScript("OnShow", function(self)
        for _, p in ipairs(_openDropdownPopups) do
            if p ~= self and p:IsShown() then p:Hide() end
        end
    end)
    popup:HookScript("OnShow", function() catcher:Show() end)
    popup:HookScript("OnHide", function() catcher:Hide() end)

    btn:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
        else
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            updateRowColors()
            popup:Show()
        end
    end)

    btn:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)

    local function refresh()
        local cur = getValue()
        for _, r in ipairs(rows) do
            if r.opt.value == cur then
                btnText:SetText(r.opt.label)
                return
            end
        end
        if options[1] then btnText:SetText(options[1].label) end
    end

    refresh()
    btn.Refresh = refresh
    return btn
end

-- ── Parent panel (title only) ─────────────────────────────────────────────────

local function BuildParentPanel()
    local panel = CreateFrame("Frame")
    panel.name = "MathWro QOL"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MathWro QOL")

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ver:SetText("v1.0.0 by MathWro  |  Select a category on the left.")

    return panel
end

-- ── General subpage ───────────────────────────────────────────────────────────

local function BuildGeneralPanel()
    local panel = CreateFrame("Frame")
    panel.name = "General"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("General")

    -- Dark backdrop below the title
    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_GeneralScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 900)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Game Menu Scale ───────────────────────────────────────────────────────

    local gmLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    gmLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
    gmLabel:SetText("Game Menu Scale")

    local gmDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    gmDesc:SetPoint("TOPLEFT", gmLabel, "BOTTOMLEFT", 0, -4)
    gmDesc:SetText("Scale the Escape menu. Default is 1.0.")

    local slider = CreateFrame("Slider", "MathWroQOL_GameMenuSlider", scrollChild, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", gmDesc, "BOTTOMLEFT", 0, -16)
    slider:SetMinMaxValues(0.5, 2.0)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    _G[slider:GetName().."Low"]:SetText("0.5x")
    _G[slider:GetName().."High"]:SetText("2.0x")
    _G[slider:GetName().."Text"]:SetText("Scale: 1.0x")

    slider:SetScript("OnValueChanged", function(self, value, userInput)
        _G[self:GetName().."Text"]:SetText(string.format("Scale: %.2fx", value))
        if not userInput then return end
        if not addon.db.gameMenu then addon.db.gameMenu = {} end
        addon.db.gameMenu.scale = value
        addon:NotifyFeature("gameMenu")
    end)

    panel:HookScript("OnShow", function()
        local scale = (addon.db.gameMenu and addon.db.gameMenu.scale) or 1.0
        slider:SetValue(scale)
    end)

    -- ── Game Menu Dragging ────────────────────────────────────────────────────

    local moveableCB = MakeCheckbox(scrollChild, "Allow dragging", 0, 0,
        function() return addon.db.gameMenu and addon.db.gameMenu.moveable == true end,
        function(val)
            if not addon.db.gameMenu then addon.db.gameMenu = {} end
            addon.db.gameMenu.moveable = val
            addon:NotifyFeature("gameMenu")
        end
    )
    moveableCB:ClearAllPoints()
    moveableCB:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -16)

    local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", moveableCB, "BOTTOMLEFT", 0, -8)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        for _, f in ipairs(addon.features) do
            if f.name == "gameMenu" and f.ResetPosition then
                f:ResetPosition()
                break
            end
        end
    end)

    -- ── CDM Button ────────────────────────────────────────────────────────────

    local cdmSep = MakeSeparator(scrollChild, resetBtn, -12)

    local cdmLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cdmLabel:SetPoint("TOPLEFT", cdmSep, "BOTTOMLEFT", 0, -10)
    cdmLabel:SetText("CDM Button")

    local cdmDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cdmDesc:SetPoint("TOPLEFT", cdmLabel, "BOTTOMLEFT", 0, -4)
    cdmDesc:SetText("Adds a CDM button to the Game Menu that opens the Cooldown Manager.")

    local cdmEnabledCB = MakeCheckbox(scrollChild, "Show CDM button in game menu", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.enabled end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.enabled = val
            addon:NotifyFeature("cdmButton")
        end
    )
    cdmEnabledCB:ClearAllPoints()
    cdmEnabledCB:SetPoint("TOPLEFT", cdmDesc, "BOTTOMLEFT", 0, -8)

    local slashNote = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashNote:SetPoint("TOPLEFT", cdmEnabledCB, "BOTTOMLEFT", 0, -8)
    slashNote:SetText("Slash commands:")

    local waCB = MakeCheckbox(scrollChild, "Enable /wa command", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashWA end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashWA = val
        end
    )
    waCB:ClearAllPoints()
    waCB:SetPoint("TOPLEFT", slashNote, "BOTTOMLEFT", 0, -8)

    local cmCB = MakeCheckbox(scrollChild, "Enable /cm command", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashCM end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashCM = val
        end
    )
    cmCB:ClearAllPoints()
    cmCB:SetPoint("TOPLEFT", waCB, "BOTTOMLEFT", 0, -4)

    -- ── Auction House Filters ─────────────────────────────────────────────────

    local ahSep = MakeSeparator(scrollChild, cmCB, -12)

    local ahLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ahLabel:SetPoint("TOPLEFT", ahSep, "BOTTOMLEFT", 0, -10)
    ahLabel:SetText("Auction House Filters")

    local ahDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ahDesc:SetPoint("TOPLEFT", ahLabel, "BOTTOMLEFT", 0, -4)
    ahDesc:SetText("Automatically enable selected filters each time you open the Auction House.")

    local ahExpCB = MakeCheckbox(scrollChild, "Auto-enable 'Current expansion only' filter", 0, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.currentExpansionOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.currentExpansionOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahExpCB:ClearAllPoints()
    ahExpCB:SetPoint("TOPLEFT", ahDesc, "BOTTOMLEFT", 0, -8)

    local ahUsableCB = MakeCheckbox(scrollChild, "Auto-enable 'Usable only' filter", 0, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.usableOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.usableOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahUsableCB:ClearAllPoints()
    ahUsableCB:SetPoint("TOPLEFT", ahExpCB, "BOTTOMLEFT", 0, -4)

    -- ── Combat Logging ────────────────────────────────────────────────────────

    local clSep = MakeSeparator(scrollChild, ahUsableCB, -12)

    local clLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    clLabel:SetPoint("TOPLEFT", clSep, "BOTTOMLEFT", 0, -10)
    clLabel:SetText("Combat Logging")

    local clDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    clDesc:SetPoint("TOPLEFT", clLabel, "BOTTOMLEFT", 0, -4)
    clDesc:SetWidth(500)
    clDesc:SetJustifyH("LEFT")
    clDesc:SetText("Automatically start combat logging when entering selected instance types. Stops on exit. If you manually stop logging mid-instance, it stays off until the next instance.")

    -- No NotifyFeature call needed: CombatLog:Apply() is a no-op; settings
    -- take effect on the next zone transition (PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA).

    -- Row 1: Dungeon | Raid
    local clDungeonCB = MakeCheckbox(scrollChild, "Dungeon (includes Mythic+)", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.dungeon end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.dungeon = val
        end
    )
    clDungeonCB:ClearAllPoints()
    clDungeonCB:SetPoint("TOPLEFT", clDesc, "BOTTOMLEFT", 0, -8)

    local clRaidCB = MakeCheckbox(scrollChild, "Raid", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.raid end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.raid = val
        end
    )
    clRaidCB:ClearAllPoints()
    clRaidCB:SetPoint("TOPLEFT", clDungeonCB, "TOPLEFT", 200, 0)

    -- Row 2: Scenario | Battleground
    local clScenarioCB = MakeCheckbox(scrollChild, "Scenario", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.scenario end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.scenario = val
        end
    )
    clScenarioCB:ClearAllPoints()
    clScenarioCB:SetPoint("TOPLEFT", clDungeonCB, "BOTTOMLEFT", 0, -4)

    local clPvpCB = MakeCheckbox(scrollChild, "Battleground", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.pvp end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.pvp = val  -- IsInInstance() returns "pvp" for battlegrounds
        end
    )
    clPvpCB:ClearAllPoints()
    clPvpCB:SetPoint("TOPLEFT", clScenarioCB, "TOPLEFT", 200, 0)

    -- Row 3: Arena
    local clArenaCB = MakeCheckbox(scrollChild, "Arena", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.arena end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.arena = val
        end
    )
    clArenaCB:ClearAllPoints()
    clArenaCB:SetPoint("TOPLEFT", clScenarioCB, "BOTTOMLEFT", 0, -4)

    local clMaxLevelCB = MakeCheckbox(scrollChild, "Only at max level", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.maxLevelOnly end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.maxLevelOnly = val
        end
    )
    clMaxLevelCB:ClearAllPoints()
    clMaxLevelCB:SetPoint("TOPLEFT", clArenaCB, "BOTTOMLEFT", 0, -8)

    return panel
end

-- ── ElvUI Plugins subpage ─────────────────────────────────────────────────────

local function BuildElvUIPanel()
    local panel = CreateFrame("Frame")
    panel.name = "ElvUI Plugins"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ElvUI Plugins")

    local elvuiLoaded = ElvUI ~= nil

    -- Dark backdrop below the title
    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_ElvUIScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 900)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Vehicle Bar Visibility ────────────────────────────────────────────────

    -- The "not loaded" notice anchors to scrollChild top; sectionLabel follows it.
    -- When ElvUI is loaded, sectionLabel anchors directly to scrollChild top.
    local sectionLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionLabel:SetText("Vehicle Bar Visibility")

    if not elvuiLoaded then
        local notice = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notice:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
        notice:SetTextColor(1, 0.3, 0.3)
        notice:SetText("ElvUI is not loaded. These options are unavailable.")
        sectionLabel:SetPoint("TOPLEFT", notice, "BOTTOMLEFT", 0, -16)
    else
        sectionLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
    end

    local sectionDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sectionDesc:SetPoint("TOPLEFT", sectionLabel, "BOTTOMLEFT", 0, -4)
    sectionDesc:SetWidth(500)
    sectionDesc:SetJustifyH("LEFT")
    sectionDesc:SetText("Keep selected action bars visible while in vehicle combat, including override bar states. Prevents mouseover fade from hiding bars during these encounters.")

    local widgets = {}

    local enabledCB = MakeCheckbox(scrollChild, "Enable", 0, 0,
        function() return addon.db.vehicleBar and addon.db.vehicleBar.enabled end,
        function(val)
            if addon.db.vehicleBar then
                addon.db.vehicleBar.enabled = val
                addon:NotifyFeature("vehicleBar")
            end
        end
    )
    enabledCB:ClearAllPoints()
    enabledCB:SetPoint("TOPLEFT", sectionDesc, "BOTTOMLEFT", 0, -12)
    widgets[#widgets + 1] = enabledCB

    local barsLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    barsLabel:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -8)
    barsLabel:SetText("Bars to keep visible:")

    local barRefs = {}
    for i = 1, 10 do
        local col = (i - 1) % 5
        local cb = MakeCheckbox(scrollChild, "Bar "..i, 0, 0,
            function()
                return addon.db.vehicleBar and addon.db.vehicleBar.bars[i] == true
            end,
            function(val)
                if addon.db.vehicleBar then
                    addon.db.vehicleBar.bars[i] = val and true or nil
                    addon:NotifyFeature("vehicleBar")
                end
            end
        )
        cb:ClearAllPoints()
        if i == 1 then
            cb:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", 0, -8)
        elseif i == 6 then
            cb:SetPoint("TOPLEFT", barRefs[1], "BOTTOMLEFT", 0, -4)
        elseif col == 0 then
            cb:SetPoint("TOPLEFT", barRefs[i - 5], "BOTTOMLEFT", 0, -4)
        else
            cb:SetPoint("TOPLEFT", barRefs[i - 1], "TOPLEFT", 90, 0)
        end
        barRefs[i] = cb
        widgets[#widgets + 1] = cb
    end

    if not elvuiLoaded then
        for _, w in ipairs(widgets) do
            w:Disable()
        end
        sectionLabel:SetTextColor(0.5, 0.5, 0.5)
        sectionDesc:SetTextColor(0.5, 0.5, 0.5)
        barsLabel:SetTextColor(0.5, 0.5, 0.5)
    end

    return panel
end

-- ── Edit Mode subpage ─────────────────────────────────────────────────────────

local function BuildEditModePanel()
    local panel = CreateFrame("Frame")
    panel.name = "Edit Mode"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Edit Mode")

    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_EditModeScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 900)
    scrollFrame:SetScrollChild(scrollChild)

    -- ── Nudge Overlay ─────────────────────────────────────────────────────────

    local nudgeLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nudgeLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -12)
    nudgeLabel:SetText("Nudge Overlay")

    local nudgeDesc = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nudgeDesc:SetPoint("TOPLEFT", nudgeLabel, "BOTTOMLEFT", 0, -4)
    nudgeDesc:SetWidth(500)
    nudgeDesc:SetJustifyH("LEFT")
    nudgeDesc:SetText("Shows arrow buttons and exact coordinates when selecting a UI element in Edit Mode. Click arrows to nudge 1 px, Shift-click for 10 px.")

    local nudgeCB = MakeCheckbox(scrollChild, "Enable nudge overlay", 0, 0,
        function() return addon.db.editModeNudge and addon.db.editModeNudge.enabled end,
        function(val)
            if not addon.db.editModeNudge then addon.db.editModeNudge = {} end
            addon.db.editModeNudge.enabled = val
            addon:NotifyFeature("editModeNudge")
        end
    )
    nudgeCB:ClearAllPoints()
    nudgeCB:SetPoint("TOPLEFT", nudgeDesc, "BOTTOMLEFT", 0, -8)

    return panel
end

-- ── Combat Tracker subpage ────────────────────────────────────────────────────

local function BuildCombatTrackerPanel()
    local panel = CreateFrame("Frame")
    panel.name  = "Combat Tracker"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Combat Tracker")
    title:SetTextColor(1, 0.82, 0, 1)

    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT",     title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    bg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    bg:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    if ElvUI then
        local E = ElvUI[1]
        bg:SetBackdropColor(unpack(E.media.backdropfadecolor))
        bg:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end

    local scrollFrame = CreateFrame("ScrollFrame", "MathWroQOL_CTScroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     bg, "TOPLEFT",     8,   -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28,  8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local sc = CreateFrame("Frame", nil, scrollFrame)
    sc:SetSize(530, 1600)
    scrollFrame:SetScrollChild(sc)

    -- Collect refresh callbacks; called on panel OnShow
    local refreshFns = {}

    -- ── Global enable ──────────────────────────────────────────────────────────

    local enableCB = MakeCheckbox(sc, "Enable Combat Tracker", 8, -16,
        function() return addon.db.combatTracker.enabled end,
        function(val)
            addon.db.combatTracker.enabled = val
            addon:NotifyFeature("combatTracker")
        end
    )

    local resetBtn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 22)
    resetBtn:SetText("Reset Positions")
    local S = ElvSkin()
    if S then S:HandleButton(resetBtn) end
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("TOPLEFT", enableCB, "BOTTOMLEFT", 0, -8)
    resetBtn:SetScript("OnClick", function()
        local defaults = {
            racials     = { point = "CENTER", x = -220, y = 200 },
            trinkets    = { point = "CENTER", x =    0, y = 200 },
            consumables = { point = "CENTER", x =  220, y = 200 },
        }
        for key, def in pairs(defaults) do
            local f = addon.db.combatTracker.frames[key]
            f.point = def.point
            f.x     = def.x
            f.y     = def.y
        end
        addon:NotifyFeature("combatTracker")
    end)

    local sep0 = MakeSeparator(sc, resetBtn, -12)

    -- ── Helper: build a per-section block ─────────────────────────────────────

    local LAYOUT_OPTIONS = {
        { label = "Horizontal", value = "horizontal" },
        { label = "Vertical",   value = "vertical"   },
        { label = "Grid",       value = "grid"        },
    }

    local function BuildSectionBlock(anchor, key, sectionTitle, extraFn)
        local lbl = sc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
        lbl:SetText(sectionTitle)
        lbl:SetTextColor(1, 0.82, 0, 1)

        local secEnabledCB = MakeCheckbox(sc, "Enable", 0, 0,
            function() return addon.db.combatTracker.frames[key].enabled end,
            function(val)
                addon.db.combatTracker.frames[key].enabled = val
                addon:NotifyFeature("combatTracker")
            end
        )
        secEnabledCB:ClearAllPoints()
        secEnabledCB:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -8)

        local layoutLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        layoutLabel:SetPoint("TOPLEFT", secEnabledCB, "BOTTOMLEFT", 0, -10)
        layoutLabel:SetText("Layout:")

        local layoutBtn = MakeDropdown(sc, LAYOUT_OPTIONS,
            function() return addon.db.combatTracker.frames[key].layout end,
            function(val) addon.db.combatTracker.frames[key].layout = val end
        )
        layoutBtn:SetPoint("LEFT", layoutLabel, "RIGHT", 8, 0)
        table.insert(refreshFns, function() layoutBtn:Refresh() end)

        local gridColsLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        gridColsLabel:SetPoint("TOPLEFT", layoutLabel, "TOPLEFT", 220, 0)
        gridColsLabel:SetText("Grid columns:")

        local COLS_OPTIONS = {}
        for i = 2, 5 do
            table.insert(COLS_OPTIONS, { label = tostring(i) .. " cols", value = i })
        end
        local colsBtn = MakeDropdown(sc, COLS_OPTIONS,
            function() return addon.db.combatTracker.frames[key].gridCols end,
            function(val) addon.db.combatTracker.frames[key].gridCols = val end
        )
        colsBtn:SetPoint("LEFT", gridColsLabel, "RIGHT", 8, 0)
        table.insert(refreshFns, function() colsBtn:Refresh() end)

        local widthSlider = MakeSliderWithInput(sc, "Icon Width (px)", 16, 80,
            function() return addon.db.combatTracker.frames[key].iconWidth end,
            function(val)
                addon.db.combatTracker.frames[key].iconWidth = val
                addon:NotifyFeature("combatTracker")
            end
        )
        widthSlider:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -12)
        table.insert(refreshFns, function() widthSlider:Refresh() end)

        local heightSlider = MakeSliderWithInput(sc, "Icon Height (px)", 16, 80,
            function() return addon.db.combatTracker.frames[key].iconHeight end,
            function(val)
                addon.db.combatTracker.frames[key].iconHeight = val
                addon:NotifyFeature("combatTracker")
            end
        )
        heightSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -8)
        table.insert(refreshFns, function() heightSlider:Refresh() end)

        -- Merge-into options: "Standalone" + other two section names
        local mergeOptions = { { label = "Standalone", value = "none" } }
        local sectionNames = { racials="Racials", trinkets="Trinkets", consumables="Consumables" }
        for _, other in ipairs({ "racials", "trinkets", "consumables" }) do
            if other ~= key then
                table.insert(mergeOptions, { label = "-> " .. sectionNames[other], value = other })
            end
        end

        local mergeLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        mergeLabel:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -10)
        mergeLabel:SetText("Merge into:")

        local mergeBtn = MakeDropdown(sc, mergeOptions,
            function()
                return addon.db.combatTracker.frames[key].mergeInto or "none"
            end,
            function(val)
                addon.db.combatTracker.frames[key].mergeInto = (val == "none") and nil or val
                addon:NotifyFeature("combatTracker")
            end
        )
        mergeBtn:SetPoint("LEFT", mergeLabel, "RIGHT", 8, 0)
        table.insert(refreshFns, function() mergeBtn:Refresh() end)

        local lastWidget = mergeLabel
        if extraFn then
            lastWidget = extraFn(mergeLabel) or mergeLabel
        end

        return lastWidget
    end

    -- ── RACIALS section ────────────────────────────────────────────────────────

    local racialSpellContainer
    local lastRacialWidget

    lastRacialWidget = BuildSectionBlock(sep0, "racials", "RACIALS", function(mergeLabel)
        local toggleLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        toggleLabel:SetPoint("TOPLEFT", mergeLabel, "BOTTOMLEFT", 0, -14)
        toggleLabel:SetText("Hide racial abilities:")

        racialSpellContainer = CreateFrame("Frame", nil, sc)
        racialSpellContainer:SetPoint("TOPLEFT", toggleLabel, "BOTTOMLEFT", 0, -6)
        racialSpellContainer:SetSize(500, 100)

        return racialSpellContainer
    end)

    -- Refresh callback for racial toggles: rebuild checkbox list for current race
    table.insert(refreshFns, function()
        -- Clear previous children
        for _, child in ipairs({ racialSpellContainer:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
        for _, child in ipairs({ racialSpellContainer:GetRegions() }) do
            child:Hide()
        end

        local entries = addon.combatTracker
            and addon.combatTracker.sections.racials
            and addon.combatTracker.sections.racials._allRacialNames
            or {}

        local totalHeight = 0
        local prevCB
        for _, entry in ipairs(entries) do
            local cb = MakeCheckbox(racialSpellContainer, entry.name, 0, 0,
                function()
                    return not (addon.db.combatTracker.racials.hiddenSpells[entry.name] == true)
                end,
                function(val)
                    addon.db.combatTracker.racials.hiddenSpells[entry.name] = (not val) and true or nil
                    addon:NotifyFeature("combatTracker")
                end
            )
            cb:ClearAllPoints()
            if prevCB then
                cb:SetPoint("TOPLEFT", prevCB, "BOTTOMLEFT", 0, -4)
            else
                cb:SetPoint("TOPLEFT", racialSpellContainer, "TOPLEFT", 0, 0)
            end
            totalHeight = totalHeight + 26
            prevCB = cb
        end
        racialSpellContainer:SetHeight(math.max(totalHeight, 10))
    end)

    local sep1 = MakeSeparator(sc, racialSpellContainer, -12)

    -- ── TRINKETS section ───────────────────────────────────────────────────────

    local lastTrinketWidget = BuildSectionBlock(sep1, "trinkets", "TRINKETS", function(mergeLabel)
        local onUseCB = MakeCheckbox(sc, "On-use only (hide passive trinkets)", 0, 0,
            function() return addon.db.combatTracker.frames.trinkets.onUseOnly end,
            function(val)
                addon.db.combatTracker.frames.trinkets.onUseOnly = val
                addon:NotifyFeature("combatTracker")
            end
        )
        onUseCB:ClearAllPoints()
        onUseCB:SetPoint("TOPLEFT", mergeLabel, "BOTTOMLEFT", 0, -10)
        return onUseCB
    end)

    local sep2 = MakeSeparator(sc, lastTrinketWidget, -12)

    -- ── CONSUMABLES section ────────────────────────────────────────────────────

    local lastConsWidget = BuildSectionBlock(sep2, "consumables", "CONSUMABLES", function(mergeLabel)
        local hideCB = MakeCheckbox(sc, "Hide icon if not in inventory", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.hideIfMissing end,
            function(val)
                addon.db.combatTracker.frames.consumables.hideIfMissing = val
                addon:NotifyFeature("combatTracker")
            end
        )
        hideCB:ClearAllPoints()
        hideCB:SetPoint("TOPLEFT", mergeLabel, "BOTTOMLEFT", 0, -10)

        local typeLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        typeLabel:SetPoint("TOPLEFT", hideCB, "BOTTOMLEFT", 0, -10)
        typeLabel:SetText("Track these consumable types:")

        local combatCB = MakeCheckbox(sc, "Combat Potions", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showCombatPotions end,
            function(val)
                addon.db.combatTracker.frames.consumables.showCombatPotions = val
                addon:NotifyFeature("combatTracker")
            end
        )
        combatCB:ClearAllPoints()
        combatCB:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -6)

        local healCB = MakeCheckbox(sc, "Healing Potions", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showHealingPotions end,
            function(val)
                addon.db.combatTracker.frames.consumables.showHealingPotions = val
                addon:NotifyFeature("combatTracker")
            end
        )
        healCB:ClearAllPoints()
        healCB:SetPoint("TOPLEFT", combatCB, "TOPLEFT", 200, 0)

        local manaCB = MakeCheckbox(sc, "Mana Potions", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showManaPotions end,
            function(val)
                addon.db.combatTracker.frames.consumables.showManaPotions = val
                addon:NotifyFeature("combatTracker")
            end
        )
        manaCB:ClearAllPoints()
        manaCB:SetPoint("TOPLEFT", combatCB, "BOTTOMLEFT", 0, -4)

        local hsCB = MakeCheckbox(sc, "Healthstone", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showHealthstone end,
            function(val)
                addon.db.combatTracker.frames.consumables.showHealthstone = val
                addon:NotifyFeature("combatTracker")
            end
        )
        hsCB:ClearAllPoints()
        hsCB:SetPoint("TOPLEFT", manaCB, "TOPLEFT", 200, 0)

        local customLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        customLabel:SetPoint("TOPLEFT", manaCB, "BOTTOMLEFT", 0, -14)
        customLabel:SetWidth(500)
        customLabel:SetJustifyH("LEFT")
        customLabel:SetText("Custom item IDs (comma-separated):")

        local customBox = CreateFrame("EditBox", nil, sc, "InputBoxTemplate")
        customBox:SetSize(300, 20)
        customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -6)
        customBox:SetAutoFocus(false)
        customBox:SetMaxLetters(200)

        local function parseCustomItems(str)
            local result = {}
            for id in str:gmatch("%d+") do
                result[tonumber(id)] = true
            end
            return result
        end

        local function customItemsToString(tbl)
            local ids = {}
            for id in pairs(tbl or {}) do table.insert(ids, tostring(id)) end
            table.sort(ids)
            return table.concat(ids, ", ")
        end

        customBox:SetScript("OnEnterPressed", function(self)
            addon.db.combatTracker.frames.consumables.customItems = parseCustomItems(self:GetText())
            self:ClearFocus()
            addon:NotifyFeature("combatTracker")
        end)
        customBox:SetScript("OnEditFocusLost", function(self)
            addon.db.combatTracker.frames.consumables.customItems = parseCustomItems(self:GetText())
            addon:NotifyFeature("combatTracker")
        end)

        table.insert(refreshFns, function()
            customBox:SetText(customItemsToString(addon.db.combatTracker.frames.consumables.customItems))
        end)

        return customBox
    end)

    local sep3 = MakeSeparator(sc, lastConsWidget, -12)

    -- ── MASQUE section (hidden if Masque not loaded) ────────────────────────────

    local MSQ = LibStub and LibStub("Masque", true)
    if MSQ then
        local masqueLabel = sc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        masqueLabel:SetPoint("TOPLEFT", sep3, "BOTTOMLEFT", 0, -10)
        masqueLabel:SetText("MASQUE SKINNING")
        masqueLabel:SetTextColor(1, 0.82, 0, 1)

        local masqueCB = MakeCheckbox(sc, "Enable Masque skinning", 0, 0,
            function() return addon.db.combatTracker.masque.enabled end,
            function(val)
                addon.db.combatTracker.masque.enabled = val
                addon:NotifyFeature("combatTracker")
            end
        )
        masqueCB:ClearAllPoints()
        masqueCB:SetPoint("TOPLEFT", masqueLabel, "BOTTOMLEFT", 0, -8)

        local masqueNote = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        masqueNote:SetPoint("TOPLEFT", masqueCB, "BOTTOMLEFT", 0, -6)
        masqueNote:SetWidth(450)
        masqueNote:SetJustifyH("LEFT")
        masqueNote:SetText("When enabled, three groups appear in the Masque addon UI under MathWroQOL: CT Racials, CT Trinkets, CT Consumables.")
    else
        local masqueNote = sc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        masqueNote:SetPoint("TOPLEFT", sep3, "BOTTOMLEFT", 0, -10)
        masqueNote:SetTextColor(0.5, 0.5, 0.5)
        masqueNote:SetText("Masque skinning: install the Masque addon to enable icon skinning.")
    end

    -- ── Refresh all controls on panel show ────────────────────────────────────

    panel:HookScript("OnShow", function()
        C_Timer.After(0, function()
            for _, fn in ipairs(refreshFns) do fn() end
        end)
    end)

    return panel
end

-- ── Registration ──────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= "MathWroQOL" then return end
    self:UnregisterEvent("ADDON_LOADED")

    local parentPanel   = BuildParentPanel()
    local generalPanel  = BuildGeneralPanel()
    local elvuiPanel    = BuildElvUIPanel()
    local editModePanel      = BuildEditModePanel()
    local combatTrackerPanel = BuildCombatTrackerPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local parentCat = Settings.RegisterCanvasLayoutCategory(parentPanel, parentPanel.name)
        local generalCat = Settings.RegisterCanvasLayoutSubcategory(parentCat, generalPanel,  generalPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, elvuiPanel,    elvuiPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, editModePanel, editModePanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, combatTrackerPanel, combatTrackerPanel.name)
        Settings.RegisterAddOnCategory(parentCat)

        SLASH_MQOL1 = "/mqol"
        SlashCmdList["MQOL"] = function()
            Settings.OpenToCategory(generalCat:GetID())
        end
    else
        -- Fallback for older API
        InterfaceOptions_AddCategory(parentPanel)
        InterfaceOptions_AddCategory(generalPanel, parentPanel)
        InterfaceOptions_AddCategory(elvuiPanel,   parentPanel)
        InterfaceOptions_AddCategory(editModePanel, parentPanel)
        InterfaceOptions_AddCategory(combatTrackerPanel, parentPanel)

        SLASH_MQOL1 = "/mqol"
        SlashCmdList["MQOL"] = function()
            InterfaceOptionsFrame_OpenToCategory(generalPanel)
        end
    end
end)
