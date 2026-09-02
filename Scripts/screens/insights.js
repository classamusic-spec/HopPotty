/**
 * 13 — Progress.
 *
 * ## What this screen is not allowed to say
 *
 * Descriptive statistics, never advice, and never a performance. §7 and §13 bar
 * success rates, dry streaks, failure or accident rates, best days, longest
 * streaks and any ranking or competitive language. The screen this replaces
 * broke that rule in its third card: **Longest dry stretch — 2h 15m, with no
 * accident recorded**. A "longest" is a record; a record invites beating it;
 * and the thing being scored was a child's body. It is gone, along with the
 * week-on-week bar pair that framed it as a contest with last week.
 *
 * What is here instead comes from the preferred list: potty check-ins, routine
 * participation, the common interval, the most consistent time of day, and
 * hand-washing completion. All counts and ranges, none of them a rate.
 *
 * ## Why it is two objects instead of five cards
 *
 * The screen used to be a stack of near-identical cards, each with its own
 * tinted glyph tile, its own big number and its own copy of the same
 * "Pattern, not medical advice" pill — three of the same hedge on one screen,
 * which reads as boilerplate rather than as care. §35: one chart that earns a
 * card, one grouped list for everything that is a label and a value, and the
 * hedge said once, as the footer of the group it qualifies.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, elevation } = require('./ui');
const { segmented, columnChart, listRow, listGroup, tints } = require('./kit');
const { tabBar, pageGround, sectionHeader, metricChip } = require('./parent');

/**
 * The child this period belongs to, as a quiet chip.
 *
 * Shared by 13, 40 and 44 so all three Progress screens name the child the same
 * way. It is a chip and not a card: it identifies, it does not report.
 */
function childChip(col, appearance, name = 'Maya') {
  return `<div style="display:flex;align-items:center;gap:7px;height:32px;padding:0 12px 0 4px;border-radius:16px;
    background:${col.surface};border:0.5px solid ${col.divider}">
    <div style="width:24px;height:24px;border-radius:12px;background:${T.palette.hopGreenSoft};overflow:hidden;
      display:grid;place-items:center"><div style="transform:translateY(2px)">${svg('Art/character/hop-face.svg', { width: 30 })}</div></div>
    <span style="${type('parentCallout', { color: col.textPrimary, weight: 'semibold' })};font-size:14px">${name}</span>
  </div>`;
}

/** The observations that are a label and a value, in one grouped list. */
function observationRows(col) {
  const rows = [
    ['Common interval', '45–55 min'],
    ['Most consistent time', '9–11 AM'],
    ['Routine participation', '12 of 14'],
    ['Hand-washing completed', '11 of 12'],
    ['Accidents recorded', '4'],
  ];
  return rows.map(([label, value], i) => listRow(col, {
    label, value, chevron: true, last: i === rows.length - 1,
  }));
}

/**
 * The week's totals.
 *
 * Four columns, not five. Accidents are still counted — a caregiver who logged
 * one deserves to see it counted — but as a row in the list below rather than as
 * a headline number in the same weight as the rest. §7 asks for them to be
 * recorded, never ranked and never made a rate; a fifth column here also made
 * the row too narrow to set its own labels, which is its own answer.
 */
function weekTotals(col, appearance) {
  const TINT = tints(appearance);
  const rule = `<div style="width:0.5px;align-self:stretch;background:${col.divider}"></div>`;
  const cells = [
    ['check', '38', 'Checks', TINT.check.tint],
    ['tried', '31', 'Tried', TINT.tried.tint],
    ['pee', '19', 'Pee', TINT.pee.tint],
    ['poop', '6', 'Poop', TINT.poop.tint],
  ];
  return cells.map(([glyph, value, label, tint], i) =>
    (i ? rule : '') + metricChip(col, { glyph, value, label, tint })).join('');
}

function insights(appearance = 'light') {
  const col = c(appearance);
  const TINT = tints(appearance);

  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${pageGround(col)}">
    ${statusBar(col.textPrimary)}
    <div class="fit" style="flex:1;display:flex;flex-direction:column;gap:14px;padding:2px ${T.spacing.pageCompact}px 8px;overflow:hidden">

      <div style="flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;padding-top:4px">
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px">Progress</div>
        ${childChip(col, appearance)}
      </div>

      <div style="flex:0 0 auto">${segmented(col, appearance, ['Day', 'Week', 'Month'], 1)}</div>

      <!-- The one thing on this screen that earns a card of its own. -->
      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.l}px;padding:16px 16px 14px;
        border:0.5px solid ${col.divider};box-shadow:${elevation(appearance, 'resting')}">
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:15px">Potty check-ins</div>
        <div style="display:flex;align-items:baseline;gap:8px;margin-top:2px">
          <span style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px;
            font-variant-numeric:tabular-nums">18</span>
          <span style="${type('parentCallout', { color: col.textSecondary })};font-size:15px">across 5 days with entries</span>
        </div>
        <div style="margin-top:12px">
          ${columnChart(col, [2, 4, 1, 3, 4, 2, 2], ['M', 'T', 'W', 'T', 'F', 'S', 'S'], {
            h: 78, tint: TINT.check.tint, dim: col.divider,
          })}
        </div>
      </div>

      <!-- The week's totals, in the same compact row Home uses for the day. -->
      <div style="flex:0 0 auto;background:${col.surface};border-radius:${T.radius.l}px;padding:14px 2px;
        border:0.5px solid ${col.divider};box-shadow:${elevation(appearance, 'resting')};display:flex;align-items:stretch">
        ${weekTotals(col, appearance)}
      </div>

      <div style="flex:0 0 auto">
        ${sectionHeader(col, 'This week')}
        ${listGroup(col, appearance, {
          rows: observationRows(col),
          footer: 'Patterns in what you logged over 7 days. Descriptions of a period, not medical advice.',
        })}
      </div>

      <div style="flex:1"></div>
    </div>
    ${tabBar(col, 'Progress')}
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

module.exports = { insights, childChip, observationRows, weekTotals };
