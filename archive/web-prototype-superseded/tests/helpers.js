'use strict';
// Shared helpers for the Node test suites. Everything goes through the same
// public modules the browser uses; tests only reach into state directly to
// set up a scenario (for example granting materials), never to fake a result.
const assert = require('node:assert/strict');
const Content = require('../src/content.js');
const World = require('../src/world.js');
const State = require('../src/state.js');
const Rules = require('../src/rules.js');
const Actions = require('../src/actions.js');
const Combat = require('../src/combat.js');
const I18n = require('../src/i18n.js');

function ok(r, label) {
  assert.ok(r && r.ok, (label || 'action') + ' failed: ' + (r && r.reasonKey) + (r && r.error ? '\n' + r.error : ''));
  return r.state;
}
function act(s, name, ...args) { return ok(Actions[name](s, ...args), name); }
function newGame(seed) { return State.createNewGame(seed == null ? 1234 : seed); }

// Give a test state extra resources for setup.
function grant(s, res) {
  const d = State.clone(s);
  for (const k of ['gold', 'materials', 'food', 'supplies']) if (res[k]) d.inventory[k] += res[k];
  if (res.specialties) for (const [id, n] of Object.entries(res.specialties)) d.inventory.specialties[id] = (d.inventory.specialties[id] || 0) + n;
  if (res.ingredients) for (const [id, n] of Object.entries(res.ingredients)) d.inventory.ingredients[id] = (d.inventory.ingredients[id] || 0) + n;
  if (res.stamina != null) d.ship.stamina = res.stamina;
  return d;
}

// Settle whatever happened after a departure: sea events take the passive
// choice and sea battles are fought with no commands.
function settle(s) {
  for (let i = 0; i < 6; i++) {
    if (s.voyage && s.voyage.event) { s = act(s, 'resolveSeaEvent', s.voyage.event.kind === 'vessel' ? 'ignore' : s.voyage.event.kind === 'inspection' ? 'refuse' : 'take'); continue; }
    if (s.encounter && s.encounter.context.type === 'sea') { s = act(s, 'resolveEncounter', s.encounter.attemptId, []); continue; }
    break;
  }
  return s;
}
function sail(s, toId, opts) { return settle(act(s, 'depart', toId, Object.assign({ confirmed: true }, opts || {}))); }

// Find a seed whose first departure to `toId` has no sea event, so a test
// can reason about exact food and stamina numbers.
function calmSeed(toId, from) {
  for (let seed = from || 1; seed < 500; seed++) {
    const s = newGame(seed);
    const r = Actions.depart(s, toId, { confirmed: true });
    if (r.ok && r.value && r.value.arrived === toId) return seed;
  }
  throw new Error('no calm seed');
}

module.exports = { assert, Content, World, State, Rules, Actions, Combat, I18n, ok, act, newGame, grant, settle, sail, calmSeed };
