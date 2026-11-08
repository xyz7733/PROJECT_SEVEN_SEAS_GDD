'use strict';
// Gate 5: ordered egg inputs give authored, deterministic outcomes recorded in
// the Codex; pets work in battle, aboard ship, or exploring; evolution persists.
const test = require('node:test');
const { assert, Content, State, Rules, Actions, newGame, act, grant, sail, calmSeed } = require('./helpers.js');

const RBB = ['ing:fire_pepper', 'ing:sea_pearl', 'ing:sea_pearl'];
const BRB = ['ing:sea_pearl', 'ing:fire_pepper', 'ing:sea_pearl'];

function voyagerLab(seed, res) {
  let s = State.clone(grant(newGame(seed), res));
  const hull = Content.hull('voyager');
  s.ship.hullId = hull.id; s.ship.hullTier = hull.tier;
  s.ship.decks = hull.decks.map((hd, i) => State.makeDeck(hd, i));
  s = act(s, 'buildFacility', 'hatchery', 0, 7, 2, 0);
  s = act(s, 'buildFacility', 'pet_lab', 0, 9, 1, 0);
  return s;
}
function withHatchery(seed) {
  let s = grant(newGame(seed), { gold: 400, materials: 60, ingredients: { sea_pearl: 4, fire_pepper: 2, dusk_ink: 3, salt_crystal: 2, kelp_sprig: 2 } });
  s = act(s, 'buildFacility', 'hatchery', 0, 7, 2, 0);
  return s;
}

test('every family has three distinct role signatures and authored species', () => {
  assert.equal(Content.PET_FAMILIES.length, 10);
  for (const fam of Content.PET_FAMILIES) {
    for (const role of Content.PET_ROLES) {
      assert.equal(fam.sig[role].length, 3);
      assert.equal(Content.ROLE_BY_COLOR[fam.sig[role][0]], role, fam.id + ' ' + role + ' signature starts with a ' + role + ' colour');
      const sp = Content.PET_SPECIES[fam.id + '_' + role];
      assert.ok(sp && sp.evolvesTo && Content.PET_SPECIES[sp.evolvesTo], fam.id + '_' + role);
    }
    assert.ok(Content.PET_ABILITIES[fam.ability]);
  }
});

test('hatching is deterministic, order-sensitive, and consumes the inputs', () => {
  const egg = { id: 'egg-x', familyId: 'tidefin', grade: 1 };
  const a = Rules.hatchOutcome(egg, RBB);
  assert.deepEqual(a, Rules.hatchOutcome(egg, RBB.slice()));
  assert.equal(a.role, 'companion');
  assert.equal(a.prime, true, 'R,B,B is the tidefin companion signature');
  const b = Rules.hatchOutcome(egg, BRB);
  assert.equal(b.role, 'helper', 'the first colour decides the role');
  assert.equal(b.prime, false);
  assert.equal(Rules.hatchOutcome({ familyId: 'tidefin', grade: 2 }, RBB).level, 3, 'better eggs hatch stronger');

  let s = newGame(31);
  const egg0 = s.inventory.eggs[0];
  assert.equal(Actions.hatchEgg(s, egg0.id, RBB).reasonKey, 'err.need_facility');
  s = withHatchery(31);
  const pearls = s.inventory.ingredients.sea_pearl;
  const r = Actions.hatchEgg(s, egg0.id, RBB);
  assert.ok(r.ok, r.reasonKey);
  const t = r.state;
  const pet = t.pets[0];
  assert.equal(pet.speciesId, 'tidefin_companion');
  assert.equal(pet.prime, true);
  assert.equal(t.inventory.ingredients.sea_pearl, pearls - 2);
  assert.equal(t.inventory.eggs.length, s.inventory.eggs.length - 1);
  assert.deepEqual(t.codex.hatchLog[0], { familyId: 'tidefin', colors: ['red', 'blue', 'blue'], speciesId: 'tidefin_companion', prime: true });
  assert.ok(t.codex.pets.tidefin_companion.prime);
  // Missing inputs fail without consuming anything.
  const poor = State.clone(s); poor.inventory.ingredients.sea_pearl = 1;
  const no = Actions.hatchEgg(poor, egg0.id, RBB);
  assert.equal(no.reasonKey, 'err.no_input');
  assert.equal(no.state, poor);
  assert.equal(Actions.hatchEgg(s, egg0.id, []).reasonKey, 'err.hatch_inputs');
});

test('companions fight beside their owner; helpers staff facilities; explorers open secrets', () => {
  let s = voyagerLab(32, { gold: 900, materials: 200, specialties: { saltleaf_grain: 5 }, ingredients: { sea_pearl: 4, fire_pepper: 2, dusk_ink: 3, salt_crystal: 2, kelp_sprig: 2 } });
  assert.equal(Rules.petCapacity(s), 4, 'the pet lab adds room for two more pets');
  s = State.clone(s);
  s.inventory.eggs.push({ id: 'egg-h', familyId: 'tidefin', grade: 1 }, { id: 'egg-e', familyId: 'tidefin', grade: 1 });
  s = act(s, 'hatchEgg', s.inventory.eggs[0].id, RBB);
  s = act(s, 'hatchEgg', 'egg-h', ['ing:sea_pearl', 'ing:kelp_sprig']);
  s = act(s, 'hatchEgg', 'egg-e', ['ing:dusk_ink', 'ing:salt_crystal']);
  const [comp, helper, explorer] = s.pets;
  assert.deepEqual([comp.role, helper.role, explorer.role], ['companion', 'helper', 'explorer']);

  const owner = s.formation[0];
  assert.equal(Actions.assignPet(s, comp.id, 'companion', 'crew-9999').reasonKey, 'err.pet_owner');
  assert.equal(Actions.assignPet(s, helper.id, 'companion', owner).reasonKey, 'err.pet_role');
  s = act(s, 'assignPet', comp.id, 'companion', owner);
  const allies = Actions.buildAllies(s);
  assert.equal(allies.find(a => a.key === owner).pet.petId, comp.id);

  // Find any free cell that keeps the layout valid for the galley.
  let galleyState = null;
  for (let y = 0; y < 4 && !galleyState; y++) for (let x = 0; x < 12 && !galleyState; x++) {
    const r = Actions.buildFacility(grant(s, { gold: 200, materials: 40 }), 'galley', 0, x, y, 0);
    if (r.ok && !Rules.layoutOf(r.state).disabled.length) galleyState = r.state;
  }
  assert.ok(galleyState, 'a galley fits');
  const galley = galleyState.ship.facilities.find(f => f.id === 'galley');
  const m0 = Rules.staffMult(galleyState, 'galley');
  const staffed = act(galleyState, 'assignPet', helper.id, 'helper', galley.uid);
  assert.ok(Rules.staffMult(staffed, 'galley') > m0, 'a helper pet raises production');

  const seed = calmSeed('gull_rock');
  let v = State.clone(s);
  v.envelope.rng = newGame(seed).envelope.rng;
  v = sail(v, 'gull_rock');
  assert.equal(v.world.currentLocationId, 'gull_rock');
  {
    v = act(v, 'setTactics', 'defensive', null);
    v = act(v, 'enterRoom', 'landing'); v = act(v, 'resolveEncounter', v.encounter.attemptId, []);
    v = act(v, 'enterRoom', 'grove');
    assert.equal(Actions.enterRoom(v, 'hollow').reasonKey, 'err.need_explorer');
    v = act(v, 'assignPet', explorer.id, 'explorer');
    const st = v.ship.stamina;
    v = act(v, 'enterRoom', 'hollow');
    assert.ok(v.world.locations.gull_rock.rooms.includes('hollow'));
    assert.ok(v.ship.stamina < st);
  }
  // Leaving the formation unassigns a companion.
  const moved = act(s, 'setFormation', 0, null);
  assert.equal(moved.pets.find(p => p.id === comp.id).assignment, null);
});

test('evolution needs a pet lab, level, and specialty; it survives save and reload', () => {
  let s = grant(newGame(33), { gold: 3000, materials: 300, specialties: { saltleaf_grain: 10 }, ingredients: { sea_pearl: 2 } });
  s = act(s, 'buildFacility', 'hatchery', 0, 7, 2, 0);
  s = act(s, 'hatchEgg', s.inventory.eggs[0].id, RBB);
  const pet = s.pets[0];
  assert.equal(Actions.evolvePet(s, pet.id).reasonKey, 'err.need_facility');
  s = State.clone(s);
  const hull = Content.hull('voyager');
  s.ship.hullId = hull.id; s.ship.hullTier = hull.tier;
  s.ship.decks = hull.decks.map((hd, i) => State.makeDeck(hd, i));
  s = act(s, 'buildFacility', 'pet_lab', 0, 9, 1, 0);
  assert.equal(Actions.evolvePet(s, pet.id).reasonKey, 'err.pet_level');
  s = State.clone(s); s.pets[0].level = Rules.petLevelNeeded(s.pets[0]);
  assert.equal(Rules.petLevelNeeded(s.pets[0]), 4, 'prime pets evolve a level early');
  const cost = Rules.evolveCost(s.pets[0]);
  const r = Actions.evolvePet(s, pet.id);
  assert.ok(r.ok, r.reasonKey);
  const t = r.state;
  assert.equal(t.pets[0].evolved, true);
  assert.equal(t.pets[0].speciesId, 'tidefin_companion_evo');
  assert.equal(t.inventory.specialties.saltleaf_grain, s.inventory.specialties.saltleaf_grain - cost.specialty[1]);
  assert.ok(Rules.petRoles(t.pets[0]).length === 2, 'evolved pets gain a second role');
  assert.ok(t.codex.pets.tidefin_companion_evo);
  assert.equal(Actions.evolvePet(t, pet.id).reasonKey, 'err.already_evolved');
  const back = State.unpack(JSON.stringify(State.pack(t))).state;
  assert.deepEqual(back.pets, t.pets);
  assert.ok(Rules.petPowerMult(back.pets[0]) > Rules.petPowerMult(s.pets[0]));
});
