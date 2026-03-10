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

-- Re-anchor GameMenuButtonAddOns below `anchorFrame` and resize the menu.
-- Called every OnShow because Blizzard rebuilds button layout on each open.
local function repositionButtons(anchorFrame)
    if not btn or not btn:IsShown() then return end

    -- One button height + standard spacing used by the game menu template
    local BUTTON_HEIGHT = 24
    local SPACING = 1

    -- Anchor CDM button below anchorFrame
    btn:ClearAllPoints()
    btn:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -SPACING)

    -- Shift AddOns (and everything below it) down by inserting our button
    if GameMenuButtonAddOns then
        GameMenuButtonAddOns:ClearAllPoints()
        GameMenuButtonAddOns:SetPoint("TOP", btn, "BOTTOM", 0, -SPACING)
    end

    -- Expand the frame to fit the extra button
    local extraHeight = BUTTON_HEIGHT + SPACING
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + extraHeight)
end

local function getAnchorFrame()
    -- If ElvUI's game menu button exists and is shown, group below it.
    -- ElvUI names its button "ElvUIGameMenuButton".
    if ElvUI and _G["ElvUIGameMenuButton"] and _G["ElvUIGameMenuButton"]:IsShown() then
        return _G["ElvUIGameMenuButton"]
    end
    -- Otherwise anchor directly below Shop.
    return GameMenuButtonShop
end

function CDMButton:Apply()
    if not btn then return end
    local db = addon.db.cdmButton
    if db and db.enabled then
        btn:Show()
    else
        btn:Hide()
        -- If hidden, restore AddOns to its default anchor (below Shop or ElvUI btn)
        -- Blizzard will reset layout on next OnShow anyway, so nothing extra needed.
    end
end

function CDMButton:Initialize()
    local db = addon.db.cdmButton

    -- Create button once
    btn = CreateFrame("Button", "MathWroQOL_CDMButton", GameMenuFrame, "GameMenuButtonTemplate")
    btn:SetText("CDM")
    btn:SetScript("OnClick", function()
        HideUIPanel(GameMenuFrame)
        openCDM()
    end)

    -- Hook OnShow to reposition every time the menu opens
    if not GameMenuFrame._mqolCDMHooked then
        GameMenuFrame:HookScript("OnShow", function()
            if addon.db.cdmButton and addon.db.cdmButton.enabled then
                repositionButtons(getAnchorFrame())
            end
        end)
        GameMenuFrame._mqolCDMHooked = true
    end

    -- Register slash commands (cannot be unregistered; toggled by db flag at fire time)
    if db.slashWA then
        SLASH_MQOLWA1 = "/wa"
        SlashCmdList["MQOLWA"] = function()
            openCDM()
        end
    end

    if db.slashCM then
        SLASH_MQOLCM1 = "/cm"
        SlashCmdList["MQOLCM"] = function()
            openCDM()
        end
    end

    self:Apply()
end
