// Browser smoke test over the Chrome DevTools Protocol (no npm packages).
// Opens index.html from file:// in headless Chrome with a fresh profile and
// plays through the real UI: language picker → new game → every view →
// sail → room battle using the pause menu → manual save → page reload →
// continue → mid-battle reload (no reroll) → language switch with restart →
// every view in Simplified Chinese → phone-width layout check.
//
// Usage: node tests/smoke.mjs            (screenshots go to $SMOKE_OUT or the OS temp dir)
//        CHROME=/path/to/chrome node tests/smoke.mjs
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = process.env.SMOKE_OUT || path.join(os.tmpdir(), 'p7s-smoke');
fs.mkdirSync(OUT, { recursive: true });
const PROFILE = fs.mkdtempSync(path.join(os.tmpdir(), 'p7s-chrome-'));
const PORT = 9300 + Math.floor(Math.random() * 500);
const URL_ = pathToFileURL(path.join(ROOT, 'index.html')).href;

function findChrome() {
  const c = [process.env.CHROME, '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'];
  return c.find(p => p && fs.existsSync(p));
}
const CHROME = findChrome();
if (!CHROME) { console.log('SKIP: no Chrome/Chromium found (set CHROME=/path/to/chrome)'); process.exit(0); }

const sleep = ms => new Promise(r => setTimeout(r, ms));
const results = [];
let failures = 0;
function check(cond, label, detail) {
  results.push((cond ? 'PASS ' : 'FAIL ') + label + (cond || detail == null ? '' : ' — ' + detail));
  if (!cond) failures++;
  return cond;
}

const chrome = spawn(CHROME, ['--headless=new', '--no-sandbox', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  '--remote-debugging-port=' + PORT, '--user-data-dir=' + PROFILE, '--window-size=1366,900', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
chrome.stderr.on('data', () => {});

async function json(p) { const r = await fetch('http://127.0.0.1:' + PORT + p); return r.json(); }
let target = null;
for (let i = 0; i < 100 && !target; i++) {
  try { target = (await json('/json/list')).find(t => t.type === 'page'); } catch { /* not up yet */ }
  if (!target) await sleep(100);
}
if (!target) { console.error('Chrome did not start'); chrome.kill(); process.exit(1); }

// ------------------------------------------------------------ CDP client
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let seq = 0;
const pending = new Map();
const events = [];
const consoleErrors = [];
ws.onmessage = ev => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(m.error.message)) : p.res(m.result); return; }
  events.push(m);
  if (m.method === 'Runtime.exceptionThrown') consoleErrors.push('exception: ' + (m.params.exceptionDetails.exception && m.params.exceptionDetails.exception.description || m.params.exceptionDetails.text));
  if (m.method === 'Runtime.consoleAPICalled' && (m.params.type === 'error' || m.params.type === 'assert')) consoleErrors.push('console.' + m.params.type + ': ' + m.params.args.map(a => a.value || a.description).join(' '));
  if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') consoleErrors.push('log: ' + m.params.entry.text + ' ' + (m.params.entry.url || ''));
};
const send = (method, params) => new Promise((res, rej) => { const id = ++seq; pending.set(id, { res, rej }); ws.send(JSON.stringify({ id, method, params: params || {} })); });
async function ev(expr) {
  const r = await send('Runtime.evaluate', { expression: '(async () => { ' + expr + ' })()', awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error('eval failed: ' + (r.exceptionDetails.exception ? r.exceptionDetails.exception.description : r.exceptionDetails.text) + '\n' + expr);
  return r.result.value;
}
async function waitFor(expr, label, ms = 6000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { if (await ev('return !!(' + expr + ');')) return true; await sleep(60); }
  throw new Error('timeout waiting for ' + label + ' (' + expr + ')');
}
async function shot(name) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync(path.join(OUT, name + '.png'), Buffer.from(r.data, 'base64'));
}
async function loadPage(reload) {
  const loaded = new Promise(res => { const iv = setInterval(() => { if (events.some(e => e.method === 'Page.loadEventFired' && !e.seen && (e.seen = true))) { clearInterval(iv); res(); } }, 30); });
  if (reload) await send('Page.reload', { ignoreCache: true }); else await send('Page.navigate', { url: URL_ });
  await loaded;
  await waitFor('window.P7S && window.P7S.app && document.getElementById("app").children.length', 'boot');
}

// In-page helpers: find buttons by visible text and click them.
const LIB = `
  const P = window.P7S, app = P.app, t = P.I18n.t;
  const vis = el => el && !el.disabled && el.offsetParent !== null;
  const byText = (sel, text, root) => [...(root || document).querySelectorAll(sel)].find(b => vis(b) && b.textContent.includes(text));
  const click = el => { if (!el) throw new Error('element not found'); el.click(); return true; };
  const pageText = () => document.body.innerText;
`;
const run = body => ev(LIB + body);

async function scanText(label) {
  const r = await run(`const s = pageText(); return { bad: (s.match(/⟦[^⟧]*⟧/g) || []).slice(0, 5), ph: (s.match(/\\{[a-zA-Z_]+\\}/g) || []).slice(0, 5), cjk: /[\\u4e00-\\u9fff]/.test(document.getElementById('main') ? document.getElementById('main').innerText : s), len: s.length };`);
  check(r.bad.length === 0, label + ': no missing-key markers', r.bad.join(' '));
  check(r.ph.length === 0, label + ': no raw {placeholders}', r.ph.join(' '));
  return r;
}
async function settleModalsAndBattles(maxRounds = 12) {
  for (let i = 0; i < maxRounds; i++) {
    const st = await run(`return { modal: !!document.querySelector('.modal'), battle: !document.getElementById('battle').hidden, result: !!document.querySelector('.b-result') };`);
    if (st.result) { await run(`click(document.querySelector('.b-result .btn.primary'));`); await sleep(120); continue; }
    if (st.battle) { await run(`click(byText('#battle button', t('battle.skip')));`); await waitFor('document.querySelector(".b-result")', 'battle result'); continue; }
    if (st.modal) { await run(`click([...document.querySelectorAll('.modal .modal-actions button')].find(vis));`); await sleep(120); continue; }
    return;
  }
}
const VIEWS = ['home', 'ship', 'map', 'crew', 'port', 'pets', 'codex', 'system'];
// Horizontal overflow of the page or of the main scroll pane; names the
// widest element that sticks out so a failure points at the culprit.
const overflowX = () => run(`const m = document.getElementById('main');
  const px = Math.max(document.documentElement.scrollWidth - window.innerWidth, m.scrollWidth - m.clientWidth);
  let culprit = '';
  if (px > 1) { const edge = m.getBoundingClientRect().right; let worst = 0;
    for (const el of m.querySelectorAll('*')) { const r = el.getBoundingClientRect().right - edge; if (r > worst + 1) { worst = r; culprit = el.tagName.toLowerCase() + '.' + [...el.classList].join('.'); } } }
  return { px, culprit };`);
async function visitAllViews(prefix, expectCjk) {
  for (let i = 0; i < VIEWS.length; i++) {
    await run(`click(document.querySelectorAll('#nav .nav-btn')[${i}]);`);
    await sleep(80);
    const ok = await run(`return document.querySelector('#nav .nav-btn.on') === document.querySelectorAll('#nav .nav-btn')[${i}] && document.getElementById('main').children.length > 0 && document.getElementById('main').innerText.trim().length > 20;`);
    check(ok, prefix + ' view ' + VIEWS[i] + ' renders');
    const r = await scanText(prefix + ' ' + VIEWS[i]);
    if (expectCjk) check(r.cjk, prefix + ' ' + VIEWS[i] + ' shows Chinese text');
    const over = await overflowX();
    check(over.px <= 1, prefix + ' ' + VIEWS[i] + ': no horizontal overflow at desktop width', over.px + 'px, widest: ' + over.culprit);
    await shot(prefix + '-' + VIEWS[i]);
  }
}
const snapshot = () => run(`const s = app.state; return { tx: s.envelope.lastTxId, loc: s.world.currentLocationId, stamina: s.ship.stamina, food: s.inventory.food, gold: s.inventory.gold, ledger: s.inventory.ledger, crew: s.crew.map(m => m.id + ':' + m.level + ':' + m.xp), enc: s.encounter && s.encounter.attemptId, cleared: s.world.locations.gull_rock.rooms.slice() };`);

try {
  await send('Page.enable'); await send('Runtime.enable'); await send('Log.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1366, height: 900, deviceScaleFactor: 1, mobile: false });

  // ---------------------------------------------------- 1. first run (en)
  await loadPage(false);
  check(await run(`return location.protocol === 'file:';`), 'runs from file://');
  check(await run(`return document.querySelectorAll('.lang-btn').length === 2;`), 'startup language picker shows two languages');
  const picker = await run(`return pageText();`);
  check(/English/.test(picker) && /\u7b80\u4f53\u4e2d\u6587/.test(picker), 'picker names both languages natively');
  await shot('00-language-picker');
  await run(`click(document.querySelector('.lang-btn[lang="en"]'));`);
  await waitFor('document.querySelector(".title-screen")', 'title screen');
  check(await run(`return document.documentElement.lang === 'en' && !byText('.title-actions button', t('title.continue'));`), 'title screen in English with no save yet');
  await shot('01-title-en');
  await run(`click(byText('.title-actions button', t('title.new_game')));`);
  await waitFor('document.getElementById("main") && window.P7S.app.state', 'game shell');
  await visitAllViews('en', false);

  // ------------------------------------------- keyboard shortcuts (§13.3)
  const key = k => run(`document.body.dispatchEvent(new KeyboardEvent('keydown', { key: ${JSON.stringify(k)}, bubbles: true })); return app.ui.view;`);
  check(await key('2') === 'ship', 'key 2 opens the ship view');
  await run(`document.querySelectorAll('#main details').forEach(d => { d.open = true; }); click(byText('#main button', t('ship.build')));`);
  const placing = await run(`return app.ui.shipMode;`);
  check(/^build:/.test(placing), 'Build puts the ship editor into placement mode', placing);
  await key('r');
  check(await run(`return app.ui.shipRot === 1 && !!byText('#main button[aria-pressed="true"]', t('ship.rotate'));`), 'R rotates the facility being placed');
  await key('Escape');
  check(await run(`return app.ui.shipMode === 'select' && !byText('#main button', t('ship.rotate'));`), 'Esc cancels placement');
  check(await key('8') === 'system' && await key('1') === 'home', 'number keys switch views');

  // ---------------------------------------- 2. sail and fight via the UI
  await run(`click(document.querySelectorAll('#nav .nav-btn')[2]);`);
  await run(`click(byText('.marker', t('loc.gull_rock.name')));`);
  await sleep(80);
  const food0 = (await snapshot()).food;
  await run(`click(byText('#main button', t('route.sail')));`);
  await sleep(150);
  await settleModalsAndBattles();
  let snap = await snapshot();
  check(snap.loc === 'gull_rock', 'sailed to Gull Rock through the map', JSON.stringify(snap));
  check(snap.food < food0, 'food was charged at departure');
  await shot('10-site-gull-rock');
  const st0 = snap.stamina;
  await run(`click(byText('#main button', t('site.fight')));`);
  await waitFor('!document.getElementById("battle").hidden && document.querySelector(".b-pause")', 'battle overlay');
  await shot('11-battle-live');
  // Pause, change stance and focus, resume at x4.
  await run(`click(document.querySelector('.b-pause'));`);
  await waitFor('document.querySelector(".b-menu-in")', 'pause menu');
  await shot('12-battle-paused');
  await run(`click(byText('.b-menu-in button', t('stance.defensive.name')));`);
  await sleep(60);
  check(await run(`return app.battle.sim.stance === 'defensive';`), 'pause menu stance applies immediately');
  await run(`const g = document.querySelectorAll('.b-menu-in .b-group')[2]; click([...g.querySelectorAll('button')].filter(vis)[1]);`);
  await sleep(60);
  check(await run(`return !!app.battle.sim.focus;`), 'pause menu focus target applies');
  await run(`click(document.querySelector('.b-pause')); click(document.querySelector('.b-speed[data-speed="4"]'));`);
  const cmds = await run(`return app.battle.sim.commands.map(c => c.type);`);
  check(cmds.includes('stance') && cmds.includes('focus'), 'commands are recorded for the replay', cmds.join(','));
  await waitFor('document.querySelector(".b-result")', 'battle end', 60000);
  await shot('13-battle-result');
  await run(`click(document.querySelector('.b-result .btn.primary'));`);
  await sleep(150);
  await settleModalsAndBattles();
  snap = await snapshot();
  check(snap.stamina === st0 - 8, 'room cost 8 stamina', st0 + ' → ' + snap.stamina);
  check(snap.enc == null, 'encounter resolved and committed');

  // --------------------------------------------- 3. manual save + reload
  await run(`click(document.querySelectorAll('#nav .nav-btn')[7]);`);
  await run(`click(byText('#main .slot-row button', t('system.save_here')));`);
  await sleep(100);
  check(await run(`return app.store.loadSlot(1).ok;`), 'manual slot 1 saved');
  const beforeReload = await snapshot();
  await loadPage(true);
  await waitFor('document.querySelector(".title-screen")', 'title after reload');
  check(await run(`return !!byText('.title-actions button', t('title.continue'));`), 'title offers Continue after reload');
  await run(`click(byText('.title-actions button', t('title.continue')));`);
  await waitFor('window.P7S.app.state && document.getElementById("main")', 'continued');
  const afterReload = await snapshot();
  check(JSON.stringify(afterReload) === JSON.stringify(beforeReload), 'reload resumes the exact committed state', JSON.stringify([beforeReload, afterReload]));

  // ------------------------------------ 4. reload in the middle of a battle
  await run(`click(document.querySelectorAll('#nav .nav-btn')[2]);`);
  await sleep(60);
  await run(`click(byText('#main button', t('site.fight')));`);
  await waitFor('!document.getElementById("battle").hidden', 'second battle');
  const mid = await run(`const e = app.state.encounter; const r = P.Combat.resolve(e.spec, []); return { id: e.attemptId, stamina: app.state.ship.stamina, outcome: r.outcome, time: r.time };`);
  await sleep(400);
  await loadPage(true);
  await waitFor('document.querySelector(".title-screen")', 'title after mid-battle reload');
  await run(`click(byText('.title-actions button', t('title.continue')));`);
  await waitFor('!document.getElementById("battle").hidden', 'battle resumes after reload');
  const resumed = await run(`return { id: app.state.encounter && app.state.encounter.attemptId, stamina: app.state.ship.stamina };`);
  check(resumed.id === mid.id, 'the suspended encounter is restored');
  check(resumed.stamina === mid.stamina, 'reload does not refund or recharge stamina');
  await run(`click(byText('#battle button', t('battle.skip')));`);
  await waitFor('document.querySelector(".b-result")', 'resumed battle result');
  const committed = await run(`return app.state.committed['${mid.id}'];`);
  check(committed && committed.outcome === mid.outcome && committed.time === mid.time, 'same outcome as before the reload (no reroll)', JSON.stringify([mid, committed]));
  await run(`click(document.querySelector('.b-result .btn.primary'));`);
  await sleep(150);
  await settleModalsAndBattles();

  // -------------------------------------- 5. language switch with restart
  const preSwitch = await snapshot();
  await run(`click(document.querySelectorAll('#nav .nav-btn')[7]);`);
  await run(`const s = [...document.querySelectorAll('#main select')].find(x => [...x.options].some(o => o.value === 'zh-CN')); s.value = 'zh-CN'; s.dispatchEvent(new Event('change'));`);
  await sleep(60);
  const loaded = new Promise(res => { const iv = setInterval(() => { if (events.some(e => e.method === 'Page.loadEventFired' && !e.seen && (e.seen = true))) { clearInterval(iv); res(); } }, 30); });
  await run(`click(byText('#main button', t('system.restart_language')));`);
  await sleep(100);
  await run(`click(document.querySelector('.modal .btn.primary'));`);
  await loaded;
  await waitFor('window.P7S && window.P7S.app && document.querySelector(".title-screen")', 'title in Chinese');
  check(await run(`return document.documentElement.lang === 'zh-CN' && /[\\u4e00-\\u9fff]/.test(pageText());`), 'restart applies Simplified Chinese');
  await shot('20-title-zh');
  await run(`click(byText('.title-actions button', t('title.continue')));`);
  await waitFor('window.P7S.app.state && document.getElementById("main")', 'continued in Chinese');
  const postSwitch = await snapshot();
  check(JSON.stringify(postSwitch) === JSON.stringify(preSwitch), 'the save is locale-independent across the switch');
  await visitAllViews('zh', true);

  // --------------------------------------------------- 6. storage + keys
  const store = await run(`const out = []; for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); out.push([k, /[\\u4e00-\\u9fff]/.test(localStorage.getItem(k))]); } return out;`);
  check(store.length >= 3 && store.every(([, cjk]) => !cjk), 'stored saves contain no localized text', JSON.stringify(store));
  check(await run(`return P.I18n.missingKeys().length === 0;`), 'no missing translation keys were requested', JSON.stringify(await run(`return P.I18n.missingKeys();`)));

  // --------------------------------------------- 7. phone-width layout
  await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  for (let i = 0; i < VIEWS.length; i++) {
    await run(`click(document.querySelectorAll('#nav .nav-btn')[${i}]);`);
    await sleep(80);
    const over = await overflowX();
    check(over.px <= 1, 'phone width: ' + VIEWS[i] + ' has no horizontal overflow', over.px + 'px, widest: ' + over.culprit);
    if (i === 0 || i === 1 || i === 2) await shot('30-phone-' + VIEWS[i]);
  }

  check(consoleErrors.length === 0, 'no console errors or exceptions', consoleErrors.slice(0, 5).join(' | '));
} catch (e) {
  check(false, 'smoke run aborted', e.stack || String(e));
  try { await shot('99-failure'); } catch { /* ignore */ }
} finally {
  try { ws.close(); } catch { /* ignore */ }
  chrome.kill('SIGKILL');
  await sleep(200);
  try { fs.rmSync(PROFILE, { recursive: true, force: true }); } catch { /* ignore */ }
}

console.log(results.join('\n'));
console.log('\n' + (results.length - failures) + '/' + results.length + ' checks passed; screenshots in ' + OUT);
process.exit(failures ? 1 : 0);
