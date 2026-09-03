import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { IconTile, PlayMark } from './OnboardingMarks';
import {
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 11 — the test pause.
 *
 * No render exists for this step, but render 33 draws the same card at the end
 * of setup, and this screen uses it: the mark, the title, the sentence, and a
 * button that runs one real pause.
 *
 * Reached only when a pause can actually work — the flow routes past it when
 * nothing is selected, because showing a caregiver a failure they caused by
 * skipping the picker teaches them the feature is broken.
 */

export interface TestPauseScreenProps {
  /** `null` before the caregiver has tried. */
  didSucceed: boolean | null;
  isWorking?: boolean;
  onRunTestPause?: () => void;
  onContinue?: () => void;
  onSkip?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function TestPauseScreen({
  didSucceed,
  isWorking = false,
  onRunTestPause,
  onContinue,
  onSkip,
  onBack,
  step = stepPosition('testPause'),
}: TestPauseScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <OnboardingScaffold
      eyebrow="Test"
      title="Try a Potty Pause"
      message="This runs one pause right now so you can see exactly what your child sees. It ends on its own."
      step={step}
      primaryLabel={didSucceed === true ? 'Next' : 'Run a test pause'}
      primaryEnabled={!isWorking}
      onPrimary={didSucceed === true ? onContinue : onRunTestPause}
      skipLabel="Skip the test"
      onSkip={onSkip}
      onBack={onBack}
    >
      <View
        style={[
          styles.card,
          restingShadow(theme),
          {
            backgroundColor: theme.color.surface,
            borderRadius: theme.radius.l,
            padding: theme.spacing.l,
            gap: theme.spacing.m,
          },
        ]}
      >
        <IconTile
          size={32}
          radius={theme.radius.s}
          background={theme.isDark ? theme.color.surfaceSunken : theme.palette.pondBlueSoft}
        >
          <PlayMark size={15} color={theme.color.eventPee} />
        </IconTile>
        <HopText variant="parentCaption" tone="secondary" style={styles.flex}>
          The pause ends on its own timer. Screen access is never held back for a result.
        </HopText>
      </View>

      {didSucceed === true ? (
        <View style={[styles.row, { marginTop: theme.spacing.l, gap: theme.spacing.s }]}>
          <HopText variant="parentHeadline" style={{ color: theme.color.success }}>
            ✓
          </HopText>
          <HopText variant="parentCallout" tone="secondary" style={styles.flex}>
            That worked. The apps you picked paused and came straight back.
          </HopText>
        </View>
      ) : null}

      {didSucceed === false ? (
        <View
          style={{
            marginTop: theme.spacing.l,
            backgroundColor: theme.color.surfaceSunken,
            borderRadius: theme.radius.m,
            padding: theme.spacing.l,
          }}
        >
          <HopText variant="parentHeadline">That pause did not start</HopText>
          <HopText variant="parentCallout" tone="secondary" style={{ marginTop: theme.spacing.xs }}>
            Your child was not interrupted. The next pause will try again.
          </HopText>
        </View>
      ) : null}

      {isWorking ? (
        <HopText variant="parentCallout" tone="secondary" style={{ marginTop: theme.spacing.l }}>
          Running one pause…
        </HopText>
      ) : null}
    </OnboardingScaffold>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  card: { flexDirection: 'row', alignItems: 'flex-start' },
  row: { flexDirection: 'row', alignItems: 'flex-start' },
});
