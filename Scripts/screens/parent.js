/**
 * 01 / 14 / 15 — the parent Home screen.
 *
 * ## Why the pond is not here any more
 *
 * This screen used to *be* Hop's pond: a full-bleed illustrated scene across the
 * top 60% of the display, Hop sitting in the middle of it, the countdown floating
 * on the water and the caregiver's data on a sheet that rose out of it. It was
 * carefully made and it was the wrong screen. Parent Mode's brief asks for a
 * first-party Apple parenting utility — Health, Screen Time, Journal, Fitness —
 * "restrained, calm, spacious, trustworthy, neutral, system-like, precise, low
 * visual noise", and it names "Hop on every parent screen" as something to
 * remove. A cartoon frog on a lily pad is the single loudest thing this app
 * could put in front of a caregiver, and it was the first thing they saw.
 *
 * So Home is now built the way iOS builds a utility: a grouped background, a
 * small number of opaque cards on it, one dominant object, and hierarchy carried
 * by spacing, type and hairlines rather than by illustration and colour.
 *
 * Hop still appears — in onboarding, in the Potty Pause preview, in the empty
 * state a family sees on day one, and in his own pond, which is one tab away.
 * He is a reward and a guide, not wallpaper.
 *
 * ## The order of the screen
 *
 * 1. A quiet identity strip: avatar, greeting, whose routine this is. Switching
 *    child is a tap on it, which is why it carries a chevron and nothing else.
 * 2. The hero — **Next Potty Pause** — and nothing competing with it.
 * 3. Today, as one compact row of four numbers. No tiles, no discs, and
 *    accidents are deliberately not among the four.
 * 4. The day's entries, in the shape Apple Health draws a timeline: a time, a
 *    small mark, a word. No red anywhere; `eventAccident` is a neutral grey.
 * 5. One observation, once.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, elevation } = require('./ui');
const { tints, statusBarPad } = require('./kit');

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/**
 * The ground a grouped parent screen stands on.
 *
 * `surfaceSunken` in both appearances, which is the one pair in the palette that
 * sits *behind* `surface` on light and on dark alike — the same relationship
 * iOS's grouped background has to a cell. Using `backgroundPrimary` instead
 * would put dark cards on a ground of exactly their own colour.
 */
const pageGround = (col) => col.surfaceSunken;

/**
 * A plain grouped card: a fill, a radius, a hairline, almost no shadow.
 *
 * §40 asks for parent depth to be "almost flat". The hairline does the work of
 * finding the edge; the shadow is only there so the card does not look printed.
 */
function card(col, inner, { pad = 16, radius = T.radius.l, elev = 'resting', bg, extra = '', appearance = 'light' } = {}) {
  return `<div style="background:${bg || col.surface};border-radius:${radius}px;padding:${pad}px;
    border:0.5px solid ${col.divider};
    box-shadow:${elev === 'none' ? 'none' : elevation(appearance, elev)};${extra}">${inner}</div>`;
}

/** A section heading, in the shape Apple Health puts above a group. */
function sectionHeader(col, title, { action } = {}) {
  return `<div style="display:flex;align-items:baseline;justify-content:space-between;padding:0 4px 7px">
    <span style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:17px">${title}</span>
    ${action ? `<span style="${type('parentCallout', { color: col.brandAction })};font-size:15px">${action}</span>` : ''}
  </div>`;
}

// ---------------------------------------------------------------------------
// Marks
// ---------------------------------------------------------------------------

/**
 * The marks this screen draws by hand, and the ones it must not.
 *
 * §37: SF Symbols carry parent chrome — chevron, bell, gear, chart, timer,
 * profile — and custom vector art is reserved for Hop, the pond, the routine,
 * games, quizzes and rewards. The four *event* marks stay bespoke for the reason
 * `HopGlyph.swift` gives: the system set has nothing that means "tried", and a
 * symbol that is nearly right is worse than one that is obviously ours. Each is
 * drawn here at the weight and size an SF Symbol would be, so the timeline reads
 * as one family.
 *
 * `chevron`, `chart` and the four tab marks below are the SF Symbols
 * `chevron.right`, `chart.bar.fill`, `house.fill`, `chart.bar.fill`,
 * `drop.circle.fill` and `gearshape.fill`, traced at their system proportions —
 * the harness has no symbol font, the app calls `Image(systemName:)`.
 */
const GLYPH = {
  tried: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.2"><circle cx="12" cy="12" r="8.4"/><circle cx="12" cy="12" r="3" fill="${f}" stroke="none"/></svg>`,
  pee: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 2.5c3.6 4.3 6.4 7.8 6.4 11a6.4 6.4 0 0 1-12.8 0c0-3.2 2.8-6.7 6.4-11z"/></svg>`,
  poop: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M9.6 6.2c0-1.9 1.3-3.2 2.6-3.2 1.6 0 2.3 1.2 2 2.4 2 .1 3 1.3 2.8 2.7 2 .2 3 1.6 3 2.9 1.7.4 2.6 1.7 2.6 3.1 0 2.2-2 3.9-4.6 3.9H6c-2.6 0-4.6-1.7-4.6-3.9 0-1.5 1-2.8 2.8-3.2-.1-1.6 1-2.9 2.8-3-.2-1.4.9-2.6 2.6-2.7z"/></svg>`,
  accident: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 8v4.4"/><circle cx="12" cy="16" r="0.4" fill="${f}"/></svg>`,
  check: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12.5 9.5 17.5 19.5 6.5"/></svg>`,
  star: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 2.6l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.5 6.1 20.6l1.2-6.5L2.5 9.5l6.6-.9z"/></svg>`,
  chevron: (f, s = 14) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l7 7-7 7"/></svg>`,
  chevronDown: (f, s = 14) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l7 7 7-7"/></svg>`,
  chart: (f, s = 17) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><rect x="3" y="12" width="4" height="8.5" rx="1.4"/><rect x="10" y="7" width="4" height="13.5" rx="1.4"/><rect x="17" y="3.5" width="4" height="17" rx="1.4"/></svg>`,
};

/**
 * One of the four numbers in the Today row.
 *
 * Was a 36pt tinted disc with a glyph in it, stacked over the value and the
 * label — four of those side by side is exactly the "giant colourful tiles" the
 * brief rules out, and it spent the screen's whole colour budget above the fold.
 * Now it is a number and a word, separated from its neighbours by a hairline,
 * the way Fitness and Screen Time draw a summary row. The event tint survives as
 * a 13pt mark beside the label, small enough to be an identifier rather than a
 * decoration, and it is what keeps the four distinguishable without colour.
 */
function metricChip(col, { glyph, value, label, tint }) {
  return `<div style="flex:1;min-width:0;display:flex;flex-direction:column;align-items:flex-start;gap:3px;padding:0 12px">
    <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'bold' })};font-size:22px;
      font-variant-numeric:tabular-nums;line-height:1.15">${value}</div>
    <div style="display:flex;align-items:center;gap:5px">
      ${GLYPH[glyph](tint, 13)}
      <span style="${type('parentCaption', { color: col.textSecondary })};font-size:13px">${label}</span>
    </div>
  </div>`;
}

/**
 * One entry in the day's timeline.
 *
 * The tinted 28pt disc behind each mark is gone. Health draws a row as a time, a
 * small tinted symbol and a word; the disc was a third object per row and, four
 * rows down, four more coloured circles. The rows also lost their per-row
 * chevron — every one of them pushed to the same place, so the destination is
 * named once in the section header instead of eleven times down the card.
 */
function timelineRow(col, { time, label, glyph, tint, detail, last }) {
  return `<div style="display:flex;align-items:center;gap:12px;min-height:${T.hitTarget.parentMinimum}px;
    ${last ? '' : `box-shadow:inset 0 -0.5px 0 ${col.divider};`}">
    <div style="${type('parentCallout', { color: col.textSecondary })};width:72px;font-size:15px;
      font-variant-numeric:tabular-nums;flex:0 0 auto">${time}</div>
    <div style="width:20px;display:grid;place-items:center;flex:0 0 auto">${GLYPH[glyph](tint, 17)}</div>
    <div style="${type('parentBody', { color: col.textPrimary })};flex:1;font-size:16px">${label}</div>
    ${detail ? `<span style="${type('parentCallout', { color: col.textSecondary })};font-size:15px;flex:0 0 auto">${detail}</span>` : ''}
  </div>`;
}

/**
 * The tab bar.
 *
 * The raised circular Hop button in the middle is gone. A floating action button
 * centred in a tab bar is a Material Design pattern — explicitly ruled out — and
 * it made a cartoon face the visual centre of every parent screen in the app.
 * Four equal tabs, system proportions, the pond reachable as a destination
 * rather than as a mascot glued to the chrome.
 */
function tabBar(col, active) {
  const tabs = [
    ['Home', GLYPH_TAB.home],
    ['Progress', GLYPH_TAB.chart],
    ["Hop's Pond", GLYPH_TAB.pond],
    ['Settings', GLYPH_TAB.gear],
  ];
  return `<div style="flex:0 0 auto;border-top:0.5px solid ${col.divider};background:${col.surface};
    display:flex;align-items:flex-start;padding:8px 4px 0">
    ${tabs.map(([name, icon]) => {
      const on = name === active;
      const tint = on ? col.brandAction : col.textSecondary;
      return `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:3px;color:${tint}">
        ${icon(tint)}
        <div style="${type('parentFootnote', { weight: on ? 'semibold' : 'medium' })};font-size:10px;color:${tint}">${name}</div>
      </div>`;
    }).join('')}
  </div>`;
}

/** `house.fill`, `chart.bar.fill`, `drop.circle.fill`, `gearshape.fill`. */
const GLYPH_TAB = {
  home: (f) => `<svg viewBox="0 0 24 24" width="23" height="23" fill="${f}"><path d="M12 3.2 21 11h-2.4v8.2a1 1 0 0 1-1 1H14V15h-4v5.2H6.4a1 1 0 0 1-1-1V11H3z"/></svg>`,
  chart: (f) => `<svg viewBox="0 0 24 24" width="23" height="23" fill="${f}"><rect x="3" y="12" width="4" height="8.5" rx="1.4"/><rect x="10" y="7" width="4" height="13.5" rx="1.4"/><rect x="17" y="3.5" width="4" height="17" rx="1.4"/></svg>`,
  pond: (f) => `<svg viewBox="0 0 24 24" width="23" height="23" fill="none" stroke="${f}" stroke-width="1.9"><circle cx="12" cy="12" r="9.2"/><path d="M12 6.4c2.1 2.6 3.4 4.5 3.4 6.1a3.4 3.4 0 0 1-6.8 0c0-1.6 1.3-3.5 3.4-6.1z" fill="${f}" stroke="none"/></svg>`,
  gear: (f) => `<svg viewBox="0 0 24 24" width="23" height="23" fill="${f}"><path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2zm8.4 3.6c0 .5 0 1-.1 1.5l2 1.6-2 3.4-2.4-1a7.6 7.6 0 0 1-2.5 1.5l-.4 2.5h-4l-.4-2.5a7.6 7.6 0 0 1-2.5-1.5l-2.4 1-2-3.4 2-1.6a8.6 8.6 0 0 1 0-3l-2-1.6 2-3.4 2.4 1a7.6 7.6 0 0 1 2.5-1.5L10 2h4l.4 2.5a7.6 7.6 0 0 1 2.5 1.5l2.4-1 2 3.4-2 1.6c.1.5.1 1 .1 1.5z"/></svg>`,
};

// ---------------------------------------------------------------------------
// The identity strip
// ---------------------------------------------------------------------------

/**
 * Who this screen is about, said quietly.
 *
 * The brief asks for "small child avatar, name, contextual greeting" and for
 * profile switching to be easy but visually quiet. What was here instead was a
 * frosted glass capsule with a blurred backdrop, a star count in a second
 * capsule and a notification bell with a badge in a third — three floating
 * objects competing with the hero before a caregiver had read anything.
 *
 * The stars moved to the pond, where they are earned and where a child can see
 * them; a parent utility does not need a score in its title bar. The bell went
 * with them: nothing on this screen was ever going to be reached through it.
 */
function identityStrip(col, { name = 'Maya', greeting = 'Good afternoon' } = {}) {
  return `<div style="display:flex;align-items:center;gap:12px;min-height:${T.hitTarget.parentMinimum}px">
    <div style="width:38px;height:38px;border-radius:19px;background:${T.palette.hopGreenSoft};
      display:grid;place-items:center;overflow:hidden;flex:0 0 auto">
      <div style="transform:translateY(3px)">${svg('Art/character/hop-face.svg', { width: 46 })}</div>
    </div>
    <div style="flex:1;min-width:0">
      <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px">${greeting}</div>
      <div style="display:flex;align-items:center;gap:5px">
        <span style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:22px;line-height:1.2">${name}'s routine</span>
        ${GLYPH.chevronDown(col.textTertiary, 13)}
      </div>
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// The hero
// ---------------------------------------------------------------------------

/**
 * Next Potty Pause. The one dominant object on the screen.
 *
 * It is a card again, and that is the point of the change rather than a
 * regression: the countdown used to stand on a painted pond, which bought its
 * legibility back with a shaped veil and a text halo — three mechanisms to make
 * text readable over a drawing that did not need to be there. On an opaque
 * surface the ink is `textPrimary` on `surface` at 12.9:1 and needs none of
 * them. Contrast that costs nothing is contrast that cannot be lost when the
 * art changes.
 *
 * Left-aligned, not centred. A centred block with two centred buttons is a
 * marketing hero; Health, Fitness and Screen Time all set their numbers on the
 * left margin, and the eye finds them faster for it.
 *
 * Every run is marked `data-ink` so the contrast checker can score it against
 * the ground actually painted underneath.
 */
function timerHero(col, appearance, { mode = 'Routine Mode', value = '28:14', size = 54 } = {}) {
  const modePill = `<div style="display:inline-flex;align-items:center;gap:6px;height:26px;padding:0 11px;
    border-radius:13px;background:${col.surfaceSunken};flex:0 0 auto">
    <div style="width:7px;height:7px;border-radius:4px;background:${col.brandAction}"></div>
    <span data-ink style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:12px">${mode}</span>
  </div>`;

  return card(col, `
    <div style="display:flex;align-items:center;justify-content:space-between;gap:12px">
      <span data-ink style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};
        text-transform:uppercase;letter-spacing:.7px;font-size:12px">Next Potty Pause</span>
      ${modePill}
    </div>
    <div data-ink style="${type('parentLargeTitle', { color: col.textPrimary, weight: 'bold' })};font-size:${size}px;
      line-height:1.06;letter-spacing:-1.4px;margin-top:8px;font-variant-numeric:tabular-nums">${value}</div>
    <div style="height:1px;background:${col.divider};margin:16px 0 14px"></div>
    <div style="display:flex;gap:10px">
      ${heroButton(col, appearance, 'Skip', { role: 'secondary' })}
      ${heroButton(col, appearance, 'Start Now', { role: 'primary' })}
    </div>`, { pad: 18, radius: T.radius.l, appearance });
}

/**
 * The two actions.
 *
 * Both 48pt with a 12pt radius — a control on a card, not a capsule floating on
 * water. Skip is a tinted fill rather than a hairline outline: on the sunken
 * grey a hairline button reads as disabled, and `brandAction` on `surfaceSunken`
 * is the pair that has to carry it.
 */
function heroButton(col, appearance, label, { role }) {
  const H = 48;
  if (role === 'primary') {
    return `<div style="flex:1;height:${H}px;border-radius:${T.radius.m}px;background:${col.brandAction};
      display:grid;place-items:center;${type('parentHeadline', { color: col.textOnBrand, weight: 'semibold' })};font-size:17px">
      <span data-ink>${label}</span></div>`;
  }
  return `<div style="flex:1;height:${H}px;border-radius:${T.radius.m}px;background:${col.surfaceSunken};
    display:grid;place-items:center;${type('parentHeadline', { color: col.brandAction, weight: 'semibold' })};font-size:17px">
    <span data-ink>${label}</span></div>`;
}

// ---------------------------------------------------------------------------
// The three blocks below it
// ---------------------------------------------------------------------------

function todayBlock(col, appearance) {
  const TINT = tints(appearance);
  const rule = `<div style="width:0.5px;align-self:stretch;background:${col.divider};margin:2px 0"></div>`;
  return `<div>
    ${sectionHeader(col, 'Today')}
    ${card(col, `<div style="display:flex;align-items:stretch">
      ${metricChip(col, { glyph: 'check', value: '6', label: 'Checks', tint: TINT.check.tint })}
      ${rule}
      ${metricChip(col, { glyph: 'tried', value: '5', label: 'Tried', tint: TINT.tried.tint })}
      ${rule}
      ${metricChip(col, { glyph: 'pee', value: '3', label: 'Pee', tint: TINT.pee.tint })}
      ${rule}
      ${metricChip(col, { glyph: 'poop', value: '1', label: 'Poop', tint: TINT.poop.tint })}
    </div>`, { pad: 14, appearance })}
  </div>`;
}

/**
 * The day, in the shape Apple Health draws a timeline.
 *
 * The accident at 10:05 is here on purpose, and it is drawn exactly like every
 * other entry: `eventAccident` is the palette's neutral grey, the row carries no
 * tint, no warning mark and no emphasis. §7 — an accident is a fact about a
 * period, not a failure, and the timeline must not editorialise it.
 *
 * `full` is the iPad's longer day. The phone shows the last few and names the
 * rest in the header; the detail column on a 1024pt screen has the height for
 * the day itself, which is the difference between an iPad layout and a stretched
 * phone one.
 */
function routineBlock(col, appearance, { full = false } = {}) {
  const TINT = tints(appearance);
  const day = [
    { time: '1:42 PM', label: 'Pee', glyph: 'pee', tint: TINT.pee.tint },
    { time: '12:54 PM', label: 'Tried', glyph: 'tried', tint: TINT.tried.tint },
    { time: '11:58 AM', label: 'Poop', glyph: 'poop', tint: TINT.poop.tint },
    { time: '11:10 AM', label: 'Tried', glyph: 'tried', tint: TINT.tried.tint },
    { time: '10:05 AM', label: 'Accident', glyph: 'accident', tint: TINT.accident.tint },
    { time: '9:16 AM', label: 'Pee', glyph: 'pee', tint: TINT.pee.tint },
    { time: '8:20 AM', label: 'Tried', glyph: 'tried', tint: TINT.tried.tint },
  ];
  const rows = full ? day : day.slice(0, 3);
  return `<div>
    ${sectionHeader(col, "Today's entries", { action: full ? '' : 'Show all' })}
    ${card(col, rows.map((r, i) => timelineRow(col, { ...r, last: i === rows.length - 1 })).join(''),
      { appearance, extra: 'padding:2px 16px' })}
  </div>`;
}

/**
 * One observation, once.
 *
 * The hedge used to be a filled pill inside the card, repeated on every card of
 * every Progress screen. It is a footnote under the card now — said once, in the
 * place iOS puts the sentence that qualifies a group.
 */
function insightBlock(col, appearance) {
  const TINT = tints(appearance);
  return `<div>
    ${card(col, `<div style="display:flex;gap:12px;align-items:flex-start">
      <div style="width:22px;padding-top:1px;flex:0 0 auto">${GLYPH.chart(TINT.pee.tint, 18)}</div>
      <div style="flex:1">
        <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:16px">A pattern is forming</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:14px;margin-top:3px;line-height:1.4">
          Half of the recorded gaps between potty visits fell within 45–55 minutes.</div>
      </div>
    </div>`, { pad: 15, appearance })}
    <div style="${type('parentCaption', { color: col.textSecondary })};font-size:12.5px;padding:7px 6px 0;line-height:1.35">
      A pattern in what you logged, not medical advice.</div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 01 / 14 — phone
// ---------------------------------------------------------------------------

const W = 393, H = 852;
const PAGE = T.spacing.pageCompact;      // 20
const TAB_H = 50, HOME_IND = 26;

function parentHome(appearance = 'light') {
  const col = c(appearance);

  return `
  <div style="display:flex;flex-direction:column;width:${W}px;height:${H}px;overflow:hidden;background:${pageGround(col)}">
    ${statusBar(col.textPrimary)}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:6px ${PAGE}px 8px;overflow:hidden;min-height:0">
      ${identityStrip(col)}
      <div data-arrive style="display:flex;flex-direction:column;gap:16px;padding-top:10px">
        ${timerHero(col, appearance)}
        ${todayBlock(col, appearance)}
        ${routineBlock(col, appearance)}
        ${insightBlock(col, appearance)}
      </div>
      <div style="flex:1"></div>
    </div>
    ${tabBar(col, 'Home')}
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

// ---------------------------------------------------------------------------
// 15 — iPad
// ---------------------------------------------------------------------------

const PAD = { w: 1024, h: 768, rail: 260 };

/**
 * The split-view sidebar the iPad build actually shows instead of a tab bar.
 *
 * §44 asks for intentional split navigation rather than a stretched phone. The
 * rail is a real iPadOS sidebar — a sunken ground, a selected row that is a
 * filled capsule, system-proportioned marks — and the detail column is laid out
 * for the width it has rather than being the phone column with more air.
 */
function sidebar(col, appearance, active = 'Home') {
  const rows = [
    ['Home', GLYPH_TAB.home],
    ['Progress', GLYPH_TAB.chart],
    ["Hop's Pond", GLYPH_TAB.pond],
    ['Settings', GLYPH_TAB.gear],
  ];
  return `<div style="position:absolute;left:0;top:0;bottom:0;width:${PAD.rail}px;background:${col.surfaceSunken};
    border-right:0.5px solid ${col.divider};display:flex;flex-direction:column">
    ${statusBarPad(col.textSecondary)}
    <div style="padding:16px 20px 12px">
      <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:26px">HopPotty</div>
    </div>
    <div style="padding:0 12px;display:flex;flex-direction:column;gap:2px">
      ${rows.map(([label, icon]) => {
        const on = label === active;
        const tint = on ? col.textOnBrand : col.textSecondary;
        return `<div style="height:${T.hitTarget.parentMinimum}px;border-radius:10px;display:flex;align-items:center;gap:12px;
          padding:0 12px;${on ? `background:${col.brandAction};` : ''}">
          <div style="width:23px;display:grid;place-items:center">${icon(tint)}</div>
          <span style="${type('parentBody', { weight: on ? 'semibold' : 'regular' })};font-size:16px;
            color:${on ? col.textOnBrand : col.textPrimary}">${label}</span>
        </div>`;
      }).join('')}
    </div>
    <div style="flex:1"></div>
    <div style="padding:0 20px 18px;display:flex;align-items:center;gap:10px">
      <div style="width:30px;height:30px;border-radius:15px;background:${T.palette.hopGreenSoft};
        display:grid;place-items:center;overflow:hidden;flex:0 0 auto">
        <div style="transform:translateY(2px)">${svg('Art/character/hop-face.svg', { width: 36 })}</div>
      </div>
      <div style="flex:1;min-width:0">
        <div style="${type('parentCallout', { color: col.textPrimary, weight: 'semibold' })};font-size:15px">Maya</div>
      </div>
      ${GLYPH.chevronDown(col.textTertiary, 13)}
    </div>
  </div>`;
}

function parentHomePad(appearance = 'light') {
  const col = c(appearance);
  const w = PAD.w - PAD.rail;              // 764
  const gutter = T.spacing.pageRegular;    // 32
  const gap = 24;
  const colW = Math.round((w - gutter * 2 - gap) / 2);

  return `
  <div style="position:relative;width:${PAD.w}px;height:${PAD.h}px;overflow:hidden;background:${pageGround(col)}">
    ${sidebar(col, appearance, 'Home')}
    <div style="position:absolute;left:${PAD.rail}px;top:0;width:${w}px;height:${PAD.h}px;overflow:hidden;
      display:flex;flex-direction:column">
      <div style="height:24px;flex:0 0 auto"></div>
      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:6px ${gutter}px 20px;overflow:hidden">

        <div style="display:flex;align-items:flex-end;justify-content:space-between;padding-bottom:4px">
          <div>
            <div style="${type('parentCaption', { color: col.textSecondary })};font-size:14px">Good afternoon</div>
            <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px;line-height:1.18">Maya's routine</div>
          </div>
        </div>

        <div data-arrive style="display:flex;gap:${gap}px;padding-top:18px;align-items:flex-start">
          <div style="width:${colW}px;flex:0 0 auto;display:flex;flex-direction:column;gap:20px">
            ${timerHero(col, appearance, { size: 64 })}
            ${todayBlock(col, appearance)}
            ${insightBlock(col, appearance)}
          </div>
          <div style="width:${colW}px;flex:0 0 auto">
            ${routineBlock(col, appearance, { full: true })}
          </div>
        </div>
        <div style="flex:1"></div>
      </div>
    </div>
  </div>`;
}

module.exports = {
  parentHome, parentHomePad, card, GLYPH, GLYPH_TAB, metricChip, timelineRow, tabBar,
  sectionHeader, pageGround, identityStrip, sidebar, PAD,
};
