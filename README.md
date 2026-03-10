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
Automatically pre-enables selected filters each time you open the Auction House. Two independent toggles in the options panel: "Current expansion only" (default on) and "Usable only" (default off). Filters are re-applied on every AH open so any in-session manual changes are reset.

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
