# RothInfoStrings

Compact, event-driven information strings for World of Warcraft Retail 12.1. The addon displays zone/coordinates, FPS/latency, mail, XP or watched reputation, and an on-demand addon-memory tooltip.

## Compatibility

- Retail / Midnight `12.1.0`
- Interface `120100`
- Version `0.5.0`
- Verified Blizzard source baseline `12.1.0.69497`
- SavedVariables `RothInfoStringsDB` schema v2
- External dependencies: none
- GitHub Actions / CI: none

## Commands

```text
/ris lock
/ris unlock
/ris toggle
/ris reset
/ris memory
/ris config
```

## Retail 12.1 data boundary

Every game-returned scalar/table/object is checked for accessibility before type checks, comparison, arithmetic, formatting, concatenation, indexing, logging, or persistence.

- inaccessible zone, map ID, map-position object/coordinates, latency, mail, level, XP, watched-reputation table, or reputation fields fail closed;
- corrupted SavedVariables anchors are restricted to valid WoW point names before `SetPoint`;
- UI anchor/scale refresh requested in combat is applied once after regen;
- coordinate polling exists only while moving;
- the performance ticker reads FPS/network only;
- addon-memory profiling runs only on hover, explicit click, or `/ris memory`;
- explicit garbage collection is blocked in combat;
- the unused RothLib declaration and XML loader are removed.

## Memory behavior

The tooltip samples addon memory on demand and lists at most 25 addons. No login or periodic memory walk occurs. Clicking the information block outside combat explicitly runs garbage collection and refreshes the tooltip; combat clicks do nothing.

## Settings

The options page uses Blizzard's current vertical Settings API and controls enablement, lock/drag policy, Minimap attachment, display sections, memory tooltip availability, and scale.

## Performance

- no `OnUpdate`;
- one FPS/latency ticker while enabled;
- one coordinate ticker only while moving;
- no combat log, aura scan, frame-tree scan, or periodic addon-memory profiling;
- all tickers are cancelled before restart and when disabled.

## Validation

`tests/test_safe_runtime.lua` injects inaccessible map/reputation objects and fields, latency, level/XP, mail, and addon-load arguments. It also verifies anchor sanitization, explicit-only memory/GC behavior, moving-only coordinates, and combat-deferred UI refresh.

Live-client verification remains required; see [Docs/TODO.md](Docs/TODO.md).

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Agent guide](AGENT_GUIDE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
- [WoW addon engineering knowledge base](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb)

## License

Licensed under the [MIT License](LICENSE).
