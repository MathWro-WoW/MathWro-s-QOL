# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Architecture Reference

Read `docs/ARCHITECTURE.md` before making any code changes. It is the canonical reference for load order, feature contracts, code style, Config.lua helpers, performance rules, and WoW API pitfalls.

## Machine Layout (Claude-specific)

- Addon source: `/run/media/mathwro/2TBM2/World of Warcraft/_retail_/Interface/AddOns/`
- SavedVariables / session logs: `/run/media/mathwro/SSD/World of Warcraft/_retail_/WTF/`
- Two separate WoW installs exist. Only the 2TBM2 install is actively played.
- Do not use ElvUI_SLE on the SSD install as a reference — it is outdated.

## Testing

No build step or test runner. Test by loading the addon in WoW Retail (`_retail_`) and using `/reload` in-game after file changes. Check for Lua errors in the default error frame or via `!BugGrabber` / `BugSack`.
