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
    elseif GameMenuFrame.buttonPool then
        -- No ElvUI: find the Shop (BLIZZARD_STORE) button from the active pool.
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

    -- Expand frame to fit the extra button (35px height + 10px gap, matching ElvUI spacing).
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
    local db = addon.db.cdmButton

    -- Use the same template and size as ElvUI's retail game menu button.
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
