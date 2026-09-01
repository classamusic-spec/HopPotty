/**
 * Illustrated environments for the child-facing screens.
 *
 * These are drawn here, from palette tokens, rather than imported as flat art
 * for one reason: they have to compose with type and buttons at an exact size,
 * and a scene that is 40px too tall clips a headline. Each one takes the box it
 * must fill and draws to it.
 *
 * Where finished vector art exists in `Art/`, `artOr` in `ui.js` lets a screen
 * prefer it; these are the drawings the screens use until it does.
 */
const { T, mix, alpha } = require('./ui');

const P = T.palette;
const INK_ = P.midnight;

/** Soft, irregular cloud built from overlapping circles. */
function cloud(x, y, s, fill, op) {
  return `<g opacity="${op}" transform="translate(${x} ${y}) scale(${s})">
    <ellipse cx="0" cy="6" rx="52" ry="17" fill="${fill}"/>
    <circle cx="-18" cy="-2" r="19" fill="${fill}"/>
    <circle cx="8" cy="-9" r="24" fill="${fill}"/>
    <circle cx="32" cy="0" r="16" fill="${fill}"/>
  </g>`;
}

/** A cluster of reeds. */
function reeds(x, y, s, dark) {
  const blade = (dx, len, lean, c2) =>
    `<path d="M ${dx} 0 C ${dx + lean * 0.3} ${-len * 0.5}, ${dx + lean} ${-len * 0.8}, ${dx + lean * 1.2} ${-len}"
      fill="none" stroke="${c2}" stroke-width="6" stroke-linecap="round"/>`;
  return `<g transform="translate(${x} ${y}) scale(${s})">
    ${blade(-14, 54, -12, dark ? P.hopGreenDeep : P.hopGreen)}
    ${blade(0, 74, 4, dark ? P.hopGreenDeep : P.hopGreen)}
    ${blade(13, 46, 14, P.hopGreenLight)}
    <ellipse cx="0" cy="-76" rx="6" ry="14" fill="${P.sand300}"/>
  </g>`;
}

/** A round-petalled flower. Five petals, no stamens; it reads at 20px. */
function flower(x, y, s, petal, heart) {
  const petals = [0, 72, 144, 216, 288].map((a) =>
    `<ellipse cx="0" cy="-9" rx="6.4" ry="8.4" fill="${petal}" transform="rotate(${a})"/>`).join('');
  return `<g transform="translate(${x} ${y}) scale(${s})">${petals}<circle cx="0" cy="0" r="4.6" fill="${heart}"/></g>`;
}

/** A lily pad, notched, seen from a low angle. */
function lilyPad(x, y, s, tone) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <ellipse cx="0" cy="0" rx="34" ry="13" fill="${tone}"/>
    <path d="M 0 0 L 26 -8 A 34 13 0 0 0 20 -10 Z" fill="${P.pondBlueSoft}" opacity="0.55"/>
    <ellipse cx="-6" cy="-3" rx="16" ry="5" fill="#FFFFFF" opacity="0.18"/>
  </g>`;
}

/** A grass tuft along a ground edge. */
function tuft(x, y, s, tone) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    <path d="M -9 0 C -8 -8, -6 -13, -3 -17" stroke="${tone}" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M 0 0 C 0 -10, 1 -16, 3 -22" stroke="${tone}" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M 9 0 C 9 -7, 8 -12, 6 -16" stroke="${tone}" stroke-width="4" fill="none" stroke-linecap="round"/>
  </g>`;
}

/**
 * The default HopPotty outdoors: warm sky, a low sun, two soft hills and a
 * grass shelf for a character to stand on.
 *
 * `horizon` is the fraction of the box the sky occupies.
 */
function meadow(w, h, { horizon = 0.66, pond = false, glow = null, dim = 0, propsOffset = 46 } = {}) {
  const py = horizon * h + propsOffset;
  const y0 = h * horizon;
  const id = 'm' + Math.random().toString(36).slice(2, 7);
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="display:block">
    <defs>
      <linearGradient id="${id}sky" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${mix(P.pondBlueSoft, P.pondBlueLight, 0.18)}"/>
        <stop offset="0.55" stop-color="${mix(P.pondBlueSoft, P.cloud, 0.55)}"/>
        <stop offset="1" stop-color="${P.cloud}"/>
      </linearGradient>
      <linearGradient id="${id}near" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${P.hopGreenLight}"/>
        <stop offset="1" stop-color="${mix(P.hopGreenLight, P.hopGreen, 0.55)}"/>
      </linearGradient>
      <radialGradient id="${id}sun" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${P.sunshine}" stop-opacity="0.42"/>
        <stop offset="1" stop-color="${P.sunshine}" stop-opacity="0"/>
      </radialGradient>
      <radialGradient id="${id}glow" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.85"/>
        <stop offset="0.62" stop-color="#FFFFFF" stop-opacity="0.34"/>
        <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
      </radialGradient>
    </defs>

    <rect width="${w}" height="${h}" fill="url(#${id}sky)"/>
    <circle cx="${w * 0.82}" cy="${h * 0.13}" r="${w * 0.34}" fill="url(#${id}sun)"/>
    <circle cx="${w * 0.82}" cy="${h * 0.13}" r="${w * 0.085}" fill="${P.sunshineSoft}"/>

    ${cloud(w * 0.2, h * 0.13, 0.95, '#FFFFFF', 0.8)}
    ${cloud(w * 0.72, h * 0.27, 0.62, '#FFFFFF', 0.6)}
    ${cloud(w * 0.05, h * 0.33, 0.5, '#FFFFFF', 0.45)}

    <!-- far hills -->
    <path d="M 0 ${y0 - 40} C ${w * 0.18} ${y0 - 92}, ${w * 0.42} ${y0 - 88}, ${w * 0.58} ${y0 - 44}
             C ${w * 0.74} ${y0 - 4}, ${w * 0.9} ${y0 - 18}, ${w} ${y0 - 46} L ${w} ${h} L 0 ${h} Z"
          fill="${mix(P.hopGreenSoft, P.hopGreenLight, 0.45)}"/>
    <path d="M 0 ${y0 - 6} C ${w * 0.22} ${y0 - 46}, ${w * 0.5} ${y0 - 40}, ${w * 0.7} ${y0 - 12}
             C ${w * 0.85} ${y0 + 8}, ${w * 0.94} ${y0 - 2}, ${w} ${y0 - 14} L ${w} ${h} L 0 ${h} Z"
          fill="${mix(P.hopGreenLight, P.hopGreenSoft, 0.35)}"/>

    <!-- near ground -->
    <path d="M 0 ${y0 + 26} C ${w * 0.26} ${y0 - 2}, ${w * 0.62} ${y0 + 2}, ${w} ${y0 + 30} L ${w} ${h} L 0 ${h} Z"
          fill="url(#${id}near)"/>

    ${pond ? `<ellipse cx="${w * 0.5}" cy="${h * 0.93}" rx="${w * 0.46}" ry="${h * 0.1}" fill="${P.pondBlue}" opacity="0.75"/>
      <ellipse cx="${w * 0.5}" cy="${h * 0.92}" rx="${w * 0.4}" ry="${h * 0.075}" fill="${P.pondBlueLight}" opacity="0.6"/>` : ''}

    <!-- distant tufts sit on the horizon; everything taller waits until propsOffset,
         so a headline over the field never lands on a flower. -->
    ${tuft(w * 0.34, y0 + 12, 0.5, mix(P.hopGreen, P.hopGreenLight, 0.5))}
    ${tuft(w * 0.62, y0 + 16, 0.45, mix(P.hopGreen, P.hopGreenLight, 0.5))}
    ${reeds(w * 0.08, py + 4, 0.85)}
    ${reeds(w * 0.94, py + 12, 0.72)}
    ${tuft(w * 0.24, py, 1, P.hopGreenDeep)}
    ${tuft(w * 0.79, py + 8, 0.85, P.hopGreenDeep)}
    ${flower(w * 0.16, py + 20, 0.9, P.sunshine, P.sunshineDeep)}
    ${flower(w * 0.88, py + 28, 0.8, P.peachPop, P.sunshineSoft)}
    ${flower(w * 0.36, py + 36, 0.7, '#FFFFFF', P.sunshine)}

    ${glow ? `<ellipse cx="${glow[0]}" cy="${glow[1]}" rx="${glow[2]}" ry="${glow[2] * 0.92}" fill="url(#${id}glow)"/>` : ''}
    ${dim ? `<rect width="${w}" height="${h}" fill="${P.cloud}" opacity="${dim}"/>` : ''}
  </svg>`;
}

/**
 * The reward pond, proportioned for a tall phone.
 *
 * `unlocked` names which decorations are in the scene, so the same drawing shows
 * a bare pond on day one and a crowded one months later. Placement follows
 * `PondCatalog`: back to front, and nothing lands on top of anything else.
 */
function pond(w, h, unlocked = []) {
  const has = (k) => unlocked.includes(k);
  const id = 'p' + Math.random().toString(36).slice(2, 7);
  const SKY = h * 0.28, WATER = h * 0.40, SHORE = h * 0.735;
  const at = (fx, fy) => [w * fx, h * fy];

  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="display:block">
    <defs>
      <linearGradient id="${id}sky" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${mix(P.pondBlueSoft, P.pondBlueLight, 0.34)}"/>
        <stop offset="1" stop-color="${mix(P.cloud, P.sunshineSoft, 0.45)}"/>
      </linearGradient>
      <linearGradient id="${id}water" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${mix(P.pondBlueLight, P.cloud, 0.3)}"/>
        <stop offset="0.35" stop-color="${P.pondBlue}"/>
        <stop offset="1" stop-color="${mix(P.pondBlue, P.pondBlueDeep, 0.5)}"/>
      </linearGradient>
      <linearGradient id="${id}bank" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${P.hopGreenLight}"/>
        <stop offset="1" stop-color="${mix(P.hopGreenLight, P.hopGreen, 0.75)}"/>
      </linearGradient>
      <radialGradient id="${id}sun" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${P.sunshine}" stop-opacity="0.5"/>
        <stop offset="1" stop-color="${P.sunshine}" stop-opacity="0"/>
      </radialGradient>
    </defs>

    <rect width="${w}" height="${h}" fill="url(#${id}sky)"/>
    <circle cx="${w * 0.17}" cy="${SKY * 0.42}" r="${w * 0.42}" fill="url(#${id}sun)"/>
    ${has('sunbeam') ? `<circle cx="${w * 0.17}" cy="${SKY * 0.42}" r="${w * 0.09}" fill="${P.sunshine}" opacity="0.9"/>` : ''}
    ${has('cloudPuff') ? cloud(w * 0.74, SKY * 0.34, 0.95, '#FFFFFF', 0.9) : ''}
    ${cloud(w * 0.28, SKY * 0.2, 0.5, '#FFFFFF', 0.42)}
    ${has('rainbow') ? `<g opacity="0.5" fill="none" stroke-width="8" stroke-linecap="round">
        ${[P.peachPop, P.sunshine, P.hopGreenLight, P.pondBlueLight, P.lavender].map((cc, i) =>
          `<path d="M ${w * 0.34 + i * 9} ${WATER} A ${w * 0.34 - i * 9} ${h * 0.16 - i * 8} 0 0 1 ${w * 1.06 - i * 9} ${WATER}" stroke="${cc}"/>`).join('')}
      </g>` : ''}

    <!-- far bank, with the back-most plantings on it -->
    <path d="M 0 ${SKY + 26} C ${w * 0.22} ${SKY - 24}, ${w * 0.58} ${SKY - 18}, ${w * 0.78} ${SKY + 18}
             C ${w * 0.9} ${SKY + 40}, ${w * 0.96} ${SKY + 30}, ${w} ${SKY + 22} L ${w} ${WATER + 30} L 0 ${WATER + 30} Z"
          fill="${mix(P.hopGreenSoft, P.hopGreenLight, 0.55)}"/>
    ${has('blossomTree') ? `<g transform="translate(${w * 0.13} ${SKY + 16})">
        <rect x="-6" y="-20" width="12" height="46" rx="6" fill="${P.sand500}"/>
        <circle cx="-16" cy="-36" r="24" fill="${mix(P.peachSoft, P.peachPop, 0.35)}"/>
        <circle cx="13" cy="-44" r="27" fill="${mix(P.peachSoft, P.peachPop, 0.25)}"/>
        <circle cx="2" cy="-24" r="22" fill="${mix(P.peachSoft, P.peachPop, 0.45)}"/></g>` : ''}
    ${has('clubhouse') ? `<g transform="translate(${w * 0.55} ${SKY + 24})">
        <rect x="-28" y="-24" width="56" height="42" rx="7" fill="${mix(P.sand300, P.sand100, 0.5)}"/>
        <path d="M -35 -24 L 0 -50 L 35 -24 Z" fill="${P.peachDeep}" opacity="0.85"/>
        <rect x="-8" y="-4" width="16" height="22" rx="4" fill="${P.hopGreenDeep}" opacity="0.5"/></g>` : ''}
    ${has('fernPatch') ? reeds(w * 0.2, SKY + 30, 0.7, true) : ''}
    <!-- base scenery, not decorations: a pond with nothing unlocked is still a place -->
    <g opacity="0.55">
      <ellipse cx="${w * 0.08}" cy="${SKY + 20}" rx="42" ry="26" fill="${mix(P.hopGreenLight, P.hopGreen, 0.5)}"/>
      <ellipse cx="${w * 0.38}" cy="${SKY + 8}" rx="34" ry="20" fill="${mix(P.hopGreenLight, P.hopGreen, 0.35)}"/>
      <ellipse cx="${w * 0.72}" cy="${SKY + 26}" rx="46" ry="24" fill="${mix(P.hopGreenLight, P.hopGreen, 0.45)}"/>
      <ellipse cx="${w * 0.96}" cy="${SKY + 18}" rx="30" ry="18" fill="${mix(P.hopGreenLight, P.hopGreen, 0.3)}"/>
    </g>
    ${tuft(w * 0.5, WATER + 4, 0.55, mix(P.hopGreen, P.hopGreenDeep, 0.2))}
    ${tuft(w * 0.86, WATER + 2, 0.5, mix(P.hopGreen, P.hopGreenDeep, 0.2))}
    ${tuft(w * 0.16, WATER + 6, 0.5, mix(P.hopGreen, P.hopGreenDeep, 0.2))}

    <!-- water -->
    <path d="M 0 ${WATER + 8} C ${w * 0.3} ${WATER - 18}, ${w * 0.72} ${WATER - 14}, ${w} ${WATER + 10} L ${w} ${h} L 0 ${h} Z"
          fill="url(#${id}water)"/>
    <g fill="none" stroke="#FFFFFF" stroke-linecap="round">
      <path d="M ${w * 0.08} ${WATER + 46} q 26 -10 52 0 t 52 0" stroke-opacity="0.3" stroke-width="4"/>
      <path d="M ${w * 0.5} ${WATER + 92} q 24 -9 48 0 t 48 0" stroke-opacity="0.22" stroke-width="4"/>
      <path d="M ${w * 0.04} ${WATER + 150} q 24 -9 48 0 t 48 0" stroke-opacity="0.18" stroke-width="4"/>
      <path d="M ${w * 0.52} ${WATER + 196} q 22 -8 44 0 t 44 0" stroke-opacity="0.16" stroke-width="4"/>
    </g>
    ${has('moonReflection') ? `<ellipse cx="${w * 0.52}" cy="${WATER + 170}" rx="46" ry="14" fill="${P.sunshineSoft}" opacity=".4"/>` : ''}

    <!-- things in the water -->
    ${has('waterLilyCluster') ? lilyPad(...at(0.22, 0.66), 0.8, mix(P.hopGreen, P.hopGreenLight, 0.35)) : ''}
    ${has('lilyPadLarge') ? lilyPad(...at(0.56, 0.508), 1.6, mix(P.hopGreen, P.hopGreenDeep, 0.3)) : ''}
    ${has('lilyPadSmall') ? lilyPad(...at(0.3, 0.585), 0.95, mix(P.hopGreen, P.hopGreenDeep, 0.12)) : ''}
    ${has('lilyFlower') ? `<g transform="translate(${w * 0.78} ${h * 0.545})">
        ${[0, 60, 120, 180, 240, 300].map((a) => `<ellipse cx="0" cy="-8" rx="5" ry="10" fill="#FFFFFF" transform="rotate(${a})"/>`).join('')}
        <circle r="4.4" fill="${P.sunshine}"/></g>` : ''}
    ${has('fishOrange') ? `<g transform="translate(${w * 0.72} ${h * 0.64})">
        <ellipse rx="17" ry="10" fill="${P.peachPop}"/><path d="M15 0 L28 -9 L28 9 Z" fill="${P.peachPop}"/>
        <circle cx="-7" cy="-2" r="2.6" fill="${INK_}"/></g>` : ''}
    ${has('fishBlue') ? `<g transform="translate(${w * 0.24} ${h * 0.7}) scale(-1 1)">
        <ellipse rx="13" ry="8" fill="${P.pondBlueLight}"/><path d="M11 0 L21 -7 L21 7 Z" fill="${P.pondBlueLight}"/>
        <circle cx="-5" cy="-2" r="2.2" fill="${INK_}"/></g>` : ''}
    ${has('tadpoleFriend') ? `<g transform="translate(${w * 0.44} ${h * 0.685})">
        <circle r="10" fill="${P.hopGreenDeep}"/><path d="M9 0 C 16 -7, 22 7, 28 0 C 22 4, 16 9, 9 0Z" fill="${P.hopGreenDeep}"/>
        <circle cx="-2" cy="-3" r="2.6" fill="#FFFFFF"/></g>` : ''}
    ${has('duckling') ? `<g transform="translate(${w * 0.66} ${h * 0.575})">
        <ellipse rx="19" ry="14" fill="${P.sunshine}"/><circle cx="-14" cy="-14" r="11" fill="${P.sunshine}"/>
        <path d="M -24 -14 l -9 3 9 4 z" fill="${P.sunshineDeep}"/><circle cx="-16" cy="-17" r="2" fill="${INK_}"/></g>` : ''}
    ${has('turtleRock') ? `<g transform="translate(${w * 0.16} ${h * 0.62})">
        <ellipse rx="20" ry="11" fill="${P.sand300}"/><ellipse cy="-6" rx="15" ry="9" fill="${mix(P.sand300, P.sand100, .4)}"/></g>` : ''}

    <!-- near shore -->
    <path d="M 0 ${SHORE + 12} C ${w * 0.26} ${SHORE - 26}, ${w * 0.68} ${SHORE - 22}, ${w} ${SHORE + 6} L ${w} ${h} L 0 ${h} Z"
          fill="url(#${id}bank)"/>
    ${has('reedsLeft') ? reeds(w * 0.08, SHORE + 16, 1.15, true) : ''}
    ${has('reedsRight') ? reeds(w * 0.93, SHORE + 10, 1.0, true) : ''}
    ${has('cattails') ? reeds(w * 0.19, SHORE + 30, 0.85, true) : ''}
    ${has('stoneSmall') ? `<ellipse cx="${w * 0.3}" cy="${SHORE + 6}" rx="21" ry="13" fill="${P.sand300}"/>` : ''}
    ${has('stoneStack') ? `<g transform="translate(${w * 0.1} ${h * 0.94})">
        <ellipse rx="20" ry="10" fill="${P.sand300}"/><ellipse cy="-15" rx="15" ry="8" fill="${mix(P.sand300, P.sand100, 0.4)}"/>
        <ellipse cy="-27" rx="10" ry="6" fill="${P.sand300}"/></g>` : ''}
    ${has('mushroomCluster') ? `<g transform="translate(${w * 0.42} ${h * 0.96})">
        <rect x="-4" y="-14" width="8" height="16" rx="4" fill="${P.sand100}"/>
        <path d="M -15 -13 a 15 12 0 0 1 30 0 z" fill="${P.peachDeep}"/>
        <circle cx="-5" cy="-17" r="2.6" fill="${P.cloud}"/></g>` : ''}
    ${has('flowerYellow') ? flower(w * 0.16, SHORE + 22, 1.05, P.sunshine, P.sunshineDeep) : ''}
    ${has('flowerPink') ? flower(w * 0.84, SHORE + 16, 1.0, P.peachPop, P.sunshineSoft) : ''}
    ${has('flowerPurple') ? flower(w * 0.68, SHORE + 28, 0.9, P.lavender, P.sunshineSoft) : ''}
    ${has('snail') ? `<g transform="translate(${w * 0.56} ${SHORE + 44})">
        <ellipse cx="6" cy="4" rx="12" ry="5" fill="${P.sand500}"/>
        <circle cx="0" cy="0" r="9" fill="${P.peachDeep}"/><circle cx="0" cy="0" r="4.4" fill="${P.peachSoft}"/></g>` : ''}

    <!-- in front of everything -->
    ${has('butterflyBlue') ? `<g transform="translate(${w * 0.19} ${h * 0.44})">
        <ellipse cx="-9" cy="-3" rx="10" ry="12" fill="${P.pondBlueLight}" transform="rotate(-22)"/>
        <ellipse cx="9" cy="-3" rx="10" ry="12" fill="${P.pondBlue}" transform="rotate(22)"/>
        <rect x="-1.8" y="-10" width="3.6" height="19" rx="1.8" fill="${INK_}" opacity="0.7"/></g>` : ''}
    ${has('butterflyYellow') ? `<g transform="translate(${w * 0.86} ${h * 0.47})">
        <ellipse cx="-8" cy="-3" rx="9" ry="11" fill="${P.sunshine}" transform="rotate(-22)"/>
        <ellipse cx="8" cy="-3" rx="9" ry="11" fill="${P.sunshineBright}" transform="rotate(22)"/>
        <rect x="-1.6" y="-9" width="3.2" height="17" rx="1.6" fill="${INK_}" opacity="0.7"/></g>` : ''}
    ${has('dragonfly') ? `<g transform="translate(${w * 0.6} ${h * 0.36})">
        <ellipse cx="-12" cy="-5" rx="15" ry="5" fill="${P.pondBlueLight}" opacity="0.85" transform="rotate(-14)"/>
        <ellipse cx="12" cy="-5" rx="15" ry="5" fill="${P.pondBlueLight}" opacity="0.85" transform="rotate(14)"/>
        <rect x="-2" y="-4" width="4" height="24" rx="2" fill="${P.lavenderDeep}"/></g>` : ''}
    ${has('fireflies') ? [[0.86, 0.62], [0.9, 0.68], [0.8, 0.66]].map(([fx, fy]) =>
        `<circle cx="${w * fx}" cy="${h * fy}" r="5" fill="${P.sunshine}" opacity="0.9"/>
         <circle cx="${w * fx}" cy="${h * fy}" r="11" fill="${P.sunshine}" opacity="0.28"/>`).join('') : ''}
  </svg>`;
}

/**
 * The hand-washing game's environment: a basin, a running tap and warm tile.
 * Deliberately quiet; the bubbles are the only thing that should catch an eye.
 */
function washroom(w, h) {
  const id = 'b' + Math.random().toString(36).slice(2, 7);
  const basinY = h * 0.72;
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="display:block">
    <defs>
      <linearGradient id="${id}wall" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${mix(P.pondBlueSoft, P.cloud, 0.25)}"/>
        <stop offset="1" stop-color="${mix(P.pondBlueSoft, P.pondBlueLight, 0.22)}"/>
      </linearGradient>
      <linearGradient id="${id}basin" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="${mix(P.cloud, P.sand200, 0.5)}"/>
      </linearGradient>
    </defs>
    <rect width="${w}" height="${h}" fill="url(#${id}wall)"/>
    <g opacity="0.5" stroke="#FFFFFF" stroke-width="2">
      ${[0.22, 0.4, 0.58].map((t) => `<path d="M 0 ${h * t} H ${w}"/>`).join('')}
      ${[0.25, 0.5, 0.75].map((t) => `<path d="M ${w * t} 0 V ${h * 0.58}"/>`).join('')}
    </g>
    <!-- tap -->
    <g transform="translate(${w * 0.5} ${basinY - 108})">
      <rect x="-9" y="0" width="18" height="42" rx="9" fill="${mix(P.sand300, P.cloud, 0.3)}"/>
      <path d="M 0 4 C 0 -22, 34 -22, 34 4 L 34 16" fill="none" stroke="${mix(P.sand300, P.cloud, 0.3)}" stroke-width="15" stroke-linecap="round"/>
      <path d="M 34 22 v 44" stroke="${P.pondBlueLight}" stroke-width="10" stroke-linecap="round" opacity="0.75"/>
    </g>
    <!-- basin -->
    <path d="M ${w * 0.14} ${basinY} h ${w * 0.72} a 26 26 0 0 1 -26 30 h ${-w * 0.72 + 52} a 26 26 0 0 1 -26 -30 z" fill="url(#${id}basin)"/>
    <ellipse cx="${w * 0.5}" cy="${basinY}" rx="${w * 0.36}" ry="15" fill="${P.pondBlueSoft}"/>
    <ellipse cx="${w * 0.5}" cy="${basinY}" rx="${w * 0.36}" ry="15" fill="none" stroke="#FFFFFF" stroke-width="4"/>
    <rect x="${w * 0.1}" y="${basinY + 30}" width="${w * 0.8}" height="${h - basinY - 30}" fill="${mix(P.cloud, P.sand200, 0.35)}" opacity="0.6"/>
    <!-- soap -->
    <g transform="translate(${w * 0.84} ${basinY - 34})">
      <rect x="-16" y="0" width="32" height="34" rx="10" fill="${mix(P.lavenderSoft, P.lavender, 0.35)}"/>
      <rect x="-6" y="-14" width="12" height="16" rx="5" fill="${mix(P.lavenderSoft, P.lavender, 0.6)}"/>
    </g>
  </svg>`;
}

/**
 * The hand-washing game: warm light, a bank of foam to stand in, nothing else.
 *
 * An earlier version drew a basin and a tap. At this size they read as clutter
 * competing with the bubbles, which are the only thing the child may touch.
 */
function soap(w, h, { foamY = 0.74 } = {}) {
  const id = 's' + Math.random().toString(36).slice(2, 7);
  const y = h * foamY;
  const blob = (cx, r, o) => `<circle cx="${cx}" cy="${y + 10}" r="${r}" fill="#FFFFFF" opacity="${o}"/>`;
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="display:block">
    <defs>
      <linearGradient id="${id}air" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${mix(P.pondBlueSoft, P.pondBlueLight, 0.3)}"/>
        <stop offset="0.62" stop-color="${mix(P.pondBlueSoft, P.cloud, 0.55)}"/>
        <stop offset="1" stop-color="${P.cloud}"/>
      </linearGradient>
      <radialGradient id="${id}warm" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${P.sunshineSoft}" stop-opacity="0.7"/>
        <stop offset="1" stop-color="${P.sunshineSoft}" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <rect width="${w}" height="${h}" fill="url(#${id}air)"/>
    <circle cx="${w * 0.5}" cy="${y - 40}" r="${w * 0.62}" fill="url(#${id}warm)"/>
    <g opacity="0.5">
      <circle cx="${w * 0.14}" cy="${h * 0.2}" r="46" fill="#FFFFFF" opacity="0.35"/>
      <circle cx="${w * 0.88}" cy="${h * 0.36}" r="62" fill="#FFFFFF" opacity="0.28"/>
    </g>
    <path d="M 0 ${y + 26} C ${w * 0.2} ${y - 4}, ${w * 0.8} ${y - 4}, ${w} ${y + 26} L ${w} ${h} L 0 ${h} Z"
          fill="${mix(P.pondBlueSoft, P.cloud, 0.62)}"/>
    ${blob(w * 0.06, 40, 0.95)}${blob(w * 0.24, 52, 0.95)}${blob(w * 0.46, 44, 0.95)}
    ${blob(w * 0.68, 56, 0.95)}${blob(w * 0.9, 42, 0.95)}
    <rect x="0" y="${y + 22}" width="${w}" height="${h - y - 22}" fill="${mix(P.pondBlueSoft, P.cloud, 0.42)}"/>
    ${blob(w * 0.15, 26, 0.9)}${blob(w * 0.36, 30, 0.9)}${blob(w * 0.58, 24, 0.9)}${blob(w * 0.8, 30, 0.9)}
    <circle cx="${w * 0.16}" cy="${y - 6}" r="13" fill="#FFFFFF" opacity="0.8"/>
    <circle cx="${w * 0.76}" cy="${y - 16}" r="9" fill="#FFFFFF" opacity="0.7"/>
    <circle cx="${w * 0.55}" cy="${y - 24}" r="7" fill="#FFFFFF" opacity="0.6"/>
  </svg>`;
}

/** The calm ground for a screen that asks a question rather than shows a place. */
function dome(w, height, fill) {
  return `<svg width="${w}" height="${height}" viewBox="0 0 ${w} ${height}" style="display:block">
    <path d="M 0 0 H ${w} V ${height - 62} C ${w * 0.78} ${height + 10}, ${w * 0.22} ${height + 10}, 0 ${height - 62} Z" fill="${fill}"/>
  </svg>`;
}

module.exports = { meadow, pond, washroom, soap, dome, cloud, reeds, flower, lilyPad, tuft };
