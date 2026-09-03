import React from 'react';
import { Pressable, StyleSheet, View, useWindowDimensions } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { HOP_FEET_FRACTION } from '../../mascot/poses.generated';
import { PondScene } from '../pond/PondScene';
import { ChevronGlyph, HandGlyph, StarGlyph } from './ChildGlyphs';

/**
 * Hop's hub — the child's home.
 *
 * The reference is `Art/render/screens/45-hop-hub.png`. The pond is the whole
 * screen and Hop lives in it; the four doors are picture buttons a two-year-old
 * can hit without reading a word, and the only way back to the grown-up side is
 * the small pill in the corner, which sits behind the parent gate.
 *
 * The star count is a count, not a target: it says how many there are and
 * nothing about how many there should be. There is no streak, no daily goal and
 * no badge, because the moment the number acquires an expectation this stops
 * being a place a child wants to visit.
 *
 * Hop's pond gets no decorations here on purpose. This is the ground the hub
 * stands on; a child's collection belongs on the screen that is about their
 * collection.
 */

/** One of the four doors. */
export interface HopHubScreenProps {
  /** The child's nickname, or null when none is set. */
  readonly childName?: string | null;
  /** Stars in the pond. Shown as a count, never as progress towards anything. */
  readonly stars: number;
  readonly onPottyTime: () => void;
  readonly onPond: () => void;
  readonly onGames: () => void;
  readonly onQuestions: () => void;
  /** Raises the parent gate. Never a plain way out. */
  readonly onGrownUps: () => void;
}

/** How large Hop stands in the scene, and where his feet land. */
const HOP_WIDTH = 214;
const HOP_GROUND = 0.5;

export function HopHubScreen({
  childName,
  stars,
  onPottyTime,
  onPond,
  onGames,
  onQuestions,
  onGrownUps,
}: HopHubScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const isWide = width >= 768;
  const hopSide = isWide ? HOP_WIDTH * 1.25 : HOP_WIDTH;

  const greeting = childName ? `Hi, ${childName}!` : 'Hi!';

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <PondScene width={width} height={height} showsHop={false} />

      {/* the wash that lets four large doors sit on a drawing without cards */}
      <Svg width={width} height={height} style={StyleSheet.absoluteFill} pointerEvents="none">
        <Defs>
          <LinearGradient id="hubWash" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0.42" stopColor={theme.color.backgroundPrimary} stopOpacity={0} />
            <Stop offset="0.7" stopColor={theme.color.backgroundPrimary} stopOpacity={0.55} />
            <Stop offset="1" stopColor={theme.color.backgroundPrimary} stopOpacity={0.9} />
          </LinearGradient>
        </Defs>
        <Rect x={0} y={0} width={width} height={height} fill="url(#hubWash)" />
      </Svg>

      <View
        pointerEvents="none"
        style={{
          position: 'absolute',
          left: width / 2 - hopSide / 2,
          top: height * HOP_GROUND - hopSide * HOP_FEET_FRACTION,
          width: hopSide,
          height: hopSide,
        }}
      >
        <HopCharacter size={hopSide} state="wave" accessibilityLabel="Hop waves hello" />
      </View>

      <View
        style={[
          styles.content,
          {
            paddingHorizontal: theme.spacing.xl,
            paddingBottom: theme.spacing.s,
            maxWidth: isWide ? 640 : undefined,
            alignSelf: isWide ? 'center' : 'stretch',
            width: isWide ? '100%' : undefined,
          },
        ]}
        pointerEvents="box-none"
      >
        <View style={styles.topRow} pointerEvents="box-none">
          <View
            style={[
              styles.starPill,
              {
                backgroundColor: theme.color.surface,
                borderRadius: theme.hitTarget.parentMinimum / 2,
                gap: theme.spacing.xs,
              },
            ]}
            accessible
            accessibilityRole="text"
            accessibilityLabel={stars === 1 ? '1 star' : `${stars} stars`}
          >
            <StarGlyph color={theme.palette.sunshineBright} size={21} />
            <HopText variant="parentTitle">{String(stars)}</HopText>
          </View>

          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Grown-ups"
            accessibilityHint="Opens the grown-up area. A grown-up answers a question first."
            onPress={onGrownUps}
            style={({ pressed }) => [
              styles.grownUpPill,
              {
                backgroundColor: theme.color.surface,
                borderRadius: theme.hitTarget.parentMinimum / 2,
                paddingHorizontal: theme.spacing.l,
                gap: theme.spacing.xs,
                opacity: pressed ? 0.85 : 1,
              },
            ]}
          >
            <HandGlyph color={theme.palette.sand500} size={16} />
            <HopText variant="parentCallout" tone="secondary">
              Grown-ups
            </HopText>
          </Pressable>
        </View>

        <View style={styles.greeting} pointerEvents="none">
          <HopText variant="childTitle" style={styles.centred} accessibilityRole="header">
            {greeting}
          </HopText>
          <HopText variant="parentTitle" tone="secondary" style={styles.centred}>
            What shall we do?
          </HopText>
        </View>

        <View style={styles.spacer} pointerEvents="none" />

        <View style={{ gap: theme.spacing.m }}>
          <HubDoor
            label="Potty time"
            hint="Hop comes along for every step."
            artwork="scene.routine.try"
            primary
            onPress={onPottyTime}
          />
          <HubDoor
            label="Hop's Pond"
            hint="See the friends in your pond."
            pondThumbnail
            onPress={onPond}
          />
          <HubDoor
            label="Games"
            hint="Pick a game to play with Hop."
            artwork="scene.games.flySnack"
            onPress={onGames}
          />
          <HubDoor
            label="Hop's questions"
            hint="Hop asks you three things."
            artwork="scene.games.bodySignal"
            onPress={onQuestions}
          />
        </View>
      </View>
    </View>
  );
}

/** The thumbnail size every door shares, so no door reads as bigger. */
const THUMB = { width: 88, height: 64 } as const;

/**
 * One door.
 *
 * All four are the same height and the same shape. The first is filled because
 * it is the thing the product is for, not because the other three are lesser —
 * which is why the picture, the word and the chevron are identical on all of
 * them.
 */
function HubDoor({
  label,
  hint,
  artwork,
  pondThumbnail = false,
  primary = false,
  onPress,
}: {
  readonly label: string;
  readonly hint: string;
  readonly artwork?: HopIllustrationKey;
  readonly pondThumbnail?: boolean;
  readonly primary?: boolean;
  readonly onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={hint}
      onPress={onPress}
      style={({ pressed }) => [
        styles.door,
        {
          minHeight: theme.hitTarget.childMinimum,
          borderRadius: theme.radius.xl,
          paddingLeft: theme.spacing.s,
          paddingRight: theme.spacing.l,
          gap: theme.spacing.m,
          backgroundColor: primary ? theme.color.brandAction : theme.color.surface,
          opacity: pressed ? 0.9 : 1,
        },
      ]}
    >
      <View style={[styles.thumb, { borderRadius: theme.radius.m }]}>
        {pondThumbnail ? (
          <PondScene width={THUMB.width} height={THUMB.height} showsHop={false} />
        ) : artwork ? (
          <HopArtwork
            artwork={artwork}
            width={THUMB.width}
            height={THUMB.height}
            fit="cover"
            decorative
          />
        ) : null}
      </View>

      <View style={styles.doorLabel} pointerEvents="none">
        <HopText variant="buttonLarge" tone={primary ? 'onBrand' : 'primary'}>
          {label}
        </HopText>
      </View>

      <ChevronGlyph
        color={primary ? theme.color.textOnBrand : theme.palette.sand500}
        size={22}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
  topRow: {
    height: 52,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  starPill: {
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: 11,
    paddingRight: 15,
  },
  grownUpPill: { minHeight: 44, flexDirection: 'row', alignItems: 'center' },
  greeting: { marginTop: 8 },
  centred: { textAlign: 'center' },
  spacer: { flex: 1 },
  door: { flexDirection: 'row', alignItems: 'center' },
  thumb: { width: THUMB.width, height: THUMB.height, overflow: 'hidden' },
  doorLabel: { flex: 1 },
});
