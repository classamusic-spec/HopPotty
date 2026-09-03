import React from 'react';
import {
  Circle,
  ClipPath,
  Defs,
  Ellipse,
  G,
  Line,
  LinearGradient,
  Path,
  RadialGradient,
  Rect,
  Stop,
  Text as SvgText,
} from 'react-native-svg';

import type { HopNode } from '../mascot/poses.generated';

/**
 * Renders a generated scene graph with react-native-svg.
 *
 * Shared by the mascot and the illustration catalogue, because both are the
 * same problem: a tree of SVG elements parsed at build time, drawn without
 * re-parsing. Keeping one renderer means an element type added to the art
 * pipeline becomes available to both at once, and — more importantly — that
 * neither can quietly support a tag the other drops on the floor.
 */

// react-native-svg has no generic element factory, so every tag the art
// pipeline emits is mapped explicitly. An unknown tag draws nothing, and
// nothing drawn silently is a missing sky or a missing limb — so it warns.
const ELEMENTS = {
  g: G,
  path: Path,
  circle: Circle,
  ellipse: Ellipse,
  line: Line,
  rect: Rect,
  text: SvgText,
  clipPath: ClipPath,
  defs: Defs,
  linearGradient: LinearGradient,
  radialGradient: RadialGradient,
  stop: Stop,
} as const;

export type SvgTagName = keyof typeof ELEMENTS;

const isKnownTag = (t: string): t is SvgTagName => t in ELEMENTS;

export interface SceneRenderOptions {
  /** Replace a whole subtree by its `id` — how a blink swaps in other eyes. */
  readonly overrides?: Readonly<Record<string, HopNode>>;
  /** Append a translation to a part, e.g. pupils following a gaze. */
  readonly offsets?: Readonly<Record<string, { x: number; y: number }>>;
}

export function renderSceneNode(
  node: HopNode,
  key: string,
  options: SceneRenderOptions = {},
): React.ReactNode {
  const id = typeof node.p.id === 'string' ? node.p.id : undefined;
  const effective = id && options.overrides?.[id] ? (options.overrides[id] as HopNode) : node;

  if (!isKnownTag(effective.t)) {
    if (__DEV__) {
      console.warn(`SvgScene: unknown element "${effective.t}" — regenerate the art?`);
    }
    return null;
  }

  const Component = ELEMENTS[effective.t];
  const props: Record<string, string | number> = { ...effective.p };

  const offset = id ? options.offsets?.[id] : undefined;
  if (offset) {
    const base = typeof props.transform === 'string' ? `${props.transform} ` : '';
    props.transform = `${base}translate(${offset.x} ${offset.y})`;
  }

  // `Text` carries a string body rather than element children.
  if (effective.t === 'text') {
    return (
      <SvgText key={key} {...props}>
        {effective.x}
      </SvgText>
    );
  }

  const children = effective.c?.map((child, i) => renderSceneNode(child, `${key}.${i}`, options));

  return (
    <Component key={key} {...props}>
      {children}
    </Component>
  );
}
