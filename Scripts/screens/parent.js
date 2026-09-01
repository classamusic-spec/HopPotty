const { T, c, type, statusBar, homeIndicator, svg, shadow, alpha, elevation } = require('./ui');
const { tints } = require('./kit');

/** Rounded card container matching HopCard. */
function card(col, inner, { pad = 17, radius = T.radius.xl, elev = 'resting', bg, extra = '', appearance = 'light' } = {}) {
  return `<div style="background:${bg || col.surface};border-radius:${radius}px;padding:${pad}px;
    box-shadow:${elev === 'none' ? 'none' : elevation(appearance, elev)};${extra}">${inner}</div>`;
}

function pillButton(col, label, { fill, textColor, grow = true, height = 44 } = {}) {
  return `<div style="flex:${grow ? 1 : '0 0 auto'};height:${height}px;border-radius:${height / 2}px;
    background:${fill};display:grid;place-items:center;${type('parentHeadline', { color: textColor, weight: 'semibold' })}
    ${fill === 'transparent' ? `border:1.5px solid ${col.divider};` : ''}">${label}</div>`;
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

/** Parent dashboard. Modelled on Apple Health's density and restraint. */
function parentHome(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const TINT = tints(appearance);
  const modeSoft = dark ? alpha(T.palette.hopGreen, .16) : T.palette.hopGreenSoft;
  const modeInk = dark ? T.palette.hopGreenLight : T.palette.hopGreenInk;
  const P = T.spacing.pageCompact;
  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}
    <div class="fit" style="flex:1;overflow:hidden;display:flex;flex-direction:column;gap:9px;padding:2px ${P}px 6px">

      <div style="display:flex;align-items:center;gap:12px">
        <div style="width:42px;height:42px;border-radius:21px;background:${T.palette.hopGreenSoft};
          display:grid;place-items:center;overflow:hidden;border:2px solid ${T.palette.hopGreenLight}">
          <div style="transform:translateY(3px)">${svg('Art/character/hop-face.svg', { width: 52 })}</div>
        </div>
        <div style="flex:1">
          <div style="${type('parentCaption', { color: col.textTertiary })}">Good morning,</div>
          <div style="display:flex;align-items:center;gap:5px">
            <span style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:26px">Maya</span>
            ${GLYPH.chevron(col.textTertiary).replace('M9 5l7 7-7 7', 'M6 9l6 6 6-6')}
          </div>
        </div>
        <div style="width:38px;height:38px;border-radius:19px;background:${col.surface};display:grid;place-items:center;
          box-shadow:0 2px 8px ${col.shadow}">
          <svg viewBox="0 0 24 24" width="19" height="19" fill="${col.textSecondary}"><path d="M12 22a2.4 2.4 0 0 0 2.4-2.2H9.6A2.4 2.4 0 0 0 12 22zm7-6.4v-4.9c0-3.3-1.9-5.9-4.8-6.6v-.7a2.2 2.2 0 0 0-4.4 0v.7C6.9 4.8 5 7.4 5 10.7v4.9l-1.6 1.7v.9h17.2v-.9z"/></svg>
        </div>
      </div>

      <!-- Hero: the one thing a parent opens this app to see. -->
      ${card(col, `
        <div style="display:flex;align-items:flex-start;gap:10px">
          <div style="flex:1">
            <div style="${type('parentCaption', { color: col.textSecondary, weight: 'semibold' })};text-transform:uppercase;letter-spacing:.6px;font-size:11.5px">Next Potty Pause</div>
            <div style="${type('timerHero', { color: col.textPrimary })};font-size:44px;margin-top:1px;font-variant-numeric:tabular-nums">28:14</div>
            <div style="display:inline-flex;align-items:center;gap:6px;margin-top:4px;padding:4px 11px;border-radius:20px;background:${modeSoft}">
              <div style="width:7px;height:7px;border-radius:4px;background:${dark ? T.palette.hopGreenLight : T.palette.hopGreenDeep}"></div>
              <span style="${type('parentFootnote', { color: modeInk, weight: 'semibold' })};font-size:12px">Routine Mode</span>
            </div>
          </div>
          <div style="margin:-8px -6px 0 0">${svg('Art/character/hop-idle.svg', { width: 104 })}</div>
        </div>
        <div style="display:flex;gap:10px;margin-top:13px">
          ${pillButton(col, 'Skip', { fill: 'transparent', textColor: col.textSecondary })}
          ${pillButton(col, 'Start Now', { fill: col.brandAction, textColor: col.textOnBrand })}
        </div>`, { elev: 'raised', appearance })}

      <div>
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
      </div>

      <div>
        <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15.5px;margin-bottom:6px">Today's routine</div>
        ${card(col, `
          ${timelineRow(col, { time: '1:42 PM', label: 'Pee', glyph: 'pee', tint: TINT.pee.tint, tintSoft: TINT.pee.soft })}
          ${timelineRow(col, { time: '12:54 PM', label: 'Tried', glyph: 'tried', tint: TINT.tried.tint, tintSoft: TINT.tried.soft })}
          ${timelineRow(col, { time: '11:58 AM', label: 'Poop', glyph: 'poop', tint: TINT.poop.tint, tintSoft: TINT.poop.soft, last: true })}
        `, { pad: 13, appearance })}
      </div>

      ${card(col, `<div style="display:flex;gap:13px;align-items:flex-start">
        <div style="width:38px;height:38px;border-radius:12px;background:${TINT.pee.soft};display:grid;place-items:center;flex:0 0 auto">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="${TINT.pee.tint}"><rect x="3" y="13" width="3.6" height="7" rx="1.2"/><rect x="10.2" y="8" width="3.6" height="12" rx="1.2"/><rect x="17.4" y="4" width="3.6" height="16" rx="1.2"/></svg>
        </div>
        <div style="flex:1">
          <div style="${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:15px">A pattern is forming</div>
          <div style="${type('parentCallout', { color: col.textSecondary })};font-size:13.5px;margin-top:3px">Most successful tries this week happened about 45–55 minutes apart.</div>
          <div style="display:inline-block;margin-top:8px;padding:3px 9px;border-radius:8px;background:${col.surfaceSunken};
            ${type('parentFootnote', { color: col.textTertiary, weight: 'medium' })};font-size:10.5px">Pattern, not medical advice</div>
        </div>
      </div>`, { pad: 13, appearance })}
    </div>
    ${tabBar(col, 'Home')}
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

module.exports = { parentHome, card, pillButton, GLYPH, metricChip, timelineRow, tabBar };
