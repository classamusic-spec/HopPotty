import React from 'react';
import { Pressable, StyleSheet, View, type ViewStyle } from 'react-native';

import { useHopTheme } from '../theme';
import { HopText } from './HopText';

export interface HopButtonProps {
  label: string;
  onPress?: () => void;
  variant?: 'primary' | 'secondary' | 'quiet';
  /** Child surfaces get a much larger minimum target than parent ones. */
  audience?: 'parent' | 'child';
  disabled?: boolean;
  style?: ViewStyle;
}

export function HopButton({
  label,
  onPress,
  variant = 'primary',
  audience = 'parent',
  disabled = false,
  style,
}: HopButtonProps): React.ReactElement {
  const theme = useHopTheme();
  const minHeight =
    audience === 'child' ? theme.hitTarget.childPrimary : theme.hitTarget.parentMinimum;

  const background =
    variant === 'primary'
      ? theme.color.brandAction
      : variant === 'secondary'
        ? theme.color.surfaceElevated
        : 'transparent';

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.base,
        {
          minHeight,
          paddingHorizontal: theme.spacing.xl,
          borderRadius: theme.radius.xl,
          backgroundColor: background,
          opacity: disabled ? 0.4 : pressed ? 0.85 : 1,
        },
        style,
      ]}
    >
      <View pointerEvents="none">
        <HopText
          variant={audience === 'child' ? 'buttonLarge' : 'parentHeadline'}
          tone={variant === 'primary' ? 'onBrand' : 'brand'}
        >
          {label}
        </HopText>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: { alignItems: 'center', justifyContent: 'center' },
});
