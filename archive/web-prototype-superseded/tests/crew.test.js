'use strict';
// Gates 3 and 4: generated crew, tavern rotation, six battle slots, jobs,
// 12 base classes with two branches, respec, two legacy passives, and
// equipment slots that change stats and behaviour.
const test = require('node:test');
const { assert, Content, State, Rules, Actions, Combat, newGame, act, grant } = require('./helpers.js');

test('12 base classes, each with two branches, all fully defined', () => {
  assert.equal(Content.BASE_CLASS_IDS.length, 12);
  assert.equal(Object.keys(Content.CLASSES).length, 36);
  for (const id of Content.BASE_CLASS_IDS) {
    const c = Content.CLASSES[id];
    assert.equal(c.tier, 'base');
    assert.equal(c.branches.length, 2, id);
    for (const b of c.branches) {
      assert.equal(Content.CLASSES[b].parent, id);
      assert.notEqual(Content.CLASSES[b].passive, c.passive, b + ' needs its own passive');
    }
  }
  for (const c of Object.values(Content.CLASSES)) {
    assert.ok(c.skills.length >= 2 && c.skills.every(k => Content.SKILLS[k]), c.id + ' skills');
    assert.ok(Content.PASSIVES[c.passive], c.id + ' passive');
    assert.ok(c.weapons.length >= 1 && c.weapons.every(w => Content.WEAPON_TYPES[w]), c.id + ' weapons');
  }
});

test('recruits are generated from stable seeds with origins, traits, and aptitudes', () => {
  const s = newGame(11);
  const a = Rules.tavernPool(s, 'brightquay');
  const b = Rules.tavernPool(State.clone(s), 'brightquay');
  assert.deepEqual(a, b, 'the same day shows the same tavern');
  for (const m of s.crew.concat(a.map(o => o.member))) {
    assert.ok(Content.ORIGINS.includes(m.originId), 'origin ' + m.originId);
    assert.ok(m.traits.length >= 1 && m.aptitudes.length >= 1);
    assert.ok(Number.isInteger(m.seed));
  }
  assert.equal(State.makeRecruit(99, { level: 1 }).seed, State.makeRecruit(99, { level: 1 }).seed);
  assert.deepEqual(State.makeRecruit(99, { level: 1 }), State.makeRecruit(99, { level: 1 }));
});

test('hiring uses the pool, cannot repeat, and the tavern rotates every three days', () => {
  let s = grant(newGame(12), { gold: 1000 });
  const pool = Rules.tavernPool(s, 'brightquay');
  const gold0 = s.inventory.gold;
  s = act(s, 'recruit', 0);
  const hired = s.crew[s.crew.length - 1];
  assert.equal(hired.classId, pool[0].member.classId);
  assert.equal(hired.seed, pool[0].member.seed);
  assert.match(hired.id, /^crew-\d+$/);
  assert.equal(s.inventory.gold, gold0 - pool[0].cost);
  assert.ok(s.formation.includes(hired.id), 'a free battle slot is filled');
  assert.equal(Actions.recruit(s, 0).reasonKey, 'err.already_hired');
  assert.ok(Rules.tavernPool(s, 'brightquay')[0].hired);

  const rot = Rules.rotation(s);
  for (let i = 0; i < 3; i++) s = act(s, 'waitAtPort');
  assert.equal(Rules.rotation(s), rot + 1);
  const next = Rules.tavernPool(s, 'brightquay');
  assert.ok(!next[0].hired);
  assert.notDeepEqual(next.map(o => o.member.seed), pool.map(o => o.member.seed));

  // Capacity comes from reachable quarters.
  s = act(s, 'recruit', 0);
  assert.equal(s.crew.length, Rules.crewCapacity(s));
  assert.equal(Actions.recruit(s, 1).reasonKey, 'err.over_capacity');
});

test('six battle slots map to three lanes; jobs respect facility slots', () => {
  let s = newGame(13);
  assert.equal(s.formation.length, 6);
  assert.deepEqual([0, 1, 2, 3, 4, 5].map(Rules.laneOfSlot), ['front', 'front', 'center', 'center', 'rear', 'rear']);
  const guard = s.crew[0];
  s = act(s, 'setFormation', 3, guard.id);
  assert.equal(s.formation[3], guard.id);
  assert.equal(s.formation[0], null, 'moving a crew member vacates the old slot');
  assert.equal(Rules.memberStats(s, Rules.member(s, guard.id)).lane, 'center');
  const pantry = s.ship.facilities.find(f => f.id === 'pantry');
  assert.equal(Actions.assignJob(s, guard.id, pantry.uid).reasonKey, 'err.no_job_slots');
  s = grant(s, { gold: 200, materials: 30 });
  s = act(s, 'buildFacility', 'chart_table', 0, 7, 2, 0);
  const table = s.ship.facilities.find(f => f.id === 'chart_table');
  s = act(s, 'assignJob', guard.id, table.uid);
  assert.equal(Rules.member(s, guard.id).jobFacilityUid, table.uid);
  assert.equal(Actions.assignJob(s, s.crew[1].id, table.uid).reasonKey, 'err.job_full');
  // A class whose job list includes the facility works at full efficiency.
  const nav = State.clone(s); nav.crew[1].classId = 'navigator';
  assert.ok(Rules.workerEfficiency(nav, nav.crew[1], 'chart_table') > Rules.workerEfficiency(s, s.crew[1], 'chart_table'));
  s = act(s, 'assignJob', guard.id, null);
  assert.equal(Rules.member(s, guard.id).jobFacilityUid, null);
});

test('respec keeps level, mastery, and branch qualification', () => {
  let s = grant(newGame(14), { gold: 2000 });
  const id = s.crew[0].id; // guard
  assert.equal(Actions.changeClass(s, id, 'guardian').reasonKey, 'err.not_qualified');
  s = State.clone(s);
  const m0 = Rules.member(s, id);
  m0.level = 9; m0.mastery.guard = 40;
  assert.ok(Rules.qualifiedFor(m0, 'guardian'));
  const cost = Rules.respecCost(m0).gold;
  assert.equal(cost, Content.TUNING.respecBase + Content.TUNING.respecPerLevel * 9);
  const gold0 = s.inventory.gold;
  s = act(s, 'changeClass', id, 'guardian');
  let m = Rules.member(s, id);
  assert.equal(m.classId, 'guardian');
  assert.equal(m.level, 9);
  assert.equal(m.mastery.guard, 40);
  assert.equal(s.inventory.gold, gold0 - cost);
  assert.equal(Rules.memberStats(s, m).skills.join(), Content.CLASSES.guardian.skills.join(), 'actives follow the current class');

  // Switching to an unrelated base class unequips an incompatible weapon,
  // and coming back to the branch needs no re-qualification.
  s = act(s, 'changeClass', id, 'gunner');
  m = Rules.member(s, id);
  assert.equal(m.equipment.weapon, null);
  assert.ok(Rules.qualifiedFor(m, 'guardian'));
  s = act(s, 'changeClass', id, 'guardian');
  assert.equal(Rules.member(s, id).level, 9);
  assert.equal(Actions.changeClass(s, id, 'guardian').reasonKey, 'err.same_class');
});

test('exactly two legacy passives from mastered classes', () => {
  let s = grant(newGame(15), { gold: 5000 });
  const id = s.crew[0].id;
  s = State.clone(s);
  const m = Rules.member(s, id);
  Object.assign(m.mastery, { guard: 100, duelist: 100, gunner: 100, medic: 40 });
  s = act(s, 'changeClass', id, 'duelist');
  const opts = Rules.legacyOptions(Rules.member(s, id));
  assert.deepEqual(opts.sort(), [Content.CLASSES.guard.passive, Content.CLASSES.gunner.passive].sort(), 'current class and unmastered classes are excluded');
  assert.equal(Actions.setLegacy(s, id, 0, Content.CLASSES.medic.passive).reasonKey, 'err.not_mastered');
  s = act(s, 'setLegacy', id, 0, Content.CLASSES.guard.passive);
  assert.equal(Actions.setLegacy(s, id, 1, Content.CLASSES.guard.passive).reasonKey, 'err.legacy_duplicate');
  s = act(s, 'setLegacy', id, 1, Content.CLASSES.gunner.passive);
  assert.equal(Actions.setLegacy(s, id, 2, Content.CLASSES.gunner.passive).reasonKey, 'err.unknown', 'no third slot');
  const passives = Rules.activePassives(Rules.member(s, id));
  assert.equal(passives.length, 3, 'current passive plus exactly two legacy passives');
  const stats = Rules.memberStats(s, Rules.member(s, id));
  assert.ok(stats.mods.defPct > 0, 'legacy steadfast still applies');
});

test('weapons are class-restricted and change range; outfits and accessories change behaviour', () => {
  let s = grant(newGame(16), { gold: 1000 });
  const guard = s.crew[0];
  const gunInst = s.inventory.equipment.find(e => e.itemId === 'w_gun_1');
  assert.equal(Actions.equip(s, guard.id, 'weapon', gunInst.uid).reasonKey, 'err.weapon_incompatible');
  assert.equal(Actions.equip(s, guard.id, 'outfit', gunInst.uid).reasonKey, 'err.wrong_slot');

  // A navigator fights at range with a gun but steps into melee with a blade.
  s = act(s, 'changeClass', guard.id, 'navigator');
  const blade = s.inventory.equipment.find(e => e.itemId === 'w_blade_1');
  s = act(s, 'equip', guard.id, 'weapon', gunInst.uid);
  assert.equal(Rules.memberStats(s, Rules.member(s, guard.id)).range, 'ranged');
  assert.equal(s.crew.find(m => m.classId === 'gunner').equipment.weapon, null, 'equipment moves rather than duplicates');
  s = act(s, 'equip', guard.id, 'weapon', blade.uid);
  assert.equal(Rules.memberStats(s, Rules.member(s, guard.id)).range, 'melee');

  // Accessory: the escape rope halves the retreat time.
  s = act(s, 'buyItem', 'a_escape_rope');
  const rope = s.inventory.equipment.find(e => e.itemId === 'a_escape_rope');
  const before = Rules.memberStats(s, Rules.member(s, guard.id));
  s = act(s, 'equip', guard.id, 'accessory', rope.uid);
  const after = Rules.memberStats(s, Rules.member(s, guard.id));
  assert.ok(!before.mods.escape && after.mods.escape);

  // Outfit: heat-resistant gear blocks the heat hazard.
  const d = State.clone(s);
  d.inventory.equipment.push({ uid: 'eq-test', itemId: 'o_coat_2', reinforce: 0, affix: null });
  const coated = act(d, 'equip', guard.id, 'outfit', 'eq-test');
  assert.ok(Rules.memberStats(coated, Rules.member(coated, guard.id)).resist.includes('heat'));

  const spec = (st, mods) => ({
    allies: Actions.buildAllies(st), seed: 5, stance: 'balanced', priority: 'auto', bonuses: {}, retreatSecs: 3, modifiers: mods || [],
    waves: [[{ enemyId: 'reef_crab', level: 1 }]]
  });
  const ropeRetreat = Combat.resolve(spec(s), [{ tick: 0, type: 'retreat', value: null }]);
  const noRope = act(s, 'equip', guard.id, 'accessory', null);
  const plainRetreat = Combat.resolve(spec(noRope), [{ tick: 0, type: 'retreat', value: null }]);
  assert.equal(ropeRetreat.outcome, 'retreat');
  assert.ok(ropeRetreat.time < plainRetreat.time, 'rope ' + ropeRetreat.time + ' vs ' + plainRetreat.time);

  const heatHp = st => Combat.run(spec(st, ['heat']), [], 200).allies.find(u => u.key === guard.id).hp;
  const noHeatHp = st => Combat.run(spec(st, []), [], 200).allies.find(u => u.key === guard.id).hp;
  assert.ok(heatHp(s) < noHeatHp(s), 'heat hurts unprotected crew');
  assert.equal(heatHp(coated), noHeatHp(coated), 'the coat cancels heat damage');
});

test('injuries reduce stats and are treatable at port', () => {
  let s = grant(newGame(17), { gold: 500 });
  const d = State.clone(s); d.crew[0].injured = true;
  const hurt = Rules.memberStats(d, d.crew[0]);
  const fine = Rules.memberStats(s, s.crew[0]);
  assert.ok(hurt.atk < fine.atk && hurt.hp < fine.hp);
  const t = act(d, 'treat', d.crew[0].id);
  assert.equal(t.crew[0].injured, false);
  assert.equal(Actions.treat(t, t.crew[0].id).reasonKey, 'err.not_injured');
});
