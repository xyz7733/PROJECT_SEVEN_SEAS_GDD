/*
 * Project Seven Seas — world content: ten handcrafted sea regions with ten
 * locations each (100 total), routes, room graphs, encounters, quests,
 * captain trials, legend challenges, and sea-event pools (GDD §4, §5, §12).
 * All identifiers are English; display text comes from localization keys.
 */
(function (root) {
  'use strict';

  const Content = root.P7S && root.P7S.Content ? root.P7S.Content : require('./content.js');

  // Location slots per region, in this fixed order (GDD §12.3 budget).
  const SLOT_TYPES = ['port', 'port', 'island', 'island', 'island', 'dungeon', 'dungeon', 'wreck', 'arena', 'secret'];
  const SLOT_LEVEL = [0, 0, 0, 1, 2, 2, 3, 2, 4, 3];
  // Base chart layout (normalized coordinates); each region transforms it.
  const BASE_LAYOUT = [[0.15, 0.62], [0.62, 0.84], [0.34, 0.40], [0.48, 0.66], [0.75, 0.52], [0.14, 0.24], [0.86, 0.80], [0.58, 0.24], [0.86, 0.17], [0.30, 0.86]];
  // Route graph between slot indexes (undirected).
  const SLOT_ROUTES = [[0, 2], [0, 5], [0, 3], [2, 7], [2, 3], [3, 1], [3, 9], [1, 4], [1, 6], [4, 8], [7, 8], [4, 6], [5, 7], [2, 5]];

  const REGIONS = [
    {
      id: 'dawnwater', rivalId: 'mira_gull', level: 1, mechanic: null,
      palette: { sea: '#3a8fd0', deep: '#2a6fae', land: '#e9d58f', grass: '#79c46a', accent: '#f7d154' },
      locs: ['brightquay', 'saltmarsh_landing', 'gull_rock', 'lantern_isle', 'coral_steps', 'old_lookout', 'brine_cellars', 'driftplank_wreck', 'dawn_trial_ring', 'tidefin_grotto'],
      enemies: { skirmisher: 'gull_raider', brute: 'reef_crab', shooter: 'spray_gunner', caster: 'brine_witch', healer: 'kelp_tender' }, bosses: ['lookout_warden', 'cellar_king'],
      sea: { pirate: 3, monster: 2, cache: 3, vessel: 2, shortcut: 1, weather: 1, inspection: 1, clue: 2 },
      capability: ['vanguard', 'striker', 'support'],
      ports: [{ market: 1, tavern: 1, workshop: 0, quest_board: 1, navigation: 0 }, { market: 1, tavern: 1, workshop: 1, quest_board: 0, navigation: 1 }],
      trial: { waves: [[['captain'], ['skirmisher'], ['shooter'], ['healer']]] }
    },
    {
      id: 'emberreach', rivalId: 'flint_cinder', level: 6, mechanic: 'burning',
      palette: { sea: '#b35a3c', deep: '#7a3626', land: '#4a3a36', grass: '#e0703a', accent: '#ffb347' },
      locs: ['cinderport', 'ashfall_harbor', 'basalt_isle', 'smolder_key', 'obsidian_atoll', 'magma_vents', 'forge_depths', 'scorched_galleon', 'ember_crucible', 'cinderback_nest'],
      enemies: { skirmisher: 'cinder_imp', brute: 'magma_golem', shooter: 'ash_slinger', caster: 'flame_seer', healer: 'ember_monk' }, bosses: ['vent_tyrant', 'forge_colossus'],
      sea: { pirate: 2, monster: 3, cache: 2, vessel: 3, shortcut: 1, weather: 2, inspection: 1, clue: 1 },
      capability: ['support', 'vanguard'],
      ports: [{ market: 1, tavern: 1, workshop: 2, quest_board: 1, navigation: 0 }, { market: 1, tavern: 0, workshop: 1, quest_board: 1, navigation: 1 }],
      trial: { waves: [[['captain'], ['brute'], ['shooter'], ['shooter']]] }
    },
    {
      id: 'verdant_maw', rivalId: 'rook_fern', level: 11, mechanic: 'disruptor',
      palette: { sea: '#2f8f6a', deep: '#1f6a4e', land: '#5b7f3a', grass: '#3fae4a', accent: '#c6e86b' },
      locs: ['rootharbor', 'fernwater_post', 'tanglewood_isle', 'orchid_cay', 'maw_shore', 'overgrown_shrine', 'thornroot_caves', 'vine_wreck', 'verdant_arena', 'moss_hollow'],
      enemies: { skirmisher: 'vine_stalker', brute: 'bark_brute', shooter: 'thorn_archer', caster: 'spore_shaman', healer: 'bloom_nurse' }, bosses: ['shrine_tyrant', 'root_mother'],
      sea: { pirate: 2, monster: 3, cache: 2, vessel: 1, shortcut: 3, weather: 1, inspection: 1, clue: 2 },
      capability: ['controller', 'scout'],
      ports: [{ market: 1, tavern: 1, workshop: 1, quest_board: 1, navigation: 1 }, { market: 0, tavern: 1, workshop: 0, quest_board: 1, navigation: 1 }],
      trial: { waves: [[['captain'], ['skirmisher'], ['skirmisher'], ['caster'], ['caster']]] }
    },
    {
      id: 'glass_current', rivalId: 'selene_prism', level: 16, mechanic: 'decoys',
      palette: { sea: '#4fb3c8', deep: '#2c7f9c', land: '#cfe6ef', grass: '#9fd3e6', accent: '#e7f7ff' },
      locs: ['prismhaven', 'mirrorbay', 'shard_reef', 'lens_isle', 'quartz_spire', 'crystal_vault', 'refraction_maze', 'glassbound_hulk', 'prism_court', 'glasswing_lagoon'],
      enemies: { skirmisher: 'shard_fencer', brute: 'quartz_knight', shooter: 'prism_sniper', caster: 'mirror_mage', healer: 'lens_cleric' }, bosses: ['vault_sentinel', 'refraction_queen'],
      sea: { pirate: 3, monster: 2, cache: 2, vessel: 2, shortcut: 1, weather: 1, inspection: 2, clue: 2 },
      capability: ['striker', 'controller'],
      ports: [{ market: 2, tavern: 1, workshop: 1, quest_board: 1, navigation: 1 }, { market: 1, tavern: 1, workshop: 1, quest_board: 0, navigation: 0 }],
      trial: { waves: [[['captain'], ['decoy'], ['decoy'], ['shooter'], ['healer']]] }
    },
    {
      id: 'crown_shoals', rivalId: 'cassian_crest', level: 21, mechanic: 'mixed',
      palette: { sea: '#3f6fb8', deep: '#2b4f8c', land: '#f2dfa7', grass: '#d9b44a', accent: '#ffd76a' },
      locs: ['crownport', 'silkmarket', 'gilded_cay', 'heron_isle', 'regent_bank', 'charter_archive', 'old_family_crypt', 'treasury_wreck', 'crown_tourney', 'pearl_grotto'],
      enemies: { skirmisher: 'cutpurse', brute: 'crown_enforcer', shooter: 'musket_noble', caster: 'court_hexer', healer: 'gilded_medic' }, bosses: ['archive_keeper', 'family_patriarch'],
      sea: { pirate: 3, monster: 1, cache: 2, vessel: 2, shortcut: 1, weather: 1, inspection: 3, clue: 2 },
      capability: ['vanguard', 'striker', 'controller', 'support'],
      ports: [{ market: 2, tavern: 2, workshop: 1, quest_board: 1, navigation: 1 }, { market: 2, tavern: 1, workshop: 1, quest_board: 1, navigation: 0 }],
      trial: { waves: [[['captain'], ['brute'], ['shooter'], ['caster'], ['healer']]] }
    },
    {
      id: 'stormbelt', rivalId: 'nessa_gale', level: 26, mechanic: null,
      palette: { sea: '#4a5f7a', deep: '#2f3e55', land: '#7c8796', grass: '#8fa6bf', accent: '#ffe066' },
      locs: ['gale_harbor', 'beacon_rest', 'thunder_rock', 'squall_isle', 'lightning_reach', 'drowned_beacon', 'tempest_caverns', 'stormwrack_hulk', 'eye_of_storm', 'cloudray_aerie'],
      enemies: { skirmisher: 'squall_runner', brute: 'thunder_brute', shooter: 'gale_harpooner', caster: 'storm_witch', healer: 'beacon_keeper' }, bosses: ['drowned_keeper', 'tempest_wyrm'],
      sea: { pirate: 2, monster: 2, cache: 2, vessel: 2, shortcut: 1, weather: 4, inspection: 1, clue: 1 },
      capability: ['support', 'vanguard'],
      ports: [{ market: 1, tavern: 1, workshop: 2, quest_board: 1, navigation: 1 }, { market: 1, tavern: 1, workshop: 1, quest_board: 1, navigation: 1 }],
      trial: { waves: [[['captain'], ['brute'], ['shooter'], ['caster']]] }
    },
    {
      id: 'moonwake', rivalId: 'orin_lantern', level: 31, mechanic: 'intent',
      palette: { sea: '#2b2f6b', deep: '#1a1d47', land: '#5c5a8a', grass: '#8a7fd0', accent: '#d9c8ff' },
      locs: ['lanternport', 'dusk_mooring', 'nightbloom_isle', 'echo_atoll', 'starfall_key', 'forgotten_observatory', 'dream_labyrinth', 'moonlit_wreck', 'moonwake_stage', 'dreammoth_glade'],
      enemies: { skirmisher: 'night_stalker', brute: 'dream_ogre', shooter: 'star_archer', caster: 'moon_oracle', healer: 'lull_spirit' }, bosses: ['observatory_ghost', 'labyrinth_dreamer'],
      sea: { pirate: 2, monster: 3, cache: 2, vessel: 1, shortcut: 2, weather: 1, inspection: 1, clue: 3 },
      capability: ['scout', 'controller'],
      ports: [{ market: 1, tavern: 1, workshop: 1, quest_board: 1, navigation: 2 }, { market: 1, tavern: 1, workshop: 1, quest_board: 1, navigation: 1 }],
      trial: { waves: [[['captain'], ['brute'], ['brute'], ['caster']]] }
    },
    {
      id: 'ashen_trench', rivalId: 'vale_ash', level: 36, mechanic: 'sealed',
      palette: { sea: '#3a3340', deep: '#221d28', land: '#5a4f4a', grass: '#9a5a4a', accent: '#ff7a5a' },
      locs: ['ashport', 'relic_dock', 'cinder_shelf', 'sunken_spires', 'abyss_ledge', 'sealed_ruins', 'trench_sanctum', 'relic_hunter_wreck', 'ashen_seal_arena', 'gloomjaw_den'],
      enemies: { skirmisher: 'relic_thief', brute: 'abyss_brute', shooter: 'trench_gunner', caster: 'ash_hexer', healer: 'deep_priest' }, bosses: ['seal_guardian', 'trench_horror'],
      sea: { pirate: 3, monster: 3, cache: 1, vessel: 1, shortcut: 1, weather: 1, inspection: 1, clue: 2 },
      capability: ['controller', 'striker'],
      ports: [{ market: 1, tavern: 1, workshop: 2, quest_board: 1, navigation: 1 }, { market: 2, tavern: 1, workshop: 1, quest_board: 1, navigation: 0 }],
      trial: { waves: [[['captain'], ['caster'], ['caster'], ['brute']]] }
    },
    {
      id: 'leviathan_ring', rivalId: 'brakka_reef', level: 41, mechanic: 'waves',
      palette: { sea: '#1f7a8c', deep: '#145566', land: '#c9b28a', grass: '#5fb39a', accent: '#9ef0d0' },
      locs: ['ringhold', 'migration_post', 'shell_isle', 'bone_reef', 'titan_atoll', 'leviathan_gut', 'coral_colossus', 'behemoth_wreck', 'ring_arena', 'shellwarden_shoal'],
      enemies: { skirmisher: 'ring_raider', brute: 'shell_titan', shooter: 'bone_spitter', caster: 'tide_shaman', healer: 'reef_mender' }, bosses: ['gut_leviathan', 'colossus_core'],
      sea: { pirate: 1, monster: 5, cache: 2, vessel: 1, shortcut: 1, weather: 1, inspection: 1, clue: 1 },
      capability: ['vanguard', 'support'],
      ports: [{ market: 1, tavern: 1, workshop: 2, quest_board: 1, navigation: 1 }, { market: 1, tavern: 1, workshop: 1, quest_board: 1, navigation: 1 }],
      trial: { waves: [[['skirmisher'], ['skirmisher'], ['shooter'], ['skirmisher']], [['brute'], ['brute'], ['caster']], [['captain'], ['healer'], ['skirmisher']]] }
    },
    {
      id: 'grand_horizon', rivalId: 'aurelia_dawn', level: 46, mechanic: 'elite', requiresHullTier: 4,
      palette: { sea: '#e08a4a', deep: '#a85a3a', land: '#f7e3b0', grass: '#f2b84a', accent: '#fff3c4' },
      locs: ['horizon_gate', 'conclave_harbor', 'sunrise_isle', 'zenith_cay', 'dawnstar_reef', 'ancient_gatehouse', 'compass_vault', 'rival_flagship_wreck', 'horizon_arena', 'starwake_haven'],
      enemies: { skirmisher: 'gate_duelist', brute: 'horizon_knight', shooter: 'sky_gunner', caster: 'dawn_mage', healer: 'conclave_medic' }, bosses: ['gate_warden', 'compass_guardian'],
      sea: { pirate: 4, monster: 1, cache: 2, vessel: 1, shortcut: 1, weather: 1, inspection: 2, clue: 1 },
      capability: ['vanguard', 'striker', 'controller', 'support', 'scout'],
      ports: [{ market: 2, tavern: 2, workshop: 2, quest_board: 1, navigation: 1 }, { market: 2, tavern: 2, workshop: 2, quest_board: 1, navigation: 1 }],
      trial: { waves: [[['rival', 'flint_cinder'], ['rival', 'selene_prism'], ['healer']], [['brute'], ['brute'], ['caster'], ['healer']], [['captain'], ['skirmisher'], ['shooter']]], levelBonus: 1 }
    }
  ];

  // Rival captains (named, non-recruitable; GDD §4.4, §4.8).
  const RIVALS = {
    mira_gull:     { regionId: 'dawnwater',      skills: ['e_slash', 'e_roar'],               mult: 1.0 },
    flint_cinder:  { regionId: 'emberreach',     skills: ['e_crush', 'e_volley'],             mult: 1.05, burn: true },
    rook_fern:     { regionId: 'verdant_maw',    skills: ['e_hex', 'e_slash'],                mult: 1.05 },
    selene_prism:  { regionId: 'glass_current',  skills: ['e_shell', 'e_volley'],             mult: 1.05 },
    cassian_crest: { regionId: 'crown_shoals',   skills: ['e_slash', 'e_mend', 'e_roar'],     mult: 1.08 },
    nessa_gale:    { regionId: 'stormbelt',      skills: ['e_volley', 'e_stun_all'],          mult: 1.08 },
    orin_lantern:  { regionId: 'moonwake',       skills: ['e_charge', 'e_hex'],               mult: 1.1 },
    vale_ash:      { regionId: 'ashen_trench',   skills: ['e_shell', 'e_crush'],              mult: 1.1, regen: 0.012 },
    brakka_reef:   { regionId: 'leviathan_ring', skills: ['e_crush', 'e_shell'],              mult: 1.12 },
    aurelia_dawn:  { regionId: 'grand_horizon',  skills: ['e_slash', 'e_stun_all', 'e_roar'], mult: 1.18, regen: 0.006 }
  };
  const FACTION_LEADERS = { conclave: 'archon_vessa', league: 'harbormaster_tobin', tidebound: 'dr_ilse_marrow', pennants: 'red_jory' };

  // Postgame legend challenges for late-game regions (GDD §12.3).
  const LEGENDS = {
    stormbelt:      { restriction: 'double_hazard', reward: 'u_storm_crown',  levelBonus: 14 },
    moonwake:       { restriction: 'no_healing',    reward: 'u_moonveil',     levelBonus: 12 },
    ashen_trench:   { restriction: 'four_crew',     reward: 'u_trench_seal',  levelBonus: 10 },
    leviathan_ring: { restriction: 'endless_waves', reward: 'u_ringbreaker',  levelBonus: 8 },
    grand_horizon:  { restriction: 'encore',        reward: 'u_horizon_star', levelBonus: 8 }
  };

  // Room graphs per location type (GDD §5.5). `secret` rooms need an explorer pet.
  const ROOM_TEMPLATES = {
    island: [
      { id: 'landing', kind: 'battle', cost: 8, next: ['grove', 'ridge'], family: 'materials' },
      { id: 'grove', kind: 'resource', cost: 4, next: ['heart', 'hollow'], family: 'specialty' },
      { id: 'ridge', kind: 'battle', cost: 8, next: ['heart'], family: 'gold' },
      { id: 'heart', kind: 'elite', cost: 12, next: [], objective: true, family: 'ingredients' },
      { id: 'hollow', kind: 'resource', cost: 3, next: [], secret: true, family: 'egg' }
    ],
    dungeon: [
      { id: 'gate', kind: 'battle', cost: 10, next: ['west', 'east'], family: 'materials' },
      { id: 'west', kind: 'battle', cost: 10, next: ['depths'], family: 'gold' },
      { id: 'east', kind: 'resource', cost: 6, next: ['depths'], family: 'specialty' },
      { id: 'depths', kind: 'elite', cost: 12, next: ['guardian', 'vault'], family: 'supplies' },
      { id: 'guardian', kind: 'boss', cost: 15, next: [], objective: true, family: 'equipment' },
      { id: 'vault', kind: 'resource', cost: 4, next: [], secret: true, family: 'egg' }
    ],
    wreck: [
      { id: 'hold', kind: 'resource', cost: 6, next: ['cabin'], family: 'materials' },
      { id: 'cabin', kind: 'elite', cost: 10, next: [], objective: true, family: 'equipment' }
    ],
    secret: [
      { id: 'sanctum', kind: 'event', cost: 6, next: [], objective: true, family: 'egg' }
    ],
    arena: [
      { id: 'trial', kind: 'trial', cost: 15, next: [], objective: true, family: 'equipment' }
    ],
    port: []
  };

  // Five main steps per region (GDD §12.3). Indexes refer to location slots.
  const MAIN_TEMPLATE = [
    { type: 'clear', slot: 2, reveal: [1, 3, 7] },
    { type: 'visit', slot: 1, reveal: [5, 4] },
    { type: 'clear', slot: 5, reveal: [6] },
    { type: 'deliver', slot: 0, count: 3, reveal: [8] },
    { type: 'trial', slot: 8, reveal: [] }
  ];
  // Five local or discovery quests per region.
  const SIDE_TEMPLATE = [
    { id: 'survey',   type: 'clear',    slot: 3, giver: 0, faction: 'league',    reward: 'recipe' },
    { id: 'salvage',  type: 'clear',    slot: 7, giver: 0, faction: 'league',    reward: 'supplies' },
    { id: 'outpost',  type: 'clear',    slot: 4, giver: 1, faction: 'league',    reward: 'ingredients' },
    { id: 'legend',   type: 'discover', slot: 9, giver: 1, faction: 'tidebound', reward: 'clue' },
    { id: 'depths',   type: 'clear',    slot: 6, giver: 1, faction: 'tidebound', reward: 'egg' }
  ];
  const CONTRACT_TYPES = ['hunt', 'supply', 'haul'];
  const SEA_EVENT_KINDS = ['pirate', 'monster', 'cache', 'vessel', 'shortcut', 'weather', 'inspection', 'clue'];
  const SEA_EVENT_CHANCE = 0.55;

  // --------------------------------------------------------------- build data
  function hash32(str) {
    let h = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
    return h >>> 0;
  }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

  const LOCATIONS = {};
  const REGION_BY_ID = {};
  const ROUTES = [];
  REGIONS.forEach((r, ri) => {
    r.order = ri + 1;
    r.tier = ri + 1;
    r.specialtyId = Content.REGION_SPECIALTY[r.id];
    r.hazard = Content.REGION_HAZARD[r.id];
    r.petFamilyId = Content.PET_FAMILIES[ri].id;
    r.nextRegionId = REGIONS[ri + 1] ? REGIONS[ri + 1].id : null;
    r.mainQuestId = 'main.' + r.id;
    r.captainTrialId = 'trial.' + r.id;
    r.locationIds = r.locs.slice();
    REGION_BY_ID[r.id] = r;
    const mx = ri % 2 === 1, my = ri % 4 >= 2;
    r.locs.forEach((id, si) => {
      const h = hash32(id);
      let [x, y] = BASE_LAYOUT[si];
      if (mx) x = 1 - x;
      if (my) y = 1 - y;
      x = clamp(x + (((h & 0xff) / 255) - 0.5) * 0.08, 0.08, 0.92);
      y = clamp(y + ((((h >>> 8) & 0xff) / 255) - 0.5) * 0.08, 0.1, 0.9);
      const type = SLOT_TYPES[si];
      LOCATIONS[id] = {
        id, regionId: r.id, slot: si, type, x: Math.round(x * 1000) / 1000, y: Math.round(y * 1000) / 1000,
        level: type === 'arena' ? r.level + 4 + (r.trial.levelBonus || 0) : r.level + SLOT_LEVEL[si],
        initial: ri === 0 ? (si === 0 ? 'visited' : si === 2 ? 'revealed' : 'hidden') : 'hidden',
        portIndex: type === 'port' ? si : null,
        nameKey: 'loc.' + id + '.name'
      };
    });
    SLOT_ROUTES.forEach(([a, b]) => ROUTES.push([r.locs[a], r.locs[b]]));
  });
  // Inter-region sea lanes connect each region's second port to the next region's first port.
  for (let i = 0; i < REGIONS.length - 1; i++) ROUTES.push([REGIONS[i].locs[1], REGIONS[i + 1].locs[0]]);

  const NEIGHBORS = {};
  for (const [a, b] of ROUTES) {
    (NEIGHBORS[a] = NEIGHBORS[a] || []).push(b);
    (NEIGHBORS[b] = NEIGHBORS[b] || []).push(a);
  }

  // Ports (GDD §19.1 Port record).
  const PORTS = {};
  REGIONS.forEach(r => {
    [0, 1].forEach(pi => {
      const id = r.locs[pi];
      PORTS[id] = { id, regionId: r.id, base: Object.assign({}, r.ports[pi]), faction: pi === 0 ? 'league' : (r.order % 2 ? 'tidebound' : 'league'), safeReturnId: id };
    });
  });

  // Quests: 5 main + 5 side per region = 100 authored quests.
  const QUESTS = {};
  REGIONS.forEach(r => {
    MAIN_TEMPLATE.forEach((step, i) => {
      const id = 'main.' + r.id + '.' + i;
      QUESTS[id] = {
        id, kind: 'main', regionId: r.id, step: i, type: step.type, locationId: r.locs[step.slot],
        count: step.count || 0, itemId: step.type === 'deliver' ? r.specialtyId : null,
        reveal: step.reveal.map(s => r.locs[s]), titleKey: 'quest.' + r.id + '.' + i,
        reward: { gold: 30 + 25 * r.tier * (i + 1), xp: 20 + 12 * r.tier, rep: 6 + 2 * i }
      };
    });
    SIDE_TEMPLATE.forEach(s => {
      const id = 'side.' + r.id + '.' + s.id;
      QUESTS[id] = {
        id, kind: 'side', regionId: r.id, template: s.id, type: s.type, locationId: r.locs[s.slot],
        giverId: r.locs[s.giver], faction: s.faction, rewardKind: s.reward, titleKey: 'side.' + s.id + '.title',
        reward: { gold: 40 + 30 * r.tier, materials: 6 + 4 * r.tier, xp: 15 + 10 * r.tier, rep: 8 }
      };
    });
  });

  // ------------------------------------------------------------- accessors
  function region(id) { return REGION_BY_ID[id] || null; }
  function location(id) { return LOCATIONS[id] || null; }
  function regionOf(locId) { const l = LOCATIONS[locId]; return l ? REGION_BY_ID[l.regionId] : null; }
  function rooms(locId) { const l = LOCATIONS[locId]; return l ? ROOM_TEMPLATES[l.type] : []; }
  function room(locId, roomId) { return rooms(locId).find(r => r.id === roomId) || null; }
  function neighbors(locId) { return NEIGHBORS[locId] || []; }
  function mainStep(regionId, step) { return QUESTS['main.' + regionId + '.' + step] || null; }
  function sideQuests(regionId) { return Object.values(QUESTS).filter(q => q.kind === 'side' && q.regionId === regionId); }

  // Voyage distance in chart units: in-region Euclidean distance plus a lane
  // cost for each region crossed.
  function distance(a, b) {
    const la = LOCATIONS[a], lb = LOCATIONS[b];
    if (!la || !lb) return 0;
    const ra = REGION_BY_ID[la.regionId].order, rb = REGION_BY_ID[lb.regionId].order;
    if (ra === rb) return Math.hypot(la.x - lb.x, la.y - lb.y);
    return Math.abs(ra - rb) * 0.9 + 0.3;
  }

  // Resolve an enemy record: regional roster member, boss, pirate, or rival.
  function enemy(enemyId) {
    if (RIVALS[enemyId]) {
      const r = RIVALS[enemyId];
      return { id: enemyId, archetype: 'captain', regionId: r.regionId, skills: r.skills, mult: r.mult, burn: !!r.burn, regen: r.regen || 0, boss: true, rival: true };
    }
    if (Content.PIRATES[enemyId]) {
      const a = Content.ENEMY_ARCHETYPES[Content.PIRATES[enemyId]];
      return { id: enemyId, archetype: Content.PIRATES[enemyId], regionId: null, skills: a.skills, mult: 1, pirate: true };
    }
    if (enemyId === 'crystal_decoy') return { id: enemyId, archetype: 'decoy', regionId: 'glass_current', skills: [], mult: 1, decoy: true };
    for (const r of REGIONS) {
      for (const [arch, id] of Object.entries(r.enemies)) {
        if (id === enemyId) {
          let skills = Content.ENEMY_ARCHETYPES[arch].skills.slice();
          if (r.mechanic === 'intent' && arch === 'brute') skills = ['e_charge'];
          if (r.mechanic === 'decoys' && arch === 'brute') skills = ['e_crush', 'e_shell'];
          if (r.mechanic === 'sealed' && arch === 'caster') skills = ['e_hex', 'e_stun_all'];
          return { id, archetype: arch, regionId: r.id, skills, mult: 1, burn: r.mechanic === 'burning' && (arch === 'skirmisher' || arch === 'shooter') };
        }
      }
      const bi = r.bosses.indexOf(enemyId);
      if (bi >= 0) {
        const skills = ['e_crush', bi === 0 ? 'e_roar' : 'e_stun_all'];
        if (r.mechanic === 'sealed' || r.mechanic === 'decoys') skills.push('e_shell');
        if (r.mechanic === 'intent') skills.push('e_charge');
        return { id: enemyId, archetype: 'boss', regionId: r.id, skills, mult: 1 + 0.06 * bi, boss: true, regen: r.mechanic === 'sealed' ? 0.01 : 0, burn: r.mechanic === 'burning' };
      }
    }
    return null;
  }

  function allEnemyIds() {
    const ids = [];
    REGIONS.forEach(r => { ids.push(...Object.values(r.enemies), ...r.bosses); });
    ids.push(...Object.keys(Content.PIRATES), 'crystal_decoy', ...Object.keys(RIVALS));
    return ids;
  }

  // Deterministic tiny RNG for authored-but-varied groups.
  function seeded(seed) {
    let s = seed >>> 0;
    return function () {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  const GROUPS = {
    battle: [['skirmisher', 'skirmisher', 'shooter'], ['brute', 'skirmisher', 'caster'], ['skirmisher', 'shooter', 'healer'], ['brute', 'shooter', 'shooter']],
    elite: [['brute', 'skirmisher', 'shooter', 'healer'], ['brute', 'brute', 'caster', 'shooter'], ['skirmisher', 'skirmisher', 'caster', 'healer']],
    boss: [['boss', 'skirmisher', 'healer'], ['boss', 'brute', 'shooter']]
  };

  // Build an encounter definition (GDD §19.1 Encounter record).
  function encounterFor(locId, roomId, opts) {
    const o = opts || {};
    const loc = LOCATIONS[locId];
    const r = REGION_BY_ID[loc.regionId];
    const rm = room(locId, roomId);
    const rand = seeded(hash32(locId + ':' + roomId + ':' + (o.variant || 0)));
    const lvl = loc.level + (rm && rm.kind === 'elite' ? 1 : 0) + (rm && rm.kind === 'boss' ? 2 : 0);
    const mods = [];
    if (r.hazard) mods.push(r.hazard);
    if (r.mechanic) mods.push(r.mechanic);
    let waves;
    if (rm && rm.kind === 'trial') {
      waves = r.trial.waves.map(w => w.map(([arch, rid]) => {
        if (arch === 'captain') return { enemyId: r.rivalId, level: loc.level };
        if (arch === 'rival') return { enemyId: rid, level: loc.level - 2 };
        if (arch === 'decoy') return { enemyId: 'crystal_decoy', level: loc.level };
        return { enemyId: r.enemies[arch], level: loc.level - 1 };
      }));
      if (o.legend) {
        const lg = LEGENDS[r.id];
        waves = waves.map(w => w.map(e => Object.assign({}, e, { level: e.level + lg.levelBonus })));
        if (lg.restriction === 'endless_waves') waves = waves.concat([waves[1].map(e => Object.assign({}, e)), waves[0].map(e => Object.assign({}, e))]);
        mods.push('legend_' + lg.restriction);
      } else mods.push('trial');
    } else {
      const kind = rm ? (rm.kind === 'boss' ? 'boss' : rm.kind === 'elite' ? 'elite' : 'battle') : 'battle';
      const pool = GROUPS[kind];
      let group = pool[Math.floor(rand() * pool.length)].slice();
      if (r.mechanic === 'mixed') group = kind === 'battle' ? ['brute', 'shooter', 'caster'] : ['brute', 'shooter', 'caster', 'healer'];
      if (r.mechanic === 'disruptor' && kind !== 'boss') group[group.length - 1] = 'caster';
      const bossId = loc.slot === 5 ? r.bosses[0] : r.bosses[1];
      let wave = group.map(arch => ({ enemyId: arch === 'boss' ? bossId : r.enemies[arch], level: lvl }));
      if (r.mechanic === 'decoys') wave.unshift({ enemyId: 'crystal_decoy', level: lvl });
      if (r.mechanic === 'elite') wave.push({ enemyId: r.enemies.skirmisher, level: lvl - 1 });
      waves = [wave];
      if (r.mechanic === 'waves' && (kind === 'elite' || kind === 'boss')) waves.unshift([{ enemyId: r.enemies.skirmisher, level: lvl - 1 }, { enemyId: r.enemies.shooter, level: lvl - 1 }, { enemyId: r.enemies.skirmisher, level: lvl - 1 }]);
    }
    return {
      id: locId + ':' + roomId + (o.legend ? ':legend' : ''), locationId: locId, roomId, regionId: r.id,
      arena: loc.type === 'arena' ? 'arena' : loc.type, waves, modifiers: mods, level: lvl,
      kind: rm ? rm.kind : 'battle', staminaCost: rm ? rm.cost + (o.legend ? 10 : 0) : 0,
      retreat: { escapeSecs: 3 }, legend: !!o.legend, restriction: o.legend ? LEGENDS[r.id].restriction : null
    };
  }

  // Forced boarding at sea: Crimson Pennant pirates or regional monsters.
  function seaEncounter(regionId, kind, variant, level) {
    const r = REGION_BY_ID[regionId];
    const rand = seeded(hash32(regionId + ':sea:' + kind + ':' + variant));
    let wave;
    if (kind === 'pirate') {
      const ids = Object.keys(Content.PIRATES);
      const n = r.tier >= 4 ? 4 : 3;
      wave = [{ enemyId: 'pennant_bosun', level }];
      for (let i = 1; i < n; i++) wave.push({ enemyId: ids[Math.floor(rand() * ids.length)], level });
    } else {
      const g = GROUPS.battle[Math.floor(rand() * GROUPS.battle.length)];
      wave = g.map(a => ({ enemyId: r.enemies[a], level }));
    }
    const mods = ['boarding'];
    if (r.hazard) mods.push(r.hazard);
    return { id: 'sea:' + regionId + ':' + kind, locationId: null, roomId: null, regionId, arena: 'boarding', waves: [wave], modifiers: mods, level, kind: 'boarding', staminaCost: 0, forced: true, retreat: { escapeSecs: 3 } };
  }

  // Room reward table: fixed first-clear rewards and smaller repeat rewards.
  function roomRewards(locId, roomId, first) {
    const loc = LOCATIONS[locId];
    const r = REGION_BY_ID[loc.regionId];
    const rm = room(locId, roomId);
    const t = r.tier;
    const out = { gold: 0, materials: 0, food: 0, supplies: 0, specialty: 0, ingredient: 0, egg: null, items: [], unique: null, clue: null, shortcut: false };
    const k = rm.kind;
    if (k === 'battle') { out.gold = 10 + 12 * t; out.materials = 3 + 2 * t; }
    if (k === 'elite') { out.gold = 18 + 22 * t; out.materials = 6 + 3 * t; out.ingredient = 1; out.specialty = 1; }
    if (k === 'boss') { out.gold = 40 + 45 * t; out.materials = 12 + 4 * t; out.specialty = 2; out.supplies = 1; }
    if (k === 'resource') { out.materials = 5 + 3 * t; out.specialty = 1; out.food = loc.type === 'island' ? 2 : 0; out.ingredient = 1; }
    if (k === 'event') { out.materials = 6 + 2 * t; out.ingredient = 2; }
    if (k === 'trial') { out.gold = 100 + 90 * t; out.materials = 10 + 5 * t; out.specialty = 2; }
    if (rm.secret) { out.specialty += 1; out.ingredient += 1; }
    if (!first) {
      out.gold = Math.round(out.gold * 0.5); out.materials = Math.round(out.materials * 0.6);
      out.specialty = Math.min(out.specialty, 1); out.food = Math.min(out.food, 1); out.supplies = 0;
      if (k === 'resource') out.ingredient = 1;
      return out;
    }
    out.gold = Math.round(out.gold * 1.5);
    if (k === 'resource' && !rm.secret) out.specialty += 1;
    if (k === 'boss' && loc.slot === 5) out.unique = UNIQUE_BY_REGION[r.id][0];
    if (k === 'boss' && loc.slot === 6) out.egg = { familyId: r.petFamilyId, grade: 2 };
    if (k === 'elite' && loc.type === 'wreck') out.items.push('a_' + Content.REGIONAL_ACCESSORIES[t - 1].id);
    if (k === 'elite' && loc.type === 'island') out.items.push(t % 2 ? 'o_coat_' + t : 'w_blade_' + t);
    if (rm.secret) out.egg = { familyId: r.petFamilyId, grade: 1 };
    if (k === 'event') { out.egg = { familyId: r.petFamilyId, grade: 3 }; out.clue = 'clue.pet.' + r.petFamilyId; out.shortcut = true; }
    if (k === 'trial') out.unique = UNIQUE_BY_REGION[r.id][1];
    return out;
  }
  const UNIQUE_BY_REGION = {};
  REGIONS.forEach((r, i) => {
    const pairs = [['u_gullfeather_saber', 'u_mira_spyglass'], ['u_cinder_maul', 'u_flint_heartstone'], ['u_fernwhip', 'u_rook_mask'], ['u_prism_rifle', 'u_selene_mirror'],
      ['u_crest_rapier', 'u_cassian_signet'], ['u_gale_harpoon', 'u_nessa_stormcloak'], ['u_lantern_staff', 'u_orin_charm'], ['u_abyss_cleaver', 'u_vale_ring'],
      ['u_leviathan_tooth', 'u_brakka_shell'], ['u_dawnbreaker', 'u_aurelia_crown']];
    UNIQUE_BY_REGION[r.id] = pairs[i];
  });

  const World = {
    SLOT_TYPES, REGIONS, RIVALS, FACTION_LEADERS, LEGENDS, ROOM_TEMPLATES, MAIN_TEMPLATE, SIDE_TEMPLATE,
    CONTRACT_TYPES, SEA_EVENT_KINDS, SEA_EVENT_CHANCE, LOCATIONS, ROUTES, PORTS, QUESTS, UNIQUE_BY_REGION,
    hash32, seeded, region, location, regionOf, rooms, room, neighbors, mainStep, sideQuests, distance,
    enemy, allEnemyIds, encounterFor, seaEncounter, roomRewards
  };

  root.P7S = root.P7S || {};
  root.P7S.World = World;
  if (typeof module !== 'undefined' && module.exports) module.exports = World;
})(typeof globalThis !== 'undefined' ? globalThis : this);
