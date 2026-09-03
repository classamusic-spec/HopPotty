/**
 * The rest of the child's world: the four routine steps after the first, the
 * gentle sit timer, the games hub and every mini-game board.
 *
 * Two ideas hold these together.
 *
 *  - **The drawing carries the meaning.** `PottyRoutineStep.illustrationLabel`
 *    says so outright, so every step and every game shows its finished vector
 *    from `Art/scenes/` at full size inside a card, never a redraw and never a
 *    decorative crop. Those scenes are 4:3, so each card's picture band is 4:3
 *    exactly and nothing is cut off.
 *  - **A board is a place.** The same scene is blurred up behind the whole
 *    screen, the way the Potty Pause shield blurs the app behind it, so the card
 *    sits in the room it is a picture of rather than on a blank page.
 *
 * Child-safety rules these screens are built around: nothing is scored, nothing
 * is lost, no clock is ever shown as a countdown, and no game is locked. The sit
 * timer fills rather than empties, and the tummy meter fills rather than drains.
 *
 * Colour, radius, type and hit targets come from `Scripts/tokens.json` like
 * every other screen here. The one exception is the mud, whose browns are lifted
 * out of `games-mudOff.svg`: a sprite sitting on that scene has to be the same
 * mud as the puddles already drawn in it.
 */
const fs = require('fs');
const path = require('path');
const { T, c, type, svg, statusBar, homeIndicator, alpha, mix, elevation, artOr, ROOT } = require('./ui');
const { childButton, MARK } = require('./kit');
const { stage, room, skipRow, grownUpRow, words, veil, bubbleWashStage } = require('./child');
const scenes = require('./scenes');
const hopArt = require('../hop-art');

const P = T.palette;

/** Ink for body copy, resolved per appearance. */
const ink = (appearance) => (appearance.startsWith('dark') ? c(appearance).textPrimary : P.midnight);

/**
 * A vector as a CSS background value.
 *
 * Full-bleed art is a background rather than an `<img>` on purpose: `cover` does
 * the cropping arithmetic, and a layer that is meant to bleed past the viewport
 * is not something the overflow check has to treat as content.
 */
function bgImage(rel) {
  const abs = path.join(ROOT, rel);
  if (!fs.existsSync(abs)) return null;
  // Single quotes: this value is interpolated into a double-quoted `style`
  // attribute, and a double quote here would close the attribute early.
  return `url('data:image/svg+xml;base64,${Buffer.from(fs.readFileSync(abs, 'utf8')).toString('base64')}')`;
}

// ---------------------------------------------------------------------------
// Ground
// ---------------------------------------------------------------------------

/**
 * The room a card is a picture of.
 *
 * The scene fills the whole phone, blurred until it reads as light and wall
 * rather than as a second picture, then veiled back towards the page colour so
 * the type over it keeps its contrast.
 */
function ambient(art, appearance, { veil = 0.3, blur = 42, glow = null } = {}) {
  const col = c(appearance);
  const url = bgImage(art);
  const dark = appearance.startsWith('dark');
  return `<div style="position:absolute;inset:0;overflow:hidden;background:${col.backgroundPrimary}">
    ${url ? `<div style="position:absolute;inset:-96px;background-image:${url};background-size:cover;
      background-position:center;background-repeat:no-repeat;filter:blur(${blur}px)"></div>` : ''}
    <div style="position:absolute;inset:0;background:${alpha(col.backgroundPrimary, veil)}"></div>
    ${glow ? `<div style="position:absolute;left:${glow[0] - glow[2]}px;top:${glow[1] - glow[2]}px;
      width:${glow[2] * 2}px;height:${glow[2] * 2}px;border-radius:50%;
      background:radial-gradient(circle, ${alpha('#FFFFFF', dark ? 0.07 : 0.3)} 0%, ${alpha('#FFFFFF', 0)} 72%)"></div>` : ''}
  </div>`;
}

/** A character, feet on the bottom edge of its own box. */
function hopAt(pose, width, style) {
  return `<div data-hop style="position:absolute;${style};width:${width}px;height:${width}px">
    ${svg(`Art/character/hop-${pose}.svg`, { width })}</div>`;
}

// ---------------------------------------------------------------------------
// The card every board and every step is built on
// ---------------------------------------------------------------------------

/**
 * Picture band plus optional tray.
 *
 * `svgLayer` is drawn in the picture band's own coordinates, so `frame()` can
 * put a sprite exactly on a feature of the scene it is sitting on.
 */
function boardCard(appearance, {
  art, w = 369, svgLayer = '', htmlLayer = '', tray = '', trayH = 0, radius = T.radius.xxl,
}) {
  const col = c(appearance);
  const sceneH = Math.round((w * 3) / 4);
  return `<div style="position:relative;width:${w}px;border-radius:${radius}px;overflow:hidden;
      background:${col.surface};box-shadow:${elevation(appearance, 'floating')}">
    <div style="position:relative;width:${w}px;height:${sceneH}px">
      <div style="position:absolute;inset:0">${artOr([art], { width: w, height: sceneH }, '')}</div>
      ${svgLayer ? `<svg width="${w}" height="${sceneH}" viewBox="0 0 ${w} ${sceneH}"
        style="position:absolute;left:0;top:0;display:block">${svgLayer}</svg>` : ''}
      ${htmlLayer}
    </div>
    ${tray ? `<div style="height:${trayH}px;display:flex;flex-direction:column;align-items:center;
      justify-content:center;gap:13px;padding:0 16px;
      box-shadow:inset 0 1px 0 ${alpha(P.midnight, 0.07)}">${tray}</div>` : ''}
  </div>`;
}

/** Scene coordinates (the art's own 640×480) → card coordinates. */
const frame = (w) => {
  const s = w / 640;
  return { s, x: (v) => +(v * s).toFixed(1), y: (v) => +(v * s).toFixed(1) };
};


/**
 * The scene, bled edge to edge.
 *
 * The picture used to sit inside a rounded white card floating on a blurred
 * copy of itself, which is the single change that made every one of these
 * screens read as an app rather than as a place. It is now the same picture at
 * full width with its top and bottom masked away, over the same blurred copy —
 * so the sharp middle melts into a soft continuation of itself and the screen
 * has no frame anywhere on it.
 */
function worldBand(art, { top, height = 295 }) {
  const url = bgImage(art);
  if (!url) return '';
  const fade = 'linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,1) 17%, ' +
    'rgba(0,0,0,1) 83%, rgba(0,0,0,0) 100%)';
  return `<div style="position:absolute;left:0;top:${top}px;width:393px;height:${height}px;
    background-image:${url};background-size:cover;background-position:center;background-repeat:no-repeat;
    -webkit-mask-image:${fade};mask-image:${fade}"></div>`;
}

// ---------------------------------------------------------------------------
// Sprites — the small pieces a board moves around
// ---------------------------------------------------------------------------

/** A four-point sparkle, the same shape the scene art uses. */
const sparkPath = (r) => `M 0 ${-r} q ${(r * 0.28).toFixed(2)} ${(r * 0.72).toFixed(2)} ${r} ${r} ` +
  `q ${(-r * 0.72).toFixed(2)} ${(r * 0.28).toFixed(2)} ${-r} ${r} ` +
  `q ${(-r * 0.28).toFixed(2)} ${(-r * 0.72).toFixed(2)} ${-r} ${-r} ` +
  `q ${(r * 0.72).toFixed(2)} ${(-r * 0.28).toFixed(2)} ${r} ${-r} Z`;

const sparkle = (x, y, r, fill, o = 1) =>
  `<g transform="translate(${x} ${y})" opacity="${o}"><path d="${sparkPath(r)}" fill="${fill}"/></g>`;

/** Three sparkles where a patch of mud used to be. */
const sparkleBurst = (x, y, s) => `<g transform="translate(${x} ${y}) scale(${s})">
  ${sparkle(0, 0, 13, P.pondBlueLight)}${sparkle(17, 17, 8, '#FFFFFF')}${sparkle(-16, 15, 6.4, P.sunshine, 0.95)}</g>`;

/** A fly: two soft wings, a round body, two friendly eyes. */
function fly(x, y, s, body, { rot = 0, trail = false } = {}) {
  const k = s / 40;
  return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${k})">
    ${trail ? `<g fill="${body}" opacity=".22"><circle cx="-24" cy="6" r="3.4"/><circle cx="-36" cy="9" r="2.4"/>
      <circle cx="-47" cy="12" r="1.7"/></g>` : ''}
    <ellipse cx="-7" cy="-9" rx="11" ry="7" fill="#FFFFFF" opacity=".7" transform="rotate(-30 -7 -9)"/>
    <ellipse cx="7" cy="-9" rx="11" ry="7" fill="#FFFFFF" opacity=".7" transform="rotate(30 7 -9)"/>
    <ellipse cx="0" cy="2" rx="10" ry="8.4" fill="${body}"/>
    <ellipse cx="0" cy="6" rx="7" ry="4.6" fill="#FFFFFF" opacity=".22"/>
    <circle cx="-3.6" cy="-1.4" r="3" fill="#FFFFFF"/><circle cx="3.6" cy="-1.4" r="3" fill="#FFFFFF"/>
    <circle cx="-3.2" cy="-0.9" r="1.5" fill="${P.midnight}"/><circle cx="4" cy="-0.9" r="1.5" fill="${P.midnight}"/>
  </g>`;
}

/**
 * Hop's hand, exactly as `routine-highFive.svg` draws it.
 *
 * Copied rather than re-invented, so the hand a child wipes clean in Mud Off is
 * the same hand they high-five at the end of the routine.
 */
function hopHand(x, y, s, { rot = 0, flip = false, fill = hopArt.HAND.skin } = {}) {
  // The same hand Bubble Wash draws, from the same definition: Mud Off is the
  // other close-up of the child's hands and they were two different drawings.
  const pieces = hopArt.handShapes();
  const grown = hopArt.grownEls(pieces, 5);
  const filled = pieces.map((sh) => hopArt.fillEl(sh, fill)).join('');
  return `<g transform="translate(${x} ${y}) ${flip ? 'scale(-1 1) ' : ''}rotate(${rot}) scale(${s})"
    style="filter:drop-shadow(0 8px 12px ${alpha(P.midnight, 0.26)})">
    <g fill="${P.cloud}" stroke="${P.cloud}" stroke-linejoin="round" stroke-linecap="round">${grown}</g>
    ${filled}
    ${hopArt.handCreases(hopArt.HAND.skinDeep)}
  </g>`;
}

/** The browns come out of `games-mudOff.svg`; the sprite has to match the scene. */
const MUD = { brown: '#B07747', brownLight: '#C08A5E', green: P.hopGreenDeep, paint: P.lavender };

/** A blob of mud, drawn irregular so no two patches read as the same object. */
function mudPatch(x, y, r, tone, { rot = 0 } = {}) {
  const k = r / 20;
  return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${k})">
    <path d="M -3 -19 q 13 -5 18 5 q 9 8 2 17 q 2 12 -10 14 q -9 6 -17 -2 q -13 -2 -12 -14 q -6 -11 4 -16 q 5 -6 15 -4 Z"
      fill="${tone}"/>
    <path d="M -8 -9 q 8 -4 12 3 q -6 6 -12 -3 Z" fill="#FFFFFF" opacity=".22"/>
    <circle cx="16" cy="15" r="4.6" fill="${tone}"/>
    <circle cx="-18" cy="12" r="3.2" fill="${tone}"/>
  </g>`;
}

/** The rings that say "a finger goes here". A pulse, never a countdown. */
function tapHint(x, y, r, tint, { rings = 3 } = {}) {
  const ring = (k, sw, o) => `<circle r="${(r * k).toFixed(1)}" stroke-width="${sw}" opacity="${o}"/>`;
  return `<g transform="translate(${x} ${y})" fill="none" stroke="${tint}" stroke-linecap="round">
    ${ring(1, 4, 0.85)}${rings > 1 ? ring(1.4, 3, 0.36) : ''}${rings > 2 ? ring(1.86, 2.4, 0.17) : ''}
  </g>`;
}

/** A dashed swipe path with a fingertip at the near end. */
function swipeHint(x, y, len, tint) {
  return `<g transform="translate(${x} ${y})">
    <path d="M ${-len / 2} 8 q ${len / 4} -22 ${len / 2} -4 q ${len / 4} 18 ${len / 2} -6" fill="none"
      stroke="${tint}" stroke-width="5" stroke-linecap="round" stroke-dasharray="0.1 13" opacity=".8"
      style="filter:drop-shadow(0 0 2px ${alpha('#FFFFFF', 0.9)})"/>
    <circle cx="${len / 2}" cy="-2" r="13" fill="${alpha('#FFFFFF', 0.92)}"/>
    <circle cx="${len / 2}" cy="-2" r="13" fill="none" stroke="${tint}" stroke-width="3.6"/>
  </g>`;
}

/** Hop's thought bubble: the signal a child is watching for. */
function thoughtBubble(x, y, s, tint, glyph) {
  const k = s / 100;
  return `<g transform="translate(${x} ${y}) scale(${k})">
    <circle cx="-46" cy="54" r="7" fill="#FFFFFF"/>
    <circle cx="-30" cy="40" r="11.5" fill="#FFFFFF"/>
    <ellipse cx="0" cy="0" rx="50" ry="39" fill="#FFFFFF"/>
    <ellipse cx="0" cy="0" rx="50" ry="39" fill="none" stroke="${tint}" stroke-width="4" stroke-opacity=".4"/>
    <g transform="translate(0 2)">${glyph}</g>
  </g>`;
}

/** A soft ball, the toy Hop is playing with when the signal arrives. */
function ball(x, y, r, tint, light) {
  return `<g transform="translate(${x} ${y})">
    <ellipse cx="0" cy="${r + 5}" rx="${r * 0.9}" ry="${r * 0.24}" fill="${P.midnight}" opacity=".1"/>
    <circle r="${r}" fill="${tint}"/>
    <path d="M ${-r} 0 a ${r} ${r * 0.42} 0 0 0 ${r * 2} 0 a ${r} ${r * 0.42} 0 0 0 ${-r * 2} 0 Z" fill="${light}" opacity=".75"/>
    <ellipse cx="${-r * 0.34}" cy="${-r * 0.42}" rx="${r * 0.3}" ry="${r * 0.2}" fill="#FFFFFF" opacity=".6"
      transform="rotate(-24 ${-r * 0.34} ${-r * 0.42})"/>
  </g>`;
}

/** Water going round: two arcs and an arrow head. Flush and Wave's vocabulary. */
function swirl(x, y, r, tint, o = 1) {
  const sw = Math.max(2.2, r * 0.19).toFixed(1);
  return `<g transform="translate(${x} ${y})" opacity="${o}">
    <g fill="none" stroke="${tint}" stroke-linecap="round" stroke-width="${sw}">
      <path d="M ${(r * 0.96).toFixed(1)} ${(-r * 0.12).toFixed(1)}
               a ${r} ${(r * 0.62).toFixed(1)} 0 1 1 ${(-r * 0.7).toFixed(1)} ${(-r * 0.44).toFixed(1)}"/>
      <path d="M ${(r * 0.5).toFixed(1)} ${(r * 0.2).toFixed(1)}
               a ${(r * 0.5).toFixed(1)} ${(r * 0.32).toFixed(1)} 0 1 1 ${(-r * 0.36).toFixed(1)} ${(-r * 0.22).toFixed(1)}"
        opacity=".75"/>
    </g>
    <path d="M ${(r * 0.96).toFixed(1)} ${(-r * 0.46).toFixed(1)} l ${(r * 0.3).toFixed(1)} ${(r * 0.34).toFixed(1)}
             l ${(-r * 0.34).toFixed(1)} ${(r * 0.26).toFixed(1)} Z" fill="${tint}"/>
  </g>`;
}

// ---------------------------------------------------------------------------
// Picture cards and tiles
// ---------------------------------------------------------------------------

/** Pictographs for Potty Order's four cards and Bathroom Match's tiles. */
const PICT = {
  pants: (f) => `<g fill="${f}"><path d="M -19 -20 h 38 l 5 42 h -15 l -9 -25 l -9 25 h -15 Z"/>
    <rect x="-21" y="-26" width="42" height="9" rx="4.5"/></g>`,
  sit: (f) => `<g><path d="M -21 -7 q 0 25 21 25 q 21 0 21 -25 Z" fill="${f}"/>
    <ellipse cx="0" cy="-8" rx="25" ry="9.5" fill="${f}"/>
    <ellipse cx="0" cy="-9" rx="13.5" ry="4.6" fill="#FFFFFF" opacity=".92"/>
    <rect x="-6" y="17" width="12" height="7" rx="3.5" fill="${f}"/></g>`,
  wipe: (f) => `<g><circle r="21" fill="${f}"/><circle r="8" fill="#FFFFFF"/>
    <circle r="14" fill="none" stroke="#FFFFFF" stroke-width="2" opacity=".38"/>
    <path d="M 19 6 q 13 3 13 17 h -14 Z" fill="${f}" opacity=".72"/></g>`,
  wash: (f) => `<g fill="${f}"><circle cx="-9" cy="-6" r="10.5"/><circle cx="8" cy="5" r="13.5"/>
    <circle cx="-9" cy="13" r="6.4" opacity=".72"/></g>`,
  soap: (f) => `<g><path d="M -14 16 q -5 -32 14 -32 q 19 0 14 32 Z" fill="${f}"/>
    <rect x="-11" y="-2" width="22" height="7" rx="3.5" fill="#FFFFFF" opacity=".6"/>
    <rect x="-6" y="-25" width="12" height="11" rx="4" fill="${f}" opacity=".7"/>
    <path d="M 0 -28 h 11 q 5 0 5 5 v 4" stroke="${f}" stroke-width="5.5" fill="none" stroke-linecap="round" opacity=".7"/></g>`,
  towel: (f) => `<g><rect x="-19" y="-20" width="38" height="40" rx="10" fill="${f}"/>
    <rect x="-19" y="1" width="38" height="5" rx="2.5" fill="#FFFFFF" opacity=".9"/>
    <rect x="-19" y="9" width="38" height="5" rx="2.5" fill="#FFFFFF" opacity=".6"/>
    <path d="M 19 -20 v 13 h -13 Z" fill="#FFFFFF" opacity=".34"/></g>`,
  /** A tile still face down: the same quiet target the scene's empty slots use. */
  back: (f) => `<g fill="none" stroke="${f}" stroke-width="3.4"><circle r="14"/>
    <circle r="4.6" fill="${f}" stroke="none"/></g>`,
};

/** One picture card from the routine: a white tile with a pictograph on it. */
function pictureCard(x, y, w, h, tint, glyph, { rot = 0, lifted = false, radius = 15 } = {}) {
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    ${lifted ? `<ellipse cx="4" cy="${h / 2 + 18}" rx="${w * 0.44}" ry="7" fill="${P.midnight}" opacity=".18"/>` : ''}
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${radius}" fill="#FFFFFF"/>
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${radius}" fill="none"
      stroke="${alpha(tint, lifted ? 0.6 : 0.34)}" stroke-width="${lifted ? 3.4 : 2.6}"/>
    <g transform="scale(${(Math.min(w, h) / 78).toFixed(3)})">${glyph(tint)}</g>
  </g>`;
}

// ---------------------------------------------------------------------------
// Progress, never a score
// ---------------------------------------------------------------------------

/**
 * A row of marks. Filled ones are things that have happened; the rest are
 * waiting, drawn as an open outline rather than a gap, so nothing looks lost.
 */
function marks(total, done, { tint, soft, size = 42, glyph = null, restGlyph = null }) {
  return `<div style="display:flex;gap:12px;align-items:center;justify-content:center">
    ${Array.from({ length: total }, (_, i) => {
      const on = i < done;
      return `<div style="width:${size}px;height:${size}px;border-radius:${size / 2}px;display:grid;place-items:center;
        ${on ? `background:${tint};box-shadow:0 2px 7px ${alpha(tint, .32)}`
        : `background:${alpha(soft || '#FFFFFF', .92)};border:2.6px solid ${alpha(tint, .24)}`}">
        ${on ? (glyph ? glyph('#FFFFFF', i) : '') : (restGlyph ? restGlyph(alpha(tint, .3), i) : '')}
      </div>`;
    }).join('')}
  </div>`;
}

/** A caption in Hop's voice, under whatever it is describing. */
function trayCaption(text, { color = P.sand600, size = 15 } = {}) {
  return `<div style="${type('parentCallout', { color, weight: 'medium' })};font-size:${size}px;text-align:center">${text}</div>`;
}

/**
 * Hop's tummy, filling up.
 *
 * Six beads that fill from the left. There is no total on screen and no number:
 * a tummy that is getting full is a friendly thing, and a bar that could look
 * like it was running out would say the opposite.
 */
function tummyMeter(filled, total = 6) {
  const bead = (i) => {
    const on = i < filled;
    return `<div style="width:31px;height:27px;border-radius:13.5px;
      ${on ? `background:linear-gradient(180deg, ${P.peachPop}, ${P.peachDeep});box-shadow:0 2px 5px ${alpha(P.peachDeep, .28)}`
      : `background:${alpha('#FFFFFF', .82)};border:2.4px solid ${alpha(P.peachDeep, .2)}`}">
      ${on ? `<div style="height:8px;margin:4px 6px 0;border-radius:4px;background:#FFFFFF;opacity:.34"></div>` : ''}
    </div>`;
  };
  return `<div style="display:flex;align-items:center;gap:12px;padding:9px 15px 9px 9px;border-radius:27px;
    background:${alpha('#FFFFFF', .94)};box-shadow:0 1px 4px ${alpha(P.midnight, .1)}">
    <div style="width:38px;height:38px;border-radius:19px;background:${P.sunshineSoft};overflow:hidden;flex:0 0 auto;
      display:grid;place-items:center">
      <div style="transform:translateY(2px)">${svg('Art/character/hop-face.svg', { width: 44 })}</div>
    </div>
    <div style="display:flex;gap:6px">${Array.from({ length: total }, (_, i) => bead(i)).join('')}</div>
  </div>`;
}

/** The sit timer, drawn the one way it is allowed to be drawn: filling up. */
function calmRing(size, progress, { track, fill, sw = 18 }) {
  const r = (size - sw) / 2;
  const circ = 2 * Math.PI * r;
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"
    style="position:absolute;left:0;top:0;display:block;transform:rotate(-90deg)">
    <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${track}" stroke-width="${sw}"/>
    <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${fill}" stroke-width="${sw}"
      stroke-linecap="round" stroke-dasharray="${circ.toFixed(1)}"
      stroke-dashoffset="${(circ * (1 - progress)).toFixed(1)}"/>
  </svg>`;
}

// ---------------------------------------------------------------------------
// 16–19, 20 — the routine
// ---------------------------------------------------------------------------

/**
 * One step of the guided routine.
 *
 * A full-screen place, and one thing to do in it. What used to be here and is
 * not any more: the five-dot indicator at the top, the five-cell named strip
 * along the bottom, and the rounded card the illustration sat inside. Between
 * them they told a child, twice, how much of a queue was still ahead of them —
 * and framed the room as a picture on a page rather than the room they are
 * standing in.
 *
 * What is left is the step's own scene, bled edge to edge; Hop, large, doing the
 * step alongside the child; one short sentence; one big button; and — only where
 * the content marks the step skippable — the word "Skip this" underneath.
 */
function routineStep(appearance, {
  art, pose, hopWidth = 250, title, instruction, primary, skip, bandTop = 190, extra = '',
}) {
  const col = c(appearance);
  const BAND_H = 295; // 393 wide at the scenes' own 4:3

  const ground = `<div style="position:absolute;inset:0;overflow:hidden">
    ${ambient(art, appearance, { veil: 0.24, blur: 46 })}
    ${worldBand(art, { top: bandTop, height: BAND_H })}
  </div>`;

  return stage(`${ground}${veil(appearance, { from: 468, height: 384, strength: 0.74 })}`, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${grownUpRow()}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        <div data-hop style="width:${hopWidth}px">${svg(`Art/character/hop-${pose}.svg`, { width: hopWidth })}</div>
      </div>

      <div style="height:${T.spacing.s}px"></div>
      ${words(title, instruction)}
      ${extra}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, primary, { kind: 'primary', height: 104, radius: T.radius.hero })}
        ${skipRow(skip)}
      </div>
    </div>`);
}

/** 16 — Wipe. */
function routineWipe(appearance = 'light') {
  return routineStep(appearance, {
    art: 'Art/scenes/routine-wipe.svg',
    pose: 'sit',
    hopWidth: 236,
    title: 'Wipe',
    instruction: 'Wipe from front to back.',
    primary: 'Next',
    skip: 'Skip this',
  });
}

/** 17 — Flush. */
function routineFlush(appearance = 'light') {
  return routineStep(appearance, {
    art: 'Art/scenes/routine-flush.svg',
    pose: 'wave',
    hopWidth: 250,
    title: 'Flush',
    instruction: 'Flush it away.',
    primary: 'Next',
    // Skippable on purpose: the noise frightens a real share of two- and
    // three-year-olds, and a routine that traps a scared child at the flush is
    // a routine they refuse tomorrow.
    skip: 'Skip this',
  });
}

/**
 * 18 — Wash.
 *
 * The wash step *is* Bubble Wash. There is no illustration of hands under a tap
 * with a "Next" under it any more: the child arrives in the close-up and rubs
 * Hop's hands, which is the same thing the standalone game does, drawn by the
 * same function so the two cannot drift.
 */
function routineWash(appearance = 'light') {
  return bubbleWashStage(appearance, { line: 'Wash those hands!', beat: 'soap' });
}

/**
 * 19 — High five.
 *
 * The last step before the celebration, and the only one whose target is a
 * drawing rather than a button: Hop's hand is up, and the thing to touch is the
 * hand. It is short by design — a second beat of praise before the celebration
 * would leave the celebration nowhere to go.
 */
function routineHighFive(appearance = 'light') {
  const col = c(appearance);
  const scene = `<div style="position:absolute;inset:0;overflow:hidden">
    ${room(appearance, { floorY: 648 })}
    <div style="position:absolute;left:0;top:0;width:393px;height:852px;
      background:radial-gradient(circle at 50% 40%, ${alpha(P.sunshineSoft, .95)} 0%, ${alpha(P.sunshineSoft, 0)} 60%)"></div>
  </div>`;

  return stage(`${scene}${veil(appearance, { from: 596, height: 256, strength: 0.66 })}`, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${grownUpRow()}

      <div style="flex:1"></div>

      <div data-hop style="flex:0 0 auto;display:flex;justify-content:center">
        ${svg('Art/character/hop-cheer.svg', { width: 306 })}
      </div>

      ${words('High five', 'High five with Hop!')}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'All done!', { kind: 'primary', height: 104, radius: T.radius.hero })}
      </div>
    </div>`);
}

/**
 * 20 — sitting, and giving it a try.
 *
 * The calm ring is drawn here because this render is the *caregiver switched it
 * on* state. It is off by default (`AppSettings.routineSitTimerEnabled`), and
 * when it is off this screen is Hop, the sentence and the button, with nothing
 * in the middle. Either way the ring fills rather than empties, nothing is
 * gated on it, and reaching the end changes nothing except that the ring is
 * full.
 */
function routineTryTimer(appearance = 'light') {
  const col = c(appearance);
  const size = 300;

  const scene = `<div style="position:absolute;inset:0;overflow:hidden">
    ${room(appearance, { floorY: 654 })}
    <div style="position:absolute;left:0;top:0;width:393px;height:852px;
      background:radial-gradient(circle at 50% 44%, ${alpha(P.cloud, .85)} 0%, ${alpha(P.cloud, 0)} 56%)"></div>
  </div>`;

  return stage(`${scene}${veil(appearance, { from: 600, height: 252, strength: 0.7 })}`, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${grownUpRow()}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        <div style="position:relative;width:${size}px;height:${size}px">
          ${calmRing(size, 0.36, { track: alpha(P.hopGreenSoft, .95), fill: P.hopGreen })}
          <div data-hop style="position:absolute;left:50%;bottom:34px;transform:translateX(-50%);width:232px">
            ${svg('Art/character/hop-sit.svg', { width: 232 })}
          </div>
        </div>
      </div>

      <div style="height:${T.spacing.s}px"></div>
      ${words('Try', 'Give it a try.', { small: 'Take all the time you need.' })}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'Next', { kind: 'primary', height: 104, radius: T.radius.hero })}
        ${skipRow('Skip this')}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 21 / 30 — the games hub
// ---------------------------------------------------------------------------

/**
 * Every game in `MiniGameCatalog.all`, in catalogue order, with its scene and
 * the line a child hears before it starts.
 *
 * Nothing here is locked and nothing is ranked: no "new" flag, no "best", no
 * progress ring on a tile. Eight games, all available, always. `focus` is where
 * in the scene the thumbnail's band is taken from, so each crop keeps the thing
 * the game is about.
 */
const GAMES = [
  { key: 'bubbleWash', title: 'Bubble Wash', desc: 'Pop every bubble to get your hands sparkly clean!', focus: 0.55 },
  { key: 'pottyPath', title: 'Potty Path', desc: 'Hop along the lily pads all the way to the potty!', focus: 0.62 },
  { key: 'bathroomMatch', title: 'Bathroom Match', desc: 'Find the two that go together.', focus: 0.44 },
  { key: 'flySnack', title: 'Fly Snack', desc: "Tap a fly and watch Hop's tongue go!", focus: 0.76 },
  { key: 'mudOff', title: 'Mud Off', desc: "Swipe the mud off Hop's hands.", focus: 0.62 },
  { key: 'bodySignal', title: 'Listen to Your Body', desc: 'Tap the bubble when it pops up.', focus: 0.46 },
  { key: 'flushWave', title: 'Flush and Wave', desc: 'Tap the flusher and wave bye-bye!', focus: 0.66 },
  { key: 'pottyOrder', title: 'Potty Order', desc: 'Put the cards on the path in order.', focus: 0.5 },
];

/** A thumbnail: the game's own scene, cropped to a band around its subject. */
function thumb(key, h, focus) {
  const url = bgImage(`Art/scenes/games-${key}.svg`);
  return `<div style="width:100%;height:${h}px;background-color:${P.sand100};
    ${url ? `background-image:${url};background-size:cover;background-position:center ${(focus * 100).toFixed(0)}%;
    background-repeat:no-repeat;` : ''}"></div>`;
}

function gamesHub(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const H = ink(appearance);

  // A door, not a card: the whole tile is the picture of the place the game
  // happens in, with its name laid on the picture. The sentence a child cannot
  // read is gone — `MiniGame.childDescription` is what Hop says out loud when
  // the game opens, which is where a pre-reader actually receives it.
  //
  // The name sits on a *nameplate*, not on a fade. A gradient that is still
  // arriving where the glyphs are put white type on a pale bathroom wall at
  // 1.6:1 — and a two-line name like "Listen to Your Body" reaches higher up the
  // fade than a one-line one, so the failure was worst on the longest title.
  // So: a solid plate deep enough to carry white type over the brightest picture
  // in the set, exactly as tall as two lines of the name, with a short fade
  // above it to join it to the scene. The plate is a caption bar on a picture —
  // part of the composition — rather than a veil over the whole tile, so the
  // illustration is undimmed everywhere it matters.
  // Tight on purpose: 46px of plate is exactly two lines of the longest name
  // plus its padding, and the 12px feather above it is only enough to stop the
  // top edge reading as a cut. Together they cover 58 of the tile's 158 — the
  // picture keeps its whole upper two-thirds undimmed, which is the trade a
  // wash over the whole tile would have lost.
  const PLATE = 48;
  const door = (g) => `
    <div style="position:relative;height:158px;border-radius:${T.radius.xxl}px;overflow:hidden;
      box-shadow:${elevation(appearance, 'resting')}">
      ${thumb(g.key, 158, g.focus)}
      <div style="position:absolute;left:0;right:0;bottom:${PLATE}px;height:12px;
        background:linear-gradient(180deg, ${alpha(P.midnight, 0)} 0%, ${alpha(P.midnight, .78)} 100%)"></div>
      <div style="position:absolute;left:0;right:0;bottom:0;height:${PLATE}px;background:${alpha(P.midnight, .78)}"></div>
      <!-- Inset past the tile's own corner radius, not just past its edge. A
           text run's rect is the width of its line box, so a caption 11px from
           a 32px-rounded corner has the page showing through the first pixel
           column of its own box — which reads fine and scores 1.6:1. -->
      <div style="position:absolute;left:18px;right:18px;bottom:11px;
        ${type('childInstruction', { color: P.cloud })};font-size:15px;line-height:1.12">${g.title}</div>
    </div>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${col.backgroundPrimary}">
    <div style="position:absolute;left:0;top:0">
      ${scenes.dome(393, 178, dark ? alpha(P.hopGreen, 0.13) : P.hopGreenSoft)}
    </div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(H)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 16px 6px;overflow:hidden">

        <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:${T.hitTarget.childMinimum}px">
          <div style="width:56px;height:56px;border-radius:28px;flex:0 0 auto;display:grid;place-items:center;
            background:${dark ? col.surfaceElevated : alpha(P.cloud, .88)};box-shadow:${elevation(appearance, 'resting')}">
            <svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="${dark ? col.textSecondary : P.sand600}"
              stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>
          </div>
          <div style="flex:1;text-align:center;${type('childTitle', { color: H })};font-size:30px">Play</div>
          <div style="width:56px"></div>
        </div>

        <div style="flex:0 0 auto;display:grid;grid-template-columns:1fr 1fr;gap:11px;margin-top:8px">
          ${GAMES.map(door).join('')}
        </div>

        <div style="flex:1"></div>
      </div>
      ${homeIndicator(H)}
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 22–28 — the boards
// ---------------------------------------------------------------------------

/**
 * The shell every mini-game board shares.
 *
 * Title, the line a child hears, the board, and one calm way out. No score, no
 * clock, and the exit is a full-width child-sized target rather than a small
 * cross in a corner.
 */
function gameScreen(appearance, {
  art, title, line, svgLayer = '', htmlLayer = '', tray = '',
  primary = null, secondary = 'All done', tint = P.hopGreenDeep, titleSize = 32, bandTop = 250,
}) {
  const col = c(appearance);
  const BAND_H = 295;
  const ground = `<div style="position:absolute;inset:0;overflow:hidden">
    ${ambient(art, appearance, { veil: 0.26, blur: 48 })}
    ${worldBand(art, { top: bandTop, height: BAND_H })}
  </div>`;

  // Sprites are positioned in the band's own coordinates, which are the scene's
  // 640×480 scaled to the full 393 — `frame(393)`.
  const board = `<div style="position:absolute;left:0;top:${bandTop}px;width:393px;height:${BAND_H}px">
    ${svgLayer ? `<svg width="393" height="${BAND_H}" viewBox="0 0 393 ${BAND_H}"
      style="position:absolute;left:0;top:0;display:block">${svgLayer}</svg>` : ''}
    ${htmlLayer}
  </div>`;

  return stage(`${ground}${veil(appearance, { from: 500, height: 352, strength: 0.6 })}`, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${grownUpRow()}

      <div style="flex:0 0 auto;text-align:center;margin-top:2px">
        <div style="${type('childTitle', { color: P.midnight })};font-size:${titleSize}px">${title}</div>
        <div style="${type('childInstruction', { color: P.midnight })};font-size:18px;margin-top:6px;opacity:.74">${line}</div>
      </div>

      <div style="flex:1"></div>

      ${tray ? `<div style="flex:0 0 auto;display:flex;flex-direction:column;align-items:center;gap:12px">${tray}</div>
        <div style="height:${T.spacing.xl}px"></div>` : ''}

      <div style="flex:0 0 auto">
        ${primary ? childButton(col, appearance, primary, { kind: 'primary', height: 96, radius: T.radius.hero }) : ''}
        ${primary && secondary ? '<div style="height:12px"></div>' : ''}
        ${secondary ? childButton(col, appearance, secondary, {
          kind: 'secondary',
          fill: alpha(col.surface, .86), textColor: tint, fontSize: 21,
        }) : ''}
      </div>
    </div>
    <div style="position:absolute;left:0;top:0;width:393px;height:852px;pointer-events:none">${board}</div>`);
}

/** 22 — Potty Path. */
function gamePottyPath(appearance = 'light') {
  const f = frame(393);
  const pads = [[92, 448], [206, 390], [306, 366], [396, 344], [472, 330]];
  const scale = [0.95, 0.85, 0.78, 0.7, 0.62];
  const done = 3;
  const padMark = (fc, notch) => `<svg viewBox="0 0 40 40" width="27" height="27">
    <ellipse cx="20" cy="21" rx="15" ry="7.4" fill="${fc}"/>
    <path d="M20 21 L34.1 18.5 A15 7.4 0 0 0 27.5 14.6 Z" fill="${notch}"/></svg>`;

  const layer = pads.map(([x, y], i) => {
    const tone = i < done ? mix(P.hopGreen, P.hopGreenDeep, 0.5) : mix(P.hopGreenLight, P.hopGreen, 0.35);
    return `${scenes.lilyPad(f.x(x), f.y(y), scale[i], tone)}
      ${i < done ? sparkle(f.x(x) + 4, f.y(y) - 13, 6, P.sunshine, 0.9) : ''}`;
  }).join('');

  return gameScreen(appearance, {
    art: 'Art/scenes/games-pottyPath.svg',
    title: 'Potty Path',
    line: 'Hop along the lily pads all the way to the potty!',
    svgLayer: layer,
    htmlLayer: hopAt('jump', 128, `left:${f.x(306) - 64}px;top:${f.y(366) + 8 - 128}px`),
    tray: marks(5, done, {
      tint: P.hopGreenDeep,
      soft: P.hopGreenSoft,
      size: 44,
      glyph: (fc) => padMark(fc, P.hopGreenDeep),
      restGlyph: (fc) => padMark(fc, 'none'),
    }),
    tint: P.hopGreenDeep,
  });
}

/** 23 — Bathroom Match. The only game with no ending of its own. */
function gameBathroomMatch(appearance = 'light') {
  const f = frame(393);
  const tile = (glyph, hue, { matched = false, faceDown = false, hint = false } = {}) => `
    <div style="width:88px;height:74px;border-radius:${T.radius.m}px;display:grid;place-items:center;position:relative;
      background:${faceDown ? alpha(hue, .13) : '#FFFFFF'};
      box-shadow:${faceDown ? 'none' : `0 2px 8px ${alpha(P.midnight, .1)}`};
      border:${matched ? `3px solid ${P.hopGreenDeep}` : faceDown ? `2.4px dashed ${alpha(hue, .42)}` : `2px solid ${alpha(hue, .22)}`};
      ${hint ? `outline:3px solid ${alpha(hue, .3)};outline-offset:5px;` : ''}">
      <svg viewBox="-30 -30 60 60" width="46" height="46">${glyph(faceDown ? alpha(hue, .5) : hue)}</svg>
      ${matched ? `<div style="position:absolute;right:-8px;top:-8px;width:24px;height:24px;border-radius:12px;
        background:${P.hopGreenDeep};display:grid;place-items:center;box-shadow:0 1px 4px ${alpha(P.midnight, .2)}">
        ${MARK.check('#FFFFFF', 14)}</div>` : ''}
    </div>`;

  return gameScreen(appearance, {
    art: 'Art/scenes/games-bathroomMatch.svg',
    title: 'Bathroom Match',
    line: 'Find the two that go together.',
    htmlLayer: hopAt('talk', 136, `left:${f.x(470) - 68}px;top:${f.y(430) - 136}px`),
    tray: `<div style="display:flex;gap:9px">
        ${tile(PICT.soap, P.lavenderDeep, { matched: true })}
        ${tile(PICT.towel, P.peachPop)}
        ${tile(PICT.back, P.lavenderDeep, { faceDown: true })}
      </div>
      <div style="display:flex;gap:9px">
        ${tile(PICT.back, P.pondBlueDeep, { faceDown: true, hint: true })}
        ${tile(PICT.soap, P.lavenderDeep, { matched: true })}
        ${tile(PICT.wipe, P.pondBlueDeep)}
      </div>`,
  });
}

/** 24 — Fly Snack. */
function gameFlySnack(appearance = 'light') {
  const f = frame(393);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-flySnack.svg',
    title: 'Fly Snack',
    line: 'Hop is on his lily pad. Tap the flies for a snack!',
    svgLayer: `
      ${fly(f.x(138), f.y(202), 34, P.pondBlue, { rot: -8, trail: true })}
      ${tapHint(f.x(430), f.y(150), 30, P.pondBlue, { rings: 2 })}
      ${fly(f.x(430), f.y(150), 31, P.hopGreenDeep, { rot: 10 })}
      ${sparkle(f.x(226), f.y(198), 7, P.sunshine, 0.9)}`,
    htmlLayer: `${hopAt('catch', 160, `left:${f.x(320) - 80}px;top:${f.y(412) - 154}px`)}
      <svg width="393" height="295" viewBox="0 0 393 295" style="position:absolute;left:0;top:0;display:block">
        ${fly(f.x(456), f.y(244), 28, P.sunshineBright, { rot: -18 })}
        ${sparkle(f.x(486), f.y(214), 6.4, '#FFFFFF', .9)}
      </svg>`,
    tray: `${tummyMeter(4)}${trayCaption("Yum! Hop's tummy is filling up.")}`,
    tint: P.hopGreenDeep,
  });
}

/** 25 — Mud Off. */
function gameMudOff(appearance = 'light') {
  const f = frame(393);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-mudOff.svg',
    title: 'Mud Off',
    line: 'Hop played by the pond! Swipe each patch away.',
    svgLayer: `
      ${hopHand(f.x(196), f.y(430), f.s * 118 / hopArt.HAND.extent, { rot: -8 })}
      ${hopHand(f.x(444), f.y(430), f.s * 118 / hopArt.HAND.extent, {
        rot: -8, flip: true, fill: hopArt.HAND.skinLight,
      })}
      ${mudPatch(f.x(193), f.y(397), f.x(32), MUD.brown, { rot: 16 })}
      ${mudPatch(f.x(447), f.y(397), f.x(27), MUD.paint, { rot: -24 })}
      ${sparkleBurst(f.x(235), f.y(350), f.s * 1.3)}
      ${sparkleBurst(f.x(405), f.y(350), f.s * 1.05)}
      ${swipeHint(f.x(200), f.y(430), f.x(150), P.pondBlueDeep)}`,
    tray: `${marks(4, 2, {
      tint: P.pondBlueDeep,
      soft: '#FFFFFF',
      size: 42,
      glyph: (fc) => `<svg viewBox="-15 -15 30 30" width="25" height="25"><path d="${sparkPath(12)}" fill="${fc}"/></svg>`,
      // The marks name the patches still on Hop's hands, in their own colours.
      restGlyph: (_, i) => `<svg viewBox="-24 -24 48 48" width="25" height="25">
        ${mudPatch(0, 0, 17, i === 2 ? MUD.brown : MUD.paint)}</svg>`,
    })}${trayCaption('One patch gone!')}`,
    tint: P.pondBlueDeep,
  });
}

/** 26 — Listen to Your Body. */
function gameBodySignal(appearance = 'light') {
  const f = frame(393);
  const bubbleMark = (fc, filled) => `<svg viewBox="-17 -17 34 34" width="27" height="27">
    <ellipse rx="13" ry="10" ${filled ? `fill="${fc}"` : `fill="none" stroke="${fc}" stroke-width="3"`}/>
    <circle cx="-11.5" cy="12.5" r="3.4" ${filled ? `fill="${fc}"` : `fill="none" stroke="${fc}" stroke-width="2.6"`}/></svg>`;

  return gameScreen(appearance, {
    art: 'Art/scenes/games-bodySignal.svg',
    title: 'Listen to Your Body',
    titleSize: 29,
    line: 'Hop is bouncing his ball. Watch for his bubble!',
    svgLayer: `${ball(f.x(404), f.y(398), f.x(34), P.peachPop, P.sunshine)}`,
    htmlLayer: `${hopAt('full', 148, `left:${f.x(270) - 74}px;top:${f.y(366) - 148}px`)}
      <svg width="393" height="295" viewBox="0 0 393 295" style="position:absolute;left:0;top:0;display:block">
        ${tapHint(f.x(486), f.y(150), f.x(132), P.pondBlue, { rings: 1 })}
        ${thoughtBubble(f.x(486), f.y(150), f.x(190), P.pondBlueDeep, `<g transform="scale(0.8)">${PICT.sit(P.pondBlueDeep)}</g>`)}
      </svg>`,
    tray: marks(3, 1, {
      tint: P.pondBlueDeep,
      soft: '#FFFFFF',
      size: 44,
      glyph: (fc) => bubbleMark(fc, true),
      restGlyph: (fc) => bubbleMark(fc, false),
    }),
    tint: P.pondBlueDeep,
  });
}

/** 27 — Flush and Wave. One cause, one effect, as often as a child likes. */
function gameFlushWave(appearance = 'light') {
  const f = frame(393);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-flushWave.svg',
    title: 'Flush and Wave',
    line: 'Tap the flusher and watch the water swirl!',
    svgLayer: `
      ${tapHint(f.x(452), f.y(254), f.x(46), P.pondBlue, { rings: 2 })}
      ${swirl(f.x(452), f.y(332), f.x(40), '#FFFFFF', 0.95)}
      ${swirl(f.x(452), f.y(332), f.x(22), P.pondBlueSoft, 0.9)}
      ${sparkle(f.x(536), f.y(288), 8, '#FFFFFF', .9)}${sparkle(f.x(372), f.y(296), 6, '#FFFFFF', .7)}`,
    htmlLayer: hopAt('wave', 140, `left:${f.x(250) - 70}px;top:${f.y(425) - 140}px`),
    tray: `${marks(3, 2, {
      tint: P.pondBlueDeep,
      soft: '#FFFFFF',
      size: 42,
      glyph: (fc) => `<svg viewBox="-17 -14 34 28" width="26" height="26">${swirl(0, 0, 13, fc)}</svg>`,
      restGlyph: (fc) => `<svg viewBox="-17 -14 34 28" width="26" height="26">${swirl(0, 0, 13, fc)}</svg>`,
    })}${trayCaption('Whoosh! Around it goes.')}`,
    primary: 'Again!',
    tint: P.pondBlueDeep,
  });
}

/**
 * 28 — Potty Order.
 *
 * The scene already carries the four dashed slots and the arrows between them,
 * so the sprites here are only the cards: two placed, one on its way down, and
 * the rest waiting in the tray. A card in the wrong slot bounces back, which is
 * why nothing on this board is marked wrong.
 */
function gamePottyOrder(appearance = 'light') {
  const f = frame(393);
  const slot = (i) => ({ cx: f.x(93 + i * 146), cy: f.y(220) });
  const cw = f.x(104);
  const ch = f.y(124);

  return gameScreen(appearance, {
    art: 'Art/scenes/games-pottyOrder.svg',
    title: 'Potty Order',
    line: 'Four cards, one path. Which one comes first?',
    svgLayer: `
      ${pictureCard(slot(0).cx, slot(0).cy, cw, ch, P.lavenderDeep, PICT.pants)}
      ${pictureCard(slot(1).cx, slot(1).cy, cw, ch, P.hopGreenDeep, PICT.sit)}
      ${pictureCard(slot(2).cx, slot(2).cy - f.y(56), cw, ch, P.peachDeep, PICT.wipe, { rot: -6, lifted: true })}
      ${sparkle(slot(1).cx + cw * 0.52, slot(1).cy - ch * 0.46, 8, P.sunshine, .95)}`,
    tray: `<div style="display:flex;gap:14px;align-items:center">
      ${[[PICT.wipe, P.peachDeep, true], [PICT.wash, P.pondBlueDeep, false]].map(([g, hue, taken]) => `
        <div style="width:74px;height:88px;border-radius:16px;display:grid;place-items:center;
          background:${taken ? alpha(P.sand100, .7) : '#FFFFFF'};
          border:${taken ? `2.6px dashed ${alpha(hue, .42)}` : `2.6px solid ${alpha(hue, .3)}`};
          ${taken ? '' : `box-shadow:0 3px 10px ${alpha(P.midnight, .12)}`}">
          <svg viewBox="-30 -30 60 60" width="44" height="44" style="${taken ? 'opacity:.3' : ''}">${g(hue)}</svg>
        </div>`).join('')}
      </div>
      ${trayCaption('That one fits!')}`,
    tint: P.hopGreenDeep,
  });
}

// ---------------------------------------------------------------------------
// 29 — the hand-off
// ---------------------------------------------------------------------------

/** What Hop is saying, drawn the way a picture book draws it. */
function speechBubble(text, { maxWidth = 268 } = {}) {
  return `<div style="position:relative;padding:14px 22px;border-radius:24px;background:#FFFFFF;
    box-shadow:0 4px 16px ${alpha(P.midnight, .12)};max-width:${maxWidth}px;text-align:center">
    <span style="${type('childInstruction', { color: P.midnight })};font-size:19px">${text}</span>
    <svg width="30" height="20" viewBox="0 0 30 20" style="position:absolute;left:50%;margin-left:-15px;bottom:-14px;display:block">
      <path d="M4 0 C 10 12, 18 17, 27 19 C 15 16, 9 9, 6 0 Z" fill="#FFFFFF"/>
    </svg>
  </div>`;
}

/**
 * 29 — Fly Snack's ending, which is the lesson: Hop ate, Hop's tummy filled, and
 * now Hop needs the potty.
 *
 * The one game whose round finishes by walking the child into the routine
 * (`MiniGameCompletion.handOffToRoutine`), so the primary is the canonical
 * "Let's Go!" and the way out is still offered beside it. Neither choice is a
 * failure and neither takes anything away.
 */
function gameFlySnackHandoff(appearance = 'light') {
  const col = c(appearance);

  return stage(ambient('Art/scenes/games-flySnack.svg', appearance, { veil: 0.32, glow: [196, 400, 236] }), `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="height:20px"></div>

      <div style="flex:0 0 auto;text-align:center">
        <div style="${type('celebration', { color: P.midnight })};font-size:35px;line-height:1.14">
          Hop's tummy says:<br>potty time!</div>
      </div>

      <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:20px">${tummyMeter(6)}</div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        ${speechBubble("Let's hop to the potty together.")}
      </div>
      <div style="height:12px"></div>
      <div style="flex:0 0 auto;display:flex;justify-content:center">
        <div data-hop style="width:257px;height:257px">${svg('Art/character/hop-full.svg', { width: 257 })}</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, "Let's Go!", { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:14px"></div>
        ${childButton(col, appearance, 'All done', {
          kind: 'secondary',
          fill: alpha('#FFFFFF', .82), textColor: P.sand600, fontSize: 21,
        })}
      </div>
    </div>`);
}

module.exports = {
  routineWipe, routineFlush, routineWash, routineHighFive, routineTryTimer,
  gamesHub,
  gamePottyPath, gameBathroomMatch, gameFlySnack, gameMudOff,
  gameBodySignal, gameFlushWave, gamePottyOrder, gameFlySnackHandoff,
};
