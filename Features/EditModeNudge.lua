local _, addon = ...

local EditModeNudge = { name = "editModeNudge" }
addon:RegisterFeature(EditModeNudge)

-- ── Nudge overlay ─────────────────────────────────────────────────────────────

local overlay       -- the container frame (created lazily)
local coordLabel    -- FontString showing anchor info
local selectedFrame -- the Edit Mode system currently selected
local arrowButtons = {} -- UP, DOWN, LEFT, RIGHT

-- ── Arrow button factory ──────────────────────────────────────────────────────

-- rotation in radians: UP=0, DOWN=pi, LEFT=pi/2, RIGHT=-pi/2
local ARROW_ROTATION = {
    UP    = 0,
    DOWN  = math.pi,
    LEFT  = math.pi * 0.5,
    RIGHT = -math.pi * 0.5,
}

local function CreateArrowButton(parent, direction)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(200)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.85)

    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("CENTER")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    arrow:SetRotation(ARROW_ROTATION[direction])
    arrow:SetVertexColor(1, 1, 1, 0.9)
    btn.arrow = arrow

    btn:SetScript("OnEnter", function(self)
        self.arrow:SetVertexColor(1, 0.82, 0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Nudge " .. direction:lower())
        GameTooltip:AddLine("Click: 1 px  |  Shift-click: 10 px", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.arrow:SetVertexColor(1, 1, 1, 0.9)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        if selectedFrame and selectedFrame.ProcessMovementKey then
            selectedFrame:ProcessMovementKey(direction)
            EditModeNudge:UpdateCoordLabel()
        end
    end)

    return btn
end

-- ── Coordinate label updater ──────────────────────────────────────────────────

function EditModeNudge:UpdateCoordLabel()
    if not coordLabel or not selectedFrame then return end

    local centerX, centerY = selectedFrame:GetCenter()
    if not centerX then
        coordLabel:SetText("")
        return
    end

    -- Convert to screen-centre-relative coordinates
    local screenCenterX = UIParent:GetWidth() / 2
    local screenCenterY = UIParent:GetHeight() / 2
    local relativeX = centerX - screenCenterX
    local relativeY = centerY - screenCenterY

    coordLabel:SetFormattedText(
        "X: %.1f  Y: %.1f",
        relativeX, relativeY
    )
end

-- ── Overlay creation (lazy) ───────────────────────────────────────────────────

local function EnsureOverlay()
    if overlay then return end

    overlay = CreateFrame("Frame", "MathWroQOL_EditModeNudgeOverlay", UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(150)
    overlay:Hide()

    arrowButtons.UP = CreateArrowButton(overlay, "UP")
    arrowButtons.UP:SetPoint("BOTTOM", overlay, "TOP", 0, 4)

    arrowButtons.DOWN = CreateArrowButton(overlay, "DOWN")
    arrowButtons.DOWN:SetPoint("TOP", overlay, "BOTTOM", 0, -4)

    arrowButtons.LEFT = CreateArrowButton(overlay, "LEFT")
    arrowButtons.LEFT:SetPoint("RIGHT", overlay, "LEFT", -4, 0)

    arrowButtons.RIGHT = CreateArrowButton(overlay, "RIGHT")
    arrowButtons.RIGHT:SetPoint("LEFT", overlay, "RIGHT", 4, 0)

    coordLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordLabel:SetPoint("BOTTOM", arrowButtons.UP, "TOP", 0, 4)
    coordLabel:SetJustifyH("CENTER")
    coordLabel:SetTextColor(1, 0.82, 0, 1)

    local highlight = overlay:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.15)
    overlay.highlight = highlight
end

-- ── Attach / detach from a system frame ───────────────────────────────────────

local COORD_UPDATE_INTERVAL = 0.05
local timeSinceLastUpdate = 0

local function AttachToSystem(systemFrame)
    if not addon.db.editModeNudge or not addon.db.editModeNudge.enabled then return end

    EnsureOverlay()
    selectedFrame = systemFrame
    timeSinceLastUpdate = 0

    overlay:ClearAllPoints()
    overlay:SetAllPoints(systemFrame)
    overlay:SetScript("OnUpdate", function(_, elapsed)
        timeSinceLastUpdate = timeSinceLastUpdate + elapsed
        if timeSinceLastUpdate >= COORD_UPDATE_INTERVAL then
            timeSinceLastUpdate = 0
            EditModeNudge:UpdateCoordLabel()
        end
    end)
    overlay:Show()

    EditModeNudge:UpdateCoordLabel()
end

local function DetachOverlay()
    selectedFrame = nil
    if overlay then
        overlay:SetScript("OnUpdate", nil)
        overlay:Hide()
    end
end

-- ── Hooks ─────────────────────────────────────────────────────────────────────

local hooked = false

local function InstallHooks()
    if hooked then return end
    hooked = true

    hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(_, systemFrame)
        if not addon.db.editModeNudge or not addon.db.editModeNudge.enabled then return end
        AttachToSystem(systemFrame)
    end)

    hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
        DetachOverlay()
    end)

    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        DetachOverlay()
    end)
end

-- ── Feature contract ──────────────────────────────────────────────────────────

function EditModeNudge:Initialize()
    if not addon.db.editModeNudge then
        addon.db.editModeNudge = { enabled = true }
    end

    if addon.db.editModeNudge.enabled then
        InstallHooks()
    end
end

function EditModeNudge:Apply()
    if addon.db.editModeNudge.enabled then
        InstallHooks()
    else
        DetachOverlay()
    end
end
