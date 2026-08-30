# RothInfoStrings live validation matrix

Local tests establish control-flow and access boundaries only. Complete these checks on the exact Retail 12.1 client before release.

## P0 — load, migration, and placement

- [ ] Fresh install and representative pre-0.5 SavedVariables migration.
- [ ] Invalid point/relative-point, scale, intervals, and offsets sanitize safely.
- [ ] Minimap attachment and detached UIParent placement.
- [ ] Unlock, ALT / CTRL+ALT drag, lock, reset, and reload persistence.
- [ ] Change attachment/scale during combat; one refresh applies after regen.
- [ ] No Lua, forbidden-object, secret-value, or taint error.

## P0 — information sections

- [ ] Zone text across outdoor, indoor, instance, transport, and maps without a player position.
- [ ] Coordinates stationary, moving, stopping, changing maps, and restricted map-position contexts.
- [ ] FPS plus home/world latency in normal and restricted contexts.
- [ ] New-mail updates.
- [ ] XP below cap, at cap, disabled XP, level-up, and inaccessible level/current/max values.
- [ ] Watched reputation with ordinary data, missing faction, restricted table, restricted fields, and reaction-label fallback.

## P0 — memory and garbage collection

- [ ] No `UpdateAddOnMemoryUsage` at login or from the performance ticker.
- [ ] Hover tooltip samples once and lists at most 25 addons.
- [ ] `/ris memory` performs an explicit sample.
- [ ] Left-click performs explicit GC and refreshes the tooltip outside combat.
- [ ] Hover/click in combat performs neither memory walk nor GC.
- [ ] Repeated enable/disable and Settings changes do not multiply tickers.

## P1 — settings and performance

- [ ] Every vertical Settings control and `/ris config` opening.
- [ ] `/ris lock|unlock|toggle|reset|memory|config`.
- [ ] CPU/allocation capture stationary, moving, tooltip closed, and tooltip sampled.
- [ ] Confirm the coordinate ticker exists only while moving.
- [ ] Confirm the performance ticker never samples memory and all tickers stop when disabled.
- [ ] Confirm no `OnUpdate`, combat log, aura scan, or frame-tree scan.

## Release gate

Record the exact client build, each restricted context, placement migration, ticker counts, memory/GC observations, taint/error logs, and profiler data before publishing.
