'use strict';
// Gate 9: food charged once at departure, stamina for optional challenges
// only, restoration only from food and supplies, emergency return and aid at
// zero resources, and soft defeat. Gate 10 (encounter side): reloading never
// rerolls an outcome, duplicates rewards, refills stamina, or banks cargo early.
const test = require('node:test');
const { assert, Content, World, State, Rules, Actions, Combat, newGame, act, grant, sail, calmSeed } = require('./helpers.js');
const T = Content.TUNING;

const atGull = () => sail(newGame(calmSeed('gull_rock')), 'gull_rock');

test('food is charged once at departure; sailing and docking never restore stamina', () => {
  const seed = calmSeed('gull_rock');
  const s = newGame(seed);
  const leg = Rules.legCost(s, 'brightquay', 'gull_rock');
  assert.ok(leg.food >= 1);
  const r = Actions.depart(s, 'gull_rock', { confirmed: true });
  assert.ok(r.ok);
  assert.equal(r.state.inventory.food, s.inventory.food - leg.food);
  assert.equal(r.state.ship.stamina, s.ship.stamina, 'sailing does not change stamina');
  assert.equal(r.state.voyage.route.food, leg.food);
  // Spending stamina at the site, then sailing home, does not refill it.
  let t = act(r.state, 'enterRoom', 'landing');
  t = act(t, 'resolveEncounter', t.encounter.attemptId, []);
  const st = t.ship.stamina;
  const food = t.inventory.food;
  const back = Actions.depart(t, 'brightquay', { confirmed: true });
  assert.ok(back.ok);
  let home = back.state;
  if (home.voyage && home.voyage.event) home = act(home, 'resolveSeaEvent', 'take');
  if (home.encounter) home = act(home, 'resolveEncounter', home.encounter.attemptId, []);
  assert.ok(home.inventory.food <= food - Rules.legCost(t, 'gull_rock', 'brightquay').food + 5);
  if (!home.voyage) {
    assert.ok(home.ship.stamina <= st, 'docking does not refill stamina');
    const waited = act(home, 'waitAtPort');
    assert.equal(waited.ship.stamina, home.ship.stamina, 'waiting does not refill stamina');
  }
  assert.equal(Actions.depart(s, 'tidefin_grotto').reasonKey, Rules.sailBlock(s, 'tidefin_grotto'));
});

test('optional rooms cost stamina; cleared rooms and retreats are free; low stamina blocks entry', () => {
  let s = atGull();
  const landing = World.room('gull_rock', 'landing');
  const st0 = s.ship.stamina;
  s = act(s, 'enterRoom', 'landing');
  assert.equal(s.ship.stamina, st0 - landing.cost);
  // Retreat costs nothing extra and keeps the room uncleared.
  const enc = s.encounter;
  const ret = act(s, 'resolveEncounter', enc.attemptId, [{ tick: 1, type: 'retreat', value: null }]);
  assert.equal(ret.ship.stamina, s.ship.stamina);
  assert.ok(!ret.world.locations.gull_rock.rooms.includes('landing'));
  // Re-entering an uncleared room charges again; a cleared one is free.
  let w = act(ret, 'enterRoom', 'landing');
  w = act(w, 'resolveEncounter', w.encounter.attemptId, []);
  assert.ok(w.world.locations.gull_rock.rooms.includes('landing'));
  const st1 = w.ship.stamina;
  w = act(w, 'enterRoom', 'landing');
  assert.equal(w.ship.stamina, st1, 'walking through a cleared room is free');
  assert.equal(w.encounter, null);
  // A repeat fight is optional, so it costs stamina again.
  const rep = act(w, 'enterRoom', 'landing', { repeat: true });
  assert.equal(rep.ship.stamina, st1 - landing.cost);
  assert.ok(rep.encounter && rep.encounter.context.repeat);
  // With too little stamina the room is refused, not entered.
  const tired = grant(w, { stamina: 2 });
  const no = Actions.enterRoom(tired, 'grove');
  assert.equal(no.reasonKey, 'err.no_stamina');
  assert.equal(no.state, tired);
  assert.equal(Actions.enterRoom(w, 'heart').reasonKey, 'err.room_locked');
});

test('only food rations and supplies restore stamina, capped at the maximum', () => {
  let s = grant(newGame(3), { stamina: 10 });
  const r = Actions.serveRation(s);
  assert.equal(r.value, T.rationStamina);
  assert.equal(r.state.ship.stamina, 10 + T.rationStamina);
  assert.equal(r.state.inventory.food, s.inventory.food - T.rationFood);
  const u = Actions.useSupply(r.state);
  assert.equal(u.state.ship.stamina, 10 + T.rationStamina + T.supplyStamina);
  assert.equal(u.state.inventory.supplies, s.inventory.supplies - 1);
  const full = grant(s, { stamina: T.maxStamina });
  assert.equal(Actions.serveRation(full).reasonKey, 'err.stamina_full');
  const empty = State.clone(s); empty.inventory.food = 0; empty.inventory.supplies = 0;
  assert.equal(Actions.serveRation(empty).ok, false);
  assert.equal(Actions.useSupply(empty).ok, false);
  const near = act(grant(s, { stamina: T.maxStamina - 3 }), 'useSupply');
  assert.equal(near.ship.stamina, T.maxStamina);
});

test('emergency return and basic aid work with zero resources', () => {
  let s = atGull();
  s = State.clone(s);
  Object.assign(s.inventory, { gold: 0, food: 0, supplies: 0, materials: 0 });
  s.inventory.ledger = { gold: 40, materials: 6 };
  s.ship.stamina = 0;
  assert.equal(Actions.enterRoom(s, 'landing').reasonKey, 'err.no_stamina');
  const r = Actions.emergencyReturn(s);
  assert.ok(r.ok);
  let t = r.state;
  assert.equal(t.voyage, null);
  assert.equal(t.world.currentLocationId, 'brightquay');
  assert.equal(t.inventory.gold, 40, 'cargo is banked on a safe return');
  assert.equal(t.inventory.materials, 6);
  assert.equal(t.ship.stamina, 0, 'returning does not refill stamina');
  t = State.clone(t); t.inventory.gold = 0; t.crew[0].injured = true;
  const needs = Rules.emergencyNeeds(t);
  assert.ok(needs.includes('meal') && needs.includes('treatment'));
  t = act(t, 'emergencyAid', 'meal');
  assert.ok(t.inventory.food >= 1 && t.ship.stamina >= 30);
  t = act(t, 'emergencyAid', 'treatment');
  assert.ok(t.crew.every(m => !m.injured));
  assert.equal(Actions.emergencyAid(t, 'meal').reasonKey, 'err.aid_not_needed');
  assert.ok(Actions.depart(t, 'gull_rock', { confirmed: true }).ok, 'the run can continue');
});

test('defeat loses 25% of unbanked cargo, injures at most two, and keeps progress', () => {
  let s = atGull();
  s = State.clone(s);
  s.inventory.ledger = { gold: 101, materials: 41 };
  s.ship.stamina = 80;
  s.crew.forEach(m => { m.level = 1; });
  s.captain.mainStep.dawnwater = 2;
  s = act(s, 'enterRoom', 'landing');
  // Make the fight unwinnable by replacing the waves with much stronger foes.
  s = State.clone(s);
  s.encounter.spec.waves = [[{ enemyId: 'reef_crab', level: 12 }, { enemyId: 'gull_raider', level: 12 }, { enemyId: 'brine_witch', level: 12 }]];
  const banked = s.inventory.gold;
  const foodBefore = s.inventory.food;
  const mastery = s.crew.map(m => JSON.stringify(m.mastery));
  const r = Actions.resolveEncounter(s, s.encounter.attemptId, []);
  assert.ok(r.ok);
  assert.equal(r.value.outcome, 'defeat');
  const t = r.state;
  assert.deepEqual(r.value.losses, { gold: 25, materials: 10, damagedFacility: null });
  assert.equal(t.inventory.gold, banked + 101 - 25, 'remaining cargo is banked at the safe port');
  assert.equal(t.inventory.food, foodBefore, 'food spent on the voyage is not refunded');
  assert.equal(t.world.currentLocationId, t.world.lastSafePortId);
  assert.equal(t.voyage, null);
  const injured = t.crew.filter(m => m.injured);
  assert.ok(injured.length >= 1 && injured.length <= T.maxInjuriesPerDefeat);
  assert.equal(t.captain.mainStep.dawnwater, 2, 'story progress is kept');
  assert.deepEqual(t.crew.map(m => JSON.stringify(m.mastery)), mastery, 'mastery is kept');
  assert.ok(t.world.locations.gull_rock.k !== 'hidden');
  assert.ok(t.ship.damage >= 10);
  // Everything is treatable.
  let u = grant(t, { gold: 500, materials: 50 });
  for (const m of injured) u = act(u, 'treat', m.id);
  u = act(u, 'repairShip');
  assert.ok(u.crew.every(m => !m.injured) && u.ship.damage === 0);
});

test('a suspended encounter survives save and reload without rerolling', () => {
  let s = atGull();
  s = act(s, 'enterRoom', 'landing');
  const store = State.createSaveStore(State.createMemoryStorage());
  assert.ok(store.saveSlot(1, s, 1).ok);
  const first = Actions.resolveEncounter(s, s.encounter.attemptId, [{ tick: 4, type: 'stance', value: 'defensive' }]);
  const loaded = store.loadSlot(1).state;
  assert.deepEqual(loaded.encounter, s.encounter, 'the spec, seed, and attempt id are saved');
  assert.equal(loaded.ship.stamina, s.ship.stamina, 'reloading does not refund the room cost');
  const second = Actions.resolveEncounter(loaded, loaded.encounter.attemptId, [{ tick: 4, type: 'stance', value: 'defensive' }]);
  assert.deepEqual(second.value, first.value, 'same outcome after reload');
  assert.deepEqual(second.state.inventory, first.state.inventory);
  // Reloading after the result cannot apply it twice.
  assert.ok(store.saveSlot(2, first.state, 2).ok);
  const after = store.loadSlot(2).state;
  const dup = Actions.resolveEncounter(after, s.encounter.attemptId, []);
  assert.ok(dup.duplicate);
  assert.deepEqual(dup.state.inventory, first.state.inventory);
  assert.ok(after.committed[s.encounter.attemptId]);
});

test('reloading mid-voyage keeps unbanked cargo in the ledger and the RNG position', () => {
  let s = atGull();
  s = act(s, 'enterRoom', 'landing');
  s = act(s, 'resolveEncounter', s.encounter.attemptId, []);
  assert.ok(s.inventory.ledger.gold > 0, 'battle gold goes to the ledger');
  const packed = JSON.stringify(State.pack(s));
  const back = State.unpack(packed).state;
  assert.deepEqual(back.inventory, s.inventory);
  assert.deepEqual(back.envelope.rng, s.envelope.rng);
  const a = Actions.enterRoom(s, 'ridge');
  const b = Actions.enterRoom(back, 'ridge');
  assert.deepEqual(a.state.encounter.spec, b.state.encounter.spec, 'the next roll is identical after reload');
});

test('a weather-eye navigator lowers the sea event chance; a level-3 workshop discounts crafting', () => {
  const s = newGame(5);
  const base = Rules.seaEventChance(s);
  const nav = State.clone(s); nav.crew[0].classId = 'navigator'; nav.crew[0].equipment.weapon = null;
  assert.ok(Rules.seaEventChance(nav) < base);
  const benched = State.clone(nav); benched.formation = benched.formation.map(x => (x === nav.crew[0].id ? null : x));
  assert.equal(Rules.seaEventChance(benched), base, 'only crew in the battle formation count');
  const w = State.clone(s); w.world.ports.brightquay.tracks.workshop = 3;
  const item = Object.values(Content.ITEMS).find(i => i.recipe);
  assert.ok(Rules.craftCost(item.id, null, w).materials < Rules.craftCost(item.id, null, s).materials);
  const inst = s.inventory.equipment[0];
  assert.ok(Rules.reinforceCost(inst, w).gold < Rules.reinforceCost(inst, s).gold);
});

test('the battle engine and the log never refer to a missing enemy or room', () => {
  for (const id of World.allEnemyIds()) assert.ok(World.enemy(id), id);
  const ids = Object.keys(World.LOCATIONS);
  for (const id of ids) for (const rm of World.rooms(id)) {
    for (const n of rm.next) assert.ok(World.room(id, n), id + ':' + rm.id + ' → ' + n);
    if (['battle', 'elite', 'boss', 'trial'].includes(rm.kind)) {
      const def = World.encounterFor(id, rm.id, { variant: 0 });
      assert.ok(def.waves.length >= 1 && def.waves.every(w => w.length >= 1 && w.every(e => World.enemy(e.enemyId))), id + ':' + rm.id);
    }
  }
  assert.ok(Combat.LIMIT_TICKS > 0);
});
