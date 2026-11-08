# Project Seven Seas — Implementation Status

**Game title:** Project Seven Seas
**Source of truth:** `PROJECT_SEVEN_SEAS_GDD.md` (v1.0)
**Launch languages:** English (`en`) and Simplified Chinese (`zh-CN`)
**Status:** All six steps are complete and verified. See `README.md` for run and test commands.

## Chosen stack

- **Vanilla HTML5, CSS, and JavaScript** with no framework, bundler, or runtime dependencies.
- Runs fully offline from `index.html` over `file://`. It needs no server, account, network service, or paid asset.
- Locale tables are plain script files (`locales/en.js`, `locales/zh-CN.js`), so they load over `file://`. Both have 1,748 keys with matching placeholders.
- Saves go to browser `localStorage`:
  - 3 manual slots and 3 rotating recovery saves;
  - each save is one atomic write verified by a content hash;
  - export and import as JSON.
- Visuals are pixel art generated at runtime with Canvas and DOM. All names are original.
- Validation:
  - Node.js 22 runs the syntax check, unit tests, and a full-campaign bot.
  - Headless Chrome runs a DevTools Protocol smoke test with no npm packages.

## Implementation checklist

- [x] **1. Foundation and localization.**
  - App shell, startup language picker, and external `en`/`zh-CN` tables keyed by stable IDs.
  - Seeded RNG and a transactional save envelope.
  - Autosave plus recovery rotation, README, and smoke test.
  - Language switching restarts the game. Saves contain no localized text.
- [x] **2. Ship and crew.**
  - Ship: four hull tiers with 1–4 decks and 27 facilities placed freely, with doors and stairs. Unreachable facilities are disabled and come back when reconnected. Departure needs a reachable cabin, quarters, and pantry. Also presets, repair, and demolish.
  - Crew: generated with stable IDs and seeds, plus locale name pools. 12 base classes × 2 branches. Mastery-gated respec keeps level and mastery. Exactly two legacy passives. Weapon, outfit, and accessory slots each change behavior.
  - Formation: six battle slots in front, center, and rear lanes.
- [x] **3. Automatic combat.**
  - One deterministic engine serves island, dungeon, boarding, sea, trial, and legend fights.
  - Pause menu for focus target, stance, skill priority, and retreat; each changes the outcome.
  - Battle speed ×1/×2/×4 and skip.
  - Soft failure: 25% of unbanked gold and materials, treatable injuries, and hull damage.
  - Resolving an encounter is idempotent across reloads.
- [x] **4. World and exploration.**
  - Ten seas, each with 10 locations: ports, islands, dungeons, wrecks, arenas, and secret sites.
  - Locations move Hidden → Revealed → Visited → Cleared.
  - Sail to any revealed location. Fast travel only between visited ports on charted routes. Sea events on the way.
  - Room-graph expeditions. Stamina is charged only for optional challenges.
  - Emergency Return and port aid work at zero resources.
- [x] **5. Economy and pets.**
  - Port investment unlocks real services: market, tavern, workshop, quest board, and services. Specialties are consumed by recipes, evolution, and deliveries.
  - Food and battle supplies; Galley and Workshop production.
  - Pets: 10 families and 60 species. Ordered egg recipes give deterministic results recorded in the Codex. Companion, helper, and explorer roles. Evolution persists.
- [x] **6. Campaign, postgame, and validation.**
  - Main arcs and side quests in every sea. Ten captain trials. The final trial grants the strongest-captain title.
  - Postgame free exploration and five legend challenges. Full Codex.
  - Accessibility: text size, reduced motion, pause on start, and icons alongside colour.
  - End-to-end tests cover GDD scenarios A–G.

## Verification (last run)

| Command | Result |
| --- | --- |
| `npm run check` (`node tests/check.js`) | 35 files pass `node --check`; `index.html` loads all 21 scripts exactly once |
| `npm test` (`node --test "tests/*.test.js"`) | 58 / 58 pass: ship, crew, combat, voyage, world, pets, state, i18n, and full campaign |
| `npm run smoke` (`node tests/smoke.mjs`) | 107 / 107 checks pass in headless Chrome from `file://`, in both locales |
| `npm run bot` (`node tests/bot.js 2026`) | Reaches postgame with the title in 183 battles (178 won, 5 lost), in-game day 72, about 3.3 s |

GDD acceptance scenarios and where they are exercised:

- **A. First expedition:** smoke test. New game, sail to Gull Rock, automatic battle, result screen.
- **B. Tactical intervention:**
  - `combat.test.js`: focus, stance, and priority each change the result.
  - Smoke test: pause, Defensive stance, focus, and resume through the UI.
- **C. Ship layout problem:** `ship.test.js`. A removed stair or a blocking facility disables the cut-off facilities with a warning, and fixing the layout restores them.
- **D. Respec:** `crew.test.js`. Vanguard → Guardian keeps level and mastery, changes skills, and charges the displayed cost.
- **E. Empty stamina:** `voyage.test.js`. Rations and supplies restore stamina; waiting and reloading do not; Emergency Return and aid work at zero resources.
- **F. Language selection:**
  - Smoke test: save in English, restart in Simplified Chinese, and get an identical state snapshot with translated views and locale names.
  - `campaign.test.js`: every campaign log line renders in both locales.
- **G. Campaign completion:** `campaign.test.js` and `world.test.js`. The final trial grants the title, postgame opens, and legend challenges become available from the same save.
