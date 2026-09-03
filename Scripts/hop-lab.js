#!/usr/bin/env node
/**
 * Hop's debug lab, and the silhouette gate.
 *
 * Hop is now the brand's most important visual asset, and "does he read?" had
 * been answered by opinion. This answers it two ways instead.
 *
 * ## The lab (§53)
 *
 *   node Scripts/hop-lab.js
 *   → Art/render/hop-lab/index.html
 *
 * Every pose, on white / Cloud / Pond Blue / vegetation green / dark, with the
 * outline switchable between Off, Default, Strong and High Contrast and the
 * size between Small, Medium and Hero. The point of Off is not that anyone would
 * ship it: it is the test the brief asks for — *the character must still read if
 * the outline goes away*, which is what stops the outline carrying the drawing
 * on its own. The point of Strong and High Contrast is the same in reverse:
 * if Default only works once you reach for Strong, Default is wrong.
 *
 * The lab opens on **Auto**, which picks the level the app would actually pick
 * for that size (`HopOutlineStyle.forSize` in Swift, `--level` here), so what is
 * on screen is what ships rather than a setting someone left on.
 *
 * ## The silhouette gate (§19, §54)
 *
 *   node Scripts/hop-lab.js --silhouette
 *   → Art/render/hop-lab/silhouette-*.png and a pass/fail table
 *
 * The manual version of this test is: hide the facial detail, look at the flat
 * silhouette, and confirm the head, both arms, both hands, the torso, both legs
 * and both feet are each immediately distinguishable. That is a real test and a
 * slow one, so it is measured instead.
 *
 * For each part, the figure is rendered flat twice — once whole, once with that
 * part hidden — and once more with *only* that part. The area that disappears
 * when the part is hidden is the part's **exclusive contribution** to the
 * outline; divided by the part's own area it is its **exposure**: the fraction
 * of itself that is not buried inside something else.
 *
 *   exposure 0.00  the part is entirely inside the rest of the body. Invisible.
 *   exposure 0.25  a quarter of it clears everything else — a readable lobe.
 *   exposure 1.00  the part stands completely free.
 *
 * A limb hidden behind the body is not automatically wrong — an arm behind a
 * head is a real thing an arm does — so the gate is a floor, not a target, and
 * it is applied per part class: a hand is small and a head is not, so a hand is
 * also required to clear a minimum share of the whole silhouette.
 *
 * **When a pose fails, the fix order is fixed (§61): pose → overlap → tone →
 * spacing → stroke.** This script cannot be satisfied by thickening the
 * outline, because it measures a drawing with no outline in it at all.
 *
 * ## The rest
 *
 *   node Scripts/hop-lab.js --contracts   everything outside this file that
 *                                         reads Hop's markup or restates his
 *                                         numbers — the blink derivation, the
 *                                         widget's head, the Swift pose table,
 *                                         the outline levels and the tokens.
 *                                         (It re-runs `widget-face.js`, which
 *                                         rewrites the generated widget art —
 *                                         which is what you want after changing
 *                                         the drawing anyway.)
 *   node Scripts/hop-lab.js --levels      every level, fit-checked
 */
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const art = require('./hop-art.js');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'Art', 'render', 'hop-lab');

// ---------------------------------------------------------------------------
// Backgrounds Hop has to survive
// ---------------------------------------------------------------------------

/**
 * The five grounds from §18, and they are not decoration: each one attacks the
 * drawing differently. Cream and white attack the outline (a light background
 * makes a subtle dark edge the only thing holding the shape); vegetation green
 * attacks the *fill* (Hop's own hue, so the silhouette is all that is left);
 * pond blue attacks the tonal ramp; night attacks everything at once.
 */
const GROUNDS = [
  { id: 'white', label: 'White', css: '#FFFFFF' },
  { id: 'cloud', label: 'Cloud', css: '#FFF9F2' },
  { id: 'pond', label: 'Pond Blue', css: '#6FC7E8' },
  { id: 'leaf', label: 'Vegetation', css: '#4E9E63' },
  { id: 'night', label: 'Night', css: '#14192A' },
];

/** The lab's four outline buttons, and what each one means in `hop-art.js`. */
const SWITCHES = [
  { id: 'auto', label: 'Auto', title: 'What the app picks for this size' },
  { id: 'off', label: 'Outline off', title: 'The readability test: tone and pose alone' },
  { id: 'default', label: 'Default', title: 'What ships in Art/character' },
  { id: 'scene', label: 'Strong', title: 'Over illustration and busy scenery' },
  { id: 'highContrast', label: 'High contrast', title: 'Increase Contrast, and accessibility appearances' },
];

/**
 * The three sizes, and the level each one resolves to under Auto.
 *
 * This table is the responsive rule (§17) and it is duplicated in exactly one
 * other place — `HopOutlineStyle.forSize` in `HopCharacterView.swift` — because
 * the app draws Hop as vectors at whatever size it likes and has to make the
 * same choice at runtime. Small gets a heavier silhouette because at 64px the
 * default edge is under a pixel; hero gets a lighter one because a large Hop
 * with a small Hop's edge is a magnified sticker.
 */
const SIZES = [
  { id: 'small', label: 'Small · 64', px: 64, auto: 'small' },
  { id: 'medium', label: 'Medium · 160', px: 160, auto: 'default' },
  { id: 'hero', label: 'Hero · 320', px: 320, auto: 'hero' },
];

const LEVELS = ['off', 'hero', 'default', 'scene', 'small', 'highContrast'];

// ---------------------------------------------------------------------------
// Measuring
// ---------------------------------------------------------------------------

/** The parts the gate asks about, in the order §19 lists them. */
const GATE = [
  { id: 'head', label: 'head', minExposure: 0.30, minShare: 0.06 },
  { id: 'body', label: 'torso', minExposure: 0.10, minShare: 0.02 },
  { id: 'left-arm', label: 'left arm', minExposure: 0.30, minShare: 0.015 },
  { id: 'right-arm', label: 'right arm', minExposure: 0.30, minShare: 0.015 },
  { id: 'left-hand', label: 'left hand', minExposure: 0.30, minShare: 0.008 },
  { id: 'right-hand', label: 'right hand', minExposure: 0.30, minShare: 0.008 },
  { id: 'left-leg', label: 'left leg', minExposure: 0.30, minShare: 0.015 },
  { id: 'right-leg', label: 'right leg', minExposure: 0.30, minShare: 0.015 },
  // A foot's floor is lower than a limb's, and not as a concession: the sole is
  // an ellipse 28 units across sitting on the end cap of a 26-unit shin, so by
  // construction most of a foot is inside its own leg. A foot standing entirely
  // free exposes about a third of itself, which is the toes — so 0.28 is "the
  // toes clear everything", which is the thing the test is actually asking.
  { id: 'left-foot', label: 'left foot', minExposure: 0.28, minShare: 0.010 },
  { id: 'right-foot', label: 'right foot', minExposure: 0.28, minShare: 0.010 },
];

/**
 * The poses §19 names, and the file each one is.
 *
 * The brief's list is written in the language of the product ("looking at a
 * button", "quiz thinking"); the pose set is written in the language of the
 * drawing. This is the map, and it is here rather than in a document because a
 * pose that stops covering its situation should show up in the gate's output.
 */
const SITUATIONS = [
  ['idle', 'idle'], ['wave', 'wave'], ['talk', 'pointing · reassuring · looking at a button'],
  ['scrub', 'washing hands · hands together'], ['jump', 'jumping · hopping'],
  ['land', 'landing'], ['cheer', 'celebration'], ['walk', 'holding an object · leaning'],
  ['wait', 'sitting · quiz thinking'], ['sit', 'sitting (lily pad)'], ['catch', 'catching'],
  ['full', 'holding his tummy'], ['sleep', 'asleep'], ['blink', 'blinking'], ['face', 'avatar crop'],
];

/**
 * Painted area of an SVG, in pixels, measured off a canvas rather than a
 * screenshot so the page's own background cannot be counted as ink. Same
 * technique as `check-hop-fit.js`, and for the same reason.
 */
async function paintedArea(page, svg, side) {
  const b64 = Buffer.from(svg, 'utf8').toString('base64');
  return page.evaluate(async ({ b64, side }) => {
    const img = new Image();
    img.width = side; img.height = side;
    await new Promise((res, rej) => {
      img.onload = res;
      img.onerror = () => rej(new Error('the SVG did not decode'));
      img.src = 'data:image/svg+xml;base64,' + b64;
    });
    const canvas = document.createElement('canvas');
    canvas.width = side; canvas.height = side;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    ctx.clearRect(0, 0, side, side);
    ctx.drawImage(img, 0, 0, side, side);
    const d = ctx.getImageData(0, 0, side, side).data;
    let n = 0;
    for (let i = 3; i < d.length; i += 4) if (d[i] >= 128) n++;
    return n;
  }, { b64, side });
}

/** Which gate parts a pose actually draws. `face` is a crop with a head and
 *  nothing else, so asking it about legs would be asking the wrong question. */
function partsIn(pose, svg) {
  return GATE.filter((p) => svg.includes(`id="${p.id}"`));
}

async function silhouetteGate({ side = 384, write = true } = {}) {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 64, height: 64 } });
  await page.goto('about:blank');

  const rows = [];
  for (const [pose, situation] of SITUATIONS) {
    const flat = art.poseSVG(pose, { flat: true });
    const total = await paintedArea(page, flat, side);
    const parts = [];
    for (const part of partsIn(pose, flat)) {
      const without = await paintedArea(page, art.poseSVG(pose, { flat: true, omit: [part.id] }), side);
      const alone = await paintedArea(page, art.poseSVG(pose, { flat: true, only: [part.id] }), side);
      const unique = Math.max(0, total - without);
      parts.push({
        ...part,
        unique,
        own: alone,
        exposure: alone ? unique / alone : 0,
        share: total ? unique / total : 0,
      });
    }
    for (const p of parts) p.pass = p.exposure >= p.minExposure && p.share >= p.minShare;
    rows.push({ pose, situation, total, parts, pass: parts.every((p) => p.pass) });
  }
  await browser.close();

  if (write) {
    fs.mkdirSync(OUT, { recursive: true });
    for (const [pose] of SITUATIONS) {
      fs.writeFileSync(path.join(OUT, `silhouette-${pose}.svg`), art.poseSVG(pose, { flat: true }));
    }
  }
  return rows;
}

/**
 * The gate's findings, pose by pose — to the console, and to
 * `Art/render/hop-lab/silhouette-report.txt` next to the flat drawings it
 * measured, so the numbers and the pictures live together.
 */
function reportGate(rows) {
  const lines = [];
  const say = (line = '') => { lines.push(line); process.stdout.write(line + '\n'); };
  const width = 22;

  say('silhouette gate — flat, no facial detail, no outline');
  say('');
  for (const row of rows) {
    say(`${row.pose.padEnd(8)} ${row.pass ? 'pass' : 'FAIL'}   ${row.situation}`);
    const cells = row.parts.map((p) => `${p.label} ${(p.exposure * 100).toFixed(0)}%${p.pass ? ' ' : '!'}`);
    for (let i = 0; i < cells.length; i += 5) {
      say('         ' + cells.slice(i, i + 5).map((c) => c.padEnd(width)).join('').trimEnd());
    }
  }

  const bad = rows.filter((r) => !r.pass);
  say('');
  say('-'.repeat(74));
  if (!bad.length) {
    say(`all ${rows.length} poses read as flat silhouettes.`);
  } else {
    for (const row of bad) {
      for (const p of row.parts.filter((x) => !x.pass)) {
        say(`  ${row.pose}: ${p.label} shows ${(p.exposure * 100).toFixed(0)}% of itself ` +
          `(min ${(p.minExposure * 100).toFixed(0)}%), ${(p.share * 100).toFixed(1)}% of the silhouette ` +
          `(min ${(p.minShare * 100).toFixed(1)}%)`);
      }
    }
    say('');
    say('Fix in this order: pose → overlap → tone → spacing → stroke.');
    say('Thickening the outline cannot pass this test — it is measured without one.');
  }

  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, 'silhouette-report.txt'), lines.join('\n') + '\n');
  return bad.length ? 1 : 0;
}

// ---------------------------------------------------------------------------
// The contracts
// ---------------------------------------------------------------------------

/**
 * The two things outside this directory that read Hop's markup rather than his
 * picture, checked here so the failure arrives next to the change that caused it
 * rather than three scripts downstream.
 */
/**
 * The Swift pose table, read back out of `HopPose.swift`.
 *
 * Deliberately a small hand-rolled reader rather than anything general: the
 * input is one generated-looking switch statement in one file, and a parser that
 * fails loudly on markup it has not seen is worth more here than one that
 * shrugs and reports "no differences".
 */
function swiftPoses() {
  const src = fs.readFileSync(
    path.join(ROOT, 'HopPotty', 'DesignSystem', 'Components', 'HopPose.swift'), 'utf8');
  const from = src.indexOf('static func parameters(for pose: HopPose) -> HopPoseGeometry {');
  if (from < 0) throw new Error('HopPose.swift no longer has a parameters(for:) table');
  const body = src.slice(from);
  const out = {};
  const marks = [...body.matchAll(/\n\s*case \.`?(\w+)`?:/g)];
  for (let i = 0; i < marks.length; i++) {
    const at = marks[i].index + marks[i][0].length;
    const to = i + 1 < marks.length ? marks[i + 1].index : body.length;
    out[marks[i][1]] = body.slice(at, to);
  }
  return out;
}

/** The text inside `name(` … `)`, paren-balanced, or null. */
function callArgs(text, name) {
  const at = text.indexOf(name + '(');
  if (at < 0) return null;
  let depth = 0;
  for (let i = at + name.length; i < text.length; i++) {
    if (text[i] === '(') depth++;
    else if (text[i] === ')') {
      depth--;
      if (!depth) return text.slice(at + name.length + 1, i);
    }
  }
  return null;
}

const num = (s) => (s === undefined ? undefined : Number(s));
const one = (text, re) => { const m = re.exec(text); return m ? m : null; };

/** One Swift case as the same shape `hop-art.js` stores a pose in. */
function swiftPose(text) {
  const p = {};
  const scalar = (key) => {
    const m = one(text, new RegExp(`\\b${key}: (-?[\\d.]+)`));
    if (m) p[key] = num(m[1]);
  };
  ['lift', 'squash', 'tilt', 'lean', 'armsForward', 'bellyScale', 'torsoWidth',
    'torsoBottom', 'pawSpread'].forEach(scalar);
  // Swift spells these out; the generator's names are shorter.
  const armW = one(text, /\barmWidth: (-?[\d.]+)/);
  if (armW) p.armW = num(armW[1]);
  const armWT = one(text, /\barmTipWidth: (-?[\d.]+)/);
  if (armWT) p.armWTip = num(armWT[1]);
  if (p.pawSpread !== undefined) { p.pawHands = p.pawSpread; delete p.pawSpread; }
  const belly = one(text, /\bbelly: HopBellyGeometry\(cy: (-?[\d.]+), rx: (-?[\d.]+), ry: (-?[\d.]+)\)/);
  if (belly) p.belly = { cy: num(belly[1]), rx: num(belly[2]), ry: num(belly[3]) };
  const point = (key) => {
    const m = one(text, new RegExp(`\\b${key}: CGPoint\\(x: (-?[\\d.]+), y: (-?[\\d.]+)\\)`));
    if (m) p[key] = [num(m[1]), num(m[2])];
  };
  point('armL'); point('armR'); point('tongueTo');
  // Read each leg from its own argument list rather than one fixed-order
  // regex: the leg has grown fields twice now, and a regex that spells out
  // every field in order silently stops matching when one is added — which
  // reports the *defaults* as Swift's answer and makes a real mismatch look
  // like a different real mismatch.
  for (const side of ['legL', 'legR']) {
    const at = text.indexOf(`${side}: HopLegGeometry(`);
    if (at < 0) continue;
    const args = callArgs(text.slice(at), 'HopLegGeometry');
    if (args === null) continue;
    const hip = one(args, /hip: CGPoint\(x: (-?[\d.]+), y: (-?[\d.]+)\)/);
    const ankle = one(args, /ankle: CGPoint\(x: (-?[\d.]+), y: (-?[\d.]+)\)/);
    if (!hip || !ankle) continue;
    const leg = { hip: [num(hip[1]), num(hip[2])], ankle: [num(ankle[1]), num(ankle[2])] };
    const spread = one(args, /toeSpread: (-?[\d.]+)/);
    if (spread) leg.spread = num(spread[1]);
    const root = one(args, /rootWidth: (-?[\d.]+)/);
    if (root) leg.w1 = num(root[1]);
    const tip = one(args, /tipWidth: (-?[\d.]+)/);
    if (tip) leg.w2 = num(tip[1]);
    p[side] = leg;
  }
  const mouth = one(text, /\bmouth: \.(\w+)/);
  if (mouth) p.mouth = mouth[1];
  for (const flag of ['withPack', 'wiggling', 'sleeping']) {
    if (new RegExp(`\\b${flag}: true`).test(text)) p[flag] = true;
  }
  const eyes = callArgs(text, 'HopEyeGeometry');
  if (eyes !== null) {
    const e = {};
    const gaze = one(eyes, /gaze: CGSize\(width: (-?[\d.]+), height: (-?[\d.]+)\)/);
    if (gaze) e.gaze = [num(gaze[1]), num(gaze[2])];
    const blink = one(eyes, /blink: (-?[\d.]+)/);
    if (blink) e.blink = num(blink[1]);
    const mood = one(eyes, /mood: \.(\w+)/);
    if (mood) e.mood = mood[1];
    const lid = one(eyes, /lidDrop: (-?[\d.]+)/);
    if (lid) e.lidDrop = num(lid[1]);
    p.eyes = e;
  }
  return p;
}

/** The generator's own defaults, so "unset" compares equal to "set to the
 *  default" on either side. These are `figure()`'s destructuring defaults. */
const POSE_DEFAULTS = {
  lift: 0, squash: 0, tilt: 0, lean: 0, armsForward: 0,
  armL: [22, 103], armR: [128, 103],
  legL: { hip: [56, 124], ankle: [52, 146], spread: 1, w1: 26, w2: 18 },
  legR: { hip: [94, 124], ankle: [98, 146], spread: 1, w1: 26, w2: 18 },
  mouth: 'open', bellyScale: 1, torsoWidth: 58,
  withPack: false, wiggling: false, sleeping: false, tongueTo: null,
  eyes: { gaze: [0, 0], blink: 0, mood: 'happy', lidDrop: 0 },
};

function normalise(p) {
  const legOf = (l, d) => ({
    hip: (l && l.hip) || d.hip,
    ankle: (l && l.ankle) || d.ankle,
    spread: (l && (l.spread ?? l.toeSpread)) ?? d.spread,
    // A crouched haunch is a leg with a much wider root, so the widths are part
    // of the pose and have to be compared like everything else in it.
    w1: (l && (l.w1 ?? l.rootWidth)) ?? d.w1,
    w2: (l && (l.w2 ?? l.tipWidth)) ?? d.w2,
  });
  const bellyOf = (b) => (b ? { cy: b.cy, rx: b.rx, ry: b.ry } : null);
  const e = p.eyes || {};
  return {
    lift: p.lift ?? 0, squash: p.squash ?? 0, tilt: p.tilt ?? 0, lean: p.lean ?? 0,
    armsForward: p.armsForward ?? ((p.frontL || p.frontR) ? 1 : 0),
    armL: p.armL || POSE_DEFAULTS.armL, armR: p.armR || POSE_DEFAULTS.armR,
    legL: legOf(p.legL, POSE_DEFAULTS.legL), legR: legOf(p.legR, POSE_DEFAULTS.legR),
    mouth: p.mouth || 'open', bellyScale: p.bellyScale ?? 1, torsoWidth: p.torsoWidth ?? 58,
    torsoBottom: p.torsoBottom ?? null, belly: bellyOf(p.belly),
    armW: p.armW ?? 15, armWTip: p.armWTip ?? 11.5, pawHands: p.pawHands ?? 0,
    withPack: !!p.withPack, wiggling: !!p.wiggling, sleeping: !!p.sleeping,
    tongueTo: p.tongueTo || null,
    eyes: {
      gaze: e.gaze || [0, 0], blink: e.blink ?? 0,
      mood: e.mood || 'happy', lidDrop: e.lidDrop ?? 0,
    },
  };
}

/**
 * The generator's pose table against Swift's.
 *
 * This exists because the two have diverged before and nothing noticed: the
 * Swift port kept a stale canvas transform while the SVGs moved, so the app drew
 * a clipped frog while the renders showed a fixed one. One owner is the policy;
 * this is the check that the policy was kept.
 */
function checkPoseTables() {
  let bad = 0;
  const swift = swiftPoses();
  for (const name of Object.keys(art.POSE_PARAMS)) {
    if (!(name in swift)) {
      console.log(`  FAIL HopPose.swift has no case for \`${name}\``);
      bad++;
      continue;
    }
    const a = normalise(art.POSE_PARAMS[name]);
    const b = normalise(swiftPose(swift[name]));
    for (const key of Object.keys(a)) {
      if (JSON.stringify(a[key]) !== JSON.stringify(b[key])) {
        console.log(`  FAIL ${name}.${key}: hop-art.js says ${JSON.stringify(a[key])}, ` +
          `HopPose.swift says ${JSON.stringify(b[key])}`);
        bad++;
      }
    }
  }
  if (!bad) console.log(`  ok   all ${Object.keys(art.POSE_PARAMS).length} poses match HopPose.swift, parameter for parameter`);
  return bad;
}

/** The outline levels against `HopOutlineStyle`, for the same reason. */
function checkOutlineLevels() {
  const src = fs.readFileSync(
    path.join(ROOT, 'HopPotty', 'DesignSystem', 'Components', 'HopCharacterShapes.swift'), 'utf8');
  const named = { hero: 'hero', default: 'standard', scene: 'scene', small: 'small', highContrast: 'highContrast', off: 'off' };
  let bad = 0;
  for (const [level, swiftName] of Object.entries(named)) {
    const m = new RegExp(
      `static let ${swiftName} = HopOutlineStyle\\(exterior: ([\\d.]+), inner: ([\\d.]+), innerOpacity: ([\\d.]+)\\)`
    ).exec(src);
    if (!m) { console.log(`  FAIL HopOutlineStyle has no \`${swiftName}\``); bad++; continue; }
    const l = art.OUTLINE[level];
    if (Number(m[1]) !== l.exterior || Number(m[2]) !== l.inner || Number(m[3]) !== l.innerOpacity) {
      console.log(`  FAIL outline ${level}: hop-art.js has ${l.exterior}/${l.inner}/${l.innerOpacity}, ` +
        `HopOutlineStyle.${swiftName} has ${m[1]}/${m[2]}/${m[3]}`);
      bad++;
    }
  }
  if (!bad) console.log('  ok   all six outline levels match HopOutlineStyle');
  return bad;
}

/**
 * The canvas transform against `HopCanvas`.
 *
 * This is the one that actually went wrong: the Swift port kept a stale
 * `scale 3.2, offset (16, 0)` while the generator solved a new one from the
 * drawing, so the app clipped fourteen of fifteen poses while every render on
 * disk was fine. Three numbers, checked, and it cannot happen quietly again.
 */
function checkCanvas() {
  const src = fs.readFileSync(
    path.join(ROOT, 'HopPotty', 'DesignSystem', 'Components', 'HopCharacterShapes.swift'), 'utf8');
  const want = [
    ['referenceScale', /static let referenceScale: CGFloat = ([\d.]+)/, art.SCALE],
    ['referenceOrigin.x', /static let referenceOrigin = CGPoint\(x: ([\d.]+), y: [\d.]+\)/, art.OX],
    ['referenceOrigin.y', /static let referenceOrigin = CGPoint\(x: [\d.]+, y: ([\d.]+)\)/, art.OY],
    ['groundLine', /static let groundLine: CGFloat = ([\d.]+)\n/, art.GROUND],
    ['groundAnkle', /static let groundAnkle: CGFloat = ([\d.]+)/, art.ANKLE],
  ];
  let bad = 0;
  for (const [label, re, expected] of want) {
    const m = re.exec(src);
    if (!m) { console.log(`  FAIL HopCanvas has no ${label}`); bad++; continue; }
    if (Number(m[1]) !== expected) {
      console.log(`  FAIL HopCanvas.${label}: hop-art.js has ${expected}, Swift has ${m[1]}`);
      bad++;
    }
  }
  if (!bad) console.log('  ok   HopCanvas restates the generator\'s transform exactly');
  return bad;
}

/** The colour tokens against `HopPalette`, so neither language invents a green. */
function checkTokens() {
  const src = fs.readFileSync(
    path.join(ROOT, 'HopPottyKit', 'Sources', 'HopPottyDesignTokens', 'HopPalette.swift'), 'utf8');
  const want = {
    hopFillHighlight: art.T.fillHighlight,
    hopFillShadow: art.T.fillShadow,
    hopFillDeep: art.T.fillDeep,
    hopOutline: art.T.outline,
  };
  let bad = 0;
  for (const [token, hex] of Object.entries(want)) {
    const m = new RegExp(`static let ${token} = HopColorValue\\(hex: 0x([0-9A-Fa-f]{6})\\)`).exec(src);
    if (!m) { console.log(`  FAIL HopPalette has no \`${token}\``); bad++; continue; }
    if (`#${m[1].toUpperCase()}` !== hex.toUpperCase()) {
      console.log(`  FAIL ${token}: hop-art.js paints ${hex}, HopPalette says #${m[1].toUpperCase()}`);
      bad++;
    }
  }
  if (!/static let hopFill = hopGreen/.test(src)) {
    console.log('  FAIL HopPalette.hopFill is no longer hopGreen'); bad++;
  }
  if (!bad) console.log('  ok   Hop\'s colour tokens match HopPalette');
  return bad;
}

function checkContracts() {
  let bad = 0;
  const dir = path.join(ROOT, 'Art', 'character');

  const motion = require('./web/motion.js');
  const idle = fs.readFileSync(path.join(dir, 'hop-idle.svg'), 'utf8');
  const blink = fs.readFileSync(path.join(dir, 'hop-blink.svg'), 'utf8');
  if (motion.VARIANTS.blink(idle) === blink) {
    console.log('  ok   blinking hop-idle reproduces hop-blink.svg byte for byte');
  } else {
    console.log('  FAIL blinking hop-idle no longer reproduces hop-blink.svg');
    bad++;
  }
  for (const [name, variant] of [['gaze', 'gazeL'], ['smile', 'smile'], ['talk', 'talkShut']]) {
    const made = motion.VARIANTS[variant](idle);
    if (made !== idle) console.log(`  ok   motion.js can still derive ${name}`);
    else { console.log(`  FAIL motion.js's ${name} rule no longer matches the markup`); bad++; }
  }

  try {
    const widget = require('./widget-face.js');
    const built = widget.build ? widget.build() : null;
    const moods = widget.MOODS.length;
    console.log(`  ok   widget-face.js still lifts ${moods} heads out of the art` +
      (built && built.arts ? ` (${built.arts[0].shapes.length} shapes in the first)` : ''));
  } catch (error) {
    console.log(`  FAIL widget-face.js: ${error.message}`);
    bad++;
  }

  for (const pose of art.POSE_NAMES) {
    const svg = fs.readFileSync(path.join(dir, `hop-${pose}.svg`), 'utf8');
    const ids = [...svg.matchAll(/ id="([^"]+)"/g)].map((m) => m[1]);
    const dupes = ids.filter((id, i) => ids.indexOf(id) !== i);
    if (dupes.length) { console.log(`  FAIL hop-${pose}.svg repeats ids: ${[...new Set(dupes)].join(', ')}`); bad++; }
  }
  if (!bad) console.log('  ok   no pose repeats an id');

  bad += checkCanvas();
  bad += checkPoseTables();
  bad += checkOutlineLevels();
  bad += checkTokens();
  return bad ? 1 : 0;
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------

/**
 * Ids are unique per document, and the lab puts sixty Hops in one document.
 * Suffixing every id — and every `url(#…)` that points at one — keeps the eye
 * clips pointing at their own eyes, which is otherwise a very quiet bug: every
 * eye in the page clips to the *first* Hop's, and only a pose with a different
 * blink shows it.
 */
function namespaced(svg, suffix) {
  return svg
    .replace(/ id="([^"]+)"/g, (_m, id) => ` id="${id}-${suffix}"`)
    .replace(/url\(#([^)]+)\)/g, (_m, id) => `url(#${id}-${suffix})`);
}

function labPage() {
  const set = {};
  for (const [pose] of SITUATIONS) {
    set[pose] = {};
    for (const level of LEVELS) set[pose][level] = art.poseSVG(pose, { level });
    set[pose].flat = art.poseSVG(pose, { flat: true, flatColour: '#2C5A43' });
  }

  const cards = SITUATIONS.map(([pose, situation]) => `
      <section class="card" data-pose="${pose}">
        <header><h2>${pose}</h2><p>${situation}</p></header>
        <div class="grounds">
          ${GROUNDS.map((g) => `<div class="ground" data-ground="${g.id}" style="--bg:${g.css}">
            <div class="stage" data-slot="${pose}:${g.id}"></div>
            <span>${g.label}</span>
          </div>`).join('')}
        </div>
      </section>`).join('');

  return `<!doctype html>
<meta charset="utf-8">
<title>Hop — character lab</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  :root { color-scheme: light; --ink:#243047; --line:#EBE3D8; }
  * { box-sizing: border-box; }
  body { margin:0; font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;
         color:var(--ink); background:#F7F1E9; }
  header.top { position:sticky; top:0; z-index:5; background:#FFFCF8; border-bottom:1px solid var(--line);
               padding:14px 20px; display:flex; flex-wrap:wrap; gap:18px; align-items:center; }
  header.top h1 { font-size:15px; margin:0 12px 0 0; letter-spacing:.02em; }
  .group { display:flex; gap:6px; align-items:center; }
  .group b { font-weight:600; font-size:11px; text-transform:uppercase; letter-spacing:.08em; color:#7D766D; margin-right:4px; }
  button { font:inherit; font-size:12px; padding:5px 11px; border-radius:999px; border:1px solid var(--line);
           background:#fff; color:var(--ink); cursor:pointer; }
  button[aria-pressed="true"] { background:var(--ink); color:#fff; border-color:var(--ink); }
  main { padding:20px; display:grid; gap:18px; grid-template-columns:repeat(auto-fill,minmax(min(100%,560px),1fr)); }
  .card { background:#fff; border:1px solid var(--line); border-radius:16px; padding:14px 16px 16px; }
  .card header { display:flex; align-items:baseline; gap:10px; margin-bottom:10px; }
  .card h2 { font-size:14px; margin:0; }
  .card p { margin:0; font-size:12px; color:#7D766D; }
  .grounds { display:flex; gap:10px; overflow-x:auto; padding-bottom:2px; }
  .ground { flex:0 0 auto; display:flex; flex-direction:column; align-items:center; gap:6px; }
  .ground .stage { width:var(--hop); height:var(--hop); background:var(--bg); border-radius:12px;
                   display:grid; place-items:center; overflow:hidden; border:1px solid rgba(0,0,0,.06); }
  .ground span { font-size:10px; color:#7D766D; }
  .stage svg { width:100%; height:100%; display:block; }
  body { --hop:160px; }
  .note { grid-column:1/-1; font-size:12px; color:#5A544D; background:#FFF3D4; border:1px solid #FFD769;
          border-radius:12px; padding:10px 14px; }
</style>
<header class="top">
  <h1>Hop — character lab</h1>
  <div class="group" id="levels"><b>Outline</b>${SWITCHES.map((s) =>
    `<button data-level="${s.id}" title="${s.title}"${s.id === 'auto' ? ' aria-pressed="true"' : ''}>${s.label}</button>`).join('')}</div>
  <div class="group" id="sizes"><b>Size</b>${SIZES.map((s) =>
    `<button data-size="${s.id}"${s.id === 'medium' ? ' aria-pressed="true"' : ''}>${s.label}</button>`).join('')}</div>
  <div class="group"><b>View</b><button id="flat">Silhouette</button></div>
</header>
<main>
  <div class="note"><b>Auto</b> is what the app draws at that size. <b>Outline off</b> is the test that
  matters: pose, depth order and the four-step green ramp have to hold the character on their own, so that
  the outline is the last cue rather than the only one. If a pose only reads on <b>Strong</b>, the pose is
  wrong — fix it in the order pose → overlap → tone → spacing → stroke.</div>
  ${cards}
</main>
<script>
const ART = ${JSON.stringify(set)};
const AUTO = ${JSON.stringify(Object.fromEntries(SIZES.map((s) => [s.id, s.auto])))};
const PX = ${JSON.stringify(Object.fromEntries(SIZES.map((s) => [s.id, s.px])))};
let level = 'auto', size = 'medium', flat = false;

function ns(svg, suffix) {
  return svg.replace(/ id="([^"]+)"/g, (m, id) => ' id="' + id + '-' + suffix + '"')
            .replace(/url\\(#([^)]+)\\)/g, (m, id) => 'url(#' + id + '-' + suffix + ')');
}

function paint() {
  const resolved = flat ? 'flat' : (level === 'auto' ? AUTO[size] : level);
  document.body.style.setProperty('--hop', PX[size] + 'px');
  let n = 0;
  for (const stage of document.querySelectorAll('.stage')) {
    const [pose] = stage.dataset.slot.split(':');
    stage.innerHTML = ns(ART[pose][resolved], (n++).toString(36));
  }
}
for (const b of document.querySelectorAll('#levels button')) b.onclick = () => {
  level = b.dataset.level; flat = false;
  document.querySelectorAll('#levels button').forEach((x) => x.setAttribute('aria-pressed', x === b));
  document.getElementById('flat').setAttribute('aria-pressed', 'false');
  paint();
};
for (const b of document.querySelectorAll('#sizes button')) b.onclick = () => {
  size = b.dataset.size;
  document.querySelectorAll('#sizes button').forEach((x) => x.setAttribute('aria-pressed', x === b));
  paint();
};
document.getElementById('flat').onclick = (e) => {
  flat = !flat;
  e.currentTarget.setAttribute('aria-pressed', String(flat));
  paint();
};
paint();
</script>
`;
}

// ---------------------------------------------------------------------------
// Levels
// ---------------------------------------------------------------------------

function writeLevels() {
  const base = path.join(ROOT, 'Art', 'render', 'hop-levels');
  for (const level of LEVELS) {
    const dir = path.join(base, level);
    fs.mkdirSync(dir, { recursive: true });
    for (const pose of art.POSE_NAMES) {
      fs.writeFileSync(path.join(dir, `hop-${pose}.svg`), art.poseSVG(pose, { level }).trim() + '\n');
    }
    const l = art.OUTLINE[level];
    console.log(`  ${level.padEnd(13)} exterior ${String(l.exterior).padEnd(5)} inner ${String(l.inner).padEnd(5)} at ${l.innerOpacity}` +
      `   → ${path.relative(ROOT, dir)}`);
  }
  console.log('\nfit-check each with:  node Scripts/check-hop-fit.js --dir ' + path.relative(ROOT, base) + '/<level>');
}

// ---------------------------------------------------------------------------

async function main() {
  const argv = process.argv.slice(2);
  if (argv.includes('--contracts')) return checkContracts();
  if (argv.includes('--levels')) { writeLevels(); return 0; }
  if (argv.includes('--silhouette')) return reportGate(await silhouetteGate());

  fs.mkdirSync(OUT, { recursive: true });
  const file = path.join(OUT, 'index.html');
  fs.writeFileSync(file, labPage());
  console.log('wrote', path.relative(ROOT, file));
  console.log(`      ${SITUATIONS.length} poses × ${GROUNDS.length} grounds × ${LEVELS.length} outline levels`);
  return 0;
}

main().then((code) => process.exit(code)).catch((e) => { console.error(e); process.exit(2); });
