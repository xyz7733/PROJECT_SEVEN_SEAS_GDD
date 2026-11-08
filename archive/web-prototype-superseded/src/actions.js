/*
 * Project Seven Seas — transactions. Every player action is one atomic
 * commit: the mutator works on a draft copy, validates, and either fails
 * without side effects or returns the next state (GDD §19.4).
 */
(function (root) {
  'use strict';

  const P = root.P7S || {};
  const Content = P.Content || require('./content.js');
  const World = P.World || require('./world.js');
  const State = P.State || require('./state.js');
  const Rules = P.Rules || require('./rules.js');
  const Combat = P.Combat || require('./combat.js');
  const T = Content.TUNING;

  const fail = (reasonKey, reasonParams) => ({ ok: false, reasonKey, reasonParams: reasonParams || {} });
  const done = (value, saveReason) => ({ ok: true, value, saveReason });
  const log = State.addLog;
  const locName = id => 'loc.' + id + '.name';

  function run(state, kind, fn) {
    return State.commit(state, kind, d => {
      const r = fn(d);
      if (r && r.ok === false) return r;
      afterChange(d);
      return r || done();
    });
  }

  // ---------------------------------------------------------------- economy
  function hasCost(d, c) {
    const inv = d.inventory;
    if (c.gold && inv.gold < c.gold) return fail('err.no_gold', { need: c.gold });
    if (c.materials && inv.materials < c.materials) return fail('err.no_materials', { need: c.materials });
    if (c.food && inv.food < c.food) return fail('err.no_food', { need: c.food });
    if (c.supplies && inv.supplies < c.supplies) return fail('err.no_supplies', { need: c.supplies });
    if (c.specialty) {
      const [id, n] = c.specialty;
      if ((inv.specialties[id] || 0) < n) return fail('err.no_specialty', { item: 'spec.' + id + '.name', need: n });
    }
    return null;
  }
  function pay(d, c) {
    const bad = hasCost(d, c);
    if (bad) return bad;
    const inv = d.inventory;
    inv.gold -= c.gold || 0; inv.materials -= c.materials || 0; inv.food -= c.food || 0; inv.supplies -= c.supplies || 0;
    if (c.specialty) inv.specialties[c.specialty[0]] -= c.specialty[1];
    return null;
  }
  // Gold and materials found on a voyage are unbanked until the ship docks.
  function gain(d, g) {
    const inv = d.inventory;
    const banked = !d.voyage;
    if (g.gold) { if (banked) inv.gold += g.gold; else inv.ledger.gold += g.gold; }
    if (g.materials) { if (banked) inv.materials += g.materials; else inv.ledger.materials += g.materials; }
  }
  function addFood(d, n) {
    const cap = Rules.foodCapacity(d);
    const room = Math.max(0, cap - d.inventory.food);
    const got = Math.min(room, n);
    d.inventory.food += got;
    if (got < n) log(d, 'log.food_overflow', { n: n - got });
    return got;
  }
  function addSupplies(d, n) {
    const cap = Rules.supplyCapacity(d);
    const got = Math.min(Math.max(0, cap - d.inventory.supplies), n);
    d.inventory.supplies += got;
    if (got < n) log(d, 'log.supply_overflow', { n: n - got });
    return got;
  }
  function addSpecialty(d, id, n) { d.inventory.specialties[id] = (d.inventory.specialties[id] || 0) + n; }
  function addIngredient(d, id, n) { d.inventory.ingredients[id] = (d.inventory.ingredients[id] || 0) + n; }
  function addEquipment(d, itemId, opts) {
    if (d.inventory.equipment.length >= Rules.equipCapacity(d)) {
      const mats = Rules.salvageValue({ itemId, reinforce: 0 }).materials;
      gain(d, { materials: mats });
      log(d, 'log.equip_overflow', { item: itemNameKey(itemId), n: mats });
      return null;
    }
    const inst = { uid: State.nextId(d, 'eq'), itemId, reinforce: 0, affix: (opts && opts.affix) || null };
    d.inventory.equipment.push(inst);
    d.codex.items[itemId] = true;
    const it = Content.ITEMS[itemId];
    if (it.recipe && !d.inventory.recipes.includes(itemId)) d.inventory.recipes.push(itemId);
    if (it.unique && !d.inventory.uniques.includes(itemId)) d.inventory.uniques.push(itemId);
    return inst;
  }
  function itemNameKey(itemId) {
    const it = Content.ITEMS[itemId];
    if (it.nameKey) return it.nameKey;
    return 'item.' + (it.wtype ? 'w_' + it.wtype : 'o_' + it.otype) + '.t' + it.tier;
  }
  function addEgg(d, familyId, grade) {
    d.inventory.eggs.push({ id: State.nextId(d, 'egg'), familyId, grade, inputs: [] });
    log(d, 'log.egg_found', { family: 'petfam.' + familyId + '.name' });
  }
  function addClue(d, clueKey) {
    if (!d.codex.clues.includes(clueKey)) { d.codex.clues.push(clueKey); log(d, 'log.clue', { clue: clueKey }); return true; }
    return false;
  }
  function reveal(d, locId) {
    const l = d.world.locations[locId];
    if (l && l.k === 'hidden') { l.k = 'revealed'; log(d, 'log.revealed', { location: locName(locId) }); return true; }
    return false;
  }
  function advanceClock(d, hours) { d.envelope.gameClock += hours; }

  function requirePort(d) {
    if (d.encounter) return fail('err.in_encounter');
    if (!Rules.atPort(d)) return fail('err.need_port');
    return null;
  }
  function requireCalm(d) {
    if (d.encounter) return fail('err.in_encounter');
    if (d.voyage && d.voyage.event) return fail('err.event_pending');
    return null;
  }
  function here(d) { return d.world.currentLocationId; }
  function hereRegion(d) { return World.location(here(d)).regionId; }

  // ------------------------------------------------------------ after change
  function afterChange(d) {
    d.ship.staminaMax = Rules.staminaMax(d);
    if (d.ship.stamina > d.ship.staminaMax) d.ship.stamina = d.ship.staminaMax;
    let guard = 0;
    while (checkMain(d) && guard++ < 6) { /* chained steps */ }
    checkSides(d);
    checkCrewEvents(d);
    checkTidebound(d);
    for (const m of d.crew) d.codex.classes[m.classId] = true;
  }
  function stepDone(d, q) {
    if (q.type === 'clear') return Rules.knowledge(d, q.locationId) === 'cleared';
    if (q.type === 'visit') return Rules.isVisited(d, q.locationId);
    if (q.type === 'trial') return d.captain.trialsWon.includes(q.regionId);
    return false; // deliveries complete through deliverMain()
  }
  function completeMain(d, q) {
    const rid = q.regionId;
    d.captain.mainStep[rid] = q.step + 1;
    gain(d, { gold: q.reward.gold });
    grantXp(d, q.reward.xp, true);
    d.captain.reputation.conclave += q.reward.rep;
    for (const id of q.reveal) reveal(d, id);
    log(d, 'log.main_done', { quest: q.titleKey });
    if (q.type === 'trial') {
      const reg = World.region(rid);
      if (rid === 'leviathan_ring' && !d.inventory.blueprints.includes('legend_keel')) { d.inventory.blueprints.push('legend_keel'); log(d, 'log.blueprint', { item: 'blueprint.legend_keel' }); }
      if (reg.nextRegionId && !d.captain.regionsUnlocked.includes(reg.nextRegionId)) {
        const nx = World.region(reg.nextRegionId);
        d.captain.regionsUnlocked.push(nx.id);
        d.captain.mainStep[nx.id] = 0;
        reveal(d, nx.locs[0]);
        reveal(d, nx.locs[2]);
        log(d, 'log.region_unlocked', { region: 'region.' + nx.id + '.name' });
      }
      if (!reg.nextRegionId && !d.captain.postgame) {
        d.captain.postgame = true;
        d.captain.titleKey = 'title.strongest';
        d.captain.flags.postgameAt = d.envelope.gameClock;
        log(d, 'log.postgame', {});
      }
    }
  }
  function checkMain(d) {
    for (const rid of d.captain.regionsUnlocked) {
      const step = d.captain.mainStep[rid] || 0;
      const q = World.mainStep(rid, step);
      if (q && stepDone(d, q)) { completeMain(d, q); return true; }
    }
    return false;
  }
  function checkSides(d) {
    for (const [qid, st] of Object.entries(d.world.quests)) {
      if (st.status !== 'active') continue;
      const q = World.QUESTS[qid];
      const ok = q.type === 'discover' ? Rules.isVisited(d, q.locationId) : Rules.knowledge(d, q.locationId) === 'cleared';
      if (!ok) continue;
      st.status = 'done';
      const r = World.region(q.regionId);
      gain(d, { gold: q.reward.gold, materials: q.reward.materials });
      grantXp(d, q.reward.xp, true);
      d.captain.reputation[q.faction] += q.reward.rep;
      if (q.rewardKind === 'recipe') { const id = 'o_armor_' + Math.min(10, r.tier + 1); if (!d.inventory.recipes.includes(id)) d.inventory.recipes.push(id); st.extra = id; }
      if (q.rewardKind === 'supplies') addSupplies(d, 2);
      if (q.rewardKind === 'ingredients') { const ing = Content.INGREDIENT_BY_COLOR[Content.petFamily(r.petFamilyId).color]; addIngredient(d, ing, 3); st.extra = ing; }
      if (q.rewardKind === 'clue') addClue(d, 'clue.pet.' + r.petFamilyId);
      if (q.rewardKind === 'egg') addEgg(d, r.petFamilyId, 2);
      log(d, 'log.side_done', { quest: q.titleKey, location: locName(q.locationId) });
    }
  }
  function originRegion(m) { return Content.REGION_ORDER[Content.ORIGINS.indexOf(m.originId)]; }
  function checkCrewEvents(d) {
    for (const m of d.crew) {
      if (m.event.status !== 'active') continue;
      let complete = false;
      if (m.eventId === 'homesick') complete = Rules.atPort(d) && hereRegion(d) === originRegion(m) && m.event.progress >= 0 && m.event.armed;
      if (m.eventId === 'proving') complete = m.event.progress >= 5;
      if (m.eventId === 'feast') complete = m.event.progress >= 5;
      if (complete) finishCrewEvent(d, m);
    }
  }
  function finishCrewEvent(d, m) {
    const story = Rules.facLevel(d, 'story_deck');
    m.event.status = 'done';
    const xp = Math.round(40 * m.level * (1 + 0.5 * story));
    addMemberXp(d, m, xp);
    m.mastery[m.classId] = (m.mastery[m.classId] || 0) + 10 + 5 * story;
    gain(d, { gold: 30 + 20 * story });
    log(d, 'log.crew_event_done', { crew: m.id, event: 'event.' + m.eventId + '.title' });
  }
  function checkTidebound(d) {
    const rank = Rules.repRank(d, 'tidebound');
    const got = d.captain.flags.tideClues || 0;
    if (rank > got) {
      d.captain.flags.tideClues = rank;
      const fam = d.captain.regionsUnlocked.map(r => World.region(r).petFamilyId).find(f => !d.codex.clues.includes('clue.pet.' + f));
      if (fam) addClue(d, 'clue.pet.' + fam);
    }
  }

  // ----------------------------------------------------------------- xp
  function xpMult(d) {
    return 1 + 0.05 * Rules.repRank(d, 'conclave') + 0.05 * Rules.facLevel(d, 'tide_archive') + 0.05 * Rules.facLevel(d, 'music_room');
  }
  function addMemberXp(d, m, xp) {
    const mods = Rules.memberStats(d, m).mods;
    m.xp += Math.round(xp * (1 + (mods.xpPct || 0)));
    while (m.level < T.levelCap && m.xp >= Rules.xpToNext(m.level)) { m.xp -= Rules.xpToNext(m.level); m.level++; log(d, 'log.level_up', { crew: m.id, level: m.level }); }
    if (m.level >= T.levelCap) m.xp = 0;
  }
  // Formation members get full XP; benched crew learn on the practice deck.
  function grantXp(d, base, includeBench) {
    const k = xpMult(d);
    const practice = Rules.facLevel(d, 'practice_deck');
    for (const m of d.crew) {
      const inForm = d.formation.includes(m.id);
      if (inForm) addMemberXp(d, m, base * k);
      else if (includeBench || practice) addMemberXp(d, m, base * k * (practice ? 0.3 + 0.15 * practice : 0.25) * Rules.staffMult(d, 'practice_deck'));
    }
  }

  // ============================================================ SHIP EDITOR
  const BUILD_LIMIT = { crew_quarters: 3, pantry: 3, cargo_hold: 2 };
  function buildFacility(state, facId, deck, x, y, rot) {
    return run(state, 'ship.build', d => {
      const bad = requirePort(d); if (bad) return bad;
      const def = Content.FACILITIES[facId];
      if (!def) return fail('err.unknown');
      if (d.ship.hullTier < def.minTier) return fail('err.hull_tier', { tier: def.minTier });
      const count = d.ship.facilities.filter(f => f.id === facId).length;
      if (count >= (BUILD_LIMIT[facId] || 1)) return fail('err.build_limit');
      const place = Rules.canPlace(d.ship, facId, deck, x, y, rot ? 1 : 0, null);
      if (!place.ok) return place;
      const c = pay(d, def.cost); if (c) return c;
      const f = { uid: State.nextId(d, 'fac'), id: facId, deck, x, y, rot: rot ? 1 : 0, level: 1, damaged: false, stowed: false };
      d.ship.facilities.push(f);
      log(d, 'log.built', { facility: 'fac.' + facId + '.name' });
      return done(f.uid);
    });
  }
  function moveFacility(state, uid, deck, x, y, rot) {
    return run(state, 'ship.move', d => {
      const bad = requirePort(d); if (bad) return bad;
      const f = d.ship.facilities.find(q => q.uid === uid);
      if (!f) return fail('err.unknown');
      const place = Rules.canPlace(d.ship, f.id, deck, x, y, rot ? 1 : 0, f.uid);
      if (!place.ok) return place;
      Object.assign(f, { deck, x, y, rot: rot ? 1 : 0, stowed: false });
      return done(uid);
    });
  }
  function clearAssignmentsFor(d, uid) {
    for (const m of d.crew) if (m.jobFacilityUid === uid) m.jobFacilityUid = null;
    for (const p of d.pets) if (p.assignment && p.assignment.kind === 'helper' && p.assignment.target === uid) p.assignment = null;
  }
  function stowFacility(state, uid) {
    return run(state, 'ship.stow', d => {
      const bad = requirePort(d); if (bad) return bad;
      const f = d.ship.facilities.find(q => q.uid === uid);
      if (!f) return fail('err.unknown');
      f.stowed = true; clearAssignmentsFor(d, uid);
      return done(uid);
    });
  }
  function demolishFacility(state, uid) {
    return run(state, 'ship.demolish', d => {
      const bad = requirePort(d); if (bad) return bad;
      const i = d.ship.facilities.findIndex(q => q.uid === uid);
      if (i < 0) return fail('err.unknown');
      const f = d.ship.facilities[i];
      if (f.id === 'captains_cabin') return fail('err.cannot_demolish_cabin');
      const ref = Rules.demolishRefund(f);
      d.inventory.gold += ref.gold; d.inventory.materials += ref.materials;
      if (ref.specialty) addSpecialty(d, ref.specialty[0], Math.floor(ref.specialty[1] / 2));
      clearAssignmentsFor(d, uid);
      d.ship.facilities.splice(i, 1);
      log(d, 'log.demolished', { facility: 'fac.' + f.id + '.name', gold: ref.gold, materials: ref.materials });
      return done(ref);
    });
  }
  function upgradeFacility(state, uid) {
    return run(state, 'ship.upgrade', d => {
      const bad = requirePort(d); if (bad) return bad;
      const f = d.ship.facilities.find(q => q.uid === uid);
      if (!f) return fail('err.unknown');
      if (f.level >= 3) return fail('err.max_level');
      if (f.level + 1 > d.ship.hullTier + 1) return fail('err.hull_tier', { tier: f.level });
      const c = pay(d, Rules.upgradeCost(f)); if (c) return c;
      f.level++;
      log(d, 'log.upgraded', { facility: 'fac.' + f.id + '.name', level: f.level });
      return done(f.level);
    });
  }
  function stairOpen(ship, deck, x, y) {
    const dk = ship.decks[deck];
    if (!dk || Rules.fixedKind(dk, x, y)) return false;
    if (dk.entry && dk.entry[0] === x && dk.entry[1] === y) return false;
    if (Rules.occupancy(ship)[deck + ':' + x + ':' + y]) return false;
    return !Rules.stairAt(ship, deck, x, y);
  }
  function placeStair(state, deck, x, y) {
    return run(state, 'ship.stair', d => {
      const bad = requirePort(d); if (bad) return bad;
      if (deck + 1 >= d.ship.decks.length) return fail('err.no_lower_deck');
      if (!stairOpen(d.ship, deck, x, y) || !stairOpen(d.ship, deck + 1, x, y)) return fail('err.cell_blocked');
      const c = pay(d, Content.STRUCTURES.stair.cost); if (c) return c;
      d.ship.stairs.push({ deck, x, y });
      return done();
    });
  }
  function removeStair(state, index) {
    return run(state, 'ship.unstair', d => {
      const bad = requirePort(d); if (bad) return bad;
      if (!d.ship.stairs[index]) return fail('err.unknown');
      d.ship.stairs.splice(index, 1);
      d.inventory.materials += Math.floor(Content.STRUCTURES.stair.cost.materials / 2);
      return done();
    });
  }
  function toggleDoor(state, deck, y) {
    return run(state, 'ship.door', d => {
      const bad = requirePort(d); if (bad) return bad;
      const dk = d.ship.decks[deck];
      if (!dk || dk.bulkhead == null || y <= 0 || y >= dk.h - 1) return fail('err.bad_cell');
      const i = dk.doors.findIndex(([, dy]) => dy === y);
      if (i >= 0) { dk.doors.splice(i, 1); return done(false); }
      const c = pay(d, Content.STRUCTURES.door.cost); if (c) return c;
      dk.doors.push([dk.bulkhead, y]);
      return done(true);
    });
  }
  function savePreset(state, index) {
    return run(state, 'ship.preset_save', d => {
      if (index < 0 || index > 2) return fail('err.unknown');
      d.ship.presets[index] = {
        hullTier: d.ship.hullTier,
        facilities: d.ship.facilities.map(f => ({ id: f.id, deck: f.deck, x: f.x, y: f.y, rot: f.rot, stowed: f.stowed })),
        stairs: d.ship.stairs.map(s => Object.assign({}, s)), doors: d.ship.decks.map(dk => dk.doors.map(x => x.slice()))
      };
      return done(index);
    });
  }
  // Apply a stored layout to owned facilities; anything that no longer fits is stowed.
  function applyPreset(state, index) {
    return run(state, 'ship.preset_apply', d => {
      const bad = requirePort(d); if (bad) return bad;
      const pr = d.ship.presets[index];
      if (!pr) return fail('err.no_preset');
      const owned = d.ship.facilities.slice();
      for (const f of owned) f.stowed = true;
      d.ship.stairs = [];
      d.ship.decks.forEach((dk, i) => { if (dk.bulkhead != null && pr.doors[i]) dk.doors = pr.doors[i].filter(([x]) => x === dk.bulkhead).map(x => x.slice()); });
      for (const s of pr.stairs) if (s.deck + 1 < d.ship.decks.length) d.ship.stairs.push(Object.assign({}, s));
      const used = new Set();
      for (const p of pr.facilities) {
        if (p.stowed) continue;
        const f = owned.find(o => o.id === p.id && !used.has(o.uid));
        if (!f) continue;
        used.add(f.uid);
        if (Rules.canPlace(d.ship, f.id, p.deck, p.x, p.y, p.rot, f.uid).ok) Object.assign(f, { deck: p.deck, x: p.x, y: p.y, rot: p.rot, stowed: false });
      }
      d.ship.stairs = d.ship.stairs.filter(s => stairCellsFree(d.ship, s));
      for (const f of owned) if (f.stowed) clearAssignmentsFor(d, f.uid);
      return done(index);
    });
  }
  function stairCellsFree(ship, s) {
    const occ = Rules.occupancy(ship);
    return [s.deck, s.deck + 1].every(dd => ship.decks[dd] && !Rules.fixedKind(ship.decks[dd], s.x, s.y) && !occ[dd + ':' + s.x + ':' + s.y]);
  }
  function deletePreset(state, index) {
    return run(state, 'ship.preset_delete', d => { if (!d.ship.presets[index]) return fail('err.no_preset'); d.ship.presets[index] = null; return done(); });
  }
  function upgradeHull(state, hullId) {
    return run(state, 'ship.hull', d => {
      const bad = requirePort(d); if (bad) return bad;
      const hull = Content.hull(hullId);
      if (!hull) return fail('err.unknown');
      const av = Rules.hullAvailable(d, hull);
      if (!av.ok) return av;
      const c = pay(d, hull.cost); if (c) return c;
      const oldDecks = d.ship.decks;
      d.ship.hullId = hull.id; d.ship.hullTier = hull.tier;
      d.ship.decks = hull.decks.map((hd, i) => {
        const nd = State.makeDeck(hd, i);
        const od = oldDecks[i];
        if (od && od.bulkhead === nd.bulkhead) nd.doors = od.doors.map(x => x.slice());
        return nd;
      });
      for (const f of d.ship.facilities) {
        if (f.stowed) continue;
        if (!Rules.canPlace(d.ship, f.id, f.deck, f.x, f.y, f.rot, f.uid).ok) { f.stowed = true; clearAssignmentsFor(d, f.uid); }
      }
      d.ship.stairs = d.ship.stairs.filter(s => stairCellsFree(d.ship, s));
      log(d, 'log.hull_upgraded', { hull: 'hull.' + hull.id + '.name' });
      return done(hull.id, 'save.reason_hull');
    });
  }
  function repairShip(state) {
    return run(state, 'ship.repair', d => {
      if (d.encounter) return fail('err.in_encounter');
      const rc = Rules.repairCost(d);
      if (!rc.needed) return fail('err.nothing_to_repair');
      if (Rules.atPort(d)) {
        const c = pay(d, { gold: rc.gold, materials: rc.materials }); if (c) return c;
      } else {
        if (!Rules.facLevel(d, 'workshop', { allowDamaged: true })) return fail('err.need_workshop');
        const c = pay(d, { materials: Math.ceil(rc.materials * 1.5) }); if (c) return c;
      }
      d.ship.damage = 0;
      for (const f of d.ship.facilities) f.damaged = false;
      advanceClock(d, 2);
      log(d, 'log.repaired', {});
      return done();
    });
  }

  // ================================================================== CREW
  function recruit(state, index) {
    return run(state, 'crew.recruit', d => {
      const bad = requirePort(d); if (bad) return bad;
      const portId = here(d);
      const pool = Rules.tavernPool(d, portId);
      const offer = pool[index];
      if (!offer) return fail('err.unknown');
      if (offer.hired) return fail('err.already_hired');
      const cap = Rules.crewCapacity(d);
      if (d.crew.length >= cap) return fail('err.over_capacity');
      const c = pay(d, { gold: offer.cost }); if (c) return c;
      const m = State.clone(offer.member);
      m.id = State.nextId(d, 'crew');
      if (m.eventId === 'homesick') m.event.armed = originRegion(m) !== hereRegion(d);
      d.crew.push(m);
      const free = d.formation.indexOf(null);
      if (free >= 0) d.formation[free] = m.id;
      const rot = Rules.rotation(d);
      const tv = d.world.taverns[portId];
      if (!tv || tv.rotation !== rot) d.world.taverns[portId] = { rotation: rot, hired: [index] };
      else tv.hired.push(index);
      d.codex.classes[m.classId] = true;
      log(d, 'log.recruited', { crew: m.id });
      return done(m.id);
    });
  }
  function dismiss(state, crewId) {
    return run(state, 'crew.dismiss', d => {
      const bad = requirePort(d); if (bad) return bad;
      if (d.crew.length <= 1) return fail('err.last_crew');
      const i = d.crew.findIndex(m => m.id === crewId);
      if (i < 0) return fail('err.unknown');
      d.crew.splice(i, 1);
      d.formation = d.formation.map(x => (x === crewId ? null : x));
      for (const p of d.pets) if (p.assignment && p.assignment.kind === 'companion' && p.assignment.target === crewId) p.assignment = null;
      return done();
    });
  }
  function setFormation(state, slot, crewId) {
    return run(state, 'crew.formation', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.atPort(d) && !Rules.facLevel(d, 'muster_deck', { allowDamaged: true })) return fail('err.need_muster');
      if (slot < 0 || slot > 5) return fail('err.unknown');
      if (crewId && !Rules.member(d, crewId)) return fail('err.unknown');
      const prev = d.formation[slot];
      const from = crewId ? d.formation.indexOf(crewId) : -1;
      if (from >= 0) d.formation[from] = prev;
      d.formation[slot] = crewId || null;
      if (!d.formation.some(Boolean)) return fail('err.empty_formation');
      for (const p of d.pets) if (p.assignment && p.assignment.kind === 'companion' && !d.formation.includes(p.assignment.target)) p.assignment = null;
      return done();
    });
  }
  function assignJob(state, crewId, facUid) {
    return run(state, 'crew.job', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const m = Rules.member(d, crewId);
      if (!m) return fail('err.unknown');
      if (facUid) {
        const f = d.ship.facilities.find(q => q.uid === facUid);
        if (!f) return fail('err.unknown');
        const lay = Rules.layoutOf(d);
        if (!lay.facilities[f.uid].reachable) return fail('warn.facility_unreachable', { deck: f.deck + 1 });
        const slots = Rules.jobSlots(f);
        if (!slots) return fail('err.no_job_slots');
        const used = d.crew.filter(x => x.jobFacilityUid === f.uid && x.id !== crewId).length;
        if (used >= slots) return fail('err.job_full');
      }
      m.jobFacilityUid = facUid || null;
      return done();
    });
  }
  function changeClass(state, crewId, classId) {
    return run(state, 'crew.respec', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.atPort(d) && !Rules.facLevel(d, 'class_hall')) return fail('err.need_class_hall');
      const m = Rules.member(d, crewId);
      const cls = Content.CLASSES[classId];
      if (!m || !cls) return fail('err.unknown');
      if (m.classId === classId) return fail('err.same_class');
      if (!Rules.qualifiedFor(m, classId)) return fail('err.not_qualified', { cls: 'class.' + cls.parent + '.name' });
      const c = pay(d, Rules.respecCost(m)); if (c) return c;
      const fromId = m.classId;
      m.classId = classId;
      if (m.mastery[classId] == null) m.mastery[classId] = 0;
      m.legacy = m.legacy.filter(p => p !== cls.passive);
      const w = Rules.equipInst(d, m.equipment.weapon);
      if (w && !Rules.weaponCompatible(classId, w.itemId)) { m.equipment.weapon = null; log(d, 'log.unequipped', { crew: m.id, item: itemNameKey(w.itemId) }); }
      d.codex.classes[classId] = true;
      log(d, 'log.respec', { crew: m.id, from: 'class.' + fromId + '.name', to: 'class.' + classId + '.name' });
      return done();
    });
  }
  function setLegacy(state, crewId, slot, passiveId) {
    return run(state, 'crew.legacy', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const m = Rules.member(d, crewId);
      if (!m || slot < 0 || slot >= T.legacySlots) return fail('err.unknown');
      if (passiveId) {
        if (!Rules.legacyOptions(m).includes(passiveId)) return fail('err.not_mastered');
        if (m.legacy.includes(passiveId) && m.legacy[slot] !== passiveId) return fail('err.legacy_duplicate');
      }
      const next = m.legacy.slice();
      next[slot] = passiveId || null;
      m.legacy = next.filter(Boolean).slice(0, T.legacySlots);
      return done();
    });
  }
  function equip(state, crewId, slot, eqUid) {
    return run(state, 'crew.equip', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const m = Rules.member(d, crewId);
      if (!m || !['weapon', 'outfit', 'accessory'].includes(slot)) return fail('err.unknown');
      if (eqUid) {
        const inst = Rules.equipInst(d, eqUid);
        if (!inst) return fail('err.unknown');
        const it = Content.ITEMS[inst.itemId];
        if (it.slot !== slot) return fail('err.wrong_slot');
        if (!Rules.weaponCompatible(m.classId, inst.itemId)) return fail('err.weapon_incompatible', { cls: 'class.' + m.classId + '.name' });
        for (const o of d.crew) for (const s of ['weapon', 'outfit', 'accessory']) if (o.equipment[s] === eqUid) o.equipment[s] = null;
      }
      m.equipment[slot] = eqUid || null;
      return done();
    });
  }
  function rename(state, crewId, nickname) {
    return run(state, 'crew.rename', d => {
      const m = Rules.member(d, crewId);
      if (!m) return fail('err.unknown');
      const n = String(nickname || '').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, 18);
      m.nickname = n || null;
      return done();
    });
  }
  function treat(state, crewId) {
    return run(state, 'crew.treat', d => {
      if (d.encounter) return fail('err.in_encounter');
      const m = Rules.member(d, crewId);
      if (!m) return fail('err.unknown');
      if (!m.injured) return fail('err.not_injured');
      if (Rules.atPort(d)) {
        const rr = Rules.facLevel(d, 'recovery_room');
        const day = Rules.day(d);
        const used = d.captain.flags.recoveryDay === day ? d.captain.flags.recoveryUsed || 0 : 0;
        if (rr && used < rr) { d.captain.flags.recoveryDay = day; d.captain.flags.recoveryUsed = used + 1; }
        else { const c = pay(d, { gold: Rules.treatCost(m).gold }); if (c) return c; }
      } else {
        if (!Rules.facLevel(d, 'infirmary')) return fail('err.need_infirmary');
        const c = pay(d, { supplies: 1 }); if (c) return c;
      }
      m.injured = false;
      advanceClock(d, 2);
      log(d, 'log.treated', { crew: m.id });
      return done();
    });
  }
  function crewEventDeliver(state, crewId) {
    return run(state, 'crew.event', d => {
      const bad = requirePort(d); if (bad) return bad;
      const m = Rules.member(d, crewId);
      if (!m || m.eventId !== 'collector' || m.event.status !== 'active') return fail('err.unknown');
      const spec = World.region(originRegion(m)).specialtyId;
      const c = pay(d, { specialty: [spec, 1] }); if (c) return c;
      finishCrewEvent(d, m);
      return done();
    });
  }

  // ============================================================= EQUIPMENT
  function buyItem(state, itemId) {
    return run(state, 'eq.buy', d => {
      const bad = requirePort(d); if (bad) return bad;
      if (!Rules.shopItems(d, here(d)).includes(itemId)) return fail('err.not_sold');
      if (d.inventory.equipment.length >= Rules.equipCapacity(d)) return fail('err.equip_full');
      const c = pay(d, { gold: Rules.itemPrice(itemId) }); if (c) return c;
      return done(addEquipment(d, itemId).uid);
    });
  }
  function craftItem(state, itemId, affix) {
    return run(state, 'eq.craft', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.canCraftHere(d)) return fail('err.need_workshop');
      if (!d.inventory.recipes.includes(itemId)) return fail('err.no_recipe');
      if (affix && !Content.AFFIXES[affix]) return fail('err.unknown');
      if (affix && !Rules.canReinforceHere(d)) return fail('err.need_workshop2');
      if (d.inventory.equipment.length >= Rules.equipCapacity(d)) return fail('err.equip_full');
      const cost = Rules.craftCost(itemId, affix, d);
      if (!cost) return fail('err.no_recipe');
      const c = pay(d, cost); if (c) return c;
      advanceClock(d, 1);
      const inst = addEquipment(d, itemId, { affix });
      log(d, 'log.crafted', { item: itemNameKey(itemId) });
      return done(inst.uid);
    });
  }
  function reinforce(state, eqUid) {
    return run(state, 'eq.reinforce', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.canReinforceHere(d)) return fail('err.need_workshop2');
      const inst = Rules.equipInst(d, eqUid);
      if (!inst) return fail('err.unknown');
      if ((inst.reinforce || 0) >= 3) return fail('err.max_level');
      const c = pay(d, Rules.reinforceCost(inst, d)); if (c) return c;
      inst.reinforce = (inst.reinforce || 0) + 1;
      return done(inst.reinforce);
    });
  }
  function salvage(state, eqUid) {
    return run(state, 'eq.salvage', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.atPort(d) && !Rules.facLevel(d, 'material_bench') && !Rules.facLevel(d, 'workshop')) return fail('err.need_bench');
      const i = d.inventory.equipment.findIndex(e => e.uid === eqUid);
      if (i < 0) return fail('err.unknown');
      if (d.crew.some(m => Object.values(m.equipment).includes(eqUid))) return fail('err.equipped');
      const inst = d.inventory.equipment[i];
      const v = Rules.salvageValue(inst);
      const bench = Rules.facLevel(d, 'material_bench');
      const mats = Math.round(v.materials * (1 + 0.15 * bench));
      d.inventory.equipment.splice(i, 1);
      d.inventory.materials += mats;
      return done(mats);
    });
  }

  // ================================================================= PORTS
  function invest(state, track) {
    return run(state, 'port.invest', d => {
      const bad = requirePort(d); if (bad) return bad;
      const portId = here(d);
      if (!Content.INVESTMENT_TRACKS.includes(track)) return fail('err.unknown');
      const cost = Rules.investCost(d, portId, track);
      if (!cost) return fail('err.max_level');
      const c = pay(d, cost); if (c) return c;
      d.world.ports[portId].tracks[track] = cost.level;
      d.captain.reputation.league += 3;
      const reg = World.region(World.PORTS[portId].regionId);
      if (track === 'navigation' && cost.level >= 2) {
        const [a, b] = reg.locs.slice(0, 2);
        if (Rules.isVisited(d, a) && Rules.isVisited(d, b)) { const k = Rules.routeKey(a, b); if (!d.world.chartedRoutes.includes(k)) d.world.chartedRoutes.push(k); }
      }
      if (track === 'navigation' && cost.level >= 3) reg.locs.slice(0, 9).forEach(id => reveal(d, id));
      if (track === 'quest_board' && cost.level >= 3) reveal(d, reg.locs[9]);
      log(d, 'log.invested', { port: locName(portId), track: 'track.' + track + '.name', level: cost.level });
      return done(cost.level);
    });
  }
  function buyGoods(state, kind, id, qty) {
    return run(state, 'port.buy', d => {
      const bad = requirePort(d); if (bad) return bad;
      const portId = here(d);
      const n = Math.max(1, Math.min(99, qty | 0 || 1));
      const pr = Rules.prices(d, portId);
      const m = Rules.portTrack(d, portId, 'market');
      if (kind === 'food') {
        if (d.inventory.food + n > Rules.foodCapacity(d)) return fail('err.food_full');
        const c = pay(d, { gold: pr.food * n }); if (c) return c;
        d.inventory.food += n;
      } else if (kind === 'supplies') {
        if (m < 1) return fail('err.market_level', { level: 1 });
        if (d.inventory.supplies + n > Rules.supplyCapacity(d)) return fail('err.supplies_full');
        const c = pay(d, { gold: pr.supplies * n }); if (c) return c;
        d.inventory.supplies += n;
      } else if (kind === 'ingredient') {
        if (m < 1) return fail('err.market_level', { level: 1 });
        if (!Content.INGREDIENTS[id]) return fail('err.unknown');
        const c = pay(d, { gold: pr.ingredient * n }); if (c) return c;
        addIngredient(d, id, n);
      } else if (kind === 'specialty') {
        if (m < 2) return fail('err.market_level', { level: 2 });
        if (id !== World.region(World.PORTS[portId].regionId).specialtyId) return fail('err.not_sold');
        const c = pay(d, { gold: Rules.specialtyBuyPrice(d, portId, id) * n }); if (c) return c;
        addSpecialty(d, id, n);
      } else if (kind === 'egg') {
        if (m < 3) return fail('err.market_level', { level: 3 });
        const fam = World.region(World.PORTS[portId].regionId).petFamilyId;
        const c = pay(d, { gold: pr.egg }); if (c) return c;
        addEgg(d, fam, 1);
      } else return fail('err.unknown');
      return done(n);
    });
  }
  function sellSpecialty(state, specId, qty) {
    return run(state, 'port.sell', d => {
      const bad = requirePort(d); if (bad) return bad;
      const n = Math.max(1, qty | 0 || 1);
      if ((d.inventory.specialties[specId] || 0) < n) return fail('err.no_specialty', { item: 'spec.' + specId + '.name', need: n });
      const price = Rules.specialtySellPrice(d, here(d), specId);
      d.inventory.specialties[specId] -= n;
      d.inventory.gold += price * n;
      return done(price * n);
    });
  }
  function acceptQuest(state, qid) {
    return run(state, 'port.quest', d => {
      const bad = requirePort(d); if (bad) return bad;
      const q = World.QUESTS[qid];
      if (!q || q.kind !== 'side') return fail('err.unknown');
      if (q.giverId !== here(d)) return fail('err.wrong_port');
      if (Rules.portTrack(d, here(d), 'quest_board') < 1) return fail('err.board_level', { level: 1 });
      if (d.world.quests[qid]) return fail('err.already_accepted');
      d.world.quests[qid] = { status: 'active' };
      if (q.type === 'discover') reveal(d, q.locationId);
      if (q.template !== 'legend') reveal(d, q.locationId);
      log(d, 'log.quest_accepted', { quest: q.titleKey, location: locName(q.locationId) });
      return done(qid);
    });
  }
  function acceptContract(state, contractId) {
    return run(state, 'port.contract', d => {
      const bad = requirePort(d); if (bad) return bad;
      const offer = Rules.contractOffers(d, here(d)).find(c => c.id === contractId);
      if (!offer) return fail('err.unknown');
      if (d.world.contracts[contractId]) return fail('err.already_accepted');
      if (Rules.activeContracts(d).length >= 3) return fail('err.contract_limit');
      d.world.contracts[contractId] = { status: 'active', progress: 0, type: offer.type, portId: offer.portId, regionId: offer.regionId, need: offer.need, specialtyId: offer.specialtyId || null, reward: offer.reward };
      return done(contractId);
    });
  }
  function completeContract(state, contractId) {
    return run(state, 'port.contract_done', d => {
      const bad = requirePort(d); if (bad) return bad;
      const c = d.world.contracts[contractId];
      if (!c || c.status !== 'active') return fail('err.unknown');
      if (c.portId !== here(d)) return fail('err.wrong_port');
      if (c.type === 'hunt' && c.progress < c.need) return fail('err.contract_incomplete', { have: c.progress, need: c.need });
      if (c.type === 'supply') { const p = pay(d, { food: c.need }); if (p) return p; }
      if (c.type === 'haul') { const p = pay(d, { specialty: [c.specialtyId, c.need] }); if (p) return p; }
      c.status = 'done';
      d.inventory.gold += c.reward.gold; d.inventory.materials += c.reward.materials;
      d.captain.reputation.league += c.reward.rep;
      log(d, 'log.contract_done', { gold: c.reward.gold });
      return done();
    });
  }
  function deliverMain(state) {
    return run(state, 'main.deliver', d => {
      const bad = requirePort(d); if (bad) return bad;
      const ms = Rules.mainStatus(d);
      if (ms.done || ms.quest.type !== 'deliver') return fail('err.nothing_to_deliver');
      if (ms.quest.locationId !== here(d)) return fail('err.wrong_port');
      const c = pay(d, { specialty: [ms.quest.itemId, ms.quest.count] }); if (c) return c;
      completeMain(d, ms.quest);
      return done();
    });
  }
  // Free emergency assistance so a captain can never be soft-locked (GDD §11.2).
  function emergencyAid(state, kind) {
    return run(state, 'port.aid', d => {
      const bad = requirePort(d); if (bad) return bad;
      if (!Rules.emergencyNeeds(d).includes(kind)) return fail('err.aid_not_needed');
      if (kind === 'meal') { d.inventory.food += 2; d.ship.stamina = Math.min(d.ship.staminaMax, Math.max(d.ship.stamina, 30)); }
      if (kind === 'treatment') for (const m of d.crew) m.injured = false;
      if (kind === 'repair') { d.ship.damage = Math.min(d.ship.damage, 10); for (const f of d.ship.facilities) f.damaged = false; }
      d.captain.flags.aidCount = (d.captain.flags.aidCount || 0) + 1;
      log(d, 'log.aid', { kind: 'aid.' + kind });
      return done(kind);
    });
  }
  function dockWork(state) {
    return run(state, 'port.work', d => {
      const bad = requirePort(d); if (bad) return bad;
      if (!Rules.recoveryContractAvailable(d)) return fail('err.aid_not_needed');
      const t = Rules.regionTierOfPort(here(d));
      advanceClock(d, 6);
      d.inventory.food += 3;
      d.inventory.gold += 20 + 5 * t;
      log(d, 'log.dock_work', { gold: 20 + 5 * t });
      return done();
    });
  }
  function waitAtPort(state) {
    return run(state, 'port.wait', d => {
      const bad = requirePort(d); if (bad) return bad;
      advanceClock(d, 24);
      log(d, 'log.waited', {});
      return done();
    });
  }

  // =============================================================== STAMINA
  function serveRation(state) {
    return run(state, 'stamina.ration', d => {
      if (d.encounter) return fail('err.in_encounter');
      if (d.ship.stamina >= d.ship.staminaMax) return fail('err.stamina_full');
      const c = pay(d, { food: T.rationFood }); if (c) return c;
      const gainSt = T.rationStamina + 3 * Rules.facLevel(d, 'mess_hall');
      d.ship.stamina = Math.min(d.ship.staminaMax, d.ship.stamina + gainSt);
      d.captain.stats.rations++;
      for (const m of d.crew) if (m.eventId === 'feast' && m.event.status === 'active') m.event.progress++;
      return done(gainSt);
    });
  }
  function useSupply(state) {
    return run(state, 'stamina.supply', d => {
      if (d.encounter) return fail('err.in_encounter');
      if (d.ship.stamina >= d.ship.staminaMax) return fail('err.stamina_full');
      const c = pay(d, { supplies: 1 }); if (c) return c;
      let pct = 0;
      for (const m of Rules.activeCrew(d)) pct = Math.max(pct, Rules.memberStats(d, m).mods.supplyPct || 0);
      const g = Math.round(T.supplyStamina * (1 + pct));
      d.ship.stamina = Math.min(d.ship.staminaMax, d.ship.stamina + g);
      return done(g);
    });
  }
  function produceFood(state) {
    return run(state, 'prod.galley', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const L = Rules.facLevel(d, 'galley');
      if (!L) return fail('err.need_facility', { facility: 'fac.galley.name' });
      const c = pay(d, { materials: 3 }); if (c) return c;
      const n = Math.round((2 + L) * Rules.staffMult(d, 'galley'));
      const got = addFood(d, n);
      if (!got) return fail('err.food_full');
      advanceClock(d, 1);
      return done(got);
    });
  }
  function produceSupplies(state) {
    return run(state, 'prod.workshop', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const L = Rules.facLevel(d, 'workshop');
      if (!L) return fail('err.need_facility', { facility: 'fac.workshop.name' });
      if (d.inventory.supplies >= Rules.supplyCapacity(d)) return fail('err.supplies_full');
      const c = pay(d, { materials: 4 }); if (c) return c;
      const n = Math.max(1, Math.floor((L >= 2 ? 2 : 1) * Rules.staffMult(d, 'workshop')));
      addSupplies(d, n);
      advanceClock(d, 1);
      return done(n);
    });
  }

  // ================================================================ VOYAGE
  function dock(d, portId) {
    const inv = d.inventory;
    const banked = { gold: inv.ledger.gold, materials: inv.ledger.materials };
    inv.gold += banked.gold; inv.materials += banked.materials;
    inv.ledger = { gold: 0, materials: 0 };
    const prev = d.world.lastSafePortId;
    if (prev && prev !== portId) { const k = Rules.routeKey(prev, portId); if (!d.world.chartedRoutes.includes(k)) d.world.chartedRoutes.push(k); }
    d.world.lastSafePortId = portId;
    d.world.currentLocationId = portId;
    d.voyage = null;
    for (const m of d.crew) if (m.eventId === 'homesick' && m.event.status === 'active' && originRegion(m) !== World.location(portId).regionId) m.event.armed = true;
    if (banked.gold || banked.materials) log(d, 'log.banked', banked);
    return banked;
  }
  function arrive(d, toId) {
    const loc = World.location(toId);
    const ls = d.world.locations[toId];
    const first = ls.k === 'hidden' || ls.k === 'revealed';
    if (first) { ls.k = 'visited'; ls.firstVisit = true; }
    d.codex.locations[toId] = true;
    d.captain.regionId = loc.regionId;
    d.world.currentLocationId = toId;
    log(d, 'log.arrived', { location: locName(toId) });
    if (Rules.facLevel(d, 'lookout')) {
      for (const n of World.neighbors(toId)) { const nl = World.location(n); if (nl.type !== 'secret' && nl.regionId === loc.regionId) reveal(d, n); }
    }
    const ex = Rules.explorerPet(d);
    if (ex && first) {
      const secret = World.region(loc.regionId).locs[9];
      if (World.neighbors(toId).includes(secret) && reveal(d, secret)) log(d, 'log.pet_found_secret', {});
      addPetXp(d, ex, 6);
    }
    for (const p of d.pets) if (p.assignment && p.assignment.kind === 'helper') addPetXp(d, p, 3);
    if (World.PORTS[toId]) return dock(d, toId);
    if (d.voyage) d.voyage.site = { locationId: toId, current: null };
    return null;
  }
  function seaEventFor(d, regionId) {
    if (State.nextFloat(d) >= Rules.seaEventChance(d)) return null;
    const w = Rules.seaWeights(d, regionId);
    let total = Object.values(w).reduce((a, b) => a + b, 0);
    let r = State.nextFloat(d) * total;
    for (const k of World.SEA_EVENT_KINDS) { r -= w[k]; if (r < 0) return k; }
    return 'cache';
  }
  // Depart for a revealed destination. Food is charged once per leg here.
  function depart(state, toId, opts) {
    const o = opts || {};
    return run(state, o.fast ? 'voyage.fast' : 'voyage.depart', d => {
      const block = Rules.sailBlock(d, toId, !!o.fast);
      if (block) return fail(block);
      const lay = Rules.layoutOf(d);
      if (Rules.atPort(d) && lay.disabled.length && !o.confirmed) return fail('warn.confirm_unreachable', { n: lay.disabled.length });
      const from = here(d);
      const leg = Rules.legCost(d, from, toId);
      d.inventory.food -= leg.food;
      advanceClock(d, leg.hours);
      d.captain.stats.voyages++;
      if (!d.voyage) d.voyage = { id: State.nextId(d, 'voy'), originPortId: from, at: from, route: null, event: null, site: null };
      d.voyage.route = { from, to: toId, food: leg.food, hours: leg.hours, fast: !!o.fast };
      d.voyage.site = null;
      const toLoc = World.location(toId);
      const kind = o.fast ? null : seaEventFor(d, toLoc.regionId);
      if (kind === 'pirate' || kind === 'monster') {
        const reg = World.region(toLoc.regionId);
        const variant = State.nextInt(d, 0, 999);
        const def = World.seaEncounter(reg.id, kind, variant, Math.max(1, toLoc.level));
        startEncounter(d, def, { type: 'sea', kind, toId, fromId: from });
        log(d, 'log.boarded', { kind: 'sea.' + kind + '.title' });
        return done({ event: kind }, 'save.reason_battle');
      }
      if (kind) {
        d.voyage.event = { kind, regionId: toLoc.regionId, variant: State.nextInt(d, 0, 999) };
        return done({ event: kind });
      }
      const banked = arrive(d, toId);
      return done({ arrived: toId, banked }, World.PORTS[toId] ? 'save.reason_port' : null);
    });
  }
  function resolveSeaEvent(state, choice) {
    return run(state, 'voyage.event', d => {
      if (!d.voyage || !d.voyage.event) return fail('err.no_event');
      const ev = d.voyage.event;
      const t = World.region(ev.regionId).tier;
      const reg = World.region(ev.regionId);
      if (ev.kind === 'cache') { addSupplies(d, 1); gain(d, { materials: 5 + 2 * t }); }
      if (ev.kind === 'vessel') {
        if (choice === 'help') {
          const c = pay(d, { food: 2 }); if (c) return c;
          d.captain.reputation.tidebound += 5; gain(d, { gold: 20 + 10 * t });
        }
      }
      if (ev.kind === 'shortcut') {
        const hidden = reg.locs.filter((id, i) => i !== 9 && d.world.locations[id].k === 'hidden');
        if (hidden.length) reveal(d, hidden[ev.variant % hidden.length]);
        d.world.shortcuts[reg.id] = true;
      }
      if (ev.kind === 'weather') {
        const nav = Rules.activeCrew(d).some(m => Content.baseClassOf(m.classId) === 'navigator');
        if (!Rules.facLevel(d, 'barricade_room') && !nav) { d.ship.damage = Math.min(100, d.ship.damage + 8); advanceClock(d, 2); log(d, 'log.weather_damage', {}); }
      }
      if (ev.kind === 'inspection') {
        if (choice === 'pay') { const c = pay(d, { gold: 10 + 5 * t }); if (c) return c; d.captain.reputation.pennants += 2; }
        else advanceClock(d, 6);
      }
      if (ev.kind === 'clue') {
        if (!addClue(d, 'clue.pet.' + reg.petFamilyId)) d.captain.reputation.tidebound += 3;
        const secret = reg.locs[9];
        if (d.codex.clues.includes('clue.pet.' + reg.petFamilyId)) reveal(d, secret);
      }
      d.voyage.event = null;
      const toId = d.voyage.route.to;
      const banked = arrive(d, toId);
      return done({ arrived: toId, banked }, World.PORTS[toId] ? 'save.reason_port' : null);
    });
  }
  // Always available safe return; no food, gold, or stamina is required.
  function emergencyReturn(state) {
    return run(state, 'voyage.return', d => {
      if (d.encounter) return fail('err.in_encounter');
      if (!d.voyage) return fail('err.already_docked');
      const portId = d.world.lastSafePortId;
      advanceClock(d, 12);
      d.voyage.event = null;
      d.world.locations[portId].k = d.world.locations[portId].k === 'hidden' ? 'visited' : d.world.locations[portId].k;
      d.world.currentLocationId = portId;
      d.captain.regionId = World.location(portId).regionId;
      const banked = dock(d, portId);
      log(d, 'log.emergency_return', { location: locName(portId) });
      return done({ banked }, 'save.reason_port');
    });
  }

  // ----------------------------------------------------------------- rooms
  function roomAccessible(d, locId, roomId) {
    const rooms = World.rooms(locId);
    const cleared = d.world.locations[locId].rooms;
    if (rooms[0] && rooms[0].id === roomId) return true;
    return rooms.some(r => cleared.includes(r.id) && r.next.includes(roomId));
  }
  function enterRoom(state, roomId, opts) {
    const o = opts || {};
    return run(state, 'site.room', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const locId = here(d);
      const loc = World.location(locId);
      if (!d.voyage || !d.voyage.site || d.voyage.site.locationId !== locId) return fail('err.not_at_site');
      const rm = World.room(locId, roomId);
      if (!rm) return fail('err.unknown');
      if (!roomAccessible(d, locId, roomId)) return fail('err.room_locked');
      if (rm.secret && !Rules.explorerPet(d)) return fail('err.need_explorer');
      const cleared = d.world.locations[locId].rooms.includes(roomId);
      const repeat = cleared && o.repeat;
      if (cleared && !repeat) { d.voyage.site.current = roomId; return done({ moved: true }); }
      if (rm.kind === 'trial') {
        const ms = d.captain.mainStep[loc.regionId] || 0;
        if (ms < 4 && !d.captain.trialsWon.includes(loc.regionId)) return fail('err.trial_locked');
      }
      if (repeat && !['battle', 'elite', 'boss', 'trial'].includes(rm.kind)) return fail('err.room_depleted');
      const cost = rm.cost;
      if (d.ship.stamina < cost) return fail('err.no_stamina', { need: cost, have: d.ship.stamina });
      d.ship.stamina -= cost;
      d.voyage.site.current = roomId;
      if (['battle', 'elite', 'boss', 'trial'].includes(rm.kind)) {
        const variant = repeat ? State.nextInt(d, 1, 999) : 0;
        const def = World.encounterFor(locId, roomId, { variant });
        startEncounter(d, def, { type: rm.kind === 'trial' ? 'trial' : 'room', locationId: locId, roomId, repeat: !!repeat });
        return done({ encounter: true }, rm.kind === 'trial' ? 'save.reason_trial' : null);
      }
      const rewards = World.roomRewards(locId, roomId, true);
      const got = applyRewards(d, rewards, loc);
      clearRoom(d, locId, roomId);
      return done({ rewards: got });
    });
  }
  function startLegend(state) {
    return run(state, 'site.legend', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const locId = here(d);
      const loc = World.location(locId);
      if (!d.captain.postgame) return fail('err.postgame_only');
      if (loc.type !== 'arena' || !World.LEGENDS[loc.regionId]) return fail('err.no_legend');
      if (!d.voyage || !d.voyage.site) return fail('err.not_at_site');
      const def = World.encounterFor(locId, 'trial', { legend: true });
      if (d.ship.stamina < def.staminaCost) return fail('err.no_stamina', { need: def.staminaCost, have: d.ship.stamina });
      d.ship.stamina -= def.staminaCost;
      startEncounter(d, def, { type: 'legend', locationId: locId, roomId: 'trial' });
      return done({ encounter: true }, 'save.reason_trial');
    });
  }
  function clearRoom(d, locId, roomId) {
    const ls = d.world.locations[locId];
    if (!ls.rooms.includes(roomId)) ls.rooms.push(roomId);
    const rm = World.room(locId, roomId);
    if (rm.objective && ls.k !== 'cleared') { ls.k = 'cleared'; log(d, 'log.cleared', { location: locName(locId) }); }
  }
  function applyRewards(d, r, loc) {
    const bonus = 1 + Math.max(0, ...Rules.activeCrew(d).map(m => Rules.memberStats(d, m).mods.lootPct || 0));
    const goldPct = 1 + Math.max(0, ...Rules.activeCrew(d).map(m => Rules.memberStats(d, m).mods.goldPct || 0));
    const bench = 1 + 0.15 * Rules.facLevel(d, 'material_bench') * Rules.staffMult(d, 'material_bench');
    const out = { gold: Math.round(r.gold * goldPct), materials: Math.round(r.materials * bonus * bench), items: [] };
    gain(d, out);
    if (r.food) out.food = addFood(d, r.food);
    if (r.supplies) out.supplies = addSupplies(d, r.supplies);
    const reg = loc ? World.region(loc.regionId) : null;
    if (r.specialty && reg) { const n = Math.round(r.specialty * bonus); addSpecialty(d, reg.specialtyId, n); out.specialty = [reg.specialtyId, n]; }
    if (r.ingredient) {
      const keys = Object.keys(Content.INGREDIENTS);
      out.ingredients = [];
      for (let i = 0; i < r.ingredient; i++) { const ing = State.pick(d, keys); addIngredient(d, ing, 1); out.ingredients.push(ing); }
    }
    if (r.egg) { addEgg(d, r.egg.familyId, r.egg.grade); out.egg = r.egg; }
    for (const it of r.items) { const inst = addEquipment(d, it); if (inst) out.items.push(it); }
    if (r.unique && !d.inventory.uniques.includes(r.unique)) { const inst = addEquipment(d, r.unique); if (inst) out.items.push(r.unique); }
    if (r.clue) { addClue(d, r.clue); out.clue = r.clue; }
    if (r.shortcut && reg) d.world.shortcuts[reg.id] = true;
    return out;
  }

  // ============================================================ ENCOUNTERS
  function buildAllies(d, restriction) {
    let allies = [];
    d.formation.forEach((id, slot) => {
      if (!id) return;
      const m = Rules.member(d, id);
      if (!m) return;
      const stats = Rules.memberStats(d, m);
      const pet = d.pets.find(p => p.assignment && p.assignment.kind === 'companion' && p.assignment.target === m.id);
      let petSpec = null;
      if (pet && Rules.petRoles(pet).includes('companion')) {
        const fam = Content.petFamily(pet.familyId);
        petSpec = { petId: pet.id, speciesId: pet.speciesId, familyId: pet.familyId, ability: fam.ability, evolved: !!pet.evolved, mult: Math.round(Rules.petPowerMult(pet, m, stats) * 100) / 100 };
      }
      allies.push({ key: m.id, classId: m.classId, level: m.level, slot, lane: Rules.laneOfSlot(slot), stats, pet: petSpec, name: m.nickname });
    });
    if (restriction === 'four_crew') allies = allies.slice(0, 4);
    return allies;
  }
  function battleBonuses(d, def) {
    const b = { startMeter: 10 * Rules.facLevel(d, 'muster_deck') * Rules.staffMult(d, 'muster_deck') };
    if (def.arena === 'boarding') {
      b.startMeter += 25 * Rules.facLevel(d, 'boarding_gate') * Rules.staffMult(d, 'boarding_gate');
      b.boardingTaken = Math.min(0.4, 0.08 * Rules.facLevel(d, 'barricade_room') * Rules.staffMult(d, 'barricade_room'));
      b.frontShield = 0.08 * Rules.facLevel(d, 'guard_post') * Rules.staffMult(d, 'guard_post');
    }
    b.startMeter = Math.min(80, Math.round(b.startMeter));
    return b;
  }
  function startEncounter(d, def, context) {
    const attemptId = State.nextId(d, 'enc');
    const allies = buildAllies(d, def.restriction);
    const spec = {
      allies, waves: def.waves, modifiers: def.modifiers, seed: State.nextU32(d) || 1,
      stance: d.tactics.stance, priority: d.tactics.priority, bonuses: battleBonuses(d, def), retreatSecs: def.retreat ? def.retreat.escapeSecs : 3
    };
    d.encounter = { attemptId, def, spec, context, startedAt: d.envelope.gameClock };
    for (const w of def.waves) for (const e of w) d.codex.enemies[e.enemyId] = d.codex.enemies[e.enemyId] || { seen: true, defeated: 0 };
    return attemptId;
  }
  function setTactics(state, stance, priority) {
    return run(state, 'tactics', d => {
      if (stance && !Content.STANCES.includes(stance)) return fail('err.unknown');
      if (priority && !Content.PRIORITIES.includes(priority)) return fail('err.unknown');
      if (stance) d.tactics.stance = stance;
      if (priority) d.tactics.priority = priority;
      if (d.encounter) { d.encounter.spec.stance = d.tactics.stance; d.encounter.spec.priority = d.tactics.priority; }
      return done();
    });
  }
  function battleXp(def) {
    const kindMult = { battle: 1, elite: 1.25, boss: 1.6, trial: 2, boarding: 1 }[def.kind] || 1;
    let xp = 0;
    for (const w of def.waves) for (const e of w) xp += 8 + 3 * e.level;
    return xp * kindMult;
  }
  function levelGapXp(m, lvl) { const gap = m.level - lvl; return gap <= 2 ? 1 + Math.max(0, -gap) * 0.05 : Math.max(0.2, 1 - 0.15 * (gap - 2)); }
  function addPetXp(d, p, xp) {
    p.xp += xp;
    while (p.level < 30 && p.xp >= Rules.petXpToNext(p.level)) { p.xp -= Rules.petXpToNext(p.level); p.level++; }
  }
  // Resolve the active encounter. The same attempt can only commit once; a
  // repeat call (e.g. after a reload) returns the stored result unchanged.
  function resolveEncounter(state, attemptId, commands) {
    if (state.committed[attemptId]) return { ok: true, state, value: state.committed[attemptId], duplicate: true };
    return run(state, 'encounter.resolve', d => {
      const enc = d.encounter;
      if (!enc || enc.attemptId !== attemptId) return fail('err.no_encounter');
      const cmds = (commands || []).filter(c => c && Number.isInteger(c.tick) && c.tick >= 0 && ['focus', 'stance', 'priority', 'retreat'].includes(c.type)).slice(0, 400);
      const res = Combat.resolve(enc.spec, cmds);
      const ctx = enc.context;
      const def = enc.def;
      const hpVals = Object.values(res.allyHp);
      const summary = { attemptId, outcome: res.outcome, reason: res.reason, time: res.time, context: ctx, rewards: null, losses: null, injured: [], allyHp: res.allyHp, hpAvg: hpVals.length ? Math.round(100 * hpVals.reduce((a, b) => a + b, 0) / hpVals.length) / 100 : 0, defId: def.id, kind: def.kind };
      for (const id of res.enemiesDefeated) { const c = d.codex.enemies[id] || (d.codex.enemies[id] = { seen: true, defeated: 0 }); c.defeated++; }
      d.encounter = null;
      if (res.outcome === 'victory') victory(d, def, ctx, res, summary);
      else if (res.outcome === 'retreat') retreatOutcome(d, ctx, summary);
      else defeat(d, def, ctx, res, summary);
      State.recordAttempt(d, attemptId, summary);
      return done(summary, 'save.reason_battle');
    });
  }
  function victory(d, def, ctx, res, summary) {
    d.captain.stats.battlesWon++;
    const xp = battleXp(def);
    const k = xpMult(d);
    const practice = Rules.facLevel(d, 'practice_deck');
    const lvl = def.level;
    const classHall = Rules.facLevel(d, 'class_hall');
    for (const m of d.crew) {
      const fought = enc_has(res, m.id);
      if (fought) {
        addMemberXp(d, m, xp * k * levelGapXp(m, lvl));
        const mods = Rules.memberStats(d, m).mods;
        const mast = T.masteryPerBattle * (def.kind === 'boss' || def.kind === 'trial' ? 2 : 1) * (1 + (mods.masteryPct || 0) + 0.2 * classHall);
        m.mastery[m.classId] = Math.round(((m.mastery[m.classId] || 0) + mast) * 10) / 10;
        if (m.eventId === 'proving' && m.event.status === 'active') m.event.progress++;
      } else if (practice) addMemberXp(d, m, xp * k * (0.3 + 0.15 * practice) * levelGapXp(m, lvl));
    }
    for (const p of d.pets) if (p.assignment && p.assignment.kind === 'companion' && enc_has(res, p.assignment.target)) addPetXp(d, p, Math.round(4 + def.level));
    const loc = ctx.locationId ? World.location(ctx.locationId) : World.location(ctx.toId);
    const reg = World.region(loc.regionId);
    for (const c of Rules.activeContracts(d)) if (c.type === 'hunt' && c.regionId === reg.id) d.world.contracts[c.id].progress++;
    let rewards;
    if (ctx.type === 'sea') {
      const pen = 1 + 0.05 * Rules.repRank(d, 'pennants');
      rewards = applyRewards(d, { gold: Math.round((15 + 12 * reg.tier) * pen), materials: 4 + 2 * reg.tier, food: 0, supplies: 0, specialty: 0, ingredient: ctx.kind === 'monster' ? 1 : 0, items: [] }, loc);
      if (ctx.kind === 'pirate') d.captain.reputation.pennants += 1;
    } else if (ctx.type === 'legend') {
      const lg = World.LEGENDS[loc.regionId];
      const first = !d.captain.legendsWon.includes(loc.regionId);
      rewards = applyRewards(d, Object.assign(World.roomRewards(ctx.locationId, 'trial', false), first ? { unique: lg.reward } : {}), loc);
      if (first) { d.captain.legendsWon.push(loc.regionId); log(d, 'log.legend_won', { region: 'region.' + loc.regionId + '.name' }); }
    } else {
      const first = !d.world.locations[ctx.locationId].rooms.includes(ctx.roomId);
      rewards = applyRewards(d, World.roomRewards(ctx.locationId, ctx.roomId, first), loc);
      clearRoom(d, ctx.locationId, ctx.roomId);
      if (ctx.type === 'trial' && !d.captain.trialsWon.includes(loc.regionId)) {
        d.captain.trialsWon.push(loc.regionId);
        log(d, 'log.trial_won', { region: 'region.' + loc.regionId + '.name', rival: 'enemy.' + reg.rivalId + '.name' });
      }
    }
    if (res.plunder) { gain(d, { gold: res.plunder }); rewards.gold += res.plunder; }
    summary.rewards = rewards;
    summary.xp = Math.round(xp * k);
    if (ctx.type === 'sea') {
      const toId = ctx.toId;
      const banked = arrive(d, toId);
      summary.arrived = toId; summary.banked = banked;
    }
  }
  function enc_has(res, crewId) { return Object.prototype.hasOwnProperty.call(res.allyHp, crewId); }
  function retreatOutcome(d, ctx, summary) {
    d.captain.stats.retreats++;
    if (ctx.type === 'sea') {
      const origin = ctx.fromId;
      if (World.PORTS[origin]) { d.world.currentLocationId = origin; dock(d, origin); }
      else { d.world.currentLocationId = origin; d.voyage.site = { locationId: origin, current: null }; }
      summary.returnedTo = origin;
    }
    log(d, 'log.retreated', {});
  }
  // Soft failure (GDD §11.3): permanent progress is kept; unbanked cargo is
  // reduced, some crew are injured, and the ship returns to the last safe port.
  function defeat(d, def, ctx, res, summary) {
    d.captain.stats.battlesLost++;
    const inv = d.inventory;
    const lostGold = Math.floor(inv.ledger.gold * T.defeatLossRate);
    const lostMats = Math.floor(inv.ledger.materials * T.defeatLossRate);
    inv.ledger.gold -= lostGold; inv.ledger.materials -= lostMats;
    const maxInj = Rules.facLevel(d, 'infirmary') >= 2 ? 1 : T.maxInjuriesPerDefeat;
    const ko = res.koAllies.slice(0, maxInj);
    for (const id of ko) { const m = Rules.member(d, id); if (m) { m.injured = true; summary.injured.push(id); } }
    d.ship.damage = Math.min(100, d.ship.damage + 10);
    let damagedFacility = null;
    if (def.arena === 'boarding') {
      const cands = d.ship.facilities.filter(f => !f.stowed && !f.damaged && f.id !== 'captains_cabin');
      if (cands.length) { damagedFacility = cands[State.nextInt(d, 0, cands.length - 1)]; damagedFacility.damaged = true; }
    }
    summary.losses = { gold: lostGold, materials: lostMats, damagedFacility: damagedFacility ? damagedFacility.id : null };
    const portId = d.world.lastSafePortId;
    advanceClock(d, 12);
    d.world.currentLocationId = portId;
    d.captain.regionId = World.location(portId).regionId;
    if (!d.voyage) d.voyage = { id: State.nextId(d, 'voy'), originPortId: portId, at: portId, route: null, event: null, site: null };
    dock(d, portId);
    summary.returnedTo = portId;
    log(d, 'log.defeat', { gold: lostGold, materials: lostMats });
  }

  // ================================================================== PETS
  function hatchEgg(state, eggId, inputs) {
    return run(state, 'pet.hatch', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.facLevel(d, 'hatchery', { allowDamaged: true })) return fail('err.need_facility', { facility: 'fac.hatchery.name' });
      const ei = d.inventory.eggs.findIndex(e => e.id === eggId);
      if (ei < 0) return fail('err.unknown');
      if (!Array.isArray(inputs) || inputs.length < 1 || inputs.length > 3) return fail('err.hatch_inputs');
      if (d.pets.length >= Rules.petCapacity(d)) return fail('err.pet_full');
      const need = {};
      for (const inp of inputs) {
        if (!Rules.inputColor(inp)) return fail('err.hatch_inputs');
        need[inp] = (need[inp] || 0) + 1;
      }
      for (const [inp, n] of Object.entries(need)) {
        const [kind, id] = inp.split(':');
        const have = kind === 'ing' ? d.inventory.ingredients[id] || 0 : d.inventory.specialties[id] || 0;
        if (have < n) return fail('err.no_input', { item: (kind === 'ing' ? 'ing.' : 'spec.') + id + '.name' });
      }
      for (const [inp, n] of Object.entries(need)) {
        const [kind, id] = inp.split(':');
        if (kind === 'ing') d.inventory.ingredients[id] -= n; else d.inventory.specialties[id] -= n;
      }
      const egg = d.inventory.eggs[ei];
      const out = Rules.hatchOutcome(egg, inputs);
      d.inventory.eggs.splice(ei, 1);
      const pet = {
        id: State.nextId(d, 'pet'), speciesId: out.speciesId, familyId: out.familyId, role: out.role, prime: out.prime,
        affinity: out.affinity, level: out.level, xp: 0, evolved: false, assignment: null, nickname: null, inputs: inputs.slice()
      };
      d.pets.push(pet);
      d.captain.stats.hatches++;
      const prevEntry = d.codex.pets[out.speciesId];
      d.codex.pets[out.speciesId] = { prime: !!(prevEntry && prevEntry.prime) || out.prime, seen: true };
      d.codex.hatchLog.unshift({ familyId: out.familyId, colors: inputs.map(Rules.inputColor), speciesId: out.speciesId, prime: out.prime });
      if (d.codex.hatchLog.length > 60) d.codex.hatchLog.length = 60;
      log(d, out.prime ? 'log.hatched_prime' : 'log.hatched', { species: 'pet.' + out.speciesId + '.name' });
      return done(pet.id);
    });
  }
  function assignPet(state, petId, kind, target) {
    return run(state, 'pet.assign', d => {
      const bad = requireCalm(d); if (bad) return bad;
      const p = d.pets.find(x => x.id === petId);
      if (!p) return fail('err.unknown');
      if (!kind) { p.assignment = null; return done(); }
      if (!Rules.petRoles(p).includes(kind)) return fail('err.pet_role', { role: 'petrole.' + kind });
      if (kind === 'companion') {
        if (!d.formation.includes(target)) return fail('err.pet_owner');
        for (const o of d.pets) if (o !== p && o.assignment && o.assignment.kind === 'companion' && o.assignment.target === target) o.assignment = null;
      } else if (kind === 'helper') {
        const f = d.ship.facilities.find(x => x.uid === target);
        if (!f) return fail('err.unknown');
        if (!Rules.layoutOf(d).facilities[f.uid].reachable) return fail('warn.facility_unreachable', { deck: f.deck + 1 });
      } else if (kind === 'explorer') {
        for (const o of d.pets) if (o !== p && o.assignment && o.assignment.kind === 'explorer') o.assignment = null;
        target = null;
      } else return fail('err.unknown');
      p.assignment = { kind, target: target || null };
      return done();
    });
  }
  function evolvePet(state, petId) {
    return run(state, 'pet.evolve', d => {
      const bad = requireCalm(d); if (bad) return bad;
      if (!Rules.facLevel(d, 'pet_lab')) return fail('err.need_facility', { facility: 'fac.pet_lab.name' });
      const p = d.pets.find(x => x.id === petId);
      if (!p) return fail('err.unknown');
      if (p.evolved) return fail('err.already_evolved');
      const cost = Rules.evolveCost(p);
      if (p.level < cost.level) return fail('err.pet_level', { level: cost.level });
      const c = pay(d, { materials: cost.materials, specialty: cost.specialty }); if (c) return c;
      p.evolved = true;
      p.speciesId = Content.PET_SPECIES[p.speciesId].evolvesTo || p.speciesId;
      d.codex.pets[p.speciesId] = { prime: p.prime, seen: true };
      log(d, 'log.evolved', { species: 'pet.' + p.speciesId + '.name' });
      return done(p.speciesId);
    });
  }
  function renamePet(state, petId, nickname) {
    return run(state, 'pet.rename', d => {
      const p = d.pets.find(x => x.id === petId);
      if (!p) return fail('err.unknown');
      const n = String(nickname || '').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, 18);
      p.nickname = n || null;
      return done();
    });
  }

  const Actions = {
    run, afterChange, buildAllies, battleXp,
    buildFacility, moveFacility, stowFacility, demolishFacility, upgradeFacility, placeStair, removeStair, toggleDoor,
    savePreset, applyPreset, deletePreset, upgradeHull, repairShip,
    recruit, dismiss, setFormation, assignJob, changeClass, setLegacy, equip, rename, treat, crewEventDeliver,
    buyItem, craftItem, reinforce, salvage,
    invest, buyGoods, sellSpecialty, acceptQuest, acceptContract, completeContract, deliverMain, emergencyAid, dockWork, waitAtPort,
    serveRation, useSupply, produceFood, produceSupplies,
    depart, resolveSeaEvent, emergencyReturn, enterRoom, startLegend, setTactics, resolveEncounter,
    hatchEgg, assignPet, evolvePet, renamePet, roomAccessible, itemNameKey, BUILD_LIMIT
  };
  root.P7S = root.P7S || {};
  root.P7S.Actions = Actions;
  if (typeof module !== 'undefined' && module.exports) module.exports = Actions;
})(typeof globalThis !== 'undefined' ? globalThis : this);
