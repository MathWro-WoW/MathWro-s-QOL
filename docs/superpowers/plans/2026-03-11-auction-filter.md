# Auction House Filter Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-enable "Current expansion only" and/or "Usable only" AH filters each time the player opens the Auction House, controlled by two independent toggles in the General settings panel.

**Architecture:** Blizzard exposes `AUCTION_HOUSE_DEFAULT_FILTERS` (a global table keyed by `Enum.AuctionHouseFilter.*` integers) which the AH reads each time it opens. The feature writes the two managed entries into this table on `ADDON_LOADED` for `Blizzard_AuctionHouseUI` and again on every `AUCTION_HOUSE_OPENED`. No widget manipulation needed.

**Tech Stack:** WoW Retail Lua addon (interface 120001). No build step. Test by `/reload` in-game and opening the AH.

---

## Chunk 1: Core feature file and registration

**Files:**
- Create: `Features/AuctionFilter.lua`
- Modify: `MathWroQOL.toc` (add load entry)
- Modify: `Core.lua` (add defaults)

### Task 1: Add DB defaults

**Files:**
- Modify: `Core.lua`

- [ ] **Step 1: Add `auctionFilter` defaults to the `defaults` table in `Core.lua`**

In `Core.lua`, find the `defaults` table (lines 6–16) and add:

```lua
    auctionFilter = {
        currentExpansionOnly = true,
        usableOnly = false,
    },
```

The full `defaults` table should look like:

```lua
local defaults = {
    vehicleBar = {
        enabled = true,
        bars = { [1] = true },
    },
    cdmButton = {
        enabled = true,
        slashWA = true,
        slashCM = true,
    },
    auctionFilter = {
        currentExpansionOnly = true,
        usableOnly = false,
    },
}
```

- [ ] **Step 2: Register the TOC entry**

In `MathWroQOL.toc`, add after `Features\CDMButton.lua`:

```
Features\AuctionFilter.lua
```

- [ ] **Step 3: Commit**

```bash
git add Core.lua MathWroQOL.toc
git commit -m "feat: add auctionFilter defaults and TOC entry"
```

---

### Task 2: Create the feature file

**Files:**
- Create: `Features/AuctionFilter.lua`

- [ ] **Step 1: Create `Features/AuctionFilter.lua`**

```lua
local _, addon = ...

local AuctionFilter = { name = "auctionFilter" }
addon:RegisterFeature(AuctionFilter)

-- Write the two managed filter entries into AUCTION_HOUSE_DEFAULT_FILTERS.
-- Only touches CurrentExpansionOnly and UsableOnly — all other entries untouched.
local function applyFilters()
    if not AUCTION_HOUSE_DEFAULT_FILTERS then return end
    local db = addon.db.auctionFilter
    if not db then return end
    AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.CurrentExpansionOnly] = db.currentExpansionOnly == true
    AUCTION_HOUSE_DEFAULT_FILTERS[Enum.AuctionHouseFilter.UsableOnly] = db.usableOnly == true
end

function AuctionFilter:Apply()
    applyFilters()
end

function AuctionFilter:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("AUCTION_HOUSE_OPENED")
    frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_AuctionHouseUI" then
            -- Blizzard_AuctionHouseUI just loaded; AUCTION_HOUSE_DEFAULT_FILTERS now exists.
            self:UnregisterEvent("ADDON_LOADED")
            applyFilters()
        elseif event == "AUCTION_HOUSE_OPENED" then
            -- Intentionally stays registered: re-apply on every open so any
            -- in-session user changes to the filter are reset each time.
            applyFilters()
        end
    end)
end
```

- [ ] **Step 2: Reload and verify no Lua errors**

In-game: `/reload`, then open the AH. Check the default error frame or BugSack for errors.

- [ ] **Step 3: Verify filters are applied**

Open the AH, click the Filter button. Confirm "Current expansion only" is checked and "Usable only" is unchecked. Close and reopen the AH to confirm they reset correctly even if you toggle them manually.

- [ ] **Step 4: Commit**

```bash
git add Features/AuctionFilter.lua
git commit -m "feat: add AuctionFilter feature — auto-enable AH filters on open"
```

---

## Chunk 2: Settings UI

**Files:**
- Modify: `Config.lua` (add two checkboxes to `BuildGeneralPanel`)

### Task 3: Add checkboxes to General panel

The General panel uses hardcoded y-offsets. The last existing element is the `/cm` checkbox at y = `-356`. Add the new AH Filter section below it.

- [ ] **Step 1: Add the AH Filter section to `BuildGeneralPanel` in `Config.lua`**

After the `/cm` checkbox block (around line 137, before `return panel`), add:

```lua
    -- ── Auction House Filters ─────────────────────────────────────────────────

    local ahLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ahLabel:SetPoint("TOPLEFT", cmCB, "BOTTOMLEFT", 0, -24)
    ahLabel:SetText("Auction House Filters")

    local ahDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ahDesc:SetPoint("TOPLEFT", ahLabel, "BOTTOMLEFT", 0, -4)
    ahDesc:SetText("Automatically enable selected filters each time you open the Auction House.")

    local ahExpCB = MakeCheckbox(panel, "Auto-enable 'Current expansion only' filter", 16, -418,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.currentExpansionOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.currentExpansionOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )

    local ahUsableCB = MakeCheckbox(panel, "Auto-enable 'Usable only'", 16, -444,
        function() return addon.db.auctionFilter and addon.db.auctionFilter.usableOnly end,
        function(val)
            if not addon.db.auctionFilter then addon.db.auctionFilter = {} end
            addon.db.auctionFilter.usableOnly = val
            addon:NotifyFeature("auctionFilter")
        end
    )
```

**Note on y-offsets:** The existing checkboxes use absolute y-offsets from the panel's `TOPLEFT`. The values `-418` and `-444` continue the pattern after the last checkbox at `-356` (26px per row). Adjust if visual spacing looks off in-game.

- [ ] **Step 2: Reload and verify UI**

`/reload`, open Interface → MathWro QOL → General. Confirm the "Auction House Filters" section appears with both checkboxes. Confirm the "Current expansion only" checkbox is ticked by default and "Usable only" is not.

- [ ] **Step 3: Verify toggle works**

Uncheck "Auto-enable 'Current expansion only'", open the AH, confirm the filter is NOT pre-checked. Re-enable it, open the AH, confirm it IS pre-checked again.

- [ ] **Step 4: Commit**

```bash
git add Config.lua
git commit -m "feat: add AH filter toggles to General settings panel"
```
