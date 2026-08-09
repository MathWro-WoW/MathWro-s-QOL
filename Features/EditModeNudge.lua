local _, addon = ...

local EditModeNudge = { name = "editModeNudge" }
addon.editModeNudge = EditModeNudge
addon:RegisterFeature(EditModeNudge)

-- ── Nudge overlay ─────────────────────────────────────────────────────────────

local overlay       -- the container frame (created lazily)
local coordEditor   -- compact popup for manual coordinate entry
local selectedFrame -- the Edit Mode system currently selected
local selectedLibEditModeSelection
local selectedEllesmereMover
local arrowButtons = {} -- UP, DOWN, LEFT, RIGHT
local coordInputs = {}  -- x, y
local syncingCoordInputs = false
local function IsBlizzardNudgeEnabled()
    return addon.db and addon.db.editModeNudge
        and addon.db.editModeNudge.enabled == true
end

local function IsEllesmereNudgeEnabled()
    return addon.db and addon.db.editModeNudge
        and addon.db.editModeNudge.ellesmereEnabled == true
        and EllesmereUI and EllesmereUI.RegisterUnlockModeListener
end

local function IsAnyNudgeEnabled()
    return IsBlizzardNudgeEnabled() or IsEllesmereNudgeEnabled()
end

local function GetEllesmerePixelCenter()
    if not selectedEllesmereMover or not selectedEllesmereMover.UpdateCoordText then
        return nil, nil
    end

    local coordFS = selectedEllesmereMover._coordFS
    if not coordFS then return nil, nil end

    -- EUI already handles stored-vs-live positions, frame scale, pixel-grid
    -- snapping, and odd-sized frame parity in this readout. Reuse that result
    -- instead of maintaining a second coordinate conversion here.
    selectedEllesmereMover:UpdateCoordText()
    local text = coordFS:GetText()
    if type(text) ~= "string" then return nil, nil end

    local x, y = text:match("^%s*([+-]?%d+)%s*,%s*([+-]?%d+)%s*$")
    return tonumber(x), tonumber(y)
end

local function GetSelectedRelativeCenter()
    if selectedEllesmereMover then
        local x, y = GetEllesmerePixelCenter()
        if x and y then return x, y end
    end

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

local function MoveSelectedFrameBy(dx, dy, movementKeySteps)
    if not selectedFrame or ((dx == 0) and (dy == 0)) then return end

    if selectedEllesmereMover and EllesmereUI and EllesmereUI._unlockNudge then
        EllesmereUI._unlockNudge(dx, dy, selectedEllesmereMover, true)
        EditModeNudge:UpdateCoordLabel()
        return
    end

    if selectedLibEditModeSelection then
        local LibEditMode = LibStub and LibStub("LibEditMode", true)
        if LibEditMode and LibEditMode.internal and LibEditMode.internal.MoveParent then
            LibEditMode.internal:MoveParent(selectedLibEditModeSelection, dx, dy)
            EditModeNudge:UpdateCoordLabel()
            return
        end
    end

    if selectedFrame.ProcessMovementKey then
        local xSteps = dx ~= 0 and (movementKeySteps or math.floor(math.abs(dx) + 0.5)) or 0
        local ySteps = dy ~= 0 and (movementKeySteps or math.floor(math.abs(dy) + 0.5)) or 0
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
        local delta = value - currentX
        if selectedEllesmereMover and EllesmereUI and EllesmereUI.PP
            and EllesmereUI.PP.FromPixels
        then
            delta = EllesmereUI.PP.FromPixels(delta)
        end
        MoveSelectedFrameBy(delta, 0)
    else
        if NormalizeCoord(currentY) == value then
            EditModeNudge:UpdateCoordLabel()
            return
        end
        local delta = value - currentY
        if selectedEllesmereMover and EllesmereUI and EllesmereUI.PP
            and EllesmereUI.PP.FromPixels
        then
            delta = EllesmereUI.PP.FromPixels(delta)
        end
        MoveSelectedFrameBy(0, delta)
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
local function GetEllesmereAccent(alpha)
    if EllesmereUI and EllesmereUI.GetAccentColor then
        local r, g, b = EllesmereUI.GetAccentColor()
        return r, g, b, alpha or 1
    end
    return 1, 0.82, 0, alpha or 1
end

local function StyleEllesmereButton(btn, background)
    if not EllesmereUI then return end

    local r, g, b = GetEllesmereAccent(0.8)
    if background then
        background:SetColorTexture(0.075, 0.113, 0.141, 0.95)
    end
    if EllesmereUI.MakeBorder then
        if not btn._mqolEllesmereBorder then
            btn._mqolEllesmereBorder = EllesmereUI.MakeBorder(btn, r, g, b, 0.7)
        else
            btn._mqolEllesmereBorder:SetColor(r, g, b, 0.7)
        end
    end
end

local function RefreshEllesmereButtonStyle(btn)
    if not EllesmereUI then return end
    local r, g, b = GetEllesmereAccent(0.8)
    if btn._mqolEllesmereBorder then
        btn._mqolEllesmereBorder:SetColor(r, g, b, 0.7)
    end
    if btn.arrow then
        btn.arrow:SetVertexColor(r, g, b, 0.9)
    end
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

local ELLESMERE_ARROW_TEXTURES = {
    UP    = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-up3.png",
    DOWN  = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-down3.png",
    LEFT  = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-left.png",
    RIGHT = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow-right.png",
}

local function CreateArrowButton(parent, direction)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    btn:SetFrameStrata(EllesmereUI and "FULLSCREEN_DIALOG" or "DIALOG")
    btn:SetFrameLevel(EllesmereUI and 700 or 200)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.85)

    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    if EllesmereUI then
        arrow:SetTexture(ELLESMERE_ARROW_TEXTURES[direction])
        arrow:SetTexCoord(0, 1, 0, 1)
    elseif ElvUI and ElvUI[1] and ElvUI[1].Media and ElvUI[1].Media.Textures and ElvUI[1].Media.Textures.ArrowUp then
        arrow:SetTexture(ElvUI[1].Media.Textures.ArrowUp)
        arrow:SetTexCoord(0, 1, 0, 1)
        arrow:SetRotation(ARROW_ROTATION[direction])
    else
        arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
        arrow:SetTexCoord(0.18, 0.82, 0.18, 0.82)
        arrow:SetRotation(ARROW_ROTATION[direction])
    end
    arrow:SetVertexColor(1, 1, 1, 0.9)
    btn.arrow = arrow
    StyleEllesmereButton(btn, bg)

    btn:SetScript("OnEnter", function(self)
        local r, g, b = GetEllesmereAccent(1)
        self.arrow:SetVertexColor(r, g, b, 1)
        if self._mqolEllesmereBorder then self._mqolEllesmereBorder:SetColor(1, 1, 1, 0.95) end
        if EllesmereUI and EllesmereUI.ShowWidgetTooltip then
            EllesmereUI.ShowWidgetTooltip(self, "Nudge " .. direction:lower() .. "\nClick: 1 px  |  Shift-click: 10 px")
        else
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Nudge " .. direction:lower())
            GameTooltip:AddLine("Click: 1 px  |  Shift-click: 10 px", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        RefreshEllesmereButtonStyle(self)
        if EllesmereUI and EllesmereUI.HideWidgetTooltip then
            EllesmereUI.HideWidgetTooltip()
        else
            GameTooltip:Hide()
        end
    end)

    btn:SetScript("OnClick", function()
        if not selectedFrame then return end
        local shiftHeld = IsShiftKeyDown()
        local pixelScale = EllesmereUI and EllesmereUI.PP and EllesmereUI.PP.mult or 1
        local amount = (shiftHeld and 10 or 1) * (selectedEllesmereMover and pixelScale or 1)
        local dx = (direction == "RIGHT" and amount) or (direction == "LEFT" and -amount) or 0
        local dy = (direction == "UP" and amount) or (direction == "DOWN" and -amount) or 0
        local movementKeySteps = shiftHeld and 1 or nil

        MoveSelectedFrameBy(dx, dy, movementKeySteps)
    end)

    return btn
end

local function CreateCoordInput(parent, axis)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(98, 22)

    local fontPath
    if EllesmereUI and EllesmereUI.GetFontPath then
        fontPath = EllesmereUI.GetFontPath("extras")
    end

    local label = row:CreateFontString(nil, "OVERLAY")
    if EllesmereUI and EllesmereUI.PrimeFontShadow then
        EllesmereUI.PrimeFontShadow(label, true)
    end
    if fontPath then label:SetFont(fontPath, 10, "") end
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetText(string.upper(axis))
    label:SetTextColor(0.75, 0.75, 0.75, 0.9)

    local input = CreateFrame("EditBox", nil, row)
    input:SetSize(44, 20)
    input:SetPoint("LEFT", label, "RIGHT", 4, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(8)
    input:SetJustifyH("CENTER")
    input:SetJustifyV("MIDDLE")
    input:SetTextInsets(0, 0, 0, 0)
    if fontPath then input:SetFont(fontPath, 10, "") end
    input:SetTextColor(1, 1, 1, 0.9)
    local inputBg = input:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints()
    inputBg:SetColorTexture(0, 0, 0, 0.4)

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

    local reset = CreateFrame("Button", nil, row)
    reset:SetSize(22, 20)
    reset:SetPoint("LEFT", input, "RIGHT", 4, 0)
    local resetBg = reset:CreateTexture(nil, "BACKGROUND")
    resetBg:SetAllPoints()
    resetBg:SetColorTexture(0.075, 0.113, 0.141, 0.95)
    local resetBorder
    if EllesmereUI and EllesmereUI.MakeBorder then
        resetBorder = EllesmereUI.MakeBorder(reset, 1, 1, 1, 0.22)
    end
    local resetText = reset:CreateFontString(nil, "OVERLAY")
    if EllesmereUI and EllesmereUI.PrimeFontShadow then
        EllesmereUI.PrimeFontShadow(resetText, true)
    end
    if fontPath then resetText:SetFont(fontPath, 10, "") end
    resetText:SetPoint("CENTER", reset, "CENTER")
    resetText:SetText("0")
    resetText:SetTextColor(1, 1, 1, 0.65)
    reset:SetScript("OnEnter", function()
        if resetBorder then resetBorder:SetColor(1, 1, 1, 0.9) end
        resetText:SetTextColor(1, 1, 1, 1)
    end)
    reset:SetScript("OnLeave", function()
        if resetBorder then resetBorder:SetColor(1, 1, 1, 0.22) end
        resetText:SetTextColor(1, 1, 1, 0.65)
    end)
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
    overlay:SetFrameStrata(EllesmereUI and "FULLSCREEN_DIALOG" or "DIALOG")
    overlay:SetFrameLevel(EllesmereUI and 650 or 150)
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
    coordEditor:SetSize(218, 58)
    coordEditor:SetFrameLevel(710)
    coordEditor:SetPoint("BOTTOM", arrowButtons.UP, "TOP", 0, 4)

    if EllesmereUI then
        local editorBg = coordEditor:CreateTexture(nil, "BACKGROUND")
        editorBg:SetAllPoints()
        editorBg:SetColorTexture(0.075, 0.113, 0.141, 0.97)
        coordEditor._bg = editorBg
        if EllesmereUI.MakeBorder then
            EllesmereUI.MakeBorder(coordEditor, 1, 1, 1, 0.20)
        end
    else
        coordEditor:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile     = false,
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        coordEditor:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
        coordEditor:SetBackdropBorderColor(1, 0.82, 0, 0.7)
    end

    local title = coordEditor:CreateFontString(nil, "OVERLAY")
    if EllesmereUI and EllesmereUI.PrimeFontShadow then
        EllesmereUI.PrimeFontShadow(title, true)
    end
    if EllesmereUI and EllesmereUI.GetFontPath then
        local fontPath = EllesmereUI.GetFontPath("extras")
        if fontPath then title:SetFont(fontPath, 10, "") end
    end
    title:SetPoint("TOP", coordEditor, "TOP", 0, -6)
    title:SetText("Position")
    title:SetTextColor(GetEllesmereAccent(1))

    local xRow = CreateCoordInput(coordEditor, "x")
    xRow:SetPoint("BOTTOMLEFT", coordEditor, "BOTTOMLEFT", 10, 6)

    local yRow = CreateCoordInput(coordEditor, "y")
    yRow:SetPoint("BOTTOMRIGHT", coordEditor, "BOTTOMRIGHT", -10, 6)

    local highlight = overlay:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    local r, g, b = GetEllesmereAccent(1)
    highlight:SetColorTexture(r, g, b, 0.15)
    overlay.highlight = highlight
end

-- ── Attach / detach from a system frame ───────────────────────────────────────

local COORD_UPDATE_INTERVAL = 0.05
local timeSinceLastUpdate = 0

local function AttachToSystem(systemFrame, libEditModeSelection)
    if not IsBlizzardNudgeEnabled() then return end

    EnsureOverlay()
    selectedFrame = systemFrame
    selectedLibEditModeSelection = libEditModeSelection
    selectedEllesmereMover = nil
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

local function AttachToEllesmereMover(mover)
    if not EllesmereUI or not EllesmereUI._unlockNudge then return end
    if not IsEllesmereNudgeEnabled() then return end
    if not mover or not mover._barKey then return end

    EnsureOverlay()
    selectedFrame = mover
    selectedLibEditModeSelection = nil
    selectedEllesmereMover = mover
    timeSinceLastUpdate = 0

    overlay:ClearAllPoints()
    overlay:SetAllPoints(mover)
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
    selectedEllesmereMover = nil
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
        if not IsBlizzardNudgeEnabled() then return end
        AttachToSystem(frame, self)
    end)
end

local ellesmereUnlockHooked = false
local unlockMoverScanPending = false

local function HookUnlockMover(mover)
    if not mover or mover._mqolUnlockNudgeHooked then return end
    mover._mqolUnlockNudgeHooked = true

    mover:HookScript("OnClick", function(self)
        C_Timer.After(0, function()
            if not IsEllesmereNudgeEnabled() then return end
            if not EllesmereUI or not EllesmereUI.IsUnlockModeActive
                or not EllesmereUI.IsUnlockModeActive()
            then
                return
            end
            if self._selected then
                AttachToEllesmereMover(self)
            elseif selectedEllesmereMover == self then
                DetachOverlay()
            end
        end)
    end)

    mover:HookScript("OnHide", function(self)
        if selectedEllesmereMover == self then
            DetachOverlay()
        end
    end)
end

local function ScanUnlockMovers()
    if not IsEllesmereNudgeEnabled() then return end
    if not EllesmereUI or not EllesmereUI.IsUnlockModeActive
        or not EllesmereUI.IsUnlockModeActive()
    then
        return
    end

    local frame = EnumerateFrames()
    while frame do
        if frame.IsObjectType and frame:IsObjectType("Button")
            and frame._barKey and frame._bg and frame._brd
        then
            HookUnlockMover(frame)
        end
        frame = EnumerateFrames(frame)
    end
end

local function QueueUnlockMoverScan()
    if unlockMoverScanPending then return end
    if not IsEllesmereNudgeEnabled() then return end
    unlockMoverScanPending = true
    C_Timer.After(0, function()
        unlockMoverScanPending = false
        ScanUnlockMovers()
    end)
end

local function InstallEllesmereUnlockHooks()
    if ellesmereUnlockHooked or not EllesmereUI then return end
    if not EllesmereUI.RegisterUnlockModeListener then return end

    ellesmereUnlockHooked = true
    EllesmereUI:RegisterUnlockModeListener("MathWroQOL_EditModeNudge", function(active)
        if active then
            QueueUnlockMoverScan()
        elseif selectedEllesmereMover then
            DetachOverlay()
        end
    end)

    if EllesmereUI.RegisterUnlockElements then
        hooksecurefunc(EllesmereUI, "RegisterUnlockElements", QueueUnlockMoverScan)
    end

    if EllesmereUI.IsUnlockModeActive and EllesmereUI.IsUnlockModeActive() then
        QueueUnlockMoverScan()
    end
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
    if IsBlizzardNudgeEnabled() and not hooked then
        hooked = true

        hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(_, systemFrame)
            if not IsBlizzardNudgeEnabled() then return end
            AttachToSystem(systemFrame)
        end)

        hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function()
            DetachOverlay()
        end)

        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            DetachOverlay()
        end)
    end

    if IsBlizzardNudgeEnabled() then
        InstallLibEditModeHooks()
    end
    if IsEllesmereNudgeEnabled() then
        InstallEllesmereUnlockHooks()
    end
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
        addon.db.editModeNudge = { enabled = false, ellesmereEnabled = false }
    end

    if IsAnyNudgeEnabled() then
        InstallHooks()
    end
end

function EditModeNudge:Apply()
    local blizzardEnabled = IsBlizzardNudgeEnabled()
    local ellesmereEnabled = IsEllesmereNudgeEnabled()

    if blizzardEnabled or ellesmereEnabled then
        InstallHooks()
    end

    local selectedProviderDisabled = (selectedEllesmereMover and not ellesmereEnabled)
        or (selectedFrame and not selectedEllesmereMover and not blizzardEnabled)
    if (not blizzardEnabled and not ellesmereEnabled) or selectedProviderDisabled then
        DetachOverlay()
    end
end
