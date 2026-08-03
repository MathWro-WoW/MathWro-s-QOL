local _, addon = ...

local CDMButton = { name = "cdmButton" }
addon:RegisterFeature(CDMButton)

-- The button widget, created once and reused.
local btn
local ellesmereSkin
local nativeArt = {}
local positionPending = false

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
    if not ellesmereSkin or not btn then return end

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

local function positionCDMButton()
    if not btn or not btn:IsShown() then return end

    local baseButton, boundaryButton, pooled = findMenuAnchors()
    if not baseButton then return end

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
    btn:ClearAllPoints()
    btn:SetPoint("TOP", anchorButton, "BOTTOM", 0, -gap)
    suppressNativeButtonArt()

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
    if positionPending then return end
    positionPending = true
    -- A second zero-delay pass runs after extensions that perform their own
    -- one-frame-deferred menu positioning.
    C_Timer.After(0, function()
        C_Timer.After(0, function()
            positionPending = false
            positionCDMButton()
        end)
    end)
end

function CDMButton:Apply()
    if not btn then return end
    local db = addon.db.cdmButton
    if db and db.enabled then
        btn:Show()
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

    -- Hook Layout (not OnShow): Blizzard calls Layout() to position all pooled
    -- buttons, so hooking here ensures our SetPoint runs after theirs.
    if not GameMenuFrame._mqolCDMHooked then
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

    -- Use EllesmereUI's public third-party skin API when ElvUI is not the
    -- active provider. The callback also tracks later EllesmereUI theme changes.
    if not ElvUI and EllesmereUI and EllesmereUI.RegisterSkin then
        EllesmereUI.RegisterSkin("MathWroQOL", function(S)
            ellesmereSkin = S
            S.Button(btn)
            S.Font(btn:GetFontString())
            S.WhiteButtonLabel(btn)
            suppressNativeButtonArt()
        end)
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
