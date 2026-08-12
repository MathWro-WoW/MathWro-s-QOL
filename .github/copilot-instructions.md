# MathWroQOL — Copilot Instructions

Full architecture reference: `docs/ARCHITECTURE.md`. Read it before making code changes.

---

## Critical Constraints

- Interface version: `120100` — **single value only** (BigWigs packager breaks on comma-separated)
- TOC filename must match folder exactly: `MathWroQOL.toc` inside `MathWroQOL/`
- All hardcoded addon name strings must use `"MathWroQOL"` (e.g. `ADDON_LOADED` checks)
- `local` everything — no global namespace pollution
  - Exceptions: `MathWroQOL = addon` (Core.lua), `addon.featureName = Feature` for cross-file access
- 4-space indentation, no tabs, no trailing whitespace

---

## Feature Contract

```lua
local _, addon = ...

local MyFeature = { name = "myFeature" }
addon:RegisterFeature(MyFeature)

function MyFeature:Initialize()
    -- Called once on PLAYER_LOGIN. Register hooks and events here.
end

function MyFeature:Apply()
    -- Called by addon:NotifyFeature("myFeature") on settings change.
    -- Re-apply state only. Do NOT re-register hooks here.
end
```

- Provider-dependent features must return early when none of their supported providers are loaded.
  ElvUI-only features must begin with:
  ```lua
  if not ElvUI then return end
  ```

---

## Adding a Feature (4 Surfaces)

1. `Features/MyFeature.lua` — implement feature contract
2. `Features\MyFeature.lua` in `MathWroQOL.toc` (backslash separator)
3. Default values in `Core.lua` `defaults` table under `myFeature = { ... }`
4. UI controls in the correct panel in `Config.lua`

---

## Config.lua Helpers (available in all panels)

| Helper | Purpose |
|---|---|
| `MakePanelScaffold(panel, title, scrollName)` | Scrollable panel content area |
| `MakeCard(parent, anchor, title, desc)` | Card frame; returns `card, content` |
| `MakeSeparator(parent, anchor, offsetY)` | 1px horizontal divider (Frame-wrapped) |
| `MakeCheckbox(parent, label, x, y, get, set)` | Toggle with ElvUI skin support |
| `MakeSliderWithInput(parent, label, min, max, get, set)` | Slider + synced input box |
| `MakeDropdown(parent, options, get, set)` | Dropdown; options are `{ label, value }` |
| `MakeCollapsibleSection(parent, title, isExpanded)` | Expandable section |

Controls should mutate `addon.db.<feature>` then call `addon:NotifyFeature("<name>")`.

---

## Performance — Non-Negotiable Rules

- **No `OnUpdate` polling** for state tracking, cooldowns, or bag scanning. Use events.
  - Exception: time-critical visual feedback with no event equivalent (see `EditModeNudge.lua`)
- **Debounce `BAG_UPDATE`** — fires 50–100× per loot interaction:
  ```lua
  local scanPending = false
  -- in event handler:
  if scanPending then return end
  scanPending = true
  C_Timer.After(0, function() scanPending = false; RebuildIcons() end)
  ```
- **Cooldown caching** — only call `SetCooldown()` when `(start, duration)` actually changes; call `Clear()` (not `SetCooldown(0,0)`) when done

---

## Key WoW API Pitfalls

- `GameMenuFrame` re-centers itself every `OnShow` — re-apply saved position from an `OnShow` hook
- `GameMenuFrame` buttons are pooled — iterate `buttonPool:EnumerateActive()`; use `MainMenuFrameButtonTemplate`, hook `Layout()` not `OnShow`
- `AUCTION_HOUSE_DEFAULT_FILTERS` only exists after `Blizzard_AuctionHouseUI` loads; use `AUCTION_HOUSE_SHOW` (not `AUCTION_HOUSE_OPENED` — doesn't exist)
- `RegisterStateDriver` — last call wins; use an `applying` guard flag when your hook calls it
- ElvUI has **two** fade systems: per-bar `bar.mouseover` and global `bar.inheritGlobalFade` via `AB.fadeParent`. Vehicle logic must handle both.
- `GetInventoryItemID()` is unreliable at `PLAYER_LOGIN` — use `PLAYER_ENTERING_WORLD` instead
- `C_Spell.GetSpellCooldown()` can return `SecretWhenSpellCooldownRestricted` — use `pcall` or prefer `C_Item.GetItemCooldown()` for items

---

## No Build Step

Test by loading in WoW Retail (`_retail_`) and running `/reload` in-game. Errors surface via the default Lua error frame or `!BugGrabber` / `BugSack`.
