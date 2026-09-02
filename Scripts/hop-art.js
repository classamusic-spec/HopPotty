#!/usr/bin/env node
/**
 * Generates Hop's pose set from one shared anatomy definition.
 *
 * Hop is drawn in the 150×160 space of the approved reference
 * (`hop_mascot.svg`) so every number here can be checked against it directly,
 * then scaled onto the 512×512 canvas the app and the SwiftUI port use.
 *
 * A pose is not confined to that 150×160 box — `jump` lifts him above y=0 and
 * every standing pose's toes reach past y=160 — so the placement on the canvas
 * is derived from the drawing (see `STAGE`) rather than assumed from the
 * reference's own bounds. `Scripts/check-hop-fit.js` measures the rendered
 * result and fails if any pose reaches the canvas edge.
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
  bodyLight: '#8FDCAC',   // HopPalette.hopGreenLight — a limb crossing in front
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

/** The head silhouette: crown, jaw and the two eye sockets, one fill, no seams. */
function headShape({ tilt = 0, neck = true } = {}) {
  return `<g transform="rotate(${tilt} 75 50)">
    <ellipse cx="75" cy="40" rx="44" ry="33" fill="${C.body}"/>
    <ellipse cx="75" cy="56" rx="61" ry="27" fill="${C.body}"/>
    <circle cx="${EYE_L.cx}" cy="${EYE_L.cy}" r="${SOCKET_R}" fill="${C.body}"/>
    <circle cx="${EYE_R.cx}" cy="${EYE_R.cy}" r="${SOCKET_R}" fill="${C.body}"/>
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
/**
 * Torso: straight sides that run up under the jaw, rounded only at the hips.
 * A capsule with rounded top corners narrowed just below the jaw and read as a
 * neck; the reference has none — the body tucks straight up behind the head.
 */
function torso({ squash = 0, width = 60 } = {}) {
  const x0 = 75 - width / 2, x1 = 75 + width / 2;
  const top = 58 + squash * 4, bottom = 127 - squash * 4, r = Math.min(26, width / 2);
  return `<path d="M ${x0} ${top} H ${x1} V ${bottom - r} A ${r} ${r} 0 0 1 ${x1 - r} ${bottom} H ${x0 + r} A ${r} ${r} 0 0 1 ${x0} ${bottom - r} Z" fill="${C.body}"/>`;
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
 *
 * `shade` moves the arm one step *up* the green ramp, to `hopGreenLight`. An arm
 * that crosses in front of the torso is otherwise the same flat green as the
 * torso and simply disappears — `scrub`'s cupped hands and `full`'s hand on the
 * tummy were both invisible. Lighter rather than darker because a value step is
 * the only depth cue this style allows and the nearer thing is the lit one: the
 * darker step read as a pair of heavy sleeves, not as arms in front.
 */
function arm(shoulder, hand, { width = 15, shade = false } = {}) {
  const skin = shade ? C.bodyLight : C.body;
  const [sx, sy] = shoulder; const [hx, hy] = hand;
  const dx = hx - sx, dy = hy - sy; const len = Math.hypot(dx, dy) || 1;
  const ux = dx / len, uy = dy / len;
  const finger = (deg) => {
    const a = Math.atan2(uy, ux) + (deg * Math.PI) / 180;
    const tx = hx + Math.cos(a) * 12, ty = hy + Math.sin(a) * 12;
    return `<line x1="${hx}" y1="${hy}" x2="${tx.toFixed(1)}" y2="${ty.toFixed(1)}" stroke="${skin}" stroke-width="10.5" stroke-linecap="round"/>`;
  };
  return `<g>
    <line x1="${sx}" y1="${sy}" x2="${hx}" y2="${hy}" stroke="${skin}" stroke-width="${width}" stroke-linecap="round"/>
    <circle cx="${hx}" cy="${hy}" r="9.5" fill="${skin}"/>
    ${finger(-50)}${finger(0)}${finger(50)}
  </g>`;
}

/**
 * A leg from hip to ankle with a three-toed foot. `side` −1 is Hop's right
 * (viewer's left); toes fan outward and down like the reference.
 *
 * The fan is shallow — the reference's toes splay across the ground rather than
 * hanging off the front of the foot. The steepest toe used to point almost
 * straight down at 82°, which put the lowest ink two units below the ground
 * shadow: Hop stood *through* his own shadow, and the toes were the first thing
 * the canvas cut off.
 */
function leg(hip, ankle, side, { toeSpread = 1 } = {}) {
  const [hx, hy] = hip; const [ax, ay] = ankle;
  const fx = ax - side * 2, fy = ay + 3;
  const toe = (deg, r = 5) => {
    const a = (deg * Math.PI) / 180;
    const tx = fx + Math.cos(a) * 15 * toeSpread, ty = fy + Math.sin(a) * 10;
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
    <line x1="${hx}" y1="${hy}" x2="${ax}" y2="${ay}" stroke="${C.body}" stroke-width="26" stroke-linecap="round"/>
    <ellipse cx="${fx}" cy="${fy}" rx="14" ry="8.5" fill="${C.body}"/>
    ${toe(t(-4), 6)}${toe(t(-34), 6)}${toe(t(-64), 5.6)}
    ${crease(t(-20))}${crease(t(-50))}
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

/**
 * The ground shadow, resting on `GROUND` so its lower edge is the lowest ink in
 * the drawing and the toes touch it rather than pierce it. It shrinks and fades
 * with `lift`, which is what makes an airborne pose read as airborne.
 */
function shadow(lift = 0) {
  const ry = 3.6;
  return `<ellipse cx="75" cy="${(GROUND - ry - lift * 0.1).toFixed(2)}" rx="${40 - lift * 0.4}" ry="${ry}" fill="${C.shadow}" opacity="${(0.12 - lift * 0.002).toFixed(3)}"/>`;
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
    // The reference hangs the arms down and out at roughly 30°, not straight
    // out at shoulder height: horizontal arms read as poles bolted to a barrel,
    // and reached past both edges of the canvas.
    armL = [22, 103], armR = [128, 103], shadeL = false, shadeR = false,
    legL = { hip: [56, 124], ankle: [52, ANKLE], spread: 1 },
    legR = { hip: [94, 124], ankle: [98, ANKLE], spread: 1 },
    eyes: eyeOpts = {}, mouth: mouthKind = 'open',
    withPack = false, sleeping = false, showShadow = true,
    bellyScale = 1, tongueTo = null, wiggling = false,
    torsoWidth = 58,
  } = p;
  const shoulderL = [48, 86], shoulderR = [102, 86];
  return `
  ${showShadow ? shadow(lift) : ''}
  <g transform="translate(0 ${-lift}) translate(75 100) rotate(${lean}) translate(-75 -100)">
    ${withPack ? pack() : ''}
    ${leg(legL.hip, legL.ankle, -1, { toeSpread: legL.spread })}
    ${leg(legR.hip, legR.ankle, 1, { toeSpread: legR.spread })}
    ${torso({ squash, width: torsoWidth })}
    ${belly({ scale: bellyScale })}
    ${arm(shoulderL, armL, { shade: shadeL })}
    ${arm(shoulderR, armR, { shade: shadeR })}
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
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CANVAS} ${CANVAS}" width="${CANVAS}" height="${CANVAS}">
<g transform="translate(${OX} ${OY}) scale(${SCALE})">${inner}
</g>
</svg>`;
}

const poses = {
  /** The reference pose: arms wide, open smile. App icon and dashboard chip. */
  idle: () => wrap(figure({})),

  /** Eyes closed mid-blink; cross-faded with `idle` for the ambient loop. */
  blink: () => wrap(figure({ eyes: { blink: 1, mood: 'rest' } })),

  /** Speaking a line. Smaller mouth, one hand slightly raised toward the child. */
  talk: () => wrap(figure({ mouth: 'talk', armR: [128, 90], eyes: { gaze: [0, 1] } })),

  /** Waving hello. Onboarding and the shield greeting. */
  wave: () => wrap(figure({ armR: [127, 42], armL: [26, 106], tilt: -3, eyes: { gaze: [1, 0] } })),

  /** Walking to the bathroom with the pack. Routine step one. */
  walk: () => wrap(figure({
    lean: 4, withPack: true,
    armL: [30, 110], armR: [120, 80],
    legL: { hip: [55, 122], ankle: [44, ANKLE], spread: 1 },
    legR: { hip: [95, 122], ankle: [104, ANKLE - 6], spread: 0.8 },
    eyes: { gaze: [2, 0] }, mouth: 'talk',
  })),

  /** Waiting patiently on the potty — sat down, hands resting, calm. */
  wait: () => wrap(figure({
    lift: -6, squash: 0.3,
    armL: [30, 120], armR: [120, 120],
    legL: { hip: [55, 122], ankle: [42, ANKLE - 6], spread: 1.1 },
    legR: { hip: [95, 122], ankle: [108, ANKLE - 6], spread: 1.1 },
    eyes: { gaze: [0, 3], lidDrop: 0.35 }, mouth: 'small',
  })),

  /**
   * Mid-hop, airborne. The celebration.
   *
   * `lift` is the one parameter that costs the whole set size: every pose is
   * scaled to fit the tallest thing any pose draws, and the crown of a lifted
   * Hop is it. Eight is as high as he goes before everyone else shrinks.
   */
  jump: () => wrap(figure({
    lift: 8, squash: -0.15,
    armL: [23, 58], armR: [127, 58],
    legL: { hip: [55, 122], ankle: [48, 136], spread: 0.9 },
    legR: { hip: [95, 122], ankle: [102, 136], spread: 0.9 },
    eyes: { blink: 1, mood: 'happy' }, mouth: 'open',
  })),

  /**
   * Both arms up. The star-earned moment.
   *
   * Out as well as up: Hop's eye sockets are the widest part of him at that
   * height, so hands raised straight overhead vanish behind his own head and
   * the pose reads as a frog with no arms at all.
   */
  cheer: () => wrap(figure({
    lift: 2,
    armL: [23, 40], armR: [127, 40],
    eyes: { gaze: [0, -2] }, mouth: 'open',
  })),

  /** Resting during quiet hours and "paused until tomorrow". */
  sleep: () => wrap(figure({
    tilt: 4, lift: -4, squash: 0.2, sleeping: true,
    armL: [30, 118], armR: [120, 118],
    legL: { hip: [56, 124], ankle: [52, ANKLE - 4], spread: 1 },
    legR: { hip: [94, 124], ankle: [98, ANKLE - 4], spread: 1 },
    eyes: { blink: 1, mood: 'rest' }, mouth: 'small',
  })),

  /** Landing frame after a jump — the squash before the settle. */
  land: () => wrap(figure({
    squash: 0.5,
    armL: [24, 116], armR: [126, 116],
    legL: { hip: [55, 120], ankle: [46, ANKLE], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [104, ANKLE], spread: 1.2 },
    eyes: { gaze: [0, 2] }, mouth: 'open',
  })),

  // ---- Mini-game states ----

  /**
   * Frog squat on a lily pad, watching the sky. Fly Snack's resting state.
   *
   * The hands come down past the hips and onto the pad: with the arms tucked at
   * the waist they were the torso's own green over the torso and Hop read as a
   * legless bust.
   */
  sit: () => wrap(figure({
    lift: -10, squash: 0.35,
    armL: [46, 128], armR: [104, 128], shadeL: true, shadeR: true,
    legL: { hip: [55, 120], ankle: [32, ANKLE - 10], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [118, ANKLE - 10], spread: 1.2 },
    eyes: { gaze: [0, -3] }, mouth: 'small',
  })),

  /** Tongue out for a fly. Same squat; the tongue reaches toward `tongueTo`. */
  catch: () => wrap(figure({
    lift: -10, squash: 0.35,
    armL: [46, 128], armR: [104, 128], shadeL: true, shadeR: true,
    legL: { hip: [55, 120], ankle: [32, ANKLE - 10], spread: 1.2 },
    legR: { hip: [95, 120], ankle: [118, ANKLE - 10], spread: 1.2 },
    // Out sideways at mouth height. Aimed up at the fly it crossed his own
    // eye, and a pink bar over the pupil reads as damage, not as a tongue.
    eyes: { gaze: [3, -4] }, mouth: 'open', tongueTo: [138, 53],
  })),

  /**
   * Tummy full, and the body saying so. Bigger belly, hand on it, knees
   * together, a small bashful smile — kind, never distressed. This is the
   * moment the child learns to notice.
   */
  full: () => wrap(figure({
    squash: 0.1, bellyScale: 1.28, torsoWidth: 68, wiggling: true,
    // Both hands on the tummy, and clear of the wiggle marks: an arm parked on
    // top of them cancelled the one cue that says he is squirming.
    armL: [46, 118], armR: [92, 112], shadeL: true, shadeR: true,
    legL: { hip: [55, 124], ankle: [66, ANKLE], spread: 0.9 },
    legR: { hip: [95, 124], ankle: [84, ANKLE], spread: 0.9 },
    eyes: { gaze: [0, 3], lidDrop: 0.15 }, mouth: 'small',
  })),

  /**
   * Hands held out front, palms up, for washing and wiping games. Shaded,
   * because hands in front of the body in one flat green are no hands at all.
   */
  scrub: () => wrap(figure({
    armL: [56, 112], armR: [94, 112], shadeL: true, shadeR: true,
    eyes: { gaze: [0, 4] }, mouth: 'talk',
  })),

  /**
   * Head only, for avatars and the app icon.
   *
   * A crop, not a pose — and the only drawing here that keeps the original
   * `translate(16 8) scale(3.2)`. Its box is already tight on the head with 17
   * to 61 canvas pixels of air on every side, so it was never clipped, and it is
   * used at chip sizes where a head that suddenly shrank by a tenth would show.
   * `HopPoseGeometry.faceCrop` is this rectangle, and stays matched to it.
   */
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
// Printed rather than buried, because two constants outside this file — `FEET`
// in `Scripts/screens/child.js` and `SIT_FEET` in `Scripts/screens/parent.js`,
// and `referenceScale`/`referenceOffset` in `HopCharacterShapes.swift` — are
// this transform restated, and drift the moment the stage moves.
console.log('----');
console.log(`transform  translate(${OX} ${OY}) scale(${SCALE})   stage ${JSON.stringify(STAGE)}`);
console.log(`feet       ground y=${GROUND} -> canvas ${(OY + SCALE * GROUND).toFixed(1)}` +
  `  = ${FEET_FRACTION.toFixed(4)} of the box  (FEET and SIT_FEET)`);
