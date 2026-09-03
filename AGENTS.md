# AGENTS.md — MathWroQOL

Instructions for AI agents (Codex, OpenCode) operating in this repository.

## Architecture Reference

Read `docs/ARCHITECTURE.md` before writing or modifying any code. It contains the canonical reference for load order, feature contracts, code style, naming conventions, Config.lua helpers, performance rules, and WoW API pitfalls.
- Target Retail interface: `120100` in `MathWroQOL.toc`; keep it as one value.

---

### API Documentation

Use Context7 (`npx ctx7@latest library` followed by `npx ctx7@latest docs`) to retrieve current WoW API documentation before making API-dependent changes.

---

## Build / Lint / Test

There is no build step or linter. Run the Lua 5.1 smoke and syntax checks:

```bash
lua tests/CombatTracker_Cooldowns_smoke.lua
lua tests/CombatLog_smoke.lua
lua tests/BuffHealthColor_smoke.lua
lua tests/EditModeNudge_smoke.lua
luac -p Features/*.lua tests/*.lua
```

Then validate in-game:

1. Load the addon in WoW Retail (`_retail_`)
2. Run `/reload` after each change
3. Check the default error frame or `!BugGrabber` / `BugSack`

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
| `CombatTracker.lua` | Enable in `/mqol`; enter combat; trigger a racial, Healthstone or potion, and on-use trinket; verify each cooldown starts immediately without restricted-value errors |
| `Config.lua` | Run `/mqol`; verify provider-specific submenus, disabled dependency states, controls, and first-open layout |
| `CVarSettings.lua` | Run `/mqol`; confirm Spell Queue Window leaves the current CVar unchanged until explicitly enabled, first activation captures that value without writing it, and only that captured or subsequently user-selected value is restored after `/reload` |

---

## Releases
GitHub Actions only. Use Semantic Versioning: additive features increment MINOR; fixes increment PATCH. Create and push an annotated tag:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
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
