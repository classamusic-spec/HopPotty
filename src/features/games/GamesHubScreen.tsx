import React from 'react';
import { Pressable, ScrollView, StyleSheet, View, useWindowDimensions } from 'react-native';
import Svg, { Defs, LinearGradient, Path, Rect, Stop } from 'react-native-svg';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { MiniGameId } from '../../navigation/types';
import { withAlpha } from './paint';

/**
 * Play — the eight games, all of them, always.
 *
 * References `Art/render/screens/21-games-hub.png` and `30-games-hub-dark.png`.
 *
 * A tile is a **door, not a card**: the whole thing is a picture of the place
 * the game happens in, with its name laid on the picture. Nothing here is
 * locked and nothing is ranked — no "new" flag, no "best", no progress ring on
 * a tile, no lock on a game a child has not reached. A grid that ranked itself
 * would turn eight toys into a ladder.
 *
 * The name sits on a *nameplate* rather than on a fade. A gradient still
 * arriving where the glyphs are puts white type on a pale bathroom wall; a
 * solid plate deep enough to carry white type over the brightest picture in the
 * set does not. The plate is a caption bar on a picture — part of the
 * composition — so the illustration keeps its whole upper two-thirds undimmed.
 */

export interface GamesHubEntry {
  readonly id: MiniGameId;
  readonly title: string;
  readonly scene: HopIllustrationKey;
}

/** `MiniGameCatalog.all`, in catalogue order. */
export const GAMES_HUB_ENTRIES: readonly GamesHubEntry[] = [
  { id: 'bubbleWash', title: 'Bubble Wash', scene: 'scene.games.bubbleWash' },
  { id: 'pottyPath', title: 'Potty Path', scene: 'scene.games.pottyPath' },
  { id: 'bathroomMatch', title: 'Bathroom Match', scene: 'scene.games.bathroomMatch' },
  { id: 'flySnack', title: 'Fly Snack', scene: 'scene.games.flySnack' },
  { id: 'mudOff', title: 'Mud Off', scene: 'scene.games.mudOff' },
  { id: 'bodySignal', title: 'Listen to Your Body', scene: 'scene.games.bodySignal' },
  { id: 'flushWave', title: 'Flush and Wave', scene: 'scene.games.flushWave' },
  { id: 'pottyOrder', title: 'Potty Order', scene: 'scene.games.pottyOrder' },
];

export interface GamesHubScreenProps {
  games?: readonly GamesHubEntry[];
  onOpen?: (id: MiniGameId) => void;
  onBack?: () => void;
}

/** The tile geometry the render harness draws (`gamesHub`), in points. */
const TILE = { height: 158, plate: 48, feather: 12, inset: 18, captionBottom: 11 } as const;
const GRID_GAP = 11;
/**
 * The green arch behind the title.
 *
 * The harness draws it 178 tall on a screen whose title row starts under a
 * status bar; stated instead as a relationship to the row it sits behind, it
 * lands in the same place whatever inset the row ends up with. The straight
 * edge finishes just above the row, and the curve hangs below it.
 */
const DOME_ABOVE_ROW = 10;
const DOME_LIP = 62;
/** How far past its own box the arch's belly hangs. */
const DOME_SAG = 10;
const BACK_SIDE = 56;
/** Past this width the hub is a wider grid, not a stretched phone. */
const WIDE = 768;

export function GamesHubScreen({
  games = GAMES_HUB_ENTRIES,
  onOpen,
  onBack,
}: GamesHubScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width } = useWindowDimensions();

  const columns = width >= WIDE ? 4 : 2;
  const pad = theme.spacing.l;
  const tileWidth = (width - pad * 2 - GRID_GAP * (columns - 1)) / columns;

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <Dome width={width} rowHeight={theme.hitTarget.childMinimum} />

      <View style={[styles.header, { paddingHorizontal: pad, height: theme.hitTarget.childMinimum }]}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Back"
          onPress={onBack}
          style={[
            styles.back,
            {
              width: BACK_SIDE,
              height: BACK_SIDE,
              borderRadius: BACK_SIDE / 2,
              backgroundColor: theme.isDark
                ? theme.color.surfaceElevated
                : withAlpha(theme.palette.cloud, 0.88),
            },
          ]}
        >
          <Svg width={26} height={26} viewBox="0 0 24 24">
            <Path
              d="M15 5l-7 7 7 7"
              fill="none"
              stroke={theme.isDark ? theme.color.textSecondary : theme.palette.sand600}
              strokeWidth={2.8}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </Svg>
        </Pressable>

        <HopText variant="childTitle" style={styles.title} accessibilityRole="header">
          Play
        </HopText>

        <View style={{ width: BACK_SIDE }} />
      </View>

      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: pad,
          paddingTop: theme.spacing.s,
          paddingBottom: theme.spacing.xxxl,
          gap: GRID_GAP,
        }}
      >
        <View style={[styles.grid, { gap: GRID_GAP }]}>
          {games.map((game) => (
            <GameDoor
              key={game.id}
              game={game}
              width={tileWidth}
              onPress={onOpen ? () => onOpen(game.id) : undefined}
            />
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

/** The soft green arch the hub's title sits in. */
function Dome({ width, rowHeight }: { width: number; rowHeight: number }): React.ReactElement {
  const theme = useHopTheme();
  const h = rowHeight - DOME_ABOVE_ROW + DOME_LIP;
  const fill = theme.isDark
    ? withAlpha(theme.palette.hopGreen, 0.13)
    : theme.palette.hopGreenSoft;
  return (
    <View pointerEvents="none" style={[styles.dome, { height: h }]}>
      <Svg width={width} height={h} viewBox={`0 0 ${width} ${h}`}>
        <Path
          d={
            `M 0 0 H ${width} V ${h - DOME_LIP} ` +
            `C ${width * 0.78} ${h + DOME_SAG}, ${width * 0.22} ${h + DOME_SAG}, 0 ${h - DOME_LIP} Z`
          }
          fill={fill}
        />
      </Svg>
    </View>
  );
}

function GameDoor({
  game,
  width,
  onPress,
}: {
  game: GamesHubEntry;
  width: number;
  onPress?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const plate = withAlpha(theme.palette.midnight, 0.78);

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={game.title}
      onPress={onPress}
      style={({ pressed }) => [
        styles.door,
        {
          width,
          height: TILE.height,
          borderRadius: theme.radius.xxl,
          backgroundColor: theme.color.surfaceSunken,
          opacity: pressed ? 0.88 : 1,
        },
      ]}
    >
      <HopArtwork artwork={game.scene} fit="cover" decorative style={StyleSheet.absoluteFill} />

      {/* A short feather joins the plate to the picture without dimming it. */}
      <View
        pointerEvents="none"
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: TILE.plate,
          height: TILE.feather,
        }}
      >
        <Svg width="100%" height="100%">
          <Defs>
            <LinearGradient id="hopDoorFeather" x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0" stopColor={theme.palette.midnight} stopOpacity={0} />
              <Stop offset="1" stopColor={theme.palette.midnight} stopOpacity={0.78} />
            </LinearGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#hopDoorFeather)" />
        </Svg>
      </View>
      <View
        pointerEvents="none"
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: TILE.plate,
          backgroundColor: plate,
        }}
      />
      <HopText
        variant="parentCallout"
        numberOfLines={2}
        style={{
          position: 'absolute',
          left: TILE.inset,
          right: TILE.inset,
          bottom: TILE.captionBottom,
          color: theme.palette.cloud,
        }}
      >
        {game.title}
      </HopText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  dome: { position: 'absolute', left: 0, right: 0, top: 0 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  back: { alignItems: 'center', justifyContent: 'center' },
  title: { flex: 1, textAlign: 'center' },
  grid: { flexDirection: 'row', flexWrap: 'wrap' },
  door: { overflow: 'hidden' },
});

export default GamesHubScreen;
