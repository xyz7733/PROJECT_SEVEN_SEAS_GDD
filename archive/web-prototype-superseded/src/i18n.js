/*
 * Project Seven Seas — localization runtime (GDD §14).
 *
 * Game state stores only stable IDs, string keys, and parameters. This module
 * turns them into display text for the active locale. Locale tables live in
 * /locales and register themselves on P7S.LOCALES. The active locale is chosen
 * at startup; switching it restarts the game, and saves never store it.
 *
 * Parameter values that are themselves localization keys are translated
 * recursively, numbers are formatted per locale, and a few families of names
 * (set equipment, pet species, main-quest steps) are composed from smaller
 * translated parts so both languages share one structure.
 */
(function (root) {
  'use strict';

  const P = root.P7S = root.P7S || {};
  const SUPPORTED = ['en', 'zh-CN'];
  const DEFAULT = 'en';

  function registry() {
    P.LOCALES = P.LOCALES || {};
    if (typeof module !== 'undefined' && module.exports && typeof require === 'function') {
      for (const code of SUPPORTED) {
        if (!P.LOCALES[code]) {
          try { P.LOCALES[code] = require('../locales/' + code + '.js'); } catch (e) { /* browser build */ }
        }
      }
    }
    return P.LOCALES;
  }

  let code = null;
  let table = null;
  let numberFmt = null;
  const missing = new Set();

  function setLocale(c) {
    const reg = registry();
    code = SUPPORTED.includes(c) && reg[c] ? c : DEFAULT;
    table = reg[code];
    try { numberFmt = new Intl.NumberFormat(table.meta.numberLocale || code); } catch (e) { numberFmt = null; }
    return code;
  }
  function locale() { return code; }
  function meta(c) { const reg = registry(); return (reg[c || code] || reg[DEFAULT]).meta; }
  function strings() { if (!table) setLocale(DEFAULT); return table.strings; }

  function fmtNum(n) {
    if (typeof n !== 'number' || !isFinite(n)) return String(n);
    const v = Math.round(n * 100) / 100;
    return numberFmt ? numberFmt.format(v) : String(v);
  }
  function pct(x) { return fmtNum(Math.round(x * 100)) + '%'; }

  // ------------------------------------------------------------ composition
  const SET_ITEM = /^item\.(w|o)_([a-z]+)\.t(\d+)$/;
  const SPECIES = /^pet\.([a-z]+)_(companion|helper|explorer)(_evo)?\.name$/;
  const MAIN_STEP = /^quest\.([a-z_]+)\.(\d)$/;
  function compose(key, S) {
    let m = SET_ITEM.exec(key);
    if (m) {
      const typeKey = (m[1] === 'w' ? 'wtype.' : 'otype.') + m[2];
      if (S[typeKey] && S['itemtier.' + m[3]]) return fill(S['item.set_format'], { tier: S['itemtier.' + m[3]], type: S[typeKey] });
    }
    m = SPECIES.exec(key);
    if (m) {
      const fam = S['petfam.' + m[1] + '.name'], form = S['petform.' + m[2] + (m[3] ? '_evo' : '')];
      if (fam && form) return fill(S['pet.species_format'], { family: fam, form });
    }
    m = MAIN_STEP.exec(key);
    if (m) {
      const W = P.World || (typeof require === 'function' ? require('./world.js') : null);
      const q = W && W.QUESTS['main.' + m[1] + '.' + m[2]];
      if (q) {
        const itemName = q.itemId ? (S['spec.' + q.itemId + '.name'] || q.itemId) : '';
        return fill(S['qtype.' + q.type], { location: S['loc.' + q.locationId + '.name'] || q.locationId, count: fmtNum(q.count), item: itemName });
      }
    }
    return null;
  }
  function fill(tpl, params) {
    return String(tpl).replace(/\{([a-zA-Z0-9_]+)\}/g, (all, name) => (params && params[name] != null ? String(params[name]) : all));
  }

  function has(key) {
    if (typeof key !== 'string') return false;
    const S = strings();
    return Object.prototype.hasOwnProperty.call(S, key) || compose(key, S) != null;
  }
  function raw(key) {
    const S = strings();
    if (Object.prototype.hasOwnProperty.call(S, key)) return S[key];
    const c = compose(key, S);
    if (c != null) return c;
    missing.add(key);
    return null;
  }

  // Translate a key with parameters. Parameter strings that are keys are
  // translated too; numbers are locale-formatted; `crew`/`pet` params are
  // resolved through the optional context (state) to display names.
  function t(key, params, ctx, depth) {
    if (key == null) return '';
    const tpl = raw(key);
    if (tpl == null) return '⟦' + key + '⟧';
    if (!params) return tpl;
    const dp = depth || 0;
    // Parameters are resolved lazily so nested keys can reuse sibling params.
    return String(tpl).replace(/\{([a-zA-Z0-9_]+)\}/g, (all, name) =>
      (Object.prototype.hasOwnProperty.call(params, name) && params[name] != null ? param(name, params[name], ctx, params, dp) : all));
  }
  function param(name, v, ctx, all, depth) {
    if (typeof v === 'number') return fmtNum(v);
    if (typeof v === 'boolean') return v ? t('ui.yes') : t('ui.no');
    if (typeof v === 'object' && v.key) return t(v.key, v.params, ctx, depth + 1);
    if (typeof v !== 'string') return String(v);
    if (name === 'crew' && ctx && ctx.crew) {
      const m = ctx.crew.find(c => c.id === v);
      return m ? crewName(m) : t('ui.former_crew');
    }
    if (name === 'pet' && ctx && ctx.pets) {
      const pet = ctx.pets.find(x => x.id === v);
      return pet ? petName(pet) : v;
    }
    if (depth < 3 && /^[a-z][a-zA-Z0-9_]*\.[a-zA-Z0-9_.]+$/.test(v) && has(v)) {
      const sib = Object.assign({}, all);
      delete sib[name];
      return t(v, sib, ctx, depth + 1);
    }
    return v;
  }

  // ------------------------------------------------------------------ names
  function hash(s) {
    let h = 2166136261 >>> 0;
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
    return h >>> 0;
  }
  // Default crew names are derived from the stable seed by the active
  // locale's name pool, so the same sailor keeps one identity in each language.
  function crewName(m) {
    if (!m) return '';
    if (m.nickname) return m.nickname;
    const pool = (table || registry()[DEFAULT]).names;
    const s = m.seed >>> 0;
    const given = pool.given[s % pool.given.length];
    const family = pool.family[(hash(String(s)) >>> 3) % pool.family.length];
    return fill(pool.format, { given, family });
  }
  function petName(p) {
    if (!p) return '';
    return p.nickname || t('pet.' + p.speciesId + '.name');
  }
  function itemKey(itemId) {
    const C = P.Content || (typeof require === 'function' ? require('./content.js') : null);
    const it = C.ITEMS[itemId];
    if (!it) return 'ui.unknown';
    if (it.nameKey) return it.nameKey;
    return 'item.' + (it.wtype ? 'w_' + it.wtype : 'o_' + it.otype) + '.t' + it.tier;
  }
  function itemName(itemId, inst) {
    let n = t(itemKey(itemId));
    if (inst && inst.affix) n = fill(t('item.affix_format'), { affix: t('affix.' + inst.affix + '.name'), name: n });
    if (inst && inst.reinforce) n += ' +' + inst.reinforce;
    return n;
  }
  function reason(r) {
    if (!r) return '';
    return t(r.reasonKey || 'err.unknown', r.reasonParams);
  }
  function logLine(entry, ctx) { return t(entry.key, entry.params, ctx); }

  // ------------------------------------------------------------- validation
  function keys(c) { const reg = registry(); return reg[c] ? Object.keys(reg[c].strings) : []; }
  function missingKeys() { return [...missing]; }

  const I18n = {
    SUPPORTED, DEFAULT, setLocale, locale, meta, has, raw, t, fill, fmtNum, pct,
    crewName, petName, itemKey, itemName, reason, logLine, keys, missingKeys, registry
  };
  P.I18n = I18n;
  if (typeof module !== 'undefined' && module.exports) module.exports = I18n;
})(typeof globalThis !== 'undefined' ? globalThis : this);
