# RothInfoStrings architecture

`RothInfoStrings.toc` loads `Info.xml`, which includes `core.lua`, and then loads `options.lua` as a separate TOC entry. The core initializes `RothInfoStringsDB`, applies the anchor, formats values safely and updates the information strings from game events. The options file owns checkboxes/sliders and requests refreshes.

The optional `RothLib` dependency is declared in the TOC but is not bundled in this directory; keep integration checks separate from the core path.
