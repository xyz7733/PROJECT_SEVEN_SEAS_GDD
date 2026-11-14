# Project Seven Seas

An isometric pixel-art seafaring management and expedition game, built natively in **Godot 4.7.2** with
**GDScript**. You captain a multi-deck ship, furnish it room by room, recruit and train a living crew,
explore islands and dungeons on foot, and fight automatic battles you can steer with stances, focus
targets and retreat. Languages: **English** and **Simplified Chinese**.

The game follows `PROJECT_SEVEN_SEAS_GDD.md` (v1.0) and the art direction in `VISUAL_REWORK_BRIEF.md`.
Current status and known gaps: `IMPLEMENTATION_STATUS.md`.

Current release: **craft-01-fix1**, following craft-01. It gives the game a sense of occasion:
- battles open on a wide shot of the whole arena and settle on the fight, framed clear of the HUD
  and the combat log, on ground that wears away naturally instead of in stair-stepped tiles;
- bosses step forward in a letterboxed intro with their name, a horn and a roar, and keep a health bar
  under the title strip for the rest of the fight; the last blow of a fight lands in slow motion;
- weather: overcast skies, rain, fog, storms with lightning and thunder, and ashfall over the volcanic
  seas. Each region has its own climate, the sky changes every six hours and spells hold for a while.
  It shows in port, at sea, on islands and in battle, never underground, and can be turned off in
  System;
- original rain and storm loops, near and far thunder and the boss horn
  (`tools/audiogen/gen_weather.py`);
- no more hard cuts between stages: the old view is swept away in a dithered diagonal (a short
  crossfade with Reduce Motion).

The previous release, life-01, added ambient life in every stage, the wake and bow wave, lit windows
at night and more feedback for actions (see `IMPLEMENTATION_STATUS.md`).

The follow-up fixes weather showing below decks, clears active lightning when entering shelter,
corrects 18 enemy skill names in both languages and includes the current audio credits in the
Windows distribution. The original craft-01 checkpoint is retained.

Automated Windows rendering now runs on an RTX 4070 Laptop GPU: at 1280×720 with VSync on a 240 Hz
display, the sampled weather and battle scenes average about 239–241 FPS. Stage construction still
blocks for 17–75 ms, with a measured battle-entry frame of 128 ms. The source probe and screenshots
cover weather, shelter, stage changes and ordinary/boss battles; human motion review, mouse-driven
play, speaker listening and campaign balance remain pending. See `IMPLEMENTATION_STATUS.md` for
evidence and limits.

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
A damaged file is reported as corrupt and is never loaded. Older saves are migrated on load: schema-3
saves move rooms off the open deck onto interior levels, and schema-4 saves gain the bestiary and
collection-book fields. The ledger reports how many rooms were moved.

### Controls

| Input | Action |
|---|---|
| Left click | Select crew, facilities, stairs, doors and town buildings; pick a room on an island; click the rowboat to return to the ship; focus an enemy in battle |
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

### Validate on Windows

With the matching Windows editor in `tools/godot/windows/`, run from the repository root:

```
python tools/validation/validate_windows.py
python tools/validation/validate_windows.py --skip-import --export
```

Use `--engine PATH` for another installation of Godot 4.7.2. The runner imports resources, runs the
core suite and the populated real-font layout suite, and optionally exports the Windows release.
It redirects only its child processes' profile paths into `build/validation/`, preserving installed
player saves and preferences. Logs are written there too. This verifies rules and layout without
opening a game window; animation, mouse interaction and audio still need a playtest.

For an automated rendering and frame-pacing probe in a real Windows window:

```
python tools/validation/validate_gpu_windows.py
```

This runs silently with the Dummy audio driver and an isolated profile. It writes screenshots,
`metrics.json` and logs under `build/validation/gpu-craft/<timestamp>/`. Frame intervals include
VSync and presentation waits; these are not GPU execution timings. Use `--locale zh_CN`, `--ui 1.5`
or `--screen INDEX` as needed. `--audio` enables sound for a human listening review.

### Screenshot harness

`game/tests/shots.tscn` runs the real main scene in a window and saves viewport PNGs, driven by a small
scenario script. It is development-only and is not exported (`tests/*` is excluded).

```
godot --path game res://tests/shots.tscn -- --out DIR --scenario FILE.gd [--locale zh_CN] [--ui 1.5]
```

A scenario is a GDScript file with a `run` coroutine. `h` is the harness: `h.main` is the main scene,
and `h.new_game(seed)`, `h.wait(seconds)`, `h.frames(n)`, `h.shot(name)`, `h.act(result)`, `h.key`,
`h.move`, `h.click` and `h.wheel` drive it.

```gdscript
extends RefCounted

func run(h) -> void:
	await h.new_game(7)
	await h.wait(0.5)
	await h.shot("port")
	h.main.open_window("crew", "detail")
	await h.wait(0.4)
	await h.shot("crew_detail")
```

It needs a display. On a Linux machine without one, `xvfb-run` with Mesa's software renderer works
(`--rendering-driver opengl3`). Point `XDG_DATA_HOME` / `APPDATA` at a scratch folder first, so the
player's saves and settings are never touched. `tools/shots/run_linux.sh` does both:

```
bash tools/shots/run_linux.sh tools/shots/scenarios/tour.gd OUT_DIR [--locale zh_CN] [--ui 1.5]
```

Ready-made scenarios are in `tools/shots/scenarios/`:

| Scenario | What it does |
|---|---|
| `tour.gd` | Title, port by day and night, lower decks, a crossing with any sea fight, the first island and a land fight with its report (14 screenshots) |
| `battles.gd` | Five land battles (island, dungeon boss, wreck elite, trial ring, volcanic boss): the opening shot, the boss intro, the fight and late in the fight (20 screenshots) |
| `weather.gd` | Every sky over the port, a stormy night with a lightning flash, rain at sea and in a sea fight, island fog, an island fight in rain and a dungeon fight (no weather underground) (12 screenshots) |
| `transitions.gd` | Stage changes caught mid-sweep, plus the frozen frame saved next to its screenshot for a pixel comparison (8 screenshots) |
| `windows.gd` | Every tab of every window from a new game (30 screenshots); run it per language and UI size |
| `width_audit.gd` | No screenshots: prints, for every window tab, whether its content fits the window's width and which control is too wide if not |

## Where things live

| Path | Contents |
|---|---|
| `game/` | The Godot project |
| `game/scripts/core/` | Rules, transactions, combat simulation, world generation, saves, settings, localization, audio, weather rolls (`Game`, `C`, `I18n`, `Settings` and `Audio` autoloads) |
| `game/scripts/view/` | In-world stages: `ShipView` (isometric decks, crew, town quay), `SiteView` (island and dungeon exploration), `BattleView` (live battles), `Ambience` (gulls, sea life, cloud shadows, night lights), `SailFx` (wake and bow wave), `WeatherLayer` (rain, fog, ash, lightning), `Curtain` (the sweep between stages), `Actor`, the `Art` atlas loader, input bindings |
| `game/scripts/ui/` | Compact HUD, game windows (ship builder, inspector, crew, pets, port, chart, codex, log, system), dialogs |
| `game/scripts/main.gd`, `boot.gd` | Scene flow: title screen, stage switching, sailing transition, sea events, battle reports, hotkeys |
| `game/assets/gen/` | All generated pixel art: atlases plus JSON metadata (anchors, frames, spots, lights) |
| `game/assets/fonts/` | Fusion Pixel 12px (SIL OFL 1.1, licences beside it) |
| `game/assets/audio/` | Music, ambience and effects (CC0; per-pack licence files in `licenses/`) |
| `game/data/` | Game content (`content.json`), world (`world.json`), bestiary (`bestiary.json`) and collection book (`collections.json`) |
| `game/i18n/` | `strings.csv` (`keys,en,zh_CN`, imported as Godot translations), `names.json`, `source/` tables |
| `docs/ASSET_INVENTORY.md` | **Asset inventory**: every shipped texture with size, frames, method and use; the audio files; code-drawn scene elements; the font licence |
| `docs/AUDIO_LICENSES.md` | **Audio licences**: source URL, creator, original name and licence for every audio file |
| `art/previews/` | Contact sheets of the generated art (not shipped) |
| `tools/shots/` | Screenshot scenarios and a headless Linux runner for the [screenshot harness](#screenshot-harness) |
| `art/reference/` | The two user reference screenshots: art direction only, never shipped or traced |
| `tools/artgen/` | Original art generators (Python + Pillow, voxel and pixel renderers) |
| `game/tests/` | Headless suites (`test_main.tscn`, `test_ui_layout.tscn`) and the screenshot harness (`shots.tscn`). Not exported |
| `tools/audiogen/` | Original sound generators: `gen_stingers.py` (victory and defeat stingers), `gen_weather.py` (rain and storm loops, thunder, boss horn) |
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
