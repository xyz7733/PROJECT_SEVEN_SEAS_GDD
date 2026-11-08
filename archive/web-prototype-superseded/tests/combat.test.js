'use strict';
// Gate 6: one shared deterministic auto-combat engine. The pause menu sends
// focus, priority, stance, and retreat commands; each has an observable effect.
const test = require('node:test');
const { assert, State, Actions, Combat, newGame, act, sail, calmSeed } = require('./helpers.js');

function roomEncounter(seed) {
  let s = sail(newGame(seed == null ? calmSeed('gull_rock') : seed), 'gull_rock');
  s = act(s, 'enterRoom', 'landing');
  return s;
}
function hardSpec(base, over) {
  return Object.assign({}, base, {
    waves: [[{ enemyId: 'reef_crab', level: 4 }, { enemyId: 'gull_raider', level: 4 }, { enemyId: 'brine_witch', level: 4 }]]
  }, over || {});
}

test('the same spec and commands always give the same battle', () => {
  const s = roomEncounter();
  const spec = s.encounter.spec;
  const a = Combat.resolve(spec, []);
  const b = Combat.resolve(State.clone(spec), []);
  assert.deepEqual(a, b);
  assert.ok(['victory', 'defeat', 'retreat', 'timeout'].includes(a.outcome) || a.outcome);
  const other = Combat.resolve(Object.assign({}, spec, { seed: spec.seed + 1 }), []);
  assert.notDeepEqual(other.dealt, a.dealt, 'a different seed is a different fight');
});

test('live stepping with paused commands replays exactly from the recorded list', () => {
  const s = roomEncounter();
  const spec = hardSpec(s.encounter.spec);
  const sim = Combat.create(spec);
  while (!sim.outcome) {
    if (sim.tick === 15) Combat.issue(sim, 'stance', 'defensive');
    if (sim.tick === 30) Combat.issue(sim, 'focus', sim.enemies[sim.enemies.length - 1].uid);
    if (sim.tick === 45) Combat.issue(sim, 'priority', 'survival');
    Combat.step(sim);
  }
  assert.equal(sim.commands.length, 3);
  assert.deepEqual(Combat.result(sim), Combat.resolve(spec, sim.commands));
  assert.equal(Combat.issue(sim, 'stance', 'aggressive'), false, 'no commands after the end');
});

test('retreat ends the battle with a retreat outcome; escape stance retreats faster', () => {
  const spec = hardSpec(roomEncounter().encounter.spec);
  const r = Combat.resolve(spec, [{ tick: 10, type: 'retreat', value: null }]);
  assert.equal(r.outcome, 'retreat');
  assert.ok(Math.abs(r.time - (1 + spec.retreatSecs)) < 0.21, 'retreat takes retreatSecs: ' + r.time);
  const fast = Combat.resolve(spec, [{ tick: 10, type: 'stance', value: 'escape' }, { tick: 10, type: 'retreat', value: null }]);
  assert.equal(fast.outcome, 'retreat');
  assert.ok(fast.time < r.time);
});

test('stance, focus, and priority each change the outcome of the same fight', () => {
  const spec = hardSpec(roomEncounter().encounter.spec);
  const base = Combat.resolve(spec, []);
  const aggressive = Combat.resolve(spec, [{ tick: 0, type: 'stance', value: 'aggressive' }]);
  const defensive = Combat.resolve(spec, [{ tick: 0, type: 'stance', value: 'defensive' }]);
  const sum = o => Object.values(o).reduce((a, b) => a + b, 0);
  assert.notDeepEqual(aggressive, base);
  assert.notDeepEqual(defensive, base);
  assert.ok(sum(aggressive.dealt) / aggressive.time > sum(defensive.dealt) / defensive.time, 'aggressive deals damage faster');

  const sim = Combat.create(spec);
  const last = sim.enemies[sim.enemies.length - 1].uid;
  const focused = Combat.resolve(spec, [{ tick: 0, type: 'focus', value: last }]);
  assert.notDeepEqual(focused, base);
  const firstDown = res => res.enemiesDefeated[0];
  assert.equal(firstDown(focused), sim.enemies[sim.enemies.length - 1].key, 'the focused enemy falls first');

  const support = Combat.resolve(spec, [{ tick: 0, type: 'priority', value: 'survival' }]);
  const damage = Combat.resolve(spec, [{ tick: 0, type: 'priority', value: 'damage' }]);
  assert.notDeepEqual(support, damage);
});

test('a companion pet joins the fight and changes the result', () => {
  const s = roomEncounter();
  const spec = hardSpec(s.encounter.spec, { waves: [[{ enemyId: 'reef_crab', level: 2 }, { enemyId: 'gull_raider', level: 2 }, { enemyId: 'brine_witch', level: 2 }]] });
  const pet = { petId: 'pet-x', speciesId: 'tidefin_companion', familyId: 'tidefin', ability: require('../src/content.js').petFamily('tidefin').ability, evolved: false, mult: 1 };
  const withPet = Object.assign({}, spec, { allies: spec.allies.map((a, i) => (i === 0 ? Object.assign({}, a, { pet }) : a)) });
  const r0 = Combat.resolve(spec, []);
  const r1 = Combat.resolve(withPet, []);
  assert.notDeepEqual(r1, r0);
  const sim = Combat.create(withPet);
  let acted = false;
  while (!sim.outcome) { Combat.step(sim); if (sim.log.some(e => e.type === 'pet')) acted = true; }
  assert.ok(acted, 'the pet acts during the fight');
  assert.ok(r1.dealt[spec.allies[0].key] > r0.dealt[spec.allies[0].key], 'pet damage counts for its owner');
});

test('resolveEncounter applies results once and ignores invalid commands', () => {
  const s = roomEncounter();
  const id = s.encounter.attemptId;
  const r = Actions.resolveEncounter(s, id, [{ tick: 0, type: 'stance', value: 'aggressive' }, { tick: -3, type: 'retreat' }, { tick: 2, type: 'teleport' }]);
  assert.ok(r.ok);
  const expected = Combat.resolve(s.encounter.spec, [{ tick: 0, type: 'stance', value: 'aggressive' }]);
  assert.equal(r.value.outcome, expected.outcome);
  assert.equal(r.value.time, expected.time, 'invalid commands are dropped, not applied');
  const again = Actions.resolveEncounter(r.state, id, []);
  assert.ok(again.duplicate);
  assert.equal(again.state, r.state, 'a repeat changes nothing');
  assert.equal(r.state.encounter, null);
});
