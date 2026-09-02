#!/usr/bin/env node
/**
 * Hop's rig, and the fifteen drawings it emits.
 *
 * Hop is drawn in the 150×160 space of the approved reference
 * (`hop_mascot.svg`) so every number here can be checked against it directly,
 * then scaled onto the 512×512 canvas the app and the SwiftUI port use.
 *
 * ## What changed, and why it is a rig now
 *
 * This file used to build each pose as a flat pile of shapes with the pose
 * baked into absolute coordinates: an arm was a line from one point to another,
 * so "raise the arm" was a different drawing rather than a different transform.
 * Nothing in the emitted SVG said which shapes were an arm. The files had no
 * anatomical ids at all — only clip paths — so no consumer could address a limb,
 * and the three failures a caregiver can name were structural:
 *
 *   * arms disappeared into the head (`cheer`, `jump`),
 *   * hands disappeared into the torso (`scrub`, `full`, `sit`),
 *   * legs merged with each other and with the body mid-jump.
 *
 * All three are the same failure: **one flat green, no boundaries.**
 *
 * So the drawing is now a small scene graph — ``NODES`` below — of named parts
 * with stable ids (`hop-root`, `shadow`, `body`, `belly`, `head`, `eyes-group`,
 * `left-eye`, `right-eye`, `left-pupil`, `right-pupil`, `mouth`, `cheeks`,
 * `left-arm`, `right-arm`, `left-hand`, `right-hand`, `left-leg`, `right-leg`,
 * `left-foot`, `right-foot`, `optional-bag`, `accent-details`). Each limb is
 * authored **once**, in its own local space, and posed by a group transform:
 * an arm is a capsule along +x from the shoulder with the hand at its far end,
 * placed by `translate(shoulder) rotate(θ)`. A pose is therefore a set of
 * angles and lengths, not a redraw, and every major limb is independently
 * poseable by editing one transform.
 *
 * The same fifteen files still ship, because the screens, the widget generator
 * and the web prototype all consume them by name.
 *
 * ## The separation system (three levels, and all three do work)
 *
 * 1. **Exterior silhouette** — `#hop-silhouette`, one opaque `hop-outline`
 *    underlay of the whole body drawn beneath everything, each part inflated by
 *    `exterior` reference units. Because it is a single layer of one colour, it
 *    has no interior seams: only the outer edge of the union survives, which is
 *    what makes Hop read on cream, pond blue, vegetation green, white and dark.
 * 2. **Internal overlap separation** — each part carries its own *lighter and
 *    thinner* rim (`inner` units, `hop-outline` at `innerOpacity`) drawn
 *    directly beneath its own fill. Parts are drawn in depth order, so a part's
 *    rim lands only where it overlaps something already drawn: arm against head,
 *    hand against belly, leg against body, foot against leg, hand against hand.
 *    Where it coincides with the exterior edge it disappears into the darker
 *    silhouette, so it costs nothing on the outside.
 * 3. **Tonal separation** — four steps of green, assigned by depth rather than
 *    by part: head and torso are the primary front surfaces, arms sit a step
 *    back, legs a step further, feet come forward again, and an arm crossing in
 *    front of the body steps *up* to the highlight. Hop still reads with the
 *    outline turned off — `node Scripts/hop-lab.js` proves it.
 *
 * The outline is deliberately **anatomical**: HEAD, BODY, LEFT/RIGHT ARM,
 * LEFT/RIGHT HAND, LEFT/RIGHT LEG, LEFT/RIGHT FOOT. Never a cheek, an eye, a
 * highlight or an individual sub-path — outlining those fragments him into a
 * sticker sheet.
 *
 * ### `vector-effect="non-scaling-stroke"` — evaluated and rejected
 *
 * It pins a stroke to device pixels. Every line in this drawing is authored in
 * reference units and scales with Hop on purpose: that is what lets one file
 * serve a 28pt chip and a 320pt hero. Under `non-scaling-stroke` the internal
 * separation lines would be the same pixel weight at 64px as at 512px — eight
 * times heavier relative to the body — which is exactly the "magnified sticker"
 * §17 warns about, inverted. Responsiveness is handled instead by *choosing an
 * outline level* for the size: see ``OUTLINE`` and `HopOutlineStyle` in Swift.
 *
 * ## Two contracts this file must not break
 *
 * **`Scripts/web/motion.js`** derives blink/gaze/smile/talk frames by rewriting
 * the eye and mouth markup with regular expressions, and
 * `Scripts/web/build-prototype.js` asserts that deriving a blink from
 * `hop-idle.svg` reproduces `hop-blink.svg` byte for byte. Its blink rule keys
 * on a bare `<g>` immediately followed by the eye's `<clipPath>`, and ends at
 * the first `</g>` pair — so `left-eye`/`right-eye` wrap that group from the
 * *outside* and survive the substitution, and `left-pupil`/`right-pupil` are ids
 * on the pupil circles rather than groups, because a nested group inside the
 * clip would stop the gaze rule at the wrong `</g>`. `node Scripts/hop-lab.js
 * --contracts` checks both.
 *
 * **`Scripts/widget-face.js`** lifts the widget's head out of this art by
 * taking every drawable **from the crown ellipse onward**, and throws on any
 * paint it does not know and on any element other than `<circle>`, `<ellipse>`
 * and `<path>`. So everything that is new — the silhouette layer, the head's own
 * rim — is emitted as `<path>` (never `<ellipse>`, which would be mistaken for
 * the crown) and placed *before* the crown, and nothing after the crown gained a
 * colour or an element type. The head's own fill markup is byte-for-byte what it
 * always was.
 *
 * ## The rest
 *
 * A pose is not confined to the 150×160 box — `jump` lifts above y=0 and every
 * standing pose's toes reach past y=160 — so the canvas placement is derived
 * from the drawing (see `STAGE`). `Scripts/check-hop-fit.js` measures the
 * rendered result and fails if any pose reaches the canvas edge; the outline
 * counts as ink, which is why `exterior` is budgeted against the tightest pose.
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
 * Hop's colour tokens. These are the single source of truth for the character;
 * `HopPalette.swift` carries the same values under the same names so the app and
 * the art cannot drift, and `Scripts/hop-lab.js` reads them from here.
 *
 * The four greens are a *depth ramp*, not decoration. They were tuned by
 * rendering the set and looking at it: `#8FDCAC` — the old "limb in front"
 * light green — read as a ghost rather than as an arm, and one flat `#63C88A`
 * for everything is what made the character a blob in the first place.
 */
const T = {
  /** Front surfaces: head and torso. `HopPalette.hopGreen`. */
  fill: '#63C88A',
  /** A limb crossing in front of the body. Reads as nearer, not as translucent. */
  fillHighlight: '#71D397',
  /** Arms and hands at rest, and the top of a foot. A step back from the head. */
  fillShadow: '#52B77A',
  /** Legs, and the spots and toe creases. The deepest body value. */
  fillDeep: '#45A971',

  /** The structural outline. Dark green, never black: black is a sticker. */
  outline: '#356B50',
  /** Internal overlaps, at `OUTLINE[level].innerOpacity`. */
  outlineSoftOpacity: 0.62,
  /** Reserved for the faintest separations; the lab exposes it. */
  outlineSubtleOpacity: 0.38,

  ink: '#1B5E39',           // nostrils, closed-eye lines, closed mouths
  belly: '#FFF3D4',         // HopPalette.sunshineSoft
  cheek: '#FF9F8F',         // HopPalette.peachPop
  eyeWhite: '#FFFFFF',
  pupil: '#243047',         // HopPalette.midnight
  highlight: '#FFFFFF',
  mouthInterior: '#8A3F30', // HopPalette.peachInk
  tongue: '#FF6F7D',        // character-only
  bagBody: '#C98A5B',
  bagStrap: '#A76F46',
  shadow: '#243047',
};

/**
 * The semantic outline states, in reference units.
 *
 * `exterior` is how far the silhouette underlay is inflated past the fill —
 * the visible weight of the outside edge. `inner` is the same for a part's own
 * rim, drawn at `innerOpacity`, and is always roughly half of `exterior`
 * because an internal boundary that matches the outside one reads as a cut-out.
 *
 * These are *states*, not per-screen overrides. A caller picks one by what the
 * drawing has to survive, never by which screen it is on:
 *
 *   default       the shipped files: cream, cards, white, most of the app
 *   scene         over illustration — pond water, vegetation green, dark sky
 *   small         28–64pt: chips, list rows, the tab bar
 *   hero          200pt and up: softer edge, the tonal ramp carries more
 *   highContrast  Increase Contrast, and any accessibility appearance
 *
 * `exterior` is capped by the canvas, not by taste: `check-hop-fit.js` fails
 * below 6 units of clear air, and `jump`'s eye sockets are the closest ink to
 * an edge in the whole set. 2.8 is the measured ceiling — at 3.1 that pose's
 * top margin falls to 5.5 and the check goes red. Every level here has been run
 * through `check-hop-fit.js --dir`; see `hop-lab.js --levels`.
 */
const OUTLINE = {
  off: { exterior: 0, inner: 0, innerOpacity: 0 },
  hero: { exterior: 1.55, inner: 0.9, innerOpacity: 0.5 },
  default: { exterior: 2.0, inner: 1.15, innerOpacity: 0.62 },
  scene: { exterior: 2.35, inner: 1.25, innerOpacity: 0.72 },
  small: { exterior: 2.6, inner: 1.35, innerOpacity: 0.78 },
  highContrast: { exterior: 2.8, inner: 1.75, innerOpacity: 0.95 },
};

// ---------------------------------------------------------------------------
// The stage: where the reference space lands on the canvas
// ---------------------------------------------------------------------------

/**
 * How the reference space is placed on the canvas.
 *
 * The first transform — `translate(16 0) scale(3.2)` — mapped the reference's
 * own 150×160 bounds edge to edge, which left zero headroom: `jump` lost the
 * top of its crown, and every pose lost its toes and its ground shadow. So the
 * transform is solved from the drawing instead. `STAGE` is the reference-space
 * rectangle the whole pose set is built to fit; it is scaled to the canvas with
 * `MARGIN` of clear air on the binding axis and centred on both.
 *
 * The canvas stays square and 512 wide: screens size Hop by width and assume a
 * square box, so changing the aspect would move him on every screen.
 */
const CANVAS = 512;
/** Minimum clear air on every side, in canvas pixels. */
const MARGIN = 12;
/** The reference-space rectangle every pose is drawn to fit. */
const STAGE = { x0: 5, y0: -3, x1: 145, y1: 164 };
/** Reference y a standing pose's toes touch down on. Poses are built to it. */
const GROUND = 163.6;
/** Reference y of the ankle of a foot standing on `GROUND`. */
const ANKLE = 146;

/** Rounded to a tenth so the SwiftUI port carries a number, not a fraction. */
const SCALE = Math.floor((CANVAS - 2 * MARGIN) /
  Math.max(STAGE.x1 - STAGE.x0, STAGE.y1 - STAGE.y0) * 10) / 10;
const OX = +(CANVAS / 2 - SCALE * (STAGE.x0 + STAGE.x1) / 2).toFixed(3);
const OY = +(CANVAS / 2 - SCALE * (STAGE.y0 + STAGE.y1) / 2).toFixed(3);
/** Where the feet land in the box. Screens position Hop by this fraction. */
const FEET_FRACTION = (OY + SCALE * GROUND) / CANVAS;

// ---------------------------------------------------------------------------
// Anatomy, in reference coordinates
// ---------------------------------------------------------------------------

const EYE_L = { cx: 42.4, cy: 25.7 };
const EYE_R = { cx: 108.4, cy: 25.7 };
const SOCKET_R = 20.5;
const WHITE_R = 16.5;
const PUPIL_R = 12.3;

const SHOULDER_L = [48, 86];
const SHOULDER_R = [102, 86];
const ARM_W = 15;
const PALM_R = 9.5;
const FINGER_LEN = 12;
const FINGER_W = 10.5;
const FINGER_ANGLES = [-50, 0, 50];

const LEG_W = 26;
const SOLE = { rx: 14, ry: 8.5 };
const TOES = [[-4, 6], [-34, 6], [-64, 5.6]];
const CREASES = [-20, -50];

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

function ellipseD(cx, cy, rx, ry) {
  return `M ${n2(cx + rx)} ${n2(cy)}` +
    ` C ${n2(cx + rx)} ${n2(cy + ry * K)} ${n2(cx + rx * K)} ${n2(cy + ry)} ${n2(cx)} ${n2(cy + ry)}` +
    ` C ${n2(cx - rx * K)} ${n2(cy + ry)} ${n2(cx - rx)} ${n2(cy + ry * K)} ${n2(cx - rx)} ${n2(cy)}` +
    ` C ${n2(cx - rx)} ${n2(cy - ry * K)} ${n2(cx - rx * K)} ${n2(cy - ry)} ${n2(cx)} ${n2(cy - ry)}` +
    ` C ${n2(cx + rx * K)} ${n2(cy - ry)} ${n2(cx + rx)} ${n2(cy - ry * K)} ${n2(cx + rx)} ${n2(cy)} Z`;
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
    case 'e': return ellipseD(s.cx, s.cy, s.rx, s.ry);
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
    case 'e': return `<ellipse cx="${s.cx}" cy="${s.cy}" rx="${s.rx}" ry="${s.ry}" fill="${colour}"/>`;
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
//   rim: false  the part carries no internal separation (the belly is inside
//               the torso; an accent is not anatomy)
//   sil: false  the part is not part of Hop's outline at all, and disappears
//               from a flat silhouette
//   extra       finished markup drawn after the fill: the face, the toe
//               creases. Never inflated, never in the silhouette.
// ---------------------------------------------------------------------------

/**
 * Hiding and isolating parts.
 *
 * `omit` drops a named part and everything hanging off it — omitting `left-arm`
 * takes the hand with it, because "is the left arm distinguishable" is a
 * question about the whole forelimb. `only` does the reverse: it keeps a named
 * part's whole subtree and nothing else, but still walks through its ancestors
 * so the part arrives in the right place.
 *
 * Both exist for the silhouette gate in `hop-lab.js`, which measures what each
 * limb contributes to the outline by rendering the figure with and without it.
 */
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
  if (mine && !ctx.flat && node.rim !== false && ctx.level.inner > 0 && node.shapes && node.shapes.length) {
    bits.push(`<g fill="${T.outline}" stroke="${T.outline}" stroke-linejoin="round" stroke-linecap="round" opacity="${ctx.level.innerOpacity}">` +
      grownEls(node.shapes, ctx.level.inner) + '</g>');
  }
  if (mine && node.shapes) {
    const tone = ctx.flat ? ctx.flatColour : node.tone;
    bits.push(node.shapes.map((s) => fillEl(s, tone)).join(''));
  }
  for (const child of node.children || []) bits.push(drawNode(child, ctx, mine));
  if (mine && !ctx.flat && node.extra) bits.push(node.extra);
  const attrs = (node.id ? ` id="${node.id}"` : '') + (node.transform ? ` transform="${node.transform}"` : '');
  return attrs ? `<g${attrs}>${bits.join('')}</g>` : bits.join('');
}

function silhouetteNode(node, ctx, kept = false) {
  if (node.sil === false) return '';
  if (hidden(node, ctx)) return '';
  if (!wanted(node, ctx, kept)) return '';
  const mine = kept || !ctx.only || (node.id && ctx.only.has(node.id));
  const bits = [];
  if (mine && node.shapes && node.shapes.length) bits.push(grownEls(node.shapes, ctx.level.exterior));
  for (const child of node.children || []) bits.push(silhouetteNode(child, ctx, mine));
  const body = bits.join('');
  if (!body) return '';
  return node.transform ? `<g transform="${node.transform}">${body}</g>` : body;
}

// ---------------------------------------------------------------------------
// Parts
// ---------------------------------------------------------------------------

/** The head silhouette: crown, jaw and the two eye sockets, one fill, no seams.
 *  The crown ellipse is first and is `widget-face.js`'s anchor — do not move it,
 *  do not reshape it, and do not put another ellipse of the same size above it. */
function headNode(tilt, face) {
  return {
    id: 'head',
    transform: `rotate(${tilt} 75 50)`,
    tone: T.fill,
    shapes: [
      { t: 'e', cx: 75, cy: 40, rx: 44, ry: 33 },
      { t: 'e', cx: 75, cy: 56, rx: 61, ry: 27 },
      { t: 'c', cx: EYE_L.cx, cy: EYE_L.cy, r: SOCKET_R },
      { t: 'c', cx: EYE_R.cx, cy: EYE_R.cy, r: SOCKET_R },
    ],
    extra: face,
  };
}

/**
 * One arm, authored once in its own space and posed by a transform.
 *
 * Local space puts the shoulder at the origin and the arm along +x, so the hand
 * — palm and three fanned fingers — is the same markup in every pose and the
 * only thing that changes is `translate(shoulder) rotate(θ)` and the reach.
 * That is what makes the arm poseable rather than redrawn.
 *
 * `front` is the one tonal decision a pose makes about an arm: an arm crossing
 * in front of the torso steps *up* the ramp, because the nearer thing is the lit
 * one. It used to step to `#8FDCAC`, which was so far up that `scrub`'s cupped
 * hands read as a reflection rather than as hands.
 */
function armNode(side, shoulder, hand, { front = false } = {}) {
  const [sx, sy] = shoulder;
  const [hx, hy] = hand;
  const dx = hx - sx;
  const dy = hy - sy;
  const len = Math.hypot(dx, dy) || 1;
  const deg = (Math.atan2(dy, dx) * 180) / Math.PI;
  const tone = front ? T.fillHighlight : T.fillShadow;
  const finger = (a) => ({
    t: 'l', x1: 0, y1: 0,
    x2: n2(Math.cos((a * Math.PI) / 180) * FINGER_LEN),
    y2: n2(Math.sin((a * Math.PI) / 180) * FINGER_LEN),
    w: FINGER_W,
  });
  return {
    id: `${side}-arm`,
    transform: `translate(${n2(sx)} ${n2(sy)}) rotate(${n2(deg)})`,
    tone,
    shapes: [{ t: 'l', x1: 0, y1: 0, x2: n2(len), y2: 0, w: ARM_W }],
    children: [{
      id: `${side}-hand`,
      transform: `translate(${n2(len)} 0)`,
      tone,
      shapes: [{ t: 'c', cx: 0, cy: 0, r: PALM_R }, ...FINGER_ANGLES.map(finger)],
    }],
  };
}

/**
 * One leg, hip to ankle, with a three-toed foot.
 *
 * `sign` −1 is Hop's right (the viewer's left); toes fan outward and down like
 * the reference. The foot un-rotates the shin — `rotate(-θ)` inside the leg
 * group — because a frog's foot stays flat on the ground however the shin is
 * angled, and because the toe fan is measured from the horizon, not from the
 * leg. That leaves the foot independently poseable: give the inner `rotate` a
 * different number and the ankle bends without touching the shin.
 *
 * The fan is shallow — the reference's toes splay across the ground rather than
 * hanging off the front of the foot. The steepest toe used to point almost
 * straight down at 82°, which put the lowest ink below the ground shadow.
 */
function legNode(side, sign, hip, ankle, spread) {
  const [hx, hy] = hip;
  const [ax, ay] = ankle;
  const len = Math.hypot(ax - hx, ay - hy) || 1;
  const deg = (Math.atan2(ay - hy, ax - hx) * 180) / Math.PI;
  const base = sign < 0 ? 180 : 0;
  const out = (d) => (sign < 0 ? base + d : base - d);
  const toe = ([d, r]) => {
    const a = (out(d) * Math.PI) / 180;
    return {
      t: 'l', x1: 0, y1: 0,
      x2: n2(Math.cos(a) * 15 * spread), y2: n2(Math.sin(a) * 10), w: r * 2,
    };
  };
  const crease = (d) => {
    const a = (out(d) * Math.PI) / 180;
    return `<line x1="${n2(Math.cos(a) * 5)}" y1="${n2(Math.sin(a) * 5)}" x2="${n2(Math.cos(a) * 14 * spread)}" y2="${n2(Math.sin(a) * 12)}" stroke="${T.fillDeep}" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/>`;
  };
  return {
    id: `${side}-leg`,
    transform: `translate(${n2(hx)} ${n2(hy)}) rotate(${n2(deg)})`,
    tone: T.fillDeep,
    shapes: [{ t: 'l', x1: 0, y1: 0, x2: n2(len), y2: 0, w: LEG_W }],
    children: [{
      id: `${side}-foot`,
      transform: `translate(${n2(len)} 0) rotate(${n2(-deg)}) translate(${-sign * 2} 3)`,
      tone: T.fillShadow,
      shapes: [{ t: 'e', cx: 0, cy: 0, rx: SOLE.rx, ry: SOLE.ry }, ...TOES.map(toe)],
      extra: CREASES.map(crease).join(''),
    }],
  };
}

/**
 * Torso: straight sides that run up under the jaw, rounded only at the hips.
 * A capsule with rounded top corners narrowed just below the jaw and read as a
 * neck; the reference has none — the body tucks straight up behind the head.
 */
function bodyNode({ squash = 0, width = 58 } = {}) {
  const x0 = 75 - width / 2;
  const x1 = 75 + width / 2;
  const top = 58 + squash * 4;
  const bottom = 127 - squash * 4;
  const r = Math.min(26, width / 2);
  return {
    id: 'body',
    tone: T.fill,
    shapes: [{
      t: 'p',
      d: `M ${n2(x0)} ${n2(top)} H ${n2(x1)} V ${n2(bottom - r)} A ${r} ${r} 0 0 1 ${n2(x1 - r)} ${n2(bottom)} H ${n2(x0 + r)} A ${r} ${r} 0 0 1 ${n2(x0)} ${n2(bottom - r)} Z`,
    }],
  };
}

/** The cream belly. Inside the torso, so it is neither outlined nor part of the
 *  silhouette: cream on green is already the strongest separation in the
 *  drawing, and a rim around it would read as a bib. */
function bellyNode(scale) {
  return {
    id: 'belly', tone: T.belly, rim: false, sil: false,
    shapes: [{ t: 'e', cx: 75, cy: n2(104 + (scale - 1) * 4), rx: n2(24 * scale), ry: n2(23 * scale) }],
  };
}

/** The adventure pack, worn on the back; only its edge and strap show. */
function bagNode() {
  return {
    id: 'optional-bag', tone: T.bagBody,
    shapes: [{ t: 'r', x: 98, y: 84, w: 22, h: 30, r: 9 }],
    children: [{
      id: 'bag-strap', tone: T.bagStrap,
      shapes: [{ t: 's', d: 'M 92 78 q 12 4 16 20', w: 4 }],
    }],
  };
}

// ---------------------------------------------------------------------------
// The face
// ---------------------------------------------------------------------------

/** The three darker spots on the forehead, exactly where the reference puts them. */
function spots() {
  return `
    <ellipse cx="75.3" cy="19.4" rx="4.4" ry="2.6" fill="${T.fillDeep}"/>
    <ellipse cx="72.8" cy="26.2" rx="2.6" ry="1.9" fill="${T.fillDeep}"/>
    <ellipse cx="80.6" cy="24.6" rx="3.0" ry="1.6" fill="${T.fillDeep}"/>`;
}

function nostrils() {
  return `
    <circle cx="67.4" cy="41" r="2.1" fill="${T.ink}"/>
    <circle cx="82.6" cy="41" r="2.1" fill="${T.ink}"/>`;
}

function cheeks() {
  return `<g id="cheeks">
    <circle cx="32" cy="51" r="7.6" fill="${T.cheek}"/>
    <circle cx="118" cy="51" r="7.6" fill="${T.cheek}"/></g>`;
}

/**
 * Eyes. `blink` 0…1 closes the lid; `mood` picks the closed-eye line — a happy
 * upward arc for celebrating, a soft downward arc for resting.
 *
 * The shape of this markup is a contract with `Scripts/web/motion.js`. Its
 * blink rule matches a bare `<g>` followed by the eye's `<clipPath>` and stops
 * at the first `</g></g>`, so `left-eye`/`right-eye` wrap that group from
 * outside and are still standing after the substitution — which is what lets a
 * derived blink stay byte-identical to `hop-blink.svg`. The pupil carries its id
 * on the circle for the same reason: a `<g id="left-pupil">` inside the clip
 * would end the gaze rule's lazy match early and freeze the catchlight.
 */
function eyes({ gaze = [0, 0], blink = 0, mood = 'happy', lidDrop = 0 } = {}) {
  const [gx, gy] = gaze;
  const one = ({ cx, cy }, side) => {
    if (blink >= 1) {
      const dir = mood === 'rest' ? 1 : -1;
      return `<path d="M ${cx - 10} ${cy + 3} Q ${cx} ${cy + 3 + dir * 9} ${cx + 10} ${cy + 3}"
        fill="none" stroke="${T.ink}" stroke-width="3.2" stroke-linecap="round"/>`;
    }
    const lid = lidDrop > 0
      ? `<circle cx="${cx}" cy="${(cy - (2 * WHITE_R + 1 - 2 * WHITE_R * lidDrop)).toFixed(1)}" r="${WHITE_R + 1}" fill="${T.fill}"/>`
      : '';
    // The lid is clipped to the white so a lowered lid never shows outside the
    // eye — unclipped it read as a pair of ears above the head.
    const clipId = `eyeClip${Math.round(cx)}`;
    return `<g>
      <clipPath id="${clipId}"><circle cx="${cx}" cy="${cy}" r="${WHITE_R}"/></clipPath>
      <circle cx="${cx}" cy="${cy}" r="${WHITE_R}" fill="${T.eyeWhite}"/>
      <g clip-path="url(#${clipId})">
        <circle id="${side}-pupil" cx="${cx + gx}" cy="${cy + 1 + gy}" r="${PUPIL_R}" fill="${T.pupil}"/>
        <circle cx="${cx + gx + 3.2}" cy="${cy - 4 + gy}" r="3.4" fill="${T.highlight}"/>
        ${lid}
      </g>
    </g>`;
  };
  return `<g id="eyes-group"><g id="left-eye">${one(EYE_L, 'left')}</g><g id="right-eye">${one(EYE_R, 'right')}</g></g>`;
}

/**
 * Mouth. `open`: the reference's wide smile with tongue. `talk`: the same at
 * 70%, for speech. `closed`: a calm smile line. `small`: a resting smile.
 *
 * The inner scaled group is what `motion.js` rewrites to derive `smile` and
 * `talkShut`; `<g id="mouth">` wraps it from outside for the same reason the
 * eyes do.
 */
function mouth(kind = 'open') {
  if (kind === 'closed' || kind === 'small') {
    const d = kind === 'closed' ? 12 : 8;
    return `<g id="mouth"><path d="M 58 50 Q 75 ${50 + d} 92 50" fill="none" stroke="${T.ink}" stroke-width="3.4" stroke-linecap="round"/></g>`;
  }
  const s = kind === 'talk' ? 0.72 : 1;
  const uid = 'mouthClip' + kind;
  return `<g id="mouth"><g transform="translate(75 50) scale(${s}) translate(-75 -50)">
    <clipPath id="${uid}">
      <path d="M 53 47.5 Q 75 52 97 47.5 C 96 60 88 69.5 75 69.5 C 62 69.5 54 60 53 47.5 Z"/>
    </clipPath>
    <path d="M 53 47.5 Q 75 52 97 47.5 C 96 60 88 69.5 75 69.5 C 62 69.5 54 60 53 47.5 Z" fill="${T.mouthInterior}"/>
    <ellipse cx="75" cy="66" rx="15" ry="7.5" fill="${T.tongue}" clip-path="url(#${uid})"/>
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
  return `<g id="wiggle" fill="none" stroke="${T.fillDeep}" stroke-width="2.4" stroke-linecap="round" opacity="0.6">
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
 * Depth order is fixed and is half of the separation system: bag, legs, torso,
 * belly, arms, head. Each part's rim lands on whatever is already under it, so
 * the order decides which boundaries exist. Arms are never drawn after the head
 * — partly because a frog whose eyes are at the corners of his own silhouette
 * has nowhere to put a forearm that is not across an eye, and partly because
 * `widget-face.js` reads everything after the crown as face and would not know
 * what an arm was.
 */
function figure(p = {}) {
  const {
    lift = 0, squash = 0, tilt = 0, lean = 0,
    // The reference hangs the arms down and out at roughly 30°, not straight
    // out at shoulder height: horizontal arms read as poles bolted to a barrel,
    // and reached past both edges of the canvas.
    armL = [22, 103], armR = [128, 103], frontL = false, frontR = false,
    legL = { hip: [56, 124], ankle: [52, ANKLE], spread: 1 },
    legR = { hip: [94, 124], ankle: [98, ANKLE], spread: 1 },
    eyes: eyeOpts = {}, mouth: mouthKind = 'open',
    withPack = false, sleeping = false, showShadow = true,
    bellyScale = 1, tongueTo = null, wiggling = false,
    torsoWidth = 58,
  } = p;

  const face = [
    `<g id="accent-details">${spots()}</g>`,
    eyes(eyeOpts),
    cheeks(),
    nostrils(),
    mouth(mouthKind),
    tongueTo ? tongue(tongueTo) : '',
  ].join('');

  const body = [
    withPack ? bagNode() : null,
    legNode('left', -1, legL.hip, legL.ankle, legL.spread),
    legNode('right', 1, legR.hip, legR.ankle, legR.spread),
    bodyNode({ squash, width: torsoWidth }),
    bellyNode(bellyScale),
    armNode('left', SHOULDER_L, armL, { front: frontL }),
    armNode('right', SHOULDER_R, armR, { front: frontR }),
    headNode(tilt, face),
  ].filter(Boolean);

  return {
    shadow: showShadow ? shadowNode(lift) : null,
    body,
    transform: `translate(0 ${-lift}) translate(75 100) rotate(${lean}) translate(-75 -100)`,
    after: (wiggling ? wiggle() : '') + (sleeping ? zzz() : ''),
  };
}

/** A figure, rendered at one outline level. */
function render(fig, ctx) {
  const silhouette = ctx.flat || ctx.level.exterior <= 0
    ? ''
    : `<g id="hop-silhouette" fill="${T.outline}" stroke="${T.outline}" stroke-linejoin="round" stroke-linecap="round">` +
      fig.body.map((n) => silhouetteNode(n, ctx)).join('') + '</g>';
  const parts = fig.body.map((n) => drawNode(n, ctx)).join('');
  const shadow = fig.shadow && !ctx.flat ? drawNode(fig.shadow, ctx) : '';
  return `<g id="hop-root">${shadow}<g id="hop-figure" transform="${fig.transform}">` +
    silhouette + parts + (ctx.flat ? '' : fig.after) + '</g></g>';
}

function context(opts = {}) {
  return {
    level: OUTLINE[opts.level || 'default'] || OUTLINE.default,
    flat: !!opts.flat,
    flatColour: opts.flatColour || T.outline,
    omit: opts.omit && opts.omit.length ? new Set(opts.omit) : null,
    only: opts.only && opts.only.length ? new Set(opts.only) : null,
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
 * Fifteen poses. Every one of them was checked as a flat silhouette — see
 * `node Scripts/hop-lab.js --silhouette` — and where a limb vanished the *pose*
 * was moved before anything was done to the stroke.
 */
const poses = {
  /** The reference pose: arms wide, open smile. App icon and dashboard chip. */
  idle: () => figure({}),

  /** Eyes closed mid-blink; cross-faded with `idle` for the ambient loop. */
  blink: () => figure({ eyes: { blink: 1, mood: 'rest' } }),

  /** Speaking a line, one hand raised toward the child. Also Hop pointing at a
   *  button, which is the same gesture with the gaze moved. */
  talk: () => figure({ mouth: 'talk', armR: [131, 84], eyes: { gaze: [0, 1] } }),

  /** Waving hello. Onboarding and the shield greeting.
   *  The waving hand sits clear of the jaw's outer edge rather than on it: at
   *  y=42 the head still measures 124 units across, so a hand at x=127 was a
   *  bump on the silhouette instead of a wave. */
  wave: () => figure({ armR: [134, 38], armL: [24, 108], tilt: -3, eyes: { gaze: [1, 0] } }),

  /** Walking to the bathroom with the pack — Hop holding something, and leaning.
   *  The trailing arm swings behind the hip so the two arms are separable in
   *  silhouette rather than one shape either side of the belly. */
  walk: () => figure({
    lean: 4, withPack: true,
    armL: [26, 114], armR: [118, 74],
    legL: { hip: [55, 122], ankle: [40, ANKLE], spread: 1 },
    legR: { hip: [95, 122], ankle: [106, ANKLE - 8], spread: 0.8 },
    eyes: { gaze: [2, 0] }, mouth: 'talk',
  }),

  /** Waiting patiently on the potty — sat down, hands resting, calm. Also the
   *  quiz-thinking pose: still, hands down, eyes lowered. */
  wait: () => figure({
    lift: -6, squash: 0.3,
    armL: [26, 122], armR: [124, 122],
    legL: { hip: [55, 122], ankle: [38, ANKLE - 6], spread: 1.1 },
    legR: { hip: [95, 122], ankle: [112, ANKLE - 6], spread: 1.1 },
    eyes: { gaze: [0, 3], lidDrop: 0.35 }, mouth: 'small',
  }),

  /**
   * Mid-hop, airborne. The celebration.
   *
   * `lift` is the one parameter that costs the whole set size: every pose is
   * scaled to fit the tallest thing any pose draws, and the crown of a lifted
   * Hop is it. Eight is as high as he goes before everyone else shrinks.
   *
   * The arms used to end at x=23 and x=127 at eye height, which is *inside* the
   * head — the jaw is 122 units wide — so a jumping Hop had no arms at all in
   * silhouette. They now sweep down and back from the shoulder, which is what a
   * jumping frog does and which puts both hands outside every other shape. The
   * legs tuck asymmetrically for the same reason: two identical tucked legs are
   * one leg.
   */
  jump: () => figure({
    lift: 8, squash: -0.15,
    armL: [14, 74], armR: [136, 74],
    legL: { hip: [55, 122], ankle: [40, 134], spread: 0.9 },
    legR: { hip: [95, 122], ankle: [106, 142], spread: 0.9 },
    eyes: { blink: 1, mood: 'happy' }, mouth: 'open',
  }),

  /**
   * Both arms up. The star-earned moment.
   *
   * Out as well as up: Hop's eye sockets are the widest part of him at that
   * height, so hands raised overhead vanish behind his own head. The hands sit
   * at the head's upper corners and just outside them, and the head's own rim
   * cuts across the forearms — which is what turns "a lumpy head" into "arms
   * behind the head".
   */
  cheer: () => figure({
    lift: 2,
    armL: [15, 30], armR: [135, 30],
    eyes: { gaze: [0, -2] }, mouth: 'open',
  }),

  /** Resting during quiet hours and "paused until tomorrow". */
  sleep: () => figure({
    tilt: 4, lift: -4, squash: 0.2, sleeping: true,
    armL: [26, 120], armR: [124, 120],
    legL: { hip: [56, 124], ankle: [50, ANKLE - 4], spread: 1 },
    legR: { hip: [94, 124], ankle: [100, ANKLE - 4], spread: 1 },
    eyes: { blink: 1, mood: 'rest' }, mouth: 'small',
  }),

  /** Landing frame after a jump — the squash before the settle. */
  land: () => figure({
    squash: 0.5,
    armL: [18, 122], armR: [132, 122],
    legL: { hip: [55, 120], ankle: [42, ANKLE], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [108, ANKLE], spread: 1.2 },
    eyes: { gaze: [0, 2] }, mouth: 'open',
  }),

  // ---- Mini-game states ----

  /**
   * Frog squat on a lily pad, watching the sky. Fly Snack's resting state.
   *
   * The hands come down past the hips and onto the pad: with the arms tucked at
   * the waist they were the torso's own green over the torso and Hop read as a
   * legless bust.
   */
  sit: () => figure({
    lift: -10, squash: 0.35,
    armL: [44, 130], armR: [106, 130], frontL: true, frontR: true,
    legL: { hip: [55, 120], ankle: [30, ANKLE - 10], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [120, ANKLE - 10], spread: 1.2 },
    eyes: { gaze: [0, -3] }, mouth: 'small',
  }),

  /** Tongue out for a fly. Same squat; the tongue reaches toward `tongueTo`. */
  catch: () => figure({
    lift: -10, squash: 0.35,
    armL: [44, 130], armR: [106, 130], frontL: true, frontR: true,
    legL: { hip: [55, 120], ankle: [30, ANKLE - 10], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [120, ANKLE - 10], spread: 1.2 },
    // Out sideways at mouth height. Aimed up at the fly it crossed his own
    // eye, and a pink bar over the pupil reads as damage, not as a tongue.
    eyes: { gaze: [3, -4] }, mouth: 'open', tongueTo: [138, 53],
  }),

  /**
   * Tummy full, and the body saying so. Bigger belly, hands on it, knees
   * together, a small bashful smile — kind, never distressed. This is the
   * moment the child learns to notice.
   *
   * The two hands are held at different heights and different reaches: level
   * with each other they fused into one green mitten across the belly.
   */
  full: () => figure({
    squash: 0.1, bellyScale: 1.28, torsoWidth: 68, wiggling: true,
    armL: [50, 122], armR: [88, 106], frontL: true, frontR: true,
    legL: { hip: [55, 124], ankle: [64, ANKLE], spread: 0.9 },
    legR: { hip: [95, 124], ankle: [86, ANKLE], spread: 0.9 },
    eyes: { gaze: [0, 3], lidDrop: 0.15 }, mouth: 'small',
  }),

  /**
   * Hands held out front, palms up, for washing and wiping games — and the
   * "hands together" pose the routine ends on.
   *
   * The hands are offset rather than symmetrical for the same reason `full`'s
   * are: two hands at the same height and the same reach are one shape.
   */
  scrub: () => figure({
    armL: [60, 118], armR: [92, 106], frontL: true, frontR: true,
    eyes: { gaze: [0, 4] }, mouth: 'talk',
  }),
};

/**
 * Head only, for avatars and the app icon.
 *
 * A crop, not a pose — and the only drawing here that keeps the original
 * `translate(16 8) scale(3.2)`. Its box is already tight on the head, and it is
 * used at chip sizes where a head that suddenly shrank by a tenth would show.
 * `HopPoseGeometry.faceCrop` is this rectangle, and stays matched to it.
 */
function faceSVG(ctx) {
  const face = [
    `<g id="accent-details">${spots()}</g>`,
    eyes({}), cheeks(), nostrils(), mouth('open'),
  ].join('');
  const head = headNode(0, face);
  const silhouette = ctx.flat || ctx.level.exterior <= 0
    ? ''
    : `<g id="hop-silhouette" fill="${T.outline}" stroke="${T.outline}" stroke-linejoin="round" stroke-linecap="round">` +
      silhouetteNode(head, ctx) + '</g>';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 290" width="512" height="290">
<g transform="translate(16 8) scale(3.2)">
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

/** The anatomical ids a silhouette check can hide one at a time. */
const LIMB_IDS = [
  'head', 'body', 'left-arm', 'right-arm', 'left-hand', 'right-hand',
  'left-leg', 'right-leg', 'left-foot', 'right-foot',
];

module.exports = {
  T, OUTLINE, CANVAS, STAGE, GROUND, ANKLE, SCALE, OX, OY, FEET_FRACTION,
  poses, POSE_NAMES, LIMB_IDS, poseSVG,
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
  console.log(`outline    ${level}: exterior ${OUTLINE[level].exterior}, ` +
    `inner ${OUTLINE[level].inner} at ${OUTLINE[level].innerOpacity}`);
}
