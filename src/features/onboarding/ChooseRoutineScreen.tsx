import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  OnboardingEyebrow,
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 04 — how assertively HopPotty interrupts.
 *
 * The three modes are presented as equals. Gentle is not "the lesser option"
 * and is not styled as one: a family that only ever wants a reminder is using
 * HopPotty correctly, and it is also the only mode that needs no permission at
 * all — which is why the next three screens disappear when it is chosen.
 *
 * The band group is the one in `Art/render/screens/32-onboarding-child-profile.png`:
 * one surface, inset dividers, a check on the selected row. The rows carry
 * `PottyPauseMode`'s own copy from `HopCopy.onboarding`.
 */

export type PottyPauseModeId = 'gentle' | 'pause' | 'routine';

export const POTTY_PAUSE_MODES: readonly PottyPauseModeId[] = ['gentle', 'pause', 'routine'];

const MODE_COPY: Readonly<Record<PottyPauseModeId, { title: string; detail: string }>> = {
  gentle: {
    title: 'Gentle',
    detail: 'A reminder appears. Nothing is ever blocked.',
  },
  pause: {
    title: 'Potty Pause',
    detail:
      'The apps you pick go quiet and a friendly screen invites your child to the potty. The pause ends on its own timer.',
  },
  routine: {
    title: 'Guided routine',
    detail:
      'Hop walks your child through trying, wiping, flushing and washing, then hands the game back.',
  },
};

export interface ChooseRoutineScreenProps {
  mode: PottyPauseModeId;
  onChangeMode?: (mode: PottyPauseModeId) => void;
  onContinue?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function ChooseRoutineScreen({
  mode,
  onChangeMode,
  onContinue,
  onBack,
  step = stepPosition('chooseRoutine'),
}: ChooseRoutineScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <OnboardingScaffold
      eyebrow="Your routine"
      title="How would you like HopPotty to interrupt?"
      step={step}
      primaryLabel="Next"
      onPrimary={onContinue}
      onBack={onBack}
    >
      <OnboardingEyebrow text="Choose one" tone="secondary" />
      <View
        style={[
          styles.group,
          restingShadow(theme),
          {
            marginTop: theme.spacing.m,
            backgroundColor: theme.color.surface,
            borderRadius: theme.radius.l,
          },
        ]}
      >
        {POTTY_PAUSE_MODES.map((id, index) => (
          <ModeBand
            key={id}
            title={MODE_COPY[id].title}
            detail={MODE_COPY[id].detail}
            selected={id === mode}
            last={index === POTTY_PAUSE_MODES.length - 1}
            onPress={() => onChangeMode?.(id)}
          />
        ))}
      </View>

      <HopText
        variant="parentCaption"
        tone="secondary"
        style={{ marginTop: theme.spacing.s, paddingHorizontal: theme.spacing.xs }}
      >
        You can change this any time in Settings.
      </HopText>
    </OnboardingScaffold>
  );
}

function ModeBand({
  title,
  detail,
  selected,
  last,
  onPress,
}: {
  title: string;
  detail: string;
  selected: boolean;
  last: boolean;
  onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={`${title}. ${detail}`}
      onPress={onPress}
      style={({ pressed }) => [
        styles.band,
        {
          minHeight: theme.hitTarget.parentMinimum + theme.spacing.m,
          paddingVertical: theme.spacing.m,
          paddingHorizontal: theme.spacing.l,
          gap: theme.spacing.m,
          borderBottomWidth: last ? 0 : StyleSheet.hairlineWidth,
          borderBottomColor: theme.color.divider,
          opacity: pressed ? 0.7 : 1,
        },
      ]}
    >
      <View style={styles.flex}>
        <HopText variant={selected ? 'parentHeadline' : 'parentBody'}>{title}</HopText>
        <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xxs }}>
          {detail}
        </HopText>
      </View>
      {selected ? (
        <HopText
          variant="parentHeadline"
          tone="brand"
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          ✓
        </HopText>
      ) : (
        <View
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
          style={[styles.emptyMark, { borderColor: theme.color.divider }]}
        />
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  group: { overflow: 'hidden' },
  band: { flexDirection: 'row', alignItems: 'center' },
  emptyMark: { width: 20, height: 20, borderRadius: 10, borderWidth: 1.6 },
});
