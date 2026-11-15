# World Art 01 — Ten-Sea Visual Rework

Revision: `world-art-01`. Source integration, asset generation, Windows import and release export
are complete. The [native fullscreen review](FULLSCREEN_REVIEW_20261114.md) now records ten-trial
main-campaign completion, complete catalogue fixtures and six issue groups requiring work.
OS-mouse play and speaker listening remain outstanding. Artifact hashes and the immutable delivery
checkpoint are recorded separately in the Windows handoff; the reviewed release artifacts are unchanged.

## Art direction and coverage

The direction is warm, inhabited, refined isometric pixel art across the whole campaign. The ten
seas share readable character scale, restrained material texture, warm occupied spaces and a navy,
aged-brass and cream interface. Architecture, coast composition, landmarks and ambient life identify
each region; darker regions retain clear characters and pools of warm light.

`game/data/scene_profiles.json` is a presentation catalogue. It contains ten regional identities,
100 location compositions, 310 existing gameplay-room positions and 190 combat-room compositions.
`docs/WORLD_ART_COVERAGE.json` lists those identities explicitly. A listed profile establishes
structural coverage, not a rendered or manually accepted scene.

The landmark atlas contains 100 location-specific vignettes. Main harbours and primary regional
ruins use the ten selected AI-origin masters with native dressing. Islands, secondary ports,
cellars, wrecks, trials and pet sanctuaries use explicitly composed native architecture and prop
kits. Each location selects its own variant; the manifest records components and image hashes.
All landmarks reserve a 144-by-64-pixel foundation. The static geometry audit covers all 80 site
foundations, existing room pads and every route edge including the landing approach.

| Existing content | Count | Presentation work |
|---|---:|---|
| Ports | 20 | Service order, setbacks, district/landmark placement and regional architecture |
| Islands | 30 | Room positions, landing, coast lobes/cuts, landmark and scenic pieces |
| Dungeons | 20 | Recognizable interior/ruin compositions with sheltered lighting |
| Wrecks | 10 | Grounded salvage compositions and existing room access |
| Trial arenas | 10 | Regional ceremonial settings with an unobstructed fight band |
| Secret sites | 10 | Regional sanctuary compositions with existing discovery rules |
| Combat-room contexts | 190 | Location/room-specific backdrop profiles, not new encounters |
| Hulls / facilities | 4 / 27 | Unified materials, detailing, furnished interiors and work states |
| Crew classes / humanoid NPC looks | 36 / 56 | Shared layered-puppet refinement; the NPC set includes ten rival captains |
| Nonhuman monster/rare sprite rows | 54 | Body-plan and silhouette refinement |
| Boss identities | 30 | Twenty original regional bosses and ten expansion bosses |
| Pet species | 60 | Ten families, three roles and two evolution stages |

## Regional identities

| Region | Architecture / materials | Landmark family | Ambient character |
|---|---|---|---|
| Dawnwater Shallows | Painted fishing harbour, honey wood, cream plaster and sailcloth | Lantern tower / working harbour beacon | Gulls, terns, warm dock and rope textures |
| Emberreach | Basalt, copper and sheltered forge structures | Furnace and vent machinery | Embers, thermal air and cooling-metal transients |
| Verdant Maw | Root-supported timber, woven roofs and leafy walkways | Root-bound shrine | Leaf drift, small insects and canopy droplets |
| Glass Current | Pale stone, faceted glass and crystalline roofs | Prism vault | Glasswing silhouettes, sparse refractive motes and glass resonance |
| Crown Shoals | Stone arcades, textile awnings and heraldic trim | Charter/archive architecture | Petals, cloth, workshop taps and distant harbour bells |
| Stormbelt | Low storm roofs, stone shelters and heavy rigging | Navigation beacon | Albatrosses, spray, wind and loose rigging |
| Moonwake | Indigo roofs, lantern structures and observatory details | Star-observatory architecture | Moths, moon motes, quiet night air and restrained chimes |
| Ashen Trench | Dark masonry, copper equipment and salvage structures | Ancient seal / relic excavation | Cinders, low vent air and settling stone |
| Leviathan Ring | Shell roofs, giant-bone arches and coral structures | Coral colossus | Lagoon fish, bubbles and shell resonance |
| Grand Horizon | Ivory stone, brass, sun motifs and ceremonial roofs | Compass / gate architecture | Golden motes, flags and high-harbour air |

The runtime review confirms these identities appear in rendered fixtures and includes exposed
night/weather follow-up. It identifies remaining landmark style and repeated-composition issues;
profile coverage does not establish art-direction acceptance.

## Source implementation

- **Profiles:** explicit location IDs, existing room IDs, ground-contact coordinates, coast
  shapes, scenic pieces and port layouts are generated by `tools/content/build_scene_profiles.py`.
  `SceneProfiles` provides cached `region`, `location`, `battle` and `point` lookups. The profile
  catalogue supplements existing gameplay content; it does not own room links or saved progress.
- **Exploration:** `SiteView` reads authored coordinates and applies coast shapes before forcing
  the existing room pads, party offsets, paths, landing jetty and boat lane. Landmark footing and
  routes are reserved from incidental prop placement. Existing room access and discovery logic
  continue to come from `C`, `Rules` and `Actions`.
- **Ports and battles:** `ShipView` reads service order, setbacks and styles, keeps the harbor
  composition relative to the hull and gives townsfolk work stops. `BattleView` resolves the
  location/room profile; `ArenaScene` adds its backdrop through the existing placement and
  fight-clearance checks. Missing profile or image data can use the existing procedural scene.
- **Ships and rooms:** hulls gain quieter timber, floor inlays, stern crests, window trim and
  figureheads. Facilities gain framed walls, thresholds and category plaques. New paired
  furniture groups are placed atomically only where protected access and connectivity remain
  intact. Gun-deck partitioning and less repetitive gun dressing improve room identity.
- **Actors and creatures:** all 36 classes gain profession-specific silhouettes and kit details;
  the ten rivals gain different costume/hat types, not only captain-coat recolours. Human eyes,
  outline clusters and anticipation/contact poses are refined. Thirty boss identities gain
  anatomy or regalia such as beacon armour, forge stacks, a mirror fan, an orrery, hydra heads,
  an angler lure and a coral cage. Pet families gain evolved anatomy and visible role gear.
  These remain original parameterized pixel drawings with bespoke geometry. The layered human
  animation, contact anchors, existing sizes and eleven-frame creature contracts are retained;
  unique in-game frame-by-frame acceptance of every identity has not been performed.
- **UI and chart:** navy, aged brass and cream panels, revised icons, a new title medallion and
  chart artwork share the material language. The deck control uses a compact header with an
  expandable scrolling list; keyboard floor switching and the first-session guide anchor remain.
- **Atmosphere and audio:** `Ambience.apply_region()` selects regional densities, wind, bird,
  fish and flying-insect variants and sparse atmospheric motes. Ten quiet regional layers and
  one cabin layer are synthesized by `tools/audiogen/gen_regional.py`. Caves and secret sites
  suppress the regional outdoor layer; below decks it changes to cabin sounds and the outside
  bed is muffled. Weather remains presentation-only and hidden in shelter.
- **Shutdown:** the audio owner gains `stop_all()` and `quit_cleanly()` and the title Quit action
  uses that cleanup. This is an implementation change; the earlier sound-device/exit warning
  is not considered verified as fixed until an appropriate shutdown check is recorded.

## Provenance

Most shipped game artwork is original, reproducibly generated by `tools/artgen/`: voxel scenery
and furniture, pixel characters/creatures, terrain, chart, interface and effects. These are
code-authored assets. The font and existing licensed audio retain their source and licence records.

The ten regional landmark masters are AI-assisted raster artwork created for this project with
the built-in OpenAI ImageGen tool. Its exact model is unavailable and is not asserted. Masters
are retained as `art/source/landmarks/<region-id>.png`; prompts and provenance belong in the
adjacent `manifest.json`. `tools/artgen/gen_landmarks.py` prepares transparent native-size images
(144 by 150 pixel vignettes; AI components reduced to 64 colours each) in `game/assets/gen/env/landmarks.png` and
`landmarks.json`, consumed through `Art.world_landmark()`. All ten masters have been prepared,
integrated and imported; their preview is `art/previews/world_landmarks.png`. The masters are not
third-party downloaded sprites and are not described as handmade pixel drawings. Do not apply
the audio's CC0 statement to these images.

All eleven new regional/cabin WAVs are original procedural synthesis, with no recordings or
third-party samples, released under CC0 1.0 by Project Seven Seas. Exact filenames, format and
sources are in `docs/AUDIO_LICENSES.md` and the generated regional audio manifest.

## Evidence and remaining review

Completed source and packaging evidence:

- Source profile IDs and counts were checked against the existing world catalogue. Coverage is
  100 locations and 190 combat contexts; the JSON manifest distinguishes structural coverage
  from runtime inspection.
- Component authors report Python compilation and whitespace checks. The profile static audit
  checks IDs, coordinate coverage, spacing, service order, combat backdrop offsets and existing
  prop references. This is static analysis, not a Godot gameplay test suite.
- Selected generated atlas/furniture previews were inspected during authoring. The actor author
  also rendered all monster and boss rows in memory and sampled pet family/role/evolution poses.
  These previews do not establish complete in-game composition or motion quality.
- Regional audio metadata records duration, peaks, RMS and sample continuity. Each file is
  24 seconds, mono 16-bit PCM at 22,050 Hz. These measurements do not replace listening.
- The complete `tools/artgen/build_all.py` run finished in approximately 33 seconds and produced
  33 asset-inventory rows. The ten AI-assisted masters are retained with prompts/provenance;
  the transparent landmark atlas uses native kit colours and 64-colour AI components, with sprites no larger than 144 by
  150 native pixels. Preparing and importing these images does not establish in-game placement.
- Godot Windows `--editor --import --quit` and release export completed. The logs
  `build/validation/world-art-01/import.log` and `export.log` contain no `SCRIPT ERROR` or `ERROR:`
  entries. This is editor import/export evidence, not runtime gameplay execution.
- `build/validation/world-art-01/pack-audit.json` records 382 packed files with all 382 directory
  digests matching, no audit errors, and all 14 required new resources: the profile catalogue,
  landmark atlas/metadata and eleven regional/cabin loops. It records `runtimeStarted: false`.

The November 14 follow-up now records actual native fullscreen GPU frames for 20 ports, 80 sites,
190 battle contexts and 14 hull views, a ten-trial normal-rules save chain, 186 bilingual window/tab
cases, input/management checks and bounded real-time combat. Explicit exposed-deck follow-ups cover
ten night ports and five weather states. Review fixtures, normal progression and driver corrections
are distinguished in [Fullscreen Review](FULLSCREEN_REVIEW_20261114.md).

Pending before release acceptance:

- Fix the pet target lookup, exploration Fit, Inspector and pause-banner issues, defeat-report
  empty Tween, and resource cleanup reproduced on Dummy and the default WASAPI output.
- Unify the pixel treatment of major landmarks and native scenery, and give locations more
  distinct spatial compositions. Rendered profile presence is not visual acceptance.
- Human OS-mouse play with crew movement, ladders, facilities, occlusion and stage-entry pacing;
  other resolutions, exhaustive old-save migration and low-end hardware remain outside this review.
- Speaker listening for regional/cabin loops, music/weather/effects balance and repeated cues;
  verify window-close exit and other audio devices after addressing the observed shutdown warnings.

The review did not use a browser or web server. Prior craft-01-fix1 check counts and GPU measurements
remain historical evidence for that earlier revision and are not reused for world-art-01.
