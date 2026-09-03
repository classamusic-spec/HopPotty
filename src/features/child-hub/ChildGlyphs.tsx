import React from 'react';
import Svg, { Circle, Path } from 'react-native-svg';

/**
 * The handful of small marks the child surfaces draw.
 *
 * These are not illustrations — there is no `HopIllustrationKey` for a star, a
 * chevron or a padlock, and there should not be: they are interface glyphs, the
 * same size and weight everywhere, and an illustration key would invite an
 * artist to redraw one per screen. The path data is the render harness's own
 * (`Scripts/screens/kit.js`, `MARK`), so a star here and a star in a design
 * render are the same star.
 *
 * **They belong in the design system**, next to `HopText` and `HopButton`, and
 * should move there. They live under a feature only because this workstream may
 * not write into `src/design-system/`. Every colour is passed in by the caller
 * from a token; nothing here decides what anything looks like except its shape.
 */
export interface ChildGlyphProps {
  /** A colour from the theme. Glyphs never pick their own. */
  readonly color: string;
  /** Side of the square the glyph is drawn in, in points. */
  readonly size?: number;
}

/** A star. The only shape the product uses for a reward. */
export function StarGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d="M12 2.4l2.95 6.1 6.7.92-4.87 4.66 1.2 6.6L12 17.55 6.02 20.68l1.2-6.6L2.35 9.42l6.7-.92z"
        fill={color}
      />
    </Svg>
  );
}

/** A drop. "I peed". */
export function DropGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d="M12 2.6c3.6 4.3 6.4 7.8 6.4 11a6.4 6.4 0 0 1-12.8 0c0-3.2 2.8-6.7 6.4-11z"
        fill={color}
      />
    </Svg>
  );
}

/** A swirl. "I pooped" — drawn as cheerfully as the other two. */
export function SwirlGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d="M9.6 6.2c0-1.9 1.3-3.2 2.6-3.2 1.6 0 2.3 1.2 2 2.4 2 .1 3 1.3 2.8 2.7 2 .2 3 1.6 3 2.9 1.7.4 2.6 1.7 2.6 3.1 0 2.2-2 3.9-4.6 3.9H6c-2.6 0-4.6-1.7-4.6-3.9 0-1.5 1-2.8 2.8-3.2-.1-1.6 1-2.9 2.8-3-.2-1.4.9-2.6 2.6-2.7z"
        fill={color}
      />
    </Svg>
  );
}

/** A ring. "I tried" — a thing in its own right, never an empty slot. */
export function RingGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Circle cx={12} cy={12} r={8.4} fill="none" stroke={color} strokeWidth={2.3} />
      <Circle cx={12} cy={12} r={3} fill={color} />
    </Svg>
  );
}

/** A speaker. The audio-first control on every question. */
export function SpeakerGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path d="M4 9.4h3.4L12 5.2v13.6L7.4 14.6H4z" fill={color} />
      <Path
        d="M15.2 8.6a5 5 0 0 1 0 6.8"
        fill="none"
        stroke={color}
        strokeWidth={2}
        strokeLinecap="round"
      />
      <Path
        d="M17.9 5.9a8.6 8.6 0 0 1 0 12.2"
        fill="none"
        stroke={color}
        strokeWidth={2}
        strokeLinecap="round"
      />
    </Svg>
  );
}

/** A raised hand. The way to a grown-up, everywhere it appears. */
export function HandGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d="M8.6 12.4V5.2a1.6 1.6 0 0 1 3.2 0v6M11.8 11V4.4a1.6 1.6 0 0 1 3.2 0V11m0-1.2a1.6 1.6 0 0 1 3.2 0v5.4a6 6 0 0 1-6 6h-1.2a5.6 5.6 0 0 1-4.4-2.2l-2.4-3.2a1.6 1.6 0 0 1 2.4-2l1.8 1.8"
        fill="none"
        stroke={color}
        strokeWidth={1.9}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** A padlock. Only ever on a pond item that is still coming. */
export function LockGlyph({ color, size = 20 }: ChildGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d="M7 10V8a5 5 0 0 1 10 0v2h.6A1.4 1.4 0 0 1 19 11.4v8.2a1.4 1.4 0 0 1-1.4 1.4H6.4A1.4 1.4 0 0 1 5 19.6v-8.2A1.4 1.4 0 0 1 6.4 10zm2.2 0h5.6V8a2.8 2.8 0 0 0-5.6 0z"
        fill={color}
      />
    </Svg>
  );
}

export interface ChevronGlyphProps extends ChildGlyphProps {
  /** Which way it points. Forward on a door, back on a title bar. */
  readonly direction?: 'forward' | 'back';
}

/** A chevron. */
export function ChevronGlyph({
  color,
  size = 22,
  direction = 'forward',
}: ChevronGlyphProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path
        d={direction === 'forward' ? 'M9 5l7 7-7 7' : 'M15 5l-7 7 7 7'}
        fill="none"
        stroke={color}
        strokeWidth={2.8}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}
