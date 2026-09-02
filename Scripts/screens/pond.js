/**
 * 10 — Hop's Pond.
 *
 * The reward is a place, not a score. Every star spends on something that stays
 * in the scene, the price of the next thing is visible in advance, and there is
 * no randomness anywhere — `PondCatalog` fixes the order and the cost, so a
 * child always knows what is coming and how far away it is.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOrInline } = require('./ui');
const { MARK } = require('./kit');
const scenes = require('./scenes');
const { FEET } = require('./child');
const P = T.palette;
const INK = P.midnight;

/** The first twelve items of `PondCatalog`, in catalogue order. */
const UNLOCKED = [
  'lilyPadSmall', 'reedsLeft', 'fishOrange', 'cloudPuff', 'flowerYellow',
  'lilyPadLarge', 'reedsRight', 'stoneSmall', 'tadpoleFriend', 'flowerPink',
  'butterflyBlue', 'lilyFlower',
];

/** Thumbnails for the collection strip. Small, flat, readable at 34px. */
const THUMB = {
  lilyPad: `<svg viewBox="0 0 40 40" width="34" height="34"><ellipse cx="20" cy="22" rx="16" ry="7" fill="${P.hopGreenDeep}"/><path d="M20 22 L32 17 A16 7 0 0 0 28 15.6Z" fill="${P.pondBlueSoft}"/></svg>`,
  reeds: `<svg viewBox="0 0 40 40" width="34" height="34"><g stroke="${P.hopGreenDeep}" stroke-width="3" fill="none" stroke-linecap="round"><path d="M14 32 C13 24 14 18 16 13"/><path d="M22 32 C22 23 23 17 25 12"/></g><ellipse cx="25" cy="10" rx="3" ry="6" fill="${P.sand300}"/></svg>`,
  fish: `<svg viewBox="0 0 40 40" width="34" height="34"><ellipse cx="18" cy="20" rx="11" ry="7" fill="${P.peachPop}"/><path d="M28 20 L36 14 L36 26Z" fill="${P.peachPop}"/><circle cx="13" cy="18" r="1.8" fill="${INK}"/></svg>`,
  cloud: `<svg viewBox="0 0 40 40" width="34" height="34"><g fill="${P.pondBlueLight}"><ellipse cx="20" cy="24" rx="15" ry="6"/><circle cx="14" cy="20" r="6"/><circle cx="22" cy="17" r="8"/></g></svg>`,
  flowerY: `<svg viewBox="0 0 40 40" width="34" height="34"><g transform="translate(20 20)">${[0, 72, 144, 216, 288].map((a) => `<ellipse cx="0" cy="-8" rx="5" ry="7" fill="${P.sunshine}" transform="rotate(${a})"/>`).join('')}<circle r="4" fill="${P.sunshineDeep}"/></g></svg>`,
  flowerP: `<svg viewBox="0 0 40 40" width="34" height="34"><g transform="translate(20 20)">${[0, 72, 144, 216, 288].map((a) => `<ellipse cx="0" cy="-8" rx="5" ry="7" fill="${P.peachPop}" transform="rotate(${a})"/>`).join('')}<circle r="4" fill="${P.sunshineSoft}"/></g></svg>`,
  stone: `<svg viewBox="0 0 40 40" width="34" height="34"><ellipse cx="20" cy="24" rx="14" ry="9" fill="${P.sand300}"/><ellipse cx="16" cy="21" rx="6" ry="3" fill="${P.sand100}" opacity=".7"/></svg>`,
  tadpole: `<svg viewBox="0 0 40 40" width="34" height="34"><circle cx="16" cy="20" r="8" fill="${P.hopGreenDeep}"/><path d="M23 20 C28 15 32 25 36 20 C32 22 28 26 23 20Z" fill="${P.hopGreenDeep}"/><circle cx="14" cy="18" r="2" fill="#FFFFFF"/></svg>`,
  butterfly: `<svg viewBox="0 0 40 40" width="34" height="34"><ellipse cx="12" cy="18" rx="8" ry="10" fill="${P.pondBlueLight}" transform="rotate(-22 12 18)"/><ellipse cx="28" cy="18" rx="8" ry="10" fill="${P.pondBlue}" transform="rotate(22 28 18)"/><rect x="18.4" y="10" width="3.2" height="18" rx="1.6" fill="${INK}" opacity=".7"/></svg>`,
  lilyFlower: `<svg viewBox="0 0 40 40" width="34" height="34"><g transform="translate(20 21)">${[0, 60, 120, 180, 240, 300].map((a) => `<ellipse cx="0" cy="-7" rx="4" ry="8" fill="#FFFFFF" stroke="${P.sand200}" stroke-width="1" transform="rotate(${a})"/>`).join('')}<circle r="3.4" fill="${P.sunshine}"/></g></svg>`,
};

function hopsPond(appearance = 'light') {
  const col = c(appearance);
  // Inline, not an `<img>`: the pond exposes stable ids (`pond-ripples`,
  // `pond-lily-1`, `pond-reeds`, …) and the web prototype's motion layer has to
  // be able to reach them. An `<img>` would seal them off.
  const scene = artOrInline(['Art/pond/pond-scene.svg', 'Art/scenes/pond.svg'], { width: 393, height: 852 },
    scenes.pond(393, 852, UNLOCKED));

  const tile = (inner, { locked = false, cost } = {}) => `
    <div style="width:56px;flex:0 0 auto;display:flex;flex-direction:column;align-items:center;gap:5px">
      <div style="width:56px;height:56px;border-radius:18px;display:grid;place-items:center;
        ${locked
          ? `background:${alpha(P.sand100, .85)};border:1.5px dashed ${P.sand300}`
          : `background:#FFFFFF;box-shadow:${elevation(appearance, 'resting')}`}">
        ${inner}
      </div>
      ${locked ? `<div style="display:flex;align-items:center;gap:3px">
          ${MARK.star(P.sunshineBright, 11)}
          <span style="${type('parentFootnote', { color: P.sand600, weight: 'semibold' })}">${cost}</span>
        </div>` : `<div style="height:14px"></div>`}
    </div>`;

  const lockedGlyph = `<svg viewBox="0 0 24 24" width="20" height="20" fill="${P.sand300}"><path d="M7 10V8a5 5 0 0 1 10 0v2h.6A1.4 1.4 0 0 1 19 11.4v8.2a1.4 1.4 0 0 1-1.4 1.4H6.4A1.4 1.4 0 0 1 5 19.6v-8.2A1.4 1.4 0 0 1 6.4 10zm2.2 0h5.6V8a2.8 2.8 0 0 0-5.6 0z"/></svg>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden">
    <div style="position:absolute;inset:0">${scene}</div>
    <div data-hop style="position:absolute;left:${393 * 0.56}px;top:${852 * 0.508 - 6 - 166 * FEET}px;
      transform:translateX(-50%)">
      ${svg('Art/character/hop-idle.svg', { width: 166 })}
    </div>

    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}

      <div class="fit" style="flex:1;display:flex;flex-direction:column;padding:0 20px 6px;overflow:hidden">
        <div style="flex:0 0 auto;display:flex;align-items:center;gap:12px;height:52px">
          <div style="width:48px;height:48px;border-radius:24px;background:${alpha('#FFFFFF', .82)};
            display:grid;place-items:center;flex:0 0 auto">
            <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="${P.sand600}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>
          </div>
          <div style="flex:1;text-align:center;${type('childTitle', { color: INK })};font-size:26px">Maya's pond</div>
          <div style="height:44px;padding:0 15px 0 11px;border-radius:22px;background:${alpha('#FFFFFF', .88)};
            display:flex;align-items:center;gap:6px;flex:0 0 auto">
            ${MARK.star(P.sunshineBright, 21)}
            <span style="${type('buttonLarge', { color: P.sunshineDeep })};font-size:19px">13</span>
          </div>
        </div>

        <div style="flex:1"></div>

        <div style="flex:0 0 auto;background:${alpha('#FFFFFF', .92)};border-radius:${T.radius.xl}px;
          padding:14px 0 12px;box-shadow:0 2px 14px ${alpha(INK, .1)}">
          <div style="display:flex;align-items:baseline;justify-content:space-between;padding:0 16px">
            <span style="${type('childInstruction', { color: INK })};font-size:19px">Decorations</span>
            <span style="${type('buttonLarge', { color: P.hopGreenInk })};font-size:18px">12 / 41</span>
          </div>
          <div style="display:flex;align-items:center;gap:7px;padding:4px 16px 0">
            ${MARK.star(P.sunshineBright, 14)}
            <span style="${type('parentCallout', { color: P.sand600 })}">3 more stars and a dragonfly hops in!</span>
          </div>
          <div style="display:flex;justify-content:space-between;padding:11px 16px 0">
            ${tile(THUMB.lilyPad)}
            ${tile(THUMB.fish)}
            ${tile(THUMB.butterfly)}
            ${tile(THUMB.flowerY)}
            ${tile(lockedGlyph, { locked: true, cost: 3 })}
          </div>
        </div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

module.exports = { hopsPond, UNLOCKED, THUMB };
