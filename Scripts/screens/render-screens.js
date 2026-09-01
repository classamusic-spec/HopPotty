#!/usr/bin/env node
/** Renders each defined screen to a PNG at device scale. */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { baseCSS, ROOT } = require('./ui');

const DEVICES = {
  iphone: { width: 393, height: 852 },
  ipad: { width: 1024, height: 768 },
};

async function main() {
  const registry = require('./registry');
  const only = process.argv.slice(2);
  const outDir = path.join(ROOT, 'Art', 'render', 'screens');
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  for (const [name, def] of Object.entries(registry)) {
    if (only.length && !only.includes(name)) continue;
    const device = DEVICES[def.device || 'iphone'];
    const page = await browser.newPage({ viewport: device, deviceScaleFactor: 2 });
    const html = `<!doctype html><meta charset="utf-8"><style>${baseCSS(def.appearance)}
      html,body{width:${device.width}px;height:${device.height}px;overflow:hidden}</style>
      <body>${def.render(def.appearance)}</body>`;
    await page.setContent(html, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(200);
    await page.screenshot({ path: path.join(outDir, `${name}.png`) });
    await page.close();
    console.log('rendered', name);
  }
  await browser.close();
}
main().catch((e) => { console.error(e); process.exit(1); });
