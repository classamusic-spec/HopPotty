/**
 * Hermes Owlet — locked vector geometry.
 *
 * The art direction here is APPROVED AND LOCKED. This module is pure data: it
 * holds every path, anchor and colour the character is drawn from, so the SVG
 * renderer, the animation rig and the static asset exporter all read from one
 * source of truth. Change a number here and every consumer follows.
 *
 * Canvas is a 512x512 square so the head works as an app / tray / status icon
 * as well as a desktop companion. The character occupies roughly y 84..452.
 */

export const VIEW_BOX = { width: 512, height: 512 } as const;

/** Flat colour tokens. Do not introduce additional colours without a reason. */
export const HERMES_COLORS = {
  navy: '#17265C',
  navyDeep: '#101B44',
  navyLight: '#2E4794',
  cyan: '#29A9F5',
  cyanDim: '#2A86C4',
  cyanBright: '#7BD6FF',
  cream: '#FDF8EC',
  gold: '#FBBF45',
  goldDark: '#E3A32B',
  goldBright: '#FFDE8C',
  white: '#FFFFFF',
  concern: '#E8836F',
} as const;

export type HermesColorToken = keyof typeof HERMES_COLORS;

/**
 * Brightness is expressed as a flat colour step, not as a translucent overlay
 * or a filter: a semi-transparent "glow" laid over navy just reads as grey
 * mud, and filters cost GPU time a companion app should not spend. Index 0 is
 * fully dimmed, 5 is the locked gold, 10 is the brightest flash.
 */
export const GOLD_RAMP = [
  '#E3A32B',
  '#E8A930',
  '#EDAE35',
  '#F1B43B',
  '#F6B940',
  '#FBBF45',
  '#FCC553',
  '#FDCB61',
  '#FDD270',
  '#FED87E',
  '#FFDE8C',
] as const;

/** Stroke weights, in user units. The heavy navy outline is part of the design. */
export const STROKE = {
  silhouette: 7,
  detail: 6,
  fine: 5,
  halo: 11,
  brow: 8,
} as const;

/** Pivots and centres the rig animates around. */
export const ANCHORS = {
  /** Head rotates about a point low in the skull so a tilt reads as a neck tilt. */
  headPivot: { x: 256, y: 402 },
  tuftPivot: { x: 244, y: 246 },
  leftWingPivot: { x: 134, y: 356 },
  rightWingPivot: { x: 378, y: 356 },
  leftEye: { x: 190, y: 322 },
  rightEye: { x: 322, y: 322 },
  leftHeadphone: { x: 86, y: 352 },
  rightHeadphone: { x: 426, y: 352 },
  halo: { cx: 254, cy: 111, rx: 96, ry: 26 },
  foreheadStar: { x: 256, y: 226 },
  beakSeam: { x: 256, y: 375 },
  /** Eye geometry. The pupil never reaches the sclera edge. */
  eye: {
    scleraRadius: 48,
    irisRadius: 40,
    /** Navy core is offset up-and-right, leaving the cyan crescent lower-left. */
    coreOffset: { x: 11, y: -13 },
    highlightOffset: { x: 16, y: -18 },
    highlightRadius: 8,
    maxGazeX: 7,
    maxGazeY: 5,
  },
} as const;

/**
 * How far the lower beak may drop at full amplitude, in user units.
 * ~4% of face-mask height — deliberately conservative: the owl must never
 * read as a puppet.
 */
export const BEAK_MAX_DROP = 9;

export const PATHS = {
  crownTuft:
    'M 162 244 C 160 202 168 172 180 150 C 187 139 200 145 197 158 C 194 174 192 190 191 204 ' +
    'C 205 174 230 138 250 116 C 261 105 273 113 269 127 C 262 152 253 182 249 202 ' +
    'C 265 177 289 151 308 143 C 320 138 328 149 320 161 C 305 184 295 213 293 246 Z',

  headBase:
    'M 256 166 C 340 166 403 222 403 292 C 405 314 406 342 402 362 C 394 420 356 452 292 452 ' +
    'L 220 452 C 156 452 118 420 110 362 C 106 342 107 314 109 292 C 109 222 172 166 256 166 Z',

  faceMask:
    'M 256 285 C 250 256 240 228 220 213 C 197 197 165 206 146 229 C 129 249 118 277 117 307 ' +
    'C 116 333 116 353 118 369 C 123 413 158 443 206 443 L 306 443 C 354 443 389 413 394 369 ' +
    'C 396 353 396 333 395 307 C 394 277 383 249 366 229 C 347 206 315 197 292 213 ' +
    'C 272 228 262 256 256 285 Z',

  foreheadStar:
    'M 256 205 C 256 216 259 221 268 226 C 259 231 256 236 256 247 C 256 236 253 231 244 226 ' +
    'C 253 221 256 216 256 205 Z',

  haloSpark:
    'M 0 -13 C 0 -6 2 -3 10 0 C 2 3 0 6 0 13 C 0 6 -2 3 -10 0 C -2 -3 0 -6 0 -13 Z',

  /** Left wing: three overlapping cream feathers, drawn back-to-front. */
  wingFeathers: [
    'M 132 338 C 72 297 45 225 42 166 C 89 203 132 265 132 338 Z',
    'M 126 348 C 65 329 30 275 18 224 C 66 243 115 285 126 348 Z',
    'M 120 358 C 74 365 39 337 22 304 C 59 301 102 315 120 358 Z',
  ] as const,

  /** Gold inner feather accents, laid over the cream feathers. */
  wingAccents: [
    'M 102 324 C 75 302 63 266 60 238 C 81 258 101 290 102 324 Z',
    'M 98 348 C 73 338 59 314 54 292 C 73 302 93 322 98 348 Z',
  ] as const,

  /** Eye sclera, in eye-local coordinates; the outer-top corner is pointed. */
  scleraLeft:
    'M -29 -42 C -12 -50 8 -49 23 -40 C 40 -29 48 -12 48 5 C 48 28 27 48 0 48 ' +
    'C -27 48 -48 28 -48 5 C -48 -13 -41 -32 -29 -42 Z',
  scleraRight:
    'M 29 -42 C 12 -50 -8 -49 -23 -40 C -40 -29 -48 -12 -48 5 C -48 28 -27 48 0 48 ' +
    'C 27 48 48 28 48 5 C 48 -13 41 -32 29 -42 Z',

  /** Lids, in eye-local coordinates. Their leading edge carries the navy line. */
  upperLid: 'M -74 -104 L 74 -104 L 74 -12 C 46 6 -46 6 -74 -12 Z',
  lowerLid: 'M -74 104 L 74 104 L 74 12 C 46 -6 -46 -6 -74 12 Z',

  /** Brow, in eye-local coordinates. Hidden at neutral so the silhouette holds. */
  brow: 'M -30 0 C -14 -9 14 -9 30 0',

  /**
   * The beak is one diamond at rest and two halves when it opens, so each half
   * is drawn as a fill plus an OPEN outline that skips the shared seam. Without
   * that, a closed navy line would sit across the middle of the beak even when
   * the owl is silent, which the locked art does not have.
   */
  upperBeakFill:
    'M 256 345 C 259 345 262 346 264 349 L 278 368 C 280 371 279 377 275 377 L 237 377 ' +
    'C 233 377 232 371 234 368 L 248 349 C 250 346 253 345 256 345 Z',
  upperBeakEdge:
    'M 237 376 C 233 376 232 371 234 368 L 248 349 C 250 346 253 345 256 345 ' +
    'C 259 345 262 346 264 349 L 278 368 C 280 371 279 376 275 376',
  lowerBeakFill:
    'M 237 375 L 275 375 C 279 375 280 379 278 382 L 261 402 C 258 405 254 405 251 402 ' +
    'L 234 382 C 232 379 233 375 237 375 Z',
  lowerBeakEdge:
    'M 275 375 C 279 375 280 379 278 382 L 261 402 C 258 405 254 405 251 402 ' +
    'L 234 382 C 232 379 233 375 237 375',
} as const;

/** Blink drive. Lids are parked off-eye at 0 and overlap at 1. */
export const LID_TRAVEL = {
  upperParked: -104,
  upperClosed: 12,
  lowerParked: 104,
  lowerClosed: 4,
} as const;

/** Headphone ring radii, outer to inner. */
export const HEADPHONE = {
  glowRadius: 45,
  outerRadius: 35,
  cyanRadius: 23,
  innerRadius: 11,
} as const;
