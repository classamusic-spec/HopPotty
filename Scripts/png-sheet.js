#!/usr/bin/env node
// Composes rendered screens into one sheet, so a whole set can be reviewed for
// consistency in a single look rather than screen by screen.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
(async () => {
  const [out, cols, w, ...files] = process.argv.slice(2);
  const cells = files.map(f => {
    const b64 = fs.readFileSync(path.resolve(f)).toString('base64');
    return `<figure><img src="data:image/png;base64,${b64}"><figcaption>${path.basename(f, '.png')}</figcaption></figure>`;
  }).join('');
  const html = `<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#E8E2DA;font:600 12px system-ui,sans-serif;color:#243047}
    .g{display:grid;grid-template-columns:repeat(${cols},${w}px);gap:18px;padding:22px}
    figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:7px}
    img{width:${w}px;border-radius:14px;box-shadow:0 4px 16px rgba(36,48,71,.18);display:block}
    figcaption{opacity:.65;font-size:11px}</style><div class="g">${cells}</div>`;
  const tmp = path.join(path.dirname(path.resolve(out)), '.pngsheet.html');
  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  fs.writeFileSync(tmp, html);
  const b = await chromium.launch({ args: ['--no-sandbox'] });
  const p = await b.newPage({ viewport: { width: cols * (+w + 18) + 44, height: 400 }, deviceScaleFactor: 1 });
  await p.goto('file://' + tmp); await p.waitForTimeout(400);
  await p.screenshot({ path: path.resolve(out), fullPage: true });
  await b.close(); fs.unlinkSync(tmp); console.log('->', out);
})();
