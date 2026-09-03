import React from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { StarGlyph } from '../child-hub/ChildGlyphs';
import { MeadowScene } from './MeadowScene';

/**
 * The end of a run: one sentence, one star, one way back.
 *
 * The reference is `Art/render/screens/09-routine-complete.png`. The sentence
 * celebrates the skill the child controls — the going and the trying — and never
 * the result, which is why all three answers to "All done trying?" arrive here
 * at the same screen with the same star.
 *
 * ## What is deliberately not here
 *
 * The lifetime star total. A running tally on the last screen of a bathroom trip
 * is a performance metric, and this screen is praise, not a scoreboard. The pond
 * is where stars live, and the quiet second line offers it to anyone who wants
 * to go and look.
 */
export interface RoutineCompleteScreenProps {
  /**
   * Stars earned by this run. Zero is legal — a child who left early keeps what
   * they earned and is never told what they missed — and simply hides the badge.
   */
  readonly starsEarned: number;
  /** Back to the game the pause interrupted. The promise being kept. */
  readonly onBackToPlay: () => void;
  readonly onSeePond: () => void;
}

/** Where the four sparkles sit around Hop, as fractions of the frame. */
const SPARKLES: readonly { readonly x: number; readonly y: number; readonly size: number; readonly opacity: number }[] = [
  { x: 0.01, y: 0.03, size: 26, opacity: 0.95 },
  { x: 0.8, y: 0.01, size: 19, opacity: 0.8 },
  { x: 0.08, y: 0.19, size: 15, opacity: 0.7 },
  { x: 0.84, y: 0.16, size: 23, opacity: 0.85 },
];

export function RoutineCompleteScreen({
  starsEarned,
  onBackToPlay,
  onSeePond,
}: RoutineCompleteScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const isWide = width >= 768;
  const hopSide = isWide ? 360 : 288;

  const starLine =
    starsEarned === 1 ? 'You earned a star!' : `You earned ${starsEarned} stars!`;

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <MeadowScene width={width} height={height} horizon={0.6} propsOffset={60} />

      <View
        style={[
          styles.content,
          {
            paddingHorizontal: theme.spacing.xxl,
            paddingBottom: theme.spacing.s,
            maxWidth: isWide ? 560 : undefined,
            alignSelf: isWide ? 'center' : 'stretch',
            width: isWide ? '100%' : undefined,
          },
        ]}
      >
        <View style={styles.headroom} />

        <View pointerEvents="none">
          <HopText variant="celebration" style={styles.centred} accessibilityRole="header">
            You listened to your body!
          </HopText>
        </View>

        {starsEarned > 0 ? (
          <View style={[styles.badgeRow, { marginTop: theme.spacing.l }]} pointerEvents="none">
            <View
              style={[
                styles.badge,
                {
                  backgroundColor: theme.palette.sunshineSoft,
                  borderRadius: theme.radius.xl,
                  paddingLeft: theme.spacing.l,
                  paddingRight: theme.spacing.xxl,
                  gap: theme.spacing.s,
                },
              ]}
              accessible
              accessibilityRole="text"
              accessibilityLabel={starLine}
            >
              <StarGlyph color={theme.palette.sunshineBright} size={30} />
              <HopText variant="buttonLarge" style={{ color: theme.palette.sunshineDeep }}>
                {starLine}
              </HopText>
            </View>
          </View>
        ) : null}

        <View style={[styles.mascot, { marginTop: theme.spacing.l }]} pointerEvents="none">
          <HopCharacter
            size={hopSide}
            state="celebrate"
            accessibilityLabel="Hop cheers with you"
          />
          {SPARKLES.map((sparkle) => (
            <View
              key={`${sparkle.x}-${sparkle.y}`}
              pointerEvents="none"
              style={{
                position: 'absolute',
                left: `${sparkle.x * 100}%`,
                top: `${sparkle.y * 100}%`,
                opacity: sparkle.opacity,
              }}
            >
              <StarGlyph color={theme.palette.sunshine} size={sparkle.size} />
            </View>
          ))}
        </View>

        <View style={styles.spacer} pointerEvents="none" />

        <View style={{ gap: theme.spacing.m }}>
          <HopButton
            label="Back to play!"
            audience="child"
            onPress={onBackToPlay}
            style={{ minHeight: 104, borderRadius: theme.radius.hero }}
          />
          <HopButton
            label="See your pond"
            audience="child"
            variant="secondary"
            onPress={onSeePond}
            style={{ minHeight: theme.hitTarget.childMinimum, borderRadius: theme.radius.hero }}
          />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
  headroom: { height: 26 },
  centred: { textAlign: 'center' },
  badgeRow: { alignItems: 'center' },
  badge: { minHeight: 56, flexDirection: 'row', alignItems: 'center' },
  mascot: { alignItems: 'center' },
  spacer: { flex: 1 },
});
