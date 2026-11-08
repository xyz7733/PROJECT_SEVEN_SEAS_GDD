'use strict';
// End-to-end: a bot plays a new save through all ten regions to the final
// trial and postgame using only the public action API. Every log line the
// campaign produces must render in both locales, and saves taken along the
// way must round-trip exactly.
const test = require('node:test');
const { assert, Content, State, Rules, Actions, I18n } = require('./helpers.js');
const { playCampaign } = require('./bot.js');

test('a full campaign reaches the title and postgame; logs render in both locales; saves round-trip', () => {
  const entries = new Map();
  const originals = {};
  let calls = 0, roundTrips = 0;
  const skip = new Set(['run', 'afterChange', 'buildAllies', 'battleXp', 'roomAccessible', 'itemNameKey']);
  for (const [name, fn] of Object.entries(Actions)) {
    if (typeof fn !== 'function' || skip.has(name)) continue;
    originals[name] = fn;
    Actions[name] = function (...args) {
      const r = fn.apply(this, args);
      if (r && r.ok && r.state) {
        for (const e of r.state.log) entries.set(JSON.stringify([e.key, e.params]), e);
        if (++calls % 400 === 0) {
          const back = State.unpack(JSON.stringify(State.pack(r.state)));
          assert.ok(back.ok, 'save at call ' + calls + ': ' + back.reasonKey);
          const a = State.clone(r.state); const b = back.state;
          a.envelope.stateHash = b.envelope.stateHash;
          assert.deepEqual(b, a, 'save round-trip at call ' + calls);
          roundTrips++;
        }
      }
      return r;
    };
  }
  let result;
  try { result = playCampaign(2026); } finally { Object.assign(Actions, originals); }

  const s = result.state;
  assert.ok(result.ok, 'campaign did not finish: ' + result.reason);
  assert.equal(s.captain.postgame, true);
  assert.equal(s.captain.titleKey, 'title.strongest');
  assert.deepEqual(s.captain.regionsUnlocked.slice().sort(), Content.REGION_ORDER.slice().sort());
  assert.equal(s.captain.trialsWon.length, 10);
  assert.equal(s.ship.hullTier, 4, 'the same ship grew to the final hull');
  assert.ok(Rules.mainStatus(s).done);
  assert.ok(roundTrips >= 3, 'took ' + roundTrips + ' mid-campaign saves');
  assert.ok(entries.size > 60, 'collected ' + entries.size + ' distinct log lines');

  const keys = new Set([...entries.values()].map(e => e.key));
  for (const k of ['log.arrived', 'log.main_done', 'log.region_unlocked', 'log.postgame', 'log.banked']) assert.ok(keys.has(k), 'campaign logged ' + k);
  for (const code of I18n.SUPPORTED) {
    I18n.setLocale(code);
    for (const e of entries.values()) {
      const line = I18n.logLine(e, s);
      assert.ok(line.length > 0);
      assert.doesNotMatch(line, /⟦|\{[a-zA-Z]+\}/, code + ' ' + e.key + ' → ' + line);
    }
    for (const m of s.crew) assert.ok(I18n.crewName(m).length > 0);
    assert.doesNotMatch(I18n.t(s.captain.titleKey), /⟦/);
  }
  I18n.setLocale('en');
  assert.deepEqual(I18n.missingKeys(), [], 'no key was missing during rendering');
  // Postgame legends are open after the title.
  assert.equal(Actions.startLegend(s).ok, false);
  assert.notEqual(Actions.startLegend(s).reasonKey, 'err.postgame_only');
});

test('the campaign is reproducible from the seed', () => {
  const a = playCampaign(7, { stopAtRegion: 'verdant_maw' });
  const b = playCampaign(7, { stopAtRegion: 'verdant_maw' });
  assert.deepEqual(a.state, b.state);
});
