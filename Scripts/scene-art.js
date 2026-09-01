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
 *   Art/scenes/step-*.svg           the five routine step illustrations
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
// A pond-blue sibling for the second frog friend: same anatomy, cooler skin.
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
  hopBodyBlue: lin('hopBodyBlue', [[0, HOP_BLUE.bodyLight], [0.52, HOP_BLUE.bodyMid], [1, HOP_BLUE.bodyDeep]], { x1: 0.2, x2: 0.85 }),
  hopSheen: rad('hopSheen', [[0, '#FFFFFF', 0.45], [1, '#FFFFFF', 0]], { cx: 0.34, cy: 0.22, r: 0.6 }),
  hopCheek: rad('hopCheek', [[0, '#FF8E86', 0.85], [0.55, P.peach, 0.55], [1, P.peach, 0]]),
  hopEyeDome: rad('hopEyeDome', [[0, HOP.domeLight], [1, HOP.domeDeep]], { cx: 0.36, cy: 0.28, r: 0.75 }),
  hopEyeDomeBlue: rad('hopEyeDomeBlue', [[0, HOP_BLUE.domeLight], [1, HOP_BLUE.domeDeep]], { cx: 0.36, cy: 0.28, r: 0.75 }),
  groundShadow: rad('groundShadow', [[0, P.midnight, 0.20], [1, P.midnight, 0]]),
  softShadow: rad('softShadow', [[0, P.midnight, 0.14], [1, P.midnight, 0]]),

  // -- Sky / weather --
  skyPond: lin('skyPond', [[0, '#CFEDF9'], [0.55, P.pondBlueSoft], [1, P.sunshineSoft]]),
  skyWarm: lin('skyWarm', [[0, '#DCEFF8'], [0.48, P.pondBlueSoft], [0.8, P.sunshineSoft], [1, '#FFF1E6']]),
  skyHaze: lin('skyHaze', [[0, P.cloud, 0], [1, P.cloud, 0.85]]),
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
  towelGrad: lin('towelGrad', [[0, '#CFE9F7'], [1, '#A6D6EE']]),
  iconWell: rad('iconWell', [[0, '#FFFFFF', 0.55], [1, '#FFFFFF', 0]], { cx: 0.35, cy: 0.28, r: 0.8 }),

  // -- App icon --
  iconSky: lin('iconSky', [[0, '#8FDCAC'], [0.52, P.hopGreen], [1, '#3FA672']]),
  iconHalo: rad('iconHalo', [[0, '#FFFFFF', 0.42], [0.62, '#FFFFFF', 0.10], [1, '#FFFFFF', 0]], { cx: 0.5, cy: 0.42, r: 0.62 }),
  iconWater: lin('iconWater', [[0, '#7FD0EC', 0.85], [1, '#4FB6DC', 0.95]]),
  iconVignette: rad('iconVignette', [[0.6, P.hopGreenInk, 0], [1, P.hopGreenInk, 0.28]], { r: 0.72 }),
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

/** A grass blade / reed: rooted wide, curving to a point. */
function blade(x, baseY, h, curve, w) {
  return `M ${R(x - w)} ${R(baseY)} Q ${R(x - w * 0.5 + curve * 0.25)} ${R(baseY - h * 0.55)} ${R(x + curve)} ${R(baseY - h)} Q ${R(x + w * 0.7 + curve * 0.2)} ${R(baseY - h * 0.45)} ${R(x + w)} ${R(baseY)} Z`;
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

/** A fern frond: leaflets stepped along a bending spine, shrinking to the tip. */
function frond(len, bend) {
  const at = (t) => {
    const mt = 1 - t;
    return [R(2 * mt * t * (bend * 0.18) + t * t * bend), R(2 * mt * t * (-len * 0.5) + t * t * -len)];
  };
  const spine = `<path d="M 0 0 Q ${R(bend * 0.18)} ${R(-len * 0.5)} ${R(bend)} ${R(-len)}" fill="none" stroke="${P.hopGreenDeep}" stroke-width="5" stroke-linecap="round"/>`;
  const leaves = Array.from({ length: 7 }, (_, i) => {
    const t = 0.12 + (i / 6) * 0.84;
    const [x, y] = at(t);
    const w = 26 * (1 - t * 0.8) + 5;
    const lean = 14 + t * 26;
    return `<ellipse cx="${R(x - w * 0.72)}" cy="${y}" rx="${R(w)}" ry="${R(w * 0.44)}" fill="url(#fernGreen)" transform="rotate(${R(-28 - lean)} ${R(x - w * 0.72)} ${y})"/>
      <ellipse cx="${R(x + w * 0.72)}" cy="${y}" rx="${R(w)}" ry="${R(w * 0.44)}" fill="url(#fernGreen)" transform="rotate(${R(28 + lean)} ${R(x + w * 0.72)} ${y})"/>`;
  }).join('');
  return spine + leaves;
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
    <rect x="0" y="250" width="${SCENE_W}" height="150" fill="url(#skyHaze)"/>`,

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
    <g fill="${P.hopGreenDeep}" opacity="0.5">
      <path d="${blade(196, 704, 54, 12, 7)}"/><path d="${blade(214, 706, 40, -10, 6)}"/>
      <path d="${blade(1010, 690, 50, -12, 7)}"/><path d="${blade(992, 692, 38, 10, 6)}"/>
      <path d="${blade(628, 806, 44, 10, 7)}"/><path d="${blade(648, 808, 32, -8, 6)}"/>
    </g>`,

  foreground: () => `
    <path d="M -20 828 Q 300 780 620 812 Q 900 840 1220 792 L 1220 920 L -20 920 Z" fill="url(#groundNear)" opacity="0.95"/>
    <g fill="${P.hopGreenInk}" opacity="0.22">
      <path d="${blade(90, 858, 74, 18, 11)}"/><path d="${blade(126, 862, 56, -14, 9)}"/>
      <path d="${blade(1110, 848, 78, -18, 11)}"/><path d="${blade(1074, 852, 58, 14, 9)}"/>
    </g>
    <ellipse cx="600" cy="900" rx="760" ry="120" fill="${P.hopGreenInk}" opacity="0.10"/>`,
};

// --- Decorations. All drawn inside 0 0 200 200, centred on (100, 100). ------
const ITEMS = {
  lilyPadSmall: () => `
    <ellipse cx="100" cy="118" rx="66" ry="14" fill="${P.pondBlueInk}" opacity="0.1"/>
    <path d="${pad(100, 106, 68, { notch: 52 })}" fill="${P.hopGreenDeep}" opacity="0.55"/>
    <path d="${pad(100, 102, 68, { notch: 52 })}" fill="url(#padGreenLight)"/>
    <path d="M 100 102 l 42 -17" stroke="${P.hopGreenSoft}" stroke-width="3" stroke-linecap="round" opacity="0.45" fill="none"/>
    <ellipse cx="78" cy="90" rx="26" ry="8" fill="#FFFFFF" opacity="0.2"/>`,

  lilyPadLarge: () => `
    <ellipse cx="102" cy="128" rx="84" ry="16" fill="${P.pondBlueInk}" opacity="0.1"/>
    <path d="${pad(58, 96, 44, { notch: 210, spread: 18 })}" fill="url(#padGreen)" opacity="0.85"/>
    <path d="${pad(108, 110, 84, { notch: 62 })}" fill="${P.hopGreenDeep}" opacity="0.5"/>
    <path d="${pad(108, 105, 84, { notch: 62 })}" fill="url(#padGreenLight)"/>
    <g stroke="${P.hopGreenSoft}" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.32">
      <path d="M 108 105 l 52 -22"/><path d="M 108 105 l 6 -34"/><path d="M 108 105 l -56 -13"/><path d="M 108 105 l -28 28"/>
    </g>
    <ellipse cx="80" cy="90" rx="30" ry="9" fill="#FFFFFF" opacity="0.18"/>`,

  lilyFlower: () => `
    <ellipse cx="100" cy="148" rx="58" ry="13" fill="${P.pondBlueInk}" opacity="0.1"/>
    <path d="${pad(100, 140, 62, { notch: 90, spread: 15 })}" fill="url(#padGreenLight)"/>
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
      <path d="${blade(64, 180, 96, 34, 10)}"/><path d="${blade(136, 180, 84, -32, 10)}"/>
    </g>
    ${[[80, 62, 0.94, 5], [104, 40, 1.1, 0], [126, 76, 0.86, -5]].map(([x, top, s, lean]) => `
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
    <path d="M 46 100 q -22 -30 -30 -34 q 4 34 0 68 q 10 -6 30 -34 Z" fill="${P.peachDeep}"/>
    <ellipse cx="106" cy="100" rx="64" ry="38" fill="url(#peachBall)"/>
    <path d="M 96 66 q 18 -22 40 -14 q -14 12 -18 22 Z" fill="${P.peachDeep}" opacity="0.85"/>
    <path d="M 90 134 q 14 18 34 12 q -12 -10 -16 -18 Z" fill="${P.peachDeep}" opacity="0.7"/>
    <ellipse cx="118" cy="92" rx="30" ry="16" fill="#FFFFFF" opacity="0.28"/>
    <circle cx="142" cy="94" r="9" fill="#FFFFFF"/><circle cx="144" cy="94" r="5" fill="${P.midnight}"/>`,

  fishBlue: () => g('translate(200 0) scale(-1 1)', `
    <path d="M 46 100 q -22 -30 -30 -34 q 4 34 0 68 q 10 -6 30 -34 Z" fill="${P.pondBlueDeep}"/>
    <ellipse cx="106" cy="100" rx="60" ry="36" fill="url(#blueBall)"/>
    <path d="M 96 68 q 18 -22 40 -14 q -14 12 -18 22 Z" fill="${P.pondBlueDeep}" opacity="0.85"/>
    <ellipse cx="118" cy="92" rx="28" ry="15" fill="#FFFFFF" opacity="0.3"/>
    <circle cx="140" cy="94" r="9" fill="#FFFFFF"/><circle cx="142" cy="94" r="5" fill="${P.midnight}"/>`),

  tadpoleFriend: () => `
    <path d="M 96 96 q -34 -6 -54 -30 q 10 30 -2 58 q 26 -18 56 -12 Z" fill="${P.hopGreenDeep}" opacity="0.9"/>
    <circle cx="118" cy="96" r="42" fill="url(#greenBall)"/>
    <ellipse cx="106" cy="82" rx="20" ry="12" fill="#FFFFFF" opacity="0.3"/>
    <circle cx="134" cy="86" r="11" fill="#FFFFFF"/><circle cx="136" cy="87" r="6" fill="${P.midnight}"/>
    <path d="M 126 114 q 14 8 26 -2" fill="none" stroke="${P.hopGreenInk}" stroke-width="5" stroke-linecap="round" opacity="0.8"/>`,

  butterflyBlue: () => `
    ${g('translate(100 104)', `
      ${wing(74, 52, -22, 'url(#blueBall)', 0.95)}
      ${g('scale(-1 1)', wing(74, 52, -22, 'url(#blueBall)', 0.95))}
      ${wing(48, 36, -152, P.pondBlueLight, 0.95)}
      ${g('scale(-1 1)', wing(48, 36, -152, P.pondBlueLight, 0.95))}
      <ellipse cx="0" cy="4" rx="8" ry="34" fill="${P.night600}"/>
      <circle cx="0" cy="-32" r="10" fill="${P.night600}"/>
      <path d="M -3 -40 q -12 -14 -20 -18" stroke="${P.night600}" stroke-width="4" fill="none" stroke-linecap="round"/>
      <path d="M 3 -40 q 12 -14 20 -18" stroke="${P.night600}" stroke-width="4" fill="none" stroke-linecap="round"/>
      <circle cx="-30" cy="-34" r="9" fill="#FFFFFF" opacity="0.45"/><circle cx="30" cy="-34" r="9" fill="#FFFFFF" opacity="0.45"/>`)}`,

  butterflyYellow: () => `
    ${g('translate(100 104)', `
      ${wing(72, 50, -24, 'url(#yellowBall)', 0.95)}
      ${g('scale(-1 1)', wing(72, 50, -24, 'url(#yellowBall)', 0.95))}
      ${wing(46, 34, -150, P.sunshineSoft, 0.98)}
      ${g('scale(-1 1)', wing(46, 34, -150, P.sunshineSoft, 0.98))}
      <ellipse cx="0" cy="4" rx="8" ry="33" fill="${P.woodDeep}"/>
      <circle cx="0" cy="-31" r="10" fill="${P.woodDeep}"/>
      <path d="M -3 -39 q -12 -14 -20 -18" stroke="${P.woodDeep}" stroke-width="4" fill="none" stroke-linecap="round"/>
      <path d="M 3 -39 q 12 -14 20 -18" stroke="${P.woodDeep}" stroke-width="4" fill="none" stroke-linecap="round"/>
      <circle cx="-29" cy="-33" r="9" fill="${P.peachSoft}" opacity="0.8"/><circle cx="29" cy="-33" r="9" fill="${P.peachSoft}" opacity="0.8"/>`)}`,

  dragonfly: () => `
    ${g('translate(100 100)', `
      ${g('rotate(-16)', `<ellipse cx="46" cy="-24" rx="48" ry="15" fill="${P.lavender}" opacity="0.55"/>`)}
      ${g('rotate(16)', `<ellipse cx="-46" cy="-24" rx="48" ry="15" fill="${P.lavender}" opacity="0.55"/>`)}
      ${g('rotate(14)', `<ellipse cx="40" cy="12" rx="42" ry="12" fill="${P.pondBlueLight}" opacity="0.5"/>`)}
      ${g('rotate(-14)', `<ellipse cx="-40" cy="12" rx="42" ry="12" fill="${P.pondBlueLight}" opacity="0.5"/>`)}
      <rect x="-7" y="-34" width="14" height="82" rx="7" fill="url(#lavenderBall)"/>
      <circle cx="0" cy="-38" r="17" fill="${P.lavenderDeep}"/>
      <circle cx="-6" cy="-42" r="6" fill="#FFFFFF" opacity="0.7"/>`)}`,

  snail: () => `
    <ellipse cx="104" cy="146" rx="66" ry="12" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 54 138 q -22 -4 -22 -22 q 0 -16 16 -18 q 14 -2 18 10 l 8 26 Z" fill="url(#greenBall)"/>
    <path d="M 36 100 q -4 -22 6 -32" stroke="${P.hopGreenDeep}" stroke-width="6" stroke-linecap="round" fill="none"/>
    <circle cx="42" cy="64" r="8" fill="${P.hopGreenDeep}"/><circle cx="41" cy="63" r="3.4" fill="#FFFFFF"/>
    <path d="M 46 132 q 34 14 76 0 q 20 -6 20 -6" stroke="url(#greenBall)" stroke-width="26" stroke-linecap="round" fill="none"/>
    <circle cx="112" cy="98" r="46" fill="url(#peachBall)"/>
    <path d="M 112 98 m 0 -32 a 32 32 0 1 1 -22 55 a 22 22 0 1 1 26 -36 a 12 12 0 1 0 -14 20"
      fill="none" stroke="${P.peachSoft}" stroke-width="9" stroke-linecap="round" opacity="0.85"/>`,

  ladybug: () => `
    <ellipse cx="100" cy="142" rx="56" ry="11" fill="${P.midnight}" opacity="0.1"/>
    <ellipse cx="100" cy="104" rx="62" ry="52" fill="url(#peachBall)"/>
    <path d="M 100 52 a 62 52 0 0 0 0 104 Z" fill="#FFFFFF" opacity="0.12"/>
    <path d="M 100 52 L 100 156" stroke="${P.peachInk}" stroke-width="6" opacity="0.55"/>
    <path d="M 100 52 a 62 52 0 0 1 -58 -40 q 26 -14 58 -8 q 32 -6 58 8 a 62 52 0 0 1 -58 40 Z" fill="${P.night700}"/>
    <circle cx="80" cy="30" r="7" fill="#FFFFFF"/><circle cx="120" cy="30" r="7" fill="#FFFFFF"/>
    <circle cx="80" cy="30" r="3.4" fill="${P.night900}"/><circle cx="120" cy="30" r="3.4" fill="${P.night900}"/>
    <g fill="${P.peachInk}" opacity="0.75">
      <circle cx="74" cy="86" r="11"/><circle cx="126" cy="86" r="11"/>
      <circle cx="70" cy="124" r="9"/><circle cx="130" cy="124" r="9"/>
    </g>`,

  rainbow: () => {
    const bands = [P.peach, P.sunshine, P.hopGreen, P.pondBlue, P.lavender];
    return `<g fill="none" stroke-linecap="round" opacity="0.9">
      ${bands.map((c, i) => `<path d="M ${18 + i * 15} 150 a ${82 - i * 15} ${82 - i * 15} 0 0 1 ${164 - i * 30} 0" stroke="${c}" stroke-width="14" opacity="${R(0.92 - i * 0.04)}"/>`).join('')}
    </g>
    ${cloud(38, 154, 74, { opacity: 0.95 })}
    ${cloud(162, 154, 74, { opacity: 0.95 })}`;
  },

  sunbeam: () => `
    <circle cx="100" cy="100" r="86" fill="url(#sunGlow)"/>
    ${Array.from({ length: 8 }, (_, i) => g(`translate(100 100) rotate(${i * 45 + 22})`,
      `<path d="M -10 -46 L 10 -46 L 5 -94 L -5 -94 Z" fill="url(#beamFade)"/>`)).join('')}
    <circle cx="100" cy="100" r="46" fill="url(#sunDisc)"/>
    <circle cx="86" cy="86" r="16" fill="#FFFFFF" opacity="0.35"/>`,

  cloudPuff: () => `${cloud(100, 100, 160)}
    <ellipse cx="86" cy="86" rx="34" ry="16" fill="#FFFFFF" opacity="0.75"/>`,

  frogFriendGreen: () => `
    <ellipse cx="100" cy="176" rx="56" ry="11" fill="${P.midnight}" opacity="0.12"/>
    ${placeFrog(100, 96, 196, frog({ squash: 0.12, gaze: [8, 10], smile: 0.9 }))}`,

  frogFriendBlue: () => `
    <ellipse cx="100" cy="176" rx="56" ry="11" fill="${P.midnight}" opacity="0.12"/>
    ${placeFrog(100, 96, 190, frog({
      skin: HOP_BLUE, grad: 'hopBodyBlue', dome: 'hopEyeDomeBlue', squash: 0.16,
      gaze: [-8, 10], open: 0.5, arms: [[126, 320, -120, 46], [388, 340, 24]],
    }))}`,

  clubhouse: () => `
    <ellipse cx="100" cy="176" rx="76" ry="12" fill="${P.midnight}" opacity="0.12"/>
    <path d="M 34 116 q 0 -14 14 -14 h 104 q 14 0 14 14 v 44 q 0 12 -12 12 h -108 q -12 0 -12 -12 Z" fill="url(#woodGrad)"/>
    <path d="M 100 30 L 178 100 q 8 8 -4 8 H 26 q -12 0 -4 -8 Z" fill="url(#greenBall)"/>
    <path d="M 100 46 L 160 100 H 40 Z" fill="#FFFFFF" opacity="0.14"/>
    <path d="M 76 172 v -44 q 0 -24 24 -24 q 24 0 24 24 v 44 Z" fill="${P.woodDeep}"/>
    <circle cx="115" cy="146" r="4.6" fill="${P.sunshine}"/>
    <rect x="44" y="118" width="24" height="24" rx="8" fill="${P.pondBlueSoft}"/>
    <rect x="132" y="118" width="24" height="24" rx="8" fill="${P.pondBlueSoft}"/>
    <path d="M 30 108 h 140" stroke="${P.woodDeep}" stroke-width="6" stroke-linecap="round" opacity="0.5"/>`,

  lantern: () => `
    <path d="M 100 8 v 22" stroke="${P.woodDeep}" stroke-width="6" stroke-linecap="round"/>
    <path d="M 78 30 q 22 -16 44 0 Z" fill="${P.woodDeep}"/>
    <rect x="72" y="28" width="56" height="10" rx="5" fill="${P.woodDeep}"/>
    <circle cx="100" cy="98" r="66" fill="url(#glowWarm)"/>
    <path d="M 78 40 q 22 -8 44 0 v 60 q 0 22 -22 22 q -22 0 -22 -22 Z" fill="url(#yellowBall)"/>
    <path d="M 84 44 q 8 -3 16 -3 v 74 q -16 -2 -16 -20 Z" fill="#FFFFFF" opacity="0.4"/>
    <rect x="70" y="118" width="60" height="12" rx="6" fill="${P.woodDeep}"/>
    <circle cx="100" cy="138" r="6" fill="${P.woodDeep}"/>`,

  signpost: () => `
    <ellipse cx="100" cy="180" rx="52" ry="10" fill="${P.midnight}" opacity="0.12"/>
    <rect x="92" y="52" width="17" height="126" rx="8" fill="url(#woodGradV)"/>
    <path d="M 26 62 h 108 l 26 24 l -26 24 H 26 q -8 0 -8 -8 V 70 q 0 -8 8 -8 Z" fill="url(#woodGrad)"/>
    <path d="M 26 62 h 108 l 12 11 H 26 Z" fill="#FFFFFF" opacity="0.18"/>
    ${g('translate(72 86) scale(0.42)', `<path d="${pad(0, 6, 66, { notch: 52 })}" fill="${P.hopGreenSoft}"/>`)}
    <circle cx="112" cy="86" r="9" fill="${P.sunshineSoft}"/>
    <path d="M 60 178 q 20 -10 40 0" stroke="${P.hopGreenDeep}" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.5"/>`,

  waterLilyCluster: () => `
    <ellipse cx="100" cy="150" rx="88" ry="18" fill="${P.pondBlueInk}" opacity="0.1"/>
    <path d="${pad(52, 118, 50, { notch: 200 })}" fill="url(#padGreen)"/>
    <path d="${pad(148, 128, 44, { notch: 340 })}" fill="url(#padGreen)"/>
    <path d="${pad(100, 106, 62, { notch: 62 })}" fill="url(#padGreenLight)"/>
    ${Array.from({ length: 8 }, (_, i) => g(`translate(96 88) rotate(${i * 45 + 22})`, `<path d="${petal(40, 15)}" fill="url(#petalWhite)"/>`)).join('')}
    ${Array.from({ length: 5 }, (_, i) => g(`translate(96 88) rotate(${i * 72})`, `<path d="${petal(26, 11)}" fill="url(#petalPeach)"/>`)).join('')}
    <circle cx="96" cy="88" r="9" fill="${P.sunshine}"/>
    <circle cx="152" cy="112" r="7" fill="${P.peachSoft}"/>`,

  mushroomCluster: () => {
    const shroom = (x, y, s) => g(`translate(${x} ${y}) scale(${s})`, `
      <path d="M -16 0 q -4 44 0 52 q 16 6 32 0 q 4 -8 0 -52 Z" fill="${P.sand100}"/>
      <path d="M 0 -46 q 52 0 52 34 q 0 12 -14 12 h -76 q -14 0 -14 -12 q 0 -34 52 -34 Z" fill="url(#peachBall)"/>
      <circle cx="-18" cy="-16" r="9" fill="${P.cloud}" opacity="0.9"/>
      <circle cx="12" cy="-26" r="7" fill="${P.cloud}" opacity="0.9"/>
      <circle cx="28" cy="-8" r="6" fill="${P.cloud}" opacity="0.85"/>`);
    return `<ellipse cx="100" cy="164" rx="70" ry="12" fill="${P.midnight}" opacity="0.1"/>
      ${shroom(60, 118, 0.72)}${shroom(140, 124, 0.6)}${shroom(100, 108, 1)}`;
  },

  fernPatch: () => {
    const frond = (x, y, len, tilt, s) => g(`translate(${x} ${y}) rotate(${tilt}) scale(${s})`, `
      <path d="M 0 0 Q ${R(len * 0.1)} ${R(-len * 0.55)} 0 ${R(-len)}" stroke="${P.hopGreenDeep}" stroke-width="6" fill="none" stroke-linecap="round"/>
      ${Array.from({ length: 6 }, (_, i) => {
        const t = i / 5, yy = -len * (0.16 + t * 0.76), w = 30 * (1 - t * 0.72);
        return `<ellipse cx="${R(-w * 0.7)}" cy="${R(yy)}" rx="${R(w)}" ry="${R(w * 0.42)}" fill="url(#fernGreen)" transform="rotate(${R(-22 - t * 12)} ${R(-w * 0.7)} ${R(yy)})"/>
                <ellipse cx="${R(w * 0.7)}" cy="${R(yy)}" rx="${R(w)}" ry="${R(w * 0.42)}" fill="url(#fernGreen)" transform="rotate(${R(22 + t * 12)} ${R(w * 0.7)} ${R(yy)})"/>`;
      }).join('')}`);
    return `${frond(62, 176, 118, -18, 0.9)}${frond(140, 176, 106, 20, 0.85)}${frond(100, 180, 148, 0, 1)}`;
  },

  duckling: () => `
    <ellipse cx="100" cy="150" rx="70" ry="14" fill="${P.pondBlueInk}" opacity="0.12"/>
    <path d="M 34 132 q 6 -50 62 -50 q 56 0 62 50 q -62 20 -124 0 Z" fill="url(#yellowBall)"/>
    <circle cx="130" cy="78" r="36" fill="url(#yellowBall)"/>
    <circle cx="119" cy="66" r="13" fill="#FFF6D4" opacity="0.7"/>
    <path d="M 160 78 q 22 -6 22 8 q 0 12 -22 8 Z" fill="${P.peach}"/>
    <circle cx="142" cy="70" r="8" fill="#FFFFFF"/><circle cx="144" cy="71" r="4.6" fill="${P.midnight}"/>
    <path d="M 62 108 q 26 -14 48 4 q -22 20 -48 -4 Z" fill="${P.sunshineBright}" opacity="0.85"/>
    <path d="M 40 140 q 60 20 120 0" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.5"/>`,

  turtleRock: () => `
    <ellipse cx="100" cy="158" rx="80" ry="16" fill="${P.pondBlueInk}" opacity="0.12"/>
    ${pebble(100, 140, 78, 30)}
    <path d="M 34 108 q 4 -46 66 -46 q 62 0 66 46 Z" fill="url(#greenBall)"/>
    <g fill="${P.hopGreenSoft}" opacity="0.5">
      <path d="M 100 68 l 18 12 l -8 20 h -20 l -8 -20 Z"/>
      <path d="M 60 92 l 16 8 l -6 8 h -20 Z"/><path d="M 140 92 l -16 8 l 6 8 h 20 Z"/>
    </g>
    <circle cx="160" cy="104" r="17" fill="${P.hopGreenLight}"/>
    <circle cx="166" cy="100" r="5" fill="${P.midnight}"/>
    <path d="M 160 110 q 10 4 14 -2" stroke="${P.hopGreenInk}" stroke-width="3.4" stroke-linecap="round" fill="none"/>
    <ellipse cx="52" cy="110" rx="16" ry="9" fill="${P.hopGreenLight}"/>`,

  starLantern: () => {
    const star = (cx, cy, r, inner, fill) => {
      const pts = Array.from({ length: 10 }, (_, i) => {
        const rr = i % 2 ? inner : r;
        const a = (Math.PI / 5) * i - Math.PI / 2;
        return `${R(cx + rr * Math.cos(a))} ${R(cy + rr * Math.sin(a))}`;
      });
      return `<path d="M ${pts.join(' L ')} Z" fill="${fill}" stroke="${fill}" stroke-width="14" stroke-linejoin="round"/>`;
    };
    return `<path d="M 100 8 v 26" stroke="${P.woodDeep}" stroke-width="6" stroke-linecap="round"/>
      <circle cx="100" cy="106" r="82" fill="url(#glowWarm)"/>
      ${star(100, 106, 66, 30, P.sunshine)}
      ${star(96, 100, 40, 18, '#FFF0C2')}`;
  },

  windChime: () => `
    <path d="M 100 12 v 20" stroke="${P.woodDeep}" stroke-width="5" stroke-linecap="round"/>
    <ellipse cx="100" cy="42" rx="52" ry="14" fill="url(#woodGrad)"/>
    <ellipse cx="100" cy="38" rx="52" ry="14" fill="${P.woodLight}"/>
    ${[[58, 92, P.lavender], [82, 118, P.pondBlue], [118, 108, P.sunshine], [142, 84, P.peach]].map(([x, len, c]) => `
      <path d="M ${x} 44 v ${R(len - 40)}" stroke="${P.sand300}" stroke-width="3" opacity="0.8"/>
      <rect x="${x - 8}" y="${R(len - 4)}" width="16" height="52" rx="8" fill="${c}"/>
      <rect x="${x - 8}" y="${R(len - 4)}" width="6" height="52" rx="3" fill="#FFFFFF" opacity="0.35"/>`).join('')}
    <path d="M 100 44 v 96" stroke="${P.sand300}" stroke-width="3" opacity="0.8"/>
    ${g('translate(100 158)', `<path d="${pad(0, 0, 26, { notch: 90, spread: 26 })}" fill="url(#padGreen)"/>`)}`,

  birdhouse: () => `
    <rect x="92" y="120" width="16" height="62" rx="8" fill="url(#woodGradV)"/>
    <path d="M 44 76 q 0 -12 14 -12 h 84 q 14 0 14 12 v 46 q 0 12 -14 12 h -84 q -14 0 -14 -12 Z" fill="url(#woodGrad)"/>
    <path d="M 100 18 L 172 72 q 8 6 -2 6 H 30 q -10 0 -2 -6 Z" fill="url(#peachBall)"/>
    <circle cx="100" cy="94" r="21" fill="${P.woodDeep}"/>
    <circle cx="100" cy="90" r="15" fill="${P.night800}" opacity="0.55"/>
    <rect x="94" y="112" width="12" height="20" rx="6" fill="${P.woodDeep}"/>
    <circle cx="146" cy="52" r="16" fill="${P.sunshine}"/>
    <circle cx="152" cy="48" r="4" fill="${P.midnight}"/>
    <path d="M 160 54 q 12 -2 12 4 q -8 4 -12 0 Z" fill="${P.peach}"/>`,

  pebblePath: () => `
    ${pebble(38, 128, 34, 15, { fill: 'url(#stoneGrad)' })}
    ${pebble(96, 138, 42, 18, { fill: 'url(#stoneGradCool)' })}
    ${pebble(158, 126, 32, 14, { fill: 'url(#stoneGrad)' })}
    ${pebble(66, 100, 28, 12, { fill: 'url(#stoneGradCool)' })}
    ${pebble(128, 96, 30, 13, { fill: 'url(#stoneGrad)' })}
    ${pebble(98, 70, 24, 11, { fill: 'url(#stoneGradCool)' })}`,

  driftwood: () => `
    <ellipse cx="100" cy="146" rx="82" ry="12" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 22 116 q -6 -30 24 -32 q 40 -4 76 -2 q 34 2 56 6 q 22 4 20 18 q -2 14 -24 16 q -40 4 -80 2 q -40 -2 -72 -8 Z" fill="url(#woodGrad)"/>
    <path d="M 40 96 q 60 -8 130 4" stroke="${P.woodLight}" stroke-width="7" stroke-linecap="round" fill="none" opacity="0.65"/>
    <ellipse cx="42" cy="104" rx="12" ry="16" fill="${P.woodDeep}" opacity="0.55"/>
    <g fill="url(#bladeGreen)">
      <path d="${blade(140, 88, 46, 12, 7)}"/><path d="${blade(154, 90, 34, -10, 6)}"/>
    </g>`,

  blossomTree: () => `
    <ellipse cx="100" cy="184" rx="66" ry="12" fill="${P.midnight}" opacity="0.1"/>
    <path d="M 92 184 q -6 -52 -22 -74 q 20 12 26 26 q 2 -34 6 -50 q 8 20 8 52 q 12 -18 30 -26 q -20 22 -28 72 Z" fill="url(#woodGradV)"/>
    <circle cx="64" cy="76" r="40" fill="url(#blossomCloud)"/>
    <circle cx="136" cy="72" r="36" fill="url(#blossomCloud)"/>
    <circle cx="100" cy="46" r="44" fill="url(#blossomCloud)"/>
    <circle cx="98" cy="94" r="30" fill="url(#blossomCloud)"/>
    <g fill="${P.peach}" opacity="0.5">
      <circle cx="72" cy="52" r="6"/><circle cx="120" cy="46" r="5"/><circle cx="98" cy="80" r="5"/><circle cx="46" cy="86" r="5"/>
    </g>
    <g fill="${P.peachSoft}">
      <ellipse cx="148" cy="128" rx="7" ry="4.6" transform="rotate(28 148 128)"/>
      <ellipse cx="52" cy="140" rx="6" ry="4" transform="rotate(-24 52 140)"/>
      <ellipse cx="124" cy="158" rx="5.6" ry="3.6" transform="rotate(14 124 158)"/>
    </g>`,

  fireflies: () => {
    const fly = (x, y, r, o) => `<circle cx="${x}" cy="${y}" r="${R(r * 3.4)}" fill="url(#glowWarm)" opacity="${o}"/>
      <circle cx="${x}" cy="${y}" r="${r}" fill="#FFF3C8"/>`;
    return `${fly(58, 62, 9, 0.95)}${fly(132, 44, 7, 0.8)}${fly(96, 108, 10, 1)}
      ${fly(150, 128, 7.4, 0.85)}${fly(50, 150, 6, 0.7)}${fly(112, 168, 5.4, 0.6)}`;
  },

  moonReflection: () => `
    <g opacity="0.9">
      <ellipse cx="100" cy="100" rx="74" ry="70" fill="url(#moonGlow)"/>
      <path d="M 46 62 q 54 -16 108 0 q -54 18 -108 0 Z" fill="${P.sunshineSoft}" opacity="0.85"/>
      <path d="M 34 96 q 66 -20 132 0 q -66 20 -132 0 Z" fill="${P.sunshineSoft}" opacity="0.95"/>
      <path d="M 46 130 q 54 -16 108 0 q -54 18 -108 0 Z" fill="${P.sunshineSoft}" opacity="0.8"/>
      <path d="M 62 158 q 38 -12 76 0 q -38 12 -76 0 Z" fill="${P.sunshineSoft}" opacity="0.6"/>
    </g>`,

  pondSwing: () => `
    <path d="M 20 22 q 80 -14 160 0" stroke="url(#woodGrad)" stroke-width="14" stroke-linecap="round" fill="none"/>
    <path d="M 56 26 v 96" stroke="${P.sand300}" stroke-width="7" stroke-linecap="round"/>
    <path d="M 144 26 v 96" stroke="${P.sand300}" stroke-width="7" stroke-linecap="round"/>
    <rect x="40" y="120" width="120" height="26" rx="13" fill="url(#woodGrad)"/>
    <rect x="40" y="120" width="120" height="10" rx="5" fill="${P.woodLight}" opacity="0.6"/>
    <g fill="${P.hopGreen}" opacity="0.85">
      <ellipse cx="34" cy="18" rx="16" ry="9" transform="rotate(-18 34 18)"/>
      <ellipse cx="166" cy="20" rx="14" ry="8" transform="rotate(16 166 20)"/>
      <ellipse cx="100" cy="12" rx="13" ry="7"/>
    </g>
    <circle cx="100" cy="160" r="8" fill="${P.peach}" opacity="0.6"/>`,
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

/** The shared bathroom set: soft wall, skirting, floor. Every step stands in it. */
function bathroom({ floorY = 348, wall = 'url(#tileWall)' } = {}) {
  return `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="${wall}"/>
    <circle cx="120" cy="112" r="86" fill="${P.pondBlueSoft}" opacity="0.55"/>
    <circle cx="548" cy="86" r="58" fill="${P.sunshineSoft}" opacity="0.6"/>
    <rect x="0" y="${floorY}" width="${SW}" height="${SH - floorY}" fill="${P.sand100}"/>
    <rect x="0" y="${floorY - 12}" width="${SW}" height="16" rx="8" fill="${P.sand200}"/>`;
}
const contactShadow = (cx, cy, rx, ry = rx * 0.2) =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${R(ry)}" fill="url(#softShadow)"/>`;

/** The child-height potty: a rounded shell, a seat ring and a low back rest. */
function pottyChair(cx, baseY, s = 1) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 6, 132, 22)}
    <path d="M -104 -78 q 0 -22 22 -22 h 164 q 22 0 22 22 v 34 q 0 56 -104 56 q -104 0 -104 -56 Z" fill="url(#greenBall)"/>
    <path d="M -96 -74 q 0 -14 14 -14 h 148 q 14 0 14 14 v 8 q -88 22 -176 0 Z" fill="#FFFFFF" opacity="0.22"/>
    <ellipse cx="0" cy="-96" rx="112" ry="34" fill="${P.hopGreenDeep}"/>
    <ellipse cx="0" cy="-100" rx="112" ry="34" fill="url(#padGreenLight)"/>
    <ellipse cx="0" cy="-100" rx="62" ry="17" fill="${P.hopGreenInk}" opacity="0.35"/>
    <ellipse cx="0" cy="-102" rx="62" ry="17" fill="${P.pondBlueSoft}" opacity="0.5"/>
    <path d="M -96 -108 q -14 -66 34 -66 h 124 q 48 0 34 66 q -96 -20 -192 0 Z" fill="url(#greenBall)"/>
    <path d="M -76 -122 q -8 -36 22 -36 h 108 q 30 0 22 36 Z" fill="#FFFFFF" opacity="0.2"/>
    <ellipse cx="0" cy="-6" rx="92" ry="16" fill="${P.hopGreenInk}" opacity="0.2"/>`);
}

/** A grown-up toilet, three-quarter side view. Shared by Flush and the quiz. */
function toilet(cx, baseY, s = 1, { lidOpen = true } = {}) {
  return g(`translate(${cx} ${baseY}) scale(${s})`, `
    ${contactShadow(0, 6, 130, 22)}
    <path d="M -46 0 q -22 0 -18 -22 l 14 -78 h 108 l 12 78 q 4 22 -18 22 Z" fill="url(#porcelainSide)"/>
    <path d="M -96 -190 q 0 -26 30 -26 h 116 q 34 0 34 30 q 0 54 -84 54 q -96 0 -96 -58 Z" fill="url(#porcelainGrad)"/>
    <ellipse cx="-4" cy="-196" rx="96" ry="34" fill="${P.porcelainShade}"/>
    <ellipse cx="-4" cy="-202" rx="96" ry="34" fill="url(#porcelainGrad)"/>
    <ellipse cx="-4" cy="-202" rx="62" ry="20" fill="${P.pondBlueSoft}"/>
    ${lidOpen ? `<path d="M 62 -228 q 56 -30 74 22 q 16 46 -30 62 q -18 6 -26 -12 q 22 -12 12 -40 q -8 -22 -30 -32 Z" fill="url(#porcelainGrad)"/>` : ''}
    <path d="M 74 -300 q 0 -22 22 -22 h 66 q 22 0 22 22 v 96 q 0 20 -22 20 h -66 q -22 0 -22 -20 Z" fill="url(#porcelainGrad)"/>
    <rect x="96" y="-288" width="34" height="14" rx="7" fill="${P.pondBlueLight}"/>`);
}

const scenes = {
  'step-try': () => `
    ${bathroom()}
    <rect x="404" y="196" width="180" height="152" rx="26" fill="${P.pondBlueSoft}"/>
    <rect x="404" y="196" width="180" height="152" rx="26" fill="url(#iconWell)"/>
    <path d="M 494 196 v 152 M 404 272 h 180" stroke="#FFFFFF" stroke-width="10" opacity="0.85"/>
    <ellipse cx="150" cy="428" rx="118" ry="24" fill="${P.lavenderSoft}"/>
    ${pottyChair(300, 404, 1)}
    ${g('translate(126 372) scale(0.36)', frog({ gaze: [10, 8], smile: 0.85 }))}
    <g opacity="0.75">
      <circle cx="560" cy="404" r="30" fill="${P.hopGreenSoft}"/>
      <path d="${blade(560, 408, 54, 12, 9)}" fill="url(#bladeGreen)"/>
      <path d="${blade(548, 410, 38, -10, 8)}" fill="url(#bladeGreen)"/>
    </g>`,

  'step-wipe': () => `
    ${bathroom()}
    <rect x="140" y="150" width="360" height="26" rx="13" fill="${P.sand200}"/>
    <rect x="150" y="176" width="20" height="60" rx="10" fill="${P.sand300}"/>
    <rect x="470" y="176" width="20" height="60" rx="10" fill="${P.sand300}"/>
    ${contactShadow(320, 430, 150, 26)}
    <path d="M 190 238 h 260 q 26 0 26 26 v 96 q 0 26 -26 26 h -260 Z" fill="${P.porcelainMid}"/>
    <path d="M 450 238 q 26 0 26 26 v 96 q 0 26 -26 26 q -26 0 -26 -26 v -96 q 0 -26 26 -26 Z" fill="url(#porcelainGrad)"/>
    <ellipse cx="190" cy="312" rx="34" ry="74" fill="url(#porcelainGrad)"/>
    <ellipse cx="190" cy="312" rx="14" ry="30" fill="${P.sand200}"/>
    <ellipse cx="190" cy="312" rx="8" ry="18" fill="${P.sand300}"/>
    <path d="M 300 386 q -6 46 8 74 q -34 8 -62 -4 q 18 -34 14 -70 Z" fill="url(#porcelainGrad)"/>
    <path d="M 258 456 q 26 10 50 4" stroke="${P.sand200}" stroke-width="6" fill="none" stroke-linecap="round"/>
    <g opacity="0.5">
      <circle cx="536" cy="258" r="11" fill="${P.lavender}"/>
      <circle cx="566" cy="298" r="7" fill="${P.pondBlue}"/>
      <circle cx="516" cy="308" r="6" fill="${P.peach}"/>
    </g>`,

  'step-flush': () => `
    ${bathroom()}
    ${toilet(300, 424, 0.92)}
    <g opacity="0.95">
      <path d="M 236 220 q 60 -26 120 0 q -60 26 -120 0 Z" fill="${P.pondBlueLight}" opacity="0.45"/>
      <path d="M 296 230 m -66 0 a 66 30 0 1 1 96 26" fill="none" stroke="url(#waterStream)" stroke-width="16" stroke-linecap="round"/>
      <path d="M 296 244 m -42 0 a 42 19 0 1 1 62 16" fill="none" stroke="url(#waterStream)" stroke-width="13" stroke-linecap="round" opacity="0.8"/>
      <path d="M 296 256 m -20 0 a 20 9 0 1 1 30 8" fill="none" stroke="url(#waterStream)" stroke-width="10" stroke-linecap="round" opacity="0.6"/>
      <circle cx="228" cy="196" r="10" fill="${P.pondBlueLight}" opacity="0.7"/>
      <circle cx="374" cy="214" r="7" fill="${P.pondBlueLight}" opacity="0.6"/>
      <circle cx="352" cy="176" r="5" fill="${P.pondBlue}" opacity="0.5"/>
    </g>`,

  'step-wash': () => `
    ${bathroom({ floorY: 400 })}
    <rect x="96" y="196" width="212" height="34" rx="17" fill="${P.sand200}"/>
    <path d="M 250 196 v -46 q 0 -34 -34 -34 h -70" stroke="url(#porcelainSide)" stroke-width="26" fill="none" stroke-linecap="round"/>
    <rect x="112" y="102" width="46" height="28" rx="14" fill="${P.pondBlueLight}"/>
    <rect x="228" y="196" width="44" height="30" rx="12" fill="${P.porcelainShade}"/>
    <path d="M 250 226 q -10 74 -6 118" stroke="url(#waterStream)" stroke-width="30" stroke-linecap="round" fill="none" opacity="0.75"/>
    <path d="M 244 236 q -6 60 -4 96" stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" fill="none" opacity="0.5"/>
    <g>
      ${g('translate(196 372) rotate(-12)', `
        <path d="M 0 0 q -8 -56 26 -74 q 34 -18 62 4 q 26 20 20 60 q -6 40 -54 42 q -46 2 -54 -32 Z" fill="url(#handGrad)"/>
        <rect x="-4" y="-84" width="26" height="46" rx="13" fill="url(#handGrad)"/>
        <rect x="22" y="-96" width="26" height="58" rx="13" fill="url(#handGrad)"/>
        <rect x="48" y="-92" width="26" height="54" rx="13" fill="url(#handGrad)"/>
        <rect x="72" y="-72" width="24" height="40" rx="12" fill="url(#handGrad)"/>`)}
      ${g('translate(340 380) scale(-1 1) rotate(-14)', `
        <path d="M 0 0 q -8 -56 26 -74 q 34 -18 62 4 q 26 20 20 60 q -6 40 -54 42 q -46 2 -54 -32 Z" fill="url(#handGradDeep)"/>
        <rect x="-4" y="-84" width="26" height="46" rx="13" fill="url(#handGradDeep)"/>
        <rect x="22" y="-96" width="26" height="58" rx="13" fill="url(#handGradDeep)"/>
        <rect x="48" y="-92" width="26" height="54" rx="13" fill="url(#handGradDeep)"/>
        <rect x="72" y="-72" width="24" height="40" rx="12" fill="url(#handGradDeep)"/>`)}
    </g>
    <g>
      <circle cx="188" cy="286" r="26" fill="url(#bubbleFill)"/>
      <circle cx="352" cy="256" r="20" fill="url(#bubbleFill)"/>
      <circle cx="404" cy="330" r="28" fill="url(#bubbleFill)"/>
      <circle cx="150" cy="352" r="17" fill="url(#bubbleFill)"/>
      <circle cx="392" cy="404" r="15" fill="url(#bubbleFill)"/>
      <circle cx="286" cy="222" r="13" fill="url(#bubbleFill)"/>
    </g>`,

  'step-highfive': () => `
    <rect x="0" y="0" width="${SW}" height="${SH}" fill="${P.hopGreenSoft}"/>
    <circle cx="320" cy="232" r="176" fill="#FFFFFF" opacity="0.55"/>
    <circle cx="320" cy="232" r="120" fill="url(#glowWarm)" opacity="0.65"/>
    ${g('translate(214 268) rotate(16)', `
      <path d="M 0 0 q -10 -62 28 -82 q 38 -20 70 4 q 30 22 22 66 q -8 44 -60 46 q -50 2 -60 -34 Z" fill="url(#handGrad)"/>
      <rect x="-6" y="-96" width="30" height="52" rx="15" fill="url(#handGrad)"/>
      <rect x="24" y="-110" width="30" height="66" rx="15" fill="url(#handGrad)"/>
      <rect x="54" y="-106" width="30" height="62" rx="15" fill="url(#handGrad)"/>
      <rect x="82" y="-82" width="28" height="46" rx="14" fill="url(#handGrad)"/>`)}
    ${g('translate(430 268) scale(-1 1) rotate(16)', `
      <path d="M 0 0 q -10 -62 28 -82 q 38 -20 70 4 q 30 22 22 66 q -8 44 -60 46 q -50 2 -60 -34 Z" fill="${HOP.bodyMid}"/>
      <rect x="-6" y="-96" width="30" height="52" rx="15" fill="${HOP.bodyMid}"/>
      <rect x="24" y="-110" width="30" height="66" rx="15" fill="${HOP.bodyMid}"/>
      <rect x="54" y="-106" width="30" height="62" rx="15" fill="${HOP.bodyMid}"/>
      <rect x="82" y="-82" width="28" height="46" rx="14" fill="${HOP.bodyMid}"/>
      <path d="M 20 -30 q 40 16 78 -6" stroke="${HOP.bodyDeep}" stroke-width="8" fill="none" stroke-linecap="round" opacity="0.35"/>`)}
    <g fill="${P.sunshine}">
      ${[[152, 120, 20], [498, 132, 17], [320, 62, 22], [110, 260, 14], [538, 268, 15], [250, 84, 12], [400, 96, 13]]
        .map(([x, y, r]) => `<path d="M ${x} ${y - r} q ${R(r * 0.28)} ${R(r * 0.72)} ${r} ${r} q ${R(-r * 0.72)} ${R(r * 0.28)} ${-r} ${r} q ${R(-r * 0.28)} ${R(-r * 0.72)} ${-r} ${-r} q ${R(r * 0.72)} ${R(-r * 0.28)} ${r} ${-r} Z"/>`).join('')}
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
    ${g('translate(0 -140) scale(0.62)', `<path d="${pad(0, 0, 62, { notch: 52 })}" fill="${P.hopGreenSoft}"/>`)}
    <circle cx="34" cy="-72" r="9" fill="${P.sunshineBright}"/>`);

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
    ${g('translate(430 636) scale(0.62) translate(-256 -440)', `
      ${hopBody({ squash: 0.05 })}
      ${hopSheen}
      ${hopArm(122, 330, 142)}${hopArm(392, 344, 46)}
      ${hopBelly()}
      ${hopFoot(204, 442, 1, 16)}${hopFoot(330, 436, -1)}
      ${hopEyes({ gaze: [13, 6] })}
      ${hopCheeks()}
      ${hopMouth({ open: 0.35 })}`)}
    <g fill="${P.hopGreenInk}" opacity="0.2">
      <path d="${blade(70, 700, 96, 24, 14)}"/><path d="${blade(120, 706, 70, -18, 11)}"/>
      <path d="${blade(1140, 692, 100, -24, 14)}"/><path d="${blade(1088, 698, 72, 18, 11)}"/>
    </g>
    ${flower(200, 604, 26, { fill: 'url(#yellowBall)', core: P.sunshineSoft, stemH: 46 })}
    ${flower(1010, 640, 24, { fill: 'url(#peachBall)', core: P.peachSoft, petals: 6, stemH: 44 })}
    ${g('translate(646 336)', `
      ${wing(46, 32, -24, P.lavender, 0.75)}${g('scale(-1 1)', wing(46, 32, -24, P.lavender, 0.75))}
      <ellipse cx="0" cy="2" rx="5" ry="20" fill="${P.night600}" opacity="0.8"/>`)}
    <ellipse cx="600" cy="700" rx="720" ry="90" fill="${P.hopGreenInk}" opacity="0.08"/>`;
  return svg({ viewBox: `0 0 ${W} ${H}`, width: W, height: H, body });
}

// ===========================================================================
// 4. QUIZ ANSWER ICONS  (120 x 120)
// ===========================================================================
/** Every quiz icon sits on the same soft tinted disc: it lifts the subject off
 *  the Cloud background and makes the set read as one family at tile size. */
const disc = (tint) => `<circle cx="60" cy="60" r="58" fill="${tint}"/>`;

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
    ${[[34, 1], [86, -1]].map(([x, f]) => g(`translate(${x} 90) scale(${f} 1)`, `
      <path d="M -20 0 q -8 -34 6 -46 q 16 -14 30 -2 q 12 10 10 30 q -2 22 -22 22 q -20 0 -24 -4 Z" fill="url(#handGrad)"/>
      <rect x="-22" y="-56" width="13" height="26" rx="6.5" fill="url(#handGrad)"/>
      <rect x="-9" y="-62" width="13" height="32" rx="6.5" fill="url(#handGrad)"/>
      <rect x="4" y="-60" width="13" height="30" rx="6.5" fill="url(#handGrad)"/>
      <rect x="16" y="-50" width="12" height="22" rx="6" fill="url(#handGrad)"/>
      <path d="M -24 -34 q 22 8 42 -2" stroke="${P.handDeep}" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.4"/>`)).join('')}`,

  toilet: () => `${disc(P.pondBlueSoft)}
    ${g('translate(58 104) scale(0.3)', `
      <path d="M -46 0 q -22 0 -18 -22 l 14 -78 h 108 l 12 78 q 4 22 -18 22 Z" fill="url(#porcelainSide)"/>
      <path d="M -96 -190 q 0 -26 30 -26 h 116 q 34 0 34 30 q 0 54 -84 54 q -96 0 -96 -58 Z" fill="url(#porcelainGrad)"/>
      <ellipse cx="-4" cy="-196" rx="96" ry="34" fill="${P.porcelainShade}"/>
      <ellipse cx="-4" cy="-202" rx="96" ry="34" fill="url(#porcelainGrad)"/>
      <ellipse cx="-4" cy="-202" rx="62" ry="20" fill="${P.pondBlueLight}"/>
      <path d="M 62 -228 q 56 -30 74 22 q 16 46 -30 62 q -18 6 -26 -12 q 22 -12 12 -40 q -8 -22 -30 -32 Z" fill="url(#porcelainGrad)"/>
      <path d="M 74 -300 q 0 -22 22 -22 h 66 q 22 0 22 22 v 96 q 0 20 -22 20 h -66 q -22 0 -22 -20 Z" fill="url(#porcelainGrad)"/>
      <rect x="96" y="-288" width="34" height="14" rx="7" fill="${P.pondBlue}"/>`)}`,

  'toilet-paper': () => `${disc(P.sunshineSoft)}
    <ellipse cx="60" cy="98" rx="30" ry="5" fill="${P.sunshineDeep}" opacity="0.12"/>
    <path d="M 42 34 h 30 q 20 0 20 22 v 34 q 0 12 -20 12 h -30 Z" fill="${P.porcelainMid}"/>
    <path d="M 72 34 q 20 0 20 22 v 34 q 0 12 -20 12 q -20 0 -20 -12 v -34 q 0 -22 20 -22 Z" fill="url(#porcelainGrad)"/>
    <ellipse cx="42" cy="61" rx="16" ry="27" fill="url(#porcelainGrad)"/>
    <ellipse cx="42" cy="61" rx="7" ry="12" fill="${P.sand200}"/>
    <ellipse cx="42" cy="61" rx="3.4" ry="6" fill="${P.sand300}"/>
    <path d="M 92 62 q 12 20 8 34 q -12 4 -20 -2 q 6 -16 2 -30 Z" fill="url(#porcelainGrad)"/>
    <path d="M 80 92 q 10 4 18 0" stroke="${P.sand200}" stroke-width="3" fill="none" stroke-linecap="round"/>`,

  towel: () => `${disc(P.pondBlueSoft)}
    <rect x="18" y="30" width="84" height="9" rx="4.5" fill="${P.sand300}"/>
    <path d="M 30 34 h 60 q 8 0 8 8 v 46 q 0 10 -10 10 h -56 q -10 0 -10 -10 v -46 q 0 -8 8 -8 Z" fill="url(#towelGrad)"/>
    <path d="M 30 34 h 26 v 64 h -18 q -10 0 -10 -10 v -46 q 0 -8 2 -8 Z" fill="#FFFFFF" opacity="0.3"/>
    <rect x="26" y="56" width="72" height="10" rx="5" fill="#FFFFFF" opacity="0.7"/>
    <path d="M 34 98 q 30 8 60 0" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" opacity="0.6"/>`,

  tap: () => `${disc(P.pondBlueSoft)}
    <path d="M 92 40 h -34 q -22 0 -22 24 v 10" stroke="url(#porcelainSide)" stroke-width="15" fill="none" stroke-linecap="round"/>
    <rect x="84" y="28" width="20" height="24" rx="9" fill="${P.sand300}"/>
    <rect x="26" y="70" width="22" height="12" rx="5" fill="${P.porcelainShade}"/>
    <path d="M 37 82 q -4 22 -2 30" stroke="url(#waterStream)" stroke-width="17" stroke-linecap="round" fill="none"/>
    <path d="M 33 88 q -2 14 -1 20" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.6"/>
    <circle cx="62" cy="96" r="10" fill="url(#bubbleFill)"/>
    <circle cx="80" cy="80" r="7" fill="url(#bubbleFill)"/>`,

  snack: () => `${disc(P.peachSoft)}
    <ellipse cx="60" cy="100" rx="28" ry="5" fill="${P.peachInk}" opacity="0.12"/>
    <path d="M 60 40 q -34 -12 -34 26 q 0 36 24 36 q 10 0 10 -4 q 0 4 10 4 q 24 0 24 -36 q 0 -38 -34 -26 Z" fill="url(#peachBall)"/>
    <path d="M 44 44 q -12 8 -12 26" stroke="#FFFFFF" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.35"/>
    <path d="M 60 40 q 2 -14 -4 -20" stroke="${P.woodDeep}" stroke-width="6" fill="none" stroke-linecap="round"/>
    <path d="M 62 28 q 18 -14 26 0 q -14 14 -26 0 Z" fill="${P.hopGreen}"/>`,

  controller: () => `${disc(P.lavenderSoft)}
    <path d="M 22 56 q 6 -18 24 -18 h 28 q 18 0 24 18 l 8 24 q 6 20 -12 22 q -14 2 -20 -12 h -48 q -6 14 -20 12 q -18 -2 -12 -22 Z" fill="url(#lavenderBall)"/>
    <path d="M 22 56 q 6 -18 24 -18 h 28 q 18 0 24 18 q -38 -8 -76 0 Z" fill="#FFFFFF" opacity="0.22"/>
    <rect x="32" y="60" width="22" height="7" rx="3.5" fill="${P.cloud}"/>
    <rect x="39.5" y="52.5" width="7" height="22" rx="3.5" fill="${P.cloud}"/>
    <circle cx="80" cy="58" r="6" fill="${P.sunshine}"/>
    <circle cx="92" cy="70" r="6" fill="${P.peach}"/>`,

  bed: () => `${disc(P.sunshineSoft)}
    <ellipse cx="60" cy="98" rx="42" ry="5" fill="${P.sunshineDeep}" opacity="0.12"/>
    <rect x="16" y="44" width="12" height="52" rx="6" fill="url(#woodGradV)"/>
    <rect x="94" y="62" width="12" height="34" rx="6" fill="url(#woodGradV)"/>
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
    <path d="M 78 44 h -20 q -14 0 -14 14 v 6" stroke="url(#porcelainSide)" stroke-width="11" fill="none" stroke-linecap="round"/>
    <rect x="72" y="34" width="16" height="18" rx="7" fill="${P.sand300}"/>
    <path d="M 22 64 h 76 q 8 0 6 10 l -8 24 q -3 10 -14 10 h -44 q -11 0 -14 -10 l -8 -24 q -2 -10 6 -10 Z" fill="url(#porcelainGrad)"/>
    <path d="M 26 68 h 68 l -4 12 q -30 8 -60 0 Z" fill="${P.pondBlueLight}" opacity="0.55"/>
    <rect x="52" y="80" width="16" height="6" rx="3" fill="${P.sand200}"/>`,

  bubbles: () => `${disc(P.pondBlueSoft)}
    <circle cx="48" cy="56" r="26" fill="url(#bubbleFill)"/>
    <circle cx="82" cy="42" r="16" fill="url(#bubbleFill)"/>
    <circle cx="84" cy="80" r="20" fill="url(#bubbleFill)"/>
    <circle cx="46" cy="92" r="13" fill="url(#bubbleFill)"/>
    <circle cx="30" cy="34" r="10" fill="url(#bubbleFill)"/>
    <circle cx="40" cy="46" r="8" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="78" cy="36" r="5" fill="#FFFFFF" opacity="0.85"/>
    <circle cx="78" cy="72" r="6" fill="#FFFFFF" opacity="0.85"/>`,
};

// ===========================================================================
// 5. EVENT GLYPHS  (96 x 96)
// ===========================================================================
// Meaning is carried by silhouette alone: an open ring, one drop, a soft coil,
// and a drop breaking out of a broken ring. Colour is a second, optional cue —
// every glyph is also emitted in single-ink `-mono`.
const drop = (cx, cy, h, w) =>
  `M ${cx} ${R(cy - h / 2)} C ${R(cx + w * 0.62)} ${R(cy - h * 0.1)} ${R(cx + w)} ${R(cy + h * 0.12)} ${cx} ${R(cy + h / 2)} C ${R(cx - w)} ${R(cy + h * 0.12)} ${R(cx - w * 0.62)} ${R(cy - h * 0.1)} ${cx} ${R(cy - h / 2)} Z`;

const eventGlyphs = {
  // Tried: an open ring around a small centre — an attempt, outcome not stated.
  tried: (ink, accent) => `
    <circle cx="48" cy="48" r="29" fill="none" stroke="${ink}" stroke-width="9" stroke-linecap="round" stroke-dasharray="118 30" transform="rotate(-58 48 48)"/>
    <circle cx="48" cy="48" r="11" fill="${accent}"/>`,

  // Pee: a single, solid drop.
  pee: (ink, accent) => `
    <path d="${drop(48, 50, 62, 27)}" fill="${accent}"/>
    <path d="M 38 56 q 2 -14 10 -22" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" fill="none" opacity="0.55"/>`,

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
    <circle cx="48" cy="48" r="31" fill="none" stroke="${ink}" stroke-width="8" stroke-linecap="round" stroke-dasharray="26 22" opacity="0.75"/>
    <path d="${drop(48, 48, 50, 22)}" fill="${accent}"/>
    <g stroke="${ink}" stroke-width="7" stroke-linecap="round" opacity="0.9">
      <path d="M 78 18 l 10 -10"/><path d="M 18 78 l -10 10"/>
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
  // The pause motif: two soft bars behind Hop, wide enough to read as a pause
  // at 40pt and pale enough that they never compete with the face.
  const pause = `<g fill="#FFFFFF" opacity="0.2">
      <rect x="150" y="286" width="104" height="392" rx="52"/>
      <rect x="770" y="286" width="104" height="392" rx="52"/>
    </g>`;
  const body = `
    <rect width="${S}" height="${S}" fill="url(#iconSky)"/>
    <circle cx="512" cy="430" r="470" fill="url(#iconHalo)"/>
    ${pause}
    <path d="M 0 792 Q 256 736 512 780 Q 768 824 1024 764 L 1024 1024 L 0 1024 Z" fill="url(#iconWater)"/>
    <path d="M 0 836 Q 256 786 512 826 Q 768 866 1024 812" fill="none" stroke="#FFFFFF" stroke-width="14" opacity="0.35"/>
    ${g('translate(214 872) scale(1.5)', `<path d="${pad(0, 0, 62, { notch: 44 })}" fill="${P.hopGreenDeep}" opacity="0.55"/>`)}
    ${g('translate(820 916) scale(1.25)', `<path d="${pad(0, 0, 62, { notch: 210 })}" fill="${P.hopGreenDeep}" opacity="0.5"/>`)}
    <ellipse cx="512" cy="812" rx="270" ry="46" fill="${P.hopGreenInk}" opacity="0.16"/>
    ${g('translate(512 486) scale(2.02) translate(-256 -274)', `
      ${hopBody({})}
      ${hopSheen}
      ${hopEyes({})}
      ${hopCheeks()}
      ${hopMouth({ smile: 1 })}`)}
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
     ${g('translate(600 630) scale(0.46) translate(-256 -300)', frog({}))}</g>`,
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
