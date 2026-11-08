/*
 * Project Seven Seas — Sea Chart: regions, knowledge states, route planning,
 * sailing, fast travel between charted ports, and site exploration rooms.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, World, Rules, I18n: I, UI, Art } = P;
  const { h, btn, panel, kv, tag, note, icon, tabs, empty } = UI;
  const t = I.t;
  const Views = P.Views;
  const loc = id => t('loc.' + id + '.name');

  function map(app) {
    const s = app.state;
    const ui = app.ui;
    const cur = World.location(s.world.currentLocationId);
    if (!ui.mapRegion || !World.region(ui.mapRegion)) ui.mapRegion = cur.regionId;
    const reg = World.region(ui.mapRegion);
    const unlocked = Rules.regionUnlocked(s, reg.id);
    const view = h('div.view.view-map');

    view.appendChild(h('div.view-head', h('h2', { text: t('map.title') }), h('span.small', { text: Views.whereText(s) })));
    view.appendChild(tabs(World.REGIONS.map(r => ({
      id: r.id, label: Rules.regionUnlocked(s, r.id) ? t('region.' + r.id + '.name') : t('map.region_locked_n', { n: r.order }),
      locked: !Rules.regionUnlocked(s, r.id), title: Rules.regionUnlocked(s, r.id) ? null : t('map.region_locked_hint')
    })), reg.id, id => { ui.mapRegion = id; ui.mapSel = null; app.rerender(); }, 'region-tabs'));

    if (!unlocked) {
      view.appendChild(panel(t('map.region_locked_n', { n: reg.order }), note(t('map.region_locked_hint')), Views.objective(app, true)));
      return view;
    }

    // Site exploration comes first while the ship is anchored at a site.
    const atSite = s.voyage && s.voyage.site && s.voyage.site.locationId === s.world.currentLocationId;
    const layout = h('div.map-layout');
    const left = h('div.map-left');
    left.appendChild(chart(app, reg));
    left.appendChild(h('p.small.region-desc', { text: t('region.' + reg.id + '.desc') }));
    left.appendChild(h('div.row.wrap',
      tag(t('map.specialty', { item: t('spec.' + reg.specialtyId + '.name') })),
      reg.hazard ? tag(t('map.hazard', { hazard: t('hazard.' + reg.hazard + '.name') }), 'warn') : null,
      reg.mechanic ? tag(t('mechanic.' + reg.mechanic + '.name'), 'warn') : null,
      tag(t('map.level', { n: reg.level })),
      tag(t('map.pet_family', { family: t('petfam.' + reg.petFamilyId + '.name') }))));
    left.appendChild(locationList(app, reg));
    layout.appendChild(left);

    const right = h('div.map-right');
    if (atSite) right.appendChild(sitePanel(app));
    if (s.voyage && !s.encounter) {
      right.appendChild(panel(t('map.voyage'),
        h('div.kvs', kv(t('map.origin'), loc(s.voyage.originPortId)), kv(t('home.ledger_short'), t('home.ledger', { gold: s.inventory.ledger.gold, materials: s.inventory.ledger.materials }))),
        note(t('map.emergency_hint')),
        btn(t('home.emergency_return'), () => app.emergencyReturn(), { kind: 'danger', icon: 'home' })));
    }
    if (ui.mapSel && World.location(ui.mapSel) && World.location(ui.mapSel).regionId === reg.id) right.appendChild(routePanel(app, ui.mapSel));
    else right.appendChild(panel(t('map.route'), note(t('map.select_hint'))));
    layout.appendChild(right);
    view.appendChild(layout);
    return view;
  }

  function chart(app, reg) {
    const s = app.state;
    const ui = app.ui;
    const wrap = h('div.chart');
    const canvas = h('canvas.chart-canvas', { width: 320, height: 200, 'aria-hidden': 'true' });
    const locs = reg.locs.map(id => {
      const l = World.location(id);
      return { id, x: l.x, y: l.y, type: l.type, knowledge: Rules.knowledge(s, id), current: id === s.world.currentLocationId };
    });
    try { Art.drawSeaChart(canvas, { palette: reg.palette, locations: locs, seed: World.hash32(reg.id) }); } catch (e) { /* canvas unsupported */ }
    wrap.appendChild(canvas);
    for (const l of locs) {
      if (l.knowledge === 'hidden') continue;
      const m = h('button.marker.k-' + l.knowledge + (l.current ? '.current' : '') + (ui.mapSel === l.id ? '.sel' : ''), {
        type: 'button', style: { left: (l.x * 100) + '%', top: (l.y * 100) + '%' }, title: loc(l.id) + ' · ' + t('know.' + l.knowledge),
        on: { click: () => { ui.mapSel = l.id; app.rerender(); } }
      }, icon(l.type), h('span.marker-label', { text: loc(l.id) }));
      wrap.appendChild(m);
    }
    const hidden = locs.filter(l => l.knowledge === 'hidden').length;
    if (hidden) wrap.appendChild(h('span.chart-fog', { text: t('map.uncharted', { n: hidden }) }));
    return wrap;
  }

  function locationList(app, reg) {
    const s = app.state;
    const ui = app.ui;
    const ul = h('ul.list.loc-list');
    for (const id of reg.locs) {
      const k = Rules.knowledge(s, id);
      if (k === 'hidden') continue;
      const l = World.location(id);
      ul.appendChild(h('li' + (ui.mapSel === id ? '.sel' : ''),
        h('button.linkish', { type: 'button', on: { click: () => { ui.mapSel = id; app.rerender(); } } }, icon(l.type), h('span', { text: loc(id) })),
        h('span.row', tag(t('loctype.' + l.type)), Views.knowledgeTag(s, id), l.type !== 'port' ? tag(t('map.level', { n: l.level })) : null,
          id === s.world.currentLocationId ? tag(t('map.here'), 'good') : null)));
    }
    const hiddenCount = reg.locs.filter(id => Rules.knowledge(s, id) === 'hidden').length;
    if (hiddenCount) ul.appendChild(h('li.empty', { text: t('map.hidden_count', { n: hiddenCount }) }));
    return panel(t('map.locations'), ul);
  }

  function routePanel(app, toId) {
    const s = app.state;
    const l = World.location(toId);
    const reg = World.region(l.regionId);
    const here = toId === s.world.currentLocationId;
    const body = [
      h('div.row', icon(l.type), tag(t('loctype.' + l.type)), Views.knowledgeTag(s, toId), l.type !== 'port' ? tag(t('map.level', { n: l.level })) : null),
      h('p.desc', { text: t('loctype.' + l.type + '.desc') })
    ];
    if (World.PORTS[toId]) body.push(h('p.small', { text: t('map.port_services', { list: Content.INVESTMENT_TRACKS.map(tr => t('track.' + tr + '.name') + ' ' + Rules.portTrack(s, toId, tr)).join(' · ') }) }));
    const rooms = World.rooms(toId);
    if (rooms.length) {
      const cleared = s.world.locations[toId].rooms;
      body.push(h('p.small', { text: t('map.rooms_cleared', { n: cleared.length, total: rooms.length }) }));
    }
    if (here) {
      body.push(h('p.good-note', icon('ok'), h('span', { text: t('map.you_are_here') })));
      if (Rules.atPort(s)) body.push(btn(t('home.open_port'), () => app.go('port'), { icon: 'port', kind: 'primary' }));
      return panel(loc(toId), body);
    }
    const info = Rules.routeInfo(s, toId, false);
    const lines = [
      kv(t('route.distance'), t('route.hours', { n: info.hours })),
      kv(t('route.food'), t('route.food_value', { n: info.food, after: info.foodAfter }), info.foodAfter < 0 ? 'bad' : null),
      World.PORTS[toId] ? null : kv(t('route.return'), info.returnPorts.length ? t('route.return_value', { n: info.returnFood, port: loc(info.returnPorts[0].id) }) : t('route.no_return'), info.returnOk ? null : 'warn'),
      World.PORTS[toId] ? null : kv(t('route.stamina'), t('route.stamina_value', { need: info.plannedStamina, have: info.stamina }), info.staminaAfter < 0 ? 'warn' : null),
      kv(t('route.hazards'), !info.hazardsKnown ? t('route.unknown') : info.hazards.length ? info.hazards.map(z => I.has('hazard.' + z + '.name') ? t('hazard.' + z + '.name') : t('mechanic.' + z + '.name')).join(', ') : t('route.none')),
      kv(t('route.capability'), info.capability.map(r => t('role.' + r)).join(', ')),
      kv(t('route.level'), I.fmtNum(info.level), info.level > avgLevel(s) + 3 ? 'warn' : null)
    ];
    body.push(h('div.kvs', lines));
    if (info.encounters.length) {
      body.push(h('h4', { text: info.exact ? t('route.events_exact') : t('route.events_rough') }));
      body.push(h('ul.odds', info.encounters.map(e => h('li', h('span', { text: t('sea.' + e.kind + '.title') }), h('b', { text: info.exact ? e.pct + '%' : t('odds.' + (e.pct >= 15 ? 'high' : e.pct >= 7 ? 'mid' : 'low')) })))));
    }
    if (!info.returnOk && !World.PORTS[toId]) body.push(h('div.alert.warn', icon('warn'), h('span', { text: t('route.return_warning') })));
    if (info.firstDiscovery) body.push(h('p.small', { text: t('route.first_discovery') }));
    const block = info.blockKey;
    body.push(h('div.row.wrap',
      btn(t('route.sail'), () => app.depart(toId, false), { kind: 'primary', icon: 'ship', cost: { food: info.food }, state: s, reason: block ? t(block) : null })));
    if (World.PORTS[toId]) {
      const fb = Rules.sailBlock(s, toId, true);
      body.push(h('div.row.wrap', btn(t('route.fast'), () => app.depart(toId, true), { icon: 'map', cost: { food: info.food }, state: s, reason: fb ? t(fb) : null }), h('small', { text: t('route.fast_hint') })));
    }
    return panel(t('map.route_to', { location: loc(toId) }), body);
  }
  function avgLevel(s) {
    const a = Rules.activeCrew(s);
    return a.length ? a.reduce((x, m) => x + m.level, 0) / a.length : 1;
  }

  // Rooms of the current site with stamina costs (GDD §11.1).
  function sitePanel(app) {
    const s = app.state;
    const locId = s.world.currentLocationId;
    const l = World.location(locId);
    const rooms = World.rooms(locId);
    const cleared = s.world.locations[locId].rooms;
    const explorer = Rules.explorerPet(s);
    const rows = rooms.map(rm => {
      const done = cleared.includes(rm.id);
      const accessible = P.Actions.roomAccessible(s, locId, rm.id);
      const secretLocked = rm.secret && !explorer;
      const trialLocked = rm.kind === 'trial' && (s.captain.mainStep[l.regionId] || 0) < 4 && !s.captain.trialsWon.includes(l.regionId);
      let reason = null;
      if (!accessible) reason = t('err.room_locked');
      else if (secretLocked) reason = t('err.need_explorer');
      else if (trialLocked) reason = t('err.trial_locked');
      const isFight = ['battle', 'elite', 'boss', 'trial'].includes(rm.kind);
      const current = s.voyage.site.current === rm.id;
      return h('li.room' + (done ? '.done' : '') + (current ? '.current' : '') + (reason ? '.locked' : ''),
        h('div.room-info',
          h('b', { text: t('room.' + rm.id + '.name') }),
          h('small', { text: t('roomkind.' + rm.kind) + (rm.objective ? ' · ' + t('map.objective') : '') + (rm.secret ? ' · ' + t('map.secret') : '') + ' · ' + t('reward.family.' + rm.family) })),
        h('div.row',
          done ? tag(t('know.cleared'), 'good') : null,
          done
            ? btn(t('site.move'), () => app.act('enterRoom', rm.id), { small: true, title: t('site.move_free'), reason: reason && reason !== t('err.trial_locked') ? reason : null, cost: null })
            : btn(t(isFight ? 'site.fight' : 'site.search'), () => app.act('enterRoom', rm.id), { small: true, kind: 'primary', cost: { stamina: rm.cost }, state: s, reason }),
          done && isFight ? btn(t('site.repeat'), () => app.act('enterRoom', rm.id, { repeat: true }), { small: true, cost: { stamina: rm.cost }, state: s, reason, title: t('site.repeat_hint') }) : null));
    });
    const body = [h('ul.rooms', rows), note(t('site.stamina_rule'))];
    if (s.captain.postgame && l.type === 'arena' && World.LEGENDS[l.regionId]) {
      const lg = World.LEGENDS[l.regionId];
      const def = World.encounterFor(locId, 'trial', { legend: true });
      body.push(h('div.legend-box', h('h4', { text: t('legend.title', { region: t('region.' + l.regionId + '.name') }) }),
        h('p.small', { text: t('legend.restriction.' + lg.restriction) }),
        s.captain.legendsWon.includes(l.regionId) ? tag(t('legend.won'), 'good') : null,
        btn(t('legend.challenge'), () => app.act('startLegend'), { kind: 'primary', cost: { stamina: def.staminaCost }, state: s })));
    }
    return panel(t('site.title', { location: loc(locId) }), body);
  }

  Views.map = map;
})(typeof globalThis !== 'undefined' ? globalThis : this);
