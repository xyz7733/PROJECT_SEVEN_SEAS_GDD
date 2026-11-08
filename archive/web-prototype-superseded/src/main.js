/*
 * Project Seven Seas — application controller.
 *
 * Boot order: storage probe → settings → startup language choice (first run)
 * → title screen (continue / new / load / language) → game shell.
 * Every player action is a pure transaction from Actions; a successful one
 * replaces the state and is autosaved immediately, so a reload always resumes
 * from the last committed transaction (GDD §19).
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, State, Actions, Rules, World, I18n: I, UI, Art, Views, Battle } = P;
  const { h, btn, icon, clear, tag, bar } = UI;
  const t = I.t;

  const NAV = [
    { id: 'home', icon: 'helm' }, { id: 'ship', icon: 'ship' }, { id: 'map', icon: 'map' }, { id: 'crew', icon: 'crew' },
    { id: 'port', icon: 'port' }, { id: 'pets', icon: 'pets' }, { id: 'codex', icon: 'codex' }, { id: 'system', icon: 'system' }
  ];

  // ---------------------------------------------------------------- storage
  function probeStorage() {
    try {
      const ls = root.localStorage;
      const k = 'p7s.probe';
      ls.setItem(k, '1'); ls.removeItem(k);
      return { storage: ls, kind: 'local' };
    } catch (e) {
      return { storage: State.createMemoryStorage(), kind: 'memory' };
    }
  }

  const app = {
    state: null, ui: { view: 'home' }, settings: null, store: null, storage: null, storageKind: 'memory',
    lastSaveOk: 0, lastSaveError: null, battle: null, busy: false, screen: 'boot'
  };
  P.app = app;

  // ------------------------------------------------------------ persistence
  function persist(reasonKey, rotate) {
    const res = app.store.autosave(app.state, reasonKey || 'save.reason_auto', Date.now(), rotate);
    if (res.ok) { app.state = res.state; app.lastSaveOk = Date.now(); app.lastSaveError = null; }
    else {
      const first = !app.lastSaveError;
      app.lastSaveError = res.reasonKey;
      if (first) toast(t('err.save_write_failed'), 'bad');
    }
    return res;
  }
  app.saveSettings = function (patch) {
    Object.assign(app.settings, patch);
    State.saveSettings(app.storage, app.settings);
    applySettings();
    rerender();
  };
  function applySettings() {
    const de = document.documentElement;
    de.style.setProperty('--text-scale', String(app.settings.textScale || 1));
    de.classList.toggle('reduce-motion', !!app.settings.reduceMotion);
  }

  // ----------------------------------------------------------- transactions
  // Run a named action. Failures are explained, never silent.
  app.act = async function (name, ...args) {
    const fn = Actions[name];
    if (!fn || !app.state) return null;
    let r = fn(app.state, ...args);
    if (!r.ok && r.reasonKey === 'warn.confirm_unreachable' && name === 'depart') {
      const ok = await app.confirm(t('confirm.unreachable_title'), t('warn.confirm_unreachable', r.reasonParams));
      if (!ok) return r;
      const o = Object.assign({}, args[1] || {}, { confirmed: true });
      r = fn(app.state, args[0], o);
    }
    if (!r.ok) {
      toast(I.reason(r), 'bad');
      if (r.error && root.console) root.console.error(r.error);
      rerender();
      return r;
    }
    if (r.duplicate) { rerender(); return r; }
    app.state = r.state;
    persist(r.saveReason, !!r.saveReason);
    afterCommit();
    return r;
  };
  function afterCommit() {
    rerender();
    if (app.state.encounter && !app.battle) app.openBattle();
    else if (app.state.voyage && app.state.voyage.event && !app.battle) seaEventDialog();
  }
  app.afterBattle = function () {
    rerender();
    if (app.state.voyage && app.state.voyage.event) seaEventDialog();
    else if (app.state.encounter) app.openBattle();
  };
  app.openBattle = function () {
    if (!app.state.encounter || app.battle) return;
    Battle.open(app);
  };
  app.depart = function (toId, fast) { return app.act('depart', toId, { fast: !!fast }); };
  app.emergencyReturn = async function () {
    const s = app.state;
    const ok = await app.confirm(t('confirm.return_title'), t('confirm.return_body', { location: 'loc.' + s.world.lastSafePortId + '.name', gold: s.inventory.ledger.gold, materials: s.inventory.ledger.materials }));
    if (ok) return app.act('emergencyReturn');
    return null;
  };
  app.go = function (view) {
    if (!NAV.find(n => n.id === view)) return;
    app.ui.view = view;
    rerender(true);
    const main = document.getElementById('main');
    if (main) { main.scrollTop = 0; main.focus({ preventScroll: true }); }
  };

  // ------------------------------------------------------------ sea events
  function seaEventDialog() {
    const ev = app.state.voyage && app.state.voyage.event;
    if (!ev || document.querySelector('.modal.sea-event')) return;
    const reg = World.region(ev.regionId);
    const tier = reg.tier;
    const choices = [];
    if (ev.kind === 'vessel') {
      choices.push({ id: 'help', label: t('sea.vessel.help'), cost: { food: 2 } });
      choices.push({ id: 'ignore', label: t('sea.vessel.ignore') });
    } else if (ev.kind === 'inspection') {
      choices.push({ id: 'pay', label: t('sea.inspection.pay'), cost: { gold: 10 + 5 * tier } });
      choices.push({ id: 'refuse', label: t('sea.inspection.refuse') });
    } else choices.push({ id: 'continue', label: t('sea.continue') });
    const body = h('div',
      h('p', { text: t('sea.' + ev.kind + '.desc', { region: 'region.' + reg.id + '.name' }) }),
      h('p.small', { text: t('sea.' + ev.kind + '.effect', { n: 10 + 5 * tier }) }));
    modal(t('sea.' + ev.kind + '.title'), body, choices.map(c => ({
      label: c.label, kind: c === choices[0] ? 'primary' : null, cost: c.cost,
      reason: c.cost && !UI.canAfford(app.state, c.cost) ? t('ship.cannot_afford') : null,
      value: c.id
    })), 'sea-event', true).then(choice => { if (choice) app.act('resolveSeaEvent', choice); });
  }

  // ----------------------------------------------------------------- modals
  function modal(title, body, buttons, cls, noDismiss) {
    return new Promise(resolve => {
      const layer = document.getElementById('modals');
      const prev = document.activeElement;
      const done = v => { layer.removeChild(wrap); document.removeEventListener('keydown', onKey, true); if (prev && prev.focus) try { prev.focus(); } catch (e) { /* gone */ } resolve(v); };
      const btns = buttons.map(b => btn(b.label, () => done(b.value), { kind: b.kind, cost: b.cost, state: app.state, reason: b.reason }));
      const box = h('div.modal-box', { role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'modal-title' },
        h('h3#modal-title', { text: title }), typeof body === 'string' ? h('p', { text: body }) : body, h('div.modal-actions', btns));
      const wrap = h('div.modal' + (cls ? '.' + cls : ''), box);
      function onKey(e) {
        if (e.key === 'Escape' && !noDismiss) { e.preventDefault(); e.stopPropagation(); done(null); }
        else if (e.key === 'Tab') {
          const f = [...box.querySelectorAll('button:not([disabled]), input, select')];
          if (!f.length) return;
          const i = f.indexOf(document.activeElement);
          if (e.shiftKey && i <= 0) { e.preventDefault(); f[f.length - 1].focus(); } else if (!e.shiftKey && i === f.length - 1) { e.preventDefault(); f[0].focus(); }
        }
        e.stopPropagation();
      }
      document.addEventListener('keydown', onKey, true);
      if (!noDismiss) wrap.addEventListener('click', e => { if (e.target === wrap) done(null); });
      layer.appendChild(wrap);
      const first = btns.find(b => !b.disabled);
      setTimeout(() => (first || box).focus && (first || box).focus(), 20);
    });
  }
  app.confirm = function (title, body) {
    return modal(title, body, [{ label: t('ui.confirm'), kind: 'primary', value: true }, { label: t('ui.cancel'), value: false }]).then(v => !!v);
  };
  function toast(text, kind) {
    const layer = document.getElementById('toasts');
    if (!layer) return;
    const el = h('div.toast' + (kind ? '.' + kind : ''), { role: kind === 'bad' ? 'alert' : 'status' }, icon(kind === 'bad' ? 'warn' : 'ok'), h('span', { text }));
    layer.appendChild(el);
    while (layer.childNodes.length > 4) layer.removeChild(layer.firstChild);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 400); }, kind === 'bad' ? 4200 : 2600);
  }
  app.toast = toast;

  // -------------------------------------------------------------- save ops
  function enterGame(state, reasonKey, rotate) {
    app.state = state;
    app.screen = 'game';
    if (!NAV.find(n => n.id === app.ui.view)) app.ui.view = 'home';
    persist(reasonKey, rotate);
    renderShell();
    if (state.encounter) app.openBattle();
    else if (state.voyage && state.voyage.event) seaEventDialog();
  }
  app.saveToSlot = function (n) {
    const r = app.store.saveSlot(n, app.state, Date.now());
    if (r.ok) toast(t('system.saved_slot', { n }), 'good'); else toast(t('err.save_write_failed'), 'bad');
    rerender();
  };
  function loadResult(r) {
    if (!r.ok) { toast(t(r.reasonKey || 'err.save_corrupt'), 'bad'); rerender(); return false; }
    closeBattle();
    enterGame(r.state, 'save.reason_loaded', true);
    toast(t('system.loaded'), 'good');
    return true;
  }
  app.loadFromSlot = n => loadResult(app.store.loadSlot(n));
  app.loadFromRecovery = i => loadResult(app.store.loadRecovery(i));
  app.importSave = text => loadResult(State.unpack(text));
  app.exportSave = function () {
    const wrapper = State.pack(app.state, { kind: 'export', savedAtMs: Date.now(), reasonKey: 'save.reason_manual' });
    const blob = new Blob([JSON.stringify(wrapper)], { type: 'application/json' });
    const a = h('a', { href: URL.createObjectURL(blob), download: 'seven-seas-' + app.state.envelope.profileId + '-' + app.state.envelope.lastTxId + '.json' });
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    toast(t('system.exported'), 'good');
  };
  app.newGame = function () {
    closeBattle();
    const seed = ((Date.now() >>> 0) ^ Math.floor(Math.random() * 0x7fffffff)) >>> 0;
    app.store.wipeRecovery();
    app.ui = { view: 'home' };
    enterGame(State.createNewGame(seed), 'save.reason_new_game', true);
    toast(t('system.new_started'), 'good');
  };
  app.switchLocale = function (code) {
    if (app.state && app.screen === 'game') persist('save.reason_auto', false);
    app.settings.locale = code;
    State.saveSettings(app.storage, app.settings);
    root.location.reload();
  };
  app.toTitle = function () { closeBattle(); app.screen = 'title'; renderTitle(); };
  function closeBattle() { if (app.battle) { app.battle.done = true; cancelAnimationFrame(app.battle.raf); app.battle = null; const o = document.getElementById('battle'); o.hidden = true; clear(o); document.body.classList.remove('in-battle'); } }

  // ------------------------------------------------------------- rendering
  function rerender(viewChanged) {
    if (app.screen !== 'game' || !app.state) return;
    const main = document.getElementById('main');
    const scroll = main ? main.scrollTop : 0;
    // Remember the focused control by position so keyboard users keep their place.
    let focusIdx = -1;
    if (main && main.contains(document.activeElement)) focusIdx = [...main.querySelectorAll('button, select, input, summary')].indexOf(document.activeElement);
    // Keep <details> open states across rerenders.
    const openDetails = main ? [...main.querySelectorAll('details')].map(d => d.open) : [];
    renderStatus();
    renderNav();
    renderAside();
    const view = (Views[app.ui.view] || Views.home)(app);
    clear(main).appendChild(view);
    if (!viewChanged) {
      main.scrollTop = scroll;
      [...main.querySelectorAll('details')].forEach((d, i) => { if (openDetails[i] != null) d.open = openDetails[i]; });
      if (focusIdx >= 0) { const f = main.querySelectorAll('button, select, input, summary')[focusIdx]; if (f) f.focus({ preventScroll: true }); }
    }
  }
  app.rerender = () => rerender(false);

  function renderStatus() {
    const s = app.state;
    const el = clear(document.getElementById('status'));
    const inv = s.inventory;
    const foodCap = Rules.foodCapacity(s), supCap = Rules.supplyCapacity(s);
    const item = (ic, label, value, cls, title) => h('div.st-item' + (cls ? '.' + cls : ''), { title: title || label }, icon(ic), h('span.st-label', { text: label }), h('b', { text: value }));
    const day = Math.floor(s.envelope.gameClock / 24) + 1;
    el.appendChild(h('div.st-brand', UI.sprite(Art.titleShipURL(), 'brand-ship'), h('span', { text: t('app.short') })));
    el.appendChild(item('gold', t('status.gold'), I.fmtNum(inv.gold)));
    if (inv.ledger.gold || inv.ledger.materials) el.appendChild(item('save', t('status.ledger'), '+' + I.fmtNum(inv.ledger.gold) + ' / +' + I.fmtNum(inv.ledger.materials), 'ledger', t('status.ledger_hint')));
    el.appendChild(item('food', t('status.food'), I.fmtNum(inv.food) + '/' + I.fmtNum(foodCap), inv.food < 3 ? 'low' : null));
    el.appendChild(item('supplies', t('status.supplies'), I.fmtNum(inv.supplies) + '/' + I.fmtNum(supCap)));
    el.appendChild(item('materials', t('status.materials'), I.fmtNum(inv.materials)));
    el.appendChild(h('div.st-item.st-stamina', { title: t('status.stamina') }, icon('stamina'), h('span.st-label', { text: t('status.stamina') }),
      bar(s.ship.stamina, s.ship.staminaMax, 'stamina.mini', I.fmtNum(s.ship.stamina) + '/' + I.fmtNum(s.ship.staminaMax))));
    el.appendChild(item('clock', t('status.time'), t('ui.day', { n: day }) + ' ' + UI.clockText(s.envelope.gameClock)));
    el.appendChild(item(Rules.atPort(s) ? 'port' : 'ship', t('status.location'), t('loc.' + s.world.currentLocationId + '.name'), s.voyage ? 'at-sea' : null));
    el.appendChild(h('div.st-save' + (app.lastSaveError ? '.bad' : ''), { title: app.lastSaveError ? t('err.save_write_failed') : t('status.saved') }, icon('save'), h('span', { text: app.lastSaveError ? t('status.save_failed') : t('status.saved') })));
  }
  function renderNav() {
    const s = app.state;
    const el = clear(document.getElementById('nav'));
    const needs = Rules.emergencyNeeds(s).length;
    const lay = Rules.layoutOf(s);
    const badges = {
      ship: lay.missingRequired.length + lay.disabled.length || null,
      port: needs || null,
      crew: s.crew.filter(m => m.injured).length || null,
      pets: s.inventory.eggs.length || null
    };
    NAV.forEach((n, i) => {
      el.appendChild(h('button.nav-btn' + (app.ui.view === n.id ? '.on' : ''), {
        type: 'button', 'aria-current': app.ui.view === n.id ? 'page' : null, title: t('nav.' + n.id) + ' [' + (i + 1) + ']',
        on: { click: () => app.go(n.id) }
      }, icon(n.icon), h('span', { text: t('nav.' + n.id) }), badges[n.id] ? h('span.badge', { text: String(badges[n.id]) }) : null));
    });
  }
  function renderAside() {
    const el = clear(document.getElementById('aside'));
    el.appendChild(h('section.aside-sec', h('h3', { text: t('home.objective') }), Views.objective(app, true)));
    el.appendChild(h('section.aside-sec', h('h3', { text: t('home.log') }), Views.logList(app, 12)));
  }

  function renderShell() {
    document.body.className = 'game';
    const appEl = clear(document.getElementById('app'));
    appEl.appendChild(h('header#status.statusbar', { role: 'banner' }));
    appEl.appendChild(h('nav#nav.nav', { 'aria-label': t('nav.label') }));
    appEl.appendChild(h('div.body', h('main#main.main', { tabindex: '-1' }), h('aside#aside.aside', { 'aria-label': t('home.log') })));
    rerender(true);
  }

  // ------------------------------------------------------- language & title
  function renderLanguagePicker(onPick) {
    document.body.className = 'picker';
    const appEl = clear(document.getElementById('app'));
    const reg = I.registry();
    const box = h('div.lang-picker', UI.sprite(Art.titleShipURL(), 'title-ship'),
      h('div.lang-prompts', I.SUPPORTED.map(c => h('p', { lang: reg[c].meta.htmlLang, text: reg[c].strings['lang.choose'] }))),
      h('div.lang-options', I.SUPPORTED.map(c => h('button.btn.primary.lang-btn', { type: 'button', lang: reg[c].meta.htmlLang, on: { click: () => onPick(c) } },
        h('b', { text: reg[c].meta.nativeName }), h('small', { text: reg[c].strings['lang.note'] })))));
    appEl.appendChild(box);
    setTimeout(() => { const b = box.querySelector('button'); if (b) b.focus(); }, 20);
  }
  function renderTitle() {
    document.body.className = 'title';
    const appEl = clear(document.getElementById('app'));
    const latest = app.store.loadLatest();
    const slots = app.store.listSlots().filter(s => s.ok);
    const loadList = h('div.title-loads', { hidden: true },
      slots.length ? h('ul.list', slots.map(sl => h('li.slot-row', h('div', h('b', { text: t('system.slot_n', { n: sl.slot }) }), h('small', { text: Views.metaLine(sl.meta) })),
        btn(t('system.load'), () => { const r = app.store.loadSlot(sl.slot); if (r.ok) enterGame(r.state, 'save.reason_loaded', true); else toast(t(r.reasonKey), 'bad'); }, { small: true })))) : h('p.small', { text: t('title.no_slots') }),
      h('h4', { text: t('system.recovery') }),
      h('ul.list', app.store.listRecovery().map((r, i) => h('li.slot-row', h('div', h('b', { text: i === 0 ? t('system.recovery_latest') : t('system.recovery_older', { n: i }) }), h('small', { text: t(r.meta.reasonKey || 'save.reason_auto') + ' · ' + Views.metaLine(r.meta) })),
        btn(t('system.load'), () => enterGame(r.state, 'save.reason_loaded', true), { small: true })))));
    const startNew = async () => {
      if (latest.ok && !(await app.confirm(t('system.new_title'), t('system.new_body')))) return;
      app.newGame();
    };
    const box = h('div.title-screen',
      UI.sprite(Art.titleShipURL(), 'title-ship'),
      h('h1', { text: t('app.title') }),
      h('p.tagline', { text: t('app.tagline') }),
      h('div.title-actions',
        latest.ok ? btn(t('title.continue'), () => enterGame(latest.state, 'save.reason_loaded', false), { kind: 'primary', icon: 'helm' }) : null,
        latest.ok ? h('small.title-meta', { text: Views.metaLine(latest.meta) }) : null,
        btn(t('title.new_game'), startNew, { kind: latest.ok ? null : 'primary', icon: 'flag' }),
        btn(t('title.load'), () => { loadList.hidden = !loadList.hidden; }, { icon: 'save' }),
        btn(t('title.language', { lang: I.meta().nativeName }), () => renderLanguagePicker(code => { if (code === I.locale()) renderTitle(); else app.switchLocale(code); }), { icon: 'system' })),
      loadList,
      app.storageKind !== 'local' ? h('p.note.warn', { text: t('system.storage_memory_hint') }) : null,
      h('p.small.title-foot', { text: t('title.footer') }));
    appEl.appendChild(box);
    setTimeout(() => { const b = box.querySelector('.btn.primary'); if (b) b.focus(); }, 20);
  }

  // ---------------------------------------------------------------- keys
  function onKey(e) {
    if (app.battle && app.battle.keys) { if (!document.querySelector('.modal')) app.battle.keys(e); return; }
    if (app.screen !== 'game' || document.querySelector('.modal')) return;
    const tag = (e.target && e.target.tagName) || '';
    if (/INPUT|SELECT|TEXTAREA/.test(tag) || e.ctrlKey || e.metaKey || e.altKey) return;
    // Ship editor: R rotates the piece being placed, Esc drops back to select.
    if (app.ui.view === 'ship') {
      const mode = app.ui.shipMode || 'select';
      if ((e.key === 'r' || e.key === 'R') && /^(build|move):/.test(mode)) { e.preventDefault(); app.ui.shipRot = app.ui.shipRot ? 0 : 1; app.rerender(); return; }
      if (e.key === 'Escape' && mode !== 'select') { e.preventDefault(); app.ui.shipMode = 'select'; app.rerender(); return; }
    }
    const n = Number(e.key);
    if (n >= 1 && n <= NAV.length) { e.preventDefault(); app.go(NAV[n - 1].id); }
  }

  // ---------------------------------------------------------------- boot
  function boot() {
    const st = probeStorage();
    app.storage = st.storage;
    app.storageKind = st.kind;
    app.store = State.createSaveStore(app.storage);
    app.settings = State.loadSettings(app.storage);
    applySettings();
    document.addEventListener('keydown', onKey);
    const start = code => {
      I.setLocale(code);
      document.documentElement.lang = I.meta().htmlLang;
      document.title = t('app.title');
      app.screen = 'title';
      renderTitle();
    };
    if (!app.settings.locale || !I.SUPPORTED.includes(app.settings.locale)) {
      renderLanguagePicker(code => { app.settings.locale = code; State.saveSettings(app.storage, app.settings); start(code); });
    } else start(app.settings.locale);
  }

  app.boot = boot;
  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
