# RothInfoStrings

Lightweight, event-driven information strings for WoW Midnight. The addon displays compact player/zone information and exposes basic positioning and display options.

## Compatibility

- Interface: `120000` (alternate interface `120001`)
- Version: `0.4.0`
- Author: Galaxy (Roth UI) / rebuilt
- SavedVariables: `RothInfoStringsDB`

## Installation

Copy `RothInfoStrings` into `World of Warcraft/_retail_/Interface/AddOns/`, enable it and reload the UI. The TOC retains an optional `RothLib` compatibility declaration, but the loaded `core.lua`/`options.lua` contain no direct RothLib call; the addon has no active RothLib integration path in this tree.

## Development status

This is a small legacy-derived addon with no older development tracker. The repository now records the required login, zone-change, options, saved-placement, and safe-formatting validation in [todo.md](todo.md).

## License

Licensed under the [MIT License](LICENSE).
