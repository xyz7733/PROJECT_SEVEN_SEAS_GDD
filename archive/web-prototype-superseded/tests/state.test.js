'use strict';
// Gate 10: atomic transactions, manual slots, three rotating recovery saves,
// corruption detection, and write-failure handling.
const test = require('node:test');
const { assert, Content, State, Actions, newGame, act, sail } = require('./helpers.js');

test('new games are deterministic per seed and carry stable IDs', () => {
  const a = newGame(42), b = newGame(42), c = newGame(43);
  assert.deepEqual(a, b);
  assert.notDeepEqual(a.crew.map(m => m.seed), c.crew.map(m => m.seed));
  assert.equal(new Set(a.crew.map(m => m.id)).size, a.crew.length);
  for (const m of a.crew) assert.match(m.id, /^crew-\d+$/);
  for (const f of a.ship.facilities) assert.match(f.uid, /^fac-\d+$/);
});

test('a failed transaction leaves the state untouched; success bumps the tx id', () => {
  const s = newGame(1);
  const before = JSON.stringify(s);
  const r = Actions.buildFacility(s, 'hatchery', 0, 0, 0, 0); // hull corner
  assert.equal(r.ok, false);
  assert.equal(r.state, s);
  assert.equal(JSON.stringify(s), before);
  const r2 = Actions.setTactics(s, 'defensive', null);
  assert.ok(r2.ok);
  assert.equal(r2.state.envelope.lastTxId, s.envelope.lastTxId + 1);
  assert.equal(JSON.stringify(s), before, 'original is never mutated');
});

test('pack/unpack round-trips and rejects tampered, newer, older, or garbage saves', () => {
  const s = sail(newGame(9), 'gull_rock');
  const packed = State.pack(s, { reasonKey: 'save.reason_manual' });
  const back = State.unpack(JSON.stringify(packed));
  assert.ok(back.ok);
  assert.deepEqual(back.state, Object.assign(State.clone(s), { envelope: Object.assign({}, s.envelope, { stateHash: back.state.envelope.stateHash }) }));

  const tampered = JSON.parse(JSON.stringify(packed)); tampered.data.inventory.gold += 999;
  assert.equal(State.unpack(JSON.stringify(tampered)).reasonKey, 'err.save_corrupt');
  const newer = JSON.parse(JSON.stringify(packed)); newer.schemaVersion = State.SCHEMA_VERSION + 1;
  assert.equal(State.unpack(newer).reasonKey, 'err.save_newer');
  const older = JSON.parse(JSON.stringify(packed)); older.schemaVersion = State.SCHEMA_VERSION - 1;
  assert.equal(State.unpack(older).reasonKey, 'err.save_old');
  assert.equal(State.unpack('{not json').reasonKey, 'err.save_corrupt');
  assert.equal(State.unpack(null).reasonKey, 'err.save_missing');
});

test('recovery saves rotate through exactly three slots and the newest wins', () => {
  const storage = State.createMemoryStorage();
  const store = State.createSaveStore(storage);
  let s = newGame(3);
  const gens = [];
  for (let i = 0; i < 5; i++) {
    s = act(s, 'setTactics', i % 2 ? 'balanced' : 'defensive', null);
    const r = store.autosave(s, 'save.reason_port', 1000 + i);
    assert.ok(r.ok);
    s = r.state;
    gens.push(r.generation);
  }
  assert.deepEqual(gens, [1, 2, 3, 4, 5]);
  const list = store.listRecovery();
  assert.equal(list.length, Content.TUNING.recoverySaveCount);
  assert.deepEqual(list.map(x => x.state.envelope.recoveryGeneration), [5, 4, 3]);
  assert.equal(store.loadLatest().state.envelope.lastTxId, s.envelope.lastTxId);

  // Refreshing in place (rotate=false) keeps the older safe points.
  s = act(s, 'setTactics', 'aggressive', null);
  const refresh = store.autosave(s, 'save.reason_auto', 2000, false);
  assert.equal(refresh.generation, 5);
  assert.deepEqual(store.listRecovery().map(x => x.state.envelope.recoveryGeneration), [5, 4, 3]);
  assert.equal(store.loadLatest().state.tactics.stance, 'aggressive');
});

test('a corrupt recovery slot is skipped and older saves still load', () => {
  const storage = State.createMemoryStorage();
  const store = State.createSaveStore(storage);
  let s = newGame(4);
  for (let i = 0; i < 3; i++) { s = act(s, 'setTactics', 'defensive', null); s = store.autosave(s, 'save.reason_port', i).state; }
  const newestKey = State.KEYS.recovery(3 % Content.TUNING.recoverySaveCount);
  storage.setItem(newestKey, storage.getItem(newestKey).slice(0, 200));
  const latest = store.loadLatest();
  assert.ok(latest.ok);
  assert.equal(latest.state.envelope.recoveryGeneration, 2);
});

test('manual slots save, list, load, report corruption, and delete', () => {
  const storage = State.createMemoryStorage();
  const store = State.createSaveStore(storage);
  const s = sail(newGame(6), 'gull_rock');
  assert.ok(store.saveSlot(1, s, 5).ok);
  const slots = store.listSlots();
  assert.equal(slots.length, Content.TUNING.manualSlotCount);
  assert.ok(slots[0].ok && !slots[1].ok && !slots[1].corrupt);
  assert.equal(store.loadSlot(1).state.world.currentLocationId, 'gull_rock');
  storage.setItem(State.KEYS.slot(2), '{"format":"broken"}');
  assert.ok(store.listSlots()[1].corrupt);
  assert.ok(store.deleteSlot(1).ok);
  assert.equal(store.loadSlot(1).reasonKey, 'err.save_missing');
});

test('a failed write reports an error and keeps the previous save intact', () => {
  const inner = State.createMemoryStorage();
  let full = false;
  const storage = {
    getItem: k => inner.getItem(k), removeItem: k => inner.removeItem(k), key: i => inner.key(i), get length() { return inner.length; },
    setItem: (k, v) => { if (full) { const e = new Error('quota'); e.name = 'QuotaExceededError'; throw e; } inner.setItem(k, v); }
  };
  const store = State.createSaveStore(storage);
  const s = newGame(8);
  assert.ok(store.saveSlot(1, s, 1).ok);
  full = true;
  const s2 = act(s, 'setTactics', 'aggressive', null);
  const r = store.saveSlot(1, s2, 2);
  assert.equal(r.ok, false);
  assert.equal(r.reasonKey, 'err.save_write_failed');
  const auto = store.autosave(s2, 'save.reason_port', 3);
  assert.equal(auto.ok, false);
  assert.equal(auto.state, s2, 'state is returned unchanged when the write fails');
  assert.equal(store.loadSlot(1).state.tactics.stance, s.tactics.stance);
});

test('settings (including locale preference) are stored apart from saves', () => {
  const storage = State.createMemoryStorage();
  State.saveSettings(storage, Object.assign({}, State.DEFAULT_SETTINGS, { locale: 'zh-CN' }));
  assert.equal(State.loadSettings(storage).locale, 'zh-CN');
  const store = State.createSaveStore(storage);
  store.saveSlot(1, newGame(2), 0);
  assert.doesNotMatch(storage.getItem(State.KEYS.slot(1)), /zh-CN/);
  storage.setItem(State.KEYS.settings, '{bad');
  assert.deepEqual(State.loadSettings(storage), State.DEFAULT_SETTINGS);
});
