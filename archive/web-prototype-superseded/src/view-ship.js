/*
 * Project Seven Seas — Ship view: free multi-deck layout editor with doors,
 * stairs, reachability, presets, dismantle/repair, hull upgrades, jobs.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, Rules, Actions, I18n: I, UI, Art } = P;
  const { h, btn, panel, kv, tag, note, icon, costView, tabs, select, empty } = UI;
  const t = I.t;
  const Views = P.Views;

  function facName(id) { return t('fac.' + id + '.name'); }

  function ship(app) {
    const s = app.state;
    const ui = app.ui;
    const atPort = Rules.atPort(s);
    const portReason = atPort ? null : t('err.need_port');
    const lay = Rules.layoutOf(s);
    if (ui.shipDeck == null || ui.shipDeck >= s.ship.decks.length) ui.shipDeck = 0;
    if (!ui.shipMode) ui.shipMode = 'select';
    const deckIndex = ui.shipDeck;
    const deck = s.ship.decks[deckIndex];
    const hull = Content.hull(s.ship.hullId);

    const view = h('div.view.view-ship');
    view.appendChild(h('div.view-head',
      h('h2', { text: t('hull.' + hull.id + '.name') }),
      tag(t('ship.tier', { n: hull.tier })),
      h('span.small', { text: t('ship.decks', { n: s.ship.decks.length }) }),
      atPort ? tag(t('ship.edit_ok'), 'good') : tag(t('ship.edit_port_only'), 'warn')));

    // ---------------------------------------------------------- deck grid
    const left = h('div.ship-left');
    left.appendChild(tabs(s.ship.decks.map((d, i) => {
      const n = s.ship.facilities.filter(f => !f.stowed && f.deck === i).length;
      return { id: String(i), label: t('ship.deck_n', { n: i + 1 }), badge: n };
    }), String(deckIndex), id => { ui.shipDeck = +id; ui.shipSel = null; app.rerender(); }));

    const modeBar = h('div.toolbar',
      btn(t('ship.mode_select'), () => { ui.shipMode = 'select'; app.rerender(); }, { small: true, pressed: ui.shipMode === 'select' }),
      btn(t('ship.mode_stair'), () => { ui.shipMode = 'stair'; app.rerender(); }, { small: true, pressed: ui.shipMode === 'stair', reason: portReason || (deckIndex + 1 >= s.ship.decks.length ? t('err.no_lower_deck') : null), cost: Content.STRUCTURES.stair.cost, state: s }),
      /^(build|move):/.test(ui.shipMode) ? btn(t('ship.rotate'), () => { ui.shipRot = ui.shipRot ? 0 : 1; app.rerender(); }, { small: true, pressed: !!ui.shipRot }) : null,
      /^(build|move|stair)/.test(ui.shipMode) ? btn(t('ui.cancel'), () => { ui.shipMode = 'select'; app.rerender(); }, { small: true }) : null);
    left.appendChild(modeBar);
    if (/^build:/.test(ui.shipMode)) left.appendChild(note(t('ship.build_hint', { facility: facName(ui.shipMode.slice(6)) })));
    if (/^move:/.test(ui.shipMode)) {
      const f = s.ship.facilities.find(x => x.uid === ui.shipMode.slice(5));
      if (f) left.appendChild(note(t('ship.move_hint', { facility: facName(f.id) })));
    }
    if (ui.shipMode === 'stair') left.appendChild(note(t('ship.stair_hint', { a: deckIndex + 1, b: deckIndex + 2 })));

    left.appendChild(deckGrid(app, deckIndex, deck, lay));
    left.appendChild(h('div.legend',
      h('span.lg.lg-walk', { text: t('ship.legend_walk') }), h('span.lg.lg-entry', { text: t('ship.legend_entry') }),
      h('span.lg.lg-door', { text: t('ship.legend_door') }), h('span.lg.lg-stair', { text: t('ship.legend_stair') }),
      h('span.lg.lg-off', { text: t('ship.legend_disabled') })));

    // Layout analysis.
    const sum = h('div.kvs',
      kv(t('ship.capacity'), t('home.crew_cap_value', { n: s.crew.length, max: lay.capacity }), lay.overCapacity ? 'bad' : null),
      kv(t('ship.food_cap'), I.fmtNum(Rules.foodCapacity(s, lay))),
      kv(t('ship.supply_cap'), I.fmtNum(Rules.supplyCapacity(s, lay))),
      kv(t('ship.equip_cap'), I.fmtNum(Rules.equipCapacity(s, lay))),
      kv(t('ship.stamina_max'), I.fmtNum(Rules.staminaMax(s, lay))),
      kv(t('ship.departure'), lay.canDepart ? t('ship.depart_ok') : t('ship.depart_blocked'), lay.canDepart ? 'good' : 'bad'));
    const issues = h('ul.warnings');
    for (const id of lay.missingRequired) issues.appendChild(h('li.bad', icon('warn'), h('span', { text: t('home.missing_required', { facility: facName(id) }) })));
    for (const uid of lay.disabled) {
      const f = s.ship.facilities.find(x => x.uid === uid);
      const info = lay.facilities[uid];
      issues.appendChild(h('li.warn', icon('lock'), h('button.linkish', { type: 'button', text: facName(f.id), on: { click: () => { ui.shipSel = uid; if (!f.stowed) ui.shipDeck = f.deck; app.rerender(); } } }), h('span', { text: ' — ' + t(info.reasonKey, info.reasonParams) })));
    }
    left.appendChild(panel(t('ship.layout'), sum, issues.childNodes.length ? issues : h('p.good-note', icon('ok'), h('span', { text: t('home.ship_ready') }))));

    // --------------------------------------------------------- side panel
    const right = h('div.ship-right');
    right.appendChild(selectionPanel(app, lay, portReason));
    right.appendChild(buildPalette(app, portReason));
    const stowed = s.ship.facilities.filter(f => f.stowed);
    if (stowed.length) {
      right.appendChild(panel(t('ship.stowed'), h('ul.list', stowed.map(f => h('li',
        h('span', { text: facName(f.id) + ' · ' + t('ui.lv', { n: f.level }) }),
        btn(t('ship.place'), () => { ui.shipMode = 'move:' + f.uid; ui.shipSel = f.uid; app.rerender(); }, { small: true, reason: portReason }))))));
    }
    right.appendChild(presetPanel(app, portReason));
    right.appendChild(hullPanel(app));
    right.appendChild(servicePanel(app));

    view.appendChild(h('div.ship-layout', left, right));
    return view;
  }

  // Grid of cells with facilities placed on top using explicit grid areas.
  function deckGrid(app, d, deck, lay) {
    const s = app.state;
    const ui = app.ui;
    const grid = h('div.deck-grid', { style: { '--cols': deck.w, '--rows': deck.h }, role: 'grid', 'aria-label': t('ship.deck_n', { n: d + 1 }) });
    const occ = Rules.occupancy(s.ship);
    let preview = null;
    const mode = ui.shipMode;
    const placing = /^(build|move):/.test(mode);
    const placeId = mode.startsWith('build:') ? mode.slice(6) : null;
    const moving = mode.startsWith('move:') ? s.ship.facilities.find(f => f.uid === mode.slice(5)) : null;

    function showPreview(x, y) {
      if (!placing) return;
      const id = placeId || (moving && moving.id);
      if (!id) return;
      const fp = Rules.footprint({ id, rot: ui.shipRot ? 1 : 0 });
      const ok = Rules.canPlace(s.ship, id, d, x, y, ui.shipRot ? 1 : 0, moving ? moving.uid : null);
      if (!preview) { preview = h('div.preview'); grid.appendChild(preview); }
      preview.className = 'preview ' + (ok.ok ? 'ok' : 'bad');
      preview.style.gridColumn = (x + 1) + ' / span ' + fp.w;
      preview.style.gridRow = (y + 1) + ' / span ' + fp.h;
      preview.title = ok.ok ? '' : t(ok.reasonKey, ok.reasonParams);
    }

    for (let y = 0; y < deck.h; y++) {
      for (let x = 0; x < deck.w; x++) {
        const fixed = Rules.fixedKind(deck, x, y);
        const door = Rules.isDoor(deck, x, y);
        const stair = Rules.stairAt(s.ship, d, x, y);
        const entry = deck.entry && deck.entry[0] === x && deck.entry[1] === y;
        const reached = lay.reached.has(d + ':' + x + ':' + y);
        const cls = ['cell'];
        if (fixed) cls.push('fx-' + fixed);
        if (door) cls.push('door');
        if (entry) cls.push('entry');
        if (stair) cls.push(stair.deck === d ? 'stair-down' : 'stair-up');
        if (reached && !occ[d + ':' + x + ':' + y]) cls.push('walk');
        let label = t('ship.cell', { x: x + 1, y: y + 1 });
        if (fixed) label += ' · ' + t('ship.fixed_' + fixed);
        if (door) label += ' · ' + t('ship.legend_door');
        if (entry) label += ' · ' + t('ship.legend_entry');
        if (stair) label += ' · ' + t(stair.deck === d ? 'ship.stair_down' : 'ship.stair_up');
        const cell = h('button.' + cls.join('.'), {
          type: 'button', title: label, 'aria-label': label, style: { gridColumn: x + 1, gridRow: y + 1 },
          on: {
            click: () => onCell(app, d, x, y),
            mouseenter: () => showPreview(x, y),
            focus: () => showPreview(x, y)
          }
        });
        grid.appendChild(cell);
      }
    }
    for (const f of s.ship.facilities) {
      if (f.stowed || f.deck !== d) continue;
      const fp = Rules.footprint(f);
      const info = lay.facilities[f.uid];
      const def = Content.FACILITIES[f.id];
      const cls = ['fac', 'cat-' + def.category];
      if (!info.reachable) cls.push('off');
      if (f.damaged) cls.push('damaged');
      if (ui.shipSel === f.uid) cls.push('sel');
      if (moving && moving.uid === f.uid) cls.push('moving');
      const el = h('button.' + cls.join('.'), {
        type: 'button', style: { gridColumn: (f.x + 1) + ' / span ' + fp.w, gridRow: (f.y + 1) + ' / span ' + fp.h, '--cat': Art.CATEGORY_COLORS[def.category] },
        title: facName(f.id) + (info.reachable ? '' : ' — ' + t(info.reasonKey, info.reasonParams)),
        on: { click: () => { if (placing) return; ui.shipSel = f.uid; ui.shipMode = 'select'; app.rerender(); } }
      },
      h('span.fac-name', { text: facName(f.id) }),
      h('span.fac-lv', { text: t('ui.lv', { n: f.level }) }),
      !info.reachable ? icon('lock', 'fac-flag') : f.damaged ? icon('warn', 'fac-flag') : null);
      if (placing) el.style.pointerEvents = 'none';
      grid.appendChild(el);
    }
    grid.addEventListener('mouseleave', () => { if (preview) { preview.remove(); preview = null; } });
    return h('div.deck-wrap', grid);
  }

  function onCell(app, d, x, y) {
    const s = app.state;
    const ui = app.ui;
    const mode = ui.shipMode;
    const deck = s.ship.decks[d];
    if (mode.startsWith('build:')) {
      const r = app.act('buildFacility', mode.slice(6), d, x, y, ui.shipRot ? 1 : 0);
      if (r && r.ok) { ui.shipSel = r.value; ui.shipMode = 'select'; app.rerender(); }
      return;
    }
    if (mode.startsWith('move:')) {
      const uid = mode.slice(5);
      const r = app.act('moveFacility', uid, d, x, y, ui.shipRot ? 1 : 0);
      if (r && r.ok) { ui.shipMode = 'select'; ui.shipSel = uid; app.rerender(); }
      return;
    }
    if (mode === 'stair') {
      const r = app.act('placeStair', d, x, y);
      if (r && r.ok) { ui.shipMode = 'select'; app.rerender(); }
      return;
    }
    const stairIdx = s.ship.stairs.findIndex(st => (st.deck === d || st.deck + 1 === d) && st.x === x && st.y === y);
    if (stairIdx >= 0) { ui.shipSel = 'stair:' + stairIdx; app.rerender(); return; }
    if (deck.bulkhead === x && y > 0 && y < deck.h - 1) { ui.shipSel = 'door:' + d + ':' + y; app.rerender(); return; }
    ui.shipSel = null;
    app.rerender();
  }

  function selectionPanel(app, lay, portReason) {
    const s = app.state;
    const ui = app.ui;
    const sel = ui.shipSel;
    if (sel && sel.startsWith('stair:')) {
      const i = +sel.slice(6);
      const st = s.ship.stairs[i];
      if (st) {
        return panel(t('ship.stair'), h('p', { text: t('ship.stair_info', { a: st.deck + 1, b: st.deck + 2, x: st.x + 1, y: st.y + 1 }) }),
          btn(t('ship.remove_stair'), () => { const r = app.act('removeStair', i); if (r && r.ok) { ui.shipSel = null; app.rerender(); } }, { kind: 'danger', small: true, reason: portReason }));
      }
    }
    if (sel && sel.startsWith('door:')) {
      const [, dd, yy] = sel.split(':').map(Number);
      const deck = s.ship.decks[dd];
      const isDoor = Rules.isDoor(deck, deck.bulkhead, yy);
      return panel(t('ship.bulkhead'), h('p', { text: t(isDoor ? 'ship.door_info' : 'ship.bulkhead_info', { deck: dd + 1, y: yy + 1 }) }),
        btn(t(isDoor ? 'ship.remove_door' : 'ship.add_door'), () => app.act('toggleDoor', dd, yy), { small: true, reason: portReason, cost: isDoor ? null : Content.STRUCTURES.door.cost, state: s }));
    }
    const f = sel && s.ship.facilities.find(x => x.uid === sel);
    if (!f) return panel(t('ship.selection'), note(t('ship.select_hint')));
    const def = Content.FACILITIES[f.id];
    const info = lay.facilities[f.uid];
    const workers = s.crew.filter(m => m.jobFacilityUid === f.uid);
    const helpers = s.pets.filter(p => p.assignment && p.assignment.kind === 'helper' && p.assignment.target === f.uid);
    const slots = Rules.jobSlots(f);
    const up = f.level < 3 ? Rules.upgradeCost(f) : null;
    const upReason = portReason || (f.level >= 3 ? t('err.max_level') : f.level + 1 > s.ship.hullTier + 1 ? t('err.hull_tier', { tier: f.level }) : null);
    const ref = Rules.demolishRefund(f);
    const body = [
      h('p.desc', { text: t('fac.' + f.id + '.desc') }),
      h('div.kvs',
        kv(t('ship.category'), t('faccat.' + def.category)),
        kv(t('ship.level'), I.fmtNum(f.level) + ' / 3'),
        kv(t('ship.size'), Rules.footprint(f).w + '×' + Rules.footprint(f).h),
        kv(t('ship.status'), f.stowed ? t('ship.status_stowed') : !info.reachable ? t('ship.status_disabled') : f.damaged ? t('ship.status_damaged') : t('ship.status_active'), (!info.reachable || f.damaged) ? 'bad' : 'good')),
      !info.reachable ? h('div.alert.warn', icon('lock'), h('span', { text: t(info.reasonKey, info.reasonParams) + ' ' + t('ship.disabled_effect') })) : null,
      f.damaged ? h('div.alert.warn', icon('warn'), h('span', { text: t('ship.damaged_effect') })) : null
    ];
    if (slots) {
      const avail = s.crew.filter(m => m.jobFacilityUid !== f.uid);
      body.push(h('div.jobs', h('h4', { text: t('ship.jobs', { n: workers.length, max: slots }) }),
        h('ul.list', workers.map(m => h('li', UI.sprite(Art.portraitURL(m), 'portrait.tiny'), h('span', { text: I.crewName(m) + ' · ' + t('ship.efficiency', { pct: I.pct(Rules.workerEfficiency(s, m, f.id)) }) }),
          btn(t('ship.unassign'), () => app.act('assignJob', m.id, null), { small: true })))),
        workers.length < slots ? select([{ value: null, label: t('ship.assign_worker') }].concat(avail.map(m => ({ value: m.id, label: I.crewName(m) + ' — ' + t('class.' + m.classId + '.name') + ' (' + I.pct(Rules.workerEfficiency(s, m, f.id)) + ')' }))), null, v => { if (v) app.act('assignJob', v, f.uid); }, { label: t('ship.assign_worker'), disabled: !info.reachable }) : null,
        helpers.length ? h('p.small', { text: t('ship.pet_helpers', { names: helpers.map(I.petName).join(', ') }) }) : null,
        h('p.small', { text: t('ship.staff_bonus', { pct: I.pct(Rules.staffMult(s, f.id) - 1) }) })));
    }
    body.push(h('div.row.wrap',
      f.level < 3 ? btn(t('ship.upgrade'), () => app.act('upgradeFacility', f.uid), { small: true, kind: 'primary', cost: up, state: s, reason: upReason }) : tag(t('ship.max_level'), 'good'),
      btn(t('ship.move'), () => { ui.shipMode = 'move:' + f.uid; ui.shipRot = f.rot; app.rerender(); }, { small: true, reason: portReason }),
      !f.stowed ? btn(t('ship.stow'), () => app.act('stowFacility', f.uid), { small: true, reason: portReason, title: t('ship.stow_hint') }) : null,
      btn(t('ship.demolish'), async () => {
        if (await app.confirm(t('ship.demolish_confirm', { facility: facName(f.id) }), t('ship.refund', { gold: ref.gold, materials: ref.materials }))) {
          const r = app.act('demolishFacility', f.uid); if (r && r.ok) { ui.shipSel = null; app.rerender(); }
        }
      }, { small: true, kind: 'danger', reason: portReason || (f.id === 'captains_cabin' ? t('err.cannot_demolish_cabin') : null) })));
    return panel(facName(f.id), body);
  }

  function buildPalette(app, portReason) {
    const s = app.state;
    const ui = app.ui;
    const groups = {};
    for (const [id, def] of Object.entries(Content.FACILITIES)) (groups[def.category] = groups[def.category] || []).push([id, def]);
    const wrap = h('div.palette');
    for (const cat of Content.FACILITY_CATEGORIES) {
      const list = groups[cat];
      if (!list) continue;
      wrap.appendChild(h('h4.pal-cat', { style: { '--cat': Art.CATEGORY_COLORS[cat] } }, h('i.swatch'), h('span', { text: t('faccat.' + cat) })));
      for (const [id, def] of list) {
        const count = s.ship.facilities.filter(f => f.id === id).length;
        const limit = Actions.BUILD_LIMIT[id] || 1;
        const reason = portReason || (s.ship.hullTier < def.minTier ? t('err.hull_tier', { tier: def.minTier }) : count >= limit ? t('err.build_limit') : !UI.canAfford(s, def.cost) ? t('ship.cannot_afford') : null);
        wrap.appendChild(h('div.pal-row' + (ui.shipMode === 'build:' + id ? '.on' : ''),
          h('div.pal-info', h('b', { text: t('fac.' + id + '.name') }), h('small', { text: def.w + '×' + def.h + ' · ' + t('ship.owned', { n: count, max: limit }) + (def.required ? ' · ' + t('ship.required') : '') }),
            h('small.desc', { text: t('fac.' + id + '.desc') })),
          btn(t('ship.build'), () => { ui.shipMode = 'build:' + id; ui.shipRot = 0; app.rerender(); }, { small: true, cost: def.cost, state: s, reason })));
      }
    }
    const details = h('details.panel.palette-panel', { open: /^build:/.test(ui.shipMode) || !!ui.paletteOpen });
    details.addEventListener('toggle', () => { ui.paletteOpen = details.open; });
    details.appendChild(h('summary.panel-h', h('span', { text: t('ship.build_palette') })));
    details.appendChild(wrap);
    return details;
  }

  function presetPanel(app, portReason) {
    const s = app.state;
    const rows = [0, 1, 2].map(i => {
      const pr = s.ship.presets[i];
      return h('li', h('span', { text: t('ship.preset_n', { n: i + 1 }) + (pr ? ' · ' + t('ship.preset_info', { n: pr.facilities.filter(f => !f.stowed).length }) : ' · ' + t('ship.preset_empty')) }),
        h('span.row',
          btn(t('ship.preset_save'), () => app.act('savePreset', i), { small: true }),
          pr ? btn(t('ship.preset_apply'), () => app.act('applyPreset', i), { small: true, reason: portReason }) : null,
          pr ? btn(t('ui.delete'), () => app.act('deletePreset', i), { small: true, kind: 'danger' }) : null));
    });
    return panel(t('ship.presets'), note(t('ship.presets_hint')), h('ul.list', rows));
  }

  function hullPanel(app) {
    const s = app.state;
    const rows = Content.HULLS.map(hl => {
      const owned = hl.tier <= s.ship.hullTier;
      const av = Rules.hullAvailable(s, hl);
      const reason = owned ? null : !av.ok ? t(av.reasonKey, av.reasonParams) : !UI.canAfford(s, hl.cost) ? t('ship.cannot_afford') : null;
      return h('li.hull-row' + (hl.id === s.ship.hullId ? '.current' : ''),
        h('div', h('b', { text: t('hull.' + hl.id + '.name') }), h('small.hull-meta', { text: t('ship.tier', { n: hl.tier }) + ' · ' + t('ship.decks', { n: hl.decks.length }) }),
          h('small.desc', { text: t('hull.' + hl.id + '.desc') })),
        hl.id === s.ship.hullId ? tag(t('ship.current_hull'), 'good') : owned ? tag(t('ship.hull_owned'))
          : btn(t('ship.upgrade_hull'), async () => {
            if (await app.confirm(t('ship.hull_confirm', { hull: t('hull.' + hl.id + '.name') }), t('ship.hull_confirm_body'))) app.act('upgradeHull', hl.id);
          }, { small: true, kind: 'primary', cost: hl.cost, state: s, reason }));
    });
    return panel(t('ship.hulls'), h('ul.list', rows));
  }

  function servicePanel(app) {
    const s = app.state;
    const rc = Rules.repairCost(s);
    const atPort = Rules.atPort(s);
    const repairReason = !rc.needed ? t('err.nothing_to_repair') : (!atPort && !Rules.facLevel(s, 'workshop', { allowDamaged: true })) ? t('err.need_workshop') : null;
    const galley = Rules.facLevel(s, 'galley');
    const workshop = Rules.facLevel(s, 'workshop');
    return panel(t('ship.services'),
      h('div.kvs', kv(t('home.damage'), s.ship.damage + '%', s.ship.damage >= 40 ? 'bad' : null),
        kv(t('ship.damaged_facilities'), I.fmtNum(s.ship.facilities.filter(f => f.damaged).length))),
      s.ship.damage >= 40 ? note(t('ship.damage_penalty'), 'warn') : null,
      h('div.row.wrap',
        btn(t('ship.repair'), () => app.act('repairShip'), { small: true, cost: atPort ? { gold: rc.gold, materials: rc.materials } : { materials: Math.ceil(rc.materials * 1.5) }, state: s, reason: repairReason }),
        btn(t('ship.produce_food', { n: Math.round((2 + galley) * Rules.staffMult(s, 'galley')) }), () => app.act('produceFood'), { small: true, icon: 'food', cost: { materials: 3 }, state: s, reason: galley ? null : t('err.need_facility', { facility: facName('galley') }) }),
        btn(t('ship.produce_supplies'), () => app.act('produceSupplies'), { small: true, icon: 'supplies', cost: { materials: 4 }, state: s, reason: workshop ? null : t('err.need_facility', { facility: facName('workshop') }) })),
      note(t('ship.production_hint')));
  }

  Views.ship = ship;
})(typeof globalThis !== 'undefined' ? globalThis : this);
