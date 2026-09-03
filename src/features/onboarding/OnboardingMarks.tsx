import React from 'react';
import { StyleSheet, View, type ViewStyle } from 'react-native';

import { useHopTheme } from '../../design-system/theme';

/**
 * The small marks the caregiver screens label their rows with.
 *
 * These are interface furniture, not illustration: an illustration comes from
 * `HopArtwork` by the key SwiftUI uses, and `artwork.generated.ts` has no key
 * for a play triangle or a padlock because the SwiftUI app draws those with SF
 * Symbols. So they are built from plain views and tokens — geometry only, no
 * hand-authored SVG path, nothing that could drift away from a drawing.
 *
 * Every one is decorative: the sentence beside it always carries the meaning.
 */

export interface MarkProps {
  size: number;
  color: string;
}

const hidden = {
  accessibilityElementsHidden: true,
  importantForAccessibility: 'no-hide-descendants',
} as const;

export function PlayMark({ size, color }: MarkProps): React.ReactElement {
  return (
    <View
      {...hidden}
      style={{
        width: 0,
        height: 0,
        borderTopWidth: size / 2,
        borderBottomWidth: size / 2,
        borderLeftWidth: size * 0.86,
        borderTopColor: 'transparent',
        borderBottomColor: 'transparent',
        borderLeftColor: color,
        marginLeft: size * 0.12,
      }}
    />
  );
}

export function PauseMark({ size, color }: MarkProps): React.ReactElement {
  const bar: ViewStyle = {
    width: size * 0.26,
    height: size,
    borderRadius: size * 0.13,
    backgroundColor: color,
  };
  return (
    <View {...hidden} style={[styles.row, { gap: size * 0.2 }]}>
      <View style={bar} />
      <View style={bar} />
    </View>
  );
}

/** The routine's mark: a ring around a filled centre. */
export function RingMark({ size, color }: MarkProps): React.ReactElement {
  return (
    <View
      {...hidden}
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: size * 0.1,
        borderColor: color,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <View
        style={{
          width: size * 0.34,
          height: size * 0.34,
          borderRadius: size * 0.17,
          backgroundColor: color,
        }}
      />
    </View>
  );
}

export function LockMark({ size, color }: MarkProps): React.ReactElement {
  return (
    <View {...hidden} style={{ width: size, alignItems: 'center' }}>
      <View
        style={{
          width: size * 0.56,
          height: size * 0.36,
          borderWidth: size * 0.12,
          borderBottomWidth: 0,
          borderColor: color,
          borderTopLeftRadius: size * 0.28,
          borderTopRightRadius: size * 0.28,
        }}
      />
      <View
        style={{
          width: size * 0.84,
          height: size * 0.56,
          borderRadius: size * 0.14,
          backgroundColor: color,
        }}
      />
    </View>
  );
}

/** Four rounded squares — "the apps you choose". */
export function AppsMark({ size, color }: MarkProps): React.ReactElement {
  const cell: ViewStyle = {
    width: size * 0.42,
    height: size * 0.42,
    borderRadius: size * 0.12,
    backgroundColor: color,
  };
  return (
    <View {...hidden} style={{ width: size, gap: size * 0.16 }}>
      <View style={[styles.row, { gap: size * 0.16 }]}>
        <View style={cell} />
        <View style={[cell, styles.faded]} />
      </View>
      <View style={[styles.row, { gap: size * 0.16 }]}>
        <View style={[cell, styles.faded]} />
        <View style={cell} />
      </View>
    </View>
  );
}

/** Two sliders — "you can turn this off anytime". */
export function SlidersMark({ size, color }: MarkProps): React.ReactElement {
  const track: ViewStyle = {
    height: size * 0.14,
    borderRadius: size * 0.07,
    backgroundColor: color,
    flex: 1,
  };
  const knob = (offset: number): ViewStyle => ({
    position: 'absolute',
    left: offset,
    top: -size * 0.09,
    width: size * 0.32,
    height: size * 0.32,
    borderRadius: size * 0.16,
    backgroundColor: color,
  });
  return (
    <View {...hidden} style={{ width: size, gap: size * 0.3 }}>
      <View style={styles.row}>
        <View style={track} />
        <View style={knob(size * 0.5)} />
      </View>
      <View style={styles.row}>
        <View style={track} />
        <View style={knob(size * 0.14)} />
      </View>
    </View>
  );
}

export function ClockMark({ size, color }: MarkProps): React.ReactElement {
  return (
    <View
      {...hidden}
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: size * 0.09,
        borderColor: color,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <View
        style={{
          position: 'absolute',
          width: size * 0.09,
          height: size * 0.3,
          borderRadius: size * 0.05,
          backgroundColor: color,
          top: size * 0.16,
        }}
      />
      <View
        style={{
          position: 'absolute',
          width: size * 0.24,
          height: size * 0.09,
          borderRadius: size * 0.05,
          backgroundColor: color,
          left: size * 0.38,
          top: size * 0.42,
        }}
      />
    </View>
  );
}

/** The tinted rounded square a mark sits in on a caregiver row. */
export function IconTile({
  size = 34,
  radius,
  background,
  children,
}: {
  size?: number;
  radius?: number;
  background: string;
  children: React.ReactNode;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: radius ?? theme.radius.s,
        backgroundColor: background,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
  faded: { opacity: 0.55 },
});
