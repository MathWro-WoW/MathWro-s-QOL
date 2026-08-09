local _, addon = ...

local GameMenu = { name = "gameMenu" }
addon:RegisterFeature(GameMenu)

local DEFAULT_SCALE = 1.0
local DEFAULT_POINT = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }

local function applyPosition(db)
    local p = db.position
    if not p then return end
    GameMenuFrame:ClearAllPoints()
    GameMenuFrame:SetPoint(p.point, _G[p.relativeTo] or UIParent, p.relativePoint, p.x, p.y)
end

local function enableDrag(db)
    GameMenuFrame:SetMovable(true)
    GameMenuFrame:EnableMouse(true)
    GameMenuFrame:RegisterForDrag("LeftButton")

    -- Re-apply saved position each time the frame shows, because Blizzard
    -- re-anchors GameMenuFrame to CENTER on every open.
    if not GameMenuFrame._mqolShowHooked then
        GameMenuFrame:HookScript("OnShow", function()
            if addon.db.gameMenu.moveable and addon.db.gameMenu.position then
                applyPosition(addon.db.gameMenu)
            end
        end)
        GameMenuFrame._mqolShowHooked = true
    end

    if not GameMenuFrame._mqolDragHooked then
        GameMenuFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        GameMenuFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, relativeTo, relativePoint, x, y = self:GetPoint()
            addon.db.gameMenu.position = {
                point = point,
                relativeTo = (relativeTo and relativeTo:GetName()) or "UIParent",
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end)
        GameMenuFrame._mqolDragHooked = true
    end
end

local function disableDrag()
    GameMenuFrame:SetMovable(false)
    GameMenuFrame:RegisterForDrag()  -- unregister all buttons
end

function GameMenu:ApplyMoveable()
    local db = addon.db.gameMenu
    if db.moveable then
        enableDrag(db)
        applyPosition(db)
    else
        disableDrag()
    end
end

function GameMenu:ResetPosition()
    addon.db.gameMenu.position = nil
    GameMenuFrame:ClearAllPoints()
    GameMenuFrame:SetPoint(DEFAULT_POINT.point, UIParent, DEFAULT_POINT.relativePoint, DEFAULT_POINT.x, DEFAULT_POINT.y)
end

function GameMenu:Apply()
    local scale = (addon.db.gameMenu and addon.db.gameMenu.scale) or DEFAULT_SCALE
    GameMenuFrame:SetScale(scale)
    self:ApplyMoveable()
end

function GameMenu:Initialize()
    if not addon.db.gameMenu then
        addon.db.gameMenu = { scale = DEFAULT_SCALE, moveable = false }
    else
        if addon.db.gameMenu.scale == nil then addon.db.gameMenu.scale = DEFAULT_SCALE end
        if addon.db.gameMenu.moveable == nil then addon.db.gameMenu.moveable = false end
    end
    self:Apply()
end
