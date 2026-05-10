local _, addon = ...

local function ElvSkin()
    if not ElvUI then return nil end
    return ElvUI[1]:GetModule("Skins")
end

local function ApplyFrameBackdrop(frame, useFadeColor)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    if ElvUI then
        local E = ElvUI[1]
        if useFadeColor then
            frame:SetBackdropColor(unpack(E.media.backdropfadecolor))
        else
            frame:SetBackdropColor(unpack(E.media.backdropcolor))
        end
        frame:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end
end

local function SetChildrenEnabled(container, enabled)
    if not container then return end

    local alpha = enabled and 1.0 or 0.4

    local function applyToWidget(widget)
        if not widget then return end

        widget:SetAlpha(alpha)

        if widget.IsObjectType and widget:IsObjectType("CheckButton") then
            if enabled then widget:Enable() else widget:Disable() end
        elseif widget.IsObjectType and widget:IsObjectType("Button") then
            if enabled then widget:Enable() else widget:Disable() end
        elseif widget.IsObjectType and widget:IsObjectType("EditBox") then
            if enabled then widget:SetEnabled(true) else widget:SetEnabled(false) end
        elseif widget.IsObjectType and widget:IsObjectType("Slider") then
            if enabled then widget:Enable() else widget:Disable() end
        else
            widget:EnableMouse(enabled)
        end

        for _, region in ipairs({ widget:GetRegions() }) do
            if region.SetAlpha then
                region:SetAlpha(alpha)
            end
        end

        for _, child in ipairs({ widget:GetChildren() }) do
            applyToWidget(child)
        end
    end

    for _, child in ipairs({ container:GetChildren() }) do
        applyToWidget(child)
    end

    for _, region in ipairs({ container:GetRegions() }) do
        if region.SetAlpha then
            region:SetAlpha(alpha)
        end
    end
end

local function FindScrollChildAndRecalc(startFrame)
    local f = startFrame
    while f do
        if f.RecalcScrollHeight then
            C_Timer.After(0, f.RecalcScrollHeight)
            return
        end
        f = f:GetParent()
    end
end

local function MakePanelScaffold(panel, titleText, scrollName)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(titleText)

    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -6, -8)
    bg:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)
    ApplyFrameBackdrop(bg, true)

    local scrollFrame = CreateFrame("ScrollFrame", scrollName, bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", bg, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -28, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(530, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local function RecalcScrollHeight()
        local top = scrollChild:GetTop()
        if not top then return end
        local lowest = top
        for _, child in pairs({ scrollChild:GetChildren() }) do
            if child:IsShown() then
                local b = child:GetBottom()
                if b and b < lowest then lowest = b end
            end
        end
        local h = math.max(1, (top - lowest) + 20)
        scrollChild:SetHeight(h)
    end

    scrollChild.RecalcScrollHeight = RecalcScrollHeight

    panel:HookScript("OnShow", function()
        C_Timer.After(0, RecalcScrollHeight)
    end)

    return scrollChild
end

local function MakeCard(parent, anchor, title, description)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    card:SetSize(500, 200)
    ApplyFrameBackdrop(card, true)

    local header = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
    header:SetText(title)
    header:SetTextColor(1, 0.82, 0, 1)

    local desc = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(484)
    desc:SetJustifyH("LEFT")
    desc:SetText(description)

    local content = CreateFrame("Frame", nil, card)
    content:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
    content:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    content:SetHeight(1)  -- initial; SetBottomWidget recalculates

    function card:SetBottomWidget(widget, bottomPadding)
        bottomPadding = bottomPadding or 8

        local function applyHeight()
            if not widget or not content:GetTop() or not widget:GetBottom() then return end
            local contentHeight = math.max(10, (content:GetTop() - widget:GetBottom()) + bottomPadding)
            content:SetHeight(contentHeight)

            if card:GetTop() and (widget:GetBottom() or 0) then
                local h = math.max(60, (card:GetTop() - widget:GetBottom()) + bottomPadding)
                card:SetHeight(h)
            end
        end

        applyHeight()
        C_Timer.After(0, applyHeight)
    end

    return card, content
end

local function MakeSeparator(parent, anchor, offsetY)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(1)
    holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    holder:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    local line = holder:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    line:SetAllPoints(holder)

    return holder
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

local function MakeColorSwatch(parent, label, getColor, setColor)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(260, 28)

    local lbl = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", container, "LEFT", 0, 0)
    lbl:SetText(label)

    local swatch = CreateFrame("Button", nil, container, "BackdropTemplate")
    swatch:SetSize(34, 20)
    swatch:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
    ApplyFrameBackdrop(swatch, false)

    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
    swatch.fill = fill

    function swatch:Refresh()
        local c = getColor() or {}
        fill:SetColorTexture(c.r or 1, c.g or 1, c.b or 1, 1)
    end

    swatch:SetScript("OnClick", function(self)
        local c = getColor() or {}
        local oldR, oldG, oldB = c.r or 1, c.g or 1, c.b or 1

        local function commitColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            setColor({ r = r, g = g, b = b })
            self:Refresh()
        end

        local function cancelColor()
            setColor({ r = oldR, g = oldG, b = oldB })
            self:Refresh()
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = oldR,
                g = oldG,
                b = oldB,
                hasOpacity = false,
                swatchFunc = commitColor,
                cancelFunc = cancelColor,
            })
        else
            ColorPickerFrame.func = commitColor
            ColorPickerFrame.cancelFunc = cancelColor
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(oldR, oldG, oldB)
            ColorPickerFrame:Show()
        end
    end)

    swatch:Refresh()
    container.swatch = swatch
    return container
end

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

    local displayBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
    displayBtn:SetSize(40, 20)
    displayBtn:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    ApplyFrameBackdrop(displayBtn, false)
    displayBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local valueLabel = displayBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueLabel:SetAllPoints()
    valueLabel:SetJustifyH("CENTER")

    local input = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    input:SetFontObject(GameFontHighlightSmall)
    input:SetJustifyH("CENTER")
    input:SetSize(40, 20)
    input:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(3)
    ApplyFrameBackdrop(input, false)
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

local _openDropdownPopups = {}
local _dropdownCount = 0
local function MakeDropdown(parent, options, getValue, setValue, notifyFeature)
    _dropdownCount = _dropdownCount + 1
    notifyFeature = notifyFeature or "combatTracker"

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(130, 22)
    ApplyFrameBackdrop(btn, false)
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    if ElvUI then
        btn:SetBackdropBorderColor(unpack(ElvUI[1].media.bordercolor))
    end

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetPoint("RIGHT", -22, 0)
    btnText:SetJustifyH("LEFT")

    local btnIcon = btn:CreateTexture(nil, "OVERLAY")
    btnIcon:SetSize(14, 14)
    btnIcon:SetPoint("LEFT", btn, "LEFT", 5, 0)
    btnIcon:Hide()

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -3, 0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    arrow:SetTexCoord(0, 1, 0, 0.5)
    arrow:SetVertexColor(1, 0.82, 0, 1)
    btn.arrow = arrow

    local popup = CreateFrame("Frame", "MathWroQOL_DropPopup" .. _dropdownCount, UIParent, "BackdropTemplate")
    table.insert(_openDropdownPopups, popup)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetWidth(130)
    ApplyFrameBackdrop(popup, false)
    popup:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    if ElvUI then
        popup:SetBackdropBorderColor(unpack(ElvUI[1].media.bordercolor))
    end
    popup:Hide()

    local ROW_H = 20
    local rows = {}

    local function clearRows()
        for _, row in ipairs(rows) do
            row.frame:Hide()
        end
        rows = {}
    end

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

    local function refresh()
        local cur = getValue()
        for _, r in ipairs(rows) do
            if r.opt.value == cur then
                btnText:SetText(r.opt.label)
                if r.opt.icon then
                    btnIcon:SetTexture(r.opt.icon)
                    btnIcon:Show()
                    btnText:ClearAllPoints()
                    btnText:SetPoint("LEFT", btnIcon, "RIGHT", 5, 0)
                    btnText:SetPoint("RIGHT", -22, 0)
                else
                    btnIcon:Hide()
                    btnText:ClearAllPoints()
                    btnText:SetPoint("LEFT", 6, 0)
                    btnText:SetPoint("RIGHT", -22, 0)
                end
                return
            end
        end
        btnIcon:Hide()
        btnText:ClearAllPoints()
        btnText:SetPoint("LEFT", 6, 0)
        btnText:SetPoint("RIGHT", -22, 0)
        if options[1] then btnText:SetText(options[1].label) end
    end

    local function rebuildRows(newOptions)
        if newOptions then options = newOptions end
        clearRows()
        popup:SetHeight(math.max(1, #options) * ROW_H + 4)

        for i, opt in ipairs(options) do
            local row = CreateFrame("Button", nil, popup)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT", popup, "TOPLEFT", 2, -(i - 1) * ROW_H - 2)
            row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -(i - 1) * ROW_H - 2)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 0.82, 0, 0.15)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if opt.icon then
                local icon = row:CreateTexture(nil, "OVERLAY")
                icon:SetSize(14, 14)
                icon:SetPoint("LEFT", row, "LEFT", 5, 0)
                icon:SetTexture(opt.icon)
                row.icon = icon
                label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            else
                label:SetPoint("LEFT", 6, 0)
            end
            label:SetJustifyH("LEFT")
            label:SetText(opt.label)
            row.label = label

            row:SetScript("OnClick", function()
                if opt.action then
                    opt.action(btn)
                else
                    setValue(opt.value)
                    btnText:SetText(opt.label)
                    addon:NotifyFeature(notifyFeature)
                end
                popup:Hide()
            end)

            rows[i] = { frame = row, opt = opt }
        end

        refresh()
    end

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
    popup:HookScript("OnShow", function() catcher:Show(); arrow:SetTexCoord(0, 1, 0.5, 1) end)
    popup:HookScript("OnHide", function() catcher:Hide(); arrow:SetTexCoord(0, 1, 0, 0.5) end)

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
        if ElvUI then
            self:SetBackdropBorderColor(unpack(ElvUI[1].media.bordercolor))
        else
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
    end)

    rebuildRows(options)
    btn.Refresh = refresh
    btn.SetOptions = rebuildRows
    btn.SetDropdownWidth = function(_, width)
        width = tonumber(width)
        if not width then return end
        btn:SetWidth(width)
        popup:SetWidth(width)
    end
    return btn
end

local function MakeCollapsibleSection(parent, title, isExpanded)
    local HEADER_H = 24

    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetWidth(500)
    ApplyFrameBackdrop(section, true)

    local header = CreateFrame("Button", nil, section)
    header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)

    local hover = header:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 0.82, 0, 0.08)

    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("LEFT", 6, 0)

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    label:SetTextColor(1, 0.82, 0, 1)
    label:SetText(title)

    local content = CreateFrame("Frame", nil, section)
    content:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -(HEADER_H + 6))
    content:SetPoint("TOPRIGHT", section, "TOPRIGHT", -8, -(HEADER_H + 6))
    content:SetHeight(1)

    section.content = content
    section.header = header
    section._expanded = isExpanded == true
    section._contentBottomWidget = nil
    section._contentBottomPadding = 8
    section._contentHeight = 1

    function section:UpdateLayout()
        if self._expanded then
            content:Show()
            if self._contentBottomWidget and content:GetTop() and self._contentBottomWidget:GetBottom() then
                self._contentHeight = math.max(10, (content:GetTop() - self._contentBottomWidget:GetBottom()) + self._contentBottomPadding)
            end
            content:SetHeight(self._contentHeight)
            self:SetHeight(HEADER_H + self._contentHeight + 12)
            arrow:SetAtlas("Soulbinds_Collection_CategoryHeader_Collapse", false)
        else
            content:Hide()
            self:SetHeight(HEADER_H + 4)
            arrow:SetAtlas("Soulbinds_Collection_CategoryHeader_Expand", false)
        end
    end

    function section:SetContentBottom(widget, padding)
        self._contentBottomWidget = widget
        self._contentBottomPadding = padding or 8
        self:UpdateLayout()
        C_Timer.After(0, function() self:UpdateLayout() end)
    end

    local function bubbleScrollRecalc()
        FindScrollChildAndRecalc(section)
    end

    function section:SetExpanded(expanded)
        self._expanded = expanded == true
        self:UpdateLayout()
        if self._expanded then
            C_Timer.After(0, function()
                self:UpdateLayout()
                bubbleScrollRecalc()
            end)
        else
            bubbleScrollRecalc()
        end
    end

    header:SetScript("OnClick", function()
        section:SetExpanded(not section._expanded)
    end)

    section:SetExpanded(isExpanded == true)
    return section
end

local function BuildParentPanel()
    local panel = CreateFrame("Frame")
    panel.name = "MathWro QOL"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MathWro QOL")

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ver:SetText("v1.5.2 by MathWro  |  Select a category on the left.")

    return panel
end

local function BuildGeneralPanel()
    local panel = CreateFrame("Frame")
    panel.name = "General"

    local sc = MakePanelScaffold(panel, "General", "MathWroQOL_GeneralScroll")

    local rootAnchor = CreateFrame("Frame", nil, sc)
    rootAnchor:SetSize(1, 1)
    rootAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)

    local gameMenuCard, gameMenuContent = MakeCard(
        sc,
        rootAnchor,
        "Game Menu",
        "Customize the Escape menu appearance and behavior."
    )

    local gmSlider = CreateFrame("Slider", "MathWroQOL_GameMenuSlider", gameMenuContent, "OptionsSliderTemplate")
    gmSlider:SetPoint("TOPLEFT", gameMenuContent, "TOPLEFT", 16, -2)
    gmSlider:SetMinMaxValues(0.5, 2.0)
    gmSlider:SetValueStep(0.05)
    gmSlider:SetObeyStepOnDrag(true)
    gmSlider:SetWidth(220)
    _G[gmSlider:GetName() .. "Low"]:SetText("0.5x")
    _G[gmSlider:GetName() .. "High"]:SetText("2.0x")
    _G[gmSlider:GetName() .. "Text"]:SetText("Scale: 1.0x")

    local S = ElvSkin()
    if S then S:HandleSliderFrame(gmSlider) end

    gmSlider:SetScript("OnValueChanged", function(self, value, userInput)
        _G[self:GetName() .. "Text"]:SetText(string.format("Scale: %.2fx", value))
        if not userInput then return end
        if not addon.db.gameMenu then addon.db.gameMenu = {} end
        addon.db.gameMenu.scale = value
        addon:NotifyFeature("gameMenu")
    end)

    local dragCB = MakeCheckbox(gameMenuContent, "Allow dragging", 0, 0,
        function() return addon.db.gameMenu and addon.db.gameMenu.moveable == true end,
        function(val)
            if not addon.db.gameMenu then addon.db.gameMenu = {} end
            addon.db.gameMenu.moveable = val
            addon:NotifyFeature("gameMenu")
        end
    )
    dragCB:ClearAllPoints()
    dragCB:SetPoint("TOPLEFT", gmSlider, "BOTTOMLEFT", -4, -12)

    local resetContainer = CreateFrame("Frame", nil, gameMenuContent)
    resetContainer:SetPoint("TOPLEFT", dragCB, "BOTTOMLEFT", 20, -6)
    resetContainer:SetSize(160, 24)

    local resetBtn = CreateFrame("Button", nil, resetContainer, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("TOPLEFT", resetContainer, "TOPLEFT", 0, 0)
    resetBtn:SetText("Reset Position")
    if S then S:HandleButton(resetBtn) end
    resetBtn:SetScript("OnClick", function()
        for _, f in ipairs(addon.features) do
            if f.name == "gameMenu" and f.ResetPosition then
                f:ResetPosition()
                break
            end
        end
    end)

    local function updateDragGatekeeper()
        SetChildrenEnabled(resetContainer, addon.db.gameMenu and addon.db.gameMenu.moveable == true)
    end
    dragCB:HookScript("OnClick", updateDragGatekeeper)

    gameMenuCard:SetBottomWidget(resetContainer, 10)

    local cdmCard, cdmContent = MakeCard(
        sc,
        gameMenuCard,
        "CDM Button",
        "Adds a CDM button to the Game Menu that opens the Cooldown Manager."
    )

    local cdmEnableCB = MakeCheckbox(cdmContent, "Show CDM button in game menu", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.enabled end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.enabled = val
            addon:NotifyFeature("cdmButton")
        end
    )
    cdmEnableCB:ClearAllPoints()
    cdmEnableCB:SetPoint("TOPLEFT", cdmContent, "TOPLEFT", 12, -2)

    local slashContainer = CreateFrame("Frame", nil, cdmContent)
    slashContainer:SetPoint("TOPLEFT", cdmEnableCB, "BOTTOMLEFT", 20, -6)
    slashContainer:SetSize(430, 110)

    local slashLabel = slashContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashLabel:SetPoint("TOPLEFT", slashContainer, "TOPLEFT", 0, 0)
    slashLabel:SetText("Slash commands:")

    local waCB = MakeCheckbox(slashContainer, "Enable /wa command", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashWA end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashWA = val
        end
    )
    waCB:ClearAllPoints()
    waCB:SetPoint("TOPLEFT", slashLabel, "BOTTOMLEFT", -4, -4)

    local cmCB = MakeCheckbox(slashContainer, "Enable /cm command", 0, 0,
        function() return addon.db.cdmButton and addon.db.cdmButton.slashCM end,
        function(val)
            if not addon.db.cdmButton then addon.db.cdmButton = {} end
            addon.db.cdmButton.slashCM = val
        end
    )
    cmCB:ClearAllPoints()
    cmCB:SetPoint("TOPLEFT", waCB, "BOTTOMLEFT", 0, -4)

    local function updateCDMGatekeeper()
        SetChildrenEnabled(slashContainer, addon.db.cdmButton and addon.db.cdmButton.enabled == true)
    end
    cdmEnableCB:HookScript("OnClick", updateCDMGatekeeper)

    cdmCard:SetBottomWidget(slashContainer, 10)

    local auctionCard, auctionContent = MakeCard(
        sc,
        cdmCard,
        "Auction House Filters",
        "Automatically enable selected filters each time you open the Auction House."
    )

    local ahExpCB = MakeCheckbox(auctionContent, "Auto-enable 'Current expansion only' filter", 0, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.currentExpansionOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.currentExpansionOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahExpCB:ClearAllPoints()
    ahExpCB:SetPoint("TOPLEFT", auctionContent, "TOPLEFT", 12, -2)

    local ahUsableCB = MakeCheckbox(auctionContent, "Auto-enable 'Usable only' filter", 0, 0,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.usableOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.usableOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
    ahUsableCB:ClearAllPoints()
    ahUsableCB:SetPoint("TOPLEFT", ahExpCB, "BOTTOMLEFT", 0, -4)

    auctionCard:SetBottomWidget(ahUsableCB, 10)

    panel:HookScript("OnShow", function()
        local scale = (addon.db.gameMenu and addon.db.gameMenu.scale) or 1.0
        gmSlider:SetValue(scale)
        updateDragGatekeeper()
        updateCDMGatekeeper()
    end)

    return panel
end

local function BuildCombatLogPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Combat Logging"

    local sc = MakePanelScaffold(panel, "Combat Logging", "MathWroQOL_CombatLogScroll")

    local rootAnchor = CreateFrame("Frame", nil, sc)
    rootAnchor:SetSize(1, 1)
    rootAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)

    local card, content = MakeCard(
        sc,
        rootAnchor,
        "Combat Logging",
        "Automatically start combat logging when entering selected instance types. Stops on exit. If you manually stop logging mid-instance, it stays off until the next instance."
    )

    local clDungeonCB = MakeCheckbox(content, "Dungeon (includes Mythic+)", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.dungeon end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.dungeon = val
        end
    )
    clDungeonCB:ClearAllPoints()
    clDungeonCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -2)

    local clRaidCB = MakeCheckbox(content, "Raid", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.raid end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.raid = val
        end
    )
    clRaidCB:ClearAllPoints()
    clRaidCB:SetPoint("TOPLEFT", clDungeonCB, "TOPLEFT", 220, 0)

    local clScenarioCB = MakeCheckbox(content, "Scenario", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.scenario end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.scenario = val
        end
    )
    clScenarioCB:ClearAllPoints()
    clScenarioCB:SetPoint("TOPLEFT", clDungeonCB, "BOTTOMLEFT", 0, -4)

    local clPvpCB = MakeCheckbox(content, "Battleground", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.pvp end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.pvp = val
        end
    )
    clPvpCB:ClearAllPoints()
    clPvpCB:SetPoint("TOPLEFT", clScenarioCB, "TOPLEFT", 220, 0)

    local clArenaCB = MakeCheckbox(content, "Arena", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.arena end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.arena = val
        end
    )
    clArenaCB:ClearAllPoints()
    clArenaCB:SetPoint("TOPLEFT", clScenarioCB, "BOTTOMLEFT", 0, -4)

    local clMaxLevelCB = MakeCheckbox(content, "Only at max level", 0, 0,
        function() return addon.db.combatLog and addon.db.combatLog.maxLevelOnly end,
        function(val)
            if not addon.db.combatLog then addon.db.combatLog = {} end
            addon.db.combatLog.maxLevelOnly = val
        end
    )
    clMaxLevelCB:ClearAllPoints()
    clMaxLevelCB:SetPoint("TOPLEFT", clArenaCB, "BOTTOMLEFT", 0, -10)

    card:SetBottomWidget(clMaxLevelCB, 12)

    return panel
end

local function BuildElvUIPanel()
    local panel = CreateFrame("Frame")
    panel.name = "ElvUI Plugins"

    local sc = MakePanelScaffold(panel, "ElvUI Plugins", "MathWroQOL_ElvUIScroll")
    local elvuiLoaded = ElvUI ~= nil

    local rootAnchor = CreateFrame("Frame", nil, sc)
    rootAnchor:SetSize(1, 1)
    rootAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)

    local card, content = MakeCard(
        sc,
        rootAnchor,
        "Vehicle Bar Visibility",
        "Keep selected action bars visible while in vehicle combat, including override bar states. Prevents mouseover fade from hiding bars during these encounters."
    )

    local notice
    if not elvuiLoaded then
        notice = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notice:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -2)
        notice:SetTextColor(1, 0.3, 0.3)
        notice:SetText("ElvUI is not loaded. These options are unavailable.")
    end

    local enabledCB = MakeCheckbox(content, "Enable", 0, 0,
        function() return addon.db.vehicleBar and addon.db.vehicleBar.enabled end,
        function(val)
            if addon.db.vehicleBar then
                addon.db.vehicleBar.enabled = val
                addon:NotifyFeature("vehicleBar")
            end
        end
    )
    enabledCB:ClearAllPoints()
    if notice then
        enabledCB:SetPoint("TOPLEFT", notice, "BOTTOMLEFT", -4, -8)
    else
        enabledCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -2)
    end

    local barsContainer = CreateFrame("Frame", nil, content)
    barsContainer:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 20, -6)
    barsContainer:SetSize(430, 170)

    local barsLabel = barsContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    barsLabel:SetPoint("TOPLEFT", barsContainer, "TOPLEFT", 0, 0)
    barsLabel:SetText("Bars to keep visible:")

    local barRefs = {}
    for i = 1, 10 do
        local col = (i - 1) % 5
        local cb = MakeCheckbox(barsContainer, "Bar " .. i, 0, 0,
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
            cb:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", -4, -6)
        elseif i == 6 then
            cb:SetPoint("TOPLEFT", barRefs[1], "BOTTOMLEFT", 0, -4)
        elseif col == 0 then
            cb:SetPoint("TOPLEFT", barRefs[i - 5], "BOTTOMLEFT", 0, -4)
        else
            cb:SetPoint("TOPLEFT", barRefs[i - 1], "TOPLEFT", 90, 0)
        end
        barRefs[i] = cb
    end

    local function updateVehicleGatekeeper()
        local enabled = addon.db.vehicleBar and addon.db.vehicleBar.enabled == true
        SetChildrenEnabled(barsContainer, enabled)
    end
    enabledCB:HookScript("OnClick", updateVehicleGatekeeper)

    if not elvuiLoaded then
        enabledCB:Disable()
        enabledCB:SetAlpha(0.4)
        SetChildrenEnabled(barsContainer, false)
    end

    card:SetBottomWidget(barsContainer, 10)

    local buffCard, buffContent = MakeCard(
        sc,
        card,
        "Buff Health Color",
        "Recolor selected ElvUI unit frame health bars while units have configured buffs. Add custom spell IDs to create more buff profiles next to Atonement and Lifebloom."
    )

    local buffEnableCB = MakeCheckbox(buffContent, "Enable", 0, 0,
        function()
            return addon.db.buffHealthColor and addon.db.buffHealthColor.enabled == true
        end,
        function(val)
            if addon.db.buffHealthColor then
                addon.db.buffHealthColor.enabled = val
                addon:NotifyFeature("buffHealthColor")
            end
        end
    )
    buffEnableCB:ClearAllPoints()
    buffEnableCB:SetPoint("TOPLEFT", buffContent, "TOPLEFT", 12, -2)

    local buffOptions = CreateFrame("Frame", nil, buffContent)
    buffOptions:SetPoint("TOPLEFT", buffEnableCB, "BOTTOMLEFT", 20, -8)
    buffOptions:SetSize(430, 330)

    local buffOrder = {
        "atonement",
        "lifebloom",
        "prayerOfMending",
        "riptide",
        "beaconOfTheSavior",
        "renewingMist",
    }
    local builtinLabels = {
        atonement = "Atonement",
        lifebloom = "Lifebloom",
        prayerOfMending = "Prayer of Mending",
        riptide = "Riptide",
        beaconOfTheSavior = "Beacon of the Savior",
        renewingMist = "Renewing Mist",
    }
    local builtinSpellIDs = {
        atonement = 194384,
        lifebloom = 33763,
        prayerOfMending = 41635,
        riptide = 61295,
        beaconOfTheSavior = 1244893,
        renewingMist = 448430,
    }
    local defaultColors = {
        atonement = { r = 0.95, g = 0.72, b = 0.22 },
        lifebloom = { r = 0.20, g = 0.85, b = 0.25 },
        prayerOfMending = { r = 0.95, g = 0.88, b = 0.42 },
        riptide = { r = 0.16, g = 0.62, b = 0.95 },
        beaconOfTheSavior = { r = 1.00, g = 0.78, b = 0.50 },
        renewingMist = { r = 0.35, g = 0.92, b = 0.70 },
    }
    local defaultSpecs = {
        atonement = { [256] = true },
        lifebloom = { [105] = true },
        prayerOfMending = { [257] = true },
        riptide = { [264] = true },
        beaconOfTheSavior = { [65] = true },
        renewingMist = { [270] = true },
    }
    local healerSpecChoices = {
        { specID = 256, label = "Discipline Priest" },
        { specID = 257, label = "Holy Priest" },
        { specID = 65, label = "Holy Paladin" },
        { specID = 105, label = "Restoration Druid" },
        { specID = 264, label = "Restoration Shaman" },
        { specID = 270, label = "Mistweaver Monk" },
    }
    local specChoicesByBuff = {
        atonement = {
            { specID = 256, label = "Discipline Priest" },
        },
        lifebloom = {
            { specID = 105, label = "Restoration Druid" },
        },
        prayerOfMending = {
            { specID = 256, label = "Discipline Priest" },
            { specID = 257, label = "Holy Priest" },
        },
        riptide = {
            { specID = 264, label = "Restoration Shaman" },
        },
        beaconOfTheSavior = {
            { specID = 65, label = "Holy Paladin" },
        },
        renewingMist = {
            { specID = 270, label = "Mistweaver Monk" },
        },
    }

    local function copyFrames(frames)
        frames = frames or {}
        return {
            player = frames.player == true,
            target = frames.target == true,
            party  = frames.party ~= false,
            raid1  = frames.raid1 ~= false,
            raid2  = frames.raid2 ~= false,
            raid3  = frames.raid3 ~= false,
        }
    end

    local function copyColor(color, fallback)
        color = color or fallback or {}
        return {
            r = color.r or 1,
            g = color.g or 1,
            b = color.b or 1,
        }
    end

    local function copySpecs(specs)
        local copy = {}
        for specID, enabled in pairs(specs or {}) do
            copy[tonumber(specID) or specID] = enabled == true
        end
        return copy
    end

    local function specTableHasValues(specs)
        if type(specs) ~= "table" then return false end
        for _, enabled in pairs(specs) do
            if enabled == true then return true end
        end
        return false
    end

    local function getCurrentSpecID()
        if not GetSpecialization or not GetSpecializationInfo then return nil end

        local specIndex = GetSpecialization()
        if not specIndex then return nil end

        return tonumber(GetSpecializationInfo(specIndex))
    end

    local function getSpecChoicesFromTable(specs)
        local choices = {}
        for _, option in ipairs(healerSpecChoices) do
            if specs[option.specID] == true or specs[tostring(option.specID)] == true then
                table.insert(choices, option)
            end
        end
        return choices
    end

    local function getSpecChoices(key, profile)
        if specChoicesByBuff[key] then return specChoicesByBuff[key], false end

        if profile and specTableHasValues(profile.validSpecs) then
            return getSpecChoicesFromTable(profile.validSpecs), false
        end

        local choices = { { specID = 0, label = "All specs" } }
        for _, option in ipairs(healerSpecChoices) do
            table.insert(choices, option)
        end
        return choices, true
    end

    local function inferCustomSpellSpecs(spellID)
        local inferred = {}
        local spellBook = C_SpellBook
        local currentSpecID = getCurrentSpecID()

        if spellBook and spellBook.GetNumSpellBookSkillLines and spellBook.GetSpellBookSkillLineInfo and spellBook.GetSpellBookItemInfo then
            local numLines = spellBook.GetNumSpellBookSkillLines()
            for lineIndex = 1, numLines do
                local lineInfo = spellBook.GetSpellBookSkillLineInfo(lineIndex)
                if lineInfo then
                    local lineSpecID = tonumber(lineInfo.offSpecID) or currentSpecID
                    local startIndex = (lineInfo.itemIndexOffset or 0) + 1
                    local endIndex = (lineInfo.itemIndexOffset or 0) + (lineInfo.numSpellBookItems or 0)
                    for slotIndex = startIndex, endIndex do
                        local item = spellBook.GetSpellBookItemInfo(slotIndex, Enum.SpellBookSpellBank.Player)
                        if item and tonumber(item.spellID) == spellID and lineSpecID then
                            inferred[lineSpecID] = true
                        elseif item and item.itemType == Enum.SpellBookItemType.Flyout and GetFlyoutInfo and GetFlyoutSlotInfo then
                            local _, _, flyoutNumSlots = GetFlyoutInfo(item.actionID)
                            for flyoutSlot = 1, flyoutNumSlots or 0 do
                                local flyoutSpellID, _, _, _, slotSpecID = GetFlyoutSlotInfo(item.actionID, flyoutSlot)
                                if tonumber(flyoutSpellID) == spellID then
                                    inferred[tonumber(slotSpecID) or lineSpecID] = true
                                end
                            end
                        end
                    end
                end
            end
        end

        if not specTableHasValues(inferred) and IsPlayerSpell and IsPlayerSpell(spellID) and currentSpecID then
            inferred[currentSpecID] = true
        end

        return inferred
    end

    local function getSpellLabel(spellID)
        spellID = tonumber(spellID)
        if not spellID then return nil end

        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            if info and info.name then return info.name end
        end

        local name = GetSpellInfo and GetSpellInfo(spellID)
        return name
    end

    local function getSpellIcon(spellID)
        spellID = tonumber(spellID)
        if not spellID then return nil end

        if C_Spell and C_Spell.GetSpellTexture then
            return C_Spell.GetSpellTexture(spellID)
        end

        return GetSpellTexture and GetSpellTexture(spellID)
    end

    local function ensureBuffDb()
        local db = addon.db.buffHealthColor
        if not db then return nil end
        if type(db.buffs) ~= "table" then db.buffs = {} end
        if type(db.customOrder) ~= "table" then db.customOrder = {} end

        for _, key in ipairs(buffOrder) do
            if type(db.buffs[key]) ~= "table" then db.buffs[key] = {} end
            local profile = db.buffs[key]
            if profile.enabled == nil then profile.enabled = key == "atonement" end
            profile.label = profile.label or builtinLabels[key]
            profile.spellID = profile.spellID or builtinSpellIDs[key]
            profile.color = profile.color or copyColor(defaultColors[key])
            profile.frames = profile.frames or copyFrames()
            if profile.allSpecs == nil then profile.allSpecs = false end
            if not profile.specs then profile.specs = copySpecs(defaultSpecs[key]) end
            profile.validSpecs = copySpecs(defaultSpecs[key])
            if key == "prayerOfMending" then profile.validSpecs[256] = true end
        end

        for _, key in ipairs(db.customOrder) do
            local profile = db.buffs[key]
            if type(profile) == "table" then
                if profile.enabled == nil then profile.enabled = true end
                profile.label = profile.label or ("Spell " .. tostring(profile.spellID or key))
                profile.color = profile.color or copyColor(defaultColors.atonement)
                profile.frames = profile.frames or copyFrames()
                if profile.allSpecs == nil then profile.allSpecs = true end
                if not profile.specs then profile.specs = {} end
                if profile.validSpecs ~= nil and not specTableHasValues(profile.validSpecs) then profile.validSpecs = nil end
            end
        end

        db.selectedBuff = db.selectedBuff or "atonement"
        return db
    end

    local function getSelectedProfile()
        local db = ensureBuffDb()
        if not db or not db.buffs then return nil end
        local profile = db.buffs[db.selectedBuff]
        if profile then return profile end

        db.selectedBuff = "atonement"
        return db.buffs.atonement
    end

    local openCustomSpellPopup = function() end

    local function buildBuffOptions()
        local db = ensureBuffDb()
        local options = {}

        for _, key in ipairs(buffOrder) do
            local profile = db and db.buffs and db.buffs[key]
            table.insert(options, {
                label = profile and profile.label or builtinLabels[key],
                value = key,
                icon = getSpellIcon(profile and profile.spellID or builtinSpellIDs[key]),
            })
        end

        for _, key in ipairs((db and db.customOrder) or {}) do
            local profile = db.buffs and db.buffs[key]
            if profile then
                table.insert(options, {
                    label = profile.label or ("Spell " .. tostring(profile.spellID)),
                    value = key,
                    icon = getSpellIcon(profile.spellID),
                })
            end
        end

        table.insert(options, {
            label = "Add custom ID...",
            action = function()
                openCustomSpellPopup()
            end,
        })

        return options
    end

    local selectorLabel = buffOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    selectorLabel:SetPoint("TOPLEFT", buffOptions, "TOPLEFT", 0, 0)
    selectorLabel:SetText("Buff profile:")

    local profileEnableCB
    local profileAllSpecsCB
    local colorSwatch
    local spellInfo
    local removeBtn
    local frameRefs = {}
    local frameCheckboxes = {}
    local specCheckboxes = {}
    local specRefs = {}
    local specFixedText
    local refreshSpecControls = function() end
    local buffSelector

    local function refreshProfileControls()
        local db = ensureBuffDb()
        local profile = getSelectedProfile()
        if not db or not profile then return end

        if buffSelector then
            buffSelector:Refresh()
        end
        if profileEnableCB then profileEnableCB:SetChecked(profile.enabled == true) end
        for key, cb in pairs(frameCheckboxes) do
            cb:SetChecked(profile.frames and profile.frames[key] == true)
        end
        refreshSpecControls(db.selectedBuff, profile)
        if colorSwatch and colorSwatch.swatch then colorSwatch.swatch:Refresh() end
        if spellInfo then
            spellInfo:SetText("Spell ID: " .. tostring(profile.spellID or ""))
        end
        if removeBtn then
            local removable = tostring(db.selectedBuff or ""):match("^custom:")
            removeBtn:SetShown(removable and true or false)
        end
    end

    buffSelector = MakeDropdown(buffOptions, buildBuffOptions(),
        function()
            local db = ensureBuffDb()
            return db and db.selectedBuff or "atonement"
        end,
        function(value)
            local db = ensureBuffDb()
            if db then
                db.selectedBuff = value
                C_Timer.After(0, refreshProfileControls)
            end
        end,
        "buffHealthColor"
    )
    buffSelector:SetDropdownWidth(210)
    buffSelector:SetPoint("LEFT", selectorLabel, "RIGHT", 12, 0)

    local customPopup = CreateFrame("Frame", "MathWroQOL_BuffHealthColorCustomSpellPopup", UIParent, "BackdropTemplate")
    customPopup:SetSize(220, 78)
    customPopup:SetFrameStrata("TOOLTIP")
    ApplyFrameBackdrop(customPopup, false)
    customPopup:Hide()

    local customPopupLabel = customPopup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    customPopupLabel:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 10, -10)
    customPopupLabel:SetText("Add buff spell ID")

    local customInput = CreateFrame("EditBox", nil, customPopup, "InputBoxTemplate")
    customInput:SetSize(92, 22)
    customInput:SetPoint("TOPLEFT", customPopupLabel, "BOTTOMLEFT", 2, -10)
    customInput:SetAutoFocus(false)
    customInput:SetNumeric(true)
    customInput:SetMaxLetters(8)

    local addCustomBtn = CreateFrame("Button", nil, customPopup, "UIPanelButtonTemplate")
    addCustomBtn:SetSize(48, 22)
    addCustomBtn:SetPoint("LEFT", customInput, "RIGHT", 8, 0)
    addCustomBtn:SetText("Add")
    local addCustomSkin = ElvSkin()
    if addCustomSkin then addCustomSkin:HandleButton(addCustomBtn) end

    local cancelCustomBtn = CreateFrame("Button", nil, customPopup, "UIPanelButtonTemplate")
    cancelCustomBtn:SetSize(58, 22)
    cancelCustomBtn:SetPoint("LEFT", addCustomBtn, "RIGHT", 6, 0)
    cancelCustomBtn:SetText("Cancel")
    local cancelCustomSkin = ElvSkin()
    if cancelCustomSkin then cancelCustomSkin:HandleButton(cancelCustomBtn) end

    local function addCustomSpellID()
        local spellID = tonumber(customInput:GetText())
        if not spellID or spellID < 1 then return end

        local db = ensureBuffDb()
        if not db then return end

        local key = "custom:" .. tostring(spellID)
        if not db.buffs[key] then
            local inferredSpecs = inferCustomSpellSpecs(spellID)
            local inferred = specTableHasValues(inferredSpecs)
            db.buffs[key] = {
                enabled = true,
                label = getSpellLabel(spellID) or ("Spell " .. tostring(spellID)),
                spellID = spellID,
                color = copyColor(defaultColors.atonement),
                frames = copyFrames(),
                allSpecs = not inferred,
                specs = inferred and copySpecs(inferredSpecs) or {},
                validSpecs = inferred and copySpecs(inferredSpecs) or nil,
            }
            table.insert(db.customOrder, key)
        end

        db.selectedBuff = key
        customInput:SetText("")
        customPopup:Hide()
        buffSelector:SetOptions(buildBuffOptions())
        refreshProfileControls()
        addon:NotifyFeature("buffHealthColor")
        FindScrollChildAndRecalc(buffOptions)
    end

    openCustomSpellPopup = function()
        customPopup:ClearAllPoints()
        customPopup:SetPoint("TOPLEFT", buffSelector, "BOTTOMLEFT", 0, -4)
        customPopup:Show()
        customInput:SetText("")
        customInput:SetFocus()
    end

    addCustomBtn:SetScript("OnClick", addCustomSpellID)
    cancelCustomBtn:SetScript("OnClick", function()
        customInput:SetText("")
        customPopup:Hide()
    end)
    customInput:SetScript("OnEnterPressed", function(self)
        addCustomSpellID()
        self:ClearFocus()
    end)
    customInput:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        customPopup:Hide()
    end)

    profileEnableCB = MakeCheckbox(buffOptions, "Enable selected buff", 0, 0,
        function()
            local profile = getSelectedProfile()
            return profile and profile.enabled == true
        end,
        function(val)
            local profile = getSelectedProfile()
            if profile then
                profile.enabled = val == true
                addon:NotifyFeature("buffHealthColor")
            end
        end
    )
    profileEnableCB:ClearAllPoints()
    profileEnableCB:SetPoint("TOPLEFT", selectorLabel, "BOTTOMLEFT", -4, -8)

    spellInfo = buffOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    spellInfo:SetPoint("LEFT", profileEnableCB.Text, "RIGHT", 18, 0)
    spellInfo:SetTextColor(0.68, 0.68, 0.68)

    colorSwatch = MakeColorSwatch(buffOptions, "Buff color",
        function()
            local profile = getSelectedProfile()
            return profile and profile.color
        end,
        function(color)
            local profile = getSelectedProfile()
            if profile then
                profile.color = color
                addon:NotifyFeature("buffHealthColor")
            end
        end
    )
    colorSwatch:SetPoint("TOPLEFT", profileEnableCB, "BOTTOMLEFT", 4, -10)

    local frameLabel = buffOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frameLabel:SetPoint("TOPLEFT", colorSwatch, "BOTTOMLEFT", 0, -10)
    frameLabel:SetText("Frames to recolor:")

    local frameOptions = {
        { key = "player", label = "Player" },
        { key = "target", label = "Target" },
        { key = "party",  label = "Party" },
        { key = "raid1",  label = "Raid 1" },
        { key = "raid2",  label = "Raid 2" },
        { key = "raid3",  label = "Raid 3" },
    }

    for i, opt in ipairs(frameOptions) do
        local cb = MakeCheckbox(buffOptions, opt.label, 0, 0,
            function()
                local profile = getSelectedProfile()
                return profile and profile.frames and profile.frames[opt.key] == true
            end,
            function(val)
                local profile = getSelectedProfile()
                if profile and profile.frames then
                    profile.frames[opt.key] = val == true
                    addon:NotifyFeature("buffHealthColor")
                end
            end
        )
        cb:ClearAllPoints()
        if i == 1 then
            cb:SetPoint("TOPLEFT", frameLabel, "BOTTOMLEFT", -4, -6)
        elseif i == 4 then
            cb:SetPoint("TOPLEFT", frameRefs[1], "BOTTOMLEFT", 0, -4)
        else
            cb:SetPoint("TOPLEFT", frameRefs[i - 1], "TOPLEFT", 96, 0)
        end
        frameRefs[i] = cb
        frameCheckboxes[opt.key] = cb
    end

    local specLabel = buffOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    specLabel:SetPoint("TOPLEFT", frameRefs[4], "BOTTOMLEFT", 4, -10)
    specLabel:SetText("Specs to load in:")

    specFixedText = buffOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    specFixedText:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -8)
    specFixedText:SetWidth(420)
    specFixedText:SetJustifyH("LEFT")
    specFixedText:SetTextColor(0.68, 0.68, 0.68)
    specFixedText:Hide()

    local allSpecOptions = {
        { specID = 0, label = "All specs" },
        { specID = 256, label = "Discipline Priest" },
        { specID = 257, label = "Holy Priest" },
        { specID = 65, label = "Holy Paladin" },
        { specID = 105, label = "Restoration Druid" },
        { specID = 264, label = "Restoration Shaman" },
        { specID = 270, label = "Mistweaver Monk" },
    }

    for _, opt in ipairs(allSpecOptions) do
        local cb = MakeCheckbox(buffOptions, opt.label, 0, 0,
            function()
                local profile = getSelectedProfile()
                if not profile then return false end
                if opt.specID == 0 then
                    return profile.allSpecs == true
                end
                return profile.specs and (profile.specs[opt.specID] == true or profile.specs[tostring(opt.specID)] == true)
            end,
            function(val)
                local profile = getSelectedProfile()
                if not profile then return end

                if opt.specID == 0 then
                    profile.allSpecs = val == true
                else
                    if type(profile.specs) ~= "table" then profile.specs = {} end
                    profile.specs[opt.specID] = val == true or nil
                    profile.allSpecs = false
                    if profileAllSpecsCB then profileAllSpecsCB:SetChecked(false) end
                end

                addon:NotifyFeature("buffHealthColor")
            end
        )
        cb:ClearAllPoints()
        cb:Hide()

        specRefs[opt.specID] = cb
        if opt.specID == 0 then
            profileAllSpecsCB = cb
        else
            specCheckboxes[opt.specID] = cb
        end
    end

    refreshSpecControls = function(key, profile)
        for _, cb in pairs(specRefs) do
            cb:Hide()
            cb:ClearAllPoints()
        end
        if specFixedText then specFixedText:Hide() end
        if not profile then return end

        local choices, allowAll = getSpecChoices(key, profile)
        if not allowAll then
            profile.allSpecs = false
        end

        if not allowAll and #choices == 1 then
            local specID = choices[1].specID
            if type(profile.specs) ~= "table" then profile.specs = {} end
            profile.specs[specID] = true
            specFixedText:SetText("Loads in: " .. choices[1].label)
            specFixedText:Show()
            return
        end

        local visibleRefs = {}
        for _, opt in ipairs(choices) do
            local cb = specRefs[opt.specID]
            if cb then
                local visibleIndex = #visibleRefs + 1
                cb:Show()
                cb:SetChecked(opt.specID == 0 and profile.allSpecs == true or profile.specs and (profile.specs[opt.specID] == true or profile.specs[tostring(opt.specID)] == true))
                if visibleIndex == 1 then
                    cb:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", -4, -6)
                elseif (visibleIndex - 1) % 3 == 0 then
                    cb:SetPoint("TOPLEFT", visibleRefs[visibleIndex - 3], "BOTTOMLEFT", 0, -4)
                else
                    cb:SetPoint("TOPLEFT", visibleRefs[visibleIndex - 1], "TOPLEFT", 136, 0)
                end
                table.insert(visibleRefs, cb)
            end
        end
    end

    local customActionRow = CreateFrame("Frame", nil, buffOptions)
    customActionRow:SetSize(430, 24)
    customActionRow:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -88)

    removeBtn = CreateFrame("Button", nil, customActionRow, "UIPanelButtonTemplate")
    removeBtn:SetSize(72, 22)
    removeBtn:SetPoint("TOPLEFT", customActionRow, "TOPLEFT", 0, 0)
    removeBtn:SetText("Remove")
    local removeSkin = ElvSkin()
    if removeSkin then removeSkin:HandleButton(removeBtn) end

    removeBtn:SetScript("OnClick", function()
        local db = ensureBuffDb()
        if not db or not db.selectedBuff or not tostring(db.selectedBuff):match("^custom:") then return end

        local selected = db.selectedBuff
        db.buffs[selected] = nil
        for i = #db.customOrder, 1, -1 do
            if db.customOrder[i] == selected then
                table.remove(db.customOrder, i)
            end
        end

        db.selectedBuff = "atonement"
        buffSelector:SetOptions(buildBuffOptions())
        refreshProfileControls()
        addon:NotifyFeature("buffHealthColor")
        FindScrollChildAndRecalc(buffOptions)
    end)

    local function updateBuffGatekeeper()
        local enabled = addon.db.buffHealthColor and addon.db.buffHealthColor.enabled == true
        SetChildrenEnabled(buffOptions, enabled)
        if not enabled then customPopup:Hide() end
        refreshProfileControls()
    end
    buffEnableCB:HookScript("OnClick", updateBuffGatekeeper)

    if not elvuiLoaded then
        buffEnableCB:Disable()
        buffEnableCB:SetAlpha(0.4)
        SetChildrenEnabled(buffOptions, false)
    end

    refreshProfileControls()
    buffCard:SetBottomWidget(customActionRow, 16)

    panel:HookScript("OnShow", function()
        if elvuiLoaded then
            updateVehicleGatekeeper()
            updateBuffGatekeeper()
        end
    end)

    return panel
end

local function BuildEditModePanel()
    local panel = CreateFrame("Frame")
    panel.name = "Edit Mode"

    local sc = MakePanelScaffold(panel, "Edit Mode", "MathWroQOL_EditModeScroll")

    local rootAnchor = CreateFrame("Frame", nil, sc)
    rootAnchor:SetSize(1, 1)
    rootAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)

    local card, content = MakeCard(
        sc,
        rootAnchor,
        "Nudge Overlay",
        "Shows arrow buttons and exact coordinates when selecting a UI element in Edit Mode. Click arrows to nudge 1 px, Shift-click for 10 px."
    )

    local nudgeCB = MakeCheckbox(content, "Enable nudge overlay", 0, 0,
        function() return addon.db.editModeNudge and addon.db.editModeNudge.enabled end,
        function(val)
            if not addon.db.editModeNudge then addon.db.editModeNudge = {} end
            addon.db.editModeNudge.enabled = val
            addon:NotifyFeature("editModeNudge")
        end
    )
    nudgeCB:ClearAllPoints()
    nudgeCB:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -2)

    local detailsContainer = CreateFrame("Frame", nil, content)
    detailsContainer:SetPoint("TOPLEFT", nudgeCB, "BOTTOMLEFT", 20, -6)
    detailsContainer:SetSize(430, 40)

    local details = detailsContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", detailsContainer, "TOPLEFT", 0, 0)
    details:SetWidth(420)
    details:SetJustifyH("LEFT")
    details:SetText("Applies while Edit Mode is active.")

    local function updateNudgeGatekeeper()
        SetChildrenEnabled(detailsContainer, addon.db.editModeNudge and addon.db.editModeNudge.enabled == true)
    end
    nudgeCB:HookScript("OnClick", updateNudgeGatekeeper)

    card:SetBottomWidget(detailsContainer, 10)

    panel:HookScript("OnShow", updateNudgeGatekeeper)

    return panel
end

local function BuildDebugPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Debug"

    local sc = MakePanelScaffold(panel, "Debug", "MathWroQOL_DebugScroll")

    local rootAnchor = CreateFrame("Frame", nil, sc)
    rootAnchor:SetSize(1, 1)
    rootAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)

    local card, content = MakeCard(
        sc,
        rootAnchor,
        "Buff Health Color",
        "Prints diagnostic details for the selected unit token to the chat frame."
    )

    local buttons = CreateFrame("Frame", nil, content)
    buttons:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -2)
    buttons:SetSize(430, 56)

    local units = {
        { label = "Target", unit = "target" },
        { label = "Party 1", unit = "party1" },
        { label = "Raid 1", unit = "raid1" },
        { label = "Player", unit = "player" },
    }

    local function runBuffDebug(unit)
        if addon.DebugBuffHealthColor then
            addon.DebugBuffHealthColor(unit)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MQOL BuffHealth:|r diagnostic unavailable; BuffHealthColor did not finish loading")
        else
            print("MQOL BuffHealth: diagnostic unavailable; BuffHealthColor did not finish loading")
        end
    end

    local S = ElvSkin()
    local firstButton
    for i, option in ipairs(units) do
        local btn = CreateFrame("Button", nil, buttons, "UIPanelButtonTemplate")
        btn:SetSize(92, 22)
        btn:SetText(option.label)
        if S then S:HandleButton(btn) end
        if i == 1 then
            btn:SetPoint("TOPLEFT", buttons, "TOPLEFT", 0, 0)
            firstButton = btn
        else
            btn:SetPoint("LEFT", firstButton, "LEFT", (i - 1) * 100, 0)
        end
        btn:SetScript("OnClick", function()
            runBuffDebug(option.unit)
        end)
    end

    card:SetBottomWidget(buttons, 10)

    local vehicleCard, vehicleContent = MakeCard(
        sc,
        card,
        "Vehicle Bar",
        "Prints ElvUI action bar, vehicle state, and action slot diagnostics to the chat frame."
    )

    local vehicleButtons = CreateFrame("Frame", nil, vehicleContent)
    vehicleButtons:SetPoint("TOPLEFT", vehicleContent, "TOPLEFT", 12, -2)
    vehicleButtons:SetSize(430, 28)

    local function runVehicleDebug(message)
        if addon.DebugVehicleBar then
            addon.DebugVehicleBar(message)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99MQOL Vehicle:|r diagnostic unavailable; VehicleBar did not finish loading")
        else
            print("MQOL Vehicle: diagnostic unavailable; VehicleBar did not finish loading")
        end
    end

    local vehicleStateBtn = CreateFrame("Button", nil, vehicleButtons, "UIPanelButtonTemplate")
    vehicleStateBtn:SetSize(120, 22)
    vehicleStateBtn:SetPoint("TOPLEFT", vehicleButtons, "TOPLEFT", 0, 0)
    vehicleStateBtn:SetText("Print State")
    if S then S:HandleButton(vehicleStateBtn) end
    vehicleStateBtn:SetScript("OnClick", function()
        runVehicleDebug("button")
    end)

    local vehicleWatchBtn = CreateFrame("Button", nil, vehicleButtons, "UIPanelButtonTemplate")
    vehicleWatchBtn:SetSize(130, 22)
    vehicleWatchBtn:SetPoint("LEFT", vehicleStateBtn, "RIGHT", 8, 0)
    vehicleWatchBtn:SetText("Toggle Watch")
    if S then S:HandleButton(vehicleWatchBtn) end
    vehicleWatchBtn:SetScript("OnClick", function()
        runVehicleDebug("watch")
    end)

    vehicleCard:SetBottomWidget(vehicleButtons, 10)

    return panel
end

local function BuildCombatTrackerPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Combat Tracker"

    local sc = MakePanelScaffold(panel, "Combat Tracker", "MathWroQOL_CTScroll")

    local refreshFns = {}

    local rootAnchor = CreateFrame("Frame", nil, sc)
    rootAnchor:SetSize(1, 1)
    rootAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)

    local topCard, topContent = MakeCard(
        sc,
        rootAnchor,
        "Combat Tracker",
        "Track racials, trinkets, and consumables with fully configurable icon groups."
    )

    local enableCB = MakeCheckbox(topContent, "Enable Combat Tracker", 0, 0,
        function() return addon.db.combatTracker.enabled end,
        function(val)
            addon.db.combatTracker.enabled = val
            addon:NotifyFeature("combatTracker")
        end
    )
    enableCB:ClearAllPoints()
    enableCB:SetPoint("TOPLEFT", topContent, "TOPLEFT", 12, -2)

    local resetBtn = CreateFrame("Button", nil, topContent, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 22)
    resetBtn:SetPoint("TOPLEFT", enableCB, "BOTTOMLEFT", 20, -8)
    resetBtn:SetText("Reset Positions")
    local S = ElvSkin()
    if S then S:HandleButton(resetBtn) end
    resetBtn:SetScript("OnClick", function()
        local defaults = {
            racials     = { point = "CENTER", x = -220, y = 200 },
            trinkets    = { point = "CENTER", x = 0, y = 200 },
            consumables = { point = "CENTER", x = 220, y = 200 },
        }
        for key, def in pairs(defaults) do
            local f = addon.db.combatTracker.frames[key]
            f.point = def.point
            f.x = def.x
            f.y = def.y
        end
        addon:NotifyFeature("combatTracker")
    end)

    local topSep = MakeSeparator(topContent, resetBtn, -10)
    topCard:SetBottomWidget(topSep, 10)

    local trackerBody = CreateFrame("Frame", nil, sc)
    trackerBody:SetPoint("TOPLEFT", topCard, "BOTTOMLEFT", 0, -12)
    trackerBody:SetSize(500, 2200)

    local LAYOUT_OPTIONS = {
        { label = "Horizontal", value = "horizontal" },
        { label = "Vertical", value = "vertical" },
        { label = "Grid", value = "grid" },
    }

    local STACK_FONT_OPTIONS = {
        { label = "Friz Quadrata (Default)", value = "Fonts\\FRIZQT__.TTF" },
        { label = "Arial Narrow", value = "Fonts\\ARIALN.TTF" },
        { label = "Morpheus", value = "Fonts\\MORPHEUS.TTF" },
        { label = "Skurri", value = "Fonts\\skurri.TTF" },
    }

    local GROW_DIR_OPTIONS = {
        { label = "Grow Right", value = "growRight" },
        { label = "Grow Left", value = "growLeft" },
        { label = "Grow Down", value = "growDown" },
        { label = "Grow Up", value = "growUp" },
        { label = "Center Horiz.", value = "centerH" },
        { label = "Center Vert.", value = "centerV" },
    }

    local DROPDOWN_X = 120
    local ROW_SPACING = 10
    local GROUP_SPACING = 16

    local function MakeOptionRow(parent, labelText, controlFn)
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(24)
        row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

        local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetText(labelText)

        local control = controlFn(row)
        if control then
            control:ClearAllPoints()
            control:SetPoint("LEFT", row, "LEFT", DROPDOWN_X, 0)
        end

        row.label = lbl
        row.control = control
        return row
    end

    local function BuildSectionBlock(section, key, sectionTitle, extraFn)
        local content = section.content

        local secEnabledCB = MakeCheckbox(content, "Enable", 0, 0,
            function() return addon.db.combatTracker.frames[key].enabled end,
            function(val)
                addon.db.combatTracker.frames[key].enabled = val
                addon:NotifyFeature("combatTracker")
            end
        )
        secEnabledCB:ClearAllPoints()
        secEnabledCB:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)

        local gated = CreateFrame("Frame", nil, content)
        gated:SetPoint("TOPLEFT", secEnabledCB, "BOTTOMLEFT", 16, -ROW_SPACING)
        gated:SetPoint("RIGHT", content, "RIGHT", -8, 0)
        gated:SetHeight(1)

        local function recalcGatedHeight()
            local top = gated:GetTop()
            if not top then return end
            local lowest = top
            for _, child in pairs({ gated:GetChildren() }) do
                if child:IsShown() then
                    local b = child:GetBottom()
                    if b and b < lowest then lowest = b end
                end
            end
            gated:SetHeight(math.max(1, (top - lowest) + 8))
        end

        -- ── Merge & Layout ──
        local mergeRow, layoutRow, gridRow, growDirRow, sizeSep

        local function updateLayoutVisibility()
            local merged = (addon.db.combatTracker.frames[key].mergeInto or "none") ~= "none"
            local isGrid = addon.db.combatTracker.frames[key].layout == "grid"

            if merged then
                layoutRow:Hide()
                layoutRow:SetHeight(0.001)
                gridRow:Hide()
                gridRow:SetHeight(0.001)
                growDirRow:Hide()
                growDirRow:SetHeight(0.001)
                sizeSep:ClearAllPoints()
                sizeSep:SetPoint("RIGHT", gated, "RIGHT", 0, 0)
                sizeSep:SetPoint("TOPLEFT", mergeRow, "BOTTOMLEFT", 0, -GROUP_SPACING)
            else
                layoutRow:SetHeight(24)
                layoutRow:Show()
                layoutRow:ClearAllPoints()
                layoutRow:SetPoint("RIGHT", gated, "RIGHT", 0, 0)
                layoutRow:SetPoint("TOPLEFT", mergeRow, "BOTTOMLEFT", 0, -ROW_SPACING)

                if isGrid then
                    gridRow:SetHeight(24)
                    gridRow:Show()
                else
                    gridRow:Hide()
                    gridRow:SetHeight(0.001)
                end

                growDirRow:SetHeight(24)
                growDirRow:Show()
                growDirRow:ClearAllPoints()
                growDirRow:SetPoint("RIGHT", gated, "RIGHT", 0, 0)
                growDirRow:SetPoint("TOPLEFT", isGrid and gridRow or layoutRow, "BOTTOMLEFT", 0, -ROW_SPACING)

                sizeSep:ClearAllPoints()
                sizeSep:SetPoint("RIGHT", gated, "RIGHT", 0, 0)
                sizeSep:SetPoint("TOPLEFT", growDirRow, "BOTTOMLEFT", 0, -GROUP_SPACING)
            end
            C_Timer.After(0, function()
                recalcGatedHeight()
                section:UpdateLayout()
                FindScrollChildAndRecalc(section)
            end)
        end

        local mergeOptions = { { label = "Standalone", value = "none" } }
        local sectionNames = { racials = "Racials", trinkets = "Trinkets", consumables = "Consumables" }
        for _, other in ipairs({ "racials", "trinkets", "consumables" }) do
            if other ~= key then
                table.insert(mergeOptions, { label = "-> " .. sectionNames[other], value = other })
            end
        end
        mergeRow = MakeOptionRow(gated, "Merge into:", function(row)
            local btn = MakeDropdown(row, mergeOptions,
                function()
                    return addon.db.combatTracker.frames[key].mergeInto or "none"
                end,
                function(val)
                    addon.db.combatTracker.frames[key].mergeInto = (val == "none") and nil or val
                    updateLayoutVisibility()
                    addon:NotifyFeature("combatTracker")
                end
            )
            table.insert(refreshFns, function() btn:Refresh() end)
            return btn
        end)
        mergeRow:SetPoint("TOPLEFT", gated, "TOPLEFT", 0, 0)

        layoutRow = MakeOptionRow(gated, "Layout:", function(row)
            local btn = MakeDropdown(row, LAYOUT_OPTIONS,
                function() return addon.db.combatTracker.frames[key].layout end,
                function(val)
                    addon.db.combatTracker.frames[key].layout = val
                    updateLayoutVisibility()
                    addon:NotifyFeature("combatTracker")
                end
            )
            table.insert(refreshFns, function() btn:Refresh() end)
            return btn
        end)
        layoutRow:SetPoint("TOPLEFT", mergeRow, "BOTTOMLEFT", 0, -ROW_SPACING)

        local COLS_OPTIONS = {}
        for i = 2, 5 do
            table.insert(COLS_OPTIONS, { label = tostring(i), value = i })
        end
        gridRow = MakeOptionRow(gated, "Icons per row:", function(row)
            local btn = MakeDropdown(row, COLS_OPTIONS,
                function() return addon.db.combatTracker.frames[key].gridCols end,
                function(val)
                    addon.db.combatTracker.frames[key].gridCols = val
                    addon:NotifyFeature("combatTracker")
                end
            )
            table.insert(refreshFns, function() btn:Refresh() end)
            return btn
        end)
        gridRow:SetPoint("TOPLEFT", layoutRow, "BOTTOMLEFT", 0, -ROW_SPACING)

        growDirRow = MakeOptionRow(gated, "Anchor direction:", function(row)
            local btn = MakeDropdown(row, GROW_DIR_OPTIONS,
                function() return addon.db.combatTracker.frames[key].growDirection or "growRight" end,
                function(val)
                    addon.db.combatTracker.frames[key].growDirection = val
                    addon:NotifyFeature("combatTracker")
                end
            )
            table.insert(refreshFns, function() btn:Refresh() end)
            return btn
        end)
        growDirRow:SetPoint("TOPLEFT", gridRow, "BOTTOMLEFT", 0, -ROW_SPACING)

        -- ── Icon Size ──
        sizeSep = MakeSeparator(gated, growDirRow, -GROUP_SPACING)

        updateLayoutVisibility()

        local widthSlider = MakeSliderWithInput(gated, "Icon Width (px)", 16, 80,
            function() return addon.db.combatTracker.frames[key].iconWidth end,
            function(val)
                addon.db.combatTracker.frames[key].iconWidth = val
                addon:NotifyFeature("combatTracker")
            end
        )
        widthSlider:SetPoint("TOPLEFT", sizeSep, "BOTTOMLEFT", 0, -GROUP_SPACING)
        table.insert(refreshFns, function() widthSlider:Refresh() end)

        local heightSlider = MakeSliderWithInput(gated, "Icon Height (px)", 16, 80,
            function() return addon.db.combatTracker.frames[key].iconHeight end,
            function(val)
                addon.db.combatTracker.frames[key].iconHeight = val
                addon:NotifyFeature("combatTracker")
            end
        )
        heightSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -4)
        table.insert(refreshFns, function() heightSlider:Refresh() end)

        -- ── Stack Counter ──
        local stackSep = MakeSeparator(gated, heightSlider, -GROUP_SPACING)

        local stackEnabledCB = MakeCheckbox(gated, "Show stack counter on icons", 0, 0,
            function() return addon.db.combatTracker.frames[key].stackCountEnabled ~= false end,
            function(val)
                addon.db.combatTracker.frames[key].stackCountEnabled = val
                addon:NotifyFeature("combatTracker")
            end
        )
        stackEnabledCB:ClearAllPoints()
        stackEnabledCB:SetPoint("TOPLEFT", stackSep, "BOTTOMLEFT", 0, -GROUP_SPACING)

        local stackFontSizeSlider = MakeSliderWithInput(gated, "Counter font size", 8, 24,
            function() return addon.db.combatTracker.frames[key].stackCountFontSize end,
            function(val)
                addon.db.combatTracker.frames[key].stackCountFontSize = val
                addon:NotifyFeature("combatTracker")
            end
        )
        stackFontSizeSlider:SetPoint("TOPLEFT", stackEnabledCB, "BOTTOMLEFT", 16, -ROW_SPACING)
        table.insert(refreshFns, function() stackFontSizeSlider:Refresh() end)

        local stackFontRow = MakeOptionRow(gated, "Counter font:", function(row)
            local btn = MakeDropdown(row, STACK_FONT_OPTIONS,
                function()
                    return addon.db.combatTracker.frames[key].stackCountFont or "Fonts\\FRIZQT__.TTF"
                end,
                function(val)
                    addon.db.combatTracker.frames[key].stackCountFont = val
                    addon:NotifyFeature("combatTracker")
                end
            )
            table.insert(refreshFns, function() btn:Refresh() end)
            return btn
        end)
        stackFontRow:SetPoint("TOPLEFT", stackFontSizeSlider, "BOTTOMLEFT", 0, -ROW_SPACING)

        -- ── Cooldown Counter ──
        local cdSep = MakeSeparator(gated, stackFontRow, -GROUP_SPACING)

        local cdEnabledCB = MakeCheckbox(gated, "Show cooldown countdown text", 0, 0,
            function() return addon.db.combatTracker.frames[key].cdCountEnabled ~= false end,
            function(val)
                addon.db.combatTracker.frames[key].cdCountEnabled = val
                addon:NotifyFeature("combatTracker")
            end
        )
        cdEnabledCB:ClearAllPoints()
        cdEnabledCB:SetPoint("TOPLEFT", cdSep, "BOTTOMLEFT", 0, -GROUP_SPACING)

        local cdFontSizeSlider = MakeSliderWithInput(gated, "Cooldown font size", 8, 24,
            function() return addon.db.combatTracker.frames[key].cdCountFontSize end,
            function(val)
                addon.db.combatTracker.frames[key].cdCountFontSize = val
                addon:NotifyFeature("combatTracker")
            end
        )
        cdFontSizeSlider:SetPoint("TOPLEFT", cdEnabledCB, "BOTTOMLEFT", 16, -ROW_SPACING)
        table.insert(refreshFns, function() cdFontSizeSlider:Refresh() end)

        local cdFontRow = MakeOptionRow(gated, "Cooldown font:", function(row)
            local btn = MakeDropdown(row, STACK_FONT_OPTIONS,
                function()
                    return addon.db.combatTracker.frames[key].cdCountFont or "Fonts\\FRIZQT__.TTF"
                end,
                function(val)
                    addon.db.combatTracker.frames[key].cdCountFont = val
                    addon:NotifyFeature("combatTracker")
                end
            )
            table.insert(refreshFns, function() btn:Refresh() end)
            return btn
        end)
        cdFontRow:SetPoint("TOPLEFT", cdFontSizeSlider, "BOTTOMLEFT", 0, -ROW_SPACING)

        -- ── Desaturate on Cooldown ──
        local desatSep = MakeSeparator(gated, cdFontRow, -GROUP_SPACING)

        local desatCB = MakeCheckbox(gated, "Desaturate icon on cooldown", 0, 0,
            function() return addon.db.combatTracker.frames[key].desaturateOnCD == true end,
            function(val)
                addon.db.combatTracker.frames[key].desaturateOnCD = val
                addon:NotifyFeature("combatTracker")
            end
        )
        desatCB:ClearAllPoints()
        desatCB:SetPoint("TOPLEFT", desatSep, "BOTTOMLEFT", 0, -GROUP_SPACING)

        -- ── Extra + Gatekeeper ──
        local lastWidget = desatCB
        if extraFn then
            local extraSep = MakeSeparator(gated, desatCB, -GROUP_SPACING)
            lastWidget = extraFn(gated, extraSep) or extraSep
        end

        local function updateSectionGatekeeper()
            SetChildrenEnabled(gated, addon.db.combatTracker.frames[key].enabled == true)
        end
        secEnabledCB:HookScript("OnClick", updateSectionGatekeeper)
        table.insert(refreshFns, updateSectionGatekeeper)

        section:SetContentBottom(lastWidget, 10)
        table.insert(refreshFns, function()
            recalcGatedHeight()
            section:UpdateLayout()
        end)

        return lastWidget
    end

    local racialsSection = MakeCollapsibleSection(trackerBody, "Racials", false)
    racialsSection:SetPoint("TOPLEFT", trackerBody, "TOPLEFT", 0, 0)

    local racialSpellContainer
    BuildSectionBlock(racialsSection, "racials", "RACIALS", function(parent, anchor)
        local toggleLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        toggleLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
        toggleLabel:SetText("Hide racial abilities:")

        racialSpellContainer = CreateFrame("Frame", nil, parent)
        racialSpellContainer:SetPoint("TOPLEFT", toggleLabel, "BOTTOMLEFT", 0, -6)
        racialSpellContainer:SetSize(430, 10)

        local function RebuildRacialList()
            for _, child in ipairs({ racialSpellContainer:GetChildren() }) do
                child:Hide()
                child:SetParent(nil)
            end
            for _, region in ipairs({ racialSpellContainer:GetRegions() }) do
                if region.Hide then region:Hide() end
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
            racialsSection:SetContentBottom(racialSpellContainer, 10)
        end

        table.insert(refreshFns, RebuildRacialList)
        return racialSpellContainer
    end)

    local trinketsSection = MakeCollapsibleSection(trackerBody, "Trinkets", false)
    trinketsSection:SetPoint("TOPLEFT", racialsSection, "BOTTOMLEFT", 0, -12)

    BuildSectionBlock(trinketsSection, "trinkets", "TRINKETS", function(parent, anchor)
        local onUseCB = MakeCheckbox(parent, "On-use only (hide passive trinkets)", 0, 0,
            function() return addon.db.combatTracker.frames.trinkets.onUseOnly end,
            function(val)
                addon.db.combatTracker.frames.trinkets.onUseOnly = val
                addon:NotifyFeature("combatTracker")
            end
        )
        onUseCB:ClearAllPoints()
        onUseCB:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, -10)
        return onUseCB
    end)

    local consumablesSection = MakeCollapsibleSection(trackerBody, "Consumables", false)
    consumablesSection:SetPoint("TOPLEFT", trinketsSection, "BOTTOMLEFT", 0, -12)

    BuildSectionBlock(consumablesSection, "consumables", "CONSUMABLES", function(parent, anchor)
        local hideCB = MakeCheckbox(parent, "Hide icon if not in inventory", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.hideIfMissing end,
            function(val)
                addon.db.combatTracker.frames.consumables.hideIfMissing = val
                addon:NotifyFeature("combatTracker")
            end
        )
        hideCB:ClearAllPoints()
        hideCB:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, -10)

        local typeLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        typeLabel:SetPoint("TOPLEFT", hideCB, "BOTTOMLEFT", 4, -10)
        typeLabel:SetText("Track these consumable types:")

        local combatCB = MakeCheckbox(parent, "Combat Potions", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showCombatPotions end,
            function(val)
                addon.db.combatTracker.frames.consumables.showCombatPotions = val
                addon:NotifyFeature("combatTracker")
            end
        )
        combatCB:ClearAllPoints()
        combatCB:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", -4, -6)

        local healCB = MakeCheckbox(parent, "Healing Potions", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showHealingPotions end,
            function(val)
                addon.db.combatTracker.frames.consumables.showHealingPotions = val
                addon:NotifyFeature("combatTracker")
            end
        )
        healCB:ClearAllPoints()
        healCB:SetPoint("TOPLEFT", combatCB, "TOPLEFT", 200, 0)

        local manaCB = MakeCheckbox(parent, "Mana Potions", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showManaPotions end,
            function(val)
                addon.db.combatTracker.frames.consumables.showManaPotions = val
                addon:NotifyFeature("combatTracker")
            end
        )
        manaCB:ClearAllPoints()
        manaCB:SetPoint("TOPLEFT", combatCB, "BOTTOMLEFT", 0, -4)

        local hsCB = MakeCheckbox(parent, "Healthstone", 0, 0,
            function() return addon.db.combatTracker.frames.consumables.showHealthstone end,
            function(val)
                addon.db.combatTracker.frames.consumables.showHealthstone = val
                addon:NotifyFeature("combatTracker")
            end
        )
        hsCB:ClearAllPoints()
        hsCB:SetPoint("TOPLEFT", manaCB, "TOPLEFT", 200, 0)

        -- ── Item Display Order (nested collapsible) ──
        local orderSection = MakeCollapsibleSection(parent, "Item Display Order", false)
        orderSection:ClearAllPoints()
        orderSection:SetPoint("TOPLEFT", manaCB, "BOTTOMLEFT", -8, -GROUP_SPACING)
        orderSection:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

        local orderContent = orderSection.content

        local resetBtn = CreateFrame("Button", nil, orderContent, "UIPanelButtonTemplate")
        resetBtn:SetSize(80, 20)
        resetBtn:SetText("Reset Order")
        local Sc = ElvSkin()
        if Sc then Sc:HandleButton(resetBtn) end
        resetBtn:SetPoint("TOPLEFT", orderContent, "TOPLEFT", 0, 0)

        local orderListFrame = CreateFrame("Frame", nil, orderContent)
        orderListFrame:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
        orderListFrame:SetPoint("RIGHT", orderContent, "RIGHT", 0, 0)
        orderListFrame:SetHeight(10)

        -- ── Custom Item Input ──
        local customLabel = orderContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        customLabel:SetPoint("TOPLEFT", orderListFrame, "BOTTOMLEFT", 0, -14)
        customLabel:SetText("Add custom item — enter an item ID and press Add:")

        local idBox = CreateFrame("EditBox", nil, orderContent, "InputBoxTemplate")
        idBox:SetSize(80, 20)
        idBox:SetNumeric(true)
        idBox:SetAutoFocus(false)
        idBox:SetMaxLetters(10)
        idBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -6)

        local addBtn = CreateFrame("Button", nil, orderContent, "UIPanelButtonTemplate")
        addBtn:SetSize(60, 22)
        addBtn:SetText("Add")
        local Sc2 = ElvSkin()
        if Sc2 then Sc2:HandleButton(addBtn) end
        addBtn:SetPoint("LEFT", idBox, "RIGHT", 6, 1)

        -- Bottom sentinel for height calculation
        local orderBottom = CreateFrame("Frame", nil, orderContent)
        orderBottom:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 0, -4)
        orderBottom:SetSize(1, 1)

        local orderRowPool = {}

        local function getConsumablesSec()
            return addon.combatTracker
                and addon.combatTracker.sections
                and addon.combatTracker.sections.consumables
        end

        local function getItemRank(id)
            local _, itemLink = GetItemInfo(id)
            if itemLink then
                local rank = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemLink)
                if rank then return rank end
            end
            return C_TradeSkillUI.GetItemCraftedQualityByItemInfo(id)
        end

        local function getItemCategory(id)
            local consumablesSec = getConsumablesSec()
            if not consumablesSec then return nil, getItemRank(id) end
            local IDS = consumablesSec.CONSUMABLE_IDS
            for i, cid in ipairs(IDS.combatPotions or {}) do
                if cid == id then return "Combat Potion", (i % 2 == 1) and 1 or 2 end
            end
            for i, cid in ipairs(IDS.healingPotions or {}) do
                if cid == id then return "Healing Potion", (i % 2 == 1) and 1 or 2 end
            end
            for i, cid in ipairs(IDS.manaPotions or {}) do
                if cid == id then return "Mana Potion", (i % 2 == 1) and 1 or 2 end
            end
            for _, cid in ipairs(IDS.healthstone or {}) do
                if cid == id then return "Healthstone", nil end
            end
            return "Custom", getItemRank(id)
        end

        local function ensureItemOrder()
            local frameDb = addon.db.combatTracker.frames.consumables
            if not frameDb.itemOrder or #frameDb.itemOrder == 0 then
                local sec = getConsumablesSec()
                if sec and sec.BuildDefaultOrder then
                    frameDb.itemOrder = sec.BuildDefaultOrder(frameDb)
                end
            end
            return frameDb.itemOrder or {}
        end

        local function syncItemOrder()
            local frameDb = addon.db.combatTracker.frames.consumables
            local order = frameDb.itemOrder or {}

            local tracked = {}
            local sec = getConsumablesSec()
            if sec and sec.CONSUMABLE_IDS then
                local IDS = sec.CONSUMABLE_IDS
                if frameDb.showCombatPotions then
                    for _, id in ipairs(IDS.combatPotions) do tracked[id] = true end
                end
                if frameDb.showHealingPotions then
                    for _, id in ipairs(IDS.healingPotions) do tracked[id] = true end
                end
                if frameDb.showManaPotions then
                    for _, id in ipairs(IDS.manaPotions) do tracked[id] = true end
                end
                if frameDb.showHealthstone then
                    for _, id in ipairs(IDS.healthstone) do tracked[id] = true end
                end
            end
            for id in pairs(frameDb.customItems or {}) do
                tracked[id] = true
            end

            local existing = {}
            for _, id in ipairs(order) do existing[id] = true end

            local pruned = {}
            for _, id in ipairs(order) do
                if tracked[id] then table.insert(pruned, id) end
            end

            for id in pairs(tracked) do
                if not existing[id] then table.insert(pruned, id) end
            end

            frameDb.itemOrder = pruned
            return pruned
        end

        local function updateParentHeight()
            consumablesSection:SetContentBottom(orderSection, 10)
            C_Timer.After(0, function()
                consumablesSection:UpdateLayout()
                FindScrollChildAndRecalc(consumablesSection)
            end)
        end

        local function updateOrderSectionHeight()
            orderSection:SetContentBottom(orderBottom, 4)
            C_Timer.After(0, function()
                orderSection:UpdateLayout()
                updateParentHeight()
                C_Timer.After(0, function()
                    orderSection:UpdateLayout()
                    updateParentHeight()
                end)
            end)
        end

        local function RebuildOrderList()
            for _, r in ipairs(orderRowPool) do r:Hide() end

            local order = ensureItemOrder()
            order = syncItemOrder()

            local ROW_H = 28
            local prevRow
            for idx, id in ipairs(order) do
                local row = orderRowPool[idx]
                if not row then
                    row = CreateFrame("Frame", nil, orderListFrame)
                    row:SetHeight(ROW_H)

                    local bg = row:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(1, 1, 1, 0.03)
                    row.bg = bg

                    local iconTex = row:CreateTexture(nil, "ARTWORK")
                    iconTex:SetSize(22, 22)
                    iconTex:SetPoint("LEFT", 4, 0)
                    iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    row.iconTex = iconTex

                    local removeBtn = CreateFrame("Button", nil, row)
                    removeBtn:SetSize(22, 22)
                    removeBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                    local xt = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    xt:SetAllPoints()
                    xt:SetText("\195\151")
                    xt:SetTextColor(0.8, 0.3, 0.3, 1)
                    row.removeBtn = removeBtn
                    row.removeTxt = xt

                    local useElvUI = ElvUI and ElvUI[1] and ElvUI[1].Media and ElvUI[1].Media.Textures

                    local downBtn = CreateFrame("Button", nil, row)
                    downBtn:SetSize(18, 18)
                    downBtn:SetPoint("RIGHT", removeBtn, "LEFT", 2, -5)
                    local downTex = downBtn:CreateTexture(nil, "ARTWORK")
                    downTex:SetAllPoints()
                    if useElvUI then
                        downTex:SetTexture(ElvUI[1].Media.Textures.ArrowUp)
                        downTex:SetRotation(3.14159)
                    else
                        downTex:SetAtlas("common-icon-arrow-down")
                    end
                    downBtn.tex = downTex
                    downBtn.useElvUI = useElvUI
                    downBtn:SetScript("OnEnter", function(self)
                        self.tex:SetVertexColor(1, 0.82, 0, 1)
                    end)
                    downBtn:SetScript("OnLeave", function(self)
                        self.tex:SetVertexColor(1, 1, 1, 1)
                    end)
                    row.downBtn = downBtn

                    local upBtn = CreateFrame("Button", nil, row)
                    upBtn:SetSize(18, 18)
                    upBtn:SetPoint("RIGHT", removeBtn, "LEFT", 2, 5)
                    local upTex = upBtn:CreateTexture(nil, "ARTWORK")
                    upTex:SetAllPoints()
                    if useElvUI then
                        upTex:SetTexture(ElvUI[1].Media.Textures.ArrowUp)
                    else
                        upTex:SetAtlas("common-icon-arrow-up")
                    end
                    upBtn.tex = upTex
                    upBtn:SetScript("OnEnter", function(self)
                        self.tex:SetVertexColor(1, 0.82, 0, 1)
                    end)
                    upBtn:SetScript("OnLeave", function(self)
                        self.tex:SetVertexColor(1, 1, 1, 1)
                    end)
                    row.upBtn = upBtn

                    local catFStr = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    catFStr:SetPoint("RIGHT", downBtn, "LEFT", -4, 4)
                    catFStr:SetWidth(90)
                    catFStr:SetJustifyH("RIGHT")
                    row.catFStr = catFStr

                    local rankTex = row:CreateTexture(nil, "OVERLAY")
                    rankTex:SetSize(14, 14)
                    rankTex:SetPoint("RIGHT", catFStr, "LEFT", -2, 0)
                    row.rankTex = rankTex

                    local nameFStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    nameFStr:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
                    nameFStr:SetPoint("RIGHT", rankTex, "LEFT", -4, 0)
                    nameFStr:SetJustifyH("LEFT")
                    nameFStr:SetWordWrap(false)
                    nameFStr:SetNonSpaceWrap(false)
                    row.nameFStr = nameFStr

                    table.insert(orderRowPool, row)
                end

                row:ClearAllPoints()
                if prevRow then
                    row:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, -1)
                else
                    row:SetPoint("TOPLEFT", orderListFrame, "TOPLEFT", 0, 0)
                end
                row:SetPoint("RIGHT", orderListFrame, "RIGHT", 0, 0)

                if idx % 2 == 0 then
                    row.bg:SetColorTexture(1, 1, 1, 0.05)
                else
                    row.bg:SetColorTexture(1, 1, 1, 0.02)
                end

                local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(id)
                if itemIcon then
                    row.iconTex:SetTexture(itemIcon)
                else
                    row.iconTex:SetTexture(134400)
                    C_Item.RequestLoadItemDataByID(id)
                end
                row.nameFStr:SetText(itemName or ("Item #" .. id))

                local cat, rank = getItemCategory(id)
                row.catFStr:SetText(cat or "")

                if rank then
                    row.rankTex:SetAtlas("Professions-Icon-Quality-12-Tier" .. rank .. "-Small", true)
                    row.rankTex:Show()
                else
                    row.rankTex:Hide()
                end

                local isCustom = (cat == "Custom")
                if isCustom then
                    row.removeBtn:Show()
                    row.removeTxt:Show()
                else
                    row.removeBtn:Hide()
                    row.removeTxt:Hide()
                end

                local capturedIdx = idx
                local capturedID = id
                row.upBtn:SetScript("OnClick", function()
                    if capturedIdx <= 1 then return end
                    local o = addon.db.combatTracker.frames.consumables.itemOrder
                    o[capturedIdx], o[capturedIdx - 1] = o[capturedIdx - 1], o[capturedIdx]
                    addon:NotifyFeature("combatTracker")
                    RebuildOrderList()
                end)
                row.downBtn:SetScript("OnClick", function()
                    local o = addon.db.combatTracker.frames.consumables.itemOrder
                    if capturedIdx >= #o then return end
                    o[capturedIdx], o[capturedIdx + 1] = o[capturedIdx + 1], o[capturedIdx]
                    addon:NotifyFeature("combatTracker")
                    RebuildOrderList()
                end)
                row.removeBtn:SetScript("OnClick", function()
                    addon.db.combatTracker.frames.consumables.customItems[capturedID] = nil
                    local o = addon.db.combatTracker.frames.consumables.itemOrder
                    table.remove(o, capturedIdx)
                    addon:NotifyFeature("combatTracker")
                    RebuildOrderList()
                end)

                row.upBtn:SetShown(idx > 1)
                row.downBtn:SetShown(idx < #order)

                row:Show()
                prevRow = row
            end

            local listH = math.max(#order * (ROW_H + 1), 10)
            orderListFrame:SetHeight(listH)

            updateOrderSectionHeight()
        end

        resetBtn:SetScript("OnClick", function()
            local sec = getConsumablesSec()
            if sec and sec.BuildDefaultOrder then
                local frameDb = addon.db.combatTracker.frames.consumables
                frameDb.itemOrder = sec.BuildDefaultOrder(frameDb)
                addon:NotifyFeature("combatTracker")
                RebuildOrderList()
            end
        end)

        addBtn:SetScript("OnClick", function()
            local id = tonumber(idBox:GetText())
            if id and id > 0 then
                addon.db.combatTracker.frames.consumables.customItems[id] = true
                idBox:SetText("")
                idBox:ClearFocus()
                local o = addon.db.combatTracker.frames.consumables.itemOrder
                if o then table.insert(o, id) end
                addon:NotifyFeature("combatTracker")
                RebuildOrderList()
            end
        end)
        idBox:SetScript("OnEnterPressed", function() addBtn:Click() end)

        local function onCategoryToggle()
            syncItemOrder()
            addon:NotifyFeature("combatTracker")
            RebuildOrderList()
        end
        combatCB:HookScript("OnClick", onCategoryToggle)
        healCB:HookScript("OnClick", onCategoryToggle)
        manaCB:HookScript("OnClick", onCategoryToggle)
        hsCB:HookScript("OnClick", onCategoryToggle)

        local infoFrame = CreateFrame("Frame")
        infoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        infoFrame:SetScript("OnEvent", function()
            if orderListFrame:IsVisible() then RebuildOrderList() end
        end)

        table.insert(refreshFns, function()
            if orderSection._expanded then
                RebuildOrderList()
            end
        end)
        orderSection.header:HookScript("OnClick", function()
            if orderSection._expanded then
                RebuildOrderList()
            else
                updateParentHeight()
            end
        end)
        return orderSection
    end)

    local masqueCard, masqueContent = MakeCard(
        trackerBody,
        consumablesSection,
        "Masque",
        "Optional icon skinning integration for Combat Tracker groups."
    )

    local MSQ = LibStub and LibStub("Masque", true)
    local masqueLastWidget
    if MSQ then
        local masqueCB = MakeCheckbox(masqueContent, "Enable Masque skinning", 0, 0,
            function() return addon.db.combatTracker.masque.enabled end,
            function(val)
                addon.db.combatTracker.masque.enabled = val
                addon:NotifyFeature("combatTracker")
            end
        )
        masqueCB:ClearAllPoints()
        masqueCB:SetPoint("TOPLEFT", masqueContent, "TOPLEFT", 12, -2)

        local masqueNote = masqueContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        masqueNote:SetPoint("TOPLEFT", masqueCB, "BOTTOMLEFT", 4, -8)
        masqueNote:SetWidth(450)
        masqueNote:SetJustifyH("LEFT")
        masqueNote:SetText("When enabled, three groups appear in the Masque addon UI under MathWroQOL: CT Racials, CT Trinkets, CT Consumables.")
        masqueLastWidget = masqueNote
    else
        local masqueNote = masqueContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        masqueNote:SetPoint("TOPLEFT", masqueContent, "TOPLEFT", 12, -4)
        masqueNote:SetTextColor(0.5, 0.5, 0.5)
        masqueNote:SetText("Masque skinning: install the Masque addon to enable icon skinning.")
        masqueLastWidget = masqueNote
    end
    masqueCard:SetBottomWidget(masqueLastWidget, 12)

    local function updateTrackerGatekeeper()
        SetChildrenEnabled(trackerBody, addon.db.combatTracker.enabled == true)
    end
    enableCB:HookScript("OnClick", updateTrackerGatekeeper)

    panel:HookScript("OnShow", function()
        C_Timer.After(0, function()
            for _, fn in ipairs(refreshFns) do fn() end
            updateTrackerGatekeeper()
            racialsSection:UpdateLayout()
            trinketsSection:UpdateLayout()
            consumablesSection:UpdateLayout()
        end)
    end)

    return panel
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 ~= "MathWroQOL" then return end
    self:UnregisterEvent("ADDON_LOADED")

    local parentPanel = BuildParentPanel()
    local generalPanel = BuildGeneralPanel()
    local combatLogPanel = BuildCombatLogPanel()
    local combatTrackerPanel = BuildCombatTrackerPanel()
    local elvuiPanel = BuildElvUIPanel()
    local editModePanel = BuildEditModePanel()
    local debugPanel = BuildDebugPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local parentCat = Settings.RegisterCanvasLayoutCategory(parentPanel, parentPanel.name)
        local generalCat = Settings.RegisterCanvasLayoutSubcategory(parentCat, generalPanel, generalPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, combatLogPanel, combatLogPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, combatTrackerPanel, combatTrackerPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, elvuiPanel, elvuiPanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, editModePanel, editModePanel.name)
        Settings.RegisterCanvasLayoutSubcategory(parentCat, debugPanel, debugPanel.name)
        Settings.RegisterAddOnCategory(parentCat)

        SLASH_MQOL1 = "/mqol"
        SlashCmdList["MQOL"] = function()
            Settings.OpenToCategory(generalCat:GetID())
        end
    else
        InterfaceOptions_AddCategory(parentPanel)
        InterfaceOptions_AddCategory(generalPanel, parentPanel)
        InterfaceOptions_AddCategory(combatLogPanel, parentPanel)
        InterfaceOptions_AddCategory(combatTrackerPanel, parentPanel)
        InterfaceOptions_AddCategory(elvuiPanel, parentPanel)
        InterfaceOptions_AddCategory(editModePanel, parentPanel)
        InterfaceOptions_AddCategory(debugPanel, parentPanel)

        SLASH_MQOL1 = "/mqol"
        SlashCmdList["MQOL"] = function()
            InterfaceOptionsFrame_OpenToCategory(generalPanel)
        end
    end
end)
