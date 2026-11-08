/*
 * Project Seven Seas — Port view: investment tracks that unlock real
 * services, controlled specialty trade, tavern, workshop, quest board,
 * contracts, and always-available emergency assistance.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, World, Rules, I18n: I, UI, Art } = P;
  const { h, btn, panel, kv, tag, note, icon, tabs, empty, select } = UI;
  const t = I.t;
  const T = Content.TUNING;
  const Views = P.Views;
  const loc = id => t('loc.' + id + '.name');
  const TABS = ['invest', 'market', 'tavern', 'workshop', 'board', 'services'];

  function port(app) {
    const s = app.state;
    const ui = app.ui;
    const view = h('div.view.view-port');
    if (!Rules.atPort(s)) {
      view.appendChild(h('div.view-head', h('h2', { text: t('port.title') })));
      view.appendChild(panel(t('port.not_docked'),
        h('p', { text: Views.whereText(s) }),
        note(t('port.not_docked_hint', { location: loc(s.world.lastSafePortId) })),
        h('div.row.wrap',
          s.voyage && !s.encounter ? btn(t('home.emergency_return'), () => app.emergencyReturn(), { kind: 'danger', icon: 'home' }) : null,
          btn(t('home.open_chart'), () => app.go('map'), { icon: 'map' }))));
      return view;
    }
    const portId = s.world.currentLocationId;
    const reg = World.region(World.PORTS[portId].regionId);
    if (!TABS.includes(ui.portTab)) ui.portTab = 'invest';
    view.appendChild(h('div.view-head',
      h('h2', { text: loc(portId) }), tag(t('region.' + reg.id + '.name')),
      tag(t('map.specialty', { item: t('spec.' + reg.specialtyId + '.name') })),
      h('span.small', { text: t('port.reputation', { list: Content.FACTIONS.map(f => t('faction.' + f + '.name') + ' ' + t('rank.' + Rules.repRank(s, f))).join(' · ') }) })));
    view.appendChild(h('div.port-objective', Views.objective(app, true)));
    const needs = Rules.emergencyNeeds(s);
    view.appendChild(tabs(TABS.map(id => ({ id, label: t('port.tab_' + id), badge: id === 'services' && needs.length ? needs.length : null })), ui.portTab, id => { ui.portTab = id; app.rerender(); }));
    const body = { invest, market, tavern, workshop, board, services }[ui.portTab](app, portId, reg);
    view.appendChild(body);
    return view;
  }

  function invest(app, portId) {
    const s = app.state;
    const rows = Content.INVESTMENT_TRACKS.map(tr => {
      const lvl = Rules.portTrack(s, portId, tr);
      const cost = Rules.investCost(s, portId, tr);
      const levels = [1, 2, 3].map(n => h('li' + (n <= lvl ? '.got' : ''), icon(n <= lvl ? 'ok' : 'lock'), h('span', { text: t('track.' + tr + '.l' + n) })));
      return h('div.track',
        h('div.track-h', h('b', { text: t('track.' + tr + '.name') }), tag(t('port.track_level', { n: lvl })), h('small', { text: t('track.' + tr + '.desc') })),
        h('ul.track-levels', levels),
        cost ? btn(t('port.invest_to', { n: cost.level }), () => app.act('invest', tr), { small: true, kind: 'primary', cost, state: s, reason: UI.canAfford(s, cost) ? null : t('ship.cannot_afford') }) : tag(t('port.track_max'), 'good'));
    });
    return h('div.grid2', panel(t('port.invest_title'), note(t('port.invest_hint')), h('div.tracks', rows)));
  }

  function market(app, portId, reg) {
    const s = app.state;
    const pr = Rules.prices(s, portId);
    const m = Rules.portTrack(s, portId, 'market');
    const foodCap = Rules.foodCapacity(s);
    const supCap = Rules.supplyCapacity(s);
    const lockedAt = n => (m < n ? t('err.market_level', { level: n }) : null);
    const goods = panel(t('port.goods'),
      h('div.goods',
        goodRow(t('status.food'), 'food', t('port.stock', { n: s.inventory.food, max: foodCap }), [1, 5, 10].map(q => btn('+' + q, () => app.act('buyGoods', 'food', null, q), { small: true, cost: { gold: pr.food * q }, state: s, reason: s.inventory.food + q > foodCap ? t('err.food_full') : null }))),
        goodRow(t('status.supplies'), 'supplies', t('port.stock', { n: s.inventory.supplies, max: supCap }), [1, 3].map(q => btn('+' + q, () => app.act('buyGoods', 'supplies', null, q), { small: true, cost: { gold: pr.supplies * q }, state: s, reason: lockedAt(1) || (s.inventory.supplies + q > supCap ? t('err.supplies_full') : null) })))),
      note(t('port.food_rule')));
    const ingr = panel(t('port.ingredients'), lockedAt(1) ? note(lockedAt(1), 'warn') : null,
      h('div.goods', Object.entries(Content.INGREDIENTS).map(([id, ing]) => goodRow(t('ing.' + id + '.name'), null, t('port.owned', { n: s.inventory.ingredients[id] || 0 }) + ' · ' + t('color.' + ing.color),
        [btn('+1', () => app.act('buyGoods', 'ingredient', id, 1), { small: true, cost: { gold: pr.ingredient }, state: s, reason: lockedAt(1) })], ing.color))));
    // Controlled specialty trade (GDD §10.3): buy only the local specialty;
    // sell price depends on distance from its home region.
    const specRows = [];
    const local = reg.specialtyId;
    specRows.push(goodRow(t('spec.' + local + '.name'), null, t('port.owned', { n: s.inventory.specialties[local] || 0 }) + ' · ' + t('port.local_specialty'),
      [btn('+1', () => app.act('buyGoods', 'specialty', local, 1), { small: true, cost: { gold: Rules.specialtyBuyPrice(s, portId, local) }, state: s, reason: lockedAt(2) })], Content.SPECIALTIES[local].color));
    for (const [id, n] of Object.entries(s.inventory.specialties)) {
      if (!n) continue;
      const price = Rules.specialtySellPrice(s, portId, id);
      specRows.push(goodRow(t('spec.' + id + '.name'), null, t('port.owned', { n }) + ' · ' + t('port.sell_price', { n: price }),
        [btn(t('port.sell_one'), () => app.act('sellSpecialty', id, 1), { small: true })], Content.SPECIALTIES[id].color));
    }
    const specs = panel(t('port.specialties'), h('div.goods', specRows), note(t('port.specialty_rule')));
    const egg = panel(t('port.eggs'), h('p', { text: t('port.egg_offer', { family: t('petfam.' + reg.petFamilyId + '.name') }) }),
      btn(t('port.buy_egg'), () => app.act('buyGoods', 'egg', null, 1), { small: true, cost: { gold: pr.egg }, state: s, reason: lockedAt(3) }));
    const items = Rules.shopItems(s, portId);
    const cap = Rules.equipCapacity(s);
    const shop = panel(t('port.equipment_shop'), h('p.small', { text: t('port.equip_stock', { n: s.inventory.equipment.length, max: cap }) }),
      items.length ? h('div.shop', items.map(id => itemCard(app, id, null, btn(t('port.buy'), () => app.act('buyItem', id), { small: true, cost: { gold: Rules.itemPrice(id) }, state: s, reason: s.inventory.equipment.length >= cap ? t('err.equip_full') : null })))) : note(t('err.market_level', { level: 1 }), 'warn'));
    return h('div.grid2', goods, ingr, specs, egg, shop);
  }
  function goodRow(label, iconName, sub, buttons, color) {
    return h('div.good', h('div.good-l', iconName ? icon(iconName) : h('i.dot', { style: { background: Art.COLOR_HEX[color] || '#888' } }), h('b', { text: label }), h('small', { text: sub })), h('div.row', buttons));
  }
  function itemCard(app, itemId, inst, action) {
    const it = Content.ITEMS[itemId];
    return h('div.item-card',
      h('div.item-h', h('b', { text: I.itemName(itemId, inst) }), tag(t('slot.' + it.slot)), it.wtype ? tag(t('wtype.' + it.wtype)) : null, it.tier ? tag(t('ui.tier', { n: it.tier })) : null),
      h('ul.small-list', UI.itemLines(itemId, inst).map(x => h('li', { text: x }))),
      it.wtype ? h('small', { text: t('port.usable_by', { list: Content.BASE_CLASS_IDS.filter(c => Content.CLASSES[c].weapons.includes(it.wtype)).map(c => t('class.' + c + '.name')).join(', ') }) }) : null,
      action);
  }

  function tavern(app, portId) {
    const s = app.state;
    const pool = Rules.tavernPool(s, portId);
    const cap = Rules.crewCapacity(s);
    const lvl = Rules.portTrack(s, portId, 'tavern');
    const nextDay = (Rules.rotation(s) + 1) * 3 + 1;
    const cards = pool.map(o => {
      const m = o.member;
      const cls = Content.CLASSES[m.classId];
      return h('div.recruit' + (o.hired ? '.hired' : ''),
        h('div.row', UI.sprite(Art.portraitURL(Object.assign({ id: 'pool' + o.index }, m)), 'portrait'),
          h('div', h('b', { text: I.crewName(m) }), h('small', { text: t('class.' + m.classId + '.name') + ' · ' + t('ui.lv', { n: m.level }) }))),
        h('div.kvs',
          kv(t('crew.origin'), t('origin.' + m.originId)),
          kv(t('crew.traits'), m.traits.map(x => t('trait.' + x)).join(', ')),
          kv(t('crew.aptitudes'), o.aptVisible ? m.aptitudes.map(a => t('apt.' + a + '.name')).join(', ') : t('port.aptitudes_hidden')),
          kv(t('route.capability'), cls.roles.map(r => t('role.' + r)).join(', '))),
        m.mastery[m.classId] >= T.qualifyMastery ? tag(t('port.qualified', { cls: t('class.' + m.classId + '.name') }), 'good') : null,
        o.hired ? tag(t('port.hired'), 'good') : btn(t('port.recruit'), () => app.act('recruit', o.index), { small: true, kind: 'primary', cost: { gold: o.cost }, state: s, reason: s.crew.length >= cap ? t('err.over_capacity') : null }));
    });
    return h('div',
      panel(t('port.tavern_title'), note(t('port.tavern_hint', { day: nextDay, level: lvl })), h('p.small', { text: t('home.crew_cap_value', { n: s.crew.length, max: cap }) }),
        h('div.recruits', cards)));
  }

  function workshop(app, portId) {
    const s = app.state;
    const craft = Rules.canCraftHere(s);
    const reinf = Rules.canReinforceHere(s);
    const recipes = s.inventory.recipes.filter(id => Content.ITEMS[id] && Content.ITEMS[id].recipe);
    if (!app.ui.craftAffix) app.ui.craftAffix = '';
    const affixSel = select([{ value: null, label: t('port.no_affix') }].concat(Object.keys(Content.AFFIXES).map(a => ({ value: a, label: t('affix.' + a + '.name') + ' — ' + UI.modLines(Content.AFFIXES[a]).join(', ') }))),
      app.ui.craftAffix || null, v => { app.ui.craftAffix = v || ''; app.rerender(); }, { label: t('port.affix'), disabled: !reinf });
    const recipeCards = recipes.map(id => {
      const cost = Rules.craftCost(id, app.ui.craftAffix || null, s);
      return itemCard(app, id, app.ui.craftAffix ? { affix: app.ui.craftAffix } : null,
        btn(t('port.craft'), () => app.act('craftItem', id, app.ui.craftAffix || null), { small: true, cost, state: s, reason: craft ? null : t('err.need_workshop') }));
    });
    const inv = s.inventory.equipment.map(e => {
      const owner = s.crew.find(c => Object.values(c.equipment).includes(e.uid));
      const rc = Rules.reinforceCost(e, s);
      return itemCard(app, e.itemId, e, h('div.row.wrap',
        owner ? tag(t('port.equipped_by', { name: I.crewName(owner) })) : null,
        btn(t('port.reinforce'), () => app.act('reinforce', e.uid), { small: true, cost: rc, state: s, reason: !reinf ? t('err.need_workshop2') : (e.reinforce || 0) >= 3 ? t('err.max_level') : null }),
        btn(t('port.salvage', { n: Rules.salvageValue(e).materials }), () => app.act('salvage', e.uid), { small: true, kind: 'danger', reason: owner ? t('err.equipped') : null })));
    });
    return h('div',
      panel(t('port.workshop_title'), note(craft ? t('port.workshop_ok') : t('err.need_workshop')), h('div.row', h('label.small', { text: t('port.affix') }), affixSel, reinf ? null : h('small', { text: t('err.need_workshop2') })),
        recipeCards.length ? h('div.shop', recipeCards) : empty(t('port.no_recipes'))),
      panel(t('port.inventory', { n: s.inventory.equipment.length, max: Rules.equipCapacity(s) }), inv.length ? h('div.shop', inv) : empty(t('port.no_equipment'))));
  }

  function board(app, portId, reg) {
    const s = app.state;
    const ms = Rules.mainStatus(s);
    const qb = Rules.portTrack(s, portId, 'quest_board');
    const main = panel(t('port.main_quest'), Views.objective(app),
      !ms.done && ms.quest.type === 'deliver'
        ? btn(t('port.deliver', { n: ms.quest.count, item: t('spec.' + ms.quest.itemId + '.name') }), () => app.act('deliverMain'), { kind: 'primary', cost: { specialty: [ms.quest.itemId, ms.quest.count] }, state: s, reason: ms.quest.locationId !== portId ? t('err.wrong_port') : null })
        : null);
    const sides = World.sideQuests(reg.id).filter(q => q.giverId === portId).map(q => {
      const st = s.world.quests[q.id];
      return h('li',
        h('div', h('b', { text: t(q.titleKey, { location: loc(q.locationId) }) }), h('small', { text: t('side.' + q.template + '.desc', { location: loc(q.locationId) }) + ' · ' + t('faction.' + q.faction + '.name') }),
          h('small', { text: t('port.reward', { gold: q.reward.gold, xp: q.reward.xp, extra: t('reward.kind.' + q.rewardKind) }) })),
        !st ? btn(t('port.accept'), () => app.act('acceptQuest', q.id), { small: true, reason: qb < 1 ? t('err.board_level', { level: 1 }) : null })
          : tag(t(st.status === 'done' ? 'port.quest_done' : 'port.quest_active'), st.status === 'done' ? 'good' : null));
    });
    const offers = Rules.contractOffers(s, portId).map(c => h('li',
      h('div', h('b', { text: t('contract.' + c.type + '.title') }), h('small', { text: Views.contractText(c) }), h('small', { text: t('port.contract_reward', { gold: c.reward.gold, materials: c.reward.materials }) })),
      c.status === 'offered' ? btn(t('port.accept'), () => app.act('acceptContract', c.id), { small: true })
        : c.status === 'active' ? btn(t('port.complete'), () => app.act('completeContract', c.id), { small: true, kind: 'primary', cost: c.type === 'supply' ? { food: c.need } : c.type === 'haul' ? { specialty: [c.specialtyId, c.need] } : null, state: s, reason: c.type === 'hunt' && c.progress < c.need ? t('err.contract_incomplete', { have: c.progress, need: c.need }) : null })
          : tag(t('port.quest_done'), 'good')));
    const active = Rules.activeContracts(s).filter(c => c.portId !== portId).map(c => h('li', h('small', { text: Views.contractText(c) })));
    return h('div.grid2', main,
      panel(t('port.side_quests'), qb < 1 ? note(t('err.board_level', { level: 1 }), 'warn') : null, sides.length ? h('ul.list', sides) : empty(t('port.no_side'))),
      panel(t('port.contracts'), qb < 2 ? note(t('err.board_level', { level: 2 }), 'warn') : note(t('port.contract_hint')), offers.length ? h('ul.list', offers) : null,
        active.length ? h('div', h('h4', { text: t('port.contracts_elsewhere') }), h('ul.list', active)) : null));
  }

  function services(app, portId) {
    const s = app.state;
    const needs = Rules.emergencyNeeds(s);
    const injured = s.crew.filter(m => m.injured);
    const rc = Rules.repairCost(s);
    const rr = Rules.facLevel(s, 'recovery_room');
    const aid = panel(t('port.aid_title'), note(t('port.aid_hint')),
      h('div.row.wrap', ['meal', 'treatment', 'repair'].map(k => btn(t('aid.' + k), () => app.act('emergencyAid', k), { small: true, kind: needs.includes(k) ? 'primary' : null, reason: needs.includes(k) ? null : t('err.aid_not_needed'), title: t('aid.' + k + '.desc') }))),
      h('div.row.wrap', btn(t('port.dock_work', { n: 20 + 5 * Rules.regionTierOfPort(portId) }), () => app.act('dockWork'), { small: true, reason: Rules.recoveryContractAvailable(s) ? null : t('port.dock_work_locked') }), h('small', { text: t('port.dock_work_hint') })));
    const treat = panel(t('port.treatment'),
      injured.length ? h('ul.list', injured.map(m => h('li', h('span', { text: I.crewName(m) }), btn(t('crew.treat'), () => app.act('treat', m.id), { small: true, cost: rr ? null : { gold: Rules.treatCost(m).gold }, state: s })))) : empty(t('port.no_injured')),
      rr ? note(t('port.recovery_room', { n: rr })) : null);
    const repair = panel(t('port.repair'), h('div.kvs', kv(t('home.damage'), s.ship.damage + '%')),
      btn(t('ship.repair'), () => app.act('repairShip'), { small: true, cost: { gold: rc.gold, materials: rc.materials }, state: s, reason: rc.needed ? null : t('err.nothing_to_repair') }));
    const wait = panel(t('port.wait_title'), note(t('port.wait_hint')), btn(t('port.wait'), () => app.act('waitAtPort'), { small: true, icon: 'clock' }));
    return h('div.grid2', aid, treat, repair, wait);
  }

  Views.port = port;
  Views.itemCard = itemCard;
})(typeof globalThis !== 'undefined' ? globalThis : this);
