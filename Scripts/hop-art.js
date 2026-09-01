#!/usr/bin/env node
/**
 * Generates Hop's pose set from one shared anatomy definition.
 *
 * Poses are parameterised rather than hand-drawn per file so a change to the
 * character — eye size, palette, belly shape — propagates everywhere at once.
 * The same parameter names carry over to the SwiftUI `HopCharacterView`, which
 * redraws these shapes as animatable paths.
 */
const fs = require('fs');
const path = require('path');

const C = {
  bodyLight: '#9FE3B9',
  bodyMid: '#63C88A',
  bodyDeep: '#45A971',
  bodyShadow: '#37905F',
  belly: '#F0FBF4',
  bellyEdge: '#DCF3E5',
  ink: '#25603F',
  mouth: '#2F7D52',
  cheek: '#FF9F8F',
  eyeWhite: '#FFFFFF',
  pupil: '#243047',
  bagBody: '#C98A5B',
  bagStrap: '#A76F46',
  bagFlap: '#E0A472',
  shadow: '#243047',
};

/** Eyes: two domes riding above the head line, the single most frog-defining feature. */
function eyes({ lx = 194, rx = 318, cy = 196, r = 57, pupilR = 25, gaze = [0, 10], blink = 0, lidTilt = 0 }) {
  const [gx, gy] = gaze;
  const eye = (cx) => {
    const openH = r * (1 - blink);
    const dome = `<circle cx="${cx}" cy="${cy}" r="${r + 3}" fill="url(#hopEyeDome)"/>`;
    if (blink >= 1) {
      // Closed: the skin dome stays, with a soft lash line where the lid meets.
      return `<g>${dome}
        <path d="M ${cx - r * 0.66} ${cy + 2} Q ${cx} ${cy + r * 0.42} ${cx + r * 0.66} ${cy + 2}"
          fill="none" stroke="${C.ink}" stroke-width="8" stroke-linecap="round" opacity="0.85"/>
      </g>`;
    }
    return `
      <g>
        ${dome}
        <ellipse cx="${cx}" cy="${cy}" rx="${r}" ry="${openH}" fill="${C.eyeWhite}"/>
        <circle cx="${cx + gx}" cy="${cy + gy * (1 - blink)}" r="${pupilR * (1 - blink * 0.35)}" fill="${C.pupil}"/>
        <circle cx="${cx + gx - pupilR * 0.36}" cy="${cy + gy * (1 - blink) - pupilR * 0.42}" r="${pupilR * 0.36}" fill="#FFFFFF" opacity="0.96"/>
        <circle cx="${cx + gx + pupilR * 0.32}" cy="${cy + gy * (1 - blink) + pupilR * 0.34}" r="${pupilR * 0.17}" fill="#FFFFFF" opacity="0.72"/>
      </g>`;
  };
  return eye(lx, 'l') + eye(rx, 'r');
}

/** The merged head-and-body egg. Frogs have no neck; giving Hop one would age him up. */
function body({ squash = 0 }) {
  const s = squash;
  return `<path d="
    M 256 ${186 + s * 14}
    C ${330 + s * 10} ${186 + s * 14}, ${392 + s * 14} ${232 + s * 8}, ${400 + s * 16} ${292 + s * 4}
    C ${408 + s * 18} ${350}, ${396 + s * 12} ${400}, 340 418
    C 300 430, 212 430, 172 418
    C ${116 - s * 12} 400, ${104 - s * 18} 350, ${112 - s * 16} ${292 + s * 4}
    C ${120 - s * 14} ${232 + s * 8}, ${182 - s * 10} ${186 + s * 14}, 256 ${186 + s * 14}
    Z" fill="url(#hopBody)"/>`;
}

function belly() {
  return `
    <ellipse cx="256" cy="364" rx="86" ry="56" fill="${C.belly}" opacity="0.95"/>
    <ellipse cx="256" cy="364" rx="86" ry="56" fill="none" stroke="${C.bellyEdge}" stroke-width="3"/>`;
}

function mouth({ open = 0, smile = 1 }) {
  if (open > 0) {
    // An open mouth reads as speech or delight; kept small and soft, never a gape.
    return `
      <path d="M 202 292 Q 256 ${300 + open * 8} 310 292 Q 300 ${330 + open * 26} 256 ${332 + open * 28} Q 212 ${330 + open * 26} 202 292 Z"
        fill="${C.ink}" opacity="0.9"/>
      <path d="M 232 ${322 + open * 20} Q 256 ${336 + open * 24} 280 ${322 + open * 20} Q 256 ${330 + open * 22} 232 ${322 + open * 20} Z" fill="${C.cheek}" opacity="0.85"/>`;
  }
  return `<path d="M 202 294 Q 256 ${294 + 44 * smile} 310 294" fill="none" stroke="${C.mouth}" stroke-width="11" stroke-linecap="round"/>`;
}

function cheeks() {
  return `
    <ellipse cx="158" cy="308" rx="30" ry="19" fill="url(#hopCheek)"/>
    <ellipse cx="354" cy="308" rx="30" ry="19" fill="url(#hopCheek)"/>`;
}

/** A frog foot: a rounded sole with three toe pads. Legible down to icon size. */
function foot(cx, cy, flip = 1, lift = 0) {
  const y = cy - lift;
  return `<g transform="translate(${cx} ${y}) scale(${flip} 1)">
    <ellipse cx="0" cy="2" rx="44" ry="21" fill="${C.bodyDeep}"/>
    <circle cx="-27" cy="-11" r="17" fill="${C.bodyDeep}"/>
    <circle cx="0" cy="-16" r="17" fill="${C.bodyDeep}"/>
    <circle cx="27" cy="-11" r="17" fill="${C.bodyDeep}"/>
    <ellipse cx="0" cy="4" rx="29" ry="12" fill="${C.bodyLight}" opacity="0.45"/>
    <ellipse cx="0" cy="2" rx="44" ry="21" fill="none" stroke="${C.bodyShadow}" stroke-width="2.5" opacity="0.35"/>
  </g>`;
}

/** An arm drawn as a tapered capsule, angled by pose. */
function arm(cx, cy, angle, len = 54, w = 30) {
  return `<g transform="translate(${cx} ${cy}) rotate(${angle})">
    <rect x="${-w / 2}" y="${-w / 2}" width="${len + w / 2}" height="${w}" rx="${w / 2}" fill="${C.bodyDeep}"/>
    <circle cx="${len}" cy="0" r="${w / 2 + 4}" fill="${C.bodyDeep}"/>
    <circle cx="${len - 4}" cy="-4" r="${w / 2 - 2}" fill="${C.bodyMid}" opacity="0.5"/>
  </g>`;
}

/** The strap, drawn in front of the body so the pack reads as worn. */
function bagStrap() {
  return `<path d="M 352 236 q 30 20 38 58" fill="none" stroke="${C.bagStrap}" stroke-width="12" stroke-linecap="round" opacity="0.92"/>`;
}

function adventureBag() {
  return `<g id="hop-bag">
    <rect x="374" y="282" width="66" height="78" rx="24" fill="${C.bagBody}"/>
    <path d="M 374 304 q 0 -22 24 -22 h 18 q 24 0 24 22 v 8 q -33 11 -66 0 Z" fill="${C.bagFlap}"/>
    <rect x="399" y="306" width="17" height="13" rx="5" fill="${C.bagStrap}"/>
    <rect x="374" y="282" width="66" height="78" rx="24" fill="none" stroke="${C.bagStrap}" stroke-width="3" opacity="0.45"/>
  </g>`;
}

function defs() {
  return `<defs>
    <linearGradient id="hopBody" x1="0.2" y1="0" x2="0.85" y2="1">
      <stop offset="0" stop-color="${C.bodyLight}"/>
      <stop offset="0.52" stop-color="${C.bodyMid}"/>
      <stop offset="1" stop-color="${C.bodyDeep}"/>
    </linearGradient>
    <radialGradient id="hopSheen" cx="0.34" cy="0.22" r="0.6">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="hopCheek" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#FF8E86" stop-opacity="0.85"/>
      <stop offset="0.55" stop-color="#FF9F8F" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#FF9F8F" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="hopEyeDome" cx="0.36" cy="0.28" r="0.75">
      <stop offset="0" stop-color="#A9E8C2"/>
      <stop offset="1" stop-color="#4FB47B"/>
    </radialGradient>
    <radialGradient id="groundShadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="${C.shadow}" stop-opacity="0.20"/>
      <stop offset="1" stop-color="${C.shadow}" stop-opacity="0"/>
    </radialGradient>
  </defs>`;
}

function wrap(inner, { shadow = true, lift = 0 } = {}) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
${defs()}
${shadow ? `<ellipse cx="256" cy="${452 + lift * 0.25}" rx="${132 - lift * 0.35}" ry="${26 - lift * 0.06}" fill="url(#groundShadow)"/>` : ''}
${inner}
</svg>`;
}

const sheen = `<ellipse cx="200" cy="248" rx="96" ry="70" fill="url(#hopSheen)"/>`;

const poses = {
  /** Resting. The pose used for the app icon and the parent dashboard chip. */
  idle: () => wrap(`
    <g id="hop">
      ${body({})}
      ${sheen}
      ${arm(118, 338, 160)}${arm(394, 338, 20)}
      ${belly()}
      ${foot(190, 436)}${foot(322, 436, -1)}
      ${eyes({})}
      ${cheeks()}
      ${mouth({ smile: 1 })}
    </g>`),

  /** Eyes closed mid-blink. Cross-faded with `idle` for the ambient blink loop. */
  blink: () => wrap(`
    <g id="hop">
      ${body({})}
      ${sheen}
      ${arm(118, 338, 160)}${arm(394, 338, 20)}
      ${belly()}
      ${foot(190, 436)}${foot(322, 436, -1)}
      ${eyes({ blink: 1 })}
      ${cheeks()}
      ${mouth({ smile: 1 })}
    </g>`),

  /** Waving hello. Opens onboarding and greets the child on the shield. */
  wave: () => wrap(`
    <g id="hop">
      ${body({})}
      ${sheen}
      ${arm(118, 338, 160)}
      ${arm(392, 300, -64, 52)}
      ${belly()}
      ${foot(190, 436)}${foot(322, 436, -1)}
      ${eyes({ gaze: [5, 7] })}
      ${cheeks()}
      ${mouth({ open: 0.6 })}
    </g>`),

  /** Mid-hop, airborne. The celebration pose. */
  jump: () => wrap(`
    <g id="hop" transform="translate(0 -50)">
      ${body({ squash: -0.22 })}
      ${sheen}
      ${arm(126, 302, -128, 50)}${arm(386, 302, -52, 50)}
      ${belly()}
      ${foot(196, 442, 1, -6)}${foot(316, 442, -1, -6)}
      ${eyes({ blink: 1 })}
      ${cheeks()}
      ${mouth({ open: 1 })}
    </g>`, { lift: 50 }),

  /** Walking toward the bathroom, adventure bag on. Routine step one. */
  walk: () => wrap(`
    <g id="hop">
      ${adventureBag()}
      ${body({ squash: 0.05 })}
      ${sheen}
      ${bagStrap()}
      ${arm(122, 330, 142)}${arm(392, 344, 46)}
      ${belly()}
      ${foot(204, 442, 1, 16)}${foot(330, 436, -1)}
      ${eyes({ gaze: [13, 6] })}
      ${cheeks()}
      ${mouth({ open: 0.35 })}
    </g>`),

  /** Waiting patiently. The "give it a try" step — calm, never impatient. */
  wait: () => wrap(`
    <g id="hop" transform="translate(0 24)">
      ${body({ squash: 0.18 })}
      ${sheen}
      ${arm(128, 348, 152)}${arm(384, 348, 28)}
      ${belly()}
      ${foot(198, 430)}${foot(314, 430, -1)}
      ${eyes({ gaze: [0, 13], blink: 0.38 })}
      ${cheeks()}
      ${mouth({ smile: 0.7 })}
    </g>`),

  /** Cheering with both arms up. The awarded-a-star moment. */
  cheer: () => wrap(`
    <g id="hop">
      ${body({ squash: -0.08 })}
      ${sheen}
      ${arm(128, 296, -108, 54)}${arm(384, 296, -72, 54)}
      ${belly()}
      ${foot(190, 436)}${foot(322, 436, -1)}
      ${eyes({ blink: 1 })}
      ${cheeks()}
      ${mouth({ open: 1 })}
    </g>`),

  /** Face only. Source for the app icon and small avatars; crop is tuned so the
   *  eye domes clear the top edge and the smile is not clipped. */
  face: () => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="100 118 312 292" width="512" height="479">
${defs()}
<g id="hop-face">
  ${body({})}
  ${sheen}
  ${eyes({})}
  ${cheeks()}
  ${mouth({ smile: 1 })}
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
