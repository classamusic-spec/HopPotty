import React, { useMemo, useState } from 'react';
import {
  PanResponder,
  StyleSheet,
  View,
  type GestureResponderEvent,
  type PanResponderGestureState,
} from 'react-native';

import { GameHost } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { GameBoard } from './GameBoard';
import type { SceneFrame } from './sceneFrame';
import { useBoardFrame } from './useBoardFrame';
import { IconSprite, Sparkle } from './sprites';

/**
 * `StyleSheet.absoluteFillObject` is absent from React Native 0.87's generated
 * types, and this needs the spreadable object rather than the registered
 * `absoluteFill` style id.
 */
const HOP_ABSOLUTE_FILL = { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 } as const;

/**
 * Potty Path — the trip to the bathroom, rehearsed as a small friendly journey.
 *
 * Reference: `Art/render/screens/22-game-potty-path.png`.
 *
 * The pads and their scales are the harness's own numbers, in the scene's 640×480
 * coordinates, so Hop lands on the floor of the room he is crossing rather than
 * near it. Every stop on the route is named — `GameCopy.pathStart` and friends —
 * because naming the rooms is most of what makes this a rehearsal of a real trip
 * rather than a puzzle about dots.
 */

export interface PottyPathGameProps {
  /** How many pads Hop has already reached. Never shown as a number. */
  reached?: number;
  onHopTo?: (pad: number) => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

/** The route across the room, in scene coordinates, and each pad's size. */
const PADS: readonly { x: number; y: number; scale: number; name: string }[] = [
  { x: 92, y: 448, scale: 0.95, name: 'The toy corner' },
  { x: 206, y: 390, scale: 0.85, name: 'The rug' },
  { x: 306, y: 366, scale: 0.78, name: 'The hallway' },
  { x: 396, y: 344, scale: 0.7, name: 'The bathroom door' },
  { x: 472, y: 330, scale: 0.62, name: 'The potty' },
];

/**
 * A pad's box, in scene units, for a pad drawn at `scale`.
 *
 * The harness draws a pad with `rx = 34 * scale` points on a band where one
 * point is 640/393 scene units; `pond.lilyPadSmall` fills 0.68 of its own file
 * with the pad, so the box is that width divided by the fill.
 */
const PAD_BOX = (scale: number): number => ((34 * (640 / 393)) / 0.68) * 2 * scale;
/** The pad's own centre sits a little below the middle of its file. */
const PAD_RISE = 6 / 200;

/** Hop's box on this board, in scene units, and how far his feet sit past a pad. */
const HOP_SIZE = 208;
const HOP_DROP = 13;

export function PottyPathGame({
  reached = 3,
  onHopTo,
  onDone,
  onGrownUp,
}: PottyPathGameProps): React.ReactElement {
  const { frame, onSlotLayout } = useBoardFrame();
  const at = Math.min(Math.max(reached - 1, 0), PADS.length - 1);

  return (
    <GameHost
      title="Potty Path"
      instruction="Hop along the lily pads all the way to the potty!"
      progress={{ total: PADS.length, done: Math.min(reached, PADS.length) }}
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none" onLayout={onSlotLayout}>
          <GameBoard scene="scene.games.pottyPath" frame={frame}>
            {PADS.map((pad, i) => {
              const box = PAD_BOX(pad.scale);
              const done = i < reached;
              return (
                <React.Fragment key={pad.name}>
                  <IconSprite
                    artwork="pond.lilyPadSmall"
                    frame={frame}
                    cx={pad.x}
                    cy={pad.y - box * PAD_RISE}
                    size={box}
                    label={pad.name}
                    opacity={done ? 1 : 0.58}
                    {...(onHopTo ? { onPress: () => onHopTo(i + 1) } : null)}
                  />
                  {done ? (
                    <Sparkle
                      frame={frame}
                      cx={pad.x + 6.5}
                      cy={pad.y - 21}
                      radius={9.8}
                      opacity={0.9}
                    />
                  ) : null}
                </React.Fragment>
              );
            })}

            <DraggableHop
              frame={frame}
              cx={PADS[at]!.x}
              groundY={PADS[at]!.y + HOP_DROP}
              onDropAt={onHopTo}
            />
          </GameBoard>
        </View>
      }
    />
  );
}

/**
 * Hop, and the finger that carries him.
 *
 * A drag rather than only a tap because the render shows a hand moving Hop
 * along the path — but the pads are buttons too, so a child who cannot yet drag
 * plays the same board rather than a described one.
 */
function DraggableHop({
  frame,
  cx,
  groundY,
  onDropAt,
}: {
  frame: SceneFrame;
  cx: number;
  groundY: number;
  onDropAt?: (pad: number) => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const [drag, setDrag] = useState<{ x: number; y: number } | null>(null);
  const side = frame.len(HOP_SIZE);

  const responder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: (_e: GestureResponderEvent, g: PanResponderGestureState) =>
          Math.abs(g.dx) + Math.abs(g.dy) > 4,
        onPanResponderMove: (_e, g) => setDrag({ x: g.dx, y: g.dy }),
        onPanResponderRelease: (_e, g) => {
          setDrag(null);
          if (!onDropAt) return;
          // Where the finger let go, back in the scene's own coordinates.
          const dropX = cx + g.dx / frame.scale;
          const dropY = groundY + g.dy / frame.scale;
          let best = 0;
          let bestD = Number.POSITIVE_INFINITY;
          PADS.forEach((pad, i) => {
            const d = (pad.x - dropX) ** 2 + (pad.y - dropY) ** 2;
            if (d < bestD) {
              bestD = d;
              best = i;
            }
          });
          onDropAt(best + 1);
        },
        onPanResponderTerminate: () => setDrag(null),
      }),
    [cx, groundY, frame.scale, onDropAt],
  );

  return (
    <View
      {...responder.panHandlers}
      accessibilityRole="adjustable"
      accessibilityLabel="Hop is here"
      accessibilityHint="Drag Hop to the next lily pad, or tap a pad"
      style={{
        position: 'absolute',
        left: frame.x(cx) - side / 2 + (drag?.x ?? 0),
        top: frame.y(groundY) - side + (drag?.y ?? 0),
        width: side,
        height: side,
      }}
    >
      {/* The wrapper carries the name and the role: Hop is one element to a
          screen reader, never a hundred and thirty-nine paths. */}
      <HopCharacter size={side} state={drag ? 'hop' : 'idle'} animated={!drag} decorative />
      {drag ? (
        <View
          pointerEvents="none"
          style={[
            styles.lift,
            { borderRadius: theme.radius.hero, borderColor: theme.palette.hopGreenLight },
          ]}
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  board: { flex: 1, justifyContent: 'center' },
  lift: { ...HOP_ABSOLUTE_FILL, borderWidth: 2, opacity: 0.5 },
});

export default PottyPathGame;
