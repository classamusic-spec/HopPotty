import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  OnboardingEyebrow,
  OnboardingScaffold,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 05 — the rhythm.
 *
 * There is no render for this step; it is drawn in the house style of
 * `Art/render/screens/32-onboarding-child-profile.png` — an eyebrow, a
 * question, a group of choices, and a quiet sentence under it.
 *
 * The disclaimer is not a grey footnote. A caregiver choosing "how often should
 * my child go" is exactly the person who might read a number here as advice, so
 * `HopFeatureStrings.intervalDisclaimer` gets a panel of its own and says
 * plainly that HopPotty is not a clinical tool.
 */

/** `PottyInterval.presets`, in order. */
export const INTERVAL_PRESETS: readonly number[] = [15, 20, 30, 45, 60, 90];

/** `PottyInterval.customRange`. The floor keeps HopPotty from being a nuisance. */
export const INTERVAL_MIN = 10;
export const INTERVAL_MAX = 240;
const INTERVAL_STEP = 5;

export interface IntervalScreenProps {
  intervalMinutes: number;
  onChangeInterval?: (minutes: number) => void;
  onContinue?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

function clamp(minutes: number): number {
  return Math.min(Math.max(minutes, INTERVAL_MIN), INTERVAL_MAX);
}

function minutesLabel(minutes: number): string {
  return minutes === 1 ? '1 minute' : `${minutes} minutes`;
}

export function IntervalScreen({
  intervalMinutes,
  onChangeInterval,
  onContinue,
  onBack,
  step = stepPosition('interval'),
}: IntervalScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const isCustom = !INTERVAL_PRESETS.includes(intervalMinutes);

  const choose = (minutes: number) => onChangeInterval?.(clamp(minutes));

  return (
    <OnboardingScaffold
      eyebrow="Rhythm"
      title="How often is a good rhythm?"
      message="Many families start near 45 minutes and adjust after a few days. You can change it any time."
      step={step}
      primaryLabel="Next"
      onPrimary={onContinue}
      onBack={onBack}
    >
      <OnboardingEyebrow text="Every" tone="secondary" />
      <View style={[styles.chips, { marginTop: theme.spacing.m, gap: theme.spacing.s }]}>
        {INTERVAL_PRESETS.map((minutes) => (
          <Chip
            key={minutes}
            label={String(minutes)}
            accessibilityLabel={minutesLabel(minutes)}
            selected={!isCustom && minutes === intervalMinutes}
            onPress={() => choose(minutes)}
          />
        ))}
        <Chip
          label="Custom"
          accessibilityLabel="Custom interval"
          selected={isCustom}
          // Seeded from whatever preset was showing, so the stepper never
          // starts from a number the caregiver did not choose.
          onPress={() => choose(intervalMinutes + INTERVAL_STEP)}
        />
      </View>

      {isCustom ? (
        <View style={{ marginTop: theme.spacing.l }}>
          <View
            style={[
              styles.stepper,
              {
                backgroundColor: theme.color.surfaceSunken,
                borderRadius: theme.radius.m,
                paddingHorizontal: theme.spacing.l,
                paddingVertical: theme.spacing.m,
                gap: theme.spacing.l,
              },
            ]}
          >
            <HopText variant="parentHeadline" style={styles.flex}>
              {minutesLabel(intervalMinutes)}
            </HopText>
            <StepperButton
              label="−"
              accessibilityLabel="Five minutes less"
              disabled={intervalMinutes <= INTERVAL_MIN}
              onPress={() => choose(intervalMinutes - INTERVAL_STEP)}
            />
            <StepperButton
              label="+"
              accessibilityLabel="Five minutes more"
              disabled={intervalMinutes >= INTERVAL_MAX}
              onPress={() => choose(intervalMinutes + INTERVAL_STEP)}
            />
          </View>
          <HopText
            variant="parentFootnote"
            tone="secondary"
            style={{ marginTop: theme.spacing.s, paddingHorizontal: theme.spacing.xs }}
          >
            {`Anything from ${INTERVAL_MIN} to ${INTERVAL_MAX} minutes.`}
          </HopText>
        </View>
      ) : (
        <HopText variant="parentHeadline" style={{ marginTop: theme.spacing.l }}>
          {minutesLabel(intervalMinutes)}
        </HopText>
      )}

      <View
        style={{
          marginTop: theme.spacing.xl,
          backgroundColor: theme.color.surfaceSunken,
          borderRadius: theme.radius.m,
          padding: theme.spacing.l,
        }}
      >
        <HopText variant="parentCallout" tone="secondary">
          You can change this anytime. HopPotty doesn&apos;t provide medical timing
          recommendations.
        </HopText>
      </View>
    </OnboardingScaffold>
  );
}

function Chip({
  label,
  accessibilityLabel,
  selected,
  onPress,
}: {
  label: string;
  accessibilityLabel: string;
  selected: boolean;
  onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={accessibilityLabel}
      onPress={onPress}
      style={({ pressed }) => [
        styles.chip,
        {
          minHeight: theme.hitTarget.parentMinimum,
          paddingHorizontal: theme.spacing.l,
          borderRadius: theme.radius.l,
          backgroundColor: selected ? theme.color.brandAction : theme.color.surface,
          borderColor: selected ? theme.color.brandAction : theme.color.divider,
          opacity: pressed ? 0.75 : 1,
        },
      ]}
    >
      <HopText variant="parentHeadline" tone={selected ? 'onBrand' : 'primary'}>
        {label}
      </HopText>
    </Pressable>
  );
}

function StepperButton({
  label,
  accessibilityLabel,
  disabled,
  onPress,
}: {
  label: string;
  accessibilityLabel: string;
  disabled: boolean;
  onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.stepperButton,
        {
          width: theme.hitTarget.parentMinimum,
          height: theme.hitTarget.parentMinimum,
          borderRadius: theme.radius.s,
          backgroundColor: theme.color.surface,
          opacity: disabled ? 0.4 : pressed ? 0.75 : 1,
        },
      ]}
    >
      <HopText variant="parentMetric" tone="brand">
        {label}
      </HopText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  chips: { flexDirection: 'row', flexWrap: 'wrap' },
  chip: { alignItems: 'center', justifyContent: 'center', borderWidth: 1 },
  stepper: { flexDirection: 'row', alignItems: 'center' },
  stepperButton: { alignItems: 'center', justifyContent: 'center' },
});
