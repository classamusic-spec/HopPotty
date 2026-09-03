import React from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';

import { useHopTheme } from '../../design-system/theme';

/**
 * `StyleSheet.absoluteFillObject` is absent from React Native 0.87's generated
 * types, and this needs the spreadable object rather than the registered
 * `absoluteFill` style id.
 */
const HOP_ABSOLUTE_FILL = { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 } as const;

/**
 * The calm ring that fills while the child is sitting.
 *
 * Two rules make it calm rather than pressuring, and both are load-bearing:
 *
 * 1. **It fills; it never drains.** A shape that empties is a countdown, and a
 *    countdown in a bathroom is the exact feeling this product exists to remove.
 *    Something growing is something being made.
 * 2. **Nothing is gated on it.** The child can advance or leave at any fraction.
 *    Reaching the end changes nothing except that the ring is full.
 *
 * There is no number anywhere on it and never may be. It is also off by default
 * (`AppSettings.routineSitTimerEnabled`) — when a caregiver has not switched one
 * on, the try step is Hop, the sentence and the button, with nothing in the
 * middle, so the ring is `null` rather than zero.
 */
export interface RoutineTimerRingProps {
  /** 0…1. Clamped, so a caller cannot draw a ring past full. */
  readonly fraction: number;
  readonly diameter: number;
  /** Drawn inside the ring — Hop, sitting. */
  readonly children?: React.ReactNode;
  /** Read by VoiceOver in place of the ring itself. */
  readonly accessibilityLabel: string;
}

export function RoutineTimerRing({
  fraction,
  diameter,
  children,
  accessibilityLabel,
}: RoutineTimerRingProps): React.ReactElement {
  const theme = useHopTheme();
  const clamped = Math.min(1, Math.max(0, fraction));
  const stroke = Math.max(10, diameter * 0.085);
  const r = (diameter - stroke) / 2;
  const circumference = 2 * Math.PI * r;

  return (
    <View
      style={{ width: diameter, height: diameter }}
      accessible
      accessibilityRole="progressbar"
      accessibilityLabel={accessibilityLabel}
    >
      <Svg
        width={diameter}
        height={diameter}
        viewBox={`0 0 ${diameter} ${diameter}`}
        style={StyleSheet.absoluteFill}
      >
        <Circle
          cx={diameter / 2}
          cy={diameter / 2}
          r={r}
          fill="none"
          stroke={theme.palette.hopGreenSoft}
          strokeWidth={stroke}
        />
        <Circle
          cx={diameter / 2}
          cy={diameter / 2}
          r={r}
          fill="none"
          stroke={theme.palette.hopGreen}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={`${circumference}`}
          strokeDashoffset={circumference * (1 - clamped)}
          // Starts at the top and grows clockwise, which is the direction a
          // three-year-old has already seen on every timer in their house.
          transform={`rotate(-90 ${diameter / 2} ${diameter / 2})`}
        />
      </Svg>
      <View
        style={[styles.inside, { paddingBottom: theme.spacing.xxxl }]}
        pointerEvents="none"
      >
        {children}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  inside: { ...HOP_ABSOLUTE_FILL, alignItems: 'center', justifyContent: 'flex-end' },
});
