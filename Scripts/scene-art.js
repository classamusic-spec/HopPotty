#!/usr/bin/env node
/**
 * Generates every non-character illustration in the app from one shared
 * vocabulary of shapes, gradients and palette constants.
 *
 * Same approach as `hop-art.js`: nothing here is a hand-drawn one-off. A pond
 * decoration, a routine step and a quiz icon all draw from the same primitives
 * (`pad`, `blade`, `flower`, `pebble`, `dome`…), so a change to the house style
 * lands everywhere at once and the whole set stays visibly related.
 *
 * Output
 * ------
 *   Art/pond/pond-base.svg          the reward scene, all layers, ids per PondLayer
 *   Art/pond/pond-base-<layer>.svg  each base layer alone, so the app can draw
 *                                   the character between `decoration` and
 *                                   `foreground` exactly as PondLayer orders it
 *   Art/pond/item-<PondItemID>.svg  one file per decoration, transparent, all on
 *                                   the same 200x200 unit box
 *   Art/pond/pond-preview.svg       every item composited at its PondCatalog
 *                                   anchor — a proof the set works as a scene
 *   Art/scenes/routine-*.svg        the five routine step illustrations
 *   Art/scenes/games-*.svg          one backdrop per mini-game
 *   Art/scenes/shield-hero.svg      Potty Pause hero art
 *   Art/icons/quiz-*.svg            quiz answer objects
 *   Art/icons/event-*.svg           tried / pee / poop / accident, plus -mono
 *   Art/appicon/appicon-1024.svg    the app icon
 *
 * Unit contract for pond items
 * ----------------------------
 * Every decoration is drawn inside `0 0 200 200` and is *centre anchored*: the
 * point a `PondAnchor` names is the centre of that box, so the app places an
 * item with a single translate and needs no per-item offset table. At
 * `scale: 1` the box occupies 320x320 of the 1200x900 scene (see PLACEMENT).
 */
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Palette. Brand hues and ramp steps mirror HopPalette.swift exactly.
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

  // Illustration-only extensions. Not brand tokens — these exist so wood, skin
  // and porcelain can sit next to the brand hues without going cold or muddy.
  wood: '#C98A5B', woodDeep: '#A76F46', woodLight: '#E0A472',
  handLight: '#FFDCC9', handMid: '#F5C4A9', handDeep: '#DCA084',
  porcelain: '#FFFFFF', porcelainMid: '#F4F1EC', porcelainShade: '#E4DFD8',
};

// Hop's own body ramp, copied from hop-art.js so friends and the app icon are
// cut from exactly the same cloth as the character.
const HOP = {
  bodyLight: '#9FE3B9', bodyMid: '#63C88A', bodyDeep: '#45A971', bodyShadow: '#37905F',
  belly: '#F0FBF4', bellyEdge: '#DCF3E5', ink: '#25603F', mouth: '#2F7D52',
  cheek: '#FF9F8F', eyeWhite: '#FFFFFF', pupil: '#243047',
  domeLight: '#A9E8C2', domeDeep: '#4FB47B',
  bagBody: '#C98A5B', bagStrap: '#A76F46', bagFlap: '#E0A472',
};
// Two siblings for the frog friends. Same anatomy as Hop — that is the point,
// they are his species — but distinct skins, so a child never mistakes a
// decoration for Hop himself.
const HOP_MINT = {
  bodyLight: '#CBF0DA', bodyMid: '#93DDB2', bodyDeep: '#6BC496', bodyShadow: '#54AD7E',
  belly: '#FBFFFC', bellyEdge: '#E6F6EC', ink: '#3C8F63', mouth: '#49996E',
  cheek: '#FF9F8F', eyeWhite: '#FFFFFF', pupil: '#243047',
  domeLight: '#DCF5E6', domeDeep: '#7BCFA1',
};
const HOP_BLUE = {
  bodyLight: '#C4EBF8', bodyMid: '#6FC7E8', bodyDeep: '#4FAACE', bodyShadow: '#2A87AC',
  belly: '#F2FBFE', bellyEdge: '#DCF0F8', ink: '#1B6280', mouth: '#22779A',
  cheek: '#FF9F8F', eyeWhite: '#FFFFFF', pupil: '#243047',
  domeLight: '#BEE8F7', domeDeep: '#57B2D6',
};

// ---------------------------------------------------------------------------
// Gradient / filter library. Every def lives here once; `autoDefs` pulls in
// exactly the ones a drawing references, so no file carries dead markup.
// ---------------------------------------------------------------------------
const stops = (list) => list.map(([o, c, a]) =>
  `<stop offset="${o}" stop-color="${c}"${a === undefined ? '' : ` stop-opacity="${a}"`}/>`).join('');
const lin = (id, list, { x1 = 0, y1 = 0, x2 = 0, y2 = 1 } = {}) =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${stops(list)}</linearGradient>`;
const rad = (id, list, { cx = 0.5, cy = 0.5, r = 0.5 } = {}) =>
  `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}">${stops(list)}</radialGradient>`;

const DEFS = {
  // -- Hop --
  hopBody: lin('hopBody', [[0, HOP.bodyLight], [0.52, HOP.bodyMid], [1, HOP.bodyDeep]], { x1: 0.2, x2: 0.85 }),
  hopBodyMint: lin('hopBodyMint', [[0, HOP_MINT.bodyLight], [0.52, HOP_MINT.bodyMid], [1, HOP_MINT.bodyDeep]], { x1: 0.2, x2: 0.85 }),
  hopEyeDomeMint: rad('hopEyeDomeMint', [[0, HOP_MINT.domeLight], [1, HOP_MINT.domeDeep]], { cx: 0.36, cy: 0.28, r: 0.75 }),
  hopBodyBlue: lin('hopBodyBlue', [[0, HOP_BLUE.bodyLight], [0.52, HOP_BLUE.bodyMid], [1, HOP_BLUE.bodyDeep]], { x1: 0.2, x2: 0.85 }),
  hopSheen: rad('hopSheen', [[0, '#FFFFFF', 0.45], [1, '#FFFFFF', 0]], { cx: 0.34, cy: 0.22, r: 0.6 }),
  hopCheek: rad('hopCheek', [[0, '#FF8E86', 0.85], [0.55, P.peach, 0.55], [1, P.peach, 0]]),
  hopEyeDome: rad('hopEyeDome', [[0, HOP.domeLight], [1, HOP.domeDeep]], { cx: 0.36, cy: 0.28, r: 0.75 }),
  hopEyeDomeBlue: rad('hopEyeDomeBlue', [[0, HOP_BLUE.domeLight], [1, HOP_BLUE.domeDeep]], { cx: 0.36, cy: 0.28, r: 0.75 }),
  groundShadow: rad('groundShadow', [[0, P.midnight, 0.20], [1, P.midnight, 0]]),
  softShadow: rad('softShadow', [[0, P.midnight, 0.14], [1, P.midnight, 0]]),

  // -- Sky / weather --
  skyPond: lin('skyPond', [[0, '#CFEDF9'], [0.55, P.pondBlueSoft], [1, P.sunshineSoft]]),
  skyWarm: lin('skyWarm', [[0, '#CFE9F6'], [0.42, '#E6F5FB'], [0.75, P.sunshineSoft], [1, '#FFF0E2']]),
  skyHaze: lin('skyHaze', [[0, P.cloud, 0], [0.55, P.cloud, 0.12], [1, P.cloud, 0.8]]),
  sunGlow: rad('sunGlow', [[0, P.sunshine, 0.95], [0.45, P.sunshine, 0.45], [1, P.sunshine, 0]]),
  sunDisc: rad('sunDisc', [[0, '#FFF0C2'], [1, P.sunshine]], { cx: 0.4, cy: 0.35, r: 0.75 }),
  beamFade: lin('beamFade', [[0, P.sunshine, 0.42], [1, P.sunshine, 0]]),
  cloudFill: lin('cloudFill', [[0, '#FFFFFF'], [1, '#EAF3F8']]),
  moonGlow: rad('moonGlow', [[0, P.sunshineSoft, 0.9], [1, P.sunshineSoft, 0]]),

  // -- Land / water --
  hillFar: lin('hillFar', [[0, '#C7E9D6'], [1, '#AEDFC4']]),
  hillMid: lin('hillMid', [[0, '#A9DEC0'], [1, '#8CD1A9']]),
  ground: lin('ground', [[0, '#A8DFC0'], [0.5, P.hopGreenLight], [1, '#7ECBA0']]),
  groundNear: lin('groundNear', [[0, '#7CC79E'], [1, '#5FB287']]),
  water: lin('water', [[0, P.pondBlueLight], [0.55, P.pondBlue], [1, '#57B6DC']]),
  waterDeep: lin('waterDeep', [[0, '#7FCFEC'], [1, P.pondBlueDeep]]),
  shoreSand: lin('shoreSand', [[0, P.sand100], [1, P.sand200]]),

  // -- Plants --
  padGreen: lin('padGreen', [[0, P.hopGreenLight], [1, P.hopGreenDeep]], { x1: 0.2, x2: 0.9 }),
  padGreenLight: lin('padGreenLight', [[0, '#A7E6C2'], [1, P.hopGreen]], { x1: 0.2, x2: 0.9 }),
  bladeGreen: lin('bladeGreen', [[0, P.hopGreenLight], [1, P.hopGreenDeep]]),
  bladeGreenDeep: lin('bladeGreenDeep', [[0, P.hopGreen], [1, P.hopGreenInk]]),
  fernGreen: lin('fernGreen', [[0, '#8FD9AF'], [1, P.hopGreenDeep]]),
  petalWhite: lin('petalWhite', [[0, '#FFFFFF'], [1, P.peachSoft]]),
  petalPeach: lin('petalPeach', [[0, P.peachSoft], [1, P.peach]]),
  blossomCloud: rad('blossomCloud', [[0, '#FFF0EC'], [1, '#FFC7BC']], { cx: 0.38, cy: 0.32, r: 0.78 }),

  // -- Materials --
  woodGrad: lin('woodGrad', [[0, P.woodLight], [1, P.woodDeep]], { x1: 0.2, x2: 0.9 }),
  woodGradV: lin('woodGradV', [[0, P.woodLight], [1, P.wood]]),
  stoneGrad: lin('stoneGrad', [[0, '#EFEAE3'], [1, '#C9C2B8']], { x1: 0.25, x2: 0.85 }),
  stoneGradCool: lin('stoneGradCool', [[0, '#E6E4EE'], [1, '#BDB8CC']], { x1: 0.25, x2: 0.85 }),
  porcelainGrad: lin('porcelainGrad', [[0, '#FFFFFF'], [0.6, P.porcelainMid], [1, P.porcelainShade]], { x1: 0.2, x2: 0.9 }),
  porcelainSide: lin('porcelainSide', [[0, P.porcelainMid], [1, '#DAD4CB']], { x1: 0, x2: 1, y2: 0 }),
  tileWall: lin('tileWall', [[0, '#FFFDFA'], [1, '#F1EDE6']]),

  // -- Accents --
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
  iconWell: rad('iconWell', [[0, '#FFFFFF', 0.55], [1, '#FFFFFF', 0]], { cx: 0.35, cy: 0.28, r: 0.8 }),

  // -- Quiz answer set (see section 4b) --
  // A clip so an icon may draw ground, sky or a stack that runs past the disc
  // and still end exactly on its edge, instead of being hand-trimmed per icon.
  iconDiscClip: '<clipPath id="iconDiscClip"><circle cx="60" cy="60" r="58"/></clipPath>',
  tvScreenClip: '<clipPath id="tvScreenClip"><rect x="23" y="35" width="74" height="36" rx="7"/></clipPath>',
  mirrorGlassClip: '<clipPath id="mirrorGlassClip"><ellipse cx="60" cy="58" rx="28" ry="36"/></clipPath>',
  paperSheet: lin('paperSheet', [[0, '#FFFFFF'], [1, P.sand100]], { x1: 0.2, x2: 0.9 }),
  paperStack: lin('paperStack', [[0, P.sand100], [1, P.sand300]], { x1: 0.2, x2: 0.9 }),
  screenGrad: lin('screenGrad', [[0, '#E9F7FD'], [1, P.pondBlueLight]], { x1: 0.2, x2: 0.9 }),
  glassGrad: lin('glassGrad', [[0, '#FFFFFF'], [0.55, P.pondBlueSoft], [1, '#D6ECF6']], { x1: 0.2, x2: 0.9 }),
  metalGrad: lin('metalGrad', [[0, P.sand100], [1, P.sand400]], { x1: 0.15, x2: 0.9 }),
  furGrad: rad('furGrad', [[0, P.woodLight], [1, P.wood]], { cx: 0.36, cy: 0.3, r: 0.85 }),
  furGradDeep: lin('furGradDeep', [[0, P.wood], [1, P.woodDeep]], { x1: 0.2, x2: 0.9 }),
  shirtGrad: lin('shirtGrad', [[0, P.hopGreenLight], [1, P.hopGreenDeep]], { x1: 0.2, x2: 0.9 }),
  hairGrad: lin('hairGrad', [[0, P.woodLight], [1, P.woodDeep]], { x1: 0.25, x2: 0.85 }),
  chuteGrad: lin('chuteGrad', [[0, '#FFC0B2'], [1, P.peachDeep]], { x1: 0.1, x2: 0.9 }),

  // -- App icon --
  iconSky: lin('iconSky', [[0, '#5FBE8C'], [0.5, '#3FA672'], [1, '#227A4E']], { x1: 0.15, x2: 0.85 }),
  iconHalo: rad('iconHalo', [[0, '#FFFFFF', 0.3], [0.6, '#FFFFFF', 0.08], [1, '#FFFFFF', 0]], { cx: 0.5, cy: 0.42, r: 0.62 }),
  iconWater: lin('iconWater', [[0, '#7FD0EC', 0.85], [1, '#4FB6DC', 0.95]]),
  iconDisc: '<clipPath id="iconDisc"><circle cx="512" cy="490" r="386"/></clipPath>',
  iconVignette: rad('iconVignette', [[0.62, P.hopGreenInk, 0], [1, P.hopGreenInk, 0.22]], { r: 0.75 }),
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
// Shape primitives. Everything downstream is assembled from these, which is
// what keeps the whole set looking like one hand.
// ---------------------------------------------------------------------------
const R = (n) => Math.round(n * 100) / 100;
const g = (transform, inner) => `<g transform="${transform}">${inner}</g>`;
const ellipsePath = (cx, cy, rx, ry) =>
  `M ${R(cx - rx)} ${R(cy)} a ${R(rx)} ${R(ry)} 0 1 0 ${R(rx * 2)} 0 a ${R(rx)} ${R(ry)} 0 1 0 ${R(-rx * 2)} 0`;

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

/** A grass blade / reed: rooted wide, curving to a soft tip.
 *  The tip is a small arc, not a point — sharp spikes read as harsh, which is
 *  the opposite of what this app is for. */
function blade(x, baseY, h, curve, w) {
  const tx = x + curve, ty = baseY - h;
  return `M ${R(x - w)} ${R(baseY)}
    Q ${R(x - w * 0.45 + curve * 0.3)} ${R(baseY - h * 0.6)} ${R(tx - w * 0.16)} ${R(ty + w * 0.3)}
    Q ${R(tx)} ${R(ty - w * 0.2)} ${R(tx + w * 0.2)} ${R(ty + w * 0.5)}
    Q ${R(x + w * 0.75 + curve * 0.25)} ${R(baseY - h * 0.5)} ${R(x + w)} ${R(baseY)} Z`;
}

/** One petal, tip pointing up from (0,0). Rotate to build a flower. */
function petal(len, wide) {
  return `M 0 0 C ${R(wide)} ${R(-len * 0.35)} ${R(wide * 0.62)} ${R(-len * 0.82)} 0 ${R(-len)} C ${R(-wide * 0.62)} ${R(-len * 0.82)} ${R(-wide)} ${R(-len * 0.35)} 0 0 Z`;
}

/** A five-petal shore flower on a stem. */
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

/** One butterfly half: a broad upper wing and a smaller rounded lower wing,
 *  hinged at the origin so `scale(-1 1)` mirrors it exactly. */
function butterflyHalf(fillTop, fillLow, spot) {
  return `
    <path d="M 2 -18 C 18 -60 58 -74 70 -50 C 82 -26 52 -4 6 -2 Z" fill="${fillTop}"/>
    <path d="M 4 2 C 34 4 56 20 48 42 C 40 62 12 54 4 22 Z" fill="${fillLow}"/>
    <circle cx="46" cy="-40" r="9" fill="${spot}" opacity="0.55"/>
    <circle cx="28" cy="26" r="6" fill="${spot}" opacity="0.45"/>`;
}

/** A fern frond drawn as one lobed, arching leaf silhouette.
 *  Two earlier attempts stacked leaflet pairs along a spine; both read as a
 *  small conifer. A single scalloped blade reads as foliage at any size. */
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

// ---------------------------------------------------------------------------
// Hop's anatomy, mirrored from hop-art.js so friends, the shield hero and the
// app icon are literally the same character, not a redraw.
// ---------------------------------------------------------------------------
function hopEyes({ lx = 194, rx = 318, cy = 196, r = 57, pupilR = 25, gaze = [0, 10], blink = 0, skin = HOP, dome = 'hopEyeDome' }) {
  const [gx, gy] = gaze;
  const one = (cx) => {
    const domeShape = `<circle cx="${cx}" cy="${cy}" r="${r + 3}" fill="url(#${dome})"/>`;
    if (blink >= 1) {
      return `<g>${domeShape}<path d="M ${R(cx - r * 0.66)} ${cy + 2} Q ${cx} ${R(cy + r * 0.42)} ${R(cx + r * 0.66)} ${cy + 2}" fill="none" stroke="${skin.ink}" stroke-width="8" stroke-linecap="round" opacity="0.85"/></g>`;
    }
    return `<g>${domeShape}
      <ellipse cx="${cx}" cy="${cy}" rx="${r}" ry="${R(r * (1 - blink))}" fill="${skin.eyeWhite}"/>
      <circle cx="${R(cx + gx)}" cy="${R(cy + gy)}" r="${R(pupilR)}" fill="${skin.pupil}"/>
      <circle cx="${R(cx + gx - pupilR * 0.36)}" cy="${R(cy + gy - pupilR * 0.42)}" r="${R(pupilR * 0.36)}" fill="#FFFFFF" opacity="0.96"/>
      <circle cx="${R(cx + gx + pupilR * 0.32)}" cy="${R(cy + gy + pupilR * 0.34)}" r="${R(pupilR * 0.17)}" fill="#FFFFFF" opacity="0.72"/>
    </g>`;
  };
  return one(lx) + one(rx);
}

function hopBody({ squash = 0, grad = 'hopBody' } = {}) {
  const s = squash;
  return `<path d="
    M 256 ${186 + s * 14}
    C ${330 + s * 10} ${186 + s * 14}, ${392 + s * 14} ${232 + s * 8}, ${400 + s * 16} ${292 + s * 4}
    C ${408 + s * 18} 350, ${396 + s * 12} 400, 340 418
    C 300 430, 212 430, 172 418
    C ${116 - s * 12} 400, ${104 - s * 18} 350, ${112 - s * 16} ${292 + s * 4}
    C ${120 - s * 14} ${232 + s * 8}, ${182 - s * 10} ${186 + s * 14}, 256 ${186 + s * 14}
    Z" fill="url(#${grad})"/>`;
}
const hopBelly = (skin = HOP) => `<ellipse cx="256" cy="364" rx="86" ry="56" fill="${skin.belly}" opacity="0.95"/>
  <ellipse cx="256" cy="364" rx="86" ry="56" fill="none" stroke="${skin.bellyEdge}" stroke-width="3"/>`;
function hopMouth({ open = 0, smile = 1, skin = HOP }) {
  if (open > 0) {
    return `<path d="M 202 292 Q 256 ${R(300 + open * 8)} 310 292 Q 300 ${R(330 + open * 26)} 256 ${R(332 + open * 28)} Q 212 ${R(330 + open * 26)} 202 292 Z" fill="${skin.ink}" opacity="0.9"/>
      <path d="M 232 ${R(322 + open * 20)} Q 256 ${R(336 + open * 24)} 280 ${R(322 + open * 20)} Q 256 ${R(330 + open * 22)} 232 ${R(322 + open * 20)} Z" fill="${skin.cheek}" opacity="0.85"/>`;
  }
  return `<path d="M 202 294 Q 256 ${R(294 + 44 * smile)} 310 294" fill="none" stroke="${skin.mouth}" stroke-width="11" stroke-linecap="round"/>`;
}
const hopCheeks = () => `<ellipse cx="158" cy="308" rx="30" ry="19" fill="url(#hopCheek)"/>
  <ellipse cx="354" cy="308" rx="30" ry="19" fill="url(#hopCheek)"/>`;
function hopFoot(cx, cy, flip = 1, lift = 0, skin = HOP) {
  return g(`translate(${cx} ${cy - lift}) scale(${flip} 1)`, `
    <ellipse cx="0" cy="2" rx="44" ry="21" fill="${skin.bodyDeep}"/>
    <circle cx="-27" cy="-11" r="17" fill="${skin.bodyDeep}"/><circle cx="0" cy="-16" r="17" fill="${skin.bodyDeep}"/><circle cx="27" cy="-11" r="17" fill="${skin.bodyDeep}"/>
    <ellipse cx="0" cy="4" rx="29" ry="12" fill="${skin.bodyLight}" opacity="0.45"/>`);
}
function hopArm(cx, cy, angle, len = 54, w = 30, skin = HOP) {
  return g(`translate(${cx} ${cy}) rotate(${angle})`, `
    <rect x="${-w / 2}" y="${-w / 2}" width="${len + w / 2}" height="${w}" rx="${w / 2}" fill="${skin.bodyDeep}"/>
    <circle cx="${len}" cy="0" r="${w / 2 + 4}" fill="${skin.bodyDeep}"/>
    <circle cx="${len - 4}" cy="-4" r="${w / 2 - 2}" fill="${skin.bodyMid}" opacity="0.5"/>`);
}
const hopSheen = `<ellipse cx="200" cy="248" rx="96" ry="70" fill="url(#hopSheen)"/>`;

/** Hop, or a friend, standing. Drawn in the 512-box then placed by the caller. */
function frog({ skin = HOP, grad = 'hopBody', dome = 'hopEyeDome', squash = 0, gaze = [0, 10], blink = 0, smile = 1, open = 0, arms = [[118, 338, 160], [394, 338, 20]], feet = true } = {}) {
  return `${hopBody({ squash, grad })}
    ${hopSheen}
    ${arms.map((a) => hopArm(a[0], a[1], a[2], a[3] || 54, a[4] || 30, skin)).join('')}
    ${hopBelly(skin)}
    ${feet ? hopFoot(190, 436, 1, 0, skin) + hopFoot(322, 436, -1, 0, skin) : ''}
    ${hopEyes({ gaze, blink, skin, dome })}
    ${hopCheeks()}
    ${hopMouth({ smile, open, skin })}`;
}

/** Place a 512-box frog into an arbitrary box, centred on (cx, cy). */
function placeFrog(cx, cy, size, inner) {
  const s = size / 512;
  return g(`translate(${R(cx)} ${R(cy)}) scale(${R(s)}) translate(-256 -300)`, inner);
}

// ---------------------------------------------------------------------------
// Hop's CURRENT anatomy, mirrored from hop-art.js.
//
// The block above is the first Hop — a gradient egg with dome eyes — and is
// still what the routine scenes and the shield hero draw. This block is the
// redrawn one: flat, from the approved reference (`hop_mascot.svg`), articulated
// as head / torso / two arms / two legs. Numbers are in the reference's 150x160
// space so they can be checked against `Scripts/hop-art.js` line for line, and
// `placeFlat` puts that box wherever a caller needs it.
//
// Flat means flat: no gradients, no outlines, no sheen. Depth is value steps in
// the skin ramp alone.
// ---------------------------------------------------------------------------

/** Shared, species-level colours — the parts of a frog that are not its skin. */
const FLAT = {
  belly: P.sunshineSoft, cheek: P.peach, eyeWhite: P.white, pupil: P.midnight,
  highlight: P.white, mouthInterior: P.peachInk,
  tongue: '#FF6F7D',            // character-only, as in hop-art.js
  bagBody: P.wood, bagStrap: P.woodDeep,
};
/** Hop himself: the brand ramp. */
const FLAT_HOP = { body: P.hopGreen, bodyDeep: '#45A971', ink: P.hopGreenInk };
/** Two siblings. Same anatomy — they are his species — different skin, so a
 *  child never mistakes a pond decoration for Hop. */
const FLAT_MINT = { body: '#93DDB2', bodyDeep: '#6BC496', ink: '#3C8F63' };
const FLAT_BLUE = { body: P.pondBlue, bodyDeep: '#4FAACE', ink: P.pondBlueInk };

const FLAT_EYE_L = { cx: 42.4, cy: 25.7 };
const FLAT_EYE_R = { cx: 108.4, cy: 25.7 };
const FLAT_WHITE_R = 15.5;

// Clip ids have to be unique per *file*, and pond-preview.svg carries both
// friends at once, so every clip gets a serial number rather than a fixed name.
let flatClip = 0;

/** Crown, jaw and the two eye sockets: one fill, no seams. */
const flatHead = (skin) => `
  <ellipse cx="75" cy="42" rx="46" ry="31" fill="${skin.body}"/>
  <ellipse cx="75" cy="54" rx="65" ry="26" fill="${skin.body}"/>
  <circle cx="${FLAT_EYE_L.cx}" cy="${FLAT_EYE_L.cy}" r="19.5" fill="${skin.body}"/>
  <circle cx="${FLAT_EYE_R.cx}" cy="${FLAT_EYE_R.cy}" r="19.5" fill="${skin.body}"/>`;

const flatSpots = (skin) => `
  <ellipse cx="75.3" cy="19.4" rx="4.4" ry="2.6" fill="${skin.bodyDeep}"/>
  <ellipse cx="72.8" cy="26.2" rx="2.6" ry="1.9" fill="${skin.bodyDeep}"/>
  <ellipse cx="80.6" cy="24.6" rx="3" ry="1.6" fill="${skin.bodyDeep}"/>`;

const flatNostrils = (skin) => `
  <circle cx="67.4" cy="41" r="2.1" fill="${skin.ink}"/>
  <circle cx="82.6" cy="41" r="2.1" fill="${skin.ink}"/>`;

const flatCheeks = () => `
  <circle cx="32" cy="51" r="7.6" fill="${FLAT.cheek}"/>
  <circle cx="118" cy="51" r="7.6" fill="${FLAT.cheek}"/>`;

function flatEyes({ gaze = [0, 0], blink = 0, mood = 'happy', skin = FLAT_HOP } = {}) {
  const [gx, gy] = gaze;
  const one = ({ cx, cy }) => {
    if (blink >= 1) {
      const dir = mood === 'rest' ? 1 : -1;
      return `<path d="M ${cx - 10} ${cy + 3} Q ${cx} ${cy + 3 + dir * 9} ${cx + 10} ${cy + 3}" fill="none" stroke="${skin.ink}" stroke-width="3.2" stroke-linecap="round"/>`;
    }
    return `<circle cx="${cx}" cy="${cy}" r="${FLAT_WHITE_R}" fill="${FLAT.eyeWhite}"/>
      <circle cx="${R(cx + gx)}" cy="${R(cy + 1 + gy)}" r="11.5" fill="${FLAT.pupil}"/>
      <circle cx="${R(cx + gx + 3.2)}" cy="${R(cy - 4 + gy)}" r="3.4" fill="${FLAT.highlight}"/>`;
  };
  return one(FLAT_EYE_L) + one(FLAT_EYE_R);
}

/** `open` is the reference's wide smile with tongue; `talk` the same at 72%. */
function flatMouth(kind = 'open', skin = FLAT_HOP) {
  if (kind === 'closed' || kind === 'small') {
    const d = kind === 'closed' ? 12 : 8;
    return `<path d="M 58 50 Q 75 ${50 + d} 92 50" fill="none" stroke="${skin.ink}" stroke-width="3.4" stroke-linecap="round"/>`;
  }
  const s = kind === 'talk' ? 0.72 : 1;
  const uid = `flatMouth${++flatClip}`;
  const shape = 'M 53 47.5 Q 75 52 97 47.5 C 96 60 88 69.5 75 69.5 C 62 69.5 54 60 53 47.5 Z';
  return `<g transform="translate(75 50) scale(${s}) translate(-75 -50)">
    <clipPath id="${uid}"><path d="${shape}"/></clipPath>
    <path d="${shape}" fill="${FLAT.mouthInterior}"/>
    <ellipse cx="75" cy="66" rx="15" ry="7.5" fill="${FLAT.tongue}" clip-path="url(#${uid})"/>
  </g>`;
}

/** Straight sides that run up under the jaw, rounded only at the hips. */
function flatTorso({ squash = 0, width = 60 } = {}, skin = FLAT_HOP) {
  const x0 = 75 - width / 2, x1 = 75 + width / 2;
  const top = 58 + squash * 4, bottom = 130 - squash * 4, r = Math.min(27, width / 2);
  return `<path d="M ${x0} ${top} H ${x1} V ${bottom - r} A ${r} ${r} 0 0 1 ${x1 - r} ${bottom} H ${x0 + r} A ${r} ${r} 0 0 1 ${x0} ${bottom - r} Z" fill="${skin.body}"/>`;
}

const flatBelly = ({ scale = 1 } = {}) =>
  `<ellipse cx="75" cy="${R(104 + (scale - 1) * 4)}" rx="${R(24 * scale)}" ry="${R(23 * scale)}" fill="${FLAT.belly}"/>`;

/** An arm from a shoulder to a hand, with the three fingers that make a hand
 *  read as a hand. */
function flatArm(shoulder, hand, skin = FLAT_HOP) {
  const [sx, sy] = shoulder, [hx, hy] = hand;
  const base = Math.atan2(hy - sy, hx - sx);
  const finger = (deg) => {
    const a = base + (deg * Math.PI) / 180;
    return `<line x1="${hx}" y1="${hy}" x2="${R(hx + Math.cos(a) * 11)}" y2="${R(hy + Math.sin(a) * 11)}" stroke="${skin.body}" stroke-width="9" stroke-linecap="round"/>`;
  };
  return `<g>
    <line x1="${sx}" y1="${sy}" x2="${hx}" y2="${hy}" stroke="${skin.body}" stroke-width="13" stroke-linecap="round"/>
    <circle cx="${hx}" cy="${hy}" r="8.4" fill="${skin.body}"/>
    ${finger(-50)}${finger(0)}${finger(50)}</g>`;
}

/** A leg with a three-toed foot. `side` -1 is Hop's right, the viewer's left. */
function flatLeg(hip, ankle, side, { toeSpread = 1 } = {}, skin = FLAT_HOP) {
  const [hx, hy] = hip, [ax, ay] = ankle;
  const fx = ax - side * 2, fy = ay + 3;
  const t = (d) => (side < 0 ? 180 + d : -d);
  const toe = (deg, r) => {
    const a = (deg * Math.PI) / 180;
    return `<line x1="${fx}" y1="${fy}" x2="${R(fx + Math.cos(a) * 12 * toeSpread)}" y2="${R(fy + Math.sin(a) * 10)}" stroke="${skin.body}" stroke-width="${r * 2}" stroke-linecap="round"/>`;
  };
  const crease = (deg) => {
    const a = (deg * Math.PI) / 180;
    return `<line x1="${R(fx + Math.cos(a) * 5)}" y1="${R(fy + Math.sin(a) * 5)}" x2="${R(fx + Math.cos(a) * 14 * toeSpread)}" y2="${R(fy + Math.sin(a) * 12)}" stroke="${skin.bodyDeep}" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/>`;
  };
  return `<g>
    <line x1="${hx}" y1="${hy}" x2="${ax}" y2="${ay}" stroke="${skin.body}" stroke-width="16" stroke-linecap="round"/>
    <ellipse cx="${fx}" cy="${fy}" rx="9.5" ry="7" fill="${skin.body}"/>
    ${toe(t(-8), 5.4)}${toe(t(-46), 5.4)}${toe(t(-84), 5)}
    ${crease(t(-30))}${crease(t(-70))}</g>`;
}

const flatShadow = (lift = 0) =>
  `<ellipse cx="75" cy="${R(159 - lift * 0.1)}" rx="${R(40 - lift * 0.4)}" ry="4" fill="${P.midnight}" opacity="${R(0.12 - lift * 0.002)}"/>`;

/** The face alone, for the app icon — `hop-face.svg`, in other words. */
function flatFace({ skin = FLAT_HOP, gaze = [0, 0], mouth = 'open' } = {}) {
  return `${flatHead(skin)}${flatSpots(skin)}${flatEyes({ gaze, skin })}${flatCheeks()}${flatNostrils(skin)}${flatMouth(mouth, skin)}`;
}

/** One whole frog. Draw order is `figure()`'s: shadow, legs, torso, belly,
 *  arms, head, face — so limbs read as attached rather than stacked. */
function flatFigure({
  skin = FLAT_HOP, lift = 0, squash = 0, tilt = 0, torsoWidth = 60, bellyScale = 1,
  armL = [10, 97], armR = [140, 97],
  legL = { hip: [55, 122], ankle: [54, 148], spread: 1 },
  legR = { hip: [95, 122], ankle: [96, 148], spread: 1 },
  eyes = {}, mouth = 'open', showShadow = true,
} = {}) {
  return `${showShadow ? flatShadow(lift) : ''}
  <g transform="translate(0 ${-lift})">
    ${flatLeg(legL.hip, legL.ankle, -1, { toeSpread: legL.spread }, skin)}
    ${flatLeg(legR.hip, legR.ankle, 1, { toeSpread: legR.spread }, skin)}
    ${flatTorso({ squash, width: torsoWidth }, skin)}
    ${flatBelly({ scale: bellyScale })}
    ${flatArm([50, 90], armL, skin)}
    ${flatArm([100, 90], armR, skin)}
    <g transform="rotate(${tilt} 75 50)">
      ${flatHead(skin)}${flatSpots(skin)}
      ${flatEyes({ ...eyes, skin })}${flatCheeks()}${flatNostrils(skin)}${flatMouth(mouth, skin)}
    </g>
  </g>`;
}

/** Places the 150x160 reference box, centred on (cx, cy) at `scale`. */
function placeFlat(cx, cy, scale, inner, anchor = [75, 84]) {
  return g(`translate(${R(cx)} ${R(cy)}) scale(${R(scale)}) translate(${-anchor[0]} ${-anchor[1]})`, inner);
}

// ===========================================================================
// 1. THE POND
// ===========================================================================
const SCENE_W = 1200;
const SCENE_H = 900;
/** One item box (200 units) covers this many scene units at PondAnchor scale 1.
 *  Tuned by eye against the composited preview: any larger and neighbouring
 *  decorations touch, which is what the anchors' 0.05 minimum separation is
 *  guarding against. */
const ITEM_SPAN = 156;

const POND_CX = SCENE_W * 0.5;
const POND_CY = SCENE_H * 0.62;
const POND_RX = 470;
const POND_RY = 232;

const pondLayers = {
  sky: () => `
    <rect x="0" y="0" width="${SCENE_W}" height="${SCENE_H}" fill="url(#skyPond)"/>
    ${cloud(210, 150, 190, { opacity: 0.7 })}
    ${cloud(940, 108, 150, { opacity: 0.55 })}
    <rect x="0" y="0" width="${SCENE_W}" height="470" fill="url(#skyHaze)"/>`,

  backdrop: () => `
    <path d="M -20 372 Q 190 268 430 336 Q 610 386 760 330 Q 960 258 1220 356 L 1220 460 L -20 460 Z" fill="url(#hillFar)"/>
    <path d="M -20 408 Q 240 336 470 392 Q 700 448 940 388 Q 1090 350 1220 396 L 1220 500 L -20 500 Z" fill="url(#hillMid)" opacity="0.9"/>
    <path d="M -20 430 Q 300 388 600 424 Q 900 460 1220 418 L 1220 920 L -20 920 Z" fill="url(#ground)"/>
    <ellipse cx="${POND_CX}" cy="${POND_CY + 6}" rx="${POND_RX + 52}" ry="${POND_RY + 40}" fill="#8FD3AE" opacity="0.45"/>`,

  water: () => `
    <ellipse cx="${POND_CX}" cy="${POND_CY}" rx="${POND_RX}" ry="${POND_RY}" fill="url(#water)"/>
    <ellipse cx="${POND_CX}" cy="${POND_CY - 18}" rx="${POND_RX - 40}" ry="${POND_RY - 46}" fill="#8FD8F0" opacity="0.35"/>
    <path d="M 330 ${POND_CY - 108} q 90 -22 180 0" fill="none" stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" opacity="0.34"/>
    <path d="M 700 ${POND_CY - 66} q 70 -18 140 0" fill="none" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" opacity="0.26"/>
    <path d="M 400 ${POND_CY + 118} q 110 24 220 0" fill="none" stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" opacity="0.22"/>`,

  shore: () => `
    <path d="${ellipsePath(POND_CX, POND_CY + 10, POND_RX + 40, POND_RY + 32)} ${ellipsePath(POND_CX, POND_CY, POND_RX, POND_RY)}" fill-rule="evenodd" fill="url(#shoreSand)" opacity="0.85"/>
    <g fill="${P.hopGreenDeep}" opacity="0.4">
      <path d="${blade(192, 706, 52, 26, 10)}"/><path d="${blade(212, 708, 38, -22, 9)}"/><path d="${blade(204, 710, 30, 6, 8)}"/>
      <path d="${blade(1012, 692, 50, -26, 10)}"/><path d="${blade(992, 694, 36, 22, 9)}"/><path d="${blade(1002, 696, 28, -6, 8)}"/>
      <path d="${blade(626, 808, 42, 22, 10)}"/><path d="${blade(648, 810, 30, -18, 9)}"/>
    </g>`,

  // Kept low and thin: the near bank sits below every shore anchor (the lowest
  // is y=0.90), so it frames the scene instead of swallowing the front row.
  foreground: () => `
    <path d="M -20 884 Q 300 856 620 876 Q 900 894 1220 862 L 1220 920 L -20 920 Z" fill="url(#groundNear)" opacity="0.9"/>
    <g fill="${P.hopGreenInk}" opacity="0.18">
      <path d="${blade(74, 894, 62, 20, 10)}"/><path d="${blade(108, 898, 46, -14, 8)}"/>
      <path d="${blade(1126, 886, 66, -20, 10)}"/><path d="${blade(1090, 890, 48, 14, 8)}"/>
    </g>
    <ellipse cx="600" cy="910" rx="760" ry="80" fill="${P.hopGreenInk}" opacity="0.08"/>`,
};

// --- Decorations. All drawn inside 0 0 200 200, centred on (100, 100). ------
const ITEMS = {
  lilyPadSmall: () => `
    <path d="${pad(100, 106, 68, { notch: 52 })}" fill="${P.hopGreenDeep}" opacity="0.5"/>
    <path d="${pad(100, 102, 68, { notch: 52 })}" fill="url(#padGreenLight)"/>
    <path d="M 100 102 l 42 -17" stroke="${P.hopGreenSoft}" stroke-width="3" stroke-linecap="round" opacity="0.45" fill="none"/>
    <ellipse cx="78" cy="90" rx="26" ry="8" fill="#FFFFFF" opacity="0.2"/>`,

  lilyPadLarge: () => `
    <path d="${pad(58, 96, 44, { notch: 210, spread: 18 })}" fill="url(#padGreen)" opacity="0.85"/>
    <path d="${pad(108, 110, 84, { notch: 62 })}" fill="${P.hopGreenDeep}" opacity="0.5"/>
    <path d="${pad(108, 105, 84, { notch: 62 })}" fill="url(#padGreenLight)"/>
    <g stroke="${P.hopGreenSoft}" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.32">
      <path d="M 108 105 l 52 -22"/><path d="M 108 105 l 6 -34"/><path d="M 108 105 l -56 -13"/><path d="M 108 105 l -28 28"/>
    </g>
    <ellipse cx="80" cy="90" rx="30" ry="9" fill="#FFFFFF" opacity="0.18"/>`,

  lilyFlower: () => `
    <path d="${pad(100, 142, 78, { squash: 0.34, notch: 90, spread: 13 })}" fill="url(#padGreenLight)"/>
    ${Array.from({ length: 8 }, (_, i) => g(`translate(100 108) rotate(${i * 45 + 22})`, `<path d="${petal(58, 22)}" fill="url(#petalWhite)"/>`)).join('')}
    ${Array.from({ length: 6 }, (_, i) => g(`translate(100 106) rotate(${i * 60})`, `<path d="${petal(38, 16)}" fill="url(#petalPeach)"/>`)).join('')}
    <circle cx="100" cy="104" r="13" fill="${P.sunshine}"/>
    <circle cx="97" cy="101" r="6" fill="${P.sunshineSoft}"/>`,

  // Reeds are drawn as soft arcs rather than the straight spears of pass 1 —
  // sharp blades read as spikes, which is the wrong register for this app.
  reedsLeft: () => `
    <g fill="url(#bladeGreen)">
      <path d="${blade(76, 176, 104, 40, 11)}"/><path d="${blade(102, 178, 138, 20, 12)}"/>
      <path d="${blade(128, 176, 96, -34, 10)}"/>
    </g>
    <g fill="url(#bladeGreenDeep)" opacity="0.7">
      <path d="${blade(90, 178, 74, -30, 9)}"/><path d="${blade(116, 178, 60, 30, 8)}"/>
    </g>`,

  reedsRight: () => g('translate(200 0) scale(-1 1)', `
    <g fill="url(#bladeGreen)">
      <path d="${blade(76, 176, 110, 38, 11)}"/><path d="${blade(100, 178, 142, 18, 12)}"/>
      <path d="${blade(130, 176, 90, -36, 10)}"/>
    </g>
    <g fill="url(#bladeGreenDeep)" opacity="0.7">
      <path d="${blade(88, 178, 70, -28, 9)}"/><path d="${blade(118, 178, 58, 28, 8)}"/>
    </g>`),

  cattails: () => `
    <g fill="url(#bladeGreen)">
      <path d="${blade(84, 182, 88, 30, 9)}"/><path d="${blade(118, 182, 76, -28, 9)}"/>
    </g>
    ${[[68, 66, 0.9, 8], [102, 38, 1.06, 0], [136, 78, 0.84, -8]].map(([x, top, s, lean]) => `
      <path d="M ${x} 180 Q ${R(x + lean * 0.6)} ${R((180 + top) / 2)} ${R(x + lean)} ${R(top + 46 * s)}" stroke="${P.hopGreenDeep}" stroke-width="${R(6 * s)}" stroke-linecap="round" fill="none"/>
      <path d="M ${R(x + lean)} ${R(top + 46 * s)} q 0 -18 ${R(4 * s)} -26" stroke="${P.hopGreenDeep}" stroke-width="${R(5 * s)}" stroke-linecap="round" fill="none"/>
      <rect x="${R(x + lean - 12 * s)}" y="${R(top - 4)}" width="${R(24 * s)}" height="${R(52 * s)}" rx="${R(12 * s)}" fill="url(#woodGrad)"/>
      <rect x="${R(x + lean - 12 * s)}" y="${R(top - 4)}" width="${R(9 * s)}" height="${R(52 * s)}" rx="${R(4.5 * s)}" fill="#FFFFFF" opacity="0.2"/>`).join('')}`,

  stoneSmall: () => `
    <ellipse cx="100" cy="132" rx="62" ry="14" fill="${P.midnight}" opacity="0.10"/>
    ${pebble(96, 108, 56, 34)}
    ${pebble(142, 122, 26, 17, { fill: 'url(#stoneGradCool)' })}`,

  stoneStack: () => `
    <ellipse cx="100" cy="168" rx="66" ry="15" fill="${P.midnight}" opacity="0.10"/>
    ${pebble(100, 148, 62, 26)}
    ${pebble(96, 108, 46, 24, { fill: 'url(#stoneGradCool)' })}
    ${pebble(102, 74, 32, 19)}
    ${pebble(100, 48, 20, 13, { fill: 'url(#stoneGradCool)' })}`,

  flowerYellow: () => `${flower(100, 84, 44, { fill: 'url(#yellowBall)', core: P.sunshineSoft, stemH: 74 })}`,
  flowerPink: () => `${flower(100, 84, 44, { fill: 'url(#peachBall)', core: P.peachSoft, petals: 6, stemH: 74 })}`,
  flowerPurple: () => `${flower(100, 84, 44, { fill: 'url(#lavenderBall)', core: P.lavenderSoft, petals: 5, stemH: 74 })}`,

  fishOrange: () => `
    <path d="M 58 100 q -26 -32 -40 -38 q 8 38 0 76 q 14 -6 40 -38 Z" fill="${P.peach}"/>
    <ellipse cx="108" cy="100" rx="62" ry="37" fill="url(#peachBall)"/>
    <path d="M 100 68 q 20 -24 42 -14 q -16 12 -22 24 Z" fill="${P.peach}" opacity="0.9"/>
    <path d="M 96 132 q 14 20 36 12 q -14 -12 -18 -20 Z" fill="${P.peach}" opacity="0.75"/>
    <ellipse cx="112" cy="90" rx="32" ry="15" fill="#FFFFFF" opacity="0.3"/>
    <circle cx="144" cy="94" r="9" fill="#FFFFFF"/><circle cx="146" cy="94" r="5" fill="${P.midnight}"/>
    <path d="M 150 108 q 12 4 16 -2" stroke="${P.peachDeep}" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.7"/>`,

  fishBlue: () => g('translate(200 0) scale(-1 1)', `
    <path d="M 58 100 q -26 -30 -40 -36 q 8 36 0 72 q 14 -6 40 -36 Z" fill="${P.pondBlueLight}"/>
    <ellipse cx="108" cy="100" rx="58" ry="35" fill="url(#blueBall)"/>
    <path d="M 100 70 q 20 -24 42 -14 q -16 12 -22 24 Z" fill="${P.pondBlueLight}" opacity="0.9"/>
    <ellipse cx="112" cy="90" rx="30" ry="14" fill="#FFFFFF" opacity="0.32"/>
    <circle cx="142" cy="94" r="9" fill="#FFFFFF"/><circle cx="144" cy="94" r="5" fill="${P.midnight}"/>
    <path d="M 148 108 q 12 4 16 -2" stroke="${P.pondBlueDeep}" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.7"/>`),

  // A tadpole is a head and a tail and nothing else — pass 1 gave it fins and
  // it read as a small fish, which the pond already has two of.
  tadpoleFriend: () => `
    <path d="M 108 84 C 84 74 56 104 22 96 C 54 122 82 126 108 116 Z" fill="url(#greenBall)" opacity="0.8"/>
    <circle cx="124" cy="100" r="44" fill="url(#greenBall)"/>
    <ellipse cx="112" cy="84" rx="21" ry="12" fill="#FFFFFF" opacity="0.32"/>
    <circle cx="140" cy="90" r="11" fill="#FFFFFF"/><circle cx="142" cy="91" r="6" fill="${P.midnight}"/>
    <path d="M 130 118 q 14 8 24 -2" fill="none" stroke="${P.hopGreenInk}" stroke-width="5" stroke-linecap="round" opacity="0.75"/>`,

  butterflyBlue: () => g('translate(100 100)', `
    ${butterflyHalf('url(#blueBall)', P.pondBlueLight, '#FFFFFF')}
    ${g('scale(-1 1)', butterflyHalf('url(#blueBall)', P.pondBlueLight, '#FFFFFF'))}
    <ellipse cx="0" cy="4" rx="5.4" ry="30" fill="${P.night600}"/>
    <circle cx="0" cy="-28" r="8" fill="${P.night600}"/>
    <path d="M -3 -34 q -10 -14 -18 -18" stroke="${P.night600}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <path d="M 3 -34 q 10 -14 18 -18" stroke="${P.night600}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <circle cx="-21" cy="-52" r="3.4" fill="${P.night600}"/><circle cx="21" cy="-52" r="3.4" fill="${P.night600}"/>`),

  butterflyYellow: () => g('translate(100 100)', `
    ${butterflyHalf('url(#yellowBall)', P.sunshineSoft, '#FFFFFF')}
    ${g('scale(-1 1)', butterflyHalf('url(#yellowBall)', P.sunshineSoft, '#FFFFFF'))}
    <ellipse cx="0" cy="4" rx="5.4" ry="29" fill="${P.woodDeep}"/>
    <circle cx="0" cy="-27" r="8" fill="${P.woodDeep}"/>
    <path d="M -3 -33 q -10 -14 -18 -18" stroke="${P.woodDeep}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <path d="M 3 -33 q 10 -14 18 -18" stroke="${P.woodDeep}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <circle cx="-21" cy="-51" r="3.4" fill="${P.woodDeep}"/><circle cx="21" cy="-51" r="3.4" fill="${P.woodDeep}"/>`),

  dragonfly: () => g('translate(100 96)', `
    ${g('rotate(-12)', `<ellipse cx="52" cy="-16" rx="52" ry="13" fill="${P.lavender}" opacity="0.5"/>`)}
    ${g('rotate(12)', `<ellipse cx="-52" cy="-16" rx="52" ry="13" fill="${P.lavender}" opacity="0.5"/>`)}
    ${g('rotate(11)', `<ellipse cx="44" cy="10" rx="44" ry="11" fill="${P.pondBlueLight}" opacity="0.45"/>`)}
    ${g('rotate(-11)', `<ellipse cx="-44" cy="10" rx="44" ry="11" fill="${P.pondBlueLight}" opacity="0.45"/>`)}
    <path d="M -6 -22 h 12 q 3 0 3 4 l -3 62 q -6 6 -12 0 l -3 -62 q 0 -4 3 -4 Z" fill="url(#lavenderBall)"/>
    <g fill="#FFFFFF" opacity="0.35"><rect x="-5" y="6" width="10" height="5" rx="2.5"/><rect x="-4.4" y="24" width="9" height="4.4" rx="2.2"/></g>
    <circle cx="0" cy="-30" r="15" fill="${P.lavenderDeep}"/>
    <circle cx="-6" cy="-34" r="5" fill="#FFFFFF" opacity="0.75"/>
    <circle cx="7" cy="-33" r="3.4" fill="#FFFFFF" opacity="0.5"/>`),

  snail: () => `
    <ellipse cx="104" cy="150" rx="68" ry="12" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 40 142 q -20 -6 -18 -26 q 2 -18 20 -18 q 16 0 18 14 l 6 30 Z" fill="url(#greenBall)"/>
    <path d="M 30 100 q -6 -24 4 -34" stroke="${P.hopGreen}" stroke-width="8" stroke-linecap="round" fill="none"/>
    <path d="M 46 100 q 0 -18 8 -26" stroke="${P.hopGreen}" stroke-width="7" stroke-linecap="round" fill="none"/>
    <circle cx="35" cy="62" r="9" fill="${P.hopGreenDeep}"/><circle cx="33" cy="60" r="3.6" fill="#FFFFFF"/>
    <circle cx="55" cy="70" r="7.4" fill="${P.hopGreenDeep}"/><circle cx="53" cy="68" r="3" fill="#FFFFFF"/>
    <path d="M 40 138 q 36 16 78 0 q 18 -8 22 -8" stroke="url(#greenBall)" stroke-width="26" stroke-linecap="round" fill="none"/>
    <circle cx="114" cy="98" r="48" fill="url(#peachBall)"/>
    <path d="M 114 98 m 0 -34 a 34 34 0 1 1 -24 58 a 23 23 0 1 1 28 -38 a 12 12 0 1 0 -15 21"
      fill="none" stroke="${P.peachSoft}" stroke-width="10" stroke-linecap="round" opacity="0.9"/>`,

  // The head is a small cap peeking over the shell. Pass 1 drew it as a wide
  // black band across the top, which read as a bandit mask.
  ladybug: () => `
    <ellipse cx="100" cy="150" rx="54" ry="10" fill="${P.midnight}" opacity="0.1"/>
    <circle cx="100" cy="62" r="26" fill="${P.night700}"/>
    <circle cx="90" cy="52" r="6" fill="#FFFFFF"/><circle cx="110" cy="52" r="6" fill="#FFFFFF"/>
    <circle cx="90" cy="53" r="3" fill="${P.night900}"/><circle cx="110" cy="53" r="3" fill="${P.night900}"/>
    <path d="M 84 40 q -10 -12 -18 -14" stroke="${P.night700}" stroke-width="5" stroke-linecap="round" fill="none"/>
    <path d="M 116 40 q 10 -12 18 -14" stroke="${P.night700}" stroke-width="5" stroke-linecap="round" fill="none"/>
    <ellipse cx="100" cy="110" rx="58" ry="48" fill="url(#peachBall)"/>
    <path d="M 100 62 a 58 48 0 0 0 0 96 Z" fill="#FFFFFF" opacity="0.14"/>
    <path d="M 100 64 L 100 158" stroke="${P.peachInk}" stroke-width="5" opacity="0.45"/>
    <g fill="${P.peachInk}" opacity="0.7">
      <circle cx="74" cy="94" r="10"/><circle cx="126" cy="94" r="10"/>
      <circle cx="72" cy="128" r="8"/><circle cx="128" cy="128" r="8"/>
    </g>`,

  rainbow: () => {
    const bands = [P.peach, P.sunshine, P.hopGreen, P.pondBlue, P.lavender];
    return `<g fill="none" stroke-linecap="round" opacity="0.9">
      ${bands.map((c, i) => `<path d="M ${18 + i * 15} 150 a ${82 - i * 15} ${82 - i * 15} 0 0 1 ${164 - i * 30} 0" stroke="${c}" stroke-width="14" opacity="${R(0.92 - i * 0.04)}"/>`).join('')}
    </g>
    ${cloud(38, 154, 74, { opacity: 0.95 })}
    ${cloud(162, 154, 74, { opacity: 0.95 })}`;
  },

  // Soft tapered beams, not the hard clip-art spokes of pass 1.
  sunbeam: () => `
    <circle cx="100" cy="100" r="92" fill="url(#sunGlow)"/>
    ${Array.from({ length: 8 }, (_, i) => g(`translate(100 100) rotate(${i * 45 + 22})`,
      `<path d="M 0 -54 q 9 -6 11 -18 q 3 -18 -11 -30 q -14 12 -11 30 q 2 12 11 18 Z" fill="url(#beamFade)"/>`)).join('')}
    <circle cx="100" cy="100" r="48" fill="url(#sunDisc)"/>
    <circle cx="84" cy="84" r="15" fill="#FFFFFF" opacity="0.32"/>`,

  cloudPuff: () => `${cloud(100, 100, 160)}
    <ellipse cx="86" cy="86" rx="34" ry="16" fill="#FFFFFF" opacity="0.75"/>`,

  // Hop's species, drawn from Hop's current anatomy. Their own skins and their
  // own poses — a friend that stood like Hop and smiled like Hop would just be
  // a second Hop. The figure carries its own ground shadow, so neither item
  // draws one of its own any more.
  frogFriendGreen: () => placeFlat(100, 100, 1.16, flatFigure({
    skin: FLAT_MINT, lift: -6, squash: 0.3,
    armL: [40, 126], armR: [110, 126],
    legL: { hip: [55, 120], ankle: [36, 140], spread: 1.15 },
    legR: { hip: [95, 120], ankle: [114, 140], spread: 1.15 },
    eyes: { gaze: [2, 2] }, mouth: 'closed',
  })),

  frogFriendBlue: () => placeFlat(100, 100, 1.16, flatFigure({
    skin: FLAT_BLUE, tilt: -3,
    armL: [16, 104], armR: [140, 44],
    eyes: { gaze: [-2, 0] }, mouth: 'talk',
  })),

  // Composed high in its box: `clubhouse` is a backdrop item anchored at
  // y=0.33, right where the pond ellipse is tallest, so a base-heavy drawing
  // gets sliced off by the waterline drawn over it.
  clubhouse: () => g('translate(100 24) scale(0.74) translate(-100 -24)', `
    <ellipse cx="100" cy="178" rx="80" ry="12" fill="${P.midnight}" opacity="0.12"/>
    <path d="M 30 118 q 0 -12 12 -12 h 116 q 12 0 12 12 v 44 q 0 12 -12 12 h -116 q -12 0 -12 -12 Z" fill="url(#woodGrad)"/>
    <path d="M 100 44 L 182 104 q 10 8 -4 8 H 22 q -14 0 -4 -8 Z" fill="url(#greenBall)"/>
    <path d="M 100 58 L 158 100 H 42 Z" fill="#FFFFFF" opacity="0.14"/>
    <path d="M 86 174 v -38 q 0 -18 14 -18 q 14 0 14 18 v 38 Z" fill="${P.woodDeep}"/>
    <circle cx="108" cy="152" r="4" fill="${P.sunshine}"/>
    <circle cx="52" cy="132" r="13" fill="${P.pondBlueSoft}"/>
    <circle cx="148" cy="132" r="13" fill="${P.pondBlueSoft}"/>
    <circle cx="49" cy="129" r="5" fill="#FFFFFF" opacity="0.8"/>
    <circle cx="145" cy="129" r="5" fill="#FFFFFF" opacity="0.8"/>
    <rect x="26" y="106" width="148" height="8" rx="4" fill="${P.woodDeep}" opacity="0.45"/>`),

  // Hanging items carry their own bough. Without it they float in mid-air with
  // a cord running off to nothing.
  lantern: () => `
    <path d="M 22 16 q 44 12 92 4 q 40 -6 66 4" stroke="url(#woodGrad)" stroke-width="9" stroke-linecap="round" fill="none"/>
    <g fill="${P.hopGreen}" opacity="0.85">
      <ellipse cx="44" cy="12" rx="12" ry="6" transform="rotate(-18 44 12)"/>
      <ellipse cx="150" cy="12" rx="11" ry="5.6" transform="rotate(16 150 12)"/>
    </g>
    <path d="M 100 18 v 12" stroke="${P.woodDeep}" stroke-width="4.4" stroke-linecap="round"/>
    <circle cx="100" cy="34" r="9" fill="none" stroke="${P.woodDeep}" stroke-width="5"/>
    <circle cx="100" cy="100" r="70" fill="url(#glowWarm)"/>
    <path d="M 68 48 q 32 -12 64 0 q 6 2 4 8 h -72 q -2 -6 4 -8 Z" fill="${P.woodDeep}"/>
    <path d="M 72 58 h 56 v 44 q 0 26 -28 26 q -28 0 -28 -26 Z" fill="url(#yellowBall)"/>
    <path d="M 78 60 q 8 -2 14 -2 v 66 q -14 -4 -14 -22 Z" fill="#FFFFFF" opacity="0.42"/>
    <rect x="66" y="124" width="68" height="12" rx="6" fill="${P.woodDeep}"/>
    <path d="M 92 136 h 16 l -4 12 h -8 Z" fill="${P.woodDeep}"/>`,

  signpost: () => `
    <ellipse cx="100" cy="182" rx="50" ry="10" fill="${P.midnight}" opacity="0.12"/>
    <rect x="92" y="60" width="16" height="120" rx="8" fill="url(#woodGradV)"/>
    <path d="M 24 66 h 106 l 28 26 l -28 26 H 24 q -8 0 -8 -8 V 74 q 0 -8 8 -8 Z" fill="url(#woodGrad)"/>
    <path d="M 24 66 h 106 l 11 10 H 20 q 0 -10 4 -10 Z" fill="#FFFFFF" opacity="0.2"/>
    <path d="M 40 92 h 74 m -18 -16 l 18 16 l -18 16" stroke="${P.cloud}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.92"/>
    <path d="M 62 180 q 22 -12 44 0" stroke="${P.hopGreenDeep}" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.45"/>`,

  waterLilyCluster: () => `
    <path d="${pad(50, 124, 52, { squash: 0.38, notch: 196, spread: 14 })}" fill="url(#padGreen)"/>
    <path d="${pad(150, 130, 46, { squash: 0.38, notch: 344, spread: 14 })}" fill="url(#padGreen)"/>
    <path d="${pad(100, 118, 62, { squash: 0.38, notch: 90, spread: 13 })}" fill="url(#padGreenLight)"/>
    ${Array.from({ length: 8 }, (_, i) => g(`translate(96 92) rotate(${i * 45 + 22})`, `<path d="${petal(40, 15)}" fill="url(#petalWhite)"/>`)).join('')}
    ${Array.from({ length: 5 }, (_, i) => g(`translate(96 92) rotate(${i * 72})`, `<path d="${petal(26, 11)}" fill="url(#petalPeach)"/>`)).join('')}
    <circle cx="96" cy="92" r="9" fill="${P.sunshine}"/>
    <circle cx="150" cy="116" r="7" fill="${P.peachSoft}"/>`,

  mushroomCluster: () => {
    const shroom = (x, y, s) => g(`translate(${x} ${y}) scale(${s})`, `
      <path d="M -15 -4 q -3 40 1 48 q 14 6 28 0 q 4 -8 1 -48 Z" fill="${P.sand100}"/>
      <path d="M -15 -4 q 8 4 15 4 v 44 q -10 0 -15 -4 Z" fill="${P.sand200}" opacity="0.7"/>
      <path d="M 0 -48 q 46 0 46 30 q 0 10 -13 10 h -66 q -13 0 -13 -10 q 0 -30 46 -30 Z" fill="url(#peachBall)"/>
      <path d="M 0 -48 q -30 0 -40 20 q 12 -10 26 -12 Z" fill="#FFFFFF" opacity="0.22"/>
      <circle cx="-16" cy="-18" r="8" fill="${P.cloud}" opacity="0.9"/>
      <circle cx="10" cy="-28" r="6.4" fill="${P.cloud}" opacity="0.9"/>
      <circle cx="26" cy="-12" r="5.4" fill="${P.cloud}" opacity="0.85"/>`);
    return `<ellipse cx="100" cy="162" rx="72" ry="12" fill="${P.midnight}" opacity="0.1"/>
      ${shroom(56, 156, 0.66)}${shroom(146, 160, 0.56)}${shroom(102, 152, 0.98)}`;
  },

  // Ferns arch. Pass 1 stacked leaflets up a straight spine and the result
  // read as a stand of conifers.
  fernPatch: () => `
    ${g('translate(96 186)', frond(88, -74, 19))}
    ${g('translate(104 186)', frond(84, 72, 18))}
    ${g('translate(92 188)', frond(112, -34, 20))}
    ${g('translate(108 188)', frond(106, 32, 20))}`,

  duckling: () => `
    <ellipse cx="100" cy="152" rx="70" ry="13" fill="${P.pondBlueInk}" opacity="0.12"/>
    <ellipse cx="88" cy="118" rx="60" ry="42" fill="url(#yellowBall)"/>
    <path d="M 122 90 q 10 -14 20 -18" stroke="${P.sunshineBright}" stroke-width="18" stroke-linecap="round" fill="none"/>
    <circle cx="140" cy="70" r="34" fill="url(#yellowBall)"/>
    <circle cx="130" cy="58" r="12" fill="#FFF6D4" opacity="0.45"/>
    <path d="M 168 66 q 24 -4 24 10 q 0 12 -24 8 Z" fill="${P.peach}"/>
    <path d="M 168 76 q 14 2 22 0" stroke="${P.peachDeep}" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.6"/>
    <circle cx="150" cy="62" r="8" fill="#FFFFFF"/><circle cx="152" cy="63" r="4.6" fill="${P.midnight}"/>
    <path d="M 58 98 q 28 -16 58 4 q -8 10 -20 12 q -6 7 -14 1 q -11 -1 -16 -7 q -8 -3 -8 -10 Z" fill="#FFE9A8"/>
    <path d="M 116 102 q -8 10 -20 12 q -6 7 -14 1 q -11 -1 -16 -7" fill="none" stroke="${P.sunshineBright}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 34 146 q 66 20 132 -4" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.55"/>`,

  turtleRock: () => `
    <ellipse cx="100" cy="160" rx="82" ry="16" fill="${P.pondBlueInk}" opacity="0.12"/>
    ${pebble(100, 142, 80, 28, { fill: 'url(#stoneGrad)', light: 0.35 })}
    <ellipse cx="100" cy="152" rx="64" ry="12" fill="${P.sand300}" opacity="0.45"/>
    <ellipse cx="46" cy="122" rx="18" ry="9" fill="${P.hopGreenLight}"/>
    <ellipse cx="150" cy="124" rx="16" ry="8" fill="${P.hopGreenLight}"/>
    <path d="M 32 114 q 6 -52 68 -52 q 62 0 68 52 Z" fill="url(#greenBall)"/>
    <path d="M 32 114 q 6 -52 68 -52 q -28 14 -34 52 Z" fill="#FFFFFF" opacity="0.13"/>
    <g fill="${P.hopGreenSoft}" opacity="0.45">
      <path d="M 100 70 l 20 14 l -8 22 h -24 l -8 -22 Z"/>
      <path d="M 58 96 l 18 8 l -5 10 h -22 Z"/><path d="M 142 96 l -18 8 l 5 10 h 22 Z"/>
    </g>
    <circle cx="164" cy="104" r="19" fill="${P.hopGreenLight}"/>
    <circle cx="172" cy="99" r="5" fill="${P.midnight}"/>
    <path d="M 166 112 q 10 4 15 -2" stroke="${P.hopGreenInk}" stroke-width="3.4" stroke-linecap="round" fill="none"/>`,

  starLantern: () => {
    const star = (cx, cy, r, inner, fill) => {
      const pts = Array.from({ length: 10 }, (_, i) => {
        const rr = i % 2 ? inner : r;
        const a = (Math.PI / 5) * i - Math.PI / 2;
        return `${R(cx + rr * Math.cos(a))} ${R(cy + rr * Math.sin(a))}`;
      });
      return `<path d="M ${pts.join(' L ')} Z" fill="${fill}" stroke="${fill}" stroke-width="14" stroke-linejoin="round"/>`;
    };
    return `<path d="M 26 14 q 40 14 78 6 q 38 -8 70 2" stroke="url(#woodGrad)" stroke-width="8" stroke-linecap="round" fill="none"/>
      <g fill="${P.hopGreen}" opacity="0.85">
        <ellipse cx="48" cy="10" rx="11" ry="5.6" transform="rotate(-18 48 10)"/>
        <ellipse cx="146" cy="10" rx="10" ry="5" transform="rotate(16 146 10)"/>
      </g>
      <path d="M 100 16 v 14" stroke="${P.woodDeep}" stroke-width="4.4" stroke-linecap="round"/>
      <rect x="86" y="28" width="28" height="10" rx="5" fill="${P.woodDeep}"/>
      <circle cx="100" cy="110" r="86" fill="url(#glowWarm)"/>
      ${star(100, 110, 62, 28, P.sunshine)}
      ${star(97, 105, 36, 16, '#FFF3CE')}`;
  },

  windChime: () => `
    <path d="M 100 22 v 14" stroke="${P.woodDeep}" stroke-width="4.6" stroke-linecap="round"/>
    <ellipse cx="100" cy="46" rx="42" ry="11" fill="${P.woodDeep}"/>
    <ellipse cx="100" cy="42" rx="42" ry="11" fill="${P.woodLight}"/>
    ${[[66, 82, P.lavender], [86, 100, P.pondBlue], [114, 94, P.sunshine], [134, 78, P.peach]].map(([x, top, c]) => `
      <path d="M ${x} 48 v ${R(top - 48)}" stroke="${P.sand300}" stroke-width="2.6" opacity="0.85"/>
      <rect x="${x - 6.4}" y="${top}" width="13" height="42" rx="6.5" fill="${c}"/>
      <rect x="${x - 6.4}" y="${top}" width="4.6" height="42" rx="2.3" fill="#FFFFFF" opacity="0.35"/>`).join('')}
    <path d="M 100 48 v 78" stroke="${P.sand300}" stroke-width="2.6" opacity="0.85"/>
    ${g('translate(100 138) scale(0.72)', `<path d="${pad(0, 0, 30, { notch: 90, spread: 22 })}" fill="url(#padGreenLight)"/>`)}`,

  birdhouse: () => `
    <rect x="92" y="122" width="16" height="60" rx="8" fill="url(#woodGradV)"/>
    <path d="M 44 80 q 0 -12 14 -12 h 84 q 14 0 14 12 v 44 q 0 12 -14 12 h -84 q -14 0 -14 -12 Z" fill="url(#woodGrad)"/>
    <path d="M 100 24 L 176 76 q 10 6 -4 6 H 28 q -14 0 -4 -6 Z" fill="url(#peachBall)"/>
    <path d="M 100 36 L 156 74 H 44 Z" fill="#FFFFFF" opacity="0.15"/>
    <circle cx="100" cy="98" r="20" fill="${P.woodDeep}"/>
    <circle cx="100" cy="96" r="14" fill="${P.night800}" opacity="0.5"/>
    <rect x="94" y="116" width="12" height="18" rx="6" fill="${P.woodDeep}"/>
    <ellipse cx="140" cy="128" rx="17" ry="15" fill="${P.sunshine}"/>
    <circle cx="150" cy="122" r="3.6" fill="${P.midnight}"/>
    <path d="M 156 128 q 12 -1 12 4 q -8 4 -12 0 Z" fill="${P.peach}"/>
    <path d="M 128 136 q -12 6 -16 12" stroke="${P.sunshineBright}" stroke-width="7" stroke-linecap="round" fill="none"/>`,

  // Reads as a path now: overlapping rows that shrink and tighten with distance.
  pebblePath: () => `
    ${pebble(52, 152, 36, 15, { fill: 'url(#stoneGradCool)' })}
    ${pebble(122, 156, 40, 16, { fill: 'url(#stoneGrad)' })}
    ${pebble(84, 124, 32, 13, { fill: 'url(#stoneGrad)' })}
    ${pebble(140, 120, 28, 12, { fill: 'url(#stoneGradCool)' })}
    ${pebble(62, 98, 26, 11, { fill: 'url(#stoneGradCool)' })}
    ${pebble(112, 92, 24, 10, { fill: 'url(#stoneGrad)' })}
    ${pebble(88, 70, 19, 8, { fill: 'url(#stoneGrad)' })}
    ${pebble(126, 62, 15, 6.6, { fill: 'url(#stoneGradCool)' })}`,

  driftwood: () => `
    <ellipse cx="100" cy="148" rx="80" ry="12" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 18 118 q -4 -20 18 -26 q 18 -5 34 -3 q 34 -14 60 -2 q 30 -2 50 6 q 22 9 18 22 q -4 13 -26 15 q -34 3 -70 0 q -38 -3 -66 -8 q -16 -3 -18 -4 Z" fill="url(#woodGrad)"/>
    <path d="M 38 100 q 56 -10 122 6" stroke="${P.woodLight}" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.6"/>
    <path d="M 44 122 q 60 8 110 2" stroke="${P.woodDeep}" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.35"/>
    <ellipse cx="40" cy="108" rx="11" ry="15" fill="${P.woodDeep}" opacity="0.5"/>
    <g fill="${P.hopGreen}">
      <path d="M 118 96 q -4 -18 6 -26 q 8 10 4 26 Z"/>
      <ellipse cx="106" cy="88" rx="13" ry="7" transform="rotate(-28 106 88)"/>
      <ellipse cx="134" cy="90" rx="11" ry="6" transform="rotate(26 134 90)"/>
    </g>`,

  // One tapered trunk with real branches reaching into the canopy. Pass 1's
  // two-legged fork read as a slingshot.
  blossomTree: () => `
    <ellipse cx="100" cy="186" rx="60" ry="11" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 88 186 q -4 -56 4 -84 q 3 -12 8 -12 q 5 0 8 12 q 8 28 4 84 Z" fill="url(#woodGradV)"/>
    <g stroke="url(#woodGradV)" stroke-linecap="round" fill="none">
      <path d="M 98 116 q -16 -14 -30 -20" stroke-width="9"/>
      <path d="M 102 108 q 18 -14 32 -18" stroke-width="8"/>
      <path d="M 100 96 q -4 -18 -2 -28" stroke-width="7"/>
    </g>
    <circle cx="62" cy="80" r="34" fill="url(#blossomCloud)"/>
    <circle cx="138" cy="76" r="31" fill="url(#blossomCloud)"/>
    <circle cx="100" cy="50" r="40" fill="url(#blossomCloud)"/>
    <circle cx="76" cy="104" r="24" fill="url(#blossomCloud)"/>
    <circle cx="124" cy="102" r="22" fill="url(#blossomCloud)"/>
    <g fill="#FFFFFF" opacity="0.45">
      <circle cx="84" cy="34" r="13"/><circle cx="52" cy="66" r="10"/><circle cx="128" cy="62" r="9"/>
    </g>
    <g fill="${P.peach}" opacity="0.45">
      <circle cx="72" cy="56" r="5"/><circle cx="118" cy="44" r="4.4"/><circle cx="96" cy="86" r="4.4"/><circle cx="146" cy="94" r="4"/>
    </g>
    <g fill="${P.peachSoft}">
      <ellipse cx="152" cy="134" rx="7" ry="4.6" transform="rotate(28 152 134)"/>
      <ellipse cx="48" cy="142" rx="6" ry="4" transform="rotate(-24 48 142)"/>
      <ellipse cx="128" cy="164" rx="5.6" ry="3.6" transform="rotate(14 128 164)"/>
    </g>`,

  fireflies: () => {
    const fly = (x, y, r, o) => `<circle cx="${x}" cy="${y}" r="${R(r * 4)}" fill="url(#glowWarm)" opacity="${o}"/>
      <circle cx="${x}" cy="${y}" r="${R(r * 1.7)}" fill="${P.sunshine}" opacity="0.75"/>
      <circle cx="${x}" cy="${y}" r="${r}" fill="#FFFDF0"/>`;
    return `${fly(56, 60, 8, 0.95)}${fly(134, 44, 6, 0.85)}${fly(96, 106, 9.4, 1)}
      ${fly(152, 126, 6.6, 0.9)}${fly(48, 148, 5.4, 0.8)}${fly(114, 166, 4.6, 0.7)}
`;
  },

  // A moon *on the water*: a pale disc broken into ripple bands. Pass 1 used
  // bare cream on cream and vanished; the blue rim is what makes it read.
  moonReflection: () => `
    <ellipse cx="100" cy="104" rx="84" ry="76" fill="url(#moonGlow)"/>
    <ellipse cx="100" cy="104" rx="62" ry="54" fill="${P.sunshineSoft}" opacity="0.42"/>
    <g fill="#FFFDF0">
      <path d="M 52 56 q 48 -14 96 0 q -48 16 -96 0 Z" opacity="0.9"/>
      <path d="M 34 88 q 66 -19 132 0 q -66 19 -132 0 Z" opacity="0.95"/>
      <path d="M 44 120 q 56 -16 112 0 q -56 17 -112 0 Z" opacity="0.85"/>
      <path d="M 62 150 q 38 -11 76 0 q -38 12 -76 0 Z" opacity="0.7"/>
    </g>
    <g fill="${P.pondBlueLight}" opacity="0.55">
      <path d="M 40 72 q 60 -12 120 0 q -60 6 -120 0 Z"/>
      <path d="M 36 104 q 64 -12 128 0 q -64 6 -128 0 Z"/>
      <path d="M 52 136 q 48 -10 96 0 q -48 6 -96 0 Z"/>
    </g>`,

  pondSwing: () => `
    <path d="M 14 34 q 46 -26 96 -18 q 44 7 76 -4" stroke="url(#woodGrad)" stroke-width="13" stroke-linecap="round" fill="none"/>
    <g fill="${P.hopGreen}" opacity="0.9">
      <ellipse cx="30" cy="22" rx="15" ry="8" transform="rotate(-24 30 22)"/>
      <ellipse cx="72" cy="12" rx="14" ry="7.4" transform="rotate(-10 72 12)"/>
      <ellipse cx="150" cy="14" rx="14" ry="7.4" transform="rotate(14 150 14)"/>
      <ellipse cx="182" cy="24" rx="12" ry="6.6" transform="rotate(24 182 24)"/>
    </g>
    <path d="M 62 26 v 100" stroke="${P.sand300}" stroke-width="6" stroke-linecap="round"/>
    <path d="M 140 22 v 104" stroke="${P.sand300}" stroke-width="6" stroke-linecap="round"/>
    <rect x="44" y="124" width="114" height="24" rx="12" fill="url(#woodGrad)"/>
    <rect x="44" y="124" width="114" height="9" rx="4.5" fill="${P.woodLight}" opacity="0.65"/>
    <ellipse cx="101" cy="164" rx="46" ry="7" fill="${P.midnight}" opacity="0.08"/>`,
};

/** Mirrors PondCatalog.placement — used only to composite the review preview. */
const PLACEMENT = {
  lilyPadSmall: [0.46, 0.640, 1.00], reedsLeft: [0.13, 0.600, 1.00], fishOrange: [0.66, 0.710, 0.90],
  cloudPuff: [0.74, 0.110, 1.00], flowerYellow: [0.26, 0.830, 0.85], lilyPadLarge: [0.59, 0.570, 1.10],
  reedsRight: [0.87, 0.580, 1.00], stoneSmall: [0.19, 0.760, 0.80], tadpoleFriend: [0.40, 0.740, 0.75],
  flowerPink: [0.78, 0.830, 0.85], butterflyBlue: [0.30, 0.550, 0.80], lilyFlower: [0.49, 0.585, 0.70],
  cattails: [0.08, 0.700, 1.00], fishBlue: [0.72, 0.660, 0.85], sunbeam: [0.22, 0.090, 1.00],
  mushroomCluster: [0.33, 0.880, 0.80], snail: [0.65, 0.870, 0.60], frogFriendGreen: [0.44, 0.620, 1.00],
  butterflyYellow: [0.70, 0.520, 0.80], flowerPurple: [0.90, 0.740, 0.85], rainbow: [0.50, 0.160, 1.00],
  stoneStack: [0.11, 0.840, 0.90], dragonfly: [0.52, 0.500, 0.70], waterLilyCluster: [0.28, 0.680, 1.00],
  duckling: [0.62, 0.790, 0.80], fernPatch: [0.16, 0.380, 1.00], ladybug: [0.24, 0.900, 0.50],
  signpost: [0.80, 0.900, 0.90], lantern: [0.86, 0.460, 0.80], turtleRock: [0.38, 0.550, 0.90],
  birdhouse: [0.82, 0.320, 0.90], pebblePath: [0.48, 0.900, 1.20], frogFriendBlue: [0.60, 0.545, 1.00],
  driftwood: [0.06, 0.500, 0.90], blossomTree: [0.10, 0.280, 1.30], windChime: [0.16, 0.400, 0.70],
  clubhouse: [0.50, 0.330, 1.20], pondSwing: [0.28, 0.520, 1.10], starLantern: [0.68, 0.400, 0.80],
  fireflies: [0.86, 0.660, 0.90], moonReflection: [0.52, 0.800, 1.00],
};
/** Draw order by PondLayer, so the preview stacks the way the app will. */
const ITEM_LAYER = {
  sky: ['cloudPuff', 'sunbeam', 'rainbow'],
  backdrop: ['fernPatch', 'birdhouse', 'blossomTree', 'clubhouse'],
  water: ['lilyPadSmall', 'fishOrange', 'lilyPadLarge', 'tadpoleFriend', 'lilyFlower', 'fishBlue',
    'waterLilyCluster', 'duckling', 'turtleRock', 'moonReflection'],
  shore: ['reedsLeft', 'flowerYellow', 'reedsRight', 'stoneSmall', 'flowerPink', 'cattails',
    'mushroomCluster', 'snail', 'flowerPurple', 'stoneStack', 'signpost', 'pebblePath', 'driftwood'],
  decoration: ['lantern', 'windChime', 'pondSwing', 'starLantern'],
  character: ['frogFriendGreen', 'frogFriendBlue'],
  foreground: ['butterflyBlue', 'butterflyYellow', 'dragonfly', 'ladybug', 'fireflies'],
};

function placeItem(id) {
  const [x, y, s] = PLACEMENT[id];
  const k = (s * ITEM_SPAN) / 200;
  return g(`translate(${R(x * SCENE_W)} ${R(y * SCENE_H)}) scale(${R(k)}) translate(-100 -100)`, ITEMS[id]());
}

// ===========================================================================
// 2. ROUTINE STEP ILLUSTRATIONS  (640 x 480)
// ===========================================================================
const SW = 640, SH = 480;

/** The shared bathroom set.
 *
 *  The wall is deliberately tinted rather than white: every subject in this set
 *  is porcelain or paper, and pass 1 put white objects on a white wall, which
 *  left the potty and the toilet as vague pale blobs. The tint is the figure /
 *  ground contrast the whole set depends on.
 */
function bathroom({ floorY = 356, wall = P.pondBlueSoft, floor = P.sand100 } = {}) {
  return `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="${wall}"/>
    <circle cx="118" cy="104" r="80" fill="#FFFFFF" opacity="0.45"/>
    <circle cx="556" cy="82" r="54" fill="${P.sunshineSoft}" opacity="0.75"/>
    <rect x="0" y="${floorY}" width="${SW}" height="${SH - floorY}" fill="${floor}"/>
    <rect x="0" y="${floorY - 10}" width="${SW}" height="14" rx="7" fill="${P.sand200}"/>`;
}
const contactShadow = (cx, cy, rx, ry = rx * 0.2) =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${R(ry)}" fill="url(#softShadow)"/>`;

/** The child-height potty: a low bowl, a seat ring you can see the hole in,
 *  and a rounded back rest. Each part is a different tone so it reads as an
 *  object rather than a green mass. */
function pottyChair(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 4, 128, 22)}
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

/** A grown-up toilet, three-quarter view. Shared by Flush and the quiz icon. */
function toilet(cx, baseY, s = 1, { lidOpen = true } = {}) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 4, 126, 22)}
    <path d="M -58 0 q -22 0 -18 -24 l 20 -116 h 102 l 20 116 q 4 24 -18 24 Z" fill="url(#porcelainSide)"/>
    <path d="M -58 0 q -22 0 -18 -24 l 20 -116 h 34 l -16 140 Z" fill="#FFFFFF" opacity="0.4"/>
    <path d="M 54 -320 q 0 -22 22 -22 h 68 q 22 0 22 22 v 128 q 0 20 -22 20 h -68 q -22 0 -22 -20 Z" fill="${P.sand300}"/>
    <path d="M 50 -324 q 0 -22 22 -22 h 68 q 22 0 22 22 v 128 q 0 20 -22 20 h -68 q -22 0 -22 -20 Z" fill="url(#porcelainGrad)"/>
    <path d="M 50 -324 q 0 -22 22 -22 h 18 v 170 h -18 q -22 0 -22 -20 Z" fill="#FFFFFF" opacity="0.45"/>
    <rect x="74" y="-310" width="34" height="14" rx="7" fill="${P.pondBlue}"/>
    <path d="M -96 -186 q 0 -28 32 -28 h 112 q 32 0 32 30 q 0 52 -88 52 q -88 0 -88 -54 Z" fill="url(#porcelainGrad)"/>
    <ellipse cx="-4" cy="-192" rx="96" ry="33" fill="${P.sand300}" opacity="0.8"/>
    <ellipse cx="-4" cy="-200" rx="96" ry="33" fill="url(#porcelainGrad)"/>
    <ellipse cx="-4" cy="-200" rx="72" ry="24" fill="${P.sand200}" opacity="0.7"/>
    <ellipse cx="-4" cy="-203" rx="72" ry="24" fill="${P.porcelainMid}"/>
    <ellipse cx="-4" cy="-203" rx="54" ry="17" fill="${P.pondBlueDeep}" opacity="0.5"/>
    <ellipse cx="-4" cy="-206" rx="54" ry="17" fill="${P.pondBlueLight}"/>
    <rect x="34" y="-236" width="46" height="14" rx="7" fill="${P.sand200}"/>`);
}

/** A hand: a rounded palm with four fingers and a thumb, drawn from the wrist
 *  at the origin. Used by Wash, High five and the quiz set. */
function hand(fill, shade) {
  return `
    <path d="M 0 0 q -10 -60 26 -80 q 38 -20 68 4 q 30 24 22 66 q -8 42 -58 44 q -48 2 -58 -34 Z" fill="${fill}"/>
    <rect x="-6" y="-94" width="25" height="52" rx="12.5" fill="${fill}"/>
    <rect x="23" y="-110" width="25" height="68" rx="12.5" fill="${fill}"/>
    <rect x="52" y="-106" width="25" height="64" rx="12.5" fill="${fill}"/>
    <rect x="80" y="-84" width="23" height="46" rx="11.5" fill="${fill}"/>
    <path d="M 16 -40 q 42 14 78 -6" stroke="${shade}" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.35"/>`;
}

// --- Props for the mini-game backdrops -------------------------------------
// These three scenes are *backdrops*: the app composites the live SwiftUI
// character and the interactive pieces (bubbles, lily pads, picture cards) on
// top of them. So every prop below is deliberately pushed to an edge and the
// middle of each frame is left open. A backdrop that competes with the pieces
// standing on it is a backdrop that has to be redrawn.

/** A towel folded over a wall rail. Anchored at the centre of the rail. */
function towelOnRail(cx, railY, s = 1) {
  return g(`translate(${cx} ${railY}) scale(${s})`, `
    <rect x="-52" y="0" width="104" height="12" rx="6" fill="${P.sand300}"/>
    <path d="M -38 5 h 76 q 8 0 8 10 v 56 q 0 8 -9 8 q -10 -10 -18 0 q -10 10 -20 0 q -10 -10 -18 0 q -9 7 -15 0 v -64 q 0 -10 8 -10 Z" fill="url(#towelGrad)"/>
    <path d="M -38 5 h 26 v 74 q -10 5 -19 -2 q -13 2 -13 -9 v -53 q 0 -10 8 -10 Z" fill="#FFFFFF" opacity="0.32"/>
    <rect x="-42" y="34" width="84" height="11" rx="5.5" fill="#FFFFFF" opacity="0.8"/>`);
}

/** A pump bottle of hand soap, standing on its base at the origin. */
function soapPump(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 3, 40, 8)}
    <path d="M -26 0 q -8 -58 26 -58 q 34 0 26 58 Z" fill="url(#lavenderBall)"/>
    <path d="M -26 0 q -8 -58 26 -58 q -14 24 -12 58 Z" fill="#FFFFFF" opacity="0.3"/>
    <rect x="-20" y="-34" width="40" height="13" rx="6.5" fill="#FFFFFF" opacity="0.55"/>
    <rect x="-11" y="-76" width="22" height="20" rx="7" fill="${P.sand400}"/>
    <path d="M 0 -82 h 20 q 9 0 9 9 v 7" stroke="${P.sand400}" stroke-width="10" fill="none" stroke-linecap="round"/>`);
}

/** A potted fern. The pot is peach so it stays warm against a cool wall. */
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

/** The bathroom door at the end of Potty Path: a little gabled porch with a
 *  lit arch window and a plaque, so the destination reads as *friendly* and as
 *  *the bathroom* rather than as a generic house. Anchored at the threshold. */
function friendlyDoor(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 20, 140, 24)}
    <path d="M -104 8 q 0 -14 14 -14 h 180 q 14 0 14 14 v 14 h -208 Z" fill="${P.sand200}"/>
    <path d="M -92 0 v -162 q 0 -14 14 -14 h 156 q 14 0 14 14 V 0 Z" fill="url(#woodGradV)"/>
    <path d="M 0 -278 L 126 -172 q 12 10 -4 10 H -122 q -16 0 -4 -10 Z" fill="url(#greenBall)"/>
    <path d="M 0 -252 L 94 -174 H -94 Z" fill="#FFFFFF" opacity="0.14"/>
    <path d="M -62 0 v -134 q 0 -62 62 -62 q 62 0 62 62 V 0 Z" fill="url(#woodGrad)"/>
    <path d="M -50 0 v -130 q 0 -50 50 -50 q 50 0 50 50 V 0 Z" fill="${P.woodLight}" opacity="0.45"/>
    <path d="M -28 -128 q 0 -32 28 -32 q 28 0 28 32 v 24 q 0 8 -8 8 h -40 q -8 0 -8 -8 Z" fill="${P.sunshineSoft}"/>
    <path d="M -28 -128 q 0 -32 28 -32 q -13 12 -13 32 v 32 h -7 q -8 0 -8 -8 Z" fill="#FFFFFF" opacity="0.55"/>
    <path d="M -28 -112 h 56 M 0 -160 v 64" stroke="${P.woodDeep}" stroke-width="5" opacity="0.5"/>
    <circle cx="36" cy="-62" r="9" fill="${P.sunshineBright}"/>
    <g transform="translate(0 -56)">
      <rect x="-32" y="-16" width="64" height="34" rx="12" fill="${P.cloud}"/>
      ${g('translate(0 6) scale(0.09)', `
        <path d="M -104 -78 q 0 -22 22 -22 h 164 q 22 0 22 22 v 34 q 0 56 -104 56 q -104 0 -104 -56 Z" fill="url(#greenBall)"/>
        <ellipse cx="0" cy="-100" rx="112" ry="34" fill="url(#padGreenLight)"/>
        <ellipse cx="0" cy="-102" rx="62" ry="17" fill="${P.pondBlueSoft}"/>
        <path d="M -96 -108 q -14 -66 34 -66 h 124 q 48 0 34 66 q -96 -20 -192 0 Z" fill="url(#greenBall)"/>`)}
    </g>`);
}

/** A counter-top basin: a rim, a well you can see into, and a wall-mounted
 *  gooseneck tap running into it. */
function basinAndTap(cx, rimY, s = 1) {
  return g(`translate(${cx} ${rimY}) scale(${s})`, `
    <path d="M 92 6 V -58 q 0 -40 -48 -40 h -50 v 18" stroke="${P.sand300}" stroke-width="22" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 92 6 V -58 q 0 -40 -48 -40 h -50 v 18" stroke="${P.sand200}" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="88" y="-58" width="48" height="15" rx="7.5" fill="${P.sand400}"/>
    <circle cx="140" cy="-50" r="11" fill="${P.sand300}"/>
    <circle cx="137" cy="-53" r="5" fill="#FFFFFF" opacity="0.6"/>
    <path d="M -6 -74 q -4 40 -2 66" stroke="url(#waterStream)" stroke-width="26" stroke-linecap="round" fill="none"/>
    <path d="M -12 -62 q -3 30 -2 46" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" fill="none" opacity="0.5"/>
    <ellipse cx="0" cy="10" rx="124" ry="36" fill="${P.sand300}" opacity="0.75"/>
    <ellipse cx="0" cy="0" rx="124" ry="36" fill="url(#porcelainGrad)"/>
    <ellipse cx="0" cy="2" rx="96" ry="26" fill="${P.porcelainShade}"/>
    <ellipse cx="0" cy="4" rx="92" ry="24" fill="${P.pondBlueLight}"/>
    <ellipse cx="0" cy="11" rx="76" ry="16" fill="${P.pondBlue}" opacity="0.35"/>
    <ellipse cx="-34" cy="-5" rx="40" ry="9" fill="#FFFFFF" opacity="0.6"/>`);
}

const scenes = {
  'routine-try': () => `
    ${bathroom()}
    <rect x="428" y="150" width="150" height="126" rx="24" fill="#FFFFFF" opacity="0.75"/>
    <path d="M 503 150 v 126 M 428 213 h 150" stroke="${P.pondBlueSoft}" stroke-width="9"/>
    <ellipse cx="330" cy="428" rx="200" ry="30" fill="${P.lavenderSoft}"/>
    ${pottyChair(348, 400, 1)}
    ${g('translate(122 404) scale(0.47) translate(-256 -440)', `
      ${hopBody({ squash: 0.05 })}${hopSheen}
      ${hopArm(122, 334, 150)}${hopArm(392, 342, 34)}
      ${hopBelly()}${hopFoot(198, 438)}${hopFoot(320, 438, -1)}
      ${hopEyes({ gaze: [16, 6] })}${hopCheeks()}${hopMouth({ smile: 0.9 })}`)}`,

  'routine-wipe': () => `
    ${bathroom()}
    <rect x="128" y="120" width="344" height="22" rx="11" fill="${P.sand300}"/>
    <rect x="138" y="142" width="18" height="44" rx="9" fill="${P.sand300}"/>
    <rect x="446" y="142" width="18" height="44" rx="9" fill="${P.sand300}"/>
    <rect x="180" y="146" width="240" height="16" rx="8" fill="${P.sand200}"/>
    ${contactShadow(300, 430, 150, 24)}
    <path d="M 300 258 q 96 -8 96 84 q 0 62 -18 106 q -44 12 -84 -6 q 22 -60 6 -184 Z" fill="${P.sand100}"/>
    <path d="M 300 258 q 96 -8 96 84 q 0 62 -18 106 q -20 5 -40 3 q 26 -66 20 -122 q -6 -58 -58 -71 Z" fill="#FFFFFF" opacity="0.75"/>
    <path d="M 296 440 q 40 14 82 2" stroke="${P.sand200}" stroke-width="8" fill="none" stroke-linecap="round"/>
    <circle cx="300" cy="256" r="96" fill="url(#porcelainGrad)"/>
    <circle cx="300" cy="256" r="96" fill="none" stroke="${P.sand200}" stroke-width="5"/>
    <circle cx="300" cy="256" r="40" fill="${P.sand200}"/>
    <circle cx="300" cy="256" r="27" fill="${P.sand100}"/>
    <circle cx="272" cy="222" r="34" fill="#FFFFFF" opacity="0.7"/>
    <g opacity="0.45">
      <circle cx="546" cy="252" r="12" fill="${P.lavender}"/>
      <circle cx="574" cy="294" r="8" fill="${P.pondBlue}"/>
      <circle cx="530" cy="304" r="6" fill="${P.peach}"/>
    </g>`,

  'routine-flush': () => `
    ${bathroom()}
    ${toilet(324, 432, 1.02)}
    <g>
      <path d="M 320 228 m -62 0 a 62 27 0 1 1 90 23" fill="none" stroke="${P.pondBlueDeep}" stroke-width="16" stroke-linecap="round" opacity="0.85"/>
      <path d="M 320 242 m -39 0 a 39 17 0 1 1 58 15" fill="none" stroke="${P.pondBlue}" stroke-width="14" stroke-linecap="round"/>
      <path d="M 320 254 m -18 0 a 18 8 0 1 1 28 7" fill="none" stroke="${P.pondBlueLight}" stroke-width="11" stroke-linecap="round"/>
      <circle cx="232" cy="188" r="12" fill="${P.pondBlueLight}" opacity="0.85"/>
      <circle cx="404" cy="208" r="9" fill="${P.pondBlueLight}" opacity="0.75"/>
      <circle cx="376" cy="162" r="7" fill="${P.pondBlue}" opacity="0.6"/>
      <circle cx="264" cy="150" r="5.4" fill="${P.pondBlue}" opacity="0.5"/>
    </g>`,

  'routine-wash': () => `
    ${bathroom({ floorY: 446 })}
    <path d="M 262 214 v -54 q 0 -34 -34 -34 h -78" stroke="${P.sand300}" stroke-width="26" fill="none" stroke-linecap="round"/>
    <path d="M 262 214 v -54 q 0 -34 -34 -34 h -78" stroke="${P.sand200}" stroke-width="14" fill="none" stroke-linecap="round"/>
    <rect x="112" y="108" width="52" height="30" rx="15" fill="${P.pondBlue}"/>
    <rect x="238" y="208" width="48" height="30" rx="12" fill="${P.sand300}"/>
    <path d="M 262 238 q -8 76 -4 122" stroke="url(#waterStream)" stroke-width="34" stroke-linecap="round" fill="none"/>
    <path d="M 254 250 q -6 60 -4 96" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" fill="none" opacity="0.55"/>
    ${g('translate(196 396) rotate(-14) scale(0.86)', hand('url(#handGrad)', P.handDeep))}
    ${g('translate(392 404) scale(-1 1) rotate(-16) scale(0.86)', hand('url(#handGradDeep)', P.peachDeep))}
    <g>
      <circle cx="176" cy="288" r="26" fill="url(#bubbleFill)"/>
      <circle cx="386" cy="252" r="21" fill="url(#bubbleFill)"/>
      <circle cx="446" cy="330" r="29" fill="url(#bubbleFill)"/>
      <circle cx="140" cy="352" r="18" fill="url(#bubbleFill)"/>
      <circle cx="424" cy="402" r="15" fill="url(#bubbleFill)"/>
      <circle cx="330" cy="196" r="13" fill="url(#bubbleFill)"/>
      <circle cx="104" cy="252" r="11" fill="url(#bubbleFill)"/>
    </g>`,

  'routine-highFive': () => `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="${P.hopGreenSoft}"/>
    <circle cx="320" cy="236" r="182" fill="#FFFFFF" opacity="0.6"/>
    <circle cx="320" cy="228" r="104" fill="url(#glowWarm)"/>
    ${g('translate(196 386) rotate(30) scale(0.94)', hand('url(#handGrad)', P.handDeep))}
    ${g('translate(444 386) scale(-1 1) rotate(30) scale(0.94)', hand(HOP.bodyMid, HOP.bodyShadow))}
    <g fill="#FFFFFF" opacity="0.85">
      <circle cx="320" cy="206" r="16"/><circle cx="280" cy="182" r="10"/><circle cx="362" cy="186" r="11"/>
      <circle cx="304" cy="164" r="6"/><circle cx="342" cy="158" r="7"/>
    </g>
    <g fill="${P.sunshine}">
      ${[[142, 118, 21], [500, 128, 18], [320, 54, 23], [104, 258, 14], [540, 262, 15], [232, 74, 12], [412, 86, 13]]
        .map(([x, y, r]) => `<path d="M ${x} ${y - r} q ${R(r * 0.28)} ${R(r * 0.72)} ${r} ${r} q ${R(-r * 0.72)} ${R(r * 0.28)} ${-r} ${r} q ${R(-r * 0.28)} ${R(-r * 0.72)} ${-r} ${-r} q ${R(r * 0.72)} ${R(-r * 0.28)} ${r} ${-r} Z"/>`).join('')}
    </g>`,

  // --- Mini-game backdrops -------------------------------------------------
  // Hop is deliberately absent from all three. The app composites the live
  // SwiftUI character over these, and a second, painted Hop in the backdrop
  // would read as a twin standing behind him.

  /** Bubble Wash: the basin the scrubbing happens over. Props hug the counter
   *  and the two side walls so the upper middle stays open for bubbles. */
  'games-bubbleWash': () => `
    ${bathroom({ floorY: 430 })}
<path d="M 88 352 h 464 v 78 h -464 Z" fill="url(#woodGradV)"/>
    <rect x="104" y="364" width="186" height="66" rx="12" fill="${P.woodLight}" opacity="0.5"/>
    <rect x="350" y="364" width="186" height="66" rx="12" fill="${P.woodLight}" opacity="0.5"/>
    <circle cx="278" cy="392" r="6.5" fill="${P.sand200}"/>
    <circle cx="362" cy="392" r="6.5" fill="${P.sand200}"/>
    <rect x="52" y="320" width="536" height="32" rx="16" fill="${P.sand300}"/>
    <rect x="52" y="316" width="536" height="32" rx="16" fill="url(#porcelainGrad)"/>
    ${towelOnRail(556, 168, 0.9)}
    ${soapPump(126, 320, 0.85)}
    ${basinAndTap(300, 318, 1)}
    <g>
      <circle cx="196" cy="212" r="34" fill="url(#bubbleFill)"/>
      <circle cx="106" cy="252" r="22" fill="url(#bubbleFill)"/>
      <circle cx="452" cy="216" r="27" fill="url(#bubbleFill)"/>
      <circle cx="504" cy="288" r="18" fill="url(#bubbleFill)"/>
      <circle cx="206" cy="120" r="16" fill="url(#bubbleFill)"/>
      <circle cx="392" cy="148" r="13" fill="url(#bubbleFill)"/>
      <circle cx="268" cy="64" r="11" fill="url(#bubbleFill)"/>
      <circle cx="592" cy="238" r="14" fill="url(#bubbleFill)"/>
    </g>`,

  /** Potty Path: the world the lily-pad grid is laid over. The middle of the
   *  frame is lawn and sky on purpose — the pads land there. */
  'games-pottyPath': () => `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="url(#skyWarm)"/>
    <circle cx="84" cy="68" r="78" fill="url(#sunGlow)" opacity="0.8"/>
    <circle cx="84" cy="68" r="34" fill="url(#sunDisc)"/>
    ${cloud(272, 62, 112, { opacity: 0.7 })}
    ${cloud(524, 40, 86, { opacity: 0.5 })}
    <path d="M -20 218 Q 130 162 300 202 Q 460 240 660 196 L 660 500 L -20 500 Z" fill="url(#hillFar)"/>
    <path d="M -20 270 Q 170 218 360 264 Q 520 302 660 256 L 660 500 L -20 500 Z" fill="url(#hillMid)"/>
    <path d="M -20 316 Q 200 286 420 320 Q 550 340 660 316 L 660 500 L -20 500 Z" fill="url(#ground)"/>
    ${friendlyDoor(496, 322, 0.46)}
    <path d="M 26 492 Q 96 424 214 384 Q 340 342 452 326 L 496 320 L 496 342 Q 370 362 258 402 Q 152 444 122 492 Z" fill="url(#shoreSand)" opacity="0.92"/>
    ${pebble(206, 390, 21, 8)}
    ${pebble(306, 366, 17, 7)}
    ${pebble(396, 344, 14, 6)}
    ${g('translate(80 424)', `
      ${contactShadow(0, 4, 34, 8)}
      <rect x="-6" y="-66" width="12" height="68" rx="6" fill="url(#woodGradV)"/>
      <path d="M -40 -100 h 60 l 18 15 l -18 15 h -60 q -9 0 -9 -9 v -12 q 0 -9 9 -9 Z" fill="url(#greenBall)"/>
      <path d="M -40 -100 h 28 v 30 h -28 q -9 0 -9 -9 v -12 q 0 -9 9 -9 Z" fill="#FFFFFF" opacity="0.22"/>
      <path d="M -26 -85 h 26 M -8 -95 l 11 10 l -11 10" stroke="${P.cloud}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`)}
    ${pebble(26, 462, 16, 8)}
    ${pebble(150, 470, 13, 6.5)}
    <g fill="${P.hopGreenInk}" opacity="0.2">
      <path d="${blade(24, 424, 62, 16, 10)}"/><path d="${blade(52, 430, 44, -12, 8)}"/>
      <path d="${blade(624, 452, 68, -18, 11)}"/><path d="${blade(596, 458, 48, 14, 9)}"/>
      <path d="${blade(470, 470, 42, -12, 8)}"/><path d="${blade(556, 400, 38, 12, 8)}"/>
      <path d="${blade(228, 470, 46, 14, 9)}"/><path d="${blade(198, 476, 32, -10, 7)}"/>
    </g>
    ${g('translate(546 462) scale(0.34)', `${frond(150, -48)}${frond(160, 44)}${frond(148, -2)}`)}
    ${flower(30, 398, 19, { fill: 'url(#yellowBall)', core: P.sunshineSoft, stemH: 34 })}
    ${flower(580, 396, 18, { fill: 'url(#peachBall)', core: P.peachSoft, petals: 6, stemH: 32 })}
    ${g('translate(404 206) scale(0.46)', `
      ${butterflyHalf(P.lavender, P.lavenderSoft, '#FFFFFF')}
      ${g('scale(-1 1)', butterflyHalf(P.lavender, P.lavenderSoft, '#FFFFFF'))}
      <ellipse cx="0" cy="4" rx="5" ry="28" fill="${P.night600}" opacity="0.8"/>
      <circle cx="0" cy="-26" r="7.4" fill="${P.night600}" opacity="0.8"/>`)}`,

  /** Bathroom Match: a quiet room. Everything sits on the two side walls or on
   *  the floor, so the two columns of picture cards have the whole middle. */
  'games-bathroomMatch': () => `
    ${bathroom({ floorY: 392, wall: P.lavenderSoft })}
    <rect x="0" y="300" width="${SW}" height="82" fill="#FFFFFF" opacity="0.5"/>
    <rect x="0" y="292" width="${SW}" height="13" rx="6" fill="${P.sand300}"/>
    <g stroke="${P.lavenderDeep}" stroke-width="3" opacity="0.22" stroke-linecap="round">
      <path d="M 0 341 h ${SW}"/>
      <path d="M 80 306 v 35 M 240 306 v 35 M 400 306 v 35 M 560 306 v 35"/>
      <path d="M 160 343 v 37 M 320 343 v 37 M 480 343 v 37"/>
    </g>
    <circle cx="118" cy="104" r="74" fill="${P.pondBlueSoft}" opacity="0.75"/>
    <circle cx="118" cy="104" r="80" fill="none" stroke="${P.sand300}" stroke-width="14"/>
    <path d="M 78 56 a 78 78 0 0 0 -28 60" stroke="#FFFFFF" stroke-width="13" fill="none" stroke-linecap="round" opacity="0.8"/>
    <rect x="0" y="262" width="170" height="13" rx="6" fill="${P.sand300}"/>
    <path d="M 30 275 v 18 M 138 275 v 18" stroke="${P.sand400}" stroke-width="7" stroke-linecap="round"/>
    <g>
      <rect x="18" y="246" width="84" height="16" rx="8" fill="url(#towelGrad)"/>
      <rect x="24" y="230" width="72" height="16" rx="8" fill="${P.peachSoft}"/>
      <rect x="30" y="214" width="60" height="16" rx="8" fill="${P.sunshineSoft}"/>
      <path d="M 22 254 h 76" stroke="#FFFFFF" stroke-width="3" opacity="0.6" stroke-linecap="round"/>
    </g>
    ${soapPump(136, 262, 0.55)}
    ${towelOnRail(560, 172, 1.06)}
    ${pottedPlant(578, 398, 0.78)}
    ${contactShadow(320, 438, 178, 30)}
    <rect x="168" y="404" width="304" height="56" rx="28" fill="${P.peach}" opacity="0.55"/>
    <rect x="182" y="414" width="276" height="36" rx="18" fill="${P.peachSoft}"/>
    <path d="M 214 422 h 212 M 214 442 h 212" stroke="${P.peach}" stroke-width="6" opacity="0.38" stroke-linecap="round"/>
    <g stroke="${P.peachDeep}" stroke-width="4" opacity="0.38" stroke-linecap="round">
      <path d="M 180 402 v -9 M 216 402 v -9 M 252 402 v -9 M 288 402 v -9 M 324 402 v -9 M 360 402 v -9 M 396 402 v -9 M 432 402 v -9 M 462 402 v -9"/>
    </g>`,
};

// ===========================================================================
// 3. SHIELD HERO  (1200 x 700)
// ===========================================================================
function shieldHero() {
  const W = 1200, H = 700;
  const door = g('translate(880 470) scale(1.05)', `
    ${contactShadow(0, 26, 150, 24)}
    <path d="M -108 10 q 0 -14 14 -14 h 188 q 14 0 14 14 v 14 h -216 Z" fill="${P.sand200}"/>
    <path d="M -96 0 v -170 q 0 -14 14 -14 h 164 q 14 0 14 14 V 0 Z" fill="url(#woodGradV)"/>
    <path d="M 0 -286 L 128 -178 q 12 10 -4 10 H -124 q -16 0 -4 -10 Z" fill="url(#greenBall)"/>
    <path d="M 0 -262 L 96 -180 H -96 Z" fill="#FFFFFF" opacity="0.13"/>
    <path d="M -64 0 v -140 q 0 -64 64 -64 q 64 0 64 64 V 0 Z" fill="url(#woodGrad)"/>
    <path d="M -52 0 v -136 q 0 -52 52 -52 q 52 0 52 52 V 0 Z" fill="${P.woodLight}" opacity="0.45"/>
    <path d="M -30 -136 q 0 -34 30 -34 q 30 0 30 34 v 26 q 0 8 -8 8 h -44 q -8 0 -8 -8 Z" fill="${P.sunshineSoft}"/>
    <path d="M -30 -136 q 0 -34 30 -34 q -14 12 -14 34 v 34 h -8 q -8 0 -8 -8 Z" fill="#FFFFFF" opacity="0.55"/>
    <path d="M -30 -118 h 60 M 0 -170 v 68" stroke="${P.woodDeep}" stroke-width="5" opacity="0.55"/>
    <circle cx="36" cy="-66" r="9" fill="${P.sunshineBright}"/>
    <path d="M -62 -6 h 124" stroke="${P.woodDeep}" stroke-width="6" opacity="0.35"/>`);

  const body = `
    <rect x="0" y="0" width="${W}" height="${H}" fill="url(#skyWarm)"/>
    <circle cx="196" cy="132" r="120" fill="url(#sunGlow)" opacity="0.75"/>
    <circle cx="196" cy="132" r="54" fill="url(#sunDisc)"/>
    ${cloud(430, 118, 168, { opacity: 0.75 })}
    ${cloud(1010, 156, 140, { opacity: 0.6 })}
    ${cloud(700, 92, 110, { opacity: 0.45 })}
    <path d="M -20 372 Q 210 268 480 340 Q 720 402 940 336 Q 1090 292 1220 344 L 1220 720 L -20 720 Z" fill="url(#hillFar)"/>
    <path d="M -20 430 Q 260 356 540 420 Q 800 478 1220 404 L 1220 720 L -20 720 Z" fill="url(#hillMid)"/>
    <path d="M -20 500 Q 300 452 640 500 Q 940 542 1220 486 L 1220 720 L -20 720 Z" fill="url(#ground)"/>
    <path d="M 120 720 Q 260 600 470 548 Q 640 506 900 494 L 980 494 Q 700 528 560 576 Q 400 632 340 720 Z" fill="url(#shoreSand)" opacity="0.95"/>
    ${[[300, 664, 30], [392, 620, 26], [486, 588, 22], [578, 562, 19], [664, 542, 16], [752, 526, 14]]
      .map(([x, y, r]) => pebble(x, y, r, r * 0.42, { fill: 'url(#stoneGrad)', light: 0.6 })).join('')}
    ${door}
    ${contactShadow(430, 636, 150, 26)}
    ${g('translate(430 636) rotate(-3) scale(0.66) translate(-256 -440)', `
      ${hopBody({ squash: 0.05 })}
      ${hopSheen}
      ${hopArm(126, 342, 128)}${hopArm(390, 330, 22, 60)}
      ${hopBelly()}
      ${hopFoot(202, 444, 1, 18)}${hopFoot(332, 436, -1)}
      ${hopEyes({ gaze: [26, 5] })}
      ${hopCheeks()}
      ${hopMouth({ open: 0.35 })}`)}
    <g fill="${P.hopGreenInk}" opacity="0.2">
      <path d="${blade(70, 700, 96, 24, 14)}"/><path d="${blade(120, 706, 70, -18, 11)}"/>
      <path d="${blade(1140, 692, 100, -24, 14)}"/><path d="${blade(1088, 698, 72, 18, 11)}"/>
    </g>
    ${flower(200, 604, 26, { fill: 'url(#yellowBall)', core: P.sunshineSoft, stemH: 46 })}
    ${flower(1010, 640, 24, { fill: 'url(#peachBall)', core: P.peachSoft, petals: 6, stemH: 44 })}
    ${g('translate(646 330) scale(0.72)', `
      ${butterflyHalf(P.lavender, P.lavenderSoft, '#FFFFFF')}
      ${g('scale(-1 1)', butterflyHalf(P.lavender, P.lavenderSoft, '#FFFFFF'))}
      <ellipse cx="0" cy="4" rx="5" ry="28" fill="${P.night600}" opacity="0.8"/>
      <circle cx="0" cy="-26" r="7.4" fill="${P.night600}" opacity="0.8"/>`)}
    <ellipse cx="600" cy="700" rx="720" ry="90" fill="${P.hopGreenInk}" opacity="0.08"/>`;
  return svg({ viewBox: `0 0 ${W} ${H}`, width: W, height: H, body });
}

// ===========================================================================
// 4. QUIZ ANSWER ICONS  (120 x 120)
// ===========================================================================
/** Every quiz icon sits on the same soft tinted disc: it lifts the subject off
 *  the Cloud background and makes the set read as one family at tile size. */
const disc = (tint) => `<circle cx="60" cy="60" r="58" fill="${tint}"/>`;

// ---------------------------------------------------------------------------
// Quiz answer-set primitives.
//
// The pictures in section 4 are alternatives to each other, not free-standing
// drawings: "front to back" only means anything beside "back to front", and
// "a few squares" only means anything beside "a giant pile". So everything a
// child must NOT read as the difference — the hand, the paper square, the
// arrow, the shadow — lives here once, and each icon inside an answer set
// varies exactly one thing.
// ---------------------------------------------------------------------------

/** Soft contact shadow in icon units, so a subject sits rather than floats. */
const iconShadow = (cx, cy, rx, ink = P.midnight, o = 0.11) =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${R(rx)}" ry="${R(rx * 0.17)}" fill="${ink}" opacity="${o}"/>`;

/** One bold arrow along a horizontal. `both` adds a second head, which is the
 *  only thing separating "side to side" from the two one-way answers — the
 *  direction set is deliberately three readings of one drawing. */
function arrow(x1, x2, y, { color = P.lavenderDeep, w = 13, head = 16, both = false } = {}) {
  const d = x2 > x1 ? 1 : -1;
  const headAt = (tip, dir) =>
    `<path d="M ${R(tip)} ${y} L ${R(tip - dir * head)} ${R(y - head)} L ${R(tip - dir * head)} ${R(y + head)} Z" fill="${color}"/>`;
  return `<path d="M ${R(both ? x1 + d * head : x1)} ${y} H ${R(x2 - d * head)}" stroke="${color}" stroke-width="${w}" stroke-linecap="round" fill="none"/>
    ${headAt(x2, d)}${both ? headAt(x1, -d) : ''}`;
}

/** A hand pinching a folded square of toilet paper, wrist at the origin and
 *  fingers pointing up. Shared by Wipe and all three direction answers, so a
 *  child comparing them can only be comparing the arrow. */
function wipeHand() {
  const fingers = [[-27, -68], [-13, -73], [1, -71], [15, -64]]
    .map(([x, top]) => `<rect x="${x}" y="${top}" width="13" height="${R(-top - 32)}" rx="6.5" fill="url(#handGrad)"/>`)
    .join('');
  return `
    <g transform="rotate(-7 0 -60)">
      <rect x="-40" y="-92" width="80" height="66" rx="9" fill="${P.sand300}" opacity="0.5"/>
      <rect x="-40" y="-96" width="80" height="66" rx="9" fill="url(#paperSheet)"/>
      <rect x="-40" y="-96" width="80" height="66" rx="9" fill="none" stroke="${P.sand200}" stroke-width="2"/>
      <path d="M -40 -63 h 80" stroke="${P.sand200}" stroke-width="3" fill="none"/>
      <path d="M 40 -96 h -19 l 19 19 Z" fill="${P.sand200}"/>
    </g>
    <rect x="-28" y="-48" width="56" height="58" rx="19" fill="url(#handGrad)"/>
    ${fingers}
    <g transform="rotate(30 -30 -40)"><rect x="-39" y="-62" width="17" height="36" rx="8.5" fill="url(#handGradDeep)"/></g>
    <path d="M -22 -36 q 24 8 46 -2" stroke="${P.handDeep}" stroke-width="3.6" fill="none" stroke-linecap="round" opacity="0.3"/>`;
}

/** The pair of open hands. Factored out of the Hands icon so Wash hands is the
 *  same hands under water rather than a second, subtly different pair. */
function handPair() {
  return [[34, 1], [86, -1]].map(([x, f]) => g(`translate(${x} 90) scale(${f} 1)`, `
      <path d="M -20 0 q -8 -34 6 -46 q 16 -14 30 -2 q 12 10 10 30 q -2 22 -22 22 q -20 0 -24 -4 Z" fill="url(#handGrad)"/>
      <rect x="-22" y="-56" width="13" height="26" rx="6.5" fill="url(#handGrad)"/>
      <rect x="-9" y="-62" width="13" height="32" rx="6.5" fill="url(#handGrad)"/>
      <rect x="4" y="-60" width="13" height="30" rx="6.5" fill="url(#handGrad)"/>
      <rect x="16" y="-50" width="12" height="22" rx="6" fill="url(#handGrad)"/>
      <path d="M -24 -34 q 22 8 42 -2" stroke="${P.handDeep}" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.4"/>`)).join('');
}

/** One sheet of toilet paper, drawn at a fixed unit. The three "how much"
 *  answers differ only in how many of these there are, so the comparison a
 *  child makes is a count and not a shape. */
const PAPER_UNIT = 30;
const paperSquares = (x, y, n) => `
    <rect x="${R(x)}" y="${R(y + 4)}" width="${R(PAPER_UNIT * n)}" height="${PAPER_UNIT}" rx="5" fill="${P.sand300}" opacity="0.5"/>
    <rect x="${R(x)}" y="${R(y)}" width="${R(PAPER_UNIT * n)}" height="${PAPER_UNIT}" rx="5" fill="url(#paperSheet)"/>
    <rect x="${R(x)}" y="${R(y)}" width="${R(PAPER_UNIT * n)}" height="${PAPER_UNIT}" rx="5" fill="none" stroke="${P.sand300}" stroke-width="2.4"/>
    ${Array.from({ length: n - 1 }, (_, i) =>
      `<path d="M ${R(x + PAPER_UNIT * (i + 1))} ${R(y + 4)} V ${R(y + PAPER_UNIT - 4)}" stroke="${P.sand400}" stroke-width="2.6" stroke-linecap="round" stroke-dasharray="3 5"/>`).join('')}`;

/** An eighth note, for "scrub for as long as a song". */
function musicNote(cx, cy, s, color) {
  return g(`translate(${cx} ${cy}) scale(${s})`, `
    <path d="M 4 16 V -20 q 0 -3 3 -4 l 17 -5 q 3 -1 3 2 v 9 q 0 3 -3 4 l -14 4 V 16 Z" fill="${color}"/>
    <ellipse cx="-4" cy="16" rx="11" ry="8.5" transform="rotate(-20 -4 16)" fill="${color}"/>`);
}

const quizIcons = {
  soap: () => `${disc(P.lavenderSoft)}
    <ellipse cx="60" cy="92" rx="34" ry="6" fill="${P.lavenderDeep}" opacity="0.14"/>
    <path d="M 26 78 q 0 -22 34 -22 q 34 0 34 22 v 4 q 0 8 -10 8 h -48 q -10 0 -10 -8 Z" fill="${P.lavenderDeep}"/>
    <path d="M 26 74 q 0 -24 34 -24 q 34 0 34 24 q 0 10 -34 10 q -34 0 -34 -10 Z" fill="url(#lavenderBall)"/>
    <ellipse cx="48" cy="62" rx="14" ry="6" fill="#FFFFFF" opacity="0.4"/>
    <circle cx="44" cy="32" r="11" fill="url(#bubbleFill)"/>
    <circle cx="72" cy="22" r="8" fill="url(#bubbleFill)"/>
    <circle cx="86" cy="42" r="6" fill="url(#bubbleFill)"/>`,

  hands: () => `${disc(P.peachSoft)}
    ${handPair()}`,

  toilet: () => `${disc(P.pondBlueSoft)}
    ${toilet(52, 108, 0.29, { lidOpen: false })}`,

  // Key is `icon.quiz.toiletPaper`, so the file must be `quiz-toiletPaper.svg`:
  // `HopIllustrationKey.assetName` drops the family and joins the rest with
  // hyphens, preserving case. Hyphenating the camelCase word here would emit
  // `quiz-toilet-paper.svg`, which no key resolves to.
  toiletPaper: () => `${disc(P.sunshineSoft)}
    <ellipse cx="60" cy="98" rx="30" ry="5" fill="${P.sunshineDeep}" opacity="0.12"/>
    <path d="M 42 34 h 30 q 20 0 20 22 v 34 q 0 12 -20 12 h -30 Z" fill="${P.porcelainMid}"/>
    <path d="M 72 34 q 20 0 20 22 v 34 q 0 12 -20 12 q -20 0 -20 -12 v -34 q 0 -22 20 -22 Z" fill="url(#porcelainGrad)"/>
    <ellipse cx="42" cy="61" rx="16" ry="27" fill="url(#porcelainGrad)"/>
    <ellipse cx="42" cy="61" rx="7" ry="12" fill="${P.sand200}"/>
    <ellipse cx="42" cy="61" rx="3.4" ry="6" fill="${P.sand300}"/>
    <path d="M 92 62 q 12 20 8 34 q -12 4 -20 -2 q 6 -16 2 -30 Z" fill="url(#porcelainGrad)"/>
    <path d="M 80 92 q 10 4 18 0" stroke="${P.sand200}" stroke-width="3" fill="none" stroke-linecap="round"/>`,

  towel: () => `${disc(P.pondBlueSoft)}
    <rect x="18" y="26" width="84" height="10" rx="5" fill="${P.sand300}"/>
    <path d="M 30 30 h 60 q 6 0 6 8 v 46 q 0 6 -7 6 q -8 -8 -14 0 q -8 8 -16 0 q -8 -8 -16 0 q -7 6 -13 0 v -52 q 0 -8 6 -8 Z" fill="url(#towelGrad)"/>
    <path d="M 30 30 h 22 v 62 q -8 4 -16 -2 q -12 2 -12 -8 v -44 q 0 -8 6 -8 Z" fill="#FFFFFF" opacity="0.32"/>
    <rect x="26" y="54" width="68" height="9" rx="4.5" fill="#FFFFFF" opacity="0.8"/>
    <path d="M 62 32 v 58" stroke="${P.pondBlueDeep}" stroke-width="2.6" opacity="0.18"/>`,

  tap: () => `${disc(P.pondBlueSoft)}
    <rect x="88" y="26" width="18" height="34" rx="8" fill="${P.sand400}"/>
    <path d="M 96 40 h -30 q -14 0 -14 16 v 8" stroke="${P.sand300}" stroke-width="15" fill="none" stroke-linecap="round"/>
    <path d="M 96 40 h -30 q -14 0 -14 16 v 8" stroke="${P.sand200}" stroke-width="7" fill="none" stroke-linecap="round"/>
    <rect x="42" y="60" width="20" height="11" rx="5" fill="${P.sand400}"/>
    <path d="M 52 72 v 28" stroke="${P.pondBlue}" stroke-width="19" stroke-linecap="round" fill="none"/>
    <path d="M 47 80 v 13" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.55"/>
    <circle cx="74" cy="90" r="9" fill="url(#bubbleFill)"/>
    <circle cx="88" cy="74" r="6.4" fill="url(#bubbleFill)"/>
    <circle cx="34" cy="86" r="6" fill="url(#bubbleFill)"/>`,

  snack: () => `${disc(P.peachSoft)}
    <ellipse cx="60" cy="100" rx="28" ry="5" fill="${P.peachInk}" opacity="0.12"/>
    <path d="M 60 40 q -34 -12 -34 26 q 0 36 24 36 q 10 0 10 -4 q 0 4 10 4 q 24 0 24 -36 q 0 -38 -34 -26 Z" fill="url(#peachBall)"/>
    <path d="M 44 44 q -12 8 -12 26" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.35"/>
    <path d="M 60 40 q 2 -14 -4 -20" stroke="${P.woodDeep}" stroke-width="6" fill="none" stroke-linecap="round"/>
    <path d="M 62 28 q 18 -14 26 0 q -14 14 -26 0 Z" fill="${P.hopGreen}"/>`,

  controller: () => `${disc(P.lavenderSoft)}
    <path d="M 30 54 q 6 -16 22 -16 h 16 q 16 0 22 16 l 12 26 q 8 18 -10 21 q -15 2 -21 -13 h -32 q -6 15 -21 13 q -18 -3 -10 -21 Z" fill="url(#lavenderBall)"/>
    <path d="M 30 54 q 6 -16 22 -16 h 16 q 16 0 22 16 q -30 -7 -60 0 Z" fill="#FFFFFF" opacity="0.22"/>
    <rect x="30" y="61" width="22" height="7" rx="3.5" fill="${P.cloud}"/>
    <rect x="37.5" y="53.5" width="7" height="22" rx="3.5" fill="${P.cloud}"/>
    <circle cx="76" cy="58" r="6.4" fill="${P.sunshine}"/>
    <circle cx="89" cy="70" r="6.4" fill="${P.peach}"/>`,

  bed: () => `${disc(P.sunshineSoft)}
    <ellipse cx="60" cy="98" rx="42" ry="5" fill="${P.sunshineDeep}" opacity="0.12"/>
    <path d="M 14 40 q 0 -10 10 -10 q 10 0 10 10 v 56 h -20 Z" fill="url(#woodGradV)"/>
    <path d="M 88 60 q 0 -8 9 -8 q 9 0 9 8 v 36 h -18 Z" fill="url(#woodGradV)"/>
    <rect x="20" y="70" width="82" height="20" rx="9" fill="${P.porcelainMid}"/>
    <path d="M 28 70 h 68 q 10 0 10 10 v 4 h -78 Z" fill="url(#lavenderBall)" opacity="0.9"/>
    <path d="M 28 62 q 0 -12 14 -12 h 16 q 14 0 14 12 v 8 h -44 Z" fill="${P.cloud}"/>
    <path d="M 62 78 q 22 -8 44 0" stroke="#FFFFFF" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.5"/>`,

  potty: () => `${disc(P.hopGreenSoft)}
    ${g('translate(60 96) scale(0.34)', `
      <path d="M -104 -78 q 0 -22 22 -22 h 164 q 22 0 22 22 v 34 q 0 56 -104 56 q -104 0 -104 -56 Z" fill="url(#greenBall)"/>
      <ellipse cx="0" cy="-96" rx="112" ry="34" fill="${P.hopGreenDeep}"/>
      <ellipse cx="0" cy="-100" rx="112" ry="34" fill="url(#padGreenLight)"/>
      <ellipse cx="0" cy="-102" rx="62" ry="17" fill="${P.pondBlueSoft}"/>
      <path d="M -96 -108 q -14 -66 34 -66 h 124 q 48 0 34 66 q -96 -20 -192 0 Z" fill="url(#greenBall)"/>
      <path d="M -76 -122 q -8 -36 22 -36 h 108 q 30 0 22 36 Z" fill="#FFFFFF" opacity="0.2"/>`)}`,

  sink: () => `${disc(P.pondBlueSoft)}
    <path d="M 60 46 v -14 q 0 -10 10 -10 h 12" stroke="${P.sand300}" stroke-width="10" fill="none" stroke-linecap="round"/>
    <rect x="76" y="16" width="16" height="16" rx="7" fill="${P.sand400}"/>
    <path d="M 47 74 q -3 18 -6 24 h 38 q -3 -6 -6 -24 Z" fill="${P.porcelainShade}"/>
    <ellipse cx="60" cy="99" rx="26" ry="6" fill="url(#porcelainGrad)"/>
    <path d="M 20 54 q 6 22 18 24 h 44 q 12 -2 18 -24 Z" fill="url(#porcelainGrad)"/>
    <ellipse cx="60" cy="54" rx="40" ry="11" fill="url(#porcelainGrad)"/>
    <ellipse cx="60" cy="55" rx="30" ry="7.4" fill="${P.pondBlueLight}"/>
    <ellipse cx="49" cy="52" rx="13" ry="3.4" fill="#FFFFFF" opacity="0.7"/>`,

  bubbles: () => `${disc(P.pondBlueSoft)}
    <circle cx="48" cy="56" r="26" fill="url(#bubbleFill)"/>
    <circle cx="82" cy="42" r="16" fill="url(#bubbleFill)"/>
    <circle cx="84" cy="80" r="20" fill="url(#bubbleFill)"/>
    <circle cx="46" cy="92" r="13" fill="url(#bubbleFill)"/>
    <circle cx="30" cy="34" r="10" fill="url(#bubbleFill)"/>
    <circle cx="40" cy="46" r="8" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="78" cy="36" r="5" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="78" cy="72" r="6" fill="#FFFFFF" opacity="0.85"/>`,

  // -- Wiping: the action, then the direction, then the amount --------------
  //
  // Disc tints are chosen per *question*, not per icon: the three options a
  // child sees together never share a tint unless the set is meant to read as
  // one family (direction, amount), where the tint is held constant on purpose
  // so the only visible difference is the thing being taught.

  wipe: () => `${disc(P.hopGreenSoft)}
    ${iconShadow(60, 106, 28, P.hopGreenInk, 0.12)}
    <path d="M 20 40 q -8 14 0 28" stroke="${P.hopGreen}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.4"/>
    <path d="M 10 36 q -10 18 0 36" stroke="${P.hopGreen}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.2"/>
    ${g('translate(62 100) scale(0.85)', wipeHand())}`,

  frontToBack: () => `${disc(P.peachSoft)}
    ${arrow(20, 100, 26, { head: 15 })}
    ${g('translate(58 102) scale(0.6)', wipeHand())}`,

  backToFront: () => `${disc(P.peachSoft)}
    ${arrow(100, 20, 26, { head: 15 })}
    ${g('translate(58 102) scale(0.6)', wipeHand())}`,

  sideToSide: () => `${disc(P.peachSoft)}
    ${arrow(22, 98, 26, { head: 15, both: true })}
    ${g('translate(58 102) scale(0.6)', wipeHand())}`,

  paperCorner: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 80, 19, P.sunshineDeep, 0.24)}
    ${g('rotate(-7 60 58)', `
      <path d="M 45 48 h 30 v 16 l -7.5 6 l -7.5 -6 l -7.5 6 l -7.5 -6 Z" fill="${P.sand400}" opacity="0.55" transform="translate(0 4)"/>
      <path d="M 45 48 h 30 v 16 l -7.5 6 l -7.5 -6 l -7.5 6 l -7.5 -6 Z" fill="url(#paperStack)" stroke="${P.sand400}" stroke-width="2.6" stroke-linejoin="round"/>
      <path d="M 45 56 h 30" stroke="${P.sand300}" stroke-width="2" fill="none"/>`)}`,

  paperFewSquares: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 88, 34, P.sunshineDeep, 0.14)}
    ${g('rotate(-5 60 60)', paperSquares(15, 45, 3))}`,

  paperPile: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 104, 40, P.sunshineDeep, 0.16)}
    ${[[22, 86, 76, -2], [28, 73, 66, 4], [17, 60, 74, -5], [30, 47, 62, 6], [23, 34, 68, -4], [33, 22, 54, 3]]
      .map(([x, y, w, rot]) => `<g transform="rotate(${rot} ${R(x + w / 2)} ${y + 8})">
      <rect x="${x}" y="${y}" width="${w}" height="17" rx="4" fill="url(#paperStack)"/>
      <rect x="${x}" y="${y}" width="${w}" height="12" rx="4" fill="url(#paperSheet)"/>
      <rect x="${x}" y="${y}" width="${w}" height="12" rx="4" fill="none" stroke="${P.sand200}" stroke-width="1.6"/></g>`).join('')}`,

  // -- Hand washing ---------------------------------------------------------

  washHands: () => `${disc(P.hopGreenSoft)}
    <path d="M 92 20 h -22 q -10 0 -10 10 v 4" stroke="${P.sand400}" stroke-width="12" fill="none" stroke-linecap="round"/>
    <path d="M 92 20 h -22 q -10 0 -10 10 v 4" stroke="${P.sand200}" stroke-width="6" fill="none" stroke-linecap="round"/>
    <path d="M 60 32 v 16" stroke="${P.pondBlue}" stroke-width="11" stroke-linecap="round" fill="none"/>
    <path d="M 60 34 v 11" stroke="${P.pondBlueLight}" stroke-width="4.5" stroke-linecap="round" fill="none"/>
    ${g('translate(60 70) scale(0.72) translate(-60 -60)', handPair())}
    ${[[24, 62, 10], [96, 58, 8], [88, 84, 10], [30, 88, 7]].map(([cx, cy, r]) =>
      `<circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#bubbleFill)" stroke="${P.pondBlue}" stroke-width="2" stroke-opacity="0.35"/>`).join('')}
    <path d="M 44 98 q 8 7 16 5" stroke="${P.pondBlue}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.55"/>
    <path d="M 76 98 q -8 7 -16 5" stroke="${P.pondBlue}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.55"/>`,

  oneFinger: () => `${disc(P.peachSoft)}
    ${iconShadow(60, 108, 26, P.peachInk, 0.12)}
    <path d="M 90 18 h -22 q -10 0 -10 10 v 4" stroke="${P.sand400}" stroke-width="12" fill="none" stroke-linecap="round"/>
    <path d="M 90 18 h -22 q -10 0 -10 10 v 4" stroke="${P.sand200}" stroke-width="6" fill="none" stroke-linecap="round"/>
    <path d="${drop(58, 41, 15, 5.2)}" fill="${P.pondBlue}"/>
    <rect x="50" y="50" width="16" height="42" rx="8" fill="url(#handGrad)"/>
    <rect x="36" y="72" width="48" height="34" rx="16" fill="url(#handGrad)"/>
    <rect x="26" y="76" width="15" height="24" rx="7.5" fill="url(#handGradDeep)"/>
    <path d="M 46 84 q 18 7 34 0" stroke="${P.handDeep}" stroke-width="3.2" fill="none" stroke-linecap="round" opacity="0.3"/>
    <path d="M 47 94 q 18 7 34 0" stroke="${P.handDeep}" stroke-width="3.2" fill="none" stroke-linecap="round" opacity="0.2"/>`,

  quickSplash: () => `${disc(P.pondBlueSoft)}
    <ellipse cx="60" cy="84" rx="38" ry="10" fill="${P.pondBlueDeep}" opacity="0.28"/>
    <ellipse cx="60" cy="81" rx="38" ry="10" fill="url(#waterStream)"/>
    <path d="M 40 82 q 3 -24 20 -24 q 17 0 20 24 q -20 -7 -40 0 Z" fill="url(#bubbleFill)"/>
    <path d="${drop(60, 34, 22, 8)}" fill="${P.pondBlue}"/>
    <circle cx="33" cy="54" r="6" fill="${P.pondBlueLight}"/>
    <circle cx="88" cy="50" r="7" fill="${P.pondBlueLight}"/>
    <circle cx="97" cy="70" r="4.4" fill="${P.pondBlueLight}" opacity="0.8"/>`,

  singing: () => `${disc(P.lavenderSoft)}
    <circle cx="32" cy="84" r="15" fill="url(#bubbleFill)"/>
    <circle cx="60" cy="97" r="10" fill="url(#bubbleFill)"/>
    <circle cx="88" cy="86" r="12" fill="url(#bubbleFill)"/>
    <circle cx="27" cy="76" r="5" fill="#FFFFFF" opacity="0.8"/>
    ${musicNote(44, 48, 1.2, P.lavenderDeep)}
    ${musicNote(85, 32, 0.78, P.lavenderDeep)}`,

  // -- Flushing and the two things that are not a flush ---------------------

  // Two passes of a tank-and-lever close-up read as a soap dispenser at 40pt.
  // This is the shared `toilet` object with its water actually swirling and
  // its lever picked out in warm yellow: "the thing you press", and "flushing
  // the toilet", in one picture. It never shares a question with the plain
  // Toilet icon, so the repeated object costs nothing.
  flush: () => `${disc(P.lavenderSoft)}
    ${toilet(52, 110, 0.29, { lidOpen: false })}
    <path d="M 51 46 m -14 0 a 14 6 0 1 1 20 5" fill="none" stroke="${P.pondBlueDeep}" stroke-width="5" stroke-linecap="round"/>
    <path d="M 51 49 m -6 0 a 6 3 0 1 1 9 2" fill="none" stroke="${P.pondBlueDeep}" stroke-width="4" stroke-linecap="round" opacity="0.85"/>
    <circle cx="27" cy="34" r="5" fill="${P.pondBlueLight}"/>
    <circle cx="72" cy="28" r="4" fill="${P.pondBlueLight}" opacity="0.85"/>
    <circle cx="38" cy="22" r="3.2" fill="${P.pondBlue}" opacity="0.6"/>
    <rect x="60" y="36" width="18" height="8" rx="4" fill="${P.sunshineDeep}"/>
    <rect x="60" y="35" width="18" height="7" rx="3.5" fill="${P.sunshineBright}"/>`,

  lightSwitch: () => `${disc(P.sunshineSoft)}
    <circle cx="60" cy="50" r="44" fill="url(#glowWarm)"/>
    ${iconShadow(60, 100, 28, P.sunshineDeep, 0.14)}
    <rect x="33" y="26" width="54" height="70" rx="10" fill="${P.sand400}"/>
    <rect x="33" y="23" width="54" height="70" rx="10" fill="url(#porcelainGrad)"/>
    <rect x="45" y="34" width="30" height="48" rx="7" fill="${P.sand300}"/>
    <path d="M 47 58 v -14 q 0 -8 8 -8 h 10 q 8 0 8 8 v 14 Z" fill="#FFFFFF"/>
    <path d="M 47 60 v 12 q 0 8 8 8 h 10 q 8 0 8 -8 v -12 Z" fill="${P.sand200}"/>
    <path d="M 40 30 v 58" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.7"/>`,

  doorbell: () => `${disc(P.peachSoft)}
    ${iconShadow(60, 100, 25, P.peachInk, 0.13)}
    <rect x="38" y="25" width="44" height="70" rx="10" fill="${P.sand400}"/>
    <rect x="38" y="22" width="44" height="70" rx="10" fill="url(#metalGrad)"/>
    <rect x="44" y="28" width="11" height="58" rx="5.5" fill="#FFFFFF" opacity="0.45"/>
    <rect x="47" y="66" width="26" height="13" rx="4" fill="${P.sand300}"/>
    <circle cx="60" cy="46" r="17" fill="${P.sand400}"/>
    <circle cx="60" cy="46" r="14" fill="${P.peachDeep}"/>
    <circle cx="60" cy="44" r="14" fill="url(#peachBall)"/>
    <circle cx="55" cy="39" r="5" fill="#FFFFFF" opacity="0.5"/>
    <path d="M 92 34 q 9 14 0 28" stroke="${P.peachDeep}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.5"/>
    <path d="M 28 34 q -9 14 0 28" stroke="${P.peachDeep}" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.5"/>`,

  // -- Things that are not the potty (all of them pleasant places) ----------

  kitchen: () => `${disc(P.lavenderSoft)}
    ${iconShadow(60, 102, 40, P.lavenderInk, 0.11)}
    <path d="M 74 32 q 0 -8 8 -8 h 12 q 8 0 8 8 v 26 h -28 Z" fill="url(#woodGradV)"/>
    <rect x="86" y="56" width="9" height="42" rx="4.5" fill="${P.woodDeep}"/>
    <path d="M 66 38 h 18 v 13 q 0 7 -9 7 q -9 0 -9 -7 Z" fill="url(#peachBall)"/>
    <path d="M 84 42 q 8 0 8 5 q 0 5 -8 5" stroke="${P.peachDeep}" stroke-width="3.4" fill="none" stroke-linecap="round"/>
    <ellipse cx="42" cy="54" rx="19" ry="6" fill="${P.sand300}"/>
    <ellipse cx="42" cy="52" rx="19" ry="6" fill="url(#porcelainGrad)"/>
    <ellipse cx="42" cy="52" rx="9" ry="2.8" fill="${P.sand200}"/>
    <rect x="16" y="62" width="88" height="11" rx="5.5" fill="${P.woodDeep}"/>
    <rect x="16" y="58" width="88" height="11" rx="5.5" fill="url(#woodGrad)"/>
    <rect x="26" y="68" width="9" height="32" rx="4.5" fill="url(#woodGradV)"/>
    <rect x="85" y="68" width="9" height="32" rx="4.5" fill="url(#woodGradV)"/>`,

  outside: () => `${disc(P.pondBlueSoft)}
    <g clip-path="url(#iconDiscClip)">
      <circle cx="90" cy="32" r="24" fill="url(#sunGlow)"/>
      <circle cx="90" cy="32" r="13" fill="url(#sunDisc)"/>
      <ellipse cx="30" cy="26" rx="17" ry="9" fill="#FFFFFF" opacity="0.7"/>
      <ellipse cx="42" cy="28" rx="12" ry="7" fill="#FFFFFF" opacity="0.7"/>
      <path d="M 0 86 q 26 -24 60 -24 q 38 0 60 26 v 32 h -120 Z" fill="url(#ground)"/>
      <rect x="36" y="56" width="9" height="30" rx="4" fill="url(#woodGradV)"/>
      <circle cx="40" cy="48" r="18" fill="${P.hopGreenDeep}"/>
      <circle cx="40" cy="45" r="18" fill="url(#greenBall)"/>
      <circle cx="26" cy="55" r="11" fill="url(#greenBall)"/>
      <circle cx="54" cy="54" r="12" fill="url(#greenBall)"/>
      <path d="M 0 98 q 30 -12 60 -8 q 34 4 60 14 v 18 h -120 Z" fill="url(#groundNear)"/>
      <circle cx="78" cy="92" r="4" fill="${P.sunshine}"/>
      <circle cx="94" cy="100" r="3.4" fill="${P.peach}"/>
      <circle cx="22" cy="100" r="3.4" fill="${P.white}" opacity="0.8"/>
    </g>`,

  slide: () => `${disc(P.hopGreenSoft)}
    <g clip-path="url(#iconDiscClip)">
      <path d="M 0 94 q 30 -10 60 -10 q 30 0 60 10 v 26 h -120 Z" fill="url(#ground)"/>
    </g>
    <rect x="70" y="50" width="8" height="46" rx="4" fill="${P.lavenderDeep}"/>
    <rect x="92" y="50" width="8" height="46" rx="4" fill="${P.lavenderDeep}"/>
    ${[58, 70, 82].map((y) => `<rect x="72" y="${y}" width="26" height="6" rx="3" fill="${P.lavender}"/>`).join('')}
    <rect x="63" y="42" width="40" height="9" rx="4.5" fill="${P.lavender}"/>
    <path d="M 67 47 C 49 54 34 70 31 86 q -1 9 9 9" stroke="${P.peachDeep}" stroke-width="16" stroke-linecap="round" fill="none"/>
    <path d="M 68 42 C 50 49 35 66 32 82 q -1 8 9 8" stroke="url(#chuteGrad)" stroke-width="10" stroke-linecap="round" fill="none"/>
    <path d="M 70 37 C 52 44 37 62 34 78 q -1 7 8 7" stroke="${P.peachSoft}" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.85"/>`,

  toyBox: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 102, 38, P.sunshineDeep, 0.13)}
    <g transform="rotate(-12 60 44)"><rect x="22" y="26" width="78" height="14" rx="6" fill="url(#woodGrad)"/>
      <rect x="22" y="26" width="78" height="8" rx="4" fill="${P.woodLight}" opacity="0.6"/></g>
    <circle cx="40" cy="48" r="12" fill="url(#peachBall)"/>
    <rect x="68" y="40" width="20" height="18" rx="4" fill="url(#blueBall)"/>
    <path d="M 58 34 l 4.4 9 l 9.6 1.4 l -7 6.8 l 1.7 9.6 l -8.7 -4.6 l -8.7 4.6 l 1.7 -9.6 l -7 -6.8 l 9.6 -1.4 Z" fill="url(#yellowBall)"/>
    <path d="M 22 56 h 76 v 34 q 0 8 -8 8 h -60 q -8 0 -8 -8 Z" fill="url(#woodGrad)"/>
    <rect x="20" y="52" width="80" height="11" rx="5.5" fill="${P.woodDeep}"/>
    <rect x="20" y="50" width="80" height="10" rx="5" fill="url(#woodGradV)"/>
    <rect x="52" y="70" width="16" height="12" rx="4" fill="${P.sunshineBright}"/>`,

  toyTruck: () => `${disc(P.lavenderSoft)}
    ${iconShadow(60, 102, 38, P.lavenderInk, 0.12)}
    <rect x="16" y="50" width="54" height="32" rx="6" fill="url(#yellowBall)"/>
    <rect x="22" y="56" width="20" height="7" rx="3.5" fill="#FFFFFF" opacity="0.4"/>
    <path d="M 68 42 h 18 q 6 0 9 5 l 9 15 q 2 3 2 7 v 13 h -38 Z" fill="url(#peachBall)"/>
    <path d="M 74 48 h 11 l 8 13 h -19 Z" fill="url(#screenGrad)"/>
    <rect x="14" y="78" width="92" height="9" rx="4.5" fill="${P.peachDeep}"/>
    <circle cx="34" cy="88" r="13" fill="${P.night600}"/>
    <circle cx="34" cy="88" r="6" fill="${P.sand100}"/>
    <circle cx="86" cy="88" r="13" fill="${P.night600}"/>
    <circle cx="86" cy="88" r="6" fill="${P.sand100}"/>`,

  keepPlaying: () => `${disc(P.lavenderSoft)}
    ${iconShadow(60, 100, 36, P.lavenderInk, 0.12)}
    <rect x="20" y="62" width="35" height="35" rx="8" fill="url(#peachBall)"/>
    <rect x="26" y="68" width="14" height="6" rx="3" fill="#FFFFFF" opacity="0.35"/>
    <rect x="59" y="62" width="35" height="35" rx="8" fill="url(#blueBall)"/>
    <rect x="65" y="68" width="14" height="6" rx="3" fill="#FFFFFF" opacity="0.35"/>
    <rect x="39" y="23" width="35" height="35" rx="8" fill="url(#yellowBall)"/>
    <rect x="45" y="29" width="14" height="6" rx="3" fill="#FFFFFF" opacity="0.4"/>`,

  // -- People, toys and the rest of the distractor cast ---------------------

  grownUp: () => `${disc(P.peachSoft)}
    ${iconShadow(60, 104, 34, P.peachInk, 0.12)}
    <path d="M 84 84 q 16 -14 15 -36" stroke="url(#shirtGrad)" stroke-width="16" stroke-linecap="round" fill="none"/>
    <path d="M 26 104 q 0 -40 34 -40 q 34 0 34 40 Z" fill="url(#shirtGrad)"/>
    <path d="M 26 104 q 0 -40 34 -40 q -15 13 -15 40 Z" fill="#FFFFFF" opacity="0.16"/>
    <circle cx="99" cy="44" r="10" fill="url(#handGrad)"/>
    <circle cx="60" cy="42" r="18" fill="url(#handGrad)"/>
    <path d="M 42 44 q -2 -24 18 -24 q 20 0 18 24 q -6 -13 -18 -13 q -12 0 -18 13 Z" fill="url(#hairGrad)"/>`,

  teddy: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 104, 32, P.sunshineDeep, 0.14)}
    <ellipse cx="33" cy="74" rx="11" ry="15" fill="url(#furGradDeep)" transform="rotate(22 33 74)"/>
    <ellipse cx="87" cy="74" rx="11" ry="15" fill="url(#furGradDeep)" transform="rotate(-22 87 74)"/>
    <ellipse cx="46" cy="99" rx="13" ry="10" fill="url(#furGradDeep)"/>
    <ellipse cx="74" cy="99" rx="13" ry="10" fill="url(#furGradDeep)"/>
    <ellipse cx="60" cy="80" rx="26" ry="24" fill="url(#furGrad)"/>
    <ellipse cx="60" cy="84" rx="15" ry="14" fill="${P.sand100}"/>
    <circle cx="40" cy="37" r="11" fill="url(#furGradDeep)"/>
    <circle cx="80" cy="37" r="11" fill="url(#furGradDeep)"/>
    <circle cx="40" cy="37" r="5.5" fill="${P.peachSoft}"/>
    <circle cx="80" cy="37" r="5.5" fill="${P.peachSoft}"/>
    <circle cx="60" cy="48" r="22" fill="url(#furGrad)"/>
    <ellipse cx="60" cy="56" rx="12" ry="9" fill="${P.sand100}"/>
    <ellipse cx="60" cy="50" rx="5" ry="4" fill="${P.woodDeep}"/>
    <circle cx="51" cy="43" r="2.8" fill="${P.night700}"/>
    <circle cx="69" cy="43" r="2.8" fill="${P.night700}"/>`,

  television: () => `${disc(P.lavenderSoft)}
    ${iconShadow(60, 98, 30, P.lavenderInk, 0.12)}
    <rect x="36" y="88" width="48" height="7" rx="3.5" fill="${P.sand400}"/>
    <path d="M 50 76 l -9 14 h 38 l -9 -14 Z" fill="${P.sand400}"/>
    <rect x="16" y="30" width="88" height="52" rx="12" fill="${P.sand400}"/>
    <rect x="16" y="27" width="88" height="52" rx="12" fill="url(#metalGrad)"/>
    <rect x="23" y="35" width="74" height="36" rx="7" fill="url(#screenGrad)"/>
    <g clip-path="url(#tvScreenClip)">
      <circle cx="82" cy="45" r="7" fill="${P.sunshine}"/>
      <path d="M 21 68 q 14 -16 28 -5 q 12 9 20 -3 q 12 -17 28 3 v 10 h -76 Z" fill="url(#greenBall)"/>
    </g>
    <path d="M 27 39 q 8 -2 12 0" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.7"/>`,

  mirror: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 108, 22, P.sunshineDeep, 0.13)}
    <path d="M 48 96 h 24 l 6 12 h -36 Z" fill="${P.sand400}"/>
    <ellipse cx="60" cy="58" rx="36" ry="44" fill="${P.sand400}"/>
    <ellipse cx="60" cy="58" rx="36" ry="44" fill="url(#metalGrad)"/>
    <ellipse cx="60" cy="58" rx="28" ry="36" fill="url(#glassGrad)"/>
    <g clip-path="url(#mirrorGlassClip)">
      <path d="M 40 100 L 72 12 h 13 L 53 100 Z" fill="#FFFFFF" opacity="0.6"/>
      <path d="M 64 100 L 96 12 h 6 L 70 100 Z" fill="#FFFFFF" opacity="0.35"/>
    </g>`,

  toothbrush: () => `${disc(P.sunshineSoft)}
    ${g('rotate(-32 60 60)', `
      <rect x="44" y="53" width="54" height="15" rx="7.5" fill="${P.pondBlueDeep}"/>
      <rect x="44" y="52" width="54" height="13" rx="6.5" fill="url(#blueBall)"/>
      <rect x="74" y="54" width="18" height="7" rx="3.5" fill="#FFFFFF" opacity="0.35"/>
      <rect x="10" y="51" width="44" height="19" rx="9" fill="${P.pondBlueDeep}"/>
      <rect x="10" y="50" width="44" height="17" rx="8.5" fill="url(#blueBall)"/>
      ${[13, 21, 29, 37, 45].map((x) => `<rect x="${x}" y="${x === 13 || x === 45 ? 40 : 37}" width="7" height="${x === 13 || x === 45 ? 16 : 19}" rx="3.5" fill="${P.sand300}"/>
      <rect x="${x}" y="${x === 13 || x === 45 ? 39 : 36}" width="7" height="${x === 13 || x === 45 ? 16 : 19}" rx="3.5" fill="${P.porcelainMid}"/>`).join('')}
      <path d="M 16 36 q 14 -10 28 -2 q -14 8 -28 2 Z" fill="${P.hopGreenLight}"/>`)}`,

  shoes: () => `${disc(P.peachSoft)}
    ${iconShadow(60, 100, 42, P.peachInk, 0.11)}
    ${[[26, 58, P.lavender, P.lavenderDeep], [54, 76, P.pondBlue, P.pondBlueDeep]].map(([x, y, body, deep]) => g(`translate(${x} ${y})`, `
      <path d="M -8 21 q -11 0 -11 -8 q 0 -9 11 -11 l 41 -6 q 12 -1 14 8 l 2 8 q 1 9 -10 9 Z" fill="${P.sand300}"/>
      <path d="M -8 19 q -11 0 -11 -8 q 0 -9 11 -11 l 41 -6 q 12 -1 14 8 l 2 8 q 1 9 -10 9 Z" fill="#FFFFFF"/>
      <path d="M -8 0 q 0 -18 13 -18 q 11 0 14 11 q 3 9 16 12 q 12 3 14 11 h -57 Z" fill="${body}"/>
      <path d="M -8 -1 q 0 -17 13 -17 q 7 0 11 5 q -16 4 -16 24 h -8 Z" fill="#FFFFFF" opacity="0.22"/>
      <path d="M 5 -9 q 8 5 11 13" stroke="#FFFFFF" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.85"/>
      <path d="M 13 -12 q 8 6 11 14" stroke="#FFFFFF" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.85"/>
      <path d="M -8 14 h 57" stroke="${deep}" stroke-width="2.4" fill="none" opacity="0.18"/>`)).join('')}`,

  sock: () => `${disc(P.peachSoft)}
    ${iconShadow(66, 108, 26, P.peachInk, 0.13)}
    ${g('translate(56 58)', `
      <path d="M -22 -32 h 28 q 8 0 8 8 v 30 q 0 8 8 12 l 13 6 q 10 5 5 15 q -6 9 -17 4 l -20 -9 q -25 -12 -25 -35 v -23 q 0 -8 8 -8 Z" fill="${P.sand300}"/>
      <path d="M -22 -36 h 28 q 8 0 8 8 v 30 q 0 8 8 12 l 13 6 q 10 5 5 15 q -6 9 -17 4 l -20 -9 q -25 -12 -25 -35 v -23 q 0 -8 8 -8 Z" fill="url(#paperSheet)"/>
      <path d="M -22 -36 h 28 q 8 0 8 8 v 30 q 0 8 8 12 l 13 6 q 10 5 5 15 q -6 9 -17 4 l -20 -9 q -25 -12 -25 -35 v -23 q 0 -8 8 -8 Z" fill="none" stroke="${P.sand300}" stroke-width="2.2"/>
      <rect x="-22" y="-32" width="36" height="6" rx="3" fill="${P.pondBlue}"/>
      <rect x="-22" y="-22" width="36" height="6" rx="3" fill="${P.lavender}"/>
      <rect x="-22" y="-12" width="36" height="6" rx="3" fill="${P.pondBlue}"/>
      <path d="M 22 30 q 12 6 18 13" stroke="${P.pondBlueLight}" stroke-width="10" fill="none" stroke-linecap="round" opacity="0.6"/>`)}`,

  hat: () => `${disc(P.sunshineSoft)}
    ${iconShadow(60, 92, 44, P.sunshineDeep, 0.13)}
    <ellipse cx="60" cy="76" rx="46" ry="15" fill="${P.peachDeep}"/>
    <ellipse cx="60" cy="73" rx="46" ry="15" fill="url(#peachBall)"/>
    <path d="M 32 74 q -3 -38 28 -38 q 31 0 28 38 q -28 9 -56 0 Z" fill="url(#peachBall)"/>
    <path d="M 32 67 q 28 9 56 0 q 1 4 1 8 q -28 9 -56 0 Z" fill="${P.sand50}"/>
    <path d="M 41 50 q 6 -8 16 -9" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.4"/>`,

  apple: () => `${disc(P.pondBlueSoft)}
    ${iconShadow(58, 102, 30, P.pondBlueInk, 0.12)}
    <path d="M 54 44 q -32 -11 -32 27 q 0 35 23 35 q 9 0 9 -4 q 0 4 9 4 q 23 0 23 -35 q 0 -38 -32 -27 Z" fill="url(#peachBall)"/>
    <path d="M 40 50 q -12 9 -12 26" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.32"/>
    <path d="M 54 45 q 2 -14 -4 -20" stroke="${P.woodDeep}" stroke-width="6" fill="none" stroke-linecap="round"/>
    <path d="M 56 33 q 18 -14 26 0 q -14 14 -26 0 Z" fill="${P.hopGreen}"/>
    ${g('rotate(10 86 92)', `
      <path d="M 64 100 q 12 -22 34 -16 q 10 3 7 10 q -5 11 -23 11 q -18 0 -18 -5 Z" fill="${P.sand300}"/>
      <path d="M 64 98 q 12 -22 34 -16 q 10 3 7 10 q -5 11 -23 11 q -18 0 -18 -5 Z" fill="${P.sand50}"/>
      <path d="M 64 98 q 12 -22 34 -16 q 8 2 8 7 q -18 -8 -42 9 Z" fill="url(#peachBall)"/>`)}`,

};

// ===========================================================================
// 5. EVENT GLYPHS  (96 x 96)
// ===========================================================================
// Meaning is carried by silhouette alone: an open ring, one drop, a soft coil,
// and a drop breaking out of a broken ring. Colour is a second, optional cue —
// every glyph is also emitted in single-ink `-mono`.
const drop = (cx, cy, h, w) => {
  const top = cy - h / 2, bot = cy + h / 2, r = w;
  return `M ${cx} ${R(top)}
    C ${R(cx + w * 0.5)} ${R(top + h * 0.3)} ${R(cx + r)} ${R(bot - r * 1.1)} ${R(cx + r)} ${R(bot - r)}
    A ${R(r)} ${R(r)} 0 1 1 ${R(cx - r)} ${R(bot - r)}
    C ${R(cx - r)} ${R(bot - r * 1.1)} ${R(cx - w * 0.5)} ${R(top + h * 0.3)} ${cx} ${R(top)} Z`;
};

const eventGlyphs = {
  // Tried: an open ring around a small centre — an attempt, outcome not stated.
  tried: (ink, accent) => `
    <circle cx="48" cy="48" r="29" fill="none" stroke="${ink}" stroke-width="9" stroke-linecap="round" stroke-dasharray="118 30" transform="rotate(-58 48 48)"/>
    <circle cx="48" cy="48" r="11" fill="${accent}"/>`,

  // Pee: a single, solid drop.
  pee: (ink, accent) => `
    <path d="${drop(48, 50, 62, 24)}" fill="${accent}"/>
    <path d="M 38 58 q 1 -15 8 -24" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.5"/>`,

  // Poop: a rounded three-tier coil. No face, no flies, no smell lines.
  poop: (ink, accent) => `
    <ellipse cx="48" cy="76" rx="32" ry="12" fill="${accent}"/>
    <path d="M 16 76 q 0 -18 32 -18 q 32 0 32 18 Z" fill="${accent}"/>
    <path d="M 24 60 q 0 -16 24 -16 q 24 0 24 16 q 0 8 -24 8 q -24 0 -24 -8 Z" fill="${accent}"/>
    <path d="M 32 46 q 0 -14 16 -14 q 16 0 16 14 q 0 7 -16 7 q -16 0 -16 -7 Z" fill="${accent}"/>
    <ellipse cx="40" cy="66" rx="9" ry="4" fill="#FFFFFF" opacity="0.22"/>
    <ellipse cx="42" cy="40" rx="6" ry="3" fill="#FFFFFF" opacity="0.22"/>`,

  // Accident: the same drop, outside a ring that has opened up.
  accident: (ink, accent) => `
    <circle cx="48" cy="42" r="31" fill="none" stroke="${ink}" stroke-width="8" stroke-linecap="round" stroke-dasharray="27 21" opacity="0.7"/>
    <path d="${drop(48, 40, 46, 19)}" fill="${accent}"/>
    <path d="M 40 46 q 1 -11 6 -18" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.45"/>
    <g fill="${accent}">
      <ellipse cx="48" cy="86" rx="19" ry="6"/>
      <circle cx="24" cy="78" r="5"/><circle cx="73" cy="76" r="4.4"/>
    </g>`,
};
const EVENT_TINT = {
  tried: [P.night600, P.sunshineBright],
  pee: [P.night600, P.pondBlue],
  poop: [P.night600, P.wood],
  accident: [P.night600, P.lavender],
};

// ===========================================================================
// 6. APP ICON  (1024 x 1024)
// ===========================================================================
function appIcon() {
  const S = 1024;
  // Pass 1 put Hop's green face on a green field and he all but disappeared.
  // The face now sits on a Cloud disc inside the pond-green frame, which is
  // what carries the silhouette down to 40pt.
  const body = `
    <rect width="${S}" height="${S}" fill="url(#iconSky)"/>
    <circle cx="512" cy="452" r="500" fill="url(#iconHalo)"/>
    <circle cx="512" cy="496" r="404" fill="${P.hopGreenInk}" opacity="0.12"/>
    <circle cx="512" cy="490" r="398" fill="${P.hopGreenSoft}"/>
    <circle cx="512" cy="490" r="386" fill="${P.cloud}"/>
    <g clip-path="url(#iconDisc)">
      <g fill="${P.hopGreen}" opacity="0.14">
        <rect x="166" y="368" width="88" height="330" rx="44"/>
        <rect x="770" y="368" width="88" height="330" rx="44"/>
      </g>
      <path d="M 100 748 Q 300 706 512 742 Q 724 778 930 730 L 930 900 L 100 900 Z" fill="url(#iconWater)"/>
      <path d="M 100 792 Q 300 754 512 786 Q 724 818 930 776" fill="none" stroke="#FFFFFF" stroke-width="13" opacity="0.4"/>
      ${g('translate(268 828) scale(1.5)', `<path d="${pad(0, 0, 62, { notch: 46 })}" fill="${P.hopGreenDeep}" opacity="0.4"/>`)}
      ${g('translate(760 846) scale(1.25)', `<path d="${pad(0, 0, 62, { notch: 208 })}" fill="${P.hopGreenDeep}" opacity="0.35"/>`)}
    </g>
    <ellipse cx="512" cy="726" rx="228" ry="32" fill="${P.hopGreenInk}" opacity="0.07"/>
    ${g('translate(512 432) scale(4.9) translate(-75 -43)', flatFace({}))}
    <rect width="${S}" height="${S}" fill="url(#iconVignette)"/>`;
  return svg({ viewBox: `0 0 ${S} ${S}`, width: S, height: S, body });
}

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

// --- pond base, whole and per PondLayer ---
const layerOrder = ['sky', 'backdrop', 'water', 'shore', 'foreground'];
const baseBody = layerOrder.map((l) => `<g id="layer-${l}">${pondLayers[l]()}</g>`).join('\n');
write('Art/pond/pond-base.svg', svg({ viewBox: `0 0 ${SCENE_W} ${SCENE_H}`, width: SCENE_W, height: SCENE_H, body: baseBody }));
for (const l of layerOrder) {
  write(`Art/pond/pond-base-${l}.svg`, svg({
    viewBox: `0 0 ${SCENE_W} ${SCENE_H}`, width: SCENE_W, height: SCENE_H,
    body: `<g id="layer-${l}">${pondLayers[l]()}</g>`,
  }));
}

// --- one file per decoration ---
for (const [id, build] of Object.entries(ITEMS)) {
  write(`Art/pond/item-${id}.svg`, svg({ viewBox: '0 0 200 200', width: 200, height: 200, body: `<g id="item-${id}">${build()}</g>` }));
}

// --- the whole pond, composited exactly as PondCatalog places it ---
const previewBody = [
  `<g id="layer-sky">${pondLayers.sky()}${ITEM_LAYER.sky.map(placeItem).join('')}</g>`,
  `<g id="layer-backdrop">${pondLayers.backdrop()}${ITEM_LAYER.backdrop.map(placeItem).join('')}</g>`,
  `<g id="layer-water">${pondLayers.water()}${ITEM_LAYER.water.map(placeItem).join('')}</g>`,
  `<g id="layer-shore">${pondLayers.shore()}${ITEM_LAYER.shore.map(placeItem).join('')}</g>`,
  `<g id="layer-decoration">${ITEM_LAYER.decoration.map(placeItem).join('')}</g>`,
  `<g id="layer-character">${ITEM_LAYER.character.map(placeItem).join('')}
     ${g('translate(636 672) scale(0.5) translate(-256 -300)', frog({}))}</g>`,
  `<g id="layer-foreground">${pondLayers.foreground()}${ITEM_LAYER.foreground.map(placeItem).join('')}</g>`,
].join('\n');
write('Art/pond/pond-preview.svg', svg({ viewBox: `0 0 ${SCENE_W} ${SCENE_H}`, width: SCENE_W, height: SCENE_H, body: previewBody }));

// --- routine steps + shield ---
for (const [name, build] of Object.entries(scenes)) {
  write(`Art/scenes/${name}.svg`, svg({ viewBox: `0 0 ${SW} ${SH}`, width: SW, height: SH, body: `<g id="${name}">${build()}</g>` }));
}
write('Art/scenes/shield-hero.svg', shieldHero());

// --- quiz icons ---
for (const [name, build] of Object.entries(quizIcons)) {
  write(`Art/icons/quiz-${name}.svg`, svg({ viewBox: '0 0 120 120', width: 120, height: 120, body: `<g id="quiz-${name}">${build()}</g>` }));
}

// --- event glyphs, tinted and single-ink ---
for (const [name, build] of Object.entries(eventGlyphs)) {
  const [ink, accent] = EVENT_TINT[name];
  write(`Art/icons/event-${name}.svg`, svg({ viewBox: '0 0 96 96', width: 96, height: 96, body: `<g id="event-${name}">${build(ink, accent)}</g>` }));
  write(`Art/icons/event-${name}-mono.svg`, svg({ viewBox: '0 0 96 96', width: 96, height: 96, body: `<g id="event-${name}-mono">${build(P.midnight, P.midnight)}</g>` }));
}

// --- app icon ---
write('Art/appicon/appicon-1024.svg', appIcon());

console.log(out.map((f) => 'wrote ' + f).join('\n'));
console.log(`${out.length} files`);
