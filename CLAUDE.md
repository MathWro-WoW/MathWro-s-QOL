# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Drive Layout

- Addon source: `/run/media/mathwro/2TBM2/World of Warcraft/_retail_/Interface/AddOns/`
- SavedVariables / session logs: `/run/media/mathwro/SSD/World of Warcraft/_retail_/WTF/`
- These are two separate WoW installs. Only the 2TBM2 install is actively played.
- Do not use ElvUI_SLE on the SSD install as a reference — it is outdated.

## Critical: TOC Filename

The `.toc` file name must exactly match the addon folder name: `MathWroQOL.toc` inside `MathWroQOL/`. Mismatch = addon invisible in game. Any hardcoded addon name strings in Lua (e.g. `ADDON_LOADED` checks) must also use `"MathWroQOL"`.

## Testing

No build step or test runner. Test by loading the addon in WoW retail (`_retail_`) and using `/reload` in-game after file changes. Check for Lua errors in the default error frame or via `!BugGrabber`/`BugSack` if installed.

## Interface Version

Target: `120001` (Midnight, patch 12.0.1). Use a single value — the BigWigs packager does not support comma-separated interface values and will generate a broken `release.json` if you do.

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

## GameMenuFrame Button Insertion (Retail)

Retail uses a `buttonPool` system — named globals like `GameMenuButtonShop` do not exist. Key patterns:
- Use `MainMenuFrameButtonTemplate` (200×35) not `GameMenuButtonTemplate`
- Hook `hooksecurefunc(GameMenuFrame, "Layout", fn)` — NOT `OnShow`. `Layout()` runs after button pooling; `OnShow` is too early
- Find pool buttons by iterating `GameMenuFrame.buttonPool:EnumerateActive()` and matching `button:GetText()` against globals like `_G.BLIZZARD_STORE`
- ElvUI stores its game menu button as `GameMenuFrame.ElvUI` (not a named global)
- To nudge pool buttons below insertion point: compare `button:GetTop()` against `anchorBtn:GetBottom()`, then `button:SetPoint(point, relativeTo, relativePoint, x, y - offset)`
- Apply ElvUI skin via `hooksecurefunc(GameMenuFrame, "InitButtons", fn)` → `E:GetModule("Skins"):HandleButton(btn, nil, nil, nil, true)`

## ElvUI Action Bar Fade System

Two parallel fade systems exist — individual and global:
- **Individual mouseover** (`bar.mouseover = true`): fades via `E:UIFrameFadeOut(bar, ...)` on `Bar_OnLeave`. NOT affected by ElvUI's `mouseLock`
- **Global fade parent** (`bar.inheritGlobalFade = true`): parented to `AB.fadeParent`; respects `mouseLock` which ElvUI sets true for vehicle/override/combat states
- `AB:PLAYER_ENTERING_WORLD` does NOT call `UpdateButtonSettings` — state drivers are only re-registered during `AB:Initialize()` and explicit `Apply()` calls
- Bar 1 default visibility in Retail: `[petbattle] hide; show` (no vehicleui/overridebar). Bars 2–10: `[vehicleui][petbattle][overridebar] hide; show`
- Vehicle-like state detection: `HasOverrideActionBar() or HasVehicleActionBar() or IsPossessBarVisible() or UnitExists("vehicle")`. Override-bar shapeshifts trigger `HasOverrideActionBar()` but NOT `UNIT_ENTERED_VEHICLE`
- Relevant events: `UPDATE_OVERRIDE_ACTIONBAR`, `VEHICLE_UPDATE`, `UNIT_ENTERED_VEHICLE` / `UNIT_EXITED_VEHICLE`
