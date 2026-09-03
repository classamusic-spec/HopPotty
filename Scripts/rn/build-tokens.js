#!/usr/bin/env node
/**
 * Generates the React Native design system from the app's own design tokens.
 *
 * ## Why this is generated
 *
 * `HopPottyDesignTokens` (Swift) is the single source of truth for every
 * colour, radius, type style and motion curve in HopPotty. The `hoptokens`
 * executable already exports it to `Scripts/tokens.json` so the render harness
 * cannot drift from the app. React Native is now a third consumer of the same
 * values, and hand-copying them into TypeScript would reintroduce exactly the
 * drift that export was built to prevent — the migration brief's own rule
 * against "magic hex codes scattered across screens".
 *
 * So the TypeScript design system is generated, and `--check` fails the build
 * if the committed file no longer matches the Swift tokens. A designer changing
 * one Swift colour updates SwiftUI, the renders and React Native together.
 *
 *   Scripts/rn/build-tokens.js          regenerate
 *   Scripts/rn/build-tokens.js --check  verify, change nothing
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const SRC = path.join(ROOT, 'Scripts', 'tokens.json');
const OUT = path.join(ROOT, 'src', 'design-system', 'tokens.generated.ts');

const T = JSON.parse(fs.readFileSync(SRC, 'utf8'));

const q = (s) => JSON.stringify(s);
const keysOf = (o) => Object.keys(o).sort();

/** A TS object literal, one key per line, sorted so the diff is stable. */
function obj(o, indent, valueFor) {
  const pad = ' '.repeat(indent);
  return keysOf(o).map((k) => `${pad}${k}: ${valueFor(o[k], k)},`).join('\n');
}

const appearanceNames = keysOf(T.appearances);
const colorNames = keysOf(T.appearances[appearanceNames[0]]);

// Every appearance must define every colour, or a screen would read
// `undefined` and paint transparent in exactly one theme.
for (const a of appearanceNames) {
  const missing = colorNames.filter((c) => !(c in T.appearances[a]));
  if (missing.length) {
    console.error(`build-tokens: appearance "${a}" is missing ${missing.join(', ')}`);
    process.exit(1);
  }
}

const lines = [];
lines.push('/**');
lines.push(' * GENERATED FILE — DO NOT EDIT.');
lines.push(' *');
lines.push(' * Source of truth: HopPottyKit/Sources/HopPottyDesignTokens (Swift),');
lines.push(' * exported by the `hoptokens` executable to Scripts/tokens.json.');
lines.push(' *');
lines.push(' * Regenerate:  node Scripts/rn/build-tokens.js');
lines.push(' * Verify:      node Scripts/rn/build-tokens.js --check');
lines.push(' */');
lines.push('');

// ---- appearances -----------------------------------------------------------
lines.push(`export type HopAppearance = ${appearanceNames.map(q).join(' | ')};`);
lines.push('');
lines.push('export interface HopSemanticColors {');
lines.push(colorNames.map((c) => `  readonly ${c}: string;`).join('\n'));
lines.push('}');
lines.push('');
lines.push('export const appearances: Readonly<Record<HopAppearance, HopSemanticColors>> = {');
for (const a of appearanceNames) {
  lines.push(`  ${a}: {`);
  lines.push(obj(T.appearances[a], 4, (v) => q(v)));
  lines.push('  },');
}
lines.push('};');
lines.push('');

// ---- palette ---------------------------------------------------------------
// The raw brand ramp. Screens should reach for `appearances[...]` semantics;
// the palette exists for art and for tokens that are deliberately theme-fixed.
lines.push('export const palette = {');
lines.push(obj(T.palette, 2, (v) => q(v)));
lines.push('} as const;');
lines.push('');
lines.push('export type HopPaletteName = keyof typeof palette;');
lines.push('');

// ---- scalar scales ---------------------------------------------------------
for (const [name, comment] of [
  ['spacing', 'Layout rhythm, in points.'],
  ['radius', 'Corner radii, in points.'],
  ['hitTarget', 'Minimum touch targets. `child*` values are deliberately large.'],
]) {
  lines.push(`/** ${comment} */`);
  lines.push(`export const ${name} = {`);
  lines.push(obj(T[name], 2, (v) => String(v)));
  lines.push('} as const;');
  lines.push('');
}

// ---- typography ------------------------------------------------------------
lines.push('export interface HopTypeStyle {');
lines.push('  readonly family: string;');
lines.push('  readonly size: number;');
lines.push('  readonly weight: string;');
lines.push('  readonly lineHeight: number;');
lines.push('  readonly tracking: number;');
lines.push('  /** Whether this style participates in Dynamic Type scaling. */');
lines.push('  readonly scales: boolean;');
lines.push('}');
lines.push('');
lines.push('export const typography = {');
for (const k of keysOf(T.typography)) {
  const s = T.typography[k];
  lines.push(`  ${k}: { family: ${q(s.family)}, size: ${s.size}, weight: ${q(s.weight)}, ` +
    `lineHeight: ${s.lineHeight}, tracking: ${s.tracking}, scales: ${s.scales} },`);
}
lines.push('} as const satisfies Readonly<Record<string, HopTypeStyle>>;');
lines.push('');
lines.push('export type HopTypeStyleName = keyof typeof typography;');
lines.push('');

// ---- motion ----------------------------------------------------------------
lines.push('export interface HopMotionSpec {');
lines.push('  /** Seconds. */');
lines.push('  readonly duration: number;');
lines.push('  /** SwiftUI spring bounce, 0 = critically damped. */');
lines.push('  readonly bounce: number;');
lines.push('}');
lines.push('');
lines.push('export const motion = {');
for (const k of keysOf(T.motion)) {
  lines.push(`  ${k}: { duration: ${T.motion[k].duration}, bounce: ${T.motion[k].bounce} },`);
}
lines.push('} as const satisfies Readonly<Record<string, HopMotionSpec>>;');
lines.push('');
lines.push('export type HopMotionName = keyof typeof motion;');
lines.push('');

const out = lines.join('\n');

const check = process.argv.includes('--check');
const existing = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : null;

if (check) {
  if (existing === null) {
    console.error('STALE: src/design-system/tokens.generated.ts does not exist.');
    console.error('       run: node Scripts/rn/build-tokens.js');
    process.exit(1);
  }
  if (existing !== out) {
    console.error('STALE: the React Native tokens no longer match the Swift design tokens.');
    console.error('       run: node Scripts/rn/build-tokens.js');
    process.exit(1);
  }
  console.log(`react native tokens: current  (${appearanceNames.length} appearances, ` +
    `${colorNames.length} semantic colours, ${Object.keys(T.palette).length} palette, ` +
    `${Object.keys(T.typography).length} type styles, ${Object.keys(T.motion).length} motion)`);
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, out);
  console.log(`wrote src/design-system/tokens.generated.ts  ` +
    `(${appearanceNames.length} appearances, ${colorNames.length} semantic colours, ` +
    `${Object.keys(T.palette).length} palette, ${Object.keys(T.typography).length} type styles)`);
}
