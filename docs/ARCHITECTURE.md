# MathWroQOL — Architecture Reference

Canonical reference for architecture, code style, and WoW API patterns.
All AI instruction files (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`) defer to this document.

---

## Interface Version & TOC

- Target: `120001` (Midnight 12.0.1). **Single value only** — the BigWigs packager breaks on comma-separated values.
- The `.toc` filename must exactly match the addon folder name: `MathWroQOL.toc` inside `MathWroQOL/`. Mismatch = addon invisible in-game.
- Any hardcoded addon name strings (e.g. `ADDON_LOADED` checks) must use `"MathWroQOL"`.
- Optional addon integrations are declared via `## OptionalDeps:` so ElvUI, Masque, and CooldownManagerCentered load first when present.

---

## Libraries

Loaded before `Core.lua`:

- `Libs\LibStub\LibStub.lua`
- `Libs\LibEditMode\LibEditMode.lua` plus `pools.lua` and `widgets\*.lua` — enables native Edit Mode glow + drag for custom frames

---

## Load Order

Defined in `MathWroQOL.toc`:

1. `Libs\LibStub\LibStub.lua`
2. `Libs\LibEditMode\LibEditMode.lua`
3. `Libs\LibEditMode\pools.lua`
4. `Libs\LibEditMode\widgets\button.lua`
5. `Libs\LibEditMode\widgets\checkbox.lua`
6. `Libs\LibEditMode\widgets\dialog.lua`
7. `Libs\LibEditMode\widgets\divider.lua`
8. `Libs\LibEditMode\widgets\dropdown.lua`
9. `Libs\LibEditMode\widgets\expander.lua`
10. `Libs\LibEditMode\widgets\extension.lua`
11. `Libs\LibEditMode\widgets\slider.lua`
12. `Libs\LibEditMode\widgets\colorpicker.lua`
13. `Core.lua`
14. `Config.lua`
15. `Features\VehicleBar.lua`
16. `Features\BuffHealthColor.lua`
17. `Features\GameMenu.lua`
18. `Features\CDMButton.lua`
19. `Features\CMCMasque.lua`
20. `Features\AuctionFilter.lua`
21. `Features\CombatLog.lua`
22. `Features\EditModeNudge.lua`
23. `Features\CombatTracker.lua`
24. `Features\CombatTracker_Racials.lua`
25. `Features\CombatTracker_Trinkets.lua`
26. `Features\CombatTracker_Consumables.lua`

---

## Core Framework

`Core.lua` is the addon framework. On `ADDON_LOADED`:

- Initialises `MathWroQOLDB` (SavedVariables)
- Runs `applyDefaults()` recursively — merges missing keys from `defaults` without overwriting saved values
- Exposes `addon:RegisterFeature(feature)` for module self-registration
- Exposes `addon:NotifyFeature(name)` to call `feature:Apply()` when settings change

On `PLAYER_LOGIN`, iterates registered features and calls `feature:Initialize()` on each.

---

## Feature Contract

Every feature file follows this pattern:

```lua
local _, addon = ...

local MyFeature = { name = "myFeature" }
addon:RegisterFeature(MyFeature)

function MyFeature:Initialize()
    -- Called once on PLAYER_LOGIN.
    -- Register hooks, events, one-time setup here.
    -- Safe to call self:Apply() at the end to apply initial state.
end

function MyFeature:Apply()
    -- Called by addon:NotifyFeature("myFeature") when settings change.
    -- Re-apply current settings. Do NOT re-register hooks here.
end
```

Every feature must have a top-level `enabled = false` default in `Core.lua` unless there is a documented reason to ship it on. Treat `enabled` as a hard execution gate: `Initialize()`, `Apply()`, event handlers, hooks, timers, and helper callbacks must return before doing feature work when `addon.db.<featureName>.enabled` is false. Disabled features may keep only the inert registration needed to notice settings changes or required early Blizzard addon events; they must not scan state, update frames, register recurring timers, or process gameplay events while disabled.

Features that have no lifecycle needs (e.g. `AuctionFilter`, `CombatLog`) may have no-op or absent `Initialize()`/`Apply()` and instead register event frames at file top level — see [Event Registration](#event-registration).

---

## Adding a New Feature

Four surfaces to wire:

1. Create `Features/MyFeature.lua` with the feature contract above
2. Add `Features\MyFeature.lua` to `MathWroQOL.toc` (use backslash path separator in TOC)
3. Add default values to the `defaults` table in `Core.lua`, including top-level `enabled = false`
4. Add UI controls to the correct panel function in `Config.lua`

---

## Settings Storage

`addon.db` is a direct reference to `MathWroQOLDB`. Each feature owns `addon.db.<featureName>` (e.g. `addon.db.gameMenu`, `addon.db.vehicleBar`). New keys get defaults from `applyDefaults()` in `Core.lua` — add new defaults to the `defaults` table there.

---

## Feature Inventory

| Feature | File(s) | DB key | Notes |
|---|---|---|---|
| Vehicle Bar | `VehicleBar.lua` | `vehicleBar` | ElvUI-only; keeps action bars visible in vehicle encounters |
| Game Menu | `GameMenu.lua` | `gameMenu` | Drag, scale, persist position of Escape menu |
| CDM Button | `CDMButton.lua` | `cdmButton` | Injects CDM button into Escape menu; `/wa` and `/cm` slashes |
| CMC Masque | `CMCMasque.lua` | `cmcMasque` | Registers CooldownManagerCentered Essential, Utility, and Buff Icon viewer buttons with Masque when both addons are loaded |
| Auction Filter | `AuctionFilter.lua` | `auctionFilter` | Pre-enables AH filters on open |
| Combat Log | `CombatLog.lua` | `combatLog` | Auto-starts/stops combat logging by instance type and level cap |
| Edit Mode Nudge | `EditModeNudge.lua` | `editModeNudge` | Arrow buttons + coordinate display for native Edit Mode frames and LibEditMode-registered custom frames |
| Buff Health Color | `BuffHealthColor.lua` | `buffHealthColor` | ElvUI health bar recoloring for configured player-cast buffs such as Atonement, Lifebloom, Prayer of Mending, Riptide, Beacon of the Savior, Renewing Mist, and custom spell IDs. Each buff profile has frame, color, and specialization filters. Built-ins expose only relevant class specs; custom IDs infer spec filters from the player spellbook when possible |
| Combat Tracker | `CombatTracker.lua` + 3 section files | `combatTracker` | Cooldown icon display system (racials, trinkets, consumables) |

---

## CombatTracker Subsystem

`CombatTracker.lua` is a **framework**, not a simple feature. It exposes a `RegisterSection(def)` API that the three section files use to self-register:

```lua
-- In a section file (e.g. CombatTracker_Racials.lua):
local CT = addon.combatTracker  -- set by CombatTracker.lua at load time

local Racials = { name = "racials", hostKey = "frames.racials" }
CT:RegisterSection(Racials)

function Racials:RebuildIcons() ... end
function Racials:UpdateCooldowns() ... end
function Racials:Initialize() ... end
```

Key CT methods available to sections:

| Method | Purpose |
|---|---|
| `CT:RegisterSection(def)` | Self-registration for section plugins |
| `CT:CreateButton(parent)` | Pool factory — 36×36 button with icon, cooldown frame, stack count text |
| `CT:LayoutSection(section)` | Stable-anchor grid/horizontal/vertical layout engine |
| `CT:CreateSectionFrame(section)` | Creates anchor frame, registers with LibEditMode, hooks EditModeNudge overlay |
| `CT:ApplyMasque(section)` | Lazy Masque group creation + button registration |
| `CT:UpdateButtonCooldown(btn, start, dur)` | pcall-safe cooldown setter; calls `Clear()` if `duration < 1.5s` |

`CombatTracker` exposes itself globally so section files can reference the parent:
```lua
addon.combatTracker = CT  -- in CombatTracker.lua top-level
```

`EditModeNudge` similarly exposes itself for CombatTracker to attach the nudge overlay to section frames:
```lua
addon.editModeNudge = EditModeNudge  -- in EditModeNudge.lua top-level
```

---

## Config.lua Panels

Settings panels registered via `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterCanvasLayoutSubcategory` (TWW API), with fallback to `InterfaceOptions_AddCategory`:

- **Parent** — "MathWro QOL" (container, no interactive controls)
  - **General** — GameMenu scaling / drag / reset position; CombatLog instance toggles + level filter
  - **Combat Tracker** — master enable; per-section collapsible blocks (Racials, Trinkets, Consumables)
  - **ElvUI Plugins** — VehicleBar per-bar visibility toggles
  - **CDM Plugins** — CooldownManagerCentered compatibility options such as Masque skinning
  - **Edit Mode** — EditModeNudge enable toggle
  - **Debug** — troubleshooting actions such as Buff Health Color unit diagnostics

`/mqol` opens the panel via `Settings.OpenToCategory(parentCat:GetID())` (fallback: `InterfaceOptionsFrame_OpenToCategory`).

---

## Config.lua Helper Functions

All are `local function` defined in `Config.lua`. Not global.

| Helper | Signature | Purpose |
|---|---|---|
| `MakePanelScaffold` | `(panel, titleText, scrollName)` | Titled panel with scrollable content area; returns scroll child frame |
| `MakeCard` | `(parent, anchor, title, desc)` | Card frame with title + description; returns `card, content` |
| `MakeSeparator` | `(parent, anchor, offsetY)` | 1px horizontal line (Frame-wrapped, not bare Texture — see pitfalls) |
| `MakeCheckbox` | `(parent, label, x, y, getValue, setValue)` | Toggle checkbox with ElvUI skin support |
| `MakeSliderWithInput` | `(parent, label, min, max, get, set)` | Slider + input box with internal sync guard |
| `MakeDropdown` | `(parent, options, getValue, setValue, notifyFeature)` | Dropdown; options are `{ label, value, icon }` tables and may include `{ label, action }` rows; optional feature notify name defaults to `combatTracker` |
| `MakeCollapsibleSection` | `(parent, title, isExpanded)` | Expandable section with header arrow |
| `ApplyFrameBackdrop` | `(frame, useFadeColor)` | Backdrop with white borders; uses ElvUI colors when loaded |
| `SetChildrenEnabled` | `(container, enabled)` | Recursively enables/disables and fades all child widgets |
| `MakeOptionRow` | `(parent, labelText, controlFn)` | **Local to `BuildCombatTrackerPanel` only.** Label-left / control-right row layout |

---

## Config.lua Pitfalls

- **Bare Texture two-point anchoring**: A `Texture` with two anchor points on different edges (e.g. `TOPLEFT` + `RIGHT`) will not reliably return `GetBottom()` during initial layout — WoW defers resolution and returns nil. This breaks any code that reads bounds (like `SetBottomWidget`). Wrap in a 1px-height Frame instead; Frames resolve deferred anchors correctly. `MakeSeparator` is a Frame wrapping a texture for exactly this reason.
- **MakeCard content anchoring**: The content frame inside `MakeCard` must not set both `TOPLEFT` and `TOPRIGHT` with different Y offsets — WoW averages mismatched Y values on same-edge anchors, pushing content behind the card header. Use `TOPLEFT` for position + `RIGHT` for width constraint.
- **MakeCollapsibleSection arrows**: Use `Soulbinds_Collection_CategoryHeader_Expand` / `Collapse` atlas textures. WoW's default fonts lack `▸`/`▾`.
- **Always `ClearAllPoints()` before `SetPoint()`** on reused/repositioned widgets.
- **FontStrings that may wrap**: set `SetWidth()` and `SetJustifyH("LEFT")` explicitly.
- Controls should mutate `addon.db.<feature>` then call `addon:NotifyFeature("<name>")` to push the change back to the feature.

---

## Code Style

### Language & Environment

- **Lua 5.1** (WoW embedded). No external modules. All WoW API is global.
- No `pcall`/`xpcall` — let errors surface to `!BugGrabber`. Don't silently swallow errors.
- Guard with nil checks before nested table access: `if not db or not db.enabled then return end`
- Use early `return` to short-circuit, not deep nesting.

### Formatting

- 4-space indentation, no tabs
- `local` everything — avoid polluting the global namespace
  - Exceptions: `MathWroQOL = addon` in Core.lua; `addon.combatTracker = CT` / `addon.editModeNudge = EditModeNudge` for cross-file feature access
- Section headers: `-- ── Section Name ──...` comment bars
- Inline comments: `--` with two spaces before on the same line
- No trailing whitespace

### Naming

| Kind | Convention | Example |
|---|---|---|
| Feature table | PascalCase | `local VehicleBar = { name = "vehicleBar" }` |
| Feature `.name` key | camelCase | `"editModeNudge"` |
| Local functions | camelCase | `local function applyFilters()` |
| Feature methods | PascalCase | `function MyFeature:Initialize()` |
| Constants | UPPER_SNAKE | `local COORD_UPDATE_INTERVAL = 0.05` |
| Guard flags | camelCase | `local applying = false` |
| DB keys | camelCase | `addon.db.vehicleBar.enabled` |
| Frame globals | prefixed | `"MathWroQOL_CDMButton"` |

### Cross-file Access

When a feature needs to be accessed by another feature, expose it on the addon table at top level:

```lua
addon.editModeNudge = EditModeNudge  -- EditModeNudge.lua, after local table definition
```

Use `local self = self` as an upvalue inside closures that need method access after `Initialize()` returns.

---

## Hooking Patterns

- Use `hooksecurefunc()` — post-hook only, never pre-hook
- When a hook can re-enter itself (e.g. a `RegisterStateDriver` hook that calls `RegisterStateDriver`), use an `applying` guard flag:

```lua
local applying = false
hooksecurefunc("RegisterStateDriver", function(frame, attr, condition)
    if applying then return end
    applying = true
    -- ... modify and re-register
    applying = false
end)
```

- One-time hook registration: use a `local hooked = false` flag or a `frame._mqolHookName` sentinel to prevent double-hooking
- Hook concrete singletons, not mixin tables (e.g. hook `EditModeSystemSettingsDialog`, not `EditModeSystemMixin` — mixin functions are copied to instances at init)
- `GameMenuFrame`: hook `Layout()` not `OnShow` — `Layout()` runs after button pooling; `OnShow` is too early

---

## Event Registration

Features that must receive events before a LoD Blizzard addon loads, or before early zone events fire, must register their event frame at **file top level** (outside any function):

```lua
-- At top level — ensures frame exists before Blizzard_AuctionHouseUI loads:
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
    -- ...
end)
```

`AuctionFilter.lua` and `CombatLog.lua` are the reference examples. All other features register events inside `Initialize()`.

General event rules:
- Use a dedicated local frame per feature, not an existing frame handling unrelated events
- Unregister events when a feature is disabled: call `frame:UnregisterAllEvents()` in `Apply()` when `enabled == false`, re-register when re-enabled
- `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` are safe to handle synchronously — they fire at sensible rates and per-spell/item queries are cheap

---

## ElvUI Integration

- ElvUI-dependent files must begin with `if not ElvUI then return end`
- Access ElvUI via `local E = ElvUI[1]`; modules via `E:GetModule("ModuleName", true)`
- Config.lua builds the ElvUI panel even when ElvUI is absent — it disables/greys controls rather than hiding them

---

## Performance Rules

### No OnUpdate Polling

Never use `frame:SetScript("OnUpdate", ...)` to track cooldowns, scan bags, or monitor state. Use events. The only permitted `OnUpdate` usage is time-critical visual feedback with no event equivalent (e.g. coordinate display during an Edit Mode drag — see `EditModeNudge.lua`).

### Debounce High-Frequency Events

`BAG_UPDATE` fires 50–100× per loot interaction. `UNIT_AURA` can also fire at high rates. Debounce with a pending flag + `C_Timer.After(0, ...)`:

```lua
local scanPending = false
frame:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE" then
        if scanPending then return end
        scanPending = true
        C_Timer.After(0, function()
            scanPending = false
            RebuildIcons()  -- runs once per loot event, not 50+
        end)
    end
end)
```

### Cooldown Frames Are Self-Managing

`CooldownFrameTemplate` animates the swipe and countdown text internally. Rules:

1. **Only call `SetCooldown()` when state actually changes.** Cache `(start, duration)` per button; skip if unchanged — calling it unconditionally resets the swipe animation mid-cycle causing visible jitter.
2. **Call `Clear()` when the cooldown ends**, not `SetCooldown(0, 0)`.
3. **`SecretWhenSpellCooldownRestricted`**: `C_Spell.GetSpellCooldown()` returns restricted sentinel values during combat. Comparing them (e.g. `start > 0`) raises a Lua error. Strategies by context:
   - **Items/inventory**: Use `C_Item.GetItemCooldown()` or `GetInventoryItemCooldown()` — unrestricted.
   - **Spells (setting on cast)**: In `UNIT_SPELLCAST_SUCCEEDED`, use `GetTime()` for start and `GetSpellBaseCooldown(spellID)` for base duration in ms. Do **not** use `C_Spell.GetSpellInfo(spellID).cooldownMS` — that field does not exist (see pitfalls below).
   - **Spells (clearing on expiry)**: `SPELL_UPDATE_COOLDOWN` fires when cooldown ends; `start` is `0` (a plain zero, not secret) so the clear path works.
   - **Fallback guard**: Wrap reads in `pcall`; if it errors, the spell is actively on cooldown and was already set by the cast handler.

```lua
local function UpdateCooldown(button, start, duration)
    if button._cdStart == start and button._cdDuration == duration then return end
    button._cdStart, button._cdDuration = start, duration
    if duration > 1.5 then
        CooldownFrame_Set(button.cooldown, start, duration, true)
    else
        button.cooldown:Clear()
    end
end
```

### Event Scope — Register Only What You Need

- Register events on a dedicated local frame per feature
- Unregister events when a feature is disabled
- `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` are safe to handle synchronously

---

## WoW API Pitfalls

- **`GameMenuFrame` position**: Blizzard re-centers to `CENTER, UIParent, CENTER` on every `OnShow`. Saved positions must be re-applied from an `OnShow` hook.
- **`GameMenuFrame` buttons (Retail)**: Retail uses a `buttonPool` system — named globals like `GameMenuButtonShop` do not exist. Iterate `GameMenuFrame.buttonPool:EnumerateActive()` and match `button:GetText()` against globals like `_G.BLIZZARD_STORE`. Use `MainMenuFrameButtonTemplate` (200×35), not `GameMenuButtonTemplate`. ElvUI's game menu button is `GameMenuFrame.ElvUI` (not a named global).
- **`AUCTION_HOUSE_DEFAULT_FILTERS`**: Only exists after `Blizzard_AuctionHouseUI` loads (LoD addon). Correct event is `AUCTION_HOUSE_SHOW` (not `AUCTION_HOUSE_OPENED` — that event does not exist).
- **`RegisterStateDriver`**: Last call wins. Hooks that call `RegisterStateDriver` must use an `applying` guard to prevent recursion.
- **ElvUI fade systems**: Two parallel systems exist — individual mouseover fading (`bar.mouseover = true`, fades via `E:UIFrameFadeOut` on `Bar_OnLeave`) and global fade parent (`bar.inheritGlobalFade = true`, parented to `AB.fadeParent`, respects `mouseLock`). ElvUI sets `mouseLock = true` for vehicle/override/combat states. Vehicle visibility logic must handle both.
- **`AB:PLAYER_ENTERING_WORLD`**: Does NOT call `UpdateButtonSettings` — state drivers are only re-registered during `AB:Initialize()` and explicit `Apply()` calls.
- **Vehicle-like state detection**: `HasOverrideActionBar() or HasVehicleActionBar() or IsPossessBarVisible() or UnitExists("vehicle")`. Override-bar shapeshifts trigger `HasOverrideActionBar()` but NOT `UNIT_ENTERED_VEHICLE`.
- **Inventory API availability**: `GetInventoryItemID()` and related calls are not reliable at `PLAYER_LOGIN`. Use `PLAYER_ENTERING_WORLD` instead (see `CombatTracker_Trinkets.lua`).
- **`C_Spell.GetSpellInfo()` has no cooldown field**: The `SpellInfo` struct only contains `name`, `iconID`, `originalIconID`, `castTime`, `minRange`, `maxRange`, `spellID`, `rank`. There is no `cooldownMS`. To get a spell's base cooldown, use `GetSpellBaseCooldown(spellID)` which returns `cooldownMS, gcdMS` (both in milliseconds, unrestricted).
- **ElvUI skinning game menu button**: Apply via `hooksecurefunc(GameMenuFrame, "InitButtons", fn)` → `E:GetModule("Skins"):HandleButton(btn, nil, nil, nil, true)`. Guard with a `IsSkinned` flag to avoid re-skinning.
- **Lazy frame creation**: Prefer `local function EnsureWidget()` pattern for UI that may never be needed. Named globals get the `MathWroQOL_` prefix and explicit `FrameStrata`/`FrameLevel`.
