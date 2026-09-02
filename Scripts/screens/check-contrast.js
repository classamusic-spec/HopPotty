#!/usr/bin/env node
/**
 * Worst-pixel contrast for every text run on a rendered screen.
 *
 * The other half of `check-fit.js`. That one asks whether a box fits; this one
 * asks whether the text inside it can be read. Run it the same way:
 *
 * ```bash
 * NODE_PATH=/opt/node22/lib/node_modules node Scripts/screens/check-contrast.js
 * NODE_PATH=... ALL=1 node Scripts/screens/check-contrast.js 01-parent-home
 * ```
 *
 * `ALL=1` prints the 24 worst runs on each screen rather than only the failures,
 * which is how you find the number to watch before it becomes the number that
 * broke. `WHY=1` adds, for each failure, the ink, the exact pixel it lost
 * against and where that pixel is — the difference between "darken the ink" and
 * "the plate underneath is not painting at all".
 *
 * ## Two things it does that a token-pair calculator cannot
 *
 * 1. **It composites first.** A run over Hop's pond does not sit on a colour; it
 *    sits on sky, hills, water and whatever ripple drifted under it. The ink is
 *    scored against the *worst pixel* of the ground actually painted beneath its
 *    glyphs, which is the only number WCAG is about.
 * 2. **It measures glyph boxes, not element boxes.** A run's bounding box
 *    includes its padding and the rounded corners of whatever it sits in.
 *    Scoring those pixels invents failures a reader never sees — white on a green
 *    capsule "fails" against the page showing through the corner — so the rects
 *    come from a `Range` over the text nodes.
 *
 * ## Exemptions
 *
 * `EXEMPT` below is the whole list, each entry carrying its reason. A run that
 * fails and is not in it fails the script — this is a gate, not a report. A run
 * that is in it and *stops* failing also fails the script, so the list cannot
 * quietly outlive the thing it excused.
 *
 * Composite-then-measure: the run's ink colour is compared against the darkest
 * *and* lightest pixel of the ground actually painted underneath it, after the
 * text itself has been made transparent. A run over a gradient or a drawing is
 * therefore scored on the pixel that hurts, not on the token it nominally sits
 * on.
 */
const { chromium } = require('playwright');
const path = require('path');

/**
 * Runs that are allowed to score under the floor, and why.
 *
 * One entry, and it is not "we could not get it to pass".
 *
 * The **platform's destructive red** is `Button(role: .destructive)`, which iOS
 * paints and this render only depicts. It is 3.4:1 on white and Apple ships it
 * in Settings; matching it is more useful to a caregiver than being right about
 * it alone, and the word "Delete" carries the meaning without the colour. Note
 * this covers only the rows iOS draws — every destructive control the app draws
 * itself uses `HopDestructiveButton`, which is darker on purpose and passes at
 * 6.5:1.
 *
 * The dimmed screen behind a sheet is *not* here. It is marked `data-scenery`
 * in the render and skipped outright, because it is not one run to excuse but
 * every run on a whole screen the person is looking past.
 */
const EXEMPT = {
  '34-settings-hub': { text: 'Delete everything', why: "iOS's own destructive red, which iOS paints" },
};
const { baseCSS } = require('./ui');

const DEVICES = { iphone: { width: 393, height: 852 }, ipad: { width: 1024, height: 768 } };

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
    await page.waitForTimeout(120);

    // 1. collect the runs, 2. make their ink transparent
    const runs = await page.evaluate(() => {
      const out = [];
      const touched = [];
      for (const el of document.querySelectorAll('body *')) {
        if (el.closest('svg')) continue;
        // Text the render has declared scenery — the dimmed screen behind a
        // sheet. Not a reading surface, so not a reading measurement.
        if (el.closest('[data-scenery]')) continue;
        const cs = getComputedStyle(el);
        const size = parseFloat(cs.fontSize);
        const weight = parseInt(cs.fontWeight, 10) || 400;
        for (const node of el.childNodes) {
          if (node.nodeType !== 3 || !node.textContent.trim()) continue;
          // The *glyph* boxes, not the block's box: a run's bounding box
          // includes the padding and the rounded corners of whatever it sits
          // in, and scoring those pixels invents failures a reader never sees.
          const range = document.createRange();
          range.selectNodeContents(node);
          for (const r of range.getClientRects()) {
            if (r.width < 1 || r.height < 1) continue;
            out.push({
              text: node.textContent.trim().replace(/\s+/g, ' ').slice(0, 34),
              color: cs.color,
              x: Math.round(r.left), y: Math.round(r.top),
              w: Math.round(r.width), h: Math.round(r.height),
              large: size >= 24 || (size >= 18.66 && weight >= 700),
            });
          }
          touched.push(el);
        }
      }
      for (const el of touched) {
        el.style.color = 'transparent';
        el.style.textShadow = 'none';
        el.style.webkitTextFillColor = 'transparent';
      }
      return out;
    });

    const shot = (await page.screenshot({ type: 'png' })).toString('base64');
    const scored = await page.evaluate(async ({ runs, shot }) => {
      const img = new Image();
      img.src = 'data:image/png;base64,' + shot;
      await img.decode();
      const cv = document.createElement('canvas');
      cv.width = img.width; cv.height = img.height;
      const ctx = cv.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(img, 0, 0);
      const lum = (r, g, b) => {
        const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
      };
      const ratio = (a, b) => (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
      const parse = (c) => c.match(/[\d.]+/g).map(Number);
      return runs.map((run) => {
        const [cr, cg, cb] = parse(run.color);
        const L = lum(cr, cg, cb);
        const x = Math.max(0, run.x), y = Math.max(0, run.y);
        const w = Math.min(cv.width - x, run.w), h = Math.min(cv.height - y, run.h);
        if (w <= 0 || h <= 0) return { ...run, ratio: null };
        const d = ctx.getImageData(x, y, w, h).data;
        let worst = Infinity;
        let at = null;
        for (let i = 0; i < d.length; i += 4) {
          const r = ratio(L, lum(d[i], d[i + 1], d[i + 2]));
          if (r < worst) { worst = r; at = { r: d[i], g: d[i + 1], b: d[i + 2], i: i / 4 }; }
        }
        // Where the worst pixel is and what colour it is. A number alone tells
        // you a run failed; this tells you what it failed against, which is the
        // difference between "darken the ink" and "the plate is not painting".
        const spot = at
          ? { colour: `rgb(${at.r}, ${at.g}, ${at.b})`, x: x + (at.i % w), y: y + Math.floor(at.i / w) }
          : null;
        return { text: run.text, large: run.large, ratio: worst, ink: run.color, box: { x, y, w, h }, spot };
      });
    }, { runs, shot });

    const floor = (r) => (r.large ? 3.0 : 4.5);
    const allowed = EXEMPT[name];
    const under = scored.filter((r) => r.ratio !== null && r.ratio < floor(r));
    const excused = under.filter((r) => allowed && r.text === allowed.text);
    const fails = under.filter((r) => !excused.includes(r));
    if (allowed && !excused.length) {
      stale.push(`${name}: "${allowed.text}" is exempt (${allowed.why}) but no longer scores under the floor`);
    }
    failed += fails.length;
    const min = scored.reduce((m, r) => (r.ratio !== null && r.ratio < m.ratio ? r : m), { ratio: Infinity, text: '—' });
    console.log(`${fails.length ? '✗' : '✓'} ${name}  worst ${min.ratio === Infinity ? 'n/a' : min.ratio.toFixed(2)}:1  "${min.text}"`);
    for (const f of fails) {
      console.log(`    ${f.ratio.toFixed(2)}:1  (floor ${floor(f)})  "${f.text}"`);
      if (process.env.WHY) {
        console.log(`        ink ${f.ink}  over ${f.spot ? f.spot.colour : '—'} ` +
          `at (${f.spot ? f.spot.x : '?'}, ${f.spot ? f.spot.y : '?'})  ` +
          `run box ${f.box.w}×${f.box.h} at (${f.box.x}, ${f.box.y})`);
      }
    }
    for (const e of excused) console.log(`    ${e.ratio.toFixed(2)}:1  exempt — ${allowed.why}`);
    if (process.env.ALL) {
      for (const r of scored.filter((s) => s.ratio !== null).sort((a, b) => a.ratio - b.ratio).slice(0, 24)) {
        console.log(`      ${r.ratio.toFixed(2)}:1  ${r.large ? 'L' : ' '}  "${r.text}"`);
      }
    }
    await page.close();
  }
  await browser.close();

  for (const line of stale) console.log(`\nstale exemption — ${line}`);
  if (failed || stale.length) {
    console.log(`\n${failed} run(s) below the floor${stale.length ? `, ${stale.length} stale exemption(s)` : ''}`);
    process.exitCode = 1;
  } else {
    console.log('\nEvery text run clears its floor, or is exempt for a written reason.');
  }
}

/** Runs below the floor with no exemption, and exemptions no longer needed. */
let failed = 0;
const stale = [];

main().catch((e) => { console.error(e); process.exit(1); });
