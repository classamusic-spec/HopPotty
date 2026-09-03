import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { AuthorizationStatus } from '../../services/screen-time/types';
import { LockMark, PauseMark } from './OnboardingMarks';
import {
  OnboardingScaffold,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 07 — authorization, with every answer designed.
 *
 * There is no render for this step, because there is no single picture of it:
 * it is four screens' worth of copy in one view, and the app must never imply
 * Screen Time works when it does not.
 *
 * - **notDetermined** — ask, having already explained why.
 * - **approved** — say so, then move on.
 * - **denied** — the caregiver said no. HopPotty moves to gentle mode, says
 *   exactly what that means, and offers the Settings app rather than nagging.
 *   "Ask again" is offered once and is never the only way forward.
 * - **unavailable** — this device cannot do it at all. No retry button is
 *   shown, because there is nothing a retry could change.
 */

export interface AuthorizationScreenProps {
  status: AuthorizationStatus;
  /** The system prompt is up, or the answer is being read back. */
  isWorking?: boolean;
  /** Ask iOS. Called for `notDetermined` and for "Ask again" after a denial. */
  onRequestAuthorization?: () => void;
  /** Move on. Called when there is nothing left to ask. */
  onContinue?: () => void;
  /** Opens the iOS Settings app — the only thing that can change a denial. */
  onOpenSystemSettings?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function AuthorizationScreen({
  status,
  isWorking = false,
  onRequestAuthorization,
  onContinue,
  onOpenSystemSettings,
  onBack,
  step = stepPosition('authorization'),
}: AuthorizationScreenProps): React.ReactElement {
  const theme = useHopTheme();

  const title =
    status === 'approved'
      ? 'Screen Time is connected'
      : status === 'denied'
        ? 'HopPotty will send reminders instead'
        : status === 'unavailable'
          ? 'Screen Time is unavailable here'
          : 'HopPotty uses Screen Time';

  const message =
    status === 'notDetermined'
      ? 'iOS does the pausing. HopPotty asks permission to pause only the apps you pick, and never sees what happens inside them.'
      : undefined;

  const primaryLabel =
    status === 'notDetermined'
      ? 'Allow Screen Time'
      : status === 'denied'
        ? 'Ask again'
        : 'Next';

  const onPrimary =
    status === 'notDetermined' || status === 'denied' ? onRequestAuthorization : onContinue;

  return (
    <OnboardingScaffold
      eyebrow="Permission"
      title={title}
      message={message}
      step={step}
      primaryLabel={primaryLabel}
      primaryEnabled={!isWorking}
      onPrimary={onPrimary}
      // Offered only after a denial, and worded as continuing rather than
      // giving up: gentle mode is a real way to use HopPotty, not a consolation.
      secondaryLabel={status === 'denied' ? 'Not now' : undefined}
      onSecondary={status === 'denied' ? onContinue : undefined}
      onBack={onBack}
    >
      {status === 'approved' ? (
        <StatusBanner
          text="HopPotty can pause the apps you pick. It never sees what happens inside them."
          mark={
            <HopText variant="parentHeadline" style={{ color: theme.color.success }}>
              ✓
            </HopText>
          }
        />
      ) : null}

      {status === 'denied' ? (
        <View style={{ gap: theme.spacing.m }}>
          <StatusBanner
            text="Without Screen Time permission, apps are never paused. Hop still checks in on your schedule, and you can turn pausing on later in Settings."
            mark={<PauseMark size={18} color={theme.color.warning} />}
          />
          <HopButton
            label="Open Settings"
            variant="secondary"
            onPress={onOpenSystemSettings}
            style={styles.secondary}
          />
        </View>
      ) : null}

      {status === 'unavailable' ? (
        <StatusBanner
          text="This device is managed by someone else, so HopPotty is unable to pause apps on it. Gentle reminders still work."
          mark={<LockMark size={19} color={theme.color.neutral} />}
        />
      ) : null}

      {isWorking ? (
        <HopText variant="parentCallout" tone="secondary" style={{ marginTop: theme.spacing.m }}>
          Waiting for iOS…
        </HopText>
      ) : null}
    </OnboardingScaffold>
  );
}

function StatusBanner({
  text,
  mark,
}: {
  text: string;
  mark: React.ReactNode;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      accessible
      accessibilityLabel={text}
      style={[
        styles.banner,
        {
          backgroundColor: theme.color.surfaceSunken,
          borderRadius: theme.radius.m,
          padding: theme.spacing.l,
          gap: theme.spacing.m,
        },
      ]}
    >
      <View style={styles.markSlot}>{mark}</View>
      <HopText variant="parentCallout" tone="secondary" style={styles.flex}>
        {text}
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  banner: { flexDirection: 'row', alignItems: 'flex-start' },
  markSlot: { width: 24, alignItems: 'center', paddingTop: 2 },
  secondary: { alignSelf: 'stretch' },
});
