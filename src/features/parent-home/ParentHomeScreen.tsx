import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { HopButton, HopCard, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';

/**
 * Parent Home.
 *
 * The reference is `Art/render/screens/01-parent-home.png`. Parent Mode is
 * deliberately the restrained half of the product: neutral surfaces, real
 * typography, one accent. Hop appears here as a small greeting, not as the
 * subject — the subject is the next pause and what happened today.
 */

export interface TodayCounts {
  readonly checks: number;
  readonly tried: number;
  readonly pee: number;
  readonly poop: number;
}

export interface PottyEntry {
  readonly id: string;
  readonly time: string;
  readonly kind: 'Pee' | 'Poop' | 'Tried' | 'Accident';
}

export interface ParentHomeScreenProps {
  childName: string;
  stars: number;
  /** Seconds until the next scheduled pause, or null when none is scheduled. */
  nextPauseInSeconds: number | null;
  counts: TodayCounts;
  entries: readonly PottyEntry[];
  onSkip?: () => void;
  onStartNow?: () => void;
}

const two = (n: number) => String(n).padStart(2, '0');

function formatCountdown(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${two(m)}:${two(s)}`;
}

export function ParentHomeScreen({
  childName,
  stars,
  nextPauseInSeconds,
  counts,
  entries,
  onSkip,
  onStartNow,
}: ParentHomeScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <ScrollView
      style={{ backgroundColor: theme.color.backgroundPrimary }}
      contentContainerStyle={{ paddingBottom: theme.spacing.giant }}
    >
      {/* The pond band: Hop, the countdown, and the two ways to act on it. */}
      <View style={[styles.hero, { backgroundColor: theme.palette.pondBlueLight }]}>
        {/*
          The pond tint is a fixed brand hue with no dark variant, so on its own
          it stays a bright band under dark-mode text — which made the countdown
          and "Routine Mode" almost unreadable. The reference does not swap the
          colour either; it lays a scrim over the same pond and turns it into a
          night one. Same treatment here, same stops.
        */}
        {theme.isDark ? <HeroScrim /> : null}
        <View style={styles.heroRow}>
          <View
            style={[
              styles.chip,
              { backgroundColor: theme.color.surface, borderRadius: theme.radius.l },
            ]}
          >
            <HopText variant="parentFootnote" tone="secondary">
              Good afternoon,
            </HopText>
            <HopText variant="parentHeadline">{childName}</HopText>
          </View>
          <View
            style={[
              styles.stars,
              { backgroundColor: theme.color.surface, borderRadius: theme.radius.l },
            ]}
          >
            <HopText variant="parentHeadline" tone="brand">{`★ ${stars}`}</HopText>
          </View>
        </View>

        <View style={styles.mascot}>
          <HopCharacter
            size="hero"
            state="idle"
            accessibilityLabel={`Hop is waiting with ${childName}`}
          />
        </View>

        <HopText variant="parentCaption" tone="secondary" style={styles.centered}>
          NEXT POTTY PAUSE
        </HopText>
        <HopText variant="timerHero" style={styles.centered}>
          {nextPauseInSeconds === null ? '—' : formatCountdown(nextPauseInSeconds)}
        </HopText>
        <HopText variant="parentFootnote" tone="secondary" style={styles.centered}>
          ● Routine Mode
        </HopText>

        <View style={[styles.actions, { gap: theme.spacing.m }]}>
          <HopButton label="Skip" variant="secondary" onPress={onSkip} style={styles.action} />
          <HopButton label="Start Now" onPress={onStartNow} style={styles.action} />
        </View>
      </View>

      <HopCard style={[styles.card, { marginTop: -theme.spacing.xl }]}>
        <HopText variant="parentTitle">Today</HopText>
        <View style={[styles.counts, { marginTop: theme.spacing.m }]}>
          <Count value={counts.checks} label="Checks" />
          <Count value={counts.tried} label="Tried" />
          <Count value={counts.pee} label="Pee" />
          <Count value={counts.poop} label="Poop" />
        </View>
      </HopCard>

      <HopCard style={styles.card}>
        <View style={styles.entriesHeader}>
          <HopText variant="parentHeadline">Today&apos;s entries</HopText>
          <HopText variant="parentCallout" tone="brand">
            Show all
          </HopText>
        </View>
        {entries.length === 0 ? (
          <HopText variant="parentCallout" tone="secondary" style={{ marginTop: theme.spacing.m }}>
            Nothing logged yet today.
          </HopText>
        ) : (
          entries.map((entry) => (
            <View
              key={entry.id}
              style={[styles.entryRow, { borderTopColor: theme.color.divider }]}
            >
              <HopText variant="parentCallout" tone="secondary">
                {entry.time}
              </HopText>
              <HopText variant="parentCallout">{entry.kind}</HopText>
            </View>
          ))
        )}
      </HopCard>
    </ScrollView>
  );
}

/** Turns the day pond into a night one, rather than replacing it. */
function HeroScrim(): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <Svg width="100%" height="100%">
        <Defs>
          <LinearGradient id="parentHomeNight" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor={theme.color.scrim} stopOpacity={0.72} />
            <Stop offset="0.4" stopColor={theme.color.scrim} stopOpacity={0.54} />
            <Stop offset="1" stopColor={theme.color.scrim} stopOpacity={0.68} />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="100%" height="100%" fill="url(#parentHomeNight)" />
      </Svg>
    </View>
  );
}

function Count({ value, label }: { value: number; label: string }): React.ReactElement {
  return (
    <View style={styles.count}>
      <HopText variant="parentMetric">{String(value)}</HopText>
      <HopText variant="parentFootnote" tone="secondary">
        {label}
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { paddingTop: 12, paddingHorizontal: 16, paddingBottom: 40 },
  heroRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  chip: { paddingHorizontal: 12, paddingVertical: 6 },
  stars: { paddingHorizontal: 12, paddingVertical: 8 },
  mascot: { alignItems: 'center', marginVertical: 4 },
  centered: { textAlign: 'center' },
  actions: { flexDirection: 'row', marginTop: 16 },
  action: { flex: 1 },
  card: { marginHorizontal: 12, marginTop: 12 },
  counts: { flexDirection: 'row', justifyContent: 'space-between' },
  count: { alignItems: 'center', flex: 1 },
  entriesHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  entryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 8,
  },
});
