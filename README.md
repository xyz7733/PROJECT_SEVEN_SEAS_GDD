# Project Seven Seas

An isometric pixel-art seafaring management and expedition game, built natively in **Godot 4.7.2** with
**GDScript**. You captain a multi-deck ship, furnish it room by room, recruit and train a living crew,
explore islands and dungeons on foot, and fight automatic battles you can steer with stances, focus
targets and retreat. Languages: **English** and **Simplified Chinese**.

The game follows `PROJECT_SEVEN_SEAS_GDD.md` (v1.0) and the art direction in `VISUAL_REWORK_BRIEF.md`.
Current status and known gaps: `IMPLEMENTATION_STATUS.md`.

## Play on Windows

The native Windows x86-64 build is in `build/windows/`:

| File | Purpose |
|---|---|
| `build/windows/ProjectSevenSeas.exe` | Game executable (Godot 4.7.2 release template, x86-64, GUI subsystem) |
| `build/windows/ProjectSevenSeas.pck` | Resource pack: scripts, scenes, art, audio, fonts, data and translations |
| `build/windows/licenses/` | Licence record and licence texts for the bundled audio and font. Keep it with the game when you share it |

1. Copy **both files**, and the `licenses` folder if you redistribute the game, into the same folder. The pack is not embedded, so the exe needs the `.pck`
   beside it with the same base name.
2. Double-click `ProjectSevenSeas.exe`. No installer, browser, network connection or account is needed.

**Requirements:** 64-bit Windows 10 or 11 and a GPU with OpenGL 3.3 (the project uses the GL
Compatibility renderer). The build is unsigned, so Windows SmartScreen may ask you to confirm the first
launch ("More info" → "Run anyway").

**First launch** asks for a language. You can change it later under System → Settings; the game then
restarts in the new language. Saves don't depend on the language.

**Settings** (System → Settings) also include:
- battle speed;
- **UI size** (normal, large and extra large, which is 1.0×, 1.25× and 1.5×; useful for long Chinese
  text);
- fullscreen, reduce motion (which also skips the rowboat landing) and pause at encounter start;
- separate **Master, Music, Ambience and Effects** volume sliders.

**Saves and settings** are written to `%APPDATA%\Godot\app_userdata\Project Seven Seas\`:
- `saves\slot_1..3.p7s`: three manual slots;
- `saves\recovery_1..3.p7s`: three rotating autosaves;
- `settings.cfg`.

Every save is written to a temporary file and renamed into place, and carries a SHA-256 content hash.
A damaged file is reported as corrupt and is never loaded. Saves from before the multi-level ship
(schema 3) are migrated on load. Rooms are moved off the open deck onto interior levels, and the
ledger reports how many were moved.

### Controls

| Input | Action |
|---|---|
| Left click | Select crew, facilities, stairs, doors and town buildings; pick a room on an island; focus an enemy in battle |
| Right drag / middle drag, or WASD / arrow keys | Pan the camera |
| Mouse wheel, `+` / `-` | Zoom |
| `Tab`, `PgUp` / `PgDn` | Next ship level / level up or down (weather deck ↔ interior levels) |
| `R` | Rotate a facility while placing it |
| `H` | Show or hide sails and rigging |
| `B` `C` `P` `O` `M` `K` `L` | Ship builder, Crew, Pets, Port (in port only), Chart, Codex, Log |
| `Space`, `1` `2` `4` | In battle: pause, speed ×1, ×2, ×4 |
| `Esc` | Close the top window, or open the System menu |
| `F11` | Toggle fullscreen |

## Open the project in the Godot editor

- **Project file:** `game/project.godot`.
- **Engine:** Godot **4.7.2 stable**, standard build (not the .NET build). Nothing else is needed: no
  plugins, no C#, no add-ons.
- **Windows:** download Godot 4.7.2 from <https://godotengine.org/download/archive/>, start the editor,
  choose **Import**, and select `game/project.godot`.
- **Linux:** the repository already contains the official Linux editor in **self-contained mode**
  (`tools/godot/._sc_`). Its editor settings and export templates live in `tools/godot/editor_data/`.

  ```
  tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game --editor
  ```

- **Main scene:** `game/scenes/boot.tscn`. It applies the saved language, or asks for one, and then
  loads `game/scenes/main.tscn`. Every stage (ship, island, battle), the HUD and all windows are built
  in code from `game/scripts/`.

## Export the Windows build

The export preset is **"Windows Desktop"** in `game/export_presets.cfg`:
- target: x86-64;
- `.pck` kept separate (`embed_pck=false`);
- icon: `game/icon.ico`;
- export path: `../build/windows/ProjectSevenSeas.exe`, relative to `game/`, which is
  **`build/windows/ProjectSevenSeas.exe`** at the repository root.

**From the editor:** Project → Export → Windows Desktop → Export Project. Untick "Export With Debug"
for a release build.

**From the command line (Linux, bundled tools):**

```
cd game
../tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import
../tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
    --export-release "Windows Desktop" ../build/windows/ProjectSevenSeas.exe
```

The bundled editor already has the official 4.7.2 export templates installed in
`tools/godot/editor_data/export_templates/4.7.2.stable/`. On another machine, install them once with
Editor → Manage Export Templates → Download and Install, or get the official `.tpz` from the Godot
download archive.

Run `--import` again after adding a script with a new `class_name` or after rebuilding `strings.csv`.

## Where things live

| Path | Contents |
|---|---|
| `game/` | The Godot project |
| `game/scripts/core/` | Rules, transactions, combat simulation, world generation, saves, settings, localization, audio (`Game`, `C`, `I18n`, `Settings` and `Audio` autoloads) |
| `game/scripts/view/` | In-world stages: `ShipView` (isometric decks, crew, town quay), `SiteView` (island and dungeon exploration), `BattleView` (live battles), `Actor`, the `Art` atlas loader, input bindings |
| `game/scripts/ui/` | Compact HUD, game windows (ship builder, inspector, crew, pets, port, chart, codex, log, system), dialogs |
| `game/scripts/main.gd`, `boot.gd` | Scene flow: title screen, stage switching, sailing transition, sea events, battle reports, hotkeys |
| `game/assets/gen/` | All generated pixel art: atlases plus JSON metadata (anchors, frames, spots, lights) |
| `game/assets/fonts/` | Fusion Pixel 12px (SIL OFL 1.1, licences beside it) |
| `game/assets/audio/` | Music, ambience and effects (CC0; per-pack licence files in `licenses/`) |
| `game/data/` | Game content (`content.json`) and world (`world.json`) |
| `game/i18n/` | `strings.csv` (`keys,en,zh_CN`, imported as Godot translations), `names.json`, `source/` tables |
| `docs/ASSET_INVENTORY.md` | **Asset inventory**: every shipped texture with size, frames, method and use; the audio files; code-drawn scene elements; the font licence |
| `docs/AUDIO_LICENSES.md` | **Audio licences**: source URL, creator, original name and licence for every audio file |
| `art/previews/` | Contact sheets of the generated art (not shipped) |
| `art/reference/` | The two user reference screenshots: art direction only, never shipped or traced |
| `tools/artgen/` | Original art generators (Python + Pillow, voxel and pixel renderers) |
| `tools/audiogen/gen_stingers.py` | Generates the original victory and defeat stingers |
| `tools/i18n/build_strings.py` | Builds `strings.csv` from `game/i18n/source/*.json` and checks keys and placeholders |
| `tools/data_export/export_data.js` | Development-only: converted the archived prototype's data to `game/data/` |
| `archive/web-prototype-superseded/` | The earlier HTML/JS prototype, kept only as a mechanics and data reference. It is not part of the game |
| `build/windows/` | Native Windows export |

### Regenerating art and strings

```
tools/artgen/.venv/bin/python tools/artgen/build_all.py   # rewrites game/assets/gen/, art/previews/ and docs/ASSET_INVENTORY.md
python3 tools/i18n/build_strings.py                       # rewrites game/i18n/strings.csv
```

Then re-import (see above). Edit translations in `game/i18n/source/native_en.json` and
`native_zh_CN.json`. The `base_*.json` tables come from the data export, and `native_*` entries
override them. Chinese text belongs only in the localization files. Identifiers, comments and docs are
in English.

## Licences and originality

All art, names and text are original to this project. The tile, sprite, facility, ship, creature, icon
and effect atlases are produced by the scripts in `tools/artgen/`; no downloaded, traced or AI-generated
images are used. Third-party assets:
- **Font:** Fusion Pixel (SIL Open Font License 1.1).
- **Audio:** all CC0 1.0, from Kenney, OpenGameArt (Thimras, beardalaxy, Eldritch Grim) and
  BigSoundBank. The victory and defeat stingers are original, generated by `tools/audiogen/`.

Each audio file's source and licence is listed in `docs/AUDIO_LICENSES.md`, a copy of which ships in
`build/windows/licenses/`. Godot Engine is MIT-licensed.
