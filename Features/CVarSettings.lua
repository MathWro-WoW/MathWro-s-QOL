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
local LEGACY_SPELL_QUEUE_WINDOW = 400

local function migrateSpellQueueWindow(db)
    if db.migrationVersion then return end

    if db.value == nil or tonumber(db.value) == LEGACY_SPELL_QUEUE_WINDOW then
        db.enabled = false
        db.value = nil
    end
    db.migrationVersion = 1
end

function SpellQueueWindow:Apply()
    local db = addon.db and addon.db.spellQueueWindow
    if not db or not db.enabled or db.value == nil then return end

    local value = tostring(db.value)
    if C_CVar.GetCVar(SPELL_QUEUE_WINDOW_CVAR) ~= value then
        C_CVar.SetCVar(SPELL_QUEUE_WINDOW_CVAR, value)
    end
end

function SpellQueueWindow:Initialize()
    local db = addon.db and addon.db.spellQueueWindow
    if not db then return end

    migrateSpellQueueWindow(db)
    self:Apply()
end
