import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { GameHost } from '../../design-system/components';
import { GameBoard } from './GameBoard';
import { useBoardFrame } from './useBoardFrame';
import { HopSprite, IconSprite, TapHint } from './sprites';

/**
 * Listen to Your Body — catching the signal in the middle of playing, which is
 * exactly when it is easiest to miss.
 *
 * Reference: `Art/render/screens/26-game-body-signal.png`.
 *
 * Tapping Hop when no bubble is showing gets a giggle, which is the point: a
 * child exploring the screen finds warmth, so there is nothing here to get
 * right and nothing to get otherwise. The three quiet dots under the board say
 * how many signals have come and gone; they never say how many were missed,
 * because none of them can be.
 */

export interface BodySignalGameProps {
  /** How many signals the child has noticed. Never shown as a number. */
  noticed?: number;
  /** Signals in a round. Three, with play between them. */
  signals?: number;
  /** Whether Hop's bubble is showing right now. */
  bubbleShowing?: boolean;
  onTapBubble?: () => void;
  onTapHop?: () => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

/** The board, in the scene's own coordinates. */
const HOP = { cx: 270, groundY: 366, size: 241 } as const;
const BALL = { cx: 404, cy: 398, radius: 34 } as const;
const BUBBLE = { cx: 486, cy: 150, width: 190 } as const;

/** How much of `icon.games.ball` its ball fills, and of the thought bubble its bubble. */
const BALL_FILL = 88 / 120;
const BUBBLE_FILL = 95 / 120;
/** The bubble sits above the middle of its own file; the box shifts to match. */
const BUBBLE_RISE = 15 / 120;
/** The ball sits a shade below the middle of its own file. */
const BALL_DROP = 2 / 120;

export function BodySignalGame({
  noticed = 1,
  signals = 3,
  bubbleShowing = true,
  onTapBubble,
  onTapHop,
  onDone,
  onGrownUp,
}: BodySignalGameProps): React.ReactElement {
  const { frame, onSlotLayout } = useBoardFrame();
  const bubbleBox = BUBBLE.width / BUBBLE_FILL;

  return (
    <GameHost
      title="Listen to Your Body"
      instruction="Hop is bouncing his ball. Watch for his bubble!"
      progress={{ total: signals, done: Math.min(noticed, signals) }}
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none" onLayout={onSlotLayout}>
          <GameBoard scene="scene.games.bodySignal" frame={frame}>
            <IconSprite
              artwork="icon.games.ball"
              frame={frame}
              cx={BALL.cx}
              cy={BALL.cy - (BALL_DROP * (BALL.radius * 2)) / BALL_FILL}
              size={(BALL.radius * 2) / BALL_FILL}
              label="Hop's ball"
            />

            <HopSprite
              frame={frame}
              cx={HOP.cx}
              groundY={HOP.groundY}
              size={HOP.size}
              state="sit"
              label="Hop, playing"
            />

            {/* Hop is touchable even with no bubble showing: a child who pokes
                him finds a giggle rather than nothing, so there is no wrong
                place to put a finger on this board. */}
            {onTapHop ? (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Hop, playing"
                onPress={onTapHop}
                style={{
                  position: 'absolute',
                  left: frame.x(HOP.cx) - frame.len(HOP.size) / 2,
                  top: frame.y(HOP.groundY) - frame.len(HOP.size),
                  width: frame.len(HOP.size),
                  height: frame.len(HOP.size),
                }}
              />
            ) : null}

            {bubbleShowing ? (
              <>
                <TapHint frame={frame} cx={BUBBLE.cx} cy={BUBBLE.cy} radius={132} rings={1} />
                <IconSprite
                  artwork="icon.games.thoughtBubble"
                  frame={frame}
                  cx={BUBBLE.cx}
                  cy={BUBBLE.cy + bubbleBox * BUBBLE_RISE}
                  size={bubbleBox}
                  label="Hop's bubble"
                  {...(onTapBubble ? { onPress: onTapBubble } : null)}
                />
              </>
            ) : null}
          </GameBoard>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  board: { flex: 1, justifyContent: 'center' },
});

export default BodySignalGame;
