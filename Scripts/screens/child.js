/**
 * The screens a two-to-five-year-old actually touches.
 *
 * Two modes, and the difference is deliberate:
 *
 *  - **Place** screens (the routine, the celebration, the games) are full-bleed
 *    illustrated environments. A child reads a place faster than a page.
 *  - **Ask** screens (the outcome question, the quiz) drop the environment for a
 *    calm ground and a soft dome, because a question deserves one focus and the
 *    answers have to be the brightest thing on screen.
 *
 * Rules both obey: almost no text, none of it required in order to act; primary
 * targets at `hitTarget.childPrimary`, secondaries at `childMinimum`; and no
 * option ever drawn smaller than its siblings.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOr } = require('./ui');
const { childButton, stepDots, pageDots, MARK } = require('./kit');
const scenes = require('./scenes');
const P = T.palette;

const INK = P.midnight;
/**
 * Fraction of Hop's box above the ground his feet stand on.
 *
 * Derived, not measured by eye: `hop-art.js` puts the ground line at reference
 * y 163.6 and places the reference space at `scale 2.9, offset (38.5, 22.55)`,
 * so the feet land at `(163.6 × 2.9 + 22.55) / 512`. Every grounded pose shares
 * it, because the generator sets `ankle = 146 + lift` for all of them.
 * `HopCanvas.feetFraction` computes the same value in Swift.
 */
const FEET = 0.9707;

/** A character standing in the flow, tagged so `measure.js` can find its feet. */
function hop(pose, width) {
  return `<div data-hop style="display:flex;justify-content:center">${svg(`Art/character/hop-${pose}.svg`, { width })}</div>`;
}

/** A full-bleed scene with the interface stacked over it. */
function stage(sceneHtml, body, { tint = INK } = {}) {
  return `<div style="position:relative;width:100%;height:100%;overflow:hidden">
    <div style="position:absolute;inset:0">${sceneHtml}</div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(tint)}${body}${homeIndicator(tint)}
    </div>
  </div>`;
}

/** The quiet way out of a routine screen. Never styled as an escape hatch. */
function grownUpChip(label) {
  return `<div style="height:36px;padding:0 14px;border-radius:18px;background:${alpha('#FFFFFF', .7)};
    display:flex;align-items:center;gap:6px">
    ${MARK.hand(P.sand500, 14)}
    <span style="${type('parentCallout', { color: P.sand600, weight: 'medium' })};font-size:13px">${label}</span>
  </div>`;
}

/**
 * "Skip this", drawn as an offer rather than an escape.
 *
 * The slot is the same height whether or not a step offers a skip, so the big
 * green button lands on the same pixel on all six routine screens. A child
 * tapping "Next" through the routine should not have to find the button again
 * at every step, and the strip below it is the fixed thing they navigate by.
 *
 * The drawn row is `hitTarget.parentMinimum`. The child minimum is 72pt and the
 * SwiftUI view is expected to reach it with `.hopHitTarget(.child)`, which
 * expands the frame without changing what is drawn — see `Docs/DesignReview.md`.
 */
const SKIP_H = T.hitTarget.parentMinimum;

function skipRow(label) {
  return `<div style="flex:0 0 auto;height:${SKIP_H}px;display:flex;align-items:center;justify-content:center">
    ${label ? `<span style="${type('parentHeadline', { color: P.sand600, weight: 'semibold' })}">${label}</span>` : ''}
  </div>`;
}

const STEP = {
  try: (f, s = 22) => MARK.ring(f, s),
  wipe: (f, s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><rect x="4.4" y="4.4" width="10" height="15.2" rx="5"/><path d="M14.4 19.6h5.2V9.2a4.8 4.8 0 0 0-5.2-4.8"/><circle cx="9.4" cy="9.4" r="1.6"/></svg>`,
  flush: (f, s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M19.4 12a7.4 7.4 0 1 1-2.2-5.2"/><path d="M19.8 3.6v5h-5"/><circle cx="12" cy="12" r="2.4" fill="${f}" stroke="none"/></svg>`,
  wash: (f, s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><circle cx="8.2" cy="8.6" r="3.6"/><circle cx="15.4" cy="13.4" r="4.8"/><circle cx="8" cy="17" r="2.6" opacity=".7"/></svg>`,
  five: (f, s = 22) => MARK.star(f, s),
};

const STEPS = [['Try', 'try'], ['Wipe', 'wipe'], ['Flush', 'flush'], ['Wash', 'wash'], ['High five', 'five']];

/** The labelled journey along the bottom of a routine screen. */
function stepStrip(active) {
  const cell = ([label, key], i) => {
    const done = i < active, now = i === active;
    const bg = now ? P.hopGreenDeep : done ? P.hopGreenSoft : '#FFFFFF';
    const fg = now ? '#FFFFFF' : done ? P.hopGreenDeep : P.sand500;
    return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px">
      <div style="width:44px;height:44px;border-radius:22px;background:${bg};display:grid;place-items:center;
        ${now ? `box-shadow:0 0 0 4px ${alpha(P.hopGreenDeep, .18)};` : ''}">
        ${done ? `<svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="${fg}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.6 9.8 17.4 19 7.6"/></svg>` : STEP[key](fg, 21)}
      </div>
      <div style="${type('parentFootnote', { color: P.sand600, weight: now ? 'semibold' : 'medium' })}">${label}</div>
    </div>`;
  };
  return `<div style="display:flex;align-items:flex-start;padding:13px 8px 12px;border-radius:${T.radius.xl}px;
    background:${alpha('#FFFFFF', .72)};box-shadow:0 1px 3px ${alpha(INK, .06)}">
    ${STEPS.map(cell).join('')}
  </div>`;
}

// ---------------------------------------------------------------------------
// 06 — The Potty Pause shield
// ---------------------------------------------------------------------------

/**
 * ## This screen is not ours to lay out
 *
 * `ShieldConfiguration` (ManagedSettingsUI) exposes nine properties and no
 * others: a background blur style, a background colour, **one static image**, a
 * title, a subtitle, a primary button label and its fill, and a secondary button
 * label. See `Extensions/HopPottyShieldConfiguration/…Extension.swift`.
 *
 * Fixed by iOS and drawn here as iOS draws it:
 *  - the order and spacing of icon → title → subtitle → primary → secondary;
 *  - the system font, at the system's sizes and weights — `Label` carries a
 *    `String` and a `UIColor`, so HopPotty's rounded face is unavailable here;
 *  - button shape and size, which is why the 96pt child target cannot be
 *    guaranteed on this one surface;
 *  - the secondary button, which is a tinted label with no fill of its own.
 *
 * The design problem is therefore entirely colour and words. What HopPotty does
 * with them: a warm cloud tint over the blur instead of the system's cold grey,
 * Hop as the single image, and copy that invites rather than refuses. The
 * default appearance this replaces says "limit", "blocked" and "not available".
 */
function pottyPauseShield(appearance = 'light') {
  const col = c(appearance);
  const sys = "'HopStandard',system-ui,sans-serif"; // stand-in for SF Pro

  // The paused app, blurred by the system. Abstract on purpose: HopPotty never
  // sees what is behind the shield.
  const behind = `<svg width="393" height="852" viewBox="0 0 393 852" style="display:block">
    <rect width="393" height="852" fill="${P.lavender}"/>
    <circle cx="90" cy="180" r="150" fill="${P.pondBlue}"/>
    <circle cx="330" cy="90" r="120" fill="${P.sunshineBright}"/>
    <rect x="30" y="380" width="330" height="220" rx="60" fill="${P.peachPop}"/>
    <circle cx="120" cy="700" r="130" fill="${P.hopGreen}"/>
    <circle cx="340" cy="620" r="90" fill="${P.sunshine}"/>
    <rect x="0" y="790" width="393" height="62" fill="${P.pondBlueDeep}"/>
  </svg>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${P.cloud}">
    <div style="position:absolute;inset:-60px;filter:blur(40px);opacity:.95">${behind}</div>
    <!-- backgroundBlurStyle + backgroundColor: the only two ways HopPotty warms this screen -->
    <div style="position:absolute;inset:0;background:${alpha(P.cloud, .78)}"></div>

    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;
        padding:0 46px;overflow:hidden">

        <!-- icon: one static image, centred and scaled by the system -->
        <div data-hop style="display:flex;justify-content:center">${svg('Art/character/hop-wave.svg', { width: 168 })}</div>

        <div style="text-align:center;margin-top:14px;font-family:${sys};font-size:24px;font-weight:700;
          letter-spacing:-.3px;color:${INK}">Potty time!</div>

        <div style="text-align:center;margin-top:9px;font-family:${sys};font-size:16px;font-weight:400;
          line-height:1.38;color:${P.sand600}">
          Let's hop to the potty. Your game will be here when you get back.</div>

        <div style="width:100%;margin-top:30px;height:50px;border-radius:14px;background:${col.brandAction};
          display:grid;place-items:center;font-family:${sys};font-size:17px;font-weight:600;color:${col.textOnBrand}">
          Let's Go!</div>

        <div style="width:100%;margin-top:6px;height:44px;display:grid;place-items:center;
          font-family:${sys};font-size:17px;font-weight:400;color:${INK}">Need a grown-up?</div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 07 — Routine, first step
// ---------------------------------------------------------------------------

function routineStepOne(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/routine-path.svg'], { width: 393, height: 852 },
    scenes.meadow(393, 852, { horizon: 0.482, glow: [196, 372, 164], propsOffset: 150 }));

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:40px">
        <div style="flex:1"></div>
        ${stepDots(5, 0, { now: P.hopGreenDeep, done: P.hopGreenDeep, todo: alpha(P.sand500, .32) })}
        <div style="flex:1;display:flex;justify-content:flex-end">${grownUpChip('Grown-up')}</div>
      </div>

      <div style="height:96px"></div>
      ${hop('walk', 250)}

      <div style="flex:0 0 auto;text-align:center;margin-top:22px">
        <div style="${type('childTitle', { color: INK })}">Let's hop to the potty!</div>
        <div style="${type('childInstruction', { color: INK })};font-size:19px;margin-top:9px;opacity:.72">
          Hop is coming too. Take your time.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, "I'm here!", { kind: 'primary', height: 100, radius: T.radius.hero })}
        <div style="height:${T.spacing.m}px"></div>
        ${skipRow(null)}
        ${stepStrip(0)}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 08 — The outcome question  (ask mode)
// ---------------------------------------------------------------------------

/**
 * Three answers, one shape. Identical height, identical type, identical
 * structure; only the hue changes. "I tried" is the commonest outcome of a real
 * potty visit and nothing on this screen may rank it below the other two.
 */
function routineOutcome(appearance = 'light') {
  const col = c(appearance);
  const DOME = 350;

  const choice = (label, glyph, tint, soft) => `
    <div style="height:106px;border-radius:${T.radius.xxl}px;background:${col.surface};
      display:flex;align-items:center;gap:20px;padding:0 24px;box-shadow:${elevation(appearance, 'raised')};
      border:1.5px solid ${alpha(tint, .26)}">
      <div style="width:66px;height:66px;border-radius:33px;background:${soft};display:grid;place-items:center;flex:0 0 auto">
        ${glyph(tint, 34)}
      </div>
      <span style="${type('buttonLarge', { color: INK })};font-size:28px">${label}</span>
    </div>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${col.backgroundPrimary}">
    <div style="position:absolute;left:0;top:0">${scenes.dome(393, DOME, P.hopGreenSoft)}</div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

        <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:38px">
          <div style="flex:1"></div>
          ${stepDots(5, 0, { now: P.hopGreenDeep, done: P.hopGreenDeep, todo: alpha(P.sand500, .3) })}
          <div style="flex:1;display:flex;justify-content:flex-end">${grownUpChip('Grown-up')}</div>
        </div>

        <div style="height:8px"></div>
        ${hop('wait', 170)}

        <div style="flex:0 0 auto;text-align:center;margin-top:4px">
          <div style="${type('childTitle', { color: INK })}">All done trying?</div>
        </div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:15px">
          ${choice('I peed', MARK.drop, P.pondBlueDeep, P.pondBlueSoft)}
          ${choice('I pooped', MARK.swirl, P.peachDeep, P.peachSoft)}
          ${choice('I tried', MARK.ring, P.lavenderDeep, P.lavenderSoft)}
        </div>

        <div style="flex:1"></div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 09 — Celebration
// ---------------------------------------------------------------------------

function routineComplete(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/celebration.svg'], { width: 393, height: 852 },
    scenes.meadow(393, 852, { horizon: 0.614, glow: [196, 440, 192], propsOffset: 40 }));

  const sparkle = (x, y, s, o) => `<div style="position:absolute;left:${x}px;top:${y}px;opacity:${o}">${MARK.star(P.sunshine, s)}</div>`;

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      <div style="height:34px"></div>

      <div style="flex:0 0 auto;text-align:center">
        <div style="${type('celebration', { color: INK })};font-size:38px;line-height:1.14">You listened<br>to your body!</div>
      </div>

      <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:18px">
        <div style="height:54px;padding:0 24px 0 17px;border-radius:27px;background:${P.sunshineSoft};
          display:flex;align-items:center;gap:10px;box-shadow:${elevation(appearance, 'resting')}">
          ${MARK.star(P.sunshineBright, 29)}
          <span style="${type('buttonLarge', { color: P.sunshineDeep })};font-size:23px">+1 Hop Star</span>
        </div>
      </div>

      <div style="flex:0 0 auto;text-align:center;margin-top:9px">
        <span style="${type('childInstruction', { color: P.sand600 })};font-size:18px">13 stars in your pond</span>
      </div>

      <div style="height:26px"></div>

      <div style="flex:0 0 auto;position:relative">
        ${hop('cheer', 246)}
        ${sparkle(6, 26, 24, .95)}${sparkle(300, 10, 18, .8)}${sparkle(38, 148, 14, .7)}
        ${sparkle(316, 132, 22, .85)}
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'Back to Play', { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:14px"></div>
        ${childButton(col, appearance, 'See my pond', {
          kind: 'secondary',
          fill: alpha('#FFFFFF', .76), textColor: P.sand600, fontSize: 21,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 11 — Bubble Wash
// ---------------------------------------------------------------------------

/** A soap bubble: rim, sheen and one highlight. Nothing else. */
function bubble(x, y, d, { popped = false } = {}) {
  if (popped) {
    return `<div style="position:absolute;left:${x}px;top:${y}px;width:${d}px;height:${d}px">
      <svg width="${d}" height="${d}" viewBox="0 0 100 100">
        ${[0, 60, 120, 180, 240, 300].map((a) => `<circle cx="50" cy="16" r="5" fill="${P.pondBlueLight}" opacity=".5" transform="rotate(${a} 50 50)"/>`).join('')}
      </svg></div>`;
  }
  const gid = 'bub' + Math.round(x * 7 + y * 3 + d);
  return `<div style="position:absolute;left:${x}px;top:${y}px;width:${d}px;height:${d}px">
    <svg width="${d}" height="${d}" viewBox="0 0 100 100">
      <defs><radialGradient id="${gid}" cx="0.36" cy="0.3" r="0.72">
        <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.92"/>
        <stop offset="0.55" stop-color="${P.pondBlueLight}" stop-opacity="0.34"/>
        <stop offset="1" stop-color="${P.pondBlue}" stop-opacity="0.5"/>
      </radialGradient></defs>
      <circle cx="50" cy="50" r="47" fill="url(#${gid})" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="2.6"/>
      <ellipse cx="35" cy="31" rx="15" ry="11" fill="#FFFFFF" opacity="0.8" transform="rotate(-24 35 31)"/>
      <circle cx="66" cy="66" r="5" fill="#FFFFFF" opacity="0.5"/>
    </svg></div>`;
}

/** Progress drawn as bubbles caught, not as a score. */
function caughtDots(total, caught) {
  return `<div style="display:flex;gap:10px;justify-content:center;align-items:center">
    ${Array.from({ length: total }, (_, i) => i < caught
      ? `<div style="width:16px;height:16px;border-radius:8px;background:${P.pondBlueDeep}"></div>`
      : `<div style="width:16px;height:16px;border-radius:8px;border:2px solid ${alpha(P.pondBlueDeep, .34)}"></div>`).join('')}
  </div>`;
}

function bubbleWash(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/game-bubble-wash.svg'], { width: 393, height: 852 },
    scenes.soap(393, 852, { foamY: 0.833 }));

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="flex:0 0 auto;text-align:center;padding-top:2px">
        <div style="${type('childTitle', { color: INK })};font-size:34px">Catch the bubbles!</div>
        <div style="margin-top:14px">${caughtDots(5, 3)}</div>
      </div>

      <div style="flex:1;position:relative;margin:0 -22px">
        ${bubble(24, 30, 132)}
        ${bubble(206, 4, 100)}
        ${bubble(272, 132, 108)}
        ${bubble(112, 186, 88)}
        ${bubble(96, 300, 96, { popped: true })}
        ${bubble(212, 250, 124)}
        <div data-hop style="position:absolute;left:50%;bottom:-4px;transform:translateX(-50%)">
          ${svg('Art/character/hop-jump.svg', { width: 208 })}
        </div>
      </div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'All done', {
          kind: 'secondary',
          fill: '#FFFFFF', textColor: P.pondBlueDeep, fontSize: 21,
          border: `1.5px solid ${alpha(P.pondBlueDeep, .2)}`,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 12 — Hop's question  (ask mode)
// ---------------------------------------------------------------------------

const PICTURE = {
  snack: `<svg viewBox="0 0 96 96" width="76" height="76">
    <ellipse cx="48" cy="76" rx="33" ry="8" fill="#FFFFFF"/>
    <ellipse cx="48" cy="74" rx="33" ry="8" fill="none" stroke="${P.sand200}" stroke-width="2"/>
    <path d="M48 30c-10-8-25-2-25 13 0 13 11 24 19 26 3 .8 9 .8 12 0 8-2 19-13 19-26 0-15-15-21-25-13z" fill="${P.peachDeep}"/>
    <path d="M48 30c-3-4-3-10 0-14" stroke="${P.hopGreenDeep}" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <path d="M50 20c6-5 13-4 15 0-3 5-11 6-15 0z" fill="${P.hopGreen}"/>
    <ellipse cx="37" cy="47" rx="8" ry="5.5" fill="#FFFFFF" opacity=".4" transform="rotate(-26 37 47)"/>
  </svg>`,
  wash: `<svg viewBox="0 0 96 96" width="76" height="76">
    <g transform="translate(31 62) rotate(-14)">
      <rect x="-13" y="-6" width="26" height="30" rx="11" fill="${P.hopGreen}"/>
      <circle cx="-8.5" cy="-8" r="6.4" fill="${P.hopGreen}"/><circle cx="0" cy="-11" r="6.8" fill="${P.hopGreen}"/>
      <circle cx="8.5" cy="-8" r="6.4" fill="${P.hopGreen}"/>
      <ellipse cx="0" cy="6" rx="8" ry="9" fill="${P.hopGreenLight}" opacity=".65"/>
    </g>
    <g transform="translate(65 62) rotate(14) scale(-1 1)">
      <rect x="-13" y="-6" width="26" height="30" rx="11" fill="${P.hopGreen}"/>
      <circle cx="-8.5" cy="-8" r="6.4" fill="${P.hopGreen}"/><circle cx="0" cy="-11" r="6.8" fill="${P.hopGreen}"/>
      <circle cx="8.5" cy="-8" r="6.4" fill="${P.hopGreen}"/>
      <ellipse cx="0" cy="6" rx="8" ry="9" fill="${P.hopGreenLight}" opacity=".65"/>
    </g>
    <circle cx="34" cy="28" r="12" fill="#FFFFFF" stroke="${P.pondBlue}" stroke-width="1.8" stroke-opacity=".5"/>
    <circle cx="60" cy="21" r="9" fill="#FFFFFF" stroke="${P.pondBlue}" stroke-width="1.8" stroke-opacity=".5"/>
    <circle cx="49" cy="40" r="7" fill="#FFFFFF" stroke="${P.pondBlue}" stroke-width="1.6" stroke-opacity=".5"/>
    <circle cx="73" cy="38" r="4.6" fill="#FFFFFF" stroke="${P.pondBlue}" stroke-width="1.4" stroke-opacity=".45"/>
    <circle cx="20" cy="44" r="4" fill="#FFFFFF" stroke="${P.pondBlue}" stroke-width="1.4" stroke-opacity=".45"/>
  </svg>`,
  games: `<svg viewBox="0 0 96 96" width="76" height="76">
    <rect x="10" y="30" width="76" height="42" rx="19" fill="${P.lavender}"/>
    <rect x="10" y="30" width="76" height="15" rx="7.5" fill="#FFFFFF" opacity=".2"/>
    <rect x="23" y="44" width="7.5" height="16" rx="3.7" fill="#FFFFFF"/>
    <rect x="19" y="48" width="16" height="7.5" rx="3.7" fill="#FFFFFF"/>
    <circle cx="64" cy="47" r="6" fill="#FFFFFF"/>
    <circle cx="74" cy="57" r="6" fill="#FFFFFF"/>
  </svg>`,
};

function quiz(appearance = 'light') {
  const col = c(appearance);
  const DOME = 292;

  const answer = (label, picture, hue) => `
    <div style="height:120px;border-radius:${T.radius.xxl}px;background:${col.surface};display:flex;align-items:center;
      gap:20px;padding:0 22px;box-shadow:${elevation(appearance, 'raised')};border:1.5px solid ${alpha(hue, .2)}">
      <div style="width:92px;height:92px;border-radius:26px;background:${alpha(hue, .14)};display:grid;place-items:center;flex:0 0 auto">
        ${picture}
      </div>
      <span style="${type('buttonLarge', { color: INK })};font-size:26px">${label}</span>
    </div>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${col.backgroundPrimary}">
    <div style="position:absolute;left:0;top:0">${scenes.dome(393, DOME, P.hopGreenSoft)}</div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

        <div style="flex:0 0 auto;display:flex;align-items:flex-start;gap:14px;padding-top:12px">
          <div style="width:62px;height:62px;border-radius:31px;background:#FFFFFF;overflow:hidden;flex:0 0 auto;
            display:grid;place-items:center;box-shadow:${elevation(appearance, 'resting')}">
            <div data-hop style="transform:translateY(4px)">${svg('Art/character/hop-face.svg', { width: 76 })}</div>
          </div>
          <div style="flex:1;${type('childInstruction', { color: INK })};font-size:23px;line-height:1.3;padding-top:2px">
            What do we do after using the potty?</div>
        </div>

        <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:18px">
          <div style="height:${T.hitTarget.childMinimum}px;padding:0 26px 0 20px;border-radius:36px;background:${col.surface};
            display:flex;align-items:center;gap:12px;box-shadow:${elevation(appearance, 'resting')}">
            ${MARK.speaker(P.pondBlueDeep, 26)}
            <span style="${type('parentTitle', { color: P.sand600, weight: 'semibold' })};font-size:19px">Hear it again</span>
          </div>
        </div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:15px">
          ${answer('A snack', PICTURE.snack, P.peachDeep)}
          ${answer('Wash hands', PICTURE.wash, P.pondBlueDeep)}
          ${answer('Play a game', PICTURE.games, P.lavenderDeep)}
        </div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;display:flex;justify-content:center;padding-bottom:4px">
          ${pageDots(col, 3, 1, { tint: P.hopGreenDeep })}
        </div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

module.exports = {
  pottyPauseShield, routineStepOne, routineOutcome, routineComplete, bubbleWash, quiz,
  stepStrip, grownUpChip, stage, skipRow, bubble, hop, STEP, FEET, INK,
};
