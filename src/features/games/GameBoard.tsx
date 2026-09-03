import React from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { useHopTheme } from '../../design-system/theme';
import type { SceneFrame } from './sceneFrame';

/**
 * The picture a board is played on.
 *
 * The scene is drawn at its own 4:3 (or taller, when the board *is* the
 * picture) with its top and bottom melted away into the page, so the screen has
 * no frame anywhere on it — the harness's `worldBand`, which is the single
 * change that made these screens read as a place rather than as an app. A card
 * around the picture would put a rounded white rectangle between the child and
 * the world they are supposed to be inside.
 *
 * `GameHost` also takes a `scene`, which paints one full-bleed behind the whole
 * screen. The boards do not use it: `cover` on a 4:3 drawing at phone
 * proportions keeps only the middle third of the picture, which crops away the
 * toilet in Flush and Wave and every other feature a board's sprites sit on.
 * The renders show a band, so the band is what the board draws.
 */
export interface GameBoardProps {
  scene: HopIllustrationKey;
  frame: SceneFrame;
  /** Sprites, positioned in the frame's scene coordinates. */
  children?: React.ReactNode;
}

/** How much of the band each soft edge takes, from `worldBand`'s own mask. */
const FADE = 0.17;

export function GameBoard({ scene, frame, children }: GameBoardProps): React.ReactElement {
  return (
    <View
      style={[styles.band, { width: frame.width, height: frame.height }]}
      pointerEvents="box-none"
    >
      <HopArtwork artwork={scene} fit="cover" decorative style={StyleSheet.absoluteFill} />
      {children}
      <BandEdge edge="top" height={frame.height * FADE} />
      <BandEdge edge="bottom" height={frame.height * FADE} />
    </View>
  );
}

/**
 * One soft end of the band.
 *
 * A wash of the page colour rather than an alpha mask, because the page behind
 * the band *is* the page colour — the two are indistinguishable, and this way
 * the sprites melt away with the picture instead of being sliced off on a hard
 * horizontal line.
 */
function BandEdge({
  edge,
  height,
}: {
  edge: 'top' | 'bottom';
  height: number;
}): React.ReactElement {
  const theme = useHopTheme();
  const c = theme.color.backgroundPrimary;
  const id = `hopBandFade-${edge}`;
  return (
    <View
      pointerEvents="none"
      style={[styles.edge, edge === 'top' ? { top: 0 } : { bottom: 0 }, { height }]}
    >
      <Svg width="100%" height="100%">
        <Defs>
          <LinearGradient id={id} x1="0" y1={edge === 'top' ? '0' : '1'} x2="0" y2={edge === 'top' ? '1' : '0'}>
            <Stop offset="0" stopColor={c} stopOpacity={1} />
            <Stop offset="1" stopColor={c} stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="100%" height="100%" fill={`url(#${id})`} />
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  band: { overflow: 'hidden', alignSelf: 'center' },
  edge: { position: 'absolute', left: 0, right: 0 },
});
