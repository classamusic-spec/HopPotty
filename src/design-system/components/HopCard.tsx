import React from 'react';
import { View, type ViewProps } from 'react-native';

import { useHopTheme } from '../theme';

/** A surface. Radius, colour and elevation come from the tokens, never inline. */
export function HopCard({ style, ...rest }: ViewProps): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      style={[
        {
          backgroundColor: theme.color.surface,
          borderRadius: theme.radius.xl,
          padding: theme.spacing.l,
        },
        style,
      ]}
      {...rest}
    />
  );
}
