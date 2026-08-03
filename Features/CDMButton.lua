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
local function positionCDMButton()
    if not btn or not btn:IsShown() then return end

    local anchorBtn, ellesmereAnchor
    if GameMenuFrame.ElvUI then
        -- ElvUI is loaded: group CDM directly below the ElvUI button.
        anchorBtn = GameMenuFrame.ElvUI
    elseif _G.EllesmereUI_UnlockMenuButton and _G.EllesmereUI_UnlockMenuButton:IsShown() then
        anchorBtn = _G.EllesmereUI_UnlockMenuButton
        ellesmereAnchor = true
    elseif _G.EllesmereUI_GameMenuButton and _G.EllesmereUI_GameMenuButton:IsShown() then
        anchorBtn = _G.EllesmereUI_GameMenuButton
        ellesmereAnchor = true
    elseif GameMenuFrame.buttonPool then
        -- No suite-specific button: find Shop in the active Blizzard pool.
        local storeText = _G.BLIZZARD_STORE
        if storeText then
            for button in GameMenuFrame.buttonPool:EnumerateActive() do
                if button:GetText() == storeText then
                    anchorBtn = button
                    break
                end
            end
        end
    end

    if not anchorBtn then return end

    local anchorWidth, anchorHeight = anchorBtn:GetSize()
    if anchorWidth and anchorWidth > 0 then
        btn:SetSize(anchorWidth, anchorHeight or 35)
    end

    local extraHeight = ellesmereAnchor and 40 or 45
    local gap = ellesmereAnchor and 4 or 10
    btn:ClearAllPoints()
    btn:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -gap)
    suppressNativeButtonArt()

    -- Nudge all pool buttons that sit at or below the anchor's bottom edge down
    -- to make room for CDM. Layout() resets their positions each open, so this
    -- runs fresh every time and doesn't accumulate.
    local anchorBottom = anchorBtn:GetBottom()
    if anchorBottom and GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            local top = button:GetTop()
            if top and top <= anchorBottom + 1 then
                local point, relativeTo, relativePoint, x, y = button:GetPoint()
                if point then
                    button:ClearAllPoints()
                    button:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) - extraHeight)
                end
            end
        end
    end

    -- Expand the frame to fit the extra button and its gap.
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + extraHeight)
end

local function queuePositionCDMButton()
    if positionPending then return end
    positionPending = true
    C_Timer.After(0, function()
        positionPending = false
        positionCDMButton()
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

    -- Apply ElvUI skin when ElvUI is active, mirroring ElvUI's own GameMenuInitButtons hook.
    if ElvUI and not GameMenuFrame._mqolCDMSkinHooked then
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
