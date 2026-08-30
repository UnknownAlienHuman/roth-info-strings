# RothInfoStrings code index

| File | Responsibility |
|---|---|
| `RothInfoStrings.toc` | Retail 12.1 metadata, SavedVariables, and definitive load order |
| `core.lua` | Defaults/sanitization, value access gates, information lines, event routing, tickers, on-demand memory, drag/slash behavior, and combat-deferred refresh |
| `options.lua` | Current Blizzard vertical Settings category and refresh callbacks |
| `tests/test_safe_runtime.lua` | Mocked regression for inaccessible values, explicit memory sampling, and combat deferral |

Detailed ownership and state routing are in [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENT_GUIDE.md`](AGENT_GUIDE.md).
