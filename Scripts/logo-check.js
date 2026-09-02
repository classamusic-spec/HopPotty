#!/usr/bin/env node
/**
 * Proves that the split lockup is still the lockup.
 *
 * `Scripts/logo-art.js` rebuilds the sticker outline the artwork fused into one
 * contour, so its output is *derived* rather than copied — and a derivation
 * nobody measures is a redraw that has not been noticed yet. This renders the
 * artwork and the recombined layers at the same size, over the same background,
 * and reports how much of the frame disagrees.
 *
 * ## Why only the light ground is a pass/fail
 *
 * The artwork's silhouette is not a hug of the drawing — it bridges the notch
 * between the frog's two eye bumps with a flat slab. On white that slab is
 * invisible, which is presumably why it shipped; on the dark appearance's
 * `#14192A` it is a grey block across the crown. The rebuilt outline follows
 * each shape, so it does not have the slab, so the two *cannot* agree on dark
 * and demanding that they do would mean reintroducing the artefact into the one
 * appearance where it shows. Dark is measured and printed, not gated.
 *
 *   node Scripts/logo-check.js          pass/fail
 *   node Scripts/logo-check.js --write  also leave the renders in Art/render/logo/
 */
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const ORIGINAL = path.join(ROOT, 'Art', 'brand', 'hoppotty-logo.svg');
const REBUILT = path.join(ROOT, 'Art', 'brand', 'hoppotty-logo-flat.svg');
const OUT = path.join(ROOT, 'Art', 'render', 'logo');

/** Fraction of pixels allowed to differ by more than `CHANNEL`, per ground. */
const TOLERANCE = 0.0015;
/** Below this a pixel is antialiasing along an edge, not a different drawing. */
const CHANNEL = 20;

const GROUNDS = [
  // name, ground, gated. Both are `backgroundPrimary` — the splash's ground in
  // each appearance. See the header for why dark is measured but not gated.
  ['light', '#FFF9F2', true],
  ['dark', '#14192A', false],
];

const dataURI = (file) =>
  `data:image/svg+xml;base64,${Buffer.from(fs.readFileSync(file, 'utf8')).toString('base64')}`;

async function main() {
  const write = process.argv.includes('--write');
  const W = 1200, H = 692;
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  let bad = 0;

  for (const [name, ground, gated] of GROUNDS) {
    await page.setContent(
      `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:${ground}}` +
      `img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}</style>` +
      `<img id="a" src="${dataURI(ORIGINAL)}"><img id="b" src="${dataURI(REBUILT)}">`,
      { waitUntil: 'load' }
    );
    const stat = await page.evaluate(async ({ bg, channel }) => {
      const imgs = [document.getElementById('a'), document.getElementById('b')];
      await Promise.all(imgs.map((i) => i.decode()));
      const W = innerWidth, H = innerHeight;
      const pixels = imgs.map((img) => {
        const cv = document.createElement('canvas');
        cv.width = W; cv.height = H;
        const cx = cv.getContext('2d');
        cx.fillStyle = bg; cx.fillRect(0, 0, W, H);
        const k = Math.min(W / img.naturalWidth, H / img.naturalHeight);
        const w = img.naturalWidth * k, h = img.naturalHeight * k;
        cx.drawImage(img, (W - w) / 2, (H - h) / 2, w, h);
        return cx.getImageData(0, 0, W, H).data;
      });
      let worst = 0, over = 0, n = 0, sum = 0;
      for (let i = 0; i < pixels[0].length; i += 4) {
        const d = Math.max(
          Math.abs(pixels[0][i] - pixels[1][i]),
          Math.abs(pixels[0][i + 1] - pixels[1][i + 1]),
          Math.abs(pixels[0][i + 2] - pixels[1][i + 2])
        );
        sum += d; n++; worst = Math.max(worst, d);
        if (d > channel) over++;
      }
      return { pctOver: over / n, mean: sum / n, worst };
    }, { bg: ground, channel: CHANNEL });

    const ok = stat.pctOver <= TOLERANCE;
    if (gated && !ok) bad++;
    const mark = gated ? (ok ? '\u2713' : '\u2717') : '\u00b7';
    const limit = gated ? `limit ${(TOLERANCE * 100).toFixed(3)}%` : 'not gated: the crown slab';
    console.log(
      `${mark} ${name.padEnd(5)} ${(stat.pctOver * 100).toFixed(3)}% of pixels differ by ` +
      `>${CHANNEL}/channel (${limit}), mean ${stat.mean.toFixed(2)}`
    );

    if (write) {
      fs.mkdirSync(OUT, { recursive: true });
      for (const [id, label] of [['a', 'original'], ['b', 'rebuilt']]) {
        await page.evaluate((keep) => {
          for (const el of document.querySelectorAll('img')) el.style.visibility = el.id === keep ? '' : 'hidden';
        }, id);
        await page.screenshot({ path: path.join(OUT, `check-${name}-${label}.png`) });
      }
      await page.evaluate(() => { for (const el of document.querySelectorAll('img')) el.style.visibility = ''; });
    }
  }

  await browser.close();
  if (bad) {
    console.log('\nThe rebuilt lockup no longer matches the artwork. Re-run Scripts/logo-art.js;');
    console.log('if it still fails, the sticker outline (OUTLINE / SHADOW) needs re-measuring.');
  }
  process.exitCode = bad ? 1 : 0;
}

main().catch((e) => { console.error(e); process.exit(1); });
