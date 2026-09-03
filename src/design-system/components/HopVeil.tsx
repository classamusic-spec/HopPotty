import React from 'react';
import { View, type ViewStyle } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import { useHopTheme } from '../theme';

/**
 * The light that lets words sit on a drawing without a card under them.
 *
 * A card would solve the contrast problem and cost the whole idea: the moment
 * type gets a white box, the screen stops being a place and becomes a page. A
 * soft vertical wash of the page colour does the same job and leaves the scene
 * continuous underneath — the same treatment the design renders use.
 *
 * Drawn with react-native-svg rather than a gradient library because the app
 * already depends on it for all the art, and one fewer native dependency is one
 * fewer thing to break a brownfield pod install.
 */
export function HopVeil({
  from = 0,
  height = 300,
  strength = 0.82,
  style,
}: {
  from?: number;
  height?: number;
  strength?: number;
  style?: ViewStyle;
}): React.ReactElement {
  const theme = useHopTheme();
  const c = theme.color.backgroundPrimary;
  return (
    <View
      pointerEvents="none"
      style={[{ position: 'absolute', left: 0, right: 0, top: from, height }, style]}
    >
      <Svg width="100%" height="100%">
        <Defs>
          <LinearGradient id="hopVeil" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor={c} stopOpacity={0} />
            <Stop offset="0.42" stopColor={c} stopOpacity={strength * 0.5} />
            <Stop offset="1" stopColor={c} stopOpacity={strength} />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="100%" height="100%" fill="url(#hopVeil)" />
      </Svg>
    </View>
  );
}
