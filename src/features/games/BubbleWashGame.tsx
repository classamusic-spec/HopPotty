import React, { useCallback, useMemo } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';

import { GameHost } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { GameBoard } from './GameBoard';
import { withAlpha } from './paint';
import { boardFrame, type SceneFrame } from './sceneFrame';
import {
  Foam,
  HandSprite,
  SoapBubble,
  Sparkle,
  SwipeHint,
  Unwashed,
  type HandSide,
} from './sprites';
import { useSceneRub } from './useSceneRub';

/**
 * Bubble Wash — twenty seconds of scrubbing, made worth finishing.
 *
 * References `Art/render/screens/11-game-bubble-wash.png` (mid-rub) and
 * `46-bubble-wash-clean.png` (the ending).
 *
 * The composition solves the problem this screen would otherwise have. The
 * brief asks for Hop's *hands* enlarged into the foreground **and** for Hop to
 * watch what the child is doing, and a character cannot be in both places at
 * once without his own arms crossing his own chest. In a bathroom he can: the
 * reflection is four hundred points above the hands, so no hand and no torso
 * can ever overlap.
 *
 * Foam is the only progress readout, and it is *on the hands*, in the shape of
 * the path the finger took. A child reads how far they have got by looking at
 * the thing they are touching — which is also why there is no meter anywhere
 * else and why `GameHost`'s dots are left off this board.
 */

/** One beat of hand-washing, in the order the routine teaches them. */
export type WashStage = 'water' | 'soap' | 'rub' | 'rinse' | 'dry' | 'clean';

const STAGE_LABEL: Readonly<Record<WashStage, string>> = {
  water: 'Wet your hands',
  soap: 'Pump the soap',
  rub: 'Rub, rub, rub!',
  rinse: 'Rinse them off',
  dry: 'Dry them well',
  clean: 'Squeaky clean!',
};

export interface WashSpot {
  readonly id: string;
  readonly hand: HandSide;
  readonly done: boolean;
}

export interface WashBubble {
  readonly id: string;
  /** Scene coordinates and diameter, in scene units. */
  readonly x: number;
  readonly y: number;
  readonly size: number;
  readonly popped: boolean;
}

export interface BubbleWashGameProps {
  stage?: WashStage;
  /** The places on the hands the child has not been yet. */
  spots?: readonly WashSpot[];
  bubbles?: readonly WashBubble[];
  onPopBubble?: (id: string) => void;
  /** A spot the finger rubbed across. */
  onRubSpot?: (id: string) => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

/**
 * The composition, in the scene's own coordinates.
 *
 * `scene.games.bubbleWash` puts the basin at (300, 318) with a half-width of
 * 124, so the pair of hands is placed against *that* rather than against a
 * number tuned by eye: two centres 178 apart, each hand 190 tall, leaves a
 * comfortable gutter of basin between them and neither hand's box ever reaches
 * the other's.
 */
const BAND_RATIO = 1.3;
const HANDS = { left: 211, right: 389, cy: 360, height: 190, tilt: -7 } as const;
const MIRROR = { cx: 300, cy: 118, size: 150 } as const;

/** Foam and unwashed lobes, as fractions of a hand's height from its centre. */
const FOAM_TRAIL: Readonly<Record<HandSide, readonly { dx: number; dy: number; r: number }[]>> = {
  left: [
    { dx: -0.287, dy: 0.339, r: 0.1 },
    { dx: -0.139, dy: 0.252, r: 0.086 },
    { dx: 0.009, dy: 0.322, r: 0.096 },
    { dx: 0.139, dy: 0.226, r: 0.082 },
  ],
  right: [
    { dx: -0.143, dy: 0.243, r: 0.086 },
    { dx: 0.004, dy: 0.33, r: 0.096 },
    { dx: 0.152, dy: 0.243, r: 0.082 },
    { dx: 0.291, dy: 0.322, r: 0.1 },
  ],
};

const SPOT_AT: Readonly<Record<HandSide, { dx: number; dy: number; r: number }>> = {
  left: { dx: -0.157, dy: 0.435, r: 0.104 },
  right: { dx: 0.161, dy: 0.409, r: 0.1 },
};

/** The rinsed ending: three stars and a scatter of droplets. */
const ENDING_SPARKLES: readonly { x: number; y: number; r: number }[] = [
  { x: 205, y: 292, r: 18 },
  { x: 400, y: 262, r: 14 },
  { x: 300, y: 236, r: 11 },
];
const DROPLETS: readonly { x: number; y: number; r: number }[] = [
  { x: 238, y: 268, r: 9 },
  { x: 372, y: 252, r: 8 },
  { x: 178, y: 350, r: 7 },
  { x: 424, y: 340, r: 8 },
];

export const BUBBLE_WASH_SPOTS: readonly WashSpot[] = [
  { id: 'left-spot', hand: 'left', done: false },
  { id: 'right-spot', hand: 'right', done: false },
];

export const BUBBLE_WASH_BUBBLES: readonly WashBubble[] = [
  { id: 'b1', x: 150, y: 150, size: 100, popped: false },
  { id: 'b2', x: 470, y: 118, size: 78, popped: false },
  { id: 'b3', x: 424, y: 232, size: 60, popped: false },
  { id: 'b4', x: 176, y: 262, size: 54, popped: true },
];

/** How close a finger has to come to a spot to take it away, in hand heights. */
const REACH = 0.16;

export function BubbleWashGame({
  stage = 'rub',
  spots = BUBBLE_WASH_SPOTS,
  bubbles = BUBBLE_WASH_BUBBLES,
  onPopBubble,
  onRubSpot,
  onDone,
  onGrownUp,
}: BubbleWashGameProps): React.ReactElement {
  const { width } = useWindowDimensions();
  const frame = useMemo(() => boardFrame(width, BAND_RATIO), [width]);

  const soaping = stage === 'soap';
  const clean = stage === 'clean';
  const toDo = clean || soaping ? [] : spots.filter((s) => !s.done);

  const spotPoint = useCallback(
    (spot: WashSpot) => {
      const at = SPOT_AT[spot.hand];
      const hand = spot.hand === 'left' ? HANDS.left : HANDS.right;
      return {
        x: hand + at.dx * HANDS.height,
        y: HANDS.cy + at.dy * HANDS.height,
        r: at.r * HANDS.height,
      };
    },
    [],
  );

  const rubAt = useCallback(
    (x: number, y: number) => {
      if (!onRubSpot) return;
      for (const spot of toDo) {
        const p = spotPoint(spot);
        const reach = REACH * HANDS.height;
        if ((p.x - x) ** 2 + (p.y - y) ** 2 <= reach * reach) {
          onRubSpot(spot.id);
          return;
        }
      }
    },
    [toDo, onRubSpot, spotPoint],
  );

  const rub = useSceneRub(frame, rubAt);

  return (
    <GameHost
      title={STAGE_LABEL[stage]}
      instruction="Pop every bubble to get your hands sparkly clean!"
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none">
          <View ref={rub.ref} onLayout={rub.onLayout} {...rub.panHandlers}>
            <GameBoard scene="scene.games.bubbleWash" frame={frame}>
              <Mirror frame={frame} />

              {bubbles.map((bubble) => (
                <SoapBubble
                  key={bubble.id}
                  frame={frame}
                  cx={bubble.x}
                  cy={bubble.y}
                  size={bubble.size}
                  popped={bubble.popped}
                  label="A bubble"
                  {...(bubble.popped || !onPopBubble
                    ? null
                    : { onPress: () => onPopBubble(bubble.id) })}
                />
              ))}

              <HandSprite
                side="left"
                frame={frame}
                cx={HANDS.left}
                cy={HANDS.cy}
                handHeight={HANDS.height}
                rotate={HANDS.tilt}
                label="Hop's hands"
              />
              <HandSprite
                side="right"
                frame={frame}
                cx={HANDS.right}
                cy={HANDS.cy}
                handHeight={HANDS.height}
                rotate={HANDS.tilt}
              />

              {soaping
                ? null
                : (['left', 'right'] as const).flatMap((side) =>
                    FOAM_TRAIL[side].map((puff, i) => (
                      <Foam
                        key={`${side}-${i}`}
                        frame={frame}
                        cx={(side === 'left' ? HANDS.left : HANDS.right) + puff.dx * HANDS.height}
                        cy={HANDS.cy + puff.dy * HANDS.height}
                        radius={puff.r * HANDS.height}
                      />
                    )),
                  )}

              {clean ? (
                <>
                  <Foam frame={frame} cx={HANDS.left - 30} cy={HANDS.cy + 96} radius={22} />
                  <Foam frame={frame} cx={HANDS.right + 30} cy={HANDS.cy + 96} radius={22} />
                  <Foam frame={frame} cx={300} cy={HANDS.cy + 76} radius={16} />
                  {ENDING_SPARKLES.map((s) => (
                    <Sparkle key={`${s.x}`} frame={frame} cx={s.x} cy={s.y} radius={s.r} />
                  ))}
                  <Droplets frame={frame} />
                </>
              ) : null}

              {toDo.map((spot) => {
                const p = spotPoint(spot);
                return <Unwashed key={spot.id} frame={frame} cx={p.x} cy={p.y} radius={p.r} />;
              })}

              {toDo.length > 0 ? (
                <SwipeHint
                  frame={frame}
                  cx={300}
                  cy={HANDS.cy + 0.4 * HANDS.height}
                  length={268}
                  ringRadius={15.7}
                />
              ) : null}
            </GameBoard>
          </View>
        </View>
      }
    />
  );
}

/**
 * Hop, watching his own hands from the mirror over the sink.
 *
 * A reflection rather than a second character: the state Hop is in here is the
 * one the child is performing, so he is drawn scrubbing.
 */
function Mirror({ frame }: { frame: SceneFrame }): React.ReactElement {
  const theme = useHopTheme();
  const d = frame.len(MIRROR.size);
  return (
    <View
      pointerEvents="none"
      accessible
      accessibilityRole="image"
      accessibilityLabel="Hop, watching in the mirror"
      style={{
        position: 'absolute',
        left: frame.x(MIRROR.cx) - d / 2,
        top: frame.y(MIRROR.cy) - d / 2,
        width: d,
        height: d,
        borderRadius: d / 2,
        borderWidth: frame.len(7),
        borderColor: theme.palette.cloud,
        backgroundColor: withAlpha(theme.palette.pondBlueSoft, 0.92),
        overflow: 'hidden',
        alignItems: 'center',
        justifyContent: 'flex-end',
      }}
    >
      <HopCharacter size={d * 1.05} state="wash" decorative />
    </View>
  );
}

/** Water running off clean hands. */
function Droplets({ frame }: { frame: SceneFrame }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View pointerEvents="none">
      {DROPLETS.map((drop) => {
        const d = frame.len(drop.r) * 2;
        return (
          <View
            key={`${drop.x}-${drop.y}`}
            style={{
              position: 'absolute',
              left: frame.x(drop.x) - d / 2,
              top: frame.y(drop.y) - d / 2,
              width: d,
              height: d * 1.25,
              borderRadius: d / 2,
              borderTopLeftRadius: d * 0.2,
              backgroundColor: withAlpha(theme.palette.pondBlueLight, 0.9),
            }}
          />
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  board: { flex: 1, justifyContent: 'center' },
});

export default BubbleWashGame;
