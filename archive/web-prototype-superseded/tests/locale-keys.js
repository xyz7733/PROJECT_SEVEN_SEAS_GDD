/*
 * Enumerates every localization key the game can ask for: literal keys found
 * in the source plus the key families generated from content and world data.
 * Used by the locale parity test and by the smoke test's coverage report.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const Content = require('../src/content.js');
const World = require('../src/world.js');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src');

// Namespaces that belong to the locale tables. Literals in other namespaces
// (CSS selectors such as 'div.row', storage keys such as 'p7s.settings') are
// not localization keys.
const NS = new Set(['app', 'battle', 'blueprint', 'codex', 'confirm', 'contract', 'crew', 'err', 'fac', 'home', 'item', 'know',
  'lang', 'legend', 'loc', 'log', 'map', 'nav', 'obj', 'pet', 'petrole', 'pets', 'port', 'route', 'save', 'sea', 'ship', 'site',
  'skill', 'stat', 'status', 'system', 'title', 'ui', 'warn', 'where', 'main', 'voyage', 'stamina']);
// Literals that look like keys but are transaction kinds, classes, or prefixes.
const NOT_KEYS = new Set(['stamina.mini', 'stamina.ration', 'stamina.supply', 'main.deliver', 'pet.assign', 'pet.evolve', 'pet.hatch',
  'pet.rename', 'voyage.depart', 'voyage.event', 'voyage.fast', 'voyage.return']);

function sourceFiles() {
  return fs.readdirSync(SRC).filter(f => f.endsWith('.js')).map(f => path.join(SRC, f));
}

function txKinds() {
  const kinds = new Set();
  const s = fs.readFileSync(path.join(SRC, 'actions.js'), 'utf8');
  for (const m of s.matchAll(/run\(\s*(?:state|s|d)\s*,\s*'([a-z_]+\.[a-z_.]+)'/g)) kinds.add(m[1]);
  return kinds;
}

function staticKeys() {
  const out = new Set();
  const kinds = txKinds();
  const counts = new Map();
  const runUses = new Map();
  for (const f of sourceFiles()) {
    const s = fs.readFileSync(f, 'utf8');
    for (const m of s.matchAll(/'([a-z][a-zA-Z0-9_]*\.[a-zA-Z0-9_.]*[a-zA-Z0-9])'(\s*\+)?/g)) {
      const k = m[1];
      if (m[2]) continue; // a prefix such as 'battle.ev_' + kind
      if (!NS.has(k.split('.')[0])) continue;
      if (/\.(js|json|css|html|png)$/.test(k)) continue;
      counts.set(k, (counts.get(k) || 0) + 1);
    }
    for (const m of s.matchAll(/run\(\s*(?:state|s|d)\s*,\s*'([^']+)'/g)) runUses.set(m[1], (runUses.get(m[1]) || 0) + 1);
  }
  for (const [k, n] of counts) {
    if (NOT_KEYS.has(k)) continue;
    // A transaction kind is only a display key if it is also used elsewhere.
    if (kinds.has(k) && n <= (runUses.get(k) || 0)) continue;
    out.add(k);
  }
  return out;
}

function dataKeys() {
  const C = Content, W = World;
  const out = new Set();
  const add = k => out.add(k);
  const each = (list, fn) => (Array.isArray(list) ? list.map(x => (x && typeof x === 'object' ? x.id : x)) : Object.keys(list)).forEach(fn);

  each(C.CLASSES, id => { add('class.' + id + '.name'); add('class.' + id + '.desc'); });
  each(C.SKILLS, id => add('skill.' + id + '.name'));
  each(C.PASSIVES, id => add('passive.' + id + '.name'));
  each(C.FACILITIES, id => { add('fac.' + id + '.name'); add('fac.' + id + '.desc'); });
  each(C.FACILITY_CATEGORIES, id => add('faccat.' + id));
  for (const hl of C.HULLS) { add('hull.' + hl.id + '.name'); add('hull.' + hl.id + '.desc'); }
  for (const r of W.REGIONS) {
    add('region.' + r.id + '.name'); add('region.' + r.id + '.desc'); add('arc.' + r.id + '.title');
    for (let i = 0; i < W.MAIN_TEMPLATE.length; i++) add('arc.' + r.id + '.' + i);
    if (r.mechanic) add('mechanic.' + r.mechanic + '.name');
    add('clue.pet.' + r.petFamilyId);
  }
  each(C.HAZARDS, id => add('hazard.' + id + '.name'));
  each(C.ORIGINS, id => add('origin.' + id));
  each(C.TRAITS, id => add('trait.' + id));
  each(C.CREW_EVENTS, id => { add('event.' + id + '.title'); add('event.' + id + '.desc'); });
  each(C.APTITUDES, id => add('apt.' + id + '.name'));
  each(C.SPECIALTIES, id => add('spec.' + id + '.name'));
  each(C.INGREDIENTS, id => add('ing.' + id + '.name'));
  each(C.AFFIXES, id => add('affix.' + id + '.name'));
  each(C.WEAPON_TYPES, id => add('wtype.' + id));
  let maxTier = 0;
  const slots = new Set();
  for (const it of Object.values(C.ITEMS)) {
    if (it.nameKey) add(it.nameKey);
    if (it.otype) add('otype.' + it.otype);
    if (it.tier > maxTier) maxTier = it.tier;
    slots.add(it.slot);
  }
  for (let i = 1; i <= maxTier; i++) add('itemtier.' + i);
  for (const s of slots) add('slot.' + s);
  each(C.ROLES, id => add('role.' + id));
  each(C.FORMATION_LANES, id => { add('lane.' + id); add('lane.' + id + '.desc'); });
  each(C.LOCATION_TYPES, id => { add('loctype.' + id); add('loctype.' + id + '.desc'); });
  each(C.KNOWLEDGE_STATES, id => add('know.' + id));
  each(C.SKILL_CATS, id => add('cat.' + id));
  ['melee', 'ranged'].forEach(id => add('range.' + id));
  each(C.ENEMY_ARCHETYPES, id => add('archetype.' + id));
  each(C.PET_ABILITIES, id => add('petability.' + id));
  each(C.PET_FAMILIES, id => add('petfam.' + id + '.name'));
  for (const r of C.PET_ROLES) { add('petform.' + r); add('petform.' + r + '_evo'); add('petrole.' + r); add('petrole.' + r + '.desc'); }
  each(C.COLOR_TAGS, id => add('color.' + id));
  for (const list of Object.values(W.ROOM_TEMPLATES)) for (const rm of list) { add('room.' + rm.id + '.name'); add('roomkind.' + rm.kind); add('reward.family.' + rm.family); }
  for (const lg of Object.values(W.LEGENDS)) add('legend.restriction.' + lg.restriction);
  for (const sq of W.SIDE_TEMPLATE) { add('reward.kind.' + sq.reward); add('side.' + sq.id + '.title'); add('side.' + sq.id + '.desc'); add('qtype.' + sq.type); }
  for (const st of W.MAIN_TEMPLATE) add('qtype.' + st.type);
  for (const c of W.CONTRACT_TYPES) { add('contract.' + c); add('contract.' + c + '.title'); }
  each(C.FACTIONS, id => add('faction.' + id + '.name'));
  for (let i = 0; i <= 3; i++) add('rank.' + i);
  for (const tr of C.INVESTMENT_TRACKS) { add('track.' + tr + '.name'); add('track.' + tr + '.desc'); for (let n = 1; n <= 3; n++) add('track.' + tr + '.l' + n); }
  for (const k of ['meal', 'treatment', 'repair']) { add('aid.' + k); add('aid.' + k + '.desc'); }
  for (const id of W.allEnemyIds()) add('enemy.' + id + '.name');
  each(W.LOCATIONS, id => add('loc.' + id + '.name'));
  for (const k of W.SEA_EVENT_KINDS) { add('sea.' + k + '.title'); add('sea.' + k + '.desc'); add('sea.' + k + '.effect'); }
  for (const s of C.STANCES) { add('stance.' + s + '.name'); add('stance.' + s + '.desc'); }
  for (const p of C.PRIORITIES) { add('priority.' + p + '.name'); add('priority.' + p + '.desc'); }
  for (const k of ['stun', 'slow', 'mark', 'taunt', 'evade', 'shield', 'buffAtk', 'buffDef', 'regen', 'dot', 'sunder']) add('status.' + k);
  for (const k of ['gold', 'food', 'supplies', 'materials', 'stamina']) add('status.' + k);

  // Modifier, effect, and property descriptions.
  const mods = new Set();
  const addMods = o => { for (const k of Object.keys(o || {})) mods.add(k); };
  Object.values(C.PASSIVES).forEach(addMods);
  Object.values(C.APTITUDES).forEach(addMods);
  Object.values(C.AFFIXES).forEach(addMods);
  Object.values(C.ITEMS).forEach(it => addMods(it.mods));
  for (const k of mods) add('mod.' + k);
  const props = new Set();
  Object.values(C.ITEMS).forEach(it => (it.props || []).forEach(p => props.add(p)));
  Object.values(C.WEAPON_TYPES).forEach(w => (w.props || []).forEach(p => props.add(p)));
  for (const p of props) add('prop.' + p);
  const fxs = [Object.values(C.SKILLS).map(s => s.fx), Object.values(C.PET_ABILITIES).map(a => a.fx)].flat();
  for (const fx of fxs) for (const k of Object.keys(fx || {})) if (!/(Dur|Stun)$/.test(k)) add('fx.' + k);
  for (const s of Object.values(C.SKILLS)) { add('scope.' + s.scope); add('cat.' + s.cat); if (s.cond) add('skill.cond_' + s.cond); }

  // Composite UI families built from prefixes in the source.
  for (const k of ['hp', 'atk', 'def', 'spd']) { add('stat.' + k); add('stat.' + k + '_short'); }
  for (const k of ['focus', 'stance', 'priority', 'retreat']) add('battle.ev_command_' + k);
  for (const k of ['victory', 'defeat', 'retreat']) add('battle.ev_end_' + k);
  for (const k of ['victory', 'defeat', 'defeat_timeout', 'retreat']) add('battle.outcome_' + k);
  for (const k of ['locations', 'enemies', 'classes', 'pets', 'items', 'clues']) add('codex.tab_' + k);
  for (const k of ['invest', 'market', 'tavern', 'workshop', 'board', 'services']) add('port.tab_' + k);
  for (const k of ['locked', 'open', 'won']) add('obj.trial_' + k);
  for (const k of ['enemy', 'owner', 'allies']) add('pets.target_' + k);
  for (const k of ['hull', 'mast', 'bulkhead']) add('ship.fixed_' + k);
  for (const k of ['home', 'ship', 'map', 'crew', 'port', 'pets', 'codex', 'system']) add('nav.' + k);
  for (const k of ['high', 'mid', 'low']) add('odds.' + k);
  for (const k of ['item.set_format', 'pet.species_format']) add(k);
  return out;
}

function requiredKeys() {
  const all = new Set([...staticKeys(), ...dataKeys()]);
  return [...all].sort();
}

function placeholders(str) {
  return [...String(str).matchAll(/\{([a-zA-Z0-9_]+)\}/g)].map(m => m[1]).sort();
}

module.exports = { requiredKeys, staticKeys, dataKeys, placeholders, txKinds };

if (require.main === module) {
  const keys = requiredKeys();
  if (process.argv[2] === '--missing') {
    global.P7S = global.P7S || {};
    const code = process.argv[3] || 'en';
    const L = require('../locales/' + code + '.js');
    const miss = keys.filter(k => !Object.prototype.hasOwnProperty.call(L.strings, k));
    console.log(miss.join('\n'));
    console.error(miss.length + ' missing of ' + keys.length);
  } else console.log(keys.join('\n'));
}
