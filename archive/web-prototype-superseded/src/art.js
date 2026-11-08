/*
 * Project Seven Seas — generated placeholder pixel art.
 * Every sprite is drawn at runtime from small bitmaps or seeded rules, so the
 * project ships no image assets. No text is ever baked into art (GDD §13.5).
 */
(function (root) {
  'use strict';

  const PAL = {
    k: '#1a1c2c', w: '#f4f4f4', y: '#ffcd4a', o: '#e0892a', r: '#d8434a', p: '#f08aa0',
    g: '#5cbf5a', G: '#2e8a4a', b: '#3b7dd8', B: '#24508f', c: '#73d2f0', n: '#a8683a',
    N: '#6a3c1e', s: '#c2c8d6', S: '#6c7486', v: '#9b6ad8', t: '#f2d2a9', e: '#e9d58f'
  };

  const ICONS = {
    gold:      ['..kkkk..', '.kyyyyk.', 'kyywyyok', 'kywyyyok', 'kyyyyyok', 'kyyyyook', '.kooook.', '..kkkk..'],
    food:      ['........', '..kkkkk.', '.koooook', 'koyoyook', 'kooooook', 'kooooook', '.kkkkkk.', '........'],
    stamina:   ['....kkkk', '...kyyyk', '..kyyyk.', '.kyyyykk', 'kkkyyyk.', '..kyyk..', '.kyyk...', '.kkk....'],
    supplies:  ['kkkkkkkk', 'knnnnnnk', 'kNnnnnNk', 'knNnnNnk', 'knnNNnnk', 'knNnnNnk', 'kNnnnnNk', 'kkkkkkkk'],
    materials: ['........', 'kkkkkkk.', 'knnnnnnk', 'kNNNNNNk', '.kkkkkkk', 'knnnnnnk', 'kNNNNNNk', 'kkkkkkk.'],
    reputation:['...kk...', '..kyyk..', 'kkkyykkk', 'kyyyyyyk', '.kyyyyk.', '.kyyyyk.', 'kyykkyyk', 'kkk..kkk'],
    clock:     ['..kkkk..', '.kwwwwk.', 'kwwkwwwk', 'kwwkwwwk', 'kwwkkkwk', 'kwwwwwwk', '.kwwwwk.', '..kkkk..'],
    save:      ['........', '.kkkkkk.', 'knnnnnnk', 'kNNyyNNk', 'knnkknnk', 'knnnnnnk', 'kkkkkkkk', '........'],
    home:      ['..kkkk..', '..k..k..', '..kkkk..', 'kkkSSkkk', '...SS...', 'k..SS..k', 'kS.SS.Sk', '.kSSSSk.'],
    ship:      ['...k....', '...kww..', '...kwww.', '...kwwww', '...k....', 'kkkkkkkk', '.knnnnk.', '..kkkk..'],
    map:       ['kkkkkkkk', 'keebbeek', 'kebbbgek', 'kebrbggk', 'keerggek', 'kbbegrek', 'kbbeeebk', 'kkkkkkkk'],
    crew:      ['..kkkk..', '.kNNNNk.', '.kttttk.', '.ktkktk.', '..kttk..', '.kbbbbk.', 'kbbbbbbk', 'kbbkkbbk'],
    port:      ['....kr..', '....krr.', '....k...', '..kkkk..', '.krrrrk.', 'kwwwwwwk', 'kwkwwnwk', 'kkkkkkkk'],
    pets:      ['...kk...', '..kwwk..', '.kwgwwk.', '.kwwwgk.', 'kwgwwwwk', 'kwwwgwwk', '.kwwwwk.', '..kkkk..'],
    codex:     ['.kkkkkk.', 'kvvvvvwk', 'kvyyvvwk', 'kvvvvvwk', 'kvyyyvwk', 'kvvvvvwk', 'kvvvvvwk', '.kkkkkkk'],
    system:    ['..kssk..', '.kssssk.', 'kssSSssk', 'ssSkkSss', 'ssSkkSss', 'kssSSssk', '.kssssk.', '..kssk..'],
    helm:      ['...nn...', '.n.nn.n.', '..nNNn..', 'nnNkkNnn', 'nnNkkNnn', '..nNNn..', '.n.nn.n.', '...nn...'],
    flag:      ['.kkkkkk.', '.krrrrrk', '.krwwrrk', '.krrrrrk', '.kkkkkk.', '.k......', '.k......', 'kkk.....'],
    bed:       ['........', 'k.......', 'kww....k', 'kwwbbbbk', 'kbbbbbbk', 'kkkkkkkk', 'k......k', '........'],
    barrel:    ['..kkkk..', '.knnnnk.', 'kSSSSSSk', 'knnnnnnk', 'knnnnnnk', 'kSSSSSSk', '.knnnnk.', '..kkkk..'],
    ok:        ['........', '......kk', '.....kgk', 'kk..kgk.', 'kgkkgk..', '.kggk...', '..kk....', '........'],
    warn:      ['...kk...', '..kyyk..', '..ykky..', '.kykkyk.', '.kykkyk.', 'kyyyyyyk', 'kyykkyyk', 'kkkkkkkk'],
    lock:      ['..kkkk..', '.kS..Sk.', '.k....k.', 'kkkkkkkk', 'kyyyyyyk', 'kyykkyyk', 'kyyyyyyk', 'kkkkkkkk'],
    hp:        ['........', '.kk..kk.', 'krrkkrrk', 'krwrrrrk', 'krrrrrrk', '.krrrrk.', '..krrk..', '...kk...'],
    atk:       ['......kk', '.....ksk', '....kswk', '.k.kswk.', '.kkswk..', '..kNk...', '.kNkkk..', 'kNk.....'],
    def:       ['kkkkkkkk', 'kbbwwbbk', 'kbbwwbbk', 'kwwwwwwk', 'kbbwwbbk', '.kbwwbk.', '..kbbk..', '...kk...'],
    spd:       ['....k...', '....kk..', 'kkkkkck.', 'kcccccck', 'kkkkkck.', '....kk..', '....k...', '........'],
    island:    ['.GG..GG.', 'GggGGggG', '...nn...', '...n....', '...n....', '..en....', '.eeeeee.', 'bbbbbbbb'],
    dungeon:   ['..kkkk..', '.kSSSSk.', 'kSSkkSSk', 'kSkNNkSk', 'kSkNNkSk', 'kSkNNkSk', 'kSkNNkSk', 'kkkkkkkk'],
    wreck:     ['....k...', '...kw...', '..k.w...', '....k...', 'kk..kkk.', 'knkknnnk', '.knnnk..', 'bbbbbbbb'],
    arena:     ['k......k', '.ks..sk.', '..ksks..', '...kk...', '...kk...', '..ksks..', '.kN..Nk.', 'kN....Nk'],
    secret:    ['...y....', '...y....', '.y.y.y..', '..yyy...', 'yyywyyy.', '..yyy...', '.y.y.y..', '...y....'],
    question:  ['.kkkkk..', 'kyyyyyk.', 'kyk.kyyk', '...kyyk.', '..kyyk..', '..kkk...', '..kyk...', '..kkk...'],
    eye:       ['........', '..kkkk..', '.kwwwwk.', 'kwwkkwwk', 'kwwkkwwk', '.kwwwwk.', '..kkkk..', '........'],
    vanguard:  ['kkkkkkkk', 'kbbwwbbk', 'kbbwwbbk', 'kwwwwwwk', 'kbbwwbbk', '.kbwwbk.', '..kbbk..', '...kk...'],
    striker:   ['......kk', '.....krk', '....krwk', '.k.krwk.', '.kkrwk..', '..kNk...', '.kNkkk..', 'kNk.....'],
    controller:['..kkkk..', '.kvvvvk.', 'kvvwwvvk', 'kvwkkwvk', 'kvwkkwvk', 'kvvwwvvk', '.kvvvvk.', '..kkkk..'],
    support:   ['..kkkk..', '..kggk..', 'kkkggkkk', 'kggggggk', 'kggggggk', 'kkkggkkk', '..kggk..', '..kkkk..'],
    scout:     ['........', '..kkkk..', '.kccccSk', 'kcwcckSk', 'kcccck..', '.kkkk...', '........', '........']
  };

  const CLASS_COLORS = {
    guard: '#3b7dd8', duelist: '#d8434a', spearfighter: '#e0892a', gunner: '#6c7486',
    brawler: '#a8683a', medic: '#e8eef4', cook: '#f0e2b8', navigator: '#2e8a4a',
    tinkerer: '#c08a3a', beastkeeper: '#5cbf5a', mystic: '#9b6ad8', quartermaster: '#ffcd4a'
  };
  const SKINS = ['#f6dcc0', '#f2d2a9', '#e0b088', '#c08a5e', '#8d5a3b', '#5e3b26'];
  const HAIRS = ['#2a1e14', '#6a3c1e', '#c9a24a', '#d8434a', '#e8e8f0', '#3b4f8f', '#2e6a4a', '#8a3a6a'];

  const hasDOM = typeof document !== 'undefined';
  const cache = new Map();

  function makeCanvas(w, h) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    return c;
  }

  function bitmapURL(rows, palette) {
    const pal = palette || PAL;
    const h = rows.length, w = rows[0].length;
    const c = makeCanvas(w, h);
    const ctx = c.getContext('2d');
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const ch = rows[y][x];
        if (ch === '.' || ch === ' ') continue;
        ctx.fillStyle = pal[ch] || ch;
        ctx.fillRect(x, y, 1, 1);
      }
    }
    return c.toDataURL();
  }

  function iconURL(name) {
    const key = 'icon:' + name;
    if (!cache.has(key)) cache.set(key, bitmapURL(ICONS[name] || ICONS.question));
    return cache.get(key);
  }

  // Pixel grid helper: draw colored pixels, then add a dark outline around them.
  function pixelGrid(w, h) {
    const px = new Array(w * h).fill(null);
    return {
      w, h, px,
      set(x, y, c) { if (x >= 0 && y >= 0 && x < w && y < h) px[y * w + x] = c; },
      get(x, y) { return (x >= 0 && y >= 0 && x < w && y < h) ? px[y * w + x] : null; },
      outline(color) {
        const add = [];
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
          if (px[y * w + x]) continue;
          const n = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
            const v = this.get(x + dx, y + dy);
            return v && v !== color;
          });
          if (n) add.push([x, y]);
        }
        for (const [x, y] of add) px[y * w + x] = color;
      },
      toURL() {
        const c = makeCanvas(w, h);
        const ctx = c.getContext('2d');
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
          const v = px[y * w + x];
          if (v) { ctx.fillStyle = v; ctx.fillRect(x, y, 1, 1); }
        }
        return c.toDataURL();
      }
    };
  }

  function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16);
    const f = v => Math.max(0, Math.min(255, Math.round(v + amt)));
    const r = f(n >> 16), g = f((n >> 8) & 255), b = f(n & 255);
    return '#' + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1);
  }

  // Seeded 12x12 crew portrait. Same seed -> same face in every language.
  function portraitURL(member) {
    const key = 'portrait:' + member.id + ':' + member.seed + ':' + member.classId + ':' + (member.injured ? 1 : 0);
    if (cache.has(key)) return cache.get(key);
    const s = member.seed >>> 0;
    const skin = SKINS[s % SKINS.length];
    const hair = HAIRS[(s >>> 4) % HAIRS.length];
    const style = (s >>> 8) % 3;
    const acc = (s >>> 11) % 4;
    const outfit = classColor(member.classId);
    const g = pixelGrid(12, 12);

    for (let y = 9; y < 12; y++) for (let x = 2; x < 10; x++) g.set(x, y, outfit);
    g.set(5, 9, shade(outfit, -40)); g.set(6, 9, shade(outfit, -40));
    g.set(5, 8, skin); g.set(6, 8, skin);
    for (let y = 2; y < 8; y++) for (let x = 3; x < 9; x++) g.set(x, y, skin);
    g.set(3, 7, null); g.set(8, 7, null);
    g.set(4, 7, shade(skin, -25)); g.set(7, 7, shade(skin, -25));
    g.set(4, 5, '#1a1c2c'); g.set(7, 5, '#1a1c2c');
    g.set(5, 6, shade(skin, -30)); g.set(6, 6, shade(skin, -30));

    for (let x = 3; x < 9; x++) { g.set(x, 1, hair); g.set(x, 2, hair); }
    g.set(4, 3, hair); g.set(3, 3, hair); g.set(8, 3, hair);
    if (style === 1) for (let y = 3; y < 8; y++) { g.set(2, y, hair); g.set(9, y, hair); }
    if (style === 2) { g.set(4, 0, hair); g.set(6, 0, hair); g.set(8, 0, hair); }

    if (acc === 1) for (let x = 3; x < 9; x++) g.set(x, 2, '#d8434a');
    if (acc === 1) g.set(9, 3, '#d8434a');
    if (acc === 2) { for (let x = 1; x < 11; x++) g.set(x, 1, '#2a2236'); for (let x = 3; x < 9; x++) g.set(x, 0, '#2a2236'); g.set(6, 0, '#ffcd4a'); }
    if (acc === 3) g.set(2, 6, '#ffcd4a');
    if (member.injured) { g.set(7, 2, '#f4f4f4'); g.set(8, 2, '#f4f4f4'); g.set(8, 3, '#f4f4f4'); }

    g.outline('#1a1c2c');
    const url = g.toURL();
    cache.set(key, url);
    return url;
  }

  // A small sailing ship for the title and language screen.
  function titleShipURL() {
    if (cache.has('title-ship')) return cache.get('title-ship');
    const g = pixelGrid(40, 30);
    const wood = '#a8683a', woodD = '#6a3c1e', sail = '#f4f4f4', sailD = '#c2c8d6';
    for (let y = 2; y < 21; y++) g.set(19, y, woodD);
    for (let y = 4; y < 17; y++) {
      const half = Math.floor((y - 3) * 0.55) + 1;
      for (let x = 19 - half * 2 - 1; x < 19; x++) g.set(x, y, x < 19 - half ? sailD : sail);
    }
    for (let y = 6; y < 17; y++) {
      const half = Math.floor((y - 5) * 0.5) + 1;
      for (let x = 20; x < 20 + half * 2 + 2; x++) g.set(x, y, x > 20 + half * 2 - 1 ? sailD : sail);
    }
    for (let x = 20; x < 25; x++) { g.set(x, 1, '#d8434a'); g.set(x, 2, '#d8434a'); }
    g.set(22, 1, '#f4f4f4'); g.set(22, 2, '#1a1c2c');
    for (let y = 18; y < 24; y++) {
      const inset = Math.max(0, y - 20);
      for (let x = 6 + inset * 2; x < 35 - inset; x++) g.set(x, y, y === 18 ? woodD : wood);
    }
    for (let x = 4; x < 9; x++) g.set(x, 17, wood);
    for (const x of [12, 17, 22, 27]) g.set(x, 20, '#ffcd4a');
    for (let x = 6; x < 35; x++) g.set(x, 22, woodD);
    g.outline('#1a1c2c');
    for (let y = 24; y < 30; y++) for (let x = 0; x < 40; x++) {
      const crest = (x + y * 3) % 9 === 0 || (x * 7 + y) % 13 === 0;
      g.set(x, y, crest ? '#73d2f0' : (y < 26 ? '#3b7dd8' : '#24508f'));
    }
    const url = g.toURL();
    cache.set('title-ship', url);
    return url;
  }

  // ------------------------------------------------------------- sea chart

  function hash2(x, y, seed) {
    let h = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263) + Math.imul(seed | 0, 2246822519)) >>> 0;
    h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }

  const ISLAND_RADIUS = { port: 11, island: 9, dungeon: 8, arena: 7, secret: 6, wreck: 4 };

  // Draws a region chart at low resolution; CSS scales it with crisp pixels.
  // opts: { palette, locations:[{id,x,y,type,knowledge,current}], seed }
  function drawSeaChart(canvas, opts) {
    const W = canvas.width, H = canvas.height;
    const ctx = canvas.getContext('2d');
    const pal = opts.palette;
    const seed = opts.seed || 7;
    const img = ctx.createImageData(W, H);
    const put = (x, y, hex) => {
      if (x < 0 || y < 0 || x >= W || y >= H) return;
      const n = parseInt(hex.slice(1), 16);
      const i = (y * W + x) * 4;
      img.data[i] = n >> 16; img.data[i + 1] = (n >> 8) & 255; img.data[i + 2] = n & 255; img.data[i + 3] = 255;
    };
    const known = opts.locations.filter(l => l.knowledge !== 'hidden');
    const hidden = opts.locations.filter(l => l.knowledge === 'hidden');
    const shallow = shade(pal.sea, 28);

    // Water with depth dithering and wave crests.
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let near = 999;
      for (const l of known) {
        const d = Math.hypot(x - l.x * W, y - l.y * H) - (ISLAND_RADIUS[l.type] || 8);
        if (d < near) near = d;
      }
      const n = hash2(x, y, seed);
      let col = pal.sea;
      if (near < 4) col = shallow;
      else if (near > 30 && n < 0.55) col = pal.deep;
      else if (near > 18 && n < 0.25) col = pal.deep;
      put(x, y, col);
    }
    for (let i = 0; i < W * H / 70; i++) {
      const x = Math.floor(hash2(i, 1, seed) * W), y = Math.floor(hash2(i, 2, seed) * H);
      for (let k = 0; k < 3; k++) put(x + k, y, shade(pal.sea, 55));
    }

    // Charted route dots from the current location to known destinations.
    const cur = opts.locations.find(l => l.current);
    if (cur) {
      for (const l of known) {
        if (l === cur) continue;
        const x0 = cur.x * W, y0 = cur.y * H, x1 = l.x * W, y1 = l.y * H;
        const len = Math.hypot(x1 - x0, y1 - y0);
        for (let d = 10; d < len - 8; d += 4) {
          const x = Math.round(x0 + (x1 - x0) * d / len), y = Math.round(y0 + (y1 - y0) * d / len);
          put(x, y, '#fff4d6'); put(x + 1, y, '#fff4d6');
        }
      }
    }

    // Islands and site features.
    for (const l of known) {
      const cx = Math.round(l.x * W), cy = Math.round(l.y * H);
      const r = ISLAND_RADIUS[l.type] || 8;
      const ls = hash2(cx, cy, seed) * 1000;
      for (let y = -r - 3; y <= r + 3; y++) for (let x = -r - 3; x <= r + 3; x++) {
        const ang = Math.atan2(y, x);
        const wob = 1 + 0.22 * Math.sin(ang * 3 + ls) + 0.12 * Math.sin(ang * 5 + ls * 2);
        const d = Math.hypot(x, y) / (r * wob);
        if (l.type === 'wreck') {
          if (d < 0.9) put(cx + x, cy + y, pal.land);
        } else if (d < 0.62) put(cx + x, cy + y, hash2(cx + x, cy + y, seed + 3) < 0.15 ? shade(pal.grass, -25) : pal.grass);
        else if (d < 1) put(cx + x, cy + y, pal.land);
      }
      if (l.type === 'port') {
        for (let x = 0; x < 9; x++) put(cx + r - 2 + x, cy + 2, '#6a3c1e');
        for (const [hx, hy, roof] of [[-4, -3, '#d8434a'], [0, -5, '#3b7dd8'], [-1, 0, '#d8434a']]) {
          for (let x = 0; x < 3; x++) { put(cx + hx + x, cy + hy, roof); put(cx + hx + x, cy + hy + 1, '#f4f4f4'); put(cx + hx + x, cy + hy + 2, '#f4f4f4'); }
          put(cx + hx + 1, cy + hy + 2, '#6a3c1e');
        }
      } else if (l.type === 'dungeon') {
        for (let y = -3; y < 3; y++) for (let x = -3; x < 4; x++) put(cx + x, cy + y, (x + y) % 3 === 0 ? '#5a5f70' : '#8a90a0');
        put(cx, cy + 1, '#1a1c2c'); put(cx + 1, cy + 1, '#1a1c2c'); put(cx, cy + 2, '#1a1c2c'); put(cx + 1, cy + 2, '#1a1c2c');
      } else if (l.type === 'arena') {
        for (let a = 0; a < 12; a++) put(cx + Math.round(Math.cos(a / 12 * Math.PI * 2) * (r + 3)), cy + Math.round(Math.sin(a / 12 * Math.PI * 2) * (r + 3)), '#c2c8d6');
      } else if (l.type === 'secret') {
        put(cx, cy, '#1a1c2c'); put(cx + 1, cy, '#1a1c2c'); put(cx, cy + 1, '#1a1c2c');
      } else if (l.type === 'wreck') {
        for (let x = -3; x < 4; x++) put(cx + x, cy, '#6a3c1e');
        for (let x = -2; x < 3; x++) put(cx + x, cy + 1, '#a8683a');
        put(cx + 1, cy - 1, '#6a3c1e'); put(cx + 1, cy - 2, '#6a3c1e');
      } else {
        for (let y = 0; y < 4; y++) put(cx - 1, cy - y, '#6a3c1e');
        for (const [dx, dy] of [[-3, -4], [-2, -5], [0, -5], [1, -4], [-1, -5]]) put(cx + dx, cy + dy, '#2e8a4a');
      }
    }

    // Fog over uncharted sites: dithered cloud, never the site itself.
    for (const l of hidden) {
      const cx = Math.round(l.x * W), cy = Math.round(l.y * H);
      for (let y = -14; y <= 14; y++) for (let x = -18; x <= 18; x++) {
        const d = Math.hypot(x / 18, y / 14) + hash2(cx + x, cy + y, seed + 9) * 0.25;
        if (d < 0.95 && ((x + y) & 1) === 0) put(cx + x, cy + y, '#e6ecf2');
        else if (d < 0.7) put(cx + x, cy + y, '#c9d3de');
      }
    }

    // Compass rose.
    const rx = W - 14, ry = H - 14;
    for (let i = -6; i <= 6; i++) { put(rx + i, ry, '#fff4d6'); put(rx, ry + i, '#fff4d6'); }
    put(rx, ry - 7, '#d8434a'); put(rx - 1, ry - 6, '#d8434a'); put(rx + 1, ry - 6, '#d8434a');

    ctx.putImageData(img, 0, 0);
  }

  // ------------------------------------------------------- battle sprites
  // Branch classes inherit the outfit color of their base class.
  function classColor(classId) {
    const C = root.P7S && root.P7S.Content;
    const base = C && C.baseClassOf ? C.baseClassOf(classId) : classId;
    return CLASS_COLORS[base] || CLASS_COLORS[classId] || '#888888';
  }
  const COLOR_HEX = { red: '#d8434a', blue: '#3b7dd8', green: '#5cbf5a', yellow: '#ffcd4a', purple: '#9b6ad8', white: '#e8eef4' };
  const CATEGORY_COLORS = {
    command: '#c9a24a', living: '#7a9fd0', training: '#d07a5a', medical: '#e8eef4', production: '#d8a050',
    navigation: '#5ab0a0', storage: '#a8683a', pet: '#8ac06a', social: '#c07ab0', defense: '#8a90a0'
  };
  // 12x12 enemy silhouettes per archetype. A = accent, B = body, D = dark.
  const ENEMY_BITMAPS = {
    skirmisher: ['....DDD.....', '...DBBBD....', '...DBkBD....', '....DBD.....', '..DDBBBDD.s.', '.DBBBBBBBDs.', '.D.DBBBD.Ds.', '...DBBBD..s.', '...DAAAD....', '...DB.BD....', '..DB...BD...', '..DD...DD...'],
    brute:      ['...DDDDDD...', '..DBBBBBBD..', '..DBkBBkBD..', '..DBBBBBBD..', '.DDBBAABBDD.', 'DBBBBBBBBBBD', 'DBBBBBBBBBBD', 'DBDBBBBBBDBD', 'DD.DBBBBD.DD', '...DBBBBD...', '..DBBDDBBD..', '..DDD..DDD..'],
    shooter:    ['....DDDD....', '...DAAAAD...', '...DBkBkD...', '....DBBD....', '...DBBBBDsss', '..DBBBBBBDss', '..DBDBBDBD..', '....DBBD....', '....DBBD....', '...DB..BD...', '...DB..BD...', '...DD..DD...'],
    caster:     ['.....A......', '....DAD.....', '...DAAAD....', '..DDDDDDD...', '...DBkBD..A.', '...DBBBD.DAD', '..DAAAAAD.D.', '.DAAAAAAAD..', '.DAABBBAAD..', '.DAABBBAAD..', 'DAAAAAAAAAD.', 'DDDDDDDDDDD.'],
    healer:     ['....DDDD....', '...DwwwwD...', '...DBkBkD...', '....DBBD....', '..DDwwwwDD..', '.DwwwAwwwwD.', '.DwwAAAwwwD.', '.DwwwAwwwwD.', '..DwwwwwwD..', '..DwwwwwwD..', '..DwwwwwwD..', '..DDDDDDDD..'],
    boss:       ['.A..AAAA..A.', '.AAAAAAAAAA.', '..DDDDDDDD..', '.DBBkBBkBBD.', '.DBBBBBBBBD.', 'DDBBBAABBBDD', 'DBBBBBBBBBBD', 'DBBDBBBBDBBD', 'DBBDAAAADBBD', 'DDDBBBBBBDDD', '..DBBDDBBD..', '..DDD..DDD..'],
    captain:    ['...DDDDDD...', '..DAAAAAAD..', '.DDDDDDDDDD.', '...DBkBkD...', '....DBBD....', '..DDAAAADD..', '.DBBAAAABBD.', '.DBDBBBBDBDs', '...DBBBBD.Ds', '...DAAAAD..s', '...DB..BD...', '..DDD..DDD..'],
    decoy:      ['....DDDD....', '...DAAAAD...', '..DAwAAwAD..', '..DAAAAAAD..', '.DAAAAAAAAD.', '.DAAwwwwAAD.', '.DAAAAAAAAD.', '..DAAAAAAD..', '...DAAAAD...', '....DAAD....', '.....DD.....', '............']
  };
  function enemySpriteURL(archetype, accent, body) {
    const key = 'enemy:' + archetype + ':' + accent + ':' + body;
    if (cache.has(key)) return cache.get(key);
    const rows = ENEMY_BITMAPS[archetype] || ENEMY_BITMAPS.skirmisher;
    const pal = Object.assign({}, PAL, { A: accent, B: body, D: '#1a1c2c' });
    const url = bitmapURL(rows, pal);
    cache.set(key, url);
    return url;
  }
  // Full-body 12x16 crew sprite for battle, seeded like the portrait.
  function allySpriteURL(member) {
    const key = 'ally:' + member.seed + ':' + member.classId;
    if (cache.has(key)) return cache.get(key);
    const s = member.seed >>> 0;
    const skin = SKINS[s % SKINS.length], hair = HAIRS[(s >>> 4) % HAIRS.length];
    const out = classColor(member.classId);
    const g = pixelGrid(12, 16);
    for (let y = 1; y < 6; y++) for (let x = 4; x < 8; x++) g.set(x, y, skin);
    for (let x = 4; x < 8; x++) g.set(x, 0, hair);
    g.set(4, 1, hair); g.set(7, 1, hair);
    g.set(5, 3, '#1a1c2c'); g.set(7, 3, '#1a1c2c');
    for (let y = 6; y < 12; y++) for (let x = 3; x < 9; x++) g.set(x, y, out);
    for (let y = 7; y < 11; y++) { g.set(2, y, out); g.set(9, y, out); }
    g.set(2, 11, skin); g.set(9, 11, skin);
    for (let y = 12; y < 16; y++) { g.set(4, y, shade(out, -50)); g.set(7, y, shade(out, -50)); }
    for (let x = 3; x < 9; x++) g.set(x, 9, shade(out, -35));
    g.outline('#1a1c2c');
    const url = g.toURL();
    cache.set(key, url);
    return url;
  }
  // Pet sprite: family color, role-specific shape, evolved forms gain a crest.
  function petSpriteURL(familyId, role, evolved, colorTag) {
    const key = 'pet:' + familyId + ':' + role + ':' + (evolved ? 1 : 0);
    if (cache.has(key)) return cache.get(key);
    const body = COLOR_HEX[colorTag] || '#8ac06a';
    const h = (root.P7S && root.P7S.World && root.P7S.World.hash32) ? root.P7S.World.hash32(familyId) : familyId.length * 977;
    const g = pixelGrid(12, 12);
    const r = role === 'helper' ? 4.2 : role === 'explorer' ? 3.4 : 3.8;
    const cy = role === 'explorer' ? 6 : 7;
    for (let y = 0; y < 12; y++) for (let x = 0; x < 12; x++) {
      const d = Math.hypot((x - 5.5) / (role === 'explorer' ? 1.3 : 1), y - cy);
      if (d < r) g.set(x, y, d < r - 1.6 ? shade(body, 30) : body);
    }
    g.set(4, cy - 1, '#1a1c2c'); g.set(7, cy - 1, '#1a1c2c');
    if (role === 'explorer') { g.set(1, cy - 2, body); g.set(10, cy - 2, body); g.set(0, cy - 3, body); g.set(11, cy - 3, body); }
    if (role === 'helper') { g.set(3, 11, shade(body, -40)); g.set(8, 11, shade(body, -40)); }
    if (role === 'companion') { g.set(5, cy - 4, body); g.set(6, cy - 5, body); }
    if (h & 1) { g.set(2, cy + 1, shade(body, -30)); g.set(9, cy + 1, shade(body, -30)); }
    if (evolved) { g.set(4, 1, '#ffcd4a'); g.set(5, 0, '#ffcd4a'); g.set(6, 1, '#ffcd4a'); g.set(7, 0, '#ffcd4a'); }
    g.outline('#1a1c2c');
    const url = g.toURL();
    cache.set(key, url);
    return url;
  }
  function eggSpriteURL(colorTag, grade) {
    const key = 'egg:' + colorTag + ':' + grade;
    if (cache.has(key)) return cache.get(key);
    const base = COLOR_HEX[colorTag] || '#e8eef4';
    const g = pixelGrid(10, 12);
    for (let y = 1; y < 12; y++) for (let x = 0; x < 10; x++) {
      const d = Math.hypot((x - 4.5) / 4, (y - 6.8) / (y < 7 ? 5.6 : 4.4));
      if (d < 1) g.set(x, y, ((x + y * 2) % 5 === 0) ? shade(base, -35) : '#f4f0e0');
    }
    for (let i = 0; i < grade; i++) g.set(3 + i * 2, 7, base);
    g.outline('#1a1c2c');
    const url = g.toURL();
    cache.set(key, url);
    return url;
  }

  const Art = {
    PAL, ICONS, CLASS_COLORS, COLOR_HEX, CATEGORY_COLORS, iconURL, portraitURL, titleShipURL, drawSeaChart, hasDOM,
    classColor, enemySpriteURL, allySpriteURL, petSpriteURL, eggSpriteURL, shade
  };
  root.P7S = root.P7S || {};
  root.P7S.Art = Art;
  if (typeof module !== 'undefined' && module.exports) module.exports = Art;
})(typeof globalThis !== 'undefined' ? globalThis : this);
