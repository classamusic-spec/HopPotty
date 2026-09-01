#!/usr/bin/env node
// Composes several renders into one contact sheet so a whole art set can be
// reviewed in a single look.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function main() {
  const [outPng, cols, tileW, tileH, bg, ...files] = process.argv.slice(2);
  const columns = parseInt(cols, 10);
  const w = parseInt(tileW, 10), h = parseInt(tileH, 10);
  const cells = files.map((f) => {
    const abs = path.resolve(f);
    const label = path.basename(f).replace(/\.(svg|html)$/, '');
    const data = fs.readFileSync(abs, 'utf8');
    const encoded = Buffer.from(data).toString('base64');
    return `<figure><img src="data:image/svg+xml;base64,${encoded}"><figcaption>${label}</figcaption></figure>`;
  }).join('\n');
  const html = `<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:${bg};font:600 13px -apple-system,system-ui,sans-serif;color:#243047}
    .grid{display:grid;grid-template-columns:repeat(${columns},${w}px);gap:16px;padding:20px}
    figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:6px}
    img{width:${w}px;height:${h}px;object-fit:contain;background:rgba(0,0,0,.03);border-radius:14px}
    figcaption{opacity:.6;font-size:11px}
  </style><div class="grid">${cells}</div>`;
  const tmp = path.join(path.dirname(path.resolve(outPng)), '.sheet.html');
  fs.mkdirSync(path.dirname(path.resolve(outPng)), { recursive: true });
  fs.writeFileSync(tmp, html);
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: columns * (w + 16) + 40, height: 100 }, deviceScaleFactor: 2 });
  await page.goto('file://' + tmp);
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.resolve(outPng), fullPage: true });
  await browser.close();
  fs.unlinkSync(tmp);
  console.log('contact sheet ->', outPng);
}
main().catch((e) => { console.error(e); process.exit(1); });
