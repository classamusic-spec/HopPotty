/**
 * The screens a two-to-five-year-old actually touches.
 *
 * ## The rule these are built to
 *
 * A child screen is a **place**, not a page. There is no card stack, no list, no
 * header bar and no checklist: a full-bleed illustrated world, Hop staged large
 * inside it, one sentence, and one obvious thing to touch. A child who cannot
 * read a word should be able to act on every screen here from the drawing alone.
 *
 * What that rules out, and why each one is gone:
 *
 *  - **cards** — a rounded white rectangle floating on a background is the
 *    vocabulary of an app, and it puts a frame between the child and the world
 *    they are supposed to be in. Scenes are full-bleed instead;
 *  - **progress chrome** — step dots and the named five-cell strip were two
 *    readings of the same checklist on every routine screen. A guided routine is
 *    one focused step at a time; a child who can see four steps still to come is
 *    being shown a queue;
 *  - **counters, totals and timers** — anything that reads as a score or a clock;
 *  - **second and third doors** — one primary, and at most one quiet secondary.
 *
 * The only chrome that survives is the way to a grown-up, which is a safety
 * feature and is drawn as one soft round target in the same corner every time.
 *
 * Colour, radius, type and hit targets all come from `Scripts/tokens.json`, so a
 * render can only show the design system the app compiles against.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOr } = require('./ui');
const { childButton, MARK } = require('./kit');
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

/**
 * The light that lets words sit on a drawing without a card under them.
 *
 * A card would solve the contrast problem and cost the whole idea: the moment
 * type gets a white box, the screen stops being a place and becomes a page. A
 * soft vertical wash of the page colour does the same job and leaves the scene
 * continuous underneath it.
 */
function veil(appearance, { from = 0, height = 300, strength = 0.82 } = {}) {
  const col = c(appearance);
  return `<div style="position:absolute;left:0;right:0;top:${from}px;height:${height}px;pointer-events:none;
    background:linear-gradient(180deg, ${alpha(col.backgroundPrimary, 0)} 0%, ${alpha(col.backgroundPrimary, strength * 0.5)} 42%,
      ${alpha(col.backgroundPrimary, strength)} 100%)"></div>`;
}

/**
 * The bathroom, drawn as a room rather than as a set of props.
 *
 * Deliberately almost empty: a wall, a tile line and a floor. Every routine step
 * puts something specific in front of this — the toilet, the paper, Hop sitting
 * — and a room that already contains a basin, a tap and a soap bottle turns
 * those into clutter competing with the one thing the child is meant to look at.
 */
function room(appearance, { floorY = 520, glow = null } = {}) {
  const wallTop = mix(P.pondBlueSoft, P.cloud, 0.34);
  const wallBottom = mix(P.pondBlueSoft, P.pondBlueLight, 0.16);
  const floor = mix(P.sand100, P.sand200, 0.35);
  return `<svg width="393" height="852" viewBox="0 0 393 852" style="display:block">
    <defs>
      <linearGradient id="roomWall" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${wallTop}"/><stop offset="1" stop-color="${wallBottom}"/>
      </linearGradient>
      <radialGradient id="roomGlow" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${P.cloud}" stop-opacity="0.9"/>
        <stop offset="1" stop-color="${P.cloud}" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <rect width="393" height="852" fill="url(#roomWall)"/>
    <g stroke="${P.cloud}" stroke-width="2" opacity="0.42">
      ${[186, 372].map((y) => `<path d="M 0 ${y} H 393"/>`).join('')}
      ${[98, 196, 294].map((x) => `<path d="M ${x} 0 V ${floorY}"/>`).join('')}
    </g>
    ${glow ? `<circle cx="${glow[0]}" cy="${glow[1]}" r="${glow[2]}" fill="url(#roomGlow)"/>` : ''}
    <rect x="0" y="${floorY - 12}" width="393" height="14" fill="${mix(P.sand200, P.cloud, 0.4)}"/>
    <rect x="0" y="${floorY}" width="393" height="${852 - floorY}" fill="${floor}"/>
    <g stroke="${P.sand200}" stroke-width="2" opacity="0.7">
      ${[0.3, 0.62].map((t) => `<path d="M 0 ${floorY + (852 - floorY) * t} H 393"/>`).join('')}
    </g>
  </svg>`;
}

/**
 * The way to a grown-up.
 *
 * One round target, same corner on every routine screen, drawn quietly. It is
 * the only piece of chrome a child screen keeps, and it keeps it because
 * `Docs/ChildSafety.md` requires an adult to be reachable from every child
 * surface — including when something has gone wrong, where the words a child
 * sees are "Let's ask a grown-up" and never an error.
 *
 * Drawn at 56 and framed to `hitTarget.childMinimum` in SwiftUI with
 * `.hopHitTarget(.child)`, which a render cannot show.
 */
function grownUpButton() {
  return `<div style="width:56px;height:56px;border-radius:28px;background:${alpha(P.cloud, 0.86)};
    display:grid;place-items:center;box-shadow:0 2px 8px ${alpha(INK, 0.08)}">
    ${MARK.hand(P.sand600, 26)}
  </div>`;
}

/** The top row of a routine screen: nothing but the way to a grown-up. */
function grownUpRow() {
  return `<div style="flex:0 0 auto;display:flex;justify-content:flex-end;padding:0 4px">${grownUpButton()}</div>`;
}

/**
 * "Skip this", drawn as an offer rather than an escape.
 *
 * Only on the steps the content marks skippable — plenty of visits have nothing
 * to wipe, and the flush frightens a real share of three-year-olds. It is a
 * plain word under the primary, never a button competing with it.
 */
function skipRow(label) {
  if (!label) return '';
  return `<div style="flex:0 0 auto;height:${T.hitTarget.childMinimum}px;display:flex;align-items:center;justify-content:center">
    <span style="${type('childInstruction', { color: P.sand600, weight: 'semibold' })};font-size:20px">${label}</span>
  </div>`;
}

/** Title and one line, floating on the world. Never more than two sentences. */
function words(title, line, { small = null, titleSize = null } = {}) {
  return `<div style="flex:0 0 auto;text-align:center">
    <div style="${type('childTitle', { color: INK })}${titleSize ? `;font-size:${titleSize}px` : ''}">${title}</div>
    ${line ? `<div style="${type('childInstruction', { color: INK })};margin-top:${T.spacing.s}px;opacity:.78">${line}</div>` : ''}
    ${small ? `<div style="${type('childInstruction', { color: P.sand600 })};font-size:18px;margin-top:${T.spacing.s}px">${small}</div>` : ''}
  </div>`;
}

// ---------------------------------------------------------------------------
// Props drawn here rather than in `scenes.js`
// ---------------------------------------------------------------------------

/**
 * The bathroom door at the end of the path.
 *
 * The destination has to be *visible* on the screen that asks a child to walk
 * to it, or "let's hop to the potty" is an instruction with no picture. Drawn
 * small and up the path so Hop reads as heading somewhere rather than standing
 * beside a prop.
 */
function doorway(x, groundY, s) {
  const wood = mix(P.sand300, P.peachDeep, 0.34);
  const woodDark = mix(P.sand500, P.peachDeep, 0.4);
  const roof = mix(P.hopGreen, P.hopGreenDeep, 0.45);
  return `<g transform="translate(${x} ${groundY}) scale(${s})">
    <ellipse cx="0" cy="4" rx="66" ry="10" fill="${INK}" opacity="0.08"/>
    <rect x="-52" y="-8" width="104" height="12" rx="5" fill="${mix(P.sand200, P.sand300, 0.5)}"/>
    <rect x="-44" y="-116" width="88" height="110" rx="4" fill="${wood}"/>
    <path d="M -60 -116 L 0 -168 L 60 -116 Z" fill="${roof}"/>
    <path d="M -60 -116 L 0 -168 L 0 -116 Z" fill="${P.hopGreenLight}" opacity="0.35"/>
    <rect x="-32" y="-104" width="64" height="92" rx="30" fill="${woodDark}" opacity="0.35"/>
    <rect x="-24" y="-96" width="48" height="40" rx="21" fill="${P.sunshineSoft}"/>
    <circle cx="18" cy="-52" r="5" fill="${P.sunshineBright}"/>
  </g>`;
}

/** The path that goes to the door. Drawn under Hop, so he is standing on it. */
function pathToDoor(w, h, groundY, doorX) {
  return `<path d="M ${w * 0.34} ${h} C ${w * 0.4} ${h - 130}, ${doorX - 26} ${groundY + 90}, ${doorX - 10} ${groundY + 2}
           L ${doorX + 24} ${groundY + 2} C ${doorX + 20} ${groundY + 96}, ${w * 0.66} ${h - 120}, ${w * 0.78} ${h} Z"
        fill="${mix(P.sand100, P.sand200, 0.45)}" opacity="0.92"/>`;
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
 * The design problem is therefore entirely colour, words and *one image*. So the
 * image is made to carry the screen: Hop as large as the system will draw him,
 * because he is the only thing here HopPotty controls the shape of.
 *
 * Nothing else is on this screen and nothing else may be added to it. There is
 * no counter, no star, no timer, no game list and no settings — partly because
 * `ShieldConfiguration` has nowhere to put one, and mainly because this is an
 * interruption and an interruption that decorates itself stops being brief.
 */
function pottyPauseShield(appearance = 'light') {
  const col = c(appearance);
  const sys = "'HopStandard',system-ui,sans-serif"; // stand-in for SF Pro

  // The paused app, blurred by the system. Abstract and calm on purpose:
  // HopPotty never sees what is behind the shield, and a loud guess at it makes
  // this screen look busier than iOS will actually draw it.
  const behind = `<svg width="393" height="852" viewBox="0 0 393 852" style="display:block">
    <rect width="393" height="852" fill="${P.lavenderSoft}"/>
    <circle cx="96" cy="210" r="180" fill="${P.pondBlueSoft}"/>
    <circle cx="330" cy="640" r="200" fill="${P.sunshineSoft}"/>
    <rect x="24" y="380" width="345" height="200" rx="70" fill="${P.hopGreenSoft}"/>
  </svg>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${P.cloud}">
    <div style="position:absolute;inset:-60px;filter:blur(46px);opacity:.9">${behind}</div>
    <!-- backgroundBlurStyle + backgroundColor: the only two ways HopPotty warms this screen -->
    <div style="position:absolute;inset:0;background:${alpha(P.cloud, .8)}"></div>

    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}
      <div class="fit" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;
        padding:0 40px;overflow:hidden">

        <!-- icon: one static image, centred and scaled by the system -->
        <div data-hop style="display:flex;justify-content:center">${svg('Art/character/hop-wave.svg', { width: 244 })}</div>

        <div style="text-align:center;margin-top:18px;font-family:${sys};font-size:26px;font-weight:700;
          letter-spacing:-.3px;color:${INK}">Potty time!</div>

        <div style="text-align:center;margin-top:10px;font-family:${sys};font-size:17px;font-weight:400;
          line-height:1.42;color:${P.sand600}">
          Let's hop to the potty.<br>Your game will be here when you get back.</div>

        <div style="width:100%;margin-top:32px;height:50px;border-radius:14px;background:${col.brandAction};
          display:grid;place-items:center;font-family:${sys};font-size:17px;font-weight:600;color:${col.textOnBrand}">
          Let's Go</div>

        <div style="width:100%;margin-top:8px;height:44px;display:grid;place-items:center;
          font-family:${sys};font-size:17px;font-weight:400;color:${INK}">Need a grown-up?</div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 07 — The Potty Pause, in the app: routine step one
// ---------------------------------------------------------------------------

/**
 * The pause and the first step of the routine are the same moment, so they are
 * one screen.
 *
 * A child taps "Let's Go" on the shield, the app comes forward, and this is what
 * they land on: the same words in HopPotty's own voice, in a world instead of a
 * system sheet. Hop is walking up the path toward the bathroom door — the
 * destination is drawn, because "let's hop to the potty" said to a two-year-old
 * without a picture of where is only words.
 *
 * Nothing else is on it. No step indicator, no strip of what is coming, no
 * counter and no menu — the whole screen is a place, a sentence and a door.
 */
function routineStepOne(appearance = 'light') {
  const col = c(appearance);
  const GROUND = 438;
  const DOOR_X = 330;
  const scene = `<div style="position:relative;width:393px;height:852px">
    ${scenes.meadow(393, 852, { horizon: 0.49, glow: [180, 392, 190], propsOffset: 218 })}
    <svg width="393" height="852" viewBox="0 0 393 852" style="position:absolute;left:0;top:0;display:block">
      ${pathToDoor(393, 852, GROUND, DOOR_X)}
      ${doorway(DOOR_X, GROUND, 0.56)}
    </svg>
  </div>`;

  return stage(`${scene}${veil(appearance, { from: 560, height: 292, strength: 0.62 })}`, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">

      <div style="height:88px"></div>
      ${hop('walk', 290)}

      <div style="height:${T.spacing.l}px"></div>
      ${words('Potty time!', "Let's hop to the potty.", {
        small: 'Your game will be here when you get back.',
      })}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, "Let's Go", { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:${T.spacing.m}px"></div>
        ${childButton(col, appearance, 'Need a grown-up?', {
          kind: 'secondary',
          fill: alpha(col.surface, .8), textColor: P.sand600, fontSize: 20,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 08 — "All done trying?"  (routine step three)
// ---------------------------------------------------------------------------

/**
 * Three answers, one shape.
 *
 * Identical height, identical radius, identical type, identical elevation and an
 * identical glyph diameter; the only differences are the hue, the picture and
 * the word, and each of those is a *peer* difference — three kinds of thing, not
 * three grades. `Docs/ChildSafety.md` makes that a hard rule, and "I tried" sits
 * in the first position because a child who sat down and nothing happened did
 * the entire skill this product teaches.
 *
 * The scene stays: this is still the bathroom, not a form. It is veiled towards
 * the page colour under the answers so three large targets are the brightest
 * thing on screen.
 */
function routineOutcome(appearance = 'light') {
  const col = c(appearance);

  const choice = (label, glyph, tint, soft) => `
    <div style="height:112px;border-radius:${T.radius.hero}px;background:${col.surface};
      display:flex;align-items:center;gap:22px;padding:0 26px;box-shadow:${elevation(appearance, 'raised')};
      border:2px solid ${alpha(tint, .34)}">
      <div style="width:70px;height:70px;border-radius:35px;background:${soft};display:grid;place-items:center;flex:0 0 auto">
        ${glyph(tint, 36)}
      </div>
      <span style="${type('buttonLarge', { color: INK })};font-size:30px">${label}</span>
    </div>`;

  const scene = room(appearance, { floorY: 452, glow: [196, 300, 210] });

  return stage(`${scene}${veil(appearance, { from: 372, height: 480, strength: 0.9 })}`, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${grownUpRow()}

      <div style="height:2px"></div>
      ${hop('talk', 236)}

      <div style="height:${T.spacing.m}px"></div>
      ${words('All done trying?', null)}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:14px">
        ${choice('I tried', MARK.ring, P.lavenderDeep, P.lavenderSoft)}
        ${choice('I peed', MARK.drop, P.pondBlueDeep, P.pondBlueSoft)}
        ${choice('I pooped', MARK.swirl, P.peachDeep, P.peachSoft)}
      </div>

      <div style="height:${T.spacing.s}px"></div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 09 — Celebration
// ---------------------------------------------------------------------------

/**
 * The end of a run: one sentence, one star, one way back.
 *
 * What is deliberately *not* here: the lifetime star total. A running tally on
 * the last screen of a bathroom trip is a performance metric, and this screen is
 * praise for a thing the child controls — the going and the trying — not a
 * scoreboard. The pond is where stars live, and the quiet second line offers it
 * to anyone who wants to go and look.
 */
function routineComplete(appearance = 'light') {
  const col = c(appearance);
  const scene = scenes.meadow(393, 852, { horizon: 0.6, glow: [196, 430, 200], propsOffset: 60 });

  const sparkle = (x, y, s, o) => `<div style="position:absolute;left:${x}px;top:${y}px;opacity:${o}">${MARK.star(P.sunshine, s)}</div>`;

  return stage(scene, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      <div style="height:26px"></div>

      <div style="flex:0 0 auto;text-align:center">
        <div style="${type('celebration', { color: INK })};font-size:38px;line-height:1.14">You listened<br>to your body!</div>
      </div>

      <div style="flex:0 0 auto;display:flex;justify-content:center;margin-top:16px">
        <div style="height:56px;padding:0 26px 0 18px;border-radius:28px;background:${P.sunshineSoft};
          display:flex;align-items:center;gap:10px;box-shadow:${elevation(appearance, 'resting')}">
          ${MARK.star(P.sunshineBright, 30)}
          <span style="${type('buttonLarge', { color: P.sunshineDeep })};font-size:24px">+1 Hop Star</span>
        </div>
      </div>

      <div style="height:16px"></div>

      <div style="flex:0 0 auto;position:relative">
        ${hop('cheer', 288)}
        ${sparkle(4, 30, 26, .95)}${sparkle(316, 12, 19, .8)}${sparkle(30, 168, 15, .7)}
        ${sparkle(330, 146, 23, .85)}
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${childButton(col, appearance, 'Back to Play', { kind: 'primary', height: 104, radius: T.radius.hero })}
        <div style="height:${T.spacing.m}px"></div>
        ${childButton(col, appearance, 'See my pond', {
          kind: 'secondary',
          fill: alpha(col.surface, .78), textColor: P.sand600, fontSize: 20,
        })}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 11 / 18 / 46 — Bubble Wash
// ---------------------------------------------------------------------------

/**
 * ## Bubble Wash is one experience, drawn three times
 *
 * It is the signature screen of the whole app and it is not a mini-game with a
 * board. It is a close-up: Hop's hands enlarged into the foreground over a real
 * basin, his reflection watching from the mirror, and a child rubbing across the
 * hands with a finger. Foam appears along the path the finger takes; the parts
 * that have not been rubbed stay gently visible so there is always somewhere
 * obvious to go next; and when the hands are covered the water rinses them and
 * the screen leaves by itself.
 *
 * Nothing on it counts. There is no score, no points, no timer, no combo and no
 * "play again" — the round is over when the hands are clean, which takes about
 * as long as washing hands takes.
 *
 * ### Why the hands are drawn the way they are
 *
 * Two green shapes on a green character overlap into one blob at this scale, so
 * the composition is built to keep them apart rather than relying on the drawing
 * to survive it:
 *
 *  - **they never touch** — a fixed gutter down the middle of the basin, and the
 *    wrists leave the frame at different angles;
 *  - **they are not the same green** — the near hand is the character green, the
 *    far hand is a step lighter, so the pair reads as depth rather than as one
 *    silhouette;
 *  - **each carries its own outline** — a cloud-coloured rim and a soft shadow,
 *    which is the boundary that survives foam being drawn over the top of it;
 *  - **no torso is in the same plane** — Hop's body is not on this screen at all.
 *    He is in the mirror, four hundred points away from his own hands, which is
 *    the one placement where a hand cannot overlap a chest.
 */

/**
 * Hop's hand, placed by where it *looks* like it is.
 *
 * The drawing's own path starts at the heel of the palm, which is useless for
 * composing a close-up: two hands placed by their path origins overlap before
 * anyone notices. `HAND_C` is the drawing's optical centre, so a caller says
 * "this hand's middle is here" and the gutter between the pair becomes a number
 * that can be checked rather than a thing that looked fine once.
 */
const HAND_C = { x: 51, y: -35 };
/** Half-extent of the drawing about that centre, before scaling. */
const HAND_HALF = { w: 64, h: 80 };

function hopHand(cx, cy, s, { flip = false, rot = 0, fill = P.hopGreen, rim = P.cloud } = {}) {
  const crease = mix(fill, P.hopGreenInk, 0.55);
  const inner = mix(fill, P.hopGreenInk, 0.24);
  return `<g transform="translate(${cx} ${cy}) rotate(${rot}) scale(${flip ? -s : s} ${s})
      translate(${-HAND_C.x} ${-HAND_C.y})"
    style="filter:drop-shadow(0 8px 12px ${alpha(INK, 0.22)})">
    <!-- The rim is the boundary that survives foam being drawn over the top of
         it, and it is why two green hands on a green character do not merge. -->
    <g fill="${fill}" stroke="${rim}" stroke-width="6" stroke-linejoin="round">
      <path d="M 0 0 q -10 -60 26 -80 q 38 -20 68 4 q 30 24 22 66 q -8 42 -58 44 q -48 2 -58 -34 Z"/>
      <rect x="-6" y="-94" width="25" height="52" rx="12.5"/>
      <rect x="23" y="-110" width="25" height="68" rx="12.5"/>
      <rect x="52" y="-106" width="25" height="64" rx="12.5"/>
      <rect x="80" y="-84" width="23" height="46" rx="11.5"/>
    </g>
    <!-- The palm pad is a shade deeper than the fingers, so a hand has an inside
         as well as an outline and the four fingers stay countable. -->
    <ellipse cx="52" cy="-12" rx="44" ry="38" fill="${inner}" opacity="0.16"/>
    <path d="M 16 -40 q 42 14 78 -6" stroke="${crease}" stroke-width="6" fill="none"
      stroke-linecap="round" opacity="0.4"/>
  </g>`;
}

/**
 * A patch of foam.
 *
 * Foam is the only progress readout this screen has, and it is *on the hands*,
 * in the shape of the path the finger took. A child reads how far they have got
 * by looking at the thing they are touching rather than at a meter somewhere
 * else — which is also why there is no meter somewhere else.
 */
function foam(x, y, r, o = 1) {
  const puff = (dx, dy, rr, oo) => `<circle cx="${dx}" cy="${dy}" r="${rr}" fill="${P.cloud}" opacity="${oo}"/>`;
  return `<g transform="translate(${x} ${y})" opacity="${o}">
    ${puff(0, 0, r, 0.97)}${puff(r * 0.78, r * 0.3, r * 0.72, 0.95)}${puff(-r * 0.74, r * 0.24, r * 0.66, 0.95)}
    ${puff(r * 0.3, -r * 0.62, r * 0.6, 0.93)}${puff(-r * 0.34, -r * 0.56, r * 0.54, 0.91)}
    <circle cx="${-r * 0.3}" cy="${-r * 0.3}" r="${r * 0.26}" fill="${P.pondBlueSoft}" opacity="0.75"/>
    <circle cx="${r * 0.44}" cy="${r * 0.1}" r="${r * 0.18}" fill="${P.pondBlueSoft}" opacity="0.6"/>
  </g>`;
}

/** A foam trail along a swipe: the shape of what the finger just did. */
function foamTrail(points, r) {
  return points.map(([x, y], i) => foam(x, y, r * (0.74 + 0.26 * Math.sin(i * 1.7 + 1)))).join('');
}

/**
 * A region of hand still to be washed.
 *
 * Drawn as a softly shaded lobe with a dashed edge, never as a red mark:
 * nothing here is *wrong*, it is only somewhere the child has not been yet. The
 * dash carries the meaning as well as the tone does, so the state is never held
 * by colour alone.
 */
function unwashed(x, y, r) {
  return `<g transform="translate(${x} ${y})">
    <ellipse rx="${r}" ry="${r * 0.86}" fill="${mix(P.hopGreen, P.hopGreenInk, 0.3)}" opacity="0.44"/>
    <ellipse rx="${r}" ry="${r * 0.86}" fill="none" stroke="${P.cloud}" stroke-width="3.4"
      stroke-dasharray="8 9" opacity="0.95"/>
  </g>`;
}

/** A soap bubble in the air: rim, sheen and one highlight. Nothing else. */
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
        <stop offset="0" stop-color="${P.cloud}" stop-opacity="0.92"/>
        <stop offset="0.55" stop-color="${P.pondBlueLight}" stop-opacity="0.34"/>
        <stop offset="1" stop-color="${P.pondBlue}" stop-opacity="0.5"/>
      </radialGradient></defs>
      <circle cx="50" cy="50" r="47" fill="url(#${gid})" stroke="${P.cloud}" stroke-opacity="0.85" stroke-width="2.6"/>
      <ellipse cx="35" cy="31" rx="15" ry="11" fill="${P.cloud}" opacity="0.8" transform="rotate(-24 35 31)"/>
      <circle cx="66" cy="66" r="5" fill="${P.cloud}" opacity="0.5"/>
    </svg></div>`;
}

/**
 * Hop, watching his own hands from the mirror over the sink.
 *
 * The mirror solves the composition problem this screen would otherwise have.
 * The brief asks for Hop's *hands* enlarged into the foreground **and** for Hop
 * to watch what the child is doing — and a character cannot be in both places
 * at once without his own arms crossing his own chest. In a bathroom he can: the
 * reflection is four hundred points above the hands, so there is no plane in
 * which a hand and a torso can overlap at all.
 *
 * `look` is how far down at his hands he is looking and `joy` is how much of a
 * smile he has. Both rise with coverage, which is the whole of "Hop tracks the
 * interaction".
 */
function mirror(cx, cy, r, { look = 0.5, joy = 0 } = {}) {
  const drop = 2 + look * 10;
  const id = 'mir' + Math.round(cx + cy + r);
  return `<g transform="translate(${cx} ${cy})">
    <circle cy="${r * 0.06}" r="${r + 10}" fill="${mix(P.sand200, P.cloud, 0.45)}"/>
    <circle r="${r + 2}" fill="${mix(P.pondBlueSoft, P.cloud, 0.55)}"/>
    <clipPath id="${id}"><circle r="${r}"/></clipPath>
    <g clip-path="url(#${id})">
      <foreignObject x="${-r}" y="${-r * 0.55 + drop}" width="${r * 2}" height="${r * 2}">
        <div xmlns="http://www.w3.org/1999/xhtml" style="width:${r * 2}px">
          ${svg('Art/character/hop-face.svg', { width: r * 2 })}
        </div>
      </foreignObject>
      ${joy > 0.5 ? `<g fill="${P.sunshine}" opacity="0.9">
        <path d="M ${-r * 0.62} ${-r * 0.5} q 4 10 14 14 q -10 4 -14 14 q -4 -10 -14 -14 q 10 -4 14 -14 Z"/>
      </g>` : ''}
    </g>
    <circle r="${r}" fill="none" stroke="${P.cloud}" stroke-width="7" opacity="0.95"/>
    <path d="M ${-r * 0.7} ${-r * 0.34} a ${r * 0.8} ${r * 0.8} 0 0 1 ${r * 0.46} ${-r * 0.56}"
      stroke="${P.cloud}" stroke-width="9" fill="none" stroke-linecap="round" opacity="0.5"/>
  </g>`;
}

/** The soap dispenser, and the pulse that says "press me" on the soap beat. */
function soapPump(x, y, s, { hint = false } = {}) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    ${hint ? `<g fill="none" stroke="${P.lavenderDeep}" stroke-width="4" stroke-linecap="round">
      <circle cy="-40" r="46" opacity="0.7"/><circle cy="-40" r="62" opacity="0.3"/></g>` : ''}
    <rect x="-27" y="-48" width="54" height="60" rx="18" fill="${mix(P.lavenderSoft, P.lavender, 0.5)}"/>
    <rect x="-27" y="-26" width="54" height="15" rx="7.5" fill="${P.cloud}" opacity="0.75"/>
    <rect x="-11" y="-72" width="22" height="26" rx="8" fill="${mix(P.lavender, P.lavenderDeep, 0.28)}"/>
    <path d="M 0 -76 h 20 q 8 0 8 8 v 7" stroke="${mix(P.lavender, P.lavenderDeep, 0.28)}" stroke-width="9"
      fill="none" stroke-linecap="round"/>
  </g>`;
}

/** The dashed swipe path with a fingertip on it: where a finger goes next. */
function rubHint(points) {
  const d = points.map(([x, y], i) => `${i ? 'L' : 'M'} ${x} ${y}`).join(' ');
  const [tx, ty] = points[points.length - 1];
  return `<g>
    <path d="${d}" fill="none" stroke="${P.pondBlueDeep}" stroke-width="7" stroke-linecap="round"
      stroke-dasharray="0.1 17" opacity="0.55"/>
    <circle cx="${tx}" cy="${ty}" r="19" fill="${alpha(P.cloud, 0.92)}"/>
    <circle cx="${tx}" cy="${ty}" r="19" fill="none" stroke="${P.pondBlueDeep}" stroke-width="4.5" opacity="0.8"/>
  </g>`;
}

/**
 * The basin Bubble Wash happens over.
 *
 * Drawn here rather than taken from `scenes.washroom` because this screen needs
 * the counter low and the basin wide — the hands have to sit *in* it — and
 * because the generic room's own soap bottle would be a second soap bottle.
 */
function washStand(appearance, { soapHint = false, running = true } = {}) {
  const counterY = 580;
  const basinY = 618;
  const chrome = mix(P.sand300, P.cloud, 0.45);
  const chromeDark = mix(P.sand300, P.sand500, 0.35);
  return `<div style="position:relative;width:393px;height:852px">
    ${room(appearance, { floorY: counterY, glow: [196, 320, 230] })}
    <svg width="393" height="852" viewBox="0 0 393 852" style="position:absolute;left:0;top:0;display:block">
      ${mirror(196, 236, 74, { look: 0.6 })}

      <!-- tap, behind the basin -->
      <g>
        <ellipse cx="150" cy="${counterY - 2}" rx="26" ry="8" fill="${chromeDark}" opacity="0.35"/>
        <rect x="139" y="470" width="22" height="112" rx="11" fill="${chrome}"/>
        <path d="M 150 480 C 150 434, 238 434, 238 480 L 238 508" fill="none" stroke="${chrome}"
          stroke-width="21" stroke-linecap="round"/>
        <rect x="226" y="502" width="24" height="16" rx="6" fill="${chromeDark}" opacity="0.5"/>
        ${running ? `<path d="M 238 518 v 86" stroke="${P.pondBlueLight}" stroke-width="14"
          stroke-linecap="round" opacity="0.75"/>` : ''}
      </g>

      ${soapPump(50, 578, 0.78, { hint: soapHint })}

      <!-- counter and basin -->
      <rect x="0" y="${counterY}" width="393" height="${852 - counterY}" fill="${mix(P.cloud, P.sand200, 0.32)}"/>
      <rect x="0" y="${counterY}" width="393" height="18" rx="9" fill="${P.cloud}"/>
      <ellipse cx="196" cy="${basinY}" rx="168" ry="52" fill="${mix(P.cloud, P.sand200, 0.6)}"/>
      <ellipse cx="196" cy="${basinY}" rx="152" ry="44" fill="${P.pondBlueSoft}"/>
      <ellipse cx="196" cy="${basinY + 8}" rx="132" ry="34" fill="${mix(P.pondBlue, P.pondBlueLight, 0.5)}" opacity="0.5"/>
      <ellipse cx="196" cy="${basinY}" rx="152" ry="44" fill="none" stroke="${P.cloud}" stroke-width="7"/>
      ${running ? `<ellipse cx="238" cy="${basinY + 4}" rx="34" ry="12" fill="${P.cloud}" opacity="0.5"/>` : ''}
      <path d="M 0 ${852 - 96} H 393" stroke="${P.sand200}" stroke-width="2" opacity="0.7"/>
    </svg>
  </div>`;
}

/**
 * The one composition all three Bubble Wash renders share.
 *
 * `beat` is which moment of the wash is being drawn; everything that changes
 * between the three is a consequence of it, so the three screens cannot drift
 * apart from each other or from the SwiftUI they describe.
 *
 * The hand geometry is stated as numbers rather than eyeballed, because the one
 * thing this screen cannot survive is the pair reading as a single green blob:
 * two centres 197 apart, each hand 156 wide, leaves a 41pt gutter of basin
 * between them at their closest point, and neither hand's box ever reaches the
 * other's.
 */
function bubbleWashStage(appearance, { line, beat = 'rub' } = {}) {
  const soaping = beat === 'soap';
  const clean = beat === 'clean';

  const HAND_S = 1.22;
  const LEFT = { x: 98, y: 690 };
  const RIGHT = { x: 295, y: 690 };

  const leftTrail = [[50, 726], [84, 706], [118, 722], [148, 700]];
  const rightTrail = [[244, 704], [278, 724], [312, 704], [344, 722]];

  const hands = `
    ${hopHand(LEFT.x, LEFT.y, HAND_S, { rot: -7, fill: P.hopGreen })}
    ${hopHand(RIGHT.x, RIGHT.y, HAND_S, { rot: -7, flip: true, fill: mix(P.hopGreen, P.hopGreenLight, 0.55) })}`;

  const onHands = soaping ? '' : `
    ${foamTrail(leftTrail, 23)}
    ${foamTrail(rightTrail, 22)}
    ${clean ? `${foam(78, 750, 25)}${foam(132, 746, 23)}${foam(262, 750, 24)}${foam(316, 746, 23)}
      ${foam(196, 716, 18, 0.8)}` : ''}`;

  const toDo = beat === 'rub' ? `
    ${unwashed(80, 748, 24)}
    ${unwashed(314, 742, 23)}
    ${rubHint([[74, 748], [126, 716], [184, 738], [248, 712], [312, 736]])}` : '';

  const ending = clean ? `
    <g fill="${P.sunshine}">
      <path d="M 66 586 q 5 13 18 18 q -13 5 -18 18 q -5 -13 -18 -18 q 13 -5 18 -18 Z"/>
      <path d="M 338 558 q 4 10 14 14 q -10 4 -14 14 q -4 -10 -14 -14 q 10 -4 14 -14 Z"/>
      <path d="M 196 536 q 3 8 11 11 q -8 3 -11 11 q -3 -8 -11 -11 q 8 -3 11 -11 Z"/>
    </g>
    <g fill="${P.pondBlueLight}" opacity="0.9">
      ${[[118, 572, 9], [274, 560, 8], [56, 672, 7], [346, 664, 8], [196, 596, 6]]
        .map(([dx, dy, dr]) => `<path d="M ${dx} ${dy - dr * 1.8} c ${dr} ${dr * 1.4} ${dr} ${dr * 1.4} ${dr} ${dr * 1.9}
          a ${dr} ${dr} 0 1 1 ${-dr * 2} 0 c 0 ${-dr * 0.5} 0 ${-dr * 0.5} ${dr} ${-dr * 1.9} Z"/>`).join('')}
    </g>` : '';

  const bubbles = soaping
    ? `${bubble(20, 306, 82)}${bubble(288, 348, 62)}`
    : `${bubble(16, 318, 94)}${bubble(292, 300, 72)}${bubble(238, 404, 54)}${bubble(70, 434, 48, { popped: true })}`;

  return stage(washStand(appearance, { soapHint: soaping, running: !soaping }), `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 6px;overflow:hidden">
      ${grownUpRow()}

      <div style="flex:0 0 auto;text-align:center;margin-top:4px">
        <div style="${type('childTitle', { color: INK })};font-size:32px">${line}</div>
      </div>

      <div style="flex:1"></div>
    </div>
    <div style="position:absolute;left:0;top:0;width:393px;height:852px;pointer-events:none">
      ${bubbles}
      <svg width="393" height="852" viewBox="0 0 393 852" style="position:absolute;left:0;top:0;display:block">
        ${hands}${onHands}${toDo}${ending}
      </svg>
    </div>`);
}

/** 11 — Bubble Wash, mid-rub: foam along the path, two patches still to go. */
function bubbleWash(appearance = 'light') {
  return bubbleWashStage(appearance, { line: 'Rub, rub, rub!', beat: 'rub' });
}

/** 46 — the ending: rinsed, shaken, sparkling, and about to leave by itself. */
function bubbleWashClean(appearance = 'light') {
  return bubbleWashStage(appearance, { line: 'Squeaky clean!', beat: 'clean' });
}

// ---------------------------------------------------------------------------
// 12 — Hop's question  (the quiz; its SwiftUI twin is another workstream's)
// ---------------------------------------------------------------------------

const PICTURE = {
  snack: `<svg viewBox="0 0 96 96" width="76" height="76">
    <ellipse cx="48" cy="76" rx="33" ry="8" fill="${P.cloud}"/>
    <ellipse cx="48" cy="74" rx="33" ry="8" fill="none" stroke="${P.sand200}" stroke-width="2"/>
    <path d="M48 30c-10-8-25-2-25 13 0 13 11 24 19 26 3 .8 9 .8 12 0 8-2 19-13 19-26 0-15-15-21-25-13z" fill="${P.peachDeep}"/>
    <path d="M48 30c-3-4-3-10 0-14" stroke="${P.hopGreenDeep}" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <path d="M50 20c6-5 13-4 15 0-3 5-11 6-15 0z" fill="${P.hopGreen}"/>
    <ellipse cx="37" cy="47" rx="8" ry="5.5" fill="${P.cloud}" opacity=".4" transform="rotate(-26 37 47)"/>
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
    <circle cx="34" cy="28" r="12" fill="${P.cloud}" stroke="${P.pondBlue}" stroke-width="1.8" stroke-opacity=".5"/>
    <circle cx="60" cy="21" r="9" fill="${P.cloud}" stroke="${P.pondBlue}" stroke-width="1.8" stroke-opacity=".5"/>
    <circle cx="49" cy="40" r="7" fill="${P.cloud}" stroke="${P.pondBlue}" stroke-width="1.6" stroke-opacity=".5"/>
    <circle cx="73" cy="38" r="4.6" fill="${P.cloud}" stroke="${P.pondBlue}" stroke-width="1.4" stroke-opacity=".45"/>
    <circle cx="20" cy="44" r="4" fill="${P.cloud}" stroke="${P.pondBlue}" stroke-width="1.4" stroke-opacity=".45"/>
  </svg>`,
  games: `<svg viewBox="0 0 96 96" width="76" height="76">
    <rect x="10" y="30" width="76" height="42" rx="19" fill="${P.lavender}"/>
    <rect x="10" y="30" width="76" height="15" rx="7.5" fill="${P.cloud}" opacity=".2"/>
    <rect x="23" y="44" width="7.5" height="16" rx="3.7" fill="${P.cloud}"/>
    <rect x="19" y="48" width="16" height="7.5" rx="3.7" fill="${P.cloud}"/>
    <circle cx="64" cy="47" r="6" fill="${P.cloud}"/>
    <circle cx="74" cy="57" r="6" fill="${P.cloud}"/>
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
          <div style="width:62px;height:62px;border-radius:31px;background:${col.surface};overflow:hidden;flex:0 0 auto;
            display:grid;place-items:center;box-shadow:${elevation(appearance, 'resting')}">
            <div data-hop style="width:62px;height:62px">${svg('Art/character/hop-face.svg', { width: 62 })}</div>
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
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

module.exports = {
  pottyPauseShield, routineStepOne, routineOutcome, routineComplete,
  bubbleWash, bubbleWashClean, bubbleWashStage, quiz,
  stage, room, veil, words, grownUpRow, grownUpButton, skipRow, doorway, pathToDoor,
  hopHand, foam, washStand, mirror,
  hop, bubble, FEET, INK,
};
