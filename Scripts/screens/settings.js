/**
 * Caregiver configuration. Grouped lists, native spacing, no invention.
 *
 * These two screens carry the app's two hardest promises — that a pause always
 * ends, and that HopPotty never learns what its child is doing — so both say so
 * in plain words on the screen itself rather than in a help article.
 */
const { T, c, type, statusBar, homeIndicator, alpha, mix, elevation } = require('./ui');
const { listRow, listGroup, navBar, iosSwitch, MARK } = require('./kit');
const P = T.palette;

/** A neutral stand-in for a third-party app mark. Never a real logo. */
function appMark(hue, glyph) {
  return `<div style="width:38px;height:38px;border-radius:11px;background:${hue};display:grid;place-items:center;flex:0 0 auto">${glyph}</div>`;
}

const MARKS = {
  play: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="${f}"><path d="M8 5.4 18.4 12 8 18.6z"/></svg>`,
  bars: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="${f}"><rect x="4" y="4" width="4.4" height="16" rx="2"/><rect x="15.6" y="4" width="4.4" height="16" rx="2"/><path d="M9 4h5l1 16h-5z"/></svg>`,
  sparkle: (f) => `<svg viewBox="0 0 24 24" width="18" height="18" fill="${f}"><path d="M12 2.6c.7 5.2 3.5 8 8.7 8.7-5.2.7-8 3.5-8.7 8.7-.7-5.2-3.5-8-8.7-8.7 5.2-.7 8-3.5 8.7-8.7z"/></svg>`,
  frame: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="${f}" stroke-width="2.4"><rect x="4.4" y="4.4" width="15.2" height="15.2" rx="4.4"/></svg>`,
  blocks: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="${f}"><rect x="3.6" y="3.6" width="7.4" height="7.4" rx="1.6"/><rect x="13" y="3.6" width="7.4" height="7.4" rx="1.6" opacity=".55"/><rect x="3.6" y="13" width="7.4" height="7.4" rx="1.6" opacity=".55"/><rect x="13" y="13" width="7.4" height="7.4" rx="1.6"/></svg>`,
  dot: (f) => `<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="${f}" stroke-width="2.6"><circle cx="12" cy="12" r="7.4"/></svg>`,
};

/** 04 — Potty Pause timing. */
function timerSettings(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const accentInk = dark ? P.hopGreenLight : P.hopGreenInk;

  const action = (label, last) => listRow(col, {
    label: `<span style="text-align:center;display:block;color:${col.brandAction}">${label}</span>`,
    accessory: '', last, minHeight: 46,
  });

  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${col.backgroundSecondary}">
    ${statusBar(col.textPrimary)}
    ${navBar(col, 'Potty Pause', { large: true })}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:10px;padding:2px 20px 6px;overflow:hidden">

      <!-- The schedule, said once, in words. Every control below only edits this sentence. -->
      <div style="flex:0 0 auto;background:${dark ? alpha(P.hopGreen, .13) : P.hopGreenSoft};border-radius:${T.radius.l}px;
        padding:13px 15px;display:flex;gap:12px;align-items:flex-start">
        <div style="width:30px;height:30px;border-radius:15px;flex:0 0 auto;display:grid;place-items:center;
          background:${dark ? alpha(P.hopGreenLight, .2) : '#FFFFFF'}">${MARK.clock(accentInk, 17)}</div>
        <div style="flex:1">
          <div style="${type('parentFootnote', { color: accentInk, weight: 'semibold' })};font-size:11px;
            letter-spacing:.6px;text-transform:uppercase">Your schedule</div>
          <div style="${type('parentCallout', { color: dark ? col.textPrimary : accentInk })};font-size:14px;
            line-height:1.42;margin-top:3px">
            Hop invites Maya about every 45 minutes, with a 2-minute heads-up. Pauses last 3 minutes and stay quiet at nap and bedtime.</div>
        </div>
      </div>

      ${listGroup(col, appearance, {
        rows: [listRow(col, { label: 'Mode', value: 'Guided routine', chevron: true, last: true })],
      })}

      ${listGroup(col, appearance, {
        header: 'Timing',
        rows: [
          listRow(col, { label: 'Every', value: '45 minutes', chevron: true }),
          listRow(col, { label: 'Warning before a pause', value: '2 minutes', chevron: true }),
          listRow(col, { label: 'Pause length', value: '3 minutes', chevron: true, last: true }),
        ],
        footer: 'A pause always ends when this time is up, whatever happened in the bathroom.',
      })}

      ${listGroup(col, appearance, {
        header: 'Quiet times',
        rows: [
          listRow(col, { label: 'Nap', value: '12:30 – 2:30 PM', chevron: true }),
          listRow(col, { label: 'Bedtime', value: 'After 7:30 PM', chevron: true }),
          listRow(col, {
            label: `<span style="color:${col.brandAction}">Add a quiet time</span>`, accessory: '', last: true,
          }),
        ],
        footer: 'HopPotty stays silent during these.',
      })}

      ${listGroup(col, appearance, {
        rows: [action('Test Potty Pause'), action('Restore Screen Access', true)],
        footer: 'Restoring lifts any pause that is up right now.',
      })}

      <div style="flex:1"></div>
    </div>
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

/**
 * 05 — Apps that pause.
 *
 * ## Why this screen does not list apps
 *
 * Apple hands a selection to us as opaque `ApplicationToken`s. HopPotty cannot
 * read a name, an icon, or what an app is; `ScreenTimeConfiguration` therefore
 * stores counts and nothing else (see `Docs/ScreenTimeArchitecture.md` §3). A
 * mock listing "Netflix" with its own switch would be unbuildable, and it would
 * contradict the privacy promise printed on the same screen.
 *
 * So HopPotty shows what it actually holds — a count of apps and categories —
 * and hands the choosing to Apple's `FamilyActivityPicker`, a system view we
 * cannot restyle. The sheet below is drawn in system chrome on purpose: the seam
 * between our design and Apple's is real and a designer should see it here.
 */
function chooseApps(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const systemTint = col.focusRing;
  const sheetTop = 452;

  const countTile = (n, label) => `
    <div style="flex:1;text-align:center">
      <div style="${type('metric', { color: col.textPrimary })};font-size:30px">${n}</div>
      <div style="${type('parentCaption', { color: col.textTertiary })};font-size:12.5px;margin-top:1px">${label}</div>
    </div>`;

  // --- Apple's picker. System chrome, deliberately not ours. ---
  const pickerRow = (name, detail, state, last) => {
    const box = state === 'all'
      ? `<svg viewBox="0 0 24 24" width="22" height="22"><circle cx="12" cy="12" r="11" fill="${systemTint}"/><path d="M6.6 12.4 10.4 16 17.4 8.6" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`
      : state === 'some'
        ? `<svg viewBox="0 0 24 24" width="22" height="22"><circle cx="12" cy="12" r="11" fill="${systemTint}"/><rect x="7" y="10.8" width="10" height="2.6" rx="1.3" fill="#FFFFFF"/></svg>`
        : `<svg viewBox="0 0 24 24" width="22" height="22"><circle cx="12" cy="12" r="10.6" fill="none" stroke="${col.divider}" stroke-width="1.6"/></svg>`;
    return `<div style="display:flex;align-items:center;gap:12px;padding:0 16px;height:52px;
      ${last ? '' : `box-shadow:inset 0 -0.5px 0 ${col.divider};`}">
      ${box}
      <div style="width:30px;height:30px;border-radius:7px;background:${col.divider};flex:0 0 auto"></div>
      <div style="flex:1;${type('parentBody', { color: col.textPrimary })};font-size:16px">${name}</div>
      <span style="${type('parentCallout', { color: col.textTertiary })};font-size:15px">${detail}</span>
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="${col.textTertiary}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l7 7-7 7"/></svg>
    </div>`;
  };

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden;background:${T.palette.midnight}">

    <!-- HopPotty's own screen, scaled back the way iOS scales a sheet's presenter -->
    <div style="position:absolute;left:0;right:0;top:10px;height:${sheetTop + 40}px;overflow:hidden;
      border-radius:14px;background:${col.backgroundSecondary}">
      <div style="display:flex;flex-direction:column;height:100%">
        ${statusBar(col.textPrimary)}
        ${navBar(col, 'Apps that pause', { large: true })}
        <div style="flex:1;display:flex;flex-direction:column;gap:12px;padding:0 20px">

          <div style="background:${col.surface};border-radius:${T.radius.l}px;padding:15px 16px;
            box-shadow:${elevation(appearance, 'resting')}">
            <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:16px">
              4 apps and 1 category will pause</div>
            <div style="display:flex;margin-top:12px">
              ${countTile('4', 'Apps')}
              <div style="width:1px;background:${col.divider}"></div>
              ${countTile('1', 'Category')}
              <div style="width:1px;background:${col.divider}"></div>
              ${countTile('0', 'Websites')}
            </div>
          </div>

          <div style="background:${col.surface};border-radius:${T.radius.l}px;padding:13px 15px;display:flex;gap:12px;
            align-items:flex-start;box-shadow:${elevation(appearance, 'resting')}">
            <div style="width:30px;height:30px;border-radius:10px;flex:0 0 auto;display:grid;place-items:center;
              background:${dark ? alpha(P.pondBlueLight, .2) : P.pondBlueSoft}">${MARK.lock(col.eventPee, 16)}</div>
            <div style="flex:1">
              <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:14.5px">HopPotty never learns which apps</div>
              <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:3px;line-height:1.42">
                Apple hands over a sealed token for each choice. HopPotty can count them and pause them — it cannot read a name or an icon, and never sees what happens inside.</div>
            </div>
          </div>

          <div style="height:50px;border-radius:25px;background:${col.brandAction};display:grid;place-items:center;
            ${type('parentHeadline', { color: col.textOnBrand, weight: 'semibold' })};font-size:17px">Choose apps</div>
        </div>
      </div>
      <div style="position:absolute;inset:0;background:${alpha(T.palette.midnight, .14)}"></div>
    </div>

    <!-- Apple's FamilyActivityPicker. System-drawn; nothing here is ours to style. -->
    <div style="position:absolute;left:0;right:0;top:${sheetTop}px;bottom:0;background:${col.surface};
      border-radius:12px 12px 0 0;box-shadow:0 -8px 30px ${alpha(T.palette.midnight, .22)};display:flex;flex-direction:column">
      <div style="height:20px;display:grid;place-items:center;flex:0 0 auto">
        <div style="width:36px;height:5px;border-radius:3px;background:${col.divider}"></div>
      </div>
      <div style="height:44px;display:flex;align-items:center;padding:0 16px;flex:0 0 auto">
        <span style="${type('parentBody', { color: systemTint })};font-size:16px;flex:1">Cancel</span>
        <span style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:16px">Select Apps &amp; Categories</span>
        <span style="${type('parentBody', { color: systemTint, weight: 'semibold' })};font-size:16px;flex:1;text-align:right">Done</span>
      </div>
      <div style="padding:0 16px 10px;flex:0 0 auto">
        <div style="height:36px;border-radius:10px;background:${col.surfaceSunken};display:flex;align-items:center;gap:7px;padding:0 10px">
          <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="${col.textTertiary}" stroke-width="2.4" stroke-linecap="round"><circle cx="10.6" cy="10.6" r="6.8"/><path d="M15.6 15.6 20 20"/></svg>
          <span style="${type('parentCallout', { color: col.textTertiary })};font-size:15px">Search</span>
        </div>
      </div>
      <div style="${type('parentFootnote', { color: col.textTertiary })};font-size:11.5px;letter-spacing:.5px;
        text-transform:uppercase;padding:2px 16px 6px;flex:0 0 auto">Categories</div>
      <div style="flex:1;overflow:hidden;box-shadow:inset 0 0.5px 0 ${col.divider}">
        ${pickerRow('Games', '', 'some')}
        ${pickerRow('Entertainment', '', 'all')}
        ${pickerRow('Education', '', 'none')}
        ${pickerRow('Social Networking', '', 'none')}
        ${pickerRow('Creativity', '', 'none', true)}
      </div>
    </div>
  </div>`;
}

module.exports = { timerSettings, chooseApps };
