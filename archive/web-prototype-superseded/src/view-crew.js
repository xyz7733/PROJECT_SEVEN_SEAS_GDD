/*
 * Project Seven Seas — Crew view: roster, six-slot formation, tactics,
 * class tree with branches and respec, legacy passives, equipment, jobs.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, Rules, I18n: I, UI, Art } = P;
  const { h, btn, panel, kv, tag, note, icon, select, bar, empty } = UI;
  const t = I.t;
  const T = Content.TUNING;
  const Views = P.Views;

  function crew(app) {
    const s = app.state;
    const ui = app.ui;
    if (!ui.crewSel || !Rules.member(s, ui.crewSel)) ui.crewSel = s.crew[0] && s.crew[0].id;
    const view = h('div.view.view-crew');
    const lay = Rules.layoutOf(s);
    view.appendChild(h('div.view-head', h('h2', { text: t('crew.title') }), h('span.small', { text: t('home.crew_cap_value', { n: s.crew.length, max: lay.capacity }) })));

    const left = h('div.crew-left');
    // Formation: front, center, rear lanes with two slots each (GDD §7.3).
    const formReason = (!Rules.atPort(s) && !Rules.facLevel(s, 'muster_deck', { allowDamaged: true })) ? t('err.need_muster') : s.encounter ? t('err.in_encounter') : null;
    const fgrid = h('div.formation');
    Content.FORMATION_LANES.forEach((lane, li) => {
      const col = h('div.lane', h('div.lane-h', { text: t('lane.' + lane) }), h('small.lane-d', { text: t('lane.' + lane + '.desc') }));
      for (let k = 0; k < 2; k++) {
        const slot = li * 2 + k;
        const id = s.formation[slot];
        const m = id && Rules.member(s, id);
        const opts = [{ value: null, label: t('crew.empty_slot') }].concat(s.crew.map(c => ({ value: c.id, label: I.crewName(c) + ' · ' + t('class.' + c.classId + '.name') })));
        col.appendChild(h('div.slot' + (m ? '' : '.empty'),
          m ? Views.crewChip(app, m, { active: ui.crewSel === m.id, onClick: () => { ui.crewSel = m.id; app.rerender(); } }) : h('div.slot-empty', { text: t('crew.empty_slot') }),
          select(opts, id, v => app.act('setFormation', slot, v), { label: t('crew.slot_n', { n: slot + 1 }), disabled: !!formReason })));
      }
      fgrid.appendChild(col);
    });
    left.appendChild(panel(t('crew.formation'), fgrid, formReason ? note(formReason, 'warn') : note(t('crew.formation_hint'))));

    // Default tactics used when an encounter starts (GDD §12.3).
    left.appendChild(panel(t('crew.tactics'),
      h('h4', { text: t('battle.stance') }),
      h('div.row.wrap', Content.STANCES.map(st => btn(t('stance.' + st + '.name'), () => app.act('setTactics', st, null), { small: true, pressed: s.tactics.stance === st, title: t('stance.' + st + '.desc') }))),
      h('h4', { text: t('battle.priority') }),
      h('div.row.wrap', Content.PRIORITIES.map(pr => btn(t('priority.' + pr + '.name'), () => app.act('setTactics', null, pr), { small: true, pressed: s.tactics.priority === pr, title: t('priority.' + pr + '.desc') }))),
      note(t('crew.tactics_hint'))));

    // Roster.
    const roster = h('div.roster');
    for (const m of s.crew) {
      const slot = s.formation.indexOf(m.id);
      roster.appendChild(Views.crewChip(app, m, {
        active: ui.crewSel === m.id, showPower: true, onClick: () => { ui.crewSel = m.id; app.rerender(); },
        extra: slot >= 0 ? tag(t('lane.' + Rules.laneOfSlot(slot)), 'lane') : tag(t('crew.reserve'))
      }));
    }
    left.appendChild(panel(t('crew.roster'), roster));

    const m = Rules.member(s, ui.crewSel);
    view.appendChild(h('div.crew-layout', left, m ? detail(app, m) : empty(t('crew.none'))));
    return view;
  }

  function detail(app, m) {
    const s = app.state;
    const ui = app.ui;
    const st = Rules.memberStats(s, m);
    const cls = Content.CLASSES[m.classId];
    const calm = s.encounter ? t('err.in_encounter') : null;
    const wrap = h('div.crew-detail');

    // Header with identity and personal story.
    const nameInput = h('input.text', { type: 'text', value: m.nickname || '', placeholder: I.crewName(Object.assign({}, m, { nickname: null })), maxLength: 18, 'aria-label': t('crew.rename') });
    nameInput.addEventListener('change', () => app.act('rename', m.id, nameInput.value));
    const xpNeed = Rules.xpToNext(m.level);
    wrap.appendChild(panel(null,
      h('div.crew-head',
        UI.sprite(Art.portraitURL(m), 'portrait.big'),
        h('div.crew-head-text',
          h('h3', { text: I.crewName(m) }),
          h('p', { text: t('class.' + m.classId + '.name') + ' · ' + t('ui.lv', { n: m.level }) + (cls.tier === 'branch' ? ' · ' + t('crew.branch_of', { base: t('class.' + cls.parent + '.name') }) : '') }),
          bar(m.xp, xpNeed, 'xp', t('crew.xp', { n: Math.floor(m.xp), max: xpNeed })),
          h('div.row.wrap', h('label.small', { text: t('crew.rename') }), nameInput),
          m.injured ? h('div.alert.bad', icon('warn'), h('span', { text: t('crew.injury_note', { pct: I.pct(T.injuryPenalty) }) }),
            btn(t('crew.treat'), () => app.act('treat', m.id), { small: true, cost: Rules.atPort(s) ? { gold: Rules.treatCost(m).gold } : { supplies: 1 }, state: s, reason: !Rules.atPort(s) && !Rules.facLevel(s, 'infirmary') ? t('err.need_infirmary') : null })) : null)),
      h('div.kvs.cols',
        kv(t('crew.origin'), t('origin.' + m.originId)),
        kv(t('crew.traits'), m.traits.map(x => t('trait.' + x)).join(', ')),
        kv(t('crew.aptitudes'), m.aptitudes.map(a => t('apt.' + a + '.name')).join(', ')),
        kv(t('crew.affinity'), t('color.' + m.petAffinity)),
        kv(t('crew.event'), t('event.' + m.eventId + '.title') + ' — ' + (m.event.status === 'done' ? t('crew.event_done') : t('event.' + m.eventId + '.desc', { n: m.event.progress || 0, origin: t('origin.' + m.originId) })))),
      h('ul.small-list', m.aptitudes.map(a => h('li', { text: t('apt.' + a + '.name') + ': ' + UI.modLines(Content.APTITUDES[a]).join(', ') }))),
      m.eventId === 'collector' && m.event.status === 'active'
        ? btn(t('crew.event_deliver'), () => app.act('crewEventDeliver', m.id), { small: true, reason: Rules.atPort(s) ? null : t('err.need_port') }) : null,
      h('div.row.wrap',
        btn(t('crew.dismiss'), async () => { if (await app.confirm(t('crew.dismiss_confirm', { name: I.crewName(m) }), t('crew.dismiss_body'))) app.act('dismiss', m.id); },
          { small: true, kind: 'danger', reason: !Rules.atPort(s) ? t('err.need_port') : s.crew.length <= 1 ? t('err.last_crew') : null }))));

    // Stats.
    wrap.appendChild(panel(t('crew.stats'),
      h('div.stat-grid',
        stat('hp', st.hp), stat('atk', st.atk), stat('def', st.def), stat('spd', st.spd),
        h('div.stat', h('span', { text: t('stat.crit') }), h('b', { text: I.pct(st.crit) })),
        h('div.stat', h('span', { text: t('stat.dodge') }), h('b', { text: I.pct(st.dodge) }))),
      h('div.row.wrap', tag(t('range.' + st.range)), tag(t('lane.' + st.lane)), st.roles.map(r => tag(t('role.' + r), 'role')),
        st.resist.map(r => tag(t('item.resist', { hazard: t('hazard.' + r + '.name') }), 'good'))),
      h('p.small', { text: t('crew.power', { n: Rules.power(s, m) }) })));

    // Equipment (GDD §8): weapon, outfit, accessory each change behavior.
    const eq = h('div.equip');
    for (const slot of ['weapon', 'outfit', 'accessory']) {
      const inst = Rules.equipInst(s, m.equipment[slot]);
      const usedBy = uid => s.crew.find(c => c.id !== m.id && Object.values(c.equipment).includes(uid));
      const options = s.inventory.equipment.filter(e => Content.ITEMS[e.itemId] && Content.ITEMS[e.itemId].slot === slot && e.uid !== m.equipment[slot])
        .map(e => {
          const ok = Rules.weaponCompatible(m.classId, e.itemId);
          const other = usedBy(e.uid);
          return { value: e.uid, disabled: !ok, label: I.itemName(e.itemId, e) + (ok ? '' : ' — ' + t('crew.incompatible')) + (other ? ' (' + I.crewName(other) + ')' : '') };
        });
      eq.appendChild(h('div.equip-slot',
        h('div.equip-h', h('b', { text: t('slot.' + slot) }), slot === 'weapon' ? h('small', { text: t('crew.weapons_allowed', { list: cls.weapons.map(w => t('wtype.' + w)).join(', ') }) }) : null),
        inst ? h('div.item-card', h('b', { text: I.itemName(inst.itemId, inst) }), h('ul.small-list', UI.itemLines(inst.itemId, inst).map(x => h('li', { text: x })))) : h('p.empty', { text: t('crew.no_item') }),
        h('div.row.wrap',
          select([{ value: null, label: options.length ? t('crew.choose_item') : t('crew.no_items_owned') }].concat(options), null, v => { if (v) app.act('equip', m.id, slot, v); }, { label: t('slot.' + slot), disabled: !!calm || !options.length }),
          inst ? btn(t('crew.unequip'), () => app.act('equip', m.id, slot, null), { small: true, reason: calm }) : null)));
    }
    wrap.appendChild(panel(t('crew.equipment'), eq));

    // Skills and passives.
    const legacyOpts = Rules.legacyOptions(m);
    const legacyBox = h('div.legacy');
    for (let i = 0; i < T.legacySlots; i++) {
      const cur = m.legacy[i] || null;
      const opts = [{ value: null, label: legacyOpts.length ? t('crew.legacy_none') : t('crew.legacy_locked') }]
        .concat(legacyOpts.map(p => ({ value: p, label: t('passive.' + p + '.name'), disabled: m.legacy.includes(p) && p !== cur })));
      legacyBox.appendChild(h('div.legacy-slot', h('small', { text: t('crew.legacy_n', { n: i + 1 }) }),
        select(opts, cur, v => app.act('setLegacy', m.id, i, v), { label: t('crew.legacy_n', { n: i + 1 }), disabled: !!calm }),
        cur ? h('small.desc', { text: UI.passiveText(cur) }) : null));
    }
    wrap.appendChild(panel(t('crew.skills'),
      h('ul.skill-list', st.skills.map(id => h('li', h('b', { text: t('skill.' + id + '.name') }), h('small', { text: UI.skillText(id) })))),
      h('h4', { text: t('crew.passives') }),
      h('ul.skill-list', h('li', h('b', { text: t('passive.' + cls.passive + '.name') }), tag(t('crew.class_passive')), h('small', { text: UI.passiveText(cls.passive) }))),
      h('h4', { text: t('crew.legacy') }), note(t('crew.legacy_hint', { n: T.masteredAt })), legacyBox));

    // Class tree: 12 base classes, two branches each (GDD §7.4).
    const respecReason = calm || ((!Rules.atPort(s) && !Rules.facLevel(s, 'class_hall')) ? t('err.need_class_hall') : null);
    const cost = Rules.respecCost(m);
    const tree = h('div.class-tree');
    for (const baseId of Content.BASE_CLASS_IDS) {
      const base = Content.CLASSES[baseId];
      const node = id => {
        const c = Content.CLASSES[id];
        const mast = m.mastery[id] || 0;
        const qual = Rules.qualifiedFor(m, id);
        const current = m.classId === id;
        const reason = current ? null : respecReason || (!qual ? t('crew.need_mastery', { cls: t('class.' + c.parent + '.name'), n: T.qualifyMastery }) : !UI.canAfford(s, cost) ? t('err.no_gold', { need: cost.gold }) : null);
        return h('div.class-node' + (current ? '.current' : '') + (qual ? '' : '.locked') + (mast >= T.masteredAt ? '.mastered' : ''), { style: { '--cc': Art.classColor(id) } },
          h('div.cn-head', h('i.swatch'), h('b', { text: t('class.' + id + '.name') }), mast >= T.masteredAt ? tag(t('crew.mastered'), 'good') : null),
          h('small', { text: t('class.' + id + '.desc') }),
          bar(Math.min(mast, T.masteredAt), T.masteredAt, 'mastery', t('crew.mastery', { n: Math.floor(mast), max: T.masteredAt })),
          current ? tag(t('crew.current_class'), 'good') : btn(t('crew.change_class'), async () => {
            if (await app.confirm(t('crew.respec_confirm', { name: I.crewName(m), cls: t('class.' + id + '.name') }), t('crew.respec_body'))) app.act('changeClass', m.id, id);
          }, { small: true, cost, state: s, reason }));
      };
      tree.appendChild(h('div.class-branch', node(baseId), h('div.branches', base.branches.map(node))));
    }
    wrap.appendChild(panel(t('crew.classes'), note(t('crew.respec_rule')), tree));

    // Job and companion.
    const jobs = s.ship.facilities.filter(f => Rules.jobSlots(f) > 0 && !f.stowed);
    const lay = Rules.layoutOf(s);
    const curJob = s.ship.facilities.find(f => f.uid === m.jobFacilityUid);
    const pet = s.pets.find(p => p.assignment && p.assignment.kind === 'companion' && p.assignment.target === m.id);
    wrap.appendChild(panel(t('crew.job'),
      h('p', { text: curJob ? t('crew.job_current', { facility: t('fac.' + curJob.id + '.name'), pct: I.pct(Rules.workerEfficiency(s, m, curJob.id)) }) : t('crew.job_none') }),
      h('p.small', { text: t('crew.jobs_preferred', { list: cls.jobs.map(j => t('fac.' + j + '.name')).join(', ') }) }),
      select([{ value: null, label: t('crew.job_none') }].concat(jobs.map(f => ({
        value: f.uid, disabled: !lay.facilities[f.uid].reachable,
        label: t('fac.' + f.id + '.name') + ' · ' + I.pct(Rules.workerEfficiency(s, m, f.id)) + (lay.facilities[f.uid].reachable ? '' : ' — ' + t('ship.status_disabled'))
      }))), m.jobFacilityUid, v => app.act('assignJob', m.id, v), { label: t('crew.job'), disabled: !!calm }),
      h('p.small', { text: pet ? t('crew.companion', { pet: I.petName(pet) }) : t('crew.no_companion') })));
    return wrap;
  }
  function stat(k, v) { return h('div.stat', h('span', { text: t('stat.' + k) }), h('b', { text: I.fmtNum(v) })); }

  Views.crew = crew;
})(typeof globalThis !== 'undefined' ? globalThis : this);
