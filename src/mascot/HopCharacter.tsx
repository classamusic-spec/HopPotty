import React, { useEffect, useMemo, useRef, useState } from 'react';
import Svg, {
  Circle,
  ClipPath,
  Ellipse,
  G,
  Line,
  Path,
  Rect,
  Text as SvgText,
} from 'react-native-svg';

import {
  HOP_POSES,
  HOP_VIEWBOX,
  type HopNode,
  type HopPartId,
  type HopPoseName,
} from './poses.generated';
import { hopPoseFor, type HopAnimationState } from './hopStates';

/**
 * Hop, drawn from the art rig.
 *
 * The geometry in `poses.generated.ts` is the rig's own output, verified
 * element for element at build time, so this component never decides what Hop
 * looks like — only which pose is showing and how its named parts are moved.
 * That split is deliberate: a bug here can misplace a pupil, but it cannot
 * redraw the character.
 */

// react-native-svg has no generic element factory, so the tags the rig emits
// are mapped explicitly. An unknown tag is a generator change that this file
// has not caught up with, and drawing nothing silently would lose a limb.
const ELEMENTS = {
  g: G,
  path: Path,
  circle: Circle,
  ellipse: Ellipse,
  line: Line,
  rect: Rect,
  text: SvgText,
  clipPath: ClipPath,
} as const;

type TagName = keyof typeof ELEMENTS;

const isKnownTag = (t: string): t is TagName => t in ELEMENTS;

/** Parts whose subtree may be swapped for another pose's version of it. */
export type HopPartOverrides = Partial<Record<HopPartId, HopNode>>;

interface RenderContext {
  readonly overrides: HopPartOverrides;
  /** Extra transform appended to a part, e.g. pupils following a gaze. */
  readonly offsets: Partial<Record<HopPartId, { x: number; y: number }>>;
}

function renderNode(node: HopNode, key: string, ctx: RenderContext): React.ReactNode {
  const id = node.p.id as HopPartId | undefined;

  // A part override replaces the whole subtree — how a blink swaps in the
  // blink pose's eyes without re-rendering the other hundred-odd elements.
  const effective = id && ctx.overrides[id] ? (ctx.overrides[id] as HopNode) : node;

  if (!isKnownTag(effective.t)) {
    if (__DEV__) {
      console.warn(`HopCharacter: unknown element "${effective.t}" — regenerate the mascot?`);
    }
    return null;
  }

  const Component = ELEMENTS[effective.t];
  const { ...props } = effective.p as Record<string, string | number>;

  const offset = id ? ctx.offsets[id] : undefined;
  if (offset) {
    const base = typeof props.transform === 'string' ? `${props.transform} ` : '';
    props.transform = `${base}translate(${offset.x} ${offset.y})`;
  }

  const children = effective.c?.map((child, i) => renderNode(child, `${key}.${i}`, ctx));

  // `Text` is the one element that carries a string body rather than children.
  if (effective.t === 'text') {
    return (
      <SvgText key={key} {...props}>
        {effective.x}
      </SvgText>
    );
  }

  return (
    <Component key={key} {...props}>
      {children}
    </Component>
  );
}

/** How large Hop is drawn, in points. Named rather than numeric at call sites. */
export type HopSize = 'small' | 'medium' | 'hero' | 'pond';

const SIZES: Readonly<Record<HopSize, number>> = {
  small: 64,
  medium: 128,
  hero: 240,
  pond: 320,
};

export interface HopCharacterProps {
  size?: HopSize | number;
  state?: HopAnimationState;
  /**
   * Where Hop is looking, in unit coordinates relative to his own centre —
   * (0,0) straight ahead, (1,-1) up and to his left. Clamped.
   */
  lookTarget?: { x: number; y: number } | null;
  /**
   * When false, Hop holds a still pose. Blinking and gaze stop; the expression
   * of the state is still shown, because losing it would cost meaning rather
   * than motion.
   */
  animated?: boolean;
  /** Accessibility label. Hop is one element to a screen reader, never 139. */
  accessibilityLabel?: string;
  /** Hidden from assistive tech where Hop is pure decoration on a busy screen. */
  decorative?: boolean;
}

/** How far a pupil travels, in rig units, at full gaze deflection. */
const PUPIL_TRAVEL = 2.4;

const BLINK_MIN_MS = 2600;
const BLINK_MAX_MS = 6200;
const BLINK_HOLD_MS = 140;

export function HopCharacter({
  size = 'medium',
  state = 'idle',
  lookTarget = null,
  animated = true,
  accessibilityLabel,
  decorative = false,
}: HopCharacterProps): React.ReactElement {
  const pose: HopPoseName = hopPoseFor(state);
  const [blinking, setBlinking] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Blinking is a pose the rig already draws, so it is a part swap rather than
  // an animated eyelid: the `blink` pose's eyes replace the current pose's.
  useEffect(() => {
    if (!animated || pose === 'blink' || pose === 'sleep') {
      setBlinking(false);
      return;
    }
    let cancelled = false;
    const schedule = () => {
      const delay = BLINK_MIN_MS + Math.random() * (BLINK_MAX_MS - BLINK_MIN_MS);
      timer.current = setTimeout(() => {
        if (cancelled) return;
        setBlinking(true);
        timer.current = setTimeout(() => {
          if (cancelled) return;
          setBlinking(false);
          schedule();
        }, BLINK_HOLD_MS);
      }, delay);
    };
    schedule();
    return () => {
      cancelled = true;
      if (timer.current) clearTimeout(timer.current);
    };
  }, [animated, pose]);

  const overrides = useMemo<HopPartOverrides>(() => {
    if (!blinking) return {};
    const eyes = findPart(HOP_POSES.blink, 'eyes-group');
    return eyes ? { 'eyes-group': eyes } : {};
  }, [blinking]);

  const offsets = useMemo(() => {
    if (!lookTarget || !animated) return {};
    const clamp = (v: number) => Math.max(-1, Math.min(1, v));
    const dx = clamp(lookTarget.x) * PUPIL_TRAVEL;
    const dy = clamp(lookTarget.y) * PUPIL_TRAVEL;
    return {
      'left-pupil': { x: dx, y: dy },
      'right-pupil': { x: dx, y: dy },
    } as RenderContext['offsets'];
  }, [lookTarget, animated]);

  const side = typeof size === 'number' ? size : SIZES[size];
  const tree = HOP_POSES[pose];

  return (
    <Svg
      width={side}
      height={side}
      viewBox={`0 0 ${HOP_VIEWBOX} ${HOP_VIEWBOX}`}
      // One accessible element, not a hundred and thirty-nine decorative paths.
      accessible={!decorative}
      accessibilityRole={decorative ? undefined : 'image'}
      accessibilityLabel={decorative ? undefined : accessibilityLabel}
      importantForAccessibility={decorative ? 'no-hide-descendants' : 'yes'}
    >
      {renderNode(tree, 'hop', { overrides, offsets })}
    </Svg>
  );
}

/** Depth-first search for a named part in a pose tree. */
function findPart(node: HopNode, id: HopPartId): HopNode | null {
  if (node.p.id === id) return node;
  for (const child of node.c ?? []) {
    const found = findPart(child, id);
    if (found) return found;
  }
  return null;
}

export default HopCharacter;
