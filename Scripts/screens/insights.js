/**
 * 13 — Progress.
 *
 * Descriptive statistics, never advice. Every card carries the same hedge in the
 * same words, because a caregiver reading a number about their child's body will
 * supply a judgement if the screen does not refuse to make one.
 *
 * Every headline here is a count or a range the engine can actually produce —
 * `PatternInsights.participation`, `.typicalGap`, `.longestDryStretch`. Nothing
 * on this screen is a rate: `Docs/MedicalBoundary.md` §4 forbids "success rate"
 * by name, and a percentage of tries would make a child's body a score.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation } = require('./ui');
const { segmented, sparkline, patternLabel, MARK, tints } = require('./kit');
const { tabBar } = require('./parent');
const P = T.palette;

function insights(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const TINT = tints(appearance);

  const card = (inner) => `<div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.xl}px;
    padding:15px 16px 13px;box-shadow:${elevation(appearance, 'resting')}">${inner}</div>`;

  const head = (label, glyph, tint, soft) => `
    <div style="display:flex;align-items:center;gap:10px">
      <div style="width:28px;height:28px;border-radius:9px;background:${soft};display:grid;place-items:center;flex:0 0 auto">${glyph(tint, 16)}</div>
      <span style="${type('parentCallout', { color: col.textSecondary, weight: 'semibold' })}">${label}</span>
    </div>`;

  /** The spread of recorded gaps. The commonest is called out, the rest recede. */
  const dayShape = (values, peak) => `<div style="display:flex;align-items:flex-end;gap:4px;height:46px">
    ${values.map((v, i) => `<div style="flex:1;height:${Math.max(8, v * 46)}px;border-radius:3px;
      background:${i === peak ? col.eventTried : alpha(col.eventTried, dark ? .3 : .22)}"></div>`).join('')}
  </div>`;

  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:${T.spacing.s}px;padding:0 ${T.spacing.pageCompact}px 8px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:flex-end;justify-content:space-between">
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px">Progress</div>
        <div style="display:flex;align-items:center;gap:7px;height:32px;padding:0 12px 0 5px;border-radius:16px;
          background:${col.surface};box-shadow:${elevation(appearance, 'resting')}">
          <div style="width:24px;height:24px;border-radius:12px;background:${T.palette.hopGreenSoft};overflow:hidden;
            display:grid;place-items:center"><div style="transform:translateY(2px)">${svg('Art/character/hop-face.svg', { width: 30 })}</div></div>
          <span style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })}">Maya</span>
        </div>
      </div>

      <div style="flex:0 0 auto">${segmented(col, appearance, ['Day', 'Week', 'Month'], 1)}</div>

      ${card(`
        ${head('Visits recorded', MARK.check, TINT.check.tint, TINT.check.soft)}
        <div style="${type('metric', { color: col.textPrimary })};font-size:32px;margin-top:7px">18 visits</div>
        <div style="${type('parentCaption', { color: col.textSecondary })};margin-top:3px;line-height:1.36">
          across 5 days with entries. 12 in the period before.</div>
        <div style="margin:8px -4px 0">
          ${sparkline([2, 4, 1, 3, 4, 2, 2], {
            w: 317, h: 46, stroke: TINT.check.tint, fill: TINT.check.tint,
          })}
        </div>
        <div style="display:flex;justify-content:space-between;margin-top:2px">
          ${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => `<span style="${type('parentFootnote', { color: col.textSecondary })};width:20px;text-align:center">${d}</span>`).join('')}
        </div>
        <div style="margin-top:${T.spacing.m}px">${patternLabel(col)}</div>`)}

      ${card(`
        <div style="display:flex;align-items:flex-start;gap:14px">
          <div style="flex:1;min-width:0">
            ${head('Typical gap', MARK.clock, TINT.tried.tint, TINT.tried.soft)}
            <div style="${type('metric', { color: col.textPrimary })};font-size:28px;margin-top:7px">45–55 min</div>
            <div style="${type('parentCaption', { color: col.textSecondary })};margin-top:3px;line-height:1.36">
              Half of the recorded gaps fell in this range, from 20 gaps.</div>
          </div>
          <div style="width:104px;flex:0 0 auto;padding-top:26px">${dayShape([0.3, 0.45, 0.6, 1, 0.72, 0.4, 0.25], 3)}</div>
        </div>
        <div style="margin-top:${T.spacing.m}px">${patternLabel(col)}</div>`)}

      ${card(`
        <div style="display:flex;align-items:flex-start;gap:14px">
          <div style="flex:1;min-width:0">
            ${head('Longest dry stretch', MARK.droplets, TINT.pee.tint, TINT.pee.soft)}
            <div style="${type('metric', { color: col.textPrimary })};font-size:28px;margin-top:7px">2h 15m</div>
            <div style="${type('parentCaption', { color: col.textSecondary })};margin-top:3px;line-height:1.36">
              with no accident recorded, on Thursday morning.</div>
          </div>
          <div style="width:104px;flex:0 0 auto;padding-top:24px">
            <div style="${type('parentFootnote', { color: col.textSecondary })}">This week</div>
            <div style="height:9px;border-radius:5px;background:${TINT.pee.tint};margin-top:4px"></div>
            <div style="${type('parentFootnote', { color: col.textSecondary })};margin-top:8px">Last week</div>
            <div style="height:9px;width:81%;border-radius:5px;background:${TINT.pee.soft};margin-top:4px"></div>
          </div>
        </div>
        <div style="margin-top:${T.spacing.m}px">${patternLabel(col)}</div>`)}

      <div style="flex:1"></div>
    </div>
    ${tabBar(col, 'Progress')}
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

module.exports = { insights };
