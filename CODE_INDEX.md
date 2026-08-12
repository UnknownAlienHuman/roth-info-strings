# RothInfoStrings code index

| File | Responsibility |
|---|---|
| `RothInfoStrings.toc` | Metadata and SavedVariables |
| `Info.xml` | Includes `core.lua`; the TOC loads `options.lua` afterward |
| `core.lua` | DB defaults, safe formatting, anchor and event-driven updates |
| `options.lua` | Settings controls and refresh |

Detailed load/event/state routing is in [`AGENT_GUIDE.md`](AGENT_GUIDE.md).
