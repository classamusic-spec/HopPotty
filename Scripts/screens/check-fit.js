#!/usr/bin/env node
/**
 * Overflow check for the screen harness.
 *
 * A render is a fixed-size viewport with `overflow:hidden`, so a card that is
 * 30px too tall does not scroll — it silently loses its bottom edge. This walks
 * every element of every screen and reports anything crossing the viewport, plus
 * any text box shorter than the text inside it.
 */
const { chromium } = require('playwright');
const path = require('path');
const { baseCSS, ROOT } = require('./ui');

const DEVICES = { iphone: { width: 393, height: 852 }, ipad: { width: 1024, height: 768 } };

async function main() {
  const registry = require('./registry');
  const only = process.argv.slice(2);
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  let bad = 0;
  for (const [name, def] of Object.entries(registry)) {
    if (only.length && !only.includes(name)) continue;
    const device = DEVICES[def.device || 'iphone'];
    const page = await browser.newPage({ viewport: device, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><meta charset="utf-8"><style>${baseCSS(def.appearance)}
      html,body{width:${device.width}px;height:${device.height}px;overflow:hidden}</style>
      <body>${def.render(def.appearance)}</body>`, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    const report = await page.evaluate(({ w, h }) => {
      const out = { over: [], clipped: [], docH: document.body.scrollHeight };
      const label = (el) => {
        const t = (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 46);
        return `${el.tagName.toLowerCase()}${el.className ? '.' + String(el.className).slice(0, 14) : ''}` +
          (t ? ` "${t}"` : '');
      };
      for (const el of document.querySelectorAll('body *')) {
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) continue;
        if (r.bottom > h + 0.6 || r.right > w + 0.6 || r.top < -0.6 || r.left < -0.6) {
          out.over.push(`${label(el)} @ [${r.left.toFixed(0)},${r.top.toFixed(0)} ${r.width.toFixed(0)}x${r.height.toFixed(0)}]`);
        }
        const cropsArt = el.querySelector('img,svg') !== null;
        if (!cropsArt && el.scrollHeight > el.clientHeight + 1 && getComputedStyle(el).overflow !== 'visible') {
          out.clipped.push(`${label(el)} content ${el.scrollHeight} > box ${el.clientHeight}`);
        }
      }
      return out;
    }, device);
    const problems = [...new Set([...report.over.map((s) => 'OVERFLOW ' + s), ...report.clipped.map((s) => 'CLIPPED  ' + s)])];
    if (problems.length) {
      bad++;
      console.log(`\n✗ ${name}  (body ${report.docH}px / ${device.height}px)`);
      problems.slice(0, 12).forEach((p) => console.log('   ' + p));
      if (problems.length > 12) console.log(`   …and ${problems.length - 12} more`);
    } else {
      console.log(`✓ ${name}`);
    }
    await page.close();
  }
  await browser.close();
  process.exitCode = bad ? 1 : 0;
}
main().catch((e) => { console.error(e); process.exit(1); });
