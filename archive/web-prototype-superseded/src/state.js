/*
 * Project Seven Seas — persistent state model and local save system.
 *
 * - All state is locale-independent: it stores stable IDs, seeds, and string
 *   keys with parameters, never display text (GDD §14.2, §19.2, §19.3).
 * - Mutations go through commit(), which applies changes to a draft copy and
 *   bumps the transaction ID only on success (GDD §15.2, §19.4).
 * - Saves: manual slots plus three rotating recovery saves. Each save is a
 *   single atomic localStorage write verified by a content hash (GDD §15).
 */
(function (root) {
  'use strict';

  const Content = root.P7S && root.P7S.Content ? root.P7S.Content : require('./content.js');
  const World = root.P7S && root.P7S.World ? root.P7S.World : require('./world.js');

  const SCHEMA_VERSION = 2;
  const SAVE_FORMAT = 'p7s-save';
  const KEYS = {
    settings: 'p7s.settings',
    recovery: i => 'p7s.recovery.' + i,
    slot: n => 'p7s.slot.' + n
  };
  const T = Content.TUNING;

  // ---------------------------------------------------------------- utilities
  function clone(value) {
    return typeof structuredClone === 'function' ? structuredClone(value) : JSON.parse(JSON.stringify(value));
  }
  // FNV-1a 32-bit hash, hex encoded.
  function hashString(str) {
    let h = 0x811c9dc5;
    for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
    return h.toString(16).padStart(8, '0');
  }
  function stateHash(state) {
    const copy = clone(state);
    copy.envelope.stateHash = '';
    return hashString(JSON.stringify(copy));
  }
  // Mulberry32 step on a uint32 state.
  function mix(s) {
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return (t ^ (t >>> 14)) >>> 0;
  }
  // The global generator's state lives in the save envelope, so suspended
  // saves resume without rerolling (GDD §15.2).
  function nextU32(state) {
    const rng = state.envelope.rng;
    rng.s = (rng.s + 0x6d2b79f5) >>> 0;
    return mix(rng.s);
  }
  function nextFloat(state) { return nextU32(state) / 4294967296; }
  function nextInt(state, min, max) { return min + Math.floor(nextFloat(state) * (max - min + 1)); }
  function pick(state, list) { return list[Math.floor(nextFloat(state) * list.length)]; }
  // Independent local generator for derived content (tavern pools, loot).
  function localRng(seed) {
    let s = seed >>> 0;
    const f = () => { s = (s + 0x6d2b79f5) >>> 0; return mix(s) / 4294967296; };
    f.int = (a, b) => a + Math.floor(f() * (b - a + 1));
    f.pick = list => list[Math.floor(f() * list.length)];
    return f;
  }
  function seedOf(str) { return parseInt(hashString(str), 16) >>> 0; }

  function nextId(state, prefix) {
    state.counters[prefix] = (state.counters[prefix] || 0) + 1;
    return prefix + '-' + String(state.counters[prefix]).padStart(4, '0');
  }
  function addLog(state, key, params) {
    state.log.unshift({ key, params: params || {}, clock: state.envelope.gameClock });
    if (state.log.length > T.logLimit) state.log.length = T.logLimit;
  }

  // -------------------------------------------------------------------- crew
  // Deterministic recruit from an identity seed (GDD §7.1). The display name
  // is derived from `seed` by the active locale's name pool.
  function makeRecruit(seed, opts) {
    const o = opts || {};
    const r = localRng(seed);
    const classPool = o.classPool || Content.BASE_CLASS_IDS;
    const classId = o.classId || r.pick(classPool);
    const originPool = o.originPool || Content.ORIGINS;
    const originId = o.originId || r.pick(originPool);
    const traits = [];
    while (traits.length < 2) { const t = r.pick(Content.TRAITS); if (!traits.includes(t)) traits.push(t); }
    const aptKeys = Object.keys(Content.APTITUDES);
    const aptitudes = [];
    while (aptitudes.length < 2) { const a = r.pick(aptKeys); if (!aptitudes.includes(a)) aptitudes.push(a); }
    const level = o.level || 1;
    const mastery = {};
    mastery[classId] = o.qualified ? T.qualifyMastery : 0;
    return {
      id: null, seed: seed >>> 0, nickname: null, originId, traits, aptitudes,
      aptClass: r.pick(Content.BASE_CLASS_IDS), petAffinity: r.pick(Content.COLOR_TAGS),
      eventId: r.pick(Content.CREW_EVENTS), event: { status: 'active', progress: 0 },
      variance: { hp: r.int(-6, 6), atk: r.int(-2, 2), def: r.int(-2, 2), spd: r.int(-1, 1) },
      level, xp: 0, classId, mastery, legacy: [], equipment: { weapon: null, outfit: null, accessory: null },
      jobFacilityUid: null, injured: false
    };
  }

  // -------------------------------------------------------------------- ship
  function makeDeck(hullDeck, index) {
    const { w, h } = hullDeck;
    const fixed = [[0, 0, 'hull'], [w - 1, 0, 'hull'], [0, h - 1, 'hull'], [w - 1, h - 1, 'hull']];
    if (index === 0) fixed.push([5, 0, 'mast']);
    const bulkhead = hullDeck.bulkhead == null ? null : hullDeck.bulkhead;
    return {
      id: 'deck-' + (index + 1), w, h, fixed, bulkhead,
      doors: bulkhead == null ? [] : [[bulkhead, Math.floor(h / 2)]],
      entry: index === 0 ? [6, h - 1] : null
    };
  }

  // ----------------------------------------------------------------- new game
  function createNewGame(seedInput) {
    const seed = (seedInput == null ? Math.floor(Math.random() * 0xffffffff) : seedInput) >>> 0;
    const hull = Content.HULLS[0];
    const locations = {};
    for (const loc of Object.values(World.LOCATIONS)) locations[loc.id] = { k: loc.initial, firstVisit: loc.initial === 'visited', rooms: [] };
    const ports = {};
    for (const p of Object.values(World.PORTS)) ports[p.id] = { tracks: Object.assign({}, p.base) };

    const state = {
      envelope: {
        schemaVersion: SCHEMA_VERSION, contentVersion: Content.CONTENT_VERSION,
        profileId: 'captain-' + hashString('profile:' + seed), seed, lastTxId: 0, lastTxKind: 'new_game',
        gameClock: 8, rng: { s: seed }, recoveryGeneration: 0, stateHash: ''
      },
      counters: {},
      captain: {
        titleKey: 'title.unknown_captain', regionId: 'dawnwater', regionsUnlocked: ['dawnwater'],
        mainStep: { dawnwater: 0 }, trialsWon: [], legendsWon: [],
        reputation: { conclave: 0, league: 0, tidebound: 0, pennants: 0 },
        postgame: false, stats: { battlesWon: 0, battlesLost: 0, retreats: 0, rations: 0, voyages: 0, hatches: 0 }, flags: {}
      },
      world: {
        currentLocationId: 'brightquay', lastSafePortId: 'brightquay', locations, chartedRoutes: [],
        clues: [], ports, shortcuts: {}, quests: {}, contracts: {}, taverns: {}
      },
      ship: {
        hullId: hull.id, hullTier: hull.tier, decks: hull.decks.map(makeDeck), stairs: [], facilities: [],
        stamina: T.startStamina, staminaMax: T.maxStamina, damage: 0, presets: []
      },
      crew: [], formation: [null, null, null, null, null, null], tactics: { stance: 'balanced', priority: 'auto' },
      pets: [],
      inventory: {
        gold: T.startGold, food: T.startFood, supplies: T.startSupplies, materials: T.startMaterials,
        specialties: {}, ingredients: {}, equipment: [], eggs: [], recipes: [], uniques: [], blueprints: [],
        ledger: { gold: 0, materials: 0 }
      },
      codex: { locations: {}, enemies: {}, classes: {}, pets: {}, recipes: [], clues: [], items: {}, hatchLog: [] },
      voyage: null, encounter: null, committed: {}, committedOrder: [], log: []
    };

    const place = (id, x, y) => state.ship.facilities.push({ uid: nextId(state, 'fac'), id, deck: 0, x, y, rot: 0, level: 1, damaged: false, stowed: false });
    place('captains_cabin', 7, 0);
    place('crew_quarters', 1, 0);
    place('pantry', 1, 3);
    place('muster_deck', 4, 2);

    const starters = [['guard', 0, 'w_shield_1'], ['duelist', 1, 'w_blade_1'], ['gunner', 4, 'w_gun_1'], ['medic', 5, 'w_kit_1']];
    starters.forEach(([classId, slot, itemId], i) => {
      const m = makeRecruit(seedOf(state.envelope.profileId + ':starter:' + i), { classId, originId: 'dawnwater_fishers' });
      m.id = nextId(state, 'crew');
      if (i === 0) m.eventId = 'proving';
      const uid = nextId(state, 'eq');
      state.inventory.equipment.push({ uid, itemId, reinforce: 0, affix: null });
      m.equipment.weapon = uid;
      state.crew.push(m);
      state.formation[slot] = m.id;
      state.codex.classes[classId] = true;
      state.codex.items[itemId] = true;
      if (!state.inventory.recipes.includes(itemId)) state.inventory.recipes.push(itemId);
    });
    state.inventory.eggs.push({ id: nextId(state, 'egg'), familyId: 'tidefin', grade: 1, inputs: [] });
    state.inventory.ingredients = { fire_pepper: 1, sea_pearl: 2, salt_crystal: 1 };
    state.codex.locations.brightquay = true;
    addLog(state, 'log.new_game', {});
    addLog(state, 'log.arrived', { location: 'loc.brightquay.name' });
    state.envelope.stateHash = stateHash(state);
    return state;
  }

  // ----------------------------------------------------------- transactions
  // Apply a mutation to a draft copy. Returns { ok, state, reasonKey }.
  // The original state is never modified, so a failed action changes nothing.
  function commit(state, kind, mutator) {
    const draft = clone(state);
    let result;
    try {
      result = mutator(draft);
    } catch (err) {
      if (root.P7S_DEBUG && typeof console !== 'undefined') console.error(err);
      return { ok: false, state, reasonKey: 'err.internal', error: String(err && err.stack || err) };
    }
    if (result && result.ok === false) return { ok: false, state, reasonKey: result.reasonKey, reasonParams: result.reasonParams };
    draft.envelope.lastTxId += 1;
    draft.envelope.lastTxKind = kind;
    return { ok: true, state: draft, value: result && result.value, saveReason: result && result.saveReason };
  }

  // Remember a committed attempt so reloading returns the same result (GDD §19.4).
  function recordAttempt(state, attemptId, value) {
    state.committed[attemptId] = value;
    state.committedOrder.push(attemptId);
    while (state.committedOrder.length > T.committedLimit) delete state.committed[state.committedOrder.shift()];
  }

  // -------------------------------------------------------------------- saves
  function pack(state, meta) {
    const snapshot = clone(state);
    snapshot.envelope.stateHash = stateHash(snapshot);
    return {
      format: SAVE_FORMAT,
      schemaVersion: SCHEMA_VERSION,
      meta: Object.assign({
        txId: snapshot.envelope.lastTxId,
        gameClock: snapshot.envelope.gameClock,
        regionId: snapshot.captain.regionId,
        locationId: snapshot.world.currentLocationId,
        crewCount: snapshot.crew.length,
        profileId: snapshot.envelope.profileId,
        generation: snapshot.envelope.recoveryGeneration,
        titleKey: snapshot.captain.titleKey,
        trials: snapshot.captain.trialsWon.length
      }, meta || {}),
      data: snapshot
    };
  }
  // Validate and unpack a stored save. Returns { ok, state, meta } or { ok:false, reasonKey }.
  function unpack(raw) {
    if (!raw) return { ok: false, reasonKey: 'err.save_missing' };
    let wrapper;
    try { wrapper = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch (e) { return { ok: false, reasonKey: 'err.save_corrupt' }; }
    if (!wrapper || wrapper.format !== SAVE_FORMAT || !wrapper.data || !wrapper.data.envelope) return { ok: false, reasonKey: 'err.save_corrupt' };
    if (wrapper.schemaVersion > SCHEMA_VERSION) return { ok: false, reasonKey: 'err.save_newer' };
    if (wrapper.schemaVersion < SCHEMA_VERSION) return { ok: false, reasonKey: 'err.save_old' };
    const data = wrapper.data;
    if (stateHash(data) !== data.envelope.stateHash) return { ok: false, reasonKey: 'err.save_corrupt' };
    return { ok: true, state: data, meta: wrapper.meta };
  }
  function createMemoryStorage() {
    const map = new Map();
    return {
      getItem: k => (map.has(k) ? map.get(k) : null),
      setItem: (k, v) => { map.set(k, String(v)); },
      removeItem: k => { map.delete(k); },
      get length() { return map.size; },
      key: i => [...map.keys()][i] || null
    };
  }
  function createSaveStore(storage) {
    function write(key, wrapper) {
      try {
        storage.setItem(key, JSON.stringify(wrapper)); // single-key write: replaced atomically
        return { ok: true };
      } catch (err) {
        return { ok: false, reasonKey: 'err.save_write_failed', error: String(err && err.name || err) };
      }
    }
    function readKey(key) {
      try { return unpack(storage.getItem(key)); } catch (e) { return { ok: false, reasonKey: 'err.save_corrupt' }; }
    }
    function listRecovery() {
      const out = [];
      for (let i = 0; i < T.recoverySaveCount; i++) {
        const r = readKey(KEYS.recovery(i));
        if (r.ok) out.push(Object.assign({ index: i }, r));
      }
      return out.sort((a, b) => b.state.envelope.recoveryGeneration - a.state.envelope.recoveryGeneration);
    }
    return {
      // Automatic safe-point save into the oldest of three rotating recovery slots.
      // With rotate=false the newest recovery slot is refreshed in place, so the
      // live state is always recoverable while older safe points are kept.
      autosave(state, reasonKey, savedAtMs, rotate) {
        const existing = listRecovery();
        const newest = Math.max(existing.length ? existing[0].state.envelope.recoveryGeneration : 0, state.envelope.recoveryGeneration);
        const generation = rotate === false && newest > 0 ? newest : newest + 1;
        const snapshot = clone(state);
        snapshot.envelope.recoveryGeneration = generation;
        const res = write(KEYS.recovery(generation % T.recoverySaveCount), pack(snapshot, { reasonKey, savedAtMs: savedAtMs || 0, kind: 'recovery' }));
        return Object.assign(res, { generation, state: res.ok ? snapshot : state });
      },
      saveSlot(n, state, savedAtMs) {
        return write(KEYS.slot(n), pack(state, { reasonKey: 'save.reason_manual', savedAtMs: savedAtMs || 0, kind: 'manual', slot: n }));
      },
      loadSlot(n) { return readKey(KEYS.slot(n)); },
      loadRecovery(index) { return readKey(KEYS.recovery(index)); },
      deleteSlot(n) { try { storage.removeItem(KEYS.slot(n)); return { ok: true }; } catch (e) { return { ok: false }; } },
      // Most recent valid recovery save; corrupt entries are skipped.
      loadLatest() {
        const list = listRecovery();
        return list.length ? list[0] : { ok: false, reasonKey: 'err.save_missing' };
      },
      listRecovery,
      listSlots() {
        const out = [];
        for (let n = 1; n <= T.manualSlotCount; n++) {
          const r = readKey(KEYS.slot(n));
          let present = false;
          try { present = storage.getItem(KEYS.slot(n)) !== null; } catch (e) { present = false; }
          out.push({ slot: n, ok: r.ok, meta: r.ok ? r.meta : null, corrupt: present && !r.ok });
        }
        return out;
      },
      wipeRecovery() {
        for (let i = 0; i < T.recoverySaveCount; i++) { try { storage.removeItem(KEYS.recovery(i)); } catch (e) { /* ignore */ } }
      }
    };
  }

  // LocalePreference is a local setting, never part of a captain save (GDD §19.2).
  const DEFAULT_SETTINGS = { locale: null, textScale: 1, reduceMotion: false, pauseAtEncounterStart: false, battleSpeed: 1 };
  function loadSettings(storage) {
    try {
      const raw = storage.getItem(KEYS.settings);
      return Object.assign({}, DEFAULT_SETTINGS, raw ? JSON.parse(raw) : {});
    } catch (e) {
      return Object.assign({}, DEFAULT_SETTINGS);
    }
  }
  function saveSettings(storage, settings) {
    try { storage.setItem(KEYS.settings, JSON.stringify(settings)); return { ok: true }; } catch (e) { return { ok: false }; }
  }

  const State = {
    SCHEMA_VERSION, SAVE_FORMAT, KEYS,
    clone, hashString, stateHash, mix, nextU32, nextFloat, nextInt, pick, localRng, seedOf, nextId, addLog,
    makeRecruit, makeDeck, createNewGame, commit, recordAttempt,
    pack, unpack, createSaveStore, createMemoryStorage,
    DEFAULT_SETTINGS, loadSettings, saveSettings
  };

  root.P7S = root.P7S || {};
  root.P7S.State = State;
  if (typeof module !== 'undefined' && module.exports) module.exports = State;
})(typeof globalThis !== 'undefined' ? globalThis : this);
