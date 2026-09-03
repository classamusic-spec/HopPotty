import React, { useMemo } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';

import type { HopIllustrationKey } from '../../art/HopArtwork';
import { ChildStage, GameHost, GrownUpButton, HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { TummyMeter } from './boardTray';
import { GameBoard } from './GameBoard';
import { withAlpha } from './paint';
import { boardFrame } from './sceneFrame';
import { HopSprite, IconSprite, Sparkle, TapHint } from './sprites';

/**
 * Fly Snack — the whole chain in one minute: eating gives the body a signal,
 * and the signal means it is time to go.
 *
 * References `Art/render/screens/24-game-fly-snack.png` and
 * `29-game-fly-snack-handoff.png`.
 *
 * A fly the child does not catch drifts off and comes round again, so there is
 * nothing to miss and nothing to count. The tummy fills only on catches, which
 * is why it can be six friendly beads rather than a bar that could look like it
 * was running out — and why there is no number beside it.
 *
 * This is the one game whose round finishes by walking the child into the
 * guided routine. The ending names the place it is taking them rather than
 * offering a door back to the game list, and the way out is still offered
 * beside it: neither choice is a failure and neither takes anything away.
 */

export type FlyKind = 'blue' | 'green' | 'gold';

export interface Fly {
  readonly id: string;
  readonly kind: FlyKind;
  /** Where it is, in the scene's own coordinates, and how big it is there. */
  readonly x: number;
  readonly y: number;
  readonly size: number;
  /** The one a nudge is pointing at. A pulse, never a countdown. */
  readonly hinted?: boolean;
}

export interface FlySnackGameProps {
  /** `handOff` is the ending that walks the child to the bathroom. */
  phase?: 'play' | 'handOff';
  /** How full Hop's tummy is. Never rendered as a number. */
  fed?: number;
  flies?: readonly Fly[];
  onCatch?: (id: string) => void;
  onStartRoutine?: () => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

const FLY_ART: Readonly<Record<FlyKind, HopIllustrationKey>> = {
  blue: 'icon.games.fly.blue',
  green: 'icon.games.fly.green',
  gold: 'icon.games.fly.gold',
};

/** Hop on his lily pad, and the flies the render draws around him. */
const HOP = { cx: 320, groundY: 422, size: 260 } as const;
const TUMMY_TOTAL = 6;
/** The ending's Hop, at the size the render draws him. */
const HOP_ENDING = 257;

export const FLY_SNACK_FLIES: readonly Fly[] = [
  { id: 'f1', kind: 'blue', x: 138, y: 202, size: 78 },
  { id: 'f2', kind: 'green', x: 430, y: 150, size: 71, hinted: true },
  { id: 'f3', kind: 'gold', x: 456, y: 244, size: 64 },
];

export function FlySnackGame({
  phase = 'play',
  fed = 4,
  flies = FLY_SNACK_FLIES,
  onCatch,
  onStartRoutine,
  onDone,
  onGrownUp,
}: FlySnackGameProps): React.ReactElement {
  const { width } = useWindowDimensions();
  const frame = useMemo(() => boardFrame(width), [width]);

  if (phase === 'handOff') {
    return <FlySnackHandOff onStartRoutine={onStartRoutine} onDone={onDone} onGrownUp={onGrownUp} />;
  }

  return (
    <GameHost
      title="Fly Snack"
      instruction="Hop is on his lily pad. Tap the flies for a snack!"
      caption="Yum! Hop's tummy is filling up."
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none">
          <View style={styles.bandSlot} pointerEvents="box-none">
            <GameBoard scene="scene.games.flySnack" frame={frame}>
              <HopSprite
                frame={frame}
                cx={HOP.cx}
                groundY={HOP.groundY}
                size={HOP.size}
                state="talk"
                label="Hop on his lily pad"
              />

              {flies.map((fly) => (
                <React.Fragment key={fly.id}>
                  {fly.hinted ? (
                    <TapHint frame={frame} cx={fly.x} cy={fly.y} radius={48.9} rings={2} />
                  ) : null}
                  <IconSprite
                    artwork={FLY_ART[fly.kind]}
                    frame={frame}
                    cx={fly.x}
                    cy={fly.y}
                    size={fly.size}
                    label="A fly"
                    {...(onCatch ? { onPress: () => onCatch(fly.id) } : null)}
                  />
                </React.Fragment>
              ))}

              <Sparkle frame={frame} cx={226} cy={198} radius={11.4} opacity={0.9} />
              <Sparkle frame={frame} cx={486} cy={214} radius={10.4} opacity={0.9} />
            </GameBoard>
          </View>

          <View style={styles.meter}>
            <TummyMeter filled={fed} total={TUMMY_TOTAL} />
          </View>
        </View>
      }
    />
  );
}

/**
 * 29 — the ending, which is the lesson: Hop ate, Hop's tummy filled, and now
 * Hop needs the potty.
 */
function FlySnackHandOff({
  onStartRoutine,
  onDone,
  onGrownUp,
}: {
  onStartRoutine?: () => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <ChildStage scene="scene.games.flySnack" veilFrom={420} veilHeight={432} veilStrength={0.72}>
      <View style={[styles.endingRow, { paddingHorizontal: theme.spacing.xl }]}>
        <GrownUpButton onPress={onGrownUp} />
      </View>

      <View style={[styles.ending, { paddingHorizontal: theme.spacing.xl, gap: theme.spacing.l }]}>
        <HopText variant="celebration" style={styles.centered} accessibilityRole="header">
          {"Hop's tummy says:\npotty time!"}
        </HopText>

        <TummyMeter filled={TUMMY_TOTAL} total={TUMMY_TOTAL} />

        <View style={styles.grow} />

        <SpeechBubble text="Let's hop to the potty together." />
        <HopCharacter
          size={HOP_ENDING}
          state="sit"
          accessibilityLabel="Hop, with a full tummy"
        />

        <View style={styles.grow} />

        <View style={[styles.actions, { gap: theme.spacing.m }]}>
          <HopButton
            label="Let's go!"
            audience="child"
            onPress={onStartRoutine}
            style={styles.action}
          />
          <HopButton
            label="All done"
            audience="child"
            variant="secondary"
            onPress={onDone}
            style={styles.action}
          />
        </View>
      </View>
    </ChildStage>
  );
}

/** What Hop is saying, drawn the way a picture book draws it. */
function SpeechBubble({ text }: { text: string }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View style={styles.bubbleWrap}>
      <View
        style={[
          styles.bubble,
          {
            paddingVertical: theme.spacing.m,
            paddingHorizontal: theme.spacing.xxl,
            borderRadius: theme.radius.xl,
            backgroundColor: theme.color.surface,
          },
        ]}
      >
        <HopText variant="parentTitle" style={styles.centered}>
          {text}
        </HopText>
      </View>
      <View
        style={[
          styles.tail,
          {
            backgroundColor: theme.color.surface,
            borderColor: withAlpha(theme.palette.midnight, 0),
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  board: { flex: 1 },
  bandSlot: { flex: 1, justifyContent: 'center' },
  meter: { alignItems: 'center' },
  ending: { flex: 1, alignItems: 'center' },
  endingRow: { alignItems: 'flex-end', paddingTop: 8 },
  centered: { textAlign: 'center' },
  grow: { flex: 1 },
  actions: { alignSelf: 'stretch' },
  action: { alignSelf: 'stretch' },
  bubbleWrap: { alignItems: 'center', maxWidth: 300 },
  bubble: { alignItems: 'center' },
  tail: {
    width: 22,
    height: 22,
    marginTop: -11,
    borderRadius: 4,
    transform: [{ rotate: '45deg' }],
  },
});

export default FlySnackGame;
