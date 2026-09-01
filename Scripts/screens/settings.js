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

/** 05 — Which apps pause, framed as what Apple hands over and what it does not. */
function chooseApps(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const soft = (hex) => (dark ? alpha(hex, 0.22) : mix(hex, '#FFFFFF', 0.8));

  const app = (name, mark, on, last) => listRow(col, {
    icon: mark, label: name, accessory: iosSwitch(col, on), last, minHeight: 56,
  });

  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${col.backgroundSecondary}">
    ${statusBar(col.textPrimary)}
    ${navBar(col, 'Choose Apps', {
      back: false,
      trailing: `<span style="${type('parentHeadline', { color: col.brandAction, weight: 'semibold' })};font-size:17px">Done</span>`,
    })}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:11px;padding:4px 20px 4px;overflow:hidden">

      <div style="padding:0 2px">
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:27px">Pick the apps that pause</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:14.5px;margin-top:6px;line-height:1.42">
          Usually the games and video apps your child uses most.</div>
      </div>

      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.l}px;padding:13px 15px;display:flex;gap:12px;
        align-items:flex-start;box-shadow:${elevation(appearance, 'resting')}">
        <div style="width:30px;height:30px;border-radius:10px;flex:0 0 auto;display:grid;place-items:center;
          background:${dark ? alpha(P.pondBlueLight, .2) : P.pondBlueSoft}">${MARK.lock(col.eventPee, 16)}</div>
        <div style="flex:1">
          <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:14.5px">Apple keeps this private</div>
          <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13px;margin-top:3px;line-height:1.42">
            The list comes from Apple's Screen Time picker. HopPotty is handed a sealed token for each app — never a name, an icon, or what happens inside.</div>
        </div>
      </div>

      ${listGroup(col, appearance, {
        header: 'On this device',
        rows: [
          app('YouTube Kids', appMark(soft(P.peachPop), MARKS.play(P.peachDeep)), true),
          app('Netflix', appMark(soft(P.lavender), MARKS.bars(P.lavenderDeep)), true),
          app('Disney+', appMark(soft(P.pondBlue), MARKS.sparkle(P.pondBlueDeep)), true),
          app('ABCmouse', appMark(soft(P.sunshineBright), MARKS.frame(P.sunshineDeep)), false),
          app('Minecraft', appMark(soft(P.hopGreen), MARKS.blocks(P.hopGreenDeep)), true),
          app('PBS Kids', appMark(soft(P.sand300), MARKS.dot(P.sand600)), false, true),
        ],
      })}

      ${listGroup(col, appearance, {
        header: 'Whole categories',
        rows: [
          listRow(col, { label: 'Choose whole categories', sub: 'All Games, All Entertainment', chevron: true, last: true, minHeight: 52 }),
        ],
        footer: '4 apps will pause. Everything not switched on here is left completely alone.',
      })}

      <div style="flex:1"></div>
    </div>
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

module.exports = { timerSettings, chooseApps };
