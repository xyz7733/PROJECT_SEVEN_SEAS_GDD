# Native Windows Playtest Feedback — November 7, 2026

## Reviewed Build and Scope

- Native Windows executable plus resource pack from `build/windows`, downloaded into `native-build/windows-multideck-20261107`.
- Executable SHA-256: `1edeef2171ef1dc274f2175bf90de4da4658731983edb3a855415a4d9dabfb4b`.
- Resource pack SHA-256: `13f62cb9254d7bf52dbfd067ce6821f73609107d688bf8cb11a2ebc308b4a895`.
- Manual interaction with the actual exported executable at 1280x720, Chinese interface, default UI scale. No browser or automated gameplay suite.
- This manual review is complete and the local review process has been closed. It covered a fresh Chinese-language start, ship/port presentation, the three starter levels, chart opening and destination selection, island exploration states, and a visible battle victory/result flow. Exploration and battle states were also changed through the shared interactive desktop during the review; the report does not claim a fully isolated end-to-end campaign run. Audio mix and the English-language interface were not assessed in this session.

## P0: Right-Side UI Is Outside the Window

The user directly reports that the right sidebar is cut off. The fresh-game ship screenshots show a panel starting at the far right and continuing beyond the client bounds. The selected-destination chart also extends its right detail content below the window, hiding lower content and potentially the travel action.

Reproduce: start a new game, inspect the right-side port/services panel, open the chart, and select the first discovered island. See `09-first-newgame.png`, `13-pagedown.png`, and `15-chart-selected-island.png`.

Fix safe-area placement and panel size in the actual logical viewport, including Chinese wrapping, right anchors, minimum sizes, font metrics, and supported UI scales. Keep long destination information in a scrollable area with the primary travel action always visible. All actions must remain reachable at 1280x720 and every advertised scale. Apply the correction to shared windows and HUD layout rather than moving just one screenshot's panel.

## P0: Fullscreen Has Obvious Black Bars

Windows fullscreen on a 2560x1600 (16:10) display was captured in `hud01-22-fullscreen1610.png`. The game content is centered with large black borders on all four sides. The image/client is 2560x1603. Measuring non-black pixels gives bounds `(320, 202, 2242, 1404)`, approximately 1922x1202, which is itself about 16:10. The first TUI message called this a 16:9 rectangle; that interpretation is corrected by the pixel measurements. This is a viewport/render-scale or multi-monitor adaptation problem to investigate, rather than proof that aspect-ratio letterboxing alone is responsible. `GetDpiForWindow` reported 96 during the capture.

- Make fullscreen use the whole monitor for the rendered world and HUD. Inspect integer scaling, root viewport/subviewport sizing, window-to-framebuffer conversion, DPI changes, and monitor-switch handling against the measured render rectangle.
- Keep characters and UI proportions correct; do not stretch sprites non-uniformly. Adapt the camera and ocean background to the full available viewport and anchor HUD to that actual viewport. Preserve consistent mouse hit coordinates after resizing.
- Verify 16:9 (2560x1440) and 16:10 (2560x1600) monitors, windowed and F11, at both English and Simplified Chinese. Ensure the floor selector, build panel, chart footer and Set Sail button remain reachable after expansion.
- Record the exact stretch/aspect decision in the next English handoff and provide Windows partner checks for both display ratios.

At UI scale 1.5, `hud01-13-scale150.png` also shows the title screen's large title panel and footer exceeding the 1280x720 window. The in-game ship view is mostly bounded at this scale, but the title flow needs its own safe-area layout and scroll/fit treatment. The 1.5 scale check is therefore not a pass until title, system windows, chart and ship HUD all fit.

## P1: Redesign the Chart

The user's assessment is that the chart is unacceptable. The actual chart is covered by dozens of overlapping, near-black fog circles. They obscure geographic shapes, icons, and the visual structure of the world. Selecting the first island draws a visible dotted route, but does not make the underlying map readable. See `14-current.png` and `15-chart-selected-island.png`.

Build a coherent illustrated nautical chart with deliberate coastlines, recognizable sea regions, consistent icon hierarchy, a compass/legend, and restrained cartographic decoration. Represent unexplored space with a merged fog mask, subtle desaturation, or a coherent shaded territory. Keep discovered landmarks and routes readable. Distinguish current ship, home port, selected destination, available routes, and completion state. Allow useful zoom/pan or fit controls. Destination information should clearly prioritize travel time, food consumption, stamina estimate, hazards, and a reachable travel action. Preserve discovery rules and actual route costs.

## P1: Natural Island and Port Coastlines

The user reports that island shapes are too regular. The starter port visibly sits on a long, geometrically straight land pad with repetitive paving and checker-like paths. Replace regular pads with authored bays, coves, headlands, peninsulas, reefs, offshore rocks/islets, varied beach widths, and elevation transitions. Compose paths, vegetation, landmarks, settlements, and encounter spaces around the geography. Keep collision and all required destinations reachable.

## P1: More Integrated Art and Better Interior Composition

The user explicitly requests more art assets. Prioritize assets that visibly enrich the playable scenes: distinct cabins, bunks, galley and workshop modules, shelving and storage, doors/partial walls, crates and nets, harbor fixtures, region landmarks, coastline transitions, creature silhouettes, animation variants, and readable battle effects.

The first furnished interior is now real: `PgDn` switches from the weather deck to the gun deck, removes the upper deck, and shows furniture, wall lamps, a ladder, and inhabitants. The hull is visibly larger and ordinary management facilities are off the exposed upper deck. Preserve these improvements.

The enlarged interior currently reads as a mostly empty warehouse with furniture clustered at its ends. Improve room composition, useful corridors, partial walls, doors, floor variation, warm lighting, hatch destinations, and inhabitants at work. Maintain navigation space and the exposed deck's boarding function. More atlas files alone will not meet the request.

The starter's second interior is also confirmed: `19-hold-level.png` and `20-build-palette.png` show the hold and its ladder, lamps, and a single food/storage-like furniture cluster. The build-key attempt did not reveal a usable palette within the visible window; this may be part of the shared off-screen window placement problem, so building/placement is not accepted as verified from this review.

## Additional Visual and Camera Findings

- In `17-after-battle.png`, the four exploration crew cluster tightly on the same small area near a flag. Give idle/walking party members small formation offsets and readable selection/occlusion feedback so the player can distinguish them.
- `19-hold-level.png` shows a large black triangular void beyond the finite ocean backdrop near the upper-right edge. Extend the ocean background or constrain the camera so normal views do not reveal undrawn world edges. Add a fit-to-current-level action; a zoomed interior can otherwise sit partly under the bottom HUD.
- First-game onboarding presents an objective to clear the first island but does not clearly surface the interior-level control or guide the player from travel planning to an accessible travel action. Add a short contextual first-session guide after the layout defects are fixed.

## P1: Crew Clipping Through Decks

During the Windows playtest of `hud-01`, the user reports crew visually clipping through the deck. This needs a dedicated movement/occlusion review. `hud01-02-ship.png` is context for the active scene, not a definitive isolated clipping frame. The exact root cause has not yet been established.

- Investigate the actor foot/contact point, level floor elevation, path interpolation, walkable bounds, sprite animation anchors, and depth sorting against hull/deck surfaces and furnishings.
- Use the same world-to-floor coordinates for actors, facilities, stairs and hatches. Derive occlusion from the actor's contact point and current level, rather than its sprite rectangle or animation frame bounds.
- Compare standing, walking, working, hit/downed and ladder transitions on all levels. Keep credible rail/wall occlusion and block invalid routes through solid geometry.
- Correct the underlying coordinate or ordering defect once reproduced. A global actor-on-top z-index, sprite cropping, or camera zoom can conceal one frame while breaking walls and other levels.
- Preserve the visibly improved right-side HUD layout. Add the clipping scenario to the next immutable Windows checkpoint handoff so the local partner can verify it in motion.

## Battle Presentation Observed

`16-chart-scroll.png` is actually a battle victory screenshot captured while the shared game state changed, despite its filename. It shows a completed fight with a modal reward report: 8.3 seconds, 86% crew health, 33 gold, 5 materials, and 33 XP. `17-after-battle.png` shows the resulting island exploration state. These images support feedback about the visible report and scene presentation; they do not establish that every per-enemy effect or drop animation is absent.

Keep a readable battle arena behind the result, group the new post-battle item statistics and recruitment decisions clearly, and give the player distinct visual feedback for defeated human opponents, item drops, and the final committed rewards.

## Runtime Error Observed

During level/camera/UI interaction, stderr repeatedly reports:

```
ERROR: The object does not have any 'meta' values with the key 'fac'.
   at: get_meta (core/object/object.cpp:1053)
```

Inspect selection/hover code and guard facility metadata by object kind or `has_meta`. Non-facility objects must not be treated as facilities. The exact trigger has not yet been isolated; this is a real runtime observation rather than an assumed cause. Capture a bounded diagnostic rather than allowing repeated log spam.

## Input Observation

`PgDn` successfully reveals the furnished interior. Early `Tab` attempts did not visibly switch levels in the tested state; this may be UI focus or key timing and needs diagnosis before classifying it as a confirmed binding defect. Make level selection discoverable with an obvious mouse control and destination names.

## Battle Recruitment, Effects, and Rewards

The user requests a battle outcome flow with three related rules:

1. When defeated opponents include recruitable human characters, the post-battle result may offer a recruitment opportunity. This must be a probability driven by the encounter/opponent data, not an unconditional prompt. The player can accept or decline. Recruitment must respect roster capacity, identity/class generation, existing crew rules, and bilingual result text.
2. Combat needs richer, readable visual feedback: attack wind-ups, weapon-specific arcs/projectiles, impact sparks and flashes, critical-hit emphasis, skill silhouettes, healing, status application, knockouts and defeat reactions. Effects should be large enough to read at the game's pixel scale and remain depth-sorted in the arena. Preserve pause and speed controls.
3. Defeated opponents should immediately produce visible item drops in the battle space, with recognizable item icons and a clear collection effect. The user then clarified that recruitment decisions and item accounting must be resolved together **after the battle ends**, not as interruptions during the live fight. Live drops are presentation of pending rewards; they must not trigger recruit dialogs, inventory accounting, or repeated notifications that interrupt combat. Keep the presentation readable and brief rather than accumulating persistent bodies/effects. After combat, process recruitment and item totals exactly once in the post-battle report, including item rarity and quantity. Avoid duplicate rewards between live drops and the result ledger.

The result screen should therefore have distinct sections for rewards, item quantities, and a conditional recruit offer, with accept/decline controls and capacity/full-roster messaging. Save the committed outcome atomically only after this result is resolved, so closing or recovering from the screen cannot duplicate or lose loot or a recruit.
