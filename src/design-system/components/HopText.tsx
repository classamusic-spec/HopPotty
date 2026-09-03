import React from 'react';
import { Text, type TextProps, type TextStyle } from 'react-native';

import { textStyle, useHopTheme } from '../theme';
import type { HopTypeStyleName } from '../tokens.generated';

export interface HopTextProps extends TextProps {
  /** A named style from the design tokens. There is no unnamed size. */
  variant?: HopTypeStyleName;
  /** A semantic colour name; defaults to primary text for the appearance. */
  tone?: 'primary' | 'secondary' | 'tertiary' | 'onBrand' | 'brand';
  children?: React.ReactNode;
}

/**
 * Every piece of text in the app.
 *
 * `Text` is never used directly in a feature: doing so is how a screen ends up
 * with a hard-coded 17pt that ignores both the type scale and Dynamic Type.
 */
export function HopText({
  variant = 'parentBody',
  tone = 'primary',
  style,
  ...rest
}: HopTextProps): React.ReactElement {
  const theme = useHopTheme();
  const color =
    tone === 'secondary'
      ? theme.color.textSecondary
      : tone === 'tertiary'
        ? theme.color.textTertiary
        : tone === 'onBrand'
          ? theme.color.textOnBrand
          : tone === 'brand'
            ? theme.color.brandAction
            : theme.color.textPrimary;

  return (
    <Text
      // Dynamic Type is on by default; styles that opt out say so in the tokens.
      allowFontScaling={theme.type[variant].scales}
      style={[textStyle(variant) as TextStyle, { color }, style]}
      {...rest}
    />
  );
}
