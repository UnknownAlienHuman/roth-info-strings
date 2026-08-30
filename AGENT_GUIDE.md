# RothInfoStrings agent guide

## Start here

[`RothInfoStrings.toc`](RothInfoStrings.toc) is the definitive load contract. Retail 12.1 loads `core.lua` and then `options.lua`. The addon has no XML indirection, bundled library, or optional addon dependency.

Target contract:

- Retail / Midnight `12.1.0`;
- Interface `120100`;
- verified Blizzard source baseline `12.1.0.69497`;
- one SavedVariables root: `RothInfoStringsDB`.

## Runtime map

### Initialization

`core.lua` handles `ADDON_LOADED` by recursively merging defaults and sanitizing persisted numeric/string placement fields. `PLAYER_LOGIN` creates `RothInfoStringsAnchor`, three FontStrings, drag/tooltip scripts, slash commands, and the active tickers.

### Display sections

- zone/coordinates: `GetZoneText`, `GetCoordinatesText`, `UpdateZoneAndCoordinates`;
- FPS/latency/cached memory label: `UpdatePerformance`;
- mail/XP/watched reputation: `UpdateProgress`, `GetXPText`, `GetReputationText`;
- explicit addon-memory sample and tooltip: `SampleMemory`, `ShowMemoryTooltip`.

Coordinates update once on zone/world events, while stopped, and through a bounded ticker only between `PLAYER_STARTED_MOVING` and `PLAYER_STOPPED_MOVING`.

FPS/network text uses one bounded performance ticker. It does not scan addon memory. `C_AddOns.UpdateAddOnMemoryUsage` and the addon list walk run only from hover, click, `/ris memory`, or a direct internal diagnostic call.

### Placement and lifecycle

`Refresh` is the single runtime apply boundary. It sanitizes DB state, defers when combat is active, applies Minimap/UIParent anchoring and scale, applies lock/mouse state, updates display sections, and restarts only the required tickers. `PLAYER_REGEN_ENABLED` completes a deferred refresh.

Dragging is allowed only while unlocked, outside combat, and with the configured modifier. A successful drag stores an accessible point/relative point and numeric offsets, then disables Minimap attachment.

### Settings

`options.lua` registers a vertical Blizzard Settings category after the addon has loaded. `Settings.RegisterAddOnSetting` owns direct writes for enablement, lock/drag policy, Minimap attachment, section visibility, memory tooltip availability, and scale. Every setting callback calls `_G.RothInfoStrings_Refresh`.

No deprecated `InterfaceOptionsCheckButtonTemplate`, `OptionsSliderTemplate`, or `InterfaceOptions_AddCategory` fallback remains.

## Data-safety invariants

- Call `canaccessvalue` or `issecretvalue` before every type check, comparison, arithmetic operation, format, concatenation, log, table-key derivation, or persistent write involving game-returned values.
- An inaccessible map ID must not be passed to `GetPlayerMapPosition`.
- Coordinate arithmetic requires accessible numeric X/Y values.
- An inaccessible level stops the XP path before `UnitXP` or `UnitXPMax` is read.
- Inaccessible reputation fields must not be concatenated or used to construct a global label key.
- Inaccessible mail state is ignored.
- Do not serialize or log raw game payloads.
- Do not reintroduce the string placeholder `SV` by calling `tostring` on a restricted value; use ordinary fixed fallback text.
- UI placement/scale changes requested in combat must remain deferred.

## Performance invariants

- No `OnUpdate` handler.
- No always-running coordinate ticker.
- No periodic addon-memory scan.
- Keep `perfInterval` bounded to `0.5..10.0` seconds and `coordInterval` to `0.1..2.0` seconds.
- Stop all tickers when the addon is disabled.
- Memory tooltip sorting is user-triggered and limited to the top 25 rows.
- Do not restore the old automatic low-FPS shutdown; the addon must not hide itself based on a transient FPS sample.

## State

Durable keys include:

- `enabled`, `locked`, `scale`;
- `pos`, Minimap attachment points/offsets;
- `ctrlAltDrag`;
- `showZone`, `showCoords`, `showPerf`, `showMail`, `showXPRep`, `showMem`;
- `perfInterval`, `coordInterval`.

Frame references, FontStrings, ticker handles, movement state, deferred-refresh state, cached memory total, and memory sample time are runtime-only.

## Commands

```text
/ris lock
/ris unlock
/ris toggle
/ris reset
/ris memory
/ris config
```

`/ris memory` is the explicit command-line memory sampling path. `/ris config` opens the numeric Settings category ID stored by `options.lua`.

## Change routing

- defaults, sanitization, secret/access helpers: top of `core.lua`;
- zone/coordinates/performance/progress/memory formatting: `core.lua`;
- frame, drag, tooltip, tickers, events, slash and refresh: `core.lua`;
- options registration and callbacks: `options.lua`;
- offline regression: `tests/test_safe_runtime.lua`;
- metadata/load order: `RothInfoStrings.toc`.

## Verification

From the repository root:

```sh
texlua --luaconly core.lua
texlua --luaconly options.lua
texlua tests/test_safe_runtime.lua
```

Expected regression result:

```text
PASS: inaccessible values fail closed, memory is on-demand, and UI refresh defers in combat
```

The test injects inaccessible values for zone, map ID, latency, level, mail, and reputation; asserts that `UnitXP` is not reached after an inaccessible level; verifies no memory update occurs at login; verifies explicit memory sampling; and verifies combat-deferred scale application.

In the target client, test login/reload, zone transitions, stationary/moving coordinates, XP/level/faction/mail events, Settings callbacks, drag persistence, Minimap attachment, memory hover/click/command, enable/disable, combat-time setting changes, and `/console taintLog 1` plus Lua error capture.

Static and mocked results do not prove current-client restricted behavior or Settings rendering. Record the exact client build for live evidence.
