local _, addon = ...

local EditModeNudge = { name = "editModeNudge" }
addon.editModeNudge = EditModeNudge
addon:RegisterFeature(EditModeNudge)

-- ── Nudge overlay ─────────────────────────────────────────────────────────────

local overlay       -- the container frame (created lazily)
local coordEditor   -- compact popup for manual coordinate entry
local selectedFrame -- the Edit Mode system currently selected
local selectedLibEditModeSelection
local arrowButtons = {} -- UP, DOWN, LEFT, RIGHT
local coordInputs = {}  -- x, y
local syncingCoordInputs = false

local function GetSelectedRelativeCenter()
    if not selectedFrame then return nil, nil end

    local centerX, centerY = selectedFrame:GetCenter()
    if not centerX then return nil, nil end

    local screenCenterX = UIParent:GetWidth() / 2
    local screenCenterY = UIParent:GetHeight() / 2

    return centerX - screenCenterX, centerY - screenCenterY
end

local function NormalizeCoord(value)
    if math.abs(value) <= 0.5 then return 0 end

    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

local function MoveSelectedFrameBy(dx, dy)
    if not selectedFrame or ((dx == 0) and (dy == 0)) then return end

    if selectedLibEditModeSelection then
        local LibEditMode = LibStub and LibStub("LibEditMode", true)
        if LibEditMode and LibEditMode.internal and LibEditMode.internal.MoveParent then
            LibEditMode.internal:MoveParent(selectedLibEditModeSelection, dx, dy)
            EditModeNudge:UpdateCoordLabel()
            return
        end
    end

    if selectedFrame.ProcessMovementKey then
        local xSteps = math.floor(math.abs(dx) + 0.5)
        local ySteps = math.floor(math.abs(dy) + 0.5)
        local xDirection = dx > 0 and "RIGHT" or "LEFT"
        local yDirection = dy > 0 and "UP" or "DOWN"

        for _ = 1, xSteps do
            selectedFrame:ProcessMovementKey(xDirection)
        end
        for _ = 1, ySteps do
            selectedFrame:ProcessMovementKey(yDirection)
        end

        EditModeNudge:UpdateCoordLabel()
        return
    end

    local point, rel, relPoint, x, y = selectedFrame:GetPoint(1)
    if not point then return end

    selectedFrame:ClearAllPoints()
    selectedFrame:SetPoint(point, rel, relPoint, (x or 0) + dx, (y or 0) + dy)
    EditModeNudge:UpdateCoordLabel()
end

local function SetSelectedAxis(axis, value)
    local currentX, currentY = GetSelectedRelativeCenter()
    if not currentX then return end

    value = NormalizeCoord(value)

    if axis == "x" then
        if NormalizeCoord(currentX) == value then
            EditModeNudge:UpdateCoordLabel()
            return
        end
        MoveSelectedFrameBy(value - currentX, 0)
    else
        if NormalizeCoord(currentY) == value then
            EditModeNudge:UpdateCoordLabel()
            return
        end
        MoveSelectedFrameBy(0, value - currentY)
    end
end

local function SyncCoordInputs(x, y)
    if not coordInputs.x or not coordInputs.y then return end

    syncingCoordInputs = true
    if not coordInputs.x:HasFocus() then
        coordInputs.x:SetText(tostring(NormalizeCoord(x)))
    end
    if not coordInputs.y:HasFocus() then
        coordInputs.y:SetText(tostring(NormalizeCoord(y)))
    end
    syncingCoordInputs = false
end

-- ── Arrow button factory ──────────────────────────────────────────────────────

-- Prefer ElvUI's clean arrow texture when available. Fall back to Blizzard's
-- visible arrow texture, cropped to reduce its uneven transparent padding.
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
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    if ElvUI and ElvUI[1] and ElvUI[1].Media and ElvUI[1].Media.Textures and ElvUI[1].Media.Textures.ArrowUp then
        arrow:SetTexture(ElvUI[1].Media.Textures.ArrowUp)
        arrow:SetTexCoord(0, 1, 0, 1)
    else
        arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        arrow:SetTexCoord(0.18, 0.82, 0.18, 0.82)
    end
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
        if not selectedFrame then return end
        local amount = IsShiftKeyDown() and 10 or 1
        local dx = (direction == "RIGHT" and amount) or (direction == "LEFT" and -amount) or 0
        local dy = (direction == "UP"    and amount) or (direction == "DOWN" and -amount) or 0

        MoveSelectedFrameBy(dx, dy)
    end)

    return btn
end

local function CreateCoordInput(parent, axis)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(82, 22)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetText(string.upper(axis))
    label:SetTextColor(1, 0.82, 0, 1)

    local input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    input:SetSize(44, 20)
    input:SetPoint("LEFT", label, "RIGHT", 4, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(8)
    input:SetJustifyH("CENTER")
    input:SetJustifyV("MIDDLE")
    input:SetTextInsets(0, 0, 0, 0)
    input:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value then
            SetSelectedAxis(axis, value)
        end
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self.cancelEdit = true
        self:ClearFocus()
    end)
    input:SetScript("OnEditFocusLost", function(self)
        if syncingCoordInputs then return end
        if self.cancelEdit then
            self.cancelEdit = nil
            local x, y = GetSelectedRelativeCenter()
            if x then SyncCoordInputs(x, y) end
            return
        end

        local value = tonumber(self:GetText())
        if value then
            SetSelectedAxis(axis, value)
        else
            local x, y = GetSelectedRelativeCenter()
            if x then SyncCoordInputs(x, y) end
        end
    end)

    local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    reset:SetSize(22, 20)
    reset:SetPoint("LEFT", input, "RIGHT", 4, 0)
    reset:SetText("r")
    reset:SetScript("OnClick", function()
        SetSelectedAxis(axis, 0)
    end)

    coordInputs[axis] = input
    return row
end

-- ── Coordinate label updater ──────────────────────────────────────────────────

function EditModeNudge:UpdateCoordLabel()
    if not selectedFrame then return end

    local relativeX, relativeY = GetSelectedRelativeCenter()
    if not relativeX then return end

    SyncCoordInputs(relativeX, relativeY)
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

    coordEditor = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    coordEditor:SetSize(190, 54)
    coordEditor:SetFrameLevel(210)
    coordEditor:SetPoint("BOTTOM", arrowButtons.UP, "TOP", 0, 4)
    coordEditor:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    coordEditor:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
    coordEditor:SetBackdropBorderColor(1, 0.82, 0, 0.7)

    local title = coordEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", coordEditor, "TOP", 0, -6)
    title:SetText("Position")
    title:SetTextColor(1, 0.82, 0, 1)

    local xRow = CreateCoordInput(coordEditor, "x")
    xRow:SetPoint("BOTTOMLEFT", coordEditor, "BOTTOMLEFT", 10, 6)

    local yRow = CreateCoordInput(coordEditor, "y")
    yRow:SetPoint("BOTTOMRIGHT", coordEditor, "BOTTOMRIGHT", -10, 6)

    local highlight = overlay:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.15)
    overlay.highlight = highlight
end

-- ── Attach / detach from a system frame ───────────────────────────────────────

local COORD_UPDATE_INTERVAL = 0.05
local timeSinceLastUpdate = 0

local function AttachToSystem(systemFrame, libEditModeSelection)
    if not addon.db.editModeNudge or not addon.db.editModeNudge.enabled then return end

    EnsureOverlay()
    selectedFrame = systemFrame
    selectedLibEditModeSelection = libEditModeSelection
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
    selectedLibEditModeSelection = nil
    if overlay then
        overlay:SetScript("OnUpdate", nil)
        overlay:Hide()
    end
end

-- ── Hooks ─────────────────────────────────────────────────────────────────────

local hooked = false
local libEditModeHooked = false

local function AttachToLibEditModeSelection(frame, selection)
    if not frame or not selection or selection.mathWroQOLNudgeHooked then return end
    selection.mathWroQOLNudgeHooked = true

    selection:HookScript("OnMouseDown", function(self)
        if not addon.db.editModeNudge or not addon.db.editModeNudge.enabled then return end
        AttachToSystem(frame, self)
    end)
end

local function InstallLibEditModeHooks()
    local LibEditMode = LibStub and LibStub("LibEditMode", true)
    if not LibEditMode then return end

    if LibEditMode.frameSelections then
        for frame, selection in next, LibEditMode.frameSelections do
            AttachToLibEditModeSelection(frame, selection)
        end
    end

    if libEditModeHooked or not LibEditMode.AddFrame then return end
    libEditModeHooked = true

    hooksecurefunc(LibEditMode, "AddFrame", function(_, frame)
        local selection = LibEditMode.frameSelections and LibEditMode.frameSelections[frame]
        AttachToLibEditModeSelection(frame, selection)
    end)
end

local function InstallHooks()
    if not hooked then
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

    InstallLibEditModeHooks()
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Called by external systems to attach the nudge overlay to a frame that is not
-- a native WoW Edit Mode system frame.
function EditModeNudge:AttachToFrame(frame, libEditModeSelection)
    AttachToSystem(frame, libEditModeSelection)
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
