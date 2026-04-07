# MathWro QOL

A personal World of Warcraft addon for quality-of-life tweaks. Built for Midnight (patch 12.x).

## Features

### General

**Game Menu Scale**
Scale the Escape menu up or down. Range: 0.5× – 2.0×. Persists across sessions.

**Game Menu Dragging**
Make the Escape menu freely draggable. Position is saved and restored on each login. Includes a Reset Position button to snap it back to centre.

**CDM Button**
Adds a "CDM" button to the Escape menu that directly opens the Cooldown Manager window (`CooldownViewerSettings`). Positioned between Shop and AddOns, and grouped below the ElvUI button when ElvUI is active. Also registers `/wa` and `/cm` chat commands as shortcuts. All three (button, `/wa`, `/cm`) can be toggled independently in the options panel.

**Auction House Filters**
Automatically pre-enables selected filters each time you open the Auction House. Two independent toggles in the options panel: "Current expansion only" and "Usable only". Filters are re-applied on every AH open so any in-session manual changes are reset.

### Combat Logging

**Automatic Combat Logging**
Automatically starts and stops combat logging based on instance type. Supports dungeons, raids, scenarios, PvP, and arenas with independent toggles. Optional max-level-only gate to skip logging while levelling. Respects manual stop — if you disable logging mid-instance, the addon will not re-enable it until you leave.

### Combat Tracker

**Racials, Trinkets & Consumables**
Displays icon bars for racial abilities, equipped trinkets, and consumable items (combat potions, healing potions, mana potions, healthstones). Each section tracks cooldowns with swipe animations and optional countdown text. Consumables show stack counts from your inventory. Individual racial abilities can be hidden via the options panel. When both a regular and fleeting version of a consumable are in your bags, only the fleeting version is shown.

**Layout & Positioning**
Each section can be positioned independently via Edit Mode (LibEditMode integration) or merged into another section's bar. Layout options include horizontal row, vertical column, and grid with configurable icons-per-row. Anchor direction controls growth direction.

**Customisation**
Per-section icon width and height sliders. Stack counter and cooldown countdown text with independent font and size controls. Custom item tracking by item ID. Reorderable item display with drag-style up/down arrows showing Midnight-style rank quality icons. Optional Masque skinning integration.

### Edit Mode

**Edit Mode Nudge**
Adds arrow buttons and a coordinate readout when an Edit Mode frame is selected. Nudge frames by 1px per click, or 10px with Shift held. Coordinates display the frame's position relative to screen centre.

### ElvUI Plugins *(requires ElvUI)*

**Vehicle Bar Visibility**
Keep selected action bars (1–10) visible during vehicle combat and override bar states (e.g. shapeshift-style encounters). Prevents ElvUI's mouseover fade from hiding bars for the duration of the encounter, and restores normal fade behaviour on exit. By default only bar 1 is enabled — enable additional bars in the options panel.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/mqol` | Open the MathWro QOL options panel |
| `/wa` | Open WeakAuras (requires CDM Button → Enable /wa command) |
| `/cm` | Open Cooldown Manager (requires CDM Button → Enable /cm command) |

---

*This addon was developed with the assistance of AI.*
