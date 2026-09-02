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
const { T, c, type, svg, statusBar, homeIndicator, alpha, mix, elevation, artOr } = require('./ui');
const { childButton, stepDots, MARK } = require('./kit');
const { stepStrip, grownUpChip, stage } = require('./child');
const scenes = require('./scenes');

const P = T.palette;
const W = 393;
const H = 852;

/** Ink for body copy, resolved per appearance. */
const ink = (appearance) => (appearance.startsWith('dark') ? c(appearance).textPrimary : P.midnight);

// ---------------------------------------------------------------------------
// Ground
// ---------------------------------------------------------------------------

/**
 * The room a card is a picture of.
 *
 * The scene is scaled to cover the whole phone and blurred, then veiled back to
 * the page colour. It reads as light and wall rather than as a picture, which is
 * the point: the crisp copy of the same drawing is the only thing to look at.
 */
function ambient(art, appearance, { veil = 0.46, blur = 46, glow = null } = {}) {
  const col = c(appearance);
  const aw = Math.round((H * 4) / 3);
  return `<div style="position:absolute;inset:0;overflow:hidden;background:${col.backgroundPrimary}">
    <div style="position:absolute;left:${Math.round((W - aw) / 2)}px;top:0;filter:blur(${blur}px);transform:scale(1.2)">
      ${artOr([art], { width: aw, height: H }, '')}
    </div>
    <div style="position:absolute;inset:0;background:${alpha(col.backgroundPrimary, veil)}"></div>
    ${glow ? `<div style="position:absolute;left:${glow[0]}px;top:${glow[1]}px;width:${glow[2] * 2}px;
      height:${glow[2] * 2}px;margin:-${glow[2]}px 0 0 -${glow[2]}px;border-radius:50%;
      background:radial-gradient(circle, ${alpha('#FFFFFF', appearance.startsWith('dark') ? 0.1 : 0.8)} 0%, ${alpha('#FFFFFF', 0)} 70%)"></div>` : ''}
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
 * Scene band plus optional tray.
 *
 * `svgLayer` is drawn in the picture band's own coordinates, so a sprite can be
 * placed against a feature of the scene by scaling the scene's 640×480 frame.
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
      justify-content:center;gap:11px;padding:0 16px;
      box-shadow:inset 0 1px 0 ${alpha(P.midnight, 0.06)}">${tray}</div>` : ''}
  </div>`;
}

/** Scene coordinates → card coordinates, for a card `w` wide. */
const frame = (w) => {
  const s = w / 640;
  return { s, x: (v) => +(v * s).toFixed(1), y: (v) => +(v * s).toFixed(1) };
};

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
 * Copied rather than re-invented so the hand a child wipes in Mud Off is the
 * same hand they high-five at the end of the routine.
 */
function hopHand(x, y, s, { rot = 0, flip = false, fill = P.hopGreen } = {}) {
  return `<g transform="translate(${x} ${y}) ${flip ? 'scale(-1 1) ' : ''}rotate(${rot}) scale(${s})">
    <path d="M 0 0 q -10 -60 26 -80 q 38 -20 68 4 q 30 24 22 66 q -8 42 -58 44 q -48 2 -58 -34 Z" fill="${fill}"/>
    <rect x="-6" y="-94" width="25" height="52" rx="12.5" fill="${fill}"/>
    <rect x="23" y="-110" width="25" height="68" rx="12.5" fill="${fill}"/>
    <rect x="52" y="-106" width="25" height="64" rx="12.5" fill="${fill}"/>
    <rect x="80" y="-84" width="23" height="46" rx="11.5" fill="${fill}"/>
    <path d="M 16 -40 q 42 14 78 -6" stroke="${P.hopGreenInk}" stroke-width="6" fill="none"
      stroke-linecap="round" opacity="0.3"/>
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
    <path d="M -8 -9 q 8 -4 12 3 q -6 6 -12 -3 Z" fill="#FFFFFF" opacity=".2"/>
    <circle cx="15" cy="14" r="4.2" fill="${tone}"/>
    <circle cx="-17" cy="11" r="3" fill="${tone}"/>
  </g>`;
}

/** The concentric ring that says "a finger goes here". Never a countdown. */
function tapHint(x, y, r, tint) {
  return `<g transform="translate(${x} ${y})" fill="none" stroke="${tint}" stroke-linecap="round">
    <circle r="${r}" stroke-width="4" opacity=".85"/>
    <circle r="${r * 1.45}" stroke-width="3" opacity=".4"/>
    <circle r="${r * 1.95}" stroke-width="2.4" opacity=".2"/>
  </g>`;
}

/** A dashed swipe path with a fingertip at the near end. */
function swipeHint(x, y, len, tint) {
  return `<g transform="translate(${x} ${y})">
    <path d="M ${-len / 2} 8 q ${len / 4} -22 ${len / 2} -4 q ${len / 4} 18 ${len / 2} -6" fill="none"
      stroke="${tint}" stroke-width="4.4" stroke-linecap="round" stroke-dasharray="2 12" opacity=".55"/>
    <circle cx="${len / 2}" cy="-2" r="12" fill="${alpha('#FFFFFF', 0.9)}"/>
    <circle cx="${len / 2}" cy="-2" r="12" fill="none" stroke="${tint}" stroke-width="3.4"/>
  </g>`;
}

/** Hop's thought bubble: the signal a child is watching for. */
function thoughtBubble(x, y, s, tint, glyph) {
  const k = s / 100;
  return `<g transform="translate(${x} ${y}) scale(${k})">
    <circle cx="-30" cy="52" r="7" fill="#FFFFFF" opacity=".95"/>
    <circle cx="-16" cy="38" r="11" fill="#FFFFFF" opacity=".95"/>
    <ellipse cx="0" cy="0" rx="50" ry="38" fill="#FFFFFF"/>
    <ellipse cx="0" cy="0" rx="50" ry="38" fill="none" stroke="${tint}" stroke-width="4" stroke-opacity=".45"/>
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

/** A swirl of water going round. Flush and Wave's whole vocabulary. */
function swirl(x, y, r, tint, o = 1) {
  return `<g transform="translate(${x} ${y})" opacity="${o}" fill="none" stroke="${tint}"
    stroke-linecap="round" stroke-width="${(r * 0.24).toFixed(1)}">
    <path d="M ${-r} 0 a ${r} ${r * 0.7} 0 1 1 ${r * 0.9} ${r * 0.66}"/>
    <path d="M ${-r * 0.5} ${r * 0.16} a ${r * 0.5} ${r * 0.36} 0 1 1 ${r * 0.46} ${r * 0.32}" opacity=".7"/>
  </g>`;
}

// ---------------------------------------------------------------------------
// Picture cards and tiles
// ---------------------------------------------------------------------------

/** Pictographs for Potty Order's four cards and Bathroom Match's tiles. */
const PICT = {
  pants: (f) => `<g fill="${f}"><path d="M -19 -22 h 38 l 5 44 h -16 l -8 -26 l -8 26 h -16 Z"/>
    <rect x="-20" y="-26" width="40" height="8" rx="4"/></g>`,
  sit: (f) => `<g><path d="M -21 -8 q 0 24 21 24 q 21 0 21 -24 Z" fill="${f}"/>
    <ellipse cx="0" cy="-9" rx="24" ry="9" fill="${f}"/>
    <ellipse cx="0" cy="-10" rx="13" ry="4.4" fill="#FFFFFF" opacity=".9"/>
    <rect x="-6" y="16" width="12" height="7" rx="3.5" fill="${f}"/></g>`,
  wipe: (f) => `<g><circle r="21" fill="${f}"/><circle r="7.6" fill="#FFFFFF"/>
    <path d="M 19 6 q 12 2 12 16 h -13 Z" fill="${f}" opacity=".7"/></g>`,
  wash: (f) => `<g fill="${f}"><circle cx="-9" cy="-6" r="10"/><circle cx="8" cy="4" r="13"/>
    <circle cx="-8" cy="12" r="6.4" opacity=".75"/></g>`,
  soap: (f) => `<g><path d="M -14 16 q -5 -32 14 -32 q 19 0 14 32 Z" fill="${f}"/>
    <rect x="-11" y="-2" width="22" height="7" rx="3.5" fill="#FFFFFF" opacity=".6"/>
    <rect x="-6" y="-25" width="12" height="11" rx="4" fill="${f}" opacity=".7"/>
    <path d="M 0 -28 h 11 q 5 0 5 5 v 4" stroke="${f}" stroke-width="5.5" fill="none" stroke-linecap="round" opacity=".7"/></g>`,
  towel: (f) => `<g><rect x="-19" y="-18" width="38" height="36" rx="9" fill="${f}"/>
    <rect x="-19" y="-4" width="38" height="7" rx="3.5" fill="#FFFFFF" opacity=".8"/>
    <rect x="-19" y="-22" width="38" height="7" rx="3.5" fill="${f}" opacity=".55"/></g>`,
};

/** One picture card from the routine: a white tile with a pictograph on it. */
function pictureCard(x, y, w, h, tint, glyph, {
  rot = 0, lifted = false, radius = 15,
} = {}) {
  return `<g transform="translate(${x} ${y}) rotate(${rot})">
    ${lifted ? `<ellipse cx="4" cy="${h / 2 + 16}" rx="${w * 0.44}" ry="7" fill="${P.midnight}" opacity=".16"/>` : ''}
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${radius}" fill="#FFFFFF"/>
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${radius}" fill="none"
      stroke="${alpha(tint, lifted ? 0.55 : 0.32)}" stroke-width="${lifted ? 3.4 : 2.6}"/>
    <g transform="translate(0 0) scale(${Math.min(w, h) / 78})">${glyph(tint)}</g>
  </g>`;
}

// ---------------------------------------------------------------------------
// Progress, never a score
// ---------------------------------------------------------------------------

/**
 * A row of marks. Filled ones are things that have happened; the rest are
 * waiting, drawn as an open outline rather than a gap, so nothing looks lost.
 */
function marks(total, done, { tint, soft, size = 34, glyph = null, restGlyph = null }) {
  return `<div style="display:flex;gap:11px;align-items:center;justify-content:center">
    ${Array.from({ length: total }, (_, i) => {
      const on = i < done;
      return `<div style="width:${size}px;height:${size}px;border-radius:${size / 2}px;display:grid;place-items:center;
        ${on ? `background:${tint};box-shadow:0 2px 6px ${alpha(tint, .3)}`
        : `background:${alpha(soft || '#FFFFFF', .9)};border:2.4px solid ${alpha(tint, .26)}`}">
        ${on ? (glyph ? glyph('#FFFFFF') : '') : (restGlyph ? restGlyph(alpha(tint, .34)) : '')}
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
 * a tummy that is "getting full" is a friendly thing, and a bar that could look
 * like it is running out would say the opposite.
 */
function tummyMeter(filled, total = 6) {
  const bead = (i) => {
    const on = i < filled;
    return `<div style="width:31px;height:26px;border-radius:13px;
      ${on ? `background:linear-gradient(180deg, ${P.peachPop}, ${P.peachDeep});box-shadow:0 2px 5px ${alpha(P.peachDeep, .28)}`
      : `background:${alpha('#FFFFFF', .8)};border:2.4px solid ${alpha(P.peachDeep, .22)}`}">
      ${on ? `<div style="height:8px;margin:4px 6px 0;border-radius:4px;background:#FFFFFF;opacity:.34"></div>` : ''}
    </div>`;
  };
  return `<div style="display:flex;align-items:center;gap:11px;padding:9px 14px;border-radius:26px;
    background:${alpha('#FFFFFF', .92)};box-shadow:0 1px 3px ${alpha(P.midnight, .08)}">
    <div style="width:34px;height:34px;border-radius:17px;background:${P.sunshineSoft};display:grid;place-items:center;flex:0 0 auto">
      <svg viewBox="0 0 24 24" width="22" height="22"><ellipse cx="12" cy="13" rx="9" ry="8.4" fill="${P.hopGreen}"/>
        <ellipse cx="12" cy="14" rx="6" ry="5.6" fill="${P.sunshineSoft}"/></svg>
    </div>
    <div style="display:flex;gap:6px">${Array.from({ length: total }, (_, i) => bead(i)).join('')}</div>
  </div>`;
}

/** The sit timer. It fills up; it never counts down and it never runs out. */
function calmRing(size, progress, { track, fill, inner = '' }) {
  const sw = 16;
  const r = (size - sw) / 2;
  const cCirc = 2 * Math.PI * r;
  return `<div style="position:relative;width:${size}px;height:${size}px">
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" style="display:block;transform:rotate(-90deg)">
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${track}" stroke-width="${sw}"/>
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke="${fill}" stroke-width="${sw}"
        stroke-linecap="round" stroke-dasharray="${cCirc.toFixed(1)}"
        stroke-dashoffset="${(cCirc * (1 - progress)).toFixed(1)}"/>
    </svg>
    <div style="position:absolute;inset:${sw}px;border-radius:50%;overflow:hidden;display:grid;place-items:end center">${inner}</div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 16–19, 20 — the routine
// ---------------------------------------------------------------------------

const STEP_DOTS = { now: P.hopGreenDeep, done: P.hopGreenDeep, todo: alpha(P.sand500, 0.32) };

/** The row every routine screen opens with: where you are, and the way out. */
function routineTopRow(index) {
  return `<div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:40px">
    <div style="flex:1"></div>
    ${stepDots(5, index, STEP_DOTS)}
    <div style="flex:1;display:flex;justify-content:flex-end">${grownUpChip('Grown-up')}</div>
  </div>`;
}

/** "Skip this", drawn as an offer rather than an escape. */
function skipRow(label) {
  return `<div style="flex:0 0 auto;height:38px;display:flex;align-items:center;justify-content:center">
    <span style="${type('parentHeadline', { color: P.sand600, weight: 'semibold' })};font-size:16px">${label}</span>
  </div>`;
}

/**
 * One step of the guided routine.
 *
 * Same chrome as the first step: dots, a grown-up chip, one large title, one
 * instruction, one primary target at `hitTarget.childPrimary`, and the labelled
 * strip along the bottom so a child can see the whole trip at once.
 */
function routineStep(appearance, {
  index, art, pose, hopWidth = 152, title, instruction, primary, skip, extra = '',
}) {
  const col = c(appearance);
  const cardW = 349;
  const cardH = Math.round((cardW * 3) / 4);
  const overhang = 58;

  return stage(ambient(art, appearance, { veil: 0.5, glow: [196, 430, 210] }), `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${routineTopRow(index)}

      <div style="flex:0 0 auto;text-align:center;margin-top:8px">
        <div style="${type('childTitle', { color: P.midnight })};font-size:36px">${title}</div>
        <div style="${type('childInstruction', { color: P.midnight })};font-size:19px;margin-top:7px;opacity:.72">${instruction}</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;position:relative;width:${cardW}px;height:${cardH + overhang}px;margin:0 auto">
        ${boardCard(appearance, { art, w: cardW })}
        ${hopAt(pose, hopWidth, `left:-14px;bottom:0`)}
      </div>
      ${extra}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, primary, { kind: 'primary', height: 100, radius: T.radius.hero })}
        ${skip ? skipRow(skip) : '<div style="height:14px"></div>'}
        ${stepStrip(index)}
      </div>
    </div>`);
}

/** 16 — Wipe. */
function routineWipe(appearance = 'light') {
  return routineStep(appearance, {
    index: 1,
    art: 'Art/scenes/routine-wipe.svg',
    pose: 'sit',
    hopWidth: 150,
    title: 'Wipe',
    instruction: 'Wipe from front to back.',
    primary: 'Next',
    skip: 'Skip this',
  });
}

/** 17 — Flush. */
function routineFlush(appearance = 'light') {
  return routineStep(appearance, {
    index: 2,
    art: 'Art/scenes/routine-flush.svg',
    pose: 'wave',
    hopWidth: 154,
    title: 'Flush',
    instruction: 'Flush it away.',
    primary: 'Next',
    skip: 'Skip this',
  });
}

/** 18 — Wash. The twenty seconds are bubbles filling, never a countdown. */
function routineWash(appearance = 'light') {
  return routineStep(appearance, {
    index: 3,
    art: 'Art/scenes/routine-wash.svg',
    pose: 'scrub',
    hopWidth: 150,
    title: 'Wash',
    instruction: 'Soap, scrub, rinse.',
    primary: 'Next',
    skip: null,
    extra: `<div style="flex:0 0 auto;margin-top:16px;display:flex;justify-content:center">
      ${marks(5, 3, {
        tint: P.pondBlueDeep,
        soft: '#FFFFFF',
        size: 32,
        glyph: (f) => MARK.droplets(f, 17),
        restGlyph: (f) => MARK.droplets(f, 17),
      })}</div>`,
  });
}

/** 19 — High five. The last step, so its button leaves the routine. */
function routineHighFive(appearance = 'light') {
  return routineStep(appearance, {
    index: 4,
    art: 'Art/scenes/routine-highFive.svg',
    pose: 'cheer',
    hopWidth: 156,
    title: 'High five',
    instruction: 'High five with Hop!',
    primary: 'All done!',
    skip: null,
  });
}

/**
 * 20 — the sit timer.
 *
 * The ring fills. There is no number in it, no ticking, and nothing happens when
 * it comes round: the caption is `routine.sitTimer.caption`, and the child
 * leaves whenever they want by tapping Next or Skip this.
 */
function routineTryTimer(appearance = 'light') {
  const col = c(appearance);
  const art = 'Art/scenes/routine-try.svg';
  const size = 268;

  return stage(ambient(art, appearance, { veil: 0.5, glow: [196, 400, 220] }), `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${routineTopRow(0)}

      <div style="flex:0 0 auto;text-align:center;margin-top:8px">
        <div style="${type('childTitle', { color: P.midnight })};font-size:36px">Try</div>
        <div style="${type('childInstruction', { color: P.midnight })};font-size:19px;margin-top:7px;opacity:.72">
          Sit down and give it a try.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        <div style="position:relative;width:${size}px;height:${size}px">
          <div style="position:absolute;inset:14px;border-radius:50%;background:${alpha('#FFFFFF', .72)}"></div>
          ${calmRing(size, 0.36, { track: alpha('#FFFFFF', 0.78), fill: P.hopGreen })}
          <div data-hop style="position:absolute;left:50%;bottom:26px;transform:translateX(-50%);width:186px;height:186px">
            ${svg('Art/character/hop-sit.svg', { width: 186 })}
          </div>
        </div>
      </div>

      <div style="flex:0 0 auto;text-align:center;margin-top:18px">
        <div style="${type('childInstruction', { color: P.sand600 })};font-size:19px">Take all the time you need.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'Next', { kind: 'primary', height: 100, radius: T.radius.hero })}
        ${skipRow('Skip this')}
        ${stepStrip(0)}
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
 * Nothing here is locked and nothing is ranked: there is no "new", no "best" and
 * no progress ring on a tile. Eight games, all available, always.
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
function thumb(key, w, h, focus) {
  const artH = Math.round((w * 3) / 4);
  const shift = Math.round((artH - h) * focus);
  return `<div style="position:relative;width:${w}px;height:${h}px;overflow:hidden;background:${P.sand100}">
    <div style="position:absolute;left:0;top:${-shift}px">
      ${artOr([`Art/scenes/games-${key}.svg`], { width: w, height: artH }, '')}
    </div>
  </div>`;
}

function gamesHub(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const H_ = ink(appearance);
  const cardW = 175.5;
  const thumbH = 80;

  const card = (g) => `
    <div style="border-radius:${T.radius.l}px;overflow:hidden;background:${col.surface};
      box-shadow:${elevation(appearance, 'resting')}">
      ${thumb(g.key, Math.ceil(cardW), thumbH, g.focus)}
      <div style="padding:8px 11px 10px">
        <div style="${type('childInstruction', { color: H_ })};font-size:14.5px;line-height:1.18;height:34px;overflow:hidden">${g.title}</div>
        <div style="${type('parentCallout', { color: col.textTertiary })};font-size:11px;line-height:1.3;
          height:29px;overflow:hidden;margin-top:2px">${g.desc}</div>
      </div>
    </div>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${col.backgroundPrimary}">
    <div style="position:absolute;left:0;top:0">
      ${scenes.dome(W, 216, dark ? alpha(P.hopGreen, 0.13) : P.hopGreenSoft)}
    </div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(H_)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 16px 6px;overflow:hidden">

        <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:56px">
          <div style="width:52px;height:52px;border-radius:26px;flex:0 0 auto;display:grid;place-items:center;
            background:${dark ? col.surfaceElevated : alpha('#FFFFFF', .86)};box-shadow:${elevation(appearance, 'resting')}">
            <svg viewBox="0 0 24 24" width="23" height="23" fill="none" stroke="${dark ? col.textSecondary : P.sand600}"
              stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>
          </div>
          <div style="flex:1;text-align:center;${type('childTitle', { color: H_ })};font-size:28px">Play</div>
          <div style="height:44px;padding:0 15px 0 11px;border-radius:22px;flex:0 0 auto;display:flex;align-items:center;gap:6px;
            background:${dark ? col.surfaceElevated : alpha('#FFFFFF', .88)}">
            ${MARK.star(P.sunshineBright, 21)}
            <span style="${type('buttonLarge', { color: dark ? P.sunshine : P.sunshineDeep })};font-size:19px">13</span>
          </div>
        </div>

        <div style="flex:0 0 auto;display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:6px">
          ${GAMES.map(card).join('')}
        </div>

        <div style="flex:1"></div>
      </div>
      ${homeIndicator(H_)}
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
  art, title, line, svgLayer = '', htmlLayer = '', tray = '', trayH = 0,
  primary = null, secondary = 'All done', secondaryTint = P.hopGreenDeep, titleSize = 32,
}) {
  const col = c(appearance);
  return stage(ambient(art, appearance, { veil: 0.52, glow: [196, 430, 230] }), `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 12px 6px;overflow:hidden">

      <div style="flex:0 0 auto;text-align:center;padding:2px 12px 0">
        <div style="${type('childTitle', { color: P.midnight })};font-size:${titleSize}px">${title}</div>
        <div style="${type('childInstruction', { color: P.midnight })};font-size:18px;margin-top:8px;opacity:.72">${line}</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        ${boardCard(appearance, { art, w: 369, svgLayer, htmlLayer, tray, trayH })}
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;padding:0 4px">
        ${primary ? childButton(col, appearance, primary, { kind: 'primary', height: 96, radius: T.radius.hero }) : ''}
        ${primary && secondary ? '<div style="height:12px"></div>' : ''}
        ${secondary ? childButton(col, appearance, secondary, {
          kind: 'secondary', height: 76, radius: 38,
          fill: '#FFFFFF', textColor: secondaryTint, fontSize: 21,
          border: `1.5px solid ${alpha(secondaryTint, .2)}`,
        }) : ''}
      </div>
    </div>`);
}

/** 22 — Potty Path. */
function gamePottyPath(appearance = 'light') {
  const f = frame(369);
  const pads = [[92, 448], [206, 390], [306, 366], [396, 344], [472, 330]];
  const done = 3;
  const layer = pads.map(([x, y], i) => {
    const tone = i < done ? mix(P.hopGreen, P.hopGreenDeep, 0.42) : mix(P.hopGreenLight, P.hopGreen, 0.3);
    return `${scenes.lilyPad(f.x(x), f.y(y), 0.62 - i * 0.05, tone)}
      ${i < done ? sparkle(f.x(x), f.y(y) - 10, 5.4, P.sunshine, 0.85) : ''}`;
  }).join('');

  return gameScreen(appearance, {
    art: 'Art/scenes/games-pottyPath.svg',
    title: 'Potty Path',
    line: 'Hop along the lily pads all the way to the potty!',
    svgLayer: layer,
    htmlLayer: hopAt('jump', 96, `left:${f.x(306) - 48}px;top:${f.y(366) - 96}px`),
    trayH: 148,
    tray: marks(5, done, {
      tint: P.hopGreenDeep,
      soft: P.hopGreenSoft,
      size: 40,
      glyph: (fc) => `<svg viewBox="0 0 40 40" width="26" height="26"><ellipse cx="20" cy="21" rx="15" ry="7.4" fill="${fc}"/>
        <path d="M20 21 L31 16.6 A15 7.4 0 0 0 27.6 15.3Z" fill="${P.hopGreenDeep}"/></svg>`,
      restGlyph: (fc) => `<svg viewBox="0 0 40 40" width="26" height="26"><ellipse cx="20" cy="21" rx="15" ry="7.4" fill="${fc}"/></svg>`,
    }),
    secondaryTint: P.hopGreenDeep,
  });
}

/** 23 — Bathroom Match. The only game with no ending of its own. */
function gameBathroomMatch(appearance = 'light') {
  const f = frame(369);
  const tile = (glyph, tint, matched) => `
    <div style="width:88px;height:74px;border-radius:${T.radius.m}px;display:grid;place-items:center;
      background:#FFFFFF;box-shadow:0 2px 8px ${alpha(P.midnight, .1)};
      border:${matched ? `3px solid ${P.hopGreenDeep}` : `2px solid ${alpha(tint, .22)}`};position:relative">
      <svg viewBox="-30 -30 60 60" width="46" height="46">${glyph(tint)}</svg>
      ${matched ? `<div style="position:absolute;right:-7px;top:-7px;width:23px;height:23px;border-radius:12px;
        background:${P.hopGreenDeep};display:grid;place-items:center">${MARK.check('#FFFFFF', 14)}</div>` : ''}
    </div>`;

  const backTile = (tint) => `
    <div style="width:88px;height:74px;border-radius:${T.radius.m}px;display:grid;place-items:center;
      background:${alpha(tint, .16)};border:2px dashed ${alpha(tint, .4)}">
      ${MARK.droplets(alpha(tint, .45), 26)}
    </div>`;

  return gameScreen(appearance, {
    art: 'Art/scenes/games-bathroomMatch.svg',
    title: 'Bathroom Match',
    line: 'Find the two that go together.',
    svgLayer: `${tapHint(f.x(300), f.y(250), 22, P.lavenderDeep)}`,
    htmlLayer: hopAt('talk', 128, `right:8px;bottom:${Math.round(f.y(480) - f.y(392)) - 6}px`),
    trayH: 184,
    tray: `<div style="display:flex;gap:9px">
        ${tile(PICT.soap, P.lavenderDeep, true)}${tile(PICT.towel, P.peachDeep, false)}${backTile(P.lavenderDeep)}
      </div>
      <div style="display:flex;gap:9px">
        ${backTile(P.pondBlueDeep)}${tile(PICT.soap, P.lavenderDeep, true)}${tile(PICT.wipe, P.pondBlueDeep, false)}
      </div>`,
    primary: 'All done',
    secondary: null,
  });
}

/** 24 — Fly Snack. */
function gameFlySnack(appearance = 'light') {
  const f = frame(369);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-flySnack.svg',
    title: 'Fly Snack',
    line: 'Hop is on his lily pad. Tap the flies for a snack!',
    svgLayer: `
      ${fly(f.x(150), f.y(150), 34, P.pondBlue, { rot: -8, trail: true })}
      ${fly(f.x(470), f.y(112), 30, P.hopGreenDeep, { rot: 10 })}
      ${fly(f.x(392), f.y(232), 27, P.sunshineBright, { rot: -14, trail: true })}
      ${tapHint(f.x(392), f.y(232), 26, P.sunshineDeep)}
      ${sparkle(f.x(250), f.y(196), 7, P.sunshine, 0.9)}`,
    htmlLayer: hopAt('catch', 148, `left:${f.x(320) - 74}px;top:${f.y(412) - 142}px`),
    trayH: 156,
    tray: `${tummyMeter(4)}${trayCaption("Yum! Hop's tummy is filling up.")}`,
    secondaryTint: P.hopGreenDeep,
  });
}

/** 25 — Mud Off. */
function gameMudOff(appearance = 'light') {
  const f = frame(369);
  const handY = f.y(410);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-mudOff.svg',
    title: 'Mud Off',
    line: 'Hop played by the pond! Swipe each patch away.',
    svgLayer: `
      ${hopHand(f.x(232), handY, 0.5, { rot: -16 })}
      ${hopHand(f.x(438), handY, 0.5, { rot: -16, flip: true })}
      ${mudPatch(f.x(268), f.y(352), 17, MUD.brown, { rot: 14 })}
      ${mudPatch(f.x(216), f.y(300), 13, MUD.green, { rot: -22 })}
      ${mudPatch(f.x(452), f.y(340), 15, MUD.brownLight, { rot: 30 })}
      <g>${sparkle(f.x(396), f.y(300), 10, P.pondBlueLight)}${sparkle(f.x(414), f.y(326), 6.4, '#FFFFFF')}
         ${sparkle(f.x(374), f.y(326), 5.2, P.sunshine, .9)}</g>
      ${swipeHint(f.x(330), f.y(392), 96, P.pondBlueDeep)}`,
    trayH: 156,
    tray: `${marks(4, 2, {
      tint: P.pondBlueDeep,
      soft: '#FFFFFF',
      size: 40,
      glyph: (fc) => `<svg viewBox="-14 -14 28 28" width="24" height="24"><path d="${sparkPath(11)}" fill="${fc}"/></svg>`,
      restGlyph: () => `<svg viewBox="-22 -22 44 44" width="24" height="24">${mudPatch(0, 0, 15, MUD.brown)}</svg>`,
    })}${trayCaption('One patch gone!')}`,
    secondaryTint: P.pondBlueDeep,
  });
}

/** 26 — Listen to Your Body. */
function gameBodySignal(appearance = 'light') {
  const f = frame(369);
  const floor = f.y(366);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-bodySignal.svg',
    title: 'Listen to Your Body',
    titleSize: 29,
    line: 'Hop is bouncing his ball. Watch for his bubble!',
    svgLayer: `
      ${ball(f.x(196), f.y(316), 26, P.peachPop, P.sunshine)}
      ${thoughtBubble(f.x(392), f.y(126), 116, P.pondBlueDeep, `<g transform="scale(0.72)">${PICT.sit(P.pondBlueDeep)}</g>`)}
      ${tapHint(f.x(392), f.y(126), 46, P.pondBlueDeep)}`,
    htmlLayer: hopAt('full', 138, `left:${f.x(300) - 69}px;top:${floor - 132}px`),
    trayH: 148,
    tray: marks(3, 1, {
      tint: P.pondBlueDeep,
      soft: '#FFFFFF',
      size: 42,
      glyph: (fc) => `<svg viewBox="-16 -16 32 32" width="26" height="26"><ellipse rx="13" ry="10" fill="${fc}"/>
        <circle cx="-11" cy="12" r="3.4" fill="${fc}"/></svg>`,
      restGlyph: (fc) => `<svg viewBox="-16 -16 32 32" width="26" height="26"><ellipse rx="13" ry="10" fill="none" stroke="${fc}" stroke-width="3"/></svg>`,
    }),
    secondaryTint: P.pondBlueDeep,
  });
}

/** 27 — Flush and Wave. One cause, one effect, as often as a child likes. */
function gameFlushWave(appearance = 'light') {
  const f = frame(369);
  return gameScreen(appearance, {
    art: 'Art/scenes/games-flushWave.svg',
    title: 'Flush and Wave',
    line: 'Tap the handle and watch the water swirl!',
    svgLayer: `
      ${tapHint(f.x(452), f.y(254), 30, P.pondBlueDeep)}
      ${swirl(f.x(452), f.y(336), 34, '#FFFFFF', 0.9)}
      ${swirl(f.x(452), f.y(336), 21, P.pondBlueSoft, 0.85)}
      ${sparkle(f.x(524), f.y(292), 8, '#FFFFFF', .9)}${sparkle(f.x(384), f.y(300), 6, '#FFFFFF', .7)}`,
    htmlLayer: hopAt('wave', 132, `left:${f.x(210) - 66}px;top:${f.y(372) - 126}px`),
    trayH: 156,
    tray: `${marks(3, 2, {
      tint: P.pondBlueDeep,
      soft: '#FFFFFF',
      size: 40,
      glyph: (fc) => `<svg viewBox="-16 -16 32 32" width="26" height="26">${swirl(0, 0, 12, fc)}</svg>`,
      restGlyph: (fc) => `<svg viewBox="-16 -16 32 32" width="26" height="26">${swirl(0, 0, 12, fc)}</svg>`,
    })}${trayCaption('Whoosh! Around it goes.')}`,
    primary: 'Again!',
    secondaryTint: P.pondBlueDeep,
  });
}

/** 28 — Potty Order. The scene already carries four dashed slots; fill two. */
function gamePottyOrder(appearance = 'light') {
  const f = frame(369);
  const slot = (i) => ({ cx: f.x(93 + i * 146), cy: f.y(220) });
  const cw = f.x(104);
  const ch = f.y(124);

  return gameScreen(appearance, {
    art: 'Art/scenes/games-pottyOrder.svg',
    title: 'Potty Order',
    line: 'Four cards, one path. Which one comes first?',
    svgLayer: `
      ${pictureCard(slot(0).cx, slot(0).cy, cw, ch, P.hopGreenDeep, PICT.pants)}
      ${pictureCard(slot(1).cx, slot(1).cy, cw, ch, P.hopGreenDeep, PICT.sit)}
      ${pictureCard(slot(2).cx, slot(2).cy - f.y(52), cw, ch, P.sunshineDeep, PICT.wipe, { rot: -6, lifted: true })}
      ${sparkle(slot(1).cx + cw * 0.5, slot(1).cy - ch * 0.44, 8, P.sunshine, .95)}`,
    trayH: 168,
    tray: `<div style="display:flex;gap:14px;align-items:center">
      ${[[PICT.wipe, P.sunshineDeep, true], [PICT.wash, P.pondBlueDeep, false]].map(([g, tint, taken]) => `
        <div style="width:74px;height:88px;border-radius:16px;display:grid;place-items:center;
          background:${taken ? alpha(P.sand100, .7) : '#FFFFFF'};
          border:${taken ? `2.6px dashed ${alpha(tint, .45)}` : `2.6px solid ${alpha(tint, .3)}`};
          ${taken ? '' : `box-shadow:0 3px 10px ${alpha(P.midnight, .12)}`}">
          <svg viewBox="-30 -30 60 60" width="44" height="44" style="${taken ? 'opacity:.32' : ''}">${g(tint)}</svg>
        </div>`).join('')}
      </div>
      ${trayCaption('That one fits!')}`,
    secondaryTint: P.hopGreenDeep,
  });
}

// ---------------------------------------------------------------------------
// 29 — the hand-off
// ---------------------------------------------------------------------------

/**
 * Fly Snack's ending, which is the lesson: Hop ate, Hop's tummy filled, and now
 * Hop needs the potty. The one game whose round finishes by walking the child
 * into the routine (`MiniGameCompletion.handOffToRoutine`), so the button is the
 * canonical shield button and there is no way to "fail" to take it.
 */
function gameFlySnackHandoff(appearance = 'light') {
  const col = c(appearance);
  const art = 'Art/scenes/games-flySnack.svg';

  return stage(ambient(art, appearance, { veil: 0.5, glow: [196, 392, 230] }), `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="height:22px"></div>

      <div style="flex:0 0 auto;text-align:center">
        <div style="${type('celebration', { color: P.midnight })};font-size:35px;line-height:1.14">
          Hop's tummy says:<br>potty time!</div>
      </div>

      <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:20px">${tummyMeter(6)}</div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;position:relative;display:flex;justify-content:center">
        <div data-hop style="width:250px;height:250px">${svg('Art/character/hop-full.svg', { width: 250 })}</div>
        <div style="position:absolute;left:8px;top:2px">${speechBubble("I need the potty!")}</div>
      </div>

      <div style="flex:0 0 auto;text-align:center;margin-top:10px">
        <div style="${type('childInstruction', { color: P.sand600 })};font-size:19px">Let's hop to the potty together.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, "Let's Go!", { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:14px"></div>
        ${childButton(col, appearance, 'All done', {
          kind: 'secondary', height: 76, radius: 38,
          fill: alpha('#FFFFFF', .8), textColor: P.sand600, fontSize: 21,
        })}
      </div>
    </div>`);
}

/** What Hop is saying, drawn the way a picture book draws it. */
function speechBubble(text) {
  return `<div style="position:relative;padding:12px 18px;border-radius:22px;background:#FFFFFF;
    box-shadow:0 3px 12px ${alpha(P.midnight, .12)};max-width:190px">
    <span style="${type('childInstruction', { color: P.midnight })};font-size:19px">${text}</span>
    <svg width="26" height="18" viewBox="0 0 26 18" style="position:absolute;left:24px;bottom:-13px;display:block">
      <path d="M2 0 C 8 12, 16 15, 25 17 C 14 15, 8 8, 4 0 Z" fill="#FFFFFF"/>
    </svg>
  </div>`;
}

module.exports = {
  routineWipe, routineFlush, routineWash, routineHighFive, routineTryTimer,
  gamesHub,
  gamePottyPath, gameBathroomMatch, gameFlySnack, gameMudOff,
  gameBodySignal, gameFlushWave, gamePottyOrder, gameFlySnackHandoff,
};
