import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { SelectionSummary } from '../../services/screen-time/types';
import { IconTile, LockMark } from './OnboardingMarks';
import {
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 08 — the apps that pause.
 *
 * The reference is `Art/render/screens/05-choose-apps.png` (`chooseApps()` in
 * `Scripts/screens/settings.js`).
 *
 * ## Why this screen does not list apps
 *
 * Apple hands a selection over as opaque `ApplicationToken`s. HopPotty cannot
 * read a name, an icon, or what an app is, and `ScreenTimeConfiguration` stores
 * counts and nothing else. A list of app names would be unbuildable, and it
 * would contradict the privacy promise printed on this very screen.
 *
 * So this screen shows the *summary* and a button. The choosing is done by
 * `FamilyActivityPicker` — a system view presented through the native module,
 * which nothing here reimplements or restyles.
 */

export interface ChooseAppsScreenProps {
  selection: SelectionSummary;
  /** Presents Apple's `FamilyActivityPicker`. */
  onChooseApps?: () => void;
  onContinue?: () => void;
  onBack?: () => void;
  /**
   * Whether the system picker can be presented at all. False on any platform
   * without Family Controls — said out loud rather than shown as a button that
   * does nothing.
   */
  pickerAvailable?: boolean;
  step?: OnboardingStepPosition;
}

function plural(count: number, one: string, many: string): string {
  return `${count} ${count === 1 ? one : many}`;
}

/** "4 apps and 1 category will pause" — what HopPotty actually holds. */
export function summarySentence(selection: SelectionSummary): string {
  const parts: string[] = [];
  if (selection.applicationCount > 0) {
    parts.push(plural(selection.applicationCount, 'app', 'apps'));
  }
  if (selection.categoryCount > 0) {
    parts.push(plural(selection.categoryCount, 'category', 'categories'));
  }
  if (selection.webDomainCount > 0) {
    parts.push(plural(selection.webDomainCount, 'website', 'websites'));
  }
  const [first, ...rest] = parts;
  if (first === undefined) return 'Nothing is picked yet.';
  const last = rest.pop();
  const listed = last === undefined ? first : `${[first, ...rest].join(', ')} and ${last}`;
  return `${listed} will pause`;
}

export function ChooseAppsScreen({
  selection,
  onChooseApps,
  onContinue,
  onBack,
  pickerAvailable = true,
  step = stepPosition('chooseApps'),
}: ChooseAppsScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <OnboardingScaffold
      eyebrow="Apps"
      title="Pick the apps that pause"
      message="Usually the games and video apps your child uses most. Everything else keeps working as it does now."
      step={step}
      primaryLabel="Next"
      primaryEnabled={!selection.isEmpty}
      onPrimary={onContinue}
      onBack={onBack}
    >
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
        <HopText variant="parentHeadline">{summarySentence(selection)}</HopText>
        <View style={[styles.counts, { marginTop: theme.spacing.m }]}>
          <Count value={selection.applicationCount} label="Apps" />
          <View style={[styles.rule, { backgroundColor: theme.color.divider }]} />
          <Count
            value={selection.categoryCount}
            label={selection.categoryCount === 1 ? 'Category' : 'Categories'}
          />
          <View style={[styles.rule, { backgroundColor: theme.color.divider }]} />
          <Count value={selection.webDomainCount} label="Websites" />
        </View>
      </View>

      <View
        style={[
          styles.privacy,
          restingShadow(theme),
          {
            marginTop: theme.spacing.m,
            backgroundColor: theme.color.surface,
            borderRadius: theme.radius.l,
            padding: theme.spacing.l,
            gap: theme.spacing.m,
          },
        ]}
      >
        <IconTile
          size={30}
          radius={theme.radius.s}
          background={theme.isDark ? theme.color.surfaceSunken : theme.palette.pondBlueSoft}
        >
          <LockMark size={16} color={theme.color.eventPee} />
        </IconTile>
        <View style={styles.flex}>
          <HopText variant="parentHeadline">HopPotty never learns which apps</HopText>
          <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xs }}>
            It can pause the ones you pick, and nothing else. It cannot read their names or see
            inside them.
          </HopText>
        </View>
      </View>

      <HopButton
        label="Choose apps"
        onPress={onChooseApps}
        disabled={!pickerAvailable}
        style={{ ...styles.action, marginTop: theme.spacing.l }}
      />

      <HopText
        variant="parentCaption"
        tone="secondary"
        style={{ marginTop: theme.spacing.m, textAlign: 'center' }}
      >
        {pickerAvailable
          ? "The next screen is Apple's own picker. HopPotty cannot see or change what it shows."
          : 'This device has no Screen Time picker, so no apps can be paused here.'}
      </HopText>
    </OnboardingScaffold>
  );
}

function Count({ value, label }: { value: number; label: string }): React.ReactElement {
  return (
    <View accessible accessibilityLabel={`${value} ${label}`} style={styles.count}>
      <HopText variant="metric">{String(value)}</HopText>
      <HopText variant="parentCaption" tone="secondary">
        {label}
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  counts: { flexDirection: 'row', alignItems: 'center' },
  count: { flex: 1, alignItems: 'center' },
  rule: { width: StyleSheet.hairlineWidth, alignSelf: 'stretch' },
  privacy: { flexDirection: 'row', alignItems: 'flex-start' },
  action: { alignSelf: 'stretch', minHeight: 50 },
});
