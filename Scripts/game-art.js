#!/usr/bin/env node
/**
 * Backdrops and sprites for the five new mini-games.
 *
 * A sibling of `scene-art.js`, not an extension of it: that file is being
 * edited elsewhere, so the palette, the gradient library and the handful of
 * primitives this one needs are copied in rather than imported. The copies are
 * verbatim, which is what keeps the two files drawing the same house style —
 * same brand hues, same soft gradients, same rounded silhouettes.
 *
 * Output
 * ------
 *   Art/scenes/games-flySnack.svg     pond at dusk, hero lily pad, open sky
 *   Art/scenes/games-mudOff.svg       garden tap and basin, clear centre
 *   Art/scenes/games-bodySignal.svg   playroom with the bathroom door at right
 *   Art/scenes/games-flushWave.svg    friendly bathroom, flusher and bowl clear
 *   Art/scenes/games-pottyOrder.svg   soft path with four empty card slots
 *   Art/icons/games-*.svg             the sprites the games move around
 *
 * File names are load bearing. `HopIllustrationKey.assetName` drops the family
 * segment and joins the rest with hyphens, case preserved: `icon.games.fly.blue`
 * resolves to `games-fly-blue.svg` and nothing else. Renaming a file here
 * silently unhooks it from the content layer.
 *
 * Hop is never drawn into a scene. The app composites the live character over
 * these backdrops, so a painted Hop would read as a twin standing behind him.
 * Every scene leaves a clear stage — see the STAGE note above each one for
 * where his feet land.
 */
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Palette. Copied from scene-art.js, which mirrors HopPalette.swift exactly.
// ---------------------------------------------------------------------------
const P = {
  hopGreen: '#63C88A', hopGreenLight: '#8FDCAC', hopGreenDeep: '#2F8C57',
  hopGreenInk: '#1B5E39', hopGreenSoft: '#E3F5EA',
  pondBlue: '#6FC7E8', pondBlueLight: '#9BDCF1', pondBlueDeep: '#2A87AC',
  pondBlueInk: '#15566F', pondBlueSoft: '#E0F4FC',
  sunshine: '#FFD769', sunshineBright: '#FFC53D', sunshineSoft: '#FFF3D4',
  sunshineDeep: '#A87A0C', sunshineInk: '#7A5A08',
  peach: '#FF9F8F', peachSoft: '#FFE8E3', peachDeep: '#C96755', peachInk: '#8A3F30',
  lavender: '#AFA5EF', lavenderSoft: '#EFEDFB', lavenderDeep: '#6F63C0', lavenderInk: '#453B85',
  midnight: '#243047', cloud: '#FFF9F2',
  sand50: '#FFFCF8', sand100: '#F7F1E9', sand200: '#EBE3D8', sand300: '#D8CEC1',
  sand400: '#AFA69B', sand500: '#7D766D', sand600: '#5A544D',
  night900: '#14192A', night800: '#1B2337', night700: '#243047', night600: '#33415C', night500: '#4C5A76',
  white: '#FFFFFF',

  // Illustration-only extensions, as in scene-art.js.
  wood: '#C98A5B', woodDeep: '#A76F46', woodLight: '#E0A472',
  handLight: '#FFDCC9', handMid: '#F5C4A9', handDeep: '#DCA084',
  porcelain: '#FFFFFF', porcelainMid: '#F4F1EC', porcelainShade: '#E4DFD8',
};

// ---------------------------------------------------------------------------
// Gradient library. `autoDefs` emits only what a drawing references.
// ---------------------------------------------------------------------------
const stops = (list) => list.map(([o, c, a]) =>
  `<stop offset="${o}" stop-color="${c}"${a === undefined ? '' : ` stop-opacity="${a}"`}/>`).join('');
const lin = (id, list, { x1 = 0, y1 = 0, x2 = 0, y2 = 1 } = {}) =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${stops(list)}</linearGradient>`;
const rad = (id, list, { cx = 0.5, cy = 0.5, r = 0.5 } = {}) =>
  `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}">${stops(list)}</radialGradient>`;

const DEFS = {
  // -- Shared with scene-art.js --
  groundShadow: rad('groundShadow', [[0, P.midnight, 0.20], [1, P.midnight, 0]]),
  softShadow: rad('softShadow', [[0, P.midnight, 0.14], [1, P.midnight, 0]]),
  skyPond: lin('skyPond', [[0, '#CFEDF9'], [0.55, P.pondBlueSoft], [1, P.sunshineSoft]]),
  skyWarm: lin('skyWarm', [[0, '#CFE9F6'], [0.42, '#E6F5FB'], [0.75, P.sunshineSoft], [1, '#FFF0E2']]),
  sunGlow: rad('sunGlow', [[0, P.sunshine, 0.95], [0.45, P.sunshine, 0.45], [1, P.sunshine, 0]]),
  sunDisc: rad('sunDisc', [[0, '#FFF0C2'], [1, P.sunshine]], { cx: 0.4, cy: 0.35, r: 0.75 }),
  cloudFill: lin('cloudFill', [[0, '#FFFFFF'], [1, '#EAF3F8']]),
  hillFar: lin('hillFar', [[0, '#C7E9D6'], [1, '#AEDFC4']]),
  hillMid: lin('hillMid', [[0, '#A9DEC0'], [1, '#8CD1A9']]),
  ground: lin('ground', [[0, '#A8DFC0'], [0.5, P.hopGreenLight], [1, '#7ECBA0']]),
  groundNear: lin('groundNear', [[0, '#7CC79E'], [1, '#5FB287']]),
  water: lin('water', [[0, P.pondBlueLight], [0.55, P.pondBlue], [1, '#57B6DC']]),
  shoreSand: lin('shoreSand', [[0, P.sand100], [1, P.sand200]]),
  padGreen: lin('padGreen', [[0, P.hopGreenLight], [1, P.hopGreenDeep]], { x1: 0.2, x2: 0.9 }),
  padGreenLight: lin('padGreenLight', [[0, '#A7E6C2'], [1, P.hopGreen]], { x1: 0.2, x2: 0.9 }),
  bladeGreen: lin('bladeGreen', [[0, P.hopGreenLight], [1, P.hopGreenDeep]]),
  fernGreen: lin('fernGreen', [[0, '#8FD9AF'], [1, P.hopGreenDeep]]),
  petalWhite: lin('petalWhite', [[0, '#FFFFFF'], [1, P.peachSoft]]),
  woodGrad: lin('woodGrad', [[0, P.woodLight], [1, P.woodDeep]], { x1: 0.2, x2: 0.9 }),
  woodGradV: lin('woodGradV', [[0, P.woodLight], [1, P.wood]]),
  stoneGrad: lin('stoneGrad', [[0, '#EFEAE3'], [1, '#C9C2B8']], { x1: 0.25, x2: 0.85 }),
  porcelainGrad: lin('porcelainGrad', [[0, '#FFFFFF'], [0.6, P.porcelainMid], [1, P.porcelainShade]], { x1: 0.2, x2: 0.9 }),
  porcelainSide: lin('porcelainSide', [[0, P.porcelainMid], [1, '#DAD4CB']], { x1: 0, x2: 1, y2: 0 }),
  glowWarm: rad('glowWarm', [[0, P.sunshine, 0.75], [0.5, P.sunshine, 0.28], [1, P.sunshine, 0]]),
  bubbleFill: rad('bubbleFill', [[0, '#FFFFFF', 0.95], [0.55, P.pondBlueSoft, 0.7], [1, P.pondBlueLight, 0.55]], { cx: 0.36, cy: 0.3, r: 0.8 }),
  waterStream: lin('waterStream', [[0, P.pondBlueLight, 0.95], [1, P.pondBlue, 0.75]]),
  peachBall: rad('peachBall', [[0, '#FFC0B2'], [1, P.peachDeep]], { cx: 0.35, cy: 0.3, r: 0.8 }),
  yellowBall: rad('yellowBall', [[0, '#FFE9A8'], [1, P.sunshineBright]], { cx: 0.35, cy: 0.3, r: 0.8 }),
  lavenderBall: rad('lavenderBall', [[0, '#D6D0F7'], [1, P.lavenderDeep]], { cx: 0.35, cy: 0.3, r: 0.8 }),
  greenBall: rad('greenBall', [[0, '#A7E6C2'], [1, P.hopGreenDeep]], { cx: 0.35, cy: 0.3, r: 0.8 }),
  blueBall: rad('blueBall', [[0, '#BDE9F8'], [1, P.pondBlueDeep]], { cx: 0.35, cy: 0.3, r: 0.8 }),
  handGrad: lin('handGrad', [[0, P.handLight], [1, P.handMid]], { x1: 0.2, x2: 0.9 }),
  handGradDeep: lin('handGradDeep', [[0, P.handMid], [1, P.handDeep]], { x1: 0.2, x2: 0.9 }),
  towelGrad: lin('towelGrad', [[0, '#A8DCF2'], [1, '#6FC0E2']]),
  paperSheet: lin('paperSheet', [[0, '#FFFFFF'], [1, P.sand100]], { x1: 0.2, x2: 0.9 }),
  metalGrad: lin('metalGrad', [[0, P.sand100], [1, P.sand400]], { x1: 0.15, x2: 0.9 }),

  // -- New to the games set --------------------------------------------------
  // Dusk is the one lighting condition the existing scenes do not cover. It is
  // still warm: the sky runs blue at the top into gold at the waterline, never
  // into grey, so Fly Snack sits beside the daylit scenes rather than apart.
  skyDusk: lin('skyDusk', [[0, '#8FC8E9'], [0.38, '#BFE1F1'], [0.68, P.sunshineSoft], [1, '#FFD3A2']]),
  waterDusk: lin('waterDusk', [[0, '#B6E4F5'], [0.35, P.pondBlue], [1, '#3E9EC6']]),
  goldPath: lin('goldPath', [[0, P.sunshine, 0.75], [1, P.sunshine, 0]]),
  hedgeGreen: lin('hedgeGreen', [[0, '#8AD3A9'], [1, '#4FA97A']]),
  wallWarm: lin('wallWarm', [[0, '#FFF6EA'], [1, '#F1E3D2']], { x1: 0.2, x2: 0.9 }),
  rugGrad: lin('rugGrad', [[0, P.peachSoft], [1, '#FFD3C7']], { x1: 0.15, x2: 0.9 }),
  slotWell: lin('slotWell', [[0, '#FFFFFF', 0.85], [1, '#FFFFFF', 0.45]]),

  // Sprite bodies. Each fly is one radial ramp so all three read as the same
  // animal in three coats, the way the pond frogs do.
  flyBlue: rad('flyBlue', [[0, '#C9EDFA'], [0.55, P.pondBlue], [1, P.pondBlueDeep]], { cx: 0.34, cy: 0.28, r: 0.82 }),
  flyGreen: rad('flyGreen', [[0, '#CCF2DC'], [0.55, P.hopGreen], [1, P.hopGreenDeep]], { cx: 0.34, cy: 0.28, r: 0.82 }),
  flyGold: rad('flyGold', [[0, '#FFF0C4'], [0.55, P.sunshine], [1, '#D9A21E']], { cx: 0.34, cy: 0.28, r: 0.82 }),
  wingGlass: rad('wingGlass', [[0, '#FFFFFF', 0.92], [0.6, '#FFFFFF', 0.6], [1, P.pondBlueSoft, 0.35]], { cx: 0.34, cy: 0.3, r: 0.8 }),

  mudBrown: rad('mudBrown', [[0, '#D9A778'], [0.55, '#B07747'], [1, '#7E4F2B']], { cx: 0.34, cy: 0.3, r: 0.85 }),
  mudGreen: rad('mudGreen', [[0, '#CBE6A6'], [0.55, '#8FBB63'], [1, '#5A7F3A']], { cx: 0.34, cy: 0.3, r: 0.85 }),
  mudPaint: rad('mudPaint', [[0, '#DCD6FA'], [0.55, P.lavender], [1, P.lavenderDeep]], { cx: 0.34, cy: 0.3, r: 0.85 }),

  cardFace: lin('cardFace', [[0, '#FFFFFF'], [1, P.sand50]], { x1: 0.2, x2: 0.85 }),
  cardPanel: lin('cardPanel', [[0, P.pondBlueSoft], [1, '#EFF8FC']], { x1: 0.2, x2: 0.85 }),
  denimGrad: lin('denimGrad', [[0, '#A8D9F0'], [1, '#4FA5CC']], { x1: 0.2, x2: 0.9 }),

  // Clips
  leafClip: '<clipPath id="leafClip"><path d="M 60 8 C 98 36 98 86 60 114 C 22 86 22 36 60 8 Z"/></clipPath>',
  pondClip: '<clipPath id="pondClip"><rect x="0" y="0" width="640" height="480"/></clipPath>',
};

/** Collect the defs a body actually references, transitively. */
function autoDefs(...bodies) {
  const body = bodies.join('\n');
  const found = new Set();
  const scan = (text) => {
    for (const m of text.matchAll(/url\(#([A-Za-z0-9_-]+)\)/g)) {
      const id = m[1];
      if (found.has(id) || !DEFS[id]) continue;
      found.add(id);
      scan(DEFS[id]);
    }
  };
  scan(body);
  // Clip paths are referenced by clip-path="url(#id)" too, so the same scan
  // catches them; nothing else to do here.
  if (!found.size) return '';
  return `<defs>${[...found].sort().map((id) => DEFS[id]).join('')}</defs>`;
}

function svg({ viewBox, width, height, body }) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" width="${width}" height="${height}">
${autoDefs(body)}
${body}
</svg>`;
}

// ---------------------------------------------------------------------------
// Shape primitives, copied from scene-art.js.
// ---------------------------------------------------------------------------
const R = (n) => Math.round(n * 100) / 100;
const g = (transform, inner) => `<g transform="${transform}">${inner}</g>`;

/** A lily pad: a squashed disc with a wedge cut out of it. */
function pad(cx, cy, r, { squash = 0.46, notch = 90, spread = 24 } = {}) {
  const pt = (deg) => {
    const a = (deg * Math.PI) / 180;
    return [R(cx + r * Math.cos(a)), R(cy + r * squash * Math.sin(a))];
  };
  const [x0, y0] = pt(notch + spread);
  const [x1, y1] = pt(notch - spread);
  return `M ${x0} ${y0} A ${R(r)} ${R(r * squash)} 0 1 1 ${x1} ${y1} L ${R(cx)} ${R(cy)} Z`;
}

/** A grass blade / reed: rooted wide, curving to a soft tip. */
function blade(x, baseY, h, curve, w) {
  const tx = x + curve, ty = baseY - h;
  return `M ${R(x - w)} ${R(baseY)}
    Q ${R(x - w * 0.45 + curve * 0.3)} ${R(baseY - h * 0.6)} ${R(tx - w * 0.16)} ${R(ty + w * 0.3)}
    Q ${R(tx)} ${R(ty - w * 0.2)} ${R(tx + w * 0.2)} ${R(ty + w * 0.5)}
    Q ${R(x + w * 0.75 + curve * 0.25)} ${R(baseY - h * 0.5)} ${R(x + w)} ${R(baseY)} Z`;
}

/** One petal, tip pointing up from (0,0). */
function petal(len, wide) {
  return `M 0 0 C ${R(wide)} ${R(-len * 0.35)} ${R(wide * 0.62)} ${R(-len * 0.82)} 0 ${R(-len)} C ${R(-wide * 0.62)} ${R(-len * 0.82)} ${R(-wide)} ${R(-len * 0.35)} 0 0 Z`;
}

/** A five-petal flower on a stem. */
function flower(cx, cy, r, { fill = 'url(#yellowBall)', core = P.sunshineSoft, petals = 5, stem = true, stemH = 46 } = {}) {
  const ring = Array.from({ length: petals }, (_, i) =>
    g(`translate(${R(cx)} ${R(cy)}) rotate(${R((360 / petals) * i)})`,
      `<path d="${petal(r, r * 0.56)}" fill="${fill}"/>`)).join('');
  const stalk = stem
    ? `<path d="M ${R(cx)} ${R(cy)} q ${R(r * 0.3)} ${R(stemH * 0.55)} ${R(r * 0.06)} ${R(stemH)}" fill="none" stroke="${P.hopGreenDeep}" stroke-width="${R(r * 0.22)}" stroke-linecap="round"/>
       <path d="M ${R(cx + r * 0.12)} ${R(cy + stemH * 0.55)} q ${R(r * 0.75)} ${R(-r * 0.4)} ${R(r * 0.95)} ${R(r * 0.16)} q ${R(-r * 0.6)} ${R(r * 0.42)} ${R(-r * 0.95)} ${R(-r * 0.16)} Z" fill="${P.hopGreen}"/>`
    : '';
  return `${stalk}${ring}<circle cx="${R(cx)}" cy="${R(cy)}" r="${R(r * 0.3)}" fill="${core}"/>`;
}

/** A rounded pebble with a soft top light. */
function pebble(cx, cy, rx, ry, { fill = 'url(#stoneGrad)', light = 0.5 } = {}) {
  return `<ellipse cx="${R(cx)}" cy="${R(cy)}" rx="${R(rx)}" ry="${R(ry)}" fill="${fill}"/>
    <ellipse cx="${R(cx - rx * 0.18)}" cy="${R(cy - ry * 0.34)}" rx="${R(rx * 0.55)}" ry="${R(ry * 0.4)}" fill="#FFFFFF" opacity="${light * 0.5}"/>`;
}

/** A soft cloud built from three lobes on a rounded base. */
function cloud(cx, cy, w, { fill = 'url(#cloudFill)', opacity = 1 } = {}) {
  const u = w / 100;
  return `<g opacity="${opacity}"><path d="
    M ${R(cx - 46 * u)} ${R(cy + 14 * u)}
    a ${R(20 * u)} ${R(20 * u)} 0 0 1 ${R(6 * u)} ${R(-38 * u)}
    a ${R(26 * u)} ${R(26 * u)} 0 0 1 ${R(42 * u)} ${R(-14 * u)}
    a ${R(22 * u)} ${R(22 * u)} 0 0 1 ${R(40 * u)} ${R(16 * u)}
    a ${R(18 * u)} ${R(18 * u)} 0 0 1 ${R(-4 * u)} ${R(36 * u)}
    Z" fill="${fill}"/></g>`;
}

/** A fern frond drawn as one lobed, arching leaf silhouette. */
function frond(len, bend, w = 21) {
  const N = 7;
  const at = (t) => [2 * (1 - t) * t * (bend * 0.15) + t * t * bend, 2 * (1 - t) * t * (-len * 0.55) + t * t * -len];
  const half = (t) => w * Math.sin(Math.PI * Math.min(1, 0.18 + t * 0.78)) * (1 - t * 0.2);
  const pts = Array.from({ length: N + 1 }, (_, i) => at(i / N));
  let d = `M ${R(pts[0][0] - half(0))} ${R(pts[0][1])}`;
  for (let i = 1; i <= N; i++) {
    const h = half((i - 0.5) / N), hi = half(i / N);
    const mx = (pts[i - 1][0] + pts[i][0]) / 2, my = (pts[i - 1][1] + pts[i][1]) / 2;
    d += ` Q ${R(mx - h * 1.5)} ${R(my)} ${R(pts[i][0] - hi)} ${R(pts[i][1])}`;
  }
  for (let i = N - 1; i >= 0; i--) {
    const h = half((i + 0.5) / N), hi = half(i / N);
    const mx = (pts[i + 1][0] + pts[i][0]) / 2, my = (pts[i + 1][1] + pts[i][1]) / 2;
    d += ` Q ${R(mx + h * 1.5)} ${R(my)} ${R(pts[i][0] + hi)} ${R(pts[i][1])}`;
  }
  return `<path d="${d} Z" fill="url(#fernGreen)"/>
    <path d="M 0 0 Q ${R(bend * 0.15)} ${R(-len * 0.55)} ${R(bend)} ${R(-len)}" fill="none" stroke="${P.hopGreenSoft}" stroke-width="2.6" stroke-linecap="round" opacity="0.4"/>`;
}

/** A drop, point up. Copied from the event glyph set. */
const drop = (cx, cy, h, w) => {
  const top = cy - h / 2, bot = cy + h / 2, r = w;
  return `M ${cx} ${R(top)}
    C ${R(cx + w * 0.5)} ${R(top + h * 0.3)} ${R(cx + r)} ${R(bot - r * 1.1)} ${R(cx + r)} ${R(bot - r)}
    A ${R(r)} ${R(r)} 0 1 1 ${R(cx - r)} ${R(bot - r)}
    C ${R(cx - r)} ${R(bot - r * 1.1)} ${R(cx - w * 0.5)} ${R(top + h * 0.3)} ${cx} ${R(top)} Z`;
};

const contactShadow = (cx, cy, rx, ry = rx * 0.2) =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${R(ry)}" fill="url(#softShadow)"/>`;

/** Soft contact shadow in icon units. */
const iconShadow = (cx, cy, rx, ink = P.midnight, o = 0.11) =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${R(rx)}" ry="${R(rx * 0.17)}" fill="${ink}" opacity="${o}"/>`;

/** A hand: rounded palm, four fingers, a thumb, drawn from the wrist. */
function hand(fill, shade) {
  return `
    <path d="M 0 0 q -10 -60 26 -80 q 38 -20 68 4 q 30 24 22 66 q -8 42 -58 44 q -48 2 -58 -34 Z" fill="${fill}"/>
    <rect x="-6" y="-94" width="25" height="52" rx="12.5" fill="${fill}"/>
    <rect x="23" y="-110" width="25" height="68" rx="12.5" fill="${fill}"/>
    <rect x="52" y="-106" width="25" height="64" rx="12.5" fill="${fill}"/>
    <rect x="80" y="-84" width="23" height="46" rx="11.5" fill="${fill}"/>
    <path d="M 16 -40 q 42 14 78 -6" stroke="${shade}" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.35"/>`;
}

/** The pair of open hands, sized for a 120 box. Copied from the quiz set so the
 *  Wash card is literally the same hands the quiz uses. */
function handPair() {
  return [[34, 1], [86, -1]].map(([x, f]) => g(`translate(${x} 90) scale(${f} 1)`, `
      <path d="M -20 0 q -8 -34 6 -46 q 16 -14 30 -2 q 12 10 10 30 q -2 22 -22 22 q -20 0 -24 -4 Z" fill="url(#handGrad)"/>
      <rect x="-22" y="-56" width="13" height="26" rx="6.5" fill="url(#handGrad)"/>
      <rect x="-9" y="-62" width="13" height="32" rx="6.5" fill="url(#handGrad)"/>
      <rect x="4" y="-60" width="13" height="30" rx="6.5" fill="url(#handGrad)"/>
      <rect x="16" y="-50" width="12" height="22" rx="6" fill="url(#handGrad)"/>
      <path d="M -24 -34 q 22 8 42 -2" stroke="${P.handDeep}" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.4"/>`)).join('');
}

/** A hand pinching a folded square of paper, wrist at the origin. */
function wipeHand() {
  const fingers = [[-24, -60], [-11, -65], [2, -63], [15, -56]]
    .map(([x, top]) => `<rect x="${x}" y="${top}" width="12" height="${R(-top - 30)}" rx="6" fill="url(#handGrad)"/>`)
    .join('');
  return `
    <rect x="-33" y="-78" width="66" height="50" rx="8" fill="${P.sand200}"/>
    <rect x="-33" y="-82" width="66" height="50" rx="8" fill="url(#paperSheet)"/>
    <path d="M -33 -57 h 66" stroke="${P.sand200}" stroke-width="3" opacity="0.75" fill="none"/>
    <rect x="-26" y="-44" width="52" height="52" rx="18" fill="url(#handGrad)"/>
    <g transform="rotate(-16 -30 -18)"><rect x="-40" y="-32" width="15" height="30" rx="7.5" fill="url(#handGradDeep)"/></g>
    ${fingers}
    <path d="M -20 -34 q 22 8 42 -2" stroke="${P.handDeep}" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.32"/>`;
}

// ===========================================================================
// 1. SCENE SET  (640 x 480)
// ===========================================================================
const SW = 640, SH = 480;

/** The shared interior set: tinted wall, skirting, floor. Never white on white
 *  — porcelain and paper need a tinted ground to read against. */
function room({ floorY = 356, wall = P.pondBlueSoft, floor = P.sand100, skirting = P.sand200 } = {}) {
  return `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="${wall}"/>
    <circle cx="118" cy="104" r="80" fill="#FFFFFF" opacity="0.45"/>
    <circle cx="556" cy="82" r="54" fill="${P.sunshineSoft}" opacity="0.75"/>
    <rect x="0" y="${floorY}" width="${SW}" height="${SH - floorY}" fill="${floor}"/>
    <rect x="0" y="${floorY - 10}" width="${SW}" height="14" rx="7" fill="${skirting}"/>`;
}

/** Two soft rings on water, so a pad or a stem sits in the pond rather than on
 *  top of a blue rectangle. */
const ripple = (cx, cy, rx, o = 0.5) => `
  <ellipse cx="${cx}" cy="${cy}" rx="${R(rx)}" ry="${R(rx * 0.24)}" fill="none" stroke="#FFFFFF" stroke-width="4" opacity="${o}"/>
  <ellipse cx="${cx}" cy="${R(cy + rx * 0.12)}" rx="${R(rx * 0.66)}" ry="${R(rx * 0.16)}" fill="none" stroke="#FFFFFF" stroke-width="3" opacity="${R(o * 0.7)}"/>`;

/** A lily pad with thickness, veins and a highlight, drawn flat on the water. */
function lilyPad(cx, cy, r, { squash = 0.36, notch = 90, spread = 15, veins = true } = {}) {
  const vein = (deg) => {
    const a = (deg * Math.PI) / 180;
    return `<path d="M ${cx} ${cy} L ${R(cx + r * 0.86 * Math.cos(a))} ${R(cy + r * squash * 0.86 * Math.sin(a))}" stroke="${P.hopGreenInk}" stroke-width="${R(r * 0.016 + 1.2)}" opacity="0.18" stroke-linecap="round"/>`;
  };
  const angles = [130, 155, 180, 205, 230, 255, 285, 310, 335, 0, 25, 50];
  return `
    <path d="${pad(cx, cy + r * 0.055, r, { squash, notch, spread })}" fill="${P.hopGreenInk}" opacity="0.35"/>
    <path d="${pad(cx, cy, r, { squash, notch, spread })}" fill="url(#padGreen)"/>
    <path d="${pad(cx, cy - r * 0.018, r * 0.94, { squash, notch, spread: spread + 2 })}" fill="url(#padGreenLight)"/>
    ${veins ? angles.map(vein).join('') : ''}
    <ellipse cx="${R(cx - r * 0.34)}" cy="${R(cy - r * squash * 0.42)}" rx="${R(r * 0.34)}" ry="${R(r * squash * 0.3)}" fill="#FFFFFF" opacity="0.22"/>`;
}

/** A cattail: a soft stem, one long leaf and a rounded brown head. Reeds are
 *  what tells a child this blue is a pond and not a swimming pool. */
function cattail(x, baseY, h, { tilt = 0, head = true, s = 1 } = {}) {
  const topY = baseY - h;
  return g(`translate(${x} ${baseY}) rotate(${tilt}) translate(${-x} ${-baseY})`, `
    <path d="${blade(x - 14 * s, baseY, h * 0.72, -26 * s, 8 * s)}" fill="url(#bladeGreen)" opacity="0.9"/>
    <path d="${blade(x + 13 * s, baseY, h * 0.62, 24 * s, 7 * s)}" fill="url(#bladeGreen)" opacity="0.8"/>
    <path d="M ${x} ${baseY} Q ${R(x + 4 * s)} ${R(baseY - h * 0.5)} ${x} ${R(topY)}" stroke="${P.hopGreenDeep}" stroke-width="${R(5 * s)}" fill="none" stroke-linecap="round"/>
    ${head ? `<rect x="${R(x - 8 * s)}" y="${R(topY - 4 * s)}" width="${R(16 * s)}" height="${R(46 * s)}" rx="${R(8 * s)}" fill="${P.wood}"/>
    <rect x="${R(x - 8 * s)}" y="${R(topY - 4 * s)}" width="${R(7 * s)}" height="${R(46 * s)}" rx="${R(3.5 * s)}" fill="#FFFFFF" opacity="0.22"/>
    <path d="M ${x} ${R(topY - 6 * s)} v ${R(-12 * s)}" stroke="${P.hopGreenDeep}" stroke-width="${R(4 * s)}" stroke-linecap="round"/>` : ''}`);
}

/** A garden standpipe: a tap on a post with a tin basin under it. */
function gardenTap(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(6, 4, 96, 18)}
    <rect x="-13" y="-210" width="26" height="212" rx="13" fill="${P.sand300}"/>
    <rect x="-13" y="-210" width="11" height="212" rx="5.5" fill="#FFFFFF" opacity="0.45"/>
    <path d="M 0 -210 v -22 q 0 -18 18 -18 h 26" stroke="${P.sand300}" stroke-width="24" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 0 -210 v -22 q 0 -18 18 -18 h 26" stroke="${P.sand200}" stroke-width="11" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="38" y="-262" width="20" height="26" rx="9" fill="${P.sand400}"/>
    <circle cx="0" cy="-256" r="17" fill="${P.pondBlue}"/>
    <circle cx="0" cy="-256" r="9" fill="${P.pondBlueSoft}"/>
    <rect x="-30" y="-262" width="60" height="12" rx="6" fill="${P.pondBlueDeep}" opacity="0.35"/>
    <path d="M 48 -232 q -4 62 -2 108" stroke="url(#waterStream)" stroke-width="22" stroke-linecap="round" fill="none"/>
    <path d="M 42 -220 q -3 46 -2 82" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.5"/>
    <ellipse cx="46" cy="-8" rx="104" ry="30" fill="${P.sand400}" opacity="0.5"/>
    <path d="M -50 -76 h 192 q 10 0 8 12 l -14 56 q -2 10 -14 12 q -76 10 -152 0 q -12 -2 -14 -12 l -14 -56 q -2 -12 8 -12 Z" fill="url(#metalGrad)"/>
    <path d="M -50 -76 h 46 l 8 82 q -20 -2 -36 -6 q -12 -2 -14 -12 l -14 -56 q -2 -8 10 -8 Z" fill="#FFFFFF" opacity="0.4"/>
    <ellipse cx="46" cy="-76" rx="98" ry="22" fill="${P.sand300}"/>
    <ellipse cx="46" cy="-79" rx="98" ry="22" fill="url(#metalGrad)"/>
    <ellipse cx="46" cy="-77" rx="78" ry="16" fill="${P.pondBlue}"/>
    <ellipse cx="46" cy="-79" rx="78" ry="16" fill="${P.pondBlueLight}"/>
    <ellipse cx="18" cy="-83" rx="30" ry="6" fill="#FFFFFF" opacity="0.6"/>`);
}

/** A kind toilet, seen from the front.
 *
 *  Front-on rather than three-quarter because Flush Wave asks a child to find
 *  the flusher: the button has to sit square in the frame. Every edge is
 *  rounded and the porcelain is warmed towards Cloud, so it reads as a friendly
 *  object; the concentric seat ring (rim, seat, water) is what keeps it from
 *  reading as a basin on a stand.
 */
function kindToilet(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 6, 150, 26)}
    <!-- cistern -->
    <path d="M -96 -196 q 0 -20 20 -20 h 152 q 20 0 20 20 v 96 q 0 20 -20 20 h -152 q -20 0 -20 -20 Z" fill="${P.sand300}"/>
    <path d="M -96 -204 q 0 -20 20 -20 h 152 q 20 0 20 20 v 96 q 0 20 -20 20 h -152 q -20 0 -20 -20 Z" fill="url(#porcelainGrad)"/>
    <path d="M -96 -204 q 0 -20 20 -20 h 40 v 136 h -40 q -20 0 -20 -20 Z" fill="#FFFFFF" opacity="0.5"/>
    <ellipse cx="0" cy="-224" rx="96" ry="18" fill="${P.porcelainMid}"/>
    <ellipse cx="0" cy="-227" rx="96" ry="18" fill="url(#porcelainGrad)"/>
    <!-- flusher: a big soft push button, the one thing a child must find -->
    <ellipse cx="0" cy="-227" rx="40" ry="15" fill="${P.pondBlueDeep}" opacity="0.35"/>
    <ellipse cx="0" cy="-232" rx="40" ry="15" fill="url(#blueBall)"/>
    <ellipse cx="0" cy="-234" rx="26" ry="9" fill="${P.pondBlueSoft}" opacity="0.9"/>
    <ellipse cx="-12" cy="-236" rx="12" ry="4" fill="#FFFFFF" opacity="0.75"/>
    <!-- bowl -->
    <path d="M -84 -120 C -96 -52 -66 -14 -50 -6 Q 0 12 50 -6 C 66 -14 96 -52 84 -120 Z" fill="url(#porcelainGrad)"/>
    <path d="M -84 -120 C -96 -52 -66 -14 -50 -6 Q -34 0 -20 2 C -48 -20 -60 -66 -56 -120 Z" fill="#FFFFFF" opacity="0.45"/>
    <path d="M -58 4 q 58 16 116 0 l 6 22 q -62 16 -128 0 Z" fill="${P.sand200}"/>
    <!-- concentric seat: rim, seat ring, water -->
    <ellipse cx="0" cy="-116" rx="112" ry="40" fill="${P.sand300}"/>
    <ellipse cx="0" cy="-124" rx="112" ry="40" fill="url(#porcelainGrad)"/>
    <ellipse cx="0" cy="-124" rx="84" ry="27" fill="${P.sand300}" opacity="0.8"/>
    <ellipse cx="0" cy="-128" rx="84" ry="27" fill="${P.porcelainMid}"/>
    <ellipse cx="0" cy="-128" rx="62" ry="19" fill="${P.pondBlueDeep}" opacity="0.45"/>
    <ellipse cx="0" cy="-132" rx="62" ry="19" fill="${P.pondBlueLight}"/>
    <ellipse cx="-24" cy="-136" rx="24" ry="6" fill="#FFFFFF" opacity="0.55"/>`);
}

/** A pedestal sink beside the toilet: a rounded basin on a soft column. */
function pedestalSink(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 4, 92, 18)}
    <path d="M -34 0 q -14 0 -10 -18 l 16 -104 h 56 l 16 104 q 4 18 -10 18 Z" fill="url(#porcelainSide)"/>
    <path d="M -34 0 q -14 0 -10 -18 l 16 -104 h 20 l -14 122 Z" fill="#FFFFFF" opacity="0.45"/>
    <path d="M 0 -206 v -34 q 0 -26 -26 -26 h -34" stroke="${P.sand300}" stroke-width="20" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 0 -206 v -34 q 0 -26 -26 -26 h -34" stroke="${P.sand200}" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="-76" y="-276" width="26" height="20" rx="9" fill="${P.sand400}"/>
    <ellipse cx="0" cy="-118" rx="92" ry="28" fill="${P.sand300}"/>
    <ellipse cx="0" cy="-126" rx="92" ry="28" fill="url(#porcelainGrad)"/>
    <ellipse cx="0" cy="-126" rx="66" ry="18" fill="${P.porcelainShade}"/>
    <ellipse cx="0" cy="-129" rx="64" ry="17" fill="${P.pondBlueLight}"/>
    <ellipse cx="-22" cy="-133" rx="24" ry="6" fill="#FFFFFF" opacity="0.6"/>`);
}

/** A towel folded over a wall rail. */
function towelOnRail(cx, railY, s = 1) {
  return g(`translate(${cx} ${railY}) scale(${s})`, `
    <rect x="-52" y="0" width="104" height="12" rx="6" fill="${P.sand300}"/>
    <path d="M -38 5 h 76 q 8 0 8 10 v 56 q 0 8 -9 8 q -10 -10 -18 0 q -10 10 -20 0 q -10 -10 -18 0 q -9 7 -15 0 v -64 q 0 -10 8 -10 Z" fill="url(#towelGrad)"/>
    <path d="M -38 5 h 26 v 74 q -10 5 -19 -2 q -13 2 -13 -9 v -53 q 0 -10 8 -10 Z" fill="#FFFFFF" opacity="0.32"/>
    <rect x="-42" y="34" width="84" height="11" rx="5.5" fill="#FFFFFF" opacity="0.8"/>`);
}

/** A potted fern. */
function pottedPlant(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 4, 52, 10)}
    ${g('translate(-14 -50) scale(0.46)', frond(150, -56))}
    ${g('translate(16 -52) scale(0.5)', frond(158, 52))}
    ${g('translate(0 -56) scale(0.58)', frond(152, -4))}
    <path d="M -36 -44 h 72 l -9 44 q -2 6 -10 6 h -34 q -8 0 -10 -6 Z" fill="url(#peachBall)"/>
    <path d="M -36 -44 h 22 l -5 50 h -7 q -8 0 -10 -6 Z" fill="#FFFFFF" opacity="0.26"/>
    <rect x="-42" y="-54" width="84" height="15" rx="7.5" fill="${P.peach}"/>
    <rect x="-42" y="-54" width="30" height="15" rx="7.5" fill="#FFFFFF" opacity="0.3"/>`);
}

/** The child-height potty. Shared by the Sit and Pants-down cards and by the
 *  door plaque, so the object a child is asked to recognise is always the
 *  same object. Anchored at the floor, centred on x. */
function pottyChair(cx, baseY, s = 1, { shadow = true } = {}) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${shadow ? contactShadow(0, 4, 128, 22) : ''}
    <path d="M -86 -70 q -8 -60 86 -60 q 94 0 86 60 q -86 -20 -172 0 Z" fill="${P.hopGreenDeep}"/>
    <path d="M -72 -82 q -6 -38 72 -38 q 78 0 72 38 q -72 -14 -144 0 Z" fill="url(#greenBall)"/>
    <path d="M -84 -64 C -88 -6 -70 20 -58 26 Q 0 44 58 26 C 70 20 88 -6 84 -64 Z" fill="url(#greenBall)"/>
    <path d="M -84 -64 C -88 -6 -70 20 -58 26 Q -36 34 -20 36 Q -54 12 -54 -64 Z" fill="#FFFFFF" opacity="0.2"/>
    <ellipse cx="0" cy="-58" rx="96" ry="28" fill="${P.hopGreenDeep}"/>
    <ellipse cx="0" cy="-64" rx="96" ry="28" fill="url(#padGreenLight)"/>
    <ellipse cx="0" cy="-64" rx="52" ry="14" fill="${P.hopGreenInk}" opacity="0.5"/>
    <ellipse cx="0" cy="-67" rx="52" ry="14" fill="${P.pondBlueSoft}"/>
    <ellipse cx="-26" cy="-72" rx="23" ry="6" fill="#FFFFFF" opacity="0.5"/>`);
}

/** An interior door set into the wall, with an arch top, a plaque showing the
 *  potty and a warm light spilling under it. Anchored at the threshold. */
function bathroomDoor(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    <path d="M -124 0 v -282 q 0 -104 124 -104 q 124 0 124 104 V 0 Z" fill="${P.sand300}"/>
    <path d="M -110 0 v -278 q 0 -92 110 -92 q 110 0 110 92 V 0 Z" fill="${P.sand100}"/>
    <path d="M -96 0 v -272 q 0 -80 96 -80 q 96 0 96 80 V 0 Z" fill="url(#woodGrad)"/>
    <path d="M -80 -12 v -256 q 0 -66 80 -66 q 80 0 80 66 v 256 Z" fill="${P.woodLight}" opacity="0.4"/>
    <path d="M -58 -34 v -228 q 0 -46 58 -46 q 58 0 58 46 v 228 Z" fill="none" stroke="${P.woodDeep}" stroke-width="5" opacity="0.35"/>
    <circle cx="66" cy="-150" r="13" fill="${P.sunshineBright}"/>
    <circle cx="62" cy="-154" r="5" fill="#FFF6DC" opacity="0.85"/>
    <rect x="-124" y="-8" width="248" height="16" rx="8" fill="${P.sand300}"/>
    <g transform="translate(0 -238)">
      <rect x="-52" y="-42" width="104" height="84" rx="22" fill="${P.cloud}"/>
      <rect x="-52" y="-42" width="104" height="84" rx="22" fill="none" stroke="${P.sand200}" stroke-width="4"/>
      ${pottyChair(0, 30, 0.34, { shadow: false })}
    </g>`);
}

/** A soft toy box. */
function toyBox(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 6, 108, 20)}
    <path d="M -92 -108 h 184 q 12 0 12 12 v 84 q 0 12 -12 12 h -184 q -12 0 -12 -12 v -84 q 0 -12 12 -12 Z" fill="url(#woodGradV)"/>
    <path d="M -92 -108 h 60 v 108 h -60 q -12 0 -12 -12 v -84 q 0 -12 12 -12 Z" fill="#FFFFFF" opacity="0.2"/>
    <rect x="-108" y="-124" width="216" height="24" rx="12" fill="${P.wood}"/>
    <rect x="-108" y="-128" width="216" height="24" rx="12" fill="url(#woodGrad)"/>
    <circle cx="-46" cy="-150" r="26" fill="url(#peachBall)"/>
    <circle cx="6" cy="-158" r="32" fill="url(#blueBall)"/>
    <path d="M -22 -160 q 28 -14 56 4" stroke="#FFFFFF" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.55"/>
    <rect x="46" y="-172" width="46" height="46" rx="10" fill="url(#yellowBall)" transform="rotate(-12 69 -149)"/>
    <path d="M 56 -150 h 26 M 69 -163 v 26" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" opacity="0.6" transform="rotate(-12 69 -149)"/>`);
}

/** A window with a warm sky in it. */
function window(cx, cy, w, h) {
  const x = cx - w / 2, y = cy - h / 2;
  return `
    <rect x="${x - 10}" y="${y - 10}" width="${w + 20}" height="${h + 20}" rx="26" fill="${P.sand200}"/>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18" fill="url(#skyWarm)"/>
    <circle cx="${R(x + w * 0.72)}" cy="${R(y + h * 0.28)}" r="${R(h * 0.14)}" fill="url(#sunDisc)"/>
    ${cloud(x + w * 0.34, y + h * 0.36, w * 0.34, { opacity: 0.9 })}
    <path d="M ${x} ${R(y + h * 0.72)} q ${R(w * 0.3)} ${R(-h * 0.16)} ${R(w * 0.58)} ${R(h * 0.04)} q ${R(w * 0.24)} ${R(h * 0.08)} ${R(w * 0.42)} ${R(-h * 0.04)} V ${y + h} H ${x} Z" fill="url(#hillFar)"/>
    <rect x="${R(cx - 6)}" y="${y}" width="12" height="${h}" fill="${P.sand200}"/>
    <rect x="${x}" y="${R(cy - 6)}" width="${w}" height="12" fill="${P.sand200}"/>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="18" fill="none" stroke="${P.sand300}" stroke-width="7"/>`;
}

const scenes = {
  /** Fly Snack.
   *  STAGE: the hero lily pad, centred on x 320 with its surface at y 404 —
   *  Hop sits there, about 210 tall. Everything above y 280 is empty sky so a
   *  fly can cross it, and his tongue can reach up and right without hitting a
   *  reed. Dusk gold rather than midday: the game is a quiet, aiming game. */
  'games-flySnack': () => `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="url(#skyDusk)"/>
    <circle cx="502" cy="176" r="118" fill="url(#sunGlow)" opacity="0.7"/>
    <circle cx="502" cy="176" r="40" fill="url(#sunDisc)"/>
    ${cloud(150, 74, 128, { opacity: 0.55 })}
    ${cloud(392, 52, 92, { opacity: 0.4 })}
    ${cloud(596, 96, 76, { opacity: 0.35 })}
    <path d="M -20 300 Q 90 250 232 274 Q 360 296 480 268 Q 570 248 660 272 L 660 340 L -20 340 Z" fill="url(#hillFar)"/>
    <path d="M -20 318 Q 140 288 300 310 Q 470 334 660 300 L 660 360 L -20 360 Z" fill="url(#hillMid)"/>
    <rect x="0" y="330" width="${SW}" height="${SH - 330}" fill="url(#waterDusk)"/>
    <path d="M -20 326 Q 120 316 260 330 Q 400 344 660 326 L 660 348 L -20 348 Z" fill="url(#shoreSand)" opacity="0.85"/>
    <path d="M 452 336 L 552 336 L 604 480 L 400 480 Z" fill="url(#goldPath)" opacity="0.55"/>
    <g stroke="#FFFFFF" stroke-linecap="round" fill="none" opacity="0.4">
      <path d="M 60 372 h 54" stroke-width="5"/>
      <path d="M 150 396 h 42" stroke-width="5"/>
      <path d="M 512 386 h 60" stroke-width="5"/>
      <path d="M 430 420 h 44" stroke-width="5"/>
      <path d="M 96 440 h 66" stroke-width="6"/>
      <path d="M 556 448 h 48" stroke-width="6"/>
    </g>
    ${lilyPad(94, 372, 62, { notch: 250 })}
    ${lilyPad(556, 356, 52, { notch: 300 })}
    ${lilyPad(228, 344, 40, { notch: 70 })}
    ${ripple(320, 432, 196, 0.32)}
    ${lilyPad(320, 412, 162, { squash: 0.34, spread: 14 })}
    <g>
      ${flower(214, 384, 22, { fill: 'url(#petalWhite)', core: P.sunshine, petals: 7, stem: false })}
      <ellipse cx="214" cy="392" rx="30" ry="8" fill="${P.hopGreenDeep}" opacity="0.25"/>
    </g>
    <g>
      ${cattail(34, 448, 178, { tilt: -5 })}
      ${cattail(74, 462, 130, { tilt: 4, s: 0.82 })}
      ${cattail(12, 470, 96, { tilt: -8, s: 0.7, head: false })}
      ${cattail(612, 452, 190, { tilt: 6 })}
      ${cattail(572, 468, 136, { tilt: -4, s: 0.84 })}
      ${cattail(632, 476, 100, { tilt: 9, s: 0.72, head: false })}
    </g>
    <g fill="url(#bladeGreen)" opacity="0.85">
      <path d="${blade(114, 470, 62, 16, 11)}"/>
      <path d="${blade(538, 474, 54, -14, 10)}"/>
    </g>`,

  /** Mud Off.
   *  STAGE: the grass in front of the fence, centred on x 356 with the ground
   *  at y 430 — Hop crouches there to scrub. The tap, its basin and its water
   *  are all left of x 230, so nothing overlaps his hands. */
  'games-mudOff': () => `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="url(#skyWarm)"/>
    <circle cx="546" cy="66" r="86" fill="url(#sunGlow)" opacity="0.7"/>
    <circle cx="546" cy="66" r="34" fill="url(#sunDisc)"/>
    ${cloud(180, 62, 118, { opacity: 0.6 })}
    ${cloud(392, 40, 84, { opacity: 0.42 })}
    <path d="M -20 214 Q 140 168 320 200 Q 500 232 660 190 L 660 320 L -20 320 Z" fill="url(#hillFar)"/>
    <g fill="url(#hedgeGreen)">
      ${[[-10, 250, 78], [86, 236, 88], [200, 244, 82], [312, 232, 92], [432, 244, 84], [548, 236, 90], [648, 250, 76]]
        .map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}
      <rect x="-20" y="244" width="${SW + 40}" height="96" />
    </g>
    <g opacity="0.35" fill="#FFFFFF">
      ${[[54, 214, 20], [176, 206, 16], [288, 198, 18], [402, 208, 15], [520, 200, 17], [612, 216, 14]]
        .map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}"/>`).join('')}
    </g>
    <rect x="0" y="316" width="${SW}" height="${SH - 316}" fill="url(#ground)"/>
    <path d="M -20 380 Q 180 356 340 382 Q 500 408 660 384 L 660 500 L -20 500 Z" fill="url(#groundNear)" opacity="0.55"/>
    <g fill="${P.hopGreenInk}" opacity="0.16">
      ${[[268, 358, 30, 8, 7], [388, 350, 24, -8, 6], [466, 372, 32, 10, 7], [196, 372, 26, -8, 6],
         [520, 404, 34, 12, 8], [300, 412, 28, -10, 7], [420, 440, 32, 10, 8], [246, 452, 26, -8, 7],
         [592, 434, 30, -10, 7], [356, 470, 24, 8, 6]]
        .map(([x, y, h, c, w]) => `<path d="${blade(x, y, h, c, w)}"/>`).join('')}
    </g>
    <g opacity="0.5">
      <ellipse cx="470" cy="416" rx="52" ry="15" fill="${P.wood}" opacity="0.35"/>
      <ellipse cx="238" cy="446" rx="40" ry="12" fill="${P.wood}" opacity="0.3"/>
    </g>
    ${g('translate(0 0)', `
      <rect x="500" y="238" width="160" height="20" rx="10" fill="${P.wood}"/>
      ${[[512, 214], [560, 220], [608, 214]].map(([x, y]) =>
        `<path d="M ${x} ${y} h 40 q 8 0 8 8 v 120 q 0 8 -8 8 h -40 q -8 0 -8 -8 v -120 q 0 -8 8 -8 Z" fill="url(#woodGradV)"/>
         <path d="M ${x} ${y} h 14 v 136 h -14 q -8 0 -8 -8 v -120 q 0 -8 8 -8 Z" fill="#FFFFFF" opacity="0.22"/>`).join('')}
      <rect x="500" y="300" width="160" height="16" rx="8" fill="${P.woodDeep}" opacity="0.7"/>
    `)}
    ${towelOnRail(566, 190, 0.86)}
    ${gardenTap(126, 430, 0.9)}
    <g>
      <circle cx="252" cy="286" r="24" fill="url(#bubbleFill)"/>
      <circle cx="196" cy="238" r="15" fill="url(#bubbleFill)"/>
      <circle cx="308" cy="242" r="18" fill="url(#bubbleFill)"/>
      <circle cx="352" cy="300" r="12" fill="url(#bubbleFill)"/>
      <circle cx="150" cy="180" r="11" fill="url(#bubbleFill)"/>
    </g>
    ${pottedPlant(60, 470, 0.72)}
    ${flower(608, 424, 20, { fill: 'url(#peachBall)', core: P.peachSoft, petals: 6, stemH: 34 })}
    ${flower(38, 402, 17, { fill: 'url(#yellowBall)', core: P.sunshineSoft, stemH: 30 })}
    ${pebble(430, 462, 22, 9)}
    ${pebble(520, 470, 16, 7)}`,

  /** Body Signal.
   *  STAGE: the rug, centred on x 268 with the floor at y 420 — Hop plays there
   *  and hops right when the signal comes. The door is hard against the right
   *  edge with its threshold at y 430, so the run has somewhere to end. */
  'games-bodySignal': () => `
    ${room({ floorY: 366, wall: P.sunshineSoft, floor: P.sand100, skirting: P.sand200 })}
    <rect x="0" y="0" width="${SW}" height="366" fill="url(#wallWarm)" opacity="0.45"/>
    <g stroke="${P.peach}" stroke-width="7" opacity="0.16" stroke-linecap="round">
      <path d="M 44 40 v 320 M 148 40 v 320 M 252 40 v 320 M 356 40 v 320"/>
    </g>
    ${window(150, 150, 176, 140)}
    <g opacity="0.9">
      <rect x="286" y="96" width="118" height="16" rx="8" fill="${P.sand300}"/>
      <rect x="296" y="60" width="24" height="38" rx="6" fill="url(#peachBall)"/>
      <rect x="324" y="52" width="20" height="46" rx="6" fill="url(#blueBall)"/>
      <rect x="348" y="64" width="26" height="34" rx="6" fill="url(#yellowBall)"/>
      <rect x="376" y="56" width="18" height="42" rx="6" fill="url(#lavenderBall)"/>
    </g>
    ${bathroomDoor(548, 430, 0.66)}
    <g opacity="0.5">
      <path d="M 452 430 h 78" stroke="${P.sunshine}" stroke-width="10" stroke-linecap="round" fill="none" opacity="0.55"/>
    </g>
    <ellipse cx="268" cy="424" rx="196" ry="52" fill="${P.peach}" opacity="0.35"/>
    <ellipse cx="268" cy="418" rx="196" ry="52" fill="url(#rugGrad)"/>
    <ellipse cx="268" cy="418" rx="150" ry="38" fill="none" stroke="#FFFFFF" stroke-width="8" opacity="0.65"/>
    <ellipse cx="268" cy="418" rx="98" ry="24" fill="none" stroke="#FFFFFF" stroke-width="6" opacity="0.45"/>
    ${toyBox(96, 396, 0.62)}
    <g>
      ${contactShadow(400, 408, 34, 8)}
      <circle cx="400" cy="384" r="26" fill="url(#yellowBall)"/>
      <path d="M 378 374 q 22 -12 44 0" stroke="#FFFFFF" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.6"/>
      <path d="M 378 394 q 22 12 44 0" stroke="${P.peach}" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.6"/>
    </g>
    <g>
      ${contactShadow(150, 450, 30, 7)}
      <rect x="124" y="418" width="52" height="34" rx="10" fill="url(#lavenderBall)"/>
      <rect x="132" y="410" width="36" height="12" rx="6" fill="${P.lavenderSoft}"/>
    </g>
    ${pottedPlant(468, 366, 0.5)}`,

  /** Flush Wave.
   *  STAGE: the floor between the sink and the toilet, centred on x 268 with the
   *  floor at y 424 — Hop stands there and waves at the flusher. The toilet is
   *  right of centre so the button sits at his eye line; the sink is pushed to
   *  the left wall. */
  'games-flushWave': () => `
    ${room({ floorY: 372, wall: P.pondBlueSoft, floor: P.sand100 })}
    <rect x="0" y="286" width="${SW}" height="90" fill="#FFFFFF" opacity="0.4"/>
    <rect x="0" y="278" width="${SW}" height="14" rx="7" fill="${P.sand300}"/>
    <g stroke="${P.pondBlueDeep}" stroke-width="3" opacity="0.16" stroke-linecap="round">
      <path d="M 0 332 h ${SW}"/>
      <path d="M 72 292 v 40 M 216 292 v 40 M 360 292 v 40 M 504 292 v 40"/>
      <path d="M 144 334 v 38 M 288 334 v 38 M 432 334 v 38 M 576 334 v 38"/>
    </g>
    <circle cx="322" cy="118" r="66" fill="#FFFFFF" opacity="0.4"/>
    ${kindToilet(452, 428, 0.78)}
    ${pedestalSink(120, 424, 0.6)}
    ${towelOnRail(238, 168, 0.72)}
    <g opacity="0.9">
      <circle cx="332" cy="212" r="18" fill="url(#bubbleFill)"/>
      <circle cx="286" cy="252" r="12" fill="url(#bubbleFill)"/>
      <circle cx="372" cy="256" r="9" fill="url(#bubbleFill)"/>
    </g>
    ${pottedPlant(596, 372, 0.6)}
    ${g('translate(452 246)', `
      <path d="M 0 0 m -46 0 a 46 20 0 1 1 66 17" fill="none" stroke="${P.pondBlueDeep}" stroke-width="11" stroke-linecap="round" opacity="0.32"/>
      <path d="M 0 10 m -28 0 a 28 12 0 1 1 42 11" fill="none" stroke="${P.pondBlue}" stroke-width="9" stroke-linecap="round" opacity="0.3"/>
    `)}`,

  /** Potty Order.
   *  STAGE: none — no character stands in this one. The four slots are the
   *  subject: they sit on the path across the middle at y 148..288, and
   *  everything below y 310 is deliberately empty lawn so the app can deal the
   *  cards there. */
  'games-pottyOrder': () => `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="url(#skyWarm)"/>
    <circle cx="76" cy="58" r="72" fill="url(#sunGlow)" opacity="0.65"/>
    <circle cx="76" cy="58" r="30" fill="url(#sunDisc)"/>
    ${cloud(268, 46, 100, { opacity: 0.55 })}
    ${cloud(506, 66, 78, { opacity: 0.4 })}
    <path d="M -20 152 Q 150 108 340 140 Q 510 168 660 132 L 660 360 L -20 360 Z" fill="url(#hillFar)"/>
    <path d="M -20 196 Q 190 158 400 192 Q 540 214 660 190 L 660 400 L -20 400 Z" fill="url(#hillMid)"/>
    <path d="M -20 322 Q 200 296 420 324 Q 550 340 660 320 L 660 500 L -20 500 Z" fill="url(#ground)"/>
    <path d="M -20 300 Q 160 268 320 292 Q 480 316 660 286 L 660 336 Q 480 366 320 342 Q 160 318 -20 350 Z" fill="url(#shoreSand)"/>
    <path d="M -20 306 Q 160 274 320 298 Q 480 322 660 292" fill="none" stroke="#FFFFFF" stroke-width="5" opacity="0.55"/>
    ${[0, 1, 2, 3].map((i) => {
      const x = 34 + i * 146, y = 148, w = 118, h = 140;
      const cx = x + w / 2;
      return `<g id="slot${i + 1}">
        <ellipse cx="${cx}" cy="${y + h + 14}" rx="${R(w * 0.46)}" ry="12" fill="url(#softShadow)"/>
        <rect x="${x + 4}" y="${y + 6}" width="${w}" height="${h}" rx="26" fill="${P.midnight}" opacity="0.07"/>
        <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="26" fill="url(#slotWell)"/>
        <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="26" fill="none" stroke="${P.hopGreenDeep}" stroke-width="5" stroke-dasharray="16 13" stroke-linecap="round" opacity="0.55"/>
        <circle cx="${cx}" cy="${R(y + h / 2)}" r="19" fill="${P.hopGreenSoft}" opacity="0.9"/>
        <text x="${cx}" y="${R(y + h / 2 + 10)}" text-anchor="middle" font-family="-apple-system, system-ui, sans-serif" font-size="26" font-weight="700" fill="${P.hopGreenDeep}" opacity="0.55">${i + 1}</text>
      </g>`;
    }).join('')}
    <g fill="${P.hopGreenDeep}" opacity="0.4">
      ${[0, 1, 2].map((i) => {
        const x = 152 + i * 146, y = 218;
        return `<path d="M ${x} ${y - 11} L ${x + 15} ${y} L ${x} ${y + 11} Z"/>`;
      }).join('')}
    </g>
    <g fill="${P.hopGreenInk}" opacity="0.18">
      ${[[26, 356, 54, 14, 9], [72, 366, 38, -10, 7], [598, 370, 58, -16, 10], [560, 380, 40, 12, 8],
         [214, 392, 44, 12, 8], [400, 400, 38, -10, 7], [312, 428, 46, 14, 9], [500, 438, 36, -10, 7],
         [122, 446, 42, 12, 8], [612, 452, 34, 10, 7]]
        .map(([x, y, h, c, w]) => `<path d="${blade(x, y, h, c, w)}"/>`).join('')}
    </g>
    ${flower(58, 424, 18, { fill: 'url(#yellowBall)', core: P.sunshineSoft, stemH: 30 })}
    ${flower(576, 416, 17, { fill: 'url(#peachBall)', core: P.peachSoft, petals: 6, stemH: 28 })}
    ${pebble(258, 356, 18, 7)}
    ${pebble(452, 348, 15, 6)}`,
};

// ===========================================================================
// 2. SPRITES  (120 x 120, transparent)
// ===========================================================================

/** One fly. Round, big eyed, translucent wings — a snack a child wants to
 *  catch, not a housefly. All three colours are the same drawing so the set
 *  reads as one species; only the coat changes. */
function fly(bodyGrad, deep, { wingTint = '#FFFFFF' } = {}) {
  return `
    <g opacity="0.85">
      <ellipse cx="26" cy="38" rx="26" ry="13" transform="rotate(-32 26 38)" fill="url(#wingGlass)" stroke="${wingTint}" stroke-width="2.5" opacity="0.9"/>
      <ellipse cx="94" cy="38" rx="26" ry="13" transform="rotate(32 94 38)" fill="url(#wingGlass)" stroke="${wingTint}" stroke-width="2.5" opacity="0.9"/>
    </g>
    <path d="M 52 40 q -6 -14 -14 -20" stroke="${deep}" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <path d="M 68 40 q 6 -14 14 -20" stroke="${deep}" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <circle cx="36" cy="18" r="5" fill="${deep}"/>
    <circle cx="84" cy="18" r="5" fill="${deep}"/>
    <ellipse cx="60" cy="98" rx="22" ry="4.5" fill="${deep}" opacity="0.16"/>
    <g stroke="${deep}" stroke-width="4" stroke-linecap="round" opacity="0.85">
      <path d="M 42 88 q -6 8 -12 10"/>
      <path d="M 60 92 v 10"/>
      <path d="M 78 88 q 6 8 12 10"/>
    </g>
    <ellipse cx="60" cy="66" rx="38" ry="34" fill="${bodyGrad}"/>
    <ellipse cx="60" cy="80" rx="26" ry="17" fill="#FFFFFF" opacity="0.3"/>
    <ellipse cx="46" cy="48" rx="15" ry="10" transform="rotate(-18 46 48)" fill="#FFFFFF" opacity="0.32"/>
    <circle cx="45" cy="60" r="16" fill="#FFFFFF"/>
    <circle cx="75" cy="60" r="16" fill="#FFFFFF"/>
    <circle cx="45" cy="60" r="16" fill="none" stroke="${deep}" stroke-width="2" opacity="0.3"/>
    <circle cx="75" cy="60" r="16" fill="none" stroke="${deep}" stroke-width="2" opacity="0.3"/>
    <circle cx="47" cy="62" r="7.5" fill="${P.midnight}"/>
    <circle cx="77" cy="62" r="7.5" fill="${P.midnight}"/>
    <circle cx="44.5" cy="59" r="2.8" fill="#FFFFFF"/>
    <circle cx="74.5" cy="59" r="2.8" fill="#FFFFFF"/>
    <path d="M 52 80 q 8 7 16 0" stroke="${deep}" stroke-width="3.6" fill="none" stroke-linecap="round"/>`;
}

/** A soft splotch: one blob, a wet highlight and two flecks. Never a spatter
 *  with sharp points — mud in this app is a mess to wash off, not something
 *  unpleasant. */
function splotch(d, grad, deep, flecks) {
  return `
    <path d="${d}" fill="${deep}" opacity="0.22" transform="translate(2 4)"/>
    <path d="${d}" fill="${grad}"/>
    <ellipse cx="46" cy="42" rx="15" ry="9" transform="rotate(-22 46 42)" fill="#FFFFFF" opacity="0.3"/>
    <ellipse cx="72" cy="72" rx="9" ry="6" transform="rotate(14 72 72)" fill="#FFFFFF" opacity="0.16"/>
    ${flecks.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${grad}"/>`).join('')}`;
}

/** A four-point star. */
const star = (cx, cy, r, fill) =>
  `<path d="M ${cx} ${R(cy - r)} q ${R(r * 0.28)} ${R(r * 0.72)} ${r} ${r} q ${R(-r * 0.72)} ${R(r * 0.28)} ${-r} ${r} q ${R(-r * 0.28)} ${R(-r * 0.72)} ${-r} ${-r} q ${R(r * 0.72)} ${R(-r * 0.28)} ${r} ${-r} Z" fill="${fill}"/>`;

/** A picture card: the same rounded card and inner panel every time, so the
 *  four steps of the sequence differ only in the picture on them. */
const card = (inner) => `
  <rect x="9" y="11" width="102" height="102" rx="24" fill="${P.midnight}" opacity="0.1"/>
  <rect x="8" y="6" width="104" height="104" rx="24" fill="url(#cardFace)"/>
  <rect x="8" y="6" width="104" height="104" rx="24" fill="none" stroke="${P.sand200}" stroke-width="3"/>
  <rect x="16" y="14" width="88" height="88" rx="18" fill="url(#cardPanel)"/>
  <g clip-path="url(#cardClip)">${inner}</g>`;
DEFS.cardClip = '<clipPath id="cardClip"><rect x="16" y="14" width="88" height="88" rx="18"/></clipPath>';

const sprites = {
  'fly-blue': () => fly('url(#flyBlue)', P.pondBlueInk),
  'fly-green': () => fly('url(#flyGreen)', P.hopGreenInk),
  'fly-gold': () => fly('url(#flyGold)', P.sunshineInk),

  /** Tummy Meter: a leaf standing on its stem, cut into six bands from the
   *  bottom up. Empty here on purpose — the app fills `seg1`..`seg6`, so this
   *  file must never ship a filled segment or the first frame will be wrong. */
  tummyMeter: () => {
    const top = 14, bottom = 110, n = 6;
    const band = (bottom - top) / n;
    const segs = Array.from({ length: n }, (_, i) => {
      const y = bottom - (i + 1) * band + 1.6;
      return `<rect id="seg${i + 1}" x="18" y="${R(y)}" width="84" height="${R(band - 3.2)}" rx="5" fill="${P.hopGreenSoft}" opacity="0.75"/>`;
    }).join('');
    return `
      <path d="M 60 116 q 0 -6 0 -12" stroke="${P.hopGreenDeep}" stroke-width="6" stroke-linecap="round" fill="none"/>
      <path d="M 60 8 C 98 36 98 86 60 114 C 22 86 22 36 60 8 Z" fill="${P.cloud}"/>
      <g clip-path="url(#leafClip)">${segs}</g>
      <g clip-path="url(#leafClip)" stroke="${P.hopGreenLight}" stroke-width="2.4" opacity="0.85">
        ${Array.from({ length: n - 1 }, (_, i) =>
          `<path d="M 18 ${R(bottom - (i + 1) * band)} h 84" fill="none"/>`).join('')}
      </g>
      <path d="M 60 8 C 98 36 98 86 60 114 C 22 86 22 36 60 8 Z" fill="none" stroke="${P.hopGreenDeep}" stroke-width="5" stroke-linejoin="round"/>
      <path d="M 60 12 V 110" stroke="${P.hopGreenDeep}" stroke-width="3" opacity="0.35" stroke-linecap="round"/>`;
  },

  'mud-brown': () => splotch(
    'M 20 62 C 12 42 26 24 48 22 C 64 20 74 10 90 18 C 106 26 108 48 100 62 C 92 76 98 92 80 98 C 60 105 40 100 30 90 C 21 81 24 72 20 62 Z',
    'url(#mudBrown)', '#7E4F2B', [[16, 88, 6.5], [100, 84, 5], [92, 26, 4]]),

  'mud-green': () => splotch(
    'M 22 54 C 16 34 34 18 54 22 C 72 26 84 14 96 26 C 108 38 104 58 96 70 C 88 82 90 96 72 100 C 52 104 32 96 24 82 C 18 72 26 66 22 54 Z',
    'url(#mudGreen)', '#5A7F3A', [[14, 78, 6], [104, 60, 5], [58, 108, 4.5]]),

  'mud-paint': () => splotch(
    'M 18 58 C 14 36 32 20 52 24 C 70 28 78 16 94 22 C 110 28 112 50 102 64 C 94 76 100 90 84 98 C 66 106 42 102 30 92 C 20 84 20 70 18 58 Z',
    'url(#mudPaint)', P.lavenderInk, [[104, 82, 6], [16, 34, 5], [66, 108, 4.5]]),

  sparkle: () => `
    <circle cx="58" cy="54" r="42" fill="url(#glowWarm)" opacity="0.7"/>
    ${star(58, 54, 38, P.sunshineBright)}
    ${star(58, 54, 24, P.sunshine)}
    ${star(58, 54, 11, '#FFFDF2')}
    ${star(100, 92, 15, P.sunshine)}
    ${star(22, 94, 11, P.sunshineBright)}
    ${star(102, 24, 9, P.sunshineSoft)}`,

  ball: () => `
    ${iconShadow(60, 106, 34)}
    <circle cx="60" cy="62" r="44" fill="url(#peachBall)"/>
    <path d="M 22 84 q 38 -22 76 0 q -6 12 -16 20 q -22 8 -44 0 q -10 -8 -16 -20 Z" fill="${P.cloud}" opacity="0.9"/>
    <path d="M 16 62 q 44 -26 88 0" stroke="${P.cloud}" stroke-width="9" fill="none" stroke-linecap="round" opacity="0.85"/>
    <circle cx="60" cy="62" r="44" fill="none" stroke="${P.peachDeep}" stroke-width="3" opacity="0.28"/>
    <ellipse cx="44" cy="40" rx="16" ry="11" transform="rotate(-24 44 40)" fill="#FFFFFF" opacity="0.5"/>`,

  thoughtBubble: () => `
    <circle cx="30" cy="102" r="7" fill="#FFFFFF" opacity="0.95"/>
    <circle cx="30" cy="102" r="7" fill="none" stroke="${P.pondBlueLight}" stroke-width="2.5"/>
    <circle cx="44" cy="88" r="11" fill="#FFFFFF" opacity="0.95"/>
    <circle cx="44" cy="88" r="11" fill="none" stroke="${P.pondBlueLight}" stroke-width="2.5"/>
    ${cloud(62, 44, 104, { fill: '#FFFFFF' })}
    <g opacity="0.9">${cloud(62, 44, 104, { fill: 'none' })}</g>
    <path d="M 14 58 a 21 21 0 0 1 6 -40 a 27 27 0 0 1 44 -15 a 23 23 0 0 1 42 17 a 19 19 0 0 1 -4 38 Z"
      fill="none" stroke="${P.pondBlueLight}" stroke-width="3" stroke-linejoin="round"/>
    <path d="${drop(60, 38, 40, 15)}" fill="url(#blueBall)"/>
    <path d="M 52 44 q 1 -10 6 -16" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.6"/>`,

  flusher: () => `
    ${iconShadow(60, 108, 36)}
    <rect x="14" y="18" width="92" height="80" rx="24" fill="${P.sand300}"/>
    <rect x="14" y="14" width="92" height="80" rx="24" fill="url(#porcelainGrad)"/>
    <rect x="14" y="14" width="34" height="80" rx="17" fill="#FFFFFF" opacity="0.5"/>
    <circle cx="60" cy="54" r="30" fill="${P.pondBlueDeep}" opacity="0.3"/>
    <circle cx="60" cy="50" r="30" fill="url(#blueBall)"/>
    <circle cx="60" cy="50" r="19" fill="${P.pondBlueSoft}" opacity="0.85"/>
    <ellipse cx="51" cy="40" rx="11" ry="7" transform="rotate(-24 51 40)" fill="#FFFFFF" opacity="0.7"/>
    <path d="M 60 50 m -11 0 a 11 5 0 1 1 16 4" fill="none" stroke="${P.pondBlueDeep}" stroke-width="4" stroke-linecap="round" opacity="0.55"/>`,

  swirl: () => `
    <ellipse cx="60" cy="70" rx="48" ry="26" fill="${P.pondBlueSoft}" opacity="0.6"/>
    <path d="M 60 66 m -42 0 a 42 20 0 1 1 60 17" fill="none" stroke="${P.pondBlueDeep}" stroke-width="13" stroke-linecap="round"/>
    <path d="M 60 74 m -26 0 a 26 12 0 1 1 38 10" fill="none" stroke="${P.pondBlue}" stroke-width="12" stroke-linecap="round"/>
    <path d="M 60 80 m -12 0 a 12 6 0 1 1 18 5" fill="none" stroke="${P.pondBlueLight}" stroke-width="9" stroke-linecap="round"/>
    <circle cx="24" cy="30" r="9" fill="${P.pondBlueLight}" opacity="0.85"/>
    <circle cx="98" cy="38" r="7" fill="${P.pondBlue}" opacity="0.7"/>
    <circle cx="64" cy="18" r="5.5" fill="${P.pondBlueLight}" opacity="0.8"/>`,

  /** Step 1: trousers puddled at the ankles beside the potty. No body, no
   *  anatomy — the trousers on the floor are the whole idea. */
  'card-pantsDown': () => card(`
    ${pottyChair(84, 92, 0.24)}
    <ellipse cx="44" cy="94" rx="24" ry="6" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 24 52 h 40 q 6 0 6 7 l -3 22 q -1 6 -7 6 h -8 q -6 0 -7 -6 l -1 -10 l -1 10 q -1 6 -7 6 h -8 q -6 0 -7 -6 l -3 -22 q 0 -7 6 -7 Z" fill="url(#denimGrad)"/>
    <path d="M 24 52 h 14 l -1 35 h -6 q -6 0 -7 -6 l -3 -22 q 0 -7 3 -7 Z" fill="#FFFFFF" opacity="0.25"/>
    <rect x="22" y="46" width="46" height="10" rx="5" fill="${P.pondBlueDeep}"/>
    <rect x="22" y="44" width="46" height="10" rx="5" fill="${P.pondBlue}"/>
    <g stroke="#FFFFFF" stroke-width="2.4" opacity="0.45" stroke-linecap="round">
      <path d="M 27 64 h 15 M 27 72 h 13 M 51 64 h 15 M 53 72 h 13"/>
    </g>
    <path d="M 74 40 q 10 8 8 18" stroke="${P.hopGreenDeep}" stroke-width="3.5" fill="none" stroke-linecap="round" opacity="0.5"/>
    <path d="M 78 60 l 5 -6 l 5 6 Z" fill="${P.hopGreenDeep}" opacity="0.5"/>`),

  /** Step 2: the potty itself, front on, with an arrow curving down into it. */
  'card-sit': () => card(`
    ${pottyChair(60, 94, 0.36)}
    <path d="M 60 22 q 22 4 22 22" stroke="${P.hopGreenDeep}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.6"/>
    <path d="M 74 46 l 8 10 l 8 -10 Z" fill="${P.hopGreenDeep}" opacity="0.6"/>
    ${star(34, 30, 9, P.sunshine)}
    ${star(48, 20, 6, P.sunshineBright)}`),

  /** Step 3: the hand and the folded square, the same drawing the quiz uses. */
  'card-wipe': () => card(`
    <g stroke="${P.hopGreen}" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.5">
      <path d="M 26 56 q -6 8 0 16"/>
      <path d="M 18 50 q -8 14 0 28"/>
    </g>
    ${g('translate(66 96) scale(0.62)', wipeHand())}`),

  /** Step 4: the same pair of hands as the quiz, under a tap. */
  'card-wash': () => card(`
    <path d="M 78 26 h -22 q -12 0 -12 12 v 8" stroke="${P.sand300}" stroke-width="12" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 78 26 h -22 q -12 0 -12 12 v 8" stroke="${P.sand200}" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="76" y="19" width="16" height="14" rx="6" fill="${P.sand400}"/>
    <path d="M 44 48 q -2 16 -1 26" stroke="url(#waterStream)" stroke-width="14" stroke-linecap="round" fill="none"/>
    ${g('translate(0 6) scale(0.94) translate(4 0)', handPair())}
    <circle cx="30" cy="44" r="9" fill="url(#bubbleFill)"/>
    <circle cx="88" cy="56" r="7" fill="url(#bubbleFill)"/>
    <circle cx="24" cy="66" r="5" fill="url(#bubbleFill)"/>
    <circle cx="96" cy="36" r="5" fill="url(#bubbleFill)"/>`),
};

// ===========================================================================
// Emit
// ===========================================================================
const ROOT = path.resolve(__dirname, '..');
const out = [];
function write(rel, content) {
  const file = path.join(ROOT, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content.trim() + '\n');
  out.push(rel);
}

for (const [name, build] of Object.entries(scenes)) {
  write(`Art/scenes/${name}.svg`, svg({
    viewBox: `0 0 ${SW} ${SH}`, width: SW, height: SH, body: `<g id="${name}">${build()}</g>`,
  }));
}

for (const [name, build] of Object.entries(sprites)) {
  write(`Art/icons/games-${name}.svg`, svg({
    viewBox: '0 0 120 120', width: 120, height: 120, body: `<g id="games-${name}">${build()}</g>`,
  }));
}

console.log(out.map((f) => 'wrote ' + f).join('\n'));
console.log(`${out.length} files`);
