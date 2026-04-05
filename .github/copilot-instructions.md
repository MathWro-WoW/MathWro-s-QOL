# MathWroQOL Copilot Instructions

## Build, test, and lint

There is no local build step, linter, or automated test runner in this repository.

To validate changes, load the addon in WoW Retail (`_retail_`) and run:

```text
/reload
```

For a single feature check, reload and exercise only the affected surface:

- `GameMenu.lua` / `CDMButton.lua`: open the Escape menu and verify scaling, dragging, or button placement.
- `AuctionFilter.lua`: open the Auction House and confirm the configured filters are pre-enabled.
- `CombatLog.lua`: enter or leave an instance type enabled in `/mqol` and confirm combat logging starts or stops.
- `VehicleBar.lua`: enter a vehicle or override-bar encounter with ElvUI loaded and verify selected bars stay visible.
- `Config.lua`: run `/mqol` and verify the correct panel, control state, and layout.

For error inspection, use the default WoW Lua error frame or `!BugGrabber` / `BugSack` if installed.

Release packaging is handled by GitHub Actions, not a local build command:

```bash
git tag v1.0.0
git push origin v1.0.0
```

That triggers `.github/workflows/release.yml`, which runs `BigWigsMods/packager@v2`.

## High-level architecture

`MathWroQOL.toc` defines the runtime load order:

1. `Core.lua`
2. `Config.lua`
3. `Features/*.lua`

`Core.lua` is the addon framework. It initializes `MathWroQOLDB`, applies defaults recursively, stores the live settings table on `addon.db`, exposes `addon:RegisterFeature(feature)` for module registration, and exposes `addon:NotifyFeature(name)` so the config UI can tell a feature to re-apply itself. On `PLAYER_LOGIN`, it calls `Initialize()` on every registered feature.

`Config.lua` builds the Blizzard settings UI. It creates a parent category plus `General` and `ElvUI Plugins` subcategories, and `/mqol` opens that settings view. Controls usually mutate `addon.db.<feature>` and then call `addon:NotifyFeature("<featureName>")` so the feature can re-apply without re-registering permanent hooks.

Each file in `Features/` is a self-registering module. The common pattern is:

```lua
local _, addon = ...

local Feature = { name = "featureKey" }
addon:RegisterFeature(Feature)
```

The current feature split is:

- `GameMenu.lua`: scales `GameMenuFrame`, enables dragging, and persists custom position.
- `CDMButton.lua`: injects a pooled Escape-menu button and registers `/wa` and `/cm`.
- `AuctionFilter.lua`: writes chosen values into `AUCTION_HOUSE_DEFAULT_FILTERS` whenever the Auction House UI loads or opens.
- `CombatLog.lua`: watches zone transitions and starts or stops combat logging based on selected instance types.
- `VehicleBar.lua`: ElvUI-only behavior that adjusts action-bar visibility and mouseover fade behavior during vehicle or override-bar states.

## Key conventions

The `.toc` filename must exactly match the addon folder name: `MathWroQOL.toc` inside `MathWroQOL/`. If you add `ADDON_LOADED` checks or other hardcoded addon-name comparisons, use `"MathWroQOL"`.

When adding a new feature, wire it through all four surfaces:

1. Create `Features/MyFeature.lua` and register it at top level.
2. Add `Features\MyFeature.lua` to `MathWroQOL.toc`.
3. Add default SavedVariables in the `defaults` table in `Core.lua`.
4. Add controls to the correct panel in `Config.lua`.

Feature modules follow a two-stage lifecycle:

- `Initialize()` runs once on `PLAYER_LOGIN` and is where hooks and event setup belong.
- `Apply()` is for re-applying current settings after `addon:NotifyFeature()` and should not duplicate one-time setup unless the feature intentionally needs that behavior.

Each feature owns a subtable under `addon.db` keyed by its feature name, such as `addon.db.gameMenu` or `addon.db.vehicleBar`.

ElvUI-dependent features should short-circuit at file load with:

```lua
if not ElvUI then return end
```

`Config.lua` still builds the ElvUI panel when ElvUI is absent, but it disables or greys those controls instead of hiding the panel.

The options UI has its own layout conventions:

- Use `MakeSeparator()` between sections.
- Use `MakeCheckbox()` for checkboxes.
- Use `MakeOptionRow(parent, labelText, controlFn)` for label-left / control-right rows (dropdowns, font pickers).
- Use `MakeCollapsibleSection(parent, title, isExpanded)` for expandable section groups.
- Use `MakeCard(parent, anchor, title, description)` for top-level setting cards; returns `card, content`.
- Call `ClearAllPoints()` before repositioning reused widgets.
- Any `FontString` that can wrap should explicitly set `SetWidth()` and `SetJustifyH("LEFT")`.

Config.lua has several layout pitfalls:

- A bare `Texture` with two anchor points on different edges (e.g. `TOPLEFT` + `RIGHT`) will not reliably return `GetBottom()` during initial layout — WoW defers resolution and `GetBottom()` returns nil. This breaks any code that reads bounds (like `SetBottomWidget`). Wrap in a 1px-height Frame instead; Frames resolve deferred anchors correctly.
- `MakeSeparator` is a Frame wrapping a texture (not a bare texture) for the reason above. It uses `TOPLEFT` (anchored to the previous widget) + `RIGHT` (anchored to parent) so its width adapts to the container.
- The content frame inside `MakeCard` must not set both `TOPLEFT` and `TOPRIGHT` with different Y offsets — WoW averages mismatched Y values on same-edge anchors, pushing the content behind the card header. Use `TOPLEFT` for position + `RIGHT` for width constraint.
- `MakeCollapsibleSection` arrows use `Soulbinds_Collection_CategoryHeader_Expand` / `Collapse` atlas textures, not Unicode characters (WoW's default fonts lack `▸`/`▾`).

Some features intentionally register event frames at file top level instead of inside `Initialize()`. Follow that pattern when a frame must exist before a load-on-demand Blizzard UI or early zone event fires. `AuctionFilter.lua` and `CombatLog.lua` are the reference examples.

When hooking APIs that can be re-entered by your own changes, use a guard flag. `VehicleBar.lua` uses an `applying` flag around `RegisterStateDriver()` updates to avoid recursive hook behavior.

Retail Escape-menu button insertion has repo-specific rules:

- Hook `GameMenuFrame:Layout()` with `hooksecurefunc`, not `OnShow`.
- Use `MainMenuFrameButtonTemplate`, not `GameMenuButtonTemplate`.
- Find pooled Blizzard buttons through `GameMenuFrame.buttonPool:EnumerateActive()`.
- If ElvUI is present, its menu button is `GameMenuFrame.ElvUI`.

For `GameMenuFrame` positioning, Blizzard re-centers the frame on every show, so saved positions must be re-applied from an `OnShow` hook.

For Auction House defaults, only touch the managed entries in `AUCTION_HOUSE_DEFAULT_FILTERS`, and use `AUCTION_HOUSE_SHOW` plus `ADDON_LOADED` for `Blizzard_AuctionHouseUI`.

For action-bar visibility work, remember that ElvUI has two separate fade systems: individual mouseover fading on bars and the global fade parent. `VehicleBar.lua` is the reference for handling both.

This addon targets interface version `120001`. Keep that as a single value in the TOC; do not use comma-separated interface versions.
