#!/usr/bin/env node
/**
 * Reports where each screen's character actually lands.
 *
 * A character floating 100px above the grass is the fastest way to make an
 * illustrated screen look assembled rather than drawn, and it is invisible in
 * code. This prints the y of the ground shadow inside every `[data-hop]`, so a
 * scene's horizon can be set to the number instead of guessed.
 */
const { chromium } = require('playwright');
const { baseCSS } = require('./ui');

const DEVICES = { iphone: { width: 393, height: 852 }, ipad: { width: 1024, height: 768 } };
const FEET = 452 / 512;

async function main() {
  const registry = require('./registry');
  const only = process.argv.slice(2);
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  for (const [name, def] of Object.entries(registry)) {
    if (only.length && !only.includes(name)) continue;
    const device = DEVICES[def.device || 'iphone'];
    const page = await browser.newPage({ viewport: device, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><meta charset="utf-8"><style>${baseCSS(def.appearance)}
      html,body{width:${device.width}px;height:${device.height}px;overflow:hidden}</style>
      <body>${def.render(def.appearance)}</body>`, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    const hops = await page.evaluate((feet) => [...document.querySelectorAll('[data-hop]')].map((el) => {
      const img = el.querySelector('img');
      const r = (img || el).getBoundingClientRect();
      return { top: Math.round(r.top), h: Math.round(r.height), feet: Math.round(r.top + r.height * feet) };
    }), FEET);
    if (hops.length) {
      hops.forEach((h) => console.log(`${name}: character top ${h.top}, height ${h.h}, FEET AT y=${h.feet}` +
        `  → horizon ${(h.feet / device.height).toFixed(3)}`));
    }
    await page.close();
  }
  await browser.close();
}
main().catch((e) => { console.error(e); process.exit(1); });
