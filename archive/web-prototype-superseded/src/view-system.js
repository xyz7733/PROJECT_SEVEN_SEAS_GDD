/*
 * Project Seven Seas — System view: manual save slots, the three rotating
 * recovery saves, save export/import, settings, language restart, new game.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, State, I18n: I, UI } = P;
  const { h, btn, panel, kv, tag, note, empty, select } = UI;
  const t = I.t;
  const T = Content.TUNING;

  function metaLine(meta) {
    if (!meta) return '';
    const day = Math.floor((meta.gameClock || 0) / 24) + 1;
    return [t(meta.titleKey || 'title.unknown_captain'), t('loc.' + meta.locationId + '.name'), t('ui.day', { n: day }), t('system.crew_n', { n: meta.crewCount }), t('system.trials_n', { n: meta.trials || 0 })].join(' · ');
  }
  function when(ms) {
    if (!ms) return '';
    try { return new Date(ms).toLocaleString(I.meta().htmlLang); } catch (e) { return ''; }
  }

  function system(app) {
    const s = app.state;
    const store = app.store;
    const view = h('div.view.view-system');
    view.appendChild(h('div.view-head', h('h2', { text: t('system.title') }),
      tag(app.storageKind === 'local' ? t('system.storage_local') : t('system.storage_memory'), app.storageKind === 'local' ? 'good' : 'bad'),
      app.lastSaveError ? tag(t('system.last_save_failed'), 'bad') : app.lastSaveOk ? tag(t('system.last_saved', { time: when(app.lastSaveOk) }), 'good') : null));
    if (app.storageKind !== 'local') view.appendChild(note(t('system.storage_memory_hint'), 'warn'));
    if (app.lastSaveError) view.appendChild(note(t('err.save_write_failed'), 'warn'));

    // ------------------------------------------------------- manual slots
    const busy = !!s.encounter;
    const slots = store.listSlots().map(sl => h('li.slot-row',
      h('div', h('b', { text: t('system.slot_n', { n: sl.slot }) }),
        sl.ok ? h('small', { text: metaLine(sl.meta) }) : h('small', { text: sl.corrupt ? t('system.slot_corrupt') : t('system.slot_empty') }),
        sl.ok && sl.meta.savedAtMs ? h('small.muted', { text: when(sl.meta.savedAtMs) }) : null),
      h('div.row',
        btn(t('system.save_here'), async () => {
          if ((sl.ok || sl.corrupt) && !(await app.confirm(t('system.overwrite_title'), t('system.overwrite_body', { n: sl.slot })))) return;
          app.saveToSlot(sl.slot);
        }, { small: true, kind: 'primary', icon: 'save', reason: busy ? t('err.in_encounter') : null }),
        btn(t('system.load'), async () => {
          if (!(await app.confirm(t('system.load_title'), t('system.load_body')))) return;
          app.loadFromSlot(sl.slot);
        }, { small: true, reason: sl.ok ? null : t('system.slot_empty') }),
        btn(t('system.delete'), async () => {
          if (!(await app.confirm(t('system.delete_title'), t('system.delete_body', { n: sl.slot })))) return;
          store.deleteSlot(sl.slot); app.rerender();
        }, { small: true, kind: 'danger', reason: sl.ok || sl.corrupt ? null : t('system.slot_empty') }))));
    const manual = panel(t('system.manual'), note(t('system.manual_hint')), h('ul.list', slots));

    // ---------------------------------------------------- recovery saves
    const rec = store.listRecovery();
    const recovery = panel(t('system.recovery'), note(t('system.recovery_hint', { n: T.recoverySaveCount })),
      rec.length ? h('ul.list', rec.map((r, i) => h('li.slot-row',
        h('div', h('b', { text: i === 0 ? t('system.recovery_latest') : t('system.recovery_older', { n: i }) }),
          h('small', { text: t(r.meta.reasonKey || 'save.reason_auto') + ' · ' + metaLine(r.meta) }),
          r.meta.savedAtMs ? h('small.muted', { text: when(r.meta.savedAtMs) }) : null),
        btn(t('system.load'), async () => {
          if (!(await app.confirm(t('system.load_title'), t('system.load_recovery_body')))) return;
          app.loadFromRecovery(r.index);
        }, { small: true })))) : empty(t('system.no_recovery')));

    // ------------------------------------------------------ export/import
    const fileInput = h('input', { type: 'file', accept: '.json,application/json', 'aria-label': t('system.import'), style: { display: 'none' } });
    fileInput.addEventListener('change', () => {
      const f = fileInput.files && fileInput.files[0];
      if (!f) return;
      const reader = new FileReader();
      reader.onload = async () => {
        if (!(await app.confirm(t('system.import_title'), t('system.import_body')))) return;
        app.importSave(String(reader.result || ''));
      };
      reader.readAsText(f);
    });
    const transfer = panel(t('system.transfer'), note(t('system.transfer_hint')),
      h('div.row.wrap', btn(t('system.export'), () => app.exportSave(), { small: true, icon: 'save', reason: busy ? t('err.in_encounter') : null }),
        btn(t('system.import'), () => fileInput.click(), { small: true }), fileInput));

    // ------------------------------------------------------------ settings
    const st = app.settings;
    const settings = panel(t('system.settings'),
      h('div.settings',
        h('label.setting', h('span', { text: t('system.text_scale') }),
          select([0.9, 1, 1.15, 1.3].map(v => ({ value: String(v), label: Math.round(v * 100) + '%' })), String(st.textScale), v => app.saveSettings({ textScale: Number(v) }), { label: t('system.text_scale') })),
        h('label.setting', h('span', { text: t('system.battle_speed') }),
          select([1, 2, 4].map(v => ({ value: String(v), label: '×' + v })), String(st.battleSpeed), v => app.saveSettings({ battleSpeed: Number(v) }), { label: t('system.battle_speed') })),
        toggle(t('system.reduce_motion'), st.reduceMotion, v => app.saveSettings({ reduceMotion: v })),
        toggle(t('system.pause_start'), st.pauseAtEncounterStart, v => app.saveSettings({ pauseAtEncounterStart: v }))));

    // ------------------------------------------------------------ language
    if (!app.ui.pendingLocale) app.ui.pendingLocale = I.locale();
    const lang = panel(t('system.language'), note(t('system.language_hint')),
      h('div.row.wrap',
        select(I.SUPPORTED.map(c => ({ value: c, label: I.meta(c).nativeName })), app.ui.pendingLocale, v => { app.ui.pendingLocale = v; app.rerender(); }, { label: t('system.language') }),
        btn(t('system.restart_language'), async () => {
          const code = app.ui.pendingLocale;
          if (!(await app.confirm(t('system.restart_title'), t('system.restart_body', { lang: I.meta(code).nativeName })))) return;
          app.switchLocale(code);
        }, { small: true, kind: 'primary', reason: app.ui.pendingLocale === I.locale() ? t('system.language_current') : busy ? t('err.in_encounter') : null })));

    // ------------------------------------------------------------ captain
    const cap = panel(t('system.captain'),
      h('div.kvs',
        kv(t('system.profile'), s.envelope.profileId),
        kv(t('system.seed'), String(s.envelope.seed)),
        kv(t('system.transactions'), I.fmtNum(s.envelope.lastTxId)),
        kv(t('system.battles'), t('system.battles_value', { w: s.captain.stats.battlesWon, l: s.captain.stats.battlesLost, r: s.captain.stats.retreats })),
        kv(t('system.voyages'), I.fmtNum(s.captain.stats.voyages)),
        kv(t('system.postgame'), s.captain.postgame ? t('ui.yes') : t('ui.no'))),
      h('div.row.wrap',
        btn(t('system.title_screen'), () => app.toTitle(), { small: true, icon: 'home', reason: busy ? t('err.in_encounter') : null }),
        btn(t('system.new_game'), async () => {
          if (!(await app.confirm(t('system.new_title'), t('system.new_body')))) return;
          app.newGame();
        }, { small: true, kind: 'danger', reason: busy ? t('err.in_encounter') : null })),
      h('div.shortcuts', h('h4', { text: t('system.shortcuts') }), h('p.small', { text: t('system.shortcuts_list') })));

    view.appendChild(h('div.grid2', manual, recovery, settings, lang, transfer, cap));
    return view;
  }

  function toggle(label, value, onChange) {
    const input = h('input', { type: 'checkbox' });
    input.checked = !!value;
    input.addEventListener('change', () => onChange(input.checked));
    return h('label.setting.toggle', input, h('span', { text: label }));
  }

  P.Views.system = system;
  P.Views.metaLine = metaLine;
  P.Views.when = when;
})(typeof globalThis !== 'undefined' ? globalThis : this);
