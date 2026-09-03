#!/usr/bin/env node
/**
 * Generates Hop's React Native scene graph from the existing art rig.
 *
 * ## Why generated rather than redrawn
 *
 * `Scripts/hop-art.js` is the mascot rig: fifteen poses built from shared
 * anatomy, held to the silhouette, fit and cross-language contract gates. It is
 * already JavaScript, and it already emits named groups — `head`, `left-pupil`,
 * `right-arm`, `mouth` — which is precisely what an animatable React Native
 * character needs.
 *
 * Redrawing Hop in TSX would fork the character: two drawings, two sets of
 * geometry, and a gate that can only check one of them. Instead the rig's own
 * SVG output is parsed at BUILD time into a typed scene graph. Runtime does no
 * parsing, the geometry is provably the rig's, and `--check` fails if the two
 * ever diverge.
 *
 * `SvgXml` was rejected for the same reason it is tempting: it would render the
 * rig's string directly, but re-parse on every prop change and expose no handle
 * on `left-pupil`, so blinking, gaze and a waving arm would all be impossible.
 * A structured tree keeps every part addressable.
 *
 *   Scripts/rn/build-mascot.js          regenerate
 *   Scripts/rn/build-mascot.js --check  verify, change nothing
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const art = require(path.join(ROOT, 'Scripts', 'hop-art.js'));
const OUT = path.join(ROOT, 'src', 'mascot', 'poses.generated.ts');

const { PROP, parse, tighten, verifyFaithful } = require('./svg-scene');

const poses = {};
let elementCount = 0;
for (const name of art.POSE_NAMES) {
  const svg = art.poseSVG(name);
  const parsed = tighten(parse(svg));
  // The <svg> wrapper carries only the viewBox, which is constant and lives on
  // the component instead; the tree we ship starts at its single child.
  const root = parsed.t === 'svg' && parsed.c && parsed.c.length === 1 ? parsed.c[0] : parsed;
  elementCount += verifyFaithful(name, svg, root, { skipRoot: 'svg' });
  poses[name] = root;
}

const partIds = [...new Set(
  JSON.stringify(poses).match(/"id":"([^"]+)"/g)?.map((s) => s.slice(6, -1)) ?? []
)].sort();

const lines = [];
lines.push('/**');
lines.push(' * GENERATED FILE — DO NOT EDIT.');
lines.push(' *');
lines.push(' * Hop\'s pose geometry, parsed from the art rig (Scripts/hop-art.js) at build');
lines.push(' * time so React Native renders the same character the app and the render');
lines.push(' * harness draw, from the same source.');
lines.push(' *');
lines.push(' * Regenerate:  node Scripts/rn/build-mascot.js');
lines.push(' * Verify:      node Scripts/rn/build-mascot.js --check');
lines.push(' */');
lines.push('');
lines.push('/** One SVG element: tag, props, children. */');
lines.push('export interface HopNode {');
lines.push('  readonly t: string;');
lines.push('  readonly p: Readonly<Record<string, string | number>>;');
lines.push('  /** Literal text content — only the sleep pose\'s "Zzz" uses this. */');
lines.push('  readonly x?: string;');
lines.push('  readonly c?: readonly HopNode[];');
lines.push('}');
lines.push('');
lines.push(`export const HOP_VIEWBOX = ${art.CANVAS};`);
lines.push('');
lines.push('/** Feet sit this far down the canvas — used to seat Hop on a baseline. */');
lines.push(`export const HOP_FEET_FRACTION = ${art.FEET_FRACTION};`);
lines.push('');
lines.push(`export type HopPoseName = ${art.POSE_NAMES.map((p) => JSON.stringify(p)).join(' | ')};`);
lines.push('');
lines.push('/** Every addressable part id the rig emits, for animation targeting. */');
lines.push(`export type HopPartId = ${partIds.map((p) => JSON.stringify(p)).join(' | ')};`);
lines.push('');
lines.push('export const HOP_POSES: Readonly<Record<HopPoseName, HopNode>> = ');
lines.push(JSON.stringify(poses) + ';');
lines.push('');

/**
 * Every rig pose must be reachable from a product state.
 *
 * Screens ask for a state, never a pose — that indirection is what keeps
 * renaming a pose an art change. But it also means a pose no state maps to is
 * a drawing the app can never show, which is invisible until someone notices
 * the wrong frog. Two separate screen ports hit exactly that (`catch`, `full`,
 * `face`, `walk`), so it is checked rather than remembered.
 */
function verifyStateCoverage() {
  const statesFile = path.join(ROOT, 'src', 'mascot', 'hopStates.ts');
  if (!fs.existsSync(statesFile)) return;
  const src = fs.readFileSync(statesFile, 'utf8');
  const body = src.slice(src.indexOf('const POSE_FOR'), src.indexOf('export function hopPoseFor'));
  const mapped = new Set([...body.matchAll(/:\s*'([A-Za-z]+)'\s*,/g)].map((m) => m[1]));
  const unreachable = art.POSE_NAMES.filter((p) => !mapped.has(p));
  if (unreachable.length) {
    console.error(
      `build-mascot: ${unreachable.length} pose(s) no product state can reach: ${unreachable.join(', ')}`,
    );
    console.error('       add a state in src/mascot/hopStates.ts, or the app can never draw them.');
    process.exit(1);
  }
  const unknown = [...mapped].filter((m) => !art.POSE_NAMES.includes(m));
  if (unknown.length) {
    console.error(`build-mascot: hopStates.ts maps to pose(s) the rig does not draw: ${unknown.join(', ')}`);
    process.exit(1);
  }
  return mapped.size;
}
const posesReachable = verifyStateCoverage();

const out = lines.join('\n');
const check = process.argv.includes('--check');
const existing = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : null;

if (check) {
  if (existing !== out) {
    console.error('STALE: the React Native mascot no longer matches the art rig.');
    console.error('       run: node Scripts/rn/build-mascot.js');
    process.exit(1);
  }
  console.log(`react native mascot: current  (${art.POSE_NAMES.length} poses, ${partIds.length} named parts, ${elementCount} elements verified against the rig)`);
  if (posesReachable) console.log(`  all ${posesReachable} poses reachable from a product state`);
} else {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, out);
  const kb = (Buffer.byteLength(out) / 1024).toFixed(0);
  console.log(`wrote src/mascot/poses.generated.ts  (${art.POSE_NAMES.length} poses, ${partIds.length} named parts, ${kb} KB)`);
  console.log(`  ${elementCount} elements verified identical to the rig`);
}
