/*
 * Project Seven Seas — Pet Lab view: ordered egg feeding with deterministic,
 * Codex-recorded outcomes, and pet assignment to battle, ship, or exploration.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, Rules, I18n: I, UI, Art } = P;
  const { h, btn, panel, kv, tag, note, icon, empty, select } = UI;
  const t = I.t;
  const Views = P.Views;

  function colorDot(c) { return h('i.dot', { style: { background: Art.COLOR_HEX[c] || '#888' }, title: t('color.' + c) }); }
  function inputLabel(inp) { const [k, id] = inp.split(':'); return t((k === 'ing' ? 'ing.' : 'spec.') + id + '.name'); }
  function seqText(colors) { return colors.map(c => t('color.' + c)).join(' → '); }

  function pets(app) {
    const s = app.state;
    const ui = app.ui;
    const hatchery = Rules.facLevel(s, 'hatchery', { allowDamaged: true });
    const lab = Rules.facLevel(s, 'pet_lab');
    const view = h('div.view.view-pets');
    view.appendChild(h('div.view-head', h('h2', { text: t('pets.title') }),
      tag(t('pets.count', { n: s.pets.length, max: Rules.petCapacity(s) })),
      tag(t('pets.eggs_count', { n: s.inventory.eggs.length, max: Rules.eggCapacity(s) })),
      tag(hatchery ? t('pets.hatchery_level', { n: hatchery }) : t('pets.no_hatchery'), hatchery ? 'good' : 'bad'),
      tag(lab ? t('pets.lab_level', { n: lab }) : t('pets.no_lab'), lab ? 'good' : null)));

    // ----------------------------------------------------------- hatching
    if (!s.inventory.eggs.find(e => e.id === ui.petEgg)) { ui.petEgg = s.inventory.eggs.length ? s.inventory.eggs[0].id : null; ui.petInputs = []; }
    ui.petInputs = ui.petInputs || [];
    const egg = s.inventory.eggs.find(e => e.id === ui.petEgg);
    const eggList = s.inventory.eggs.length ? h('div.eggs', s.inventory.eggs.map(e => {
      const fam = Content.petFamily(e.familyId);
      return h('button.egg' + (e.id === ui.petEgg ? '.sel' : ''), { type: 'button', onclick: () => { ui.petEgg = e.id; ui.petInputs = []; app.rerender(); }, 'aria-pressed': String(e.id === ui.petEgg) },
        UI.sprite(Art.eggSpriteURL(fam.color, e.grade), 'egg-sprite'),
        h('b', { text: t('petfam.' + e.familyId + '.name') }), h('small', { text: t('pets.grade', { n: e.grade }) }));
    })) : empty(t('pets.no_eggs'));

    // Count what is still available after the inputs already queued.
    const queued = {};
    for (const inp of ui.petInputs) queued[inp] = (queued[inp] || 0) + 1;
    const avail = [];
    for (const [id, n] of Object.entries(s.inventory.ingredients)) if (n > 0) avail.push({ inp: 'ing:' + id, n: n - (queued['ing:' + id] || 0), color: Content.INGREDIENTS[id].color });
    for (const [id, n] of Object.entries(s.inventory.specialties)) if (n > 0) avail.push({ inp: 'spec:' + id, n: n - (queued['spec:' + id] || 0), color: Content.SPECIALTIES[id].color });

    let hatchPanel;
    if (egg) {
      const fam = Content.petFamily(egg.familyId);
      const colors = ui.petInputs.map(Rules.inputColor);
      const known = colors.length ? s.codex.hatchLog.find(x => x.familyId === egg.familyId && x.colors.join() === colors.join()) : null;
      const role = colors.length ? Content.ROLE_BY_COLOR[colors[0]] : null;
      const slots = [0, 1, 2].map(i => {
        const inp = ui.petInputs[i];
        return h('div.feed-slot' + (inp ? '.filled' : ''), h('small', { text: t('pets.feed_n', { n: i + 1 }) }),
          inp ? h('span', colorDot(Rules.inputColor(inp)), h('span', { text: inputLabel(inp) })) : h('span.muted', { text: t('pets.empty_slot') }));
      });
      const picker = avail.length ? h('div.feed-pick', avail.map(a => btn(inputLabel(a.inp) + ' ×' + Math.max(0, a.n), () => { ui.petInputs.push(a.inp); app.rerender(); },
        { small: true, reason: a.n <= 0 ? t('pets.none_left') : ui.petInputs.length >= 3 ? t('pets.max_inputs') : null, title: t('color.' + a.color) }))) : note(t('pets.no_inputs'), 'warn');
      const clue = s.codex.clues.includes('clue.pet.' + egg.familyId);
      hatchPanel = panel(t('pets.feed_title', { family: t('petfam.' + egg.familyId + '.name') }),
        note(t('pets.feed_rule')),
        h('div.feed-slots', slots), picker,
        h('div.kvs',
          kv(t('pets.predicted_role'), role ? t('petrole.' + role) : '—'),
          kv(t('pets.known_outcome'), known ? t('pet.' + known.speciesId + '.name') + (known.prime ? ' · ' + t('pets.prime') : '') : colors.length ? t('pets.unrecorded') : '—'),
          kv(t('pets.hatch_level'), String([1, 3, 5][egg.grade - 1] || 1))),
        clue ? h('div.clue', h('b', { text: t('pets.signatures') }), h('ul.small-list', Content.PET_ROLES.map(r => h('li', { text: t('petrole.' + r) + ': ' + seqText(fam.sig[r]) })))) : note(t('pets.signature_hint')),
        h('div.row.wrap',
          btn(t('pets.clear'), () => { ui.petInputs = []; app.rerender(); }, { small: true, reason: ui.petInputs.length ? null : t('pets.nothing_queued') }),
          btn(t('pets.hatch'), async () => {
            const r = await app.act('hatchEgg', egg.id, ui.petInputs.slice());
            if (r && r.ok) { ui.petInputs = []; ui.petSel = r.value; app.rerender(); }
          }, { kind: 'primary', icon: 'pets', reason: !hatchery ? t('err.need_facility', { facility: 'fac.hatchery.name' }) : !ui.petInputs.length ? t('err.hatch_inputs') : s.pets.length >= Rules.petCapacity(s) ? t('err.pet_full') : null })));
    } else hatchPanel = panel(t('pets.feed_title_none'), empty(t('pets.no_eggs_hint')));

    view.appendChild(h('div.grid2', panel(t('pets.eggs'), eggList, note(t('pets.egg_sources'))), hatchPanel));

    // ------------------------------------------------------------- roster
    if (!s.pets.find(p => p.id === ui.petSel)) ui.petSel = s.pets.length ? s.pets[0].id : null;
    const roster = s.pets.length ? h('div.pet-list', s.pets.map(p => {
      const sp = Content.PET_SPECIES[p.speciesId];
      return h('button.pet-chip' + (p.id === ui.petSel ? '.sel' : ''), { type: 'button', onclick: () => { ui.petSel = p.id; app.rerender(); } },
        UI.sprite(Art.petSpriteURL(p.familyId, sp.role, p.evolved, p.affinity), 'pet-sprite'),
        h('span', h('b', { text: I.petName(p) }), h('small', { text: t('ui.lv', { n: p.level }) + (p.prime ? ' · ' + t('pets.prime') : '') + ' · ' + assignText(s, p) })));
    })) : empty(t('pets.no_pets'));
    const sel = s.pets.find(p => p.id === ui.petSel);
    view.appendChild(h('div.grid2', panel(t('pets.roster'), roster), sel ? petDetail(app, sel, lab) : panel(t('pets.detail'), empty(t('pets.no_pets')))));
    return view;
  }

  function assignText(s, p) {
    const a = p.assignment;
    if (!a) return t('pets.unassigned');
    if (a.kind === 'companion') { const m = Rules.member(s, a.target); return t('pets.with', { name: m ? I.crewName(m) : '—' }); }
    if (a.kind === 'helper') { const f = s.ship.facilities.find(x => x.uid === a.target); return t('pets.at', { facility: f ? t('fac.' + f.id + '.name') : '—' }); }
    return t('petrole.explorer');
  }

  function petDetail(app, p, lab) {
    const s = app.state;
    const sp = Content.PET_SPECIES[p.speciesId];
    const fam = Content.petFamily(p.familyId);
    const roles = Rules.petRoles(p);
    const ab = Content.PET_ABILITIES[fam.ability];
    const ec = Rules.evolveCost(p);
    const a = p.assignment || {};
    const companionOpts = [{ value: null, label: '—' }].concat(s.formation.filter(Boolean).map(id => ({ value: id, label: I.crewName(Rules.member(s, id)) })));
    const layout = Rules.layoutOf(s);
    const helperOpts = [{ value: null, label: '—' }].concat(s.ship.facilities.filter(f => !f.stowed).map(f => ({ value: f.uid, label: t('fac.' + f.id + '.name') + ' · ' + t('ship.deck_n', { n: f.deck + 1 }), disabled: !layout.facilities[f.uid] || !layout.facilities[f.uid].reachable })));
    const owner = a.kind === 'companion' ? Rules.member(s, a.target) : null;
    const power = Rules.petPowerMult(p, owner, owner ? Rules.memberStats(s, owner) : null);
    return panel(t('pets.detail'),
      h('div.row', UI.sprite(Art.petSpriteURL(p.familyId, sp.role, p.evolved, p.affinity), 'pet-sprite big'),
        h('div', h('h3', { text: I.petName(p) }), h('small', { text: t('pet.' + p.speciesId + '.name') + ' · ' + t('petfam.' + p.familyId + '.name') }),
          h('div.row.wrap', p.prime ? tag(t('pets.prime'), 'good') : null, p.evolved ? tag(t('pets.evolved'), 'good') : null, tag(t('pets.affinity', { color: t('color.' + p.affinity) }))))),
      UI.bar(p.xp, Rules.petXpToNext(p.level), 'xp', t('ui.lv', { n: p.level }) + ' · ' + t('crew.xp', { n: p.xp, max: Rules.petXpToNext(p.level) })),
      h('div.kvs',
        kv(t('pets.roles'), roles.map(r => t('petrole.' + r)).join(', ')),
        kv(t('pets.ability'), t('petability.' + fam.ability) + ' — ' + abilityText(ab)),
        kv(t('pets.power'), '×' + I.fmtNum(Math.round(power * 100) / 100)),
        kv(t('pets.assignment'), assignText(s, p)),
        kv(t('pets.inputs'), (p.inputs || []).map(inputLabel).join(' → ') || '—')),
      h('div.assign',
        h('div.row.wrap', h('b', { text: t('petrole.companion') }), select(companionOpts, a.kind === 'companion' ? a.target : null, v => app.act('assignPet', p.id, v ? 'companion' : null, v), { label: t('petrole.companion'), disabled: !roles.includes('companion') }),
          roles.includes('companion') ? h('small', { text: t('petrole.companion.desc') }) : h('small.muted', { text: t('err.pet_role', { role: 'petrole.companion' }) })),
        h('div.row.wrap', h('b', { text: t('petrole.helper') }), select(helperOpts, a.kind === 'helper' ? a.target : null, v => app.act('assignPet', p.id, v ? 'helper' : null, v), { label: t('petrole.helper') }),
          h('small', { text: roles.includes('helper') ? t('petrole.helper.desc') : t('pets.helper_half') })),
        h('div.row.wrap', h('b', { text: t('petrole.explorer') }),
          btn(a.kind === 'explorer' ? t('pets.recall') : t('pets.send_explore'), () => app.act('assignPet', p.id, a.kind === 'explorer' ? null : 'explorer'), { small: true, pressed: a.kind === 'explorer', reason: roles.includes('explorer') ? null : t('err.pet_role', { role: 'petrole.explorer' }) }),
          h('small', { text: t('petrole.explorer.desc') })),
        p.assignment ? btn(t('pets.unassign'), () => app.act('assignPet', p.id, null), { small: true }) : null),
      h('div.evolve',
        h('h4', { text: t('pets.evolution') }),
        p.evolved ? note(t('pets.evolved_note')) : h('div',
          note(t('pets.evolve_hint', { level: ec.level })),
          btn(t('pets.evolve'), () => app.act('evolvePet', p.id), { kind: 'primary', cost: { materials: ec.materials, specialty: ec.specialty }, state: s,
            reason: !lab ? t('err.need_facility', { facility: 'fac.pet_lab.name' }) : p.level < ec.level ? t('err.pet_level', { level: ec.level }) : null }))),
      renameRow(app, p));
  }
  function renameRow(app, p) {
    const input = h('input.text', { type: 'text', value: p.nickname || '', placeholder: t('pet.' + p.speciesId + '.name'), maxLength: 18, 'aria-label': t('crew.rename') });
    input.addEventListener('change', () => app.act('renamePet', p.id, input.value));
    return h('div.row.wrap', h('label.small', { text: t('crew.rename') }), input);
  }
  function abilityText(ab) {
    const parts = [t('pets.target_' + (ab.target || 'enemy'))];
    if (ab.power) parts.push(t('pets.ab_power', { pct: I.pct(ab.power) }));
    if (ab.heal) parts.push(t('pets.ab_heal', { pct: I.pct(ab.heal) }));
    if (ab.shield) parts.push(t('pets.ab_shield', { pct: I.pct(ab.shield) }));
    return parts.concat(UI.fxLines(ab.fx)).join(', ');
  }

  Views.pets = pets;
})(typeof globalThis !== 'undefined' ? globalThis : this);
