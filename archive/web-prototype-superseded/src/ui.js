/*
 * Project Seven Seas — DOM helpers and shared formatting for the views.
 * Everything visible is built from localization keys; no text is hard-coded.
 */
(function (root) {
  'use strict';

  const P = root.P7S;
  const I = P.I18n;
  const Art = P.Art;
  const Content = P.Content;
  const t = I.t;

  // h('div.cls#id', {attrs}, ...children)
  function h(sel, attrs, ...kids) {
    const m = /^([a-z0-9]+)?((?:[.#][\w-]+)*)$/i.exec(sel) || [];
    const el = document.createElement(m[1] || 'div');
    for (const part of (m[2] || '').match(/[.#][\w-]+/g) || []) {
      if (part[0] === '.') el.classList.add(part.slice(1)); else el.id = part.slice(1);
    }
    if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) { kids.unshift(attrs); attrs = null; }
    if (attrs) {
      for (const [k, v] of Object.entries(attrs)) {
        if (v == null || v === false) continue;
        if (k === 'on') for (const [ev, fn] of Object.entries(v)) el.addEventListener(ev, fn);
        else if (k === 'text') el.textContent = v;
        else if (k === 'class') el.className += (el.className ? ' ' : '') + v;
        else if (k === 'style' && typeof v === 'object') { for (const [sk, sv] of Object.entries(v)) { if (sv == null) continue; if (sk.startsWith('--')) el.style.setProperty(sk, String(sv)); else el.style[sk] = sv; } }
        else if (k === 'dataset') Object.assign(el.dataset, v);
        else if (k in el && typeof v !== 'string' && k !== 'list') el[k] = v;
        else el.setAttribute(k, v === true ? '' : v);
      }
    }
    append(el, kids);
    return el;
  }
  function append(el, kids) {
    for (const k of kids) {
      if (k == null || k === false) continue;
      if (Array.isArray(k)) append(el, k);
      else el.appendChild(k instanceof Node ? k : document.createTextNode(String(k)));
    }
    return el;
  }
  function clear(el) { while (el.firstChild) el.removeChild(el.firstChild); return el; }

  function icon(name, cls) { return h('img.ico' + (cls ? '.' + cls : ''), { src: Art.iconURL(name), alt: '', 'aria-hidden': 'true', draggable: false }); }
  function sprite(url, cls) { return h('img.sprite' + (cls ? '.' + cls : ''), { src: url, alt: '', draggable: false }); }

  // A button that always responds: when `reason` is set it is shown disabled
  // with an explanation instead of silently doing nothing.
  function btn(label, onClick, opts) {
    const o = opts || {};
    const b = h('button.btn' + (o.kind ? '.' + o.kind : '') + (o.small ? '.small' : ''), {
      type: 'button', title: o.reason || o.title || null, 'aria-pressed': o.pressed != null ? String(!!o.pressed) : null,
      dataset: o.data || null
    });
    if (o.icon) b.appendChild(icon(o.icon));
    b.appendChild(h('span', { text: label }));
    if (o.cost) b.appendChild(costView(o.cost, o.state));
    if (o.reason) { b.disabled = true; b.classList.add('blocked'); }
    else if (onClick) b.addEventListener('click', onClick);
    if (o.pressed) b.classList.add('on');
    return b;
  }
  function blockedNote(reasonText) { return reasonText ? h('p.note.blocked-note', icon('lock'), h('span', { text: reasonText })) : null; }

  // ------------------------------------------------------------------ costs
  const COST_ICONS = { gold: 'gold', materials: 'materials', food: 'food', supplies: 'supplies', stamina: 'stamina' };
  function costView(cost, state) {
    const wrap = h('span.cost');
    if (!cost) return wrap;
    const inv = state ? state.inventory : null;
    for (const k of ['gold', 'materials', 'food', 'supplies', 'stamina']) {
      if (!cost[k]) continue;
      const have = !state ? Infinity : k === 'stamina' ? state.ship.stamina : inv[k];
      wrap.appendChild(h('span.c' + (have < cost[k] ? '.short' : ''), { title: t('status.' + k) }, icon(COST_ICONS[k]), I.fmtNum(cost[k])));
    }
    if (cost.specialty) {
      const [id, n] = cost.specialty;
      const have = inv ? inv.specialties[id] || 0 : Infinity;
      wrap.appendChild(h('span.c.spec' + (have < n ? '.short' : ''), { title: t('spec.' + id + '.name') }, h('i.dot', { style: { background: Art.COLOR_HEX[Content.SPECIALTIES[id].color] } }), t('spec.' + id + '.name') + ' ×' + n));
    }
    if (!wrap.childNodes.length) wrap.appendChild(h('span.c.free', { text: t('ui.free') }));
    return wrap;
  }
  function canAfford(state, cost) {
    if (!cost) return true;
    const inv = state.inventory;
    for (const k of ['gold', 'materials', 'food', 'supplies']) if (cost[k] && inv[k] < cost[k]) return false;
    if (cost.stamina && state.ship.stamina < cost.stamina) return false;
    if (cost.specialty && (inv.specialties[cost.specialty[0]] || 0) < cost.specialty[1]) return false;
    return true;
  }

  // ------------------------------------------------------------- structure
  function panel(title, ...kids) {
    return h('section.panel', title ? h('h3.panel-h', typeof title === 'string' ? h('span', { text: title }) : title) : null, ...kids);
  }
  function tabs(items, active, onSelect, cls) {
    return h('div.tabs' + (cls ? '.' + cls : ''), { role: 'tablist' }, items.map(it => h('button.tab' + (it.id === active ? '.active' : '') + (it.locked ? '.locked' : ''), {
      type: 'button', role: 'tab', 'aria-selected': String(it.id === active), title: it.title || null,
      on: { click: () => onSelect(it.id) }
    }, it.icon ? icon(it.icon) : null, h('span', { text: it.label }), it.badge != null ? h('b.badge', { text: String(it.badge) }) : null)));
  }
  function bar(value, max, cls, label) {
    const pctv = max > 0 ? Math.max(0, Math.min(100, 100 * value / max)) : 0;
    return h('div.bar' + (cls ? '.' + cls : ''), { role: 'meter', 'aria-valuenow': value, 'aria-valuemax': max, title: label || null },
      h('div.fill', { style: { width: pctv + '%' } }), label ? h('span.bar-label', { text: label }) : null);
  }
  function kv(label, value, cls) { return h('div.kv' + (cls ? '.' + cls : ''), h('span.k', { text: label }), h('span.v', value instanceof Node ? value : { text: String(value) })); }
  function tag(text, cls) { return h('span.tag' + (cls ? '.' + cls : ''), { text }); }
  function empty(text) { return h('p.empty', { text }); }
  function note(text, cls) { return h('p.note' + (cls ? '.' + cls : ''), { text }); }

  function select(options, value, onChange, opts) {
    const o = opts || {};
    const s = h('select.sel', { 'aria-label': o.label || null, disabled: !!o.disabled });
    for (const op of options) {
      const el = h('option', { value: op.value == null ? '' : op.value, text: op.label, disabled: !!op.disabled });
      if ((op.value == null ? '' : op.value) === (value == null ? '' : value)) el.selected = true;
      s.appendChild(el);
    }
    s.addEventListener('change', () => onChange(s.value === '' ? null : s.value));
    return s;
  }

  // ------------------------------------------------------------ formatting
  function clockText(gameClock) {
    const day = Math.floor(gameClock / 24) + 1;
    const hour = Math.floor(gameClock % 24);
    return t('status.clock', { day, hour: String(hour).padStart(2, '0') });
  }
  const signed = n => (n > 0 ? '+' : '') + I.fmtNum(n);
  function modLines(mods) {
    const out = [];
    if (!mods) return out;
    for (const [k, v] of Object.entries(mods)) {
      if (!v) continue;
      const key = 'mod.' + k;
      if (!I.has(key)) continue;
      out.push(t(key, { pct: I.pct(v), n: I.fmtNum(v), s: I.fmtNum(v) }));
    }
    return out;
  }
  function fxLines(fx) {
    const out = [];
    for (const [k, v] of Object.entries(fx || {})) {
      if (/(Dur|Stun)$/.test(k)) continue;
      const key = 'fx.' + k;
      if (!I.has(key)) continue;
      const dur = fx[k + 'Dur'] || fx.buffDur || fx.regenDur || fx.dotDur || 0;
      out.push(t(key, { n: I.fmtNum(v), pct: I.pct(v), secs: I.fmtNum(typeof v === 'number' ? v : 0), dur: I.fmtNum(dur), stun: I.fmtNum(fx.trapStun || 1) }));
    }
    return out;
  }
  function skillText(id) {
    const sk = Content.SKILLS[id];
    if (!sk) return '';
    const parts = [t('cat.' + sk.cat), t('scope.' + sk.scope)];
    if (sk.power) parts.push(t('skill.power', { pct: I.pct(sk.power) }));
    if (sk.heal) parts.push(t('skill.heal', { pct: I.pct(sk.heal) }));
    parts.push(...fxLines(sk.fx));
    if (sk.cond) parts.push(t('skill.cond_' + sk.cond));
    parts.push(t('skill.cd', { n: I.fmtNum(sk.cd) }));
    return parts.join(' · ');
  }
  function passiveText(id) { return modLines(Content.PASSIVES[id]).join(' · '); }
  function statsLine(s) {
    return [['hp', s.hp], ['atk', s.atk], ['def', s.def], ['spd', s.spd]].filter(([, v]) => v).map(([k, v]) => t('stat.' + k + '_short') + ' ' + signed(v)).join('  ');
  }
  function itemLines(itemId, inst) {
    const it = Content.ITEMS[itemId];
    const lines = [];
    if (!it) return lines;
    const st = Object.assign({}, it.stats);
    if (inst && inst.reinforce) for (const k of ['atk', 'def', 'hp']) if (st[k]) st[k] = Math.round(st[k] * (1 + 0.1 * inst.reinforce));
    const sl = statsLine(st);
    if (sl) lines.push(sl);
    const props = (it.props || []).slice();
    if (it.wtype) for (const p of Content.WEAPON_TYPES[it.wtype].props) if (!props.includes(p)) props.unshift(p);
    for (const p of props) lines.push(t('prop.' + p));
    lines.push(...modLines(it.mods));
    for (const r of it.resist || []) lines.push(t('item.resist', { hazard: t('hazard.' + r + '.name') }));
    if (inst && inst.affix) lines.push(...modLines(Content.AFFIXES[inst.affix]));
    return lines;
  }

  P.UI = {
    h, append, clear, icon, sprite, btn, blockedNote, costView, canAfford, panel, tabs, bar, kv, tag, empty, note, select,
    clockText, signed, modLines, fxLines, skillText, passiveText, statsLine, itemLines
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
