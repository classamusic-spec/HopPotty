/**
 * Shared pieces the screens beyond the parent dashboard needed.
 *
 * Everything here obeys the same rule as `ui.js`: colour, radius, spacing and
 * type come out of the exported token file, so a render can only ever show the
 * design system the app compiles against.
 */
const { T, c, type, svg, alpha, mix, elevation, artOr } = require('./ui');

// ---------------------------------------------------------------------------
// Frames
// ---------------------------------------------------------------------------

/** iPadOS status bar: slim, edge to edge, unlike the phone's notch split. */
function statusBarPad(tint) {
  return `<div style="height:24px;flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;
    padding:0 22px;color:${tint}">
    <div style="${type('parentFootnote')};font-weight:700;font-size:13px">9:41 AM</div>
    <div style="display:flex;gap:7px;align-items:center">
      <svg width="15" height="11" viewBox="0 0 17 12" fill="${tint}"><path d="M8.5 11.2 5.9 8.4a3.7 3.7 0 0 1 5.2 0zM3.4 5.9a7.3 7.3 0 0 1 10.2 0l1.7-1.8a9.8 9.8 0 0 0-13.6 0z"/></svg>
      <svg width="23" height="11" viewBox="0 0 25 12"><rect x="0.5" y="0.5" width="20" height="11" rx="3.2" fill="none" stroke="${tint}" stroke-opacity="0.4"/><rect x="2" y="2" width="16" height="8" rx="2" fill="${tint}"/><path d="M22.5 4v4a2.1 2.1 0 0 0 0-4z" fill="${tint}" fill-opacity="0.5"/></svg>
    </div>
  </div>`;
}

// ---------------------------------------------------------------------------
// Parent controls
// ---------------------------------------------------------------------------

/** iOS segmented control: a sunken track with one raised selected pill. */
function segmented(col, appearance, items, activeIndex) {
  return `<div style="display:flex;gap:2px;padding:2px;border-radius:11px;background:${col.surfaceSunken};
    border:0.5px solid ${col.divider}">
    ${items.map((label, i) => {
      const on = i === activeIndex;
      return `<div style="flex:1;height:30px;border-radius:9px;display:grid;place-items:center;
        ${on ? `background:${col.surface};box-shadow:${elevation(appearance, 'resting')};` : ''}
        ${type('parentCallout', { color: on ? col.textPrimary : col.textSecondary, weight: on ? 'semibold' : 'medium' })};">${label}</div>`;
    }).join('')}
  </div>`;
}

/** iOS switch, at its real 51×31 size. */
function iosSwitch(col, on) {
  return `<div style="width:51px;height:31px;border-radius:16px;flex:0 0 auto;
    background:${on ? col.success : col.surfaceSunken};${on ? '' : `border:1px solid ${col.divider};`}
    display:flex;align-items:center;justify-content:${on ? 'flex-end' : 'flex-start'};padding:2px">
    <div style="width:27px;height:27px;border-radius:14px;background:#FFFFFF;
      box-shadow:0 1px 1px ${alpha(col.shadow, .12)},0 3px 8px ${alpha(col.shadow, .16)}"></div>
  </div>`;
}

/** A rounded icon tile of the kind iOS Settings puts at the head of a row. */
function iconTile(bg, glyph, { size = 30, radius = 8 } = {}) {
  return `<div style="width:${size}px;height:${size}px;border-radius:${radius}px;background:${bg};
    display:grid;place-items:center;flex:0 0 auto">${glyph}</div>`;
}

/** One row of a grouped list. */
function listRow(col, { icon, label, value, sub, accessory, chevron = false, last = false, labelColor, align = 'center', minHeight = 44 }) {
  const acc = accessory !== undefined ? accessory
    : `${value !== undefined ? `<span style="${type('parentCallout', { color: col.textSecondary })};font-size:15px;text-align:right">${value}</span>` : ''}
       ${chevron ? `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="${col.textTertiary}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" style="flex:0 0 auto"><path d="M9 5l7 7-7 7"/></svg>` : ''}`;
  return `<div style="display:flex;align-items:${align};gap:11px;min-height:${minHeight}px;padding:8px 14px 8px ${icon ? '13' : '16'}px;
    ${last ? '' : `box-shadow:inset 0 -1px 0 ${col.divider};`}">
    ${icon || ''}
    <div style="flex:1;min-width:0">
      <div style="${type('parentBody', { color: labelColor || col.textPrimary })};font-size:16px">${label}</div>
      ${sub ? `<div style="${type('parentCaption', { color: col.textSecondary })};margin-top:1px">${sub}</div>` : ''}
    </div>
    <div style="display:flex;align-items:center;gap:6px;flex:0 0 auto;max-width:56%">${acc}</div>
  </div>`;
}

/** A grouped-list section: optional uppercase header, a card of rows, a footer. */
function listGroup(col, appearance, { header, rows, footer }) {
  return `<div style="flex:0 0 auto">
    ${header ? `<div style="${type('parentFootnote', { color: col.textSecondary, weight: 'semibold' })};
      letter-spacing:.5px;text-transform:uppercase;padding:0 16px 6px">${header}</div>` : ''}
    <div style="background:${col.surface};border-radius:${T.radius.l}px;overflow:hidden;
      box-shadow:${elevation(appearance, 'resting')}">${rows.join('')}</div>
    ${footer ? `<div style="${type('parentCaption', { color: col.textSecondary })};
      padding:7px 16px 0;line-height:1.35">${footer}</div>` : ''}
  </div>`;
}

/** A nav bar with a back chevron, a centred title and an optional trailing item. */
function navBar(col, title, { back = true, trailing = '', large = false } = {}) {
  if (large) {
    return `<div style="flex:0 0 auto;padding:2px 20px 4px">
      <div style="display:flex;align-items:center;justify-content:space-between;height:38px">
        ${back ? `<div style="display:flex;align-items:center;gap:2px;margin-left:-6px">
          <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="${col.brandAction}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>
          <span style="${type('parentBody', { color: col.brandAction })};font-size:16px">Settings</span></div>` : '<div></div>'}
        ${trailing}
      </div>
      <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:30px;margin-top:2px">${title}</div>
    </div>`;
  }
  return `<div style="flex:0 0 auto;height:44px;display:flex;align-items:center;padding:0 16px;gap:10px">
    ${back ? `<svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="${col.brandAction}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>` : '<div style="width:21px"></div>'}
    <div style="flex:1;text-align:center;${type('parentHeadline', { color: col.textPrimary, weight: 'semibold' })};font-size:17px">${title}</div>
    <div style="min-width:21px;display:flex;justify-content:flex-end">${trailing}</div>
  </div>`;
}

// ---------------------------------------------------------------------------
// Child controls
// ---------------------------------------------------------------------------

/**
 * A child-sized button.
 *
 * `childPrimary` (96pt) and `childMinimum` (72pt) come from the hit-target
 * tokens, so these cannot drift below what a two-year-old can reliably hit.
 */
function childButton(col, appearance, label, {
  kind = 'primary', height, fill, textColor, icon = '', border, radius, fontSize,
} = {}) {
  const h = height || (kind === 'primary' ? T.hitTarget.childPrimary + 8 : T.hitTarget.childMinimum);
  const bg = fill || (kind === 'primary' ? col.brandAction : alpha('#FFFFFF', .72));
  const fg = textColor || (kind === 'primary' ? col.textOnBrand : col.textSecondary);
  return `<div style="height:${h}px;border-radius:${radius || Math.min(T.radius.hero, h / 2)}px;background:${bg};
    display:flex;align-items:center;justify-content:center;gap:12px;
    ${border ? `border:${border};` : ''}
    box-shadow:${kind === 'primary' ? elevation(appearance, 'raised') : 'none'}">
    ${icon}<span style="${type('buttonLarge', { color: fg })};font-size:${fontSize || (kind === 'primary' ? 27 : 21)}px">${label}</span>
  </div>`;
}

/** Page dots for an onboarding pager. */
function pageDots(col, count, active, { tint } = {}) {
  const on = tint || col.brandAction;
  return `<div style="display:flex;gap:8px;align-items:center;justify-content:center">
    ${Array.from({ length: count }, (_, i) => i === active
      ? `<div style="width:22px;height:8px;border-radius:4px;background:${on}"></div>`
      : `<div style="width:8px;height:8px;border-radius:4px;background:${alpha(col.textTertiary, .34)}"></div>`).join('')}
  </div>`;
}

/** The routine's step indicator. Five dots, never a number. */
function stepDots(count, active, { done, todo, now }) {
  return `<div style="display:flex;gap:9px;align-items:center;justify-content:center">
    ${Array.from({ length: count }, (_, i) => {
      if (i === active) return `<div style="width:15px;height:15px;border-radius:8px;background:${now};
        box-shadow:0 0 0 5px ${alpha(now, .22)}"></div>`;
      return `<div style="width:11px;height:11px;border-radius:6px;background:${i < active ? done : todo}"></div>`;
    }).join('')}
  </div>`;
}

// ---------------------------------------------------------------------------
// Glyphs beyond the parent set
// ---------------------------------------------------------------------------

const MARK = {
  star: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 2.4l2.95 6.1 6.7.92-4.87 4.66 1.2 6.6L12 17.55 6.02 20.68l1.2-6.6L2.35 9.42l6.7-.92z"/></svg>`,
  starOutline: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="1.9" stroke-linejoin="round"><path d="M12 3.4l2.6 5.4 5.9.8-4.3 4.1 1.05 5.8L12 16.7l-5.25 2.8 1.05-5.8-4.3-4.1 5.9-.8z"/></svg>`,
  drop: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 2.6c3.6 4.3 6.4 7.8 6.4 11a6.4 6.4 0 0 1-12.8 0c0-3.2 2.8-6.7 6.4-11z"/></svg>`,
  swirl: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M9.6 6.2c0-1.9 1.3-3.2 2.6-3.2 1.6 0 2.3 1.2 2 2.4 2 .1 3 1.3 2.8 2.7 2 .2 3 1.6 3 2.9 1.7.4 2.6 1.7 2.6 3.1 0 2.2-2 3.9-4.6 3.9H6c-2.6 0-4.6-1.7-4.6-3.9 0-1.5 1-2.8 2.8-3.2-.1-1.6 1-2.9 2.8-3-.2-1.4.9-2.6 2.6-2.7z"/></svg>`,
  ring: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.3"><circle cx="12" cy="12" r="8.4"/><circle cx="12" cy="12" r="3" fill="${f}" stroke="none"/></svg>`,
  clock: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.1" stroke-linecap="round"><circle cx="12" cy="12" r="8.6"/><path d="M12 7.2V12l3.2 2"/></svg>`,
  bell: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 22a2.3 2.3 0 0 0 2.3-2.1H9.7A2.3 2.3 0 0 0 12 22zm6.8-6.3v-4.7c0-3.2-1.8-5.7-4.6-6.4v-.7a2.2 2.2 0 0 0-4.4 0v.7c-2.8.7-4.6 3.2-4.6 6.4v4.7l-1.6 1.7v.8h16.8v-.8z"/></svg>`,
  moon: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M20.4 15.2A8.8 8.8 0 0 1 9.1 3.8a8.8 8.8 0 1 0 11.3 11.4z"/></svg>`,
  lock: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M7 10V8a5 5 0 0 1 10 0v2h.6A1.4 1.4 0 0 1 19 11.4v8.2a1.4 1.4 0 0 1-1.4 1.4H6.4A1.4 1.4 0 0 1 5 19.6v-8.2A1.4 1.4 0 0 1 6.4 10zm2.2 0h5.6V8a2.8 2.8 0 0 0-5.6 0z"/></svg>`,
  play: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M7.4 4.6 19 12 7.4 19.4z"/></svg>`,
  pause: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><rect x="5.6" y="4.4" width="4.6" height="15.2" rx="2"/><rect x="13.8" y="4.4" width="4.6" height="15.2" rx="2"/></svg>`,
  loop: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 11.2a8 8 0 1 0-.6 4.4"/><path d="M20.4 5.6v5.8h-5.6"/></svg>`,
  speaker: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M4 9.4h3.4L12 5.2v13.6L7.4 14.6H4z"/><path d="M15.2 8.6a5 5 0 0 1 0 6.8" fill="none" stroke="${f}" stroke-width="2" stroke-linecap="round"/><path d="M17.9 5.9a8.6 8.6 0 0 1 0 12.2" fill="none" stroke="${f}" stroke-width="2" stroke-linecap="round"/></svg>`,
  hand: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M8.6 12.4V5.2a1.6 1.6 0 0 1 3.2 0v6M11.8 11V4.4a1.6 1.6 0 0 1 3.2 0V11m0-1.2a1.6 1.6 0 0 1 3.2 0v5.4a6 6 0 0 1-6 6h-1.2a5.6 5.6 0 0 1-4.4-2.2l-2.4-3.2a1.6 1.6 0 0 1 2.4-2l1.8 1.8"/></svg>`,
  home: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 3.2 21 11h-2.4v8.2a1 1 0 0 1-1 1H14V15h-4v5.2H6.4a1 1 0 0 1-1-1V11H3z"/></svg>`,
  chart: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><rect x="3" y="12" width="4" height="8.5" rx="1.4"/><rect x="10" y="7" width="4" height="13.5" rx="1.4"/><rect x="17" y="3.5" width="4" height="17" rx="1.4"/></svg>`,
  gear: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2zm8.4 3.6c0 .5 0 1-.1 1.5l2 1.6-2 3.4-2.4-1a7.6 7.6 0 0 1-2.5 1.5l-.4 2.5h-4l-.4-2.5a7.6 7.6 0 0 1-2.5-1.5l-2.4 1-2-3.4 2-1.6a8.6 8.6 0 0 1 0-3l-2-1.6 2-3.4 2.4 1a7.6 7.6 0 0 1 2.5-1.5L10 2h4l.4 2.5a7.6 7.6 0 0 1 2.5 1.5l2.4-1 2 3.4-2 1.6c.1.5.1 1 .1 1.5z"/></svg>`,
  droplets: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><circle cx="8" cy="9" r="4.2"/><circle cx="16.4" cy="14.6" r="5.4"/></svg>`,
  check: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="${f}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4.6 12.6 9.6 17.6 19.4 6.6"/></svg>`,
  leaf: (f, s = 20) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="${f}"><path d="M20 4C9.5 4 4 9 4 16c0 1.5.3 2.8.8 4l1.7-1.6C7.6 13 12 9.8 18 9c-4.6 1.6-7.8 4.6-9.4 9.6 3 1.3 6.6.9 8.9-1.4C20.6 14.4 20.6 8 20 4z"/></svg>`,
};

// ---------------------------------------------------------------------------
// Data marks
// ---------------------------------------------------------------------------

/** A sparkline with a soft area under it and the last point called out. */
function sparkline(values, { w = 300, h = 60, stroke, fill, dot = true, pad = 6 }) {
  const min = Math.min(...values), max = Math.max(...values);
  const span = max - min || 1;
  const pts = values.map((v, i) => [
    pad + (i * (w - pad * 2)) / (values.length - 1),
    pad + (1 - (v - min) / span) * (h - pad * 2),
  ]);
  const d = pts.map((p, i) => {
    if (i === 0) return `M ${p[0].toFixed(1)} ${p[1].toFixed(1)}`;
    const q = pts[i - 1], cx = (q[0] + p[0]) / 2;
    return `C ${cx.toFixed(1)} ${q[1].toFixed(1)}, ${cx.toFixed(1)} ${p[1].toFixed(1)}, ${p[0].toFixed(1)} ${p[1].toFixed(1)}`;
  }).join(' ');
  const last = pts[pts.length - 1];
  const gid = 'spark' + Math.random().toString(36).slice(2, 8);
  return `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="display:block;overflow:visible">
    <defs><linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${fill}" stop-opacity="0.30"/>
      <stop offset="1" stop-color="${fill}" stop-opacity="0"/></linearGradient></defs>
    <path d="${d} L ${last[0].toFixed(1)} ${h} L ${pts[0][0].toFixed(1)} ${h} Z" fill="url(#${gid})"/>
    <path d="${d}" fill="none" stroke="${stroke}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
    ${dot ? `<circle cx="${last[0].toFixed(1)}" cy="${last[1].toFixed(1)}" r="5.4" fill="${stroke}" stroke="#FFFFFF" stroke-width="2.6"/>` : ''}
  </svg>`;
}

/** The hedge that sits on every observation HopPotty makes. */
function patternLabel(col) {
  return `<div style="display:inline-block;padding:4px 9px;border-radius:8px;background:${col.surfaceSunken};
    ${type('parentFootnote', { color: col.textSecondary, weight: 'medium' })}">Pattern, not medical advice</div>`;
}

// ---------------------------------------------------------------------------
// Event tints, resolved per appearance
// ---------------------------------------------------------------------------

/**
 * Glyph colour and its soft backing for each kind of event.
 *
 * In light, the soft backing is the pale palette tint. In dark those tints are
 * near-white and would blow a hole in the screen, so the same hue is used at low
 * opacity over the card instead.
 */
function tints(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const pair = (tint, soft) => ({ tint, soft: dark ? alpha(tint, 0.16) : soft });
  return {
    check: pair(col.success, T.palette.hopGreenSoft),
    tried: pair(col.eventTried, T.palette.lavenderSoft),
    pee: pair(col.eventPee, T.palette.pondBlueSoft),
    poop: pair(col.eventPoop, T.palette.peachSoft),
    star: pair(col.celebration, T.palette.sunshineSoft),
    accident: pair(col.eventAccident, T.palette.sand100),
  };
}

module.exports = {
  statusBarPad, segmented, iosSwitch, iconTile, listRow, listGroup, navBar,
  childButton, pageDots, stepDots, MARK, sparkline, patternLabel, tints,
};
