import type { HopIllustrationKey } from '../../art/HopArtwork';

/**
 * Where everything in Hop's Pond sits.
 *
 * The anchors, the layer order and the two geometry constants below are
 * `PondCatalog` and `PondGeometry` in the Swift app, and `POND_ANCHORS` /
 * `POND_LAYERS` in the render harness. They are repeated here rather than
 * imported because there is no generated TypeScript pond catalogue yet — the
 * art generator emits the *drawings* (`pond.<id>`) but not their placement. A
 * screen that made up its own coordinates would draw a different pond from the
 * one a child already has, so this table is the app's, verbatim.
 *
 * Coordinates are unit space inside the pond *stage* — the fixed-aspect
 * composition every pond screen places against — with `x` running left to right
 * and `y` from the sky down to the nearest thing to the viewer.
 */

/** Every pond decoration's id, derived from the generated artwork keys. */
export type PondItemId =
  Extract<HopIllustrationKey, `pond.${string}`> extends `pond.${infer Id}` ? Id : never;

/** The illustration key for a decoration. */
export function pondArtwork(id: PondItemId): HopIllustrationKey {
  return `pond.${id}` as HopIllustrationKey;
}

/** `[x, y, scale]` for each decoration, in unlock order. */
export const POND_ANCHORS: Readonly<Record<PondItemId, readonly [number, number, number]>> = {
  lilyPadSmall: [0.46, 0.64, 1.0],
  reedsLeft: [0.13, 0.6, 1.0],
  fishOrange: [0.66, 0.71, 0.9],
  cloudPuff: [0.74, 0.11, 1.0],
  flowerYellow: [0.26, 0.83, 0.85],
  lilyPadLarge: [0.59, 0.57, 1.1],
  reedsRight: [0.87, 0.58, 1.0],
  stoneSmall: [0.19, 0.76, 0.8],
  tadpoleFriend: [0.4, 0.74, 0.75],
  flowerPink: [0.78, 0.83, 0.85],
  butterflyBlue: [0.3, 0.55, 0.8],
  lilyFlower: [0.49, 0.585, 0.7],
  cattails: [0.08, 0.7, 1.0],
  fishBlue: [0.72, 0.66, 0.85],
  sunbeam: [0.22, 0.09, 1.0],
  mushroomCluster: [0.33, 0.88, 0.8],
  snail: [0.65, 0.87, 0.6],
  frogFriendGreen: [0.44, 0.62, 1.0],
  butterflyYellow: [0.7, 0.52, 0.8],
  flowerPurple: [0.9, 0.74, 0.85],
  rainbow: [0.5, 0.16, 1.0],
  stoneStack: [0.11, 0.84, 0.9],
  dragonfly: [0.52, 0.5, 0.7],
  waterLilyCluster: [0.28, 0.68, 1.0],
  duckling: [0.62, 0.79, 0.8],
  fernPatch: [0.16, 0.38, 1.0],
  ladybug: [0.24, 0.9, 0.5],
  signpost: [0.8, 0.9, 0.9],
  lantern: [0.86, 0.46, 0.8],
  turtleRock: [0.38, 0.55, 0.9],
  birdhouse: [0.82, 0.32, 0.9],
  pebblePath: [0.48, 0.9, 1.2],
  frogFriendBlue: [0.6, 0.545, 1.0],
  driftwood: [0.06, 0.5, 0.9],
  blossomTree: [0.1, 0.28, 1.3],
  windChime: [0.16, 0.4, 0.7],
  clubhouse: [0.5, 0.33, 1.2],
  pondSwing: [0.28, 0.52, 1.1],
  starLantern: [0.68, 0.4, 0.8],
  fireflies: [0.86, 0.66, 0.9],
  moonReflection: [0.52, 0.8, 1.0],
};

/** The unlock order `PondCatalog` prices the items in. */
export const POND_UNLOCK_ORDER = Object.keys(POND_ANCHORS) as readonly PondItemId[];

/**
 * Draw order, back to front — `PondLayer` in the app.
 *
 * Hop is composited between `decoration` and `foreground`, which is where the
 * app puts him, so a dragonfly passes in front of him and a lantern behind.
 */
export const POND_LAYERS: readonly (readonly PondItemId[])[] = [
  ['cloudPuff', 'sunbeam', 'rainbow'],
  ['fernPatch', 'birdhouse', 'blossomTree', 'clubhouse'],
  [
    'lilyPadSmall',
    'fishOrange',
    'lilyPadLarge',
    'tadpoleFriend',
    'lilyFlower',
    'fishBlue',
    'waterLilyCluster',
    'duckling',
    'turtleRock',
    'moonReflection',
  ],
  [
    'reedsLeft',
    'flowerYellow',
    'reedsRight',
    'stoneSmall',
    'flowerPink',
    'cattails',
    'mushroomCluster',
    'snail',
    'flowerPurple',
    'stoneStack',
    'signpost',
    'pebblePath',
    'driftwood',
  ],
  ['lantern', 'windChime', 'pondSwing', 'starLantern'],
];

/** Layers drawn in front of Hop. */
export const POND_FOREGROUND_LAYERS: readonly (readonly PondItemId[])[] = [
  ['frogFriendGreen', 'frogFriendBlue'],
  ['butterflyBlue', 'butterflyYellow', 'dragonfly', 'ladybug', 'fireflies'],
];

/** Width ÷ height of the stage composition. `PondGeometry.referenceAspect`. */
export const POND_ASPECT = 1.1;

/**
 * How the spare height on a tall phone is split above and below the stage.
 *
 * Biased downward so the extra room reads as sky over the horizon rather than
 * as an empty field under the pond.
 */
export const POND_BIAS = 0.55;

/** An item is drawn this fraction of the stage width, before its own scale. */
export const POND_ITEM_EXTENT = 0.155;

/** Where Hop sits, and how large. `PondGeometry` in the app. */
export const POND_HOP = { x: 0.5, y: 0.665, extent: 0.22 } as const;

export interface PondStageBox {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

/** The stage's rectangle inside a frame of `width` × `height` points. */
export function pondStageBox(width: number, height: number): PondStageBox {
  const stageHeight = width / POND_ASPECT;
  const slack = height - stageHeight;
  return {
    x: 0,
    y: slack >= 0 ? slack * POND_BIAS : slack * 0.5,
    width,
    height: stageHeight,
  };
}

/** A unit coordinate on the stage, in the frame's own points. */
export function pondPoint(
  box: PondStageBox,
  ux: number,
  uy: number,
): { readonly x: number; readonly y: number } {
  return { x: box.x + ux * box.width, y: box.y + uy * box.height };
}
