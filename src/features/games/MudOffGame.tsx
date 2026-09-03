import React, { useCallback, useMemo } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';

import type { HopIllustrationKey } from '../../art/HopArtwork';
import { GameHost } from '../../design-system/components';
import { GameBoard } from './GameBoard';
import { boardFrame } from './sceneFrame';
import { HandSprite, IconSprite, SparkleBurst, SwipeHint } from './sprites';
import { useSceneRub } from './useSceneRub';

/**
 * Mud Off — seeing something on your hands, and washing it off.
 *
 * Reference: `Art/render/screens/25-game-mud-off.png`.
 *
 * **Divergence from the SwiftUI original, on purpose.** `MudOffGame.swift`
 * stages `HopCharacterStage(pose: .scrub)` — Hop full-body, holding his hands
 * out. The render draws the hands themselves, close up, filling the board: the
 * child rubs Hop's palm rather than watching a small frog hold it. The render
 * is the reference (`Docs/ReactNativeConventions.md`), so this follows the
 * render; the Swift screen is the one that needs to move.
 *
 * The board *is* the picture here, so the band runs from under the instruction
 * down past the tray and the art scales up to fill it, trading the edges of the
 * scene for size — the harness's `bandHeight: 420`. The hands run off the
 * bottom and melt into the page rather than being sliced.
 */

export type MessKind = 'brown' | 'green' | 'paint';

export interface MudPatch {
  readonly id: string;
  readonly kind: MessKind;
  /** Where it sits on Hop's hands, in the scene's own coordinates. */
  readonly x: number;
  readonly y: number;
  /** The patch's radius there. */
  readonly radius: number;
  readonly cleaned: boolean;
}

export interface MudOffGameProps {
  patches?: readonly MudPatch[];
  /** A patch the child swiped across or tapped. */
  onWipe?: (id: string) => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

/** One patch per kind so two side by side are told apart by name, not colour. */
const MESS_LABEL: Readonly<Record<MessKind, string>> = {
  brown: 'A patch of mud',
  green: 'A patch of pond weed',
  paint: 'A patch of paint',
};

const MESS_ART: Readonly<Record<MessKind, HopIllustrationKey>> = {
  brown: 'icon.games.mud.brown',
  green: 'icon.games.mud.green',
  paint: 'icon.games.mud.paint',
};

/**
 * The board the render draws: four patches, two already gone.
 *
 * Positions, radii and the hands' geometry are the harness's `gameMudOff`.
 */
export const MUD_OFF_BOARD: readonly MudPatch[] = [
  { id: 'left-back', kind: 'brown', x: 245, y: 332, radius: 24, cleaned: true },
  { id: 'right-back', kind: 'paint', x: 395, y: 332, radius: 20, cleaned: true },
  { id: 'left-palm', kind: 'brown', x: 210, y: 371, radius: 27, cleaned: false },
  { id: 'right-palm', kind: 'paint', x: 430, y: 371, radius: 23, cleaned: false },
];

/** The band is taller than the scene's 4:3, so the hands fill the screen. */
const BAND_RATIO = 420 / 393;
/** The hands: optical centres, how tall the drawing is, and its tilt. */
const HANDS = { left: 213, right: 427, cy: 398, height: 272, tilt: -8 } as const;
/**
 * A mud drawing's box for a patch of a given radius.
 *
 * The harness's blob spans about 2.1 radii; `icon.games.mud.*` fills 0.8 of its
 * own file, so the box is that width divided by the fill.
 */
const MUD_BOX = (radius: number): number => (radius * 2.1) / 0.8;
/** How close a finger has to come to a patch to take it away. */
const REACH = 1.5;

export function MudOffGame({
  patches = MUD_OFF_BOARD,
  onWipe,
  onDone,
  onGrownUp,
}: MudOffGameProps): React.ReactElement {
  const { width } = useWindowDimensions();
  const frame = useMemo(() => boardFrame(width, BAND_RATIO), [width]);

  const rubAt = useCallback(
    (x: number, y: number) => {
      if (!onWipe) return;
      for (const patch of patches) {
        if (patch.cleaned) continue;
        const reach = patch.radius * REACH;
        if ((patch.x - x) ** 2 + (patch.y - y) ** 2 <= reach * reach) {
          onWipe(patch.id);
          return;
        }
      }
    },
    [patches, onWipe],
  );

  const rub = useSceneRub(frame, rubAt);
  const remaining = patches.filter((p) => !p.cleaned);
  const firstLeft = remaining.find((p) => p.x < HANDS.right);

  return (
    <GameHost
      title="Mud Off"
      instruction="Hop played by the pond! Swipe each patch away."
      progress={{ total: patches.length, done: patches.length - remaining.length }}
      caption={remaining.length < patches.length ? 'One patch gone!' : undefined}
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none">
          <View ref={rub.ref} onLayout={rub.onLayout} {...rub.panHandlers}>
            <GameBoard scene="scene.games.mudOff" frame={frame}>
              <HandSprite
                side="left"
                frame={frame}
                cx={HANDS.left}
                cy={HANDS.cy}
                handHeight={HANDS.height}
                rotate={HANDS.tilt}
                label="Hop, holding out his hands"
              />
              <HandSprite
                side="right"
                frame={frame}
                cx={HANDS.right}
                cy={HANDS.cy}
                handHeight={HANDS.height}
                rotate={HANDS.tilt}
              />

              {patches.map((patch) =>
                patch.cleaned ? (
                  <SparkleBurst
                    key={patch.id}
                    frame={frame}
                    cx={patch.x}
                    cy={patch.y}
                    scale={patch.radius / 22}
                  />
                ) : (
                  <IconSprite
                    key={patch.id}
                    artwork={MESS_ART[patch.kind]}
                    frame={frame}
                    cx={patch.x}
                    cy={patch.y}
                    size={MUD_BOX(patch.radius)}
                    label={MESS_LABEL[patch.kind]}
                    {...(onWipe ? { onPress: () => onWipe(patch.id) } : null)}
                  />
                ),
              )}

              {firstLeft ? (
                <SwipeHint
                  frame={frame}
                  cx={firstLeft.x + 6}
                  cy={firstLeft.y + 27}
                  length={124}
                  ringRadius={14.9}
                />
              ) : null}
            </GameBoard>
          </View>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  board: { flex: 1, justifyContent: 'center' },
});

export default MudOffGame;
