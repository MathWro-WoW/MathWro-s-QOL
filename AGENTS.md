# AGENTS.md — MathWroQOL

Instructions for AI agents (Codex, OpenCode) operating in this repository.

## Architecture Reference

Read `docs/ARCHITECTURE.md` before writing or modifying any code. It contains the canonical reference for load order, feature contracts, code style, naming conventions, Config.lua helpers, performance rules, and WoW API pitfalls.
- Target Retail interface: `120100` in `MathWroQOL.toc`; keep it as one value.

---

### API Documentation

Agents should consult the WoW API documentation which is available via the MCP Server "documcp" by using the MCP's provided tools and referencing the source called "WoW Addon API". This documentation includes detailed information on all available functions, events, and constants that can be used in addon development.

---

## Build / Lint / Test
There is **no build step, linter, or automated test runner**. Validate manually:

1. Load the addon in WoW Retail (`_retail_`)
2. Run `/reload` in-game after each change
3. Check for Lua errors in the default WoW error frame, or via `!BugGrabber` / `BugSack`

### Per-feature Validation
| Feature | How to test |
|---|---|
| `GameMenu.lua` | Press Escape; verify scale, drag, button placement, and Reset Position |
| `CDMButton.lua` | Press Escape; verify the CDM button appears and slash commands work |
| `AuctionFilter.lua` | Open Auction House; confirm configured filters are pre-enabled |
| `CombatLog.lua` | Enter/leave an enabled instance type; confirm logging starts/stops |
| `VehicleBar.lua` | Test selected bars with ElvUI and EllesmereUI Action Bars independently when available |
| `BuffHealthColor.lua` | With ElvUI, test configured spell IDs on player, target, party, and raid frames; verify restricted aura updates produce no Lua errors |
| `EditModeNudge.lua` | Test native Edit Mode/LibEditMode and EllesmereUI Unlock Mode independently |
| `CombatTracker.lua` | Enable in `/mqol`; enter combat; verify icons and cooldowns update |
| `Config.lua` | Run `/mqol`; verify provider-specific submenus, disabled dependency states, controls, and first-open layout |

---

## Releases
GitHub Actions only. The current minor release line is `v1.9.0`.

```bash
git tag v1.9.0
git push origin v1.9.0
```

Triggers `.github/workflows/release.yml` → `BigWigsMods/packager@v2`.

Do **not** use comma-separated `## Interface:` values in the TOC — the packager will produce a broken `release.json`.

---

## Git Conventions

- Commit message format: `type(scope): short description`
  - Types: `feat`, `fix`, `docs`, `chore`, `refactor`
  - Scope is optional but useful (e.g. `fix(combat-tracker):`, `feat(trinkets):`)
- Body explains *why*, not *what*
- Keep commits atomic — one logical change per commit
