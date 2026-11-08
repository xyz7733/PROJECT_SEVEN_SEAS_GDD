/*
 * Project Seven Seas — battle overlay (GDD §8). One shared auto-combat
 * simulation runs live; the captain can pause at any time and issue
 * commands (focus target, skill priority, stance, retreat). The recorded
 * commands are handed to Actions.resolveEncounter, which re-simulates the
 * battle from the stored seed, so the visible fight and the committed result
 * are identical and a reload never rerolls it.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const { Content, Combat, I18n: I, UI, Art, World } = P;
  const { h, btn, icon, tag } = UI;
  const t = I.t;

  const STATUS_ICONS = { stun: 'lock', slow: 'clock', mark: 'eye', taunt: 'vanguard', evade: 'scout', shield: 'def', buffAtk: 'atk', buffDef: 'def', regen: 'hp', dot: 'warn', sunder: 'warn' };

  function unitName(app, sim, uid) {
    const u = sim.allies.find(x => x.uid === uid) || sim.enemies.find(x => x.uid === uid);
    if (!u) return '?';
    if (u.side === 'ally') { const m = app.state.crew.find(c => c.id === u.key); return m ? I.crewName(m) : t('ui.former_crew'); }
    return t(u.nameKey);
  }
  function skillName(id) {
    if (!id) return t('battle.basic_attack');
    if (id.startsWith('pet_')) return t('petability.' + id.slice(4));
    return t('skill.' + id + '.name');
  }
  function eventText(app, sim, ev) {
    const n = uid => unitName(app, sim, uid);
    switch (ev.type) {
      case 'wave': return t('battle.ev_wave', { n: ev.wave, max: sim.spec.waves.length });
      case 'hit': return t(ev.crit ? 'battle.ev_crit' : 'battle.ev_hit', { src: n(ev.src), tgt: n(ev.tgt), n: ev.amount, skill: skillName(ev.skill) }) + (ev.absorbed ? ' ' + t('battle.ev_absorbed', { n: ev.absorbed }) : '');
      case 'miss': return t('battle.ev_miss', { src: n(ev.src), tgt: n(ev.tgt) });
      case 'heal': return t('battle.ev_heal', { src: n(ev.src), tgt: n(ev.tgt), n: ev.amount });
      case 'ko': return t('battle.ev_ko', { tgt: n(ev.tgt) });
      case 'skill': return t('battle.ev_skill', { src: n(ev.src), skill: skillName(ev.skill) });
      case 'windup': return t('battle.ev_windup', { src: n(ev.src), skill: skillName(ev.skill), tgt: n(ev.tgt) });
      case 'interrupt': return t('battle.ev_interrupt', { tgt: n(ev.tgt), skill: skillName(ev.skill) });
      case 'stun': return t('battle.ev_stun', { tgt: n(ev.tgt), n: Math.round(ev.secs * 10) / 10 });
      case 'intercept': return t('battle.ev_intercept', { src: n(ev.src), tgt: n(ev.tgt) });
      case 'thorns': return t('battle.ev_thorns', { src: n(ev.src), tgt: n(ev.tgt), n: ev.amount });
      case 'trap': return t('battle.ev_trap', { tgt: n(ev.tgt), n: ev.amount });
      case 'resist': return t('battle.ev_resist', { tgt: n(ev.tgt) });
      case 'dot': return t('battle.ev_dot', { tgt: n(ev.tgt), n: ev.amount });
      case 'pet': return t('battle.ev_pet', { src: n(ev.src), ability: t('petability.' + ev.ability) });
      case 'hazard': return t('battle.ev_hazard', { hazard: t('hazard.' + ev.hazard + '.name') });
      case 'encore': return t('battle.ev_encore');
      case 'command': return t('battle.ev_command_' + ev.cmd, { value: ev.cmd === 'focus' ? n(ev.value) : ev.cmd === 'stance' ? t('stance.' + ev.value + '.name') : ev.cmd === 'priority' ? t('priority.' + ev.value + '.name') : '' });
      case 'end': return t('battle.ev_end_' + ev.outcome);
      default: return ev.type;
    }
  }

  function contextTitle(enc) {
    const c = enc.context || {};
    const def = enc.def;
    if (c.type === 'sea') return t('battle.title_sea', { kind: t('sea.' + c.kind + '.title'), location: t('loc.' + c.toId + '.name') });
    if (c.type === 'legend') return t('battle.title_legend', { region: t('region.' + def.regionId + '.name') });
    return t('battle.title_room', { room: t('room.' + def.roomId + '.name'), location: t('loc.' + def.locationId + '.name'), kind: t('roomkind.' + def.kind) });
  }

  function open(app) {
    const enc = app.state.encounter;
    if (!enc) return null;
    const overlay = document.getElementById('battle');
    UI.clear(overlay);
    overlay.hidden = false;
    document.body.classList.add('in-battle');
    const sim = Combat.create(enc.spec);
    const st = {
      sim, speed: app.settings.battleSpeed || 1, paused: !!app.settings.pauseAtEncounterStart, menu: !!app.settings.pauseAtEncounterStart,
      acc: 0, last: 0, seenSeq: 0, raf: 0, done: false, logLines: [], cards: {}, resolved: false
    };
    app.battle = st;

    // ---------------------------------------------------------------- DOM
    const title = h('div.b-title', h('h2', { text: contextTitle(enc) }), h('div.b-mods', (enc.def.modifiers || []).map(m => tag(modName(m), 'mod'))));
    const clock = h('span.b-clock');
    const waveEl = h('span.b-wave');
    const allyCol = h('div.b-side.b-allies', { 'aria-label': t('battle.allies') });
    const enemyCol = h('div.b-side.b-enemies', { 'aria-label': t('battle.enemies') });
    const logEl = h('ol.b-log', { 'aria-live': 'polite' });
    const tactics = h('div.b-tactics');
    const pauseBtn = h('button.btn.primary.b-pause', { type: 'button' });
    const speedBtns = [1, 2, 4].map(v => h('button.btn.small.b-speed', { type: 'button', text: '×' + v, dataset: { speed: String(v) }, on: { click: () => { st.speed = v; refreshControls(); } } }));
    const skipBtn = h('button.btn.small', { type: 'button', title: t('battle.skip_hint'), on: { click: () => skip() } }, h('span', { text: t('battle.skip') }));
    const retreatBtn = h('button.btn.small.danger', { type: 'button', on: { click: () => command('retreat', null) } });
    const status = h('div.b-status');
    const menu = h('div.b-menu');
    const board = h('div.b-board', allyCol, h('div.b-vs', { text: 'VS' }), enemyCol);
    const box = h('div.b-box', { role: 'dialog', 'aria-modal': 'true', 'aria-label': contextTitle(enc) },
      h('div.b-head', title, h('div.b-meta', waveEl, clock)),
      board, status,
      h('div.b-controls', pauseBtn, h('div.row', speedBtns), skipBtn, retreatBtn),
      menu,
      h('details.b-logwrap', { open: true }, h('summary', { text: t('battle.log') }), logEl));
    overlay.appendChild(box);
    pauseBtn.addEventListener('click', () => togglePause());

    function modName(m) {
      if (Content.HAZARDS[m]) return t('hazard.' + m + '.name');
      if (m.startsWith('legend_')) return t('legend.restriction.' + m.slice(7));
      if (m === 'trial') return t('battle.mod_trial');
      return t('mechanic.' + m + '.name');
    }

    function unitCard(u) {
      const isAlly = u.side === 'ally';
      let spriteUrl;
      if (isAlly) { const m = app.state.crew.find(c => c.id === u.key); spriteUrl = Art.allySpriteURL(m || { classId: u.defId, seed: 1 }); }
      else { const def = World.enemy(u.key); const reg = def.regionId ? World.region(def.regionId) : null; spriteUrl = Art.enemySpriteURL(u.archetype, reg ? reg.palette.accent : '#c33', reg ? reg.palette.land : '#555'); }
      const hpFill = h('div.fill');
      const shFill = h('div.fill.shield');
      const meter = h('div.fill');
      const hpText = h('small.b-hp');
      const sts = h('div.b-st');
      const wind = h('div.b-windup');
      const fx = h('div.b-fx', { 'aria-hidden': 'true' });
      const card = h(isAlly ? 'div.b-unit.ally' : 'button.b-unit.enemy', isAlly ? {} : { type: 'button', title: t('battle.focus_hint') },
        h('div.b-sprite', UI.sprite(spriteUrl, 'unit-sprite'), u.pet ? UI.sprite(Art.petSpriteURL(u.pet.familyId, 'companion', u.pet.evolved, null), 'pet-mini') : null, fx),
        h('div.b-info',
          h('b', { text: unitName(app, sim, u.uid) }),
          h('small', { text: t('ui.lv', { n: u.level }) + ' · ' + (isAlly ? t('class.' + u.defId + '.name') : t('archetype.' + u.archetype)) + ' · ' + t('lane.' + u.lane) }),
          h('div.bar.hp', hpFill, shFill), hpText,
          h('div.bar.meter', meter), sts, wind));
      if (!isAlly) card.addEventListener('click', () => { if (u.alive && !u.decoy) command('focus', sim.focus === u.uid ? null : u.uid); });
      return { card, hpFill, shFill, meter, hpText, sts, wind, fx };
    }
    function layoutSide(col, units, side) {
      UI.clear(col);
      for (const lane of Content.FORMATION_LANES) {
        const laneUnits = units.filter(u => u.lane === lane);
        const laneEl = h('div.b-lane', h('small.b-lane-h', { text: t('lane.' + lane) }));
        for (const u of laneUnits) {
          const c = unitCard(u);
          st.cards[u.uid] = c;
          laneEl.appendChild(c.card);
        }
        col.appendChild(laneEl);
      }
      col.dataset.side = side;
    }
    let shownWave = -1;
    let shownEnemies = null;
    function syncUnits() {
      if (shownWave !== sim.wave || shownEnemies !== sim.enemies) {
        shownWave = sim.wave; shownEnemies = sim.enemies;
        st.cards = {};
        layoutSide(allyCol, sim.allies, 'ally');
        layoutSide(enemyCol, sim.enemies, 'enemy');
      }
      for (const u of sim.allies.concat(sim.enemies)) {
        const c = st.cards[u.uid];
        if (!c) continue;
        const pct = Math.max(0, u.hp / u.maxHp);
        c.hpFill.style.width = (pct * 100).toFixed(1) + '%';
        c.hpFill.className = 'fill' + (pct < 0.3 ? ' low' : pct < 0.6 ? ' mid' : '');
        c.shFill.style.width = Math.min(100, (u.st.shield / u.maxHp) * 100).toFixed(1) + '%';
        c.meter.style.width = Math.min(100, u.meter).toFixed(0) + '%';
        c.hpText.textContent = I.fmtNum(Math.max(0, Math.round(u.hp))) + ' / ' + I.fmtNum(u.maxHp) + (u.st.shield > 0 ? ' (+' + I.fmtNum(Math.round(u.st.shield)) + ')' : '');
        c.card.classList.toggle('ko', !u.alive);
        c.card.classList.toggle('focus', sim.focus === u.uid);
        c.card.classList.toggle('stunned', u.st.stun > 0);
        if (u.side === 'enemy') c.card.disabled = !u.alive || u.decoy;
        const active = Object.keys(STATUS_ICONS).filter(k => (k === 'shield' ? 0 : u.st[k]) > 0);
        const sig = active.join(',');
        if (c.sts.dataset.sig !== sig) {
          c.sts.dataset.sig = sig;
          UI.clear(c.sts);
          for (const k of active) c.sts.appendChild(h('span.b-chip', { title: t('status.' + k) }, icon(STATUS_ICONS[k]), h('span', { text: t('status.' + k) })));
        }
        const w = u.windup ? t('battle.winding', { skill: skillName(u.windup.skill), n: Math.max(0, Math.round(u.windup.left * 10) / 10) }) : '';
        if (c.wind.textContent !== w) c.wind.textContent = w;
      }
      waveEl.textContent = t('battle.wave', { n: sim.wave + 1, max: sim.spec.waves.length });
      clock.textContent = t('battle.time', { n: Math.floor(sim.tick * Combat.DT), max: Math.round(Combat.LIMIT_TICKS * Combat.DT) });
    }
    function float(uid, text, cls) {
      if (app.settings.reduceMotion) return;
      const c = st.cards[uid];
      if (!c) return;
      const el = h('span.b-float.' + cls, { text });
      c.fx.appendChild(el);
      setTimeout(() => el.remove(), 900);
    }
    function consumeLog() {
      for (const ev of sim.log) {
        if (ev.seq <= st.seenSeq) continue;
        st.seenSeq = ev.seq;
        if (ev.type === 'hit') float(ev.tgt, (ev.crit ? '!' : '') + I.fmtNum(ev.amount), ev.crit ? 'crit' : 'dmg');
        else if (ev.type === 'heal') float(ev.tgt, '+' + I.fmtNum(ev.amount), 'heal');
        else if (ev.type === 'miss') float(ev.tgt, t('battle.miss'), 'miss');
        else if (ev.type === 'dot' || ev.type === 'thorns' || ev.type === 'trap') float(ev.tgt, I.fmtNum(ev.amount), 'dot');
        else if (ev.type === 'interrupt') float(ev.tgt, t('battle.interrupted'), 'ctl');
        else if (ev.type === 'stun') float(ev.tgt, t('status.stun'), 'ctl');
        if (ev.type === 'heal' && ev.amount < 1) continue;
        st.logLines.push({ cls: ev.type, text: eventText(app, sim, ev) });
      }
      if (st.logLines.length > 60) st.logLines.splice(0, st.logLines.length - 60);
      const want = st.logLines.slice(-14);
      UI.clear(logEl);
      for (const l of want) logEl.appendChild(h('li.ev-' + l.cls, { text: l.text }));
    }

    // ------------------------------------------------------------ commands
    function command(type, value) {
      if (sim.outcome) return;
      Combat.issue(sim, type, value);
      // Apply immediately for feedback while paused; the replay applies the
      // same command at the same tick, so the result is identical.
      if (st.paused) previewCommand(type, value);
      refreshControls();
      syncUnits();
    }
    function previewCommand(type, value) {
      if (type === 'focus') sim.focus = value;
      else if (type === 'stance') sim.stance = value;
      else if (type === 'priority') sim.priority = value;
    }
    function togglePause(force) {
      st.paused = force != null ? force : !st.paused;
      st.menu = st.paused;
      refreshControls();
    }
    function refreshControls() {
      UI.clear(pauseBtn);
      pauseBtn.appendChild(h('span', { text: st.paused ? t('battle.resume') : t('battle.pause') }));
      for (const b of speedBtns) b.classList.toggle('on', Number(b.dataset.speed) === st.speed);
      UI.clear(retreatBtn);
      retreatBtn.appendChild(h('span', { text: sim.retreating > 0 ? t('battle.retreating', { n: Math.max(0, Math.round(sim.retreating * 10) / 10) }) : t('battle.retreat') }));
      retreatBtn.disabled = sim.retreating > 0 || !!sim.outcome;
      status.textContent = t('battle.status', { stance: t('stance.' + sim.stance + '.name'), priority: t('priority.' + sim.priority + '.name'), focus: sim.focus ? unitName(app, sim, sim.focus) : t('battle.focus_auto') });
      renderMenu();
    }
    function renderMenu() {
      UI.clear(menu);
      menu.hidden = !st.menu;
      box.classList.toggle('paused', st.paused);
      if (!st.menu) return;
      const stance = h('div.b-group', h('h4', { text: t('battle.stance') }), h('div.row.wrap', Content.STANCES.map(s =>
        h('button.btn.small' + (sim.stance === s ? '.on' : ''), { type: 'button', title: t('stance.' + s + '.desc'), on: { click: () => command('stance', s) } }, h('span', { text: t('stance.' + s + '.name') })))),
        h('small', { text: t('stance.' + sim.stance + '.desc') }));
      const prio = h('div.b-group', h('h4', { text: t('battle.priority') }), h('div.row.wrap', Content.PRIORITIES.map(p =>
        h('button.btn.small' + (sim.priority === p ? '.on' : ''), { type: 'button', title: t('priority.' + p + '.desc'), on: { click: () => command('priority', p) } }, h('span', { text: t('priority.' + p + '.name') })))),
        h('small', { text: t('priority.' + sim.priority + '.desc') }));
      const focus = h('div.b-group', h('h4', { text: t('battle.focus') }), h('div.row.wrap',
        h('button.btn.small' + (!sim.focus ? '.on' : ''), { type: 'button', on: { click: () => command('focus', null) } }, h('span', { text: t('battle.focus_auto') })),
        sim.enemies.filter(e => e.alive && !e.decoy).map(e => h('button.btn.small' + (sim.focus === e.uid ? '.on' : ''), { type: 'button', on: { click: () => command('focus', e.uid) } }, h('span', { text: unitName(app, sim, e.uid) })))),
        h('small', { text: t('battle.focus_hint') }));
      const retreat = h('div.b-group', h('h4', { text: t('battle.retreat') }), h('small', { text: t('battle.retreat_hint', { n: enc.spec.retreatSecs || 3 }) }));
      menu.appendChild(h('div.b-menu-in', h('h3', { text: t('battle.paused') }), stance, prio, focus, retreat));
    }

    // ---------------------------------------------------------------- loop
    function frame(ts) {
      if (st.done) return;
      if (!st.last) st.last = ts;
      const dt = Math.min(0.25, (ts - st.last) / 1000);
      st.last = ts;
      if (!st.paused) {
        st.acc += dt * st.speed;
        let n = 0;
        while (st.acc >= Combat.DT && !sim.outcome && n < 40) { Combat.step(sim); st.acc -= Combat.DT; n++; }
        if (n) { syncUnits(); consumeLog(); refreshControls(); }
      }
      if (sim.outcome) { finish(); return; }
      st.raf = requestAnimationFrame(frame);
    }
    function skip() {
      st.paused = false; st.menu = false;
      let guard = 0;
      while (!sim.outcome && guard++ < Combat.LIMIT_TICKS + 10) Combat.step(sim);
      syncUnits(); consumeLog();
      finish();
    }
    async function finish() {
      if (st.resolved) return;
      st.resolved = true;
      st.done = true;
      cancelAnimationFrame(st.raf);
      syncUnits(); consumeLog();
      const r = await app.act('resolveEncounter', enc.attemptId, sim.commands.slice());
      showResult(r && r.ok ? r.value : null);
    }
    function showResult(summary) {
      UI.clear(menu);
      menu.hidden = false;
      box.classList.add('ended');
      pauseBtn.disabled = true; skipBtn.disabled = true; retreatBtn.disabled = true;
      for (const b of speedBtns) b.disabled = true;
      const closeBtn = btn(t('battle.continue'), () => close(), { kind: 'primary' });
      if (!summary) {
        menu.appendChild(h('div.b-menu-in.b-result', h('h3', { text: t('battle.result_error') }), closeBtn));
        return;
      }
      menu.appendChild(resultView(app, summary, closeBtn));
      setTimeout(() => closeBtn.focus(), 30);
    }
    function close() {
      st.done = true;
      cancelAnimationFrame(st.raf);
      overlay.hidden = true;
      UI.clear(overlay);
      document.body.classList.remove('in-battle');
      app.battle = null;
      app.afterBattle();
    }
    st.keys = e => {
      if (st.resolved) { if (e.key === 'Enter' || e.key === 'Escape') { e.preventDefault(); const b = menu.querySelector('.btn.primary'); if (b) b.click(); } return; }
      if (e.key === ' ' || e.key === 'Escape' || e.key === 'p') { e.preventDefault(); togglePause(); }
      else if (e.key === '1' || e.key === '2' || e.key === '4') { st.speed = Number(e.key); refreshControls(); }
      else if (e.key === 'r') command('retreat', null);
      else if (e.key === 's') skip();
    };
    st.close = close;
    syncUnits(); consumeLog(); refreshControls();
    st.raf = requestAnimationFrame(frame);
    setTimeout(() => pauseBtn.focus(), 30);
    return st;
  }

  function rewardLines(r) {
    if (!r) return [];
    const out = [];
    if (r.gold) out.push(t('battle.r_gold', { n: r.gold }));
    if (r.materials) out.push(t('battle.r_materials', { n: r.materials }));
    if (r.food) out.push(t('battle.r_food', { n: r.food }));
    if (r.supplies) out.push(t('battle.r_supplies', { n: r.supplies }));
    if (r.specialty) out.push(t('battle.r_specialty', { item: 'spec.' + r.specialty[0] + '.name', n: r.specialty[1] }));
    if (r.ingredients && r.ingredients.length) out.push(t('battle.r_ingredients', { list: r.ingredients.map(i => t('ing.' + i + '.name')).join(', ') }));
    if (r.egg) out.push(t('battle.r_egg', { family: 'petfam.' + r.egg.familyId + '.name', n: r.egg.grade }));
    for (const it of r.items || []) out.push(t('battle.r_item', { item: I.itemName(it) }));
    if (r.clue) out.push(t('battle.r_clue', { clue: r.clue }));
    return out;
  }

  function resultView(app, s, closeBtn) {
    const outcomeKey = 'battle.outcome_' + s.outcome + (s.reason === 'timeout' ? '_timeout' : '');
    const lines = [];
    if (s.outcome === 'victory') {
      lines.push(...rewardLines(s.rewards));
      if (s.xp) lines.push(t('battle.r_xp', { n: s.xp }));
      if (s.context && s.context.type !== 'sea' && !(s.context.type === 'legend')) lines.push(t('battle.r_ledger'));
      if (s.arrived) lines.push(t('battle.r_arrived', { location: 'loc.' + s.arrived + '.name' }));
    } else if (s.outcome === 'retreat') {
      lines.push(t('battle.retreat_result'));
    } else {
      lines.push(t('battle.defeat_result', { gold: s.losses ? s.losses.gold : 0, materials: s.losses ? s.losses.materials : 0, location: 'loc.' + s.returnedTo + '.name' }));
      if (s.losses && s.losses.damagedFacility) lines.push(t('battle.defeat_facility', { facility: 'fac.' + s.losses.damagedFacility + '.name' }));
      if (s.injured.length) lines.push(t('battle.defeat_injured', { list: s.injured.map(id => { const m = app.state.crew.find(c => c.id === id); return m ? I.crewName(m) : '?'; }).join(', ') }));
      lines.push(t('battle.defeat_keep'));
    }
    return h('div.b-menu-in.b-result.' + s.outcome,
      h('h3', { text: t(outcomeKey) }),
      h('p.small', { text: t('battle.result_time', { n: s.time, hp: I.pct(s.hpAvg) }) }),
      h('ul.small-list', lines.map(x => h('li', { text: x }))),
      closeBtn);
  }

  P.Battle = { open, eventText, rewardLines };
})(typeof globalThis !== 'undefined' ? globalThis : this);
