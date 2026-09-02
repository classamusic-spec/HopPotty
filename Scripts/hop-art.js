#!/usr/bin/env node
/**
 * Generates Hop's pose set from one shared anatomy definition.
 *
 * Hop is drawn in the 150×160 space of the approved reference
 * (`hop_mascot.svg`) so every number here can be checked against it directly,
 * then scaled onto the 512×512 canvas the app and the SwiftUI port use.
 *
 * The reference is a single fused outline, which cannot animate. This file
 * rebuilds it as articulated parts — head, torso, two arms, two legs — at the
 * same proportions, so poses are parameter changes rather than redraws. The
 * same parameters carry over to `HopCharacterView`.
 *
 * Style is flat, like the reference: no gradients, no outlines. Depth comes
 * from value steps in the green ramp alone.
 */
const fs = require('fs');
const path = require('path');

/**
 * Palette. The reference used a yellower green (#64C157); Hop's brand green is
 * #63C88A, so every green here is drawn from `HopPalette`'s ramp. The mouth and
 * tongue are character-only colours, like the pack's browns were — they never
 * appear in UI and are not semantic tokens.
 */
const C = {
  body: '#63C88A',        // HopPalette.hopGreen
  bodyDeep: '#45A971',    // spots, toe creases
  ink: '#1B5E39',         // nostrils, closed-eye lines (hopGreenInk)
  belly: '#FFF3D4',       // HopPalette.sunshineSoft — warm cream, reference used #FFE698
  cheek: '#FF9F8F',       // HopPalette.peachPop — reference used #FD8585
  eyeWhite: '#FFFFFF',
  pupil: '#243047',       // HopPalette.midnight — reference used near-black #020D2B
  highlight: '#FFFFFF',
  mouthInterior: '#8A3F30', // HopPalette.peachInk — reference used #7F0B10
  tongue: '#FF6F7D',      // character-only; reference #FF4455
  bagBody: '#C98A5B',
  bagStrap: '#A76F46',
  shadow: '#243047',
};

// ---------------------------------------------------------------------------
// Anatomy, in reference coordinates
// ---------------------------------------------------------------------------

const EYE_L = { cx: 42.4, cy: 25.7 };
const EYE_R = { cx: 108.4, cy: 25.7 };
const SOCKET_R = 19.5;
const WHITE_R = 15.5;
const PUPIL_R = 11.5;

/** The head silhouette: crown, jaw and the two eye sockets, one fill, no seams. */
function headShape({ tilt = 0, neck = true } = {}) {
  return `<g transform="rotate(${tilt} 75 50)">
    <ellipse cx="75" cy="42" rx="46" ry="31" fill="${C.body}"/>
    <ellipse cx="75" cy="54" rx="65" ry="26" fill="${C.body}"/>
    <circle cx="${EYE_L.cx}" cy="${EYE_L.cy}" r="${SOCKET_R}" fill="${C.body}"/>
    <circle cx="${EYE_R.cx}" cy="${EYE_R.cy}" r="${SOCKET_R}" fill="${C.body}"/>
    ${neck ? `<rect x="50" y="66" width="50" height="20" fill="${C.body}"/>` : ''}
  </g>`;
}

/** The three darker spots on the forehead, exactly where the reference puts them. */
function spots() {
  return `
    <ellipse cx="75.3" cy="19.4" rx="4.4" ry="2.6" fill="${C.bodyDeep}"/>
    <ellipse cx="72.8" cy="26.2" rx="2.6" ry="1.9" fill="${C.bodyDeep}"/>
    <ellipse cx="80.6" cy="24.6" rx="3.0" ry="1.6" fill="${C.bodyDeep}"/>`;
}

function nostrils() {
  return `
    <circle cx="67.4" cy="41" r="2.1" fill="${C.ink}"/>
    <circle cx="82.6" cy="41" r="2.1" fill="${C.ink}"/>`;
}

function cheeks() {
  return `
    <circle cx="32" cy="51" r="7.6" fill="${C.cheek}"/>
    <circle cx="118" cy="51" r="7.6" fill="${C.cheek}"/>`;
}

/**
 * Eyes. `blink` 0…1 closes the lid; `mood` picks the closed-eye line — a happy
 * upward arc for celebrating, a soft downward arc for resting.
 */
function eyes({ gaze = [0, 0], blink = 0, mood = 'happy', lidDrop = 0 } = {}) {
  const [gx, gy] = gaze;
  const one = ({ cx, cy }) => {
    if (blink >= 1) {
      const dir = mood === 'rest' ? 1 : -1;
      return `<path d="M ${cx - 10} ${cy + 3} Q ${cx} ${cy + 3 + dir * 9} ${cx + 10} ${cy + 3}"
        fill="none" stroke="${C.ink}" stroke-width="3.2" stroke-linecap="round"/>`;
    }
    const lid = lidDrop > 0
      ? `<circle cx="${cx}" cy="${(cy - (2 * WHITE_R + 1 - 2 * WHITE_R * lidDrop)).toFixed(1)}" r="${WHITE_R + 1}" fill="${C.body}"/>`
      : '';
    // The lid is clipped to the white so a lowered lid never shows outside the
    // eye — unclipped it read as a pair of ears above the head.
    const clipId = `eyeClip${Math.round(cx)}`;
    return `<g>
      <clipPath id="${clipId}"><circle cx="${cx}" cy="${cy}" r="${WHITE_R}"/></clipPath>
      <circle cx="${cx}" cy="${cy}" r="${WHITE_R}" fill="${C.eyeWhite}"/>
      <g clip-path="url(#${clipId})">
        <circle cx="${cx + gx}" cy="${cy + 1 + gy}" r="${PUPIL_R}" fill="${C.pupil}"/>
        <circle cx="${cx + gx + 3.2}" cy="${cy - 4 + gy}" r="3.4" fill="${C.highlight}"/>
        ${lid}
      </g>
    </g>`;
  };
  return one(EYE_L) + one(EYE_R);
}

/**
 * Mouth. `open`: the reference's wide smile with tongue. `talk`: the same at
 * 70%, for speech. `closed`: a calm smile line. `small`: a resting smile.
 */
function mouth(kind = 'open') {
  if (kind === 'closed' || kind === 'small') {
    const d = kind === 'closed' ? 12 : 8;
    return `<path d="M 58 50 Q 75 ${50 + d} 92 50" fill="none" stroke="${C.ink}" stroke-width="3.4" stroke-linecap="round"/>`;
  }
  const s = kind === 'talk' ? 0.72 : 1;
  const uid = 'mouthClip' + kind;
  return `<g transform="translate(75 50) scale(${s}) translate(-75 -50)">
    <clipPath id="${uid}">
      <path d="M 53 47.5 Q 75 52 97 47.5 C 96 60 88 69.5 75 69.5 C 62 69.5 54 60 53 47.5 Z"/>
    </clipPath>
    <path d="M 53 47.5 Q 75 52 97 47.5 C 96 60 88 69.5 75 69.5 C 62 69.5 54 60 53 47.5 Z" fill="${C.mouthInterior}"/>
    <ellipse cx="75" cy="66" rx="15" ry="7.5" fill="${C.tongue}" clip-path="url(#${uid})"/>
  </g>`;
}

/** Torso: a soft capsule. `squash` compresses vertically for landing frames. */
function torso({ squash = 0, width = 60 } = {}) {
  const h = 54 - squash * 8;
  return `<rect x="${75 - width / 2}" y="${76 + squash * 4}" width="${width}" height="${h}" rx="27" fill="${C.body}"/>`;
}

function belly({ scale = 1 } = {}) {
  return `<ellipse cx="75" cy="${104 + (scale - 1) * 4}" rx="${24 * scale}" ry="${23 * scale}" fill="${C.belly}"/>`;
}

/**
 * A frog's tongue, out and reaching for something. A thick capsule from the
 * mouth to `to`, with a rounder tip so it reads as a tongue and not a rope.
 * Drawn after the face so it leaves the open mouth rather than sitting under it.
 */
function tongue(to = [128, 20]) {
  const [tx, ty] = to;
  return `<g>
    <line x1="75" y1="60" x2="${tx}" y2="${ty}" stroke="${C.tongue}" stroke-width="7" stroke-linecap="round"/>
    <circle cx="${tx}" cy="${ty}" r="5.5" fill="${C.tongue}"/>
  </g>`;
}

/** Soft motion marks either side of the body, for the "I need to go" wiggle. */
function wiggle() {
  return `<g fill="none" stroke="${C.bodyDeep}" stroke-width="2.4" stroke-linecap="round" opacity="0.6">
    <path d="M 36 96 q -5 6 0 12"/><path d="M 30 92 q -7 9 0 18"/>
    <path d="M 114 96 q 5 6 0 12"/><path d="M 120 92 q 7 9 0 18"/>
  </g>`;
}

/**
 * An arm from a shoulder to a hand point, with three fingers fanned along the
 * arm's direction. Fingers are what make the reference's hands read as hands.
 */
function arm(shoulder, hand, { width = 13 } = {}) {
  const [sx, sy] = shoulder; const [hx, hy] = hand;
  const dx = hx - sx, dy = hy - sy; const len = Math.hypot(dx, dy) || 1;
  const ux = dx / len, uy = dy / len;
  const finger = (deg) => {
    const a = Math.atan2(uy, ux) + (deg * Math.PI) / 180;
    const tx = hx + Math.cos(a) * 11, ty = hy + Math.sin(a) * 11;
    return `<line x1="${hx}" y1="${hy}" x2="${tx.toFixed(1)}" y2="${ty.toFixed(1)}" stroke="${C.body}" stroke-width="9" stroke-linecap="round"/>`;
  };
  return `<g>
    <line x1="${sx}" y1="${sy}" x2="${hx}" y2="${hy}" stroke="${C.body}" stroke-width="${width}" stroke-linecap="round"/>
    <circle cx="${hx}" cy="${hy}" r="8.4" fill="${C.body}"/>
    ${finger(-50)}${finger(0)}${finger(50)}
  </g>`;
}

/**
 * A leg from hip to ankle with a three-toed foot. `side` −1 is Hop's right
 * (viewer's left); toes fan outward and down like the reference.
 */
function leg(hip, ankle, side, { toeSpread = 1 } = {}) {
  const [hx, hy] = hip; const [ax, ay] = ankle;
  const fx = ax - side * 2, fy = ay + 3;
  const toe = (deg, r = 5) => {
    const a = (deg * Math.PI) / 180;
    const tx = fx + Math.cos(a) * 12 * toeSpread, ty = fy + Math.sin(a) * 10;
    return `<line x1="${fx}" y1="${fy}" x2="${tx.toFixed(1)}" y2="${ty.toFixed(1)}" stroke="${C.body}" stroke-width="${r * 2}" stroke-linecap="round"/>`;
  };
  const base = side < 0 ? 180 : 0;
  const t = (d) => (side < 0 ? base + d : base - d);
  const crease = (deg) => {
    const a = (deg * Math.PI) / 180;
    const x1 = fx + Math.cos(a) * 5, y1 = fy + Math.sin(a) * 5;
    const x2 = fx + Math.cos(a) * 14 * toeSpread, y2 = fy + Math.sin(a) * 12;
    return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${C.bodyDeep}" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/>`;
  };
  return `<g>
    <line x1="${hx}" y1="${hy}" x2="${ax}" y2="${ay}" stroke="${C.body}" stroke-width="16" stroke-linecap="round"/>
    <ellipse cx="${fx}" cy="${fy}" rx="9.5" ry="7" fill="${C.body}"/>
    ${toe(t(-8), 5.4)}${toe(t(-46), 5.4)}${toe(t(-84), 5)}
    ${crease(t(-30))}${crease(t(-70))}
  </g>`;
}

/** The adventure pack, worn on the back; only its edge and strap show. */
function pack() {
  return `<g>
    <rect x="98" y="84" width="22" height="30" rx="9" fill="${C.bagBody}"/>
    <path d="M 92 78 q 12 4 16 20" fill="none" stroke="${C.bagStrap}" stroke-width="4" stroke-linecap="round"/>
  </g>`;
}

function zzz() {
  return `<g fill="${C.ink}" font-family="system-ui, sans-serif" font-weight="800" opacity="0.7">
    <text x="122" y="14" font-size="9">z</text>
    <text x="131" y="6" font-size="12">z</text>
  </g>`;
}

function shadow(lift = 0) {
  return `<ellipse cx="75" cy="${159 - lift * 0.1}" rx="${40 - lift * 0.4}" ry="4" fill="${C.shadow}" opacity="${0.12 - lift * 0.002}"/>`;
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------

/**
 * One pose = one parameter set. Draw order is fixed: shadow, pack, legs, torso,
 * belly, arms, head, face — so limbs read as attached rather than stacked.
 */
function figure(p = {}) {
  const {
    lift = 0, squash = 0, tilt = 0, lean = 0,
    armL = [10, 97], armR = [140, 97],
    legL = { hip: [55, 122], ankle: [54, 148], spread: 1 },
    legR = { hip: [95, 122], ankle: [96, 148], spread: 1 },
    eyes: eyeOpts = {}, mouth: mouthKind = 'open',
    withPack = false, sleeping = false, showShadow = true,
    bellyScale = 1, tongueTo = null, wiggling = false,
    torsoWidth = 60,
  } = p;
  const shoulderL = [50, 90], shoulderR = [100, 90];
  return `
  ${showShadow ? shadow(lift) : ''}
  <g transform="translate(0 ${-lift}) translate(75 100) rotate(${lean}) translate(-75 -100)">
    ${withPack ? pack() : ''}
    ${leg(legL.hip, legL.ankle, -1, { toeSpread: legL.spread })}
    ${leg(legR.hip, legR.ankle, 1, { toeSpread: legR.spread })}
    ${torso({ squash, width: torsoWidth })}
    ${belly({ scale: bellyScale })}
    ${arm(shoulderL, armL)}
    ${arm(shoulderR, armR)}
    ${headShape({ tilt })}
    <g transform="rotate(${tilt} 75 50)">
      ${spots()}
      ${eyes(eyeOpts)}
      ${cheeks()}
      ${nostrils()}
      ${mouth(mouthKind)}
      ${tongueTo ? tongue(tongueTo) : ''}
    </g>
    ${wiggling ? wiggle() : ''}
    ${sleeping ? zzz() : ''}
  </g>`;
}

function wrap(inner) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
<g transform="translate(16 0) scale(3.2)">${inner}
</g>
</svg>`;
}

const poses = {
  /** The reference pose: arms wide, open smile. App icon and dashboard chip. */
  idle: () => wrap(figure({})),

  /** Eyes closed mid-blink; cross-faded with `idle` for the ambient loop. */
  blink: () => wrap(figure({ eyes: { blink: 1, mood: 'rest' } })),

  /** Speaking a line. Smaller mouth, one hand slightly raised toward the child. */
  talk: () => wrap(figure({ mouth: 'talk', armR: [136, 84], eyes: { gaze: [0, 1] } })),

  /** Waving hello. Onboarding and the shield greeting. */
  wave: () => wrap(figure({ armR: [143, 38], armL: [12, 100], tilt: -3, eyes: { gaze: [1, 0] } })),

  /** Walking to the bathroom with the pack. Routine step one. */
  walk: () => wrap(figure({
    lean: 4, withPack: true,
    armL: [24, 112], armR: [122, 78],
    legL: { hip: [55, 122], ankle: [44, 146], spread: 1 },
    legR: { hip: [95, 122], ankle: [104, 140], spread: 0.8 },
    eyes: { gaze: [2, 0] }, mouth: 'talk',
  })),

  /** Waiting patiently on the potty — sat down, hands resting, calm. */
  wait: () => wrap(figure({
    lift: -6, squash: 0.3,
    armL: [32, 124], armR: [118, 124],
    legL: { hip: [55, 122], ankle: [42, 138], spread: 1.1 },
    legR: { hip: [95, 122], ankle: [108, 138], spread: 1.1 },
    eyes: { gaze: [0, 3], lidDrop: 0.35 }, mouth: 'small',
  })),

  /** Mid-hop, airborne. The celebration. */
  jump: () => wrap(figure({
    lift: 10, squash: -0.15,
    armL: [14, 58], armR: [136, 58],
    legL: { hip: [55, 122], ankle: [48, 136], spread: 0.9 },
    legR: { hip: [95, 122], ankle: [102, 136], spread: 0.9 },
    eyes: { blink: 1, mood: 'happy' }, mouth: 'open',
  })),

  /** Both arms straight up. The star-earned moment. */
  cheer: () => wrap(figure({
    lift: 2,
    armL: [30, 30], armR: [120, 30],
    eyes: { gaze: [0, -2] }, mouth: 'open',
  })),

  /** Resting during quiet hours and "paused until tomorrow". */
  sleep: () => wrap(figure({
    tilt: 4, lift: -4, squash: 0.2, sleeping: true,
    armL: [34, 122], armR: [116, 122],
    eyes: { blink: 1, mood: 'rest' }, mouth: 'small',
  })),

  /** Landing frame after a jump — the squash before the settle. */
  land: () => wrap(figure({
    squash: 0.5,
    armL: [14, 108], armR: [136, 108],
    legL: { hip: [55, 120], ankle: [46, 146], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [104, 146], spread: 1.2 },
    eyes: { gaze: [0, 2] }, mouth: 'open',
  })),

  // ---- Mini-game states ----

  /** Frog squat on a lily pad, watching the sky. Fly Snack's resting state. */
  sit: () => wrap(figure({
    lift: -10, squash: 0.35,
    armL: [50, 134], armR: [100, 134],
    legL: { hip: [55, 120], ankle: [30, 134], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [120, 134], spread: 1.2 },
    eyes: { gaze: [0, -3] }, mouth: 'small',
  })),

  /** Tongue out for a fly. Same squat; the tongue reaches toward `tongueTo`. */
  catch: () => wrap(figure({
    lift: -10, squash: 0.35,
    armL: [50, 134], armR: [100, 134],
    legL: { hip: [55, 120], ankle: [30, 134], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [120, 134], spread: 1.2 },
    eyes: { gaze: [3, -4] }, mouth: 'open', tongueTo: [142, 34],
  })),

  /**
   * Tummy full, and the body saying so. Bigger belly, hand on it, knees
   * together, a small bashful smile — kind, never distressed. This is the
   * moment the child learns to notice.
   */
  full: () => wrap(figure({
    squash: 0.1, bellyScale: 1.28, torsoWidth: 68, wiggling: true,
    armL: [20, 104], armR: [88, 112],
    legL: { hip: [55, 124], ankle: [66, 150], spread: 0.9 },
    legR: { hip: [95, 124], ankle: [84, 150], spread: 0.9 },
    eyes: { gaze: [0, 3], lidDrop: 0.15 }, mouth: 'small',
  })),

  /** Hands held out front, palms up, for washing and wiping games. */
  scrub: () => wrap(figure({
    armL: [50, 118], armR: [100, 118],
    eyes: { gaze: [0, 4] }, mouth: 'talk',
  })),

  /** Head only, for avatars and the app icon. */
  face: () => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 290" width="512" height="290">
<g transform="translate(16 8) scale(3.2)">
  ${headShape({ neck: false })}
  ${spots()}
  ${eyes({})}
  ${cheeks()}
  ${nostrils()}
  ${mouth('open')}
</g>
</svg>`,
};

const outDir = path.resolve(__dirname, '..', 'Art', 'character');
fs.mkdirSync(outDir, { recursive: true });
for (const [name, build] of Object.entries(poses)) {
  const file = path.join(outDir, `hop-${name}.svg`);
  fs.writeFileSync(file, build().trim() + '\n');
  console.log('wrote', path.relative(path.resolve(__dirname, '..'), file));
}
