import React from 'react';
import { Pressable, StyleSheet, Switch, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { ClockMark, IconTile } from './OnboardingMarks';
import {
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 09 — quiet times.
 *
 * No render exists for this step; it follows the grouped-surface language of
 * `Art/render/screens/32-onboarding-child-profile.png`.
 *
 * Skippable, and pre-seeded by the host with the two windows nearly every
 * family with a small child has (`QuietWindow.onboardingSuggestions`: nap
 * 12:30–2:30, bedtime 7:30–7:00). Offered switched on, so the common case is
 * one tap — and skipping is a real answer, not a deferral.
 *
 * Times arrive already formatted: how a wall-clock time is written is a locale
 * decision the host makes once, not something twelve screens each get wrong.
 */

export type QuietWindowLabel = 'nap' | 'bedtime' | 'school' | 'mealtime' | 'custom';

const LABEL_TITLES: Readonly<Record<QuietWindowLabel, string>> = {
  nap: 'Nap',
  bedtime: 'Bedtime',
  school: 'School',
  mealtime: 'Mealtime',
  custom: 'Quiet time',
};

export interface QuietWindowOption {
  readonly id: string;
  readonly label: QuietWindowLabel;
  /** Already formatted for the caregiver's locale, e.g. "12:30 PM". */
  readonly start: string;
  readonly end: string;
  readonly isEnabled: boolean;
}

export interface QuietHoursScreenProps {
  windows: readonly QuietWindowOption[];
  onToggleWindow?: (id: string, isEnabled: boolean) => void;
  /** The caregiver wants to change this window's hours. */
  onEditWindow?: (id: string) => void;
  onContinue?: () => void;
  onSkip?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function QuietHoursScreen({
  windows,
  onToggleWindow,
  onEditWindow,
  onContinue,
  onSkip,
  onBack,
  step = stepPosition('quietHours'),
}: QuietHoursScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <OnboardingScaffold
      eyebrow="Schedule"
      title="Quiet times"
      message="HopPotty stays silent during these. Naps, meals and bedtime are the usual ones."
      step={step}
      primaryLabel="Next"
      onPrimary={onContinue}
      skipLabel="Skip for now"
      onSkip={onSkip}
      onBack={onBack}
    >
      {windows.length === 0 ? (
        <View
          style={{
            backgroundColor: theme.color.surfaceSunken,
            borderRadius: theme.radius.m,
            padding: theme.spacing.l,
          }}
        >
          <HopText variant="parentCallout" tone="secondary">
            No quiet times yet.
          </HopText>
        </View>
      ) : (
        <View style={{ gap: theme.spacing.s }}>
          {windows.map((window) => (
            <QuietWindowRow
              key={window.id}
              window={window}
              onToggle={(value) => onToggleWindow?.(window.id, value)}
              onEdit={onEditWindow ? () => onEditWindow(window.id) : undefined}
            />
          ))}
        </View>
      )}
    </OnboardingScaffold>
  );
}

function QuietWindowRow({
  window,
  onToggle,
  onEdit,
}: {
  window: QuietWindowOption;
  onToggle: (value: boolean) => void;
  onEdit?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const title = LABEL_TITLES[window.label];
  const range = `${window.start} – ${window.end}`;

  return (
    <View
      style={[
        restingShadow(theme),
        {
          backgroundColor: theme.color.surface,
          borderRadius: theme.radius.l,
          padding: theme.spacing.l,
        },
      ]}
    >
      <View style={[styles.row, { gap: theme.spacing.m }]}>
        <IconTile
          size={30}
          radius={theme.radius.s}
          background={theme.isDark ? theme.color.surfaceSunken : theme.palette.lavenderSoft}
        >
          <ClockMark size={16} color={theme.palette.lavenderDeep} />
        </IconTile>
        <HopText variant="parentHeadline" style={styles.flex}>
          {title}
        </HopText>
        <Switch
          value={window.isEnabled}
          onValueChange={onToggle}
          accessibilityRole="switch"
          accessibilityLabel={`${title} quiet time`}
          trackColor={{ false: theme.color.divider, true: theme.color.brandAction }}
          thumbColor={theme.color.surface}
        />
      </View>

      {window.isEnabled ? (
        <Pressable
          accessibilityRole={onEdit ? 'button' : 'text'}
          accessibilityLabel={`${title}, ${range}`}
          accessibilityHint={onEdit ? 'Changes these hours' : undefined}
          disabled={!onEdit}
          onPress={onEdit}
          style={({ pressed }) => [
            {
              marginTop: theme.spacing.s,
              minHeight: theme.hitTarget.parentMinimum,
              justifyContent: 'center',
              opacity: pressed ? 0.7 : 1,
            },
          ]}
        >
          <HopText variant="parentCallout" tone={onEdit ? 'brand' : 'secondary'}>
            {range}
          </HopText>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  row: { flexDirection: 'row', alignItems: 'center' },
});
