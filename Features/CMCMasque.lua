local _, addon = ...

local CMCMasque = { name = "cmcMasque" }
addon:RegisterFeature(CMCMasque)

local VIEWERS = {
    essential = {
        frameName = "EssentialCooldownViewer",
        label = "CMC Essential",
        staticID = "MathWroQOL_CMC_Essential",
    },
    utility = {
        frameName = "UtilityCooldownViewer",
        label = "CMC Utility",
        staticID = "MathWroQOL_CMC_Utility",
    },
    buffIcons = {
        frameName = "BuffIconCooldownViewer",
        label = "CMC Buff Icons",
        staticID = "MathWroQOL_CMC_BuffIcons",
    },
}

local VIEWER_ORDER = { "essential", "utility", "buffIcons" }

local groups
local registered = {}
local hooked = false

local function isAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function dependenciesReady()
    return isAddonLoaded("CooldownManagerCentered") and LibStub and LibStub("Masque", true)
end

local function getViewerEnabled(db, key)
    return db and db.viewers and db.viewers[key] == true
end

local function getGroups()
    if groups then return groups end

    local MSQ = LibStub and LibStub("Masque", true)
    if not MSQ then return nil end

    groups = {}
    for _, key in ipairs(VIEWER_ORDER) do
        local def = VIEWERS[key]
        groups[key] = MSQ:Group("MathWroQOL", def.label, def.staticID)
        registered[key] = registered[key] or {}
    end

    return groups
end

local function getButtonRegions(button)
    if not button or not button.Icon then return nil end

    local regions = {
        Icon = button.Icon,
    }

    if button.Cooldown then
        regions.Cooldown = button.Cooldown
    end

    if button.Count then
        regions.Count = button.Count
    elseif button.CountText then
        regions.Count = button.CountText
    elseif button.ChargeCount and button.ChargeCount.Current then
        regions.Count = button.ChargeCount.Current
    elseif button.Applications and button.Applications.Applications then
        regions.Count = button.Applications.Applications
    end

    return regions
end
local function getViewerButtons(viewer)
    if not viewer then return {} end
    if viewer.GetItemFrames then
        return viewer:GetItemFrames()
    end
    return { viewer:GetChildren() }
end

local function unregisterViewer(key)
    if not groups or not groups[key] or not registered[key] then return end

    for button in pairs(registered[key]) do
        groups[key]:RemoveButton(button)
    end

    registered[key] = {}
end

local function registerViewer(key)
    local db = addon.db and addon.db.cmcMasque
    if not db or not db.enabled or not getViewerEnabled(db, key) then
        unregisterViewer(key)
        return
    end

    local allGroups = getGroups()
    local group = allGroups and allGroups[key]
    local viewer = _G[VIEWERS[key].frameName]
    if not group or not viewer then return end

    local active = {}
    for _, child in ipairs(getViewerButtons(viewer)) do
        local regions = getButtonRegions(child)
        if regions then
            active[child] = true
            if not registered[key][child] then
                group:AddButton(child, regions, "Legacy", true)
                registered[key][child] = true
            end
            group:ReSkin(child)
        end
    end

    for button in pairs(registered[key]) do
        if not active[button] then
            group:RemoveButton(button)
            registered[key][button] = nil
        end
    end
end

local function refreshViewer(key)
    if not dependenciesReady() then return end
    registerViewer(key)
end

local function refreshAll()
    if not dependenciesReady() then return end

    for _, key in ipairs(VIEWER_ORDER) do
        registerViewer(key)
    end
end

local function clearAll()
    for _, key in ipairs(VIEWER_ORDER) do
        unregisterViewer(key)
    end
end

local function hookViewers()
    if hooked then return end

    for _, key in ipairs(VIEWER_ORDER) do
        local viewerKey = key
        local viewer = _G[VIEWERS[key].frameName]
        if viewer and viewer.RefreshLayout then
            hooksecurefunc(viewer, "RefreshLayout", function()
                C_Timer.After(0, function()
                    refreshViewer(viewerKey)
                end)
            end)
        end
    end

    hooked = true
end

function CMCMasque:Apply()
    local db = addon.db and addon.db.cmcMasque
    if not db or not db.enabled or not dependenciesReady() then
        clearAll()
        return
    end

    hookViewers()
    refreshAll()
end

function CMCMasque:Initialize()
    if not dependenciesReady() then return end

    hookViewers()
    self:Apply()
end
