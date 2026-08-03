local _, addon = ...

local CDMButton = { name = "cdmButton" }
addon:RegisterFeature(CDMButton)

-- The button widget, created once and reused.
local btn
local ellesmereStyled = false
local exactEllesmereStyle = false
local nativeArt = {}
local positionPending = false
local ellesmereInset
local ellesmereBackground
local ellesmereHighlight

local function openCDM()
    if CooldownViewerSettings then
        CooldownViewerSettings:Show()
    end
end
local function keepNativeTextureHidden(texture)
    if not texture or nativeArt[texture] then return end
    nativeArt[texture] = true
    texture:SetAlpha(0)
    hooksecurefunc(texture, "SetAlpha", function(self, alpha)
        if alpha and alpha > 0 then
            self:SetAlpha(0)
        end
    end)
end

local function suppressNativeButtonArt()
    if not ellesmereStyled or not btn then return end

    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        keepNativeTextureHidden(btn[key])
    end
    for _, getter in ipairs({
        "GetNormalTexture",
        "GetPushedTexture",
        "GetDisabledTexture",
        "GetHighlightTexture",
    }) do
        keepNativeTextureHidden(btn[getter] and btn[getter](btn))
    end

    if exactEllesmereStyle then
        for index = 1, select("#", btn:GetRegions()) do
            local region = select(index, btn:GetRegions())
            if region ~= ellesmereHighlight and region:IsObjectType("Texture") then
                keepNativeTextureHidden(region)
            end
        end
    end
end

local function refreshExactEllesmereStyle()
    if not ellesmereInset or not ellesmereBackground then return end

    local db = _G.EllesmereUIDB
    local color = db and db.popupMenuButtonBackgroundColor
        or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    ellesmereBackground:SetColorTexture(
        color.r,
        color.g,
        color.b,
        color.a == nil and 0.8 or color.a
    )
    if EllesmereUI and EllesmereUI._applyBlizzardConfiguredBorder then
        EllesmereUI._applyBlizzardConfiguredBorder(
            ellesmereInset,
            "popupMenuButton",
            1
        )
    end
end

local function applyExactEllesmereStyle()
    if not btn or not EllesmereUI
        or not EllesmereUI._applyBlizzardConfiguredBorder
    then
        return false
    end

    ellesmereStyled = true
    exactEllesmereStyle = true
    suppressNativeButtonArt()

    ellesmereInset = CreateFrame("Frame", nil, btn)
    ellesmereInset:SetPoint("TOPLEFT", 2, -2)
    ellesmereInset:SetPoint("BOTTOMRIGHT", -2, 2)
    ellesmereInset:SetFrameLevel(btn:GetFrameLevel())
    ellesmereBackground = ellesmereInset:CreateTexture(
        nil,
        "BACKGROUND",
        nil,
        -6
    )
    ellesmereBackground:SetAllPoints()

    ellesmereHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
    ellesmereHighlight:SetAllPoints(ellesmereInset)
    ellesmereHighlight:SetColorTexture(1, 1, 1, 0.1)
    refreshExactEllesmereStyle()
    return true
end

local function refreshEllesmereStyleSafely()
    if not ellesmereInset then return end
    if securecallfunction then
        securecallfunction(refreshExactEllesmereStyle)
    else
        refreshExactEllesmereStyle()
    end
end

-- Queued from GameMenuFrame.Layout so every provider's own layout hook finishes
-- before MathWroQOL inserts its button.
local function findMenuAnchors()
    if not GameMenuFrame.buttonPool then return nil, nil, {} end

    local pooled = {}
    local storeButton, optionsButton, addonsButton
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        pooled[button] = true
        local text = button:GetText()
        if text == _G.BLIZZARD_STORE then
            storeButton = button
        elseif text == _G.GAMEMENU_OPTIONS then
            optionsButton = button
        elseif text == _G.ADDONS then
            addonsButton = button
        end
    end

    local baseButton = storeButton or optionsButton
    if not baseButton then return nil, addonsButton, pooled end
    if addonsButton then return baseButton, addonsButton, pooled end

    -- Fallback for clients without an AddOns entry: use the nearest pooled
    -- button below the insertion anchor as the lower layout boundary.
    local baseBottom = baseButton:GetBottom()
    local boundaryTop
    if baseBottom then
        for button in pairs(pooled) do
            local top = button:GetTop()
            if top and top < baseBottom + 2 and (not boundaryTop or top > boundaryTop) then
                addonsButton = button
                boundaryTop = top
            end
        end
    end
    return baseButton, addonsButton, pooled
end

local function findLowestCustomButton(baseButton, boundaryButton, pooled)
    local baseBottom = baseButton:GetBottom()
    local baseWidth = baseButton:GetWidth()
    if not baseBottom or not baseWidth or baseWidth <= 0 then return baseButton end

    local boundaryTop = boundaryButton and boundaryButton:GetTop()
    local baseCenter = baseButton:GetCenter()
    local anchorButton = baseButton
    local anchorBottom = baseBottom
    for _, child in ipairs({ GameMenuFrame:GetChildren() }) do
        if child ~= btn and not pooled[child] and child:IsShown()
            and child.IsObjectType and child:IsObjectType("Button")
        then
            local top = child:GetTop()
            local bottom = child:GetBottom()
            local width = child:GetWidth()
            local height = child:GetHeight()
            local center = child:GetCenter()
            local aligned = not baseCenter or not center
                or math.abs(center - baseCenter) <= baseWidth * 0.35
            if top and bottom and width and height and height > 10
                and width >= baseWidth * 0.6 and aligned
                and top <= baseBottom + 2
                and (not boundaryTop or top > boundaryTop)
                and bottom < anchorBottom
            then
                anchorButton = child
                anchorBottom = bottom
            end
        end
    end
    return anchorButton
end

local function matchMenuButtonStyle(sourceButton)
    local source = sourceButton and sourceButton:GetFontString()
    local target = btn and btn:GetFontString()
    if not source or not target then return end

    local sourcePath, sourceSize, sourceFlags = source:GetFont()
    local targetPath, _, targetFlags = target:GetFont()
    if not sourceSize or not targetPath then return end

    local exclusiveProvider = (ElvUI and not EllesmereUI)
        or (EllesmereUI and not ElvUI)
    if exclusiveProvider then
        target:SetFont(sourcePath or targetPath, sourceSize, sourceFlags or "")
        if source.GetTextColor and target.SetTextColor then
            target:SetTextColor(source:GetTextColor())
        end
        if source.GetShadowColor and target.SetShadowColor then
            target:SetShadowColor(source:GetShadowColor())
        end
        if source.GetShadowOffset and target.SetShadowOffset then
            target:SetShadowOffset(source:GetShadowOffset())
        end
        if source.GetSpacing and target.SetSpacing then
            target:SetSpacing(source:GetSpacing())
        end
        if source.GetJustifyH and target.SetJustifyH then
            target:SetJustifyH(source:GetJustifyH())
        end
        if source.GetJustifyV and target.SetJustifyV then
            target:SetJustifyV(source:GetJustifyV())
        end
    else
        -- With both or neither suite active, preserve the native face and
        -- effects while matching only the surrounding label size.
        target:SetFont(targetPath, sourceSize, targetFlags or "")
    end
end

local function isCDMEnabled()
    local db = addon.db and addon.db.cdmButton
    return db and db.enabled
end

local function positionCDMButton()
    if not btn then return end
    if not isCDMEnabled() then
        btn:Hide()
        return
    end

    local baseButton, boundaryButton, pooled = findMenuAnchors()
    if not baseButton then
        btn:Show()
        return
    end

    -- Discover custom buttons by geometry rather than addon-specific names.
    -- The lowest visible menu-sized button between Shop/Options and AddOns is
    -- the end of the current custom-button chain.
    local anchorButton = findLowestCustomButton(baseButton, boundaryButton, pooled)
    local anchorIsCustom = anchorButton ~= baseButton
    local gap = anchorIsCustom and 4 or 10

    local width, height = baseButton:GetSize()
    if width and width > 0 then
        btn:SetSize(width, height or 35)
    end
    matchMenuButtonStyle(boundaryButton or baseButton)
    btn:ClearAllPoints()
    btn:SetPoint("TOP", anchorButton, "BOTTOM", 0, -gap)
    suppressNativeButtonArt()
    refreshEllesmereStyleSafely()
    btn:Show()

    -- Move only the pooled section at and below AddOns, and only as far as
    -- necessary to maintain the same gap below CDM. Existing custom-button
    -- spacing remains untouched.
    local shift = 0
    local boundaryTop = boundaryButton and boundaryButton:GetTop()
    local buttonBottom = btn:GetBottom()
    if boundaryTop and buttonBottom then
        shift = math.max(0, math.ceil(boundaryTop - (buttonBottom - gap)))
    end
    if shift > 0 then
        for button in pairs(pooled) do
            local top = button:GetTop()
            if top and top <= boundaryTop + 1 then
                local point, relativeTo, relativePoint, x, y = button:GetPoint()
                if point then
                    button:ClearAllPoints()
                    button:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) - shift)
                end
            end
        end
        GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + shift)
    end
end

local function queuePositionCDMButton()
    if not btn or not isCDMEnabled() then return end

    -- Hide our stale position while other extensions discover and arrange
    -- their buttons. Otherwise two geometry-based integrations can anchor to
    -- each other and drift farther down on every menu open.
    btn:Hide()
    if positionPending then return end
    positionPending = true
    C_Timer.After(0, function()
        C_Timer.After(0, function()
            positionPending = false
            positionCDMButton()
        end)
    end)
end

function CDMButton:Apply()
    if not btn then return end
    if isCDMEnabled() then
        btn:Show()
        if GameMenuFrame:IsShown() then
            queuePositionCDMButton()
        end
    else
        btn:Hide()
    end
end

function CDMButton:Initialize()

    -- Use Retail's native game menu button template.
    btn = CreateFrame("Button", "MathWroQOL_CDMButton", GameMenuFrame, "MainMenuFrameButtonTemplate")
    btn:SetSize(200, 35)
    btn:SetText("CDM")
    btn:SetScript("OnClick", function()
        HideUIPanel(GameMenuFrame)
        openCDM()
    end)

    -- Hide immediately on show/layout so other geometry-based integrations do
    -- not discover CDM's stale position. The deferred pass restores it.
    if not GameMenuFrame._mqolCDMHooked then
        GameMenuFrame:HookScript("OnShow", queuePositionCDMButton)
        hooksecurefunc(GameMenuFrame, "Layout", queuePositionCDMButton)
        GameMenuFrame._mqolCDMHooked = true
    end

    -- Apply suite styling only when exactly one provider is active. If ElvUI
    -- and EllesmereUI are both present, leave the CDM button native.
    if ElvUI and not EllesmereUI and not GameMenuFrame._mqolCDMSkinHooked then
        hooksecurefunc(GameMenuFrame, "InitButtons", function()
            if btn and not btn.IsSkinned then
                local E = ElvUI[1]
                local S = E and E:GetModule("Skins")
                if S and S.HandleButton then
                    S:HandleButton(btn, nil, nil, nil, true)
                    if btn.backdrop then
                        btn.backdrop:SetInside(nil, 1, 1)
                    end
                    btn.IsSkinned = true
                end
            end
        end)
        GameMenuFrame._mqolCDMSkinHooked = true
    end

    -- EllesmereUI's public Button primitive uses generic window colors and the
    -- full frame bounds, while its pause menu has popup-specific colors,
    -- borders, and a 2px inset. Use the guarded popup path for an exact match;
    -- retain the public API as a compatibility fallback.
    if not ElvUI and EllesmereUI then
        local db = _G.EllesmereUIDB
        local menuSkinEnabled = not db or db.reskinGameMenu ~= false
        if menuSkinEnabled then
            local exact
            if securecallfunction then
                exact = securecallfunction(applyExactEllesmereStyle)
            else
                exact = applyExactEllesmereStyle()
            end
            if not exact and EllesmereUI.RegisterSkin then
                EllesmereUI.RegisterSkin("MathWroQOL", function(S)
                    ellesmereStyled = true
                    S.Button(btn)
                    S.Font(btn:GetFontString())
                    S.WhiteButtonLabel(btn)
                    suppressNativeButtonArt()
                end)
            end
        end
    end

    -- Register slash commands; toggled by db flag at invocation time.
    SLASH_MQOLWA1 = "/wa"
    SlashCmdList["MQOLWA"] = function()
        if addon.db.cdmButton and addon.db.cdmButton.slashWA then
            openCDM()
        end
    end

    SLASH_MQOLCM1 = "/cm"
    SlashCmdList["MQOLCM"] = function()
        if addon.db.cdmButton and addon.db.cdmButton.slashCM then
            openCDM()
        end
    end

    self:Apply()
end
