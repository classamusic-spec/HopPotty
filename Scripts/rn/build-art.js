#!/usr/bin/env node
/**
 * Generates the React Native illustration catalogue from `Art/`.
 *
 * ## Why the app's own SVGs rather than new drawings
 *
 * The SwiftUI app draws every illustration through `HopArtwork(key)`, resolving
 * a `HopIllustrationKey` to an asset in the catalogue that `build-assets.sh`
 * fills from `Art/`. React Native asks for the same keys and gets the same
 * files, so a pond, a bathroom or a game backdrop is *the same drawing* in both
 * apps rather than a redraw that slowly diverges. The key list comes from
 * `Scripts/art-keys.sh`, which is also what `check-art.sh` and
 * `build-assets.sh` use, so none of the three can drift apart.
 *
 * ## Why ids are namespaced
 *
 * These files each define their own gradients and clip paths as `id="a"`,
 * `id="b"`. That is fine in isolation and broken the moment two of them render
 * on one screen: SVG ids are global to the document, so the second `linearGradient`
 * named `a` silently wins and an illustration is painted with another's sky.
 * Every id is therefore prefixed with its key, and every `url(#…)` reference
 * rewritten to match.
 *
 *   Scripts/rn/build-art.js          regenerate
 *   Scripts/rn/build-art.js --check  verify, change nothing
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const { parse, tighten, verifyFaithful } = require('./svg-scene');

const ROOT = path.join(__dirname, '..', '..');
const OUT = path.join(ROOT, 'src', 'art', 'artwork.generated.ts');

/** The same key list the Swift asset catalogue is built from. */
function artKeys() {
  const out = execFileSync('bash', ['-c', `source "${ROOT}/Scripts/art-keys.sh"; art_keys`], {
    encoding: 'utf8',
  });
  return out
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .map((l) => {
      const [family, name] = l.split(/\s+/);
      return { family, name };
    });
}

/** `pond/lilyPad` → the key the content layer writes: `pond.lilyPad`. */
function illustrationKey(family, name) {
  const head = { scenes: 'scene', icons: 'icon', character: 'character', pond: 'pond' }[family];
  return `${head}.${name.split('-').join('.')}`;
}

const keys = artKeys();
const assets = {};
let elementCount = 0;
let missing = 0;

for (const { family, name } of keys) {
  const file = path.join(ROOT, 'Art', family, `${name}.svg`);
  if (!fs.existsSync(file)) {
    console.error(`build-art: no drawing for ${family}/${name}.svg — see Scripts/check-art.sh`);
    missing += 1;
    continue;
  }
  const svg = fs.readFileSync(file, 'utf8');

  // Namespace so two illustrations on one screen cannot capture each other's
  // gradients. Applied identically to the tree and to the verification scan.
  const ns = `${family}_${name}`.replace(/[^A-Za-z0-9_]/g, '_');
  const rewrite = (prop, value) => {
    if (prop === 'id') return `${ns}__${value}`;
    return value.replace(/url\(#([^)]+)\)/g, (_, id) => `url(#${ns}__${id})`);
  };

  const applyRewrite = (node) => {
    const p = {};
    for (const [k, v] of Object.entries(node.p)) {
      p[k] = typeof v === 'string' ? rewrite(k, v) : v;
    }
    const out = { t: node.t, p };
    if (node.x !== undefined) out.x = node.x;
    if (node.c) out.c = node.c.map(applyRewrite);
    return out;
  };

  const parsed = tighten(parse(svg));
  if (parsed.t !== 'svg') throw new Error(`${family}/${name}: root is <${parsed.t}>, expected <svg>`);

  const viewBox = String(parsed.p.viewBox ?? `0 0 ${parsed.p.width ?? 100} ${parsed.p.height ?? 100}`);
  const children = (parsed.c ?? []).map(applyRewrite);
  // The wrapper's own width/height are dropped: the component sizes the
  // drawing, and baking a pixel size in would defeat the vector.
  const tree = { t: 'g', p: {}, c: children };

  elementCount += verifyFaithful(`${family}/${name}`, svg, tree, {
    skipRoot: 'svg',
    rewrite,
    syntheticRoot: true,
  });

  assets[illustrationKey(family, name)] = { viewBox, tree };
}

if (missing) {
  console.error(`build-art: ${missing} key(s) have no drawing`);
  process.exit(1);
}

const names = Object.keys(assets).sort();
const lines = [];
lines.push('/**');
lines.push(' * GENERATED FILE — DO NOT EDIT.');
lines.push(' *');
lines.push(" * The app's illustrations, parsed from `Art/` at build time. These are the");
lines.push(' * same drawings the SwiftUI app loads from its asset catalogue, reached by the');
lines.push(' * same `HopIllustrationKey` strings, so the two apps cannot diverge.');
lines.push(' *');
lines.push(' * Regenerate:  node Scripts/rn/build-art.js');
lines.push(' * Verify:      node Scripts/rn/build-art.js --check');
lines.push(' */');
lines.push("import type { HopNode } from '../mascot/poses.generated';");
lines.push('');
lines.push('export interface HopArtworkAsset {');
lines.push('  readonly viewBox: string;');
lines.push('  readonly tree: HopNode;');
lines.push('}');
lines.push('');
lines.push(`export type HopIllustrationKey = ${names.map((n) => JSON.stringify(n)).join(' | ')};`);
lines.push('');
lines.push('export const HOP_ARTWORK: Readonly<Record<HopIllustrationKey, HopArtworkAsset>> =');
lines.push(JSON.stringify(assets) + ';');
lines.push('');

const out = lines.join('\n');
const check = process.argv.includes('--check');
const existing = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : null;

if (check) {
  if (existing !== out) {
    console.error('STALE: the React Native illustrations no longer match Art/.');
    console.error('       run: node Scripts/rn/build-art.js');
    process.exit(1);
  }
  console.log(
    `react native art: current  (${names.length} illustrations, ${elementCount} elements verified against Art/)`,
  );
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, out);
  console.log(
    `wrote src/art/artwork.generated.ts  (${names.length} illustrations, ${(Buffer.byteLength(out) / 1024).toFixed(0)} KB)`,
  );
  console.log(`  ${elementCount} elements verified identical to Art/`);
}
