import React from 'react';
import { StyleSheet, View } from 'react-native';

import type { HopIllustrationKey } from '../../art/HopArtwork';
import { useHopTheme } from '../theme';
import { ChildStage } from './ChildStage';
import { HopButton } from './HopButton';
import { HopText } from './HopText';

/**
 * The chrome every mini-game sits inside.
 *
 * It owns the four things the games must all agree about, so no individual game
 * can quietly disagree: the way out is always on screen from the first frame;
 * there is no clock; there is no score; and every ending is the same ending.
 * `progress` draws quiet dots and is never rendered as a number.
 */
export interface GameHostProps {
  title: string;
  instruction: string;
  scene?: HopIllustrationKey;
  /** Sprites drawn over the scene, in the board's own space. */
  board?: React.ReactNode;
  /** Quiet marks under the board. Never a score. */
  progress?: { total: number; done: number };
  caption?: string;
  primaryLabel?: string;
  doneLabel?: string;
  onPrimary?: () => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

export function GameHost({
  title,
  instruction,
  scene,
  board,
  progress,
  caption,
  primaryLabel,
  doneLabel = 'All done',
  onPrimary,
  onDone,
  onGrownUp,
}: GameHostProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <ChildStage scene={scene} veilFrom={500} veilHeight={352} veilStrength={0.6}>
      <View style={styles.header}>
        <View style={styles.grownUpRow}>
          <GrownUpButton onPress={onGrownUp} />
        </View>
        <HopText variant="childTitle" style={styles.centered}>
          {title}
        </HopText>
        <HopText variant="childInstruction" tone="secondary" style={styles.centered}>
          {instruction}
        </HopText>
      </View>

      <View style={styles.board} pointerEvents="box-none">
        {board}
      </View>

      <View style={[styles.tray, { paddingHorizontal: theme.spacing.xl }]}>
        {progress ? <ProgressMarks {...progress} /> : null}
        {caption ? (
          <HopText variant="parentCallout" tone="secondary" style={styles.centered}>
            {caption}
          </HopText>
        ) : null}
        {primaryLabel ? (
          <HopButton
            label={primaryLabel}
            audience="child"
            onPress={onPrimary}
            style={styles.action}
          />
        ) : null}
        <HopButton
          label={doneLabel}
          audience="child"
          variant={primaryLabel ? 'secondary' : 'primary'}
          onPress={onDone}
          style={styles.action}
        />
      </View>
    </ChildStage>
  );
}

/** The way back to a grown-up, in the same corner on every child screen. */
export function GrownUpButton({ onPress }: { onPress?: () => void }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      accessibilityRole="button"
      accessibilityLabel="Need a grown-up"
      onTouchEnd={onPress}
      style={[
        styles.grownUp,
        { backgroundColor: theme.color.surface, borderRadius: theme.hitTarget.parentMinimum / 2 },
      ]}
    >
      <HopText variant="parentHeadline">✋</HopText>
    </View>
  );
}

/**
 * How far through a round the child is — as dots, never a count.
 *
 * A number here would turn a toy into a test, which is the one thing the games
 * are not allowed to become.
 */
export function ProgressMarks({ total, done }: { total: number; done: number }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View style={styles.marks} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: total, now: done }}>
      {Array.from({ length: total }, (_, i) => (
        <View
          key={i}
          style={[
            styles.mark,
            {
              backgroundColor: i < done ? theme.color.brandAction : theme.color.surface,
              borderColor: theme.color.divider,
            },
          ]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: 22, paddingTop: 8 },
  grownUpRow: { alignItems: 'flex-end', marginBottom: 4 },
  grownUp: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center' },
  centered: { textAlign: 'center' },
  board: { flex: 1 },
  tray: { alignItems: 'center', gap: 12, paddingBottom: 24 },
  action: { alignSelf: 'stretch' },
  marks: { flexDirection: 'row', gap: 10 },
  mark: { width: 34, height: 34, borderRadius: 17, borderWidth: 1 },
});
