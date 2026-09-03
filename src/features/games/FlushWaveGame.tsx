import React, { useMemo } from 'react';
import { Pressable, StyleSheet, View, useWindowDimensions } from 'react-native';

import { GameHost } from '../../design-system/components';
import { GameBoard } from './GameBoard';
import { boardFrame } from './sceneFrame';
import { HopSprite, IconSprite, Sparkle, TapHint } from './sprites';

/**
 * Flush and Wave — one cause, one effect, as often as a child likes.
 *
 * Reference: `Art/render/screens/27-game-flush-wave.png`.
 *
 * The shortest game in the catalogue, and the one built for the child who finds
 * the flush loud: the whole thing is a handle, a swirl and a wave, with the
 * sound under their own finger and nowhere they have to be. "Again!" is a
 * primary rather than a nag, and "All done" sits under it from the first frame.
 */

export interface FlushWaveGameProps {
  /** How many times the water has gone round. Never shown as a number. */
  flushes: number;
  /** Flushes drawn as dots. The round has no other length. */
  marks?: number;
  /** Whether the water is going round right now. */
  swirling?: boolean;
  onFlush?: () => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

/** The board, in the scene's own coordinates. */
const FLUSHER = { cx: 452, cy: 254, radius: 46 } as const;
const SWIRL = { cx: 452, cy: 332, radius: 40 } as const;
const HOP = { cx: 250, groundY: 425, size: 228 } as const;

/** How much of `icon.games.swirl` the swirl itself fills. */
const SWIRL_FILL = 100 / 120;

export function FlushWaveGame({
  flushes,
  marks = 3,
  swirling = true,
  onFlush,
  onDone,
  onGrownUp,
}: FlushWaveGameProps): React.ReactElement {
  const { width } = useWindowDimensions();
  const frame = useMemo(() => boardFrame(width), [width]);
  const reach = frame.len(FLUSHER.radius) * 2;

  return (
    <GameHost
      title="Flush and Wave"
      instruction="Tap the flusher and watch the water swirl!"
      progress={{ total: marks, done: Math.min(flushes, marks) }}
      caption={flushes > 0 ? 'Whoosh! Around it goes.' : undefined}
      primaryLabel="Again!"
      onPrimary={onFlush}
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none">
          <GameBoard scene="scene.games.flushWave" frame={frame}>
            <HopSprite
              frame={frame}
              cx={HOP.cx}
              groundY={HOP.groundY}
              size={HOP.size}
              state="wave"
              label="Hop, by the toilet"
            />

            {swirling ? (
              <>
                <IconSprite
                  artwork="icon.games.swirl"
                  frame={frame}
                  cx={SWIRL.cx}
                  cy={SWIRL.cy}
                  size={(SWIRL.radius * 2) / SWIRL_FILL}
                  label="The water, swirling"
                />
                <Sparkle frame={frame} cx={536} cy={288} radius={13} opacity={0.9} />
                <Sparkle frame={frame} cx={372} cy={296} radius={9.8} opacity={0.7} />
              </>
            ) : null}

            <TapHint frame={frame} cx={FLUSHER.cx} cy={FLUSHER.cy} radius={FLUSHER.radius} rings={2} />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="The flusher"
              onPress={onFlush}
              style={{
                position: 'absolute',
                left: frame.x(FLUSHER.cx) - reach / 2,
                top: frame.y(FLUSHER.cy) - reach / 2,
                width: reach,
                height: reach,
                borderRadius: reach / 2,
              }}
            />
          </GameBoard>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  board: { flex: 1, justifyContent: 'center' },
});

export default FlushWaveGame;
