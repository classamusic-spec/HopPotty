/**
 * Every animated feature carries a stable `data-ho` name as well as a stable
 * `id`. The rig looks nodes up by `data-ho` so several Hermes Owlets can share
 * a page without their ids colliding, while `#head-root`, `#left-eye` and the
 * rest still resolve for tooling and design hand-off.
 */
export const RIG_NODE_KEYS = [
  'owlet-root',
  'halo-group',
  'halo',
  'halo-bloom',
  'halo-spark',
  'head-root',
  'crown-tuft',
  'left-wing',
  'right-wing',
  'head-base',
  'face-mask',
  'forehead-star-group',
  'forehead-star',
  'forehead-star-bloom',
  'left-eye',
  'right-eye',
  'left-pupil',
  'right-pupil',
  'left-pupil-core',
  'right-pupil-core',
  'left-lid',
  'right-lid',
  'left-lower-lid',
  'right-lower-lid',
  'left-brow',
  'right-brow',
  'beak',
  'upper-beak',
  'lower-beak',
  'beak-gap',
  'left-headphone',
  'right-headphone',
  'left-headphone-lit',
  'right-headphone-lit',
  'left-headphone-glow',
  'right-headphone-glow',
  'effects',
  'listening-glow',
  'thinking-spark',
  'speaking-pulse',
  'error-pulse',
] as const;

export type RigNodeKey = (typeof RIG_NODE_KEYS)[number];

export type RigNodes = Partial<Record<RigNodeKey, SVGElement>>;

export const collectRigNodes = (root: SVGSVGElement): RigNodes => {
  const nodes: RigNodes = {};
  for (const key of RIG_NODE_KEYS) {
    const el = root.querySelector<SVGElement>(`[data-ho="${key}"]`);
    if (el) nodes[key] = el;
  }
  return nodes;
};
