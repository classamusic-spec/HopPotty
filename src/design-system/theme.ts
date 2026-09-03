import { Platform, useColorScheme } from 'react-native';

import {
  appearances,
  hitTarget,
  motion,
  palette,
  radius,
  spacing,
  typography,
  type HopAppearance,
  type HopMotionName,
  type HopSemanticColors,
  type HopTypeStyleName,
} from './tokens.generated';

/**
 * The theme, assembled from the generated tokens.
 *
 * Nothing here invents a value. Every colour, size and curve comes from
 * `tokens.generated.ts`, which comes from the Swift design tokens — so this
 * file decides only *which* appearance is showing, never what it contains.
 * A screen that wants a colour the tokens do not have is a request for a new
 * token, not for a literal.
 */
export interface HopTheme {
  readonly appearance: HopAppearance;
  readonly isDark: boolean;
  readonly color: HopSemanticColors;
  readonly palette: typeof palette;
  readonly spacing: typeof spacing;
  readonly radius: typeof radius;
  readonly hitTarget: typeof hitTarget;
  readonly type: typeof typography;
  readonly motion: typeof motion;
}

export function makeTheme(appearance: HopAppearance): HopTheme {
  return {
    appearance,
    isDark: appearance === 'dark' || appearance === 'darkHighContrast',
    color: appearances[appearance],
    palette,
    spacing,
    radius,
    hitTarget,
    type: typography,
    motion,
  };
}

/**
 * The appearance for the current device settings.
 *
 * High-contrast variants exist in the tokens and are selected by the platform
 * accessibility setting where React Native exposes it; until then a caller may
 * pass one explicitly. Defaulting to light rather than to the device value
 * would be the wrong kind of safe — it would ignore a setting the user made.
 */
export function useHopTheme(override?: HopAppearance): HopTheme {
  const scheme = useColorScheme();
  const appearance: HopAppearance = override ?? (scheme === 'dark' ? 'dark' : 'light');
  return makeTheme(appearance);
}

/** A type style as React Native text props. */
export function textStyle(name: HopTypeStyleName) {
  const style = typography[name];
  return {
    fontSize: style.size,
    lineHeight: Math.round(style.size * style.lineHeight),
    letterSpacing: style.tracking,
    fontWeight: fontWeightFor(style.weight),
    // The parent surfaces use the system face and the child surfaces the
    // rounded one. Apple's fonts are not redistributable, so this names the
    // platform family rather than shipping a binary.
    fontFamily: style.family === 'rounded' ? roundedFamily() : undefined,
  } as const;
}

function roundedFamily(): string | undefined {
  // `SF Pro Rounded` is present on iOS and is what the SwiftUI app asks for.
  // Android and web fall back to the platform default rather than to a
  // downloaded lookalike, which would change the product's voice.
  return Platform.OS === 'ios' ? 'SF Pro Rounded' : undefined;
}

function fontWeightFor(weight: string) {
  switch (weight) {
    case 'bold':
      return '700' as const;
    case 'semibold':
      return '600' as const;
    case 'medium':
      return '500' as const;
    case 'heavy':
      return '800' as const;
    default:
      return '400' as const;
  }
}

/** Motion as a duration in milliseconds, for animation calls. */
export function durationMs(name: HopMotionName): number {
  return Math.round(motion[name].duration * 1000);
}
