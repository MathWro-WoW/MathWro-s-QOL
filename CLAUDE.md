# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Drive Layout

- Addon source: `/run/media/mathwro/2TBM2/World of Warcraft/_retail_/Interface/AddOns/`
- SavedVariables / session logs: `/run/media/mathwro/SSD/World of Warcraft/_retail_/WTF/`
- These are two separate WoW installs. Only the 2TBM2 install is actively played.
- Do not use ElvUI_SLE on the SSD install as a reference — it is outdated.

## Critical: TOC Filename

The `.toc` file name must exactly match the addon folder name: `MathWro QOL_Mainline.toc` inside `MathWro QOL/`. Mismatch = addon invisible in game. Any hardcoded addon name strings in Lua (e.g. `ADDON_LOADED` checks) must also use `"MathWro QOL"`.

## Testing

No build step or test runner. Test by loading the addon in WoW retail (`_retail_`) and using `/reload` in-game after file changes. Check for Lua errors in the default error frame or via `!BugGrabber`/`BugSack` if installed.

## Interface Version

Target: `120000, 120001` (Midnight, patch 12.x). Both values are required in the TOC for compatibility with minor patch variants.

## Architecture

**Load order** is defined in `MathWro QOL_Mainline.toc`:
1. `Core.lua` — initialises `MathWroQOLDB` (SavedVariables), applies defaults, exposes `addon:RegisterFeature()` and `addon:NotifyFeature()`
2. `Config.lua` — builds and registers the Blizzard options panel (three panels: parent, General, ElvUI Plugins)
3. `Features/*.lua` — each feature self-registers by calling `addon:RegisterFeature(featureTable)` at file load time

**Feature contract** (`Features/*.lua`):
- Must call `addon:RegisterFeature({ name = "key", ... })` at the top level
- `feature:Initialize()` — called once on `PLAYER_LOGIN`; set up hooks, apply initial state
- `feature:Apply()` — called by `addon:NotifyFeature("key")` whenever settings change; re-apply state without re-registering hooks

**ElvUI-dependent features** must start with `if not ElvUI then return end` to skip all code when ElvUI is absent. The options panel (`Config.lua`) checks `ElvUI ~= nil` at panel build time to disable/grey those controls.

**Settings storage**: `addon.db` is a direct reference to `MathWroQOLDB`. Each feature owns a sub-table keyed by its name (e.g. `addon.db.gameMenu`, `addon.db.vehicleBar`). Defaults for new keys are applied by `applyDefaults()` in `Core.lua` — add new feature defaults to the `defaults` table there.

**Options panel** uses `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterCanvasLayoutSubcategory` (TWW API). The parent category has no interactive controls. Sub-panels are "General" (non-ElvUI features) and "ElvUI Plugins" (ElvUI-dependent features).

## Adding a New Feature

1. Create `Features/MyFeature.lua` with the feature contract above
2. Add `Features\MyFeature.lua` to `MathWro QOL_Mainline.toc` after existing feature lines
3. Add default DB values to the `defaults` table in `Core.lua`
4. Add a UI section to the appropriate sub-panel in `Config.lua` (`BuildGeneralPanel` or `BuildElvUIPanel`)

## Key WoW API Notes

- `RegisterStateDriver(frame, "visibility", condition)` — last call wins; used by VehicleBar to override ElvUI's hide-on-vehicle condition
- `hooksecurefunc("FunctionName", hook)` — post-hook only; use an `applying` flag guard when the hook itself calls the same function to prevent recursion
- `GameMenuFrame` — re-anchored to `CENTER, UIParent, CENTER` by Blizzard on every `OnShow`; position persistence requires an `OnShow` hook to re-apply saved coordinates
