'use strict';
// Gate 7 and 8: ten regions of 8–12 locations, each with a main arc, captain
// trial, specialty, enemies, rewards, palette, and pet family; knowledge
// states; sailing and fast-travel rules; ports, investment, and main status.
const test = require('node:test');
const { assert, Content, World, State, Rules, Actions, newGame, act, grant, sail, calmSeed } = require('./helpers.js');

test('ten regions with complete identities and 8–12 locations each', () => {
  assert.equal(World.REGIONS.length, 10);
  assert.deepEqual(World.REGIONS.map(r => r.id), Content.REGION_ORDER);
  const specs = new Set(), fams = new Set();
  World.REGIONS.forEach((r, i) => {
    assert.ok(r.locs.length >= 8 && r.locs.length <= 12, r.id + ' has ' + r.locs.length);
    assert.equal(r.order, i + 1);
    assert.ok(r.palette && r.palette.sea && r.palette.land, r.id + ' visuals');
    assert.ok(Content.SPECIALTIES[r.specialtyId], r.id + ' specialty');
    assert.ok(Content.petFamily(r.petFamilyId), r.id + ' pet family');
    specs.add(r.specialtyId); fams.add(r.petFamilyId);
    for (const role of ['skirmisher', 'brute', 'shooter', 'caster', 'healer']) assert.ok(World.enemy(r.enemies[role]), r.id + ' ' + role);
    assert.ok(r.bosses.length >= 1 && r.bosses.every(b => World.enemy(b)));
    assert.ok(World.RIVALS[r.rivalId] || World.enemy(r.rivalId), r.id + ' rival');
    for (let step = 0; step < World.MAIN_TEMPLATE.length; step++) assert.ok(World.mainStep(r.id, step), r.id + ' main step ' + step);
    assert.equal(World.mainStep(r.id, World.MAIN_TEMPLATE.length - 1).type, 'trial');
    assert.equal(World.LOCATIONS[r.locs[8]].type, 'arena', r.id + ' captain trial arena');
    assert.ok(r.locs.some(id => World.PORTS[id]), r.id + ' has a port');
    assert.equal(r.nextRegionId, World.REGIONS[i + 1] ? World.REGIONS[i + 1].id : null);
    assert.ok(World.sideQuests(r.id).length >= 2, r.id + ' side quests');
  });
  assert.equal(specs.size, 10);
  assert.equal(fams.size, 10);
  const legends = Object.keys(World.LEGENDS);
  assert.ok(legends.length >= 5 && legends.every(id => World.region(id)), 'postgame legend trials');
});

test('every location has a connected room graph with an objective and rewards', () => {
  for (const [id, loc] of Object.entries(World.LOCATIONS)) {
    if (loc.type === 'port') continue;
    const rooms = World.rooms(id);
    assert.ok(rooms.length >= 1, id);
    assert.ok(rooms.some(r => r.objective), id + ' objective');
    const seen = new Set([rooms[0].id]);
    const q = [rooms[0]];
    while (q.length) for (const n of q.shift().next) if (!seen.has(n)) { seen.add(n); q.push(World.room(id, n)); }
    assert.equal(seen.size, rooms.length, id + ' has unreachable rooms');
    for (const r of rooms) {
      const rw = World.roomRewards(id, r.id, true);
      assert.ok(rw && (rw.gold > 0 || rw.materials > 0 || rw.specialty > 0 || rw.items.length > 0 || rw.ingredient), id + ':' + r.id + ' rewards');
    }
  }
});

test('locations move Hidden → Revealed → Visited → Cleared', () => {
  const seed = calmSeed('gull_rock');
  let s = newGame(seed);
  assert.deepEqual(Content.KNOWLEDGE_STATES, ['hidden', 'revealed', 'visited', 'cleared']);
  assert.equal(Rules.knowledge(s, 'brightquay'), 'visited');
  assert.equal(Rules.knowledge(s, 'gull_rock'), 'revealed');
  assert.equal(Rules.knowledge(s, 'lantern_isle'), 'hidden');
  assert.equal(Actions.depart(s, 'lantern_isle').reasonKey, 'err.not_revealed');
  assert.equal(Actions.depart(s, 'cinderport').reasonKey, 'err.region_locked');
  s = sail(s, 'gull_rock');
  assert.equal(Rules.knowledge(s, 'gull_rock'), 'visited');
  s = act(s, 'setTactics', 'defensive', null);
  for (const room of ['landing', 'ridge', 'heart']) {
    s = act(s, 'enterRoom', room);
    if (s.encounter) {
      const r = Actions.resolveEncounter(s, s.encounter.attemptId, []);
      assert.equal(r.value.outcome, 'victory', room);
      s = r.state;
    }
  }
  assert.equal(Rules.knowledge(s, 'gull_rock'), 'cleared');
  assert.equal(s.captain.mainStep.dawnwater, 1, 'clearing Gull Rock completes main step 1');
  for (const id of World.mainStep('dawnwater', 0).reveal) assert.equal(Rules.knowledge(s, id), 'revealed');
  // Cleared stays cleared; a cleared site is still a valid destination.
  const st = Rules.mainStatus(s);
  assert.equal(st.step, 1);
  assert.equal(st.quest.type, 'visit');
  assert.equal(st.trialLocationId, 'dawn_trial_ring');
});

test('sail to any revealed location; fast travel only between visited, charted ports', () => {
  let s = grant(newGame(calmSeed('gull_rock')), { food: 40 });
  s = State.clone(s);
  s.world.locations.saltmarsh_landing.k = 'revealed';
  assert.equal(Actions.depart(s, 'saltmarsh_landing', { fast: true }).reasonKey, 'err.fast_not_visited');
  assert.equal(Actions.depart(s, 'gull_rock', { fast: true }).reasonKey, 'err.fast_ports_only');
  s = sail(s, 'saltmarsh_landing');
  if (s.world.currentLocationId !== 'saltmarsh_landing') s = sail(s, 'saltmarsh_landing');
  assert.equal(s.world.currentLocationId, 'saltmarsh_landing');
  assert.equal(s.voyage, null, 'arriving at a port docks');
  assert.ok(s.world.chartedRoutes.includes(Rules.routeKey('brightquay', 'saltmarsh_landing')));
  const fast = Actions.depart(s, 'brightquay', { fast: true, confirmed: true });
  assert.ok(fast.ok, fast.reasonKey);
  assert.equal(fast.state.world.currentLocationId, 'brightquay', 'fast travel has no sea events');
  assert.ok(fast.state.inventory.food < s.inventory.food, 'fast travel still costs food');
  // A port reached only by an uncharted route cannot be fast-travelled to.
  const t = State.clone(s); t.world.chartedRoutes = [];
  assert.equal(Actions.depart(t, 'brightquay', { fast: true }).reasonKey, 'err.fast_not_charted');
  // Food is checked before departure.
  const hungry = State.clone(s); hungry.inventory.food = 0;
  assert.equal(Actions.depart(hungry, 'gull_rock', { confirmed: true }).reasonKey, 'err.no_food_route');
});

test('the main step and its trial are always visible; the final trial opens postgame', () => {
  let s = newGame(21);
  const st = Rules.mainStatus(s);
  assert.equal(st.regionId, 'dawnwater');
  assert.equal(st.step, 0);
  assert.ok(st.quest && st.quest.titleKey);
  assert.equal(st.trialLocationId, World.region('dawnwater').locs[8]);
  // Simulate the arc finishing in every region and check the unlock chain.
  s = State.clone(s);
  s.captain.regionsUnlocked = Content.REGION_ORDER.slice();
  for (const r of Content.REGION_ORDER) s.captain.mainStep[r] = World.MAIN_TEMPLATE.length;
  assert.equal(Rules.mainStatus(s).done, true);
  // Winning the last trial through the real completion path grants the title.
  let u = State.clone(newGame(22));
  u.captain.regionsUnlocked = Content.REGION_ORDER.slice();
  for (const r of Content.REGION_ORDER) u.captain.mainStep[r] = World.MAIN_TEMPLATE.length;
  u.captain.mainStep.grand_horizon = World.MAIN_TEMPLATE.length - 1;
  u.captain.trialsWon = Content.REGION_ORDER.slice();
  u = act(u, 'setTactics', 'balanced', null); // any transaction runs the completion checks
  assert.equal(u.captain.postgame, true);
  assert.equal(u.captain.titleKey, 'title.strongest');
  assert.equal(u.captain.mainStep.grand_horizon, World.MAIN_TEMPLATE.length);
});

test('port investment unlocks real services with no hidden reputation gate', () => {
  let s = grant(newGame(23), { gold: 5000, materials: 500, specialties: { saltleaf_grain: 20 } });
  const before = Rules.shopItems(s, 'brightquay');
  const cost = Rules.investCost(s, 'brightquay', 'market');
  assert.ok(cost && cost.gold > 0);
  assert.ok(!cost.rep && !cost.reputation, 'investment needs only listed resources');
  s = act(s, 'invest', 'market');
  const after = Rules.shopItems(s, 'brightquay');
  assert.ok(after.length > before.length, 'market level 2 stocks weapons and outfits');
  const tav0 = Rules.tavernPool(s, 'brightquay').length;
  s = act(s, 'invest', 'tavern');
  assert.ok(Rules.tavernPool(s, 'brightquay').length > tav0, 'tavern level 2 shows more recruits');
  assert.equal(Actions.craftItem(newGame(23), 'w_blade_1').ok, false, 'no workshop, no crafting');
  s = act(s, 'invest', 'workshop');
  assert.ok(Rules.canCraftHere(s));
  const crafted = Actions.craftItem(s, 'w_blade_1');
  assert.ok(crafted.ok, crafted.reasonKey);
  assert.equal(crafted.state.inventory.specialties.saltleaf_grain, s.inventory.specialties.saltleaf_grain - 1, 'specialties are spent by recipes');
});
