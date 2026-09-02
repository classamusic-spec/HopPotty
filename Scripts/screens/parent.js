/**
 * 01 / 14 / 15 — the parent Home screen.
 *
 * Hop's pond is the screen, not an illustration on it. The scene is the full
 * backdrop of the top of the display and Hop sits in it on his lily pad; the
 * numbers a parent opens the app for float on the water with nothing under them
 * — no card, just ink, a shaped veil and two pill controls — and everything else
 * lives on a rounded sheet that rises from below the surface.
 *
 * The pond is drawn by the same code `10-hops-pond` uses (`scenes.pond` through
 * `artOr`, with ids from `PondCatalog`), so Home and the reward screen are
 * literally the same place seen from two crops — not two drawings of a pond.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOrInline } = require('./ui');
const { tints, statusBarPad } = require('./kit');
const scenes = require('./scenes');
const pondScreen = require('./pond');

/** Rounded card container matching HopCard. */
function card(col, inner, { pad = 17, radius = T.radius.xl, elev = 'resting', bg, extra = '', appearance = 'light' } = {}) {
  return `<div style="background:${bg || col.surface};border-radius:${radius}px;padding:${pad}px;
    box-shadow:${elev === 'none' ? 'none' : elevation(appearance, elev)};${extra}">${inner}</div>`;
}

const GLYPH = {
  tried: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="${f}" stroke-width="2.2"><circle cx="12" cy="12" r="8.4"/><circle cx="12" cy="12" r="3" fill="${f}" stroke="none"/></svg>`,
  pee: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="${f}"><path d="M12 2.5c3.6 4.3 6.4 7.8 6.4 11a6.4 6.4 0 0 1-12.8 0c0-3.2 2.8-6.7 6.4-11z"/></svg>`,
  poop: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="${f}"><path d="M9.6 6.2c0-1.9 1.3-3.2 2.6-3.2 1.6 0 2.3 1.2 2 2.4 2 .1 3 1.3 2.8 2.7 2 .2 3 1.6 3 2.9 1.7.4 2.6 1.7 2.6 3.1 0 2.2-2 3.9-4.6 3.9H6c-2.6 0-4.6-1.7-4.6-3.9 0-1.5 1-2.8 2.8-3.2-.1-1.6 1-2.9 2.8-3-.2-1.4.9-2.6 2.6-2.7z"/></svg>`,
  accident: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 8v4.4"/><circle cx="12" cy="16" r="0.4" fill="${f}"/></svg>`,
  check: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="${f}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5 9.5 17.5 19.5 6.5"/></svg>`,
  star: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="${f}"><path d="M12 2.6l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.5 6.1 20.6l1.2-6.5L2.5 9.5l6.6-.9z"/></svg>`,
  chevron: (f) => `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="${f}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l7 7-7 7"/></svg>`,
};

function metricChip(col, { glyph, value, label, tint, tintSoft }) {
  return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:5px">
    <div style="width:36px;height:36px;border-radius:18px;background:${tintSoft};display:grid;place-items:center">
      ${GLYPH[glyph](tint)}
    </div>
    <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'bold' })};font-size:17.5px">${value}</div>
    <div style="${type('parentCaption', { color: col.textTertiary })};font-size:11.5px">${label}</div>
  </div>`;
}

function timelineRow(col, { time, label, glyph, tint, tintSoft, last }) {
  return `<div style="display:flex;align-items:center;gap:14px;padding:7px 0;
    ${last ? '' : `border-bottom:1px solid ${col.divider}`}">
    <div style="${type('parentCallout', { color: col.textSecondary })};width:66px;font-size:13.5px;font-variant-numeric:tabular-nums">${time}</div>
    <div style="width:28px;height:28px;border-radius:14px;background:${tintSoft};display:grid;place-items:center">${GLYPH[glyph](tint)}</div>
    <div style="${type('parentBody', { color: col.textPrimary, weight: 'medium' })};flex:1;font-size:15.5px">${label}</div>
    ${GLYPH.chevron(col.textTertiary)}
  </div>`;
}

function tabBar(col, active) {
  const tabs = [
    ['Home', `<svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M12 3.2 21 11h-2.4v8.2a1 1 0 0 1-1 1H14V15h-4v5.2H6.4a1 1 0 0 1-1-1V11H3z"/></svg>`],
    ['Progress', `<svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><rect x="3" y="12" width="4" height="8.5" rx="1.4"/><rect x="10" y="7" width="4" height="13.5" rx="1.4"/><rect x="17" y="3.5" width="4" height="17" rx="1.4"/></svg>`],
    ['Hop', null],
    ['Settings', `<svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2zm8.4 3.6c0 .5 0 1-.1 1.5l2 1.6-2 3.4-2.4-1a7.6 7.6 0 0 1-2.5 1.5l-.4 2.5h-4l-.4-2.5a7.6 7.6 0 0 1-2.5-1.5l-2.4 1-2-3.4 2-1.6a8.6 8.6 0 0 1 0-3l-2-1.6 2-3.4 2.4 1a7.6 7.6 0 0 1 2.5-1.5L10 2h4l.4 2.5a7.6 7.6 0 0 1 2.5 1.5l2.4-1 2 3.4-2 1.6c.1.5.1 1 .1 1.5z"/></svg>`],
  ];
  return `<div style="flex:0 0 auto;border-top:1px solid ${col.divider};background:${col.surface};
    display:flex;align-items:flex-start;padding:9px 8px 0;position:relative">
    ${tabs.map(([name, icon]) => {
      if (name === 'Hop') {
        return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:3px">
          <div style="width:52px;height:52px;border-radius:26px;background:${T.palette.hopGreenSoft};
            border:2.5px solid ${T.palette.hopGreen};margin-top:-16px;display:grid;place-items:center;overflow:hidden;
            box-shadow:0 4px 12px ${col.shadow}">
            <div style="transform:translateY(4px)">${svg('Art/character/hop-face.svg', { width: 58 })}</div>
          </div>
          <div style="${type('parentFootnote', { color: T.palette.hopGreenDeep, weight: 'semibold' })};font-size:10.5px">Hop</div>
        </div>`;
      }
      const on = name === active;
      const tint = on ? col.brandAction : col.textTertiary;
      return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:3px;color:${tint}">
        ${icon}<div style="${type('parentFootnote', { weight: on ? 'semibold' : 'medium' })};font-size:10.5px;color:${tint}">${name}</div>
      </div>`;
    }).join('')}
  </div>`;
}

// ---------------------------------------------------------------------------
// The pond backdrop
// ---------------------------------------------------------------------------

/**
 * Decorations Home shows, by `PondCatalog` id.
 *
 * Home is a crop of the pond, not the whole pond, and the countdown stands on the
 * near shore — so an id anchored below Hop's pad would be bought and never seen.
 * These are the ones whose anchors land in the band the countdown leaves open:
 * the clouds, the far reeds, the pads Hop needs, a lily flower, a fish, a
 * butterfly, and the two reed clumps that rise either side of the numerals.
 *
 * With the card gone this list is also a legibility decision. Every one of these
 * is either lighter than the water it sits on or anchored clear of the numerals;
 * the dark decorations — the dragonfly especially — stay above the block, which
 * is why the worst ground pixel behind the countdown is still water.
 */
const HOME_DECOR = ['cloudPuff', 'fernPatch', 'lilyPadLarge', 'lilyPadSmall', 'lilyFlower',
  'fishOrange', 'reedsLeft', 'reedsRight', 'butterflyBlue'];

/**
 * Fraction of Hop's box above the ground his feet stand on.
 *
 * Derived, not measured by eye: `hop-art.js` puts the ground line at reference
 * y 163.6 and places the reference space at `scale 2.9, offset (38.5, 22.55)`,
 * so the feet land at `(163.6 × 2.9 + 22.55) / 512`. Every grounded pose shares
 * it, because the generator sets `ankle = 146 + lift` for all of them — so this
 * one number seats sit, idle, wait and the rest on the same line.
 * `HopCanvas.feetFraction` computes the same value in Swift.
 */
const SIT_FEET = 0.9707;
/** Where the bank Hop stands on sits inside `pond-scene.svg`, as a fraction. */
const PAD_X = 0.5;
const BANK_FRACTION = 0.53;

/**
 * Geometry for a crop of the pond that keeps the drawing at its own aspect.
 *
 * The scene is authored at 393:852 with its bank 53% down. Asking for a box of
 * some other shape either letterboxes it or distorts it, so instead the box is
 * always the drawing's natural size for the width given, and the *offset* is
 * solved from the one thing the layout actually cares about: the screen row the
 * bank has to land on, because that is where Hop's feet go and where the water
 * has to start being visible below him.
 */
function pondCrop(w, bankY, height) {
  const boxH = Math.round(w * (1704 / 786));
  return { boxH, top: Math.round(bankY - boxH * BANK_FRACTION), height, bankY };
}

/**
 * The scene, drawn at `boxH` and hung at `top` so the crop lands where we want.
 *
 * The pond is a tall composition (sky → far bank → water → near shore). Home
 * only has room for its middle, so the drawing is made taller than the band and
 * pulled up: the sky thins out, the water fills the frame, and Hop's pad lands
 * clear of both the top pills and the countdown.
 */
function pondBackdrop(appearance, { w, boxH, top, height }) {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  // Inline rather than an `<img>` for the same reason `10-hops-pond` is: the
  // scene's stable ids are what the motion layer animates.
  // `slice`: Home shows a *crop* of a taller drawing, so the scene must fill the
  // band and let the rest fall outside it. Fitting instead would letterbox the
  // pond into a column with flat colour either side.
  const scene = artOrInline(['Art/pond/pond-scene.svg', 'Art/scenes/pond.svg'],
    { width: w, height: boxH, fit: 'slice' }, scenes.pond(w, boxH, HOME_DECOR));
  // The crop can start above the drawing and end below it; these are the two
  // colours its own gradients start and end on, so the seams are invisible.
  const skyTop = mix(T.palette.pondBlueSoft, T.palette.pondBlueLight, 0.34);
  const bankBottom = mix(T.palette.hopGreenLight, T.palette.hopGreen, 0.75);
  return `<div style="position:absolute;left:0;top:0;width:${w}px;height:${height}px;overflow:hidden;
    background:${skyTop}">
    <div style="position:absolute;left:0;right:0;top:${top + boxH}px;bottom:0;background:${bankBottom}"></div>
    <div style="position:absolute;left:0;top:${top}px;width:${w}px;height:${boxH}px">${scene}</div>
    ${dark ? `<div style="position:absolute;inset:0;background:linear-gradient(180deg,
        ${alpha(col.scrim, .62)} 0%, ${alpha(col.scrim, .5)} 40%, ${alpha(col.scrim, .68)} 100%)"></div>
      <div style="position:absolute;inset:0;background:radial-gradient(130% 62% at 22% 6%,
        ${alpha(T.palette.lavender, .26)} 0%, ${alpha(T.palette.lavender, 0)} 62%)"></div>` : ''}
  </div>`;
}

/** Hop, squatting on the big lily pad. Drawn after any dusk scrim, never under it. */
function hopOnPad(appearance, { w, size, bankY }) {
  const padX = w * PAD_X;
  const padY = bankY;
  return `<div data-hop style="position:absolute;left:${padX}px;top:${padY - 5 - size * SIT_FEET}px;
    width:${size}px;transform:translateX(-50%)">${svg('Art/character/hop-sit.svg', { width: size })}</div>`;
}

// ---------------------------------------------------------------------------
// Chrome that floats on the scene
// ---------------------------------------------------------------------------

/** A translucent capsule sitting on the scene. 44pt, footnote-scale type. */
function scenePill(col, appearance, inner, { pad = '0 14px', gap = 8 } = {}) {
  const dark = appearance.startsWith('dark');
  return `<div style="position:relative;height:44px;border-radius:22px;flex:0 0 auto;display:flex;align-items:center;gap:${gap}px;
    padding:${pad};background:${alpha(col.surface, dark ? .78 : .85)};
    border:1px solid ${alpha(dark ? '#FFFFFF' : col.surface, dark ? .10 : .6)};
    box-shadow:${elevation(appearance, 'resting')};backdrop-filter:blur(18px)">${inner}</div>`;
}

/** Child switcher · star count · alerts, along the top edge of the scene. */
function sceneTopBar(col, appearance, { pageX }) {
  const TINT = tints(appearance);
  const chevronDown = GLYPH.chevron(col.textTertiary).replace('M9 5l7 7-7 7', 'M6 9l6 6 6-6');
  const switcher = scenePill(col, appearance, `
    <div style="width:32px;height:32px;border-radius:16px;background:${T.palette.hopGreenSoft};
      display:grid;place-items:center;overflow:hidden;border:1.5px solid ${T.palette.hopGreenLight};flex:0 0 auto">
      <div style="transform:translateY(3px)">${svg('Art/character/hop-face.svg', { width: 40 })}</div>
    </div>
    <div style="display:flex;flex-direction:column;justify-content:center">
      <div style="${type('parentFootnote', { color: col.textTertiary })};font-size:10.5px;line-height:1.1">Good morning,</div>
      <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'bold' })};font-size:15.5px;line-height:1.2">Maya</div>
    </div>
    ${chevronDown}`, { pad: '0 10px 0 6px', gap: 8 });

  const stars = scenePill(col, appearance, `
    ${GLYPH.star(col.celebration)}
    <span style="${type('parentFootnote', { color: col.textPrimary, weight: 'bold' })};font-size:14px;
      font-variant-numeric:tabular-nums">13</span>`, { pad: '0 13px', gap: 5 });

  const bell = scenePill(col, appearance, `
    <svg viewBox="0 0 24 24" width="19" height="19" fill="${col.textSecondary}"><path d="M12 22a2.4 2.4 0 0 0 2.4-2.2H9.6A2.4 2.4 0 0 0 12 22zm7-6.4v-4.9c0-3.3-1.9-5.9-4.8-6.6v-.7a2.2 2.2 0 0 0-4.4 0v.7C6.9 4.8 5 7.4 5 10.7v4.9l-1.6 1.7v.9h17.2v-.9z"/></svg>
    <div style="position:absolute;margin:-16px 0 0 14px;width:8px;height:8px;border-radius:4px;
      background:${TINT.poop.tint};border:1.5px solid ${col.surface}"></div>`, { pad: '0 12px', gap: 0 });

  return `<div style="position:absolute;left:${pageX}px;right:${pageX}px;top:0;display:flex;align-items:center;gap:9px">
    ${switcher}<div style="flex:1"></div>${stars}${bell}
  </div>`;
}

/**
 * The countdown block, standing on the water with nothing under it.
 *
 * There is no card here on purpose. A caregiver opens this app to read one
 * number, and the number now sits on the pond itself — but a pond is not a
 * colour. It is a gradient of sky, hills and water with ripples drifting across
 * it, so the legibility the card used to guarantee has to be rebuilt out of
 * three things that are not a card:
 *
 * 1. **A veil shaped like the content, not like a box** (`heroVeil`). A soft
 *    ellipse of the ground's own light — `cloud` by day, `scrim` at dusk —
 *    inscribed in its own box so it reaches zero alpha on every side and has no
 *    edge to see. It exists to raise the *floor* of the water under the type,
 *    which is the only number WCAG cares about.
 * 2. **A tight halo on the glyphs** (`heroHalo`). Not a drop shadow — a 2px and
 *    a 12px pass in the veil's own colour, so a numeral crossing a ripple keeps
 *    its own edge.
 * 3. **Weight and size.** The countdown grew from 44 to 56 and the label went
 *    from `textSecondary` to the full ink: over a drawing, hierarchy has to come
 *    from size, not from a colour that is already spending its contrast on the
 *    ground.
 *
 * Every run of ink here is marked `data-ink`, which is not decoration: it lets a
 * checker measure each run's box, hide the ink, screenshot the ground it stood
 * on and find the *worst pixel* inside that box — the same composite-then-measure
 * order `ContrastTests` uses. Against these three renders the worst pixel gives:
 *
 * | run           | light (phone) | dark (phone) | light (iPad) |
 * | ---           | ---           | ---          | ---          |
 * | Next Potty Pause | 8.6:1      | 8.7:1        | 9.2:1        |
 * | 28:14         | 10.2:1        | 9.8:1        | 8.2:1        |
 * | Routine Mode  | 6.2:1         | 7.0:1        | 5.1:1        |
 * | Skip          | 7.1:1         | 7.5:1        | 7.1:1        |
 * | Start Now     | 5.0:1         | 10.8:1       | 5.0:1        |
 *
 * against a 4.5:1 floor for everything except the countdown, which is large text
 * at 3:1. The binding case is "Routine Mode" on iPad, where the block crosses the
 * near shore and the ink is the darkest green the palette has — 5.1:1, which is
 * the number to watch if this crop ever moves. See `Docs/Accessibility.md` §1.6.
 */
function heroVeil(appearance) {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  // Light lifts the water toward the sheet's own cloud; dusk deepens it with
  // the same scrim the pond already wears, so neither reads as a new material.
  const tone = dark ? col.scrim : T.palette.cloud;
  const core = dark ? 0.46 : 0.66;
  // The box is hung 56 above the block and 8 below it so its centre lands on the
  // numerals rather than in the middle of the block — the label, the countdown
  // and the mode line all live in the top hundred points, and the buttons below
  // carry their own fill and need none of this.
  //
  // `50% 50% at 50% 50%` is load-bearing, not decoration: an ellipse wider than
  // its own box is cut off by that box, and a gradient that is still opaque
  // where it is cut is a rectangle with a visible edge — which is exactly the
  // card this screen just removed. Inscribing the ellipse means the veil reaches
  // zero alpha on every side of its box, so there is nothing to see an edge of.
  return `<div style="position:absolute;left:-60px;right:-60px;top:-56px;bottom:-8px;pointer-events:none;
    background:radial-gradient(50% 50% at 50% 50%,
      ${alpha(tone, core)} 0%, ${alpha(tone, core * 0.88)} 30%, ${alpha(tone, core * 0.56)} 55%,
      ${alpha(tone, core * 0.2)} 78%, ${alpha(tone, 0)} 100%)"></div>`;
}

/** The glyph-level half of the same job: a tight halo in the veil's colour. */
function heroHalo(appearance) {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const tone = dark ? col.scrim : T.palette.cloud;
  return `text-shadow:0 1px 2px ${alpha(tone, dark ? .6 : .95)}, 0 0 12px ${alpha(tone, dark ? .55 : .85)};`;
}

/**
 * The two actions, drawn to survive water.
 *
 * Both are real controls with real fills — a button is a surface, which is not
 * the card the countdown lost — but they are not the same surface. Start Now is
 * the saturated brand solid at `raised`, white on deep green, and it would read
 * over anything. Skip is the one that had to change: a hairline over transparent
 * is invisible on a pond, so it becomes a frosted neutral pill — the same
 * material as the pills along the top of the scene, which is already this
 * screen's language for "a control floating on the water". Quieter than the
 * primary, never faint.
 */
function heroButton(col, appearance, label, { role }) {
  const dark = appearance.startsWith('dark');
  const H = 48;
  // Capsules, not the 14pt radius a parent button has on a card. On this screen
  // a capsule is already what "a control floating on the water" looks like —
  // the child switcher, the star count and the bell are all `scenePill` — so
  // the two actions join that family rather than looking like a form that lost
  // its form. `HopSceneActionButton` draws the same shape in the app.
  const R = H / 2;
  if (role === 'primary') {
    return `<div style="flex:1;height:${H}px;border-radius:${R}px;background:${col.brandAction};
      display:grid;place-items:center;box-shadow:${elevation(appearance, 'raised')};
      ${type('parentHeadline', { color: col.textOnBrand, weight: 'bold' })};font-size:17px">
      <span data-ink>${label}</span></div>`;
  }
  // The same fill, hairline and blur `HomeScenePill` gives the child switcher
  // and the star count at the top of this scene, and the same numbers
  // `HopSceneActionButton` uses in the app.
  return `<div style="flex:1;height:${H}px;border-radius:${R}px;
    background:${alpha(col.surface, dark ? .8 : .88)};
    border:1px solid ${alpha(col.divider, .5)};
    display:grid;place-items:center;box-shadow:${elevation(appearance, 'resting')};backdrop-filter:blur(16px);
    ${type('parentHeadline', { color: col.textSecondary, weight: 'semibold' })};font-size:17px">
    <span data-ink>${label}</span></div>`;
}

/** Label, countdown, mode and the two actions — centred, on the pond. */
function timerHero(col, appearance) {
  const dark = appearance.startsWith('dark');
  const halo = heroHalo(appearance);
  const modeInk = dark ? T.palette.hopGreenLight : T.palette.hopGreenInk;
  const modeDot = dark ? T.palette.hopGreenLight : T.palette.hopGreenDeep;
  return `<div data-hero style="position:relative">
    ${heroVeil(appearance)}
    <div style="position:relative;display:flex;flex-direction:column;align-items:center;text-align:center">
      <div data-ink style="${type('parentCaption', { color: col.textPrimary, weight: 'bold' })};text-transform:uppercase;
        letter-spacing:.9px;font-size:11.5px;${halo}">Next Potty Pause</div>
      <div data-ink style="${type('timerHero', { color: col.textPrimary })};font-size:56px;line-height:1.02;margin-top:3px;
        font-variant-numeric:tabular-nums;${halo}">28:14</div>
      <div style="display:inline-flex;align-items:center;gap:7px;margin-top:7px">
        <div style="width:8px;height:8px;border-radius:4px;background:${modeDot};
          box-shadow:0 0 0 3px ${alpha(dark ? col.scrim : T.palette.cloud, dark ? .45 : .8)}"></div>
        <span data-ink style="${type('parentFootnote', { color: modeInk, weight: 'bold' })};font-size:12.5px;${halo}">Routine Mode</span>
      </div>
      <div style="display:flex;gap:12px;margin-top:17px;align-self:stretch">
        ${heroButton(col, appearance, 'Skip', { role: 'secondary' })}
        ${heroButton(col, appearance, 'Start Now', { role: 'primary' })}
      </div>
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// Sheet content — the same three blocks, unchanged
// ---------------------------------------------------------------------------

function todayBlock(col, appearance) {
  const TINT = tints(appearance);
  return `<div>
    <div style="display:flex;align-items:baseline;justify-content:space-between;margin-bottom:6px">
      <span style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:16px">Today</span>
      <span style="${type('parentCallout', { color: col.brandAction, weight: 'semibold' })};font-size:14px">View all</span>
    </div>
    ${card(col, `<div style="display:flex">
      ${metricChip(col, { glyph: 'check', value: '6', label: 'Checks', tint: TINT.check.tint, tintSoft: TINT.check.soft })}
      ${metricChip(col, { glyph: 'tried', value: '5', label: 'Tried', tint: TINT.tried.tint, tintSoft: TINT.tried.soft })}
      ${metricChip(col, { glyph: 'pee', value: '3', label: 'Pee', tint: TINT.pee.tint, tintSoft: TINT.pee.soft })}
      ${metricChip(col, { glyph: 'poop', value: '1', label: 'Poop', tint: TINT.poop.tint, tintSoft: TINT.poop.soft })}
    </div>`, { pad: 14, appearance })}
  </div>`;
}

function routineBlock(col, appearance) {
  const TINT = tints(appearance);
  return `<div>
    <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15.5px;margin-bottom:6px">Today's routine</div>
    ${card(col, `
      ${timelineRow(col, { time: '1:42 PM', label: 'Pee', glyph: 'pee', tint: TINT.pee.tint, tintSoft: TINT.pee.soft })}
      ${timelineRow(col, { time: '12:54 PM', label: 'Tried', glyph: 'tried', tint: TINT.tried.tint, tintSoft: TINT.tried.soft })}
      ${timelineRow(col, { time: '11:58 AM', label: 'Poop', glyph: 'poop', tint: TINT.poop.tint, tintSoft: TINT.poop.soft, last: true })}
    `, { pad: 13, appearance })}
  </div>`;
}

function insightBlock(col, appearance) {
  const TINT = tints(appearance);
  return card(col, `<div style="display:flex;gap:13px;align-items:flex-start">
    <div style="width:38px;height:38px;border-radius:12px;background:${TINT.pee.soft};display:grid;place-items:center;flex:0 0 auto">
      <svg viewBox="0 0 24 24" width="20" height="20" fill="${TINT.pee.tint}"><rect x="3" y="13" width="3.6" height="7" rx="1.2"/><rect x="10.2" y="8" width="3.6" height="12" rx="1.2"/><rect x="17.4" y="4" width="3.6" height="16" rx="1.2"/></svg>
    </div>
    <div style="flex:1">
      <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15px">A pattern is forming</div>
      <div style="${type('parentCallout', { color: col.textSecondary })};font-size:13.5px;margin-top:3px">Most successful tries this week happened about 45–55 minutes apart.</div>
      <div style="display:inline-block;margin-top:8px;padding:3px 9px;border-radius:8px;background:${col.surfaceSunken};
        ${type('parentFootnote', { color: col.textTertiary, weight: 'medium' })};font-size:10.5px">Pattern, not medical advice</div>
    </div>
  </div>`, { pad: 13, appearance });
}

/** The grabber that says the sheet moves. */
function grabber(col) {
  return `<div style="display:grid;place-items:center;padding:8px 0 6px">
    <div style="width:38px;height:5px;border-radius:3px;background:${col.divider}"></div></div>`;
}

// ---------------------------------------------------------------------------
// 01 / 14 — phone
// ---------------------------------------------------------------------------

const W = 393, H = 852;
const PAGE = T.spacing.pageCompact;      // 20
const TAB_H = 50, HOME_IND = 26;
const SHEET_Y = 497;                     // the water line the sheet rises to
// No card edge to sit against any more, so the block keeps its own air above
// the sheet instead of the 14pt gap a card's shadow used to fill.
const HERO_BOTTOM = SHEET_Y - 26;
// The pond is drawn short and wide and hung 36px down: that crop puts the sky
// behind the pills, the far bank behind Hop's head, and the fish, the small pad
// and the lily flower in the strip of water the countdown leaves open.
// The bank sits just clear of the countdown, so Hop stands on it with water
// visible between his feet and the label above the numerals.
const POND = pondCrop(W, 239, SHEET_Y + 48);
const HOP_W = Math.round(W * 0.34);      // 134

function parentHome(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const sheetTop = SHEET_Y;
  const tabTop = H - HOME_IND - TAB_H;

  return `
  <div style="position:relative;width:${W}px;height:${H}px;overflow:hidden;background:${col.backgroundPrimary}">

    ${pondBackdrop(appearance, { w: W, ...POND })}
    ${hopOnPad(appearance, { w: W, size: HOP_W, bankY: POND.bankY })}

    <!-- the sheet: everything that is not the pond or the countdown -->
    <div style="position:absolute;left:0;right:0;top:${sheetTop}px;bottom:${H - tabTop}px;
      background:${col.backgroundPrimary};border-radius:${T.radius.hero}px ${T.radius.hero}px 0 0;
      box-shadow:0 -10px 30px ${alpha(col.shadow, dark ? .5 : .12)};overflow:hidden">
      ${grabber(col)}
      <div data-arrive style="display:flex;flex-direction:column;gap:11px;padding:2px ${PAGE}px 0">
        ${todayBlock(col, appearance)}
        ${routineBlock(col, appearance)}
        ${insightBlock(col, appearance)}
      </div>
      <!-- the sheet scrolls; the fade is the edge, not a cut -->
      <div style="position:absolute;left:0;right:0;bottom:0;height:36px;pointer-events:none;
        background:linear-gradient(180deg, ${alpha(col.backgroundPrimary, 0)} 0%, ${col.backgroundPrimary} 78%)"></div>
    </div>

    <!-- the countdown, floating on the water -->
    <div style="position:absolute;left:${PAGE}px;right:${PAGE}px;bottom:${H - HERO_BOTTOM}px">
      ${timerHero(col, appearance)}
    </div>

    <div style="position:absolute;left:0;right:0;top:0">${statusBar(dark ? col.textPrimary : T.palette.midnight)}</div>
    <div style="position:absolute;left:0;right:0;top:56px;height:44px">
      ${sceneTopBar(col, appearance, { pageX: PAGE })}
    </div>

    <div style="position:absolute;left:0;right:0;top:${tabTop}px;display:flex;flex-direction:column">
      ${tabBar(col, 'Home')}
      ${homeIndicator(col.textPrimary)}
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 15 — iPad
// ---------------------------------------------------------------------------

const PAD = { w: 1024, h: 768, rail: 244 };

/** The split-view sidebar the iPad build actually shows instead of a tab bar. */
function sidebar(col, appearance) {
  const rows = [
    ['Home', `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><path d="M12 3.2 21 11h-2.4v8.2a1 1 0 0 1-1 1H14V15h-4v5.2H6.4a1 1 0 0 1-1-1V11H3z"/></svg>`, true],
    ['Progress', `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><rect x="3" y="12" width="4" height="8.5" rx="1.4"/><rect x="10" y="7" width="4" height="13.5" rx="1.4"/><rect x="17" y="3.5" width="4" height="17" rx="1.4"/></svg>`, false],
    ["Hop's pond", `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><ellipse cx="12" cy="13" rx="9" ry="6"/><path d="M12 13 L21 9.4 A9 6 0 0 0 18 7.4Z" fill="${col.backgroundSecondary}"/></svg>`, false],
    ['Settings', `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2zm8.4 3.6c0 .5 0 1-.1 1.5l2 1.6-2 3.4-2.4-1a7.6 7.6 0 0 1-2.5 1.5l-.4 2.5h-4l-.4-2.5a7.6 7.6 0 0 1-2.5-1.5l-2.4 1-2-3.4 2-1.6a8.6 8.6 0 0 1 0-3l-2-1.6 2-3.4 2.4 1a7.6 7.6 0 0 1 2.5-1.5L10 2h4l.4 2.5a7.6 7.6 0 0 1 2.5 1.5l2.4-1 2 3.4-2 1.6c.1.5.1 1 .1 1.5z"/></svg>`, false],
  ];
  return `<div style="position:absolute;left:0;top:0;bottom:0;width:${PAD.rail}px;background:${col.backgroundSecondary};
    border-right:1px solid ${col.divider};display:flex;flex-direction:column">
    ${statusBarPad(col.textSecondary)}
    <div style="padding:14px 18px 10px;display:flex;align-items:center;gap:11px">
      <div style="width:38px;height:38px;border-radius:19px;background:${T.palette.hopGreenSoft};display:grid;
        place-items:center;overflow:hidden;border:2px solid ${T.palette.hopGreenLight}">
        <div style="transform:translateY(3px)">${svg('Art/character/hop-face.svg', { width: 46 })}</div>
      </div>
      <div style="${type('parentTitle', { color: col.textPrimary })};font-size:20px">HopPotty</div>
    </div>
    <div style="padding:4px 12px;display:flex;flex-direction:column;gap:2px">
      ${rows.map(([label, icon, on]) => `<div style="height:44px;border-radius:12px;display:flex;align-items:center;gap:12px;
        padding:0 12px;color:${on ? col.brandAction : col.textSecondary};
        ${on ? `background:${col.surface};box-shadow:${elevation(appearance, 'resting')};` : ''}">
        ${icon}<span style="${type('parentBody', { weight: on ? 'semibold' : 'medium' })};font-size:15.5px;color:${on ? col.textPrimary : col.textSecondary}">${label}</span>
      </div>`).join('')}
    </div>
  </div>`;
}

function parentHomePad(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const w = PAD.w - PAD.rail;              // 780
  const sheetY = 430;                      // 56% — the pond runs across the top
  const heroBottom = sheetY - 16;
  const pond = pondCrop(w, 236, sheetY + 44);
  const hopW = Math.round(w * 0.20);
  const gap = 20, gutter = 28;
  const colW = Math.round((w - gutter * 2 - gap) / 2);

  return `
  <div style="position:relative;width:${PAD.w}px;height:${PAD.h}px;overflow:hidden;background:${col.backgroundPrimary}">
    ${sidebar(col, appearance)}
    <div style="position:absolute;left:${PAD.rail}px;top:0;width:${w}px;height:${PAD.h}px;overflow:hidden">

      ${pondBackdrop(appearance, { w, ...pond })}
      ${hopOnPad(appearance, { w, size: hopW, bankY: pond.bankY })}

      <div style="position:absolute;left:0;right:0;top:${sheetY}px;bottom:0;background:${col.backgroundPrimary};
        border-radius:${T.radius.hero}px ${T.radius.hero}px 0 0;
        box-shadow:0 -10px 30px ${alpha(col.shadow, dark ? .5 : .12)};overflow:hidden">
        ${grabber(col)}
        <div data-arrive style="display:flex;gap:${gap}px;padding:4px ${gutter}px 0;align-items:flex-start">
          <div style="width:${colW}px;display:flex;flex-direction:column;gap:14px">
            ${todayBlock(col, appearance)}
            ${insightBlock(col, appearance)}
          </div>
          <div style="width:${colW}px">
            ${routineBlock(col, appearance)}
          </div>
        </div>
      </div>

      <div style="position:absolute;left:${gutter}px;width:${Math.round(w * 0.52)}px;bottom:${PAD.h - heroBottom}px">
        ${timerHero(col, appearance)}
      </div>

      <div style="position:absolute;left:0;right:0;top:22px;height:44px">
        ${sceneTopBar(col, appearance, { pageX: gutter })}
      </div>
    </div>
  </div>`;
}

module.exports = { parentHome, parentHomePad, card, GLYPH, metricChip, timelineRow, tabBar };
