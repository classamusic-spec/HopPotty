#!/usr/bin/env node
/**
 * Splits the HopPotty lockup into the four layers the splash animates, and
 * emits them for both consumers.
 *
 *   Art/brand/hoppotty-logo.svg          the product owner's artwork (input)
 *     ↓
 *   Art/brand/layers/logo-*-{back,face}.svg   two files per layer, inline fills
 *   Art/brand/hoppotty-logo-flat.svg     the four layers recombined (proof)
 *   HopPotty/DesignSystem/Components/HopLogoArtwork.swift
 *   Scripts/web/logo-metrics.json       the same measurements, for the web
 *
 * ## Why this exists
 *
 * The animation the product owner asked for moves "Hop", "Potty" and the frog
 * independently, so the lockup has to be three (four, with the tagline) things
 * that can each carry their own transform. The delivered SVG is one flat
 * document, and — the part that forces this script — its white sticker outline
 * is a **single fused contour** wrapping the mascot and both words at once. One
 * path cannot be in three places, so it cannot simply be assigned to a layer.
 *
 * So the fills are taken exactly as drawn and only the *outline* is rebuilt: a
 * round-joined stroke of the same colour and width behind each layer's own
 * shapes, plus a second copy offset down by the same distance the original
 * silhouette hangs below the glyphs. Both numbers are measured from the
 * artwork (see OUTLINE / SHADOW below), and `Scripts/logo-check.js` renders the
 * recombination against the original and fails on the difference, so the
 * reconstruction stays honest every time either one changes.
 *
 * Nothing here recolours, redraws or "improves" the artwork. Every fill, every
 * curve and the paint order inside a layer are the ones in the file.
 *
 *   node Scripts/logo-art.js        regenerate
 *   node Scripts/logo-check.js      prove the result still matches the artwork
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'Art', 'brand', 'hoppotty-logo.svg');
const LAYER_DIR = path.join(ROOT, 'Art', 'brand', 'layers');
const FLAT = path.join(ROOT, 'Art', 'brand', 'hoppotty-logo-flat.svg');
const SWIFT = path.join(ROOT, 'HopPotty', 'DesignSystem', 'Components', 'HopLogoArtwork.swift');
const METRICS = path.join(ROOT, 'Scripts', 'web', 'logo-metrics.json');

/**
 * The sticker outline, measured from the artwork rather than chosen.
 *
 * The fused silhouette (`fill="#F4F4F4"`, the first path in the file) extends
 * 1.4–1.5 units beyond the glyphs on the left, right and top, and 2.7 below
 * them. That is one outline of ~1.45 all round plus a shadow offset of ~1.3
 * straight down — which is exactly the "white outline + soft grey drop shadow"
 * the lockup is meant to have, flattened by the exporter into one colour.
 */
const OUTLINE = 1.45;
const SHADOW = 1.30;
const BACKING = '#F4F4F4';

// ---------------------------------------------------------------------------
// Reading the artwork
// ---------------------------------------------------------------------------

/** `.cls-N { fill:#RRGGBB; stroke:… }` → `{ 'cls-N': { fill, stroke, … } }`. */
function styleClasses(src) {
  const out = {};
  const block = /<style[^>]*>([\s\S]*?)<\/style>/.exec(src);
  if (!block) return out;
  for (const rule of block[1].matchAll(/\.([\w-]+)\s*\{([^}]*)\}/g)) {
    const decls = {};
    for (const decl of rule[2].split(';')) {
      const i = decl.indexOf(':');
      if (i > 0) decls[decl.slice(0, i).trim()] = decl.slice(i + 1).trim();
    }
    out[rule[1]] = decls;
  }
  return out;
}

function readPaths(src) {
  const classes = styleClasses(src);
  const out = [];
  for (const m of src.matchAll(/<path\b([^>]*?)\/>/g)) {
    const attrs = m[1];
    const attr = (n) => {
      const r = new RegExp(`\\b${n}="([^"]*)"`).exec(attrs);
      return r ? r[1] : null;
    };
    const style = classes[attr('class')] || {};
    const fill = attr('fill') || style.fill || '#000000';
    const stroke = attr('stroke') || style.stroke || null;
    out.push({
      d: attr('d') || '',
      fill: fill === 'none' ? null : fill,
      stroke: stroke === 'none' ? null : stroke,
      strokeWidth: parseFloat(attr('stroke-width') || style['stroke-width'] || '0') || 0,
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Path normalisation
// ---------------------------------------------------------------------------

/**
 * Every path in the file, rewritten as absolute `M` / `L` / `C` / `Z`.
 *
 * The exporter emits relative `m c h s l v z` — six of the ten command forms,
 * no arcs and no quadratics, which is why this is forty lines rather than a
 * library. Normalising here means both consumers get the same four opcodes:
 * the SVG layers can be re-rendered by any browser, and the Swift side needs a
 * decoder that understands nothing but move/line/curve/close.
 */
function normalise(d) {
  const toks = d.match(/[a-zA-Z]|-?\d*\.?\d+(?:[eE][-+]?\d+)?/g) || [];
  const out = [];
  let i = 0, cmd = null, cx = 0, cy = 0, sx = 0, sy = 0, reflect = null;
  const num = () => parseFloat(toks[i++]);
  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i])) cmd = toks[i++];
    if (!cmd) throw new Error(`path data starts with a number: ${d.slice(0, 24)}`);
    const rel = cmd === cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M': {
        let x = num(), y = num();
        if (rel) { x += cx; y += cy; }
        out.push(['M', x, y]); cx = sx = x; cy = sy = y; reflect = null;
        cmd = rel ? 'l' : 'L';                     // an implicit lineto follows
        break;
      }
      case 'L': {
        let x = num(), y = num();
        if (rel) { x += cx; y += cy; }
        out.push(['L', x, y]); cx = x; cy = y; reflect = null;
        break;
      }
      case 'H': { let x = num(); if (rel) x += cx; out.push(['L', x, cy]); cx = x; reflect = null; break; }
      case 'V': { let y = num(); if (rel) y += cy; out.push(['L', cx, y]); cy = y; reflect = null; break; }
      case 'C': {
        let a1 = num(), b1 = num(), a2 = num(), b2 = num(), x = num(), y = num();
        if (rel) { a1 += cx; b1 += cy; a2 += cx; b2 += cy; x += cx; y += cy; }
        out.push(['C', a1, b1, a2, b2, x, y]); reflect = [a2, b2]; cx = x; cy = y;
        break;
      }
      case 'S': {
        let a2 = num(), b2 = num(), x = num(), y = num();
        if (rel) { a2 += cx; b2 += cy; x += cx; y += cy; }
        const a1 = reflect ? 2 * cx - reflect[0] : cx;
        const b1 = reflect ? 2 * cy - reflect[1] : cy;
        out.push(['C', a1, b1, a2, b2, x, y]); reflect = [a2, b2]; cx = x; cy = y;
        break;
      }
      case 'Z': out.push(['Z']); cx = sx; cy = sy; reflect = null; break;
      default: throw new Error(`unsupported path command "${cmd}"`);
    }
  }
  return out;
}

/** Tight-ish bounds: curves are sampled rather than solved. Used to sort layers. */
function bounds(segs) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  const hit = (x, y) => { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); };
  let cx = 0, cy = 0;
  for (const s of segs) {
    if (s[0] === 'M' || s[0] === 'L') { hit(s[1], s[2]); cx = s[1]; cy = s[2]; }
    else if (s[0] === 'C') {
      for (let t = 0; t <= 1.0001; t += 0.05) {
        const u = 1 - t;
        hit(u * u * u * cx + 3 * u * u * t * s[1] + 3 * u * t * t * s[3] + t * t * t * s[5],
            u * u * u * cy + 3 * u * u * t * s[2] + 3 * u * t * t * s[4] + t * t * t * s[6]);
      }
      cx = s[5]; cy = s[6];
    }
  }
  return { x0, y0, x1, y1 };
}

const round = (n) => (Math.round(n * 1000) / 1000);
const emit = (segs) => segs.map((s) => s[0] + (s.length > 1 ? ' ' + s.slice(1).map(round).join(' ') : '')).join(' ');

/** One path's contours, split at each `M`. */
function contours(segs) {
  const out = [];
  for (const s of segs) {
    if (s[0] === 'M' || !out.length) out.push([]);
    out[out.length - 1].push(s);
  }
  return out;
}

/** Signed area of a contour, from a coarse flattening. Only its sign is used. */
function signedArea(segs) {
  const pts = [];
  let cx = 0, cy = 0;
  for (const s of segs) {
    if (s[0] === 'M' || s[0] === 'L') { pts.push([s[1], s[2]]); cx = s[1]; cy = s[2]; }
    else if (s[0] === 'C') {
      for (let k = 1; k <= 8; k++) {
        const t = k / 8, u = 1 - t;
        pts.push([
          u * u * u * cx + 3 * u * u * t * s[1] + 3 * u * t * t * s[3] + t * t * t * s[5],
          u * u * u * cy + 3 * u * u * t * s[2] + 3 * u * t * t * s[4] + t * t * t * s[6],
        ]);
      }
      cx = s[5]; cy = s[6];
    }
  }
  let a = 0;
  for (let i = 0; i < pts.length; i++) {
    const [x0, y0] = pts[i], [x1, y1] = pts[(i + 1) % pts.length];
    a += x0 * y1 - x1 * y0;
  }
  return a / 2;
}

/** The same contour, walked the other way round. */
function reverseContour(segs) {
  const drawn = segs.filter((s) => s[0] !== 'Z');
  const start = [drawn[0][1], drawn[0][2]];
  const ends = [start, ...drawn.slice(1).map((s) => (s[0] === 'C' ? [s[5], s[6]] : [s[1], s[2]]))];
  const out = [['M', ...ends[ends.length - 1]]];
  for (let i = drawn.length - 1; i >= 1; i--) {
    const s = drawn[i], to = ends[i - 1];
    out.push(s[0] === 'C' ? ['C', s[3], s[4], s[1], s[2], to[0], to[1]] : ['L', to[0], to[1]]);
  }
  out.push(['Z']);
  return out;
}

/**
 * A layer's shapes as one path whose every contour winds the same way.
 *
 * This is what the sticker outline is filled from, and the winding is the whole
 * point. A letter is one path with two contours — the ring of the "o" and its
 * counter, wound in opposite directions so the counter reads as a hole. Fill
 * that as-is and the backing has a hole in it too, and the page shows through
 * the middle of every "o" and "p"; the artwork's own silhouette is *solid*
 * there. Turning every contour the same way makes a non-zero fill of the whole
 * layer the union of its shapes, which is exactly the silhouette, in one path.
 */
function unionPath(shapes) {
  const out = [];
  for (const s of shapes) {
    for (const contour of s.contourSegs) {
      out.push(emit(signedArea(contour) < 0 ? reverseContour(contour) : contour));
    }
  }
  return out.join(' ');
}

// ---------------------------------------------------------------------------
// Which layer a shape belongs to
// ---------------------------------------------------------------------------

/**
 * Four layers, decided by geometry rather than by a table of path indices.
 *
 * An index table would be wrong the first time the artwork is re-exported with
 * one more speckle. These rules survive that, and every one of them is checked
 * against `EXPECTED` below — a re-export that breaks an assumption fails the
 * build loudly instead of quietly putting the frog's cheek in the wordmark.
 *
 *   backing   the fused sticker silhouette. Dropped: rebuilt per layer.
 *   tagline   everything inside the yellow pill — the pill, "Pause. Potty.
 *             Play." and the six sparkles.
 *   mascot    everything sitting above the wordmark's cap line (the frog: head,
 *             face, belly patch, arms and hands). Nothing in the wordmark
 *             reaches as high as y=55; nothing in the mascot reaches lower.
 *   hop/potty the wordmark, split at the gap between "Hop" and "Potty".
 */
const MASCOT_FLOOR = 55;      // mascot shapes end above this; glyphs end below it
const WORD_SPLIT = 75.4;      // the gap between "Hop" (…74.7) and "Potty" (76.1…)

const EXPECTED = { backing: 1, tagline: 24, mascot: 23, hop: 3, potty: 7 };

function classify(shapes) {
  const pill = shapes
    .filter((s) => s.fill && s.fill.toUpperCase() === '#FADE67')
    .sort((a, b) => (b.bb.x1 - b.bb.x0) - (a.bb.x1 - a.bb.x0))[0];
  if (!pill) throw new Error('no yellow tagline pill found — has the artwork changed?');

  const inPill = (bb) =>
    bb.x0 >= pill.bb.x0 - 1 && bb.x1 <= pill.bb.x1 + 1 &&
    bb.y0 >= pill.bb.y0 - 1 && bb.y1 <= pill.bb.y1 + 1;

  for (const s of shapes) {
    if (s.fill && s.fill.toUpperCase() === BACKING) s.layer = 'backing';
    else if (inPill(s.bb)) s.layer = 'tagline';
    else if (s.bb.y1 < MASCOT_FLOOR) s.layer = 'mascot';
    else s.layer = (s.bb.x0 + s.bb.x1) / 2 < WORD_SPLIT ? 'hop' : 'potty';
  }

  const counts = {};
  for (const s of shapes) counts[s.layer] = (counts[s.layer] || 0) + 1;
  for (const [layer, n] of Object.entries(EXPECTED)) {
    if (counts[layer] !== n) {
      throw new Error(
        `layer "${layer}" holds ${counts[layer] || 0} shapes, expected ${n}. The artwork ` +
        `changed shape — re-check MASCOT_FLOOR / WORD_SPLIT and update EXPECTED.`
      );
    }
  }
  return shapes;
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

/** Which layers wear the sticker outline. The tagline pill does not. */
const OUTLINED = { mascot: true, hop: true, potty: true, tagline: false };

/**
 * Which layer covers which.
 *
 * The artwork paints the frog last, over the wordmark. The splash paints it
 * *under* the wordmark instead, for one reason: the product owner asked for a
 * mascot that "pops up behind the wording", and a frog painted last rises in
 * front of the letters rather than out from behind them.
 *
 * This costs nothing, and that is measured rather than assumed. The two orders
 * render identically — the hands overlap the letters by less than half a unit,
 * and where they do, hand and letter are the same green (#5CBC5C).
 * `Scripts/logo-check.js` reports the same 0.012% either way.
 */
const PAINT_ORDER = ['tagline', 'mascot', 'hop', 'potty'];

/**
 * A layer, in two parts: `back` (its rebuilt sticker outline) and `face` (the
 * artwork's own fills).
 *
 * **Two parts, not one, and this is the whole trick.** The artwork's silhouette
 * is a single shape *behind everything*, so the frog's white edge never covers
 * a letter. Give each layer a self-contained outline-then-fills and it does:
 * the mascot is painted last, so its edge lands on top of the wordmark and the
 * letters grow a white bite out of their crowns.
 *
 * Splitting the layer lets the splash paint all four backs and then all four
 * faces. Every layer still carries its own edge wherever it travels to, and at
 * rest the four edges merge underneath the fills — which is the original
 * drawing, and `Scripts/logo-check.js` measures how nearly.
 *
 * The outline is one path — `unionPath`'s — filled and then stroked, so it is
 * the layer's solid silhouette pushed out by `OUTLINE`. It is drawn twice, once
 * offset down by `SHADOW` and once in place, because that is what the original
 * silhouette is: an outline and a drop shadow flattened into one flat colour.
 * Two copies of one flat colour union into exactly that.
 *
 * Deliberately no `<style>` block and no `class` attributes anywhere in the
 * output. The prototype inlines every screen into one document, and `.cls-3` is
 * not a name — it would repaint every other drawing on the page.
 */
function layerParts(shapes, { indent = '  ', outlined = true } = {}) {
  const face = [];
  for (const s of shapes) {
    if (s.fill) face.push(`<path d="${s.d}" fill="${s.fill}"/>`);
    if (s.stroke) {
      face.push(
        `<path d="${s.d}" fill="none" stroke="${s.stroke}" stroke-width="${round(s.strokeWidth)}" ` +
        `stroke-linecap="round"/>`
      );
    }
  }
  const faceMarkup = face.map((p) => indent + p).join('\n');
  if (!outlined) return { back: '', face: faceMarkup, union: null };

  const union = unionPath(shapes);
  const dilated =
    `<path d="${union}" fill="${BACKING}"/>\n${indent}  ` +
    `<path d="${union}" fill="none" stroke="${BACKING}" stroke-width="${round(OUTLINE * 2)}" ` +
    `stroke-linejoin="round" stroke-linecap="round"/>`;

  const back = [
    `${indent}<g transform="translate(0 ${SHADOW})">`,
    `${indent}  ${dilated}`,
    `${indent}</g>`,
    `${indent}<g>`,
    `${indent}  ${dilated}`,
    `${indent}</g>`,
  ].join('\n');
  return { back, face: faceMarkup, union };
}

const HEADER = (name, part) =>
  `<!-- Generated by Scripts/logo-art.js from Art/brand/hoppotty-logo.svg. Do not edit.\n` +
  `     ${name} — the ${part} of one layer of the lockup, drawn in the full\n` +
  `     164.8 x 95 box so the layers stack without alignment maths. Fills are\n` +
  `     inline: this markup is inlined into a document with a dozen other\n` +
  `     drawings, where a class named .cls-3 would repaint all of them. -->`;

const wrapSVG = (name, part, body, viewBox) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">\n` +
  `${HEADER(name, part)}\n${body}\n</svg>\n`;

/** The Swift table: the same absolute path strings, one value per layer. */
function swiftSource(byLayer, parts, viewBox) {
  const layerConst = (layer) => {
    const body = byLayer[layer].map((s) => {
      const hex = (c) => (c ? `0x${c.replace('#', '').toUpperCase()}` : 'nil');
      return `            HopLogoShape(d: "${s.d}", fill: ${hex(s.fill)}, stroke: ${hex(s.stroke)}, strokeWidth: ${round(s.strokeWidth)}),`;
    }).join('\n');
    const union = parts[layer].union ? `"${parts[layer].union}"` : 'nil';
    const b = byLayer[layer].reduce((acc, s) => ({
      x0: Math.min(acc.x0, s.bb.x0), y0: Math.min(acc.y0, s.bb.y0),
      x1: Math.max(acc.x1, s.bb.x1), y1: Math.max(acc.y1, s.bb.y1),
    }), { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity });
    const box = `CGRect(x: ${round(b.x0)}, y: ${round(b.y0)}, ` +
      `width: ${round(b.x1 - b.x0)}, height: ${round(b.y1 - b.y0)})`;
    return `    static let ${layer} = HopLogoLayerArt(\n` +
      `        shapes: [\n${body}\n        ],\n` +
      `        silhouette: ${union},\n` +
      `        bounds: ${box}\n    )`;
  };
  const box = viewBox.split(/[\s,]+/);

  return `// Generated by Scripts/logo-art.js from Art/brand/hoppotty-logo.svg. Do not edit.
//
// The product owner's lockup, as path data, split into the four layers the
// splash animates. Every string is the artwork's own curves with the exporter's
// relative commands resolved to absolute \`M\` / \`L\` / \`C\` / \`Z\` — no shape was
// redrawn and no colour was changed. \`HopLogoView.swift\` turns these into
// \`Path\`s; it is also the file to read for what \`silhouette\` is for.
//
// Paint order, back to front: ${PAINT_ORDER.join(', ')} — see PAINT_ORDER in the
// generator for why the frog is under the wordmark and not over it. It is
// \`HopLogoLayer.allCases\` that has to agree with this line.
//
// Regenerate with:  node Scripts/logo-art.js
// Verify with:      node Scripts/logo-check.js

import CoreGraphics

enum HopLogoArtwork {

    /// The box every layer is drawn in. Layers share it, so stacking them needs
    /// no alignment arithmetic — only a transform per layer.
    static let viewBox = CGRect(x: ${box[0]}, y: ${box[1]}, width: ${box[2]}, height: ${box[3]})

    /// The sticker outline, rebuilt per layer because the artwork's own is one
    /// fused contour around the whole lockup and a single path cannot travel in
    /// three directions. Both numbers are measured from that contour.
    static let outlineWidth: CGFloat = ${round(OUTLINE * 2)}
    static let shadowOffset: CGFloat = ${round(SHADOW)}
    static let backingColor: UInt32 = 0x${BACKING.replace('#','').toUpperCase()}

${layerConst('mascot')}

${layerConst('hop')}

${layerConst('potty')}

${layerConst('tagline')}
}
`;
}

// ---------------------------------------------------------------------------

function build() {
  const src = fs.readFileSync(SRC, 'utf8');
  const viewBox = (/viewBox="([^"]+)"/.exec(src) || [, '0 0 164.8 95'])[1].trim();

  const shapes = [];
  let dropped = 0;
  for (const raw of readPaths(src)) {
    const segs = normalise(raw.d);
    // A lone moveto draws nothing. The artwork carries one (`class="cls-15"`,
    // no fill of its own); it is dropped rather than carried into two outputs.
    if (!segs.some((s) => s[0] === 'L' || s[0] === 'C')) { dropped++; continue; }
    shapes.push({ ...raw, d: emit(segs), contourSegs: contours(segs), bb: bounds(segs) });
  }
  classify(shapes);

  const byLayer = { mascot: [], hop: [], potty: [], tagline: [] };
  for (const s of shapes) if (s.layer !== 'backing') byLayer[s.layer].push(s);

  // The artwork's own order, with only the fused silhouette lifted out of it.
  const order = ['tagline', 'hop', 'potty', 'mascot'];
  const parts = {};
  for (const name of order) {
    parts[name] = layerParts(byLayer[name], { outlined: OUTLINED[name] });
  }

  fs.mkdirSync(LAYER_DIR, { recursive: true });
  const written = [];
  for (const name of order) {
    for (const [part, label] of [['back', 'sticker outline'], ['face', 'artwork']]) {
      const file = path.join(LAYER_DIR, `logo-${name}-${part}.svg`);
      if (!parts[name][part]) { fs.rmSync(file, { force: true }); continue; }
      fs.writeFileSync(file, wrapSVG(`logo-${name}-${part}`, label, parts[name][part], viewBox));
      written.push(`logo-${name}-${part}`);
    }
  }

  // The recombination: every layer's outline, then every layer's fills. This is
  // what the splash draws once it has landed; `Scripts/logo-check.js` measures
  // it against the artwork.
  const group = (name, part) => parts[name][part]
    ? `  <g id="${part}-${name}">\n${parts[name][part].replace(/^ {2}/gm, '    ')}\n  </g>`
    : '';
  fs.writeFileSync(FLAT,
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">\n` +
    `${HEADER('hoppotty-logo-flat', 'four layers recombined')}\n` +
    [...order.map((n) => group(n, 'back')), ...PAINT_ORDER.map((n) => group(n, 'face'))]
      .filter(Boolean).join('\n') +
    `\n</svg>\n`);

  fs.writeFileSync(SWIFT, swiftSource(byLayer, parts, viewBox));

  // The same measurements the Swift gets, for the web. The prototype's splash
  // has to start a word exactly as far off-screen as the app's does, and that
  // distance is a function of how much of the box the word's drawing occupies —
  // so both sides read it from here rather than from two sets of numbers.
  const box = viewBox.split(/[\s,]+/).map(Number);
  const metrics = {
    generatedBy: 'Scripts/logo-art.js',
    viewBox: { x: box[0], y: box[1], width: box[2], height: box[3] },
    outlineWidth: round(OUTLINE * 2),
    shadowOffset: round(SHADOW),
    backingColor: BACKING,
    paintOrder: PAINT_ORDER,
    outlined: order.filter((n) => OUTLINED[n]),
    layers: Object.fromEntries(order.map((name) => {
      const b = byLayer[name].reduce((acc, s) => ({
        x0: Math.min(acc.x0, s.bb.x0), y0: Math.min(acc.y0, s.bb.y0),
        x1: Math.max(acc.x1, s.bb.x1), y1: Math.max(acc.y1, s.bb.y1),
      }), { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity });
      return [name, {
        x: round(b.x0), y: round(b.y0),
        width: round(b.x1 - b.x0), height: round(b.y1 - b.y0),
      }];
    })),
  };
  fs.writeFileSync(METRICS, JSON.stringify(metrics, null, 2) + '\n');

  const counts = order.map((n) => `${n} ${byLayer[n].length}`).join(', ');
  console.log(`logo-art: ${shapes.length} shapes (${counts}); ${dropped} empty path dropped`);
  console.log(`  → Art/brand/layers/{${written.join(',')}}.svg`);
  console.log(`  → Art/brand/hoppotty-logo-flat.svg`);
  console.log(`  → HopPotty/DesignSystem/Components/HopLogoArtwork.swift`);
  console.log(`  → Scripts/web/logo-metrics.json`);
  return { byLayer, viewBox };
}

if (require.main === module) build();
module.exports = { build, OUTLINE, SHADOW, BACKING, normalise, bounds };
