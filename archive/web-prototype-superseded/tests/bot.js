'use strict';
// Headless campaign bot: plays the full game only through the public action
// API, the same way the UI does. Used to prove that every region, the final
// trial, and postgame are reachable from a new save.
const Content = require('../src/content.js');
const World = require('../src/world.js');
const State = require('../src/state.js');
const Rules = require('../src/rules.js');
const A = require('../src/actions.js');

function playCampaign(seed, opts) {
  const o = Object.assign({ maxSteps: 40000, verbose: false, stopAtRegion: null }, opts || {});
  let s = State.createNewGame(seed);
  const stats = { steps: 0, battles: 0, wins: 0, losses: 0, retreats: 0, gold: {}, hard: [], regionAt: {}, levelsAt: {}, failures: {}, aid: 0 };
  const say = (...a) => { if (o.verbose) console.log(...a); };
  function act(name, ...args) {
    const before = s.inventory.gold + s.inventory.ledger.gold;
    const r = A[name](s, ...args);
    if (r.ok) {
      const delta = r.state.inventory.gold + r.state.inventory.ledger.gold - before;
      const key = name === 'resolveEncounter' ? 'battle' : name === 'buyGoods' ? 'buy_' + args[0] : name;
      stats.gold[key] = (stats.gold[key] || 0) + delta;
      s = r.state;
    }
    else stats.failures[name + ':' + r.reasonKey] = (stats.failures[name + ':' + r.reasonKey] || 0) + 1;
    return r;
  }
  function fight() {
    const enc = s.encounter;
    const r = act('resolveEncounter', enc.attemptId, []);
    stats.battles++;
    const out = r.value.outcome;
    if (out === 'victory') stats.wins++; else if (out === 'defeat') stats.losses++; else stats.retreats++;
    say('  battle', enc.def.id, 'L' + enc.def.level, out, 'team', s.crew.map(m => m.level).join('/'));
    const hp = Object.values(r.value.hpLeft || {});
    if (enc.def.kind === 'trial' || enc.def.kind === 'boss') stats.hard.push(enc.def.id + ':' + out[0] + ':' + (r.value.hpAvg != null ? r.value.hpAvg : '?'));
    return out;
  }
  const curPort = () => (Rules.atPort(s) ? s.world.currentLocationId : null);
  const tier = () => World.region(s.captain.regionsUnlocked[s.captain.regionsUnlocked.length - 1]).tier;

  function portChores() {
    const port = curPort();
    if (!port) return;
    for (const k of Rules.emergencyNeeds(s)) { if (act('emergencyAid', k).ok) stats.aid++; }
    for (const m of s.crew) if (m.injured) act('treat', m.id);
    if (Rules.repairCost(s).needed) act('repairShip');
    // Investments that unlock services in the current region.
    const reg = World.PORTS[port].regionId;
    // Invest selectively: the first port of each region gets a level-2 market.
    if (World.region(reg).locs[0] === port) {
      for (const tr of ['market']) {
        const c = Rules.portTrack(s, port, tr) < 2 ? Rules.investCost(s, port, tr) : null;
        if (c && s.inventory.gold > c.gold + 500) act('invest', tr);
      }
    }
    // Stock specialties needed for later hulls when this port sells them.
    for (const h of Content.HULLS.filter(h => h.tier > s.ship.hullTier && h.cost)) {
      const [spec, n] = h.cost.specialty;
      if (World.region(reg).specialtyId === spec && (s.inventory.specialties[spec] || 0) < n) {
        if (Rules.portTrack(s, port, 'market') < 2) { const c = Rules.investCost(s, port, 'market'); if (c && s.inventory.gold > c.gold + 100) act('invest', 'market'); }
        if (Rules.portTrack(s, port, 'market') >= 2) act('buyGoods', 'specialty', spec, n - (s.inventory.specialties[spec] || 0));
      }
    }
    // Hull upgrades.
    const next = Content.HULLS.find(h => h.tier === s.ship.hullTier + 1);
    if (next && Rules.hullAvailable(s, next).ok) {
      if (Rules.portTrack(s, port, 'workshop') < 2) { const c = Rules.investCost(s, port, 'workshop'); if (c && s.inventory.gold > c.gold) act('invest', 'workshop'); }
      const [spec, n] = next.cost.specialty;
      if ((s.inventory.specialties[spec] || 0) < n && Rules.portTrack(s, port, 'market') >= 2 && World.region(reg).specialtyId === spec) act('buyGoods', 'specialty', spec, n);
      const r = act('upgradeHull', next.id);
      if (r.ok) { say(' hull ->', next.id); layoutAfterHull(); }
    }
    // Quarters for six crew.
    const quarters = s.ship.facilities.find(f => f.id === 'crew_quarters');
    if (quarters && quarters.level < 2 && s.inventory.gold > 200) act('upgradeFacility', quarters.uid);
    // Recruit to fill six slots.
    while (s.crew.length < Math.min(6, Rules.crewCapacity(s))) {
      const pool = Rules.tavernPool(s, port).filter(p => !p.hired && p.cost <= s.inventory.gold - 60);
      if (!pool.length) break;
      const pick = pool.find(p => !s.crew.some(m => m.classId === p.member.classId)) || pool[0];
      if (!act('recruit', pick.index).ok) break;
    }
    for (let i = 0; i < 6; i++) if (!s.formation[i]) { const free = s.crew.find(m => !s.formation.includes(m.id)); if (free) act('setFormation', i, free.id); }
    gearUp(port);
    // Sell surplus specialties from older regions, keep enough for steps and hull.
    for (const [spec, n] of Object.entries(s.inventory.specialties)) {
      const keep = Content.HULLS.some(h => h.tier > s.ship.hullTier && h.cost && h.cost.specialty[0] === spec) ? 12 : 8;
      if (n > keep) act('sellSpecialty', spec, n - keep);
    }
    const cap = Rules.foodCapacity(s);
    const need = cap - s.inventory.food;
    const price = Rules.prices(s, port).food;
    if (need > 0) act('buyGoods', 'food', null, Math.min(need, Math.floor((s.inventory.gold - 20) / price)));
    if (Rules.portTrack(s, port, 'market') >= 1 && s.inventory.supplies < 3 && s.inventory.gold > 200) act('buyGoods', 'supplies', null, 2);
  }
  function hullReserve() {
    const next = Content.HULLS.find(h => h.tier === s.ship.hullTier + 1);
    if (!next || s.captain.regionsUnlocked.length < next.unlockRegion) return 0;
    if (next.blueprint && !s.inventory.blueprints.includes(next.blueprint)) return 0;
    return next.cost.gold + 400;
  }
  function layoutAfterHull() {
    for (const f of s.ship.facilities.filter(x => x.stowed)) {
      outer: for (let d = 0; d < s.ship.decks.length; d++) for (let y = 0; y < s.ship.decks[d].h; y++) for (let x = 0; x < s.ship.decks[d].w; x++) {
        if (Rules.canPlace(s.ship, f.id, d, x, y, 0, f.uid).ok) { const r = act('moveFacility', f.uid, d, x, y, 0); if (r.ok && Rules.layoutOf(s).facilities[f.uid].reachable) break outer; }
      }
    }
  }
  function bestFor(m, slot, port) {
    const t = tier();
    const shop = Rules.shopItems(s, port);
    let cands = [];
    if (slot === 'weapon') cands = Content.CLASSES[m.classId].weapons.map(w => 'w_' + w + '_' + t);
    if (slot === 'outfit') cands = ['o_armor_' + t, 'o_coat_' + t];
    return cands.filter(id => Content.ITEMS[id]);
  }
  function score(itemId) { const it = Content.ITEMS[itemId]; return (it.stats.atk || 0) * 2 + (it.stats.def || 0) * 1.5 + (it.stats.hp || 0) / 6 + it.tier; }
  function gearUp(port) {
    for (const m of Rules.activeCrew(s)) {
      for (const slot of ['weapon', 'outfit']) {
        const cur = Rules.equipInst(s, m.equipment[slot]);
        const curScore = cur ? score(cur.itemId) : -1;
        for (const id of bestFor(m, slot, port)) {
          if (score(id) <= curScore) continue;
          // Prefer an unequipped owned item, else craft, else buy.
          let inst = s.inventory.equipment.find(e => e.itemId === id && !s.crew.some(c => Object.values(c.equipment).includes(e.uid)));
          if (!inst) {
            const sold = Rules.shopItems(s, port).includes(id);
            if (sold && s.inventory.gold > Rules.itemPrice(id) + 200 + hullReserve()) { const r = act('buyItem', id); if (r.ok) inst = Rules.equipInst(s, r.value); }
            else if (s.inventory.recipes.includes(id) && Rules.canCraftHere(s)) { const r = act('craftItem', id); if (r.ok) inst = Rules.equipInst(s, r.value); }
          }
          if (inst) { act('equip', m.id, slot, inst.uid); break; }
        }
      }
      {  // Salvage obsolete, unequipped gear for materials.
        const old = s.inventory.equipment.filter(e => !s.crew.some(c => Object.values(c.equipment).includes(e.uid)) && Content.ITEMS[e.itemId].tier < tier() - 1 && !Content.ITEMS[e.itemId].unique);
        for (const e of old) act('salvage', e.uid);
      }
    }
    // Uniques go to whoever can use them.
    for (const uid of s.inventory.equipment.filter(e => Content.ITEMS[e.itemId].unique).map(e => e.uid)) {
      if (s.crew.some(c => Object.values(c.equipment).includes(uid))) continue;
      const it = Content.ITEMS[Rules.equipInst(s, uid).itemId];
      const m = Rules.activeCrew(s).find(c => Rules.weaponCompatible(c.classId, it.id) && (!c.equipment[it.slot] || score(Rules.equipInst(s, c.equipment[it.slot]).itemId) < score(it.id) + 6));
      if (m) act('equip', m.id, it.slot, uid);
    }
  }
  function ensureStamina(need) {
    while (s.ship.stamina < need) {
      if (s.inventory.supplies > 0 && s.ship.stamina + 30 <= s.ship.staminaMax + 10) { if (!act('useSupply').ok) break; continue; }
      if (s.inventory.food > 4) { if (!act('serveRation').ok) break; continue; }
      return false;
    }
    return true;
  }
  function sailTo(dest) {
    let guard = 0;
    while (s.world.currentLocationId !== dest && guard++ < 6) {
      if (s.encounter) { fight(); continue; }
      if (s.voyage && s.voyage.event) { const ev = s.voyage.event.kind; act('resolveSeaEvent', ev === 'inspection' ? (s.inventory.gold > 60 ? 'pay' : 'delay') : ev === 'vessel' ? 'ignore' : 'take'); continue; }
      const fast = Rules.atPort(s) && World.PORTS[dest] && !Rules.sailBlock(s, dest, true);
      const r = act('depart', dest, { fast: !!fast, confirmed: true });
      if (!r.ok) {
        if (r.reasonKey === 'err.no_food_route') {
          if (Rules.atPort(s)) { portChores(); let g = 0; while (s.inventory.food < Rules.legCost(s, s.world.currentLocationId, dest).food && g++ < 20) { if (!act('dockWork').ok) act('emergencyAid', 'meal'); portChores(); } continue; }
          act('emergencyReturn'); portChores(); continue;
        }
        return false;
      }
      while (s.encounter || (s.voyage && s.voyage.event)) {
        if (s.encounter) fight();
        else { const ev = s.voyage.event.kind; act('resolveSeaEvent', ev === 'inspection' ? (s.inventory.gold > 60 ? 'pay' : 'delay') : 'take'); }
      }
    }
    return s.world.currentLocationId === dest;
  }
  function nearestPort() {
    const here = s.world.currentLocationId;
    const reg = World.location(here).regionId;
    return World.region(reg).locs.slice(0, 2).filter(p => Rules.isKnown(s, p)).sort((a, b) => World.distance(here, a) - World.distance(here, b))[0] || s.world.lastSafePortId;
  }
  // Clear rooms toward the objective; returns 'cleared' | 'defeat' | 'tired'.
  function clearSite(locId, repeatRoom) {
    const rooms = World.rooms(locId);
    for (let guard = 0; guard < 20; guard++) {
      const ls = s.world.locations[locId];
      if (repeatRoom) {
        const rm = World.room(locId, repeatRoom);
        if (!ensureStamina(rm.cost)) return 'tired';
        const r = act('enterRoom', repeatRoom, { repeat: true });
        if (!r.ok) return 'tired';
        const out = fight();
        return out === 'victory' ? 'cleared' : 'defeat';
      }
      if (ls.k === 'cleared') return 'cleared';
      const next = rooms.find(r => !ls.rooms.includes(r.id) && !r.secret && A.roomAccessible(s, locId, r.id) && (r.kind !== 'resource' || r.next.length || true));
      if (!next) return 'cleared';
      if (!ensureStamina(next.cost)) return 'tired';
      const r = act('enterRoom', next.id);
      if (!r.ok) { say('  room fail', next.id, r.reasonKey); return 'tired'; }
      if (s.encounter) { const out = fight(); if (out !== 'victory') return 'defeat'; }
    }
    return 'cleared';
  }
  function grind(times) {
    // Repeat battles at the hardest cleared location in the current region.
    const reg = World.location(s.world.currentLocationId).regionId;
    const r = World.region(reg);
    const cleared = r.locs.filter(id => Rules.knowledge(s, id) === 'cleared' && ['island', 'dungeon'].includes(World.location(id).type));
    const pool = cleared.length ? cleared : [];
    if (!pool.length) {
      // Fall back to previous region's island.
      return false;
    }
    const loc = pool.sort((a, b) => World.location(a).level - World.location(b).level)[Math.max(0, pool.length - 2)];
    for (let i = 0; i < times; i++) {
      if (!sailTo(loc)) return false;
      const room = World.rooms(loc).find(x => x.kind === 'battle').id;
      const out = clearSite(loc, room);
      if (out !== 'cleared') { if (s.voyage) act('emergencyReturn'); portChores(); }
    }
    sailTo(nearestPort()); portChores();
    return true;
  }

  let lastRegion = null;
  for (stats.steps = 0; stats.steps < o.maxSteps; stats.steps++) {
    if (s.captain.postgame) break;
    const ms = Rules.mainStatus(s);
    if (ms.done) break;
    if (o.stopAtRegion && ms.regionId === o.stopAtRegion) break;
    if (ms.regionId !== lastRegion) {
      lastRegion = ms.regionId; stats.regionAt[ms.regionId] = stats.battles;
      stats.levelsAt[ms.regionId] = s.crew.map(m => m.level);
      say('== region', ms.regionId, 'battles so far', stats.battles, 'levels', s.crew.map(m => m.level).join('/'), 'gold', s.inventory.gold, 'hull', s.ship.hullId);
    }
    const q = ms.quest;
    if (s.encounter) { fight(); continue; }
    if (s.voyage && s.voyage.event) { act('resolveSeaEvent', 'take'); continue; }
    // Region entry: sail from previous region's second port to this region's first port.
    const target = q.locationId;
    if (!Rules.isKnown(s, target)) { say('target hidden', target); return { ok: false, state: s, stats, reason: 'hidden ' + target }; }
    if (Rules.atPort(s)) portChores();
    if (q.type === 'deliver') {
      const spec = q.itemId;
      const have = s.inventory.specialties[spec] || 0;
      if (have < q.count) {
        // Gather at a cleared resource room or buy at the market.
        const port = World.region(q.regionId).locs[0];
        if (!sailTo(port)) continue;
        portChores();
        if (Rules.portTrack(s, port, 'market') < 2) act('invest', 'market');
        const rb = act('buyGoods', 'specialty', spec, q.count - have);
        if (!rb.ok) { grind(2); continue; }
      }
      if (!sailTo(q.locationId)) continue;
      const r = act('deliverMain');
      if (!r.ok) say('deliver fail', r.reasonKey);
      continue;
    }
    if (q.type === 'visit') { sailTo(target); continue; }
    if (q.type === 'clear' || q.type === 'trial') {
      if (Rules.sailBlock(s, target) === 'err.hull_required' || (s.voyage && World.region(World.location(target).regionId).requiresHullTier > s.ship.hullTier)) {
        if (s.voyage) act('emergencyReturn');
        portChores();
        if (s.ship.hullTier < 4) { grind(3); stats.hullGrind = (stats.hullGrind || 0) + 1; if (stats.hullGrind > 40) return { ok: false, state: s, stats, reason: 'hull grind' }; continue; }
      }
      if (!sailTo(target)) { say('cannot sail', target, Rules.sailBlock(s, target), 'at', s.world.currentLocationId, 'food', s.inventory.food, 'gold', s.inventory.gold, 'ledger', JSON.stringify(s.inventory.ledger), 'leg', JSON.stringify(Rules.legCost(s, s.world.currentLocationId, target)), 'cap', Rules.foodCapacity(s), 'voy', !!s.voyage); if ((stats.failures['sail:' + target] || 0) > 3) return { ok: false, state: s, stats, reason: 'stuck' }; stats.failures['sail:' + target] = (stats.failures['sail:' + target] || 0) + 1; if (Rules.atPort(s)) { act('dockWork'); } else act('emergencyReturn'); continue; }
      const out = clearSite(target);
      if (out === 'defeat') { say(' defeat at', target); portChores(); grind(3); continue; }
      if (out === 'tired') { act('emergencyReturn'); portChores(); continue; }
      if (q.type === 'trial' && !s.captain.trialsWon.includes(q.regionId)) { grind(2); }
      continue;
    }
  }
  return { ok: s.captain.postgame, state: s, stats };
}

module.exports = { playCampaign };

if (require.main === module) {
  const seed = +process.argv[2] || 2026;
  const t0 = Date.now();
  const r = playCampaign(seed, { verbose: process.argv.includes('-v') });
  const s = r.state;
  console.log('postgame', r.ok, 'title', s.captain.titleKey, 'steps', r.stats.steps, 'battles', r.stats.battles, 'W/L/R', r.stats.wins, r.stats.losses, r.stats.retreats, 'aid', r.stats.aid);
  console.log('levels', s.crew.map(m => m.classId + ':' + m.level).join(' '), 'gold', s.inventory.gold, 'hull', s.ship.hullId, 'day', Rules.day(s));
  console.log('regionAt', JSON.stringify(r.stats.regionAt));
  console.log('levelsAt', JSON.stringify(r.stats.levelsAt));
  console.log('failures', JSON.stringify(r.stats.failures));
  console.log('hard', r.stats.hard.join(' '));
  console.log('gold flows', JSON.stringify(r.stats.gold));
  console.log('ms', Date.now() - t0);
}
