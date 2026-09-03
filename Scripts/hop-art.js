#!/usr/bin/env node
/**
 * Hop's rig, and the fifteen drawings it emits.
 *
 * Hop is drawn in a 150-wide reference space (the head is 122 units across,
 * x 13.5…136.5) and scaled onto the 512×512 canvas the app and the SwiftUI port
 * use. Every number here was converted from the owner's two reference drawings
 * at **6.25 px per unit** (their head is 765 px wide on a 1366 canvas, so
 * 765 / 122), which keeps the head exactly the size it was and lets the canvas
 * transform, `FEET`, the chip crop and the widget crop all stay where they are.
 *
 * ## Two bodies, one head, one outline
 *
 * The owner's instruction is that the *outline treatment* must match the
 * references, that standing poses use the reference-2 body, and that anything
 * on the ground or a lily pad uses the reference-1 body. So a pose picks a
 * body:
 *
 *   * `standing` — a rounded torso with a cream circle belly, ta-da arms out
 *     to the sides, two straight leg columns and three-lobed feet. idle, blink,
 *     talk, wave, walk, cheer, jump, scrub, full, and the `face` crop.
 *   * `crouch` — a tall cream oval belly, two fat haunches either side of it,
 *     back feet at the outer corners and the front arms coming straight down
 *     to hands on the ground: four limbs touching, back-foot hand hand
 *     back-foot. sit, catch, wait, sleep, land.
 *
 * The head is identical in both and sits directly on the body.
 *
 * The style is flat sticker: one green, one cream, and **one outline on every
 * boundary** — the exterior, the belly's edge, each arm, each hand and each of
 * its three fingers, each leg, each foot and each of its three toes, the eye
 * whites and the mouth. The internal boundaries are the same width, the same
 * colour and fully opaque, exactly like the outside edge. There is no lighter
 * internal rim and no tonal ramp; the reference has neither.
 *
 * ## How the outline is built
 *
 * The drawing is a small scene graph — `NODES` below — of named parts with
 * stable ids (`hop-root`, `shadow`, `body`, `belly`, `head`, `eyes-group`,
 * `left-eye`, `right-eye`, `left-pupil`, `right-pupil`, `mouth`, `cheeks`,
 * `left-arm`, `right-arm`, `left-hand`, `right-hand`, `left-leg`, `right-leg`,
 * `left-foot`, `right-foot`, `optional-bag`, `accent-details`).
 *
 * 1. **`#hop-silhouette`** — every body shape at once, grown by the outline
 *    width and painted in one opaque `hop-outline`, under everything. One flat
 *    colour has no interior seams, so all that survives is Hop's outside edge.
 * 2. **Each part's own rim** — the same shapes grown by the same width, drawn
 *    directly under that part's fill. Parts are drawn in depth order, so a rim
 *    lands exactly where its part crosses something already drawn: an arm on a
 *    haunch, a hand on the belly, a finger on the finger beside it, a foot on
 *    its leg, the head on everything. Where a rim coincides with the exterior it
 *    disappears into the silhouette, so it costs nothing on the outside.
 *
 * Fingers and toes are each their own node so that the lines *between* them
 * exist. They radiate from one point at the same radius, so their base caps
 * share one circle and the only line they leave on the limb behind them is a
 * single wrist (or ankle) arc.
 *
 * The outline width is a *state*, not a per-screen number — `OUTLINE` — chosen
 * by what Hop has to survive (his size, his ground, Increase Contrast). It is
 * responsive: heavier at 64pt than at 320pt, because a stroke that is right at
 * hero size is under a pixel on a chip. `vector-effect="non-scaling-stroke"`
 * was evaluated and rejected for the opposite reason: a device-pixel stroke is
 * eight times heavier relative to the body at 64px than at 512px.
 *
 * ## Contracts this file must not break
 *
 * **`Scripts/web/motion.js`** derives blink/gaze/smile/talk frames by rewriting
 * the eye and mouth markup with regular expressions, and its blink applied to
 * `hop-idle.svg` must reproduce `hop-blink.svg` byte for byte. Its blink rule
 * keys on a bare `<g>` immediately followed by the eye's `<clipPath>` and ends
 * at the first `</g></g>` — so `left-eye`/`right-eye` wrap that group from the
 * *outside*, `left-pupil`/`right-pupil` are ids on the circles rather than
 * groups, the closed-eye line keeps its exact markup, and the eye centres are
 * numbers whose ±10 and +3/+12 offsets are exact in binary.
 *
 * **`Scripts/widget-face.js`** lifts the widget's head out of this art by taking
 * the head's share of `#hop-silhouette` plus everything from `#head` onward,
 * finds the head by the crown ellipse (`isCrown` there restates `CROWN` here),
 * and throws on any paint it does not know. So `#head` is always the last body
 * node, it opens with its own rim, the crown ellipse is its first fill, and
 * nothing inside it is anything but `<circle>`, `<ellipse>` and `<path>`.
 *
 * `node Scripts/hop-lab.js --contracts` checks all of the above and the Swift
 * mirror; `node Scripts/check-hop-fit.js` measures that every pose fits.
 *
 *   node Scripts/hop-art.js                 # the fifteen shipped files
 *   node Scripts/hop-art.js --level small   # the same set at another level
 */
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

/**
 * Hop's colours. `HopCharacterPalette` in the app carries the same values, and
 * `hop-lab.js --contracts` checks that it does. Two are brand tokens — the body
 * is `HopPalette.hopGreen`, the outline is `HopPalette.hopOutline` — and the
 * line features share the brand's `hopGreenInk`. Everything else is the
 * reference drawing's own value and belongs to the character alone.
 */
const T = {
  /** The one body green: head, torso, limbs. `HopPalette.hopGreen`. */
  fill: '#63C88A',
  /** The three forehead spots and the wiggle marks — a step darker, no outline. */
  spot: '#45A971',
  /** The outline, everywhere. A saturated deep green. `HopPalette.hopOutline`. */
  outline: '#1E7A32',
  /** Nostrils, closed-eye lines, closed mouths, the z's. `HopPalette.hopGreenInk`. */
  ink: '#1B5E39',
  belly: '#F5E6A3',
  cheek: '#F4A0A0',
  eyeWhite: '#FFFFFF',
  pupil: '#0D1B3E',
  highlight: '#FFFFFF',
  mouthInterior: '#8B1A1A',
  tongue: '#E84A5F',
  bagBody: '#C98A5B',
  bagStrap: '#A76F46',
  shadow: '#243047',
};

/**
 * The outline states, in reference units. One number each: the visible width
 * of every boundary, outside and inside alike.
 *
 * `hero` is the reference exactly — 14 px on a 765 px head is 2.24 units. The
 * others step up as Hop gets smaller, because the same width that is right at
 * 320pt is under a pixel at 64pt:
 *
 *   hero          200pt and up
 *   default       the shipped files: cream, cards, white, most of the app
 *   scene         over illustration — pond water, vegetation green, dark sky
 *   small         28–96pt: chips, list rows, the tab bar
 *   highContrast  Increase Contrast, and any accessibility appearance
 *
 * The ceiling is the canvas, not taste: `check-hop-fit.js` fails below 6 units
 * of clear air, and `jump`'s domes and every standing pose's toes are the ink
 * nearest an edge. 3.0 leaves 8 at the top and 7 at the bottom.
 */
const OUTLINE = {
  off: { width: 0 },
  hero: { width: 2.2 },
  default: { width: 2.4 },
  scene: { width: 2.6 },
  small: { width: 2.8 },
  highContrast: { width: 3.0 },
};

// ---------------------------------------------------------------------------
// The stage: where the reference space lands on the canvas
// ---------------------------------------------------------------------------

/**
 * How the reference space is placed on the canvas.
 *
 * `STAGE` is the reference-space rectangle the whole pose set is built to fit;
 * it is scaled to the canvas with `MARGIN` of clear air on the binding axis
 * (height) and centred on both. It is symmetric about x = 75, so widening it
 * for the ta-da arms moves nothing: the transform is the one the screens, the
 * widget and `HopCanvas` already restate.
 */
const CANVAS = 512;
/** Minimum clear air on every side, in canvas pixels. */
const MARGIN = 12;
/** The reference-space rectangle every pose is drawn to fit. */
const STAGE = { x0: -6, y0: -3, x1: 156, y1: 164 };
/** Reference y the toes touch down on. Poses are built to it. */
const GROUND = 163.6;
/** Reference y of the ankle of a standing leg whose toes are on `GROUND`. */
const ANKLE = 150;

/** Rounded to a tenth so the SwiftUI port carries a number, not a fraction. */
const SCALE = Math.floor((CANVAS - 2 * MARGIN) /
  Math.max(STAGE.x1 - STAGE.x0, STAGE.y1 - STAGE.y0) * 10) / 10;
const OX = +(CANVAS / 2 - SCALE * (STAGE.x0 + STAGE.x1) / 2).toFixed(3);
const OY = +(CANVAS / 2 - SCALE * (STAGE.y0 + STAGE.y1) / 2).toFixed(3);
/** Where the feet land in the box. Screens position Hop by this fraction. */
const FEET_FRACTION = (OY + SCALE * GROUND) / CANVAS;

// ---------------------------------------------------------------------------
// Anatomy, in reference coordinates (reference px ÷ 6.25; x centred on 75)
// ---------------------------------------------------------------------------

// The head. Two big domes on a wide jaw, with a crown between them that sits
// well below the domes' tops — that dip is the "M" of the silhouette.
const EYE_L = { cx: 41.5, cy: 27 };
const EYE_R = { cx: 108.5, cy: 27 };
const DOME_R = 21.5;
const CROWN = { cx: 75, cy: 40, rx: 36, ry: 23 };
const JAW = { cx: 75, cy: 55, rx: 61.5, ry: 30 };
const WHITE_R = 11.2;
const PUPIL_R = 9.3;
/** The pupil sits slightly low and slightly inward of the white's centre. */
const PUPIL_OFFSET = { inward: 0.6, down: 1 };
/** One catchlight, top-left of the pupil, about 30% of the pupil's diameter. */
const HIGHLIGHT = { dx: -3, dy: -3.2, r: 2.8 };
const FACE_CENTRE = [75, 50];

const SPOTS = [[75, 23, 3.8], [70.5, 28.5, 2.4], [79.5, 28.5, 2.4]];
const NOSTRILS = { y: 43.5, xs: [66.5, 83.5], r: 1.9 };
const CHEEKS = { y: 54.5, xs: [31.5, 118.5], r: 7.2 };
const MOUTH_D = 'M 49.5 48.5 Q 75 52 100.5 48.5 C 100 62 90 72.2 75 72.2 C 60 72.2 50 62 49.5 48.5 Z';
const TONGUE_IN = { cx: 75, cy: 67.5, rx: 16, ry: 8.8 };

// Limbs.
const ARM_W = 11.2;
/** Three fingers fan about the arm's own direction: up, out, down. Drawn in
 *  this order so the middle one lands on top with a clean line either side. */
const FINGER_ANGLES = [-60, 60, 0];
const FINGER_LEN = 9.5;
/** A touch narrower than the arm, so the wrist reads as a wrist. */
const FINGER_W = 9.6;
const LEG_W = 15.2;
const TOE_LEN = 7.5;
const TOE_W = 9.5;
/** The toes fan from a point just outward and below the ankle. */
const FOOT_OFFSET = { outward: 2, down: 1 };
/** The crouch haunch: a fat lobe, tilted so its bottom swings outward. */
const HAUNCH = { rx: 18.5, ry: 25, tilt: 15 };

/**
 * What differs between the two bodies, besides the poses that use them: where
 * the arms hang from, how the toes fan (measured from straight down, outward
 * positive), the torso, and which side of the torso the arms are on.
 */
const BODIES = {
  standing: {
    shoulderL: [50.5, 94.5], shoulderR: [99.5, 94.5],
    toes: [-40, 70, 15],
    torso: { top: 70, bottom: 139, r: 16 },
    // Arms attach at the torso's sides: drawn before it, so the torso's own
    // edge is the boundary and no shoulder seam is drawn on the chest.
    armsInFront: false,
  },
  crouch: {
    shoulderL: [44, 90], shoulderR: [106, 90],
    toes: [0, 80, 40],
    torso: { x0: 51, x1: 99, top: 70, bottom: 144, r: 20 },
    // The front legs are in front of the belly, as a sitting frog's are.
    armsInFront: true,
  },
};

// ---------------------------------------------------------------------------
// Primitives
//
// A part is a list of shape descriptors rather than markup, because every part
// has to be emitted three times — inflated into the silhouette, inflated into
// its own rim, and filled — and three hand-written copies of a leg is how the
// three drift apart.
// ---------------------------------------------------------------------------

const n2 = (v) => +(+v).toFixed(2);
/** The circle-to-cubic constant. Four segments is exact to within a thousandth. */
const K = 0.5522847498307936;
const rad = (deg) => (deg * Math.PI) / 180;

/** An ellipse as four cubics, optionally rotated about its centre. */
function ellipseD(cx, cy, rx, ry, deg = 0) {
  const c = Math.cos(rad(deg));
  const s = Math.sin(rad(deg));
  const p = (x, y) => `${n2(cx + x * c - y * s)} ${n2(cy + x * s + y * c)}`;
  return `M ${p(rx, 0)}` +
    ` C ${p(rx, ry * K)} ${p(rx * K, ry)} ${p(0, ry)}` +
    ` C ${p(-rx * K, ry)} ${p(-rx, ry * K)} ${p(-rx, 0)}` +
    ` C ${p(-rx, -ry * K)} ${p(-rx * K, -ry)} ${p(0, -ry)}` +
    ` C ${p(rx * K, -ry)} ${p(rx, -ry * K)} ${p(rx, 0)} Z`;
}

function roundRectD(x, y, w, h, r) {
  return `M ${n2(x + r)} ${n2(y)} H ${n2(x + w - r)} A ${r} ${r} 0 0 1 ${n2(x + w)} ${n2(y + r)}` +
    ` V ${n2(y + h - r)} A ${r} ${r} 0 0 1 ${n2(x + w - r)} ${n2(y + h)}` +
    ` H ${n2(x + r)} A ${r} ${r} 0 0 1 ${n2(x)} ${n2(y + h - r)}` +
    ` V ${n2(y + r)} A ${r} ${r} 0 0 1 ${n2(x + r)} ${n2(y)} Z`;
}

/** A shape as closed path data. Every sub-path winds the same way, so a list of
 *  them in one `<path>` fills as their union under the non-zero rule. */
function closedD(s) {
  switch (s.t) {
    case 'e': return ellipseD(s.cx, s.cy, s.rx, s.ry, s.rot || 0);
    case 'c': return ellipseD(s.cx, s.cy, s.r, s.r);
    case 'r': return roundRectD(s.x, s.y, s.w, s.h, s.r);
    case 'p': return s.d;
    default: return null;
  }
}

/** The shipped fill markup for one shape — the element types the rest of the
 *  toolchain already reads. */
function fillEl(s, colour) {
  switch (s.t) {
    case 'e': return s.rot
      ? `<path d="${ellipseD(s.cx, s.cy, s.rx, s.ry, s.rot)}" fill="${colour}"/>`
      : `<ellipse cx="${s.cx}" cy="${s.cy}" rx="${s.rx}" ry="${s.ry}" fill="${colour}"/>`;
    case 'c': return `<circle cx="${s.cx}" cy="${s.cy}" r="${s.r}" fill="${colour}"/>`;
    case 'r': return `<rect x="${s.x}" y="${s.y}" width="${s.w}" height="${s.h}" rx="${s.r}" fill="${colour}"/>`;
    case 'p': return `<path d="${s.d}" fill="${colour}"/>`;
    case 'l': return `<line x1="${s.x1}" y1="${s.y1}" x2="${s.x2}" y2="${s.y2}" stroke="${colour}" stroke-width="${s.w}" stroke-linecap="round"/>`;
    case 's': return `<path d="${s.d}" fill="none" stroke="${colour}" stroke-width="${s.w}" stroke-linecap="round"/>`;
    default: throw new Error(`unknown shape ${s.t}`);
  }
}

/**
 * The same shapes grown by `d` reference units on every side.
 *
 * Closed shapes are grown by stroking them with the fill colour at `2d`, which
 * is an exact offset for any outline — unlike adding `d` to a radius, which is
 * only exact for a circle. Round-capped segments are grown by widening the
 * stroke, which is exact by construction.
 *
 * Everything is emitted as `<path>`, never `<ellipse>`: `widget-face.js` finds
 * the head by looking for the crown ellipse, and a second one would send it
 * looking at the outline instead of at Hop.
 */
function grownEls(shapes, d) {
  const out = [];
  const closed = shapes.map(closedD).filter(Boolean);
  if (closed.length) out.push(`<path d="${closed.join(' ')}" stroke-width="${n2(2 * d)}"/>`);
  for (const s of shapes) {
    if (s.t === 'l') out.push(`<path d="M ${s.x1} ${s.y1} L ${s.x2} ${s.y2}" fill="none" stroke-width="${n2(s.w + 2 * d)}"/>`);
    else if (s.t === 's') out.push(`<path d="${s.d}" fill="none" stroke-width="${n2(s.w + 2 * d)}"/>`);
  }
  return out.join('');
}

// ---------------------------------------------------------------------------
// The scene graph
//
// node = { id, transform, tone, shapes, children, extra, rim, sil }
//   rim: false  the part carries no outline of its own (an accent is not anatomy)
//   sil: false  the part is not part of Hop's outline at all, and disappears
//               from a flat silhouette (the belly is inside the torso; the
//               shadow is not Hop)
//   extra       finished markup drawn after the fill — the face. A function of
//               the context when it needs the outline width. Never inflated,
//               never in the silhouette.
// ---------------------------------------------------------------------------

/**
 * Hiding and isolating parts.
 *
 * `omit` drops a named part and everything that belongs to it — omitting
 * `left-arm` takes the hand with it, because "is the left arm distinguishable"
 * is a question about the whole forelimb. Hands are drawn later than their
 * arms (in front of the belly), so that link is `LIMB` rather than nesting.
 * `only` does the reverse: it keeps a named part's whole subtree and nothing
 * else, but still walks through its ancestors so the part arrives in the right
 * place.
 *
 * Both exist for the silhouette gate in `hop-lab.js`, which measures what each
 * limb contributes to the outline by rendering the figure with and without it.
 */
const LIMB = {
  'left-arm': ['left-hand'], 'right-arm': ['right-hand'],
  'left-leg': ['left-foot'], 'right-leg': ['right-foot'],
};

function hidden(node, ctx) {
  return !!(ctx.omit && node.id && ctx.omit.has(node.id));
}

/** Does this node, or anything under it, survive an `only` filter? */
function wanted(node, ctx, kept) {
  if (!ctx.only || kept) return true;
  if (node.id && ctx.only.has(node.id)) return true;
  return (node.children || []).some((child) => wanted(child, ctx, false));
}

function drawNode(node, ctx, kept = false) {
  if (hidden(node, ctx)) return '';
  if (ctx.flat && node.sil === false) return '';
  if (!wanted(node, ctx, kept)) return '';
  const mine = kept || !ctx.only || (node.id && ctx.only.has(node.id));
  const bits = [];
  if (mine && !ctx.flat && node.rim !== false && ctx.level.width > 0 && node.shapes && node.shapes.length) {
    bits.push(`<g fill="${T.outline}" stroke="${T.outline}" stroke-linejoin="round" stroke-linecap="round">` +
      grownEls(node.shapes, ctx.level.width) + '</g>');
  }
  if (mine && node.shapes) {
    const tone = ctx.flat ? ctx.flatColour : node.tone;
    bits.push(node.shapes.map((s) => fillEl(s, tone)).join(''));
  }
  for (const child of node.children || []) bits.push(drawNode(child, ctx, mine));
  if (mine && !ctx.flat && node.extra) {
    bits.push(typeof node.extra === 'function' ? node.extra(ctx) : node.extra);
  }
  const attrs = (node.id ? ` id="${node.id}"` : '') + (node.transform ? ` transform="${node.transform}"` : '');
  return attrs ? `<g${attrs}>${bits.join('')}</g>` : bits.join('');
}

function silhouetteNode(node, ctx, kept = false) {
  if (node.sil === false) return '';
  if (hidden(node, ctx)) return '';
  if (!wanted(node, ctx, kept)) return '';
  const mine = kept || !ctx.only || (node.id && ctx.only.has(node.id));
  const bits = [];
  if (mine && node.shapes && node.shapes.length) bits.push(grownEls(node.shapes, ctx.level.width));
  for (const child of node.children || []) bits.push(silhouetteNode(child, ctx, mine));
  const body = bits.join('');
  if (!body) return '';
  return node.transform ? `<g transform="${node.transform}">${body}</g>` : body;
}

// ---------------------------------------------------------------------------
// Parts
// ---------------------------------------------------------------------------

/** The head: crown, jaw and the two domes, one fill, no seams. The crown
 *  ellipse is first and is `widget-face.js`'s anchor — `isCrown` there
 *  restates `CROWN`; change one and change the other. */
function headNode(tilt, face) {
  return {
    id: 'head',
    transform: `rotate(${tilt} ${FACE_CENTRE[0]} ${FACE_CENTRE[1]})`,
    tone: T.fill,
    shapes: [
      { t: 'e', cx: CROWN.cx, cy: CROWN.cy, rx: CROWN.rx, ry: CROWN.ry },
      { t: 'e', cx: JAW.cx, cy: JAW.cy, rx: JAW.rx, ry: JAW.ry },
      { t: 'c', cx: EYE_L.cx, cy: EYE_L.cy, r: DOME_R },
      { t: 'c', cx: EYE_R.cx, cy: EYE_R.cy, r: DOME_R },
    ],
    extra: face,
  };
}

/** A round-capped segment from `a` toward `deg`, `len` long, `w` wide. */
function ray(a, deg, len, w) {
  return {
    t: 'l', x1: n2(a[0]), y1: n2(a[1]),
    x2: n2(a[0] + Math.cos(rad(deg)) * len),
    y2: n2(a[1] + Math.sin(rad(deg)) * len),
    w,
  };
}

/**
 * One arm: a capsule from the body's shoulder to the pose's hand point. The
 * hand is a separate node (`handNode`) because it is drawn later than the arm
 * — in front of the belly — while the arm may be behind the torso.
 */
function armNode(side, shoulder, hand) {
  return {
    id: `${side}-arm`,
    tone: T.fill,
    shapes: [{ t: 'l', x1: n2(shoulder[0]), y1: n2(shoulder[1]), x2: n2(hand[0]), y2: n2(hand[1]), w: ARM_W }],
  };
}

/**
 * One hand: three fingers radiating from the hand point about the direction
 * the arm arrived from. Each finger is its own node so the boundaries between
 * them are drawn. They start where the arm's cap is and share one base
 * circle, so the only mark they leave on the arm is a single wrist arc.
 */
function handNode(side, shoulder, hand) {
  const dir = (Math.atan2(hand[1] - shoulder[1], hand[0] - shoulder[0]) * 180) / Math.PI;
  return {
    id: `${side}-hand`,
    children: FINGER_ANGLES.map((a) => ({ tone: T.fill, shapes: [ray(hand, dir + a, FINGER_LEN, FINGER_W)] })),
  };
}

/**
 * One leg, and its three-toed foot.
 *
 * Standing, the leg is a straight column from a hip inside the torso to the
 * ankle. Crouching, the "leg" is a haunch: a fat lobe centred on `hip`, tilted
 * so its bottom swings outward, with the back foot at `ankle`. `sign` −1 is
 * Hop's right, the viewer's left; toe angles are measured from straight down,
 * outward positive, and each toe is its own node for the same reason a finger
 * is. The foot has no sole and no creases — three lobes and nothing else.
 */
function legNode(side, sign, leg, body) {
  const kind = BODIES[body];
  const { hip, ankle, spread = 1 } = leg;
  const foot = [ankle[0] + sign * FOOT_OFFSET.outward, ankle[1] + FOOT_OFFSET.down];
  const toe = (d) => {
    const deg = 90 - sign * d;
    return {
      t: 'l', x1: n2(foot[0]), y1: n2(foot[1]),
      x2: n2(foot[0] + Math.cos(rad(deg)) * TOE_LEN * spread),
      y2: n2(foot[1] + Math.sin(rad(deg)) * TOE_LEN),
      w: TOE_W,
    };
  };
  const shapes = body === 'crouch'
    ? [{ t: 'e', cx: n2(hip[0]), cy: n2(hip[1]), rx: HAUNCH.rx, ry: HAUNCH.ry, rot: -sign * HAUNCH.tilt }]
    : [{ t: 'l', x1: n2(hip[0]), y1: n2(hip[1]), x2: n2(ankle[0]), y2: n2(ankle[1]), w: LEG_W }];
  return {
    id: `${side}-leg`,
    tone: T.fill,
    shapes,
    children: [{
      id: `${side}-foot`,
      children: kind.toes.map((d) => ({ tone: T.fill, shapes: [toe(d)] })),
    }],
  };
}

/**
 * Torso: straight sides that run up under the jaw, rounded at the hips. There
 * is no neck in either reference; the body tucks straight up behind the head.
 * Crouching it is narrower than the belly's outline and all but hidden — it is
 * the green behind the belly and the thing the haunches and arms attach to.
 */
function bodyNode({ body, squash = 0, width = 57 } = {}) {
  const torso = BODIES[body].torso;
  const x0 = torso.x0 ?? 75 - width / 2;
  const x1 = torso.x1 ?? 75 + width / 2;
  const top = torso.top + squash * 4;
  const bottom = torso.bottom - squash * 4;
  const r = Math.min(torso.r, (x1 - x0) / 2);
  return {
    id: 'body',
    tone: T.fill,
    shapes: [{
      t: 'p',
      d: `M ${n2(x0)} ${n2(top)} H ${n2(x1)} V ${n2(bottom - r)} A ${r} ${r} 0 0 1 ${n2(x1 - r)} ${n2(bottom)} H ${n2(x0 + r)} A ${r} ${r} 0 0 1 ${n2(x0)} ${n2(bottom - r)} Z`,
    }],
  };
}

/** The cream belly, outlined like everything else. Inside the torso, so it is
 *  not part of the silhouette: standing it is a circle, crouching a tall oval. */
function bellyNode(scale, body) {
  const shape = body === 'crouch'
    ? { t: 'e', cx: 75, cy: 114, rx: n2(22.5 * scale), ry: n2(27.2 * scale) }
    : { t: 'c', cx: 75, cy: n2(110 + (scale - 1) * 3), r: n2(24 * scale) };
  return { id: 'belly', tone: T.belly, sil: false, shapes: [shape] };
}

/** The adventure pack, worn on the back; only its edge and strap show. */
function bagNode() {
  return {
    id: 'optional-bag', tone: T.bagBody,
    shapes: [{ t: 'r', x: 98, y: 84, w: 22, h: 30, r: 9 }],
    children: [{
      // Out of the silhouette: the strap runs up behind the torso and adds
      // nothing to Hop's outline that the pack's own body does not, and keeping
      // it out is what lets `HopFigureShape.silhouette` — which has no way to
      // grow a quadratic stroke — describe the same shape.
      id: 'bag-strap', tone: T.bagStrap, sil: false,
      shapes: [{ t: 's', d: 'M 92 78 q 12 4 16 20', w: 4 }],
    }],
  };
}

// ---------------------------------------------------------------------------
// The face
// ---------------------------------------------------------------------------

/** The three darker spots on the forehead. No outline. */
function spots() {
  return SPOTS.map(([cx, cy, r]) => `
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="${T.spot}"/>`).join('');
}

function nostrils() {
  return NOSTRILS.xs.map((cx) => `
    <circle cx="${cx}" cy="${NOSTRILS.y}" r="${NOSTRILS.r}" fill="${T.ink}"/>`).join('');
}

/** Low and wide on the jaw. No outline. */
function cheeks() {
  return `<g id="cheeks">${CHEEKS.xs.map((cx) =>
    `<circle cx="${cx}" cy="${CHEEKS.y}" r="${CHEEKS.r}" fill="${T.cheek}"/>`).join('')}</g>`;
}

/**
 * Eyes. `blink` 0…1 closes the lid; `mood` picks the closed-eye line — a happy
 * upward arc for celebrating, a soft downward arc for resting.
 *
 * Each white is outlined: a ring grown by the outline width, drawn under the
 * white by the same construction every rim uses. The pupil is very large —
 * 83% of the white — and sits slightly low and inward, with one catchlight at
 * its top-left.
 *
 * The shape of this markup is a contract with `Scripts/web/motion.js`. Its
 * blink rule matches a bare `<g>` followed by the eye's `<clipPath>` and stops
 * at the first `</g></g>`, so `left-eye`/`right-eye` wrap that group from
 * outside and are still standing after the substitution — which is what lets a
 * derived blink stay byte-identical to `hop-blink.svg`. The pupil carries its id
 * on the circle for the same reason: a `<g id="left-pupil">` inside the clip
 * would end the gaze rule's lazy match early and freeze the catchlight.
 */
function eyes({ gaze = [0, 0], blink = 0, mood = 'happy', lidDrop = 0 } = {}, width = 0) {
  const [gx, gy] = gaze;
  const one = ({ cx, cy }, side, inward) => {
    if (blink >= 1) {
      const dir = mood === 'rest' ? 1 : -1;
      return `<path d="M ${cx - 10} ${cy + 3} Q ${cx} ${cy + 3 + dir * 9} ${cx + 10} ${cy + 3}"
        fill="none" stroke="${T.ink}" stroke-width="3.2" stroke-linecap="round"/>`;
    }
    const px = n2(cx + gx + inward * PUPIL_OFFSET.inward);
    const py = n2(cy + PUPIL_OFFSET.down + gy);
    const ring = width > 0
      ? `<circle cx="${cx}" cy="${cy}" r="${WHITE_R}" fill="${T.outline}" stroke="${T.outline}" stroke-width="${n2(2 * width)}"/>`
      : '';
    const lid = lidDrop > 0
      ? `<circle cx="${cx}" cy="${(cy - (2 * WHITE_R + 1 - 2 * WHITE_R * lidDrop)).toFixed(1)}" r="${WHITE_R + 1}" fill="${T.fill}"/>`
      : '';
    // The lid is clipped to the white so a lowered lid never shows outside the
    // eye — unclipped it read as a pair of ears above the head.
    const clipId = `eyeClip${Math.round(cx)}`;
    return `<g>
      <clipPath id="${clipId}"><circle cx="${cx}" cy="${cy}" r="${WHITE_R}"/></clipPath>
      ${ring}
      <circle cx="${cx}" cy="${cy}" r="${WHITE_R}" fill="${T.eyeWhite}"/>
      <g clip-path="url(#${clipId})">
        <circle id="${side}-pupil" cx="${px}" cy="${py}" r="${PUPIL_R}" fill="${T.pupil}"/>
        <circle cx="${n2(px + HIGHLIGHT.dx)}" cy="${n2(py + HIGHLIGHT.dy)}" r="${HIGHLIGHT.r}" fill="${T.highlight}"/>
        ${lid}
      </g>
    </g>`;
  };
  return `<g id="eyes-group"><g id="left-eye">${one(EYE_L, 'left', 1)}</g><g id="right-eye">${one(EYE_R, 'right', -1)}</g></g>`;
}

/**
 * Mouth. `open`: the reference's wide open smile — corners high, a deep U, a
 * dark red interior with a pink tongue at the bottom, and the outline around
 * it. `talk`: the same at 72%, for speech. `closed`: a calm smile line.
 * `small`: a resting smile line.
 *
 * The inner scaled group is what `motion.js` rewrites to derive `smile` and
 * `talkShut`; `<g id="mouth">` wraps it from outside for the same reason the
 * eyes do, and it scales about `FACE_CENTRE` because that rule says so.
 */
function mouth(kind = 'open', width = 0) {
  if (kind === 'closed' || kind === 'small') {
    const d = kind === 'closed' ? 12 : 8;
    return `<g id="mouth"><path d="M 56 52 Q 75 ${52 + d} 94 52" fill="none" stroke="${T.ink}" stroke-width="3.4" stroke-linecap="round"/></g>`;
  }
  const s = kind === 'talk' ? 0.72 : 1;
  const uid = 'mouthClip' + kind;
  const ring = width > 0
    ? `<path d="${MOUTH_D}" fill="${T.outline}" stroke="${T.outline}" stroke-width="${n2(2 * width)}" stroke-linejoin="round"/>`
    : '';
  return `<g id="mouth"><g transform="translate(${FACE_CENTRE[0]} ${FACE_CENTRE[1]}) scale(${s}) translate(${-FACE_CENTRE[0]} ${-FACE_CENTRE[1]})">
    <clipPath id="${uid}">
      <path d="${MOUTH_D}"/>
    </clipPath>
    ${ring}
    <path d="${MOUTH_D}" fill="${T.mouthInterior}"/>
    <ellipse cx="${TONGUE_IN.cx}" cy="${TONGUE_IN.cy}" rx="${TONGUE_IN.rx}" ry="${TONGUE_IN.ry}" fill="${T.tongue}" clip-path="url(#${uid})"/>
  </g></g>`;
}

/**
 * A frog's tongue, out and reaching for something. A thick capsule from the
 * mouth to `to`, with a rounder tip so it reads as a tongue and not a rope.
 * Drawn after the face so it leaves the open mouth rather than sitting under it.
 */
function tongue(to = [128, 20]) {
  const [tx, ty] = to;
  return `<g id="tongue">
    <line x1="75" y1="60" x2="${tx}" y2="${ty}" stroke="${T.tongue}" stroke-width="7" stroke-linecap="round"/>
    <circle cx="${tx}" cy="${ty}" r="5.5" fill="${T.tongue}"/>
  </g>`;
}

/** Soft motion marks either side of the body, for the "I need to go" wiggle. */
function wiggle() {
  return `<g id="wiggle" fill="none" stroke="${T.spot}" stroke-width="2.4" stroke-linecap="round" opacity="0.6">
    <path d="M 36 96 q -5 6 0 12"/><path d="M 30 92 q -7 9 0 18"/>
    <path d="M 114 96 q 5 6 0 12"/><path d="M 120 92 q 7 9 0 18"/>
  </g>`;
}

function zzz() {
  return `<g id="sleep-marks" fill="${T.ink}" font-family="system-ui, sans-serif" font-weight="800" opacity="0.7">
    <text x="122" y="14" font-size="9">z</text>
    <text x="131" y="6" font-size="12">z</text>
  </g>`;
}

/**
 * The ground shadow, resting on `GROUND` so its lower edge is the lowest ink in
 * the drawing and the toes touch it rather than pierce it. It shrinks and fades
 * with `lift`, which is what makes an airborne pose read as airborne. It is not
 * anatomy: no outline, and it leaves a flat silhouette.
 */
function shadowNode(lift) {
  const ry = 3.6;
  return {
    id: 'shadow', rim: false, sil: false, tone: T.shadow,
    shapes: [],
    extra: `<ellipse cx="75" cy="${(GROUND - ry - lift * 0.1).toFixed(2)}" rx="${40 - lift * 0.4}" ry="${ry}" fill="${T.shadow}" opacity="${(0.12 - lift * 0.002).toFixed(3)}"/>`,
  };
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------

/**
 * One pose = one parameter set.
 *
 * Depth order is the outline system, because each part's rim lands on whatever
 * is already under it. Standing: bag, legs, arms, torso, belly, hands, head —
 * the arms attach behind the torso's sides so the torso's edge is their
 * boundary and no shoulder seam is drawn on the chest, and the hands come
 * forward again so they can rest on the belly. Crouching: bag, haunches,
 * torso, belly, arms, hands, head — the front legs are in front of the belly.
 * The head is always last, both because a frog whose eyes are at the corners
 * of his own silhouette has nowhere to put a forearm that is not across an
 * eye, and because `widget-face.js` reads everything after the crown as face.
 */
function figure(p = {}) {
  const {
    body = 'standing',
    lift = 0, squash = 0, tilt = 0, lean = 0,
    // Reference 2's ta-da arms: out to the sides at roughly shoulder height,
    // hands open — up, out, down.
    armL = [9, 98], armR = [141, 98],
    legL = { hip: [54, 128], ankle: [54, ANKLE], spread: 1 },
    legR = { hip: [96, 128], ankle: [96, ANKLE], spread: 1 },
    eyes: eyeOpts = {}, mouth: mouthKind = 'open',
    withPack = false, sleeping = false, showShadow = true,
    bellyScale = 1, tongueTo = null, wiggling = false,
    torsoWidth = 57,
  } = p;
  const kind = BODIES[body];
  if (!kind) throw new Error(`no such body: ${body}`);

  const face = (ctx) => [
    `<g id="accent-details">${spots()}</g>`,
    eyes(eyeOpts, ctx.level.width),
    cheeks(),
    nostrils(),
    mouth(mouthKind, ctx.level.width),
    tongueTo ? tongue(tongueTo) : '',
  ].join('');

  const arms = [armNode('left', kind.shoulderL, armL), armNode('right', kind.shoulderR, armR)];
  const trunk = [bodyNode({ body, squash, width: torsoWidth }), bellyNode(bellyScale, body)];
  const parts = [
    withPack ? bagNode() : null,
    legNode('left', -1, legL, body),
    legNode('right', 1, legR, body),
    ...(kind.armsInFront ? [...trunk, ...arms] : [...arms, ...trunk]),
    handNode('left', kind.shoulderL, armL),
    handNode('right', kind.shoulderR, armR),
    headNode(tilt, face),
  ].filter(Boolean);

  return {
    shadow: showShadow ? shadowNode(lift) : null,
    body: parts,
    transform: `translate(0 ${-lift}) translate(75 100) rotate(${lean}) translate(-75 -100)`,
    after: (wiggling ? wiggle() : '') + (sleeping ? zzz() : ''),
  };
}

/** A figure, rendered at one outline level. */
function render(fig, ctx) {
  const silhouette = ctx.flat || ctx.level.width <= 0
    ? ''
    : `<g id="hop-silhouette" fill="${T.outline}" stroke="${T.outline}" stroke-linejoin="round" stroke-linecap="round">` +
      fig.body.map((n) => silhouetteNode(n, ctx)).join('') + '</g>';
  const parts = fig.body.map((n) => drawNode(n, ctx)).join('');
  const shadow = fig.shadow && !ctx.flat ? drawNode(fig.shadow, ctx) : '';
  return `<g id="hop-root">${shadow}<g id="hop-figure" transform="${fig.transform}">` +
    silhouette + parts + (ctx.flat ? '' : fig.after) + '</g></g>';
}

/** A set of part ids, with each limb's dependants folded in. */
function limbSet(ids) {
  if (!ids || !ids.length) return null;
  const out = new Set(ids);
  for (const id of ids) for (const dep of LIMB[id] || []) out.add(dep);
  return out;
}

function context(opts = {}) {
  return {
    level: OUTLINE[opts.level || 'default'] || OUTLINE.default,
    flat: !!opts.flat,
    flatColour: opts.flatColour || T.outline,
    omit: limbSet(opts.omit),
    only: limbSet(opts.only),
  };
}

function wrap(inner) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CANVAS} ${CANVAS}" width="${CANVAS}" height="${CANVAS}">
<g transform="translate(${OX} ${OY}) scale(${SCALE})">
${inner}
</g>
</svg>`;
}

// ---------------------------------------------------------------------------
// The pose set
// ---------------------------------------------------------------------------

/**
 * The crouch body's limbs, shared by every pose that sits: haunch centres for
 * hips, back feet at the outer corners, hands on the ground between them. The
 * crouch is six units shorter than the standing body, so every crouch pose
 * carries `lift: -6` to put those four contact points on `GROUND`.
 */
const CROUCH = {
  body: 'crouch', lift: -6,
  armL: [49, 142], armR: [101, 142],
  legL: { hip: [26, 117.5], ankle: [28.5, 143.5], spread: 1 },
  legR: { hip: [124, 117.5], ankle: [121.5, 143.5], spread: 1 },
};

/**
 * Fifteen poses. Every one of them was checked as a flat silhouette — see
 * `node Scripts/hop-lab.js --silhouette` — and where a limb vanished the *pose*
 * was moved before anything was done to the stroke.
 *
 * Gaze offsets are small on purpose: the pupil is 83% of the white, so 1.9
 * units is all the travel there is before it is cut off by the eye's edge.
 */
const POSE_PARAMS = {
  /** The reference pose: ta-da arms, open smile. App icon and dashboard chip. */
  idle: {},

  /** Eyes closed mid-blink; cross-faded with `idle` for the ambient loop. */
  blink: { eyes: { blink: 1, mood: 'rest' } },

  /** Speaking a line, one hand raised toward the child. Also Hop pointing at a
   *  button, which is the same gesture with the gaze moved. */
  talk: { mouth: 'talk', armR: [141, 82], eyes: { gaze: [0, 0.5] } },

  /** Waving hello. Onboarding and the shield greeting. The waving hand sits
   *  clear of the dome and the jaw; the forearm passes behind the jaw. */
  wave: { armR: [144, 38], armL: [12, 118], tilt: -3, eyes: { gaze: [0.6, 0] } },

  /** Walking to the bathroom with the pack — Hop holding something, and
   *  leaning. The trailing arm swings back, the front leg lifts. The trailing
   *  leg's ankle is two below the ground so the 4° lean lands its toes on it. */
  walk: {
    lean: 4, withPack: true,
    armL: [14, 120], armR: [138, 82],
    legL: { hip: [54, 128], ankle: [40, ANKLE + 2], spread: 1.1 },
    legR: { hip: [96, 128], ankle: [112, ANKLE - 10], spread: 1.1 },
    eyes: { gaze: [1, 0] }, mouth: 'talk',
  },

  /** Waiting patiently on the potty — sat down, hands resting, calm. Also the
   *  quiz-thinking pose: still, hands down, eyes lowered. */
  wait: { ...CROUCH, eyes: { gaze: [0, 1.2], lidDrop: 0.35 }, mouth: 'small' },

  /**
   * Mid-hop, airborne. The celebration.
   *
   * `lift` is the one parameter that costs the whole set size: every pose is
   * scaled to fit the tallest thing any pose draws, and the domes of a lifted
   * Hop are it. 7.5 leaves the high-contrast outline 8 units of air.
   *
   * The arms sweep out and down from the shoulders — what a jumping frog does,
   * and what keeps both hands outside every other shape — and the legs kick
   * asymmetrically, because two identical tucked legs are one leg.
   */
  jump: {
    lift: 7.5, squash: -0.15,
    armL: [9, 118], armR: [141, 118],
    legL: { hip: [54, 128], ankle: [38, 140], spread: 1.15 },
    legR: { hip: [96, 128], ankle: [106, 147], spread: 1.15 },
    eyes: { blink: 1, mood: 'happy' }, mouth: 'open',
  },

  /**
   * Both arms up. The star-earned moment.
   *
   * Out as well as up: the domes are the widest part of Hop at that height, so
   * hands raised straight overhead vanish behind his own head. The hands sit
   * just outside the domes' upper corners.
   */
  cheer: {
    lift: 2,
    armL: [8, 34], armR: [142, 34],
    eyes: { gaze: [0, -1] }, mouth: 'open',
  },

  /** Resting during quiet hours and "paused until tomorrow". */
  sleep: {
    ...CROUCH, tilt: 4, sleeping: true,
    eyes: { blink: 1, mood: 'rest' }, mouth: 'small',
  },

  /** Landing frame after a jump — the squash before the settle. Hands wider
   *  than a sit, mouth open, eyes down at the ground. */
  land: {
    ...CROUCH, squash: 0.5,
    armL: [44, 142], armR: [106, 142],
    eyes: { gaze: [0, 1] }, mouth: 'open',
  },

  // ---- Mini-game states ----

  /** Frog squat on a lily pad, watching the sky. Fly Snack's resting state. */
  sit: { ...CROUCH, eyes: { gaze: [0, -1.2] }, mouth: 'small' },

  /** Tongue out for a fly. Same squat; the tongue reaches toward `tongueTo` —
   *  out sideways at mouth height, because aimed up at the fly it crossed his
   *  own eye. */
  catch: {
    ...CROUCH,
    eyes: { gaze: [1.2, -1.2] }, mouth: 'open', tongueTo: [142, 56],
  },

  /**
   * Tummy full, and the body saying so. Bigger belly, hands on it, knees
   * together, a small bashful smile — kind, never distressed. This is the
   * moment the child learns to notice.
   *
   * The two hands are held at different heights: level with each other they
   * fused into one green mitten across the belly.
   */
  full: {
    squash: 0.1, bellyScale: 1.22, torsoWidth: 64, wiggling: true,
    armL: [40, 120], armR: [110, 126],
    legL: { hip: [54, 128], ankle: [58, ANKLE], spread: 1 },
    legR: { hip: [96, 128], ankle: [92, ANKLE], spread: 1 },
    eyes: { gaze: [0, 1.2], lidDrop: 0.15 }, mouth: 'small',
  },

  /**
   * Hands held out front, palms up, for washing and wiping games — and the
   * "hands together" pose the routine ends on. Offset rather than symmetrical
   * for the same reason `full`'s are.
   */
  scrub: {
    armL: [36, 122], armR: [114, 114],
    eyes: { gaze: [0, 1.4] }, mouth: 'talk',
  },
};

/** Each entry, built. The parameters are kept apart from the building so the
 *  table can be compared with `HopPoseGeometry.parameters(for:)` in Swift — see
 *  `hop-lab.js --contracts`, which exists because the two diverged once before
 *  and nothing noticed until the app drew a clipped frog while the renders
 *  showed a fixed one. */
const poses = Object.fromEntries(
  Object.entries(POSE_PARAMS).map(([name, params]) => [name, () => figure(params)]));

/**
 * Head only, for avatars and the app icon.
 *
 * A crop, not a pose — and the only drawing here with its own transform. Its
 * box is tight on the head, and it is used at chip sizes where a head that
 * suddenly shrank by a tenth would show. `HopPoseGeometry.faceCrop` is the
 * head's rectangle on the full canvas, computed from the same anatomy.
 */
const FACE_BOX = { w: 512, h: 296, tx: 16, ty: 4, scale: 3.2 };

function faceSVG(ctx) {
  const face = (c) => [
    `<g id="accent-details">${spots()}</g>`,
    eyes({}, c.level.width), cheeks(), nostrils(), mouth('open', c.level.width),
  ].join('');
  const head = headNode(0, face);
  const silhouette = ctx.flat || ctx.level.width <= 0
    ? ''
    : `<g id="hop-silhouette" fill="${T.outline}" stroke="${T.outline}" stroke-linejoin="round" stroke-linecap="round">` +
      silhouetteNode(head, ctx) + '</g>';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${FACE_BOX.w} ${FACE_BOX.h}" width="${FACE_BOX.w}" height="${FACE_BOX.h}">
<g transform="translate(${FACE_BOX.tx} ${FACE_BOX.ty}) scale(${FACE_BOX.scale})">
<g id="hop-root">${silhouette}${drawNode(head, ctx)}</g>
</g>
</svg>`;
}

/** One named pose as a finished SVG document. */
function poseSVG(name, opts = {}) {
  const ctx = context(opts);
  if (name === 'face') return faceSVG(ctx);
  const build = poses[name];
  if (!build) throw new Error(`no such pose: ${name}`);
  return wrap(render(build(), ctx));
}

const POSE_NAMES = [...Object.keys(poses), 'face'];

module.exports = {
  T, OUTLINE, CANVAS, STAGE, GROUND, ANKLE, SCALE, OX, OY, FEET_FRACTION,
  BODIES, CROWN, poses, POSE_PARAMS, POSE_NAMES, poseSVG,
};

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

if (require.main === module) {
  const argv = process.argv.slice(2);
  let level = 'default';
  let outDir = path.resolve(__dirname, '..', 'Art', 'character');
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--level') level = argv[++i];
    else if (argv[i] === '--out') outDir = path.resolve(argv[++i]);
  }
  if (!OUTLINE[level]) {
    console.error(`unknown outline level "${level}" — one of ${Object.keys(OUTLINE).join(', ')}`);
    process.exit(2);
  }
  fs.mkdirSync(outDir, { recursive: true });
  for (const name of POSE_NAMES) {
    const file = path.join(outDir, `hop-${name}.svg`);
    fs.writeFileSync(file, poseSVG(name, { level }).trim() + '\n');
    console.log('wrote', path.relative(path.resolve(__dirname, '..'), file));
  }
  // Printed rather than buried, because two constants outside this file — `FEET`
  // in `Scripts/screens/child.js` and `SIT_FEET` in `Scripts/screens/parent.js`,
  // and `referenceScale`/`referenceOrigin` in `HopCharacterShapes.swift` — are
  // this transform restated, and drift the moment the stage moves.
  console.log('----');
  console.log(`transform  translate(${OX} ${OY}) scale(${SCALE})   stage ${JSON.stringify(STAGE)}`);
  console.log(`feet       ground y=${GROUND} -> canvas ${(OY + SCALE * GROUND).toFixed(1)}` +
    `  = ${FEET_FRACTION.toFixed(4)} of the box  (FEET and SIT_FEET)`);
  console.log(`outline    ${level}: ${OUTLINE[level].width} units on every boundary`);
}
