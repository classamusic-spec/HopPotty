import React from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';

import { HopButton, HopText, HopVeil } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { MeadowScene } from './MeadowScene';

/**
 * The Potty Pause, in the app's own voice.
 *
 * The reference is `Art/render/screens/07-routine-step1.png`.
 * `06-potty-pause-shield.png` is the *system* shield — nine properties, iOS's
 * own layout, none of it ours — and this is the screen a child lands on the
 * instant they tap "Let's Go" on it. It says the same four things, because they
 * are the same moment; saying them here in HopPotty's own type, at HopPotty's
 * own size, in a world instead of a system sheet, is the whole point.
 *
 * Hop is heading up the path to the bathroom door, and the door is drawn,
 * because "let's hop to the potty" said to a two-year-old without a picture of
 * where is only words.
 *
 * ## What is not on it
 *
 * Everything. No step indicator, no strip of what is coming, no star count, no
 * timer, no settings and no game list — one drawing, two sentences, a promise
 * and two buttons. An interruption that decorates itself stops being brief.
 *
 * The secondary is the shield's own "Need a grown-up?" and does the same thing:
 * it raises the parent gate. It is the way out this screen carries, and it is
 * not styled as an escape hatch.
 */
export interface RoutinePauseScreenProps {
  /** The child's nickname, or null when none is set. */
  readonly childName?: string | null;
  /** Starts the routine. The child's own word for it is "Let's Go". */
  readonly onGo: () => void;
  /** Hands the device to an adult, through the gate. Never a dead end. */
  readonly onAskForGrownUp: () => void;
}

export function RoutinePauseScreen({
  childName,
  onGo,
  onAskForGrownUp,
}: RoutinePauseScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const isWide = width >= 768;

  const title = childName ? `Potty time, ${childName}!` : 'Potty time!';
  const hopSide = isWide ? 360 : 290;

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <MeadowScene width={width} height={height} horizon={0.49} propsOffset={218} showsDoor />
      <HopVeil from={height * 0.66} height={height * 0.34} strength={0.62} />

      <View
        style={[
          styles.content,
          {
            paddingHorizontal: theme.spacing.xxl,
            paddingBottom: theme.spacing.s,
            maxWidth: isWide ? 560 : undefined,
            alignSelf: isWide ? 'center' : 'stretch',
            width: isWide ? '100%' : undefined,
          },
        ]}
      >
        <View style={styles.headroom} />

        <View style={styles.mascot} pointerEvents="none">
          <HopCharacter size={hopSide} state="walk" accessibilityLabel="Hop walks up to the bathroom door" />
        </View>

        <View style={{ height: theme.spacing.l }} />

        <View pointerEvents="none">
          <HopText variant="childTitle" style={styles.centred} accessibilityRole="header">
            {title}
          </HopText>
          <HopText
            variant="childInstruction"
            tone="secondary"
            style={[styles.centred, { marginTop: theme.spacing.s }]}
          >
            Let&apos;s hop to the potty. Your game will be here when you get back.
          </HopText>
        </View>

        <View style={styles.spacer} />

        <View style={{ gap: theme.spacing.m }}>
          <HopButton
            label="Let's Go!"
            audience="child"
            onPress={onGo}
            style={{ minHeight: 104, borderRadius: theme.radius.hero }}
          />
          <HopButton
            label="Need a grown-up?"
            audience="child"
            variant="secondary"
            onPress={onAskForGrownUp}
            style={{ minHeight: theme.hitTarget.childMinimum, borderRadius: theme.radius.hero }}
          />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, overflow: 'hidden' },
  content: { flex: 1 },
  headroom: { height: 88 },
  mascot: { alignItems: 'center' },
  centred: { textAlign: 'center' },
  spacer: { flex: 1 },
});
