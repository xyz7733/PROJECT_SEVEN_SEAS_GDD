# Superseded: browser prototype (reference only)

This folder holds the earlier HTML/CSS/JavaScript prototype of Project Seven Seas.
It is **superseded** by the native Godot 4 game in `../../game/` (see the root `README.md`).

It is kept only as a reference for game mechanics and content data:

- `src/content.js`, `src/world.js`: content and world data. `tools/data_export/export_data.js` converts them to the JSON files in `game/data/`.
- `locales/en.js`, `locales/zh-CN.js`: string tables, converted to `game/i18n/translations.csv` and the name pools.
- `src/rules.js`, `src/actions.js`, `src/state.js`, `src/combat.js`: rules the native game ports to GDScript.

Do not ship or open this prototype as the game. The delivered product is the native executable.
