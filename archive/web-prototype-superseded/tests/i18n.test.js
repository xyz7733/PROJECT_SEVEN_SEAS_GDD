'use strict';
// Gate 1: bilingual tables with full key and placeholder parity, plus
// locale-independent state (names and text are derived at render time).
const test = require('node:test');
const { assert, State, I18n, Actions, newGame, act, sail } = require('./helpers.js');
const Keys = require('./locale-keys.js');
const en = require('../locales/en.js');
const zh = require('../locales/zh-CN.js');

const LOCALES = { en, 'zh-CN': zh };

test('both locales register metadata and name pools', () => {
  for (const [code, L] of Object.entries(LOCALES)) {
    assert.equal(L.meta.code, code);
    assert.ok(L.meta.nativeName && L.meta.htmlLang && L.meta.numberLocale);
    assert.ok(L.names.given.length >= 20 && L.names.family.length >= 20, code + ' name pool');
    assert.match(L.names.format, /\{given\}/);
    assert.match(L.names.format, /\{family\}/);
    assert.ok(L.strings['lang.choose'] && L.strings['lang.note']);
  }
  assert.deepEqual(I18n.SUPPORTED, ['en', 'zh-CN']);
});

test('every key the game can request exists in both locales', () => {
  const required = Keys.requiredKeys();
  assert.ok(required.length > 1500, 'key enumeration found ' + required.length);
  for (const [code, L] of Object.entries(LOCALES)) {
    const missing = required.filter(k => !Object.prototype.hasOwnProperty.call(L.strings, k));
    assert.deepEqual(missing, [], code + ' is missing keys');
  }
});

test('locales have identical key sets and identical placeholders', () => {
  const ek = Object.keys(en.strings).sort();
  const zk = Object.keys(zh.strings).sort();
  assert.deepEqual(zk, ek);
  for (const k of ek) {
    assert.deepEqual(Keys.placeholders(zh.strings[k]), Keys.placeholders(en.strings[k]), 'placeholder mismatch in ' + k);
    assert.ok(String(en.strings[k]).length > 0 && String(zh.strings[k]).length > 0, 'empty string ' + k);
  }
});

test('Chinese text stays in locale resources only', () => {
  const fs = require('fs');
  const path = require('path');
  const root = path.join(__dirname, '..');
  const files = [];
  for (const dir of ['src', 'tests']) for (const f of fs.readdirSync(path.join(root, dir))) files.push(path.join(root, dir, f));
  for (const f of ['index.html', 'styles.css', 'package.json', 'README.md', 'IMPLEMENTATION_STATUS.md']) if (fs.existsSync(path.join(root, f))) files.push(path.join(root, f));
  for (const f of files) assert.doesNotMatch(fs.readFileSync(f, 'utf8'), /[\u4e00-\u9fff]/, f + ' contains CJK text');
});

test('translator formats numbers, nested keys, missing keys, and composed names', () => {
  I18n.setLocale('en');
  assert.equal(I18n.t('err.no_gold', { need: 1500 }), 'Needs 1,500 gold.');
  assert.equal(I18n.t('log.arrived', { location: 'loc.brightquay.name' }), 'Arrived at Brightquay.');
  assert.equal(I18n.t('item.w_blade.t1'), 'Driftwood Blade');
  assert.equal(I18n.t('pet.tidefin_companion_evo.name'), 'Tidefin Champion');
  assert.equal(I18n.t('no.such_key'), '⟦no.such_key⟧');
  assert.ok(I18n.missingKeys().includes('no.such_key'));
  assert.match(I18n.t('quest.dawnwater.0'), /Gull Rock/);

  I18n.setLocale('zh-CN');
  assert.equal(I18n.t('log.arrived', { location: 'loc.brightquay.name' }), '\u62b5\u8fbe \u660e\u6e2f\u3002');
  assert.equal(I18n.t('item.w_blade.t1'), '\u6f02\u6728\u5200\u5251');
  assert.equal(I18n.t('pet.tidefin_companion_evo.name'), '\u6f6e\u9ccd·\u51a0\u519b');
  assert.match(I18n.t('quest.dawnwater.0'), /\u9e25\u5ca9/);
  I18n.setLocale('en');
});

test('saves are locale-independent and names come from stable seeds', () => {
  let s = newGame(77);
  s = sail(s, 'gull_rock');
  const json = JSON.stringify(State.pack(s));
  for (const L of Object.values(LOCALES)) {
    for (const probe of [L.strings['loc.brightquay.name'], L.strings['hull.starter.name'], L.strings['class.guard.name']]) {
      assert.ok(!json.includes('"' + probe + '"'), 'save contains localized text ' + probe);
    }
  }
  assert.doesNotMatch(json, /[\u4e00-\u9fff]/);
  assert.ok(!('locale' in s.envelope) && !('locale' in s.captain));

  const m = s.crew[0];
  I18n.setLocale('en'); const enName = I18n.crewName(m); const enLog = s.log.map(e => I18n.logLine(e, s));
  I18n.setLocale('zh-CN'); const zhName = I18n.crewName(m); const zhLog = s.log.map(e => I18n.logLine(e, s));
  I18n.setLocale('en');
  assert.equal(I18n.crewName(m), enName, 'same seed gives the same name again');
  assert.notEqual(enName, zhName);
  assert.match(zhName, /[\u4e00-\u9fff]/);
  for (const line of enLog.concat(zhLog)) {
    assert.doesNotMatch(line, /⟦|\{[a-zA-Z]+\}/, 'unrendered log line: ' + line);
  }
});

test('every failure reason an action returns renders in both locales', () => {
  const s = newGame(5);
  const probes = [
    Actions.depart(s, 'tidefin_grotto'), Actions.depart(s, 'brightquay'), Actions.serveRation(Object.assign(State.clone(s), { ship: Object.assign({}, s.ship, { stamina: 100 }) })),
    Actions.enterRoom(s, 'landing'), Actions.emergencyReturn(s), Actions.resolveEncounter(s, 'enc-nope', []),
    Actions.changeClass(s, s.crew[0].id, 'guardian'), Actions.buildFacility(s, 'pet_lab', 0, 2, 1, 0)
  ];
  for (const code of ['en', 'zh-CN']) {
    I18n.setLocale(code);
    for (const r of probes) {
      assert.equal(r.ok, false);
      const text = I18n.reason(r);
      assert.ok(text.length > 0);
      assert.doesNotMatch(text, /⟦|\{[a-zA-Z]+\}/, code + ' ' + r.reasonKey + ' → ' + text);
    }
  }
  I18n.setLocale('en');
  act(s, 'setTactics', 'defensive', 'survival');
});
