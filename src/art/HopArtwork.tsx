import React from 'react';
import { View, type ViewStyle } from 'react-native';
import Svg from 'react-native-svg';

import { HOP_ARTWORK, type HopIllustrationKey } from './artwork.generated';
import { renderSceneNode } from './SvgScene';

/**
 * An illustration, by the same key the SwiftUI app uses.
 *
 * `HopArtwork("scene.games.mudOff")` here and `HopArtwork("scene.games.mudOff")`
 * in Swift resolve to the same file in `Art/`, so the two apps draw the same
 * picture. A key with no drawing is a build failure in `build-art.js`, not a
 * placeholder at runtime — the SwiftUI app spent a while silently rendering
 * coloured blobs for exactly that reason, and the generator exists so React
 * Native cannot repeat it.
 */
export interface HopArtworkProps {
  artwork: HopIllustrationKey;
  width?: number;
  height?: number;
  style?: ViewStyle;
  /** How the drawing fits its box. Scenes usually want to cover. */
  fit?: 'contain' | 'cover';
  accessibilityLabel?: string;
  /** Hidden from assistive tech where the art is scenery, not content. */
  decorative?: boolean;
}

export function HopArtwork({
  artwork,
  width,
  height,
  style,
  fit = 'contain',
  accessibilityLabel,
  decorative = false,
}: HopArtworkProps): React.ReactElement | null {
  const asset = HOP_ARTWORK[artwork];
  if (!asset) {
    if (__DEV__) console.warn(`HopArtwork: no drawing for "${artwork}"`);
    return null;
  }

  return (
    <View
      style={style}
      accessible={!decorative}
      accessibilityRole={decorative ? undefined : 'image'}
      accessibilityLabel={decorative ? undefined : accessibilityLabel}
      importantForAccessibility={decorative ? 'no-hide-descendants' : 'yes'}
    >
      <Svg
        width={width ?? '100%'}
        height={height ?? '100%'}
        viewBox={asset.viewBox}
        preserveAspectRatio={fit === 'cover' ? 'xMidYMid slice' : 'xMidYMid meet'}
      >
        {renderSceneNode(asset.tree, artwork)}
      </Svg>
    </View>
  );
}

export type { HopIllustrationKey };
export default HopArtwork;
