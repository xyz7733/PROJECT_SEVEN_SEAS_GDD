/*
 * Project Seven Seas — derived rules. Pure read-only helpers that compute
 * layout reachability, facility effects, crew stats, route estimates, port
 * services, tavern pools, and pet outcomes from the persistent state.
 */
(function (root) {
  'use strict';

  const P = root.P7S || {};
  const Content = P.Content || require('./content.js');
  const World = P.World || require('./world.js');
  const State = P.State || require('./state.js');
  const T = Content.TUNING;
  const LANES = Content.FORMATION_LANES;

  // ------------------------------------------------------------------ layout
  function footprint(f) {
    const def = Content.FACILITIES[f.id];
    return f.rot ? { w: def.h, h: def.w } : { w: def.w, h: def.h };
  }
  function facCells(f) {
    const { w, h } = footprint(f);
    const out = [];
    for (let dx = 0; dx < w; dx++) for (let dy = 0; dy < h; dy++) out.push([f.x + dx, f.y + dy]);
    return out;
  }
  function isDoor(deck, x, y) { return deck.doors.some(([dx, dy]) => dx === x && dy === y); }
  // Returns null for an open cell or the kind of fixed obstacle.
  function fixedKind(deck, x, y) {
    if (x < 0 || y < 0 || x >= deck.w || y >= deck.h) return 'out';
    const f = deck.fixed.find(([fx, fy]) => fx === x && fy === y);
    if (f) return f[2];
    if (deck.bulkhead === x && !isDoor(deck, x, y)) return 'bulkhead';
    return null;
  }
  function stairAt(ship, d, x, y) {
    return ship.stairs.find(s => (s.deck === d || s.deck + 1 === d) && s.x === x && s.y === y) || null;
  }
  function occupancy(ship) {
    const occ = {};
    for (const f of ship.facilities) {
      if (f.stowed) continue;
      for (const [x, y] of facCells(f)) occ[f.deck + ':' + x + ':' + y] = f.uid;
    }
    return occ;
  }
  // Check whether a facility footprint can be placed (ignoring `ignoreUid`).
  function canPlace(ship, facId, deckIndex, x, y, rot, ignoreUid) {
    const deck = ship.decks[deckIndex];
    if (!deck) return { ok: false, reasonKey: 'err.bad_cell' };
    const occ = occupancy(ship);
    const cells = facCells({ id: facId, x, y, rot });
    for (const [cx, cy] of cells) {
      const k = fixedKind(deck, cx, cy);
      if (k) return { ok: false, reasonKey: k === 'out' ? 'err.out_of_bounds' : 'err.cell_blocked' };
      if (deck.bulkhead === cx) return { ok: false, reasonKey: 'err.cell_door' };
      const o = occ[deckIndex + ':' + cx + ':' + cy];
      if (o && o !== ignoreUid) return { ok: false, reasonKey: 'err.cell_occupied' };
      if (stairAt(ship, deckIndex, cx, cy)) return { ok: false, reasonKey: 'err.cell_stair' };
      if (deck.entry && deck.entry[0] === cx && deck.entry[1] === cy) return { ok: false, reasonKey: 'err.cell_entry' };
    }
    return { ok: true };
  }

  // Breadth-first search from the gangway through walkable cells and stairs
  // (GDD §6.2). A facility is reachable when an adjacent walkable cell is reached.
  function analyzeLayout(ship, crewCount) {
    const occ = occupancy(ship);
    const walkable = (d, x, y) => {
      const deck = ship.decks[d];
      if (!deck || fixedKind(deck, x, y)) return false;
      return !occ[d + ':' + x + ':' + y];
    };
    const reached = new Set();
    const deck0 = ship.decks[0];
    const queue = [];
    if (deck0.entry && walkable(0, deck0.entry[0], deck0.entry[1])) { queue.push([0, deck0.entry[0], deck0.entry[1]]); reached.add('0:' + deck0.entry[0] + ':' + deck0.entry[1]); }
    while (queue.length) {
      const [d, x, y] = queue.shift();
      const next = [[d, x + 1, y], [d, x - 1, y], [d, x, y + 1], [d, x, y - 1]];
      for (const s of ship.stairs) {
        if (s.x === x && s.y === y && s.deck === d) next.push([d + 1, x, y]);
        if (s.x === x && s.y === y && s.deck + 1 === d) next.push([d - 1, x, y]);
      }
      for (const [nd, nx, ny] of next) {
        const k = nd + ':' + nx + ':' + ny;
        if (reached.has(k) || !walkable(nd, nx, ny)) continue;
        reached.add(k);
        queue.push([nd, nx, ny]);
      }
    }
    const decksReached = new Set([...reached].map(k => +k.split(':')[0]));
    const facilities = {};
    for (const f of ship.facilities) {
      if (f.stowed) { facilities[f.uid] = { reachable: false, stowed: true, reasonKey: 'warn.facility_stowed', reasonParams: {} }; continue; }
      let ok = false;
      for (const [x, y] of facCells(f)) {
        for (const [nx, ny] of [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]) {
          if (reached.has(f.deck + ':' + nx + ':' + ny)) { ok = true; break; }
        }
        if (ok) break;
      }
      facilities[f.uid] = ok ? { reachable: true }
        : { reachable: false, reasonKey: decksReached.has(f.deck) ? 'warn.facility_unreachable' : 'warn.deck_no_stair', reasonParams: { deck: f.deck + 1 } };
    }
    const missingRequired = [];
    for (const [id, def] of Object.entries(Content.FACILITIES)) {
      if (!def.required) continue;
      if (!ship.facilities.some(f => f.id === id && facilities[f.uid].reachable)) missingRequired.push(id);
    }
    const disabled = ship.facilities.filter(f => !facilities[f.uid].reachable).map(f => f.uid);
    let capacity = 0;
    for (const f of ship.facilities) if (f.id === 'crew_quarters' && facilities[f.uid].reachable) capacity += 4 + 2 * f.level;
    const overCapacity = crewCount != null && crewCount > capacity;
    return {
      facilities, reached, decksReached, missingRequired, disabled, capacity, overCapacity,
      canDepart: missingRequired.length === 0 && !overCapacity
    };
  }

  // -------------------------------------------------------------- facilities
  function layoutOf(state) { return analyzeLayout(state.ship, state.crew.length); }
  // Active = placed and reachable. Bonus = active and not damaged (GDD §8.6).
  function activeFacilities(state, layout) {
    const lay = layout || layoutOf(state);
    return state.ship.facilities.filter(f => lay.facilities[f.uid] && lay.facilities[f.uid].reachable);
  }
  function facLevel(state, id, opts) {
    const o = opts || {};
    let best = 0;
    for (const f of activeFacilities(state, o.layout)) if (f.id === id && (o.allowDamaged || !f.damaged)) best = Math.max(best, f.level);
    return best;
  }
  function bestFacility(state, id, layout) {
    let best = null;
    for (const f of activeFacilities(state, layout)) if (f.id === id && (!best || f.level > best.level || (best.damaged && !f.damaged))) best = f;
    return best;
  }
  function jobSlots(f) { return Content.FACILITIES[f.id].jobs + (Content.FACILITIES[f.id].jobs && f.level >= 3 ? 1 : 0); }
  function memberMods(state, m) { return memberStats(state, m).mods; }
  function workerEfficiency(state, m, facId) {
    const cls = Content.CLASSES[m.classId];
    let e = cls.jobs.includes(facId) ? 1 : 0.5;
    const mods = memberMods(state, m);
    e += mods.jobPct || 0;
    return e;
  }
  function petHelperEfficiency(pet) {
    const roles = petRoles(pet);
    return (roles.includes('helper') ? 1 : 0.5) * (pet.evolved ? 1.4 : 1);
  }
  // Production multiplier from staffed workers and helper pets: 1 + 0.5 × Σ efficiency.
  function staffMult(state, facId, layout) {
    const f = bestFacility(state, facId, layout);
    if (!f || f.damaged) return 1;
    let sum = 0;
    for (const m of state.crew) if (m.jobFacilityUid === f.uid) sum += workerEfficiency(state, m, facId);
    for (const p of state.pets) if (p.assignment && p.assignment.kind === 'helper' && p.assignment.target === f.uid) sum += petHelperEfficiency(p);
    return 1 + 0.5 * sum;
  }
  function crewCapacity(state, layout) { return (layout || layoutOf(state)).capacity; }
  function foodCapacity(state, layout) {
    let c = 0;
    for (const f of activeFacilities(state, layout)) if (f.id === 'pantry') c += 20 + 10 * f.level;
    return c;
  }
  function supplyCapacity(state, layout) {
    return T.baseSupplyCap + 5 * facLevel(state, 'cargo_hold', { allowDamaged: true, layout });
  }
  function equipCapacity(state, layout) {
    return T.baseEquipCap + 20 * facLevel(state, 'cargo_hold', { allowDamaged: true, layout }) + 30 * facLevel(state, 'secure_locker', { allowDamaged: true, layout });
  }
  function petCapacity(state, layout) {
    return 2 + 2 * facLevel(state, 'pet_lab', { allowDamaged: true, layout }) + 3 * facLevel(state, 'creature_pens', { allowDamaged: true, layout });
  }
  function eggCapacity(state, layout) { return 2 + facLevel(state, 'hatchery', { allowDamaged: true, layout }); }
  function staminaMax(state, layout) {
    const cabin = facLevel(state, 'captains_cabin', { allowDamaged: true, layout });
    return T.maxStamina + 10 * Math.max(0, cabin - 1) + 10 * (state.ship.hullTier - 1);
  }
  function upgradeCost(f) {
    const def = Content.FACILITIES[f.id];
    const lvl = f.level + 1;
    const gold = Math.round((def.cost.gold || 60) * 0.8 * lvl);
    const materials = Math.round((def.cost.materials || 10) * lvl);
    return { gold, materials };
  }
  function demolishRefund(f) {
    const def = Content.FACILITIES[f.id];
    let materials = def.cost.materials || 0;
    let gold = Math.round((def.cost.gold || 0) * 0.5);
    for (let l = 2; l <= f.level; l++) { const c = upgradeCost({ id: f.id, level: l - 1 }); materials += c.materials; gold += Math.round(c.gold * 0.5); }
    return { gold, materials, specialty: def.cost.specialty || null };
  }

  // ------------------------------------------------------------------- crew
  function member(state, id) { return state.crew.find(m => m.id === id) || null; }
  function equipInst(state, uid) { return uid ? state.inventory.equipment.find(e => e.uid === uid) || null : null; }
  function addMods(target, mods, scale) {
    if (!mods) return;
    for (const [k, v] of Object.entries(mods)) target[k] = (target[k] || 0) + v * (scale || 1);
  }
  function activePassives(m) {
    const cls = Content.CLASSES[m.classId];
    const out = [cls.passive];
    for (const p of m.legacy || []) if (!out.includes(p)) out.push(p);
    return out;
  }
  function masteredClasses(m) { return Object.keys(m.mastery).filter(c => m.mastery[c] >= T.masteredAt); }
  function legacyOptions(m) {
    const current = Content.CLASSES[m.classId].passive;
    return masteredClasses(m).map(c => Content.CLASSES[c].passive).filter((p, i, a) => p !== current && a.indexOf(p) === i);
  }
  function qualifiedFor(m, classId) {
    const c = Content.CLASSES[classId];
    if (!c) return false;
    if (c.tier === 'base') return true;
    return (m.mastery[c.parent] || 0) >= T.qualifyMastery || (m.mastery[classId] || 0) > 0;
  }
  function weaponCompatible(classId, itemId) {
    const it = Content.ITEMS[itemId];
    if (!it || it.slot !== 'weapon') return true;
    return Content.CLASSES[classId].weapons.includes(it.wtype);
  }
  function weaponRange(classId, item) {
    if (!item) return Content.CLASSES[classId].range;
    if (['blade', 'shield', 'fist'].includes(item.wtype)) return 'melee';
    if (['spear', 'whip'].includes(item.wtype)) return 'reach';
    if (item.wtype === 'gun') return 'ranged';
    return Content.CLASSES[classId].range;
  }
  function slotOf(state, crewId) { return state.formation.indexOf(crewId); }
  function laneOfSlot(i) { return LANES[Math.floor(i / 2)]; }

  // Derived combat stats including class, level, equipment, passives, injury.
  function memberStats(state, m) {
    const cls = Content.CLASSES[m.classId];
    const g = T.growth;
    const L = m.level;
    const mods = {};
    for (const p of activePassives(m)) addMods(mods, Content.PASSIVES[p]);
    for (const a of m.aptitudes) addMods(mods, Content.APTITUDES[a]);
    const props = [];
    const resist = [];
    let hp = cls.base.hp * cls.mult.hp * (1 + g.hp * (L - 1)) + m.variance.hp;
    let atk = cls.base.atk * cls.mult.atk * (1 + g.atk * (L - 1)) + m.variance.atk;
    let def = cls.base.def * cls.mult.def * (1 + g.def * (L - 1)) + m.variance.def;
    let spd = cls.base.spd * cls.mult.spd + 0.25 * (L - 1) + m.variance.spd;
    let weaponItem = null;
    for (const slot of ['weapon', 'outfit', 'accessory']) {
      const inst = equipInst(state, m.equipment[slot]);
      if (!inst) continue;
      const it = Content.ITEMS[inst.itemId];
      if (!it) continue;
      if (slot === 'weapon') weaponItem = it;
      const f = 1 + 0.1 * (inst.reinforce || 0);
      hp += (it.stats.hp || 0) * f; atk += (it.stats.atk || 0) * f; def += (it.stats.def || 0) * f; spd += it.stats.spd || 0;
      for (const p of it.props || []) if (!props.includes(p)) props.push(p);
      for (const r of it.resist || []) if (!resist.includes(r)) resist.push(r);
      addMods(mods, it.mods);
      if (inst.affix) addMods(mods, Content.AFFIXES[inst.affix]);
    }
    if (props.includes('crit')) mods.crit = (mods.crit || 0) + 0.1;
    if (props.includes('lifesteal')) mods.lifesteal = (mods.lifesteal || 0) + 0.15;
    if (props.includes('guard')) mods.guard = (mods.guard || 0) + 0.1;
    hp *= 1 + (mods.hpPct || 0); atk *= 1 + (mods.atkPct || 0); def *= 1 + (mods.defPct || 0); spd += mods.spd || 0;
    if (m.injured) { const k = 1 - T.injuryPenalty; hp *= k; atk *= k; def *= k; spd *= k; }
    const slot = slotOf(state, m.id);
    return {
      hp: Math.round(hp), atk: Math.round(atk), def: Math.round(def), spd: Math.round(spd * 10) / 10,
      crit: 0.05 + (mods.crit || 0), dodge: mods.dodge || 0,
      range: weaponRange(m.classId, weaponItem), lane: slot >= 0 ? laneOfSlot(slot) : cls.lane,
      props, mods, resist, skills: cls.skills.slice(), passives: activePassives(m), roles: cls.roles
    };
  }
  function power(state, m) { const s = memberStats(state, m); return Math.round(s.hp / 6 + s.atk * 2 + s.def * 1.5 + s.spd * 2); }
  function xpToNext(level) { return T.xpBase + T.xpPerLevel * level; }
  function respecCost(m) { return { gold: T.respecBase + T.respecPerLevel * m.level }; }
  function treatCost(m) { return { gold: 20 + 5 * m.level, supplies: 1 }; }

  // ------------------------------------------------------------------- pets
  function petRoles(pet) {
    const sp = Content.PET_SPECIES[pet.speciesId];
    const roles = [sp.role];
    if (pet.evolved) {
      const alt = Content.ROLE_BY_COLOR[pet.affinity];
      roles.push(alt && alt !== sp.role ? alt : Content.PET_ROLES[(Content.PET_ROLES.indexOf(sp.role) + 1) % 3]);
    }
    return roles;
  }
  function inputColor(input) {
    const [kind, id] = input.split(':');
    if (kind === 'ing') return Content.INGREDIENTS[id] && Content.INGREDIENTS[id].color;
    if (kind === 'spec') return Content.SPECIALTIES[id] && Content.SPECIALTIES[id].color;
    return null;
  }
  // Authored deterministic outcome from family, grade, and ordered inputs (GDD §9.6).
  function hatchOutcome(egg, inputs) {
    const fam = Content.petFamily(egg.familyId);
    const colors = inputs.map(inputColor);
    const role = Content.ROLE_BY_COLOR[colors[0]] || 'companion';
    const sig = fam.sig[role];
    const prime = colors.length === 3 && colors.every((c, i) => c === sig[i]);
    const counts = {};
    colors.forEach(c => { counts[c] = (counts[c] || 0) + 1; });
    let affinity = colors[0];
    for (const c of colors) if (counts[c] > counts[affinity]) affinity = c;
    return { speciesId: fam.id + '_' + role, familyId: fam.id, role, prime, affinity, level: [1, 3, 5][egg.grade - 1] || 1 };
  }
  function petLevelNeeded(pet) { return pet.prime ? 4 : 5; }
  function evolveCost(pet) {
    const fam = Content.petFamily(pet.familyId);
    const tier = Content.REGION_ORDER.indexOf(fam.regionId) + 1;
    return { materials: 15 + 5 * tier, specialty: [Content.REGION_SPECIALTY[fam.regionId], 2], level: petLevelNeeded(pet) };
  }
  function petXpToNext(level) { return 20 * level; }
  function petPowerMult(pet, owner, ownerStats) {
    let k = (1 + 0.08 * (pet.level - 1)) * (pet.evolved ? 1.4 : 1) * (pet.prime ? 1.25 : 1);
    let bonus = 0;
    if (ownerStats) {
      bonus += ownerStats.mods.petPct || 0;
      if (ownerStats.props.includes('pet')) bonus += 0.25;
    }
    if (owner && owner.petAffinity === pet.affinity) bonus += 0.2;
    return k * (1 + bonus);
  }
  function explorerPet(state) { return state.pets.find(p => p.assignment && p.assignment.kind === 'explorer') || null; }

  // ------------------------------------------------------------------ world
  function knowledge(state, locId) { return state.world.locations[locId] ? state.world.locations[locId].k : 'hidden'; }
  function isKnown(state, locId) { return knowledge(state, locId) !== 'hidden'; }
  function isVisited(state, locId) { const k = knowledge(state, locId); return k === 'visited' || k === 'cleared'; }
  function regionUnlocked(state, regionId) { return state.captain.regionsUnlocked.includes(regionId); }
  function day(state) { return Math.floor(state.envelope.gameClock / 24); }
  function rotation(state) { return Math.floor(day(state) / 3); }
  function atPort(state) { return !state.voyage && !!World.PORTS[state.world.currentLocationId]; }
  function portTrack(state, portId, track) { const p = state.world.ports[portId]; return p ? p.tracks[track] || 0 : 0; }
  function repRank(state, faction) { return Math.min(3, Math.floor((state.captain.reputation[faction] || 0) / 40)); }
  function totalRep(state) { return Object.values(state.captain.reputation).reduce((a, b) => a + b, 0); }

  // Chance that a sailed leg triggers a sea event. Crew with the `avoid`
  // modifier (Weather Eye) steer around part of the trouble.
  function seaEventChance(state) {
    let avoid = 0;
    for (const m of activeCrew(state)) avoid = Math.max(avoid, memberStats(state, m).mods.avoid || 0);
    return World.SEA_EVENT_CHANCE * (1 - Math.min(0.5, avoid));
  }
  function activeCrew(state) { return state.formation.filter(Boolean).map(id => member(state, id)).filter(Boolean); }
  function foodSaving(state) {
    let save = 0;
    for (const m of activeCrew(state)) save = Math.max(save, memberStats(state, m).mods.foodSave || 0);
    return save;
  }

  // Voyage leg estimate (GDD §5.2): distance, hours, food.
  function legCost(state, fromId, toId) {
    const a = World.location(fromId), b = World.location(toId);
    const d = World.distance(fromId, toId);
    const cross = a.regionId !== b.regionId;
    let food = Math.max(1, Math.ceil(d * 6)) + Math.floor(state.crew.length / 5);
    const lay = layoutOf(state);
    const mess = facLevel(state, 'mess_hall', { layout: lay });
    if (mess) food -= mess >= 3 ? 2 : 1;
    if (cross) food -= 2 * facLevel(state, 'compass_room', { layout: lay });
    if (!cross && state.world.shortcuts[a.regionId]) food -= 1;
    food -= foodSaving(state);
    if (state.ship.damage >= 40) food += 1;
    return { distance: d, hours: Math.round(4 + d * 20), food: Math.max(1, food), cross };
  }
  function knownPorts(state) { return Object.keys(World.PORTS).filter(p => isKnown(state, p) && regionUnlocked(state, World.location(p).regionId)); }
  function hazardKnown(state, regionId) {
    const r = World.region(regionId);
    return r.locs.some(id => isVisited(state, id)) || facLevel(state, 'chart_table') > 0 || facLevel(state, 'compass_room') > 0 ||
      r.locs.slice(0, 2).some(p => portTrack(state, p, 'navigation') >= 1);
  }
  function forecastExact(state, regionId) {
    const r = World.region(regionId);
    return facLevel(state, 'chart_table') > 0 || r.locs.slice(0, 2).some(p => portTrack(state, p, 'navigation') >= 1);
  }
  function seaWeights(state, regionId) {
    const r = World.region(regionId);
    const w = Object.assign({}, r.sea);
    const chart = facLevel(state, 'chart_table');
    if (chart) { const k = 1 + 0.5 * (staffMult(state, 'chart_table') - 1); w.pirate *= Math.max(0.2, 1 - 0.15 * chart * k); w.monster *= Math.max(0.2, 1 - 0.15 * chart * k); }
    return w;
  }
  function plannedStamina(state, locId) {
    const loc = World.location(locId);
    if (!loc || loc.type === 'port') return 0;
    const done = state.world.locations[locId].rooms || [];
    return World.rooms(locId).filter(r => !r.secret && !done.includes(r.id)).reduce((a, r) => a + r.cost, 0) || World.rooms(locId).filter(r => r.objective).reduce((a, r) => a + r.cost, 0);
  }
  function sailBlock(state, toId, fast) {
    const loc = World.location(toId);
    if (!loc) return 'err.unknown_location';
    if (state.encounter) return 'err.in_encounter';
    if (state.voyage && state.voyage.event) return 'err.event_pending';
    if (toId === state.world.currentLocationId) return 'err.same_location';
    if (!regionUnlocked(state, loc.regionId)) return 'err.region_locked';
    const reg = World.region(loc.regionId);
    if (reg.requiresHullTier && state.ship.hullTier < reg.requiresHullTier) return 'err.hull_required';
    if (!isKnown(state, toId)) return 'err.not_revealed';
    if (!state.voyage) { const lay = layoutOf(state); if (!lay.canDepart) return lay.overCapacity ? 'err.over_capacity' : 'err.layout_blocked'; }
    if (fast) {
      if (!atPort(state) || !World.PORTS[toId]) return 'err.fast_ports_only';
      if (!isVisited(state, toId)) return 'err.fast_not_visited';
      if (!chartedPath(state, state.world.currentLocationId, toId)) return 'err.fast_not_charted';
    }
    const leg = legCost(state, state.world.currentLocationId, toId);
    if (state.inventory.food < leg.food) return 'err.no_food_route';
    return null;
  }
  function routeKey(a, b) { return a < b ? a + '|' + b : b + '|' + a; }
  // Fast travel: both ports visited and connected through safely charted routes.
  function chartedPath(state, a, b) {
    const adj = {};
    for (const k of state.world.chartedRoutes) {
      const [x, y] = k.split('|');
      (adj[x] = adj[x] || []).push(y); (adj[y] = adj[y] || []).push(x);
    }
    const seen = new Set([a]);
    const q = [a];
    while (q.length) {
      const c = q.shift();
      if (c === b) return true;
      for (const n of adj[c] || []) if (!seen.has(n)) { seen.add(n); q.push(n); }
    }
    return false;
  }
  function routeInfo(state, toId, fast) {
    const from = state.world.currentLocationId;
    const loc = World.location(toId);
    const leg = legCost(state, from, toId);
    const ports = knownPorts(state).filter(p => p !== toId).map(p => ({ id: p, food: legCost(state, toId, p).food, hours: legCost(state, toId, p).hours }))
      .sort((a, b) => a.food - b.food).slice(0, 3);
    const returnFood = World.PORTS[toId] ? 0 : (ports.length ? ports[0].food : 0);
    const foodAfter = state.inventory.food - leg.food;
    const reg = World.region(loc.regionId);
    const hazards = [];
    if (reg.hazard) hazards.push(reg.hazard);
    if (reg.mechanic) hazards.push(reg.mechanic);
    const planned = plannedStamina(state, toId);
    const w = seaWeights(state, loc.regionId);
    const total = Object.values(w).reduce((a, b) => a + b, 0);
    const chance = seaEventChance(state);
    const encounters = World.SEA_EVENT_KINDS.map(k => ({ kind: k, pct: Math.round(100 * chance * w[k] / total) })).filter(e => e.pct > 0);
    return {
      toId, fromId: from, fast: !!fast, distance: leg.distance, hours: leg.hours, food: leg.food, foodAfter, returnFood,
      returnOk: foodAfter >= returnFood, suppliesAfter: state.inventory.supplies,
      stamina: state.ship.stamina, plannedStamina: planned, staminaAfter: state.ship.stamina - planned,
      hazards, hazardsKnown: hazardKnown(state, loc.regionId), encounters: fast ? [] : encounters, exact: forecastExact(state, loc.regionId),
      firstDiscovery: !isVisited(state, toId), level: loc.level, capability: reg.capability, returnPorts: ports,
      blockKey: sailBlock(state, toId, fast)
    };
  }

  // -------------------------------------------------------------- main quest
  // The current main step: the newest unlocked region whose arc is unfinished.
  function mainStatus(state) {
    const regs = state.captain.regionsUnlocked;
    for (let i = regs.length - 1; i >= 0; i--) {
      const rid = regs[i];
      const step = state.captain.mainStep[rid] || 0;
      if (step < World.MAIN_TEMPLATE.length) {
        const q = World.mainStep(rid, step);
        const reg = World.region(rid);
        const arena = reg.locs[8];
        return { regionId: rid, step, quest: q, trialLocationId: arena, trialKnown: isKnown(state, arena), trialWon: state.captain.trialsWon.includes(rid), done: false };
      }
    }
    return { done: true, regionId: regs[regs.length - 1] };
  }
  function questDone(state, qid) { const q = state.world.quests[qid]; return !!(q && q.status === 'done'); }

  // ------------------------------------------------------------------ ports
  function regionTierOfPort(portId) { return World.region(World.PORTS[portId].regionId).tier; }
  function investCost(state, portId, track) {
    const lvl = portTrack(state, portId, track);
    if (lvl >= 3) return null;
    const t = regionTierOfPort(portId);
    const next = lvl + 1;
    const gold = Math.round((70 + 55 * t) * next * (1 - 0.05 * repRank(state, 'league')));
    const cost = { gold, level: next };
    if (next === 3) cost.specialty = [World.region(World.PORTS[portId].regionId).specialtyId, 2];
    return cost;
  }
  function prices(state, portId) {
    const t = regionTierOfPort(portId);
    const disc = portTrack(state, portId, 'market') >= 3 ? 0.9 : 1;
    return {
      food: Math.round((3 + t) * disc), supplies: Math.round((18 + 4 * t) * disc), ingredient: Math.round((10 + 2 * t) * disc),
      egg: Math.round((140 + 45 * t) * disc)
    };
  }
  function specialtyBuyPrice(state, portId, specId) {
    return Math.round(Content.SPECIALTIES[specId].price * (portTrack(state, portId, 'market') >= 3 ? 0.9 : 1));
  }
  // Controlled trade: stable base value with a mild distance premium (GDD §10.3).
  function specialtySellPrice(state, portId, specId) {
    const home = Content.REGION_ORDER.indexOf(Object.keys(Content.REGION_SPECIALTY).find(r => Content.REGION_SPECIALTY[r] === specId));
    const here = Content.REGION_ORDER.indexOf(World.PORTS[portId].regionId);
    const k = Math.min(1.4, 0.6 + 0.15 * Math.abs(home - here));
    return Math.round(Content.SPECIALTIES[specId].price * k * (portTrack(state, portId, 'market') >= 3 ? 1.15 : 1));
  }
  function shopItems(state, portId) {
    const m = portTrack(state, portId, 'market');
    const t = regionTierOfPort(portId);
    const out = [];
    if (m >= 1) out.push('a_escape_rope', 'a_work_gloves');
    if (m >= 2) { for (const w of Object.keys(Content.WEAPON_TYPES)) out.push('w_' + w + '_' + t); out.push('o_coat_' + t, 'o_armor_' + t); }
    if (m >= 3) out.push('a_' + Content.REGIONAL_ACCESSORIES[t - 1].id);
    return out;
  }
  function itemPrice(itemId) { return Content.ITEMS[itemId].price; }
  function salvageValue(inst) {
    const it = Content.ITEMS[inst.itemId];
    return { materials: Math.max(2, Math.round((it.recipe ? it.recipe.materials : 4) * 0.6 + 2 * (inst.reinforce || 0))) };
  }
  // A level-3 port workshop (master smiths) cuts gold and material costs.
  function workshopDiscount(state) {
    return state && atPort(state) && portTrack(state, state.world.currentLocationId, 'workshop') >= 3 ? 0.75 : 1;
  }
  function reinforceCost(inst, state) {
    const it = Content.ITEMS[inst.itemId];
    const k = workshopDiscount(state);
    return { materials: Math.round((6 + 4 * it.tier + 4 * (inst.reinforce || 0)) * k), gold: Math.round(20 * it.tier * k) };
  }
  function craftCost(itemId, affix, state) {
    const it = Content.ITEMS[itemId];
    if (!it || !it.recipe) return null;
    const k = workshopDiscount(state);
    const c = { materials: Math.round(it.recipe.materials * k), specialty: it.recipe.specialty.slice(), gold: Math.round(it.price * 0.25 * k) };
    if (affix) c.specialty = [c.specialty[0], c.specialty[1] + 1];
    return c;
  }
  function canCraftHere(state) {
    if (atPort(state) && portTrack(state, state.world.currentLocationId, 'workshop') >= 1) return true;
    return facLevel(state, 'workshop') > 0;
  }
  function canReinforceHere(state) {
    if (atPort(state) && portTrack(state, state.world.currentLocationId, 'workshop') >= 2) return true;
    return facLevel(state, 'workshop') >= 2;
  }
  function repairCost(state) {
    const t = atPort(state) ? regionTierOfPort(state.world.currentLocationId) : 1;
    const dmgFac = state.ship.facilities.filter(f => f.damaged).length;
    return { gold: Math.round(state.ship.damage * (2 + t) + 30 * dmgFac), materials: Math.ceil(state.ship.damage / 4) + 5 * dmgFac, needed: state.ship.damage > 0 || dmgFac > 0 };
  }
  function hullAvailable(state, hull) {
    if (hull.tier !== state.ship.hullTier + 1) return { ok: false, reasonKey: hull.tier <= state.ship.hullTier ? 'err.hull_owned' : 'err.hull_previous' };
    const regionIdx = state.captain.regionsUnlocked.length;
    if (regionIdx < hull.unlockRegion) return { ok: false, reasonKey: 'err.hull_region', reasonParams: { region: 'region.' + Content.REGION_ORDER[hull.unlockRegion - 1] + '.name' } };
    if (hull.blueprint && !state.inventory.blueprints.includes(hull.blueprint)) return { ok: false, reasonKey: 'err.hull_blueprint' };
    if (!atPort(state) || portTrack(state, state.world.currentLocationId, 'workshop') < 2) return { ok: false, reasonKey: 'err.need_workshop2' };
    return { ok: true };
  }
  function foodPriceHere(state) { return atPort(state) ? prices(state, state.world.currentLocationId).food : 5; }
  // Free emergency assistance (GDD §11.2): available when a basic meal,
  // treatment, or essential repair cannot be afforded.
  function emergencyNeeds(state) {
    if (!atPort(state)) return [];
    const needs = [];
    const inv = state.inventory;
    const pr = prices(state, state.world.currentLocationId);
    if (inv.food < 1 && inv.gold < pr.food) needs.push('meal');
    if (state.ship.stamina < 15 && inv.food < 1 && inv.supplies < 1 && inv.gold < pr.food) { if (!needs.includes('meal')) needs.push('meal'); }
    const injured = state.crew.filter(m => m.injured);
    if (injured.length && inv.supplies < 1 && inv.gold < treatCost(injured[0]).gold) needs.push('treatment');
    const rc = repairCost(state);
    if ((state.ship.damage >= 30 || state.ship.facilities.some(f => f.damaged)) && inv.gold < rc.gold && inv.materials < rc.materials) needs.push('repair');
    return needs;
  }
  // Dock work is the always-available recovery contract for a captain short on gold.
  function recoveryContractAvailable(state) { return atPort(state) && state.inventory.gold < 60; }

  // ------------------------------------------------------------------ tavern
  const TAVERN_SIZE = [1, 3, 4, 5];
  function tavernPool(state, portId) {
    const lvl = portTrack(state, portId, 'tavern');
    const rot = rotation(state);
    const tv = state.world.taverns[portId];
    const hired = tv && tv.rotation === rot ? tv.hired : [];
    const reg = World.region(World.PORTS[portId].regionId);
    const ri = reg.order - 1;
    const corner = facLevel(state, 'tavern_corner');
    const size = TAVERN_SIZE[lvl] + (corner ? 1 : 0);
    const base = State.seedOf(state.envelope.profileId + ':tavern:' + portId + ':' + rot);
    const r = State.localRng(base);
    const classes = Content.BASE_CLASS_IDS.slice();
    for (let i = classes.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [classes[i], classes[j]] = [classes[j], classes[i]]; }
    const classPool = lvl >= 2 ? Content.BASE_CLASS_IDS : classes.slice(0, lvl >= 1 ? 8 : 4);
    const originPool = lvl >= 2 ? Content.ORIGINS : lvl >= 1
      ? [Content.ORIGINS[ri], Content.ORIGINS[Math.max(0, ri - 1)], Content.ORIGINS[Math.min(9, ri + 1)]]
      : [Content.ORIGINS[ri]];
    const level = Math.max(1, reg.level + (lvl >= 2 ? 1 : 0) + (lvl >= 3 ? 1 : 0));
    const out = [];
    for (let i = 0; i < size; i++) {
      const m = State.makeRecruit(State.seedOf(base + ':' + i), { classPool, originPool, level, qualified: lvl >= 3 && i < 2 });
      out.push({ index: i, member: m, cost: recruitCost(state, m), hired: hired.includes(i), aptVisible: lvl >= 2 });
    }
    return out;
  }
  function recruitCost(state, m) { return Math.round((50 + 20 * m.level) * (1 - 0.1 * facLevel(state, 'tavern_corner'))); }

  // --------------------------------------------------------------- contracts
  function contractOffers(state, portId) {
    if (portTrack(state, portId, 'quest_board') < 2) return [];
    const rot = rotation(state);
    const reg = World.region(World.PORTS[portId].regionId);
    const t = reg.tier;
    const r = State.localRng(State.seedOf(state.envelope.profileId + ':contracts:' + portId + ':' + rot));
    const out = [];
    const used = [];
    for (let i = 0; i < 2; i++) {
      let type = r.pick(World.CONTRACT_TYPES);
      if (used.includes(type)) type = World.CONTRACT_TYPES[(World.CONTRACT_TYPES.indexOf(type) + 1) % 3];
      used.push(type);
      const id = 'contract:' + portId + ':' + rot + ':' + i;
      const pr = prices(state, portId);
      let c;
      if (type === 'hunt') c = { need: 3, reward: { gold: 40 + 30 * t, materials: 8 + 4 * t, rep: 4 } };
      if (type === 'supply') { const n = 4 + t; c = { need: n, reward: { gold: Math.round(n * pr.food * 1.6), materials: 0, rep: 3 } }; }
      if (type === 'haul') {
        const unlocked = state.captain.regionsUnlocked.filter(x => x !== reg.id);
        const src = unlocked.length ? unlocked[Math.floor(r() * unlocked.length)] : reg.id;
        const spec = World.region(src).specialtyId;
        c = { need: 2, specialtyId: spec, reward: { gold: Math.round(specialtySellPrice(state, portId, spec) * 2 * 1.5), materials: 4 * t, rep: 4 } };
      }
      const saved = state.world.contracts[id];
      out.push(Object.assign({ id, portId, type, regionId: reg.id, status: saved ? saved.status : 'offered', progress: saved ? saved.progress : 0 }, c));
    }
    return out;
  }
  function activeContracts(state) {
    return Object.entries(state.world.contracts).filter(([, c]) => c.status === 'active').map(([id, c]) => Object.assign({ id }, c));
  }

  // ----------------------------------------------------------------- codex
  function codexProgress(state) {
    const locTotal = Object.keys(World.LOCATIONS).length;
    const locSeen = Object.values(state.world.locations).filter(l => l.k !== 'hidden').length;
    const enemyTotal = World.allEnemyIds().length;
    const enemySeen = Object.keys(state.codex.enemies).length;
    const classTotal = Object.keys(Content.CLASSES).length;
    const classSeen = Object.keys(state.codex.classes).length;
    const petTotal = Object.keys(Content.PET_SPECIES).length;
    const petSeen = Object.keys(state.codex.pets).length;
    return { locations: [locSeen, locTotal], enemies: [enemySeen, enemyTotal], classes: [classSeen, classTotal], pets: [petSeen, petTotal], recipes: [state.inventory.recipes.length, Object.values(Content.ITEMS).filter(i => i.recipe).length], items: [Object.keys(state.codex.items).length, Object.keys(Content.ITEMS).length], clues: [state.codex.clues.length, null] };
  }

  const Rules = {
    seaEventChance, footprint, facCells, fixedKind, isDoor, stairAt, occupancy, canPlace, analyzeLayout, layoutOf, activeFacilities, facLevel, bestFacility,
    jobSlots, workerEfficiency, petHelperEfficiency, staffMult, crewCapacity, foodCapacity, supplyCapacity, equipCapacity, petCapacity, eggCapacity, staminaMax,
    upgradeCost, demolishRefund, member, equipInst, activePassives, masteredClasses, legacyOptions, qualifiedFor, weaponCompatible, weaponRange,
    slotOf, laneOfSlot, memberStats, power, xpToNext, respecCost, treatCost,
    petRoles, inputColor, hatchOutcome, evolveCost, petLevelNeeded, petXpToNext, petPowerMult, explorerPet,
    knowledge, isKnown, isVisited, regionUnlocked, day, rotation, atPort, portTrack, repRank, totalRep, activeCrew, foodSaving,
    legCost, knownPorts, hazardKnown, forecastExact, seaWeights, plannedStamina, sailBlock, routeKey, chartedPath, routeInfo,
    mainStatus, questDone, investCost, prices, specialtySellPrice, specialtyBuyPrice, shopItems, itemPrice, salvageValue, reinforceCost, craftCost, workshopDiscount,
    canCraftHere, canReinforceHere, repairCost, hullAvailable, foodPriceHere, emergencyNeeds, recoveryContractAvailable,
    tavernPool, recruitCost, contractOffers, activeContracts, codexProgress, regionTierOfPort
  };

  root.P7S = root.P7S || {};
  root.P7S.Rules = Rules;
  if (typeof module !== 'undefined' && module.exports) module.exports = Rules;
})(typeof globalThis !== 'undefined' ? globalThis : this);
