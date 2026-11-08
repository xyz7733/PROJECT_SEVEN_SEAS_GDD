/*
 * Project Seven Seas — shared view parts and the Overview (bridge) view.
 * Each view is a function (app) -> DOM node and is re-rendered after every
 * committed transaction, so the screen always reflects the saved state.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, World, Rules, I18n: I, UI, Art } = P;
  const { h, btn, panel, kv, tag, empty, note, bar, icon, sprite, costView } = UI;
  const t = I.t;
  const T = Content.TUNING;

  const Views = P.Views = P.Views || {};

  // ------------------------------------------------------------ shared parts
  function locLabel(id) { return t('loc.' + id + '.name'); }
  function knowledgeTag(state, locId) {
    const k = Rules.knowledge(state, locId);
    return tag(t('know.' + k), 'k-' + k);
  }
  // Current main step and its captain trial, always visible (GDD §10.5).
  function objective(app, compact) {
    const s = app.state;
    const ms = Rules.mainStatus(s);
    if (ms.done) {
      return h('div.objective.done',
        h('div.obj-head', icon('flag'), h('b', { text: t(s.captain.titleKey) })),
        h('p', { text: t('obj.postgame') }),
        h('p.small', { text: t('obj.legends', { n: s.captain.legendsWon.length, total: Object.keys(World.LEGENDS).length }) }));
    }
    const q = ms.quest;
    const reg = World.region(ms.regionId);
    const known = Rules.isKnown(s, q.locationId);
    const trialState = ms.trialWon ? 'won' : ms.step >= 4 ? 'open' : 'locked';
    const el = h('div.objective',
      h('div.obj-head', icon('flag'), h('span.obj-region', { text: t('region.' + reg.id + '.name') }), h('span.obj-step', { text: t('obj.step', { n: ms.step + 1, total: World.MAIN_TEMPLATE.length }) })),
      h('div.obj-arc', { text: t('arc.' + reg.id + '.title') }),
      h('div.obj-title', { text: t(q.titleKey) }),
      compact ? null : h('p.obj-why', { text: t('arc.' + reg.id + '.' + ms.step) }),
      h('div.obj-target', icon(known ? 'map' : 'question'), h('span', { text: known ? t('obj.target', { location: locLabel(q.locationId) }) : t('obj.target_hidden') }),
        q.type === 'deliver' ? h('span.small', { text: ' · ' + t('obj.have', { have: s.inventory.specialties[q.itemId] || 0, need: q.count }) }) : null),
      h('div.obj-trial.t-' + trialState, icon(trialState === 'locked' ? 'lock' : 'flag'),
        h('span', { text: t('obj.trial_' + trialState, { location: locLabel(ms.trialLocationId), rival: t('enemy.' + reg.rivalId + '.name') }) })),
      compact ? null : h('div.row', btn(t('obj.show_on_chart'), () => { app.ui.mapRegion = reg.id; app.ui.mapSel = known ? q.locationId : null; app.go('map'); }, { small: true, icon: 'map' })));
    return el;
  }
  function logList(app, limit) {
    const s = app.state;
    const list = h('ol.log');
    for (const e of s.log.slice(0, limit || 14)) {
      list.appendChild(h('li', h('span.log-time', { text: UI.clockText(e.clock) }), h('span.log-text', { text: I.logLine(e, s) })));
    }
    if (!s.log.length) list.appendChild(h('li.empty', { text: t('log.empty') }));
    return list;
  }
  function crewChip(app, m, opts) {
    const o = opts || {};
    const s = app.state;
    return h('button.crew-chip' + (o.active ? '.active' : '') + (m.injured ? '.injured' : ''), {
      type: 'button', title: I.crewName(m), on: { click: o.onClick || (() => { app.ui.crewSel = m.id; app.go('crew'); }) }
    },
    sprite(Art.portraitURL(m), 'portrait'),
    h('span.cc-text', h('b', { text: I.crewName(m) }), h('small', { text: t('class.' + m.classId + '.name') + ' · ' + t('ui.lv', { n: m.level }) })),
    m.injured ? tag(t('crew.injured'), 'bad') : null,
    o.extra || null,
    s && o.showPower ? h('small.power', { text: t('crew.power', { n: Rules.power(s, m) }) }) : null);
  }
  function whereText(s) {
    const loc = World.location(s.world.currentLocationId);
    if (s.encounter) return t('where.battle', { location: locLabel(loc.id) });
    if (s.voyage && s.voyage.event) return t('where.at_sea', { location: locLabel(s.voyage.route.to) });
    if (s.voyage && s.voyage.site) return t('where.site', { location: locLabel(loc.id) });
    if (Rules.atPort(s)) return t('where.port', { location: locLabel(loc.id) });
    return t('where.location', { location: locLabel(loc.id) });
  }

  // --------------------------------------------------------------- overview
  function home(app) {
    const s = app.state;
    const lay = Rules.layoutOf(s);
    const atPort = Rules.atPort(s);
    const root = h('div.view.view-home');

    const hero = h('div.hero',
      h('div.hero-text',
        h('h2', { text: t(s.captain.titleKey) }),
        h('p.where', icon(atPort ? 'port' : 'ship'), h('span', { text: whereText(s) })),
        h('p.small', { text: t('home.last_safe', { location: locLabel(s.world.lastSafePortId) }) })),
      h('div.hero-actions',
        atPort ? btn(t('home.open_port'), () => app.go('port'), { icon: 'port', kind: 'primary' }) : null,
        s.voyage && s.voyage.site ? btn(t('home.explore_site'), () => app.go('map'), { icon: 'map', kind: 'primary' }) : null,
        btn(t('home.open_chart'), () => app.go('map'), { icon: 'map' }),
        s.voyage && !s.encounter ? btn(t('home.emergency_return'), () => app.emergencyReturn(), { icon: 'home', kind: 'danger', title: t('home.emergency_hint') }) : null,
        s.encounter ? btn(t('home.resume_battle'), () => app.openBattle(), { icon: 'atk', kind: 'primary' }) : null));
    root.appendChild(hero);

    const grid = h('div.grid2');
    grid.appendChild(panel(t('home.objective'), objective(app)));

    // Stamina and food (GDD §11).
    const stam = panel(t('home.stamina'),
      bar(s.ship.stamina, s.ship.staminaMax, 'stamina', t('home.stamina_value', { n: s.ship.stamina, max: s.ship.staminaMax })),
      h('div.row.wrap',
        btn(t('home.serve_ration', { n: T.rationStamina + 3 * Rules.facLevel(s, 'mess_hall') }), () => app.act('serveRation'), { icon: 'food', cost: { food: T.rationFood }, state: s }),
        btn(t('home.use_supply', { n: T.supplyStamina }), () => app.act('useSupply'), { icon: 'supplies', cost: { supplies: 1 }, state: s })),
      note(t('home.stamina_rule')),
      s.inventory.ledger.gold || s.inventory.ledger.materials
        ? h('div.ledger', icon('save'), h('span', { text: t('home.ledger', { gold: s.inventory.ledger.gold, materials: s.inventory.ledger.materials }) })) : null,
      Rules.emergencyNeeds(s).length ? h('div.alert.warn', icon('warn'), h('span', { text: t('home.aid_available') }), btn(t('home.open_port'), () => { app.ui.portTab = 'services'; app.go('port'); }, { small: true })) : null);
    grid.appendChild(stam);

    // Ship readiness.
    const hull = Content.hull(s.ship.hullId);
    const shipItems = [
      kv(t('home.hull'), t('hull.' + hull.id + '.name') + ' · ' + t('ship.tier', { n: hull.tier })),
      kv(t('home.crew_cap'), t('home.crew_cap_value', { n: s.crew.length, max: lay.capacity })),
      kv(t('home.damage'), s.ship.damage + '%', s.ship.damage >= 40 ? 'bad' : null)
    ];
    const warnings = [];
    for (const id of lay.missingRequired) warnings.push(h('li.bad', icon('warn'), h('span', { text: t('home.missing_required', { facility: t('fac.' + id + '.name') }) })));
    if (lay.overCapacity) warnings.push(h('li.bad', icon('warn'), h('span', { text: t('home.over_capacity') })));
    for (const uid of lay.disabled) {
      const f = s.ship.facilities.find(x => x.uid === uid);
      const info = lay.facilities[uid];
      warnings.push(h('li.warn', icon('lock'), h('span', { text: t('fac.' + f.id + '.name') + ' — ' + t(info.reasonKey, info.reasonParams) })));
    }
    for (const f of s.ship.facilities.filter(x => x.damaged)) warnings.push(h('li.warn', icon('warn'), h('span', { text: t('home.facility_damaged', { facility: t('fac.' + f.id + '.name') }) })));
    grid.appendChild(panel(t('home.ship'), h('div.kvs', shipItems),
      warnings.length ? h('ul.warnings', warnings) : h('p.good-note', icon('ok'), h('span', { text: t('home.ship_ready') })),
      btn(t('home.open_ship'), () => app.go('ship'), { small: true, icon: 'ship' })));

    // Formation.
    const form = h('div.formation-mini');
    Content.FORMATION_LANES.forEach((lane, li) => {
      const col = h('div.lane', h('div.lane-h', { text: t('lane.' + lane) }));
      for (let k = 0; k < 2; k++) {
        const id = s.formation[li * 2 + k];
        const m = id && Rules.member(s, id);
        col.appendChild(m ? crewChip(app, m) : h('div.slot-empty', { text: t('crew.empty_slot') }));
      }
      form.appendChild(col);
    });
    grid.appendChild(panel(t('home.formation'), form,
      h('div.row', tag(t('stance.' + s.tactics.stance + '.name')), tag(t('priority.' + s.tactics.priority + '.name')),
        btn(t('home.open_crew'), () => app.go('crew'), { small: true, icon: 'crew' }))));

    // Quests and contracts.
    const ql = h('ul.list');
    for (const [qid, qs] of Object.entries(s.world.quests)) {
      if (qs.status !== 'active') continue;
      const q = World.QUESTS[qid];
      ql.appendChild(h('li', icon('flag'), h('span', { text: t(q.titleKey, { location: locLabel(q.locationId) }) }), h('small', { text: ' · ' + locLabel(q.locationId) })));
    }
    for (const c of Rules.activeContracts(s)) {
      ql.appendChild(h('li', icon('codex'), h('span', { text: Views.contractText(c) })));
    }
    if (!ql.childNodes.length) ql.appendChild(h('li.empty', { text: t('home.no_quests') }));
    grid.appendChild(panel(t('home.quests'), ql));
    root.appendChild(grid);
    return root;
  }
  Views.contractText = function contractText(c) {
    if (c.type === 'hunt') return t('contract.hunt', { region: t('region.' + c.regionId + '.name'), have: c.progress || 0, need: c.need, port: locLabel(c.portId) });
    if (c.type === 'supply') return t('contract.supply', { need: c.need, port: locLabel(c.portId) });
    return t('contract.haul', { need: c.need, item: t('spec.' + c.specialtyId + '.name'), port: locLabel(c.portId) });
  };

  Object.assign(Views, { home, objective, logList, crewChip, locLabel, knowledgeTag, whereText });
})(typeof globalThis !== 'undefined' ? globalThis : this);
