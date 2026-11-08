'use strict';
// Syntax-checks every JavaScript file in the project with `node --check`, and
// confirms index.html loads each src/ and locales/ script exactly once.
// Usage: node tests/check.js
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const files = [];
for (const dir of ['src', 'locales', 'tests']) {
  for (const f of fs.readdirSync(path.join(ROOT, dir)).sort()) {
    if (/\.(m?js)$/.test(f)) files.push(path.join(dir, f));
  }
}

let failed = 0;
for (const f of files) {
  const r = spawnSync(process.execPath, ['--check', path.join(ROOT, f)], { encoding: 'utf8' });
  if (r.status !== 0) { failed++; console.log('FAIL ' + f + '\n' + r.stderr); } else console.log('ok   ' + f);
}

const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const loaded = [...html.matchAll(/<script src="([^"]+)"/g)].map(m => m[1]);
for (const f of files.filter(x => !x.startsWith('tests')).map(x => x.split(path.sep).join('/'))) {
  const n = loaded.filter(x => x === f).length;
  if (n !== 1) { failed++; console.log('FAIL index.html loads ' + f + ' ' + n + ' times'); }
}
for (const src of loaded) if (!fs.existsSync(path.join(ROOT, src))) { failed++; console.log('FAIL index.html references missing ' + src); }

console.log('\n' + files.length + ' files checked, ' + loaded.length + ' scripts in index.html, ' + failed + ' problem(s)');
process.exit(failed ? 1 : 0);
