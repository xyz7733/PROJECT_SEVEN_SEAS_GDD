# Project Seven Seas

An isometric pixel-art seafaring management and expedition game, built natively in **Godot 4.7.2** with
**GDScript**. You captain a multi-deck ship, furnish it room by room, recruit and train a living crew,
explore islands and dungeons on foot, and fight automatic battles you can steer with stances, focus
targets and retreat. Languages: **English** and **Simplified Chinese**.

The game follows the [game design document](docs/design/PROJECT_SEVEN_SEAS_GDD.md) (v1.0) and the
[visual rework brief](docs/design/VISUAL_REWORK_BRIEF.md).
Current status and known gaps: [Implementation Status](docs/IMPLEMENTATION_STATUS.md).

Development: [documentation](docs/README.md), [repository workflow](CONTRIBUTING.md),
[tool index](tools/README.md), [changelog](CHANGELOG.md).

Current release: **2.1.0 · crew-01**, which gives every sailor six personal attributes.
Local Windows package: `build/ProjectSevenSeas-crew-01.zip`. Exported builds are
excluded from Git. Published downloads belong on
[GitHub Releases](https://github.com/xyz7733/PROJECT_SEVEN_SEAS_GDD/releases).

- **Six attributes:** Might, Vigor, Agility, Focus, Will and Seamanship. 10 is average, and each
  point above or below adds a small, fixed amount to attack; max HP and defence; speed and dodge;
  critical chance and control effects; healing and skill cooldowns; or ship-job efficiency.
- **Born, not ranked:** base values are rolled once from the sailor's identity, leaning toward
  their origin's strengths, with one random talent and one weakness. There is no rarity ladder:
  every spread has strong and weak sides, and the sailor's two personality traits nudge it further.
- **Training:** a sailor earns a training point every 4 levels (15 by level 60) to put into any
  attribute. Retraining at a port or with a Class Hall refunds every point for 30 + 6 × level gold.
- **Interface:** a new Crew → Attributes tab with a hexagon chart, per-attribute rows and +
  buttons, the base/trait/training breakdown, the net effect on stats and the class's two key
  attributes. A compact attribute strip with tooltips appears in Details, tavern cards, the
  post-battle recruit offer and the ship Inspector, and the roster marks unspent points.
- **Saves:** schema 6. Older saves migrate on load; each existing sailor gets the attributes
  their stored identity produces, plus the training points their level has already earned.

See the [Crew 01 release notes](docs/CREW_01.md) for the full tables, migration details and
validation. Everything else is unchanged from the previous release:

**2.0.1 · world-art-02**, the follow-up to the ten-sea visual rework. The catalogue retains
**20 ports, 80 exploration sites, 310 rooms and 190 combat-room contexts**, with six review fixes:

- companion attack skills select enemies by default, explicit self/ally skills retain their targets,

  and Sic 'Em immediately performs a pet skill at the intended 1.6× damage;

- exploration Fit includes the party, landing, boat and complete landmark inside the HUD safe area;

- Inspector panels clear the objective strip and show all four stats in two columns;

- pause and battle notices use reserved areas, while damage numbers merge and avoid actors and the HUD;

- defeat reports no longer create an empty animation Tween;

- title, System and window-close exits share bounded audio cleanup, with deferred playback when the mixer stalls.

The ports now use distinct street and coastal layouts; complete cabin groups combine walls, open

thresholds, floors, furniture and crew activity across all four hulls. Runtime landmarks use the

project's native voxel/pixel renderer. Four dungeons in Glass Current and Stormbelt add optional

local preparation routes: calibrate prisms to remove glare and actual decoys, or relight beacons

for shelter in subsequent local fights. Existing west-room completion records carry these effects;

no new save fields are required. Other regions and legendary challenges keep their rules.

Read the [World Art 02 release notes](docs/WORLD_ART_02.md) and
[validation manifest](docs/WORLD_ART_02_VALIDATION.json) for the final evidence, counts and known
limits. Checks use isolated player data. Engine-driven fullscreen review does not establish OS-mouse
play or speaker-listening acceptance; the final corrections were targeted regressions, not a new
full-campaign manual playthrough. Earlier checkpoints are recorded under Release history below.

## Play on Windows

Extract the locally exported `build/ProjectSevenSeas-crew-01.zip`, or use the native Windows
x86-64 files in `build/windows/`. Keep the EXE, matching PCK and `licenses` folder together:

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
- **Linux:** the development workspace uses the official Linux editor in **self-contained mode**
  (`tools/godot/._sc_`). Engine binaries and templates are local tools excluded from Git; install
  them on a fresh clone. Editor settings and export templates live in `tools/godot/editor_data/`.

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
| `game/scripts/core/` | Rules, transactions, crew attributes, combat simulation, world generation, saves, settings, localization, audio, weather rolls (`Game`, `C`, `I18n`, `Settings` and `Audio` autoloads) |
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

This repository is licensed under the **GNU General Public License version 3**
(SPDX: `GPL-3.0-only`); see [LICENSE](LICENSE). Third-party material and files with
separate licence notices retain those terms. Preserve their licences and source
credits when redistributing the game.

Runtime artwork is drawn by the project's voxel and pixel generators in `tools/artgen/`, including
the regional landmark families and their location compositions. The earlier AI-assisted masters
remain under `art/source/landmarks/` as concept/source references; they are not included in the
distributed PCK, and the current runtime atlases do not use their pixels. See
[World Art 02](docs/WORLD_ART_02.md) and [Asset Inventory](docs/ASSET_INVENTORY.md). Existing asset IDs,
contact points and animation contracts remain the basis for integration. Third-party assets:

- **Font:** Fusion Pixel (SIL Open Font License 1.1).
- **Audio:** all CC0 1.0, from Kenney, OpenGameArt (Thimras, beardalaxy, Eldritch Grim) and
  BigSoundBank. The stingers, weather sounds and eleven regional/cabin layers are original, generated
  by `tools/audiogen/`; original synthesized audio is also released under CC0 1.0.

Each audio file's source and licence is listed in `docs/AUDIO_LICENSES.md`, a copy of which ships in
`build/windows/licenses/`. Godot Engine is MIT-licensed.

## Release history

**world-art-02 (previous, 2.0.1).** Six review fixes (companion skills, exploration Fit, Inspector,
battle notices, defeat settlement, audio exit), native landmark artwork, revised port and site layouts,
furnished cabin groups and two-region preparation routes. Evidence: [release notes](docs/WORLD_ART_02.md),
[validation manifest](docs/WORLD_ART_02_VALIDATION.json); its checkpoint is kept in
`build/windows-checkpoints/world-art-02/`.

**world-art-01 (historical).** The first complete ten-sea visual rework introduced regional
architecture, authored compositions, 100 landmark vignettes assembled from ten AI-assisted masters
and native scenery, refined ships, interiors, characters and creatures, a navy/brass interface,
and eleven original regional/cabin sound layers. Its Windows export contained 382 matching
packed-file digests. The [fullscreen review](docs/FULLSCREEN_REVIEW_20261114.md) completed the ten-trial
main campaign through normal rules and inspected the presentation catalogue, finding the six issue
groups addressed by world-art-02. Those campaign results belong to world-art-01. See
[World Art 01](docs/WORLD_ART_01.md) and its [coverage manifest](docs/WORLD_ART_COVERAGE.json).

**craft-01-fix1 (historical).** Regional weather, battle staging and shelter fixes passed 2,263 core
checks and 748 layout checks, with RTX 4070 rendering measurements. These counts and measurements
remain evidence for that revision. The original records are retained in
[Implementation Status](docs/IMPLEMENTATION_STATUS.md).
