/*
 * Project Seven Seas — deterministic automatic combat (GDD §8).
 * One engine serves island, dungeon, trial, monster, and boarding fights.
 * Same spec + same command list => identical result, so a reload cannot
 * reroll an encounter. Commands are recorded with the tick they apply on.
 */
(function (root) {
  'use strict';

  const P = root.P7S || {};
  const Content = P.Content || require('./content.js');
  const World = P.World || require('./world.js');
  const T = Content.TUNING;
  const DT = T.battleTick;
  const LIMIT_TICKS = Math.round(T.battleTimeLimit / DT);
  const LANES = Content.FORMATION_LANES;

  function rngFrom(seed) {
    let s = seed >>> 0;
    return function () {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  const PRIORITY_ORDER = {
    survival: ['survival', 'support', 'control', 'damage'],
    control: ['control', 'damage', 'support', 'survival'],
    damage: ['damage', 'control', 'support', 'survival'],
    support: ['support', 'survival', 'control', 'damage']
  };
  const STANCE = {
    aggressive: { dealt: 1.15, taken: 1.1, heal: 0.55, dodge: 0 },
    balanced: { dealt: 1, taken: 1, heal: 0.7, dodge: 0 },
    defensive: { dealt: 0.85, taken: 0.8, heal: 0.85, dodge: 0.05 },
    escape: { dealt: 0.6, taken: 0.9, heal: 0.8, dodge: 0.15 }
  };

  // ------------------------------------------------------------- unit setup
  function makeStatus() {
    return { stun: 0, slow: 0, mark: 0, taunt: 0, evade: 0, shield: 0, buffAtk: 0, buffAtkT: 0, buffDef: 0, buffDefT: 0, regen: 0, regenT: 0, dot: 0, dotT: 0, sunder: 0, sunderT: 0 };
  }
  function allyUnit(a, i) {
    const s = a.stats;
    return {
      uid: 'a' + i, side: 'ally', key: a.key, defId: a.classId, nameKey: a.nameKey || null, name: a.name || null, level: a.level,
      lane: a.lane, slot: a.slot, range: s.range, maxHp: s.hp, hp: Math.max(1, Math.round(s.hp * (a.hpRatio == null ? 1 : a.hpRatio))),
      atk: s.atk, def: s.def, spd: s.spd, crit: s.crit, dodge: s.dodge, mods: s.mods || {}, props: s.props || [], resist: s.resist || [],
      skills: (s.skills || []).map(id => ({ id, cd: 0 })), roles: s.roles || [], meter: 0, st: makeStatus(), alive: true,
      boss: false, decoy: false, pet: a.pet ? Object.assign({ timer: 3 }, a.pet) : null, firstAidUsed: false, windup: null,
      dealt: 0, healed: 0
    };
  }
  function enemyUnit(e, i, wave, partyLevel) {
    const def = World.enemy(e.enemyId);
    const arch = Content.ENEMY_ARCHETYPES[def.archetype];
    const g = T.enemyGrowth;
    const sc = T.enemyScale;
    const L = Math.max(1, e.level);
    const gap = Math.max(0.55, Math.min(2.2, 1 + T.levelGap * (L - (partyLevel || L))));
    const m = (def.mult || 1) * gap * (1 + (sc.perLevel || 0) * (L - 1));
    const hp = Math.round(arch.base.hp * sc.hp * (1 + g.hp * (L - 1)) * m);
    return {
      uid: 'e' + wave + '_' + i, side: 'enemy', key: e.enemyId, defId: e.enemyId, nameKey: 'enemy.' + e.enemyId + '.name', level: L,
      archetype: def.archetype, lane: arch.lane, range: arch.range, maxHp: hp, hp,
      atk: Math.round(arch.base.atk * sc.atk * (1 + g.atk * (L - 1)) * m * (e.atkMult || 1)), def: Math.round(arch.base.def * sc.def * (1 + g.def * (L - 1)) * (def.mult || 1)),
      spd: arch.base.spd + g.spd * (L - 1) * (arch.base.spd ? 1 : 0), crit: 0.05, dodge: def.archetype === 'skirmisher' ? 0.05 : 0,
      mods: { regenPct: def.regen || 0 }, props: def.burn ? ['burn'] : [], resist: [], skills: def.skills.map(id => ({ id, cd: 2 + i })),
      roles: [], meter: 0, st: makeStatus(), alive: true, boss: !!def.boss, decoy: !!def.decoy, rival: !!def.rival, pet: null, windup: null,
      dealt: 0, healed: 0
    };
  }

  // spec: { allies:[{key, classId, level, slot, lane, stats, pet, hpRatio}], waves, modifiers, seed, stance, priority, bonuses }
  function create(spec) {
    const sim = {
      spec, tick: 0, rng: rngFrom(spec.seed || 1), wave: 0, allies: spec.allies.map(allyUnit), enemies: [],
      stance: spec.stance || 'balanced', priority: spec.priority || 'auto', focus: null, retreating: 0, outcome: null,
      commands: [], cmdIndex: 0, log: [], logSeq: 0, defeated: [], plunder: 0, trap: null, encored: false,
      mods: new Set(spec.modifiers || []), seqUid: 0,
      partyLevel: spec.allies.length ? spec.allies.reduce((a, u) => a + u.level, 0) / spec.allies.length : 1
    };
    const b = spec.bonuses || {};
    for (const u of sim.allies) {
      u.meter = Math.min(95, (b.startMeter || 0) + (u.mods.quickStart || 0));
      if (b.frontShield && u.lane === 'front') u.st.shield += Math.round(u.maxHp * b.frontShield);
    }
    const teamShield = Math.max(0, ...sim.allies.map(u => u.mods.teamShield || 0));
    if (teamShield) for (const u of sim.allies) u.st.shield += Math.round(u.maxHp * teamShield);
    spawnWave(sim, 0);
    return sim;
  }
  function spawnWave(sim, w) {
    sim.wave = w;
    sim.enemies = sim.spec.waves[w].map((e, i) => enemyUnit(e, i, w, sim.partyLevel));
    sim.focus = null;
    pushLog(sim, { type: 'wave', wave: w + 1 });
  }
  function pushLog(sim, ev) {
    ev.tick = sim.tick; ev.seq = ++sim.logSeq;
    sim.log.push(ev);
    if (sim.log.length > 80) sim.log.shift();
  }

  // --------------------------------------------------------------- helpers
  const living = list => list.filter(u => u.alive);
  function hazardActive(sim, u, h) {
    if (u.side !== 'ally') return false;
    if (u.mods.hazardResist || u.resist.includes(h)) return false;
    return true;
  }
  function hazards(sim) { return [...sim.mods].filter(m => Content.HAZARDS[m]); }
  function hazardScale(sim) { return sim.mods.has('legend_double_hazard') ? 2 : 1; }
  function auraMax(sim, side, key) {
    let v = 0;
    for (const u of living(side === 'ally' ? sim.allies : sim.enemies)) v = Math.max(v, (u.mods[key] || 0) + (key === 'auraAtk' && u.props.includes('aura') ? 0.06 : 0));
    return v;
  }
  function laneOrder(list) {
    const occupied = LANES.filter(l => list.some(u => u.alive && u.lane === l));
    return occupied;
  }
  function reachable(attacker, foes, skill) {
    const alive = living(foes);
    if (!alive.length) return [];
    const fx = (skill && skill.fx) || {};
    if (attacker.range === 'ranged' || fx.reachAll || fx.snipe) return alive;
    const lanes = laneOrder(foes);
    const n = attacker.range === 'reach' ? 2 : 1;
    const allowed = lanes.slice(0, n);
    return alive.filter(u => allowed.includes(u.lane));
  }
  function hpRatio(u) { return u.hp / u.maxHp; }
  function lowest(list) { let b = null; for (const u of list) if (!b || hpRatio(u) < hpRatio(b)) b = u; return b; }
  function frontLane(list) { const l = laneOrder(list)[0]; return living(list).filter(u => u.lane === l); }

  function pickEnemyTarget(sim, src, skill) {
    const pool = reachable(src, sim.enemies, skill);
    if (!pool.length) return null;
    if (sim.focus) { const f = pool.find(u => u.uid === sim.focus); if (f) return f; }
    const taunt = pool.find(u => u.st.taunt > 0); if (taunt) return taunt;
    const decoy = pool.find(u => u.decoy);
    if (decoy && sim.rng() < 0.7) return decoy;
    const nonDecoy = pool.filter(u => !u.decoy);
    const fx = (skill && skill.fx) || {};
    if (fx.snipe) {
      const pri = nonDecoy.find(u => u.archetype === 'healer') || nonDecoy.find(u => u.archetype === 'caster');
      if (pri) return pri;
    }
    const marked = nonDecoy.find(u => u.st.mark > 0); if (marked) return marked;
    return lowest(nonDecoy.length ? nonDecoy : pool);
  }
  function pickAllyTarget(sim, src, skill) {
    const pool = reachable(src, sim.allies, skill);
    if (!pool.length) return null;
    const taunt = pool.find(u => u.st.taunt > 0); if (taunt) return taunt;
    if (src.boss || src.archetype === 'shooter') return lowest(pool);
    return pool[Math.floor(sim.rng() * pool.length)];
  }

  // ----------------------------------------------------------- damage/heal
  function dealDamage(sim, src, tgt, power, opts) {
    const o = opts || {};
    if (!tgt || !tgt.alive) return 0;
    if (src.side === 'enemy' && tgt.side === 'ally' && tgt.lane !== 'front' && !o.noIntercept) {
      let best = null;
      for (const g of living(sim.allies)) {
        if (g === tgt || g.lane !== 'front') continue;
        const c = (g.mods.intercept || 0) + (g.mods.guard || 0);
        if (c > 0 && (!best || c > best.c)) best = { g, c };
      }
      if (best && sim.rng() < best.c) { pushLog(sim, { type: 'intercept', src: best.g.uid, tgt: tgt.uid }); tgt = best.g; }
    }
    const stanceA = STANCE[sim.stance];
    let dodge = tgt.dodge + (tgt.st.evade > 0 ? 0.5 : 0);
    if (tgt.side === 'ally') dodge += stanceA.dodge + auraMax(sim, 'ally', 'auraDodge');
    if (!o.noDodge && dodge > 0 && sim.rng() < Math.min(0.75, dodge)) { pushLog(sim, { type: 'miss', src: src.uid, tgt: tgt.uid }); return 0; }
    const atkBuff = 1 + src.st.buffAtk + (src.side === 'ally' ? auraMax(sim, 'ally', 'auraAtk') : 0);
    let atk = src.atk * atkBuff;
    const ignore = Math.min(0.8, (src.mods.defIgnore || 0) + (o.pierce || 0) + (src.props.includes('pierce') ? 0.25 : 0));
    const def = Math.max(0, tgt.def * (1 + tgt.st.buffDef) * (1 - 0.08 * tgt.st.sunder) * (1 - ignore));
    const K = 40 + 6 * tgt.level;
    let dmg = atk * power * K / (K + def);
    let crit = false;
    if (sim.rng() < src.crit) { dmg *= 1.5; crit = true; }
    if (tgt.boss) dmg *= 1 + (src.mods.bossDmg || 0) + (o.boss || 0);
    if (tgt.st.mark > 0) dmg *= 1.2 + (src.mods.markedDmg || 0);
    if (src.side === 'ally') {
      if (sim.focus === tgt.uid) dmg *= 1.15 + (src.mods.focusDmg || 0);
      dmg *= stanceA.dealt;
      if (sim.mods.has('glare') && hazardActive(sim, src, 'glare')) dmg *= Content.HAZARDS.glare.dealtMult;
      if (sim.retreating > 0) dmg *= 0.5;
    } else {
      dmg *= stanceA.taken;
      if (sim.mods.has('pressure') && hazardActive(sim, tgt, 'pressure')) dmg *= Content.HAZARDS.pressure.takenMult;
      if (sim.spec.bonuses && sim.spec.bonuses.boardingTaken) dmg *= 1 - sim.spec.bonuses.boardingTaken;
    }
    if (o.execute && hpRatio(tgt) < 0.3) dmg *= 1 + o.execute;
    dmg = Math.max(1, Math.round(dmg));
    let absorbed = 0;
    if (tgt.st.shield > 0) { absorbed = Math.min(tgt.st.shield, dmg); tgt.st.shield -= absorbed; }
    const net = dmg - absorbed;
    tgt.hp -= net;
    src.dealt += dmg;
    pushLog(sim, { type: 'hit', src: src.uid, tgt: tgt.uid, amount: dmg, crit, skill: o.skill || null, absorbed });
    if (tgt.mods.thorns && src.range !== 'ranged' && src.alive) {
      const r = Math.max(1, Math.round(dmg * tgt.mods.thorns));
      src.hp -= r; pushLog(sim, { type: 'thorns', src: tgt.uid, tgt: src.uid, amount: r });
      checkDeath(sim, src);
    }
    if (src.mods.lifesteal) heal(sim, src, src, dmg * src.mods.lifesteal, { quiet: true });
    if (src.side === 'enemy' && sim.trap && src.alive) {
      const tr = sim.trap; sim.trap = null;
      src.hp -= tr.dmg; applyStun(sim, src, tr.stun);
      pushLog(sim, { type: 'trap', tgt: src.uid, amount: tr.dmg });
      checkDeath(sim, src);
    }
    checkDeath(sim, tgt);
    if (tgt.alive && tgt.side === 'ally' && tgt.mods.firstAid && !tgt.firstAidUsed && hpRatio(tgt) < 0.35) {
      tgt.firstAidUsed = true; heal(sim, tgt, tgt, tgt.maxHp * tgt.mods.firstAid, { force: true });
    }
    return net;
  }
  function heal(sim, src, tgt, amount, opts) {
    const o = opts || {};
    if (!tgt || !tgt.alive) return 0;
    if (tgt.side === 'ally' && sim.mods.has('legend_no_healing') && !o.force) return 0;
    const amt = Math.round(amount * (1 + (src.mods.healPct || 0)));
    const real = Math.min(tgt.maxHp - tgt.hp, amt);
    if (real <= 0) return 0;
    tgt.hp += real;
    src.healed += real;
    if (!o.quiet) pushLog(sim, { type: 'heal', src: src.uid, tgt: tgt.uid, amount: real });
    return real;
  }
  function applyStun(sim, u, secs) {
    if (!u.alive || u.decoy) return;
    if (u.mods.stunImmune) { pushLog(sim, { type: 'resist', tgt: u.uid }); return; }
    const d = u.boss ? secs * 0.5 : secs;
    u.st.stun = Math.max(u.st.stun, d);
    if (u.windup) { pushLog(sim, { type: 'interrupt', tgt: u.uid, skill: u.windup.skill }); u.windup = null; }
    pushLog(sim, { type: 'stun', tgt: u.uid, secs: d });
  }
  function checkDeath(sim, u) {
    if (u.alive && u.hp <= 0) {
      u.hp = 0; u.alive = false; u.windup = null;
      pushLog(sim, { type: 'ko', tgt: u.uid });
      if (u.side === 'enemy') sim.defeated.push(u.key);
      if (sim.focus === u.uid) sim.focus = null;
    }
  }
  function cleanse(u) { u.st.stun = 0; u.st.slow = 0; u.st.dot = 0; u.st.dotT = 0; u.st.mark = 0; u.st.sunder = 0; }

  // ----------------------------------------------------------------- skills
  function healThreshold(sim) {
    let t = STANCE[sim.stance].heal;
    if (sim.priority === 'damage') t = Math.min(t, 0.5);
    if (sim.priority === 'support' || sim.priority === 'survival') t = Math.max(t, 0.8);
    return t;
  }
  function friendsOf(sim, u) { return u.side === 'ally' ? sim.allies : sim.enemies; }
  function foesOf(sim, u) { return u.side === 'ally' ? sim.enemies : sim.allies; }
  function skillUsable(sim, u, sk) {
    const def = Content.SKILLS[sk.id];
    if (!def || sk.cd > 0) return false;
    const fx = def.fx || {};
    const friends = living(friendsOf(sim, u));
    if (def.heal) {
      if (u.side === 'ally' && sim.mods.has('legend_no_healing')) return !!(fx.buffAtk || fx.cleanse);
      const thr = def.cond === 'critical' ? 0.35 : (u.side === 'ally' ? healThreshold(sim) : 0.6);
      return friends.some(f => hpRatio(f) < thr);
    }
    if (fx.pet && !u.pet) return false;
    if (def.cat === 'survival' && (fx.shield || fx.taunt || fx.evade || fx.buffDef)) {
      const lim = u.side === 'ally' && sim.stance === 'defensive' ? 0.97 : 0.85;
      if (def.scope === 'self') return hpRatio(u) < lim || u.lane === 'front';
      return friends.some(f => hpRatio(f) < lim);
    }
    if (u.side === 'ally' && sim.retreating > 0 && def.cat !== 'survival' && def.cat !== 'support') return false;
    if (def.scope === 'enemy' || def.scope === 'enemy_lane') return !!(u.side === 'ally' ? pickEnemyTargetPreview(sim, u, def) : reachable(u, sim.allies, def).length);
    return true;
  }
  function pickEnemyTargetPreview(sim, u, def) { return reachable(u, sim.enemies, def).length > 0; }
  function chooseSkill(sim, u) {
    const ready = u.skills.filter(sk => skillUsable(sim, u, sk));
    if (!ready.length) return null;
    if (u.side === 'enemy') return ready[0];
    let order;
    if (sim.priority === 'auto') {
      const friends = living(sim.allies);
      const danger = friends.some(f => hpRatio(f) < 0.45);
      const windup = living(sim.enemies).some(e => e.windup);
      order = danger ? ['survival', 'support', 'control', 'damage'] : windup ? ['control', 'damage', 'support', 'survival'] : ['damage', 'control', 'support', 'survival'];
      if (sim.stance === 'defensive') order = ['survival', 'support', 'control', 'damage'];
    } else order = PRIORITY_ORDER[sim.priority];
    if (sim.retreating > 0) order = ['survival', 'support', 'control', 'damage'];
    for (const cat of order) {
      const pick = ready.find(sk => {
        const d = Content.SKILLS[sk.id];
        if (cat === 'control' && windupInterrupt(sim) && !(d.fx && d.fx.stun)) return false;
        return d.cat === cat;
      });
      if (pick) return pick;
    }
    return ready[0];
  }
  function windupInterrupt(sim) { return living(sim.enemies).some(e => e.windup); }

  function cast(sim, u, sk) {
    const def = Content.SKILLS[sk.id];
    const fx = def.fx || {};
    sk.cd = def.cd * (1 - (u.mods.cdr || 0));
    if (fx.windup && !u.windup) {
      const tgt = u.side === 'enemy' ? pickAllyTarget(sim, u, def) : pickEnemyTarget(sim, u, def);
      if (!tgt) return;
      u.windup = { skill: sk.id, left: fx.windup, target: tgt.uid };
      pushLog(sim, { type: 'windup', src: u.uid, skill: sk.id, tgt: tgt.uid });
      return;
    }
    pushLog(sim, { type: 'skill', src: u.uid, skill: sk.id });
    resolveSkill(sim, u, def, sk.id, null);
  }
  function unitByUid(sim, uid) { return sim.allies.find(x => x.uid === uid) || sim.enemies.find(x => x.uid === uid) || null; }
  function resolveSkill(sim, u, def, skillId, fixedTarget) {
    const fx = def.fx || {};
    const foes = foesOf(sim, u);
    const friends = friendsOf(sim, u);
    let targets = [];
    if (def.scope === 'enemy') {
      let t = fixedTarget && fixedTarget.alive ? fixedTarget : (u.side === 'ally' ? pickEnemyTarget(sim, u, def) : pickAllyTarget(sim, u, def));
      if (t) targets = [t];
    } else if (def.scope === 'enemy_lane') {
      const t = u.side === 'ally' ? pickEnemyTarget(sim, u, def) : pickAllyTarget(sim, u, def);
      if (t) targets = living(foes).filter(x => x.lane === t.lane);
    } else if (def.scope === 'enemies') targets = living(foes);
    else if (def.scope === 'ally') targets = [lowest(living(friends))];
    else if (def.scope === 'allies') targets = living(friends);
    else if (def.scope === 'front_allies') targets = frontLane(friends);
    else if (def.scope === 'self') targets = [u];
    targets = targets.filter(Boolean);
    let power = def.power || 0;
    if (fx.pet && u.pet) power *= fx.pet * u.pet.mult;
    for (const t of targets) {
      const hostile = t.side !== u.side;
      if (hostile && power > 0) dealDamage(sim, u, t, power, { skill: skillId, pierce: fx.pierce, execute: fx.execute, boss: fx.boss });
      if (!t.alive && hostile) continue;
      if (def.heal && !hostile) heal(sim, u, t, def.heal * u.atk);
      const ctrl = 1 + (u.mods.controlPct || 0);
      if (hostile) {
        if (fx.stun) applyStun(sim, t, fx.stun * ctrl);
        if (fx.slow && !t.decoy) t.st.slow = Math.max(t.st.slow, fx.slow * ctrl);
        if (fx.mark) t.st.mark = Math.max(t.st.mark, fx.mark);
        if (fx.sunder) { t.st.sunder = Math.min(3, t.st.sunder + 2); t.st.sunderT = fx.sunder; }
        if (fx.dot) { t.st.dot = Math.max(t.st.dot, fx.dot * u.atk); t.st.dotT = fx.dotDur || 4; }
        if (fx.dispel) { t.st.shield = 0; t.st.buffAtk = 0; t.st.buffDef = 0; t.st.regen = 0; }
      } else {
        const hb = 1 + (u.mods.healPct || 0);
        if (fx.shield && !(u.side === 'ally' && sim.mods.has('legend_no_healing'))) t.st.shield += Math.round(fx.shield * t.maxHp * hb);
        if (fx.shield && u.side === 'ally' && sim.mods.has('legend_no_healing')) t.st.shield += Math.round(fx.shield * 0.5 * t.maxHp);
        if (fx.taunt) t.st.taunt = Math.max(t.st.taunt, fx.taunt);
        if (fx.evade) t.st.evade = Math.max(t.st.evade, fx.evade);
        if (fx.buffAtk) { t.st.buffAtk = Math.max(t.st.buffAtk, fx.buffAtk); t.st.buffAtkT = fx.buffDur || 5; }
        if (fx.buffDef) { t.st.buffDef = Math.max(t.st.buffDef, fx.buffDef); t.st.buffDefT = fx.buffDur || 5; }
        if (fx.regen) { t.st.regen = fx.regen; t.st.regenT = fx.regenDur || 5; }
        if (fx.meter) t.meter = Math.min(99, t.meter + fx.meter);
        if (fx.cleanse) cleanse(t);
        if (fx.trap) sim.trap = { dmg: Math.round(u.atk * fx.trap), stun: fx.trapStun || 1 };
      }
    }
    if (fx.cleanseAllies) for (const f of living(friends)) cleanse(f);
    if (fx.plunder && targets.length) sim.plunder += Math.round(2 + 1.5 * targets[0].level);
    if (fx.pet && u.pet) u.pet.timer = 0;
  }

  // Basic action, shaped by the equipped weapon's properties (GDD §7.6).
  function basicAttack(sim, u) {
    const friends = living(friendsOf(sim, u));
    if (u.side === 'ally' && u.props.includes('mend') && !sim.mods.has('legend_no_healing')) {
      const low = lowest(friends);
      if (low && hpRatio(low) < healThreshold(sim)) { heal(sim, u, low, 0.9 * u.atk); return; }
    }
    if (u.side === 'ally' && sim.retreating > 0) return;
    const tgt = u.side === 'ally' ? pickEnemyTarget(sim, u, null) : pickAllyTarget(sim, u, null);
    if (!tgt) return;
    if (u.props.includes('double')) {
      dealDamage(sim, u, tgt, 0.6);
      if (tgt.alive) dealDamage(sim, u, tgt, 0.6);
    } else dealDamage(sim, u, tgt, 1);
    if (u.props.includes('splash')) for (const o of living(foesOf(sim, u))) if (o !== tgt && o.lane === tgt.lane) dealDamage(sim, u, o, 0.35, { noDodge: true });
    if (u.props.includes('sunder') && tgt.alive) { tgt.st.sunder = Math.min(3, tgt.st.sunder + 1); tgt.st.sunderT = 6; }
    if (u.props.includes('chill') && tgt.alive && !tgt.decoy) tgt.st.slow = Math.max(tgt.st.slow, 1);
    if (u.props.includes('burn') && tgt.alive && !(tgt.resist.includes('heat') || tgt.mods.hazardResist)) { tgt.st.dot = Math.max(tgt.st.dot, 0.15 * u.atk); tgt.st.dotT = 3; }
    if (u.props.includes('nourish') && !sim.mods.has('legend_no_healing')) { const low = lowest(friends); if (low) heal(sim, u, low, 0.35 * u.atk, { quiet: true }); }
  }

  // Companion pet acts on its own timer (GDD §9.5).
  function petAct(sim, u) {
    const p = u.pet;
    const ab = Content.PET_ABILITIES[p.ability];
    const fx = ab.fx || {};
    const base = u.atk * p.mult;
    pushLog(sim, { type: 'pet', src: u.uid, ability: p.ability });
    if (ab.target === 'owner') {
      if (ab.heal) heal(sim, u, lowest(living(sim.allies)), ab.heal * base);
      if (ab.shield) u.st.shield += Math.round(ab.shield * u.maxHp * Math.min(2, p.mult));
      if (fx.taunt) u.st.taunt = Math.max(u.st.taunt, fx.taunt);
      return;
    }
    if (ab.target === 'allies') {
      for (const a of living(sim.allies)) {
        if (ab.heal) heal(sim, u, a, ab.heal * base, { quiet: true });
        if (fx.meter) a.meter = Math.min(99, a.meter + fx.meter * Math.min(2, p.mult));
      }
      return;
    }
    const tgt = pickEnemyTarget(sim, Object.assign({}, u, { range: 'ranged' }), null);
    if (!tgt) return;
    if (ab.power) dealDamage(sim, u, tgt, ab.power * p.mult, { noDodge: true, skill: 'pet_' + p.ability });
    if (!tgt.alive) return;
    if (fx.slow) tgt.st.slow = Math.max(tgt.st.slow, fx.slow);
    if (fx.stun) applyStun(sim, tgt, fx.stun);
    if (fx.mark) tgt.st.mark = Math.max(tgt.st.mark, fx.mark);
    if (fx.dot) { tgt.st.dot = Math.max(tgt.st.dot, fx.dot * base); tgt.st.dotT = fx.dotDur; }
  }

  // ------------------------------------------------------------------ ticks
  function applyCommand(sim, cmd) {
    if (cmd.type === 'focus') {
      const t = sim.enemies.find(e => e.uid === cmd.value && e.alive);
      sim.focus = t ? t.uid : null;
    } else if (cmd.type === 'stance' && STANCE[cmd.value]) sim.stance = cmd.value;
    else if (cmd.type === 'priority' && (cmd.value === 'auto' || PRIORITY_ORDER[cmd.value])) sim.priority = cmd.value;
    else if (cmd.type === 'retreat' && !sim.retreating) {
      let secs = (sim.spec.retreatSecs || 3);
      if (sim.allies.some(a => a.alive && a.mods.escape)) secs *= 0.5;
      if (sim.stance === 'escape') secs *= 0.67;
      sim.retreating = Math.max(DT, secs);
    }
    pushLog(sim, { type: 'command', cmd: cmd.type, value: cmd.value });
  }
  // Record a command for the current tick (applied before the tick advances).
  function issue(sim, type, value) {
    if (sim.outcome) return false;
    const cmd = { tick: sim.tick, type, value: value == null ? null : value };
    sim.commands.push(cmd);
    return true;
  }

  function updateStatus(sim, u) {
    const st = u.st;
    for (const k of ['stun', 'slow', 'mark', 'taunt', 'evade']) if (st[k] > 0) st[k] = Math.max(0, st[k] - DT);
    if (st.buffAtkT > 0) { st.buffAtkT -= DT; if (st.buffAtkT <= 0) st.buffAtk = 0; }
    if (st.buffDefT > 0) { st.buffDefT -= DT; if (st.buffDefT <= 0) st.buffDef = 0; }
    if (st.sunderT > 0) { st.sunderT -= DT; if (st.sunderT <= 0) st.sunder = 0; }
    const sec = sim.tick % 10 === 0;
    if (sec && st.regenT > 0) { heal(sim, u, u, st.regen * u.maxHp, { quiet: true }); st.regenT -= 1; if (st.regenT <= 0) st.regen = 0; }
    if (sec && st.dotT > 0 && u.alive) { u.hp -= Math.max(1, Math.round(st.dot)); st.dotT -= 1; if (st.dotT <= 0) st.dot = 0; pushLog(sim, { type: 'dot', tgt: u.uid, amount: Math.round(st.dot) }); checkDeath(sim, u); }
    if (sec && u.mods.regenPct && u.alive) heal(sim, u, u, u.mods.regenPct * u.maxHp, { quiet: true, force: true });
    for (const sk of u.skills) if (sk.cd > 0) sk.cd = Math.max(0, sk.cd - DT);
  }
  function applyHazards(sim) {
    const sc = hazardScale(sim);
    for (const h of hazards(sim)) {
      const H = Content.HAZARDS[h];
      if (!H.every) continue;
      const period = Math.round(H.every / DT / (sc > 1 ? 1.5 : 1));
      if (sim.tick === 0 || sim.tick % period !== 0) continue;
      const victims = living(sim.allies).filter(u => hazardActive(sim, u, h));
      if (!victims.length) continue;
      pushLog(sim, { type: 'hazard', hazard: h });
      for (const u of victims) {
        if (H.dmgPct) { u.hp -= Math.max(1, Math.round(u.maxHp * H.dmgPct * sc)); checkDeath(sim, u); }
        if (H.slow) u.st.slow = Math.max(u.st.slow, H.slow);
      }
      if (H.stunRandom) { const v = living(victims); if (v.length) applyStun(sim, v[Math.floor(sim.rng() * v.length)], H.stunRandom * sc); }
    }
  }
  function speedMult(sim, u) {
    let k = u.st.slow > 0 ? 0.6 : 1;
    if (sim.mods.has('tide') && hazardActive(sim, u, 'tide')) k *= Content.HAZARDS.tide.spdMult;
    return k;
  }

  function step(sim) {
    if (sim.outcome) return sim;
    while (sim.cmdIndex < sim.commands.length && sim.commands[sim.cmdIndex].tick <= sim.tick) applyCommand(sim, sim.commands[sim.cmdIndex++]);
    sim.tick++;
    applyHazards(sim);
    const auraRegen = Math.max(0, ...living(sim.allies).map(u => u.mods.auraRegen || 0));
    const units = living(sim.allies).concat(living(sim.enemies));
    for (const u of units) {
      if (!u.alive) continue;
      updateStatus(sim, u);
      if (!u.alive) continue;
      if (auraRegen && u.side === 'ally' && sim.tick % 10 === 0) heal(sim, u, u, auraRegen * u.maxHp, { quiet: true });
      if (u.st.stun > 0 || u.decoy) continue;
      if (u.windup) {
        u.windup.left -= DT;
        if (u.windup.left <= 0) {
          const w = u.windup; u.windup = null;
          const def = Content.SKILLS[w.skill];
          pushLog(sim, { type: 'skill', src: u.uid, skill: w.skill });
          resolveSkill(sim, u, def, w.skill, unitByUid(sim, w.target));
        }
        continue;
      }
      if (u.pet && u.alive && sim.retreating <= 0) {
        const interval = (u.pet.evolved ? 6 : 7) - (u.props.includes('pet') ? 1 : 0);
        u.pet.timer += DT;
        if (u.pet.timer >= interval) { u.pet.timer = 0; petAct(sim, u); }
      }
      u.meter += (40 + u.spd * 4) * DT * speedMult(sim, u);
      if (u.meter >= 100) {
        u.meter -= 100;
        const sk = chooseSkill(sim, u);
        if (sk) cast(sim, u, sk); else basicAttack(sim, u);
      }
      if (endCheck(sim)) return sim;
    }
    if (sim.retreating > 0) {
      sim.retreating -= DT;
      if (sim.retreating <= 1e-9) { finish(sim, 'retreat'); return sim; }
    }
    endCheck(sim);
    if (!sim.outcome && sim.tick >= LIMIT_TICKS) finish(sim, 'defeat', 'timeout');
    return sim;
  }
  function endCheck(sim) {
    if (sim.outcome) return true;
    if (!living(sim.allies).length) { finish(sim, 'defeat'); return true; }
    if (!living(sim.enemies).filter(e => !e.decoy).length) {
      if (sim.wave + 1 < sim.spec.waves.length) {
        for (const a of living(sim.allies)) heal(sim, a, a, a.maxHp * 0.1, { quiet: true, force: true });
        spawnWave(sim, sim.wave + 1);
        return false;
      }
      if (sim.mods.has('legend_encore') && !sim.encored) {
        sim.encored = true;
        const last = sim.spec.waves[sim.spec.waves.length - 1];
        const cap = last.filter(e => World.enemy(e.enemyId).rival);
        sim.enemies = (cap.length ? cap : last.slice(0, 1)).map((e, i) => enemyUnit(Object.assign({}, e, { atkMult: 1.2 }), i, 'x', sim.partyLevel));
        pushLog(sim, { type: 'encore' });
        return false;
      }
      finish(sim, 'victory');
      return true;
    }
    return false;
  }
  function finish(sim, outcome, reason) {
    sim.outcome = outcome;
    sim.reason = reason || null;
    pushLog(sim, { type: 'end', outcome });
  }

  function result(sim) {
    return {
      outcome: sim.outcome, reason: sim.reason, ticks: sim.tick, time: Math.round(sim.tick * DT * 10) / 10, wave: sim.wave + 1, waves: sim.spec.waves.length,
      koAllies: sim.allies.filter(a => !a.alive).map(a => a.key),
      allyHp: Object.fromEntries(sim.allies.map(a => [a.key, Math.round(100 * a.hp / a.maxHp) / 100])),
      enemiesDefeated: sim.defeated.slice(), plunder: sim.plunder,
      dealt: Object.fromEntries(sim.allies.map(a => [a.key, a.dealt])), healed: Object.fromEntries(sim.allies.map(a => [a.key, a.healed]))
    };
  }
  // Replay a full battle from a spec and a command list.
  function run(spec, commands, untilTick) {
    const sim = create(spec);
    sim.commands = (commands || []).slice().sort((a, b) => a.tick - b.tick);
    const stop = untilTick == null ? Infinity : untilTick;
    while (!sim.outcome && sim.tick < stop) step(sim);
    return sim;
  }
  function resolve(spec, commands) { return result(run(spec, commands)); }

  const Combat = { DT, LIMIT_TICKS, STANCE, PRIORITY_ORDER, create, step, issue, run, resolve, result, reachable, rngFrom };
  root.P7S = root.P7S || {};
  root.P7S.Combat = Combat;
  if (typeof module !== 'undefined' && module.exports) module.exports = Combat;
})(typeof globalThis !== 'undefined' ? globalThis : this);
