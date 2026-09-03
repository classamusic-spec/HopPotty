import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  OnboardingScaffold,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 10 — the heads-up.
 *
 * No render exists for this step. It is the plainest screen in the flow on
 * purpose: one promise, one ask, and a denial that does not become a nag.
 *
 * iOS only ever asks once, so a denial is final until the caregiver changes it
 * in the Settings app. The screen says that and moves on rather than showing a
 * retry button that cannot work.
 */

export type NotificationPermission = 'notDetermined' | 'authorized' | 'provisional' | 'denied';

export interface NotificationsScreenProps {
  permission: NotificationPermission;
  /** The system prompt is up. */
  isWorking?: boolean;
  onAllow?: () => void;
  onContinue?: () => void;
  onOpenSystemSettings?: () => void;
  onSkip?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function NotificationsScreen({
  permission,
  isWorking = false,
  onAllow,
  onContinue,
  onOpenSystemSettings,
  onSkip,
  onBack,
  step = stepPosition('notifications'),
}: NotificationsScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const granted = permission === 'authorized' || permission === 'provisional';

  return (
    <OnboardingScaffold
      eyebrow="Notifications"
      title="Let Hop give a heads-up"
      message="A short notice before a pause gives your child a moment to finish what they are doing. HopPotty never sends anything to bring your child back to a screen."
      step={step}
      primaryLabel={granted ? 'Next' : 'Allow notifications'}
      primaryEnabled={!isWorking}
      // A denial is final on iOS, so the primary advances rather than re-asking.
      onPrimary={granted || permission === 'denied' ? onContinue : onAllow}
      skipLabel="Not now"
      onSkip={onSkip}
      onBack={onBack}
    >
      {permission === 'denied' ? (
        <View style={{ gap: theme.spacing.m }}>
          <View
            style={{
              backgroundColor: theme.color.surfaceSunken,
              borderRadius: theme.radius.m,
              padding: theme.spacing.l,
            }}
          >
            <HopText variant="parentCallout" tone="secondary">
              The heads-up before a pause needs notification permission.
            </HopText>
          </View>
          <HopButton
            label="Open Settings"
            variant="secondary"
            onPress={onOpenSystemSettings}
            style={styles.secondary}
          />
        </View>
      ) : null}

      {granted ? (
        <View style={[styles.row, { gap: theme.spacing.s }]}>
          <HopText variant="parentHeadline" style={{ color: theme.color.success }}>
            ✓
          </HopText>
          <HopText variant="parentCallout" tone="secondary" style={styles.flex}>
            Hop can give your child a heads-up before a pause.
          </HopText>
        </View>
      ) : null}
    </OnboardingScaffold>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  row: { flexDirection: 'row', alignItems: 'flex-start' },
  secondary: { alignSelf: 'stretch' },
});
