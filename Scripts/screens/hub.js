/**
 * 45 — Hop's hub: the child's home behind the "Hop" tab.
 *
 * The pond is the whole screen and Hop lives in it; the four doors (potty time,
 * the pond, games, Hop's questions) are big picture buttons a two-year-old can
 * hit, and the only way back to the grown-up side is the small pill in the
 * corner, which sits behind the parent gate. Stars are a count, not a target.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, elevation, artOr } = require('./ui');
const { MARK } = require('./kit');
const scenes = require('./scenes');
const { UNLOCKED } = require('./pond');
const { FEET } = require('./child');
const fs = require('fs');
const path = require('path');
const { ROOT } = require('./ui');
const P = T.palette;
const INK = P.midnight;

function thumb(rel, w, h, focus = 0.5) {
  const abs = path.join(ROOT, rel);
  const url = fs.existsSync(abs)
    ? `url('data:image/svg+xml;base64,${Buffer.from(fs.readFileSync(abs, 'utf8')).toString('base64')}')`
    : null;
  return `<div style="width:${w}px;height:${h}px;border-radius:16px;flex:0 0 auto;background-color:${P.sand100};
    ${url ? `background-image:${url};background-size:cover;background-position:center ${(focus * 100).toFixed(0)}%;` : ''}"></div>`;
}

function hopHub(appearance = 'light') {
  const col = c(appearance);
  // The hub uses `pond-scene.svg` — the pond recomposed for a tall phone —
  // rather than `pond-stage.svg`, which is the composition `PondCatalog`'s
  // anchors are placed against. The difference matters exactly once: the pond
  // *screen* has to put a duckling in the water, and the hub only has to stand a
  // frog and four doors on a pond-coloured ground. Decorations are deliberately
  // absent for the same reason — this is the ground the hub stands on, and a
  // child's collection belongs on the screen that is about their collection.
  const scene = artOr(['Art/pond/pond-scene.svg', 'Art/scenes/pond.svg'], { width: 393, height: 852 },
    scenes.pond(393, 852, UNLOCKED));

  const door = (label, art, focus, { primary = false } = {}) => `
    <div style="height:84px;border-radius:${T.radius.xl}px;display:flex;align-items:center;gap:14px;padding:0 14px 0 10px;
      background:${primary ? col.brandAction : alpha('#FFFFFF', .94)};box-shadow:${elevation(appearance, primary ? 'raised' : 'resting')}">
      ${thumb(art, 88, 64, focus)}
      <span style="${type('buttonLarge', { color: primary ? col.textOnBrand : INK })};font-size:24px;flex:1">${label}</span>
      <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="${primary ? alpha('#FFFFFF', .85) : P.sand500}"
        stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l7 7-7 7"/></svg>
    </div>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden">
    <div style="position:absolute;inset:0">${scene}</div>
    <div style="position:absolute;inset:0;background:linear-gradient(180deg, ${alpha('#FFFFFF', 0)} 42%, ${alpha(P.cloud, .55)} 70%, ${alpha(P.cloud, .9)} 100%)"></div>
    <div data-hop style="position:absolute;left:50%;top:${852 * 0.5 - 214 * FEET}px;transform:translateX(-50%)">
      ${svg('Art/character/hop-wave.svg', { width: 214 })}
    </div>

    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}

      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 20px 6px;overflow:hidden">
        <div style="flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;height:52px">
          <div style="height:44px;padding:0 15px 0 11px;border-radius:22px;background:${alpha('#FFFFFF', .88)};
            display:flex;align-items:center;gap:6px">
            ${MARK.star(P.sunshineBright, 21)}
            <span style="${type('buttonLarge', { color: P.sunshineDeep })};font-size:19px">13</span>
          </div>
          <div style="height:${T.hitTarget.parentMinimum}px;padding:0 15px;border-radius:22px;background:${alpha('#FFFFFF', .7)};
            display:flex;align-items:center;gap:6px">
            ${MARK.hand(P.sand500, 14)}
            <span style="${type('parentCallout', { color: P.sand600, weight: 'medium' })};font-size:13px">Grown-ups</span>
          </div>
        </div>

        <div style="flex:0 0 auto;text-align:center;margin-top:8px;${type('childTitle', { color: INK })};font-size:30px">Hi, Maya!</div>
        <div style="flex:0 0 auto;text-align:center;${type('childInstruction', { color: P.sand600 })};font-size:17px">What shall we do?</div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;display:flex;flex-direction:column;gap:${T.spacing.m}px">
          ${door('Potty time', 'Art/scenes/routine-try.svg', 0.55, { primary: true })}
          ${door("Hop's Pond", 'Art/pond/pond-preview.svg', 0.6)}
          ${door('Games', 'Art/scenes/games-flySnack.svg', 0.55)}
          ${door("Hop's questions", 'Art/scenes/games-bodySignal.svg', 0.5)}
        </div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

module.exports = { hopHub };
