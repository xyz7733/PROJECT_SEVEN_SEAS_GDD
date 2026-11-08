'use strict';
// Gate 2: one persistent ship with hull tiers, multi-deck free layout, doors,
// stairs, reachability, presets, dismantle, repair, and departure gating.
const test = require('node:test');
const { assert, Content, State, Rules, Actions, newGame, act, grant } = require('./helpers.js');

const facOf = (s, id) => s.ship.facilities.find(f => f.id === id);
const reach = (s, uid) => Rules.layoutOf(s).facilities[uid];

test('four hull tiers with one to four decks', () => {
  assert.deepEqual(Content.HULLS.map(h => h.tier), [1, 2, 3, 4]);
  assert.deepEqual(Content.HULLS.map(h => h.decks.length), [1, 2, 3, 4]);
  assert.ok(Object.keys(Content.FACILITIES).length >= 20);
});

test('departure requires reachable Command, Quarters, and Pantry', () => {
  let s = newGame(1);
  assert.equal(Rules.sailBlock(s, 'gull_rock'), null);
  const pantry = facOf(s, 'pantry');
  s = act(s, 'stowFacility', pantry.uid);
  assert.deepEqual(Rules.layoutOf(s).missingRequired, ['pantry']);
  assert.equal(Rules.sailBlock(s, 'gull_rock'), 'err.layout_blocked');
  assert.equal(Actions.depart(s, 'gull_rock').reasonKey, 'err.layout_blocked');
  s = act(s, 'moveFacility', pantry.uid, 0, 1, 3, 0);
  assert.equal(Rules.sailBlock(s, 'gull_rock'), null);
  assert.equal(Actions.demolishFacility(s, facOf(s, 'captains_cabin').uid).reasonKey, 'err.cannot_demolish_cabin');
});

test('an enclosed optional facility is disabled, needs confirmation, and recovers', () => {
  let s = grant(newGame(1), { gold: 500, materials: 100 });
  s = act(s, 'buildFacility', 'lookout', 0, 9, 1, 0);
  const lookout = facOf(s, 'lookout');
  assert.ok(reach(s, lookout.uid).reachable);
  s = act(s, 'buildFacility', 'chart_table', 0, 9, 2, 0); // seals the lookout in
  const r = reach(s, lookout.uid);
  assert.equal(r.reachable, false);
  assert.equal(r.reasonKey, 'warn.facility_unreachable');
  assert.equal(Rules.facLevel(s, 'lookout'), 0, 'unreachable facilities give no effect');
  assert.equal(Rules.sailBlock(s, 'gull_rock'), null, 'optional facilities never block departure');
  const dep = Actions.depart(s, 'gull_rock');
  assert.equal(dep.reasonKey, 'warn.confirm_unreachable');
  assert.equal(dep.reasonParams.n, 1);
  // A bad move can seal a required room instead: (3,1) is the only corridor to the pantry.
  const sealed = act(s, 'moveFacility', facOf(s, 'chart_table').uid, 0, 3, 1, 0);
  assert.deepEqual(Rules.layoutOf(sealed).missingRequired, ['pantry']);
  assert.equal(Actions.depart(sealed, 'gull_rock', { confirmed: true }).reasonKey, 'err.layout_blocked');
  // Moving the blocker somewhere harmless restores the lookout.
  s = act(s, 'moveFacility', facOf(s, 'chart_table').uid, 0, 7, 2, 0);
  assert.ok(reach(s, lookout.uid).reachable);
  assert.equal(Rules.facLevel(s, 'lookout'), 1);
  assert.ok(Actions.depart(s, 'gull_rock').ok);
});

function voyager(s) {
  const d = State.clone(s);
  const hull = Content.hull('voyager');
  d.ship.hullId = hull.id; d.ship.hullTier = hull.tier;
  d.ship.decks = hull.decks.map((hd, i) => State.makeDeck(hd, i));
  return d;
}

test('stairs connect decks and bulkhead doors gate the far side', () => {
  let s = grant(voyager(newGame(2)), { gold: 2000, materials: 300 });
  s = act(s, 'buildFacility', 'hatchery', 1, 1, 1, 0);
  const hatch = facOf(s, 'hatchery');
  assert.equal(reach(s, hatch.uid).reasonKey, 'warn.deck_no_stair');
  s = act(s, 'placeStair', 0, 3, 1);
  assert.ok(reach(s, hatch.uid).reachable, 'stair connects deck 2');

  s = act(s, 'buildFacility', 'galley', 1, 7, 1, 0); // beyond the bulkhead at x=5
  const galley = facOf(s, 'galley');
  assert.ok(reach(s, galley.uid).reachable, 'the default door is open');
  const doorY = s.ship.decks[1].doors[0][1];
  s = act(s, 'toggleDoor', 1, doorY);
  assert.equal(reach(s, galley.uid).reachable, false);
  assert.equal(reach(s, galley.uid).reasonKey, 'warn.facility_unreachable');
  s = act(s, 'toggleDoor', 1, doorY);
  assert.ok(reach(s, galley.uid).reachable);

  // Moving a stair: remove it, and the lower deck is cut off until it is placed again.
  s = act(s, 'removeStair', 0);
  assert.equal(reach(s, hatch.uid).reachable, false);
  s = act(s, 'placeStair', 0, 3, 2);
  assert.ok(reach(s, hatch.uid).reachable);
  assert.equal(Actions.placeStair(s, 1, 2, 2).reasonKey, 'err.no_lower_deck');
});

test('layout presets restore positions of owned facilities', () => {
  let s = grant(newGame(3), { gold: 300, materials: 50 });
  s = act(s, 'buildFacility', 'lookout', 0, 3, 1, 0);
  const uid = facOf(s, 'lookout').uid;
  s = act(s, 'savePreset', 0);
  s = act(s, 'moveFacility', uid, 0, 6, 1, 0);
  assert.deepEqual([facOf(s, 'lookout').x, facOf(s, 'lookout').y], [6, 1]);
  s = act(s, 'applyPreset', 0);
  assert.deepEqual([facOf(s, 'lookout').x, facOf(s, 'lookout').y], [3, 1]);
  assert.equal(Actions.applyPreset(s, 2).reasonKey, 'err.no_preset');
});

test('dismantle refunds part of the cost; upgrades and repairs work at port', () => {
  let s = grant(newGame(4), { gold: 1000, materials: 200 });
  s = act(s, 'buildFacility', 'galley', 0, 7, 2, 0);
  const g = facOf(s, 'galley');
  const ref = Rules.demolishRefund(g);
  assert.ok(ref.gold > 0 && ref.gold < Content.FACILITIES.galley.cost.gold);
  const gold0 = s.inventory.gold;
  s = act(s, 'demolishFacility', g.uid);
  assert.equal(s.inventory.gold, gold0 + ref.gold);
  assert.equal(facOf(s, 'galley'), undefined);

  const q = facOf(s, 'crew_quarters');
  const cap0 = Rules.crewCapacity(s);
  s = act(s, 'upgradeFacility', q.uid);
  assert.equal(Rules.crewCapacity(s), cap0 + 2);
  assert.equal(Actions.upgradeFacility(s, q.uid).reasonKey, 'err.hull_tier', 'level 3 needs a better hull');

  const dmg = State.clone(s); dmg.ship.damage = 30; dmg.ship.facilities[1].damaged = true;
  assert.equal(Rules.facLevel(dmg, 'crew_quarters'), 0, 'damaged facilities lose their bonus');
  const fixed = act(dmg, 'repairShip');
  assert.equal(fixed.ship.damage, 0);
  assert.ok(fixed.ship.facilities.every(f => !f.damaged));
  assert.equal(Actions.repairShip(fixed).reasonKey, 'err.nothing_to_repair');
});

test('hull upgrade keeps the same ship, crew, and facilities', () => {
  let s = grant(newGame(5), { gold: 2000, materials: 200, specialties: { ember_ore: 3 } });
  assert.equal(Actions.upgradeHull(s, 'voyager').reasonKey, 'err.hull_region');
  s = State.clone(s);
  s.captain.regionsUnlocked.push('emberreach');
  assert.equal(Actions.upgradeHull(s, 'voyager').reasonKey, 'err.need_workshop2');
  s.world.ports.brightquay.tracks.workshop = 2;
  const r = Actions.upgradeHull(s, 'voyager');
  assert.ok(r.ok, r.reasonKey);
  assert.equal(r.saveReason, 'save.reason_hull');
  const t = r.state;
  assert.equal(t.ship.hullTier, 2);
  assert.equal(t.ship.decks.length, 2);
  assert.deepEqual(t.crew.map(m => m.id), s.crew.map(m => m.id));
  assert.deepEqual(t.ship.facilities.map(f => f.uid), s.ship.facilities.map(f => f.uid));
  assert.equal(Actions.upgradeHull(t, 'voyager').reasonKey, 'err.hull_owned');
  assert.equal(Actions.upgradeHull(t, 'legend').reasonKey, 'err.hull_previous');
});

test('the layout can only be edited in port', () => {
  let s = act(newGame(1), 'depart', 'gull_rock', { confirmed: true });
  assert.ok(s.voyage);
  assert.equal(Actions.buildFacility(s, 'lookout', 0, 3, 1, 0).reasonKey, 'err.need_port');
});
