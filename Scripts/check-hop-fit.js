#!/usr/bin/env node
/**
 * Fit check for Hop's pose set: does every drawing actually fit its own canvas?
 *
 * The pose files are generated from one shared transform in `hop-art.js`, so a
 * single wrong number there clips *every* pose at once — and a clipped mascot is
 * invisible in review, because the SVG still opens, still scales, and still
 * looks like a frog. The first version of that transform mapped the reference's
 * 150×160 bounds edge to edge on a 512×512 canvas: `hop-jump.svg` lost the top
 * of its crown, and all fifteen lost their toes and their ground shadow. Nobody
 * saw it until it turned up inside a mini-game and was blamed on the game.
 *
 * So this measures the thing that was wrong rather than the code that caused it:
 * it rasterises each pose at its own viewBox size, finds the alpha bounding box
 * of what was actually painted, and reports the clear air on each of the four
 * sides. Two ways to fail:
 *
 *   - **Clipped.** A side margin at or below `--min-margin`. Ink at the very
 *     edge is ink that was very probably cut off, and the cut is not visible in
 *     the file — only in the raster.
 *   - **Shrunk.** The drawing fills less than `--min-fill` of its box on its
 *     larger axis. A transform that overshoots the other way is just as broken:
 *     Hop keeps every toe and arrives on screen a third of the size, and the
 *     screens that size him by width have no way to tell.
 *
 * Wire it into CI next to `check-art.sh`: it needs no arguments and exits
 * non-zero on any failure.
 *
 *   node Scripts/check-hop-fit.js
 *   node Scripts/check-hop-fit.js --min-margin 8 idle jump
 *   node Scripts/check-hop-fit.js --dir /tmp/old-art      # measure another set
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');

/**
 * Margins are in the file's own user units (its viewBox), so the numbers read
 * against `hop-art.js`'s `MARGIN` directly. 12 is what the generator aims for;
 * failing below 6 leaves room for a deliberate tighter crop without hiding a
 * real clip.
 */
const DEFAULTS = {
  dir: path.join(ROOT, 'Art', 'character'),
  minMargin: 6,
  /**
   * The squatting poses are legitimately the shortest in the set at ~85%, so the
   * floor sits below them: it is here to catch a transform that is wrong the
   * other way, and a scale error large enough to matter takes even the tallest
   * pose under 80%.
   */
  minFill: 0.80,
  /** Supersampling. Two is enough to place an edge inside half a user unit. */
  ss: 2,
  /** Below this, a pixel is antialiasing spill rather than something drawn. */
  alpha: 8,
};

function parseArgs(argv) {
  const opts = { ...DEFAULTS, only: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dir') opts.dir = path.resolve(argv[++i]);
    else if (a === '--min-margin') opts.minMargin = parseFloat(argv[++i]);
    else if (a === '--min-fill') opts.minFill = parseFloat(argv[++i]);
    else if (a === '--help' || a === '-h') { console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]); process.exit(0); }
    else opts.only.push(a.replace(/^hop-/, '').replace(/\.svg$/, ''));
  }
  return opts;
}

/** The declared canvas of an SVG file: its viewBox, which is what it promises. */
function viewBoxOf(src, file) {
  const m = src.match(/viewBox="\s*([-\d.]+)[ ,]+([-\d.]+)[ ,]+([-\d.]+)[ ,]+([-\d.]+)\s*"/);
  if (!m) throw new Error(`${file}: no viewBox to measure against`);
  const [x, y, w, h] = m.slice(1).map(Number);
  return { x, y, w, h };
}

/**
 * The alpha bounding box of a rendered SVG, in the file's own user units.
 *
 * Drawn in a canvas rather than screenshotted so the measurement is of the
 * artwork alone — a screenshot carries the page's own background and any
 * rounding the compositor applied to it.
 */
async function alphaBox(page, src, vb, { ss, alpha }) {
  const W = Math.round(vb.w * ss), H = Math.round(vb.h * ss);
  const b64 = Buffer.from(src, 'utf8').toString('base64');
  const box = await page.evaluate(async ({ b64, W, H, alpha }) => {
    const img = new Image();
    img.width = W; img.height = H;
    await new Promise((res, rej) => {
      img.onload = res;
      img.onerror = () => rej(new Error('the SVG did not decode'));
      img.src = 'data:image/svg+xml;base64,' + b64;
    });
    const canvas = document.createElement('canvas');
    canvas.width = W; canvas.height = H;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.clearRect(0, 0, W, H);
    ctx.drawImage(img, 0, 0, W, H);
    const d = ctx.getImageData(0, 0, W, H).data;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (let y = 0; y < H; y++) {
      const row = y * W * 4;
      for (let x = 0; x < W; x++) {
        if (d[row + x * 4 + 3] >= alpha) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    return Number.isFinite(x0) ? { x0, y0, x1, y1 } : null;
  }, { b64, W, H, alpha });
  if (!box) return null;
  // Pixel indices back to user units; the far edge is the *outside* of the pixel.
  return {
    x0: vb.x + box.x0 / ss,
    y0: vb.y + box.y0 / ss,
    x1: vb.x + (box.x1 + 1) / ss,
    y1: vb.y + (box.y1 + 1) / ss,
  };
}

function pad(v, n) { return String(v).padStart(n); }
function num(v) { return v.toFixed(1); }

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(opts.dir)) {
    console.error(`no such directory: ${opts.dir}`);
    process.exit(2);
  }
  const files = fs.readdirSync(opts.dir)
    .filter((f) => /^hop-.+\.svg$/.test(f))
    .filter((f) => !opts.only.length || opts.only.includes(f.slice(4, -4)))
    .sort();
  if (!files.length) {
    console.error(`no hop-*.svg found in ${path.relative(ROOT, opts.dir) || opts.dir}`);
    process.exit(2);
  }

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 64, height: 64 } });
  await page.goto('about:blank');

  const rows = [];
  for (const file of files) {
    const src = fs.readFileSync(path.join(opts.dir, file), 'utf8');
    const vb = viewBoxOf(src, file);
    const box = await alphaBox(page, src, vb, opts);
    const name = file.slice(4, -4);
    if (!box) { rows.push({ name, vb, empty: true, problems: ['nothing was drawn'] }); continue; }
    const m = {
      left: box.x0 - vb.x,
      top: box.y0 - vb.y,
      right: vb.x + vb.w - box.x1,
      bottom: vb.y + vb.h - box.y1,
    };
    const w = box.x1 - box.x0, h = box.y1 - box.y0;
    const fill = Math.max(w / vb.w, h / vb.h);
    const problems = [];
    for (const [side, v] of Object.entries(m)) {
      // How much was lost cannot be read off a clipped raster — the ink that
      // ran past the edge was never painted. Report that it reached the edge.
      if (v <= 0) problems.push(`CLIPPED at the ${side} edge`);
      else if (v < opts.minMargin) problems.push(`${side} margin ${num(v)} < ${opts.minMargin}`);
    }
    if (fill < opts.minFill) problems.push(`fills ${(fill * 100).toFixed(0)}% of its box (min ${(opts.minFill * 100).toFixed(0)}%)`);
    rows.push({ name, vb, box, m, w, h, fill, problems });
  }
  await browser.close();

  console.log(`hop fit — ${path.relative(ROOT, opts.dir) || opts.dir}` +
    `   min margin ${opts.minMargin}, min fill ${(opts.minFill * 100).toFixed(0)}%\n`);
  console.log('pose        box        drawn         left    top  right bottom   fill');
  console.log('-'.repeat(74));
  for (const r of rows) {
    if (r.empty) { console.log(`${r.name.padEnd(10)}  ${r.vb.w}x${r.vb.h}   (nothing drawn)`); continue; }
    const mark = (v) => (v <= 0 ? `${num(v)}!` : v < opts.minMargin ? `${num(v)}?` : num(v));
    console.log(
      r.name.padEnd(10),
      `${r.vb.w}x${r.vb.h}`.padEnd(10),
      `${num(r.w)}x${num(r.h)}`.padEnd(13),
      pad(mark(r.m.left), 6), pad(mark(r.m.top), 6), pad(mark(r.m.right), 6), pad(mark(r.m.bottom), 6),
      pad(`${(r.fill * 100).toFixed(0)}%`, 6),
      r.problems.length ? '  FAIL' : '');
  }
  console.log('-'.repeat(74));

  const bad = rows.filter((r) => r.problems.length);
  if (!bad.length) {
    console.log(`\nall ${rows.length} poses fit, with at least ${opts.minMargin} units clear on every side.`);
    return 0;
  }
  console.log('');
  for (const r of bad) console.log(`  ${r.name}: ${r.problems.join('; ')}`);
  console.log(`\n${bad.length} of ${rows.length} poses do not fit their canvas.`);
  console.log('The transform lives in `wrap()` in Scripts/hop-art.js — fix it there and regenerate.');
  return 1;
}

main().then((code) => process.exit(code)).catch((e) => { console.error(e); process.exit(2); });
