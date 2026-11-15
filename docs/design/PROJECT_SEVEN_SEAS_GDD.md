# Project Seven Seas

## Game Design Document

**Document version:** 1.0
**Status:** Complete blueprint; balance values require playtesting
**Target platform:** PC
**Mode:** Local single-player
**Languages:** English and Simplified Chinese (`zh-CN`)
**Working title:** Project Seven Seas
**Visual target:** 2D pixel art with readable, colorful management screens and combat arenas

Project Seven Seas is an expanded, original high-seas management RPG inspired by the public design baseline of Kairosoft's *High Sea Saga* and *High Sea Saga DX*. The game keeps the reference game's recruit, build, explore, board, and collect loop while expanding the world into a handcrafted, light-fantasy campaign.

The player commands one growing pirate ship. Sailing is automatic after a destination is chosen. Battles are automatic by default, but the player can pause and issue a small set of high-level tactical commands. The campaign leads through ten sea regions toward the title of strongest pirate captain. After the final captain trial, the world remains open for completion, collection, and experimentation.

### Reading guide

- [Product definition](#1-product-definition) and [reference baseline](#2-reference-baseline-and-design-boundary)
- [Core experience](#3-core-experience), [world](#4-world-and-narrative), and [exploration](#5-exploration-and-sailing)
- [Ship construction](#6-main-ship-and-multi-deck-construction), [crew and equipment](#7-crew-recruitment-and-growth), and [combat](#8-automatic-boarding-combat)
- [Pets](#9-pet-eggs-and-evolution), [ports](#10-ports-investment-and-regional-specialties), and [resources](#11-resources-and-progression)
- [Content](#12-quests-and-content), [interface](#13-user-interface-and-usability), and [localization](#14-localization-and-language-support)
- [Saves](#15-save-offline-and-recovery), [balance](#16-balance-principles), and [acceptance scenarios](#17-acceptance-scenarios)
- [Sources](#18-source-references), [content contracts](#19-content-and-state-contracts), and [design defaults](#20-design-defaults-and-playtest-parameters)

---

## 1. Product Definition

### 1.1 One-sentence promise

Build a living pirate ship, assemble and retrain a crew of strange specialists, explore a handcrafted fantasy ocean, and prove your captaincy through a chain of increasingly difficult sea trials.

### 1.2 Player fantasy

The player should feel like a captain who gradually turns a cramped, improvised vessel into a self-sufficient home and a highly coordinated adventuring crew. The player makes meaningful decisions before and between encounters; the crew then acts with enough autonomy to feel alive.

### 1.3 Design pillars

1. **A ship that feels inhabited.** Facilities, routes, jobs, and deck access visibly explain why the ship performs well or poorly.
2. **Readable crew composition.** Classes, equipment, pets, and formation have separate jobs. A player can understand why a build works without calculating hidden formulas.
3. **Discovery with a hand-authored purpose.** Each sea region has a visual identity, a local problem, a captain trial, and at least one discovery that changes future choices.
4. **Automatic play with meaningful intervention.** The player is never required to micromanage every character, but a well-timed high-level command can rescue a bad battle.
5. **A generous offline campaign.** There are no purchases, server dependencies, or real-time recovery walls. The game can be played for a long session or in short planning bursts.

### 1.4 Target audience

- Players who enjoy management RPGs, party building, exploration, and collection.
- Players who prefer observing an active team but still want tactical decisions.
- Players who enjoy long-form single-player progression without online pressure.
- Existing fans of compact management games who want more map variety, clearer systems, and less forced repetition.

### 1.5 Product constraints

- PC local single-player is the launch target.
- No online multiplayer, competitive ranking, account service, or required cloud connection.
- No premium currency, in-app purchase, advertisement, or real-time stamina refill.
- One main ship is the only persistent mobile base. The design does not require independent fleet management.
- The first blueprint covers the complete game rather than an intentionally reduced vertical slice.

### 1.6 Non-goals

- Realistic naval simulation with wind tables, cannon ballistics, and a dynamic global commodity market.
- Direct action control of every crew member during combat.
- Permanent-death survival as the main source of difficulty.
- A procedurally generated world that replaces authored regional identity.

---

## 2. Reference Baseline and Design Boundary

The reference baseline identifies the gameplay loop being expanded. Rules in later sections describe this project's proposed design; they do not claim to document the reference game's internal implementation.

Official public material for *High Sea Saga* and *High Sea Saga DX* describes the following foundations:

- recruiting a crew in a tavern;
- building a pirate ship;
- forming combat members;
- real-time crew combat against monsters and pirates;
- port resupply and weapon purchases;
- investing in islands to unlock stronger goods;
- quests involving mysterious islands and rival pirates;
- strengthening crew with food earned during combat.

The original mobile release and DX release have different store and monetization histories. Project Seven Seas is designed as an offline PC game with no purchase or service dependency.

The project brief and Kairosoft's simplified Chinese product listing use different Chinese names for the reference game. The GDD uses the English working title Project Seven Seas and treats those names as reference aliases only.

Community reports about stamina, grinding, UI density, and save handling are treated as design signals rather than authoritative mechanics. The new design removes real-time waiting, clarifies system roles, and keeps the satisfying parts of the reference loop: crew building, ship expansion, exploration, battles, equipment, and monsters.

---

## 3. Core Experience

### 3.1 Core loop

The game repeatedly follows this loop:

1. **Prepare:** review the next objective, repair the ship, recruit or retrain crew, adjust facilities, equip items, and choose pets.
2. **Invest:** visit a port, spend gold to improve local services, buy food and materials, and accept available work.
3. **Sail:** select a discovered destination. The ship travels automatically while the player watches progress and receives encounter notifications.
4. **Encounter:** resolve an island expedition, dungeon, wreck, event, or enemy-ship boarding battle. Combat is automatic unless the player pauses to issue a high-level command.
5. **Return and interpret:** bring home gold, materials, food, experience, reputation, discoveries, and possible recruits or eggs.
6. **Grow:** expand the ship, unlock facilities, advance class mastery, evolve pets, and prepare for a more demanding region.

Every major reward must answer at least one of three questions:

- Does it let the player reach a new place?
- Does it make a new crew build possible?
- Does it improve the ship as a home and operating base?

### 3.2 Typical thirty-minute session

The captain starts at a developed port with a partially expanded ship. The player checks the next captain-trial requirement, buys food, and replaces a damaged Guardian with a newly recruited Navigator. A second-floor training room is moved to shorten the route between the crew quarters and the infirmary.

The player selects a revealed island. The ship sails automatically. An enemy pirate ship attacks and the crew enters a boarding battle. The player pauses once to set the enemy captain as the focus target and changes the team stance to Defensive. The battle completes automatically. The crew wins, but one frontline member needs treatment and the ship spends food.

On the island, the team clears a short dungeon, finds a rare egg ingredient, and completes a local request. Back at port, the player invests in the harbor, unlocks a new regional specialty, feeds the egg in the Pet Lab, and resets one crew member from Duelist to Guardian. The next choice is whether to challenge the region captain or spend one more trip collecting materials for a better infirmary.

### 3.3 Session pacing

- A normal short session should produce one meaningful preparation decision and one or two encounters.
- A long session should support several expeditions without waiting for a device timer.
- Travelling, treatment, production, and repairing advance the in-game voyage clock only when the player chooses an action that consumes time.
- Pausing menus and layout editing never consume stamina or advance the clock.

---

## 4. World and Narrative

### 4.1 Tone

The world is light fantasy: colorful ports, comic rival captains, strange monsters, ancient ruins, and optimistic adventure. Danger is real, but the presentation remains welcoming. The player is a heroic or mischievous explorer rather than a grim conqueror.

The game may include curses, sea spirits, lost civilizations, and impossible weather as readable fantasy rules. It should not require realistic colonial economics or cruelty toward neutral civilian ports.

### 4.2 Main goal

The player begins as an unknown captain and pursues the title of strongest pirate captain. “Strongest” is demonstrated through a chain of regional captain trials, discoveries, reputation milestones, and a final open challenge. The title is earned through capability and recognition, not through owning the most money or destroying every neutral settlement.

### 4.3 Story structure

The campaign has five broad acts:

1. **A Small Flag:** learn the ship, recruit a first crew, and earn permission to leave the starter waters.
2. **The Rival Routes:** defeat regional captains and discover that the same hidden route is being pursued by several pirate factions.
3. **The Broken Compass:** recover fragments of an ancient navigation device while choosing which ports and factions to help.
4. **The Current Gates:** cross dangerous sea regions and pass trials that test ship layout, crew composition, pet utility, and exploration skill.
5. **The Horizon Trial:** challenge the current sea champion and claim the title of strongest pirate captain.

The story is guided but not restrictive. Main quests unlock sea regions and captain trials. Side quests, port development, dungeons, wrecks, and discoveries remain available at the player's preferred pace.

### 4.4 Named and generated characters

Recruitable crew members are procedurally generated. Each recruit receives a name, visual seed, origin, personality tags, class aptitude, and a small set of personal preferences. Their personal requests use short authored event templates with tag-based variations, rather than an individually written story for every recruit.

Named characters are reserved for non-recruitable roles such as rival captains, port leaders, researchers, merchants, and faction representatives. They carry the authored story while generated recruits provide the player's personal crew identity.

### 4.5 Sea regions

The full world contains ten handcrafted regions. Each region contains 8–12 locations, one captain trial, one regional story arc, one signature pet family, and a regional specialty. The 80–120-location total includes ports, islands, dungeons, wrecks, captain arenas, and secret sites; it does not add these as extra maps outside the target. Interior floors and encounters are parts of their parent location.

| Region | Identity | Main design question |
|---|---|---|
| Dawnwater | Safe currents, fishing towns, and starter ruins | Can the player build a reliable ship and basic team? |
| Emberreach | Volcanic islands and heat-adapted monsters | Can the player manage damage, food, and repair pressure? |
| Verdant Maw | Dense jungle islands and hidden inland routes | Can exploration and pet utility open alternate paths? |
| Glass Current | Crystal reefs, reflective waters, and precision enemies | Can the player adapt target priorities and class counters? |
| Crown Shoals | Wealthy ports, old pirate families, and political errands | Can the player balance investment, reputation, and recruitment? |
| Stormbelt | Violent weather lanes and isolated settlements | Can the ship layout support recovery and emergency supplies? |
| Moonwake | Nocturnal islands, dream creatures, and navigation puzzles | Can the player use discovery tools rather than raw power? |
| Ashen Trench | Deep-sea ruins and relic hunters | Can the player combine pet evolution and class specialization? |
| Leviathan Ring | Monster migration routes and large boarding encounters | Can the player keep a stable automatic battle plan under pressure? |
| Grand Horizon | Ancient gates, rival fleets, and the final captain trial | Can the player demonstrate the complete build? |

The names are working names and may be revised without changing the structure.

### 4.6 Location types

- **Port:** resupply, recruit, invest, trade regional specialties, accept quests, and repair.
- **Island:** fixed exploration map with combat groups, resources, and story encounters.
- **Dungeon:** layered combat route with a visible reward theme and a guardian encounter.
- **Wreck:** short optional risk-and-reward site found while travelling.
- **Captain Arena:** repeatable test of a specific team-building challenge.
- **Secret Site:** one-time discovery that changes a route, unlocks a pet family, or reveals a story clue.

### 4.7 Ocean society and factions

The settled ocean is held together by port charters and the Horizon Conclave, an independent gathering that recognizes legendary captains. Pirate reputation reflects daring, reliability, and victories against recognized rivals. The campaign never requires raiding neutral settlements; combat targets are hostile pirates, monsters, and formally accepted challengers.

| Faction | Identity | Player relationship | Gameplay contribution |
|---|---|---|---|
| Horizon Conclave | veteran captains who sanction the regional trials | earn recognition and challenge its champion | main story and trial access |
| Free Harbor League | independent ports sharing navigation and trade knowledge | invest, deliver specialties, and solve local problems | services, route clues, and contracts |
| Tidebound Society | naturalists and relic researchers | share discoveries and investigate ruins | pet recipes, codex clues, and optional sites |
| Crimson Pennants | ambitious rival captains seeking the same title | defeat rivals and occasionally cooperate against a common threat | boarding encounters and regional antagonists |

Relationships unlock optional services, prices, and story variations. No faction choice permanently removes a main-story port or makes the strongest-captain title unattainable. The campaign has one title-winning ending, with local epilogue variations based on completed side arcs.

### 4.8 Regional story and reward outline

The captain trial belongs to its region's arena and is included in the location total. Each trial is opened by the regional main quest; the table defines its learning goal rather than an extra grind gate.

| Region | Story hook | Rival captain | Trial lesson | Specialty | Signature pet family |
|---|---|---|---|---|---|
| Dawnwater | recover a stolen chart and restore the starter harbor's lookout | Mira Gull | combine a defender, damage dealer, and healer | Saltleaf Grain | Tidefin |
| Emberreach | carry relief supplies through a volcanic blockade | Flint Cinder | handle sustained damage and recovery | Ember Ore | Cinderback |
| Verdant Maw | resolve raids around an overgrown inland shrine | Rook Fern | choose routes and counter disruptive enemies | Verdant Resin | Mossling |
| Glass Current | expose a rival using crystal decoys to confuse sailors | Selene Prism | select targets and manage protective effects | Prism Quartz | Glasswing |
| Crown Shoals | expose a forged port charter without destroying local trade | Cassian Crest | build a flexible team for mixed threats | Crown Silk | Pearlcub |
| Stormbelt | reopen isolated harbors after a season of broken navigation beacons | Nessa Gale | maintain survival during environmental pressure | Stormwood | Cloudray |
| Moonwake | follow nighttime signals to a forgotten observatory | Orin Lantern | recognize enemy intent and use information | Moon Ink | Dreammoth |
| Ashen Trench | prevent relic hunters from breaking an ancient sea seal | Vale Ash | combine elemental control and focused damage | Abyss Alloy | Gloomjaw |
| Leviathan Ring | negotiate safe passage through a monster migration | Brakka Reef | withstand successive waves with a stable automatic plan | Leviathan Scale | Shellwarden |
| Grand Horizon | face the Conclave's champion and the rivals who reached the final waters | Aurelia Dawn | demonstrate the ship, crew, and pet build together | Horizon Glass | Starwake |

The ancient navigation device connects these arcs: its fragments reveal the safe approach to Grand Horizon. Named captains are story NPCs, while every ordinary recruit remains generated. Completing the ten trials awards the title; the saved world then remains open for free sailing.

---

## 5. Exploration and Sailing

### 5.1 Automatic sailing

The player chooses a revealed, reachable destination and confirms departure. The ship then travels automatically. The map shows route distance, expected food use, known hazards, and possible encounter types.

The player does not steer the ship frame by frame. This keeps the focus on preparation, discovery, and crew management.

Locations have four knowledge states: Hidden, Revealed, Visited, and Cleared. Story clues, port information, a completed survey, or a connected route can reveal a new destination. First arrival marks it Visited; completing its primary objective marks it Cleared. A first visit therefore does not require the player to have visited the location already.

### 5.2 Route information

Before departure, the route panel shows:

- destination and estimated voyage time;
- expected food consumption;
- stamina costs for planned optional challenges and projected remaining stamina;
- projected food and battle-supply reserves after the route;
- known environmental hazard tags;
- whether the route contains a first-time discovery;
- recommended crew capability tags;
- return-port options if the player retreats.

Unknown information is represented as a range or a clue rather than a hidden exact value. Exploration tools and port investment reveal more detail.

### 5.3 Encounters at sea

Sea encounters are authored by region but selected from readable encounter pools:

- enemy pirate boarding;
- monster boarding;
- drifting supply cache;
- damaged vessel requesting help;
- navigation shortcut;
- weather or sea hazard;
- faction inspection;
- discovery clue.

Repeated content uses alternate rewards, modifiers, and tactical conditions so that a known route remains useful without becoming the only optimal activity.

### 5.4 Discovery rules

First-time discoveries provide the largest reward and unlock map knowledge, story, facilities, or recipes. Repeat visits provide materials, food, contracts, and a smaller chance at rare drops. Discovering a location records it in the same world catalog; it does not generate an additional unbudgeted location.

Fast travel is allowed only between discovered ports and only after the route has been safely charted. Fast travel consumes the normal in-game food and voyage time; it is not a free teleport.

### 5.5 Island and dungeon exploration

An island or dungeon contains an authored route graph. The player chooses the next room, branch, resource stop, or exit; the squad moves there automatically. Battles on these routes use the same automatic combat and high-level command rules as boarding battles. Exploration requires no direct movement or aiming controls.

The next room shows its visible threats, entry stamina cost, and known reward family. The player may return along cleared paths without paying another challenge entry cost. Main objectives always have a route that can be completed without a specific rare pet; pet abilities open optional shortcuts, information, or bonus rewards.

---

## 6. Main Ship and Multi-deck Construction

### 6.1 Ship model

The player owns one persistent main ship. The ship grows through hull tiers and additional decks. A new hull tier increases available build area, crew capacity, storage, and the number of advanced facilities that can be supported.

The ship is both the player's base and the main expression of progression. There is no requirement to maintain multiple independently staffed ships.

### 6.2 Deck layout

Each deck is a grid connected by stairs, ladders, and doors. Facilities occupy one or more cells. Crew members and pets use the same navigation graph as the player view.

The build system must show:

- occupied cells;
- walkable cells;
- blocked cells;
- stairs and deck connections;
- facility coverage or work radius;
- whether a required facility is unreachable.

A layout that places a facility but makes it unreachable is invalid for normal operation. The player can temporarily create a blocked layout while remodeling, but the game clearly identifies disabled facilities and the reason.

Layout editing occurs at a safe port with the simulation paused. Unreachable optional facilities provide no production or bonuses. Departure requires reachable Command, Quarters, Pantry, and deck connections for the active crew; optional facilities may remain disabled after an explicit warning. Demolishing a facility returns its construction materials, allowing the player to correct a layout without losing progression. Saved layout presets can be applied to compatible hulls.

### 6.3 Facility categories

| Category | Example facilities | Primary responsibility |
|---|---|---|
| Command | Captain's Cabin, Chart Table, Muster Room | unlock decisions, route information, trial tracking, and formation setup |
| Living | Crew Quarters, Mess Hall | crew capacity, food use, morale support |
| Training | Practice Hall, Class Hall | experience conversion and class mastery |
| Medical | Infirmary, Recovery Room | injury recovery and safer failed expeditions |
| Production | Workshop, Galley, Material Bench | materials, food, repairs, and crafting |
| Navigation | Lookout, Compass Room, Tide Archive | discovery range and route information |
| Storage | Pantry, Cargo Hold, Secure Locker | food, materials, specialty goods, and item limits |
| Pet | Hatchery, Pet Lab, Creature Pens | egg incubation, feeding, evolution, and pet capacity |
| Social | Tavern Corner, Story Lounge, Music Room | recruitment quality, events, and crew bonding |
| Defense | Boarding Gate, Barricade Room, Guard Post | boarding readiness and damage mitigation |

Facilities have levels and upgrade conditions. Upgrading a facility improves its function or unlocks a choice; it should not only add an invisible percentage to every system.

### 6.4 Layout trade-offs

The player cannot fit every facility at maximum level. Expansion decisions should create visible trade-offs:

- more quarters versus more training space;
- larger storage versus faster production;
- safer boarding routes versus shorter crew travel paths;
- a strong Pet Lab versus a stronger infirmary;
- a broad production deck versus a compact, efficient ship.

The ship should remain useful when imperfect. A suboptimal layout costs time, capacity, or efficiency; it does not make the campaign unwinnable.

### 6.5 Level architecture: open decks and interior levels

The ship is a stack of named levels. Each level is one of two kinds:

- **Open (weather) decks** are exposed to the sky. They carry the mast, helm, rails, rigging and hatches, and they are where the crew moves and where boarding fights happen. Only **deck fittings** may be built there: the Lookout, the Boarding Gate and the Guard Post.
- **Interior levels** are under cover. Every other facility is a room and belongs on an interior level: cabins, quarters, mess, galley, workshop, infirmary, training, storage, pet rooms and social rooms.

Each facility carries a zone, `deck` or `interior`. Placement previews, building, moving, layout presets, save validation and save migration all enforce the zone. A refused placement names the reason and says which level to switch to.

| Hull | Open decks (elevation, cells) | Interior levels (elevation, cells) | Total |
|---|---|---|---|
| Starter | main deck 0 (12×6) | gun deck −1 (12×6), hold −2 (10×6) | 3 |
| Voyager | main 0 (13×6), quarterdeck +1 (5×6) | gun deck −1 (18×6), hold −2 (16×6) | 4 |
| Adventurer | main 0 (13×7), quarterdeck +1 (6×7), forecastle +1 (5×7) | gun deck −1 (24×7), orlop −2 (22×7), hold −3 (18×7) | 6 |
| Legend | main 0 (15×8), quarterdeck +1 (7×8), forecastle +1 (6×8), poop deck +2 (5×8) | gun deck −1 (33×8), orlop −2 (31×8), hold −3 (27×8) | 7 |

Level names are localized (EN/ZH). The build palette shows each facility's zone and the levels of the current hull where it fits.

### 6.6 Viewing and switching levels

The ship stage shows one view level at a time:

- **View level 0** is the weather deck: all open decks together, with the raised castles.
- **View level *k*** is the *k*-th interior level from the top, drawn as a cutaway with everything above it removed.

The level selector in the HUD, PgUp/PgDn and Tab switch levels. The selector shows the level's name, its kind and what may be built there. Crew, pets and facility effects appear only on the level where they are. Starting a build switches to a level that can hold the chosen facility.

### 6.7 Stairs, hatches and access

- Open decks at different heights are joined by **deck stairs**.
- Each covered level is joined to the level above it by **hatch ladders**.

Each hull defines default ladders. A new ship, a hull upgrade and a migrated save all start with at least one link between every pair of joinable levels. Players add or remove links in stair mode. Crew pathing, work assignment, reachability warnings, departure requirements and boarding reinforcement all use the same link graph. Removing the last link to a level makes its facilities unreachable, which the layout view flags (Scenario C).

In a boarding battle, the fight takes place on the real weather decks of both ships, joined by planks and grapnels. Defenders climb up through the nearest hatch. Interior rooms affect the fight through readiness, capacity and recovery, never as a battlefield.

### 6.8 Layout guidance

- Keep the weather deck clear apart from the three fittings. It is the circulation and boarding space.
- Put command, living and production rooms on the highest interior level so crew paths stay short.
- Put storage low in the hold. The automatic re-seating does this too.
- Put a hatch ladder near the rooms crew use most, so their paths stay short.
- Bigger hulls add whole levels rather than just wider decks. Each new level is a new routing decision: which rooms share a level, and where the ladders go.

**Saves.** Each deck in a save keeps its `id`, `kind` and elevation. Layout presets refer to levels by id. Saves written before the level model (schema 3) are migrated on load:

1. The deck list is rebuilt from the hull.
2. Facilities that still fit stay where they are. The others move to the first free spot on a suitable level, or are stowed with their assignments cleared.
3. The old presets are cleared.
4. A ledger entry says how many rooms were moved off the open deck.

---

## 7. Crew Recruitment and Growth

### 7.1 Recruitment

Ports expose a rotating pool of generated recruits. A tavern's investment level affects the range of origins, aptitude tags, and starting classes that can appear.

Each generated recruit contains:

- name and portrait seed;
- origin and preferred region;
- personality tags;
- base attributes;
- class aptitude tags;
- equipment compatibility;
- pet affinity tags;
- a small personal request or event seed.

Recruitment should create interesting choices through aptitudes, starting qualifications, origins, and personality. A recruit from the starter port can remain valuable throughout the campaign; there is no mandatory rarity ladder.

### 7.2 Roles

Every class belongs to one or more readable combat roles:

- **Vanguard:** absorbs pressure and protects nearby allies.
- **Striker:** deals direct damage to a selected target.
- **Controller:** applies slows, disables, marks, or formation disruption.
- **Support:** heals, cleanses, buffs, or improves resource efficiency.
- **Scout:** improves discovery, target information, and route safety.

Scout is a crew role. A Scout reveals combat threat tags and optional route clues when assigned to the active expedition. Navigation facilities improve the whole ship's map coverage; exploration pets identify specific secrets or optional shortcuts. These systems provide complementary information rather than three interchangeable stacking bonuses.

Ship facilities can also assign non-combat jobs. A crew member may be effective in combat but inefficient in production, or vice versa.

### 7.3 Class tree

Crew members progress through a class tree. A class has:

- a role identity;
- a basic action set;
- a class mastery track;
- a small number of active or passive skills;
- equipment and pet affinities;
- a promotion or branch condition.

The class tree should create meaningful alternatives rather than a single mandatory ladder. For example, a Vanguard can specialize in protection or disruption, while a Support can specialize in healing or resource efficiency.

### 7.4 Respec rules

Respec changes the current class path and active skill configuration. The following remain permanently available:

- personal level;
- earned class mastery records;
- unlocked class qualifications;
- discovered class nodes.

Respec costs a moderate amount of in-game currency or materials. It is affordable enough to support experimentation but expensive enough to preserve a sense of commitment. Respec never deletes a crew member's long-term history.

Only the current class grants active combat skills. A crew member can additionally equip two legacy passive skills from mastered classes. Mastery does not apply every unlocked passive simultaneously. Aptitudes improve learning or job efficiency; they do not permanently exclude a generated recruit from a class. Respec is available at a port or the ship's Class Hall outside combat and preserves the crew member's existing formation and items where compatible.

### 7.5 Class catalog

The initial catalog has twelve base classes, each with two advanced branches. Branch names and skill values are authored defaults, while the class-tree and respec structure is a confirmed requirement.

| Base class | Combat responsibility | Ship or exploration affinity | Advanced branches |
|---|---|---|---|
| Guard | protect the frontline | boarding readiness | Guardian / Bulwark |
| Duelist | focus a priority enemy | captain challenges | Blade Dancer / Challenger |
| Spearfighter | reach past protected targets | hazard clearing | Harpooner / Dragoon |
| Gunner | ranged pressure | lookout work | Sharpshooter / Skirmisher |
| Brawler | disrupt close enemies | heavy labor | Breaker / Grappler |
| Medic | heal and remove ailments | infirmary work | Surgeon / Lifekeeper |
| Cook | support and supply efficiency | galley work | Provisioner / Feastmaster |
| Navigator | identify threats and mark targets | route surveying | Pathfinder / Tide Reader |
| Tinkerer | barriers and temporary devices | workshop work | Engineer / Trapper |
| Beastkeeper | pet coordination | hatchery work | Beastwarden / Wildspeaker |
| Mystic | elemental control | relic identification | Stormcaller / Hexbreaker |
| Quartermaster | protective buffs | storage and trade | Purser / Standard Bearer |

### 7.6 Equipment

A crew member has three equipment slots: Weapon, Outfit, and Accessory. Class rules determine weapon compatibility. Weapons change range or attack properties, outfits provide defense and resistance, and accessories add a narrow tactical or job modifier. Equipment does not unlock an unrelated second class tree.

Ports sell reliable regional sets; dungeons and captain challenges offer distinctive alternatives. The Workshop crafts discovered recipes and reinforces an item within its regional tier. Item names, base effects, and recipe outputs are authored. Optional affixes come from a small tagged pool with an explicit preview, and crafting offers a deterministic route to required defensive effects. Essential counters cannot depend on a single rare drop.

Salvaging returns displayed materials. Reinforcement does not consume another copy of a unique item and cannot destroy equipment. Normal combat never permanently breaks gear. Equipment favors role specialization; class defines tactical identity, equipment modifies its execution, and pets provide companion or exploration utility.

### 7.7 Formation

The default formation has six active crew slots across three readable lanes: Front, Center, and Rear, with two positions per lane. The Muster Deck provides formation setup from the tutorial. Hull expansion increases the reserve roster and ship workforce without requiring additional battle slots.

Formation affects:

- which enemies can reach a crew member quickly;
- protection and support range;
- skill targeting;
- boarding readiness;
- available high-level tactics.

Formation is intentionally less granular than direct character control. The player should spend time choosing a team and a plan, not dragging every member through a combat arena.

---

## 8. Automatic Boarding Combat

### 8.1 Combat promise

Battles should look active even when the player does nothing. The crew selects targets, moves within the encounter arena, uses skills, and reacts to danger according to its build and current command state. Boarding, island, dungeon, and captain-trial encounters share this combat system, with different arena art, hazards, and objectives.

### 8.2 Battle flow

1. **Readiness:** the game displays both teams, threat tags, environmental modifiers, and the player's current stance.
2. **Automatic engagement:** crew members execute their class behavior and skill priorities.
3. **Optional intervention:** the player may pause and issue a high-level command.
4. **Resolution:** the enemy is defeated, the player retreats, or the active squad suffers a soft failure and returns to the ship or a safe port.
5. **Rewards and recovery:** food, materials, experience, discoveries, and injuries are resolved.

### 8.3 High-level commands

The player may issue these commands while paused:

- **Focus target:** choose an enemy priority target or target group.
- **Skill priority:** select a team-wide preference such as survival, control, damage, or support.
- **Team stance:** Aggressive, Balanced, Defensive, or Escape Ready.
- **Retreat:** end the encounter when escape conditions allow.

Commands are optional. A correctly prepared team must be able to clear ordinary content without constant input.

### 8.4 Ship and boarding interaction

The ship does not run a separate artillery mini-game. Ship facilities influence boarding through:

- boarding readiness;
- crew capacity;
- route access and reinforcement speed;
- defensive barriers;
- recovery and repair;
- food and material reserves.

Ship building and crew building therefore share one combat context instead of creating two independent upgrade games.

### 8.5 Difficulty bands

- **Routine encounter:** tests general preparation and provides normal rewards.
- **Tactical encounter:** has a visible modifier that rewards a particular role or command.
- **Captain trial:** tests a region's core lesson and grants a major unlock.
- **Legend encounter:** optional late-game challenge with unusual restrictions and collection rewards.

### 8.6 Defeat and retreat

Defeat is a soft failure. The player keeps all recruited crew, owned equipment, pets, personal levels, class mastery, discovered recipes, port investments, completed quests, and permanent unlocks. Defeat never deletes a crew member or reverses an evolution. The player loses 25% of unbanked gold and loose materials from the current expedition; already granted experience, quest items, first-discovery records, and unique drops are protected. Consumed food is not refunded. Returning to a port banks the expedition inventory.

Up to two defeated crew members may receive an injury, shown as a temporary 10% reduction to combat attributes. Injuries never stack. An Infirmary treatment or port medical service removes an injury using a displayed supply cost; a recruit can fill in during treatment. Facility damage disables efficiency bonuses until repaired, but never removes a facility, its upgrade level, critical storage, or the ability to return to port.

Retreat remains available when stamina is low or the battle is unwinnable. The player must never be trapped by an empty stamina pool or a failed route.

---

## 9. Pet Eggs and Evolution

### 9.1 Purpose

Pets provide a separate collection and synergy layer. They should not simply duplicate the strongest crew member's damage number.

### 9.2 Egg loop

1. Find an egg or an egg ingredient through exploration, quests, ports, or combat.
2. Place the egg in the Hatchery.
3. Choose food, color materials, and a recipe direction.
4. Incubate and reveal a species or evolution branch.
5. Assign the pet to a crew member, a ship facility, or an exploration role.

Recipes should be discoverable through clues, experimentation, and the Pet Codex. The player may intentionally discover a new result rather than rely on blind trial and error.

### 9.3 Pet roles

- **Battle companion:** modifies a crew member's combat behavior or provides a limited support action.
- **Ship helper:** improves production, recovery, storage, or facility work.
- **Explorer:** reveals route information, detects secrets, or improves discovery rewards.

Each pet has one primary role and optional affinities. A pet that is excellent in one context should not be mandatory in every context.

### 9.4 Evolution

Evolution consumes discovered materials and may require a species, color, or affinity condition. Evolution changes the pet's role options and visual identity. It does not erase the player's discovery record.

### 9.5 Pet readability

Every egg and pet screen must show:

- known recipe inputs;
- discovered and undiscovered outcomes;
- current role;
- evolution requirements;
- assigned owner or facility;
- the practical effect of the pet.

### 9.6 Recipe and assignment defaults

An egg records its family, grade, and up to three ordered feed inputs. Ingredients carry six color tags: Red, Blue, Green, Yellow, Purple, and White. The egg family, grade, and ordered inputs select an authored recipe outcome. This is a new game's deterministic recipe system; it is not a claim about the reference game's formula.

The Codex records attempted inputs, known results, and clue sources. Once an outcome is known, its preview is exact. An undiscovered outcome remains a silhouette with a family or role hint. Confirming a complete recipe hatches the egg immediately using in-game ingredients; no real-time incubation timer is used. Repeating the same recipe always produces the same species, though an independently seeded cosmetic variation may differ.

A pet can occupy one assignment at a time: companion to one active crew member, helper at one reachable facility, or expedition explorer. Companion actions use their owner's combat logic and do not occupy another crew formation slot. Assignments can be changed outside combat; the same pet cannot grant several bonuses simultaneously. Evolution preserves the pet's stable identity, discovered history, and invested growth.

---

## 10. Ports, Investment, and Regional Specialties

### 10.1 Port role

Ports are external support hubs. They do not duplicate the full ship-building system. Their main functions are:

- supplies and repairs;
- recruitment;
- equipment and material purchases;
- regional investment;
- specialty goods;
- local quests and faction relationships;
- route and discovery information.

### 10.2 Investment

Investment is divided into readable service tracks such as:

- market and specialty goods;
- recruitment and tavern quality;
- workshop and repair quality;
- quest board and information;
- route safety and navigation.

Each investment level unlocks a service, a new item family, a new recruit source, a quest branch, or a travel convenience. Investment is not a mandatory maxing exercise for every port.

### 10.3 Regional specialties

Specialties have stable base uses and mild regional price differences. They may be:

- used in ship facilities;
- used in equipment crafting;
- used in pet recipes;
- delivered for quests;
- traded for a controlled profit.

The market is intentionally readable and mostly stable. The player should plan routes around needs and discoveries, not monitor a simulation of global supply and demand.

### 10.4 Port decision

Each port visit should produce at least one clear decision:

- spend now on supplies or invest for future access;
- buy a reliable item or save for a rare material;
- recruit a promising generated crew member or preserve roster space;
- take a safe contract or a more dangerous discovery route.

---

## 11. Resources and Progression

### 11.1 Resource responsibilities

| Resource | Primary uses | Main sources |
|---|---|---|
| Gold | purchases, investment, services, respec | quests, trade, combat, discoveries |
| Materials | ship upgrades, equipment, repairs, pet evolution | islands, dungeons, wrecks, contracts |
| Food | voyage consumption and stamina recovery | ports, galley, combat, production |
| Stamina | pays for optional expedition challenges | food and battle-supply consumables |
| Experience | personal crew level | combat, quests, training facilities |
| Class mastery | class-tree progress and qualifications | using classes, training, class trials |
| Reputation | access to captain trials, factions, and higher port services | regional quests, discoveries, captain victories |
| Regional specialties | targeted crafting, quests, pet recipes, controlled trade | specific ports and regions |

No single resource should replace every other resource. A player should be able to understand why a trip produced a reward and what future decision that reward enables.

### 11.2 Stamina model

Stamina is one ship-wide expedition pool. It represents how much continuous challenge work the active squad can perform. Its only recovery sources are food and battle-supply consumables, including food prepared by the Galley.

- A route consumes food once at departure; it does not also deduct stamina.
- Each optional combat or expedition challenge shows and deducts its stamina cost when the player confirms entry. Defeat does not add a second stamina charge.
- Forced attacks during sailing do not require entry stamina. Retreat, walking cleared paths, and safe return do not require stamina.
- Food and battle supplies recover a displayed amount up to the maximum pool size. Consuming supplies is immediate; surplus recovery is not stored.
- Ports sell food, the Galley converts ingredients into meals, and battles can drop supplementary supplies. Facilities improve storage and conversion efficiency; they never grant passive stamina regeneration.
- Resting, elapsed device time, closing the application, and remaining offline do not refill stamina.
- Empty stamina never blocks ship editing, recruitment, inventory management, treatment, or return to a safe port.

If a route becomes impossible to finish safely, Emergency Return brings the player to the last safe port without requiring food or stamina and uses the same protected-reward and cargo-loss rules as defeat. Every port offers free emergency assistance when the player cannot afford a basic meal, treatment, or essential repair. It supplies only enough non-tradeable recovery provisions and repairs for an accessible recovery contract, with no debt or real-time delay. The contract provides basic gold and food, and cannot generate rare materials. This recovery route remains available after repeated defeats.

The game clock advances when the player departs, confirms treatment or repairs, or completes a production batch. These actions resolve immediately or through an accelerated game-time transition. It does not advance while paused or while editing the ship. There are no real-time production or recovery timers.

### 11.3 Unlock rules

New sea regions use one visible main gate: complete the current region's main story step and win its captain trial. Reputation, discoveries, port investment, and navigation facilities provide alternative preparation options, side content, and better services. They are not additional hidden grind requirements. A region may ask for one named capability, such as a reinforced hull or a survey tool, when that capability is granted by its main quest.

Purely increasing an abstract combat number must never be the only way to unlock a region.

### 11.4 Ship progression

The main ship has four broad hull tiers:

1. **Starter hull:** an open main deck over two interior levels (gun deck and hold), basic quarters, basic storage, and a small crew.
2. **Voyager hull:** adds a quarterdeck and longer interior levels for training, production, and reliable medical support.
3. **Adventurer hull:** adds a forecastle and a third interior level (orlop) for advanced facilities, pet specialization, and longer routes.
4. **Legend hull:** adds a poop deck and the longest interior levels, with room for late-game facilities and access to the final sea trial.

See §6.5 for the exact level list of each hull.

Each hull tier should add a new design problem rather than only increase capacity.

---

## 12. Quests and Content

### 12.1 Quest types

- **Main quest:** advances the campaign and opens a sea region.
- **Captain trial:** tests a region-specific team-building lesson.
- **Port request:** delivers goods, resolves a local problem, or improves a service.
- **Discovery quest:** points toward a hidden island, wreck, or ancient site.
- **Crew event:** reacts to a generated crew member's origin, tag, or personal request.
- **Contract:** repeatable content for gold, materials, food, or reputation.
- **Legend challenge:** optional late-game encounter with a special restriction.

### 12.2 Reward rules

One-time story and discovery rewards should unlock new choices. Repeatable content should primarily provide materials, food, gold, and controlled access to rare drops.

The game should not force the player to repeat a completed story dungeon dozens of times before the next story gate. If a region requires a material, at least two reasonable sources must exist.

### 12.3 Content target

The complete blueprint targets:

- 10 sea regions;
- 80–120 locations;
- 10 regional captain trials;
- 10–15 named rival captains and faction leaders;
- 12–16 base crew classes with branch specializations;
- 50–70 pet species or evolution endpoints;
- approximately 100 authored main and regional quests;
- a repeatable contract set for each region;
- one postgame legend challenge family per late-game region.

These are content targets for planning. Final counts may be tuned without changing the system architecture.

A concrete content budget uses 100 locations: two ports, three islands, two dungeons, one wreck, one captain arena, and one secret site per region. Dungeons and secret sites can use multiple rooms without being counted as additional world locations. A regional arc targets five main quests and five local or discovery quests, producing approximately 100 authored quests. Generated crew requests and repeatable contracts use separate event templates and do not inflate this authored-quest count.

---

## 13. User Interface and Usability

### 13.1 Primary screens

1. **Ship view:** shows decks, facilities, crew movement, warnings, and current production.
2. **World map:** shows regions, discovered routes, location tags, route estimates, and objectives.
3. **Port screen:** shows services, investment tracks, specialty goods, recruitment, and quests.
4. **Crew screen:** shows role, class tree, equipment, pet assignment, mastery, and respec.
5. **Battle screen:** shows team state, target focus, stance, skill priority, pause, and retreat.
6. **Pet Lab:** shows eggs, recipes, clues, evolution paths, and assignments.
7. **Codex:** records locations, enemies, classes, pets, recipes, discoveries, and story clues.

### 13.2 Information hierarchy

The interface must show the reason behind a recommendation or warning. Examples:

- “Food will last for this route, but not for the return trip.”
- “This crew member cannot reach the assigned facility because Deck 2 has no active stair.”
- “This enemy is marked as the current focus target.”
- “Respec retains class mastery and changes the active class path.”

### 13.3 Input

The required input is keyboard and mouse. Every important action has a visible shortcut or mouse control. Controller support is an optional later input layer and is not required for this blueprint's PC acceptance criteria.

### 13.4 Accessibility

The game should provide:

- adjustable text size where layout allows;
- color-independent status icons;
- battle speed controls;
- pause at encounter start as an option;
- readable contrast on map, battle, and facility states;
- no information that is available only through color.

### 13.5 Art and audio direction

The visual direction is colorful 2D pixel art. Ship decks use a readable angled view; the world map emphasizes routes and distinct regional silhouettes. Crew silhouettes, role icons, and health states must remain recognizable during automatic battles. Decorative animation is restrained when many crew members share a screen.

Each region has a distinct palette, environmental tile set, port identity, enemy family, and musical theme. Ship ambience conveys work and community. Battle audio distinguishes major hazards, defeat risk, rewards, and high-level command acknowledgement. All meaningful audio cues have visible equivalents.

Audio implementation in the native build:

- **Music:** travel and port music crossfades with the scene, and battles get their own music. Islands and dungeons rely on ambience alone.
- **Ambience:** seamless beds for the open sea (wind in the rigging), the harbour, the coast and caves.
- **Effects:** short effects for UI confirm and cancel, placement, demolition, repair, level switching, trade, combat hits and blocks, skills, knockouts and the boarding ram.
- **Stingers:** victory and defeat stingers that briefly duck the music.
- **Repetition control:** each effect has a cooldown, a voice cap and pitch variation so repeats stay restrained.
- **Volume:** players set Master, Music, Ambience and Effects volume separately.
- **Visible feedback:** every cue has a visual equivalent, such as a toast, a floating number, a burst or a log entry.
- **Licensing:** all third-party audio is CC0, with each file's licence checked. Sources and licences are listed in `docs/AUDIO_LICENSES.md`, and the licence texts ship with the build.

Player-facing text is rendered by the localization system with fonts covering both English and Simplified Chinese. Quest names, skill descriptions, and button labels are not baked into pixel-art textures. Pixel styling must not make long Chinese descriptions unreadable.

---

## 14. Localization and Language Support

### 14.1 Launch languages

The game supports:

- English (`en`);
- Simplified Chinese (`zh-CN`).

The language is selected at startup. Changing the language requires restarting the game so that fonts, generated names, and layout measurements are rebuilt consistently. Saves are shared between languages.

### 14.2 Text architecture

All player-facing text uses stable string keys. Game logic stores keys and parameters rather than hardcoded display strings.

Required string categories include:

- UI labels and tooltips;
- quests and dialogue;
- crew origins and personality tags;
- class names and skill descriptions;
- item, facility, pet, and location names;
- warnings and accessibility text;
- tutorial and codex entries.

### 14.3 Translation rules

- English is the authoring language for the GDD and content identifiers.
- Simplified Chinese is a full launch translation, not a partial machine-translated fallback.
- Numbers, units, placeholders, and control names use explicit formatting tokens.
- Text expansion is tested in both languages, especially on buttons, tooltips, and battle commands.
- Generated crew names use locale-specific name pools and preserve the same gameplay identity. A stable identity seed selects localized default names; a player-entered nickname is stored as literal text and is never translated or regenerated.
- The same save data must load correctly regardless of the selected language.

---

## 15. Save, Offline, and Recovery

### 15.1 Save model

The game uses local saves with:

- one active captain profile;
- multiple manual save slots;
- automatic safe-point saves;
- a recovery save before a major captain trial;
- locale-independent progression data.

### 15.2 Safe points

Automatic saves occur after:

- arriving at a port;
- settling any combat, expedition, discovery, contract, or quest reward;
- finishing a captain trial;
- applying a ship layout;
- confirming recruitment, crafting, investment, a respec, hatching, or evolution;
- resolving a failed expedition.

Permanent state changes and their costs are written in one transaction before the reward or confirmation screen appears. Loading cannot grant a reward twice, spend an input twice, or restore only one half of an evolution. The game retains three rotating recovery saves and replaces a save atomically. If writing fails, it reports the failure and does not claim the transaction was saved.

Mid-route or mid-encounter suspension stores the current state and random-generator state. It resumes the same encounter without rerolling recruits, loot, or egg outcomes. Manual saves are available outside unresolved reward transactions. Previously written manual slots remain available for deliberate player reloads.

### 15.3 Offline behavior

All campaign, battle, resource, and localization systems work without a server. The game never checks device time to restore stamina and never requires the player to remain online.

---

## 16. Balance Principles

1. The strongest build is not the only viable build.
2. Every region teaches a new decision before it asks for mastery of that decision.
3. Automatic combat must be reliable for ordinary content and imperfect for challenge content.
4. High-level commands should change outcomes without becoming mandatory button mashing.
5. Respec supports experimentation but does not remove all cost from planning.
6. A failed expedition should teach the player what to change next time.
7. Repetition provides useful materials but never becomes the only path to story progress.
8. Port investment should open options, not require every port to be fully upgraded.
9. Pets, equipment, classes, and ship facilities must each create different kinds of decisions.
10. A long campaign must remain readable: the player can always identify the next objective, the reason it is locked, and at least one practical route toward it.

---

## 17. Acceptance Scenarios

### Scenario A: First expedition

The player recruits a generated crew, builds a basic ship layout, buys food, selects the first island, watches the ship sail, and completes an automatic battle. The player understands the result without issuing a command.

### Scenario B: Tactical intervention

An enemy captain begins defeating the player's frontline. The player pauses, marks the captain as the focus target, changes the stance to Defensive, and resumes. The result changes because of the command, but the player does not control individual movement.

### Scenario C: Ship layout problem

The player moves the only stair or hatch ladder connecting two levels. The game highlights affected facilities, explains that workers cannot reach them, and allows the player to correct the layout before departure. Separately, the player tries to place a galley on the open weather deck; the preview refuses it and names the interior levels where it fits.

### Scenario D: Respec

A crew member changes from a Vanguard branch to a Guardian branch. Their personal level and class mastery remain. The active skill set changes and the player pays the displayed in-game cost.

### Scenario E: Empty stamina

The expedition pool reaches zero. The player can consume food or battle supplies to recover, or retreat and return safely. If both food and gold are empty, the last safe port still provides emergency resupply and essential treatment. Waiting, resting, or restarting the application does not refill stamina. No real-time timer or purchase prompt is required.

### Scenario F: Language selection

The player starts in English, saves after a captain trial, restarts in Simplified Chinese, and sees the same ship, crew, quests, and discoveries with translated text and locale-appropriate generated names.

### Scenario G: Campaign completion

The player defeats the final captain, receives the strongest captain title, and continues from the same save to explore unresolved locations, complete the codex, evolve pets, and attempt legend challenges.

---

## 18. Source References

- [Kairosoft official product page](https://kairosoft.net/game/appli/pirate.html)
- [Kairosoft Android product list](https://kairopark.jp/android/en/?from=m100dx)
- [High Sea Saga App Store listing](https://apps.apple.com/us/app/high-sea-saga/id1084639614)
- [High Sea Saga DX App Store listing](https://apps.apple.com/us/app/high-sea-saga-dx/id6477660875)
- [High Sea Saga DX on Steam](https://store.steampowered.com/app/2431880/High_Sea_Saga_DX/)
- [DX customer review feed](https://itunes.apple.com/us/rss/customerreviews/id=6477660875/sortBy=mostRecent/json)
- [Original customer review feed](https://itunes.apple.com/us/rss/customerreviews/id=1084639614/sortBy=mostRecent/json)
- [Community pet calculator reference](https://github.com/DreamNya/HighSeaSaga-PetCalculator)

The official pages support the reference baseline. The community tool and customer reviews are used only as supplemental evidence for player expectations and possible friction points; they do not define Project Seven Seas mechanics.

---

## 19. Content and State Contracts

The following contracts describe the minimum information that content and save systems must preserve. Field names are English identifiers; display names are localized through string keys.

### 19.1 Content records

- **SeaRegion:** `id`, `theme`, `mainQuestId`, `captainTrialId`, `locationIds`, `specialtyId`, `petFamilyId`, `recommendedCapabilityTags`.
- **Location:** `id`, `regionId`, `type`, `revealConditions`, `routeRequirements`, `challengeIds`, `rewardFamilies`, `firstVisitRewardId`, `repeatableContractIds`.
- **Port:** `id`, `regionId`, `investmentTracks`, `serviceLevels`, `recruitPoolId`, `specialtyGoods`, `questBoardId`, `safeReturnId`.
- **CrewTemplate:** `originId`, `personalityTags`, `baseClassId`, `aptitudeTags`, `equipmentTags`, `petAffinityTags`, `eventTemplateIds`.
- **ClassDefinition:** `id`, `roleTags`, `activeSkills`, `passiveSkills`, `masteryTrack`, `branchIds`, `equipmentRules`, `petRules`.
- **FacilityDefinition:** `id`, `footprint`, `category`, `upgradeLevels`, `workAccessRules`, `jobSlots`, `recipeIds`, `effectTags`, `constructionCost`.
- **ItemDefinition:** `id`, `itemType`, `regionTier`, `equipmentSlot`, `effects`, `recipeId`, `specialtyOriginId`, `tradeRules`.
- **PetDefinition:** `id`, `role`, `recipeInputs`, `evolutionOptions`, `affinityTags`, `visualVariantIds`, `abilityTextKey`.
- **Quest:** `id`, `questType`, `prerequisites`, `steps`, `failureResolution`, `firstCompletionRewards`, `repeatRewardFamily`.
- **Encounter:** `id`, `arenaType`, `enemyGroup`, `modifiers`, `staminaCost`, `retreatRules`, `rewardTable`.
- **CaptainTrial:** `id`, `regionId`, `arenaLocationId`, `mainQuestPrerequisite`, `encounterId`, `firstClearRewards`, `nextRegionId`.

All records with displayable content reference `nameKey`, `descriptionKey`, and any additional text keys; presentation text is never an object identifier.

### 19.2 Persistent state

- **CaptainState:** current region, main quest progress, captain-trial progress, reputation, discoveries, codex state, and postgame flag.
- **WorldState:** each location's knowledge state, charted routes, completed first rewards, revealed clues, and local quest flags.
- **ShipState:** hull tier, deck layouts, facility levels, facility placements, storage, food, current stamina, maximum stamina, ship damage, and unlocked presets.
- **CrewState:** stable generated ID, identity seed, level, current class, class mastery, legacy passive skills, equipment IDs, pet assignment, job assignment, and injury state.
- **PetState:** stable ID, species, evolution state, recipe discovery, ability state, assignment, and cosmetic variant.
- **InventoryState:** banked gold, food, battle supplies, materials, specialties, equipment, eggs, recipes, unique item ownership, and a separate current-expedition ledger for unbanked gold and loose materials.
- **LocalePreference:** startup locale selection in local settings. It can open any captain save and never changes gameplay values.
- **SaveEnvelope:** schema version, content version, captain profile ID, last committed transaction ID, game clock, random-generator state, and recovery-save generation.

### 19.3 Invariants

1. Generated crew and pets keep stable IDs across saves, respecs, and language changes.
2. A reward transaction is applied once or not at all; it cannot be partially applied.
3. A first-discovery record is permanent once committed.
4. A failed expedition cannot delete permanent crew growth, equipment ownership, pet evolution, class mastery, port investment, or completed quest progress.
5. Localization keys can change display text but cannot change prerequisites, costs, effects, or reward quantities.
6. A location's `Revealed`, `Visited`, and `Cleared` states are distinct and never inferred from a fast-travel flag.
7. Current stamina and the current-expedition ledger are persisted with a suspension or recovery save; loading cannot refill stamina or convert unbanked rewards into banked inventory.

### 19.4 Reward transaction

Every reward screen is backed by a transaction containing an encounter or quest ID, a unique attempt ID, consumed inputs, generated rewards, permanent discoveries, and the resulting state hash. The transaction is committed before the screen appears. Reloading the same attempt ID returns the already committed result rather than rolling a new result.

---

## 20. Design Defaults and Playtest Parameters

The product decisions in this document are fixed for the blueprint. The following values are implementation defaults that must be tested and adjusted without changing the product promise:

- six active battle slots across Front, Center, and Rear;
- twelve base classes with two branches each;
- four broad hull tiers;
- ten regions with 8–12 locations per region;
- a 25% loss of unbanked expedition gold and loose materials on defeat;
- up to two simultaneous injuries per failed encounter;
- 10% temporary injury reduction until treatment;
- two legacy passive skills from mastered classes;
- one ship-wide stamina pool;
- one food charge at route departure and explicit stamina costs at optional challenges;
- three rotating recovery saves plus manual slots;
- a 30-minute first-session test and a ten-region campaign completion test.

Playtesting must tune costs, encounter duration, drop rates, route lengths, facility coverage, class coefficients, and text length. Tuning must not introduce real-time waiting, hidden unlock gates, permanent character deletion, duplicate stamina pools, or a second direct-control combat layer.
