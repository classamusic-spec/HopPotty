import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View, useWindowDimensions } from 'react-native';

import { HopText } from '../../design-system/components';
import { durationMs, useHopTheme } from '../../design-system/theme';
import { HopArtwork } from '../../art/HopArtwork';
import { HopCharacter } from '../../mascot/HopCharacter';

/**
 * 00 — the launch screen.
 *
 * The reference is `Art/render/screens/00-splash.png`, produced by `splash()`
 * in `Scripts/screens/splash.js`. The ground is `backgroundPrimary`, which is
 * the colour iOS has already painted from `LaunchBackground`, so the handover
 * from the system's flat fill to this view has nothing to show.
 *
 * ## What this port could not reproduce
 *
 * The harness draws two files that React Native has no key for:
 * `Art/pond/pond-scene.svg` and the four-layer brand lockup in
 * `Art/brand/layers/`. Neither is in `Scripts/art-keys.sh`, so neither reaches
 * `artwork.generated.ts` — and inventing a drawing here is exactly what the
 * generator exists to prevent. So the pond is composed from the pond props that
 * *are* keyed (`pond.cloudPuff`, `pond.reedsLeft`, `pond.lilyPadLarge`, …) over
 * token-coloured bands, and the wordmark is set in the display type rather than
 * being the artwork's own lettering. Adding those two keys to the art pipeline
 * would let this screen draw the real lockup unchanged.
 *
 * The motion is deliberately small and never loops: `Docs/ChildSafety.md` rules
 * out a pulsing shine, so the whole stage arrives once and then holds still.
 */

/** `HopSplashChoreography`: the lockup is 74% of the width, capped at 360pt. */
const LOGO_WIDTH_FRACTION = 0.74;
const LOGO_MAX_WIDTH = 360;

export interface SplashScreenProps {
  /** Called once the lockup has settled, so the host can move on. */
  onFinished?: () => void;
  /** False holds the finished mark still, for Reduce Motion and for tests. */
  animated?: boolean;
}

export function SplashScreen({
  onFinished,
  animated = true,
}: SplashScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const logoWidth = Math.min(width * LOGO_WIDTH_FRACTION, LOGO_MAX_WIDTH);

  const entrance = useRef(new Animated.Value(animated ? 0 : 1)).current;

  useEffect(() => {
    if (!animated) {
      onFinished?.();
      return;
    }
    const animation = Animated.timing(entrance, {
      toValue: 1,
      duration: durationMs('childArrive'),
      useNativeDriver: true,
    });
    animation.start(({ finished }) => {
      if (finished) onFinished?.();
    });
    return () => animation.stop();
  }, [animated, entrance, onFinished]);

  const waterTop = Math.round(height * 0.58);
  const bankTop = Math.round(height * 0.5);

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      {/* The pond, in bands. Sky, far bank, water, near bank. */}
      <View style={[StyleSheet.absoluteFill, { backgroundColor: theme.palette.pondBlueSoft }]} />
      <View
        style={[
          styles.bank,
          {
            top: bankTop,
            height: height - bankTop,
            backgroundColor: theme.palette.hopGreenLight,
          },
        ]}
      />
      <View
        style={[
          styles.water,
          {
            top: waterTop,
            height: height - waterTop - 40,
            backgroundColor: theme.palette.pondBlue,
            borderTopLeftRadius: width,
            borderTopRightRadius: width,
          },
        ]}
      />
      <View style={[styles.shore, { backgroundColor: theme.palette.hopGreen }]} />

      {/* Pond props — the app's own drawings, by the keys SwiftUI uses. */}
      <HopArtwork artwork="pond.cloudPuff" decorative style={{ ...styles.cloudLeft, top: height * 0.07 }} />
      <HopArtwork artwork="pond.cloudPuff" decorative style={{ ...styles.cloudRight, top: height * 0.16 }} />
      <HopArtwork artwork="pond.reedsLeft" decorative style={{ ...styles.reedsLeft, top: waterTop - 90 }} />
      <HopArtwork artwork="pond.reedsRight" decorative style={{ ...styles.reedsRight, top: waterTop - 90 }} />
      <HopArtwork artwork="pond.cattails" decorative style={{ ...styles.cattails, top: waterTop - 70 }} />
      <HopArtwork artwork="pond.lilyPadLarge" decorative style={{ ...styles.lilyLarge, top: waterTop + 70 }} />
      <HopArtwork artwork="pond.lilyPadSmall" decorative style={{ ...styles.lilySmall, top: waterTop + 190 }} />
      <HopArtwork artwork="pond.dragonfly" decorative style={{ ...styles.dragonfly, top: waterTop - 30 }} />

      <Animated.View
        style={[
          styles.centre,
          {
            opacity: entrance,
            transform: [
              { translateY: entrance.interpolate({ inputRange: [0, 1], outputRange: [16, 0] }) },
            ],
          },
        ]}
      >
        <View
          accessible
          accessibilityRole="image"
          accessibilityLabel="HopPotty — Pause. Potty. Play."
          style={{ width: logoWidth, alignItems: 'center' }}
        >
          {/* The light behind the mark. It never pulses. */}
          <HopArtwork
            artwork="pond.sunbeam"
            decorative
            style={{
              ...styles.shine,
              width: logoWidth * 1.46,
              height: logoWidth * 1.46,
              marginLeft: -(logoWidth * 1.46) / 2,
              marginTop: -(logoWidth * 1.46) / 2,
            }}
          />

          {/* The frog sits *under* the two words, so he pops up from behind
              them rather than across them — `logo-metrics.json`'s paintOrder. */}
          <HopCharacter size={logoWidth * 0.56} state="happy" decorative animated={false} />

          <View style={styles.wordmark}>
            <Wordmark part="Hop" color={theme.palette.hopGreen} />
            <Wordmark part="Potty" color={theme.palette.pondBlue} />
          </View>

          <View
            style={[
              styles.tagline,
              {
                marginTop: theme.spacing.s,
                paddingHorizontal: theme.spacing.l,
                paddingVertical: theme.spacing.s,
                borderRadius: theme.radius.l,
                backgroundColor: theme.palette.sunshine,
                gap: theme.spacing.s,
              },
            ]}
          >
            <HopText variant="parentTitle" style={{ color: theme.palette.hopGreenDeep }}>
              Pause.
            </HopText>
            <HopText variant="parentTitle" style={{ color: theme.palette.pondBlueDeep }}>
              Potty.
            </HopText>
            <HopText variant="parentTitle" style={{ color: theme.palette.peachDeep }}>
              Play.
            </HopText>
          </View>
        </View>
      </Animated.View>
    </View>
  );
}

/**
 * One word of the lockup.
 *
 * The artwork's letters carry a white sticker outline, which is what keeps the
 * mark legible over water rather than over cream. A halo is the nearest thing
 * type has to it, and it uses the surface colour rather than a literal white.
 */
function Wordmark({ part, color }: { part: string; color: string }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <HopText
      variant="hero"
      style={{
        color,
        textShadowColor: theme.color.surface,
        textShadowOffset: { width: 0, height: 0 },
        textShadowRadius: 6,
      }}
    >
      {part}
    </HopText>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  bank: { position: 'absolute', left: 0, right: 0 },
  water: { position: 'absolute', left: -20, right: -20 },
  shore: { position: 'absolute', left: 0, right: 0, bottom: 0, height: 40 },
  cloudLeft: { position: 'absolute', left: -30, width: 220, height: 220 },
  cloudRight: { position: 'absolute', right: -40, width: 180, height: 180 },
  reedsLeft: { position: 'absolute', left: -14, width: 120, height: 120 },
  reedsRight: { position: 'absolute', right: -14, width: 120, height: 120 },
  cattails: { position: 'absolute', right: 46, width: 92, height: 92 },
  lilyLarge: { position: 'absolute', left: 18, width: 130, height: 130 },
  lilySmall: { position: 'absolute', right: 26, width: 110, height: 110 },
  dragonfly: { position: 'absolute', right: 24, width: 76, height: 76 },
  centre: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    alignItems: 'center',
    justifyContent: 'center',
  },
  // Explicitly behind the mark. On iOS subview order alone would put it there,
  // but a positioned view paints *over* its in-flow siblings on the web, which
  // buried Hop under the glow in the browser preview. Saying the depth out loud
  // is the same drawing on both, and is what the artwork is: light behind him.
  shine: { position: 'absolute', left: '50%', top: '50%', zIndex: -1 },
  wordmark: { flexDirection: 'row', marginTop: -26 },
  tagline: { flexDirection: 'row', alignItems: 'center' },
});
