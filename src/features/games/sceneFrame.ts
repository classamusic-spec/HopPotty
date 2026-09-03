/**
 * The mapping from an illustration's own coordinates to points on a board.
 *
 * Every scene in `Art/scenes/` is drawn on a 640×480 canvas, and the render
 * harness places every sprite in *that* space — `Scripts/screens/child-extra.js`
 * says a lily pad is at (206, 390), not at "38% across". Keeping the same space
 * here means the sprite positions can be copied out of the harness verbatim
 * rather than re-derived by eye, which is the one thing
 * `Docs/ReactNativeConventions.md` asks a port not to do.
 *
 * This is the harness's own `bandFrame()` generalised to any board width: the
 * picture is painted to *cover* its band, so past the scene's 4:3 the art scales
 * up and its sides run off rather than letterboxing, and `x`/`y` carry that crop
 * offset. They are therefore positions, not lengths — a radius or a stroke
 * length is `len()`.
 */

/** The canvas every illustration is drawn on. */
export const SCENE = { width: 640, height: 480 } as const;

/**
 * The widest a board is drawn.
 *
 * iPad is a first-class layout rather than a stretched phone: past the scene's
 * own width the picture would be upscaled past its drawn resolution and the
 * pieces would stop being hand-sized, so the board stops growing and centres.
 */
export const MAX_BOARD_WIDTH = SCENE.width;

export interface SceneFrame {
  /** The band's size in points. */
  readonly width: number;
  readonly height: number;
  /** Points per scene unit. */
  readonly scale: number;
  /** A scene x coordinate, in board points. */
  x(v: number): number;
  /** A scene y coordinate, in board points. */
  y(v: number): number;
  /** A scene length — a radius, a sprite size — in board points. */
  len(v: number): number;
}

export function sceneFrame(width: number, height: number): SceneFrame {
  const scale = Math.max(width / SCENE.width, height / SCENE.height);
  const ox = (width - SCENE.width * scale) / 2;
  const oy = (height - SCENE.height * scale) / 2;
  return {
    width,
    height,
    scale,
    x: (v) => ox + v * scale,
    y: (v) => oy + v * scale,
    len: (v) => v * scale,
  };
}

/**
 * The band for a board, given the space it has and how tall it wants to be.
 *
 * `heightRatio` is the band's height as a multiple of its width. The default
 * 0.75 is the scenes' own 4:3, which shows the whole picture; a game whose board
 * *is* the picture asks for more and trades the edges of the scene for size,
 * exactly as `gameScreen`'s `bandHeight` does in the harness.
 */
export function boardFrame(availableWidth: number, heightRatio = 0.75): SceneFrame {
  const width = Math.min(availableWidth, MAX_BOARD_WIDTH);
  return sceneFrame(width, width * heightRatio);
}
