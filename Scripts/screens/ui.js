/**
 * Shared render primitives for the screen harness.
 *
 * These read the SAME token JSON the app compiles against (exported by the
 * `hoptokens` Swift target), so a render can never show a colour, radius or type
 * size the app does not actually use. It is a visualisation of the design
 * system, not a separate mockup that drifts from it.
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const T = JSON.parse(fs.readFileSync(path.join(ROOT, 'Scripts', 'tokens.json'), 'utf8'));

const fontData = (file) =>
  fs.readFileSync(path.join(ROOT, 'Scripts', 'fonts', file)).toString('base64');

function svg(relPath, { width, height, opacity } = {}) {
  const abs = path.join(ROOT, relPath);
  if (!fs.existsSync(abs)) {
    return `<div style="width:${width || 100}px;height:${height || 100}px;display:grid;place-items:center;
      border:2px dashed ${T.palette.sand300};border-radius:16px;color:${T.palette.sand500};font-size:11px">${path.basename(relPath)}</div>`;
  }
  const b64 = Buffer.from(fs.readFileSync(abs, 'utf8')).toString('base64');
  const style = [
    width ? `width:${width}px` : '',
    height ? `height:${height}px` : '',
    opacity ? `opacity:${opacity}` : '',
    'object-fit:contain;display:block',
  ].filter(Boolean).join(';');
  return `<img src="data:image/svg+xml;base64,${b64}" style="${style}">`;
}

/** Resolved semantic colours for an appearance. */
const c = (appearance = 'light') => T.appearances[appearance];

function baseCSS(appearance = 'light') {
  const col = c(appearance);
  return `
@font-face{font-family:'HopRounded';src:url(data:font/ttf;base64,${fontData('Fredoka.ttf')}) format('truetype');font-weight:300 700;font-display:block}
@font-face{font-family:'HopStandard';src:url(data:font/ttf;base64,${fontData('Nunito.ttf')}) format('truetype');font-weight:200 900;font-display:block}
*{box-sizing:border-box;margin:0;padding:0;-webkit-font-smoothing:antialiased}
body{font-family:'HopStandard',system-ui,sans-serif;color:${col.textPrimary};background:${col.backgroundPrimary}}
.rounded{font-family:'HopRounded','HopStandard',sans-serif}
.mono-digits{font-variant-numeric:tabular-nums}
`;
}

/** A style string for one named text style from the exported type scale. */
function type(name, { color, weight, size } = {}) {
  const s = T.typography[name];
  const w = { regular: 400, medium: 500, semibold: 600, bold: 700, heavy: 800 }[weight || s.weight];
  const fam = s.family === 'rounded' ? "'HopRounded','HopStandard',sans-serif" : "'HopStandard',sans-serif";
  return `font-family:${fam};font-size:${size || s.size}px;font-weight:${w};` +
    `line-height:${s.lineHeight};letter-spacing:${s.tracking}px;` + (color ? `color:${color};` : '');
}

/** iOS status bar. Present so the renders read at true device scale. */
function statusBar(tint) {
  return `<div style="height:54px;display:flex;align-items:flex-end;justify-content:space-between;
    padding:0 28px 8px;color:${tint};flex:0 0 auto">
    <div style="${type('parentFootnote')};font-weight:700;font-size:15px">9:41</div>
    <div style="display:flex;gap:6px;align-items:center">
      <svg width="18" height="12" viewBox="0 0 18 12" fill="${tint}"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
      <svg width="17" height="12" viewBox="0 0 17 12" fill="${tint}"><path d="M8.5 11.2 5.9 8.4a3.7 3.7 0 0 1 5.2 0zM3.4 5.9a7.3 7.3 0 0 1 10.2 0l1.7-1.8a9.8 9.8 0 0 0-13.6 0z"/></svg>
      <svg width="25" height="12" viewBox="0 0 25 12"><rect x="0.5" y="0.5" width="20" height="11" rx="3.2" fill="none" stroke="${tint}" stroke-opacity="0.4"/><rect x="2" y="2" width="15" height="8" rx="2" fill="${tint}"/><path d="M22.5 4v4a2.1 2.1 0 0 0 0-4z" fill="${tint}" fill-opacity="0.5"/></svg>
    </div>
  </div>`;
}

/** Home indicator. */
function homeIndicator(tint) {
  return `<div style="height:26px;display:grid;place-items:end center;padding-bottom:8px;flex:0 0 auto">
    <div style="width:140px;height:5px;border-radius:3px;background:${tint};opacity:.28"></div></div>`;
}

/** Soft shadow string for an elevation step. */
function shadow(appearance, level = 'resting') {
  const col = c(appearance);
  const spec = { resting: [14, 4, 1], raised: [24, 8, 1.15], floating: [40, 16, 1.3] }[level];
  return `0 ${spec[1]}px ${spec[0]}px ${col.shadow}`;
}

module.exports = { T, c, baseCSS, type, statusBar, homeIndicator, svg, shadow, ROOT };
