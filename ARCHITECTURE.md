# RothInfoStrings architecture

## Ownership

`core.lua` is the runtime owner. It initializes/sanitizes `RothInfoStringsDB`, owns the addon frame and FontStrings, formats accessible values, routes game events, manages the FPS/latency ticker and moving-only coordinate ticker, samples addon memory on demand, handles drag/lock/slash behavior, and defers UI refresh during combat.

`options.lua` is the Settings owner. It registers a vertical addon category using Blizzard's current Settings API and writes directly to top-level SavedVariables keys. Value-change callbacks call the exported `_G.RothInfoStrings_Refresh` runtime boundary.

## Load order

```text
RothInfoStrings.toc
  -> core.lua
  -> options.lua
```

There is no XML indirection and no optional addon dependency.

## Data flow

```text
ADDON_LOADED
  -> merge defaults
  -> sanitize persisted values

PLAYER_LOGIN
  -> create UI
  -> register slash commands
  -> refresh all sections
  -> start FPS/latency ticker

PLAYER_STARTED_MOVING
  -> start coordinate ticker

PLAYER_STOPPED_MOVING
  -> stop coordinate ticker
  -> one final coordinate update

XP / level / faction / mail events
  -> update progress line

zone / entering-world events
  -> update zone and coordinates

hover / click / /ris memory
  -> explicit C_AddOns memory sample
  -> tooltip
```

## Safety boundary

- `canaccessvalue` or `issecretvalue` gates every secret-capable scalar before type checks, comparisons, arithmetic, formatting, concatenation, logging, or persistence.
- `CanBeAccessedInContext` and `IsForbidden` gate the map-position object when those methods exist.
- Inaccessible coordinate/map values do not reach `GetPlayerMapPosition` or percentage arithmetic.
- Inaccessible level prevents XP reads; inaccessible reputation fields are not indexed into labels or concatenated.
- Inaccessible mail state is ignored.
- UI anchor/scale changes requested during combat are deferred until `PLAYER_REGEN_ENABLED`.
- Memory collection is never periodic. The performance ticker does not call `C_AddOns.UpdateAddOnMemoryUsage`.

## State

`RothInfoStringsDB` stores enablement, lock/drag policy, scale/placement, Minimap attachment, section toggles, and bounded ticker intervals. FontStrings, tickers, moving state, pending refresh, cached memory total, and memory sample time are runtime-only.

## Evidence boundary

`tests/test_safe_runtime.lua` proves the fail-closed formatting, on-demand memory, and combat-deferred refresh contract against mocks. It does not prove live map/reputation API accessibility, Settings layout, tooltip behavior, or protected/taint behavior on the current client.
