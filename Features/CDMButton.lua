local _, addon = ...

local CDMButton = { name = "cdmButton" }
addon:RegisterFeature(CDMButton)

-- The button widget, created once and reused.
local btn

local function openCDM()
    if CooldownViewerSettings then
        CooldownViewerSettings:Show()
    end
end

-- Called via hooksecurefunc on GameMenuFrame.Layout.
-- Blizzard re-pools and re-positions all buttons in Layout(), so this hook
-- runs after the layout is fully settled — the correct place to insert extras.
local function positionCDMButton()
    if not btn or not btn:IsShown() then return end

    local anchorBtn
    if GameMenuFrame.ElvUI then
        -- ElvUI is loaded: group CDM directly below the ElvUI button.
        anchorBtn = GameMenuFrame.ElvUI
    elseif _G.EllesmereUI_UnlockMenuButton and _G.EllesmereUI_UnlockMenuButton:IsShown() then
        anchorBtn = _G.EllesmereUI_UnlockMenuButton
    elseif _G.EllesmereUI_GameMenuButton and _G.EllesmereUI_GameMenuButton:IsShown() then
        anchorBtn = _G.EllesmereUI_GameMenuButton
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

    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -10)

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
                    button:SetPoint(point, relativeTo, relativePoint, x, y - 45)
                end
            end
        end
    end

    -- Expand the frame to fit the extra button and its gap.
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 45)
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
        hooksecurefunc(GameMenuFrame, "Layout", positionCDMButton)
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
            S.Button(btn)
            S.WhiteButtonLabel(btn)
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
