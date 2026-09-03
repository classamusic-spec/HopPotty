import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { OnboardingScaffold, stepPosition, type OnboardingStepPosition } from './OnboardingScaffold';

/**
 * 02 — Meet Hop.
 *
 * The reference is `Art/render/screens/02-onboarding-meet-hop.png`, produced by
 * `meetHop()` in `Scripts/screens/onboarding.js`. Hop waves once on arrival and
 * then stands there: a mascot that keeps waving is a mascot asking to be looked
 * at, and this is a caregiver screen.
 */

/** The medallion the harness draws: a 300pt disc of pond behind the character. */
const MEDALLION = 300;
const HOP_SIZE = 276;

export interface MeetHopScreenProps {
  onGetStarted?: () => void;
  onSkip?: () => void;
  step?: OnboardingStepPosition;
}

export function MeetHopScreen({
  onGetStarted,
  onSkip,
  step = stepPosition('meetHop'),
}: MeetHopScreenProps): React.ReactElement {
  return (
    <OnboardingScaffold
      title="Meet Hop"
      titleAlign="center"
      message="Your child's new potty-time buddy."
      detail="HopPotty pauses the games your child is playing, invites them to the potty, and hands the game straight back."
      hero={<HopMedallion />}
      step={step}
      primaryLabel="Get Started"
      onPrimary={onGetStarted}
      skipLabel="Skip"
      onSkip={onSkip}
    />
  );
}

/** A circle of pond, cropped to a disc, with Hop standing in it. */
function HopMedallion(): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View style={styles.stage}>
      <View
        style={[
          styles.disc,
          {
            backgroundColor: theme.isDark ? theme.color.surfaceElevated : theme.palette.hopGreenSoft,
          },
        ]}
      >
        <View style={[styles.ring, { borderColor: theme.palette.hopGreenLight }]} />
        <View style={[styles.bankFar, { backgroundColor: theme.palette.hopGreenLight }]} />
        <View style={[styles.bankNear, { backgroundColor: theme.palette.hopGreen }]} />
        <View style={styles.character}>
          <HopCharacter
            size={HOP_SIZE}
            state="wave"
            accessibilityLabel="Hop waves hello"
          />
        </View>
      </View>

      {/* Specks. Scenery, so they carry no label of their own. */}
      <HopText
        variant="parentTitle"
        style={[styles.speckTopLeft, { color: theme.palette.sunshine }]}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      >
        ★
      </HopText>
      <HopText
        variant="parentCaption"
        style={[styles.speckRight, { color: theme.palette.sunshine }]}
        accessibilityElementsHidden
        importantForAccessibility="no-hide-descendants"
      >
        ★
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  stage: { width: MEDALLION, height: MEDALLION, justifyContent: 'center', alignItems: 'center' },
  disc: {
    width: MEDALLION,
    height: MEDALLION,
    borderRadius: MEDALLION / 2,
    overflow: 'hidden',
    justifyContent: 'flex-end',
  },
  ring: {
    position: 'absolute',
    left: (MEDALLION - 224) / 2,
    top: (MEDALLION - 224) / 2,
    width: 224,
    height: 224,
    borderRadius: 112,
    borderWidth: StyleSheet.hairlineWidth * 3,
    opacity: 0.5,
  },
  bankFar: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 72,
    borderTopLeftRadius: MEDALLION / 2,
    borderTopRightRadius: MEDALLION / 2,
    opacity: 0.7,
  },
  bankNear: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 44,
    borderTopLeftRadius: MEDALLION / 3,
    borderTopRightRadius: MEDALLION / 3,
    opacity: 0.55,
  },
  character: { position: 'absolute', left: (MEDALLION - HOP_SIZE) / 2, top: 12 },
  speckTopLeft: { position: 'absolute', left: 6, top: 52 },
  speckRight: { position: 'absolute', right: 14, top: 104 },
});
