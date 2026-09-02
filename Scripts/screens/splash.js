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
const { c, svgInline, statusBar, ROOT } = require('./ui');

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

function splash(appearance = 'light') {
  const col = c(appearance);
  const width = logoWidth();
  const height = width * METRICS.viewBox.height / METRICS.viewBox.width;

  const backs = METRICS.paintOrder.map((l) => layerPart(l, 'back', width, height)).join('');
  const faces = METRICS.paintOrder.map((l) => layerPart(l, 'face', width, height)).join('');

  return `
  <div class="hp-splash" style="position:relative;width:100%;height:100%;background:${col.backgroundPrimary};overflow:hidden">
    ${statusBar(col.textPrimary)}
    <div style="position:absolute;inset:0;display:grid;place-items:center">
      <div class="hp-splash-logo" style="position:relative;width:${width}px;height:${height}px"
        role="img" aria-label="HopPotty">${backs}${faces}</div>
    </div>
  </div>`;
}

module.exports = { splash, logoWidth, METRICS, LOGO_WIDTH_FRACTION, LOGO_MAX_WIDTH, DEVICE_WIDTH };
