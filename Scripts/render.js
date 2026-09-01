#!/usr/bin/env node
// Renders SVG/HTML sources to PNG so artwork can be inspected during
// development. The SVGs are the source of truth; rasters are throwaway.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error('usage: render.js <file.svg|file.html> [outPng] [width] [height]');
    process.exit(1);
  }
  const input = path.resolve(args[0]);
  const out = args[1] ? path.resolve(args[1]) : input.replace(/\.(svg|html)$/, '.png');
  const width = parseInt(args[2] || '512', 10);
  const height = parseInt(args[3] || '512', 10);

  fs.mkdirSync(path.dirname(out), { recursive: true });
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: 2,
  });
  if (input.endsWith('.svg')) {
    // Embed rather than navigating to the SVG directly: a bare SVG document
    // renders at its intrinsic size and overflows or letterboxes the viewport.
    const encoded = Buffer.from(fs.readFileSync(input, 'utf8')).toString('base64');
    const shell = `<!doctype html><meta charset="utf-8"><style>
      html,body{margin:0;height:100%}
      body{display:grid;place-items:center;background:transparent}
      img{width:100%;height:100%;object-fit:contain}
    </style><img src="data:image/svg+xml;base64,${encoded}">`;
    const tmp = path.join(path.dirname(out), '.render.html');
    fs.writeFileSync(tmp, shell);
    await page.goto('file://' + tmp);
    await page.waitForTimeout(250);
    await page.screenshot({ path: out, omitBackground: true });
    fs.unlinkSync(tmp);
    await browser.close();
    console.log('rendered ->', out);
    return;
  }
  await page.goto('file://' + input);
  await page.waitForTimeout(250);
  await page.screenshot({ path: out, omitBackground: input.endsWith('.svg') });
  await browser.close();
  console.log('rendered ->', out);
}
main().catch((e) => { console.error(e); process.exit(1); });
