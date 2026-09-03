import React from 'react';
import { Pressable, StyleSheet, View, type ViewStyle } from 'react-native';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import type { HopAnimationState } from '../../mascot/hopStates';
import { withAlpha } from './paint';
import type { SceneFrame } from './sceneFrame';

/**
 * The small pieces a board moves around.
 *
 * Every one of these is a *drawing the app already ships*, reached by its
 * `HopIllustrationKey`, rather than a shape redrawn here — a sprite invented in
 * a screen is how the two apps start drawing different mud. What this file owns
 * is placement: where a drawing sits in the scene's own coordinates, how big it
 * is there, and whether a finger can reach it.
 *
 * Nothing here counts anything. The hints pulse, they never tick.
 */

// ---------------------------------------------------------------------------
// Placement
// ---------------------------------------------------------------------------

export interface SpritePlacement {
  frame: SceneFrame;
  /** Centre, in scene coordinates. */
  cx: number;
  cy: number;
  /** Box side, in scene units. */
  size: number;
  /** Degrees, clockwise. */
  rotate?: number;
}

function boxStyle(
  { frame, cx, cy, size, rotate }: SpritePlacement,
  width = size,
): ViewStyle {
  return {
    position: 'absolute',
    left: frame.x(cx) - frame.len(width) / 2,
    top: frame.y(cy) - frame.len(size) / 2,
    width: frame.len(width),
    height: frame.len(size),
    ...(rotate ? { transform: [{ rotate: `${rotate}deg` }] } : null),
  };
}

// ---------------------------------------------------------------------------
// An illustration, on the board
// ---------------------------------------------------------------------------

export interface IconSpriteProps extends SpritePlacement {
  artwork: HopIllustrationKey;
  /** Box width in scene units, when the drawing is not square. */
  width?: number;
  /** Present only when the sprite is a thing rather than scenery. */
  label?: string;
  onPress?: () => void;
  opacity?: number;
}

/**
 * One shipped drawing, centred on a point in the scene.
 *
 * A sprite with an `onPress` is a real control: it carries a role and a name,
 * so a child using VoiceOver plays the same board rather than a described one.
 */
export function IconSprite({
  artwork,
  width,
  label,
  onPress,
  opacity,
  ...place
}: IconSpriteProps): React.ReactElement {
  const style = [boxStyle(place, width), opacity === undefined ? null : { opacity }];
  const art = (
    <HopArtwork
      artwork={artwork}
      fit="contain"
      decorative={!label || Boolean(onPress)}
      accessibilityLabel={label}
      style={StyleSheet.absoluteFill}
    />
  );

  if (!onPress) {
    return (
      <View style={style} pointerEvents="none">
        {art}
      </View>
    );
  }

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={style}
    >
      {art}
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Hop
// ---------------------------------------------------------------------------

export interface HopSpriteProps {
  frame: SceneFrame;
  /** Where Hop's feet are, in scene coordinates. */
  cx: number;
  groundY: number;
  /** Hop's box, in scene units. */
  size: number;
  state?: HopAnimationState;
  label?: string;
}

/** Hop, standing on a point of the scene rather than floating over it. */
export function HopSprite({
  frame,
  cx,
  groundY,
  size,
  state = 'idle',
  label,
}: HopSpriteProps): React.ReactElement {
  const side = frame.len(size);
  return (
    <View
      pointerEvents="none"
      style={{ position: 'absolute', left: frame.x(cx) - side / 2, top: frame.y(groundY) - side }}
    >
      <HopCharacter size={side} state={state} accessibilityLabel={label} decorative={!label} />
    </View>
  );
}

// ---------------------------------------------------------------------------
// Hop's hands, for the two close-up boards
// ---------------------------------------------------------------------------

/**
 * The shipped hand drawings, and how much of each file the hand itself fills.
 *
 * From `Scripts/hop-art.js`: the artist's file is measured, each hand written
 * out on its own bounding box with two units of padding for the outline. A
 * caller sizing "the hand" means the drawing, not the padding, so the box is
 * scaled up by the ratio between them.
 */
const HANDS = {
  left: {
    key: 'icon.wash.handLeft' as HopIllustrationKey,
    box: { w: 50.14, h: 73.59 },
    hand: { w: 46.14, h: 69.59 },
  },
  right: {
    key: 'icon.wash.handRight' as HopIllustrationKey,
    box: { w: 50.03, h: 74.07 },
    hand: { w: 46.03, h: 70.07 },
  },
} as const;

export type HandSide = keyof typeof HANDS;

export interface HandSpriteProps {
  side: HandSide;
  frame: SceneFrame;
  /** The hand's optical centre, in scene coordinates. */
  cx: number;
  cy: number;
  /** How tall the drawn hand is, in scene units. */
  handHeight: number;
  rotate?: number;
  label?: string;
}

export function HandSprite({
  side,
  frame,
  cx,
  cy,
  handHeight,
  rotate,
  label,
}: HandSpriteProps): React.ReactElement {
  const spec = HANDS[side];
  const boxH = handHeight * (spec.box.h / spec.hand.h);
  const boxW = boxH * (spec.box.w / spec.box.h);
  return (
    <IconSprite
      artwork={spec.key}
      frame={frame}
      cx={cx}
      cy={cy}
      size={boxH}
      width={boxW}
      {...(rotate === undefined ? null : { rotate })}
      {...(label === undefined ? null : { label })}
    />
  );
}

// ---------------------------------------------------------------------------
// Sparkle
// ---------------------------------------------------------------------------

/**
 * How much of the sparkle drawing's box the star itself fills.
 *
 * `icon.games.sparkle` is a four-point star inside a warm glow, and the star
 * spans 76 of the file's 120 units. Callers place sparkles by the star's radius
 * the way the harness does, so the box is derived from it.
 */
const SPARKLE_FILL = 76 / 120;

export function Sparkle({
  frame,
  cx,
  cy,
  radius,
  opacity,
}: {
  frame: SceneFrame;
  cx: number;
  cy: number;
  /** The star's radius, in scene units. */
  radius: number;
  opacity?: number;
}): React.ReactElement {
  return (
    <IconSprite
      artwork="icon.games.sparkle"
      frame={frame}
      cx={cx}
      cy={cy}
      size={(radius * 2) / SPARKLE_FILL}
      {...(opacity === undefined ? null : { opacity })}
    />
  );
}

/** Three sparkles where a patch of mud used to be. */
export function SparkleBurst({
  frame,
  cx,
  cy,
  scale,
}: {
  frame: SceneFrame;
  cx: number;
  cy: number;
  scale: number;
}): React.ReactElement {
  return (
    <>
      <Sparkle frame={frame} cx={cx} cy={cy} radius={13 * scale} />
      <Sparkle frame={frame} cx={cx + 17 * scale} cy={cy + 17 * scale} radius={8 * scale} />
      <Sparkle
        frame={frame}
        cx={cx - 16 * scale}
        cy={cy + 15 * scale}
        radius={6.4 * scale}
        opacity={0.95}
      />
    </>
  );
}

// ---------------------------------------------------------------------------
// Hints — where a finger goes. A pulse, never a countdown.
// ---------------------------------------------------------------------------

export interface TapHintProps {
  frame: SceneFrame;
  cx: number;
  cy: number;
  /** Inner ring radius, in scene units. */
  radius: number;
  rings?: number;
}

export function TapHint({ frame, cx, cy, radius, rings = 3 }: TapHintProps): React.ReactElement {
  const theme = useHopTheme();
  // Ring proportions, stroke widths and opacities are the harness's `tapHint`.
  const spec: readonly { k: number; sw: number; o: number }[] = [
    { k: 1, sw: 4, o: 0.85 },
    { k: 1.4, sw: 3, o: 0.36 },
    { k: 1.86, sw: 2.4, o: 0.17 },
  ];
  return (
    <View pointerEvents="none">
      {spec.slice(0, rings).map(({ k, sw, o }) => {
        const d = frame.len(radius * k * 2);
        return (
          <View
            key={k}
            style={{
              position: 'absolute',
              left: frame.x(cx) - d / 2,
              top: frame.y(cy) - d / 2,
              width: d,
              height: d,
              borderRadius: d / 2,
              borderWidth: frame.len(sw),
              borderColor: withAlpha(theme.palette.pondBlue, o),
            }}
          />
        );
      })}
    </View>
  );
}

export interface SwipeHintProps {
  frame: SceneFrame;
  cx: number;
  cy: number;
  /** How far the swipe travels, in scene units. */
  length: number;
  /** The fingertip ring's radius, in scene units. */
  ringRadius: number;
}

/** A dotted path with a fingertip at the far end: where a finger goes next. */
export function SwipeHint({
  frame,
  cx,
  cy,
  length,
  ringRadius,
}: SwipeHintProps): React.ReactElement {
  const theme = useHopTheme();
  const dots = 9;
  const amplitude = length * 0.09;
  const dot = frame.len(length * 0.023) * 2;
  const ring = frame.len(ringRadius) * 2;
  return (
    <View pointerEvents="none">
      {Array.from({ length: dots }, (_, i) => {
        const t = i / (dots - 1);
        const x = cx - length / 2 + t * length;
        const y = cy - Math.sin(t * Math.PI * 2) * amplitude;
        return (
          <View
            key={i}
            style={{
              position: 'absolute',
              left: frame.x(x) - dot / 2,
              top: frame.y(y) - dot / 2,
              width: dot,
              height: dot,
              borderRadius: dot / 2,
              backgroundColor: withAlpha(theme.palette.pondBlueDeep, 0.8),
            }}
          />
        );
      })}
      <View
        style={{
          position: 'absolute',
          left: frame.x(cx + length / 2) - ring / 2,
          top: frame.y(cy) - ring / 2,
          width: ring,
          height: ring,
          borderRadius: ring / 2,
          borderWidth: frame.len(ringRadius * 0.28),
          borderColor: theme.palette.pondBlueDeep,
          backgroundColor: withAlpha(theme.palette.cloud, 0.92),
        }}
      />
    </View>
  );
}

// ---------------------------------------------------------------------------
// Foam and bubbles
// ---------------------------------------------------------------------------

/** How the five puffs of one patch of foam sit, from the harness's `foam`. */
const PUFFS: readonly { dx: number; dy: number; r: number; o: number }[] = [
  { dx: 0, dy: 0, r: 1, o: 0.97 },
  { dx: 0.78, dy: 0.3, r: 0.72, o: 0.95 },
  { dx: -0.74, dy: 0.24, r: 0.66, o: 0.95 },
  { dx: 0.3, dy: -0.62, r: 0.6, o: 0.93 },
  { dx: -0.34, dy: -0.56, r: 0.54, o: 0.91 },
];

/** A patch of foam: the shape of what the finger just did. */
export function Foam({
  frame,
  cx,
  cy,
  radius,
}: {
  frame: SceneFrame;
  cx: number;
  cy: number;
  radius: number;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View pointerEvents="none">
      {PUFFS.map(({ dx, dy, r, o }, i) => {
        const d = frame.len(radius * r) * 2;
        return (
          <View
            key={i}
            style={{
              position: 'absolute',
              left: frame.x(cx + radius * dx) - d / 2,
              top: frame.y(cy + radius * dy) - d / 2,
              width: d,
              height: d,
              borderRadius: d / 2,
              backgroundColor: withAlpha(theme.palette.cloud, o),
            }}
          />
        );
      })}
      {[
        { dx: -0.3, dy: -0.3, r: 0.26, o: 0.75 },
        { dx: 0.44, dy: 0.1, r: 0.18, o: 0.6 },
      ].map(({ dx, dy, r, o }, i) => {
        const d = frame.len(radius * r) * 2;
        return (
          <View
            key={`b${i}`}
            style={{
              position: 'absolute',
              left: frame.x(cx + radius * dx) - d / 2,
              top: frame.y(cy + radius * dy) - d / 2,
              width: d,
              height: d,
              borderRadius: d / 2,
              backgroundColor: withAlpha(theme.palette.pondBlueSoft, o),
            }}
          />
        );
      })}
    </View>
  );
}

export interface SoapBubbleProps {
  frame: SceneFrame;
  cx: number;
  cy: number;
  /** Diameter, in scene units. */
  size: number;
  popped?: boolean;
  label?: string;
  onPress?: () => void;
}

/** A soap bubble in the air: rim, sheen and one highlight. Nothing else. */
export function SoapBubble({
  frame,
  cx,
  cy,
  size,
  popped = false,
  label,
  onPress,
}: SoapBubbleProps): React.ReactElement {
  const theme = useHopTheme();
  const d = frame.len(size);
  const box: ViewStyle = {
    position: 'absolute',
    left: frame.x(cx) - d / 2,
    top: frame.y(cy) - d / 2,
    width: d,
    height: d,
  };

  if (popped) {
    return (
      <View style={box} pointerEvents="none">
        {[0, 60, 120, 180, 240, 300].map((a) => (
          <View
            key={a}
            style={{
              position: 'absolute',
              left: d / 2 - d * 0.05,
              top: d / 2 - d * 0.05,
              width: d * 0.1,
              height: d * 0.1,
              borderRadius: d * 0.05,
              backgroundColor: withAlpha(theme.palette.pondBlueLight, 0.5),
              transform: [{ rotate: `${a}deg` }, { translateY: -d * 0.34 }],
            }}
          />
        ))}
      </View>
    );
  }

  const skin = (
    <>
      <View
        style={{
          width: d,
          height: d,
          borderRadius: d / 2,
          backgroundColor: withAlpha(theme.palette.pondBlueLight, 0.34),
          borderWidth: Math.max(1, d * 0.026),
          borderColor: withAlpha(theme.palette.cloud, 0.85),
        }}
      />
      <View
        style={{
          position: 'absolute',
          left: d * 0.2,
          top: d * 0.2,
          width: d * 0.3,
          height: d * 0.22,
          borderRadius: d * 0.15,
          backgroundColor: withAlpha(theme.palette.cloud, 0.8),
          transform: [{ rotate: '-24deg' }],
        }}
      />
      <View
        style={{
          position: 'absolute',
          left: d * 0.61,
          top: d * 0.61,
          width: d * 0.1,
          height: d * 0.1,
          borderRadius: d * 0.05,
          backgroundColor: withAlpha(theme.palette.cloud, 0.5),
        }}
      />
    </>
  );

  if (!onPress) {
    return (
      <View style={box} pointerEvents="none">
        {skin}
      </View>
    );
  }
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} style={box}>
      {skin}
    </Pressable>
  );
}

/**
 * A region of hand still to be washed.
 *
 * A softly shaded lobe with a dashed edge, never a red mark: nothing here is
 * *wrong*, it is only somewhere the child has not been yet. The dash carries
 * the meaning as well as the tone does, so the state is never held by colour
 * alone.
 */
export function Unwashed({
  frame,
  cx,
  cy,
  radius,
}: {
  frame: SceneFrame;
  cx: number;
  cy: number;
  radius: number;
}): React.ReactElement {
  const theme = useHopTheme();
  const w = frame.len(radius) * 2;
  const h = frame.len(radius * 0.86) * 2;
  return (
    <View
      pointerEvents="none"
      style={{
        position: 'absolute',
        left: frame.x(cx) - w / 2,
        top: frame.y(cy) - h / 2,
        width: w,
        height: h,
        borderRadius: w / 2,
        backgroundColor: withAlpha(theme.palette.hopGreenDeep, 0.4),
        borderWidth: frame.len(3.4),
        borderColor: withAlpha(theme.palette.cloud, 0.95),
        borderStyle: 'dashed',
      }}
    />
  );
}
