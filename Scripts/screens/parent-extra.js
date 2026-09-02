/**
 * 31–44 — the rest of the caregiver's app.
 *
 * Onboarding's permission moment, the settings tree, the paywall, the gate, the
 * two screens where something has gone wrong or has not started yet, the quick
 * reminder sheet, and the surfaces that live outside the app: widgets, a Live
 * Activity, and Progress on an iPad.
 *
 * Everything here follows the same rule as the screens before it: colour,
 * radius, spacing and type come out of `Scripts/tokens.json`, the words come out
 * of `HopCopy*.swift` wherever a key exists, and no screen shows a number the
 * app could not actually know. Where a surface does not exist in the codebase
 * yet — widgets and the Live Activity — nothing is invented beyond what the
 * schedule and the routine already hold.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOr } = require('./ui');
const {
  listRow, listGroup, navBar, iosSwitch, iconTile, segmented, pageDots, stepDots,
  MARK, sparkline, patternLabel, tints, statusBarPad,
} = require('./kit');
const { card, metricChip, tabBar, parentHome } = require('./parent');
const { ctaButton } = require('./onboarding');

const P = T.palette;
const W = 393, H = 852;
const PAGE = T.spacing.pageCompact;   // 20
const TAB_H = 50, HOME_IND = 26;

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/** A phone screen: status bar, a body, the home indicator. */
function phone(appearance, body, { bg } = {}) {
  const col = c(appearance);
  return `<div style="display:flex;flex-direction:column;height:${H}px;background:${bg || col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}${body}${homeIndicator(col.textPrimary)}</div>`;
}

/** Hop's face on a coloured disc, the way every avatar in the app is drawn. */
function avatarDisc(size, { fill = P.hopGreenSoft, ring = P.hopGreenLight, ringWidth = 1.5 } = {}) {
  return `<div style="width:${size}px;height:${size}px;border-radius:${size / 2}px;background:${fill};
    display:grid;place-items:center;overflow:hidden;flex:0 0 auto;
    ${ring ? `border:${ringWidth}px solid ${ring};` : ''}">
    <div style="transform:translateY(${Math.round(size * 0.1)}px)">${svg('Art/character/hop-face.svg', { width: size * 1.25 })}</div>
  </div>`;
}

/** The uppercase eyebrow an onboarding screen opens with. */
function eyebrow(col, text, tint) {
  return `<div style="${type('parentFootnote', { color: tint || col.brandAction, weight: 'semibold' })};
    font-size:12px;letter-spacing:.9px;text-transform:uppercase">${text}</div>`;
}

/** A back chevron on its own row, as onboarding draws it. */
function backRow(col, { trailing = '' } = {}) {
  return `<div style="height:26px;display:flex;align-items:center;justify-content:space-between">
    <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="${col.brandAction}" stroke-width="2.6"
      stroke-linecap="round" stroke-linejoin="round" style="margin-left:-4px"><path d="M15 5l-7 7 7 7"/></svg>
    ${trailing}
  </div>`;
}

/** A promise: a tinted glyph tile, then one sentence that has to be true. */
function promiseRow(col, appearance, { glyph, tint, soft, text }) {
  return `<div style="display:flex;gap:13px;align-items:flex-start;background:${col.surface};
    border-radius:${T.radius.l}px;padding:13px 15px;box-shadow:${elevation(appearance, 'resting')}">
    ${iconTile(soft, glyph(tint, 18), { size: 34, radius: 11 })}
    <div style="flex:1;${type('parentCaption', { color: col.textSecondary })};font-size:13.5px;line-height:1.42">${text}</div>
  </div>`;
}

/** A secondary, unfilled caregiver button. Same height as the primary. */
function secondaryButton(col, label, { height = 52 } = {}) {
  return `<div style="height:${height}px;border-radius:${height / 2}px;border:1.5px solid ${col.divider};
    display:grid;place-items:center;${type('parentHeadline', { color: col.textSecondary, weight: 'semibold' })};font-size:17px">${label}</div>`;
}

/**
 * A sheet over the screen that presented it.
 *
 * iOS scales the presenter back, rounds its corners and dims it; drawing that
 * rather than a flat scrim is what makes a sheet read as a sheet.
 */
function sheetOver(appearance, presenter, sheetInner, { top, radius = 12 } = {}) {
  const col = c(appearance);
  return `<div style="position:relative;width:${W}px;height:${H}px;overflow:hidden;background:${P.midnight}">
    <div style="position:absolute;left:0;top:10px;width:${W}px;height:${H}px;overflow:hidden;border-radius:14px;
      transform:scale(0.93);transform-origin:top center;box-shadow:0 -2px 16px ${alpha(P.midnight, .4)}">
      ${presenter}
      <div style="position:absolute;inset:0;background:${alpha(P.midnight, .14)}"></div>
    </div>
    <div style="position:absolute;left:0;right:0;top:${top}px;bottom:0;background:${col.backgroundPrimary};
      border-radius:${radius}px ${radius}px 0 0;box-shadow:0 -8px 30px ${alpha(P.midnight, .28)};
      display:flex;flex-direction:column;overflow:hidden">
      <div style="height:20px;display:grid;place-items:center;flex:0 0 auto">
        <div style="width:36px;height:5px;border-radius:3px;background:${col.divider}"></div>
      </div>
      ${sheetInner}
    </div>
  </div>`;
}

/** A sheet's own bar: a leading control, a centred title, an optional trailing. */
function sheetBar(col, title, { leading = '', trailing = '' } = {}) {
  return `<div style="height:44px;display:flex;align-items:center;padding:0 16px;flex:0 0 auto">
    <div style="flex:1;${type('parentBody', { color: col.brandAction })};font-size:16px">${leading}</div>
    <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:17px">${title}</div>
    <div style="flex:1;text-align:right;${type('parentBody', { color: col.brandAction, weight: 'semibold' })};font-size:16px">${trailing}</div>
  </div>`;
}

/** A glyph the shared set does not carry. */
const EXTRA = {
  pond: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><ellipse cx="12" cy="13" rx="9" ry="6"/><path d="M12 13 L21 9.4 A9 6 0 0 0 18 7.4Z" fill="#FFFFFF" fill-opacity=".55"/></svg>`,
  shield: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 2.4 20 5.4v6.2c0 4.6-3.2 8.6-8 10-4.8-1.4-8-5.4-8-10V5.4z"/></svg>`,
  people: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><circle cx="8.6" cy="8.2" r="3.6"/><circle cx="16.6" cy="9.4" r="2.8"/><path d="M2.4 19.4c0-3.3 2.8-5.6 6.2-5.6s6.2 2.3 6.2 5.6z"/><path d="M16.4 14.2c2.8 0 5.2 1.9 5.2 4.6h-4.3c0-1.8-.5-3.4-1.5-4.6z"/></svg>`,
  slider: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round"><path d="M4 7.6h10M18 7.6h2M4 16.4h4M12 16.4h8"/><circle cx="16" cy="7.6" r="2.2" fill="${f}" stroke="none"/><circle cx="10" cy="16.4" r="2.2" fill="${f}" stroke="none"/></svg>`,
  trash: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M9.4 3.2h5.2l.8 1.6h4.2v2.2H4.4V4.8h4.2zM6 8.6h12l-.9 11.1a1.6 1.6 0 0 1-1.6 1.5H8.5a1.6 1.6 0 0 1-1.6-1.5z"/></svg>`,
  export: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15.4V3.6"/><path d="M7.8 7.8 12 3.6l4.2 4.2"/><path d="M4.6 14.6v4.4a1.4 1.4 0 0 0 1.4 1.4h12a1.4 1.4 0 0 0 1.4-1.4v-4.4"/></svg>`,
  apps: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><rect x="3.4" y="3.4" width="7.4" height="7.4" rx="2"/><rect x="13.2" y="3.4" width="7.4" height="7.4" rx="2" opacity=".55"/><rect x="3.4" y="13.2" width="7.4" height="7.4" rx="2" opacity=".55"/><rect x="13.2" y="13.2" width="7.4" height="7.4" rx="2"/></svg>`,
  warning: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round"><circle cx="12" cy="12" r="8.6"/><path d="M12 7.6v5"/><circle cx="12" cy="16.2" r="0.5" fill="${f}"/></svg>`,
  info: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round"><circle cx="12" cy="12" r="8.6"/><path d="M12 11.4v4.8"/><circle cx="12" cy="8" r="0.6" fill="${f}"/></svg>`,
  plus: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.6" stroke-linecap="round"><path d="M12 5.4v13.2M5.4 12h13.2"/></svg>`,
  roll: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="4.6" width="9.6" height="14.8" rx="4.8"/><path d="M13.6 19.4h5.6V9.2a4.6 4.6 0 0 0-5.6-4.6"/><circle cx="8.8" cy="9.4" r="1.5"/></svg>`,
};

// ---------------------------------------------------------------------------
// 31 — the permission conversation, before Apple's prompt
// ---------------------------------------------------------------------------

/**
 * The explainer HopPotty shows *before* `requestAuthorization(for:)`.
 *
 * The order is the whole design: a system alert that arrives with no context is
 * the one a caregiver declines, and a declined Family Controls request is not
 * retryable in the way a caregiver expects (`Docs/ScreenTimeArchitecture.md` §3).
 * So the three promises are made here, in HopPotty's own words, and the screen
 * says plainly that the next screen is Apple's and what happens if they say no.
 */
function screenTimeAsk(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const soft = (hex) => (dark ? alpha(hex, 0.2) : mix(hex, '#FFFFFF', 0.8));

  return phone(appearance, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 24px 8px;overflow:hidden">
      ${backRow(col)}

      <div style="flex:0 0 auto;padding-top:10px">
        ${eyebrow(col, 'Permission')}
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px;margin-top:5px">HopPotty uses Screen Time</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:15px;margin-top:9px;line-height:1.45">
          iOS does the pausing. HopPotty asks permission to pause only the apps you pick, and never sees what happens inside them.</div>
      </div>

      <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:10px;padding-top:20px">
        ${promiseRow(col, appearance, {
          glyph: MARK.lock, tint: dark ? P.hopGreenLight : P.hopGreenInk, soft: soft(P.hopGreen),
          text: 'The pause ends when this time is up, whatever happened in the bathroom. Screen access is never held back for a result.',
        })}
        ${promiseRow(col, appearance, {
          glyph: EXTRA.shield, tint: col.eventPee, soft: soft(P.pondBlue),
          text: 'Apple hands over a sealed token for each app you pick. HopPotty can count them and pause them — it cannot read a name or an icon.',
        })}
        ${promiseRow(col, appearance, {
          glyph: MARK.check, tint: dark ? P.lavender : P.lavenderDeep, soft: soft(P.lavender),
          text: 'Every event, star and note lives on your device. There is no account, no analytics, and nothing is uploaded.',
        })}
      </div>

      <div style="flex:0 0 auto;margin-top:18px;display:flex;gap:11px;align-items:flex-start;
        border-radius:${T.radius.l}px;padding:13px 15px;background:${col.surfaceSunken};border:1px solid ${col.divider}">
        ${iconTile(dark ? alpha('#FFFFFF', .08) : '#FFFFFF', EXTRA.info(col.textTertiary, 17), { size: 30, radius: 9 })}
        <div style="flex:1;${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.4">
          The next screen is Apple's. HopPotty cannot see or change what it asks.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.4;
          text-align:center;padding:0 6px 14px">
          Without Screen Time permission, apps are never paused. Hop still checks in on your schedule, and you can turn pausing on later in Settings.</div>
        ${pageDots(col, 4, 3)}
        <div style="margin-top:18px">${ctaButton(col, appearance, 'Allow Screen Time')}</div>
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 32 — the child profile
// ---------------------------------------------------------------------------

/** The five frog colours of `HopAvatarStyle`, as their palette pairs. */
const AVATARS = [
  ['frogGreen', P.hopGreenSoft, P.hopGreen],
  ['frogBlue', P.pondBlueSoft, P.pondBlue],
  ['frogSunshine', P.sunshineSoft, P.sunshineBright],
  ['frogPeach', P.peachSoft, P.peachPop],
  ['frogLavender', P.lavenderSoft, P.lavender],
];

/**
 * Nickname, a starting routine, a colour. That is the whole form.
 *
 * `ChildProfile` has nowhere to put a birthday, a last name or a photograph, and
 * the band below is a *routine* choice rather than a fact about the child — so
 * the footer says so instead of leaving a caregiver to assume HopPotty is
 * keeping an age.
 */
function childProfile(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');

  const band = (title, sub, on) => `
    <div style="display:flex;align-items:center;gap:12px;min-height:56px;padding:10px 15px;
      ${on ? '' : `box-shadow:inset 0 -1px 0 ${col.divider};`}">
      <div style="flex:1;min-width:0">
        <div style="${type('parentBody', { color: col.textPrimary, weight: on ? 'semibold' : 'regular' })};font-size:16px">${title}</div>
        <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;margin-top:1px">${sub}</div>
      </div>
      ${on
        ? `<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="${col.brandAction}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4.6 12.6 9.6 17.6 19.4 6.6"/></svg>`
        : `<div style="width:20px;height:20px;border-radius:10px;border:1.6px solid ${col.divider}"></div>`}
    </div>`;

  return phone(appearance, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 24px 8px;overflow:hidden">
      ${backRow(col)}

      <div style="flex:0 0 auto;padding-top:8px">
        ${eyebrow(col, 'Your child')}
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:29px;margin-top:5px">What can Hop call your child?</div>
      </div>

      <div style="flex:0 0 auto;margin-top:14px;height:56px;border-radius:${T.radius.m}px;background:${col.surface};
        border:1.5px solid ${col.brandAction};display:flex;align-items:center;padding:0 16px;gap:2px;
        box-shadow:${elevation(appearance, 'resting')}">
        <span style="${type('parentTitle', { color: col.textPrimary })};font-size:20px">Maya</span>
        <div style="width:2px;height:24px;background:${col.brandAction};border-radius:1px;margin-left:2px"></div>
        <div style="flex:1"></div>
        <span style="${type('parentFootnote', { color: col.textTertiary })};font-size:12px">4/24</span>
      </div>
      <div style="flex:0 0 auto;${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;
        line-height:1.4;padding:7px 4px 0">
        Optional. HopPotty asks for nothing else: no last name, no birthday, no photo.</div>

      <div style="flex:0 0 auto;display:flex;align-items:center;gap:10px;margin-top:14px;align-self:flex-start;
        padding:8px 14px 8px 8px;border-radius:24px;background:${dark ? alpha(P.hopGreen, .13) : P.hopGreenSoft}">
        ${avatarDisc(30, { fill: '#FFFFFF', ring: P.hopGreenLight })}
        <span style="${type('parentCallout', { color: dark ? col.textPrimary : P.hopGreenInk, weight: 'semibold' })};font-size:14.5px">Hi, Maya! I'm Hop.</span>
      </div>

      <div style="flex:0 0 auto;padding-top:20px">
        ${eyebrow(col, 'Character', col.textTertiary)}
        <div style="display:flex;gap:12px;margin-top:11px">
          ${AVATARS.map(([name, fill, ring], i) => `
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px">
              <div style="position:relative;padding:3px;border-radius:29px;
                ${i === 0 ? `box-shadow:0 0 0 2.5px ${col.brandAction};` : ''}">
                ${avatarDisc(52, { fill, ring, ringWidth: 2 })}
              </div>
            </div>`).join('')}
        </div>
      </div>

      <div style="flex:0 0 auto;padding-top:20px">
        ${eyebrow(col, 'Where are you starting?', col.textTertiary)}
        <div style="margin-top:9px;background:${col.surface};border-radius:${T.radius.l}px;overflow:hidden;
          box-shadow:${elevation(appearance, 'resting')}">
          ${band('Just starting out', 'Around 2. Nappies most of the day.')}
          ${band('Getting the hang of it', 'Around 3. Dry stretches, some accidents.', true)}
          ${band('Mostly independent', '4 and up. Needs the occasional nudge.', false)}
        </div>
        <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.4;padding:7px 4px 0">
          This only picks a starting routine, and you can change it any time. HopPotty stores no age and no birthday.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${pageDots(col, 4, 2)}
        <div style="margin-top:18px">${ctaButton(col, appearance, 'Continue')}</div>
      </div>
    </div>`, { bg: dark ? undefined : col.backgroundPrimary });
}

// ---------------------------------------------------------------------------
// 33 — the schedule is set
// ---------------------------------------------------------------------------

/** The finish line of setup: what was set, in one sentence, and the way out. */
function firstPauseSet(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const accentInk = dark ? P.hopGreenLight : P.hopGreenInk;
  const sparkle = (x, y, s, o) => `<div style="position:absolute;left:${x}px;top:${y}px;opacity:${o}">${MARK.star(P.sunshine, s)}</div>`;

  return phone(appearance, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 24px 8px;overflow:hidden">
      <div style="height:20px"></div>

      <div style="flex:0 0 auto;position:relative;display:flex;justify-content:center">
        <div style="position:absolute;left:50%;top:22px;width:214px;height:214px;margin-left:-107px;border-radius:107px;
          background:${dark ? alpha(P.hopGreen, .12) : mix(P.hopGreenSoft, P.cloud, .28)}"></div>
        <div style="position:relative">${svg('Art/character/hop-cheer.svg', { width: 226 })}</div>
        ${sparkle(10, 38, 21, .95)}${sparkle(298, 20, 15, .8)}${sparkle(32, 162, 13, .7)}${sparkle(308, 138, 19, .85)}
      </div>

      <div style="flex:0 0 auto;text-align:center;padding-top:4px">
        <div style="${type('hero', { color: col.textPrimary })};font-size:38px">You are all set</div>
        <div style="${type('parentBody', { color: col.textSecondary })};font-size:17px;margin-top:9px;line-height:1.4">
          HopPotty is watching the clock now. Everything is editable in Settings.</div>
      </div>

      <div style="flex:0 0 auto;margin-top:20px;background:${dark ? alpha(P.hopGreen, .13) : P.hopGreenSoft};
        border-radius:${T.radius.l}px;padding:14px 16px;display:flex;gap:12px;align-items:flex-start">
        ${iconTile(dark ? alpha(P.hopGreenLight, .2) : '#FFFFFF', MARK.clock(accentInk, 17), { size: 30, radius: 15 })}
        <div style="flex:1">
          <div style="${type('parentFootnote', { color: accentInk, weight: 'semibold' })};font-size:11px;
            letter-spacing:.6px;text-transform:uppercase">Your schedule</div>
          <div style="${type('parentCallout', { color: dark ? col.textPrimary : accentInk })};font-size:14px;
            line-height:1.42;margin-top:3px">
            Hop invites Maya about every 45 minutes, with a 2-minute heads-up. Pauses last 3 minutes and stay quiet at nap and bedtime.</div>
        </div>
      </div>

      <div style="flex:0 0 auto;margin-top:10px;display:flex;gap:11px;align-items:flex-start;padding:0 4px">
        ${MARK.check(col.textTertiary, 15)}
        <div style="flex:1;${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.42">
          A pause always ends on its own timer. Screen access is never held back for a result.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.l}px;padding:14px 15px;
        box-shadow:${elevation(appearance, 'resting')}">
        <div style="display:flex;gap:12px;align-items:flex-start">
          ${iconTile(dark ? alpha(P.pondBlue, .2) : P.pondBlueSoft, MARK.play(col.eventPee, 16), { size: 32, radius: 10 })}
          <div style="flex:1">
            <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15.5px">Try a Potty Pause</div>
            <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:3px;line-height:1.42">
              This runs one pause right now so you can see exactly what your child sees. It ends on its own.</div>
          </div>
        </div>
        <div style="margin-top:12px">${secondaryButton(col, 'Run a test pause', { height: 44 })}</div>
      </div>

      <div style="height:14px;flex:0 0 auto"></div>

      <div style="flex:0 0 auto">
        ${ctaButton(col, appearance, 'Go to HopPotty')}
        <div style="height:12px"></div>
        <div style="text-align:center;${type('parentCallout', { color: col.textTertiary })};font-size:15px">Change the schedule</div>
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 34 — Settings
// ---------------------------------------------------------------------------

/** The grouped list every caregiver already knows how to read. */
function settingsHub(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const tile = (hue, glyph) => iconTile(hue, glyph, { size: 29, radius: 8 });
  const soft = (hex) => (dark ? alpha(hex, 0.24) : mix(hex, '#FFFFFF', 0.72));

  return `
  <div style="display:flex;flex-direction:column;height:${H}px;background:${col.backgroundSecondary}">
    ${statusBar(col.textPrimary)}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:10px;padding:0 ${PAGE}px 6px;overflow:hidden">

      <div style="flex:0 0 auto;${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px;padding-bottom:2px">Settings</div>

      ${listGroup(col, appearance, {
        header: 'Children',
        rows: [
          listRow(col, {
            icon: avatarDisc(30, { fill: P.hopGreenSoft, ring: P.hopGreenLight }),
            label: 'Maya', sub: 'Currently shown', chevron: true, minHeight: 48,
          }),
          listRow(col, {
            icon: avatarDisc(30, { fill: P.pondBlueSoft, ring: P.pondBlue }),
            label: 'Sam', chevron: true, minHeight: 48,
          }),
          listRow(col, {
            icon: tile(soft(P.hopGreen), EXTRA.plus(col.brandAction, 16)),
            label: `<span style="color:${col.brandAction}">Add a child</span>`, accessory: '', last: true,
          }),
        ],
      })}

      ${listGroup(col, appearance, {
        rows: [
          listRow(col, {
            icon: tile(soft(P.hopGreen), MARK.clock('#FFFFFF', 17)),
            label: 'Potty Pause', value: 'Guided routine', chevron: true,
          }),
          listRow(col, {
            icon: tile(soft(P.pondBlue), EXTRA.apps('#FFFFFF', 16)),
            label: 'Apps that pause', value: '4 apps, 1 category', chevron: true,
          }),
          listRow(col, {
            icon: tile(soft(P.lavender), MARK.bell('#FFFFFF', 16)),
            label: 'Warning before a pause', accessory: iosSwitch(col, true), last: true,
          }),
        ],
        footer: 'The pause ends when this time is up, whatever happened in the bathroom.',
      })}

      ${listGroup(col, appearance, {
        rows: [
          listRow(col, {
            icon: tile(soft(P.sunshine), MARK.star('#FFFFFF', 16)),
            label: 'HopPotty Family', chevron: true, last: true,
          }),
        ],
        footer: 'The free version keeps one child, the full routine and every reminder. Nothing your child earned is ever behind the purchase.',
      })}

      ${listGroup(col, appearance, {
        rows: [
          listRow(col, {
            icon: tile(soft(P.pondBlue), EXTRA.export('#FFFFFF', 15)),
            label: 'Export my data', chevron: true,
          }),
          listRow(col, {
            icon: tile(soft(P.peachPop), EXTRA.trash('#FFFFFF', 15)),
            label: `<span style="color:${col.eventPoop}">Delete everything</span>`, accessory: '', last: true,
          }),
        ],
      })}

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;text-align:center;padding-bottom:2px;
        ${type('parentCaption', { color: col.textTertiary })};font-size:12px">Version 1.0 (12)</div>
    </div>
    ${tabBar(col, 'Settings')}
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

// ---------------------------------------------------------------------------
// 35 — Children
// ---------------------------------------------------------------------------

/**
 * The child list.
 *
 * Each child owns a schedule, a timeline, their own stars and their own pond,
 * so the row says which schedule is theirs rather than treating a second child
 * as a copy of the first.
 */
function childProfiles(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const TINT = tints(appearance);

  /** One of today's counts, small enough that four fit across a card. */
  const stat = (glyph, tint, soft, value, label) => `
    <div style="flex:1;display:flex;align-items:center;gap:8px;min-width:0">
      <div style="width:26px;height:26px;border-radius:13px;background:${soft};display:grid;place-items:center;flex:0 0 auto">${glyph(tint, 14)}</div>
      <div style="min-width:0">
        <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'bold' })};font-size:15px;line-height:1.1">${value}</div>
        <div style="${type('parentFootnote', { color: col.textTertiary })};font-size:10.5px;line-height:1.2">${label}</div>
      </div>
    </div>`;

  const childCard = (name, schedule, disc, counts, pond, { active = false } = {}) => `
    <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.xl}px;padding:13px 15px 14px;
      box-shadow:${elevation(appearance, 'resting')}">
      <div style="display:flex;align-items:center;gap:12px">
        ${avatarDisc(46, disc)}
        <div style="flex:1;min-width:0">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="${type('parentTitle', { color: col.textPrimary })};font-size:19px">${name}</span>
            ${active ? `<span style="padding:2px 8px;border-radius:8px;background:${dark ? alpha(P.hopGreen, .2) : P.hopGreenSoft};
              ${type('parentFootnote', { color: dark ? P.hopGreenLight : P.hopGreenInk, weight: 'semibold' })};font-size:10.5px">Currently shown</span>` : ''}
          </div>
          <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;margin-top:2px">${schedule}</div>
        </div>
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="${col.textTertiary}" stroke-width="2.8"
          stroke-linecap="round" stroke-linejoin="round" style="flex:0 0 auto"><path d="M9 5l7 7-7 7"/></svg>
      </div>

      <div style="${type('parentFootnote', { color: col.textTertiary, weight: 'semibold' })};font-size:11px;
        letter-spacing:.5px;text-transform:uppercase;margin-top:13px;padding-top:12px;border-top:1px solid ${col.divider}">Today</div>
      <div style="display:flex;gap:6px;margin-top:9px">
        ${stat(MARK.ring, TINT.tried.tint, TINT.tried.soft, counts[0], 'Tried')}
        ${stat(MARK.drop, TINT.pee.tint, TINT.pee.soft, counts[1], 'Pee')}
        ${stat(MARK.swirl, TINT.poop.tint, TINT.poop.soft, counts[2], 'Poop')}
        ${stat(MARK.star, TINT.star.tint, TINT.star.soft, counts[3], 'Stars')}
      </div>

      <div style="display:flex;align-items:center;gap:10px;margin-top:12px">
        <span style="${type('parentFootnote', { color: col.textTertiary })};font-size:11.5px;flex:0 0 auto">Pond</span>
        <div style="flex:1;height:7px;border-radius:4px;background:${col.surfaceSunken};overflow:hidden">
          <div style="width:${Math.round((pond / 41) * 100)}%;height:100%;border-radius:4px;background:${col.brandPrimary}"></div>
        </div>
        <span style="${type('parentFootnote', { color: col.textTertiary })};font-size:11.5px;flex:0 0 auto;
          font-variant-numeric:tabular-nums">${pond} of 41</span>
      </div>
    </div>`;

  return `
  <div style="display:flex;flex-direction:column;height:${H}px;background:${col.backgroundSecondary}">
    ${statusBar(col.textPrimary)}
    ${navBar(col, 'Children', { large: true })}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:12px;padding:4px ${PAGE}px 6px;overflow:hidden">

      ${childCard('Maya', 'Guided routine · every 45 minutes',
        { fill: P.hopGreenSoft, ring: P.hopGreenLight }, ['5', '3', '1', '13'], 6, { active: true })}

      ${childCard('Sam', 'Gentle · every 60 minutes',
        { fill: P.pondBlueSoft, ring: P.pondBlue }, ['2', '1', '0', '4'], 2)}

      ${listGroup(col, appearance, {
        rows: [
          listRow(col, {
            icon: iconTile(dark ? alpha(P.hopGreen, .24) : P.hopGreenSoft, EXTRA.plus(col.brandAction, 16), { size: 29, radius: 8 }),
            label: `<span style="color:${col.brandAction}">Add a child</span>`, accessory: '', last: true,
          }),
        ],
        footer: 'Every child gets their own pond, stars and schedule. Nothing is shared between them, and switching child is one tap from Home.',
      })}

      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.l}px;padding:14px 15px;
        display:flex;gap:13px;align-items:flex-start;box-shadow:${elevation(appearance, 'resting')}">
        ${iconTile(dark ? alpha(P.sunshine, .22) : P.sunshineSoft, MARK.star(dark ? P.sunshine : P.sunshineDeep, 17), { size: 32, radius: 10 })}
        <div style="flex:1">
          <div style="display:flex;align-items:center;gap:8px">
            <span style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15px">HopPotty Family</span>
            <span style="padding:2px 8px;border-radius:8px;background:${dark ? alpha(P.hopGreen, .2) : P.hopGreenSoft};
              ${type('parentFootnote', { color: dark ? P.hopGreenLight : P.hopGreenInk, weight: 'semibold' })};font-size:10.5px">Unlocked</span>
          </div>
          <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:3px;line-height:1.42">
            One purchase, already made. Every child you add is covered.</div>
        </div>
      </div>

      <div style="flex:1"></div>
    </div>
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

// ---------------------------------------------------------------------------
// 36 — HopPotty Family
// ---------------------------------------------------------------------------

/**
 * One purchase, one price, no pressure.
 *
 * There is no countdown, no expiring discount, no pre-ticked anything and no
 * guilt-worded dismissal — `PurchaseService` has no API for any of them. Restore
 * is a full-width control with a plain word on it, beside the buy button rather
 * than hidden under the footer.
 *
 * The price shown is the US storefront's. In the app it is `Product.displayPrice`
 * and is never written down in code.
 */
function paywallFamily(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const soft = (hex) => (dark ? alpha(hex, 0.22) : mix(hex, '#FFFFFF', 0.78));

  const feature = (glyph, tint, hue, title, body) => `
    <div style="display:flex;gap:13px;align-items:flex-start">
      ${iconTile(soft(hue), glyph(tint, 18), { size: 34, radius: 11 })}
      <div style="flex:1;min-width:0">
        <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15.5px">${title}</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:13.5px;margin-top:2px;line-height:1.38">${body}</div>
      </div>
    </div>`;

  return `
  <div style="display:flex;flex-direction:column;height:${H}px;background:${col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}
    ${sheetBar(col, 'HopPotty Family', { leading: 'Done' })}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 ${PAGE}px 6px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:center;gap:14px;background:${dark ? alpha(P.hopGreen, .13) : P.hopGreenSoft};
        border-radius:${T.radius.xl}px;padding:12px 16px">
        ${avatarDisc(44, { fill: '#FFFFFF', ring: P.hopGreenLight, ringWidth: 2 })}
        <div style="flex:1">
          <div style="${type('parentTitle', { color: col.textPrimary })};font-size:19px">One purchase.</div>
          <div style="${type('parentTitle', { color: dark ? P.hopGreenLight : P.hopGreenInk })};font-size:19px">Every feature, for good.</div>
        </div>
      </div>

      <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:12px;padding-top:16px">
        ${feature(EXTRA.people, dark ? P.hopGreenLight : P.hopGreenInk, P.hopGreen, 'More than one child',
          'Give each child their own pond, stars and schedule.')}
        ${feature(EXTRA.pond, col.eventPee, P.pondBlue, 'The whole pond',
          'Every decoration Hop can unlock, across all three ponds.')}
        ${feature(MARK.clock, dark ? P.lavender : P.lavenderDeep, P.lavender, 'Detailed patterns',
          'Longer windows and time-of-day comparisons.')}
        ${feature(MARK.check, dark ? P.sunshine : P.sunshineDeep, P.sunshine, 'Custom routines',
          'Choose the steps and how long each one lasts.')}
        ${feature(EXTRA.export, col.eventPoop, P.peachPop, 'Export your data',
          'Take a copy of the timeline with you.')}
      </div>

      <div style="flex:1;min-height:8px"></div>

      <div style="flex:0 0 auto;background:${col.surfaceSunken};border-radius:${T.radius.l}px;padding:11px 15px;
        border:1px solid ${col.divider}">
        ${[
          'One purchase, not a subscription. The price is the price.',
          'Shared with everyone in your Family Sharing group.',
          'No ads, no analytics, no tracking — in either version.',
        ].map((line, i) => `<div style="display:flex;gap:10px;align-items:flex-start;${i ? 'margin-top:7px' : ''}">
          ${MARK.check(col.success, 15)}
          <div style="flex:1;${type('parentCaption', { color: col.textSecondary })};font-size:12.5px;line-height:1.35">${line}</div>
        </div>`).join('')}
      </div>

      <div style="height:12px;flex:0 0 auto"></div>

      <div style="flex:0 0 auto">
        <div style="text-align:center;${type('parentTitle', { color: col.textPrimary })};font-size:22px">$19.99 once</div>
        <div style="margin-top:12px">${ctaButton(col, appearance, 'Unlock HopPotty')}</div>
        <div style="margin-top:9px">${secondaryButton(col, 'Restore purchase', { height: 50 })}</div>
        <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.42;
          text-align:center;padding:12px 2px 0">
          The free version keeps one child, the full routine and every reminder. Nothing your child earned is ever behind the purchase.</div>
      </div>
    </div>
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

// ---------------------------------------------------------------------------
// 37 — the grown-up gate
// ---------------------------------------------------------------------------

/**
 * Hold, then a sum.
 *
 * Either half alone is beatable by the person it is meant to stop, which is why
 * the screen shows both: the ring that has just been held, and the arithmetic
 * that needs an adult. It is not a security boundary and the screen never
 * pretends otherwise.
 */
function parentGate(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const KEY_W = 111, KEY_H = 46, KEY_GAP = 8;

  const key = (label, { wide = false, faint = false } = {}) => `
    <div style="width:${KEY_W}px;height:${KEY_H}px;border-radius:6px;display:grid;place-items:center;
      background:${faint ? 'transparent' : col.surface};
      ${faint ? '' : `box-shadow:0 1px 0 ${alpha(col.shadow, dark ? .5 : .22)};`}
      ${type('parentTitle', { color: col.textPrimary })};font-size:${wide ? 21 : 24}px;font-weight:400">${label}</div>`;

  const del = `<svg viewBox="0 0 24 24" width="24" height="17" fill="none" stroke="${col.textPrimary}" stroke-width="1.6"
    stroke-linecap="round"><path d="M8.4 4.6h11.2a1.6 1.6 0 0 1 1.6 1.6v11.6a1.6 1.6 0 0 1-1.6 1.6H8.4L2.4 12z"/><path d="M11.6 9.2 16.8 14.8M16.8 9.2 11.6 14.8"/></svg>`;

  const sheet = `
    ${sheetBar(col, 'Grown-ups only', { leading: 'Cancel' })}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 22px 0;overflow:hidden">

      <div style="flex:0 0 auto;${type('parentBody', { color: col.textSecondary })};font-size:16px;line-height:1.4">
        Hold the button, then answer the question.</div>

      <div style="flex:0 0 auto;display:flex;align-items:center;gap:14px;margin-top:18px;
        background:${col.surface};border-radius:${T.radius.l}px;padding:13px 15px;box-shadow:${elevation(appearance, 'resting')}">
        <div style="position:relative;width:52px;height:52px;flex:0 0 auto">
          <svg width="52" height="52" viewBox="0 0 52 52">
            <circle cx="26" cy="26" r="22" fill="none" stroke="${col.divider}" stroke-width="6"/>
            <circle cx="26" cy="26" r="22" fill="none" stroke="${col.brandAction}" stroke-width="6"
              stroke-linecap="round" stroke-dasharray="138.2 138.2" transform="rotate(-90 26 26)"/>
          </svg>
          <div style="position:absolute;inset:0;display:grid;place-items:center">
            ${MARK.check(col.brandAction, 20)}
          </div>
        </div>
        <div style="flex:1">
          <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15.5px">Held</div>
          <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;margin-top:1px">Press and hold, one second.</div>
        </div>
      </div>

      <div style="flex:0 0 auto;padding-top:22px">
        <div style="${type('parentTitle', { color: col.textPrimary })};font-size:24px">What is 13 plus 24?</div>
        <div style="margin-top:14px;height:56px;border-radius:${T.radius.m}px;background:${col.surface};
          border:1.5px solid ${col.brandAction};display:flex;align-items:center;padding:0 16px;
          box-shadow:${elevation(appearance, 'resting')}">
          <span style="${type('parentTitle', { color: col.textPrimary })};font-size:22px;font-variant-numeric:tabular-nums">3</span>
          <div style="width:2px;height:26px;background:${col.brandAction};border-radius:1px;margin-left:2px"></div>
        </div>
        <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.42;padding:9px 2px 0">
          Three tries, then Hop offers a different sum. There is no lock-out — Restore Screen Access must always be reachable.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;margin:0 -22px;padding:6px 6px 4px;background:${dark ? col.surfaceSunken : mix(P.sand200, P.sand100, .4)}">
        ${[['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']].map((row) => `
          <div style="display:flex;gap:${KEY_GAP}px;justify-content:center;margin-bottom:${KEY_GAP}px">
            ${row.map((n) => key(n)).join('')}
          </div>`).join('')}
        <div style="display:flex;gap:${KEY_GAP}px;justify-content:center;margin-bottom:${KEY_GAP}px">
          ${key('', { faint: true })}${key('0')}
          <div style="width:${KEY_W}px;height:${KEY_H}px;display:grid;place-items:center">${del}</div>
        </div>
      </div>
      ${homeIndicator(col.textPrimary)}
    </div>`;

  return sheetOver(appearance, settingsHub(appearance), sheet, { top: 236 });
}

// ---------------------------------------------------------------------------
// 38 — deleting a child's data
// ---------------------------------------------------------------------------

/**
 * The counts are read at the moment the sheet opens, and they are the whole
 * point: a caregiver approves a number, not a vibe. Cancel is the same width and
 * the same weight as Delete.
 */
function deleteDataConfirm(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const SHEET_TOP = 396;

  const line = (text) => `
    <div style="display:flex;gap:11px;align-items:flex-start;padding:3px 0">
      <svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="${col.textTertiary}" stroke-width="2"
        style="flex:0 0 auto;margin-top:1px"><circle cx="12" cy="12" r="9"/><path d="M8 12h8" stroke-linecap="round"/></svg>
      <div style="flex:1;${type('parentBody', { color: col.textSecondary })};font-size:16px;line-height:1.35">${text}</div>
    </div>`;

  const sheet = `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:6px 22px 0;overflow:hidden">
      <div style="flex:0 0 auto;${type('parentTitle', { color: col.textPrimary })};font-size:22px">Delete Maya's data?</div>

      <div style="flex:0 0 auto;padding-top:12px">
        ${line('47 logged potty events will be removed.')}
        ${line('31 earned stars will be removed.')}
        ${line('6 pond decorations will be removed.')}
      </div>

      <div style="flex:0 0 auto;${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};
        font-size:17px;padding-top:12px">This cannot be undone.</div>

      <div style="flex:0 0 auto;display:flex;gap:11px;align-items:flex-start;margin-top:14px;
        background:${col.surfaceSunken};border-radius:${T.radius.l}px;padding:12px 14px;border:1px solid ${col.divider}">
        ${iconTile(dark ? alpha('#FFFFFF', .08) : '#FFFFFF', MARK.lock(col.textTertiary, 15), { size: 28, radius: 9 })}
        <div style="flex:1;${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.42">
          Every event, star and note lives on your device. Deleting removes it here, right away, and there is no copy anywhere else.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;padding-bottom:4px">
        <div style="height:52px;border-radius:26px;background:${col.eventPoop};display:grid;place-items:center;
          box-shadow:${elevation(appearance, 'raised')};
          ${type('parentHeadline', { color: '#FFFFFF', weight: 'semibold' })};font-size:17px">Delete</div>
        <div style="height:10px"></div>
        ${secondaryButton(col, 'Cancel')}
      </div>
    </div>
    ${homeIndicator(col.textPrimary)}`;

  return sheetOver(appearance, settingsHub(appearance), sheet, { top: SHEET_TOP });
}

// ---------------------------------------------------------------------------
// 39 — Screen Time permission was turned off
// ---------------------------------------------------------------------------

/**
 * Authorization can end without anyone in the family doing anything wrong: a
 * child's account graduating to an adult one, a change in iOS Settings, or
 * another parental-controls app taking over (`ScreenTimeArchitecture.md` §12.8).
 *
 * So the screen states what stopped, states that the apps came straight back,
 * says what still works, and offers the one action that can change it. It does
 * not scold, and it does not imply the child is being kept from anything.
 */
function accessRestored(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const warnSoft = dark ? alpha(P.sunshine, .18) : P.sunshineSoft;
  const warnInk = dark ? P.sunshine : P.sunshineDeep;

  const still = (glyph, text, last) => `
    <div style="display:flex;gap:12px;align-items:flex-start;padding:11px 0;
      ${last ? '' : `box-shadow:inset 0 -1px 0 ${col.divider};`}">
      ${glyph}
      <div style="flex:1;${type('parentCallout', { color: col.textSecondary })};font-size:14px;line-height:1.4">${text}</div>
    </div>`;

  return phone(appearance, `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 24px 8px;overflow:hidden">
      ${backRow(col)}

      <div style="flex:0 0 auto;display:flex;justify-content:center;padding-top:6px">
        <div style="position:relative;width:150px;height:150px">
          <div style="position:absolute;inset:0;border-radius:75px;background:${dark ? alpha(P.sunshine, .1) : mix(P.sunshineSoft, P.cloud, .3)}"></div>
          <div style="position:absolute;left:50%;top:6px;transform:translateX(-50%)">
            ${svg('Art/character/hop-wait.svg', { width: 150 })}
          </div>
          <div style="position:absolute;right:-2px;top:6px;width:38px;height:38px;border-radius:19px;
            background:${warnSoft};border:2px solid ${col.backgroundPrimary};display:grid;place-items:center">
            ${EXTRA.warning(warnInk, 20)}
          </div>
        </div>
      </div>

      <div style="flex:0 0 auto;text-align:center;padding-top:10px">
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:28px;line-height:1.16">Screen Time permission<br>was turned off</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:15px;margin-top:10px;line-height:1.45">
          HopPotty needs Screen Time permission to pause apps. You can grant it again in Settings.</div>
      </div>

      <div style="flex:0 0 auto;margin-top:18px;background:${col.surface};border-radius:${T.radius.l}px;
        padding:2px 15px 4px;box-shadow:${elevation(appearance, 'resting')}">
        ${still(MARK.check(col.success, 18), 'Screen access is back. Any pause that was up has already ended.')}
        ${still(MARK.bell(dark ? P.lavender : P.lavenderDeep, 17), 'Hop still checks in on your schedule. Reminders keep working without it.')}
        ${still(MARK.star(col.celebration, 17), 'Stars and pond decorations stay exactly as they are.', true)}
      </div>

      <div style="flex:0 0 auto;margin-top:12px;display:flex;gap:11px;align-items:flex-start;padding:0 4px">
        ${EXTRA.info(col.textTertiary, 15)}
        <div style="flex:1;${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.42">
          iOS can turn this off on its own — when a child's account changes, or when another parental-controls app takes over.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto">
        ${ctaButton(col, appearance, 'Open Settings')}
        <div style="height:10px"></div>
        ${secondaryButton(col, 'Not now')}
      </div>
    </div>`);
}

// ---------------------------------------------------------------------------
// 40 — Progress, day one
// ---------------------------------------------------------------------------

/**
 * The empty state a family sees on the first day.
 *
 * Nothing here is phrased as a shortfall. An empty period is a fact about the
 * period, not about the child — so the copy says the entries are not there yet
 * and stops, and the pattern cards say plainly that they need more days rather
 * than showing a chart of one point.
 */
function progressEmpty(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const TINT = tints(appearance);

  const zeroRow = (glyph, tint, soft, text, label, last) => `
    <div style="display:flex;align-items:center;gap:12px;padding:8px 0;
      ${last ? '' : `box-shadow:inset 0 -1px 0 ${col.divider};`}">
      <div style="width:30px;height:30px;border-radius:15px;background:${soft};display:grid;place-items:center;flex:0 0 auto">${glyph(tint, 16)}</div>
      <div style="flex:1;${type('parentCallout', { color: col.textSecondary })};font-size:14.5px">${text}</div>
      <span style="${type('parentFootnote', { color: col.textTertiary })};font-size:11.5px;flex:0 0 auto">${label}</span>
    </div>`;

  return `
  <div style="display:flex;flex-direction:column;height:${H}px;background:${col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:9px;padding:0 ${PAGE}px 8px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:flex-end;justify-content:space-between">
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px">Progress</div>
        <div style="display:flex;align-items:center;gap:7px;height:32px;padding:0 12px 0 5px;border-radius:16px;
          background:${col.surface};box-shadow:${elevation(appearance, 'resting')}">
          ${avatarDisc(24, { fill: P.hopGreenSoft, ring: null })}
          <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:12.5px">Maya</span>
        </div>
      </div>

      <div style="flex:0 0 auto">${segmented(col, appearance, ['Day', 'Week', 'Month'], 0)}</div>

      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.xl}px;padding:16px 18px 16px;
        box-shadow:${elevation(appearance, 'resting')};text-align:center">
        <div style="display:flex;justify-content:center">${svg('Art/character/hop-wait.svg', { width: 100 })}</div>
        <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:17px;margin-top:6px">
          Nothing logged in this period</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:14px;margin-top:6px;line-height:1.42;padding:0 6px">
          Entries appear here as you and your child log them. Nothing is missing — the period simply has no entries.</div>
        <div style="margin-top:14px;height:44px;border-radius:22px;background:${col.brandAction};display:grid;place-items:center;
          ${type('parentHeadline', { color: col.textOnBrand, weight: 'semibold' })};font-size:16px">Log a visit</div>
      </div>

      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.xl}px;padding:14px 16px 13px;
        box-shadow:${elevation(appearance, 'resting')}">
        <div style="${type('parentHeadline', { color: col.textSecondary, weight: 'semibold' })};font-size:14.5px">Today so far</div>
        <div style="margin-top:4px">
          ${zeroRow(MARK.ring, TINT.tried.tint, TINT.tried.soft, 'No potty visits logged yet', 'Visits')}
          ${zeroRow(MARK.star, TINT.star.tint, TINT.star.soft, 'None yet today', 'Stars', true)}
        </div>
      </div>

      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.xl}px;padding:15px 16px 13px;
        box-shadow:${elevation(appearance, 'resting')}">
        <div style="display:flex;align-items:center;gap:10px">
          <div style="width:28px;height:28px;border-radius:9px;background:${TINT.pee.soft};display:grid;place-items:center;flex:0 0 auto">${MARK.chart(TINT.pee.tint, 16)}</div>
          <span style="${type('parentHeadline', { color: col.textSecondary, weight: 'semibold' })};font-size:14.5px">Patterns</span>
        </div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:14px;margin-top:9px;line-height:1.42">
          A few more days of logging will fill this in. Patterns need several days before they describe anything.</div>
        <div style="margin-top:10px">${patternLabel(col)}</div>
      </div>

      <div style="flex:1"></div>
    </div>
    ${tabBar(col, 'Progress')}
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

// ---------------------------------------------------------------------------
// 41 — a quick reminder
// ---------------------------------------------------------------------------

/**
 * One timer, once.
 *
 * A Quick Reminder never shields an app, never repeats, never snoozes and never
 * touches the schedule (`QuickReminder.swift`). The sheet says so, and when the
 * schedule already has a pause near the chosen time it mentions that — advisory
 * only, because nothing here is allowed to move a pause or refuse a reminder.
 */
function quickReminderSheet(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const SHEET_TOP = 288;

  const chip = (label, on) => `
    <div style="flex:1;height:44px;border-radius:22px;display:grid;place-items:center;
      background:${on ? col.brandAction : col.surface};
      border:1.5px solid ${on ? col.brandAction : col.divider};
      ${type('parentCallout', { color: on ? col.textOnBrand : col.textSecondary, weight: on ? 'semibold' : 'medium' })};font-size:14px">${label}</div>`;

  const sheet = `
    <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:2px 20px 0;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:flex-start;gap:12px">
        <div style="flex:1">
          <div style="${type('parentTitle', { color: col.textPrimary })};font-size:22px">Quick reminder</div>
          <div style="${type('parentCallout', { color: col.textSecondary })};font-size:14px;margin-top:3px;line-height:1.4">
            One reminder, once. Nothing is paused and your schedule is untouched.</div>
        </div>
        <div style="width:30px;height:30px;border-radius:15px;background:${col.surfaceSunken};display:grid;place-items:center;flex:0 0 auto">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="${col.textTertiary}" stroke-width="2.8" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>
        </div>
      </div>

      <div style="flex:0 0 auto;display:flex;gap:9px;padding-top:16px">
        ${chip('In 15 minutes')}${chip('In 30 minutes', true)}
      </div>
      <div style="flex:0 0 auto;display:flex;gap:9px;padding-top:9px">
        ${chip('In 1 hour')}${chip('Pick a time')}
      </div>

      <div style="flex:0 0 auto;margin-top:14px;background:${col.surface};border-radius:${T.radius.l}px;overflow:hidden;
        box-shadow:${elevation(appearance, 'resting')}">
        ${listRow(col, {
          icon: iconTile(dark ? alpha(P.hopGreen, .22) : P.hopGreenSoft, MARK.clock(dark ? P.hopGreenLight : P.hopGreenInk, 16), { size: 29, radius: 8 }),
          label: 'Remind me at',
          accessory: `<div style="height:32px;padding:0 11px;border-radius:8px;background:${col.surfaceSunken};display:flex;align-items:center">
            <span style="${type('parentBody', { color: col.textPrimary })};font-size:16px;font-variant-numeric:tabular-nums">2:15 PM</span></div>`,
          minHeight: 50,
        })}
        ${listRow(col, {
          icon: avatarDisc(29, { fill: P.hopGreenSoft, ring: P.hopGreenLight }),
          label: 'For', value: 'Maya', chevron: true, minHeight: 50, last: true,
        })}
      </div>

      <div style="flex:0 0 auto;padding-top:16px">
        <div style="${type('parentFootnote', { color: col.textTertiary, weight: 'semibold' })};font-size:11.5px;
          letter-spacing:.5px;text-transform:uppercase">Why, if you like</div>
        <div style="display:flex;gap:8px;margin-top:9px">
          ${['After a drink', 'Before leaving', 'Before a nap'].map((label, i) => `
            <div style="flex:1;height:38px;border-radius:19px;display:grid;place-items:center;
              background:${i === 0 ? (dark ? alpha(P.pondBlue, .22) : P.pondBlueSoft) : col.surface};
              border:1.5px solid ${i === 0 ? (dark ? alpha(P.pondBlue, .5) : P.pondBlue) : col.divider};
              ${type('parentCaption', { color: i === 0 ? (dark ? P.pondBlueLight : P.pondBlueDeep) : col.textSecondary, weight: i === 0 ? 'semibold' : 'medium' })};font-size:12.5px">${label}</div>`).join('')}
        </div>
      </div>

      <div style="flex:0 0 auto;display:flex;gap:11px;align-items:flex-start;margin-top:14px;padding:0 4px">
        ${MARK.bell(col.textTertiary, 15)}
        <div style="flex:1;${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;line-height:1.42">
          A Potty Pause is already coming at about 2:20 PM. You can set this anyway.</div>
      </div>

      <div style="flex:1"></div>

      <div style="flex:0 0 auto;padding-bottom:4px">
        ${ctaButton(col, appearance, 'Set reminder')}
      </div>
    </div>
    ${homeIndicator(col.textPrimary)}`;

  return sheetOver(appearance, parentHome(appearance), sheet, { top: SHEET_TOP });
}

// ---------------------------------------------------------------------------
// 42 / 43 — the surfaces outside the app
// ---------------------------------------------------------------------------

/** A wallpaper that belongs to the palette without pretending to be a photo. */
function wallpaper(w, h, { night = false } = {}) {
  const id = 'wp' + Math.random().toString(36).slice(2, 7);
  const top = night ? mix(P.midnight, P.lavenderDeep, 0.28) : mix(P.pondBlueSoft, P.pondBlueLight, 0.5);
  const bottom = night ? P.midnight : mix(P.hopGreenSoft, P.cloud, 0.35);
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="display:block">
    <defs>
      <linearGradient id="${id}g" x1="0" y1="0" x2="0.2" y2="1">
        <stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/>
      </linearGradient>
      <radialGradient id="${id}a" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${night ? P.lavender : P.sunshine}" stop-opacity="${night ? 0.3 : 0.42}"/>
        <stop offset="1" stop-color="${night ? P.lavender : P.sunshine}" stop-opacity="0"/>
      </radialGradient>
      <radialGradient id="${id}b" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${night ? P.pondBlue : P.hopGreen}" stop-opacity="${night ? 0.28 : 0.34}"/>
        <stop offset="1" stop-color="${night ? P.pondBlue : P.hopGreen}" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <rect width="${w}" height="${h}" fill="url(#${id}g)"/>
    <circle cx="${w * 0.78}" cy="${h * 0.16}" r="${w * 0.46}" fill="url(#${id}a)"/>
    <circle cx="${w * 0.14}" cy="${h * 0.82}" r="${w * 0.52}" fill="url(#${id}b)"/>
  </svg>`;
}

/** The label that says which of iOS's places a band is showing. */
function bandLabel(text, { dark = false, top = 12 } = {}) {
  const ink = dark ? '#FFFFFF' : P.midnight;
  return `<div style="position:absolute;left:14px;top:${top}px;z-index:3;height:24px;padding:0 11px;border-radius:12px;
    background:${alpha(dark ? '#FFFFFF' : P.midnight, dark ? .16 : .1)};display:flex;align-items:center;
    ${type('parentFootnote', { color: alpha(ink, .82), weight: 'semibold' })};font-size:10.5px;letter-spacing:.7px;
    text-transform:uppercase">${text}</div>`;
}

/** A HopPotty widget: a surface card at the system's corner radius. */
function widgetCard(appearance, w, h, inner, { pad = 14 } = {}) {
  const col = c(appearance);
  return `<div style="width:${w}px;height:${h}px;border-radius:${T.radius.xl}px;background:${col.surface};
    padding:${pad}px;overflow:hidden;box-shadow:0 6px 18px ${alpha(P.midnight, .16)};display:flex;flex-direction:column">${inner}</div>`;
}

/** A neutral app icon. Never a real logo, never a real name. */
function appIcon(size, hue) {
  return `<div style="width:${size}px;height:${size}px;border-radius:${Math.round(size * 0.225)}px;
    background:${hue};border:1px solid ${alpha('#FFFFFF', .5)};
    box-shadow:0 4px 10px ${alpha(P.midnight, .16)}"></div>`;
}

/** Pale tints for the placeholder icons, so a home screen looks like one. */
const ICON_TINTS = [P.pondBlueSoft, P.sunshineSoft, P.lavenderSoft, P.peachSoft,
  P.hopGreenSoft, P.sand100, P.pondBlueSoft, P.sunshineSoft];

/**
 * 42 — the widgets.
 *
 * Two places, one screen: the Home Screen widgets at their real sizes above, the
 * lock-screen accessories below. Everything shown is something the app already
 * knows — the next pause, the mode, the interval, the child's name and their
 * star count. There is no streak, no "days in a row", and nothing a widget would
 * have to invent.
 */
function widgets(appearance = 'light') {
  const col = c(appearance);
  const BAND_A = 526;
  const BAND_B = H - BAND_A - 10;
  const M = 24;
  const smallW = 158, mediumW = W - M * 2;

  const smallWidget = widgetCard(appearance, smallW, smallW, `
    <div style="display:flex;align-items:center;gap:6px;flex:0 0 auto">
      ${avatarDisc(24, { fill: P.hopGreenSoft, ring: null })}
      <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:11.5px">Maya</span>
      <div style="flex:1"></div>
      ${MARK.star(col.celebration, 13)}
      <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:11.5px;font-variant-numeric:tabular-nums">13</span>
    </div>
    <div style="flex:1"></div>
    <div style="${type('parentFootnote', { color: col.textTertiary, weight: 'semibold' })};font-size:10px;
      letter-spacing:.6px;text-transform:uppercase;flex:0 0 auto">Next Potty Pause</div>
    <div style="${type('metric', { color: col.textPrimary })};font-size:30px;margin-top:2px;flex:0 0 auto">in 24 min</div>
    <div style="display:inline-flex;align-items:center;gap:5px;margin-top:7px;padding:3px 9px;border-radius:20px;
      background:${P.hopGreenSoft};align-self:flex-start;flex:0 0 auto">
      <div style="width:6px;height:6px;border-radius:3px;background:${P.hopGreenDeep}"></div>
      <span style="${type('parentFootnote', { color: P.hopGreenInk, weight: 'semibold' })};font-size:10.5px">Guided routine</span>
    </div>`);

  const mediumWidget = widgetCard(appearance, mediumW, smallW, `
    <div style="display:flex;height:100%;gap:14px">
      <div style="width:104px;flex:0 0 auto;border-radius:${T.radius.l}px;background:${mix(P.hopGreenSoft, P.cloud, .25)};
        position:relative;overflow:hidden">
        <div style="position:absolute;left:0;right:0;bottom:0;height:34px;background:${alpha(P.hopGreenLight, .55)}"></div>
        <div style="position:absolute;left:50%;bottom:2px;transform:translateX(-50%)">
          ${svg('Art/character/hop-sit.svg', { width: 92 })}
        </div>
      </div>
      <div style="flex:1;display:flex;flex-direction:column;min-width:0">
        <div style="display:flex;align-items:center;gap:7px;flex:0 0 auto">
          ${avatarDisc(22, { fill: P.hopGreenSoft, ring: null })}
          <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:11.5px">Maya</span>
          <div style="flex:1"></div>
          ${MARK.star(col.celebration, 13)}
          <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:11.5px;font-variant-numeric:tabular-nums">13</span>
        </div>
        <div style="flex:1"></div>
        <div style="${type('parentFootnote', { color: col.textTertiary, weight: 'semibold' })};font-size:10px;
          letter-spacing:.6px;text-transform:uppercase;flex:0 0 auto">Next Potty Pause</div>
        <div style="${type('metric', { color: col.textPrimary })};font-size:32px;margin-top:2px;flex:0 0 auto">in 24 min</div>
        <div style="${type('parentCaption', { color: col.textSecondary })};font-size:12.5px;margin-top:5px;flex:0 0 auto">
          Guided routine · every 45 minutes</div>
        <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12px;margin-top:2px;flex:0 0 auto">
          Quiet from 12:30 PM</div>
      </div>
    </div>`);

  /** Accessory widgets render monochrome over the wallpaper. Drawn that way. */
  const circular = (inner) => `<div style="width:72px;height:72px;border-radius:36px;
    background:${alpha('#FFFFFF', .22)};display:grid;place-items:center;position:relative">${inner}</div>`;

  const lockCircular = circular(`
    <svg width="72" height="72" viewBox="0 0 72 72" style="position:absolute;inset:0">
      <circle cx="36" cy="36" r="32" fill="none" stroke="${alpha('#FFFFFF', .3)}" stroke-width="5"/>
      <circle cx="36" cy="36" r="32" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"
        stroke-dasharray="94 201" transform="rotate(-90 36 36)"/>
    </svg>
    <div style="position:relative;text-align:center">
      <div style="${type('parentFootnote', { color: '#FFFFFF', weight: 'bold' })};font-size:17px;line-height:1;font-variant-numeric:tabular-nums">24</div>
      <div style="${type('parentFootnote', { color: alpha('#FFFFFF', .8) })};font-size:9.5px;line-height:1.2;margin-top:1px">min</div>
    </div>`);

  const lockStars = circular(`
    <div style="text-align:center;display:flex;flex-direction:column;align-items:center;gap:1px">
      ${MARK.star('#FFFFFF', 17)}
      <div style="${type('parentFootnote', { color: '#FFFFFF', weight: 'bold' })};font-size:15px;line-height:1.1;font-variant-numeric:tabular-nums">13</div>
    </div>`);

  const lockRectangular = `
    <div style="width:172px;height:72px;border-radius:${T.radius.m}px;background:${alpha('#FFFFFF', .16)};
      padding:9px 12px;display:flex;flex-direction:column;justify-content:center">
      <div style="display:flex;align-items:center;gap:6px">
        ${MARK.clock(alpha('#FFFFFF', .85), 12)}
        <span style="${type('parentFootnote', { color: alpha('#FFFFFF', .85), weight: 'semibold' })};font-size:10px;
          letter-spacing:.6px;text-transform:uppercase">Next Potty Pause</span>
      </div>
      <div style="${type('parentTitle', { color: '#FFFFFF' })};font-size:20px;margin-top:3px">in 24 min</div>
      <div style="${type('parentFootnote', { color: alpha('#FFFFFF', .75) })};font-size:11px;margin-top:1px">Maya · Guided routine</div>
    </div>`;

  return `
  <div style="position:relative;width:${W}px;height:${H}px;overflow:hidden;background:${P.midnight}">

    <!-- Home Screen -->
    <div style="position:absolute;left:0;top:0;width:${W}px;height:${BAND_A}px;overflow:hidden">
      <div style="position:absolute;inset:0">${wallpaper(W, BAND_A)}</div>
      ${bandLabel('Home Screen', { top: 62 })}
      <div style="position:relative;display:flex;flex-direction:column;height:100%">
        ${statusBar(P.midnight)}
        <div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:16px;padding:14px ${M}px 0">
          ${mediumWidget}
          <div style="display:flex;gap:16px;width:100%">
            ${smallWidget}
            <div style="flex:1;display:flex;flex-direction:column;justify-content:space-between;padding:4px 0">
              <div style="display:flex;justify-content:space-between">
                ${appIcon(60, ICON_TINTS[0])}${appIcon(60, ICON_TINTS[1])}
              </div>
              <div style="display:flex;justify-content:space-between">
                ${appIcon(60, ICON_TINTS[2])}${appIcon(60, ICON_TINTS[3])}
              </div>
            </div>
          </div>
        </div>
        <div style="flex:0 0 auto;display:flex;justify-content:center;gap:7px;padding-bottom:10px">
          <div style="width:7px;height:7px;border-radius:4px;background:${alpha(P.midnight, .55)}"></div>
          <div style="width:7px;height:7px;border-radius:4px;background:${alpha(P.midnight, .22)}"></div>
        </div>
        <div style="flex:0 0 auto;margin:0 ${M - 8}px 12px;height:78px;border-radius:${T.radius.xl}px;
          background:${alpha('#FFFFFF', .34)};display:flex;align-items:center;justify-content:space-around;padding:0 12px">
          ${appIcon(58, ICON_TINTS[4])}${appIcon(58, ICON_TINTS[5])}
          ${appIcon(58, ICON_TINTS[6])}${appIcon(58, ICON_TINTS[7])}
        </div>
      </div>
    </div>

    <!-- Lock Screen -->
    <div style="position:absolute;left:0;top:${BAND_A + 10}px;width:${W}px;height:${BAND_B}px;overflow:hidden">
      <div style="position:absolute;inset:0">${wallpaper(W, BAND_B, { night: true })}</div>
      ${bandLabel('Lock Screen', { dark: true })}
      <div style="position:relative;display:flex;flex-direction:column;height:100%;padding:0 ${M}px">
        <div style="height:44px"></div>
        <div style="flex:0 0 auto;text-align:center">
          <div style="${type('parentCallout', { color: alpha('#FFFFFF', .82) })};font-size:14px">Tuesday, 8 September</div>
          <div style="${type('timerHero', { color: '#FFFFFF' })};font-size:62px;line-height:1.05;font-variant-numeric:tabular-nums">9:41</div>
        </div>
        <div style="flex:0 0 auto;display:flex;align-items:center;justify-content:center;gap:14px;margin-top:14px">
          ${lockCircular}${lockRectangular}${lockStars}
        </div>
        <div style="flex:1"></div>
        ${homeIndicator('#FFFFFF')}
      </div>
    </div>
  </div>`;
}

/**
 * 43 — the Live Activity.
 *
 * A pause is running. The activity says which routine step the child is on and
 * that Hop is waiting — and shows no countdown, because a visible clock on a
 * three-year-old's bathroom trip is pressure, and because the pause ending is
 * the app's job rather than the child's.
 */
function liveActivity(appearance = 'light') {
  const col = c(appearance);
  const BAND_A = 274;
  const BAND_B = H - BAND_A - 10;
  const M = 22;

  const stepChip = (label, glyph, on) => `
    <div style="display:flex;flex-direction:column;align-items:center;gap:5px;flex:1">
      <div style="width:36px;height:36px;border-radius:18px;display:grid;place-items:center;
        background:${on ? P.hopGreenDeep : alpha('#FFFFFF', .12)}">${glyph(on ? '#FFFFFF' : alpha('#FFFFFF', .55), 19)}</div>
      <span style="${type('parentFootnote', { color: on ? '#FFFFFF' : alpha('#FFFFFF', .55), weight: on ? 'semibold' : 'medium' })};font-size:10px">${label}</span>
    </div>`;

  const flush = (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M19.4 12a7.4 7.4 0 1 1-2.2-5.2"/><path d="M19.8 3.6v5h-5"/><circle cx="12" cy="12" r="2.2" fill="${f}" stroke="none"/></svg>`;

  // The expanded Dynamic Island: leading, trailing, centre, bottom.
  const island = `
    <div style="width:${W - M * 2}px;border-radius:${T.radius.xxl}px;background:#000000;padding:14px 18px 16px;
      box-shadow:0 10px 30px ${alpha('#000000', .5)}">
      <div style="display:flex;align-items:center;gap:12px">
        ${avatarDisc(38, { fill: alpha(P.hopGreen, .22), ring: alpha(P.hopGreenLight, .6), ringWidth: 1.5 })}
        <div style="flex:1;min-width:0">
          <div style="${type('parentHeadline', { color: '#FFFFFF', weight: 'semibold' })};font-size:15.5px">Potty Pause</div>
          <div style="${type('parentCaption', { color: alpha('#FFFFFF', .66) })};font-size:12.5px;margin-top:1px">Hop is waiting</div>
        </div>
        <div style="text-align:right;flex:0 0 auto">
          <div style="${type('parentFootnote', { color: alpha('#FFFFFF', .66), weight: 'semibold' })};font-size:10.5px;
            letter-spacing:.5px;text-transform:uppercase">Step 2 of 5</div>
          <div style="${type('parentTitle', { color: '#FFFFFF' })};font-size:17px;margin-top:1px">Wipe</div>
        </div>
      </div>
      <div style="display:flex;gap:4px;margin-top:14px">
        ${stepChip('Try', MARK.ring, false)}
        ${stepChip('Wipe', EXTRA.roll, true)}
        ${stepChip('Flush', flush, false)}
        ${stepChip('Wash', MARK.droplets, false)}
        ${stepChip('High five', MARK.star, false)}
      </div>
      <div style="${type('parentCaption', { color: alpha('#FFFFFF', .62) })};font-size:12.5px;text-align:center;margin-top:12px">
        The pause ends on its own. Maya's game comes back.</div>
    </div>`;

  const activityCard = `
    <div style="width:${W - M * 2}px;border-radius:${T.radius.xl}px;background:${alpha('#FFFFFF', .16)};
      padding:14px 16px 15px">
      <div style="display:flex;align-items:center;gap:11px">
        ${avatarDisc(34, { fill: alpha(P.hopGreen, .3), ring: alpha(P.hopGreenLight, .6), ringWidth: 1.5 })}
        <div style="flex:1;min-width:0">
          <div style="${type('parentHeadline', { color: '#FFFFFF', weight: 'semibold' })};font-size:15px">Potty Pause · Hop is waiting</div>
          <div style="${type('parentCaption', { color: alpha('#FFFFFF', .72) })};font-size:12.5px;margin-top:1px">Maya · Step 2 of 5 · Wipe</div>
        </div>
        <div style="width:28px;height:28px;border-radius:14px;background:${alpha('#FFFFFF', .18)};display:grid;place-items:center;flex:0 0 auto">
          ${EXTRA.shield(alpha('#FFFFFF', .9), 15)}
        </div>
      </div>
      <div style="margin-top:14px">
        ${stepDots(5, 1, { done: alpha('#FFFFFF', .85), todo: alpha('#FFFFFF', .3), now: '#FFFFFF' })}
      </div>
      <div style="${type('parentCallout', { color: alpha('#FFFFFF', .8) })};font-size:13.5px;text-align:center;margin-top:14px">
        Your game comes back soon.</div>
    </div>`;

  return `
  <div style="position:relative;width:${W}px;height:${H}px;overflow:hidden;background:${P.midnight}">

    <!-- Dynamic Island, expanded -->
    <div style="position:absolute;left:0;top:0;width:${W}px;height:${BAND_A}px;overflow:hidden;
      background:${mix(P.midnight, '#000000', .45)}">
      ${bandLabel('Dynamic Island · expanded', { dark: true })}
      <div style="position:relative;display:flex;flex-direction:column;height:100%;align-items:center">
        <div style="height:46px;flex:0 0 auto"></div>
        ${island}
        <div style="flex:1"></div>
      </div>
    </div>

    <!-- Lock Screen -->
    <div style="position:absolute;left:0;top:${BAND_A + 10}px;width:${W}px;height:${BAND_B}px;overflow:hidden">
      <div style="position:absolute;inset:0">${wallpaper(W, BAND_B, { night: true })}</div>
      ${bandLabel('Lock Screen', { dark: true })}
      <div style="position:relative;display:flex;flex-direction:column;height:100%;align-items:center;padding:0 ${M}px">
        <div style="height:46px;flex:0 0 auto"></div>
        <div style="flex:0 0 auto;text-align:center">
          <div style="${type('parentCallout', { color: alpha('#FFFFFF', .82) })};font-size:14px">Tuesday, 8 September</div>
          <div style="${type('timerHero', { color: '#FFFFFF' })};font-size:66px;line-height:1.05;font-variant-numeric:tabular-nums">1:42</div>
        </div>
        <div style="flex:1"></div>
        ${activityCard}
        <div style="${type('parentCaption', { color: alpha('#FFFFFF', .62) })};font-size:12px;text-align:center;
          margin-top:16px;padding:0 10px;line-height:1.4">
          No countdown, on purpose. A visible clock reads as pressure to a small child, and the pause ends whether or not anyone is watching it.</div>
        <div style="height:26px;flex:0 0 auto"></div>
        ${homeIndicator('#FFFFFF')}
      </div>
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// 44 — Progress on iPad
// ---------------------------------------------------------------------------

const PAD = { w: 1024, h: 768, rail: 244 };

/** The split-view sidebar, with Progress selected. */
function sidebar(col, appearance, active) {
  const rows = [
    ['Home', `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><path d="M12 3.2 21 11h-2.4v8.2a1 1 0 0 1-1 1H14V15h-4v5.2H6.4a1 1 0 0 1-1-1V11H3z"/></svg>`],
    ['Progress', `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><rect x="3" y="12" width="4" height="8.5" rx="1.4"/><rect x="10" y="7" width="4" height="13.5" rx="1.4"/><rect x="17" y="3.5" width="4" height="17" rx="1.4"/></svg>`],
    ["Hop's pond", `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><ellipse cx="12" cy="13" rx="9" ry="6"/><path d="M12 13 L21 9.4 A9 6 0 0 0 18 7.4Z" fill="${col.backgroundSecondary}"/></svg>`],
    ['Settings', `<svg viewBox="0 0 24 24" width="21" height="21" fill="currentColor"><path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2zm8.4 3.6c0 .5 0 1-.1 1.5l2 1.6-2 3.4-2.4-1a7.6 7.6 0 0 1-2.5 1.5l-.4 2.5h-4l-.4-2.5a7.6 7.6 0 0 1-2.5-1.5l-2.4 1-2-3.4 2-1.6a8.6 8.6 0 0 1 0-3l-2-1.6 2-3.4 2.4 1a7.6 7.6 0 0 1 2.5-1.5L10 2h4l.4 2.5a7.6 7.6 0 0 1 2.5 1.5l2.4-1 2 3.4-2 1.6c.1.5.1 1 .1 1.5z"/></svg>`],
  ];
  return `<div style="position:absolute;left:0;top:0;bottom:0;width:${PAD.rail}px;background:${col.backgroundSecondary};
    border-right:1px solid ${col.divider};display:flex;flex-direction:column">
    ${statusBarPad(col.textSecondary)}
    <div style="padding:14px 18px 10px;display:flex;align-items:center;gap:11px">
      ${avatarDisc(38, { fill: P.hopGreenSoft, ring: P.hopGreenLight, ringWidth: 2 })}
      <div style="${type('parentTitle', { color: col.textPrimary })};font-size:20px">HopPotty</div>
    </div>
    <div style="padding:4px 12px;display:flex;flex-direction:column;gap:2px">
      ${rows.map(([label, icon]) => {
        const on = label === active;
        return `<div style="height:44px;border-radius:12px;display:flex;align-items:center;gap:12px;padding:0 12px;
          color:${on ? col.brandAction : col.textSecondary};
          ${on ? `background:${col.surface};box-shadow:${elevation(appearance, 'resting')};` : ''}">
          ${icon}<span style="${type('parentBody', { weight: on ? 'semibold' : 'medium' })};font-size:15.5px;
            color:${on ? col.textPrimary : col.textSecondary}">${label}</span>
        </div>`;
      }).join('')}
    </div>
    <div style="flex:1"></div>
    <div style="padding:0 16px 18px">
      <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12px;line-height:1.4">
        Patterns describe the week you logged. They are not advice.</div>
    </div>
  </div>`;
}

/**
 * Progress, laid out for the iPad the way Home is in 15.
 *
 * The extra width buys two things and nothing else: the week's chart gets room
 * to be read, and the two smaller observations sit beside it instead of below
 * the fold. Every card still carries the same hedge in the same words.
 */
function insightsPad(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const TINT = tints(appearance);
  const w = PAD.w - PAD.rail;      // 780
  const gutter = T.spacing.pageRegular, gap = 20;
  const colW = Math.round((w - gutter * 2 - gap) / 2);

  const cardBox = (inner, { pad = '18px 20px 16px' } = {}) => `
    <div style="background:${col.surface};border-radius:${T.radius.xl}px;padding:${pad};
      box-shadow:${elevation(appearance, 'resting')}">${inner}</div>`;

  const head = (label, glyph, tint, soft) => `
    <div style="display:flex;align-items:center;gap:10px">
      <div style="width:28px;height:28px;border-radius:9px;background:${soft};display:grid;place-items:center;flex:0 0 auto">${glyph(tint, 16)}</div>
      <span style="${type('parentHeadline', { color: col.textSecondary, weight: 'semibold' })};font-size:14.5px">${label}</span>
    </div>`;

  const dayShape = (values, peak) => `<div style="display:flex;align-items:flex-end;gap:5px;height:72px">
    ${values.map((v, i) => `<div style="flex:1;height:${Math.max(10, v * 72)}px;border-radius:3px;
      background:${i === peak ? col.eventTried : alpha(col.eventTried, dark ? .3 : .22)}"></div>`).join('')}
  </div>`;

  return `
  <div style="position:relative;width:${PAD.w}px;height:${PAD.h}px;overflow:hidden;background:${col.backgroundPrimary}">
    ${sidebar(col, appearance, 'Progress')}

    <div style="position:absolute;left:${PAD.rail}px;top:0;width:${w}px;height:${PAD.h}px;overflow:hidden;
      display:flex;flex-direction:column">
      <div style="height:24px;flex:0 0 auto"></div>

      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:8px ${gutter}px 20px;overflow:hidden">

        <div style="flex:0 0 auto;display:flex;align-items:center;justify-content:space-between">
          <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:32px">Progress</div>
          <div style="display:flex;align-items:center;gap:12px">
            <div style="width:210px">${segmented(col, appearance, ['Day', 'Week', 'Month'], 1)}</div>
            <div style="display:flex;align-items:center;gap:8px;height:34px;padding:0 13px 0 5px;border-radius:17px;
              background:${col.surface};box-shadow:${elevation(appearance, 'resting')}">
              ${avatarDisc(26, { fill: P.hopGreenSoft, ring: null })}
              <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};font-size:13px">Maya</span>
            </div>
          </div>
        </div>

        <div style="flex:0 0 auto;display:flex;gap:${gap}px;padding-top:16px;align-items:flex-start">

          <div style="width:${colW}px;flex:0 0 auto">
            ${cardBox(`
              ${head('Successful tries', MARK.check, TINT.check.tint, TINT.check.soft)}
              <div style="display:flex;align-items:flex-end;gap:12px;margin-top:8px">
                <div style="${type('timerHero', { color: col.textPrimary })};font-size:52px;line-height:1">67%</div>
                <div style="display:flex;align-items:center;gap:4px;padding:3px 10px 3px 7px;border-radius:11px;
                  background:${TINT.check.soft};margin-bottom:9px">
                  <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="${TINT.check.tint}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V6"/><path d="M5.6 12.4 12 6l6.4 6.4"/></svg>
                  <span style="${type('parentFootnote', { color: TINT.check.tint, weight: 'semibold' })};font-size:12px">+12% vs last week</span>
                </div>
              </div>
              <div style="margin:8px -4px 0">
                ${sparkline([0.42, 0.5, 0.44, 0.58, 0.55, 0.63, 0.67], {
                  w: colW - 32, h: 150, stroke: TINT.check.tint, fill: TINT.check.tint,
                })}
              </div>
              <div style="display:flex;justify-content:space-between;margin-top:4px">
                ${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => `<span style="${type('parentFootnote', { color: col.textTertiary })};font-size:11.5px;width:22px;text-align:center">${d}</span>`).join('')}
              </div>
              <div style="margin-top:12px">${patternLabel(col)}</div>`)}

            <div style="height:${gap}px"></div>

            ${cardBox(`
              <div style="${type('parentHeadline', { color: col.textSecondary, weight: 'semibold' })};font-size:14.5px">What was logged</div>
              <div style="display:flex;margin-top:12px">
                ${metricChip(col, { glyph: 'check', value: '38', label: 'Checks', tint: TINT.check.tint, tintSoft: TINT.check.soft })}
                ${metricChip(col, { glyph: 'tried', value: '31', label: 'Tried', tint: TINT.tried.tint, tintSoft: TINT.tried.soft })}
                ${metricChip(col, { glyph: 'pee', value: '19', label: 'Pee', tint: TINT.pee.tint, tintSoft: TINT.pee.soft })}
                ${metricChip(col, { glyph: 'poop', value: '6', label: 'Poop', tint: TINT.poop.tint, tintSoft: TINT.poop.soft })}
                ${metricChip(col, { glyph: 'accident', value: '4', label: 'Accidents', tint: TINT.accident.tint, tintSoft: TINT.accident.soft })}
              </div>`)}

            <div style="height:${gap}px"></div>

            ${cardBox(`
              <div style="display:flex;gap:13px;align-items:flex-start">
                <div style="width:34px;height:34px;border-radius:11px;background:${TINT.accident.soft};display:grid;place-items:center;flex:0 0 auto">
                  ${EXTRA.info(TINT.accident.tint, 18)}
                </div>
                <div style="flex:1">
                  <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15px">4 accidents were logged, 3 of them after 3 PM.</div>
                  <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:4px;line-height:1.38">
                    Recorded as a neutral fact. Accidents never touch your child's stars, and your child never sees this entry.</div>
                </div>
              </div>`)}
          </div>

          <div style="width:${colW}px;flex:0 0 auto">
            ${cardBox(`
              ${head('Best time of day', MARK.clock, TINT.tried.tint, TINT.tried.soft)}
              <div style="display:flex;align-items:flex-start;gap:16px;margin-top:8px">
                <div style="flex:1;min-width:0">
                  <div style="${type('metric', { color: col.textPrimary })};font-size:28px">45–55 min</div>
                  <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:4px;line-height:1.38">
                    after the last visit is when most successful tries happened.</div>
                </div>
                <div style="width:140px;flex:0 0 auto;padding-top:14px">${dayShape([0.3, 0.45, 0.6, 1, 0.72, 0.4, 0.25], 3)}</div>
              </div>
              <div style="margin-top:12px">${patternLabel(col)}</div>`)}

            <div style="height:${gap}px"></div>

            ${cardBox(`
              ${head('Longest dry stretch', MARK.droplets, TINT.pee.tint, TINT.pee.soft)}
              <div style="display:flex;align-items:flex-start;gap:16px;margin-top:8px">
                <div style="flex:1;min-width:0">
                  <div style="${type('metric', { color: col.textPrimary })};font-size:28px">2h 15m</div>
                  <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:4px;line-height:1.38">
                    on Thursday morning. Last week's longest was 1h 50m.</div>
                </div>
                <div style="width:140px;flex:0 0 auto;padding-top:12px">
                  <div style="${type('parentFootnote', { color: col.textTertiary })};font-size:11px">This week</div>
                  <div style="height:10px;border-radius:5px;background:${TINT.pee.tint};margin-top:4px"></div>
                  <div style="${type('parentFootnote', { color: col.textTertiary })};font-size:11px;margin-top:9px">Last week</div>
                  <div style="height:10px;width:81%;border-radius:5px;background:${TINT.pee.soft};margin-top:4px"></div>
                </div>
              </div>
              <div style="margin-top:12px">${patternLabel(col)}</div>`)}

            <div style="height:${gap}px"></div>

            ${cardBox(`
              <div style="display:flex;gap:13px;align-items:flex-start">
                <div style="width:34px;height:34px;border-radius:11px;background:${TINT.star.soft};display:grid;place-items:center;flex:0 0 auto">
                  ${MARK.star(TINT.star.tint, 18)}
                </div>
                <div style="flex:1">
                  <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15px">Most visits happened between 9:00 AM and 11:00 AM.</div>
                  <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:4px;line-height:1.38">
                    The average gap between logged visits was 1 hour 10 minutes.</div>
                </div>
              </div>`)}
          </div>
        </div>

        <div style="flex:1"></div>
      </div>
    </div>
  </div>`;
}

module.exports = {
  screenTimeAsk, childProfile, firstPauseSet, settingsHub, childProfiles,
  paywallFamily, parentGate, deleteDataConfirm, accessRestored, progressEmpty,
  quickReminderSheet, widgets, liveActivity, insightsPad,
};
