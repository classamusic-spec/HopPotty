/**
 * 00 — the launch animation.
 *
 * The first thing HopPotty draws, and the only screen in the walkthrough that
 * is not a screen: iOS paints a flat `LaunchBackground` before any of the app's
 * code runs, and this is the SwiftUI view that takes over from it. The ground
 * is `backgroundPrimary`, which is the colour the system just painted, so the
 * handover has nothing to show.
 *
 * ## The markup is a stack of layers, and the order matters twice
 *
 * `Scripts/logo-art.js` splits the lockup into four layers, each in two parts —
 * its rebuilt sticker outline (`-back`) and the artwork's own fills (`-face`).
 * Every outline is drawn first and every fill second, across all four layers,
 * because a layer drawn complete would put the frog's white edge on top of the
 * wordmark and bite a chunk out of the letters' crowns.
 *
 * The fills then go down in `logo-metrics.json`'s `paintOrder`, which puts the
 * frog *under* the two words — that is what lets it pop up from behind them
 * rather than across them.
 *
 * ## Why the layer files and not `Art/brand/hoppotty-logo.svg`
 *
 * Two reasons, and the second one is a trap. The lockup has to come apart for
 * the animation; and the artwork carries a `<style>` block of `.cls-0` … `.cls-18`
 * class names, which — inlined into a prototype that puts every screen in ONE
 * document — are global rules that repaint every other drawing on the page. The
 * generated layers carry inline fills and no `<style>` at all, and
 * `build-prototype.js` asserts that no `cls-` selector reaches the build.
 *
 * The motion lives in `Scripts/web/motion.js` (`splashCSS`), timed from the same
 * `HopMotion` tokens as `HopPotty/Features/Splash/HopSplashChoreography.swift`.
 * The base state here is the *assembled* lockup, so a still render — and a
 * reader with `prefers-reduced-motion: reduce`, where every animation is turned
 * off — sees the finished mark rather than a word waiting off-screen.
 */
const fs = require('fs');
const path = require('path');
const { c, svgInline, statusBar, ROOT, alpha } = require('./ui');
const scenes = require('./scenes');
const pondScreen = require('./pond');

const METRICS = JSON.parse(fs.readFileSync(path.join(ROOT, 'Scripts', 'web', 'logo-metrics.json'), 'utf8'));

/** The device the prototype draws, and the logo inside it. Mirrors `HopSplashChoreography`. */
const DEVICE_WIDTH = 393;
const LOGO_WIDTH_FRACTION = 0.74;
const LOGO_MAX_WIDTH = 360;

const logoWidth = (container = DEVICE_WIDTH) =>
  Math.min(container * LOGO_WIDTH_FRACTION, LOGO_MAX_WIDTH);

/**
 * Where a layer's squash is anchored, as a CSS `transform-origin`.
 *
 * The bottom of the layer's own drawing, not the bottom of the box it is drawn
 * in — the same reason `HopCanvas.groundAnchor` exists. "Hop" lands on the
 * baseline of its letters, twenty units above the bottom of a box that also has
 * to hold the tagline pill.
 */
function groundAnchor(layer) {
  const box = METRICS.layers[layer];
  return `50% ${(100 * (box.y + box.height) / METRICS.viewBox.height).toFixed(2)}%`;
}

function layerPart(layer, part, width, height) {
  const file = `Art/brand/layers/logo-${layer}-${part}.svg`;
  if (!fs.existsSync(path.join(ROOT, file))) return '';
  return `<div class="hp-sl hp-sl-${layer}" style="position:absolute;left:0;top:0;width:${width}px;height:${height}px;` +
    `transform-origin:${groundAnchor(layer)}">${svgInline(file, { width, height })}</div>`;
}

/**
 * The light behind the lockup.
 *
 * Decoration, and also the reason the wordmark survives being moved off a flat
 * cream ground onto water: the artwork's white sticker outline is a strong edge
 * against `backgroundPrimary` and a weak one against pale sky. A grey scrim over
 * the pond would fix that by making the pond worse; a warm bloom under the logo
 * fixes it by making the logo better.
 *
 * It never pulses. A throbbing shine is the oldest attention mechanic there is
 * and `Docs/ChildSafety.md` rules those out, so the rays and the bloom both hold
 * still: the whole thing arrives with the stage and leaves with it.
 */
function shine(width) {
  const size = Math.round(width * 1.46);
  const warm = '#FFF3D4';
  // Odd count, so no ray has a twin opposite it and the fan never reads as a
  // grid; alternating lengths, so it never reads as a wheel.
  const rays = 13;
  const slivers = Array.from({ length: rays }, (_, i) => {
    const step = 360 / rays;
    const reach = i % 2 === 0 ? 48 : 39;
    return `<polygon points="50,50 ${50 + reach},${50 - step * 0.15} ${50 + reach},${50 + step * 0.15}"
      fill="${warm}" transform="rotate(${(i * step).toFixed(2)} 50 50)"/>`;
  }).join('');

  return `<div class="hp-splash-shine" style="position:absolute;left:50%;top:50%;width:${size}px;height:${size}px;
    margin:-${size / 2}px 0 0 -${size / 2}px;pointer-events:none">
    <svg viewBox="0 0 100 100" width="${size}" height="${size}" style="display:block">
      <defs>
        <radialGradient id="hpShineBloom" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="${warm}" stop-opacity="0.6"/>
          <stop offset="42%" stop-color="${warm}" stop-opacity="0.2"/>
          <stop offset="100%" stop-color="${warm}" stop-opacity="0"/>
        </radialGradient>
        <!-- The rays fade out along their own length. Flat slivers read as
             paper cut-outs laid over the scene; light has to end in nothing. -->
        <radialGradient id="hpShineFade" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.85"/>
          <stop offset="52%" stop-color="#FFFFFF" stop-opacity="0.30"/>
          <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
        </radialGradient>
        <mask id="hpShineMask"><rect width="100" height="100" fill="url(#hpShineFade)"/></mask>
      </defs>
      <g mask="url(#hpShineMask)" opacity="0.78" style="filter:blur(0.85px)">${slivers}</g>
      <circle cx="50" cy="50" r="50" fill="url(#hpShineBloom)"/>
    </svg>
  </div>`;
}

function splash(appearance = 'light') {
  const col = c(appearance);
  const width = logoWidth();
  const height = width * METRICS.viewBox.height / METRICS.viewBox.width;

  const backs = METRICS.paintOrder.map((l) => layerPart(l, 'back', width, height)).join('');
  const faces = METRICS.paintOrder.map((l) => layerPart(l, 'face', width, height)).join('');

  // Hop's own pond, the place the app is set. `slice` because this is a crop of
  // a taller drawing, exactly as Home is. It is not the first frame — the CSS
  // fades `.hp-splash-stage` up out of the launch colour — because a handover
  // that went straight from a flat fill to a landscape would read as a flash.
  const pond = `<div class="hp-splash-stage" style="position:absolute;inset:0;overflow:hidden">
    ${svgInline('Art/pond/pond-scene.svg', { width: DEVICE_WIDTH, height: 852, fit: 'slice' })}
  </div>`;

  return `
  <div class="hp-splash" style="position:relative;width:100%;height:100%;background:${col.backgroundPrimary};overflow:hidden">
    ${pond}
    ${statusBar(col.textPrimary)}
    <div style="position:absolute;inset:0;display:grid;place-items:center">
      <div class="hp-splash-logo" style="position:relative;width:${width}px;height:${height}px"
        role="img" aria-label="HopPotty">
        <div class="hp-splash-stage">${shine(width)}</div>
        ${backs}${faces}
      </div>
    </div>
  </div>`;
}

module.exports = { splash, logoWidth, METRICS, LOGO_WIDTH_FRACTION, LOGO_MAX_WIDTH, DEVICE_WIDTH };
