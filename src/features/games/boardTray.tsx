import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { withAlpha } from './paint';

/**
 * The pieces that sit under a board rather than on it.
 *
 * Sizes here are the render harness's own, in points
 * (`Scripts/screens/child-extra.js`): a tummy bead is 31×27 because that is
 * what the reference draws, and re-deriving it by eye would be the regression
 * `Docs/ReactNativeConventions.md` warns about. Colour, radius and type still
 * come from the tokens.
 */

// ---------------------------------------------------------------------------
// Hop's tummy, filling up
// ---------------------------------------------------------------------------

const TUMMY = {
  bead: { width: 31, height: 27, radius: 13.5 },
  face: 38,
  hop: 44,
  pill: 27,
} as const;

/**
 * Six beads that fill from the left.
 *
 * There is no total on screen and no number: a tummy that is getting full is a
 * friendly thing, and a bar that could look like it was running out would say
 * the opposite. This is also why it fills rather than drains.
 */
export function TummyMeter({
  filled,
  total = 6,
  label = "Hop's tummy",
}: {
  filled: number;
  total?: number;
  label?: string;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel={label}
      style={[
        styles.tummy,
        {
          gap: theme.spacing.m,
          paddingVertical: theme.spacing.s,
          paddingLeft: theme.spacing.s,
          paddingRight: theme.spacing.l,
          borderRadius: TUMMY.pill,
          backgroundColor: withAlpha(theme.palette.cloud, 0.94),
        },
      ]}
    >
      <View
        style={[
          styles.tummyFace,
          {
            width: TUMMY.face,
            height: TUMMY.face,
            borderRadius: TUMMY.face / 2,
            backgroundColor: theme.palette.sunshineSoft,
          },
        ]}
      >
        <HopCharacter size={TUMMY.hop} state="idle" decorative />
      </View>
      <View style={[styles.tummyBeads, { gap: theme.spacing.xs + theme.spacing.xxs }]}>
        {Array.from({ length: total }, (_, i) => {
          const on = i < filled;
          return (
            <View
              key={i}
              style={{
                width: TUMMY.bead.width,
                height: TUMMY.bead.height,
                borderRadius: TUMMY.bead.radius,
                backgroundColor: on
                  ? theme.palette.peachDeep
                  : withAlpha(theme.palette.cloud, 0.82),
                borderWidth: on ? 0 : 2,
                borderColor: withAlpha(theme.palette.peachDeep, 0.2),
                overflow: 'hidden',
              }}
            >
              {on ? (
                <View
                  style={{
                    height: TUMMY.bead.height * 0.3,
                    marginTop: theme.spacing.xs,
                    marginHorizontal: theme.spacing.s - theme.spacing.xxs,
                    borderRadius: theme.radius.xs,
                    backgroundColor: withAlpha(theme.palette.peachPop, 0.55),
                  }}
                />
              ) : null}
            </View>
          );
        })}
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Picture tiles
// ---------------------------------------------------------------------------

export type TileState = 'faceUp' | 'faceDown' | 'matched';

export interface MatchTileProps {
  /** The thing on the tile. Not drawn while the tile is face down. */
  artwork: HopIllustrationKey;
  label: string;
  state: TileState;
  /** The one a nudge is pointing at. Never a countdown, never a wrong answer. */
  hinted?: boolean;
  onPress?: () => void;
}

const TILE = { width: 88, height: 74, art: 46, badge: 24 } as const;

/**
 * One tile on the Bathroom Match shelf.
 *
 * A tile still face down is drawn as an open dashed outline rather than as a
 * gap, so nothing on the board ever looks lost, and a matched pair is marked
 * with a tick as well as a colour.
 */
export function MatchTile({
  artwork,
  label,
  state,
  hinted = false,
  onPress,
}: MatchTileProps): React.ReactElement {
  const theme = useHopTheme();
  const faceDown = state === 'faceDown';
  const matched = state === 'matched';

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ selected: matched }}
      onPress={onPress}
      style={[
        styles.tile,
        {
          width: TILE.width,
          height: TILE.height,
          borderRadius: theme.radius.m,
          backgroundColor: faceDown
            ? withAlpha(theme.palette.lavenderSoft, 0.85)
            : theme.color.surface,
          borderWidth: matched ? 3 : faceDown ? 2.4 : 2,
          borderStyle: faceDown ? 'dashed' : 'solid',
          borderColor: matched
            ? theme.palette.hopGreenDeep
            : withAlpha(theme.palette.lavenderDeep, faceDown ? 0.42 : 0.22),
          ...(hinted
            ? {
                shadowColor: theme.palette.pondBlueDeep,
                shadowOpacity: 0.5,
                shadowRadius: 6,
                shadowOffset: { width: 0, height: 0 },
              }
            : null),
        },
      ]}
    >
      {faceDown ? (
        <View
          style={[
            styles.faceDown,
            {
              width: TILE.art * 0.62,
              height: TILE.art * 0.62,
              borderRadius: TILE.art * 0.31,
              borderColor: withAlpha(theme.palette.lavenderDeep, 0.5),
            },
          ]}
        >
          <View
            style={{
              width: TILE.art * 0.2,
              height: TILE.art * 0.2,
              borderRadius: TILE.art * 0.1,
              backgroundColor: withAlpha(theme.palette.lavenderDeep, 0.5),
            }}
          />
        </View>
      ) : (
        <HopArtwork
          artwork={artwork}
          fit="contain"
          decorative
          style={{ width: TILE.art, height: TILE.art }}
        />
      )}
      {matched ? (
        <View
          style={[
            styles.badge,
            {
              width: TILE.badge,
              height: TILE.badge,
              borderRadius: TILE.badge / 2,
              backgroundColor: theme.palette.hopGreenDeep,
            },
          ]}
        >
          <View style={styles.check}>
            <View
              style={{
                width: TILE.badge * 0.42,
                height: TILE.badge * 0.2,
                borderLeftWidth: 2.6,
                borderBottomWidth: 2.6,
                borderColor: theme.color.textOnBrand,
                transform: [{ rotate: '-45deg' }],
              }}
            />
          </View>
        </View>
      ) : null}
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// The cards still in hand
// ---------------------------------------------------------------------------

const HAND_CARD = { width: 74, height: 88, art: 58, radius: 16 } as const;

export interface HandCardProps {
  artwork: HopIllustrationKey;
  label: string;
  /** Already on the path. Its place in the hand stays, drawn as an outline. */
  placed?: boolean;
  /** Picked up and waiting for a spot. */
  held?: boolean;
  onPress?: () => void;
}

/** One card waiting to go on the path. */
export function HandCard({
  artwork,
  label,
  placed = false,
  held = false,
  onPress,
}: HandCardProps): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: placed, selected: held }}
      accessibilityHint={placed ? undefined : 'Pick it up and tap a spot'}
      disabled={placed}
      onPress={onPress}
      style={[
        styles.tile,
        {
          width: HAND_CARD.width,
          height: HAND_CARD.height,
          borderRadius: HAND_CARD.radius,
          backgroundColor: placed
            ? withAlpha(theme.palette.sand100, 0.7)
            : theme.color.surface,
          borderWidth: 2.6,
          borderStyle: placed ? 'dashed' : 'solid',
          borderColor: withAlpha(
            held ? theme.palette.hopGreenDeep : theme.palette.peachDeep,
            placed ? 0.42 : held ? 0.9 : 0.3,
          ),
          transform: held ? [{ translateY: -theme.spacing.s }] : [],
        },
      ]}
    >
      <HopArtwork
        artwork={artwork}
        fit="contain"
        decorative
        style={{ width: HAND_CARD.art, height: HAND_CARD.art, opacity: placed ? 0.3 : 1 }}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  tummy: { flexDirection: 'row', alignItems: 'center' },
  tummyFace: { alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  tummyBeads: { flexDirection: 'row' },
  tile: { alignItems: 'center', justifyContent: 'center' },
  faceDown: { alignItems: 'center', justifyContent: 'center', borderWidth: 3.4 },
  badge: {
    position: 'absolute',
    right: -8,
    top: -8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  check: { alignItems: 'center', justifyContent: 'center' },
});
