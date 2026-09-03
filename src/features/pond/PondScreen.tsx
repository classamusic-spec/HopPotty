import React from 'react';
import { Pressable, ScrollView, StyleSheet, View, useWindowDimensions } from 'react-native';
import Svg, { Circle } from 'react-native-svg';

import { HopArtwork } from '../../art/HopArtwork';
import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { ChevronGlyph, LockGlyph, StarGlyph } from '../../design-system/components/ChildGlyphs';
import { PondScene } from './PondScene';
import { pondArtwork, type PondItemId } from './pondLayout';

/**
 * Hop's Pond — where the stars go.
 *
 * The reference is `Art/render/screens/10-hops-pond.png`. The reward is a
 * *place*, not a score: every star spends on something that stays in the scene,
 * the price of the next thing is visible in advance, and there is no randomness
 * anywhere. So the pond fills the screen and the child's own decorations are
 * drawn in it; the title, the star count and the collection float over the water
 * as chrome.
 *
 * The tray is deliberately shallow. It is a way of finding a thing by name — and
 * of seeing what is coming — not the point of the screen. The point of the
 * screen is above it.
 *
 * ## What is not on it
 *
 * No "next" nagging, no timer on an unlock, no way to spend a star twice and no
 * way to lose one. A locked tile shows its price and nothing else; it is a thing
 * that is coming, never a thing the child has failed to reach.
 */

/** What is coming next, and how far away it is. */
export interface PondNextUnlock {
  readonly id: PondItemId;
  /** The item's name, as it appears in the sentence: "a dragonfly". */
  readonly name: string;
  /** Stars still to earn. */
  readonly starsNeeded: number;
  /** What it costs in total, shown on its locked tile. */
  readonly starCost: number;
  /** 0…1 of the way there. Drawn as a ring, never as a percentage. */
  readonly progress: number;
}

export interface PondScreenProps {
  /** The child's nickname, or null when none is set. */
  readonly childName?: string | null;
  /** Stars available to spend. */
  readonly stars: number;
  /** Decorations already in the pond, in unlock order. */
  readonly unlocked: readonly PondItemId[];
  /** How many decorations there are in all. */
  readonly collectionTotal: number;
  readonly nextUnlock?: PondNextUnlock | null;
  readonly onBack?: () => void;
}

export function PondScreen({
  childName,
  stars,
  unlocked,
  collectionTotal,
  nextUnlock = null,
  onBack,
}: PondScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const isWide = width >= 768;

  const title = childName ? `${childName}'s pond` : 'Your pond';
  const isEmpty = unlocked.length === 0 && nextUnlock === null;
  const nextLine = nextUnlock
    ? nextUnlock.starsNeeded === 1
      ? `1 more star and ${nextUnlock.name} hops in!`
      : `${nextUnlock.starsNeeded} more stars and ${nextUnlock.name} hops in!`
    : null;

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <PondScene
        width={width}
        height={height}
        unlocked={unlocked}
        hopAccessibilityLabel="Hop, sitting on his lily pad"
      />

      <View style={styles.content} pointerEvents="box-none">
        {/* chrome, floating over the water */}
        <View
          style={[styles.chrome, { paddingHorizontal: theme.spacing.xl, gap: theme.spacing.s }]}
          pointerEvents="box-none"
        >
          {onBack ? (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Back"
              onPress={onBack}
              style={({ pressed }) => [
                styles.pill,
                styles.roundPill,
                {
                  backgroundColor: theme.color.surface,
                  borderRadius: theme.hitTarget.parentMinimum / 2,
                  opacity: pressed ? 0.85 : 1,
                },
              ]}
            >
              <ChevronGlyph color={theme.color.brandAction} size={24} direction="back" />
            </Pressable>
          ) : (
            <View style={styles.pillSpacer} />
          )}

          <View style={styles.chromeGap} />

          <View
            style={[
              styles.pill,
              {
                backgroundColor: theme.color.surface,
                borderRadius: theme.hitTarget.parentMinimum / 2,
                paddingHorizontal: theme.spacing.l,
              },
            ]}
          >
            <HopText variant="parentTitle">{title}</HopText>
          </View>

          <View style={styles.chromeGap} />

          <View
            style={[
              styles.pill,
              {
                backgroundColor: theme.color.surface,
                borderRadius: theme.hitTarget.parentMinimum / 2,
                paddingHorizontal: theme.spacing.m,
                gap: theme.spacing.xs,
              },
            ]}
            accessible
            accessibilityRole="text"
            accessibilityLabel={stars === 1 ? '1 star' : `${stars} stars`}
          >
            <StarGlyph color={theme.palette.sunshineBright} size={20} />
            <HopText variant="parentTitle">{String(stars)}</HopText>
          </View>
        </View>

        <View style={styles.spacer} pointerEvents="none" />

        {/* the tray: what is coming, then the collection */}
        <View
          style={[
            styles.tray,
            {
              backgroundColor: theme.color.surface,
              borderTopLeftRadius: theme.radius.hero,
              borderTopRightRadius: theme.radius.hero,
              paddingHorizontal: theme.spacing.xl,
              paddingTop: theme.spacing.l,
              paddingBottom: theme.spacing.xs,
              maxWidth: isWide ? 720 : undefined,
              alignSelf: isWide ? 'center' : 'stretch',
              width: isWide ? '100%' : undefined,
            },
          ]}
        >
          {nextUnlock && nextLine ? (
            <View style={[styles.nextRow, { gap: theme.spacing.m }]} accessible accessibilityRole="text" accessibilityLabel={nextLine}>
              <View style={styles.nextArt}>
                <HopArtwork artwork={pondArtwork(nextUnlock.id)} width={52} height={52} decorative />
              </View>
              <HopText variant="parentTitle" style={styles.nextLine}>
                {nextLine}
              </HopText>
              <ProgressRing
                fraction={nextUnlock.progress}
                diameter={38}
                track={theme.palette.hopGreenSoft}
                fill={theme.color.brandAction}
              />
            </View>
          ) : null}

          {isEmpty ? (
            // Day one. Never "no decorations yet": the ledger only ever grows,
            // so an empty pond reads as a beginning rather than as an absence.
            <View style={{ paddingTop: theme.spacing.m, paddingBottom: theme.spacing.m }}>
              <HopText variant="parentTitle">Your pond is ready</HopText>
              <HopText variant="parentCallout" tone="secondary">
                Every star adds something new.
              </HopText>
            </View>
          ) : (
            <>
              <View
                style={[styles.collectionHeader, { gap: theme.spacing.s, paddingTop: theme.spacing.m }]}
              >
                <HopText variant="parentTitle">Your collection</HopText>
                <HopText variant="parentCallout" tone="secondary">
                  {`${unlocked.length} of ${collectionTotal}`}
                </HopText>
              </View>

              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={[
                  styles.strip,
                  { gap: theme.spacing.s, paddingTop: theme.spacing.s },
                ]}
              >
                {unlocked.map((id) => (
                  <CollectionTile key={id} id={id} />
                ))}
                {nextUnlock ? <CollectionTile locked cost={nextUnlock.starCost} /> : null}
              </ScrollView>
            </>
          )}
        </View>
      </View>
    </View>
  );
}

/**
 * One square in the collection.
 *
 * Unlocked and locked are the same size and the same shape. The only difference
 * is a gold edge and the word "Yours!" against a soft dashed edge and a price —
 * because a thing still coming is not a thing withheld.
 */
function CollectionTile({
  id,
  locked = false,
  cost,
}: {
  readonly id?: PondItemId;
  readonly locked?: boolean;
  readonly cost?: number;
}): React.ReactElement {
  const theme = useHopTheme();

  return (
    <View
      style={[styles.tile, { gap: theme.spacing.xs }]}
      accessible
      accessibilityRole="image"
      accessibilityLabel={
        locked ? `Still to come. ${cost === 1 ? '1 star' : `${cost ?? 0} stars`}` : 'Yours!'
      }
    >
      <View
        style={[
          styles.tileBox,
          {
            borderRadius: theme.radius.m,
            backgroundColor: locked ? theme.color.surfaceSunken : theme.color.surface,
            borderColor: locked ? theme.palette.sand300 : theme.palette.sunshineBright,
            borderStyle: locked ? 'dashed' : 'solid',
            borderWidth: locked ? 1.5 : 2,
          },
        ]}
      >
        {locked || !id ? (
          <LockGlyph color={theme.palette.sand300} size={18} />
        ) : (
          <HopArtwork artwork={pondArtwork(id)} width={34} height={34} decorative />
        )}
      </View>

      {locked ? (
        <View style={[styles.tileCost, { gap: theme.spacing.xxs }]}>
          <StarGlyph color={theme.palette.sunshineBright} size={10} />
          <HopText variant="parentFootnote" tone="secondary">
            {String(cost ?? 0)}
          </HopText>
        </View>
      ) : (
        <HopText variant="parentFootnote" tone="brand">
          Yours!
        </HopText>
      )}
    </View>
  );
}

/**
 * How close the next decoration is.
 *
 * A ring that fills, with no number on it — the sentence beside it already says
 * how many stars are left, and saying it twice would make it a target.
 */
function ProgressRing({
  fraction,
  diameter,
  track,
  fill,
}: {
  readonly fraction: number;
  readonly diameter: number;
  readonly track: string;
  readonly fill: string;
}): React.ReactElement {
  const clamped = Math.min(1, Math.max(0, fraction));
  const stroke = diameter * 0.2;
  const r = (diameter - stroke) / 2;
  const circumference = 2 * Math.PI * r;

  return (
    <Svg width={diameter} height={diameter} viewBox={`0 0 ${diameter} ${diameter}`}>
      <Circle cx={diameter / 2} cy={diameter / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
      <Circle
        cx={diameter / 2}
        cy={diameter / 2}
        r={r}
        fill="none"
        stroke={fill}
        strokeWidth={stroke}
        strokeDasharray={`${circumference}`}
        strokeDashoffset={circumference * (1 - clamped)}
        transform={`rotate(-90 ${diameter / 2} ${diameter / 2})`}
      />
    </Svg>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
  chrome: { flexDirection: 'row', alignItems: 'center', paddingTop: 4 },
  chromeGap: { flex: 1 },
  pill: { height: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'center' },
  roundPill: { width: 44 },
  pillSpacer: { width: 44, height: 44 },
  spacer: { flex: 1 },
  tray: { overflow: 'hidden' },
  nextRow: { flexDirection: 'row', alignItems: 'center' },
  nextArt: { width: 52, height: 52, opacity: 0.42, alignItems: 'center', justifyContent: 'center' },
  nextLine: { flex: 1 },
  collectionHeader: { flexDirection: 'row', alignItems: 'baseline' },
  strip: { flexDirection: 'row', alignItems: 'flex-start' },
  tile: { width: 52, alignItems: 'center' },
  tileBox: { width: 52, height: 52, alignItems: 'center', justifyContent: 'center' },
  tileCost: { flexDirection: 'row', alignItems: 'center' },
});
