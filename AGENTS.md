# AGENTS.md — MathWroQOL

Instructions for AI agents operating in this World of Warcraft addon repository.

## Build / Lint / Test

There is **no build step, linter, or test runner**. Validation is manual: load the addon in WoW Retail (`_retail_`) and `/reload` in-game.

### Per-feature validation

| Feature file | How to test |
|---|---|
| `GameMenu.lua` / `CDMButton.lua` | Press Escape; verify scale, drag, button placement |
| `AuctionFilter.lua` | Open Auction House; confirm filters pre-enabled |
| `CombatLog.lua` | Enter/leave an enabled instance type; confirm logging starts/stops |
| `VehicleBar.lua` | Enter a vehicle with ElvUI loaded; verify bar visibility |
| `EditModeNudge.lua` | Enter Edit Mode; select a frame; verify arrows and coordinates |
| `Config.lua` | Run `/mqol`; verify panels, controls, layout |

Error inspection: default Lua error frame, or `!BugGrabber` / `BugSack`.

### Releases

GitHub Actions only. Tag and push:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Triggers `.github/workflows/release.yml` → `BigWigsMods/packager@v2`. Do NOT use comma-separated `## Interface:` values in the TOC — the packager will produce a broken `release.json`.

## Architecture

### Load order (defined in `MathWroQOL.toc`)

1. **`Core.lua`** — framework: inits `MathWroQOLDB`, applies defaults, exposes `addon:RegisterFeature()` / `addon:NotifyFeature()`
2. **`Config.lua`** — Blizzard settings UI (parent + General / ElvUI Plugins / Edit Mode subcategories), `/mqol` command
3. **`Features/*.lua`** — self-registering modules

### Feature contract

Every feature file follows this pattern:

```lua
local _, addon = ...

local MyFeature = { name = "myFeature" }
addon:RegisterFeature(MyFeature)

function MyFeature:Initialize()  -- called once on PLAYER_LOGIN
    -- hooks, events, one-time setup
    self:Apply()
end

function MyFeature:Apply()  -- called by addon:NotifyFeature("myFeature")
    -- re-apply current settings; do NOT re-register hooks
end
```

### Adding a new feature (4 surfaces)

1. Create `Features/MyFeature.lua` with the contract above
2. Add `Features\MyFeature.lua` to `MathWroQOL.toc` (backslash path separator)
3. Add default values to `defaults` table in `Core.lua`
4. Add UI controls to the correct panel in `Config.lua` (`BuildGeneralPanel`, `BuildElvUIPanel`, or `BuildEditModePanel`)

### Settings storage

`addon.db` → `MathWroQOLDB` (SavedVariables). Each feature owns `addon.db.<featureName>` (e.g. `addon.db.gameMenu`, `addon.db.vehicleBar`). New keys get defaults via `applyDefaults()` in `Core.lua`.

## Code Style

### Language & environment

- **Lua 5.1** (WoW embedded). No external modules. All WoW API is global.
- **Interface version**: `120001` (Midnight 12.0.1). Single value in TOC.
- **TOC filename must match folder**: `MathWroQOL.toc` in `MathWroQOL/`. Hardcoded addon name strings must use `"MathWroQOL"`.

### Formatting

- 4-space indentation, no tabs
- `local` everything — avoid polluting the global namespace (exception: `MathWroQOL = addon` in Core.lua)
- Section headers use `-- ── Section Name ──...` comment bars
- Inline comments on the same line use `--` with two spaces before
- Multiline block comments at function/section level for explaining non-obvious behavior
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

### Error handling

- No pcall/xpcall — let errors surface to `!BugGrabber`. WoW addons should not silently swallow errors.
- Guard with nil checks before accessing nested tables: `if not db or not db.enabled then return end`
- Use `return` early to short-circuit, not deep nesting

### Hooking

- Use `hooksecurefunc()` — post-hook only, never pre-hook
- When a hook can re-enter itself (e.g. `RegisterStateDriver` hook that calls `RegisterStateDriver`), use an `applying` guard flag
- Avoid hooking mixin tables directly — mixin functions are copied to instances at init. Hook the concrete singleton (e.g. `EditModeSystemSettingsDialog`, not `EditModeSystemMixin`)
- One-time hook registration: use a `local hooked = false` flag or `frame._mqolHookName` sentinel

### ElvUI integration

- ElvUI-dependent files must begin with `if not ElvUI then return end`
- Access ElvUI via `local E = ElvUI[1]`; modules via `E:GetModule("ModuleName", true)`
- Config.lua still builds the ElvUI panel without ElvUI — it disables/greys controls

### Config.lua conventions

- `MakeSeparator(parent, anchor, offsetY)` between sections
- `MakeCheckbox(parent, label, x, y, getValue, setValue)` for toggles
- Always `cb:ClearAllPoints()` before `cb:SetPoint(...)` on reused widgets
- FontStrings that may wrap: set `SetWidth()` and `SetJustifyH("LEFT")`
- Controls mutate `addon.db.<feature>` then call `addon:NotifyFeature("<name>")`

### Event registration

- Some features register event frames at file top level (not inside `Initialize()`) when the handler must exist before a LoD Blizzard addon loads or before early zone events fire. See `AuctionFilter.lua` and `CombatLog.lua` as reference.

### Frame creation

- Prefer lazy creation (`local function EnsureOverlay()` pattern) for UI that may never be needed
- Named globals get the `MathWroQOL_` prefix
- Set `FrameStrata` and `FrameLevel` explicitly for overlay/dialog-level frames

## Performance Rules

These rules apply to every feature. Violating them causes frame drops, animation jitter, or CPU spikes that are hard to diagnose in-game.

### No OnUpdate polling

Never use `frame:SetScript("OnUpdate", ...)` to track cooldowns, check bag contents, or monitor state. Use events instead. The only permitted OnUpdate usage is for time-critical visual feedback that has no event equivalent (e.g. coordinate display during a drag — see `EditModeNudge.lua`).

### Debounce high-frequency events

`BAG_UPDATE` fires 50–100× during a single loot interaction. Any handler that scans bags or rebuilds UI must debounce using a pending flag + `C_Timer.After(0, ...)`:

```lua
local scanPending = false
frame:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE" then
        if scanPending then return end
        scanPending = true
        C_Timer.After(0, function()
            scanPending = false
            RebuildIcons()  -- runs once per loot event, not 50×
        end)
    end
end)
```

Other high-frequency events to treat the same way: `UNIT_AURA` (when monitoring many units).

### Cooldown frames are self-managing

`CooldownFrameTemplate` animates the swipe and countdown text internally — no OnUpdate or timer needed from the addon. Two rules:

1. **Only call `CooldownFrame_Set()` / `SetCooldown()` when the cooldown state actually changes.** Calling it every `SPELL_UPDATE_COOLDOWN` unconditionally resets the swipe animation mid-cycle, causing visible jitter. Cache `(start, duration)` per button and skip the call if unchanged.
2. **Call `Clear()` when the cooldown ends**, not just `SetCooldown(0, 0)`.

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

### Event scope — register only what you need

- Register events on a dedicated local frame, not on an existing feature frame that handles unrelated events.
- Unregister events when a feature is disabled (call `frame:UnregisterAllEvents()` in `Apply()` when `enabled == false`, re-register when enabled).
- `SPELL_UPDATE_COOLDOWN` and `BAG_UPDATE_COOLDOWN` are safe to handle synchronously — they fire at sensible rates and per-spell/item queries are cheap.

## WoW API Pitfalls

- `GameMenuFrame` position resets every `OnShow` — re-apply from hook
- `GameMenuFrame` buttons are pooled (`buttonPool:EnumerateActive()`); use `MainMenuFrameButtonTemplate`, not `GameMenuButtonTemplate`
- `AUCTION_HOUSE_DEFAULT_FILTERS` only exists after `Blizzard_AuctionHouseUI` loads. Event: `AUCTION_HOUSE_SHOW` (not `AUCTION_HOUSE_OPENED`)
- `RegisterStateDriver` — last call wins; hooks must re-register to override
- ElvUI has **two** fade systems: individual mouseover (per-bar `bar.mouseover`) and global fade parent (`bar.inheritGlobalFade`). Vehicle visibility must handle both.

## Git Conventions

- Commit messages: `type: short description` (e.g. `feat:`, `fix:`, `docs:`)
- Body explains *why*, not *what*
- Do NOT commit `.github/copilot-instructions.md` changes without explicit request
