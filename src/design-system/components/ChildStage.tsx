import React from 'react';
import { StyleSheet, View, type ViewStyle } from 'react-native';

import { HopArtwork, type HopIllustrationKey } from '../../art/HopArtwork';
import { useHopTheme } from '../theme';
import { HopVeil } from './HopVeil';

/**
 * A child screen: one drawing, edge to edge, with the interface over it.
 *
 * Child Mode is a place rather than a page, so the scene bleeds to every edge
 * and the controls float on a soft wash of the page colour instead of sitting
 * in cards. The design renders establish this and every child screen follows
 * it — which is why this is one component rather than a pattern each screen
 * re-implements slightly differently.
 */
export function ChildStage({
  scene,
  children,
  veilFrom = 420,
  veilHeight = 432,
  veilStrength = 0.82,
  sceneStyle,
}: {
  scene?: HopIllustrationKey;
  children?: React.ReactNode;
  veilFrom?: number;
  veilHeight?: number;
  veilStrength?: number;
  sceneStyle?: ViewStyle;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      {scene ? (
        <View style={[StyleSheet.absoluteFill, sceneStyle]}>
          <HopArtwork artwork={scene} fit="cover" decorative style={StyleSheet.absoluteFill} />
        </View>
      ) : null}
      <HopVeil from={veilFrom} height={veilHeight} strength={veilStrength} />
      <View style={styles.content}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
});
