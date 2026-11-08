/*
 * Project Seven Seas — system content: classes, skills, passives, facilities,
 * hulls, items, pets, enemy archetypes, and tuning (GDD §6, §7, §9, §19.1, §20).
 * Content records use English identifiers only; display text is resolved by
 * localization keys derived from these IDs.
 */
(function (root) {
  'use strict';

  const CONTENT_VERSION = '1.0.0';

  const ROLES = ['vanguard', 'striker', 'controller', 'support', 'scout'];
  const FORMATION_LANES = ['front', 'center', 'rear'];
  const COLOR_TAGS = ['red', 'blue', 'green', 'yellow', 'purple', 'white'];
  const LOCATION_TYPES = ['port', 'island', 'dungeon', 'wreck', 'arena', 'secret'];
  const KNOWLEDGE_STATES = ['hidden', 'revealed', 'visited', 'cleared'];
  const INVESTMENT_TRACKS = ['market', 'tavern', 'workshop', 'quest_board', 'navigation'];
  const FACILITY_CATEGORIES = ['command', 'living', 'training', 'medical', 'production', 'navigation', 'storage', 'pet', 'social', 'defense'];
  const STANCES = ['aggressive', 'balanced', 'defensive', 'escape'];
  const PRIORITIES = ['auto', 'survival', 'control', 'damage', 'support'];
  const SKILL_CATS = ['damage', 'control', 'support', 'survival'];
  const ORIGINS = ['dawnwater_fishers', 'ember_forges', 'verdant_villages', 'glass_reefs', 'crown_courts', 'storm_harbors', 'moon_isles', 'trench_divers', 'ring_nomads', 'horizon_wanderers'];
  const TRAITS = ['brave', 'cautious', 'cheerful', 'stubborn', 'curious', 'loyal', 'thrifty', 'calm', 'reckless', 'kind', 'proud', 'sleepy'];
  const CREW_EVENTS = ['homesick', 'proving', 'feast', 'collector'];
  // Recruit aptitude tags improve learning or job efficiency; they never
  // exclude a recruit from a class (GDD §7.4).
  const APTITUDES = {
    quick_learner: { xpPct: 0.2 }, devoted: { masteryPct: 0.25 }, deckhand: { jobPct: 0.5 }, brawny: { hpPct: 0.08 },
    sharp: { atkPct: 0.06 }, nimble: { spd: 2 }, tough: { defPct: 0.08 }, beast_friend: { petPct: 0.2 }
  };
  const FACTIONS = ['conclave', 'league', 'tidebound', 'pennants'];

  // ------------------------------------------------------------------ skills
  // scope: enemy | enemy_lane | enemies | ally | allies | front_allies | self
  // power = damage multiplier, heal = heal multiplier. fx holds effects (seconds).
  const SKILLS = {
    shield_bash:       { cat: 'control',  cd: 8,  scope: 'enemy',        power: 0.8, fx: { stun: 1.5 } },
    hold_the_line:     { cat: 'survival', cd: 12, scope: 'self',         fx: { taunt: 4, shield: 0.2 } },
    guardian_wall:     { cat: 'survival', cd: 14, scope: 'front_allies', fx: { shield: 0.12 } },
    quake_slam:        { cat: 'control',  cd: 10, scope: 'enemy_lane',   power: 1.0, fx: { slow: 3 } },
    lunge:             { cat: 'damage',   cd: 6,  scope: 'enemy',        power: 1.6 },
    riposte:           { cat: 'survival', cd: 12, scope: 'self',         fx: { evade: 4 } },
    whirling_blades:   { cat: 'damage',   cd: 9,  scope: 'enemy_lane',   power: 1.15 },
    call_out:          { cat: 'damage',   cd: 10, scope: 'enemy',        power: 1.9, fx: { boss: 0.5, mark: 3 } },
    piercing_thrust:   { cat: 'damage',   cd: 7,  scope: 'enemy',        power: 1.4, fx: { pierce: 0.3, reachAll: true } },
    sweep_spear:       { cat: 'control',  cd: 9,  scope: 'enemy_lane',   power: 0.8, fx: { slow: 3 } },
    harpoon_pull:      { cat: 'control',  cd: 10, scope: 'enemy',        power: 1.2, fx: { stun: 1, mark: 4, reachAll: true } },
    sky_dive:          { cat: 'damage',   cd: 12, scope: 'enemy',        power: 2.3, fx: { reachAll: true } },
    aimed_shot:        { cat: 'damage',   cd: 7,  scope: 'enemy',        power: 1.7, fx: { snipe: true } },
    smoke_shell:       { cat: 'control',  cd: 12, scope: 'enemies',      power: 0.35, fx: { slow: 3 } },
    headshot:          { cat: 'damage',   cd: 12, scope: 'enemy',        power: 2.3, fx: { execute: 1.0, snipe: true } },
    scatter_volley:    { cat: 'damage',   cd: 10, scope: 'enemies',      power: 0.75 },
    haymaker:          { cat: 'control',  cd: 9,  scope: 'enemy',        power: 1.2, fx: { stun: 1.5 } },
    brawl:             { cat: 'damage',   cd: 8,  scope: 'enemy_lane',   power: 1.0 },
    armor_crush:       { cat: 'control',  cd: 10, scope: 'enemy',        power: 1.3, fx: { sunder: 6 } },
    suplex:            { cat: 'control',  cd: 13, scope: 'enemy',        power: 1.5, fx: { stun: 2.5 } },
    first_aid:         { cat: 'support',  cd: 6,  scope: 'ally',         heal: 1.8 },
    cleanse:           { cat: 'support',  cd: 10, scope: 'allies',       heal: 0.5, fx: { cleanse: true } },
    emergency_surgery: { cat: 'survival', cd: 14, scope: 'ally',         heal: 3.6, cond: 'critical' },
    renewal:           { cat: 'support',  cd: 14, scope: 'allies',       heal: 0.9, fx: { regen: 0.02, regenDur: 5 } },
    hearty_snack:      { cat: 'support',  cd: 8,  scope: 'ally',         heal: 1.2, fx: { buffAtk: 0.1, buffDur: 5 } },
    spice_bomb:        { cat: 'control',  cd: 11, scope: 'enemies',      power: 0.5, fx: { slow: 2 } },
    supply_drop:       { cat: 'survival', cd: 14, scope: 'allies',       fx: { buffDef: 0.2, buffDur: 6 } },
    grand_feast:       { cat: 'support',  cd: 16, scope: 'allies',       heal: 0.6, fx: { buffAtk: 0.25, buffDur: 6 } },
    mark_target:       { cat: 'control',  cd: 8,  scope: 'enemy',        power: 0.6, fx: { mark: 5, snipe: true } },
    quick_read:        { cat: 'support',  cd: 14, scope: 'allies',       fx: { meter: 35 } },
    shortcut_strike:   { cat: 'damage',   cd: 8,  scope: 'enemy',        power: 1.6, fx: { reachAll: true, snipe: true } },
    ebb_tide:          { cat: 'control',  cd: 12, scope: 'enemies',      power: 0.45, fx: { slow: 4 } },
    deploy_barrier:    { cat: 'survival', cd: 10, scope: 'ally',         fx: { shield: 0.25 } },
    spring_trap:       { cat: 'control',  cd: 10, scope: 'self',         fx: { trap: 1.5, trapStun: 1.5 } },
    turret:            { cat: 'damage',   cd: 15, scope: 'enemies',      fx: { dot: 0.35, dotDur: 5 } },
    snare_net:         { cat: 'control',  cd: 16, scope: 'enemies',      power: 0.3, fx: { stun: 1.2 } },
    sic_em:            { cat: 'damage',   cd: 7,  scope: 'enemy',        power: 1.2, fx: { pet: 1.6 } },
    soothing_call:     { cat: 'support',  cd: 10, scope: 'ally',         heal: 1.2 },
    pack_guard:        { cat: 'survival', cd: 13, scope: 'front_allies', fx: { shield: 0.1 } },
    call_of_wild:      { cat: 'control',  cd: 12, scope: 'enemies',      power: 0.9, fx: { slow: 2 } },
    frost_bolt:        { cat: 'control',  cd: 7,  scope: 'enemy',        power: 1.3, fx: { slow: 3, reachAll: true } },
    arc_burst:         { cat: 'damage',   cd: 10, scope: 'enemies',      power: 0.8 },
    chain_lightning:   { cat: 'damage',   cd: 13, scope: 'enemies',      power: 1.25, fx: { stun: 0.8 } },
    dispel_hex:        { cat: 'control',  cd: 12, scope: 'enemies',      power: 0.6, fx: { dispel: true, cleanseAllies: true } },
    rally_banner:      { cat: 'support',  cd: 14, scope: 'allies',       fx: { buffAtk: 0.2, buffDur: 6 } },
    brace:             { cat: 'survival', cd: 14, scope: 'allies',       fx: { buffDef: 0.2, buffDur: 5 } },
    tribute:           { cat: 'damage',   cd: 9,  scope: 'enemy',        power: 1.3, fx: { plunder: 1 } },
    hold_colors:       { cat: 'survival', cd: 16, scope: 'allies',       fx: { buffDef: 0.3, buffDur: 6, cleanse: true } },
    // enemy skills
    e_slash:           { cat: 'damage',   cd: 6,  scope: 'enemy',        power: 1.3 },
    e_crush:           { cat: 'control',  cd: 10, scope: 'enemy',        power: 1.5, fx: { stun: 1 } },
    e_volley:          { cat: 'damage',   cd: 9,  scope: 'enemies',      power: 0.55 },
    e_hex:             { cat: 'control',  cd: 9,  scope: 'enemy',        power: 0.9, fx: { slow: 3, mark: 3, reachAll: true } },
    e_mend:            { cat: 'support',  cd: 8,  scope: 'ally',         heal: 1.6 },
    e_roar:            { cat: 'support',  cd: 15, scope: 'allies',       fx: { buffAtk: 0.2, buffDur: 6 } },
    e_charge:          { cat: 'damage',   cd: 11, scope: 'enemy',        power: 3.2, fx: { windup: 2.5 } },
    e_shell:           { cat: 'survival', cd: 9,  scope: 'self',         fx: { shield: 0.22 } },
    e_stun_all:        { cat: 'control',  cd: 13, scope: 'enemies',      power: 0.4, fx: { stun: 1 } }
  };

  // ---------------------------------------------------------------- passives
  const PASSIVES = {
    steadfast: { defPct: 0.10, intercept: 0.15 },       sentinel: { intercept: 0.35, hpPct: 0.08 },     iron_hide: { thorns: 0.2, defPct: 0.10 },
    keen_edge: { crit: 0.15 },                            flowing_step: { spd: 3, dodge: 0.08 },          giant_slayer: { bossDmg: 0.25 },
    armor_breaker: { defIgnore: 0.15 },                   tidebreaker: { markedDmg: 0.2 },                momentum: { spd: 2, crit: 0.08 },
    steady_aim: { atkPct: 0.10 },                         eagle_eye: { crit: 0.2 },                       quick_reload: { cdr: 0.15 },
    thick_skin: { hpPct: 0.12 },                          shatter: { defIgnore: 0.2 },                    iron_grip: { controlPct: 0.25 },
    bedside_manner: { healPct: 0.15 },                    precise_hands: { healPct: 0.25 },               life_ward: { auraRegen: 0.006 },
    thrifty_kitchen: { foodSave: 1 },                     ration_master: { supplyPct: 0.25, foodSave: 1 }, comfort_food: { hpPct: 0.08, healPct: 0.10 },
    weather_eye: { xpPct: 0.10, avoid: 0.10 },            trailblazer: { lootPct: 0.2 },                  foresight: { auraDodge: 0.06 },
    handy: { jobPct: 0.25 },                              reinforced_plating: { teamShield: 0.08 },       hidden_blades: { thorns: 0.15, crit: 0.05 },
    beast_bond: { petPct: 0.3 },                          alpha_bond: { petPct: 0.5, hpPct: 0.05 },       wild_heart: { petPct: 0.3, atkPct: 0.08 },
    attunement: { atkPct: 0.12 },                         static_field: { crit: 0.1, atkPct: 0.06 },      warding: { hazardResist: 1, defPct: 0.08 },
    ledger_keeper: { goldPct: 0.15 },                     deep_pockets: { goldPct: 0.3, lootPct: 0.1 },   inspiring_presence: { auraAtk: 0.05 }
  };

  // ----------------------------------------------------------------- classes
  // Twelve base classes, two branches each (GDD §7.3, §7.5). Stat growth is
  // proportional to base values (see TUNING.growth).
  const BASE_CLASSES = {
    guard:         { roles: ['vanguard'],               lane: 'front',  range: 'melee',  base: { hp: 150, atk: 11, def: 15, spd: 8 },  weapons: ['shield', 'blade'], skills: ['shield_bash', 'hold_the_line'], passive: 'steadfast',       jobs: ['boarding_gate', 'guard_post', 'barricade_room'], branches: ['guardian', 'bulwark'] },
    duelist:       { roles: ['striker'],                lane: 'front',  range: 'melee',  base: { hp: 110, atk: 18, def: 8,  spd: 13 }, weapons: ['blade'],           skills: ['lunge', 'riposte'],            passive: 'keen_edge',       jobs: ['practice_deck'],                                 branches: ['blade_dancer', 'challenger'] },
    spearfighter:  { roles: ['striker', 'controller'],  lane: 'center', range: 'reach',  base: { hp: 120, atk: 15, def: 10, spd: 10 }, weapons: ['spear'],           skills: ['piercing_thrust', 'sweep_spear'], passive: 'armor_breaker', jobs: ['material_bench', 'guard_post'],                    branches: ['harpooner', 'dragoon'] },
    gunner:        { roles: ['striker'],                lane: 'rear',   range: 'ranged', base: { hp: 92,  atk: 16, def: 7,  spd: 11 }, weapons: ['gun'],             skills: ['aimed_shot', 'smoke_shell'],    passive: 'steady_aim',      jobs: ['lookout'],                                       branches: ['sharpshooter', 'skirmisher'] },
    brawler:       { roles: ['controller', 'vanguard'], lane: 'front',  range: 'melee',  base: { hp: 135, atk: 14, def: 11, spd: 10 }, weapons: ['fist'],            skills: ['haymaker', 'brawl'],            passive: 'thick_skin',      jobs: ['material_bench', 'practice_deck'],               branches: ['breaker', 'grappler'] },
    medic:         { roles: ['support'],                lane: 'rear',   range: 'ranged', base: { hp: 96,  atk: 10, def: 9,  spd: 11 }, weapons: ['kit'],             skills: ['first_aid', 'cleanse'],         passive: 'bedside_manner',  jobs: ['infirmary', 'recovery_room'],                    branches: ['surgeon', 'lifekeeper'] },
    cook:          { roles: ['support'],                lane: 'center', range: 'melee',  base: { hp: 115, atk: 11, def: 10, spd: 9 },  weapons: ['ladle', 'blade'],  skills: ['hearty_snack', 'spice_bomb'],   passive: 'thrifty_kitchen', jobs: ['galley', 'mess_hall'],                           branches: ['provisioner', 'feastmaster'] },
    navigator:     { roles: ['scout', 'controller'],    lane: 'center', range: 'ranged', base: { hp: 98,  atk: 12, def: 8,  spd: 14 }, weapons: ['gun', 'blade'],    skills: ['mark_target', 'quick_read'],    passive: 'weather_eye',     jobs: ['chart_table', 'compass_room', 'lookout'],        branches: ['pathfinder', 'tide_reader'] },
    tinkerer:      { roles: ['support', 'controller'],  lane: 'center', range: 'ranged', base: { hp: 104, atk: 12, def: 10, spd: 9 },  weapons: ['tool', 'gun'],     skills: ['deploy_barrier', 'spring_trap'], passive: 'handy',          jobs: ['workshop', 'material_bench'],                    branches: ['engineer', 'trapper'] },
    beastkeeper:   { roles: ['support', 'striker'],     lane: 'center', range: 'reach',  base: { hp: 108, atk: 13, def: 9,  spd: 11 }, weapons: ['whip', 'spear'],   skills: ['sic_em', 'soothing_call'],      passive: 'beast_bond',      jobs: ['hatchery', 'pet_lab', 'creature_pens'],          branches: ['beastwarden', 'wildspeaker'] },
    mystic:        { roles: ['controller'],             lane: 'rear',   range: 'ranged', base: { hp: 88,  atk: 17, def: 7,  spd: 10 }, weapons: ['staff'],           skills: ['frost_bolt', 'arc_burst'],      passive: 'attunement',      jobs: ['tide_archive', 'class_hall'],                    branches: ['stormcaller', 'hexbreaker'] },
    quartermaster: { roles: ['support', 'vanguard'],    lane: 'center', range: 'melee',  base: { hp: 125, atk: 12, def: 12, spd: 9 },  weapons: ['banner', 'blade'], skills: ['rally_banner', 'brace'],        passive: 'ledger_keeper',   jobs: ['tavern_corner', 'mess_hall', 'cargo_hold'],      branches: ['purser', 'standard_bearer'] }
  };
  const BRANCHES = {
    guardian:        { parent: 'guard',         skill: 'guardian_wall',     passive: 'sentinel',           mult: { hp: 1.18, atk: 1.05, def: 1.18, spd: 1.0 } },
    bulwark:         { parent: 'guard',         skill: 'quake_slam',        passive: 'iron_hide',          mult: { hp: 1.12, atk: 1.12, def: 1.12, spd: 1.05 }, roles: ['vanguard', 'controller'] },
    blade_dancer:    { parent: 'duelist',       skill: 'whirling_blades',   passive: 'flowing_step',       mult: { hp: 1.08, atk: 1.15, def: 1.05, spd: 1.12 } },
    challenger:      { parent: 'duelist',       skill: 'call_out',          passive: 'giant_slayer',       mult: { hp: 1.12, atk: 1.18, def: 1.08, spd: 1.0 } },
    harpooner:       { parent: 'spearfighter',  skill: 'harpoon_pull',      passive: 'tidebreaker',        mult: { hp: 1.1, atk: 1.12, def: 1.1, spd: 1.05 } },
    dragoon:         { parent: 'spearfighter',  skill: 'sky_dive',          passive: 'momentum',           mult: { hp: 1.08, atk: 1.2, def: 1.05, spd: 1.08 }, roles: ['striker'] },
    sharpshooter:    { parent: 'gunner',        skill: 'headshot',          passive: 'eagle_eye',          mult: { hp: 1.05, atk: 1.2, def: 1.05, spd: 1.05 } },
    skirmisher:      { parent: 'gunner',        skill: 'scatter_volley',    passive: 'quick_reload',       mult: { hp: 1.1, atk: 1.12, def: 1.08, spd: 1.12 }, roles: ['striker', 'controller'] },
    breaker:         { parent: 'brawler',       skill: 'armor_crush',       passive: 'shatter',            mult: { hp: 1.1, atk: 1.15, def: 1.1, spd: 1.05 } },
    grappler:        { parent: 'brawler',       skill: 'suplex',            passive: 'iron_grip',          mult: { hp: 1.15, atk: 1.1, def: 1.12, spd: 1.0 } },
    surgeon:         { parent: 'medic',         skill: 'emergency_surgery', passive: 'precise_hands',      mult: { hp: 1.1, atk: 1.15, def: 1.1, spd: 1.05 } },
    lifekeeper:      { parent: 'medic',         skill: 'renewal',           passive: 'life_ward',          mult: { hp: 1.12, atk: 1.12, def: 1.12, spd: 1.0 } },
    provisioner:     { parent: 'cook',          skill: 'supply_drop',       passive: 'ration_master',      mult: { hp: 1.12, atk: 1.08, def: 1.12, spd: 1.05 }, roles: ['support', 'vanguard'] },
    feastmaster:     { parent: 'cook',          skill: 'grand_feast',       passive: 'comfort_food',       mult: { hp: 1.15, atk: 1.12, def: 1.08, spd: 1.0 } },
    pathfinder:      { parent: 'navigator',     skill: 'shortcut_strike',   passive: 'trailblazer',        mult: { hp: 1.08, atk: 1.18, def: 1.05, spd: 1.1 }, roles: ['scout', 'striker'] },
    tide_reader:     { parent: 'navigator',     skill: 'ebb_tide',          passive: 'foresight',          mult: { hp: 1.1, atk: 1.12, def: 1.1, spd: 1.08 } },
    engineer:        { parent: 'tinkerer',      skill: 'turret',            passive: 'reinforced_plating', mult: { hp: 1.1, atk: 1.15, def: 1.12, spd: 1.0 } },
    trapper:         { parent: 'tinkerer',      skill: 'snare_net',         passive: 'hidden_blades',      mult: { hp: 1.08, atk: 1.15, def: 1.08, spd: 1.1 }, roles: ['controller'] },
    beastwarden:     { parent: 'beastkeeper',   skill: 'pack_guard',        passive: 'alpha_bond',         mult: { hp: 1.15, atk: 1.08, def: 1.15, spd: 1.0 }, roles: ['support', 'vanguard'] },
    wildspeaker:     { parent: 'beastkeeper',   skill: 'call_of_wild',      passive: 'wild_heart',         mult: { hp: 1.08, atk: 1.18, def: 1.05, spd: 1.08 }, roles: ['striker', 'controller'] },
    stormcaller:     { parent: 'mystic',        skill: 'chain_lightning',   passive: 'static_field',       mult: { hp: 1.06, atk: 1.2, def: 1.05, spd: 1.06 }, roles: ['controller', 'striker'] },
    hexbreaker:      { parent: 'mystic',        skill: 'dispel_hex',        passive: 'warding',            mult: { hp: 1.12, atk: 1.1, def: 1.15, spd: 1.04 }, roles: ['controller', 'support'] },
    purser:          { parent: 'quartermaster', skill: 'tribute',           passive: 'deep_pockets',       mult: { hp: 1.1, atk: 1.15, def: 1.08, spd: 1.06 }, roles: ['support', 'striker'] },
    standard_bearer: { parent: 'quartermaster', skill: 'hold_colors',       passive: 'inspiring_presence', mult: { hp: 1.15, atk: 1.08, def: 1.15, spd: 1.0 } }
  };

  // Flatten into one class table (ClassDefinition, GDD §19.1).
  const CLASSES = {};
  for (const [id, c] of Object.entries(BASE_CLASSES)) {
    CLASSES[id] = Object.assign({ id, tier: 'base', parent: null, mult: { hp: 1, atk: 1, def: 1, spd: 1 } }, c);
  }
  for (const [id, b] of Object.entries(BRANCHES)) {
    const p = BASE_CLASSES[b.parent];
    CLASSES[id] = {
      id, tier: 'branch', parent: b.parent, roles: b.roles || p.roles, lane: p.lane, range: p.range, base: p.base,
      weapons: p.weapons, skills: [p.skills[0], b.skill], passive: b.passive, jobs: p.jobs, branches: [], mult: b.mult
    };
  }
  const BASE_CLASS_IDS = Object.keys(BASE_CLASSES);

  // -------------------------------------------------------------- facilities
  // minTier = minimum hull tier. jobs = job slots. specialty = [id, count].
  const FACILITIES = {
    captains_cabin: { category: 'command',    w: 2, h: 2, required: true,  minTier: 1, jobs: 0, cost: { gold: 0,   materials: 0 } },
    chart_table:    { category: 'command',    w: 1, h: 1, minTier: 1, jobs: 1, cost: { gold: 80,  materials: 10 } },
    muster_deck:    { category: 'command',    w: 2, h: 2, minTier: 1, jobs: 0, cost: { gold: 60,  materials: 10 } },
    crew_quarters:  { category: 'living',     w: 2, h: 2, required: true,  minTier: 1, jobs: 0, cost: { gold: 80,  materials: 12 } },
    mess_hall:      { category: 'living',     w: 2, h: 2, minTier: 2, jobs: 1, cost: { gold: 140, materials: 20 } },
    practice_deck:  { category: 'training',   w: 3, h: 2, minTier: 2, jobs: 2, cost: { gold: 160, materials: 25 } },
    class_hall:     { category: 'training',   w: 2, h: 2, minTier: 2, jobs: 1, cost: { gold: 220, materials: 30, specialty: ['crown_silk', 2] } },
    infirmary:      { category: 'medical',    w: 2, h: 2, minTier: 1, jobs: 1, cost: { gold: 150, materials: 20 } },
    recovery_room:  { category: 'medical',    w: 2, h: 1, minTier: 3, jobs: 1, cost: { gold: 200, materials: 25, specialty: ['verdant_resin', 2] } },
    galley:         { category: 'production', w: 2, h: 1, minTier: 1, jobs: 1, cost: { gold: 100, materials: 15 } },
    workshop:       { category: 'production', w: 2, h: 2, minTier: 2, jobs: 1, cost: { gold: 180, materials: 30, specialty: ['ember_ore', 2] } },
    material_bench: { category: 'production', w: 2, h: 1, minTier: 2, jobs: 1, cost: { gold: 120, materials: 20 } },
    lookout:        { category: 'navigation', w: 1, h: 1, minTier: 1, jobs: 1, cost: { gold: 90,  materials: 12 } },
    compass_room:   { category: 'navigation', w: 2, h: 1, minTier: 3, jobs: 1, cost: { gold: 220, materials: 30, specialty: ['prism_quartz', 2] } },
    tide_archive:   { category: 'navigation', w: 2, h: 2, minTier: 3, jobs: 1, cost: { gold: 260, materials: 35, specialty: ['moon_ink', 2] } },
    pantry:         { category: 'storage',    w: 2, h: 1, required: true,  minTier: 1, jobs: 0, cost: { gold: 50,  materials: 8 } },
    cargo_hold:     { category: 'storage',    w: 2, h: 2, minTier: 2, jobs: 0, cost: { gold: 120, materials: 20 } },
    secure_locker:  { category: 'storage',    w: 1, h: 1, minTier: 2, jobs: 0, cost: { gold: 140, materials: 20 } },
    hatchery:       { category: 'pet',        w: 2, h: 1, minTier: 1, jobs: 1, cost: { gold: 120, materials: 15 } },
    pet_lab:        { category: 'pet',        w: 2, h: 2, minTier: 2, jobs: 1, cost: { gold: 200, materials: 30, specialty: ['saltleaf_grain', 3] } },
    creature_pens:  { category: 'pet',        w: 2, h: 1, minTier: 3, jobs: 0, cost: { gold: 140, materials: 20 } },
    tavern_corner:  { category: 'social',     w: 2, h: 1, minTier: 2, jobs: 1, cost: { gold: 130, materials: 15 } },
    story_deck:     { category: 'social',     w: 2, h: 2, minTier: 3, jobs: 0, cost: { gold: 150, materials: 20 } },
    music_room:     { category: 'social',     w: 2, h: 1, minTier: 3, jobs: 0, cost: { gold: 160, materials: 20, specialty: ['crown_silk', 1] } },
    boarding_gate:  { category: 'defense',    w: 1, h: 1, minTier: 1, jobs: 1, cost: { gold: 100, materials: 15 } },
    barricade_room: { category: 'defense',    w: 2, h: 1, minTier: 2, jobs: 0, cost: { gold: 150, materials: 25 } },
    guard_post:     { category: 'defense',    w: 1, h: 1, minTier: 3, jobs: 1, cost: { gold: 120, materials: 20, specialty: ['stormwood', 1] } }
  };
  const STRUCTURES = {
    stair: { cost: { gold: 30, materials: 5 } },
    door:  { cost: { gold: 20, materials: 3 } }
  };

  // Four hull tiers (GDD §11.4). bulkhead = blocked column with a default door.
  const HULLS = [
    { id: 'starter',    tier: 1, decks: [{ w: 10, h: 4 }], cost: null, unlockRegion: 1 },
    { id: 'voyager',    tier: 2, decks: [{ w: 12, h: 4 }, { w: 10, h: 4, bulkhead: 5 }], cost: { gold: 500, materials: 50, specialty: ['ember_ore', 3] }, unlockRegion: 2 },
    { id: 'adventurer', tier: 3, decks: [{ w: 12, h: 5, bulkhead: 8 }, { w: 12, h: 4, bulkhead: 6 }, { w: 10, h: 4 }], cost: { gold: 1500, materials: 120, specialty: ['prism_quartz', 4] }, unlockRegion: 4 },
    { id: 'legend',     tier: 4, decks: [{ w: 14, h: 5, bulkhead: 9 }, { w: 12, h: 5, bulkhead: 6 }, { w: 12, h: 4 }, { w: 10, h: 4, bulkhead: 5 }], cost: { gold: 3200, materials: 220, specialty: ['leviathan_scale', 5] }, unlockRegion: 9, blueprint: 'legend_keel' }
  ];

  // ------------------------------------------------------------------- items
  const WEAPON_TYPES = {
    blade:  { atk: 1.0,  spd: 1, props: [] },
    shield: { atk: 0.6,  def: 0.6, props: ['guard'] },
    spear:  { atk: 0.9,  props: ['reach'] },
    gun:    { atk: 1.0,  props: ['ranged'] },
    fist:   { atk: 0.75, props: ['double'] },
    kit:    { atk: 0.55, props: ['mend'] },
    ladle:  { atk: 0.7,  props: ['nourish'] },
    staff:  { atk: 0.95, props: ['splash'] },
    tool:   { atk: 0.8,  props: ['sunder'] },
    whip:   { atk: 0.85, props: ['reach', 'pet'] },
    banner: { atk: 0.7,  props: ['aura'] }
  };
  const REGION_ORDER = ['dawnwater', 'emberreach', 'verdant_maw', 'glass_current', 'crown_shoals', 'stormbelt', 'moonwake', 'ashen_trench', 'leviathan_ring', 'grand_horizon'];
  const REGION_SPECIALTY = {
    dawnwater: 'saltleaf_grain', emberreach: 'ember_ore', verdant_maw: 'verdant_resin', glass_current: 'prism_quartz', crown_shoals: 'crown_silk',
    stormbelt: 'stormwood', moonwake: 'moon_ink', ashen_trench: 'abyss_alloy', leviathan_ring: 'leviathan_scale', grand_horizon: 'horizon_glass'
  };
  const REGION_HAZARD = {
    dawnwater: null, emberreach: 'heat', verdant_maw: 'poison', glass_current: 'glare', crown_shoals: null,
    stormbelt: 'storm', moonwake: 'dream', ashen_trench: 'pressure', leviathan_ring: 'tide', grand_horizon: null
  };
  const HAZARDS = {
    heat:     { every: 4, dmgPct: 0.03 },
    poison:   { every: 4, dmgPct: 0.025 },
    glare:    { dealtMult: 0.88 },
    storm:    { every: 5, dmgPct: 0.035, slow: 1 },
    dream:    { every: 6, stunRandom: 1 },
    pressure: { takenMult: 1.12 },
    tide:     { spdMult: 0.85 }
  };
  const SPECIALTIES = {
    saltleaf_grain: { color: 'white',  price: 20 },  ember_ore: { color: 'red', price: 34 },      verdant_resin: { color: 'green', price: 48 },
    prism_quartz:   { color: 'blue',   price: 62 },  crown_silk: { color: 'yellow', price: 76 },  stormwood: { color: 'blue', price: 90 },
    moon_ink:       { color: 'purple', price: 104 }, abyss_alloy: { color: 'purple', price: 118 }, leviathan_scale: { color: 'green', price: 132 },
    horizon_glass:  { color: 'yellow', price: 150 }
  };
  const INGREDIENTS = {
    fire_pepper: { color: 'red', price: 12 }, sea_pearl: { color: 'blue', price: 12 }, kelp_sprig: { color: 'green', price: 12 },
    sun_honey: { color: 'yellow', price: 12 }, dusk_ink: { color: 'purple', price: 12 }, salt_crystal: { color: 'white', price: 12 }
  };
  const INGREDIENT_BY_COLOR = { red: 'fire_pepper', blue: 'sea_pearl', green: 'kelp_sprig', yellow: 'sun_honey', purple: 'dusk_ink', white: 'salt_crystal' };

  // Regional accessory effect per tier (cycled through regions).
  const REGIONAL_ACCESSORIES = [
    { id: 'lucky_shell',      mods: { goldPct: 0.12 } },
    { id: 'ember_charm',      mods: { firstAid: 0.3 } },
    { id: 'vine_band',        mods: { quickStart: 50 } },
    { id: 'prism_lens',       mods: { focusDmg: 0.2 } },
    { id: 'crown_seal',       mods: { goldPct: 0.15, lootPct: 0.1 } },
    { id: 'storm_anchor',     mods: { stunImmune: 1, defPct: 0.05 } },
    { id: 'moon_lantern',     mods: { dodge: 0.1 } },
    { id: 'abyss_ring',       mods: { lifesteal: 0.1 } },
    { id: 'scale_talisman',   mods: { thorns: 0.15, hpPct: 0.06 } },
    { id: 'horizon_compass',  mods: { spd: 4, crit: 0.08 } }
  ];
  const AFFIXES = {
    sturdy: { hpPct: 0.06 }, keen: { crit: 0.05 }, swift: { spd: 2 }, warded: { defPct: 0.06 }, mighty: { atkPct: 0.05 }
  };

  const ITEMS = {};
  function round(n) { return Math.round(n); }
  REGION_ORDER.forEach((regionId, idx) => {
    const t = idx + 1;
    const spec = REGION_SPECIALTY[regionId];
    for (const [type, w] of Object.entries(WEAPON_TYPES)) {
      ITEMS['w_' + type + '_' + t] = {
        id: 'w_' + type + '_' + t, slot: 'weapon', wtype: type, tier: t, regionId, set: true,
        stats: { atk: round((3 + 3.7 * (t - 1)) * w.atk), def: w.def ? round((2 + 2.2 * (t - 1)) * w.def) : 0, hp: 0, spd: w.spd || 0 },
        props: w.props.slice(), price: round(45 + 42 * Math.pow(t - 1, 1.5)), recipe: { materials: 4 + 3 * t, specialty: [spec, 1] }
      };
    }
    ITEMS['o_coat_' + t] = {
      id: 'o_coat_' + t, slot: 'outfit', otype: 'coat', tier: t, regionId, set: true,
      stats: { atk: 0, def: round(2 + 2.3 * (t - 1)), hp: round(8 + 15 * (t - 1)), spd: 1 }, props: [], resist: REGION_HAZARD[regionId] ? [REGION_HAZARD[regionId]] : [],
      price: round(40 + 38 * Math.pow(t - 1, 1.5)), recipe: { materials: 4 + 3 * t, specialty: [spec, 1] }
    };
    ITEMS['o_armor_' + t] = {
      id: 'o_armor_' + t, slot: 'outfit', otype: 'armor', tier: t, regionId, set: true,
      stats: { atk: 0, def: round(3 + 3.3 * (t - 1)), hp: round(14 + 26 * (t - 1)), spd: -1 }, props: [], resist: REGION_HAZARD[regionId] ? [REGION_HAZARD[regionId]] : [],
      price: round(55 + 50 * Math.pow(t - 1, 1.5)), recipe: { materials: 6 + 4 * t, specialty: [spec, 2] }
    };
    const acc = REGIONAL_ACCESSORIES[idx];
    ITEMS['a_' + acc.id] = {
      id: 'a_' + acc.id, slot: 'accessory', tier: t, regionId, nameKey: 'item.a_' + acc.id + '.name',
      stats: { atk: 0, def: 0, hp: round(5 * t), spd: 0 }, props: [], mods: acc.mods,
      price: round(60 + 55 * Math.pow(t - 1, 1.5)), recipe: { materials: 5 + 3 * t, specialty: [spec, 2] }
    };
  });
  ITEMS.a_escape_rope = { id: 'a_escape_rope', slot: 'accessory', tier: 1, regionId: null, nameKey: 'item.a_escape_rope.name', stats: { atk: 0, def: 0, hp: 0, spd: 0 }, props: [], mods: { escape: 1 }, price: 40, general: true };
  ITEMS.a_work_gloves = { id: 'a_work_gloves', slot: 'accessory', tier: 1, regionId: null, nameKey: 'item.a_work_gloves.name', stats: { atk: 0, def: 1, hp: 0, spd: 0 }, props: [], mods: { jobPct: 0.5 }, price: 50, general: true };

  // Distinctive alternatives from dungeons, trials, and legend challenges (GDD §7.6).
  const UNIQUES = [
    ['gullfeather_saber', 'weapon', 'blade', 1, { atk: 8, spd: 2 }, ['double']],
    ['mira_spyglass', 'accessory', null, 1, { hp: 10 }, [], { quickStart: 40, crit: 0.05 }],
    ['cinder_maul', 'weapon', 'fist', 2, { atk: 12 }, ['double', 'sunder']],
    ['flint_heartstone', 'accessory', null, 2, { hp: 20 }, [], { hazardResist: 1, hpPct: 0.08 }],
    ['fernwhip', 'weapon', 'whip', 3, { atk: 15 }, ['reach', 'pet', 'chill']],
    ['rook_mask', 'accessory', null, 3, { hp: 25 }, [], { stunImmune: 1, dodge: 0.05 }],
    ['prism_rifle', 'weapon', 'gun', 4, { atk: 22 }, ['ranged', 'pierce']],
    ['selene_mirror', 'accessory', null, 4, { hp: 30 }, [], { focusDmg: 0.3 }],
    ['crest_rapier', 'weapon', 'blade', 5, { atk: 26, spd: 2 }, ['double', 'crit']],
    ['cassian_signet', 'accessory', null, 5, { hp: 30 }, [], { goldPct: 0.25, crit: 0.05 }],
    ['gale_harpoon', 'weapon', 'spear', 6, { atk: 30 }, ['reach', 'chill']],
    ['nessa_stormcloak', 'outfit', null, 6, { def: 24, hp: 150, spd: 1 }, [], null, ['storm', 'tide', 'heat']],
    ['lantern_staff', 'weapon', 'staff', 7, { atk: 34 }, ['splash', 'mend']],
    ['orin_charm', 'accessory', null, 7, { hp: 40 }, [], { dodge: 0.1, quickStart: 40 }],
    ['abyss_cleaver', 'weapon', 'blade', 8, { atk: 40 }, ['lifesteal', 'pierce']],
    ['vale_ring', 'accessory', null, 8, { hp: 45 }, [], { lifesteal: 0.1, atkPct: 0.08 }],
    ['leviathan_tooth', 'weapon', 'spear', 9, { atk: 44 }, ['reach', 'sunder', 'pierce']],
    ['brakka_shell', 'outfit', null, 9, { def: 36, hp: 240, spd: -1 }, [], null, ['heat', 'poison', 'glare', 'storm', 'dream', 'pressure', 'tide']],
    ['dawnbreaker', 'weapon', 'blade', 10, { atk: 52, spd: 2 }, ['double', 'pierce', 'lifesteal']],
    ['aurelia_crown', 'accessory', null, 10, { hp: 60, spd: 3 }, [], { auraAtk: 0.08 }],
    ['storm_crown', 'accessory', null, 10, { hp: 80 }, [], { hazardResist: 1, stunImmune: 1, spd: 2 }],
    ['moonveil', 'outfit', null, 10, { def: 46, hp: 320, spd: 2 }, [], { dodge: 0.08 }, ['dream', 'glare']],
    ['trench_seal', 'accessory', null, 10, { hp: 70 }, [], { lifesteal: 0.12, thorns: 0.12 }],
    ['ringbreaker', 'weapon', 'fist', 10, { atk: 50 }, ['double', 'sunder', 'pierce']],
    ['horizon_star', 'accessory', null, 10, { hp: 90, spd: 4 }, [], { crit: 0.12, auraAtk: 0.05 }]
  ];
  for (const [id, slot, wtype, tier, stats, props, mods, resist] of UNIQUES) {
    ITEMS['u_' + id] = {
      id: 'u_' + id, slot, wtype: wtype || undefined, tier, unique: true, nameKey: 'item.u_' + id + '.name',
      stats: Object.assign({ atk: 0, def: 0, hp: 0, spd: 0 }, stats), props, mods: mods || null, resist: resist || [], price: 0
    };
  }

  // -------------------------------------------------------------------- pets
  // Role is chosen by the FIRST feed input; matching a family's signature
  // sequence hatches a Prime pet (GDD §9.6).
  const ROLE_BY_COLOR = { red: 'companion', yellow: 'companion', blue: 'helper', green: 'helper', purple: 'explorer', white: 'explorer' };
  const PET_FAMILIES = [
    { id: 'tidefin',     regionId: 'dawnwater',      color: 'blue',   ability: 'splash',   sig: { companion: ['red', 'blue', 'blue'],      helper: ['blue', 'white', 'green'],   explorer: ['white', 'blue', 'purple'] } },
    { id: 'cinderback',  regionId: 'emberreach',     color: 'red',    ability: 'burn',     sig: { companion: ['red', 'red', 'yellow'],     helper: ['green', 'red', 'white'],    explorer: ['purple', 'red', 'red'] } },
    { id: 'mossling',    regionId: 'verdant_maw',    color: 'green',  ability: 'mend',     sig: { companion: ['yellow', 'green', 'red'],   helper: ['green', 'green', 'blue'],   explorer: ['white', 'green', 'yellow'] } },
    { id: 'glasswing',   regionId: 'glass_current',  color: 'blue',   ability: 'mark',     sig: { companion: ['red', 'white', 'blue'],     helper: ['blue', 'blue', 'yellow'],   explorer: ['purple', 'white', 'blue'] } },
    { id: 'pearlcub',    regionId: 'crown_shoals',   color: 'white',  ability: 'shell',    sig: { companion: ['yellow', 'white', 'white'], helper: ['blue', 'yellow', 'white'],  explorer: ['white', 'white', 'green'] } },
    { id: 'cloudray',    regionId: 'stormbelt',      color: 'yellow', ability: 'gust',     sig: { companion: ['yellow', 'blue', 'yellow'], helper: ['green', 'yellow', 'blue'],  explorer: ['purple', 'yellow', 'white'] } },
    { id: 'dreammoth',   regionId: 'moonwake',       color: 'purple', ability: 'lull',     sig: { companion: ['red', 'purple', 'white'],   helper: ['blue', 'purple', 'purple'], explorer: ['purple', 'purple', 'yellow'] } },
    { id: 'gloomjaw',    regionId: 'ashen_trench',   color: 'purple', ability: 'maul',     sig: { companion: ['red', 'purple', 'red'],     helper: ['green', 'purple', 'red'],   explorer: ['purple', 'green', 'purple'] } },
    { id: 'shellwarden', regionId: 'leviathan_ring', color: 'green',  ability: 'ward',     sig: { companion: ['yellow', 'green', 'green'], helper: ['green', 'blue', 'green'],   explorer: ['white', 'green', 'blue'] } },
    { id: 'starwake',    regionId: 'grand_horizon',  color: 'yellow', ability: 'radiance', sig: { companion: ['yellow', 'yellow', 'white'], helper: ['blue', 'yellow', 'yellow'], explorer: ['white', 'yellow', 'purple'] } }
  ];
  const PET_ROLES = ['companion', 'helper', 'explorer'];
  const PET_ABILITIES = {
    splash:   { power: 1.1, fx: { slow: 2 } },
    burn:     { power: 0.6, fx: { dot: 0.25, dotDur: 4 } },
    mend:     { heal: 1.4, target: 'owner' },
    mark:     { power: 0.4, fx: { mark: 4 } },
    shell:    { shield: 0.15, target: 'owner' },
    gust:     { target: 'allies', fx: { meter: 15 } },
    lull:     { power: 0.3, fx: { stun: 1.5 } },
    maul:     { power: 1.9 },
    ward:     { target: 'owner', shield: 0.2, fx: { taunt: 3 } },
    radiance: { target: 'allies', heal: 0.5 }
  };
  const PET_SPECIES = {};
  for (const f of PET_FAMILIES) {
    for (const role of PET_ROLES) {
      PET_SPECIES[f.id + '_' + role] = { id: f.id + '_' + role, familyId: f.id, role, evolved: false, evolvesTo: f.id + '_' + role + '_evo' };
      PET_SPECIES[f.id + '_' + role + '_evo'] = { id: f.id + '_' + role + '_evo', familyId: f.id, role, evolved: true, evolvesTo: null };
    }
  }

  // -------------------------------------------------------- enemy archetypes
  const ENEMY_ARCHETYPES = {
    skirmisher: { lane: 'front',  range: 'melee',  base: { hp: 62,  atk: 9,  def: 4,  spd: 13 }, skills: ['e_slash'], tags: ['swift'] },
    brute:      { lane: 'front',  range: 'melee',  base: { hp: 115, atk: 10, def: 8,  spd: 7 },  skills: ['e_crush'], tags: ['armored'] },
    shooter:    { lane: 'rear',   range: 'ranged', base: { hp: 52,  atk: 10, def: 3,  spd: 10 }, skills: ['e_volley'], tags: ['ranged'] },
    caster:     { lane: 'rear',   range: 'ranged', base: { hp: 52,  atk: 11, def: 3,  spd: 9 },  skills: ['e_hex'], tags: ['caster'] },
    healer:     { lane: 'center', range: 'ranged', base: { hp: 62,  atk: 7,  def: 4,  spd: 10 }, skills: ['e_mend'], tags: ['healer'] },
    boss:       { lane: 'front',  range: 'melee',  base: { hp: 250, atk: 12, def: 9,  spd: 9 },  skills: ['e_crush', 'e_roar'], tags: ['boss'], boss: true },
    captain:    { lane: 'front',  range: 'melee',  base: { hp: 300, atk: 13, def: 9,  spd: 11 }, skills: ['e_slash', 'e_roar'], tags: ['boss', 'captain'], boss: true },
    decoy:      { lane: 'front',  range: 'melee',  base: { hp: 120, atk: 0,  def: 30, spd: 0 },  skills: [], tags: ['decoy'], decoy: true }
  };
  const PIRATES = {
    pennant_deckhand: 'skirmisher', pennant_bosun: 'brute', pennant_gunner: 'shooter', pennant_hexer: 'caster', pennant_surgeon: 'healer'
  };

  // ------------------------------------------------------------------ tuning
  const TUNING = {
    growth: { hp: 0.12, atk: 0.10, def: 0.09, spd: 0.25 },
    enemyGrowth: { hp: 0.13, atk: 0.11, def: 0.09, spd: 0.25 },
    enemyScale: { hp: 2.2, atk: 1.9, def: 1.0, perLevel: 0.008 },
    levelGap: 0.07,         // per level an enemy is above (or below) the party average
    levelCap: 60,
    xpBase: 90, xpPerLevel: 36, // xp needed for the next level = xpBase + xpPerLevel * level
    masteryPerBattle: 5,
    qualifyMastery: 40,      // branch qualification
    masteredAt: 100,         // passive becomes a legacy option
    legacySlots: 2,
    rationStamina: 15, rationFood: 1, supplyStamina: 30,
    startGold: 300, startFood: 12, startSupplies: 2, startMaterials: 20, startStamina: 60, maxStamina: 100,
    injuryPenalty: 0.10, maxInjuriesPerDefeat: 2, defeatLossRate: 0.25,
    recoverySaveCount: 3, manualSlotCount: 3, logLimit: 40, committedLimit: 300,
    baseFoodCap: 0, baseSupplyCap: 10, baseEquipCap: 40, basePetCap: 0,
    respecBase: 40, respecPerLevel: 12,
    battleTick: 0.1, battleTimeLimit: 240
  };

  const Content = {
    CONTENT_VERSION, ROLES, FORMATION_LANES, COLOR_TAGS, LOCATION_TYPES, KNOWLEDGE_STATES, INVESTMENT_TRACKS,
    FACILITY_CATEGORIES, STANCES, PRIORITIES, SKILL_CATS, ORIGINS, TRAITS, CREW_EVENTS, APTITUDES, FACTIONS,
    SKILLS, PASSIVES, BASE_CLASSES, BRANCHES, CLASSES, BASE_CLASS_IDS, FACILITIES, STRUCTURES, HULLS,
    WEAPON_TYPES, REGION_ORDER, REGION_SPECIALTY, REGION_HAZARD, HAZARDS, SPECIALTIES, INGREDIENTS, INGREDIENT_BY_COLOR,
    REGIONAL_ACCESSORIES, AFFIXES, ITEMS, ROLE_BY_COLOR, PET_FAMILIES, PET_ROLES, PET_ABILITIES, PET_SPECIES,
    ENEMY_ARCHETYPES, PIRATES, TUNING,
    hull(id) { return HULLS.find(h => h.id === id) || HULLS[0]; },
    petFamily(id) { return PET_FAMILIES.find(f => f.id === id) || null; },
    baseClassOf(id) { const c = CLASSES[id]; return c && c.parent ? c.parent : id; }
  };

  root.P7S = root.P7S || {};
  root.P7S.Content = Content;
  if (typeof module !== 'undefined' && module.exports) module.exports = Content;
})(typeof globalThis !== 'undefined' ? globalThis : this);
