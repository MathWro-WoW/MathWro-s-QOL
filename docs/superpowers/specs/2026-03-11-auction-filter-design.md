# Auction House Filter Feature — Design

## Summary

Auto-enable selected Auction House filters each time the player opens the AH. Two independent toggles: "Current expansion only" and "Usable only". Both default off except "Current expansion only" which defaults on.

## Mechanism

Blizzard exposes a global table `AUCTION_HOUSE_DEFAULT_FILTERS` (indexed by `Enum.AuctionHouseFilter.*` integers) that the AH reads each time it opens to initialize filter state. Setting entries in this table is sufficient to apply filters automatically.

Relevant enum keys:
- `Enum.AuctionHouseFilter.CurrentExpansionOnly`
- `Enum.AuctionHouseFilter.UsableOnly`

Reference: `Blizzard_AuctionHouseUI\Blizzard_AuctionHouseUtil.lua:31`

## Feature Contract

- **File:** `Features/AuctionFilter.lua`
- **Key:** `"auctionFilter"`
- **DB defaults:** `{ currentExpansionOnly = true, usableOnly = false }`

## Behavior

1. **`ADDON_LOADED` → `"Blizzard_AuctionHouseUI"`**: Ensure `AUCTION_HOUSE_DEFAULT_FILTERS` exists, then set both entries based on db flags.
2. **`AUCTION_HOUSE_OPENED`**: Re-apply both entries so any in-session user changes are reset on next open.
3. **`Apply()`**: Update `AUCTION_HOUSE_DEFAULT_FILTERS` immediately if the table already exists (e.g. after settings change mid-session).

Only the two managed entries are written — all other filter defaults (rarity, uncollected, upgrades, etc.) are untouched.

## Config (General Panel)

Two checkboxes added to `BuildGeneralPanel()`:
- "Auto-enable 'Current expansion only' filter"
- "Auto-enable 'Usable only' filter"

## Files Changed

| File | Change |
|------|--------|
| `Features/AuctionFilter.lua` | New file |
| `MathWro QOL_Mainline.toc` | Add `Features\AuctionFilter.lua` |
| `Core.lua` | Add `auctionFilter` defaults |
| `Config.lua` | Add two checkboxes to General panel |
