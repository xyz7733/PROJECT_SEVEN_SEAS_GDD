#!/usr/bin/env node
/*
 * Development-only converter. It reads the archived browser prototype's
 * content, world, and locale tables and writes plain data files for the
 * native Godot project:
 *
 *   game/data/content.json         classes, skills, items, facilities, pets, tuning
 *   game/data/world.json           regions, locations, routes, ports, quests
 *   game/i18n/source/base_en.json  base string table (English)
 *   game/i18n/source/base_zh_CN.json
 *   game/i18n/names.json           locale name pools for crew identities
 *
 * The delivered game never runs JavaScript; this script exists only so the
 * confirmed mechanics data is carried over without retyping it.
 * Usage: node tools/data_export/export_data.js
 */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const REF = path.join(ROOT, 'archive', 'web-prototype-superseded');
const OUT = path.join(ROOT, 'game');

const Content = require(path.join(REF, 'src', 'content.js'));
const World = require(path.join(REF, 'src', 'world.js'));
const EN = require(path.join(REF, 'locales', 'en.js'));
const ZH = require(path.join(REF, 'locales', 'zh-CN.js'));

// Native ship hulls: decks are stepped terraces along the ship's length.
// x0 = offset along the keel (cells), elev = terrace height in levels.
// Deck index 0 is always the main deck with the gangway entry.
function deck(id, w, h, x0, elev, extra) {
  return Object.assign({ id, w, h, x0, elev, fixed: [], bulkhead: null, entry: null }, extra || {});
}
const SHIP_HULLS = [
  { id: 'starter', tier: 1, beam: 6, cost: null, unlockRegion: 1, decks: [
    deck('main', 11, 6, 0, 0, { fixed: [[5, 3, 'mast'], [0, 3, 'helm']], entry: [6, 0] })
  ] },
  { id: 'voyager', tier: 2, beam: 6, cost: { gold: 500, materials: 50, specialty: ['ember_ore', 3] }, unlockRegion: 2, decks: [
    deck('main', 11, 6, 6, 0, { fixed: [[5, 3, 'mast']], entry: [6, 0] }),
    deck('quarter', 6, 6, 0, 1, { fixed: [[1, 3, 'helm']] })
  ] },
  { id: 'adventurer', tier: 3, beam: 7, cost: { gold: 1500, materials: 120, specialty: ['prism_quartz', 4] }, unlockRegion: 4, decks: [
    deck('main', 12, 7, 7, 0, { fixed: [[5, 3, 'mast']], entry: [6, 0], bulkhead: 9 }),
    deck('quarter', 7, 7, 0, 1, { fixed: [[1, 3, 'helm']] }),
    deck('fore', 5, 7, 19, 1, { fixed: [[2, 3, 'foremast']] })
  ] },
  { id: 'legend', tier: 4, beam: 8, cost: { gold: 3200, materials: 220, specialty: ['leviathan_scale', 5] }, unlockRegion: 9, blueprint: 'legend_keel', decks: [
    deck('main', 14, 8, 14, 0, { fixed: [[6, 4, 'mast']], entry: [7, 0], bulkhead: 10 }),
    deck('quarter', 8, 8, 6, 1, { fixed: [[1, 4, 'helm'], [5, 4, 'mizzen']] }),
    deck('fore', 6, 8, 28, 1, { fixed: [[2, 4, 'foremast']] }),
    deck('poop', 6, 8, 0, 2, { fixed: [] })
  ] }
];

const content = {};
for (const [k, v] of Object.entries(Content)) {
  if (typeof v === 'function') continue;
  content[k] = v;
}
content.HULLS = SHIP_HULLS;

const world = {};
for (const k of ['SLOT_TYPES', 'REGIONS', 'RIVALS', 'FACTION_LEADERS', 'LEGENDS', 'ROOM_TEMPLATES', 'MAIN_TEMPLATE', 'SIDE_TEMPLATE',
  'CONTRACT_TYPES', 'SEA_EVENT_KINDS', 'SEA_EVENT_CHANCE', 'LOCATIONS', 'ROUTES', 'PORTS', 'QUESTS', 'UNIQUE_BY_REGION']) {
  world[k] = World[k];
}
world.GROUPS = {
  battle: [['skirmisher', 'skirmisher', 'shooter'], ['brute', 'skirmisher', 'caster'], ['skirmisher', 'shooter', 'healer'], ['brute', 'shooter', 'shooter']],
  elite: [['brute', 'skirmisher', 'shooter', 'healer'], ['brute', 'brute', 'caster', 'shooter'], ['skirmisher', 'skirmisher', 'caster', 'healer']],
  boss: [['boss', 'skirmisher', 'healer'], ['boss', 'brute', 'shooter']]
};

function write(rel, obj) {
  const file = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(obj, null, 1) + '\n');
  console.log('wrote', rel, fs.statSync(file).size, 'bytes');
}
write('data/content.json', content);
write('data/world.json', world);
write('i18n/source/base_en.json', EN.strings);
write('i18n/source/base_zh_CN.json', ZH.strings);
write('i18n/names.json', { en: EN.names, zh_CN: ZH.names });
