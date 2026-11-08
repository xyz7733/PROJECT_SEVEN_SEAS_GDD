# Project Seven Seas

An offline, single-player pirate crew management game with automatic battles. You captain one ship for the whole game: grow it from a one-deck sloop into a four-deck flagship, recruit and train a generated crew, hatch pets, chart ten seas, and win ten captain trials to earn the title of strongest captain. After that, the same save continues into postgame legend challenges.

The game follows `PROJECT_SEVEN_SEAS_GDD.md` (v1.0). It is plain HTML, CSS, and JavaScript with no dependencies, build step, server, account, or network access. All art is generated in the browser at runtime, and all names and text are original.

The interface is fully available in **English** and **Simplified Chinese (zh-CN)**.

## Run the game

Open `index.html` in a modern desktop or mobile browser. Double-clicking the file works; it loads over `file://` and needs no server.

If your browser blocks local storage for `file://` pages, the System view shows **Temporary storage**. In that case, either use **Export save**, or serve the folder locally:

```sh
python3 -m http.server 8000      # then open http://localhost:8000/
```

On first launch you choose a language. You can change it later in **System → Language**, which restarts the game. Saves are not affected because they store only IDs and seeds, never displayed text.

## Test and verify

Node.js 22 or newer is required for the tests. The smoke test also needs Chrome or Chromium; it skips cleanly (exit 0) if neither is installed. No `npm install` is needed because there are no packages.

| Command | Equivalent | What it does |
| --- | --- | --- |
| `npm run check` | `node tests/check.js` | Runs `node --check` on every `.js`/`.mjs` file and confirms `index.html` loads each source and locale script exactly once. |
| `npm test` | `node --test "tests/*.test.js"` | Runs 58 state, rules, content, and localization tests, including a full scripted campaign. Takes about 4 s. |
| `npm run smoke` | `node tests/smoke.mjs` | Drives the real UI in headless Chrome over the DevTools Protocol from `file://`, with 107 checks. |
| `npm run bot` | `node tests/bot.js [seed] [-v]` | Plays a whole campaign through the public action API and prints balance statistics. |
| `npm run verify` | all of the above except the bot | One command for check, test, and smoke. |

The smoke test covers:

- language picker, then a new game, then every view;
- keyboard shortcuts;
- sailing to the first island and fighting through the pause menu (stance, focus, resume);
- saving to a slot, reloading the page, and continuing with identical state;
- reloading mid-battle, which resumes the same encounter and outcome without a reroll;
- switching to Simplified Chinese with a restart, then checking every view again;
- confirming stored saves contain no localized text;
- checking for horizontal overflow at desktop and phone widths;
- confirming there are no console errors.

Screenshots go to `$SMOKE_OUT`, or `<os tmpdir>/p7s-smoke`. Set `CHROME=/path/to/chrome` to pick a browser.

## Controls

Everything works with the mouse. Disabled buttons show a lock and a tooltip that explains why.

| Where | Keys |
| --- | --- |
| Anywhere | `1`–`8` switch views: Overview, Ship, Sea Chart, Crew, Port, Pet Lab, Codex, System |
| Ship editor | `R` rotates the facility being placed or moved, `Esc` cancels placement |
| Battle | `Space` or `P` pauses, `1` / `2` / `4` set speed, `R` retreats, `S` skips to the end, `Enter` continues after the result. Click an enemy card to set the focus target. |
| Dialogs | `Esc` cancels, `Tab` cycles buttons |

System → Settings has text size, battle speed, reduce motion, and pause when a battle starts.

## What is in the game

- **Languages (§14).**
  - Every string comes from `locales/en.js` or `locales/zh-CN.js`. Both have the same 1,748 keys, which the tests check, along with placeholder parity.
  - Crew names are generated per locale from the same seed, so a crew member keeps their identity across languages.
- **Ship (§6).**
  - Four hull tiers: Driftling Sloop with 1 deck, then 2, 3, and 4 decks.
  - 27 facility types placed freely on grid decks, with doors and stairs. A reachability check runs from the entry point.
  - You cannot depart without a reachable Captain's Cabin, crew quarters, and pantry.
  - A facility that crew cannot reach is disabled and labelled. It works again as soon as the layout reconnects it.
  - Also: three layout presets, stowing, demolish refunds, facility upgrades, hull repair, and hull upgrades that keep every facility and crew ID.
- **Crew (§7–8).**
  - Generated recruits have stable IDs and seeds, plus origin, traits, aptitudes, pet affinity, and a personal story.
  - Port taverns rotate every three days.
  - Six battle slots across front, center, and rear lanes. Facility jobs raise production.
  - 12 base classes, each with 2 branches (36 classes). Branches unlock at 40 mastery.
  - Respec keeps level, mastery, and qualifications. Exactly two legacy passives come from mastered classes.
  - Weapon, Outfit, and Accessory slots change range, resistances, retreat speed, and stats. Class weapon rules are enforced.
- **Pets (§10).**
  - 10 families with 60 species.
  - Egg recipes are ordered colour inputs. The same egg and order always gives the same pet, and the Codex records each result.
  - A pet is assigned as a battle companion, a facility helper, or an explorer that opens secret rooms.
  - Evolution needs a Pet Lab, a level, and a specialty, and it survives save and reload.
- **Battle (§9).**
  - One deterministic engine runs island, dungeon, boarding, sea, trial, and legend fights.
  - The pause menu sets focus target, skill priority, team stance, and retreat. Every command is logged and changes the simulation.
  - Crew members do not move individually, and there is no artillery minigame.
- **World (§11).**
  - 10 seas with 10 locations each: 20 ports, 30 islands, 20 dungeons, 10 wrecks, 10 arenas, and 10 secret sites.
  - Each sea has its own main arc, captain trial, rival, specialty, palette, enemy family, and pet family. Nine of the ten also add a hazard, a special battle rule, or both. There are 86 enemies in total.
  - Locations move from Hidden to Revealed to Visited to Cleared.
  - You can sail to any revealed location. Fast travel works only between visited ports on a charted route.
  - Winning the final trial grants the title and opens 5 postgame legend challenges.
- **Ports (§12).**
  - Investment levels unlock real services: market stock, tavern size, workshop crafting and hull work, quest board, and services.
  - Regional specialties are spent on crafting, evolution, and main-arc deliveries.
  - The current main step and its trial are always shown. No reputation grind hides them.
- **Stamina and soft failure (§9.5, §11.4).**
  - Food is charged once at departure. Optional rooms cost stamina.
  - Forced fights, retreats, cleared rooms, and returning are free.
  - Only food rations and battle supplies restore stamina. Waiting or reloading never does.
  - Emergency Return and the port's free aid (meal, treatment, repair) work at zero gold and food.
  - Defeat costs 25% of unbanked gold and materials. Injuries and hull damage can be treated.
- **Saves (§15).**
  - Three manual slots and three rotating recovery saves. Recovery saves are written at ports, after battles and trials, and after hull upgrades.
  - Each save is one atomic `localStorage` write with a content hash.
  - Encounters carry an attempt ID, and resolving one is idempotent. Reloading never duplicates rewards, rerolls a fight, refills stamina, or banks gold early.
  - Saves can be exported and imported as JSON files.

## Project layout

```
index.html            Entry point; classic scripts in dependency order (works from file://)
styles.css            All styling: dashboard, pixel panels, battle screen, responsive and light/dark
locales/en.js         English strings and name pools
locales/zh-CN.js      Simplified Chinese strings and name pools
src/content.js        Classes, skills, items, facilities, hulls, pets, tuning
src/world.js          Seas, locations, room graphs, enemies, quests, rivals, legends
src/i18n.js           Locale lookup, placeholders, generated names, missing-key tracking
src/state.js          Locale-independent state, transactions, atomic save store
src/rules.js          Pure derived rules: layout reachability, stats, costs, travel, stamina
src/combat.js         Deterministic auto-battle engine and command handling
src/actions.js        Every player action as a transaction returning {ok, state, reasonKey}
src/art.js            Generated pixel sprites, portraits, icons, and sea charts
src/ui.js, views.js   DOM helpers and shared view pieces
src/view-*.js         Ship, Sea Chart, Crew, Port, Pet Lab, Codex, System views
src/battle.js         Battle screen and pause menu
src/main.js           App shell, navigation, dialogs, keyboard, boot, autosave
tests/                Node tests, campaign bot, CDP smoke test, syntax check
```

## Known limitations

- **No audio.** The game has no music or sound effects. Every event the GDD ties to an audio cue is shown visually instead.
- **Fonts come from the operating system.** Chinese text uses the system's CJK font, such as Noto Sans CJK, Microsoft YaHei, or PingFang. A system with no CJK font at all will show fallback glyphs.
- **Saves are tied to the browser profile.** They live in that browser's `localStorage`. Use Export and Import to move a save to another browser or machine.
- **Tested in Chrome only.** Automated browser testing ran in headless Chrome. Other modern browsers should work because the game uses only standard DOM, CSS grid, and Canvas features, but they were not tested here.
- **No controller support.** Input is keyboard and mouse or touch. The GDD lists controller support as optional.
