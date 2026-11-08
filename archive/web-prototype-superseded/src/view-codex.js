/*
 * Project Seven Seas — Codex view: everything the captain has discovered,
 * including the deterministic hatch log for repeating egg outcomes.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, World, Rules, I18n: I, UI, Art } = P;
  const { h, panel, kv, tag, note, tabs, empty } = UI;
  const t = I.t;
  const Views = P.Views;
  const TABS = ['locations', 'enemies', 'classes', 'pets', 'items', 'clues'];

  function codex(app) {
    const s = app.state;
    const ui = app.ui;
    if (!TABS.includes(ui.codexTab)) ui.codexTab = 'locations';
    const prog = Rules.codexProgress(s);
    const view = h('div.view.view-codex');
    view.appendChild(h('div.view-head', h('h2', { text: t('codex.title') }),
      h('span.small', { text: t('codex.captain', { title: s.captain.titleKey, n: s.captain.trialsWon.length }) })));
    const counts = { locations: prog.locations, enemies: prog.enemies, classes: prog.classes, pets: prog.pets, items: prog.items, clues: prog.clues };
    view.appendChild(h('div.codex-progress', TABS.map(id => {
      const [n, max] = counts[id];
      return h('div.stat', h('b', { text: max ? I.fmtNum(n) + ' / ' + I.fmtNum(max) : I.fmtNum(n) }), h('small', { text: t('codex.tab_' + id) }), max ? UI.bar(n, max, 'thin') : null);
    })));
    view.appendChild(tabs(TABS.map(id => ({ id, label: t('codex.tab_' + id) })), ui.codexTab, id => { ui.codexTab = id; app.rerender(); }));
    view.appendChild({ locations, enemies, classes, pets, items, clues }[ui.codexTab](app));
    return view;
  }

  function locations(app) {
    const s = app.state;
    return h('div.codex-regions', World.REGIONS.map(r => {
      const unlocked = Rules.regionUnlocked(s, r.id);
      const locs = r.locs.map(id => {
        const k = Rules.knowledge(s, id);
        const l = World.location(id);
        return h('li.k-' + k, UI.icon(k === 'hidden' ? 'question' : l.type), h('span', { text: k === 'hidden' ? t('codex.unknown_location') : t('loc.' + id + '.name') }), Views.knowledgeTag(s, id));
      });
      const ms = s.captain.mainStep[r.id] || 0;
      const arcLines = [];
      for (let i = 0; i < Math.min(ms + 1, 5); i++) arcLines.push(h('li', { text: t('arc.' + r.id + '.' + i) }));
      return panel(t('region.' + r.id + '.name'),
        unlocked ? h('p.small', { text: t('region.' + r.id + '.desc') }) : note(t('codex.region_locked'), 'warn'),
        unlocked ? h('div.kvs',
          kv(t('codex.arc'), t('arc.' + r.id + '.title')),
          kv(t('map.specialty_label'), t('spec.' + r.specialtyId + '.name')),
          kv(t('codex.hazard'), r.hazard ? t('hazard.' + r.hazard + '.name') : t('codex.none_value')),
          kv(t('codex.mechanic'), r.mechanic ? t('mechanic.' + r.mechanic + '.name') : t('codex.none_value')),
          kv(t('codex.pet_family'), t('petfam.' + r.petFamilyId + '.name')),
          kv(t('codex.trial'), s.captain.trialsWon.includes(r.id) ? t('codex.trial_won') : t('codex.trial_pending')),
          s.captain.postgame && World.LEGENDS[r.id] ? kv(t('legend.title'), s.captain.legendsWon.includes(r.id) ? t('codex.trial_won') : t('legend.restriction.' + World.LEGENDS[r.id].restriction)) : null) : null,
        unlocked && arcLines.length ? h('ol.arc', arcLines) : null,
        h('ul.codex-locs', locs));
    }));
  }

  function enemies(app) {
    const s = app.state;
    const ids = World.allEnemyIds();
    const cards = ids.map(id => {
      const c = s.codex.enemies[id];
      const e = World.enemy(id);
      if (!c) return h('div.codex-card.unknown', UI.icon('question'), h('span', { text: t('codex.unknown_enemy') }));
      const reg = e.regionId ? World.region(e.regionId) : null;
      return h('div.codex-card',
        UI.sprite(Art.enemySpriteURL(e.archetype, reg ? reg.palette.accent : '#a33', reg ? reg.palette.land : '#555'), 'enemy-sprite'),
        h('div', h('b', { text: t('enemy.' + id + '.name') }),
          h('small', { text: t('archetype.' + e.archetype) + (reg ? ' · ' + t('region.' + reg.id + '.name') : '') }),
          h('small', { text: t('codex.defeated', { n: c.defeated || 0 }) }),
          e.boss ? tag(t(e.rival ? 'codex.rival' : 'codex.boss'), 'bad') : null));
    });
    return panel(t('codex.tab_enemies'), h('div.codex-grid', cards));
  }

  function classes(app) {
    const s = app.state;
    return panel(t('codex.tab_classes'), note(t('codex.classes_hint')), h('div.codex-grid', Content.BASE_CLASS_IDS.map(base => {
      const cls = Content.CLASSES[base];
      const ids = [base].concat(cls.branches || []);
      return h('div.codex-card.class-card',
        h('i.dot', { style: { background: Art.classColor(base) } }),
        h('div', ids.map(id => h('div', h('b' + (s.codex.classes[id] ? '' : '.muted'), { text: s.codex.classes[id] ? t('class.' + id + '.name') : t('codex.unknown_class') }),
          s.codex.classes[id] ? h('small', { text: t('class.' + id + '.desc') }) : null))));
    })));
  }

  function pets(app) {
    const s = app.state;
    const fams = Content.PET_FAMILIES.map(f => {
      const forms = Content.PET_ROLES.flatMap(r => [f.id + '_' + r, f.id + '_' + r + '_evo']);
      return h('div.codex-card',
        UI.sprite(Art.petSpriteURL(f.id, 'companion', false, f.color), 'pet-sprite'),
        h('div', h('b', { text: t('petfam.' + f.id + '.name') }), h('small', { text: t('region.' + f.regionId + '.name') + ' · ' + t('petability.' + f.ability) }),
          h('ul.small-list', forms.map(sp => { const c = s.codex.pets[sp]; return h('li' + (c ? '' : '.muted'), { text: c ? t('pet.' + sp + '.name') + (c.prime ? ' ★' : '') : t('codex.unknown_pet') }); }))));
    });
    const log = s.codex.hatchLog.length ? h('table.hatch-log',
      h('thead', h('tr', h('th', { text: t('codex.family') }), h('th', { text: t('codex.order') }), h('th', { text: t('codex.result') }))),
      h('tbody', s.codex.hatchLog.map(x => h('tr',
        h('td', { text: t('petfam.' + x.familyId + '.name') }),
        h('td', x.colors.map(c => h('i.dot', { style: { background: Art.COLOR_HEX[c] }, title: t('color.' + c) })), h('span.small', { text: ' ' + x.colors.map(c => t('color.' + c)).join(' → ') })),
        h('td', { text: t('pet.' + x.speciesId + '.name') + (x.prime ? ' · ' + t('pets.prime') : '') })))))
      : empty(t('codex.no_hatches'));
    return h('div', panel(t('codex.hatch_log'), note(t('codex.hatch_hint')), log), panel(t('codex.tab_pets'), h('div.codex-grid', fams)));
  }

  function items(app) {
    const s = app.state;
    const seen = Object.keys(s.codex.items);
    const recipes = s.inventory.recipes;
    const rows = seen.map(id => h('li', h('b', { text: I.itemName(id) }), h('small', { text: t('slot.' + Content.ITEMS[id].slot) + (recipes.includes(id) ? ' · ' + t('codex.recipe_known') : '') })));
    return h('div.grid2',
      panel(t('codex.items_seen'), rows.length ? h('ul.list.compact', rows) : empty(t('codex.none'))),
      panel(t('codex.recipes'), recipes.length ? h('ul.list.compact', recipes.map(id => h('li', h('b', { text: I.itemName(id) }), h('small', { text: t('codex.recipe_cost', { n: Content.ITEMS[id].recipe.materials, item: 'spec.' + Content.ITEMS[id].recipe.specialty[0] + '.name', k: Content.ITEMS[id].recipe.specialty[1] }) }))) ) : empty(t('codex.none')),
        h('div.kvs', kv(t('codex.blueprints'), s.inventory.blueprints.length ? s.inventory.blueprints.map(b => t('blueprint.' + b)).join(', ') : '—'),
          kv(t('codex.uniques'), s.inventory.uniques.length ? s.inventory.uniques.map(u => I.itemName(u)).join(', ') : '—'))));
  }

  function clues(app) {
    const s = app.state;
    return panel(t('codex.tab_clues'), s.codex.clues.length ? h('ul.list', s.codex.clues.map(c => h('li', { text: t(c) }))) : empty(t('codex.no_clues')));
  }

  Views.codex = codex;
})(typeof globalThis !== 'undefined' ? globalThis : this);
