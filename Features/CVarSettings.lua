local _, addon = ...

local CameraDistance = { name = "cameraDistance" }
addon:RegisterFeature(CameraDistance)

local MAX_CAMERA_DISTANCE_CVAR = "cameraDistanceMaxZoomFactor"
local MAX_CAMERA_DISTANCE = "2.6"

function CameraDistance:Apply()
    local db = addon.db and addon.db.cameraDistance
    if not db or not db.enabled then return end
    if GetCVar(MAX_CAMERA_DISTANCE_CVAR) ~= MAX_CAMERA_DISTANCE then
        SetCVar(MAX_CAMERA_DISTANCE_CVAR, MAX_CAMERA_DISTANCE)
    end
end

function CameraDistance:Initialize()
    self:Apply()
end

local SpellQueueWindow = { name = "spellQueueWindow" }
addon:RegisterFeature(SpellQueueWindow)

local SPELL_QUEUE_WINDOW_CVAR = "SpellQueueWindow"
local DEFAULT_SPELL_QUEUE_WINDOW = "400"

function SpellQueueWindow:Apply()
    local db = addon.db and addon.db.spellQueueWindow
    if not db or not db.enabled then return end

    local value = tostring(db.value or DEFAULT_SPELL_QUEUE_WINDOW)
    if C_CVar.GetCVar(SPELL_QUEUE_WINDOW_CVAR) ~= value then
        C_CVar.SetCVar(SPELL_QUEUE_WINDOW_CVAR, value)
    end
end

function SpellQueueWindow:Initialize()
    self:Apply()
end
