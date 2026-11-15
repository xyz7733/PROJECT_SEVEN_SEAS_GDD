# Project Seven Seas — Implementation Status

- **Game title:** Project Seven Seas
- **Source of truth:** [PROJECT_SEVEN_SEAS_GDD.md](design/PROJECT_SEVEN_SEAS_GDD.md) (v1.0, with the multi-deck and audio amendments
  in §6.5–6.8 and §13.5), [VISUAL_REWORK_BRIEF.md](design/VISUAL_REWORK_BRIEF.md) and [NATIVE_POLISH_REQUEST.md](design/NATIVE_POLISH_REQUEST.md)
- **Engine:** Godot 4.7.2 stable, GDScript, GL Compatibility renderer, 640×360 base viewport
  with expanding canvas scaling; default window 1280×720
- **Languages:** English (`en`) and Simplified Chinese (`zh_CN`)
- **Current delivery:** **2.1.0 · crew-01** (November 15, 2026): six personal attributes for every
  sailor (Might, Vigor, Agility, Focus, Will, Seamanship), training points and retraining, a new
  Crew → Attributes tab and attribute strips across the crew, tavern, recruit and Inspector views,
  and save schema 6 with migration. Download the [Windows ZIP](../build/ProjectSevenSeas-crew-01.zip).
  World and catalogue are unchanged from **2.0.1 · world-art-02** (November 14, 2026).
- **Current evidence:** [Crew 01 release notes](CREW_01.md) and
  [Windows handoff](WINDOWS_HANDOFF.json); world-art-02 evidence stays in its
  [release notes](WORLD_ART_02.md) and [validation manifest](WORLD_ART_02_VALIDATION.json).
  Older test counts, hashes and main-campaign results below remain specific to their named
  checkpoints.

## Crew attributes (crew-01)

- **Attributes:** `game/scripts/core/crew_attrs.gd` (`Attrs`). 10 is neutral; each point away from
  10 adds a fixed modifier through `Rules.member_stats()` after collections and before equipment
  (Might ATK 1.2%; Vigor HP 1.5% and DEF 0.8%; Agility SPD 0.1 and dodge 0.4% above 10 only;
  Focus crit 0.5% and control 1.5%; Will healing 1.5% and cooldown 0.6%; Seamanship job 3%).
  Values are clamped to 1–30; crit and dodge never go below zero.
- **Rolling:** six × 6 plus 22 points dealt by weighted draw (origin leanings ×2.2, one talent ×2,
  one weakness ×0.35, taper above 10, single base cap 16) from a separate stream seeded by the
  identity seed, so every other part of a recruit roll is unchanged. Each trait shifts two or three
  attributes by a net +1. Base classes name two key attributes; branches use their root class.
- **Training:** one point per 4 levels (15 at level 60), actions `crew.train` and `crew.retrain`
  (outside encounters and events; retraining needs a port or Class Hall and costs 30 + 6 × level
  gold). A level-up that earns a point logs it; the roster shows unspent points.
- **Interface:** Crew → Attributes tab (hexagon chart, rows with + buttons, points and retrain,
  net effects, class keys, trait shifts), with a compact arrangement when the window is narrow;
  attribute strips with tooltips in Details, tavern cards, the battle-report recruit offer and the
  Inspector. Six new generated icons; 59 new strings per language.
- **Saves:** schema 6; schema 3–5 saves migrate by rolling each existing sailor's attributes from
  their stored seed and origin and adding an empty training record (idempotent).
- **Validation:** **7,226 core checks and 940 layout checks** pass on the source, including the new
  `test_attrs.gd` suite, a hand-written schema-5 save and the Attributes tab at all three UI sizes in
  both languages. Existing combat and balance tests pass unchanged. No manual campaign playthrough
  was made for this release.

## Review fixes and scene revision (world-art-02)

- **R1 — Companion skills:** a missing target means an enemy for attack skills; explicit ally and
  self effects retain their targeting semantics, deterministic replay and settlement. Sic 'Em
  immediately performs the intended 1.6× pet skill and then resets its natural action timer.
- **R2 — Exploration Fit:** frame the room nodes, crew, landing, return boat and complete landmark
  clear of the HUD and site title, with wider overview zoom levels for large sites.
- **R3 — Inspector:** dock below the objective strip and use two columns for HP, ATK, DEF and SPD.
- **R4 — Battle readability:** put pause and full-field notices in reserved areas; merge rapid
  same-unit numbers, cap visible floaters and avoid actor sprites, HP bars, other labels and HUD.
- **R5 — Defeat settlement:** create reward animation only when there are reward stamps; preserve
  the Continue button and victory animation.
- **R6 — Audio exit:** defer playback while the mixer is stalled, retain the latest soundscape,
  discard stale effects and share bounded cleanup across title Quit, System Quit and window close.

**Locations and runtime art.** The 20 ports now use 18 spatial layout families, with service and
resident paths following the streets. Fifty island/dungeon layouts have revised room/landmark
relationships. All ten landmark families now use the same native voxel renderer as the ship and
buildings; the previous AI masters remain concept/source references outside the distributed pack.
The coastline treatment preserves protected room, path and boarding areas and existing elevation rules.

**Cabins.** Complete modules combine lit side walls, an open threshold, coordinated floors,
grouped furniture and reachable crew activity spots. Default layouts contain 2/3/6/6 modules across
the four hulls. Player facilities, stairs and work entrances take precedence; crowded refits omit
decorative modules instead of blocking navigation.

**Two-region route samples.** Four dungeons in Glass Current and Stormbelt offer an optional west
combat preparation route, an east resource route or direct progression. West combat costs 10 stamina;
the east resource visit costs 6. Calibrating Glass Current prisms removes glare and actual decoys
from later local fights; relighting Stormbelt beacons provides shelter. Existing west-room completion
records carry preparation state, including on old saves. An already generated pending encounter keeps
its original definition. The remaining regions, main quest templates and legendary challenges retain
their existing rules.

**Validation boundary.** The final source passes **6,975 core checks and 928 layout checks**.
Package-comparison and targeted fullscreen results are recorded in the
[validation manifest](WORLD_ART_02_VALIDATION.json). All runs use isolated
player data. Engine Input/UI/API review is distinct from OS-mouse play, and no speaker listening has
been claimed. The local WASAPI mixer did not advance continuously; deferred playback and bounded
exit were reviewed alongside Dummy playback, with remaining engine/device limits described in the
[release notes](WORLD_ART_02.md). This correction pass does not claim a new manual main-campaign run.

## Historical: ten-sea visual rework (world-art-01)

The following world-art-01 record describes the earlier package and its review findings. Its AI
landmark integration, packed-resource counts and unresolved issues are historical; the current
world-art-02 changes and evidence are summarized above.

The source work applies a warm, inhabited pixel-art direction across the complete campaign:
regional architecture and location compositions; new regional landmarks; refined hulls, facilities,
interior groups, classes, rival captains, monsters, bosses and pets; a navy/brass/cream UI and chart;
regional ambient life; and eleven original synthesized regional/cabin sound layers.

`SceneProfiles` supplies ten regional profiles, 100 location profiles and 190 combat-room profiles.
The landmark atlas supplies 100 location-specific vignettes from ten preserved AI masters and
authored native kits; each location and battle selects its corresponding variant. All 80 site
foundations statically clear room pads and routes at their actual 144-by-64-pixel footprint.
Existing room IDs, links, rule ownership, reward transactions and save schema remain the integration
boundary. The coverage manifest records structural coverage separately from runtime acceptance.

Detailed source changes, exact content counts, mixed code-authored/AI-assisted art provenance,
static evidence and outstanding review are in `docs/WORLD_ART_01.md` and
`docs/WORLD_ART_COVERAGE.json`. The regional audio sources and CC0 records are in
`docs/AUDIO_LICENSES.md`.

**Build evidence:** the complete `build_all.py` run finished in approximately 33 seconds and
produced 33 inventory rows. All ten AI-assisted landmark masters were prepared with 64 colours each,
then composed with native kits into 100 transparent 144-by-150-pixel vignettes integrated through
`Art.world_landmark()`. Godot Windows `--editor --import --quit` and `--export-release` completed;
`import.log` and `export.log` under `build/validation/world-art-01/` contain no `SCRIPT ERROR` or
`ERROR:` entries. `build/validation/world-art-01/pack-audit.json` records 382 packed resources,
382 matching file digests and all 14 required resources: scene profiles, landmark PNG/metadata and
11 sound loops. Artifact hashes and the immutable delivery checkpoint are recorded separately.

**Runtime review:** the exact exported PCK was exercised on Windows Godot 4.7.2, RTX 4070 Laptop
GPU, OpenGL, 2560×1600 fullscreen. A normal-rules save chain completed all ten main trials;
fixtures rendered 100 locations, 190 battle contexts and 14 hull views. Controls and 186 bilingual
window/tab/scale cases, bounded real-time fights, exposed night/weather and frame pacing were
recorded. Offensive pet skills, exploration Fit, Inspector layout, pause-banner occlusion,
defeat-report Tween construction and Dummy/WASAPI shutdown resource cleanup need work.
The release EXE/PCK were not changed. This uses Godot Input and normal API callbacks, not an
OS-mouse manual playthrough or speaker listening. Full evidence, corrected driver assumptions and
remaining acceptance limits are in `docs/FULLSCREEN_REVIEW_20261114.md`. Earlier 2,263/748 check
counts are not reused as world-art-01 results.

## Craft follow-up (craft-01-fix1)

- Weather now stops immediately below decks and returns on the weather deck. Deck selection
  refreshes the weather layer; entering shelter also cancels any active lightning flash. Eleven
  new checks use the real main scene and deck selector to cover rain, fog, ash, flashes and audio beds.
- Eighteen enemy skill translations used an unused `eskill.*` prefix while battle text requested
  `skill.*`. The English and Chinese keys now match their consumers; content checks inspect both
  imported translation resources so a fallback language cannot hide a missing entry.
- `build/windows/licenses/AUDIO_LICENSES.md` had lagged behind the checkpoint and source credits.
  It now includes all five original craft sounds and agrees with `docs/AUDIO_LICENSES.md`.
- The real-scene regression test yields normal audio frames between deck changes and lets the mixer
  release stopped playback instances before exit.

**Windows GPU evidence.** `python tools/validation/validate_gpu_windows.py` ran the source project in
a real 1280×720 window using NVIDIA OpenGL 3.3 / driver 617.42 on an RTX 4070 Laptop GPU. VSync was
enabled on a 2560×1600, 240 Hz display. Audio used the Dummy driver throughout, as requested.
The run passed 16 rendering/state assertions, collected 21 timing samples and 8 synchronous stage
construction measurements, and produced 16 screenshots. Reviewed screenshots show the five sampled
skies, rain-free interiors, sea storms, island fog, land combat, the Old Lookout intro and its boss bar.

| Sample | Mean FPS | p95 frame interval |
|---|---:|---:|
| Port: clear / rain / storm / fog / ash | about 240 | 4.81 / 4.91 / 5.04 / 4.83 / 4.90 ms |
| Sea storm / island fog | about 240 | 4.69 / 4.20 ms |
| Land battle, ×1 / ×4 | about 240 | 4.20 / 4.20 ms |
| Old Lookout boss, ×1 / ×4 | 239 / 241 | 4.20 / 4.20 ms |

Stage construction, including the curtain readback and view binding, blocked for **17–75 ms**.
The first land-battle transition included a **128 ms** frame; boss entry included a 102 ms frame.
Steady-state weather rendering is inexpensive on this machine, but those entry hitches remain.
These are wall-clock process-frame intervals including VSync/presentation, measured from the source
project, not GPU timer queries or a full playthrough. Screenshots are taken outside stable samples.
The probe predates the translation-only correction; those corrected battle labels are checked separately.

The final exported title also starts on NVIDIA hardware with a known language. Terminating it while
its music and ambience are active under the Dummy audio backend reports 8 audio playback/sequence
instances and 4 audio resources still in use, with exit code 0 and no running-script errors. This
was observed with `--quit-after 180`; the UI Quit buttons also call `SceneTree.quit()` directly,
so it has not been established as a command-line-only issue. Normal sound-device shutdown is untested.
The fresh-profile export, source GPU probe, final translated screenshots and headless suites exit cleanly.

Evidence: `build/validation/gpu-craft/20261114-193924-597377/metrics.json` and its screenshots/log;
the original exported craft-01 also started successfully on NVIDIA hardware for 180 frames, logged
in `build/validation/craft-takeover/original-release-gpu.log`. The automated probe invokes game code
without OS mouse input. Human assessment of motion, click-to-skip, finishing-blow timing, full-screen
interaction, larger battles, speaker mixing and long-term balance remains pending. Desktop control
could not be used because its native pipe was unavailable.

## Craft pass (craft-01)

The goal of this pass was to give the game a sense of occasion: battles that are staged rather than
just shown, a sky that changes, and no hard cuts between stages.

**Battle camera (`scripts/view/battle_view.gd`).** A land battle opens on a wide shot of the whole
arena at ×1 and glides (about 1.2 s) to the fight. The fight is framed from where every fighter
stands: the largest zoom up to ×2 that keeps them all clear of the title strip, the boss bar, the
action strip and the combat log. Reduce motion skips the glide.

**Natural ground (`Coast.make_blend`, `scripts/view/coast.gd`).** Tiles meet along their diamond
edges, so worn patches and trails used to show stair steps. A shader overlay now redraws every pixel
near a border between kinds of raised ground with the ground that wins a noisy bilinear vote of the
four nearest cell centres, so the border follows a ragged natural line. It is used on islands, in
dungeons and in land battle arenas. Quays, decks and lower ground keep their own edges.

**Combat log.** At most four single lines, fading with age and trimmed with an ellipsis at 230 px, so
it never runs over the front rank. The framing lifts the fight above it when there is room.

**Bosses.**
- When a boss (or a rival captain) is on the field, black bars close in, the camera glides to it,
  a war horn sounds over two drum hits (music ducked), the boss rears up with a flash, a shake and a
  red burst on the ground, and a card names it: "Guardian of Old Lookout / Lookout Warden" or
  "Rival captain / Captain Mira Gull". Clicking the bars skips the intro. With Reduce motion the intro
  is a still card without the glide or the shake.
- After the intro a boss bar sits under the title strip for the rest of the fight. Damage leaves a
  pale trailing chip that drains after a short hold. The bar fades once the boss falls.
- A slow red ring pulses on the ground under each boss.

**Finishing blow.** The knockout that ends a fight plays in slow motion (0.3× for 0.6 s, 1 s for a
boss) with a white flash while the camera leans in on it. It is skipped with Reduce motion.

**Weather (`scripts/core/weather.gd`, `scripts/view/weather_layer.gd`).**
- Skies: clear, overcast, rain, fog, storm and ashfall. Each of the ten regions has its own climate
  (the Stormbelt is mostly storms and rain, the Moonwake foggy, the Emberreach and Ashen Trench have
  ashfall).
- The sky is rolled from the save's seed, the region and the six-hour watch, so reloading shows the
  same weather. A watch keeps the previous one's weather 45% of the time, so spells last a while. A
  new game's first morning is always clear, and an open storm sea event always shows a storm.
- Drawn over port, sea, islands and battles on their own layer, under the HUD: an overcast tint,
  slanting rain streaks with splashes pinned to the ground where they land, ordered-dithered fog
  banks that drift with the world (violet in the Moonwake, warm in the Emberreach), falling ash with
  embers, and lightning flashes followed by thunder after a delay that grows with the distance.
  Nothing shows underground. A new stage gets its sky at once; on the same stage a change of weather
  eases in.
- Overcast skies bring more cloud shadows. Rain thins the gulls, storms send them away, and
  butterflies and fireflies stay out of the rain.
- Rain and storm beds play over the stage's own ambience and crossfade when the weather changes.
- The HUD clock shows the sky's icon, and its tooltip names the weather. "Weather effects" in the
  System window turns all of it off. Reduce motion keeps the rain and fog but drops the flashes.
- Weather is presentation only. It never changes rules, odds, costs or the save.

**Stage changes (`scripts/view/curtain.gd`).** Going between the title, the ship, an island and a
battle no longer cuts. The last frame of the old stage is frozen on top and swept away in the art's
own pixel grid: a diagonal band with a 4×4 ordered-dither edge and a thin dark rim, forwards into a
place and backwards out of it, in 0.5 s. With Reduce motion it is a 0.25 s crossfade. The frozen
frame also covers the first, slower frame of the new stage.

**New original sounds (`tools/audiogen/gen_weather.py`, CC0).** Seamless rain (8 s) and storm (10 s)
loops, near and far thunder, and the boss horn. All are synthesised from shaped noise and sine
partials with fixed seeds. The loops are periodic by construction, and every file was checked for
clicks at its start, end and loop point.

**New art.** Five 16×16 sky icons for the HUD (`ui/icons.png`, `gen_ui.py`).

**Defects found by looking at the game.**
- In the first renders the combat log ran over the front rank, the action strip showed through the
  boss intro and the bars closed in during the wide opening shot. All three are fixed.
- The first thunder and horn renders clicked at the end: the one-shot filter wrapped round. One-shot
  sounds now use a zero-padded filter.

**New checks.**
- The core suite checks the weather (`tests/test_weather.gd`): every region has a climate whose
  weights add up to 100 and names only known skies with a look and a name; the same seed, region and
  watch always give the same sky; 4,000 watches per region follow the weights within 4 points; spells
  hold; the first morning is clear; a storm event shows a storm; the harness override and its reset.
- `tools/shots/scenarios/` gains `battles.gd` (five arenas, boss intros, the fight and late in it),
  `weather.gd` (every sky in port, a stormy night with a flash, rain at sea and in a sea fight, island
  fog, an island fight in rain, a dungeon fight with no weather) and `transitions.gd` (each stage change
  mid-sweep). The last also saves the frozen frame next to its screenshot. The two match pixel for
  pixel, so the sweep starts from exactly what was on screen.
- The screenshot harness stops all sound before it quits, so quitting during a track no longer reports
  audio playbacks as leaked at exit.

## Living world pass (life-01)

The goal of this pass was to make the game feel alive and responsive, and to look at it: until now no
rendered frame had been reviewed.

**Ambient life (`scripts/view/ambience.gd`, art from `tools/artgen/gen_ambient.py`).** One `Ambience`
node per stage follows the camera and draws:
- sun glints and, on open water, whitecaps;
- fish that leap and leave a ripple;
- gulls that flap, glide and cast a shadow on the water;
- large, slow cloud shadows;
- butterflies over meadows by day and fireflies at night (additive glow);
- in port, a lighthouse beam that sweeps at night.

Ports, the open sea, the title screen, islands and boarding battles each set their own mix. Caves and
other enclosed sites get no sky life, only fireflies. Everything is off below decks.

**Sailing (`scripts/view/sail_fx.gd`).** While under way the hull throws foam along both waterlines,
two bow-wave arms and spray at the stem, and leaves a pale trail astern. The sea scrolls past and
rocks and sea stacks drift by outside the ship's lane. The title screen shows the ship under sail,
framed to the right of the menu, with a ship's-wheel emblem above the title
(`tools/artgen/gen_title.py`). The status strip reads "At sea, bound for …" during the crossing, even
when a battle or a landing is already waiting at the far end.

**Night in port.** Building windows light up at dusk (`env/buildings_lit.png`, derived from the
emissive window voxels by `gen_env.py`) and are drawn un-tinted over the night tint. Most homes are
lit, not all.

**Feedback.**
- A signed note appears under the resource strip whenever gold, food, supplies or materials change, and
  the chip flashes. Loading or starting a game does not report the difference.
- Battle hits that shake the camera also hold the simulation for about 70 ms (scaled by battle speed),
  and floating numbers pop in. Both are skipped with Reduce motion.
- Windows and dialogs fade in (skipped with Reduce motion). Window panels are now opaque, so the world
  no longer shows through the text.

**Defects found by looking at the game.**
- The slash crescent failed to triangulate on some frames (`Invalid polygon data` in `battle_fx.gd`)
  and was not drawn. It is now built from explicit triangles.
- The open sea had a hard-edged light/dark diamond around the ship. It is now uniform deep water under
  the ambient layer.
- The battle speed buttons clipped "×1" to "×".
- The crew formation tab clipped its three lanes; dropdowns forced their width to their longest entry.
- Several window tabs were wider than the window and needed sideways scrolling: the ship Build and
  Hulls tabs and the port Workshop at the normal UI size, and more at 1.25× and 1.5×. Costs and tags
  now wrap, card grids follow the window width, and wrapping text is narrowed to its column
  (`UIK.fit_paragraphs`).
- The battle report was 10 px wider than planned and ran 6 px past the right edge of the screen at
  every UI size, cutting the last character of right-aligned text ("Chance 32%"). At UI 1.5× it also
  ran 12 px below the screen. Its footer note and rows now wrap inside the planned width and the panel
  is docked by its real size, from under the top strip to the foot of the screen.

**New checks.**
- The layout suite opens every tab of the ship, crew, pets, port, log and system windows in both
  languages at UI 1.0/1.25/1.5 and requires that the content fits the window's width.
- It also builds a battle report with every kind of row (rare foe, plunder, gear, a new and a duplicate
  curio, a recruit offer with a full roster) and requires that the panel stays on screen and keeps its
  planned width, before and after Collect. These checks fail on the previous report code.
- The core suite checks that every ambient sprite, both title emblems and a lit-window overlay for
  every port building exist.
- `game/tests/shots.tscn` is a development-only harness that runs the real main scene from a scenario
  script and saves viewport screenshots (see README). It is not exported. The scenarios used for this
  pass are kept in `tools/shots/scenarios/` (a tour of every stage, every window tab, and a width
  audit), with `tools/shots/run_linux.sh` to run them without a display.

## Earlier polish changes (polish-01)

- Fixed the Codex progress-key mismatch that stopped every tab before its content was built.
  Collection progress now counts distinct owned entries and ignores duplicate drops.
- Card grids follow the actual scroll viewport width, including its scrollbar. The Codex
  summary, long text, reward controls and market dealer actions wrap or stack at larger UI sizes.
- Crew and pets refresh their depth key and deck visibility immediately after movement. This
  removes a reproduced one-frame lag when crossing a floor-cell boundary or reaching a hatch,
  while retaining furniture occlusion and the original foot position.
- Regression checks cover cell crossings and ladder arrival, all seven Codex tabs and the
  stocked market in both languages at all three UI sizes and both 16:9 and 16:10 logical sizes.
- `tools/validation/validate_windows.py` runs checks with child-process profile paths under
  `build/validation/`; the player's installed settings and saves are not used. Exported releases
  exclude the test scenes and scripts.
- The first-launch language picker now supports its intended keyboard focus without startup warnings.

The earlier HTML/JavaScript version is retired. It is kept in `archive/web-prototype-superseded/` only
as a mechanics and data reference. Its test results don't apply to this build.

## Native artifacts

| Path | Description |
|---|---|
| [build/ProjectSevenSeas-world-art-02.zip](../build/ProjectSevenSeas-world-art-02.zip) | Current 2.0.1 Windows distribution; extract the EXE, PCK and licenses together |
| `build/windows/ProjectSevenSeas.exe` | Windows x86-64 executable: PE32+, GUI subsystem, official 4.7.2 release template |
| `build/windows/ProjectSevenSeas.pck` | Current resource pack, kept beside the matching EXE and not embedded |
| `build/windows/licenses/` | Audio licence record and the licence texts for the bundled audio and fonts |
| `game/project.godot` | The Godot project |
| `game/export_presets.cfg` | Export preset "Windows Desktop" |
| `docs/ASSET_INVENTORY.md` | Inventory of every shipped texture, font and audio file, and the code-drawn scene elements |
| `docs/AUDIO_LICENSES.md` | Per-file audio sources, creators, original names and licences |
| [docs/WORLD_ART_02.md](WORLD_ART_02.md) | Current release changes, compatibility notes and known limits |
| [docs/WORLD_ART_02_VALIDATION.json](WORLD_ART_02_VALIDATION.json) | Final current-release validation evidence; package hashes are recorded in the Windows handoff |

**Historical early-native export hashes (before world-art-01; not current package hashes):**

```
1edeef2171ef1dc274f2175bf90de4da4658731983edb3a855415a4d9dabfb4b  ProjectSevenSeas.exe
13ff5d591979c6cbbd5d30860b2013aa705d82ae46a738da614650ce0faac422  ProjectSevenSeas.pck
```

That historical EXE used the unmodified release template; game content lived in its matching PCK.
For the current distribution and immutable checkpoint hashes, use
[Windows handoff](WINDOWS_HANDOFF.json), rather than the historical values above.

### Windows checkpoints

Builds sent for Windows testing are immutable, read-only directories under `build/windows-checkpoints/`.
Each holds the exe, the pck, `licenses/` and an English `HANDOFF.md` with hashes, changes and the
requested Windows checks. `docs/WINDOWS_HANDOFF.json` always describes the newest one. The
`build/windows/` contains the current release export; use the matching checkpoint for immutable review.

| Revision | Contents | Windows status |
|---|---|---|
| `world-art-02` · `2.0.1` | Current six-fix release, native landmarks, distinct port/site layouts, complete cabin groups and two-region preparation routes | Current evidence: [validation manifest](WORLD_ART_02_VALIDATION.json), [release notes](WORLD_ART_02.md) and Windows handoff |
| `world-art-01` (historical) | Ten-sea visual revision with AI-assisted landmark vignettes and regional/cabin sound layers | Ten-trial main campaign and complete catalogue reviewed; six issue groups documented in the [fullscreen review](FULLSCREEN_REVIEW_20261114.md) |
| `hud-01` | Sidebar, build window, chart footer and floor selector at every UI size; no `fac` spam | Confirmed by the user |
| `hud-02` | Fullscreen fill, title at UI 1.25/1.5, rowboat polygon error, crew depth and routes | Downloaded and hash-verified by the user; results pending |
| `chart-01` | Sea chart redesign (fog, markers, routes, zoom/pan/legend, cost-first panel, footer); everything else byte-identical to hud-02 | Not yet tested |
| `coast-01` | Natural coastlines for ports and island sites (bays, coves, headlands, spits, islets, reefs, sea stacks, two ground heights, surf); chart and HUD code byte-identical to chart-01 | Not yet tested |
| `int-01` | Composed ship interiors (partitions with doors and lanterns, stanchions, mess tables, guns, stores and cargo bays, runner corridors, floor variation), crew chores, ladder/hatch destination hover, legend stair fix; everything else byte-identical to coast-01 | Not yet tested |
| `battle-01` | Battle settlement: two-step end with an atomic Collect, result report (rewards, spoils by rarity and quantity, conditional recruit offer with Sign on / Let go and full-roster handling), weapon-specific combat effects, defeat reactions, live item drops into a spoils counter; everything else byte-identical to int-01 | Not yet tested |
| `guide-01` | Island landing party in a staggered formation with single-file walks, idle glances, crew hover (marker, others dimmed, tooltip) and click to the crew window; first-session guide (five contextual steps from ship levels to the first room, Hide / Show again); everything else byte-identical to battle-01 | Not yet tested |
| `polish-01` | Includes the November 8 content expansion; fixes Codex opening, responsive cards and dealer actions, same-frame crew/pet surface ordering | 1,906 core and 472 layout checks pass on Windows Godot headless; interactive visual review pending |
| `life-01` | Ambient life in every stage, wake/bow wave and passing rocks while sailing, title under sail with an emblem, lit windows and lighthouse beam at night, resource-change notes, hit-stop, opaque fading windows, slash-effect fix, every window tab fits its width, battle report kept on screen | 1,950 core and 748 layout checks pass on Windows Godot headless; exported exe starts cleanly; stages reviewed from software-rendered screenshots on Linux; playtest on a real GPU with sound pending |
| `craft-01` | Battle camera with a wide opening shot, natural ground borders, a compact combat log, boss intros with a horn and a boss bar, finishing-blow slow motion; weather by region (overcast, rain, fog, storm with lightning and thunder, ashfall) with original rain/storm/thunder sounds and a System toggle; dithered sweeps between stages | 2,118 core and 748 layout checks pass on Windows Godot headless; exported exe starts cleanly; stages reviewed from software-rendered screenshots on Linux; playtest on a real GPU with sound pending |

## Polish pass: what was integrated

### Multi-deck ship architecture (highest priority)

**Level model.** Every hull is now a stack of named levels. Each level is either an **open** deck
(exposed to the weather) or an **interior** level (under cover):

| Hull | Open decks (elevation, cells) | Interior levels (elevation, cells) | Total |
|---|---|---|---|
| Starter | main 0 (12×6) | gun deck −1 (12×6), hold −2 (10×6) | 3 |
| Voyager | main 0 (13×6), quarterdeck +1 (5×6) | gun deck −1 (18×6), hold −2 (16×6) | 4 |
| Adventurer | main 0 (13×7), quarterdeck +1 (6×7), forecastle +1 (5×7) | gun deck −1 (24×7), orlop −2 (22×7), hold −3 (18×7) | 6 |
| Legend | main 0 (15×8), quarterdeck +1 (7×8), forecastle +1 (6×8), poop +2 (5×8) | gun deck −1 (33×8), orlop −2 (31×8), hold −3 (27×8) | 7 |

**Zone rules** (`scripts/core/rules.gd`):
- Each facility has a zone: `deck` or `interior`. Only the lookout, boarding gate and guard post are
  deck fittings. Every other facility (cabins, quarters, galley, workshop, storage, pet rooms and so
  on) is an interior room.
- `zone_ok`, `eligible_decks`, `is_open_deck` and `deck_kind` enforce the rule. A room can't be placed
  on an exposed deck and a fitting can't go inside.
- Placement previews, build, move, preset apply, save validation and migration all go through
  `Rules.can_place`. A refused placement explains why (`err.zone_interior` / `err.zone_deck`).
- Each build-palette card shows the facility's zone and the levels of the current hull where it fits.
  If it fits nowhere, the card shows a warning.
- Starting a build switches the view to a suitable level when the current one can't hold the
  facility.
- The Hulls tab lists each hull's open and interior levels.
- The open decks hold only fixed naval fittings: mast, helm, hatches, rails and rigging, plus those
  three facilities. They stay free for crew movement and boarding fights.

**Level view** (`scripts/view/ship_view.gd`):
- View level 0 is the weather deck: all open decks together, with the raised castles.
- View level *k* is the *k*-th interior level from the top, drawn as a cutaway with everything above
  it removed.
- The HUD level selector, PgUp/PgDn and Tab switch levels. The selector shows the level's EN/ZH name,
  its kind (open or interior) and a hint about what may be built there. It replaces the old "All
  decks" label.
- Switching level gives a creak sound. Crew, pets and effects are shown only on the level they
  stand on.

**Stairs and hatches:**
- Each hull defines default hatch ladders. Each ladder links a covered level to the level above it
  through a hatch on the deck.
- `Actions.auto_stairs` makes sure every pair of joinable levels has at least one link. It uses the
  default ladder first, then the free cell nearest the middle of the shared span.
- Crew pathing, work assignment, departure checks, reachability warnings and boarding reinforcement
  all use the same stair and ladder graph.

**Inspector:**
- A selected facility shows which level it is on.
- A selected stair shows whether it is a deck stair or a hatch ladder, and which levels it joins.

**Boarding battles** (`scripts/view/battle_view.gd`):
- The fight takes place on the real weather decks of both hulls, joined by planks and grapnels.
- Defenders climb up through the nearest hatch and form on deck.

**Saves and migration:**
- Each deck in the save keeps its `id`, `kind` and `elev`. Presets store `deckId`, so a preset is
  matched to levels by name rather than by index.
- Schema 5. `GS.migrate` upgrades schema-3 saves through 4 and schema-4 saves to 5:
  1. It rebuilds the deck list from the hull with `Actions.rebuild_decks`. Facilities, doors and
     stairs carry over by deck id, and the default stairs are added.
  2. It re-seats each facility with `Actions.reseat_facilities`. A valid placement is kept. Otherwise
     the facility moves to the first free spot on a suitable interior level. If there is no room, it
     is stowed and its crew assignments are cleared. Uids, levels, damage and assignments are kept
     wherever possible. Required facilities are placed first.
  3. It clears the old single-level layout presets.
  4. It writes a ledger entry (`log.ship_refit`) saying how many rooms were moved off the open deck.
  5. It adds the collection book, curio-shard and set-reward fields, and backfills every seen enemy
     with kills, variants and region sightings.

**Scale:** a ship cell is 2×2 terrain tiles (64×32 px) and one deck level is 48 px high. This was
fixed in the geometry, so the crew and the hull stay in proportion. Camera zoom only changes how
close the view is.

### Scene craftsmanship

- **Ports:**
  - Each of the 20 ports has an authored style: town, market, fort or outpost (`PORT_STYLE`).
  - Building order, spacing and depth are seeded by the port id, so ports no longer repeat.
  - **Market ports** have a plaza with a landmark (statue, pillar, crystal, ruined pillar or tree)
    and stalls with goods.
  - **Towns** have street stalls and back-row homes with chimney smoke.
  - **Forts** have a cannon line, flags and a gate.
  - **Outposts** have sparse homes, net racks and a campfire.
  - Every port has regional bunting or laundry lines, a regional tint and moored rowboats.
- **Rowboat landing:**
  - Arriving at an island landing now rows the party ashore in a two-part rowboat with oars, a wake
    and a shadow. The trip takes about 3.4 s, with a rowing sound.
  - The party then steps up onto the jetty one by one.
  - The landing is skipped when Reduce Motion is on.
- **Palms:** a curved, ringed trunk with a crown knob, coconuts and eight arched fronds with drooping
  leaflets. They replace the earlier blob palms.
- **Hooded characters:** a rounded cowl with a peak that falls back, a mantle, an oval face opening
  with inner shadow and rim light, and seams on the back view.
- **Battle FX:** large bursts with a ring, rays and a core for crits (gold), skills (blue for allies,
  red for enemies, with a ground ring) and knockouts.
- **UI size option:** Settings → UI size scales the HUD, windows and dialogs to 1.0, 1.25 or 1.5. This
  helps long Chinese text.

### Natural coastlines (coast-01)

- **Builder:** `scripts/view/coast.gd` shapes land from warped, roughened disks and capsules (masses,
  coves, headlands, spits), then fixes the cells actors need as land and the berth and boat lanes as
  water. A clean-up pass turns specks into offshore rocks, fills small lakes and removes one-cell spurs,
  notches and diagonal pinches, so edges stay clean in pixel art.
- **Elevation and tiles:** raised land (8 px) and low beach ledges (4 px). Beach width follows exposure:
  cliffs and shingle on open coasts, wide sand, wet sand and lagoon shallows in sheltered bays. Water is
  tiled by distance to land (lagoon, shallows, reef, sea, deep), with a surf line along every shore.
- **Ports:** the straight pad and checker paving are gone. The town sits on a raised terrace with
  ridges and back bays, a peninsula, offshore islets, a pier cove with moored boats, a sand arm and a
  lighthouse headland. The quay is stone slabs at the berth and the street is ragged cobble; plots,
  lanes, plazas and set-piece clearings are worn into the ground. Groves, palms, reeds, tufts and
  driftwood follow noise and the shoreline; pillars and statues are rare landmarks.
- **Sites:** shaped from the room graph with coves, a landing spit, a reef headland and islets. Gull
  Rock is hand-tuned with cliffs, a north-east headland and sea stacks.
- **Art:** per-region cobble, slabs, wet sand, shingle, cliff, dune, rubble, meadow and forest ground,
  beach and band faces, reef and lagoon water, sea stacks, sea rocks, reeds, tufts and driftwood.

### Ship interiors (int-01)

- **Layout:** `scripts/view/ship_dress.gd` composes every interior level deterministically per hull and
  level, between the facilities. Corridors with canvas runners (duckboards in the hold) join every
  ladder, hatch, bulkhead door side and facility work spot. Frame columns every 5–6 cells split the
  level into compartments: on the orlop and in the hold, plank partitions run in from the far wall and
  end in a door post with the door hooked open and a lantern. Each compartment is one kind of room
  (orlop: store, sail room, berths, carpenter; hold: dry goods, casks, stores, grain and hens). The gun
  deck has guns at every other port and a mess table under a lantern per compartment. Stanchions stand
  beside the corridor. Walls and the near row are filled in part with capped runs, so floor shows
  between groups, and worn floor patches vary the planking.
- **Navigation:** furnished cells are blocked for crew pathing in the view only; the rules ignore them.
  A cell is furnished only off the corridors, away from ladders and hatches, clear of facility fronts,
  work-spot access and door sides, and when its free neighbours stay connected without it. Open decks
  (boarding) are not furnished. Build modes fade the furniture and it never blocks placement.
- **Crew:** idle crew sometimes work at a piece (guns, pump, mess table, cargo, sails...) and hover
  shows the chore. Hovering a ladder or hatch names its destination.
- **Art:** 27 voxel pieces in two rotations with per-cell shadow slices, runners and duckboards in 16
  joins, six floor patches and cargo battens (`tools/artgen/gen_dressing.py`).

### Battle settlement (battle-01)

- **Two-step end:** when a fight ends, the view calls `Actions.end_encounter`, which stores the
  outcome, the recorded commands and the spoils plan on the encounter and grants nothing (autosaved).
  The result report is built from `Actions.preview_encounter`, a dry run of the settlement. **Collect**
  calls `Actions.resolve_encounter` with the recruit choice and settles rewards, items, XP, losses and
  the recruit in one transaction with an autosave. A reload during the report restores the finished
  battle (`BattleView._restore`) and reopens the same report; a settled attempt id cannot commit twice.
- **Spoils plan** (`scripts/core/settle.gd`): the reward table becomes ledger rows (kind, quantity,
  rarity, icon), seeded by the attempt. Each row is split over the opponents that carry it (bosses and
  rivals triple, decoys nothing). The same plan drives the live drops and the commit.
- **Recruitment:** only defeated people (37 regional kinds and the pennant pirates) can ask to join.
  The chance comes from per-archetype bases (6–16 %), is scaled by the encounter kind (elite ×1.15, boss
  ×0.6, trial and legend ×0) and is capped at 45 %. Candidates come from the tavern generator with an
  archetype-matched class and the region's origin. The player must choose Sign on or Let go. A full
  roster disables Sign on and shows a berth note.
- **Result report** (`scripts/ui/battle_report.gd`): docked right between the HUD bars, with the arena
  visible on the left and the camera panned to the survivors. It has Rewards, Spoils (rarity chips,
  item rows with ×quantity, storage-full and salvage notes) and Recruit sections, plus defeat and
  retreat variants.
- **Effects** (`scripts/view/battle_fx.gd`): weapon-specific swings and projectiles that land on
  arrival, sparks, knock-back, crit emphasis, skill symbols, wind-up rings, heal crosses, status marks,
  white-flag and smoke defeat reactions, and rarity-ringed drops that fly into a spoils counter. Every
  effect is attached to its unit, so it depth-sorts with that unit.

### Landing party and first-session guide (guide-01)

- **Formation** (`scripts/view/site_view.gd`): at a room the four crew stand in two staggered rows left
  of the marker (about 20 px apart in a row, 12 px between rows, leader at the right of the back row)
  and the pet stands in front of the leader. Before, they stood in a 14 px diamond with the pet 2 px
  from the second member. Animation phases are desynced, and idle members glance aside, back or at a
  neighbour on per-member timers.
- **Walking:** a walk to the next room shifts the group with a 0.07 s stagger. A walk across two or
  more rooms becomes a single file on the leader's line: followers join nearest first, about 0.3 s
  (about 19 px) apart, with up to 2 px side-steps, and spread to their spots at the end. A new walk
  first settles stragglers, and each walk reports one arrival. The island builder also forces these
  single-file legs onto raised, prop-free land.
- **Hover and click:** a member under the pointer gets a selection marker, the other members and the
  pet drop to 50 % opacity, and the tooltip shows name, class, level and role. The front-most figure
  wins; the room marker itself (within about 12 px) still picks the room. A click opens the crew
  window on that member.
- **Returning to the ship:** the moored rowboat is clickable (hover: Return to ship), and the site HUD
  has a Return to ship button. Either walks the party back to the landing for free and boards the
  ship; no stamina, food or time is spent, and cleared rooms stay cleared. From the ship at an island
  the HUD's Go ashore button (also in the chart footer) lands the party at the landing again.
- **Guide** (`scripts/ui/guide.gd`): while the first main objective is open, one card at a time points
  at the next control with a pulsing gold frame and an arrow: ship levels, Set sail, the objective's
  destination in the chart list, Sail (with a note when it is blocked), and a room after landing. Each
  step shows only when its screen is active and nothing covers it, and ends on the action. The card is
  placed beside its target and never over it, the top bar or the objective chip. Got it skips a step;
  Hide guide turns it off; System > Settings > Show again turns it back on. Progress lives in Settings
  (per install, not per save).

### Audio

- **Autoload** `scripts/core/audio.gd` (`Audio`):
  - buses Master, Music, Ambience and SFX;
  - crossfading music (two players) and ambience beds (two players with loop-point crossfades);
  - a 12-voice SFX pool with per-sound cooldown, voice cap, round-robin variants and pitch jitter.
- **Scene mapping:**

  | Scene | Music | Ambience |
  |---|---|---|
  | Title, open sea | sailors' chant | masts and wind |
  | Port | pirate ship theme | harbour gulls |
  | Island | none | coast waves |
  | Dungeon or secret | none | cave |
  | Battle | battle music | sea (boarding), cave, harbour or coast, by location |

- **Victory and defeat:** short stingers that duck the music.
- **UI sounds:** every button clicks automatically. Confirm, back, close, toggle and switch sounds are
  chosen by button type. Error notices beep. Windows give open and close sounds.
- **Game actions:**
  - build, move and stairs → place; demolish and stow → demolish; repair and upgrade → repair;
  - doors, hull creak, coins for trade and recruiting, equipment, pages for quests, and so on.
- **Combat sounds:** wind-ups, swings, slashes, hits and heavy hits, blocks, guns, cannon fire and
  cannon hits, splashes, heals, skills, knockouts, wave bells, and a ram sound when a boarding starts.
- **Settings:** Master, Music, Ambience and Effects sliders (0–100 %), applied live and saved. A note
  credits the sources.
- **Sources:** all CC0. Kenney packs, three OpenGameArt tracks (Thimras, beardalaxy, Eldritch Grim)
  and BigSoundBank recordings. The two stingers are original, made by `tools/audiogen/gen_stingers.py`.
  The licence of each file was checked before download. Non-commercial, no-derivatives and unclear
  licences were rejected, and the rejected candidates are listed. See `docs/AUDIO_LICENSES.md`. The
  licence texts ship in `build/windows/licenses/`.

## What the native build contains

### Scene flow (`scripts/boot.gd`, `scripts/main.gd`)
- **First launch:** a language picker drawn over the ship at dusk, prompting in both languages.
- **Title screen:** the live ship under sail as backdrop, framed beside the menu, with a ship's-wheel
  emblem. Continue (newest save), New Game, Load (manual and recovery slots with summaries), Settings,
  Language and Quit.
- **Stage switching** follows the game state:
  - port or open sea → ship stage;
  - island, dungeon, wreck or arena → exploration stage;
  - any encounter → battle stage.
- **Sailing** plays a short transition with set sails, a wake and bow wave, a scrolling sea and rocks
  drifting past (click to skip).
- **Sea events** (stranded vessel, inspection, cache, clue, weather, shortcut) open as dialogs. Pirate
  and monster events become boarding or sea battles.
- **Battle reports:**
  - victory: rewards, XP, ledger note;
  - defeat: losses, injured crew, damaged facility, return port;
  - retreat.

### Ship stage (`scripts/view/ship_view.gd`)
- The multi-deck hull described above, viewed one level at a time. Rigging and sails can be toggled.
- **27 facilities** as animated voxel dioramas, each with idle and working states. They also have
  work spots, lights and effects such as steam, smoke and sparks.
- **Living crew:** pixel puppets walk the levels along ladder-aware paths, go to their posts, work,
  idle, sleep and show mood bubbles. Pets roam the decks too.
- **Build mode:** place, move, rotate, stow and demolish facilities, place stairs and toggle bulkhead
  doors. Cell markers show valid and invalid cells and the zone rule, and unreachable facilities are
  flagged.
- **In port,** the town sits on a natural island coast beside the ship (`scripts/view/coast.gd`, see
  Natural coastlines below). Its market, tavern, workshop, quest board, house and navigation office can
  be clicked to open the matching services.
- Day/night tint from the in-game clock, and regional terrain and props for ten seas. At night the
  town's windows are lit and the lighthouse beam sweeps the harbour.
- Ambient life (`scripts/view/ambience.gd`): gulls, glints, leaping fish, cloud shadows, butterflies or
  fireflies over the port meadows.

### Exploration stage (`scripts/view/site_view.gd`)
- **Terrain:** each location's room graph is laid out as an isometric island. The coast is shaped
  from it (masses, lobes, coves beside trails, a spit at the landing, a headland with a reef, offshore
  islets) with per-type styles for island, dungeon, wreck, secret and arena. Gull Rock is hand-tuned:
  cliffs, a long north-east headland and three sea stacks over a reef.
- **Arrival:** the rowboat landing at the jetty.
- **Rooms:** each room shows its state (open, locked, hidden, cleared) with markers and a floating icon.
  Rooms with enemies preview the enemies in place, and loot rooms show chests and crystals.
- **Party:** up to four formation crew plus the explorer pet stand in a staggered formation and walk
  the trails to the chosen room, in single file on longer walks. There they fight, search, repeat a
  cleared challenge, or start a legend challenge in the postgame. The stamina cost is shown up front.
  Hovering a member highlights them and dims the others; a click opens their crew page.

### Battle stage (`scripts/view/battle_view.gd`)
- The deterministic combat simulation (`scripts/core/combat.gd`) runs live at ×1/×2/×4.
- **Arenas:**
  - boarding: both real weather decks, joined by planks and grapnels, on a sea with whitecaps and a gull;
  - land fights: a regional field.
- Crew, pets and enemies are animated sprites. Battles show:
  - floating damage, crit, heal and status text;
  - projectiles, slash, hit and spark effects, and the large bursts;
  - skill wind-up warnings, hazards with screen tint, wave arrivals and an event log.
- **Commands:** pause, stance, skill priority, focus target (click an enemy), retreat and skip. Each
  command is recorded with its tick and replayed by the authoritative resolver
  (`Actions.resolve_encounter`), so the outcome you watch is the one that is committed.

### HUD and windows (`scripts/ui/`)
- **HUD:** compact resource strip, objective line, icon navigation with hotkeys, view controls (level
  selector, zoom, sails), a context action (Set sail / Emergency return), build hints, hover tooltips
  and toasts. During the first objective a getting-started card points at the next control.
- **Windows:**

  | Window | Tabs or contents |
  |---|---|
  | Ship | build (with level eligibility), layout, hulls, services (repair) |
  | Inspector | selected crew, facility (with level and access), stair or door |
  | Crew | formation, detail, equipment, skills, classes |
  | Pets | eggs (hatching), roster (roles, evolution) |
  | Port | investment, market (goods, equipment, daily curio dealer and shard exchange), tavern, workshop, quest board |
  | Chart | one illustrated chart of the ten seas with rule-based exploration fog, markers, routes, zoom/pan/fit and legend; cost-first destination panel with supplies projection and scout intel; footer Sail / Fast travel / Explore |
  | Codex | locations, regional bestiary with claimable rewards, classes, pets, items, clues, collections (sets, charts, shards) |
  | Overview | objective, stamina and food, readiness, quests, and the log |
  | System | saves, settings (language, battle speed, UI size, fullscreen, motion, getting-started tips, audio volumes), captain |

### Game systems (`scripts/core/`, ported from the archived prototype)
- **Ships:** four hulls with 3–7 levels, 27 facilities with zones, stairs, hatch ladders and doors,
  reachability rules, departure requirements, repair.
- **Crew:** 36 classes (12 base × 2 branches plus base forms), respec that keeps level and mastery,
  legacy passives, equipment (179 items), formation lanes.
- **Bestiary:** 50 expansion enemies (30 monsters, 10 bosses, 10 rares, plus a summonable swarmling)
  across ten regional rosters, 3 new combat archetypes, 18 enemy skills, 12 traits and 6 elite
  variants. Per-monster drop tables feed first-kill trophies; the Codex tracks seen/defeated, kills,
  variants and regions, and pays one-time 50%/100% region rewards.
- **Collections:** 82 relics, trophies, charts, lore pages and curios; 15 sets whose modifiers apply
  once complete and whose gold/material/shard/item rewards are claimed once; chart digs at their
  location; duplicate conversions into curio shards; and a deterministic daily curio dealer with a
  shard exchange in every port.
- **Scout and supplies:** a healthy scout on the crew reveals exact threats, rare sightings, hidden
  rooms and sea-event odds; route cards project supplies on arrival.
- **World:** ten seas and 100 locations with knowledge states, voyages, food per leg, sea events,
  fast travel, Emergency Return and port aid.
- **Economy:** port investment, market, tavern recruiting, workshop crafting, specialties, galley and
  workshop production.
- **Pets:** 10 families, deterministic egg recipes, three roles, evolution.
- **Campaign:** 100 quests, captain trials, the title, postgame and legend challenges.
- **Saves:**
  - schema 5, migrated from schemas 3 and 4;
  - 3 manual slots plus 3 rotating recovery autosaves under `user://saves`;
  - atomic writes with SHA-256 content hashes;
  - corrupt files are detected and never loaded.
- **Localization:** 2,424 keys in both languages, built from `game/i18n/source/` by
  `tools/i18n/build_strings.py`, which reports 0 key or placeholder mismatches. Saves contain no
  localized text.

### Assets
- **Textures** (`game/assets/gen/`, made by `tools/artgen/`): all original, generated by the project's
  own voxel and pixel renderers. They cover:
  - ship hulls and their levels, facilities, terrain tiles and props for ten regions, buildings;
  - character layers and creatures (pets, monsters, bosses);
  - UI theme, icons, markers, bubbles and effects.
- **Code-drawn scene elements:** rowboats, stalls, net racks, bunting and laundry lines, battle
  bursts, the wake and bow wave, the lighthouse beam and firefly glows.
- **Audio** (`game/assets/audio/`): 3 music tracks, 5 ambience loops and 53 effects, all CC0. Two of
  the effects (the stingers) are original.
- **Font:** Fusion Pixel 12px (SIL OFL 1.1). It includes glyphs from Ark Pixel, Cubic 11 and Galmuri,
  and their licence texts ship in `build/windows/licenses/` with it.

`docs/ASSET_INVENTORY.md` lists every file.

## Verification actually performed

| Check | Result |
|---|---|
| `godot --headless --import` | Completes without errors. All audio imports, with loops set in code |
| Script load check (headless suite) | Every script under `scripts/ui/` and `scripts/view/` loads with no parse errors |
| Headless test suite (`res://tests/test_main.tscn`) | 2,118 checks on Windows Godot: content integrity, ambient/title/lit-window art, deterministic combat, weather rolls and climates, bestiary/collection rewards and progress, save migration/hash rejection, routes/scout intel, leaving/relanding, immediate crew depth/ladder visibility and UI/view script loading. 0 script errors |
| Real-font UI layout suite (`res://tests/test_ui_layout.tscn`) | 748 checks: all seven populated Codex tabs and stocked market in EN/ZH, UI 1.0/1.25/1.5, logical sizes 640×360 and 640×400; windows bounded, no horizontal scrolling, all actions within content width, real tab content built and card grids shrink/regrow. Every tab of the ship, crew, pets, port, log and system windows on screen and no wider than its window (EN/ZH, UI 1.0/1.25/1.5, 640×360). A fully populated battle report on screen at its planned width, before and after Collect (same six layouts). 0 script errors or leak warnings |
| Offscreen screenshot review (`res://tests/shots.tscn` with `tools/shots/scenarios/`, Linux, Xvfb + Mesa llvmpipe, 1280×720) | The real main scene driven by scenario scripts: title, new game in port by day and night, sailing, island landing and exploration, a cave, land and boarding battles with the report, every window in English at UI 1.0 and in Chinese at UI 1.5. Used to find and fix the defects listed under life-01 and to check each new effect. The same sources then passed the Windows suites (life-01) |
| craft-01 screenshot review (same harness) | `battles.gd` (5 arenas × opening, intro, fight, late), `weather.gd` (12 skies and stages) and `transitions.gd` (8 mid-sweep frames) reviewed frame by frame. The frozen transition frame matches the on-screen frame exactly (maximum channel difference 0). All three runs exit with no script errors and no leak warnings (craft-01) |
| Window width audit (`tools/shots/scenarios/width_audit.gd`, same harness) | Every window tab in EN/ZH at UI 1.0 and 1.5 from a new game: content no wider than the scroll area in all four runs (life-01) |
| Scene load check | `scenes/boot.tscn` and `scenes/main.tscn` load as instantiable PackedScenes |
| Localization key check | Every literal key used by the scripts exists. Runtime-built families (deck titles, room names and kinds, sea events, outcomes) were checked against the data |
| `tools/i18n/build_strings.py` | 2,434 keys, 0 problems |
| Chart probes (temporary, deleted before export) | Fog built for new, mid and late-game states in 93–186 ms on a worker thread. The chart window fits at 16:9 UI 1.0/1.25/1.5 and 16:10 UI 1.0/1.5 in both languages: 30 of 30 layout cases pass, with default HUD insets and nothing rendered |
| Coast probes (temporary, deleted before export) | 8 ports (4 styles, 7 regions): ship water open, quay built, townsfolk stroll area, buildings, set pieces and sprites on land, moored boats afloat: 0 problems, built in 262–362 ms. 11 sites (islands, dungeons, wreck, secret, arena): rooms, trails, formation offsets on raised land, jetty and boat lane clear: 0 problems, built in 55–129 ms (coast-01) |
| Dressing probe (temporary, deleted before export) | Real ship view bound for the starter, voyager, adventurer and legend hulls: every cell reachable without furniture stays reachable, every ladder/hatch/stair approach, facility access and work-spot access reachable, every chore on a reachable cell: 0 problems on all four; view bind 157–341 ms (int-01) |
| Settlement probe (temporary, deleted before export) | 240 runs over 40 room battles with people: plan deterministic and shares sum to quantities, end grants nothing and is idempotent, binary save round trip, preview equals commit, second commit a no-op, 43 offers vs 43.6 expected, accepted recruits placed in formation, full roster refuses: 0 problems (battle-01) |
| Battle view probe (temporary, nothing rendered) | Real battle view and report bound headless for five whole battles at ×4 (people, creatures, wind-up, pirates on boarding decks): every drop share reached the counter, Collect gated on the recruit choice, restore path reopens the report, no node leak, 0 script errors (battle-01) |
| Site and party probes (temporary, nothing rendered) | All 80 non-port sites: every spot and every walk leg (including the single-file legs, both directions) on raised prop-free land, boat lane water, land unchanged, at most one prop moved, spots at least 12 px apart. Real site view on 11 islands (4 with a pet): slots after landing, one arrival per walk, closest pair on long walks at least 13.8–15.6 px, idle facings vary, hover pick 4/4 with dimming restored: 0 problems (guide-01) |
| Guide probe (temporary, main scene built without rendering) | 6 new games (English and Chinese at UI 1.0/1.25/1.5): steps in order from levels to Sail, the first case through landing, room entry and Hide guide; every card on screen, never over its target, the top bar or the objective chip: 0 problems (guide-01) |
| `godot --export-release "Windows Desktop"` | Succeeds. A search of the pack confirms that the music, ambience, effects, stingers and `audio.gd` are inside it, and that the localization sources and the probe are left out |
| `polish-01` release startup | Exported Windows exe starts and exits after 30 headless frames with no warnings or errors; all 325 packed resource hashes verified, test resources excluded and responsive grid included |
| `life-01` release | Exported on Windows by `validate_windows.py --export`; the exe starts and exits after 30 headless frames with no warnings or errors. All 337 packed files match their MD5 directory hashes; the pack contains the new scripts and atlases and no test or localization-source files. The same pack was also run with rendering on Linux (Mesa llvmpipe, 150 frames each): on a fresh profile the first-launch language choice appears over the moving sea, and with a language set the title screen draws with the emblem, the ship under sail and revision `life-01`; no script errors |
| `craft-01` release | Exported on Windows by `validate_windows.py --export`; the exe starts and exits after 30 headless frames with no warnings or errors. All 353 packed files match their MD5 directory hashes; the pack contains the weather, weather-layer and curtain scripts and the five new sounds, and no test or localization-source files. The same pack was run with rendering on Linux (Mesa llvmpipe, 150 frames each): a fresh profile shows the first-launch language choice and, with a language set, the title shows revision `craft-01`; no script errors. The run that also recorded a movie reported the title music and sea ambience playbacks as leaked when it was forced to quit; a run without recording reported none |

**Not done in this pass:** a playtest on Windows with a real GPU, mouse-driven play through a whole
session, listening tests or a complete campaign run. No game window was opened on the Windows desktop.
The screenshots come from a software renderer at 1280×720; they show composition, layout and drawing
errors, but not frame pacing, performance or how the motion reads at speed. Logs are under
`build/validation/`.

## Unfinished work and known gaps

- **Bosses and pets** use the same parameterised body plans as other creatures; they were not
  hand-drawn in this pass. New bestiary art was generated but not visually reviewed in motion.
- **Bestiary and collection balance** is first-pass: drop rates, curio prices, shard costs and set
  bonuses have not been tuned against a long-run economy simulation.
- **The seven-tab Codex and port curio dealer** pass populated real-font layout checks, including
  Chinese UI 1.5×. Screenshots of the first Codex tab were reviewed; mouse-driven interaction was not.
- **Islands and dungeons** are still laid out from the room graphs. Their coasts are now shaped
  (coast-01), but only Gull Rock is hand-tuned.
- **Land battle arenas** are still a generic regional field. Only boarding fights use real authored
  hulls.
- **Ambient life and sailing effects (life-01)** are decoration only: gulls, fish and clouds do not
  react to the ship or events, and the same mix plays in every region. Since craft-01 the clouds,
  gulls, butterflies and fireflies follow the weather. The wake is drawn from foam flecks and flat
  shapes, not a water simulation. Their cost was only seen on a software renderer; it has not been
  measured on Windows.
- **Weather and staging (craft-01)** were reviewed in still frames only. How the rain, fog drift,
  sweeps, glides and slow motion read in motion and at speed, and their cost on a real GPU, still need
  a playtest. The new sounds were checked by spectrogram and click analysis, not on speakers. The
  rain and storm beds have no separate volume slider; they follow Ambience. Weather does not show on
  the sea chart and has no forecast. Each stage change reads the last frame back from the GPU once,
  which may cost a few milliseconds at high resolutions. Boss intros play each time a boss fight
  starts, and there is no setting to turn them off (they can be clicked away).
- **Large UI (1.25× and 1.5×)** now fits every window tab without sideways scrolling, but the windows
  are cramped at 1.5× and show only a few rows at a time.
- **Ports** are seeded variations of four styles, not 20 hand-placed maps. The quay is straight by
  design (the ship's berth). Coasts have two ground heights only (beach 4 px, raised 8 px), with no
  multi-tier hills. Building a port takes about 0.3 s here, which may show as a hitch on arrival. Only
  the starter hull was probed in port. The chart's island shapes are not traced from these coasts.
- **Ship interiors (int-01)** are scenery only: one-cell pieces, partitions only from the far wall,
  no multi-cell set pieces, and building re-lays the level so nearby pieces can move. The larger hulls
  were probed and composited offline only.
- **Battle settlement (battle-01)** effects are drawn in code (simple shapes in the palette, not
  hand-drawn animations). There are at most 6 drop icons per opponent. The report closes by itself
  about 2 s after Collect. Its panel is checked to stay on screen in both languages at UI 1.0/1.25/1.5
  (life-01), but at 1.5× it shows only about six rows at a time and scrolls.
- **Landing party and guide (guide-01):** the formation is the same on every island and does not turn
  with the trail; a one-room shift keeps the group shape, so two members can pass about 11–12 px apart.
  The guide covers only the path from port to the first landing, its progress is per install, and on
  the chart its card can cover part of the map.
- **Still pending:** more integrated art and visual review of crew deck clipping. `polish-01`
  fixes a reproduced one-frame stale depth/visibility key; other occlusion cases in the P1
  feedback have not been visually cleared.
- **The ship is hidden on islands and in battle** (except for boarding). Ship management there is
  through the windows only.
- **Interactive play remains unverified.** The headless checks and the screenshot review do not rule
  out:
  - logic errors, such as an edge case in save migration or ladder placement on a cramped hull;
  - UI overlap in states the scenarios did not reach (late-game inventories, long rosters);
  - depth-sorting glitches while crew move;
  - audio balance and loop seams;
  - performance problems.
- **Windows specifics:**
  - headless checks run on Windows; rendering was reviewed only on Linux with a software renderer;
  - the exe is unsigned, so SmartScreen may warn;
  - it needs OpenGL 3.3.
