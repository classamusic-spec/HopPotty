/**
 * 10 — Hop's Pond.
 *
 * The reward is a place, not a score. Every star spends on something that stays
 * in the scene, the price of the next thing is visible in advance, and there is
 * no randomness anywhere — `PondCatalog` fixes the order and the cost, so a
 * child always knows what is coming and how far away it is.
 *
 * ## The scene is the screen
 *
 * The pond fills it edge to edge and the child's own decorations are drawn *in
 * it*, at the anchors `PondCatalog` gives them, at the size the app draws them.
 * An earlier version of this screen showed a base pond with nothing of the
 * child's in it and put their twelve decorations in a row of 56px tiles at the
 * bottom, which is a trophy cabinet with a wallpaper behind it. Everything else
 * here — the title, the star count, what is coming next, the collection — floats
 * over the water as chrome, and the collection tray is deliberately shallow: it
 * is a way of finding a thing by name, not the point of the screen.
 *
 * Mirrors `PondScreen.swift` and `PondSceneView.swift`: same anchors, same
 * `0.155 × scale` item size, same layer order, same tray.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation, artOrInline } = require('./ui');
const { MARK } = require('./kit');
const scenes = require('./scenes');
const { FEET } = require('./child');
const P = T.palette;
const INK = P.midnight;

/** The first twelve items of `PondCatalog`, in catalogue order — 13 stars' worth. */
const UNLOCKED = scenes.POND_ORDER.slice(0, 12);

/** Thumbnails for the collection tray. Small, flat, readable at 34px. */
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

/** Where Hop stands, and how big he is — `PondGeometry` in the app. */
const HOP = { x: 0.5, y: 0.665, extent: 0.22 };

/**
 * Hop on his pad, grounded.
 *
 * The pad and the contact shadow are drawn here rather than left to the
 * backdrop for the reason §25 gives: he has to read against green plants
 * *without* a card behind him, and a deep-green pad plus one soft shadow
 * ellipse is what a card would otherwise have been doing.
 */
function hopOnHisPad(w, h) {
  const cx = w * HOP.x;
  const cy = h * HOP.y;
  const side = w * HOP.extent;
  const r = side * 0.62;
  const padDeep = mix(P.hopGreenDeep, P.pondBlueDeep, 0.18);
  return `
    <svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="position:absolute;inset:0;display:block">
      <g id="pond-hop-pad">
        <path d="M ${cx - r} ${cy} a ${r} ${r * 0.30} 0 1 0 ${r * 2} 0 a ${r} ${r * 0.30} 0 1 0 ${-r * 2} 0 Z
                 M ${cx} ${cy} L ${cx + r * 0.86} ${cy - r * 0.20} L ${cx + r * 0.7} ${cy - r * 0.27} Z"
              fill="${padDeep}" fill-rule="evenodd"/>
        <ellipse cx="${cx - r * 0.22}" cy="${cy - r * 0.155}" rx="${r * 0.5}" ry="${r * 0.085}" fill="#FFFFFF" opacity="0.18"/>
        <ellipse cx="${cx}" cy="${cy}" rx="${side * 0.26}" ry="${side * 0.055}" fill="${P.pondBlueInk}" opacity="0.20"/>
      </g>
    </svg>
    <div data-hop style="position:absolute;left:${cx}px;top:${cy - side * FEET}px;transform:translateX(-50%)">
      ${svg('Art/character/hop-idle.svg', { width: side })}
    </div>`;
}

function hopsPond(appearance = 'light') {
  const col = c(appearance);
  const W = 393, H = 852;

  // Inline, not an `<img>`: the pond exposes stable ids (`pond-ripples`,
  // `pond-lily-1`, `pond-reeds`, …) and the web prototype's motion layer has to
  // be able to reach them. An `<img>` would seal them off.
  const scene = artOrInline(['Art/pond/pond-scene.svg', 'Art/scenes/pond.svg'], { width: W, height: H, fit: 'slice' },
    scenes.pond(W, H, UNLOCKED));

  // The child's own twelve, in the world, at PondCatalog's anchors — with Hop
  // composited between the `decoration` and `foreground` layers, which is where
  // `PondLayer` puts him.
  const decorations = scenes.pondDecorations(W, H, UNLOCKED, { before: [hopOnHisPad(W, H)] });

  const pill = (inner, pad = '0 15px') => `
    <div style="height:44px;padding:${pad};border-radius:22px;background:${alpha('#FFFFFF', .94)};
      display:flex;align-items:center;gap:6px;flex:0 0 auto;box-shadow:${elevation(appearance, 'resting')}">${inner}</div>`;

  const tile = (inner, { locked = false, cost } = {}) => `
    <div style="width:52px;flex:0 0 auto;display:flex;flex-direction:column;align-items:center;gap:4px">
      <div style="width:52px;height:52px;border-radius:17px;display:grid;place-items:center;
        ${locked
          ? `background:${alpha(P.sand100, .85)};border:1.5px dashed ${P.sand300}`
          : `background:#FFFFFF;border:2px solid ${alpha(P.sunshineBright, .8)}`}">
        ${inner}
      </div>
      ${locked ? `<div style="display:flex;align-items:center;gap:3px">
          ${MARK.star(P.sunshineBright, 10)}
          <span style="${type('parentFootnote', { color: P.sand600, weight: 'semibold' })};font-size:11px">${cost}</span>
        </div>` : `<div style="${type('parentFootnote', { color: P.hopGreenInk, weight: 'semibold' })};font-size:11px">Yours!</div>`}
    </div>`;

  const lockedGlyph = `<svg viewBox="0 0 24 24" width="18" height="18" fill="${P.sand300}"><path d="M7 10V8a5 5 0 0 1 10 0v2h.6A1.4 1.4 0 0 1 19 11.4v8.2a1.4 1.4 0 0 1-1.4 1.4H6.4A1.4 1.4 0 0 1 5 19.6v-8.2A1.4 1.4 0 0 1 6.4 10zm2.2 0h5.6V8a2.8 2.8 0 0 0-5.6 0z"/></svg>`;

  return `
  <div style="position:relative;width:100%;height:100%;overflow:hidden">
    <div style="position:absolute;inset:0">${scene}</div>
    <div style="position:absolute;inset:0">${decorations}</div>

    <div style="position:relative;display:flex;flex-direction:column;height:100%">
      ${statusBar(INK)}

      <div class="fit" style="flex:1;display:flex;flex-direction:column;overflow:hidden">
        <!-- chrome, floating over the water -->
        <div style="flex:0 0 auto;display:flex;align-items:center;gap:8px;padding:4px 20px 0">
          ${pill(`<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="${P.hopGreenDeep}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>`, '0 10px')}
          <div style="flex:1"></div>
          ${pill(`<span style="${type('childTitle', { color: INK })};font-size:22px">Maya's pond</span>`, '0 16px')}
          <div style="flex:1"></div>
          ${pill(`${MARK.star(P.sunshineBright, 20)}<span style="${type('buttonLarge', { color: P.sunshineDeep })};font-size:18px">13</span>`, '0 14px 0 11px')}
        </div>

        <div style="flex:1"></div>

        <!-- the tray: what is coming, then the collection. Shallow on purpose. -->
        <div style="flex:0 0 auto;background:${alpha('#FFFFFF', .96)};border-radius:${T.radius.hero}px ${T.radius.hero}px 0 0;
          padding:16px 20px 4px;box-shadow:0 -2px 20px ${alpha(INK, .12)}">
          <div style="display:flex;align-items:center;gap:12px">
            <div style="width:52px;height:52px;flex:0 0 auto;opacity:.42;display:grid;place-items:center">
              ${svg('Art/pond/dragonfly.svg', { width: 52, height: 52 })}
            </div>
            <div style="flex:1;${type('childInstruction', { color: INK })};font-size:18px">3 more stars and a dragonfly hops in!</div>
            <div style="width:38px;height:38px;flex:0 0 auto;border-radius:19px;
              background:conic-gradient(${col.brandAction} 0 62%, ${alpha(col.brandAction, .18)} 62% 100%);
              -webkit-mask:radial-gradient(circle, transparent 12px, #000 12px);
              mask:radial-gradient(circle, transparent 12px, #000 12px)"></div>
          </div>

          <div style="display:flex;align-items:baseline;gap:8px;padding-top:14px">
            <span style="${type('parentTitle', { color: INK })};font-size:17px">Your collection</span>
            <span style="${type('parentCallout', { color: P.sand600 })}">12 of 41</span>
          </div>
          <div style="display:flex;gap:9px;padding-top:8px;overflow:hidden">
            ${tile(THUMB.lilyPad)}
            ${tile(THUMB.reeds)}
            ${tile(THUMB.fish)}
            ${tile(THUMB.cloud)}
            ${tile(THUMB.flowerY)}
            ${tile(lockedGlyph, { locked: true, cost: 16 })}
          </div>
        </div>
      </div>
      ${homeIndicator(INK)}
    </div>
  </div>`;
}

module.exports = { hopsPond, UNLOCKED, THUMB };
