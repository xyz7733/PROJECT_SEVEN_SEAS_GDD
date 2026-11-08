# Project Seven Seas — Implementation Status

- **Game title:** Project Seven Seas
- **Source of truth:** `PROJECT_SEVEN_SEAS_GDD.md` (v1.0, with the multi-deck and audio amendments
  in §6.5–6.8 and §13.5), `VISUAL_REWORK_BRIEF.md` and `NATIVE_POLISH_REQUEST.md`
- **Engine:** Godot 4.7.2 stable, GDScript, GL Compatibility renderer, 640×360 pixel viewport
  scaled ×2 into a 1280×720 window
- **Languages:** English (`en`) and Simplified Chinese (`zh_CN`)
- **Status:** The native Windows build with the polish pass is exported. Every script compiles and
  every scene loads in the engine. As instructed, the game was **not launched, playtested or run
  through automated tests** here. Its runtime behaviour, visuals and audio mix are therefore
  unverified, and visual acceptance is the user's call.

The earlier HTML/JavaScript version is retired. It is kept in `archive/web-prototype-superseded/` only
as a mechanics and data reference. Its test results don't apply to this build.

## Native artifacts

| Path | Description |
|---|---|
| `build/windows/ProjectSevenSeas.exe` | Windows x86-64 executable: PE32+, GUI subsystem, official 4.7.2 release template (109 MB) |
| `build/windows/ProjectSevenSeas.pck` | Resource pack, kept beside the exe and not embedded (31 MB, of which about 21 MB is audio) |
| `build/windows/licenses/` | Audio licence record and the licence texts for the bundled audio and fonts |
| `game/project.godot` | The Godot project |
| `game/export_presets.cfg` | Export preset "Windows Desktop" |
| `docs/ASSET_INVENTORY.md` | Inventory of every shipped texture, font and audio file, and the code-drawn scene elements |
| `docs/AUDIO_LICENSES.md` | Per-file audio sources, creators, original names and licences |

SHA-256 of the exported files:

```
1edeef2171ef1dc274f2175bf90de4da4658731983edb3a855415a4d9dabfb4b  ProjectSevenSeas.exe
13f62cb9254d7bf52dbfd067ce6821f73609107d688bf8cb11a2ebc308b4a895  ProjectSevenSeas.pck
```

The exe hash hasn't changed since the previous build because the exe is the unmodified release
template. All game content lives in the pck.

### Windows checkpoints

Builds sent for Windows testing are immutable, read-only directories under `build/windows-checkpoints/`.
Each holds the exe, the pck, `licenses/` and an English `HANDOFF.md` with hashes, changes and the
requested Windows checks. `docs/WINDOWS_HANDOFF.json` always describes the newest one. The
`build/windows/` export above is the polish-pass build from before the checkpoints.

| Revision | Contents | Windows status |
|---|---|---|
| `hud-01` | Sidebar, build window, chart footer and floor selector at every UI size; no `fac` spam | Confirmed by the user |
| `hud-02` | Fullscreen fill, title at UI 1.25/1.5, rowboat polygon error, crew depth and routes | Downloaded and hash-verified by the user; results pending |
| `chart-01` | Sea chart redesign (fog, markers, routes, zoom/pan/legend, cost-first panel, footer); everything else byte-identical to hud-02 | Not yet tested |
| `coast-01` | Natural coastlines for ports and island sites (bays, coves, headlands, spits, islets, reefs, sea stacks, two ground heights, surf); chart and HUD code byte-identical to chart-01 | Not yet tested |
| `int-01` | Composed ship interiors (partitions with doors and lanterns, stanchions, mess tables, guns, stores and cargo bays, runner corridors, floor variation), crew chores, ladder/hatch destination hover, legend stair fix; everything else byte-identical to coast-01 | Not yet tested |
| `battle-01` | Battle settlement: two-step end with an atomic Collect, result report (rewards, spoils by rarity and quantity, conditional recruit offer with Sign on / Let go and full-roster handling), weapon-specific combat effects, defeat reactions, live item drops into a spoils counter; everything else byte-identical to int-01 | Not yet tested |
| `guide-01` | Island landing party in a staggered formation with single-file walks, idle glances, crew hover (marker, others dimmed, tooltip) and click to the crew window; first-session guide (five contextual steps from ship levels to the first room, Hide / Show again); everything else byte-identical to battle-01 | Not yet tested |

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
- Schema 4. `GS.migrate` upgrades schema-3 saves:
  1. It rebuilds the deck list from the hull with `Actions.rebuild_decks`. Facilities, doors and
     stairs carry over by deck id, and the default stairs are added.
  2. It re-seats each facility with `Actions.reseat_facilities`. A valid placement is kept. Otherwise
     the facility moves to the first free spot on a suitable interior level. If there is no room, it
     is stowed and its crew assignments are cleared. Uids, levels, damage and assignments are kept
     wherever possible. Required facilities are placed first.
  3. It clears the old single-level layout presets.
  4. It writes a ledger entry (`log.ship_refit`) saying how many rooms were moved off the open deck.

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
- **Title screen:** the live ship as backdrop. Continue (newest save), New Game, Load (manual and
  recovery slots with summaries), Settings, Language and Quit.
- **Stage switching** follows the game state:
  - port or open sea → ship stage;
  - island, dungeon, wreck or arena → exploration stage;
  - any encounter → battle stage.
- **Sailing** plays a short transition with set sails and a moving sea (click to skip).
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
- Day/night tint from the in-game clock, and regional terrain and props for ten seas.

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
  - boarding: both real weather decks, joined by planks and grapnels;
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
  | Port | investment, market, tavern, workshop, quest board |
  | Chart | one illustrated chart of the ten seas with rule-based exploration fog, markers, routes, zoom/pan/fit and legend; cost-first destination panel; footer Sail / Fast travel / Explore |
  | Codex | locations, enemies, classes, pets, items, clues |
  | Overview | objective, stamina and food, readiness, quests, and the log |
  | System | saves, settings (language, battle speed, UI size, fullscreen, motion, getting-started tips, audio volumes), captain |

### Game systems (`scripts/core/`, ported from the archived prototype)
- **Ships:** four hulls with 3–7 levels, 27 facilities with zones, stairs, hatch ladders and doors,
  reachability rules, departure requirements, repair.
- **Crew:** 36 classes (12 base × 2 branches plus base forms), respec that keeps level and mastery,
  legacy passives, equipment (167 items), formation lanes.
- **World:** ten seas and 100 locations with knowledge states, voyages, food per leg, sea events,
  fast travel, Emergency Return and port aid.
- **Economy:** port investment, market, tavern recruiting, workshop crafting, specialties, galley and
  workshop production.
- **Pets:** 10 families, deterministic egg recipes, three roles, evolution.
- **Campaign:** 100 quests, captain trials, the title, postgame and legend challenges.
- **Saves:**
  - schema 4, migrated from schema 3;
  - 3 manual slots plus 3 rotating recovery autosaves under `user://saves`;
  - atomic writes with SHA-256 content hashes;
  - corrupt files are detected and never loaded.
- **Localization:** 1,846 keys in both languages, built from `game/i18n/source/` by
  `tools/i18n/build_strings.py`, which reports 0 key or placeholder mismatches. Saves contain no
  localized text.

### Assets
- **Textures** (`game/assets/gen/`, made by `tools/artgen/`): all original, generated by the project's
  own voxel and pixel renderers. They cover:
  - ship hulls and their levels, facilities, terrain tiles and props for ten regions, buildings;
  - character layers and creatures (pets, monsters, bosses);
  - UI theme, icons, markers, bubbles and effects.
- **Code-drawn scene elements:** rowboats, stalls, net racks, bunting and laundry lines, and battle
  bursts.
- **Audio** (`game/assets/audio/`): 3 music tracks, 5 ambience loops and 53 effects, all CC0. Two of
  the effects (the stingers) are original.
- **Font:** Fusion Pixel 12px (SIL OFL 1.1). It includes glyphs from Ark Pixel, Cubic 11 and Galmuri,
  and their licence texts ship in `build/windows/licenses/` with it.

`docs/ASSET_INVENTORY.md` lists every file.

## Verification actually performed

| Check | Result |
|---|---|
| `godot --headless --import` | Completes without errors. All audio imports, with loops set in code |
| Script load-probe (temporary script, deleted before export) | All 43 GDScript files compile and load, with no warnings (guide-01) |
| Scene load check | `scenes/boot.tscn` and `scenes/main.tscn` load as instantiable PackedScenes |
| Localization key check | Every literal key used by the scripts exists. Runtime-built families (deck titles, room names and kinds, sea events, outcomes) were checked against the data |
| `tools/i18n/build_strings.py` | 1,987 keys, 0 problems (guide-01) |
| Chart probes (temporary, deleted before export) | Fog built for new, mid and late-game states in 93–186 ms on a worker thread. The chart window fits at 16:9 UI 1.0/1.25/1.5 and 16:10 UI 1.0/1.5 in both languages: 30 of 30 layout cases pass, with default HUD insets and nothing rendered |
| Coast probes (temporary, deleted before export) | 8 ports (4 styles, 7 regions): ship water open, quay built, townsfolk stroll area, buildings, set pieces and sprites on land, moored boats afloat: 0 problems, built in 262–362 ms. 11 sites (islands, dungeons, wreck, secret, arena): rooms, trails, formation offsets on raised land, jetty and boat lane clear: 0 problems, built in 55–129 ms (coast-01) |
| Dressing probe (temporary, deleted before export) | Real ship view bound for the starter, voyager, adventurer and legend hulls: every cell reachable without furniture stays reachable, every ladder/hatch/stair approach, facility access and work-spot access reachable, every chore on a reachable cell: 0 problems on all four; view bind 157–341 ms (int-01) |
| Settlement probe (temporary, deleted before export) | 240 runs over 40 room battles with people: plan deterministic and shares sum to quantities, end grants nothing and is idempotent, binary save round trip, preview equals commit, second commit a no-op, 43 offers vs 43.6 expected, accepted recruits placed in formation, full roster refuses: 0 problems (battle-01) |
| Battle view probe (temporary, nothing rendered) | Real battle view and report bound headless for five whole battles at ×4 (people, creatures, wind-up, pirates on boarding decks): every drop share reached the counter, Collect gated on the recruit choice, restore path reopens the report, no node leak, 0 script errors (battle-01) |
| Site and party probes (temporary, nothing rendered) | All 80 non-port sites: every spot and every walk leg (including the single-file legs, both directions) on raised prop-free land, boat lane water, land unchanged, at most one prop moved, spots at least 12 px apart. Real site view on 11 islands (4 with a pet): slots after landing, one arrival per walk, closest pair on long walks at least 13.8–15.6 px, idle facings vary, hover pick 4/4 with dimming restored: 0 problems (guide-01) |
| Guide probe (temporary, main scene built without rendering) | 6 new games (English and Chinese at UI 1.0/1.25/1.5): steps in order from levels to Sail, the first case through landing, room entry and Hide guide; every card on screen, never over its target, the top bar or the objective chip: 0 problems (guide-01) |
| `godot --export-release "Windows Desktop"` | Succeeds. A search of the pack confirms that the music, ambience, effects, stingers and `audio.gd` are inside it, and that the localization sources and the probe are left out |

**Not done, by instruction:** launching the game, playtesting, screenshots, listening tests, and
automated or end-to-end tests. The prototype's JavaScript test suite was not ported. GDD acceptance
scenarios A–G rely on the ported rules but haven't been re-verified in the native build.

## Unfinished work and known gaps

- **Bosses and pets** were not redrawn in this pass. Boss designs are still simple.
- **Islands and dungeons** are still laid out from the room graphs. Their coasts are now shaped
  (coast-01), but only Gull Rock is hand-tuned.
- **Land battle arenas** are still a generic regional field. Only boarding fights use real authored
  hulls.
- **Ports** are seeded variations of four styles, not 20 hand-placed maps. The quay is straight by
  design (the ship's berth). Coasts have two ground heights only (beach 4 px, raised 8 px), with no
  multi-tier hills. Building a port takes about 0.3 s here, which may show as a hitch on arrival. Only
  the starter hull was probed in port. The chart's island shapes are not traced from these coasts.
- **Ship interiors (int-01)** are scenery only: one-cell pieces, partitions only from the far wall,
  no multi-cell set pieces, and building re-lays the level so nearby pieces can move. The larger hulls
  were probed and composited offline only.
- **Battle settlement (battle-01)** effects are drawn in code (simple shapes in the palette, not
  hand-drawn animations). There are at most 6 drop icons per opponent. The report closes by itself
  about 2 s after Collect. Its layout at UI 1.5 and with long Chinese text is unchecked.
- **Landing party and guide (guide-01):** the formation is the same on every island and does not turn
  with the trail; a one-room shift keeps the group shape, so two members can pass about 11–12 px apart.
  The guide covers only the path from port to the first landing, its progress is per install, and on
  the chart its card can cover part of the map.
- **Still pending:** more integrated art, and the crew deck-clipping investigation (P1 in the
  playtest feedback; cause not yet established).
- **The ship is hidden on islands and in battle** (except for boarding). Ship management there is
  through the windows only.
- **Runtime unverified.** Compile and load checks can't catch these. Expect some of them on first play:
  - logic errors, such as an edge case in save migration or ladder placement on a cramped hull;
  - UI overlap at 1.5× size or with long Chinese text;
  - depth-sorting glitches;
  - audio balance and loop seams;
  - performance problems.
- **Windows specifics:**
  - not tested on real Windows hardware;
  - the exe is unsigned, so SmartScreen may warn;
  - it needs OpenGL 3.3.
