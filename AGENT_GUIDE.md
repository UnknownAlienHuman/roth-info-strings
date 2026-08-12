# RothInfoStrings agent guide

## Start here

Read [`RothInfoStrings.toc`](RothInfoStrings.toc): it declares `RothInfoStringsDB`, optional `RothLib`, loads `Info.xml` (which includes `core.lua`), then loads `options.lua`. `core.lua` is the runtime owner; `options.lua` is a Blizzard Settings/legacy Interface Options view that calls the exported `_G.RothInfoStrings_Refresh` hook.

## Runtime and state flow

`core.lua` copies defaults on `ADDON_LOADED`, creates `RothInfoStringsAnchor` on `PLAYER_LOGIN`, applies minimap or explicit placement, and starts the performance ticker. It updates zone/coordinates, XP/reputation/mail, network/fps, and memory on zone/player/progress/movement events. `PLAYER_STARTED_MOVING` starts a coordinate ticker and `PLAYER_STOPPED_MOVING` cancels it. `UpdatePerf` pauses memory scans below 30 FPS and hides/stops the UI after sustained FPS below 10; `/ris toggle` resets that protection.

The single SavedVariables root is `RothInfoStringsDB`: enabled/lock/scale/position, minimap attachment, display toggles, ticker intervals, and drag modifier policy. `SetLocked`, `ApplyAnchor`, `UpdatePerf`, `UpdateProgress`, `StartPerfTicker`, and `StartCoordTicker` are the key symbols. `/ris lock|unlock|toggle|reset` is registered on `PLAYER_LOGIN`; Settings controls mirror those operations.

## Dependencies and risks

`RothLib` is an optional TOC declaration but no direct `RothLib` symbol use appears in `core.lua` or `options.lua`; treat it as compatibility metadata, not a hard runtime API. The code uses `issecretvalue` checks for XP/level values and safe string conversion, but coordinates and reputation fields are patch-sensitive and need live-client verification before changing arithmetic/formatting.

The main hot path is the 0.5-second moving coordinate ticker and 2-second performance ticker. `UpdateMemTotal`/tooltip walks all addons and must remain throttled/paused under low FPS. Dragging changes the persisted position and disables minimap attachment; preserve this state transition.

## Change routing

- Display values, event routing, tickers, drag/lock, and slash: `core.lua`.
- Settings widgets and refresh bridge: `options.lua`.
- SavedVariables defaults/migration: top of `core.lua` and `ADDON_LOADED` branch; keep `CopyDefaults` semantics.

## Verification

Static: expand `Info.xml`, parse both Lua files, verify TOC references, and run `git diff --check`. In game, run `/ris unlock`, drag with the required modifier, `/ris lock`, `/ris toggle`, `/ris reset`, change Settings scale/attachment/memory, move, change zone, gain XP/mail, and sustain low FPS to validate the emergency path. Confirm `RothInfoStrings_Refresh` is present and no secret-value errors occur. Current audit does not claim live patch/API proof.
