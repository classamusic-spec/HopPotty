/**
 * The screens a two-to-five-year-old actually touches.
 *
 * Rules these obey, and the reasons:
 *  - Full-bleed environments, because a child reads a place faster than a page.
 *  - Almost no text, and none of it required to act.
 *  - Primary targets at `hitTarget.childPrimary`, secondaries at `childMinimum`.
 *  - The three outcome buttons are identical in size, weight and structure, so
 *    "I tried" can never render as the consolation option.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOr } = require('./ui');
const { childButton, stepDots, pageDots, MARK } = require('./kit');
const scenes = require('./scenes');
const P = T.palette;

const INK = P.midnight;

/** A full-bleed scene with the interface stacked over it. */
function stage(sceneHtml, body, { tint = INK } = {}) {
  return `<div style="position:relative;width:100%;height:100%;overflow:hidden">
    <div style="position:absolute;inset:0">${sceneHtml}</div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(tint)}${body}${homeIndicator(tint)}
    </div>
  </div>`;
}

/** The quiet way out of any child screen. Never styled as an escape hatch. */
function grownUpChip(label) {
  return `<div style="height:38px;padding:0 15px;border-radius:19px;background:${alpha('#FFFFFF', .78)};
    display:flex;align-items:center;gap:7px;box-shadow:0 1px 3px ${alpha(INK, .08)}">
    ${MARK.hand(P.sand600, 15)}
    <span style="${type('parentCallout', { color: P.sand600, weight: 'medium' })};font-size:13.5px">${label}</span>
  </div>`;
}

const STEP = {
  try: (f, s = 22) => MARK.ring(f, s),
  wipe: (f, s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><rect x="4.4" y="4.4" width="10" height="15.2" rx="5"/><path d="M14.4 19.6h5.2V9.2a4.8 4.8 0 0 0-5.2-4.8"/><circle cx="9.4" cy="9.4" r="1.6"/></svg>`,
  flush: (f, s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M19.4 12a7.4 7.4 0 1 1-2.2-5.2"/><path d="M19.8 3.6v5h-5"/><circle cx="12" cy="12" r="2.4" fill="${f}" stroke="none"/></svg>`,
  wash: (f, s = 22) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><circle cx="8.2" cy="8.6" r="3.6"/><circle cx="15.4" cy="13.4" r="4.8"/><circle cx="8" cy="17" r="2.6" opacity=".7"/></svg>`,
  five: (f, s = 22) => MARK.star(f, s),
};

const STEPS = [
  ['Try', 'try'], ['Wipe', 'wipe'], ['Flush', 'flush'], ['Wash', 'wash'], ['High five', 'five'],
];

/** The labelled journey along the bottom of a routine screen. */
function stepStrip(active) {
  const cell = ([label, key], i) => {
    const done = i < active, now = i === active;
    const bg = now ? P.hopGreenDeep : done ? P.hopGreenSoft : alpha('#FFFFFF', .9);
    const fg = now ? '#FFFFFF' : done ? P.hopGreenDeep : P.sand300;
    return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px">
      <div style="width:44px;height:44px;border-radius:22px;background:${bg};display:grid;place-items:center;
        ${now ? `box-shadow:0 0 0 4px ${alpha(P.hopGreenDeep, .16)};` : ''}">
        ${done ? `<svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="${fg}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.6 9.8 17.4 19 7.6"/></svg>` : STEP[key](fg, 21)}
      </div>
      <div style="${type('parentFootnote', { color: now ? P.sand600 : P.sand500, weight: now ? 'semibold' : 'medium' })};font-size:11.5px">${label}</div>
    </div>`;
  };
  return `<div style="display:flex;align-items:flex-start;padding:13px 8px 12px;border-radius:${T.radius.xl}px;
    background:${alpha('#FFFFFF', .62)};box-shadow:0 1px 3px ${alpha(INK, .06)}">
    ${STEPS.map(cell).join('')}
  </div>`;
}

// ---------------------------------------------------------------------------
// 06 — Potty Pause shield
// ---------------------------------------------------------------------------

/**
 * The moment the whole product is judged on. A child's game just stopped, and
 * this screen has about one second to read as an invitation rather than a
 * punishment: a place, a friend, and the promise that the game is coming back.
 */
function pottyPauseShield(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/pause-meadow.svg', 'Art/scenes/scene-shield.svg'], { width: 393, height: 852 },
    scenes.meadow(393, 852, { horizon: 0.62, glow: [196, 470, 200] }));

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 24px 6px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        <div style="height:34px;padding:0 14px 0 5px;border-radius:17px;background:${alpha('#FFFFFF', .66)};
          display:flex;align-items:center;gap:7px">
          <div style="width:26px;height:26px;border-radius:13px;background:${P.hopGreenSoft};overflow:hidden;display:grid;place-items:center">
            <div style="transform:translateY(2px)">${svg('Art/character/hop-face.svg', { width: 32 })}</div>
          </div>
          <span style="${type('parentFootnote', { color: P.sand600, weight: 'semibold' })};font-size:12px">HopPotty</span>
        </div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center;margin-bottom:6px">
        ${svg('Art/character/hop-wave.svg', { width: 262 })}
      </div>

      <div style="flex:0 0 auto;text-align:center">
        <div style="${type('celebration', { color: INK })};font-size:44px">Potty time!</div>
        <div style="${type('childInstruction', { color: P.sand600 })};font-size:21px;margin-top:12px;line-height:1.36;padding:0 6px">
          Let's hop to the potty. Your game will be here when you get back.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, "Let's Go!", { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:14px"></div>
        ${childButton(col, appearance, 'Need a grown-up?', {
          kind: 'secondary', height: 72, radius: 36,
          fill: alpha('#FFFFFF', .72), textColor: P.sand600, fontSize: 20,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 07 — Routine, first step
// ---------------------------------------------------------------------------

function routineStepOne(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/routine-path.svg'], { width: 393, height: 852 },
    scenes.meadow(393, 852, { horizon: 0.58, glow: [196, 430, 170] }));

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:40px">
        <div style="flex:1"></div>
        ${stepDots(5, 0, { now: P.hopGreenDeep, done: P.hopGreenDeep, todo: alpha(P.sand500, .3) })}
        <div style="flex:1;display:flex;justify-content:flex-end">${grownUpChip('Grown-up')}</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        ${svg('Art/character/hop-walk.svg', { width: 244 })}
      </div>

      <div style="flex:0 0 auto;text-align:center;margin-top:6px">
        <div style="${type('childTitle', { color: INK })};font-size:36px">Let's hop to the potty!</div>
        <div style="${type('childInstruction', { color: P.sand600 })};font-size:19px;margin-top:10px">
          Hop is coming too. Take your time.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, "I'm here!", { kind: 'primary', height: 100, radius: T.radius.hero })}
        <div style="height:14px"></div>
        ${stepStrip(0)}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 08 — The outcome question
// ---------------------------------------------------------------------------

/**
 * Three answers, one shape. Identical height, identical type, identical
 * structure; only the hue changes. "I tried" is the third option and the most
 * common one, and nothing on this screen may rank it below the others.
 */
function routineOutcome(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/routine-bathroom.svg'], { width: 393, height: 852 },
    scenes.meadow(393, 852, { horizon: 0.5, glow: [196, 300, 180], dim: 0.16 }));

  const choice = (label, glyph, tint, soft) => `
    <div style="height:106px;border-radius:${T.radius.xxl}px;background:${alpha('#FFFFFF', .94)};
      display:flex;align-items:center;gap:18px;padding:0 24px;box-shadow:${elevation(appearance, 'raised')};
      border:1.5px solid ${alpha(tint, .28)}">
      <div style="width:64px;height:64px;border-radius:32px;background:${soft};display:grid;place-items:center;flex:0 0 auto">
        ${glyph(tint, 34)}
      </div>
      <span style="${type('buttonLarge', { color: INK })};font-size:28px">${label}</span>
    </div>`;

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;height:40px">
        <div style="flex:1"></div>
        ${stepDots(5, 0, { now: P.hopGreenDeep, done: P.hopGreenDeep, todo: alpha(P.sand500, .3) })}
        <div style="flex:1;display:flex;justify-content:flex-end">${grownUpChip('Grown-up')}</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;justify-content:center">
        ${svg('Art/character/hop-wait.svg', { width: 176 })}
      </div>

      <div style="flex:0 0 auto;text-align:center;margin:2px 0 20px">
        <div style="${type('childTitle', { color: INK })};font-size:36px">All done trying?</div>
      </div>

      <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:14px">
        ${choice('I peed', MARK.drop, P.pondBlueDeep, P.pondBlueSoft)}
        ${choice('I pooped', MARK.swirl, P.peachDeep, P.peachSoft)}
        ${choice('I tried', MARK.ring, P.lavenderDeep, P.lavenderSoft)}
      </div>

      <div style="flex:1"></div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 09 — Celebration
// ---------------------------------------------------------------------------

function routineComplete(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/celebration.svg'], { width: 393, height: 852 },
    scenes.meadow(393, 852, { horizon: 0.64, glow: [196, 400, 210] }));

  const sparkle = (x, y, s, o) => `<div style="position:absolute;left:${x}px;top:${y}px;opacity:${o}">${MARK.star(P.sunshine, s)}</div>`;

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 24px 6px;overflow:hidden">
      <div style="flex:1"></div>

      <div style="flex:0 0 auto;position:relative;display:flex;justify-content:center">
        ${svg('Art/character/hop-cheer.svg', { width: 252 })}
        ${sparkle(22, 34, 26, .95)}${sparkle(300, 62, 20, .85)}${sparkle(56, 152, 15, .7)}
        ${sparkle(316, 168, 24, .8)}${sparkle(146, 6, 16, .6)}
      </div>

      <div style="flex:0 0 auto;text-align:center;margin-top:2px">
        <div style="${type('celebration', { color: INK })};font-size:38px;line-height:1.14">You listened to your body!</div>
      </div>

      <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:18px">
        <div style="height:52px;padding:0 22px 0 16px;border-radius:26px;background:${P.sunshineSoft};
          display:flex;align-items:center;gap:10px;box-shadow:${elevation(appearance, 'resting')}">
          ${MARK.star(P.sunshineBright, 28)}
          <span style="${type('buttonLarge', { color: P.sunshineDeep })};font-size:22px">+1 Hop Star</span>
        </div>
      </div>

      <div style="flex:0 0 auto;text-align:center;margin-top:10px">
        <span style="${type('childInstruction', { color: P.sand600 })};font-size:18px">13 stars in your pond</span>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'Back to Play', { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:14px"></div>
        ${childButton(col, appearance, 'See my pond', {
          kind: 'secondary', height: 76, radius: 38,
          fill: alpha('#FFFFFF', .72), textColor: P.sand600, fontSize: 21,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 11 — Bubble Wash
// ---------------------------------------------------------------------------

/** A soap bubble: rim, sheen and a single highlight. Nothing else. */
function bubble(x, y, d, { popped = false } = {}) {
  if (popped) {
    return `<div style="position:absolute;left:${x}px;top:${y}px;width:${d}px;height:${d}px">
      <svg width="${d}" height="${d}" viewBox="0 0 100 100">
        ${[0, 60, 120, 180, 240, 300].map((a) => `<circle cx="50" cy="16" r="5" fill="${P.pondBlueLight}" opacity=".55" transform="rotate(${a} 50 50)"/>`).join('')}
      </svg></div>`;
  }
  const gid = 'bub' + Math.round(x + y + d);
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

function bubbleWash(appearance = 'light') {
  const col = c(appearance);
  const scene = artOr(['Art/scenes/game-bubble-wash.svg'], { width: 393, height: 852 },
    scenes.washroom(393, 852));

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="flex:0 0 auto;text-align:center;padding-top:2px">
        <div style="${type('childTitle', { color: INK })};font-size:34px">Catch the bubbles!</div>
        <div style="display:flex;justify-content:center;margin-top:14px">
          ${pageDots(col, 5, -1, {})}
        </div>
      </div>

      <div style="flex:1;position:relative;margin:0 -22px">
        ${bubble(30, 34, 128)}
        ${bubble(196, 6, 96)}
        ${bubble(268, 124, 112)}
        ${bubble(96, 176, 84)}
        ${bubble(210, 232, 136)}
        ${bubble(24, 250, 74, { popped: true })}
        <div style="position:absolute;left:50%;bottom:-18px;transform:translateX(-50%)">
          ${svg('Art/character/hop-jump.svg', { width: 214 })}
        </div>
      </div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'All done', {
          kind: 'secondary', height: 76, radius: 38,
          fill: alpha('#FFFFFF', .8), textColor: P.sand600, fontSize: 21,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 12 — Hop's question
// ---------------------------------------------------------------------------

const PICTURE = {
  snack: `<svg viewBox="0 0 96 96" width="72" height="72">
    <ellipse cx="48" cy="72" rx="34" ry="9" fill="${P.sand200}"/>
    <ellipse cx="48" cy="68" rx="30" ry="7" fill="#FFFFFF"/>
    <path d="M48 32c-10-8-24-2-24 12 0 12 10 22 18 24 3 .8 9 .8 12 0 8-2 18-12 18-24 0-14-14-20-24-12z" fill="${P.peachDeep}"/>
    <path d="M48 32c-3-4-3-9 0-13" stroke="${P.hopGreenDeep}" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M50 22c6-4 12-3 14 1-3 4-10 5-14-1z" fill="${P.hopGreen}"/>
    <ellipse cx="38" cy="46" rx="7" ry="5" fill="#FFFFFF" opacity=".38" transform="rotate(-24 38 46)"/>
  </svg>`,
  wash: `<svg viewBox="0 0 96 96" width="72" height="72">
    <rect x="18" y="18" width="12" height="26" rx="6" fill="${P.sand300}"/>
    <path d="M24 22c0-8 22-8 22 0v10" stroke="${P.sand300}" stroke-width="11" fill="none" stroke-linecap="round"/>
    <path d="M46 34v14" stroke="${P.pondBlueLight}" stroke-width="7" stroke-linecap="round"/>
    <path d="M30 74c0-12 8-20 18-20s18 8 18 20z" fill="${P.hopGreenLight}"/>
    <path d="M36 56c-4-6-2-12 4-13M60 56c4-6 2-12-4-13" stroke="${P.hopGreen}" stroke-width="5" fill="none" stroke-linecap="round"/>
    <circle cx="40" cy="50" r="7" fill="#FFFFFF" opacity=".9"/>
    <circle cx="56" cy="46" r="5.5" fill="#FFFFFF" opacity=".8"/>
    <circle cx="49" cy="58" r="4.5" fill="#FFFFFF" opacity=".75"/>
  </svg>`,
  games: `<svg viewBox="0 0 96 96" width="72" height="72">
    <rect x="12" y="32" width="72" height="40" rx="18" fill="${P.lavender}"/>
    <rect x="22" y="46" width="7" height="15" rx="3.5" fill="#FFFFFF"/>
    <rect x="18" y="50" width="15" height="7" rx="3.5" fill="#FFFFFF"/>
    <circle cx="64" cy="48" r="5.5" fill="#FFFFFF"/>
    <circle cx="73" cy="57" r="5.5" fill="#FFFFFF"/>
    <rect x="12" y="32" width="72" height="14" rx="7" fill="#FFFFFF" opacity=".18"/>
  </svg>`,
};

function quiz(appearance = 'light') {
  const col = c(appearance);
  const answer = (label, picture, hue) => `
    <div style="height:118px;border-radius:${T.radius.xxl}px;background:${col.surface};display:flex;align-items:center;
      gap:20px;padding:0 22px;box-shadow:${elevation(appearance, 'resting')};border:1.5px solid ${alpha(hue, .22)}">
      <div style="width:88px;height:88px;border-radius:24px;background:${alpha(hue, .16)};display:grid;place-items:center;flex:0 0 auto">
        ${picture}
      </div>
      <span style="${type('buttonLarge', { color: INK })};font-size:26px">${label}</span>
    </div>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${col.backgroundPrimary}">
    <div style="position:absolute;left:-70px;top:-130px;width:533px;height:340px;border-radius:0 0 50% 50%;
      background:${P.hopGreenSoft}"></div>
    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

        <div style="flex:0 0 auto;display:flex;align-items:flex-start;gap:14px;padding-top:4px">
          <div style="width:60px;height:60px;border-radius:30px;background:#FFFFFF;overflow:hidden;flex:0 0 auto;
            display:grid;place-items:center;box-shadow:${elevation(appearance, 'resting')}">
            <div style="transform:translateY(4px)">${svg('Art/character/hop-face.svg', { width: 74 })}</div>
          </div>
          <div style="flex:1;${type('childInstruction', { color: INK })};font-size:23px;line-height:1.3">
            What do we do after using the potty?</div>
        </div>

        <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:16px">
          <div style="height:56px;padding:0 22px 0 16px;border-radius:28px;background:${col.surface};
            display:flex;align-items:center;gap:10px;box-shadow:${elevation(appearance, 'resting')}">
            ${MARK.speaker(P.pondBlueDeep, 24)}
            <span style="${type('parentHeadline', { color: P.pondBlueDeep, weight: 'semibold' })};font-size:17px">Hear it again</span>
          </div>
        </div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:14px">
          ${answer('A snack', PICTURE.snack, P.peachDeep)}
          ${answer('Wash hands', PICTURE.wash, P.pondBlueDeep)}
          ${answer('Play a game', PICTURE.games, P.lavenderDeep)}
        </div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;display:flex;justify-content:center;padding-bottom:6px">
          ${pageDots(col, 3, 1, { tint: P.hopGreenDeep })}
        </div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

module.exports = {
  pottyPauseShield, routineStepOne, routineOutcome, routineComplete, bubbleWash, quiz,
  stepStrip, grownUpChip, stage, bubble, STEP,
};
